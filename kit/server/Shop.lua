-- Game passes and developer products.
-- Catalog lives in the game's shared Config (Config.Passes / Config.Products, keyed by name) so the client
-- can draw the shop; this module grants them. An id of 0 means "not created yet": in Studio the purchase is
-- simulated so every perk can be play-tested, in a live server the player sees "Coming soon".
-- A product with `once = true` (starter packs) can be bought once per player; the server refuses later prompts.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Data = require(script.Parent:WaitForChild("Data"))

local Shop = {}

type Catalog = { [string]: { id: number, name: string, price: number, once: boolean? } }
local passes: Catalog = {}
local products: Catalog = {}
local grants: { [string]: (Player, { [string]: any }) -> boolean } = {}
local passHooks: { (Player, string) -> () } = {}
local passById: { [number]: string } = {}
local productById: { [number]: string } = {}
local ownedCache: { [Player]: { [string]: boolean } } = {}

local buyRemote = Net.event("Buy")
local notifyRemote = Net.event("Notify")

local function grantPass(player: Player, key: string)
	local d = Data.get(player)
	if d then
		d.passes = d.passes or {}
		d.passes[key] = true
		Data.dirty(player)
	end
	ownedCache[player] = ownedCache[player] or {}
	ownedCache[player][key] = true
	for _, cb in ipairs(passHooks) do
		task.spawn(cb, player, key)
	end
end

local function grantProduct(player: Player, key: string): boolean
	local d = Data.get(player)
	local fn = grants[key]
	if not d or not fn then
		return false
	end
	local ok, res = pcall(fn, player, d)
	if not ok then
		warn("[Shop] grant failed", key, res)
		return false
	end
	if res ~= false then
		d.spent = (d.spent or 0) + (products[key] and products[key].price or 0)
		if products[key] and products[key].once then
			d.bought = d.bought or {}
			d.bought[key] = true
		end
		Data.dirty(player)
		return true
	end
	return false
end

-- opts.grants: { productKey = function(player, data) ... return true end }
function Shop.init(opts: { passes: Catalog, products: Catalog, grants: { [string]: (Player, { [string]: any }) -> boolean } })
	passes = opts.passes or {}
	products = opts.products or {}
	grants = opts.grants or {}
	for k, p in pairs(passes) do
		if p.id ~= 0 then
			passById[p.id] = k
		end
	end
	for k, p in pairs(products) do
		if p.id ~= 0 then
			productById[p.id] = k
		end
	end

	MarketplaceService.ProcessReceipt = function(info)
		local player = Players:GetPlayerByUserId(info.PlayerId)
		local key = productById[info.ProductId]
		if not player or not key then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local d = Data.wait(player, 10)
		-- a save that failed to load is never written back, so a grant there would be lost: Roblox retries later
		if not d or (Data.isTemp(player) and not RunService:IsStudio()) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		d.receipts = d.receipts or {}
		if d.receipts[info.PurchaseId] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		if not grantProduct(player, key) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		d.receipts[info.PurchaseId] = os.time()
		local n = 0
		for _ in pairs(d.receipts) do
			n += 1
		end
		if n > 60 then -- keep the newest receipts only
			local oldestId, oldestT = nil, math.huge
			for id, t in pairs(d.receipts) do
				if t < oldestT then
					oldestId, oldestT = id, t
				end
			end
			if oldestId then
				d.receipts[oldestId] = nil
			end
		end
		Data.save(player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = passById[passId]
		if purchased and key then
			grantPass(player, key)
		end
	end)

	Data.onLoaded(function(player, d)
		ownedCache[player] = {}
		d.passes = d.passes or {}
		for key, p in pairs(passes) do
			if d.passes[key] then
				ownedCache[player][key] = true
			elseif p.id ~= 0 then
				local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, p.id)
				if ok and owns then
					grantPass(player, key)
				end
			end
		end
		for key in pairs(ownedCache[player]) do
			for _, cb in ipairs(passHooks) do
				task.spawn(cb, player, key)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		ownedCache[p] = nil
	end)

	buyRemote.OnServerEvent:Connect(function(player, kind, key)
		if type(key) ~= "string" or not Net.allow(player, "buy", 0.5) then
			return
		end
		Shop.prompt(player, kind, key)
	end)
end

function Shop.prompt(player: Player, kind: string, key: string)
	local item = (kind == "pass" and passes or products)[key]
	if not item then
		return
	end
	if kind == "pass" and Shop.owns(player, key) then
		notifyRemote:FireClient(player, "You already own " .. item.name .. "!", "green")
		return
	end
	if kind ~= "pass" and item.once and Shop.boughtOnce(player, key) then
		notifyRemote:FireClient(player, "You already got the " .. item.name .. "!", "green")
		return
	end
	if Data.isTemp(player) and not RunService:IsStudio() then
		notifyRemote:FireClient(player, "Your save didn't load, so the shop is paused. Rejoin to fix it!", "orange")
		return
	end
	if item.id == 0 then
		if RunService:IsStudio() then
			notifyRemote:FireClient(player, "Studio test purchase: " .. item.name, "purple")
			if kind == "pass" then
				grantPass(player, key)
			else
				grantProduct(player, key)
			end
		else
			notifyRemote:FireClient(player, item.name .. " is coming soon!", "orange")
		end
		return
	end
	if kind == "pass" then
		MarketplaceService:PromptGamePassPurchase(player, item.id)
	else
		MarketplaceService:PromptProductPurchase(player, item.id)
	end
end

function Shop.owns(player: Player, key: string): boolean
	local c = ownedCache[player]
	if c and c[key] then
		return true
	end
	local d = Data.get(player) :: any
	return d ~= nil and d.passes ~= nil and d.passes[key] == true
end

-- True when a `once` product was already bought by this player.
function Shop.boughtOnce(player: Player, key: string): boolean
	local d = Data.get(player) :: any
	return d ~= nil and d.bought ~= nil and d.bought[key] == true
end

-- cb(player, passKey) runs when a pass is bought and on join for every pass the player owns.
function Shop.onPass(cb: (Player, string) -> ())
	table.insert(passHooks, cb)
end

function Shop.notify(player: Player, text: string, color: string?)
	notifyRemote:FireClient(player, text, color or "white")
end

function Shop.notifyAll(text: string, color: string?)
	notifyRemote:FireAllClients(text, color or "white")
end

return Shop

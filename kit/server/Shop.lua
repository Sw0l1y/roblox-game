-- Game passes and developer products.
-- Catalog lives in the game's shared Config (Config.Passes / Config.Products, keyed by name) so the client
-- can draw the shop; this module grants them. An id of 0 means "not created yet": in Studio the purchase is
-- simulated so every perk can be play-tested, in a live server the player sees "Coming soon".
-- A product with `once = true` (starter packs) can be bought once per player; the server refuses later prompts.
-- Extra catalog fields the kit handles itself:
--   random = true        a paid random item (bag, pack, box): refused for players under Roblox's paid-random
--                        restriction (kit Policy). Games give those players a fixed reward on the currency path.
--   gift = "PassKey"     (product) a gift copy of that pass for another player in the server (Shop.prompt target).
--   boost = { kind = "coins", mult = 2, minutes = 15, needs = 2? }   (product) a server-wide boost (kit Boosts)
--                        for everyone, with a shoutout; `needs` = only sold while that multiplier is running.
-- Prices: Config holds the planned price; once an item exists, its live price (regional pricing, price tests)
-- comes from GetProductInfo, here and in kit/client/Prices.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Data = require(script.Parent:WaitForChild("Data"))
local Policy = require(script.Parent:WaitForChild("Policy"))
local Boosts = require(script.Parent:WaitForChild("Boosts"))

local Shop = {}

type Catalog = { [string]: { id: number, name: string, price: number, once: boolean?, random: boolean?, gift: string?, boost: { [string]: any }? } }
local passes: Catalog = {}
local products: Catalog = {}
local grants: { [string]: (Player, { [string]: any }) -> boolean } = {}
local passHooks: { (Player, string) -> () } = {}
local passById: { [number]: string } = {}
local productById: { [number]: string } = {}
local ownedCache: { [Player]: { [string]: boolean } } = {}
local giftTarget: { [Player]: { [string]: number } } = {} -- buyer -> gift product key -> recipient UserId

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

local function giveGift(buyer: Player, key: string, d: { [string]: any }): boolean
	local passKey = products[key].gift :: string
	local pass = passes[passKey]
	if not pass then
		return false
	end
	local targetId = giftTarget[buyer] and giftTarget[buyer][key]
	local target = targetId and Players:GetPlayerByUserId(targetId)
	if target and target ~= buyer and Data.get(target) and not Shop.owns(target, passKey) then
		grantPass(target, passKey)
		Data.dirty(target)
		notifyRemote:FireAllClients("\u{1F381} " .. buyer.DisplayName .. " gifted " .. pass.name .. " to " .. target.DisplayName .. "!", "pink")
	elseif not Shop.owns(buyer, passKey) then
		grantPass(buyer, passKey) -- the friend left or already has it: the buyer gets the pass instead
		notifyRemote:FireClient(buyer, "Your friend wasn't here, so " .. pass.name .. " is yours!", "pink")
	else
		d.giftCredits = d.giftCredits or {} -- send it later for free from the same gift button
		d.giftCredits[passKey] = (d.giftCredits[passKey] or 0) + 1
		notifyRemote:FireClient(buyer, "Saved as a gift: pick a friend to send " .. pass.name .. " to!", "pink")
	end
	return true
end

local function grantProduct(player: Player, key: string): boolean
	local d = Data.get(player)
	local item = products[key]
	local fn = grants[key]
	if item and item.gift and d then
		fn = function(p, data)
			return giveGift(p, key, data)
		end
	elseif item and item.boost and not fn then
		fn = function(p: Player, _data: { [string]: any }): boolean
			local b = item.boost :: { [string]: any }
			local m = Boosts.add(b.kind, b.mult, (b.minutes or 15) * 60, p.DisplayName)
			notifyRemote:FireAllClients("\u{26A1} " .. p.DisplayName .. " started " .. m .. "x " .. tostring(b.label or b.kind) .. " for EVERYONE!", "gold")
			return true
		end
	end
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
	Policy.init()
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
	task.spawn(function() -- live prices for spend tracking (the client shop fetches its own, see kit Prices)
		for _, set in ipairs({ { passes, Enum.InfoType.GamePass }, { products, Enum.InfoType.Product } }) do
			for _, item in pairs(set[1]) do
				if item.id ~= 0 then
					local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, item.id, set[2])
					if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
						item.price = info.PriceInRobux
					end
				end
			end
		end
	end)

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
		giftTarget[p] = nil
	end)

	buyRemote.OnServerEvent:Connect(function(player, kind, key, target)
		if type(key) ~= "string" or not Net.allow(player, "buy", 0.5) then
			return
		end
		Shop.prompt(player, kind, key, type(target) == "number" and target or nil)
	end)
end

-- target: for a `gift` product, the UserId of the player in this server who gets the pass.
function Shop.prompt(player: Player, kind: string, key: string, target: number?)
	local item = (kind == "pass" and passes or products)[key]
	if not item then
		return
	end
	if item.random and Policy.randomBlocked(player) then
		notifyRemote:FireClient(player, item.name .. " isn't available in your region.", "orange")
		return
	end
	local boost = item.boost :: any
	if kind ~= "pass" and boost and boost.needs and Boosts.mult(boost.kind) < boost.needs then
		notifyRemote:FireClient(player, item.name .. " unlocks while a " .. tostring(boost.needs) .. "x boost is running!", "orange")
		return
	end
	if kind ~= "pass" and item.gift then
		local who = target and Players:GetPlayerByUserId(target)
		if not who or who == player then
			notifyRemote:FireClient(player, "Pick a player in this server to gift to!", "orange")
			return
		end
		if Shop.owns(who, item.gift) then
			notifyRemote:FireClient(player, who.DisplayName .. " already has it!", "orange")
			return
		end
		giftTarget[player] = giftTarget[player] or {}
		giftTarget[player][key] = target :: number
		local d = Data.get(player) :: any
		local credits = d and d.giftCredits
		if credits and (credits[item.gift] or 0) > 0 then -- a saved gift: send it for free
			credits[item.gift] -= 1
			Data.dirty(player)
			giveGift(player, key, d)
			return
		end
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

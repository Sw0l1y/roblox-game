-- ServerScriptService.GameServer
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local store = DataStoreService:GetDataStore("PlayerData_v1")

-- Remotes
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local function newRemote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local ClickRE = newRemote("Click")
local UpgradeRE = newRemote("Upgrade")
local RebirthRE = newRemote("Rebirth")

-- World
local function newPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = workspace
	return p
end

newPart({ Name = "Ground", Size = Vector3.new(400, 1, 400), Position = Vector3.new(0, -0.5, 0),
	Color = Color3.fromRGB(96, 168, 92), Material = Enum.Material.Grass })

local spawnLoc = Instance.new("SpawnLocation")
spawnLoc.Anchored = true
spawnLoc.Size = Vector3.new(12, 1, 12)
spawnLoc.Position = Vector3.new(0, 0.5, 0)
spawnLoc.Duration = 0
spawnLoc.Parent = workspace

local sellPad = newPart({ Name = "SellPad", Size = Vector3.new(16, 1, 16), Position = Vector3.new(0, 0.5, 36),
	Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Neon })
local bb = Instance.new("BillboardGui")
bb.Size = UDim2.fromOffset(240, 80)
bb.StudsOffset = Vector3.new(0, 6, 0)
bb.AlwaysOnTop = true
bb.Parent = sellPad
local bbText = Instance.new("TextLabel")
bbText.Size = UDim2.fromScale(1, 1)
bbText.BackgroundTransparency = 1
bbText.Text = "SELL POWER"
bbText.Font = Enum.Font.FredokaOne
bbText.TextScaled = true
bbText.TextColor3 = Color3.new(1, 1, 1)
bbText.TextStrokeTransparency = 0
bbText.Parent = bb

-- Player data
local DEFAULT = { Power = 0, Coins = 0, Level = 0, Rebirths = 0 }
local loaded = {}
local passes = {}
local lastClick = {}

local function setStat(player, key, value)
	player:SetAttribute(key, value)
	local ls = player:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild(key)
	if v then
		v.Value = value
	end
end

local function get(player, key)
	return player:GetAttribute(key) or 0
end

local function save(player)
	if not loaded[player] then
		return
	end
	local data = {}
	for k in pairs(DEFAULT) do
		data[k] = get(player, k)
	end
	local ok, err = pcall(function()
		store:SetAsync(tostring(player.UserId), data)
	end)
	if not ok then
		warn("Save failed for", player.Name, err)
	end
end

local function hasPass(player, key)
	return passes[player] and passes[player][key] == true
end

local function refreshPasses(player)
	passes[player] = passes[player] or {}
	for _, gp in ipairs(Config.GamePasses) do
		if gp.Id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, gp.Id)
			passes[player][gp.Key] = ok and owns or false
			player:SetAttribute("Pass_" .. gp.Key, passes[player][gp.Key])
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = player
	for _, key in ipairs({ "Coins", "Rebirths" }) do
		local v = Instance.new("NumberValue")
		v.Name = key
		v.Parent = ls
	end

	local ok, data = pcall(function()
		return store:GetAsync(tostring(player.UserId))
	end)
	if not ok then
		player:Kick("Could not load your data, please rejoin.")
		return
	end
	data = data or {}
	for k, d in pairs(DEFAULT) do
		setStat(player, k, data[k] or d)
	end
	loaded[player] = true
	refreshPasses(player)
end)

Players.PlayerRemoving:Connect(function(player)
	save(player)
	loaded[player] = nil
	passes[player] = nil
	lastClick[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		save(player)
	end
end)

task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			save(player)
		end
	end
end)

-- Gameplay
local function powerPerClick(player)
	local p = (1 + get(player, "Level")) * Config.RebirthMult(get(player, "Rebirths"))
	if hasPass(player, "DoublePower") then
		p *= 2
	end
	return p
end

local function addClick(player)
	if loaded[player] then
		setStat(player, "Power", get(player, "Power") + powerPerClick(player))
	end
end

ClickRE.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if lastClick[player] and now - lastClick[player] < Config.ClickCooldown then
		return
	end
	lastClick[player] = now
	addClick(player)
end)

task.spawn(function()
	while true do
		task.wait(Config.AutoClickInterval)
		for _, player in ipairs(Players:GetPlayers()) do
			if hasPass(player, "AutoClick") then
				addClick(player)
			end
		end
	end
end)

local sellDebounce = {}
sellPad.Touched:Connect(function(hit)
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if not player or not loaded[player] or sellDebounce[player] then
		return
	end
	local power = get(player, "Power")
	if power <= 0 then
		return
	end
	sellDebounce[player] = true
	local mult = hasPass(player, "VIP") and 1.5 or 1
	setStat(player, "Coins", get(player, "Coins") + math.floor(power * mult))
	setStat(player, "Power", 0)
	task.delay(0.3, function()
		sellDebounce[player] = nil
	end)
end)

UpgradeRE.OnServerEvent:Connect(function(player)
	if not loaded[player] then
		return
	end
	local cost = Config.UpgradeCost(get(player, "Level"))
	if get(player, "Coins") >= cost then
		setStat(player, "Coins", get(player, "Coins") - cost)
		setStat(player, "Level", get(player, "Level") + 1)
	end
end)

RebirthRE.OnServerEvent:Connect(function(player)
	if not loaded[player] then
		return
	end
	local cost = Config.RebirthCost(get(player, "Rebirths"))
	if get(player, "Coins") >= cost then
		setStat(player, "Rebirths", get(player, "Rebirths") + 1)
		setStat(player, "Coins", 0)
		setStat(player, "Power", 0)
		setStat(player, "Level", 0)
		save(player)
	end
end)

-- Monetization
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased then
		refreshPasses(player)
	end
end)

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player or not loaded[player] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	for _, prod in ipairs(Config.Products) do
		if prod.Id ~= 0 and prod.Id == receipt.ProductId and prod.Key == "CoinPack" then
			local amount = 1000 * (1 + get(player, "Rebirths")) ^ 2
			setStat(player, "Coins", get(player, "Coins") + amount)
			save(player)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

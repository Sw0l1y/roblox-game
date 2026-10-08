-- ServerScriptService.GameServer (Candy Smash Simulator)
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local store = DataStoreService:GetDataStore("CandyData_v1")

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
local FxRE = newRemote("Fx") -- server -> client effects
local BuyRE = newRemote("Buy") -- client -> server: prompt a pass/product

---------------------------------------------------------------------------
-- Lighting / mood
---------------------------------------------------------------------------
Lighting.ClockTime = 14.5
Lighting.Brightness = 3
Lighting.Ambient = Color3.fromRGB(150, 110, 140)
Lighting.OutdoorAmbient = Color3.fromRGB(200, 150, 190)
Lighting.GlobalShadows = true
local atmo = Instance.new("Atmosphere")
atmo.Density = 0.3
atmo.Color = Color3.fromRGB(255, 190, 230)
atmo.Decay = Color3.fromRGB(255, 140, 200)
atmo.Glare = 0.4
atmo.Haze = 1.5
atmo.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect")
cc.Saturation = 0.35
cc.Contrast = 0.1
cc.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.6
bloom.Size = 30
bloom.Threshold = 1.5
bloom.Parent = Lighting

---------------------------------------------------------------------------
-- World building
---------------------------------------------------------------------------
local world = Instance.new("Folder")
world.Name = "CandyWorld"
world.Parent = workspace
local rng = Random.new(42)

local function newPart(props, class)
	local p = Instance.new(class or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = props.Parent or world
	return p
end

local function billboard(adornee, text, color, height, width)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(width or 260, 80)
	bb.StudsOffset = Vector3.new(0, height or 6, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 250
	bb.Parent = adornee
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0
	t.Parent = bb
	return t
end

local function lollipop(pos, scale)
	local h = 10 * scale
	newPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 0.8 * scale, 0.8 * scale),
		CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic })
	local candy = newPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2 * scale, 7 * scale, 7 * scale),
		CFrame = CFrame.new(pos + Vector3.new(0, h + 3 * scale, 0)) * CFrame.Angles(0, math.rad(rng:NextInteger(0, 180)), 0),
		Color = Color3.fromHSV(rng:NextNumber(), 0.6, 1), Material = Enum.Material.Glass, Transparency = 0.1 })
	newPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.3 * scale, 3.5 * scale, 3.5 * scale),
		CFrame = candy.CFrame, Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic })
end

local function gumdrop(pos, scale)
	newPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(6, 6, 6) * scale, Position = pos + Vector3.new(0, 1 * scale, 0),
		Color = Color3.fromHSV(rng:NextNumber(), 0.75, 1), Material = Enum.Material.Glass, Transparency = 0.15 })
end

local function candyCane(pos, scale)
	local seg = 2 * scale
	for i = 0, 7 do
		newPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(seg, 1.5 * scale, 1.5 * scale),
			CFrame = CFrame.new(pos + Vector3.new(0, seg * i + seg / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = (i % 2 == 0) and Color3.fromRGB(230, 30, 50) or Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic })
	end
	newPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2) * scale,
		Position = pos + Vector3.new(0, seg * 8, 0), Color = Color3.fromRGB(230, 30, 50) })
end

local function cloud(pos)
	for _ = 1, 4 do
		newPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(10, 18),
			Position = pos + Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(-2, 3), rng:NextNumber(-6, 6)),
			Color = Color3.fromRGB(255, 200, 235), Material = Enum.Material.SmoothPlastic, CanCollide = false })
	end
end

local function chocoChunk(pos, scale)
	newPart({ Size = Vector3.new(8, 4, 8) * scale, CFrame = CFrame.new(pos + Vector3.new(0, 2 * scale, 0))
		* CFrame.Angles(0, math.rad(rng:NextInteger(0, 90)), math.rad(rng:NextInteger(-10, 10))),
		Color = Color3.fromRGB(90, 50, 25), Material = Enum.Material.SmoothPlastic })
end

local function lavaRock(pos, scale)
	newPart({ Size = Vector3.new(6, 6, 6) * scale, CFrame = CFrame.new(pos + Vector3.new(0, 2 * scale, 0))
		* CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 1), 0),
		Color = Color3.fromRGB(255, 90, 40), Material = Enum.Material.Neon })
end

local W = 160 -- world width (X)
local sellPads = {}
local zoneGates = {}

for zi, zone in ipairs(Config.Zones) do
	local z0 = zone.ZStart
	local zc = z0 + Config.ZoneLength / 2
	newPart({ Name = zone.Name .. " Ground", Size = Vector3.new(W, 2, Config.ZoneLength), Position = Vector3.new(0, -1, zc),
		Color = zone.Ground, Material = zi == 1 and Enum.Material.SmoothPlastic or (zi == 2 and Enum.Material.Sand or Enum.Material.Basalt) })
	-- side walls (candy fence)
	for _, x in ipairs({ -W / 2, W / 2 }) do
		newPart({ Size = Vector3.new(2, 12, Config.ZoneLength), Position = Vector3.new(x, 6, zc),
			Color = Color3.fromRGB(255, 120, 190), Material = Enum.Material.SmoothPlastic, Transparency = 0.3 })
	end

	-- decorations
	for _ = 1, 22 do
		local x = rng:NextNumber(-W / 2 + 8, W / 2 - 8)
		local z = rng:NextNumber(z0 + 8, z0 + Config.ZoneLength - 8)
		if math.abs(x) > 18 then -- keep center path clear
			local pos = Vector3.new(x, 0, z)
			local r = rng:NextNumber()
			if zi == 1 then
				if r < 0.45 then
					lollipop(pos, rng:NextNumber(0.8, 1.6))
				elseif r < 0.75 then
					gumdrop(pos, rng:NextNumber(0.8, 1.8))
				else
					candyCane(pos, rng:NextNumber(0.8, 1.4))
				end
			elseif zi == 2 then
				if r < 0.6 then
					chocoChunk(pos, rng:NextNumber(0.7, 2))
				else
					candyCane(pos, rng:NextNumber(1, 1.6))
				end
			else
				if r < 0.6 then
					lavaRock(pos, rng:NextNumber(0.6, 1.6))
				else
					gumdrop(pos, rng:NextNumber(1, 2.2))
				end
			end
		end
	end
	for _ = 1, 4 do
		cloud(Vector3.new(rng:NextNumber(-W / 2, W / 2), rng:NextNumber(45, 70), rng:NextNumber(z0, z0 + Config.ZoneLength)))
	end
	if zi == 2 then
		-- chocolate river
		newPart({ Size = Vector3.new(W - 4, 0.4, 14), Position = Vector3.new(0, 0.1, zc + 30),
			Color = Color3.fromRGB(70, 35, 15), Material = Enum.Material.Glass, Transparency = 0.05 })
	elseif zi == 3 then
		-- volcano
		local base = newPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(40, 60, 60),
			CFrame = CFrame.new(0, 20, z0 + Config.ZoneLength - 20) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(60, 25, 40), Material = Enum.Material.Basalt })
		local top = newPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 30, 30),
			CFrame = base.CFrame * CFrame.new(20, 0, 0), Color = Color3.fromRGB(255, 80, 20), Material = Enum.Material.Neon })
		local fire = Instance.new("Fire")
		fire.Size = 25
		fire.Heat = 25
		fire.Color = Color3.fromRGB(255, 120, 40)
		fire.Parent = top
	end

	-- sell shop for this zone
	local pad = newPart({ Name = "SellPad", Size = Vector3.new(16, 1, 16), Position = Vector3.new(0, 0.5, z0 + 50),
		Color = Color3.fromRGB(255, 210, 40), Material = Enum.Material.Neon })
	billboard(pad, "💰 SELL CANDY 💰", Color3.new(1, 1, 1), 7)
	local a = Instance.new("Attachment")
	a.Position = Vector3.new(0, 1, 0)
	a.Parent = pad
	local burst = Instance.new("ParticleEmitter")
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burst.Color = ColorSequence.new(Color3.fromRGB(255, 220, 60), Color3.fromRGB(255, 100, 200))
	burst.Size = NumberSequence.new(1.2, 0)
	burst.Lifetime = NumberRange.new(0.8, 1.4)
	burst.Speed = NumberRange.new(25, 45)
	burst.SpreadAngle = Vector2.new(60, 60)
	burst.Acceleration = Vector3.new(0, -40, 0)
	burst.LightEmission = 1
	burst.Rate = 0
	burst.Parent = a
	local idle = burst:Clone()
	idle.Rate = 12
	idle.Speed = NumberRange.new(4, 8)
	idle.Acceleration = Vector3.new(0, 4, 0)
	idle.Parent = a
	sellPads[pad] = burst

	-- zone sign
	local sign = newPart({ Size = Vector3.new(30, 1, 1), Position = Vector3.new(0, 24, z0 + 2), Transparency = 1, CanCollide = false })
	billboard(sign, zone.Name .. "  •  x" .. zone.Mult .. " SUGAR", Color3.fromRGB(255, 240, 120), 0, 420)

	-- gate (locked unless enough rebirths; client opens it locally)
	if zone.Rebirths > 0 then
		local gate = newPart({ Name = "Gate", Size = Vector3.new(W, 30, 2), Position = Vector3.new(0, 15, z0),
			Color = Color3.fromRGB(255, 60, 120), Material = Enum.Material.ForceField, Transparency = 0.2 })
		gate:SetAttribute("Rebirths", zone.Rebirths)
		billboard(gate, "🔒 " .. zone.Name .. "\nNeeds " .. zone.Rebirths .. " Rebirth" .. (zone.Rebirths > 1 and "s" or ""),
			Color3.new(1, 1, 1), 0, 360)
		zoneGates[#zoneGates + 1] = gate
	end
end
-- back wall
newPart({ Size = Vector3.new(W, 12, 2), Position = Vector3.new(0, 6, Config.Zones[1].ZStart), Color = Color3.fromRGB(255, 120, 190),
	Transparency = 0.3 })
newPart({ Size = Vector3.new(W, 12, 2), Position = Vector3.new(0, 6, Config.Zones[#Config.Zones].ZStart + Config.ZoneLength),
	Color = Color3.fromRGB(255, 120, 190), Transparency = 0.3 })

local spawnLoc = Instance.new("SpawnLocation")
spawnLoc.Anchored = true
spawnLoc.Size = Vector3.new(14, 1, 14)
spawnLoc.Position = Vector3.new(0, 0.5, 0)
spawnLoc.Color = Color3.fromRGB(255, 120, 200)
spawnLoc.Material = Enum.Material.Neon
spawnLoc.Duration = 0
spawnLoc.Parent = world

-- Ad boards: giant in-world signs with a buy prompt
local function adBoard(pos, rotY, passKey, text)
	local board = newPart({ Name = "AdBoard", Size = Vector3.new(22, 12, 1),
		CFrame = CFrame.new(pos + Vector3.new(0, 10, 0)) * CFrame.Angles(0, math.rad(rotY), 0),
		Color = Color3.fromRGB(40, 20, 60), Material = Enum.Material.SmoothPlastic })
	for _, xo in ipairs({ -9, 9 }) do
		newPart({ Size = Vector3.new(1, 10, 1), CFrame = board.CFrame * CFrame.new(xo, -10, 0), Color = Color3.fromRGB(255, 255, 255) })
	end
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(440, 240)
	sg.LightInfluence = 0
	sg.Parent = board
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(255, 60, 140)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0
	t.Text = text
	t.Parent = sg
	local back = sg:Clone()
	back.Face = Enum.NormalId.Back
	back.Parent = board
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "BUY NOW"
	prompt.ObjectText = Config.Find(Config.GamePasses, passKey).Name
	prompt.MaxActivationDistance = 25
	prompt.RequiresLineOfSight = false
	prompt.Parent = board
	prompt.Triggered:Connect(function(player)
		local gp = Config.Find(Config.GamePasses, passKey)
		if gp and gp.Id ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, gp.Id)
		else
			FxRE:FireClient(player, "Toast", "Coming soon!")
		end
	end)
	-- flashing border
	task.spawn(function()
		local hue = 0
		while board.Parent do
			hue = (hue + 0.03) % 1
			t.BackgroundColor3 = Color3.fromHSV(hue, 0.75, 1)
			task.wait(0.1)
		end
	end)
end
adBoard(Vector3.new(-26, 0, 12), 30, "DoublePower", "⚡ 2X SUGAR ⚡\nDOUBLE EVERYTHING!")
adBoard(Vector3.new(26, 0, 12), -30, "AutoClick", "🤖 AUTO SMASHER 🤖\nEARN WHILE AFK!")
adBoard(Vector3.new(-26, 0, 64), 30, "VIP", "👑 VIP 👑\n+50% COINS!")
adBoard(Vector3.new(26, 0, 224), -30, "DoublePower", "⚡ 2X SUGAR ⚡\nGET THERE FASTER!")

---------------------------------------------------------------------------
-- Player data
---------------------------------------------------------------------------
local DEFAULT = { Power = 0, Coins = 0, Level = 0, Rebirths = 0, Sells = 0 }
local loaded = {}
local passes = {}
local lastClick = {}
local combo = {}

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
	combo[player] = nil
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

---------------------------------------------------------------------------
-- Gameplay
---------------------------------------------------------------------------
local function zoneMult(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return 1
	end
	local zone = Config.ZoneAt(root.Position.Z)
	if get(player, "Rebirths") < zone.Rebirths then
		return 1
	end
	return zone.Mult
end

local function powerPerClick(player)
	local p = (1 + get(player, "Level")) * Config.RebirthMult(get(player, "Rebirths")) * zoneMult(player)
	if hasPass(player, "DoublePower") then
		p *= 2
	end
	if (player:GetAttribute("RushUntil") or 0) > os.time() then
		p *= 3
	end
	return p
end

local function addClick(player, comboCount)
	if not loaded[player] then
		return
	end
	local gain = powerPerClick(player) * Config.ComboMult(comboCount)
	local crit = math.random() < Config.CritChance
	if crit then
		gain *= Config.CritMult
	end
	gain = math.floor(gain)
	setStat(player, "Power", get(player, "Power") + gain)
	FxRE:FireClient(player, "Click", gain, crit, comboCount)
end

ClickRE.OnServerEvent:Connect(function(player)
	local now = os.clock()
	local last = lastClick[player]
	if last and now - last < Config.ClickCooldown then
		return
	end
	if last and now - last <= Config.ComboWindow then
		combo[player] = (combo[player] or 0) + 1
	else
		combo[player] = 1
	end
	lastClick[player] = now
	addClick(player, combo[player])
end)

task.spawn(function()
	while true do
		task.wait(Config.AutoClickInterval)
		for _, player in ipairs(Players:GetPlayers()) do
			if hasPass(player, "AutoClick") then
				addClick(player, 0)
			end
		end
	end
end)

local sellDebounce = {}
for pad, burst in pairs(sellPads) do
	pad.Touched:Connect(function(hit)
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
		local earned = math.floor(power * mult)
		setStat(player, "Coins", get(player, "Coins") + earned)
		setStat(player, "Power", 0)
		setStat(player, "Sells", get(player, "Sells") + 1)
		burst:Emit(math.clamp(math.floor(math.log10(earned + 1) * 25), 20, 150))
		FxRE:FireClient(player, "Sell", earned)
		task.delay(0.3, function()
			sellDebounce[player] = nil
		end)
	end)
end

UpgradeRE.OnServerEvent:Connect(function(player)
	if not loaded[player] then
		return
	end
	local cost = Config.UpgradeCost(get(player, "Level"))
	if get(player, "Coins") >= cost then
		setStat(player, "Coins", get(player, "Coins") - cost)
		setStat(player, "Level", get(player, "Level") + 1)
		FxRE:FireClient(player, "Upgrade", get(player, "Level"))
	else
		FxRE:FireClient(player, "Broke", "Upgrade", cost)
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
		FxRE:FireClient(player, "Rebirth", get(player, "Rebirths"))
	else
		FxRE:FireClient(player, "Broke", "Rebirth", cost)
	end
end)

---------------------------------------------------------------------------
-- Monetization
---------------------------------------------------------------------------
BuyRE.OnServerEvent:Connect(function(player, kind, key)
	if kind == "Pass" then
		local gp = Config.Find(Config.GamePasses, key)
		if gp and gp.Id ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, gp.Id)
			return
		end
	elseif kind == "Product" then
		local prod = Config.Find(Config.Products, key)
		if prod and prod.Id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, prod.Id)
			return
		end
	end
	FxRE:FireClient(player, "Toast", "Coming soon!")
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased then
		refreshPasses(player)
		FxRE:FireClient(player, "Bought")
	end
end)

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player or not loaded[player] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	for _, prod in ipairs(Config.Products) do
		if prod.Id ~= 0 and prod.Id == receipt.ProductId then
			if prod.Key == "CoinPack" then
				local amount = 1000 * (1 + get(player, "Rebirths")) ^ 2
				setStat(player, "Coins", get(player, "Coins") + amount)
				save(player)
			elseif prod.Key == "SugarRush" then
				local from = math.max(player:GetAttribute("RushUntil") or 0, os.time())
				player:SetAttribute("RushUntil", from + 600)
			end
			FxRE:FireClient(player, "Bought")
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

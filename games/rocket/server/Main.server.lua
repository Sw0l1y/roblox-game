-- Build the Rocket! 🚀  Server entry: world, saves, shop, the haul loop, bots, events and the launch.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Fmt = require(Shared:WaitForChild("Fmt"))

local Data = require(script.Parent:WaitForChild("Lib"):WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Lib"):WaitForChild("Shop"))
local Assets = require(script.Parent:WaitForChild("Lib"):WaitForChild("Assets"))
local Map = require(script.Parent:WaitForChild("Lib"):WaitForChild("Map"))
local Mission = require(script.Parent:WaitForChild("Lib"):WaitForChild("Mission"))
local Rocket = require(script.Parent:WaitForChild("Lib"):WaitForChild("Rocket"))
local Crew = require(script.Parent:WaitForChild("Lib"):WaitForChild("Crew"))
local Haul = require(script.Parent:WaitForChild("Lib"):WaitForChild("Haul"))
local Bots = require(script.Parent:WaitForChild("Lib"):WaitForChild("Bots"))
local Events = require(script.Parent:WaitForChild("Lib"):WaitForChild("Events"))
local Rewards = require(script.Parent:WaitForChild("Lib"):WaitForChild("Rewards"))
local Launch = require(script.Parent:WaitForChild("Lib"):WaitForChild("Launch"))
local Debug = require(script.Parent:WaitForChild("Lib"):WaitForChild("Debug"))

-- Every remote exists before any client asks for it.
for _, name in ipairs({ "Game", "Lift", "Drop", "Help", "Upgrade", "Skin", "Daily", "Popper", "Fx", "Notify", "Data", "Buy" }) do
	Net.event(name)
end

local DEFAULTS = {
	coins = 0,
	coinsTotal = 0,
	strengthEarned = 0,
	strengthShown = Config.Tune.baseStrength,
	hauled = 0,
	delivered = 0,
	launches = 0,
	mvps = 0,
	crates = 0,
	gear = { gloves = 1, suit = 1, jet = 1, drones = 1 },
	index = {},
	planets = {},
	bestPlanet = 1,
	bestMission = 1,
	skin = "Classic",
	daily = { last = 0, streak = 0 },
	quest = { date = "", count = 0, claimed = false },
	boostUntil = 0,
	ftue = { step = 0, epic = false },
	lastOnline = 0,
	starter = false,
	seen = {},
	muted = false,
}

-- Hero meshes (AI ids in Config.Meshes; 0 = not generated yet, every user has a primitive fallback).
Assets.init(Config.Meshes :: any)
local heroFolder = Instance.new("Folder")
heroFolder.Name = "HeroMeshes"
heroFolder.Parent = ReplicatedStorage
for key in pairs(Config.Meshes :: { [string]: any }) do
	local mp = Assets.get(key)
	if mp then
		mp.Name = key
		mp.Parent = heroFolder
	end
end

-- World and the first rocket
Map.buildAll()
Mission.setPlanet(1)
Rocket.build(1, 1)

Data.init({
	name = Config.Store,
	defaults = DEFAULTS,
	leaderstats = {
		{ name = "💪 Strength", get = function(d)
			return Fmt.num(d.strengthShown or Config.Tune.baseStrength)
		end },
		{ name = "🚀 Launches", get = function(d)
			return d.launches or 0
		end },
		{ name = "🪙 Coins", get = function(d)
			return Fmt.num(d.coins or 0)
		end },
	},
})

-- Shop: products grant here; passes apply through Shop.onPass (on purchase and on every join).
local function coinsPack(key: string): (Player, { [string]: any }) -> boolean
	return function(p, d)
		local item = (Config.Products :: any)[key]
		Crew.addCoins(p, (item.coins or 0) * Rewards.bestMult(d))
		Mission.fire(p, "thanks", { name = item.name, icon = item.icon })
		return true
	end
end

Shop.init({
	passes = Config.Passes :: any,
	products = Config.Products :: any,
	grants = {
		FuelServer = function(p, _d)
			Events.fuel(p)
			return true
		end,
		SupplyDrop = function(p, _d)
			Events.supplyDrop(p.DisplayName)
			return true
		end,
		StarterPack = function(p, d)
			Crew.addCoins(p, 1500 * Rewards.bestMult(d))
			if Config.Gear.gloves.cost[(d.gear.gloves or 1) + 1] then
				d.gear.gloves = (d.gear.gloves or 1) + 1
			end
			d.boostUntil = math.max(d.boostUntil or 0, os.time()) + Config.Tune.potionSeconds
			d.starter = true
			Crew.refresh(p)
			Crew.dress(p)
			Mission.fire(p, "thanks", { name = "Starter Pack", icon = "🎁" })
			return true
		end,
		Boost15 = function(p, d)
			d.boostUntil = math.max(d.boostUntil or 0, os.time()) + Config.Tune.potionSeconds
			Crew.refresh(p)
			Mission.fire(p, "thanks", { name = "3x Strength", icon = "⚡" })
			return true
		end,
		CoinsS = coinsPack("CoinsS"),
		CoinsM = coinsPack("CoinsM"),
		CoinsL = coinsPack("CoinsL"),
		CoinsXL = coinsPack("CoinsXL"),
	},
})

local function addTrail(player: Player)
	local c = player.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not root or root:FindFirstChild("RainbowTrail") then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailTop"
	a0.Position = Vector3.new(0, 0.9, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailBottom"
	a1.Position = Vector3.new(0, -0.9, 0)
	a1.Parent = root
	local t = Instance.new("Trail")
	t.Name = "RainbowTrail"
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Lifetime = 0.7
	t.LightEmission = 0.6
	t.FaceCamera = true
	t.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 230, 120)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 90, 255)),
	})
	t.Transparency = NumberSequence.new(0.15, 1)
	t.Parent = root
end

Shop.onPass(function(player, key)
	local d = Data.get(player)
	local first = d ~= nil and d.seen[key] == nil
	if d and first then
		d.seen[key] = true
		Data.dirty(player)
	end
	if string.sub(key, 1, 3) == "Str" then
		Crew.refresh(player)
	elseif key == "RobotCrew" then
		Bots.sync()
	elseif key == "MegaJetpack" then
		player:SetAttribute("MegaJetpack", true)
		Crew.dress(player)
		Crew.applyMovement(player)
	elseif key == "VIP" then
		player:SetAttribute("VIP", true)
		Crew.tag(player)
	elseif key == "RainbowTrail" then
		player:SetAttribute("Trail", true)
		addTrail(player)
	elseif key == "PartyPopper" then
		player:SetAttribute("Popper", true)
	elseif string.sub(key, 1, 4) == "Skin" and d and first then
		for _, sk in ipairs(Config.Skins) do
			if sk.pass == key then
				Rewards.equip(player, sk.key)
			end
		end
	end
	if first then
		local pass = (Config.Passes :: any)[key]
		if pass then
			Mission.fire(player, "thanks", { name = pass.name, icon = pass.icon })
		end
	end
end)

Crew.init()
Haul.init()
Bots.init()
Events.init()
Rewards.init()
Debug.init(DEFAULTS)

Rocket.onComplete(Launch.start)
Haul.onDeliver(function()
	Rewards.repaint()
end)

-- Players ------------------------------------------------------------------------------------------------

local function onCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid", 10)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not hum or not root or not hum:IsA("Humanoid") then
		return
	end
	task.wait()
	if char.Parent and (Mission.phase == "build" or Mission.phase == "boarding") then
		char:PivotTo(Mission.area().spawnCF + Vector3.new(0, 3, 0))
	end
	Launch.onCharacter(player)
	local d = Data.wait(player)
	if not d or not char.Parent then
		return
	end
	Crew.applyMovement(player)
	Crew.tag(player)
	Crew.dress(player)
	if Shop.owns(player, "RainbowTrail") then
		addTrail(player)
	end
	;(hum :: Humanoid).Died:Connect(function()
		Haul.drop(player)
	end)
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(c)
		onCharacter(player, c)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, p)
end

Data.onLoaded(function(player, d)
	local key = Config.dateKey(os.time())
	if d.quest.date ~= key then
		d.quest.date = key
		d.quest.count = 0
		d.quest.claimed = false
	end
	Rewards.offline(player, d)
	Crew.refresh(player)
	Crew.applyMovement(player)
	Crew.tag(player)
	Crew.dress(player)
	Rewards.repaint()
	-- a fresh server grows its first rocket to fit the crowd
	local filled = Rocket.counts()
	local preFilled = 0
	for _, s in ipairs(Rocket.slots) do
		if s.pre then
			preFilled += 1
		end
	end
	local want = Config.sizeClass(#Players:GetPlayers())
	if Mission.inBuild() and filled == preFilled and want > Rocket.size and Haul.count() <= #Map.areas[Mission.planet].depotPads + 1 then
		local busy = false
		for _, l in pairs(Haul.parts) do
			if l.mode == "carry" then
				busy = true
			end
		end
		if not busy then
			Haul.clear()
			Rocket.build(Mission.planet, want)
			Rewards.repaint()
		end
	end
end)

Players.PlayerRemoving:Connect(function()
	task.defer(Rewards.repaint)
end)

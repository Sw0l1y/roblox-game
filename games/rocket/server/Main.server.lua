-- Build the Rocket! 🚀  Server entry: world, saves, shop, the haul loop, bots, events and the launch, plus the
-- launch-week features (kit Live: codes, playtime gifts, quests, badges, invites, friend bonus, hourly event).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Fmt = require(Shared:WaitForChild("Fmt"))

local Data = require(script.Parent:WaitForChild("Lib"):WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Lib"):WaitForChild("Shop"))
local Boosts = require(script.Parent:WaitForChild("Lib"):WaitForChild("Boosts"))
local Live = require(script.Parent:WaitForChild("Lib"):WaitForChild("Live"))
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
for _, name in ipairs({ "Game", "Lift", "Drop", "Help", "Upgrade", "SkipPick", "Skin", "Daily", "Popper", "Fx", "Notify", "Data", "Buy", "Live" }) do
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
	welcomed = false,
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
		{ name = "💰 Coins", get = function(d)
			return Fmt.num(d.coins or 0)
		end },
	},
})

-- Shop: products grant here; passes apply through Shop.onPass (on purchase and on every join). Gift products
-- (`gift`) are granted by the kit.
type Grant = (Player, { [string]: any }) -> boolean
local products = Config.Products :: { [string]: any }

local function thanks(p: Player, item: { [string]: any })
	Mission.fire(p, "thanks", { name = item.name, icon = item.icon })
end

local function addPersonalBoost(p: Player, d: { [string]: any }, minutes: number)
	d.boostUntil = math.max(d.boostUntil or 0, os.time()) + minutes * 60
	Crew.refresh(p)
end

local function coinsPack(key: string): Grant
	return function(p, d)
		local item = products[key]
		Crew.addCoins(p, (item.coins or 0) * Rewards.bestMult(d))
		thanks(p, item)
		return true
	end
end

-- Server boosts (coins, luck, strength ladder) for everyone, with a big shoutout banner.
local function serverBoost(key: string): Grant
	return function(p, _d)
		local b = products[key].boost
		local m = Boosts.add(b.kind, b.mult, (b.minutes or 15) * 60, p.DisplayName)
		Crew.invalidate(nil)
		Mission.announce(string.format("%s %s started %sx %s for EVERYONE!", Config.Icons.boost, p.DisplayName, tostring(m), tostring(b.label or b.kind)), "gold", "cheer")
		return true
	end
end

-- "+N Parts" / "Finish the Rocket!": drones bolt parts onto the server rocket.
local function partsDrop(key: string): Grant
	return function(p, _d)
		Events.parts(p, products[key].parts or 3)
		return true
	end
end

-- "Next Rocket: Silver/Gold/Galaxy": the next rocket gets that tier (fixed, shown before buying).
local function nextRocket(key: string): Grant
	return function(p, _d)
		local tier = Config.rocketTier(products[key].tier)
		Mission.queueTier(tier.key, p.DisplayName)
		Mission.announce(string.format("%s %s ordered a %s ROCKET! x%s launch rewards for everyone!", tier.icon, p.DisplayName, string.upper(tier.name), tostring(tier.reward)), "gold", "cheer")
		return true
	end
end

-- Zero-G training minutes for the whole server.
local function zeroG(key: string): Grant
	return function(p, _d)
		local minutes: number = tonumber(products[key].train) or 1
		local mult: number = Config.Tune.zeroGMult
		Boosts.add("train", mult, minutes * 60, p.DisplayName)
		Mission.announce(string.format("%s %s added +%d MIN ZERO-G TRAINING! %dx strength gains for everyone!", Config.Icons.zerog, p.DisplayName, minutes, mult), "purple", "magic")
		return true
	end
end

local function skipGear(key: string): Grant
	return function(p, d)
		return Rewards.skip(p, d, products[key].skip or 2)
	end
end

local grants: { [string]: Grant } = {
	FuelServer = function(p, _d)
		Events.fuel(p)
		return true
	end,
	SupplyDrop = function(p, _d)
		Events.supplyDrop(p.DisplayName)
		return true
	end,
	Intro9 = function(p, d)
		local item = products.Intro9
		Crew.addCoins(p, item.coins * Rewards.bestMult(d))
		addPersonalBoost(p, d, 15)
		thanks(p, item)
		return true
	end,
	StarterPack = function(p, d)
		Crew.addCoins(p, products.StarterPack.coins * Rewards.bestMult(d))
		if Config.Gear.gloves.cost[(d.gear.gloves or 1) + 1] then
			d.gear.gloves = (d.gear.gloves or 1) + 1
		end
		d.starter = true
		addPersonalBoost(p, d, Config.Tune.potionSeconds / 60)
		Crew.dress(p)
		thanks(p, products.StarterPack)
		return true
	end,
	Boost15 = function(p, d)
		addPersonalBoost(p, d, Config.Tune.potionSeconds / 60)
		thanks(p, products.Boost15)
		return true
	end,
}
for key, item in pairs(products) do
	if grants[key] or item.gift then
		continue
	elseif item.boost then
		grants[key] = serverBoost(key)
	elseif item.parts then
		grants[key] = partsDrop(key)
	elseif item.tier then
		grants[key] = nextRocket(key)
	elseif item.train then
		grants[key] = zeroG(key)
	elseif item.skip then
		grants[key] = skipGear(key)
	elseif item.coins then
		grants[key] = coinsPack(key)
	end
end

Shop.init({
	passes = Config.Passes :: any,
	products = Config.Products :: any,
	grants = grants,
})

-- Launch-week features. Rewards: coins x best planet (like coin packs) and minutes of personal 3x Strength.
Live.init({
	config = Config.Live,
	grant = function(player, d, reward, _source)
		if reward.coins then
			Crew.addCoins(player, reward.coins * Rewards.bestMult(d))
		end
		if reward.boost then
			addPersonalBoost(player, d, reward.boost)
		end
		Data.dirty(player)
	end,
})
Live.onHour(function()
	Events.hourly()
end)

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
	if string.sub(key, 1, 3) == "Str" or string.sub(key, 1, 6) == "Launch" then
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
	Rewards.welcome(player, d)
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
		-- (the rebuild keeps the rocket's tier)
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

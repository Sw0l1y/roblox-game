-- Toy Army ⚔️ server: builds the giant bedroom, splits players into the Green and Tan armies, hands out toy-box
-- bases, and wires saves, the shop, zones and auto-battles, the AI commander, the house cat, war rounds, the
-- tutorial (FTUE), launch features (kit Live: codes, playtime gifts, quests, badges, the hourly MEGA CAT), paid
-- strikes, army skins and every client request. Clients only ask (Net.func "Act"); the server validates everything.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local World = require(Shared:WaitForChild("World"))
local Fmt = require(Shared:WaitForChild("Fmt"))
local Lib = (script.Parent :: Instance):WaitForChild("Lib")
local Data = require(Lib:WaitForChild("Data"))
local Shop = require(Lib:WaitForChild("Shop"))
local Look = require(Lib:WaitForChild("Look"))
local Assets = require(Lib:WaitForChild("Assets"))
local Room = require(Lib:WaitForChild("Room"))
local Battle = require(Lib:WaitForChild("Battle"))
local Army = require(Lib:WaitForChild("Army"))
local Zones = require(Lib:WaitForChild("Zones"))
local Commander = require(Lib:WaitForChild("Commander"))
local Cat = require(Lib:WaitForChild("Cat"))
local Bases = require(Lib:WaitForChild("Bases"))
local Debug = require(Lib:WaitForChild("Debug"))
local Live = require(Lib:WaitForChild("Live"))
local Boosts = require(Lib:WaitForChild("Boosts"))
local Strikes = require(Lib:WaitForChild("Strikes"))

local V = Vector3.new
type Dict = { [string]: any }

-- Remotes the clients listen to (created up front so client WaitForChild never stalls) ---------------------------
local actFunc = Net.func("Act")
local rewardRemote = Net.event("Reward")
local roundRemote = Net.event("Round")
Net.event("Cat")
Net.event("Zone")
Net.event("Battle")
Net.event("Topple")
Net.event("Feed")
Net.event("Announce")
Net.event("BagResult")
Net.event("Merged")
Net.event("Strike")
Net.func("Sync")

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Look: warm late-afternoon light pouring through the bedroom window (preset B tuned for indoors) -----------------
Look.apply({
	preset = "B",
	overrides = {
		ClockTime = 16.2,
		Brightness = 2.6,
		ExposureCompensation = 0.15,
		Ambient = Color3.fromRGB(150, 126, 118),
		OutdoorAmbient = Color3.fromRGB(180, 152, 138),
	},
	atmosphere = { Density = 0.22, Offset = 0.1, Haze = 1.2, Glare = 0, Color = Color3.fromRGB(255, 216, 182), Decay = Color3.fromRGB(206, 150, 140) },
	cc = { Brightness = 0.03, Contrast = 0.1, Saturation = 0.18, TintColor = Color3.fromRGB(255, 244, 230) },
	clouds = { Cover = 0.5, Density = 0.35, Color = Color3.fromRGB(255, 236, 220) },
})

-- Hero meshes: loaded on the server and shared with clients through ReplicatedStorage.HeroMeshes ---------------
local heroFolder = Instance.new("Folder")
heroFolder.Name = "HeroMeshes"
heroFolder.Parent = ReplicatedStorage
Assets.init(Config.Meshes)
for key in pairs(Config.Meshes) do
	task.spawn(function()
		local mp = Assets.get(key)
		if mp then
			mp.Name = key
			mp.Parent = heroFolder
		end
	end)
end

-- The world ----------------------------------------------------------------------------------------------------
local room = Room.build()
Zones.init(room)
Bases.init(room)
Cat.init(room)
Commander.init()

-- Teams and their spawns on the rug (each faces its own outpost flag: the first thing to deploy to) -------------
local teamObjs: { [string]: Team } = {}
local spawns: { [string]: SpawnLocation } = {}
for _, key in ipairs(Config.TeamKeys) do
	local def = Config.Team[key]
	local t = Instance.new("Team")
	t.Name = def.name
	t.TeamColor = (BrickColor :: any).new(def.brick)
	t.AutoAssignable = false
	t.Parent = Teams
	teamObjs[key] = t
	local sp = Config.Spawn[key]
	local look = V(sp.look.X, sp.pos.Y, sp.look.Z)
	local s = Instance.new("SpawnLocation")
	s.Name = key .. "Spawn"
	s.Anchored = true
	s.Size = V(10, 1, 10)
	s.CFrame = CFrame.lookAt(V(sp.pos.X, 0.1, sp.pos.Z), V(look.X, 0.1, look.Z))
	s.Transparency = 1
	s.CanCollide = false
	s.CanQuery = false
	s.CanTouch = false
	s.CastShadow = false
	s.Neutral = false
	s.TeamColor = t.TeamColor
	s.AllowTeamChangeOnTouch = false
	s.Duration = 0
	s.Parent = room
	spawns[key] = s
	local glow = World.pad(room, V(sp.pos.X, 0.6, sp.pos.Z), 6, def.color)
	glow.CanQuery = false
	glow.CanTouch = false
end

-- Sessions ------------------------------------------------------------------------------------------------------
-- ftue: seconds after joining of the first deploy, first reward and first free gift claimed (Debug "state" prints
-- them so the headless sim reports the first-minute timings).
type Session = { joined: number, giftAt: number, supplyAt: number, autoAt: number, welcome: Dict?, ftue: { [string]: number } }
local sessions: { [Player]: Session } = {}

local function mark(player: Player, what: string)
	local s = sessions[player]
	if s and not s.ftue[what] then
		s.ftue[what] = math.floor(os.clock() - s.joined + 0.5)
	end
end

local function side(player: Player): string
	return (player:GetAttribute("Side") :: string?) or "Green"
end

local function pickTeam(): string
	local g, t = 0, 0
	for _, p in ipairs(Players:GetPlayers()) do
		local s = p:GetAttribute("Side")
		if s == "Green" then
			g += 1
		elseif s == "Tan" then
			t += 1
		end
	end
	if g == t then
		return math.random() < 0.5 and "Green" or "Tan"
	end
	return g < t and "Green" or "Tan"
end

local function outpostOf(team: string): string
	return team == "Tan" and "out_t" or "out_g"
end

-- Tutorial (FTUE) ------------------------------------------------------------------------------------------------
local function setTut(player: Player, d: Dict, n: number)
	if d.tut >= n then
		return
	end
	d.tut = n
	if d.tut == 5 and d.supplyClaimed then
		d.tut = 6
	end
	Army.addXp(player, d, 5)
	if d.tut >= Config.TutDone then
		Army.addTokens(player, d, "Heavy", 1, nil, true)
		Army.feed("🎖️ " .. player.DisplayName .. " finished basic training!", "yellow")
	end
	rewardRemote:FireClient(player, "tut", d.tut)
	Data.dirty(player)
end

local function tierOf(stack: string): number
	local u = Config.split(stack)
	return Config.UnitIndex[u] or 1
end

local function hasTankTier(d: Dict): boolean
	for stack, n in pairs(d.units) do
		if n > 0 and tierOf(stack) >= 4 then
			return true
		end
	end
	return false
end

-- Targets: where the big DEPLOY button sends the squad (tutorial step first, then the best beatable zone) --------
local function readyPower(player: Player, d: Dict): number
	local n = Army.squadSize(player, d)
	local p = 0
	for _, r in ipairs(Army.ready(player, d)) do
		for _ = 1, r.n do
			if n <= 0 then
				break
			end
			p += r.power
			n -= 1
		end
	end
	return p * Army.bonus(player, d)
end

local function bestTarget(player: Player, d: Dict): string
	local team = side(player)
	local out = outpostOf(team)
	if d.tut <= 3 then
		return out
	elseif d.tut == 4 then
		return "rug"
	elseif d.tut == 6 then
		return "tower"
	end
	local sp = readyPower(player, d)
	if sp <= 0 then
		return out
	end
	local best, bestScore = nil :: string?, -1
	for _, zs in ipairs(Zones.real()) do
		local f = zs.fight
		local score = -1
		if f then
			if f.attTeam == team or f.defTeam == team then
				score = 60 + zs.def.tier
			end
		elseif zs.owner ~= team then
			if Zones.garrisonPower(zs) < sp * 0.9 then
				score = 100 + zs.def.tier * 10 + (zs.owner and 5 or 0)
			end
		elseif #zs.garrison < zs.def.cap and Zones.garrisonPower(zs) < sp * 1.5 then
			score = 20 + zs.def.tier
		end
		if score > bestScore then
			best, bestScore = zs.def.id, score
		end
	end
	return best or out
end

-- Deploying (HUD button, map panel, flag prompts and Auto-Deploy all come through here) ---------------------------
local function doDeploy(player: Player, zoneId: string): (boolean, string?)
	local d = Data.get(player)
	local def = Config.ZoneById[zoneId]
	if not d or not def then
		return false, nil
	end
	local ready = Army.ready(player, d)
	local hadTank = ready[1] ~= nil and tierOf(ready[1].stack) >= 4
	local ok, why = Zones.deploy(player, zoneId)
	if not ok then
		return false, why
	end
	mark(player, "deploy")
	Live.quest(player, "deploy", 1)
	if d.tut == 6 and (hadTank or not hasTankTier(d)) then
		setTut(player, d, 7)
	end
	if d.tut == 4 and why == "reinforce" and zoneId == "rug" then
		setTut(player, d, 5)
	end
	if why == "attack" then
		return true, "⚔️ Attacking " .. def.name .. "!"
	elseif why == "join" then
		return true, "⚔️ Joined the battle at " .. def.name .. "!"
	elseif why == "reinforce" then
		return true, "🛡️ Guarding " .. def.name .. "!"
	end
	return true, "🎯 Drill at your Outpost!"
end

Zones.onPrompt(function(player, zoneId)
	if not Net.allow(player, "prompt", 0.5) then
		return
	end
	player:SetAttribute("ActiveAt", now())
	local ok, msg = doDeploy(player, zoneId)
	if msg then
		Shop.notify(player, msg, ok and "green" or "red")
	end
end)

Zones.onResolved(function(f, _winner, captured)
	for player, s in pairs(f.participants) do
		local d = Data.get(player)
		if d and player.Parent then
			local won = (s == "att" and captured) or (s == "def" and not captured)
			if won then
				mark(player, "reward")
				if d.tut == 1 then
					setTut(player, d, 2)
				end
				if d.tut == 4 and s == "att" and not f.drill then
					setTut(player, d, 5)
				end
				if s == "att" and not f.drill then
					Live.quest(player, "capture", 1)
					Live.badge(player, "FirstCapture")
				end
				if (d.stats.wins or 0) >= 10 then
					Live.badge(player, "Wins10")
				end
			end
		end
	end
end)

Army.on("bag", function(player, d)
	if d.tut == 2 then
		setTut(player, d, 3)
	end
	Live.quest(player, "bags", 1)
end)
Army.on("merge", function(player, d)
	if d.tut == 3 then
		setTut(player, d, 4)
	end
	Live.quest(player, "merge", 1)
end)
Army.on("upgrade", function(player, d)
	if d.tut == 7 then
		setTut(player, d, Config.TutDone)
	end
	Live.quest(player, "upgrade", 1)
	Bases.refreshNow(player)
end)
Army.on("unit", function(player, _d, unitKey)
	if unitKey == "Tank" then
		Live.badge(player, "FirstTank")
	elseif unitKey == "Dino" then
		Live.badge(player, "SecretDino")
	end
end)

-- Saves ----------------------------------------------------------------------------------------------------------
local function giveStarter(player: Player, d: Dict)
	if not d.starterGiven then
		d.starterGiven = true
		Army.addUnits(player, d, "Rifleman", "", 3)
	end
end

local function dailyReady(d: Dict): boolean
	return d.daily.last == 0 or Config.dayNumber(os.time()) > Config.dayNumber(d.daily.last)
end

Data.onLoaded(function(player: Player, d: Dict)
	if not player.Parent then
		return
	end
	giveStarter(player, d)
	-- offline earnings from the plastic press
	local away = (d.lastSeen or 0) > 0 and math.max(0, os.time() - d.lastSeen) or 0
	local earned = 0
	if away >= 60 and (d.upgrades.press or 0) > 0 then
		local cap = Shop.owns(player, "vip") and Config.OfflineCapVip or Config.OfflineCap
		earned = Army.addPlastic(player, d, Config.pressRate(d.upgrades.press) / 60 * math.min(away, cap), { kind = "offline" })
	end
	d.lastSeen = os.time()
	if d.tut == 5 and d.supplyClaimed then
		d.tut = 6
	end
	local s = sessions[player]
	if s then
		s.welcome = { offline = earned, away = away, daily = dailyReady(d), first = (d.sessions or 1) <= 1 }
		if (d.sessions or 1) <= 1 then
			-- a brand-new player's first free gift comes inside the first minute (later ones every 10 minutes)
			s.giftAt = math.min(s.giftAt, now() - (os.clock() - s.joined) + Config.FirstGiftAt)
			player:SetAttribute("GiftAt", s.giftAt)
		end
	end
	player:SetAttribute("Skin", d.skin or "")
	player:SetAttribute("TankPaint", d.tankPaint or "")
	Data.dirty(player)
	Bases.refreshNow(player)
end)

Data.onLeaving(function(_player: Player, d: Dict)
	d.lastSeen = os.time()
end)

-- Shop: passes and products (Studio simulates purchases for id 0) ---------------------------------------------------
local function rankPlastic(player: Player, d: Dict, amount: number, kind: string)
	Army.addPlastic(player, d, amount * Config.rankReward(Army.rank(d)), { raw = true, kind = kind })
end

-- Strikes are granted by firing them (or saving a credit when there is nothing to hit).
local function strikeGrant(key: string): (Player, Dict) -> boolean
	return function(player: Player, d: Dict): boolean
		if not Strikes.fire(player, key, nil) then
			d.strikeCredits[key] = (d.strikeCredits[key] or 0) + 1
			Shop.notify(player, "Saved! Use your " .. Config.Products[key].name .. " from STRIKES when there's an enemy to hit.", "orange")
		end
		return true
	end
end

local grants: { [string]: (Player, Dict) -> boolean } = {
	intro = function(player, d)
		Army.addPlastic(player, d, 1000, { raw = true, kind = "purchase" })
		Army.grantReveal(player, d, "Recruit Deal", { { "Tank", "" } })
		return true
	end,
	skip = function(player, d)
		Army.skipMerges(player, d)
		return true
	end,
	luck = function(player, d)
		d.boosts.luck = math.max(os.time(), d.boosts.luck or 0) + Config.LuckBoostSeconds
		Shop.notify(player, "🍀 LUCKY BAGS active for 15 minutes!", "green")
		return true
	end,
	starter = function(player, d)
		d.starterPack = true
		Army.addPlastic(player, d, 1500, { raw = true, kind = "purchase" })
		Army.grantReveal(player, d, "Starter Pack", { { "Medic", "" }, { "Medic", "" }, { "Tank", "Gold" } })
		return true
	end,
	bags10 = function(player, d)
		Army.addTokens(player, d, "Basic", 10, nil, true)
		return true
	end,
	tanks = function(player, d)
		Army.grantReveal(player, d, "Tank Bundle", { { "Tank", "" }, { "Tank", "" }, { "Tank", "Gold" } })
		return true
	end,
	helis = function(player, d)
		Army.grantReveal(player, d, "Heli Bundle", { { "Heli", "" }, { "Heli", "" }, { "Heli", "Glow" } })
		return true
	end,
}
for _, key in ipairs(Config.StrikeOrder) do
	grants[key] = strikeGrant(key)
end
for _, key in ipairs(Config.PlasticOrder) do
	local base = Config.Products[key].base or 0
	grants[key] = function(player: Player, d: Dict): boolean
		rankPlastic(player, d, base, "purchase")
		return true
	end
end

Shop.init({
	passes = Config.Passes :: any,
	products = Config.Products :: any,
	grants = grants,
})

-- Skins: equipped one army skin + the tank paint; mirrored to player attributes so every client paints that
-- player's toys (Arena) and the toy-box showcase repaints (Bases).
local function setSkin(player: Player, d: Dict, key: string)
	local sk = Config.Skins[key]
	if key == "" or not sk then
		d.skin = ""
	elseif sk.kind == "tank" then
		d.tankPaint = (d.tankPaint == key) and "" or key
	else
		d.skin = key
	end
	player:SetAttribute("Skin", d.skin)
	player:SetAttribute("TankPaint", d.tankPaint)
	Data.dirty(player)
	Bases.refreshNow(player)
end

local function tag(player: Player, character: Model)
	local head = character:WaitForChild("Head", 10)
	if not head or not player.Parent then
		return
	end
	local old = head:FindFirstChild("ToyTag")
	if old then
		old:Destroy()
	end
	local d = Data.get(player)
	local def = Config.Team[side(player)]
	local bb = Instance.new("BillboardGui")
	bb.Name = "ToyTag"
	bb.Size = UDim2.fromOffset(240, 56)
	bb.StudsOffset = V(0, 2.8, 0)
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	bb.Adornee = head
	local prefix = Shop.owns(player, "pro") and "👑 " or Shop.owns(player, "vip") and "🎖️ " or ""
	player:SetAttribute("Tag", Shop.owns(player, "pro") and "PRO" or Shop.owns(player, "vip") and "VIP" or "")
	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 0.58)
	name.Font = Enum.Font.LuckiestGuy
	name.TextScaled = true
	name.Text = prefix .. player.DisplayName
	name.TextColor3 = def and def.color or Color3.new(1, 1, 1)
	local s1 = Instance.new("UIStroke")
	s1.Thickness = 2.5
	s1.Color = Config.C.ink
	s1.Parent = name
	name.Parent = bb
	local rank = Instance.new("TextLabel")
	rank.Name = "Rank"
	rank.BackgroundTransparency = 1
	rank.Position = UDim2.fromScale(0, 0.6)
	rank.Size = UDim2.fromScale(1, 0.4)
	rank.Font = Enum.Font.FredokaOne
	rank.TextScaled = true
	local rk = Config.Ranks[Config.rankOf(d and d.xp or 0)]
	rank.Text = rk.glyph .. " " .. rk.name
	rank.TextColor3 = Color3.new(1, 1, 1)
	local s2 = Instance.new("UIStroke")
	s2.Thickness = 2
	s2.Color = Config.C.ink
	s2.Parent = rank
	rank.Parent = bb
	bb.Parent = head
end

local function retag(player: Player)
	local ch = player.Character
	if ch then
		task.spawn(tag, player, ch)
	end
end

Shop.onPass(function(player, key)
	local d = Data.get(player)
	if not d then
		return
	end
	if key == "vip" and not d.vipGeneral then
		d.vipGeneral = true
		Army.grantReveal(player, d, "VIP General", { { "General", "" } })
	elseif key == "pro" and not d.proBundle then
		d.proBundle = true
		Army.grantReveal(player, d, "Pro Commander", { { "Tank", "Rainbow" } })
	end
	if Config.Skins[key] and not d.skinsSeen then
		d.skinsSeen = {}
	end
	if Config.Skins[key] and not d.skinsSeen[key] then
		d.skinsSeen[key] = true -- first time: put the new skin on right away
		local sk = Config.Skins[key]
		if sk.kind == "tank" then
			if d.tankPaint ~= key then
				setSkin(player, d, key)
			end
		elseif d.skin ~= key then
			setSkin(player, d, key)
		end
	end
	if key == "pro" or key == "bigbox" then
		Bases.refreshNow(player)
	end
	if key == "vip" or key == "pro" then
		retag(player)
	end
	Data.dirty(player)
end)

Army.on("rank", function(player, _d, rank)
	retag(player)
	if (tonumber(rank) or 0) >= 5 then
		Live.badge(player, "Lieutenant")
	end
end)

-- The character usually spawns before the save has loaded (tag shows Recruit): redo the tag once the rank is known.
Data.onLoaded(function(player)
	retag(player)
end)

-- Players ----------------------------------------------------------------------------------------------------------
local function onPlayerAdded(player: Player)
	if sessions[player] then
		return
	end
	local team = pickTeam()
	player:SetAttribute("Side", team)
	player.Team = teamObjs[team]
	player.RespawnLocation = spawns[team]
	sessions[player] = {
		joined = os.clock(),
		giftAt = now() + Config.GiftEvery,
		supplyAt = os.clock() + Config.SupplyAt,
		autoAt = os.clock() + 8,
		welcome = nil,
		ftue = {},
	}
	player:SetAttribute("GiftAt", now() + Config.GiftEvery)
	player:SetAttribute("ActiveAt", now())
	player:SetAttribute("SupplyReady", false)
	player:SetAttribute("Target", outpostOf(team))
	Bases.assign(player, team)
	player.CharacterAdded:Connect(function(ch)
		tag(player, ch)
	end)
	if player.Character then
		task.spawn(tag, player, player.Character)
	end
	Army.feed("💂 " .. player.DisplayName .. " joined the " .. Config.Team[team].name .. "!", team == "Green" and "green" or "orange")
	task.delay(4, Cat.replay, player) -- the cat may already be out
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

-- Saves load after our PlayerAdded handler, so every session exists before its data arrives.
Data.init({
	name = Config.Store,
	defaults = Config.Defaults :: any,
	leaderstats = {
		{ name = "Plastic", get = function(d: Dict)
			return Fmt.num(d.plastic or 0)
		end },
		{ name = "Rank", get = function(d: Dict)
			return Config.Ranks[Config.rankOf(d.xp or 0)].name
		end },
	},
})

-- Launch features (kit Live): rewards are plastic (grows with rank), free bags and minutes of Lucky Bags.
Live.init({
	config = Config.Live,
	grant = function(player: Player, d: Dict, reward: Dict, _source: string)
		if reward.plastic then
			rankPlastic(player, d, reward.plastic, "gift")
		end
		if type(reward.bags) == "table" then
			for bag, n in pairs(reward.bags :: { [string]: number }) do
				if Config.BagByKey[bag] then
					Army.addTokens(player, d, bag, n, nil, true)
				end
			end
		end
		if reward.luckMinutes then
			d.boosts.luck = math.max(os.time(), d.boosts.luck or 0) + reward.luckMinutes * 60
		end
		Data.dirty(player)
	end,
})

-- Hourly event at :00: the MEGA CAT (4 zones, twice the lost-soldier bags) and 10 minutes of 2x plastic for all.
local function hourly()
	Cat.hourly()
	Boosts.add("plastic", Config.Hourly.boost, Config.Hourly.boostMinutes * 60, "HOURLY EVENT")
	Shop.notifyAll("⏰ HOURLY EVENT! The MEGA CAT is coming + " .. Config.Hourly.boost .. "x PLASTIC for everyone for " .. Config.Hourly.boostMinutes .. " minutes!", "gold")
end
Live.onHour(function()
	hourly()
end)

Players.PlayerRemoving:Connect(function(player)
	Zones.removePlayer(player)
	Army.cleanup(player)
	Bases.release(player)
	sessions[player] = nil
end)

-- Client requests ----------------------------------------------------------------------------------------------------
local function claimSupply(player: Player, d: Dict): (boolean, string?)
	if d.supplyClaimed then
		return false, "Supply Drop already opened!"
	end
	if player:GetAttribute("SupplyReady") ~= true then
		return false, "The Supply Drop is still on its way! 🪂"
	end
	d.supplyClaimed = true
	player:SetAttribute("SupplyReady", false)
	Army.grantReveal(player, d, "Supply Drop", { { "Tank", "" } })
	Army.addPlastic(player, d, 150, { raw = true, kind = "supply" })
	Army.feed("🪂 " .. player.DisplayName .. " opened a Supply Drop: a TANK!", "teal")
	if d.tut == 5 then
		setTut(player, d, 6)
	end
	return true, nil
end

type Action = (Player, Dict, any, any) -> (boolean, any)
local actions: { [string]: Action } = {
	hello = function(player, _d)
		local s = sessions[player]
		local w = s and s.welcome
		if s then
			s.welcome = nil
		end
		return true, w
	end,
	-- STRIKES panel: remember the zone the next strike purchase should hit
	aim = function(player, _d, zoneId)
		if type(zoneId) ~= "string" then
			return false, nil
		end
		Strikes.setAim(player, zoneId)
		return true, nil
	end,
	-- use a saved strike credit
	strike = function(player, d, key, zoneId)
		if type(key) ~= "string" or not Config.Strikes[key] or key == "callcat" then
			return false, nil
		end
		if (d.strikeCredits[key] or 0) <= 0 then
			return false, "No saved " .. Config.Products[key].name .. "!"
		end
		if not Strikes.fire(player, key, type(zoneId) == "string" and zoneId or nil) then
			return false, "Nothing to hit right now!"
		end
		d.strikeCredits[key] -= 1
		if d.strikeCredits[key] <= 0 then
			d.strikeCredits[key] = nil
		end
		Data.dirty(player)
		return true, nil
	end,
	skin = function(player, d, key)
		if type(key) ~= "string" then
			return false, nil
		end
		if key ~= "" and (not Config.Skins[key] or not Shop.owns(player, key)) then
			return false, "Buy this skin in the SHOP first!"
		end
		setSkin(player, d, key)
		return true, nil
	end,
	deploy = function(player, _d, zoneId)
		if type(zoneId) ~= "string" then
			return false, nil
		end
		return doDeploy(player, zoneId)
	end,
	recall = function(player, _d, zoneId)
		if type(zoneId) ~= "string" then
			return false, nil
		end
		if Zones.recall(player, zoneId) then
			return true, "↩️ Your soldiers marched home."
		end
		return false, "Nothing to bring home right now."
	end,
	open = function(player, _d, bagKey, useToken)
		if type(bagKey) ~= "string" then
			return false, nil
		end
		return Army.openBag(player, bagKey, useToken == true)
	end,
	merge = function(player, _d, stack)
		if type(stack) ~= "string" then
			return false, nil
		end
		return Army.merge(player, stack)
	end,
	upgrade = function(player, _d, key)
		if type(key) ~= "string" then
			return false, nil
		end
		return Army.upgrade(player, key)
	end,
	daily = function(player, d)
		if not dailyReady(d) then
			return false, "Come back tomorrow for your next daily reward!"
		end
		local today = Config.dayNumber(os.time())
		if d.daily.last > 0 and today == Config.dayNumber(d.daily.last) + 1 then
			d.daily.streak = (d.daily.streak or 0) + 1
		else
			d.daily.streak = 1
		end
		d.daily.last = os.time()
		local r = Config.Daily[(d.daily.streak - 1) % #Config.Daily + 1]
		rankPlastic(player, d, r.plastic, "daily")
		Army.addTokens(player, d, r.bag, r.n, nil, true)
		Data.dirty(player)
		return true, d.daily.streak
	end,
	gift = function(player, d)
		local s = sessions[player]
		if not s then
			return false, nil
		end
		if now() < s.giftAt then
			return false, "Free bag in " .. Fmt.time(s.giftAt - now())
		end
		mark(player, "gift")
		s.giftAt = now() + Config.GiftEvery
		player:SetAttribute("GiftAt", s.giftAt)
		rankPlastic(player, d, Config.Gift.plastic, "gift")
		Army.addTokens(player, d, Config.Gift.bag, Config.Gift.n, nil, true)
		return true, nil
	end,
	supply = function(player, d)
		return claimSupply(player, d)
	end,
	auto = function(player, d, on)
		d.settings.auto = on == true
		Data.dirty(player)
		return true, d.settings.auto
	end,
}

actFunc.OnServerInvoke = function(player: Player, action: any, a: any, b: any): (boolean, any)
	if type(action) ~= "string" then
		return false, nil
	end
	local fn = actions[action]
	if not fn then
		return false, nil
	end
	if not Net.allow(player, "act:" .. action, 0.15) then
		return false, nil
	end
	if action ~= "hello" then
		player:SetAttribute("ActiveAt", now())
	end
	local d = Data.get(player)
	if not d then
		return false, "Loading your toy box..."
	end
	local ok, r1, r2 = pcall(fn, player, d, a, b)
	if not ok then
		warn("[Act]", action, r1)
		return false, nil
	end
	return r1, r2
end

-- War rounds: every few minutes the army holding more zones wins a prize --------------------------------------------
local roundEnd = now() + Config.Round.length
workspace:SetAttribute("RoundEnd", roundEnd)

local function endRound(): string
	local g, t = Zones.count("Green"), Zones.count("Tan")
	local winner = g > t and "Green" or t > g and "Tan" or nil
	for _, p in ipairs(Players:GetPlayers()) do
		local d = Data.get(p)
		if d and winner then
			local held = winner == "Green" and g or t
			if side(p) == winner then
				rankPlastic(p, d, Config.Round.perZone * held, "round")
				Army.addTokens(p, d, "Basic", 1)
				Army.addXp(p, d, Config.Round.xp)
				Live.quest(p, "round", 1)
				Live.badge(p, "RoundWin")
			else
				rankPlastic(p, d, Config.Round.perZone * held * 0.3, "round")
			end
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		local f = p:GetAttribute("Friends")
		if type(f) == "number" and f > 0 then
			Live.quest(p, "friend", 1) -- played a round with a friend in the server
		end
	end
	roundRemote:FireAllClients(winner or "", g, t)
	if winner then
		Army.feed("🏆 The " .. Config.Team[winner].name .. " wins the round " .. math.max(g, t) .. "-" .. math.min(g, t) .. "!", winner == "Green" and "green" or "orange")
	else
		Army.feed("🤝 The round is a tie " .. g .. "-" .. t .. "!", "white")
	end
	roundEnd = now() + Config.Round.length
	workspace:SetAttribute("RoundEnd", roundEnd)
	return winner and (winner .. " wins " .. g .. "-" .. t) or ("tie " .. g .. "-" .. t)
end

task.spawn(function()
	while true do
		task.wait(0.5)
		if now() >= roundEnd then
			local ok, err = pcall(endRound)
			if not ok then
				warn("[Round]", err)
				roundEnd = now() + Config.Round.length
			end
		end
	end
end)

-- Auto-Deploy pass: ready soldiers march to the best beatable target on their own ------------------------------------
local function autoDeploy(player: Player, d: Dict)
	if not Shop.owns(player, "autodeploy") or not d.settings.auto or d.tut < 4 then
		return
	end
	if #Army.ready(player, d) == 0 then
		return
	end
	local target = bestTarget(player, d)
	local ok, msg = doDeploy(player, target)
	if ok and msg then
		Shop.notify(player, "🤖 Auto: " .. msg, "teal")
	end
end

-- Main ticks -----------------------------------------------------------------------------------------------------------
task.spawn(function()
	local tick = 0
	while true do
		task.wait(1)
		tick += 1
		local ok, err = pcall(function()
			Army.tickMerges()
			Army.tickRecover()
			for _, p in ipairs(Players:GetPlayers()) do
				local d = Data.get(p)
				local s = sessions[p]
				if d and s then
					Army.publishBusy(p)
					p:SetAttribute("DrillIn", math.ceil(Zones.drillReadyIn(p)))
					p:SetAttribute("Target", bestTarget(p, d))
					if not d.supplyClaimed and p:GetAttribute("SupplyReady") ~= true and (os.clock() >= s.supplyAt or d.tut >= 5) then
						p:SetAttribute("SupplyReady", true)
						rewardRemote:FireClient(p, "supply", 1)
					end
					if os.clock() >= s.autoAt then
						s.autoAt = os.clock() + 7
						autoDeploy(p, d)
					end
					if tick % 60 == 0 then
						d.lastSeen = os.time()
					end
				end
			end
		end)
		if not ok then
			warn("[Tick]", err)
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(Config.IncomeTick)
		local ok, err = pcall(Zones.payIncome, function(_p: Player, d: Dict): number
			return Config.pressRate(d.upgrades.press or 0) / 60 * Config.IncomeTick
		end)
		if not ok then
			warn("[Income]", err)
		end
	end
end)

-- Studio test hooks ------------------------------------------------------------------------------------------------------
Debug.init({
	round = function(): string
		return endRound()
	end,
	hourly = function(): string
		hourly()
		return "hourly event: mega cat + 2x plastic"
	end,
	ftue = function(player: Player): string
		local s = sessions[player]
		if not s then
			return "-"
		end
		local f = s.ftue
		local function t(k: string): string
			return f[k] and (tostring(f[k]) .. "s") or "-"
		end
		return string.format("deploy=%s reward=%s gift@%ds claimed=%s", t("deploy"), t("reward"), math.floor(s.giftAt - (now() - (os.clock() - s.joined)) + 0.5), t("gift"))
	end,
	skin = function(player: Player, key: string)
		local d = Data.get(player)
		if d then
			setSkin(player, d, key)
		end
	end,
	supply = function(player: Player)
		local s = sessions[player]
		if s then
			s.supplyAt = 0
		end
		local d = Data.get(player)
		if d then
			d.supplyClaimed = false
			Data.dirty(player)
		end
	end,
	refresh = function(player: Player)
		local d = Data.get(player)
		if d then
			giveStarter(player, d)
		end
		local s = sessions[player]
		if s then
			s.supplyAt = os.clock() + Config.SupplyAt
			s.giftAt = now() + Config.GiftEvery
			player:SetAttribute("GiftAt", s.giftAt)
		end
		player:SetAttribute("SupplyReady", false)
		Bases.refreshNow(player)
		retag(player)
	end,
})

-- keep Battle referenced for type exports used above
local _ = Battle

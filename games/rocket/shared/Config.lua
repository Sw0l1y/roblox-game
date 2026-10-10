-- Build the Rocket! 🚀  All tuning numbers, palette, planets, rocket parts, rarities, gear, ranks, skins,
-- the shop catalog (passes/products, ids 0 until created), icons (emoji for now) and hero meshes.
local Config = {}

local C3 = Color3.fromRGB
local V3 = Vector3.new

Config.Title = "Build the Rocket! 🚀"
Config.Store = "Rocket_v1"

-- Palette: launch-pad grey, safety orange, sky blue, white, rare gold (+ navy ink and hologram cyan).
Config.Palette = {
	pad = C3(176, 184, 198), -- #B0B8C6 launch-pad grey
	padDark = C3(120, 130, 150),
	padLight = C3(212, 218, 228),
	orange = C3(255, 132, 36), -- #FF8424 safety orange
	orangeDark = C3(214, 96, 20),
	sky = C3(90, 200, 255), -- #5AC8FF sky blue
	white = C3(242, 240, 232), -- #F2F0E8 white
	gold = C3(255, 196, 40), -- #FFC428 rare gold
	navy = C3(38, 48, 84),
	glow = C3(70, 225, 255),
	red = C3(255, 76, 76),
	green = C3(96, 220, 96),
	-- Earth nature
	grass = C3(102, 186, 78),
	grassLight = C3(138, 208, 100),
	grassDark = C3(84, 160, 64),
	sand = C3(240, 220, 168),
	sandWet = C3(222, 196, 140),
	water = C3(64, 182, 240),
	waterShallow = C3(110, 214, 245),
	rock = C3(176, 184, 198),
	rockDark = C3(138, 148, 166),
	trunk = C3(150, 104, 66),
	leaf1 = C3(84, 160, 64),
	leaf2 = C3(110, 188, 82),
	leaf3 = C3(140, 210, 100),
}

export type Planet = {
	key: string,
	name: string,
	icon: string,
	blurb: string,
	origin: Vector3,
	gravity: number,
	weight: number, -- part weight multiplier
	coins: number, -- coin multiplier
	scale: number, -- rocket scale
	extraTanks: number,
	ground: Color3,
	groundDark: Color3,
	groundLight: Color3,
	accent: Color3,
	variant: string?,
	look: { [string]: any },
	music: { number },
}

local EARTH_MUSIC = { 1842976958, 1836942830, 1845266081 }
local SPACE_MUSIC = { 1840434670, 1839807682, 1838005831 }

Config.Planets = {
	{
		key = "Earth",
		name = "EARTH",
		icon = "🌍",
		blurb = "Home base. Build your first rocket!",
		origin = V3(0, 0, 0),
		gravity = 196.2,
		weight = 1,
		coins = 1,
		scale = 1,
		extraTanks = 0,
		ground = Config.Palette.grass,
		groundDark = Config.Palette.grassDark,
		groundLight = Config.Palette.grassLight,
		accent = Config.Palette.orange,
		variant = "HouseGrass",
		look = { preset = "A", cc = { Brightness = 0.06 }, clouds = { Cover = 0.42, Density = 0.32, Color = C3(255, 255, 255) } },
		music = EARTH_MUSIC,
	},
	{
		key = "Moon",
		name = "THE MOON",
		icon = "🌙",
		blurb = "Low gravity! Giant slow-mo jumps.",
		origin = V3(3000, 0, 0),
		gravity = 196.2 * 0.3,
		weight = 2.5,
		coins = 3,
		scale = 1.15,
		extraTanks = 0,
		ground = C3(196, 198, 212),
		groundDark = C3(150, 152, 170),
		groundLight = C3(222, 224, 236),
		accent = C3(150, 120, 255),
		variant = "MoonDust",
		look = {
			preset = "D",
			overrides = { ClockTime = 14.5, OutdoorAmbient = C3(130, 128, 170) },
			atmosphere = { Density = 0.28, Offset = 0.05, Haze = 1.9, Glare = 0, Color = C3(150, 140, 230), Decay = C3(36, 26, 92) },
			clouds = false,
		},
		music = SPACE_MUSIC,
	},
	{
		key = "Mars",
		name = "MARS",
		icon = "🔴",
		blurb = "Red dust, tall mesas, bigger rocket.",
		origin = V3(6000, 0, 0),
		gravity = 196.2 * 0.42,
		weight = 6,
		coins = 8,
		scale = 1.3,
		extraTanks = 1,
		ground = C3(222, 118, 74),
		groundDark = C3(176, 84, 56),
		groundLight = C3(240, 150, 100),
		accent = C3(255, 170, 90),
		variant = "MarsSoil",
		look = {
			preset = "D",
			overrides = { ClockTime = 15, OutdoorAmbient = C3(170, 120, 110) },
			atmosphere = { Density = 0.3, Offset = 0.05, Haze = 2.2, Glare = 0.1, Color = C3(255, 160, 110), Decay = C3(120, 44, 40) },
			clouds = { Cover = 0.3, Density = 0.2, Color = C3(255, 196, 160) },
		},
		music = SPACE_MUSIC,
	},
	{
		key = "Europa",
		name = "EUROPA",
		icon = "🧊",
		blurb = "Jupiter's ice moon. The biggest rocket yet!",
		origin = V3(9000, 0, 0),
		gravity = 196.2 * 0.24,
		weight = 15,
		coins = 20,
		scale = 1.45,
		extraTanks = 1,
		ground = C3(214, 236, 250),
		groundDark = C3(160, 200, 232),
		groundLight = C3(236, 248, 255),
		accent = C3(70, 225, 255),
		variant = "EuropaIce",
		look = {
			preset = "D",
			overrides = { ClockTime = 13.5, OutdoorAmbient = C3(120, 150, 190) },
			atmosphere = { Density = 0.27, Offset = 0.05, Haze = 1.8, Glare = 0, Color = C3(140, 214, 255), Decay = C3(30, 50, 120) },
			clouds = false,
		},
		music = SPACE_MUSIC,
	},
} :: { Planet }

-- Rocket parts. weight = Earth weight (x planet.weight x rarity mass). holders = max lifters (players + bots).
export type Kind = { key: string, name: string, icon: string, weight: number, holders: number, light: boolean, lie: boolean }
Config.Kinds = {
	nose = { key = "nose", name = "Nose Cone", icon = "🔺", weight = 8, holders = 3, light = true, lie = false },
	tip = { key = "tip", name = "Booster Cap", icon = "🔸", weight = 6, holders = 3, light = true, lie = false },
	fin = { key = "fin", name = "Fin", icon = "🦈", weight = 14, holders = 3, light = true, lie = false },
	deck = { key = "deck", name = "Crew Deck", icon = "⭕", weight = 18, holders = 4, light = true, lie = false },
	capsule = { key = "capsule", name = "Crew Capsule", icon = "🛸", weight = 40, holders = 5, light = false, lie = false },
	engine = { key = "engine", name = "Engine", icon = "🔥", weight = 50, holders = 5, light = false, lie = false },
	tank = { key = "tank", name = "Fuel Tank", icon = "🛢️", weight = 60, holders = 6, light = false, lie = false },
	booster = { key = "booster", name = "Side Booster", icon = "🚀", weight = 100, holders = 8, light = false, lie = true },
	crate = { key = "crate", name = "Star Crate", icon = "⭐", weight = 30, holders = 6, light = false, lie = false },
} :: { [string]: Kind }
Config.KindOrder = { "nose", "tip", "fin", "deck", "capsule", "engine", "tank", "booster" }

-- Rarity roll for every part the depot makes (weights sum to 1000; odds shown in the Index).
export type Rarity = { key: string, weight: number, coin: number, mass: number }
Config.Rarity = {
	{ key = "Common", weight = 600, coin = 1, mass = 1 },
	{ key = "Uncommon", weight = 230, coin = 1.5, mass = 1.1 },
	{ key = "Rare", weight = 110, coin = 2.5, mass = 1.2 },
	{ key = "Epic", weight = 45, coin = 4, mass = 1.35 },
	{ key = "Legendary", weight = 12, coin = 8, mass = 1.5 },
	{ key = "Mythic", weight = 2.5, coin = 15, mass = 1.75 },
	{ key = "Secret", weight = 0.5, coin = 50, mass = 2 },
} :: { Rarity }
Config.RarityByKey = {} :: { [string]: Rarity }
for _, r in ipairs(Config.Rarity) do
	Config.RarityByKey[r.key] = r
end

-- Gear bought with coins. mult multiplies strength; jet also adds jump; drones earn coins per minute (and offline).
export type GearTrack = {
	key: string,
	name: string,
	icon: string,
	desc: string,
	mult: { number },
	cost: { number },
	jump: { number }?,
	rate: { number }?,
}
Config.Gear = {
	gloves = {
		key = "gloves",
		name = "Power Gloves",
		icon = "🧤",
		desc = "Grip harder. Multiplies your strength.",
		mult = { 1, 1.5, 2.2, 3.2, 5, 8, 13, 22 },
		cost = { 0, 120, 600, 2800, 12000, 50000, 220000, 900000 },
	},
	suit = {
		key = "suit",
		name = "Space Suit",
		icon = "🧑‍🚀",
		desc = "Pressurised muscle. Multiplies strength.",
		mult = { 1, 1.3, 1.7, 2.3, 3.2, 4.5, 6.5 },
		cost = { 0, 400, 2200, 9000, 40000, 180000, 800000 },
	},
	jet = {
		key = "jet",
		name = "Jetpack",
		icon = "🎒",
		desc = "Boost thrust: more strength and higher jumps.",
		mult = { 1, 1.2, 1.45, 1.8, 2.3, 3 },
		jump = { 0, 6, 12, 18, 24, 30 },
		cost = { 0, 900, 6000, 30000, 150000, 700000 },
	},
	drones = {
		key = "drones",
		name = "Drone Crew",
		icon = "🛸",
		desc = "Drones mine coins every minute, even offline.",
		mult = { 1, 1, 1, 1, 1, 1, 1 },
		rate = { 0, 6, 18, 45, 110, 280, 750 },
		cost = { 0, 700, 4500, 25000, 120000, 600000, 3000000 },
	},
} :: { [string]: GearTrack }
Config.GearOrder = { "gloves", "suit", "jet", "drones" }

-- Crew ranks from lifetime weight hauled (shown as the tag over your head). Each rank adds +5% strength.
export type Rank = { name: string, icon: string, need: number, tier: string }
Config.Ranks = {
	{ name = "Cadet", icon = "🔰", need = 0, tier = "Common" },
	{ name = "Rookie", icon = "🔧", need = 400, tier = "Uncommon" },
	{ name = "Engineer", icon = "⚙️", need = 2500, tier = "Rare" },
	{ name = "Pilot", icon = "🛩️", need = 12000, tier = "Epic" },
	{ name = "Captain", icon = "⭐", need = 60000, tier = "Legendary" },
	{ name = "Commander", icon = "🎖️", need = 300000, tier = "Mythic" },
	{ name = "Legend", icon = "🌌", need = 2000000, tier = "Secret" },
} :: { Rank }

-- Rocket skins: colours for each paint role of Common parts (rarer parts keep their tier colours).
export type Skin = {
	key: string,
	name: string,
	icon: string,
	body: Color3,
	accent: Color3,
	trim: Color3,
	metal: Color3,
	glow: Color3,
	unlock: string, -- "free" | "launches" | "planet" | "pass"
	need: number?,
	pass: string?,
}
Config.Skins = {
	{ key = "Classic", name = "Classic", icon = "🚀", body = Config.Palette.white, accent = Config.Palette.orange, trim = Config.Palette.navy, metal = Config.Palette.pad, glow = Config.Palette.glow, unlock = "free" },
	{ key = "Retro", name = "Retro Red", icon = "🍒", body = C3(250, 246, 238), accent = C3(232, 56, 56), trim = C3(120, 24, 34), metal = C3(190, 190, 196), glow = C3(255, 220, 90), unlock = "launches", need = 5 },
	{ key = "Arctic", name = "Arctic", icon = "❄️", body = C3(226, 244, 255), accent = C3(70, 160, 255), trim = C3(36, 70, 124), metal = C3(170, 196, 220), glow = C3(160, 255, 255), unlock = "planet", need = 4 },
	{ key = "Galaxy", name = "Galaxy", icon = "🌌", body = C3(78, 64, 150), accent = C3(255, 104, 200), trim = C3(30, 24, 70), metal = C3(120, 110, 180), glow = C3(170, 130, 255), unlock = "pass", pass = "SkinGalaxy" },
	{ key = "Candy", name = "Candy", icon = "🍬", body = C3(255, 214, 232), accent = C3(255, 90, 160), trim = C3(150, 60, 120), metal = C3(240, 240, 250), glow = C3(120, 240, 255), unlock = "pass", pass = "SkinCandy" },
	{ key = "Golden", name = "Golden", icon = "👑", body = C3(255, 206, 64), accent = C3(255, 250, 235), trim = C3(196, 130, 24), metal = C3(230, 176, 60), glow = C3(255, 244, 160), unlock = "pass", pass = "SkinGolden" },
} :: { Skin }

-- Shop -----------------------------------------------------------------------------------------------
-- Strength ladder (Build the Pyramid! sells 10 steps 29-1,499): the best step you own applies.
Config.Ladder = { "Str2", "Str3", "Str5", "Str8", "Str10", "Str15", "Str25", "Str40", "Str60", "Str100" }

Config.Passes = {
	Str2 = { id = 0, name = "2x Strength", price = 29, icon = "💪", mult = 2, desc = "Permanent 2x strength." },
	Str3 = { id = 0, name = "3x Strength", price = 59, icon = "💪", mult = 3, desc = "Permanent 3x strength." },
	Str5 = { id = 0, name = "5x Strength", price = 99, icon = "💪", mult = 5, desc = "Permanent 5x strength." },
	Str8 = { id = 0, name = "8x Strength", price = 149, icon = "💪", mult = 8, desc = "Permanent 8x strength." },
	Str10 = { id = 0, name = "10x Strength", price = 199, icon = "💪", mult = 10, desc = "Permanent 10x strength." },
	Str15 = { id = 0, name = "15x Strength", price = 299, icon = "💪", mult = 15, desc = "Permanent 15x strength." },
	Str25 = { id = 0, name = "25x Strength", price = 449, icon = "💪", mult = 25, desc = "Permanent 25x strength." },
	Str40 = { id = 0, name = "40x Strength", price = 699, icon = "💪", mult = 40, desc = "Permanent 40x strength." },
	Str60 = { id = 0, name = "60x Strength", price = 999, icon = "💪", mult = 60, desc = "Permanent 60x strength." },
	Str100 = { id = 0, name = "100x Strength", price = 1499, icon = "💪", mult = 100, desc = "Permanent 100x strength. Lift anything!" },
	RobotCrew = { id = 0, name = "Robot Crew", price = 299, icon = "🤖", desc = "2 robots follow you and help lift every part." },
	MegaJetpack = { id = 0, name = "Mega Jetpack", price = 149, icon = "🚀", desc = "Double jump with flames + faster hauling." },
	VIP = { id = 0, name = "VIP Window Seat", price = 399, icon = "👑", desc = "Gold window seat at launch, VIP tag, +20% coins." },
	Coins2x = { id = 0, name = "2x Coins", price = 249, icon = "🪙", desc = "Double coins from every part, forever." },
	SkinGalaxy = { id = 0, name = "Galaxy Rocket Skin", price = 79, icon = "🌌", desc = "Paint the server rocket purple-pink." },
	SkinCandy = { id = 0, name = "Candy Rocket Skin", price = 129, icon = "🍬", desc = "Paint the server rocket candy pink." },
	SkinGolden = { id = 0, name = "Golden Rocket", price = 1299, icon = "👑", desc = "A solid gold rocket. The ultimate flex." },
	PartyPopper = { id = 0, name = "Party Popper", price = 25, icon = "🎉", desc = "Confetti cannon button. Celebrate every bolt!" },
	RainbowTrail = { id = 0, name = "Rainbow Trail", price = 49, icon = "🌈", desc = "Leave a rainbow behind you." },
}

Config.Products = {
	FuelServer = { id = 0, name = "Fuel the Server", price = 99, icon = "⛽", desc = "Drones bolt on 3 parts + 2x for everyone for 2 min. Shoutout!" },
	SupplyDrop = { id = 0, name = "Call a Supply Drop", price = 149, icon = "📦", desc = "Star Crates fall from the sky for the whole server." },
	StarterPack = { id = 0, name = "Starter Pack", price = 49, icon = "🎁", desc = "Coins + Power Gloves upgrade + 15 min 3x strength.", coins = 1500, once = true },
	Boost15 = { id = 0, name = "3x Strength (15 min)", price = 39, icon = "⚡", desc = "Triple strength for 15 minutes." },
	CoinsS = { id = 0, name = "Pile of Coins", price = 25, icon = "🪙", desc = "A handful of coins.", coins = 500 },
	CoinsM = { id = 0, name = "Sack of Coins", price = 99, icon = "💰", desc = "A big sack of coins.", coins = 2500 },
	CoinsL = { id = 0, name = "Crate of Coins", price = 299, icon = "🏦", desc = "A crate full of coins.", coins = 10000 },
	CoinsXL = { id = 0, name = "Vault of Coins", price = 799, icon = "💎", desc = "A whole vault.", coins = 35000 },
}

-- UI glyphs (emoji now, swap for our own icon ids later).
Config.Icons = {
	coin = "🪙",
	strength = "💪",
	rocket = "🚀",
	shop = "🛒",
	gear = "🧤",
	index = "📖",
	crew = "🏆",
	daily = "🎁",
	fuel = "⛽",
	robot = "🤖",
	vip = "👑",
	music = "🔊",
	mute = "🔇",
	help = "🙋",
	drop = "⬇️",
	star = "⭐",
	drone = "🛸",
	jet = "🎒",
	suit = "🧑‍🚀",
	skins = "🎨",
	boost = "⚡",
	weight = "⚖️",
	people = "👥",
	popper = "🎉",
	trail = "🌈",
	box = "📦",
	lift = "✋",
	speed = "👟",
	planet = "🪐",
	quest = "🛢️",
	lock = "🔒",
	check = "✅",
	launch = "🔥",
}

-- Hero meshes (AI-generated later; 0 = not yet, primitives are used). Prompts follow PROTOCOL 4.3: shape words, no theme words.
Config.Meshes = {
	noseCone = {
		mesh = 0,
		texture = 0,
		size = V3(5, 6, 5),
		prompt = "smooth white party hat cone with a bright orange tip and two thin orange rings, perfectly round and symmetrical, flat round base, no brim",
	},
	crewBot = {
		mesh = 0,
		texture = 0,
		size = V3(3.4, 4.6, 3.4),
		prompt = "small round white helper robot with one big cyan visor, two short arms raised, floating on a round navy base, no legs, simple clean shapes",
	},
	supplyPod = {
		mesh = 0,
		texture = 0,
		size = V3(8, 10, 8),
		prompt = "round white drop pod capsule with two orange stripes, three short legs and a flat round top, simple clean shapes",
	},
}

-- Where things are inside every planet area (offsets from the planet origin).
Config.Layout = {
	spawn = V3(0, 0, -80),
	pad = V3(0, 0, 40),
	padTop = 1,
	landing = V3(-50, 0, -60),
	depot = V3(80, 0, -14),
	depotFront = V3(46, 0, -14),
	ftue = V3(-9, 0, -70), -- just left of the spawn path so it never hides the rocket
	gearKiosk = V3(32, 0, -62),
	shopKiosk = V3(26, 0, -88),
}

-- Tuning ---------------------------------------------------------------------------------------------
Config.Tune = {
	walkSpeed = 20,
	jumpPower = 50,
	baseStrength = 10,
	liftRange = 11, -- studs from the part edge
	boltRadius = 25, -- carried part inside this XZ radius of the pad centre = bolted on
	padRadius = 34,
	carryLift = 6.6, -- bottom of a carried part above the ground
	minRatio = 0.4, -- strength/weight needed to move at all
	maxHaulSpeed = 28,
	depotPads = 6,
	depotDelay = 1.2,
	strengthPerWeight = 0.06,
	coinsPerWeight = 2,
	launchBonus = 150,
	mvpBonus = 0.5,
	eventEvery = 240,
	eventWarn = 15,
	crateCount = 3,
	crateCoinMult = 6,
	boardTime = 10,
	countdown = 10,
	flightTime = 9,
	warpTime = 1.8,
	landTime = 3.4,
	soloBots = { 3, 2, 1 }, -- crew bots with 1, 2, 3 players
	botStrength = 13,
	botSpeed = 26,
	robotStrength = 25,
	offlineCapHours = 8,
	offlineRate = 0.5,
	fuelBoostSeconds = 120,
	fuelBolts = 3,
	potionSeconds = 900,
	potionMult = 3,
	vipCoin = 1.2,
	premiumCoin = 1.1,
	jetpackHaul = 1.25,
	indexBonus = 0.01,
	rankBonus = 0.05,
	questTarget = 10,
	sizeM = 4, -- players for a medium rocket
	sizeL = 13, -- players for a large rocket
	offerAfter = 180, -- no purchase prompts before this many seconds in a session
}

-- Daily login streak (coins x your best planet's coin multiplier); boost = 15 min 3x strength.
Config.Daily = {
	{ coins = 100, boost = false },
	{ coins = 220, boost = false },
	{ coins = 400, boost = true },
	{ coins = 700, boost = false },
	{ coins = 1000, boost = false },
	{ coins = 1600, boost = false },
	{ coins = 3200, boost = true },
}

-- Helpers ----------------------------------------------------------------------------------------------

-- Haul speed (WalkSpeed while carrying) from total strength / weight. 0 = too heavy, need a hand.
function Config.haulSpeed(ratio: number): number
	local T = Config.Tune
	if ratio < T.minRatio then
		return 0
	end
	local a = math.clamp((ratio - T.minRatio) / (1 - T.minRatio), 0, 1)
	local b = math.clamp((ratio - 1) / 3, 0, 1)
	return math.min(6 + 12 * a + 8 * b, T.maxHaulSpeed)
end

-- Rocket height above the pad, t seconds after liftoff.
function Config.flightHeight(t: number): number
	if t <= 0 then
		return 0
	end
	return 3.2 * t ^ 2.7
end

function Config.rank(hauled: number): (number, Rank)
	local idx = 1
	for i, r in ipairs(Config.Ranks) do
		if hauled >= r.need then
			idx = i
		end
	end
	return idx, Config.Ranks[idx]
end

function Config.sizeClass(players: number): number
	if players >= Config.Tune.sizeL then
		return 3
	elseif players >= Config.Tune.sizeM then
		return 2
	end
	return 1
end

function Config.rarity(key: string): Rarity
	return Config.RarityByKey[key] or Config.Rarity[1]
end

function Config.skin(key: string?): Skin
	for _, s in ipairs(Config.Skins) do
		if s.key == key then
			return s
		end
	end
	return Config.Skins[1]
end

function Config.planet(i: number): Planet
	return Config.Planets[math.clamp(i, 1, #Config.Planets)]
end

function Config.missionMult(mission: number): number
	return 1 + 0.5 * (math.max(mission, 1) - 1)
end

-- Coins for delivering one part (before personal multipliers).
function Config.deliverCoins(weight: number, tier: string, planet: number, mission: number): number
	local p = Config.planet(planet)
	local base = weight / p.weight -- weight already includes the planet multiplier
	return math.floor(base * Config.Tune.coinsPerWeight * Config.rarity(tier).coin * p.coins * Config.missionMult(mission) + 0.5)
end

function Config.dateKey(t: number): string
	return os.date("!%Y%m%d", t) :: string
end

function Config.gearCost(track: string, level: number): number?
	local g = Config.Gear[track]
	if not g then
		return nil
	end
	return g.cost[level + 1]
end

return Config

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
	{ key = "Pumpkin", name = "Pumpkin", icon = "🎃", body = C3(255, 132, 24), accent = C3(40, 30, 46), trim = C3(120, 50, 150), metal = C3(70, 60, 80), glow = C3(120, 255, 90), unlock = "pass", pass = "SkinPumpkin" },
	{ key = "Golden", name = "Golden", icon = "👑", body = C3(255, 206, 64), accent = C3(255, 250, 235), trim = C3(196, 130, 24), metal = C3(230, 176, 60), glow = C3(255, 244, 160), unlock = "pass", pass = "SkinGolden" },
} :: { Skin }

-- Shop -----------------------------------------------------------------------------------------------
-- Strength ladder (Build the Pyramid! sells 10 steps 29-1,499, its top step 250x): the best step counts. Every
-- step also unlocks FREE at a launch count (`launches`), so a pass is a skip: "free at 20 launches, or now".
-- Launch credit passes (x2 / x4 launches, they stack) make every launch count more toward those unlocks.
Config.Ladder = { "Str2", "Str3", "Str5", "Str8", "Str12", "Str20", "Str35", "Str60", "Str120", "Str250" }

-- Catalog: one item per line (tools/launch.py reads these lines and fills in the ids). id 0 = not created yet.
Config.Passes = {
	Str2 = { id = 0, name = "2x Strength", price = 29, icon = "💪", mult = 2, launches = 3, desc = "Permanent 2x strength now (free at 3 launches)." },
	Str3 = { id = 0, name = "3x Strength", price = 59, icon = "💪", mult = 3, launches = 8, desc = "Permanent 3x strength now (free at 8 launches)." },
	Str5 = { id = 0, name = "5x Strength", price = 99, icon = "💪", mult = 5, launches = 20, desc = "Permanent 5x strength now (free at 20 launches)." },
	Str8 = { id = 0, name = "8x Strength", price = 149, icon = "💪", mult = 8, launches = 40, desc = "Permanent 8x strength now (free at 40 launches)." },
	Str12 = { id = 0, name = "12x Strength", price = 199, icon = "💪", mult = 12, launches = 75, desc = "Permanent 12x strength now (free at 75 launches)." },
	Str20 = { id = 0, name = "20x Strength", price = 299, icon = "💪", mult = 20, launches = 130, desc = "Permanent 20x strength now (free at 130 launches)." },
	Str35 = { id = 0, name = "35x Strength", price = 449, icon = "💪", mult = 35, launches = 220, desc = "Permanent 35x strength now (free at 220 launches)." },
	Str60 = { id = 0, name = "60x Strength", price = 699, icon = "💪", mult = 60, launches = 400, desc = "Permanent 60x strength now (free at 400 launches)." },
	Str120 = { id = 0, name = "120x Strength", price = 999, icon = "💪", mult = 120, launches = 750, desc = "Permanent 120x strength now (free at 750 launches)." },
	Str250 = { id = 0, name = "250x Strength", price = 1499, icon = "💪", mult = 250, launches = 1500, desc = "Permanent 250x strength. Lift anything solo!" },
	RobotCrew = { id = 0, name = "Robot Crew", price = 299, icon = "🤖", desc = "2 robots follow you and help lift every part." },
	MegaJetpack = { id = 0, name = "Mega Jetpack", price = 149, icon = "🚀", desc = "Double jump with flames + faster hauling." },
	VIP = { id = 0, name = "VIP Window Seat", price = 399, icon = "👑", desc = "Gold window seat at launch, VIP tag, +20% coins." },
	Coins2x = { id = 0, name = "2x Coins", price = 249, icon = "💰", desc = "Double coins from every part, forever." },
	Launch2x = { id = 0, name = "x2 Launches", price = 149, icon = "🔥", launchMult = 2, desc = "Every launch counts x2 toward free strength unlocks and skins." },
	Launch4x = { id = 0, name = "x4 Launches", price = 1199, icon = "☄️", launchMult = 4, desc = "Every launch counts x4 toward free unlocks. Stacks with x2!" },
	SkinGalaxy = { id = 0, name = "Galaxy Rocket Skin", price = 79, icon = "🌌", desc = "Paint the server rocket purple-pink." },
	SkinCandy = { id = 0, name = "Candy Rocket Skin", price = 129, icon = "🍬", desc = "Paint the server rocket candy pink." },
	SkinPumpkin = { id = 0, name = "Pumpkin Rocket Skin", price = 149, icon = "🎃", desc = "Halloween! Paint the server rocket pumpkin orange with spooky green glow." },
	SkinGolden = { id = 0, name = "Golden Rocket", price = 1299, icon = "👑", desc = "A solid gold rocket. The ultimate flex." },
	PartyPopper = { id = 0, name = "Party Popper", price = 25, icon = "🎉", desc = "Confetti cannon button. Celebrate every bolt!" },
	RainbowTrail = { id = 0, name = "Rainbow Trail", price = 49, icon = "🌈", desc = "Leave a rainbow behind you." },
}

-- Products. Fields the kit reads: once, random, gift, boost (see kit/server/Shop). Game fields: coins (pack size
-- before the best-planet multiplier), intro (first purchase only), parts (drones bolt that many parts on, 0 = all
-- open slots), tier (next rocket tier), train (minutes of Zero-G training), skip (the gear level it buys).
Config.Products = {
	Intro9 = { id = 0, name = "Rookie Deal", price = 9, icon = "🎟️", desc = "First purchase only: 1,000 coins + 15 min 3x Strength.", coins = 1000, once = true, intro = true },
	StarterPack = { id = 0, name = "Starter Pack", price = 49, icon = "🎁", desc = "Coins + Power Gloves upgrade + 15 min 3x strength.", coins = 1500, once = true, window = 600 },
	Boost15 = { id = 0, name = "3x Strength (15 min)", price = 39, icon = "⚡", desc = "Triple strength for 15 minutes." },
	FuelServer = { id = 0, name = "Fuel the Server", price = 99, icon = "⛽", desc = "Drones bolt on 3 Legendary parts + 2x coins and strength for everyone for 2 min. Shoutout!" },
	SupplyDrop = { id = 0, name = "Call a Supply Drop", price = 149, icon = "📦", desc = "3 Star Crates fall from the sky for the whole server." },
	Parts3 = { id = 0, name = "+3 Rocket Parts", price = 49, icon = "🛸", desc = "Drones bolt 3 Legendary parts onto the server rocket. Shoutout!", parts = 3 },
	Parts8 = { id = 0, name = "+8 Rocket Parts", price = 149, icon = "🛸", desc = "Drones bolt 8 Legendary parts onto the server rocket. Shoutout!", parts = 8 },
	Parts20 = { id = 0, name = "+20 Rocket Parts", price = 399, icon = "🛸", desc = "20 Legendary parts, carried over to the next rocket. Shoutout!", parts = 20 },
	PartsAll = { id = 0, name = "Finish the Rocket!", price = 699, icon = "🏁", desc = "Drones fill EVERY open slot: launch the whole server now!", parts = 0 },
	NextSilver = { id = 0, name = "Next Rocket: Silver", price = 49, icon = "🥈", desc = "The next rocket is SILVER: bigger, x1.5 launch rewards for everyone.", tier = "Silver" },
	NextGold = { id = 0, name = "Next Rocket: Gold", price = 199, icon = "🥇", desc = "The next rocket is GOLD: bigger, x2.5 launch rewards for everyone.", tier = "Gold" },
	NextGalaxy = { id = 0, name = "Next Rocket: Galaxy", price = 699, icon = "🌌", desc = "The next rocket is GALAXY: biggest, x5 launch rewards for everyone.", tier = "Galaxy" },
	ZeroG1 = { id = 0, name = "Zero-G Training +1 min", price = 29, icon = "🌀", desc = "3x strength gains for everyone, 1 more minute.", train = 1 },
	ZeroG5 = { id = 0, name = "Zero-G Training +5 min", price = 99, icon = "🌀", desc = "3x strength gains for everyone, 5 more minutes.", train = 5 },
	ZeroG10 = { id = 0, name = "Zero-G Training +10 min", price = 179, icon = "🌀", desc = "3x strength gains for everyone, 10 more minutes.", train = 10 },
	ServerCoins2 = { id = 0, name = "Server 2x Coins", price = 99, icon = "💰", desc = "2x coins for EVERYONE for 15 min. Shoutout!", boost = { kind = "coins", mult = 2, minutes = 15, label = "COINS" } },
	ServerCoins4 = { id = 0, name = "Server 4x Coins", price = 249, icon = "💰", desc = "4x coins for EVERYONE for 15 min (while 2x runs).", boost = { kind = "coins", mult = 4, minutes = 15, needs = 2, label = "COINS" } },
	ServerCoins8 = { id = 0, name = "Server 8x Coins", price = 499, icon = "💰", desc = "8x coins for EVERYONE for 15 min (while 4x runs).", boost = { kind = "coins", mult = 8, minutes = 15, needs = 4, label = "COINS" } },
	ServerLuck2 = { id = 0, name = "Server 2x Luck", price = 99, icon = "🍀", desc = "2x luck for EVERYONE for 15 min: rarer depot parts and rockets.", random = true, boost = { kind = "luck", mult = 2, minutes = 15, label = "LUCK" } },
	ServerLuck4 = { id = 0, name = "Server 4x Luck", price = 249, icon = "🍀", desc = "4x luck for EVERYONE for 15 min (while 2x runs).", random = true, boost = { kind = "luck", mult = 4, minutes = 15, needs = 2, label = "LUCK" } },
	ServerStr2 = { id = 0, name = "Server Boost x2 Strength", price = 49, icon = "⚡", desc = "x2 strength for EVERYONE for 15 min. Shoutout!", boost = { kind = "strength", mult = 2, minutes = 15, label = "STRENGTH" } },
	ServerStr4 = { id = 0, name = "Server Boost x4 Strength", price = 99, icon = "⚡", desc = "x4 strength for EVERYONE for 15 min. Shoutout!", boost = { kind = "strength", mult = 4, minutes = 15, label = "STRENGTH" } },
	ServerStr8 = { id = 0, name = "Server Boost x8 Strength", price = 149, icon = "⚡", desc = "x8 strength for EVERYONE for 15 min. Shoutout!", boost = { kind = "strength", mult = 8, minutes = 15, label = "STRENGTH" } },
	ServerStr16 = { id = 0, name = "Server Boost x16 Strength", price = 249, icon = "⚡", desc = "x16 strength for EVERYONE for 15 min. Shoutout!", boost = { kind = "strength", mult = 16, minutes = 15, label = "STRENGTH" } },
	ServerStr32 = { id = 0, name = "Server Boost x32 Strength", price = 399, icon = "⚡", desc = "x32 strength for EVERYONE for 15 min. Shoutout!", boost = { kind = "strength", mult = 32, minutes = 15, label = "STRENGTH" } },
	ServerStr64 = { id = 0, name = "Server Boost x64 Strength", price = 599, icon = "⚡", desc = "x64 strength for EVERYONE for 15 min. Shoutout!", boost = { kind = "strength", mult = 64, minutes = 15, label = "STRENGTH" } },
	ServerStr128 = { id = 0, name = "Server Boost x128 Strength", price = 899, icon = "⚡", desc = "x128 strength for EVERYONE for 15 min. Shoutout!", boost = { kind = "strength", mult = 128, minutes = 15, label = "STRENGTH" } },
	ServerStr256 = { id = 0, name = "Server Boost x256 Strength", price = 1499, icon = "⚡", desc = "x256 strength for EVERYONE for 15 min. Shoutout!", boost = { kind = "strength", mult = 256, minutes = 15, label = "STRENGTH" } },
	ServerStr512 = { id = 0, name = "Server Boost x512 Strength", price = 2499, icon = "⚡", desc = "x512 strength for EVERYONE for 15 min. Shoutout!", boost = { kind = "strength", mult = 512, minutes = 15, label = "STRENGTH" } },
	ServerStr1024 = { id = 0, name = "Server Boost x1024 Strength", price = 3999, icon = "⚡", desc = "x1024 strength for EVERYONE for 15 min. The ultimate shoutout!", boost = { kind = "strength", mult = 1024, minutes = 15, label = "STRENGTH" } },
	SkipL2 = { id = 0, name = "Skip Gear Upgrade (Lv 2)", price = 15, icon = "⏩", desc = "Instantly upgrade the Gear you pick to level 2.", skip = 2 },
	SkipL3 = { id = 0, name = "Skip Gear Upgrade (Lv 3)", price = 29, icon = "⏩", desc = "Instantly upgrade the Gear you pick to level 3.", skip = 3 },
	SkipL4 = { id = 0, name = "Skip Gear Upgrade (Lv 4)", price = 49, icon = "⏩", desc = "Instantly upgrade the Gear you pick to level 4.", skip = 4 },
	SkipL5 = { id = 0, name = "Skip Gear Upgrade (Lv 5)", price = 99, icon = "⏩", desc = "Instantly upgrade the Gear you pick to level 5.", skip = 5 },
	SkipL6 = { id = 0, name = "Skip Gear Upgrade (Lv 6)", price = 179, icon = "⏩", desc = "Instantly upgrade the Gear you pick to level 6.", skip = 6 },
	SkipL7 = { id = 0, name = "Skip Gear Upgrade (Lv 7)", price = 299, icon = "⏩", desc = "Instantly upgrade the Gear you pick to level 7.", skip = 7 },
	SkipL8 = { id = 0, name = "Skip Gear Upgrade (Lv 8)", price = 549, icon = "⏩", desc = "Instantly upgrade the Gear you pick to level 8.", skip = 8 },
	CoinsS = { id = 0, name = "Pile of Coins", price = 25, icon = "💰", desc = "A handful of coins.", coins = 500 },
	CoinsM = { id = 0, name = "Sack of Coins", price = 99, icon = "💰", desc = "A big sack of coins.", coins = 2500 },
	CoinsL = { id = 0, name = "Crate of Coins", price = 299, icon = "🏦", desc = "A crate full of coins.", coins = 10000 },
	CoinsXL = { id = 0, name = "Vault of Coins", price = 799, icon = "💎", desc = "A whole vault.", coins = 35000 },
	CoinsXXLFirst = { id = 0, name = "Galaxy of Coins (40% off)", price = 1199, icon = "🌌", desc = "First time only: the biggest coin pack at 40% off.", coins = 100000, once = true },
	CoinsXXL = { id = 0, name = "Galaxy of Coins", price = 1999, icon = "🌌", desc = "The biggest coin pack in the galaxy.", coins = 100000 },
	GiftStr2 = { id = 0, name = "Gift: 2x Strength", price = 29, icon = "🎁", desc = "Gift 2x Strength to a player in your server.", gift = "Str2" },
	GiftStr3 = { id = 0, name = "Gift: 3x Strength", price = 59, icon = "🎁", desc = "Gift 3x Strength to a player in your server.", gift = "Str3" },
	GiftStr5 = { id = 0, name = "Gift: 5x Strength", price = 99, icon = "🎁", desc = "Gift 5x Strength to a player in your server.", gift = "Str5" },
	GiftStr8 = { id = 0, name = "Gift: 8x Strength", price = 149, icon = "🎁", desc = "Gift 8x Strength to a player in your server.", gift = "Str8" },
	GiftStr12 = { id = 0, name = "Gift: 12x Strength", price = 199, icon = "🎁", desc = "Gift 12x Strength to a player in your server.", gift = "Str12" },
	GiftStr20 = { id = 0, name = "Gift: 20x Strength", price = 299, icon = "🎁", desc = "Gift 20x Strength to a player in your server.", gift = "Str20" },
	GiftStr35 = { id = 0, name = "Gift: 35x Strength", price = 449, icon = "🎁", desc = "Gift 35x Strength to a player in your server.", gift = "Str35" },
	GiftStr60 = { id = 0, name = "Gift: 60x Strength", price = 699, icon = "🎁", desc = "Gift 60x Strength to a player in your server.", gift = "Str60" },
	GiftStr120 = { id = 0, name = "Gift: 120x Strength", price = 999, icon = "🎁", desc = "Gift 120x Strength to a player in your server.", gift = "Str120" },
	GiftStr250 = { id = 0, name = "Gift: 250x Strength", price = 1499, icon = "🎁", desc = "Gift 250x Strength to a player in your server.", gift = "Str250" },
	GiftRobotCrew = { id = 0, name = "Gift: Robot Crew", price = 299, icon = "🎁", desc = "Gift Robot Crew to a player in your server.", gift = "RobotCrew" },
	GiftMegaJetpack = { id = 0, name = "Gift: Mega Jetpack", price = 149, icon = "🎁", desc = "Gift Mega Jetpack to a player in your server.", gift = "MegaJetpack" },
	GiftVIP = { id = 0, name = "Gift: VIP Window Seat", price = 399, icon = "🎁", desc = "Gift VIP Window Seat to a player in your server.", gift = "VIP" },
	GiftCoins2x = { id = 0, name = "Gift: 2x Coins", price = 249, icon = "🎁", desc = "Gift 2x Coins to a player in your server.", gift = "Coins2x" },
	GiftLaunch2x = { id = 0, name = "Gift: x2 Launches", price = 149, icon = "🎁", desc = "Gift x2 Launches to a player in your server.", gift = "Launch2x" },
	GiftLaunch4x = { id = 0, name = "Gift: x4 Launches", price = 1199, icon = "🎁", desc = "Gift x4 Launches to a player in your server.", gift = "Launch4x" },
	GiftSkinGalaxy = { id = 0, name = "Gift: Galaxy Rocket Skin", price = 79, icon = "🎁", desc = "Gift the Galaxy Rocket Skin to a player in your server.", gift = "SkinGalaxy" },
	GiftSkinCandy = { id = 0, name = "Gift: Candy Rocket Skin", price = 129, icon = "🎁", desc = "Gift the Candy Rocket Skin to a player in your server.", gift = "SkinCandy" },
	GiftSkinPumpkin = { id = 0, name = "Gift: Pumpkin Rocket Skin", price = 149, icon = "🎁", desc = "Gift the Pumpkin Rocket Skin to a player in your server.", gift = "SkinPumpkin" },
	GiftSkinGolden = { id = 0, name = "Gift: Golden Rocket", price = 1299, icon = "🎁", desc = "Gift the Golden Rocket to a player in your server.", gift = "SkinGolden" },
	GiftPartyPopper = { id = 0, name = "Gift: Party Popper", price = 25, icon = "🎁", desc = "Gift the Party Popper to a player in your server.", gift = "PartyPopper" },
	GiftRainbowTrail = { id = 0, name = "Gift: Rainbow Trail", price = 49, icon = "🎁", desc = "Gift the Rainbow Trail to a player in your server.", gift = "RainbowTrail" },
}

-- Shop layout: which items each tab shows, in order (passes in the Strength / Passes / Skins tabs get a GIFT button).
Config.ShopPasses = { "RobotCrew", "VIP", "MegaJetpack", "Coins2x", "Launch2x", "Launch4x", "PartyPopper", "RainbowTrail" }
Config.ShopBoosts = {
	{ title = "SERVER BOOSTS · everyone, 15 min", keys = { "ServerCoins2", "ServerCoins4", "ServerCoins8", "ServerLuck2", "ServerLuck4" } },
	{ title = "STRENGTH FOR THE WHOLE SERVER · 15 min", keys = { "ServerStr2", "ServerStr4", "ServerStr8", "ServerStr16", "ServerStr32", "ServerStr64", "ServerStr128", "ServerStr256", "ServerStr512", "ServerStr1024" } },
	{ title = "THE ROCKET", keys = { "FuelServer", "Parts3", "Parts8", "Parts20", "PartsAll", "SupplyDrop", "NextSilver", "NextGold", "NextGalaxy" } },
	{ title = "ZERO-G TRAINING · 3x strength gains for everyone", keys = { "ZeroG1", "ZeroG5", "ZeroG10", "Boost15" } },
}
Config.ShopCoins = { "Intro9", "StarterPack", "CoinsS", "CoinsM", "CoinsL", "CoinsXL", "CoinsXXLFirst", "CoinsXXL" }

-- Rocket tiers: every new rocket rolls one (luck shifts it toward Galaxy); "Next Rocket" products pick it instead.
-- extra = extra fuel tanks (a bigger rocket), reward = launch bonus multiplier for everyone on board.
export type RocketTier = { key: string, name: string, icon: string, weight: number, reward: number, extra: number, color: Color3 }
Config.RocketTiers = {
	{ key = "Basic", name = "Basic", icon = "🚀", weight = 40, reward = 1, extra = 0, color = C3(196, 204, 214) },
	{ key = "Silver", name = "Silver", icon = "🥈", weight = 35, reward = 1.5, extra = 1, color = C3(214, 228, 255) },
	{ key = "Gold", name = "Gold", icon = "🥇", weight = 20, reward = 2.5, extra = 2, color = C3(255, 196, 40) },
	{ key = "Galaxy", name = "Galaxy", icon = "🌌", weight = 5, reward = 5, extra = 3, color = C3(170, 120, 255) },
} :: { RocketTier }

-- UI glyphs (emoji now, swap for our own icon ids later).
Config.Icons = {
	coin = "💰",
	strength = "💪",
	rocket = "🚀",
	shop = "🛒",
	gear = "🧤",
	index = "📖",
	crew = "🏆",
	daily = "📅",
	free = "🎁",
	gift = "🎁",
	luck = "🍀",
	zerog = "🌀",
	timer = "⏰",
	invite = "🤝",
	skip = "⏩",
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
		mesh = 126507582776353,
		texture = 138325314451382,
		size = V3(5, 6, 5),
		prompt = "smooth white party hat cone with a bright orange tip and two thin orange rings, perfectly round and symmetrical, flat round base, no brim",
	},
	crewBot = {
		mesh = 97514797873917,
		texture = 119030315157132,
		size = V3(3.4, 4.6, 3.4),
		prompt = "small round white helper robot with one big cyan visor, two short arms raised, floating on a round navy base, no legs, simple clean shapes",
	},
	supplyPod = {
		mesh = 103241298498288,
		texture = 118023485969993,
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
	offerAfter = 180, -- no offer popups before this many seconds in a session (never before minute 2)
	pillAfter = 120, -- the Starter Pack countdown pill shows from minute 2 of the first session
	starterWindow = 600, -- the Starter Pack is only sold in the first 10 minutes after a player's first join
	welcomeGiftAt = 45, -- seconds into a player's first session: a free coin gift (FTUE: a free gift by 60 s)
	welcomeCoins = 150, -- enough for Power Gloves level 2 (120)
	zeroGSeconds = 180, -- Zero-G training after every landing
	zeroGMult = 3, -- strength gains while Zero-G training runs
	hourlyCrates = 8, -- Star Crates in the HOURLY MEGA DROP
	hourlyBoostMinutes = 10, -- server 2x coins during the hourly event
	partsGap = 0.35, -- seconds between drone bolts for "+N Parts"
	droneTier = "Legendary", -- every drone-bolted part (fixed, never random)
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

-- Launch-week features (kit Live): codes, group gift, playtime gifts, daily quests, badges, invites, friend bonus.
-- Rewards (paid in Main.server.lua): coins = base coins x your best planet's coin multiplier (like coin packs),
-- boost = minutes of personal 3x Strength. Sized to about one session of progress.
Config.Live = {
	codes = { LAUNCH = { reward = { coins = 2000, boost = 15, text = "2,000 coins + 15 min 3x Strength" } } },
	group = { id = 0, reward = { coins = 3000, boost = 15, text = "3,000 coins + 15 min 3x Strength" } },
	playtime = {
		{ minutes = 5, reward = { coins = 300, text = "300 coins" } },
		{ minutes = 10, reward = { boost = 10, text = "10 min 3x Strength" } },
		{ minutes = 30, reward = { coins = 1500, text = "1,500 coins" } },
		{ minutes = 60, reward = { coins = 4000, boost = 15, text = "4,000 coins + 3x Strength" } },
	},
	quests = {
		{ key = "parts", text = "Bolt on 15 parts", goal = 15, reward = { coins = 800, text = "800 coins" } },
		{ key = "team", text = "Team-lift 3 parts", goal = 3, reward = { coins = 1000, text = "1,000 coins" } },
		{ key = "help", text = "Help crewmates lift 3 parts", goal = 3, reward = { coins = 1200, text = "1,200 coins" } },
		{ key = "launch", text = "Launch 2 rockets", goal = 2, reward = { coins = 1500, text = "1,500 coins" } },
		{ key = "friend", text = "Launch a rocket with a friend", goal = 1, reward = { coins = 2000, boost = 15, text = "2,000 coins + 3x Strength" } },
		{ key = "crate", text = "Haul 2 Star Crates", goal = 2, reward = { coins = 1200, text = "1,200 coins" } },
		{ key = "rare", text = "Bolt on an Epic or rarer part", goal = 1, reward = { boost = 15, text = "15 min 3x Strength" } },
		{ key = "upgrade", text = "Upgrade your Gear 3 times", goal = 3, reward = { coins = 1000, text = "1,000 coins" } },
	},
	badges = { Welcome = 0, FirstPart = 0, TeamLift = 0, FirstLaunch = 0, ReachMars = 0, ReachEuropa = 0, SecretPart = 0 },
	invite = { reward = { coins = 2500, boost = 15, text = "2,500 coins + 15 min 3x Strength" } },
	friendBonus = 0.1,
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

function Config.rocketTier(key: string?): RocketTier
	for _, t in ipairs(Config.RocketTiers) do
		if t.key == key then
			return t
		end
	end
	return Config.RocketTiers[1]
end

-- Best strength-ladder multiplier unlocked for free by this many launches (1 = none yet).
function Config.freeMult(launches: number): number
	local best = 1
	for _, key in ipairs(Config.Ladder) do
		local pass = (Config.Passes :: any)[key]
		if pass and pass.launches and launches >= pass.launches then
			best = math.max(best, pass.mult or 1)
		end
	end
	return best
end

-- Launch credit from passes (x2 and x4 stack): owns(passKey) -> boolean.
function Config.launchMult(owns: (string) -> boolean): number
	local m = 1
	for _, key in ipairs({ "Launch2x", "Launch4x" }) do
		if owns(key) then
			m *= (Config.Passes :: any)[key].launchMult or 1
		end
	end
	return m
end

return Config

-- Pop All The Balloons! 🎈  — every tuning number, palette, balloon roster, zones, shop catalog, meshes and icons.
-- Both the server and the client read this module, so the HUD always shows the same numbers the server uses.
local Config = {}

local V = Vector3.new
local RGB = Color3.fromRGB

-- The game's display name: every banner, sign and pill reads it from here, so a rename is this one line.
Config.Title = "Pop All The Balloons! 🎈"
-- The title without emoji (3D signs), e.g. "Pop All The Balloons!".
Config.TitlePlain = string.match((string.gsub(Config.Title, "[\128-\255]", "")), "^%s*(.-)%s*$") :: string
-- Story hook (first 10 seconds, the store description, boss and factory messages).
Config.Story = "The balloons are carrying the town away!"
Config.StoreName = "Balloons_v1"

---------------------------------------------------------------------------------------------------------------
-- Types
---------------------------------------------------------------------------------------------------------------

export type BalloonDef = {
	key: string,
	name: string,
	zone: number,
	tier: string,
	shape: string, -- round | heart | star | cluster | donut | cupcake | lollipop | saturn | ufo | hotair | bunch | crystal
	size: number, -- body diameter in studs
	c1: Color3,
	c2: Color3?,
	c3: Color3?,
	deco: { string }?, -- stripes | dots | face | craters | stars | bolt | halo | wings | tail | swirl | bubble | sugar | sprinkles | rainbow | angry | crown
	stripes: { Color3 }?,
	refl: number?, -- body reflectance (gold / chrome look)
	neon: boolean?, -- glowing body
	glass: boolean?,
	particles: string?, -- "sparkle" | "rainbow" | "fire" | "stars"
	light: boolean?,
	boss: boolean?, -- a zone boss (not in the Index or the spawn tables)
	value: number?, -- coins (Meadow scale) instead of the tier value
	label: string?, -- billboard title instead of the tier name
}

export type Zone = {
	key: string,
	name: string,
	glyph: string,
	groundY: number,
	center: Vector3, -- used for zone detection (x/z) together with radius
	radius: number,
	cost: number,
	hpMult: number,
	valueMult: number,
	spawn: Vector3, -- arrival / teleport point (on the ground)
	look: Vector3, -- where the arrival point faces
	gate: Vector3?, -- gate that guards this zone (on the previous zone's side)
	fields: { { number } }, -- balloon spawn circles {x, z, r}
	cap: { base: number, perPlayer: number, max: number },
	accent: Color3,
	sky: { atmo: Color3, decay: Color3, density: number, haze: number, tint: Color3, clock: number, ambient: Color3 },
}

export type Upgrade = {
	key: string,
	order: number,
	name: string,
	glyph: string,
	desc: string,
	max: number,
	costBase: number,
	costGrowth: number,
	color: string,
}

export type TierStat = { hp: number, value: number, weight: number, big: boolean }

export type BoostDef = { kind: string, mult: number, minutes: number?, needs: number?, label: string? }

-- Shop catalog item. tab: where the client shop shows a product ("items", "server", "coins"; "gift" and "trial"
-- products sit as buttons on their pass card). Kit fields: once, intro, window, random, gift, boost (see
-- kit/server/Shop).
export type CatalogItem = {
	id: number,
	name: string,
	price: number,
	glyph: string,
	desc: string,
	color: string,
	order: number,
	base: number?, -- coin packs: coins at Meadow scale (x best zone x rebirths)
	darts: number?, -- Mega Darts granted
	once: boolean?,
	intro: boolean?, -- first-purchase deal (kit refuses it once d.spent > 0)
	window: number?, -- seconds after the first join it is sold (first session only)
	random: boolean?,
	gift: string?,
	boost: BoostDef?,
	tab: string?,
	trial: string?, -- pass key this product lends for `minutes`
	minutes: number?,
}

---------------------------------------------------------------------------------------------------------------
-- Palette (one system for the whole game: pastel candy colours on near-flat ground)
---------------------------------------------------------------------------------------------------------------

Config.Palette = {
	-- house five (DESIGN.md): ground, structure, accent, rare glow, UI
	ground = RGB(142, 224, 106), -- #8EE06A meadow lawn
	structure = RGB(255, 244, 224), -- #FFF4E0 cream plaster
	accent = RGB(255, 77, 109), -- #FF4D6D balloon red-pink
	glow = RGB(255, 210, 63), -- #FFD23F gold
	ui = RGB(76, 201, 240), -- #4CC9F0 sky blue

	white = RGB(255, 255, 255),
	ink = RGB(28, 30, 48),
	string = RGB(245, 245, 250),
	gold = RGB(255, 205, 70),
	pink = RGB(255, 120, 170),
	sky = RGB(110, 200, 255),
	yellow = RGB(255, 215, 80),
	red = RGB(255, 80, 95),
	mint = RGB(120, 230, 190),
	lilac = RGB(190, 160, 255),
	orange = RGB(255, 160, 70),

	meadow = {
		grass = RGB(142, 224, 106),
		grassDark = RGB(108, 203, 82),
		sand = RGB(246, 227, 180),
		dirt = RGB(176, 138, 106),
		dirtDark = RGB(142, 110, 85),
		path = RGB(255, 241, 214),
		trunk = RGB(150, 100, 70),
		leaf1 = RGB(110, 205, 90),
		leaf2 = RGB(140, 225, 100),
		leaf3 = RGB(90, 185, 80),
		rock = RGB(200, 200, 210),
		rockDark = RGB(165, 165, 180),
	},
	candy = {
		ground = RGB(255, 179, 217), -- #FFB3D9
		groundDark = RGB(245, 144, 198),
		rim = RGB(255, 244, 230),
		mint = RGB(168, 240, 216), -- #A8F0D8
		choc = RGB(139, 90, 60), -- #8B5A3C
		chocDark = RGB(110, 68, 48),
		lemon = RGB(255, 230, 109), -- #FFE66D
		lilac = RGB(205, 180, 255), -- #CDB4FF
		cherry = RGB(255, 70, 100),
	},
	clouds = {
		ground = RGB(244, 250, 255), -- #F4FAFF
		groundShade = RGB(222, 236, 252),
		blue = RGB(189, 230, 255), -- #BDE6FF
		gold = RGB(255, 216, 107), -- #FFD86B
		under = RGB(201, 216, 236),
		underDark = RGB(169, 188, 216),
		peach = RGB(255, 200, 168),
	},
	space = {
		ground = RGB(91, 63, 168), -- #5B3FA8
		groundDark = RGB(59, 42, 122), -- #3B2A7A
		cyan = RGB(77, 240, 255), -- #4DF0FF
		pink = RGB(255, 92, 214), -- #FF5CD6
		under = RGB(42, 31, 85),
		underDark = RGB(28, 20, 64),
		star = RGB(255, 250, 220),
	},
	rainbow = {
		RGB(255, 80, 90),
		RGB(255, 160, 60),
		RGB(255, 225, 70),
		RGB(100, 220, 110),
		RGB(80, 170, 255),
		RGB(170, 110, 255),
	},
}

local P = Config.Palette

---------------------------------------------------------------------------------------------------------------
-- Rarity tiers (kit Tiers keys). hp/value are Meadow numbers; zones multiply them.
---------------------------------------------------------------------------------------------------------------

Config.TierOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
Config.TierStats = {
	Common = { hp = 1, value = 2, weight = 600, big = false },
	Uncommon = { hp = 2, value = 5, weight = 250, big = false },
	Rare = { hp = 6, value = 18, weight = 100, big = true },
	Epic = { hp = 15, value = 60, weight = 36, big = true },
	Legendary = { hp = 40, value = 250, weight = 11, big = true },
	Mythic = { hp = 100, value = 1200, weight = 2.7, big = true },
	Secret = { hp = 250, value = 10000, weight = 0.3, big = true },
} :: { [string]: TierStat }

-- Server-wide announcement when one of these spawns / is popped.
Config.AnnounceSpawnTier = 5 -- Legendary and up
Config.LabelTier = 3 -- billboard rarity label for Rare and up

---------------------------------------------------------------------------------------------------------------
-- Zones (each a floating island cluster, farther and higher than the last, visible from the previous one)
---------------------------------------------------------------------------------------------------------------

Config.Zones = {
	{
		key = "Meadow",
		name = "Meadow",
		glyph = "🌼",
		groundY = 0,
		center = V(0, 0, 10),
		radius = 150,
		cost = 0,
		hpMult = 1,
		valueMult = 1,
		spawn = V(0, 0, 92),
		look = V(0, 0, 0),
		gate = nil,
		fields = { { 0, 82, 30 }, { 88, 6, 28 }, { -88, 6, 28 }, { 54, 54, 15 }, { -54, 54, 15 }, { 52, -52, 14 }, { -52, -52, 14 } },
		cap = { base = 34, perPlayer = 8, max = 80 },
		accent = RGB(255, 120, 170),
		sky = { atmo = RGB(199, 225, 255), decay = RGB(106, 150, 210), density = 0.25, haze = 0.5, tint = RGB(255, 255, 255), clock = 14, ambient = RGB(155, 155, 165) },
	},
	{
		key = "Candy",
		name = "Candy Hills",
		glyph = "🍬",
		groundY = 30,
		center = V(0, 30, -300),
		radius = 140,
		cost = 1000,
		hpMult = 5,
		valueMult = 10,
		spawn = V(0, 30, -232),
		look = V(0, 30, -300),
		gate = V(0, 0, -84),
		fields = { { 0, -300, 32 }, { 82, -298, 24 }, { -82, -298, 24 }, { 46, -352, 12 }, { -46, -352, 12 } },
		cap = { base = 22, perPlayer = 8, max = 70 },
		accent = RGB(255, 140, 200),
		sky = { atmo = RGB(255, 215, 235), decay = RGB(230, 150, 200), density = 0.27, haze = 0.9, tint = RGB(255, 246, 250), clock = 14.5, ambient = RGB(170, 150, 165) },
	},
	{
		key = "Sky",
		name = "Sky Islands",
		glyph = "☁️",
		groundY = 80,
		center = V(0, 80, -596),
		radius = 140,
		cost = 40000,
		hpMult = 40,
		valueMult = 120,
		spawn = V(0, 80, -526),
		look = V(0, 80, -596),
		gate = V(0, 30, -378),
		fields = { { 0, -596, 32 }, { 82, -594, 24 }, { -82, -594, 24 }, { 46, -648, 12 }, { -46, -648, 12 } },
		cap = { base = 22, perPlayer = 8, max = 70 },
		accent = RGB(110, 200, 255),
		sky = { atmo = RGB(225, 240, 255), decay = RGB(150, 190, 240), density = 0.2, haze = 0.2, tint = RGB(248, 252, 255), clock = 13, ambient = RGB(165, 170, 185) },
	},
	{
		key = "Space",
		name = "Space Rainbow",
		glyph = "🌈",
		groundY = 140,
		center = V(0, 140, -890),
		radius = 150,
		cost = 1000000,
		hpMult = 300,
		valueMult = 1000,
		spawn = V(0, 140, -822),
		look = V(0, 140, -890),
		gate = V(0, 80, -674),
		fields = { { 0, -892, 34 }, { 86, -890, 26 }, { -86, -890, 26 }, { 0, -958, 20 } },
		cap = { base = 22, perPlayer = 8, max = 70 },
		accent = RGB(190, 110, 255),
		sky = { atmo = RGB(130, 100, 210), decay = RGB(50, 25, 100), density = 0.32, haze = 0.3, tint = RGB(236, 228, 255), clock = 20.6, ambient = RGB(150, 140, 200) },
	},
} :: { Zone }

-- Bridges between zones (from the gate side to the arrival side, both on the deck surface).
Config.Bridges = {
	{ from = V(0, 0, -88), to = V(0, 30, -222), width = 16 },
	{ from = V(0, 30, -382), to = V(0, 80, -516), width = 16 },
	{ from = V(0, 80, -678), to = V(0, 140, -812), width = 16 },
}

---------------------------------------------------------------------------------------------------------------
-- The hub (centre of the Meadow): Mega Pump stage, booths, pump spots, helper bots
---------------------------------------------------------------------------------------------------------------

Config.Hub = {
	center = V(0, 0, 0),
	plazaR = 32,
	stageR = 15,
	stageTop = 0.8,
	nozzleTop = 13.3, -- top of the Mega Pump nozzle (the Mega Balloon inflates here)
	megaPos = V(0, 38, 0), -- where the Mega Balloon hovers during the fight
	megaSize = 26,
	booths = {
		{ panel = "Upgrades", title = "⬆️ UPGRADES", angle = 135, color = RGB(80, 170, 255) },
		{ panel = "Shop", title = "🛒 SHOP", angle = 45, color = RGB(255, 110, 180) },
		{ panel = "Index", title = "📖 INDEX", angle = 315, color = RGB(170, 110, 255) },
		{ panel = "Rebirth", title = "🔄 REBIRTH", angle = 225, color = RGB(255, 170, 60) },
	},
	boothR = 41,
	pumpR = 48,
	botR = 11,
	pumpSpots = {} :: { Vector3 },
	botSpots = {} :: { Vector3 },
}
for q = 0, 3 do
	for _, a in ipairs({ 14, 28, 62, 76 }) do
		local ang = math.rad(q * 90 + a)
		table.insert(Config.Hub.pumpSpots, V(math.cos(ang) * Config.Hub.pumpR, 0, math.sin(ang) * Config.Hub.pumpR))
	end
end
for i = 0, 3 do
	local ang = math.rad(i * 90 + 45)
	table.insert(Config.Hub.botSpots, V(math.cos(ang) * Config.Hub.botR, Config.Hub.stageTop, math.sin(ang) * Config.Hub.botR))
end

-- Position of a booth's pad (where stepping opens its panel) and the booth itself.
function Config.boothPos(angleDeg: number, r: number): Vector3
	local a = math.rad(angleDeg)
	return V(math.cos(a) * r, 0, math.sin(a) * r)
end

---------------------------------------------------------------------------------------------------------------
-- Balloon roster: 4 zones x 7 tiers = 28 types (+ the MEGA Balloon)
---------------------------------------------------------------------------------------------------------------

Config.Balloons = {} :: { [string]: BalloonDef }
Config.ZoneTypes = {} :: { { string } } -- [zone][tierIndex] = key
Config.Order = {} :: { string } -- index order

local function B(def: BalloonDef)
	Config.Balloons[def.key] = def
	Config.ZoneTypes[def.zone] = Config.ZoneTypes[def.zone] or {}
	local ti = table.find(Config.TierOrder, def.tier) or 1
	Config.ZoneTypes[def.zone][ti] = def.key
	table.insert(Config.Order, def.key)
end

-- Meadow 🌼
B({ key = "red", name = "Red Balloon", zone = 1, tier = "Common", shape = "round", size = 3.2, c1 = RGB(255, 72, 88) })
B({ key = "polka", name = "Polka Balloon", zone = 1, tier = "Uncommon", shape = "round", size = 3.4, c1 = RGB(70, 160, 255), c2 = RGB(255, 255, 255), deco = { "dots" } })
B({ key = "striped", name = "Striped Balloon", zone = 1, tier = "Rare", shape = "round", size = 4.0, c1 = RGB(255, 214, 70), deco = { "stripes" }, stripes = { RGB(255, 105, 180), RGB(255, 105, 180), RGB(255, 105, 180) } })
B({ key = "heart", name = "Heart Balloon", zone = 1, tier = "Epic", shape = "heart", size = 4.6, c1 = RGB(255, 90, 155), refl = 0.12 })
B({ key = "star", name = "Star Balloon", zone = 1, tier = "Legendary", shape = "star", size = 5.2, c1 = RGB(255, 205, 50), refl = 0.18, particles = "sparkle", light = true })
B({ key = "golden", name = "Golden Balloon", zone = 1, tier = "Mythic", shape = "round", size = 5.6, c1 = RGB(255, 196, 45), refl = 0.38, particles = "sparkle", light = true, deco = { "stars" }, c2 = RGB(255, 250, 210) })
B({ key = "rainbow", name = "Rainbow Balloon", zone = 1, tier = "Secret", shape = "round", size = 6.2, c1 = RGB(255, 255, 255), deco = { "stripes" }, stripes = P.rainbow, particles = "rainbow", light = true })

-- Candy Hills 🍬
B({ key = "gumdrop", name = "Gumdrop Balloon", zone = 2, tier = "Common", shape = "round", size = 3.4, c1 = RGB(120, 230, 190), deco = { "face", "sugar" } })
B({ key = "bubblegum", name = "Bubblegum Balloon", zone = 2, tier = "Uncommon", shape = "round", size = 3.6, c1 = RGB(255, 140, 200), deco = { "bubble" }, refl = 0.08 })
B({ key = "lollipop", name = "Lollipop Balloon", zone = 2, tier = "Rare", shape = "lollipop", size = 4.4, c1 = RGB(255, 90, 120), c2 = RGB(255, 255, 255), c3 = RGB(255, 205, 80) })
B({ key = "cupcake", name = "Cupcake Balloon", zone = 2, tier = "Epic", shape = "cupcake", size = 4.8, c1 = RGB(255, 170, 210), c2 = RGB(120, 200, 255), c3 = RGB(255, 60, 90) })
B({ key = "donut", name = "Donut Balloon", zone = 2, tier = "Legendary", shape = "donut", size = 5.2, c1 = RGB(255, 120, 190), c2 = RGB(232, 172, 112), particles = "sparkle", light = true })
B({ key = "cotton", name = "Cotton Candy Balloon", zone = 2, tier = "Mythic", shape = "cluster", size = 6.0, c1 = RGB(255, 180, 222), c2 = RGB(165, 212, 255), particles = "sparkle", light = true })
B({ key = "sugar", name = "Sugar Crystal Balloon", zone = 2, tier = "Secret", shape = "crystal", size = 6.2, c1 = RGB(255, 170, 225), c2 = RGB(255, 240, 255), particles = "rainbow", light = true })

-- Sky Islands ☁️
B({ key = "cloud", name = "Cloud Balloon", zone = 3, tier = "Common", shape = "cluster", size = 3.8, c1 = RGB(250, 252, 255), c2 = RGB(222, 236, 255), deco = { "face" } })
B({ key = "sunny", name = "Sunny Balloon", zone = 3, tier = "Uncommon", shape = "round", size = 3.8, c1 = RGB(255, 220, 80), deco = { "face" } })
B({ key = "hotair", name = "Hot Air Balloon", zone = 3, tier = "Rare", shape = "hotair", size = 4.8, c1 = RGB(255, 120, 80), c2 = RGB(255, 232, 120), deco = { "stripes" }, stripes = { RGB(255, 232, 120), RGB(255, 232, 120) } })
B({ key = "bunch", name = "Balloon Bunch", zone = 3, tier = "Epic", shape = "bunch", size = 5.0, c1 = RGB(255, 90, 90), c2 = RGB(80, 170, 255), c3 = RGB(255, 220, 70) })
B({ key = "thunder", name = "Thunder Balloon", zone = 3, tier = "Legendary", shape = "round", size = 5.2, c1 = RGB(70, 80, 170), c2 = RGB(255, 235, 80), deco = { "bolt" }, particles = "sparkle", light = true })
B({ key = "angel", name = "Angel Balloon", zone = 3, tier = "Mythic", shape = "round", size = 5.6, c1 = RGB(255, 255, 255), c2 = RGB(255, 215, 90), deco = { "halo", "wings" }, particles = "sparkle", light = true })
B({ key = "phoenix", name = "Phoenix Balloon", zone = 3, tier = "Secret", shape = "round", size = 6.2, c1 = RGB(255, 110, 50), c2 = RGB(255, 200, 60), neon = true, deco = { "wings" }, particles = "fire", light = true })

-- Space Rainbow 🌈
B({ key = "moon", name = "Moon Balloon", zone = 4, tier = "Common", shape = "round", size = 3.8, c1 = RGB(205, 200, 235), c2 = RGB(170, 162, 210), deco = { "craters", "face" } })
B({ key = "planet", name = "Ringed Planet", zone = 4, tier = "Uncommon", shape = "saturn", size = 3.8, c1 = RGB(255, 170, 90), c2 = RGB(255, 232, 160) })
B({ key = "ufo", name = "UFO Balloon", zone = 4, tier = "Rare", shape = "ufo", size = 4.8, c1 = RGB(185, 195, 215), c2 = RGB(120, 255, 200), refl = 0.25 })
B({ key = "comet", name = "Comet Balloon", zone = 4, tier = "Epic", shape = "round", size = 4.6, c1 = RGB(90, 200, 255), c2 = RGB(200, 245, 255), deco = { "tail" }, refl = 0.1 })
B({ key = "galaxy", name = "Galaxy Balloon", zone = 4, tier = "Legendary", shape = "round", size = 5.2, c1 = RGB(70, 40, 140), c2 = RGB(255, 120, 230), deco = { "swirl", "stars" }, refl = 0.2, particles = "stars", light = true })
B({ key = "rainbowstar", name = "Rainbow Star", zone = 4, tier = "Mythic", shape = "star", size = 6.0, c1 = RGB(255, 255, 255), deco = { "rainbow" }, particles = "rainbow", light = true })
B({ key = "cosmic", name = "Cosmic Balloon", zone = 4, tier = "Secret", shape = "round", size = 6.6, c1 = RGB(45, 20, 90), c2 = RGB(255, 255, 255), deco = { "stripes", "stars" }, stripes = { RGB(255, 92, 214), RGB(77, 240, 255), RGB(255, 230, 90) }, refl = 0.3, particles = "rainbow", light = true })

-- The MEGA Balloon (server event). Built by BalloonArt at Config.Hub.megaSize.
Config.Mega = {
	key = "mega",
	name = "MEGA BALLOON",
	zone = 1,
	tier = "Secret",
	shape = "round",
	size = 6,
	c1 = RGB(255, 90, 140),
	c2 = RGB(255, 255, 255),
	deco = { "stripes", "face" },
	stripes = { RGB(255, 215, 80), RGB(110, 200, 255), RGB(255, 215, 80) },
	refl = 0.1,
	particles = "rainbow",
	light = true,
} :: BalloonDef

-- Zone bosses: popping a zone's balloons fills its "popped %" meter; at 100% its owner can summon the zone's
-- MEGA boss (a giant angry balloon with a crown). Beating it clears the zone and opens the next one for free.
-- Not in the Index or the spawn tables; Config.BossKeys[zone] = key.
Config.BossKeys = {} :: { string }
local function Boss(def: BalloonDef)
	def.boss = true
	Config.Balloons[def.key] = def
	Config.BossKeys[def.zone] = def.key
end
Boss({ key = "boss1", name = "Meadow Boss", zone = 1, tier = "Mythic", shape = "round", size = 11, c1 = RGB(255, 72, 88), deco = { "stripes", "angry", "crown" }, stripes = { RGB(255, 214, 70), RGB(255, 214, 70) }, particles = "sparkle", light = true, label = "👹 MEADOW BOSS" })
Boss({ key = "boss2", name = "Candy Boss", zone = 2, tier = "Mythic", shape = "round", size = 11.5, c1 = RGB(255, 120, 200), c2 = RGB(255, 255, 255), deco = { "dots", "angry", "crown" }, refl = 0.08, particles = "sparkle", light = true, label = "👹 CANDY BOSS" })
Boss({ key = "boss3", name = "Storm Boss", zone = 3, tier = "Mythic", shape = "round", size = 12, c1 = RGB(90, 100, 170), c2 = RGB(255, 235, 80), deco = { "bolt", "angry", "crown" }, particles = "sparkle", light = true, label = "👹 STORM BOSS" })
Boss({ key = "boss4", name = "Cosmic Boss", zone = 4, tier = "Mythic", shape = "round", size = 12.5, c1 = RGB(60, 30, 120), c2 = RGB(255, 120, 230), deco = { "swirl", "stars", "angry", "crown" }, refl = 0.2, particles = "stars", light = true, label = "👹 COSMIC BOSS" })

Config.Boss = {
	goal = { 120, 300, 500, 800 }, -- pops of a zone's own balloons that fill its meter
	value = 2500, -- coins x zone value multiplier x coin multiplier for the summoner (helpers get half)
	hpSeconds = 20, -- HP = damage per second of everyone in the zone x this
	minHp = 100, -- x zone HP multiplier
	life = 150, -- seconds before an unbeaten boss floats away (the meter stays full: summon it again)
	darts = 5, -- Mega Darts for the summoner
}

-- The secret ending: a hidden Balloon Factory behind Space Rainbow. Beat every zone's boss, then shut it down.
Config.Factory = {
	pos = V(0, 140, -1004), -- ground centre of the building (its door faces +Z, toward the zone)
	coins = 25000, -- coin pack base (x best zone x rebirths)
	darts = 50,
}

-- Hero mesh slot (AI mesh generated later in Studio). Until the ids are filled in, BalloonArt builds the
-- primitive balloon (stretched ball + knot + string + shine).
Config.Meshes = {
	balloon = {
		mesh = 79181564347447,
		texture = 0,
		size = V(3, 3.45, 3),
		prompt = "smooth round party balloon slightly taller than wide, small tied knot at the bottom, perfectly symmetrical, simple clean shape, plain white",
	},
}

---------------------------------------------------------------------------------------------------------------
-- Spawning, throwing, aura
---------------------------------------------------------------------------------------------------------------

Config.Spawn = {
	interval = 0.3, -- seconds between spawns per zone while below capacity
	catchUp = 3, -- spawns per interval when a zone is under half full
	nearPlayer = 34, -- spawns cluster within this many studs of a random player in the zone
	riseTime = 1.0,
	hoverBase = 2.6, -- body centre = ground + hoverBase + size * 0.6 + random(0, hoverJitter)
	hoverJitter = 1.8,
}

Config.Throw = {
	range = 60, -- max studs from the player to a normal balloon
	megaRange = 130,
	bucket = 4, -- burst allowance
	tolerance = 1.25, -- server accepts throws this much faster than the client cooldown (network jitter)
	bumpRange = 3.0, -- extra studs past the balloon radius that count as running into it
	helperShare = 0.5, -- coins for players who hit a balloon someone else popped
}

Config.Aura = {
	tick = 0.9,
	passTick = 0.55,
	maxPerTick = 3,
	passBonus = 6, -- extra radius with the Auto-Pop Aura pass (min radius 10 with the pass)
	passMin = 10,
}

Config.MegaDart = { mult = 25, radius = 16 }

---------------------------------------------------------------------------------------------------------------
-- Upgrades (coins). Effects are in Econ.upgradeValue.
---------------------------------------------------------------------------------------------------------------

Config.Upgrades = {
	power = { key = "power", order = 1, name = "Dart Power", glyph = "🎯", desc = "Damage per dart", max = 40, costBase = 30, costGrowth = 1.55, color = "red" },
	speed = { key = "speed", order = 2, name = "Throw Speed", glyph = "⚡", desc = "Darts per second", max = 17, costBase = 45, costGrowth = 1.75, color = "yellow" },
	aura = { key = "aura", order = 3, name = "Pop Aura", glyph = "🌀", desc = "Auto-pops small balloons near you", max = 12, costBase = 600, costGrowth = 2.0, color = "purple" },
	luck = { key = "luck", order = 4, name = "Luck", glyph = "🍀", desc = "Rarer balloons spawn near you", max = 20, costBase = 120, costGrowth = 1.8, color = "green" },
	walk = { key = "walk", order = 5, name = "Walk Speed", glyph = "👟", desc = "Run faster", max = 10, costBase = 80, costGrowth = 2.2, color = "sky" },
} :: { [string]: Upgrade }
Config.UpgradeOrder = { "power", "speed", "aura", "luck", "walk" }

Config.Rebirth = { base = 25000000, growth = 2.5, multPer = 0.5 }

-- Index: completing a zone's set (all non-Secret types) adds a permanent coin bonus; each Secret adds more.
Config.Index = {
	setBonus = { 0.10, 0.15, 0.20, 0.25 },
	setReward = { 500, 500, 500, 500 }, -- one-time coins x zone value multiplier
	secretBonus = 0.10,
}

---------------------------------------------------------------------------------------------------------------
-- The MEGA BALLOON server event
---------------------------------------------------------------------------------------------------------------

Config.Event = {
	interval = 300, -- every 5 minutes
	firstDelay = 150, -- new servers: first one 2.5 minutes after start
	countdown = 30, -- banner + countdown before it rises
	summonCountdown = 12,
	riseTime = 5,
	fightSeconds = 22, -- HP is sized so the server pops it in about this long
	minHp = 60,
	leakAfter = 32, -- after this many seconds it starts leaking so it always pops
	leakPct = 0.045, -- of max HP per second
	fightMax = 80,
	botInterval = 0.8,
	botPct = 0.005, -- each helper bot dart removes this share of max HP
	reward = 300, -- x zone value multiplier x coin multiplier, for everyone who hit it
	rainCoins = 60,
	rainValue = 15, -- per coin, x zone value multiplier x coin multiplier
	rainRadius = 50,
	rainSeconds = 28,
	showerCount = 18,
	showerLife = 32,
	showerWeights = { Rare = 60, Epic = 26, Legendary = 10, Mythic = 3.5, Secret = 0.5 } :: { [string]: number },
	-- a PAID summon bursts into this fixed set (shown before purchase): no paid random reward
	summonShower = { Rare = 10, Epic = 5, Legendary = 2, Mythic = 1 } :: { [string]: number },
	-- HOURLY MEGA BALLOON at the top of every hour (kit Live.onHour): bigger, richer, plus a server coin boost
	hourly = { hpMult = 3, rewardMult = 3, rainCoins = 100, showerCount = 36, scale = 1.35, boost = 2, boostMinutes = 10 },
}

---------------------------------------------------------------------------------------------------------------
-- Balloon Pump (passive + offline earnings), daily gift, FTUE
---------------------------------------------------------------------------------------------------------------

Config.Pump = {
	rate = 0.25, -- coins per second x zone value multiplier x rebirth multiplier
	maxHours = 8,
	fullMinutes = 10, -- pump balloon looks full after this much online filling
}

Config.Daily = {
	cooldown = 20 * 3600,
	resetAfter = 48 * 3600,
	rewards = {
		{ coins = 100 },
		{ coins = 200 },
		{ coins = 350, megaDarts = 5 },
		{ coins = 500 },
		{ coins = 750, luckMinutes = 15 },
		{ coins = 1000 },
		{ coins = 2000, megaDarts = 15 },
	} :: { { coins: number, megaDarts: number?, luckMinutes: number? } },
}

-- First minute: pop in < 5 s, a seeded Rare (first big reward) by ~25 s, the first upgrade by ~30 s, a free
-- gift at 45 s. No purchase prompt or offer before minute 2; the Starter Pack only in the first 10 minutes
-- (its catalog `window`).
Config.Ftue = {
	starterBalloons = 7, -- easy balloons spawned around a brand-new player
	rareAt = 22, -- seconds into the first session: seeded rare spawns near the player
	rareRetry = 75,
	giftAt = 45, -- free welcome gift
	gift = { megaDarts = 5 },
	offerAfter = 130, -- earliest offer popup (seconds of session); never during the MEGA event
	introAfter = 240, -- the 9 R$ Welcome Deal popup (never-bought players, after the Starter window)
	meterAfterPops = 10, -- the zone meter appears after this many pops
}

---------------------------------------------------------------------------------------------------------------
-- Shop (ids 0 until created on the website; the kit simulates purchases in Studio)
---------------------------------------------------------------------------------------------------------------

-- Every item stays on one line: tools/launch.py creates the id-0 ones from these lines.
Config.Passes = {
	Pumpkin = { id = 0, name = "Pumpkin Darts", price = 299, glyph = "🎃", desc = "HALLOWEEN! Pumpkin darts, candy pops and +20% coins forever", color = "orange", order = 0 },
	Coins2x = { id = 0, name = "2x Coins", price = 299, glyph = "💰", desc = "Double coins from every pop, forever!", color = "gold", order = 1 },
	Aura = { id = 0, name = "Auto-Pop Aura", price = 249, glyph = "🌀", desc = "Bigger, faster aura that pops BIG balloons too", color = "purple", order = 2 },
	Lucky = { id = 0, name = "Lucky Darts", price = 199, random = true, glyph = "🍀", desc = "x1.5 luck forever: rarer balloons spawn near you", color = "green", order = 3 },
	VIP = { id = 0, name = "VIP", price = 399, glyph = "👑", desc = "+25% coins, gold darts, [VIP] chat tag, 2x daily gift", color = "yellow", order = 4 },
	GoldenDart = { id = 0, name = "Golden Dart", price = 1299, glyph = "🏹", desc = "x3 dart power, golden trail + golden pops", color = "orange", order = 5 },
} :: { [string]: CatalogItem }

Config.Products = {
	-- Items tab
	Intro = { id = 0, name = "Welcome Deal", price = 9, once = true, intro = true, glyph = "🎁", desc = "A bag of coins + 10 Mega Darts. Only once, for new players!", color = "pink", order = 1, tab = "items", base = 3000, darts = 10 },
	Starter = { id = 0, name = "Starter Pack", price = 49, once = true, window = 600, glyph = "🎉", desc = "Coins + 15 Mega Darts + 30 min Lucky Boost (once)", color = "teal", order = 2, tab = "items", base = 2000, darts = 15 },
	MegaDarts = { id = 0, name = "10 Mega Darts", price = 25, glyph = "💥", desc = "Each one pops everything nearby (x25 damage)", color = "red", order = 3, tab = "items", darts = 10 },
	MegaDarts50 = { id = 0, name = "50 Mega Darts", price = 99, glyph = "💥", desc = "50 Mega Darts: pop the MEGA and bosses in seconds!", color = "red", order = 4, tab = "items", darts = 50 },
	LuckBoost = { id = 0, name = "Lucky Boost 15m", price = 49, random = true, glyph = "🍀", desc = "x2 luck for 15 minutes (stacks): rarer balloons spawn near you", color = "green", order = 5, tab = "items" },
	SummonMega = { id = 0, name = "Summon MEGA Balloon!", price = 99, glyph = "📣", desc = "MEGA BALLOON now! You get 2x its reward and it bursts into 10 Rare, 5 Epic, 2 Legendary, 1 Mythic", color = "pink", order = 6, tab = "items" },
	-- Server tab: 15-minute boosts for everyone in the server (kit Boosts), the bigger ones unlock while one runs
	Boost2x = { id = 0, name = "2x Coins Server Boost", price = 99, glyph = "⚡", desc = "2x coins for EVERYONE here for 15 minutes", color = "gold", order = 1, tab = "server", boost = { kind = "coins", mult = 2, minutes = 15, label = "COINS" } },
	Boost4x = { id = 0, name = "4x Coins Server Boost", price = 249, glyph = "⚡", desc = "4x coins for EVERYONE for 15 minutes", color = "orange", order = 2, tab = "server", boost = { kind = "coins", mult = 4, minutes = 15, needs = 2, label = "COINS" } },
	Boost8x = { id = 0, name = "8x Coins Server Boost", price = 499, glyph = "⚡", desc = "8x coins for EVERYONE for 15 minutes", color = "red", order = 3, tab = "server", boost = { kind = "coins", mult = 8, minutes = 15, needs = 4, label = "COINS" } },
	Boost16x = { id = 0, name = "16x Coins Server Boost", price = 999, glyph = "⚡", desc = "16x coins for EVERYONE for 15 minutes!", color = "purple", order = 4, tab = "server", boost = { kind = "coins", mult = 16, minutes = 15, needs = 8, label = "COINS" } },
	LuckServer2 = { id = 0, name = "2x Luck Server Boost", price = 149, random = true, glyph = "🍀", desc = "2x luck for EVERYONE for 15 minutes", color = "green", order = 5, tab = "server", boost = { kind = "luck", mult = 2, minutes = 15, label = "LUCK" } },
	LuckServer4 = { id = 0, name = "4x Luck Server Boost", price = 399, random = true, glyph = "🍀", desc = "4x luck for EVERYONE for 15 minutes", color = "teal", order = 6, tab = "server", boost = { kind = "luck", mult = 4, minutes = 15, needs = 2, label = "LUCK" } },
	-- Coins tab (scale with your best zone and rebirths)
	Coins1 = { id = 0, name = "Pile of Coins", price = 49, glyph = "💰", desc = "A pile of coins for your zone", color = "gold", order = 1, tab = "coins", base = 1500 },
	Coins2 = { id = 0, name = "Bag of Coins", price = 149, glyph = "💰", desc = "A bag of coins for your zone", color = "gold", order = 2, tab = "coins", base = 6000 },
	Coins3 = { id = 0, name = "Chest of Coins", price = 399, glyph = "👑", desc = "A whole chest of coins for your zone", color = "gold", order = 3, tab = "coins", base = 20000 },
	Coins4 = { id = 0, name = "Vault of Coins", price = 999, glyph = "🏦", desc = "A vault of coins for your zone", color = "orange", order = 4, tab = "coins", base = 60000 },
	Coins5 = { id = 0, name = "Mountain of Coins", price = 1999, glyph = "🏔️", desc = "A MOUNTAIN of coins for your zone", color = "purple", order = 5, tab = "coins", base = 150000 },
	-- Gift copies of every pass (kit Shop: pick a player in the server; GIFT button on each pass card)
	GiftPumpkin = { id = 0, name = "Gift Pumpkin Darts", price = 299, gift = "Pumpkin", glyph = "🎃", desc = "Gift Pumpkin Darts to a player in your server", color = "orange", order = 0, tab = "gift" },
	GiftCoins2x = { id = 0, name = "Gift 2x Coins", price = 299, gift = "Coins2x", glyph = "💰", desc = "Gift 2x Coins to a player in your server", color = "gold", order = 1, tab = "gift" },
	GiftAura = { id = 0, name = "Gift Auto-Pop Aura", price = 249, gift = "Aura", glyph = "🌀", desc = "Gift Auto-Pop Aura to a player in your server", color = "purple", order = 2, tab = "gift" },
	GiftLucky = { id = 0, name = "Gift Lucky Darts", price = 199, gift = "Lucky", random = true, glyph = "🍀", desc = "Gift Lucky Darts to a player in your server", color = "green", order = 3, tab = "gift" },
	GiftVIP = { id = 0, name = "Gift VIP", price = 399, gift = "VIP", glyph = "👑", desc = "Gift VIP to a player in your server", color = "yellow", order = 4, tab = "gift" },
	GiftGoldenDart = { id = 0, name = "Gift Golden Dart", price = 1299, gift = "GoldenDart", glyph = "🏹", desc = "Gift the Golden Dart to a player in your server", color = "orange", order = 5, tab = "gift" },
	-- Tool trials next to the permanent passes (TRY button on the pass card)
	TrialAura = { id = 0, name = "Auto-Pop Aura 15 min", price = 9, trial = "Aura", minutes = 15, glyph = "🌀", desc = "Try the Auto-Pop Aura for 15 minutes", color = "purple", order = 1, tab = "trial" },
	TrialCoins = { id = 0, name = "2x Coins 15 min", price = 15, trial = "Coins2x", minutes = 15, glyph = "💰", desc = "Try 2x Coins for 15 minutes", color = "gold", order = 2, tab = "trial" },
	TrialGolden = { id = 0, name = "Golden Dart 15 min", price = 19, trial = "GoldenDart", minutes = 15, glyph = "🏹", desc = "Try the Golden Dart (x3 power) for 15 minutes", color = "orange", order = 3, tab = "trial" },
} :: { [string]: CatalogItem }

-- The product that lends a pass for a while / gifts it (filled from the catalog above).
Config.TrialFor = {} :: { [string]: string } -- pass key -> trial product key
Config.GiftFor = {} :: { [string]: string } -- pass key -> gift product key
for key, item in pairs(Config.Products) do
	if item.trial then
		Config.TrialFor[item.trial] = key
	end
	if item.gift then
		Config.GiftFor[item.gift] = key
	end
end

---------------------------------------------------------------------------------------------------------------
-- Launch features (kit Live): codes, group gift, playtime gifts, daily quests, badges, invites, friend bonus.
-- Rewards: coins = packs of that base size (scaled by zone like the coin products), megaDarts, luckMinutes.
---------------------------------------------------------------------------------------------------------------

Config.Live = {
	codes = { LAUNCH = { reward = { coins = 1500, megaDarts = 5, text = "Coin bag + 5 Mega Darts" } } },
	group = { id = 0, reward = { coins = 2500, megaDarts = 10, text = "a big coin bag + 10 Mega Darts" } },
	playtime = {
		{ minutes = 5, reward = { coins = 400, text = "💰 Coin bag" } },
		{ minutes = 10, reward = { megaDarts = 5, text = "💥 5 Mega Darts" } },
		{ minutes = 30, reward = { luckMinutes = 15, text = "🍀 15 min Luck" } },
		{ minutes = 60, reward = { coins = 3000, megaDarts = 10, text = "💰 Big bag + 💥 10" } },
	},
	quests = {
		{ key = "pop", text = "Pop 150 balloons", goal = 150, reward = { coins = 800, text = "💰 Coin bag" } },
		{ key = "rare", text = "Pop 3 Rare+ balloons", goal = 3, reward = { megaDarts = 5, text = "💥 5 Mega Darts" } },
		{ key = "mega", text = "Hit the MEGA BALLOON", goal = 1, reward = { coins = 1200, text = "💰 Coin bag" } },
		{ key = "friend", text = "Play a MEGA round with a friend", goal = 1, reward = { coins = 2000, megaDarts = 5, text = "💰 + 💥 5" } },
		{ key = "upgrade", text = "Buy 5 upgrades", goal = 5, reward = { luckMinutes = 10, text = "🍀 10 min Luck" } },
		{ key = "pump", text = "Collect your Balloon Pump", goal = 1, reward = { coins = 600, text = "💰 Coin bag" } },
		{ key = "megadart", text = "Throw 5 Mega Darts", goal = 5, reward = { megaDarts = 8, text = "💥 8 Mega Darts" } },
		{ key = "bump", text = "Run into 25 balloons", goal = 25, reward = { coins = 500, text = "💰 Coin bag" } },
	},
	-- ids 0 until the badges are created (Live.badge skips them)
	badges = { Welcome = 0, FirstRare = 0, MegaPop = 0, ZoneBoss = 0, Secret = 0, Rebirth = 0, Factory = 0 },
	invite = { reward = { coins = 2000, megaDarts = 5, text = "a coin bag + 5 Mega Darts" } },
	friendBonus = 0.1,
}

---------------------------------------------------------------------------------------------------------------
-- Save data defaults
---------------------------------------------------------------------------------------------------------------

Config.Defaults = {
	coins = 0,
	total = 0,
	pops = 0,
	rebirths = 0,
	up = { power = 0, speed = 0, aura = 0, luck = 0, walk = 0 },
	zones = 1,
	index = {},
	megaDarts = 0,
	luckUntil = 0,
	daily = { last = 0, streak = 0 },
	pump = 0,
	ftue = { rare = false, upgrade = false, gift = false },
	playTime = 0,
	starter = false,
	megaPops = 0,
	meter = { 0, 0, 0, 0 }, -- pops toward each zone's boss
	bosses = { 0, 0, 0, 0 }, -- zone bosses beaten
	factory = false, -- secret ending done
	trial = {}, -- pass key -> os.time() a tool trial ends
}

---------------------------------------------------------------------------------------------------------------
-- Icons (emoji now; swap for our own icon ids later) and audio
---------------------------------------------------------------------------------------------------------------

Config.Icons = {
	coin = "💰",
	pop = "🎈",
	shop = "🛒",
	upgrades = "⬆️",
	index = "📖",
	zones = "🗺️",
	rebirth = "🔄",
	daily = "🎁",
	megaDart = "💥",
	luck = "🍀",
	music = "🔊",
	muted = "🔇",
	star = "⭐",
	lock = "🔒",
	pump = "⛽",
	mega = "🎈",
	check = "✅",
	vip = "👑",
	arrow = "👇",
	sparkle = "✨",
	clock = "⏰",
	free = "🎁",
	calendar = "📅",
	boss = "👹",
	factory = "🏭",
	pumpkin = "🎃",
	gift = "🎁",
	odds = "📊",
	house = "🏠",
}

Config.Music = { 1842976958, 1836942830, 1840434670, 1845266081, 1839807682, 1838005831 }

return Config

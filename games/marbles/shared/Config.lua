--!strict
-- Marble Mayhem: every tuning number, the palette, the marble collection, packs, power-ups, the money
-- ladder, meshes and icons. Shared by server and clients.
local Config = {}

-- The game's display name: every in-game banner, pill, sign and billboard reads it, so a rename is one line.
Config.Title = "Marble Mayhem"
Config.Tagline = "Race the Marbles!"
Config.STORE = "Marbles_v1"

local hex = Color3.fromHex

-- Palette (preset A, bright cartoon day) ----------------------------------------------------------------
Config.Palette = {
	table = hex("#F2D3A2"), -- ground: giant tabletop
	tableEdge = hex("#D79E62"),
	tableDark = hex("#B9824D"),
	structure = hex("#FFFFFF"), -- track rails / white structure
	accent = hex("#FF5AA8"), -- hot pink
	sky = hex("#42C2FF"),
	rare = hex("#FFD23F"), -- rare glow / gold
	ui = hex("#2A2D4A"), -- UI ink
	lime = hex("#7BE05A"),
	orange = hex("#FF8A3D"),
	grape = hex("#A774FF"),
	mint = hex("#4FE3C1"),
	red = hex("#FF4F5E"),
	cream = hex("#FFF4DE"),
	paper = hex("#FBFAF5"),
	ink = hex("#2A2D4A"),
	shadow = hex("#3B3F63"),
}

-- Track piece colours per theme (normal races use "Classic"; the Grand Prix uses the weekly theme).
Config.TrackThemes = {
	Classic = {
		floors = { hex("#FF5AA8"), hex("#42C2FF"), hex("#7BE05A"), hex("#FFC93C"), hex("#A774FF"), hex("#FF8A3D"), hex("#4FE3C1") },
		rail = hex("#FFFFFF"),
		pillars = { hex("#FFC93C"), hex("#42C2FF"), hex("#FF5AA8"), hex("#7BE05A") },
		accent = hex("#FFD23F"),
	},
	Candy = {
		floors = { hex("#FF8AD0"), hex("#FFFFFF"), hex("#8CF2D6"), hex("#FFB3E1"), hex("#C9A7FF") },
		rail = hex("#FF4FA3"),
		pillars = { hex("#FFFFFF"), hex("#FF4FA3") },
		accent = hex("#FF4FA3"),
	},
	Volcano = {
		floors = { hex("#FF6A2B"), hex("#3B2A2E"), hex("#FFB13B"), hex("#D93A2B") },
		rail = hex("#2A1E22"),
		pillars = { hex("#4A3438"), hex("#FF6A2B") },
		accent = hex("#FFB13B"),
	},
	Ice = {
		floors = { hex("#BDEBFF"), hex("#FFFFFF"), hex("#7FD6FF"), hex("#A6F0E6") },
		rail = hex("#5BB8FF"),
		pillars = { hex("#FFFFFF"), hex("#7FD6FF") },
		accent = hex("#E9FBFF"),
	},
	Space = {
		floors = { hex("#5B3BFF"), hex("#1F1A4A"), hex("#3BE8FF"), hex("#B04DFF") },
		rail = hex("#C9F6FF"),
		pillars = { hex("#2C2466"), hex("#3BE8FF") },
		accent = hex("#3BE8FF"),
	},
	Haunted = {
		floors = { hex("#7A3CFF"), hex("#3E9E4A"), hex("#FF8A1F"), hex("#2B2440") },
		rail = hex("#B6FF5A"),
		pillars = { hex("#2B2440"), hex("#FF8A1F") },
		accent = hex("#B6FF5A"),
	},
}

-- World layout -------------------------------------------------------------------------------------------
Config.World = {
	deckY = 64, -- lobby deck surface (top of the book tower)
	deckMinX = -48,
	deckMaxX = 48,
	deckMinZ = -50,
	deckMaxZ = 36,
	tableMinX = -500,
	tableMaxX = 290,
	tableMinZ = -270,
	tableMaxZ = 960,
	trophyPos = Vector3.new(0, 0, 905),
}

-- Tracks
Config.Tracks = {
	main = { kind = "main", x = 0, y = 65, z = 14, yaw = 0, endY = 4, length = 1150, width = 16, box = { -235, 235, 12, 880 } },
	gp = { kind = "gp", x = 0, y = 65, z = 14, yaw = 0, endY = 4, length = 1340, width = 16, box = { -235, 235, 12, 880 } },
	practice = { kind = "practice", x = -30, y = 65, z = -24, yaw = -math.pi / 2, endY = 4, length = 620, width = 16, box = { -480, -52, -255, 0 } },
	-- round modifier "Chaos Track": the same courses packed with jumps, splits and boost pads
	chaos = { kind = "main", mod = "chaos", x = 0, y = 65, z = 14, yaw = 0, endY = 4, length = 1150, width = 16, box = { -235, 235, 12, 880 } },
	gpchaos = { kind = "gp", mod = "chaos", x = 0, y = 65, z = 14, yaw = 0, endY = 4, length = 1340, width = 16, box = { -235, 235, 12, 880 } },
}

-- Round modifiers any player can buy for the next race (Chaos Track, Ice Track, Custom Round).
-- ice: slippery physics (less turn slowdown, wide drifts, slow to change speed, a little faster) on the Ice
-- theme. bigair: every marble flies off the jumps. chaos: the chaos track plus bigger random bumps.
Config.RoundMods = {
	chaos = { name = "CHAOS TRACK", glyph = "🌪️" },
	ice = { name = "ICE TRACK", glyph = "❄️" },
	bigair = { name = "BIG AIR", glyph = "🚀" },
}
Config.Ice = { turnMult = 0.35, driftMult = 2, accelMult = 0.6, speedMult = 1.1 }
Config.BigAirPeak = 5
Config.CustomThemes = { "Classic", "Candy", "Volcano", "Ice", "Space", "Haunted" }
Config.CustomModes = { "none", "chaos", "ice", "bigair" }

-- Race timing and physics-lite tuning --------------------------------------------------------------------
Config.Race = {
	simHz = 30,
	sendHz = 15,
	interpDelay = 0.2,
	pickTime = 10,
	firstPickTime = 5, -- first race after an idle server
	countdown = 3.5,
	resultsTime = 8,
	practiceForm = 3, -- seconds a warm-up heat waits for more joiners
	maxRaceTime = 80,
	afterWinner = 14, -- the rest get placed by position after this long
	minRacers = 8, -- bots fill up to this
	maxRacers = 12,
	practiceRacers = 6,
	marbleD = 3,
	-- speed model
	baseSpeed = 27, -- studs/s
	spdK = 0.62, -- per speed point
	slopeK = 30, -- extra target speed per unit of downhill slope
	accel = 9,
	decel = 14,
	turnK = 3.5, -- turn slowdown per unit curvature (scaled by grip)
	funnelSpeed = 17,
	rubber = 0.1, -- max catch-up bonus for marbles far behind
	-- boost timing
	glowDur = 1.1, -- seconds the marble glows (tap window shown to players)
	glowSlack = 0.35, -- extra server tolerance after the window
	perfectWin = 0.28, -- +/- around the glow centre for a PERFECT
	glowGapMin = 3.0,
	glowGapMax = 4.8,
	perfectBoost = 1.42,
	perfectTime = 1.7,
	goodBoost = 1.27,
	goodTime = 1.2,
	megaBoost = 1.6,
	megaTime = 2.2,
	missLock = 0.8,
	-- events
	funnelGap = 0.55, -- seconds between marbles dropping through a funnel hole
}

-- Payouts by placing (index = place). Practice heats pay less, Grand Prix pays double.
Config.Payout = {
	coins = { 100, 75, 60, 46, 38, 32, 28, 25, 22, 20, 18, 16 },
	xp = { 60, 50, 44, 38, 34, 30, 28, 26, 24, 22, 20, 18 },
	league = { 12, 9, 7, 6, 5, 4, 3, 3, 2, 2, 2, 2 },
	perfectCoins = 4,
	perfectXp = 3,
	practiceMult = 0.5,
	gpMult = 2,
	vipMult = 1.1,
}

-- Marble levels: XP to go from level L to L+1, one stat point per level, each point = +0.5 stat.
Config.Level = { max = 25, statPerPoint = 0.5, statCap = 20 }
function Config.xpNeed(level: number): number
	return math.floor(28 * level ^ 1.3)
end
Config.TuneUp = { cost = 250, xp = 120 }

-- Mutations: coin multipliers. Every pack pull also rolls PackMutations (percent weights, luck shifts them
-- toward the rarer end with the same maths as the tier roll, see kit Tiers.weights).
export type Mutation = { key: string, name: string, mult: number, color: Color3, glyph: string }
Config.Mutations = {
	{ key = "gold", name = "Gold", mult = 1.5, color = hex("#FFD23F"), glyph = "🟡" },
	{ key = "rainbow", name = "Rainbow", mult = 2, color = hex("#FF7AC8"), glyph = "🌈" },
	{ key = "cosmic", name = "Cosmic", mult = 3, color = hex("#8C52FF"), glyph = "🌌" },
} :: { Mutation }
Config.PackMutations = { { key = "none", weight = 94.75 }, { key = "gold", weight = 4 }, { key = "rainbow", weight = 1 }, { key = "cosmic", weight = 0.25 } }
Config.MutationByKey = {} :: { [string]: Mutation }
for _, m in ipairs(Config.Mutations) do
	Config.MutationByKey[m.key] = m
end

-- Shine Machine: pay coins to try a mutation on a marble you own (luck shifts the odds like packs).
-- Players under Roblox's paid random item restriction get a fixed GOLD shine for fixedCost instead.
Config.Shine = {
	cost = 2000,
	odds = { { key = "none", weight = 84.4 }, { key = "gold", weight = 12 }, { key = "rainbow", weight = 3 }, { key = "cosmic", weight = 0.6 } },
	fixedCost = 15000,
	fixedMut = "gold",
}

-- Marbles --------------------------------------------------------------------------------------------------
-- Patterns: cateye (vanes in clear glass), swirl (core + crossing bands), stripes, dots, candy (meridian
-- bands), eye, planet (core + ring), galaxy (dark core + neon specks), flame (glowing core + embers),
-- gem (glowing faceted core), rainbow, pumpkin (ribbed orange core with a glowing jack-o'-lantern face).
export type MarbleDef = {
	id: string,
	name: string,
	tier: string,
	pattern: string,
	c1: Color3,
	c2: Color3,
	c3: Color3,
	spd: number,
	grip: number,
	wt: number,
	texture: number, -- AI skin slot (generate_texture on the sphere mesh); 0 = primitive look
	exclusive: string?, -- "diamond" / "gp" / "halloween" marbles never drop from packs
	order: number,
}

local rows = {
	-- id, name, tier, pattern, c1, c2, c3, spd, grip, wt
	{ "blue", "Blue Swirl", "Common", "swirl", "#3B8BFF", "#FFFFFF", "#9ED8FF", 3, 3, 3 },
	{ "red", "Red Cat's Eye", "Common", "cateye", "#FF4040", "#FFD23F", "#FFFFFF", 4, 2, 3 },
	{ "mintdrop", "Mint Drop", "Common", "swirl", "#5BE38A", "#F0FFF5", "#2EA866", 3, 4, 2 },
	{ "sunny", "Sunny", "Common", "dots", "#FFD23F", "#FF8A3D", "#FFFFFF", 4, 3, 2 },
	{ "pebble", "Pebble", "Common", "dots", "#A9B1C2", "#5E667A", "#FFFFFF", 2, 3, 4 },
	{ "berry", "Berry Bop", "Common", "dots", "#B04DFF", "#FF7AC8", "#FFFFFF", 3, 3, 3 },
	{ "ocean", "Ocean Wave", "Common", "stripes", "#2EC4FF", "#E6FAFF", "#1F7BFF", 3, 4, 2 },
	{ "lime", "Lime Zest", "Common", "stripes", "#9BEA3A", "#FFFFFF", "#5AAE1F", 4, 3, 2 },
	{ "tango", "Tango", "Common", "cateye", "#FF8A3D", "#3B8BFF", "#FFFFFF", 3, 2, 4 },
	{ "bubble", "Bubblegum", "Common", "swirl", "#FF7AC8", "#FFFFFF", "#FFC2E6", 2, 4, 3 },
	{ "cocoa", "Cocoa", "Common", "swirl", "#8B5A3C", "#F2D2A0", "#5A3520", 3, 2, 4 },
	{ "snow", "Snowball", "Common", "dots", "#F4FAFF", "#7FCBFF", "#FFFFFF", 3, 3, 3 },
	{ "grape", "Grape Soda", "Common", "cateye", "#8C52FF", "#5BE3D8", "#FFFFFF", 4, 3, 2 },
	{ "cherry", "Cherry Pop", "Common", "stripes", "#FF3D6E", "#FFE0EA", "#B0103A", 3, 3, 3 },

	{ "beach", "Beach Ball", "Uncommon", "candy", "#FF4040", "#3B8BFF", "#FFD23F", 4, 4, 3 },
	{ "peppermint", "Peppermint", "Uncommon", "candy", "#FF3D57", "#FFFFFF", "#FF3D57", 4, 5, 2 },
	{ "toxic", "Toxic Goo", "Uncommon", "swirl", "#8CFF3A", "#2B3A10", "#D8FF9A", 5, 3, 3 },
	{ "melon", "Watermelon", "Uncommon", "dots", "#FF4F6D", "#22262E", "#7BE05A", 3, 4, 4 },
	{ "skyhop", "Sky Hopper", "Uncommon", "planet", "#7FD0FF", "#FFFFFF", "#3B8BFF", 5, 3, 3 },
	{ "bumble", "Bumble", "Uncommon", "stripes", "#FFC93C", "#2A2A35", "#FFC93C", 4, 3, 4 },
	{ "jelly", "Jellybean", "Uncommon", "cateye", "#FF5AA8", "#5BE38A", "#FFD23F", 4, 4, 3 },
	{ "frosty", "Frosty", "Uncommon", "cateye", "#BFEAFF", "#FFFFFF", "#7FD0FF", 3, 5, 3 },
	{ "tiger", "Tiger Stripe", "Uncommon", "stripes", "#FF8A1F", "#1E1E28", "#FF8A1F", 5, 2, 4 },
	{ "lagoon", "Lagoon", "Uncommon", "swirl", "#2EE6C8", "#1F7BFF", "#C2FFF4", 4, 4, 3 },
	{ "lemon", "Lemonade", "Uncommon", "dots", "#FFF05A", "#FFFFFF", "#FFC93C", 5, 3, 3 },
	{ "plum", "Plum Swirl", "Uncommon", "swirl", "#7A3CFF", "#FF8AD8", "#C9A7FF", 3, 4, 4 },
	{ "moss", "Mossy", "Uncommon", "dots", "#4CAF50", "#A8E063", "#2E6B31", 3, 3, 5 },

	{ "eyeball", "Eyeball", "Rare", "eye", "#2EA8FF", "#FFFFFF", "#15151C", 5, 4, 4 },
	{ "ringo", "Ringo", "Rare", "planet", "#FFB347", "#FFF2C2", "#FF7A1F", 5, 5, 3 },
	{ "earth", "Lil' Earth", "Rare", "dots", "#2E7BFF", "#4CD964", "#FFFFFF", 4, 5, 4 },
	{ "zebra", "Zebra", "Rare", "stripes", "#FFFFFF", "#1C1C24", "#FFFFFF", 6, 3, 4 },
	{ "prism", "Prism Eye", "Rare", "cateye", "#FF4040", "#3BFF8A", "#3B8BFF", 5, 4, 4 },
	{ "lavalamp", "Lava Lamp", "Rare", "flame", "#FF5A1F", "#3A1408", "#FFB13B", 4, 3, 6 },
	{ "aqua", "Aqua Orb", "Rare", "gem", "#3BE8FF", "#FFFFFF", "#1FA8FF", 5, 5, 3 },
	{ "rose", "Rose Quartz", "Rare", "swirl", "#FF9EC4", "#FFFFFF", "#FF5AA8", 4, 6, 3 },
	{ "storm", "Storm Cloud", "Rare", "swirl", "#5E6E8C", "#DDE6F5", "#FFE53B", 4, 4, 5 },
	{ "candycorn", "Candy Corn", "Rare", "stripes", "#FFFFFF", "#FF8A1F", "#FFD23F", 6, 4, 3 },
	{ "ladybug", "Ladybug", "Rare", "dots", "#FF2E2E", "#15151C", "#FFFFFF", 5, 5, 3 },
	{ "mintchip", "Mint Chip", "Rare", "dots", "#A8F5D0", "#4A2E1C", "#FFFFFF", 4, 5, 4 },

	{ "galaxy", "Galaxy", "Epic", "galaxy", "#1A1446", "#FFFFFF", "#B04DFF", 6, 5, 4 },
	{ "nebula", "Nebula", "Epic", "galaxy", "#3A0E5C", "#FF7AC8", "#5BE3FF", 5, 6, 4 },
	{ "dragon", "Dragon Eye", "Epic", "eye", "#FFB000", "#FFF6D0", "#2A0A00", 6, 4, 5 },
	{ "plasma", "Plasma", "Epic", "gem", "#FF3DF0", "#3BE8FF", "#FFFFFF", 7, 4, 4 },
	{ "magma", "Magma Core", "Epic", "flame", "#FF3D00", "#2A0A00", "#FFB13B", 5, 4, 6 },
	{ "emerald", "Emerald", "Epic", "gem", "#2EE67A", "#D8FFE8", "#0F8A45", 5, 6, 4 },
	{ "sapphire", "Sapphire", "Epic", "gem", "#2E6BFF", "#CFE0FF", "#1A3FA8", 6, 5, 4 },
	{ "aurora", "Aurora", "Epic", "stripes", "#5BFFB0", "#8C52FF", "#3BE8FF", 6, 5, 4 },
	{ "comet", "Comet", "Epic", "swirl", "#E8F6FF", "#3BE8FF", "#FFFFFF", 7, 5, 3 },
	{ "venom", "Venom", "Epic", "eye", "#8CFF3A", "#1A2A0A", "#FF3D57", 6, 5, 4 },

	{ "sunspark", "Sun Spark", "Legendary", "flame", "#FFD23F", "#FF8A1F", "#FFFFFF", 7, 5, 5 },
	{ "moonstone", "Moonstone", "Legendary", "planet", "#DDE6F5", "#9AA3B5", "#FFFFFF", 6, 7, 4 },
	{ "phoenix", "Phoenix", "Legendary", "flame", "#FF5A1F", "#FFD23F", "#FF3D57", 8, 4, 5 },
	{ "ruby", "Ruby Heart", "Legendary", "gem", "#FF1F4B", "#FFC0D0", "#A8002A", 6, 6, 5 },
	{ "thunder", "Thunderbolt", "Legendary", "cateye", "#FFE53B", "#3B8BFF", "#FFFFFF", 8, 5, 4 },
	{ "kraken", "Kraken Eye", "Legendary", "eye", "#1FD1C1", "#E0FFFB", "#0A2A28", 6, 6, 5 },
	{ "rainbow", "Rainbow", "Legendary", "rainbow", "#FF4040", "#3BFF8A", "#3B8BFF", 7, 6, 4 },

	{ "blackhole", "Black Hole", "Mythic", "galaxy", "#05050A", "#8C52FF", "#FF7AC8", 8, 6, 5 },
	{ "supernova", "Supernova", "Mythic", "flame", "#FFFFFF", "#FF7AC8", "#FFD23F", 9, 5, 5 },
	{ "unicorn", "Unicorn", "Mythic", "candy", "#FF9EE8", "#9EE8FF", "#FFF29E", 7, 7, 5 },
	{ "crown", "Royal Crown", "Mythic", "planet", "#FFD23F", "#B04DFF", "#FFFFFF", 7, 6, 6 },

	{ "glitch", "Glitch", "Secret", "stripes", "#00FFAA", "#FF00AA", "#0A0A14", 9, 6, 6 },
	{ "void", "The Void", "Secret", "galaxy", "#000000", "#FFFFFF", "#3BE8FF", 8, 7, 6 },

	{ "diamond", "Diamond Marble", "Secret", "gem", "#E8FBFF", "#9EE8FF", "#FFFFFF", 9, 7, 6, "diamond" },
	{ "gp_candy", "Lollipop GP", "Legendary", "candy", "#FF4FA3", "#FFFFFF", "#8CF2D6", 7, 6, 5, "gp" },
	{ "gp_volcano", "Volcano GP", "Legendary", "flame", "#FF6A2B", "#2A1E22", "#FFB13B", 8, 5, 5, "gp" },
	{ "gp_ice", "Glacier GP", "Legendary", "cateye", "#BDEBFF", "#FFFFFF", "#5BB8FF", 6, 8, 4, "gp" },
	{ "gp_space", "Starlight GP", "Legendary", "galaxy", "#1F1A4A", "#3BE8FF", "#FFFFFF", 7, 6, 5, "gp" },
	{ "gp_haunted", "Spooky GP", "Legendary", "eye", "#B6FF5A", "#2B2440", "#FF8A1F", 7, 6, 5, "gp" },
	{ "pumpkin", "Jack-o'-Marble", "Legendary", "pumpkin", "#FF8A1F", "#C2410C", "#FFE53B", 6, 6, 5, "halloween" },
}

Config.Marbles = {} :: { MarbleDef }
Config.MarbleById = {} :: { [string]: MarbleDef }
Config.MarblesByTier = {} :: { [string]: { MarbleDef } }
for i, r in ipairs(rows :: { { any } }) do
	local def: MarbleDef = {
		id = r[1],
		name = r[2],
		tier = r[3],
		pattern = r[4],
		c1 = hex(r[5]),
		c2 = hex(r[6]),
		c3 = hex(r[7]),
		spd = r[8],
		grip = r[9],
		wt = r[10],
		texture = 0,
		exclusive = r[11],
		order = i,
	}
	table.insert(Config.Marbles, def)
	Config.MarbleById[def.id] = def
	if not def.exclusive then
		local list = Config.MarblesByTier[def.tier]
		if not list then
			list = {}
			Config.MarblesByTier[def.tier] = list
		end
		table.insert(list, def)
	end
end
Config.STARTER = "blue"
Config.LOANERS = { "red", "mintdrop", "sunny", "ocean", "tango", "grape" }

-- Packs: tier odds as percent weights (shown as exact % that add up to 100, live with luck). Within a tier
-- every pack marble is equally likely. `fixed`: the tier of the fixed marble a player under the paid random
-- item restriction buys instead of a roll (coins are sold for Robux, so a coin pack is a paid random item).
export type Pack = { key: string, name: string, price: number, glyph: string, color: string, odds: { { key: string, weight: number } }, desc: string, fixed: string? }
Config.Packs = {
	{
		key = "basic",
		fixed = "Common",
		name = "Basic Pack",
		price = 150,
		glyph = "🎁",
		color = "green",
		desc = "Mostly Commons, a shot at Rares.",
		odds = { { key = "Common", weight = 62 }, { key = "Uncommon", weight = 28 }, { key = "Rare", weight = 8 }, { key = "Epic", weight = 1.7 }, { key = "Legendary", weight = 0.28 }, { key = "Mythic", weight = 0.02 } },
	},
	{
		key = "shiny",
		fixed = "Uncommon",
		name = "Shiny Pack",
		price = 750,
		glyph = "💎",
		color = "blue",
		desc = "Better odds: Uncommon and up.",
		odds = { { key = "Common", weight = 30 }, { key = "Uncommon", weight = 38 }, { key = "Rare", weight = 22 }, { key = "Epic", weight = 8 }, { key = "Legendary", weight = 1.8 }, { key = "Mythic", weight = 0.19 }, { key = "Secret", weight = 0.01 } },
	},
	{
		key = "mega",
		fixed = "Rare",
		name = "Mega Pack",
		price = 3000,
		glyph = "🌟",
		color = "purple",
		desc = "Rare and up. Mythics live here.",
		odds = { { key = "Uncommon", weight = 30 }, { key = "Rare", weight = 40 }, { key = "Epic", weight = 22 }, { key = "Legendary", weight = 6.5 }, { key = "Mythic", weight = 1.3 }, { key = "Secret", weight = 0.2 } },
	},
	{
		key = "galaxy",
		fixed = "Epic",
		name = "Galaxy Pack",
		price = 12000,
		glyph = "🌌",
		color = "pink",
		desc = "Epic-heavy. Best Secret odds.",
		odds = { { key = "Rare", weight = 40 }, { key = "Epic", weight = 38 }, { key = "Legendary", weight = 17 }, { key = "Mythic", weight = 4.2 }, { key = "Secret", weight = 0.8 } },
	},
	{
		key = "welcome",
		name = "Welcome Pack",
		price = 0,
		glyph = "🎉",
		color = "orange",
		desc = "Free! Guaranteed Rare or better.",
		odds = { { key = "Rare", weight = 80 }, { key = "Epic", weight = 18 }, { key = "Legendary", weight = 2 } },
	},
} :: { Pack }
Config.PackByKey = {} :: { [string]: Pack }
for _, p in ipairs(Config.Packs) do
	Config.PackByKey[p.key] = p
end
Config.LuckBoostMult = 2 -- luck while a personal Luck Boost runs (packs, pack mutations and shines)
Config.LuckyCharmMult = 1.25 -- permanent pass
-- Server luck boosts (kit Boosts kind "luck") multiply on top of both.

-- One marble of `tier` picked per UTC day (the same on server and every client). salt separates slots.
function Config.dayPick(tier: string, day: number, salt: number): string
	local list = Config.MarblesByTier[tier] or Config.MarblesByTier.Common
	return list[Random.new(day * 131 + salt):NextInteger(1, #list)].id
end

-- Fixed marble a restricted player gets from a coin pack today.
function Config.fixedMarble(packKey: string, day: number): string
	local pack = Config.PackByKey[packKey]
	return Config.dayPick(pack and pack.fixed or "Common", day, #packKey * 17)
end

-- Rotating daily deals: a marble of each tier for Robux, new every UTC day (fixed, shown before buying).
Config.Deals = {
	{ product = "DealRare", tier = "Rare", salt = 1 },
	{ product = "DealEpic", tier = "Epic", salt = 2 },
	{ product = "DealLegendary", tier = "Legendary", salt = 3 },
	{ product = "DealMythic", tier = "Mythic", salt = 4 },
}
Config.StarterMarble = "comet" -- the Epic in the Starter Pack (fixed, so every player may buy it)
Config.StarterWindow = 600 -- seconds after a player's first join that the Starter Pack is on sale (= its `window`)

-- Power-up cards: pick one per race (two with the pass).
export type Card = { key: string, name: string, glyph: string, color: string, desc: string, good: string }
Config.Cards = {
	{ key = "boost", name = "Turbo", glyph = "🚀", color = "orange", desc = "Your first BOOST is a MEGA boost.", good = "pads" },
	{ key = "magnet", name = "Magnet", glyph = "🧲", color = "red", desc = "Mid-race: pulled along behind the marble ahead.", good = "turns" },
	{ key = "sticky", name = "Sticky", glyph = "🍯", color = "yellow", desc = "Grips turns, stairs and bumpers at full speed.", good = "stairs" },
	{ key = "bounce", name = "Bounce", glyph = "🏀", color = "pink", desc = "Huge air on jumps; landings speed you up.", good = "jumps" },
} :: { Card }
Config.CardByKey = {} :: { [string]: Card }
for _, c in ipairs(Config.Cards) do
	Config.CardByKey[c.key] = c
end
Config.Magnet = { at = 0.35, time = 6, bonus = 1.15 }

-- Daily login rewards (7-day streak, then repeats).
Config.Daily = {
	{ kind = "coins", amount = 250, text = "250 Coins" },
	{ kind = "coins", amount = 500, text = "500 Coins" },
	{ kind = "pack", pack = "basic", amount = 2, text = "2 Basic Packs" },
	{ kind = "coins", amount = 1000, text = "1,000 Coins" },
	{ kind = "pack", pack = "shiny", amount = 1, text = "Shiny Pack" },
	{ kind = "coins", amount = 2500, text = "2,500 Coins" },
	{ kind = "pack", pack = "mega", amount = 1, text = "Mega Pack" },
}

-- Daily league: points from every race, tier rewards, global top board.
Config.League = {
	tiers = {
		{ key = "Bronze", pts = 20, color = "orange", reward = { kind = "coins", amount = 300 }, text = "300 Coins" },
		{ key = "Silver", pts = 60, color = "grey", reward = { kind = "pack", pack = "shiny", amount = 1 }, text = "Shiny Pack" },
		{ key = "Gold", pts = 120, color = "gold", reward = { kind = "pack", pack = "mega", amount = 1 }, text = "Mega Pack" },
		{ key = "Diamond", pts = 220, color = "sky", reward = { kind = "pack", pack = "galaxy", amount = 1 }, text = "Galaxy Pack + Trophy" },
	},
	boardSize = 10,
	refresh = 60,
}

-- Index milestones: discovering marbles pays out.
Config.IndexRewards = {
	{ count = 5, kind = "coins", amount = 500, text = "500 Coins" },
	{ count = 10, kind = "pack", pack = "shiny", amount = 1, text = "Shiny Pack" },
	{ count = 20, kind = "coins", amount = 3000, text = "3,000 Coins" },
	{ count = 30, kind = "pack", pack = "mega", amount = 1, text = "Mega Pack" },
	{ count = 45, kind = "pack", pack = "galaxy", amount = 1, text = "Galaxy Pack" },
	{ count = 60, kind = "coins", amount = 50000, text = "50,000 Coins" },
}

-- Offline practice-track earnings.
Config.Offline = { perMinute = 3, perMarble = 0.4, maxHours = 8, minMinutes = 3 }

-- Grand Prix: the recurring server event. Every few minutes the next race is a Grand Prix on a longer
-- themed track: double coins and league points, and the winner takes the week's limited marble.
Config.GrandPrix = {
	interval = 300,
	firstAfter = 240,
	themes = {
		{ key = "Candy", name = "Candy Land", marble = "gp_candy", tint = hex("#FFE3F3"), music = 1840434670 },
		{ key = "Volcano", name = "Volcano Run", marble = "gp_volcano", tint = hex("#FFE0CC"), music = 1845266081 },
		{ key = "Ice", name = "Ice Palace", marble = "gp_ice", tint = hex("#E3F6FF"), music = 1839807682 },
		{ key = "Space", name = "Space Loop", marble = "gp_space", tint = hex("#E6E0FF"), music = 1838005831 },
		{ key = "Haunted", name = "Haunted Halls", marble = "gp_haunted", tint = hex("#ECE0FF"), music = 1836942830 },
	},
	runnerUpChance = 0.3,
	-- Hourly Grand Prix (kit Live.onHour, at :00 UTC): 3x coins and points, the top 3 all take the GP marble,
	-- and a 10-minute 2x coins boost for the whole server.
	hourlyMult = 3,
	hourlyBoost = { mult = 2, minutes = 10 },
}
-- Halloween (UTC month/day window): Haunted Halls is the Grand Prix theme and the 🎃 bundle is on sale.
Config.Halloween = { from = 1001, to = 1102 }
function Config.isHalloween(now: number): boolean
	local t = os.date("!*t", now)
	local md = t.month * 100 + t.day
	return md >= Config.Halloween.from and md <= Config.Halloween.to
end
-- Week index (Saturday rollover) picks the theme.
function Config.gpTheme(now: number): { [string]: any }
	local list = Config.GrandPrix.themes
	if Config.isHalloween(now) then
		return list[#list]
	end
	local week = math.floor((now - 2 * 86400) / 604800)
	return list[(week % #list) + 1]
end

-- Trails (cosmetic, shown behind your marble in races).
Config.Trails = {
	{ key = "sparkle", name = "Sparkle Trail", colors = { hex("#FFFFFF"), hex("#9EE8FF") }, product = "TrailSparkle" },
	{ key = "flame", name = "Flame Trail", colors = { hex("#FFD23F"), hex("#FF3D00") }, product = "TrailFlame" },
	{ key = "rainbow", name = "Rainbow Trail", colors = { hex("#FF4040"), hex("#FFD23F"), hex("#3BFF8A"), hex("#3B8BFF"), hex("#B04DFF") }, product = "TrailRainbow" },
	{ key = "gold", name = "VIP Gold Trail", colors = { hex("#FFF2A8"), hex("#FFB800") }, pass = "VIP" },
	{ key = "spooky", name = "Spooky Trail", colors = { hex("#FF8A1F"), hex("#8C52FF"), hex("#B6FF5A") }, product = "PumpkinMarble" },
}
Config.TrailByKey = {} :: { [string]: { [string]: any } }
for _, t in ipairs(Config.Trails) do
	Config.TrailByKey[t.key] = t
end

-- Money ladder. ids are 0 until tools/launch.py creates them; the kit simulates purchases in Studio.
-- Keep every item on ONE line (tools/launch.py parses these lines). Product names must be unique.
-- random = true: a paid random item (or it changes a random roll): kit Shop refuses it for players under
-- Roblox's paid random item restriction, and the client hides it for them.
Config.Passes = {
	CoinsX2 = { id = 0, name = "2x Coins", price = 249, glyph = "💰", desc = "Double coins from every race, forever." },
	PowerSlot = { id = 0, name = "Extra Power-Up Slot", price = 149, glyph = "🃏", desc = "Pick TWO power-up cards every race." },
	VIP = { id = 0, name = "VIP", price = 399, glyph = "👑", desc = "Gold trail, +10% coins and a VIP tag." },
	TripleOpen = { id = 0, name = "Triple Open", price = 199, glyph = "🎰", desc = "Open 3 packs at once." },
	LuckyCharm = { id = 0, name = "Lucky Charm", price = 299, glyph = "🍀", random = true, desc = "+25% luck on packs and shines, forever." },
}
Config.Products = {
	IntroEpic = { id = 0, name = "Random Epic Marble", price = 9, once = true, intro = true, random = true, glyph = "🎲", desc = "First-buy deal: one random Epic marble. Once per player." },
	IntroEpicFixed = { id = 0, name = "First-Buy Epic Marble", price = 9, once = true, intro = true, glyph = "🎁", desc = "First-buy deal: today's Epic marble. Once per player." },
	StarterPack = { id = 0, name = "Starter Pack", price = 49, once = true, window = 600, glyph = "🎒", desc = "3,000 coins + Comet (Epic marble) + Sparkle Trail. Once!" },
	CoinsS = { id = 0, name = "1,500 Coins", price = 29, glyph = "💰", desc = "A pocket of coins." },
	CoinsM = { id = 0, name = "8,000 Coins", price = 99, glyph = "💰", desc = "A bag of coins." },
	CoinsL = { id = 0, name = "50,000 Coins", price = 449, glyph = "🏦", desc = "A vault of coins." },
	CoinsXL = { id = 0, name = "125,000 Coins", price = 999, glyph = "🏦", desc = "A mountain of coins." },
	CoinsXXL = { id = 0, name = "300,000 Coins", price = 1999, glyph = "👑", desc = "A whole bank of coins. Best value!" },
	LuckBoost = { id = 0, name = "Luck Boost (15 min)", price = 39, random = true, glyph = "🍀", desc = "2x luck on packs, mutations and shines for 15 minutes." },
	GalaxyPack = { id = 0, name = "Galaxy Pack", price = 99, random = true, glyph = "🌌", desc = "One Galaxy Pack, opened right away." },
	DealRare = { id = 0, name = "Daily Rare Marble", price = 49, glyph = "🔵", desc = "Today's Rare marble. New deal every day." },
	DealEpic = { id = 0, name = "Daily Epic Marble", price = 149, glyph = "🟣", desc = "Today's Epic marble. New deal every day." },
	DealLegendary = { id = 0, name = "Daily Legendary Marble", price = 599, glyph = "🟡", desc = "Today's Legendary marble. New deal every day." },
	DealMythic = { id = 0, name = "Daily Mythic Marble", price = 799, glyph = "🔴", desc = "Today's Mythic marble. New deal every day." },
	ServerCoins2 = { id = 0, name = "2x Coins for Everyone", price = 99, glyph = "⚡", boost = { kind = "coins", mult = 2, minutes = 15, label = "COINS" }, desc = "2x race coins for the whole server for 15 minutes." },
	ServerCoins4 = { id = 0, name = "4x Coins for Everyone", price = 249, glyph = "⚡", boost = { kind = "coins", mult = 4, minutes = 15, needs = 2, label = "COINS" }, desc = "4x race coins for the whole server. Unlocks while 2x runs." },
	ServerCoins8 = { id = 0, name = "8x Coins for Everyone", price = 499, glyph = "⚡", boost = { kind = "coins", mult = 8, minutes = 15, needs = 4, label = "COINS" }, desc = "8x race coins for the whole server. Unlocks while 4x runs." },
	ServerLuck2 = { id = 0, name = "2x Luck for Everyone", price = 149, random = true, glyph = "🍀", boost = { kind = "luck", mult = 2, minutes = 15, label = "LUCK" }, desc = "2x pack and shine luck for the whole server for 15 minutes." },
	ServerLuck4 = { id = 0, name = "4x Luck for Everyone", price = 349, random = true, glyph = "🍀", boost = { kind = "luck", mult = 4, minutes = 15, needs = 2, label = "LUCK" }, desc = "4x luck for the whole server. Unlocks while 2x luck runs." },
	StartGP = { id = 0, name = "Start a Grand Prix!", price = 99, glyph = "🏁", desc = "The next race is a Grand Prix for the whole server." },
	ChaosTrack = { id = 0, name = "Chaos Track", price = 25, glyph = "🌪️", desc = "The next race is a CHAOS TRACK: jumps, splits and bumps everywhere!" },
	IceTrack = { id = 0, name = "Ice Track", price = 55, glyph = "❄️", desc = "The next race is on slippery ICE. Marbles slide and drift!" },
	CustomRound = { id = 0, name = "Custom Round", price = 99, glyph = "🎨", desc = "You pick the next race's theme and mode for the whole server." },
	KeepStreak = { id = 0, name = "Keep My Streak", price = 19, glyph = "🔥", desc = "Missed a day? Keep your daily login streak." },
	TrailSparkle = { id = 0, name = "Sparkle Trail", price = 15, glyph = "✨", desc = "A sparkly trail behind your marble." },
	TrailFlame = { id = 0, name = "Flame Trail", price = 35, glyph = "🔥", desc = "Leave fire on the track." },
	TrailRainbow = { id = 0, name = "Rainbow Trail", price = 49, glyph = "🌈", desc = "Every colour, every race." },
	PumpkinMarble = { id = 0, name = "Jack-o'-Marble Bundle", price = 349, once = true, glyph = "🎃", desc = "Halloween only: the glowing Jack-o'-Marble + Spooky Trail." },
	DiamondMarble = { id = 0, name = "Diamond Marble", price = 1299, glyph = "💎", desc = "The rarest marble. Sparkles. Fast." },
	GiftCoinsX2 = { id = 0, name = "Gift: 2x Coins", price = 249, gift = "CoinsX2", glyph = "🎁", desc = "Gift the 2x Coins pass to a player in your server." },
	GiftPowerSlot = { id = 0, name = "Gift: Extra Power-Up Slot", price = 149, gift = "PowerSlot", glyph = "🎁", desc = "Gift the Extra Power-Up Slot pass to a player in your server." },
	GiftVIP = { id = 0, name = "Gift: VIP", price = 399, gift = "VIP", glyph = "🎁", desc = "Gift the VIP pass to a player in your server." },
	GiftTripleOpen = { id = 0, name = "Gift: Triple Open", price = 199, gift = "TripleOpen", glyph = "🎁", desc = "Gift the Triple Open pass to a player in your server." },
	GiftLuckyCharm = { id = 0, name = "Gift: Lucky Charm", price = 299, gift = "LuckyCharm", random = true, glyph = "🎁", desc = "Gift the Lucky Charm pass to a player in your server." },
}
Config.LuckBoostSeconds = 900
Config.NoOffersBefore = 150 -- seconds of play before any purchase popup (at least 2 minutes, every session)
Config.OfferGap = 360 -- seconds between purchase popups

-- Launch features (kit Live): codes, group gift, playtime gifts, daily quests, badges, invites, friend bonus.
-- Reward tables: coins, packs = { packKey = n }, luckMinutes; `text` is what the FREE panel shows.
-- Quest keys the game reports with Live.quest: race, podium, win, perfect, pack, gp, shine, friend.
Config.Live = {
	codes = { LAUNCH = { reward = { coins = 1000, packs = { shiny = 1 }, text = "1,000 coins + Shiny Pack" } } },
	group = { id = 0, reward = { packs = { mega = 1 }, text = "a Mega Pack" } },
	playtime = {
		{ minutes = 5, reward = { coins = 300, text = "300 coins" } },
		{ minutes = 10, reward = { packs = { basic = 2 }, text = "2 Basic Packs" } },
		{ minutes = 30, reward = { packs = { shiny = 1 }, luckMinutes = 10, text = "Shiny Pack + 10m Luck" } },
		{ minutes = 60, reward = { coins = 2000, packs = { mega = 1 }, text = "Mega Pack + 2,000 coins" } },
	},
	quests = {
		{ key = "race", text = "Finish 5 races", goal = 5, reward = { coins = 500, text = "500 coins" } },
		{ key = "podium", text = "Finish top 3 three times", goal = 3, reward = { packs = { basic = 2 }, text = "2 Basic Packs" } },
		{ key = "win", text = "Win a race", goal = 1, reward = { coins = 800, text = "800 coins" } },
		{ key = "perfect", text = "Hit 15 PERFECT boosts", goal = 15, reward = { packs = { shiny = 1 }, text = "Shiny Pack" } },
		{ key = "pack", text = "Open 5 packs", goal = 5, reward = { coins = 600, text = "600 coins" } },
		{ key = "gp", text = "Race in a Grand Prix", goal = 1, reward = { packs = { shiny = 1 }, text = "Shiny Pack" } },
		{ key = "shine", text = "Use the Shine Machine", goal = 1, reward = { coins = 1000, text = "1,000 coins" } },
		{ key = "friend", text = "Race with a friend in the server", goal = 1, reward = { packs = { mega = 1 }, text = "Mega Pack" } },
	},
	badges = { Welcome = 0, FirstRace = 0, FirstWin = 0, Wins10 = 0, GPWin = 0, Legendary = 0, Index30 = 0 },
	invite = { reward = { packs = { shiny = 1 }, text = "a Shiny Pack" } },
	friendBonus = 0.1,
}

-- Hero mesh slot: one sphere mesh; every marble def has its own texture slot (def.texture).
Config.Meshes = {
	Marble = { mesh = 83290749954823, texture = 0, size = Vector3.new(3, 3, 3), prompt = "perfectly round smooth sphere, simple clean shape, no details" },
	Trophy = { mesh = 132816977831168, texture = 109122908686377, size = Vector3.new(60, 90, 60), prompt = "simple trophy cup with two round handles on a short square base, smooth" },
}

-- Emoji icons (swap for our own icon ids later).
Config.Icons = {
	coins = "💰",
	trophy = "🏆",
	marble = "🔮",
	marbles = "🔮",
	pack = "📦",
	shine = "✨",
	league = "🏅",
	shop = "🛒",
	daily = "📅",
	gift = "🎁",
	boost = "⚡",
	camera = "🎥",
	music = "🎵",
	mute = "🔇",
	gp = "🏁",
	luck = "🍀",
	x2 = "💰",
	vip = "👑",
	star = "⭐",
	lock = "🔒",
	check = "✅",
	bot = "🤖",
	speed = "💨",
	grip = "🧲",
	weight = "⚖️",
	level = "⬆️",
	xp = "✨",
	sleep = "💤",
	arrow = "👇",
	fire = "🔥",
	photo = "📸",
}

-- Licensed music (kit-approved ids).
Config.Music = { 1842976958, 1836942830, 1840434670, 1845266081, 1839807682, 1838005831 }

Config.BotNames = {
	"RollyPolly", "MarbleMax", "Glassy", "Swirlz", "PebblePete", "Clacker", "SpinCycle", "Bouncy_Bea", "TurboTina",
	"Mibsy", "Shooter", "Aggie", "Cat'sEyeCal", "RingTaw", "DizzyDot", "Zoomer", "Plinko", "Ricochet", "Gumball",
	"SirRollsALot", "Bumper", "Skippy", "Jumbo", "Steelie",
}

return Config

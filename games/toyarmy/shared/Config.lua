-- Toy Army ⚔️ : every tuning number, the palette, units, bags, zones, upgrades, ranks, the money ladder,
-- hero-mesh slots and UI glyphs. Shared by the server and the client.
local Config = {}

Config.Name = "Toy Army ⚔️"
Config.Title = "Deploy the Toy Army! ⚔️"
Config.Store = "ToyArmy_v1"

local rgb = Color3.fromRGB

-- Palette (DESIGN.md art bible): honey floor, sky wallpaper, toy green, toy tan, rare gold, UI ink.
Config.C = {
	floor = rgb(226, 178, 118),
	floorSeam = rgb(204, 156, 100),
	wall = rgb(174, 212, 240),
	wallTop = rgb(196, 226, 247),
	trim = rgb(250, 246, 238),
	ceiling = rgb(252, 249, 242),
	rugOuter = rgb(92, 164, 232),
	rugRing = rgb(250, 250, 252),
	rugInner = rgb(150, 206, 246),
	rugCenter = rgb(255, 212, 82),
	bed = rgb(112, 172, 234),
	blanket = rgb(84, 196, 186),
	blanketStripe = rgb(255, 236, 160),
	sheet = rgb(250, 250, 252),
	wood = rgb(214, 150, 92),
	woodDark = rgb(168, 108, 62),
	white = rgb(250, 250, 250),
	ink = rgb(28, 30, 48),
	red = rgb(236, 72, 66),
	orange = rgb(255, 150, 52),
	yellow = rgb(255, 208, 62),
	blue = rgb(72, 142, 236),
	purple = rgb(160, 112, 236),
	pink = rgb(255, 146, 186),
	teal = rgb(56, 200, 186),
	lime = rgb(150, 220, 70),
	brown = rgb(150, 98, 60),
	grey = rgb(170, 176, 188),
	-- armies
	green = rgb(72, 180, 62),
	greenDark = rgb(38, 116, 40),
	tan = rgb(224, 186, 114),
	tanDark = rgb(166, 128, 70),
	wild = rgb(160, 166, 178),
	wildDark = rgb(104, 110, 124),
	gold = rgb(255, 198, 44),
	goldDark = rgb(208, 140, 22),
	glow = rgb(196, 255, 176),
	glowDark = rgb(110, 255, 120),
	metal = rgb(178, 188, 204),
	metalDark = rgb(104, 114, 136),
	-- cat
	catFur = rgb(246, 162, 72),
	catStripe = rgb(214, 116, 40),
	catCream = rgb(255, 238, 210),
	catPink = rgb(255, 150, 170),
	catEye = rgb(120, 220, 90),
}

-- Teams -----------------------------------------------------------------------------------------------
export type TeamDef = {
	key: string,
	name: string,
	short: string,
	color: Color3,
	dark: Color3,
	brick: string,
	ai: string,
	side: number,
}
Config.TeamKeys = { "Green", "Tan" }
Config.Team = {
	Green = { key = "Green", name = "Green Army", short = "GREEN", color = Config.C.green, dark = Config.C.greenDark, brick = "Bright green", ai = "Sgt. Sprout 🤖", side = -1 },
	Tan = { key = "Tan", name = "Tan Army", short = "TAN", color = Config.C.tan, dark = Config.C.tanDark, brick = "Brick yellow", ai = "Captain Crumbs 🤖", side = 1 },
} :: { [string]: TeamDef }

function Config.enemy(team: string): string
	return team == "Green" and "Tan" or "Green"
end

function Config.teamColor(team: string?): Color3
	local t = team and Config.Team[team]
	return t and t.color or Config.C.wild
end

-- Units ------------------------------------------------------------------------------------------------
export type UnitDef = {
	key: string,
	name: string,
	tier: string,
	atk: number,
	hp: number,
	merge: number, -- seconds to mold this unit from 3 of the tier below
	special: string,
	glyph: string,
	desc: string,
	scale: number,
}
Config.Units = {
	{ key = "Rifleman", name = "Rifleman", tier = "Common", atk = 10, hp = 30, merge = 0, special = "", glyph = "🪖", desc = "Pew pew! The classic.", scale = 1 },
	{ key = "Bazooka", name = "Bazooka", tier = "Uncommon", atk = 34, hp = 100, merge = 4, special = "splash", glyph = "💥", desc = "Blasts two toys at once.", scale = 1 },
	{ key = "Medic", name = "Medic", tier = "Rare", atk = 105, hp = 330, merge = 12, special = "heal", glyph = "⛑️", desc = "Patches up the squad.", scale = 1.05 },
	{ key = "Tank", name = "Tank", tier = "Epic", atk = 360, hp = 1150, merge = 30, special = "armor", glyph = "🛡️", desc = "Armored: takes 30% less.", scale = 1 },
	{ key = "Heli", name = "Helicopter", tier = "Legendary", atk = 1250, hp = 3900, merge = 90, special = "air", glyph = "🚁", desc = "Strafes two targets.", scale = 1 },
	{ key = "General", name = "Golden General", tier = "Mythic", atk = 4300, hp = 13500, merge = 240, special = "rally", glyph = "🎖️", desc = "Rally: squad +20% attack.", scale = 1.2 },
	{ key = "Dino", name = "Robot Dino", tier = "Secret", atk = 15500, hp = 50000, merge = 600, special = "stomp", glyph = "🦖", desc = "STOMP: hits three toys.", scale = 1 },
} :: { UnitDef }
Config.UnitByKey = {} :: { [string]: UnitDef }
Config.UnitIndex = {} :: { [string]: number }
for i, u in ipairs(Config.Units) do
	Config.UnitByKey[u.key] = u
	Config.UnitIndex[u.key] = i
end

function Config.nextUnit(key: string): UnitDef?
	local i = Config.UnitIndex[key]
	return i and Config.Units[i + 1] or nil
end

export type MutDef = { key: string, name: string, mult: number, chance: number, glyph: string, color: Color3 }
Config.Mutations = {
	{ key = "Gold", name = "Gold", mult = 2, chance = 1 / 20, glyph = "✨", color = rgb(255, 204, 60) },
	{ key = "Glow", name = "Glow", mult = 3, chance = 1 / 60, glyph = "🌙", color = rgb(150, 255, 140) },
	{ key = "Rainbow", name = "Rainbow", mult = 5, chance = 1 / 250, glyph = "🌈", color = rgb(255, 120, 220) },
} :: { MutDef }
Config.MutByKey = {} :: { [string]: MutDef }
for _, m in ipairs(Config.Mutations) do
	Config.MutByKey[m.key] = m
end

function Config.mutMult(mut: string): number
	local m = Config.MutByKey[mut]
	return m and m.mult or 1
end

-- A stack key names one kind of unit in a player's toy box: "Tank|Gold", "Rifleman|".
function Config.stack(unitKey: string, mut: string): string
	return unitKey .. "|" .. mut
end

function Config.split(stack: string): (string, string)
	local a, b = string.match(stack, "^([^|]*)|(.*)$")
	return a or stack, b or ""
end

function Config.unitName(unitKey: string, mut: string): string
	local u = Config.UnitByKey[unitKey]
	local n = u and u.name or unitKey
	if mut ~= "" then
		return mut .. " " .. n
	end
	return n
end

-- One number for "how strong": attack plus a third of health, times the mutation.
function Config.power(unitKey: string, mut: string): number
	local u = Config.UnitByKey[unitKey]
	if not u then
		return 0
	end
	return (u.atk + u.hp / 3) * Config.mutMult(mut)
end

-- Battles ------------------------------------------------------------------------------------------------
Config.Volley = 0.75 -- seconds between volleys
Config.MaxVolleys = 22 -- then the side with more health left wins
Config.DamageScale = 0.55
Config.RecoverTime = 10 -- knocked-over soldiers stand back up in the toy box after this
Config.DrillCooldown = 16
Config.ShowPerSide = 8 -- models drawn per side; the rest show as "+N"

-- Bags (numeric odds are shown in the shop) ---------------------------------------------------------------------
export type Odds = { key: string, weight: number }
export type BagDef = { key: string, name: string, price: number, rank: number, count: number, glyph: string, color: string, odds: { Odds } }
Config.Bags = {
	{
		key = "Basic", name = "Bag of Soldiers", price = 60, rank = 1, count = 3, glyph = "🎒", color = "green",
		odds = {
			{ key = "Rifleman", weight = 8200 }, { key = "Bazooka", weight = 1500 }, { key = "Medic", weight = 260 },
			{ key = "Tank", weight = 34 }, { key = "Heli", weight = 5 }, { key = "General", weight = 0.8 }, { key = "Dino", weight = 0.2 },
		},
	},
	{
		key = "Heavy", name = "Heavy Duffel", price = 750, rank = 3, count = 3, glyph = "👜", color = "blue",
		odds = {
			{ key = "Bazooka", weight = 6200 }, { key = "Medic", weight = 3000 }, { key = "Tank", weight = 680 },
			{ key = "Heli", weight = 100 }, { key = "General", weight = 18 }, { key = "Dino", weight = 2 },
		},
	},
	{
		key = "Elite", name = "Elite Crate", price = 9000, rank = 6, count = 3, glyph = "🧰", color = "purple",
		odds = {
			{ key = "Medic", weight = 6000 }, { key = "Tank", weight = 3200 }, { key = "Heli", weight = 700 },
			{ key = "General", weight = 92 }, { key = "Dino", weight = 8 },
		},
	},
	{
		key = "Mega", name = "Mega Crate", price = 110000, rank = 9, count = 3, glyph = "🎁", color = "gold",
		odds = {
			{ key = "Tank", weight = 6000 }, { key = "Heli", weight = 3300 }, { key = "General", weight = 650 }, { key = "Dino", weight = 50 },
		},
	},
} :: { BagDef }
Config.BagByKey = {} :: { [string]: BagDef }
for _, b in ipairs(Config.Bags) do
	Config.BagByKey[b.key] = b
end
Config.MaxTokens = 60 -- unopened free bags a player can hold

-- Zones (flags on bottle caps). Outposts are each team's drill ground next to its toy boxes. -------------------
export type ZoneDef = {
	id: string,
	name: string,
	glyph: string,
	pos: Vector3,
	radius: number,
	tier: number,
	reward: number,
	income: number,
	cap: number,
	wild: number, -- power of the Wind-Up Toys guarding it while neutral
	outpost: string?,
	cap1: Color3, -- bottle cap colour
}
Config.Zones = {
	{ id = "out_g", name = "Green Outpost", glyph = "🚩", pos = Vector3.new(-128, 0, 112), radius = 15, tier = 0, reward = 18, income = 0, cap = 0, wild = 0, outpost = "Green", cap1 = rgb(236, 72, 66) },
	{ id = "out_t", name = "Tan Outpost", glyph = "🚩", pos = Vector3.new(128, 0, 112), radius = 15, tier = 0, reward = 18, income = 0, cap = 0, wild = 0, outpost = "Tan", cap1 = rgb(236, 72, 66) },
	{ id = "rug", name = "The Rug", glyph = "🧶", pos = Vector3.new(0, 0.6, 6), radius = 22, tier = 1, reward = 40, income = 3, cap = 6, wild = 45, cap1 = rgb(72, 142, 236) },
	{ id = "chest", name = "Toy Chest", glyph = "🧸", pos = Vector3.new(0, 0, -128), radius = 22, tier = 2, reward = 90, income = 6, cap = 8, wild = 170, cap1 = rgb(255, 208, 62) },
	{ id = "tower", name = "Block Tower", glyph = "🧱", pos = Vector3.new(0, 0, 138), radius = 22, tier = 2, reward = 90, income = 6, cap = 8, wild = 170, cap1 = rgb(160, 112, 236) },
	{ id = "fort", name = "Bed Fort", glyph = "🛏️", pos = Vector3.new(-170, 0, 34), radius = 22, tier = 3, reward = 170, income = 10, cap = 10, wild = 430, cap1 = rgb(255, 150, 52) },
	{ id = "desk", name = "The Desk", glyph = "✏️", pos = Vector3.new(172, 44, -170), radius = 20, tier = 3, reward = 170, income = 10, cap = 10, wild = 430, cap1 = rgb(56, 200, 186) },
} :: { ZoneDef }
Config.ZoneById = {} :: { [string]: ZoneDef }
for _, z in ipairs(Config.Zones) do
	Config.ZoneById[z.id] = z
end
Config.IncomeTick = 5 -- seconds; zone income is paid this often
Config.TeamShare = 0.3 -- teammates without soldiers in a held zone still get this share

-- Spawns and toy-box base slots (four per team along the south wall) ------------------------------------------
Config.Spawn = {
	Green = { pos = Vector3.new(-58, 0.6, 64), look = Vector3.new(-128, 0, 112) },
	Tan = { pos = Vector3.new(58, 0.6, 64), look = Vector3.new(128, 0, 112) },
} :: { [string]: { pos: Vector3, look: Vector3 } }
Config.BaseSlots = {
	Green = { Vector3.new(-236, 0, 192), Vector3.new(-196, 0, 192), Vector3.new(-156, 0, 192), Vector3.new(-116, 0, 192) },
	Tan = { Vector3.new(116, 0, 192), Vector3.new(156, 0, 192), Vector3.new(196, 0, 192), Vector3.new(236, 0, 192) },
} :: { [string]: { Vector3 } }

-- Toy-box upgrades -----------------------------------------------------------------------------------------------
export type UpgradeDef = { key: string, name: string, desc: string, glyph: string, base: number, growth: number, max: number }
Config.Upgrades = {
	{ key = "box", name = "Bigger Box", desc = "+4 soldier slots", glyph = "📦", base = 100, growth = 1.7, max = 20 },
	{ key = "squad", name = "Squad Size", desc = "+1 soldier per deploy", glyph = "🪖", base = 300, growth = 2.4, max = 6 },
	{ key = "press", name = "Plastic Press", desc = "+10 🧱/min, even offline", glyph = "🏭", base = 120, growth = 1.55, max = 25 },
	{ key = "mold", name = "Fast Molds", desc = "-6% merge time", glyph = "⏩", base = 250, growth = 1.9, max = 10 },
	{ key = "lucky", name = "Lucky Bags", desc = "+6% bag luck", glyph = "🍀", base = 500, growth = 2.1, max = 10 },
} :: { UpgradeDef }
Config.UpgradeByKey = {} :: { [string]: UpgradeDef }
for _, u in ipairs(Config.Upgrades) do
	Config.UpgradeByKey[u.key] = u
end

function Config.upgradeCost(key: string, level: number): number
	local u = Config.UpgradeByKey[key]
	if not u then
		return math.huge
	end
	return math.floor(u.base * u.growth ^ level)
end

function Config.capacity(boxLevel: number, bigBox: boolean): number
	return 15 + boxLevel * 4 + (bigBox and 20 or 0)
end

function Config.squadSize(level: number, pro: boolean): number
	return 3 + level + (pro and 2 or 0)
end

function Config.pressRate(level: number): number -- plastic per minute
	return level * 10
end

function Config.mergeTime(unitKey: string, moldLevel: number, vip: boolean): number
	local u = Config.UnitByKey[unitKey]
	if not u then
		return 0
	end
	return u.merge * (1 - 0.06 * moldLevel) * (vip and 0.8 or 1)
end

Config.OfflineCap = 8 * 3600
Config.OfflineCapVip = 12 * 3600

-- Ranks ------------------------------------------------------------------------------------------------------------
export type RankDef = { name: string, xp: number, glyph: string }
Config.Ranks = {
	{ name = "Recruit", xp = 0, glyph = "🔰" },
	{ name = "Private", xp = 50, glyph = "🎗️" },
	{ name = "Corporal", xp = 200, glyph = "⭐" },
	{ name = "Sergeant", xp = 550, glyph = "⭐" },
	{ name = "Lieutenant", xp = 1300, glyph = "🌟" },
	{ name = "Captain", xp = 2800, glyph = "🌟" },
	{ name = "Major", xp = 5500, glyph = "🏅" },
	{ name = "Colonel", xp = 10000, glyph = "🏅" },
	{ name = "General", xp = 17000, glyph = "🎖️" },
	{ name = "Field Marshal", xp = 28000, glyph = "👑" },
	{ name = "Toy Legend", xp = 45000, glyph = "🏆" },
} :: { RankDef }

function Config.rankOf(xp: number): number
	local r = 1
	for i, rk in ipairs(Config.Ranks) do
		if xp >= rk.xp then
			r = i
		end
	end
	return r
end

function Config.rankBonus(rank: number): number -- army power multiplier
	return 1 + 0.05 * (rank - 1)
end

function Config.rankReward(rank: number): number -- plastic reward multiplier
	return 1 + 0.25 * (rank - 1)
end

Config.Xp = { drill = 4, capturePerTier = 15, defend = 6, lose = 3, mergePerTier = 4, bag = 2, discover = 10 }

-- Events ------------------------------------------------------------------------------------------------------------
Config.Cat = {
	first = 200, -- seconds after server start
	interval = 600,
	warn = 25,
	speed = 34, -- studs per second while walking
	targets = 2, -- zones swatted per visit
	reach = 26, -- cat stands this far from the zone it swats
	flingRadius = 36,
	pickups = 4, -- lost soldiers dropped per swat
	pickupLife = 45,
	bedPos = Vector3.new(-176, 50, -118),
	floorPos = Vector3.new(-80, 0, -86),
	hub = Vector3.new(0, 0, -40),
}
Config.Round = { length = 180, perZone = 25, xp = 10 }
Config.GiftEvery = 600 -- a free bag every 10 minutes online
Config.Gift = { plastic = 120, bag = "Basic", n = 1 }

-- Daily login streak (plastic grows with rank). Day 7 repeats.
export type DailyDef = { plastic: number, bag: string, n: number }
Config.Daily = {
	{ plastic = 150, bag = "Basic", n = 1 },
	{ plastic = 300, bag = "Basic", n = 2 },
	{ plastic = 500, bag = "Heavy", n = 1 },
	{ plastic = 800, bag = "Basic", n = 3 },
	{ plastic = 1200, bag = "Heavy", n = 2 },
	{ plastic = 2000, bag = "Basic", n = 5 },
	{ plastic = 4000, bag = "Elite", n = 1 },
} :: { DailyDef }

function Config.dayNumber(t: number): number
	return math.floor(t / 86400)
end
Config.SupplyAt = 150 -- seconds into a new player's first session: the Supply Drop (a guaranteed Tank)

Config.AI = {
	startDelay = 45,
	interval = { 14, 22 },
	assistInterval = { 32, 44 },
	maxUnits = 6,
	protectTut = 5, -- AI leaves zones guarded by players still before this tutorial step alone
}

-- Tutorial goals (FTUE) -------------------------------------------------------------------------------------------
Config.Tut = {
	"Deploy your soldiers at your Outpost flag!",
	"Open your free Bag of Soldiers!",
	"Merge 3 Riflemen into a Bazooka!",
	"Capture The Rug!",
	"Open your Supply Drop!",
	"Deploy your Tank at the Block Tower!",
	"Upgrade your Toy Box!",
}
Config.TutDone = #Config.Tut + 1

export type ShopItem = { id: number, name: string, price: number, glyph: string, desc: string }
-- Money ladder (PROTOCOL §6). ids are 0 until created; the kit simulates purchases in Studio. -----------------------
Config.Passes = {
	x2plastic = { id = 0, name = "2x Plastic", price = 199, glyph = "🧱", desc = "Double plastic from zones, captures and the press. Forever." },
	autodeploy = { id = 0, name = "Auto-Deploy", price = 149, glyph = "🤖", desc = "Your ready soldiers deploy themselves to the best target." },
	vip = { id = 0, name = "VIP General", price = 299, glyph = "🎖️", desc = "Get a Golden General, +10% plastic, 20% faster molds, VIP tag." },
	bigbox = { id = 0, name = "Mega Toy Box", price = 129, glyph = "📦", desc = "+20 soldier slots in your toy box." },
	doublemold = { id = 0, name = "Double Mold Press", price = 179, glyph = "🔀", desc = "Run 2 merges at the same time." },
	pro = { id = 0, name = "Pro Commander", price = 1499, glyph = "👑", desc = "+2 squad size, +25% army power, golden toy box, Rainbow Tank, PRO tag." },
} :: { [string]: ShopItem }
Config.PassOrder = { "x2plastic", "autodeploy", "bigbox", "doublemold", "vip", "pro" }
Config.Products = {
	skip = { id = 0, name = "Skip Merge Timers", price = 19, glyph = "⏩", desc = "Finish every merge in your mold press now." },
	plasticS = { id = 0, name = "Handful of Plastic", price = 25, glyph = "🧱", desc = "1,500 plastic (grows with your rank)." },
	luck = { id = 0, name = "Lucky Bags (15 min)", price = 39, glyph = "🍀", desc = "x2 bag luck and x2 mutation odds for 15 minutes." },
	starter = { id = 0, name = "Starter Pack", price = 49, glyph = "🎒", desc = "1,000 plastic, a Medic and 3 Heavy Duffels." },
	bags10 = { id = 0, name = "10 Bags of Soldiers", price = 69, glyph = "🎒", desc = "Ten free Bags of Soldiers." },
	callcat = { id = 0, name = "Call the Cat!", price = 79, glyph = "🐱", desc = "The cat comes NOW and swats the enemy army. Whole server sees it!" },
	plasticM = { id = 0, name = "Bucket of Plastic", price = 99, glyph = "🪣", desc = "7,500 plastic (grows with your rank)." },
	tanks = { id = 0, name = "Tank Bundle", price = 99, glyph = "🛡️", desc = "2 Tanks + 1 Gold Tank." },
	helis = { id = 0, name = "Heli Bundle", price = 249, glyph = "🚁", desc = "2 Helicopters + 1 Glow Helicopter." },
	plasticL = { id = 0, name = "Truck of Plastic", price = 299, glyph = "🚚", desc = "30,000 plastic (grows with your rank)." },
} :: { [string]: ShopItem }
Config.ProductOrder = { "skip", "luck", "callcat", "starter", "bags10", "tanks", "helis", "plasticS", "plasticM", "plasticL" }
Config.LuckBoostSeconds = 15 * 60

export type MeshInfo = { mesh: number, texture: number, size: Vector3, prompt: string }
-- Hero mesh slots: generate in Studio (PROTOCOL §4.3), fill the ids in. 0 = use the primitive build. ---------------
-- Soldiers are single-colour plastic, so the texture can stay 0 and the part colour is set to the team colour.
Config.Meshes = {
	Rifleman = { mesh = 0, texture = 0, size = Vector3.new(2.6, 3.6, 2.6), prompt = "classic plastic toy army man standing upright aiming a rifle forward, on a small round base, single solid colour, smooth simple clean shapes" },
	Bazooka = { mesh = 0, texture = 0, size = Vector3.new(2.6, 3.8, 3.2), prompt = "classic plastic toy army man standing upright with a bazooka tube on his right shoulder, on a small round base, single solid colour, smooth simple clean shapes" },
	Medic = { mesh = 0, texture = 0, size = Vector3.new(2.6, 3.7, 2.6), prompt = "classic plastic toy army medic standing upright holding a small first aid box, backpack with a cross, on a small round base, single solid colour, smooth simple shapes" },
	Tank = { mesh = 0, texture = 0, size = Vector3.new(4.2, 3.2, 6.4), prompt = "small toy army tank, boxy hull, two tracks with round wheels, round turret with one long straight cannon, single solid colour, smooth simple clean shapes" },
	Heli = { mesh = 0, texture = 0, size = Vector3.new(4.2, 3.8, 8), prompt = "small toy army helicopter, rounded body with bubble cockpit, two-blade top rotor, thin tail with small rotor, two landing skids, single solid colour, smooth simple shapes" },
	General = { mesh = 0, texture = 0, size = Vector3.new(3, 5.4, 3), prompt = "plastic toy army general standing upright pointing forward, peaked cap, long coat, medals, on a small round base, single solid colour, smooth simple shapes" },
	Dino = { mesh = 0, texture = 0, size = Vector3.new(4.5, 6.5, 8.5), prompt = "chunky toy robot t-rex standing upright, boxy metal panels, big square jaw, tiny arms, thick tail, round glowing eyes, smooth simple clean shapes" },
	Cat = { mesh = 0, texture = 0, size = Vector3.new(30, 40, 60), prompt = "big fluffy orange tabby house cat standing on four legs, tail up, round head, pointed ears, smooth simple shapes, perfectly symmetrical" },
} :: { [string]: MeshInfo }

-- UI glyphs (emoji for now; swap for our own icon ids later) ------------------------------------------------------
Config.Icons = {
	plastic = "🧱",
	bag = "🎒",
	army = "🪖",
	map = "🗺️",
	index = "📖",
	base = "📦",
	shop = "🛒",
	daily = "🎁",
	gift = "⏰",
	supply = "🪂",
	luck = "🍀",
	cat = "🐱",
	round = "🏆",
	deploy = "⚔️",
	merge = "🔀",
	xp = "⭐",
	power = "💪",
	recall = "↩️",
	watch = "👀",
	mute = "🔊",
	muted = "🔇",
	lock = "🔒",
	check = "✅",
	new = "🆕",
	skip = "⏩",
	sleep = "💤",
	ai = "🤖",
	flag = "🚩",
}

Config.Music = { 1842976958, 1836942830, 1840434670, 1845266081, 1839807682, 1838005831 }

-- Save data template (dictionary defaults stay empty when their keys vary: Data.reconcile merges them).
Config.Defaults = {
	plastic = 0,
	xp = 0,
	units = {},
	index = {},
	merging = {},
	tokens = { Basic = 0, Heavy = 0, Elite = 0, Mega = 0 },
	upgrades = { box = 0, squad = 0, press = 0, mold = 0, lucky = 0 },
	daily = { last = 0, streak = 0 },
	stats = { captures = 0, wins = 0, battles = 0, bags = 0, merges = 0, swats = 0, drills = 0, defends = 0 },
	boosts = { luck = 0 },
	settings = { auto = true },
	tut = 1,
	lastSeen = 0,
	starterGiven = false,
	supplyClaimed = false,
	vipGeneral = false,
	proBundle = false,
	starterPack = false,
}

return Config

-- Toy Army ⚔️ : every tuning number, the palette, units, bags, zones, upgrades, ranks, the money ladder,
-- hero-mesh slots and UI glyphs. Shared by the server and the client.
local Config = {}

-- The game's display name: every banner, sign and letter block reads it, so a rename is this one line.
Config.Title = "Toy Army ⚔️"
-- The title without emoji (signs, the letter-block tower): "Toy Army".
Config.TitlePlain = (string.gsub(string.gsub(Config.Title, "[^%w%s!%-']", ""), "^%s*(.-)%s*$", "%1"))
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
-- class: the rock-paper-scissors counter every card shows (Config.Classes): soldiers shoot down helicopters,
-- helicopters blast tanks, tanks crush soldiers.
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
	class: string,
}
Config.Units = {
	{ key = "Rifleman", name = "Rifleman", tier = "Common", atk = 10, hp = 30, merge = 0, special = "", glyph = "💂", desc = "Pew pew! The classic.", scale = 1, class = "Foot" },
	{ key = "Bazooka", name = "Bazooka", tier = "Uncommon", atk = 34, hp = 100, merge = 4, special = "splash", glyph = "💥", desc = "Blasts two toys at once.", scale = 1, class = "Foot" },
	{ key = "Medic", name = "Medic", tier = "Rare", atk = 105, hp = 330, merge = 12, special = "heal", glyph = "⛑️", desc = "Patches up the squad.", scale = 1.05, class = "Foot" },
	{ key = "Tank", name = "Tank", tier = "Epic", atk = 360, hp = 1150, merge = 30, special = "armor", glyph = "🛡️", desc = "Armored: takes 30% less.", scale = 1, class = "Armor" },
	{ key = "Heli", name = "Helicopter", tier = "Legendary", atk = 1250, hp = 3900, merge = 90, special = "air", glyph = "🚁", desc = "Strafes two targets.", scale = 1, class = "Air" },
	{ key = "General", name = "Golden General", tier = "Mythic", atk = 4300, hp = 13500, merge = 240, special = "rally", glyph = "🎖️", desc = "Rally: squad +20% attack.", scale = 1.2, class = "Foot" },
	{ key = "Dino", name = "Robot Dino", tier = "Secret", atk = 15500, hp = 50000, merge = 600, special = "stomp", glyph = "🦖", desc = "STOMP: hits three toys.", scale = 1, class = "Armor" },
} :: { UnitDef }
Config.UnitByKey = {} :: { [string]: UnitDef }
Config.UnitIndex = {} :: { [string]: number }
for i, u in ipairs(Config.Units) do
	Config.UnitByKey[u.key] = u
	Config.UnitIndex[u.key] = i
end

-- Counters (rock-paper-scissors): a unit hits the class it beats harder and the class that beats it softer.
export type ClassDef = { key: string, name: string, glyph: string, beats: string }
Config.Classes = {
	Foot = { key = "Foot", name = "Soldiers", glyph = "💂", beats = "Air" },
	Air = { key = "Air", name = "Air", glyph = "🚁", beats = "Armor" },
	Armor = { key = "Armor", name = "Armor", glyph = "🛡️", beats = "Foot" },
} :: { [string]: ClassDef }
Config.ClassOrder = { "Foot", "Air", "Armor" }
Config.CounterStrong = 1.4
Config.CounterWeak = 0.8

function Config.classOf(unitKey: string): ClassDef
	local u = Config.UnitByKey[unitKey]
	return Config.Classes[u and u.class or "Foot"] or Config.Classes.Foot
end

-- Damage multiplier when a unit of class `a` hits one of class `b`.
function Config.counter(a: string, b: string): number
	local ca, cb = Config.Classes[a], Config.Classes[b]
	if ca and ca.beats == b then
		return Config.CounterStrong
	elseif cb and cb.beats == a then
		return Config.CounterWeak
	end
	return 1
end

-- "strong" / "weak" / "even" for the counter hint on the DEPLOY button.
function Config.matchup(a: string, b: string): string
	local m = Config.counter(a, b)
	return m > 1 and "strong" or m < 1 and "weak" or "even"
end

-- "💂 beats 🚁" for a unit card.
function Config.counterText(unitKey: string): string
	local c = Config.classOf(unitKey)
	local beats = Config.Classes[c.beats]
	return c.glyph .. " beats " .. (beats and beats.glyph or "?")
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

-- Bags (odds in % that add up to 100 are shown in BAGS before buying) -------------------------------------------
-- fixed: what a bag bought with plastic gives instead of a roll to a player under Roblox's paid random item rule
-- (kit Policy RandomBlocked; plastic is sold for Robux). Shown on the bag before they buy. Worth about one roll.
export type Odds = { key: string, weight: number }
export type BagDef = { key: string, name: string, price: number, rank: number, count: number, glyph: string, color: string, odds: { Odds }, fixed: { string } }
Config.Bags = {
	{
		key = "Basic", name = "Bag of Soldiers", price = 60, rank = 1, count = 3, glyph = "🎒", color = "green",
		odds = {
			{ key = "Rifleman", weight = 8200 }, { key = "Bazooka", weight = 1500 }, { key = "Medic", weight = 260 },
			{ key = "Tank", weight = 34 }, { key = "Heli", weight = 5 }, { key = "General", weight = 0.8 }, { key = "Dino", weight = 0.2 },
		},
		fixed = { "Rifleman", "Rifleman", "Bazooka" },
	},
	{
		key = "Heavy", name = "Heavy Duffel", price = 750, rank = 3, count = 3, glyph = "👜", color = "blue",
		odds = {
			{ key = "Bazooka", weight = 6200 }, { key = "Medic", weight = 3000 }, { key = "Tank", weight = 680 },
			{ key = "Heli", weight = 100 }, { key = "General", weight = 18 }, { key = "Dino", weight = 2 },
		},
		fixed = { "Bazooka", "Medic", "Medic" },
	},
	{
		key = "Elite", name = "Elite Crate", price = 9000, rank = 6, count = 3, glyph = "🧰", color = "purple",
		odds = {
			{ key = "Medic", weight = 6000 }, { key = "Tank", weight = 3200 }, { key = "Heli", weight = 700 },
			{ key = "General", weight = 92 }, { key = "Dino", weight = 8 },
		},
		fixed = { "Medic", "Tank", "Tank" },
	},
	{
		key = "Mega", name = "Mega Crate", price = 110000, rank = 9, count = 3, glyph = "🎁", color = "gold",
		odds = {
			{ key = "Tank", weight = 6000 }, { key = "Heli", weight = 3300 }, { key = "General", weight = 650 }, { key = "Dino", weight = 50 },
		},
		fixed = { "Tank", "Heli", "Heli" },
	},
} :: { BagDef }
Config.BagByKey = {} :: { [string]: BagDef }
for _, b in ipairs(Config.Bags) do
	Config.BagByKey[b.key] = b
end

-- "2 Riflemen + 1 Bazooka" for a bag's fixed reward.
function Config.fixedText(bag: BagDef): string
	local counts: { [string]: number } = {}
	local order: { string } = {}
	for _, k in ipairs(bag.fixed) do
		if not counts[k] then
			table.insert(order, k)
		end
		counts[k] = (counts[k] or 0) + 1
	end
	local parts = {}
	for _, k in ipairs(order) do
		local u = Config.UnitByKey[k]
		local name = u and u.name or k
		table.insert(parts, counts[k] .. " " .. name .. (counts[k] > 1 and "s" or ""))
	end
	return table.concat(parts, " + ")
end

-- Bag luck: the Lucky Bags upgrade, the player's own Lucky Bags boost and the server-wide luck boost.
-- Returns the tier luck (kit Tiers.roll) and the mutation chance multiplier. Server rolls and the client's odds
-- display both use this, so the shown % is always the rolled %.
function Config.bagLuck(luckyLevel: number, boosted: boolean, serverMult: number): (number, number)
	local own = boosted and 2 or 1
	local luck = (1 + 0.06 * luckyLevel) * own * serverMult
	local mutMult = (1 + 0.03 * luckyLevel) * own * serverMult
	return luck, mutMult
end

-- Chance of each mutation result for one toy, as Tiers.percents entries (none, Gold, Glow, Rainbow) so the
-- shown numbers add up to 100%. Rolled rarest first (Army.rollMut).
function Config.mutOdds(mutMult: number): { { key: string, weight: number } }
	local left = 1
	local out: { { key: string, weight: number } } = {}
	for i = #Config.Mutations, 1, -1 do
		local m = Config.Mutations[i]
		local p = math.min(1, m.chance * mutMult) * left
		table.insert(out, 1, { key = m.key, weight = p })
		left -= p
	end
	table.insert(out, 1, { key = "", weight = math.max(0, left) })
	return out
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
	{ key = "squad", name = "Squad Size", desc = "+1 soldier per deploy", glyph = "💂", base = 300, growth = 2.4, max = 6 },
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

export type ShopItem = {
	id: number,
	name: string,
	price: number,
	glyph: string,
	desc: string,
	once: boolean?,
	random: boolean?,
	gift: string?,
	boost: { [string]: any }?,
	base: number?, -- plastic packs: plastic at rank 1 (times Config.rankReward)
	intro: boolean?, -- kit Shop: only for players who never bought anything
	window: number?, -- kit Shop: only in the first `window` seconds of the first session (from firstJoin)
}
-- Money ladder (DESIGN.md). ids are 0 until tools/launch.py creates them; the kit simulates purchases in Studio.
-- Keep every item on ONE line: launch.py reads name / price / desc from it. random = true: a paid random item
-- (kit Shop refuses it for players under the paid random item rule). gift = "passKey": a gift copy of a pass.
-- boost = {...}: a server-wide 15-minute boost (kit Boosts) that Army.addPlastic / bag luck multiply by.
-- intro = true / window = 600: the kit refuses the Recruit Deal after any purchase and the Starter Pack after its window.
Config.Passes = {
	x2plastic = { id = 0, name = "2x Plastic", price = 199, glyph = "🧱", desc = "Double plastic from zones, captures and the press. Forever." },
	autodeploy = { id = 0, name = "Auto-Deploy", price = 149, glyph = "🤖", desc = "Your ready soldiers deploy themselves to the best target." },
	vip = { id = 0, name = "VIP General", price = 299, glyph = "🎖️", desc = "Get a Golden General, +10% plastic, 20% faster molds, VIP tag." },
	bigbox = { id = 0, name = "Mega Toy Box", price = 129, glyph = "📦", desc = "+20 soldier slots in your toy box." },
	doublemold = { id = 0, name = "Double Mold Press", price = 179, glyph = "🔀", desc = "Run 2 merges at the same time." },
	pro = { id = 0, name = "Pro Commander", price = 1499, glyph = "👑", desc = "+2 squad size, +25% army power, golden toy box, Rainbow Tank, PRO tag." },
	skinPumpkin = { id = 0, name = "Pumpkin Army Skin", price = 299, glyph = "🎃", desc = "Halloween! Your whole army turns jack-o'-lantern orange. Equip it in SHOP > SKINS." },
	skinCamo = { id = 0, name = "Camo Army Skin", price = 499, glyph = "🌿", desc = "Your whole army in jungle camo. Everyone in the war sees it." },
	tankLava = { id = 0, name = "Lava Tank Paint", price = 699, glyph = "🔥", desc = "Every Tank you own gets red-hot lava paint." },
	skinChrome = { id = 0, name = "Chrome Army Skin", price = 1299, glyph = "💿", desc = "Shiny mirror-chrome soldiers, tanks and helicopters." },
	skinGold = { id = 0, name = "Gold Army Skin", price = 2499, glyph = "🏆", desc = "Your whole army in solid shining gold. The ultimate flex." },
} :: { [string]: ShopItem }
Config.PassOrder = { "x2plastic", "autodeploy", "bigbox", "doublemold", "vip", "pro" }
Config.Products = {
	intro = { id = 0, name = "Recruit Deal", price = 9, once = true, intro = true, glyph = "🎖️", desc = "First purchase only: a Tank and 1,000 plastic for 9 Robux!" },
	skip = { id = 0, name = "Skip Merge Timers", price = 19, glyph = "⏩", desc = "Finish every merge in your mold press now." },
	plasticS = { id = 0, name = "Handful of Plastic", price = 25, glyph = "🧱", desc = "1,500 plastic (grows with your rank).", base = 1500 },
	rubber = { id = 0, name = "Rubber-Band Volley", price = 29, glyph = "🏹", desc = "Strike: 3 enemy toys at your target take a big hit." },
	luck = { id = 0, name = "Lucky Bags (15 min)", price = 39, random = true, glyph = "🍀", desc = "x2 bag luck and x2 mutation odds for 15 minutes. See the boosted odds in BAGS." },
	starter = { id = 0, name = "Starter Pack", price = 49, once = true, window = 600, glyph = "🎒", desc = "1,500 plastic, 2 Medics and a GOLD Tank. First 10 minutes only!" },
	balloon = { id = 0, name = "Water-Balloon Bomb", price = 49, glyph = "🎈", desc = "Strike: soaks every enemy toy at your target." },
	bags10 = { id = 0, name = "10 Bags of Soldiers", price = 69, random = true, glyph = "🎒", desc = "Ten free Bags of Soldiers. Odds in BAGS." },
	callcat = { id = 0, name = "Call the Cat!", price = 79, glyph = "🐱", desc = "The cat comes NOW and swats the enemy army. Whole server sees it!" },
	plasticM = { id = 0, name = "Bucket of Plastic", price = 99, glyph = "🧺", desc = "7,500 plastic (grows with your rank).", base = 7500 },
	tanks = { id = 0, name = "Tank Bundle", price = 99, glyph = "🛡️", desc = "2 Tanks + 1 Gold Tank." },
	rcplane = { id = 0, name = "RC-Plane Drop", price = 99, glyph = "✈️", desc = "Strike: an RC plane drops a paratrooper squad on your target." },
	boost2 = { id = 0, name = "2x Plastic for Everyone", price = 99, glyph = "⚡", desc = "15 minutes of 2x plastic for the WHOLE server. Everyone sees your name!", boost = { kind = "plastic", mult = 2, minutes = 15, label = "PLASTIC" } },
	rockets = { id = 0, name = "Toy-Rocket Barrage", price = 149, glyph = "🚀", desc = "Strike: six toy rockets blast every enemy toy at your target." },
	luck2 = { id = 0, name = "2x Luck for Everyone", price = 149, random = true, glyph = "🍀", desc = "15 minutes of x2 bag luck for the WHOLE server.", boost = { kind = "luck", mult = 2, minutes = 15, label = "LUCK" } },
	helis = { id = 0, name = "Heli Bundle", price = 249, glyph = "🚁", desc = "2 Helicopters + 1 Glow Helicopter." },
	boost4 = { id = 0, name = "4x Plastic for Everyone", price = 249, glyph = "⚡", desc = "Upgrade a running 2x to 4x plastic for the whole server!", boost = { kind = "plastic", mult = 4, minutes = 15, needs = 2, label = "PLASTIC" } },
	flashlight = { id = 0, name = "Flashlight Beam", price = 279, glyph = "🔦", desc = "Strike: a giant flashlight knocks over EVERY enemy toy at your target." },
	plasticL = { id = 0, name = "Truck of Plastic", price = 299, glyph = "🚚", desc = "30,000 plastic (grows with your rank).", base = 30000 },
	luck4 = { id = 0, name = "4x Luck for Everyone", price = 349, random = true, glyph = "🌈", desc = "Upgrade a running 2x Luck to 4x bag luck for the whole server!", boost = { kind = "luck", mult = 4, minutes = 15, needs = 2, label = "LUCK" } },
	dog = { id = 0, name = "The Dog", price = 449, glyph = "🐶", desc = "Strike: the dog runs through EVERY enemy zone knocking their toys over!" },
	boost8 = { id = 0, name = "8x Plastic for Everyone", price = 499, glyph = "⚡", desc = "Upgrade a running 4x to 8x plastic for the whole server!", boost = { kind = "plastic", mult = 8, minutes = 15, needs = 4, label = "PLASTIC" } },
	plasticXL = { id = 0, name = "Crate of Plastic", price = 499, glyph = "📦", desc = "55,000 plastic (grows with your rank).", base = 55000 },
	boost16 = { id = 0, name = "16x Plastic Party", price = 999, glyph = "🎉", desc = "Upgrade a running 8x to 16x plastic for the whole server!", boost = { kind = "plastic", mult = 16, minutes = 15, needs = 8, label = "PLASTIC" } },
	plasticXXL = { id = 0, name = "Warehouse of Plastic", price = 999, glyph = "🏭", desc = "120,000 plastic (grows with your rank).", base = 120000 },
	plasticFirst = { id = 0, name = "Plastic Factory First-Time Deal", price = 1199, once = true, glyph = "🏷️", desc = "The Plastic Factory 40% off, once: 260,000 plastic (grows with your rank).", base = 260000 },
	plasticTop = { id = 0, name = "Plastic Factory", price = 1999, glyph = "🏗️", desc = "260,000 plastic (grows with your rank).", base = 260000 },
	gift_x2plastic = { id = 0, name = "Gift: 2x Plastic", price = 199, gift = "x2plastic", glyph = "🎁", desc = "Give the 2x Plastic pass to a player in this server." },
	gift_autodeploy = { id = 0, name = "Gift: Auto-Deploy", price = 149, gift = "autodeploy", glyph = "🎁", desc = "Give the Auto-Deploy pass to a player in this server." },
	gift_vip = { id = 0, name = "Gift: VIP General", price = 299, gift = "vip", glyph = "🎁", desc = "Give the VIP General pass to a player in this server." },
	gift_bigbox = { id = 0, name = "Gift: Mega Toy Box", price = 129, gift = "bigbox", glyph = "🎁", desc = "Give the Mega Toy Box pass to a player in this server." },
	gift_doublemold = { id = 0, name = "Gift: Double Mold Press", price = 179, gift = "doublemold", glyph = "🎁", desc = "Give the Double Mold Press pass to a player in this server." },
	gift_pro = { id = 0, name = "Gift: Pro Commander", price = 1499, gift = "pro", glyph = "🎁", desc = "Give the Pro Commander pass to a player in this server." },
	gift_skinPumpkin = { id = 0, name = "Gift: Pumpkin Army Skin", price = 299, gift = "skinPumpkin", glyph = "🎁", desc = "Give the Pumpkin Army Skin to a player in this server." },
	gift_skinCamo = { id = 0, name = "Gift: Camo Army Skin", price = 499, gift = "skinCamo", glyph = "🎁", desc = "Give the Camo Army Skin to a player in this server." },
	gift_tankLava = { id = 0, name = "Gift: Lava Tank Paint", price = 699, gift = "tankLava", glyph = "🎁", desc = "Give the Lava Tank Paint to a player in this server." },
	gift_skinChrome = { id = 0, name = "Gift: Chrome Army Skin", price = 1299, gift = "skinChrome", glyph = "🎁", desc = "Give the Chrome Army Skin to a player in this server." },
	gift_skinGold = { id = 0, name = "Gift: Gold Army Skin", price = 2499, gift = "skinGold", glyph = "🎁", desc = "Give the Gold Army Skin to a player in this server." },
} :: { [string]: ShopItem }
-- Shop pages (gift products have no card of their own: each pass card has a 🎁 GIFT button).
Config.BoostOrder = { "intro", "starter", "skip", "luck", "bags10", "tanks", "helis", "boost2", "boost4", "boost8", "boost16", "luck2", "luck4" }
Config.PlasticOrder = { "plasticFirst", "plasticS", "plasticM", "plasticL", "plasticXL", "plasticXXL", "plasticTop" }
Config.LuckBoostSeconds = 15 * 60
Config.StarterWindow = Config.Products.starter.window or 600 -- Starter Pack: first 10 minutes of the first session (kit Shop enforces `window`)
Config.NoOffersBefore = 120 -- no offer pop-up in a session's first 2 minutes

-- The gift product for each pass.
Config.GiftOf = {} :: { [string]: string }
for key, item in pairs(Config.Products) do
	if item.gift then
		Config.GiftOf[item.gift] = key
	end
end

-- Army skins (passes; equip one army skin and the tank paint in SHOP > SKINS). Mutations still show over a skin.
-- kind "army" paints every toy but the Golden General and the Robot Dino; "tank" paints Tanks only.
export type SkinDef = { key: string, kind: string, main: Color3, dark: Color3, alt: Color3?, material: Enum.Material?, reflect: number? }
Config.Skins = {
	skinPumpkin = { key = "skinPumpkin", kind = "army", main = rgb(255, 138, 30), dark = rgb(44, 36, 34) },
	skinCamo = { key = "skinCamo", kind = "army", main = rgb(96, 116, 56), dark = rgb(92, 70, 46), alt = rgb(60, 78, 38), material = Enum.Material.Fabric },
	tankLava = { key = "tankLava", kind = "tank", main = rgb(236, 72, 28), dark = rgb(70, 22, 14), alt = rgb(255, 170, 40) },
	skinChrome = { key = "skinChrome", kind = "army", main = rgb(214, 222, 234), dark = rgb(132, 142, 160), reflect = 0.45 },
	skinGold = { key = "skinGold", kind = "army", main = rgb(255, 212, 80), dark = rgb(220, 150, 24), material = Enum.Material.Foil, reflect = 0.3 },
} :: { [string]: SkinDef }
Config.SkinOrder = { "skinPumpkin", "skinCamo", "tankLava", "skinChrome", "skinGold" }

-- Paid strikes (dev products, STRIKES panel and the CAT button): aimed at a zone your team does not hold.
-- hits = enemy toys hit (0 = all of them), dmg = share of each one's health knocked off (1 = knocked over).
-- squad = paratroopers dropped for your team (share of your best squad's power). dog = every enemy zone.
export type StrikeDef = { key: string, line: string, hits: number, dmg: number, squad: number?, all: boolean?, delay: number }
Config.Strikes = {
	rubber = { key = "rubber", line = "3 enemy toys take a big hit", hits = 3, dmg = 0.75, delay = 1.2 },
	balloon = { key = "balloon", line = "Soaks EVERY enemy toy there", hits = 0, dmg = 0.4, delay = 1.6 },
	callcat = { key = "callcat", line = "Swats the 2 strongest enemy zones", hits = 0, dmg = 1, delay = 0 },
	rcplane = { key = "rcplane", line = "Drops a paratrooper squad for your team", hits = 2, dmg = 0.5, squad = 0.9, delay = 2.4 },
	rockets = { key = "rockets", line = "6 rockets blast EVERY enemy toy there", hits = 0, dmg = 0.8, delay = 2.2 },
	flashlight = { key = "flashlight", line = "Knocks over EVERY enemy toy there", hits = 0, dmg = 1, delay = 2.0 },
	dog = { key = "dog", line = "Runs through EVERY enemy zone", hits = 0, dmg = 1, all = true, delay = 2.0 },
} :: { [string]: StrikeDef }
Config.StrikeOrder = { "rubber", "balloon", "callcat", "rcplane", "rockets", "flashlight", "dog" }

---------------------------------------------------------------------------------------------------------------
-- Launch features (kit Live): codes, group gift, playtime gifts, daily quests, badges, invites, friend bonus.
-- Rewards (Main grants them): plastic (grows with rank, like the plastic packs), bags = { BagKey = n } free bags,
-- luckMinutes (the player's own Lucky Bags boost). Sized to about one session of progress.
---------------------------------------------------------------------------------------------------------------
Config.Live = {
	codes = { LAUNCH = { reward = { plastic = 1500, bags = { Heavy = 2 }, text = "1,500 plastic + 2 Heavy Duffels" } } },
	group = { id = 0, reward = { plastic = 2500, bags = { Elite = 1 }, text = "2,500 plastic + an Elite Crate" } },
	playtime = {
		{ minutes = 5, reward = { plastic = 300, bags = { Basic = 2 }, text = "300 🧱 + 2 Bags" } },
		{ minutes = 10, reward = { bags = { Heavy = 2 }, text = "2 Heavy Duffels" } },
		{ minutes = 30, reward = { plastic = 1000, luckMinutes = 10, text = "10 min Luck + 1,000 🧱" } },
		{ minutes = 60, reward = { plastic = 3000, bags = { Elite = 1 }, text = "Elite Crate + 3,000 🧱" } },
	},
	quests = {
		{ key = "deploy", text = "Deploy 8 squads", goal = 8, reward = { plastic = 500, text = "500 🧱" } },
		{ key = "capture", text = "Capture 3 zones", goal = 3, reward = { plastic = 400, bags = { Heavy = 1 }, text = "Heavy Duffel + 400 🧱" } },
		{ key = "merge", text = "Merge 5 times", goal = 5, reward = { bags = { Basic = 3 }, text = "3 Bags of Soldiers" } },
		{ key = "bags", text = "Open 6 bags", goal = 6, reward = { plastic = 600, text = "600 🧱" } },
		{ key = "round", text = "Win a war round", goal = 1, reward = { bags = { Heavy = 1 }, text = "Heavy Duffel" } },
		{ key = "lost", text = "Grab 2 Lost Soldiers bags", goal = 2, reward = { luckMinutes = 5, text = "5 min Luck" } },
		{ key = "upgrade", text = "Buy 3 upgrades", goal = 3, reward = { plastic = 800, text = "800 🧱" } },
		{ key = "friend", text = "Play a round with a friend", goal = 1, reward = { plastic = 1500, bags = { Heavy = 1 }, text = "1,500 🧱 + Heavy Duffel" } },
	},
	badges = { Welcome = 0, FirstCapture = 0, FirstTank = 0, RoundWin = 0, Lieutenant = 0, Wins10 = 0, SecretDino = 0 },
	invite = { reward = { plastic = 2000, bags = { Heavy = 2 }, text = "2,000 plastic + 2 Heavy Duffels" } },
	friendBonus = 0.1,
}
Config.FirstGiftAt = 45 -- seconds: a new player's first free gift (later ones every Config.GiftEvery)
Config.Hourly = { catTargets = 4, pickups = 8, boost = 2, boostMinutes = 10 }

export type MeshInfo = { mesh: number, texture: number, size: Vector3, prompt: string }
-- Hero mesh slots: generate in Studio (PROTOCOL §4.3), fill the ids in. 0 = use the primitive build. ---------------
-- Soldiers are single-colour plastic, so the texture can stay 0 and the part colour is set to the team colour.
Config.Meshes = {
	Rifleman = { mesh = 98846026302625, texture = 0, size = Vector3.new(2.6, 3.6, 2.6), prompt = "classic plastic toy army man standing upright aiming a rifle forward, on a small round base, single solid colour, smooth simple clean shapes" },
	Bazooka = { mesh = 88056513934113, texture = 0, size = Vector3.new(2.6, 3.8, 3.2), prompt = "classic plastic toy army man standing upright with a bazooka tube on his right shoulder, on a small round base, single solid colour, smooth simple clean shapes" },
	Medic = { mesh = 73629216566438, texture = 0, size = Vector3.new(2.6, 3.7, 2.6), prompt = "classic plastic toy army medic standing upright holding a small first aid box, backpack with a cross, on a small round base, single solid colour, smooth simple shapes" },
	Tank = { mesh = 130275429278896, texture = 0, size = Vector3.new(4.2, 3.2, 6.4), prompt = "small toy army tank, boxy hull, two tracks with round wheels, round turret with one long straight cannon, single solid colour, smooth simple clean shapes" },
	Heli = { mesh = 110517301607708, texture = 0, size = Vector3.new(4.2, 3.8, 8), prompt = "small toy army helicopter, rounded body with bubble cockpit, two-blade top rotor, thin tail with small rotor, two landing skids, single solid colour, smooth simple shapes" },
	General = { mesh = 98396886739471, texture = 0, size = Vector3.new(3, 5.4, 3), prompt = "plastic toy army general standing upright pointing forward, peaked cap, long coat, medals, on a small round base, single solid colour, smooth simple shapes" },
	Dino = { mesh = 115100710640997, texture = 0, size = Vector3.new(4.5, 6.5, 8.5), prompt = "chunky toy robot t-rex standing upright, boxy metal panels, big square jaw, tiny arms, thick tail, round glowing eyes, smooth simple clean shapes" },
	Cat = { mesh = 113446086946089, texture = 124539411674219, size = Vector3.new(30, 40, 60), prompt = "big fluffy orange tabby house cat standing on four legs, tail up, round head, pointed ears, smooth simple shapes, perfectly symmetrical" },
} :: { [string]: MeshInfo }

-- UI glyphs (emoji for now; swap for our own icon ids later) ------------------------------------------------------
Config.Icons = {
	plastic = "🧱",
	bag = "🎒",
	army = "💂",
	map = "🗺️",
	index = "📖",
	base = "📦",
	shop = "🛒",
	daily = "📅",
	free = "🎁",
	strike = "💥",
	deal = "🏷️",
	starter = "🎒",
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
	skin = "", -- equipped army skin (a Config.Skins pass key) or ""
	tankPaint = "",
	skinsSeen = {}, -- skins already auto-equipped once (a new skin goes on when you buy it)
	strikeCredits = {}, -- strikes bought while there was nothing to hit: used later for free
}

return Config

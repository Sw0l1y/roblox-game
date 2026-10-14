-- Cake Off! 🎂 tuning, catalog and geometry. Shared by server and client.
local Config = {}

local C = Color3.fromRGB
local V = Vector3.new

-- The game's display name: every banner, pill and sign in game reads it, so a rename is this one line.
-- Keep the emoji out of Title (TitleGlyph adds it); the DataStore name must NOT change with a rename.
Config.Title = "Cake Off!"
Config.TitleGlyph = "🎂"
Config.Name = Config.Title .. " " .. Config.TitleGlyph
Config.Tagline = "Decorate the Cake!"
Config.DataStore = "CakeOff_v1"

-- "🎂 CAKE OFF!" for banners, the phase pill and signs.
function Config.titleCaps(): string
	return Config.TitleGlyph .. " " .. string.upper(Config.Title)
end

-- Palette (DESIGN.md art bible) --------------------------------------------------------------------
Config.Palette = {
	cream = C(255, 244, 224), -- ground
	creamDark = C(240, 222, 196),
	pink = C(255, 179, 199), -- structure accent
	pinkDeep = C(255, 120, 165),
	mint = C(168, 230, 207),
	sky = C(160, 216, 247),
	choc = C(107, 66, 38),
	chocDark = C(74, 44, 26),
	honey = C(232, 186, 128), -- wood fallback
	lemon = C(255, 236, 140),
	lavender = C(205, 180, 245),
	peach = C(255, 204, 168),
	white = C(255, 255, 255),
	gold = C(255, 205, 70),
	ink = C(40, 30, 48),
	tileA = C(252, 236, 214), -- plaza checker: off-white tiles washed out to pure white in Studio's sun
	tileB = C(255, 200, 218),
}
Config.StationColors = { C(255, 179, 199), C(168, 230, 207), C(160, 216, 247), C(255, 226, 130), C(205, 180, 245), C(255, 196, 160) }

-- Round timing (seconds) ----------------------------------------------------------------------------
Config.Round = {
	firstWait = 14, -- first round starts within ~20 s of the first join
	intermission = 10,
	theme = 6,
	build = 150, -- DTI 360 s, Style Showdown 180 s: 100 s felt rushed (FIXES B.5)
	overtime = 30, -- +30 s Build Time pass (whole server)
	personal = 60, -- Overtime product: keep decorating while the first cakes are judged, shown last
	showMin = 5,
	showMax = 7,
	judgeAt = 0.5, -- fraction of a showcase slot when judges lift their cards
	results = 6,
	giant = 8,
	grace = 40, -- a late joiner gets at least this much build time...
	graceCap = 30, -- ...but the phase never grows by more than this per round
	minEntrants = 4, -- NPC bakers fill up to this many cakes
	eventEvery = 600, -- Celebrity Judge round every ~10 minutes
	earlyEndMin = 25, -- "I'm done" can end the build after this many seconds
	hourlyMult = 3, -- the Hourly Grand Gala (a bigger Celebrity round at :00) pays 3x
	hourlyBoost = 600, -- ...and starts a 10-minute server 2x coins boost
}

-- World geometry --------------------------------------------------------------------------------------
Config.World = {
	stationR = 54,
	stationCount = 12,
	slots = 13, -- slot 0 is the entrance gap facing the spawn
	spawn = V(0, 0.6, 70),
	plazaR = 74,
	stageR = 16,
	stageTop = 3.05,
	turntable = V(0, 3.75, 0), -- top centre of the turntable
	podium = { V(0, 7.05, -9.5), V(-6, 5.85, -9.5), V(6, 5.05, -9.5) }, -- top centres: 1st, 2nd, 3rd
	judgeX = 11,
	judgeZ = { -4.5, -1.5, 4.5 },
	celebZ = 1.5,
	voteCam = { pos = V(0, 11, 25), look = V(0, 7.5, 0) },
	resultCam = { pos = V(0, 12, 27), look = V(0, 7, -6) },
	giant = V(0, 0.35, 30), -- the winning cake grows giant here (plaza, in front of the stage)
	giantScale = 3,
	giantCam = { pos = V(0, 17, 57), look = V(0, 12, 30) }, -- inside the welcome arch
}
-- Station i sits on a ring around the stage, facing the centre (local -Z points at the stage).
function Config.stationCF(i: number): CFrame
	local a = math.rad(i * 360 / Config.World.slots)
	local pos = V(math.sin(a) * Config.World.stationR, 0, math.cos(a) * Config.World.stationR)
	return CFrame.lookAt(pos, V(0, 0, 0))
end
Config.Station = {
	floorTop = 0.5,
	root = CFrame.new(0, 4.1, 1), -- cake root (top of the plate), local to the station
	pad = V(0, 0.5, -8.5), -- where the baker stands
	buildRange = 16, -- studs from the pad that count as "at your station"
}

-- Cake geometry ----------------------------------------------------------------------------------------
Config.Cake = {
	tierR = { 5, 3.9, 2.9, 2.0 },
	tierH = { 3.0, 2.7, 2.4, 2.1 },
	freeTiers = 3,
	tier4Price = 500,
	baseLimit = 24,
	slotUpgrades = { 350, 750, 1500 }, -- each +4 toppings
	slotStep = 4,
	passSlots = 12,
	sizes = { 0.7, 1, 1.4 },
	sizeNames = { "S", "M", "L" },
	rotSteps = 8,
}

-- Colours (frosting, drips, piping, topping tint) ------------------------------------------------------
-- pass = sold in that game pass; event = only from the Caketober track (owned once claimed)
export type ColorDef = { key: string, name: string, color: Color3, price: number, pass: string?, event: boolean?, gloss: number?, neon: boolean?, special: string? }
Config.Colors = {
	{ key = "Vanilla", name = "Vanilla", color = C(255, 244, 222), price = 0 },
	{ key = "Pink", name = "Strawberry", color = C(255, 172, 196), price = 0 },
	{ key = "Mint", name = "Mint", color = C(160, 228, 200), price = 0 },
	{ key = "Sky", name = "Sky Blue", color = C(150, 210, 250), price = 0 },
	{ key = "Chocolate", name = "Chocolate", color = C(112, 68, 40), price = 0 },
	{ key = "Lemon", name = "Lemon", color = C(255, 232, 120), price = 0 },
	{ key = "White", name = "Whipped White", color = C(252, 252, 255), price = 60 },
	{ key = "Lavender", name = "Lavender", color = C(200, 172, 245), price = 80 },
	{ key = "Peach", name = "Peach", color = C(255, 196, 160), price = 80 },
	{ key = "Bubblegum", name = "Bubblegum", color = C(255, 110, 190), price = 120 },
	{ key = "Cherry", name = "Cherry Red", color = C(232, 52, 74), price = 120 },
	{ key = "Orange", name = "Tangerine", color = C(255, 148, 52), price = 120 },
	{ key = "Lime", name = "Lime", color = C(150, 225, 80), price = 150 },
	{ key = "Teal", name = "Teal", color = C(50, 196, 190), price = 150 },
	{ key = "Caramel", name = "Caramel", color = C(212, 140, 62), price = 150 },
	{ key = "Grape", name = "Grape", color = C(132, 64, 186), price = 200 },
	{ key = "Navy", name = "Midnight", color = C(42, 52, 112), price = 200 },
	{ key = "Licorice", name = "Licorice", color = C(38, 34, 44), price = 220 },
	{ key = "Gold", name = "Gold Shimmer", color = C(255, 200, 60), price = 0, pass = "PremiumColors", gloss = 0.35 },
	{ key = "Silver", name = "Silver", color = C(205, 212, 224), price = 0, pass = "PremiumColors", gloss = 0.4 },
	{ key = "RoseGold", name = "Rose Gold", color = C(240, 168, 158), price = 0, pass = "PremiumColors", gloss = 0.35 },
	{ key = "Pearl", name = "Pearl", color = C(246, 240, 255), price = 0, pass = "PremiumColors", gloss = 0.3 },
	{ key = "Galaxy", name = "Galaxy", color = C(44, 28, 92), price = 0, pass = "PremiumColors", special = "galaxy" },
	{ key = "Electric", name = "Electric Pink", color = C(255, 70, 180), price = 0, pass = "PremiumColors", neon = true },
	{ key = "Rainbow", name = "Rainbow", color = C(255, 120, 120), price = 0, pass = "Rainbow", special = "rainbow" },
	-- Caketober track rewards
	{ key = "Slime", name = "Slime Green", color = C(120, 240, 70), price = 0, event = true, neon = true },
	{ key = "PumpkinSpice", name = "Pumpkin Spice", color = C(226, 120, 40), price = 0, event = true, gloss = 0.1 },
	{ key = "WitchPurple", name = "Witch Purple", color = C(104, 44, 150), price = 0, event = true, gloss = 0.2 },
} :: { ColorDef }
Config.ColorByKey = {} :: { [string]: ColorDef }
for _, c in ipairs(Config.Colors) do
	Config.ColorByKey[c.key] = c
end
Config.Rainbow = { C(255, 92, 92), C(255, 170, 60), C(255, 230, 80), C(110, 220, 110), C(90, 170, 255), C(170, 110, 255) }

-- Shapes -----------------------------------------------------------------------------------------------
export type ShapeDef = { key: string, name: string, glyph: string, price: number }
Config.Shapes = {
	{ key = "Round", name = "Round", glyph = "⚪", price = 0 },
	{ key = "Square", name = "Square", glyph = "⬜", price = 0 },
	{ key = "Heart", name = "Heart", glyph = "💗", price = 300 },
	{ key = "Hexagon", name = "Hexagon", glyph = "🔷", price = 600 },
	{ key = "Star", name = "Star", glyph = "⭐", price = 1500 },
} :: { ShapeDef }
Config.ShapeByKey = {} :: { [string]: ShapeDef }
for _, s in ipairs(Config.Shapes) do
	Config.ShapeByKey[s.key] = s
end

-- Toppings (the collection) -------------------------------------------------------------------------
-- source: "free" (starter), "shop" (coins), "box" (Mystery Sprinkle Box only), "vip" (VIP pass),
--         "event" (Caketober track only: never in boxes)
export type ToppingDef = {
	id: string,
	name: string,
	tier: string,
	glyph: string,
	price: number,
	source: string,
	tint: Color3?, -- default colour of the tintable part (nil = not tintable)
	topOnly: boolean?,
	mesh: string?,
}
Config.Toppings = {
	-- Common
	{ id = "Sprinkles", name = "Sprinkles", tier = "Common", glyph = "🎊", price = 0, source = "free" },
	{ id = "Cherry", name = "Cherry", tier = "Common", glyph = "🍒", price = 0, source = "free" },
	{ id = "Candle", name = "Candle", tier = "Common", glyph = "🕯️", price = 0, source = "free", tint = C(130, 200, 255), topOnly = true },
	{ id = "Pearls", name = "Sugar Pearls", tier = "Common", glyph = "⚪", price = 0, source = "free", tint = C(250, 250, 255) },
	{ id = "Swirl", name = "Cream Swirl", tier = "Common", glyph = "🍥", price = 0, source = "free", tint = C(255, 250, 244) },
	{ id = "Leaf", name = "Mint Leaves", tier = "Common", glyph = "🍃", price = 75, source = "shop" },
	{ id = "ChocChunk", name = "Choco Chunks", tier = "Common", glyph = "🍫", price = 90, source = "shop" },
	-- Uncommon
	{ id = "Strawberry", name = "Strawberry", tier = "Uncommon", glyph = "🍓", price = 120, source = "shop", mesh = "Strawberry" },
	{ id = "Candy", name = "Wrapped Candy", tier = "Uncommon", glyph = "🍬", price = 150, source = "shop", tint = C(255, 120, 190) },
	{ id = "Blueberry", name = "Blueberries", tier = "Uncommon", glyph = "🍇", price = 160, source = "shop" },
	{ id = "HeartCandy", name = "Candy Heart", tier = "Uncommon", glyph = "💗", price = 200, source = "shop", tint = C(255, 110, 160) },
	{ id = "Bubbles", name = "Sugar Bubbles", tier = "Uncommon", glyph = "💧", price = 220, source = "shop" },
	{ id = "Lollipop", name = "Lollipop", tier = "Uncommon", glyph = "🍭", price = 240, source = "shop", tint = C(255, 90, 170), topOnly = true },
	-- Rare
	{ id = "Cookie", name = "Cookie", tier = "Rare", glyph = "🍪", price = 380, source = "shop" },
	{ id = "Flower", name = "Sugar Flower", tier = "Rare", glyph = "🌸", price = 400, source = "shop", tint = C(255, 150, 200) },
	{ id = "Shell", name = "Seashell", tier = "Rare", glyph = "🐚", price = 440, source = "shop" },
	{ id = "Star", name = "Gold Star", tier = "Rare", glyph = "⭐", price = 450, source = "shop", tint = C(255, 205, 60), topOnly = true },
	{ id = "Snowflake", name = "Snowflake", tier = "Rare", glyph = "❄️", price = 460, source = "shop", topOnly = true },
	{ id = "Ghost", name = "Little Ghost", tier = "Rare", glyph = "👻", price = 480, source = "shop", topOnly = true },
	{ id = "Donut", name = "Mini Donut", tier = "Rare", glyph = "🍩", price = 520, source = "shop", tint = C(255, 130, 180) },
	{ id = "Cupcake", name = "Mini Cupcake", tier = "Rare", glyph = "🧁", price = 560, source = "shop", tint = C(140, 220, 200), topOnly = true, mesh = "Cupcake" },
	-- Epic
	{ id = "Pumpkin", name = "Pumpkin", tier = "Epic", glyph = "🎃", price = 850, source = "shop", topOnly = true },
	{ id = "Palm", name = "Mini Palm", tier = "Epic", glyph = "🌴", price = 900, source = "shop", topOnly = true },
	{ id = "Butterfly", name = "Butterfly", tier = "Epic", glyph = "🦋", price = 950, source = "shop", tint = C(130, 200, 255) },
	{ id = "IceCream", name = "Ice Cream Cone", tier = "Epic", glyph = "🍦", price = 1000, source = "shop", topOnly = true },
	{ id = "Rainbow", name = "Rainbow Arch", tier = "Epic", glyph = "🌈", price = 1100, source = "shop", topOnly = true },
	{ id = "Crown", name = "Royal Crown", tier = "Epic", glyph = "👑", price = 1200, source = "shop", topOnly = true, mesh = "Crown" },
	{ id = "Rocket", name = "Rocket", tier = "Epic", glyph = "🚀", price = 1300, source = "shop", topOnly = true },
	{ id = "Bow", name = "Silk Bow", tier = "Epic", glyph = "🎀", price = 0, source = "vip", tint = C(232, 50, 100) },
	-- Legendary
	{ id = "Planet", name = "Ringed Planet", tier = "Legendary", glyph = "🪐", price = 2800, source = "shop", topOnly = true },
	{ id = "Castle", name = "Fairy Castle", tier = "Legendary", glyph = "🏰", price = 3200, source = "shop", topOnly = true, mesh = "Castle" },
	{ id = "Unicorn", name = "Unicorn Horn", tier = "Legendary", glyph = "🦄", price = 0, source = "box", topOnly = true, mesh = "Unicorn" },
	{ id = "Diamond", name = "Sugar Diamond", tier = "Legendary", glyph = "💎", price = 0, source = "box", topOnly = true },
	{ id = "Ring", name = "Diamond Ring", tier = "Legendary", glyph = "💍", price = 0, source = "vip", topOnly = true },
	{ id = "Swan", name = "Sugar Swan", tier = "Legendary", glyph = "🦢", price = 0, source = "vip", topOnly = true, mesh = "Swan" },
	-- Mythic
	{ id = "GalaxyOrb", name = "Galaxy Orb", tier = "Mythic", glyph = "🔮", price = 0, source = "box", topOnly = true },
	{ id = "Sparkler", name = "Sparklers", tier = "Mythic", glyph = "🎇", price = 0, source = "box", topOnly = true },
	-- Secret
	{ id = "Trophy", name = "Golden Trophy", tier = "Secret", glyph = "🏆", price = 0, source = "box", topOnly = true, mesh = "Trophy" },
	-- Caketober (track rewards, see Config.Track)
	{ id = "CandyEyes", name = "Candy Eyes", tier = "Uncommon", glyph = "👀", price = 0, source = "event" },
	{ id = "Bat", name = "Little Bat", tier = "Rare", glyph = "🦇", price = 0, source = "event" },
	{ id = "Spider", name = "Jelly Spider", tier = "Rare", glyph = "🕷️", price = 0, source = "event" },
	{ id = "Web", name = "Sugar Web", tier = "Epic", glyph = "🕸️", price = 0, source = "event", topOnly = true },
	{ id = "WitchHat", name = "Witch Hat", tier = "Epic", glyph = "🧙", price = 0, source = "event", topOnly = true, tint = C(110, 50, 160) },
	{ id = "Cauldron", name = "Bubbling Cauldron", tier = "Legendary", glyph = "🍲", price = 0, source = "event", topOnly = true },
	{ id = "Moon", name = "Haunted Moon", tier = "Mythic", glyph = "🌙", price = 0, source = "event", topOnly = true },
} :: { ToppingDef }
Config.ToppingById = {} :: { [string]: ToppingDef }
for _, t in ipairs(Config.Toppings) do
	Config.ToppingById[t.id] = t
end

-- Mystery Sprinkle Box: pick a tier by weight, then a topping of that tier from the box pool -----------
Config.Box = {
	price = 300, -- coins
	odds = {
		{ key = "Uncommon", weight = 50 },
		{ key = "Rare", weight = 30 },
		{ key = "Epic", weight = 14 },
		{ key = "Legendary", weight = 4.9 },
		{ key = "Mythic", weight = 1 },
		{ key = "Secret", weight = 0.1 },
	},
	luck = 2.5, -- Lucky Sprinkles product (multiplies with a server luck boost)
	luckSeconds = 900,
	blockedCoins = 300, -- a paid box a RandomBlocked player still holds opens as this many coins instead
	refund = { Common = 20, Uncommon = 40, Rare = 100, Epic = 250, Legendary = 600, Mythic = 1500, Secret = 5000 } :: { [string]: number },
	firstTier = "Rare", -- the very first box is at least Rare (FTUE rare moment)
}
-- Box pool by tier: every non-free, non-VIP topping from Uncommon up.
Config.BoxPool = {} :: { [string]: { string } }
for _, t in ipairs(Config.Toppings) do
	if (t.source == "shop" or t.source == "box") and t.tier ~= "Common" then
		Config.BoxPool[t.tier] = Config.BoxPool[t.tier] or {}
		table.insert(Config.BoxPool[t.tier], t.id)
	end
end

-- Server boost multiplier (kit Boosts keeps it in ReplicatedStorage attributes, so both sides can read it).
function Config.serverBoost(kind: string): number
	local rs = game:GetService("ReplicatedStorage")
	local ends = rs:GetAttribute("BoostEnd_" .. kind)
	if type(ends) ~= "number" or ends <= workspace:GetServerTimeNow() then
		return 1
	end
	local m = rs:GetAttribute("Boost_" .. kind)
	return if type(m) == "number" then m else 1
end

-- Box luck right now: Lucky Sprinkles (personal) x a server luck boost. The odds shown use the same number.
function Config.boxLuck(luckUntil: number?): number
	local personal = if (luckUntil or 0) > os.time() then Config.Box.luck else 1
	return personal * Config.serverBoost("luck")
end

-- Chance (percent) of one topping from a box: tier chance x its share of the tier. A duplicate re-rolls once
-- inside the tier, so unowned toppings are a little likelier: share = 1/n if unowned, plus k/n * 1/n where k
-- toppings of the tier are owned. Matches Progress.openBox exactly.
function Config.itemOdds(id: string, owned: { [string]: boolean }, luck: number, percents: { [string]: number }): number
	local def = Config.ToppingById[id]
	local pool = def and Config.BoxPool[def.tier]
	if not def or not pool or not table.find(pool, id) then
		return 0
	end
	local n, k = #pool, 0
	for _, other in ipairs(pool) do
		if owned[other] then
			k += 1
		end
	end
	local share = (if owned[id] then 0 else 1 / n) + (k / n) * (1 / n)
	return (percents[def.tier] or 0) * share
end

-- Themes -------------------------------------------------------------------------------------------------
export type ThemeDef = { key: string, name: string, glyph: string, toppings: { string }, colors: { string }, shapes: { string } }
Config.Themes = {
	{ key = "Birthday", name = "Birthday Bash", glyph = "🎉", toppings = { "Candle", "Sprinkles", "Star", "Cherry", "Cupcake", "Swirl", "Sparkler" }, colors = { "Pink", "Sky", "Lemon", "Mint", "Bubblegum" }, shapes = { "Round" } },
	{ key = "Rainbow", name = "Over the Rainbow", glyph = "🌈", toppings = { "Rainbow", "Sprinkles", "Star", "Lollipop", "Candy", "Unicorn" }, colors = { "Rainbow", "Cherry", "Orange", "Lemon", "Lime", "Sky", "Grape" }, shapes = { "Star" } },
	{ key = "Spooky", name = "Spooky Night", glyph = "🎃", toppings = { "Pumpkin", "Ghost", "Candy", "ChocChunk", "Star", "Bat", "Spider", "CandyEyes", "WitchHat", "Web", "Cauldron", "Moon" }, colors = { "Licorice", "Orange", "Grape", "Lime", "Slime", "PumpkinSpice", "WitchPurple" }, shapes = { "Hexagon" } },
	{ key = "Jungle", name = "Jungle Party", glyph = "🌴", toppings = { "Palm", "Leaf", "Butterfly", "Flower", "Strawberry" }, colors = { "Lime", "Mint", "Chocolate", "Caramel" }, shapes = { "Round" } },
	{ key = "Princess", name = "Princess Palace", glyph = "👑", toppings = { "Crown", "Castle", "HeartCandy", "Flower", "Pearls", "Bow", "Diamond" }, colors = { "Pink", "Lavender", "White", "Bubblegum", "Gold" }, shapes = { "Heart" } },
	{ key = "Space", name = "Outer Space", glyph = "🚀", toppings = { "Planet", "Rocket", "Star", "GalaxyOrb", "Sparkler", "Pearls" }, colors = { "Navy", "Licorice", "Grape", "Galaxy", "Silver" }, shapes = { "Star" } },
	{ key = "Ocean", name = "Under the Sea", glyph = "🌊", toppings = { "Shell", "Bubbles", "Pearls", "Blueberry", "Swirl" }, colors = { "Sky", "Teal", "White", "Navy", "Pearl" }, shapes = { "Round" } },
	{ key = "CandyLand", name = "Candy Land", glyph = "🍭", toppings = { "Lollipop", "Candy", "Donut", "Cupcake", "IceCream", "Sprinkles", "HeartCandy" }, colors = { "Bubblegum", "Mint", "Pink", "Lemon", "Lavender" }, shapes = { "Square" } },
	{ key = "Winter", name = "Winter Wonderland", glyph = "❄️", toppings = { "Snowflake", "Pearls", "Star", "Swirl", "Diamond" }, colors = { "White", "Sky", "Silver", "Navy", "Pearl" }, shapes = { "Hexagon" } },
	{ key = "Fruit", name = "Fruit Party", glyph = "🍓", toppings = { "Strawberry", "Cherry", "Blueberry", "Leaf", "Swirl" }, colors = { "Pink", "Cherry", "Peach", "Lemon", "Vanilla" }, shapes = { "Round" } },
	{ key = "Wedding", name = "Dream Wedding", glyph = "💍", toppings = { "Swirl", "Pearls", "Flower", "Swan", "Ring", "Bow" }, colors = { "White", "Vanilla", "Pearl", "Pink", "Gold" }, shapes = { "Heart", "Round" } },
	{ key = "Chocolate", name = "Chocolate Lover", glyph = "🍫", toppings = { "ChocChunk", "Cookie", "Cherry", "Strawberry", "Swirl" }, colors = { "Chocolate", "Caramel", "Vanilla", "Licorice" }, shapes = { "Square" } },
	-- Celebrity Judge specials
	{ key = "Royal", name = "Royal Banquet", glyph = "🏰", toppings = { "Crown", "Castle", "Diamond", "Ring", "Pearls", "Star" }, colors = { "Gold", "Lavender", "Navy", "White" }, shapes = { "Hexagon", "Heart" } },
	{ key = "Gala", name = "Galaxy Gala", glyph = "🌌", toppings = { "Planet", "GalaxyOrb", "Rocket", "Star", "Sparkler" }, colors = { "Galaxy", "Navy", "Grape", "Licorice" }, shapes = { "Star" } },
	{ key = "UnicornDream", name = "Unicorn Dream", glyph = "🦄", toppings = { "Unicorn", "Rainbow", "Star", "Flower", "Swirl" }, colors = { "Rainbow", "Lavender", "Pink", "Sky" }, shapes = { "Heart", "Star" } },
	{ key = "Golden", name = "Golden Gala", glyph = "🏆", toppings = { "Trophy", "Crown", "Star", "Sparkler", "Diamond" }, colors = { "Gold", "White", "Licorice", "RoseGold" }, shapes = { "Round", "Star" } },
	{ key = "Haunted", name = "Haunted Gala", glyph = "🦇", toppings = { "Moon", "Bat", "Cauldron", "WitchHat", "Ghost", "Pumpkin", "Web", "Spider" }, colors = { "Licorice", "WitchPurple", "Slime", "Orange", "PumpkinSpice" }, shapes = { "Hexagon", "Star" } },
} :: { ThemeDef }
Config.RegularThemes = 12 -- the first 12 are regular, the rest are Celebrity specials
Config.ThemeByKey = {} :: { [string]: ThemeDef }
for _, t in ipairs(Config.Themes) do
	Config.ThemeByKey[t.key] = t
end

-- Judges and NPC bakers -----------------------------------------------------------------------------
Config.Judges = {
	{ name = "Chef Crumble", hat = "chef", coat = C(255, 255, 255), skin = C(255, 214, 180), focus = "effort" },
	{ name = "Madame Fondant", hat = "beret", coat = C(255, 190, 215), skin = C(240, 190, 150), focus = "theme" },
	{ name = "Sir Sprinkles", hat = "top", coat = C(170, 210, 255), skin = C(205, 150, 110), focus = "flair" },
}
Config.Celebrity = { name = "Chef Gateau", hat = "gold", coat = C(255, 236, 170), skin = C(170, 115, 80) }
Config.BotNames = { "Chef Biscuit", "Auntie Muffin", "Baker Bao", "Granny Gumdrop", "Pierre Pastry", "Captain Cupcake", "Lil' Waffles", "Dr. Donut" }
Config.BotSkin = { C(255, 214, 180), C(240, 190, 150), C(205, 150, 110), C(170, 115, 80), C(120, 80, 55) }

-- Rewards, levels, daily -------------------------------------------------------------------------------
Config.Rewards = {
	participate = 25,
	perStar = 25,
	place = { 100, 60, 30 },
	vote = 3,
	voteCap = 12, -- vote coins per round at most
	xpBase = 30,
	xpPerStar = 15,
	xpPlace = { 60, 40, 20 },
	celebrityMult = 2,
	vipMult = 1.2,
	goldenXp = 1.25,
	newTopping = 15, -- XP for every new Index entry
	indexMilestones = { 10, 20, 30 }, -- free Mystery Box at each
	ftue = { frost = 25, topping = 25 } :: { [string]: number }, -- one-time coins: first frosting / first topping
	fair = 2, -- coins for a rating within 1 star of the cake's final score ("fair judge")
	fairCap = 12, -- fair-judge coins per round at most
	flagAt = 3, -- 1-star ratings on cakes that scored 3.5+: after this many in a session a voter counts 0.3x
	flagWeight = 0.3,
}
function Config.xpFor(level: number): number
	return 60 + 45 * level
end
Config.Titles = {
	{ 1, "Kitchen Helper" },
	{ 3, "Sprinkle Scout" },
	{ 5, "Junior Baker" },
	{ 8, "Baker" },
	{ 12, "Pastry Pro" },
	{ 16, "Cake Artist" },
	{ 20, "Frosting Wizard" },
	{ 25, "Master Baker" },
	{ 30, "Cake Boss" },
	{ 40, "Sugar Legend" },
	{ 50, "Grand Patissier" },
}
function Config.title(level: number): string
	local t = "Kitchen Helper"
	for _, row in ipairs(Config.Titles) do
		if level >= (row[1] :: number) then
			t = row[2] :: string
		end
	end
	return t
end
Config.Daily = { 50, 80, 120, 160, 220, 300, 400 } -- day 7 also gives a Mystery Box
Config.DailyCooldown = 20 * 3600
Config.DailyReset = 48 * 3600

-- Monetization ladder (FIXES A.P1.4). ids are 0 until tools/launch.py creates them; Studio simulates purchases.
-- Keep every item on ONE line: tools/launch.py reads the name/price/desc of each `id = 0` line.
-- Kit fields: once (one purchase per player), random (paid random item: refused under Roblox's paid-random
-- restriction, kit Policy), gift = "PassKey" (gift copy of that pass), boost (server-wide timed boost).
-- Game fields: section (where the Robux shop lists it), order (sort inside the section).
export type BoostDef = { kind: string, mult: number, minutes: number, needs: number?, label: string }
export type ProductDef = {
	id: number,
	name: string,
	price: number,
	glyph: string,
	desc: string,
	order: number,
	section: string?,
	once: boolean?,
	random: boolean?,
	gift: string?,
	boost: BoostDef?,
	intro: boolean?, -- kit Shop: refused once the player has spent anything
	window: number?, -- kit Shop: refused after this many seconds of the player's first session
}
Config.Passes = {
	Rainbow = { id = 0, name = "Rainbow Frosting", price = 79, glyph = "🌈", desc = "Layered rainbow frosting + rainbow drips", order = 1 },
	PremiumColors = { id = 0, name = "Premium Colours", price = 99, glyph = "✨", desc = "Gold, Silver, Rose Gold, Pearl, Galaxy, Electric Pink", order = 2 },
	ExtraToppings = { id = 0, name = "Topping Tray+", price = 99, glyph = "🍬", desc = "+12 toppings on every cake", order = 3 },
	ExtraTime = { id = 0, name = "+30s Build Time", price = 149, glyph = "⏰", desc = "+30 s build time for you AND your whole server", order = 4 },
	DoubleCoins = { id = 0, name = "2x Coins", price = 249, glyph = "💰", desc = "Double coins from every round, forever", order = 5 },
	VIP = { id = 0, name = "VIP Bakery", price = 299, glyph = "👑", desc = "3 VIP toppings, VIP tag, +20% coins", order = 6 },
	Caketober = { id = 0, name = "Caketober Pass", price = 399, glyph = "🎃", desc = "Premium Caketober rewards on all 30 tiers: Witch Hat, Cauldron, Haunted Moon, Slime frosting, 🎃 tag", order = 7 },
	GoldenOven = { id = 0, name = "Golden Oven", price = 1299, glyph = "🏆", desc = "Golden station + sparkle aura + golden tag, +25% XP", order = 8 },
} :: { [string]: ProductDef }
Config.Products = {
	-- deals
	Intro = { id = 0, name = "Baker's Treat", price = 9, once = true, intro = true, glyph = "🍰", desc = "2,000 coins + Mini Cupcake topping (first purchase only)", order = 1, section = "deal" },
	Starter = { id = 0, name = "Starter Pack", price = 49, once = true, window = 600, glyph = "🧁", desc = "2,000 coins + 3 Mystery Boxes (once)", order = 2, section = "deal" },
	Coins6Deal = { id = 0, name = "250,000 Coins First-Time Deal", price = 1199, once = true, glyph = "🏦", desc = "-40% the first time: 250,000 coins", order = 3, section = "deal" },
	-- server boosts (15 minutes, the whole server, buyer shoutout)
	SrvXP = { id = 0, name = "2x XP Server Boost", price = 79, glyph = "⭐", desc = "2x XP stars for EVERYONE for 15 minutes", order = 1, section = "boost", boost = { kind = "xp", mult = 2, minutes = 15, label = "XP" } },
	SrvCoins2 = { id = 0, name = "2x Coins Server Boost", price = 99, glyph = "⚡", desc = "2x coins for EVERYONE for 15 minutes", order = 2, section = "boost", boost = { kind = "coins", mult = 2, minutes = 15, label = "COINS" } },
	SrvParty = { id = 0, name = "Full Bakery Party", price = 199, glyph = "🎉", desc = "2x coins AND 2x XP for everyone, 15 minutes", order = 3, section = "boost" },
	SrvCoins4 = { id = 0, name = "4x Coins Server Boost", price = 249, glyph = "⚡", desc = "4x coins for everyone, 15 min (while 2x runs)", order = 4, section = "boost", boost = { kind = "coins", mult = 4, minutes = 15, needs = 2, label = "COINS" } },
	SrvCoins8 = { id = 0, name = "8x Coins Server Boost", price = 499, glyph = "⚡", desc = "8x coins for everyone, 15 min (while 4x runs)", order = 5, section = "boost", boost = { kind = "coins", mult = 8, minutes = 15, needs = 4, label = "COINS" } },
	SrvLuck2 = { id = 0, name = "Server Lucky Sprinkles", price = 149, random = true, glyph = "🍀", desc = "2x box luck for everyone for 15 minutes", order = 6, section = "boost", boost = { kind = "luck", mult = 2, minutes = 15, label = "LUCK" } },
	SrvLuck4 = { id = 0, name = "Server Super Luck", price = 349, random = true, glyph = "🍀", desc = "4x box luck for everyone, 15 min (while 2x runs)", order = 7, section = "boost", boost = { kind = "luck", mult = 4, minutes = 15, needs = 2, label = "LUCK" } },
	-- coins
	Coins1 = { id = 0, name = "1,000 Coins", price = 25, glyph = "💰", desc = "A handful of coins", order = 1, section = "coins" },
	Coins2 = { id = 0, name = "6,000 Coins", price = 99, glyph = "💰", desc = "A bag of coins", order = 2, section = "coins" },
	Coins3 = { id = 0, name = "18,000 Coins", price = 249, glyph = "💰", desc = "A vault of coins", order = 3, section = "coins" },
	Coins4 = { id = 0, name = "45,000 Coins", price = 499, glyph = "💰", desc = "A bakery safe full of coins", order = 4, section = "coins" },
	Coins5 = { id = 0, name = "110,000 Coins", price = 999, glyph = "💰", desc = "A coin mountain", order = 5, section = "coins" },
	Coins6 = { id = 0, name = "250,000 Coins", price = 1999, glyph = "🏦", desc = "The whole coin bank", order = 6, section = "coins" },
	-- boxes and luck (paid random: odds in the Box menu)
	Box1 = { id = 0, name = "Mystery Sprinkle Box", price = 29, random = true, glyph = "🎁", desc = "1 box, odds shown in the Box menu", order = 1, section = "box" },
	Luck = { id = 0, name = "Lucky Sprinkles", price = 39, random = true, glyph = "🍀", desc = "2.5x luck on your boxes for 15 minutes", order = 2, section = "box" },
	Box5 = { id = 0, name = "5 Mystery Boxes", price = 119, random = true, glyph = "🎁", desc = "5 boxes, odds shown in the Box menu", order = 3, section = "box" },
	Box15 = { id = 0, name = "15 Mystery Boxes", price = 299, random = true, glyph = "🎁", desc = "15 boxes, odds shown in the Box menu", order = 4, section = "box" },
	-- this round
	React1 = { id = 0, name = "Sprinkle Burst", price = 29, glyph = "🎊", desc = "Cheer the cake on the turntable: sprinkle explosion + 50 coins for its baker", order = 1, section = "round" },
	React2 = { id = 0, name = "Golden Spatula", price = 39, glyph = "🥄", desc = "A golden salute to the cake on show + 100 coins for its baker", order = 2, section = "round" },
	Overtime = { id = 0, name = "Overtime +60s", price = 39, glyph = "⏰", desc = "Keep decorating while the others are judged (up to +60 s). Your cake goes last", order = 3, section = "round" },
	React3 = { id = 0, name = "Chef's Kiss", price = 49, glyph = "💋", desc = "The biggest compliment: hearts for the cake on show + 150 coins for its baker", order = 4, section = "round" },
	PickTheme = { id = 0, name = "Pick Next Theme", price = 49, glyph = "🎡", desc = "Choose the next round's theme for the server", order = 5, section = "round" },
	-- Caketober track skips
	Track1 = { id = 0, name = "Caketober +1 Tier", price = 29, glyph = "🍬", desc = "Skip ahead 1 Caketober tier", order = 1, section = "track" },
	Track5 = { id = 0, name = "Caketober +5 Tiers", price = 119, glyph = "🍬", desc = "Skip ahead 5 Caketober tiers", order = 2, section = "track" },
	Track10 = { id = 0, name = "Caketober +10 Tiers", price = 199, glyph = "🍬", desc = "Skip ahead 10 Caketober tiers", order = 3, section = "track" },
	-- gift copies of every pass (shown next to each pass)
	GiftRainbow = { id = 0, name = "Gift: Rainbow Frosting", price = 79, gift = "Rainbow", glyph = "🎁", desc = "Rainbow Frosting for a player in your server", order = 1, section = "gift" },
	GiftPremiumColors = { id = 0, name = "Gift: Premium Colours", price = 99, gift = "PremiumColors", glyph = "🎁", desc = "Premium Colours for a player in your server", order = 2, section = "gift" },
	GiftExtraToppings = { id = 0, name = "Gift: Topping Tray+", price = 99, gift = "ExtraToppings", glyph = "🎁", desc = "Topping Tray+ for a player in your server", order = 3, section = "gift" },
	GiftExtraTime = { id = 0, name = "Gift: +30s Build Time", price = 149, gift = "ExtraTime", glyph = "🎁", desc = "+30s Build Time for a player in your server", order = 4, section = "gift" },
	GiftDoubleCoins = { id = 0, name = "Gift: 2x Coins", price = 249, gift = "DoubleCoins", glyph = "🎁", desc = "2x Coins for a player in your server", order = 5, section = "gift" },
	GiftVIP = { id = 0, name = "Gift: VIP Bakery", price = 299, gift = "VIP", glyph = "🎁", desc = "VIP Bakery for a player in your server", order = 6, section = "gift" },
	GiftCaketober = { id = 0, name = "Gift: Caketober Pass", price = 399, gift = "Caketober", glyph = "🎁", desc = "Caketober Pass for a player in your server", order = 7, section = "gift" },
	GiftGoldenOven = { id = 0, name = "Gift: Golden Oven", price = 1299, gift = "GoldenOven", glyph = "🎁", desc = "Golden Oven for a player in your server", order = 8, section = "gift" },
} :: { [string]: ProductDef }
-- Robux shop sections, in order (gifts sit next to their pass on the Passes tab instead).
Config.ShopSections = {
	{ key = "deal", title = "🔥 DEALS" },
	{ key = "boost", title = "⚡ SERVER BOOSTS · 15 MIN FOR EVERYONE" },
	{ key = "round", title = "🎂 THIS ROUND" },
	{ key = "coins", title = "💰 COINS" },
	{ key = "box", title = "🎁 MYSTERY BOXES & LUCK" },
	{ key = "track", title = "🎃 CAKETOBER" },
}
-- The Starter Pack holds boxes, so it is not `random`: a player under Roblox's paid-random restriction is shown
-- (and gets) this fixed pack instead. Box products and luck are `random` and hidden from them.
Config.StarterBlocked = { coins = 3500, desc = "3,500 coins (once)" }
-- Reactions on the cake being judged (never touch its score: cheering only).
export type ReactionDef = { name: string, glyph: string, coins: number, color: string }
Config.Reactions = {
	React1 = { name = "Sprinkle Burst", glyph = "🎊", coins = 50, color = "pink" },
	React2 = { name = "Golden Spatula", glyph = "🥄", coins = 100, color = "gold" },
	React3 = { name = "Chef's Kiss", glyph = "💋", coins = 150, color = "red" },
} :: { [string]: ReactionDef }
Config.ReactionOrder = { "React1", "React2", "React3" }
Config.PromptGrace = 120 -- no purchase prompt or offer popup before minute 2 of a player's first session
Config.OfferAfter = 150 -- the starter offer pops up (once) at the first lobby after this many seconds
Config.StarterWindow = Config.Products.Starter.window or 600 -- the starter pack: first 10 minutes of the first session only

-- Caketober prize track (Halloween; FIXES B.5): candy 🍬 from every round fills 30 tiers. The free row pays
-- everyone, the Caketober Pass row adds exclusive toppings and frostings. Ends 2026-11-03 00:00 UTC.
export type TrackReward = { coins: number?, boxes: number?, topping: string?, color: string? }
Config.Track = {
	name = "Caketober",
	ends = 1793664000,
	tiers = 30,
	cost = 100, -- candy per tier
	candy = { round = 10, perStar = 4, place = { 15, 10, 5 }, vote = 1, voteCap = 12, hourly = 2 },
	boxCoins = 300, -- a box reward for a RandomBlocked player (tiers can be bought) is paid as coins
	ownedCoins = 500, -- a topping/frosting reward the player already has is paid as coins
	free = {} :: { TrackReward },
	premium = {} :: { TrackReward },
}
for k = 1, Config.Track.tiers do
	Config.Track.free[k] = { coins = 60 + 10 * k }
	Config.Track.premium[k] = { coins = 200 + 30 * k }
end
for _, k in ipairs({ 5, 10, 20, 25 }) do
	Config.Track.free[k] = { boxes = 1 }
end
Config.Track.free[30] = { boxes = 3 }
Config.Track.free[3] = { topping = "CandyEyes" }
Config.Track.free[9] = { topping = "Bat" }
Config.Track.free[14] = { color = "PumpkinSpice" }
Config.Track.free[18] = { topping = "Spider" }
Config.Track.premium[1] = { color = "Slime" }
Config.Track.premium[6] = { topping = "Web" }
Config.Track.premium[12] = { topping = "WitchHat" }
Config.Track.premium[16] = { color = "WitchPurple" }
Config.Track.premium[22] = { topping = "Cauldron" }
Config.Track.premium[30] = { topping = "Moon" }
Config.TrackSkips = { Track1 = 1, Track5 = 5, Track10 = 10 }

function Config.trackLive(): boolean
	return os.time() < Config.Track.ends
end

-- Tier reached with this much candy (0..30).
function Config.trackTier(candy: number): number
	return math.clamp(math.floor((candy or 0) / Config.Track.cost), 0, Config.Track.tiers)
end

-- Glyph + short text of a track reward; `blocked` = paid-random restricted (boxes show as coins).
function Config.rewardText(r: TrackReward, blocked: boolean): (string, string)
	if r.topping then
		local t = Config.ToppingById[r.topping]
		return t.glyph, t.name
	elseif r.color then
		return "🎨", Config.ColorByKey[r.color].name
	elseif r.boxes then
		if blocked then
			return "💰", tostring(r.boxes * Config.Track.boxCoins)
		end
		return "🎁", r.boxes .. " Box" .. (if r.boxes > 1 then "es" else "")
	end
	return "💰", tostring(r.coins or 0)
end

-- Launch features (kit Live): codes, group gift, playtime gifts, daily quests, badges, invites, friend bonus.
-- Rewards: coins, boxes (free boxes), candy (Caketober). Sized to about one session (~7 rounds ≈ 1,000 coins).
Config.Live = {
	codes = { LAUNCH = { reward = { coins = 500, boxes = 1, text = "500 coins + 1 box" } } },
	group = { id = 0, reward = { coins = 1000, boxes = 2, text = "1,000 coins + 2 boxes" } },
	playtime = {
		{ minutes = 5, reward = { coins = 150, text = "150 coins" } },
		{ minutes = 10, reward = { boxes = 1, text = "1 Mystery Box" } },
		{ minutes = 30, reward = { coins = 500, candy = 50, text = "500 coins + 50 🍬" } },
		{ minutes = 60, reward = { coins = 1000, boxes = 1, text = "1,000 coins + 1 box" } },
	},
	quests = {
		{ key = "bake", text = "Bake 3 cakes", goal = 3, reward = { coins = 300, candy = 20, text = "300 coins + 20 🍬" } },
		{ key = "vote", text = "Rate 15 cakes", goal = 15, reward = { coins = 250, candy = 20, text = "250 coins + 20 🍬" } },
		{ key = "top3", text = "Finish top 3 twice", goal = 2, reward = { coins = 400, candy = 30, text = "400 coins + 30 🍬" } },
		{ key = "stars", text = "Score ⭐ 4+ on a cake", goal = 1, reward = { boxes = 1, candy = 20, text = "1 box + 20 🍬" } },
		{ key = "toppings", text = "Place 40 toppings", goal = 40, reward = { coins = 300, candy = 20, text = "300 coins + 20 🍬" } },
		{ key = "theme", text = "Use 10 🎯 theme toppings", goal = 10, reward = { coins = 350, candy = 20, text = "350 coins + 20 🍬" } },
		{ key = "friend", text = "Bake a round with a friend", goal = 1, reward = { coins = 500, boxes = 1, text = "500 coins + 1 box" } },
		{ key = "celebrity", text = "Bake in a Celebrity round", goal = 1, reward = { coins = 400, candy = 30, text = "400 coins + 30 🍬" } },
	},
	badges = { Welcome = 0, FirstCake = 0, FirstWin = 0, StarBaker = 0, TenWins = 0, Collector = 0 },
	invite = { reward = { coins = 500, boxes = 1, text = "500 coins + 1 box" } },
	friendBonus = 0.1,
}

-- Hero meshes: AI-generated later (ids 0 now). Every use has a primitive fallback in CakeBuilder.
export type MeshDef = { mesh: number, texture: number, size: Vector3, prompt: string }
Config.Meshes = {
	Strawberry = { mesh = 72286654626933, texture = 73990870392776, size = V(1.2, 1.6, 1.2), prompt = "a single strawberry, smooth glossy red, small green leaf crown on top, simple clean shapes, perfectly symmetrical" },
	Cupcake = { mesh = 123533505763956, texture = 135150338837295, size = V(1.2, 1.9, 1.2), prompt = "a small cupcake, mint paper cup with vertical ridges, round pink frosting swirl, one cherry on top, simple clean shapes" },
	Crown = { mesh = 131565692711917, texture = 113126380971214, size = V(1.8, 1.3, 1.8), prompt = "small gold crown, five rounded points with balls on the tips, one red round gem in front, smooth simple clean shapes" },
	Castle = { mesh = 122776006740492, texture = 110674373510744, size = V(1.6, 3, 1.6), prompt = "one round white tower with a pink cone roof and a small gold flag, simple clean shapes, toy style" },
	Unicorn = { mesh = 129109824156526, texture = 106955847148753, size = V(1.8, 2.2, 1.2), prompt = "a spiral unicorn horn with gold and white stripes, two small white ears at its base, smooth simple shapes" },
	Swan = { mesh = 89223478440388, texture = 92588257747924, size = V(1.2, 1.8, 1.8), prompt = "a small white swan sitting, curved neck, orange beak, wings folded, smooth simple clean shapes" },
	Trophy = { mesh = 102615103051898, texture = 84777282490244, size = V(1.4, 2, 1.4), prompt = "a small shiny gold trophy cup with two round handles on a short round base, smooth simple clean shapes" },
} :: { [string]: MeshDef }

-- UI glyphs (swap for our own icon ids later) ------------------------------------------------------------
Config.Icons = {
	coin = "💰",
	xp = "⭐",
	star = "⭐",
	shop = "🛒",
	index = "📖",
	daily = "📅",
	music = "🔊",
	mute = "🔇",
	box = "📦", -- HUD Mystery Box button (🎁 is the FREE button)
	free = "🎁",
	track = "🎃",
	candy = "🍬",
	gift = "🎁",
	theme = "🎡",
	boost = "💰",
	vip = "👑",
	trophy = "🏆",
	cake = "🎂",
	toppings = "🍒",
	undo = "↩️",
	rotate = "🔄",
	trash = "🗑️",
	left = "◀",
	right = "▶",
	zoomIn = "➕",
	zoomOut = "➖",
	done = "✅",
	walk = "🚶",
	go = "🏃",
	lock = "🔒",
	celeb = "🌟",
	timer = "⏱️",
	luck = "🍀",
	question = "❓",
	check = "✔",
}
Config.Music = { 1842976958, 1836942830, 1840434670, 1845266081, 1839807682, 1838005831 }

-- Phases, in order ------------------------------------------------------------------------------------
Config.PhaseNames = {
	Waiting = "Waiting for bakers",
	Lobby = "Next round",
	Theme = "Theme reveal",
	Build = "Decorate!",
	Vote = "Judging",
	Results = "Results",
}

return Config

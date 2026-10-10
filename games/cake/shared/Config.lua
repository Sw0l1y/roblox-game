-- Cake Off! 🎂 tuning, catalog and geometry. Shared by server and client.
local Config = {}

local C = Color3.fromRGB
local V = Vector3.new

Config.Name = "Cake Off! 🎂"
Config.Tagline = "Decorate the Cake!"
Config.DataStore = "CakeOff_v1"

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
	tileA = C(255, 246, 232),
	tileB = C(255, 220, 230),
}
Config.StationColors = { C(255, 179, 199), C(168, 230, 207), C(160, 216, 247), C(255, 226, 130), C(205, 180, 245), C(255, 196, 160) }

-- Round timing (seconds) ----------------------------------------------------------------------------
Config.Round = {
	firstWait = 14, -- first round starts within ~20 s of the first join
	intermission = 10,
	theme = 6,
	build = 100,
	overtime = 30, -- +30 s Build Time pass (whole server)
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
export type ColorDef = { key: string, name: string, color: Color3, price: number, pass: string?, gloss: number?, neon: boolean?, special: string? }
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
-- source: "free" (starter), "shop" (coins), "box" (Mystery Sprinkle Box only), "vip" (VIP pass)
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
	{ id = "Blueberry", name = "Blueberries", tier = "Uncommon", glyph = "🫐", price = 160, source = "shop" },
	{ id = "HeartCandy", name = "Candy Heart", tier = "Uncommon", glyph = "💗", price = 200, source = "shop", tint = C(255, 110, 160) },
	{ id = "Bubbles", name = "Sugar Bubbles", tier = "Uncommon", glyph = "🫧", price = 220, source = "shop" },
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
	luck = 2.5, -- Lucky Sprinkles product
	luckSeconds = 900,
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

-- Themes -------------------------------------------------------------------------------------------------
export type ThemeDef = { key: string, name: string, glyph: string, toppings: { string }, colors: { string }, shapes: { string } }
Config.Themes = {
	{ key = "Birthday", name = "Birthday Bash", glyph = "🎉", toppings = { "Candle", "Sprinkles", "Star", "Cherry", "Cupcake", "Swirl", "Sparkler" }, colors = { "Pink", "Sky", "Lemon", "Mint", "Bubblegum" }, shapes = { "Round" } },
	{ key = "Rainbow", name = "Over the Rainbow", glyph = "🌈", toppings = { "Rainbow", "Sprinkles", "Star", "Lollipop", "Candy", "Unicorn" }, colors = { "Rainbow", "Cherry", "Orange", "Lemon", "Lime", "Sky", "Grape" }, shapes = { "Star" } },
	{ key = "Spooky", name = "Spooky Night", glyph = "🎃", toppings = { "Pumpkin", "Ghost", "Candy", "ChocChunk", "Star" }, colors = { "Licorice", "Orange", "Grape", "Lime" }, shapes = { "Hexagon" } },
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

-- Monetization ladder (PROTOCOL §6). ids are 0 until created; Studio simulates purchases. ---------------
export type ProductDef = { id: number, name: string, price: number, glyph: string, desc: string, order: number }
Config.Passes = {
	Rainbow = { id = 0, name = "Rainbow Frosting", price = 79, glyph = "🌈", desc = "Layered rainbow frosting + rainbow drips", order = 1 },
	PremiumColors = { id = 0, name = "Premium Colours", price = 99, glyph = "✨", desc = "Gold, Silver, Rose Gold, Pearl, Galaxy, Electric Pink", order = 2 },
	ExtraToppings = { id = 0, name = "Topping Tray+", price = 99, glyph = "🍬", desc = "+12 toppings on every cake", order = 3 },
	ExtraTime = { id = 0, name = "+30s Build Time", price = 149, glyph = "⏰", desc = "+30 s build time for you AND your whole server", order = 4 },
	DoubleCoins = { id = 0, name = "2x Coins", price = 249, glyph = "💰", desc = "Double coins from every round, forever", order = 5 },
	VIP = { id = 0, name = "VIP Bakery", price = 299, glyph = "👑", desc = "3 VIP toppings, VIP tag, +20% coins", order = 6 },
	GoldenOven = { id = 0, name = "Golden Oven", price = 1299, glyph = "🏆", desc = "Golden station + sparkle aura + golden tag, +25% XP", order = 7 },
} :: { [string]: ProductDef }
Config.Products = {
	Coins1 = { id = 0, name = "1,000 Coins", price = 25, glyph = "🪙", desc = "A handful of coins", order = 1 },
	Box1 = { id = 0, name = "Mystery Sprinkle Box", price = 29, glyph = "🎁", desc = "1 box, odds shown in the Box menu", order = 2 },
	Luck = { id = 0, name = "Lucky Sprinkles", price = 39, glyph = "🍀", desc = "2.5x luck on boxes for 15 minutes", order = 3 },
	PickTheme = { id = 0, name = "Pick Next Theme", price = 49, glyph = "🎡", desc = "Choose the next round's theme for the server", order = 4 },
	Starter = { id = 0, name = "Starter Pack", price = 49, once = true, glyph = "🧁", desc = "2,000 coins + 3 Mystery Boxes (once)", order = 5 },
	Coins2 = { id = 0, name = "6,000 Coins", price = 99, glyph = "🪙", desc = "A bag of coins", order = 6 },
	Box5 = { id = 0, name = "5 Mystery Boxes", price = 119, glyph = "🎁", desc = "5 boxes, odds shown in the Box menu", order = 7 },
	Coins3 = { id = 0, name = "18,000 Coins", price = 249, glyph = "🪙", desc = "A vault of coins", order = 8 },
} :: { [string]: ProductDef }
Config.OfferAfter = 300 -- seconds of play before the one-time starter offer may show (never before minute 2)

-- Hero meshes: AI-generated later (ids 0 now). Every use has a primitive fallback in CakeBuilder.
export type MeshDef = { mesh: number, texture: number, size: Vector3, prompt: string }
Config.Meshes = {
	Strawberry = { mesh = 0, texture = 0, size = V(1.2, 1.6, 1.2), prompt = "a single strawberry, smooth glossy red, small green leaf crown on top, simple clean shapes, perfectly symmetrical" },
	Cupcake = { mesh = 0, texture = 0, size = V(1.2, 1.9, 1.2), prompt = "a small cupcake, mint paper cup with vertical ridges, round pink frosting swirl, one cherry on top, simple clean shapes" },
	Crown = { mesh = 0, texture = 0, size = V(1.8, 1.3, 1.8), prompt = "small gold crown, five rounded points with balls on the tips, one red round gem in front, smooth simple clean shapes" },
	Castle = { mesh = 0, texture = 0, size = V(1.6, 3, 1.6), prompt = "one round white tower with a pink cone roof and a small gold flag, simple clean shapes, toy style" },
	Unicorn = { mesh = 0, texture = 0, size = V(1.8, 2.2, 1.2), prompt = "a spiral unicorn horn with gold and white stripes, two small white ears at its base, smooth simple shapes" },
	Swan = { mesh = 0, texture = 0, size = V(1.2, 1.8, 1.8), prompt = "a small white swan sitting, curved neck, orange beak, wings folded, smooth simple clean shapes" },
	Trophy = { mesh = 0, texture = 0, size = V(1.4, 2, 1.4), prompt = "a small shiny gold trophy cup with two round handles on a short round base, smooth simple clean shapes" },
} :: { [string]: MeshDef }

-- UI glyphs (swap for our own icon ids later) ------------------------------------------------------------
Config.Icons = {
	coin = "🪙",
	xp = "⭐",
	star = "⭐",
	shop = "🛒",
	index = "📖",
	daily = "📅",
	music = "🔊",
	mute = "🔇",
	box = "🎁",
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

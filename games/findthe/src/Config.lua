-- Shared config (ReplicatedStorage.Config) for "Find the Dragon Eggs".
-- Id = 0 means the pass/product/badge hasn't been created yet ("Coming soon").
local Config = {}

Config.GameName = "Find the Dragon Eggs"

Config.GamePasses = {
	{ Key = "Radar", Img = "radar", Name = "Egg Radar", Icon = "📡", Desc = "Hot/cold meter to the nearest egg, forever", Price = 149, Id = 0 },
	{ Key = "Speed", Img = "speed", Name = "Speed Coil", Icon = "👟", Desc = "Run way faster everywhere", Price = 99, Id = 0 },
	{ Key = "DoubleJump", Img = "jump", Name = "Double Jump", Icon = "🦘", Desc = "Jump again in mid-air to reach high eggs", Price = 79, Id = 0 },
	{ Key = "VIP", Img = "vip", Name = "VIP", Icon = "👑", Desc = "2x free hints, gold VIP tag", Price = 199, Id = 0 },
}

Config.Products = {
	{ Key = "Starter", Img = "starter", Name = "Starter Pack", Icon = "🎒", Desc = "5 hints + 2 min Egg Glow!", Price = 39, Id = 0, Tab = "Boosts", Hints = 5, Glow = 120 },
	{ Key = "Hints3", Img = "hint", Name = "3 Hints", Icon = "🔍", Desc = "Point straight at hidden eggs", Price = 25, Id = 0, Tab = "Hints", Hints = 3 },
	{ Key = "Hints10", Img = "hints", Name = "10 Hints", Icon = "🔎", Desc = "Best value hint pack", Price = 69, Id = 0, Tab = "Hints", Hints = 10 },
	{ Key = "Hints30", Img = "vault", Name = "30 Hints", Icon = "🏦", Desc = "Find EVERY egg", Price = 179, Id = 0, Tab = "Hints", Hints = 30 },
	{ Key = "Glow", Img = "glow", Name = "Egg Glow", Icon = "✨", Desc = "Nearby eggs shine through walls for 2 min", Price = 35, Id = 0, Tab = "Boosts", Glow = 120 },
	{ Key = "Skip", Img = "skip", Name = "Skip Zone", Icon = "⏩", Desc = "Open the next locked zone now", Price = 49, Id = 0, Tab = "Boosts" },
}

Config.Offers = {
	{ Kind = "Product", Key = "Starter", Title = "STARTER PACK", Pitch = "5 hints + Egg Glow for new hunters!" },
	{ Kind = "Pass", Key = "Radar", Title = "EGG RADAR", Pitch = "Always know if you're HOT or COLD!" },
	{ Kind = "Product", Key = "Hints10", Title = "HINT PACK", Pitch = "10 hints that point right at eggs!" },
	{ Kind = "Pass", Key = "DoubleJump", Title = "DOUBLE JUMP", Pitch = "Reach the eggs nobody else can!" },
	{ Kind = "Product", Key = "Glow", Title = "EGG GLOW", Pitch = "Make nearby eggs shine for 2 minutes!" },
}
Config.FirstOfferDelay = 45
Config.OfferInterval = 200

-- Badges are awarded when Id ~= 0 (create them on Creator Hub, then paste ids)
Config.Badges = { Zone1 = 0, Zone2 = 0, Zone3 = 0, Zone4 = 0, Zone5 = 0, All = 0 }

Config.StartHints = 3
Config.GiftInterval = 240 -- free hint every 4 minutes
Config.DailyHints = 3
Config.HintTime = 45
Config.FindDistance = 30
Config.BaseSpeed = 18
Config.SpeedPassSpeed = 28

Config.Rarities = {
	{ Name = "Common", Color = Color3.fromRGB(210, 210, 210) },
	{ Name = "Uncommon", Color = Color3.fromRGB(90, 220, 90) },
	{ Name = "Rare", Color = Color3.fromRGB(70, 150, 255) },
	{ Name = "Epic", Color = Color3.fromRGB(180, 80, 255) },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 190, 40) },
	{ Name = "Mythic", Color = Color3.fromRGB(255, 60, 90) },
	{ Name = "Secret", Color = Color3.fromRGB(30, 30, 30) },
}
-- rarity by position in a zone's egg list (20 per zone)
local RARITY_BY_SLOT = { 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 5, 5, 6 }

Config.Zones = {
	{
		Name = "Sunny Meadow", Emoji = "🌼", Need = 0, Color = Color3.fromRGB(110, 220, 90),
		Tint = Color3.fromRGB(255, 252, 240),
		Eggs = { "Daisy", "Clover", "Buttercup", "Sprout", "Pebble", "Acorn", "Tulip", "Bumble", "Ladybug", "Mossy",
			"Honeycomb", "Dandelion", "Mushroom", "Bunny", "Sunflower", "Willow", "Hedgehog", "Golden Clover", "Rainbow", "Meadow Dragon" },
	},
	{
		Name = "Palm Beach", Emoji = "🏝️", Need = 8, Color = Color3.fromRGB(255, 210, 110),
		Tint = Color3.fromRGB(255, 246, 225),
		Eggs = { "Seashell", "Sandy", "Coconut", "Starfish", "Bubble", "Crabby", "Driftwood", "Coral", "Lagoon", "Pearl",
			"Surfer", "Tidal", "Sunset", "Jellyfish", "Pirate", "Turtle", "Kraken", "Treasure Chest", "Mermaid", "Sea Dragon" },
	},
	{
		Name = "Frosty Peaks", Emoji = "❄️", Need = 22, Color = Color3.fromRGB(150, 220, 255),
		Tint = Color3.fromRGB(225, 240, 255),
		Eggs = { "Snowball", "Frosty", "Icicle", "Mitten", "Penguin", "Pinecone", "Cocoa", "Snowflake", "Blizzard", "Glacier",
			"Polar", "Aurora", "Yeti", "Frostbite", "Crystal Ice", "Snow Fox", "Avalanche", "Diamond Frost", "North Star", "Ice Dragon" },
	},
	{
		Name = "Lava Volcano", Emoji = "🌋", Need = 40, Color = Color3.fromRGB(255, 110, 50),
		Tint = Color3.fromRGB(255, 225, 205),
		Eggs = { "Ember", "Ashy", "Cinder", "Charcoal", "Smokey", "Magma", "Basalt", "Spark", "Blaze", "Obsidian",
			"Inferno", "Scorch", "Phoenix", "Molten", "Eruption", "Fire Opal", "Hellfire", "Golden Flame", "Sun Core", "Lava Dragon" },
	},
	{
		Name = "Crystal Sky", Emoji = "💎", Need = 60, Color = Color3.fromRGB(190, 120, 255),
		Tint = Color3.fromRGB(240, 230, 255),
		Eggs = { "Cloud", "Breeze", "Feather", "Rainbow Mist", "Amethyst", "Stardust", "Comet", "Moonbeam", "Galaxy", "Nebula",
			"Sapphire", "Prism", "Celestial", "Thunder", "Cosmic", "Angel", "Starlight", "Golden Halo", "Eclipse", "Void Dragon" },
	},
}

Config.Clues = {
	Ground = "On the ground somewhere",
	Rock = "Hiding behind a rock",
	RockTop = "Sitting on a big rock",
	Tree = "Up in a tree",
	TreeBase = "At the bottom of a tree",
	Bush = "Inside a bush",
	Log = "Inside a hollow log",
	Water = "Out on the water",
	Roof = "On top of a roof",
	House = "Inside a little house",
	Tower = "At the very top of a tower",
	Ledge = "Halfway up a tower",
	Cave = "Deep inside a cave",
	CaveMouth = "Near a cave entrance",
	Crate = "Between some crates",
	Bridge = "Under a bridge",
	Edge = "Along the cliff wall",
}

Config.Titles = {
	{ Need = 0, Name = "Rookie Hunter", Color = Color3.fromRGB(220, 220, 220) },
	{ Need = 10, Name = "Egg Spotter", Color = Color3.fromRGB(110, 220, 110) },
	{ Need = 25, Name = "Egg Tracker", Color = Color3.fromRGB(90, 170, 255) },
	{ Need = 45, Name = "Egg Detective", Color = Color3.fromRGB(190, 110, 255) },
	{ Need = 70, Name = "Dragon Seeker", Color = Color3.fromRGB(255, 190, 40) },
	{ Need = 100, Name = "EGG LEGEND", Color = Color3.fromRGB(255, 70, 110) },
}

-- Flat list of all eggs: id = (zone - 1) * 20 + slot
Config.Eggs = {}
for z, zone in ipairs(Config.Zones) do
	for slot, name in ipairs(zone.Eggs) do
		local ri = RARITY_BY_SLOT[slot]
		if z == #Config.Zones and slot == 20 then
			ri = 7
		end
		local id = (z - 1) * 20 + slot
		Config.Eggs[id] = {
			Id = id,
			Zone = z,
			Slot = slot,
			Name = name .. " Egg",
			Rarity = Config.Rarities[ri].Name,
			RarityIndex = ri,
			Difficulty = slot <= 8 and 1 or (slot <= 15 and 2 or 3),
		}
	end
end
Config.TotalEggs = #Config.Eggs

function Config.Title(found)
	local t = Config.Titles[1]
	for _, title in ipairs(Config.Titles) do
		if found >= title.Need then
			t = title
		end
	end
	return t
end

function Config.Find(list, key)
	for _, v in ipairs(list) do
		if v.Key == key then
			return v
		end
	end
	return nil
end

-- Parse "1,5,9" -> { [1] = true, [5] = true, [9] = true }
function Config.ParseFound(str)
	local set = {}
	for n in string.gmatch(str or "", "%d+") do
		set[tonumber(n)] = true
	end
	return set
end

return Config

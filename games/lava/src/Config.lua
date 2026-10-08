-- Shared config (ReplicatedStorage.Config) for "Escape the Lava Wave".
-- Id = 0 means the pass/product hasn't been created yet (buy buttons say "Coming soon").
local Config = {}

Config.GameName = "Escape the Lava Wave"

Config.GamePasses = {
	{ Key = "DoubleCash", Img = "doublecash", Name = "2x Cash", Icon = "💵", Desc = "Double ALL critter income forever", Price = 199, Id = 2022572264 },
	{ Key = "DoubleCarry", Img = "carry", Name = "2x Carry", Icon = "🎒", Desc = "Carry twice as many critters", Price = 249, Id = 2021528268 },
	{ Key = "Speed", Img = "speed", Name = "Speed Coil", Icon = "👟", Desc = "+30% run speed. Outrun the lava!", Price = 149, Id = 2022182275 },
	{ Key = "VIP", Img = "vip", Name = "VIP", Icon = "👑", Desc = "+25% income, VIP tag, 2 extra base slots", Price = 299, Id = 2022344267 },
}

Config.Products = {
	{ Key = "Starter", Img = "starter", Name = "Starter Pack", Icon = "🎒", Desc = "Cash + 2 Speed levels!", Price = 49, Id = 3717316694, Tab = "Boosts" },
	{ Key = "Revive", Img = "revive", Name = "Revive", Icon = "💖", Desc = "Get your lost critters back!", Price = 25, Id = 3717316699, Tab = "Boosts" },
	{ Key = "Freeze", Img = "freeze", Name = "Freeze Lava", Icon = "🧊", Desc = "No waves for 2 min, whole server", Price = 79, Id = 3717316701, Tab = "Boosts" },
	{ Key = "Luck", Img = "luck", Name = "Server Luck x3", Icon = "🍀", Desc = "Rare critters 3x more, 15 min", Price = 149, Id = 3717316707, Tab = "Boosts" },
	{ Key = "CashS", Img = "cash", Name = "Pile of Cash", Icon = "💵", Desc = "Instant cash", Price = 25, Id = 3717316711, Tab = "Cash", Cash = 2500 },
	{ Key = "CashM", Img = "bag", Name = "Bag of Cash", Icon = "💰", Desc = "Lots of instant cash", Price = 99, Id = 3717316714, Tab = "Cash", Cash = 15000 },
	{ Key = "CashL", Img = "vault", Name = "Vault of Cash", Icon = "🏦", Desc = "A HUGE amount of cash", Price = 399, Id = 3717316715, Tab = "Cash", Cash = 100000 },
}

Config.Offers = {
	{ Kind = "Product", Key = "Starter", Title = "STARTER PACK", Pitch = "Cash + 2 SPEED levels for new runners!" },
	{ Kind = "Pass", Key = "Speed", Title = "SPEED COIL", Pitch = "Run 30% faster. The lava can't catch you!" },
	{ Kind = "Pass", Key = "DoubleCarry", Title = "2X CARRY", Pitch = "Bring home twice the critters every run!" },
	{ Kind = "Product", Key = "Luck", Title = "SERVER LUCK", Pitch = "Mythic & Secret critters spawn 3x more!" },
	{ Kind = "Pass", Key = "DoubleCash", Title = "DOUBLE CASH", Pitch = "Every critter earns 2x. Forever." },
	{ Kind = "Pass", Key = "VIP", Title = "BECOME VIP", Pitch = "+25% income, gold tag, +2 base slots!" },
}
Config.FirstOfferDelay = 45
Config.OfferInterval = 180

Config.Rarities = {
	{ Name = "Common", Color = Color3.fromRGB(205, 205, 205) },
	{ Name = "Uncommon", Color = Color3.fromRGB(90, 220, 90) },
	{ Name = "Rare", Color = Color3.fromRGB(70, 150, 255) },
	{ Name = "Epic", Color = Color3.fromRGB(180, 80, 255) },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 190, 40) },
	{ Name = "Mythic", Color = Color3.fromRGB(255, 60, 90) },
	{ Name = "Secret", Color = Color3.fromRGB(255, 255, 255) },
}

-- Critters: name, rarity, income per second, body color, glow color, extra features
Config.Critters = {
	{ Name = "Pebble Pup", Rarity = "Common", Income = 1, Color = Color3.fromRGB(150, 140, 135), Glow = Color3.fromRGB(255, 140, 60), Ears = true },
	{ Name = "Ashling", Rarity = "Common", Income = 2, Color = Color3.fromRGB(110, 105, 115), Glow = Color3.fromRGB(255, 120, 40) },
	{ Name = "Cinder Bean", Rarity = "Common", Income = 3, Color = Color3.fromRGB(90, 70, 60), Glow = Color3.fromRGB(255, 170, 60), Horns = true },
	{ Name = "Ember Toad", Rarity = "Uncommon", Income = 8, Color = Color3.fromRGB(120, 180, 70), Glow = Color3.fromRGB(255, 150, 40) },
	{ Name = "Sootsprite", Rarity = "Uncommon", Income = 11, Color = Color3.fromRGB(45, 40, 55), Glow = Color3.fromRGB(255, 210, 90), Ears = true },
	{ Name = "Flicker", Rarity = "Uncommon", Income = 14, Color = Color3.fromRGB(255, 160, 60), Glow = Color3.fromRGB(255, 240, 120), Horns = true },
	{ Name = "Magma Mole", Rarity = "Rare", Income = 40, Color = Color3.fromRGB(150, 80, 60), Glow = Color3.fromRGB(255, 90, 30), Ears = true },
	{ Name = "Blaze Bunny", Rarity = "Rare", Income = 55, Color = Color3.fromRGB(255, 220, 200), Glow = Color3.fromRGB(255, 100, 40), Ears = true, Tall = true },
	{ Name = "Obsidian Owl", Rarity = "Rare", Income = 70, Color = Color3.fromRGB(40, 30, 60), Glow = Color3.fromRGB(150, 110, 255), Horns = true },
	{ Name = "Inferno Imp", Rarity = "Epic", Income = 250, Color = Color3.fromRGB(200, 40, 40), Glow = Color3.fromRGB(255, 200, 60), Horns = true },
	{ Name = "Lava Lynx", Rarity = "Epic", Income = 320, Color = Color3.fromRGB(255, 130, 40), Glow = Color3.fromRGB(255, 60, 20), Ears = true },
	{ Name = "Pyro Pig", Rarity = "Epic", Income = 400, Color = Color3.fromRGB(255, 140, 160), Glow = Color3.fromRGB(255, 80, 40), Ears = true },
	{ Name = "Phoenix Chick", Rarity = "Legendary", Income = 1500, Color = Color3.fromRGB(255, 190, 60), Glow = Color3.fromRGB(255, 90, 30), Wings = true },
	{ Name = "Volcano Golem", Rarity = "Legendary", Income = 2000, Color = Color3.fromRGB(70, 60, 60), Glow = Color3.fromRGB(255, 100, 20), Horns = true },
	{ Name = "Molten Kitsune", Rarity = "Legendary", Income = 2500, Color = Color3.fromRGB(255, 240, 230), Glow = Color3.fromRGB(255, 120, 40), Ears = true, Wings = true },
	{ Name = "Ruby Wyvern", Rarity = "Mythic", Income = 10000, Color = Color3.fromRGB(220, 20, 60), Glow = Color3.fromRGB(255, 80, 120), Horns = true, Wings = true },
	{ Name = "Magmazilla", Rarity = "Mythic", Income = 13000, Color = Color3.fromRGB(40, 35, 35), Glow = Color3.fromRGB(255, 60, 0), Horns = true, Tall = true },
	{ Name = "Solar Seraph", Rarity = "Mythic", Income = 16000, Color = Color3.fromRGB(255, 250, 220), Glow = Color3.fromRGB(255, 220, 80), Wings = true, Halo = true },
	{ Name = "Core Titan", Rarity = "Secret", Income = 80000, Color = Color3.fromRGB(20, 10, 25), Glow = Color3.fromRGB(255, 40, 200), Horns = true, Wings = true, Crown = true },
	{ Name = "Eternal Flame", Rarity = "Secret", Income = 120000, Color = Color3.fromRGB(255, 255, 255), Glow = Color3.fromRGB(80, 220, 255), Wings = true, Halo = true, Crown = true },
}

-- Track: zones run from the hub (x = 0) toward the volcano (+x). Zone i mostly spawns rarity i.
Config.TrackStart = 60
Config.ZoneLength = 140
Config.TrackWidth = 56
Config.ZoneNames = { "Ash Fields", "Ember Path", "Magma Flats", "Scorch Canyon", "Phoenix Ridge", "Molten Core", "The Crater" }
Config.ZoneColors = {
	Color3.fromRGB(214, 196, 168), Color3.fromRGB(200, 162, 128), Color3.fromRGB(178, 124, 98), Color3.fromRGB(150, 92, 86),
	Color3.fromRGB(118, 70, 80), Color3.fromRGB(86, 50, 70), Color3.fromRGB(52, 34, 54),
}
Config.CrittersPerZone = 6
Config.RespawnTime = 8
Config.AlcoveEvery = 70 -- safe pockets on both sides of the track
Config.AlcoveWidth = 18
Config.AlcoveDepth = 14

-- Waves
Config.WaveWarning = 5
Config.WaveGapMin = 22
Config.WaveGapMax = 32
Config.WaveThickness = 40
Config.WaveKinds = {
	{ Name = "Lava Wave", Speed = 55, Height = 18, Weight = 50 },
	{ Name = "FAST Wave", Speed = 85, Height = 16, Weight = 30 },
	{ Name = "MEGA WAVE", Speed = 70, Height = 34, Weight = 15 },
	{ Name = "LIGHTNING WAVE", Speed = 120, Height = 14, Weight = 5 },
}
Config.FreezeTime = 120

-- Base
Config.BaseSlots = 10
Config.VipSlots = 2
Config.BaseRadius = 22 -- depositing happens anywhere inside your base

-- Upgrades (bought with cash)
Config.BaseSpeed = 24
Config.SpeedPerLevel = 3
Config.MaxSpeedLevel = 12
Config.MaxCarryLevel = 9
function Config.SpeedCost(level)
	return math.floor(150 * 2.1 ^ level)
end
function Config.CarryCost(level)
	return math.floor(400 * 2.7 ^ level)
end
function Config.Capacity(level, doubled)
	return (1 + level) * (doubled and 2 or 1)
end

Config.GiftInterval = 300

function Config.RebirthCost(rebirths)
	return 250000 * 5 ^ rebirths
end
function Config.RebirthMult(rebirths)
	return 1 + rebirths * 0.5
end
function Config.GiftCash(rebirths)
	return 400 * (1 + rebirths) ^ 2
end
function Config.SellValue(def)
	return def.Income * 15
end

function Config.Rarity(name)
	for i, r in ipairs(Config.Rarities) do
		if r.Name == name then
			return r, i
		end
	end
	return Config.Rarities[1], 1
end

function Config.Critter(name)
	for _, c in ipairs(Config.Critters) do
		if c.Name == name then
			return c
		end
	end
	return nil
end

function Config.Find(list, key)
	for _, v in ipairs(list) do
		if v.Key == key then
			return v
		end
	end
	return nil
end

function Config.ZoneAt(x)
	local z = math.floor((x - Config.TrackStart) / Config.ZoneLength) + 1
	if x < Config.TrackStart then
		return 0
	end
	return math.min(z, #Config.ZoneNames)
end

function Config.TrackEnd()
	return Config.TrackStart + Config.ZoneLength * #Config.ZoneNames
end

function Config.Format(n)
	n = math.floor(n)
	local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi" }
	local i = 1
	local v = n
	while math.abs(v) >= 1000 and i < #suffixes do
		v = v / 1000
		i += 1
	end
	if i == 1 then
		return tostring(n)
	end
	return string.format("%.1f%s", v, suffixes[i])
end

return Config

-- Shared config (ReplicatedStorage.Config) for "Grow a Crystal Garden".
-- Id = 0 means the pass/product hasn't been created yet (buy buttons say "Coming soon").
local Config = {}

Config.GameName = "Grow a Crystal Garden"

Config.GamePasses = {
	{ Key = "DoubleCoins", Img = "coins", Name = "2x Coins", Icon = "💰", Desc = "Every crystal sells for double", Price = 199, Id = 2023244263 },
	{ Key = "FastGrow", Img = "fastgrow", Name = "Fast Growth", Icon = "⏩", Desc = "Crystals grow 50% faster", Price = 149, Id = 2022116267 },
	{ Key = "Lucky", Img = "lucky", Name = "Lucky Mutations", Icon = "🍀", Desc = "2x mutation chance in every event", Price = 249, Id = 2022494262 },
	{ Key = "SellAnywhere", Img = "sellanywhere", Name = "Sell Anywhere", Icon = "🛒", Desc = "Sell your backpack from any spot", Price = 99, Id = 2022026273 },
	{ Key = "VIP", Img = "vip", Name = "VIP", Icon = "👑", Desc = "+25% sell price and a gold VIP tag", Price = 299, Id = 2023280258 },
}

-- Weather products start that event for the WHOLE server right away
Config.Products = {
	{ Key = "Starter", Img = "starter", Name = "Starter Pack", Icon = "🎒", Desc = "3 Sapphire seeds + coins", Price = 49, Id = 3717316967, Tab = "Boosts" },
	{ Key = "GrowAll", Img = "growall", Name = "Grow All", Icon = "✨", Desc = "Every crystal in your garden ripens NOW", Price = 39, Id = 3717316972, Tab = "Boosts" },
	{ Key = "Restock", Img = "restock", Name = "Restock Seeds", Icon = "🔄", Desc = "Fresh seed stock with 3x rare luck", Price = 29, Id = 3717316976, Tab = "Boosts" },
	{ Key = "Frost", Img = "frost", Name = "Frost Storm", Icon = "❄️", Desc = "Start a Frost Storm for the server", Price = 49, Id = 3717316978, Tab = "Weather", Event = "Frost" },
	{ Key = "Thunder", Img = "thunder", Name = "Thunderstorm", Icon = "⚡", Desc = "Start a Thunderstorm for the server", Price = 79, Id = 3717316984, Tab = "Weather", Event = "Thunder" },
	{ Key = "Meteor", Img = "meteor", Name = "Meteor Shower", Icon = "☄️", Desc = "Start a Meteor Shower for the server", Price = 149, Id = 3717316990, Tab = "Weather", Event = "Meteor" },
	{ Key = "Aurora", Img = "aurora", Name = "Rainbow Aurora", Icon = "🌈", Desc = "Start a Rainbow Aurora for the server", Price = 299, Id = 3717316992, Tab = "Weather", Event = "Aurora" },
	{ Key = "CoinsS", Img = "coins", Name = "Pouch of Coins", Icon = "💰", Desc = "Instant coins", Price = 25, Id = 3717316995, Tab = "Coins", Coins = 2500 },
	{ Key = "CoinsM", Img = "chest", Name = "Chest of Coins", Icon = "🧰", Desc = "Lots of instant coins", Price = 99, Id = 3717316998, Tab = "Coins", Coins = 15000 },
	{ Key = "CoinsL", Img = "vault", Name = "Vault of Coins", Icon = "🏦", Desc = "A HUGE amount of coins", Price = 399, Id = 3717317003, Tab = "Coins", Coins = 100000 },
}

Config.Offers = {
	{ Kind = "Product", Key = "Starter", Title = "STARTER PACK", Pitch = "3 Sapphire seeds + coins for new gardeners!" },
	{ Kind = "Pass", Key = "FastGrow", Title = "FAST GROWTH", Pitch = "Every crystal grows 50% faster. Forever." },
	{ Kind = "Product", Key = "Aurora", Title = "RAINBOW AURORA", Pitch = "Rainbow crystals sell for 20x. Start one NOW!" },
	{ Kind = "Pass", Key = "DoubleCoins", Title = "DOUBLE COINS", Pitch = "Every crystal sells for 2x!" },
	{ Kind = "Pass", Key = "Lucky", Title = "LUCKY MUTATIONS", Pitch = "Twice the Gold, Frozen and Cosmic crystals!" },
}
Config.FirstOfferDelay = 40
Config.OfferInterval = 200

Config.Rarities = {
	{ Name = "Common", Color = Color3.fromRGB(205, 205, 215) },
	{ Name = "Uncommon", Color = Color3.fromRGB(90, 225, 110) },
	{ Name = "Rare", Color = Color3.fromRGB(70, 150, 255) },
	{ Name = "Epic", Color = Color3.fromRGB(185, 85, 255) },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 190, 40) },
	{ Name = "Mythic", Color = Color3.fromRGB(255, 60, 110) },
	{ Name = "Divine", Color = Color3.fromRGB(120, 255, 240) },
}

-- Seed stock per restock: Chance to appear at all, then Min..Max seeds
Config.StockOdds = {
	Common = { Chance = 1, Min = 6, Max = 18 },
	Uncommon = { Chance = 0.8, Min = 2, Max = 8 },
	Rare = { Chance = 0.5, Min = 1, Max = 4 },
	Epic = { Chance = 0.25, Min = 1, Max = 3 },
	Legendary = { Chance = 0.1, Min = 1, Max = 2 },
	Mythic = { Chance = 0.035, Min = 1, Max = 1 },
	Divine = { Chance = 0.01, Min = 1, Max = 1 },
}

-- Grow in seconds. Value = sell price of a normal-size crystal. Regrow = harvest again and again (regrows in Grow * 0.5).
-- Shape: shard count / height / width of the cluster
Config.Crystals = {
	{ Name = "Quartz", Rarity = "Common", Price = 10, Grow = 20, Value = 18, Color = Color3.fromRGB(255, 225, 240), Shards = 3, H = 2.2 },
	{ Name = "Amethyst", Rarity = "Common", Price = 40, Grow = 45, Value = 75, Color = Color3.fromRGB(175, 110, 255), Shards = 4, H = 2.6 },
	{ Name = "Citrine", Rarity = "Uncommon", Price = 150, Grow = 80, Value = 55, Regrow = true, Color = Color3.fromRGB(255, 195, 60), Shards = 4, H = 2.8 },
	{ Name = "Emerald", Rarity = "Uncommon", Price = 450, Grow = 110, Value = 820, Color = Color3.fromRGB(40, 220, 120), Shards = 5, H = 3.2 },
	{ Name = "Sapphire", Rarity = "Rare", Price = 1400, Grow = 150, Value = 520, Regrow = true, Color = Color3.fromRGB(50, 110, 255), Shards = 5, H = 3.4 },
	{ Name = "Ruby", Rarity = "Rare", Price = 3800, Grow = 210, Value = 6800, Color = Color3.fromRGB(240, 30, 70), Shards = 6, H = 3.8 },
	{ Name = "Topaz", Rarity = "Epic", Price = 11000, Grow = 260, Value = 3600, Regrow = true, Color = Color3.fromRGB(255, 140, 40), Shards = 6, H = 4 },
	{ Name = "Opal", Rarity = "Epic", Price = 32000, Grow = 330, Value = 56000, Color = Color3.fromRGB(150, 245, 255), Shards = 7, H = 4.3 },
	{ Name = "Moonstone", Rarity = "Legendary", Price = 95000, Grow = 420, Value = 30000, Regrow = true, Color = Color3.fromRGB(200, 215, 255), Shards = 7, H = 4.7 },
	{ Name = "Starfire", Rarity = "Legendary", Price = 280000, Grow = 520, Value = 480000, Color = Color3.fromRGB(255, 90, 30), Shards = 8, H = 5 },
	{ Name = "Void Crystal", Rarity = "Mythic", Price = 1000000, Grow = 660, Value = 320000, Regrow = true, Color = Color3.fromRGB(90, 20, 160), Shards = 8, H = 5.5 },
	{ Name = "Prism Heart", Rarity = "Divine", Price = 5000000, Grow = 900, Value = 1600000, Regrow = true, Color = Color3.fromRGB(255, 255, 255), Shards = 9, H = 6 },
}

-- Mutations multiply value. Gold/Rainbow can also appear naturally when a crystal ripens.
Config.Mutations = {
	{ Name = "Gold", Mult = 5, Color = Color3.fromRGB(255, 200, 40), Natural = 0.01 },
	{ Name = "Rainbow", Mult = 20, Color = Color3.fromRGB(255, 120, 220), Natural = 0.001 },
	{ Name = "Frozen", Mult = 3, Color = Color3.fromRGB(160, 230, 255) },
	{ Name = "Charged", Mult = 4, Color = Color3.fromRGB(255, 240, 90) },
	{ Name = "Cosmic", Mult = 8, Color = Color3.fromRGB(150, 90, 255) },
}

-- Server-wide weather. Chance = per crystal, per 5s tick while the event runs.
Config.Events = {
	{ Key = "Frost", Name = "Frost Storm", Icon = "❄️", Mutation = "Frozen", Chance = 0.035, Weight = 40, Color = Color3.fromRGB(160, 230, 255) },
	{ Key = "Thunder", Name = "Thunderstorm", Icon = "⚡", Mutation = "Charged", Chance = 0.03, Weight = 30, Color = Color3.fromRGB(255, 240, 90) },
	{ Key = "Meteor", Name = "Meteor Shower", Icon = "☄️", Mutation = "Cosmic", Chance = 0.025, Weight = 20, Color = Color3.fromRGB(170, 110, 255) },
	{ Key = "Aurora", Name = "Rainbow Aurora", Icon = "🌈", Mutation = "Rainbow", Chance = 0.012, Weight = 10, Color = Color3.fromRGB(255, 120, 220) },
}
Config.EventEvery = 360 -- seconds between free events
Config.EventLength = 90
Config.EventTick = 5

Config.RestockEvery = 300
Config.StartCoins = 30
Config.StartTiles = 12
Config.MaxTiles = 36
Config.TileCols = 6
-- cost to unlock the next row of 6 tiles (rows 3..6)
Config.ExpandCosts = { 2500, 30000, 350000, 4000000 }
Config.BackpackMax = 150
Config.GiftInterval = 300
Config.HugeChance = 0.02

function Config.GiftCoins(best)
	-- scales with the best seed price you've bought so gifts stay useful
	return math.max(100, math.floor((best or 0) * 0.6))
end

function Config.Rarity(name)
	for i, r in ipairs(Config.Rarities) do
		if r.Name == name then
			return r, i
		end
	end
	return Config.Rarities[1], 1
end

function Config.Crystal(name)
	for _, c in ipairs(Config.Crystals) do
		if c.Name == name then
			return c
		end
	end
	return nil
end

function Config.Mutation(name)
	for _, m in ipairs(Config.Mutations) do
		if m.Name == name then
			return m
		end
	end
	return nil
end

function Config.Event(key)
	for _, e in ipairs(Config.Events) do
		if e.Key == key then
			return e
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

-- value of one harvested crystal: base * size * (1 + sum of (mult - 1) over its mutations)
function Config.Value(name, size, muts)
	local def = Config.Crystal(name)
	if not def then
		return 0
	end
	local m = 1
	for _, mn in ipairs(muts or {}) do
		local mut = Config.Mutation(mn)
		if mut then
			m += mut.Mult - 1
		end
	end
	return math.floor(def.Value * (size or 1) * m)
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

function Config.Time(sec)
	sec = math.max(0, math.ceil(sec))
	if sec >= 60 then
		return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
	end
	return sec .. "s"
end

return Config

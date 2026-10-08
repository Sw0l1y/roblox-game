-- Shared config (ReplicatedStorage.Config) for "Steal a Dragon Egg".
-- Id = 0 means the pass/product hasn't been created on Creator Hub yet.
local Config = {}

Config.GameName = "Steal a Dragon Egg"

Config.GamePasses = {
	{ Key = "DoubleCash", Img = "cash", Name = "2x Cash", Icon = "💵", Desc = "Double ALL egg income forever", Price = 199, Id = 2018792445 },
	{ Key = "VIP", Img = "vip", Name = "VIP", Icon = "👑", Desc = "+25% income, VIP tag, gold name", Price = 299, Id = 2022038251 },
	{ Key = "ExtraSlots", Img = "slots", Name = "+4 Egg Slots", Icon = "🥚", Desc = "Hold 12 eggs instead of 8", Price = 149, Id = 2021528255 },
	{ Key = "Speed", Img = "speed", Name = "Speed Coil", Icon = "👟", Desc = "Run faster, steal easier", Price = 99, Id = 2022266250 },
}

Config.Products = {
	{ Key = "Starter", Img = "starter", Name = "Starter Pack", Icon = "🎒", Desc = "Cash + 15 min Server Luck!", Price = 49, Id = 3717301915, Tab = "Boosts" },
	{ Key = "CashS", Img = "cash", Name = "Pile of Cash", Icon = "💵", Desc = "Instant cash", Price = 25, Id = 3717301940, Tab = "Cash", Cash = 2500 },
	{ Key = "CashM", Img = "bag", Name = "Bag of Cash", Icon = "💰", Desc = "Lots of instant cash", Price = 99, Id = 3717301950, Tab = "Cash", Cash = 15000 },
	{ Key = "CashL", Img = "vault", Name = "Vault of Cash", Icon = "🏦", Desc = "A HUGE amount of cash", Price = 399, Id = 3717301963, Tab = "Cash", Cash = 100000 },
	{ Key = "Luck", Img = "luck", Name = "Server Luck x3", Icon = "🍀", Desc = "Rare eggs for EVERYONE, 15 min", Price = 149, Id = 3717301968, Tab = "Boosts" },
	{ Key = "Lock", Img = "lock", Name = "Instant Lock", Icon = "🔒", Desc = "Lock your base for 2 minutes", Price = 15, Id = 3717301971, Tab = "Boosts" },
}

Config.Offers = {
	{ Kind = "Product", Key = "Starter", Title = "STARTER PACK", Pitch = "Cash + SERVER LUCK for new players!" },
	{ Kind = "Pass", Key = "DoubleCash", Title = "DOUBLE CASH", Pitch = "Every egg earns 2x. Forever." },
	{ Kind = "Product", Key = "Luck", Title = "SERVER LUCK", Pitch = "Make Mythic & Secret eggs spawn 3x more!" },
	{ Kind = "Pass", Key = "ExtraSlots", Title = "MORE SLOTS", Pitch = "Hold 12 eggs and earn way more!" },
	{ Kind = "Pass", Key = "VIP", Title = "BECOME VIP", Pitch = "+25% income and a gold VIP tag!" },
}
Config.FirstOfferDelay = 30
Config.OfferInterval = 180

Config.Rarities = {
	{ Name = "Common", Color = Color3.fromRGB(200, 200, 200), Weight = 50 },
	{ Name = "Uncommon", Color = Color3.fromRGB(90, 220, 90), Weight = 25 },
	{ Name = "Rare", Color = Color3.fromRGB(70, 150, 255), Weight = 13 },
	{ Name = "Epic", Color = Color3.fromRGB(180, 80, 255), Weight = 7 },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 190, 40), Weight = 3.5 },
	{ Name = "Mythic", Color = Color3.fromRGB(255, 60, 90), Weight = 1.2 },
	{ Name = "Secret", Color = Color3.fromRGB(20, 20, 20), Weight = 0.3 },
}

-- Name, rarity, buy price, income per second, egg color
Config.Eggs = {
	{ Name = "Lil Yolk", Rarity = "Common", Price = 10, Income = 1, Color = Color3.fromRGB(255, 245, 220) },
	{ Name = "Speckles", Rarity = "Common", Price = 25, Income = 2, Color = Color3.fromRGB(220, 200, 170) },
	{ Name = "Sunny Side", Rarity = "Uncommon", Price = 120, Income = 6, Color = Color3.fromRGB(255, 220, 90) },
	{ Name = "Shelldon", Rarity = "Uncommon", Price = 250, Income = 11, Color = Color3.fromRGB(140, 220, 140) },
	{ Name = "Scrambles", Rarity = "Rare", Price = 900, Income = 30, Color = Color3.fromRGB(110, 170, 255) },
	{ Name = "Frost Egg", Rarity = "Rare", Price = 1800, Income = 55, Color = Color3.fromRGB(180, 230, 255) },
	{ Name = "Eggward", Rarity = "Epic", Price = 6000, Income = 150, Color = Color3.fromRGB(190, 110, 255) },
	{ Name = "Toxic Egg", Rarity = "Epic", Price = 12000, Income = 260, Color = Color3.fromRGB(120, 255, 60) },
	{ Name = "Golden Goose", Rarity = "Legendary", Price = 50000, Income = 900, Color = Color3.fromRGB(255, 200, 30) },
	{ Name = "Lava Egg", Rarity = "Legendary", Price = 90000, Income = 1500, Color = Color3.fromRGB(255, 100, 30) },
	{ Name = "Dragon Egg", Rarity = "Mythic", Price = 400000, Income = 6000, Color = Color3.fromRGB(220, 30, 60) },
	{ Name = "Cosmic Egg", Rarity = "Mythic", Price = 900000, Income = 12000, Color = Color3.fromRGB(90, 60, 255) },
	{ Name = "Void Egg", Rarity = "Secret", Price = 5000000, Income = 60000, Color = Color3.fromRGB(30, 0, 40) },
}

Config.BaseSlots = 8
Config.ExtraSlots = 4
Config.SpawnInterval = 2.2
Config.ConveyorTime = 35
Config.LockTime = 45
Config.LockCooldown = 30
Config.GiftInterval = 300 -- free playtime gift every 5 minutes
Config.RetrieveDistance = 7

function Config.RebirthCost(rebirths)
	return 100000 * 4 ^ rebirths
end

function Config.RebirthMult(rebirths)
	return 1 + rebirths * 0.5
end

function Config.GiftCash(rebirths)
	return 500 * (1 + rebirths) ^ 2
end

function Config.Rarity(name)
	for i, r in ipairs(Config.Rarities) do
		if r.Name == name then
			return r, i
		end
	end
	return Config.Rarities[1], 1
end

function Config.EggByName(name)
	for _, e in ipairs(Config.Eggs) do
		if e.Name == name then
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

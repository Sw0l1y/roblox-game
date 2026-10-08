-- Shared config (ReplicatedStorage.Config) for Candy Smash Simulator.
-- Set IDs after creating passes/products on Creator Hub. Id = 0 means "not set up yet".
local Config = {}

Config.GameName = "Candy Smash Simulator"

Config.GamePasses = {
	{ Key = "DoublePower", Name = "2x Sugar", Price = 149, Id = 0 },
	{ Key = "AutoClick", Name = "Auto Smasher", Price = 249, Id = 0 },
	{ Key = "VIP", Name = "VIP (+50% Coins)", Price = 399, Id = 0 },
}

Config.Products = {
	{ Key = "CoinPack", Name = "Bag of Coins", Price = 49, Id = 0 },
	{ Key = "SugarRush", Name = "Sugar Rush (3x, 10 min)", Price = 79, Id = 0 },
}

-- Rotating pop-up offers (keys into GamePasses / Products)
Config.Offers = {
	{ Kind = "Pass", Key = "DoublePower", Title = "STARTER DEAL!", Pitch = "DOUBLE every smash, forever!" },
	{ Kind = "Product", Key = "SugarRush", Title = "SUGAR RUSH!", Pitch = "3x Sugar for 10 minutes!" },
	{ Kind = "Pass", Key = "AutoClick", Title = "GO AFK!", Pitch = "Smashes candy for you automatically!" },
	{ Kind = "Pass", Key = "VIP", Title = "VIP ONLY", Pitch = "+50% coins on every sell + VIP tag!" },
}
Config.FirstOfferDelay = 25
Config.OfferInterval = 150

-- Zones along +Z. Gate sits at ZStart; walls block players without enough rebirths.
Config.Zones = {
	{ Name = "Candy Meadow", ZStart = -80, Mult = 1, Rebirths = 0, Ground = Color3.fromRGB(255, 170, 210) },
	{ Name = "Chocolate Canyon", ZStart = 80, Mult = 4, Rebirths = 1, Ground = Color3.fromRGB(120, 70, 40) },
	{ Name = "Gummy Volcano", ZStart = 240, Mult = 15, Rebirths = 3, Ground = Color3.fromRGB(70, 30, 60) },
}
Config.ZoneLength = 160

Config.ClickCooldown = 0.05
Config.ComboWindow = 0.7
Config.CritChance = 0.1
Config.CritMult = 5
Config.AutoClickInterval = 0.4
Config.UpgradeBaseCost = 10
Config.UpgradeCostMult = 1.45
Config.RebirthBaseCost = 1000

function Config.UpgradeCost(level)
	return math.floor(Config.UpgradeBaseCost * Config.UpgradeCostMult ^ level)
end

function Config.RebirthCost(rebirths)
	return Config.RebirthBaseCost * (rebirths + 1) ^ 2
end

function Config.RebirthMult(rebirths)
	return 1 + rebirths * 0.5
end

function Config.ComboMult(combo)
	return math.min(1 + math.floor(combo / 10) * 0.25, 5)
end

function Config.ZoneAt(z)
	local found = Config.Zones[1]
	for _, zone in ipairs(Config.Zones) do
		if z >= zone.ZStart then
			found = zone
		end
	end
	return found
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

-- Shared config (ReplicatedStorage.Config). Set IDs after creating passes/products on Creator Hub.
local Config = {}

Config.GamePasses = {
	{ Key = "DoublePower", Name = "2x Power", Id = 0 },
	{ Key = "AutoClick", Name = "Auto Clicker", Id = 0 },
	{ Key = "VIP", Name = "VIP (+50% Coins)", Id = 0 },
}

Config.Products = {
	{ Key = "CoinPack", Name = "Coin Pack", Id = 0 },
}

Config.ClickCooldown = 0.05
Config.ComboWindow = 0.7 -- seconds between clicks to keep a combo
Config.CritChance = 0.1
Config.CritMult = 5
Config.AutoClickInterval = 0.5
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

-- +25% power per 10 combo, capped at x5
function Config.ComboMult(combo)
	return math.min(1 + math.floor(combo / 10) * 0.25, 5)
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

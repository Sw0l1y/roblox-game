-- Shared economy formulas: upgrade costs/effects, multipliers, balloon values and HP, zone lookup.
-- The server uses these to grant; the client uses the same functions to draw prices and previews.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tiers = require(Shared:WaitForChild("Tiers"))

local Econ = {}

type Data = { [string]: any }

function Econ.has(d: Data?, pass: string): boolean
	local passes: any = d and d.passes
	return type(passes) == "table" and passes[pass] == true
end

function Econ.level(d: Data?, key: string): number
	local up: any = d and d.up
	if type(up) ~= "table" then
		return 0
	end
	return tonumber(up[key]) or 0
end

-- Cost to go from `level` to `level + 1`.
function Econ.upgradeCost(key: string, level: number): number
	local u = Config.Upgrades[key]
	if not u then
		return math.huge
	end
	return math.floor(u.costBase * u.costGrowth ^ level)
end

-- Raw effect of an upgrade at a level.
function Econ.upgradeValue(key: string, level: number): number
	if key == "power" then
		return math.floor(level + 1.3 ^ level)
	elseif key == "speed" then
		return math.max(0.12, 0.5 * 0.92 ^ level)
	elseif key == "aura" then
		return level <= 0 and 0 or (7 + 1.5 * (level - 1))
	elseif key == "luck" then
		return 1 + 0.15 * level
	elseif key == "walk" then
		return 20 + 1.2 * level
	end
	return 0
end

-- Human text for an upgrade value ("x1.45", "0.42s", "12 studs").
function Econ.upgradeText(key: string, value: number): string
	if key == "power" then
		return tostring(value)
	elseif key == "speed" then
		return string.format("%.1f/s", 1 / value)
	elseif key == "aura" then
		return value <= 0 and "OFF" or (string.format("%.1f", value) .. " studs")
	elseif key == "luck" then
		return string.format("x%.2f", value)
	elseif key == "walk" then
		return string.format("%.0f", value)
	end
	return tostring(value)
end

function Econ.power(d: Data?): number
	local p = Econ.upgradeValue("power", Econ.level(d, "power"))
	if Econ.has(d, "GoldenDart") then
		p *= 3
	end
	return p
end

function Econ.cooldown(d: Data?): number
	return Econ.upgradeValue("speed", Econ.level(d, "speed"))
end

function Econ.auraRadius(d: Data?): number
	local r = Econ.upgradeValue("aura", Econ.level(d, "aura"))
	if Econ.has(d, "Aura") then
		r = math.max(r, Config.Aura.passMin) + Config.Aura.passBonus
	end
	return r
end

function Econ.walk(d: Data?): number
	return Econ.upgradeValue("walk", Econ.level(d, "walk"))
end

function Econ.luckBoostActive(d: Data?, now: number): boolean
	return d ~= nil and (tonumber(d.luckUntil) or 0) > now
end

function Econ.luck(d: Data?, now: number): number
	local l = Econ.upgradeValue("luck", Econ.level(d, "luck"))
	if Econ.has(d, "Lucky") then
		l *= 1.5
	end
	if Econ.luckBoostActive(d, now) then
		l *= 2
	end
	return l
end

function Econ.rebirthMult(n: number): number
	return 1 + Config.Rebirth.multPer * n
end

function Econ.rebirthCost(n: number): number
	return math.floor(Config.Rebirth.base * Config.Rebirth.growth ^ n)
end

-- Zone set completion: all non-Secret types of the zone popped at least once.
function Econ.zoneProgress(d: Data?, zone: number): (number, number, boolean)
	local list = Config.ZoneTypes[zone] or {}
	local found, total = 0, 0
	local secret = false
	local index: { [string]: number } = (d and d.index) or {}
	for _, key in ipairs(list) do
		local def = Config.Balloons[key]
		if def.tier == "Secret" then
			secret = (index[key] or 0) > 0
		else
			total += 1
			if (index[key] or 0) > 0 then
				found += 1
			end
		end
	end
	return found, total, secret
end

function Econ.zoneComplete(d: Data?, zone: number): boolean
	local f, t = Econ.zoneProgress(d, zone)
	return t > 0 and f >= t
end

function Econ.indexBonus(d: Data?): number
	local b = 0
	for z = 1, #Config.Zones do
		local _, _, secret = Econ.zoneProgress(d, z)
		if Econ.zoneComplete(d, z) then
			b += Config.Index.setBonus[z] or 0
		end
		if secret then
			b += Config.Index.secretBonus
		end
	end
	return b
end

function Econ.coinMult(d: Data?): number
	local m = Econ.rebirthMult(d and tonumber(d.rebirths) or 0)
	if Econ.has(d, "Coins2x") then
		m *= 2
	end
	if Econ.has(d, "VIP") then
		m *= 1.25
	end
	if d and d.premium == true then
		m *= 1.1
	end
	return m * (1 + Econ.indexBonus(d))
end

function Econ.zoneMult(d: Data?): number
	local z = math.clamp(d and tonumber(d.zones) or 1, 1, #Config.Zones)
	return Config.Zones[z].valueMult
end

function Econ.typeHp(key: string): number
	local def = Config.Balloons[key]
	if not def then
		return 1
	end
	return math.max(1, math.floor(Config.TierStats[def.tier].hp * Config.Zones[def.zone].hpMult))
end

function Econ.typeValue(key: string): number
	local def = Config.Balloons[key]
	if not def then
		return 1
	end
	return Config.TierStats[def.tier].value * Config.Zones[def.zone].valueMult
end

-- Coins this player gets for popping `key`. Shower (event) balloons pay the player's best zone rate x2
-- (the shower mixes in types from the best zone on the server, which a new player must not be paid for).
function Econ.popValue(key: string, d: Data?, shower: boolean?): number
	local def = Config.Balloons[key]
	if not def then
		return 0
	end
	local zm = Config.Zones[def.zone].valueMult
	if shower then
		zm = Econ.zoneMult(d) * 2
	end
	return math.max(1, math.floor(Config.TierStats[def.tier].value * zm * Econ.coinMult(d)))
end

function Econ.pumpRate(d: Data?): number
	return Config.Pump.rate * Econ.zoneMult(d) * Econ.rebirthMult(d and tonumber(d.rebirths) or 0)
end

function Econ.pumpCap(d: Data?): number
	return Econ.pumpRate(d) * Config.Pump.maxHours * 3600
end

-- Robux coin packs scale with the player's best zone and rebirths.
function Econ.packCoins(base: number, d: Data?): number
	return math.floor(base * Econ.zoneMult(d) * Econ.rebirthMult(d and tonumber(d.rebirths) or 0))
end

function Econ.dailyCoins(day: number, d: Data?): number
	local r = Config.Daily.rewards[math.clamp(day, 1, #Config.Daily.rewards)]
	local c = r.coins * Econ.zoneMult(d)
	if Econ.has(d, "VIP") then
		c *= 2
	end
	return math.floor(c)
end

-- Spawn table for a zone (kit Tiers.roll format), in tier order.
function Econ.spawnTable(zone: number): { { key: string, weight: number, tier: string } }
	local out: { { key: string, weight: number, tier: string } } = {}
	local list = Config.ZoneTypes[zone]
	if not list then
		return out
	end
	for ti, tier in ipairs(Config.TierOrder) do
		local key = list[ti]
		if key then
			table.insert(out, { key = key, weight = Config.TierStats[tier].weight, tier = tier })
		end
	end
	return out
end

-- "1 in 370" style odds of a type within its zone.
function Econ.odds(key: string): string
	local def = Config.Balloons[key]
	if not def then
		return "?"
	end
	local entries = Econ.spawnTable(def.zone)
	for _, e in ipairs(entries) do
		if e.key == key then
			return Tiers.odds(entries, e)
		end
	end
	return "?"
end

function Econ.tierIndex(key: string): number
	local def = Config.Balloons[key]
	return def and (Tiers.index[def.tier] or 1) or 1
end

-- Which zone a world position is in (0 = between zones / on a bridge).
function Econ.zoneAt(pos: Vector3): number
	for i, z in ipairs(Config.Zones) do
		local dx, dz = pos.X - z.center.X, pos.Z - z.center.Z
		if math.abs(pos.Y - z.groundY) < 45 and dx * dx + dz * dz < z.radius * z.radius then
			return i
		end
	end
	return 0
end

-- Nearest zone by x/z only (for fall recovery).
function Econ.nearestZone(pos: Vector3): number
	local best, bestD = 1, math.huge
	for i, z in ipairs(Config.Zones) do
		local dx, dz = pos.X - z.center.X, pos.Z - z.center.Z
		local dd = dx * dx + dz * dz
		if dd < bestD then
			best, bestD = i, dd
		end
	end
	return best
end

return Econ

-- Shared economy formulas: upgrade costs/effects, multipliers, balloon values and HP, zone lookup.
-- The server uses these to grant; the client uses the same functions to draw prices and previews.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tiers = require(Shared:WaitForChild("Tiers"))

local Econ = {}

type Data = { [string]: any }

-- The server's clock (os.time() scale) on both sides: a phone's own clock can be off.
function Econ.now(): number
	return workspace:GetServerTimeNow()
end

function Econ.has(d: Data?, pass: string): boolean
	local passes: any = d and d.passes
	return type(passes) == "table" and passes[pass] == true
end

-- Seconds left on a tool trial (a pass lent for a few minutes), 0 when none.
function Econ.trialLeft(d: Data?, pass: string): number
	local t: any = d and d.trial
	local ends = type(t) == "table" and tonumber(t[pass]) or 0
	return math.max(0, (ends or 0) - Econ.now())
end

-- The pass's effect is on: owned, or a trial is running.
function Econ.perk(d: Data?, pass: string): boolean
	return Econ.has(d, pass) or Econ.trialLeft(d, pass) > 0
end

-- A server-wide boost (kit Boosts) from its ReplicatedStorage attributes: 1 when none is running.
function Econ.boostMult(kind: string): number
	local ends = ReplicatedStorage:GetAttribute("BoostEnd_" .. kind)
	if type(ends) ~= "number" or ends <= Econ.now() then
		return 1
	end
	local m = ReplicatedStorage:GetAttribute("Boost_" .. kind)
	return if type(m) == "number" then m else 1
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
	if Econ.perk(d, "GoldenDart") then
		p *= 3
	end
	return p
end

function Econ.cooldown(d: Data?): number
	return Econ.upgradeValue("speed", Econ.level(d, "speed"))
end

function Econ.auraRadius(d: Data?): number
	local r = Econ.upgradeValue("aura", Econ.level(d, "aura"))
	if Econ.perk(d, "Aura") then
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

export type LuckWith = { boost: boolean?, lucky: boolean?, server: number? }

-- Spawn luck near this player (kit Tiers luck: >1 shifts weight to rarer tiers). `blocked` = the player is under
-- Roblox's paid random item restriction: paid luck (the coin-bought Luck upgrade, Lucky Darts) does not apply.
-- `with` previews a purchase (shop odds): Lucky Boost on, Lucky Darts owned, a server luck boost of that size.
function Econ.luck(d: Data?, now: number, blocked: boolean?, with: LuckWith?): number
	local w: LuckWith = with or {}
	local l = 1
	if not blocked then
		l = Econ.upgradeValue("luck", Econ.level(d, "luck"))
		if Econ.has(d, "Lucky") or w.lucky then
			l *= 1.5
		end
	end
	if Econ.luckBoostActive(d, now) or w.boost then
		l *= 2
	end
	return l * math.max(Econ.boostMult("luck"), w.server or 1)
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
	if Econ.perk(d, "Coins2x") then
		m *= 2
	end
	if Econ.has(d, "Pumpkin") then
		m *= 1.2
	end
	if Econ.has(d, "VIP") then
		m *= 1.25
	end
	if d and d.premium == true then
		m *= 1.1
	end
	return m * (1 + Econ.indexBonus(d))
end

-- Everything that multiplies coin income right now: the player's own multiplier, the server coin boost and
-- the friends-in-server bonus (server: kit Live.friendMult; client: 1 + friendBonus x the Friends attribute).
function Econ.incomeMult(d: Data?, friendMult: number): number
	return Econ.coinMult(d) * Econ.boostMult("coins") * friendMult
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
	local base = def.value or (def.boss and Config.Boss.value) or Config.TierStats[def.tier].value
	return math.max(1, math.floor(base * zm * Econ.coinMult(d)))
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

-- Spawn odds of a type within its zone as a percent ("0.27%"; the zone's 7 add up to 100%). With a luck other
-- than 1 it reads "0.27%  ->  0.6% 🍀": the base chance, then the chance with this luck (kit Tiers.oddsLive).
function Econ.odds(key: string, luck: number?): string
	local def = Config.Balloons[key]
	if not def then
		return "?"
	end
	local entries = Econ.spawnTable(def.zone)
	for _, e in ipairs(entries) do
		if e.key == key then
			return Tiers.oddsLive(entries, e, luck)
		end
	end
	return "?"
end

-- Every type of a zone with its chance in percent at this luck (same maths as the spawner's Tiers.roll).
function Econ.zoneOdds(zone: number, luck: number?): { { key: string, tier: string, pct: number } }
	local entries = Econ.spawnTable(zone)
	local ps = Tiers.percents(entries, luck)
	local out = {}
	for i, e in ipairs(entries) do
		table.insert(out, { key = e.key, tier = e.tier, pct = ps[i] })
	end
	return out
end

---------------------------------------------------------------------------------------------------------------
-- Zone meters, bosses, offers
---------------------------------------------------------------------------------------------------------------

function Econ.meter(d: Data?, zone: number): number
	local m: any = d and d.meter
	return type(m) == "table" and (tonumber(m[zone]) or 0) or 0
end

-- 0..1 popped toward the zone's boss.
function Econ.meterFrac(d: Data?, zone: number): number
	local goal = Config.Boss.goal[zone]
	if not goal then
		return 0
	end
	return math.clamp(Econ.meter(d, zone) / goal, 0, 1)
end

function Econ.bossBeaten(d: Data?, zone: number): number
	local b: any = d and d.bosses
	return type(b) == "table" and (tonumber(b[zone]) or 0) or 0
end

-- How many zones' bosses this player has beaten at least once.
function Econ.bossCount(d: Data?): number
	local n = 0
	for z = 1, #Config.Zones do
		if Econ.bossBeaten(d, z) > 0 then
			n += 1
		end
	end
	return n
end

-- Seconds left in the Starter Pack window (its catalog `window` after the first join, first session only: the
-- same rule kit Shop enforces); 0 when closed or bought.
function Econ.starterLeft(d: Data?): number
	if not d or d.starter or (type(d.bought) == "table" and d.bought.Starter) or (tonumber(d.sessions) or 1) > 1 then
		return 0
	end
	local first = tonumber(d.firstJoin)
	if not first then
		return 0
	end
	return math.max(0, first + (Config.Products.Starter.window or 600) - Econ.now())
end

-- The 9 R$ Welcome Deal: only for players who never bought anything (kit Shop refuses it once d.spent > 0;
-- pass purchases do not count in d.spent, so owners of a pass are not offered it either).
function Econ.introOpen(d: Data?): boolean
	if not d or (tonumber(d.spent) or 0) > 0 or (type(d.bought) == "table" and d.bought.Intro) then
		return false
	end
	local passes: any = d.passes
	if type(passes) == "table" then
		for _, owned in pairs(passes) do
			if owned then
				return false
			end
		end
	end
	return true
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

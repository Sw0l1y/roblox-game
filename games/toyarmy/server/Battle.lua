-- Auto-battles simulated on the server as plain numbers; clients only animate the volleys they are sent.
-- A Fight has two sides (att/def). Each volley every living unit hits random enemies; specials:
-- splash (Bazooka) second target at 50%, heal (Medic) heals the most hurt ally, armor (Tank) takes 30% less,
-- air (Heli) two targets, rally (General) +20% squad attack, stomp (Robot Dino) three targets.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Battle = {}

export type Unit = {
	id: number,
	unit: string,
	mut: string,
	stack: string,
	kind: string, -- "P" (a player's), "AI" (the AI commander's), "WILD" (wind-up toys guarding neutral zones)
	owner: Player?,
	userId: number,
	ownerName: string,
	team: string, -- "Green", "Tan" or "Wild"
	atk: number,
	hp: number,
	maxHp: number,
	special: string,
	power: number,
	gone: boolean?, -- owner left mid-fight
}

export type Fight = {
	key: string, -- zone id, or "drill:<userId>" for outpost drills
	zoneId: string,
	attTeam: string,
	defTeam: string,
	att: { Unit },
	def: { Unit },
	volley: number,
	drill: Player?,
	cancelled: boolean,
	participants: { [Player]: string }, -- player -> "att" / "def"
	usedTank: { [Player]: boolean },
}

-- Compact event sent to clients per hit: { fromId, toId, amount, flag } with flag 0 = hit, 1 = knock-out, 2 = heal.
export type Event = { number }

local nextId = 0
function Battle.newId(): number
	nextId += 1
	return nextId
end

function Battle.makeUnit(unitKey: string, mut: string, kind: string, owner: Player?, team: string, ownerName: string, bonus: number): Unit
	local def = Config.UnitByKey[unitKey] or Config.Units[1]
	local m = Config.mutMult(mut) * bonus
	local atk = def.atk * m
	local hp = def.hp * m
	return {
		id = Battle.newId(),
		unit = def.key,
		mut = mut,
		stack = Config.stack(def.key, mut),
		kind = kind,
		owner = owner,
		userId = owner and owner.UserId or 0,
		ownerName = ownerName,
		team = team,
		atk = atk,
		hp = hp,
		maxHp = hp,
		special = def.special,
		power = atk + hp / 3,
	}
end

function Battle.alive(list: { Unit }): { Unit }
	local out = {}
	for _, u in ipairs(list) do
		if u.hp > 0 and not u.gone then
			table.insert(out, u)
		end
	end
	return out
end

function Battle.power(list: { Unit }): number
	local p = 0
	for _, u in ipairs(list) do
		if u.hp > 0 and not u.gone then
			p += u.atk + u.hp / 3
		end
	end
	return p
end

local function healthFrac(list: { Unit }): number
	local hp, max = 0, 0
	for _, u in ipairs(list) do
		if not u.gone then
			hp += math.max(0, u.hp)
			max += u.maxHp
		end
	end
	return max > 0 and hp / max or 0
end

-- Build a squad worth about `budget` power: k units of the best tier that fits budget/3, then fill greedily.
function Battle.compose(budget: number, maxCount: number, kind: string, team: string, ownerName: string, bonus: number?): { Unit }
	local out: { Unit } = {}
	local b = bonus or 1
	local remaining = math.max(budget, 18)
	local function add(key: string)
		table.insert(out, Battle.makeUnit(key, "", kind, nil, team, ownerName, b))
		remaining -= Config.power(key, "") * b
	end
	-- the backbone: the strongest type with three of them inside the budget (never the secret Dino for wild toys)
	local top = 1
	local last = kind == "WILD" and #Config.Units - 2 or #Config.Units - 1
	for i = 1, last do
		if Config.power(Config.Units[i].key, "") * b * 3 <= remaining then
			top = i
		end
	end
	local backbone = Config.Units[top].key
	for _ = 1, math.min(3, maxCount) do
		if Config.power(backbone, "") * b * 0.85 <= remaining or #out == 0 then
			add(backbone)
		end
	end
	for i = math.min(top + 1, last), 1, -1 do
		local key = Config.Units[i].key
		while #out < maxCount and Config.power(key, "") * b * 0.85 <= remaining do
			add(key)
		end
	end
	return out
end

local function rallyMult(list: { Unit }): number
	for _, u in ipairs(list) do
		if u.special == "rally" and u.hp > 0 and not u.gone then
			return 1.2
		end
	end
	return 1
end

-- One volley. Returns the events and the winning team when the fight is over.
function Battle.step(f: Fight, rng: Random): ({ Event }, string?)
	f.volley += 1
	local events: { Event } = {}
	local att = Battle.alive(f.att)
	local def = Battle.alive(f.def)
	if #att == 0 or #def == 0 then
		return events, (#def > 0 or #att == 0) and f.defTeam or f.attTeam
	end
	local damage: { [Unit]: number } = {}
	local heals: { [Unit]: number } = {}
	local lastHit: { [Unit]: Event } = {}

	local function act(u: Unit, allies: { Unit }, enemies: { Unit }, rally: number)
		local base = u.atk * Config.DamageScale * rng:NextNumber(0.85, 1.15) * rally
		local hits: { number } = { 1 }
		if u.special == "splash" then
			hits = { 1, 0.5 }
		elseif u.special == "air" then
			hits = { 1, 0.6 }
		elseif u.special == "stomp" then
			hits = { 1, 1, 1 }
		elseif u.special == "heal" then
			hits = { 0.7 }
			local worst, frac = nil :: Unit?, 0.98
			for _, a in ipairs(allies) do
				local fr = a.hp / a.maxHp
				if fr < frac then
					worst, frac = a, fr
				end
			end
			if worst then
				local amount = u.atk * 0.45 * rally
				heals[worst] = (heals[worst] or 0) + amount
				table.insert(events, { u.id, worst.id, math.floor(amount + 0.5), 2 })
			end
		end
		local start = rng:NextInteger(1, #enemies)
		for i, mult in ipairs(hits) do
			local target = enemies[(start + i - 2) % #enemies + 1]
			local dmg = base * mult
			if target.special == "armor" then
				dmg *= 0.7
			end
			damage[target] = (damage[target] or 0) + dmg
			local ev = { u.id, target.id, math.max(1, math.floor(dmg + 0.5)), 0 }
			table.insert(events, ev)
			lastHit[target] = ev
		end
	end

	local ra, rd = rallyMult(att), rallyMult(def)
	for _, u in ipairs(att) do
		act(u, att, def, ra)
	end
	for _, u in ipairs(def) do
		act(u, def, att, rd)
	end
	for u, h in pairs(heals) do
		u.hp = math.min(u.maxHp, u.hp + h)
	end
	for u, dmg in pairs(damage) do
		u.hp -= dmg
		if u.hp <= 0 then
			local ev = lastHit[u]
			if ev then
				ev[4] = 1
			end
		end
	end

	att = Battle.alive(f.att)
	def = Battle.alive(f.def)
	if #def == 0 and #att > 0 then
		return events, f.attTeam
	elseif #att == 0 then
		return events, f.defTeam
	elseif f.volley >= Config.MaxVolleys then
		return events, healthFrac(f.att) > healthFrac(f.def) and f.attTeam or f.defTeam
	end
	return events, nil
end

-- Wire format for clients: { id, unitKey, mut, team, ownerName, userId }
function Battle.pack(list: { Unit }): { { any } }
	local out = {}
	for _, u in ipairs(list) do
		if not u.gone then
			table.insert(out, { u.id, u.unit, u.mut, u.team, u.ownerName, u.userId, math.floor(u.power) })
		end
	end
	return out
end

return Battle

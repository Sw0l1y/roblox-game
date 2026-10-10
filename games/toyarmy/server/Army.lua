-- A player's toy box: unit stacks ("Tank|Gold" -> count), bags, merges in the mold press, plastic, XP and rank.
-- Units out in zones are "busy"; knocked-over units are "recovering" for a few seconds. Neither can merge.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local Fmt = require(Shared:WaitForChild("Fmt"))
local Data = require(script.Parent:WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local Battle = require(script.Parent:WaitForChild("Battle"))

local Army = {}

type Dict = { [string]: any }
export type Result = { unit: string, mut: string, tier: string, new: boolean }

local busy: { [Player]: { [string]: number } } = {}
local recovering: { [Player]: { { stack: string, t: number } } } = {}
local rng = Random.new()

local rewardRemote = Net.event("Reward")
local bagRemote = Net.event("BagResult")
local mergedRemote = Net.event("Merged")
local announceRemote = Net.event("Announce")
local feedRemote = Net.event("Feed")

local hooks: { [string]: { (Player, Dict, any) -> () } } = { bag = {}, merge = {}, upgrade = {}, rank = {} }

function Army.on(event: string, cb: (Player, Dict, any) -> ())
	table.insert(hooks[event], cb)
end

local function fire(event: string, player: Player, d: Dict, arg: any)
	for _, cb in ipairs(hooks[event]) do
		task.spawn(cb, player, d, arg)
	end
end

function Army.feed(text: string, color: string?)
	feedRemote:FireAllClients(text, color or "white")
end

-- Ranks, bonuses ------------------------------------------------------------------------------------------

function Army.rank(d: Dict): number
	return Config.rankOf(d.xp or 0)
end

function Army.bonus(player: Player, d: Dict): number
	return Config.rankBonus(Army.rank(d)) * (Shop.owns(player, "pro") and 1.25 or 1)
end

function Army.capacity(player: Player, d: Dict): number
	return Config.capacity(d.upgrades.box or 0, Shop.owns(player, "bigbox"))
end

function Army.squadSize(player: Player, d: Dict): number
	return Config.squadSize(d.upgrades.squad or 0, Shop.owns(player, "pro"))
end

function Army.count(d: Dict): number
	local n = 0
	for _, c in pairs(d.units) do
		n += c
	end
	return n + #d.merging
end

function Army.armyPower(player: Player, d: Dict): number
	local p = 0
	for stack, c in pairs(d.units) do
		local u, m = Config.split(stack)
		p += Config.power(u, m) * c
	end
	return p * Army.bonus(player, d)
end

-- Units --------------------------------------------------------------------------------------------------

local function busyOf(player: Player): { [string]: number }
	local b = busy[player]
	if not b then
		b = {}
		busy[player] = b
	end
	return b
end

function Army.available(player: Player, d: Dict, stack: string): number
	local n = d.units[stack] or 0
	n -= busyOf(player)[stack] or 0
	for _, r in ipairs(recovering[player] or {}) do
		if r.stack == stack then
			n -= 1
		end
	end
	return math.max(0, n)
end

function Army.busyCount(player: Player): number
	local n = 0
	for _, c in pairs(busyOf(player)) do
		n += c
	end
	return n
end

-- Stacks ready to deploy, strongest first: { {stack, n, power} }
export type Ready = { stack: string, n: number, power: number }
function Army.ready(player: Player, d: Dict): { Ready }
	local out: { Ready } = {}
	for stack in pairs(d.units) do
		local n = Army.available(player, d, stack)
		if n > 0 then
			local u, m = Config.split(stack)
			table.insert(out, { stack = stack, n = n, power = Config.power(u, m) })
		end
	end
	table.sort(out, function(a: Ready, b: Ready)
		return a.power > b.power
	end)
	return out
end

-- Power of the strongest squad this player could field (busy units included): what the AI scales to.
function Army.squadPower(player: Player, d: Dict): number
	local list: { number } = {}
	for stack, c in pairs(d.units) do
		local u, m = Config.split(stack)
		for _ = 1, math.min(c, 12) do
			table.insert(list, Config.power(u, m))
		end
	end
	table.sort(list, function(a: number, b: number)
		return a > b
	end)
	local p = 0
	for i = 1, math.min(#list, Army.squadSize(player, d)) do
		p += list[i]
	end
	return p * Army.bonus(player, d)
end

-- Take up to n of the strongest ready units out of the box as battle units.
function Army.pickSquad(player: Player, n: number): { Battle.Unit }
	local d = Data.get(player)
	local out: { Battle.Unit } = {}
	if not d or n <= 0 then
		return out
	end
	local team = (player:GetAttribute("Side") :: string?) or "Green"
	local bonus = Army.bonus(player, d)
	local b = busyOf(player)
	for _, r in ipairs(Army.ready(player, d)) do
		for _ = 1, r.n do
			if #out >= n then
				break
			end
			local u, m = Config.split(r.stack)
			table.insert(out, Battle.makeUnit(u, m, "P", player, team, player.DisplayName, bonus))
			b[r.stack] = (b[r.stack] or 0) + 1
		end
		if #out >= n then
			break
		end
	end
	return out
end

-- A unit comes home (knocked = it fell over and needs a moment to stand back up).
function Army.release(player: Player, stack: string, knocked: boolean)
	local b = busy[player]
	if not b or not player.Parent then
		return
	end
	b[stack] = math.max(0, (b[stack] or 0) - 1)
	if b[stack] == 0 then
		b[stack] = nil
	end
	if knocked then
		local r = recovering[player]
		if not r then
			r = {}
			recovering[player] = r
		end
		table.insert(r, { stack = stack, t = os.clock() + Config.RecoverTime })
	end
	Data.dirty(player)
end

function Army.recoveringCount(player: Player): number
	return #(recovering[player] or {})
end

function Army.tickRecover()
	local now = os.clock()
	for player, list in pairs(recovering) do
		local changed = false
		for i = #list, 1, -1 do
			if list[i].t <= now then
				table.remove(list, i)
				changed = true
			end
		end
		if changed and player.Parent then
			Data.dirty(player)
		end
	end
end

-- Busy/recovering counts for the client (pushed as player attributes; the save data never holds them).
function Army.publishBusy(player: Player)
	local parts = {}
	for stack, c in pairs(busyOf(player)) do
		table.insert(parts, stack .. "=" .. c)
	end
	for _, r in ipairs(recovering[player] or {}) do
		table.insert(parts, r.stack .. "=r")
	end
	player:SetAttribute("Busy", table.concat(parts, ";"))
end

function Army.cleanup(player: Player)
	busy[player] = nil
	recovering[player] = nil
end

function Army.clearBusy(player: Player)
	busy[player] = {}
	recovering[player] = {}
end

-- Adds units (ignores capacity: callers check it when it matters). Returns true if the stack is new in the index.
function Army.addUnits(player: Player, d: Dict, unitKey: string, mut: string, n: number): boolean
	local stack = Config.stack(unitKey, mut)
	d.units[stack] = (d.units[stack] or 0) + n
	local new = not d.index[stack]
	if new then
		d.index[stack] = true
		d.index[unitKey] = true
		local def = Config.UnitByKey[unitKey]
		Army.addXp(player, d, Config.Xp.discover * (Tiers.index[def and def.tier or "Common"] or 1))
	end
	Data.dirty(player)
	return new
end

-- Economy -------------------------------------------------------------------------------------------------

export type PlasticOpts = { pos: Vector3?, kind: string?, raw: boolean? }

-- Adds plastic with pass multipliers (2x Plastic, VIP +10%, Roblox Premium +10%) unless raw. Returns the amount added.
function Army.addPlastic(player: Player, d: Dict, amount: number, opts: PlasticOpts?): number
	local o: PlasticOpts = opts or {}
	local a = amount
	if not o.raw then
		if Shop.owns(player, "x2plastic") then
			a *= 2
		end
		if Shop.owns(player, "vip") then
			a *= 1.1
		end
		if player.MembershipType == Enum.MembershipType.Premium then
			a *= 1.1 -- Roblox Premium perk
		end
	end
	a = math.floor(a + 0.5)
	if a <= 0 then
		return 0
	end
	d.plastic += a
	Data.dirty(player)
	rewardRemote:FireClient(player, o.kind or "plastic", a, o.pos)
	return a
end

function Army.addXp(player: Player, d: Dict, amount: number)
	local before = Army.rank(d)
	d.xp = (d.xp or 0) + math.floor(amount)
	local after = Army.rank(d)
	Data.dirty(player)
	if after > before then
		local rk = Config.Ranks[after]
		rewardRemote:FireClient(player, "rank", after)
		Army.feed("⭐ " .. player.DisplayName .. " was promoted to " .. rk.name .. "!", "yellow")
		fire("rank", player, d, after)
	end
end

-- Free bags waiting to be opened (capped at Config.MaxTokens unless `force`, e.g. bought bags).
function Army.addTokens(player: Player, d: Dict, bag: string, n: number, pos: Vector3?, force: boolean?)
	local total = 0
	for _, c in pairs(d.tokens) do
		total += c
	end
	local add = force and n or math.min(n, math.max(0, Config.MaxTokens - total))
	if add > 0 then
		d.tokens[bag] = (d.tokens[bag] or 0) + add
		Data.dirty(player)
		rewardRemote:FireClient(player, "bag", add, pos, bag)
	end
end

-- Bags ----------------------------------------------------------------------------------------------------

local function luckOf(player: Player, d: Dict): (number, number)
	local boosted = (d.boosts.luck or 0) > os.time()
	local luck = (1 + 0.06 * (d.upgrades.lucky or 0)) * (boosted and 2 or 1)
	local mutMult = (1 + 0.03 * (d.upgrades.lucky or 0)) * (boosted and 2 or 1)
	return luck, mutMult
end

local function rollMut(mult: number): string
	for i = #Config.Mutations, 1, -1 do
		local m = Config.Mutations[i]
		if rng:NextNumber() < m.chance * mult then
			return m.key
		end
	end
	return ""
end

local function announce(player: Player, unitKey: string, mut: string)
	local def = Config.UnitByKey[unitKey]
	if not def then
		return
	end
	local ti = Tiers.index[def.tier] or 1
	if ti >= 5 or mut == "Rainbow" or (ti >= 4 and mut ~= "") then
		local t = Tiers.get(def.tier)
		local name = Config.unitName(unitKey, mut)
		local text = def.tier == "Secret" and ("🦖 " .. player.DisplayName .. " found the SECRET " .. name .. "!!")
			or ("🎉 " .. player.DisplayName .. " got a " .. string.upper(t.name) .. " " .. name .. "!")
		announceRemote:FireAllClients(text, def.tier)
	end
end

-- Open one bag (with plastic, or a free bag token). Returns ok, reason.
function Army.openBag(player: Player, bagKey: string, useToken: boolean): (boolean, string?)
	local d = Data.get(player)
	local bag = Config.BagByKey[bagKey]
	if not d or not bag then
		return false, nil
	end
	local rank = Army.rank(d)
	if useToken then
		if (d.tokens[bagKey] or 0) <= 0 then
			return false, "No free " .. bag.name .. " left!"
		end
	else
		if rank < bag.rank then
			return false, "Reach rank " .. Config.Ranks[bag.rank].name .. " to buy the " .. bag.name .. "!"
		end
		if d.plastic < bag.price then
			return false, "Need " .. Fmt.commas(bag.price) .. " 🧱 plastic!"
		end
	end
	if Army.count(d) + bag.count > Army.capacity(player, d) then
		return false, "Toy box full! Merge soldiers or upgrade your box 📦"
	end
	if useToken then
		d.tokens[bagKey] -= 1
	else
		d.plastic -= bag.price
	end
	local luck, mutMult = luckOf(player, d)
	local results: { Result } = {}
	local firstBag = (d.stats.bags or 0) == 0
	for i = 1, bag.count do
		local unitKey: string = "Rifleman"
		local mut: string = ""
		if firstBag then
			if i == 2 then
				mut = "Gold"
			end
		else
			local e = Tiers.roll(bag.odds, rng, luck)
			unitKey = e.key :: string
			mut = rollMut(mutMult)
		end
		local def = Config.UnitByKey[unitKey]
		local new = Army.addUnits(player, d, unitKey, mut, 1)
		table.insert(results, { unit = unitKey, mut = mut, tier = def and def.tier or "Common", new = new })
		announce(player, unitKey, mut)
	end
	d.stats.bags = (d.stats.bags or 0) + 1
	Army.addXp(player, d, Config.Xp.bag)
	Data.dirty(player)
	bagRemote:FireClient(player, bagKey, results)
	fire("bag", player, d, bagKey)
	return true, nil
end

-- Grant specific units with the bag reveal (supply drop, bundles).
function Army.grantReveal(player: Player, d: Dict, label: string, list: { { string } })
	local results: { Result } = {}
	for _, e in ipairs(list) do
		local def = Config.UnitByKey[e[1]]
		local new = Army.addUnits(player, d, e[1], e[2], 1)
		table.insert(results, { unit = e[1], mut = e[2], tier = def and def.tier or "Common", new = new })
		announce(player, e[1], e[2])
	end
	bagRemote:FireClient(player, label, results)
end

-- Merging ---------------------------------------------------------------------------------------------------

function Army.mergeSlots(player: Player): number
	return Shop.owns(player, "doublemold") and 2 or 1
end

-- Merge 3 of a unit type into the next one. The chosen stack goes first (one unit if it is mutated, so the
-- mutation carries up), then plain units, then other mutations. The result keeps the best mutation.
function Army.merge(player: Player, stack: string): (boolean, string?)
	local d = Data.get(player)
	if not d then
		return false, nil
	end
	local unitKey, mut = Config.split(stack)
	local nxt = Config.nextUnit(unitKey)
	if not Config.UnitByKey[unitKey] or not nxt then
		return false, "The Robot Dino is the ultimate toy!"
	end
	if #d.merging >= Army.mergeSlots(player) then
		return false, "The mold press is busy! ⏩"
	end
	local taken: { [string]: number } = {}
	local picks: { string } = {}
	local function take(st: string, maxN: number)
		local free = Army.available(player, d, st) - (taken[st] or 0)
		for _ = 1, math.min(free, maxN) do
			table.insert(picks, st)
			taken[st] = (taken[st] or 0) + 1
		end
	end
	if (d.stats.merges or 0) == 0 and unitKey == "Rifleman" then
		take(Config.stack(unitKey, "Gold"), 1) -- the very first merge carries the Gold rifleman up: a Gold Bazooka!
	end
	take(stack, mut ~= "" and 1 or 3 - #picks)
	take(Config.stack(unitKey, ""), 3 - #picks)
	for _, m in ipairs(Config.Mutations) do
		if #picks < 3 then
			take(Config.stack(unitKey, m.key), 3 - #picks)
		end
	end
	if #picks < 3 then
		return false, "Need 3 ready " .. Config.UnitByKey[unitKey].name .. "s!"
	end
	local best = ""
	for _, st in ipairs(picks) do
		local _, m = Config.split(st)
		d.units[st] -= 1
		if d.units[st] <= 0 then
			d.units[st] = nil
		end
		if Config.mutMult(m) > Config.mutMult(best) then
			best = m
		end
	end
	if best == "" and rng:NextNumber() < 0.03 then
		best = "Gold" -- lucky mold
	end
	local t = Config.mergeTime(nxt.key, d.upgrades.mold or 0, Shop.owns(player, "vip"))
	table.insert(d.merging, { key = Config.stack(nxt.key, best), start = os.time(), done = os.time() + math.ceil(t) })
	d.stats.merges = (d.stats.merges or 0) + 1
	Army.addXp(player, d, Config.Xp.mergePerTier * (Config.UnitIndex[nxt.key] or 1))
	Data.dirty(player)
	fire("merge", player, d, stack)
	return true, nil
end

function Army.skipMerges(player: Player, d: Dict)
	for _, m in ipairs(d.merging) do
		m.done = 0
	end
	Data.dirty(player)
end

function Army.tickMerges()
	local now = os.time()
	for player, d in pairs(Data.all()) do
		if player.Parent and #d.merging > 0 then
			for i = #d.merging, 1, -1 do
				local m = d.merging[i]
				if (m.done or 0) <= now then
					table.remove(d.merging, i)
					local u, mut = Config.split(m.key)
					local def = Config.UnitByKey[u]
					local new = Army.addUnits(player, d, u, mut, 1)
					mergedRemote:FireClient(player, { unit = u, mut = mut, tier = def and def.tier or "Common", new = new })
					announce(player, u, mut)
				end
			end
		end
	end
end

-- Upgrades --------------------------------------------------------------------------------------------------

function Army.upgrade(player: Player, key: string): (boolean, string?)
	local d = Data.get(player)
	local u = Config.UpgradeByKey[key]
	if not d or not u then
		return false, nil
	end
	local lvl = d.upgrades[key] or 0
	if lvl >= u.max then
		return false, u.name .. " is maxed out!"
	end
	local cost = Config.upgradeCost(key, lvl)
	if d.plastic < cost then
		return false, "Need " .. Fmt.commas(cost) .. " 🧱 plastic!"
	end
	d.plastic -= cost
	d.upgrades[key] = lvl + 1
	Data.dirty(player)
	fire("upgrade", player, d, key)
	return true, nil
end

-- Players present ----------------------------------------------------------------------------------------------

function Army.teamPlayers(team: string): { Player }
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("Side") == team and Data.get(p) then
			table.insert(out, p)
		end
	end
	return out
end

return Army

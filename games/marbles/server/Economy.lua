--!strict
-- Player economy: the marble collection (levels, stat points, copies), pack rolls with numeric odds,
-- the Shine Machine (mutations), tune-ups, daily login streak, daily league points and rewards,
-- index milestones, race payouts, offline practice earnings and Robux product grants.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local Net = require(Shared:WaitForChild("Net"))
local Fmt = require(Shared:WaitForChild("Fmt"))
local Data = require(script.Parent:WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Shop"))

local Economy = {}
local rng = Random.new()
local announceRemote = Net.event("Announce")

export type Entry = { id: string, mut: string?, lvl: number, xp: number, pts: number, spd: number, grip: number, wt: number, n: number, got: number }
export type PackItem = { id: string, mut: string?, tier: string, key: string, new: boolean, dupeXp: number }

Economy.onStartGP = nil :: ((Player) -> ())?

function Economy.defaults(): { [string]: any }
	return {
		coins = 0,
		marbles = {},
		index = {},
		indexClaimed = {},
		favorite = "",
		packs = {},
		trails = {},
		trail = "",
		races = 0,
		wins = 0,
		podiums = 0,
		perfects = 0,
		gpWins = 0,
		trophies = 0,
		packsOpened = 0,
		league = { day = 0, pts = 0, claimed = {} },
		daily = { last = 0, streak = 0 },
		ftue = { welcome = false, shine = false, teased = false, raced = false },
		luckUntil = 0,
		lastOnline = 0,
		starterBought = false,
		bestPlace = 0,
	}
end

function Economy.key(id: string, mut: string?): string
	if mut and mut ~= "" then
		return id .. ":" .. mut
	end
	return id
end

local function tierRank(id: string): number
	local def = Config.MarbleById[id]
	return def and (Tiers.index[def.tier] or 1) or 1
end

function Economy.today(): number
	return math.floor(os.time() / 86400)
end

-- Levels -------------------------------------------------------------------------------------------

function Economy.addXp(d: { [string]: any }, key: string, xp: number): number
	local e = d.marbles[key] :: Entry?
	if not e then
		return 0
	end
	local ups = 0
	e.xp += xp
	while e.lvl < Config.Level.max and e.xp >= Config.xpNeed(e.lvl) do
		e.xp -= Config.xpNeed(e.lvl)
		e.lvl += 1
		e.pts += 1
		ups += 1
	end
	if e.lvl >= Config.Level.max then
		e.xp = 0
	end
	return ups
end

-- Effective racing stats for an owned marble (or a loaner by id).
function Economy.stats(d: { [string]: any }?, key: string): (number, number, number, number)
	local e = d and d.marbles[key] :: Entry?
	local id = e and e.id or key:match("^[^:]+") or key
	local def = Config.MarbleById[id] or Config.Marbles[1]
	local k = Config.Level.statPerPoint
	local cap = Config.Level.statCap
	if e then
		return math.min(cap, def.spd + e.spd * k), math.min(cap, def.grip + e.grip * k), math.min(cap, def.wt + e.wt * k), e.lvl
	end
	return def.spd, def.grip, def.wt, 1
end

function Economy.power(d: { [string]: any }, key: string): number
	local s, g, w = Economy.stats(d, key)
	return s * 1.6 + g + w * 0.6
end

-- Best owned marble by power (the default pick); favourite wins if set.
function Economy.best(d: { [string]: any }): string?
	local fav = d.favorite
	if type(fav) == "string" and fav ~= "" and d.marbles[fav] then
		return fav
	end
	local best, bp = nil, -1
	for key in pairs(d.marbles) do
		local p = Economy.power(d, key)
		if p > bp then
			best, bp = key, p
		end
	end
	return best
end

-- Collection ----------------------------------------------------------------------------------------

local function announce(player: Player, id: string, mut: string?, verb: string)
	local def = Config.MarbleById[id]
	if not def then
		return
	end
	local rank = Tiers.index[def.tier] or 1
	if rank >= 5 or mut == "rainbow" or mut == "cosmic" then
		local m = mut and Config.MutationByKey[mut]
		local name = (m and (m.name .. " ") or "") .. def.name
		announceRemote:FireAllClients(string.format("%s %s %s %s!", player.DisplayName, verb, Tiers.get(def.tier).name:upper(), name), def.tier, mut)
	end
end

function Economy.grant(player: Player, d: { [string]: any }, reward: { [string]: any })
	if reward.kind == "coins" then
		d.coins += reward.amount
	elseif reward.kind == "pack" then
		d.packs[reward.pack] = (d.packs[reward.pack] or 0) + (reward.amount or 1)
	end
	Data.dirty(player)
end

function Economy.indexCount(d: { [string]: any }): number
	local n = 0
	for k in pairs(d.index) do
		if not string.find(k, ":") then
			n += 1
		end
	end
	return n
end

function Economy.checkIndex(player: Player, d: { [string]: any })
	local n = Economy.indexCount(d)
	for i, r in ipairs(Config.IndexRewards) do
		local k = tostring(i)
		if n >= r.count and not d.indexClaimed[k] then
			d.indexClaimed[k] = true
			Economy.grant(player, d, r :: any)
			Shop.notify(player, string.format("📖 Index %d discovered: %s!", r.count, r.text), "gold")
		end
	end
end

function Economy.addMarble(player: Player, d: { [string]: any }, id: string, mut: string?): (string, boolean, number)
	local key = Economy.key(id, mut)
	local e = d.marbles[key] :: Entry?
	local dupeXp = 0
	local isNew = e == nil
	if e then
		e.n += 1
		dupeXp = 30 * tierRank(id)
		Economy.addXp(d, key, dupeXp)
	else
		d.marbles[key] = { id = id, mut = mut, lvl = 1, xp = 0, pts = 0, spd = 0, grip = 0, wt = 0, n = 1, got = os.time() } :: Entry
	end
	local first = not d.index[id]
	d.index[id] = true
	if mut then
		d.index[key] = true
	end
	if first then
		Economy.checkIndex(player, d)
	end
	Data.dirty(player)
	return key, isNew, dupeXp
end

-- Packs -----------------------------------------------------------------------------------------------

function Economy.luck(player: Player, d: { [string]: any }): number
	local l = 1
	if Shop.owns(player, "LuckyCharm") then
		l *= Config.LuckyCharmMult
	end
	if (d.luckUntil or 0) > os.time() then
		l *= Config.LuckBoostMult
	end
	return l
end

function Economy.roll(packKey: string, luck: number): (string, string?)
	local pack = Config.PackByKey[packKey] or Config.Packs[1]
	local tier = Tiers.roll(pack.odds, rng, luck)
	local list = Config.MarblesByTier[tier.key] or Config.MarblesByTier.Common
	local def = list[rng:NextInteger(1, #list)]
	local mutLuck = luck >= Config.LuckBoostMult and 2 or 1
	local r = rng:NextNumber()
	local acc = 0
	local mut: string? = nil
	for i = #Config.Mutations, 1, -1 do
		local m = Config.Mutations[i]
		acc += m.chance * mutLuck
		if r < acc then
			mut = m.key
			break
		end
	end
	return def.id, mut
end

-- Open `count` packs (1, or 3 with Triple Open). Free packs in the inventory are used first.
function Economy.openPack(player: Player, packKey: string, count: number): { [string]: any }
	local d = Data.get(player)
	local pack = Config.PackByKey[packKey]
	if not d or not pack then
		return { ok = false, err = "Not ready yet!" }
	end
	count = (count == 3 and Shop.owns(player, "TripleOpen")) and 3 or 1
	local free = d.packs[packKey] or 0
	local items: { PackItem } = {}
	for _ = 1, count do
		if (d.packs[packKey] or 0) > 0 then
			d.packs[packKey] -= 1
		elseif pack.price > 0 and d.coins >= pack.price then
			d.coins -= pack.price
		else
			break
		end
		local id, mut = Economy.roll(packKey, Economy.luck(player, d))
		local key, isNew, dupeXp = Economy.addMarble(player, d, id, mut)
		local def = Config.MarbleById[id]
		table.insert(items, { id = id, mut = mut, tier = def.tier, key = key, new = isNew, dupeXp = dupeXp })
		d.packsOpened += 1
		announce(player, id, mut, "pulled")
	end
	if #items == 0 then
		return { ok = false, err = pack.price > 0 and ("Need " .. Fmt.commas(pack.price) .. " coins!") or "No free pack left!" }
	end
	if packKey == "welcome" then
		d.ftue.welcome = true
	end
	if (d.packs[packKey] or 0) <= 0 then
		d.packs[packKey] = nil
	end
	Data.dirty(player)
	return { ok = true, items = items, usedFree = free > 0 }
end

-- Upgrades --------------------------------------------------------------------------------------------

function Economy.upgrade(player: Player, key: string, stat: string): boolean
	local d = Data.get(player)
	if not d or (stat ~= "spd" and stat ~= "grip" and stat ~= "wt") then
		return false
	end
	local e = d.marbles[key] :: Entry?
	if not e or e.pts <= 0 then
		return false
	end
	local def = Config.MarbleById[e.id]
	local base = def and (def :: any)[stat] or 3
	if base + ((e :: any)[stat] + 1) * Config.Level.statPerPoint > Config.Level.statCap then
		Shop.notify(player, "That stat is maxed!", "orange")
		return false
	end
	(e :: any)[stat] += 1
	e.pts -= 1
	Data.dirty(player)
	return true
end

function Economy.tuneUp(player: Player, key: string): boolean
	local d = Data.get(player)
	if not d then
		return false
	end
	local e = d.marbles[key] :: Entry?
	if not e or e.lvl >= Config.Level.max then
		return false
	end
	if d.coins < Config.TuneUp.cost then
		Shop.notify(player, "Need " .. Config.TuneUp.cost .. " coins for a tune-up!", "red")
		return false
	end
	d.coins -= Config.TuneUp.cost
	local ups = Economy.addXp(d, key, Config.TuneUp.xp)
	if ups > 0 then
		Shop.notify(player, "⬆️ Level up! +" .. ups .. " stat point" .. (ups > 1 and "s" or ""), "green")
	end
	Data.dirty(player)
	return true
end

-- Shine Machine: base marble -> mutated. The first shine is free and always Gold.
function Economy.shine(player: Player, key: string): { [string]: any }
	local d = Data.get(player)
	if not d then
		return { ok = false, err = "Not ready" }
	end
	local e = d.marbles[key] :: Entry?
	if not e then
		return { ok = false, err = "Pick a marble you own." }
	end
	if e.mut then
		return { ok = false, err = "Already mutated!" }
	end
	local free = d.ftue.shine ~= true
	if not free then
		if d.coins < Config.Shine.cost then
			return { ok = false, err = "Need " .. Fmt.commas(Config.Shine.cost) .. " coins!" }
		end
		d.coins -= Config.Shine.cost
	end
	local mut: string? = nil
	if free then
		mut = "gold"
		d.ftue.shine = true
	else
		local luck = (d.luckUntil or 0) > os.time() and 2 or 1
		local odds = {}
		for _, o in ipairs(Config.Shine.odds) do
			table.insert(odds, { key = o.key, weight = o.key == "none" and o.weight or o.weight * luck })
		end
		local pick = Tiers.roll(odds, rng, 1)
		if pick.key ~= "none" then
			mut = pick.key
		end
	end
	Data.dirty(player)
	if not mut then
		return { ok = true, mut = nil, key = key }
	end
	local newKey = Economy.key(e.id, mut)
	local target = d.marbles[newKey] :: Entry?
	if target then
		target.n += 1
		Economy.addXp(d, newKey, 40 * tierRank(e.id))
	else
		d.marbles[newKey] = { id = e.id, mut = mut, lvl = e.lvl, xp = e.xp, pts = e.pts, spd = e.spd, grip = e.grip, wt = e.wt, n = 1, got = os.time() } :: Entry
	end
	if e.n > 1 then
		e.n -= 1
	else
		d.marbles[key] = nil
		if d.favorite == key then
			d.favorite = newKey
		end
	end
	d.index[newKey] = true
	announce(player, e.id, mut, "shined a")
	Data.dirty(player)
	return { ok = true, mut = mut, key = newKey }
end

-- Daily login streak ----------------------------------------------------------------------------------

function Economy.dailyReady(d: { [string]: any }): boolean
	return d.daily.last ~= Economy.today()
end

function Economy.claimDaily(player: Player): { [string]: any }?
	local d = Data.get(player)
	if not d or not Economy.dailyReady(d) then
		return nil
	end
	local day = Economy.today()
	if d.daily.last == day - 1 then
		d.daily.streak += 1
	else
		d.daily.streak = 1
	end
	d.daily.last = day
	local r: { [string]: any } = Config.Daily[(d.daily.streak - 1) % #Config.Daily + 1] :: any
	Economy.grant(player, d, r)
	Shop.notify(player, "📅 Day " .. d.daily.streak .. " reward: " .. r.text .. "!", "green")
	return r
end

-- Daily league ------------------------------------------------------------------------------------------

function Economy.leagueFresh(d: { [string]: any })
	local day = Economy.today()
	if d.league.day ~= day then
		d.league.day = day
		d.league.pts = 0
		d.league.claimed = {}
	end
end

function Economy.claimLeague(player: Player, tierIndex: number): boolean
	local d = Data.get(player)
	local tier = Config.League.tiers[tierIndex]
	if not d or not tier then
		return false
	end
	Economy.leagueFresh(d)
	local k = tostring(tierIndex)
	if d.league.pts < tier.pts or d.league.claimed[k] then
		return false
	end
	d.league.claimed[k] = true
	Economy.grant(player, d, tier.reward :: any)
	if tierIndex == #Config.League.tiers then
		d.trophies += 1
	end
	Shop.notify(player, "🏅 " .. tier.key .. " league reward: " .. tier.text .. "!", "gold")
	Data.dirty(player)
	return true
end

-- Race payout -------------------------------------------------------------------------------------------

function Economy.coinMult(player: Player, mut: string?): number
	local m = 1
	local mm = mut and Config.MutationByKey[mut]
	if mm then
		m *= mm.mult
	end
	if Shop.owns(player, "CoinsX2") then
		m *= 2
	end
	if Shop.owns(player, "VIP") then
		m *= Config.Payout.vipMult
	end
	return m
end

-- info: place, perfects, kind ("main"/"practice"/"gp"), key (marble key raced), owned (not a loaner), mut
function Economy.raceReward(player: Player, info: { [string]: any }): { [string]: any }?
	local d = Data.get(player)
	if not d then
		return nil
	end
	local P = Config.Payout
	local place = math.clamp(info.place, 1, #P.coins)
	local kindMult = info.kind == "practice" and P.practiceMult or (info.kind == "gp" and P.gpMult or 1)
	local mult = Economy.coinMult(player, info.mut)
	local coins = math.floor((P.coins[place] + info.perfects * P.perfectCoins) * kindMult * mult + 0.5)
	local xp = math.floor((P.xp[place] + info.perfects * P.perfectXp) * (info.kind == "gp" and 1.5 or 1))
	local league = info.kind == "practice" and 1 or P.league[place] * (info.kind == "gp" and 2 or 1)
	d.coins += coins
	local ups = 0
	if info.owned then
		ups = Economy.addXp(d, info.key, xp)
	end
	Economy.leagueFresh(d)
	d.league.pts += league
	d.races += 1
	d.perfects += info.perfects
	if place == 1 and info.kind ~= "practice" then
		d.wins += 1
	end
	if place <= 3 then
		d.podiums += 1
	end
	if d.bestPlace == 0 or place < d.bestPlace then
		d.bestPlace = place
	end
	local firstRace = d.ftue.raced ~= true
	d.ftue.raced = true
	if not d.ftue.welcome and (d.packs.welcome or 0) == 0 then
		d.packs.welcome = 1
	end
	Data.dirty(player)
	return { coins = coins, xp = xp, league = league, levelUps = ups, place = place, mult = mult, kindMult = kindMult, firstRace = firstRace, owned = info.owned, key = info.key }
end

-- Offline practice earnings ----------------------------------------------------------------------------

function Economy.offline(d: { [string]: any }): (number, number)
	local last = d.lastOnline or 0
	d.lastOnline = os.time()
	if last <= 0 then
		return 0, 0
	end
	local mins = math.min((os.time() - last) / 60, Config.Offline.maxHours * 60)
	if mins < Config.Offline.minMinutes then
		return 0, 0
	end
	local owned = 0
	for _ in pairs(d.marbles) do
		owned += 1
	end
	local coins = math.floor(mins * (Config.Offline.perMinute + Config.Offline.perMarble * math.min(owned, 60)))
	d.coins += coins
	return coins, math.floor(mins)
end

-- Robux products -----------------------------------------------------------------------------------------

function Economy.productGrants(): { [string]: (Player, { [string]: any }) -> boolean }
	local function trail(key: string): (Player, { [string]: any }) -> boolean
		return function(player, d)
			d.trails[key] = true
			d.trail = key
			Shop.notify(player, "New trail equipped!", "purple")
			return true
		end
	end
	return {
		StarterPack = function(player, d)
			d.coins += 2000
			d.packs.mega = (d.packs.mega or 0) + 1
			d.starterBought = true
			Shop.notify(player, "🎒 Starter Pack: 2,000 coins + a Mega Pack!", "green")
			return true
		end,
		CoinsS = function(_player, d)
			d.coins += 1500
			return true
		end,
		CoinsM = function(_player, d)
			d.coins += 8000
			return true
		end,
		CoinsL = function(_player, d)
			d.coins += 50000
			return true
		end,
		LuckBoost = function(player, d)
			d.luckUntil = math.max(os.time(), d.luckUntil or 0) + Config.LuckBoostSeconds
			Shop.notify(player, "🍀 Luck Boost active for 15 minutes!", "green")
			return true
		end,
		GalaxyPack = function(_player, d)
			d.packs.galaxy = (d.packs.galaxy or 0) + 1
			return true
		end,
		TrailSparkle = trail("sparkle"),
		TrailFlame = trail("flame"),
		TrailRainbow = trail("rainbow"),
		StartGP = function(player, _d)
			local cb = Economy.onStartGP
			if cb then
				cb(player)
			end
			return true
		end,
		DiamondMarble = function(player, d)
			Economy.addMarble(player, d, "diamond", nil)
			announceRemote:FireAllClients(player.DisplayName .. " got the DIAMOND MARBLE! 💎", "Secret", nil)
			return true
		end,
	}
end

function Economy.onPass(player: Player, key: string)
	local d = Data.get(player)
	if not d then
		return
	end
	if key == "VIP" then
		d.trails.gold = true
		if d.trail == "" then
			d.trail = "gold"
		end
		Data.dirty(player)
	end
end

-- Leaving players: remember when, for offline earnings.
function Economy.stamp(player: Player)
	local d = Data.get(player)
	if d then
		d.lastOnline = os.time()
	end
end

local _ = Players
return Economy

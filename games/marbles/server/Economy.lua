--!strict
-- Player economy: the marble collection (levels, stat points, copies), pack rolls with % odds and luck,
-- the Shine Machine (mutations), tune-ups, daily login streak (and Keep Streak), daily league points and
-- rewards, index milestones, race payouts (server boosts, friend bonus), offline practice earnings, launch
-- rewards (kit Live) and Robux product grants.
-- Paid random items: a player under Roblox's paid random item restriction (kit Policy) never gets a roll
-- they paid for with coins (coins are sold for Robux): coin packs give the pack's fixed marble of the day
-- and the Shine Machine a fixed Gold shine, both shown before paying. Free packs still roll.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local Net = require(Shared:WaitForChild("Net"))
local Fmt = require(Shared:WaitForChild("Fmt"))
local Data = require(script.Parent:WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local Policy = require(script.Parent:WaitForChild("Policy"))
local Boosts = require(script.Parent:WaitForChild("Boosts"))
local Live = require(script.Parent:WaitForChild("Live"))

local Economy = {}
local rng = Random.new()
local announceRemote = Net.event("Announce")

export type Entry = { id: string, mut: string?, lvl: number, xp: number, pts: number, spd: number, grip: number, wt: number, n: number, got: number }
export type PackItem = { id: string, mut: string?, tier: string, key: string, new: boolean, dupeXp: number }

Economy.onStartGP = nil :: ((Player) -> ())?
-- Round modifier bought for the next race: (buyer, { mode = "chaos"|"ice"|"bigair"|"none", theme = string? }).
Economy.onRoundMod = nil :: ((Player, { [string]: any }) -> ())?
-- What a player saw in the shop right before buying (deal marble id, custom round choice), set by Main.
Economy.want = {} :: { [Player]: { [string]: any } }

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
		spent = 0,
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
	if n >= 30 then
		Live.badge(player, "Index30")
	end
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

-- Current luck: Lucky Charm pass x personal Luck Boost x server luck boost. The client mirrors this
-- (Hud.luck) so every odds screen shows the same numbers the roll uses.
function Economy.luck(player: Player, d: { [string]: any }): number
	local l = 1
	if Shop.owns(player, "LuckyCharm") then
		l *= Config.LuckyCharmMult
	end
	if (d.luckUntil or 0) > os.time() then
		l *= Config.LuckBoostMult
	end
	return l * Boosts.mult("luck")
end

-- One pack pull: tier (pack odds) then a marble of that tier, then a mutation (Config.PackMutations), both
-- with the same luck maths the odds screens show (kit Tiers.percents).
function Economy.roll(packKey: string, luck: number): (string, string?)
	local pack = Config.PackByKey[packKey] or Config.Packs[1]
	local tier = Tiers.roll(pack.odds, rng, luck)
	local list = Config.MarblesByTier[tier.key] or Config.MarblesByTier.Common
	local def = list[rng:NextInteger(1, #list)]
	local m = Tiers.roll(Config.PackMutations, rng, luck)
	return def.id, if m.key ~= "none" then m.key else nil
end

-- A fixed marble for a restricted player's coin pack: today's, or yesterday's if the shop showed that one
-- just before midnight.
local function fixedPick(packKey: string, expect: string?): string
	local day = Economy.today()
	if expect and expect == Config.fixedMarble(packKey, day - 1) then
		return expect
	end
	return Config.fixedMarble(packKey, day)
end

-- Open `count` packs (1, or 3 with Triple Open). Free packs in the inventory are used first (and always
-- roll). expect: the fixed marble the client showed a restricted player.
function Economy.openPack(player: Player, packKey: string, count: number, expect: string?): { [string]: any }
	local d = Data.get(player)
	local pack = Config.PackByKey[packKey]
	if not d or not pack then
		return { ok = false, err = "Not ready yet!" }
	end
	count = (count == 3 and Shop.owns(player, "TripleOpen")) and 3 or 1
	local free = d.packs[packKey] or 0
	local blocked = Policy.randomBlocked(player)
	local items: { PackItem } = {}
	for _ = 1, count do
		local paid = false
		if (d.packs[packKey] or 0) > 0 then
			d.packs[packKey] -= 1
		elseif pack.price > 0 and d.coins >= pack.price then
			d.coins -= pack.price
			paid = true
		else
			break
		end
		local id: string, mut: string?
		if paid and blocked then
			id, mut = fixedPick(packKey, expect), nil
		else
			id, mut = Economy.roll(packKey, Economy.luck(player, d))
		end
		local key, isNew, dupeXp = Economy.addMarble(player, d, id, mut)
		local def = Config.MarbleById[id]
		table.insert(items, { id = id, mut = mut, tier = def.tier, key = key, new = isNew, dupeXp = dupeXp })
		d.packsOpened += 1
		announce(player, id, mut, "pulled")
		if (Tiers.index[def.tier] or 1) >= 5 then
			Live.badge(player, "Legendary")
		end
	end
	if #items > 0 then
		Live.quest(player, "pack", #items)
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
-- expectFixed: whether the client showed the fixed Gold shine (paid random restriction) or the odds, so a
-- player is never charged for a different shine than the one on screen.
function Economy.shine(player: Player, key: string, expectFixed: boolean?): { [string]: any }
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
	local fixed = not free and Policy.randomBlocked(player)
	local cost = fixed and Config.Shine.fixedCost or Config.Shine.cost
	if not free and expectFixed ~= nil and expectFixed ~= fixed then
		return { ok = false, err = "The Shine Machine changed - take another look!" }
	end
	if not free then
		if d.coins < cost then
			return { ok = false, err = "Need " .. Fmt.commas(cost) .. " coins!" }
		end
		d.coins -= cost
	end
	local mut: string? = nil
	if free then
		mut = "gold"
		d.ftue.shine = true
	elseif fixed then
		mut = Config.Shine.fixedMut
	else
		local pick = Tiers.roll(Config.Shine.odds, rng, Economy.luck(player, d))
		if pick.key ~= "none" then
			mut = pick.key
		end
	end
	Live.quest(player, "shine", 1)
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

-- On join: a streak of 2+ days that was just missed can be kept today with the Keep Streak product.
function Economy.checkStreak(d: { [string]: any })
	local day = Economy.today()
	local dl = d.daily
	if dl.broken and dl.broken.day ~= day then
		dl.broken = nil
	end
	if (dl.last or 0) > 0 and dl.last < day - 1 and (dl.streak or 0) >= 2 and not dl.broken then
		dl.broken = { streak = dl.streak, day = day }
	end
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

-- Race coin multiplier: mutation x 2x Coins pass x VIP x server coin boost x friends in the server.
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
	return m * Boosts.mult("coins") * Live.friendMult(player)
end

-- info: place, perfects, kind ("main"/"practice"/"gp"), hourly (the hourly Grand Prix), key (marble key
-- raced), owned (not a loaner), mut
function Economy.raceReward(player: Player, info: { [string]: any }): { [string]: any }?
	local d = Data.get(player)
	if not d then
		return nil
	end
	local P = Config.Payout
	local place = math.clamp(info.place, 1, #P.coins)
	local gpMult = info.hourly and Config.GrandPrix.hourlyMult or P.gpMult
	local kindMult = info.kind == "practice" and P.practiceMult or (info.kind == "gp" and gpMult or 1)
	local mult = Economy.coinMult(player, info.mut)
	local coins = math.floor((P.coins[place] + info.perfects * P.perfectCoins) * kindMult * mult + 0.5)
	local xp = math.floor((P.xp[place] + info.perfects * P.perfectXp) * (info.kind == "gp" and 1.5 or 1))
	local league = info.kind == "practice" and 1 or P.league[place] * (info.kind == "gp" and (info.hourly and 3 or 2) or 1)
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
	-- launch quests and badges
	Live.badge(player, "FirstRace")
	Live.quest(player, "race", 1)
	if place <= 3 then
		Live.quest(player, "podium", 1)
	end
	if place == 1 then
		Live.quest(player, "win", 1)
		if info.kind ~= "practice" then
			Live.badge(player, "FirstWin")
			if d.wins >= 10 then
				Live.badge(player, "Wins10")
			end
		end
	end
	if info.perfects > 0 then
		Live.quest(player, "perfect", info.perfects)
	end
	if info.kind == "gp" then
		Live.quest(player, "gp", 1)
	end
	if (tonumber(player:GetAttribute("Friends")) or 0) > 0 then
		Live.quest(player, "friend", 1)
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

-- Launch rewards (kit Live: codes, group, playtime, quests, invites): coins, packs, luck minutes.
function Economy.liveGrant(player: Player, d: { [string]: any }, reward: { [string]: any }, _source: string)
	if type(reward.coins) == "number" then
		d.coins += reward.coins
	end
	if type(reward.packs) == "table" then
		for key, n in pairs(reward.packs :: { [string]: number }) do
			if Config.PackByKey[key] then
				d.packs[key] = (d.packs[key] or 0) + n
			end
		end
	end
	if type(reward.luckMinutes) == "number" then
		d.luckUntil = math.max(os.time(), d.luckUntil or 0) + reward.luckMinutes * 60
	end
	Data.dirty(player)
end

-- Robux products -----------------------------------------------------------------------------------------

local function giveMarble(player: Player, d: { [string]: any }, id: string, verb: string)
	Economy.addMarble(player, d, id, nil)
	local def = Config.MarbleById[id]
	Shop.notify(player, string.format("%s %s!", verb, def and def.name or id), "purple")
	announce(player, id, nil, "got")
end

-- Today's deal marble for a deal product; yesterday's if that is what the shop showed just before midnight.
local function dealPick(player: Player, product: string): string?
	for _, deal in ipairs(Config.Deals) do
		if deal.product == product then
			local day = Economy.today()
			local want = Economy.want[player] and Economy.want[player][product]
			if want and want == Config.dayPick(deal.tier, day - 1, deal.salt) then
				return want
			end
			return Config.dayPick(deal.tier, day, deal.salt)
		end
	end
	return nil
end

function Economy.productGrants(): { [string]: (Player, { [string]: any }) -> boolean }
	local function trail(key: string): (Player, { [string]: any }) -> boolean
		return function(player, d)
			d.trails[key] = true
			d.trail = key
			Shop.notify(player, "New trail equipped!", "purple")
			return true
		end
	end
	local function coins(n: number): (Player, { [string]: any }) -> boolean
		return function(_player, d)
			d.coins += n
			return true
		end
	end
	local function deal(product: string): (Player, { [string]: any }) -> boolean
		return function(player, d)
			local id = dealPick(player, product)
			if id then
				giveMarble(player, d, id, "Daily deal:")
			end
			return true
		end
	end
	local function roundMod(mode: string): (Player, { [string]: any }) -> boolean
		return function(player, _d)
			local choice: { [string]: any } = { mode = mode }
			if mode == "custom" then
				local want = Economy.want[player] and Economy.want[player].CustomRound
				choice = type(want) == "table" and table.clone(want) or { mode = "chaos", theme = "Classic" }
			end
			local cb = Economy.onRoundMod
			if cb then
				cb(player, choice)
			end
			return true
		end
	end
	return {
		IntroEpic = function(player, d)
			local list = Config.MarblesByTier.Epic
			giveMarble(player, d, list[rng:NextInteger(1, #list)].id, "🎲 Random Epic:")
			return true
		end,
		IntroEpicFixed = function(player, d)
			giveMarble(player, d, Config.dayPick("Epic", Economy.today(), 9), "🎁 First-buy Epic:")
			return true
		end,
		StarterPack = function(player, d)
			d.coins += 3000
			Economy.addMarble(player, d, Config.StarterMarble, nil)
			d.trails.sparkle = true
			if d.trail == "" then
				d.trail = "sparkle"
			end
			d.starterBought = true
			Shop.notify(player, "🎒 Starter Pack: 3,000 coins + Comet + Sparkle Trail!", "green")
			return true
		end,
		CoinsS = coins(1500),
		CoinsM = coins(8000),
		CoinsL = coins(50000),
		CoinsXL = coins(125000),
		CoinsXXL = coins(300000),
		LuckBoost = function(player, d)
			d.luckUntil = math.max(os.time(), d.luckUntil or 0) + Config.LuckBoostSeconds
			Shop.notify(player, "🍀 Luck Boost active for 15 minutes!", "green")
			return true
		end,
		GalaxyPack = function(_player, d)
			d.packs.galaxy = (d.packs.galaxy or 0) + 1
			return true
		end,
		DealRare = deal("DealRare"),
		DealEpic = deal("DealEpic"),
		DealLegendary = deal("DealLegendary"),
		DealMythic = deal("DealMythic"),
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
		ChaosTrack = roundMod("chaos"),
		IceTrack = roundMod("ice"),
		CustomRound = roundMod("custom"),
		KeepStreak = function(player, d)
			local dl = d.daily
			local b = dl.broken
			if b then
				if dl.last == Economy.today() then
					dl.streak = b.streak + 1 -- already claimed today on a fresh streak: carry on from the old one
				else
					dl.last = Economy.today() - 1
					dl.streak = b.streak
				end
				dl.broken = nil
				Shop.notify(player, "🔥 Streak saved: " .. dl.streak .. " days!", "orange")
			else
				d.coins += 500
				Shop.notify(player, "🔥 Your streak was safe already: here's 500 coins!", "orange")
			end
			return true
		end,
		PumpkinMarble = function(player, d)
			giveMarble(player, d, "pumpkin", "🎃 Happy Halloween:")
			d.trails.spooky = true
			d.trail = "spooky"
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

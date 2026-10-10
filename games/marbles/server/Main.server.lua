--!strict
-- Marble Mayhem server: race cycle (pick -> countdown -> race -> results), warm-up heats for players who
-- join mid-race, bots so every race has at least 8 marbles, payouts, podium, daily league, the Grand Prix
-- server event, remotes for packs/upgrades/shine/daily/league, and Studio debug commands.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Fmt = require(Shared:WaitForChild("Fmt"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local Track = require(Shared:WaitForChild("Track"))

local Data = require(script.Parent:WaitForChild("Lib"):WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Lib"):WaitForChild("Shop"))
local Look = require(script.Parent:WaitForChild("Lib"):WaitForChild("Look"))
local Assets = require(script.Parent:WaitForChild("Lib"):WaitForChild("Assets"))
local Economy = require(script.Parent:WaitForChild("Lib"):WaitForChild("Economy"))
local Race = require(script.Parent:WaitForChild("Lib"):WaitForChild("Race"))
local League = require(script.Parent:WaitForChild("Lib"):WaitForChild("League"))
local Lobby = require(script.Parent:WaitForChild("Lib"):WaitForChild("Lobby"))
local Debug = require(script.Parent:WaitForChild("Lib"):WaitForChild("Debug"))

local RC = Config.Race
local rng = Random.new()

-- Remotes (created up front so clients can wait for them) ------------------------------------------------
local phaseRemote = Net.event("Phase")
local offerRemote = Net.event("PickOffer")
local pickRemote = Net.event("Pick")
local rewardRemote = Net.event("Reward")
local syncFunc = Net.func("Sync")
local openPackFunc = Net.func("OpenPack")
local shineFunc = Net.func("Shine")
local upgradeRemote = Net.event("Upgrade")
local tuneRemote = Net.event("TuneUp")
local dailyRemote = Net.event("ClaimDaily")
local leagueRemote = Net.event("ClaimLeague")
local trailRemote = Net.event("SetTrail")
local favRemote = Net.event("Favorite")
local gpRemote = Net.event("GP")
local teaseRemote = Net.event("Tease")
local offlineRemote = Net.event("Offline")
local podiumRemote = Net.event("Podium")
local announceRemote = Net.event("Announce")
Net.event("Open")
Net.event("Fx")

local function now(): number
	return workspace:GetServerTimeNow()
end

-- World, lighting, data, shop ------------------------------------------------------------------------------
Look.apply({
	preset = "A",
	clouds = { Cover = 0.55, Density = 0.45, Color = Color3.fromRGB(255, 255, 255) },
	atmosphere = { Density = 0.27, Haze = 0.9, Color = Color3.fromRGB(205, 230, 255), Decay = Color3.fromRGB(120, 170, 235) },
	cc = { Brightness = 0.09, Contrast = 0.1, Saturation = 0.22 },
})
Assets.init(Config.Meshes :: any)
Assets.preload()
task.spawn(function()
	local mp = Assets.get("Marble")
	if mp then
		local f = Instance.new("Folder")
		f.Name = "MarbleMeshes"
		mp.Name = "Sphere"
		mp.Parent = f
		f.Parent = ReplicatedStorage
	end
end)
Lobby.build()

Data.init({
	name = Config.STORE,
	defaults = Economy.defaults(),
	leaderstats = {
		{
			name = "🪙 Coins",
			get = function(d)
				return Fmt.num(d.coins)
			end,
		},
		{
			name = "🏆 Wins",
			get = function(d)
				return d.wins
			end,
		},
	},
})
Shop.init({ passes = Config.Passes :: any, products = Config.Products :: any, grants = Economy.productGrants() })
Shop.onPass(Economy.onPass)
League.init()
League.onBoard(function(rows)
	Lobby.setBoard(rows)
end)

-- Server state -----------------------------------------------------------------------------------------------
type Offer = { marbles: { { [string]: any } }, cards: { string }, slots: number, hint: string, raceNo: number }
type Pick = { key: string, cards: { string } }

local S = {
	phase = "idle",
	endsAt = 0,
	info = {} :: { [string]: any },
	raceNo = 0,
	gpAt = now() + Config.GrandPrix.firstAfter,
	forceGp = false,
	clipNext = false,
	mainRace = nil :: Race.RaceT?,
	practice = nil :: Race.RaceT?,
	forming = nil :: { players: { Player }, goAt: number }?,
	queue = {} :: { [Player]: boolean },
	offers = {} :: { [Player]: Offer },
	picks = {} :: { [Player]: Pick },
	joined = {} :: { [Player]: number },
	podium = {} :: { { [string]: any } },
	practiceSeed = rng:NextInteger(1, 1000000000),
	minRacers = RC.minRacers,
	nextTd = nil :: Track.TrackData?,
}
local teaseRaces: { [number]: boolean } = {}

local function gpInfo(): { [string]: any }
	local th = Config.gpTheme(os.time())
	return { key = th.key, name = th.name, marble = th.marble }
end

local function broadcastGp()
	gpRemote:FireAllClients(S.gpAt, gpInfo())
end

local function setPhase(phase: string, endsAt: number, info: { [string]: any })
	S.phase = phase
	S.endsAt = endsAt
	S.info = info
	phaseRemote:FireAllClients(phase, endsAt, info)
end

-- Picks ------------------------------------------------------------------------------------------------------

local function marbleOption(d: { [string]: any }?, key: string, loaner: boolean): { [string]: any }
	local id = string.match(key, "^loan:(.+)$") or (d and d.marbles[key] and d.marbles[key].id) or key
	local e = d and d.marbles[key]
	local spd, grip, wt, lvl = Economy.stats(if loaner then nil else d, if loaner then id else key)
	return { key = key, id = id, mut = e and e.mut or nil, lvl = lvl, spd = spd, grip = grip, wt = wt, loaner = loaner }
end

local function cardHint(td: Track.TrackData?): string
	if not td then
		return "boost"
	end
	local f = td.features
	if f.jumps >= 2 then
		return "bounce"
	elseif f.stairs >= 1 and f.turns >= 7 then
		return "sticky"
	elseif f.pads >= 1 then
		return "boost"
	end
	return "magnet"
end

local function makeOffer(player: Player, d: { [string]: any }): Offer
	local keys = {}
	for k in pairs(d.marbles) do
		table.insert(keys, k)
	end
	table.sort(keys, function(a, b)
		return Economy.power(d, a) > Economy.power(d, b)
	end)
	local chosen: { string } = {}
	local best = Economy.best(d)
	if best then
		table.insert(chosen, best)
	end
	-- two more: one strong, one random
	local pool = {}
	for _, k in ipairs(keys) do
		if k ~= best then
			table.insert(pool, k)
		end
	end
	if #pool > 0 then
		table.insert(chosen, table.remove(pool, 1) :: string)
	end
	if #pool > 0 then
		table.insert(chosen, table.remove(pool, rng:NextInteger(1, #pool)) :: string)
	end
	local opts = {}
	for _, k in ipairs(chosen) do
		table.insert(opts, marbleOption(d, k, false))
	end
	local loaners = table.clone(Config.LOANERS)
	while #opts < 3 and #loaners > 0 do
		local id = table.remove(loaners, rng:NextInteger(1, #loaners)) :: string
		if not d.marbles[id] then
			table.insert(opts, marbleOption(d, "loan:" .. id, true))
		end
	end
	local cards = {}
	for _, c in ipairs(Config.Cards) do
		table.insert(cards, c.key)
	end
	for i = #cards, 2, -1 do
		local j = rng:NextInteger(1, i)
		cards[i], cards[j] = cards[j], cards[i]
	end
	local hint = cardHint(S.nextTd)
	local dealt = { cards[1], cards[2], cards[3] }
	if not table.find(dealt, hint) then
		dealt[3] = hint
	end
	return { marbles = opts, cards = dealt, slots = Shop.owns(player, "PowerSlot") and 2 or 1, hint = hint, raceNo = S.raceNo }
end

local function sendOffer(player: Player)
	local d = Data.get(player)
	if not d then
		return
	end
	local offer = makeOffer(player, d)
	S.offers[player] = offer
	offerRemote:FireClient(player, offer, S.endsAt)
end

local function defaultPick(offer: Offer): Pick
	local cards = { offer.hint }
	if offer.slots >= 2 then
		for _, c in ipairs(offer.cards) do
			if c ~= offer.hint then
				table.insert(cards, c)
				break
			end
		end
	end
	return { key = offer.marbles[1].key, cards = cards }
end

pickRemote.OnServerEvent:Connect(function(player, key, cards)
	if not Net.allow(player, "pick", 0.25) or type(key) ~= "string" then
		return
	end
	local offer = S.offers[player]
	if not offer or S.phase ~= "pick" then
		return
	end
	local okKey = false
	for _, m in ipairs(offer.marbles) do
		if m.key == key then
			okKey = true
		end
	end
	if not okKey then
		return
	end
	local chosen = {}
	if type(cards) == "table" then
		for _, c in ipairs(cards :: { any }) do
			if type(c) == "string" and table.find(offer.cards, c) and not table.find(chosen, c) and #chosen < offer.slots then
				table.insert(chosen, c)
			end
		end
	end
	if #chosen == 0 then
		chosen = { offer.hint }
	end
	S.picks[player] = { key = key, cards = chosen }
	-- everyone locked in: start sooner
	local all = true
	for p in pairs(S.offers) do
		if p.Parent and not S.picks[p] then
			all = false
		end
	end
	if all and S.endsAt - now() > 1.6 then
		setPhase("pick", now() + 1.5, S.info)
	end
end)

-- Entrants ----------------------------------------------------------------------------------------------------

local function playerSpec(player: Player, d: { [string]: any }, pick: Pick?): Race.Spec?
	local key = pick and pick.key or Economy.best(d)
	if not key then
		return nil
	end
	local loaner = string.sub(key, 1, 5) == "loan:"
	if not loaner and not d.marbles[key] then
		key = Economy.best(d) or ""
		if key == "" then
			return nil
		end
	end
	local opt = marbleOption(d, key, loaner)
	local cards = pick and pick.cards or { Config.Cards[rng:NextInteger(1, #Config.Cards)].key }
	return {
		userId = player.UserId,
		name = player.DisplayName,
		bot = false,
		key = key,
		id = opt.id,
		mut = opt.mut,
		spd = opt.spd,
		grip = opt.grip,
		wt = opt.wt,
		cards = cards,
		skill = 0,
		trail = (d.trail ~= "" and d.trail) or nil,
		vip = Shop.owns(player, "VIP"),
		lvl = opt.lvl,
		owned = not loaner,
	}
end

local TIER_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

local function botSpecs(count: number, specs: { Race.Spec }, rookie: boolean, tease: boolean): { Race.Spec }
	local out: { Race.Spec } = {}
	local avg = 9
	local n = 0
	local sum = 0
	for _, sp in ipairs(specs) do
		if not sp.bot then
			sum += sp.spd + sp.grip + sp.wt
			n += 1
		end
	end
	if n > 0 then
		avg = sum / n
	end
	local tierAt = math.clamp(math.floor((avg - 9) / 2) + 1, 1, #TIER_ORDER)
	local names = table.clone(Config.BotNames)
	for k = 1, count do
		local ti = rookie and rng:NextInteger(1, 2) or math.clamp(tierAt + rng:NextInteger(-1, 1), 1, #TIER_ORDER)
		local list = Config.MarblesByTier[TIER_ORDER[ti]]
		local def = list[rng:NextInteger(1, #list)]
		local bonus = rookie and -1 or rng:NextNumber(0, math.max(0, avg - (def.spd + def.grip + def.wt))) * 0.5
		local name = table.remove(names, rng:NextInteger(1, #names)) or ("Bot" .. k)
		local mut: string? = nil
		if tease and k == 1 then
			mut = "cosmic"
		elseif not rookie and rng:NextNumber() < 0.06 then
			mut = "gold"
		end
		table.insert(out, {
			userId = 0,
			name = name,
			bot = true,
			key = def.id,
			id = def.id,
			mut = mut,
			spd = math.max(1, def.spd + bonus),
			grip = def.grip + math.max(0, bonus),
			wt = def.wt,
			cards = { Config.Cards[rng:NextInteger(1, #Config.Cards)].key },
			skill = rookie and rng:NextNumber(0.12, 0.3) or rng:NextNumber(0.4, 0.8),
			trail = nil,
			vip = false,
			lvl = 1,
			owned = false,
		})
	end
	return out
end

-- Results ------------------------------------------------------------------------------------------------------

local function handleResults(race: Race.RaceT)
	local res = race.results or {}
	local gp = race.gp
	local theme = gpInfo()
	for _, r in ipairs(res) do
		if not r.bot then
			local player = Players:GetPlayerByUserId(r.userId)
			local d = player and Data.get(player)
			if player and d then
				local info = Economy.raceReward(player, { place = r.place, perfects = r.perfects, kind = race.kind, key = r.key, owned = r.owned, mut = r.mut })
				if info then
					-- Grand Prix prize: the week's limited marble
					if gp and (r.place == 1 or (r.place <= 3 and rng:NextNumber() < Config.GrandPrix.runnerUpChance)) then
						Economy.addMarble(player, d, theme.marble, nil)
						info.gpMarble = theme.marble
						if r.place == 1 then
							d.gpWins += 1
						end
						local def = Config.MarbleById[theme.marble]
						announceRemote:FireAllClients(string.format("🏁 %s won the %s GP marble: %s!", player.DisplayName, theme.name, def and def.name or "?"), "Legendary", nil)
					end
					rewardRemote:FireClient(player, race.id, info)
				end
				local ftue = d.ftue :: any
				if teaseRaces[race.id] and not ftue.teased then
					ftue.teased = true
					teaseRemote:FireClient(player, "mutation")
					Data.dirty(player)
				end
			end
		end
	end
	teaseRaces[race.id] = nil
	if race.kind ~= "practice" then
		local top: { { [string]: any } } = {}
		for i = 1, math.min(3, #res) do
			local r = res[i]
			local row: { [string]: any } = { name = r.name, id = r.id, mut = r.mut, bot = r.bot, place = r.place }
			table.insert(top, row)
		end
		S.podium = top
		Lobby.setPodium(top)
		podiumRemote:FireAllClients(top)
		League.bump()
	end
end

local function waitDone(race: Race.RaceT)
	while not race.done do
		task.wait(0.2)
	end
end

-- Warm-up heats (practice track) ------------------------------------------------------------------------------

local function timeToMainGo(): number
	local t = now()
	if S.phase == "pick" then
		return S.endsAt - t + RC.countdown
	elseif S.phase == "results" then
		return S.endsAt - t + RC.pickTime + RC.countdown
	elseif S.phase == "race" then
		return 40 + RC.resultsTime + RC.pickTime
	end
	return RC.firstPickTime + RC.countdown
end

local startPractice: () -> ()

local function requestPractice(player: Player)
	if Race.isRacing(player.UserId, "practice") then
		return
	end
	local forming = S.forming
	if forming then
		if not table.find(forming.players, player) then
			table.insert(forming.players, player)
		end
		return
	end
	if S.practice and not S.practice.done then
		S.queue[player] = true
		return
	end
	S.forming = { players = { player }, goAt = now() + RC.practiceForm }
	task.delay(RC.practiceForm, startPractice)
end

startPractice = function()
	local forming = S.forming
	S.forming = nil
	if not forming then
		return
	end
	local specs: { Race.Spec } = {}
	local rookie = false
	for _, p in ipairs(forming.players) do
		local d = Data.get(p)
		if p.Parent and d and not Race.isRacing(p.UserId) then
			local sp = playerSpec(p, d, nil)
			if sp then
				if d.races == 0 then
					rookie = true
					sp.cards = { "boost" }
				end
				table.insert(specs, sp)
			end
		end
	end
	if #specs == 0 then
		return
	end
	for _, b in ipairs(botSpecs(math.max(0, RC.practiceRacers - #specs), specs, rookie, false)) do
		table.insert(specs, b)
	end
	local race = Race.create("practice", S.practiceSeed, "Classic", specs, RC.countdown, { rookie = rookie })
	S.practice = race
	race.onDone = function(r)
		handleResults(r)
		task.wait(6)
		Race.remove(r)
		if S.practice == r then
			S.practice = nil
		end
		-- anyone who queued up while it ran gets the next heat if the main race is still far off
		local waiting: { Player } = {}
		for p in pairs(S.queue) do
			table.insert(waiting, p)
		end
		S.queue = {}
		if timeToMainGo() > 16 then
			for _, p in ipairs(waiting) do
				if p.Parent then
					requestPractice(p)
				end
			end
		end
	end
end

-- Join flow: race within 10 s of spawning.
local function joinFlow(player: Player)
	if not player.Parent then
		return
	end
	local t = now()
	if S.phase == "pick" and S.endsAt - t >= 2.5 then
		sendOffer(player)
	elseif timeToMainGo() > 12 then
		requestPractice(player)
	end
end

Data.onLoaded(function(player, d)
	S.joined[player] = os.clock()
	if next(d.marbles) == nil then
		Economy.addMarble(player, d, Config.STARTER, nil)
	end
	Economy.leagueFresh(d)
	local coins, mins = Economy.offline(d)
	Data.dirty(player)
	if coins > 0 then
		task.delay(4, function()
			if player.Parent then
				offlineRemote:FireClient(player, coins, mins)
			end
		end)
	end
	task.delay(1, joinFlow, player)
end)
Data.onLeaving(function(player, d)
	d.lastOnline = os.time()
end)
Players.PlayerRemoving:Connect(function(p)
	S.joined[p] = nil
	S.offers[p] = nil
	S.picks[p] = nil
	S.queue[p] = nil
end)

-- Main race cycle -------------------------------------------------------------------------------------------------

local function mainLoop()
	local fresh = true
	while true do
		if #Players:GetPlayers() == 0 then
			setPhase("idle", 0, {})
			repeat
				task.wait(0.5)
			until #Players:GetPlayers() > 0
			fresh = true
			task.wait(1)
		end
		-- PICK
		S.raceNo += 1
		local t = now()
		local gp = S.forceGp or t >= S.gpAt
		if gp then
			S.forceGp = false
			S.gpAt = t + Config.GrandPrix.interval
			broadcastGp()
		end
		local kind = gp and "gp" or "main"
		local theme = gp and gpInfo().key or "Classic"
		local seed = rng:NextInteger(1, 1000000000)
		local td = Track.generate(seed, (Config.Tracks :: any)[kind])
		S.nextTd = td
		S.offers, S.picks = {}, {}
		local pickT = fresh and RC.firstPickTime or RC.pickTime
		fresh = false
		setPhase("pick", t + pickT, { kind = kind, seed = seed, theme = theme, gp = gp, features = Track.describe(td), raceNo = S.raceNo })
		if gp then
			local th = gpInfo()
			announceRemote:FireAllClients("🏁 GRAND PRIX: " .. th.name .. "! 2x coins & points!", "GP", nil)
		end
		for _, p in ipairs(Players:GetPlayers()) do
			if Data.get(p) then
				sendOffer(p)
			end
		end
		while now() < S.endsAt do
			task.wait(0.1)
		end
		-- COUNTDOWN + RACE
		local specs: { Race.Spec } = {}
		local tease = false
		for _, p in ipairs(Players:GetPlayers()) do
			local d = Data.get(p)
			if d then
				local offer = S.offers[p]
				local pick = S.picks[p] or (offer and defaultPick(offer)) or nil
				local sp = playerSpec(p, d, pick)
				if sp and #specs < RC.maxRacers then
					table.insert(specs, sp)
					local joinedAt = S.joined[p] or os.clock()
					if not d.ftue.teased and os.clock() - joinedAt > 100 then
						tease = true
					end
				end
			end
		end
		local nBots = math.max(0, S.minRacers - #specs)
		if tease and nBots == 0 and #specs < RC.maxRacers then
			nBots = 1
		end
		for _, b in ipairs(botSpecs(nBots, specs, false, tease)) do
			table.insert(specs, b)
		end
		local race = Race.create(kind, seed, theme, specs, RC.countdown, { gp = gp, clip = S.clipNext, td = td })
		S.clipNext = false
		if tease then
			teaseRaces[race.id] = true
		end
		S.mainRace = race
		setPhase("race", race.goTime, { raceId = race.id, kind = kind, gp = gp })
		waitDone(race)
		-- RESULTS
		handleResults(race)
		setPhase("results", now() + RC.resultsTime, { raceId = race.id })
		task.wait(RC.resultsTime)
		Race.remove(race)
		S.mainRace = nil
	end
end
task.spawn(mainLoop)

-- Grand Prix countdown broadcast + late mutation tease
task.spawn(function()
	task.wait(2)
	broadcastGp()
	while true do
		task.wait(5)
		for p, joinedAt in pairs(S.joined) do
			local d = Data.get(p)
			local ftue = d and d.ftue :: any
			if d and ftue and not ftue.teased and os.clock() - joinedAt > 200 and not Race.isRacing(p.UserId) then
				ftue.teased = true
				teaseRemote:FireClient(p, "mutation")
				Data.dirty(p)
			end
		end
	end
end)

Economy.onStartGP = function(player: Player)
	S.forceGp = true
	S.gpAt = now()
	broadcastGp()
	announceRemote:FireAllClients("🏁 " .. player.DisplayName .. " started a GRAND PRIX! Next race!", "GP", nil)
end

-- Client requests -----------------------------------------------------------------------------------------------

syncFunc.OnServerInvoke = function(player: Player)
	return {
		phase = S.phase,
		endsAt = S.endsAt,
		info = S.info,
		races = Race.descriptors(),
		practiceSeed = S.practiceSeed,
		gpAt = S.gpAt,
		gp = gpInfo(),
		board = League.board(),
		podium = S.podium,
		offer = S.offers[player],
	}
end

openPackFunc.OnServerInvoke = function(player, packKey, count)
	if type(packKey) ~= "string" or not Net.allow(player, "pack", 0.6) then
		return { ok = false, err = "Slow down!" }
	end
	return Economy.openPack(player, packKey, type(count) == "number" and count or 1)
end

shineFunc.OnServerInvoke = function(player, key)
	if type(key) ~= "string" or not Net.allow(player, "shine", 0.8) then
		return { ok = false, err = "Slow down!" }
	end
	return Economy.shine(player, key)
end

upgradeRemote.OnServerEvent:Connect(function(player, key, stat)
	if type(key) == "string" and type(stat) == "string" and Net.allow(player, "upgrade", 0.08) then
		Economy.upgrade(player, key, stat)
	end
end)

tuneRemote.OnServerEvent:Connect(function(player, key)
	if type(key) == "string" and Net.allow(player, "tune", 0.25) then
		Economy.tuneUp(player, key)
	end
end)

dailyRemote.OnServerEvent:Connect(function(player)
	if Net.allow(player, "daily", 1) then
		Economy.claimDaily(player)
	end
end)

leagueRemote.OnServerEvent:Connect(function(player, tier)
	if type(tier) == "number" and Net.allow(player, "league", 0.5) then
		Economy.claimLeague(player, tier)
	end
end)

trailRemote.OnServerEvent:Connect(function(player, key)
	local d = Data.get(player)
	if d and type(key) == "string" and Net.allow(player, "trail", 0.3) and (key == "" or d.trails[key]) then
		d.trail = key
		Data.dirty(player)
	end
end)

favRemote.OnServerEvent:Connect(function(player, key)
	local d = Data.get(player)
	if d and type(key) == "string" and Net.allow(player, "fav", 0.3) and d.marbles[key] then
		d.favorite = key
		Data.dirty(player)
	end
end)

-- Debug commands (Studio only) ------------------------------------------------------------------------------------

local function findPlayer(args: { string }): Player?
	local list = Players:GetPlayers()
	if args[1] then
		for _, p in ipairs(list) do
			if string.lower(p.Name) == string.lower(args[1]) or string.lower(p.DisplayName) == string.lower(args[1]) then
				table.remove(args, 1)
				return p
			end
		end
	end
	return list[1]
end

local function resetData(player: Player)
	local d = Data.get(player)
	if not d then
		return
	end
	for k in pairs(d) do
		if k ~= "passes" and k ~= "receipts" then
			d[k] = nil
		end
	end
	for k, v in pairs(Economy.defaults()) do
		d[k] = Data.deepCopy(v)
	end
	d.firstJoin = os.time()
	Economy.addMarble(player, d, Config.STARTER, nil)
	Data.dirty(player)
end

Debug.init({
	help = function()
		return "give [player] [coins|xp|league] <n>, marble [player] <id> [mut], pack [player] <pack> [n], event|gp, clip, skip, state, reset [player], practice [player], level [player] <lvl>, daily [player], offline [player] <hours>, ftue [player], bots <n>, luck [player]"
	end,
	give = function(args)
		local p = findPlayer(args)
		local d = p and Data.get(p)
		if not p or not d then
			return "no player"
		end
		local what = "coins"
		if args[1] and not tonumber(args[1]) then
			what = string.lower(table.remove(args, 1) :: string)
		end
		local n = tonumber(args[1]) or 1000
		if what == "xp" then
			local key = Economy.best(d)
			if key then
				Economy.addXp(d, key, n)
			end
		elseif what == "league" then
			Economy.leagueFresh(d)
			d.league.pts += n
			League.bump()
		else
			d.coins += n
		end
		Data.dirty(p)
		return string.format("gave %s %s %s", p.Name, Fmt.num(n), what)
	end,
	marble = function(args)
		local p = findPlayer(args)
		local d = p and Data.get(p)
		local id = args[1]
		if not p or not d or not id or not Config.MarbleById[id] then
			return "usage: marble [player] <id> [gold|rainbow|cosmic]"
		end
		local mut = args[2]
		if mut and not Config.MutationByKey[mut] then
			mut = nil
		end
		local key = Economy.addMarble(p, d, id, mut)
		return "added " .. key
	end,
	pack = function(args)
		local p = findPlayer(args)
		local d = p and Data.get(p)
		local key = args[1] or "basic"
		if not p or not d or not Config.PackByKey[key] then
			return "usage: pack [player] <basic|shiny|mega|galaxy|welcome> [n]"
		end
		local n = tonumber(args[2]) or 1
		d.packs[key] = (d.packs[key] or 0) + n
		Data.dirty(p)
		return string.format("gave %d %s pack(s)", n, key)
	end,
	event = function()
		S.forceGp = true
		S.gpAt = now()
		broadcastGp()
		announceRemote:FireAllClients("🏁 GRAND PRIX next race! (debug)", "GP", nil)
		return "Grand Prix forced for the next race"
	end,
	gp = function()
		S.forceGp = true
		S.gpAt = now()
		broadcastGp()
		return "Grand Prix forced for the next race"
	end,
	clip = function()
		S.clipNext = true
		Race.setClip(true)
		return "clip mode: photo finish + huge jumps in the current/next race"
	end,
	skip = function()
		if S.phase == "pick" or S.phase == "results" then
			setPhase(S.phase, now(), S.info)
			return "skipped " .. S.phase
		end
		return "nothing to skip in phase " .. S.phase
	end,
	state = function()
		local main = S.mainRace
		local practice = S.practice
		local ps = {}
		for _, p in ipairs(Players:GetPlayers()) do
			local d = Data.get(p)
			if d then
				local n = 0
				for _ in pairs(d.marbles) do
					n += 1
				end
				table.insert(ps, string.format("%s: %s coins, %d marbles, %d races, %d wins, league %d", p.Name, Fmt.num(d.coins), n, d.races, d.wins, d.league.pts))
			end
		end
		return string.format(
			"phase=%s ends in %.1fs raceNo=%d main=%s practice=%s gpIn=%ds | %s",
			S.phase,
			math.max(0, S.endsAt - now()),
			S.raceNo,
			main and string.format("#%d %s t=%.1f (%d marbles)", main.id, main.kind, main.sim.t, #main.sim.entrants) or "none",
			practice and string.format("#%d t=%.1f", practice.id, practice.sim.t) or "none",
			math.floor(math.max(0, S.gpAt - now())),
			table.concat(ps, " | ")
		)
	end,
	reset = function(args)
		local p = findPlayer(args)
		if not p then
			return "no player"
		end
		resetData(p)
		return "reset " .. p.Name
	end,
	practice = function(args)
		local p = findPlayer(args)
		if not p then
			return "no player"
		end
		requestPractice(p)
		return "warm-up heat requested for " .. p.Name
	end,
	level = function(args)
		local p = findPlayer(args)
		local d = p and Data.get(p)
		local key = d and Economy.best(d)
		if not p or not d or not key then
			return "no player"
		end
		local target = tonumber(args[1]) or 10
		local e = d.marbles[key]
		while e.lvl < math.min(target, Config.Level.max) do
			Economy.addXp(d, key, Config.xpNeed(e.lvl))
		end
		Data.dirty(p)
		return string.format("%s is level %d (%d points)", key, e.lvl, e.pts)
	end,
	daily = function(args)
		local p = findPlayer(args)
		local d = p and Data.get(p)
		if not p or not d then
			return "no player"
		end
		d.daily.last = Economy.today() - 1
		Data.dirty(p)
		return "daily reward claimable"
	end,
	offline = function(args)
		local p = findPlayer(args)
		local d = p and Data.get(p)
		if not p or not d then
			return "no player"
		end
		local hours = tonumber(args[1]) or 2
		d.lastOnline = os.time() - hours * 3600
		local coins, mins = Economy.offline(d)
		Data.dirty(p)
		offlineRemote:FireClient(p, coins, mins)
		return string.format("offline %d min -> %d coins", mins, coins)
	end,
	ftue = function(args)
		local p = findPlayer(args)
		local d = p and Data.get(p)
		if not p or not d then
			return "no player"
		end
		d.ftue = { welcome = false, shine = false, teased = false, raced = false }
		d.packs.welcome = nil
		S.joined[p] = os.clock()
		Data.dirty(p)
		return "FTUE flags reset"
	end,
	tease = function(args)
		local p = findPlayer(args)
		if not p then
			return "no player"
		end
		teaseRemote:FireClient(p, "mutation")
		return "tease sent"
	end,
	bots = function(args)
		S.minRacers = math.clamp(tonumber(args[1]) or RC.minRacers, 1, RC.maxRacers)
		return "min racers = " .. S.minRacers
	end,
	luck = function(args)
		local p = findPlayer(args)
		local d = p and Data.get(p)
		if not p or not d then
			return "no player"
		end
		d.luckUntil = os.time() + Config.LuckBoostSeconds
		Data.dirty(p)
		return "luck boost on"
	end,
})

local _ = Tiers

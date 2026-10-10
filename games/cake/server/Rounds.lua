-- The round loop (~3 min): Lobby -> Theme reveal -> Build -> Vote (turntable showcase) -> Results (podium +
-- giant winner cake). State lives in attributes on ReplicatedStorage.CakeState so late joiners see it;
-- one-off moments go out on the "Round" remote. Every ~10 minutes a Celebrity Judge round pays 2x.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CakeBuilder = require(Shared:WaitForChild("CakeBuilder"))
local Net = require(Shared:WaitForChild("Net"))
local Data = require(script.Parent:WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local Stations = require(script.Parent:WaitForChild("Stations"))
local Bots = require(script.Parent:WaitForChild("Bots"))
local Judging = require(script.Parent:WaitForChild("Judging"))
local Progress = require(script.Parent:WaitForChild("Progress"))
local Plaza = require(script.Parent:WaitForChild("Plaza"))

type Station = Stations.Station
type Cake = CakeBuilder.Cake
type Entry = {
	st: Station,
	owner: Player?,
	ownerId: number,
	name: string,
	isBot: boolean,
	cake: Cake,
	votes: { [Player]: number },
	judges: { number },
	celeb: number?,
	score: number,
	golden: boolean,
}

local Rounds = {}

local R = Config.Round
local roundRemote = Net.event("Round")
local rewardRemote = Net.event("Reward")
local announce = Net.event("Announce")
local voteRemote = Net.event("Vote")

local state: Folder
local built: Plaza.Built
local phase = "Waiting"
local phaseEnds = 0
local skip = false
local round = 0
local themeKey = "Birthday"
local celebrity = false
local eventAt = 0
local forceEvent = false
local themeQueue: { { key: string, by: string } } = {}
local recentThemes: { string } = {}
local graceUsed = 0
local roundToken = 0
local current: Entry? = nil
local voteCoins: { [Player]: number } = {}
local minEntrants = R.minEntrants
local lastWinner: Entry? = nil
local rng = Random.new()

local function now(): number
	return workspace:GetServerTimeNow()
end

local function setPhase(p: string, dur: number)
	phase = p
	phaseEnds = now() + dur
	skip = false
	state:SetAttribute("Phase", p)
	state:SetAttribute("PhaseEnds", phaseEnds)
end

local function setEnds(t: number)
	phaseEnds = t
	state:SetAttribute("PhaseEnds", phaseEnds)
end

local function waitUntil(t: number)
	while not skip and now() < t do
		task.wait(0.2)
	end
end

local function humans(): { Player }
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if Data.get(p) then
			table.insert(out, p)
		end
	end
	return out
end

-- Stage look for Celebrity rounds: gold glow and spotlights.
local function stageMood(gold: boolean)
	for _, p in ipairs(built.glow) do
		if p.Name == "StageGlow" then
			p.Color = if gold then Config.Palette.gold else Color3.fromRGB(255, 120, 190)
		end
	end
	for _, sl in ipairs(built.spots) do
		sl.Color = if gold then Color3.fromRGB(255, 220, 140) else Color3.fromRGB(255, 240, 220)
		sl.Brightness = if gold then 3.5 else 2.5
	end
	Bots.celebrity(gold)
end

local function chooseTheme(): (string, string?)
	if celebrity then
		local specials = {}
		for i = Config.RegularThemes + 1, #Config.Themes do
			table.insert(specials, Config.Themes[i].key)
		end
		return specials[rng:NextInteger(1, #specials)], nil
	end
	local picked = table.remove(themeQueue, 1)
	if picked then
		return picked.key, picked.by
	end
	local options = {}
	for i = 1, Config.RegularThemes do
		local k = Config.Themes[i].key
		if not table.find(recentThemes, k) then
			table.insert(options, k)
		end
	end
	return options[rng:NextInteger(1, #options)], nil
end

local function scoreOf(e: Entry): number
	local sum, w, voters = 0, 0, 0
	local hw = if e.isBot then 0.5 else 1
	for p, v in pairs(e.votes) do
		if p.Parent then
			sum += v * hw
			w += hw
			voters += 1
		end
	end
	local jw = if voters < 3 then 1 elseif voters < 6 then 0.6 else 0.35
	for _, v in ipairs(e.judges) do
		sum += v * jw
		w += jw
	end
	local c = e.celeb
	if c then
		sum += c * jw * 2
		w += jw * 2
	end
	if w <= 0 then
		return 1
	end
	return math.floor(sum / w * 10 + 0.5) / 10
end

local function giantPayload(e: Entry): { [string]: any }
	return { cake = e.cake, name = e.name, ownerId = e.ownerId, golden = e.golden, score = e.score, theme = themeKey }
end

-- One round --------------------------------------------------------------------------------------------
local function playRound()
	round += 1
	roundToken += 1
	local token = roundToken
	local function alive(): boolean
		return roundToken == token
	end

	celebrity = forceEvent or now() >= eventAt - 5
	if celebrity then
		forceEvent = false
		eventAt = now() + R.eventEvery
	end
	state:SetAttribute("EventAt", eventAt)
	local by
	themeKey, by = chooseTheme()
	table.insert(recentThemes, themeKey)
	if #recentThemes > 4 then
		table.remove(recentThemes, 1)
	end
	state:SetAttribute("Theme", themeKey)
	state:SetAttribute("Celebrity", celebrity)
	state:SetAttribute("Round", round)
	state:SetAttribute("ShowIndex", 0)
	state:SetAttribute("Overtime", "")

	-- fresh cakes and NPC bakers
	graceUsed = 0
	voteCoins = {}
	for _, st in ipairs(Stations.list) do
		if st.owner then
			Stations.reset(st)
		end
	end
	local easy = false
	for _, p in ipairs(humans()) do
		local d = Data.get(p)
		if d and (d.rounds or 0) == 0 then
			easy = true
		end
	end
	local botStations = Bots.fill(minEntrants, easy)
	stageMood(celebrity)

	setPhase("Theme", R.theme)
	roundRemote:FireAllClients("theme", { theme = themeKey, celebrity = celebrity, by = by })
	if celebrity then
		announce:FireAllClients("🌟 CELEBRITY JUDGE ROUND! 2x coins and XP!", "gold", true)
	elseif by then
		announce:FireAllClients("🎡 " .. by .. " picked the theme: " .. Config.ThemeByKey[themeKey].name .. "!", "pink", false)
	end
	waitUntil(phaseEnds)
	if not alive() then
		return
	end

	-- BUILD -------------------------------------------------------------------------------------------
	local buildTime = R.build
	local overtimeBy: string? = nil
	for _, p in ipairs(humans()) do
		if Shop.owns(p, "ExtraTime") then
			overtimeBy = p.DisplayName
			break
		end
	end
	if overtimeBy then
		buildTime += R.overtime
		state:SetAttribute("Overtime", overtimeBy)
	end
	Stations.buildOpen = true
	setPhase("Build", buildTime)
	if overtimeBy then
		announce:FireAllClients("⏰ +" .. R.overtime .. "s build time for everyone, thanks to " .. overtimeBy .. "!", "green", false)
	end
	for _, st in ipairs(botStations) do
		task.spawn(Bots.decorate, st, themeKey, alive, function()
			return phaseEnds
		end)
	end
	local start = now()
	while not skip and now() < phaseEnds and alive() do
		task.wait(0.25)
		if now() - start > R.earlyEndMin and phaseEnds - now() > 5 then
			local total, ready = 0, 0
			for _, st in ipairs(Stations.list) do
				if st.owner and (st.owner :: Player).Parent then
					total += 1
					if st.ready then
						ready += 1
					end
				end
			end
			if total > 0 and ready == total then
				setEnds(now() + 4)
				announce:FireAllClients("✅ Everyone's done! Judging starts...", "green", false)
			end
		end
	end
	Stations.buildOpen = false
	if not alive() then
		return
	end
	-- NPC bakers finish their plan instantly
	for _, st in ipairs(botStations) do
		if st.botName then
			st.edits = math.max(st.edits, 1)
		end
	end
	task.wait(0.6)

	-- VOTE --------------------------------------------------------------------------------------------
	local entries: { Entry } = {}
	for _, st in ipairs(Stations.list) do
		local owner = st.owner
		if (owner and owner.Parent and st.edits > 0) or (st.botName and not owner) then
			table.insert(entries, {
				st = st,
				owner = owner,
				ownerId = if owner then owner.UserId else 0,
				name = if owner then owner.DisplayName else (st.botName :: string),
				isBot = owner == nil,
				cake = CakeBuilder.copy(st.cake),
				votes = {},
				judges = {},
				celeb = nil,
				score = 0,
				golden = st.golden,
			})
		end
	end
	if #entries == 0 then
		announce:FireAllClients("Nobody baked this round... 🥲", "orange", false)
		return
	end
	rng:Shuffle(entries)
	local slot = math.clamp(70 / #entries, R.showMin, R.showMax)
	setPhase("Vote", (slot + 0.2) * #entries + 0.5)
	state:SetAttribute("ShowTotal", #entries)
	for i, e in ipairs(entries) do
		if not alive() then
			return
		end
		local owner = e.owner
		if owner == nil or owner.Parent then
			current = e
			local ends = now() + slot
			state:SetAttribute("ShowIndex", i)
			state:SetAttribute("ShowOwner", e.name)
			state:SetAttribute("ShowOwnerId", e.ownerId)
			roundRemote:FireAllClients("show", { idx = i, total = #entries, name = e.name, ownerId = e.ownerId, isBot = e.isBot, cake = e.cake, ends = ends, slot = slot, golden = e.golden })
			local judgeRng = Random.new(round * 1000 + i)
			local js, c = Judging.votes(e.cake, themeKey, judgeRng, celebrity)
			e.judges = js
			e.celeb = c
			waitUntil(ends - slot * (1 - R.judgeAt))
			roundRemote:FireAllClients("judges", { scores = e.judges, celeb = e.celeb })
			waitUntil(ends)
			e.score = scoreOf(e)
			roundRemote:FireAllClients("score", { idx = i, score = e.score, name = e.name, ownerId = e.ownerId })
			current = nil
			task.wait(0.2)
		end
	end
	current = nil
	if not alive() then
		return
	end

	-- RESULTS -----------------------------------------------------------------------------------------
	local ranked: { Entry } = {}
	for _, e in ipairs(entries) do
		local owner = e.owner
		if owner == nil or owner.Parent then
			table.insert(ranked, e)
		end
	end
	table.sort(ranked, function(a: Entry, b: Entry)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return #a.cake.toppings > #b.cake.toppings
	end)
	if #ranked == 0 then
		return
	end
	setPhase("Results", R.results + R.giant)
	local podium = {}
	for place = 1, math.min(3, #ranked) do
		local e = ranked[place]
		local top = Config.World.podium[place]
		table.insert(podium, { name = e.name, score = e.score, ownerId = e.ownerId, isBot = e.isBot })
		local owner = e.owner
		if owner then
			local char = owner.Character
			if char then
				char:PivotTo(CFrame.lookAt(top + Vector3.new(0, 3.2, 0), top + Vector3.new(0, 3.2, 10)))
			end
		else
			Bots.toPodium(e.st, top)
		end
	end
	roundRemote:FireAllClients("results", { podium = podium, theme = themeKey, celebrity = celebrity, count = #ranked })

	-- rewards
	local mult = if celebrity then Config.Rewards.celebrityMult else 1
	for place, e in ipairs(ranked) do
		local owner = e.owner
		if owner and owner.Parent then
			local d = Data.get(owner)
			if d then
				local rw = Config.Rewards
				local coins = (rw.participate + rw.perStar * e.score + (rw.place[place] or 0)) * mult * Progress.coinMult(owner)
				local xp = (rw.xpBase + rw.xpPerStar * e.score + (rw.xpPlace[place] or 0)) * mult * Progress.xpMult(owner)
				Progress.addCoins(owner, d, coins)
				d.rounds = (d.rounds or 0) + 1
				if place <= 3 then
					d.top3 = (d.top3 or 0) + 1
				end
				if place == 1 and #ranked >= 2 then
					d.wins = (d.wins or 0) + 1
				end
				d.bestScore = math.max(d.bestScore or 0, e.score)
				local bonusBox = celebrity and place == 1
				if bonusBox then
					d.boxes = (d.boxes or 0) + 1
				end
				local levels = Progress.addXP(owner, d, xp)
				rewardRemote:FireClient(owner, {
					kind = "round",
					place = place,
					of = #ranked,
					score = e.score,
					coins = math.floor(coins),
					xp = math.floor(xp),
					levels = levels,
					celebrity = celebrity,
					box = bonusBox,
				})
			end
		end
	end
	local winner = ranked[1]
	lastWinner = winner
	announce:FireAllClients(string.format("🏆 %s won %s %s with ⭐ %.1f!", winner.name, Config.ThemeByKey[themeKey].name, Config.ThemeByKey[themeKey].glyph, winner.score), "gold", true)
	task.wait(R.results)
	if not alive() then
		return
	end
	-- the clip moment: the winning cake grows giant on the stage with fireworks
	roundRemote:FireAllClients("giant", giantPayload(winner))
	waitUntil(phaseEnds)
	Bots.goHome()
end

-- Loop and hooks ---------------------------------------------------------------------------------------
function Rounds.run()
	eventAt = now() + R.eventEvery
	state:SetAttribute("EventAt", eventAt)
	local first = true
	while true do
		if #Players:GetPlayers() == 0 then
			setPhase("Waiting", 0)
			repeat
				task.wait(0.5)
			until #Players:GetPlayers() > 0
			first = true
		end
		setPhase("Lobby", if first then R.firstWait else R.intermission)
		first = false
		waitUntil(phaseEnds)
		if #Players:GetPlayers() > 0 then
			local ok, err = pcall(playRound)
			if not ok then
				warn("[Rounds] round failed:", err)
				Stations.buildOpen = false
				current = nil
			end
			Bots.goHome()
		end
	end
end

function Rounds.init(b: Plaza.Built)
	built = b
	local s = ReplicatedStorage:FindFirstChild("CakeState")
	if not s then
		local f = Instance.new("Folder")
		f.Name = "CakeState"
		f.Parent = ReplicatedStorage
		s = f
	end
	state = s :: Folder
	state:SetAttribute("Phase", "Waiting")
	state:SetAttribute("PhaseEnds", 0)
	state:SetAttribute("Theme", "")
	state:SetAttribute("Celebrity", false)
	state:SetAttribute("Round", 0)
	state:SetAttribute("EventAt", 0)
	state:SetAttribute("ShowIndex", 0)
	state:SetAttribute("ShowTotal", 0)
	state:SetAttribute("ShowOwner", "")
	state:SetAttribute("ShowOwnerId", 0)
	state:SetAttribute("Overtime", "")

	voteRemote.OnServerEvent:Connect(function(player: Player, stars: any, idx: any)
		local e = current
		if phase ~= "Vote" or not e or type(stars) ~= "number" or stars ~= stars then
			return
		end
		-- a late vote for the previous cake must not land on the one now showing
		if idx ~= state:GetAttribute("ShowIndex") then
			return
		end
		if e.owner == player or not Net.allow(player, "vote", 0.2) then
			return
		end
		local v = math.clamp(math.floor(stars), 1, 5)
		local firstVote = e.votes[player] == nil
		e.votes[player] = v
		if firstVote then
			local d = Data.get(player)
			local got = voteCoins[player] or 0
			if d and got < Config.Rewards.voteCap * Config.Rewards.vote then
				local c = Config.Rewards.vote
				voteCoins[player] = got + c
				Progress.addCoins(player, d, c)
				d.votes = (d.votes or 0) + 1
				rewardRemote:FireClient(player, { kind = "vote", coins = c })
			end
		end
	end)

	-- a late joiner gets a short grace so they can still make a cake
	Stations.onLateJoin = function(player: Player, _st: Station)
		if phase ~= "Build" then
			return
		end
		local remaining = phaseEnds - now()
		if remaining < R.grace and graceUsed < R.graceCap then
			local add = math.min(R.grace - remaining, R.graceCap - graceUsed)
			graceUsed += add
			setEnds(phaseEnds + add)
			announce:FireAllClients(string.format("⏳ +%ds so %s can bake too!", math.floor(add), player.DisplayName), "sky", false)
		end
	end
end

-- Theme pick (paid product) and debug hooks ------------------------------------------------------------
function Rounds.queueTheme(key: string, by: string): boolean
	local idx = nil
	for i = 1, Config.RegularThemes do
		if Config.Themes[i].key == key then
			idx = i
		end
	end
	if not idx then
		return false
	end
	table.insert(themeQueue, { key = key, by = by })
	return true
end

function Rounds.phase(): string
	return phase
end

function Rounds.skip()
	skip = true
end

function Rounds.setRemaining(sec: number)
	setEnds(now() + sec)
end

function Rounds.forceEvent()
	forceEvent = true
	eventAt = now()
	state:SetAttribute("EventAt", eventAt)
	if phase == "Lobby" or phase == "Waiting" then
		skip = true
	end
end

function Rounds.setMinEntrants(n: number)
	minEntrants = math.clamp(n, 0, Config.World.stationCount)
end

-- Fire the clip moment now (last winner, or the first cake on the plaza).
function Rounds.clip(): string
	local e = lastWinner
	if e then
		roundRemote:FireAllClients("giant", giantPayload(e))
		return "giant cake: " .. e.name
	end
	local st = Stations.list[1]
	roundRemote:FireAllClients("giant", { cake = CakeBuilder.copy(st.cake), name = st.botName or "Test Baker", ownerId = 0, golden = false, score = 5, theme = themeKey })
	return "giant cake: station " .. st.index
end

function Rounds.stateText(): string
	local owners, bots = 0, 0
	for _, st in ipairs(Stations.list) do
		if st.owner then
			owners += 1
		elseif st.botName then
			bots += 1
		end
	end
	return string.format(
		"round=%d phase=%s left=%.0fs theme=%s celebrity=%s nextEvent=%.0fs players=%d bots=%d queue=%d showing=%s",
		round,
		phase,
		math.max(0, phaseEnds - now()),
		themeKey,
		tostring(celebrity),
		math.max(0, eventAt - now()),
		owners,
		bots,
		#themeQueue,
		if current then (current :: Entry).name else "-"
	)
end

return Rounds

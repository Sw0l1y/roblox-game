-- The recurring server event: every 5 minutes (2.5 minutes after a new server starts) the MEGA BALLOON
-- inflates on the hub's Mega Pump, a countdown banner runs, it rises with a server-wide HP bar, everyone (plus
-- four Party Bots, so solo servers work) throws darts at it, and it explodes into a coin rain and a shower of
-- rare balloons — the clip moment. Players can also buy "Summon MEGA Balloon" for the whole server.
-- State lives in attributes on ReplicatedStorage.GameState so late joiners see it immediately.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = require(Shared:WaitForChild("Config"))
local Econ = require(Shared:WaitForChild("Econ"))
local Data = require(script.Parent:WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local Progress = require(script.Parent:WaitForChild("Progress"))
local Balloons = require(script.Parent:WaitForChild("Balloons"))

local Mega = {}
Mega.actions = {} :: { [string]: (Player, any) -> () }

local E = Config.Event
local state: Folder
local phase = "idle"
local nextAt = 0
local hp = 0
local maxHp = 1
local fightAt = 0 -- when the rise ends and darts start to count
local popEnd = 0
local damage: { [Player]: number } = {}
local summoner: Player? = nil
local queue: { Player } = {}
local lastBot = 0
local rng = Random.new()
local dirtyHp = false

type Rain = { pos: { Vector3 }, values: { [Player]: number }, taken: { [Player]: { [number]: boolean } }, untilT: number }
local rain: Rain? = nil

local dartRemote = Net.fast("Dart")

local function now(): number
	return workspace:GetServerTimeNow()
end

local function setPhase(p: string)
	phase = p
	state:SetAttribute("Phase", p)
end

function Mega.phase(): string
	return phase
end

function Mega.nextAt(): number
	return nextAt
end

local function schedule(at: number)
	nextAt = at
	state:SetAttribute("NextAt", at)
end

local function computeHp(): number
	local sum = 0
	for p, d in pairs(Data.all()) do
		if p.Parent then
			sum += Econ.power(d) / Econ.cooldown(d) * E.fightSeconds * 0.75
		end
	end
	return math.max(E.minHp, math.floor(sum))
end

local function startRise()
	maxHp = computeHp()
	hp = maxHp
	damage = {}
	fightAt = now() + E.riseTime
	state:SetAttribute("MaxHp", maxHp)
	state:SetAttribute("Hp", hp)
	state:SetAttribute("FightAt", fightAt)
	setPhase("rise")
	Progress.uiAll("announce", "🎈 THE MEGA BALLOON IS RISING! POP IT TOGETHER!", "Mythic")
end

local function explode(last: Player?)
	if phase ~= "fight" and phase ~= "rise" then
		return
	end
	hp = 0
	state:SetAttribute("Hp", 0)
	popEnd = now() + E.rainSeconds + 3
	state:SetAttribute("PopAt", now())
	setPhase("popped")
	Progress.uiAll("megaPop", last and last.DisplayName or "")

	-- rewards for everyone who helped (the summoner gets double)
	local maxZone = 1
	for p, d in pairs(Data.all()) do
		if p.Parent then
			maxZone = math.max(maxZone, d.zones or 1)
			if damage[p] then
				local mult = (p == summoner) and 2 or 1
				local coins = Progress.addCoins(p, d, E.reward * Econ.zoneMult(d) * Econ.coinMult(d) * mult)
				d.megaPops = (d.megaPops or 0) + 1
				Progress.ui(p, "megaReward", coins, math.floor(damage[p] / math.max(1, maxHp) * 100))
			end
		end
	end

	-- coin rain: the same coin positions for everyone, each player collects their own copy
	local pos: { Vector3 } = {}
	local flat: { number } = {}
	for _ = 1, E.rainCoins do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = 6 + math.sqrt(rng:NextNumber()) * (E.rainRadius - 6)
		local x, z = math.cos(a) * r, math.sin(a) * r
		local y = (r < Config.Hub.stageR) and Config.Hub.stageTop or 0.2
		table.insert(pos, Vector3.new(x, y, z))
		table.insert(flat, math.floor(x * 10) / 10)
		table.insert(flat, math.floor(z * 10) / 10)
		table.insert(flat, y)
	end
	local r: Rain = { pos = pos, values = {}, taken = {}, untilT = os.clock() + E.rainSeconds }
	for p, d in pairs(Data.all()) do
		if p.Parent then
			local v = math.max(1, math.floor(E.rainValue * Econ.zoneMult(d) * Econ.coinMult(d)))
			r.values[p] = v
			r.taken[p] = {}
			Progress.ui(p, "rain", flat, v)
		end
	end
	rain = r
	Balloons.shower(Config.Hub.center, E.showerCount, maxZone)
	Shop.notifyAll("🎉 MEGA POP! Grab the coins and the rare balloons!", "gold")
end

-- Start the event: countdown first (seconds), then the rise.
function Mega.start(countdown: number?, by: Player?)
	if phase ~= "idle" then
		if by then
			table.insert(queue, by)
		end
		return
	end
	summoner = by
	state:SetAttribute("Summoner", by and by.DisplayName or "")
	schedule(now() + (countdown or E.countdown))
	setPhase("countdown")
end

-- Product grant: start now, or queue right after the current one.
function Mega.summon(player: Player): boolean
	if phase == "idle" then
		Mega.start(E.summonCountdown, player)
		Shop.notifyAll("📣 " .. player.DisplayName .. " summoned a MEGA BALLOON! " .. E.summonCountdown .. " seconds!", "pink")
	else
		table.insert(queue, player)
		Shop.notifyAll("📣 " .. player.DisplayName .. " summoned the next MEGA BALLOON!", "pink")
	end
	return true
end

-- Debug: skip straight to the explosion (the clip moment).
function Mega.clip()
	if phase == "popped" then
		return
	end
	if phase == "idle" or phase == "countdown" then
		schedule(now())
		startRise()
	end
	fightAt = now()
	state:SetAttribute("FightAt", fightAt)
	setPhase("fight")
	task.delay(1.5, function()
		explode(nil)
	end)
end

function Mega.hit(player: Player, d: { [string]: any }, mega: boolean)
	if phase ~= "fight" then
		return
	end
	local hrp = Progress.root(player)
	if not hrp or (hrp.Position - Config.Hub.megaPos).Magnitude > Config.Throw.megaRange then
		return
	end
	local dmg = Econ.power(d)
	local style = Balloons.dartStyle(player)
	if mega and (d.megaDarts or 0) > 0 then
		d.megaDarts -= 1
		Progress.touch(player)
		dmg *= Config.MegaDart.mult
		style = 3
		Progress.uiAll("boom", Config.Hub.megaPos, 10)
	end
	local hand = Balloons.handOf(player)
	if hand then
		dartRemote:FireAllClients(player.UserId, hand, 0, style)
	end
	hp -= dmg
	damage[player] = (damage[player] or 0) + dmg
	dirtyHp = true
	if hp <= 0 then
		explode(player)
	end
end

Mega.actions.coin = function(player: Player, idxs: any)
	local r = rain
	if not r or os.clock() > r.untilT + 2 or type(idxs) ~= "table" then
		return
	end
	local d = Data.get(player)
	local hrp = Progress.root(player)
	local taken = r.taken[player]
	local value = r.values[player]
	if not d or not hrp or not taken or not value then
		return
	end
	local got = 0
	for n, i in ipairs(idxs) do
		if n > 20 then
			break
		end
		if type(i) == "number" and r.pos[i] and not taken[i] then
			local c = r.pos[i]
			local dx, dz = c.X - hrp.Position.X, c.Z - hrp.Position.Z
			-- client picks up at 11 studs and batches every 0.2 s while running: allow for that and for lag
			if dx * dx + dz * dz < 24 * 24 and math.abs(c.Y - hrp.Position.Y) < 20 then
				taken[i] = true
				got += value
			end
		end
	end
	if got > 0 then
		Progress.addCoins(player, d, got)
	end
end

local function step()
	local t = now()
	if phase == "idle" then
		if t >= nextAt - E.countdown then
			setPhase("countdown")
		end
	elseif phase == "countdown" then
		if t >= nextAt then
			startRise()
		end
	elseif phase == "rise" then
		if t >= fightAt then
			setPhase("fight")
			lastBot = t
		end
	elseif phase == "fight" then
		-- Party Bots help (and keep solo servers fun)
		if t - lastBot >= E.botInterval then
			lastBot = t
			for _, spot in ipairs(Config.Hub.botSpots) do
				local hand = spot + Vector3.new(0, 5.6, 0)
				dartRemote:FireAllClients(0, hand, 0, 4)
				hp -= maxHp * E.botPct
			end
			dirtyHp = true
		end
		-- leak so it always pops
		if t - fightAt > E.leakAfter then
			hp -= maxHp * E.leakPct * 0.1
			dirtyHp = true
		end
		if hp <= 0 or t - fightAt > E.fightMax then
			explode(nil)
		end
	elseif phase == "popped" then
		if t >= popEnd then
			rain = nil
			damage = {}
			summoner = nil
			state:SetAttribute("Summoner", "")
			setPhase("idle")
			-- a paid summon still runs for the server when its buyer has left
			local nextBy = table.remove(queue, 1)
			if nextBy then
				summoner = nextBy
				state:SetAttribute("Summoner", nextBy.DisplayName)
				schedule(t + 15)
				setPhase("countdown")
			else
				schedule(t + E.interval)
			end
		end
	end
	if dirtyHp then
		dirtyHp = false
		state:SetAttribute("Hp", math.max(0, math.ceil(hp)))
	end
end

function Mega.init()
	state = Instance.new("Folder")
	state.Name = "GameState"
	state:SetAttribute("Phase", "idle")
	state:SetAttribute("Hp", 0)
	state:SetAttribute("MaxHp", 1)
	state:SetAttribute("FightAt", 0)
	state:SetAttribute("PopAt", 0)
	state:SetAttribute("Summoner", "")
	state.Parent = ReplicatedStorage
	schedule(now() + E.firstDelay)
	Players.PlayerRemoving:Connect(function(p)
		damage[p] = nil
		if rain then
			rain.values[p] = nil
			rain.taken[p] = nil
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.1)
			local ok, err = pcall(step)
			if not ok then
				warn("[Mega] step", err)
			end
		end
	end)
end

function Mega.summary(): string
	return string.format("mega=%s hp=%d/%d next=%ds", phase, math.max(0, math.floor(hp)), maxHp, math.floor(nextAt - now()))
end

return Mega

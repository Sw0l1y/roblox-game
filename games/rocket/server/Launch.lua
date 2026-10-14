-- The clip moment. When the last part is bolted on: everyone boards (MVP on the nose, VIPs in the gold window
-- seat, the crew on the decks), a big countdown, liftoff with fire, smoke and shake (drawn by clients from the
-- phase times), a warp, and the whole server lands on the next planet with new gravity, a new look and a
-- bigger rocket. Server owns the timeline and the player positions; clients animate the flight locally.
-- The rocket's tier multiplies everyone's launch bonus; the next rocket's tier is a bought one (queued) or a free
-- roll (luck boosts shift it, odds in the Index). Every landing opens a 3-minute ZERO-G TRAINING window.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local Data = require(script.Parent:WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local Boosts = require(script.Parent:WaitForChild("Boosts"))
local Live = require(script.Parent:WaitForChild("Live"))
local Mission = require(script.Parent:WaitForChild("Mission"))
local Rocket = require(script.Parent:WaitForChild("Rocket"))
local Crew = require(script.Parent:WaitForChild("Crew"))
local Haul = require(script.Parent:WaitForChild("Haul"))
local Bots = require(script.Parent:WaitForChild("Bots"))
local Events = require(script.Parent:WaitForChild("Events"))
local Rewards = require(script.Parent:WaitForChild("Rewards"))

local Launch = {}

local T = Config.Tune
local running = false
local summary: { [Player]: { [string]: any } } = {}
local rng = Random.new()

local function place(player: Player, cf: CFrame, anchored: boolean)
	local c = player.Character
	local root = Crew.root(player)
	if not c or not root then
		return
	end
	root.Anchored = anchored
	root.AssemblyLinearVelocity = Vector3.zero
	c:PivotTo(cf)
end

local function landingCF(k: number, n: number): CFrame
	local area = Mission.area()
	local a = (k / math.max(n, 1)) * math.pi * 2
	local r = 8 + (k % 3) * 3.4
	local pos = area.landing + Vector3.new(math.cos(a) * r, 3.6, math.sin(a) * r)
	local look = area.padCenter + Vector3.new(0, 3.6, 0)
	return CFrame.lookAt(pos, Vector3.new(look.X, pos.Y, look.Z))
end
Launch.landingCF = landingCF

-- The top hauler still in the server (the board keeps players who left), nil if nobody hauled.
-- nil, not -1: Studio test players have negative UserIds.
local function mvpUid(top: { Crew.Entry }): number?
	for _, e in ipairs(top) do
		if Players:GetPlayerByUserId(e.uid) then
			return e.uid
		end
	end
	return nil
end

local function seatEveryone()
	local layout = Rocket.layout
	if not layout then
		return
	end
	local mvp = mvpUid(Crew.top())
	local si, vi = 0, 0
	for _, p in ipairs(Players:GetPlayers()) do
		local seat: CFrame
		local kind = "crew"
		if p.UserId == mvp then
			seat = layout.mvpSeat
			kind = "mvp"
		elseif Shop.owns(p, "VIP") and vi < #layout.vipSeats then
			vi += 1
			seat = layout.vipSeats[vi]
			kind = "vip"
		else
			si += 1
			local n = #layout.seats
			seat = layout.seats[(si - 1) % n + 1]
			if si > n then
				seat *= CFrame.new(0, 0, -1.2 * math.floor((si - 1) / n))
			end
		end
		p:SetAttribute("SeatCF", seat)
		p:SetAttribute("SeatKind", kind)
		place(p, Rocket.base * seat * CFrame.new(0, 3.2, 0), true)
	end
end

local function rewardEveryone(fromPlanet: number, toPlanet: number)
	local top = Crew.top()
	local mvp = mvpUid(top)
	local tier = Config.rocketTier(Rocket.tier)
	local fromCoins = Config.planet(fromPlanet).coins * Config.missionMult(Mission.mission) * tier.reward
	for _, p in ipairs(Players:GetPlayers()) do
		local d = Data.get(p)
		if d then
			local isMvp = p.UserId == mvp
			local coins = T.launchBonus * fromCoins * Crew.coinMult(p) * (isMvp and (1 + T.mvpBonus) or 1)
			coins = Crew.addCoins(p, coins)
			local ladderBefore = Crew.ladderMult(p, d)
			local credit = Crew.launchMult(p)
			d.launches = (d.launches or 0) + credit
			local freeAfter = Config.freeMult(d.launches)
			local unlocked = if freeAfter > ladderBefore then freeAfter else nil
			Live.quest(p, "launch", 1)
			if ((p:GetAttribute("Friends") :: number?) or 0) > 0 then
				Live.quest(p, "friend", 1) -- "launch a rocket with a friend": a friend is in this server
			end
			Live.badge(p, "FirstLaunch")
			if toPlanet >= 3 then
				Live.badge(p, "ReachMars")
			end
			if toPlanet >= 4 then
				Live.badge(p, "ReachEuropa")
			end
			if isMvp then
				d.mvps = (d.mvps or 0) + 1
			end
			local key = Config.planet(toPlanet).key
			local firstVisit = d.planets[key] == nil
			d.planets[key] = true
			d.planets[Config.planet(fromPlanet).key] = true
			if toPlanet > (d.bestPlanet or 1) and Mission.mission >= (d.bestMission or 1) then
				d.bestPlanet = toPlanet
			end
			if Mission.mission > (d.bestMission or 1) then
				d.bestMission = Mission.mission
			end
			if d.ftue and (d.ftue.step or 0) < 4 then
				d.ftue.step = 4
			end
			local contributed = 0
			for _, e in ipairs(top) do
				if e.uid == p.UserId then
					contributed = e.weight
				end
			end
			summary[p] = {
				coins = coins,
				mvp = isMvp,
				firstVisit = firstVisit,
				planet = toPlanet,
				launches = d.launches,
				credit = credit,
				contributed = contributed,
				tier = tier.key,
				unlocked = unlocked,
			}
			Data.dirty(p)
		end
	end
end

-- The next rocket's tier: a bought one first, else a free roll (server luck shifts it toward Galaxy).
local function nextTier(): (string, string?)
	local bought = Mission.popTier()
	if bought then
		return bought.tier, bought.by
	end
	return (Tiers.roll(Config.RocketTiers, rng, Boosts.mult("luck")) :: Config.RocketTier).key, nil
end

function Launch.start()
	if running or not Mission.inBuild() then
		return
	end
	running = true
	local newTier: string? = nil
	local newTierBy: string? = nil
	Haul.clear()
	Bots.clear()
	Mission.setPhase("boarding")
	Mission.announce(Config.Icons.rocket .. " ROCKET COMPLETE! ALL ABOARD!", "gold", "cheer")
	task.spawn(function()
		local ok, err = pcall(function()
			task.wait(T.boardTime)
			seatEveryone()
			Mission.setPhase("countdown")
			task.wait(T.countdown)
			Mission.setPhase("flight")
			task.wait(T.flightTime)

			-- warp: rewards, switch planet, rebuild, move everyone to the landing zone
			local from = Mission.planet
			local to = from % #Config.Planets + 1
			if to == 1 then
				Mission.mission += 1
			end
			rewardEveryone(from, to)
			Mission.setPhase("warp")
			Mission.setPlanet(to)
			Crew.resetContrib()
			local tierKey, tierBy = nextTier()
			Rocket.build(to, Config.sizeClass(#Players:GetPlayers()), tierKey)
			newTier = tierKey
			newTierBy = tierBy
			Rewards.repaint()
			local list = Players:GetPlayers()
			for k, p in ipairs(list) do
				p:SetAttribute("SeatCF", nil)
				p:SetAttribute("SeatKind", nil)
				place(p, landingCF(k, #list), true)
				Crew.invalidate(p)
				Crew.dress(p)
				Crew.refresh(p)
			end
			task.wait(T.warpTime)
			Mission.setPhase("arrive")
			task.wait(T.landTime)
		end)
		if not ok then
			warn("[Launch] sequence error", err)
		end
		for _, p in ipairs(Players:GetPlayers()) do
			local r = Crew.root(p)
			if r then
				r.Anchored = false
			end
			p:SetAttribute("SeatCF", nil)
			p:SetAttribute("SeatKind", nil)
			local s = summary[p]
			if s then
				Mission.fire(p, "landed", s)
			end
		end
		table.clear(summary)
		local pl = Mission.planetInfo()
		Mission.setPhase("build")
		Mission.announce(string.format("%s WELCOME TO %s!", pl.icon, pl.name), "sky", "victory")
		-- Zero-G training: 3x strength gains for everyone for 3 minutes (extendable with products)
		Boosts.add("train", T.zeroGMult, T.zeroGSeconds, "ZERO-G")
		task.delay(3.2, function()
			Mission.announce(string.format("%s ZERO-G TRAINING! %dx strength gains for %d min!", Config.Icons.zerog, T.zeroGMult, T.zeroGSeconds // 60), "purple", "magic")
		end)
		local nt = newTier
		if nt and nt ~= "Basic" then
			local tier = Config.rocketTier(nt)
			local by = newTierBy
			task.delay(6.4, function()
				local text = if by
					then string.format("%s %s ROCKET thanks to %s! x%s launch rewards!", tier.icon, string.upper(tier.name), by, tostring(tier.reward))
					else string.format("%s LUCKY ROLL: %s ROCKET! x%s launch rewards!", tier.icon, string.upper(tier.name), tostring(tier.reward))
				Mission.announce(text, if nt == "Galaxy" then "purple" else "gold", "reveal")
			end)
		end
		Events.schedule(T.eventEvery * 0.7)
		Bots.sync()
		running = false
	end)
end

-- Characters that spawn mid-sequence.
function Launch.onCharacter(player: Player)
	local phase = Mission.phase
	if phase == "warp" or phase == "arrive" then
		task.defer(function()
			place(player, landingCF(math.random(1, 12), 12), true)
		end)
	end
end

function Launch.isRunning(): boolean
	return running
end

-- Debug / clip: jump straight to a launch.
function Launch.now()
	if not Mission.inBuild() then
		return
	end
	Rocket.fillAll("Legendary")
end

return Launch

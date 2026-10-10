-- Progress outside the haul itself: gear upgrades (coins), rocket skins, the 7-day login streak, the daily
-- Fuel Run quest (in Haul), Drone Crew coins every minute and while offline, and party popper.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Data = require(script.Parent:WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local Mission = require(script.Parent:WaitForChild("Mission"))
local Crew = require(script.Parent:WaitForChild("Crew"))
local Rocket = require(script.Parent:WaitForChild("Rocket"))

local Rewards = {}

local T = Config.Tune
local DAY = 20 * 3600
local STREAK_BREAK = 48 * 3600

local function bestMult(d: { [string]: any }): number
	return Config.planet(d.bestPlanet or 1).coins * Config.missionMult(d.bestMission or 1)
end
Rewards.bestMult = bestMult

-- Skins -------------------------------------------------------------------------------------------------

function Rewards.skinOwned(player: Player, d: { [string]: any }, key: string): boolean
	local sk = Config.skin(key)
	if sk.key ~= key then
		return false
	end
	if sk.unlock == "free" then
		return true
	elseif sk.unlock == "launches" then
		return (d.launches or 0) >= (sk.need or 0)
	elseif sk.unlock == "planet" then
		return (d.bestPlanet or 1) >= (sk.need or 99)
	elseif sk.unlock == "pass" then
		return sk.pass ~= nil and Shop.owns(player, sk.pass)
	end
	return false
end

function Rewards.skinOf(player: Player): string?
	local d = Data.get(player)
	if not d then
		return nil
	end
	local key = d.skin or "Classic"
	if Rewards.skinOwned(player, d, key) then
		return key
	end
	return "Classic"
end

function Rewards.repaint()
	Rocket.pickSkin(Crew.contribWeights(), Rewards.skinOf)
end

function Rewards.equip(player: Player, key: string)
	local d = Data.get(player)
	if not d then
		return
	end
	if not Rewards.skinOwned(player, d, key) then
		Shop.notify(player, "That skin is locked!", "red")
		return
	end
	d.skin = key
	Data.dirty(player)
	Shop.notify(player, Config.skin(key).icon .. " " .. Config.skin(key).name .. " equipped! Top contributor's skin paints the rocket.", "purple")
	Rewards.repaint()
end

-- Gear ---------------------------------------------------------------------------------------------------

function Rewards.upgrade(player: Player, track: string)
	local d = Data.get(player)
	local g = Config.Gear[track]
	if not d or not g then
		return
	end
	local level = d.gear[track] or 1
	local cost = g.cost[level + 1]
	if not cost then
		Shop.notify(player, g.name .. " is maxed out!", "green")
		return
	end
	if (d.coins or 0) < cost then
		Shop.notify(player, "Need " .. cost - math.floor(d.coins or 0) .. " more coins!", "red")
		Mission.fire(player, "nope", { track = track })
		return
	end
	d.coins -= cost
	d.gear[track] = level + 1
	if d.ftue and (d.ftue.step or 0) < 3 then
		d.ftue.step = 3
	end
	Crew.refresh(player)
	Crew.dress(player)
	Crew.applyMovement(player)
	Mission.fire(player, "upgraded", { track = track, level = level + 1 })
end

-- Daily streak ------------------------------------------------------------------------------------------

function Rewards.dailyDay(d: { [string]: any }): (boolean, number)
	local now = os.time()
	local last = d.daily.last or 0
	if now - last < DAY then
		return false, d.daily.streak or 1
	end
	if last == 0 or now - last > STREAK_BREAK then
		return true, 1
	end
	return true, (d.daily.streak or 0) % #Config.Daily + 1
end

function Rewards.claimDaily(player: Player)
	local d = Data.get(player)
	if not d then
		return
	end
	local ready, day = Rewards.dailyDay(d)
	if not ready then
		Shop.notify(player, "Come back later for your next gift!", "orange")
		return
	end
	local r = Config.Daily[day]
	local coins = Crew.addCoins(player, r.coins * bestMult(d))
	if r.boost then
		d.boostUntil = math.max(d.boostUntil or 0, os.time()) + T.potionSeconds
	end
	d.daily.last = os.time()
	d.daily.streak = day
	Crew.refresh(player)
	Mission.fire(player, "daily", { day = day, coins = coins, boost = r.boost })
end

-- Drones (online every minute, offline at a reduced rate) ------------------------------------------------------

local function droneRate(d: { [string]: any }): number
	local rates = Config.Gear.drones.rate :: { number }
	return rates[math.clamp(d.gear.drones or 1, 1, #rates)] or 0
end

function Rewards.offline(player: Player, d: { [string]: any })
	local last = d.lastOnline or 0
	local rate = droneRate(d)
	if last > 0 and rate > 0 then
		local secs = math.min(os.time() - last, T.offlineCapHours * 3600)
		if secs >= 120 then
			local coins = Crew.addCoins(player, rate * (secs / 60) * T.offlineRate * bestMult(d))
			task.delay(4, function()
				if player.Parent then
					Mission.fire(player, "offline", { coins = coins, minutes = math.floor(secs / 60) })
				end
			end)
		end
	end
	d.lastOnline = os.time()
end

function Rewards.init()
	Net.event("Upgrade").OnServerEvent:Connect(function(player, track)
		if type(track) == "string" and Net.allow(player, "upgrade", 0.25) then
			Rewards.upgrade(player, track)
		end
	end)
	Net.event("Skin").OnServerEvent:Connect(function(player, key)
		if type(key) == "string" and Net.allow(player, "skin", 0.5) then
			Rewards.equip(player, key)
		end
	end)
	Net.event("Daily").OnServerEvent:Connect(function(player)
		if Net.allow(player, "daily", 1) then
			Rewards.claimDaily(player)
		end
	end)
	Net.event("Popper").OnServerEvent:Connect(function(player)
		if not Shop.owns(player, "PartyPopper") or not Net.allow(player, "popper", 2) then
			return
		end
		local r = Crew.root(player)
		if r then
			local P = Config.Palette
			Net.event("Fx"):FireAllClients("burst", r.Position + Vector3.new(0, 3, 0), { P.orange, P.gold, P.sky, P.white, Color3.fromRGB(255, 100, 190) }, 34, 1.6)
			Mission.fireAll("popper", { uid = player.UserId, pos = r.Position })
		end
	end)
	Data.onLeaving(function(_, d)
		d.lastOnline = os.time()
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			for _, p in ipairs(Players:GetPlayers()) do
				local d = Data.get(p)
				if d then
					d.lastOnline = os.time()
					local rate = droneRate(d)
					if rate > 0 then
						local coins = Crew.addCoins(p, rate * Mission.coinMult())
						Mission.fire(p, "income", { coins = coins })
					end
				end
			end
		end
	end)
end

return Rewards

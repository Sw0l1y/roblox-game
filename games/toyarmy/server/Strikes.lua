-- Paid strikes (dev products, Config.Strikes): the buyer aims at a zone their team does not hold (STRIKES panel,
-- "aim" before the purchase prompt), the server schedules the hit and every client draws it (Net "Strike": the
-- rubber bands, water balloon, RC plane, rockets, flashlight or the dog) landing exactly when Zones.strike knocks
-- the toys over. A strike bought while there is nothing to hit is saved as a credit and used later for free.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Data = require(script.Parent:WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local Army = require(script.Parent:WaitForChild("Army"))
local Battle = require(script.Parent:WaitForChild("Battle"))
local Zones = require(script.Parent:WaitForChild("Zones"))
local Cat = require(script.Parent:WaitForChild("Cat"))

local Strikes = {}

local V = Vector3.new
local strikeRemote = Net.event("Strike")
local aims: { [Player]: string } = {}
local DOOR = V(0, 0, 200) -- the dog runs in and out through the bedroom door
local DOG_SPEED = 85
local fired = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

local function sideOf(player: Player): string
	return (player:GetAttribute("Side") :: string?) or "Green"
end

-- A zone this team can strike: a real zone it does not hold with toys of someone else on it.
-- (The RC-Plane Drop may also land on an empty zone: its paratroopers just take it.)
function Strikes.valid(team: string, zoneId: string, key: string): boolean
	local zs = Zones.get(zoneId)
	if not zs or zs.def.outpost then
		return false
	end
	if zs.owner == team and not zs.fight then
		return false
	end
	if key == "rcplane" then
		return true
	end
	return #Zones.enemiesAt(zoneId, team) > 0
end

-- The best target when the player did not aim: the strongest enemy-held zone, else the strongest wild one.
function Strikes.pick(team: string, key: string): string?
	local best, bestScore = nil :: string?, -1
	for _, zs in ipairs(Zones.real()) do
		if Strikes.valid(team, zs.def.id, key) then
			local score = Battle.power(Zones.enemiesAt(zs.def.id, team)) + (zs.owner == Config.enemy(team) and 1e7 or 0)
			if score > bestScore then
				best, bestScore = zs.def.id, score
			end
		end
	end
	return best
end

function Strikes.setAim(player: Player, zoneId: string)
	if Config.ZoneById[zoneId] then
		aims[player] = zoneId
	end
end

function Strikes.forget(player: Player)
	aims[player] = nil
end

-- Every zone the dog visits: the enemy team's zones, or (when it holds none) every zone with toys to knock over.
local function dogTargets(team: string): { string }
	local out: { string } = {}
	local enemy = Config.enemy(team)
	for _, zs in ipairs(Zones.real()) do
		if zs.owner == enemy and #Zones.enemiesAt(zs.def.id, team) > 0 then
			table.insert(out, zs.def.id)
		end
	end
	if #out == 0 then
		for _, zs in ipairs(Zones.real()) do
			if Strikes.valid(team, zs.def.id, "dog") then
				table.insert(out, zs.def.id)
			end
		end
	end
	return out
end

-- The dog's run: in through the door, nearest zone next, back out. Returns path points and per-zone hit times.
local function dogPlan(zones: { string }, t0: number): ({ { p: Vector3, t: number } }, { { zone: string, t: number } })
	local path = { { p = DOOR, t = t0 } }
	local hits = {}
	local pos, t = DOOR, t0
	local left = table.clone(zones)
	while #left > 0 do
		local bi, bd = 1, math.huge
		for i, id in ipairs(left) do
			local zp = Config.ZoneById[id].pos
			local dist = (V(zp.X, 0, zp.Z) - pos).Magnitude
			if dist < bd then
				bi, bd = i, dist
			end
		end
		local id = table.remove(left, bi) :: string
		local zp = Config.ZoneById[id].pos
		pos = V(zp.X, 0, zp.Z)
		t += math.max(0.6, bd / DOG_SPEED)
		table.insert(path, { p = pos, t = t })
		table.insert(hits, { zone = id, t = t })
		t += 0.5 -- a quick shake and a bark
		table.insert(path, { p = pos, t = t })
	end
	t += (DOOR - pos).Magnitude / DOG_SPEED
	table.insert(path, { p = DOOR, t = t })
	return path, hits
end

local function credit(player: Player, n: number)
	local d = Data.get(player)
	if d and n > 0 then
		Army.addXp(player, d, 8 + math.min(30, n * 2))
	end
end

-- Launch a strike for this player now. Returns false (nothing launched) when there is nothing to hit.
function Strikes.fire(player: Player, key: string, zoneId: string?): boolean
	local def = Config.Strikes[key]
	local item = Config.Products[key]
	if not def or not item or not player.Parent then
		return false
	end
	local team = sideOf(player)
	if key == "callcat" then
		Cat.call(player)
		return true
	end
	local by = player.DisplayName
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local from = root and root.Position or Config.Spawn[team].pos
	if def.all then
		local list = dogTargets(team)
		if #list == 0 then
			return false
		end
		fired += 1
		local path, hits = dogPlan(list, now() + def.delay)
		strikeRemote:FireAllClients(key, { by = by, team = team, path = path, hits = hits, from = from })
		Shop.notifyAll(item.glyph .. " " .. by .. " let THE DOG loose on the " .. Config.Team[Config.enemy(team)].name .. "!", "gold")
		for _, h in ipairs(hits) do
			task.delay(math.max(0, h.t - now()), function()
				credit(player, Zones.strike(h.zone, team, def.hits, def.dmg, key))
			end)
		end
		return true
	end
	local target = zoneId
	if not target or not Strikes.valid(team, target, key) then
		target = aims[player]
		if not target or not Strikes.valid(team, target, key) then
			target = Strikes.pick(team, key)
		end
	end
	if not target then
		return false
	end
	fired += 1
	local zdef = Config.ZoneById[target]
	local hitAt = now() + def.delay
	strikeRemote:FireAllClients(key, { by = by, team = team, zone = target, t = hitAt, from = from })
	Army.feed(item.glyph .. " " .. by .. " hit " .. zdef.name .. " with a " .. item.name .. "!", team == "Green" and "green" or "orange")
	if def.dmg >= 1 then
		Shop.notifyAll(item.glyph .. " " .. by .. " used a " .. item.name .. " on " .. zdef.name .. "!", "gold")
	end
	task.delay(def.delay, function()
		local n = Zones.strike(target :: string, team, def.hits, def.dmg, key)
		credit(player, n)
		local squadShare = def.squad
		if squadShare and player.Parent then
			local d = Data.get(player)
			local budget = math.max(60, (d and Army.squadPower(player, d) or 60) * squadShare)
			local squad = Battle.compose(budget, 4, "AI", team, by .. " 🪂", 1)
			Zones.deployAI(team, target :: string, squad, player)
		end
	end)
	return true
end

-- Strikes fired since the server started (Debug "state").
function Strikes.count(): number
	return fired
end

Players.PlayerRemoving:Connect(Strikes.forget)

return Strikes

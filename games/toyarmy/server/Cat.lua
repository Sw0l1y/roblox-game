-- The house cat: the recurring server event and the clip moment. Every ~10 minutes it wakes up on the bed,
-- jumps down, stomps to the busiest zones and swats the armies there flying (flag goes neutral), drops
-- "lost soldier" bags anyone can grab, then goes back to sleep. "Call the Cat" (dev product) sends it now
-- at the buyer's enemies. The server sends clients a keyframe plan (server times) and swat moments;
-- clients animate the cat and the flying toys.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local World = require(Shared:WaitForChild("World"))
local Data = require(script.Parent:WaitForChild("Data"))
local Army = require(script.Parent:WaitForChild("Army"))
local Zones = require(script.Parent:WaitForChild("Zones"))

local Cat = {}

local V = Vector3.new
local catRemote = Net.event("Cat")
local rng = Random.new()

type Call = { by: Player?, team: string? }
local active = false
local queued: { Call } = {} -- paid calls waiting for the cat (each one runs; none is dropped)
local nextAt = 0 -- server time of the next natural visit
local warned = false
local pickupFolder: Folder? = nil
local runs = 0
local current: { keys: { any }, by: string }? = nil -- the run in progress, for players who join mid-run

local function now(): number
	return workspace:GetServerTimeNow()
end

local function yawOf(dir: Vector3): number
	return math.atan2(-dir.X, -dir.Z)
end

local function flat(v: Vector3): Vector3
	return V(v.X, 0, v.Z)
end

-- Lost soldiers: little bags the cat knocked loose. First player to touch one gets a free bag.
local function dropPickups(at: Vector3)
	local folder = pickupFolder
	if not folder then
		return
	end
	for i = 1, Config.Cat.pickups do
		local a = (i / Config.Cat.pickups) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local r = rng:NextNumber(14, 26)
		local pos = at + V(math.cos(a) * r, 2.2, math.sin(a) * r)
		local bag = World.part({
			Name = "LostSoldiers",
			Shape = Enum.PartType.Ball,
			CFrame = CFrame.new(pos),
			Size = V(3.6, 4.2, 3.6),
			Color = Config.C.lime,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Parent = folder,
		})
		World.part({ Name = "Tie", CFrame = CFrame.new(pos + V(0, 2.3, 0)), Size = V(1.2, 1, 1.2), Color = Config.C.red, CanCollide = false, CanQuery = false, CanTouch = false, Parent = bag })
		local glow = World.disc(bag, pos.X, pos.Z, 3.4, pos.Y - 1.9, 0.12, Config.C.yellow)
		glow.Material = Enum.Material.Neon
		glow.CanCollide = false
		glow.CanTouch = false
		glow.CanQuery = false
		World.label(bag, "🎒 LOST SOLDIERS!", { width = 10, height = 2.2, offset = V(0, 4.5, 0), maxDistance = 90, color = Config.C.yellow })
		local taken = false
		bag.Touched:Connect(function(hit: BasePart)
			if taken then
				return
			end
			local model = hit:FindFirstAncestorOfClass("Model") :: Model?
			local player = model and Players:GetPlayerFromCharacter(model)
			if not player then
				return
			end
			local d = Data.get(player)
			if not d then
				return
			end
			taken = true
			Army.addTokens(player, d, "Basic", 1, bag.Position)
			catRemote:FireAllClients("pickup", bag.Position, player.DisplayName)
			bag:Destroy()
		end)
		task.delay(Config.Cat.pickupLife, function()
			if bag.Parent then
				bag:Destroy()
			end
		end)
	end
end

local function swat(zoneId: string, pos: Vector3, by: Player?)
	local n = Zones.swat(zoneId)
	local def = Config.ZoneById[zoneId]
	catRemote:FireAllClients("swat", zoneId, pos, n)
	if n > 0 then
		Army.feed("🐱 The cat swatted " .. n .. " soldiers off " .. (def and def.name or zoneId) .. "!", "orange")
	end
	dropPickups(def and def.pos or pos)
	if by and by.Parent then
		local d = Data.get(by)
		if d then
			Army.addXp(by, d, 15)
		end
	end
end

-- Pick the zones to visit: for a called cat the strongest enemy zones; otherwise the busiest zones.
local function targets(call: Call?): { Config.ZoneDef }
	local list = Zones.real()
	local enemy = call and call.team and Config.enemy(call.team :: string) or nil
	table.sort(list, function(a: Zones.ZoneState, b: Zones.ZoneState)
		local sa = #a.garrison + (enemy and a.owner == enemy and 100 or 0) + Zones.garrisonPower(a) * 1e-6
		local sb = #b.garrison + (enemy and b.owner == enemy and 100 or 0) + Zones.garrisonPower(b) * 1e-6
		return sa > sb
	end)
	local out = {}
	for i = 1, math.min(Config.Cat.targets, #list) do
		table.insert(out, list[i].def)
	end
	return out
end

-- Keyframes: { t, p, y, a } where `a` is the motion from this keyframe to the next.
export type Key = { t: number, p: Vector3, y: number, a: string }

local function plan(list: { Config.ZoneDef }, t0: number): ({ Key }, { { zone: string, at: Vector3, t: number } })
	local keys: { Key } = {}
	local swipes = {}
	local bed, floor = Config.Cat.bedPos, Config.Cat.floorPos
	local t = t0
	local function push(p: Vector3, y: number, a: string)
		table.insert(keys, { t = t, p = p, y = y, a = a })
	end
	local pos = bed
	push(pos, yawOf(floor - bed), "wake")
	t += 3
	push(pos, yawOf(floor - bed), "jump")
	t += 1.3
	pos = floor
	for _, def in ipairs(list) do
		local zp = def.pos
		local dir = flat(zp - Config.Cat.hub)
		if dir.Magnitude < 1 then
			dir = V(0, 0, 1)
		end
		dir = dir.Unit
		local standTop = zp - dir * Config.Cat.reach
		local standFloor = V(standTop.X, 0, standTop.Z)
		local elevated = zp.Y > 5
		if elevated then
			standFloor = standFloor - dir * 30
		end
		local walk = flat(standFloor - pos)
		if walk.Magnitude > 1 then
			push(pos, yawOf(walk), "walk")
			t += walk.Magnitude / Config.Cat.speed
			pos = standFloor
		end
		if elevated then
			push(pos, yawOf(dir), "jump")
			t += 1.3
			pos = V(standTop.X, zp.Y, standTop.Z)
		end
		push(pos, yawOf(flat(zp - pos)), "swipe")
		table.insert(swipes, { zone = def.id, at = zp, t = t + 1.25 })
		t += 2.8
		if elevated then
			push(pos, yawOf(-dir), "jump")
			t += 1.3
			pos = standFloor
		end
	end
	local back = flat(floor - pos)
	if back.Magnitude > 1 then
		push(pos, yawOf(back), "walk")
		t += back.Magnitude / Config.Cat.speed
		pos = floor
	end
	push(pos, yawOf(flat(bed - floor)), "jump")
	t += 1.3
	push(bed, yawOf(V(1, 0, 0.4)), "sleep")
	return keys, swipes
end

function Cat.isActive(): boolean
	return active
end

local function run(call: Call?)
	if active then
		return
	end
	active = true
	runs += 1
	warned = false
	workspace:SetAttribute("CatActive", true)
	local list = targets(call)
	local t0 = now() + 0.5
	local keys, swipes = plan(list, t0)
	local by = call and call.by or nil
	current = { keys = keys, by = by and by.DisplayName or "" }
	catRemote:FireAllClients("run", keys, current.by)
	if by then
		Army.feed("🐱 " .. by.DisplayName .. " CALLED THE CAT on the " .. Config.Team[Config.enemy(call and call.team or "Green")].name .. "!", "pink")
	else
		Army.feed("🐱 THE CAT IS AWAKE! Hide your soldiers!", "pink")
	end
	for _, s in ipairs(swipes) do
		task.delay(math.max(0, s.t - now()), function()
			swat(s.zone, s.at, by)
		end)
	end
	local endT = keys[#keys].t
	task.delay(math.max(1, endT - now()), function()
		active = false
		current = nil
		workspace:SetAttribute("CatActive", false)
		catRemote:FireAllClients("done")
		if nextAt - now() < 90 then
			nextAt = now() + 90
			workspace:SetAttribute("CatAt", nextAt)
		end
	end)
end

-- Start the cat now (Debug "event", or a natural visit).
function Cat.start()
	if active then
		return false
	end
	nextAt = now() + Config.Cat.interval
	workspace:SetAttribute("CatAt", nextAt)
	run(nil)
	return true
end

-- "Call the Cat!" dev product: sends the cat at the buyer's enemies (queued if it is already out).
function Cat.call(player: Player)
	local call: Call = { by = player, team = player:GetAttribute("Side") :: string? }
	if active then
		table.insert(queued, call)
		catRemote:FireClient(player, "queued")
	else
		run(call)
	end
end

-- Debug "clip": skip the walk, swat the busiest zone right now.
function Cat.clip(): string
	local list = targets(nil)
	local def = list[1]
	if not def then
		return "no zones"
	end
	swat(def.id, def.pos, nil)
	return "swatted " .. def.id
end

-- A player who joins while the cat is out sees it where it is now.
function Cat.replay(player: Player)
	local c = current
	if c and player.Parent then
		catRemote:FireClient(player, "run", c.keys, c.by)
	end
end

function Cat.status(): string
	return string.format("cat %s, next in %ds, runs %d", active and "ACTIVE" or "asleep", math.floor(nextAt - now()), runs)
end

function Cat.init(parent: Instance)
	pickupFolder = World.folder("CatDrops", parent)
	nextAt = now() + Config.Cat.first
	workspace:SetAttribute("CatAt", nextAt)
	workspace:SetAttribute("CatActive", false)
	task.spawn(function()
		while true do
			task.wait(0.5)
			if not active then
				local q = table.remove(queued, 1)
				if q then
					if q.by and (q.by :: Player).Parent then
						run(q)
					end
				elseif now() >= nextAt then
					nextAt = now() + Config.Cat.interval
					workspace:SetAttribute("CatAt", nextAt)
					run(nil)
				elseif not warned and nextAt - now() <= Config.Cat.warn then
					warned = true
					catRemote:FireAllClients("warn", nextAt)
				end
			end
		end
	end)
end

return Cat

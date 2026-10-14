-- Recurring server event: a SUPPLY DROP every few minutes (banner + countdown, a pod falls from the sky and
-- spills golden Star Crates; each crate hauled to the pad pays big and makes a drone bolt on a part).
-- At the top of every hour the HOURLY MEGA DROP: 8 crates plus 10 minutes of 2x coins and 2x luck for everyone.
-- Also the rocket products: "Fuel the Server" (2x coins + strength for everyone, drones bolt on parts) and
-- "+N Parts" (drones bolt N Legendary parts on), each with a shoutout for the buyer.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local World = require(Shared:WaitForChild("World"))
local Boosts = require(script.Parent:WaitForChild("Boosts"))
local Mission = require(script.Parent:WaitForChild("Mission"))
local Rocket = require(script.Parent:WaitForChild("Rocket"))
local Haul = require(script.Parent:WaitForChild("Haul"))
local Crew = require(script.Parent:WaitForChild("Crew"))

local Events = {}

local T = Config.Tune
local P = Config.Palette
local rng = Random.new()
local queued: { { by: string, crates: number } } = {}
local warned = false

Events.nextDrop = 0

local DROP_SPOTS = {
	Vector3.new(-40, 0, -14),
	Vector3.new(34, 0, 84),
	Vector3.new(-52, 0, 40),
	Vector3.new(30, 0, -30),
	Vector3.new(-20, 0, -60),
	Vector3.new(60, 0, 30),
	Vector3.new(0, 0, 104),
}

function Events.schedule(delay: number)
	Events.nextDrop = Mission.now() + delay
	warned = false
	Mission.set("DropAt", Events.nextDrop)
end

local function heroPod(at: Vector3): Model
	local m = Instance.new("Model")
	m.Name = "SupplyPod"
	local hero = ReplicatedStorage:FindFirstChild("HeroMeshes")
	local mesh = hero and hero:FindFirstChild("supplyPod")
	if mesh and mesh:IsA("MeshPart") then
		local mp = (mesh :: any):Clone() :: MeshPart
		mp.Anchored = true
		mp.CFrame = CFrame.new(at + Vector3.new(0, mp.Size.Y / 2, 0))
		mp.Parent = m
	else
		-- primitive pod: white capsule body, orange stripes, legs, glowing hatch
		World.cyl(m, at + Vector3.new(0, 1.6, 0), 7, 7, P.white, { Name = "PodBody" })
		World.ball(m, at + Vector3.new(0, 8.6, 0), 7, P.white, { Name = "PodTop" })
		World.cyl(m, at + Vector3.new(0, 3, 0), 1, 7.3, P.orange, { Name = "PodStripe" })
		World.cyl(m, at + Vector3.new(0, 6.2, 0), 1, 7.3, P.orange, { Name = "PodStripe" })
		World.cyl(m, at + Vector3.new(0, 11.7, 0), 1.2, 2, P.navy, { Name = "PodCap" })
		local beacon = World.ball(m, at + Vector3.new(0, 13.2, 0), 1.6, P.gold, { Name = "PodBeacon", Material = Enum.Material.Neon })
		local light = Instance.new("PointLight")
		light.Color = P.gold
		light.Range = 18
		light.Brightness = 2
		light.Parent = beacon
		World.box(m, CFrame.new(at + Vector3.new(0, 4.6, -3.45)), Vector3.new(3.4, 4, 0.4), P.gold, { Name = "PodHatch", Material = Enum.Material.Neon })
		for k = 0, 2 do
			local a = k / 3 * math.pi * 2
			local foot = at + Vector3.new(math.cos(a) * 5, 0.3, math.sin(a) * 5)
			World.rod(m, at + Vector3.new(math.cos(a) * 3, 3, math.sin(a) * 3), foot, 0.6, P.navy)
			World.cyl(m, foot - Vector3.new(0, 0.3, 0), 0.4, 1.8, P.navy, { Name = "PodFoot" })
		end
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			(d :: BasePart).CanTouch = false
		end
	end
	return m
end

-- crates: Star Crates in the pod (default T.crateCount; the hourly mega drop has more).
function Events.supplyDrop(by: string?, crates: number?): boolean
	if not Mission.inBuild() then
		table.insert(queued, { by = by or "", crates = crates or T.crateCount })
		return false
	end
	local n = crates or T.crateCount
	local area = Mission.area()
	local spot = area.origin + DROP_SPOTS[rng:NextInteger(1, #DROP_SPOTS)]
	local fall = 2.6
	local impact = Mission.now() + fall
	Mission.fireAll("drop", { pos = spot, t = impact, by = by })
	if n > T.crateCount then
		Mission.announce(string.format("%s HOURLY MEGA DROP! %d STAR CRATES!", Config.Icons.timer, n), "gold", "reveal")
	elseif by and by ~= "" then
		Mission.announce(string.format("%s %s called a SUPPLY DROP!", Config.Icons.box, by), "gold", "reveal")
	else
		Mission.announce(Config.Icons.box .. " SUPPLY DROP! Grab the Star Crates!", "gold", "reveal")
	end
	Events.schedule(T.eventEvery)
	task.delay(fall, function()
		if not Mission.inBuild() then
			return
		end
		local pod = heroPod(spot)
		pod.Parent = workspace
		Debris:AddItem(pod, 60)
		Haul.spawnCrates(spot, n)
		Net.event("Fx"):FireAllClients("shockwave", spot + Vector3.new(0, 0.6, 0), P.gold, 30)
		Net.event("Fx"):FireAllClients("burst", spot + Vector3.new(0, 2, 0), { P.gold, P.white, P.orange }, 26, 1.8)
	end)
	return true
end

-- n drones bolt parts on, one after another. Bought mid-launch, or more parts than open slots: the rest wait
-- for the next rocket (a few minutes at most), so a paid part is never lost.
local function drones(by: string, reason: string, n: number)
	task.spawn(function()
		task.wait(0.8)
		local left = n
		local tries = 0
		while left > 0 and tries < 600 do
			if Haul.autoBolt(by, reason) then
				left -= 1
				task.wait(T.partsGap)
			else
				tries += 1
				task.wait(1)
			end
		end
	end)
end

-- Fuel the Server: 2x coins + strength for everyone, drones bolt on parts, shoutout.
function Events.fuel(player: Player)
	Boosts.add("coins", 2, T.fuelBoostSeconds, player.DisplayName)
	Boosts.add("strength", 2, T.fuelBoostSeconds, player.DisplayName)
	Crew.invalidate(nil)
	Mission.announce(string.format("%s %s FUELED THE SERVER! 2X for everyone!", Config.Icons.fuel, player.DisplayName), "orange", "cheer")
	Mission.fireAll("fuel", { by = player.DisplayName, uid = player.UserId })
	drones(player.DisplayName, "fuel", T.fuelBolts)
end

-- "+N Parts" (n = 0: every open slot right now, i.e. finish the rocket).
function Events.parts(player: Player, n: number)
	local count = n
	if count <= 0 then
		local filled, total = Rocket.counts()
		count = math.max(1, total - filled)
	end
	local text = if n <= 0
		then string.format("%s %s is FINISHING THE ROCKET! LAUNCH!", "\u{1F3C1}", player.DisplayName)
		else string.format("%s %s sent +%d ROCKET PARTS!", Config.Icons.drone, player.DisplayName, count)
	Mission.announce(text, "orange", "cheer")
	Mission.fireAll("fuel", { by = player.DisplayName, uid = player.UserId, parts = count })
	drones(player.DisplayName, "parts", count)
end

-- Top of every hour (kit Live.onHour): the HOURLY MEGA DROP and 10 minutes of 2x coins + 2x luck for everyone.
function Events.hourly()
	local secs = T.hourlyBoostMinutes * 60
	Boosts.add("coins", 2, secs, "HOURLY EVENT")
	Boosts.add("luck", 2, secs, "HOURLY EVENT")
	Crew.invalidate(nil)
	Mission.announce(string.format("%s HOURLY EVENT! 2X COINS + 2X LUCK for %d min!", Config.Icons.timer, T.hourlyBoostMinutes), "gold", "victory")
	task.delay(3, function()
		Events.supplyDrop("HOURLY", T.hourlyCrates)
	end)
end

function Events.init()
	Events.schedule(T.eventEvery * 0.6)
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(0.5)
			tick += 1
			local now = Mission.now()
			if not Mission.inBuild() then
				Events.nextDrop += 0.5
				if tick % 6 == 0 then
					Mission.set("DropAt", Events.nextDrop)
				end
			else
				if #queued > 0 then
					local q = table.remove(queued, 1)
					if q then
						Events.supplyDrop(q.by, q.crates)
					end
				elseif not warned and now >= Events.nextDrop - T.eventWarn then
					warned = true
					Mission.fireAll("dropWarn", { t = Events.nextDrop })
				elseif now >= Events.nextDrop then
					Events.supplyDrop(nil)
				end
			end
		end
	end)
end

return Events

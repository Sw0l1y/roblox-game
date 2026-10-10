-- Recurring server event: a SUPPLY DROP every few minutes (banner + countdown, a pod falls from the sky and
-- spills golden Star Crates; each crate hauled to the pad pays big and makes a drone bolt on a part).
-- Also "Fuel the Server" (product): 2x for everyone, drones bolt on parts, the buyer gets a shoutout.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local World = require(Shared:WaitForChild("World"))
local Mission = require(script.Parent:WaitForChild("Mission"))
local Haul = require(script.Parent:WaitForChild("Haul"))
local Crew = require(script.Parent:WaitForChild("Crew"))

local Events = {}

local T = Config.Tune
local P = Config.Palette
local rng = Random.new()
local queued: { string } = {}
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

function Events.supplyDrop(by: string?): boolean
	if not Mission.inBuild() then
		table.insert(queued, by or "")
		return false
	end
	local area = Mission.area()
	local spot = area.origin + DROP_SPOTS[rng:NextInteger(1, #DROP_SPOTS)]
	local fall = 2.6
	local impact = Mission.now() + fall
	Mission.fireAll("drop", { pos = spot, t = impact, by = by })
	if by and by ~= "" then
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
		Haul.spawnCrates(spot, T.crateCount)
		Net.event("Fx"):FireAllClients("shockwave", spot + Vector3.new(0, 0.6, 0), P.gold, 30)
		Net.event("Fx"):FireAllClients("burst", spot + Vector3.new(0, 2, 0), { P.gold, P.white, P.orange }, 26, 1.8)
	end)
	return true
end

-- Fuel the Server: 2x coins + strength for everyone, drones bolt on parts, shoutout.
function Events.fuel(player: Player)
	Mission.boost(T.fuelBoostSeconds, player.DisplayName)
	Crew.invalidate(nil)
	Mission.announce(string.format("%s %s FUELED THE SERVER! 2X for everyone!", Config.Icons.fuel, player.DisplayName), "orange", "cheer")
	Mission.fireAll("fuel", { by = player.DisplayName, uid = player.UserId, until_ = Mission.boostUntil })
	local by = player.DisplayName
	for k = 1, T.fuelBolts do
		task.delay(0.8 + k * 0.7, function()
			-- bought mid-launch or with no free slot: the paid drones wait for the next open slot
			local tries = 0
			while not Haul.autoBolt(by, "fuel") and tries < 120 do
				tries += 1
				task.wait(1)
			end
		end)
	end
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
					local by = table.remove(queued, 1)
					Events.supplyDrop(by)
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

-- Server-wide state: which planet the server is on, mission number, phase of the build/launch cycle and the
-- server fuel boost. Mirrored into ReplicatedStorage.RocketState attributes for every client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Look = require(script.Parent:WaitForChild("Look"))
local Map = require(script.Parent:WaitForChild("Map"))

local Mission = {}

Mission.planet = 1
Mission.mission = 1
Mission.phase = "build" -- build | boarding | countdown | flight | warp | arrive
Mission.boostUntil = 0
Mission.boostBy = ""

local state = Instance.new("Folder")
state.Name = "RocketState"
state.Parent = ReplicatedStorage
Mission.state = state

local gameRemote = Net.event("Game")

function Mission.now(): number
	return workspace:GetServerTimeNow()
end

function Mission.set(key: string, value: any)
	state:SetAttribute(key, value)
end

function Mission.area(): Map.Area
	return Map.areas[Mission.planet]
end

function Mission.planetInfo(): Config.Planet
	return Config.planet(Mission.planet)
end

function Mission.inBuild(): boolean
	return Mission.phase == "build"
end

function Mission.setPhase(phase: string)
	Mission.phase = phase
	state:SetAttribute("PhaseT", Mission.now())
	state:SetAttribute("Phase", phase)
end

function Mission.coinMult(): number
	return Mission.planetInfo().coins * Config.missionMult(Mission.mission)
end

function Mission.weightMult(): number
	return Mission.planetInfo().weight
end

function Mission.boosted(): boolean
	return Mission.now() < Mission.boostUntil
end

-- Server fuel boost: 2x coins and strength for everyone (stacks by extending).
function Mission.boost(seconds: number, by: string)
	local now = Mission.now()
	Mission.boostUntil = math.max(Mission.boostUntil, now) + seconds
	Mission.boostBy = by
	state:SetAttribute("BoostUntil", Mission.boostUntil)
	state:SetAttribute("BoostBy", by)
end

-- Move the whole server's look and physics to planet i (players are moved by the caller).
function Mission.setPlanet(i: number)
	Mission.planet = i
	local pl = Config.planet(i)
	Look.apply(pl.look)
	workspace.Gravity = pl.gravity
	for k, a in ipairs(Map.areas) do
		a.spawn.Enabled = k == i
	end
	state:SetAttribute("Planet", i)
	state:SetAttribute("Mission", Mission.mission)
	state:SetAttribute("Gravity", pl.gravity)
	local area = Map.areas[i]
	if area then
		state:SetAttribute("BoltRadius", area.boltRadius)
		state:SetAttribute("PadCenter", area.padCenter)
		state:SetAttribute("Landing", area.landing)
	end
end

function Mission.fire(player: Player, kind: string, payload: any)
	gameRemote:FireClient(player, kind, payload)
end

function Mission.fireAll(kind: string, payload: any)
	gameRemote:FireAllClients(kind, payload)
end

-- Big banner for everyone (rare finds, launches, shoutouts).
function Mission.announce(text: string, color: string, sound: string?)
	gameRemote:FireAllClients("announce", { text = text, color = color, sound = sound })
end

state:SetAttribute("Planet", 1)
state:SetAttribute("Mission", 1)
state:SetAttribute("Phase", "build")
state:SetAttribute("PhaseT", 0)
state:SetAttribute("BoostUntil", 0)
state:SetAttribute("BoostBy", "")

return Mission

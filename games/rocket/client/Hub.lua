-- Client hub: the replicated RocketState, server event dispatch ("Game" remote) and a little shared state
-- between the client modules (what the local player is carrying, the current goal, cinematic mode).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local Hub = {}

Hub.player = Players.LocalPlayer
Hub.state = ReplicatedStorage:WaitForChild("RocketState")
Hub.joinedAt = os.clock()

export type Carry = {
	id: string,
	kind: string,
	tier: string,
	weight: number,
	str: number,
	speed: number,
	holders: number,
	cap: number,
	bots: number,
	pos: Vector3,
}

-- What the local player is holding (set by Render every frame), nil when free.
Hub.carry = nil :: Carry?
Hub.cinematic = false

local listeners: { [string]: { (any) -> () } } = {}

function Hub.on(kind: string, fn: (any) -> ())
	local l = listeners[kind]
	if not l then
		l = {}
		listeners[kind] = l
	end
	table.insert(l, fn)
end

function Hub.emit(kind: string, payload: any)
	local l = listeners[kind]
	if l then
		for _, fn in ipairs(l) do
			task.spawn(fn, payload)
		end
	end
end

function Hub.attr(key: string): any
	return Hub.state:GetAttribute(key)
end

function Hub.num(key: string, default: number): number
	local v = Hub.state:GetAttribute(key)
	return if type(v) == "number" then v else default
end

function Hub.str(key: string, default: string): string
	local v = Hub.state:GetAttribute(key)
	return if type(v) == "string" then v else default
end

function Hub.now(): number
	return workspace:GetServerTimeNow()
end

function Hub.planet(): number
	return Hub.num("Planet", 1)
end

function Hub.planetInfo(): Config.Planet
	return Config.planet(Hub.planet())
end

function Hub.phase(): string
	return Hub.str("Phase", "build")
end

function Hub.phaseT(): number
	return Hub.now() - Hub.num("PhaseT", 0)
end

function Hub.origin(): Vector3
	return Hub.planetInfo().origin
end

function Hub.padCenter(): Vector3
	local v = Hub.attr("PadCenter")
	if typeof(v) == "Vector3" then
		return v
	end
	return Hub.origin() + Config.Layout.pad
end

function Hub.root(player: Player?): BasePart?
	local p = player or Hub.player
	local c = p.Character
	if not c then
		return nil
	end
	local r = c:FindFirstChild("HumanoidRootPart")
	if r and r:IsA("BasePart") then
		return r :: BasePart
	end
	return nil
end

function Hub.humanoid(): Humanoid?
	local c = Hub.player.Character
	if not c then
		return nil
	end
	return (c:FindFirstChildOfClass("Humanoid") :: any) :: Humanoid?
end

Net.event("Game").OnClientEvent:Connect(function(kind, payload)
	if type(kind) == "string" then
		Hub.emit(kind, payload)
	end
end)

return Hub

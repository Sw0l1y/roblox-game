-- Remotes by name. The server creates them on first use; clients wait for them.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}
local IS_SERVER = RunService:IsServer()

local function folder(): Instance
	local f = ReplicatedStorage:FindFirstChild("Remotes")
	if not f then
		if IS_SERVER then
			f = Instance.new("Folder")
			f.Name = "Remotes"
			f.Parent = ReplicatedStorage
		else
			f = ReplicatedStorage:WaitForChild("Remotes")
		end
	end
	return f :: Instance
end

local function get(className: string, name: string): any
	local f = folder()
	local r = f:FindFirstChild(name)
	if not r then
		if IS_SERVER then
			r = Instance.new(className)
			r.Name = name
			r.Parent = f
		else
			r = f:WaitForChild(name)
		end
	end
	return r
end

function Net.event(name: string): RemoteEvent
	return get("RemoteEvent", name)
end

function Net.func(name: string): RemoteFunction
	return get("RemoteFunction", name)
end

function Net.fast(name: string): UnreliableRemoteEvent
	return get("UnreliableRemoteEvent", name)
end

-- Server-side spam guard: true if this player may do `key` now (at most once per `seconds`).
local last: { [any]: { [string]: number } } = setmetatable({}, { __mode = "k" }) :: any
function Net.allow(player: Player, key: string, seconds: number): boolean
	local t = os.clock()
	local p = last[player]
	if not p then
		p = {}
		last[player] = p
	end
	if p[key] and t - p[key] < seconds then
		return false
	end
	p[key] = t
	return true
end

-- The kit's own remotes exist from the start, so client modules waiting on them never stall.
if IS_SERVER then
	for _, name in ipairs({ "Data", "Notify", "Buy", "Fx" }) do
		get("RemoteEvent", name)
	end
end

return Net

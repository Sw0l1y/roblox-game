-- Client copy of this player's save data, pushed by kit/server/Data whenever it changes.
-- State.data is the latest table; State.onChange(fn) runs fn(data, previous) on every push.
local Net = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Net"))

local State = {}
State.data = nil :: { [string]: any }?
State.loaded = false

local listeners: { ({ [string]: any }, { [string]: any }?) -> () } = {}

function State.onChange(fn: ({ [string]: any }, { [string]: any }?) -> ())
	table.insert(listeners, fn)
	if State.data then
		task.spawn(fn, State.data, nil)
	end
end

function State.get(key: string): any
	return State.data and State.data[key]
end

-- Yields until the first push arrives.
function State.wait(): { [string]: any }
	while not State.data do
		task.wait()
	end
	return State.data :: { [string]: any }
end

Net.event("Data").OnClientEvent:Connect(function(d)
	local prev = State.data
	State.data = d
	State.loaded = true
	for _, fn in ipairs(listeners) do
		task.spawn(fn, d, prev)
	end
end)

return State

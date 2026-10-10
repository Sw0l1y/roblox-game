--!strict
-- Studio-only test hooks: ServerStorage.DebugCmd (BindableFunction). Invoke it with one line such as
-- "give 1000000", "give Tester coins 5000", "event", "clip", "state". Main registers the commands.
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Debug = {}

export type Command = (args: { string }) -> string

function Debug.init(commands: { [string]: Command })
	if not RunService:IsStudio() then
		return
	end
	local bf = Instance.new("BindableFunction")
	bf.Name = "DebugCmd"
	bf.OnInvoke = function(line: any): string
		if type(line) ~= "string" then
			return "usage: DebugCmd:Invoke(\"command args\")"
		end
		local words = {}
		for w in string.gmatch(line, "%S+") do
			table.insert(words, w)
		end
		local name = string.lower(table.remove(words, 1) or "help")
		local fn = commands[name]
		if not fn then
			local names = {}
			for k in pairs(commands) do
				table.insert(names, k)
			end
			table.sort(names)
			return "unknown command '" .. name .. "'. Commands: " .. table.concat(names, ", ")
		end
		local ok, res = pcall(fn, words)
		if not ok then
			return "error: " .. tostring(res)
		end
		return res
	end
	bf.Parent = ServerStorage
end

return Debug

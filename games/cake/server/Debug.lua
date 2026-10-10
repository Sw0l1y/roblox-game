-- Studio-only test commands: ServerStorage.DebugCmd:Invoke("command args").
-- Commands (player = name prefix, "me" or omitted = first player):
--   give <n>                      coins to every player
--   give [player] coins|xp|box <n>
--   unlockall [player]            every topping, colour, shape, 4 tiers, slots, all passes
--   pass [player] <PassKey>       grant one pass (VIP, DoubleCoins, ExtraTime, PremiumColors, Rainbow, ExtraToppings, GoldenOven)
--   reset [player]                wipe the save back to a brand-new player
--   event                         next round is a Celebrity Judge round (skips the lobby wait)
--   clip                          play the giant-winner-cake moment now
--   skip                          end the current phase now
--   time <seconds>                set the current phase's remaining time
--   theme <Key>                   queue the next theme (Birthday, Space, Spooky, ...)
--   bots <n>                      NPC bakers fill up to n cakes (default 4)
--   box [player]                  open one Mystery Box for the player (uses a free box or coins)
--   state                         one-line summary of the round
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Data = require(script.Parent:WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local Rounds = require(script.Parent:WaitForChild("Rounds"))
local Progress = require(script.Parent:WaitForChild("Progress"))

local Debug = {}

local function findPlayer(name: string?): Player?
	local list = Players:GetPlayers()
	if not name or name == "" or name == "me" then
		return list[1]
	end
	local lower = string.lower(name)
	for _, p in ipairs(list) do
		if string.sub(string.lower(p.Name), 1, #lower) == lower then
			return p
		end
	end
	return nil
end

local function run(cmd: string, defaults: { [string]: any }): string
	local args = {}
	for w in string.gmatch(cmd, "%S+") do
		table.insert(args, w)
	end
	local c = string.lower(args[1] or "")
	if c == "give" then
		local n = tonumber(args[2])
		if n then
			for _, p in ipairs(Players:GetPlayers()) do
				local d = Data.get(p)
				if d then
					Progress.addCoins(p, d, n)
				end
			end
			return "gave " .. n .. " coins to everyone"
		end
		local p = findPlayer(args[2])
		local d = p and Data.get(p)
		if not p or not d then
			return "no player"
		end
		local what = string.lower(args[3] or "coins")
		local amount = tonumber(args[4]) or 1000
		if what == "coins" or what == "cash" then
			Progress.addCoins(p, d, amount)
		elseif what == "xp" then
			Progress.addXP(p, d, amount)
		elseif what == "box" or what == "boxes" then
			d.boxes = (d.boxes or 0) + amount
			Data.dirty(p)
		else
			return "give what? coins|xp|box"
		end
		return "gave " .. p.Name .. " " .. amount .. " " .. what
	elseif c == "unlockall" then
		local p = findPlayer(args[2])
		local d = p and Data.get(p)
		if not p or not d then
			return "no player"
		end
		for _, t in ipairs(Config.Toppings) do
			d.toppings[t.id] = true
		end
		for _, col in ipairs(Config.Colors) do
			d.colors[col.key] = true
		end
		for _, s in ipairs(Config.Shapes) do
			d.shapes[s.key] = true
		end
		d.tier4 = true
		d.slots = #Config.Cake.slotUpgrades
		for key in pairs(Config.Passes) do
			Shop.prompt(p, "pass", key)
		end
		Data.dirty(p)
		return "unlocked everything for " .. p.Name
	elseif c == "pass" then
		local p = findPlayer(if args[3] then args[2] else nil)
		local key = args[3] or args[2]
		if not p or not key or not Config.Passes[key] then
			return "pass [player] <key>"
		end
		Shop.prompt(p, "pass", key)
		return "granted " .. key
	elseif c == "reset" then
		local p = findPlayer(args[2])
		local d = p and Data.get(p)
		if not p or not d then
			return "no player"
		end
		for k in pairs(d) do
			d[k] = nil
		end
		for k, v in pairs(Data.deepCopy(defaults)) do
			d[k] = v
		end
		Data.dirty(p)
		Progress.refreshTag(p)
		return "reset " .. p.Name
	elseif c == "event" then
		Rounds.forceEvent()
		return "celebrity round queued"
	elseif c == "clip" then
		return Rounds.clip()
	elseif c == "skip" then
		Rounds.skip()
		return "skipped " .. Rounds.phase()
	elseif c == "time" then
		local n = tonumber(args[2]) or 5
		Rounds.setRemaining(n)
		return "phase ends in " .. n .. "s"
	elseif c == "theme" then
		local key = args[2] or ""
		if Rounds.queueTheme(key, "Debug") then
			return "next theme " .. key
		end
		return "unknown theme " .. key
	elseif c == "bots" then
		local n = tonumber(args[2]) or Config.Round.minEntrants
		Rounds.setMinEntrants(n)
		return "bots fill to " .. n
	elseif c == "box" then
		local p = findPlayer(args[2])
		if not p then
			return "no player"
		end
		local r = Progress.openBox(p, true)
		return if r.ok then ("opened " .. tostring(r.id) .. " (" .. tostring(r.tier) .. ")") else tostring(r.msg)
	elseif c == "state" then
		return Rounds.stateText()
	end
	return "unknown command: " .. cmd
end

function Debug.init(defaults: { [string]: any })
	if not RunService:IsStudio() then
		return
	end
	local f = Instance.new("BindableFunction")
	f.Name = "DebugCmd"
	f.OnInvoke = function(cmd: any): string
		if type(cmd) ~= "string" then
			return "usage: DebugCmd:Invoke(\"state\")"
		end
		local ok, res = pcall(run, cmd, defaults)
		if not ok then
			return "error: " .. tostring(res)
		end
		return res
	end
	f.Parent = ServerStorage
end

return Debug

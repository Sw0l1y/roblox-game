-- Studio-only test hooks: ServerStorage.DebugCmd (BindableFunction). Invoke with a command string, e.g.
--   give 1e6 | give <player> cash 1e6 | give <player> strength 500 | event | clip | fill | planet 3 | reset <player>
--   state | rarity Legendary | fuel | boost 60 | daily <player> | offline <player> 5 | ftue <player> | pass <player> VIP
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Data = require(script.Parent:WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local Mission = require(script.Parent:WaitForChild("Mission"))
local Rocket = require(script.Parent:WaitForChild("Rocket"))
local Crew = require(script.Parent:WaitForChild("Crew"))
local Haul = require(script.Parent:WaitForChild("Haul"))
local Bots = require(script.Parent:WaitForChild("Bots"))
local Events = require(script.Parent:WaitForChild("Events"))
local Launch = require(script.Parent:WaitForChild("Launch"))
local Rewards = require(script.Parent:WaitForChild("Rewards"))

local Debug = {}

local defaults: { [string]: any } = {}

local function findPlayer(name: string?): Player?
	if name then
		local lower = string.lower(name)
		for _, p in ipairs(Players:GetPlayers()) do
			if string.lower(p.Name) == lower or string.lower(p.DisplayName) == lower then
				return p
			end
		end
		for _, p in ipairs(Players:GetPlayers()) do
			if string.sub(string.lower(p.Name), 1, #lower) == lower then
				return p
			end
		end
	end
	return nil
end

-- "who" may be a player name, "all", or missing (= everyone).
local function targets(who: string?): { Player }
	if who == nil or who == "all" or who == "" then
		return Players:GetPlayers()
	end
	local p = findPlayer(who)
	return p and { p } or {}
end

local function give(list: { Player }, stat: string, n: number): string
	local out = {}
	for _, p in ipairs(list) do
		local d = Data.get(p)
		if d then
			if stat == "strength" then
				d.strengthEarned = (d.strengthEarned or 0) + n
			elseif stat == "hauled" then
				d.hauled = (d.hauled or 0) + n
				Crew.tag(p)
			elseif stat == "launches" then
				d.launches = (d.launches or 0) + n
			else
				d.coins = (d.coins or 0) + n
			end
			Crew.refresh(p)
			table.insert(out, p.Name)
		end
	end
	return string.format("gave %s %s to %s", tostring(n), stat, #out > 0 and table.concat(out, ", ") or "nobody")
end

local function state(): string
	local filled, total = Rocket.counts()
	local lines = {
		string.format("planet=%s mission=%d phase=%s rocket=%d/%d size=%d skin=%s", Mission.planetInfo().key, Mission.mission, Mission.phase, filled, total, Rocket.size, Rocket.skin),
		string.format("loose=%d bots=%d boost=%ds nextDrop=%ds gravity=%.1f", Haul.count(), Bots.count(), math.max(0, math.floor(Mission.boostUntil - Mission.now())), math.floor(Events.nextDrop - Mission.now()), workspace.Gravity),
	}
	for _, p in ipairs(Players:GetPlayers()) do
		local d = Data.get(p)
		if d then
			local holding = Haul.holdingOf(p)
			table.insert(lines, string.format("%s coins=%d str=%.1f hauled=%d delivered=%d launches=%d gear=%d/%d/%d/%d ftue=%d holding=%s", p.Name, math.floor(tonumber(d.coins) or 0), Crew.strength(p), math.floor(tonumber(d.hauled) or 0), tonumber(d.delivered) or 0, tonumber(d.launches) or 0, tonumber(d.gear.gloves) or 1, tonumber(d.gear.suit) or 1, tonumber(d.gear.jet) or 1, tonumber(d.gear.drones) or 1, tonumber(d.ftue.step) or 0, if holding then holding.kind else "-"))
		end
	end
	return table.concat(lines, "\n")
end

local function run(cmd: string): string
	local args: { string } = {}
	for w in string.gmatch(cmd, "%S+") do
		table.insert(args, w)
	end
	local c = string.lower(args[1] or "")
	if c == "give" then
		-- give 1e6 | give <player> 1e6 | give <player> <stat> <n> | give <stat> <n>
		local a2, a3, a4 = args[2], args[3], args[4]
		local n2 = tonumber(a2 or "")
		if n2 then
			return give(targets(nil), "coins", n2)
		end
		local n3 = tonumber(a3 or "")
		if n3 then
			if a2 == "cash" or a2 == "coins" or a2 == "strength" or a2 == "hauled" or a2 == "launches" then
				return give(targets(nil), a2, n3)
			end
			return give(targets(a2), "coins", n3)
		end
		local stat = string.lower(a3 or "coins")
		if stat == "cash" then
			stat = "coins"
		end
		return give(targets(a2), stat, tonumber(a4 or "") or 0)
	elseif c == "event" or c == "drop" then
		Events.supplyDrop("Debug")
		return "supply drop called (phase " .. Mission.phase .. ")"
	elseif c == "clip" or c == "fill" or c == "launch" then
		Launch.now()
		return "rocket filled; launch sequence starts (phase " .. Mission.phase .. ")"
	elseif c == "planet" then
		local i = math.clamp(tonumber(args[2] or "") or 2, 1, #Config.Planets)
		Haul.clear()
		Bots.clear()
		Mission.setPlanet(i)
		Crew.resetContrib()
		Rocket.build(i, Config.sizeClass(#Players:GetPlayers()))
		Rewards.repaint()
		for k, p in ipairs(Players:GetPlayers()) do
			local r = Crew.root(p)
			local ch = p.Character
			if r and ch then
				r.Anchored = false
				ch:PivotTo(Launch.landingCF(k, #Players:GetPlayers()))
			end
			Crew.invalidate(p)
			Crew.dress(p)
			Crew.refresh(p)
		end
		Bots.sync()
		return "moved to " .. Mission.planetInfo().name
	elseif c == "reset" then
		local list = targets(args[2])
		for _, p in ipairs(list) do
			local d = Data.get(p)
			if d then
				local keep = { passes = d.passes, receipts = d.receipts }
				table.clear(d)
				for k, v in pairs(Data.deepCopy(defaults)) do
					d[k] = v
				end
				d.passes = keep.passes or {}
				d.receipts = keep.receipts or {}
				d.firstJoin = os.time()
				Crew.refresh(p)
				Crew.tag(p)
				Crew.dress(p)
				Crew.applyMovement(p)
			end
		end
		return "reset " .. #list .. " player(s)"
	elseif c == "state" then
		return state()
	elseif c == "rarity" or c == "spawn" then
		local tier = args[2] or "Legendary"
		local l = Haul.spawnAtDepot(tier)
		return l and ("spawned " .. tier .. " " .. l.kind .. " at the depot") or "no open slot"
	elseif c == "fuel" then
		local p = targets(args[2])[1]
		if p then
			Events.fuel(p)
			return "fueled by " .. p.Name
		end
		return "no player"
	elseif c == "boost" then
		Mission.boost(tonumber(args[2] or "") or 60, "Debug")
		Crew.invalidate(nil)
		return "server boost on"
	elseif c == "daily" then
		for _, p in ipairs(targets(args[2])) do
			local d = Data.get(p)
			if d then
				d.daily.last = os.time() - 21 * 3600
				Data.dirty(p)
			end
		end
		return "daily gift ready"
	elseif c == "offline" then
		local hours = tonumber(args[3] or args[2] or "") or 2
		local who: string? = args[2]
		if tonumber(args[2] or "") then
			who = nil
		end
		for _, p in ipairs(targets(who)) do
			local d = Data.get(p)
			if d then
				if (d.gear.drones or 1) < 2 then
					d.gear.drones = 2
				end
				d.lastOnline = os.time() - hours * 3600
				Rewards.offline(p, d)
			end
		end
		return "offline earnings for " .. hours .. " h granted"
	elseif c == "ftue" then
		for _, p in ipairs(targets(args[2])) do
			local d = Data.get(p)
			if d then
				d.ftue = { step = 0, epic = false }
				d.delivered = 0
				Data.dirty(p)
			end
		end
		return "FTUE reset"
	elseif c == "pass" then
		local p = targets(args[2])[1]
		local key = args[3] or "VIP"
		if p then
			Shop.prompt(p, (Config.Passes :: any)[key] and "pass" or "product", key)
			return "prompted " .. key .. " for " .. p.Name
		end
		return "no player"
	elseif c == "bots" then
		Bots.sync()
		return "bots=" .. Bots.count()
	end
	return "unknown command: " .. cmd .. " (give, event, clip, fill, planet, reset, state, rarity, fuel, boost, daily, offline, ftue, pass, bots)"
end

function Debug.init(dataDefaults: { [string]: any })
	defaults = dataDefaults
	if not RunService:IsStudio() then
		return
	end
	local f = Instance.new("BindableFunction")
	f.Name = "DebugCmd"
	f.OnInvoke = function(cmd: any)
		if type(cmd) ~= "string" then
			return "usage: DebugCmd:Invoke(\"state\")"
		end
		local ok, res = pcall(run, cmd)
		if not ok then
			warn("[Debug] " .. cmd .. ": " .. tostring(res))
			return "error: " .. tostring(res)
		end
		return res
	end
	f.Parent = ServerStorage
end

return Debug

-- Studio-only test hooks: ServerStorage.DebugCmd (BindableFunction). Invoke with a command string, get text back.
-- See games/toyarmy/TEST.md for the list. A player argument may be a name prefix or "me"/"all" (default: everyone).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Fmt = require(Shared:WaitForChild("Fmt"))
local Net = require(Shared:WaitForChild("Net"))
local Data = require(script.Parent:WaitForChild("Data"))
local Army = require(script.Parent:WaitForChild("Army"))
local Zones = require(script.Parent:WaitForChild("Zones"))
local Cat = require(script.Parent:WaitForChild("Cat"))
local Commander = require(script.Parent:WaitForChild("Commander"))
local Battle = require(script.Parent:WaitForChild("Battle"))

local Debug = {}

export type Ctx = {
	round: () -> string,
	supply: (Player) -> (),
	refresh: (Player) -> (),
}

local function findPlayers(arg: string?): ({ Player }, boolean)
	local all = Players:GetPlayers()
	if not arg or arg == "" or arg == "all" then
		return all, false
	end
	if arg == "me" then
		return { all[1] }, true
	end
	local out = {}
	for _, p in ipairs(all) do
		if string.lower(string.sub(p.Name, 1, #arg)) == string.lower(arg) then
			table.insert(out, p)
		end
	end
	if #out == 0 then
		return all, false -- not a player name (e.g. "give 1000000"): everyone
	end
	return out, true
end

local function properUnit(s: string?): string?
	if not s then
		return nil
	end
	for _, u in ipairs(Config.Units) do
		if string.lower(u.key) == string.lower(s) or string.lower(u.name) == string.lower(s) then
			return u.key
		end
	end
	return nil
end

local function properMut(s: string?): string
	if not s then
		return ""
	end
	for _, m in ipairs(Config.Mutations) do
		if string.lower(m.key) == string.lower(s) then
			return m.key
		end
	end
	return ""
end

local function run(ctx: Ctx, cmd: string): string
	local args = {}
	for w in string.gmatch(cmd, "%S+") do
		table.insert(args, w)
	end
	local c = string.lower(args[1] or "")
	if c == "give" then
		-- give [player] [plastic|xp|bags|unit] <amount|Unit> [Mut] [count]
		local i = 2
		local targets, matched = findPlayers(args[2])
		if matched then
			i = 3
		elseif args[2] == "all" then
			i = 3
		end
		local what = string.lower(args[i] or "plastic")
		if tonumber(what) then
			what = "plastic"
		else
			i += 1
		end
		local out = {}
		for _, p in ipairs(targets) do
			local d = Data.get(p)
			if d then
				if what == "plastic" or what == "cash" then
					local n = tonumber(args[i]) or 1e6
					Army.addPlastic(p, d, n, { raw = true, kind = "debug" })
				elseif what == "xp" then
					Army.addXp(p, d, tonumber(args[i]) or 1000)
				elseif what == "bags" then
					Army.addTokens(p, d, "Basic", tonumber(args[i]) or 10)
				elseif what == "unit" then
					local u = properUnit(args[i]) or "Tank"
					local m = properMut(args[i + 1])
					local n = tonumber(args[i + 2]) or tonumber(args[i + 1]) or 1
					Army.addUnits(p, d, u, m, n)
				else
					return "give what? plastic | xp | bags | unit"
				end
				table.insert(out, p.Name)
			end
		end
		return "gave " .. what .. " to " .. (#out > 0 and table.concat(out, ", ") or "nobody")
	elseif c == "event" or c == "cat" then
		return Cat.start() and "the cat is coming!" or "the cat is already out"
	elseif c == "clip" then
		return Cat.clip()
	elseif c == "call" then
		local ps = findPlayers(args[2])
		if ps[1] then
			Cat.call(ps[1])
			return "called the cat for " .. ps[1].Name
		end
		return "no player"
	elseif c == "reset" then
		local ps = findPlayers(args[2])
		for _, p in ipairs(ps) do
			local d = Data.get(p)
			if d then
				Zones.removePlayer(p)
				Army.clearBusy(p)
				local fresh = Data.deepCopy(Config.Defaults)
				for k in pairs(d) do
					if k ~= "passes" and k ~= "receipts" and k ~= "firstJoin" and k ~= "sessions" then
						d[k] = nil
					end
				end
				for k, v in pairs(fresh) do
					d[k] = v
				end
				ctx.refresh(p)
				Data.dirty(p)
			end
		end
		return "reset " .. #ps .. " player(s)"
	elseif c == "state" then
		local lines = {}
		for _, def in ipairs(Config.Zones) do
			local zs = Zones.get(def.id)
			if zs and not def.outpost then
				table.insert(lines, string.format("%s=%s(%d,%s)%s", def.id, zs.owner or "-", #zs.garrison, Fmt.num(Battle.power(zs.garrison)), zs.fight and "*" or ""))
			end
		end
		for _, p in ipairs(Players:GetPlayers()) do
			local d = Data.get(p)
			if d then
				table.insert(lines, string.format("%s[%s] plastic=%s units=%d busy=%d tut=%d rank=%d", p.Name, tostring(p:GetAttribute("Side")), Fmt.num(d.plastic), Army.count(d), Army.busyCount(p), d.tut, Army.rank(d)))
			end
		end
		table.insert(lines, Cat.status())
		table.insert(lines, "ai " .. (Commander.isEnabled() and "on" or "off") .. " green=" .. tostring(Commander.mode("Green")) .. " tan=" .. tostring(Commander.mode("Tan")))
		return table.concat(lines, " | ")
	elseif c == "ai" then
		local a = string.lower(args[2] or "")
		if a == "on" or a == "off" then
			Commander.setEnabled(a == "on")
			return "ai " .. a
		end
		local out = {}
		for _, team in ipairs(Config.TeamKeys) do
			local mode = Commander.mode(team) or "full"
			table.insert(out, team .. ": " .. tostring(Commander.act(team, mode)))
		end
		return table.concat(out, ", ")
	elseif c == "zone" then
		local id = args[2] or "rug"
		local team = args[3]
		if team and (team == "none" or team == "-") then
			team = nil
		elseif team then
			team = string.upper(string.sub(team, 1, 1)) .. string.lower(string.sub(team, 2))
		end
		if not Config.ZoneById[id] or (team and not Config.Team[team]) then
			return "zone <rug|chest|tower|fort|desk> <Green|Tan|none>"
		end
		Zones.setOwner(id, team)
		return id .. " -> " .. tostring(team)
	elseif c == "tut" then
		local ps = findPlayers(args[2])
		local n = tonumber(args[3]) or tonumber(args[2]) or Config.TutDone
		for _, p in ipairs(ps) do
			local d = Data.get(p)
			if d then
				d.tut = n
				Data.dirty(p)
			end
		end
		return "tut " .. n
	elseif c == "merge" then
		for _, p in ipairs((findPlayers(args[2]))) do
			local d = Data.get(p)
			if d then
				Army.skipMerges(p, d)
			end
		end
		return "merges finished"
	elseif c == "rank" then
		local ps = findPlayers(args[2])
		local r = math.clamp(tonumber(args[3]) or tonumber(args[2]) or 5, 1, #Config.Ranks)
		for _, p in ipairs(ps) do
			local d = Data.get(p)
			if d then
				d.xp = math.max(d.xp, Config.Ranks[r].xp)
				Data.dirty(p)
			end
		end
		return "rank " .. Config.Ranks[r].name
	elseif c == "topple" then
		Net.event("Topple"):FireAllClients()
		return "tower toppled"
	elseif c == "round" then
		return ctx.round()
	elseif c == "supply" then
		for _, p in ipairs((findPlayers(args[2]))) do
			ctx.supply(p)
		end
		return "supply drop ready"
	elseif c == "daily" then
		for _, p in ipairs((findPlayers(args[2]))) do
			local d = Data.get(p)
			if d then
				d.daily.last = 0
				Data.dirty(p)
			end
		end
		return "daily reset"
	elseif c == "deploy" then
		local ps = findPlayers(args[3])
		local p = ps[1]
		if not p then
			return "no player"
		end
		local ok, why = Zones.deploy(p, args[2] or "rug")
		return tostring(ok) .. " " .. tostring(why)
	elseif c == "help" or c == "" then
		return "give [player] plastic|xp|bags|unit <n|Unit Mut n> · event · clip · call [p] · reset [p] · state · ai on|off|act · zone <id> <team> · tut [p] n · merge [p] · rank [p] n · topple · round · supply [p] · daily [p] · deploy <zone> [p]"
	end
	return "unknown command: " .. c .. " (try help)"
end

function Debug.init(ctx: Ctx)
	if not RunService:IsStudio() then
		return
	end
	local f = Instance.new("BindableFunction")
	f.Name = "DebugCmd"
	f.OnInvoke = function(cmd: string)
		local ok, res = pcall(run, ctx, tostring(cmd or ""))
		if not ok then
			return "error: " .. tostring(res)
		end
		return res
	end
	f.Parent = ServerStorage
end

return Debug

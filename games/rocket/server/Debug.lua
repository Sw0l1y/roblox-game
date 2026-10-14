-- Studio-only test hooks: ServerStorage.DebugCmd (BindableFunction). Invoke with a command string, e.g.
--   give 1e6 | give <player> cash 1e6 | give <player> strength 500 | event | clip | fill | planet 3 | reset <player>
--   state | rarity Legendary | fuel | boost 60 | daily <player> | offline <player> 5 | ftue <player> | pass <player> VIP
--   luck 4 60 | zerog 60 | hourly | tier Galaxy | next Gold | parts 5 | blocked <player> on|off | starter <player>
--   quest <key> 3 | minutes 30
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Data = require(script.Parent:WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local Boosts = require(script.Parent:WaitForChild("Boosts"))
local Live = require(script.Parent:WaitForChild("Live"))
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

local function boostText(): string
	local out = {}
	for _, kind in ipairs({ "coins", "strength", "luck", "train" }) do
		local m = Boosts.mult(kind)
		if m > 1 then
			table.insert(out, string.format("%s=x%s/%ds", kind, tostring(m), math.floor(Boosts.left(kind))))
		end
	end
	return #out > 0 and table.concat(out, " ") or "none"
end

local function marks(p: Player): string
	local m = Crew.marks[p] or {}
	local out = {}
	for _, k in ipairs({ "lift", "reward", "gift" }) do
		table.insert(out, string.format("%s=%s", k, if m[k] then string.format("%.1fs", m[k]) else "-"))
	end
	return table.concat(out, " ")
end

local function state(): string
	local filled, total = Rocket.counts()
	local nextT = Mission.nextTiers[1]
	local lines = {
		string.format("planet=%s mission=%d phase=%s rocket=%d/%d size=%d tier=%s next=%s skin=%s", Mission.planetInfo().key, Mission.mission, Mission.phase, filled, total, Rocket.size, Rocket.tier, nextT and nextT.tier or "roll", Rocket.skin),
		string.format("loose=%d bots=%d boosts=%s nextDrop=%ds gravity=%.1f", Haul.count(), Bots.count(), boostText(), math.floor(Events.nextDrop - Mission.now()), workspace.Gravity),
	}
	for _, p in ipairs(Players:GetPlayers()) do
		local d = Data.get(p)
		if d then
			local holding = Haul.holdingOf(p)
			table.insert(lines, string.format("%s coins=%d str=%.1f hauled=%d delivered=%d launches=%d gear=%d/%d/%d/%d ftue=%d holding=%s", p.Name, math.floor(tonumber(d.coins) or 0), Crew.strength(p), math.floor(tonumber(d.hauled) or 0), tonumber(d.delivered) or 0, tonumber(d.launches) or 0, tonumber(d.gear.gloves) or 1, tonumber(d.gear.suit) or 1, tonumber(d.gear.jet) or 1, tonumber(d.gear.drones) or 1, tonumber(d.ftue.step) or 0, if holding then holding.kind else "-"))
			local live: { [string]: any } = d.live or {}
			local qs = {}
			for _, q: any in ipairs(live.quests or {}) do
				table.insert(qs, string.format("%s %d%s", tostring(q.key), tonumber(q.n) or 0, if q.done then "ok" else ""))
			end
			table.insert(lines, string.format("  ftue %s · spent=%d sessions=%d firstJoin=%ds ago randomBlocked=%s friends=%s ladder=x%s launchCredit=x%d · play=%dmin quests=[%s]", marks(p), tonumber(d.spent) or 0, tonumber(d.sessions) or 0, os.time() - (tonumber(d.firstJoin) or os.time()), tostring(p:GetAttribute("RandomBlocked")), tostring(p:GetAttribute("Friends")), tostring(Crew.ladderMult(p, d)), Crew.launchMult(p), tonumber(live.minutes) or 0, table.concat(qs, ", ")))
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
		local secs = tonumber(args[2] or "") or 60
		Boosts.add("coins", 2, secs, "Debug")
		Boosts.add("strength", 2, secs, "Debug")
		Crew.invalidate(nil)
		return "server 2x coins + strength on: " .. boostText()
	elseif c == "luck" then
		Boosts.add("luck", tonumber(args[2] or "") or 2, tonumber(args[3] or "") or 60, "Debug")
		return "luck on: " .. boostText()
	elseif c == "zerog" then
		Boosts.add("train", Config.Tune.zeroGMult, tonumber(args[2] or "") or 60, "Debug")
		return "zero-g on: " .. boostText()
	elseif c == "hourly" then
		Events.hourly()
		return "hourly event: " .. boostText()
	elseif c == "tier" then
		local tier = Config.rocketTier(args[2] or "Galaxy")
		if not Mission.inBuild() then
			return "only during the build phase"
		end
		Haul.clear()
		Crew.resetContrib()
		Rocket.build(Mission.planet, Rocket.size, tier.key)
		Rewards.repaint()
		Bots.sync()
		return "rebuilt the rocket as " .. tier.key
	elseif c == "next" then
		local tier = Config.rocketTier(args[2] or "Gold")
		Mission.queueTier(tier.key, "Debug")
		return "queued next rocket " .. tier.key
	elseif c == "parts" then
		local p = Players:GetPlayers()[1]
		if p then
			Events.parts(p, tonumber(args[2] or "") or 3)
			return "parts drop sent"
		end
		return "no player"
	elseif c == "blocked" then
		-- test the paid-random restriction path: blocked <player> on|off
		local on = args[3] ~= "off"
		for _, p in ipairs(targets(args[2])) do
			p:SetAttribute("RandomBlocked", on)
		end
		return "RandomBlocked=" .. tostring(on)
	elseif c == "starter" then
		-- reopen the 10-minute first-session Starter Pack window
		for _, p in ipairs(targets(args[2])) do
			local d = Data.get(p)
			if d then
				d.firstJoin = os.time()
				d.sessions = 1
				d.starter = false
				if d.bought then
					d.bought.StarterPack = nil
				end
				Data.dirty(p)
			end
		end
		return "starter window reopened"
	elseif c == "quest" then
		local key = args[2] or "parts"
		local n = tonumber(args[3] or "") or 1
		for _, p in ipairs(Players:GetPlayers()) do
			Live.quest(p, key, n)
		end
		return "quest " .. key .. " +" .. n
	elseif c == "minutes" then
		local n = tonumber(args[2] or "") or 60
		for _, p in ipairs(Players:GetPlayers()) do
			local d = Data.get(p) :: any
			if d and type(d.live) == "table" then
				d.live.minutes = n
				Data.dirty(p)
			end
		end
		return "playtime set to " .. n .. " min"
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
	return "unknown command: " .. cmd .. " (give, event, clip, fill, planet, reset, state, rarity, fuel, boost, luck, zerog, hourly, tier, next, parts, blocked, starter, quest, minutes, daily, offline, ftue, pass, bots)"
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

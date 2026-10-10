-- Studio-only test commands: ServerStorage.DebugCmd (BindableFunction). Invoke with a string, get text back.
-- Player argument is optional (first player); "me" also means the first player. See TEST.md for the list.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Fmt = require(Shared:WaitForChild("Fmt"))
local Config = require(Shared:WaitForChild("Config"))
local Econ = require(Shared:WaitForChild("Econ"))
local Data = require(script.Parent:WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local Progress = require(script.Parent:WaitForChild("Progress"))
local Balloons = require(script.Parent:WaitForChild("Balloons"))
local Mega = require(script.Parent:WaitForChild("Mega"))

local Debug = {}

local function findPlayer(name: string?): Player?
	local all = Players:GetPlayers()
	if not name or name == "" or name == "me" then
		return all[1]
	end
	local lower = string.lower(name)
	for _, p in ipairs(all) do
		if string.sub(string.lower(p.Name), 1, #lower) == lower or string.sub(string.lower(p.DisplayName), 1, #lower) == lower then
			return p
		end
	end
	return nil
end

-- Split "give bob coins 1e6" into words; if the second word is not a player name, the player is the first one.
local function target(words: { string }, at: number): (Player?, number)
	local p = words[at] and findPlayer(words[at])
	if p and tonumber(words[at]) == nil then
		return p, at + 1
	end
	return findPlayer(nil), at
end

local function state(): string
	local lines = {}
	local n, perZone = 0, {}
	for _, b in pairs(Balloons.all()) do
		n += 1
		perZone[b.zone] = (perZone[b.zone] or 0) + 1
	end
	table.insert(lines, string.format("balloons=%d (meadow %d, candy %d, sky %d, space %d) %s", n, perZone[1] or 0, perZone[2] or 0, perZone[3] or 0, perZone[4] or 0, Mega.summary()))
	for _, p in ipairs(Players:GetPlayers()) do
		local d = Data.get(p)
		if d then
			local idx = 0
			for _ in pairs(d.index or {}) do
				idx += 1
			end
			local coins: number = tonumber(d.coins) or 0
			local pump: number = tonumber(d.pump) or 0
			table.insert(lines, string.format(
				"%s: coins=%s pops=%s zones=%s rebirths=%s power=%s luck=%.2f aura=%.1f megaDarts=%s pump=%s index=%d zone=%d",
				p.Name, Fmt.num(coins), tostring(d.pops or 0), tostring(d.zones or 1), tostring(d.rebirths or 0),
				Fmt.num(Econ.power(d)), Econ.luck(d, os.time()), Econ.auraRadius(d), tostring(d.megaDarts or 0),
				Fmt.num(pump), idx, Progress.zoneOf(p)
			))
		end
	end
	return table.concat(lines, "\n")
end

local function run(cmd: string): string
	local words = {}
	for w in string.gmatch(cmd, "%S+") do
		table.insert(words, w)
	end
	local c = string.lower(words[1] or "")
	if c == "state" then
		return state()
	elseif c == "event" then
		Mega.start(5, nil)
		return "MEGA BALLOON countdown started (5 s)"
	elseif c == "clip" then
		Mega.clip()
		return "MEGA BALLOON forced to pop in 1.5 s (coin rain + rare shower)"
	elseif c == "help" then
		return "give [player] [coins|megadarts|pops] n | event | clip | reset [player] | state | spawn key [player] | rare [player] | zones [player] n | index [player] | upgrade [player] key n | rebirth [player] | daily [player] | pump [player] seconds | luck [player] minutes | tp [player] zone | pass [player] key | buy [player] key"
	end
	local p, i = target(words, 2)
	if not p then
		return "no player"
	end
	local d = Data.get(p)
	if not d then
		return "no data for " .. p.Name
	end
	if c == "give" then
		local kind = "coins"
		local amount: number = tonumber(words[i]) or 0
		if not tonumber(words[i]) then
			kind = string.lower(words[i] or "coins")
			amount = tonumber(words[i + 1]) or 1000000
		end
		if kind == "coins" or kind == "cash" then
			Progress.addCoins(p, d, amount)
		elseif kind == "megadarts" or kind == "darts" then
			d.megaDarts = (d.megaDarts or 0) + amount
		elseif kind == "pops" then
			d.pops = (d.pops or 0) + amount
		else
			return "unknown kind " .. kind
		end
		Progress.touch(p)
		return string.format("gave %s %s %s", p.Name, Fmt.num(amount), kind)
	elseif c == "reset" then
		for k in pairs(d) do
			if k ~= "passes" and k ~= "receipts" then
				d[k] = nil
			end
		end
		for k, v in pairs(Data.deepCopy(Config.Defaults)) do
			d[k] = v
		end
		Progress.touch(p)
		Progress.applyStats(p)
		return "reset " .. p.Name
	elseif c == "spawn" then
		local key = words[2]
		if key and Config.Balloons[key] then
			local who = findPlayer(words[3]) or p
			local b = Balloons.spawnNear(who, key, 10)
			return b and ("spawned " .. key .. " #" .. b.id) or "could not spawn"
		end
		return "unknown balloon; keys: " .. table.concat(Config.Order, ", ")
	elseif c == "rare" then
		local zone = math.max(1, Econ.zoneAt((Progress.root(p) :: BasePart).Position))
		local b = Balloons.spawnNear(p, Config.ZoneTypes[zone][7], 12)
		return b and ("spawned the secret " .. b.key) or "could not spawn"
	elseif c == "zones" then
		d.zones = math.clamp(tonumber(words[i]) or #Config.Zones, 1, #Config.Zones)
		Progress.touch(p)
		return "zones=" .. d.zones
	elseif c == "index" then
		for _, key in ipairs(Config.Order) do
			if Config.Balloons[key].tier ~= "Secret" then
				d.index[key] = math.max(1, d.index[key] or 0)
			end
		end
		Progress.touch(p)
		return "filled the index (no secrets)"
	elseif c == "upgrade" then
		local key = words[i]
		local u = key and Config.Upgrades[key]
		if not u then
			return "keys: " .. table.concat(Config.UpgradeOrder, ", ")
		end
		d.up[key] = math.clamp(tonumber(words[i + 1]) or u.max, 0, u.max)
		Progress.touch(p)
		Progress.applyStats(p)
		return key .. "=" .. d.up[key]
	elseif c == "rebirth" then
		d.coins = Econ.rebirthCost(d.rebirths or 0)
		Progress.actions.rebirth(p, nil)
		return "rebirths=" .. d.rebirths
	elseif c == "daily" then
		d.daily.last = 0
		Progress.touch(p)
		return "daily gift ready"
	elseif c == "pump" then
		local secs = tonumber(words[i]) or 3600
		d.pump = math.min(Econ.pumpCap(d), (d.pump or 0) + Econ.pumpRate(d) * secs)
		return "pump=" .. Fmt.num(d.pump)
	elseif c == "luck" then
		d.luckUntil = os.time() + (tonumber(words[i]) or 15) * 60
		Progress.touch(p)
		return "luck boost on"
	elseif c == "tp" then
		Progress.teleport(p, math.clamp(tonumber(words[i]) or 1, 1, #Config.Zones))
		return "teleported"
	elseif c == "pass" then
		local key = words[i]
		if key and Config.Passes[key] then
			d.passes = d.passes or {}
			d.passes[key] = true
			Progress.touch(p)
			Progress.applyStats(p)
			return "granted pass " .. key
		end
		return "passes: Coins2x, Aura, Lucky, VIP, GoldenDart"
	elseif c == "buy" then
		-- the real purchase path (Shop.prompt): in Studio an id-0 item is a simulated purchase with the real grant
		local key = words[i]
		local kind = key and ((Config.Passes[key] and "pass") or (Config.Products[key] and "product")) or nil
		if not key or not kind then
			return "buy <key>: passes Coins2x Aura Lucky VIP GoldenDart; products MegaDarts LuckBoost SummonMega Starter Coins1 Coins2 Coins3"
		end
		Shop.prompt(p, kind, key)
		return "bought " .. kind .. " " .. key .. " for " .. p.Name
	end
	return "unknown command (try help)"
end

function Debug.init()
	if not RunService:IsStudio() then
		return
	end
	local f = Instance.new("BindableFunction")
	f.Name = "DebugCmd"
	f.OnInvoke = function(cmd: any)
		local ok, res = pcall(run, tostring(cmd))
		if not ok then
			return "error: " .. tostring(res)
		end
		return res
	end
	f.Parent = ServerStorage
end

return Debug

-- The AI commander fills an empty team (solo or lopsided servers) so there is always an opponent.
-- It scales to the humans it faces: its squads are built from the human team's best squad power times a
-- "mood" that rubber-bands on the zone count (holding more zones makes it ease off, fewer makes it push).
-- It never garrisons a zone above what the humans can beat, and it leaves zones of brand-new players alone.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Data = require(script.Parent:WaitForChild("Data"))
local Battle = require(script.Parent:WaitForChild("Battle"))
local Army = require(script.Parent:WaitForChild("Army"))
local Zones = require(script.Parent:WaitForChild("Zones"))

local Commander = {}

local rng = Random.new()
local nextAct: { [string]: number } = { Green = 0, Tan = 0 }
local firstHuman: number? = nil
local enabled = true

function Commander.setEnabled(on: boolean)
	enabled = on
end

function Commander.isEnabled(): boolean
	return enabled
end

-- Humans who played in the last few minutes (AFK players do not count, so the AI fills in for them).
local function humans(team: string): number
	local n = 0
	local now = workspace:GetServerTimeNow()
	for _, p in ipairs(Players:GetPlayers()) do
		local at = p:GetAttribute("ActiveAt")
		if p:GetAttribute("Side") == team and type(at) == "number" and now - at < 240 then
			n += 1
		end
	end
	return n
end

-- "full" when the team has nobody, "assist" when it is outnumbered, nil otherwise.
function Commander.mode(team: string): string?
	local mine, theirs = humans(team), humans(Config.enemy(team))
	if theirs == 0 then
		return nil
	end
	if mine == 0 then
		return "full"
	elseif mine < theirs then
		return "assist"
	end
	return nil
end

local function refPower(team: string): number
	local enemies = Army.teamPlayers(Config.enemy(team))
	if #enemies == 0 then
		return 60
	end
	local sum = 0
	for _, p in ipairs(enemies) do
		local d = Data.get(p)
		if d then
			sum += Army.squadPower(p, d)
		end
	end
	return math.max(45, sum / #enemies)
end

local function protected(zs: Zones.ZoneState): boolean
	for _, u in ipairs(zs.garrison) do
		local o = u.owner
		if o then
			local d = Data.get(o)
			if d and (d.tut or 1) < Config.AI.protectTut then
				return true
			end
		end
	end
	return false
end

function Commander.act(team: string, mode: string): string?
	local ref = refPower(team)
	local mine, theirs = Zones.count(team), Zones.count(Config.enemy(team))
	local mood = 0.75
	if mine > theirs + 1 then
		mood = 0.5
	elseif mine < theirs then
		mood = 0.95
	end
	if mode == "assist" then
		mood *= 0.7
	end
	local budget = ref * mood * rng:NextNumber(0.85, 1.15)
	local name = Config.Team[team].ai

	type Option = { zs: Zones.ZoneState, kind: string, weight: number }
	local options: { Option } = {}
	for _, zs in ipairs(Zones.real()) do
		if not zs.fight then
			if zs.owner == team then
				if #zs.garrison < zs.def.cap and Zones.garrisonPower(zs) < ref * 0.85 then
					table.insert(options, { zs = zs, kind = "reinforce", weight = 0.8 })
				end
			elseif not protected(zs) then
				local defP = Zones.garrisonPower(zs)
				local w = defP < budget * 0.95 and (2 + zs.def.tier) or 0.35
				if zs.owner == nil then
					w *= 1.3
				end
				table.insert(options, { zs = zs, kind = "attack", weight = w })
			end
		end
	end
	if #options == 0 then
		return nil
	end
	local total = 0
	for _, o in ipairs(options) do
		total += o.weight
	end
	local r = rng:NextNumber() * total
	local pick = options[#options]
	for _, o in ipairs(options) do
		r -= o.weight
		if r <= 0 then
			pick = o
			break
		end
	end
	local zs = pick.zs
	local squad
	if pick.kind == "reinforce" then
		local room = zs.def.cap - #zs.garrison
		local b = math.min(budget * 0.6, ref * 0.85 - Zones.garrisonPower(zs))
		if b < 15 then
			return nil
		end
		squad = Battle.compose(b, math.min(room, 3), "AI", team, name, 1)
	else
		squad = Battle.compose(budget, Config.AI.maxUnits, "AI", team, name, 1)
	end
	if Zones.deployAI(team, zs.def.id, squad) then
		if pick.kind == "attack" then
			Army.feed("🤖 " .. name .. " attacks " .. zs.def.name .. "!", team == "Green" and "green" or "orange")
		end
		return pick.kind .. " " .. zs.def.id
	end
	return nil
end

function Commander.init()
	task.spawn(function()
		while true do
			task.wait(1)
			if #Players:GetPlayers() > 0 then
				firstHuman = firstHuman or os.clock()
			else
				firstHuman = nil
			end
			local started = firstHuman ~= nil and os.clock() - (firstHuman :: number) >= Config.AI.startDelay
			if enabled and started then
				for _, team in ipairs(Config.TeamKeys) do
					local mode = Commander.mode(team)
					if mode and os.clock() >= nextAct[team] then
						local iv = mode == "full" and Config.AI.interval or Config.AI.assistInterval
						nextAct[team] = os.clock() + rng:NextNumber(iv[1], iv[2])
						local ok, err = pcall(Commander.act, team, mode)
						if not ok then
							warn("[Commander]", err)
						end
					end
				end
			end
		end
	end)
end

return Commander

-- Crew bots. Small servers (1-3 players) get NPC crew bots and every Robot Crew pass owner gets 2 robots.
-- Bots never haul on their own: they run to parts players are lifting (heavy ones and "Need a hand!" pings
-- first), add their strength, and follow the owner otherwise. The server keeps their logic; clients draw them
-- from ReplicatedStorage.Bots (walk segments From -> To at Speed since T0, or attached to a part at Off).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Parts = require(Shared:WaitForChild("Parts"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local Mission = require(script.Parent:WaitForChild("Mission"))
local Crew = require(script.Parent:WaitForChild("Crew"))
local Haul = require(script.Parent:WaitForChild("Haul"))

local Bots = {}

local T = Config.Tune

type Bot = {
	id: string,
	owner: Player?,
	cfg: Configuration,
	mode: string, -- "walk" | "hold" | "idle"
	part: string?,
	from: Vector3,
	to: Vector3,
	t0: number,
	speed: number,
	off: Vector3,
	slot: number,
}

local bots: { [string]: Bot } = {}
local nextId = 0
local rng = Random.new()

local folder = Instance.new("Folder")
folder.Name = "Bots"
folder.Parent = ReplicatedStorage

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function posOf(b: Bot): Vector3
	if b.mode == "hold" and b.part then
		local l = Haul.parts[b.part]
		if l then
			return l.pos + b.off
		end
	end
	if b.mode == "walk" then
		local d = b.to - b.from
		local len = d.Magnitude
		if len < 0.01 then
			return b.to
		end
		local t = math.min(len, (Mission.now() - b.t0) * b.speed)
		return b.from + d.Unit * t
	end
	return b.to
end

local function push(b: Bot)
	b.cfg:SetAttribute("Mode", b.mode)
	b.cfg:SetAttribute("From", b.from)
	b.cfg:SetAttribute("To", b.to)
	b.cfg:SetAttribute("T0", b.t0)
	b.cfg:SetAttribute("Speed", b.speed)
	b.cfg:SetAttribute("Part", b.part or "")
	b.cfg:SetAttribute("Off", b.off)
end

local function walkTo(b: Bot, dest: Vector3)
	local here = posOf(b)
	if b.mode == "walk" and (b.to - dest).Magnitude < 3 then
		return
	end
	if b.mode ~= "walk" and (here - dest).Magnitude < 2 then
		if b.mode ~= "idle" then
			b.mode = "idle"
			b.to = here
			push(b)
		end
		return
	end
	b.mode = "walk"
	b.from = here
	b.to = dest
	b.t0 = Mission.now()
	b.speed = T.botSpeed
	push(b)
end

local function strengthOf(b: Bot): number
	local base = T.botStrength * Mission.weightMult()
	if b.owner then
		return math.max(T.robotStrength * Mission.weightMult(), Crew.strength(b.owner) * 0.5)
	end
	return base
end

local function make(owner: Player?, slot: number): Bot
	nextId += 1
	local id = "B" .. nextId
	local cfg = Instance.new("Configuration")
	cfg.Name = id
	cfg:SetAttribute("Owner", owner and owner.UserId or 0)
	cfg:SetAttribute("Name", owner and (owner.DisplayName .. "'s Robot") or "Crew Bot")
	local home = Mission.area().botHome + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))
	if owner then
		local r = Crew.root(owner)
		if r then
			home = Vector3.new(r.Position.X, Mission.area().origin.Y, r.Position.Z) + Vector3.new(rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5))
		end
	end
	local b: Bot = {
		id = id,
		owner = owner,
		cfg = cfg,
		mode = "idle",
		part = nil,
		from = home,
		to = home,
		t0 = Mission.now(),
		speed = T.botSpeed,
		off = Vector3.zero,
		slot = slot,
	}
	push(b)
	cfg.Parent = folder
	bots[id] = b
	return b
end

local function destroy(b: Bot)
	if b.part then
		Haul.removeBot(b.part, b.id)
	end
	bots[b.id] = nil
	b.cfg:Destroy()
end

function Bots.clear()
	for _, b in pairs(bots) do
		destroy(b)
	end
end

-- Keep the right number of crew bots and robot-crew bots.
function Bots.sync()
	if not Mission.inBuild() then
		return
	end
	local players = Players:GetPlayers()
	local wantCrew = T.soloBots[#players] or 0
	local crew: { Bot } = {}
	local owned: { [Player]: number } = {}
	for _, b in pairs(bots) do
		local o = b.owner
		if o then
			if o.Parent == nil or not Shop.owns(o, "RobotCrew") then
				destroy(b)
			else
				owned[o] = (owned[o] or 0) + 1
			end
		else
			table.insert(crew, b)
		end
	end
	for i = #crew, wantCrew + 1, -1 do
		destroy(crew[i])
	end
	for i = #crew + 1, wantCrew do
		make(nil, i)
	end
	for _, p in ipairs(players) do
		if Shop.owns(p, "RobotCrew") then
			for i = (owned[p] or 0) + 1, 2 do
				make(p, i)
			end
		end
	end
end

local function attach(b: Bot, l: Haul.Loose): boolean
	if not Haul.addBot(l.id, b.id, strengthOf(b)) then
		return false
	end
	b.mode = "hold"
	b.part = l.id
	-- spread bots around the part
	local n = 0
	for _ in pairs(l.bots) do
		n += 1
	end
	local a = n * 2.1 + rng:NextNumber(-0.3, 0.3)
	local r = Parts.halfWidth(l.kind, l.scale) + 1.6
	b.off = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	push(b)
	return true
end

local function score(b: Bot, l: Haul.Loose, here: Vector3): number?
	if l.mode ~= "carry" or #l.holders == 0 or Haul.botSlots(l) <= 0 then
		return nil
	end
	local now = Mission.now()
	local s = (flat(l.pos) - flat(here)).Magnitude
	if b.owner then
		if table.find(l.holders, b.owner) then
			return s - 1000
		end
		if now - l.helpAt < 12 then
			return s - 150
		end
		return nil
	end
	local ratio = l.str / l.weight
	if now - l.helpAt < 12 then
		s -= 300
	end
	if l.speed <= 0 then
		s -= 200
	elseif ratio > 2.5 then
		return nil
	end
	return s
end

local function think(b: Bot)
	local here = posOf(b)
	if b.mode == "hold" then
		local l = b.part and Haul.parts[b.part]
		if l and l.mode == "carry" and l.bots[b.id] then
			-- owner bots hop to their owner's part if the owner switched
			if b.owner and not table.find(l.holders, b.owner) then
				local ol = Haul.holdingOf(b.owner)
				if ol and ol ~= l then
					Haul.removeBot(l.id, b.id)
					b.part = nil
					b.mode = "idle"
					b.to = here
					push(b)
				end
			end
			return
		end
		b.part = nil
		b.mode = "idle"
		b.to = here
		b.from = here
		push(b)
	end
	-- choose the best part to help with
	local best: Haul.Loose? = nil
	local bestScore = math.huge
	for _, l in pairs(Haul.parts) do
		local sc = score(b, l, here)
		if sc and sc < bestScore then
			best, bestScore = l, sc
		end
	end
	if best then
		local dest = best.pos
		local half = Parts.halfWidth(best.kind, best.scale)
		if (flat(here) - flat(dest)).Magnitude <= half + 4 then
			if attach(b, best) then
				return
			end
		end
		local dir = flat(here) - flat(dest)
		local approach = dest + (dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0)) * (half + 1.5)
		walkTo(b, approach)
		return
	end
	-- idle: follow the owner, or the nearest player, or wait by the depot
	local target: Vector3 = Mission.area().botHome
	local follow: Player? = b.owner
	if not follow then
		local nearest = math.huge
		for _, p in ipairs(Players:GetPlayers()) do
			local r = Crew.root(p)
			if r then
				local d = (flat(r.Position) - flat(here)).Magnitude
				if d < nearest then
					nearest = d
					follow = p
				end
			end
		end
	end
	if follow then
		local r = Crew.root(follow)
		if r then
			local ang = b.slot * 2.2 + (b.owner and 0.6 or 0)
			target = Vector3.new(r.Position.X, Mission.area().origin.Y, r.Position.Z) + Vector3.new(math.cos(ang) * 5, 0, math.sin(ang) * 5)
		end
	end
	local o = flat(Mission.area().origin)
	if (flat(target) - o).Magnitude > Mission.area().playRadius then
		target = Mission.area().botHome
	end
	if (flat(here) - flat(target)).Magnitude > 7 or b.mode == "walk" then
		walkTo(b, target)
	end
end

function Bots.count(): number
	local n = 0
	for _ in pairs(bots) do
		n += 1
	end
	return n
end

function Bots.init()
	Players.PlayerAdded:Connect(function()
		task.wait(2)
		Bots.sync()
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(Bots.sync)
	end)
	Haul.onHelp(function(l)
		-- answer pings right away
		for _, b in pairs(bots) do
			if b.mode ~= "hold" then
				task.spawn(think, b)
			end
		end
		local _ = l
	end)
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(0.25)
			tick += 1
			if Mission.inBuild() then
				for _, b in pairs(bots) do
					local ok, err = pcall(think, b)
					if not ok then
						warn("[Bots]", err)
					end
				end
				if tick % 20 == 0 then
					Bots.sync()
				end
			end
		end
	end)
end

return Bots

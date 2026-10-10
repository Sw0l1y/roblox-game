-- Team lift. Loose parts live as server data mirrored into ReplicatedStorage.Loose (one Configuration each);
-- clients draw them. Lifting adds you as a holder; haul speed = Config.haulSpeed(total strength / weight)
-- and every holder walks at that speed, so heavy parts need friends (or crew bots). The server follows the
-- holders' centroid with a speed cap (no teleport hauling), lets go of anyone who strays, and bolts the part
-- on when it reaches the pad's bolt zone.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local Parts = require(Shared:WaitForChild("Parts"))
local Data = require(script.Parent:WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local Mission = require(script.Parent:WaitForChild("Mission"))
local Rocket = require(script.Parent:WaitForChild("Rocket"))
local Crew = require(script.Parent:WaitForChild("Crew"))

local Haul = {}

local T = Config.Tune

export type Loose = {
	id: string,
	kind: string,
	tier: string,
	weight: number,
	scale: number,
	cap: number,
	slot: number?,
	star: boolean,
	pad: number?,
	ftue: boolean,
	pos: Vector3, -- ground position of the part's centre
	yaw: number,
	holders: { Player },
	bots: { [string]: number },
	mode: string, -- "rest" | "carry"
	speed: number,
	str: number,
	cfg: Configuration,
	born: number,
	helpAt: number,
	pinged: boolean,
}

Haul.parts = {} :: { [string]: Loose }
local holding: { [Player]: Loose } = {}
local padReady: { [number]: number } = {}
local nextId = 0
local rng = Random.new()
local helpListeners: { (Loose, Player) -> () } = {}
local deliverListeners: { (Loose, { Player }) -> () } = {}

local folder = Instance.new("Folder")
folder.Name = "Loose"
folder.Parent = ReplicatedStorage

local LIGHT_KINDS = { "nose", "tip", "deck", "fin" }

function Haul.onHelp(fn: (Loose, Player) -> ())
	table.insert(helpListeners, fn)
end

function Haul.onDeliver(fn: (Loose, { Player }) -> ())
	table.insert(deliverListeners, fn)
end

function Haul.holdingOf(player: Player): Loose?
	return holding[player]
end

local function botCount(l: Loose): number
	local n = 0
	for _ in pairs(l.bots) do
		n += 1
	end
	return n
end

local function totalStrength(l: Loose): number
	local s = 0
	for _, p in ipairs(l.holders) do
		s += Crew.strength(p)
	end
	for _, bs in pairs(l.bots) do
		s += bs
	end
	return s
end

local function sync(l: Loose)
	local ids = {}
	for _, p in ipairs(l.holders) do
		table.insert(ids, tostring(p.UserId))
	end
	local bids = {}
	for b in pairs(l.bots) do
		table.insert(bids, b)
	end
	l.cfg:SetAttribute("Mode", l.mode)
	l.cfg:SetAttribute("Rest", l.pos)
	l.cfg:SetAttribute("Yaw", l.yaw)
	l.cfg:SetAttribute("Holders", table.concat(ids, ","))
	l.cfg:SetAttribute("Bots", table.concat(bids, ","))
	l.cfg:SetAttribute("Str", math.floor(l.str * 10) / 10)
	l.cfg:SetAttribute("Speed", l.speed)
end

local function recompute(l: Loose)
	l.str = totalStrength(l)
	l.speed = l.mode == "carry" and Config.haulSpeed(l.str / l.weight) or 0
	for _, p in ipairs(l.holders) do
		Crew.setCarrySpeed(p, l.speed)
	end
	sync(l)
end

-- Spawning ------------------------------------------------------------------------------------------------

export type SpawnOpts = { slot: number?, star: boolean?, pad: number?, ftue: boolean?, yaw: number? }

function Haul.spawn(kind: string, tier: string, pos: Vector3, opts: SpawnOpts?): Loose
	local o: SpawnOpts = opts or ({} :: SpawnOpts)
	nextId += 1
	local id = "L" .. nextId
	local k = Config.Kinds[kind]
	local weight = math.floor(k.weight * Config.rarity(tier).mass * Mission.weightMult() * 10 + 0.5) / 10
	local scale = Rocket.layout and Rocket.layout.scale or 1
	local yaw = o.yaw or (k.lie and math.rad(90) or rng:NextNumber(0, math.pi * 2))
	local cfg = Instance.new("Configuration")
	cfg.Name = id
	local l: Loose = {
		id = id,
		kind = kind,
		tier = tier,
		weight = weight,
		scale = scale,
		cap = k.holders,
		slot = o.slot,
		star = o.star == true,
		pad = o.pad,
		ftue = o.ftue == true,
		pos = Vector3.new(pos.X, Mission.area().origin.Y, pos.Z),
		yaw = yaw,
		holders = {},
		bots = {},
		mode = "rest",
		speed = 0,
		str = 0,
		cfg = cfg,
		born = Mission.now(),
		helpAt = 0,
		pinged = false,
	}
	cfg:SetAttribute("Kind", kind)
	cfg:SetAttribute("Tier", tier)
	cfg:SetAttribute("Weight", weight)
	cfg:SetAttribute("Scale", scale)
	cfg:SetAttribute("Cap", l.cap)
	cfg:SetAttribute("Star", l.star)
	cfg:SetAttribute("Slot", o.slot or 0)
	cfg:SetAttribute("Ftue", l.ftue)
	cfg:SetAttribute("Born", l.born)
	cfg:SetAttribute("HelpAt", 0)
	sync(l)
	cfg.Parent = folder
	Haul.parts[id] = l
	if o.slot then
		Rocket.reserve(o.slot, id)
	end
	return l
end

local function release(player: Player, l: Loose)
	local idx = table.find(l.holders, player)
	if idx then
		table.remove(l.holders, idx)
	end
	if holding[player] == l then
		holding[player] = nil
	end
	Crew.setCarrySpeed(player, nil)
	if #l.holders == 0 then
		-- nobody left: the part rests where it is and the bots let go too
		l.mode = "rest"
		table.clear(l.bots)
		l.pinged = false
	end
	recompute(l)
end

function Haul.remove(l: Loose)
	for _, p in ipairs(table.clone(l.holders)) do
		if holding[p] == l then
			holding[p] = nil
		end
		Crew.setCarrySpeed(p, nil)
	end
	table.clear(l.holders)
	if l.slot then
		Rocket.unreserve(l.slot, l.id)
	end
	Haul.parts[l.id] = nil
	l.cfg:Destroy()
end

function Haul.clear()
	for _, l in pairs(Haul.parts) do
		Haul.remove(l)
	end
	table.clear(padReady)
end

-- Lifting ------------------------------------------------------------------------------------------------

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function Haul.help(player: Player, auto: boolean?)
	local l = holding[player]
	if not l then
		return
	end
	if not auto and not Net.allow(player, "help", 4) then
		return
	end
	l.helpAt = Mission.now()
	l.cfg:SetAttribute("HelpAt", l.helpAt)
	Mission.fireAll("help", {
		id = l.id,
		name = player.DisplayName,
		uid = player.UserId,
		kind = l.kind,
		pos = l.pos,
		need = math.max(0, math.ceil(l.weight * T.minRatio - l.str)),
	})
	for _, fn in ipairs(helpListeners) do
		task.spawn(fn, l, player)
	end
end

function Haul.lift(player: Player, id: string)
	if not Mission.inBuild() then
		return
	end
	local l = Haul.parts[id]
	if not l then
		return
	end
	local cur = holding[player]
	if cur == l then
		Haul.drop(player)
		return
	end
	local root = Crew.root(player)
	if not root then
		return
	end
	local reach = T.liftRange + Parts.halfWidth(l.kind, l.scale)
	if (flat(root.Position) - flat(l.pos)).Magnitude > reach + 2 then
		Shop.notify(player, "Get closer to lift it!", "orange")
		return
	end
	if #l.holders + botCount(l) >= l.cap then
		-- make room for a player by sending one bot away
		local kick = next(l.bots)
		if kick and #l.holders < l.cap then
			l.bots[kick] = nil
		else
			Shop.notify(player, "No room! " .. l.cap .. " lifters max.", "orange")
			return
		end
	end
	if cur then
		release(player, cur)
	end
	table.insert(l.holders, player)
	holding[player] = l
	if l.mode ~= "carry" then
		l.mode = "carry"
	end
	if l.pad then
		padReady[l.pad] = os.clock() + T.depotDelay
		l.pad = nil
		l.cfg:SetAttribute("Pad", 0)
	end
	if l.ftue then
		l.ftue = false
		l.cfg:SetAttribute("Ftue", false)
	end
	local d = Data.get(player)
	if d and (d.ftue.step or 0) < 1 then
		d.ftue.step = 1
		Data.dirty(player)
	end
	recompute(l)
	if l.speed <= 0 and not l.pinged then
		l.pinged = true
		Haul.help(player, true)
	end
end

function Haul.drop(player: Player)
	local l = holding[player]
	if l then
		release(player, l)
	end
end

function Haul.addBot(id: string, botId: string, strength: number): boolean
	local l = Haul.parts[id]
	if not l or l.mode ~= "carry" or #l.holders == 0 then
		return false
	end
	if l.bots[botId] then
		return true
	end
	if #l.holders + botCount(l) >= l.cap then
		return false
	end
	l.bots[botId] = strength
	recompute(l)
	return true
end

function Haul.removeBot(id: string, botId: string)
	local l = Haul.parts[id]
	if l and l.bots[botId] then
		l.bots[botId] = nil
		recompute(l)
	end
end

function Haul.botSlots(l: Loose): number
	return l.cap - #l.holders - botCount(l)
end

-- Delivery -------------------------------------------------------------------------------------------------

local function questReward(player: Player, d: { [string]: any })
	local key = Config.dateKey(os.time())
	local q = d.quest
	if q.date ~= key then
		q.date = key
		q.count = 0
		q.claimed = false
	end
	q.count += 1
	if q.count >= T.questTarget and not q.claimed then
		q.claimed = true
		local coins = Crew.addCoins(player, 1200 * Mission.coinMult())
		d.boostUntil = math.max(d.boostUntil or 0, os.time()) + T.potionSeconds
		Crew.invalidate(player)
		Mission.fire(player, "quest", { coins = coins })
	end
end

local function reward(player: Player, l: Loose, share: number, crateBonus: number)
	local d = Data.get(player)
	if not d then
		return
	end
	local coins = Config.deliverCoins(l.weight, l.tier, Mission.planet, Mission.mission) * crateBonus * Crew.coinMult(player)
	coins = Crew.addCoins(player, coins)
	local gain = math.max(0.5, l.weight * T.strengthPerWeight)
	d.strengthEarned = (d.strengthEarned or 0) + gain
	local rankBefore = Config.rank(d.hauled or 0)
	d.hauled = (d.hauled or 0) + l.weight
	d.delivered = (d.delivered or 0) + 1
	if l.star then
		d.crates = (d.crates or 0) + 1
	end
	local newEntry = false
	if not l.star then
		local key = l.kind .. ":" .. l.tier
		newEntry = d.index[key] == nil
		d.index[key] = (d.index[key] or 0) + 1
	end
	if (d.ftue.step or 0) < 2 then
		d.ftue.step = 2
	end
	questReward(player, d)
	Crew.contribute(player, l.weight * share)
	Crew.refresh(player)
	local rankAfter, rank = Config.rank(d.hauled)
	if rankAfter > rankBefore then
		Crew.tag(player)
		Mission.fire(player, "rankup", { name = rank.name, icon = rank.icon, tier = rank.tier })
	end
	Mission.fire(player, "reward", {
		coins = coins,
		strength = gain,
		kind = l.kind,
		tier = l.tier,
		pos = l.pos,
		new = newEntry,
		star = l.star,
	})
end

local function deliver(l: Loose)
	local holders = table.clone(l.holders)
	local total = 0
	for _, p in ipairs(holders) do
		total += Crew.strength(p)
	end
	local cf: CFrame? = nil
	if l.slot then
		cf = Rocket.worldCF(l.slot)
		local slot = l.slot
		Rocket.unreserve(slot, l.id)
		Rocket.fill(slot, l.tier, 0.85)
	end
	local names = {}
	for _, p in ipairs(holders) do
		table.insert(names, p.DisplayName)
	end
	Mission.fireAll("bolt", {
		id = l.id,
		slot = l.slot,
		cf = cf,
		kind = l.kind,
		tier = l.tier,
		names = names,
		star = l.star,
		pos = l.pos,
	})
	l.slot = nil -- delivered: keep the fill when removing
	for _, p in ipairs(holders) do
		local share = total > 0 and Crew.strength(p) / total or 1 / #holders
		reward(p, l, share, l.star and T.crateCoinMult or 1)
	end
	local tIdx = Tiers.index[l.tier] or 1
	if tIdx >= 5 and not l.star then
		local t = Tiers.get(l.tier)
		Mission.announce(string.format("%s %s bolted on a %s %s!", Config.Icons.star, table.concat(names, " + "), string.upper(t.name), Config.Kinds[l.kind].name), tIdx >= 6 and "pink" or "gold", "magic")
	end
	for _, fn in ipairs(deliverListeners) do
		task.spawn(fn, l, holders)
	end
	Haul.remove(l)
	if l.star then
		Haul.autoBolt(names[1] or "A Star Crate", "crate")
	end
end

-- A drone flies a part in and bolts it on (Star Crates, Fuel the Server). Returns true if a slot was filled.
function Haul.autoBolt(by: string, reason: string): boolean
	if not Mission.inBuild() then
		return false
	end
	local s = Rocket.nextOpen(nil)
	if not s then
		-- take a slot whose part is just lying around
		for _, l in pairs(Haul.parts) do
			if l.slot and l.mode == "rest" then
				local slotIndex = l.slot
				Haul.remove(l)
				s = Rocket.slots[slotIndex]
				break
			end
		end
	end
	if not s then
		return false
	end
	local tier = (Tiers.roll(Config.Rarity, rng, 1.5) :: Config.Rarity).key
	Rocket.fill(s.i, tier, 1.6)
	Mission.fireAll("drone", { cf = Rocket.worldCF(s.i), kind = s.kind, tier = tier, by = by, reason = reason, scale = s.scale })
	return true
end

-- Supply drop: Star Crates around a point.
function Haul.spawnCrates(center: Vector3, n: number)
	for k = 1, n do
		local a = (k / n) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local r = rng:NextNumber(5, 9)
		Haul.spawn("crate", "Legendary", center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), { star = true })
	end
end

-- Simulation -----------------------------------------------------------------------------------------------

local function step(dt: number)
	if not Mission.inBuild() then
		return
	end
	local area = Mission.area()
	local pad = flat(area.padCenter)
	for _, l in pairs(Haul.parts) do
		if l.mode == "carry" then
			-- prune holders who left, died or are gone
			for i = #l.holders, 1, -1 do
				local p = l.holders[i]
				if p.Parent == nil or not Crew.root(p) then
					release(p, l)
				end
			end
			if l.mode == "carry" and #l.holders > 0 then
				local str = totalStrength(l)
				if math.abs(str - l.str) > 0.05 then
					recompute(l)
				end
				local half = Parts.halfWidth(l.kind, l.scale)
				if l.speed > 0 then
					local sum = Vector3.zero
					local n = 0
					for _, p in ipairs(l.holders) do
						local r = Crew.root(p)
						if r then
							sum += flat(r.Position)
							n += 1
						end
					end
					if n > 0 then
						local target = sum / n
						local cur = flat(l.pos)
						local delta = target - cur
						local maxStep = (l.speed * T.jetpackHaul + 6) * 1.35 * dt
						if delta.Magnitude > maxStep then
							delta = delta.Unit * maxStep
						end
						local nextPos = cur + delta
						local o = flat(area.origin)
						local fromO = nextPos - o
						if fromO.Magnitude > area.playRadius then
							nextPos = o + fromO.Unit * area.playRadius
						end
						l.pos = Vector3.new(nextPos.X, area.origin.Y, nextPos.Z)
					end
				end
				-- leash: holders who wander off let go (never tighter than the lift reach, or a lift from the
				-- edge of the LIFT prompt's range is dropped again on the very next frame)
				local leash = T.liftRange + half + 2
				for i = #l.holders, 1, -1 do
					local p = l.holders[i]
					local r = Crew.root(p)
					if r and (flat(r.Position) - flat(l.pos)).Magnitude > leash then
						release(p, l)
						Shop.notify(p, "You let go of the " .. Config.Kinds[l.kind].name .. "!", "orange")
					end
				end
				if l.mode == "carry" and (flat(l.pos) - pad).Magnitude <= area.boltRadius then
					deliver(l)
				end
			end
		end
	end
end

local lastSync = 0
local function syncMoving()
	-- carried positions are drawn by clients from the holders; refresh Rest a few times a second for bots/late joiners
	local now = os.clock()
	if now - lastSync < 0.25 then
		return
	end
	lastSync = now
	for _, l in pairs(Haul.parts) do
		if l.mode == "carry" then
			l.cfg:SetAttribute("Rest", l.pos)
		end
	end
end

local function rollTier(): string
	local luck = Mission.boosted() and 1.6 or 1
	return (Tiers.roll(Config.Rarity, rng, luck) :: Config.Rarity).key
end

local function spawner()
	if not Mission.inBuild() or Rocket.complete then
		return
	end
	local area = Mission.area()
	local occupied: { [number]: boolean } = {}
	local ftueTaken = false
	for _, l in pairs(Haul.parts) do
		if l.pad then
			occupied[l.pad] = true
		end
		if l.ftue then
			ftueTaken = true
		end
	end
	-- FTUE pad by the spawn: always a light part waiting for new crew
	if not ftueTaken and (padReady[0] or 0) <= os.clock() then
		local s = Rocket.nextOpen(LIGHT_KINDS)
		if s then
			Haul.spawn(s.kind, "Common", area.ftuePad, { slot = s.i, ftue = true, yaw = math.rad(180) })
			padReady[0] = os.clock() + 3
		end
	end
	-- gift an Epic to a new player after their second delivery (rare-feeling moment in the first minute)
	local giftTo: Player? = nil
	for _, p in ipairs(Players:GetPlayers()) do
		local d = Data.get(p)
		if d and not d.ftue.epic and (d.delivered or 0) >= 2 then
			giftTo = p
			break
		end
	end
	for i, pos in ipairs(area.depotPads) do
		if not occupied[i] and (padReady[i] or 0) <= os.clock() then
			local s = Rocket.nextOpen(nil)
			if not s then
				break
			end
			local tier = rollTier()
			if giftTo then
				local d = Data.get(giftTo)
				if d then
					d.ftue.epic = true
					Data.dirty(giftTo)
				end
				if (Tiers.index[tier] or 1) < 4 then
					tier = "Epic"
				end
				Mission.fire(giftTo, "gift", { kind = s.kind, tier = tier, pos = pos })
				giftTo = nil
			end
			local l = Haul.spawn(s.kind, tier, pos, { slot = s.i, pad = i })
			l.cfg:SetAttribute("Pad", i)
			local tIdx = Tiers.index[tier] or 1
			if tIdx >= 4 then
				Mission.fireAll("rare", { kind = s.kind, tier = tier, pos = pos, id = l.id })
			end
		end
	end
end

function Haul.init()
	Net.event("Lift").OnServerEvent:Connect(function(player, id)
		if type(id) ~= "string" or not Net.allow(player, "lift", 0.2) then
			return
		end
		Haul.lift(player, id)
	end)
	Net.event("Drop").OnServerEvent:Connect(function(player)
		if not Net.allow(player, "drop", 0.2) then
			return
		end
		Haul.drop(player)
	end)
	Net.event("Help").OnServerEvent:Connect(function(player)
		Haul.help(player, false)
	end)
	Players.PlayerRemoving:Connect(function(p)
		local l = holding[p]
		if l then
			release(p, l)
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		step(dt)
		syncMoving()
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local ok, err = pcall(spawner)
			if not ok then
				warn("[Haul] spawner", err)
			end
		end
	end)
end

-- Debug helpers
function Haul.spawnAtDepot(tier: string): Loose?
	local area = Mission.area()
	local pos = area.depotPads[1] + Vector3.new(-14, 0, 0)
	local pad: number? = nil
	local s = Rocket.nextOpen(nil)
	if not s then
		-- every open slot already has a part waiting: re-roll a resting depot part into this tier
		for _, l in pairs(Haul.parts) do
			if l.slot and l.mode == "rest" and not l.ftue and not l.star then
				local slotIndex = l.slot
				pos = l.pos
				pad = l.pad
				Haul.remove(l)
				s = Rocket.slots[slotIndex]
				break
			end
		end
	end
	if not s then
		return nil
	end
	local l = Haul.spawn(s.kind, tier, pos, { slot = s.i, pad = pad })
	if pad then
		l.cfg:SetAttribute("Pad", pad)
	end
	Mission.fireAll("rare", { kind = s.kind, tier = tier, pos = pos, id = l.id })
	return l
end

function Haul.count(): number
	local n = 0
	for _ in pairs(Haul.parts) do
		n += 1
	end
	return n
end

return Haul

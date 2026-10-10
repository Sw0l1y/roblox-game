-- Server-authoritative balloons. The server owns every balloon's type, position and HP; clients build and
-- animate the models locally (Main.client -> BalloonView). Clients only ask to throw a dart / bump a balloon;
-- the server checks the rate (token bucket from the player's throw speed), the distance and the zone, applies
-- damage, pops, pays every player who helped, and replicates spawns / HP / pops in batches at 15 Hz.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local Config = require(Shared:WaitForChild("Config"))
local Econ = require(Shared:WaitForChild("Econ"))
local Data = require(script.Parent:WaitForChild("Data"))
local Progress = require(script.Parent:WaitForChild("Progress"))

local Balloons = {}

export type Balloon = {
	id: number,
	key: string,
	zone: number,
	pos: Vector3,
	hp: number,
	maxHp: number,
	big: boolean,
	radius: number,
	shower: boolean,
	born: number,
	expires: number?,
	dmg: { [Player]: number },
	reserved: Player?,
	reservedUntil: number,
}

-- pop flags (sent to clients)
Balloons.AURA = 1
Balloons.MEGA = 2

local list: { [number]: Balloon } = {}
local zoneCount: { number } = {}
for i = 1, #Config.Zones do
	zoneCount[i] = 0
end
local nextId = 0
local rng = Random.new()

local outSpawn: { { any } } = {}
local outHp: { [number]: number } = {}
local outPop: { { number } } = {}
local outGone: { number } = {}

local remote = Net.event("Balloon")
local dartRemote = Net.fast("Dart")
local syncFn = Net.func("BalloonSync")

type Bucket = { throw: number, bump: number, t: number }
local buckets: { [Player]: Bucket } = {}
local auraNext: { [Player]: number } = {}
local seeded: { [Player]: number } = {}
local starterDone: { [Player]: boolean } = {}

local function r1(n: number): number
	return math.floor(n * 10 + 0.5) / 10
end

local function record(b: Balloon, fromMega: boolean?): { any }
	local flags = (b.shower and 1 or 0) + (fromMega and 2 or 0)
	return { b.id, b.key, r1(b.pos.X), r1(b.pos.Y), r1(b.pos.Z), b.hp, b.maxHp, flags }
end

function Balloons.get(id: number): Balloon?
	return list[id]
end

function Balloons.all(): { [number]: Balloon }
	return list
end

function Balloons.count(zone: number): number
	return zoneCount[zone] or 0
end

function Balloons.hoverY(groundY: number, size: number): number
	return groundY + Config.Spawn.hoverBase + size * 0.6 + rng:NextNumber(0, Config.Spawn.hoverJitter)
end

export type SpawnOpts = { shower: boolean?, quiet: boolean?, life: number?, fromMega: boolean?, reserved: Player?, hp: number? }

function Balloons.spawn(key: string, pos: Vector3, o: SpawnOpts?): Balloon?
	local opts: SpawnOpts = o or {}
	local def = Config.Balloons[key]
	if not def then
		return nil
	end
	nextId += 1
	local hp = opts.hp or (opts.shower and 1 or Econ.typeHp(key))
	local tierStat = Config.TierStats[def.tier]
	local ti = Tiers.index[def.tier] or 1
	local life = opts.life
	if not life and ti >= Config.AnnounceSpawnTier then
		life = 150 -- legendary and rarer float away after a while: go get them!
	end
	local b: Balloon = {
		id = nextId,
		key = key,
		zone = def.zone,
		pos = pos,
		hp = hp,
		maxHp = hp,
		big = tierStat.big and not opts.shower,
		radius = def.size * 0.55,
		shower = opts.shower == true,
		born = os.clock(),
		expires = life and (os.clock() + life) or nil,
		dmg = {},
		reserved = opts.reserved,
		reservedUntil = opts.reserved and (os.clock() + 20) or 0,
	}
	list[b.id] = b
	if not b.shower then
		zoneCount[b.zone] += 1
	end
	table.insert(outSpawn, record(b, opts.fromMega))
	if not opts.quiet and not b.shower and ti >= Config.AnnounceSpawnTier then
		local t = Tiers.get(def.tier)
		Progress.uiAll("announce", "✨ A " .. t.name .. " " .. def.name .. " appeared in " .. Config.Zones[def.zone].name .. "!", def.tier, b.id)
	end
	return b
end

local function remove(b: Balloon)
	if not list[b.id] then
		return
	end
	list[b.id] = nil
	if not b.shower then
		zoneCount[b.zone] = math.max(0, zoneCount[b.zone] - 1)
	end
	outHp[b.id] = nil
end

local function pop(b: Balloon, popper: Player?, flags: number)
	if not list[b.id] then
		return
	end
	remove(b)
	table.insert(outPop, { b.id, popper and popper.UserId or 0, flags })
	for p in pairs(b.dmg) do
		if p.Parent then
			local share = (p == popper) and 1 or Config.Throw.helperShare
			Progress.reward(p, b.key, { id = b.id, pos = b.pos, share = share, shower = b.shower, aura = (flags == Balloons.AURA) and p == popper })
		end
	end
end

-- Apply damage; returns true if the balloon popped.
function Balloons.damage(b: Balloon, player: Player, amount: number, flags: number): boolean
	if not list[b.id] then
		return false
	end
	if b.reserved and b.reserved ~= player and os.clock() < b.reservedUntil then
		return false
	end
	b.hp -= amount
	b.dmg[player] = (b.dmg[player] or 0) + amount
	if b.hp <= 0 then
		pop(b, player, flags)
		return true
	end
	outHp[b.id] = math.ceil(b.hp)
	return false
end

-- Float away (expired) without a reward.
function Balloons.despawn(b: Balloon)
	if list[b.id] then
		remove(b)
		table.insert(outGone, b.id)
	end
end

---------------------------------------------------------------------------------------------------------------
-- Throwing
---------------------------------------------------------------------------------------------------------------

function Balloons.allowThrow(player: Player, d: { [string]: any }, bump: boolean): boolean
	local now = os.clock()
	local bk = buckets[player]
	if not bk then
		bk = { throw = Config.Throw.bucket, bump = 3, t = now }
		buckets[player] = bk
	end
	local dt = now - bk.t
	bk.t = now
	local rate = Config.Throw.tolerance / Econ.cooldown(d)
	bk.throw = math.min(Config.Throw.bucket, bk.throw + dt * rate)
	bk.bump = math.min(3, bk.bump + dt * 5)
	if bump then
		if bk.bump < 1 then
			return false
		end
		bk.bump -= 1
	else
		if bk.throw < 1 then
			return false
		end
		bk.throw -= 1
	end
	return true
end

function Balloons.dartStyle(player: Player): number
	if player:GetAttribute("Golden") then
		return 2
	elseif player:GetAttribute("VIP") then
		return 1
	end
	return 0
end

function Balloons.handOf(player: Player): Vector3?
	local hrp = Progress.root(player)
	if not hrp then
		return nil
	end
	return hrp.Position + hrp.CFrame.RightVector * 1.2 + Vector3.new(0, 1.4, 0)
end

-- Splash damage around a point (Mega Dart).
function Balloons.splash(player: Player, center: Vector3, amount: number)
	local hits: { Balloon } = {}
	for _, o in pairs(list) do
		if (o.pos - center).Magnitude <= Config.MegaDart.radius + o.radius then
			table.insert(hits, o)
		end
	end
	for _, o in ipairs(hits) do
		Balloons.damage(o, player, amount, Balloons.MEGA)
	end
	Progress.uiAll("boom", center, Config.MegaDart.radius)
end

function Balloons.hit(player: Player, d: { [string]: any }, id: number, mega: boolean, bump: boolean)
	local b = list[id]
	if not b then
		remote:FireClient(player, { s = {}, h = {}, p = {}, g = { id } })
		return
	end
	local hrp = Progress.root(player)
	if not hrp then
		return
	end
	local dist = (hrp.Position - b.pos).Magnitude
	if bump then
		if dist > b.radius + Config.Throw.bumpRange + 5 then
			return
		end
	elseif dist > Config.Throw.range + b.radius + 8 then
		return
	end
	if not b.shower and b.zone > (d.zones or 1) then
		return
	end
	local power = Econ.power(d)
	if mega and not bump and (d.megaDarts or 0) > 0 then
		d.megaDarts -= 1
		Progress.touch(player)
		local hand = Balloons.handOf(player)
		if hand then
			dartRemote:FireAllClients(player.UserId, hand, id, 3)
		end
		Balloons.splash(player, b.pos, power * Config.MegaDart.mult)
		return
	end
	if not bump then
		local hand = Balloons.handOf(player)
		if hand then
			dartRemote:FireAllClients(player.UserId, hand, id, Balloons.dartStyle(player))
		end
	end
	if not Balloons.damage(b, player, power, 0) and list[id] and b.reserved and b.reserved ~= player then
		-- reserved for a new player: tell this client it did not pop
		remote:FireClient(player, { s = {}, h = { { id, math.ceil(b.hp) } }, p = {}, g = {} })
	end
end

---------------------------------------------------------------------------------------------------------------
-- Spawning
---------------------------------------------------------------------------------------------------------------

local function playersIn(zone: number): { Player }
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if Progress.zoneOf(p) == zone and Data.get(p) then
			table.insert(out, p)
		end
	end
	return out
end

local function clear(zone: number, x: number, z: number, radius: number): boolean
	for _, o in pairs(list) do
		if o.zone == zone or o.shower then
			local dx, dz = o.pos.X - x, o.pos.Z - z
			local need = o.radius + radius + 1.2
			if dx * dx + dz * dz < need * need then
				return false
			end
		end
	end
	return true
end

local function pickSpot(zone: number, near: Vector3?, radius: number): Vector3?
	local zd = Config.Zones[zone]
	local candidates = zd.fields
	if near then
		local close: { { number } } = {}
		for _, f in ipairs(zd.fields) do
			local dx, dz = f[1] - near.X, f[2] - near.Z
			if math.sqrt(dx * dx + dz * dz) - f[3] < Config.Spawn.nearPlayer then
				table.insert(close, f)
			end
		end
		if #close > 0 then
			candidates = close
		end
	end
	for attempt = 1, 10 do
		local f = candidates[rng:NextInteger(1, #candidates)]
		local a = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber()) * math.max(1, f[3] - 2)
		local x, z = f[1] + math.cos(a) * r, f[2] + math.sin(a) * r
		local farFromPlayer = near and attempt <= 6 and ((x - near.X) ^ 2 + (z - near.Z) ^ 2) > Config.Spawn.nearPlayer ^ 2
		if not farFromPlayer and clear(zone, x, z, radius) then
			return Vector3.new(x, zd.groundY, z)
		end
	end
	return nil
end

local function spawnIn(zone: number, players: { Player }, quiet: boolean?)
	local target = #players > 0 and players[rng:NextInteger(1, #players)] or nil
	local luck = 1
	local near: Vector3? = nil
	if target then
		local d = Data.get(target)
		luck = Econ.luck(d, os.time())
		local hrp = Progress.root(target)
		near = hrp and hrp.Position or nil
	end
	local e = Tiers.roll(Econ.spawnTable(zone), rng, luck)
	local def = Config.Balloons[e.key]
	local spot = pickSpot(zone, near, def.size * 0.55)
	if spot then
		Balloons.spawn(e.key, Vector3.new(spot.X, Balloons.hoverY(spot.Y, def.size), spot.Z), { quiet = quiet })
	end
end

-- Spawn a balloon of `key` close to a player (debug, FTUE).
function Balloons.spawnNear(player: Player, key: string, distance: number?, o: SpawnOpts?): Balloon?
	local hrp = Progress.root(player)
	local def = Config.Balloons[key]
	if not hrp or not def then
		return nil
	end
	local zone = Econ.zoneAt(hrp.Position)
	local groundY = zone > 0 and Config.Zones[zone].groundY or (hrp.Position.Y - 3)
	local look = hrp.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(0, 0, -1)
	end
	local base = hrp.Position + flat.Unit * (distance or 12)
	local spot = Vector3.new(base.X, groundY, base.Z)
	for _ = 1, 6 do
		if clear(def.zone, spot.X, spot.Z, def.size * 0.55) then
			break
		end
		spot += Vector3.new(rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5))
	end
	return Balloons.spawn(key, Vector3.new(spot.X, Balloons.hoverY(groundY, def.size), spot.Z), o)
end

-- MEGA BALLOON shower: rare one-hit balloons burst out of the Mega and land around the plaza.
function Balloons.shower(center: Vector3, count: number, maxZone: number)
	local weights = {}
	for ti, tier in ipairs(Config.TierOrder) do
		local w = Config.Event.showerWeights[tier]
		if w then
			table.insert(weights, { tier = tier, ti = ti, weight = w })
		end
	end
	for i = 1, count do
		task.delay(0.05 + i * 0.07, function()
			local e = Tiers.roll(weights, rng, 1)
			local zone = rng:NextInteger(1, math.max(1, maxZone))
			local key = Config.ZoneTypes[zone][e.ti]
			local def = Config.Balloons[key]
			if not def then
				return
			end
			local spot: Vector3? = nil
			for _ = 1, 8 do
				local a = rng:NextNumber(0, math.pi * 2)
				local r = rng:NextNumber(18, 46)
				local x, z = center.X + math.cos(a) * r, center.Z + math.sin(a) * r
				if clear(1, x, z, def.size * 0.55) then
					spot = Vector3.new(x, 0, z)
					break
				end
			end
			if spot then
				Balloons.spawn(key, Vector3.new(spot.X, Balloons.hoverY(0, def.size) + 1, spot.Z), { shower = true, life = Config.Event.showerLife, fromMega = true, quiet = true })
			end
		end)
	end
end

---------------------------------------------------------------------------------------------------------------
-- Loops
---------------------------------------------------------------------------------------------------------------

local function spawnStep()
	for z = 1, #Config.Zones do
		local zd = Config.Zones[z]
		local ps = playersIn(z)
		local cap = math.min(zd.cap.max, zd.cap.base + zd.cap.perPlayer * #ps)
		local n = zoneCount[z]
		if n < cap then
			local count = (n < cap * 0.5) and Config.Spawn.catchUp or 1
			for _ = 1, math.min(count, cap - n) do
				spawnIn(z, ps)
			end
		end
	end
end

local function auraStep()
	local now = os.clock()
	for p, d in pairs(Data.all()) do
		local r = Econ.auraRadius(d)
		local hrp = Progress.root(p)
		if r > 0 and hrp and p.Parent and now >= (auraNext[p] or 0) then
			local pass = Econ.has(d, "Aura")
			auraNext[p] = now + (pass and Config.Aura.passTick or Config.Aura.tick)
			local pos = hrp.Position
			local cands: { { b: Balloon, d: number } } = {}
			for _, b in pairs(list) do
				if (not b.big or pass) and (b.shower or b.zone <= (d.zones or 1)) then
					local dx, dz = b.pos.X - pos.X, b.pos.Z - pos.Z
					local dd = math.sqrt(dx * dx + dz * dz)
					if dd <= r + b.radius and math.abs(b.pos.Y - pos.Y) < 14 then
						table.insert(cands, { b = b, d = dd })
					end
				end
			end
			table.sort(cands, function(a: { b: Balloon, d: number }, c: { b: Balloon, d: number }): boolean
				return a.d < c.d
			end)
			local power = Econ.power(d)
			for i = 1, math.min(#cands, Config.Aura.maxPerTick) do
				Balloons.damage(cands[i].b, p, power, Balloons.AURA)
			end
		end
	end
end

-- FTUE: easy balloons around a brand-new player, and a seeded rare near them at ~45 s.
local function ftueStep()
	for _, p in ipairs(Players:GetPlayers()) do
		local d = Data.get(p)
		local hrp = Progress.root(p)
		if d and hrp then
			if not starterDone[p] then
				starterDone[p] = true
				if (d.pops or 0) < 5 and Econ.zoneAt(hrp.Position) == 1 then
					for i = 1, Config.Ftue.starterBalloons do
						local a = (i / Config.Ftue.starterBalloons) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
						local r = rng:NextNumber(7, 13)
						local key = i % 3 == 0 and Config.ZoneTypes[1][2] or Config.ZoneTypes[1][1]
						local def = Config.Balloons[key]
						local x, z = hrp.Position.X + math.cos(a) * r, hrp.Position.Z + math.sin(a) * r
						if clear(1, x, z, def.size * 0.55) then
							Balloons.spawn(key, Vector3.new(x, Balloons.hoverY(0, def.size), z), { quiet = true })
						end
					end
				end
			end
			local ft = d.ftue or {}
			local s = Progress.sessionTime(p)
			local n = seeded[p] or 0
			if not ft.rare and ((n == 0 and s >= Config.Ftue.rareAt) or (n == 1 and s >= Config.Ftue.rareRetry)) then
				seeded[p] = n + 1
				local zone = math.max(1, Econ.zoneAt(hrp.Position))
				local key = Config.ZoneTypes[zone][n == 0 and 3 or 4]
				local b = Balloons.spawnNear(p, key, 11, { quiet = true, reserved = p })
				if b then
					Progress.ui(p, "rareNear", b.id, key)
				end
			end
		end
	end
end

local function expireStep()
	local now = os.clock()
	local gone: { Balloon } = {}
	for _, b in pairs(list) do
		if b.expires and now >= b.expires then
			table.insert(gone, b)
		end
	end
	for _, b in ipairs(gone) do
		Balloons.despawn(b)
	end
end

local function flush()
	if #outSpawn == 0 and next(outHp) == nil and #outPop == 0 and #outGone == 0 then
		return
	end
	local hp = {}
	for id, v in pairs(outHp) do
		table.insert(hp, { id, v })
	end
	remote:FireAllClients({ s = outSpawn, h = hp, p = outPop, g = outGone })
	outSpawn, outHp, outPop, outGone = {}, {}, {}, {}
end

function Balloons.init()
	syncFn.OnServerInvoke = function(player)
		local out = {}
		if not Net.allow(player, "balloonSync", 3) then
			return out
		end
		for _, b in pairs(list) do
			table.insert(out, record(b, false))
		end
		return out
	end
	Players.PlayerRemoving:Connect(function(p)
		buckets[p] = nil
		auraNext[p] = nil
		seeded[p] = nil
		starterDone[p] = nil
	end)
	-- fill every zone once so it looks alive from the start (and from the zone before it)
	for z = 1, #Config.Zones do
		for _ = 1, Config.Zones[z].cap.base do
			spawnIn(z, {}, true)
		end
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 / 15 then
			acc = 0
			flush()
		end
	end)
	local function loop(period: number, fn: () -> (), name: string)
		task.spawn(function()
			while true do
				task.wait(period)
				local ok, err = pcall(fn)
				if not ok then
					warn("[Balloons] " .. name, err)
				end
			end
		end)
	end
	loop(Config.Spawn.interval, spawnStep, "spawn")
	loop(0.15, auraStep, "aura")
	loop(1, ftueStep, "ftue")
	loop(1, expireStep, "expire")
end

return Balloons

--!strict
-- Live races: builds the track from a seed, runs RaceSim at a fixed 30 Hz from the GO time, streams a
-- compact state (5 bytes per marble) 15 times a second on an unreliable remote, forwards race events
-- (boosts, jumps, finishes, photo finish) reliably, and validates BOOST taps.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Track = require(Shared:WaitForChild("Track"))
local Net = require(Shared:WaitForChild("Net"))
local RaceSim = require(script.Parent:WaitForChild("RaceSim"))

local Race = {}

export type Spec = {
	userId: number,
	name: string,
	bot: boolean,
	key: string,
	id: string,
	mut: string?,
	spd: number,
	grip: number,
	wt: number,
	cards: { string },
	skill: number,
	trail: string?,
	vip: boolean,
	lvl: number,
	owned: boolean,
}

export type RaceT = {
	id: number,
	kind: string,
	seed: number,
	theme: string,
	td: Track.TrackData,
	sim: RaceSim.Sim,
	goTime: number,
	created: number,
	desc: { [string]: any },
	specs: { Spec },
	byUser: { [number]: number },
	done: boolean,
	acc: number,
	sendAcc: number,
	onDone: ((RaceT) -> ())?,
	gp: boolean,
	rookie: boolean,
	results: { { [string]: any } }?,
}

local races: { [number]: RaceT } = {}
local nextId = 0
local STEP = 1 / Config.Race.simHz
local SEND = 1 / Config.Race.sendHz

local startRemote = Net.event("RaceStart")
local snapRemote = Net.fast("RaceSnap")
local evtRemote = Net.event("RaceEvt")
local endRemote = Net.event("RaceEnd")
local boostRemote = Net.event("Boost")

local function now(): number
	return workspace:GetServerTimeNow()
end

-- opts: { gp, rookie, clip, td (pre-generated track for this seed) }
function Race.create(kind: string, seed: number, theme: string, specs: { Spec }, goDelay: number, opts: { [string]: any }?): RaceT
	local o: { [string]: any } = opts or {}
	local trackOpts = (Config.Tracks :: any)[kind] or Config.Tracks.main
	local td: Track.TrackData = o.td or Track.generate(seed, trackOpts)
	local rng = Random.new(seed + 17)
	for i = #specs, 2, -1 do
		local j = rng:NextInteger(1, i)
		specs[i], specs[j] = specs[j], specs[i]
	end
	local entrants: { RaceSim.Entrant } = {}
	local byUser: { [number]: number } = {}
	for i, sp in ipairs(specs) do
		local cards: { [string]: boolean } = {}
		for _, c in ipairs(sp.cards) do
			cards[c] = true
		end
		entrants[i] = {
			idx = i,
			userId = sp.userId,
			name = sp.name,
			bot = sp.bot,
			key = sp.key,
			id = sp.id,
			mut = sp.mut,
			spd = sp.spd,
			grip = sp.grip,
			wt = sp.wt,
			cards = cards,
			skill = sp.skill,
			s = 0,
			u = 0,
			ut = 0,
			h = 0,
			v = 0,
			boostT = 0,
			boostP = 1,
			megaUsed = false,
			glowAt = 0,
			lockT = 0,
			botTapAt = nil,
			magnetT = 0,
			magnetDone = false,
			padT = 0,
			air = false,
			airS0 = 0,
			airS1 = 0,
			airPeak = 0,
			splitSide = 1,
			lastPiece = 0,
			lastTag = 0,
			wanderT = 0,
			bumpCd = 0,
			noBump = false,
			finished = false,
			place = 0,
			finishT = 0,
			stopS = 0,
			stopU = 0,
			perfects = 0,
			goods = 0,
			boosting = false,
			jam = 0,
		}
		if not sp.bot then
			byUser[sp.userId] = i
		end
	end
	local sim = RaceSim.new(td, entrants, seed + 99, o.clip == true)
	nextId = nextId % 250 + 1
	while races[nextId] do
		nextId = nextId % 250 + 1
	end
	local t = now()
	local race: RaceT = {
		id = nextId,
		kind = kind,
		seed = seed,
		theme = theme,
		td = td,
		sim = sim,
		goTime = t + goDelay,
		created = t,
		desc = {},
		specs = specs,
		byUser = byUser,
		done = false,
		acc = 0,
		sendAcc = 0,
		onDone = nil,
		gp = o.gp == true,
		rookie = o.rookie == true,
		results = nil,
	}
	local list = {}
	for i, sp in ipairs(specs) do
		local e = entrants[i]
		table.insert(list, {
			idx = i,
			name = sp.name,
			userId = sp.userId,
			bot = sp.bot,
			id = sp.id,
			mut = sp.mut,
			cards = sp.cards,
			trail = sp.trail,
			vip = sp.vip,
			lvl = sp.lvl,
			s0 = e.s,
			u0 = e.u,
		})
	end
	race.desc = {
		id = race.id,
		kind = kind,
		seed = seed,
		theme = theme,
		goTime = race.goTime,
		gp = race.gp,
		rookie = race.rookie,
		entrants = list,
	}
	races[race.id] = race
	startRemote:FireAllClients(race.desc)
	return race
end

local function pack(race: RaceT, stateTime: number): buffer
	local sim = race.sim
	local n = #sim.entrants
	local b = buffer.create(14 + n * 5)
	buffer.writeu8(b, 0, race.id)
	buffer.writef64(b, 1, stateTime)
	buffer.writef32(b, 9, sim.t)
	buffer.writeu8(b, 13, n)
	for i, e in ipairs(sim.entrants) do
		local o = 14 + (i - 1) * 5
		buffer.writeu16(b, o, math.clamp(math.floor(e.s * 20 + 0.5), 0, 65535))
		buffer.writei8(b, o + 2, math.clamp(math.floor(e.u * 127 + 0.5), -127, 127))
		buffer.writeu8(b, o + 3, math.clamp(math.floor(e.h * 20 + 0.5), 0, 255))
		local f = 0
		if RaceSim.glowing(sim, e) then
			f += 1
		end
		if e.boostT > 0 then
			f += 2
		end
		if e.finished then
			f += 4
		end
		if e.magnetT > 0 then
			f += 8
		end
		if e.air then
			f += 16
		end
		if e.padT > 0 then
			f += 32
		end
		buffer.writeu8(b, o + 4, f)
	end
	return b
end

local function flushEvents(race: RaceT)
	local evs = race.sim.events
	if #evs == 0 then
		return
	end
	race.sim.events = {}
	for _, ev in ipairs(evs) do
		evtRemote:FireAllClients(race.id, table.unpack(ev))
	end
end

local function results(race: RaceT): { { [string]: any } }
	local out: { { [string]: any } } = {}
	for _, e in ipairs(RaceSim.results(race.sim)) do
		local sp = race.specs[e.idx]
		local row: { [string]: any } = {
			idx = e.idx,
			place = e.place,
			name = e.name,
			userId = e.userId,
			bot = e.bot,
			id = e.id,
			mut = e.mut,
			time = e.finishT,
			perfects = e.perfects,
			key = e.key,
			owned = sp and sp.owned or false,
		}
		table.insert(out, row)
	end
	return out
end

RunService.Heartbeat:Connect(function(dt)
	local t = now()
	for _, race in pairs(races) do
		if not race.done then
			if t >= race.goTime then
				race.acc += math.min(dt, 0.25)
				local guard = 0
				while race.acc >= STEP and guard < 10 do
					race.acc -= STEP
					guard += 1
					RaceSim.step(race.sim, STEP)
				end
				flushEvents(race)
			end
			race.sendAcc += dt
			if race.sendAcc >= SEND then
				race.sendAcc = 0
				local stateTime = t >= race.goTime and (race.goTime + race.sim.t) or t
				snapRemote:FireAllClients(pack(race, stateTime))
			end
			if race.sim.done then
				race.done = true
				snapRemote:FireAllClients(pack(race, race.goTime + race.sim.t))
				race.results = results(race)
				endRemote:FireAllClients(race.id, race.results, race.sim.photo)
				local cb = race.onDone
				if cb then
					task.spawn(cb, race)
				end
			end
		end
	end
end)

boostRemote.OnServerEvent:Connect(function(player, raceId, clientTime)
	if type(raceId) ~= "number" or not Net.allow(player, "boost", 0.2) then
		return
	end
	local race = races[raceId]
	if not race or race.done then
		return
	end
	local idx = race.byUser[player.UserId]
	if not idx then
		return
	end
	local t = race.sim.t
	local tc = t - 0.35
	if type(clientTime) == "number" and clientTime == clientTime then
		local c = clientTime - race.goTime
		if c <= t + 0.15 and c >= t - 1.0 then
			tc = c
		end
	end
	RaceSim.boost(race.sim, idx, tc)
	flushEvents(race)
end)

function Race.get(id: number): RaceT?
	return races[id]
end

function Race.all(): { [number]: RaceT }
	return races
end

-- Is this player racing in a race of `kind` that hasn't finished?
function Race.isRacing(userId: number, kind: string?): boolean
	for _, r in pairs(races) do
		if not r.done and r.byUser[userId] and (kind == nil or r.kind == kind) then
			return true
		end
	end
	return false
end

function Race.remove(race: RaceT)
	if races[race.id] == race then
		races[race.id] = nil
	end
	evtRemote:FireAllClients(race.id, -1, "remove")
end

-- For players who join mid-race.
function Race.descriptors(): { { [string]: any } }
	local out = {}
	for _, r in pairs(races) do
		local d = table.clone(r.desc)
		d.done = r.done
		d.results = r.results
		table.insert(out, d)
	end
	return out
end

function Race.setClip(on: boolean)
	for _, r in pairs(races) do
		if not r.done then
			r.sim.clip = on
		end
	end
end

local _ = Players
return Race

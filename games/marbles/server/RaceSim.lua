--!strict
-- Race simulation: every marble is a distance `s` along the track spline plus a lateral lane `u`
-- (-1..1) and an extra height `h` (jumps). Speed comes from stats, slope, turns, boosts, power-up cards,
-- pads, bumps and a little catch-up. No Roblox physics, so 12 marbles never jitter; clients interpolate.
-- Pure logic (no services): the Race module drives it and streams the state.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Track = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Track"))

local RaceSim = {}
local TAG = Track.TAG
local R = Config.Race

export type Entrant = {
	idx: number,
	userId: number,
	name: string,
	bot: boolean,
	key: string,
	id: string,
	mut: string?,
	spd: number,
	grip: number,
	wt: number,
	cards: { [string]: boolean },
	skill: number,
	s: number,
	u: number,
	ut: number,
	h: number,
	v: number,
	boostT: number,
	boostP: number,
	megaUsed: boolean,
	glowAt: number,
	lockT: number,
	botTapAt: number?,
	magnetT: number,
	magnetDone: boolean,
	padT: number,
	air: boolean,
	airS0: number,
	airS1: number,
	airPeak: number,
	splitSide: number,
	lastPiece: number,
	lastTag: number,
	wanderT: number,
	bumpCd: number,
	noBump: boolean,
	finished: boolean,
	place: number,
	finishT: number,
	stopS: number,
	stopU: number,
	perfects: number,
	goods: number,
	boosting: boolean,
	jam: number,
}

export type Sim = {
	td: Track.TrackData,
	entrants: { Entrant },
	t: number,
	rng: Random,
	nextPlace: number,
	events: { { any } },
	done: boolean,
	winnerT: number?,
	funnelLast: { [number]: number },
	clip: boolean,
	clipDone: boolean,
	photo: boolean,
	gap: number,
}

local D = R.marbleD
local LANES = { -0.72, -0.24, 0.24, 0.72 }

local function clamp(x: number, a: number, b: number): number
	return math.clamp(x, a, b)
end

local function halfW(td: Track.TrackData, i: number): number
	return math.max(0.05, td.width[i] / 2 - D / 2 - Track.RAIL)
end

-- entrants: partially filled records (idx, name, stats, cards...). Grid slots are assigned here.
function RaceSim.new(td: Track.TrackData, entrants: { Entrant }, seed: number, clip: boolean?): Sim
	local rng = Random.new(seed)
	local sim: Sim = {
		td = td,
		entrants = entrants,
		t = 0,
		rng = rng,
		nextPlace = 1,
		events = {},
		done = false,
		winnerT = nil,
		funnelLast = {},
		clip = clip == true,
		clipDone = false,
		photo = false,
		gap = 0,
	}
	-- grid: rows of four behind the gate
	local gate = td.gateS
	for k, e in ipairs(entrants) do
		local row = math.floor((k - 1) / 4)
		e.s = gate - 3 - row * 3.6
		e.u = LANES[(k - 1) % 4 + 1] * 0.92
		e.ut = e.u
		e.h = 0
		e.v = 0
		e.glowAt = rng:NextNumber(1.6, 2.8)
		e.lockT = -1
		e.wanderT = rng:NextNumber(0.5, 2)
		e.bumpCd = rng:NextNumber(1, 3)
		e.lastPiece = 0
		e.lastTag = 0
	end
	return sim
end

-- Events carry the sim time first so clients can play them in sync with the interpolated view.
local function event(sim: Sim, ...: any)
	table.insert(sim.events, { sim.t, ... })
end

-- A boost tap at race time tc (already validated/clamped by the caller). Returns the result.
function RaceSim.boost(sim: Sim, idx: number, tc: number): string?
	local e = sim.entrants[idx]
	if not e or e.finished or sim.t <= 0 then
		return nil
	end
	if tc < e.lockT then
		return "locked"
	end
	local g0 = e.glowAt
	if tc >= g0 - 0.12 and tc <= g0 + R.glowDur + R.glowSlack then
		local center = g0 + R.glowDur * 0.45
		local q = math.abs(tc - center) <= R.perfectWin and "perfect" or "good"
		if e.cards.boost and not e.megaUsed then
			e.megaUsed = true
			e.boostP, e.boostT = R.megaBoost, R.megaTime
			q = "mega"
			e.perfects += 1
		elseif q == "perfect" then
			e.boostP, e.boostT = R.perfectBoost, R.perfectTime
			e.perfects += 1
		else
			e.boostP, e.boostT = R.goodBoost, R.goodTime
			e.goods += 1
		end
		e.glowAt = sim.t + sim.rng:NextNumber(R.glowGapMin, R.glowGapMax)
		e.botTapAt = nil
		event(sim, "boost", idx, q)
		return q
	end
	e.lockT = tc + R.missLock
	event(sim, "miss", idx)
	return "miss"
end

local function finish(sim: Sim, e: Entrant)
	e.finished = true
	e.place = sim.nextPlace
	sim.nextPlace += 1
	local over = e.s - sim.td.finishS
	e.finishT = sim.t - over / math.max(e.v, 1)
	local p = e.place - 1
	e.stopS = sim.td.endS - 1.5 - math.floor(p / 4) * 3.5
	e.stopU = LANES[p % 4 + 1]
	e.boostT = 0
	e.h = 0
	if e.place == 1 then
		sim.winnerT = sim.t
	elseif e.place == 2 then
		local first: Entrant? = nil
		for _, o in ipairs(sim.entrants) do
			if o.place == 1 then
				first = o
			end
		end
		if first and e.finishT - first.finishT < 0.15 then
			sim.photo = true
			event(sim, "photo", first.idx, e.idx, e.finishT - first.finishT)
		end
	end
	event(sim, "finish", e.idx, e.place, e.finishT)
end

function RaceSim.step(sim: Sim, dt: number)
	if sim.done then
		return
	end
	sim.t += dt
	local t = sim.t
	local td = sim.td
	local rng = sim.rng
	local n = td.n
	if t <= 0 then
		return
	end

	local order = table.clone(sim.entrants)
	table.sort(order, function(a: Entrant, b: Entrant)
		if a.finished ~= b.finished then
			return a.finished
		end
		return a.s > b.s
	end)
	local leader: Entrant? = nil
	local second: Entrant? = nil
	for _, e in ipairs(order) do
		if not e.finished then
			if not leader then
				leader = e
			elseif not second then
				second = e
				break
			end
		end
	end
	local leaderS = leader and leader.s or 0

	-- Clip mode: stage a photo finish between the top two.
	if sim.clip and not sim.clipDone and leader and second and leader.s > td.finishS - 90 then
		sim.clipDone = true
		second.s = leader.s - 0.6
		second.u = leader.u > 0 and leader.u - 0.75 or leader.u + 0.75
		second.ut = second.u
		second.v = leader.v
		second.boostT, leader.boostT = 0, 0
		second.noBump, leader.noBump = true, true
		second.spd, leader.spd = leader.spd, leader.spd
		second.grip, leader.grip = leader.grip, leader.grip
		second.wt, leader.wt = leader.wt, leader.wt
		second.cards, leader.cards = {}, {}
		second.glowAt, leader.glowAt = 1e9, 1e9
		second.padT, leader.padT = 0, 0
		second.magnetT, leader.magnetT = 0, 0
	end

	local queued = 0
	for _, e in ipairs(order) do
		if e.finished then
			-- roll gently into the catch area
			local d = e.stopS - e.s
			e.v = math.max(0, math.min(e.v, d * 2.2 + 0.5))
			if d <= 0.01 then
				e.v = 0
			end
			e.s = math.min(e.stopS, e.s + e.v * dt)
			e.u += (e.stopU - e.u) * math.min(1, dt * 2.5)
			e.h = 0
			e.boosting = false
			continue
		end

		local i = clamp(math.floor(e.s) + 1, 1, n)
		local tag = td.tag[i]
		local pidx = td.piece[i]
		local piece = td.pieces[pidx]
		local ptype = piece and piece.type or ""
		local cards = e.cards
		local hw = halfW(td, i)

		-- entering a new piece
		if pidx ~= e.lastPiece then
			e.lastPiece = pidx
			if ptype == "split" then
				if math.abs(e.u) < 0.05 then
					e.splitSide = rng:NextNumber() < 0.5 and -1 or 1
				else
					e.splitSide = e.u > 0 and 1 or -1
				end
			end
		end

		-- target speed
		local vmax = R.baseSpeed + e.spd * R.spdK
		local target = vmax
		local down = clamp(-td.slope[i], -0.4, 0.9)
		target += down * R.slopeK * (0.85 + e.wt * 0.03)
		local curv = td.curv[i]
		local turnLoss = math.min(0.3, math.abs(curv) * R.turnK * math.max(0.12, 1 - e.grip / 20))
		target *= 1 - (cards.sticky and turnLoss * 0.62 or turnLoss)
		if tag == TAG.FUNNEL then
			-- marbles slow as the bowl narrows, so they bunch up at the hole
			local f = 1
			if ptype == "funnel" then
				local s0, s1 = piece.s0 + 14, piece.spiralEndS :: number
				f = clamp((s1 - e.s) / math.max(1, s1 - s0), 0, 1)
			end
			target = (R.funnelSpeed + e.grip * 0.45 + (cards.sticky and 1 or 0)) * (0.6 + 0.4 * f)
		elseif tag == TAG.STEP or tag == TAG.HOP then
			target = math.min(target, vmax * 0.92)
		end
		if tag == TAG.PAD then
			e.padT = 0.9
		end
		if ptype == "split" then
			if e.splitSide == piece.padSide and e.s >= piece.padS0 and e.s <= piece.padS1 then
				e.padT = 0.9
			end
		end
		if e.padT > 0 then
			target *= 1.32
			e.padT -= dt
		end
		e.boosting = e.boostT > 0
		if e.boostT > 0 then
			target *= e.boostP
			e.boostT -= dt
		end
		-- magnet card: fires once, mid-race
		if cards.magnet and not e.magnetDone and e.s > td.finishS * Config.Magnet.at then
			e.magnetDone = true
			e.magnetT = Config.Magnet.time
			event(sim, "power", e.idx, "magnet")
		end
		if e.magnetT > 0 then
			e.magnetT -= dt
			local best: Entrant? = nil
			for _, o in ipairs(sim.entrants) do
				if o ~= e and not o.finished and o.s > e.s and o.s - e.s < 55 then
					if not best or o.s < best.s then
						best = o
					end
				end
			end
			if best then
				target *= Config.Magnet.bonus
				e.ut = best.u
			else
				target *= 1.06
			end
		end
		-- catch-up for marbles far behind keeps the pack together
		local gap = leaderS - e.s
		if gap > 25 then
			target *= 1 + math.min(R.rubber, (gap - 25) / 300)
		end
		-- random bumps
		e.bumpCd -= dt
		if e.bumpCd <= 0 then
			e.bumpCd = rng:NextNumber(1.2, 3.2)
			if not e.noBump and (tag == TAG.NORMAL or tag == TAG.TURN or tag == TAG.WAVE or tag == TAG.SPLIT) then
				if rng:NextNumber() < 0.3 then
					e.v *= 1.04
				else
					e.v *= 1 - rng:NextNumber(0, 0.06) * math.max(0.3, 1.2 - e.wt * 0.05)
				end
				e.ut = clamp(e.ut + rng:NextNumber(-0.35, 0.35), -0.9, 0.9)
			end
		end

		-- integrate speed
		if tag == TAG.AIR then
			-- ballistic: keep speed
		elseif tag == TAG.DROP then
			e.v = math.max(e.v, 16)
		else
			local acc = target > e.v and R.accel * (1.3 - e.wt * 0.04) or R.decel
			e.v += clamp(target - e.v, -acc * dt, acc * dt)
		end
		e.v = clamp(e.v, 2, 80)

		-- stairs: each hop costs (or gives) a little speed
		if tag == TAG.HOP and e.lastTag == TAG.STEP then
			if cards.sticky or cards.bounce then
				e.v *= 1.03
			else
				e.v *= 0.93 + e.wt * 0.006
			end
		end

		-- lateral intention
		e.wanderT -= dt
		if e.wanderT <= 0 then
			e.wanderT = rng:NextNumber(0.9, 2.4)
			e.ut = clamp(e.ut + rng:NextNumber(-0.6, 0.6), -0.88, 0.88)
		end
		if not cards.sticky and tag ~= TAG.AIR then
			e.ut = clamp(e.ut + curv * e.v * math.max(0.1, 1.15 - e.grip / 16) * 0.9 * dt, -0.92, 0.92)
		end
		if ptype == "split" then
			local base = e.splitSide * 0.56
			if e.splitSide ~= piece.padSide then
				-- bumper lane: bounce off the wall bumpers
				for _, bs in ipairs(piece.bumpers :: { number }) do
					if e.s < bs and e.s + e.v * dt >= bs then
						e.ut = base + rng:NextNumber(-0.32, 0.32)
						if not cards.sticky then
							e.v *= rng:NextNumber(0.9, 1.04)
						end
						event(sim, "bump", e.idx)
					end
				end
				e.ut = clamp(e.ut, base - 0.34, base + 0.34)
			else
				e.ut = clamp(e.ut, base - 0.2, base + 0.2)
			end
		elseif tag == TAG.FUNNEL then
			e.ut = clamp((e.v - 15) / 9, -0.7, 0.85)
		elseif tag == TAG.DROP then
			e.ut = 0
		end
		local rate = (tag == TAG.AIR) and 0 or (tag == TAG.DROP and 3 or 1.3)
		e.u += clamp(e.ut - e.u, -rate * dt, rate * dt)
		e.u = clamp(e.u, -1, 1)

		-- advance
		local ns = e.s + e.v * dt

		-- funnel hole: one marble at a time
		if ptype == "funnel" then
			local se = piece.spiralEndS :: number
			if e.s < se and ns >= se then
				local last = sim.funnelLast[pidx] or -9
				if t - last < R.funnelGap then
					ns = se - 0.05
					e.v = math.min(e.v, 5)
					e.jam += dt
					queued += 1
				else
					sim.funnelLast[pidx] = t
				end
			end
		end

		-- don't drive through the marble ahead (processed first, so its position is final)
		for _, o in ipairs(order) do
			if o == e then
				break
			end
			if not o.finished then
				local ahead = o.s - e.s
				if ahead > -0.2 then
					local oi = clamp(math.floor(o.s) + 1, 1, n)
					local w = math.min(hw, halfW(td, oi))
					if math.abs(o.u - e.u) * w < D * 0.92 and ns > o.s - D * 0.92 then
						ns = math.max(e.s, o.s - D * 0.92)
						e.v = math.min(e.v, o.v + 0.5)
						-- try to swerve round it
						if w > 2.5 then
							local side = o.u > 0 and -1 or 1
							e.ut = clamp(o.u + side * (D * 1.05) / w, -0.92, 0.92)
						end
					end
				end
			end
		end
		e.s = ns

		-- jumps
		local ni = clamp(math.floor(e.s) + 1, 1, n)
		local ntag = td.tag[ni]
		if ntag == TAG.AIR then
			local p = td.pieces[td.piece[ni]]
			if not e.air and p then
				e.air = true
				e.airS0 = p.takeS
				e.airS1 = p.landS
				local peak = math.max(0, (e.v - 25) * 0.2) * math.max(0.4, 1.3 - e.wt * 0.05) + 0.4
				if cards.bounce then
					peak += 4.5
				end
				if sim.clip then
					peak += 6
				end
				e.airPeak = peak
				if peak > 2.2 then
					event(sim, "air", e.idx, peak)
				end
			end
			local f = clamp((e.s - e.airS0) / math.max(1, e.airS1 - e.airS0), 0, 1)
			e.h = e.airPeak * 4 * f * (1 - f)
		elseif e.air then
			e.air = false
			e.h = 0
			if cards.bounce then
				e.v *= 1.15
			else
				e.v *= 0.95 + e.wt * 0.004
			end
			if e.airPeak > 2.2 then
				event(sim, "land", e.idx)
			end
		else
			e.h = 0
		end
		e.lastTag = ntag

		-- glow windows and bot taps
		if t >= e.glowAt + R.glowDur + R.glowSlack then
			e.glowAt = t + rng:NextNumber(R.glowGapMin, R.glowGapMax)
			e.botTapAt = nil
		end
		if e.bot and t >= e.glowAt and t < e.glowAt + R.glowDur then
			if e.botTapAt == nil then
				if rng:NextNumber() < e.skill then
					e.botTapAt = e.glowAt + rng:NextNumber(0.2, 0.85)
				else
					e.botTapAt = -1
				end
			end
			local tap = e.botTapAt
			if tap and tap > 0 and t >= tap then
				RaceSim.boost(sim, e.idx, tap)
			end
		end

		if e.s >= td.finishS then
			finish(sim, e)
		end
	end

	-- lateral separation for marbles side by side
	for a = 1, #sim.entrants do
		local ea = sim.entrants[a]
		if not ea.finished and not ea.air then
			for b = a + 1, #sim.entrants do
				local eb = sim.entrants[b]
				if not eb.finished and not eb.air and math.abs(ea.s - eb.s) < D then
					local i = clamp(math.floor(ea.s) + 1, 1, n)
					local w = halfW(td, i)
					if w > 1.5 then
						local du = (eb.u - ea.u) * w
						if math.abs(du) < D then
							local push = (D - math.abs(du)) / w * 0.5
							local sgn = du >= 0 and 1 or -1
							if du == 0 then
								sgn = a < b and 1 or -1
							end
							ea.u = clamp(ea.u - sgn * push * 0.5, -1, 1)
							eb.u = clamp(eb.u + sgn * push * 0.5, -1, 1)
						end
					end
				end
			end
		end
	end

	if queued >= 3 and rng:NextNumber() < dt * 2 then
		event(sim, "jam", queued)
	end

	-- done?
	local all = true
	for _, e in ipairs(sim.entrants) do
		if not e.finished then
			all = false
			break
		end
	end
	local winnerT = sim.winnerT
	local timeUp = t > R.maxRaceTime or (winnerT ~= nil and t - winnerT > R.afterWinner)
	if timeUp and not all then
		-- place the stragglers by distance
		local rest: { Entrant } = {}
		for _, e in ipairs(sim.entrants) do
			if not e.finished then
				table.insert(rest, e)
			end
		end
		table.sort(rest, function(a: Entrant, b: Entrant)
			return a.s > b.s
		end)
		for _, e in ipairs(rest) do
			finish(sim, e)
			e.finishT = t + (td.finishS - e.s) / math.max(e.v, 5)
		end
		all = true
	end
	if all then
		-- let the last finisher roll in before calling it
		local settled = true
		for _, e in ipairs(sim.entrants) do
			if e.stopS - e.s > 0.5 then
				settled = false
			end
		end
		local lastT = 0
		for _, e in ipairs(sim.entrants) do
			lastT = math.max(lastT, e.finishT)
		end
		if settled or t - lastT > 2.5 or timeUp then
			sim.done = true
		end
	end
end

-- Results sorted by place.
function RaceSim.results(sim: Sim): { Entrant }
	local out = table.clone(sim.entrants)
	table.sort(out, function(a: Entrant, b: Entrant)
		return a.place < b.place
	end)
	return out
end

function RaceSim.leader(sim: Sim): Entrant?
	local best: Entrant? = nil
	for _, e in ipairs(sim.entrants) do
		if not best or (e.finished and not best.finished) or (e.finished == best.finished and ((e.finished and e.place < best.place) or (not e.finished and e.s > best.s))) then
			best = e
		end
	end
	return best
end

-- Whether entrant e's marble is glowing right now (the boost window shown to players).
function RaceSim.glowing(sim: Sim, e: Entrant): boolean
	return not e.finished and sim.t >= e.glowAt and sim.t < e.glowAt + R.glowDur
end

return RaceSim

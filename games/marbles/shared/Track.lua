--!strict
-- Procedural marble track, generated deterministically from a seed. The server simulates the race as
-- distance `s` along this path and the clients build the geometry from the same seed, so the pieces the
-- players see are exactly what the marbles follow.
--
-- A track is a list of pieces (start gate, ramps, banked turns, jumps, funnels, stairs, splits, waves,
-- boost pads, finish) emitted by a turtle, then resampled to one sample per stud of 3D arc length.
-- Sample i (1-based) sits at s = i - 1. Each sample stores the floor centre (where a marble touches),
-- its frame (forward / right / up, banking included), width and a tag the simulation reacts to.
-- Pure math: no Instances, no services, so it runs the same on server, client and in offline tests.
local Track = {}
Track.debug = nil :: ((string) -> ())?

Track.TAG = {
	NORMAL = 1,
	AIR = 2, -- jump gap: no floor
	FUNNEL = 3, -- spiral inside a funnel bowl
	DROP = 4, -- falling through the funnel hole
	STEP = 5, -- stairs: flat tread
	HOP = 6, -- stairs: falling to the next tread
	SPLIT = 7, -- two lanes around a divider
	PAD = 8, -- boost pad strip
	WAVE = 9, -- rolling hills
	GRID = 10, -- starting grid
	RUNOUT = 11, -- after the finish line
	KICKER = 12, -- jump ramp
	LANDING = 13, -- jump landing ramp
	TURN = 14, -- banked turn
}
local TAG = Track.TAG

export type Piece = { [string]: any }
export type TrackData = {
	seed: number,
	usedSeed: number,
	kind: string,
	n: number,
	length: number,
	px: { number },
	py: { number },
	pz: { number },
	fx: { number },
	fy: { number },
	fz: { number },
	rx: { number },
	ry: { number },
	rz: { number },
	ux: { number },
	uy: { number },
	uz: { number },
	yaw: { number },
	bank: { number },
	width: { number },
	tag: { number },
	piece: { number },
	curv: { number },
	slope: { number },
	pieces: { Piece },
	gateS: number,
	finishS: number,
	endS: number,
	features: { [string]: number },
	minX: number,
	maxX: number,
	minY: number,
	maxY: number,
	minZ: number,
	maxZ: number,
}

export type Opts = {
	kind: string, -- "main" | "practice" | "gp"
	x: number,
	y: number,
	z: number,
	yaw: number, -- heading of the start straight (0 = +Z, pi/2 = +X)
	endY: number, -- floor height at the finish
	length: number, -- target horizontal length (studs)
	width: number,
	box: { number }, -- {minX, maxX, minZ, maxZ} every sample must stay inside
	theme: string?,
}

local PI = math.pi
local sin, cos, abs, sqrt, floor = math.sin, math.cos, math.abs, math.sqrt, math.floor

local function clamp(x: number, a: number, b: number): number
	if x < a then
		return a
	elseif x > b then
		return b
	end
	return x
end

local function wrap(a: number): number
	a = (a + PI) % (2 * PI)
	if a < 0 then
		a += 2 * PI
	end
	return a - PI
end

-- Cubic Hermite: height at t in [0,1] from y0 (slope m0) to y1 (slope m1) over horizontal length L.
local function hermite(t: number, y0: number, y1: number, m0: number, m1: number, L: number): number
	local t2, t3 = t * t, t * t * t
	return (2 * t3 - 3 * t2 + 1) * y0 + (t3 - 2 * t2 + t) * L * m0 + (-2 * t3 + 3 * t2) * y1 + (t3 - t2) * L * m1
end

-- Shape constants shared with the client builder.
Track.FUNNEL_R = 17 -- rim radius
Track.FUNNEL_HOLE = 3.4
Track.FUNNEL_DEPTH = 7.5
Track.FUNNEL_FALL = 8
Track.STEP_DROP = 1.5
Track.STEP_FLAT = 4.5
Track.STEP_HOP = 2.2
Track.RAIL = 0.6 -- rail half thickness counted against usable width
Track.MARBLE_D = 3

type Raw = {
	x: { number },
	y: { number },
	z: { number },
	yaw: { number },
	bank: { number },
	w: { number },
	tag: { number },
	piece: { number },
	s: { number },
}

local function generateOnce(seed: number, o: Opts): TrackData?
	local rng = Random.new(seed)
	local kind = o.kind
	local W = o.width
	local raw: Raw = { x = {}, y = {}, z = {}, yaw = {}, bank = {}, w = {}, tag = {}, piece = {}, s = {} }
	local pieces: { Piece } = {}
	local X, Y, Z, YAW = o.x, o.y, o.z, o.yaw
	local slope = 0 -- current dy/dx (horizontal)
	local S = 0
	local pieceIndex = 0
	local features: { [string]: number } = { jumps = 0, funnels = 0, turns = 0, stairs = 0, splits = 0, pads = 0, waves = 0, ramps = 0 }

	local function push(x: number, y: number, z: number, yaw: number, bank: number, w: number, tag: number)
		local n = #raw.x
		if n > 0 then
			local dx, dy, dz = x - raw.x[n], y - raw.y[n], z - raw.z[n]
			local d = sqrt(dx * dx + dy * dy + dz * dz)
			if d < 1e-4 then
				return
			end
			S += d
		end
		table.insert(raw.x, x)
		table.insert(raw.y, y)
		table.insert(raw.z, z)
		table.insert(raw.yaw, yaw)
		table.insert(raw.bank, bank)
		table.insert(raw.w, w)
		table.insert(raw.tag, tag)
		table.insert(raw.piece, pieceIndex)
		table.insert(raw.s, S)
	end

	local function newPiece(ptype: string): Piece
		pieceIndex += 1
		local p: Piece = { type = ptype, s0 = S, index = pieceIndex }
		pieces[pieceIndex] = p
		return p
	end

	-- Generic run: horizontal length L, total turn A (radians, + = left), height change via Hermite to
	-- y1 with exit slope m1. widthFn/tagFn/bankFn/yExtra are optional per-t overrides.
	local function run(L: number, A: number, y1: number, m1: number, tagFn: (number) -> number, bankMax: number?, widthFn: ((number) -> number)?, yExtra: ((number) -> number)?)
		local steps = math.max(2, math.ceil(L / 0.5))
		local dx = L / steps
		local y0, m0 = Y, slope
		local kmax = A * PI / (2 * L)
		local bm = bankMax or 0
		for k = 1, steps do
			local tm = (k - 0.5) / steps
			local t = k / steps
			local curvature = kmax * sin(PI * tm)
			YAW += curvature * dx
			X += sin(YAW) * dx
			Z += cos(YAW) * dx
			local y = hermite(t, y0, y1, m0, m1, L)
			if yExtra then
				y += yExtra(t)
			end
			local bank = bm * sin(PI * t)
			local w = widthFn and widthFn(t) or W
			push(X, y, Z, YAW, bank, w, tagFn(t))
		end
		Y = y1
		slope = m1
	end

	local function const(tag: number): (number) -> number
		return function(_t: number)
			return tag
		end
	end

	-- Piece emitters -------------------------------------------------------------------------------------

	local function emitStart(drop: number)
		local p = newPiece("start")
		push(X, Y, Z, YAW, 0, W + 4, TAG.GRID)
		-- grid: 18 flat studs, the gate at 18, 6 more flat to the deck edge, then the launch ramp
		run(18, 0, Y, 0, const(TAG.GRID), 0, function()
			return W + 4
		end)
		p.gateS = S
		run(8, 0, Y, 0, const(TAG.NORMAL), 0, function(t)
			return W + 4 - 4 * t
		end)
		local L = 34
		run(L, 0, Y - drop, -math.min(0.12, drop / L), const(TAG.NORMAL))
		p.s1 = S
	end

	local function emitStraight(drop: number, L: number, pads: boolean)
		local p = newPiece(pads and "pads" or "straight")
		run(L, 0, Y - drop, -math.min(0.12, drop / L), function(t)
			if pads and t > 0.38 and t < 0.62 then
				return TAG.PAD
			end
			return TAG.NORMAL
		end)
		p.s1 = S
		if pads then
			p.padS0 = p.s0 + L * 0.38
			p.padS1 = p.s0 + L * 0.62
			features.pads += 1
		end
	end

	local function emitRamp(drop: number, L: number)
		local p = newPiece("ramp")
		run(L, 0, Y - drop, -0.08, const(TAG.NORMAL))
		p.s1 = S
		features.ramps += 1
	end

	local function emitTurn(drop: number, A: number, R: number)
		local p = newPiece("turn")
		local L = abs(A) * R
		local bankMax = math.rad(clamp(20 + (40 - R) * 0.9, 16, 32)) * (A > 0 and 1 or -1)
		run(L, A, Y - drop, -math.min(0.1, drop / L), const(TAG.TURN), bankMax)
		p.s1 = S
		p.angle = A
		p.radius = R
		features.turns += 1
	end

	local function emitWave(drop: number, L: number, humps: number)
		local p = newPiece("wave")
		local amp = 1.8
		run(L, 0, Y - drop, -math.min(0.1, drop / L), const(TAG.WAVE), 0, nil, function(t)
			return amp * sin(2 * PI * humps * t) * sin(PI * t)
		end)
		p.s1 = S
		features.waves += 1
	end

	local function emitSplit(drop: number, L: number)
		local p = newPiece("split")
		local wide = W * 2 + 6
		local tr = 0.16
		run(L, 0, Y - drop, -math.min(0.1, drop / L), const(TAG.SPLIT), 0, function(t)
			if t < tr then
				return W + (wide - W) * (0.5 - 0.5 * cos(PI * t / tr))
			elseif t > 1 - tr then
				return W + (wide - W) * (0.5 - 0.5 * cos(PI * (1 - t) / tr))
			end
			return wide
		end)
		p.s1 = S
		p.wideS0 = p.s0 + L * tr
		p.wideS1 = p.s0 + L * (1 - tr)
		p.wide = wide
		p.padSide = rng:NextNumber() < 0.5 and -1 or 1
		local a, b = p.wideS0 + 4, p.wideS1 - 4
		p.padS0 = a + (b - a) * 0.3
		p.padS1 = a + (b - a) * 0.55
		p.bumpers = { a + (b - a) * 0.2, a + (b - a) * 0.5, a + (b - a) * 0.8 }
		features.splits += 1
	end

	local function emitJump(gap: number, airDrop: number)
		local p = newPiece("jump")
		local up = 0.42
		-- kicker
		run(14, 0, Y + 2.2, up, const(TAG.KICKER))
		p.takeS = S
		-- air: parabola y = y0 + up*x - a x^2, landing airDrop lower
		local y0 = Y
		local a = (up * gap + airDrop) / (gap * gap)
		local steps = math.ceil(gap / 0.5)
		for k = 1, steps do
			local x = gap * k / steps
			X += sin(YAW) * (gap / steps)
			Z += cos(YAW) * (gap / steps)
			push(X, y0 + up * x - a * x * x, Z, YAW, 0, W, TAG.AIR)
		end
		p.landS = S
		local landSlope = up - 2 * a * gap
		Y = y0 + up * gap - a * gap * gap
		slope = landSlope
		local Ll = 24
		local landDrop = Ll * (abs(landSlope) + 0.08) * 0.42
		run(Ll, 0, Y - landDrop, -0.08, function(t)
			return t < 0.6 and TAG.LANDING or TAG.NORMAL
		end, 0, function(t)
			return W + 6 * (1 - t)
		end)
		p.s1 = S
		p.gap = gap
		p.peakY = y0 + up * up / (4 * a)
		features.jumps += 1
	end

	local function emitStairs(nSteps: number)
		local p = newPiece("stairs")
		run(8, 0, Y - 0.3, 0, const(TAG.NORMAL))
		local steps = {}
		local yL = Y
		for k = 1, nSteps do
			local stepS0 = S
			-- tread
			local n = math.ceil(Track.STEP_FLAT / 0.5)
			for _ = 1, n do
				local d = Track.STEP_FLAT / n
				X += sin(YAW) * d
				Z += cos(YAW) * d
				push(X, yL, Z, YAW, 0, W, TAG.STEP)
			end
			table.insert(steps, { s0 = stepS0, s1 = S, y = yL })
			-- hop down to the next tread
			local h = Track.STEP_DROP
			local m = math.ceil(Track.STEP_HOP / 0.4)
			for j = 1, m do
				local f = j / m
				local d = Track.STEP_HOP / m
				X += sin(YAW) * d
				Z += cos(YAW) * d
				push(X, yL - h * f * f, Z, YAW, 0, W, TAG.HOP)
			end
			yL -= h
		end
		Y = yL
		slope = 0
		-- final tread
		local lastS0 = S
		run(7, 0, Y, 0, const(TAG.STEP))
		table.insert(steps, { s0 = lastS0, s1 = S, y = Y })
		p.steps = steps
		p.s1 = S
		features.stairs += 1
	end

	local function emitFunnel(dir: number, exitYaw: number, turns: number)
		local p = newPiece("funnel")
		local R, rh, D = Track.FUNNEL_R, Track.FUNNEL_HOLE, Track.FUNNEL_DEPTH
		local tanT = D / (R - rh)
		local theta = math.atan(tanT)
		local Rs = R - 2.6
		-- lead-in: flatten, bank into the bowl
		local entryDrop = 0.6
		run(14, 0, Y - entryDrop, 0, const(TAG.NORMAL), 0)
		-- the last stretch of the lead-in banks toward the bowl
		local nRaw = #raw.x
		for k = 0, 9 do
			local i = nRaw - k
			if i >= 1 then
				raw.bank[i] = theta * dir * (1 - k / 10)
			end
		end
		local rimY = Y + (R - Rs) * tanT
		local holeY = rimY - D
		local leftX, leftZ = cos(YAW), -sin(YAW)
		local cx = X + leftX * Rs * dir
		local cz = Z + leftZ * Rs * dir
		local phi0 = YAW - dir * PI / 2
		local total = turns * 2 * PI
		local rEnd = rh + 1.3
		local phi = 0
		while phi < total do
			local t = phi / total
			local rho = Rs - (Rs - rEnd) * t ^ 0.85
			phi += 0.5 / rho
			local a = phi0 + dir * phi
			local px = cx + rho * sin(a)
			local pz = cz + rho * cos(a)
			local py = holeY + (rho - rh) * tanT
			push(px, py, pz, a + dir * PI / 2, theta * dir, 2 * (2.4 + Track.MARBLE_D / 2 + Track.RAIL), TAG.FUNNEL)
		end
		p.spiralEndS = S
		local endYaw = phi0 + dir * total + dir * PI / 2
		-- exit heading, expressed close to the spiral's final heading so interpolation stays smooth
		local ex = exitYaw + 2 * PI * math.floor((endYaw - exitYaw) / (2 * PI) + 0.5)
		-- drop through the hole
		local sx, sy, sz = raw.x[#raw.x], raw.y[#raw.y], raw.z[#raw.z]
		local fall = Track.FUNNEL_FALL
		local qy = holeY - fall
		local nd = 18
		for k = 1, nd do
			local f = k / nd
			local hf = math.min(1, f * 1.6)
			push(sx + (cx - sx) * hf, sy + (qy - sy) * f * f, sz + (cz - sz) * hf, endYaw + (ex - endYaw) * f, 0, 4.2, TAG.DROP)
		end
		X, Y, Z, YAW = cx, qy, cz, ex
		slope = 0
		p.dropEndS = S
		-- exit straight under the bowl
		run(26, 0, Y - 0.8, -0.03, const(TAG.NORMAL))
		p.s1 = S
		p.cx, p.cz, p.rimY, p.holeY, p.R, p.rh, p.tanT, p.dir = cx, cz, rimY, holeY, R, rh, tanT, dir
		p.entryPhi = phi0
		p.exitYaw = ex
		p.catchY = qy
		features.funnels += 1
	end

	local function emitFinish(drop: number)
		local p = newPiece("finish")
		run(30, 0, Y - drop, 0, const(TAG.NORMAL))
		p.finishS = S
		run(26, 0, Y, 0, const(TAG.RUNOUT), 0, function(t)
			return W + 6 * math.min(1, t * 3)
		end)
		p.s1 = S
	end

	-- Plan ---------------------------------------------------------------------------------------------

	type Plan = { t: string, w: number, fixed: number, len: number, A: number?, R: number?, humps: number?, gap: number?, airDrop: number?, steps: number?, dir: number?, turns: number?, drop: number? }
	local plan: { Plan } = {}
	local function add(pl: Plan)
		table.insert(plan, pl)
	end

	local specials: { string }
	if kind == "practice" then
		specials = { "jump", rng:NextNumber() < 0.5 and "stairs" or "wave", "pads" }
	elseif kind == "gp" then
		specials = { "jump", "funnel", "split", "stairs", "jump", "wave", "pads" }
	else
		specials = { "jump", "funnel", "split", "stairs" }
		local extra = { "jump", "wave", "pads", "wave", "pads" }
		table.insert(specials, extra[rng:NextInteger(1, #extra)])
		if rng:NextNumber() < 0.5 then
			table.insert(specials, extra[rng:NextInteger(1, #extra)])
		end
	end
	-- shuffle, but keep the funnel out of the first slot
	for i = #specials, 2, -1 do
		local j = rng:NextInteger(1, i)
		specials[i], specials[j] = specials[j], specials[i]
	end
	if specials[1] == "funnel" and #specials > 1 then
		specials[1], specials[2] = specials[2], specials[1]
	end

	local function specialPlan(t: string): Plan
		if t == "jump" then
			local gap = rng:NextNumber(22, 30)
			local airDrop = rng:NextNumber(4.5, 7)
			local landSlope = 0.42 - 2 * ((0.42 * gap + airDrop) / (gap * gap)) * gap
			local landDrop = 24 * (abs(landSlope) + 0.08) * 0.42
			return { t = t, w = 0, fixed = -2.2 + airDrop + landDrop, len = 14 + gap + 24, gap = gap, airDrop = airDrop }
		elseif t == "funnel" then
			local turns = rng:NextNumber(1.3, 1.8)
			local R, rh, D = Track.FUNNEL_R, Track.FUNNEL_HOLE, Track.FUNNEL_DEPTH
			local tanT = D / (R - rh)
			local spiral = ((R - 2.6) - (rh + 1.3)) * tanT
			return { t = t, w = 0, fixed = 0.6 + spiral + Track.FUNNEL_FALL + 0.8, len = 14 + 26 + 4, turns = turns, dir = rng:NextNumber() < 0.5 and 1 or -1 }
		elseif t == "stairs" then
			local n = rng:NextInteger(5, 7)
			return { t = t, w = 0, fixed = 0.3 + n * Track.STEP_DROP, len = 8 + n * (Track.STEP_FLAT + Track.STEP_HOP) + 7, steps = n }
		elseif t == "split" then
			return { t = t, w = 0.8, fixed = 0, len = rng:NextNumber(60, 72) }
		elseif t == "wave" then
			return { t = t, w = 0.6, fixed = 0, len = rng:NextNumber(62, 80), humps = rng:NextInteger(2, 3) }
		else -- pads
			return { t = "pads", w = 1, fixed = 0, len = rng:NextNumber(36, 46) }
		end
	end

	add({ t = "start", w = 2, fixed = 0, len = 60 })
	local horiz = 60
	local target = o.length
	local finishLen = 56
	local si = 1
	local turnsSinceSpecial = 0
	while true do
		local remaining = target - horiz - finishLen
		if remaining < 30 and si > #specials then
			break
		end
		local pl: Plan
		local wantSpecial = si <= #specials and (turnsSinceSpecial >= 1 or remaining < 70 or rng:NextNumber() < 0.3)
		if wantSpecial then
			pl = specialPlan(specials[si]) :: Plan
			si += 1
			turnsSinceSpecial = 0
		else
			local r = rng:NextNumber()
			if r < 0.62 or turnsSinceSpecial == 0 then
				local A = math.rad(rng:NextNumber(55, 115))
				local R = rng:NextNumber(26, 38)
				pl = { t = "turn", w = 1, fixed = 0, len = A * R, A = A, R = R } :: Plan
			elseif r < 0.85 then
				pl = { t = "ramp", w = 4, fixed = 0, len = rng:NextNumber(36, 52) } :: Plan
			else
				pl = { t = "straight", w = 1, fixed = 0, len = rng:NextNumber(24, 36) } :: Plan
			end
			turnsSinceSpecial += 1
		end
		add(pl)
		horiz += pl.len
		if #plan > 40 then
			break
		end
	end
	add({ t = "finish", w = 0.5, fixed = 0, len = finishLen })

	-- Height budget: fixed drops first, the rest spread over flexible pieces by weight (capped by slope).
	local budget = o.y - o.endY
	local function fixedSum(): number
		local f = 0
		for _, pl in ipairs(plan) do
			f += pl.fixed
		end
		return f
	end
	-- too much fixed drop: drop optional specials (stairs first, then extra jumps)
	local guard = 0
	while budget - fixedSum() < 8 and guard < 6 do
		guard += 1
		local removed = false
		for _, name in ipairs({ "stairs", "jump", "funnel" }) do
			for i = #plan, 1, -1 do
				if plan[i].t == name then
					local count = 0
					for _, q in ipairs(plan) do
						if q.t == name then
							count += 1
						end
					end
					if name ~= "funnel" or count > 1 or kind == "practice" then
						table.remove(plan, i)
						removed = true
						break
					end
				end
			end
			if removed then
				break
			end
		end
		if not removed then
			break
		end
	end
	local flex = budget - fixedSum()
	local maxSlope: { [string]: number } = { start = 0.22, straight = 0.12, pads = 0.1, turn = 0.1, ramp = 0.5, wave = 0.1, split = 0.08, finish = 0.06 }
	local wsum = 0
	for _, pl in ipairs(plan) do
		wsum += pl.w
	end
	local k = wsum > 0 and flex / wsum or 0
	local leftover = flex
	for _, pl in ipairs(plan) do
		if pl.w > 0 then
			local cap = (maxSlope[pl.t] or 0.1) * pl.len
			pl.drop = math.min(pl.w * k, cap)
			leftover -= pl.drop :: number
		else
			pl.drop = 0
		end
	end
	-- leftover goes to ramps (and the start), then extra ramps if needed
	local tries = 0
	while leftover > 0.5 and tries < 8 do
		tries += 1
		for _, pl in ipairs(plan) do
			if (pl.t == "ramp" or pl.t == "start") and leftover > 0 then
				local cap = (maxSlope[pl.t] or 0.1) * pl.len
				local room = cap - (pl.drop :: number)
				local d = math.min(room, leftover)
				pl.drop = (pl.drop :: number) + d
				leftover -= d
			end
		end
		if leftover > 0.5 then
			local L = 46
			table.insert(plan, (#plan), { t = "ramp", w = 4, fixed = 0, len = L, drop = 0 } :: Plan)
		end
	end

	-- Emit ---------------------------------------------------------------------------------------------
	local yaw0 = o.yaw
	local box = o.box
	local cxBox = (box[1] + box[2]) / 2
	local czBox = (box[3] + box[4]) / 2
	local halfLat = 0
	do
		-- lateral half-extent of the box across the main axis
		local rxA, rzA = -cos(yaw0), sin(yaw0)
		halfLat = abs(rxA) * (box[2] - box[1]) / 2 + abs(rzA) * (box[4] - box[3]) / 2
	end
	local function lateral(): number
		-- signed distance right of the box centre line
		return (X - cxBox) * -cos(yaw0) + (Z - czBox) * sin(yaw0)
	end
	local MAXDEV = math.rad(78)

	for _, pl in ipairs(plan) do
		local drop = pl.drop or 0
		if pl.t == "start" then
			emitStart(drop)
		elseif pl.t == "straight" then
			emitStraight(drop, pl.len, false)
		elseif pl.t == "pads" then
			emitStraight(drop, pl.len, true)
		elseif pl.t == "ramp" then
			emitRamp(drop, pl.len)
		elseif pl.t == "wave" then
			emitWave(drop, pl.len, pl.humps or 2)
		elseif pl.t == "split" then
			emitSplit(drop, pl.len)
		elseif pl.t == "jump" then
			emitJump(pl.gap or 26, pl.airDrop or 5)
		elseif pl.t == "stairs" then
			emitStairs(pl.steps or 5)
		elseif pl.t == "funnel" then
			local lat = lateral()
			-- exit heading: back toward the centre line
			local want = clamp(-lat / halfLat * 1.4, -1, 1) * math.rad(50) + rng:NextNumber(-0.25, 0.25)
			-- positive deviation turns left, which moves toward negative lateral; flip so it heads home
			local exitDev = clamp(lat > 0 and abs(want) or -abs(want), -math.rad(55), math.rad(55))
			if abs(lat) < halfLat * 0.25 then
				exitDev = rng:NextNumber(-0.5, 0.5)
			end
			-- funnel centre goes to the side with more room
			local dir = pl.dir or 1
			if lat > halfLat * 0.3 then
				dir = 1 -- centre on the left (toward centre line)
			elseif lat < -halfLat * 0.3 then
				dir = -1
			end
			emitFunnel(dir, yaw0 + exitDev, pl.turns or 1.5)
		elseif pl.t == "turn" then
			local A = pl.A or 1
			local lat = lateral()
			local dev = wrap(YAW - yaw0)
			local sign = rng:NextNumber() < 0.5 and 1 or -1
			if abs(lat) > halfLat * 0.3 then
				sign = lat > 0 and 1 or -1 -- right of the centre line: turn left (and vice versa)
			end
			-- room before the heading leaves the allowed cone; flip if there is too little
			local room = MAXDEV - sign * dev
			if room < math.rad(25) then
				sign = -sign
				room = MAXDEV - sign * dev
			end
			A = math.min(A, room)
			emitTurn(drop, sign * A, pl.R or 30)
		elseif pl.t == "finish" then
			emitFinish(drop)
		end
	end

	-- Validate -----------------------------------------------------------------------------------------
	local nr = #raw.x
	local minY = math.huge
	for i = 1, nr do
		local x, y, z = raw.x[i], raw.y[i], raw.z[i]
		local m = raw.w[i] / 2 + 2
		if raw.tag[i] == TAG.FUNNEL then
			m = Track.FUNNEL_R + 3
		end
		if raw.piece[i] > 1 and (x - m < box[1] or x + m > box[2] or z - m < box[3] or z + m > box[4]) then
			local dbg = Track.debug
			if dbg then
				dbg(string.format("out of box at raw %d (%.0f, %.0f) piece %s", i, x, z, pieces[raw.piece[i]].type))
			end
			return nil
		end
		if raw.tag[i] ~= TAG.DROP and raw.tag[i] ~= TAG.AIR and y < minY then
			minY = y
		end
	end
	if minY < o.endY - 1.5 then
		local dbg = Track.debug
		if dbg then
			dbg(string.format("too low %.1f", minY))
		end
		return nil
	end
	-- no two distant sections may overlap (spatial hash on 12-stud cells)
	local cell = 12
	local grid: { [number]: { number } } = {}
	local function key(cx: number, cz: number): number
		return (cx + 2000) * 4096 + (cz + 2000)
	end
	for i = 1, nr, 2 do
		local kx, kz = floor(raw.x[i] / cell), floor(raw.z[i] / cell)
		local kk = key(kx, kz)
		local list = grid[kk]
		if not list then
			list = {}
			grid[kk] = list
		end
		table.insert(list, i)
	end
	for i = 1, nr, 2 do
		local kx, kz = floor(raw.x[i] / cell), floor(raw.z[i] / cell)
		for ox = -2, 2 do
			for oz = -2, 2 do
				local list = grid[key(kx + ox, kz + oz)]
				if list then
					for _, j in ipairs(list) do
						if j > i and raw.piece[j] ~= raw.piece[i] and abs(raw.piece[j] - raw.piece[i]) > 1 then
							local dx, dz = raw.x[j] - raw.x[i], raw.z[j] - raw.z[i]
							local need = (raw.w[i] + raw.w[j]) / 2 + 4
							if raw.tag[i] == TAG.FUNNEL or raw.tag[j] == TAG.FUNNEL then
								need = Track.FUNNEL_R + 10
							end
							if dx * dx + dz * dz < need * need and abs(raw.y[j] - raw.y[i]) < 14 then
								local dbg = Track.debug
								if dbg then
									dbg(string.format("overlap %s/%s", pieces[raw.piece[i]].type, pieces[raw.piece[j]].type))
								end
								return nil
							end
						end
					end
				end
			end
		end
	end

	-- Resample to 1 stud ---------------------------------------------------------------------------------
	local L = raw.s[nr]
	local n = floor(L) + 1
	local td: TrackData = {
		seed = seed,
		usedSeed = seed,
		kind = kind,
		n = n,
		length = L,
		px = table.create(n, 0),
		py = table.create(n, 0),
		pz = table.create(n, 0),
		fx = table.create(n, 0),
		fy = table.create(n, 0),
		fz = table.create(n, 0),
		rx = table.create(n, 0),
		ry = table.create(n, 0),
		rz = table.create(n, 0),
		ux = table.create(n, 0),
		uy = table.create(n, 0),
		uz = table.create(n, 0),
		yaw = table.create(n, 0),
		bank = table.create(n, 0),
		width = table.create(n, 0),
		tag = table.create(n, 0),
		piece = table.create(n, 0),
		curv = table.create(n, 0),
		slope = table.create(n, 0),
		pieces = pieces,
		gateS = 0,
		finishS = 0,
		endS = 0,
		features = features,
		minX = math.huge,
		maxX = -math.huge,
		minY = math.huge,
		maxY = -math.huge,
		minZ = math.huge,
		maxZ = -math.huge,
	}
	local j = 1
	for i = 1, n do
		local s = i - 1
		while j < nr - 1 and raw.s[j + 1] < s do
			j += 1
		end
		local s0, s1 = raw.s[j], raw.s[j + 1]
		local t = s1 > s0 and clamp((s - s0) / (s1 - s0), 0, 1) or 0
		local function lerp(a: { number }): number
			return a[j] + (a[j + 1] - a[j]) * t
		end
		td.px[i] = lerp(raw.x)
		td.py[i] = lerp(raw.y)
		td.pz[i] = lerp(raw.z)
		td.yaw[i] = lerp(raw.yaw)
		td.bank[i] = lerp(raw.bank)
		td.width[i] = lerp(raw.w)
		local jj = t < 0.5 and j or j + 1
		td.tag[i] = raw.tag[jj]
		td.piece[i] = raw.piece[jj]
		td.minX = math.min(td.minX, td.px[i])
		td.maxX = math.max(td.maxX, td.px[i])
		td.minY = math.min(td.minY, td.py[i])
		td.maxY = math.max(td.maxY, td.py[i])
		td.minZ = math.min(td.minZ, td.pz[i])
		td.maxZ = math.max(td.maxZ, td.pz[i])
	end
	-- frames, curvature, slope
	for i = 1, n do
		local a, b = math.max(1, i - 1), math.min(n, i + 1)
		local dx, dy, dz = td.px[b] - td.px[a], td.py[b] - td.py[a], td.pz[b] - td.pz[a]
		local m = sqrt(dx * dx + dy * dy + dz * dz)
		if m < 1e-6 then
			dx, dy, dz, m = sin(td.yaw[i]), 0, cos(td.yaw[i]), 1
		end
		dx, dy, dz = dx / m, dy / m, dz / m
		td.fx[i], td.fy[i], td.fz[i] = dx, dy, dz
		local yaw = td.yaw[i]
		local hx, hz = -cos(yaw), sin(yaw) -- horizontal right
		-- up0 = right_h x fwd
		local u0x = 0 * dz - hz * dy
		local u0y = hz * dx - hx * dz
		local u0z = hx * dy - 0 * dx
		local um = sqrt(u0x * u0x + u0y * u0y + u0z * u0z)
		if um < 1e-6 or td.tag[i] == TAG.DROP then
			u0x, u0y, u0z, um = 0, 1, 0, 1
		end
		u0x, u0y, u0z = u0x / um, u0y / um, u0z / um
		local bk = td.bank[i]
		local cb, sb = cos(bk), sin(bk)
		td.rx[i], td.ry[i], td.rz[i] = hx * cb + u0x * sb, u0y * sb, hz * cb + u0z * sb
		td.ux[i], td.uy[i], td.uz[i] = u0x * cb - hx * sb, u0y * cb, u0z * cb - hz * sb
		local tg = td.tag[i]
		if tg == TAG.DROP or tg == TAG.AIR then
			td.curv[i] = 0
		else
			td.curv[i] = (td.yaw[b] - td.yaw[a]) / math.max(1, b - a)
		end
		td.slope[i] = dy
	end
	for _, p in ipairs(pieces) do
		p.s1 = p.s1 or L
		if p.type == "start" then
			td.gateS = p.gateS
		elseif p.type == "finish" then
			td.finishS = p.finishS
		end
	end
	td.endS = L - 2
	return td
end

-- Generate a track. If a seed's layout fails validation the next seed is tried, identically everywhere.
function Track.generate(seed: number, o: Opts): TrackData
	for k = 0, 60 do
		local td = generateOnce(seed + k * 7919, o)
		if td then
			td.seed = seed
			td.usedSeed = seed + k * 7919
			return td
		end
	end
	-- last resort: a short safe track (never expected)
	local safe = table.clone(o)
	safe.length = 300
	safe.kind = "practice"
	local td = generateOnce(seed, safe)
	assert(td, "track generation failed")
	return td
end

-- Interpolated sample at distance s: position (floor centre) and frame vectors as numbers.
function Track.at(td: TrackData, s: number): (number, number, number, number, number, number, number, number, number, number)
	local n = td.n
	if s <= 0 then
		s = 0
	elseif s >= n - 1 then
		s = n - 1.0001
	end
	local i = floor(s) + 1
	local t = s - (i - 1)
	local i2 = math.min(n, i + 1)
	local function l(a: { number }): number
		return a[i] + (a[i2] - a[i]) * t
	end
	return l(td.px), l(td.py), l(td.pz), l(td.rx), l(td.ry), l(td.rz), l(td.ux), l(td.uy), l(td.uz), l(td.width)
end

function Track.tagAt(td: TrackData, s: number): number
	local i = math.clamp(floor(s) + 1, 1, td.n)
	return td.tag[i]
end

-- World position of a marble centre: lateral u in [-1, 1], extra height h, radius r.
function Track.place(td: TrackData, s: number, u: number, h: number, r: number): (number, number, number)
	local x, y, z, rx, ry, rz, ux, uy, uz, w = Track.at(td, s)
	local half = math.max(0, w / 2 - r - Track.RAIL)
	local tag = Track.tagAt(td, s)
	if tag == TAG.DROP then
		ux, uy, uz = 0, 1, 0
	end
	return x + rx * u * half + ux * (r + h), y + ry * u * half + uy * (r + h), z + rz * u * half + uz * (r + h)
end

-- Short feature list for the pick screen ("2 JUMPS · FUNNEL · STAIRS").
function Track.describe(td: TrackData): { string }
	local f = td.features
	local out = {}
	local function addf(n: number, one: string, many: string)
		if n == 1 then
			table.insert(out, one)
		elseif n > 1 then
			table.insert(out, n .. " " .. many)
		end
	end
	addf(f.jumps, "JUMP", "JUMPS")
	addf(f.funnels, "FUNNEL", "FUNNELS")
	addf(f.stairs, "STAIRS", "STAIRS")
	addf(f.splits, "SPLIT", "SPLITS")
	addf(f.turns, "TURN", "TURNS")
	addf(f.waves, "HILLS", "HILLS")
	addf(f.pads, "BOOST PADS", "BOOST PADS")
	return out
end

return Track

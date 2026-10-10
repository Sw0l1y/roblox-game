--!strict
-- Builds a race track's geometry on the client from the same seed the server simulates, so the floors,
-- banked turns, jumps, funnels, stairs and splits are exactly where the marbles roll. Chunky bright pieces
-- (one colour per piece from the theme), white rails, candy-striped rails on turns, neon chevron boost
-- pads, a hoop over every jump, a candy pinwheel funnel bowl with a glass drop tube, a start arch with
-- countdown lights and a gate that drops at GO, and a checkered finish arch. Pillars hold it all up from
-- the tabletop, skipping anywhere another part of the track runs underneath.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Track = require(Shared:WaitForChild("Track"))

local TrackView = {}

local TAG = Track.TAG
local V3 = Vector3.new
local CF = CFrame.new
local abs, sin, cos, max, min = math.abs, math.sin, math.cos, math.max, math.min
local PI = math.pi
local THICK = 1.2
local RAIL_W = 0.8
local RAIL_UP = 1.5
local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromRGB(46, 50, 76)
local NEON = Enum.Material.Neon
local PER_FRAME = 140

export type View = {
	kind: string,
	seed: number,
	theme: string,
	td: Track.TrackData,
	model: Model,
	ready: boolean,
	dead: boolean,
	parts: number,
	lights: { BasePart },
	gateBar: BasePart?,
	gateCf: CFrame,
	startCf: CFrame,
	finishCf: CFrame,
	funnels: { { cx: number, cz: number, rimY: number, holeY: number, s0: number, s1: number } },
}

type Theme = { floors: { Color3 }, rail: Color3, pillars: { Color3 }, accent: Color3 }

local function themeOf(name: string): Theme
	local t = (Config.TrackThemes :: any)[name] or Config.TrackThemes.Classic
	return t :: Theme
end

local function wrap(a: number): number
	a = (a + PI) % (2 * PI)
	if a < 0 then
		a += 2 * PI
	end
	return a - PI
end

-- Sample accessors (index i = s + 1) ------------------------------------------------------------------------
local function P(td: Track.TrackData, i: number): Vector3
	return V3(td.px[i], td.py[i], td.pz[i])
end
local function R(td: Track.TrackData, i: number): Vector3
	return V3(td.rx[i], td.ry[i], td.rz[i])
end
local function idx(td: Track.TrackData, s: number): number
	return math.clamp(math.floor(s + 0.5) + 1, 1, td.n)
end

-- Floor frame at distance s: position on the floor centre line, right and up.
local function frameAt(td: Track.TrackData, s: number): (Vector3, Vector3, Vector3, number)
	local x, y, z, rx, ry, rz, ux, uy, uz, w = Track.at(td, s)
	return V3(x, y, z), V3(rx, ry, rz).Unit, V3(ux, uy, uz).Unit, w
end

local function horizRight(yaw: number): Vector3
	return V3(-cos(yaw), 0, sin(yaw))
end

-- Builder -----------------------------------------------------------------------------------------------------
type Builder = { view: View, folder: Instance, count: number }

local function part(b: Builder, size: Vector3, cf: CFrame, color: Color3, opts: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	if opts then
		for k, v in pairs(opts) do
			(p :: any)[k] = v
		end
	end
	p.Parent = b.folder
	b.count += 1
	b.view.parts += 1
	if b.count % PER_FRAME == 0 then
		task.wait()
	end
	return p
end

-- Upright cylinder with its base centre at `pos`.
local function cyl(b: Builder, pos: Vector3, height: number, dia: number, color: Color3, opts: { [string]: any }?): Part
	local p = part(b, V3(height, dia, dia), CF(pos + V3(0, height / 2, 0)) * CFrame.Angles(0, 0, PI / 2), color, opts)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(b: Builder, pos: Vector3, dia: number, color: Color3, opts: { [string]: any }?): Part
	local p = part(b, V3(dia, dia, dia), CF(pos), color, opts)
	p.Shape = Enum.PartType.Ball
	return p
end

local function signGui(p: BasePart, text: string, color: Color3, faces: { Enum.NormalId })
	for _, face in ipairs(faces) do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 30
		sg.LightInfluence = 0
		sg.MaxDistance = 400
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(0.94, 0.86)
		l.Position = UDim2.fromScale(0.03, 0.07)
		l.Font = Enum.Font.LuckiestGuy
		l.TextScaled = true
		l.Text = text
		l.TextColor3 = color
		local s = Instance.new("UIStroke")
		s.Thickness = 4
		s.Color = Color3.fromRGB(28, 30, 48)
		s.Parent = l
		l.Parent = sg
		sg.Parent = p
	end
end

-- Chevron arrow ("^" pointing down the track) on the floor at s, lateral offset `lo`, width `w`.
local function chevron(b: Builder, td: Track.TrackData, s: number, lo: number, w: number, color: Color3)
	local pos, right, up = frameAt(td, s)
	local fwd = up:Cross(right).Unit
	-- local frame: X right, Y up, Z back
	local base = CFrame.fromMatrix(pos + right * lo + up * 0.08, right, up, -fwd)
	local h = w * 0.35
	local beta = math.atan2(h, w / 2)
	local L = math.sqrt((w / 2) ^ 2 + h * h)
	part(b, V3(L, 0.2, 0.9), base * CF(-w / 4, 0, 0) * CFrame.Angles(0, beta, 0), color, { Material = NEON })
	part(b, V3(L, 0.2, 0.9), base * CF(w / 4, 0, 0) * CFrame.Angles(0, -beta, 0), color, { Material = NEON })
end

-- Is the column of air below (x, z) from topY down to the table clear of other track sections?
type Hash = { [number]: { number } }
local CELL = 16
local function hkey(cx: number, cz: number): number
	return (cx + 4000) * 8192 + (cz + 4000)
end

local function buildHash(td: Track.TrackData): Hash
	local h: Hash = {}
	for i = 1, td.n do
		local tg = td.tag[i]
		if tg ~= TAG.AIR and tg ~= TAG.DROP then
			local k = hkey(math.floor(td.px[i] / CELL), math.floor(td.pz[i] / CELL))
			local list = h[k]
			if not list then
				list = {}
				h[k] = list
			end
			table.insert(list, i)
		end
	end
	return h
end

local function columnClear(td: Track.TrackData, hash: Hash, x: number, z: number, topY: number, selfS: number, radius: number, ownFunnel: Track.Piece?): boolean
	local kx, kz = math.floor(x / CELL), math.floor(z / CELL)
	for ox = -2, 2 do
		for oz = -2, 2 do
			local list = hash[hkey(kx + ox, kz + oz)]
			if list then
				for _, j in ipairs(list) do
					if td.tag[j] ~= TAG.FUNNEL and abs((j - 1) - selfS) > 12 and td.py[j] < topY - 0.5 then
						local dx, dz = td.px[j] - x, td.pz[j] - z
						local need = td.width[j] / 2 + radius + 1.5
						if dx * dx + dz * dz < need * need then
							return false
						end
					end
				end
			end
		end
	end
	-- funnel bowls (their rims reach far beyond the spiral samples)
	for _, p in ipairs(td.pieces) do
		if p.type == "funnel" and p ~= ownFunnel and (selfS < (p.s0 :: number) or selfS > (p.s1 :: number)) then
			-- a column next to someone else's bowl would pass through it
			local dx, dz = (p.cx :: number) - x, (p.cz :: number) - z
			local rr = Track.FUNNEL_R + radius + 2.5
			if dx * dx + dz * dz < rr * rr and topY > (p.catchY :: number) - 2 then
				return false
			end
		end
	end
	-- the lobby book tower
	if x > -70 and x < 70 and z > -70 and z < 55 then
		return false
	end
	return true
end

-- Generic floor + rails ------------------------------------------------------------------------------------
local function generic(tag: number): boolean
	return tag ~= TAG.AIR and tag ~= TAG.DROP and tag ~= TAG.FUNNEL and tag ~= TAG.STEP and tag ~= TAG.HOP
end

local function buildFloors(b: Builder, td: Track.TrackData, th: Theme)
	local n = td.n
	local startPiece = td.piece[1]
	-- funnel lead-ins open into the bowl: no rails on their last few studs
	local noRail: { [number]: boolean } = {}
	for _, p in ipairs(td.pieces) do
		if p.type == "funnel" then
			for s = math.floor(p.s0 + 14 - 7), math.floor(p.s0 + 14) do
				noRail[s + 1] = true
			end
		end
	end
	local i = 1
	while i < n do
		if not generic(td.tag[i]) then
			i += 1
			continue
		end
		-- run of generic samples within one piece
		local pc = td.piece[i]
		local j = i
		while j < n and generic(td.tag[j + 1]) and td.piece[j + 1] == pc do
			j += 1
		end
		local seam = false
		if j < n and td.piece[j + 1] ~= pc and generic(td.tag[j + 1]) then
			j += 1 -- close the seam to the next piece
			seam = true
		end
		local piece = td.pieces[pc]
		local ptype = piece and piece.type or ""
		local floorCol = th.floors[(pc - 1) % #th.floors + 1]
		local a = i
		local slabN = 0
		while a < j do
			local bb = a + 1
			while bb < j and bb - a < 8 do
				local nb = bb + 1
				if abs(td.yaw[nb] - td.yaw[a]) > 0.07 or abs(td.slope[nb] - td.slope[a]) > 0.045 or abs(td.bank[nb] - td.bank[a]) > 0.06 or abs(td.width[nb] - td.width[a]) > 1.2 then
					break
				end
				bb = nb
			end
			slabN += 1
			local pa, pb = P(td, a), P(td, bb)
			local chord = pb - pa
			local len = chord.Magnitude
			if len > 0.05 then
				local fwd = chord.Unit
				local right = R(td, a) + R(td, bb)
				right = (right - fwd * right:Dot(fwd)).Unit
				local up = right:Cross(fwd).Unit
				local wa, wb = td.width[a], td.width[bb]
				local w = max(wa, wb)
				local wavg = (wa + wb) / 2
				local extra = abs(td.yaw[bb] - td.yaw[a]) * w / 2 + 0.35
				local mid = (pa + pb) / 2
				local frame = CFrame.fromMatrix(mid, right, up, -fwd)
				local onDeck = pc == startPiece and (a - 1) <= td.gateS + 8
				part(b, V3(w, THICK, len + extra), frame * CF(0, -THICK / 2, 0), floorCol, { CastShadow = true, CanCollide = onDeck })
				local railCol = th.rail
				if ptype == "turn" and slabN % 2 == 0 then
					railCol = th.accent
				end
				if not (noRail[a] or noRail[bb]) then
					for _, side in ipairs({ -1, 1 }) do
						local h = THICK + RAIL_UP
						part(b, V3(RAIL_W, h, len + extra), frame * CF(side * (wavg / 2 + RAIL_W / 2), RAIL_UP - h / 2, 0), railCol, { CanCollide = onDeck })
					end
				end
			end
			a = bb
		end
		i = if seam then j else j + 1
	end
end

-- Pieces ---------------------------------------------------------------------------------------------------
local function buildStart(b: Builder, view: View, td: Track.TrackData, th: Theme)
	local gs = td.gateS
	local pos, right, up, w = frameAt(td, gs)
	local fwd = up:Cross(right).Unit
	local gateCf = CFrame.fromMatrix(pos, right, up, -fwd)
	view.gateCf = gateCf
	view.startCf = gateCf
	-- grid lane lines and start line
	local half = w / 2 - Track.MARBLE_D / 2 - Track.RAIL
	for _, u in ipairs({ -0.46, 0, 0.46 }) do
		local p0 = frameAt(td, 1)
		local p1 = frameAt(td, gs - 1)
		local midS = (gs) / 2
		local mp, mr, mu = frameAt(td, midS)
		local len = (p1 - p0).Magnitude
		part(b, V3(0.3, 0.1, len), CFrame.fromMatrix(mp + mr * u * half + mu * 0.04, mr, mu, -mu:Cross(mr).Unit), WHITE)
	end
	part(b, V3(w, 0.1, 0.9), gateCf * CF(0, 0.05, 0), WHITE)
	-- arch
	local postH = 12
	for _, side in ipairs({ -1, 1 }) do
		local base = (gateCf * CF(side * (w / 2 + 1.4), -THICK, 0)).Position
		cyl(b, base, postH + THICK, 1.8, th.rail, { CastShadow = true })
		ball(b, base + V3(0, postH + THICK + 0.4, 0), 2.4, th.accent, { Material = NEON })
	end
	local bar = part(b, V3(w + 5, 2.6, 1.6), gateCf * CF(0, postH - 0.6, 0), th.accent, { CastShadow = true })
	local title = view.kind == "practice" and "WARM-UP HEAT" or (view.kind == "gp" and "🏁 GRAND PRIX 🏁" or "MARBLE MAYHEM")
	signGui(bar, title, WHITE, { Enum.NormalId.Front, Enum.NormalId.Back })
	-- countdown lights
	view.lights = {}
	for k = -1, 1 do
		local housing = part(b, V3(2.8, 2.8, 1.2), gateCf * CF(k * 3.6, postH - 3.4, 0), DARK)
		local l = ball(b, (housing.CFrame * CF(0, 0, 0.45)).Position, 2.1, Color3.fromRGB(70, 70, 86), { Material = Enum.Material.SmoothPlastic })
		table.insert(view.lights, l)
	end
	-- the gate bar that drops at GO
	view.gateBar = part(b, V3(w - 0.2, 2.4, 0.7), gateCf * CF(0, 1.2, -0.6), Color3.fromHex("#FF4F5E"), { CastShadow = true })
	-- grid backboard behind the last row
	local bp, br, bu, bw = frameAt(td, 0.5)
	local bf = bu:Cross(br).Unit
	part(b, V3(bw + 1.6, 3, 1), CFrame.fromMatrix(bp + bu * 1.5 - bf * 0.6, br, bu, -bf), th.rail)
end

local function buildFinish(b: Builder, view: View, td: Track.TrackData, th: Theme)
	local fs = td.finishS
	local pos, right, up, w = frameAt(td, fs)
	local fwd = up:Cross(right).Unit
	local cf = CFrame.fromMatrix(pos, right, up, -fwd)
	view.finishCf = cf
	-- checkered strip
	local nSq = 8
	local sq = w / nSq
	for row = 0, 1 do
		for k = 0, nSq - 1 do
			local col = (k + row) % 2 == 0 and WHITE or Color3.fromRGB(30, 30, 40)
			part(b, V3(sq, 0.1, sq), cf * CF(-w / 2 + sq * (k + 0.5), 0.05, (row - 0.5) * sq), col)
		end
	end
	local postH = 13
	for _, side in ipairs({ -1, 1 }) do
		local base = (cf * CF(side * (w / 2 + 1.6), -THICK, 0)).Position
		cyl(b, base, postH + THICK, 2, WHITE, { CastShadow = true })
		for k = 0, 2 do
			ball(b, base + V3(side * 0.8, postH + THICK + 0.8 + k * 1.9, (k - 1) * 0.9), 2.6, th.floors[(k % #th.floors) + 1])
		end
	end
	local banner = part(b, V3(w + 6, 3.6, 0.8), cf * CF(0, postH - 1, 0), Color3.fromRGB(30, 30, 40), { CastShadow = true })
	signGui(banner, "FINISH", WHITE, { Enum.NormalId.Front, Enum.NormalId.Back })
	-- checker trim on the banner
	for k = 0, 9 do
		local col = k % 2 == 0 and WHITE or th.accent
		part(b, V3((w + 6) / 10, 0.6, 0.9), cf * CF(-(w + 6) / 2 + (w + 6) / 10 * (k + 0.5), postH + 1.1, 0), col, { Material = k % 2 == 0 and Enum.Material.SmoothPlastic or NEON })
	end
	-- runout end bumper
	local ep, er, eu, ew = frameAt(td, td.length - 0.5)
	local ef = eu:Cross(er).Unit
	part(b, V3(ew + 2, 3.2, 1.6), CFrame.fromMatrix(ep + eu * 1.2 + ef * 0.5, er, eu, -ef), th.accent, { CastShadow = true })
	part(b, V3(ew + 2.2, 0.8, 1.7), CFrame.fromMatrix(ep + eu * 2.6 + ef * 0.5, er, eu, -ef), WHITE)
end

local function buildPads(b: Builder, td: Track.TrackData, s0: number, s1: number, lo: number, w: number)
	local s = s0 + 1
	local k = 0
	while s < s1 - 0.5 do
		k += 1
		chevron(b, td, s, lo, w, k % 2 == 0 and Color3.fromRGB(255, 210, 60) or Color3.fromRGB(255, 120, 40))
		s += 3
	end
end

local function buildJump(b: Builder, td: Track.TrackData, p: Track.Piece, th: Theme)
	local takeS, landS = p.takeS :: number, p.landS :: number
	-- neon lip on the kicker edge
	local pos, right, up, w = frameAt(td, takeS - 0.6)
	local fwd = up:Cross(right).Unit
	part(b, V3(w, 0.3, 1.2), CFrame.fromMatrix(pos + up * 0.12, right, up, -fwd), th.accent, { Material = NEON })
	-- arrows up the kicker
	for k = 1, 3 do
		chevron(b, td, takeS - 12 + k * 3, 0, w * 0.5, WHITE)
	end
	-- the hoop over the gap
	local midS = (takeS + landS) / 2
	local mi = idx(td, midS)
	local yaw = td.yaw[mi]
	local f = V3(sin(yaw), 0, cos(yaw))
	local rgt = horizRight(yaw)
	local centre = P(td, mi) + V3(0, 5.5, 0)
	local Rh = 10.5
	local N = 18
	local seg = 2 * PI * Rh / N * 1.08
	for k = 0, N - 1 do
		local a = (k + 0.5) / N * 2 * PI
		local radial = rgt * cos(a) + V3(0, 1, 0) * sin(a)
		local tangent = -rgt * sin(a) + V3(0, 1, 0) * cos(a)
		local pt = centre + radial * Rh
		local col = k % 2 == 0 and th.accent or WHITE
		part(b, V3(seg, 1, 1), CFrame.fromMatrix(pt, tangent, f), col, { Material = k % 2 == 0 and NEON or Enum.Material.SmoothPlastic })
	end
	-- landing target ring on the landing ramp
	local lp, lr, lu, lw = frameAt(td, landS + 3)
	local lf = lu:Cross(lr).Unit
	part(b, V3(lw * 0.7, 0.12, 1), CFrame.fromMatrix(lp + lu * 0.06, lr, lu, -lf), WHITE)
end

local function buildStairs(b: Builder, td: Track.TrackData, p: Track.Piece, th: Theme)
	local steps = p.steps :: { { s0: number, s1: number, y: number } }
	for k, st in ipairs(steps) do
		local sa = k == 1 and st.s0 or steps[k - 1].s1
		local sb = st.s1
		local ia, ib = idx(td, sa), idx(td, sb)
		local pa, pb = P(td, ia), P(td, ib)
		pa = V3(pa.X, 0, pa.Z)
		pb = V3(pb.X, 0, pb.Z)
		local len = (pb - pa).Magnitude + 0.1
		local yaw = td.yaw[ia]
		local right = horizRight(yaw)
		local w = td.width[ia]
		local h = Track.STEP_DROP + THICK + 0.3
		local mid = (pa + pb) / 2
		local cf = CFrame.fromMatrix(V3(mid.X, st.y - h / 2, mid.Z), right, V3(0, 1, 0))
		local col = th.floors[(k - 1) % #th.floors + 1]
		part(b, V3(w, h, len), cf, col, { CastShadow = true })
		-- nosing stripe
		local fwd = V3(sin(yaw), 0, cos(yaw))
		part(b, V3(w, 0.12, 0.6), CFrame.fromMatrix(V3(pb.X, st.y + 0.04, pb.Z) - fwd * 0.4, right, V3(0, 1, 0)), WHITE)
		for _, side in ipairs({ -1, 1 }) do
			local rh = h + RAIL_UP
			part(b, V3(RAIL_W, rh, len), cf * CF(side * (w / 2 + RAIL_W / 2), RAIL_UP / 2, 0), k % 2 == 0 and th.accent or th.rail)
		end
	end
end

local function buildFunnel(b: Builder, view: View, td: Track.TrackData, p: Track.Piece, th: Theme)
	local cx, cz = p.cx :: number, p.cz :: number
	local rimY, holeY = p.rimY :: number, p.holeY :: number
	local Rr, rh, tanT = p.R :: number, p.rh :: number, p.tanT :: number
	local dir = p.dir :: number
	local theta = math.atan(tanT)
	local catchY = p.catchY :: number
	table.insert(view.funnels, { cx = cx, cz = cz, rimY = rimY, holeY = holeY, s0 = p.s0 :: number, s1 = p.s1 :: number })
	local up = V3(0, 1, 0)
	local c1 = th.floors[(p.index - 1) % #th.floors + 1]
	local c2 = WHITE
	local thick = 0.6
	local function ring(r0: number, r1: number, N: number, offset: number)
		local slant = (r1 - r0) / cos(theta)
		local width = 2 * r1 * sin(PI / N) * 1.12
		local rm = (r0 + r1) / 2
		for k = 0, N - 1 do
			local a = (k + 0.5 + offset) / N * 2 * PI
			local er = V3(sin(a), 0, cos(a))
			local t = V3(cos(a), 0, -sin(a))
			local nrm = up * cos(theta) - er * sin(theta)
			local pos = V3(cx, holeY + (rm - rh) * tanT, cz) + er * rm
			local col = k % 2 == 0 and c1 or c2
			part(b, V3(width, thick, slant + 0.5), CFrame.fromMatrix(pos - nrm * thick / 2, t, nrm), col, { CastShadow = true })
		end
	end
	ring(rh, 9.5, 12, 0)
	ring(9.5, Rr + 0.3, 24, 0.5)
	-- rim (open where the chute comes in)
	local phi0 = p.entryPhi :: number
	local N = 26
	for k = 0, N - 1 do
		local a = (k + 0.5) / N * 2 * PI
		local d = wrap(a - phi0) * dir
		if not (d > -math.rad(80) and d < math.rad(14)) then
			local er = V3(sin(a), 0, cos(a))
			local t = V3(cos(a), 0, -sin(a))
			local pos = V3(cx, rimY + 0.9, cz) + er * (Rr + 0.6)
			part(b, V3(2 * PI * (Rr + 0.6) / N * 1.06, 2.4, 1), CFrame.fromMatrix(pos, t, up), k % 2 == 0 and th.rail or th.accent, { CastShadow = true })
		end
	end
	-- glass drop tube and catch tray
	local tubeTop = holeY - 0.4
	local tubeBot = catchY + 3.2
	if tubeTop > tubeBot then
		cyl(b, V3(cx, tubeBot, cz), tubeTop - tubeBot, rh * 2 + 0.8, Color3.fromRGB(200, 236, 255), { Material = Enum.Material.Glass, Transparency = 0.65 })
	end
	local tray = cyl(b, V3(cx, catchY - 1, cz), 1, 9, th.accent, { CastShadow = true })
	tray.Name = "CatchTray"
	-- neon ring around the hole
	local Nh = 12
	for k = 0, Nh - 1 do
		local a = (k + 0.5) / Nh * 2 * PI
		local er = V3(sin(a), 0, cos(a))
		local t = V3(cos(a), 0, -sin(a))
		part(b, V3(2 * PI * rh / Nh * 1.1, 0.5, 0.6), CFrame.fromMatrix(V3(cx, holeY + 0.1, cz) + er * (rh + 0.2), t, up), th.accent, { Material = NEON })
	end
end

local function buildSplit(b: Builder, td: Track.TrackData, p: Track.Piece, th: Theme)
	local w0, w1 = (p.wideS0 :: number) + 2, (p.wideS1 :: number) - 2
	-- divider wall
	local s = w0
	while s < w1 - 0.5 do
		local e = min(w1, s + 8)
		local pa, ra, ua = frameAt(td, s)
		local pb = frameAt(td, e)
		local chord = pb - pa
		local fwd = chord.Unit
		local mid = (pa + pb) / 2
		part(b, V3(1.8, 1.9, chord.Magnitude + 0.1), CFrame.fromMatrix(mid + ua * 0.95, ra, ua, -fwd), th.rail, { CastShadow = true })
		s = e
	end
	for _, es in ipairs({ w0, w1 }) do
		local pp, _, uu = frameAt(td, es)
		ball(b, pp + uu * 0.95, 2.2, th.accent, { Material = NEON })
	end
	local wide = p.wide :: number
	local half = wide / 2 - Track.MARBLE_D / 2 - Track.RAIL
	-- boost lane
	local padSide = p.padSide :: number
	buildPads(b, td, p.padS0 :: number, p.padS1 :: number, padSide * 0.56 * half, 7)
	-- bumper lane
	for _, bs in ipairs(p.bumpers :: { number }) do
		local pp, rr, uu = frameAt(td, bs)
		local base = pp + rr * (-padSide) * (wide / 2 - 1.7)
		local col = Color3.fromHex("#FF4F5E")
		local c = part(b, V3(2.4, 2.6, 2.6), CFrame.fromMatrix(base + uu * 1.2, uu, rr), col, { CastShadow = true })
		c.Shape = Enum.PartType.Cylinder
		local cap = part(b, V3(0.5, 2.7, 2.7), CFrame.fromMatrix(base + uu * 2.55, uu, rr), WHITE, { Material = NEON })
		cap.Shape = Enum.PartType.Cylinder
	end
end

local function buildPillars(b: Builder, td: Track.TrackData, th: Theme)
	local hash = buildHash(td)
	local s = 10
	local k = 0
	local startPiece = td.piece[1]
	while s < td.length - 2 do
		local i = idx(td, s)
		local tg = td.tag[i]
		local placed = false
		if (generic(tg) or tg == TAG.STEP) and not (td.piece[i] == startPiece and s < td.gateS + 10) then
			local pos = P(td, i)
			local topY = pos.Y - THICK - 0.2
			if tg == TAG.STEP then
				topY = pos.Y - Track.STEP_DROP - THICK - 0.3
			end
			if topY > 2.5 and columnClear(td, hash, pos.X, pos.Z, topY, s, 1.6) then
				k += 1
				local col = th.pillars[(k - 1) % #th.pillars + 1]
				cyl(b, V3(pos.X, 0, pos.Z), topY, 2.6, col, { CastShadow = true })
				cyl(b, V3(pos.X, 0, pos.Z), 0.8, 4.4, WHITE)
				local yaw = td.yaw[i]
				part(b, V3(min(td.width[i] - 2, 9), 0.9, 2.2), CFrame.fromMatrix(V3(pos.X, topY - 0.45, pos.Z), horizRight(yaw), V3(0, 1, 0)), WHITE)
				placed = true
			end
		end
		s += placed and 24 or 3
	end
	-- funnel legs
	for _, p in ipairs(td.pieces) do
		if p.type == "funnel" then
			local cx, cz = p.cx :: number, p.cz :: number
			local ex = p.exitYaw :: number
			local rr = (p.R :: number) * 0.78
			local topY = (p.holeY :: number) + (rr - (p.rh :: number)) * (p.tanT :: number) - 0.6
			for q = 0, 3 do
				local a = ex + PI / 4 + q * PI / 2
				local x, z = cx + rr * sin(a), cz + rr * cos(a)
				if columnClear(td, hash, x, z, topY, (p.s0 :: number) - 100, 1.5, p) then
					cyl(b, V3(x, 0, z), topY, 2.2, th.pillars[q % #th.pillars + 1], { CastShadow = true })
				end
			end
		end
	end
end

-- Public --------------------------------------------------------------------------------------------------------

function TrackView.build(kind: string, seed: number, theme: string): View
	local opts = (Config.Tracks :: any)[kind] or Config.Tracks.main
	local td = Track.generate(seed, opts)
	local model = Instance.new("Model")
	model.Name = "Track_" .. kind
	local view: View = {
		kind = kind,
		seed = seed,
		theme = theme,
		td = td,
		model = model,
		ready = false,
		dead = false,
		parts = 0,
		lights = {},
		gateBar = nil,
		gateCf = CFrame.identity,
		startCf = CFrame.identity,
		finishCf = CFrame.identity,
		funnels = {},
	}
	local folder = workspace:FindFirstChild("Tracks")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Tracks"
		folder.Parent = workspace
	end
	model.Parent = folder
	local th = themeOf(theme)
	local b: Builder = { view = view, folder = model, count = 0 }
	task.spawn(function()
		local ok, err = pcall(function()
			buildStart(b, view, td, th)
			if view.dead then
				return
			end
			buildFloors(b, td, th)
			for _, p in ipairs(td.pieces) do
				if view.dead then
					return
				end
				if p.type == "jump" then
					buildJump(b, td, p, th)
				elseif p.type == "stairs" then
					buildStairs(b, td, p, th)
				elseif p.type == "funnel" then
					buildFunnel(b, view, td, p, th)
				elseif p.type == "split" then
					buildSplit(b, td, p, th)
				elseif p.type == "pads" then
					local pp = p
					buildPads(b, td, pp.padS0 :: number, pp.padS1 :: number, 0, td.width[idx(td, pp.padS0 :: number)] * 0.6)
				end
			end
			if view.dead then
				return
			end
			buildFinish(b, view, td, th)
			buildPillars(b, td, th)
		end)
		if not ok then
			warn("[TrackView] build error:", err)
		end
		view.ready = true
	end)
	-- the frames the camera needs are known right away
	do
		local pos, right, up = frameAt(td, td.gateS)
		local fwd = up:Cross(right).Unit
		view.gateCf = CFrame.fromMatrix(pos, right, up, -fwd)
		view.startCf = view.gateCf
		local fp, fr, fu = frameAt(td, td.finishS)
		local ff = fu:Cross(fr).Unit
		view.finishCf = CFrame.fromMatrix(fp, fr, fu, -ff)
	end
	return view
end

function TrackView.destroy(view: View)
	view.dead = true
	view.model:Destroy()
end

local RED = Color3.fromRGB(255, 60, 60)
local GREEN = Color3.fromRGB(80, 255, 110)
local OFF = Color3.fromRGB(70, 70, 86)

-- Countdown lights: n = 0 (off), 1..3 red lights on, 4 = all green.
function TrackView.lights(view: View, n: number)
	for k, l in ipairs(view.lights) do
		if n >= 4 then
			l.Color = GREEN
			l.Material = NEON
		elseif k <= n then
			l.Color = RED
			l.Material = NEON
		else
			l.Color = OFF
			l.Material = Enum.Material.SmoothPlastic
		end
	end
end

function TrackView.gate(view: View, open: boolean)
	local bar = view.gateBar
	if not bar then
		return
	end
	local closed = view.gateCf * CF(0, 1.2, -0.6)
	local target = open and closed * CF(0, -3.4, 0) or closed
	TweenService:Create(bar, TweenInfo.new(open and 0.25 or 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = target }):Play()
end

-- Frame on the floor centre at s (for cameras): position, right, up, forward.
function TrackView.frame(view: View, s: number): (Vector3, Vector3, Vector3, Vector3)
	local pos, right, up = frameAt(view.td, s)
	return pos, right, up, up:Cross(right).Unit
end

return TrackView

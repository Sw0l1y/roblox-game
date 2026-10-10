-- Builds cakes and toppings from palette primitives (no textures). Shared: the server builds the live cakes
-- at every station, clients build the showcase cake on the turntable and the giant winner cake.
-- A cake is plain data, so it can travel over remotes:
--   { shape = "Round", tiers = { "Vanilla", "Pink" }, drip = "None"|colour, piping = "Auto"|colour,
--     toppings = { { id = "Cherry", cf = <CFrame relative to the cake root>, s = 1, tint = "Auto"|colour } } }
-- The cake root is the top centre of the plate; local -Z is the cake's front.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tiers = require(Shared:WaitForChild("Tiers"))

local CakeBuilder = {}

export type Topping = { id: string, cf: CFrame, s: number, tint: string }
export type Cake = { shape: string, tiers: { string }, drip: string, piping: string, toppings: { Topping } }
export type Opts = { collide: boolean?, ghost: number?, fx: boolean? }
export type Dim = { r: number, h: number, y0: number }
type Props = { r: number?, n: boolean?, a: number?, glass: boolean? }
type Seg = { arc: boolean, a: Vector2, b: Vector2, c: Vector2, r: number, t0: number, t1: number, len: number }
type Pt = { p: Vector2, n: Vector2 }

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local RAD = math.rad
local SQ2 = math.sqrt(2)
local C = Color3.fromRGB
local WHITE = C(255, 255, 255)
local INK = C(40, 30, 48)
local GOLD = C(255, 200, 60)
local BALL = Enum.PartType.Ball
local CYL = Enum.PartType.Cylinder

-- Data helpers -------------------------------------------------------------------------------------

function CakeBuilder.newCake(): Cake
	return { shape = "Round", tiers = { "Vanilla", "Pink" }, drip = "None", piping = "Auto", toppings = {} }
end

function CakeBuilder.copy(c: Cake): Cake
	local t = {}
	for i, e in ipairs(c.toppings) do
		t[i] = { id = e.id, cf = e.cf, s = e.s, tint = e.tint }
	end
	return { shape = c.shape, tiers = table.clone(c.tiers), drip = c.drip, piping = c.piping, toppings = t }
end

function CakeBuilder.dims(n: number): { Dim }
	local out = {}
	local y = 0
	for i = 1, math.clamp(n, 1, 4) do
		local h = Config.Cake.tierH[i]
		table.insert(out, { r = Config.Cake.tierR[i], h = h, y0 = y })
		y += h
	end
	return out
end

function CakeBuilder.height(c: Cake): number
	local d = CakeBuilder.dims(#c.tiers)
	local last = d[#d]
	return last.y0 + last.h
end

-- Which tier a cake-local height belongs to.
function CakeBuilder.tierAt(c: Cake, y: number): number
	for i, d in ipairs(CakeBuilder.dims(#c.tiers)) do
		if y <= d.y0 + d.h + 0.6 then
			return i
		end
	end
	return #c.tiers
end

-- Colour of a key (Rainbow cycles through `index`).
function CakeBuilder.color(key: string, index: number?): Color3
	local def = Config.ColorByKey[key]
	if not def then
		return Config.Palette.cream
	end
	if def.special == "rainbow" then
		local r = Config.Rainbow
		return r[((index or 1) - 1) % #r + 1]
	end
	return def.color
end

local function luminance(c: Color3): number
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

-- Orientation for a topping on the cake surface: up = surface normal, front faces the cake's front on top
-- surfaces and the sky on side surfaces, then `rot` eighth-turns about the normal.
function CakeBuilder.surfaceCF(root: CFrame, pos: Vector3, normal: Vector3, rot: number): CFrame
	local up = normal.Unit
	local rootUp = root.UpVector
	local ref = if math.abs(up:Dot(rootUp)) > 0.7 then root.LookVector else rootUp
	local f = ref - up * ref:Dot(up)
	if f.Magnitude < 1e-3 then
		local alt = if math.abs(up.X) < 0.9 then Vector3.xAxis else Vector3.zAxis
		f = alt - up * alt:Dot(up)
	end
	f = f.Unit
	local right = f:Cross(up)
	return CFrame.fromMatrix(pos, right, up, -f) * ANG(0, rot * math.pi * 2 / Config.Cake.rotSteps, 0)
end

-- Part factory ------------------------------------------------------------------------------------------

local function mk(parent: Instance, class: string, shape: Enum.PartType?, cf: CFrame, size: Vector3, color: Color3, o: Opts?, solid: boolean): BasePart
	local p: BasePart
	if class == "WedgePart" then
		p = Instance.new("WedgePart")
	else
		local part = Instance.new("Part")
		if shape then
			part.Shape = shape
		end
		p = part
	end
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.CanTouch = false
	if solid then
		p.CanCollide = not (o ~= nil and o.collide == false)
		p.CanQuery = true
	else
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
	end
	if o and o.ghost then
		p.Transparency = o.ghost
	end
	p.Parent = parent
	return p
end

local function styleKey(p: BasePart, key: string)
	local def = Config.ColorByKey[key]
	if not def then
		return
	end
	if def.gloss then
		p.Reflectance = def.gloss
	end
	if def.neon then
		p.Material = Enum.Material.Neon
	end
end

-- Two wedges forming an isosceles triangle prism: base centre rv, tip direction u, base direction v
-- (unit, perpendicular), half base width, length to the tip, thickness. Vectors are local to `frame`.
local function triPrism(parent: Instance, frame: CFrame, rv: Vector3, u: Vector3, v: Vector3, halfW: number, len: number, thick: number, color: Color3, o: Opts?, solid: boolean): { BasePart }
	local out = {}
	for _, sgn in ipairs({ 1, -1 }) do
		local Y = v * sgn
		local Z = -u
		local X = Y:Cross(Z)
		local center = rv + Y * (halfW / 2) + u * (len / 2)
		local w = mk(parent, "WedgePart", nil, frame * CFrame.fromMatrix(center, X, Y, Z), V(thick, halfW, len), color, o, solid)
		table.insert(out, w)
	end
	return out
end

-- Outline of a tier shape in cake-local (x, z), for piping and drips ------------------------------------

local function line(a: Vector2, b: Vector2): Seg
	return { arc = false, a = a, b = b, c = Vector2.zero, r = 0, t0 = 0, t1 = 0, len = (b - a).Magnitude }
end

local function arc(c: Vector2, r: number, t0: number, t1: number): Seg
	return { arc = true, a = Vector2.zero, b = Vector2.zero, c = c, r = r, t0 = t0, t1 = t1, len = r * math.abs(t1 - t0) }
end

local function polygon(pts: { Vector2 }): { Seg }
	local segs = {}
	for i = 1, #pts do
		table.insert(segs, line(pts[i], pts[i % #pts + 1]))
	end
	return segs
end

local function heartParams(r: number): (number, number)
	local d = r / 1.2071
	return d, -0.1036 * d
end

local function outline(shape: string, r: number): { Seg }
	if shape == "Square" then
		local a = r * 0.88
		return polygon({ Vector2.new(-a, -a), Vector2.new(a, -a), Vector2.new(a, a), Vector2.new(-a, a) })
	elseif shape == "Hexagon" then
		local R = r * 0.9 * 2 / math.sqrt(3)
		local pts = {}
		for k = 0, 5 do
			local a = RAD(k * 60)
			table.insert(pts, Vector2.new(math.cos(a) * R, math.sin(a) * R))
		end
		return polygon(pts)
	elseif shape == "Heart" then
		local d, zc = heartParams(r)
		local rc = d / SQ2
		local T = Vector2.new(0, zc - d)
		local Rv = Vector2.new(d, zc)
		local Lv = Vector2.new(-d, zc)
		return {
			line(T, Rv),
			arc(Vector2.new(d / 2, zc + d / 2), rc, RAD(-45), RAD(135)),
			arc(Vector2.new(-d / 2, zc + d / 2), rc, RAD(45), RAD(225)),
			line(Lv, T),
		}
	elseif shape == "Star" then
		local R = r * 1.08
		local ri = R * 0.5
		local pts = {}
		for k = 0, 4 do
			local a = RAD(-90 + k * 72)
			table.insert(pts, Vector2.new(math.cos(a) * R, math.sin(a) * R))
			local b = a + RAD(36)
			table.insert(pts, Vector2.new(math.cos(b) * ri, math.sin(b) * ri))
		end
		return polygon(pts)
	end
	return { arc(Vector2.zero, r, 0, math.pi * 2) }
end

local function sample(segs: { Seg }, spacing: number, phase: number?): { Pt }
	local total = 0
	for _, s in ipairs(segs) do
		total += s.len
	end
	local n = math.max(5, math.floor(total / spacing + 0.5))
	local out = {}
	for k = 0, n - 1 do
		local dist = (k + (phase or 0.5)) / n * total
		for _, s in ipairs(segs) do
			if dist <= s.len + 1e-6 then
				local t = if s.len > 0 then dist / s.len else 0
				if s.arc then
					local ang = s.t0 + (s.t1 - s.t0) * t
					local nrm = Vector2.new(math.cos(ang), math.sin(ang))
					table.insert(out, { p = s.c + nrm * s.r, n = nrm })
				else
					local p = s.a + (s.b - s.a) * t
					local dir = (s.b - s.a).Unit
					local nrm = Vector2.new(dir.Y, -dir.X)
					if nrm:Dot(p) < 0 then
						nrm = -nrm
					end
					table.insert(out, { p = p, n = nrm })
				end
				break
			end
			dist -= s.len
		end
	end
	return out
end
CakeBuilder.outline = outline
CakeBuilder.sample = sample

-- Tier body parts for a shape: base = bottom centre of the tier.
local function shapeParts(parent: Instance, shape: string, base: CFrame, r: number, h: number, color: Color3, o: Opts?, solid: boolean): { BasePart }
	local parts = {}
	local mid = base * CF(0, h / 2, 0)
	if shape == "Square" then
		local a = r * 0.88 * 2
		table.insert(parts, mk(parent, "Part", nil, mid, V(a, h, a), color, o, solid))
	elseif shape == "Hexagon" then
		local ap = r * 0.9
		local R = ap * 2 / math.sqrt(3)
		for k = 0, 2 do
			table.insert(parts, mk(parent, "Part", nil, mid * ANG(0, RAD(60 * k), 0), V(R, h, ap * 2), color, o, solid))
		end
	elseif shape == "Heart" then
		local d, zc = heartParams(r)
		local s = d * SQ2
		table.insert(parts, mk(parent, "Part", nil, mid * CF(0, 0, zc) * ANG(0, RAD(45), 0), V(s, h, s), color, o, solid))
		for _, sx in ipairs({ 1, -1 }) do
			table.insert(parts, mk(parent, "Part", CYL, mid * CF(sx * d / 2, 0, zc + d / 2) * ANG(0, 0, RAD(90)), V(h, s, s), color, o, solid))
		end
	elseif shape == "Star" then
		local R = r * 1.08
		local ri = R * 0.5
		table.insert(parts, mk(parent, "Part", CYL, mid * ANG(0, 0, RAD(90)), V(h, ri * 2, ri * 2), color, o, solid))
		local rb = ri * math.cos(RAD(36))
		local halfW = ri * math.sin(RAD(36))
		for k = 0, 4 do
			local a = RAD(-90 + k * 72)
			local u = V(math.cos(a), 0, math.sin(a))
			local v = V(-u.Z, 0, u.X)
			for _, w in ipairs(triPrism(parent, mid, u * rb, u, v, halfW, R - rb, h, color, o, solid)) do
				table.insert(parts, w)
			end
		end
	else
		table.insert(parts, mk(parent, "Part", CYL, mid * ANG(0, 0, RAD(90)), V(h, r * 2, r * 2), color, o, solid))
	end
	return parts
end

local function getFolder(model: Instance, name: string): Folder
	local f = model:FindFirstChild(name)
	if f and f:IsA("Folder") then
		return f :: any
	end
	local nf = Instance.new("Folder")
	nf.Name = name
	nf.Parent = model
	return nf
end
CakeBuilder.folder = getFolder

-- Cake body (solid, raycastable tiers) -------------------------------------------------------------------
function CakeBuilder.buildBody(model: Instance, cake: Cake, root: CFrame, o: Opts?): { BasePart }
	local f = getFolder(model, "Body")
	f:ClearAllChildren()
	local all = {}
	for i, d in ipairs(CakeBuilder.dims(#cake.tiers)) do
		local key = cake.tiers[i]
		local def = Config.ColorByKey[key]
		local base = root * CF(0, d.y0, 0)
		if def and def.special == "rainbow" then
			local layers = 5
			for l = 1, layers do
				local lh = d.h / layers
				for _, p in ipairs(shapeParts(f, cake.shape, base * CF(0, (l - 1) * lh, 0), d.r, lh, Config.Rainbow[(l + i) % #Config.Rainbow + 1], o, true)) do
					table.insert(all, p)
				end
			end
		else
			for _, p in ipairs(shapeParts(f, cake.shape, base, d.r, d.h, CakeBuilder.color(key, i), o, true)) do
				styleKey(p, key)
				table.insert(all, p)
			end
		end
	end
	return all
end

-- Piping (ball rims), drips with a glossy top cap, galaxy specks --------------------------------------
function CakeBuilder.buildDeco(model: Instance, cake: Cake, root: CFrame, o: Opts?)
	local f = getFolder(model, "Deco")
	f:ClearAllChildren()
	local rng = Random.new(71)
	local dripDef = Config.ColorByKey[cake.drip]
	local dims = CakeBuilder.dims(#cake.tiers)
	for i, d in ipairs(dims) do
		local tierKey = cake.tiers[i]
		local tierColor = CakeBuilder.color(tierKey, i)
		local top = d.y0 + d.h
		local segs = outline(cake.shape, d.r)

		if dripDef then
			local capColor = CakeBuilder.color(cake.drip, i)
			for _, p in ipairs(shapeParts(f, cake.shape, root * CF(0, top - 0.24, 0), d.r + 0.1, 0.34, capColor, o, false)) do
				p.Reflectance = math.max(0.12, dripDef.gloss or 0)
				if dripDef.neon then
					p.Material = Enum.Material.Neon
				end
			end
			for k, pt in ipairs(sample(segs, 1.85, rng:NextNumber(0.2, 0.8))) do
				local len = d.h * (0.2 + 0.42 * rng:NextNumber())
				local dd = 0.5 + 0.2 * rng:NextNumber()
				local col = CakeBuilder.color(cake.drip, k)
				local p = pt.p + pt.n * 0.06
				local cyl = mk(f, "Part", CYL, root * CF(p.X, top - len / 2, p.Y) * ANG(0, 0, RAD(90)), V(len, dd, dd), col, o, false)
				cyl.Reflectance = 0.12
				local drop = mk(f, "Part", BALL, root * CF(p.X, top - len, p.Y), V(dd * 1.12, dd * 1.12, dd * 1.12), col, o, false)
				drop.Reflectance = 0.12
				if dripDef.neon then
					cyl.Material = Enum.Material.Neon
					drop.Material = Enum.Material.Neon
				end
			end
		end

		-- piping colour: chosen, or automatic (lighter tier colour; pink on very light tiers)
		local pipeKey = cake.piping
		local pipeDef = Config.ColorByKey[pipeKey]
		local auto = Config.Palette.pink
		if luminance(tierColor) < 0.86 then
			auto = tierColor:Lerp(WHITE, 0.55)
		end
		local pd = math.clamp(0.55 + 0.1 * d.r, 0.7, 1.05)
		local rows = { top + 0.04 }
		if i == 1 then
			table.insert(rows, d.y0 + pd * 0.36)
		end
		for _, y in ipairs(rows) do
			for k, pt in ipairs(sample(segs, pd * 1.12)) do
				local col = if pipeDef then CakeBuilder.color(pipeKey, k) else auto
				local b = mk(f, "Part", BALL, root * CF(pt.p.X, y, pt.p.Y), V(pd, pd, pd), col, o, false)
				if pipeDef then
					styleKey(b, pipeKey)
				end
			end
		end

		local def = Config.ColorByKey[tierKey]
		if def and def.special == "galaxy" then
			local specks = { WHITE, C(255, 140, 230), C(120, 230, 255) }
			for k, pt in ipairs(sample(segs, 1.6, 0.3)) do
				if k % 2 == 0 or k < 3 then
					local y = d.y0 + d.h * (0.15 + 0.7 * rng:NextNumber())
					local s = 0.18 + 0.18 * rng:NextNumber()
					local b = mk(f, "Part", BALL, root * CF(pt.p.X + pt.n.X * 0.02, y, pt.p.Y + pt.n.Y * 0.02), V(s, s, s), specks[k % 3 + 1], o, false)
					b.Material = Enum.Material.Neon
				end
			end
		end
	end
end

-- Toppings ------------------------------------------------------------------------------------------------

local function emitter(p: BasePart, color: ColorSequence, rate: number, size: number, speed: number, life: number)
	local e = Instance.new("ParticleEmitter")
	e.Color = color
	e.LightEmission = 1
	e.Rate = rate
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Speed = NumberRange.new(speed * 0.6, speed)
	e.Lifetime = NumberRange.new(life * 0.6, life)
	e.SpreadAngle = Vector2.new(180, 180)
	e.LockedToPart = false
	e.Parent = p
end

-- Build one topping model at world CFrame `cf` (up = surface normal), scale `s`.
function CakeBuilder.topping(parent: Instance, id: string, cf: CFrame, s: number, tintKey: string?, o: Opts?): Model
	local def = Config.ToppingById[id]
	local m = Instance.new("Model")
	m.Name = id
	local pos0 = cf.Position
	local rng = Random.new(math.floor(math.abs(pos0.X * 131 + pos0.Y * 71 + pos0.Z * 37)) % 100000 + 1)
	local tint = if def and def.tint then def.tint else WHITE
	if def and def.tint and tintKey and Config.ColorByKey[tintKey] then
		tint = CakeBuilder.color(tintKey, rng:NextInteger(1, 6))
	end
	local fxOn = not (o and (o.fx == false or o.ghost))

	-- AI hero mesh when it exists (server copies them into ReplicatedStorage.CakeMeshes), else primitives
	local meshFolder = ReplicatedStorage:FindFirstChild("CakeMeshes")
	if def and def.mesh and meshFolder then
		local tpl = meshFolder:FindFirstChild(def.mesh)
		if tpl and tpl:IsA("MeshPart") then
			local mp = (tpl :: any):Clone() :: MeshPart
			mp.Size = (tpl :: any).Size * s
			mp.CFrame = cf * CF(0, mp.Size.Y / 2, 0)
			mp.Anchored = true
			mp.CanCollide = false
			mp.CanQuery = false
			mp.CanTouch = false
			mp.CastShadow = false
			if o and o.ghost then
				mp.Transparency = o.ghost
			end
			mp.Parent = m
			m.PrimaryPart = mp
			m.Parent = parent
			return m
		end
	end

	local first: BasePart? = nil
	local function P(class: string, shape: Enum.PartType?, size: Vector3, rel: CFrame, color: Color3, x: Props?): BasePart
		local p = mk(m, class, shape, cf * (CF(rel.Position * s) * rel.Rotation), size * s, color, o, false)
		if x then
			if x.r then
				p.Reflectance = x.r
			end
			if x.n then
				p.Material = Enum.Material.Neon
			end
			if x.glass then
				p.Material = Enum.Material.Glass
			end
			if x.a then
				p.Transparency = math.max(p.Transparency, x.a)
			end
		end
		if not first then
			first = p
		end
		return p
	end
	local function ball(pos: Vector3, d: number, c: Color3, x: Props?): BasePart
		return P("Part", BALL, V(d, d, d), CF(pos), c, x)
	end
	-- upright cylinder standing on pos
	local function cyl(pos: Vector3, h: number, d: number, c: Color3, x: Props?): BasePart
		return P("Part", CYL, V(h, d, d), CF(pos + V(0, h / 2, 0)) * ANG(0, 0, RAD(90)), c, x)
	end
	local function rod(a: Vector3, b: Vector3, d: number, c: Color3, x: Props?): BasePart
		local dir = (b - a).Unit
		local ref = if math.abs(dir.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
		local y = (ref - dir * ref:Dot(dir)).Unit
		return P("Part", CYL, V((b - a).Magnitude, d, d), CFrame.fromMatrix((a + b) / 2, dir, y), c, x)
	end
	local function box(rel: CFrame, size: Vector3, c: Color3, x: Props?): BasePart
		return P("Part", nil, size, rel, c, x)
	end
	-- disc facing the front (axis along local Z)
	local function discFront(pos: Vector3, d: number, thick: number, c: Color3, x: Props?): BasePart
		return P("Part", CYL, V(thick, d, d), CF(pos) * ANG(0, RAD(90), 0), c, x)
	end
	-- flat disc (axis along local Y), optionally tilted by `tilt`
	local function discFlat(pos: Vector3, d: number, thick: number, c: Color3, x: Props?, tilt: CFrame?): BasePart
		return P("Part", CYL, V(thick, d, d), CF(pos) * (tilt or CFrame.identity) * ANG(0, 0, RAD(90)), c, x)
	end
	local function tri(rv: Vector3, u: Vector3, v: Vector3, halfW: number, len: number, thick: number, c: Color3, x: Props?)
		for _, sgn in ipairs({ 1, -1 }) do
			local Y = v * sgn
			local Z = -u
			local X = Y:Cross(Z)
			local center = rv + Y * (halfW / 2) + u * (len / 2)
			P("WedgePart", nil, V(thick, halfW, len), CFrame.fromMatrix(center, X, Y, Z), c, x)
		end
	end
	local function radialYaw(a: number): CFrame -- local Z points along angle a in the x-z plane
		return ANG(0, RAD(90) - a, 0)
	end

	local RED = C(225, 32, 56)
	local LEAF = C(80, 175, 85)

	if id == "Sprinkles" then
		local cols = { C(255, 92, 120), C(255, 220, 80), C(110, 220, 140), C(90, 180, 255), C(190, 130, 255), WHITE }
		for _ = 1, 7 do
			local a = rng:NextNumber() * math.pi * 2
			local rr = rng:NextNumber() * 0.85
			P("Part", CYL, V(0.62, 0.17, 0.17), CF(math.cos(a) * rr, 0.09, math.sin(a) * rr) * ANG(0, rng:NextNumber() * math.pi, 0), cols[rng:NextInteger(1, #cols)], { r = 0.1 })
		end
	elseif id == "Cherry" then
		ball(V(0, 0.5, 0), 1.0, RED, { r = 0.18 })
		ball(V(-0.2, 0.72, -0.24), 0.26, C(255, 225, 230))
		rod(V(0, 0.9, 0), V(0.22, 1.55, 0.15), 0.11, C(96, 120, 44))
	elseif id == "Candle" then
		cyl(V(0, 0, 0), 1.8, 0.38, tint)
		cyl(V(0, 0.45, 0), 0.16, 0.41, WHITE)
		cyl(V(0, 1.1, 0), 0.16, 0.41, WHITE)
		rod(V(0, 1.78, 0), V(0, 1.98, 0), 0.07, C(60, 50, 50))
		ball(V(0, 2.12, 0), 0.34, C(255, 160, 40), { n = true })
		ball(V(0, 2.32, 0), 0.2, C(255, 235, 130), { n = true })
	elseif id == "Pearls" then
		ball(V(0, 0.25, 0), 0.5, tint, { r = 0.35 })
		ball(V(0.46, 0.22, 0.12), 0.44, tint, { r = 0.35 })
		ball(V(-0.18, 0.2, 0.44), 0.4, tint, { r = 0.35 })
	elseif id == "Swirl" then
		ball(V(0, 0.42, 0), 1.1, tint)
		ball(V(0.04, 0.92, 0), 0.86, tint)
		ball(V(0, 1.32, 0.02), 0.6, tint)
		ball(V(0.05, 1.6, 0), 0.3, tint)
	elseif id == "Leaf" then
		local greens = { C(70, 180, 90), C(110, 215, 110), C(60, 160, 80) }
		for k, yaw in ipairs({ -38, 0, 38 }) do
			box(CF(0, 0.12, 0) * ANG(0, RAD(yaw), 0) * ANG(RAD(15), 0, 0) * CF(0, 0, -0.5), V(0.42, 0.07, 1.1), greens[k])
		end
	elseif id == "ChocChunk" then
		box(CF(0, 0.3, 0) * ANG(0.3, 0.5, 0.2), V(0.7, 0.55, 0.6), C(92, 52, 30), { r = 0.06 })
		box(CF(0.55, 0.25, 0.2) * ANG(-0.2, 1.2, 0.3), V(0.5, 0.45, 0.5), C(122, 74, 44), { r = 0.06 })
		box(CF(-0.35, 0.25, 0.45) * ANG(0.4, 2.2, -0.2), V(0.55, 0.4, 0.45), C(80, 45, 26), { r = 0.06 })
	elseif id == "Strawberry" then
		local red = C(232, 40, 62)
		ball(V(0, 0.52, 0), 1.05, red, { r = 0.12 })
		ball(V(0, 0.95, 0), 0.8, red, { r = 0.12 })
		ball(V(0, 1.28, 0), 0.46, red, { r = 0.12 })
		for k = 0, 2 do
			box(CF(0, 0.14, 0) * ANG(0, RAD(k * 120), 0) * ANG(RAD(-12), 0, 0) * CF(0, 0, -0.45), V(0.32, 0.06, 0.75), C(60, 170, 70))
		end
		ball(V(0.3, 0.75, -0.33), 0.12, C(255, 230, 120))
		ball(V(-0.32, 0.55, -0.36), 0.12, C(255, 230, 120))
	elseif id == "Candy" then
		rod(V(-0.42, 0.38, 0), V(0.42, 0.38, 0), 0.72, tint, { r = 0.2 })
		rod(V(-0.08, 0.38, 0), V(0.08, 0.38, 0), 0.75, WHITE)
		local wing = tint:Lerp(WHITE, 0.35)
		box(CF(0.62, 0.38, 0) * ANG(RAD(45), 0, 0), V(0.1, 0.5, 0.5), wing)
		box(CF(-0.62, 0.38, 0) * ANG(RAD(45), 0, 0), V(0.1, 0.5, 0.5), wing)
	elseif id == "Blueberry" then
		for _, p in ipairs({ V(0, 0.31, 0), V(0.52, 0.31, 0.12), V(0.2, 0.31, -0.48) }) do
			ball(p, 0.62, C(62, 72, 170), { r = 0.15 })
			ball(p + V(0, 0.3, 0), 0.14, C(30, 30, 70))
		end
	elseif id == "HeartCandy" then
		local c = 0.6
		box(CF(0, c, 0) * ANG(0, 0, RAD(45)), V(0.75, 0.75, 0.3), tint, { r = 0.15 })
		discFront(V(0.265, c + 0.265, 0), 0.75, 0.3, tint, { r = 0.15 })
		discFront(V(-0.265, c + 0.265, 0), 0.75, 0.3, tint, { r = 0.15 })
	elseif id == "Bubbles" then
		local b = C(170, 225, 255)
		ball(V(0, 0.38, 0), 0.72, b, { a = 0.35, r = 0.3 })
		ball(V(0.35, 0.95, 0.1), 0.5, b, { a = 0.35, r = 0.3 })
		ball(V(0.02, 1.35, -0.14), 0.34, b, { a = 0.35, r = 0.3 })
	elseif id == "Lollipop" then
		rod(V(0, 0, 0), V(0, 1.45, 0), 0.12, WHITE)
		discFront(V(0, 1.95, 0), 1.3, 0.24, tint, { r = 0.15 })
		discFront(V(0, 1.95, 0), 0.88, 0.26, WHITE)
		discFront(V(0, 1.95, 0), 0.46, 0.28, tint, { r = 0.15 })
	elseif id == "Cookie" then
		local F = CF(0, 0.75, 0.1) * ANG(RAD(-28), 0, 0)
		P("Part", CYL, V(0.26, 1.5, 1.5), F * ANG(0, RAD(90), 0), C(222, 166, 98))
		for _, xy in ipairs({ { 0.3, 0.25 }, { -0.35, 0.1 }, { 0.05, -0.35 }, { -0.1, 0.42 } }) do
			ball((F * CF(xy[1], xy[2], -0.14)).Position, 0.24, C(80, 45, 26))
		end
	elseif id == "Flower" then
		for k = 0, 4 do
			local a = RAD(k * 72)
			discFlat(V(math.cos(a) * 0.38, 0.16, math.sin(a) * 0.38), 0.66, 0.18, tint, { r = 0.08 })
		end
		ball(V(0, 0.26, 0), 0.42, C(255, 220, 80))
	elseif id == "Shell" then
		local b = V(0, 0.12, 0.35)
		for k = 0, 4 do
			local a = RAD(-60 + k * 30)
			rod(b, b + V(math.sin(a) * 0.95, math.cos(a) * 0.85, -0.25), 0.34, if k % 2 == 0 then C(255, 188, 168) else C(255, 214, 196), { r = 0.2 })
		end
		ball(b, 0.42, C(255, 172, 158))
	elseif id == "Star" then
		rod(V(0, 0, 0), V(0, 1.1, 0), 0.1, C(225, 165, 40))
		local center = V(0, 1.72, 0)
		discFront(center, 0.6, 0.26, tint, { r = 0.3 })
		for k = 0, 4 do
			local a = RAD(90 + k * 72)
			local u = V(math.cos(a), math.sin(a), 0)
			local v = V(-math.sin(a), math.cos(a), 0)
			tri(center + u * 0.2, u, v, 0.24, 0.62, 0.26, tint, { r = 0.3 })
		end
	elseif id == "Snowflake" then
		local center = V(0, 1.0, 0)
		for k = 0, 2 do
			box(CF(center) * ANG(0, 0, RAD(k * 60)), V(0.14, 1.7, 0.14), C(240, 250, 255), { r = 0.2 })
		end
		for k = 0, 5 do
			local a = RAD(90 + k * 60)
			ball(center + V(math.cos(a) * 0.85, math.sin(a) * 0.85, 0), 0.24, C(170, 220, 255), { r = 0.2 })
		end
		ball(center, 0.32, C(200, 235, 255))
	elseif id == "Ghost" then
		local w = C(250, 250, 255)
		cyl(V(0, 0, 0), 1.0, 1.15, w)
		ball(V(0, 1.0, 0), 1.2, w)
		ball(V(0.62, 0.75, 0), 0.4, w)
		ball(V(-0.62, 0.75, 0), 0.4, w)
		ball(V(-0.22, 1.12, -0.5), 0.22, INK)
		ball(V(0.22, 1.12, -0.5), 0.22, INK)
		ball(V(0, 0.82, -0.54), 0.24, C(70, 40, 70))
	elseif id == "Donut" then
		for k = 0, 5 do
			local a = RAD(k * 60)
			local p = V(math.cos(a) * 0.5, 0.27, math.sin(a) * 0.5)
			ball(p, 0.56, C(228, 172, 104))
			ball(p + V(0, 0.14, 0), 0.5, tint, { r = 0.1 })
		end
	elseif id == "Cupcake" then
		cyl(V(0, 0, 0), 0.72, 1.0, tint)
		cyl(V(0, 0.6, 0), 0.12, 1.08, tint:Lerp(WHITE, 0.3))
		ball(V(0, 0.95, 0), 1.12, C(255, 226, 238))
		ball(V(0, 1.38, 0), 0.74, C(255, 226, 238))
		ball(V(0, 1.8, 0), 0.34, RED, { r = 0.18 })
	elseif id == "Pumpkin" then
		local o1 = C(255, 140, 30)
		for _, p in ipairs({ V(0.26, 0.46, 0), V(-0.26, 0.46, 0), V(0, 0.46, 0.26), V(0, 0.46, -0.26) }) do
			ball(p, 0.95, o1)
		end
		ball(V(0, 0.5, 0), 1.0, C(240, 118, 20))
		rod(V(0, 0.92, 0), V(0.08, 1.28, 0.04), 0.18, C(80, 130, 50))
		box(CF(0.25, 1.0, 0) * ANG(0, 0, RAD(-25)), V(0.45, 0.06, 0.3), C(90, 170, 70))
		ball(V(-0.22, 0.6, -0.68), 0.2, INK)
		ball(V(0.22, 0.6, -0.68), 0.2, INK)
	elseif id == "Palm" then
		local pts = { V(0, 0, 0), V(0.1, 0.7, 0), V(0.25, 1.4, 0), V(0.35, 2.0, 0) }
		for k = 1, 3 do
			rod(pts[k], pts[k + 1], 0.3, if k % 2 == 0 then C(190, 140, 90) else C(160, 110, 70))
		end
		local top = V(0.35, 2.05, 0)
		for k = 0, 4 do
			box(CF(top) * ANG(0, RAD(k * 72), 0) * ANG(RAD(-25), 0, 0) * CF(0, 0, -0.55), V(0.38, 0.07, 1.15), if k % 2 == 0 then C(70, 180, 90) else C(100, 210, 100))
		end
		ball(top + V(0.15, -0.2, 0.12), 0.3, C(110, 70, 40))
		ball(top + V(-0.12, -0.2, -0.1), 0.3, C(110, 70, 40))
	elseif id == "Butterfly" then
		rod(V(0, 0, 0), V(0, 0.62, 0), 0.05, C(60, 60, 70))
		rod(V(0, 0.66, 0.35), V(0, 0.66, -0.35), 0.17, C(60, 50, 70))
		ball(V(0, 0.68, -0.42), 0.24, C(60, 50, 70))
		local light = tint:Lerp(WHITE, 0.35)
		for _, sx in ipairs({ 1, -1 }) do
			discFlat(V(0.45 * sx, 0.82, -0.12), 0.95, 0.06, tint, { r = 0.1 }, ANG(0, 0, RAD(25 * sx)))
			discFlat(V(0.36 * sx, 0.72, 0.3), 0.62, 0.06, light, nil, ANG(0, 0, RAD(18 * sx)))
			rod(V(0.05 * sx, 0.75, -0.5), V(0.2 * sx, 1.05, -0.7), 0.04, INK)
		end
	elseif id == "IceCream" then
		cyl(V(0, 0, 0), 0.36, 0.26, C(232, 182, 112))
		cyl(V(0, 0.34, 0), 0.36, 0.5, C(222, 170, 100))
		cyl(V(0, 0.68, 0), 0.36, 0.76, C(232, 182, 112))
		ball(V(0, 1.35, 0), 0.98, C(255, 170, 200))
		ball(V(0, 1.98, 0), 0.82, C(170, 235, 205))
		ball(V(0, 2.45, 0), 0.32, RED, { r = 0.18 })
	elseif id == "Rainbow" then
		local bands = { { 1.25, C(255, 92, 92) }, { 1.02, C(255, 220, 80) }, { 0.79, C(90, 170, 255) } }
		for _, band in ipairs(bands) do
			local R = band[1] :: number
			local col = band[2] :: Color3
			for j = 0, 4 do
				local a0, a1 = RAD(j * 36), RAD((j + 1) * 36)
				rod(V(math.cos(a0) * R, math.sin(a0) * R + 0.15, 0), V(math.cos(a1) * R, math.sin(a1) * R + 0.15, 0), 0.26, col)
			end
		end
		for _, sx in ipairs({ 1, -1 }) do
			ball(V(1.02 * sx, 0.28, 0), 0.62, WHITE)
			ball(V(0.75 * sx, 0.22, 0.18), 0.44, WHITE)
		end
	elseif id == "Crown" then
		for k = 0, 5 do
			local a = RAD(k * 60)
			box(CF(math.cos(a) * 0.68, 0.3, math.sin(a) * 0.68) * radialYaw(a), V(0.74, 0.56, 0.12), GOLD, { r = 0.35 })
		end
		for k = 0, 4 do
			local a = RAD(-90 + k * 72)
			local b = V(math.cos(a) * 0.68, 0.5, math.sin(a) * 0.68)
			local t = V(math.cos(a) * 0.72, 0.95, math.sin(a) * 0.72)
			rod(b, t, 0.16, GOLD, { r = 0.35 })
			ball(t, 0.26, GOLD, { r = 0.35 })
		end
		ball(V(0, 0.32, -0.74), 0.26, C(230, 40, 80), { r = 0.4 })
	elseif id == "Rocket" then
		cyl(V(0, 0.35, 0), 1.3, 0.62, C(245, 245, 250))
		ball(V(0, 1.68, 0), 0.62, C(235, 60, 70))
		ball(V(0, 2.0, 0), 0.34, C(235, 60, 70))
		ball(V(0, 1.25, -0.27), 0.28, C(120, 200, 255), { r = 0.3 })
		for k = 0, 2 do
			local a = RAD(k * 120 + 90)
			box(CF(math.cos(a) * 0.38, 0.55, math.sin(a) * 0.38) * radialYaw(a), V(0.08, 0.6, 0.45), C(235, 60, 70))
		end
		ball(V(0, 0.2, 0), 0.36, C(255, 160, 40), { n = true })
	elseif id == "Bow" then
		local dark = tint:Lerp(C(0, 0, 0), 0.2)
		P("Part", CYL, V(0.24, 0.64, 0.64), CF(0.36, 0.55, 0) * ANG(0, RAD(90), 0), tint, { r = 0.2 })
		P("Part", CYL, V(0.24, 0.64, 0.64), CF(-0.36, 0.55, 0) * ANG(0, RAD(90), 0), tint, { r = 0.2 })
		ball(V(0, 0.52, 0), 0.34, dark, { r = 0.2 })
		box(CF(0.2, 0.2, 0) * ANG(0, 0, RAD(-35)), V(0.16, 0.5, 0.2), dark)
		box(CF(-0.2, 0.2, 0) * ANG(0, 0, RAD(35)), V(0.16, 0.5, 0.2), dark)
	elseif id == "Planet" then
		rod(V(0, 0, 0), V(0, 0.6, 0), 0.12, C(200, 200, 220))
		ball(V(0, 1.25, 0), 1.4, C(170, 120, 255), { r = 0.1 })
		discFlat(V(0, 1.25, 0), 2.4, 0.08, C(255, 210, 120), { r = 0.2 }, ANG(RAD(22), 0, 0))
		ball(V(0.95, 2.0, 0.1), 0.36, C(220, 220, 235))
	elseif id == "Castle" then
		cyl(V(0, 0, 0), 1.6, 0.95, C(250, 232, 242))
		box(CF(0, 1.0, -0.46), V(0.24, 0.42, 0.06), C(120, 80, 140))
		box(CF(0, 0.28, -0.46), V(0.34, 0.5, 0.06), C(150, 100, 70))
		cyl(V(0, 1.6, 0), 0.32, 1.2, C(255, 140, 180))
		cyl(V(0, 1.92, 0), 0.32, 0.82, C(255, 160, 195))
		cyl(V(0, 2.24, 0), 0.3, 0.46, C(255, 140, 180))
		rod(V(0, 2.5, 0), V(0, 3.05, 0), 0.05, C(200, 200, 210))
		box(CF(0.2, 2.92, 0), V(0.38, 0.24, 0.04), GOLD)
	elseif id == "Unicorn" then
		local ds = { 0.72, 0.58, 0.45, 0.33, 0.2 }
		for k, d in ipairs(ds) do
			cyl(V(0, (k - 1) * 0.38, 0), 0.4, d, if k % 2 == 1 then GOLD else WHITE, { r = 0.25 })
		end
		for _, sx in ipairs({ 1, -1 }) do
			box(CF(0.62 * sx, 0.35, 0.05) * ANG(0, 0, RAD(-15 * sx)), V(0.32, 0.62, 0.14), WHITE)
			box(CF(0.62 * sx, 0.33, -0.03) * ANG(0, 0, RAD(-15 * sx)), V(0.18, 0.4, 0.04), C(255, 170, 200))
		end
		ball(V(0.42, 0.18, -0.42), 0.32, C(255, 160, 200))
		ball(V(-0.4, 0.18, -0.45), 0.3, C(200, 170, 255))
		ball(V(0, 0.16, -0.6), 0.28, C(160, 220, 255))
	elseif id == "Diamond" then
		cyl(V(0, 0, 0), 0.16, 0.7, GOLD, { r = 0.35 })
		box(CF(0, 0.81, 0) * ANG(RAD(45), 0, RAD(35.26)), V(0.75, 0.75, 0.75), C(170, 230, 255), { glass = true, a = 0.2, r = 0.3 })
	elseif id == "Ring" then
		local center = V(0, 0.55, 0)
		for k = 0, 7 do
			local a = RAD(k * 45)
			ball(center + V(math.cos(a) * 0.42, math.sin(a) * 0.42, 0), 0.2, GOLD, { r = 0.4 })
		end
		box(CF(0, 1.22, 0) * ANG(RAD(45), 0, RAD(35.26)), V(0.36, 0.36, 0.36), C(200, 240, 255), { glass = true, a = 0.15, r = 0.35 })
	elseif id == "Swan" then
		local w = C(252, 252, 255)
		ball(V(0, 0.45, 0.08), 1.0, w)
		ball(V(0, 0.62, 0.5), 0.55, w)
		box(CF(0.42, 0.58, 0.12) * ANG(0, 0, RAD(20)), V(0.16, 0.45, 0.75), C(238, 238, 248))
		box(CF(-0.42, 0.58, 0.12) * ANG(0, 0, RAD(-20)), V(0.16, 0.45, 0.75), C(238, 238, 248))
		rod(V(0, 0.65, -0.32), V(0, 1.2, -0.46), 0.22, w)
		rod(V(0, 1.2, -0.46), V(0, 1.45, -0.32), 0.2, w)
		ball(V(0, 1.5, -0.32), 0.34, w)
		box(CF(0, 1.48, -0.53) * ANG(RAD(15), 0, 0), V(0.1, 0.1, 0.24), C(255, 150, 50))
	elseif id == "GalaxyOrb" then
		cyl(V(0, 0, 0), 0.42, 0.62, C(44, 28, 92))
		ball(V(0, 1.05, 0), 1.1, C(150, 80, 255), { n = true, a = 0.2 })
		ball(V(0, 1.05, 0), 0.55, C(255, 120, 220), { n = true })
		discFlat(V(0, 1.05, 0), 1.75, 0.05, C(90, 230, 255), { n = true }, ANG(RAD(-25), 0, RAD(10)))
	elseif id == "Sparkler" then
		for k = 0, 2 do
			local a = RAD(k * 120)
			local b = V(math.cos(a) * 0.25, 0, math.sin(a) * 0.25)
			local t = b + V(math.cos(a) * 0.35, 1.5, math.sin(a) * 0.35)
			rod(b, t, 0.07, C(150, 150, 160))
			local tip = ball(t, 0.28, C(255, 230, 120), { n = true })
			if fxOn then
				emitter(tip, ColorSequence.new(C(255, 240, 160), C(255, 160, 60)), 22, 0.14, 5, 0.4)
			end
		end
	elseif id == "Trophy" then
		cyl(V(0, 0, 0), 0.18, 0.95, C(110, 70, 40))
		cyl(V(0, 0.18, 0), 0.42, 0.24, GOLD, { r = 0.4 })
		ball(V(0, 0.95, 0), 0.95, GOLD, { r = 0.4 })
		cyl(V(0, 1.22, 0), 0.14, 1.0, GOLD, { r = 0.4 })
		for _, sx in ipairs({ 1, -1 }) do
			rod(V(0.46 * sx, 1.15, 0), V(0.66 * sx, 0.88, 0), 0.12, GOLD, { r = 0.4 })
			rod(V(0.66 * sx, 0.88, 0), V(0.4 * sx, 0.68, 0), 0.12, GOLD, { r = 0.4 })
		end
		ball(V(0, 0.95, -0.47), 0.22, WHITE, { n = true })
	else
		ball(V(0, 0.4, 0), 0.8, tint)
	end

	local firstPart = first
	if firstPart then
		m.PrimaryPart = firstPart
		if def and fxOn then
			local ti = Tiers.index[def.tier] or 1
			if ti >= 5 then
				emitter(firstPart, Tiers.gradient(def.tier), if ti >= 7 then 8 elseif ti == 6 then 5 else 3, 0.28, 1.4, 1.3)
			end
		end
	end
	m.Parent = parent
	return m
end

function CakeBuilder.addTopping(parent: Instance, e: Topping, root: CFrame, o: Opts?): Model
	return CakeBuilder.topping(parent, e.id, root * e.cf, e.s, e.tint, o)
end

function CakeBuilder.buildToppings(model: Instance, cake: Cake, root: CFrame, o: Opts?): { Model }
	local f = getFolder(model, "Toppings")
	f:ClearAllChildren()
	local out = {}
	for i, e in ipairs(cake.toppings) do
		out[i] = CakeBuilder.addTopping(f, e, root, o)
	end
	return out
end

-- Whole cake into `model` (Body, Deco, Toppings folders).
function CakeBuilder.build(model: Instance, cake: Cake, root: CFrame, o: Opts?)
	CakeBuilder.buildBody(model, cake, root, o)
	CakeBuilder.buildDeco(model, cake, root, o)
	CakeBuilder.buildToppings(model, cake, root, o)
end

-- Rough part count (for budgets and debug).
function CakeBuilder.count(model: Instance): number
	local n = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

return CakeBuilder

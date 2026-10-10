-- Builds every balloon from palette primitives: a slightly stretched ball body (SpecialMesh sphere), a small
-- knot, a thin two-segment string and a glossy highlight, plus per-type shapes and details (hearts, stars,
-- donuts, cupcakes, faces, stripes...). The front of a balloon is its -Z side (the client turns balloons to
-- face the camera, so details live on the front). If Config.Meshes.balloon has been generated, the server puts
-- the MeshPart in ReplicatedStorage.BalloonMesh and round bodies use it instead of the primitive sphere.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tiers = require(Shared:WaitForChild("Tiers"))

local BalloonArt = {}

type Def = Config.BalloonDef
export type Opts = {
	size: number?, -- override diameter
	weld: boolean?, -- anchored root + welded, unanchored parts (for client animation)
	silhouette: boolean?, -- black "undiscovered" look for the Index
	noString: boolean?,
	stringLen: number?,
	shadow: boolean?, -- body casts shadows (default true)
}
type Info = { bottom: Vector3, rx: number, ry: number, rz: number, radius: number, front: boolean }

local V = Vector3.new
local CF = CFrame.new
local RAD = math.rad
local WHITE = Color3.fromRGB(255, 255, 255)
local INK = Color3.fromRGB(30, 28, 45)
local STRING = Config.Palette.string

local function shade(c: Color3, f: number): Color3
	return Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
end
BalloonArt.shade = shade

local function newPart(m: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false -- never block the camera or clicks
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Parent = m
	return p
end

-- Ellipsoid: a box part with a sphere SpecialMesh, which stretches to the part size.
local function ellip(m: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = newPart(m, name, size, cf, color)
	local sm = Instance.new("SpecialMesh")
	sm.MeshType = Enum.MeshType.Sphere
	sm.Parent = p
	return p
end
BalloonArt.ellip = ellip

local function ball(m: Instance, name: string, d: number, pos: Vector3, color: Color3): Part
	return newPart(m, name, V(d, d, d), CF(pos), color, Enum.PartType.Ball)
end

-- Upright cylinder centred at pos.
local function cylY(m: Instance, name: string, h: number, dia: number, cf: CFrame, color: Color3): Part
	return newPart(m, name, V(h, dia, dia), cf * CFrame.Angles(0, 0, RAD(90)), color, Enum.PartType.Cylinder)
end

-- Cylinder facing the front (axis along Z), centred at pos.
local function cylZ(m: Instance, name: string, h: number, dia: number, pos: Vector3, color: Color3): Part
	return newPart(m, name, V(h, dia, dia), CF(pos) * CFrame.Angles(0, RAD(90), 0), color, Enum.PartType.Cylinder)
end

-- Thin box from a to b.
local function rod(m: Instance, name: string, a: Vector3, b: Vector3, thick: number, color: Color3): Part
	local dir = b - a
	local len = dir.Magnitude
	local mid = (a + b) / 2
	local cf
	if len < 1e-4 then
		cf = CF(mid)
	elseif math.abs(dir.Unit.Y) > 0.98 then
		cf = CFrame.lookAt(mid, b, Vector3.xAxis)
	else
		cf = CFrame.lookAt(mid, b)
	end
	return newPart(m, name, V(thick, thick, math.max(len, 0.05)), cf, color)
end

-- A CFrame on the ellipsoid surface (centre c, radii rx/ry/rz) at face coords u,v (fractions of rx, ry),
-- on the front (-Z) unless back. LookVector points outward along the surface normal.
local function surf(c: Vector3, rx: number, ry: number, rz: number, u: number, v: number, back: boolean?, lift: number?): CFrame
	local x, y = u * rx, v * ry
	local k = 1 - u * u - v * v
	local z = rz * math.sqrt(math.max(0, k)) * (back and 1 or -1)
	local n = V(x / (rx * rx), y / (ry * ry), z / (rz * rz))
	if n.Magnitude < 1e-6 then
		n = V(0, 0, back and 1 or -1)
	end
	n = n.Unit
	local p = c + V(x, y, z) + n * (lift or 0)
	if math.abs(n.Y) > 0.97 then
		return CFrame.lookAt(p, p + n, Vector3.zAxis)
	end
	return CFrame.lookAt(p, p + n)
end

local function styleBody(p: BasePart, def: Def)
	if def.neon then
		p.Material = Enum.Material.Neon
	elseif def.glass then
		p.Material = Enum.Material.Glass
		p.Transparency = 0.35
	end
	if def.refl then
		p.Reflectance = def.refl
	end
end

local function shine(m: Instance, c: Vector3, rx: number, ry: number, rz: number, d: number)
	local s = ellip(m, "Shine", V(0.2 * d, 0.3 * d, 0.05 * d), surf(c, rx, ry, rz, 0.4, 0.4, false, 0.01) * CFrame.Angles(0, 0, RAD(-28)), WHITE)
	s.Transparency = 0.18
	local g = ball(m, "Glint", 0.08 * d, surf(c, rx, ry, rz, 0.2, 0.62, false, 0.01).Position, WHITE)
	g.Transparency = 0.1
end

local function knotAndString(m: Instance, bottom: Vector3, d: number, color: Color3, len: number?)
	ellip(m, "Knot", V(0.18 * d, 0.16 * d, 0.18 * d), CF(bottom + V(0, -0.05 * d, 0)), shade(color, 0.8))
	if len and len > 0 then
		local top = bottom + V(0, -0.12 * d, 0)
		local mid = top + V(0.22, -len * 0.5, 0.08)
		local bot = top + V(-0.08, -len, -0.04)
		rod(m, "String", top, mid, 0.07, STRING)
		rod(m, "String", mid, bot, 0.07, STRING)
	end
end

---------------------------------------------------------------------------------------------------------------
-- Shapes: each builds the body at the origin and returns where the string attaches
---------------------------------------------------------------------------------------------------------------

local function roundBody(m: Instance, def: Def, d: number, opts: Opts): Info
	local rx, ry = d / 2, d * 0.575
	local body: BasePart
	local mesh = (not opts.silhouette) and ReplicatedStorage:FindFirstChild("BalloonMesh")
	if mesh and mesh:IsA("MeshPart") then
		local mp = (mesh :: any):Clone() :: MeshPart
		mp.Name = "Body"
		mp.Anchored = true
		mp.CanCollide = false
		mp.CanQuery = false
		mp.CanTouch = false
		mp.Size = V(d, d * 1.15, d)
		mp.CFrame = CF()
		mp.Color = def.c1
		mp.Material = Enum.Material.SmoothPlastic
		pcall(function()
			(mp :: any).TextureID = ""
		end)
		mp.Parent = m
		body = mp
	else
		body = ellip(m, "Body", V(d, d * 1.15, d), CF(), def.c1)
	end
	styleBody(body, def)
	body.CastShadow = opts.shadow ~= false
	if not def.glass and not def.neon then
		shine(m, Vector3.zero, rx, ry, rx, d)
	end
	return { bottom = V(0, -ry, 0), rx = rx, ry = ry, rz = rx, radius = d * 0.55, front = true }
end

local function heartBody(m: Instance, def: Def, d: number, opts: Opts): Info
	local a = d / 1.707
	local y0 = -0.073 * a
	local box = newPart(m, "Body", V(a, a, 0.62 * a), CF(0, y0, 0) * CFrame.Angles(0, 0, RAD(45)), def.c1)
	styleBody(box, def)
	box.CastShadow = opts.shadow ~= false
	local off = a / (2 * math.sqrt(2))
	for _, sx in ipairs({ -1, 1 }) do
		local lobe = ellip(m, "Lobe", V(a, a, 0.78 * a), CF(sx * off, y0 + off, 0), def.c1)
		styleBody(lobe, def)
	end
	-- glossy highlight on the left lobe
	shine(m, V(off, y0 + off, 0), a / 2, a / 2, 0.39 * a, a * 1.2)
	return { bottom = V(0, y0 - a / math.sqrt(2) + 0.05 * a, 0), rx = d / 2, ry = d / 2, rz = 0.35 * a, radius = d * 0.55, front = false }
end

-- Five-pointed star from 10 wedges (two mirrored right-triangle wedges per point) around a puffy centre.
local function starBody(m: Instance, def: Def, d: number, opts: Opts): Info
	local R = d / 2
	local ri = 0.46 * R
	local t = 0.34 * R
	local puff = ellip(m, "Body", V(ri * 2.3, ri * 2.3, t * 1.7), CF(), def.c1)
	styleBody(puff, def)
	puff.CastShadow = opts.shadow ~= false
	local c36 = math.cos(RAD(36))
	local s36 = math.sin(RAD(36))
	local h = R - ri * c36
	local halfBase = ri * s36
	local zf = V(0, 0, 1)
	for i = 0, 4 do
		local th = RAD(90 + i * 72)
		local u = V(math.cos(th), math.sin(th), 0)
		local p = V(-math.sin(th), math.cos(th), 0)
		local M = u * (ri * c36)
		local col = def.c1
		if def.deco and table.find(def.deco, "rainbow") then
			col = Config.Palette.rainbow[i + 1]
		end
		for _, side in ipairs({ 1, -1 }) do
			local xAxis = zf * side
			local zAxis = side == 1 and p or -p
			local pos = M + u * (h / 2) - zAxis * (halfBase / 2)
			local w = Instance.new("WedgePart")
			w.Name = "Point"
			w.Anchored = true
			w.CanCollide = false
			w.CanQuery = false
			w.CanTouch = false
			w.CastShadow = false
			w.Material = Enum.Material.SmoothPlastic
			w.Size = V(t, h, halfBase)
			w.CFrame = CFrame.fromMatrix(pos, xAxis, u, zAxis)
			w.Color = col
			w.Parent = m
			styleBody(w, def)
		end
	end
	-- centre disc fills the pentagon
	local disc = cylZ(m, "Disc", t, ri * 2.05, Vector3.zero, def.c1)
	styleBody(disc, def)
	local g = ellip(m, "Shine", V(0.22 * R, 0.34 * R, 0.05 * R), CF(-0.28 * R, 0.3 * R, -t * 0.86) * CFrame.Angles(0, 0, RAD(-25)), WHITE)
	g.Transparency = 0.2
	-- the string ties to the bottom-left point's inner corner
	return { bottom = V(0, -ri * 0.9, 0), rx = R, ry = R, rz = t, radius = d * 0.5, front = false }
end

local function clusterBody(m: Instance, def: Def, d: number, opts: Opts): Info
	local spec = {
		{ 0, 0, 0, 0.6, 1 },
		{ 0.3, -0.06, 0.05, 0.48, 2 },
		{ -0.3, -0.04, -0.04, 0.46, 2 },
		{ 0.13, 0.22, 0.06, 0.46, 1 },
		{ -0.15, 0.2, -0.08, 0.42, 2 },
		{ 0.02, -0.02, -0.24, 0.42, 1 },
	}
	for i, s in ipairs(spec) do
		local col = s[5] == 1 and def.c1 or (def.c2 or def.c1)
		local b = ball(m, i == 1 and "Body" or "Puff", s[4] * d, V(s[1] * d, s[2] * d, s[3] * d), col)
		styleBody(b, def)
		if i == 1 then
			b.CastShadow = opts.shadow ~= false
		end
	end
	local g = ellip(m, "Shine", V(0.14 * d, 0.2 * d, 0.04 * d), CF(-0.1 * d, 0.16 * d, -0.43 * d), WHITE)
	g.Transparency = 0.3
	return { bottom = V(0, -0.28 * d, 0), rx = 0.36 * d, ry = 0.32 * d, rz = 0.4 * d, radius = d * 0.5, front = true }
end

local function donutBody(m: Instance, def: Def, d: number, opts: Opts): Info
	local Rr = 0.32 * d
	local dough = def.c2 or Color3.fromRGB(232, 172, 112)
	for i = 0, 7 do
		local a = RAD(i * 45)
		local f = ball(m, i == 0 and "Body" or "Frosting", 0.38 * d, V(math.cos(a) * Rr, math.sin(a) * Rr, -0.04 * d), def.c1)
		styleBody(f, def)
		if i == 0 then
			f.CastShadow = opts.shadow ~= false
		end
		local a2 = RAD(i * 45 + 22.5)
		ball(m, "Dough", 0.34 * d, V(math.cos(a2) * Rr, math.sin(a2) * Rr, 0.06 * d), dough)
	end
	local sprinkle = { Config.Palette.yellow, Config.Palette.sky, WHITE, Config.Palette.mint, Config.Palette.yellow, WHITE }
	for i = 0, 5 do
		local a = RAD(i * 60 + 15)
		local r = Rr + (i % 2 == 0 and 0.05 or -0.06) * d
		rod(m, "Sprinkle", V(math.cos(a) * r, math.sin(a) * r, -0.22 * d), V(math.cos(a) * r + 0.06 * d, math.sin(a) * r + 0.03 * d, -0.22 * d), 0.04 * d, sprinkle[i + 1])
	end
	return { bottom = V(0, -Rr - 0.17 * d, 0), rx = d / 2, ry = d / 2, rz = 0.2 * d, radius = d * 0.5, front = false }
end

local function cupcakeBody(m: Instance, def: Def, d: number, opts: Opts): Info
	local wrap = def.c2 or Config.Palette.sky
	local w = cylY(m, "Wrapper", 0.42 * d, 0.7 * d, CF(0, -0.22 * d, 0), wrap)
	w.CastShadow = opts.shadow ~= false
	for i = 0, 5 do
		local a = RAD(i * 30 - 75)
		local x, z = math.sin(a) * 0.35 * d, -math.cos(a) * 0.35 * d
		newPart(m, "Ridge", V(0.05 * d, 0.4 * d, 0.05 * d), CF(x, -0.22 * d, z), shade(wrap, 0.82))
	end
	local f = ellip(m, "Body", V(0.92 * d, 0.5 * d, 0.92 * d), CF(0, 0.06 * d, 0), def.c1)
	styleBody(f, def)
	ellip(m, "Frosting", V(0.62 * d, 0.42 * d, 0.62 * d), CF(0, 0.26 * d, 0), def.c1)
	ball(m, "Cherry", 0.2 * d, V(0, 0.52 * d, 0), def.c3 or Config.Palette.red)
	local cols = { Config.Palette.yellow, Config.Palette.sky, WHITE, Config.Palette.mint }
	for i = 1, 4 do
		local u = ({ -0.5, -0.15, 0.2, 0.5 })[i]
		local v = ({ 0.1, 0.45, 0.2, 0.0 })[i]
		ball(m, "Sprinkle", 0.06 * d, surf(V(0, 0.06 * d, 0), 0.46 * d, 0.25 * d, 0.46 * d, u, v, false, 0.0).Position, cols[i])
	end
	local g = ellip(m, "Shine", V(0.16 * d, 0.1 * d, 0.04 * d), surf(V(0, 0.06 * d, 0), 0.46 * d, 0.25 * d, 0.46 * d, 0.45, 0.45, false, 0.01), WHITE)
	g.Transparency = 0.25
	return { bottom = V(0, -0.43 * d, 0), rx = 0.46 * d, ry = 0.25 * d, rz = 0.46 * d, radius = d * 0.5, front = false }
end

local function lollipopBody(m: Instance, def: Def, d: number, opts: Opts): Info
	local disc = cylZ(m, "Body", 0.24 * d, d, Vector3.zero, def.c1)
	disc.CastShadow = opts.shadow ~= false
	styleBody(disc, def)
	local rings: { { t: number, dia: number, col: Color3 } } = {
		{ t = 0.27, dia = 0.78, col = def.c2 or WHITE },
		{ t = 0.3, dia = 0.56, col = def.c3 or Config.Palette.yellow },
		{ t = 0.33, dia = 0.34, col = def.c2 or WHITE },
		{ t = 0.36, dia = 0.14, col = def.c1 },
	}
	for _, r in ipairs(rings) do
		cylZ(m, "Swirl", r.t * d, r.dia * d, Vector3.zero, r.col)
	end
	local g = ellip(m, "Shine", V(0.14 * d, 0.22 * d, 0.03 * d), CF(-0.26 * d, 0.24 * d, -0.19 * d) * CFrame.Angles(0, 0, RAD(-35)), WHITE)
	g.Transparency = 0.25
	cylY(m, "Stick", 0.8 * d, 0.09 * d, CF(0, -0.88 * d, 0), WHITE)
	return { bottom = V(0, -1.2 * d, 0), rx = d / 2, ry = d / 2, rz = 0.12 * d, radius = d * 0.55, front = false }
end

local function saturnBody(m: Instance, def: Def, d: number, opts: Opts): Info
	local b = ball(m, "Body", d, Vector3.zero, def.c1)
	b.CastShadow = opts.shadow ~= false
	styleBody(b, def)
	local band = cylY(m, "Band", 0.14 * d, d * 1.01, CF(0, 0.18 * d, 0), shade(def.c1, 0.86))
	band.Name = "Band"
	local ring = newPart(m, "Ring", V(0.05 * d, 1.9 * d, 1.9 * d), CFrame.Angles(RAD(-18), 0, RAD(8)) * CFrame.Angles(0, 0, RAD(90)), def.c2 or WHITE, Enum.PartType.Cylinder)
	ring.Transparency = 0.12
	shine(m, Vector3.zero, d / 2, d / 2, d / 2, d)
	return { bottom = V(0, -d / 2, 0), rx = d / 2, ry = d / 2, rz = d / 2, radius = d * 0.6, front = true }
end

local function ufoBody(m: Instance, def: Def, d: number, opts: Opts): Info
	local saucer = ellip(m, "Body", V(d, 0.32 * d, d), CF(), def.c1)
	saucer.CastShadow = opts.shadow ~= false
	styleBody(saucer, def)
	cylY(m, "Rim", 0.07 * d, 1.01 * d, CF(0, -0.02 * d, 0), shade(def.c1, 0.75))
	local dome = ball(m, "Dome", 0.5 * d, V(0, 0.12 * d, 0), def.c2 or Config.Palette.mint)
	dome.Material = Enum.Material.Glass
	dome.Transparency = 0.35
	-- little alien
	ball(m, "Alien", 0.22 * d, V(0, 0.2 * d, 0), Color3.fromRGB(130, 230, 110))
	for _, sx in ipairs({ -1, 1 }) do
		ball(m, "Eye", 0.06 * d, V(sx * 0.045 * d, 0.23 * d, -0.1 * d), INK)
	end
	local lights = { Config.Palette.yellow, Config.Palette.pink, Config.Palette.sky }
	for i = 0, 5 do
		local a = RAD(i * 60 + 30)
		local l = ball(m, "Light", 0.09 * d, V(math.cos(a) * 0.47 * d, -0.04 * d, math.sin(a) * 0.47 * d), lights[i % 3 + 1])
		l.Material = Enum.Material.Neon
	end
	return { bottom = V(0, -0.16 * d, 0), rx = d / 2, ry = 0.16 * d, rz = d / 2, radius = d * 0.55, front = false }
end

local function hotairBody(m: Instance, def: Def, d: number, opts: Opts): Info
	local rx, ry = d / 2, d * 0.56
	local env = ellip(m, "Body", V(d, d * 1.12, d), CF(), def.c1)
	env.CastShadow = opts.shadow ~= false
	styleBody(env, def)
	cylY(m, "Skirt", 0.24 * d, 0.36 * d, CF(0, -0.56 * d, 0), def.c2 or Config.Palette.yellow)
	newPart(m, "Basket", V(0.32 * d, 0.24 * d, 0.32 * d), CF(0, -0.98 * d, 0), Color3.fromRGB(170, 115, 70))
	newPart(m, "BasketRim", V(0.36 * d, 0.05 * d, 0.36 * d), CF(0, -0.86 * d, 0), Color3.fromRGB(140, 90, 55))
	for _, c in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		rod(m, "Rope", V(c[1] * 0.13 * d, -0.66 * d, c[2] * 0.13 * d), V(c[1] * 0.15 * d, -0.86 * d, c[2] * 0.15 * d), 0.03 * d, Color3.fromRGB(120, 85, 60))
	end
	shine(m, Vector3.zero, rx, ry, rx, d)
	return { bottom = V(0, -1.1 * d, 0), rx = rx, ry = ry, rz = rx, radius = d * 0.6, front = true }
end

local function bunchBody(m: Instance, def: Def, d: number, opts: Opts): Info
	local s = 0.6 * d
	local spots = { V(-0.27 * d, 0.02 * d, 0.02 * d), V(0.28 * d, 0.05 * d, 0.05 * d), V(0, 0.32 * d, -0.04 * d) }
	local cols = { def.c1, def.c2 or Config.Palette.sky, def.c3 or Config.Palette.yellow }
	local tie = V(0, -0.85 * d, 0)
	for i, c in ipairs(spots) do
		local b = ellip(m, i == 1 and "Body" or "Balloon", V(s, s * 1.15, s), CF(c), cols[i])
		styleBody(b, def)
		if i == 1 then
			b.CastShadow = opts.shadow ~= false
		end
		shine(m, c, s / 2, s * 0.575, s / 2, s)
		local kb = c + V(0, -s * 0.575, 0)
		ellip(m, "Knot", V(0.18 * s, 0.12 * s, 0.18 * s), CF(kb), shade(cols[i], 0.8))
		rod(m, "String", kb, tie, 0.06, STRING)
	end
	return { bottom = tie + V(0, 0.14 * d, 0), rx = d / 2, ry = d / 2, rz = s / 2, radius = d * 0.55, front = false }
end

local function crystalBody(m: Instance, def: Def, d: number, opts: Opts): Info
	local rx, ry = d / 2, d * 0.575
	local body = ellip(m, "Body", V(d, d * 1.15, d), CF(), def.c1)
	body.Material = Enum.Material.Glass
	body.Transparency = 0.3
	body.CastShadow = opts.shadow ~= false
	local core = ball(m, "Core", 0.5 * d, Vector3.zero, def.c2 or WHITE)
	core.Material = Enum.Material.Neon
	-- floating facets inside
	for i = 0, 3 do
		local a = RAD(i * 90 + 20)
		local f = newPart(m, "Facet", V(0.16 * d, 0.16 * d, 0.16 * d), CF(math.cos(a) * 0.27 * d, (i % 2 == 0 and 0.12 or -0.14) * d, math.sin(a) * 0.27 * d) * CFrame.Angles(RAD(45), RAD(45 + i * 20), 0), Config.Palette.rainbow[i + 2])
		f.Material = Enum.Material.Neon
		f.Transparency = 0.15
	end
	shine(m, Vector3.zero, rx, ry, rx, d)
	return { bottom = V(0, -ry, 0), rx = rx, ry = ry, rz = rx, radius = d * 0.55, front = true }
end

local SHAPES: { [string]: (Instance, Def, number, Opts) -> Info } = {
	round = roundBody,
	heart = heartBody,
	star = starBody,
	cluster = clusterBody,
	donut = donutBody,
	cupcake = cupcakeBody,
	lollipop = lollipopBody,
	saturn = saturnBody,
	ufo = ufoBody,
	hotair = hotairBody,
	bunch = bunchBody,
	crystal = crystalBody,
}

---------------------------------------------------------------------------------------------------------------
-- Details on the front of the body
---------------------------------------------------------------------------------------------------------------

local function has(def: Def, deco: string): boolean
	return def.deco ~= nil and table.find(def.deco, deco) ~= nil
end

local function stripes(m: Instance, def: Def, d: number, info: Info)
	local list = def.stripes
	if not list or #list == 0 then
		return
	end
	local n = #list
	local spread = n >= 5 and 0.78 or 0.62
	local thick = (n >= 5 and 0.11 or 0.1) * d
	for i, col in ipairs(list) do
		local h = info.ry * (-spread + 2 * spread * (i - 0.5) / n)
		local r = info.rx * math.sqrt(math.max(0, 1 - (h / info.ry) ^ 2)) + 0.022 * d
		local s = cylY(m, "Stripe", thick, r * 2, CF(0, h, 0), col)
		if def.neon then
			s.Material = Enum.Material.Neon
		elseif def.refl then
			s.Reflectance = def.refl * 0.5
		end
		if def.key == "cosmic" then
			s.Material = Enum.Material.Neon
		end
	end
end

local function onFront(m: Instance, info: Info, name: string, size: Vector3, u: number, v: number, color: Color3, lift: number?): Part
	return ellip(m, name, size, surf(Vector3.zero, info.rx, info.ry, info.rz, u, v, false, lift or 0), color)
end

local function face(m: Instance, d: number, info: Info)
	for _, sx in ipairs({ -1, 1 }) do
		onFront(m, info, "Eye", V(0.11 * d, 0.17 * d, 0.05 * d), sx * 0.27, 0.12, INK, 0)
		ball(m, "Glint", 0.045 * d, surf(Vector3.zero, info.rx, info.ry, info.rz, sx * 0.27 - 0.04, 0.19, false, 0.02).Position, WHITE)
		local ck = onFront(m, info, "Cheek", V(0.14 * d, 0.08 * d, 0.04 * d), sx * 0.45, -0.07, Config.Palette.pink, 0)
		ck.Transparency = 0.25
	end
	local sm = { { -0.15, -0.14 }, { -0.05, -0.2 }, { 0.05, -0.2 }, { 0.15, -0.14 } }
	for _, s in ipairs(sm) do
		ball(m, "Smile", 0.07 * d, surf(Vector3.zero, info.rx, info.ry, info.rz, s[1], s[2], false, 0.0).Position, INK)
	end
end

local function details(m: Instance, def: Def, d: number, info: Info)
	if has(def, "stripes") then
		stripes(m, def, d, info)
	end
	if not info.front then
		return
	end
	if has(def, "dots") then
		for _, p in ipairs({ { -0.5, 0.25 }, { 0.42, 0.4 }, { 0.05, -0.1 }, { -0.3, -0.5 }, { 0.5, -0.32 } }) do
			onFront(m, info, "Dot", V(0.2 * d, 0.2 * d, 0.05 * d), p[1], p[2], def.c2 or WHITE)
		end
	end
	if has(def, "craters") then
		for _, p in ipairs({ { -0.42, 0.42, 0.24 }, { 0.45, 0.15, 0.18 }, { -0.05, -0.55, 0.2 }, { 0.38, -0.45, 0.13 } }) do
			onFront(m, info, "Crater", V(p[3] * d, p[3] * d * 0.9, 0.05 * d), p[1], p[2], def.c2 or shade(def.c1, 0.8))
		end
	end
	if has(def, "sugar") then
		for _, p in ipairs({ { -0.55, 0.3 }, { 0.5, 0.45 }, { -0.3, -0.5 }, { 0.55, -0.2 }, { 0.1, 0.6 }, { -0.6, -0.15 } }) do
			ball(m, "Sugar", 0.06 * d, surf(Vector3.zero, info.rx, info.ry, info.rz, p[1], p[2], false, 0).Position, WHITE)
		end
	end
	if has(def, "face") then
		face(m, d, info)
	end
	if has(def, "bubble") then
		local b = ball(m, "Bubble", 0.42 * d, V(0.36 * d, -0.22 * d, -0.4 * d), def.c1)
		b.Transparency = 0.35
		ball(m, "Glint", 0.08 * d, V(0.3 * d, -0.12 * d, -0.6 * d), WHITE)
	end
	if has(def, "stars") then
		local col = def.c2 or WHITE
		for _, p in ipairs({ { -0.5, 0.2 }, { 0.4, 0.5 }, { 0.3, -0.3 }, { -0.25, -0.55 }, { 0.6, 0.0 }, { -0.1, 0.25 } }) do
			local s = ball(m, "Twinkle", 0.07 * d, surf(Vector3.zero, info.rx, info.ry, info.rz, p[1], p[2], false, 0).Position, col)
			s.Material = Enum.Material.Neon
		end
	end
	if has(def, "swirl") then
		local s = newPart(m, "Swirl", V(0.08 * d, 1.05 * d, 1.05 * d), CFrame.Angles(RAD(24), 0, RAD(-18)) * CFrame.Angles(0, 0, RAD(90)), def.c2 or Config.Palette.pink, Enum.PartType.Cylinder)
		s.Material = Enum.Material.Neon
		s.Transparency = 0.15
	end
	if has(def, "bolt") then
		local pts = { { 0.08, 0.66 }, { -0.2, 0.08 }, { 0.16, 0.12 }, { -0.08, -0.62 } }
		for i = 1, #pts - 1 do
			local a = surf(Vector3.zero, info.rx, info.ry, info.rz, pts[i][1], pts[i][2], false, 0.02)
			local b = surf(Vector3.zero, info.rx, info.ry, info.rz, pts[i + 1][1], pts[i + 1][2], false, 0.02)
			local up = (b.Position - a.Position).Unit
			local n = (a.LookVector + b.LookVector).Unit
			local x = up:Cross(n).Unit
			local z = x:Cross(up)
			local seg = newPart(m, "Bolt", V(0.12 * d, (b.Position - a.Position).Magnitude + 0.08 * d, 0.06 * d), CFrame.fromMatrix((a.Position + b.Position) / 2, x, up, z), def.c2 or Config.Palette.yellow)
			seg.Material = Enum.Material.Neon
		end
	end
	if has(def, "halo") then
		for i = 0, 9 do
			local a = RAD(i * 36)
			local h = ball(m, "Halo", 0.09 * d, V(math.cos(a) * 0.28 * d, info.ry + 0.12 * d, math.sin(a) * 0.28 * d), def.c2 or Config.Palette.gold)
			h.Material = Enum.Material.Neon
		end
	end
	if has(def, "wings") then
		local wc = def.neon and (def.c2 or Config.Palette.orange) or Color3.fromRGB(235, 245, 255)
		for _, sx in ipairs({ -1, 1 }) do
			local w = ellip(m, "Wing", V(0.62 * d, 0.34 * d, 0.1 * d), CF(sx * 0.6 * d, 0.1 * d, 0.12 * d) * CFrame.Angles(0, RAD(-sx * 25), RAD(sx * 22)), wc)
			if def.neon then
				w.Material = Enum.Material.Neon
			end
			local w2 = ellip(m, "Wing", V(0.42 * d, 0.24 * d, 0.1 * d), CF(sx * 0.66 * d, -0.08 * d, 0.14 * d) * CFrame.Angles(0, RAD(-sx * 25), RAD(sx * 8)), wc)
			if def.neon then
				w2.Material = Enum.Material.Neon
			end
		end
	end
	if has(def, "tail") then
		local spec = { { 0.42, 0.34, 0.16, 0.52, 0.25 }, { 0.76, 0.6, 0.26, 0.38, 0.45 }, { 1.04, 0.82, 0.34, 0.25, 0.62 } }
		for _, s in ipairs(spec) do
			local t = ball(m, "Tail", s[4] * d, V(s[1] * d, s[2] * d, s[3] * d), def.c2 or WHITE)
			t.Material = Enum.Material.Neon
			t.Transparency = s[5]
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------------------------------------------

-- Build a balloon model centred on its body at the origin. Returns the model and its invisible root part.
function BalloonArt.build(def: Def, opts: Opts?): (Model, BasePart)
	local o: Opts = opts or {}
	local d = o.size or def.size
	local m = Instance.new("Model")
	m.Name = def.key
	local root = newPart(m, "Root", V(0.4, 0.4, 0.4), CF(), WHITE)
	root.Transparency = 1
	root.CanQuery = false
	m.PrimaryPart = root

	local builder = SHAPES[def.shape] or roundBody
	local info = builder(m, def, d, o)
	details(m, def, d, info)
	if def.shape ~= "hotair" then
		local len = o.noString and 0 or (o.stringLen or (2.2 + d * 0.38))
		knotAndString(m, info.bottom, d, def.c1, len)
	end

	if o.silhouette then
		for _, inst in ipairs(m:GetDescendants()) do
			if inst ~= (root :: Instance) and inst:IsA("BasePart") then
				local p = inst :: BasePart
				if p.Name == "Shine" or p.Name == "Glint" or p.Name == "Twinkle" then
					p:Destroy()
				else
					p.Color = Color3.fromRGB(28, 26, 44)
					p.Material = Enum.Material.SmoothPlastic
					p.Reflectance = 0
					if p.Transparency < 0.9 then
						p.Transparency = 0
					end
				end
			end
		end
	end

	if o.weld then
		for _, inst in ipairs(m:GetDescendants()) do
			if inst ~= (root :: Instance) and inst:IsA("BasePart") then
				local p = inst :: BasePart
				local w = Instance.new("WeldConstraint")
				w.Part0 = root
				w.Part1 = p
				w.Parent = p
				p.Anchored = false
				p.Massless = true
			end
		end
	end
	return m, root
end

-- Approximate radius used for clicking, bumping and aura checks.
function BalloonArt.radius(def: Def): number
	return def.size * 0.55
end

-- Glow and particles for rare balloons (client only; skipped in Index previews).
function BalloonArt.fx(model: Model, def: Def, strength: number?)
	local body = model:FindFirstChild("Body") :: BasePart?
	if not body then
		return
	end
	local tier = Tiers.get(def.tier)
	local k = strength or 1
	if def.light then
		local l = Instance.new("PointLight")
		l.Color = def.particles == "fire" and Color3.fromRGB(255, 150, 60) or (tier.rainbow and Color3.fromRGB(255, 240, 255) or tier.color)
		l.Range = (8 + def.size) * k
		l.Brightness = 1.4
		l.Shadows = false
		l.Parent = body
	end
	if def.particles then
		local e = Instance.new("ParticleEmitter")
		e.Name = "Fx"
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Rate = 8 * k
		e.Lifetime = NumberRange.new(0.8, 1.5)
		e.Speed = NumberRange.new(1, 2.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-90, 90)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45 * k), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		if def.particles == "rainbow" then
			e.Color = Tiers.gradient("Secret")
			e.Rate = 14 * k
		elseif def.particles == "fire" then
			e.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 70, 30))
			e.Rate = 22 * k
			e.Acceleration = V(0, 5, 0)
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9 * k), NumberSequenceKeypoint.new(1, 0) })
		elseif def.particles == "stars" then
			e.Color = ColorSequence.new(Color3.fromRGB(255, 250, 220), Color3.fromRGB(200, 170, 255))
			e.Speed = NumberRange.new(0.3, 1)
		else
			e.Color = ColorSequence.new(tier.color, WHITE)
		end
		e.Parent = body
	end
end

-- Cheap decor balloon (body + shine + knot + string) for arches, bridges and booths. Anchored.
function BalloonArt.simple(parent: Instance, pos: Vector3, d: number, color: Color3, stringLen: number?, facing: Vector3?): Model
	local m = Instance.new("Model")
	m.Name = "DecorBalloon"
	local rx, ry = d / 2, d * 0.575
	local body = ellip(m, "Body", V(d, d * 1.15, d), CF(), color)
	body.Reflectance = 0.05
	local s = ellip(m, "Shine", V(0.2 * d, 0.3 * d, 0.05 * d), surf(Vector3.zero, rx, ry, rx, 0.4, 0.4, false, 0.01) * CFrame.Angles(0, 0, RAD(-28)), WHITE)
	s.Transparency = 0.18
	knotAndString(m, V(0, -ry, 0), d, color, stringLen or 0)
	m.PrimaryPart = body
	local cf = CF(pos)
	if facing then
		local flat = V(facing.X, pos.Y, facing.Z)
		if (flat - pos).Magnitude > 0.1 then
			cf = CFrame.lookAt(pos, flat)
		end
	end
	m:PivotTo(cf)
	m.Parent = parent
	return m
end

return BalloonArt

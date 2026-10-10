-- Plastic army units built from chunky SmoothPlastic primitives (or the hero MeshPart when one has been generated).
-- Every model faces -Z, stands on its round base with the base bottom at the model pivot (y = 0), so
-- `model:PivotTo(CFrame.lookAt(groundPos, target))` puts it on the floor facing its target.
-- Used by the server (toy-box showcases) and the client (garrisons, battles, viewport cards).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared:WaitForChild("World"))
local Config = require(Shared:WaitForChild("Config"))

local Toys = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local RAD = math.rad

export type Paint = {
	main: Color3,
	dark: Color3,
	team: Color3,
	gold: boolean,
	glow: boolean,
	rainbow: boolean,
}

type Builder = { m: Model, s: number, p: Paint, n: number, shadows: boolean }

local WHITE = Color3.fromRGB(250, 250, 250)
local BLACK = Color3.fromRGB(34, 36, 44)
local RED = Color3.fromRGB(232, 60, 60)

function Toys.paint(team: string?, mut: string?, unitKey: string?): Paint
	local tc = team and Config.Team[team] or nil
	local teamCol = tc and tc.color or Config.C.wild
	local main = teamCol
	local dark = tc and tc.dark or Config.C.wildDark
	if unitKey == "General" then
		main, dark = Config.C.gold, Config.C.goldDark
	elseif unitKey == "Dino" then
		main, dark = Config.C.metal, Config.C.metalDark
	end
	local m = mut or ""
	if m == "Gold" then
		main, dark = Config.C.gold, Config.C.goldDark
		if unitKey == "General" then
			main, dark = Color3.fromRGB(255, 226, 120), Color3.fromRGB(255, 176, 30)
		end
	elseif m == "Glow" then
		main, dark = Config.C.glow, Config.C.glowDark
	end
	return { main = main, dark = dark, team = teamCol, gold = m == "Gold", glow = m == "Glow", rainbow = m == "Rainbow" }
end

-- Part in model space (scaled by the builder). role: "main", "dark", "team", "white", "black", "red", "glass", "eye".
local function piece(b: Builder, name: string, cf: CFrame, size: Vector3, role: string, shape: Enum.PartType?, cls: string?): BasePart
	local s = b.s
	local color = b.p.main
	local material = Enum.Material.SmoothPlastic
	local reflect = 0
	local transparency = 0
	if role == "dark" then
		color = b.p.dark
	elseif role == "team" then
		color = b.p.team
	elseif role == "white" then
		color = WHITE
	elseif role == "black" then
		color = BLACK
	elseif role == "red" then
		color = RED
	elseif role == "glass" then
		color = Color3.fromRGB(170, 225, 255)
		material = Enum.Material.Glass
		transparency = 0.25
	elseif role == "eye" then
		color = Color3.fromRGB(255, 60, 60)
		material = Enum.Material.Neon
	end
	if role == "main" or role == "dark" then
		b.n += 1
		if b.p.rainbow then
			color = Color3.fromHSV((b.n * 0.137) % 1, 0.72, 1)
		elseif b.p.gold then
			reflect = 0.18
		elseif b.p.glow and role == "dark" then
			material = Enum.Material.Neon
		end
	end
	local props: { [string]: any } = {
		Class = cls or "Part",
		Name = name,
		CFrame = CF(cf.Position * s) * cf.Rotation,
		Size = size * s,
		Color = color,
		Material = material,
		Reflectance = reflect,
		Transparency = transparency,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = b.shadows,
		Parent = b.m,
	}
	if shape then
		props.Shape = shape
	end
	local p = World.part(props)
	if role == "main" or role == "dark" then
		p:SetAttribute("Paint", role)
	end
	return p
end

local function box(b: Builder, name: string, x: number, y: number, z: number, size: Vector3, role: string, rot: CFrame?): BasePart
	return piece(b, name, CF(x, y, z) * (rot or CFrame.identity), size, role)
end

local function ball(b: Builder, name: string, x: number, y: number, z: number, size: Vector3, role: string): BasePart
	return piece(b, name, CF(x, y, z), size, role, Enum.PartType.Ball)
end

-- Upright cylinder with its centre at (x, y, z).
local function cylY(b: Builder, name: string, x: number, y: number, z: number, h: number, d: number, role: string): BasePart
	return piece(b, name, CF(x, y, z) * ANG(0, 0, RAD(90)), V(h, d, d), role, Enum.PartType.Cylinder)
end

-- Cylinder lying along Z (barrels, tubes) with its centre at (x, y, z).
local function cylZ(b: Builder, name: string, x: number, y: number, z: number, len: number, d: number, role: string, rot: CFrame?): BasePart
	return piece(b, name, CF(x, y, z) * (rot or CFrame.identity) * ANG(0, RAD(90), 0), V(len, d, d), role, Enum.PartType.Cylinder)
end

-- Cylinder lying along X (wheels) with its centre at (x, y, z).
local function cylX(b: Builder, name: string, x: number, y: number, z: number, len: number, d: number, role: string): BasePart
	return piece(b, name, CF(x, y, z), V(len, d, d), role, Enum.PartType.Cylinder)
end

-- Isosceles triangle (two wedges) standing in the plane facing `cf`'s look direction: base `w` wide, `h` tall.
local function tri(b: Builder, name: string, cf: CFrame, w: number, h: number, thick: number, role: string)
	piece(b, name, cf * CF(w / 4, 0, 0) * ANG(0, RAD(-90), 0), V(thick, h, w / 2), role, nil, "WedgePart")
	piece(b, name, cf * CF(-w / 4, 0, 0) * ANG(0, RAD(90), 0), V(thick, h, w / 2), role, nil, "WedgePart")
end
Toys.tri = function(parent: Instance, cf: CFrame, w: number, h: number, thick: number, color: Color3, extra: { [string]: any }?)
	local out = {}
	for i, sgn in ipairs({ 1, -1 }) do
		local props: { [string]: any } = {
			Class = "WedgePart",
			Name = "Tri",
			CFrame = cf * CF(sgn * w / 4, 0, 0) * ANG(0, RAD(-90 * sgn), 0),
			Size = V(thick, h, w / 2),
			Color = color,
			Parent = parent,
		}
		for k, v in pairs(extra or {}) do
			props[k] = v
		end
		out[i] = World.part(props)
	end
	return out
end

local function base(b: Builder, r: number, h: number?)
	local hh = h or 0.3
	piece(b, "Base", CF(0, hh / 2, 0) * ANG(0, 0, RAD(90)), V(hh, r * 2, r * 2), "team", Enum.PartType.Cylinder)
end

-- Soldier body shared by Rifleman / Bazooka / Medic.
local function soldier(b: Builder, helmetRole: string)
	base(b, 1.3)
	box(b, "LegL", -0.3, 0.95, 0.08, V(0.5, 1.3, 0.55), "main")
	box(b, "LegR", 0.3, 0.95, -0.14, V(0.5, 1.3, 0.55), "main")
	box(b, "BootL", -0.3, 0.42, 0.0, V(0.56, 0.28, 0.8), "dark")
	box(b, "BootR", 0.3, 0.42, -0.22, V(0.56, 0.28, 0.8), "dark")
	box(b, "Belt", 0, 1.72, 0, V(1.22, 0.3, 0.72), "dark")
	box(b, "Torso", 0, 2.42, 0, V(1.18, 1.12, 0.7), "main")
	ball(b, "Head", 0, 3.32, 0, V(0.82, 0.82, 0.82), "main")
	ball(b, "Helmet", 0, 3.54, 0.02, V(1.04, 0.64, 1.08), helmetRole)
	cylY(b, "Brim", 0, 3.4, 0, 0.1, 1.22, helmetRole)
end

local function rifleman(b: Builder)
	soldier(b, "dark")
	box(b, "Pack", 0, 2.45, 0.55, V(0.86, 0.9, 0.42), "dark")
	box(b, "ArmR", 0.56, 2.7, -0.42, V(0.34, 0.34, 1.05), "main")
	box(b, "ArmL", -0.36, 2.64, -0.6, V(0.34, 0.34, 1.1), "main", ANG(0, RAD(-24), 0))
	box(b, "Rifle", 0.12, 2.8, -0.95, V(0.22, 0.28, 2.1), "dark")
	box(b, "Stock", 0.14, 2.66, 0.04, V(0.26, 0.42, 0.5), "dark")
	box(b, "Muzzle", 0.12, 2.82, -2.08, V(0.14, 0.14, 0.3), "dark")
end

local function bazooka(b: Builder)
	soldier(b, "dark")
	box(b, "Pack", 0, 2.45, 0.55, V(0.86, 0.9, 0.42), "dark")
	box(b, "ArmR", 0.62, 2.78, -0.25, V(0.34, 0.34, 0.9), "main", ANG(RAD(18), 0, 0))
	box(b, "ArmL", -0.5, 2.7, -0.55, V(0.34, 0.34, 1.0), "main", ANG(RAD(10), RAD(-30), 0))
	cylZ(b, "Tube", 0.62, 3.12, -0.35, 2.9, 0.62, "dark")
	cylZ(b, "Flare", 0.62, 3.12, 1.15, 0.36, 0.86, "main")
	cylZ(b, "Ring", 0.62, 3.12, -1.7, 0.24, 0.78, "main")
	box(b, "Sight", 0.62, 3.52, -0.6, V(0.18, 0.3, 0.3), "main")
	ball(b, "Muzzle", 0.62, 3.12, -1.88, V(0.5, 0.5, 0.5), "dark")
end

local function medic(b: Builder)
	soldier(b, "white")
	cylY(b, "Band", 0, 3.5, 0.02, 0.18, 1.1, "red")
	box(b, "Pack", 0, 2.45, 0.58, V(0.96, 1.0, 0.46), "white")
	box(b, "CrossV", 0, 2.45, 0.82, V(0.18, 0.6, 0.04), "red")
	box(b, "CrossH", 0, 2.45, 0.82, V(0.6, 0.18, 0.04), "red")
	box(b, "ArmR", 0.62, 2.35, -0.1, V(0.34, 1.0, 0.34), "main")
	box(b, "ArmL", -0.5, 2.7, -0.5, V(0.34, 0.34, 1.0), "main", ANG(0, RAD(-20), 0))
	box(b, "Kit", 0.72, 1.7, -0.12, V(0.36, 0.62, 0.8), "white")
	box(b, "KitX", 0.92, 1.7, -0.12, V(0.04, 0.18, 0.5), "red")
	box(b, "KitY", 0.92, 1.7, -0.12, V(0.04, 0.46, 0.18), "red")
	box(b, "Pistol", -0.62, 2.78, -1.1, V(0.2, 0.3, 0.6), "dark")
	box(b, "Muzzle", -0.62, 2.84, -1.42, V(0.12, 0.12, 0.12), "dark")
end

local function tank(b: Builder)
	base(b, 2.8, 0.22)
	for _, sx in ipairs({ -1, 1 }) do
		box(b, "Track", sx * 1.55, 0.86, 0, V(0.92, 1.18, 5.0), "dark")
		for i = 0, 3 do
			cylX(b, "Wheel", sx * 1.64, 0.82, -1.8 + i * 1.2, 0.98, 0.98, "main")
		end
	end
	box(b, "Hull", 0, 1.48, 0.1, V(2.4, 1.0, 4.3), "main")
	piece(b, "Glacis", CF(0, 1.48, -2.45), V(2.4, 1.0, 0.8), "main", nil, "WedgePart")
	box(b, "Deck", 0, 2.02, 0.6, V(2.0, 0.12, 2.4), "dark")
	cylY(b, "Turret", 0, 2.42, 0.35, 0.86, 2.15, "main")
	cylY(b, "Hatch", 0.35, 2.92, 0.6, 0.18, 0.86, "dark")
	cylZ(b, "Barrel", 0, 2.46, -1.6, 2.7, 0.4, "dark")
	cylZ(b, "Muzzle", 0, 2.46, -3.05, 0.42, 0.58, "dark")
	cylY(b, "Antenna", -0.7, 3.5, 0.9, 1.6, 0.08, "dark")
	ball(b, "Star", 0, 1.48, -1.92, V(0.5, 0.5, 0.12), "white")
end

local function heli(b: Builder)
	base(b, 2.5, 0.22)
	for _, sx in ipairs({ -1, 1 }) do
		cylZ(b, "Skid", sx * 1.1, 0.42, 0, 3.8, 0.22, "dark")
		box(b, "Strut", sx * 1.0, 0.86, -0.9, V(0.18, 0.9, 0.18), "dark")
		box(b, "Strut", sx * 1.0, 0.86, 0.9, V(0.18, 0.9, 0.18), "dark")
		cylZ(b, "Gun", sx * 1.25, 1.55, -0.9, 1.3, 0.24, "dark")
	end
	ball(b, "Body", 0, 1.95, 0, V(2.4, 2.2, 3.6), "main")
	ball(b, "Cockpit", 0, 2.2, -1.2, V(1.9, 1.5, 1.7), "glass")
	box(b, "Boom", 0, 2.25, 2.9, V(0.56, 0.56, 3.4), "main")
	box(b, "Fin", 0, 2.85, 4.4, V(0.16, 1.1, 0.7), "dark")
	box(b, "TailRotor", 0.24, 2.85, 4.45, V(0.08, 1.4, 0.22), "dark")
	cylY(b, "Mast", 0, 3.25, 0, 0.6, 0.34, "dark")
	cylY(b, "Hub", 0, 3.62, 0, 0.26, 0.62, "dark")
	box(b, "Rotor", 0, 3.75, 0, V(0.5, 0.08, 7.4), "dark")
	box(b, "Rotor", 0, 3.75, 0, V(7.4, 0.08, 0.5), "dark")
	box(b, "Muzzle", 1.25, 1.55, -1.6, V(0.1, 0.1, 0.1), "dark")
end

local function general(b: Builder)
	base(b, 1.45, 0.34)
	box(b, "LegL", -0.3, 0.98, 0.05, V(0.5, 1.3, 0.55), "main")
	box(b, "LegR", 0.3, 0.98, -0.05, V(0.5, 1.3, 0.55), "main")
	box(b, "BootL", -0.3, 0.46, 0.0, V(0.58, 0.3, 0.82), "dark")
	box(b, "BootR", 0.3, 0.46, -0.1, V(0.58, 0.3, 0.82), "dark")
	box(b, "Coat", 0, 1.95, 0.02, V(1.3, 1.1, 0.8), "main")
	box(b, "Belt", 0, 2.25, 0, V(1.34, 0.26, 0.84), "dark")
	box(b, "Torso", 0, 2.85, 0, V(1.26, 1.1, 0.76), "main")
	box(b, "Sash", 0, 2.7, -0.4, V(0.24, 1.4, 0.06), "team", ANG(0, 0, RAD(35)))
	ball(b, "EpauletL", -0.72, 3.32, 0, V(0.52, 0.32, 0.6), "dark")
	ball(b, "EpauletR", 0.72, 3.32, 0, V(0.52, 0.32, 0.6), "dark")
	ball(b, "Medal", -0.34, 3.0, -0.4, V(0.2, 0.2, 0.08), "red")
	ball(b, "Medal", -0.12, 3.0, -0.4, V(0.2, 0.2, 0.08), "white")
	ball(b, "Head", 0, 3.75, 0, V(0.86, 0.86, 0.86), "main")
	cylY(b, "Cap", 0, 4.1, 0, 0.42, 1.08, "dark")
	box(b, "Visor", 0, 3.94, -0.52, V(0.9, 0.08, 0.42), "dark")
	ball(b, "Badge", 0, 4.12, -0.55, V(0.26, 0.26, 0.08), "team")
	box(b, "ArmR", 0.62, 3.28, -0.55, V(0.34, 0.34, 1.25), "main", ANG(RAD(22), 0, 0))
	box(b, "ArmL", -0.72, 2.7, -0.1, V(0.34, 1.0, 0.34), "main")
	cylY(b, "FlagPole", -0.82, 2.9, -0.1, 4.4, 0.14, "dark")
	box(b, "Flag", -0.1, 4.6, -0.1, V(1.4, 0.9, 0.08), "team")
	box(b, "Cape", 0, 2.55, 0.48, V(1.3, 2.1, 0.12), "team", ANG(RAD(-8), 0, 0))
	box(b, "Muzzle", 0.62, 3.6, -1.2, V(0.1, 0.1, 0.1), "main")
end

local function dino(b: Builder)
	base(b, 3.0, 0.3)
	for _, sx in ipairs({ -1, 1 }) do
		box(b, "Thigh", sx * 1.0, 2.35, 0.45, V(1.2, 1.8, 1.6), "main")
		box(b, "Shin", sx * 1.0, 1.05, 0.7, V(0.9, 1.5, 1.0), "dark")
		box(b, "Foot", sx * 1.0, 0.52, 0.2, V(1.2, 0.46, 1.9), "dark")
		box(b, "Arm", sx * 1.15, 4.0, -1.75, V(0.4, 0.4, 0.95), "dark", ANG(RAD(-35), 0, 0))
		ball(b, "Eye", sx * 0.66, 6.05, -3.62, V(0.46, 0.46, 0.22), "eye")
	end
	box(b, "Body", 0, 3.65, 0.25, V(2.6, 2.6, 3.4), "main", ANG(RAD(-14), 0, 0))
	box(b, "Belly", 0, 3.45, -1.42, V(1.9, 1.9, 0.24), "dark", ANG(RAD(-14), 0, 0))
	box(b, "Neck", 0, 4.9, -1.55, V(1.4, 1.6, 1.4), "main")
	box(b, "Head", 0, 5.72, -2.62, V(1.9, 1.5, 2.6), "main")
	box(b, "Jaw", 0, 4.86, -2.72, V(1.7, 0.5, 2.2), "dark", ANG(RAD(8), 0, 0))
	for i = 0, 3 do
		box(b, "Tooth", -0.6 + i * 0.4, 5.06, -3.72, V(0.18, 0.26, 0.18), "white")
	end
	box(b, "Tail1", 0, 3.4, 2.55, V(1.8, 1.6, 2.0), "main")
	box(b, "Tail2", 0, 3.0, 4.25, V(1.2, 1.1, 2.0), "dark")
	box(b, "Tail3", 0, 2.7, 5.85, V(0.7, 0.7, 1.8), "main")
	for i, z in ipairs({ -1.0, 0.25, 1.5, 2.9 }) do
		local h = 1.0 - i * 0.12
		tri(b, "Spike", CF(0, 5.1 - i * 0.28 + h / 2, z) * ANG(0, RAD(90), 0), 1.0, h, 0.32, "team")
	end
	ball(b, "Muzzle", 0, 5.0, -4.0, V(0.2, 0.2, 0.2), "dark")
end

local BUILDERS: { [string]: (Builder) -> () } = {
	Rifleman = rifleman,
	Bazooka = bazooka,
	Medic = medic,
	Tank = tank,
	Heli = heli,
	General = general,
	Dino = dino,
}

-- Hero MeshPart templates live in ReplicatedStorage.HeroMeshes (the server fills it from Config.Meshes).
function Toys.heroMesh(key: string): MeshPart?
	local f = ReplicatedStorage:FindFirstChild("HeroMeshes")
	local t = f and f:FindFirstChild(key)
	if t and t:IsA("MeshPart") then
		return t:Clone() :: any
	end
	return nil
end

export type BuildOpts = { team: string?, mut: string?, ring: boolean?, shadows: boolean?, scale: number? }

-- Build a unit model. Attributes: Unit, Mut, Team, Rainbow (client animates hue), Height.
function Toys.build(unitKey: string, opts: BuildOpts?): Model
	local o: BuildOpts = opts or {}
	local def = Config.UnitByKey[unitKey]
	local m = Instance.new("Model")
	m.Name = unitKey
	local s = (def and def.scale or 1) * (o.scale or 1)
	local b: Builder = { m = m, s = s, p = Toys.paint(o.team, o.mut, unitKey), n = 0, shadows = o.shadows == true }
	local hero = Toys.heroMesh(unitKey)
	local height = 3.8
	if hero then
		local info = Config.Meshes[unitKey]
		base(b, (info and info.size.X or 2.6) * 0.5 / s)
		hero.Anchored = true
		hero.CanCollide = false
		hero.CanQuery = false
		hero.CanTouch = false
		hero.CastShadow = b.shadows
		hero.Material = Enum.Material.SmoothPlastic
		hero.Color = b.p.rainbow and Color3.fromHSV(math.random(), 0.7, 1) or b.p.main
		hero.Reflectance = b.p.gold and 0.18 or 0
		hero.Size = hero.Size * (o.scale or 1)
		hero.CFrame = CF(0, 0.3 * s + hero.Size.Y / 2, 0)
		hero:SetAttribute("Paint", "main")
		hero.Parent = m
		height = hero.Size.Y + 0.3 * s
	else
		local fn = BUILDERS[unitKey] or rifleman
		fn(b)
		local _, size = m:GetBoundingBox()
		height = size.Y
	end
	if o.ring then
		local r = (unitKey == "Tank" or unitKey == "Heli" or unitKey == "Dino") and 3.3 or 1.8
		local ring = World.part({
			Name = "Ring",
			Shape = Enum.PartType.Cylinder,
			Size = V(0.08, r * 2 * s, r * 2 * s),
			CFrame = CF(0, 0.05, 0) * ANG(0, 0, RAD(90)),
			Color = b.p.team,
			Material = Enum.Material.Neon,
			Transparency = 0.25,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Parent = m,
		})
		ring:SetAttribute("Paint", "ring")
	end
	if b.p.glow then
		local core = m:FindFirstChild("Torso") or m:FindFirstChild("Body") or m:FindFirstChild("Hull") or m:FindFirstChildWhichIsA("BasePart")
		if core then
			local light = Instance.new("PointLight")
			light.Color = Config.C.glowDark
			light.Range = 9 * s
			light.Brightness = 1.6
			light.Parent = core
		end
	end
	m.WorldPivot = CFrame.identity
	m:SetAttribute("Unit", unitKey)
	m:SetAttribute("Mut", o.mut or "")
	m:SetAttribute("Team", o.team or "")
	m:SetAttribute("Height", height)
	if b.p.rainbow then
		m:SetAttribute("Rainbow", true)
	end
	return m
end

-- Where projectiles leave a model (world position).
function Toys.muzzle(m: Model): Vector3
	local p = m:FindFirstChild("Muzzle")
	if p and p:IsA("BasePart") then
		return p.Position
	end
	local h = (m:GetAttribute("Height") :: number?) or 3
	return m:GetPivot().Position + Vector3.new(0, h * 0.7, 0)
end

-- Paint every "main"/"dark" part one colour (index silhouettes, hit flashes). Returns the old colours.
function Toys.tint(m: Model, color: Color3): { [BasePart]: Color3 }
	local old: { [BasePart]: Color3 } = {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("Paint") ~= "ring" then
			local bp = d :: BasePart
			old[bp] = bp.Color
			bp.Color = color
		end
	end
	return old
end

return Toys

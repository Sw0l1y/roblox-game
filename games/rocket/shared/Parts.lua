-- Rocket parts built from palette primitives (PROTOCOL 4.3: theme words hijack AI meshes, and primitives match a
-- SmoothPlastic world exactly). One builder serves the server rocket and the client's carried parts, so a part
-- looks the same in your arms and bolted on. Also: rocket layouts per planet/size, rider seats, paint and ghosts.
-- Local frame of every part: origin = bottom centre, +Y up, -Z = the rocket's front (towards spawn).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tiers = require(Shared:WaitForChild("Tiers"))

local Parts = {}

local V3 = Vector3.new
local CF = CFrame.new
local RAD = math.rad
local P = Config.Palette

export type Slot = { i: number, kind: string, cf: CFrame, scale: number, pre: boolean }
export type Layout = {
	slots: { Slot },
	height: number,
	radius: number,
	scale: number,
	seats: { CFrame },
	vipSeats: { CFrame },
	mvpSeat: CFrame,
	tanks: number,
	boosters: number,
	capsuleY: number,
}

-- Dimensions (installed orientation) at scale 1: height, horizontal radius.
local DIMS: { [string]: { number } } = {
	engine = { 6, 7.8 },
	tank = { 14, 8.3 },
	deck = { 2.6, 13 },
	capsule = { 10, 8.3 },
	nose = { 9, 5.3 },
	booster = { 28, 3.2 },
	tip = { 5, 3.1 },
	fin = { 16, 5 },
	crate = { 5.4, 3.6 },
}

function Parts.dims(kind: string, s: number): (number, number)
	local d = DIMS[kind] or { 5, 3 }
	return d[1] * s, d[2] * s
end

-- Extent below the centre and horizontal half-width in carry/rest orientation (boosters lie down).
function Parts.halfDown(kind: string, s: number): number
	local h, r = Parts.dims(kind, s)
	local k = Config.Kinds[kind]
	if k and k.lie then
		return r
	end
	return h / 2
end

function Parts.halfWidth(kind: string, s: number): number
	local h, r = Parts.dims(kind, s)
	local k = Config.Kinds[kind]
	if k and k.lie then
		return h / 2
	end
	return r
end

-- CFrame for the model pivot (bottom centre) so the part's centre sits at `center`, turned by `yaw`.
function Parts.centerCF(kind: string, s: number, center: Vector3, yaw: number): CFrame
	local h = Parts.dims(kind, s)
	local k = Config.Kinds[kind]
	local rot = (k and k.lie) and CFrame.Angles(0, 0, RAD(90)) or CFrame.new()
	return CF(center) * CFrame.Angles(0, yaw, 0) * rot * CF(0, -h / 2, 0)
end

-- Building ------------------------------------------------------------------------------------------

local function add(m: Model, role: string, props: { [string]: any }): BasePart
	local p = Instance.new(props.Class or "Part") :: any
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	for k, v in pairs(props) do
		if k ~= "Class" then
			p[k] = v
		end
	end
	p:SetAttribute("Role", role)
	p.Parent = m
	return p
end

-- Upright cylinder with base centre at (x, y0, z).
local function cyl(m: Model, role: string, y0: number, h: number, d: number, x: number?, z: number?): BasePart
	return add(m, role, {
		Name = role,
		Shape = Enum.PartType.Cylinder,
		Size = V3(h, d, d),
		CFrame = CF(x or 0, y0 + h / 2, z or 0) * CFrame.Angles(0, 0, RAD(90)),
	})
end

local function ball(m: Model, role: string, pos: Vector3, size: Vector3): BasePart
	return add(m, role, { Name = role, Shape = Enum.PartType.Ball, Size = size, CFrame = CF(pos) })
end

local function box(m: Model, role: string, cf: CFrame, size: Vector3): BasePart
	return add(m, role, { Name = role, Size = size, CFrame = cf })
end

-- Round window facing outward at angle `a` (radians, 0 = +X) on a body of radius `r`.
local function window(m: Model, a: number, y: number, r: number, d: number, s: number)
	local dir = V3(math.cos(a), 0, math.sin(a))
	local c = V3(0, y, 0) + dir * r
	add(m, "accent", {
		Name = "WindowRim",
		Shape = Enum.PartType.Cylinder,
		Size = V3(0.6 * s, d + 1 * s, d + 1 * s),
		CFrame = CFrame.lookAt(c - dir * 0.1, c + dir) * CFrame.Angles(0, RAD(90), 0),
	})
	add(m, "glow", {
		Name = "Window",
		Shape = Enum.PartType.Cylinder,
		Size = V3(0.7 * s, d, d),
		CFrame = CFrame.lookAt(c + dir * 0.05, c + dir) * CFrame.Angles(0, RAD(90), 0),
	})
end

-- Stepped cone (chunky low-poly cone from tapering discs) with an accent tip.
local function cone(m: Model, base: number, height: number, slices: number, tipFrom: number, s: number)
	local h = (height - base * 0.16) / slices
	for k = 0, slices - 1 do
		local d = base * (1 - k / slices) + 0.2 * s
		cyl(m, k >= tipFrom and "accent" or "body", k * h, h + 0.02, d)
	end
	ball(m, "accent", V3(0, slices * h + base * 0.06, 0), V3(base * 0.22, base * 0.22, base * 0.22))
end

local function heroMesh(key: string): MeshPart?
	local f = ReplicatedStorage:FindFirstChild("HeroMeshes")
	local mp = f and f:FindFirstChild(key)
	if mp and mp:IsA("MeshPart") then
		return (mp :: any):Clone()
	end
	return nil
end

local builders: { [string]: (Model, number) -> () } = {}

builders.engine = function(m: Model, s: number)
	cyl(m, "metalDark", 0, 1.2 * s, 14 * s)
	cyl(m, "metal", 1.2 * s, 1.4 * s, 12.4 * s)
	cyl(m, "metalDark", 2.6 * s, 1.4 * s, 10.8 * s)
	cyl(m, "metal", 4 * s, 1 * s, 9.4 * s)
	cyl(m, "accent", 5 * s, 1 * s, 15.6 * s)
	cyl(m, "fire", -0.05 * s, 0.3 * s, 12.6 * s)
	for i = 0, 3 do
		local a = RAD(45 + i * 90)
		local x, z = math.cos(a) * 5.6 * s, math.sin(a) * 5.6 * s
		cyl(m, "trim", 1.2 * s, 3.8 * s, 1.1 * s, x, z)
	end
end

builders.tank = function(m: Model, s: number)
	cyl(m, "body", 0, 14 * s, 16 * s)
	cyl(m, "accent", 0, 2 * s, 16.6 * s)
	cyl(m, "accent", 12.6 * s, 1.4 * s, 16.6 * s)
	cyl(m, "trim", 6.4 * s, 0.6 * s, 16.3 * s)
	for _, deg in ipairs({ -90, 30, 150 }) do
		window(m, RAD(deg), 9.6 * s, 8 * s, 3.2 * s, s)
	end
	-- two short hazard plates either side of the front window
	for _, deg in ipairs({ -60, -120 }) do
		local a = RAD(deg)
		local dir = V3(math.cos(a), 0, math.sin(a))
		local c = V3(0, 3.8 * s, 0) + dir * 8.05 * s
		box(m, "trim", CFrame.lookAt(c, c + dir), V3(2.4 * s, 1.4 * s, 0.4 * s))
	end
end

builders.deck = function(m: Model, s: number)
	cyl(m, "accent", 0, 2 * s, 16.6 * s)
	cyl(m, "metal", 1.5 * s, 0.5 * s, 26 * s)
	cyl(m, "trim", 1.1 * s, 0.4 * s, 25.2 * s)
	local n = 12
	local r = 12.4 * s
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local a2 = (i + 1) / n * math.pi * 2
		local p1 = V3(math.cos(a) * r, 0, math.sin(a) * r)
		local p2 = V3(math.cos(a2) * r, 0, math.sin(a2) * r)
		box(m, "trim", CF(p1 + V3(0, 3.1 * s, 0)), V3(0.5 * s, 2.2 * s, 0.5 * s))
		local mid = (p1 + p2) / 2 + V3(0, 4.25 * s, 0)
		box(m, "accent", CFrame.lookAt(mid, (p2 + V3(0, 4.25 * s, 0))), V3(0.45 * s, 0.45 * s, (p2 - p1).Magnitude + 0.4 * s))
	end
end

builders.capsule = function(m: Model, s: number)
	cyl(m, "accent", 0, 1 * s, 16.6 * s)
	local slices = 5
	for k = 0, slices - 1 do
		local d = (16 - k * 1.6) * s
		cyl(m, "body", k * 1.9 * s, 1.95 * s, d)
	end
	cyl(m, "accent", 9.5 * s, 0.5 * s, 9.6 * s)
	window(m, RAD(-90), 4.8 * s, 6.6 * s, 4.4 * s, s)
	window(m, RAD(-30), 4.4 * s, 6.8 * s, 2.6 * s, s)
	window(m, RAD(-150), 4.4 * s, 6.8 * s, 2.6 * s, s)
	window(m, RAD(90), 4.4 * s, 6.8 * s, 2.6 * s, s)
	-- VIP window balcony (gold) right under the big front window
	box(m, "gold", CF(0, 2.35 * s, -9.4 * s), V3(7 * s, 0.5 * s, 3.4 * s))
	box(m, "gold", CF(0, 3.4 * s, -11.05 * s), V3(7 * s, 1.6 * s, 0.3 * s))
	box(m, "gold", CF(-3.4 * s, 3.4 * s, -9.4 * s), V3(0.3 * s, 1.6 * s, 3.4 * s))
	box(m, "gold", CF(3.4 * s, 3.4 * s, -9.4 * s), V3(0.3 * s, 1.6 * s, 3.4 * s))
end

builders.nose = function(m: Model, s: number)
	local mp = heroMesh("noseCone")
	if mp then
		mp.Size = V3(10 * s, 9 * s, 10 * s)
		mp.CFrame = CF(0, 4.5 * s, 0)
		mp.Anchored = true
		mp:SetAttribute("Role", "mesh")
		mp.Parent = m
		return
	end
	cyl(m, "accent", 0, 0.7 * s, 10.6 * s)
	local base = 10 * s
	local h = 8.4 * s
	local slices = 7
	local sh = h / slices
	for k = 0, slices - 1 do
		local d = base * (1 - k / slices) + 0.3 * s
		cyl(m, k >= 5 and "accent" or "body", 0.6 * s + k * sh, sh + 0.02, d)
	end
	ball(m, "accent", V3(0, 0.6 * s + h, 0), V3(1.8 * s, 1.8 * s, 1.8 * s))
end

builders.tip = function(m: Model, s: number)
	local mp = heroMesh("noseCone")
	if mp then
		mp.Size = V3(6 * s, 5 * s, 6 * s)
		mp.CFrame = CF(0, 2.5 * s, 0)
		mp.Anchored = true
		mp:SetAttribute("Role", "mesh")
		mp.Parent = m
		return
	end
	cone(m, 6 * s, 5 * s, 5, 3, s)
end

builders.booster = function(m: Model, s: number)
	cyl(m, "metalDark", 0, 0.8 * s, 5.4 * s)
	cyl(m, "metal", 0.8 * s, 1.2 * s, 4.6 * s)
	cyl(m, "fire", -0.05 * s, 0.2 * s, 4.6 * s)
	cyl(m, "body", 2 * s, 26 * s, 6 * s)
	cyl(m, "accent", 4 * s, 1.6 * s, 6.3 * s)
	cyl(m, "accent", 23.6 * s, 1.6 * s, 6.3 * s)
	cyl(m, "trim", 14 * s, 0.8 * s, 6.3 * s)
	cyl(m, "accent", 27.6 * s, 0.4 * s, 6.2 * s)
	for i = 0, 2 do
		local a = RAD(i * 120 + 30)
		local dir = V3(math.cos(a), 0, math.sin(a))
		local c = V3(0, 4.2 * s, 0) + dir * 4.1 * s
		add(m, "accent", {
			Class = "WedgePart",
			Name = "BoosterFin",
			Size = V3(0.6 * s, 4 * s, 2.4 * s),
			CFrame = CFrame.lookAt(c, c + dir),
		})
	end
end

builders.fin = function(m: Model, s: number)
	add(m, "accent", {
		Class = "WedgePart",
		Name = "Fin",
		Size = V3(2 * s, 16 * s, 10 * s),
		CFrame = CF(0, 8 * s, 0),
	})
	box(m, "trim", CF(0, 0.5 * s, -3.6 * s), V3(2.3 * s, 1 * s, 2.8 * s))
	box(m, "body", CF(0, 8 * s, 4.4 * s), V3(2.3 * s, 16 * s, 1.2 * s))
end

builders.crate = function(m: Model, s: number)
	local c = box(m, "gold", CF(0, 2.7 * s, 0), V3(5 * s, 5 * s, 5 * s))
	box(m, "white", c.CFrame, V3(5.15 * s, 0.7 * s, 5.15 * s))
	box(m, "white", c.CFrame, V3(0.7 * s, 5.15 * s, 5.15 * s))
	box(m, "trim", CF(0, 0.15 * s, 0), V3(5.4 * s, 0.3 * s, 5.4 * s))
	ball(m, "glow", V3(0, 5.6 * s, 0), V3(1.8 * s, 1.8 * s, 1.8 * s))
end

-- Build a part model at the world origin (pivot = bottom centre). opts.collide (default true).
function Parts.build(kind: string, s: number, opts: { collide: boolean? }?): Model
	local m = Instance.new("Model")
	m.Name = kind
	local b = builders[kind] or builders.crate
	b(m, s)
	m.WorldPivot = CFrame.new()
	local collide = not (opts and opts.collide == false)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			local bp = d :: BasePart
			local role = bp:GetAttribute("Role")
			bp.CanCollide = collide and role ~= "fire" and role ~= "glow"
			if not collide then
				bp.CanQuery = false
			end
		end
	end
	return m
end

-- Paint -----------------------------------------------------------------------------------------------

export type Colors = { body: Color3, accent: Color3, trim: Color3, metal: Color3, metalDark: Color3, glow: Color3 }

function Parts.colors(skinKey: string?, tier: string?): Colors
	local sk = Config.skin(skinKey)
	local t = Tiers.get(tier or "Common")
	local idx = Tiers.index[t.key] or 1
	local c: Colors = {
		body = sk.body,
		accent = sk.accent,
		trim = sk.trim,
		metal = sk.metal,
		metalDark = sk.metal:Lerp(Color3.new(0, 0, 0), 0.25),
		glow = sk.glow,
	}
	if idx >= 2 and idx <= 4 then
		c.accent = t.color
		c.glow = t.color:Lerp(Color3.new(1, 1, 1), 0.25)
	elseif t.key == "Legendary" then
		c.body = P.gold
		c.accent = Color3.fromRGB(255, 250, 235)
		c.trim = Color3.fromRGB(196, 130, 24)
		c.glow = Color3.fromRGB(255, 240, 150)
	elseif t.key == "Mythic" then
		c.body = t.color
		c.accent = P.gold
		c.trim = t.dark
		c.glow = Color3.fromRGB(255, 190, 215)
	elseif t.key == "Secret" then
		c.body = Color3.fromRGB(44, 42, 70)
		c.accent = Color3.new(1, 1, 1)
		c.trim = Color3.fromRGB(24, 22, 40)
		c.glow = Color3.new(1, 1, 1)
	end
	return c
end

local function roleColor(role: string, c: Colors): (Color3, boolean)
	if role == "body" then
		return c.body, false
	elseif role == "accent" then
		return c.accent, false
	elseif role == "trim" then
		return c.trim, false
	elseif role == "metal" then
		return c.metal, false
	elseif role == "metalDark" then
		return c.metalDark, false
	elseif role == "glow" then
		return c.glow, true
	elseif role == "fire" then
		return P.orange, true
	elseif role == "gold" then
		return P.gold, false
	elseif role == "white" then
		return Color3.new(1, 1, 1), false
	end
	return c.body, false
end

-- Solid look for a skin + rarity. Secret parts get their accents tagged "Rainbow" (clients animate them).
function Parts.paint(m: Instance, skinKey: string?, tier: string?)
	local c = Parts.colors(skinKey, tier)
	local secret = tier == "Secret"
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			local bp = d :: BasePart
			local role = bp:GetAttribute("Role")
			if type(role) == "string" and role ~= "hit" then
				bp.Transparency = 0
				if role == "mesh" then
					bp.Material = Enum.Material.SmoothPlastic
					bp.Color = Color3.new(1, 1, 1)
				else
					local col, neon = roleColor(role, c)
					bp.Color = col
					bp.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
				end
				if secret and role == "accent" then
					CollectionService:AddTag(bp, "Rainbow")
				else
					CollectionService:RemoveTag(bp, "Rainbow")
				end
			end
		end
	end
end

-- Hologram look for an empty slot.
function Parts.ghost(m: Instance)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			local bp = d :: BasePart
			local role = bp:GetAttribute("Role")
			if type(role) == "string" and role ~= "hit" then
				bp.Material = Enum.Material.Neon
				bp.Color = P.glow
				bp.Transparency = 0.82
				bp.CanCollide = false
				CollectionService:RemoveTag(bp, "Rainbow")
			end
		end
	end
end

-- Layout ----------------------------------------------------------------------------------------------

-- Slots in build order (lower first). size: 1 small (solo/duo), 2 medium, 3 large.
function Parts.layout(planetIndex: number, size: number): Layout
	local pl = Config.planet(planetIndex)
	local s = pl.scale
	local tanks = 2 + pl.extraTanks + (size - 1)
	local nb = size == 1 and 2 or (size == 2 and 4 or 6)
	local nf = nb == 6 and 6 or 4
	local slots: { Slot } = {}
	local function push(kind: string, cf: CFrame, pre: boolean)
		table.insert(slots, { i = #slots + 1, kind = kind, cf = cf, scale = s, pre = pre })
	end
	push("engine", CF(0, 0, 0), true)
	local finStart = nb == 6 and 30 or 45
	local finStep = 360 / nf
	for k = 0, nf - 1 do
		local a = RAD(finStart + k * finStep)
		local dir = V3(math.cos(a), 0, math.sin(a))
		local pos = dir * 13 * s + V3(0, 4 * s, 0)
		push("fin", CFrame.lookAt(pos, pos + dir), true)
	end
	local y = 6 * s
	local deckYs: { number } = {}
	for k = 1, tanks do
		push("tank", CF(0, y, 0), k == 1)
		y += 14 * s
		if k < tanks then
			push("deck", CF(0, y, 0), false)
			table.insert(deckYs, y + 2 * s)
			y += 2 * s
		end
	end
	local boosterR = 11.6 * s
	for j = 0, nb - 1 do
		local a = RAD(j * 360 / nb)
		push("booster", CF(math.cos(a) * boosterR, 1 * s, math.sin(a) * boosterR) * CFrame.Angles(0, -a, 0), false)
	end
	for j = 0, nb - 1 do
		local a = RAD(j * 360 / nb)
		push("tip", CF(math.cos(a) * boosterR, 29 * s, math.sin(a) * boosterR), false)
	end
	local capsuleY = y
	push("capsule", CF(0, y, 0), false)
	y += 10 * s
	push("nose", CF(0, y, 0), false)
	y += 9 * s

	-- Rider seats: two rows on every crew deck (round-robin so riders spread out).
	local rows: { { CFrame } } = {}
	for _, dy in ipairs(deckYs) do
		for _, r in ipairs({ 9.7 * s, 11.4 * s }) do
			local row = {}
			local n = math.max(8, math.floor(2 * math.pi * r / 3.4))
			for i = 0, n - 1 do
				local a = (i + (r > 10.5 * s and 0.5 or 0)) / n * math.pi * 2
				-- side boosters pass through the deck ring: no seats inside them
				local clear = true
				for j = 0, nb - 1 do
					local diff = math.abs((a - j * 2 * math.pi / nb + math.pi) % (2 * math.pi) - math.pi)
					if diff < 0.38 then
						clear = false
					end
				end
				if clear then
					local pos = V3(math.cos(a) * r, dy, math.sin(a) * r)
					table.insert(row, CFrame.lookAt(pos, pos + V3(math.cos(a), 0, math.sin(a))))
				end
			end
			table.insert(rows, row)
		end
	end
	local seats: { CFrame } = {}
	local longest = 0
	for _, row in ipairs(rows) do
		longest = math.max(longest, #row)
	end
	for i = 1, longest do
		for _, row in ipairs(rows) do
			if row[i] then
				table.insert(seats, row[i])
			end
		end
	end
	local vipSeats = {
		CFrame.lookAt(V3(-1.7 * s, capsuleY + 2.6 * s, -9.4 * s), V3(-1.7 * s, capsuleY + 2.6 * s, -20 * s)),
		CFrame.lookAt(V3(1.7 * s, capsuleY + 2.6 * s, -9.4 * s), V3(1.7 * s, capsuleY + 2.6 * s, -20 * s)),
	}
	return {
		slots = slots,
		height = y,
		radius = boosterR + 3 * s,
		scale = s,
		seats = seats,
		vipSeats = vipSeats,
		mvpSeat = CFrame.lookAt(V3(0, y + 0.9 * s, 0), V3(0, y + 0.9 * s, -10)),
		tanks = tanks,
		boosters = nb,
		capsuleY = capsuleY,
	}
end

-- Tallest rocket a planet can have (for sizing its launch tower).
function Parts.maxHeight(planetIndex: number): number
	return Parts.layout(planetIndex, 3).height
end

return Parts

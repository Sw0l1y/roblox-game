-- World building in the house style (PROTOCOL.md §3, look test v5): flat SmoothPlastic palette parts,
-- chunky shapes, clusters instead of scatter, and our own generated MaterialVariants on big surfaces only.
-- Variant names refer to MaterialVariants that build.py writes into MaterialService (kit/materials.json +
-- games/<name>/materials.json). A textured part is coloured white: Part.Color multiplies the texture.
local CollectionService = game:GetService("CollectionService")
local MaterialService = game:GetService("MaterialService")

local World = {}

local V = Vector3.new
local CF = CFrame.new
local RAD = math.rad

-- Base materials of the variants in this place (read from MaterialService at runtime).
local variantBase: { [string]: Enum.Material } = {}
for _, v in ipairs(MaterialService:GetDescendants()) do
	if v:IsA("MaterialVariant") then
		variantBase[v.Name] = v.BaseMaterial
	end
end

function World.hasVariant(name: string): boolean
	return variantBase[name] ~= nil
end

-- Generic part maker. props may include Class ("Part"/"WedgePart"/"CornerWedgePart"/"TrussPart"),
-- Variant (MaterialVariant name), Parent, Tag, and any Part property.
function World.part(props: { [string]: any }): BasePart
	local p = Instance.new(props.Class or "Part") :: any
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local parent = props.Parent
	for k, v in pairs(props) do
		if k ~= "Class" and k ~= "Parent" and k ~= "Variant" and k ~= "Tag" then
			p[k] = v
		end
	end
	if props.Variant then
		World.texture(p, props.Variant, props.Color)
	end
	if props.Tag then
		CollectionService:AddTag(p, props.Tag)
	end
	p.Parent = parent
	return p
end

-- Apply a MaterialVariant. `tint` defaults to white; use a light grey only to darken.
function World.texture(p: BasePart, variant: string, tint: Color3?)
	local base = variantBase[variant]
	if not base then
		return -- variant not generated yet: stay flat (never fall back to stock textures)
	end
	p.Material = base
	p.MaterialVariant = variant
	p.Color = tint or Color3.new(1, 1, 1)
end

function World.folder(name: string, parent: Instance?): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or workspace
	return f
end

function World.model(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Shapes -------------------------------------------------------------------------------------------

function World.box(parent: Instance, cf: CFrame, size: Vector3, color: Color3, extra: { [string]: any }?): BasePart
	local props = { Name = "Box", CFrame = cf, Size = size, Color = color, Parent = parent }
	for k, v in pairs(extra or {}) do
		props[k] = v
	end
	return World.part(props)
end

function World.ball(parent: Instance, pos: Vector3, diameter: number, color: Color3, extra: { [string]: any }?): BasePart
	local props = { Name = "Ball", Shape = Enum.PartType.Ball, CFrame = CF(pos), Size = V(diameter, diameter, diameter), Color = color, Parent = parent }
	for k, v in pairs(extra or {}) do
		props[k] = v
	end
	return World.part(props)
end

-- Upright cylinder whose base centre is `pos`.
function World.cyl(parent: Instance, pos: Vector3, height: number, diameter: number, color: Color3, extra: { [string]: any }?): BasePart
	local props = {
		Name = "Cylinder",
		Shape = Enum.PartType.Cylinder,
		Size = V(height, diameter, diameter),
		CFrame = CF(pos + V(0, height / 2, 0)) * CFrame.Angles(0, 0, RAD(90)),
		Color = color,
		Parent = parent,
	}
	for k, v in pairs(extra or {}) do
		props[k] = v
	end
	return World.part(props)
end

-- Cylinder between two points (pipes, rails, posts).
function World.rod(parent: Instance, a: Vector3, b: Vector3, diameter: number, color: Color3, extra: { [string]: any }?): BasePart
	local len = (b - a).Magnitude
	local props = {
		Name = "Rod",
		Shape = Enum.PartType.Cylinder,
		Size = V(len, diameter, diameter),
		CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, RAD(90), 0),
		Color = color,
		Parent = parent,
	}
	for k, v in pairs(extra or {}) do
		props[k] = v
	end
	return World.part(props)
end

-- Flat disc: top surface at topY.
function World.disc(parent: Instance, x: number, z: number, radius: number, topY: number, height: number, color: Color3, variant: string?): BasePart
	return World.part({
		Name = "Disc",
		Shape = Enum.PartType.Cylinder,
		Size = V(height, radius * 2, radius * 2),
		CFrame = CF(x, topY - height / 2, z) * CFrame.Angles(0, 0, RAD(90)),
		Color = color,
		Variant = variant,
		Parent = parent,
	})
end

-- Ring of `n` boxes (fences, rims, arches seen from above).
function World.ring(parent: Instance, center: Vector3, radius: number, n: number, size: Vector3, color: Color3): { BasePart }
	local out = {}
	for i = 1, n do
		local a = (i / n) * math.pi * 2
		local pos = center + V(math.cos(a) * radius, 0, math.sin(a) * radius)
		table.insert(out, World.box(parent, CFrame.lookAt(pos, center), size, color))
	end
	return out
end

-- Terrain-like islands from overlapping discs: grass top at y=0 with a sand ring and a wet ring.
-- blobs: { {x, z, radius}, ... }
function World.island(parent: Instance, blobs: { { number } }, c: { grass: Color3, sand: Color3, wet: Color3 }, variants: { grass: string?, sand: string? }?)
	local v: { grass: string?, sand: string? } = variants or {}
	local f = World.folder("Island", parent)
	for _, b in ipairs(blobs) do
		World.disc(f, b[1], b[2], b[3], 0, 6, c.grass, v.grass)
		World.disc(f, b[1], b[2], b[3] + 9, -0.3, 5.6, c.sand, v.sand)
		World.disc(f, b[1], b[2], b[3] + 12, -0.75, 5.6, c.wet, v.sand)
	end
	return f
end

-- Flat slabs along a polyline (paths). points are Vector3 at ground level.
function World.path(parent: Instance, points: { Vector3 }, width: number, color: Color3, variant: string?, y: number?)
	local f = World.folder("Path", parent)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		World.part({
			Name = "PathSlab",
			Size = V(width, 0.4, len + width * 0.5),
			CFrame = CFrame.lookAt(V(mid.X, (y or 0.05), mid.Z), V(b.X, (y or 0.05), b.Z)),
			Color = color,
			Variant = variant,
			Parent = f,
		})
	end
	for _, p in ipairs(points) do -- round joints
		World.disc(f, p.X, p.Z, width / 2, (y or 0.05) + 0.2, 0.4, color, variant)
	end
	return f
end

-- Nature -------------------------------------------------------------------------------------------

export type Leaves = { trunk: Color3, leaf1: Color3, leaf2: Color3, leaf3: Color3 }

-- Chunky tree: tapered trunk and three stacked canopy balls.
function World.tree(parent: Instance, pos: Vector3, scale: number, c: Leaves): Model
	local m = World.model("Tree", parent)
	World.cyl(m, pos, 6 * scale, 1.8 * scale, c.trunk, { Name = "Trunk" })
	World.ball(m, pos + V(0, 8 * scale, 0), 8 * scale, c.leaf1, { Name = "Canopy" })
	World.ball(m, pos + V(1.6 * scale, 10.5 * scale, 0.8 * scale), 6 * scale, c.leaf2, { Name = "Canopy" })
	World.ball(m, pos + V(-1.2 * scale, 12 * scale, -0.6 * scale), 4.2 * scale, c.leaf3, { Name = "Canopy" })
	return m
end

function World.treeTrio(parent: Instance, pos: Vector3, c: Leaves, size: number?)
	local s = size or 1
	World.tree(parent, pos, 1.25 * s, c)
	World.tree(parent, pos + V(7 * s, 0, 3 * s), 0.95 * s, c)
	World.tree(parent, pos + V(2 * s, 0, 8 * s), 0.8 * s, c)
end

-- Pine: stacked cones from wedges look noisy, so use three shrinking balls on a thin trunk.
function World.pine(parent: Instance, pos: Vector3, scale: number, c: Leaves)
	local m = World.model("Pine", parent)
	World.cyl(m, pos, 4 * scale, 1.2 * scale, c.trunk)
	for i = 0, 2 do
		local d = (7 - i * 2) * scale
		World.part({
			Name = "Needles",
			Shape = Enum.PartType.Ball,
			Size = V(d, d * 0.8, d),
			CFrame = CF(pos + V(0, (5 + i * 3.2) * scale, 0)),
			Color = i == 1 and c.leaf2 or c.leaf1,
			Parent = m,
		})
	end
	return m
end

function World.bush(parent: Instance, pos: Vector3, c: Leaves, rng: Random, scale: number?)
	local s = scale or 1
	local sizes = { rng:NextNumber(6, 7.5) * s, rng:NextNumber(4, 5) * s, rng:NextNumber(2.5, 3.2) * s }
	local cols = { c.leaf1, c.leaf2, c.leaf3 }
	for i, d in ipairs(sizes) do
		local off = V(rng:NextNumber(-3, 3) * s, 0, rng:NextNumber(-3, 3) * s)
		World.ball(parent, pos + V(0, d * 0.32, 0) + off, d, cols[i], { Name = "Bush", CanCollide = false })
	end
end

function World.rocks(parent: Instance, pos: Vector3, c: { rock: Color3, rockDark: Color3 }, rng: Random, scale: number?)
	local sc = scale or 1
	for i = 1, 3 do
		local s = rng:NextNumber(2.5, 5.5) * sc
		local p = pos + V(rng:NextNumber(-4, 4) * sc, s * 0.3, rng:NextNumber(-4, 4) * sc)
		World.part({
			Name = "Rock",
			Size = V(s * 1.2, s * 0.8, s),
			CFrame = CF(p) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)),
			Color = i == 2 and c.rockDark or c.rock,
			Parent = parent,
		})
	end
end

function World.flowers(parent: Instance, pos: Vector3, stem: Color3, heads: { Color3 }, rng: Random)
	for i = 1, 5 do
		local p = pos + V(rng:NextNumber(-2.5, 2.5), 0, rng:NextNumber(-2.5, 2.5))
		World.part({ Name = "Stem", Size = V(0.3, 1.4, 0.3), CFrame = CF(p + V(0, 0.7, 0)), Color = stem, CanCollide = false, Parent = parent })
		World.ball(parent, p + V(0, 1.5, 0), 0.9, heads[(i - 1) % #heads + 1], { Name = "Flower", CanCollide = false })
	end
end

-- Puffy cartoon cloud from flattened white balls.
function World.cloud(parent: Instance, pos: Vector3, scale: number, rng: Random, color: Color3?)
	local col = color or Color3.fromRGB(255, 255, 255)
	local m = World.model("Cloud", parent)
	local n = rng:NextInteger(4, 6)
	for i = 1, n do
		local d = rng:NextNumber(10, 18) * scale
		local off = V((i - n / 2) * 7 * scale, rng:NextNumber(-1, 3) * scale, rng:NextNumber(-4, 4) * scale)
		World.part({
			Name = "Puff",
			Shape = Enum.PartType.Ball,
			Size = V(d, d, d), -- Roblox always draws a Ball as a sphere
			CFrame = CF(pos + off - V(0, d * 0.15, 0)),
			Color = col,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Parent = m,
		})
	end
	return m
end

-- Props -------------------------------------------------------------------------------------------

function World.crate(parent: Instance, pos: Vector3, s: number, color: Color3, band: Color3)
	local c = World.box(parent, CF(pos + V(0, s / 2, 0)), V(s, s, s), color, { Name = "Crate" })
	World.box(parent, c.CFrame, V(s + 0.12, 0.45, s + 0.12), band, { Name = "CrateBand" })
	World.box(parent, c.CFrame, V(0.45, s + 0.12, s + 0.12), band, { Name = "CrateBand" })
	return c
end

function World.barrel(parent: Instance, pos: Vector3, body: Color3, band1: Color3, band2: Color3)
	World.cyl(parent, pos, 3.6, 2.6, body, { Name = "Barrel" })
	World.cyl(parent, pos + V(0, 2.35, 0), 0.5, 2.75, band1, { Name = "BarrelBand" })
	World.cyl(parent, pos + V(0, 0.75, 0), 0.5, 2.75, band2, { Name = "BarrelBand" })
end

function World.lamp(parent: Instance, pos: Vector3, pole: Color3, glow: Color3)
	World.cyl(parent, pos, 9, 0.6, pole, { Name = "LampPole" })
	local bulb = World.ball(parent, pos + V(0, 9.6, 0), 1.8, glow, { Name = "LampBulb", Material = Enum.Material.Neon, CanCollide = false })
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = 16
	light.Brightness = 1.2
	light.Parent = bulb
end

-- Labels ------------------------------------------------------------------------------------------

-- Billboard text sized in studs (scales with distance like a 3D sign), never drawn through walls.
function World.label(adornee: Instance, text: string, opts: { [string]: any }?): BillboardGui
	local o: { [string]: any } = opts or {}
	local bb = Instance.new("BillboardGui")
	bb.Name = o.name or "Label"
	bb.Size = UDim2.fromScale(o.width or 14, o.height or 3)
	bb.StudsOffset = o.offset or V(0, 4, 0)
	bb.AlwaysOnTop = o.onTop == true
	bb.MaxDistance = o.maxDistance or 120
	bb.LightInfluence = 0
	bb.Adornee = adornee
	local l = Instance.new("TextLabel")
	l.Name = "Text"
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = o.font or Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = o.color or Color3.new(1, 1, 1)
	local s = Instance.new("UIStroke")
	s.Thickness = o.stroke or 3
	s.Color = o.strokeColor or Color3.fromRGB(25, 28, 45)
	s.Parent = l
	if o.gradient then
		local g = Instance.new("UIGradient")
		g.Color = o.gradient
		g.Rotation = 90
		g.Parent = l
	end
	l.Parent = bb
	bb.Parent = adornee
	return bb
end

-- Upright sign board with text on both faces.
function World.sign(parent: Instance, cf: CFrame, size: Vector2, text: string, board: Color3, textColor: Color3, post: Color3?): BasePart
	local b = World.box(parent, cf, V(size.X, size.Y, 0.8), board, { Name = "Sign" })
	if post then
		World.box(parent, cf * CF(-size.X / 2 + 0.6, -size.Y / 2 - 2, 0), V(0.8, 4, 0.8), post, { Name = "SignPost" })
		World.box(parent, cf * CF(size.X / 2 - 0.6, -size.Y / 2 - 2, 0), V(0.8, 4, 0.8), post, { Name = "SignPost" })
	end
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 40
		sg.LightInfluence = 0
		sg.MaxDistance = 250
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(0.92, 0.84)
		l.Position = UDim2.fromScale(0.04, 0.08)
		l.Font = Enum.Font.LuckiestGuy
		l.TextScaled = true
		l.Text = text
		l.TextColor3 = textColor
		local s = Instance.new("UIStroke")
		s.Thickness = 4
		s.Color = Color3.fromRGB(25, 28, 45)
		s.Parent = l
		l.Parent = sg
		sg.Parent = b
	end
	return b
end

-- Glowing ring on the ground marking an interaction spot.
function World.pad(parent: Instance, pos: Vector3, radius: number, color: Color3): BasePart
	World.disc(parent, pos.X, pos.Z, radius + 0.6, pos.Y + 0.12, 0.3, Color3.fromRGB(30, 34, 52))
	local glow = World.disc(parent, pos.X, pos.Z, radius, pos.Y + 0.2, 0.3, color)
	glow.Material = Enum.Material.Neon
	glow.CanCollide = false
	glow.Name = "PadGlow"
	return glow
end

-- Weld every part in `model` to its PrimaryPart (or the first part) and unanchor it, for moving models.
function World.weld(model: Model): BasePart?
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not root then
		return nil
	end
	model.PrimaryPart = root :: BasePart
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root :: BasePart
			w.Part1 = d :: BasePart
			w.Parent = d
			d.Anchored = false
		end
	end
	return root :: BasePart
end

return World

-- The giant kid's bedroom, built from our own chunky SmoothPlastic palette parts (no external kits).
-- Room: X -260..260 (west..east), Z -220..220 (north..south), floor at y = 0, ceiling at y = 170.
-- North wall: window with curtains and sunbeams, the toy chest under it. NW: the bed (the cat sleeps on it)
-- with the blanket fort at its foot. NE: the desk (climb the ruler). Centre: the round rug. South: the door,
-- the block tower and the two rows of toy-box bases (green west, tan east).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared:WaitForChild("World"))
local Config = require(Shared:WaitForChild("Config"))
local Toys = require(Shared:WaitForChild("Toys"))

local Room = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local RAD = math.rad
local C = Config.C
local rgb = Color3.fromRGB

local W, D, H = 260, 220, 170
local rng = Random.new(7)

local folder: Folder
local decor: Folder

local function merge(base: { [string]: any }, extra: { [string]: any }?): { [string]: any }
	for k, v in pairs(extra or {}) do
		base[k] = v
	end
	return base
end

-- Structure: solid, casts shadows, never fires Touched.
local function solid(cf: CFrame, size: Vector3, color: Color3, extra: { [string]: any }?): BasePart
	return World.part(merge({ Name = "Solid", CFrame = cf, Size = size, Color = color, CanTouch = false, Parent = folder }, extra))
end

-- Decor: no queries, no touch, no shadow. Collides unless told otherwise.
local function prop(cf: CFrame, size: Vector3, color: Color3, extra: { [string]: any }?): BasePart
	return World.part(merge({
		Name = "Prop",
		CFrame = cf,
		Size = size,
		Color = color,
		CanTouch = false,
		CanQuery = false,
		CastShadow = false,
		Parent = decor,
	}, extra))
end

local function ball(pos: Vector3, size: Vector3, color: Color3, extra: { [string]: any }?): BasePart
	return prop(CF(pos), size, color, merge({ Name = "Ball", Shape = Enum.PartType.Ball }, extra))
end

-- Upright cylinder, base centre at pos.
local function cyl(pos: Vector3, h: number, d: number, color: Color3, extra: { [string]: any }?): BasePart
	return prop(CF(pos + V(0, h / 2, 0)) * ANG(0, 0, RAD(90)), V(h, d, d), color, merge({ Name = "Cylinder", Shape = Enum.PartType.Cylinder }, extra))
end

-- Cylinder between two points.
local function rod(a: Vector3, b: Vector3, d: number, color: Color3, extra: { [string]: any }?): BasePart
	return prop(CFrame.lookAt((a + b) / 2, b) * ANG(0, RAD(90), 0), V((b - a).Magnitude, d, d), color, merge({ Name = "Rod", Shape = Enum.PartType.Cylinder }, extra))
end

-- Text on one face of a part (posters, labels on blocks).
local function faceText(part: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font?, bg: Color3?)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 20
	sg.LightInfluence = 0.3
	sg.MaxDistance = 300
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = bg and 0 or 1
	l.BackgroundColor3 = bg or Color3.new(1, 1, 1)
	l.Font = font or Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = C.ink
	s.Parent = l
	l.Parent = sg
	sg.Parent = part
end

-- Shell: floor, walls, trim, ceiling -----------------------------------------------------------------------

local function shell()
	local floor = World.part({ Name = "Floor", CFrame = CF(0, -1, 0), Size = V(W * 2 + 8, 2, D * 2 + 8), Color = C.floor, CanTouch = false, Parent = folder })
	World.texture(floor, "ToyFloorWood")
	if not World.hasVariant("ToyFloorWood") then
		-- flat fallback: long planks with staggered joints
		local z = -D + 22
		local row = 0
		while z < D do
			prop(CF(0, 0.03, z), V(W * 2, 0.06, 0.45), C.floorSeam, { CanCollide = false })
			row += 1
			for k = 0, 2 do
				local x = -W + ((row * 97 + k * 173) % (W * 2))
				prop(CF(x, 0.03, z - 11), V(0.45, 0.06, 21.5), C.floorSeam, { CanCollide = false })
			end
			z += 22
		end
	end

	-- lower walls (0..72) in the main wallpaper colour, upper walls lighter, white chair rail and baseboard
	local function wall(x0: number, x1: number, y0: number, y1: number, z: number, color: Color3, alongZ: boolean)
		local len = x1 - x0
		local h = y1 - y0
		local mid = (x0 + x1) / 2
		if alongZ then
			solid(CF(z, (y0 + y1) / 2, mid), V(4, h, len), color, { Name = "Wall" })
		else
			solid(CF(mid, (y0 + y1) / 2, z), V(len, h, 4), color, { Name = "Wall" })
		end
	end
	-- north wall with the window hole X -55..55, Y 60..135
	wall(-W - 4, -55, 0, 72, -D - 2, C.wall, false)
	wall(55, W + 4, 0, 72, -D - 2, C.wall, false)
	wall(-55, 55, 0, 60, -D - 2, C.wall, false)
	wall(-W - 4, -55, 72, H, -D - 2, C.wallTop, false)
	wall(55, W + 4, 72, H, -D - 2, C.wallTop, false)
	wall(-55, 55, 135, H, -D - 2, C.wallTop, false)
	-- south, west, east
	wall(-W - 4, W + 4, 0, 72, D + 2, C.wall, false)
	wall(-W - 4, W + 4, 72, H, D + 2, C.wallTop, false)
	wall(-D - 4, D + 4, 0, 72, -W - 2, C.wall, true)
	wall(-D - 4, D + 4, 72, H, -W - 2, C.wallTop, true)
	wall(-D - 4, D + 4, 0, 72, W + 2, C.wall, true)
	wall(-D - 4, D + 4, 72, H, W + 2, C.wallTop, true)

	-- trim: baseboards and chair rails (decor, no collision so nothing snags)
	for _, y in ipairs({ 4, 72 }) do
		local h = y == 4 and 8 or 3
		prop(CF(0, y, -D + 0.75), V(W * 2, h, 1.5), C.trim, { CanCollide = false })
		prop(CF(0, y, D - 0.75), V(W * 2, h, 1.5), C.trim, { CanCollide = false })
		prop(CF(-W + 0.75, y, 0), V(1.5, h, D * 2), C.trim, { CanCollide = false })
		prop(CF(W - 0.75, y, 0), V(1.5, h, D * 2), C.trim, { CanCollide = false })
	end
	-- polka dots on the upper wallpaper (big, soft, sparse)
	local dots = { rgb(255, 236, 170), rgb(255, 205, 214), rgb(214, 246, 214) }
	for i = 1, 14 do
		local x = -W + 30 + (i - 1) * 36
		if math.abs(x) > 80 then
			prop(CF(x, 150 - (i % 2) * 12, -D + 0.3) * ANG(0, RAD(90), 0), V(0.4, 8, 8), dots[i % 3 + 1], { Shape = Enum.PartType.Cylinder, CanCollide = false })
		end
		prop(CF(x, 150 - (i % 2) * 12, D - 0.3) * ANG(0, RAD(90), 0), V(0.4, 8, 8), dots[(i + 1) % 3 + 1], { Shape = Enum.PartType.Cylinder, CanCollide = false })
	end

	solid(CF(0, H + 2, 0), V(W * 2 + 8, 4, D * 2 + 8), C.ceiling, { Name = "Ceiling", CastShadow = false })
	-- ceiling lamp
	World.disc(decor, 0, 0, 26, H, 2.5, C.trim)
	local glow = World.disc(decor, 0, 0, 21, H - 2.3, 0.6, rgb(255, 244, 214))
	glow.Material = Enum.Material.Neon
	glow.CanCollide = false
	glow.CastShadow = false
end

-- Window, curtains, sunbeams, the outside ----------------------------------------------------------------

local function windowAndSun()
	local z = -D
	-- frame
	prop(CF(-57, 97.5, z + 1), V(4, 83, 6), C.trim)
	prop(CF(57, 97.5, z + 1), V(4, 83, 6), C.trim)
	prop(CF(0, 137, z + 1), V(118, 4, 6), C.trim)
	solid(CF(0, 58.5, z + 5), V(126, 3, 14), C.trim, { Name = "Sill" })
	prop(CF(0, 97.5, z - 1), V(3, 75, 3), C.trim)
	prop(CF(0, 97.5, z - 1), V(110, 3, 3), C.trim)
	World.part({
		Name = "Glass",
		CFrame = CF(0, 97.5, z - 1.6),
		Size = V(110, 75, 0.3),
		Color = rgb(214, 236, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.82,
		CanTouch = false,
		CastShadow = false,
		Parent = folder,
	})
	-- curtains
	for _, side in ipairs({ -1, 1 }) do
		for i = 0, 2 do
			local x = side * (62 + i * 6.5)
			prop(CF(x, 104, z + 3 + (i % 2) * 1.6), V(6.6, 96, 2), i % 2 == 0 and rgb(255, 186, 112) or rgb(250, 166, 96), { CanCollide = false })
		end
		prop(CF(side * 68.5, 90, z + 4), V(22, 3, 5), C.yellow, { CanCollide = false })
		ball(V(side * 84, 154, z + 4), V(5, 5, 5), C.woodDark)
	end
	rod(V(-84, 154, z + 4), V(84, 154, z + 4), 2.4, C.woodDark)
	-- window-sill props: cactus pot and a fish bowl
	cyl(V(-36, 60, z + 6), 7, 8, rgb(222, 120, 80))
	ball(V(-36, 71, z + 6), V(6, 10, 6), rgb(96, 186, 90))
	ball(V(-36, 76.5, z + 6), V(2.6, 2.6, 2.6), C.pink)
	ball(V(32, 66, z + 6), V(12, 12, 12), rgb(210, 236, 255), { Material = Enum.Material.Glass, Transparency = 0.55 })
	ball(V(32, 65, z + 6), V(10, 9, 10), rgb(110, 190, 255), { Transparency = 0.45 })
	ball(V(32, 65.5, z + 6), V(1.6, 2.2, 3), C.orange, { Material = Enum.Material.Neon })

	-- outside: lawn, trees, hills (sunlit; seen through the window)
	local lawn = World.part({ Name = "Lawn", CFrame = CF(0, -34, -D - 360), Size = V(1400, 4, 700), Color = rgb(120, 206, 96), CanTouch = false, Parent = folder })
	World.texture(lawn, "HouseGrass")
	local leaves = { trunk = rgb(150, 100, 64), leaf1 = rgb(92, 190, 80), leaf2 = rgb(120, 214, 96), leaf3 = rgb(70, 160, 70) }
	World.tree(decor, V(-95, -32, -D - 120), 7, leaves)
	World.tree(decor, V(110, -32, -D - 190), 8.5, leaves)
	World.tree(decor, V(-30, -32, -D - 330), 10, leaves)
	for i, x in ipairs({ -420, 0, 380 }) do
		ball(V(x, -60, -D - 650), V(520, 170 + i * 20, 220), rgb(110, 196, 110), { CanCollide = false })
	end
	-- fence
	for i = -9, 9 do
		prop(CF(i * 22, -20, -D - 70), V(4, 26, 2), C.white)
	end
	prop(CF(0, -14, -D - 70), V(420, 3, 1.5), C.white)

	-- sunbeams: soft glowing ribbons from the window to the floor, a window-shaped light patch, dust motes
	local anchor = World.part({ Name = "SunAnchor", CFrame = CF(0, 0, 0), Size = V(1, 1, 1), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = decor })
	for i, x in ipairs({ -38, -13, 13, 38 }) do
		local a0 = Instance.new("Attachment")
		a0.WorldPosition = V(x, 108 - (i % 2) * 8, z + 1)
		a0.Parent = anchor
		local a1 = Instance.new("Attachment")
		a1.WorldPosition = V(x * 1.35, 0.4, -78 + (i % 2) * 6)
		a1.Parent = anchor
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Color = ColorSequence.new(rgb(255, 238, 196))
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.62),
			NumberSequenceKeypoint.new(0.55, 0.84),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Width0 = 20
		beam.Width1 = 34
		beam.FaceCamera = true
		beam.Segments = 1
		beam.Parent = anchor
	end
	for _, px in ipairs({ -26, 26 }) do
		for _, pz in ipairs({ -95, -61 }) do
			prop(CF(px, 0.08, pz), V(48, 0.06, 30), rgb(255, 230, 170), { Material = Enum.Material.Neon, Transparency = 0.8, CanCollide = false })
		end
	end
	local motes = World.part({ Name = "Motes", CFrame = CF(0, 55, -130), Size = V(90, 70, 110), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = decor })
	local pe = Instance.new("ParticleEmitter")
	pe.Shape = Enum.ParticleEmitterShape.Box
	pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	pe.Rate = 7
	pe.Lifetime = NumberRange.new(6, 10)
	pe.Speed = NumberRange.new(0.2, 0.7)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new(0.35)
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.35), NumberSequenceKeypoint.new(0.8, 0.35), NumberSequenceKeypoint.new(1, 1) })
	pe.LightEmission = 1
	pe.Color = ColorSequence.new(rgb(255, 240, 200))
	pe.Parent = motes
	local sl = Instance.new("SurfaceLight")
	sl.Face = Enum.NormalId.Bottom
	sl.Angle = 90
	sl.Range = 60
	sl.Brightness = 1.2
	sl.Color = rgb(255, 232, 190)
	sl.Parent = prop(CF(0, 137.5, z + 2), V(100, 1, 4), C.trim, { CanCollide = false })
end

-- The bed (NW), teddy, sleeping spot for the cat -------------------------------------------------------------

local function bed()
	for _, x in ipairs({ -248, -108 }) do
		for _, zz in ipairs({ -208, -34 }) do
			World.cyl(folder, V(x, 0, zz), 20, 10, C.trim, { Name = "BedLeg", CanTouch = false })
		end
	end
	solid(CF(-178, 24, -121), V(156, 10, 194), C.bed, { Name = "BedFrame" })
	solid(CF(-178, 38, -121), V(150, 18, 188), C.sheet, { Name = "Mattress" })
	local top = solid(CF(-178, 48.5, -97), V(154, 3, 142), C.blanket, { Name = "Blanket" })
	World.texture(top, "ToyBlanket", C.blanket)
	local side = solid(CF(-99.5, 35, -97), V(3, 30, 142), C.blanket, { Name = "Blanket" })
	World.texture(side, "ToyBlanket", C.blanket)
	local foot = solid(CF(-178, 35, -24.5), V(156, 30, 3), C.blanket, { Name = "Blanket" })
	World.texture(foot, "ToyBlanket", C.blanket)
	for _, zz in ipairs({ -146, -98, -50 }) do
		prop(CF(-178, 48.6, zz), V(154.4, 3.2, 9), C.blanketStripe, { CanCollide = false })
		prop(CF(-99.4, 35, zz), V(3.2, 30.2, 9), C.blanketStripe, { CanCollide = false })
	end
	prop(CF(-178, 49, -171), V(154, 4, 10), C.sheet)
	ball(V(-214, 52, -194), V(64, 13, 34), C.white)
	ball(V(-142, 52, -194), V(64, 13, 34), rgb(255, 236, 240))
	-- headboard with a rounded top and star stickers
	solid(CF(-178, 40, -216), V(160, 80, 6), C.bed, { Name = "Headboard" })
	rod(V(-258, 80, -216), V(-98, 80, -216), 6, C.bed)
	for i, x in ipairs({ -226, -178, -130 }) do
		Toys.tri(decor, CF(x, 64 + (i % 2) * 4, -212.6), 10, 9, 0.6, C.yellow, { CanCollide = false, CastShadow = false, CanQuery = false })
		Toys.tri(decor, CF(x, 61.4 + (i % 2) * 4, -212.4) * ANG(0, 0, RAD(180)), 10, 9, 0.6, C.yellow, { CanCollide = false, CastShadow = false, CanQuery = false })
	end
	-- teddy bear leaning on the pillows
	local tb, tc = rgb(176, 120, 76), rgb(240, 214, 180)
	local t0 = V(-118, 47, -178)
	ball(t0 + V(0, 8, 0), V(14, 16, 12), tb)
	ball(t0 + V(0, 7, -3.5), V(9, 10, 6), tc)
	ball(t0 + V(0, 19, 0), V(12, 11, 11), tb)
	ball(t0 + V(0, 18, -5), V(5, 4, 3), tc)
	ball(t0 + V(0, 19, -6.6), V(1.6, 1.2, 1), C.ink)
	ball(t0 + V(-2.4, 21, -5), V(1.4, 1.4, 1), C.ink)
	ball(t0 + V(2.4, 21, -5), V(1.4, 1.4, 1), C.ink)
	ball(t0 + V(-5, 24.5, 0), V(4.5, 4.5, 3), tb)
	ball(t0 + V(5, 24.5, 0), V(4.5, 4.5, 3), tb)
	ball(t0 + V(-7, 9, -2), V(5, 9, 5), tb)
	ball(t0 + V(7, 9, -2), V(5, 9, 5), tb)
	ball(t0 + V(-4, 2.5, -7), V(6, 5, 9), tb)
	ball(t0 + V(4, 2.5, -7), V(6, 5, 9), tb)
	prop(CF(t0 + V(0, 14.5, -3)), V(8, 1.6, 1), C.red, { CanCollide = false })
	-- lost sock and a ball under the bed
	rod(V(-150, 2, -64), V(-130, 2, -58), 4, C.white, { CanCollide = false })
	rod(V(-130, 2, -58), V(-126, 2, -66), 4, rgb(255, 120, 120), { CanCollide = false })
	ball(V(-205, 6, -90), V(12, 12, 12), C.red)
end

-- Blanket fort at the bed's foot (zone "fort") -------------------------------------------------------------

local function fort()
	local zc = Config.ZoneById.fort.pos
	local cols = { C.white, C.pink, C.yellow, rgb(160, 210, 255), C.white, rgb(200, 240, 200) }
	for i = 0, 5 do
		local a = RAD(110 + i * 28)
		local p = zc + V(math.cos(a) * 31, 6.5, math.sin(a) * 31)
		prop(CFrame.lookAt(p, zc + V(0, 6.5, 0)), V(26, 13, 12), cols[i + 1], { Name = "Pillow", Shape = Enum.PartType.Ball })
	end
	-- pencil poles and the lean-to blanket roof sloping north toward the bed
	for _, x in ipairs({ -194, -146 }) do
		World.cyl(decor, V(x, 0, 20), 34, 3, C.yellow, { CanTouch = false, CanQuery = false })
		World.cyl(decor, V(x, 34, 20), 1.6, 3.2, C.grey, { CanTouch = false, CanQuery = false })
		World.cyl(decor, V(x, 35.6, 20), 2.6, 3.2, C.pink, { CanTouch = false, CanQuery = false })
	end
	local a, b = V(-170, 37, 20), V(-170, 46, -24)
	local roof = solid(CFrame.lookAt((a + b) / 2, b), V(62, 1.2, (b - a).Magnitude + 4), rgb(255, 142, 122), { Name = "FortRoof", CastShadow = true })
	World.texture(roof, "ToyBlanket", rgb(255, 142, 122))
	rod(V(-201, 37.5, 20), V(-139, 37.5, 20), 3, rgb(255, 142, 122))
	for i = 0, 3 do
		prop(CF(-170 + (i - 1.5) * 15, 36, 20.6), V(5, 7, 0.6), i % 2 == 0 and C.white or C.yellow, { CanCollide = false })
	end
	-- flashlight with a real spotlight, comics on the floor
	local fl = rod(V(-186, 2.2, 6), V(-178, 2.2, 1), 4.4, C.blue)
	local lens = ball(V(-177, 2.2, 0.4), V(1, 4, 4), C.yellow, { Material = Enum.Material.Neon, CanCollide = false })
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Range = 40
	spot.Angle = 50
	spot.Brightness = 2
	spot.Color = rgb(255, 236, 190)
	spot.Parent = fl
	lens.Name = "Lens"
	prop(CF(-150, 0.3, 8) * ANG(0, RAD(20), 0), V(10, 0.6, 13), C.red, { CanCollide = false })
	prop(CF(-152, 0.9, 9) * ANG(0, RAD(-10), 0), V(10, 0.6, 13), C.blue, { CanCollide = false })
	World.sign(decor, CF(-196, 8, 66) * ANG(0, RAD(150), 0), Vector2.new(22, 8), "BED FORT\nKEEP OUT!", rgb(214, 170, 120), C.ink, C.woodDark)
end

-- Desk (NE) with the ruler ramp, chair, lamp, pencils, globe ------------------------------------------------

local function desk()
	local topY = Config.ZoneById.desk.pos.Y
	local deskTop = solid(CF(180, topY - 2, -171), V(150, 4, 94), C.wood, { Name = "DeskTop" })
	deskTop.CastShadow = true
	for _, x in ipairs({ 110, 250 }) do
		for _, zz in ipairs({ -213, -129 }) do
			solid(CF(x, (topY - 4) / 2, zz), V(6, topY - 4, 6), C.trim, { Name = "DeskLeg" })
		end
	end
	solid(CF(229, (topY - 4) / 2, -171), V(40, topY - 4, 86), C.trim, { Name = "Drawers" })
	for i = 0, 2 do
		local y = 7 + i * 13
		prop(CF(229, y, -127.6), V(36, 11, 1), ({ C.pink, C.yellow, rgb(160, 210, 255) })[i + 1], { CanCollide = false })
		ball(V(229, y, -126.8), V(2.4, 2.4, 2.4), C.white, { CanCollide = false })
	end
	-- ruler ramp from the floor to the desk top
	local bottom, top = V(128, 0, -38), V(128, topY, -126)
	local len = (top - bottom).Magnitude
	local rcf = CFrame.lookAt((bottom + top) / 2, top) * CF(0, -0.8, 0)
	solid(rcf, V(14, 1.6, len + 2), rgb(255, 214, 80), { Name = "Ruler" })
	for i = 1, math.floor(len / 6) do
		local tick = rcf * CF(-5.2 + (i % 2) * 0.8, 0.82, len / 2 - i * 6)
		prop(tick, V((i % 2 == 0) and 3.6 or 2, 0.06, 0.5), C.ink, { CanCollide = false })
	end
	prop(rcf * CF(0, 0.85, 0), V(0.4, 0.06, len), rgb(240, 190, 60), { CanCollide = false })
	-- chair
	local seatY = 24
	solid(CF(198, seatY - 2, -100), V(44, 4, 40), C.red, { Name = "Seat" })
	for _, x in ipairs({ 180, 216 }) do
		for _, zz in ipairs({ -116, -84 }) do
			World.cyl(folder, V(x, 0, zz), seatY - 4, 3.5, C.trim, { CanTouch = false })
		end
	end
	solid(CF(198, seatY + 17, -81), V(44, 34, 4), C.red, { Name = "ChairBack" })
	rod(V(178, seatY + 34, -81), V(218, seatY + 34, -81), 5, C.red)
	-- lamp
	cyl(V(238, topY, -206), 2, 16, C.red)
	rod(V(238, topY + 2, -206), V(232, topY + 30, -196), 2, C.trim)
	rod(V(232, topY + 30, -196), V(210, topY + 40, -186), 2, C.trim)
	ball(V(232, topY + 30, -196), V(3.5, 3.5, 3.5), C.red)
	ball(V(206, topY + 38, -182), V(17, 12, 17), C.red)
	local bulb = ball(V(206, topY + 33, -182), V(7, 7, 7), rgb(255, 246, 210), { Material = Enum.Material.Neon, CanCollide = false })
	local light = Instance.new("PointLight")
	light.Range = 44
	light.Brightness = 1.6
	light.Color = rgb(255, 228, 180)
	light.Parent = bulb
	-- pencil cup
	cyl(V(118, topY, -208), 14, 11, C.blue)
	for i, col in ipairs({ C.red, C.yellow, C.lime, C.purple }) do
		local a = RAD(i * 90)
		local p0 = V(118 + math.cos(a) * 2, topY + 4, -208 + math.sin(a) * 2)
		local p1 = p0 + V(math.cos(a) * 5, 24, math.sin(a) * 5)
		rod(p0, p1, 1.8, col)
		ball(p1, V(1.9, 1.9, 1.9), C.pink)
	end
	-- books, globe, notebook
	for i, col in ipairs({ C.purple, C.orange, C.teal }) do
		prop(CF(125, topY + 2 + (i - 1) * 4, -148) * ANG(0, RAD(i * 9), 0), V(22, 4, 16), col)
	end
	cyl(V(238, topY, -150), 2, 12, C.woodDark)
	rod(V(238, topY + 2, -150), V(238, topY + 12, -150), 1.4, C.woodDark)
	ball(V(238, topY + 20, -150), V(17, 17, 17), rgb(80, 160, 240))
	ball(V(233, topY + 23, -154), V(9, 8, 5), C.lime, { CanCollide = false })
	ball(V(242, topY + 16, -146), V(8, 7, 6), C.lime, { CanCollide = false })
	prop(CF(150, topY + 0.3, -200) * ANG(0, RAD(-8), 0), V(30, 0.6, 22), C.white)
	prop(CF(150, topY + 0.65, -200) * ANG(0, RAD(-8), 0), V(1, 0.1, 22), C.red, { CanCollide = false })
	-- waste basket with paper balls
	cyl(V(92, 0, -204), 22, 18, rgb(160, 210, 255))
	for i = 1, 3 do
		ball(V(92 + (i - 2) * 4, 23, -204 + (i % 2) * 3), V(5, 5, 5), C.white)
	end
	ball(V(104, 2.5, -190), V(5, 5, 5), C.white)
end

-- Toy chest under the window (zone "chest") and spilled toys ------------------------------------------------

local function chest()
	local red, trim = rgb(222, 76, 64), C.yellow
	solid(CF(0, 1.5, -196), V(96, 3, 40), red, { Name = "Chest" })
	solid(CF(0, 20, -178), V(96, 40, 4), red, { Name = "Chest" })
	solid(CF(0, 20, -214), V(96, 40, 4), red, { Name = "Chest" })
	solid(CF(-46, 20, -196), V(4, 40, 40), red, { Name = "Chest" })
	solid(CF(46, 20, -196), V(4, 40, 40), red, { Name = "Chest" })
	prop(CF(0, 41, -178), V(100, 3, 5), trim)
	prop(CF(0, 41, -214), V(100, 3, 5), trim)
	prop(CF(-46, 41, -196), V(5, 3, 40), trim)
	prop(CF(46, 41, -196), V(5, 3, 40), trim)
	for _, x in ipairs({ -47, 47 }) do
		prop(CF(x, 20, -177.5), V(4, 40, 4.4), trim)
	end
	local front = prop(CF(0, 20, -175.8), V(70, 26, 0.4), trim, { CanCollide = false })
	faceText(front, Enum.NormalId.Back, "★ ★ ★", C.white, nil, rgb(240, 120, 60))
	local lid = solid(CF(0, 61, -216.5) * ANG(RAD(-6), 0, 0), V(96, 42, 4), red, { Name = "Lid" })
	local plate = prop(lid.CFrame * CF(0, 0, 2.2), V(84, 30, 0.4), trim, { CanCollide = false })
	faceText(plate, Enum.NormalId.Back, "TOYS", C.white, nil, rgb(240, 120, 60))
	-- toys peeking out of the chest
	ball(V(-24, 40, -196), V(22, 22, 22), C.blue)
	ball(V(-24, 40, -196), V(22.3, 6, 22.3), C.white, { CanCollide = false })
	cyl(V(18, 20, -200), 34, 8, C.white)
	ball(V(18, 54, -200), V(8, 9, 8), C.red)
	Toys.tri(decor, CF(18, 26, -200) * ANG(0, RAD(90), 0), 18, 10, 1, C.red, { CanCollide = false, CastShadow = false, CanQuery = false })
	rod(V(34, 30, -192), V(40, 52, -204), 5, C.lime)
	-- spilled toys: rubber duck, toy car, blocks, a ball
	local duck = V(-46, 0, -150)
	ball(duck + V(0, 6, 0), V(13, 11, 16), C.yellow)
	ball(duck + V(0, 13.5, -5), V(9, 9, 9), C.yellow)
	ball(duck + V(0, 13, -10), V(5, 2.4, 4), C.orange)
	ball(duck + V(-2.6, 15, -9), V(1.4, 1.6, 1), C.ink)
	ball(duck + V(2.6, 15, -9), V(1.4, 1.6, 1), C.ink)
	local car = CF(52, 0, -112) * ANG(0, RAD(30), 0)
	prop(car * CF(0, 4.5, 0), V(11, 5, 20), C.blue)
	prop(car * CF(0, 8.5, 2), V(9, 4, 9), rgb(190, 230, 255))
	for _, w in ipairs({ { -6, -6 }, { 6, -6 }, { -6, 6 }, { 6, 6 } }) do
		prop(car * CF(w[1], 2.5, w[2]), V(2.5, 5, 5), C.ink, { Shape = Enum.PartType.Cylinder })
	end
	ball(V(-64, 9, -100), V(18, 18, 18), C.orange)
	ball(V(-64, 9, -100), V(18.2, 18.2, 3), C.white, { CanCollide = false })
end

-- Rug (centre; zone "rug") -------------------------------------------------------------------------------------

local function rug()
	local c = V(0, 0, 6)
	local outer = World.disc(folder, c.X, c.Z, 86, 0.5, 0.5, C.rugOuter)
	World.texture(outer, "ToyRugCarpet", C.rugOuter)
	local ring = World.disc(folder, c.X, c.Z, 78, 0.54, 0.5, C.rugRing)
	World.texture(ring, "ToyRugCarpet", C.rugRing)
	local inner = World.disc(folder, c.X, c.Z, 72, 0.58, 0.5, C.rugInner)
	World.texture(inner, "ToyRugCarpet", C.rugInner)
	World.disc(folder, c.X, c.Z, 20, 0.62, 0.5, C.rugCenter)
	for _, p in ipairs({ outer, ring, inner }) do
		p.CanTouch = false
		p.CastShadow = false
	end
	-- sun rays on the centre (a big friendly sun the flag stands on)
	for i = 0, 7 do
		local a = RAD(i * 45 + 22.5)
		local p = c + V(math.cos(a) * 27, 0.66, math.sin(a) * 27)
		Toys.tri(decor, CFrame.lookAt(p, c + V(0, 0.66, 0)) * ANG(RAD(90), 0, 0), 9, 12, 0.12, C.rugCenter, { CanCollide = false, CastShadow = false, CanQuery = false, CanTouch = false })
	end
	-- fringe
	for i = 0, 39 do
		local a = i / 40 * math.pi * 2
		local p = c + V(math.cos(a) * 88, 0.2, math.sin(a) * 88)
		prop(CFrame.lookAt(p, c + V(0, 0.2, 0)), V(1.2, 0.4, 5), C.white, { CanCollide = false })
	end
	-- crayons and marbles at the rug's edge (clusters, not scatter)
	local crayons = { C.red, C.blue, C.yellow, C.lime, C.purple }
	for i, col in ipairs(crayons) do
		local base = V(66 + i * 4, 1.6, -44 + (i % 2) * 5)
		local dir = V(math.cos(i * 0.9), 0, math.sin(i * 0.9))
		rod(base, base + dir * 16, 3.2, col)
		ball(base + dir * 16.6, V(2.4, 2.4, 2.4), col)
	end
	for i = 1, 7 do
		local p = V(-70 + rng:NextNumber(-8, 8), 2, -58 + rng:NextNumber(-8, 8))
		ball(p, V(4, 4, 4), Color3.fromHSV(i / 7, 0.4, 1), { Material = Enum.Material.Glass, Transparency = 0.35, CanCollide = false })
		ball(p, V(2, 2, 2), Color3.fromHSV(i / 7, 0.8, 1), { Material = Enum.Material.Neon, CanCollide = false })
	end
end

-- Block tower base (the tower itself is client-side so it can topple), door, title banner ------------------------

local function southWall()
	-- door
	prop(CF(0, 56, D - 1.4), V(62, 112, 2), C.white)
	prop(CF(0, 56, D - 1.8), V(68, 116, 1.2), C.trim)
	for _, y in ipairs({ 30, 82 }) do
		prop(CF(0, y, D - 2.6), V(46, 36, 0.4), rgb(240, 240, 236), { CanCollide = false })
	end
	ball(V(22, 54, D - 3.2), V(4, 4, 4), C.gold)
	-- title banner above the door: the landmark text
	World.sign(decor, CF(0, 136, D - 3) * ANG(0, RAD(180), 0), Vector2.new(110, 20), "⚔️ TOY ARMY HQ ⚔️", C.yellow, C.ink)
	-- bunting: green pennants over the green bases, tan over the tan bases
	for _, side in ipairs({ -1, 1 }) do
		local col = side < 0 and C.green or C.tan
		local x0, x1 = side * 40, side * 252
		rod(V(x0, 104, D - 3), V(x1, 104, D - 3), 0.5, C.ink)
		for i = 0, 10 do
			local x = x0 + (x1 - x0) * (i + 0.5) / 11
			Toys.tri(decor, CF(x, 99, D - 3.2) * ANG(0, 0, RAD(180)), 12, 10, 0.4, i % 2 == 0 and col or C.white, { CanCollide = false, CastShadow = false, CanQuery = false })
		end
	end
	-- loose letter blocks around the tower zone, dominoes, a basketball
	local letters = { "A", "B", "C", "1", "2", "★" }
	local cols = { C.red, C.blue, C.yellow, C.lime, C.purple, C.orange }
	local spots = { V(-46, 0, 156), V(-38, 0, 168), V(44, 0, 160), V(52, 0, 148), V(-46, 8, 156), V(40, 0, 174) }
	for i, p in ipairs(spots) do
		local b = prop(CF(p + V(0, 4, 0)) * ANG(0, RAD(i * 23), 0), V(8, 8, 8), cols[i])
		faceText(b, Enum.NormalId.Front, letters[i], C.white)
		faceText(b, Enum.NormalId.Top, letters[i], C.white)
	end
	for i = 0, 7 do
		prop(CF(40 + i * 5, 4, 100 - i * 2.6) * ANG(0, RAD(30), 0), V(1.6, 8, 4), C.white)
	end
	ball(V(-80, 7, 120), V(14, 14, 14), C.orange)
	prop(CF(-80, 7, 120), V(14.2, 0.5, 14.2), C.ink, { Shape = Enum.PartType.Ball, CanCollide = false })
end

-- Side walls: dresser (west), bookshelf (east), posters, clock ---------------------------------------------

local function sideWalls()
	-- dresser on the west wall with a toy rocket and a piggy bank on top
	solid(CF(-242, 32, 108), V(32, 64, 76), C.trim, { Name = "Dresser" })
	for i, col in ipairs({ rgb(160, 210, 255), C.pink, C.yellow }) do
		local y = 10 + (i - 1) * 20
		prop(CF(-225.6, y, 108), V(1, 17, 70), col, { CanCollide = false })
		ball(V(-224.8, y, 108), V(2.6, 2.6, 2.6), C.white, { CanCollide = false })
	end
	cyl(V(-242, 64, 90), 28, 8, C.white)
	ball(V(-242, 94, 90), V(8, 9, 8), C.red)
	for i = 0, 2 do
		local a = RAD(i * 120)
		Toys.tri(decor, CF(-242 + math.cos(a) * 5, 70, 90 + math.sin(a) * 5) * ANG(0, -a + RAD(90), 0), 6, 9, 0.8, C.red, { CanCollide = false, CastShadow = false, CanQuery = false })
	end
	ball(V(-242, 71, 126), V(14, 11, 16), C.pink)
	prop(CF(-242, 71, 117.6) * ANG(0, RAD(90), 0), V(2, 4, 4), rgb(255, 120, 150), { Shape = Enum.PartType.Cylinder })
	ball(V(-246, 77, 121), V(3, 4, 2), C.pink)
	ball(V(-238, 77, 121), V(3, 4, 2), C.pink)

	-- bookshelf on the east wall
	local sx, sz = 243, 10
	solid(CF(sx, 60, sz), V(30, 120, 100), C.trim, { Name = "Shelf" })
	local cols = { C.red, C.blue, C.yellow, C.lime, C.purple, C.orange, C.teal, C.pink }
	for s = 0, 3 do
		local y = 6 + s * 30
		prop(CF(sx - 17, y - 1, sz), V(6, 2, 100), C.trim)
		prop(CF(sx - 15.4, y + 13, sz), V(0.6, 26, 96), rgb(236, 230, 220), { CanCollide = false })
		local z = sz - 44
		local i = s
		while z < sz + 40 do
			local w = 3 + (i * 7 % 4)
			local h = 16 + (i * 5 % 9)
			i += 1
			prop(CF(sx - 16.5, y + h / 2, z + w / 2), V(4, h, w), cols[i % #cols + 1], { CanCollide = false })
			z += w + 0.4
			if i % 5 == 0 then
				z += 6
			end
		end
	end
	-- posters (emoji art on plain boards, no images)
	local function poster(cf: CFrame, w: number, h: number, art: string, caption: string, bg: Color3)
		local board = prop(cf, V(w, h, 0.6), C.trim, { CanCollide = false })
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 12
		sg.LightInfluence = 0.4
		local f = Instance.new("Frame")
		f.Size = UDim2.new(1, -16, 1, -16)
		f.Position = UDim2.fromOffset(8, 8)
		f.BackgroundColor3 = bg
		f.Parent = sg
		local a = Instance.new("TextLabel")
		a.BackgroundTransparency = 1
		a.Size = UDim2.fromScale(1, 0.72)
		a.TextScaled = true
		a.Font = Enum.Font.GothamBold
		a.Text = art
		a.Parent = f
		local c = Instance.new("TextLabel")
		c.BackgroundTransparency = 1
		c.Size = UDim2.fromScale(1, 0.26)
		c.Position = UDim2.fromScale(0, 0.72)
		c.TextScaled = true
		c.Font = Enum.Font.LuckiestGuy
		c.Text = caption
		c.TextColor3 = C.white
		local st = Instance.new("UIStroke")
		st.Thickness = 3
		st.Color = C.ink
		st.Parent = c
		c.Parent = f
		sg.Parent = board
	end
	poster(CF(-W + 0.5, 112, 30) * ANG(0, RAD(-90), 0), 36, 46, "🦖", "RAWR!", rgb(140, 210, 140))
	poster(CF(W - 0.5, 118, 120) * ANG(0, RAD(90), 0), 36, 46, "🚀", "TO THE MOON", rgb(70, 90, 170))
	poster(CF(-140, 112, -D + 0.5) * ANG(0, RAD(180), 0), 40, 30, "⚽", "GOAL!", rgb(255, 180, 90))
	poster(CF(W - 0.5, 118, -60) * ANG(0, RAD(90), 0), 30, 38, "🌈", "BE BRAVE", rgb(150, 200, 255))
	-- wall clock right of the window
	local clock = prop(CF(118, 112, -D + 0.6) * ANG(0, RAD(90), 0), V(1.2, 26, 26), C.trim, { Shape = Enum.PartType.Cylinder, CanCollide = false })
	clock.Name = "Clock"
	prop(CF(118, 112, -D + 1.1) * ANG(0, RAD(90), 0), V(0.4, 22, 22), C.white, { Shape = Enum.PartType.Cylinder, CanCollide = false })
	prop(CF(118, 115, -D + 1.4), V(1, 7, 0.3), C.ink, { CanCollide = false })
	prop(CF(120.5, 112, -D + 1.4), V(5, 1, 0.3), C.ink, { CanCollide = false })
end

-- Lego bricks and blocks between the rug and the side zones (paths are never empty) ----------------------------

local function scatter()
	local function brick(cf: CFrame, col: Color3, w: number, l: number)
		local b = prop(cf * CF(0, 2.4, 0), V(w * 3.2, 4.8, l * 3.2), col)
		for i = 0, w - 1 do
			for j = 0, l - 1 do
				prop(b.CFrame * CF((i - (w - 1) / 2) * 3.2, 2.9, (j - (l - 1) / 2) * 3.2) * ANG(0, 0, RAD(90)), V(1, 2, 2), col, { Shape = Enum.PartType.Cylinder, CanCollide = false })
			end
		end
	end
	brick(CF(-104, 0, -18) * ANG(0, RAD(20), 0), C.red, 2, 4)
	brick(CF(-112, 4.8, -14) * ANG(0, RAD(-30), 0), C.yellow, 2, 2)
	brick(CF(-96, 0, -4) * ANG(0, RAD(70), 0), C.blue, 2, 3)
	brick(CF(98, 0, 30) * ANG(0, RAD(-15), 0), C.lime, 2, 4)
	brick(CF(104, 4.8, 26) * ANG(0, RAD(40), 0), C.purple, 2, 2)
	brick(CF(-92, 0, 150) * ANG(0, RAD(10), 0), C.orange, 2, 3)
	brick(CF(92, 0, 152) * ANG(0, RAD(-25), 0), C.teal, 2, 3)
	-- spinning top and a paper airplane on the tan side, a xylophone near the chest
	cyl(V(92, 0, -36), 2, 3, C.red)
	ball(V(92, 6, -36), V(12, 8, 12), C.yellow)
	cyl(V(92, 9, -36), 5, 2, C.red)
	local plane = CF(20, 1, 80) * ANG(0, RAD(30), 0)
	Toys.tri(decor, plane * ANG(RAD(-90), 0, 0), 16, 18, 0.3, C.white, { CanCollide = false, CastShadow = false, CanQuery = false })
	prop(plane * CF(0, 1.2, 1), V(0.4, 2.4, 14), C.white, { CanCollide = false })
	local xy = CF(-74, 0, -168) * ANG(0, RAD(-20), 0)
	prop(xy * CF(0, 1.5, 0), V(30, 3, 14), C.woodDark)
	for i = 0, 6 do
		prop(xy * CF(-12 + i * 4, 3.4, 0), V(3, 1, 12 - i), Color3.fromHSV(i / 7, 0.65, 1), { CanCollide = false })
	end
end

function Room.build(): Folder
	folder = World.folder("Room")
	decor = World.folder("Decor", folder)
	shell()
	windowAndSun()
	bed()
	fort()
	desk()
	chest()
	rug()
	southWall()
	sideWalls()
	scatter()
	return folder
end

return Room

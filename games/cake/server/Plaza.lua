-- Builds the bakery-street plaza: checkered plaza, the cake stage with turntable/judges/podium/landmark arch,
-- 12 bakery stations in a ring, lamps + bunting, giant cupcakes, pastel shopfronts and the spawn.
-- Everything is anchored palette primitives; big flat surfaces get our MaterialVariants when generated.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared:WaitForChild("World"))
local Config = require(Shared:WaitForChild("Config"))
local CakeBuilder = require(Shared:WaitForChild("CakeBuilder"))
local Look = require(script.Parent:WaitForChild("Look"))

local Plaza = {}

export type StationInfo = {
	index: number,
	model: Model,
	cf: CFrame,
	root: CFrame,
	pad: Vector3,
	sign: TextLabel,
	oven: { BasePart },
	plate: BasePart,
	padGlow: BasePart,
	color: Color3,
}
export type Built = {
	stations: { StationInfo },
	stage: Folder,
	turntable: BasePart,
	judges: Folder,
	glow: { BasePart },
	spots: { SpotLight },
	podium: { BasePart },
}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local RAD = math.rad
local C = Color3.fromRGB
local P = Config.Palette
local W = Config.World

local function deco(p: BasePart): BasePart
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

-- Apply one of our MaterialVariants when it exists (part goes white so the texture shows true);
-- otherwise the part keeps its flat palette colour.
local function tex(p: BasePart, variant: string): BasePart
	if World.hasVariant(variant) then
		World.texture(p, variant)
	end
	return p
end

local function box(parent: Instance, cf: CFrame, size: Vector3, color: Color3, props: { [string]: any }?): BasePart
	return World.box(parent, cf, size, color, props)
end

local function surfaceText(part: BasePart, face: Enum.NormalId, text: string, color: Color3, pps: number?, font: Enum.Font?): TextLabel
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = pps or 30
	sg.LightInfluence = 0
	sg.MaxDistance = 400
	local l = Instance.new("TextLabel")
	l.Name = "Text"
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(0.92, 0.82)
	l.Position = UDim2.fromScale(0.04, 0.09)
	l.Font = font or Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	local s = Instance.new("UIStroke")
	s.Thickness = 4
	s.Color = P.ink
	s.Parent = l
	l.Parent = sg
	sg.Parent = part
	return l
end

-- Ground, plaza floor, carpet -------------------------------------------------------------------------
local function buildGround(f: Folder)
	-- soft mint lawn out to the horizon, cream paving street inside it
	local lawn = tex(World.part({ Name = "Lawn", Size = V(340, 1, 340), CFrame = CF(0, -0.5, 0), Color = C(176, 224, 166), Parent = f }), "HouseGrass")
	lawn.CanTouch = false
	local base = tex(World.disc(f, 0, 0, 104, 0.06, 0.6, P.creamDark), "CakeStreet")
	base.Name = "Street"
	base.CanTouch = false
	-- pink frosting rim around the checkered plaza
	World.disc(f, 0, 0, W.plazaR + 2, 0.14, 0.6, P.pink)
	local plaza = World.disc(f, 0, 0, W.plazaR, 0.2, 0.6, P.tileA)
	plaza.Name = "PlazaFloor"
	if World.hasVariant("CakeTile") then
		World.texture(plaza, "CakeTile")
	else
		-- flat fallback: soft cream/pink checkerboard from 10-stud tiles
		local tiles = World.folder("Tiles", f)
		local cell = 10
		for ix = -8, 7 do
			for iz = -8, 7 do
				if (ix + iz) % 2 == 0 then
					local cx, cz = (ix + 0.5) * cell, (iz + 0.5) * cell
					if math.sqrt(cx * cx + cz * cz) + cell * 0.72 < W.plazaR then
						deco(box(tiles, CF(cx, 0.23, cz), V(cell, 0.06, cell), P.tileB, { Name = "Tile" }))
					end
				end
			end
		end
	end
	-- red-carpet path from the spawn to the stage
	local carpet = box(f, CF(0, 0.28, 44), V(8, 0.12, 56), C(255, 120, 165), { Name = "Carpet" })
	deco(carpet)
	for _, sx in ipairs({ 1, -1 }) do
		deco(box(f, CF(4.3 * sx, 0.29, 44), V(0.6, 0.14, 56), P.gold, { Name = "CarpetEdge" }))
	end
end

-- Spawn and entrance arch ----------------------------------------------------------------------------
local function buildSpawn(f: Folder)
	local sp = Instance.new("SpawnLocation")
	sp.Name = "Spawn"
	sp.Anchored = true
	sp.Size = V(10, 0.6, 10)
	sp.CFrame = CFrame.lookAt(W.spawn + V(0, -0.3, 0), V(0, W.spawn.Y - 0.3, 0))
	sp.Color = C(255, 150, 190)
	sp.Material = Enum.Material.SmoothPlastic
	sp.TopSurface = Enum.SurfaceType.Smooth
	sp.Duration = 0
	sp.Neutral = true
	sp.Parent = f
	World.pad(f, Vector3.new(W.spawn.X, 0, W.spawn.Z), 6.2, C(255, 230, 120)).CanQuery = false

	-- candy-cane arch framing the first view of the stage
	local z = 58
	for _, sx in ipairs({ 1, -1 }) do
		for k = 0, 6 do
			World.cyl(f, V(7 * sx, k * 2, z), 2, 1.6, if k % 2 == 0 then C(255, 90, 120) else C(255, 255, 255), { Name = "ArchPost" })
		end
		World.ball(f, V(7 * sx, 14.6, z), 2.4, P.gold, { Name = "ArchTop", Reflectance = 0.2 })
	end
	local sign = box(f, CFrame.lookAt(V(0, 15, z), V(0, 15, z - 10)), V(17, 3.6, 0.8), C(255, 255, 255), { Name = "WelcomeSign" })
	box(f, sign.CFrame, V(17.8, 4.4, 0.5), C(255, 120, 165), { Name = "WelcomeFrame" })
	surfaceText(sign, Enum.NormalId.Back, "WELCOME BAKERS!", C(255, 120, 165), 30)
	surfaceText(sign, Enum.NormalId.Front, "GOOD LUCK! 🎂", C(255, 120, 165), 30)
end

-- One bakery station --------------------------------------------------------------------------------
local function buildStation(parent: Folder, i: number): StationInfo
	local F = Config.stationCF(i)
	local m = World.model("Station" .. i, parent)
	local col = Config.StationColors[(i - 1) % #Config.StationColors + 1]
	local light = col:Lerp(C(255, 255, 255), 0.4)
	local function L(x: number, y: number, z: number): CFrame
		return F * CF(x, y, z)
	end

	tex(World.part({ Name = "Floor", Size = V(19, 0.5, 21), CFrame = L(0, 0.25, -0.5), Color = P.honey, Parent = m }), "CakeWood")
	box(m, L(0, 0.28, -11.1), V(19.2, 0.56, 0.6), col, { Name = "FloorTrim" })

	-- counter with cabinet doors and wood top
	box(m, L(0, 2.2, 7.5), V(18, 3.4, 3.5), col, { Name = "Counter" })
	tex(World.part({ Name = "CounterTop", Size = V(18.6, 0.4, 4.1), CFrame = L(0, 4.1, 7.5), Color = P.honey, Parent = m }), "CakeWood")
	for _, x in ipairs({ -6, 0, 6 }) do
		deco(box(m, L(x, 2.2, 5.72), V(5, 2.3, 0.14), light, { Name = "Door" }))
		deco(World.ball(m, L(x + 1.8, 2.4, 5.6).Position, 0.4, P.gold, { Name = "Knob" }))
	end

	-- back wall, shelves, jars and cake boxes
	box(m, L(0, 5.25, 9.7), V(18, 9.5, 0.8), P.cream, { Name = "BackWall" })
	for _, y in ipairs({ 6.6, 8.6 }) do
		deco(World.part({ Name = "Shelf", Size = V(16, 0.3, 1.2), CFrame = L(0, y, 9.0), Color = P.honey, Parent = m }))
	end
	local jarCols = { P.mint, P.pink, P.lemon, P.sky }
	for k, x in ipairs({ -5.5, -2, 1.5, 5 }) do
		deco(World.cyl(m, L(x, 6.75, 9.0).Position, 1.2, 0.95, jarCols[k], { Name = "Jar" }))
		deco(World.cyl(m, L(x, 7.95, 9.0).Position, 0.25, 1.05, C(255, 255, 255), { Name = "JarLid" }))
	end
	for k, x in ipairs({ -4, 0.5, 4.5 }) do
		deco(box(m, L(x, 9.3, 9.0), V(1.6, 1.1, 1.1), jarCols[(k + 1) % 4 + 1], { Name = "CakeBox" }))
	end

	-- striped awning with scalloped edge
	for k = 0, 5 do
		local x = -7.5 + k * 3
		local c = if k % 2 == 0 then col else C(255, 255, 255)
		deco(box(m, L(x, 9.6, 6.4) * ANG(RAD(-16.6), 0, 0), V(3.02, 0.25, 7), c, { Name = "Awning" }))
		deco(World.ball(m, L(x, 8.55, 3.05).Position, 1.6, c, { Name = "Scallop" }))
	end
	for _, sx in ipairs({ 1, -1 }) do
		deco(World.rod(m, L(8.8 * sx, 4.3, 3.4).Position, L(8.8 * sx, 8.6, 3.4).Position, 0.35, C(255, 255, 255), { Name = "AwningPost" }))
	end

	-- name sign
	local sign = box(m, L(0, 12.3, 10.1), V(11.5, 2.6, 0.6), C(255, 255, 255), { Name = "Sign" })
	box(m, L(0, 12.3, 10.25), V(12.1, 3.1, 0.4), col, { Name = "SignFrame" })
	local signText = surfaceText(sign, Enum.NormalId.Front, "OPEN STATION", C(255, 120, 165), 24)

	-- oven and mixing bowl on the counter
	local ovenBody = box(m, L(6, 5.8, 7.6), V(3.8, 3, 3.2), light, { Name = "Oven" })
	local ovenDoor = deco(box(m, L(6, 5.6, 5.95), V(2.8, 1.7, 0.12), C(70, 50, 60), { Name = "OvenDoor" }))
	local glow = deco(box(m, L(6, 5.6, 5.88), V(2.3, 1.2, 0.08), C(255, 150, 60), { Name = "OvenGlow", Material = Enum.Material.Neon }))
	local handle = deco(World.rod(m, L(4.9, 6.65, 5.8).Position, L(7.1, 6.65, 5.8).Position, 0.18, C(220, 220, 230), { Name = "OvenHandle" }))
	deco(World.ball(m, L(5.0, 7.0, 5.95).Position, 0.3, P.gold, { Name = "OvenKnob" }))
	deco(World.ball(m, L(7.0, 7.0, 5.95).Position, 0.3, P.gold, { Name = "OvenKnob" }))
	deco(World.cyl(m, L(-6, 4.3, 7.6).Position, 1.1, 2.4, P.sky, { Name = "Bowl" }))
	deco(World.ball(m, L(-6, 5.35, 7.6).Position, 1.7, P.cream, { Name = "Batter" }))
	deco(World.rod(m, L(-5.6, 5.4, 7.4).Position, L(-4.9, 6.9, 7.0).Position, 0.16, C(210, 210, 220), { Name = "Whisk" }))

	-- cake stand: the cake root sits on the plate top
	World.cyl(m, L(0, 0.5, 1).Position, 0.35, 4.6, P.cream, { Name = "StandBase" })
	World.cyl(m, L(0, 0.85, 1).Position, 2.9, 1.2, C(255, 255, 255), { Name = "StandStem" })
	local plate = World.cyl(m, L(0, 3.75, 1).Position, 0.35, 12.6, C(255, 255, 255), { Name = "Plate" })
	deco(World.cyl(m, L(0, 3.72, 1).Position, 0.22, 12.95, P.gold, { Name = "PlateRim", Reflectance = 0.2 }))

	local padPos = (F * CF(Config.Station.pad)).Position
	local padGlow = World.pad(m, padPos, 2.4, col)
	padGlow.CanQuery = false -- decorative glow over the solid pad disc
	return {
		index = i,
		model = m,
		cf = F,
		root = F * Config.Station.root,
		pad = padPos,
		sign = signText,
		oven = { ovenBody, ovenDoor, glow, handle },
		plate = plate,
		padGlow = padGlow,
		color = col,
	}
end

-- Little clusters between stations: lamp with a flower basket + topiary planter.
local function buildGapDecor(f: Folder, angleDeg: number, rng: Random)
	local a = RAD(angleDeg)
	local out = V(math.sin(a), 0, math.cos(a))
	local pos = out * W.stationR
	World.lamp(f, pos + out * 3, C(255, 255, 255), C(255, 236, 170))
	deco(World.ball(f, pos + out * 3 + V(0, 7.4, 0), 1.8, P.pink, { Name = "Basket" }))
	local pot = pos - out * 3
	World.cyl(f, pot, 1.6, 2.6, C(255, 196, 160), { Name = "Pot" })
	deco(World.cyl(f, pot + V(0, 1.6, 0), 0.3, 2.8, C(255, 255, 255), { Name = "PotRim" }))
	World.ball(f, pot + V(0, 3.2, 0), 3.2, C(110, 200, 120), { Name = "Topiary" })
	deco(World.ball(f, pot + V(0, 5.2, 0), 2.0, C(140, 220, 140), { Name = "Topiary" }))
	World.flowers(f, pot + V(0, 1.7, 0), C(80, 160, 80), { C(255, 150, 200), C(255, 255, 255), C(255, 220, 100) }, rng)
end

-- Giant cupcake statue (landmark clusters on the promenade).
local function buildGiantCupcake(f: Folder, pos: Vector3, col: Color3)
	local m = World.model("GiantCupcake", f)
	World.cyl(m, pos, 5, 9, col, { Name = "Wrapper" })
	for k = 0, 11 do
		local a = RAD(k * 30)
		deco(box(m, CF(pos + V(math.cos(a) * 4.45, 2.5, math.sin(a) * 4.45)) * ANG(0, RAD(90) - a, 0), V(0.6, 5, 0.3), col:Lerp(C(255, 255, 255), 0.45), { Name = "Ridge" }))
	end
	local frost = C(255, 240, 246)
	World.ball(m, pos + V(0, 6.6, 0), 9.6, frost, { Name = "Frosting" })
	World.ball(m, pos + V(0, 9.8, 0), 6.6, frost, { Name = "Frosting" })
	World.ball(m, pos + V(0, 12.2, 0), 3.8, frost, { Name = "Frosting" })
	World.ball(m, pos + V(0, 14.4, 0), 2.6, C(225, 32, 56), { Name = "Cherry", Reflectance = 0.2 })
	local cols = Config.Rainbow
	local rng = Random.new(math.floor(pos.X + pos.Z))
	for k = 1, 10 do
		local a = rng:NextNumber() * math.pi * 2
		local y = rng:NextNumber(6.5, 11)
		local r = if y < 9 then 4.6 else 3.2
		deco(World.part({ Name = "Sprinkle", Shape = Enum.PartType.Cylinder, Size = V(1.2, 0.35, 0.35), CFrame = CF(pos + V(math.cos(a) * r, y, math.sin(a) * r)) * ANG(0, rng:NextNumber() * 3, rng:NextNumber() * 3), Color = cols[k % #cols + 1], Parent = m }))
	end
end

-- Shopfront facade facing the plaza.
local SHOPS = { "Sugar Shack", "Muffin Top", "The Whisk", "Sprinkle Spot", "Donut Dream", "Choco Loco", "Berry Nice", "Tea & Tarts", "Pie Palace", "Fondant Fun", "Crumb Club", "Cocoa Corner", "Jelly Jar", "Macaron Moon", "Waffle Way", "Candy Cloud" }
local FACADE = { P.pink, P.mint, P.sky, P.lemon, P.lavender, P.peach }
local function buildFacade(f: Folder, k: number, angleDeg: number)
	local a = RAD(angleDeg)
	local pos = V(math.sin(a) * 92, 0, math.cos(a) * 92)
	local F = CFrame.lookAt(pos, V(0, 0, 0))
	local col = FACADE[(k - 1) % #FACADE + 1]
	local m = World.model("Shop" .. k, f)
	local function L(x: number, y: number, z: number): CFrame
		return F * CF(x, y, z)
	end
	World.part({ Name = "Facade", Size = V(26, 18, 6), CFrame = L(0, 9, 0), Color = col, Variant = "HousePanels", Parent = m })
	box(m, L(0, 1, -3.1), V(26.4, 2, 0.5), C(255, 255, 255), { Name = "Trim" })
	deco(box(m, L(-6.5, 3.6, -3.05), V(4, 7, 0.3), P.choc, { Name = "Door" }))
	deco(World.ball(m, L(-5.1, 3.6, -3.3).Position, 0.45, P.gold, { Name = "DoorKnob" }))
	deco(box(m, L(4, 5, -3.05), V(10.4, 5.8, 0.3), C(255, 255, 255), { Name = "WindowFrame" }))
	deco(box(m, L(4, 5, -3.15), V(9.4, 4.8, 0.2), C(190, 230, 255), { Name = "Window", Reflectance = 0.25 }))
	-- a cake in the window display
	deco(World.cyl(m, L(4, 2.3, -3.7).Position, 1.2, 2.6, C(255, 255, 255), { Name = "DisplayCake" }))
	deco(World.cyl(m, L(4, 3.5, -3.7).Position, 1.0, 1.8, P.pink, { Name = "DisplayCake" }))
	deco(World.ball(m, L(4, 4.8, -3.7).Position, 0.6, C(225, 32, 56), { Name = "DisplayCherry" }))
	for j = 0, 4 do
		local c = if j % 2 == 0 then col:Lerp(C(0, 0, 0), 0.08) else C(255, 255, 255)
		deco(box(m, L(-10.4 + j * 5.2, 9.3, -4.7) * ANG(RAD(-20), 0, 0), V(5.2, 0.25, 3.6), c, { Name = "Awning" }))
	end
	local sign = box(m, L(0, 13.6, -3.2), V(16, 3, 0.4), C(255, 255, 255), { Name = "ShopSign" })
	surfaceText(sign, Enum.NormalId.Front, SHOPS[(k - 1) % #SHOPS + 1], C(255, 120, 165), 20)
	box(m, L(0, 18.4, 0), V(27, 0.8, 7), C(255, 255, 255), { Name = "Cornice" })
	for j = 0, 5 do
		deco(World.ball(m, L(-11 + j * 4.4, 18.9, -3.0).Position, 2.4, C(255, 255, 255), { Name = "Frosting" }))
	end
	deco(box(m, L(4, 1.9, -3.7), V(10, 0.8, 1), P.choc, { Name = "FlowerBox" }))
	for j, x in ipairs({ 0.2, 1.6, 6.4, 7.8 }) do
		deco(World.ball(m, L(x, 2.6, -3.7).Position, 1.1, if j % 2 == 0 then C(255, 150, 200) else C(255, 230, 120), { Name = "Bloom" }))
	end
end

-- Candy park behind the shops: cotton-candy trees and giant lollipops fill every gap and the horizon.
local CANDY_LEAVES: { World.Leaves } = {
	{ trunk = C(255, 250, 240), leaf1 = C(255, 182, 210), leaf2 = C(255, 204, 226), leaf3 = C(255, 228, 240) },
	{ trunk = C(255, 250, 240), leaf1 = C(196, 176, 245), leaf2 = C(214, 198, 250), leaf3 = C(236, 226, 255) },
	{ trunk = C(255, 250, 240), leaf1 = C(150, 218, 196), leaf2 = C(178, 232, 212), leaf3 = C(214, 244, 232) },
	{ trunk = C(255, 250, 240), leaf1 = C(160, 210, 245), leaf2 = C(188, 224, 250), leaf3 = C(222, 240, 255) },
}
local function lollipop(f: Instance, pos: Vector3, h: number, col: Color3)
	local m = World.model("Lollipop", f)
	World.rod(m, pos, pos + V(0, h, 0), 0.9, C(255, 255, 255), { Name = "Stick" })
	local top = pos + V(0, h + 3.2, 0)
	local face = CFrame.lookAt(top, V(0, top.Y, 0)) * ANG(0, RAD(90), 0) -- cylinder axis (X) faces the plaza
	World.part({ Name = "Candy", Shape = Enum.PartType.Cylinder, Size = V(1.4, 7.4, 7.4), CFrame = face, Color = col, Parent = m })
	deco(World.part({ Name = "Swirl", Shape = Enum.PartType.Cylinder, Size = V(1.6, 4.8, 4.8), CFrame = face, Color = C(255, 255, 255), Parent = m }))
	deco(World.part({ Name = "Swirl", Shape = Enum.PartType.Cylinder, Size = V(1.8, 2.4, 2.4), CFrame = face, Color = col, Parent = m }))
end

local function buildOutskirts(f: Folder, rng: Random)
	local park = World.folder("CandyPark", f)
	local pops = { P.pink, P.mint, P.sky, P.lemon, P.lavender, C(255, 120, 165) }
	-- one landmark behind every gap between shopfronts
	for k = 0, 15 do
		local a = RAD(k * 22.5)
		local out = V(math.sin(a), 0, math.cos(a))
		if k % 2 == 0 then
			World.tree(park, out * 101, rng:NextNumber(1.25, 1.5), CANDY_LEAVES[(k // 2) % #CANDY_LEAVES + 1])
		else
			lollipop(park, out * 100, rng:NextNumber(9, 12), pops[(k // 2) % #pops + 1])
		end
	end
	-- loose rings of trees, lollipops and giant gumdrops out to the horizon
	for ring = 0, 2 do
		local r0 = 116 + ring * 18
		local n = 18 + ring * 4
		for k = 1, n do
			local a = RAD((k + rng:NextNumber(-0.3, 0.3) + ring * 0.5) * 360 / n)
			local r = r0 + rng:NextNumber(-5, 5)
			local pos = V(math.sin(a) * r, 0, math.cos(a) * r)
			local pick = rng:NextInteger(1, 6)
			if pick <= 3 then
				World.tree(park, pos, rng:NextNumber(1.3, 1.9), CANDY_LEAVES[rng:NextInteger(1, #CANDY_LEAVES)])
			elseif pick <= 5 then
				lollipop(park, pos, rng:NextNumber(10, 16), pops[rng:NextInteger(1, #pops)])
			else
				local g = pops[rng:NextInteger(1, #pops)]
				deco(World.ball(park, pos + V(0, 2.2, 0), 7, g, { Name = "Gumdrop" }))
				deco(World.cyl(park, pos + V(0, 0.4, 0), 1.6, 7.6, g:Lerp(C(255, 255, 255), 0.25), { Name = "Gumdrop" }))
			end
		end
	end
end

-- Lamps around the promenade with bunting between them.
local function buildBunting(f: Folder)
	local n = 16
	local r = 68
	local tops: { Vector3 } = {}
	for k = 0, n - 1 do
		local a = RAD((k + 0.5) * 360 / n)
		local pos = V(math.sin(a) * r, 0, math.cos(a) * r)
		World.lamp(f, pos, C(255, 255, 255), C(255, 236, 170))
		table.insert(tops, pos + V(0, 9, 0))
	end
	local flagCols = { P.pink, P.mint, P.sky, P.lemon, P.lavender }
	for k = 1, n do
		local a, b = tops[k], tops[k % n + 1]
		local sag = V(0, -1.6, 0)
		local mid = (a + b) / 2 + sag
		deco(World.rod(f, a, mid, 0.12, C(255, 255, 255), { Name = "Rope" }))
		deco(World.rod(f, mid, b, 0.12, C(255, 255, 255), { Name = "Rope" }))
		for j = 1, 7 do
			local t = j / 8
			local p = if t < 0.5 then a:Lerp(mid, t * 2) else mid:Lerp(b, (t - 0.5) * 2)
			local dir = (b - a).Unit
			local fl = Instance.new("WedgePart")
			fl.Name = "Flag"
			fl.Anchored = true
			fl.CanCollide = false
			fl.Material = Enum.Material.SmoothPlastic
			fl.Size = V(0.1, 1.4, 1.1)
			-- point down: slope faces down/outward, flat side up against the rope
			fl.CFrame = CFrame.fromMatrix(p - V(0, 0.75, 0), Vector3.yAxis:Cross(dir), -Vector3.yAxis)
			fl.Color = flagCols[(j + k) % #flagCols + 1]
			fl.Parent = f
			deco(fl)
		end
	end
end

-- Stage: a giant frosted cake with drips, turntable, judges' table, podium and the landmark arch ------------
local function buildStage(f: Folder): (BasePart, Folder, { BasePart }, { SpotLight }, { BasePart })
	local pink = C(255, 182, 203)
	local R = W.stageR
	World.cyl(f, V(0, 0, 0), 2.7, R * 2, pink, { Name = "StageBody" })
	World.cyl(f, V(0, 2.6, 0), 0.45, R * 2 + 0.4, P.cream, { Name = "StageTop" })
	local glowRing = World.cyl(f, V(0, 1.9, 0), 0.3, R * 2 + 0.25, C(255, 120, 190), { Name = "StageGlow", Material = Enum.Material.Neon, CanCollide = false })
	deco(glowRing)
	local glows = { glowRing }
	-- chocolate drips and piping around the stage cake
	local rng = Random.new(5)
	for k = 0, 25 do
		local a = RAD(k * 360 / 26 + 4)
		local len = rng:NextNumber(0.8, 1.7)
		local p = V(math.cos(a) * (R + 0.15), 0, math.sin(a) * (R + 0.15))
		deco(World.part({ Name = "Drip", Shape = Enum.PartType.Cylinder, Size = V(len, 1.0, 1.0), CFrame = CF(p + V(0, 2.75 - len / 2, 0)) * ANG(0, 0, RAD(90)), Color = P.choc, Reflectance = 0.1, CanCollide = false, Parent = f }))
		deco(World.ball(f, p + V(0, 2.75 - len, 0), 1.1, P.choc, { Name = "DripEnd", CanCollide = false }))
	end
	for k = 0, 49 do
		local a = RAD(k * 360 / 50)
		deco(World.ball(f, V(math.cos(a) * R, 3.05, math.sin(a) * R), 1.3, C(255, 255, 255), { Name = "Piping", CanCollide = false }))
	end
	-- ramps on four sides
	for k = 0, 3 do
		local a = RAD(k * 90)
		local out = V(math.sin(a), 0, math.cos(a))
		local c = out * (R + 3.2) + V(0, 1.5, 0)
		local w = Instance.new("WedgePart")
		w.Name = "Ramp"
		w.Anchored = true
		w.Material = Enum.Material.SmoothPlastic
		w.Size = V(7, 3.05, 7)
		w.CFrame = CFrame.lookAt(c, c + out)
		w.Color = P.cream
		w.Parent = f
	end

	-- turntable
	World.cyl(f, V(0, 3.05, 0), 0.4, 11.8, P.gold, { Name = "TurntableRim", Reflectance = 0.2 })
	local tt = World.cyl(f, V(0, 3.35, 0), 0.4, 11, C(255, 255, 255), { Name = "Turntable" })
	-- stripes on the turntable so its spin reads
	for k = 0, 3 do
		local s = deco(box(f, CF(0, 3.76, 0) * ANG(0, RAD(k * 45), 0), V(10.6, 0.04, 0.5), C(255, 200, 220), { Name = "TurntableStripe" }))
		s:SetAttribute("Spin", true)
	end
	tt:SetAttribute("Spin", true)

	-- judges' table (faces the turntable, -X)
	local jx = W.judgeX
	box(f, CF(jx - 0.4, 4.4, 0), V(3.4, 2.7, 15), C(255, 230, 240), { Name = "TableCloth" })
	box(f, CF(jx - 0.4, 5.95, 0), V(3.8, 0.35, 15.4), C(255, 255, 255), { Name = "TableTop" })
	for k = -3, 3 do
		deco(World.ball(f, V(jx - 2.2, 3.4, k * 2.1), 1.0, C(255, 150, 190), { Name = "Scallop" }))
	end
	local plaque = box(f, CFrame.lookAt(V(jx - 2.35, 4.7, 0), V(0, 4.7, 0)), V(5, 1.3, 0.15), P.gold, { Name = "Plaque", Reflectance = 0.2 })
	surfaceText(plaque, Enum.NormalId.Front, "JUDGES", C(255, 255, 255), 40)
	local judges = World.folder("Judges", f)
	local seats = { W.judgeZ[1], W.judgeZ[2], W.celebZ, W.judgeZ[3] }
	for k, z in ipairs(seats) do
		local chairCol = if k == 3 then P.gold else P.lavender
		box(f, CF(jx + 2.6, 4.9, z), V(2, 0.4, 2), chairCol, { Name = "Seat" })
		box(f, CF(jx + 3.5, 6.6, z), V(0.4, 3.6, 2.2), chairCol, { Name = "ChairBack", Reflectance = if k == 3 then 0.25 else 0 })
	end

	-- podium behind the turntable
	local podium = {}
	local podCols = { C(255, 215, 90), C(215, 222, 235), C(225, 160, 110) }
	for k, top in ipairs(W.podium) do
		local h = top.Y - W.stageTop
		local b = box(f, CF(top.X, W.stageTop + h / 2, top.Z), V(5.5, h, 5), podCols[k], { Name = "Podium" .. k, Reflectance = 0.1 })
		surfaceText(b, Enum.NormalId.Back, tostring(k), C(255, 255, 255), 30)
		table.insert(podium, b)
	end

	-- landmark arch: two cake pillars, the CAKE OFF! sign and a giant cake on top
	local az = -15
	for _, sx in ipairs({ 1, -1 }) do
		local x = 12.5 * sx
		local y = W.stageTop
		local cols = { P.pink, P.mint, P.sky }
		for t, r in ipairs({ 3.0, 2.6, 2.2 }) do
			World.cyl(f, V(x, y, az), 5, r * 2, cols[t], { Name = "Pillar" })
			deco(World.cyl(f, V(x, y + 4.6, az), 0.5, r * 2 + 0.3, C(255, 255, 255), { Name = "PillarBand" }))
			y += 5
		end
		World.ball(f, V(x, y + 1.1, az), 2.4, C(225, 32, 56), { Name = "PillarCherry", Reflectance = 0.2 })
	end
	local signY = W.stageTop + 16.5
	local sign = box(f, CF(0, signY, az), V(22, 6, 1.4), C(255, 120, 165), { Name = "LandmarkSign" })
	box(f, CF(0, signY, az), V(23, 7, 1.0), C(255, 255, 255), { Name = "LandmarkFrame" })
	surfaceText(sign, Enum.NormalId.Back, "CAKE OFF! 🎂", C(255, 255, 255), 24)
	surfaceText(sign, Enum.NormalId.Front, "CAKE OFF! 🎂", C(255, 255, 255), 24)
	for k = 0, 10 do
		local bulb = deco(World.ball(f, V(-10.5 + k * 2.1, signY - 3.6, az + 0.75), 0.7, C(255, 236, 170), { Name = "Bulb", Material = Enum.Material.Neon, CanCollide = false }))
		table.insert(glows, bulb)
	end

	-- giant landmark cake, built with the same cake system, then scaled up
	local lm = Instance.new("Model")
	lm.Name = "LandmarkCake"
	lm.Parent = f
	local root = CF(0, signY + 3.5, az)
	local cake = CakeBuilder.newCake()
	cake.tiers = { "White", "Pink", "Lavender" }
	cake.drip = "Chocolate"
	World.cyl(lm, root.Position - V(0, 0.4, 0), 0.4, 11.5, C(255, 255, 255), { Name = "LandmarkPlate" })
	CakeBuilder.buildBody(lm, cake, root, { collide = false })
	CakeBuilder.buildDeco(lm, cake, root, { collide = false })
	local dims = CakeBuilder.dims(3)
	local topY = dims[3].y0 + dims[3].h
	for k = 0, 5 do
		local a = RAD(k * 60)
		local p = root * CF(math.cos(a) * 1.7, topY, math.sin(a) * 1.7)
		table.insert(cake.toppings, { id = "Candle", cf = root:ToObjectSpace(CakeBuilder.surfaceCF(root, p.Position, root.UpVector, 0)), s = 1, tint = if k % 2 == 0 then "Sky" else "Pink" })
	end
	table.insert(cake.toppings, { id = "Cherry", cf = CF(0, topY, 0), s = 1.3, tint = "Auto" })
	for k = 0, 7 do
		local a = RAD(k * 45 + 22)
		local y1 = dims[1].y0 + dims[1].h
		local p = root * CF(math.cos(a) * 4.4, y1, math.sin(a) * 4.4)
		table.insert(cake.toppings, { id = if k % 2 == 0 then "Swirl" else "Strawberry", cf = root:ToObjectSpace(CakeBuilder.surfaceCF(root, p.Position, root.UpVector, k)), s = 0.9, tint = "Auto" })
	end
	CakeBuilder.buildToppings(lm, cake, root, { collide = false })
	for _, d in ipairs(lm:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
		end
	end
	lm.WorldPivot = root
	lm:ScaleTo(2.1)
	local candleLight = Instance.new("PointLight")
	candleLight.Color = C(255, 200, 120)
	candleLight.Range = 24
	candleLight.Brightness = 1.5
	candleLight.Parent = sign

	-- spotlights aimed at the turntable, with balloon bunches
	local spots = {}
	local balloonCols = { P.pink, P.sky, P.lemon, P.mint, P.lavender }
	for k = 0, 3 do
		local a = RAD(45 + k * 90)
		local base = V(math.sin(a) * (R - 1.2), W.stageTop, math.cos(a) * (R - 1.2))
		World.cyl(f, base, 9, 0.6, C(255, 255, 255), { Name = "SpotPole" })
		local headPos = base + V(0, 9.4, 0)
		local head = box(f, CFrame.lookAt(headPos, W.turntable + V(0, 3, 0)), V(1.5, 1.5, 2), C(255, 150, 190), { Name = "SpotHead" })
		local lens = deco(box(f, head.CFrame * CF(0, 0, -1.02), V(1.2, 1.2, 0.08), C(255, 245, 220), { Name = "Lens", Material = Enum.Material.Neon }))
		table.insert(glows, lens)
		local sl = Instance.new("SpotLight")
		sl.Face = Enum.NormalId.Front
		sl.Brightness = 2.5
		sl.Range = 34
		sl.Angle = 50
		sl.Color = C(255, 240, 220)
		sl.Parent = head
		table.insert(spots, sl)
		for j = 0, 2 do
			local bp = headPos + V(math.cos(j * 2.1) * 1.4, 2.4 + j * 0.9, math.sin(j * 2.1) * 1.4)
			deco(World.ball(f, bp, 2.0, balloonCols[(k + j) % #balloonCols + 1], { Name = "Balloon", Reflectance = 0.15, CanCollide = false }))
			deco(World.rod(f, headPos + V(0, 0.6, 0), bp - V(0, 1, 0), 0.05, C(255, 255, 255), { Name = "String", CanCollide = false }))
		end
	end
	return tt, judges, glows, spots, podium
end

function Plaza.build(): Built
	Look.apply({
		preset = "A",
		overrides = { ClockTime = 15.2, Ambient = C(126, 116, 128), OutdoorAmbient = C(176, 160, 170) },
		atmosphere = { Color = C(255, 226, 236), Decay = C(255, 186, 204), Haze = 1.1, Density = 0.28, Offset = 0.2 },
		cc = { Brightness = 0.08, Contrast = 0.1, Saturation = 0.22, TintColor = C(255, 248, 243) },
		clouds = { Cover = 0.55, Density = 0.4, Color = C(255, 238, 246) },
	})

	local plaza = World.folder("Plaza")
	local rng = Random.new(12)
	buildGround(plaza)
	buildSpawn(plaza)

	local stationsF = World.folder("Stations")
	local stations = {}
	for i = 1, W.stationCount do
		table.insert(stations, buildStation(stationsF, i))
	end
	local slot = 360 / W.slots
	for i = 1, W.stationCount - 1 do
		buildGapDecor(plaza, (i + 0.5) * slot, rng)
	end
	for _, a in ipairs({ 45, 135, 225, 315 }) do
		local r = RAD(a)
		buildGiantCupcake(plaza, V(math.sin(r) * 78, 0, math.cos(r) * 78), Config.StationColors[(a // 90) % #Config.StationColors + 1])
	end
	buildBunting(plaza)
	local shops = World.folder("Shops", plaza)
	for k = 1, 16 do
		buildFacade(shops, k, (k - 0.5) * 22.5)
	end
	buildOutskirts(plaza, rng)
	-- invisible boundary in front of the shops
	local wall = World.folder("Boundary", plaza)
	for k = 0, 35 do
		local a = RAD(k * 10)
		local p = V(math.sin(a) * 86, 15, math.cos(a) * 86)
		local b = box(wall, CFrame.lookAt(p, V(0, 15, 0)), V(16, 40, 2), C(255, 255, 255), { Name = "Wall", Transparency = 1 })
		deco(b)
	end
	-- puffy clouds in the sky ring
	local sky = World.folder("Sky", plaza)
	for k = 0, 9 do
		local a = RAD(k * 36 + rng:NextNumber(-10, 10))
		local r = rng:NextNumber(140, 190)
		World.cloud(sky, V(math.sin(a) * r, rng:NextNumber(70, 110), math.cos(a) * r), rng:NextNumber(1.6, 2.4), rng, C(255, 246, 250))
	end

	local stage = World.folder("Stage")
	local tt, judges, glows, spots, podium = buildStage(stage)
	return { stations = stations, stage = stage, turntable = tt, judges = judges, glow = glows, spots = spots, podium = podium }
end

return Plaza

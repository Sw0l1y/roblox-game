-- Builds the world at server start: four floating island clusters (Meadow hub -> Candy Hills -> Sky Islands ->
-- Space Rainbow), each higher and farther than the last and visible from the previous one, joined by bridges
-- with coin gates. House style: SmoothPlastic palette parts, generated MaterialVariants only on big flat
-- surfaces (white tint when the variant exists, palette colour when it does not), props in clusters, clouds.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared:WaitForChild("World"))
local Config = require(Shared:WaitForChild("Config"))
local Fmt = require(Shared:WaitForChild("Fmt"))
local BalloonArt = require(Shared:WaitForChild("BalloonArt"))

local Map = {}

local V = Vector3.new
local CF = CFrame.new
local RAD = math.rad
local P = Config.Palette
local WHITE = Color3.new(1, 1, 1)
local rng = Random.new(20261010)

export type GateInfo = { zone: number, wall: BasePart, prompt: ProximityPrompt }
Map.gates = {} :: { GateInfo }
Map.root = nil :: Folder?

-- Colour for a surface that may carry a generated variant: white when the variant exists (Part.Color
-- multiplies the texture), the flat palette colour when it has not been generated yet.
local function tex(variant: string, flat: Color3): (Color3, string?)
	if World.hasVariant(variant) then
		return WHITE, variant
	end
	return flat, nil
end

local function persistent(m: Model)
	pcall(function()
		(m :: any).ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
end

-- Small props: no touch, no queries, no shadows (performance rule for decor).
local function finalize(root: Instance, keepQuery: boolean?)
	for _, inst in ipairs(root:GetDescendants()) do
		if inst:IsA("BasePart") then
			local p = inst :: BasePart
			p.CanTouch = false
			p.CastShadow = false
			if not keepQuery then
				p.CanQuery = false
			end
		end
	end
end

local function ell(parent: Instance, size: Vector3, pos: Vector3, color: Color3): BasePart
	local p = BalloonArt.ellip(parent, "Puff", size, CF(pos), color)
	p.CanCollide = false
	return p
end

---------------------------------------------------------------------------------------------------------------
-- Ground
---------------------------------------------------------------------------------------------------------------

type IslandStyle = { top: Color3, topVar: string?, rim: Color3, rimVar: string?, band: Color3, under: Color3, rimNeon: boolean? }

local function island(parent: Instance, blobs: { { number } }, y: number, s: IslandStyle)
	local f = World.folder("Island", parent)
	for _, b in ipairs(blobs) do
		local x, z, r = b[1], b[2], b[3]
		World.disc(f, x, z, r, y, 6, s.top, s.topVar)
		local rim = World.disc(f, x, z, r + 5, y - 0.35, 5.5, s.rim, s.rimVar)
		if s.rimNeon then
			rim.Material = Enum.Material.Neon
		end
		World.disc(f, x, z, r + 3.5, y - 5.6, 5, s.band)
		World.disc(f, x, z, r * 0.78, y - 10.4, 6, s.under)
		World.disc(f, x, z, r * 0.52, y - 16.2, 7, s.band)
		World.disc(f, x, z, r * 0.28, y - 23, 8, s.under)
	end
	for _, inst in ipairs(f:GetDescendants()) do
		if inst:IsA("BasePart") then
			(inst :: BasePart).CanTouch = false;
			(inst :: BasePart).CastShadow = false
		end
	end
	return f
end

-- Flat discs a hair above the ground (lawn patches, plaza rings).
local function patch(parent: Instance, x: number, z: number, r: number, y: number, color: Color3, variant: string?): BasePart
	local p = World.disc(parent, x, z, r, y, 0.2, color, variant)
	p.CanTouch = false
	p.CastShadow = false
	return p
end

---------------------------------------------------------------------------------------------------------------
-- Shared props
---------------------------------------------------------------------------------------------------------------

local function bush(parent: Instance, pos: Vector3, c: World.Leaves, scale: number?)
	World.bush(parent, pos, c, rng, scale)
end

local function lampRow(parent: Instance, points: { Vector3 }, pole: Color3, glow: Color3)
	for _, p in ipairs(points) do
		World.lamp(parent, p, pole, glow)
	end
end

-- Arch of balloons over a path exit. `pos` is the ground point at the arch centre, `along` the path direction.
local function balloonArch(parent: Instance, pos: Vector3, along: Vector3, radius: number, colors: { Color3 })
	local f = World.folder("BalloonArch", parent)
	local side = along:Cross(Vector3.yAxis).Unit
	local n = 13
	for i = 0, n - 1 do
		local t = math.pi * i / (n - 1)
		local p = pos + side * (math.cos(t) * radius) + V(0, math.sin(t) * radius + 1.6, 0)
		BalloonArt.simple(f, p, 2.8, colors[i % #colors + 1], 0, p + along)
	end
	for _, sx in ipairs({ -1, 1 }) do
		World.cyl(f, pos + side * (sx * radius), 1.2, 2.2, P.white)
	end
	finalize(f)
	return f
end

local function signBoard(parent: Instance, pos: Vector3, facing: Vector3, text: string, w: number, h: number, board: Color3)
	local cf = CFrame.lookAt(pos, V(facing.X, pos.Y, facing.Z))
	World.sign(parent, cf, Vector2.new(w, h), text, board, WHITE, P.white)
end

---------------------------------------------------------------------------------------------------------------
-- Hub: plaza, MEGA PUMP stage, booths, helper bots, spawn
---------------------------------------------------------------------------------------------------------------

local function partyBot(parent: Instance, pos: Vector3, color: Color3)
	local m = World.model("PartyBot", parent)
	local out = V(pos.X, 0, pos.Z).Unit
	local cf = CFrame.lookAt(pos, pos + out)
	World.cyl(m, pos, 0.6, 2.8, P.ink)
	World.ball(m, pos + V(0, 2, 0), 2.9, color)
	World.ball(m, pos + V(0, 4.1, 0), 2.3, P.white)
	for _, sx in ipairs({ -1, 1 }) do
		World.ball(m, (cf * CF(sx * 0.45, 4.25, -0.98)).Position, 0.5, P.ink)
		World.ball(m, (cf * CF(sx * 0.7, 3.85, -0.86)).Position, 0.42, P.pink)
	end
	World.cyl(m, pos + V(0, 5.1, 0), 0.5, 1.3, color)
	World.cyl(m, pos + V(0, 5.6, 0), 0.6, 0.25, P.ink)
	World.box(m, CF(pos + V(0, 6.25, 0)) * CFrame.Angles(0, RAD(30), 0), V(3.2, 0.15, 0.5), P.yellow)
	local shoulder = (cf * CF(1.5, 2.6, 0)).Position
	local hand = (cf * CF(2.1, 4.4, -0.6)).Position
	World.rod(m, shoulder, hand, 0.5, color)
	World.rod(m, hand, hand + V(0, 1.6, 0), 0.22, P.white)
	World.box(m, CF(hand + V(0, 0.35, 0)), V(0.6, 0.5, 0.08), P.red)
	finalize(m, true)
	return m
end

local function booth(parent: Instance, center: Vector3, facing: Vector3, color: Color3, title: string, kind: string)
	local m = World.model("Booth_" .. kind, parent)
	local cf = CFrame.lookAt(center, V(facing.X, center.Y, facing.Z))
	local function at(x: number, y: number, z: number): CFrame
		return cf * CF(x, y, z)
	end
	World.box(m, at(0, 0.3, 0), V(13, 0.6, 9), P.structure)
	World.box(m, at(0, 1.9, -3.4), V(11, 3.2, 2.2), P.white)
	World.box(m, at(0, 2.2, -4.55), V(11.2, 0.9, 0.2), color)
	World.box(m, at(0, 3.6, -3.4), V(11.6, 0.4, 2.6), color)
	World.box(m, at(0, 5, 4.1), V(13, 9.4, 0.8), color)
	for _, sx in ipairs({ -1, 1 }) do
		World.cyl(m, (at(sx * 6, 0.6, -4)).Position, 8.6, 0.8, P.white)
	end
	-- striped awning
	for i = 0, 6 do
		local x = -6 + i * 2
		World.box(m, at(x + 1, 9.6, -0.4) * CFrame.Angles(RAD(-18), 0, 0), V(2, 0.35, 9.4), i % 2 == 0 and color or P.white)
	end
	World.sign(m, at(0, 12.6, 3.6), Vector2.new(12, 2.8), title, color, WHITE)
	if kind == "Upgrades" then
		-- target board and a giant dart on the roof
		local tc = at(0, 17.2, 3.8)
		for i, r in ipairs({ 3.4, 2.6, 1.8, 1.0 }) do
			World.part({ Name = "Target", Shape = Enum.PartType.Cylinder, Size = V(0.4 + i * 0.05, r * 2, r * 2), CFrame = tc * CFrame.Angles(0, RAD(90), 0), Color = i % 2 == 1 and P.red or P.white, Parent = m })
		end
		local tip = (tc * CF(0.6, 0.4, -0.4)).Position
		local tail = (tc * CF(3.8, 2.6, -4.6)).Position
		World.rod(m, tip, tail, 0.45, P.yellow)
		World.ball(m, tip, 0.6, Color3.fromRGB(200, 205, 215))
		World.box(m, CFrame.lookAt(tail, tip) * CF(0, 0, -0.4), V(1.6, 0.12, 1.2), P.red)
		World.box(m, CFrame.lookAt(tail, tip) * CF(0, 0, -0.4), V(0.12, 1.6, 1.2), P.red)
	elseif kind == "Shop" then
		local base = at(5.2, 10, 3)
		BalloonArt.simple(m, (base * CF(0, 6.4, 0)).Position, 3, P.red, 5, nil)
		BalloonArt.simple(m, (base * CF(-1.6, 5.6, 0.5)).Position, 2.8, P.yellow, 4.2, nil)
		BalloonArt.simple(m, (base * CF(1.4, 5.2, -0.4)).Position, 2.6, P.sky, 3.8, nil)
		World.crate(m, (at(-4.5, 0.6, -0.6)).Position, 1.6, P.pink, P.yellow)
		World.crate(m, (at(-3, 0.6, 0.6)).Position, 1.2, P.sky, P.white)
	elseif kind == "Index" then
		for i, key in ipairs({ "heart", "striped", "star" }) do
			local def = Config.Balloons[key]
			local pos = (at(-8.6 + (i - 1) * 0, 0, 1 - (i - 1) * 2.6)).Position
			World.cyl(m, pos, 2.2, 1.8, P.white)
			local b = BalloonArt.build(def, { size = 2.4, noString = true })
			b:PivotTo(CFrame.lookAt(pos + V(0, 4, 0), pos + V(0, 4, 0) + (cf.LookVector)))
			b.Parent = m
		end
	elseif kind == "Rebirth" then
		local c = at(8.8, 0, 0)
		for i = 0, 11 do
			local t = math.pi * i / 11
			local pos = (c * CF(0, math.sin(t) * 5 + 0.6, math.cos(t) * 5)).Position
			World.ball(m, pos, 1.5, P.rainbow[i % #P.rainbow + 1], { Material = Enum.Material.Neon })
		end
	end
	finalize(m, true)
	return m
end

local function buildHub(parent: Instance)
	local hub = World.folder("Hub", parent)
	local slab, slabVar = tex("HouseSlabs", P.structure)
	World.disc(hub, 0, 0, 33.6, 0.1, 1, P.pink)
	World.disc(hub, 0, 0, 32, 0.14, 1, slab, slabVar)
	patch(hub, 0, 0, 25.6, 0.17, P.sky)
	patch(hub, 0, 0, 24.6, 0.19, slab, slabVar)
	-- pastel tile inlays around the ring
	for i = 0, 11 do
		local a = RAD(i * 30 + 15)
		patch(hub, math.cos(a) * 28.6, math.sin(a) * 28.6, 1.6, 0.2, P.rainbow[i % #P.rainbow + 1])
	end

	-- MEGA PUMP stage
	local stage = World.folder("Stage", hub)
	local glowRing = World.disc(stage, 0, 0, 16.6, 0.32, 0.4, P.pink)
	glowRing.Material = Enum.Material.Neon
	World.disc(stage, 0, 0, 15.8, 0.72, 0.8, P.gold)
	World.disc(stage, 0, 0, Config.Hub.stageR, Config.Hub.stageTop, 0.8, slab, slabVar)
	patch(stage, 0, 0, 9, Config.Hub.stageTop + 0.03, P.sky)
	patch(stage, 0, 0, 8.2, Config.Hub.stageTop + 0.05, slab, slabVar)

	local base = V(0, Config.Hub.stageTop, 0)
	World.cyl(stage, base, 3, 9, P.pink, { Name = "PumpBase" })
	World.cyl(stage, base + V(0, 3, 0), 7, 5.6, P.white, { Name = "PumpBody" })
	World.cyl(stage, base + V(0, 4.6, 0), 0.6, 5.9, P.red)
	World.cyl(stage, base + V(0, 7.8, 0), 0.6, 5.9, P.red)
	World.cyl(stage, base + V(0, 10, 0), 1, 3.6, P.gold)
	World.cyl(stage, base + V(0, 11, 0), Config.Hub.nozzleTop - Config.Hub.stageTop - 11, 1.6, P.gold, { Name = "Nozzle" })
	-- plunger lever
	World.rod(stage, base + V(3.4, 3, 0), base + V(3.4, 15.5, 0), 0.6, P.gold)
	World.rod(stage, base + V(3.4, 15.5, -2.4), base + V(3.4, 15.5, 2.4), 0.7, P.red)
	World.rod(stage, base + V(2.8, 9, 0), base + V(3.4, 9, 0), 0.5, P.gold)
	-- gauge facing spawn
	World.part({ Name = "Gauge", Shape = Enum.PartType.Cylinder, Size = V(0.3, 2.6, 2.6), CFrame = CF(base + V(0, 6.2, 2.85)) * CFrame.Angles(0, RAD(90), 0), Color = P.white, Parent = stage })
	World.part({ Name = "GaugeRim", Shape = Enum.PartType.Cylinder, Size = V(0.24, 2.9, 2.9), CFrame = CF(base + V(0, 6.2, 2.78)) * CFrame.Angles(0, RAD(90), 0), Color = P.ink, Parent = stage })
	World.box(stage, CF(base + V(0.35, 6.55, 3.02)) * CFrame.Angles(0, 0, RAD(-40)), V(0.18, 1.1, 0.1), P.red)
	World.sign(stage, CF(base + V(0, 1.6, 4.75)), Vector2.new(7.2, 1.8), "🎈 MEGA PUMP", P.pink, WHITE)
	finalize(stage, true)

	for i, pos in ipairs(Config.Hub.botSpots) do
		partyBot(hub, pos, ({ P.pink, P.sky, P.yellow, P.mint })[i])
	end

	-- booths and their glowing pads
	for _, b in ipairs(Config.Hub.booths) do
		local pos = Config.boothPos(b.angle, Config.Hub.boothR)
		booth(hub, pos, V(0, 0, 0), b.color, b.title, b.panel)
		local padPos = Config.boothPos(b.angle, Config.Hub.boothR - 8.5)
		local glow = World.pad(hub, padPos + V(0, 0.12, 0), 3.4, b.color)
		glow.CanTouch = false
	end

	-- balloon arches at the four exits
	for i = 0, 3 do
		local a = RAD(i * 90)
		local dir = V(math.cos(a), 0, math.sin(a))
		balloonArch(hub, dir * 34, dir, 6.5, { P.red, P.yellow, P.sky, P.pink, P.mint })
	end
	-- title over the spawn-side arch
	local titleCf = CFrame.lookAt(V(0, 10.5, 34), V(0, 10.5, 80))
	World.sign(hub, titleCf, Vector2.new(18, 3.4), "POP ALL THE BALLOONS!", P.red, WHITE)
	finalize(hub, true)
end

local function buildSpawn(parent: Instance)
	local sp = Config.Zones[1].spawn
	local f = World.folder("Spawn", parent)
	World.disc(f, sp.X, sp.Z, 7, 0.24, 0.3, P.pink)
	World.disc(f, sp.X, sp.Z, 6, 0.3, 0.3, P.white)
	local ring = World.disc(f, sp.X, sp.Z, 4.4, 0.33, 0.2, P.sky)
	ring.Material = Enum.Material.Neon
	World.disc(f, sp.X, sp.Z, 3.6, 0.36, 0.2, P.white)
	local s = World.part({
		Class = "SpawnLocation",
		Name = "SpawnLocation",
		Size = V(8, 0.4, 8),
		CFrame = CFrame.lookAt(sp + V(0, 0.6, 0), V(0, 0.6, 0)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = true,
		Neutral = true,
		Duration = 0,
		Parent = f,
	})
	for _, c in ipairs(s:GetChildren()) do
		if c:IsA("Decal") then
			c:Destroy()
		end
	end
	finalize(f, true)
end

---------------------------------------------------------------------------------------------------------------
-- Bridges and gates
---------------------------------------------------------------------------------------------------------------

type BridgeStyle = { strips: { Color3 }, rail: Color3, under: Color3, balloons: { Color3 }, neonEdge: Color3? }

local function bridge(parent: Instance, a: Vector3, b: Vector3, width: number, s: BridgeStyle)
	local f = World.folder("Bridge", parent)
	local dir = b - a
	local len = dir.Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b)
	local n = #s.strips
	local sw = width / n
	for i, col in ipairs(s.strips) do
		local off = (i - (n + 1) / 2) * sw
		World.box(f, cf * CF(off, -0.5, 0), V(sw, 1, len + 4), col, { Name = "Deck" })
	end
	World.box(f, cf * CF(0, -2.4, 0), V(width * 0.7, 3, len), s.under, { Name = "Beam" })
	if s.neonEdge then
		for _, sx in ipairs({ -1, 1 }) do
			World.box(f, cf * CF(sx * (width / 2 + 0.15), -0.4, 0), V(0.3, 0.9, len + 4), s.neonEdge, { Material = Enum.Material.Neon })
		end
	end
	local posts = math.floor(len / 14)
	local prev: { [number]: Vector3 } = {}
	for i = 0, posts do
		local t = i / posts
		for _, sx in ipairs({ -1, 1 }) do
			local base = (cf * CF(sx * (width / 2 - 0.5), 0, len / 2 - t * len)).Position
			World.cyl(f, base, 4, 0.7, s.rail)
			local top = base + V(0, 4, 0)
			World.ball(f, top, 1, s.rail)
			if prev[sx] then
				World.rod(f, prev[sx], top, 0.45, s.rail)
			end
			prev[sx] = top
			if i % 2 == 1 then
				BalloonArt.simple(f, top + V(0, 3.4, 0), 2.4, s.balloons[(i + (sx > 0 and 1 or 0)) % #s.balloons + 1], 2.4, nil)
			end
		end
	end
	finalize(f, true)
	-- the deck itself must stay walkable and queryable
	for _, d in ipairs(f:GetChildren()) do
		if d:IsA("BasePart") and d.Name == "Deck" then
			(d :: BasePart).CanQuery = true
		end
	end
	return f
end

local function gate(parent: Instance, zoneIndex: number)
	local z = Config.Zones[zoneIndex]
	local pos = z.gate :: Vector3
	local f = World.folder("Gate_" .. z.key, parent)
	local cf = CFrame.lookAt(pos, pos + V(0, 0, -1))
	for _, sx in ipairs({ -1, 1 }) do
		local p = (cf * CF(sx * 11, 0, 0)).Position
		World.cyl(f, p, 18, 3.4, z.accent)
		World.cyl(f, p + V(0, 18, 0), 1.2, 4.4, P.gold)
		World.ball(f, p + V(0, 20.4, 0), 3, P.gold)
	end
	World.box(f, cf * CF(0, 18.6, 0), V(26, 2.6, 2.6), z.accent)
	World.sign(f, cf * CF(0, 22.6, 0), Vector2.new(22, 4.2), z.glyph .. " " .. string.upper(z.name), z.accent, WHITE)
	finalize(f, true)

	local wall = World.part({
		Name = "GateWall",
		Size = V(56, 18, 1),
		CFrame = cf * CF(0, 9, 0),
		Color = z.accent,
		Material = Enum.Material.Neon,
		Transparency = 0.6,
		CanCollide = true,
		CanTouch = false,
		CastShadow = false,
		Parent = f,
	})
	wall:SetAttribute("Zone", zoneIndex)
	CollectionService:AddTag(wall, "ZoneGate")
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sg = Instance.new("SurfaceGui")
		sg.Name = "Price"
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 24
		sg.LightInfluence = 0
		sg.MaxDistance = 220
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.42)
		l.Size = UDim2.fromScale(0.42, 0.5)
		l.Font = Enum.Font.LuckiestGuy
		l.TextScaled = true
		l.TextColor3 = WHITE
		l.Text = "🔒 " .. string.upper(z.name) .. "\n🪙 " .. Fmt.commas(z.cost)
		local st = Instance.new("UIStroke")
		st.Thickness = 4
		st.Color = P.ink
		st.Parent = l
		l.Parent = sg
		sg.Parent = wall
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UnlockPrompt"
	prompt.ActionText = "Unlock 🪙 " .. Fmt.num(z.cost)
	prompt.ObjectText = z.glyph .. " " .. z.name
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("Zone", zoneIndex)
	prompt.Parent = wall
	table.insert(Map.gates, { zone = zoneIndex, wall = wall, prompt = prompt })
end

---------------------------------------------------------------------------------------------------------------
-- Zone 1: Meadow
---------------------------------------------------------------------------------------------------------------

local MEADOW_BLOBS = {
	{ 0, 0, 50 }, { 0, 84, 40 }, { 90, 6, 38 }, { -90, 6, 38 }, { 55, 55, 26 }, { -55, 55, 26 },
	{ 52, -52, 24 }, { -52, -52, 24 }, { 0, -66, 24 },
}

local function buildMeadow(zm: Model)
	local m = P.meadow
	local grass, grassVar = tex("HouseGrass", m.grass)
	local sand, sandVar = tex("HouseSand", m.sand)
	island(zm, MEADOW_BLOBS, 0, { top = grass, topVar = grassVar, rim = sand, rimVar = sandVar, band = m.dirt, under = m.dirtDark })

	local paths = World.folder("Paths", zm)
	local slab, slabVar = tex("HouseSlabs", m.path)
	World.path(paths, { V(0, 0, 33), V(0, 0, 62) }, 9, slab, slabVar, 0.06)
	World.path(paths, { V(33, 0, 0), V(60, 0, 4) }, 9, slab, slabVar, 0.06)
	World.path(paths, { V(-33, 0, 0), V(-60, 0, 4) }, 9, slab, slabVar, 0.06)
	World.path(paths, { V(0, 0, -33), V(0, 0, -86) }, 9, slab, slabVar, 0.06)
	finalize(paths, true)

	buildHub(zm)
	buildSpawn(zm)

	local decor = World.folder("Decor", zm)
	local leaves: World.Leaves = { trunk = m.trunk, leaf1 = m.leaf1, leaf2 = m.leaf2, leaf3 = m.leaf3 }
	local pinkLeaves: World.Leaves = { trunk = m.trunk, leaf1 = Color3.fromRGB(255, 170, 200), leaf2 = Color3.fromRGB(255, 195, 215), leaf3 = Color3.fromRGB(255, 145, 185) }
	local flowerHeads = { P.pink, P.yellow, P.white, P.sky, P.red }
	local rocks = { rock = m.rock, rockDark = m.rockDark }

	-- clusters around the edges, between the balloon fields (never inside them)
	local spots = {
		{ "trio", 30, 106, 1 }, { "trio", -32, 104, 0.9 }, { "flowers", 14, 117, 1 }, { "flowers", -14, 118, 1 },
		{ "pinktrio", 108, -24, 1 }, { "trio", 122, 10, 0.9 }, { "bushrock", 108, 36, 1 },
		{ "pinktrio", -108, -24, 1 }, { "trio", -122, 10, 0.9 }, { "bushrock", -108, 36, 1 },
		{ "trio", 74, 60, 0.8 }, { "flowers", 64, 74, 1 }, { "trio", -74, 60, 0.8 }, { "flowers", -64, 74, 1 },
		{ "pinktrio", 66, -66, 0.75 }, { "bushrock", 70, -48, 0.8 }, { "pinktrio", -66, -66, 0.75 }, { "bushrock", -70, -48, 0.8 },
		{ "flowers", 12, -60, 1 }, { "flowers", -12, -60, 1 }, { "bush", 16, -74, 0.8 }, { "bush", -16, -74, 0.8 },
		{ "flowers", 40, 30, 0.9 }, { "flowers", -40, 30, 0.9 }, { "bush", 44, -14, 0.7 }, { "bush", -44, -14, 0.7 },
	}
	for _, s in ipairs(spots) do
		local kind, x, z, sc = s[1] :: string, s[2] :: number, s[3] :: number, s[4] :: number
		local pos = V(x, 0, z)
		if kind == "trio" then
			World.treeTrio(decor, pos, leaves, sc)
			patch(decor, x + 3, z + 3, 9 * sc, 0.04, m.grassDark)
		elseif kind == "pinktrio" then
			World.treeTrio(decor, pos, pinkLeaves, sc)
			patch(decor, x + 3, z + 3, 9 * sc, 0.04, m.grassDark)
		elseif kind == "flowers" then
			World.flowers(decor, pos, m.leaf3, flowerHeads, rng)
			World.flowers(decor, pos + V(3, 0, 2), m.leaf3, flowerHeads, rng)
		elseif kind == "bushrock" then
			bush(decor, pos, leaves, sc)
			World.rocks(decor, pos + V(4, 0, -3), rocks, rng, 0.7 * sc)
		elseif kind == "bush" then
			bush(decor, pos, leaves, sc)
		end
	end

	-- lamps along the paths
	lampRow(decor, { V(6, 0, 46), V(-6, 0, 46), V(6, 0, 60), V(-6, 0, 60), V(46, 0, 7), V(46, 0, -5), V(-46, 0, 7), V(-46, 0, -5), V(6, 0, -48), V(-6, 0, -48), V(6, 0, -72), V(-6, 0, -72) }, P.white, P.yellow)

	-- balloon carts near the spawn
	for _, sx in ipairs({ -1, 1 }) do
		local c = V(sx * 22, 0, 112)
		World.box(decor, CF(c + V(0, 2, 0)), V(5, 2, 3), sx < 0 and P.pink or P.sky)
		World.box(decor, CF(c + V(0, 3.1, 0)), V(5.4, 0.3, 3.4), P.white)
		for _, wx in ipairs({ -1.8, 1.8 }) do
			World.part({ Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = V(0.5, 1.8, 1.8), CFrame = CF(c + V(wx, 0.9, 1.6)), Color = P.ink, Parent = decor })
			World.part({ Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = V(0.5, 1.8, 1.8), CFrame = CF(c + V(wx, 0.9, -1.6)), Color = P.ink, Parent = decor })
		end
		for i, col in ipairs({ P.red, P.yellow, P.mint, P.lilac }) do
			BalloonArt.simple(decor, c + V(-1.5 + i, 7 + (i % 2) * 0.8, (i % 2) * 0.6 - 0.3), 2.2, col, 3.6, V(0, 0, 0))
		end
	end

	-- signposts
	signBoard(decor, V(10, 3.6, 70), V(10, 3.6, 0), "⬆️ UPGRADES ←", 9, 1.8, P.sky)
	signBoard(decor, V(-10, 3.6, -60), V(-10, 3.6, 0), "🍬 CANDY HILLS ↑", 10, 1.8, P.pink)
	finalize(decor)
	-- tree trunks stay solid, everything else is walk-through decor
	for _, d in ipairs(decor:GetDescendants()) do
		if d:IsA("BasePart") and (d.Name == "Trunk" or d.Name == "LampPole") then
			(d :: BasePart).CanCollide = true
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Zone 2: Candy Hills
---------------------------------------------------------------------------------------------------------------

local CANDY_BLOBS = {
	{ 0, -236, 24 }, { 0, -300, 44 }, { 80, -298, 34 }, { -80, -298, 34 }, { 46, -350, 22 }, { -46, -350, 22 }, { 0, -364, 22 },
}

local function candyCane(parent: Instance, pos: Vector3, h: number, yaw: number)
	local n = math.floor(h / 1.6)
	for i = 0, n - 1 do
		World.cyl(parent, pos + V(0, i * 1.6, 0), 1.6, 1.4, i % 2 == 0 and P.candy.cherry or P.white)
	end
	local top = pos + V(0, n * 1.6, 0)
	local cf = CF(top) * CFrame.Angles(0, yaw, 0)
	for i = 1, 5 do
		local t = math.pi * i / 6
		local p = (cf * CF(1.6 - math.cos(t) * 1.6, math.sin(t) * 1.6, 0)).Position
		World.ball(parent, p, 1.5, i % 2 == 0 and P.candy.cherry or P.white)
	end
end

local function lolliTree(parent: Instance, pos: Vector3, h: number, d: number, a: Color3, b: Color3, yaw: number)
	World.cyl(parent, pos, h, 0.7, P.white)
	local cf = CF(pos + V(0, h + d * 0.4, 0)) * CFrame.Angles(0, yaw, 0)
	World.part({ Name = "Candy", Shape = Enum.PartType.Cylinder, Size = V(d * 0.22, d, d), CFrame = cf, Color = a, Parent = parent })
	World.part({ Name = "Candy", Shape = Enum.PartType.Cylinder, Size = V(d * 0.26, d * 0.62, d * 0.62), CFrame = cf, Color = b, Parent = parent })
	World.part({ Name = "Candy", Shape = Enum.PartType.Cylinder, Size = V(d * 0.3, d * 0.28, d * 0.28), CFrame = cf, Color = a, Parent = parent })
end

local function gumdrop(parent: Instance, pos: Vector3, d: number, color: Color3)
	local g = ell(parent, V(d, d * 0.8, d), pos + V(0, d * 0.18, 0), color)
	g.Reflectance = 0.06
	g.CanCollide = true
	for i = 1, 4 do
		local a = RAD(i * 90 + 20)
		World.ball(parent, pos + V(math.cos(a) * d * 0.28, d * 0.5, math.sin(a) * d * 0.28), d * 0.07, P.white)
	end
end

local function donutRing(parent: Instance, pos: Vector3, r: number, frost: Color3)
	for i = 0, 9 do
		local a = RAD(i * 36)
		World.ball(parent, pos + V(math.cos(a) * r, r * 0.42, math.sin(a) * r), r * 0.9, frost)
		World.ball(parent, pos + V(math.cos(a + 0.3) * r, r * 0.3, math.sin(a + 0.3) * r), r * 0.85, Color3.fromRGB(232, 172, 112))
	end
end

local function cupcakeHouse(parent: Instance, pos: Vector3, s: number, frost: Color3, wrap: Color3, facing: Vector3)
	local cf = CFrame.lookAt(pos, V(facing.X, pos.Y, facing.Z))
	World.cyl(parent, pos, 7 * s, 12 * s, wrap)
	for i = 0, 11 do
		local a = RAD(i * 30)
		World.box(parent, CF(pos + V(math.cos(a) * 6 * s, 3.5 * s, math.sin(a) * 6 * s)) * CFrame.Angles(0, -a, 0), V(0.6, 7 * s, 0.6) * V(1, 1, 1), BalloonArt.shade(wrap, 0.82))
	end
	ell(parent, V(15 * s, 8 * s, 15 * s), pos + V(0, 8 * s, 0), frost).CanCollide = true
	ell(parent, V(10 * s, 7 * s, 10 * s), pos + V(0, 11.5 * s, 0), frost).CanCollide = true
	World.ball(parent, pos + V(0, 15.6 * s, 0), 3 * s, P.candy.cherry)
	World.box(parent, cf * CF(0, 2.2 * s, -6 * s), V(3 * s, 4.4 * s, 0.6), P.candy.choc)
	for _, sx in ipairs({ -1, 1 }) do
		World.box(parent, cf * CF(sx * 3.4 * s, 4.4 * s, -5.6 * s), V(1.6 * s, 1.6 * s, 0.5), P.candy.lemon, { Material = Enum.Material.Neon })
	end
end

local function buildCandy(zm: Model)
	local c = P.candy
	local y = Config.Zones[2].groundY
	local top, topVar = tex("CandyFrosting", c.ground)
	island(zm, CANDY_BLOBS, y, { top = top, topVar = topVar, rim = c.rim, band = c.choc, under = c.chocDark })
	local paths = World.folder("Paths", zm)
	World.path(paths, { V(0, y, -228), V(0, y, -266) }, 9, c.mint, nil, y + 0.06)
	World.path(paths, { V(0, y, -334), V(0, y, -380) }, 9, c.mint, nil, y + 0.06)
	finalize(paths, true)

	local decor = World.folder("Decor", zm)
	local function g(x: number, z: number): Vector3
		return V(x, y, z)
	end
	-- giant lollipops: the landmark you see from the Meadow
	lolliTree(decor, g(118, -300), 44, 26, c.cherry, P.white, RAD(90))
	lolliTree(decor, g(-118, -300), 44, 26, c.lilac, P.white, RAD(90))
	lolliTree(decor, g(0, -390), 34, 20, c.mint, c.ground, 0)
	-- arrival plaza
	patch(decor, 0, -236, 14, y + 0.05, c.rim)
	patch(decor, 0, -236, 12.6, y + 0.07, c.mint)
	signBoard(decor, g(0, -250) + V(0, 6, 0), g(0, -220) + V(0, 6, 0), "🍬 CANDY HILLS  x10 COINS", 18, 2.8, c.cherry)
	-- candy canes and lollipop trees in clusters
	for _, s in ipairs({ { 14, -244 }, { -14, -244 }, { 40, -276 }, { -40, -276 }, { 62, -340 }, { -62, -340 }, { 104, -322 }, { -104, -322 } }) do
		candyCane(decor, g(s[1], s[2]), 12 + rng:NextNumber(0, 5), rng:NextNumber(0, 6.28))
	end
	local lolliCols = { c.cherry, c.lilac, c.mint, c.lemon, P.sky }
	for i, s in ipairs({ { 22, -232 }, { -22, -232 }, { 36, -258 }, { -36, -258 }, { 106, -270 }, { -106, -270 }, { 98, -334 }, { -98, -334 }, { 30, -372 }, { -30, -372 }, { 70, -360 }, { -70, -360 } }) do
		lolliTree(decor, g(s[1], s[2]), rng:NextNumber(7, 11), rng:NextNumber(5, 7), lolliCols[i % #lolliCols + 1], P.white, rng:NextNumber(0, 6.28))
	end
	-- gumdrop hills around the rim
	local gumCols = { c.mint, c.lemon, c.lilac, c.cherry, P.sky, c.ground }
	for i = 0, 17 do
		local a = RAD(i * 20 + 5)
		local blob = i % 3 == 0 and CANDY_BLOBS[3] or (i % 3 == 1 and CANDY_BLOBS[4] or CANDY_BLOBS[2])
		local r = blob[3] - 3
		local x, z = blob[1] + math.cos(a) * r, blob[2] + math.sin(a) * r
		local nearField = false
		for _, f in ipairs(Config.Zones[2].fields) do
			if (V(x, 0, z) - V(f[1], 0, f[2])).Magnitude < f[3] + 3 then
				nearField = true
			end
		end
		if not nearField and math.abs(x) > 7 then
			gumdrop(decor, g(x, z), rng:NextNumber(5, 9), gumCols[i % #gumCols + 1])
		end
	end
	donutRing(decor, g(26, -236), 1.6, c.ground)
	donutRing(decor, g(-60, -366), 1.6, c.lilac)
	cupcakeHouse(decor, g(108, -262), 0.75, c.ground, P.sky, g(80, -298))
	cupcakeHouse(decor, g(-108, -262), 0.75, c.lemon, c.cherry, g(-80, -298))
	-- chocolate drips on the arrival rim
	for i = 0, 7 do
		local a = RAD(i * 45 + 10)
		ell(decor, V(3, 5, 3), V(math.cos(a) * 29, y - 3.5, -236 + math.sin(a) * 29), c.choc)
	end
	finalize(decor)
	for _, d in ipairs(decor:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Cylinder" then
			(d :: BasePart).CanCollide = true
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Zone 3: Sky Islands
---------------------------------------------------------------------------------------------------------------

local SKY_BLOBS = {
	{ 0, -530, 24 }, { 0, -596, 44 }, { 80, -594, 34 }, { -80, -594, 34 }, { 46, -646, 22 }, { -46, -646, 22 }, { 0, -660, 22 },
}

local function rainbowArch(parent: Instance, center: Vector3, radius: number, thickness: number)
	local cols = P.rainbow
	local segs = 18
	for bi, col in ipairs(cols) do
		local r = radius - (bi - 1) * thickness
		for i = 0, segs - 1 do
			local t0 = math.pi * i / segs
			local t1 = math.pi * (i + 1) / segs
			local a = center + V(math.cos(t0) * r, math.sin(t0) * r, 0)
			local b = center + V(math.cos(t1) * r, math.sin(t1) * r, 0)
			local len = (b - a).Magnitude + 0.6
			World.box(parent, CFrame.lookAt((a + b) / 2, b, Vector3.zAxis), V(thickness, 3, len), col, { Material = Enum.Material.SmoothPlastic })
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		local foot = center + V(sx * (radius - thickness * 2.5), 0, 0)
		for i = 1, 5 do
			ell(parent, V(16, 10, 16) * rng:NextNumber(0.7, 1.1), foot + V(rng:NextNumber(-7, 7), rng:NextNumber(0, 5), rng:NextNumber(-6, 6)), P.white)
		end
	end
end

local function pillar(parent: Instance, pos: Vector3, h: number)
	local s = P.clouds
	World.cyl(parent, pos, 1.2, 4.2, s.gold)
	World.cyl(parent, pos + V(0, 1.2, 0), h, 2.8, P.white)
	World.cyl(parent, pos + V(0, 1.2 + h, 0), 1, 4.2, s.gold)
	World.ball(parent, pos + V(0, 3 + h, 0), 1.8, s.gold, { Material = Enum.Material.Neon })
end

local function islet(parent: Instance, pos: Vector3, r: number, leaves: World.Leaves)
	World.disc(parent, pos.X, pos.Z, r, pos.Y, 3, P.clouds.ground)
	World.disc(parent, pos.X, pos.Z, r * 0.7, pos.Y - 3, 4, P.clouds.under)
	World.disc(parent, pos.X, pos.Z, r * 0.4, pos.Y - 7, 4, P.clouds.underDark)
	World.tree(parent, pos, r / 8, leaves)
	for i = 1, 3 do
		local a = RAD(i * 120)
		ell(parent, V(r, r * 0.5, r), pos + V(math.cos(a) * r * 0.7, -5, math.sin(a) * r * 0.7), P.white)
	end
end

local function buildSky(zm: Model)
	local s = P.clouds
	local y = Config.Zones[3].groundY
	local top, topVar = tex("CloudFluff", s.ground)
	island(zm, SKY_BLOBS, y, { top = top, topVar = topVar, rim = s.blue, band = s.under, under = s.underDark })
	local decor = World.folder("Decor", zm)
	local function g(x: number, z: number): Vector3
		return V(x, y, z)
	end
	local paths = World.folder("Paths", zm)
	World.path(paths, { V(0, y, -522), V(0, y, -560) }, 9, s.gold, nil, y + 0.06)
	World.path(paths, { V(0, y, -630), V(0, y, -676) }, 9, s.gold, nil, y + 0.06)
	finalize(paths, true)

	-- landmark rainbow arch across the zone (seen from Candy Hills)
	rainbowArch(decor, V(0, y - 2, -640), 92, 3.2)
	-- puffy cloud skirt under every island blob
	for _, b in ipairs(SKY_BLOBS) do
		for i = 1, 4 do
			local a = RAD(i * 90 + rng:NextNumber(-20, 20))
			local rr = b[3] * 0.75
			ell(decor, V(b[3] * 0.9, b[3] * 0.35, b[3] * 0.9), V(b[1] + math.cos(a) * rr, y - 9, b[2] + math.sin(a) * rr), P.white)
		end
	end
	-- golden temple at the arrival
	patch(decor, 0, -530, 13, y + 0.05, s.gold)
	patch(decor, 0, -530, 11.6, y + 0.07, P.white)
	for i = 0, 5 do
		local a = RAD(i * 60 + 30)
		pillar(decor, g(math.cos(a) * 15, -530 + math.sin(a) * 15), 10)
	end
	signBoard(decor, g(0, -546) + V(0, 6, 0), g(0, -516) + V(0, 6, 0), "☁️ SKY ISLANDS  x120 COINS", 18, 2.8, P.sky)
	-- trees with blossom-blue leaves
	local skyLeaves: World.Leaves = { trunk = Color3.fromRGB(200, 170, 140), leaf1 = Color3.fromRGB(200, 230, 255), leaf2 = Color3.fromRGB(230, 245, 255), leaf3 = Color3.fromRGB(175, 215, 255) }
	local goldLeaves: World.Leaves = { trunk = Color3.fromRGB(200, 170, 140), leaf1 = Color3.fromRGB(255, 225, 130), leaf2 = Color3.fromRGB(255, 240, 170), leaf3 = Color3.fromRGB(255, 210, 110) }
	for i, p in ipairs({ { 108, -572 }, { -108, -572 }, { 104, -620 }, { -104, -620 }, { 30, -548 }, { -30, -548 }, { 64, -664 }, { -64, -664 } }) do
		World.treeTrio(decor, g(p[1], p[2]), i % 2 == 0 and skyLeaves or goldLeaves, 0.75)
	end
	-- floating islets and drifting hot air balloons
	for i, p in ipairs({ V(150, y + 26, -560), V(-150, y + 18, -620), V(130, y + 34, -690), V(-120, y + 30, -500), V(60, y + 46, -720) }) do
		islet(decor, p, 9 + (i % 2) * 3, i % 2 == 0 and skyLeaves or goldLeaves)
	end
	for _, p in ipairs({ V(70, y + 40, -520), V(-90, y + 52, -660), V(140, y + 60, -640), V(-150, y + 44, -540) }) do
		local b = BalloonArt.build(Config.Balloons.hotair, { size = 14 })
		b:PivotTo(CF(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
		b.Parent = decor
	end
	finalize(decor)
	for _, d in ipairs(decor:GetDescendants()) do
		if d:IsA("BasePart") and (d.Name == "Cylinder" or d.Name == "Trunk") then
			(d :: BasePart).CanCollide = true
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Zone 4: Space Rainbow
---------------------------------------------------------------------------------------------------------------

local SPACE_BLOBS = {
	{ 0, -826, 24 }, { 0, -892, 46 }, { 84, -890, 36 }, { -84, -890, 36 }, { 0, -956, 30 }, { 52, -944, 20 }, { -52, -944, 20 },
}

local function crystals(parent: Instance, pos: Vector3, scale: number)
	local cols = { P.space.cyan, P.space.pink, Config.Palette.lilac }
	for i = 1, 4 do
		local h = rng:NextNumber(3, 7) * scale
		local w = rng:NextNumber(1, 1.8) * scale
		local off = V(rng:NextNumber(-2.5, 2.5), 0, rng:NextNumber(-2.5, 2.5)) * scale
		World.box(parent, CF(pos + off + V(0, h * 0.4, 0)) * CFrame.Angles(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, 6.28), rng:NextNumber(-0.35, 0.35)), V(w, h, w), cols[i % #cols + 1], { Material = Enum.Material.Neon, Transparency = 0.1 })
	end
end

local function planet(parent: Instance, pos: Vector3, d: number, color: Color3, ring: Color3?, band: Color3?)
	World.ball(parent, pos, d, color)
	if band then
		World.cyl(parent, pos + V(0, d * 0.12, 0), d * 0.1, d * 1.005, band)
		World.cyl(parent, pos - V(0, d * 0.22, 0), d * 0.07, d * 0.92, band)
	end
	if ring then
		World.part({ Name = "Ring", Shape = Enum.PartType.Cylinder, Size = V(d * 0.03, d * 2, d * 2), CFrame = CF(pos) * CFrame.Angles(RAD(-16), 0, RAD(10)) * CFrame.Angles(0, 0, RAD(90)), Color = ring, Transparency = 0.15, Parent = parent })
	end
end

local function buildSpace(zm: Model)
	local s = P.space
	local y = Config.Zones[4].groundY
	local top, topVar = tex("StarDust", s.ground)
	island(zm, SPACE_BLOBS, y, { top = top, topVar = topVar, rim = s.cyan, band = s.under, under = s.underDark, rimNeon = true })
	local decor = World.folder("Decor", zm)
	local function g(x: number, z: number): Vector3
		return V(x, y, z)
	end
	-- rainbow road from the arrival to the centre
	local road = World.folder("RainbowRoad", zm)
	for i, col in ipairs(P.rainbow) do
		local off = (i - 3.5) * 1.6
		World.box(road, CF(off, y + 0.1, -840), V(1.6, 0.2, 52), col)
		World.box(road, CF(off, y + 0.1, -940), V(1.6, 0.2, 40), col)
	end
	finalize(road, true)
	-- landmark: a giant ringed planet behind the zone, plus smaller ones around
	planet(decor, V(0, y + 120, -1080), 120, Color3.fromRGB(255, 150, 200), Color3.fromRGB(255, 230, 160), Color3.fromRGB(255, 120, 180))
	planet(decor, V(-220, y + 70, -880), 44, Color3.fromRGB(110, 200, 255), nil, Color3.fromRGB(80, 160, 240))
	planet(decor, V(230, y + 100, -800), 30, Color3.fromRGB(255, 210, 90), Color3.fromRGB(255, 255, 255), nil)
	planet(decor, V(150, y + 40, -1000), 18, Color3.fromRGB(160, 255, 190), nil, nil)
	-- crystal clusters around the edges
	for _, p in ipairs({ { 22, -818 }, { -22, -818 }, { 112, -870 }, { -112, -870 }, { 106, -918 }, { -106, -918 }, { 36, -972 }, { -36, -972 }, { 60, -856 }, { -60, -856 } }) do
		crystals(decor, g(p[1], p[2]), rng:NextNumber(0.9, 1.4))
	end
	-- neon lamps and moon rocks
	lampRow(decor, { g(7, -834), g(-7, -834), g(7, -852), g(-7, -852), g(7, -926), g(-7, -926) }, s.groundDark, s.cyan)
	for _, p in ipairs({ { 120, -895 }, { -120, -895 }, { 70, -930 }, { -70, -930 } }) do
		World.rocks(decor, g(p[1], p[2]), { rock = Color3.fromRGB(150, 140, 190), rockDark = Color3.fromRGB(110, 100, 150) }, rng, 1)
	end
	signBoard(decor, g(0, -840) + V(0, 6, 0), g(0, -810) + V(0, 6, 0), "🌈 SPACE RAINBOW  x1000 COINS", 20, 2.8, Color3.fromRGB(120, 70, 220))
	-- star field
	for _ = 1, 70 do
		local p = V(rng:NextNumber(-260, 260), y + rng:NextNumber(30, 220), -890 + rng:NextNumber(-260, 220))
		if math.abs(p.X) > 40 or p.Y > y + 60 then
			World.ball(decor, p, rng:NextNumber(0.6, 1.6), s.star, { Material = Enum.Material.Neon, CanCollide = false })
		end
	end
	finalize(decor)
end

---------------------------------------------------------------------------------------------------------------
-- Clouds: puffy sky clouds everywhere and a cloud sea under each zone
---------------------------------------------------------------------------------------------------------------

local function buildClouds(parent: Instance)
	local f = World.folder("Clouds", parent)
	for i, z in ipairs(Config.Zones) do
		-- cloud sea below the island
		for _ = 1, 11 do
			local p = z.center + V(rng:NextNumber(-150, 150), -72 + rng:NextNumber(-6, 6), rng:NextNumber(-130, 130))
			ell(f, V(rng:NextNumber(60, 95), rng:NextNumber(14, 22), rng:NextNumber(60, 95)), V(p.X, z.groundY - 72 + rng:NextNumber(-6, 6), p.Z), i == 4 and Color3.fromRGB(205, 190, 255) or P.white)
		end
		-- sky clouds around and above
		for _ = 1, 9 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(150, 260)
			local p = V(math.cos(a) * r, z.groundY + rng:NextNumber(25, 90), z.center.Z + math.sin(a) * r * 0.7)
			World.cloud(f, p, rng:NextNumber(1.1, 2.2), rng, i == 4 and Color3.fromRGB(225, 215, 255) or nil)
		end
	end
	-- a few clouds right around the hub and along the way, for depth from the spawn
	for _, p in ipairs({ V(-90, 46, 60), V(110, 52, -40), V(-70, 60, -160), V(80, 70, -200), V(-60, 96, -440), V(90, 110, -470), V(0, 150, -700) }) do
		World.cloud(f, p, 1.4, rng)
	end
	finalize(f)
end

---------------------------------------------------------------------------------------------------------------

function Map.build(): Folder
	local root = World.folder("Map", workspace)
	Map.root = root
	local zones = {}
	for i, z in ipairs(Config.Zones) do
		local m = World.model("Zone_" .. z.key, root)
		persistent(m)
		zones[i] = m
	end
	buildMeadow(zones[1])
	buildCandy(zones[2])
	buildSky(zones[3])
	buildSpace(zones[4])

	local links = World.model("Bridges", root)
	persistent(links)
	local styles: { BridgeStyle } = {
		{ strips = { P.rainbow[1], P.rainbow[2], P.rainbow[3], P.rainbow[4], P.rainbow[5], P.rainbow[6] }, rail = P.white, under = P.meadow.dirt, balloons = { P.pink, P.yellow, P.sky } },
		{ strips = { P.white, P.candy.ground, P.white, P.candy.ground, P.white }, rail = P.candy.mint, under = P.candy.choc, balloons = { P.sky, P.white, P.yellow } },
		{ strips = { P.space.groundDark, P.space.ground, P.space.groundDark }, rail = P.space.cyan, under = P.space.under, balloons = { P.space.pink, P.space.cyan, P.yellow }, neonEdge = P.space.cyan },
	}
	for i, b in ipairs(Config.Bridges) do
		bridge(links, b.from, b.to, b.width, styles[i])
	end
	for i = 2, #Config.Zones do
		gate(links, i)
	end
	local sky = World.model("Sky", root)
	persistent(sky)
	buildClouds(sky)
	return root
end

-- Ground spawn point for teleports into a zone (on the arrival plaza / the Meadow spawn).
function Map.zoneSpawn(i: number): CFrame
	local z = Config.Zones[math.clamp(i, 1, #Config.Zones)]
	local pos = z.spawn + V(0, 3.5, 0)
	return CFrame.lookAt(pos, V(z.look.X, pos.Y, z.look.Z))
end

return Map

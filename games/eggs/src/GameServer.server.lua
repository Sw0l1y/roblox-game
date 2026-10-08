-- ServerScriptService.GameServer ("Steal a Dragon Egg")
-- Loop: buy eggs off the conveyor -> they earn cash in your base -> collect -> buy rarer eggs.
-- Steal other players' eggs (hold E) and run them back to your base; owners can tag you to get them back.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local store = DataStoreService:GetDataStore("EggData_v1")

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local FxRE = Instance.new("RemoteEvent")
FxRE.Name = "Fx"
FxRE.Parent = remotes
local ActionRE = Instance.new("RemoteEvent")
ActionRE.Name = "Action"
ActionRE.Parent = remotes

local function fx(player, ...)
	FxRE:FireClient(player, ...)
end
local function announce(text, color)
	FxRE:FireAllClients("Announce", text, color or Color3.fromRGB(255, 230, 80))
end

---------------------------------------------------------------------------
-- Lighting
---------------------------------------------------------------------------
Lighting.ClockTime = 14
Lighting.Brightness = 2.6
Lighting.Ambient = Color3.fromRGB(110, 100, 130)
Lighting.OutdoorAmbient = Color3.fromRGB(165, 160, 195)
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 0.6
local atmo = Instance.new("Atmosphere")
atmo.Density = 0.3
atmo.Offset = 0.1
atmo.Color = Color3.fromRGB(205, 225, 255)
atmo.Decay = Color3.fromRGB(150, 170, 230)
atmo.Glare = 0.3
atmo.Haze = 1.2
atmo.Parent = Lighting
local rays = Instance.new("SunRaysEffect")
rays.Intensity = 0.06
rays.Spread = 0.6
rays.Parent = Lighting
local clouds = Instance.new("Clouds")
clouds.Cover = 0.55
clouds.Density = 0.6
clouds.Color = Color3.fromRGB(255, 255, 255)
clouds.Parent = workspace.Terrain
local cc = Instance.new("ColorCorrectionEffect")
cc.Saturation = 0.25
cc.Contrast = 0.08
cc.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.5
bloom.Threshold = 1.6
bloom.Parent = Lighting

---------------------------------------------------------------------------
-- Building helpers
---------------------------------------------------------------------------
local world = Instance.new("Folder")
world.Name = "World"
world.Parent = workspace

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		if k ~= "Parent" then
			p[k] = v
		end
	end
	p.Parent = props.Parent or world
	return p
end

local function billboard(adornee, lines, offsetY, width, height)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(width or 200, height or 70)
	bb.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 120
	bb.Parent = adornee
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = bb
	local labels = {}
	for i, line in ipairs(lines) do
		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(1, 0, 1 / #lines, 0)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = line.Color or Color3.new(1, 1, 1)
		t.TextStrokeTransparency = 0
		t.Text = line.Text
		t.LayoutOrder = i
		t.Parent = bb
		labels[i] = t
	end
	return labels, bb
end

local rarityIndex = {}
for i, r in ipairs(Config.Rarities) do
	rarityIndex[r.Name] = i
end

-- Stylized look: flat SmoothPlastic colors, no stock material textures, toon outlines via Highlight.
local PALETTE = {
	Grass = Color3.fromRGB(118, 214, 96),
	Grass2 = Color3.fromRGB(98, 196, 84),
	Grass3 = Color3.fromRGB(140, 226, 110),
	Sand = Color3.fromRGB(246, 226, 172),
	Stone = Color3.fromRGB(196, 200, 216),
	StoneDark = Color3.fromRGB(132, 138, 160),
	Wood = Color3.fromRGB(176, 116, 66),
	WoodDark = Color3.fromRGB(118, 74, 44),
	Straw = Color3.fromRGB(240, 200, 100),
	Belt = Color3.fromRGB(58, 56, 74),
	Gold = Color3.fromRGB(255, 204, 64),
	Outline = Color3.fromRGB(34, 26, 46),
}
local ACCENTS = {
	Color3.fromRGB(255, 99, 132), Color3.fromRGB(255, 159, 64), Color3.fromRGB(255, 205, 86),
	Color3.fromRGB(75, 192, 120), Color3.fromRGB(54, 162, 235), Color3.fromRGB(153, 102, 255),
	Color3.fromRGB(255, 120, 200), Color3.fromRGB(80, 220, 220), Color3.fromRGB(240, 110, 80),
	Color3.fromRGB(150, 220, 80), Color3.fromRGB(110, 130, 255), Color3.fromRGB(200, 90, 220),
}

local function group(name, outlined)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = world
	if outlined then
		local h = Instance.new("Highlight")
		h.FillTransparency = 1
		h.OutlineColor = PALETTE.Outline
		h.OutlineTransparency = 0.15
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = m
	end
	return m
end

local function ellipsoid(size, cf, color, parent, props)
	local p = part({ Size = size, CFrame = cf, Color = color, Parent = parent })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return p
end

-- upright cylinder: base sits at pos.Y
local function cyl(pos, height, diameter, color, parent, props)
	local p = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Parent = parent })
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return p
end

local rng = Random.new(7)
local decor = group("Decor", true)
local groundGroup = group("Ground", false)

local function tree(pos, s)
	cyl(pos, 7 * s, 1.6 * s, PALETTE.WoodDark, decor)
	local greens = { PALETTE.Grass2, PALETTE.Grass, Color3.fromRGB(80, 170, 70) }
	ellipsoid(Vector3.new(9, 7, 9) * s, CFrame.new(pos + Vector3.new(0, 8 * s, 0)), greens[rng:NextInteger(1, 3)], decor)
	ellipsoid(Vector3.new(6, 5, 6) * s, CFrame.new(pos + Vector3.new(1.5 * s, 11 * s, 0.5 * s)), greens[rng:NextInteger(1, 3)], decor)
	ellipsoid(Vector3.new(5, 4, 5) * s, CFrame.new(pos + Vector3.new(-1.8 * s, 10 * s, -1 * s)), greens[rng:NextInteger(1, 3)], decor)
end

local function rock(pos, s)
	ellipsoid(Vector3.new(6, 3.5, 5) * s, CFrame.new(pos + Vector3.new(0, 1 * s, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0),
		PALETTE.StoneDark, decor)
	ellipsoid(Vector3.new(3.5, 2.5, 3) * s, CFrame.new(pos + Vector3.new(2 * s, 0.8 * s, 1 * s)), PALETTE.Stone, decor)
end

local function bush(pos, s)
	ellipsoid(Vector3.new(5, 3.2, 4.5) * s, CFrame.new(pos + Vector3.new(0, 1.2 * s, 0)), PALETTE.Grass2, decor)
	for _ = 1, 3 do
		ellipsoid(Vector3.new(0.8, 0.8, 0.8) * s,
			CFrame.new(pos + Vector3.new(rng:NextNumber(-1.8, 1.8) * s, 2.4 * s, rng:NextNumber(-1.5, 1.5) * s)),
			Color3.fromHSV(rng:NextNumber(), 0.55, 1), decor)
	end
end

-- Ground + soft color patches + rolling hills around the edge
part({ Name = "Grass", Size = Vector3.new(700, 2, 400), Position = Vector3.new(0, -1, 0), Color = PALETTE.Grass, Parent = groundGroup })
for _ = 1, 40 do
	local d = rng:NextNumber(14, 40)
	cyl(Vector3.new(rng:NextNumber(-320, 320), 0, rng:NextNumber(-180, 180)), 0.05, d,
		rng:NextNumber() < 0.5 and PALETTE.Grass2 or PALETTE.Grass3, groundGroup, { CanCollide = false })
end
for i = 0, 47 do
	local a = i / 48 * math.pi * 2
	local r = 300 + rng:NextNumber(0, 40)
	local pos = Vector3.new(math.cos(a) * r * 1.15, -6, math.sin(a) * r * 0.62)
	local s = rng:NextNumber(50, 90)
	ellipsoid(Vector3.new(s, s * rng:NextNumber(0.5, 0.8), s), CFrame.new(pos),
		(i % 2 == 0) and PALETTE.Grass2 or PALETTE.Grass3, decor)
end
for _ = 1, 70 do
	local x, z = rng:NextNumber(-300, 300), rng:NextNumber(-170, 170)
	local inPlots = math.abs(z) > 10 and math.abs(z) < 84 and math.abs(x) < 244
	if not inPlots and math.abs(z) > 12 then
		local r = rng:NextNumber()
		local pos = Vector3.new(x, 0, z)
		if r < 0.5 then
			tree(pos, rng:NextNumber(0.9, 1.6))
		elseif r < 0.75 then
			bush(pos, rng:NextNumber(0.8, 1.3))
		else
			rock(pos, rng:NextNumber(0.7, 1.5))
		end
	end
end

-- Conveyor belt with moving chevrons (animated by the client), hatchery at the start, portal at the end
local LANE_X = 250
local conveyor = group("Conveyor", true)
part({ Name = "Belt", Size = Vector3.new(LANE_X * 2, 0.6, 12), Position = Vector3.new(0, 0.3, 0), Color = PALETTE.Belt, Parent = conveyor })
for _, z in ipairs({ -6.5, 6.5 }) do
	part({ Size = Vector3.new(LANE_X * 2, 1.4, 1), Position = Vector3.new(0, 0.7, z), Color = PALETTE.Gold, Parent = conveyor })
end
local chevrons = Instance.new("Folder")
chevrons.Name = "Chevrons"
chevrons.Parent = world
for x = -LANE_X, LANE_X - 1, 12 do
	for _, dz in ipairs({ -1, 1 }) do
		part({ Name = "Chevron", Size = Vector3.new(0.8, 0.1, 6), CFrame = CFrame.new(x, 0.65, dz * 2.6) * CFrame.Angles(0, math.rad(-dz * 40), 0),
			Color = Color3.fromRGB(110, 106, 140), CanCollide = false, CanQuery = false, Parent = chevrons })
	end
end
-- hatchery
local hx = -LANE_X - 8
part({ Size = Vector3.new(4, 18, 4), Position = Vector3.new(hx, 9, -9), Color = PALETTE.Stone, Parent = conveyor })
part({ Size = Vector3.new(4, 18, 4), Position = Vector3.new(hx, 9, 9), Color = PALETTE.Stone, Parent = conveyor })
part({ Size = Vector3.new(16, 6, 24), Position = Vector3.new(hx - 4, 21, 0), Color = PALETTE.Wood, Parent = conveyor })
part({ Size = Vector3.new(18, 1.2, 26), Position = Vector3.new(hx - 4, 24.6, 0), Color = PALETTE.WoodDark, Parent = conveyor })
part({ Size = Vector3.new(14, 18, 22), Position = Vector3.new(hx - 10, 9, 0), Color = PALETTE.Stone, Parent = conveyor })
ellipsoid(Vector3.new(7, 9, 7), CFrame.new(hx - 4, 30, 0), Color3.fromRGB(255, 235, 200), conveyor)
local hatchSign = part({ Size = Vector3.new(1, 1, 1), Position = Vector3.new(hx, 30, 0), Transparency = 1, CanCollide = false, Parent = conveyor })
billboard(hatchSign, { { Text = "🥚 EGG HATCHERY 🥚", Color = PALETTE.Gold } }, 6, 320, 46)
-- exit portal
for i = 0, 15 do
	local a = i / 16 * math.pi * 2
	part({ Size = Vector3.new(1.5, 3, 3), CFrame = CFrame.new(LANE_X + 4, 9 + math.sin(a) * 8, math.cos(a) * 8) * CFrame.Angles(a, 0, 0),
		Color = Color3.fromRGB(170, 90, 255), Material = Enum.Material.Neon, Parent = conveyor })
end
local portalFill = part({ Size = Vector3.new(0.4, 15, 15), Position = Vector3.new(LANE_X + 4, 9, 0), Color = Color3.fromRGB(120, 60, 220),
	Material = Enum.Material.Neon, Transparency = 0.4, CanCollide = false, Parent = conveyor })
local portalMesh = Instance.new("SpecialMesh")
portalMesh.MeshType = Enum.MeshType.Sphere
portalMesh.Parent = portalFill

local spawnLoc = Instance.new("SpawnLocation")
spawnLoc.Anchored = true
spawnLoc.Size = Vector3.new(8, 0.4, 8)
spawnLoc.Position = Vector3.new(0, 0.2, 0)
spawnLoc.Transparency = 1
spawnLoc.CanCollide = false
spawnLoc.Duration = 0
spawnLoc.Parent = world

-- Eggs: smooth ellipsoids with spots, outlined in their own group
local eggGroup = group("Eggs", true)

local function makeEgg(def, withPrice)
	local ri = rarityIndex[def.Rarity] or 1
	local rarity = Config.Rarities[ri]
	local s = 1 + (ri - 1) * 0.15
	local egg = Instance.new("Part")
	egg.Name = "Egg"
	egg.Size = Vector3.new(3, 4, 3) * s
	egg.Color = def.Color
	egg.Material = Enum.Material.SmoothPlastic
	egg.Anchored = true
	egg.CanCollide = false
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg
	-- spots
	if ri >= 2 then
		local spotColor = ri >= 6 and rarity.Color or Color3.new(def.Color.R * 0.7, def.Color.G * 0.7, def.Color.B * 0.7)
		local srng = Random.new(#def.Name * 31)
		for _ = 1, 3 + ri do
			local theta = srng:NextNumber(0.5, 2.6)
			local phi = srng:NextNumber(0, math.pi * 2)
			local dir = Vector3.new(math.sin(theta) * math.cos(phi) * 1.5, math.cos(theta) * 2, math.sin(theta) * math.sin(phi) * 1.5) * s * 0.93
			local d = srng:NextNumber(0.6, 1.1) * s
			local spot = Instance.new("Part")
			spot.Size = Vector3.new(d, d, d * 0.5)
			spot.CFrame = CFrame.lookAt(dir, dir * 2)
			spot.Color = spotColor
			spot.Material = ri >= 6 and Enum.Material.Neon or Enum.Material.SmoothPlastic
			spot.CanCollide = false
			spot.CanQuery = false
			spot.CanTouch = false
			spot.Massless = true
			local sm = Instance.new("SpecialMesh")
			sm.MeshType = Enum.MeshType.Sphere
			sm.Parent = spot
			local w = Instance.new("WeldConstraint")
			w.Part0 = egg
			w.Part1 = spot
			w.Parent = spot
			spot.Parent = egg
		end
	end
	if ri >= 4 then
		local aura = Instance.new("ParticleEmitter")
		aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		aura.Color = ColorSequence.new(rarity.Color)
		aura.LightEmission = 1
		aura.Size = NumberSequence.new(0.6, 0)
		aura.Lifetime = NumberRange.new(0.6, 1.2)
		aura.Rate = 4 + (ri - 4) * 6
		aura.Speed = NumberRange.new(1, 3)
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Parent = egg
	end
	if ri >= 6 then
		local light = Instance.new("PointLight")
		light.Color = rarity.Color
		light.Range = 14
		light.Brightness = 2
		light.Parent = egg
	end
	local lines = {
		{ Text = def.Name, Color = Color3.new(1, 1, 1) },
		{ Text = def.Rarity, Color = ri == 7 and Color3.fromRGB(255, 255, 255) or rarity.Color },
		{ Text = "$" .. Config.Format(def.Income) .. "/s", Color = Color3.fromRGB(120, 255, 120) },
	}
	if withPrice then
		lines[4] = { Text = "$" .. Config.Format(def.Price), Color = Color3.fromRGB(255, 230, 80) }
	end
	billboard(egg, lines, 2 + 2 * s, 170, withPrice and 90 or 70)
	egg:SetAttribute("EggName", def.Name)
	return egg
end

-- Bases: raised stone platform, wood fence, corner towers in the base's accent color, nests for eggs
local plots = {}
local PLOT_XS = { -200, -120, -40, 40, 120, 200 }
local function slotOffset(slot)
	local row = slot <= 6 and 0 or 1
	local col = (slot - 1) % 6
	return Vector3.new(-25 + col * 10, 0, 48 + row * 14)
end

for i = 1, 12 do
	local side = i <= 6 and 1 or -1
	local x = PLOT_XS[(i - 1) % 6 + 1]
	local accent = ACCENTS[i]
	local model = group("Base" .. i, true)
	local plot = { Index = i, X = x, Side = side, Slots = {}, EggParts = {}, Model = model }
	local function at(v) -- local plot coords (z grows away from the lane) -> world
		return Vector3.new(x + v.X, v.Y, side * v.Z)
	end
	plot.At = at
	part({ Name = "Platform", Size = Vector3.new(66, 1, 54), Position = at(Vector3.new(0, 0.5, 46)), Color = PALETTE.Stone, Parent = model })
	part({ Name = "Floor", Size = Vector3.new(60, 0.2, 48), Position = at(Vector3.new(0, 1.1, 47)),
		Color = accent:Lerp(Color3.new(1, 1, 1), 0.72), Parent = model })
	-- path strip to the nests
	part({ Size = Vector3.new(8, 0.25, 26), Position = at(Vector3.new(0, 1.15, 33)), Color = PALETTE.Sand, Parent = model })
	-- fence: posts + two rails on back and sides
	local function fenceLine(a, b, n)
		for k = 0, n do
			local pos = a:Lerp(b, k / n)
			part({ Size = Vector3.new(1.2, 5, 1.2), Position = pos + Vector3.new(0, 3.5, 0), Color = PALETTE.Wood, Parent = model })
		end
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		for _, h in ipairs({ 2.6, 4.6 }) do
			part({ Size = Vector3.new(0.6, 0.6, len), CFrame = CFrame.lookAt(mid + Vector3.new(0, h, 0), b + Vector3.new(0, h, 0)),
				Color = PALETTE.WoodDark, Parent = model })
		end
	end
	fenceLine(at(Vector3.new(-32, 1, 72)), at(Vector3.new(32, 1, 72)), 8)
	fenceLine(at(Vector3.new(-32, 1, 22)), at(Vector3.new(-32, 1, 72)), 6)
	fenceLine(at(Vector3.new(32, 1, 22)), at(Vector3.new(32, 1, 72)), 6)
	-- front towers with accent roofs and flags
	for _, tx in ipairs({ -32, 32 }) do
		local base = at(Vector3.new(tx, 1, 21))
		part({ Size = Vector3.new(5, 12, 5), Position = base + Vector3.new(0, 6, 0), Color = PALETTE.Stone, Parent = model })
		part({ Size = Vector3.new(6, 1, 6), Position = base + Vector3.new(0, 12.5, 0), Color = PALETTE.StoneDark, Parent = model })
		for k = 0, 3 do
			cyl(base + Vector3.new(0, 13 + k * 1.4, 0), 1.4, 6 - k * 1.5, accent, model)
		end
		part({ Size = Vector3.new(0.4, 6, 0.4), Position = base + Vector3.new(0, 21, 0), Color = PALETTE.WoodDark, Parent = model })
		part({ Size = Vector3.new(0.3, 2.4, 3.6), Position = base + Vector3.new(0, 22.6, 1.8), Color = accent, Parent = model })
	end
	plot.Door = part({ Name = "LaserDoor", Size = Vector3.new(59, 10, 0.6), Position = at(Vector3.new(0, 6, 21)),
		Color = Color3.fromRGB(255, 50, 80), Material = Enum.Material.ForceField, Transparency = 1, CanCollide = false, Parent = model })
	-- nests
	for slot = 1, Config.BaseSlots + Config.ExtraSlots do
		local c = at(slotOffset(slot) + Vector3.new(0, 1.2, 0))
		local ped = cyl(c, 1, 6.4, PALETTE.WoodDark, model, { Name = "Pedestal" })
		cyl(c + Vector3.new(0, 0.6, 0), 0.6, 6.8, PALETTE.Straw, model, { CanCollide = false })
		cyl(c + Vector3.new(0, 0.7, 0), 0.6, 4.6, Color3.fromRGB(196, 150, 80), model, { CanCollide = false })
		if slot > Config.BaseSlots then
			ped.Transparency = 0.6
			billboard(ped, { { Text = "🔒 +4 Slots", Color = Color3.fromRGB(255, 230, 80) } }, 2, 120, 30)
		end
		plot.Slots[slot] = ped
	end
	-- round pads
	plot.CollectPad = cyl(at(Vector3.new(22, 1, 30)), 0.5, 9, Color3.fromRGB(70, 220, 100), model, { Name = "CollectPad" })
	cyl(at(Vector3.new(22, 1, 30)), 0.4, 10.4, Color3.fromRGB(40, 150, 70), model, { CanCollide = false })
	plot.CollectLabel = billboard(plot.CollectPad, { { Text = "💰 COLLECT" }, { Text = "$0", Color = Color3.fromRGB(120, 255, 120) } }, 4, 160, 60)
	plot.LockPad = cyl(at(Vector3.new(-22, 1, 30)), 0.5, 9, Color3.fromRGB(80, 150, 255), model, { Name = "LockPad" })
	cyl(at(Vector3.new(-22, 1, 30)), 0.4, 10.4, Color3.fromRGB(40, 90, 180), model, { CanCollide = false })
	plot.LockLabel = billboard(plot.LockPad, { { Text = "🔒 LOCK BASE" } }, 4, 170, 34)
	-- owner sign board at the back, facing the lane
	local boardPos = at(Vector3.new(0, 12, 73))
	local board = part({ Size = Vector3.new(26, 7, 1), CFrame = CFrame.lookAt(boardPos, boardPos + Vector3.new(0, 0, -side)),
		Color = PALETTE.Wood, Parent = model })
	for _, bx in ipairs({ -11, 11 }) do
		part({ Size = Vector3.new(1.2, 10, 1.2), CFrame = board.CFrame * CFrame.new(bx, -5, 0.8), Color = PALETTE.WoodDark, Parent = model })
	end
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(520, 140)
	sg.LightInfluence = 0.2
	sg.Parent = board
	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.fromScale(1, 1)
	signText.BackgroundColor3 = accent
	signText.Font = Enum.Font.FredokaOne
	signText.TextScaled = true
	signText.TextColor3 = Color3.new(1, 1, 1)
	signText.TextStrokeTransparency = 0
	signText.Text = "Empty Base"
	signText.Parent = sg
	local signStroke = Instance.new("UIStroke")
	signStroke.Thickness = 6
	signStroke.Color = PALETTE.WoodDark
	signStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	signStroke.Parent = signText
	plot.SignLabel = { signText }
	plots[i] = plot
end

---------------------------------------------------------------------------
-- Player state
---------------------------------------------------------------------------
local S = {} -- player -> state
local workspaceLuck = 0 -- os.time() until server luck ends

local function hasPass(player, key)
	return player:GetAttribute("Pass_" .. key) == true
end

local function maxSlots(player)
	return Config.BaseSlots + (hasPass(player, "ExtraSlots") and Config.ExtraSlots or 0)
end

local function setCash(player, value)
	local s = S[player]
	s.Cash = value
	player:SetAttribute("Cash", value)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Cash.Value = value
	end
end

local function syncDiscovered(player)
	local names = {}
	for name in pairs(S[player].Discovered) do
		names[#names + 1] = name
	end
	player:SetAttribute("Discovered", table.concat(names, "|"))
end

local function incomeOf(player)
	local s = S[player]
	local total = 0
	for _, name in pairs(s.Eggs) do
		local def = Config.EggByName(name)
		if def then
			total += def.Income
		end
	end
	total *= Config.RebirthMult(s.Rebirths)
	if hasPass(player, "DoubleCash") then
		total *= 2
	end
	if hasPass(player, "VIP") then
		total *= 1.25
	end
	return total
end

local stealPrompt, sellPrompt -- forward declared

local function placeEgg(player, slot, name)
	local s = S[player]
	local plot = plots[s.Plot]
	local def = Config.EggByName(name)
	if not def then
		return
	end
	s.Eggs[slot] = name
	local egg = makeEgg(def, false)
	local ped = plot.Slots[slot]
	egg.CFrame = CFrame.new(ped.Position + Vector3.new(0, 0.5 + egg.Size.Y / 2, 0))
	egg:SetAttribute("OwnerId", player.UserId)
	egg:SetAttribute("Slot", slot)
	stealPrompt(egg)
	sellPrompt(egg, def)
	egg.Parent = eggGroup
	plot.EggParts[slot] = egg
	-- little spin so it looks alive
	TweenService:Create(egg, TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{ CFrame = egg.CFrame * CFrame.Angles(0, math.pi, 0) }):Play()
	if not s.Discovered[name] then
		s.Discovered[name] = true
		syncDiscovered(player)
	end
	player:SetAttribute("Income", incomeOf(player))
end

local function removeEgg(player, slot)
	local s = S[player]
	local plot = plots[s.Plot]
	s.Eggs[slot] = nil
	if plot.EggParts[slot] then
		plot.EggParts[slot]:Destroy()
		plot.EggParts[slot] = nil
	end
	player:SetAttribute("Income", incomeOf(player))
end

local function freeSlot(player)
	local s = S[player]
	for slot = 1, maxSlots(player) do
		if not s.Eggs[slot] then
			return slot
		end
	end
	return nil
end

local function refreshSlotLocks(player)
	local s = S[player]
	if not s or not s.Plot then
		return
	end
	local unlocked = hasPass(player, "ExtraSlots")
	for slot = Config.BaseSlots + 1, Config.BaseSlots + Config.ExtraSlots do
		local ped = plots[s.Plot].Slots[slot]
		ped.Transparency = unlocked and 0 or 0.6
		local bb = ped:FindFirstChildOfClass("BillboardGui")
		if bb then
			bb.Enabled = not unlocked
		end
	end
end

local function refreshPasses(player)
	for _, gp in ipairs(Config.GamePasses) do
		if gp.Id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, gp.Id)
			player:SetAttribute("Pass_" .. gp.Key, ok and owns or false)
		end
	end
	refreshSlotLocks(player)
	if S[player] then
		player:SetAttribute("Income", incomeOf(player))
	end
end

local function baseSpeed(player)
	return hasPass(player, "Speed") and 28 or 18
end

---------------------------------------------------------------------------
-- Stealing
---------------------------------------------------------------------------
local function isLocked(player)
	local s = S[player]
	return s and s.LockedUntil > os.time()
end

local function dropCarry(thief)
	local s = S[thief]
	local c = s and s.Carrying
	if not c then
		return nil
	end
	if c.Part then
		c.Part:Destroy()
	end
	s.Carrying = nil
	thief:SetAttribute("Carrying", "")
	local hum = thief.Character and thief.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = baseSpeed(thief)
	end
	return c
end

local function returnToVictim(thief, reason)
	local c = dropCarry(thief)
	if not c then
		return
	end
	local victim = c.Victim
	if victim.Parent and S[victim] and S[victim].Plot then
		local slot = (not S[victim].Eggs[c.Slot]) and c.Slot or freeSlot(victim)
		if slot then
			placeEgg(victim, slot, c.Name)
		end
		fx(victim, "Retrieved", c.Name)
	end
	fx(thief, "Toast", reason or "You dropped the egg!")
end

function stealPrompt(egg)
	local p = Instance.new("ProximityPrompt")
	p.Name = "Steal"
	p.ActionText = "Steal"
	p.ObjectText = egg:GetAttribute("EggName")
	p.HoldDuration = 1.5
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.Parent = egg
	p.Triggered:Connect(function(thief)
		local ts = S[thief]
		local victim = Players:GetPlayerByUserId(egg:GetAttribute("OwnerId"))
		if not ts or not ts.Plot or not victim or victim == thief or not S[victim] or not egg.Parent then
			return
		end
		if ts.Carrying then
			fx(thief, "Toast", "You're already carrying an egg!")
			return
		end
		if isLocked(victim) then
			fx(thief, "Toast", "That base is LOCKED!")
			return
		end
		local slot = egg:GetAttribute("Slot")
		local name = egg:GetAttribute("EggName")
		removeEgg(victim, slot)
		local char = thief.Character
		local head = char and char:FindFirstChild("Head")
		if not head then
			placeEgg(victim, slot, name)
			return
		end
		local carried = makeEgg(Config.EggByName(name), false)
		carried.Anchored = false
		carried.Massless = true
		carried.CFrame = head.CFrame * CFrame.new(0, 3.5, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = carried
		weld.Parent = carried
		carried.Parent = char
		ts.Carrying = { Name = name, Victim = victim, Slot = slot, Part = carried }
		thief:SetAttribute("Carrying", name)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = baseSpeed(thief) * 0.75
		end
		fx(thief, "StealStart", name)
		fx(victim, "Stolen", thief.DisplayName, name)
	end)
end

function sellPrompt(egg, def)
	local p = Instance.new("ProximityPrompt")
	p.Name = "Sell"
	p.ActionText = "Sell $" .. Config.Format(def.Price / 2)
	p.ObjectText = def.Name
	p.HoldDuration = 0.8
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.F
	p.Parent = egg
	p.Triggered:Connect(function(player)
		if egg:GetAttribute("OwnerId") ~= player.UserId or not egg.Parent then
			return
		end
		local s = S[player]
		removeEgg(player, egg:GetAttribute("Slot"))
		setCash(player, s.Cash + math.floor(def.Price / 2))
		fx(player, "Collect", math.floor(def.Price / 2))
	end)
end

local function inOwnBase(player, pos)
	local s = S[player]
	local plot = s and s.Plot and plots[s.Plot]
	if not plot then
		return false
	end
	local dz = pos.Z * plot.Side
	return math.abs(pos.X - plot.X) <= 32 and dz >= 20 and dz <= 72
end

task.spawn(function()
	while true do
		task.wait(0.2)
		for thief, s in pairs(S) do
			local c = s.Carrying
			if c then
				local char = thief.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if not root or not hum or hum.Health <= 0 then
					returnToVictim(thief, "You got knocked out and lost the egg!")
				else
					local vChar = c.Victim.Character
					local vRoot = vChar and vChar:FindFirstChild("HumanoidRootPart")
					if vRoot and (vRoot.Position - root.Position).Magnitude <= Config.RetrieveDistance then
						returnToVictim(thief, c.Victim.DisplayName .. " caught you!")
					elseif inOwnBase(thief, root.Position) then
						dropCarry(thief)
						local slot = freeSlot(thief)
						if slot then
							placeEgg(thief, slot, c.Name)
							fx(thief, "StealSuccess", c.Name)
						else
							local def = Config.EggByName(c.Name)
							setCash(thief, s.Cash + def.Price)
							fx(thief, "Toast", "Base full! Sold " .. c.Name .. " for $" .. Config.Format(def.Price))
						end
						local _, ri = Config.Rarity(Config.EggByName(c.Name).Rarity)
						if ri >= 4 then
							announce("🦹 " .. thief.DisplayName .. " stole a " .. c.Name .. " from " .. c.Victim.DisplayName .. "!",
								Config.Rarities[ri].Color)
						end
					end
				end
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Conveyor
---------------------------------------------------------------------------
local function rollEgg()
	local luck = workspaceLuck > os.time()
	local total = 0
	local weights = {}
	for i, r in ipairs(Config.Rarities) do
		local w = r.Weight * ((luck and i >= 4) and 3 or 1)
		weights[i] = w
		total += w
	end
	local roll = math.random() * total
	local ri = #Config.Rarities
	for i, w in ipairs(weights) do
		roll -= w
		if roll <= 0 then
			ri = i
			break
		end
	end
	local options = {}
	for _, e in ipairs(Config.Eggs) do
		if e.Rarity == Config.Rarities[ri].Name then
			options[#options + 1] = e
		end
	end
	return options[math.random(1, #options)], ri
end

local function spawnConveyorEgg()
	local def, ri = rollEgg()
	local egg = makeEgg(def, true)
	egg.CFrame = CFrame.new(-LANE_X, 0.6 + egg.Size.Y / 2, 0)
	local p = Instance.new("ProximityPrompt")
	p.Name = "Buy"
	p.ActionText = "Buy $" .. Config.Format(def.Price)
	p.ObjectText = def.Name .. " (" .. def.Rarity .. ")"
	p.HoldDuration = 0.25
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Parent = egg
	egg.Parent = eggGroup
	p.Triggered:Connect(function(player)
		local s = S[player]
		if not s or not s.Plot or not egg.Parent then
			return
		end
		if s.Cash < def.Price then
			fx(player, "Broke", def.Price)
			return
		end
		local slot = freeSlot(player)
		if not slot then
			fx(player, "Toast", "Your base is full! Sell an egg (hold F) or get +4 Slots.")
			return
		end
		egg:Destroy()
		setCash(player, s.Cash - def.Price)
		placeEgg(player, slot, def.Name)
		fx(player, "Bought", def.Name, def.Rarity)
	end)
	local tw = TweenService:Create(egg, TweenInfo.new(Config.ConveyorTime, Enum.EasingStyle.Linear),
		{ CFrame = CFrame.new(LANE_X, egg.CFrame.Y, 0) })
	tw:Play()
	tw.Completed:Connect(function()
		if egg.Parent then
			egg:Destroy()
		end
	end)
	if ri >= 5 then
		announce("✨ A " .. string.upper(def.Rarity) .. " " .. def.Name .. " is on the conveyor! ✨", Config.Rarities[ri].Color)
	end
end

task.spawn(function()
	while true do
		spawnConveyorEgg()
		task.wait(Config.SpawnInterval)
	end
end)

---------------------------------------------------------------------------
-- Income, collect pads, lock pads
---------------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(1)
		local now = os.time()
		for player, s in pairs(S) do
			if s.Plot then
				local plot = plots[s.Plot]
				s.Uncollected += incomeOf(player)
				plot.CollectLabel[2].Text = "$" .. Config.Format(s.Uncollected)
				local locked = s.LockedUntil > now
				plot.Door.CanCollide = locked
				plot.Door.Transparency = locked and 0.45 or 1
				if locked then
					plot.LockLabel[1].Text = "🔒 LOCKED " .. (s.LockedUntil - now) .. "s"
				elseif s.LockCdUntil > now then
					plot.LockLabel[1].Text = "⏳ READY IN " .. (s.LockCdUntil - now) .. "s"
				else
					plot.LockLabel[1].Text = "🔒 LOCK BASE"
				end
			end
		end
	end
end)

local touchDebounce = {}
local function onPad(plot, kind)
	return function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		local s = player and S[player]
		if not s or s.Plot ~= plot.Index then
			return
		end
		local key = player.UserId .. kind
		if touchDebounce[key] then
			return
		end
		touchDebounce[key] = true
		task.delay(0.5, function()
			touchDebounce[key] = nil
		end)
		if kind == "Collect" then
			local amount = math.floor(s.Uncollected)
			if amount > 0 then
				s.Uncollected = 0
				setCash(player, s.Cash + amount)
				plot.CollectLabel[2].Text = "$0"
				fx(player, "Collect", amount)
			end
		else
			local now = os.time()
			if s.LockedUntil <= now and s.LockCdUntil <= now then
				s.LockedUntil = now + Config.LockTime
				s.LockCdUntil = s.LockedUntil + Config.LockCooldown
				player:SetAttribute("LockedUntil", s.LockedUntil)
				fx(player, "Locked", Config.LockTime)
			end
		end
	end
end
for _, plot in ipairs(plots) do
	plot.CollectPad.Touched:Connect(onPad(plot, "Collect"))
	plot.LockPad.Touched:Connect(onPad(plot, "Lock"))
end

---------------------------------------------------------------------------
-- Join / leave / save
---------------------------------------------------------------------------
local function save(player)
	local s = S[player]
	if not s or not s.Loaded then
		return
	end
	local eggs = {}
	for slot, name in pairs(s.Eggs) do
		eggs[tostring(slot)] = name
	end
	local carrying = s.Carrying -- a stolen egg in transit stays with the victim
	local data = { Cash = s.Cash, Rebirths = s.Rebirths, Eggs = eggs, Discovered = s.Discovered, LastDaily = s.LastDaily }
	local ok, err = pcall(function()
		store:SetAsync(tostring(player.UserId), data)
	end)
	if not ok then
		warn("Save failed for", player.Name, err)
	end
	return carrying
end

local function onCharacter(player, char)
	local s = S[player]
	local hum = char:WaitForChild("Humanoid")
	hum.WalkSpeed = baseSpeed(player)
	local root = char:WaitForChild("HumanoidRootPart")
	if s and s.Plot then
		task.wait()
		local plot = plots[s.Plot]
		char:PivotTo(CFrame.lookAt(plot.At(Vector3.new(0, 4, 36)), plot.At(Vector3.new(0, 4, 0))))
	end
	if hasPass(player, "VIP") then
		local head = char:WaitForChild("Head")
		local labels = billboard(head, { { Text = "👑 VIP", Color = Color3.fromRGB(255, 210, 50) } }, 2.5, 100, 26)
		labels[1].Parent.MaxDistance = 80
	end
	hum.Died:Connect(function()
		if s and s.Carrying then
			returnToVictim(player, "You got knocked out and lost the egg!")
		end
	end)
	local _ = root
end

Players.PlayerAdded:Connect(function(player)
	local plotIndex
	for i, plot in ipairs(plots) do
		if not plot.Owner then
			plotIndex = i
			plot.Owner = player
			break
		end
	end
	if not plotIndex then
		player:Kick("Server is full, please join another server!")
		return
	end
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = player
	local cashV = Instance.new("NumberValue")
	cashV.Name = "Cash"
	cashV.Parent = ls
	local rebV = Instance.new("NumberValue")
	rebV.Name = "Rebirths"
	rebV.Parent = ls

	local s = { Plot = plotIndex, Cash = 0, Rebirths = 0, Eggs = {}, Discovered = {}, LastDaily = 0,
		Uncollected = 0, LockedUntil = 0, LockCdUntil = 0, GiftAt = os.time() + Config.GiftInterval }
	S[player] = s
	local plot = plots[plotIndex]
	plot.SignLabel[1].Text = player.DisplayName .. "'s Base"
	player:SetAttribute("Plot", plotIndex)
	plot.Door:SetAttribute("OwnerId", player.UserId)

	local ok, data = pcall(function()
		return store:GetAsync(tostring(player.UserId))
	end)
	if not ok then
		player:Kick("Could not load your data, please rejoin.")
		return
	end
	refreshPasses(player)
	data = data or {}
	setCash(player, data.Cash or 50)
	s.Rebirths = data.Rebirths or 0
	rebV.Value = s.Rebirths
	player:SetAttribute("Rebirths", s.Rebirths)
	s.Discovered = data.Discovered or {}
	s.LastDaily = data.LastDaily or 0
	player:SetAttribute("LastDaily", s.LastDaily)
	player:SetAttribute("GiftAt", s.GiftAt)
	player:SetAttribute("Carrying", "")
	for slotStr, name in pairs(data.Eggs or {}) do
		local slot = tonumber(slotStr)
		if slot and slot <= maxSlots(player) then
			placeEgg(player, slot, name)
		end
	end
	syncDiscovered(player)
	player:SetAttribute("Income", incomeOf(player))
	s.Loaded = true

	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	if not data.Cash then
		fx(player, "Welcome")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local s = S[player]
	if not s then
		for _, plot in ipairs(plots) do
			if plot.Owner == player then
				plot.Owner = nil
			end
		end
		return
	end
	-- an egg this player was carrying goes back to its owner
	if s.Carrying then
		returnToVictim(player)
	end
	-- eggs stolen FROM this player and still in transit are lost to them; thieves keep running
	save(player)
	local plot = plots[s.Plot]
	for slot, egg in pairs(plot.EggParts) do
		egg:Destroy()
		plot.EggParts[slot] = nil
	end
	plot.Owner = nil
	plot.SignLabel[1].Text = "Empty Base"
	plot.CollectLabel[2].Text = "$0"
	plot.Door.CanCollide = false
	plot.Door.Transparency = 1
	plot.Door:SetAttribute("OwnerId", nil)
	S[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		save(player)
	end
end)

task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			save(player)
		end
	end
end)

---------------------------------------------------------------------------
-- Actions from the client: rebirth, gifts, daily, purchases
---------------------------------------------------------------------------
local function promptBuy(player, kind, key)
	if kind == "Pass" then
		local gp = Config.Find(Config.GamePasses, key)
		if gp and gp.Id ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, gp.Id)
			return
		end
	elseif kind == "Product" then
		local prod = Config.Find(Config.Products, key)
		if prod and prod.Id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, prod.Id)
			return
		end
	end
	fx(player, "Toast", "Coming soon!")
end

ActionRE.OnServerEvent:Connect(function(player, action, a, b)
	local s = S[player]
	if not s or not s.Loaded then
		return
	end
	local now = os.time()
	if action == "Buy" then
		promptBuy(player, a, b)
	elseif action == "Gift" then
		if now >= s.GiftAt then
			local amount = Config.GiftCash(s.Rebirths)
			setCash(player, s.Cash + amount)
			s.GiftAt = now + Config.GiftInterval
			player:SetAttribute("GiftAt", s.GiftAt)
			fx(player, "Collect", amount)
		end
	elseif action == "Daily" then
		if now - s.LastDaily >= 86400 then
			local amount = Config.GiftCash(s.Rebirths) * 5
			setCash(player, s.Cash + amount)
			s.LastDaily = now
			player:SetAttribute("LastDaily", now)
			fx(player, "Collect", amount)
			save(player)
		end
	elseif action == "Rebirth" then
		local cost = Config.RebirthCost(s.Rebirths)
		if s.Cash < cost then
			fx(player, "Broke", cost)
			return
		end
		for slot in pairs(s.Eggs) do
			removeEgg(player, slot)
		end
		s.Rebirths += 1
		player:SetAttribute("Rebirths", s.Rebirths)
		player.leaderstats.Rebirths.Value = s.Rebirths
		setCash(player, 50)
		s.Uncollected = 0
		player:SetAttribute("Income", incomeOf(player))
		save(player)
		fx(player, "Rebirth", s.Rebirths)
		announce("🔄 " .. player.DisplayName .. " just reached Rebirth " .. s.Rebirths .. "!", Color3.fromRGB(200, 120, 255))
	end
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, _, purchased)
	if purchased then
		refreshPasses(player)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = baseSpeed(player)
		end
		fx(player, "Thanks")
	end
end)

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local s = player and S[player]
	if not s or not s.Loaded then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	for _, prod in ipairs(Config.Products) do
		if prod.Id ~= 0 and prod.Id == receipt.ProductId then
			local scale = (1 + s.Rebirths) ^ 2
			if prod.Cash then
				setCash(player, s.Cash + prod.Cash * scale)
			elseif prod.Key == "Starter" then
				setCash(player, s.Cash + 5000 * scale)
				workspaceLuck = math.max(workspaceLuck, os.time()) + 900
				workspace:SetAttribute("LuckUntil", workspaceLuck)
				announce("🍀 " .. player.DisplayName .. " activated SERVER LUCK x3!", Color3.fromRGB(90, 255, 120))
			elseif prod.Key == "Luck" then
				workspaceLuck = math.max(workspaceLuck, os.time()) + 900
				workspace:SetAttribute("LuckUntil", workspaceLuck)
				announce("🍀 " .. player.DisplayName .. " activated SERVER LUCK x3 for everyone!", Color3.fromRGB(90, 255, 120))
			elseif prod.Key == "Lock" then
				s.LockedUntil = os.time() + 120
				s.LockCdUntil = s.LockedUntil + Config.LockCooldown
				player:SetAttribute("LockedUntil", s.LockedUntil)
			end
			save(player)
			fx(player, "Thanks")
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

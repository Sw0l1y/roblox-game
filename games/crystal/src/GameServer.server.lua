-- ServerScriptService.GameServer ("Grow a Crystal Garden")
-- Loop: buy seeds at the Seed Shop -> plant them in your garden -> crystals grow in real time (even offline)
-- -> harvest -> sell at the Sell Stand -> buy rarer seeds and expand the garden.
-- Server-wide weather events (Frost / Thunder / Meteor / Aurora) mutate growing crystals into rarer, pricier ones.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local store = DataStoreService:GetDataStore("CrystalGarden_v1")

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
-- Lighting: dreamy sunset; weather events tween it
---------------------------------------------------------------------------
Lighting.ClockTime = 17.3
Lighting.Brightness = 2.3
Lighting.Ambient = Color3.fromRGB(120, 100, 150)
Lighting.OutdoorAmbient = Color3.fromRGB(175, 155, 205)
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 0.8
local atmo = Instance.new("Atmosphere")
atmo.Density = 0.3
atmo.Offset = 0.15
atmo.Color = Color3.fromRGB(255, 205, 230)
atmo.Decay = Color3.fromRGB(175, 135, 225)
atmo.Glare = 0.4
atmo.Haze = 1.5
atmo.Parent = Lighting
local rays = Instance.new("SunRaysEffect")
rays.Intensity = 0.08
rays.Spread = 0.7
rays.Parent = Lighting
local clouds = Instance.new("Clouds")
clouds.Cover = 0.5
clouds.Density = 0.55
clouds.Color = Color3.fromRGB(255, 225, 240)
clouds.Parent = workspace.Terrain
local cc = Instance.new("ColorCorrectionEffect")
cc.Saturation = 0.25
cc.Contrast = 0.06
cc.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.8
bloom.Size = 30
bloom.Threshold = 1.25
bloom.Parent = Lighting

local MOODS = {
	None = { Clock = 17.3, Bright = 2.3, Atmo = Color3.fromRGB(255, 205, 230), Decay = Color3.fromRGB(175, 135, 225), Tint = Color3.new(1, 1, 1), Cover = 0.5 },
	Frost = { Clock = 15.5, Bright = 2.6, Atmo = Color3.fromRGB(215, 238, 255), Decay = Color3.fromRGB(140, 185, 235), Tint = Color3.fromRGB(225, 240, 255), Cover = 0.75 },
	Thunder = { Clock = 18.2, Bright = 1.1, Atmo = Color3.fromRGB(120, 120, 155), Decay = Color3.fromRGB(60, 60, 95), Tint = Color3.fromRGB(205, 210, 235), Cover = 0.9 },
	Meteor = { Clock = 23.4, Bright = 1.4, Atmo = Color3.fromRGB(110, 70, 160), Decay = Color3.fromRGB(60, 30, 110), Tint = Color3.fromRGB(235, 220, 255), Cover = 0.2 },
	Aurora = { Clock = 22.6, Bright = 1.6, Atmo = Color3.fromRGB(90, 70, 150), Decay = Color3.fromRGB(40, 110, 140), Tint = Color3.fromRGB(235, 245, 255), Cover = 0.15 },
}
local function setMood(key)
	local m = MOODS[key] or MOODS.None
	local info = TweenInfo.new(4, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, { ClockTime = m.Clock, Brightness = m.Bright }):Play()
	TweenService:Create(atmo, info, { Color = m.Atmo, Decay = m.Decay }):Play()
	TweenService:Create(cc, info, { TintColor = m.Tint }):Play()
	TweenService:Create(clouds, info, { Cover = m.Cover }):Play()
end

---------------------------------------------------------------------------
-- Building helpers
---------------------------------------------------------------------------
local world = Instance.new("Folder")
world.Name = "World"
world.Parent = workspace

local function part(props)
	local p = Instance.new(props.Class or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		if k ~= "Parent" and k ~= "Class" then
			p[k] = v
		end
	end
	p.Parent = props.Parent or world
	return p
end

local function billboard(adornee, lines, offsetY, width, height, maxDist)
	local bb = Instance.new("BillboardGui")
	-- sized in studs (not pixels) so labels shrink with distance instead of cluttering the screen
	bb.Size = UDim2.fromScale((width or 200) / 26, (height or 70) / 26)
	bb.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	bb.MaxDistance = maxDist or 90
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

local function group(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent or world
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

-- Stylized look: flat SmoothPlastic / Glass / Neon colors, no stock material textures, no Highlight outlines.
local PALETTE = {
	Grass = Color3.fromRGB(142, 226, 170),
	Grass2 = Color3.fromRGB(118, 208, 156),
	Grass3 = Color3.fromRGB(170, 238, 190),
	Soil = Color3.fromRGB(96, 66, 116),
	SoilLocked = Color3.fromRGB(70, 60, 82),
	Stone = Color3.fromRGB(218, 208, 238),
	StoneDark = Color3.fromRGB(150, 138, 186),
	Rock = Color3.fromRGB(122, 106, 156),
	Wood = Color3.fromRGB(196, 136, 96),
	WoodDark = Color3.fromRGB(134, 86, 62),
	Path = Color3.fromRGB(252, 236, 214),
	Gold = Color3.fromRGB(255, 204, 64),
}
local ACCENTS = {
	Color3.fromRGB(255, 99, 160), Color3.fromRGB(255, 159, 64), Color3.fromRGB(255, 215, 80), Color3.fromRGB(75, 210, 130),
	Color3.fromRGB(70, 170, 255), Color3.fromRGB(160, 110, 255), Color3.fromRGB(80, 225, 225), Color3.fromRGB(240, 110, 90),
}

---------------------------------------------------------------------------
-- Crystal cluster builder (used for plants, decor and the event totem)
---------------------------------------------------------------------------
local function shard(parent, base, w, h, color, props)
	props = props or {}
	local bodyH = h * 0.72
	local tipH = h - bodyH
	local mat = props.Material or Enum.Material.Glass
	local body = part({ Name = "Shard", Size = Vector3.new(w, bodyH, w), CFrame = base * CFrame.new(0, bodyH / 2, 0), Color = color,
		Material = mat, Transparency = props.Transparency or 0.12, Reflectance = props.Reflectance or 0.12,
		CanCollide = props.CanCollide or false, CanQuery = false, CanTouch = false, Parent = parent })
	-- pointed tip: two wedges back to back form a ridge
	for k = 0, 1 do
		part({ Class = "WedgePart", Name = "Tip", Size = Vector3.new(w, tipH, w / 2),
			CFrame = base * CFrame.new(0, bodyH + tipH / 2, 0) * CFrame.Angles(0, k * math.pi, 0) * CFrame.new(0, 0, -w / 4),
			Color = color, Material = mat, Transparency = props.Transparency or 0.12, Reflectance = props.Reflectance or 0.12,
			CanCollide = false, CanQuery = false, CanTouch = false, Parent = parent })
	end
	return body
end

-- n shards fanning out from `base` (a CFrame at ground level). Returns the central body part.
local function cluster(parent, base, n, height, color, seed, props)
	local r = Random.new(seed or 1)
	local w = height * 0.3
	local main = shard(parent, base * CFrame.Angles(0, math.rad(45), 0), w, height, color, props)
	if props and props.Core then
		part({ Name = "Core", Size = Vector3.new(w * 0.45, height * 0.62, w * 0.45),
			CFrame = base * CFrame.Angles(0, math.rad(45), 0) * CFrame.new(0, height * 0.34, 0),
			Color = props.Core, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CanTouch = false, Parent = parent })
	end
	for j = 1, n - 1 do
		local ang = (j / (n - 1)) * math.pi * 2 + r:NextNumber(-0.3, 0.3)
		local tilt = math.rad(r:NextNumber(18, 34))
		local h = height * r:NextNumber(0.45, 0.78)
		local cf = base * CFrame.Angles(0, ang, 0) * CFrame.new(0, 0, -w * 0.45) * CFrame.Angles(-tilt, 0, 0)
			* CFrame.Angles(0, math.rad(45), 0)
		local c = color:Lerp(Color3.new(1, 1, 1), r:NextNumber(0, 0.18))
		shard(parent, cf, w * r:NextNumber(0.55, 0.75), h, c, props)
	end
	return main
end

---------------------------------------------------------------------------
-- The floating island
---------------------------------------------------------------------------
local rng = Random.new(11)
local decor = group("Decor")
local ground = group("Ground")

cyl(Vector3.new(0, -6, 0), 6, 360, PALETTE.Grass, ground, { Name = "Island" })
cyl(Vector3.new(0, -6.3, 0), 0.4, 366, PALETTE.Grass2, ground, { CanCollide = false })
-- rocky underside, narrowing to a point, with hanging crystals
local layers = { { 350, 10 }, { 310, 10 }, { 250, 12 }, { 180, 12 }, { 110, 12 }, { 50, 14 } }
local y = -6
for i, l in ipairs(layers) do
	y -= l[2]
	cyl(Vector3.new(0, y, 0), l[2], l[1], i % 2 == 0 and PALETTE.Rock or PALETTE.StoneDark, ground, { CanCollide = false })
end
for _ = 1, 26 do
	local a = rng:NextNumber(0, math.pi * 2)
	local rr = rng:NextNumber(30, 160)
	local depth = -10 - (1 - rr / 175) * 50
	local base = CFrame.new(math.cos(a) * rr, depth, math.sin(a) * rr) * CFrame.Angles(math.pi, 0, 0)
	cluster(decor, base, 3, rng:NextNumber(6, 14), Color3.fromHSV(rng:NextNumber(0.5, 0.95), 0.5, 1), rng:NextInteger(1, 1e6),
		{ Material = Enum.Material.Neon, Transparency = 0.1 })
end
-- invisible edge wall so nobody falls off
for i = 0, 59 do
	local a = i / 60 * math.pi * 2
	part({ Size = Vector3.new(20, 60, 2), CFrame = CFrame.new(math.cos(a) * 176, 30, math.sin(a) * 176) * CFrame.Angles(0, -a + math.pi / 2, 0),
		Transparency = 1, Parent = ground })
end
for _ = 1, 40 do
	local d = rng:NextNumber(14, 40)
	local a = rng:NextNumber(0, math.pi * 2)
	local rr = rng:NextNumber(40, 160)
	cyl(Vector3.new(math.cos(a) * rr, 0, math.sin(a) * rr), 0.05, d, rng:NextNumber() < 0.5 and PALETTE.Grass2 or PALETTE.Grass3, ground,
		{ CanCollide = false })
end

---------------------------------------------------------------------------
-- Plaza: event totem in the middle, Seed Shop and Sell Stand
---------------------------------------------------------------------------
local plaza = group("Plaza")
cyl(Vector3.new(0, 0, 0), 0.3, 76, PALETTE.Path, plaza)
cyl(Vector3.new(0, 0, 0), 0.25, 80, PALETTE.Stone, plaza, { CanCollide = false })
for i = 0, 15 do
	local a = i / 16 * math.pi * 2
	cyl(Vector3.new(math.cos(a) * 37, 0.3, math.sin(a) * 37), 0.2, 3, ACCENTS[i % 8 + 1], plaza, { CanCollide = false })
end

-- event totem: a giant glowing crystal on a pedestal
cyl(Vector3.new(0, 0.3, 0), 2, 16, PALETTE.StoneDark, plaza)
cyl(Vector3.new(0, 2.3, 0), 1.2, 12, PALETTE.Stone, plaza)
local totem = group("Totem", plaza)
local totemMain = cluster(totem, CFrame.new(0, 3.5, 0), 7, 16, Color3.fromRGB(255, 160, 230), 77,
	{ Core = Color3.fromRGB(255, 230, 250), Transparency = 0.2, CanCollide = true })
local totemLight = Instance.new("PointLight")
totemLight.Range = 40
totemLight.Brightness = 2
totemLight.Color = Color3.fromRGB(255, 160, 230)
totemLight.Parent = totemMain
local totemAnchor = part({ Size = Vector3.new(1, 1, 1), Position = Vector3.new(0, 22, 0), Transparency = 1, CanCollide = false, Parent = plaza })
local totemLabels = billboard(totemAnchor, { { Text = "Next event", Color = Color3.fromRGB(255, 255, 255) },
	{ Text = "", Color = Color3.fromRGB(255, 230, 120) } }, 3, 360, 90, 220)

local function stall(name, pos, facing, colorA, colorB, title)
	local m = group(name, plaza)
	local cf = CFrame.lookAt(pos, pos + facing)
	local function at(x, yy, z)
		return cf * CFrame.new(x, yy, z)
	end
	local counter = part({ Name = "Counter", Size = Vector3.new(14, 3.4, 3), CFrame = at(0, 1.7, -2), Color = PALETTE.Wood, Parent = m })
	part({ Size = Vector3.new(14.6, 0.5, 3.6), CFrame = at(0, 3.6, -2), Color = PALETTE.WoodDark, Parent = m })
	for _, px in ipairs({ -6.8, 6.8 }) do
		for _, pz in ipairs({ -3.2, 4 }) do
			part({ Size = Vector3.new(0.8, 10, 0.8), CFrame = at(px, 5, pz), Color = PALETTE.WoodDark, Parent = m })
		end
	end
	part({ Size = Vector3.new(14, 7, 0.6), CFrame = at(0, 3.5, 4), Color = PALETTE.Wood, Parent = m })
	-- striped awning
	for k = 0, 6 do
		part({ Size = Vector3.new(2, 0.5, 9.4), CFrame = at(-6 + k * 2, 10.2, 0.2) * CFrame.Angles(math.rad(-14), 0, 0),
			Color = k % 2 == 0 and colorA or colorB, Parent = m })
	end
	-- shopkeeper: a little crystal golem
	local keeper = CFrame.new((at(0, 0, 1.6)).Position)
	ellipsoid(Vector3.new(3.4, 4.2, 3.4), keeper * CFrame.new(0, 2.6, 0), colorA:Lerp(Color3.new(1, 1, 1), 0.4), m)
	for _, ex in ipairs({ -0.6, 0.6 }) do
		ellipsoid(Vector3.new(0.6, 0.9, 0.4), at(ex, 3.6, -0.05), Color3.fromRGB(30, 20, 40), m)
	end
	cluster(m, CFrame.new((at(0, 4.4, 1.6)).Position), 3, 2.4, colorB, 5, { Material = Enum.Material.Neon })
	local sign = part({ Size = Vector3.new(1, 1, 1), CFrame = at(0, 13.5, 0), Transparency = 1, CanCollide = false, Parent = m })
	billboard(sign, { { Text = title, Color = PALETTE.Gold } }, 0, 300, 50, 160)
	return counter, m
end

local seedCounter = stall("SeedShop", Vector3.new(-26, 0, 0), Vector3.new(1, 0, 0), Color3.fromRGB(90, 210, 120),
	Color3.fromRGB(255, 255, 255), "🌱 SEED SHOP")
local sellCounter = stall("SellStand", Vector3.new(26, 0, 0), Vector3.new(-1, 0, 0), Color3.fromRGB(255, 190, 50),
	Color3.fromRGB(255, 255, 255), "💰 SELL CRYSTALS")

local seedPrompt = Instance.new("ProximityPrompt")
seedPrompt.Name = "SeedShop"
seedPrompt.ActionText = "Open Seed Shop"
seedPrompt.ObjectText = "Seeds"
seedPrompt.HoldDuration = 0
seedPrompt.MaxActivationDistance = 12
seedPrompt.RequiresLineOfSight = false
seedPrompt.Parent = seedCounter
local sellPrompt = Instance.new("ProximityPrompt")
sellPrompt.Name = "SellAll"
sellPrompt.ActionText = "Sell All"
sellPrompt.ObjectText = "Crystals"
sellPrompt.HoldDuration = 0.3
sellPrompt.MaxActivationDistance = 12
sellPrompt.RequiresLineOfSight = false
sellPrompt.Parent = sellCounter

local spawnLoc = Instance.new("SpawnLocation")
spawnLoc.Anchored = true
spawnLoc.Size = Vector3.new(8, 0.4, 8)
spawnLoc.Position = Vector3.new(0, 0.4, 22)
spawnLoc.Transparency = 1
spawnLoc.CanCollide = false
spawnLoc.Duration = 0
spawnLoc.Parent = world

---------------------------------------------------------------------------
-- Gardens (8 in a ring around the plaza)
---------------------------------------------------------------------------
local RING = 95
local TILE = 5.6
local gardensFolder = Instance.new("Folder")
gardensFolder.Name = "Gardens"
gardensFolder.Parent = world
local crystalsFolder = Instance.new("Folder")
crystalsFolder.Name = "Crystals"
crystalsFolder.Parent = world

local plots = {}
local plotAngles = {}

local function tileLocal(n)
	local col = (n - 1) % Config.TileCols + 1
	local row = math.floor((n - 1) / Config.TileCols) + 1
	return Vector3.new((col - 3.5) * TILE, 0, -15 + (row - 1) * TILE)
end

for i = 1, 8 do
	local a = math.rad((i - 1) * 45 + 22.5)
	plotAngles[i] = a
	local center = Vector3.new(math.sin(a) * RING, 0, math.cos(a) * RING)
	local cf = CFrame.lookAt(center, Vector3.new(0, 0, 0)) -- local -Z faces the plaza
	local accent = ACCENTS[i]
	local model = group("Garden" .. i, gardensFolder)
	local plot = { Index = i, CF = cf, Tiles = {}, Visual = {}, Model = model, Accent = accent }
	local function at(x, yy, z)
		return cf * CFrame.new(x, yy, z)
	end
	plot.At = at
	part({ Name = "Platform", Size = Vector3.new(44, 1, 46), CFrame = at(0, 0.5, 0), Color = PALETTE.Grass3, Parent = model })
	-- stone border (front left open in the middle as the entrance)
	part({ Size = Vector3.new(46, 1.6, 2), CFrame = at(0, 0.8, 23.5), Color = PALETTE.Stone, Parent = model })
	part({ Size = Vector3.new(2, 1.6, 49), CFrame = at(-23, 0.8, 0), Color = PALETTE.Stone, Parent = model })
	part({ Size = Vector3.new(2, 1.6, 49), CFrame = at(23, 0.8, 0), Color = PALETTE.Stone, Parent = model })
	part({ Size = Vector3.new(16, 1.6, 2), CFrame = at(-15, 0.8, -23.5), Color = PALETTE.Stone, Parent = model })
	part({ Size = Vector3.new(16, 1.6, 2), CFrame = at(15, 0.8, -23.5), Color = PALETTE.Stone, Parent = model })
	-- glowing crystal posts in the accent color on each corner and the gate
	for _, p in ipairs({ { -23, -23.5 }, { 23, -23.5 }, { -23, 23.5 }, { 23, 23.5 }, { -7, -23.5 }, { 7, -23.5 } }) do
		cluster(model, at(p[1], 1.6, p[2]), 3, 4.5, accent, i * 10 + p[1], { Material = Enum.Material.Neon })
	end
	-- soil tiles
	for n = 1, Config.MaxTiles do
		local lp = tileLocal(n)
		local soil = part({ Name = "Soil", Size = Vector3.new(TILE - 0.6, 0.6, TILE - 0.6), CFrame = at(lp.X, 1.3, lp.Z), Color = PALETTE.Soil,
			Parent = model })
		soil:SetAttribute("Plot", i)
		soil:SetAttribute("Tile", n)
		plot.Tiles[n] = soil
	end
	-- path from the plaza to the gate
	local gate = at(0, 0, -24).Position
	local inner = Vector3.new(math.sin(a) * 37, 0, math.cos(a) * 37)
	local len = (gate - inner).Magnitude
	part({ Size = Vector3.new(10, 0.25, len), CFrame = CFrame.lookAt((gate + inner) / 2 + Vector3.new(0, 0.1, 0), gate + Vector3.new(0, 0.1, 0)),
		Color = PALETTE.Path, CanCollide = false, Parent = model })
	-- owner sign at the back, facing the plaza
	local board = part({ Size = Vector3.new(24, 6, 1), CFrame = at(0, 7.5, 22), Color = PALETTE.Wood, Parent = model })
	for _, bx in ipairs({ -10, 10 }) do
		part({ Size = Vector3.new(1.2, 8, 1.2), CFrame = at(bx, 4, 22.8), Color = PALETTE.WoodDark, Parent = model })
	end
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(480, 120)
	sg.LightInfluence = 0.2
	sg.Parent = board
	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.fromScale(1, 1)
	signText.BackgroundColor3 = accent
	signText.Font = Enum.Font.FredokaOne
	signText.TextScaled = true
	signText.TextColor3 = Color3.new(1, 1, 1)
	signText.TextStrokeTransparency = 0
	signText.Text = "Empty Garden"
	signText.Parent = sg
	local signStroke = Instance.new("UIStroke")
	signStroke.Thickness = 6
	signStroke.Color = PALETTE.WoodDark
	signStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	signStroke.Parent = signText
	plot.Sign = signText
	-- expand sign by the gate (owner only)
	local exp = part({ Name = "ExpandSign", Size = Vector3.new(5, 3.4, 0.6), CFrame = at(-14, 3.4, -25.5), Color = Color3.fromRGB(90, 210, 120),
		Parent = model })
	part({ Size = Vector3.new(0.6, 3, 0.6), CFrame = at(-14, 1.5, -25.5), Color = PALETTE.WoodDark, Parent = model })
	local expLabels, expBB = billboard(exp, { { Text = "🔓 EXPAND", Color = Color3.fromRGB(150, 255, 170) }, { Text = "", Color = PALETTE.Gold } }, 3.5,
		150, 56, 60)
	expBB:SetAttribute("Plot", i)
	plot.ExpandSign = exp
	plot.ExpandLabels = expLabels
	local ep = Instance.new("ProximityPrompt")
	ep.Name = "Expand"
	ep.ActionText = "Expand Garden"
	ep.ObjectText = "+6 tiles"
	ep.HoldDuration = 0.5
	ep.MaxActivationDistance = 10
	ep.RequiresLineOfSight = false
	ep.Parent = exp
	model:SetAttribute("Spawn", CFrame.lookAt(at(0, 4, -28).Position, at(0, 4, 0).Position))
	plots[i] = plot
end

-- decor: pastel trees, glowing mushrooms, giant crystals; kept off the gardens, paths and plaza
local function nearPath(a)
	for _, pa in ipairs(plotAngles) do
		local d = math.abs((a - pa + math.pi) % (math.pi * 2) - math.pi)
		if d < math.rad(20) then
			return true
		end
	end
	return false
end
local function tree(pos, s)
	cyl(pos, 7 * s, 1.4 * s, PALETTE.WoodDark, decor)
	local tones = { Color3.fromRGB(255, 170, 215), Color3.fromRGB(215, 170, 255), Color3.fromRGB(255, 200, 225) }
	ellipsoid(Vector3.new(9, 7, 9) * s, CFrame.new(pos + Vector3.new(0, 8 * s, 0)), tones[rng:NextInteger(1, 3)], decor)
	ellipsoid(Vector3.new(6, 5, 6) * s, CFrame.new(pos + Vector3.new(1.5 * s, 11 * s, 0.5 * s)), tones[rng:NextInteger(1, 3)], decor)
	ellipsoid(Vector3.new(5, 4, 5) * s, CFrame.new(pos + Vector3.new(-1.8 * s, 10 * s, -1 * s)), tones[rng:NextInteger(1, 3)], decor)
end
local function mushroom(pos, s)
	cyl(pos, 1.6 * s, 0.6 * s, Color3.fromRGB(250, 240, 230), decor, { CanCollide = false })
	ellipsoid(Vector3.new(2.2, 1.2, 2.2) * s, CFrame.new(pos + Vector3.new(0, 1.7 * s, 0)), Color3.fromHSV(rng:NextNumber(0.5, 0.95), 0.55, 1), decor,
		{ Material = Enum.Material.Neon, CanCollide = false })
end
for _ = 1, 140 do
	local a = rng:NextNumber(0, math.pi * 2)
	local rr = rng:NextNumber(42, 170)
	local inRing = rr > 64 and rr < 128
	if not (inRing or (rr < 64 and nearPath(a))) then
		local pos = Vector3.new(math.cos(a) * rr, 0, math.sin(a) * rr)
		local roll = rng:NextNumber()
		if roll < 0.35 then
			tree(pos, rng:NextNumber(0.9, 1.5))
		elseif roll < 0.7 then
			for _ = 1, rng:NextInteger(2, 4) do
				mushroom(pos + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3)), rng:NextNumber(0.8, 1.6))
			end
		else
			cluster(decor, CFrame.new(pos), rng:NextInteger(3, 6), rng:NextNumber(6, 16), Color3.fromHSV(rng:NextNumber(0.45, 0.95), 0.45, 1),
				rng:NextInteger(1, 1e6), { Core = Color3.new(1, 1, 1), CanCollide = true })
		end
	end
end
-- floating mini islands in the sky
for k = 1, 9 do
	local a = k / 9 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
	local rr = rng:NextNumber(230, 320)
	local pos = Vector3.new(math.cos(a) * rr, rng:NextNumber(30, 90), math.sin(a) * rr)
	local s = rng:NextNumber(18, 36)
	cyl(pos - Vector3.new(0, 2, 0), 2, s, PALETTE.Grass, decor)
	ellipsoid(Vector3.new(s * 0.9, s * 0.8, s * 0.9), CFrame.new(pos - Vector3.new(0, s * 0.35, 0)), PALETTE.Rock, decor)
	cluster(decor, CFrame.new(pos), 5, s * 0.5, Color3.fromHSV(rng:NextNumber(0.45, 0.95), 0.5, 1), k, { Material = Enum.Material.Neon })
end

---------------------------------------------------------------------------
-- Player state
---------------------------------------------------------------------------
local S = {} -- player -> state

local function hasPass(player, key)
	return player:GetAttribute("Pass_" .. key) == true
end

local function setCoins(player, value)
	local s = S[player]
	s.Coins = math.floor(value)
	player:SetAttribute("Coins", s.Coins)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Coins.Value = s.Coins
	end
end

local function encodeCounts(t)
	local parts = {}
	for name, n in pairs(t) do
		if n > 0 then
			parts[#parts + 1] = name .. "=" .. n
		end
	end
	return table.concat(parts, "|")
end

local function sellMult(player)
	local m = 1
	if hasPass(player, "DoubleCoins") then
		m *= 2
	end
	if hasPass(player, "VIP") then
		m *= 1.25
	end
	return m
end

local function syncSeeds(player)
	player:SetAttribute("Seeds", encodeCounts(S[player].Seeds))
end
local function syncStock(player)
	player:SetAttribute("Stock", encodeCounts(S[player].Stock))
end
local function syncBag(player)
	local s = S[player]
	local total = 0
	for _, item in ipairs(s.Bag) do
		total += Config.Value(item.N, item.S, item.M)
	end
	player:SetAttribute("BagJson", HttpService:JSONEncode(s.Bag))
	player:SetAttribute("BagCount", #s.Bag)
	player:SetAttribute("BagValue", math.floor(total * sellMult(player)))
end
local function syncDiscovered(player)
	local names = {}
	for name in pairs(S[player].Discovered) do
		names[#names + 1] = name
	end
	player:SetAttribute("Discovered", table.concat(names, "|"))
end

local function growSpeed(player)
	return hasPass(player, "FastGrow") and 1.5 or 1
end

local function rollSize()
	if math.random() < Config.HugeChance then
		return math.floor((2.5 + math.random() * 1.5) * 100) / 100
	end
	return math.floor((0.8 + math.random() * 0.6) * 100) / 100
end

local function rollNatural()
	local muts = {}
	for _, m in ipairs(Config.Mutations) do
		if m.Natural and math.random() < m.Natural then
			muts[1] = m.Name -- only one natural variant
			break
		end
	end
	return muts
end

local function rollStock(player, luck)
	local s = S[player]
	s.Stock = {}
	for _, c in ipairs(Config.Crystals) do
		local odds = Config.StockOdds[c.Rarity]
		local chance = odds.Chance
		if luck and luck > 1 and c.Rarity ~= "Common" then
			chance = math.min(1, chance * luck)
		end
		if math.random() < chance then
			s.Stock[c.Name] = math.random(odds.Min, odds.Max)
			local _, ri = Config.Rarity(c.Rarity)
			if ri >= 5 then
				fx(player, "RareStock", c.Name, c.Rarity)
			end
		end
	end
	syncStock(player)
end

---------------------------------------------------------------------------
-- Planted crystals: visuals + growth
---------------------------------------------------------------------------
local function hasMut(muts, name)
	for _, m in ipairs(muts or {}) do
		if m == name then
			return true
		end
	end
	return false
end

local function stageOf(t, now)
	local p = 1 - (t.R - now) / math.max(1, t.D)
	if p >= 1 then
		return 4
	elseif p >= 0.67 then
		return 3
	elseif p >= 0.34 then
		return 2
	end
	return 1
end
local STAGE_SCALE = { 0.3, 0.55, 0.8, 1 }

local function crystalColor(def, muts)
	local color = def.Color
	if hasMut(muts, "Gold") then
		color = Config.Mutation("Gold").Color
	elseif hasMut(muts, "Cosmic") then
		color = color:Lerp(Color3.fromRGB(110, 50, 210), 0.6)
	elseif hasMut(muts, "Frozen") then
		color = color:Lerp(Color3.fromRGB(205, 240, 255), 0.55)
	end
	return color
end

local function emitter(parentPart, color, rate, props)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.5, 0)
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Rate = rate
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	for k, v in pairs(props or {}) do
		e[k] = v
	end
	e.Parent = parentPart
	return e
end

local harvest -- forward declared

local function renderTile(player, n, stage)
	local s = S[player]
	local plot = plots[s.Plot]
	local soil = plot.Tiles[n]
	local vis = plot.Visual[n]
	if vis then
		vis.Model:Destroy()
		plot.Visual[n] = nil
	end
	local t = s.Tiles[n]
	soil:SetAttribute("Seed", t and t.N or nil)
	soil:SetAttribute("ReadyAt", t and t.R or nil)
	soil:SetAttribute("Dur", t and t.D or nil)
	soil:SetAttribute("Muts", t and table.concat(t.M, ",") or nil)
	soil:SetAttribute("Size", t and t.S or nil)
	if not t then
		return
	end
	local def = Config.Crystal(t.N)
	if not def then
		return
	end
	stage = stage or stageOf(t, os.time())
	local model = Instance.new("Model")
	model.Name = def.Name
	local scale = STAGE_SCALE[stage] * math.min(t.S, 1.7)
	local _, ri = Config.Rarity(def.Rarity)
	local color = crystalColor(def, t.M)
	local glow = color:Lerp(Color3.new(1, 1, 1), 0.5)
	local main = cluster(model, CFrame.new(soil.Position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, (n * 1.7) % (math.pi * 2), 0),
		stage == 1 and 2 or def.Shards, def.H * scale, color, n * 97 + #def.Name, { Core = glow, Transparency = stage == 4 and 0.1 or 0.3 })
	model.PrimaryPart = main
	model:SetAttribute("OwnerId", player.UserId)
	model:SetAttribute("Rainbow", hasMut(t.M, "Rainbow") or def.Name == "Prism Heart")
	if hasMut(t.M, "Frozen") then
		emitter(main, Color3.fromRGB(235, 250, 255), 3, { Acceleration = Vector3.new(0, -2, 0), Speed = NumberRange.new(0.5, 1) })
	end
	if hasMut(t.M, "Charged") then
		emitter(main, Color3.fromRGB(255, 245, 120), 8, { Speed = NumberRange.new(4, 7), Lifetime = NumberRange.new(0.15, 0.3) })
	end
	if hasMut(t.M, "Cosmic") then
		emitter(main, Color3.fromRGB(190, 140, 255), 5, { Size = NumberSequence.new(0.8, 0) })
	end
	if hasMut(t.M, "Gold") then
		emitter(main, Color3.fromRGB(255, 220, 90), 5)
	end
	if stage == 4 then
		local light = Instance.new("PointLight")
		light.Color = glow
		light.Range = 6 + ri
		light.Brightness = 1.2 + ri * 0.15
		light.Parent = main
		emitter(main, glow, 2 + ri, { Size = NumberSequence.new(0.35, 0) })
		local p = Instance.new("ProximityPrompt")
		p.Name = "Harvest"
		p.ActionText = "Harvest"
		p.ObjectText = def.Name .. (#t.M > 0 and (" [" .. table.concat(t.M, ", ") .. "]") or "")
		p.HoldDuration = 0
		p.MaxActivationDistance = 9
		p.RequiresLineOfSight = false
		p.Parent = main
		main:SetAttribute("OwnerId", player.UserId)
		p.Triggered:Connect(function(who)
			if who == player then
				harvest(player, n)
			end
		end)
	end
	model.Parent = crystalsFolder
	plot.Visual[n] = { Model = model, Stage = stage }
end

local function refreshTiles(player)
	local s = S[player]
	local plot = plots[s.Plot]
	for n = 1, Config.MaxTiles do
		local soil = plot.Tiles[n]
		local locked = n > s.Unlocked
		soil:SetAttribute("Locked", locked)
		soil.Color = locked and PALETTE.SoilLocked or PALETTE.Soil
		soil.Transparency = locked and 0.45 or 0
	end
	local nextRow = (s.Unlocked - Config.StartTiles) / Config.TileCols + 1
	local cost = Config.ExpandCosts[nextRow]
	plot.ExpandLabels[2].Text = cost and ("$" .. Config.Format(cost)) or "MAXED"
	player:SetAttribute("Unlocked", s.Unlocked)
	player:SetAttribute("ExpandCost", cost or 0)
end

local function discover(player, name)
	local s = S[player]
	if not s.Discovered[name] then
		s.Discovered[name] = true
		syncDiscovered(player)
		return true
	end
	return false
end

function harvest(player, n)
	local s = S[player]
	local t = s and s.Tiles[n]
	if not t or os.time() < t.R then
		return
	end
	if #s.Bag >= Config.BackpackMax then
		fx(player, "Toast", "🎒 Backpack full! Sell at the Sell Stand.")
		fx(player, "BagFull")
		return
	end
	local def = Config.Crystal(t.N)
	if not def then
		s.Tiles[n] = nil
		renderTile(player, n)
		return
	end
	local item = { N = t.N, S = t.S, M = t.M }
	table.insert(s.Bag, item)
	s.Harvested += 1
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Harvested.Value = s.Harvested
	end
	local isNew = discover(player, t.N)
	local value = math.floor(Config.Value(item.N, item.S, item.M) * sellMult(player))
	fx(player, "Harvested", t.N, def.Rarity, value, table.concat(item.M, ","), item.S, isNew)
	local _, ri = Config.Rarity(def.Rarity)
	local fancy = hasMut(item.M, "Rainbow") or hasMut(item.M, "Cosmic") or (item.S >= 2.5 and ri >= 3)
	if ri >= 5 or fancy then
		local tag = (item.S >= 2.5 and "HUGE " or "") .. (#item.M > 0 and (table.concat(item.M, " ") .. " ") or "")
		announce("💎 " .. player.DisplayName .. " harvested a " .. tag .. def.Name .. "! ($" .. Config.Format(value) .. ")",
			Config.Rarities[ri].Color)
	end
	if def.Regrow then
		local dur = math.floor(def.Grow * 0.5 / growSpeed(player))
		s.Tiles[n] = { N = t.N, R = os.time() + dur, D = dur, M = rollNatural(), S = rollSize() }
	else
		s.Tiles[n] = nil
	end
	renderTile(player, n)
	syncBag(player)
end

local function sellAll(player)
	local s = S[player]
	if #s.Bag == 0 then
		fx(player, "Toast", "Nothing to sell! Harvest ripe crystals first.")
		return
	end
	local total = 0
	for _, item in ipairs(s.Bag) do
		total += Config.Value(item.N, item.S, item.M)
	end
	total = math.floor(total * sellMult(player))
	local count = #s.Bag
	s.Bag = {}
	setCoins(player, s.Coins + total)
	syncBag(player)
	fx(player, "Sold", total, count)
end

-- growth ticker: re-render a crystal when it reaches a new stage
task.spawn(function()
	while true do
		task.wait(1)
		local now = os.time()
		for player, s in pairs(S) do
			if s.Loaded then
				local plot = plots[s.Plot]
				for n, t in pairs(s.Tiles) do
					local st = stageOf(t, now)
					local vis = plot.Visual[n]
					if not vis or vis.Stage ~= st then
						renderTile(player, n, st)
						if st == 4 and vis then
							fx(player, "Ripe", t.N)
						end
					end
				end
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Seed restock (everyone's stock refreshes together)
---------------------------------------------------------------------------
local restockAt = os.time() + Config.RestockEvery
workspace:SetAttribute("RestockAt", restockAt)
task.spawn(function()
	while true do
		task.wait(1)
		if os.time() >= restockAt then
			restockAt += Config.RestockEvery
			workspace:SetAttribute("RestockAt", restockAt)
			for player, s in pairs(S) do
				if s.Loaded then
					rollStock(player)
					fx(player, "Restocked")
				end
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Weather events
---------------------------------------------------------------------------
local eventQueue = {}
local current = nil -- { Key, Ends }

local function pickEvent()
	local total = 0
	for _, e in ipairs(Config.Events) do
		total += e.Weight
	end
	local roll = math.random() * total
	for _, e in ipairs(Config.Events) do
		roll -= e.Weight
		if roll <= 0 then
			return e.Key
		end
	end
	return Config.Events[1].Key
end

local nextEvent = pickEvent()
local nextEventAt = os.time() + 150 -- first one comes quickly so new players see it
workspace:SetAttribute("NextEvent", nextEvent)
workspace:SetAttribute("NextEventAt", nextEventAt)
workspace:SetAttribute("Event", "")
workspace:SetAttribute("EventEnds", 0)

local function startEvent(key, byName)
	local e = Config.Event(key)
	if not e then
		return
	end
	current = { Key = key, Ends = os.time() + Config.EventLength }
	workspace:SetAttribute("Event", key)
	workspace:SetAttribute("EventEnds", current.Ends)
	setMood(key)
	TweenService:Create(totemLight, TweenInfo.new(2), { Color = e.Color }):Play()
	FxRE:FireAllClients("EventStart", key, byName)
end

local function endEvent()
	current = nil
	workspace:SetAttribute("Event", "")
	workspace:SetAttribute("EventEnds", 0)
	setMood("None")
	TweenService:Create(totemLight, TweenInfo.new(2), { Color = Color3.fromRGB(255, 160, 230) }):Play()
	FxRE:FireAllClients("EventEnd")
end

local function mutateTick()
	local e = current and Config.Event(current.Key)
	if not e then
		return
	end
	local now = os.time()
	for player, s in pairs(S) do
		if s.Loaded then
			local chance = e.Chance * (hasPass(player, "Lucky") and 2 or 1)
			for n, t in pairs(s.Tiles) do
				if not hasMut(t.M, e.Mutation) and math.random() < chance then
					-- Rainbow replaces Gold (they're both colour variants)
					if e.Mutation == "Rainbow" then
						for k = #t.M, 1, -1 do
							if t.M[k] == "Gold" then
								table.remove(t.M, k)
							end
						end
					end
					table.insert(t.M, e.Mutation)
					renderTile(player, n, stageOf(t, now))
					fx(player, "Mutated", t.N, e.Mutation)
				end
			end
		end
	end
end

task.spawn(function()
	local lastTick = 0
	while true do
		task.wait(1)
		local now = os.time()
		if current then
			if now - lastTick >= Config.EventTick then
				lastTick = now
				mutateTick()
			end
			if now >= current.Ends then
				endEvent()
				if #eventQueue > 0 then
					local q = table.remove(eventQueue, 1)
					task.wait(3)
					startEvent(q.Key, q.By)
				end
			end
		elseif now >= nextEventAt then
			startEvent(nextEvent)
			nextEvent = pickEvent()
			nextEventAt = now + Config.EventLength + Config.EventEvery
			workspace:SetAttribute("NextEvent", nextEvent)
			workspace:SetAttribute("NextEventAt", nextEventAt)
		end
		-- totem label
		if current then
			local e = Config.Event(current.Key)
			totemLabels[1].Text = e.Icon .. " " .. string.upper(e.Name) .. " " .. e.Icon
			totemLabels[1].TextColor3 = e.Color
			totemLabels[2].Text = Config.Time(current.Ends - now) .. " left • " .. e.Mutation .. " mutations!"
		else
			local e = Config.Event(nextEvent)
			totemLabels[1].Text = "Next: " .. e.Icon .. " " .. e.Name
			totemLabels[1].TextColor3 = Color3.new(1, 1, 1)
			totemLabels[2].Text = "in " .. Config.Time(nextEventAt - now)
		end
	end
end)

local function queueEvent(key, player)
	local e = Config.Event(key)
	if not e then
		return
	end
	if current then
		table.insert(eventQueue, { Key = key, By = player.DisplayName })
		announce(e.Icon .. " " .. player.DisplayName .. " bought a " .. e.Name .. "! It starts after this event.", e.Color)
	else
		startEvent(key, player.DisplayName)
		announce(e.Icon .. " " .. player.DisplayName .. " started a " .. string.upper(e.Name) .. " for everyone!", e.Color)
	end
end

---------------------------------------------------------------------------
-- Join / leave / save
---------------------------------------------------------------------------
local function refreshPasses(player)
	for _, gp in ipairs(Config.GamePasses) do
		if gp.Id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, gp.Id)
			player:SetAttribute("Pass_" .. gp.Key, ok and owns or false)
		end
	end
	if S[player] and S[player].Loaded then
		syncBag(player)
	end
end

local function save(player)
	local s = S[player]
	if not s or not s.Loaded then
		return
	end
	local tiles = {}
	for n, t in pairs(s.Tiles) do
		tiles[tostring(n)] = t
	end
	local data = { Coins = s.Coins, Seeds = s.Seeds, Tiles = tiles, Bag = s.Bag, Discovered = s.Discovered, LastDaily = s.LastDaily,
		Unlocked = s.Unlocked, Best = s.Best, Harvested = s.Harvested }
	local ok, err = pcall(function()
		store:SetAsync(tostring(player.UserId), data)
	end)
	if not ok then
		warn("Save failed for", player.Name, err)
	end
end

local function onCharacter(player, char)
	local s = S[player]
	local hum = char:WaitForChild("Humanoid")
	hum.WalkSpeed = 22
	char:WaitForChild("HumanoidRootPart")
	if s and s.Plot then
		task.wait()
		char:PivotTo(plots[s.Plot].Model:GetAttribute("Spawn"))
	end
	if hasPass(player, "VIP") then
		local head = char:WaitForChild("Head")
		local labels = billboard(head, { { Text = "👑 VIP", Color = Color3.fromRGB(255, 210, 50) } }, 2.5, 100, 26)
		labels[1].Parent.MaxDistance = 80
	end
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
	local coinsV = Instance.new("NumberValue")
	coinsV.Name = "Coins"
	coinsV.Parent = ls
	local harvV = Instance.new("NumberValue")
	harvV.Name = "Harvested"
	harvV.Parent = ls

	local s = { Plot = plotIndex, Coins = 0, Seeds = {}, Tiles = {}, Bag = {}, Discovered = {}, LastDaily = 0, Unlocked = Config.StartTiles,
		Best = 0, Harvested = 0, Stock = {}, GiftAt = os.time() + Config.GiftInterval }
	S[player] = s
	local plot = plots[plotIndex]
	plot.Sign.Text = player.DisplayName .. "'s Garden"
	plot.ExpandSign:SetAttribute("OwnerId", player.UserId)
	player:SetAttribute("Plot", plotIndex)

	local ok, data = pcall(function()
		return store:GetAsync(tostring(player.UserId))
	end)
	if not ok then
		player:Kick("Could not load your garden, please rejoin.")
		return
	end
	if not player.Parent then
		return
	end
	refreshPasses(player)
	local fresh = data == nil
	data = data or {}
	setCoins(player, data.Coins or Config.StartCoins)
	s.Seeds = data.Seeds or { Quartz = 3 }
	s.Bag = data.Bag or {}
	s.Discovered = data.Discovered or {}
	s.LastDaily = data.LastDaily or 0
	s.Unlocked = math.clamp(data.Unlocked or Config.StartTiles, Config.StartTiles, Config.MaxTiles)
	s.Best = data.Best or 0
	s.Harvested = data.Harvested or 0
	harvV.Value = s.Harvested
	for key, t in pairs(data.Tiles or {}) do
		local n = tonumber(key)
		if n and type(t) == "table" and Config.Crystal(t.N) then
			t.M = t.M or {}
			t.S = t.S or 1
			s.Tiles[n] = t
		end
	end
	player:SetAttribute("LastDaily", s.LastDaily)
	player:SetAttribute("GiftAt", s.GiftAt)
	s.Loaded = true
	syncSeeds(player)
	syncBag(player)
	syncDiscovered(player)
	rollStock(player)
	refreshTiles(player)
	for n in pairs(s.Tiles) do
		renderTile(player, n)
	end

	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	if fresh then
		fx(player, "Welcome")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local s = S[player]
	for _, plot in ipairs(plots) do
		if plot.Owner == player then
			plot.Owner = nil
			plot.Sign.Text = "Empty Garden"
			plot.ExpandSign:SetAttribute("OwnerId", nil)
			plot.ExpandLabels[2].Text = ""
			for n, vis in pairs(plot.Visual) do
				vis.Model:Destroy()
				plot.Visual[n] = nil
			end
			for _, soil in ipairs(plot.Tiles) do
				for _, attr in ipairs({ "Seed", "ReadyAt", "Dur", "Muts", "Size" }) do
					soil:SetAttribute(attr, nil)
				end
				soil:SetAttribute("Locked", false)
				soil.Color = PALETTE.Soil
				soil.Transparency = 0
			end
		end
	end
	if s then
		save(player)
		S[player] = nil
	end
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

-- prompts
seedPrompt.Triggered:Connect(function(player)
	fx(player, "OpenSeeds")
end)
sellPrompt.Triggered:Connect(function(player)
	if S[player] and S[player].Loaded then
		sellAll(player)
	end
end)

---------------------------------------------------------------------------
-- Actions from the client
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

local function nearSellStand(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root and (root.Position - sellCounter.Position).Magnitude < 22
end

local function expand(player)
	local s = S[player]
	local row = (s.Unlocked - Config.StartTiles) / Config.TileCols + 1
	local cost = Config.ExpandCosts[row]
	if not cost then
		fx(player, "Toast", "Your garden is already max size!")
		return
	end
	if s.Coins < cost then
		fx(player, "Broke", cost)
		return
	end
	setCoins(player, s.Coins - cost)
	s.Unlocked += Config.TileCols
	refreshTiles(player)
	fx(player, "Expanded", s.Unlocked)
	save(player)
end

for _, plot in ipairs(plots) do
	plot.ExpandSign.Expand.Triggered:Connect(function(player)
		if S[player] and S[player].Loaded and S[player].Plot == plot.Index then
			expand(player)
		end
	end)
end

ActionRE.OnServerEvent:Connect(function(player, action, a, b)
	local s = S[player]
	if not s or not s.Loaded then
		return
	end
	local now = os.time()
	if action == "Buy" then
		promptBuy(player, a, b)
	elseif action == "BuySeed" then
		local def = type(a) == "string" and Config.Crystal(a)
		if not def then
			return
		end
		if (s.Stock[a] or 0) <= 0 then
			fx(player, "Toast", "Out of stock! Restock in " .. Config.Time(restockAt - now))
			return
		end
		if s.Coins < def.Price then
			fx(player, "Broke", def.Price)
			return
		end
		setCoins(player, s.Coins - def.Price)
		s.Stock[a] -= 1
		s.Seeds[a] = (s.Seeds[a] or 0) + 1
		s.Best = math.max(s.Best, def.Price)
		syncStock(player)
		syncSeeds(player)
		fx(player, "BoughtSeed", a, def.Rarity)
	elseif action == "Plant" then
		local n = tonumber(a)
		local def = type(b) == "string" and Config.Crystal(b)
		if not n or not def or n < 1 or n > s.Unlocked or n ~= math.floor(n) then
			return
		end
		if s.Tiles[n] then
			return
		end
		if (s.Seeds[b] or 0) <= 0 then
			fx(player, "Toast", "No " .. b .. " seeds left! Buy more at the Seed Shop.")
			return
		end
		s.Seeds[b] -= 1
		local dur = math.floor(def.Grow / growSpeed(player))
		s.Tiles[n] = { N = b, R = now + dur, D = dur, M = rollNatural(), S = rollSize() }
		syncSeeds(player)
		renderTile(player, n)
		fx(player, "Planted", b, n)
	elseif action == "Harvest" then
		-- tap a ripe crystal (mobile friendly); must be standing near your garden
		local n = tonumber(a)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local soil = n and plots[s.Plot].Tiles[n]
		if soil and root and (root.Position - soil.Position).Magnitude < 40 then
			harvest(player, n)
		end
	elseif action == "Dig" then
		local n = tonumber(a)
		if n and s.Tiles[n] then
			s.Tiles[n] = nil
			renderTile(player, n)
			fx(player, "Dug", n)
		end
	elseif action == "Sell" then
		if hasPass(player, "SellAnywhere") or nearSellStand(player) then
			sellAll(player)
		else
			fx(player, "NeedStand")
		end
	elseif action == "Expand" then
		expand(player)
	elseif action == "Gift" then
		if now >= s.GiftAt then
			local amount = Config.GiftCoins(s.Best)
			setCoins(player, s.Coins + amount)
			s.GiftAt = now + Config.GiftInterval
			player:SetAttribute("GiftAt", s.GiftAt)
			fx(player, "Coins", amount)
		end
	elseif action == "Daily" then
		if now - s.LastDaily >= 86400 then
			local amount = Config.GiftCoins(s.Best) * 4
			setCoins(player, s.Coins + amount)
			local pool = { "Citrine", "Emerald", "Sapphire" }
			local seed = pool[math.random(1, #pool)]
			s.Seeds[seed] = (s.Seeds[seed] or 0) + 1
			syncSeeds(player)
			s.LastDaily = now
			player:SetAttribute("LastDaily", now)
			fx(player, "Coins", amount)
			fx(player, "Toast", "📅 Daily reward: +1 " .. seed .. " seed!")
			save(player)
		end
	end
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, _, purchased)
	if purchased then
		refreshPasses(player)
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
			local scale = math.max(1, s.Best / 1400)
			if prod.Coins then
				setCoins(player, s.Coins + prod.Coins * scale)
			elseif prod.Key == "Starter" then
				setCoins(player, s.Coins + 1000 * scale)
				s.Seeds.Sapphire = (s.Seeds.Sapphire or 0) + 3
				syncSeeds(player)
			elseif prod.Key == "GrowAll" then
				local now = os.time()
				for _, t in pairs(s.Tiles) do
					t.R = math.min(t.R, now)
				end
				announce("✨ " .. player.DisplayName .. " used GROW ALL! Their whole garden is ripe!", Color3.fromRGB(255, 220, 120))
			elseif prod.Key == "Restock" then
				rollStock(player, 3)
				fx(player, "Restocked")
			elseif prod.Event then
				queueEvent(prod.Event, player)
			end
			save(player)
			fx(player, "Thanks")
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

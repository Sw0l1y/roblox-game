-- ServerScriptService.GameServer ("Escape the Lava Wave")
-- Loop: run toward the volcano, grab lava critters, hide in safe pockets when the lava wave comes,
-- bring critters home where they earn cash, buy speed and carry upgrades, go deeper for rarer critters.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local store = DataStoreService:GetDataStore("LavaData_v1")

Players.RespawnTime = 2.5

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

local W = Config.TrackWidth
local HALF = W / 2
local TRACK_END = Config.TrackEnd()
local WAVE_FROM = TRACK_END + 70
local WAVE_TO = -6

---------------------------------------------------------------------------
-- Lighting: hot volcanic sunset
---------------------------------------------------------------------------
Lighting.ClockTime = 17.7
Lighting.GeographicLatitude = 20
Lighting.Brightness = 2.4
Lighting.Ambient = Color3.fromRGB(120, 80, 90)
Lighting.OutdoorAmbient = Color3.fromRGB(190, 130, 120)
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 0.5
local atmo = Instance.new("Atmosphere")
atmo.Density = 0.36
atmo.Offset = 0.15
atmo.Color = Color3.fromRGB(255, 170, 130)
atmo.Decay = Color3.fromRGB(150, 70, 90)
atmo.Glare = 0.6
atmo.Haze = 1.6
atmo.Parent = Lighting
local rays = Instance.new("SunRaysEffect")
rays.Intensity = 0.08
rays.Spread = 0.7
rays.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect")
cc.Saturation = 0.2
cc.Contrast = 0.1
cc.TintColor = Color3.fromRGB(255, 240, 230)
cc.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.8
bloom.Size = 30
bloom.Threshold = 1.2
bloom.Parent = Lighting

---------------------------------------------------------------------------
-- Building helpers (flat SmoothPlastic / Neon only; no stock material textures)
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
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent or world
	return p
end

local function ellipsoid(size, cf, color, parent, props)
	local p = part({ Size = size, CFrame = cf, Color = color, Parent = parent })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	for k, v in pairs(props or {}) do
		(p :: any)[k] = v
	end
	return p
end

-- upright cylinder whose base sits at pos.Y
local function cyl(pos, height, diameter, color, parent, props)
	local p = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Parent = parent })
	for k, v in pairs(props or {}) do
		(p :: any)[k] = v
	end
	return p
end

local function billboard(adornee, lines, offsetY, width, height, maxDist)
	local bb = Instance.new("BillboardGui")
	-- sized in studs so labels shrink with distance instead of cluttering the screen
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

local function sign(pos, facing, size, str, bg, textColor)
	local labels = {}
	local board = part({ Size = Vector3.new(size.X, size.Y, 1), CFrame = CFrame.lookAt(pos, pos + facing), Color = bg })
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.CanvasSize = Vector2.new(size.X * 40, size.Y * 40)
		sg.LightInfluence = 0
		sg.Parent = board
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = textColor or Color3.new(1, 1, 1)
		t.TextStrokeTransparency = 0
		t.Text = str
		t.Parent = sg
		labels[#labels + 1] = t
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0.04, 0)
		pad.PaddingRight = UDim.new(0.04, 0)
		pad.PaddingTop = UDim.new(0.1, 0)
		pad.PaddingBottom = UDim.new(0.1, 0)
		pad.Parent = t
	end
	return board, labels
end

local PALETTE = {
	Rock = Color3.fromRGB(74, 58, 70),
	RockDark = Color3.fromRGB(46, 36, 48),
	RockLight = Color3.fromRGB(112, 88, 98),
	Lava = Color3.fromRGB(255, 110, 20),
	LavaHot = Color3.fromRGB(255, 190, 60),
	Hub = Color3.fromRGB(96, 78, 86),
	HubTile = Color3.fromRGB(122, 100, 104),
	Safe = Color3.fromRGB(70, 230, 120),
	Gold = Color3.fromRGB(255, 204, 64),
	Wood = Color3.fromRGB(150, 96, 60),
}
local ACCENTS = {
	Color3.fromRGB(255, 99, 132), Color3.fromRGB(54, 162, 235), Color3.fromRGB(255, 205, 86), Color3.fromRGB(75, 192, 120),
	Color3.fromRGB(153, 102, 255), Color3.fromRGB(255, 159, 64), Color3.fromRGB(80, 220, 220), Color3.fromRGB(255, 120, 200),
}

local rng = Random.new(11)
local decor = Instance.new("Model")
decor.Name = "Decor"
decor.Parent = world

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	for k, v in pairs(props) do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function rock(pos, s, color)
	ellipsoid(Vector3.new(7, 4, 6) * s, CFrame.new(pos + Vector3.new(0, 1 * s, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0),
		color or PALETTE.RockDark, decor)
	ellipsoid(Vector3.new(4, 3, 3.5) * s, CFrame.new(pos + Vector3.new(2.4 * s, 0.8 * s, 1 * s)), PALETTE.Rock, decor)
end

local function crystal(pos, s, color)
	for k = 1, 3 do
		local h = rng:NextNumber(4, 8) * s
		part({ Size = Vector3.new(1.4 * s, h, 1.4 * s), CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-1.5, 1.5) * s, h / 2 - 0.5, rng:NextNumber(-1.5, 1.5) * s))
			* CFrame.Angles(rng:NextNumber(-0.4, 0.4), k, rng:NextNumber(-0.4, 0.4)), Color = color, Material = Enum.Material.Neon, Parent = decor,
			CanCollide = false })
	end
end

---------------------------------------------------------------------------
-- Lava sea, track, zones, safe pockets
---------------------------------------------------------------------------
local lavaSea = part({ Name = "LavaSea", Size = Vector3.new(2400, 2, 1400), Position = Vector3.new(500, -4, 0), Color = PALETTE.Lava,
	Material = Enum.Material.Neon })
lavaSea:SetAttribute("Kill", true)

-- start strip between the hub and zone 1
part({ Name = "StartFloor", Size = Vector3.new(Config.TrackStart + 4, 2, W), Position = Vector3.new(Config.TrackStart / 2 - 2, -1, 0),
	Color = Color3.fromRGB(226, 214, 190) })
local zoneFolder = Instance.new("Folder")
zoneFolder.Name = "Zones"
zoneFolder.Parent = world
for i, name in ipairs(Config.ZoneNames) do
	local x0 = Config.TrackStart + (i - 1) * Config.ZoneLength
	local color = Config.ZoneColors[i]
	part({ Name = "Zone" .. i, Size = Vector3.new(Config.ZoneLength, 2, W), Position = Vector3.new(x0 + Config.ZoneLength / 2, -1, 0),
		Color = color, Parent = zoneFolder })
	-- floor stripes so speed reads on camera
	for x = x0 + 10, x0 + Config.ZoneLength - 10, 20 do
		part({ Size = Vector3.new(6, 0.1, W - 8), Position = Vector3.new(x, 0.05, 0), Color = color:Lerp(Color3.new(1, 1, 1), 0.18),
			CanCollide = false, CanQuery = false, Parent = zoneFolder })
	end
	-- zone gate: two pillars and a glowing sign in the zone's rarity color
	local rarity = Config.Rarities[i]
	for _, side in ipairs({ -1, 1 }) do
		part({ Size = Vector3.new(4, 26, 4), Position = Vector3.new(x0, 13, side * (HALF + 2)), Color = PALETTE.RockDark })
		part({ Size = Vector3.new(5, 2, 5), Position = Vector3.new(x0, 26.5, side * (HALF + 2)), Color = rarity.Color, Material = Enum.Material.Neon })
	end
	part({ Size = Vector3.new(3, 3, W + 8), Position = Vector3.new(x0, 25, 0), Color = PALETTE.RockDark })
	sign(Vector3.new(x0, 20, 0), Vector3.new(-1, 0, 0), Vector2.new(34, 6), "ZONE " .. i .. " • " .. string.upper(name), rarity.Color:Lerp(Color3.new(0, 0, 0), 0.35),
		Color3.new(1, 1, 1))
	part({ Size = Vector3.new(0.6, 0.12, W), Position = Vector3.new(x0, 0.08, 0), Color = rarity.Color, Material = Enum.Material.Neon,
		CanCollide = false, CanQuery = false })
end

-- side walls with safe pockets cut into them
local walls = Instance.new("Model")
walls.Name = "Walls"
walls.Parent = world
local alcoveXs = {}
for x = Config.AlcoveEvery, TRACK_END - 20, Config.AlcoveEvery do
	alcoveXs[#alcoveXs + 1] = x
end
local WALL_H = 14
local function wallSeg(xa, xb, z)
	if xb - xa < 0.5 then
		return
	end
	part({ Size = Vector3.new(xb - xa, WALL_H, 3), Position = Vector3.new((xa + xb) / 2, WALL_H / 2, z), Color = PALETTE.Rock, Parent = walls })
	part({ Size = Vector3.new(xb - xa, 0.8, 3.4), Position = Vector3.new((xa + xb) / 2, WALL_H + 0.4, z), Color = PALETTE.RockLight, Parent = walls })
end
local AW, AD = Config.AlcoveWidth, Config.AlcoveDepth
for _, side in ipairs({ -1, 1 }) do
	local z = side * (HALF + 1.5)
	local cursor = 0
	for _, ax in ipairs(alcoveXs) do
		wallSeg(cursor, ax - AW / 2, z)
		cursor = ax + AW / 2
		-- the pocket: floor, back wall, side walls, glowing rim and a roof the wave can't reach into
		local zc = side * (HALF + AD / 2)
		part({ Name = "SafeFloor", Size = Vector3.new(AW, 2, AD), Position = Vector3.new(ax, -1, zc), Color = Color3.fromRGB(60, 120, 90), Parent = walls })
		part({ Size = Vector3.new(AW - 2, 0.12, AD - 2), Position = Vector3.new(ax, 0.07, zc), Color = PALETTE.Safe, Material = Enum.Material.Neon,
			Transparency = 0.35, CanCollide = false, CanQuery = false, Parent = walls })
		part({ Size = Vector3.new(AW + 6, WALL_H, 3), Position = Vector3.new(ax, WALL_H / 2, side * (HALF + AD + 1.5)), Color = PALETTE.Rock, Parent = walls })
		for _, dx in ipairs({ -1, 1 }) do
			part({ Size = Vector3.new(3, WALL_H, AD + 3), Position = Vector3.new(ax + dx * (AW / 2 + 1.5), WALL_H / 2, side * (HALF + AD / 2 + 1.5)),
				Color = PALETTE.Rock, Parent = walls })
		end
		part({ Size = Vector3.new(AW + 6, 1.2, AD + 4), Position = Vector3.new(ax, WALL_H + 0.6, side * (HALF + AD / 2 + 1.5)), Color = PALETTE.RockLight,
			Parent = walls })
		local glow = part({ Size = Vector3.new(AW, 0.6, 0.6), Position = Vector3.new(ax, WALL_H - 0.6, side * (HALF + 0.4)), Color = PALETTE.Safe,
			Material = Enum.Material.Neon, CanCollide = false, Parent = walls })
		local light = Instance.new("PointLight")
		light.Color = PALETTE.Safe
		light.Range = 16
		light.Brightness = 1.5
		light.Parent = glow
		local anchor = part({ Size = Vector3.new(1, 1, 1), Position = Vector3.new(ax, 6, zc), Transparency = 1, CanCollide = false, CanQuery = false,
			Parent = walls })
		billboard(anchor, { { Text = "🛡️ SAFE", Color = Color3.fromRGB(140, 255, 170) } }, 3, 110, 34, 140)
	end
	wallSeg(cursor, TRACK_END + 70, z)
end
-- back wall of the volcano end
part({ Size = Vector3.new(3, WALL_H, W + 6), Position = Vector3.new(TRACK_END + 70, WALL_H / 2, 0), Color = PALETTE.Rock, Parent = walls })
-- crater floor past the last zone (where the wave is born)
part({ Size = Vector3.new(70, 2, W), Position = Vector3.new(TRACK_END + 35, -1, 0), Color = Color3.fromRGB(40, 24, 34) })
for _ = 1, 10 do
	part({ Size = Vector3.new(rng:NextNumber(4, 10), 0.15, rng:NextNumber(1, 2.5)), CFrame = CFrame.new(TRACK_END + rng:NextNumber(8, 64), 0.05,
		rng:NextNumber(-HALF + 3, HALF - 3)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = PALETTE.Lava, Material = Enum.Material.Neon,
		CanCollide = false, CanQuery = false })
end

-- the volcano
local volcano = Instance.new("Model")
volcano.Name = "Volcano"
volcano.Parent = world
local VX = TRACK_END + 170
for k = 0, 9 do
	local d = 260 - k * 22
	cyl(Vector3.new(VX, -4 + k * 12, 0), 12.5, d, k % 2 == 0 and PALETTE.RockDark or PALETTE.Rock, volcano)
end
cyl(Vector3.new(VX, 116, 0), 1, 58, PALETTE.LavaHot, volcano, { Material = Enum.Material.Neon })
local crater = part({ Size = Vector3.new(30, 4, 30), Position = Vector3.new(VX, 122, 0), Transparency = 1, CanCollide = false, Parent = volcano })
emitter(crater, { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(90, 70, 80)),
	Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 18), NumberSequenceKeypoint.new(1, 60) }),
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
	Lifetime = NumberRange.new(8, 12), Rate = 6, Speed = NumberRange.new(14, 22), SpreadAngle = Vector2.new(18, 18),
	Acceleration = Vector3.new(-3, 2, 0), RotSpeed = NumberRange.new(-20, 20) })
emitter(crater, { Texture = "rbxasset://textures/particles/fire_main.dds", Color = ColorSequence.new(PALETTE.LavaHot, PALETTE.Lava),
	Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 14), NumberSequenceKeypoint.new(1, 2) }), LightEmission = 1,
	Lifetime = NumberRange.new(1.5, 2.5), Rate = 30, Speed = NumberRange.new(12, 24), SpreadAngle = Vector2.new(25, 25) })
-- lava streams down the cone
for k = 0, 5 do
	local a = math.rad(-150 + k * 60)
	for j = 0, 8 do
		local r = 32 + j * 12
		local y = 112 - j * 12
		part({ Size = Vector3.new(7 - j * 0.4, 13, 7 - j * 0.4), CFrame = CFrame.new(VX + math.cos(a) * r, y, math.sin(a) * r)
			* CFrame.Angles(0, -a, math.rad(40)), Color = j % 2 == 0 and PALETTE.Lava or PALETTE.LavaHot, Material = Enum.Material.Neon,
			CanCollide = false, Parent = volcano })
	end
end

-- scenery beyond the walls: rocks, glowing crystals and lava geysers in the lava sea
for _ = 1, 90 do
	local x = rng:NextNumber(-40, TRACK_END + 60)
	local z = (rng:NextNumber() < 0.5 and -1 or 1) * rng:NextNumber(HALF + AD + 10, 220)
	local r = rng:NextNumber()
	if r < 0.6 then
		rock(Vector3.new(x, -3, z), rng:NextNumber(1.5, 4), r < 0.3 and PALETTE.RockDark or PALETTE.Rock)
	elseif r < 0.85 then
		ellipsoid(Vector3.new(14, 6, 14) * rng:NextNumber(0.6, 1.4), CFrame.new(x, -3, z), PALETTE.RockDark, decor)
		crystal(Vector3.new(x, 0, z), rng:NextNumber(1, 1.8), Config.Rarities[rng:NextInteger(3, 7)].Color)
	else
		local g = part({ Size = Vector3.new(2, 2, 2), Position = Vector3.new(x, -2, z), Transparency = 1, CanCollide = false, Parent = decor })
		emitter(g, { Texture = "rbxasset://textures/particles/fire_main.dds", Color = ColorSequence.new(PALETTE.LavaHot, PALETTE.Lava),
			Size = NumberSequence.new(3, 0.5), LightEmission = 1, Lifetime = NumberRange.new(1, 1.6), Rate = 14,
			Speed = NumberRange.new(18, 30), SpreadAngle = Vector2.new(8, 8), Acceleration = Vector3.new(0, -30, 0) })
	end
end
-- floating embers over the whole map
for x = 0, TRACK_END, 120 do
	local e = part({ Size = Vector3.new(120, 1, W + 40), Position = Vector3.new(x + 60, 30, 0), Transparency = 1, CanCollide = false, CanQuery = false,
		Parent = decor })
	emitter(e, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(PALETTE.LavaHot, PALETTE.Lava),
		Size = NumberSequence.new(0.4, 0), LightEmission = 1, Lifetime = NumberRange.new(4, 7), Rate = 6, Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 1.5, 0) })
end

---------------------------------------------------------------------------
-- Hub and bases
---------------------------------------------------------------------------
local hub = Instance.new("Model")
hub.Name = "Hub"
hub.Parent = world
part({ Name = "HubFloor", Size = Vector3.new(160, 2, 180), Position = Vector3.new(-78, -1, 0), Color = PALETTE.Hub, Parent = hub })
for x = -150, -10, 20 do
	for z = -80, 80, 20 do
		if (x / 20 + z / 20) % 2 == 0 then
			part({ Size = Vector3.new(19.6, 0.1, 19.6), Position = Vector3.new(x + 2, 0.05, z), Color = PALETTE.HubTile, CanCollide = false,
				CanQuery = false, Parent = hub })
		end
	end
end
-- hub rim walls
for _, z in ipairs({ -91, 91 }) do
	part({ Size = Vector3.new(164, 10, 2), Position = Vector3.new(-78, 5, z), Color = PALETTE.Rock, Parent = hub })
end
part({ Size = Vector3.new(2, 10, 184), Position = Vector3.new(-159, 5, 0), Color = PALETTE.Rock, Parent = hub })
for _, z in ipairs({ -1, 1 }) do
	part({ Size = Vector3.new(2, 10, 90 - HALF), Position = Vector3.new(1, 5, z * (HALF + (90 - HALF) / 2)), Color = PALETTE.Rock, Parent = hub })
end
-- start banner over the track entrance
for _, side in ipairs({ -1, 1 }) do
	part({ Size = Vector3.new(4, 24, 4), Position = Vector3.new(4, 12, side * (HALF + 2)), Color = PALETTE.RockDark, Parent = hub })
end
sign(Vector3.new(4, 21, 0), Vector3.new(-1, 0, 0), Vector2.new(46, 7), "🌋 RUN! GRAB CRITTERS! HIDE FROM THE LAVA! 🌋", Color3.fromRGB(200, 60, 30))

local spawnLoc = Instance.new("SpawnLocation")
spawnLoc.Anchored = true
spawnLoc.Size = Vector3.new(10, 0.4, 10)
spawnLoc.Position = Vector3.new(-70, 0.2, 0)
spawnLoc.Transparency = 1
spawnLoc.CanCollide = false
spawnLoc.Duration = 0
spawnLoc.Parent = world

-- 8 bases: 4 on each side of the hub
local plots = {}
local BASE_XS = { -138, -102, -66, -30 }
local SLOT_COLS = { -10.5, -3.5, 3.5, 10.5 }
local SLOT_ROWS = { 58, 65, 72 }
local critterFolder = Instance.new("Folder")
critterFolder.Name = "Critters"
critterFolder.Parent = world

for i = 1, 8 do
	local side = i <= 4 and 1 or -1
	local cx = BASE_XS[(i - 1) % 4 + 1]
	local accent = ACCENTS[i]
	local model = Instance.new("Model")
	model.Name = "Base" .. i
	model.Parent = world
	local plot = { Index = i, X = cx, Side = side, Slots = {}, Displays = {}, Model = model }
	local function at(v) -- local (x, y, distance from hub center line) -> world
		return Vector3.new(cx + v.X, v.Y, side * v.Z)
	end
	plot.At = at
	part({ Name = "Platform", Size = Vector3.new(32, 1, 36), Position = at(Vector3.new(0, 0.5, 62)), Color = PALETTE.RockLight, Parent = model })
	part({ Name = "Floor", Size = Vector3.new(29, 0.2, 33), Position = at(Vector3.new(0, 1.1, 62)), Color = accent:Lerp(Color3.new(1, 1, 1), 0.65), Parent = model })
	-- low glowing edge so you can see where "home" is
	for _, dx in ipairs({ -15.6, 15.6 }) do
		part({ Size = Vector3.new(0.6, 0.5, 36), Position = at(Vector3.new(dx, 1.25, 62)), Color = accent, Material = Enum.Material.Neon,
			CanCollide = false, Parent = model })
	end
	part({ Size = Vector3.new(32, 0.5, 0.6), Position = at(Vector3.new(0, 1.25, 44.2)), Color = accent, Material = Enum.Material.Neon,
		CanCollide = false, Parent = model })
	-- back wall and corner torches
	part({ Size = Vector3.new(32, 9, 1.5), Position = at(Vector3.new(0, 5.5, 80)), Color = PALETTE.Rock, Parent = model })
	for _, dx in ipairs({ -15, 15 }) do
		local base = at(Vector3.new(dx, 1, 79))
		part({ Size = Vector3.new(2, 10, 2), Position = base + Vector3.new(0, 5, 0), Color = PALETTE.RockDark, Parent = model })
		local fire = part({ Size = Vector3.new(2.6, 1, 2.6), Position = base + Vector3.new(0, 10.5, 0), Color = accent, Material = Enum.Material.Neon,
			Parent = model })
		emitter(fire, { Texture = "rbxasset://textures/particles/fire_main.dds", Color = ColorSequence.new(accent:Lerp(Color3.new(1, 1, 1), 0.4), accent),
			Size = NumberSequence.new(2.2, 0.3), LightEmission = 1, Lifetime = NumberRange.new(0.6, 1), Rate = 18, Speed = NumberRange.new(3, 6),
			SpreadAngle = Vector2.new(10, 10) })
	end
	local _, signLabels = sign(at(Vector3.new(0, 12.5, 80)), Vector3.new(0, 0, -side), Vector2.new(26, 5), "Empty Base", accent)
	plot.SignLabels = signLabels
	-- pedestals
	local slot = 0
	for _, dz in ipairs(SLOT_ROWS) do
		for _, dx in ipairs(SLOT_COLS) do
			slot += 1
			local c = at(Vector3.new(dx, 1.2, dz))
			local ped = cyl(c, 1.2, 5, PALETTE.RockDark, model, { Name = "Pedestal" })
			cyl(c + Vector3.new(0, 1.2, 0), 0.2, 4.2, accent, model, { Material = Enum.Material.Neon, CanCollide = false })
			if slot > Config.BaseSlots then
				ped.Transparency = 0.6
				local lbl = billboard(ped, { { Text = "👑 VIP Slot", Color = Color3.fromRGB(255, 220, 90) } }, 2.5, 110, 30)
				lbl[1].Parent:SetAttribute("Plot", i) -- only the owner sees it (client)
			end
			plot.Slots[slot] = ped
		end
	end
	plot.CollectPad = cyl(at(Vector3.new(9, 1, 49)), 0.5, 8, Color3.fromRGB(70, 220, 100), model, { Name = "CollectPad" })
	cyl(at(Vector3.new(9, 1, 49)), 0.4, 9.4, Color3.fromRGB(40, 150, 70), model, { CanCollide = false })
	plot.CollectLabel = billboard(plot.CollectPad, { { Text = "💰 COLLECT" }, { Text = "$0", Color = Color3.fromRGB(120, 255, 120) } }, 4, 150, 56)
	plot.CollectLabel[1].Parent:SetAttribute("Plot", i)
	plot.UpgradePad = cyl(at(Vector3.new(-9, 1, 49)), 0.5, 8, Color3.fromRGB(80, 160, 255), model, { Name = "UpgradePad" })
	cyl(at(Vector3.new(-9, 1, 49)), 0.4, 9.4, Color3.fromRGB(40, 90, 180), model, { CanCollide = false })
	local up = billboard(plot.UpgradePad, { { Text = "⚡ UPGRADES" } }, 4, 150, 30)
	up[1].Parent:SetAttribute("Plot", i)
	plots[i] = plot
end

local function inOwnBase(plot, pos)
	return math.abs(pos.X - plot.X) <= 16 and pos.Z * plot.Side >= 43 and pos.Z * plot.Side <= 81 and pos.Y < 20
end

---------------------------------------------------------------------------
-- Critter models (built once per type, then cloned)
---------------------------------------------------------------------------
local protos = Instance.new("Folder")
protos.Name = "CritterProtos"
protos.Parent = ServerStorage

local function weldTo(body, p)
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = body
	w.Part1 = p
	w.Parent = p
	p.Parent = body.Parent
end

local function buildCritter(def)
	local _, ri = Config.Rarity(def.Rarity)
	local s = 1 + (ri - 1) * 0.16
	local m = Instance.new("Model")
	m.Name = def.Name
	local bodySize = Vector3.new(2.8, def.Tall and 3.4 or 2.6, 2.8) * s
	local body = ellipsoid(bodySize, CFrame.new(), def.Color, m, { Name = "Body", CanCollide = false })
	m.PrimaryPart = body
	local function add(size, offset, color, props)
		local p = ellipsoid(size * s, CFrame.new(offset * s), color, m, props)
		weldTo(body, p)
		return p
	end
	local function addBlock(size, cf, color, props)
		local p = part({ Size = size * s, CFrame = cf, Color = color, Parent = m })
		for k, v in pairs(props or {}) do
			(p :: any)[k] = v
		end
		weldTo(body, p)
		return p
	end
	local hy = (def.Tall and 1.7 or 1.3)
	-- glowing magma cracks / spots
	local srng = Random.new(#def.Name * 97 + ri)
	for _ = 1, 4 + ri do
		local theta = srng:NextNumber(0.9, 2.5)
		local phi = srng:NextNumber(math.pi * 0.2, math.pi * 1.8)
		local dir = Vector3.new(math.sin(theta) * math.cos(phi) * 1.4, math.cos(theta) * hy, math.sin(theta) * math.sin(phi) * 1.4) * 0.97
		local d = srng:NextNumber(0.35, 0.7)
		local spot = ellipsoid(Vector3.new(d, d, d * 0.4) * s, CFrame.lookAt(dir * s, dir * s * 2), def.Glow, m,
			{ Material = Enum.Material.Neon })
		weldTo(body, spot)
	end
	-- face (looks toward -X, i.e. toward the hub, so critters face runners coming in)
	for _, ez in ipairs({ -0.55, 0.55 }) do
		add(Vector3.new(0.5, 0.9, 0.75), Vector3.new(-1.2, 0.35, ez), Color3.new(1, 1, 1))
		add(Vector3.new(0.3, 0.55, 0.45), Vector3.new(-1.42, 0.3, ez * 1.05), ri >= 6 and def.Glow or Color3.fromRGB(20, 15, 25),
			ri >= 6 and { Material = Enum.Material.Neon } or nil)
		add(Vector3.new(0.12, 0.2, 0.2), Vector3.new(-1.55, 0.45, ez * 1.05 - 0.08), Color3.new(1, 1, 1))
		add(Vector3.new(0.2, 0.3, 0.5), Vector3.new(-1.25, -0.25, ez * 1.45), Color3.fromRGB(255, 140, 150)) -- blush
	end
	add(Vector3.new(0.25, 0.25, 0.6), Vector3.new(-1.38, -0.25, 0), Color3.fromRGB(60, 20, 30)) -- mouth
	-- feet
	for _, fz in ipairs({ -0.7, 0.7 }) do
		add(Vector3.new(1, 0.5, 0.8), Vector3.new(-0.3, -hy + 0.1, fz), def.Color:Lerp(Color3.new(0, 0, 0), 0.35))
	end
	if def.Horns then
		for _, hz in ipairs({ -0.6, 0.6 }) do
			addBlock(Vector3.new(0.45, 1.2, 0.45), CFrame.new(Vector3.new(0, hy + 0.3, hz) * s) * CFrame.Angles(math.rad(hz * 40), 0, math.rad(10)),
				def.Glow:Lerp(Color3.new(1, 1, 1), 0.3), { Material = Enum.Material.Neon })
		end
	end
	if def.Ears then
		for _, ez in ipairs({ -0.75, 0.75 }) do
			add(Vector3.new(0.5, def.Tall and 1.8 or 1.1, 0.7), Vector3.new(0.1, hy + (def.Tall and 0.6 or 0.25), ez), def.Color)
			add(Vector3.new(0.3, def.Tall and 1.3 or 0.7, 0.4), Vector3.new(-0.08, hy + (def.Tall and 0.6 or 0.25), ez), def.Glow)
		end
	end
	if def.Wings then
		for _, wz in ipairs({ -1, 1 }) do
			add(Vector3.new(1.6, 1.2, 2.4), Vector3.new(0.5, 0.4, wz * 1.9), def.Glow, { Material = Enum.Material.Neon, Transparency = 0.25 })
		end
	end
	if def.Halo then
		for k = 0, 9 do
			local a = k / 10 * math.pi * 2
			add(Vector3.new(0.35, 0.35, 0.35), Vector3.new(math.cos(a) * 0.9, hy + 1.1, math.sin(a) * 0.9), Color3.fromRGB(255, 240, 150),
				{ Material = Enum.Material.Neon })
		end
	end
	if def.Crown then
		addBlock(Vector3.new(1.4, 0.5, 1.4), CFrame.new(Vector3.new(0, hy + 0.35, 0) * s), PALETTE.Gold, { Material = Enum.Material.Neon })
		for k = 0, 3 do
			local a = k / 4 * math.pi * 2
			addBlock(Vector3.new(0.3, 0.6, 0.3), CFrame.new(Vector3.new(math.cos(a) * 0.6, hy + 0.8, math.sin(a) * 0.6) * s), PALETTE.Gold,
				{ Material = Enum.Material.Neon })
		end
	end
	if ri >= 3 then
		emitter(body, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(Config.Rarities[ri].Color),
			LightEmission = 1, Size = NumberSequence.new(0.5, 0), Lifetime = NumberRange.new(0.6, 1.2), Rate = 3 + (ri - 3) * 5,
			Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180) })
	end
	if ri >= 5 then
		local light = Instance.new("PointLight")
		light.Color = def.Glow
		light.Range = 10 + ri * 2
		light.Brightness = 2
		light.Parent = body
	end
	m:SetAttribute("Critter", def.Name)
	m:SetAttribute("Rarity", ri)
	m.Parent = protos
	return m
end

for _, def in ipairs(Config.Critters) do
	buildCritter(def)
end

local function newCritter(name)
	local proto = protos:FindFirstChild(name)
	return proto and proto:Clone() or nil
end

local function labelCritter(model, def, extra)
	local r, ri = Config.Rarity(def.Rarity)
	local lines = {
		{ Text = def.Name, Color = Color3.new(1, 1, 1) },
		{ Text = def.Rarity, Color = ri == 7 and Color3.fromRGB(255, 120, 255) or r.Color },
		{ Text = "$" .. Config.Format(def.Income) .. "/s", Color = Color3.fromRGB(120, 255, 120) },
	}
	if extra then
		lines[#lines + 1] = extra
	end
	local size = model.PrimaryPart.Size.Y
	billboard(model.PrimaryPart, lines, size / 2 + 1.6, 170, 22 * #lines, 70)
end

---------------------------------------------------------------------------
-- Player state
---------------------------------------------------------------------------
local S = {}
local luckUntil = 0 -- server time
local frozenUntil = 0

local function hasPass(player, key)
	return player:GetAttribute("Pass_" .. key) == true
end

local function maxSlots(player)
	return Config.BaseSlots + (hasPass(player, "VIP") and Config.VipSlots or 0)
end

local function capacity(player)
	local s = S[player]
	return Config.Capacity(s and s.CarryLvl or 0, hasPass(player, "DoubleCarry"))
end

local function walkSpeed(player)
	local s = S[player]
	local base = Config.BaseSpeed + (s and s.SpeedLvl or 0) * Config.SpeedPerLevel
	return base * (hasPass(player, "Speed") and 1.3 or 1)
end

local function applySpeed(player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = walkSpeed(player)
	end
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
	for _, name in pairs(s.Base) do
		local def = Config.Critter(name)
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

local function syncStats(player)
	local s = S[player]
	player:SetAttribute("Income", incomeOf(player))
	player:SetAttribute("SpeedLvl", s.SpeedLvl)
	player:SetAttribute("CarryLvl", s.CarryLvl)
	player:SetAttribute("Capacity", capacity(player))
	player:SetAttribute("Carry", #s.Carry)
	player:SetAttribute("Shields", s.Shields)
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

local function placeInBase(player, slot, name)
	local s = S[player]
	local plot = plots[s.Plot]
	local def = Config.Critter(name)
	local m = def and newCritter(name)
	if not m then
		return
	end
	s.Base[slot] = name
	local ped = plot.Slots[slot]
	local body = m.PrimaryPart
	body.Anchored = true
	-- face the hub center line
	m:PivotTo(CFrame.lookAt(ped.Position + Vector3.new(0, 1 + body.Size.Y / 2, 0), ped.Position + Vector3.new(0, 1 + body.Size.Y / 2, -plot.Side * 10))
		* CFrame.Angles(0, math.rad(-90), 0))
	m:SetAttribute("OwnerId", player.UserId)
	m:SetAttribute("Slot", slot)
	m:SetAttribute("Display", true)
	labelCritter(m, def)
	local p = Instance.new("ProximityPrompt")
	p.Name = "Sell"
	p.ActionText = "Sell $" .. Config.Format(Config.SellValue(def))
	p.ObjectText = def.Name
	p.HoldDuration = 0.8
	p.MaxActivationDistance = 9
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.F
	p.Parent = body
	p.Triggered:Connect(function(who)
		if who ~= player or not m.Parent or S[player] == nil or S[player].Base[slot] ~= name then
			return
		end
		s.Base[slot] = nil
		m:Destroy()
		plot.Displays[slot] = nil
		setCash(player, s.Cash + Config.SellValue(def))
		player:SetAttribute("Income", incomeOf(player))
		fx(player, "Collect", Config.SellValue(def))
	end)
	m.Parent = critterFolder
	plot.Displays[slot] = m
	player:SetAttribute("Income", incomeOf(player))
end

local function clearBase(player)
	local s = S[player]
	local plot = plots[s.Plot]
	for slot, m in pairs(plot.Displays) do
		m:Destroy()
		plot.Displays[slot] = nil
	end
	s.Base = {}
end

local function freeSlot(player)
	local s = S[player]
	for slot = 1, maxSlots(player) do
		if not s.Base[slot] then
			return slot
		end
	end
	return nil
end

local function refreshVipSlots(player)
	local s = S[player]
	if not s or not s.Plot then
		return
	end
	local unlocked = hasPass(player, "VIP")
	for slot = Config.BaseSlots + 1, Config.BaseSlots + Config.VipSlots do
		local ped = plots[s.Plot].Slots[slot]
		ped.Transparency = unlocked and 0 or 0.6
		local bb = ped:FindFirstChildOfClass("BillboardGui")
		if bb then
			bb:SetAttribute("Unlocked", unlocked)
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
	refreshVipSlots(player)
	if S[player] and S[player].Loaded then
		syncStats(player)
		applySpeed(player)
	end
end

---------------------------------------------------------------------------
-- Carrying critters (a little stack above your head)
---------------------------------------------------------------------------
local function clearCarryModels(player)
	local s = S[player]
	for _, m in ipairs(s.CarryModels) do
		m:Destroy()
	end
	s.CarryModels = {}
end

local function rebuildCarryModels(player)
	local s = S[player]
	clearCarryModels(player)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then
		return
	end
	local y = 2.2
	for i, name in ipairs(s.Carry) do
		if i > 6 then
			break -- the stack stops growing visually; the counter shows the rest
		end
		local m = newCritter(name)
		if m then
			m:ScaleTo(0.6)
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BillboardGui") or d:IsA("ProximityPrompt") then
					d:Destroy()
				end
			end
			local body = m.PrimaryPart
			body.Anchored = false
			body.Massless = true
			body.CanCollide = false
			body.CanQuery = false
			body.CanTouch = false
			local h = body.Size.Y
			m:PivotTo(head.CFrame * CFrame.new(0, y + h / 2, 0) * CFrame.Angles(0, math.rad(-90), 0))
			y += h * 0.85
			local w = Instance.new("WeldConstraint")
			w.Part0 = head
			w.Part1 = body
			w.Parent = body
			m.Parent = char
			s.CarryModels[#s.CarryModels + 1] = m
		end
	end
	player:SetAttribute("Carry", #s.Carry)
end

---------------------------------------------------------------------------
-- Critter spawns in the zones
---------------------------------------------------------------------------
local function pickRarity(zone)
	local weights
	if zone < 7 then
		weights = { { zone, 80 }, { zone + 1, 16 }, { zone + 2, 4 } }
	else
		weights = { { 6, 82 }, { 7, 18 } }
	end
	local lucky = luckUntil > workspace:GetServerTimeNow()
	local total = 0
	for k, w in ipairs(weights) do
		if w[1] > 7 then
			w[2] = 0
		elseif lucky and k > 1 then
			w[2] *= 3
		end
		total += w[2]
	end
	local roll = math.random() * total
	for _, w in ipairs(weights) do
		roll -= w[2]
		if roll <= 0 then
			return w[1]
		end
	end
	return zone
end

local function critterOfRarity(ri)
	local options = {}
	for _, c in ipairs(Config.Critters) do
		if c.Rarity == Config.Rarities[ri].Name then
			options[#options + 1] = c
		end
	end
	return options[math.random(1, #options)]
end

local spawnSpots = {} -- zone -> { {Pos, Model} }
for z = 1, #Config.ZoneNames do
	local x0 = Config.TrackStart + (z - 1) * Config.ZoneLength
	spawnSpots[z] = {}
	for k = 1, Config.CrittersPerZone do
		local x = x0 + 12 + (k - 1) * (Config.ZoneLength - 24) / (Config.CrittersPerZone - 1)
		local zz = ((k % 2 == 0) and 1 or -1) * rng:NextNumber(4, HALF - 6)
		spawnSpots[z][k] = { Pos = Vector3.new(x, 0, zz), Model = nil }
	end
end

local grab -- forward declared

local function spawnAt(zone, spot)
	local ri = pickRarity(zone)
	local def = critterOfRarity(ri)
	local m = newCritter(def.Name)
	if not m then
		return
	end
	local body = m.PrimaryPart
	body.Anchored = true
	m:PivotTo(CFrame.new(spot.Pos + Vector3.new(0, body.Size.Y / 2 + 0.6, 0)) * CFrame.Angles(0, rng:NextNumber(-0.6, 0.6), 0))
	labelCritter(m, def)
	local p = Instance.new("ProximityPrompt")
	p.Name = "Grab"
	p.ActionText = "Grab"
	p.ObjectText = def.Name .. " (" .. def.Rarity .. ")"
	p.HoldDuration = 0.35
	p.MaxActivationDistance = 11
	p.RequiresLineOfSight = false
	p.Parent = body
	p.Triggered:Connect(function(player)
		grab(player, m, def, zone, spot)
	end)
	m:SetAttribute("Wild", true)
	m.Parent = critterFolder
	spot.Model = m
	if ri >= 6 then
		announce("✨ A " .. string.upper(def.Rarity) .. " " .. def.Name .. " appeared in " .. Config.ZoneNames[zone] .. "! ✨",
			Config.Rarities[ri].Color)
	end
end

function grab(player, m, def, zone, spot)
	local s = S[player]
	if not s or not s.Loaded or not m.Parent or spot.Model ~= m then
		return
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	if #s.Carry >= capacity(player) then
		fx(player, "Full", capacity(player))
		return
	end
	spot.Model = nil
	m:Destroy()
	table.insert(s.Carry, def.Name)
	rebuildCarryModels(player)
	local new = discover(player, def.Name)
	fx(player, "Grabbed", def.Name, def.Rarity, new)
	task.delay(Config.RespawnTime, function()
		if not spot.Model then
			spawnAt(zone, spot)
		end
	end)
end

for z, spots in ipairs(spawnSpots) do
	for _, spot in ipairs(spots) do
		spawnAt(z, spot)
	end
end

---------------------------------------------------------------------------
-- Lava waves (server decides timing and kills; clients draw the wave from the same clock)
---------------------------------------------------------------------------
workspace:SetAttribute("WaveFrom", WAVE_FROM)
workspace:SetAttribute("WaveTo", WAVE_TO)
workspace:SetAttribute("WaveStart", 0)
workspace:SetAttribute("NextWave", 0)

local function pickWave()
	local total = 0
	for _, k in ipairs(Config.WaveKinds) do
		total += k.Weight
	end
	local roll = math.random() * total
	for _, k in ipairs(Config.WaveKinds) do
		roll -= k.Weight
		if roll <= 0 then
			return k
		end
	end
	return Config.WaveKinds[1]
end

local function dropCarry(player)
	local s = S[player]
	if not s or #s.Carry == 0 then
		return nil
	end
	local lost = s.Carry
	s.Carry = {}
	clearCarryModels(player)
	player:SetAttribute("Carry", 0)
	return lost
end

local function wipeOut(player, root, noShield)
	local s = S[player]
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not s or not hum or hum.Health <= 0 then
		return
	end
	if s.Shields > 0 and not noShield then
		s.Shields -= 1
		player:SetAttribute("Shields", s.Shields)
		fx(player, "Shielded")
		-- pop them into the nearest safe pocket
		local best, bestD = nil, math.huge
		for _, ax in ipairs(alcoveXs) do
			local d = math.abs(ax - root.Position.X)
			if d < bestD then
				best, bestD = ax, d
			end
		end
		if best then
			player.Character:PivotTo(CFrame.new(best, 4, (root.Position.Z >= 0 and 1 or -1) * (HALF + Config.AlcoveDepth / 2)))
		end
		return
	end
	local lost = dropCarry(player)
	if lost then
		s.Lost = { Names = lost, At = os.clock(), X = root.Position.X, Z = root.Position.Z }
	end
	hum.Health = 0
	fx(player, "WipedOut", lost and #lost or 0)
end

local function runWave(kind)
	local now = workspace:GetServerTimeNow()
	local start = now + Config.WaveWarning
	workspace:SetAttribute("WaveName", kind.Name)
	workspace:SetAttribute("WaveSpeed", kind.Speed)
	workspace:SetAttribute("WaveHeight", kind.Height)
	workspace:SetAttribute("WaveStart", start)
	FxRE:FireAllClients("WaveWarning", kind.Name, Config.WaveWarning)
	local duration = (WAVE_FROM - WAVE_TO) / kind.Speed
	task.wait(Config.WaveWarning)
	while workspace:GetServerTimeNow() < start + duration do
		local front = WAVE_FROM - kind.Speed * (workspace:GetServerTimeNow() - start)
		for player, s in pairs(S) do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if s.Loaded and root then
				local p = root.Position
				if p.X >= front - 2 and p.X <= front + Config.WaveThickness and math.abs(p.Z) < HALF + 0.5 and p.X > 0 then
					wipeOut(player, root)
				end
			end
		end
		task.wait(0.08)
	end
	workspace:SetAttribute("WaveStart", 0)
end

task.spawn(function()
	task.wait(8)
	while true do
		local gap = math.random(Config.WaveGapMin, Config.WaveGapMax)
		workspace:SetAttribute("NextWave", workspace:GetServerTimeNow() + gap + Config.WaveWarning)
		task.wait(gap)
		while frozenUntil > workspace:GetServerTimeNow() do
			workspace:SetAttribute("NextWave", frozenUntil + 3 + Config.WaveWarning)
			task.wait(1)
		end
		runWave(pickWave())
	end
end)

-- falling into the lava sea is a wipe-out too
lavaSea.Touched:Connect(function(hit)
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and S[player] then
		wipeOut(player, root, true) -- shields only protect from waves
	end
end)

---------------------------------------------------------------------------
-- Depositing, income, best zone
---------------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(0.2)
		for player, s in pairs(S) do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if s.Loaded and root then
				local zone = Config.ZoneAt(root.Position.X)
				if zone > s.BestZone and math.abs(root.Position.Z) < HALF + 20 then
					s.BestZone = zone
					player:SetAttribute("BestZone", zone)
					player.leaderstats["Best Zone"].Value = zone
				end
				if #s.Carry > 0 and inOwnBase(plots[s.Plot], root.Position) then
					local carried = dropCarry(player) or {}
					local placed, sold, best = 0, 0, 1
					for _, name in ipairs(carried) do
						local def = Config.Critter(name)
						if def then
							local _, ri = Config.Rarity(def.Rarity)
							best = math.max(best, ri)
							local slot = freeSlot(player)
							if slot then
								placeInBase(player, slot, name)
								placed += 1
							else
								sold += Config.SellValue(def)
							end
						end
					end
					if sold > 0 then
						setCash(player, s.Cash + sold)
					end
					fx(player, "Deposited", placed, sold, best)
					if best >= 5 then
						announce("🌋 " .. player.DisplayName .. " escaped with a " .. Config.Rarities[best].Name .. " critter!",
							Config.Rarities[best].Color)
					end
				end
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		for player, s in pairs(S) do
			if s.Loaded then
				s.Uncollected += incomeOf(player)
				plots[s.Plot].CollectLabel[2].Text = "$" .. Config.Format(s.Uncollected)
			end
		end
	end
end)

local touchDebounce = {}
local function onPad(plot, kind)
	return function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		local s = player and S[player]
		if not s or not s.Loaded or s.Plot ~= plot.Index then
			return
		end
		local key = player.UserId .. kind
		if touchDebounce[key] then
			return
		end
		touchDebounce[key] = true
		task.delay(kind == "Upgrade" and 2 or 0.5, function()
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
			fx(player, "OpenUpgrades")
		end
	end
end
for _, plot in ipairs(plots) do
	plot.CollectPad.Touched:Connect(onPad(plot, "Collect"))
	plot.UpgradePad.Touched:Connect(onPad(plot, "Upgrade"))
end

---------------------------------------------------------------------------
-- Join / leave / save
---------------------------------------------------------------------------
local function save(player)
	local s = S[player]
	if not s or not s.Loaded then
		return
	end
	local base = {}
	for slot, name in pairs(s.Base) do
		base[tostring(slot)] = name
	end
	local data = { Cash = s.Cash, Rebirths = s.Rebirths, Base = base, Discovered = s.Discovered, LastDaily = s.LastDaily,
		SpeedLvl = s.SpeedLvl, CarryLvl = s.CarryLvl, Shields = s.Shields, BestZone = s.BestZone }
	local ok, err = pcall(function()
		store:SetAsync(tostring(player.UserId), data)
	end)
	if not ok then
		warn("Save failed for", player.Name, err)
	end
end

local function nearestAlcove(x, z)
	local best, bestD = alcoveXs[1], math.huge
	for _, ax in ipairs(alcoveXs) do
		local d = math.abs(ax - x)
		if d < bestD then
			best, bestD = ax, d
		end
	end
	return CFrame.new(best, 4, (z >= 0 and 1 or -1) * (HALF + Config.AlcoveDepth / 2))
end

local function applyRevive(player)
	local s = S[player]
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not s.PendingRevive or not hum or hum.Health <= 0 then
		return false
	end
	local r = s.PendingRevive
	s.PendingRevive = nil
	for _, name in ipairs(r.Names) do
		table.insert(s.Carry, name)
	end
	char:PivotTo(nearestAlcove(r.X, r.Z))
	rebuildCarryModels(player)
	fx(player, "Revived", #r.Names)
	return true
end

local function onCharacter(player, char)
	local s = S[player]
	local hum = char:WaitForChild("Humanoid")
	hum.WalkSpeed = walkSpeed(player)
	char:WaitForChild("HumanoidRootPart")
	s.Carry = s.Carry or {}
	if #s.Carry > 0 then
		s.Carry = {}
	end
	s.CarryModels = {}
	player:SetAttribute("Carry", 0)
	task.wait()
	if s.PendingRevive then
		applyRevive(player)
	else
		local plot = plots[s.Plot]
		char:PivotTo(CFrame.lookAt(plot.At(Vector3.new(0, 4, 50)), plot.At(Vector3.new(0, 4, 0))))
	end
	if hasPass(player, "VIP") then
		local head = char:WaitForChild("Head")
		local labels = billboard(head, { { Text = "👑 VIP", Color = Color3.fromRGB(255, 210, 50) } }, 2.5, 100, 26)
		labels[1].Parent.MaxDistance = 80
	end
	hum.Died:Connect(function()
		local root = char:FindFirstChild("HumanoidRootPart")
		if S[player] == s and #s.Carry > 0 and root then
			local lost = dropCarry(player)
			if lost then
				s.Lost = { Names = lost, At = os.clock(), X = root.Position.X, Z = root.Position.Z }
				fx(player, "WipedOut", #lost)
			end
		end
	end)
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
	for _, n in ipairs({ "Cash", "Best Zone", "Rebirths" }) do
		local v = Instance.new("NumberValue")
		v.Name = n
		v.Parent = ls
	end

	local s = { Plot = plotIndex, Cash = 0, Rebirths = 0, Base = {}, Discovered = {}, LastDaily = 0, SpeedLvl = 0, CarryLvl = 0,
		Shields = 0, BestZone = 0, Carry = {}, CarryModels = {}, Uncollected = 0, GiftAt = os.time() + Config.GiftInterval }
	S[player] = s
	local plot = plots[plotIndex]
	for _, l in ipairs(plot.SignLabels) do
		l.Text = player.DisplayName .. "'s Base"
	end
	player:SetAttribute("Plot", plotIndex)

	local ok, data = pcall(function()
		return store:GetAsync(tostring(player.UserId))
	end)
	if not ok then
		player:Kick("Could not load your data, please rejoin.")
		return
	end
	data = data or {}
	s.Rebirths = data.Rebirths or 0
	s.SpeedLvl = data.SpeedLvl or 0
	s.CarryLvl = data.CarryLvl or 0
	s.Shields = data.Shields or 0
	s.BestZone = data.BestZone or 0
	s.Discovered = data.Discovered or {}
	s.LastDaily = data.LastDaily or 0
	setCash(player, data.Cash or 0)
	ls.Rebirths.Value = s.Rebirths
	ls["Best Zone"].Value = s.BestZone
	player:SetAttribute("Rebirths", s.Rebirths)
	player:SetAttribute("BestZone", s.BestZone)
	player:SetAttribute("LastDaily", s.LastDaily)
	player:SetAttribute("GiftAt", s.GiftAt)
	s.Loaded = true
	refreshPasses(player)
	for slotStr, name in pairs(data.Base or {}) do
		local slot = tonumber(slotStr)
		if slot and slot <= maxSlots(player) then
			placeInBase(player, slot, name)
		end
	end
	syncDiscovered(player)
	syncStats(player)

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
	save(player)
	clearBase(player)
	local plot = plots[s.Plot]
	plot.Owner = nil
	for _, l in ipairs(plot.SignLabels) do
		l.Text = "Empty Base"
	end
	plot.CollectLabel[2].Text = "$0"
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
-- Actions from the client: upgrades, rebirth, gifts, daily, purchases
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
	if not s or not s.Loaded or type(action) ~= "string" then
		return
	end
	local now = os.time()
	if action == "Buy" then
		promptBuy(player, a, b)
	elseif action == "Upgrade" then
		local level, maxLevel, cost
		if a == "Speed" then
			level, maxLevel, cost = s.SpeedLvl, Config.MaxSpeedLevel, Config.SpeedCost(s.SpeedLvl)
		elseif a == "Carry" then
			level, maxLevel, cost = s.CarryLvl, Config.MaxCarryLevel, Config.CarryCost(s.CarryLvl)
		else
			return
		end
		if level >= maxLevel then
			fx(player, "Toast", "Already MAX!")
			return
		end
		if s.Cash < cost then
			fx(player, "Broke", cost)
			return
		end
		setCash(player, s.Cash - cost)
		if a == "Speed" then
			s.SpeedLvl += 1
			applySpeed(player)
		else
			s.CarryLvl += 1
		end
		syncStats(player)
		fx(player, "Upgraded", a, a == "Speed" and s.SpeedLvl or s.CarryLvl)
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
		else
			fx(player, "Toast", "Daily reward already claimed. Come back tomorrow!")
		end
	elseif action == "Rebirth" then
		local cost = Config.RebirthCost(s.Rebirths)
		if s.Cash < cost then
			fx(player, "Broke", cost)
			return
		end
		clearBase(player)
		s.Rebirths += 1
		player:SetAttribute("Rebirths", s.Rebirths)
		player.leaderstats.Rebirths.Value = s.Rebirths
		setCash(player, 0)
		s.Uncollected = 0
		syncStats(player)
		save(player)
		fx(player, "Rebirth", s.Rebirths)
		announce("🔄 " .. player.DisplayName .. " just reached Rebirth " .. s.Rebirths .. "!", Color3.fromRGB(200, 120, 255))
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
	local prod
	for _, p in ipairs(Config.Products) do
		if p.Id ~= 0 and p.Id == receipt.ProductId then
			prod = p
		end
	end
	if not prod then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local now = workspace:GetServerTimeNow()
	local scale = (1 + s.Rebirths) ^ 2
	if prod.Cash then
		setCash(player, s.Cash + prod.Cash * scale)
	elseif prod.Key == "Starter" then
		setCash(player, s.Cash + 3000 * scale)
		s.SpeedLvl = math.min(s.SpeedLvl + 2, Config.MaxSpeedLevel)
		applySpeed(player)
		syncStats(player)
	elseif prod.Key == "Revive" then
		if s.Lost and os.clock() - s.Lost.At < 45 then
			s.PendingRevive = s.Lost
			s.Lost = nil
			applyRevive(player) -- if they're still dead, it applies on respawn
		else
			s.Shields += 1
			player:SetAttribute("Shields", s.Shields)
			fx(player, "Toast", "🛡️ Lava Shield ready! It saves you from the next wave.")
		end
	elseif prod.Key == "Freeze" then
		frozenUntil = math.max(frozenUntil, now) + Config.FreezeTime
		workspace:SetAttribute("FrozenUntil", frozenUntil)
		announce("🧊 " .. player.DisplayName .. " FROZE the lava for everyone!", Color3.fromRGB(140, 220, 255))
	elseif prod.Key == "Luck" then
		luckUntil = math.max(luckUntil, now) + 900
		workspace:SetAttribute("LuckUntil", luckUntil)
		announce("🍀 " .. player.DisplayName .. " activated SERVER LUCK x3 for everyone!", Color3.fromRGB(90, 255, 120))
	end
	save(player)
	fx(player, "Thanks")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

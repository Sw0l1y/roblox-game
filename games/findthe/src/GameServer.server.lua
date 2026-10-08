-- ServerScriptService.GameServer ("Find the Dragon Eggs")
-- Loop: explore 5 themed zones, find 100 hidden dragon eggs (click or touch them).
-- Finding eggs opens new zones; hints point at the nearest egg; radar/glow/double jump help hunters.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local okAssets, Assets = pcall(function()
	return require(ReplicatedStorage:WaitForChild("Assets", 5))
end)
if not okAssets or type(Assets) ~= "table" then
	Assets = {}
end
local store = DataStoreService:GetDataStore("FindEggs_v1")
local lbStore = DataStoreService:GetOrderedDataStore("FindEggsLB_v1")

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
-- Lighting (the client tints it per zone)
---------------------------------------------------------------------------
Lighting.ClockTime = 14.5
Lighting.Brightness = 2.6
Lighting.Ambient = Color3.fromRGB(110, 100, 130)
Lighting.OutdoorAmbient = Color3.fromRGB(165, 160, 195)
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 0.6
local atmo = Instance.new("Atmosphere")
atmo.Density = 0.28
atmo.Offset = 0.1
atmo.Color = Color3.fromRGB(205, 225, 255)
atmo.Decay = Color3.fromRGB(150, 170, 230)
atmo.Glare = 0.3
atmo.Haze = 1.1
atmo.Parent = Lighting
local rays = Instance.new("SunRaysEffect")
rays.Intensity = 0.06
rays.Spread = 0.6
rays.Parent = Lighting
local clouds = Instance.new("Clouds")
clouds.Cover = 0.5
clouds.Density = 0.6
clouds.Parent = workspace.Terrain
local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "ZoneTint"
cc.Saturation = 0.25
cc.Contrast = 0.08
cc.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.5
bloom.Threshold = 1.6
bloom.Parent = Lighting

---------------------------------------------------------------------------
-- Building helpers (flat SmoothPlastic/Neon colors, no stock material textures)
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

local function ball(pos, d, color, parent, props)
	local p = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d), Position = pos, Color = color, Parent = parent })
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

-- box from local min/max corners, placed relative to a CFrame
local function block(cf, x0, x1, y0, y1, z0, z1, color, parent, props)
	local size = Vector3.new(x1 - x0, y1 - y0, z1 - z0)
	local p = part({ Size = size, CFrame = cf * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), Color = color, Parent = parent })
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return p
end

local function billboard(adornee, lines, offsetY, width, height, maxDistance)
	local bb = Instance.new("BillboardGui")
	-- sized in studs (not pixels) so labels shrink with distance instead of cluttering the screen
	bb.Size = UDim2.fromScale((width or 200) / 26, (height or 70) / 26)
	bb.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	bb.MaxDistance = maxDistance or 90
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

local function surfaceText(board, face, str, bg, canvas)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.CanvasSize = canvas or Vector2.new(600, 200)
	sg.LightInfluence = 0.2
	sg.Parent = board
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundColor3 = bg or Color3.fromRGB(60, 40, 90)
	l.BackgroundTransparency = bg and 0 or 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0
	l.Text = str
	l.Parent = sg
	local s = Instance.new("UIStroke")
	s.Thickness = 8
	s.Color = Color3.fromRGB(34, 26, 46)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = l
	return l, sg
end

---------------------------------------------------------------------------
-- Zone skins
---------------------------------------------------------------------------
local ZONE_LEN = 200
local HALF_W = 100
local function zoneZ(z)
	return (z - 1) * ZONE_LEN
end
local function zoneOf(pos)
	if pos.Z < 0 then
		return 0
	end
	return math.clamp(math.floor(pos.Z / ZONE_LEN) + 1, 1, #Config.Zones)
end

local SKINS = {
	{ -- Sunny Meadow
		Ground = Color3.fromRGB(118, 214, 96), Ground2 = Color3.fromRGB(98, 196, 84), Ground3 = Color3.fromRGB(140, 226, 110),
		Cliff = Color3.fromRGB(96, 178, 84), Cliff2 = Color3.fromRGB(132, 204, 104),
		Tree = "round", Trunk = Color3.fromRGB(118, 74, 44), Leaves = { Color3.fromRGB(98, 196, 84), Color3.fromRGB(80, 170, 70), Color3.fromRGB(130, 210, 90) },
		Rock = Color3.fromRGB(150, 156, 176), Rock2 = Color3.fromRGB(196, 200, 216),
		Bush = Color3.fromRGB(88, 186, 76), Dots = true,
		Wall = Color3.fromRGB(255, 244, 220), Roof = Color3.fromRGB(230, 80, 70), Hut = "house",
		Water = Color3.fromRGB(90, 180, 255), Pad = Color3.fromRGB(70, 170, 70), Liquid = "water",
		Crate = Color3.fromRGB(240, 200, 100), CrateTrim = Color3.fromRGB(196, 150, 70),
		Tower = Color3.fromRGB(196, 200, 216), Step = Color3.fromRGB(176, 116, 66),
	},
	{ -- Palm Beach
		Ground = Color3.fromRGB(246, 226, 172), Ground2 = Color3.fromRGB(238, 214, 156), Ground3 = Color3.fromRGB(252, 236, 190),
		Cliff = Color3.fromRGB(214, 180, 130), Cliff2 = Color3.fromRGB(232, 200, 150),
		Tree = "palm", Trunk = Color3.fromRGB(186, 140, 90), Leaves = { Color3.fromRGB(60, 190, 90), Color3.fromRGB(40, 160, 80) },
		Rock = Color3.fromRGB(170, 160, 150), Rock2 = Color3.fromRGB(200, 190, 175),
		Bush = Color3.fromRGB(50, 180, 110), Dots = true,
		Wall = Color3.fromRGB(110, 200, 230), Roof = Color3.fromRGB(240, 200, 100), Hut = "house",
		Water = Color3.fromRGB(60, 220, 230), Pad = Color3.fromRGB(255, 120, 140), Liquid = "water",
		Crate = Color3.fromRGB(196, 140, 80), CrateTrim = Color3.fromRGB(130, 86, 50),
		Tower = Color3.fromRGB(255, 255, 255), Step = Color3.fromRGB(255, 110, 100),
	},
	{ -- Frosty Peaks
		Ground = Color3.fromRGB(240, 248, 255), Ground2 = Color3.fromRGB(222, 236, 252), Ground3 = Color3.fromRGB(250, 252, 255),
		Cliff = Color3.fromRGB(200, 222, 245), Cliff2 = Color3.fromRGB(236, 244, 255),
		Tree = "pine", Trunk = Color3.fromRGB(110, 76, 56), Leaves = { Color3.fromRGB(40, 120, 90), Color3.fromRGB(30, 100, 80) },
		Rock = Color3.fromRGB(150, 200, 240), Rock2 = Color3.fromRGB(190, 225, 255),
		Bush = Color3.fromRGB(255, 255, 255), Dots = false,
		Wall = Color3.fromRGB(245, 250, 255), Roof = Color3.fromRGB(120, 180, 240), Hut = "igloo",
		Water = Color3.fromRGB(170, 220, 255), Pad = Color3.fromRGB(230, 245, 255), Liquid = "ice",
		Crate = Color3.fromRGB(176, 116, 66), CrateTrim = Color3.fromRGB(118, 74, 44),
		Tower = Color3.fromRGB(190, 225, 255), Step = Color3.fromRGB(120, 180, 240),
	},
	{ -- Lava Volcano
		Ground = Color3.fromRGB(78, 64, 70), Ground2 = Color3.fromRGB(66, 54, 60), Ground3 = Color3.fromRGB(96, 76, 80),
		Cliff = Color3.fromRGB(56, 44, 50), Cliff2 = Color3.fromRGB(90, 70, 74),
		Tree = "dead", Trunk = Color3.fromRGB(46, 36, 40), Leaves = { Color3.fromRGB(255, 120, 40) },
		Rock = Color3.fromRGB(44, 36, 42), Rock2 = Color3.fromRGB(70, 58, 64),
		Bush = Color3.fromRGB(110, 60, 50), Dots = false,
		Wall = Color3.fromRGB(110, 96, 100), Roof = Color3.fromRGB(70, 58, 64), Hut = "ruin",
		Water = Color3.fromRGB(255, 110, 30), Pad = Color3.fromRGB(60, 50, 56), Liquid = "lava",
		Crate = Color3.fromRGB(96, 84, 90), CrateTrim = Color3.fromRGB(255, 120, 40),
		Tower = Color3.fromRGB(56, 44, 50), Step = Color3.fromRGB(255, 120, 40),
	},
	{ -- Crystal Sky
		Ground = Color3.fromRGB(250, 248, 255), Ground2 = Color3.fromRGB(236, 230, 255), Ground3 = Color3.fromRGB(255, 240, 252),
		Cliff = Color3.fromRGB(226, 214, 255), Cliff2 = Color3.fromRGB(250, 240, 255),
		Tree = "crystal", Trunk = Color3.fromRGB(240, 230, 255), Leaves = { Color3.fromRGB(190, 120, 255), Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 130, 220) },
		Rock = Color3.fromRGB(170, 130, 255), Rock2 = Color3.fromRGB(220, 190, 255),
		Bush = Color3.fromRGB(255, 255, 255), Dots = false,
		Wall = Color3.fromRGB(255, 255, 255), Roof = Color3.fromRGB(255, 205, 80), Hut = "temple",
		Water = Color3.fromRGB(255, 170, 230), Pad = Color3.fromRGB(255, 255, 255), Liquid = "water",
		Crate = Color3.fromRGB(255, 120, 200), CrateTrim = Color3.fromRGB(255, 220, 90),
		Tower = Color3.fromRGB(255, 255, 255), Step = Color3.fromRGB(190, 120, 255),
	},
}

---------------------------------------------------------------------------
-- Props. Each one registers candidate hiding spots: { Pos (egg bottom), Diff 1-3, Clue }
---------------------------------------------------------------------------
local rng = Random.new(2026)
local spots = {} -- zone -> list
local lavaParts = {}
local zoneSpawns = {}

local function addSpot(z, pos, diff, clue)
	spots[z] = spots[z] or {}
	table.insert(spots[z], { Pos = pos, Diff = diff, Clue = clue })
end

local function randDir()
	local a = rng:NextNumber(0, math.pi * 2)
	return Vector3.new(math.cos(a), 0, math.sin(a))
end

local function tree(z, K, pos, s, folder)
	if K.Tree == "round" then
		cyl(pos, 8 * s, 1.6 * s, K.Trunk, folder)
		local blobs = {
			{ Vector3.new(0, 9 * s, 0), Vector3.new(10, 7, 10) },
			{ Vector3.new(2 * s, 12 * s, 0.5 * s), Vector3.new(6.5, 5, 6.5) },
			{ Vector3.new(-2 * s, 11 * s, -1 * s), Vector3.new(5.5, 4.5, 5.5) },
		}
		for _, b in ipairs(blobs) do
			ellipsoid(b[2] * s, CFrame.new(pos + b[1]), K.Leaves[rng:NextInteger(1, #K.Leaves)], folder, { CanCollide = false })
		end
		-- a few fruits
		for _ = 1, 3 do
			local d = randDir()
			ball(pos + Vector3.new(0, 8.5 * s, 0) + d * 4.6 * s, 0.9 * s, Color3.fromRGB(255, 80, 80), folder, { CanCollide = false })
		end
		local d = randDir()
		addSpot(z, pos + Vector3.new(0, 8.2 * s, 0) + d * 5 * s, 2, "Tree")
	elseif K.Tree == "pine" then
		cyl(pos, 4 * s, 1.4 * s, K.Trunk, folder)
		for k = 0, 3 do
			local d = (8 - k * 1.8) * s
			cyl(pos + Vector3.new(0, (3 + k * 2.6) * s, 0), 2.2 * s, d, K.Leaves[(k % #K.Leaves) + 1], folder, { CanCollide = k == 0 })
			cyl(pos + Vector3.new(0, (5.2 + k * 2.6) * s, 0), 0.5 * s, d * 0.8, Color3.fromRGB(250, 252, 255), folder, { CanCollide = false })
		end
		local d = randDir()
		addSpot(z, pos + Vector3.new(0, 5.2 * s, 0) + d * 3.6 * s, 2, "Tree")
	elseif K.Tree == "palm" then
		local top = pos
		local lean = randDir() * 0.9
		for k = 0, 6 do
			local p = pos + Vector3.new(0, k * 1.6 * s, 0) + lean * (k * k * 0.12 * s)
			cyl(p, 1.8 * s, (1.5 - k * 0.07) * s, k % 2 == 0 and K.Trunk or Color3.new(K.Trunk.R * 0.85, K.Trunk.G * 0.85, K.Trunk.B * 0.85), folder)
			top = p + Vector3.new(0, 1.8 * s, 0)
		end
		for k = 0, 6 do
			local a = k / 7 * math.pi * 2
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local leaf = part({ Size = Vector3.new(1.6 * s, 0.3 * s, 7 * s), Color = K.Leaves[(k % #K.Leaves) + 1], CanCollide = false, Parent = folder })
			leaf.CFrame = CFrame.lookAt(top + dir * 3 * s, top + dir * 7 * s + Vector3.new(0, -2.2 * s, 0))
		end
		for k = 0, 2 do
			local a = k / 3 * math.pi * 2
			ball(top + Vector3.new(math.cos(a) * 0.9 * s, -0.6 * s, math.sin(a) * 0.9 * s), 1.1 * s, Color3.fromRGB(120, 80, 40), folder, { CanCollide = false })
		end
		addSpot(z, top + Vector3.new(0, 0.2 * s, 0), 3, "Tree")
	elseif K.Tree == "dead" then
		cyl(pos, 9 * s, 1.4 * s, K.Trunk, folder)
		for k = 0, 2 do
			local a = k / 3 * math.pi * 2 + rng:NextNumber(0, 1)
			local dir = Vector3.new(math.cos(a), 0.9, math.sin(a)).Unit
			local start = pos + Vector3.new(0, (5 + k * 1.4) * s, 0)
			local b = part({ Size = Vector3.new(0.7 * s, 0.7 * s, 4.5 * s), Color = K.Trunk, Parent = folder })
			b.CFrame = CFrame.lookAt(start + dir * 2.2 * s, start + dir * 5 * s)
			-- glowing embers on the tips
			ball(start + dir * 4.5 * s, 0.6 * s, K.Leaves[1], folder, { Material = Enum.Material.Neon, CanCollide = false })
		end
		addSpot(z, pos + Vector3.new(0, 9 * s, 0), 3, "Tree")
	else -- crystal
		local cols = K.Leaves
		for k = 0, 4 do
			local h = (k == 0 and 12 or rng:NextNumber(4, 8)) * s
			local w = (k == 0 and 2.6 or 1.6) * s
			local off = k == 0 and Vector3.zero or randDir() * 2 * s
			local c = part({ Size = Vector3.new(w, h, w), Color = cols[(k % #cols) + 1], Parent = folder,
				Material = k == 0 and Enum.Material.Neon or Enum.Material.SmoothPlastic, Transparency = k == 0 and 0.15 or 0 })
			c.CFrame = CFrame.new(pos + off + Vector3.new(0, h / 2 - 0.5, 0)) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 6), rng:NextNumber(-0.25, 0.25))
		end
		addSpot(z, pos + randDir() * 3.2 * s, 2, "Tree")
	end
	addSpot(z, pos + randDir() * 1.6 * s, 1, "TreeBase")
end

local function rock(z, K, pos, s, folder)
	local d = rng:NextNumber(5, 8) * s
	ball(pos + Vector3.new(0, d * 0.25, 0), d, K.Rock, folder)
	local side = randDir()
	ball(pos + side * d * 0.45 + Vector3.new(0, d * 0.1, 0), d * 0.6, K.Rock2, folder)
	addSpot(z, pos - side * d * 0.62, 1, "Rock")
	if d > 6 then
		addSpot(z, pos + Vector3.new(0, d * 0.75, 0), 1, "RockTop")
	end
end

local function bush(z, K, pos, s, folder)
	local h = 3.4 * s
	ellipsoid(Vector3.new(5.5, h, 5) * s, CFrame.new(pos + Vector3.new(0, h / 2 - 0.3, 0)), K.Bush, folder, { CanCollide = false })
	ellipsoid(Vector3.new(3.4, h * 0.8, 3.2) * s, CFrame.new(pos + Vector3.new(2 * s, h * 0.4, 1 * s)), K.Bush, folder, { CanCollide = false })
	if K.Dots then
		for _ = 1, 4 do
			ball(pos + Vector3.new(rng:NextNumber(-2, 2) * s, h * 0.8, rng:NextNumber(-1.8, 1.8) * s), 0.7 * s,
				Color3.fromHSV(rng:NextNumber(), 0.55, 1), folder, { CanCollide = false })
		end
	end
	addSpot(z, pos + Vector3.new(0, h - 1.7, 0), 2, "Bush")
end

local function hollowLog(z, K, pos, folder)
	local cf = CFrame.new(pos + Vector3.new(0, 1.9, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local slat = part({ Size = Vector3.new(2.1, 0.5, 9), Color = k % 2 == 0 and K.Trunk or Color3.new(K.Trunk.R * 0.85, K.Trunk.G * 0.85, K.Trunk.B * 0.85), Parent = folder })
		slat.CFrame = cf * CFrame.Angles(0, 0, a) * CFrame.new(0, 1.8, 0)
	end
	addSpot(z, (cf * CFrame.new(0, -1.55, 1)).Position, 2, "Log")
end

local function crates(z, K, pos, folder)
	local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	local function crate(offset, sz)
		local c = part({ Size = Vector3.new(sz, sz, sz), CFrame = cf * CFrame.new(offset + Vector3.new(0, sz / 2, 0)), Color = K.Crate, Parent = folder })
		for _, e in ipairs({ -1, 1 }) do
			part({ Size = Vector3.new(sz + 0.1, 0.5, 0.5), CFrame = c.CFrame * CFrame.new(0, e * (sz / 2 - 0.25), -sz / 2), Color = K.CrateTrim, Parent = folder })
			part({ Size = Vector3.new(0.5, sz + 0.1, 0.5), CFrame = c.CFrame * CFrame.new(e * (sz / 2 - 0.25), 0, -sz / 2), Color = K.CrateTrim, Parent = folder })
		end
		return c
	end
	crate(Vector3.new(-3.2, 0, 0), 4)
	crate(Vector3.new(3.2, 0, 0), 4)
	crate(Vector3.new(0, 4, 0), 4)
	crate(Vector3.new(0, 0, 4.2), 3.4)
	addSpot(z, (cf * CFrame.new(0, 0, 0.6)).Position, 2, "Crate")
end

local function hut(z, K, pos, folder)
	local face = rng:NextNumber(0, math.pi * 2)
	local cf = CFrame.new(pos) * CFrame.Angles(0, face, 0)
	if K.Hut == "igloo" then
		ellipsoid(Vector3.new(14, 12, 14), cf * CFrame.new(0, 0, 0), K.Wall, folder, { CanCollide = false })
		block(cf, -2.5, 2.5, 0, 4, -9, -5, K.Wall, folder, { CanCollide = false, Transparency = 0.0 })
		block(cf, -1.8, 1.8, 0, 3.4, -9.2, -5, Color3.fromRGB(60, 80, 110), folder, { CanCollide = false })
		addSpot(z, (cf * CFrame.new(0, 0, 1)).Position, 2, "House")
		addSpot(z, (cf * CFrame.new(0, 6, 0)).Position, 3, "Roof")
		return
	end
	local W, H = 12, 8
	local wallColor, roofColor = K.Wall, K.Roof
	-- floor + walls with a door gap in the front (-Z)
	block(cf, -W / 2, W / 2, 0, 0.4, -W / 2, W / 2, Color3.new(wallColor.R * 0.8, wallColor.G * 0.8, wallColor.B * 0.8), folder)
	block(cf, -W / 2, W / 2, 0, H, W / 2 - 1, W / 2, wallColor, folder)
	block(cf, -W / 2, -W / 2 + 1, 0, H, -W / 2, W / 2, wallColor, folder)
	block(cf, W / 2 - 1, W / 2, 0, H, -W / 2, W / 2, wallColor, folder)
	block(cf, -W / 2, -2, 0, H, -W / 2, -W / 2 + 1, wallColor, folder)
	block(cf, 2, W / 2, 0, H, -W / 2, -W / 2 + 1, wallColor, folder)
	block(cf, -2, 2, 5.5, H, -W / 2, -W / 2 + 1, wallColor, folder)
	if K.Hut == "ruin" then
		-- broken walls, no roof, glowing cracks
		block(cf, -W / 2, W / 2, H, H + 1, -W / 2, -W / 2 + 1, roofColor, folder)
		block(cf, -0.3, 0.3, 1, H - 1, W / 2 - 1.05, W / 2 - 0.95, K.CrateTrim, folder, { Material = Enum.Material.Neon })
		addSpot(z, (cf * CFrame.new(-W / 2 + 0.5, H, 2)).Position, 3, "Roof")
	else
		-- stepped roof (stylized)
		for k = 0, 3 do
			local inset = k * 1.6
			block(cf, -W / 2 - 1 + inset, W / 2 + 1 - inset, H + k * 1.4, H + (k + 1) * 1.4, -W / 2 - 1 + inset, W / 2 + 1 - inset,
				k % 2 == 0 and roofColor or Color3.new(roofColor.R * 0.85, roofColor.G * 0.85, roofColor.B * 0.85), folder)
		end
		if K.Hut == "temple" then
			for _, x in ipairs({ -W / 2 - 1.5, W / 2 + 1.5 }) do
				for _, zz in ipairs({ -W / 2 - 1.5, W / 2 + 1.5 }) do
					cyl((cf * CFrame.new(x, 0, zz)).Position, H, 1.6, Color3.fromRGB(255, 255, 255), folder)
				end
			end
		else
			-- window + chimney
			block(cf, -W / 2 - 0.1, -W / 2 + 1.1, 3.5, 6, -1.5, 1.5, Color3.fromRGB(255, 230, 120), folder, { Material = Enum.Material.Neon })
			block(cf, 2.5, 4.5, H + 2, H + 7, 1, 3, Color3.fromRGB(150, 140, 150), folder)
		end
		addSpot(z, (cf * CFrame.new(0, H + 5.6, 0)).Position, 3, "Roof")
	end
	addSpot(z, (cf * CFrame.new(-W / 2 + 2.5, 0.4, W / 2 - 2.5)).Position, 2, "House")
end

local function cave(z, K, pos, folder)
	local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local c1, c2 = K.Cliff, K.Cliff2
	block(cf, -12, -4, 0, 10, 0, 24, c1, folder)
	block(cf, 4, 20, 0, 10, 0, 12, c2, folder)
	block(cf, -4, 20, 0, 10, 20, 28, c1, folder)
	block(cf, 16, 24, 0, 10, 12, 20, c2, folder)
	block(cf, -12, 24, 10, 13, 0, 28, c1, folder)
	-- dark floor inside
	block(cf, -4, 16, 0, 0.2, 0, 20, Color3.fromRGB(40, 36, 50), folder, { CanCollide = false })
	-- lumpy top
	for _ = 1, 5 do
		ellipsoid(Vector3.new(rng:NextNumber(10, 16), rng:NextNumber(5, 8), rng:NextNumber(10, 16)),
			cf * CFrame.new(rng:NextNumber(-8, 20), 13, rng:NextNumber(4, 24)), rng:NextNumber() < 0.5 and c1 or c2, folder, { CanCollide = false })
	end
	-- glowing mushrooms / crystals in the dark
	for _, p in ipairs({ Vector3.new(-3.2, 0, 8), Vector3.new(3.2, 0, 4), Vector3.new(14, 0, 19) }) do
		ball((cf * CFrame.new(p + Vector3.new(0, 0.6, 0))).Position, 1, Color3.fromRGB(120, 255, 220), folder, { Material = Enum.Material.Neon, CanCollide = false })
	end
	addSpot(z, (cf * CFrame.new(13, 0.2, 16)).Position, 3, "Cave")
	addSpot(z, (cf * CFrame.new(8, 0, -1.4)).Position, 2, "CaveMouth")
end

local function tower(z, K, pos, folder)
	local h = 34
	cyl(pos, h, 8, K.Tower, folder)
	for k = 0, 3 do
		cyl(pos + Vector3.new(0, k * 9, 0), 0.6, 8.4, K.Step, folder)
	end
	local start = rng:NextNumber(0, math.pi * 2)
	local n = 10
	for k = 1, n do
		local a = start + k * math.rad(52)
		local p = pos + Vector3.new(math.cos(a) * 8, k * 3.2 - 1, math.sin(a) * 8)
		part({ Size = Vector3.new(5, 1, 5), CFrame = CFrame.new(p) * CFrame.Angles(0, -a, 0), Color = K.Step, Parent = folder })
		if k == 5 then
			addSpot(z, p + Vector3.new(0, 0.5, 0), 2, "Ledge")
		end
	end
	local topY = h
	cyl(pos + Vector3.new(0, topY, 0), 1, 12, K.Step, folder)
	-- flag on top
	part({ Size = Vector3.new(0.4, 7, 0.4), Position = pos + Vector3.new(4, topY + 4.5, 0), Color = Color3.fromRGB(80, 60, 50), Parent = folder })
	part({ Size = Vector3.new(0.3, 2.6, 4), Position = pos + Vector3.new(4, topY + 6.6, 2), Color = Config.Zones[z].Color, Parent = folder })
	addSpot(z, pos + Vector3.new(-2, topY + 1, 0), 3, "Tower")
end

local function pool(z, K, pos, folder)
	local D = 34
	local liquid = cyl(pos + Vector3.new(0, -0.5, 0), 0.9, D, K.Water, folder, { CanCollide = K.Liquid == "ice",
		Transparency = K.Liquid == "water" and 0.15 or 0, Material = K.Liquid == "lava" and Enum.Material.Neon or Enum.Material.SmoothPlastic })
	cyl(pos + Vector3.new(0, -0.6, 0), 0.9, D + 3, K.Ground2, folder, { CanCollide = false })
	if K.Liquid == "lava" then
		table.insert(lavaParts, { Part = liquid, Zone = z })
		liquid.Size += Vector3.new(0.6, 0, 0)
		local glow = Instance.new("PointLight")
		glow.Color = K.Water
		glow.Range = 30
		glow.Brightness = 1.5
		glow.Parent = liquid
	end
	-- stepping stones / pads to an island
	local dir = randDir()
	for k = -3, 3 do
		if k ~= 0 then
			local p = pos + dir * k * 4.2
			local isPad = K.Liquid ~= "lava"
			if isPad then
				cyl(p + Vector3.new(0, -0.2, 0), 0.6, 3.6, K.Pad, folder)
			else
				cyl(p + Vector3.new(0, -0.5, 0), 2, 3.6, K.Rock2, folder)
			end
		end
	end
	cyl(pos + Vector3.new(0, -0.5, 0), 2, 7, K.Rock2, folder)
	addSpot(z, pos + Vector3.new(0, 1.5, 0), 2, "Water")
	-- a far lily pad / stone off the path
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local far = pos + side * 11
	cyl(far + Vector3.new(0, K.Liquid == "lava" and -0.5 or -0.2, 0), K.Liquid == "lava" and 2 or 0.6, 4, K.Liquid == "lava" and K.Rock2 or K.Pad, folder)
	addSpot(z, far + Vector3.new(0, K.Liquid == "lava" and 1.5 or 0.4, 0), 1, "Water")
	-- bridge across
	local bcf = CFrame.lookAt(pos + side * -6 + Vector3.new(0, 3.2, 0), pos + side * -6 + dir + Vector3.new(0, 3.2, 0))
	block(bcf, -2.5, 2.5, 0, 0.6, -14, 14, K.Crate, folder)
	for _, zz in ipairs({ -14, -5, 5, 14 }) do
		for _, xx in ipairs({ -2.5, 2.5 }) do
			block(bcf, xx - 0.3, xx + 0.3, -3.6, 2.4, zz - 0.3, zz + 0.3, K.CrateTrim, folder)
		end
	end
	block(bcf, -2.8, -2.2, 1.8, 2.3, -14, 14, K.CrateTrim, folder)
	block(bcf, 2.2, 2.8, 1.8, 2.3, -14, 14, K.CrateTrim, folder)
	-- ramps up to the bridge
	for _, e in ipairs({ -1, 1 }) do
		local r = part({ Size = Vector3.new(5, 0.6, 8), Color = K.Crate, Parent = folder })
		r.CFrame = bcf * CFrame.new(0, -1.5, e * 17.5) * CFrame.Angles(math.rad(e * 22), 0, 0)
	end
	addSpot(z, (bcf * CFrame.new(0, -3.2 + (K.Liquid == "water" and 0.1 or 0.4), 9)).Position, 2, "Bridge")
end

---------------------------------------------------------------------------
-- World
---------------------------------------------------------------------------
local function buildZone(z)
	local K = SKINS[z]
	local zone = Config.Zones[z]
	local folder = Instance.new("Folder")
	folder.Name = "Zone" .. z
	folder.Parent = world
	local oz = zoneZ(z)
	local center = Vector3.new(0, 0, oz + ZONE_LEN / 2)
	part({ Name = "Ground", Size = Vector3.new(HALF_W * 2 + 40, 2, ZONE_LEN), Position = center + Vector3.new(0, -1, 0), Color = K.Ground, Parent = folder })
	for _ = 1, 22 do
		cyl(Vector3.new(rng:NextNumber(-90, 90), 0, oz + rng:NextNumber(10, 190)), 0.05, rng:NextNumber(14, 36),
			rng:NextNumber() < 0.5 and K.Ground2 or K.Ground3, folder, { CanCollide = false })
	end
	-- cliffs along both sides
	for _, sx in ipairs({ -1, 1 }) do
		for k = 0, 13 do
			local d = rng:NextNumber(26, 40)
			ball(Vector3.new(sx * (HALF_W + d * 0.25), rng:NextNumber(-4, 4), oz + k * 15 + rng:NextNumber(0, 6)), d,
				k % 2 == 0 and K.Cliff or K.Cliff2, folder)
		end
		for k = 1, 3 do
			addSpot(z, Vector3.new(sx * (HALF_W - 14), 0, oz + k * 50 + rng:NextNumber(-8, 8)), 1, "Edge")
		end
	end
	-- sky zone: puffy clouds below the edges
	if z == 5 then
		for _ = 1, 16 do
			ellipsoid(Vector3.new(rng:NextNumber(20, 40), rng:NextNumber(8, 14), rng:NextNumber(20, 40)),
				CFrame.new(rng:NextNumber(-150, 150), rng:NextNumber(-30, -14), oz + rng:NextNumber(0, 200)), Color3.fromRGB(255, 255, 255), folder, { CanCollide = false })
		end
	end

	-- big set pieces in fixed lanes so they never overlap
	local used = {}
	local function free(pos, r)
		for _, u in ipairs(used) do
			if (u.P - pos).Magnitude < u.R + r then
				return false
			end
		end
		return true
	end
	local function reserve(pos, r)
		table.insert(used, { P = pos, R = r })
	end
	reserve(Vector3.new(0, 0, oz + 6), 14) -- entrance path
	reserve(Vector3.new(0, 0, oz + 194), 14)
	local pondPos = Vector3.new(rng:NextNumber(-45, -25), 0, oz + rng:NextNumber(55, 80))
	pool(z, K, pondPos, folder)
	reserve(pondPos, 24)
	local towerPos = Vector3.new(rng:NextNumber(30, 60), 0, oz + rng:NextNumber(120, 150))
	tower(z, K, towerPos, folder)
	reserve(towerPos, 16)
	local cavePos = Vector3.new(rng:NextNumber(-56, -50), 0, oz + rng:NextNumber(130, 150))
	cave(z, K, cavePos, folder)
	reserve(cavePos + Vector3.new(4, 0, 12), 24)
	for _ = 1, 2 do
		for _ = 1, 40 do
			local p = Vector3.new(rng:NextNumber(-70, 70), 0, oz + rng:NextNumber(30, 175))
			if free(p, 12) then
				hut(z, K, p, folder)
				reserve(p, 12)
				break
			end
		end
	end
	local function scatter(n, r, fn)
		for _ = 1, n do
			for _ = 1, 30 do
				local p = Vector3.new(rng:NextNumber(-84, 84), 0, oz + rng:NextNumber(18, 186))
				if free(p, r) then
					fn(p)
					reserve(p, r)
					break
				end
			end
		end
	end
	scatter(11, 7, function(p)
		tree(z, K, p, rng:NextNumber(0.9, 1.4), folder)
	end)
	scatter(7, 5, function(p)
		rock(z, K, p, rng:NextNumber(0.8, 1.3), folder)
	end)
	scatter(6, 5, function(p)
		bush(z, K, p, rng:NextNumber(0.9, 1.3), folder)
	end)
	scatter(3, 6, function(p)
		hollowLog(z, K, p, folder)
	end)
	scatter(2, 7, function(p)
		crates(z, K, p, folder)
	end)

	-- gate into this zone (zone 1 is always open)
	local gz = oz
	local wallColor = K.Cliff
	block(CFrame.new(0, 0, gz), -HALF_W - 20, -15, 0, 30, -3, 3, wallColor, folder)
	block(CFrame.new(0, 0, gz), 15, HALF_W + 20, 0, 30, -3, 3, wallColor, folder)
	block(CFrame.new(0, 0, gz), -15, 15, 18, 30, -3, 3, wallColor, folder)
	for _, x in ipairs({ -15, 15 }) do
		cyl(Vector3.new(x, 0, gz), 20, 5, zone.Color, folder)
		ball(Vector3.new(x, 21, gz), 6, zone.Color, folder, { Material = Enum.Material.Neon })
	end
	local sign = part({ Size = Vector3.new(28, 9, 1), Position = Vector3.new(0, 24, gz - 3.6), Color = zone.Color, Parent = folder })
	local signText = surfaceText(sign, Enum.NormalId.Front, zone.Emoji .. " " .. string.upper(zone.Name), zone.Color, Vector2.new(700, 220))
	if z > 1 then
		local gate = part({ Name = "Gate", Size = Vector3.new(30, 18, 1), Position = Vector3.new(0, 9, gz), Color = zone.Color,
			Material = Enum.Material.Neon, Transparency = 0.55, Parent = folder })
		gate:SetAttribute("Zone", z)
		gate:SetAttribute("Need", zone.Need)
		local labels, bb = billboard(gate, { { Text = "🔒 FIND " .. zone.Need .. " EGGS" }, { Text = "or SKIP ZONE ⏩", Color = Color3.fromRGB(255, 230, 80) } }, 0, 260, 90, 120)
		bb:SetAttribute("GateZone", z)
		local _ = labels
		CollectionService:AddTag(gate, "Gate")
	end
	local _ = signText
	zoneSpawns[z] = CFrame.lookAt(Vector3.new(0, 4, oz + 12), Vector3.new(0, 4, oz + 40))
end

for z = 1, #Config.Zones do
	buildZone(z)
end

-- invisible boundary walls
local endZ = zoneZ(#Config.Zones + 1)
for _, sx in ipairs({ -1, 1 }) do
	part({ Size = Vector3.new(2, 200, endZ + 140), Position = Vector3.new(sx * (HALF_W + 1), 100, (endZ - 120) / 2), Transparency = 1, Parent = world })
end
part({ Size = Vector3.new(HALF_W * 2 + 40, 200, 2), Position = Vector3.new(0, 100, endZ + 1), Transparency = 1, Parent = world })
part({ Size = Vector3.new(HALF_W * 2 + 40, 200, 2), Position = Vector3.new(0, 100, -121), Transparency = 1, Parent = world })
part({ Size = Vector3.new(HALF_W * 2 + 40, 2, endZ + 140), Position = Vector3.new(0, 170, (endZ - 120) / 2), Transparency = 1, Parent = world })

---------------------------------------------------------------------------
-- Hub: spawn plaza, title, leaderboard, ad boards
---------------------------------------------------------------------------
local hub = Instance.new("Folder")
hub.Name = "Hub"
hub.Parent = world
part({ Size = Vector3.new(HALF_W * 2 + 40, 2, 120), Position = Vector3.new(0, -1, -60), Color = Color3.fromRGB(118, 214, 96), Parent = hub })
cyl(Vector3.new(0, 0, -55), 0.3, 70, Color3.fromRGB(246, 226, 172), hub)
cyl(Vector3.new(0, 0.3, -55), 0.2, 54, Color3.fromRGB(255, 236, 190), hub)
for k = 0, 11 do
	local a = k / 12 * math.pi * 2
	ball(Vector3.new(math.cos(a) * 33, 0.6, -55 + math.sin(a) * 33), 2.4, Config.Zones[(k % 5) + 1].Color, hub, { CanCollide = false })
end
part({ Size = Vector3.new(10, 0.3, 50), Position = Vector3.new(0, 0.15, -12), Color = Color3.fromRGB(246, 226, 172), Parent = hub })
for _, sx in ipairs({ -1, 1 }) do
	for k = 0, 7 do
		local d = rng:NextNumber(26, 40)
		ball(Vector3.new(sx * (HALF_W + d * 0.25), rng:NextNumber(-4, 4), -118 + k * 15), d, k % 2 == 0 and SKINS[1].Cliff or SKINS[1].Cliff2, hub)
	end
end
for k = 0, 7 do
	ball(Vector3.new(-105 + k * 30, rng:NextNumber(-4, 4), -126), rng:NextNumber(30, 44), k % 2 == 0 and SKINS[1].Cliff or SKINS[1].Cliff2, hub)
end
-- giant egg statue in the middle
cyl(Vector3.new(0, 0, -55), 3, 14, Color3.fromRGB(196, 200, 216), hub)
cyl(Vector3.new(0, 3, -55), 1, 11, Color3.fromRGB(255, 205, 60), hub)
local statue = ellipsoid(Vector3.new(9, 12, 9), CFrame.new(0, 10, -55), Color3.fromRGB(230, 50, 60), hub)
for k = 0, 9 do
	local a = k / 10 * math.pi * 2
	local y = 7 + (k % 3) * 2.5
	local p = Vector3.new(math.cos(a) * 4.2, y, -55 + math.sin(a) * 4.2)
	local sc = part({ Size = Vector3.new(1.6, 1.6, 0.6), CFrame = CFrame.lookAt(p, Vector3.new(0, y, -55)), Color = Color3.fromRGB(255, 170, 60), Parent = hub })
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = sc
end
local sparkle = Instance.new("ParticleEmitter")
sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120))
sparkle.LightEmission = 1
sparkle.Size = NumberSequence.new(1.2, 0)
sparkle.Rate = 8
sparkle.Speed = NumberRange.new(2, 5)
sparkle.SpreadAngle = Vector2.new(180, 180)
sparkle.Parent = statue

-- title board behind spawn
local title = part({ Size = Vector3.new(60, 16, 1.5), Position = Vector3.new(0, 20, -96), Color = Color3.fromRGB(255, 205, 60), Parent = hub })
title.CFrame = CFrame.lookAt(title.Position, Vector3.new(0, 20, 0))
surfaceText(title, Enum.NormalId.Front, "🐉 FIND THE DRAGON EGGS 🥚", Color3.fromRGB(230, 60, 80), Vector2.new(1000, 260))
for _, x in ipairs({ -28, 28 }) do
	cyl(Vector3.new(x, 0, -96), 28, 2.4, Color3.fromRGB(118, 74, 44), hub)
end

-- leaderboard
local lbBoard = part({ Size = Vector3.new(22, 26, 1.2), Position = Vector3.new(-48, 15, -60), Color = Color3.fromRGB(70, 80, 120), Parent = hub })
lbBoard.CFrame = CFrame.lookAt(lbBoard.Position, Vector3.new(0, 15, -60))
for _, dz in ipairs({ -10, 10 }) do
	part({ Size = Vector3.new(1.4, 15, 1.4), CFrame = lbBoard.CFrame * CFrame.new(dz, -20, 0.8), Color = Color3.fromRGB(118, 74, 44), Parent = hub })
end
local lbGui = Instance.new("SurfaceGui")
lbGui.Face = Enum.NormalId.Front
lbGui.CanvasSize = Vector2.new(440, 520)
lbGui.LightInfluence = 0.2
lbGui.Parent = lbBoard
local lbBg = Instance.new("Frame")
lbBg.Size = UDim2.fromScale(1, 1)
lbBg.BackgroundColor3 = Color3.fromRGB(45, 50, 85)
lbBg.Parent = lbGui
local lbList = Instance.new("UIListLayout")
lbList.SortOrder = Enum.SortOrder.LayoutOrder
lbList.Parent = lbBg
local lbRows = {}
for i = 0, 10 do
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, i == 0 and 0.12 or 0.08, 0)
	t.BackgroundTransparency = i == 0 and 0 or 1
	t.BackgroundColor3 = Color3.fromRGB(255, 190, 40)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = i == 1 and Color3.fromRGB(255, 215, 60) or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0
	t.Text = i == 0 and "🏆 TOP EGG HUNTERS" or ""
	t.LayoutOrder = i
	t.Parent = lbBg
	lbRows[i] = t
end

-- in-world ad boards (hold E to buy)
local promptBuy -- forward declared
local function adBoard(pos, kind, key, headline)
	local item = kind == "Pass" and Config.Find(Config.GamePasses, key) or Config.Find(Config.Products, key)
	if not item then
		return
	end
	local b = part({ Size = Vector3.new(14, 10, 1), Position = pos, Color = Color3.fromRGB(255, 120, 60), Parent = hub })
	b.CFrame = CFrame.lookAt(pos, Vector3.new(0, pos.Y, -55))
	for _, dx in ipairs({ -6, 6 }) do
		part({ Size = Vector3.new(1, pos.Y - 5, 1), CFrame = b.CFrame * CFrame.new(dx, -(pos.Y) / 2 - 2.5 + 2.5, 0.6), Color = Color3.fromRGB(118, 74, 44), Parent = hub })
	end
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(560, 400)
	sg.LightInfluence = 0.1
	sg.Parent = b
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.new(1, 1, 1)
	bg.Parent = sg
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.fromRGB(255, 90, 140), Color3.fromRGB(150, 60, 220))
	g.Rotation = 90
	g.Parent = bg
	if Assets[item.Img] then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = Assets[item.Img]
		img.Position = UDim2.fromScale(0.02, 0.18)
		img.Size = UDim2.fromScale(0.42, 0.6)
		img.ScaleType = Enum.ScaleType.Fit
		img.Parent = bg
	end
	local function t(str, y, h, color)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0.44, y)
		l.Size = UDim2.fromScale(0.54, h)
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextColor3 = color or Color3.new(1, 1, 1)
		l.TextStrokeTransparency = 0
		l.Text = str
		l.Parent = bg
	end
	t(headline, 0.08, 0.22, Color3.fromRGB(255, 230, 80))
	t(item.Desc, 0.32, 0.34)
	t("R$ " .. item.Price, 0.7, 0.2, Color3.fromRGB(140, 255, 140))
	local p = Instance.new("ProximityPrompt")
	p.ActionText = "Buy " .. item.Name
	p.ObjectText = "R$ " .. item.Price
	p.HoldDuration = 0.3
	p.MaxActivationDistance = 14
	p.RequiresLineOfSight = false
	p.Parent = b
	p.Triggered:Connect(function(player)
		promptBuy(player, kind, key)
	end)
end
adBoard(Vector3.new(46, 9, -40), "Pass", "Radar", "EGG RADAR!")
adBoard(Vector3.new(46, 9, -72), "Product", "Hints10", "STUCK? GET HINTS!")

local spawnLoc = Instance.new("SpawnLocation")
spawnLoc.Anchored = true
spawnLoc.Size = Vector3.new(10, 0.4, 10)
spawnLoc.Position = Vector3.new(0, 0.3, -36)
spawnLoc.Transparency = 1
spawnLoc.CanCollide = false
spawnLoc.Duration = 0
spawnLoc.Parent = world
local HUB_SPAWN = CFrame.lookAt(Vector3.new(0, 4, -36), Vector3.new(0, 4, 0))

---------------------------------------------------------------------------
-- Eggs
---------------------------------------------------------------------------
local eggFolder = Instance.new("Folder")
eggFolder.Name = "Eggs"
eggFolder.Parent = workspace
local eggPos = {} -- id -> Vector3 (center)
local eggClue = {} -- id -> clue key

local function eggColor(def)
	local zone = Config.Zones[def.Zone]
	local h, _, _ = zone.Color:ToHSV()
	if def.RarityIndex == 7 then
		return Color3.fromRGB(26, 10, 40), Color3.fromRGB(200, 90, 255)
	elseif def.RarityIndex == 6 then
		return Color3.fromRGB(220, 30, 60), Color3.fromRGB(255, 205, 60)
	elseif def.RarityIndex == 5 then
		return Color3.fromRGB(255, 200, 40), Color3.fromRGB(255, 250, 200)
	end
	local hue = (h + (def.Slot * 0.173) % 0.36 - 0.18) % 1
	local base = Color3.fromHSV(hue, 0.35 + (def.Slot % 3) * 0.15, 1)
	local spot = Color3.fromHSV((hue + 0.5) % 1, 0.6, 0.95)
	return base, spot
end

local function makeEgg(def, pos)
	local ri = def.RarityIndex
	local s = 1 + (ri - 1) * 0.07
	local model = Instance.new("Model")
	model.Name = "Egg" .. def.Id
	local base, spotColor = eggColor(def)
	local size = Vector3.new(1.5, 1.95, 1.5) * s
	local center = pos + Vector3.new(0, size.Y / 2, 0)
	local body = ellipsoid(size, CFrame.new(center) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 6), rng:NextNumber(-0.2, 0.2)),
		base, model, { Name = "Body", CanCollide = false })
	local srng = Random.new(def.Id * 97)
	for _ = 1, 3 + ri do
		local theta = srng:NextNumber(0.5, 2.6)
		local phi = srng:NextNumber(0, math.pi * 2)
		local dir = Vector3.new(math.sin(theta) * math.cos(phi) * size.X / 2, math.cos(theta) * size.Y / 2, math.sin(theta) * math.sin(phi) * size.Z / 2) * 0.93
		local d = srng:NextNumber(0.3, 0.5) * s
		local sp = ellipsoid(Vector3.new(d, d, d * 0.45), CFrame.lookAt(center + dir, center + dir * 2), spotColor, model,
			{ CanCollide = false, CanTouch = false, Material = ri >= 6 and Enum.Material.Neon or Enum.Material.SmoothPlastic })
		local _ = sp
	end
	if ri >= 3 then
		local aura = Instance.new("ParticleEmitter")
		aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		aura.Color = ColorSequence.new(Config.Rarities[ri].Color)
		aura.LightEmission = 1
		aura.Size = NumberSequence.new(0.35, 0)
		aura.Lifetime = NumberRange.new(0.5, 1)
		aura.Rate = 1 + (ri - 3) * 1.5
		aura.Speed = NumberRange.new(0.5, 1.5)
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Parent = body
	end
	if ri >= 6 then
		local light = Instance.new("PointLight")
		light.Color = Config.Rarities[ri].Color
		light.Range = 8
		light.Brightness = 1.2
		light.Parent = body
	end
	model.PrimaryPart = body
	model:SetAttribute("EggId", def.Id)
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = Config.FindDistance
	click.Parent = model
	model.Parent = eggFolder
	eggPos[def.Id] = center
	return model, body, click
end

local onFind -- forward declared

local function pickSpots(z)
	local list = spots[z] or {}
	-- deterministic shuffle
	local srng = Random.new(z * 1013)
	for i = #list, 2, -1 do
		local j = srng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	local chosen = {}
	local taken = {}
	local function ok(sp)
		for _, c in ipairs(chosen) do
			if (c.Pos - sp.Pos).Magnitude < 12 then
				return false
			end
		end
		return true
	end
	local quota = { 8, 7, 5 }
	local byDiff = { {}, {}, {} }
	for diff = 3, 1, -1 do
		local want = quota[diff]
		for _, tryDiff in ipairs(diff == 3 and { 3, 2, 1 } or (diff == 2 and { 2, 3, 1 } or { 1, 2, 3 })) do
			for i, sp in ipairs(list) do
				if want > 0 and not taken[i] and sp.Diff == tryDiff and ok(sp) then
					taken[i] = true
					table.insert(chosen, sp)
					table.insert(byDiff[diff], sp)
					want -= 1
				end
			end
		end
	end
	return byDiff
end

for z = 1, #Config.Zones do
	local byDiff = pickSpots(z)
	local counters = { 0, 0, 0 }
	for slot = 1, 20 do
		local def = Config.Eggs[(z - 1) * 20 + slot]
		counters[def.Difficulty] += 1
		local sp = byDiff[def.Difficulty][counters[def.Difficulty]]
		if not sp then
			-- fallback: any free ground spot in the zone
			sp = { Pos = Vector3.new(rng:NextNumber(-80, 80), 0, zoneZ(z) + rng:NextNumber(20, 180)), Clue = "Ground" }
		end
		local model, body, click = makeEgg(def, sp.Pos)
		eggClue[def.Id] = sp.Clue
		model:SetAttribute("Clue", sp.Clue)
		click.MouseClick:Connect(function(player)
			onFind(player, def.Id)
		end)
		body.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player then
				onFind(player, def.Id)
			end
		end)
	end
end

---------------------------------------------------------------------------
-- Player state
---------------------------------------------------------------------------
local S = {}

local function hasPass(player, key)
	return player:GetAttribute("Pass_" .. key) == true
end

local function unlockedZones(s)
	local n = 1
	for z = 2, #Config.Zones do
		if s.Count >= Config.Zones[z].Need or s.Skip >= z then
			n = z
		else
			break
		end
	end
	return n
end

local function zoneCount(s, z)
	local n = 0
	for slot = 1, 20 do
		if s.Found[(z - 1) * 20 + slot] then
			n += 1
		end
	end
	return n
end

local function completedZones(s)
	local n = 0
	for z = 1, #Config.Zones do
		if zoneCount(s, z) >= 20 then
			n += 1
		end
	end
	return n
end

local function walkSpeed(player)
	local s = S[player]
	local base = hasPass(player, "Speed") and Config.SpeedPassSpeed or Config.BaseSpeed
	return base + (s and completedZones(s) or 0) * 1.5
end

local function applySpeed(player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = walkSpeed(player)
	end
end

local function headTag(player)
	local s = S[player]
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not s or not head then
		return
	end
	local old = head:FindFirstChild("HunterTag")
	if old then
		old:Destroy()
	end
	local t = Config.Title(s.Count)
	local lines = { { Text = t.Name, Color = t.Color }, { Text = "🥚 " .. s.Count .. "/" .. Config.TotalEggs } }
	if hasPass(player, "VIP") then
		table.insert(lines, 1, { Text = "👑 VIP", Color = Color3.fromRGB(255, 210, 50) })
	end
	local _, bb = billboard(head, lines, 2.6, 120, 22 * #lines, 60)
	bb.Name = "HunterTag"
end

local function sync(player)
	local s = S[player]
	local ids = {}
	for id in pairs(s.Found) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	player:SetAttribute("Found", table.concat(ids, ","))
	player:SetAttribute("FoundCount", s.Count)
	player:SetAttribute("Unlocked", unlockedZones(s))
	player:SetAttribute("Hints", s.Hints)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Eggs.Value = s.Count
	end
end

local function refreshPasses(player)
	for _, gp in ipairs(Config.GamePasses) do
		if gp.Id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, gp.Id)
			player:SetAttribute("Pass_" .. gp.Key, ok and owns or false)
		end
	end
end

local function award(player, key)
	local id = Config.Badges[key]
	if id and id ~= 0 then
		task.spawn(function()
			pcall(BadgeService.AwardBadge, BadgeService, player.UserId, id)
		end)
	end
end

function onFind(player, id)
	local s = S[player]
	local def = Config.Eggs[id]
	if not s or not s.Loaded or not def or s.Found[id] then
		return
	end
	if def.Zone > unlockedZones(s) then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - eggPos[id]).Magnitude > Config.FindDistance + 4 then
		return
	end
	local before = unlockedZones(s)
	s.Found[id] = true
	s.Count += 1
	s.Dirty = true
	sync(player)
	fx(player, "Found", id, s.Count)
	if def.RarityIndex >= 5 then
		announce("✨ " .. player.DisplayName .. " found the " .. string.upper(def.Rarity) .. " " .. def.Name .. "!", Config.Rarities[def.RarityIndex].Color)
	end
	if zoneCount(s, def.Zone) >= 20 then
		fx(player, "ZoneDone", def.Zone)
		award(player, "Zone" .. def.Zone)
		applySpeed(player)
		announce("🏆 " .. player.DisplayName .. " found every egg in " .. Config.Zones[def.Zone].Name .. "!", Config.Zones[def.Zone].Color)
	end
	local after = unlockedZones(s)
	if after > before then
		fx(player, "Unlocked", after)
	end
	if s.Count >= Config.TotalEggs then
		award(player, "All")
		announce("🐉 " .. player.DisplayName .. " FOUND ALL " .. Config.TotalEggs .. " DRAGON EGGS! 🐉", Color3.fromRGB(255, 70, 110))
	end
	headTag(player)
end

---------------------------------------------------------------------------
-- Lava sends you back to the zone entrance
---------------------------------------------------------------------------
local lavaDebounce = {}
for _, lava in ipairs(lavaParts) do
	lava.Part.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player or lavaDebounce[player] then
			return
		end
		lavaDebounce[player] = true
		task.delay(1, function()
			lavaDebounce[player] = nil
		end)
		local char = player.Character
		if char then
			char:PivotTo(zoneSpawns[lava.Zone])
			fx(player, "Lava")
		end
	end)
end

---------------------------------------------------------------------------
-- Leaderboard
---------------------------------------------------------------------------
local nameCache = {}
task.spawn(function()
	while true do
		local ok, pages = pcall(function()
			return lbStore:GetSortedAsync(false, 10)
		end)
		if ok and pages then
			local rows = pages:GetCurrentPage()
			for i = 1, 10 do
				local r = rows[i]
				if r then
					local uid = tonumber(r.key)
					local name = nameCache[uid]
					if not name and uid then
						local okName, n = pcall(Players.GetNameFromUserIdAsync, Players, uid)
						name = okName and n or "???"
						nameCache[uid] = name
					end
					lbRows[i].Text = i .. ". " .. tostring(name) .. "  🥚 " .. r.value
				else
					lbRows[i].Text = ""
				end
			end
		end
		task.wait(90)
	end
end)

---------------------------------------------------------------------------
-- Join / leave / save
---------------------------------------------------------------------------
local function save(player)
	local s = S[player]
	if not s or not s.Loaded then
		return
	end
	local ids = {}
	for id in pairs(s.Found) do
		ids[#ids + 1] = id
	end
	local data = { Found = ids, Hints = s.Hints, LastDaily = s.LastDaily, Skip = s.Skip }
	local ok, err = pcall(function()
		store:SetAsync(tostring(player.UserId), data)
	end)
	if not ok then
		warn("Save failed for", player.Name, err)
		return
	end
	s.Dirty = false
	pcall(function()
		lbStore:SetAsync(tostring(player.UserId), s.Count)
	end)
end

local function onCharacter(player, char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then
		return
	end
	hum.WalkSpeed = walkSpeed(player)
	char:WaitForChild("Head", 10)
	headTag(player)
end

Players.PlayerAdded:Connect(function(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = player
	local eggsV = Instance.new("IntValue")
	eggsV.Name = "Eggs"
	eggsV.Parent = ls

	local s = { Found = {}, Count = 0, Hints = 0, LastDaily = 0, Skip = 0, GiftAt = os.time() + Config.GiftInterval, Loaded = false }
	S[player] = s
	local ok, data = pcall(function()
		return store:GetAsync(tostring(player.UserId))
	end)
	if not ok then
		player:Kick("Could not load your data, please rejoin.")
		return
	end
	refreshPasses(player)
	local isNew = data == nil
	data = data or {}
	for _, id in ipairs(data.Found or {}) do
		if Config.Eggs[id] and not s.Found[id] then
			s.Found[id] = true
			s.Count += 1
		end
	end
	s.Hints = data.Hints or Config.StartHints
	s.LastDaily = data.LastDaily or 0
	s.Skip = data.Skip or 0
	player:SetAttribute("LastDaily", s.LastDaily)
	player:SetAttribute("GiftAt", s.GiftAt)
	player:SetAttribute("GlowUntil", 0)
	s.Loaded = true
	sync(player)

	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	fx(player, "Welcome", isNew)
end)

Players.PlayerRemoving:Connect(function(player)
	save(player)
	S[player] = nil
	lavaDebounce[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		save(player)
	end
end)

task.spawn(function()
	while true do
		task.wait(45)
		for _, player in ipairs(Players:GetPlayers()) do
			local s = S[player]
			if s and s.Dirty then
				save(player)
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Actions from the client
---------------------------------------------------------------------------
function promptBuy(player, kind, key)
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

local function nearestUnfound(player, s)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local maxZone = unlockedZones(s)
	local here = zoneOf(root.Position)
	local best, bestD
	for id, pos in pairs(eggPos) do
		local def = Config.Eggs[id]
		if not s.Found[id] and def.Zone <= maxZone then
			-- prefer eggs in the zone you're standing in
			local d = (pos - root.Position).Magnitude + (def.Zone == here and 0 or 400)
			if not bestD or d < bestD then
				best, bestD = id, d
			end
		end
	end
	return best
end

ActionRE.OnServerEvent:Connect(function(player, action, a, b)
	local s = S[player]
	if not s or not s.Loaded or type(action) ~= "string" then
		return
	end
	local now = os.time()
	if action == "Buy" then
		promptBuy(player, a, b)
	elseif action == "Hint" then
		if s.Hints <= 0 then
			fx(player, "NoHints")
			return
		end
		local id = nearestUnfound(player, s)
		if not id then
			fx(player, "Toast", s.Count >= Config.TotalEggs and "You found every egg! 🐉" or "Open the next zone to find more eggs!")
			return
		end
		s.Hints -= 1
		s.Dirty = true
		player:SetAttribute("Hints", s.Hints)
		fx(player, "Hint", id)
	elseif action == "Teleport" then
		local z = tonumber(a)
		if z == 0 then
			if player.Character then
				player.Character:PivotTo(HUB_SPAWN)
			end
		elseif z and zoneSpawns[z] and z <= unlockedZones(s) and player.Character then
			player.Character:PivotTo(zoneSpawns[z])
		else
			fx(player, "Toast", "That zone is still locked!")
		end
	elseif action == "Gift" then
		if now >= s.GiftAt then
			local n = hasPass(player, "VIP") and 2 or 1
			s.Hints += n
			s.GiftAt = now + Config.GiftInterval
			s.Dirty = true
			player:SetAttribute("GiftAt", s.GiftAt)
			player:SetAttribute("Hints", s.Hints)
			fx(player, "GotHints", n)
		end
	elseif action == "Daily" then
		if now - s.LastDaily >= 86400 then
			s.Hints += Config.DailyHints
			s.LastDaily = now
			player:SetAttribute("LastDaily", now)
			player:SetAttribute("Hints", s.Hints)
			fx(player, "GotHints", Config.DailyHints)
			save(player)
		else
			fx(player, "Toast", "Come back tomorrow for more hints!")
		end
	end
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, _, purchased)
	if purchased then
		refreshPasses(player)
		applySpeed(player)
		headTag(player)
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
			if prod.Hints then
				s.Hints += prod.Hints
				player:SetAttribute("Hints", s.Hints)
			end
			if prod.Glow then
				local untilT = math.max(player:GetAttribute("GlowUntil") or 0, os.time()) + prod.Glow
				player:SetAttribute("GlowUntil", untilT)
			end
			if prod.Key == "Skip" then
				local u = unlockedZones(s)
				if u >= #Config.Zones then
					s.Hints += 5
					player:SetAttribute("Hints", s.Hints)
					fx(player, "Toast", "All zones open! Got 5 hints instead.")
				else
					s.Skip = math.max(s.Skip, u + 1)
					sync(player)
					fx(player, "Unlocked", u + 1)
				end
			end
			save(player)
			fx(player, "Thanks")
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

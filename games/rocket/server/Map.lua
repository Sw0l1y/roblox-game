-- Builds every planet area once at server start (Earth island at the origin, then the Moon, Mars and Europa
-- 3000 studs apart). Same composition everywhere: spawn faces the rocket, the launch pad and tower are the
-- landmark, the Parts Depot sits left of the path, the crew board and kiosks frame the spawn walk, and themed
-- props sit in clusters. Flat palette parts; house MaterialVariants only on big flat surfaces.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local World = require(Shared:WaitForChild("World"))
local Parts = require(Shared:WaitForChild("Parts"))

local Map = {}

local V3 = Vector3.new
local CF = CFrame.new
local RAD = math.rad
local P = Config.Palette

export type Area = {
	index: number,
	origin: Vector3,
	folder: Folder,
	spawn: SpawnLocation,
	spawnCF: CFrame, -- feet position, facing the rocket
	padCenter: Vector3, -- ground level
	padRadius: number,
	boltRadius: number,
	rocketBase: CFrame, -- top of the pad, rocket front = -Z
	depotPads: { Vector3 },
	ftuePad: Vector3,
	landing: Vector3,
	botHome: Vector3,
	playRadius: number,
	boardTitle: TextLabel,
	boardRows: { TextLabel },
	progressGui: BillboardGui,
	progressText: TextLabel,
	progressFill: Frame,
}

Map.areas = {} :: { Area }

local SPAWN = Config.Layout.spawn
local PAD = Config.Layout.pad
local PAD_TOP = Config.Layout.padTop

-- Small builders ---------------------------------------------------------------------------------------

local function decor(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local function neon(p: BasePart): BasePart
	p.Material = Enum.Material.Neon
	return p
end

local function flag(f: Instance, pos: Vector3, color: Color3)
	World.cyl(f, pos, 12, 0.5, P.white, { Name = "FlagPole" })
	World.ball(f, pos + V3(0, 12.2, 0), 0.9, P.gold, { Name = "FlagTop" })
	World.box(f, CF(pos + V3(2.4, 10.4, 0)), V3(4.4, 2.8, 0.2), color, { Name = "Flag" })
	World.box(f, CF(pos + V3(2.4, 10.4, 0)), V3(4.45, 0.6, 0.25), P.white, { Name = "FlagStripe" })
end

local function dish(f: Instance, pos: Vector3, yaw: number, scale: number)
	local s = scale
	World.cyl(f, pos, 1.2 * s, 5 * s, P.pad, { Name = "DishBase" })
	World.cyl(f, pos + V3(0, 1.2 * s, 0), 6 * s, 1.2 * s, P.padDark, { Name = "DishPost" })
	local c = CF(pos + V3(0, 8 * s, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(RAD(-35), 0, 0)
	World.part({ Name = "Dish", Shape = Enum.PartType.Ball, Size = V3(10 * s, 2.4 * s, 10 * s), CFrame = c, Color = P.white, Parent = f })
	World.part({ Name = "DishInner", Shape = Enum.PartType.Ball, Size = V3(8 * s, 1.6 * s, 8 * s), CFrame = c * CF(0, 0.6 * s, 0), Color = P.padLight, Parent = f })
	World.rod(f, (c * CF(0, 0.6 * s, 0)).Position, (c * CF(0, 4.2 * s, 0)).Position, 0.4 * s, P.navy)
	neon(World.ball(f, (c * CF(0, 4.4 * s, 0)).Position, 0.9 * s, P.orange, { Name = "DishTip", CanCollide = false }))
end

local function dome(f: Instance, pos: Vector3, d: number, body: Color3, trim: Color3)
	World.part({ Name = "Dome", Shape = Enum.PartType.Ball, Size = V3(d, d, d), CFrame = CF(pos), Color = body, Parent = f })
	World.disc(f, pos.X, pos.Z, d / 2 + 0.6, 1.2, 1.2, trim)
	-- door
	World.box(f, CF(pos + V3(0, 2.4, -d / 2 + 0.6)), V3(4, 4.8, 2.2), trim, { Name = "DomeDoor" })
	neon(World.box(f, CF(pos + V3(0, 2.4, -d / 2 - 0.45)), V3(2.6, 3.6, 0.2), P.glow, { Name = "DomeDoorGlow", CanCollide = false }))
	-- windows ring
	for i = 0, 3 do
		local a = RAD(-45 + i * 90 + 45)
		local dir = V3(math.cos(a), 0, math.sin(a))
		local c = pos + dir * (d * 0.43) + V3(0, d * 0.22, 0)
		neon(World.part({ Name = "DomeWindow", Shape = Enum.PartType.Ball, Size = V3(2.2, 2.2, 2.2), CFrame = CF(c), Color = P.glow, Parent = f, CanCollide = false }))
	end
end

local function solar(f: Instance, pos: Vector3, yaw: number)
	local base = CF(pos) * CFrame.Angles(0, yaw, 0)
	World.box(f, base * CF(0, 1.5, 0), V3(0.8, 3, 0.8), P.pad, { Name = "SolarPost" })
	local panel = base * CF(0, 3.2, 0) * CFrame.Angles(RAD(25), 0, 0)
	World.box(f, panel, V3(10, 0.4, 5), P.navy, { Name = "SolarPanel" })
	World.box(f, panel * CF(0, 0.22, 0), V3(9.4, 0.1, 4.4), Color3.fromRGB(60, 90, 170), { Name = "SolarCells" })
	World.box(f, panel * CF(0, 0.25, 0), V3(0.25, 0.1, 4.4), P.padLight, { Name = "SolarLine" })
end

local function rover(f: Instance, pos: Vector3, yaw: number, body: Color3)
	local base = CF(pos) * CFrame.Angles(0, yaw, 0)
	World.box(f, base * CF(0, 2.6, 0), V3(5, 1.6, 8), body, { Name = "RoverBody" })
	World.box(f, base * CF(0, 3.9, 1), V3(4, 1.2, 4), P.white, { Name = "RoverCab" })
	neon(World.box(f, base * CF(0, 3.9, -1.05), V3(3.4, 0.8, 0.2), P.glow, { Name = "RoverWindow", CanCollide = false }))
	for _, x in ipairs({ -2.8, 2.8 }) do
		for _, z in ipairs({ -2.8, 0, 2.8 }) do
			local w = (base * CF(x, 1.2, z)).Position
			World.part({ Name = "RoverWheel", Shape = Enum.PartType.Cylinder, Size = V3(1, 2.4, 2.4), CFrame = CF(w) * CFrame.Angles(0, yaw, 0), Color = P.navy, Parent = f })
		end
	end
	World.rod(f, (base * CF(1.6, 3.4, 3)).Position, (base * CF(1.6, 7, 3)).Position, 0.25, P.pad)
	neon(World.ball(f, (base * CF(1.6, 7.2, 3)).Position, 0.7, P.orange, { Name = "RoverBeacon", CanCollide = false }))
end

local function barrels(f: Instance, pos: Vector3)
	World.barrel(f, pos, P.white, P.orange, P.navy)
	World.barrel(f, pos + V3(3, 0, 1.4), P.white, P.orange, P.navy)
	World.barrel(f, pos + V3(0.6, 0, 3.2), P.orange, P.white, P.navy)
end

local function crates(f: Instance, pos: Vector3)
	World.crate(f, pos, 4, P.orange, P.navy)
	World.crate(f, pos + V3(4.4, 0, -0.8), 3.2, P.white, P.navy)
	World.crate(f, pos + V3(0.6, 4, 0.2), 3, P.white, P.navy)
end

-- Big ball in the sky (Earth from the Moon, Jupiter from Europa, Mars' moons).
local function skyBall(f: Instance, pos: Vector3, d: number, color: Color3, spots: { { any } }?)
	decor(World.ball(f, pos, d, color, { Name = "SkyBody" }))
	for _, sp in ipairs(spots or {}) do
		local off = sp[1] :: Vector3
		local size = sp[2] :: number
		local col = sp[3] :: Color3
		decor(World.ball(f, pos + off.Unit * (d / 2 - size * 0.32), size, col, { Name = "SkySpot" }))
	end
end

local function crater(f: Instance, pos: Vector3, r: number, inner: Color3, rim: Color3, rng: Random)
	World.disc(f, pos.X, pos.Z, r, 0.06, 0.4, inner)
	local n = math.max(8, math.floor(r * 0.9))
	for i = 1, n do
		local a = i / n * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local d = rng:NextNumber(0.55, 0.8) * r
		local c = pos + V3(math.cos(a) * r, d * 0.1, math.sin(a) * r)
		World.part({
			Name = "CraterRim",
			Shape = Enum.PartType.Ball,
			Size = V3(d, d * 0.42, d),
			CFrame = CF(c),
			Color = (i % 3 == 0) and inner or rim,
			Parent = f,
		})
	end
end

local function mesa(f: Instance, pos: Vector3, r: number, h: number, c1: Color3, c2: Color3)
	local layers = 4
	for k = 0, layers - 1 do
		local rr = r * (1 - k * 0.12)
		World.cyl(f, pos + V3(0, k * h / layers, 0), h / layers + 0.05, rr * 2, k % 2 == 0 and c1 or c2, { Name = "Mesa" })
	end
	World.cyl(f, pos + V3(0, h, 0), 0.8, r * 2 * 0.62, c2, { Name = "MesaTop" })
end

local function iceSpikes(f: Instance, pos: Vector3, rng: Random, scale: number)
	for i = 1, 5 do
		local h = rng:NextNumber(6, 16) * scale
		local w = rng:NextNumber(1.6, 3.2) * scale
		local off = V3(rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5)) * scale
		local tilt = CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 6.28), rng:NextNumber(-0.25, 0.25))
		local col = i % 3 == 0 and Color3.fromRGB(120, 230, 255) or Color3.fromRGB(196, 240, 255)
		local p = World.box(f, CF(pos + off + V3(0, h * 0.42, 0)) * tilt, V3(w, h, w), col, { Name = "IceSpike" })
		if i % 3 == 0 then
			p.Material = Enum.Material.Neon
			p.Transparency = 0.15
		end
		World.box(f, CF(pos + off + V3(0, h * 0.42 + h / 2, 0)) * tilt * CFrame.Angles(0, RAD(45), 0), V3(w * 0.72, w * 0.72, w * 0.72), col, { Name = "IceTip" })
	end
end

local function lampRow(f: Instance, a: Vector3, b: Vector3, every: number, side: number, glow: Color3)
	local dir = (b - a)
	local len = dir.Magnitude
	if len < 1 then
		return
	end
	local u = dir.Unit
	local perp = V3(-u.Z, 0, u.X)
	local n = math.floor(len / every)
	for i = 1, n do
		local p = a + u * (i * every - every / 2) + perp * side
		World.lamp(f, p, P.navy, glow)
	end
end

-- Structures -------------------------------------------------------------------------------------------

local function buildSpawn(f: Folder, O: Vector3, i: number): (SpawnLocation, CFrame)
	local pos = O + SPAWN
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn_" .. Config.planet(i).key
	spawn.Anchored = true
	spawn.Size = V3(12, 1, 12)
	spawn.CFrame = CFrame.lookAt(pos + V3(0, 0.5, 0), O + PAD + V3(0, 0.5, 0))
	spawn.Transparency = 1
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Enabled = i == 1
	spawn.Parent = f
	World.disc(f, pos.X, pos.Z, 9, 0.5, 0.5, P.navy)
	World.disc(f, pos.X, pos.Z, 8.2, 0.62, 0.5, P.orange)
	World.disc(f, pos.X, pos.Z, 6.6, 0.7, 0.5, P.white, "HouseSlabs")
	local ring = World.disc(f, pos.X, pos.Z, 7.4, 0.66, 0.5, P.sky)
	ring.Material = Enum.Material.Neon
	-- welcome arch framing the rocket
	local archZ = pos.Z + 22
	-- tall and wide so the sign sits above the rocket from the spawn camera
	for _, x in ipairs({ -14, 14 }) do
		World.box(f, CF(pos.X + x, 10, archZ), V3(2, 20, 2), P.orange, { Name = "ArchPost" })
		World.box(f, CF(pos.X + x, 0.6, archZ), V3(3, 1.2, 3), P.navy, { Name = "ArchFoot" })
		neon(World.ball(f, V3(pos.X + x, 20.6, archZ), 1.6, P.gold, { Name = "ArchLight", CanCollide = false }))
	end
	World.sign(f, CF(pos.X, 22.4, archZ), Vector2.new(30, 4.4), "🚀 BUILD THE ROCKET!", P.navy, P.gold, nil)
	return spawn, CFrame.lookAt(pos + V3(0, 1, 0), O + PAD + V3(0, 1, 0))
end

local function buildPad(f: Folder, O: Vector3, padR: number, boltR: number, area: { [string]: any })
	local c = O + PAD
	World.disc(f, c.X, c.Z, padR + 2.4, 0.5, 2, P.navy)
	World.disc(f, c.X, c.Z, padR + 1.2, 0.62, 1.6, P.orange)
	World.disc(f, c.X, c.Z, padR, PAD_TOP, 2, P.white, "HouseSlabs")
	-- bolt zone ring (neon ring = neon disc under a slightly smaller pad disc)
	local zone = World.disc(f, c.X, c.Z, boltR + 0.7, PAD_TOP + 0.02, 0.3, P.sky)
	zone.Material = Enum.Material.Neon
	zone.CanCollide = false
	World.disc(f, c.X, c.Z, boltR - 0.7, PAD_TOP + 0.04, 0.3, P.white, "HouseSlabs")
	-- engine plate and flame trench
	World.disc(f, c.X, c.Z, 12, PAD_TOP + 0.06, 0.3, P.padDark)
	World.disc(f, c.X, c.Z, 8, PAD_TOP + 0.08, 0.3, P.navy)
	-- hazard stripes around the edge
	local n = 32
	for k = 0, n - 1 do
		local a = (k + 0.5) / n * math.pi * 2
		local r = padR - 1.4
		local p = c + V3(math.cos(a) * r, PAD_TOP + 0.03, math.sin(a) * r)
		World.box(f, CFrame.lookAt(p, c + V3(0, PAD_TOP + 0.03, 0)), V3(2 * math.pi * r / n * 0.56, 0.12, 2), k % 2 == 0 and P.orange or P.navy, { Name = "Hazard" })
	end
	-- glowing corner lights
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2 + math.pi / 8
		local p = c + V3(math.cos(a) * (padR + 0.6), PAD_TOP, math.sin(a) * (padR + 0.6))
		World.cyl(f, p - V3(0, 0.3, 0), 1, 2.2, P.navy, { Name = "PadLightBase" })
		neon(World.ball(f, p + V3(0, 0.9, 0), 1.4, P.orange, { Name = "PadLight", CanCollide = false }))
	end
	-- "BOLT ZONE" floor label
	local lab = World.box(f, CF(c + V3(0, PAD_TOP + 0.06, -boltR + 3.4)), V3(16, 0.1, 3.4), P.white, { Name = "ZoneLabel", Transparency = 1, CanCollide = false })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Top
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.Text = "⬇ BOLT PARTS HERE ⬇"
	t.TextColor3 = P.sky
	t.Rotation = 180
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Color = P.navy
	st.Parent = t
	t.Parent = sg
	sg.Parent = lab
	area.padCenter = c
end

local function buildTower(f: Folder, O: Vector3, padR: number, height: number, scale: number)
	local c = O + PAD
	local a = RAD(135)
	local dir = V3(math.cos(a), 0, math.sin(a))
	local t = c + dir * (padR + 7)
	local H = math.ceil(height / 14) * 14 + 14
	local look = CFrame.lookAt(t, V3(c.X, t.Y, c.Z))
	World.box(f, look * CF(0, 0.5, 0), V3(14, 1, 14), P.pad, { Name = "TowerBase" })
	local corners = { V3(-5, 0, -5), V3(5, 0, -5), V3(5, 0, 5), V3(-5, 0, 5) }
	for _, k in ipairs(corners) do
		World.box(f, look * CF(k.X, H / 2, k.Z), V3(1.8, H, 1.8), P.white, { Name = "TowerPost" })
	end
	local levels = math.floor(H / 14)
	for lv = 1, levels do
		local y0 = (lv - 1) * 14
		for side = 1, 4 do
			local p1 = corners[side]
			local p2 = corners[side % 4 + 1]
			local A = (look * CF(p1.X, y0 + (side % 2 == 0 and 0 or 14), p1.Z)).Position
			local B = (look * CF(p2.X, y0 + (side % 2 == 0 and 14 or 0), p2.Z)).Position
			World.rod(f, A, B, 0.7, P.orange)
		end
		World.box(f, look * CF(0, y0 + 14, 0), V3(11.6, 0.8, 11.6), lv % 2 == 0 and P.navy or P.pad, { Name = "TowerDeck" })
	end
	-- top cabin, beacon and crane over the rocket
	World.box(f, look * CF(0, H + 3, 0), V3(10, 6, 10), P.navy, { Name = "TowerCabin" })
	neon(World.box(f, look * CF(0, H + 3.4, -5.05), V3(8, 2.4, 0.2), P.glow, { Name = "CabinWindow", CanCollide = false }))
	World.box(f, look * CF(0, H + 6.4, 0), V3(11, 0.8, 11), P.orange, { Name = "CabinRoof" })
	local beacon = neon(World.ball(f, (look * CF(0, H + 8, 0)).Position, 2, P.red, { Name = "Beacon", CanCollide = false }))
	local light = Instance.new("PointLight")
	light.Color = P.red
	light.Range = 30
	light.Brightness = 2
	light.Parent = beacon
	beacon:SetAttribute("Blink", true)
	local reach = padR + 2 - 8.8 * scale
	local armY = math.min(40 * scale, H - 10)
	World.box(f, look * CF(0, armY, -5 - reach / 2), V3(3, 2, reach), P.orange, { Name = "AccessArm" })
	World.box(f, look * CF(0, armY + 1.1, -5 - reach / 2), V3(3.1, 0.3, reach), P.navy, { Name = "AccessArmStripe" })
	World.box(f, look * CF(0, H + 1, -5 - (reach + 6) / 2), V3(2.4, 2.4, reach + 6), P.white, { Name = "Crane" })
	World.rod(f, (look * CF(0, H + 1, -8 - reach)).Position, (look * CF(0, H - 8, -8 - reach)).Position, 0.3, P.navy)
	neon(World.ball(f, (look * CF(0, H - 8.4, -8 - reach)).Position, 1.2, P.orange, { Name = "CraneHook", CanCollide = false }))
end

local function buildDepot(f: Folder, O: Vector3, area: { [string]: any })
	local x0, z0 = O.X + 80, O.Z - 14
	local floorCF = CF(x0, 0.4, z0)
	World.part({ Name = "DepotFloor", Size = V3(26, 0.8, 44), CFrame = floorCF, Color = P.white, Variant = "HouseSlabs", Parent = f })
	World.box(f, CF(x0 + 12, 8, z0), V3(2, 16, 44), P.white, { Name = "DepotBack", Variant = "HousePanels" })
	for _, dz in ipairs({ -22, 22 }) do
		World.box(f, CF(x0 + 1, 8, z0 + dz), V3(24, 16, 2), P.white, { Name = "DepotSide", Variant = "HousePanels" })
		for k = 0, 2 do
			World.box(f, CF(x0 - 11 + k * 1.6, 8, z0 + dz), V3(1.2, 16, 2.2), k % 2 == 0 and P.orange or P.navy, { Name = "DepotStripe" })
		end
	end
	World.box(f, CF(x0 + 1, 16.7, z0), V3(30, 1.4, 50), P.orange, { Name = "DepotRoof" })
	World.box(f, CF(x0 - 14, 15.6, z0), V3(1, 3, 50), P.navy, { Name = "DepotFascia" })
	World.sign(f, CF(x0 - 14.8, 21, z0) * CFrame.Angles(0, RAD(-90), 0), Vector2.new(28, 6), "📦 PARTS DEPOT", P.navy, P.gold, nil)
	-- conveyor along the back wall with rollers
	World.box(f, CF(x0 + 7, 1.6, z0), V3(4, 1.6, 38), P.navy, { Name = "Conveyor" })
	for k = -8, 8 do
		World.part({ Name = "Roller", Shape = Enum.PartType.Cylinder, Size = V3(4.2, 0.9, 0.9), CFrame = CF(x0 + 7, 2.45, z0 + k * 2.2), Color = P.orange, Parent = f })
	end
	-- stacked stock on the conveyor
	for k, dz in ipairs({ -14, -2, 10 }) do
		World.cyl(f, V3(x0 + 7, 2.9, z0 + dz), 4.2, 3.4, k == 2 and P.orange or P.white, { Name = "StockTank" })
		World.cyl(f, V3(x0 + 7, 5.6, z0 + dz), 0.6, 3.6, P.navy, { Name = "StockBand" })
	end
	-- robot arm
	World.cyl(f, V3(x0 + 2, 0.8, z0 + 16), 2, 4, P.navy, { Name = "ArmBase" })
	World.rod(f, V3(x0 + 2, 2.8, z0 + 16), V3(x0 - 1, 9, z0 + 13), 1.2, P.orange)
	World.rod(f, V3(x0 - 1, 9, z0 + 13), V3(x0 - 4, 7, z0 + 9), 1, P.orange)
	neon(World.ball(f, V3(x0 - 4, 6.6, z0 + 9), 1.4, P.glow, { Name = "ArmGrip", CanCollide = false }))
	-- pickup pads in front
	local pads: { Vector3 } = {}
	for _, px in ipairs({ x0 - 22, x0 - 35 }) do
		for _, pz in ipairs({ z0 - 18, z0, z0 + 18 }) do
			local p = V3(px, 0, pz)
			World.pad(f, p, 6.2, P.sky)
			table.insert(pads, p)
		end
	end
	area.depotPads = pads
	crates(f, V3(x0 - 8, 0.8, z0 - 18))
	barrels(f, V3(x0 - 6, 0.8, z0 + 17))
	crates(f, V3(x0 - 18, 0, z0 + 29))
	barrels(f, V3(x0 - 26, 0, z0 - 30))
end

local function buildBoard(f: Folder, O: Vector3, area: { [string]: any })
	local pos = O + V3(-34, 0, -44)
	local look = CFrame.lookAt(pos, O + V3(4, 0, -72))
	local cf = look * CF(0, 11, 0)
	World.box(f, look * CF(-10, 5, 0), V3(1.4, 10, 1.4), P.navy, { Name = "BoardPost" })
	World.box(f, look * CF(10, 5, 0), V3(1.4, 10, 1.4), P.navy, { Name = "BoardPost" })
	World.box(f, cf, V3(23, 14, 1.4), P.orange, { Name = "BoardFrame" })
	local b = World.box(f, cf * CF(0, 0, -0.3), V3(21.6, 12.6, 1.2), P.navy, { Name = "Board" })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 24
	sg.LightInfluence = 0
	sg.MaxDistance = 200
	local function label(y: number, h: number, text: string, color: Color3): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0.05, y)
		l.Size = UDim2.fromScale(0.9, h)
		l.Font = Enum.Font.LuckiestGuy
		l.TextScaled = true
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Text = text
		l.TextColor3 = color
		local s = Instance.new("UIStroke")
		s.Thickness = 3
		s.Color = Color3.fromRGB(16, 20, 40)
		s.Parent = l
		l.Parent = sg
		return l
	end
	local title = label(0.04, 0.17, "🏆 CREW BOARD", P.gold)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local rows = {}
	for k = 1, 5 do
		table.insert(rows, label(0.24 + (k - 1) * 0.145, 0.12, "", k == 1 and P.gold or P.white))
	end
	sg.Parent = b
	area.boardTitle = title
	area.boardRows = rows
	World.box(f, look * CF(0, 18.6, 0), V3(10, 1.4, 1.6), P.orange, { Name = "BoardCap" })
	neon(World.ball(f, (look * CF(0, 20, 0)).Position, 1.6, P.gold, { Name = "BoardStar", CanCollide = false }))
end

local function buildKiosk(f: Folder, pos: Vector3, facing: Vector3, title: string, panel: string, color: Color3)
	local look = CFrame.lookAt(pos, V3(facing.X, pos.Y, facing.Z))
	World.box(f, look * CF(0, 1.8, 0), V3(10, 3.6, 4), P.white, { Name = "KioskCounter" })
	World.box(f, look * CF(0, 3.7, 0), V3(10.4, 0.4, 4.4), color, { Name = "KioskTop" })
	for _, x in ipairs({ -4.6, 4.6 }) do
		World.box(f, look * CF(x, 6, 1.2), V3(0.8, 8, 0.8), P.navy, { Name = "KioskPost" })
	end
	World.box(f, look * CF(0, 10.2, 0.4), V3(11.6, 0.8, 6), color, { Name = "KioskRoof" })
	for k = 0, 3 do
		World.box(f, look * CF(-4.35 + k * 2.9, 9.4, -2.5), V3(2.9, 0.9, 0.4), k % 2 == 0 and P.white or color, { Name = "KioskAwning" })
	end
	World.sign(f, look * CF(0, 12.6, 0.4), Vector2.new(11, 3), title, P.navy, P.gold, nil)
	local att = Instance.new("Attachment")
	att.Position = V3(0, 4.5, 0)
	local host = World.box(f, look * CF(0, 1.8, -2.4), V3(9, 3.4, 0.4), color, { Name = "KioskFront" })
	att.Parent = host
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "OPEN"
	prompt.ObjectText = title
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt:SetAttribute("OpenPanel", panel)
	prompt.Parent = att
end

local function buildLanding(f: Folder, O: Vector3, area: { [string]: any })
	local c = O + Config.Layout.landing
	World.disc(f, c.X, c.Z, 15, 0.4, 0.8, P.navy)
	World.disc(f, c.X, c.Z, 13.6, 0.5, 0.8, P.white, "HouseSlabs")
	local ring = World.disc(f, c.X, c.Z, 11, 0.55, 0.8, P.orange)
	ring.Material = Enum.Material.Neon
	World.disc(f, c.X, c.Z, 10, 0.6, 0.8, P.white, "HouseSlabs")
	World.box(f, CF(c + V3(0, 0.62, 0)), V3(12, 0.1, 2.4), P.orange, { Name = "LandingH" })
	World.box(f, CF(c + V3(-4.8, 0.62, 0)), V3(2.4, 0.1, 9), P.orange, { Name = "LandingH" })
	World.box(f, CF(c + V3(4.8, 0.62, 0)), V3(2.4, 0.1, 9), P.orange, { Name = "LandingH" })
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		neon(World.ball(f, c + V3(math.cos(a) * 14, 1, math.sin(a) * 14), 1, P.sky, { Name = "LandingLight", CanCollide = false }))
	end
	World.sign(f, CFrame.lookAt(c + V3(0, 3, 17), c + V3(0, 3, 40)), Vector2.new(12, 2.6), "🛬 LANDING ZONE", P.navy, P.white, P.navy)
	area.landing = c
end

local function fuelStation(f: Folder, pos: Vector3, toward: Vector3)
	local look = CFrame.lookAt(pos, V3(toward.X, pos.Y, toward.Z))
	World.box(f, look * CF(0, 0.6, 0), V3(16, 1.2, 12), P.pad, { Name = "FuelBase" })
	for k = 0, 7 do
		World.box(f, look * CF(-7 + k * 2, 1.25, 5.3), V3(2, 0.2, 1.4), k % 2 == 0 and P.orange or P.navy, { Name = "FuelHazard" })
	end
	for _, z in ipairs({ -2.6, 2.6 }) do
		local tankCF = look * CF(0, 4.4, z) * CFrame.Angles(0, RAD(90), 0)
		World.part({ Name = "FuelTank", Shape = Enum.PartType.Cylinder, Size = V3(10, 5, 5), CFrame = tankCF * CFrame.Angles(0, RAD(90), 0), Color = P.white, Parent = f })
		for _, x in ipairs({ -5, 5 }) do
			World.ball(f, (look * CF(x, 4.4, z)).Position, 5, P.orange, { Name = "FuelCap" })
		end
		World.part({ Name = "FuelBand", Shape = Enum.PartType.Cylinder, Size = V3(0.8, 5.3, 5.3), CFrame = look * CF(0, 4.4, z), Color = P.navy, Parent = f })
	end
	World.rod(f, (look * CF(8, 1.4, 0)).Position, (look * CF(8, 1.4, 0)).Position:Lerp(toward + V3(0, 1.4, 0), 0.7), 1.4, P.navy)
end

local function missionControl(f: Folder, pos: Vector3, toward: Vector3)
	local look = CFrame.lookAt(pos, V3(toward.X, pos.Y, toward.Z))
	World.box(f, look * CF(0, 7, 0), V3(20, 14, 14), P.white, { Name = "MCBody", Variant = "HousePanels" })
	World.box(f, look * CF(0, 14.4, 0), V3(21, 1, 15), P.orange, { Name = "MCRoof" })
	World.box(f, look * CF(0, 9, -7.05), V3(16, 3.4, 0.2), P.glow, { Name = "MCWindow", Material = Enum.Material.Neon, CanCollide = false })
	World.box(f, look * CF(0, 2.6, -7.1), V3(4, 5.2, 0.4), P.navy, { Name = "MCDoor" })
	World.box(f, look * CF(0, 4.6, -7.05), V3(20.2, 0.8, 0.3), P.orange, { Name = "MCStripe" })
	World.sign(f, look * CF(0, 17, 0), Vector2.new(18, 3), "MISSION CONTROL", P.navy, P.white, nil)
	dish(f, (look * CF(5, 14.8, 3)).Position, RAD(200), 0.7)
end

-- Ground -----------------------------------------------------------------------------------------------

local function earthGround(f: Folder, O: Vector3)
	local blobs = {
		{ 0, -78, 44 }, { 0, 40, 58 }, { 74, -16, 46 }, { -50, -56, 36 }, { -52, 8, 40 }, { -38, 94, 36 },
		{ 42, 86, 38 }, { 36, -54, 32 }, { 88, 32, 30 }, { -88, -22, 26 }, { 0, 112, 30 }, { -20, -30, 30 }, { 30, 2, 34 },
	}
	local shifted = {}
	for _, b in ipairs(blobs) do
		table.insert(shifted, { O.X + b[1], O.Z + b[2], b[3] })
	end
	World.island(f, shifted, { grass = P.grass, sand = P.sand, wet = P.sandWet }, { grass = "HouseGrass", sand = "HouseSand" })
	-- tint patches
	for _, pt in ipairs({ { 30, -40, 12, 1 }, { -36, 52, 14, 1 }, { 46, 78, 13, 1 }, { -24, 120, 12, 1 }, { -26, -6, 10, 0 }, { 64, 40, 9, 0 }, { -68, 30, 11, 0 } }) do
		local light = pt[4] == 1
		local d = World.disc(f, O.X + pt[1], O.Z + pt[2], pt[3], 0.05, 0.1, light and P.grassLight or P.grassDark, light and "HouseGrass" or "HouseGrassDark")
		d.CanCollide = false
	end
	local sea = World.box(f, CF(O.X, -1.7, O.Z), V3(2048, 1, 2048), P.water, { Name = "Ocean" })
	sea.CastShadow = false
	local shallow = World.disc(f, O.X + 4, O.Z + 10, 190, -1.15, 0.4, P.waterShallow)
	shallow.CastShadow = false
	shallow.CanCollide = false
end

local function planetGround(f: Folder, O: Vector3, pl: Config.Planet)
	World.part({
		Name = "Ground",
		Shape = Enum.PartType.Cylinder,
		Size = V3(6, 520, 520),
		CFrame = CF(O.X, -3, O.Z) * CFrame.Angles(0, 0, RAD(90)),
		Color = pl.ground,
		Variant = pl.variant,
		Parent = f,
	})
	local horizon = World.box(f, CF(O.X, -0.6, O.Z), V3(2048, 1, 2048), pl.groundDark, { Name = "Horizon" })
	horizon.CastShadow = false
	local rng = Random.new(pl.origin.X + 7)
	for k = 1, 12 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(60, 220)
		local d = World.disc(f, O.X + math.cos(a) * r, O.Z + math.sin(a) * r, rng:NextNumber(10, 22), 0.04, 0.1, k % 2 == 0 and pl.groundLight or pl.groundDark)
		d.CanCollide = false
	end
end

-- Paths between spawn, pad and depot.
local function paths(f: Folder, O: Vector3, padR: number, planet: number)
	local slab = planet == 1 and P.white or P.padLight
	local pad = O + PAD
	World.path(f, { O + SPAWN + V3(0, 0, 8), V3(pad.X, 0, pad.Z - padR - 1) }, 10, slab, "HouseSlabs")
	local depotFront = O + V3(46, 0, -14)
	local toPad = (V3(pad.X, 0, pad.Z) - depotFront).Unit
	World.path(f, { depotFront, V3(pad.X, 0, pad.Z) - toPad * (padR + 1) }, 12, slab, "HouseSlabs")
	World.path(f, { O + SPAWN + V3(10, 0, 4), depotFront + V3(0, 0, -10) }, 8, slab, "HouseSlabs")
	World.path(f, { O + SPAWN + V3(-8, 0, 2), O + V3(-50, 0, -60) }, 7, slab, "HouseSlabs")
	-- orange edge lines along the main path
	for _, side in ipairs({ -5.6, 5.6 }) do
		World.box(f, CF(O.X + side, 0.3, (O.Z + SPAWN.Z + 8 + pad.Z - padR - 1) / 2), V3(0.8, 0.2, (pad.Z - padR - 1) - (O.Z + SPAWN.Z + 8)), P.orange, { Name = "PathEdge", CanCollide = false })
	end
	lampRow(f, O + SPAWN + V3(0, 0, 10), V3(pad.X, 0, pad.Z - padR), 22, 8, planet == 1 and P.gold or P.glow)
	lampRow(f, depotFront, V3(pad.X, 0, pad.Z) - toPad * padR, 22, 9, planet == 1 and P.gold or P.glow)
end

-- Themed decor -----------------------------------------------------------------------------------------

local LEAVES: World.Leaves = { trunk = P.trunk, leaf1 = P.leaf1, leaf2 = P.leaf2, leaf3 = P.leaf3 }

local function earthDecor(f: Folder, O: Vector3, rng: Random)
	local function at(x: number, z: number): Vector3
		return O + V3(x, 0, z)
	end
	for _, t in ipairs({ { -64, -72 }, { 26, -104 }, { -74, 14 }, { 58, 70 }, { -30, 108 }, { 92, 22 }, { 16, 120 }, { -96, -28 }, { 40, -64 } }) do
		World.treeTrio(f, at(t[1], t[2]), LEAVES, 1)
	end
	for _, b in ipairs({ { -16, -52 }, { 16, -40 }, { -16, -22 }, { 18, -8 }, { -40, -24 }, { 62, -50 }, { -60, 46 }, { 30, 76 }, { -10, 98 }, { 96, -2 }, { -78, -50 }, { 50, 104 } }) do
		World.bush(f, at(b[1], b[2]), LEAVES, rng, 1)
	end
	for _, r in ipairs({ { -88, -10 }, { 66, -60 }, { 56, 104 }, { -60, 120 }, { 100, 40 }, { -20, -112 } }) do
		World.rocks(f, at(r[1], r[2]), { rock = P.rock, rockDark = P.rockDark }, rng, 1)
	end
	for _, fl in ipairs({ { -12, -96 }, { 14, -92 }, { -24, -64 }, { 24, -70 }, { -40, 70 }, { 36, 56 }, { -8, -36 } }) do
		World.flowers(f, at(fl[1], fl[2]), P.leaf1, { P.orange, P.white, P.sky, P.gold }, rng)
	end
	for k = 1, 9 do
		local a = k / 9 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local r = rng:NextNumber(260, 420)
		World.cloud(f, O + V3(math.cos(a) * r, rng:NextNumber(120, 190), math.sin(a) * r), rng:NextNumber(1.4, 2.2), rng)
	end
	fuelStation(f, at(-44, 96), O + PAD)
	missionControl(f, at(-66, 2), O + V3(0, 0, -40))
	dish(f, at(70, 64), RAD(140), 1.1)
	for _, fp in ipairs({ { -14, -6 }, { 14, -6 } }) do
		flag(f, at(fp[1], fp[2]), P.orange)
	end
	crates(f, at(26, 6))
	barrels(f, at(-28, 6))
	-- a little boat dock for the beach
	World.box(f, CF(O + V3(-104, -0.3, -40)), V3(16, 0.6, 5), P.white, { Name = "Dock" })
	for _, x in ipairs({ -110, -98 }) do
		World.cyl(f, O + V3(x, -2, -42.6), 2.4, 0.8, P.navy, { Name = "DockPost" })
	end
end

local function moonDecor(f: Folder, O: Vector3, pl: Config.Planet, rng: Random)
	local inner, rim = pl.groundDark, pl.groundLight
	for _, c in ipairs({ { -70, 0, 16 }, { 60, 90, 20 }, { -40, 130, 14 }, { 130, -70, 18 }, { -130, -20, 22 }, { 20, -130, 12 }, { 140, 40, 15 }, { -140, 60, 18 } }) do
		crater(f, O + V3(c[1], 0, c[2]), c[3], inner, rim, rng)
	end
	for _, r in ipairs({ { -88, -30 }, { 66, -60 }, { 56, 110 }, { -60, 120 }, { 100, 40 }, { -24, -116 } }) do
		World.rocks(f, O + V3(r[1], 0, r[2]), { rock = pl.groundLight, rockDark = pl.groundDark }, rng, 1.3)
	end
	dome(f, O + V3(-74, 0, -96), 18, P.white, P.navy)
	dome(f, O + V3(-96, 0, -70), 12, P.white, P.orange)
	World.rod(f, O + V3(-66, 2, -88), O + V3(-90, 2, -72), 3, P.padLight)
	for k = 0, 2 do
		solar(f, O + V3(70 + k * 12, 0, 70), RAD(-20))
	end
	rover(f, O + V3(40, 0, -100), RAD(30), P.white)
	flag(f, O + V3(-16, 0, -40), P.orange)
	flag(f, O + V3(16, 0, -40), P.sky)
	dish(f, O + V3(-70, 0, 30), RAD(160), 1.1)
	skyBall(f, O + V3(-380, 230, 620), 150, Color3.fromRGB(70, 150, 255), {
		{ V3(-0.6, 0.3, -1), 50, Color3.fromRGB(110, 200, 100) },
		{ V3(0.2, -0.4, -1), 40, Color3.fromRGB(110, 200, 100) },
		{ V3(0.5, 0.6, -1), 34, Color3.new(1, 1, 1) },
	})
end

local function marsDecor(f: Folder, O: Vector3, pl: Config.Planet, rng: Random)
	local c1, c2 = Color3.fromRGB(196, 92, 60), Color3.fromRGB(226, 128, 84)
	for _, m in ipairs({ { -150, 60, 34, 46 }, { 160, 20, 40, 60 }, { -120, -140, 26, 34 }, { 90, 160, 30, 40 }, { -60, 180, 22, 30 }, { 170, -130, 28, 38 } }) do
		mesa(f, O + V3(m[1], 0, m[2]), m[3], m[4], c1, c2)
	end
	for _, r in ipairs({ { -88, -30 }, { 66, -60 }, { 56, 110 }, { -60, 120 }, { 100, 40 }, { -24, -116 }, { 120, -20 }, { -100, 20 } }) do
		World.rocks(f, O + V3(r[1], 0, r[2]), { rock = pl.groundLight, rockDark = pl.groundDark }, rng, 1.4)
	end
	for _, c in ipairs({ { -70, 10, 12 }, { 110, 90, 14 }, { 30, -140, 10 } }) do
		crater(f, O + V3(c[1], 0, c[2]), c[3], pl.groundDark, pl.groundLight, rng)
	end
	dome(f, O + V3(-74, 0, -96), 18, P.white, P.orange)
	dome(f, O + V3(-98, 0, -74), 12, P.white, P.navy)
	for k = 0, 2 do
		solar(f, O + V3(66 + k * 12, 0, 72), RAD(-30))
	end
	rover(f, O + V3(36, 0, -104), RAD(-20), P.white)
	flag(f, O + V3(-16, 0, -40), P.orange)
	flag(f, O + V3(16, 0, -40), P.sky)
	skyBall(f, O + V3(-300, 260, 520), 46, Color3.fromRGB(150, 130, 120), nil)
	skyBall(f, O + V3(260, 200, 600), 28, Color3.fromRGB(170, 150, 140), nil)
end

local function europaDecor(f: Folder, O: Vector3, pl: Config.Planet, rng: Random)
	for _, s in ipairs({ { -80, -20 }, { 70, -64 }, { 60, 110 }, { -64, 120 }, { 110, 46 }, { -30, -120 }, { 130, -20 }, { -120, 40 }, { -110, -110 }, { 20, 150 } }) do
		iceSpikes(f, O + V3(s[1], 0, s[2]), rng, 1.3)
	end
	-- glowing cracks in the ice
	for k = 1, 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(70, 200)
		local p = O + V3(math.cos(a) * r, 0.05, math.sin(a) * r)
		local crack = World.box(f, CF(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), V3(rng:NextNumber(14, 30), 0.12, 0.8), Color3.fromRGB(80, 230, 255), { Name = "IceCrack", CanCollide = false })
		crack.Material = Enum.Material.Neon
	end
	dome(f, O + V3(-74, 0, -96), 18, P.white, P.sky)
	dome(f, O + V3(-98, 0, -74), 12, P.white, P.navy)
	for k = 0, 2 do
		solar(f, O + V3(66 + k * 12, 0, 72), RAD(-30))
	end
	rover(f, O + V3(36, 0, -104), RAD(10), Color3.fromRGB(220, 240, 255))
	flag(f, O + V3(-16, 0, -40), P.orange)
	flag(f, O + V3(16, 0, -40), P.sky)
	-- Jupiter: banded giant in the sky
	local jc = O + V3(-520, 330, 800)
	local jd = 420
	decor(World.ball(f, jc, jd, Color3.fromRGB(232, 196, 150), { Name = "Jupiter" }))
	for k, band in ipairs({ { -0.3, Color3.fromRGB(200, 140, 96) }, { 0.05, Color3.fromRGB(246, 222, 186) }, { 0.28, Color3.fromRGB(190, 120, 80) }, { -0.55, Color3.fromRGB(214, 166, 120) } }) do
		local y = band[1] :: number
		local col = band[2] :: Color3
		local r = math.sqrt(math.max(0, 1 - y * y)) * jd / 2
		decor(World.part({
			Name = "JupiterBand" .. k,
			Shape = Enum.PartType.Cylinder,
			Size = V3(jd * 0.07, r * 2 + 1.5, r * 2 + 1.5),
			CFrame = CF(jc + V3(0, y * jd / 2, 0)) * CFrame.Angles(0, 0, RAD(90)),
			Color = col,
			Parent = f,
		}))
	end
	decor(World.ball(f, jc + V3(jd * 0.22, -jd * 0.14, -jd * 0.42), jd * 0.12, Color3.fromRGB(214, 110, 80), { Name = "GreatRedSpot" }))
end

-- Area ---------------------------------------------------------------------------------------------------

local function finish(f: Folder)
	for _, d in ipairs(f:GetDescendants()) do
		if d:IsA("BasePart") then
			local bp = d :: BasePart
			bp.CanTouch = false
			if not bp.CanCollide then
				bp.CanQuery = false
			end
			if bp.Size.Magnitude < 2.6 then
				bp.CastShadow = false
			end
		end
	end
end

local function progressBillboard(f: Folder, c: Vector3, area: { [string]: any })
	local anchor = World.box(f, CF(c + V3(0, 2, 0)), V3(1, 1, 1), P.white, { Name = "ProgressAnchor", Transparency = 1, CanCollide = false })
	local bb = Instance.new("BillboardGui")
	bb.Name = "Progress"
	bb.Size = UDim2.fromScale(44, 11)
	bb.StudsOffsetWorldSpace = V3(0, 80, 0)
	bb.MaxDistance = 2500
	bb.LightInfluence = 0
	bb.Adornee = anchor
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 0.55)
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Text = "🚀 ROCKET 0/0"
	local st = Instance.new("UIStroke")
	st.Thickness = 4
	st.Color = P.navy
	st.Parent = t
	t.Parent = bb
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = P.navy
	bar.Position = UDim2.fromScale(0.08, 0.6)
	bar.Size = UDim2.fromScale(0.84, 0.32)
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0.5, 0)
	bc.Parent = bar
	local bs = Instance.new("UIStroke")
	bs.Thickness = 3
	bs.Color = Color3.new(1, 1, 1)
	bs.Parent = bar
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = P.orange
	fill.Size = UDim2.fromScale(0, 1)
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0.5, 0)
	fc.Parent = fill
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(P.gold, P.orange)
	g.Rotation = 90
	g.Parent = fill
	fill.Parent = bar
	bar.Parent = bb
	bb.Parent = anchor
	area.progressGui = bb
	area.progressText = t
	area.progressFill = fill
end

function Map.build(i: number): Area
	local pl = Config.planet(i)
	local O = pl.origin
	local f = World.folder("Planet_" .. pl.key, workspace)
	local rng = Random.new(1000 + i * 77)
	local maxLayout = Parts.layout(i, 3)
	local boltR = math.max(Config.Tune.boltRadius, math.ceil(maxLayout.radius + 7))
	local padR = boltR + 9
	local area: { [string]: any } = { index = i, origin = O, folder = f, padRadius = padR, boltRadius = boltR }

	if i == 1 then
		earthGround(f, O)
	else
		planetGround(f, O, pl)
	end
	local spawn, spawnCF = buildSpawn(f, O, i)
	area.spawn = spawn
	area.spawnCF = spawnCF
	buildPad(f, O, padR, boltR, area)
	area.rocketBase = CF(O + PAD + V3(0, PAD_TOP, 0))
	buildTower(f, O, padR, maxLayout.height, pl.scale)
	buildDepot(f, O, area)
	buildBoard(f, O, area)
	buildKiosk(f, O + Config.Layout.gearKiosk, O + SPAWN, "🧤 GEAR SHOP", "Gear", P.orange)
	buildKiosk(f, O + Config.Layout.shopKiosk, O + SPAWN + V3(0, 0, 4), "🛒 SHOP", "Shop", P.sky)
	buildLanding(f, O, area)
	paths(f, O, padR, i)
	area.ftuePad = O + Config.Layout.ftue
	World.pad(f, area.ftuePad, 4.2, P.gold)
	area.botHome = O + V3(30, 0, -20)
	area.playRadius = i == 1 and 125 or 230
	if i == 1 then
		earthDecor(f, O, rng)
	elseif i == 2 then
		moonDecor(f, O, pl, rng)
	elseif i == 3 then
		marsDecor(f, O, pl, rng)
	else
		europaDecor(f, O, pl, rng)
	end
	progressBillboard(f, O + PAD, area)
	finish(f)
	return (area :: any) :: Area
end

function Map.buildAll(): { Area }
	for i = 1, #Config.Planets do
		Map.areas[i] = Map.build(i)
		task.wait()
	end
	return Map.areas
end

return Map

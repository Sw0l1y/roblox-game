-- The clip moment, drawn on every client from the server's phase clock (RocketState Phase/PhaseT):
-- boarding call, the big 10-second countdown with an orbiting camera and building smoke, liftoff (the rocket
-- and its riders fly up locally with fire plumes, ground smoke, cloud layers, camera shake and a darkening
-- sky; chase camera, VIP window-seat view, MVP nose view), the white warp, and the lander touching down on
-- the next planet. Also the supply-drop pod that falls from the sky.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ClientLib = ReplicatedStorage:WaitForChild("ClientLib")
local UI = require(ClientLib:WaitForChild("UI"))
local Sfx = require(ClientLib:WaitForChild("Sfx"))
local Fx = require(ClientLib:WaitForChild("Fx"))
local Hub = require(ClientLib:WaitForChild("Hub"))

local Cinema = {}

local T = Config.Tune
local P = Config.Palette
local player = Hub.player
local camera = workspace.CurrentCamera
local rng = Random.new()
local RAD90 = math.rad(90)

local folder = Instance.new("Folder")
folder.Name = "Cinema"
folder.Parent = workspace

local function part(props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	if not p.Parent then
		p.Parent = folder
	end
	return p
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	for k, v in pairs(props) do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

-- Screen overlays (on the ScreenGui itself so they stay visible while the HUD root is hidden) ------------------

local bigNumber = UI.text(UI.gui, "", {
	Name = "Countdown",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.fromScale(0.5, 0.26),
	ZIndex = 62,
	Visible = false,
})
local bigStroke = bigNumber:FindFirstChildOfClass("UIStroke")
if bigStroke then
	bigStroke.Thickness = 6
end

local topLine = UI.text(UI.gui, "", {
	Name = "LaunchLine",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 120),
	Size = UDim2.fromOffset(620, 48),
	TextColor3 = UI.colors.gold,
	ZIndex = 61,
	Visible = false,
})

local warpOverlay = UI.frame(UI.gui, {
	Name = "Warp",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 70,
})
local warpText = UI.text(warpOverlay, "", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.45),
	Size = UDim2.fromScale(0.7, 0.12),
	TextColor3 = UI.colors.sky,
	ZIndex = 71,
})
local warpSub = UI.text(warpOverlay, "", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.56),
	Size = UDim2.fromScale(0.6, 0.06),
	TextColor3 = UI.INK,
	ZIndex = 71,
})
local warpSubStroke = warpSub:FindFirstChildOfClass("UIStroke")
if warpSubStroke then
	warpSubStroke.Enabled = false
end

-- Cinematic mode ----------------------------------------------------------------------------------------------

local inCinema = false
local hidden = false
local cc: ColorCorrectionEffect? = nil
local lastCam: CFrame? = nil

local function setCharactersHidden(on: boolean)
	if hidden == on then
		return
	end
	hidden = on
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		if c then
			for _, d in ipairs(c:GetDescendants()) do
				if d:IsA("BasePart") then
					(d :: BasePart).LocalTransparencyModifier = on and 1 or 0
				elseif d:IsA("Decal") then
					(d :: Decal).LocalTransparencyModifier = on and 1 or 0
				end
			end
		end
	end
end

local function enter()
	if inCinema then
		return
	end
	inCinema = true
	Hub.cinematic = true
	UI.closeAll()
	UI.root.Visible = false
	camera.CameraType = Enum.CameraType.Scriptable
	lastCam = camera.CFrame
end

local function exit()
	setCharactersHidden(false)
	if not inCinema then
		return
	end
	inCinema = false
	Hub.cinematic = false
	UI.root.Visible = true
	camera.CameraType = Enum.CameraType.Custom
	local hum = Hub.humanoid()
	if hum then
		camera.CameraSubject = hum
	end
	camera.FieldOfView = 70
	if cc then
		local c = cc
		cc = nil
		UI.tween(c, 0.8, { Brightness = 0, TintColor = Color3.new(1, 1, 1), Saturation = 0 })
		Debris:AddItem(c, 0.9)
	end
	lastCam = nil
end

local function setCam(target: CFrame, dt: number, rate: number?)
	local from = lastCam or target
	local k = rate and (1 - math.exp(-dt * rate)) or 1
	local cf = from:Lerp(target, k)
	lastCam = cf
	camera.CFrame = cf
end

-- Rocket geometry from the replicated attributes ------------------------------------------------------------

local function baseCF(): CFrame
	local v = Hub.attr("BaseCF")
	if typeof(v) == "CFrame" then
		return v
	end
	return CFrame.new(Hub.padCenter() + Vector3.new(0, Config.Layout.padTop, 0))
end

local function rocketModel(): Model?
	local m = workspace:FindFirstChild("Rocket")
	if m and m:IsA("Model") then
		return m :: Model
	end
	return nil
end

-- Smoke billows around the pad ---------------------------------------------------------------------------------

local puffCount = 0
local function puff(center: Vector3, spread: number, size: number)
	if puffCount > 90 then
		return
	end
	puffCount += 1
	local a = rng:NextNumber(0, math.pi * 2)
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local start = center + dir * spread * rng:NextNumber(0.3, 0.7) + Vector3.new(0, rng:NextNumber(0, 2), 0)
	local s = size * rng:NextNumber(0.6, 1.1)
	local grey = rng:NextNumber(0.82, 1)
	local p = part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(s, s, s),
		CFrame = CFrame.new(start),
		Color = Color3.new(grey, grey, grey * 1.02),
		Transparency = 0.1,
	})
	local life = rng:NextNumber(2.4, 3.6)
	local grow = s * rng:NextNumber(2.2, 3.2)
	UI.tween(p, life, {
		Size = Vector3.new(grow, grow, grow),
		Position = start + dir * spread * rng:NextNumber(1.2, 2) + Vector3.new(0, rng:NextNumber(4, 14), 0),
		Transparency = 1,
	}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(life, function()
		p:Destroy()
		puffCount -= 1
	end)
end

-- Flight state -------------------------------------------------------------------------------------------------

type Plume = { off: CFrame, d: number, outer: BasePart, core: BasePart, glow: BasePart, holder: BasePart }
type Flight = {
	base: CFrame,
	model: Model?,
	height: number,
	scale: number,
	plumes: { Plume },
	extras: { Instance },
	planet: number,
	started: boolean,
	lastRumble: number,
	seatView: boolean,
}
local flight: Flight? = nil

local function buildPlumes(f: Flight)
	local m = f.model
	if not m then
		return
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("Role") == "fire" then
			local fp = d :: BasePart
			local dia = math.max(fp.Size.Y, fp.Size.Z)
			local outer = part({ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = P.orange, Transparency = 0.25 })
			local core = part({ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 240, 170), Transparency = 0.05 })
			local glow = part({ Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 200, 80), Transparency = 0.2, Size = Vector3.new(dia * 1.05, dia * 1.05, dia * 1.05) })
			local holder = part({ Size = Vector3.new(1, 1, 1), Transparency = 1 })
			local att = Instance.new("Attachment")
			att.Orientation = Vector3.new(0, 0, 180) -- emit downward
			att.Parent = holder
			emitter(att, {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 200)),
					ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 160, 40)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 110, 110)),
				}),
				LightEmission = 0.8,
				Rate = 70,
				Lifetime = NumberRange.new(0.4, 0.8),
				Speed = NumberRange.new(30, 55),
				SpreadAngle = Vector2.new(12, 12),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, dia * 0.5), NumberSequenceKeypoint.new(1, dia * 1.4) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
				EmissionDirection = Enum.NormalId.Top,
			})
			emitter(att, {
				Color = ColorSequence.new(Color3.fromRGB(240, 240, 240), Color3.fromRGB(170, 170, 176)),
				LightEmission = 0,
				Rate = 26,
				Lifetime = NumberRange.new(1.8, 2.8),
				Speed = NumberRange.new(12, 22),
				SpreadAngle = Vector2.new(25, 25),
				Drag = 1.2,
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, dia * 0.9), NumberSequenceKeypoint.new(1, dia * 3) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) }),
				EmissionDirection = Enum.NormalId.Top,
			})
			local light = Instance.new("PointLight")
			light.Color = P.orange
			light.Range = 40
			light.Brightness = 3
			light.Parent = glow
			table.insert(f.plumes, { off = f.base:ToObjectSpace(fp.CFrame), d = dia, outer = outer, core = core, glow = glow, holder = holder })
			table.insert(f.extras, outer)
			table.insert(f.extras, core)
			table.insert(f.extras, glow)
			table.insert(f.extras, holder)
		end
	end
end

local function buildClouds(f: Flight)
	local center = f.base.Position
	for i = 1, 16 do
		local y = 150 + (i - 1) * 55 + rng:NextNumber(-20, 20)
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(26, 90) * f.scale
		local c = center + Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
		local planet = Config.planet(f.planet)
		local col = planet.key == "Mars" and Color3.fromRGB(255, 214, 190) or Color3.fromRGB(255, 255, 255)
		for k = 1, 3 do
			local s = rng:NextNumber(14, 26)
			local p = part({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(s, s * 0.7, s),
				Color = col,
				Transparency = 0.12,
				CFrame = CFrame.new(c + Vector3.new((k - 2) * s * 0.7, rng:NextNumber(-2, 2), rng:NextNumber(-4, 4))),
			})
			table.insert(f.extras, p)
		end
	end
end

local function clearFlight()
	local f = flight
	flight = nil
	if f then
		for _, e in ipairs(f.extras) do
			e:Destroy()
		end
	end
end

local function startFlight(): Flight
	clearFlight()
	local m = rocketModel()
	local f: Flight = {
		base = baseCF(),
		model = m,
		height = Hub.num("Height", 55),
		scale = Hub.num("Scale", 1),
		plumes = {},
		extras = {},
		planet = Hub.planet(),
		started = false,
		lastRumble = 0,
		seatView = false,
	}
	buildPlumes(f)
	buildClouds(f)
	flight = f
	return f
end

-- Riders sit at their seat attribute relative to the (locally moving) rocket. Their root parts are anchored
-- by the server, so moving the root moves the whole character (Motor6Ds follow).
local function placeRiders(rocketCF: CFrame)
	for _, p in ipairs(Players:GetPlayers()) do
		local seat = p:GetAttribute("SeatCF")
		local c = p.Character
		if c and typeof(seat) == "CFrame" then
			local r = c:FindFirstChild("HumanoidRootPart")
			if r and r:IsA("BasePart") then
				(r :: BasePart).CFrame = rocketCF * seat * CFrame.new(0, 3.2, 0)
			end
		end
	end
end

local function updateFlight(f: Flight, t: number, dt: number)
	local h = Config.flightHeight(t)
	local sway = CFrame.Angles(math.sin(t * 1.7) * 0.006, 0, math.sin(t * 1.3) * 0.01)
	local rocketCF = (f.base + Vector3.new(0, h, 0)) * sway
	local m = f.model
	if m and m.Parent then
		m:PivotTo(rocketCF)
	end
	placeRiders(rocketCF)
	-- plumes: longer and brighter as the engines throttle up
	local throttle = math.clamp(t / 1.2, 0.35, 1)
	local flick = 1 + math.sin(os.clock() * 31) * 0.08 + math.sin(os.clock() * 17) * 0.06
	for _, pl in ipairs(f.plumes) do
		local top = (rocketCF * pl.off).Position
		local len = pl.d * (1.6 + 2.4 * throttle) * flick
		pl.outer.Size = Vector3.new(len, pl.d * 0.95, pl.d * 0.95)
		pl.outer.CFrame = CFrame.new(top - Vector3.new(0, len / 2, 0)) * CFrame.Angles(0, 0, RAD90)
		local coreLen = len * 0.62
		pl.core.Size = Vector3.new(coreLen, pl.d * 0.55, pl.d * 0.55)
		pl.core.CFrame = CFrame.new(top - Vector3.new(0, coreLen / 2, 0)) * CFrame.Angles(0, 0, RAD90)
		pl.glow.CFrame = CFrame.new(top - Vector3.new(0, pl.d * 0.2, 0))
		pl.holder.CFrame = CFrame.new(top - Vector3.new(0, len * 0.9, 0))
	end
	-- ground smoke for the first seconds
	if t < 5 then
		local pad = f.base.Position
		for _ = 1, 2 do
			puff(pad, 26 * f.scale, 9 * f.scale)
		end
	end
	-- rumble + shake
	local shakeAmp = t < 3 and 0.55 or math.max(0.12, 0.55 - (t - 3) * 0.08)
	UI.shake(dt * 12 * shakeAmp)
	if t < 5 and os.clock() - f.lastRumble > 0.32 then
		f.lastRumble = os.clock()
		Sfx.play("thud", 0.45 * (1 - t / 6), 0.55 + rng:NextNumber(-0.05, 0.05))
	end
	-- the sky darkens into space
	local k = math.clamp(h / 750, 0, 1)
	local c = cc
	if c then
		c.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(150, 165, 255), k)
		c.Brightness = -0.16 * k
		c.Saturation = 0.15 * k
		c.Contrast = 0.12 * k
	end
	camera.FieldOfView = 70 + 14 * math.clamp(t / 6, 0, 1)

	-- camera
	local rocketPos = rocketCF.Position
	local kind = player:GetAttribute("SeatKind")
	local seat = player:GetAttribute("SeatCF")
	if t < 2.6 then
		-- ground camera on the spawn side, looking up at the liftoff
		local pos = f.base.Position + Vector3.new(-48 * f.scale, 5, -78 * f.scale)
		local look = rocketPos + Vector3.new(0, f.height * 0.45, 0)
		setCam(CFrame.lookAt(pos, look), dt, nil)
	elseif kind == "vip" and typeof(seat) == "CFrame" and t >= 4.2 then
		if not f.seatView then
			f.seatView = true
			UI.banner("👑 VIP WINDOW SEAT VIEW", "gold", 2.2)
			Sfx.play("sparkle", 0.6)
		end
		local s = rocketCF * seat
		local pos = (s * CFrame.new(0, 4.6, 2.4)).Position
		setCam(CFrame.lookAt(pos, pos + s.LookVector * 10 + Vector3.new(0, -8, 0)), dt, 8)
	elseif kind == "mvp" and t >= 4.2 then
		if not f.seatView then
			f.seatView = true
			UI.banner("🥇 MVP RIDE: ON THE NOSE!", "gold", 2.2)
			Sfx.play("sparkle", 0.6)
		end
		local pos = rocketPos + Vector3.new(0, f.height + 16 * f.scale, 12 * f.scale)
		setCam(CFrame.lookAt(pos, rocketPos + Vector3.new(0, f.height * 0.5, 0)), dt, 8)
	else
		local a = math.rad(200) + t * 0.16
		local r = 64 * f.scale
		local pos = rocketPos + Vector3.new(math.sin(a) * r, f.height * 0.95, math.cos(a) * r)
		setCam(CFrame.lookAt(pos, rocketPos + Vector3.new(0, f.height * 0.4, 0)), dt, 5)
	end
end

-- Lander (arrival on the next planet) --------------------------------------------------------------------------

local lander: Model? = nil
local landerFlame: BasePart? = nil
local landed = false
local LAND_TIME = 2.4

local function buildLander(): Model
	local m = Instance.new("Model")
	m.Name = "Lander"
	local function add(props: { [string]: any }): BasePart
		local p = part(props)
		p.Parent = m
		return p
	end
	local s = 1.6
	-- local frame: origin = feet centre, built at the world origin then pivoted
	add({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(7 * s, 9 * s, 9 * s), CFrame = CFrame.new(0, 4.5 * s, 0) * CFrame.Angles(0, 0, RAD90), Color = P.white })
	add({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1 * s, 9.3 * s, 9.3 * s), CFrame = CFrame.new(0, 3 * s, 0) * CFrame.Angles(0, 0, RAD90), Color = P.orange })
	add({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1 * s, 9.3 * s, 9.3 * s), CFrame = CFrame.new(0, 6.4 * s, 0) * CFrame.Angles(0, 0, RAD90), Color = P.orange })
	add({ Shape = Enum.PartType.Ball, Size = Vector3.new(9 * s, 9 * s, 9 * s), CFrame = CFrame.new(0, 8 * s, 0), Color = P.white })
	add({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4 * s, 3 * s, 3 * s), CFrame = CFrame.new(0, 12.6 * s, 0) * CFrame.Angles(0, 0, RAD90), Color = P.navy })
	add({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.4 * s, 1.4 * s, 1.4 * s), CFrame = CFrame.new(0, 13.8 * s, 0), Color = P.gold, Material = Enum.Material.Neon })
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + math.pi / 4
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local top = Vector3.new(0, 3 * s, 0) + dir * 4 * s
		local foot = Vector3.new(0, 0.3, 0) + dir * 7 * s
		local mid = (top + foot) / 2
		add({ Size = Vector3.new(0.7 * s, (top - foot).Magnitude, 0.7 * s), CFrame = CFrame.lookAt(mid, foot) * CFrame.Angles(RAD90, 0, 0), Color = P.navy })
		add({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 2.4 * s, 2.4 * s), CFrame = CFrame.new(foot) * CFrame.Angles(0, 0, RAD90), Color = P.pad })
		local wpos = Vector3.new(0, 5.2 * s, 0) + dir * 4.45 * s
		add({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.8 * s, 1.8 * s, 1.8 * s), CFrame = CFrame.new(wpos), Color = P.glow, Material = Enum.Material.Neon })
	end
	add({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4 * s, 4.6 * s, 4.6 * s), CFrame = CFrame.new(0, 0.7 * s, 0) * CFrame.Angles(0, 0, RAD90), Color = P.padDark })
	landerFlame = add({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(8, 3.6 * s, 3.6 * s), Color = P.orange, Material = Enum.Material.Neon, Transparency = 0.2 })
	m.WorldPivot = CFrame.new()
	m.Parent = folder
	return m
end

local function landingPoint(): Vector3
	local v = Hub.attr("Landing")
	if typeof(v) == "Vector3" then
		return v
	end
	return Hub.origin() + Config.Layout.landing
end

local function updateArrive(t: number, dt: number)
	local land = landingPoint()
	if not lander then
		lander = buildLander()
		landed = false
	end
	local m = lander :: Model
	local k = math.clamp(t / LAND_TIME, 0, 1)
	local e = 1 - (1 - k) ^ 3
	local y = (1 - e) * 170
	local spin = (1 - e) * 2.4
	m:PivotTo(CFrame.new(land + Vector3.new(0, y, 0)) * CFrame.Angles(0, spin, 0))
	local fl = landerFlame
	if fl then
		local len = k < 1 and (6 + math.sin(os.clock() * 30) * 1.2 + (1 - k) * 6) or 0.1
		fl.Size = Vector3.new(len, fl.Size.Y, fl.Size.Z)
		fl.CFrame = CFrame.new(land + Vector3.new(0, y - len / 2 + 0.2, 0)) * CFrame.Angles(0, 0, RAD90)
		fl.Transparency = k < 1 and 0.2 or 1
	end
	if k < 1 then
		setCharactersHidden(true)
		if k > 0.6 then
			puff(land, 18, 6)
		end
	elseif not landed then
		landed = true
		setCharactersHidden(false)
		Fx.shockwave(land + Vector3.new(0, 0.8, 0), Hub.planetInfo().accent, 34)
		Fx.burst(land + Vector3.new(0, 2, 0), { Hub.planetInfo().ground, P.white }, 22, 1.5)
		for _ = 1, 10 do
			puff(land, 20, 7)
		end
		UI.shake(0.9)
		Sfx.play("thud", 0.9, 0.8)
		Sfx.play("cheer", 0.5, 1, 3)
	end
	-- camera: watch the descent from the side, then swing behind your character facing the new rocket
	if t < LAND_TIME + 0.4 then
		local pos = land + Vector3.new(36, 14, -44)
		setCam(CFrame.lookAt(pos, land + Vector3.new(0, y + 6, 0)), dt, nil)
	else
		local r = Hub.root()
		local pad = Hub.padCenter()
		if r then
			local flat = Vector3.new(pad.X - r.Position.X, 0, pad.Z - r.Position.Z)
			local dir = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, 1)
			local pos = r.Position - dir * 18 + Vector3.new(0, 8, 0)
			setCam(CFrame.lookAt(pos, pad + Vector3.new(0, 24, 0)), dt, 4)
		end
	end
end

local function clearLander()
	local m = lander
	lander = nil
	landerFlame = nil
	if m then
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				UI.tween(d, 1, { Transparency = 1 })
			end
		end
		Debris:AddItem(m, 1.1)
	end
end

-- Phase handling ------------------------------------------------------------------------------------------------

local lastNumber = -1
local lastPhase = ""

local function onPhase(phase: string)
	if phase == lastPhase then
		return
	end
	local prev = lastPhase
	lastPhase = phase
	lastNumber = -1
	bigNumber.Visible = false
	if phase == "boarding" then
		topLine.Visible = true
		Sfx.play("reveal", 0.6)
		UI.confetti(40)
	elseif phase == "countdown" then
		topLine.Visible = false
		enter()
		if not cc then
			local c = Instance.new("ColorCorrectionEffect")
			c.Name = "SpaceTint"
			c.Parent = camera
			cc = c
		end
	elseif phase == "flight" then
		topLine.Visible = false
		enter()
		local f = startFlight()
		f.started = true
		bigNumber.Visible = true
		bigNumber.Text = "LIFTOFF!"
		bigNumber.TextColor3 = UI.colors.orange
		UI.punch(bigNumber, 0.9)
		task.delay(1.6, function()
			if lastPhase == "flight" then
				bigNumber.Visible = false
			end
		end)
		Sfx.play("reveal", 0.8, 0.7)
		Sfx.play("cheer", 0.55, 1, 5)
		UI.flash("orange", 0.5)
		Fx.shockwave(f.base.Position + Vector3.new(0, 1, 0), Color3.new(1, 1, 1), 70 * f.scale)
	elseif phase == "warp" then
		enter()
		local f = flight
		local from = f and f.planet or Hub.planet()
		local to = Config.planet(from % #Config.Planets + 1)
		warpText.Text = string.format("%s NEXT STOP: %s!", to.icon, to.name)
		warpSub.Text = to.blurb
		warpOverlay.Visible = true
		warpOverlay.BackgroundTransparency = 1
		warpText.TextTransparency = 1
		UI.tween(warpOverlay, 0.35, { BackgroundTransparency = 0 })
		UI.tween(warpText, 0.5, { TextTransparency = 0 })
		UI.punch(warpText, 0.6)
		Sfx.play("whoosh", 0.8, 1.3)
		Sfx.play("magic", 0.6)
		task.delay(0.4, clearFlight)
	elseif phase == "arrive" then
		enter()
		clearFlight()
		if cc then
			local c = cc
			c.TintColor = Color3.new(1, 1, 1)
			c.Brightness = 0
			c.Saturation = 0
			c.Contrast = 0
		end
		camera.FieldOfView = 70
		setCharactersHidden(true)
		UI.tween(warpOverlay, 0.6, { BackgroundTransparency = 1 })
		UI.tween(warpText, 0.4, { TextTransparency = 1 })
		task.delay(0.65, function()
			if lastPhase ~= "warp" then
				warpOverlay.Visible = false
			end
		end)
		Sfx.play("whoosh", 0.6, 0.8)
	elseif phase == "build" then
		topLine.Visible = false
		warpOverlay.Visible = false
		clearFlight()
		clearLander()
		exit()
		if prev == "arrive" then
			UI.confetti(70)
		end
	end
end

local function step(dt: number)
	local phase = Hub.phase()
	if phase ~= lastPhase then
		onPhase(phase)
	end
	local t = Hub.phaseT()
	if phase == "boarding" then
		local left = math.max(0, math.ceil(T.boardTime + T.countdown - t))
		topLine.Text = string.format("🚀 ALL ABOARD! LIFTOFF IN %d", left)
	elseif phase == "countdown" then
		local n = math.max(1, math.ceil(T.countdown - t))
		if n ~= lastNumber then
			lastNumber = n
			bigNumber.Visible = true
			bigNumber.Text = tostring(n)
			bigNumber.TextColor3 = n <= 3 and UI.colors.orange or Color3.new(1, 1, 1)
			UI.punch(bigNumber, n <= 3 and 0.8 or 0.45)
			Sfx.play("beep", 0.6, n <= 3 and 1.25 or 1)
			if n <= 3 then
				UI.shake(0.25)
			end
		end
		-- orbit the rocket, closing in for the last seconds
		local base = baseCF()
		local height = Hub.num("Height", 55)
		local scale = Hub.num("Scale", 1)
		local k = math.clamp(t / T.countdown, 0, 1)
		local a = math.rad(160) + t * 0.13
		local r = (92 - 30 * k) * scale
		local center = base.Position + Vector3.new(0, height * (0.55 - 0.25 * k), 0)
		local pos = center + Vector3.new(math.sin(a) * r, height * 0.12 + 6, math.cos(a) * r)
		setCam(CFrame.lookAt(pos, center), dt, 4)
		placeRiders(base)
		if t > T.countdown - 4 then
			puff(base.Position, 22 * scale, 7 * scale)
			UI.shake(dt * 12 * 0.12 * (t - (T.countdown - 4)))
		end
	elseif phase == "flight" then
		local f: Flight = flight or startFlight()
		if not cc then
			local c = Instance.new("ColorCorrectionEffect")
			c.Name = "SpaceTint"
			c.Parent = camera
			cc = c
		end
		updateFlight(f, t, dt)
	elseif phase == "warp" then
		local f = flight
		if f then
			updateFlight(f, T.flightTime + t, dt)
		end
	elseif phase == "arrive" then
		updateArrive(t, dt)
	end
end

-- Supply drop pod -----------------------------------------------------------------------------------------------

local function podModel(): Model
	local m = Instance.new("Model")
	m.Name = "FallingPod"
	local function add(props: { [string]: any }): BasePart
		local p = part(props)
		p.Parent = m
		return p
	end
	add({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(7, 7, 7), CFrame = CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, RAD90), Color = P.white })
	add({ Shape = Enum.PartType.Ball, Size = Vector3.new(7, 7, 7), CFrame = CFrame.new(0, 8.6, 0), Color = P.white })
	add({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 7.3, 7.3), CFrame = CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, RAD90), Color = P.orange })
	add({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 7.3, 7.3), CFrame = CFrame.new(0, 6.2, 0) * CFrame.Angles(0, 0, RAD90), Color = P.orange })
	add({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = CFrame.new(0, 13, 0), Color = P.gold, Material = Enum.Material.Neon })
	local flame = add({ Shape = Enum.PartType.Ball, Size = Vector3.new(6, 6, 6), CFrame = CFrame.new(0, 0.5, 0), Color = P.orange, Material = Enum.Material.Neon, Transparency = 0.25 })
	local att = Instance.new("Attachment")
	att.Parent = flame
	emitter(att, {
		Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(150, 140, 140)),
		LightEmission = 0.7,
		Rate = 40,
		Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(2, 6),
		SpreadAngle = Vector2.new(40, 40),
		Size = NumberSequence.new(3, 7),
		Transparency = NumberSequence.new(0.2, 1),
	})
	m.WorldPivot = CFrame.new()
	m.Parent = folder
	return m
end

local function supplyDrop(p: any)
	if type(p) ~= "table" or typeof(p.pos) ~= "Vector3" then
		return
	end
	local pos: Vector3 = p.pos
	local impact = tonumber(p.t) or (Hub.now() + 2.6)
	local dur = math.max(0.4, impact - Hub.now())
	local ring = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 22, 22),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, 0, RAD90),
		Color = P.gold,
		Material = Enum.Material.Neon,
		Transparency = 0.3,
	})
	local pod = podModel()
	local from = pos + Vector3.new(70, 360, -50)
	local t0 = os.clock()
	Sfx.play("whoosh", 0.5, 0.8)
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - t0) / dur, 0, 1)
		local at = from:Lerp(pos, k * k)
		pod:PivotTo(CFrame.lookAt(at, at + (pos - from).Unit) * CFrame.Angles(RAD90, 0, 0))
		local pulse = 20 + math.sin(os.clock() * 10) * 3
		ring.Size = Vector3.new(0.3, pulse, pulse)
		if k >= 1 then
			if conn then
				conn:Disconnect()
			end
			pod:Destroy()
			ring:Destroy()
			local r = Hub.root()
			if r and (r.Position - pos).Magnitude < 160 then
				UI.shake(0.7)
				Sfx.play("thud", 0.9, 0.7)
				Sfx.play("pop", 0.5, 0.7)
			end
		end
	end)
end

function Cinema.init()
	RunService:BindToRenderStep("RocketCinema", Enum.RenderPriority.Camera.Value, step)
	Hub.on("drop", supplyDrop)
	-- re-hide characters that respawn during the landing
	Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Connect(function()
			if hidden then
				hidden = false
				task.defer(setCharactersHidden, true)
			end
		end)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		p.CharacterAdded:Connect(function()
			if hidden then
				hidden = false
				task.defer(setCharactersHidden, true)
			end
		end)
	end
end

function Cinema.active(): boolean
	return inCinema
end

return Cinema

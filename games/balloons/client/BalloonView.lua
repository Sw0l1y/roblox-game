-- Client side of the balloons: builds every balloon the server spawns (BalloonArt, welded to an anchored root
-- so one CFrame write moves it), animates them (rise from the ground, bob, sway, face the camera, wobble when
-- hit, float away), throws darts on click/tap (aim assist, hold to keep throwing, run into small balloons to
-- bump-pop them), predicts pops for instant feedback (rolled back if the server disagrees), draws everyone
-- else's darts, rarity labels / HP bars / beacons, the pop aura ring, and all pop and reward effects.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local Fmt = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Fmt"))
local Tiers = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tiers"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Econ = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Econ"))
local BalloonArt = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalloonArt"))
local UI = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("UI"))
local Sfx = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("Sfx"))
local Fx = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("Fx"))
local State = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("State"))
local Hud = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("Hud"))
local MegaView = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("MegaView"))

local BalloonView = {}

type Def = Config.BalloonDef
type PData = { [string]: any }

type View = {
	id: number,
	key: string,
	def: Def,
	tier: number,
	model: Model,
	root: BasePart,
	base: Vector3,
	pos: Vector3,
	hp: number,
	maxHp: number,
	unacked: number,
	big: boolean,
	shower: boolean,
	fromMega: boolean,
	radius: number,
	born: number,
	phase: number,
	wobble: number,
	inflight: number,
	popped: boolean,
	predictedAt: number?,
	serverPopped: boolean,
	done: boolean,
	leavingAt: number?,
	lastBump: number,
	shown: boolean,
	label: BillboardGui?,
	hpFill: Frame?,
	hpText: TextLabel?,
	beacon: BasePart?,
}

type Dart = { model: Model, root: BasePart, style: number, trail: Trail }
type Flight = { dart: Dart, from: Vector3, t0: number, dur: number, arc: number, target: () -> Vector3, last: Vector3, arrive: (() -> ())? }
type Target = { id: number, view: View? }

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local P = Config.Palette
local rng = Random.new()

local AURA = 1
local RISE = 1.1
local SHOWER_T = 1.3
local HIDE_DIST = 460
local FAR_DIST = 170
local PICK_SLACK = 36

local views: { [number]: View } = {}
local gone: { [number]: boolean } = {}
local syncing = true
local folder: Folder
local dartFolder: Folder
local throwRemote = Net.event("Throw")
local dartRemote = Net.fast("Dart")
local nextThrow = 0
local frame = 0

-- input state
local holding = false
local holdTouch: InputObject? = nil
local holdMoved = false
local holdStart = Vector2.zero
local holdPos = Vector2.zero

-- arm swing (R15)
local swingMotor: Motor6D? = nil
local swingBase = CFrame.new()
local swingAt = -1

-- pop sound / coin fly budgets (aura can pop a lot at once)
local popSounds = 0
local flyBudget = 6

---------------------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------------------

local function hrp(): BasePart?
	local c = player.Character
	local h = c and c:FindFirstChild("HumanoidRootPart")
	if h and h:IsA("BasePart") then
		return h :: BasePart
	end
	return nil
end

local function handPos(): Vector3?
	local c = player.Character
	if not c then
		return nil
	end
	local h = c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm")
	if h and h:IsA("BasePart") then
		return (h :: BasePart).Position
	end
	local r = hrp()
	return r and (r.Position + Vector3.new(0, 1.5, 0)) or nil
end

local function myStyle(): number
	if player:GetAttribute("Golden") then
		return 2
	elseif player:GetAttribute("VIP") then
		return 1
	end
	return 0
end

local function easeOutBack(k: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (k - 1) ^ 3 + c1 * (k - 1) ^ 2
end

---------------------------------------------------------------------------------------------------------------
-- Labels and beacons
---------------------------------------------------------------------------------------------------------------

local function updateLabel(v: View)
	local fill, text = v.hpFill, v.hpText
	if fill and text then
		local hp = math.max(0, v.hp - v.unacked)
		fill.Size = UDim2.fromScale(math.clamp(hp / math.max(1, v.maxHp), 0, 1), 1)
		text.Text = Fmt.num(math.ceil(hp)) .. " / " .. Fmt.num(v.maxHp)
	end
end

local function makeLabel(v: View)
	local def = v.def
	local tier = Tiers.get(def.tier)
	local showName = v.tier >= Config.LabelTier or v.shower
	local showHp = (v.big and v.maxHp > 1) or v.maxHp >= 4
	if not showName and not showHp then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Adornee = v.root
	bb.Size = UDim2.fromOffset(190, (showName and 46 or 0) + (showHp and 22 or 0))
	bb.StudsOffsetWorldSpace = Vector3.new(0, def.size * 0.66 + 1.4, 0)
	bb.MaxDistance = v.tier >= Config.AnnounceSpawnTier and 240 or 95
	bb.AlwaysOnTop = v.tier >= Config.AnnounceSpawnTier
	bb.LightInfluence = 0
	local y = 0
	if showName then
		local tl = Instance.new("TextLabel")
		tl.BackgroundTransparency = 1
		tl.Size = UDim2.new(1, 0, 0, 24)
		tl.Font = Enum.Font.LuckiestGuy
		tl.TextScaled = true
		tl.TextColor3 = Color3.new(1, 1, 1)
		tl.Text = (v.shower and "🎁 BONUS " or "") .. string.upper(tier.name)
		if tier.rainbow then
			UI.rainbow(tl)
		else
			local g = Instance.new("UIGradient")
			g.Color = Tiers.gradient(def.tier)
			g.Rotation = 90
			g.Parent = tl
		end
		local s = Instance.new("UIStroke")
		s.Thickness = 2.5
		s.Color = P.ink
		s.Parent = tl
		tl.Parent = bb
		local nl = Instance.new("TextLabel")
		nl.BackgroundTransparency = 1
		nl.Position = UDim2.fromOffset(0, 24)
		nl.Size = UDim2.new(1, 0, 0, 20)
		nl.Font = Enum.Font.FredokaOne
		nl.TextScaled = true
		nl.TextColor3 = Color3.new(1, 1, 1)
		nl.Text = def.name
		local s2 = Instance.new("UIStroke")
		s2.Thickness = 2
		s2.Color = P.ink
		s2.Parent = nl
		nl.Parent = bb
		y = 46
	end
	if showHp then
		local back = Instance.new("Frame")
		back.BackgroundColor3 = P.ink
		back.BorderSizePixel = 0
		back.Position = UDim2.new(0.15, 0, 0, y + 2)
		back.Size = UDim2.new(0.7, 0, 0, 16)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = back
		local fill = Instance.new("Frame")
		fill.BorderSizePixel = 0
		fill.BackgroundColor3 = v.tier >= 3 and tier.color or P.red
		fill.Size = UDim2.fromScale(1, 1)
		local c2 = Instance.new("UICorner")
		c2.CornerRadius = UDim.new(0, 8)
		c2.Parent = fill
		fill.Parent = back
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = Color3.new(1, 1, 1)
		t.ZIndex = 3
		local s3 = Instance.new("UIStroke")
		s3.Thickness = 1.5
		s3.Color = P.ink
		s3.Parent = t
		t.Parent = back
		back.Parent = bb
		v.hpFill = fill
		v.hpText = t
	end
	bb.Parent = v.root
	v.label = bb
	updateLabel(v)
end

local function makeBeacon(v: View)
	local tier = Tiers.get(v.def.tier)
	local p = Instance.new("Part")
	p.Name = "Beacon"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = tier.rainbow and P.white or tier.color
	p.Transparency = 0.55
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(140, 1.2, 1.2)
	p.CFrame = CFrame.new(v.base + Vector3.new(0, 72, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = folder
	v.beacon = p
end

---------------------------------------------------------------------------------------------------------------
-- Spawn / remove
---------------------------------------------------------------------------------------------------------------

local function spawnView(r: any, fromSync: boolean)
	if type(r) ~= "table" then
		return
	end
	local id = tonumber(r[1])
	local key = r[2]
	if not id or type(key) ~= "string" or views[id] or gone[id] then
		return
	end
	local def = Config.Balloons[key]
	if not def then
		return
	end
	local flags = tonumber(r[8]) or 0
	local base = Vector3.new(tonumber(r[3]) or 0, tonumber(r[4]) or 0, tonumber(r[5]) or 0)
	local tierIdx = Tiers.index[def.tier] or 1
	local model, root = BalloonArt.build(def, { weld = true })
	if def.light or def.particles then
		BalloonArt.fx(model, def)
	end
	local maxHp = tonumber(r[7]) or 1
	local v: View = {
		id = id,
		key = key,
		def = def,
		tier = tierIdx,
		model = model,
		root = root,
		base = base,
		pos = base,
		hp = tonumber(r[6]) or 1,
		maxHp = maxHp,
		unacked = 0,
		big = Config.TierStats[def.tier].big and flags % 2 == 0,
		shower = flags % 2 == 1,
		fromMega = flags >= 2 and not fromSync,
		radius = BalloonArt.radius(def),
		born = fromSync and (os.clock() - 10) or os.clock(),
		phase = rng:NextNumber(0, math.pi * 2),
		wobble = 0,
		inflight = 0,
		popped = false,
		predictedAt = nil,
		serverPopped = false,
		done = false,
		leavingAt = nil,
		lastBump = 0,
		shown = false,
		label = nil,
		hpFill = nil,
		hpText = nil,
		beacon = nil,
	}
	views[id] = v
	root.CFrame = CFrame.new(base - Vector3.new(0, 400, 0))
	makeLabel(v)
	if tierIdx >= Config.AnnounceSpawnTier and not v.shower then
		makeBeacon(v)
	end
	if not fromSync and tierIdx >= 4 and (base - camera.CFrame.Position).Magnitude < 120 then
		Fx.sparkle(base, Tiers.get(def.tier).color, def.size * 0.8, 1.4)
	end
end

local function finalize(v: View)
	if v.done then
		return
	end
	v.done = true
	views[v.id] = nil
	v.model:Destroy()
	local b = v.beacon
	if b then
		b:Destroy()
	end
end

local function zap(to: Vector3)
	local r = hrp()
	if not r then
		return
	end
	local from = r.Position
	local dist = (to - from).Magnitude
	if dist < 0.5 then
		return
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = P.lilac
	p.Transparency = 0.15
	p.Size = Vector3.new(0.3, 0.3, dist)
	p.CFrame = CFrame.lookAt((from + to) / 2, to)
	p.Parent = folder
	TweenService:Create(p, TweenInfo.new(0.25), { Transparency = 1, Size = Vector3.new(0.05, 0.05, dist) }):Play()
	Debris:AddItem(p, 0.3)
end

local function popFx(v: View, mine: boolean, flags: number)
	if v.popped then
		return
	end
	v.popped = true
	local def = v.def
	local pos = v.pos
	v.model.Parent = nil
	local b = v.beacon
	if b then
		b.Transparency = 1
	end
	if (pos - camera.CFrame.Position).Magnitude > 170 then
		return
	end
	local s = def.size
	local cols = { def.c1, def.c2 or P.white, BalloonArt.shade(def.c1, 0.78), P.white }
	Fx.burst(pos, cols, math.floor(5 + s * 2), 0.45 + s * 0.16)
	if v.tier >= 3 then
		Fx.shockwave(pos, Tiers.get(def.tier).color, s * 2.4)
	end
	if popSounds < 10 then
		popSounds += 1
		Sfx.play("pop", mine and 0.6 or 0.28, math.clamp(1.45 - s * 0.09, 0.75, 1.5) * rng:NextNumber(0.92, 1.1))
	end
	if mine and flags == AURA then
		zap(pos)
	end
	if mine and v.tier >= 3 then
		UI.shake(0.08 + v.tier * 0.03)
	end
end

local function rollback(v: View)
	if v.done or not v.popped then
		return
	end
	v.popped = false
	v.predictedAt = nil
	v.unacked = 0
	v.model.Parent = folder
	local b = v.beacon
	if b then
		b.Transparency = 0.55
	end
	updateLabel(v)
end

local function predictPop(v: View)
	popFx(v, true, 0)
	v.predictedAt = os.clock()
end

---------------------------------------------------------------------------------------------------------------
-- Darts
---------------------------------------------------------------------------------------------------------------

type DartStyle = { shaft: Color3, fin: Color3, scale: number, glow: boolean }
local DART_STYLES: { [number]: DartStyle } = {
	[0] = { shaft = P.yellow, fin = P.accent, scale = 1, glow = false },
	[1] = { shaft = P.white, fin = P.gold, scale = 1.1, glow = false }, -- VIP: gold darts
	[2] = { shaft = P.gold, fin = P.gold, scale = 1.25, glow = true }, -- Golden Dart
	[3] = { shaft = P.red, fin = P.orange, scale = 2.4, glow = true }, -- Mega Dart
	[4] = { shaft = P.sky, fin = P.pink, scale = 1.2, glow = false }, -- Party Bots
}
local pools: { [number]: { Dart } } = {}
local flights: { Flight } = {}

local function newDart(style: number): Dart
	local st = DART_STYLES[style] or DART_STYLES[0]
	local s = st.scale
	local m = Instance.new("Model")
	m.Name = "Dart"
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		if shape then
			p.Shape = shape
		end
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Parent = m
		return p
	end
	local root = part("Root", Vector3.new(0.1, 0.1, 0.1), CFrame.new(), P.white)
	root.Transparency = 1
	part("Shaft", Vector3.new(1.5 * s, 0.17 * s, 0.17 * s), CFrame.Angles(0, math.rad(90), 0), st.shaft, Enum.PartType.Cylinder)
	local tip = part("Tip", Vector3.new(0.55 * s, 0.1 * s, 0.1 * s), CFrame.new(0, 0, -0.98 * s) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(210, 214, 226), Enum.PartType.Cylinder)
	tip.Reflectance = 0.3
	local f1 = part("Fin", Vector3.new(0.05 * s, 0.6 * s, 0.55 * s), CFrame.new(0, 0, 0.62 * s), st.fin)
	local f2 = part("Fin", Vector3.new(0.6 * s, 0.05 * s, 0.55 * s), CFrame.new(0, 0, 0.62 * s), st.fin)
	if st.glow then
		f1.Material = Enum.Material.Neon
		f2.Material = Enum.Material.Neon
	end
	for _, inst in ipairs(m:GetChildren()) do
		if inst ~= (root :: Instance) and inst:IsA("BasePart") then
			local bp = inst :: BasePart
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = bp
			w.Parent = bp
			bp.Anchored = false
			bp.Massless = true
		end
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.14 * s, 0.7 * s)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.14 * s, 0.7 * s)
	a1.Parent = root
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Lifetime = st.glow and 0.3 or 0.14
	tr.Color = ColorSequence.new(st.glow and st.fin or P.white)
	tr.Transparency = NumberSequence.new(st.glow and 0.1 or 0.45, 1)
	tr.LightEmission = st.glow and 0.8 or 0.3
	tr.FaceCamera = true
	tr.Parent = root
	m.PrimaryPart = root
	return { model = m, root = root, style = style, trail = tr }
end

local function getDart(style: number): Dart
	local pool = pools[style]
	if pool and #pool > 0 then
		return table.remove(pool) :: Dart
	end
	return newDart(style)
end

local function releaseDart(d: Dart)
	d.trail.Enabled = false
	d.model.Parent = nil
	local pool = pools[d.style]
	if not pool then
		pool = {}
		pools[d.style] = pool
	end
	if #pool < 24 then
		table.insert(pool, d)
	else
		d.model:Destroy()
	end
end

local function launch(style: number, from: Vector3, target: () -> Vector3, onArrive: (() -> ())?)
	local to = target()
	local dist = (to - from).Magnitude
	if #flights > 80 or dist < 0.2 then
		if onArrive then
			task.spawn(onArrive)
		end
		return
	end
	local d = getDart(style)
	d.trail.Enabled = false
	d.root.CFrame = CFrame.lookAt(from, to)
	d.model.Parent = dartFolder
	task.defer(function()
		if d.model.Parent then
			pcall(function()
				d.trail:Clear()
			end)
			d.trail.Enabled = true
		end
	end)
	table.insert(flights, {
		dart = d,
		from = from,
		t0 = os.clock(),
		dur = math.clamp(dist / (style == 3 and 110 or 170), 0.07, 0.45),
		arc = math.min(dist * 0.05, 3),
		target = target,
		last = from,
		arrive = onArrive,
	})
end

local function stepFlights(now: number)
	for i = #flights, 1, -1 do
		local f = flights[i]
		local k = math.clamp((now - f.t0) / f.dur, 0, 1)
		local to = f.target()
		local pos = f.from:Lerp(to, k) + Vector3.new(0, math.sin(k * math.pi) * f.arc, 0)
		local dir = pos - f.last
		if dir.Magnitude > 1e-3 then
			f.dart.root.CFrame = CFrame.lookAt(pos, pos + dir)
		end
		f.last = pos
		if k >= 1 then
			table.remove(flights, i)
			releaseDart(f.dart)
			local cb = f.arrive
			if cb then
				task.spawn(cb)
			end
		end
	end
end

-- Quick overhand arm swing on the local character (R15 only; harmless otherwise).
local function swing()
	if swingMotor then
		swingAt = os.clock()
	end
end

local function stepSwing(now: number)
	local m = swingMotor
	if not m or swingAt < 0 then
		return
	end
	local k = (now - swingAt) / 0.24
	if k >= 1 or not m.Parent then
		m.C0 = swingBase
		swingAt = -1
		return
	end
	local a = k < 0.15 and (150 * k / 0.15) or (150 * (1 - (k - 0.15) / 0.85) ^ 2)
	m.C0 = swingBase * CFrame.Angles(math.rad(a), 0, 0)
end

local function bindCharacter(c: Model)
	swingMotor = nil
	swingAt = -1
	task.spawn(function()
		local arm = c:WaitForChild("RightUpperArm", 6)
		local m = arm and arm:FindFirstChild("RightShoulder")
		if m and m:IsA("Motor6D") then
			swingMotor = m :: Motor6D
			swingBase = (m :: Motor6D).C0
		end
	end)
end

---------------------------------------------------------------------------------------------------------------
-- Throwing
---------------------------------------------------------------------------------------------------------------

local function hitPuff(v: View)
	if (v.pos - camera.CFrame.Position).Magnitude < 90 then
		Fx.burst(v.pos + (camera.CFrame.Position - v.pos).Unit * v.radius * 0.8, { v.def.c1, P.white }, 3, 0.35)
	end
end

local function arrive(v: View, mega: boolean)
	v.inflight = math.max(0, v.inflight - 1)
	if v.done then
		return
	end
	if v.serverPopped then
		if not v.popped then
			popFx(v, true, 0)
		end
		finalize(v)
		return
	end
	if v.popped then
		return
	end
	v.wobble = 1
	hitPuff(v)
	if mega then
		return -- the server's splash decides; its "boom" and pops arrive in a moment
	end
	local d = State.data
	v.unacked += Econ.power(d)
	if v.hp - v.unacked <= 0 then
		predictPop(v)
	else
		Sfx.play("thud", 0.16, rng:NextNumber(1.7, 2), 0.5)
		updateLabel(v)
	end
end

local function canHit(v: View, d: PData, from: Vector3): boolean
	if v.popped or v.serverPopped or v.done or v.leavingAt then
		return false
	end
	if not v.shower and v.def.zone > (d.zones or 1) then
		return false
	end
	return (v.base - from).Magnitude <= Config.Throw.range + v.radius
end

local function screenCircle(pos: Vector3, r: number): (Vector2?, number)
	local sp, on = camera:WorldToViewportPoint(pos)
	if not on or sp.Z <= 0.1 then
		return nil, 0
	end
	local f = camera.ViewportSize.Y / (2 * math.tan(math.rad(camera.FieldOfView) / 2) * sp.Z)
	return Vector2.new(sp.X, sp.Y), r * f
end

local function pick(screen: Vector2, d: PData, from: Vector3): Target?
	local best: Target? = nil
	local bestScore = 1
	for _, v in pairs(views) do
		if v.shown and canHit(v, d, from) then
			local sp, sr = screenCircle(v.pos, v.radius)
			if sp then
				local score = (sp - screen).Magnitude / (sr + PICK_SLACK)
				if score <= bestScore then
					local t: Target = { id = v.id, view = v }
					best = t
					bestScore = score
				end
			end
		end
	end
	local mpos, mrad = MegaView.target()
	if mpos and (mpos - from).Magnitude <= Config.Throw.megaRange then
		local sp, sr = screenCircle(mpos, mrad)
		if sp then
			local score = (sp - screen).Magnitude / (sr + PICK_SLACK)
			if score <= bestScore then
				local t: Target = { id = 0, view = nil }
				best = t
			end
		end
	end
	return best
end

-- Holding with nothing under the pointer: the Mega Balloon during the event, else the nearest balloon ahead.
local function fallback(d: PData, from: Vector3): Target?
	local mpos = MegaView.target()
	if mpos and (mpos - from).Magnitude <= Config.Throw.megaRange then
		local t: Target = { id = 0, view = nil }
		return t
	end
	local look = camera.CFrame.LookVector
	local best: View? = nil
	local bestD = 30
	for _, v in pairs(views) do
		if v.shown and canHit(v, d, from) then
			local off = v.base - from
			local dd = off.Magnitude
			if dd < bestD and (dd < 9 or off.Unit:Dot(look) > 0.25) then
				best = v
				bestD = dd
			end
		end
	end
	if best then
		local t: Target = { id = best.id, view = best }
		return t
	end
	return nil
end

local function throwAt(t: Target): boolean
	local d = State.data
	local r = hrp()
	local hand = handPos()
	if not d or not r or not hand then
		return false
	end
	local now = os.clock()
	if now < nextThrow then
		return false
	end
	nextThrow = now + Econ.cooldown(d)
	local mega = Hud.megaArmed and Hud.megaDarts() > 0
	throwRemote:FireServer(t.id, mega, false)
	if mega then
		Hud.usedMegaDart()
		Sfx.play("whoosh", 0.35, 1.4, 0.8)
	end
	swing()
	Sfx.play("swipe", 0.2, rng:NextNumber(1.2, 1.45), 0.6)
	local style = mega and 3 or myStyle()
	local v = t.view
	if v then
		local tv = v
		tv.inflight += 1
		launch(style, hand, function(): Vector3
			return tv.pos
		end, function()
			arrive(tv, mega)
		end)
	else
		local from = hand
		local seed = rng:NextNumber()
		launch(style, hand, function(): Vector3
			return MegaView.aimPoint(from, seed)
		end, function()
			MegaView.onHit(mega, true)
		end)
	end
	return true
end

local function pointerOf(input: InputObject): Vector2
	if input.UserInputType == Enum.UserInputType.Touch then
		local inset = GuiService:GetGuiInset()
		return Vector2.new(input.Position.X, input.Position.Y) + inset
	end
	return UserInputService:GetMouseLocation()
end

local function tryThrow(screen: Vector2, allowFallback: boolean)
	local d = State.data
	local r = hrp()
	if not d or not r then
		return
	end
	local t = pick(screen, d, r.Position)
	if not t and allowFallback then
		t = fallback(d, r.Position)
	end
	if t then
		throwAt(t)
	end
end

---------------------------------------------------------------------------------------------------------------
-- Per-frame update
---------------------------------------------------------------------------------------------------------------

local auraRing: BasePart? = nil
local lastBumpAny = 0
local nextBumpCheck = 0

local function stepAura(now: number, d: PData?)
	local ring = auraRing
	if not ring then
		return
	end
	local r = hrp()
	local radius = d and Econ.auraRadius(d) or 0
	if not r or radius <= 0 then
		ring.Transparency = 1
		return
	end
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local drop = (hum and hum.HipHeight or 2) + r.Size.Y / 2 - 0.15
	ring.Size = Vector3.new(0.12, radius * 2, radius * 2)
	ring.CFrame = CFrame.new(r.Position - Vector3.new(0, drop, 0)) * CFrame.Angles(0, now % (math.pi * 2), math.rad(90))
	ring.Transparency = 0.78 + math.sin(now * 4) * 0.06
end

local function stepBump(now: number, d: PData)
	if now < nextBumpCheck then
		return
	end
	nextBumpCheck = now + 0.08
	local r = hrp()
	if not r then
		return
	end
	local pos = r.Position
	for _, v in pairs(views) do
		if v.shown and not v.popped and not v.serverPopped and not v.leavingAt and (v.shower or v.def.zone <= (d.zones or 1)) then
			local reach = v.radius + Config.Throw.bumpRange + 1
			if (v.base - pos).Magnitude <= reach and now - v.lastBump > 0.35 and now - lastBumpAny > 0.18 then
				v.lastBump = now
				lastBumpAny = now
				throwRemote:FireServer(v.id, false, true)
				v.wobble = 1
				v.unacked += Econ.power(d)
				if v.hp - v.unacked <= 0 then
					predictPop(v)
				else
					Sfx.play("thud", 0.2, rng:NextNumber(1.3, 1.5), 0.5)
					updateLabel(v)
				end
			end
		end
	end
end

local function animate(v: View, now: number, camPos: Vector3, dt: number)
	local age = now - v.born
	local pos = v.base
	local leaving = v.leavingAt
	if leaving then
		local k = now - leaving
		pos = v.base + Vector3.new(math.sin(k * 3) * 0.6, k * k * 16 + k * 4, 0)
		if k > 1.8 then
			finalize(v)
			return
		end
	elseif v.fromMega and age < SHOWER_T then
		local k = age / SHOWER_T
		local e = 1 - (1 - k) ^ 2
		pos = Config.Hub.megaPos:Lerp(v.base, e) + Vector3.new(0, math.sin(k * math.pi) * 16, 0)
	elseif age < RISE then
		local k = math.clamp(age / RISE, 0, 1)
		pos = v.base - Vector3.new(0, (1 - easeOutBack(k)) * (v.def.size * 0.6 + 3.5), 0)
	end
	pos += Vector3.new(0, math.sin(now * 1.7 + v.phase) * 0.35, 0)
	local flat = Vector3.new(camPos.X, pos.Y, camPos.Z)
	local cf = (flat - pos).Magnitude > 0.1 and CFrame.lookAt(pos, flat) or CFrame.new(pos)
	local sway = math.sin(now * 1.2 + v.phase * 1.7) * 0.07
	local w = v.wobble
	if w > 0.01 then
		local j = math.sin(now * 40) * w * 0.28
		cf *= CFrame.Angles(j, 0, sway + j * 0.6)
		v.wobble = w * math.exp(-dt * 7)
	else
		cf *= CFrame.Angles(0, 0, sway)
	end
	v.root.CFrame = cf
	v.pos = pos
end

local function step(dt: number)
	frame += 1
	local now = os.clock()
	local camCf = camera.CFrame
	local camPos = camCf.Position
	local camLook = camCf.LookVector
	popSounds = math.max(0, popSounds - dt * 14)
	flyBudget = math.min(8, flyBudget + dt * 6)
	for _, v in pairs(views) do
		if not v.done then
			if v.popped then
				local pa = v.predictedAt
				if pa and not v.serverPopped and now - pa > 1.6 then
					rollback(v)
				end
			else
				local off = v.base - camPos
				local dist = off.Magnitude
				if dist > HIDE_DIST then
					if v.leavingAt then
						finalize(v) -- floated away out of sight: animate() never runs for it, so drop it here
					elseif v.shown then
						v.shown = false
						v.model.Parent = nil
					end
				else
					if not v.shown then
						v.shown = true
						v.model.Parent = folder
					end
					-- level of detail: near balloons every frame, mid every 3rd, far every 8th
					-- (and anything behind the camera only every 8th)
					local every = dist < 70 and 1 or (dist < FAR_DIST and 3 or 8)
					if dist > 12 and off:Dot(camLook) < -v.radius then
						every = 8
					end
					if every == 1 or (frame + v.id) % every == 0 or now - v.born < RISE + 0.5 or v.leavingAt or v.wobble > 0.01 then
						animate(v, now, camPos, dt)
					end
				end
			end
		end
	end
	stepFlights(now)
	stepSwing(now)
	local d = State.data
	stepAura(now, d)
	if d then
		stepBump(now, d)
	end
	if holding and not holdMoved and now >= nextThrow then
		local screen = holdTouch and holdPos or UserInputService:GetMouseLocation()
		tryThrow(screen, true)
	end
end

---------------------------------------------------------------------------------------------------------------
-- Server messages
---------------------------------------------------------------------------------------------------------------

local function onBatch(raw: any)
	if type(raw) ~= "table" then
		return
	end
	local msg: any = raw
	local me = player.UserId
	for _, r in ipairs(msg.s or {}) do
		spawnView(r, false)
	end
	for _, h: any in ipairs(msg.h or {}) do
		local id = tonumber(h[1])
		local v = id and views[id]
		if v and not v.done then
			v.hp = tonumber(h[2]) or v.hp
			v.unacked = 0
			local pa = v.predictedAt
			if pa and v.hp > 0 and os.clock() - pa > 0.35 then
				rollback(v)
			end
			updateLabel(v)
		end
	end
	for _, p: any in ipairs(msg.p or {}) do
		local id = tonumber(p[1])
		if id then
			if syncing then
				gone[id] = true
			end
			local v = views[id]
			if v and not v.done then
				v.serverPopped = true
				local mine = tonumber(p[2]) == me
				local flags = tonumber(p[3]) or 0
				if v.popped then
					finalize(v)
				elseif mine and v.inflight > 0 and flags == 0 then
					local tv = v
					task.delay(0.5, function()
						if not tv.done then
							popFx(tv, true, 0)
							finalize(tv)
						end
					end)
				else
					popFx(v, mine, flags)
					finalize(v)
				end
			end
		end
	end
	for _, gid: any in ipairs(msg.g or {}) do
		local id = tonumber(gid)
		if id then
			if syncing then
				gone[id] = true
			end
			local v = views[id]
			if v and not v.done then
				if v.popped then
					finalize(v)
				else
					v.leavingAt = os.clock()
					v.serverPopped = true
					local l = v.label
					if l then
						l:Destroy()
						v.label = nil
					end
				end
			end
		end
	end
end

local function onDart(uid: any, hand: any, targetId: any, style: any)
	if typeof(hand) ~= "Vector3" or type(targetId) ~= "number" then
		return
	end
	if uid == player.UserId then
		return
	end
	local h = hand :: Vector3
	if (h - camera.CFrame.Position).Magnitude > 240 then
		return
	end
	local st = tonumber(style) or 0
	if targetId == 0 then
		local seed = rng:NextNumber()
		launch(st, h, function(): Vector3
			return MegaView.aimPoint(h, seed)
		end, function()
			MegaView.onHit(st == 3, false)
		end)
	else
		local v = views[targetId]
		if v and not v.done and v.shown then
			local tv = v
			launch(st, h, function(): Vector3
				return tv.pos
			end, function()
				if not tv.done and not tv.popped then
					tv.wobble = 1
				end
			end)
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Public API (Ui messages from Main, Guide queries)
---------------------------------------------------------------------------------------------------------------

function BalloonView.posOf(id: number): Vector3?
	local v = views[id]
	if v and not v.done and not v.popped then
		return v.pos
	end
	return nil
end

-- Nearest poppable balloon to a point (FTUE arrow).
function BalloonView.nearest(from: Vector3, maxDist: number): Vector3?
	local d = State.data
	local best: Vector3? = nil
	local bestD = maxDist
	for _, v in pairs(views) do
		if v.shown and not v.popped and not v.leavingAt and (not d or v.shower or v.def.zone <= (d.zones or 1)) then
			local dd = (v.base - from).Magnitude
			if dd < bestD then
				best = v.pos
				bestD = dd
			end
		end
	end
	return best
end

function BalloonView.markRare(id: number)
	local v = views[id]
	if v and not v.done then
		Fx.sparkle(v.pos, Tiers.get(v.def.tier).color, v.def.size, 2.5)
	end
end

-- reward(id, key, coins, pos, first, helper, aura): coins for a pop (sent to each player who helped).
function BalloonView.onReward(_id: any, key: any, coins: any, pos: any, first: any, helper: any, aura: any)
	local def = type(key) == "string" and Config.Balloons[key] or nil
	if not def or type(coins) ~= "number" then
		return
	end
	local at: Vector3 = typeof(pos) == "Vector3" and pos or ((hrp() and (hrp() :: BasePart).Position) or Vector3.zero)
	local tier = Tiers.get(def.tier)
	local ti = Tiers.index[def.tier] or 1
	local near = (at - camera.CFrame.Position).Magnitude < 150
	if near then
		Fx.popup(at + Vector3.new(0, 1.2, 0), "+" .. Fmt.num(coins), ti >= 3 and tier.color or P.yellow, aura and 0.7 or (0.9 + ti * 0.08))
	end
	if flyBudget >= 1 and not (aura and flyBudget < 4) then
		flyBudget -= 1
		local sp = UI.screenPos(at) or UI.center()
		UI.fly(sp, Hud.coinTarget(), aura and 1 or math.clamp(ti + 1, 2, 7), Config.Icons.coin, Hud.punchCoins)
	end
	if first == true then
		Hud.markIndexNew()
		UI.toast("📖 NEW! " .. def.name .. " (" .. tier.name .. ") added to your Index!", tier.color, 3.5)
		Sfx.play("unlock", 0.45, 1.1)
	end
	if helper ~= true and ti >= 3 then
		UI.banner(string.upper(tier.name) .. "! " .. def.name, tier.color, 1.6)
		Sfx.play(ti >= 5 and "reveal" or "sparkle", 0.55)
		if ti >= 4 then
			Fx.sparkle(at, tier.color, def.size, 1.4)
		end
		if ti >= 5 then
			UI.confetti(ti >= 6 and 110 or 50, { tier.color, P.white, P.yellow, P.pink })
			Sfx.play("victory", 0.45)
		end
		if ti >= 6 then
			UI.flash(tier.rainbow and "white" or tier.color, 0.45)
			UI.shake(0.5)
			Sfx.play("cheer", 0.45, 1, 3)
		end
	end
end

-- Mega Dart explosion (or a summoned boom on the Mega Balloon).
function BalloonView.boom(center: any, radius: any)
	if typeof(center) ~= "Vector3" then
		return
	end
	local c = center :: Vector3
	local r = tonumber(radius) or 10
	Fx.shockwave(c, P.orange, r)
	Fx.shockwave(c + Vector3.new(0, 1, 0), P.yellow, r * 0.7)
	Fx.burst(c, { P.red, P.orange, P.yellow, P.white }, 22, 2)
	Sfx.play("magic", 0.5, 0.8)
	Sfx.play("pop", 0.6, 0.6)
	local h = hrp()
	if h and (h.Position - c).Magnitude < 60 then
		UI.shake(0.35)
	end
end

function BalloonView.init()
	folder = Instance.new("Folder")
	folder.Name = "ClientBalloons"
	folder.Parent = workspace
	dartFolder = Instance.new("Folder")
	dartFolder.Name = "ClientDarts"
	dartFolder.Parent = workspace

	local ring = Instance.new("Part")
	ring.Name = "AuraRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = P.lilac
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 1
	ring.Size = Vector3.new(0.12, 2, 2)
	ring.CFrame = CFrame.new(0, -500, 0)
	ring.Parent = folder
	auraRing = ring

	Net.event("Balloon").OnClientEvent:Connect(onBatch)
	dartRemote.OnClientEvent:Connect(onDart)
	task.spawn(function()
		local ok, list = pcall(function()
			return Net.func("BalloonSync"):InvokeServer()
		end)
		if ok and type(list) == "table" then
			for _, r in ipairs(list) do
				spawnView(r, true)
			end
		end
		syncing = false
		gone = {}
	end)

	player.CharacterAdded:Connect(bindCharacter)
	if player.Character then
		bindCharacter(player.Character)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			local screen = pointerOf(input)
			holding = true
			holdMoved = false
			holdStart = screen
			holdPos = screen
			holdTouch = (t == Enum.UserInputType.Touch) and input or nil
			tryThrow(screen, t == Enum.UserInputType.MouseButton1)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if holdTouch and input == holdTouch then
			holdPos = pointerOf(input)
			if (holdPos - holdStart).Magnitude > 26 then
				holdMoved = true -- dragging the camera, not throwing
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or (holdTouch and input == holdTouch) then
			holding = false
			holdTouch = nil
		end
	end)

	local warned = 0
	RunService:BindToRenderStep("Balloons", Enum.RenderPriority.Camera.Value + 2, function(dt)
		local ok, err = pcall(step, dt)
		if not ok and warned < 5 then
			warned += 1
			warn("[BalloonView]", err)
		end
	end)
end

return BalloonView

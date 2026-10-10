-- Client visuals for everything that moves: loose rocket parts (resting on pads, carried over the holders'
-- heads at the holders' centroid, wobbling when too heavy, flying up to their slot when bolted on), crew bots,
-- delivery drones, raised arms while carrying, rainbow Secret parts and blinking tower beacons.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Parts = require(Shared:WaitForChild("Parts"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local Net = require(Shared:WaitForChild("Net"))
local ClientLib = ReplicatedStorage:WaitForChild("ClientLib")
local UI = require(ClientLib:WaitForChild("UI"))
local Sfx = require(ClientLib:WaitForChild("Sfx"))
local Fx = require(ClientLib:WaitForChild("Fx"))
local Hub = require(ClientLib:WaitForChild("Hub"))

local Render = {}

local T = Config.Tune
local P = Config.Palette
local liftRemote = Net.event("Lift")
local player = Hub.player
local myUid = tostring(player.UserId)

local holder = Instance.new("Folder")
holder.Name = "RocketClient"
holder.Parent = workspace

type Vis = {
	id: string,
	cfg: Configuration,
	model: Model,
	grip: BasePart,
	prompt: ProximityPrompt,
	label: BillboardGui,
	nameText: TextLabel,
	subText: TextLabel,
	statusText: TextLabel,
	beam: BasePart?,
	kind: string,
	tier: string,
	scale: number,
	weight: number,
	cap: number,
	star: boolean,
	cf: CFrame,
	center: Vector3,
	yaw: number,
	lastC: Vector3?,
	flying: boolean,
	orphanAt: number?,
	helpUntil: number,
	skin: string,
	ftueFx: { Instance },
}

local vis: { [string]: Vis } = {}
Render.vis = vis

local function split(s: any): { string }
	local out = {}
	if type(s) == "string" then
		for w in string.gmatch(s, "[^,]+") do
			table.insert(out, w)
		end
	end
	return out
end

local function numAttr(inst: Instance, key: string, default: number): number
	local v = inst:GetAttribute(key)
	return if type(v) == "number" then v else default
end

local function vecAttr(inst: Instance, key: string, default: Vector3): Vector3
	local v = inst:GetAttribute(key)
	return if typeof(v) == "Vector3" then v else default
end

local function text(parent: Instance, y: number, h: number, size: number?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromScale(0, y)
	l.Size = UDim2.fromScale(1, h)
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Text = ""
	local s = Instance.new("UIStroke")
	s.Thickness = size or 2.5
	s.Color = UI.INK
	s.Parent = l
	l.Parent = parent
	return l
end

local function kindName(kind: string): string
	local k = Config.Kinds[kind]
	return k and k.name or kind
end

-- Loose parts ---------------------------------------------------------------------------------------------

local function poof(v: Vis)
	local c = v.center
	Fx.burst(c, { Tiers.get(v.tier).color, P.white }, 8, 0.8)
	v.model:Destroy()
	vis[v.id] = nil
end

local function boltFx(cf: CFrame, tier: string, kind: string, scale: number)
	local h = Parts.dims(kind, scale)
	local c = (cf * CFrame.new(0, h / 2, 0)).Position
	local t = Tiers.get(tier)
	Fx.burst(c, { t.color, P.white, P.orange }, 18, 1.3)
	Fx.shockwave(c, t.color, 12 * scale)
	local idx = Tiers.index[tier] or 1
	if idx >= 3 then
		Fx.sparkle(c, t.color, 7 * scale, 1.4)
	end
	local r = Hub.root()
	local near = r and (r.Position - c).Magnitude < 120
	if near then
		Sfx.play("thud", 0.7, 1.15)
		Sfx.play("coin", 0.35, 0.9)
		UI.shake(0.18)
		if idx >= 4 then
			Sfx.play("magic", 0.5)
		end
	end
end
Render.boltFx = boltFx

local function build(cfg: Configuration): Vis?
	local kind = cfg:GetAttribute("Kind")
	local tier = cfg:GetAttribute("Tier")
	if type(kind) ~= "string" or type(tier) ~= "string" then
		return nil
	end
	local scale = numAttr(cfg, "Scale", 1)
	local star = cfg:GetAttribute("Star") == true
	local skin = Hub.str("Skin", "Classic")
	local m = Parts.build(kind, scale, { collide = false })
	Parts.paint(m, skin, tier)
	m.Name = "Loose_" .. cfg.Name
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			(d :: BasePart).CanTouch = false
		end
	end
	local h = Parts.dims(kind, scale)
	local grip = Instance.new("Part")
	grip.Name = "Grip"
	grip.Size = Vector3.new(1, 1, 1)
	grip.Transparency = 1
	grip.Anchored = true
	grip.CanCollide = false
	grip.CanQuery = false
	grip.CanTouch = false
	grip.CFrame = CFrame.new(0, h / 2, 0)
	grip:SetAttribute("Role", "hit")
	grip.Parent = m
	local att = Instance.new("Attachment")
	att.Parent = grip
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "LIFT"
	prompt.ObjectText = kindName(kind)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = T.liftRange + Parts.halfWidth(kind, scale)
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = att
	local tIdx = Tiers.index[tier] or 1
	local bb = Instance.new("BillboardGui")
	bb.Name = "PartLabel"
	bb.Size = UDim2.fromScale(11, 3.4)
	bb.StudsOffsetWorldSpace = Vector3.new(0, Parts.halfDown(kind, scale) + 2.6, 0)
	bb.MaxDistance = tIdx >= 5 and 400 or 110
	bb.LightInfluence = 0
	bb.AlwaysOnTop = tIdx >= 5
	bb.Adornee = grip
	local nameText = text(bb, 0, 0.42, 3)
	local t = Tiers.get(tier)
	nameText.Text = star and "⭐ STAR CRATE" or ((tIdx > 1 and string.upper(t.name) .. " " or "") .. string.upper(kindName(kind)))
	if tIdx > 1 or star then
		local g = Instance.new("UIGradient")
		g.Color = Tiers.gradient(tier)
		g.Rotation = 90
		g.Parent = nameText
	end
	if t.rainbow then
		UI.rainbow(nameText)
	end
	local subText = text(bb, 0.42, 0.3, 2)
	local statusText = text(bb, 0.72, 0.28, 2)
	statusText.TextColor3 = Color3.fromRGB(255, 220, 80)
	bb.Parent = grip
	if tIdx >= 5 or star then
		local light = Instance.new("PointLight")
		light.Color = t.color
		light.Range = 16
		light.Brightness = 1.6
		light.Parent = grip
		local pe = Instance.new("ParticleEmitter")
		pe.Color = ColorSequence.new(t.color, Color3.new(1, 1, 1))
		pe.LightEmission = 1
		pe.Rate = 10
		pe.Lifetime = NumberRange.new(0.8, 1.4)
		pe.Speed = NumberRange.new(1.5, 3)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Size = NumberSequence.new(0.45, 0)
		pe.Parent = att
	end
	-- the first-time part glows and sparkles until someone lifts it
	local ftueFx: { Instance } = {}
	if cfg:GetAttribute("Ftue") == true then
		local fl = Instance.new("PointLight")
		fl.Color = P.gold
		fl.Range = 14
		fl.Brightness = 2.2
		fl.Parent = grip
		local sp = Instance.new("ParticleEmitter")
		sp.Color = ColorSequence.new(P.gold, Color3.new(1, 1, 1))
		sp.LightEmission = 1
		sp.Rate = 9
		sp.Lifetime = NumberRange.new(0.8, 1.3)
		sp.Speed = NumberRange.new(1, 2.5)
		sp.SpreadAngle = Vector2.new(180, 180)
		sp.Size = NumberSequence.new(0.4, 0)
		sp.Parent = att
		table.insert(ftueFx, fl)
		table.insert(ftueFx, sp)
	end
	local beam: BasePart? = nil
	if tIdx >= 5 or star then
		local b = Instance.new("Part")
		b.Name = "RareBeam"
		b.Shape = Enum.PartType.Cylinder
		b.Size = Vector3.new(140, 2.4, 2.4)
		b.Material = Enum.Material.Neon
		b.Color = t.color
		b.Transparency = 0.55
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.CanTouch = false
		b.CastShadow = false
		b.Parent = holder
		beam = b
	end
	local id = cfg.Name
	local rest = vecAttr(cfg, "Rest", Vector3.zero)
	local yaw = numAttr(cfg, "Yaw", 0)
	local center = rest + Vector3.new(0, Parts.halfDown(kind, scale), 0)
	local cf = Parts.centerCF(kind, scale, center, yaw)
	local born = numAttr(cfg, "Born", 0)
	local fresh = Hub.now() - born < 1.5
	if fresh then
		cf = cf + Vector3.new(0, 9, 0)
	end
	m:PivotTo(cf)
	m.Parent = holder
	local v: Vis = {
		id = id,
		cfg = cfg,
		model = m,
		grip = grip,
		prompt = prompt,
		label = bb,
		nameText = nameText,
		subText = subText,
		statusText = statusText,
		beam = beam,
		kind = kind,
		tier = tier,
		scale = scale,
		weight = numAttr(cfg, "Weight", 1),
		cap = numAttr(cfg, "Cap", 3),
		star = star,
		cf = cf,
		center = center,
		yaw = yaw,
		lastC = nil,
		flying = false,
		orphanAt = nil,
		helpUntil = 0,
		skin = skin,
		ftueFx = ftueFx,
	}
	prompt.Triggered:Connect(function()
		liftRemote:FireServer(id)
	end)
	if fresh then
		local r = Hub.root()
		if r and (r.Position - center).Magnitude < 90 then
			task.delay(0.35, function()
				Fx.burst(center, { t.color, P.white }, 10, 0.9)
				Sfx.play("pop", 0.35, 1.1)
			end)
		end
	end
	return v
end

local function flyTo(v: Vis, cf: CFrame)
	v.flying = true
	v.prompt.Enabled = false
	v.label.Enabled = false
	if v.beam then
		v.beam:Destroy()
		v.beam = nil
	end
	local from = v.cf
	local t0 = os.clock()
	local dur = 0.8
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - t0) / dur, 0, 1)
		local e = 1 - (1 - k) ^ 3
		local arc = math.sin(k * math.pi) * 14 * v.scale
		v.model:PivotTo(CFrame.new(0, arc, 0) * from:Lerp(cf, e))
		if k >= 1 then
			if conn then
				conn:Disconnect()
			end
			boltFx(cf, v.tier, v.kind, v.scale)
			v.model:Destroy()
			vis[v.id] = nil
		end
	end)
end

local function onBolt(p: any)
	if type(p) ~= "table" then
		return
	end
	local v = vis[p.id]
	local cf = p.cf
	if v and not v.flying then
		if typeof(cf) == "CFrame" then
			flyTo(v, cf)
		else
			-- Star Crate: pops open on the pad
			Fx.burst(v.center, { P.gold, P.white, P.orange }, 28, 1.6)
			Fx.shockwave(v.center, P.gold, 16)
			Sfx.play("sparkle", 0.6)
			if v.beam then
				v.beam:Destroy()
			end
			v.model:Destroy()
			vis[v.id] = nil
		end
	elseif typeof(cf) == "CFrame" and type(p.kind) == "string" then
		boltFx(cf, p.tier or "Common", p.kind, Hub.num("Scale", 1))
	end
end

local function updateVis(v: Vis, dt: number, now: number, heldId: string?, arms: { [string]: boolean }): Hub.Carry?
	local cfg = v.cfg
	local mode = cfg:GetAttribute("Mode")
	local rest = vecAttr(cfg, "Rest", v.center)
	local speed = numAttr(cfg, "Speed", 0)
	local str = numAttr(cfg, "Str", 0)
	local holders = split(cfg:GetAttribute("Holders"))
	local botIds = split(cfg:GetAttribute("Bots"))
	local halfDown = Parts.halfDown(v.kind, v.scale)
	local k = Config.Kinds[v.kind]
	local mine = table.find(holders, myUid) ~= nil
	local wobble = CFrame.new()
	local center: Vector3
	local tnow = os.clock()
	if mode == "carry" and speed > 0 then
		local sum = Vector3.zero
		local n = 0
		for _, uid in ipairs(holders) do
			local pl = Players:GetPlayerByUserId(tonumber(uid) or 0)
			local r = pl and Hub.root(pl)
			if r then
				sum += Vector3.new(r.Position.X, 0, r.Position.Z)
				n += 1
			end
			arms[uid] = true
		end
		local c = n > 0 and sum / n or Vector3.new(rest.X, 0, rest.Z)
		if v.lastC and k and k.lie then
			local d = c - v.lastC
			if d.Magnitude > 0.08 then
				local want = math.atan2(-d.X, -d.Z) + math.pi / 2
				local diff = (want - v.yaw + math.pi) % (2 * math.pi) - math.pi
				v.yaw += diff * math.min(1, dt * 4)
			end
		end
		v.lastC = c
		center = Vector3.new(c.X, rest.Y + T.carryLift + halfDown + math.sin(tnow * 7) * 0.12, c.Z)
	elseif mode == "carry" then
		-- too heavy: rocks on the ground while the lifters strain
		center = rest + Vector3.new(0, halfDown + 0.35 + math.abs(math.sin(tnow * 9)) * 0.25, 0)
		wobble = CFrame.Angles(math.sin(tnow * 23) * 0.05, 0, math.cos(tnow * 19) * 0.05)
		v.lastC = nil
	else
		center = rest + Vector3.new(0, halfDown, 0)
		if v.star or cfg:GetAttribute("Ftue") == true then
			center += Vector3.new(0, 0.6 + math.sin(tnow * 3) * 0.4, 0)
			wobble = CFrame.Angles(0, tnow * 0.8, 0)
		end
		v.lastC = nil
	end
	v.center = center
	if #v.ftueFx > 0 and cfg:GetAttribute("Ftue") ~= true then
		for _, e in ipairs(v.ftueFx) do
			e:Destroy()
		end
		table.clear(v.ftueFx)
	end
	local target = Parts.centerCF(v.kind, v.scale, center, v.yaw)
	if wobble ~= CFrame.new() then
		target = CFrame.new(center) * wobble * CFrame.new(-center) * target
	end
	v.cf = v.cf:Lerp(target, 1 - math.exp(-dt * 12))
	v.model:PivotTo(v.cf)
	if v.beam then
		v.beam.CFrame = CFrame.new(rest + Vector3.new(0, 70, 0)) * CFrame.Angles(0, 0, math.rad(90))
		v.beam.Transparency = mode == "rest" and (0.55 + math.sin(tnow * 4) * 0.1) or 1
	end

	-- prompt
	local phaseOk = Hub.phase() == "build"
	local full = #holders + #botIds >= v.cap
	if mine then
		v.prompt.ActionText = "DROP"
		v.prompt.Enabled = phaseOk
	elseif heldId then
		v.prompt.Enabled = false
	else
		v.prompt.ActionText = full and "FULL" or "LIFT"
		v.prompt.Enabled = phaseOk and not full
	end
	local objectText = string.format("%s  ⚖️%d", kindName(v.kind), math.floor(v.weight + 0.5))
	if v.prompt.ObjectText ~= objectText then
		v.prompt.ObjectText = objectText
	end

	-- labels
	local sub: string
	if mode == "carry" then
		sub = string.format("💪 %d/%d  👥 %d/%d", math.floor(str), math.ceil(v.weight), #holders + #botIds, v.cap)
	else
		sub = string.format("⚖️ %d  👥 0/%d", math.ceil(v.weight), v.cap)
	end
	if v.subText.Text ~= sub then
		v.subText.Text = sub
	end
	local status = ""
	local helping = tnow < v.helpUntil
	if mode == "carry" and speed <= 0 then
		status = "🙋 NEED A HAND!"
	elseif helping and mode == "carry" then
		status = "🙋 HELP ME LIFT!"
	elseif mode == "rest" and cfg:GetAttribute("Ftue") == true then
		status = "👇 LIFT ME!"
	elseif mode == "rest" and v.star then
		status = "HAUL TO THE PAD!"
	end
	if v.statusText.Text ~= status then
		v.statusText.Text = status
	end
	if status ~= "" then
		v.statusText.Rotation = math.sin(tnow * 8) * 4
	end

	if mine then
		local carry: Hub.Carry = {
			id = v.id,
			kind = v.kind,
			tier = v.tier,
			weight = v.weight,
			str = str,
			speed = speed,
			holders = #holders,
			cap = v.cap,
			bots = #botIds,
			pos = center,
		}
		return carry
	end
	return nil
end

-- Bots ------------------------------------------------------------------------------------------------------

type BotVis = {
	cfg: Configuration,
	model: Model,
	parts: { { p: BasePart, base: CFrame, up: CFrame? } },
	pos: Vector3,
	yaw: number,
}
local bots: { [string]: BotVis } = {}

local function buildBot(cfg: Configuration): BotVis
	local owned = numAttr(cfg, "Owner", 0) ~= 0
	local m = Instance.new("Model")
	m.Name = "Bot_" .. cfg.Name
	local list: { { p: BasePart, base: CFrame, up: CFrame? } } = {}
	local function add(shape: Enum.PartType?, size: Vector3, base: CFrame, color: Color3, neon: boolean?, up: CFrame?): BasePart
		local p = Instance.new("Part")
		if shape then
			p.Shape = shape
		end
		p.Size = size
		p.Color = color
		p.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Parent = m
		table.insert(list, { p = p, base = base, up = up })
		return p
	end
	local body = owned and P.gold or P.white
	local hero = ReplicatedStorage:FindFirstChild("HeroMeshes")
	local mesh = hero and hero:FindFirstChild("crewBot")
	if mesh and mesh:IsA("MeshPart") then
		local mp = (mesh :: any):Clone() :: MeshPart
		mp.Anchored = true
		mp.CanCollide = false
		mp.CanQuery = false
		mp.CanTouch = false
		mp.Parent = m
		table.insert(list, { p = mp, base = CFrame.new(0, mp.Size.Y / 2 + 0.5, 0), up = nil })
	else
		add(Enum.PartType.Ball, Vector3.new(2.8, 2.6, 2.8), CFrame.new(0, 2.6, 0), body)
		add(Enum.PartType.Ball, Vector3.new(2, 1.15, 1.2), CFrame.new(0, 2.85, -0.95), P.glow, true)
		add(Enum.PartType.Cylinder, Vector3.new(0.5, 2.95, 2.95), CFrame.new(0, 2.1, 0) * CFrame.Angles(0, 0, math.rad(90)), P.orange)
		add(Enum.PartType.Cylinder, Vector3.new(1, 0.25, 0.25), CFrame.new(0, 4.2, 0) * CFrame.Angles(0, 0, math.rad(90)), P.navy)
		add(Enum.PartType.Ball, Vector3.new(0.7, 0.7, 0.7), CFrame.new(0, 4.8, 0), owned and P.sky or P.orange, true)
		add(Enum.PartType.Cylinder, Vector3.new(0.5, 2.3, 2.3), CFrame.new(0, 1.1, 0) * CFrame.Angles(0, 0, math.rad(90)), P.navy)
		add(Enum.PartType.Cylinder, Vector3.new(0.2, 1.9, 1.9), CFrame.new(0, 0.75, 0) * CFrame.Angles(0, 0, math.rad(90)), P.glow, true)
		for _, x in ipairs({ -1.55, 1.55 }) do
			add(Enum.PartType.Cylinder, Vector3.new(1.5, 0.5, 0.5), CFrame.new(x, 1.9, 0), P.navy, false, CFrame.new(x * 0.9, 3.9, -0.3) * CFrame.Angles(0, 0, math.rad(90)))
			add(Enum.PartType.Ball, Vector3.new(0.75, 0.75, 0.75), CFrame.new(x, 1.1, 0), owned and P.orange or P.gold, false, CFrame.new(x * 0.9, 4.7, -0.3))
		end
	end
	local anchor = list[1].p
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(7, 1.3)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
	bb.MaxDistance = 80
	bb.LightInfluence = 0
	bb.Adornee = anchor
	local name = cfg:GetAttribute("Name")
	local l = text(bb, 0, 1, 2.5)
	l.Text = "🤖 " .. (type(name) == "string" and name or "Crew Bot")
	l.TextColor3 = owned and P.gold or Color3.fromRGB(200, 240, 255)
	bb.Parent = anchor
	m.Parent = holder
	local from = vecAttr(cfg, "From", Vector3.zero)
	return { cfg = cfg, model = m, parts = list, pos = from, yaw = 0 }
end

local function updateBot(b: BotVis, dt: number, now: number)
	local cfg = b.cfg
	local mode = cfg:GetAttribute("Mode")
	local ground = Hub.origin().Y
	local target: Vector3
	local face: Vector3? = nil
	local holding = false
	if mode == "hold" then
		local pid = cfg:GetAttribute("Part")
		local v = type(pid) == "string" and vis[pid] or nil
		local off = vecAttr(cfg, "Off", Vector3.zero)
		if v then
			target = Vector3.new(v.center.X + off.X, ground, v.center.Z + off.Z)
			face = Vector3.new(v.center.X, ground, v.center.Z)
			holding = true
		else
			target = vecAttr(cfg, "To", b.pos)
		end
	elseif mode == "walk" then
		local from = vecAttr(cfg, "From", b.pos)
		local to = vecAttr(cfg, "To", b.pos)
		local d = to - from
		local len = d.Magnitude
		if len > 0.01 then
			local tt = math.min(len, (now - numAttr(cfg, "T0", now)) * numAttr(cfg, "Speed", 20))
			target = from + d.Unit * tt
			face = to
		else
			target = to
		end
	else
		target = vecAttr(cfg, "To", b.pos)
	end
	target = Vector3.new(target.X, ground, target.Z)
	local prev = b.pos
	b.pos = prev:Lerp(target, 1 - math.exp(-dt * 10))
	if face and (face - b.pos).Magnitude > 0.5 then
		local d = face - b.pos
		b.yaw = math.atan2(-d.X, -d.Z)
	end
	local t = os.clock()
	local rootCF = CFrame.new(b.pos + Vector3.new(0, 0.6 + math.sin(t * 3 + #cfg.Name) * 0.25, 0)) * CFrame.Angles(0, b.yaw, 0)
	for _, e in ipairs(b.parts) do
		local lcf = (holding and e.up) or e.base
		e.p.CFrame = rootCF * lcf
	end
end

-- Arms up while carrying (R15 shoulders) ---------------------------------------------------------------------

local shoulderBase: { [Motor6D]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
local armsState: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function setArms(char: Model, up: boolean)
	if armsState[char] == up then
		return
	end
	armsState[char] = up
	for _, n in ipairs({ { "RightUpperArm", "RightShoulder" }, { "LeftUpperArm", "LeftShoulder" } }) do
		local arm = char:FindFirstChild(n[1])
		local motor = arm and arm:FindFirstChild(n[2])
		if motor and motor:IsA("Motor6D") then
			local m = motor :: Motor6D
			local base = shoulderBase[m]
			if not base then
				base = m.C0
				shoulderBase[m] = base
			end
			m.C0 = up and (base * CFrame.Angles(math.rad(165), 0, 0)) or base
		end
	end
end

-- Drones (auto-bolt) ------------------------------------------------------------------------------------------

local function droneFly(p: any)
	if type(p) ~= "table" or typeof(p.cf) ~= "CFrame" or type(p.kind) ~= "string" then
		return
	end
	local cf: CFrame = p.cf
	local scale = type(p.scale) == "number" and p.scale or 1
	local tier = type(p.tier) == "string" and p.tier or "Common"
	local partModel = Parts.build(p.kind, scale, { collide = false })
	Parts.paint(partModel, Hub.str("Skin", "Classic"), tier)
	partModel.Parent = holder
	local drone = Instance.new("Model")
	drone.Name = "Drone"
	local function dp(size: Vector3, color: Color3, neon: boolean?, shape: Enum.PartType?): BasePart
		local q = Instance.new("Part")
		q.Size = size
		q.Color = color
		if shape then
			q.Shape = shape
		end
		q.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
		q.Anchored = true
		q.CanCollide = false
		q.CanQuery = false
		q.CanTouch = false
		q.Parent = drone
		return q
	end
	local bodyP = dp(Vector3.new(5, 1.6, 5), P.white)
	local light = dp(Vector3.new(1.2, 1.2, 1.2), P.glow, true, Enum.PartType.Ball)
	local rotors: { BasePart } = {}
	for _, o in ipairs({ Vector3.new(3, 0.6, 3), Vector3.new(-3, 0.6, 3), Vector3.new(3, 0.6, -3), Vector3.new(-3, 0.6, -3) }) do
		local r = dp(Vector3.new(0.3, 3.6, 3.6), P.orange, false, Enum.PartType.Cylinder)
		r:SetAttribute("Off", o)
		table.insert(rotors, r)
	end
	drone.Parent = holder
	local h = Parts.dims(p.kind, scale)
	local from = cf + Vector3.new(90, 170, -70)
	local t0 = os.clock()
	local dur = 1.7
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - t0) / dur, 0, 1)
		local e = 1 - (1 - k) ^ 2
		local pcf = from:Lerp(cf, e)
		partModel:PivotTo(pcf)
		local top = (pcf * CFrame.new(0, h + 2.2, 0)).Position
		bodyP.CFrame = CFrame.new(top)
		light.CFrame = CFrame.new(top + Vector3.new(0, -0.9, -2.4))
		for i, r in ipairs(rotors) do
			local o = r:GetAttribute("Off")
			if typeof(o) == "Vector3" then
				r.CFrame = CFrame.new(top + o) * CFrame.Angles(0, os.clock() * 30 + i, math.rad(90))
			end
		end
		if k >= 1 then
			if conn then
				conn:Disconnect()
			end
			boltFx(cf, tier, p.kind, scale)
			partModel:Destroy()
			drone:Destroy()
		end
	end)
end

-- Main loop -----------------------------------------------------------------------------------------------------

local rainbow: { BasePart } = {}
local beacons: { BasePart } = {}

local function scanBeacons()
	table.clear(beacons)
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("Blink") == true then
			table.insert(beacons, d :: BasePart)
		end
	end
end

function Render.init()
	local looseFolder = ReplicatedStorage:WaitForChild("Loose")
	local botFolder = ReplicatedStorage:WaitForChild("Bots")

	local function addLoose(c: Instance)
		if not c:IsA("Configuration") or vis[c.Name] then
			return
		end
		local v = build(c :: Configuration)
		if v then
			vis[c.Name] = v
		end
	end
	looseFolder.ChildAdded:Connect(addLoose)
	looseFolder.ChildRemoved:Connect(function(c)
		local v = vis[c.Name]
		if v and not v.flying then
			v.orphanAt = os.clock()
		end
	end)
	for _, c in ipairs(looseFolder:GetChildren()) do
		addLoose(c)
	end

	local function addBot(c: Instance)
		if c:IsA("Configuration") and not bots[c.Name] then
			bots[c.Name] = buildBot(c :: Configuration)
		end
	end
	botFolder.ChildAdded:Connect(addBot)
	botFolder.ChildRemoved:Connect(function(c)
		local b = bots[c.Name]
		if b then
			Fx.burst(b.pos + Vector3.new(0, 2, 0), { P.white, P.glow }, 6, 0.6)
			b.model:Destroy()
			bots[c.Name] = nil
		end
	end)
	for _, c in ipairs(botFolder:GetChildren()) do
		addBot(c)
	end

	Hub.on("bolt", onBolt)
	Hub.on("drone", droneFly)
	Hub.on("help", function(p)
		if type(p) == "table" and type(p.id) == "string" then
			local v = vis[p.id]
			if v then
				v.helpUntil = os.clock() + 8
			end
		end
	end)

	-- repaint loose parts when the server rocket skin changes
	Hub.state:GetAttributeChangedSignal("Skin"):Connect(function()
		local skin = Hub.str("Skin", "Classic")
		for _, v in pairs(vis) do
			if not v.flying and v.skin ~= skin then
				v.skin = skin
				Parts.paint(v.model, skin, v.tier)
			end
		end
	end)

	for _, p in ipairs(CollectionService:GetTagged("Rainbow")) do
		if p:IsA("BasePart") then
			table.insert(rainbow, p :: BasePart)
		end
	end
	CollectionService:GetInstanceAddedSignal("Rainbow"):Connect(function(p)
		if p:IsA("BasePart") then
			table.insert(rainbow, p :: BasePart)
		end
	end)
	task.delay(3, scanBeacons)
	Hub.state:GetAttributeChangedSignal("Planet"):Connect(function()
		task.delay(2, scanBeacons)
	end)

	RunService.RenderStepped:Connect(function(dt)
		local now = Hub.now()
		local heldId = Hub.carry and Hub.carry.id or nil
		local arms: { [string]: boolean } = {}
		local mine: Hub.Carry? = nil
		for id, v in pairs(vis) do
			if v.flying then
				continue
			end
			if v.orphanAt then
				if os.clock() - v.orphanAt > 0.7 then
					if v.beam then
						v.beam:Destroy()
					end
					poof(v)
				end
				continue
			end
			local c = updateVis(v, dt, now, heldId, arms)
			if c then
				mine = c
			end
			local _ = id
		end
		Hub.carry = mine
		for _, b in pairs(bots) do
			updateBot(b, dt, now)
		end
		for _, pl in ipairs(Players:GetPlayers()) do
			local ch = pl.Character
			if ch then
				setArms(ch, arms[tostring(pl.UserId)] == true)
			end
		end
		if #rainbow > 0 then
			local t = os.clock()
			for i = #rainbow, 1, -1 do
				local p = rainbow[i]
				if p.Parent == nil or not CollectionService:HasTag(p, "Rainbow") then
					table.remove(rainbow, i)
				else
					p.Color = Color3.fromHSV((t * 0.25 + i * 0.08) % 1, 0.7, 1)
				end
			end
		end
		local blinkOn = (os.clock() % 1.2) < 0.6
		for _, b in ipairs(beacons) do
			b.Transparency = blinkOn and 0 or 0.7
		end
	end)
end

return Render

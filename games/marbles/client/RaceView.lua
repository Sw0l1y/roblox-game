--!strict
-- Live races on the client. The server streams each marble's distance along the track, lane offset and
-- height 15 times a second; this module buffers those snapshots, renders every marble 0.2 s behind the
-- server with smooth interpolation (rolling Glass marbles moved with one BulkMoveTo per frame), plays race
-- events in sync with that view, and runs the race UI: the big BOOST button with its timing meter, the
-- place/progress strip, chase cameras, countdown lights, and the clip moments - a slowed-down photo finish
-- from a side camera, and slow-mo when your marble catches big air off a jump.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Track = require(Shared:WaitForChild("Track"))
local Net = require(Shared:WaitForChild("Net"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local Fmt = require(Shared:WaitForChild("Fmt"))
local MarbleArt = require(Shared:WaitForChild("MarbleArt"))
local ClientLib = ReplicatedStorage:WaitForChild("ClientLib")
local UI = require(ClientLib:WaitForChild("UI"))
local Sfx = require(ClientLib:WaitForChild("Sfx"))
local Fx = require(ClientLib:WaitForChild("Fx"))
local TrackView = require(ClientLib:WaitForChild("TrackView"))
local MarbleIcon = require(ClientLib:WaitForChild("MarbleIcon"))

local RaceView = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local RC = Config.Race
local TAG = Track.TAG
local D = RC.marbleD
local RAD = D / 2
local V3 = Vector3.new
local exp = math.exp

local boostRemote = Net.event("Boost")

-- Hooks wired by Main.
RaceView.coinTarget = nil :: GuiObject?
RaceView.onReward = nil :: ((number, { [string]: any }) -> ())?
RaceView.onRaceOver = nil :: ((boolean) -> ())?

-- Types --------------------------------------------------------------------------------------------------
type Snap = { t: number, s: { number }, u: { number }, h: { number }, f: { number } }

type MB = {
	idx: number,
	ent: { [string]: any },
	built: MarbleArt.Built,
	def: Config.MarbleDef?,
	s: number,
	u: number,
	h: number,
	f: number,
	pos: Vector3,
	mine: boolean,
	boostTrail: Trail,
	glowState: number,
	finished: boolean,
	place: number,
}

type Rec = {
	id: number,
	desc: { [string]: any },
	kind: string,
	view: TrackView.View,
	td: Track.TrackData,
	goTime: number,
	marbles: { MB },
	snaps: { Snap },
	events: { { any } },
	myIdx: number?,
	done: boolean,
	results: { { [string]: any } }?,
	photo: boolean,
	photoShown: boolean,
	offset: number,
	slow: boolean,
	slowRate: number,
	slowUntil: number,
	slowKind: string,
	slowDone: boolean,
	folder: Folder,
	renderSim: number,
	lights: number,
	gp: boolean,
	reward: { [string]: any }?,
	resultsShown: boolean,
	myFinished: boolean,
	glowStart: number?,
	perfects: number,
	leaderIdx: number,
	removed: boolean,
}

local races: { [number]: Rec } = {}
local focus: Rec? = nil -- the race the camera/UI follows
local camMode = "free" -- free | start | follow | leader | overview | finish | preview
local camPos: Vector3? = nil
local camLook: Vector3? = nil
local camFwd = V3(0, 0, 1)
local preview: { view: TrackView.View, t0: number, endsAt: number }? = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

-- UI --------------------------------------------------------------------------------------------------------
local root = UI.root
local raceUi = UI.frame(root, { Name = "RaceUi", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 5 })

-- place + progress strip (top centre)
local strip = UI.frame(raceUi, {
	Name = "Progress",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -34),
	Size = UDim2.fromOffset(560, 24),
	BackgroundColor3 = UI.INK,
	BackgroundTransparency = 0.25,
	ZIndex = 6,
})
UI.corner(strip, 12)
UI.stroke(strip, 3)
UI.text(strip, "🏁", { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(34, 34), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, 8, 0.5, 0), ZIndex = 8 })
local dots: { Frame } = {}
local placeLabel = UI.text(raceUi, "", {
	Name = "Place",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -64),
	Size = UDim2.fromOffset(260, 58),
	ZIndex = 6,
})
local watchLabel = UI.text(raceUi, "", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -124),
	Size = UDim2.fromOffset(420, 30),
	TextColor3 = Color3.fromRGB(255, 240, 160),
	ZIndex = 6,
})
local perfectLabel = UI.text(raceUi, "", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -40, 1, -268),
	Size = UDim2.fromOffset(230, 30),
	TextColor3 = Color3.fromRGB(255, 220, 80),
	ZIndex = 6,
})

-- BOOST button + timing meter (bottom right, thumb reach)
local boostBtn = UI.button(raceUi, "BOOST", "grey", {
	Name = "Boost",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, if UI.isMobile then -200 else -40, 1, -40), -- phones: left of the touch jump button
	Size = UDim2.fromOffset(190, 190),
	ZIndex = 8,
	Visible = false,
})
local boostCorner = boostBtn:FindFirstChildOfClass("UICorner")
if boostCorner then
	boostCorner.CornerRadius = UDim.new(0.5, 0)
end
local boostGloss = boostBtn:FindFirstChild("Gloss") :: Frame?
if boostGloss then
	boostGloss.Size = UDim2.new(0.7, 0, 0.3, 0)
	boostGloss.Position = UDim2.new(0.15, 0, 0.08, 0)
end
-- recolor only on change (the race UI updates every frame; a new ColorSequence each frame is waste)
local boostCol = ""
local function boostColor(c: string)
	if c ~= boostCol then
		boostCol = c
		UI.recolor(boostBtn, c)
	end
end
local boostHint = UI.text(boostBtn, "⚡", { Font = Enum.Font.GothamBold, Size = UDim2.fromScale(0.36, 0.3), Position = UDim2.fromScale(0.32, -0.02), ZIndex = 10 })
local meter = UI.frame(raceUi, {
	Name = "Meter",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -20, 1, -244),
	Size = UDim2.fromOffset(230, 26),
	BackgroundColor3 = UI.INK,
	Visible = false,
	ZIndex = 8,
})
UI.corner(meter, 10)
UI.stroke(meter, 3)
local GOOD_A = 0
local PERF_A = math.max(0, (RC.glowDur * 0.45 - RC.perfectWin) / RC.glowDur)
local PERF_B = math.min(1, (RC.glowDur * 0.45 + RC.perfectWin) / RC.glowDur)
local goodZone = UI.frame(meter, { Size = UDim2.fromScale(1 - GOOD_A, 1), Position = UDim2.fromScale(GOOD_A, 0), BackgroundColor3 = Color3.fromRGB(90, 200, 110), ZIndex = 9 })
UI.corner(goodZone, 10)
local perfZone = UI.frame(meter, { Size = UDim2.fromScale(PERF_B - PERF_A, 1), Position = UDim2.fromScale(PERF_A, 0), BackgroundColor3 = Color3.fromRGB(255, 214, 50), ZIndex = 10 })
UI.text(perfZone, "PERFECT", { Size = UDim2.fromScale(1, 0.8), Position = UDim2.fromScale(0, 0.1), ZIndex = 11 })
local needle = UI.frame(meter, { Size = UDim2.new(0, 6, 1, 10), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 12 })
UI.stroke(needle, 2)

-- camera button (bottom left, above the menu)
local camBtn = UI.iconButton(root, Config.Icons.camera, "Camera", "purple", {
	Name = "CameraBtn",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -250, 1, -40),
	Size = UDim2.fromOffset(78, 78),
	Visible = false,
	ZIndex = 8,
})

-- results card
local results = UI.frame(root, {
	Name = "Results",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(600, 440),
	Visible = false,
	ZIndex = 30,
})
UI.corner(results, 22)
UI.stroke(results, 4.5)
UI.gradient(results, Color3.fromRGB(250, 251, 255), Color3.fromRGB(214, 222, 240))
local resHeader = UI.frame(results, { Size = UDim2.new(0.66, 0, 0, 60), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0), ZIndex = 32 })
UI.corner(resHeader, 18)
UI.stroke(resHeader, 4)
local resHeaderGrad = UI.gradient(resHeader, UI.lighten(UI.colors.orange, 0.1), UI.shade(UI.colors.orange, 0.7))
local resTitle = UI.text(resHeader, "RESULTS", { Size = UDim2.fromScale(0.9, 0.78), Position = UDim2.fromScale(0.05, 0.11), ZIndex = 33 })
local resPodium = UI.frame(results, { BackgroundTransparency = 1, Size = UDim2.new(1, -40, 0, 220), Position = UDim2.new(0, 20, 0, 44), ZIndex = 31 })
local resMine = UI.text(results, "", { Size = UDim2.new(1, -40, 0, 40), Position = UDim2.new(0, 20, 0, 268), TextColor3 = UI.INK, ZIndex = 31 })
local mineStroke = resMine:FindFirstChildOfClass("UIStroke")
if mineStroke then
	mineStroke.Enabled = false
end
local resChips = UI.frame(results, { BackgroundTransparency = 1, Size = UDim2.new(1, -40, 0, 56), Position = UDim2.new(0, 20, 0, 312), ZIndex = 31 })
UI.list(resChips, 12, true)
local resOk = UI.button(results, "NICE!", "green", { Size = UDim2.fromOffset(200, 56), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), ZIndex = 33 })
local resToken = 0
resOk.MouseButton1Click:Connect(function()
	results.Visible = false
end)

local function chip(text: string, color: any): TextLabel
	local f = UI.frame(resChips, { Size = UDim2.fromOffset(150, 50), ZIndex = 32 })
	UI.corner(f, 16)
	UI.stroke(f, 3)
	local c = UI.color(color)
	UI.gradient(f, UI.lighten(c, 0.1), UI.shade(c, 0.7))
	local l = UI.text(f, text, { Size = UDim2.new(1, -12, 0.74, 0), Position = UDim2.new(0, 6, 0.13, 0), ZIndex = 33 })
	UI.punch(f, 0.3)
	return l
end

local function ordinal(n: number): string
	local s = "TH"
	if n % 100 < 11 or n % 100 > 13 then
		local d = n % 10
		s = d == 1 and "ST" or (d == 2 and "ND" or (d == 3 and "RD" or "TH"))
	end
	return tostring(n) .. s
end
RaceView.ordinal = ordinal

-- Camera ---------------------------------------------------------------------------------------------------
local function freeCamera()
	camMode = "free"
	camPos = nil
	camLook = nil
	camera.CameraType = Enum.CameraType.Custom
	local ch = player.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if hum then
		camera.CameraSubject = hum :: Humanoid
	end
	camera.FieldOfView = 70
end

local function setCam(mode: string)
	if mode == "free" then
		freeCamera()
		return
	end
	if camMode == "free" then
		camPos = camera.CFrame.Position
		camLook = camera.CFrame.Position + camera.CFrame.LookVector * 20
	end
	camMode = mode
	camera.CameraType = Enum.CameraType.Scriptable
end

local function flat(v: Vector3, fallback: Vector3): Vector3
	local f = V3(v.X, 0, v.Z)
	if f.Magnitude < 0.05 then
		return fallback
	end
	return f.Unit
end

local function funnelAt(rec: Rec, s: number): { cx: number, cz: number, rimY: number, holeY: number, s0: number, s1: number }?
	for _, f in ipairs(rec.view.funnels) do
		if s >= f.s0 and s <= f.s1 then
			return f
		end
	end
	-- the bowl is known from the track data even before the client finished building it
	local td = rec.td
	for _, p in ipairs(td.pieces) do
		if p.type == "funnel" and s >= p.s0 and s <= p.s1 then
			return { cx = p.cx, cz = p.cz, rimY = p.rimY, holeY = p.holeY, s0 = p.s0, s1 = p.s1 }
		end
	end
	return nil
end

local function leaderOf(rec: Rec): MB?
	local best: MB? = nil
	for _, mb in ipairs(rec.marbles) do
		if not best then
			best = mb
		else
			local b = best :: MB
			if mb.finished and b.finished then
				if mb.place > 0 and (b.place == 0 or mb.place < b.place) then
					best = mb
				end
			elseif mb.finished ~= b.finished then
				if mb.finished then
					best = mb
				end
			elseif mb.s > b.s then
				best = mb
			end
		end
	end
	return best
end

local function chase(rec: Rec, mb: MB, dt: number)
	local s = mb.s
	local _, _, _, fwd = TrackView.frame(rec.view, math.max(0, s))
	local tag = Track.tagAt(rec.td, s)
	local desired: Vector3
	local look: Vector3
	local f = (tag == TAG.FUNNEL or tag == TAG.DROP) and funnelAt(rec, s) or nil
	if f then
		local out = V3(mb.pos.X - f.cx, 0, mb.pos.Z - f.cz)
		out = out.Magnitude > 0.5 and out.Unit or camFwd
		desired = V3(f.cx, f.rimY + 17, f.cz) + out * 24
		look = mb.pos
	else
		camFwd = camFwd:Lerp(flat(fwd, camFwd), 1 - exp(-dt * 2.6))
		if camFwd.Magnitude < 0.1 then
			camFwd = flat(fwd, V3(0, 0, 1))
		end
		camFwd = camFwd.Unit
		local lift = 7.5 + math.min(mb.h, 14) * 0.45
		desired = mb.pos - camFwd * 17 + V3(0, lift, 0)
		look = mb.pos + camFwd * 7 + V3(0, 1, 0)
	end
	local cp = camPos or desired
	local cl = camLook or look
	camPos = cp:Lerp(desired, 1 - exp(-dt * 5))
	camLook = cl:Lerp(look, 1 - exp(-dt * 9))
end

local function updateCamera(dt: number)
	if camMode == "free" then
		return
	end
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	local rec = focus
	if camMode == "preview" then
		local pv = preview
		if not pv or pv.view.dead then
			freeCamera()
			return
		end
		local td = pv.view.td
		local t = os.clock() - pv.t0
		local s = math.min(td.finishS, t * 95)
		local pos, _, _, fwd = TrackView.frame(pv.view, s)
		local ff = flat(fwd, V3(0, 0, 1))
		local side = V3(-ff.Z, 0, ff.X)
		local desired = pos - ff * 26 + side * 22 + V3(0, 30, 0)
		local look = (TrackView.frame(pv.view, math.min(td.finishS, s + 24)))
		if now() > pv.endsAt + RC.countdown + 2 then
			preview = nil
			freeCamera()
			return
		end
		camPos = (camPos or desired):Lerp(desired, 1 - exp(-dt * 3))
		camLook = (camLook or look):Lerp(look, 1 - exp(-dt * 4))
	elseif not rec then
		freeCamera()
		return
	elseif camMode == "start" then
		local cf = rec.view.gateCf
		local desired = (cf * CFrame.new(0, 10, 34)).Position
		local look = (cf * CFrame.new(0, 1.5, -8)).Position
		camPos = (camPos or desired):Lerp(desired, 1 - exp(-dt * 4))
		camLook = (camLook or look):Lerp(look, 1 - exp(-dt * 6))
	elseif camMode == "follow" or camMode == "leader" then
		local target: MB? = nil
		if camMode == "follow" and rec.myIdx then
			target = rec.marbles[rec.myIdx :: number]
		else
			target = leaderOf(rec)
		end
		if target then
			chase(rec, target, dt)
		end
	elseif camMode == "overview" then
		local sum = Vector3.zero
		local n = 0
		for _, mb in ipairs(rec.marbles) do
			if not mb.finished then
				sum += mb.pos
				n += 1
			end
		end
		if n == 0 then
			for _, mb in ipairs(rec.marbles) do
				sum += mb.pos
				n += 1
			end
		end
		local c = sum / math.max(1, n)
		local desired = c - camFwd * 50 + V3(0, 62, 0)
		camPos = (camPos or desired):Lerp(desired, 1 - exp(-dt * 2.5))
		camLook = (camLook or c):Lerp(c, 1 - exp(-dt * 4))
	elseif camMode == "finish" then
		local td = rec.td
		local photoCam = rec.slow and rec.slowKind == "photo"
		local desired, look
		if photoCam then
			local fp, fr, fu = TrackView.frame(rec.view, td.finishS)
			desired = fp + fr * 17 + fu * 3.2
			look = fp + fu * 1.6
		else
			local p0, _, u0 = TrackView.frame(rec.view, td.finishS - 6)
			desired = p0 + u0 * 10
			look = (TrackView.frame(rec.view, td.finishS + 18))
		end
		camPos = (camPos or desired):Lerp(desired, 1 - exp(-dt * (photoCam and 9 or 3)))
		camLook = (camLook or look):Lerp(look, 1 - exp(-dt * 6))
	end
	local cp, cl = camPos, camLook
	if cp and cl and (cl - cp).Magnitude > 0.01 then
		camera.CFrame = CFrame.lookAt(cp, cl)
	end
end

-- Marbles --------------------------------------------------------------------------------------------------
local function marblesFolder(): Folder
	local f = workspace:FindFirstChild("Marbles")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Marbles"
		f.Parent = workspace
	end
	return f :: Folder
end

local function makeLabel(mb: MB)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Tag"
	bb.Adornee = mb.built.glow
	bb.LightInfluence = 0
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	local s = Instance.new("UIStroke")
	s.Thickness = 2.5
	s.Color = UI.INK
	s.Parent = l
	local def = mb.def
	local mutDef = mb.ent.mut and Config.MutationByKey[mb.ent.mut] or nil
	if mb.mine then
		bb.Size = UDim2.fromOffset(150, 46)
		bb.StudsOffsetWorldSpace = V3(0, 4.2, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 1000
		l.Text = "YOU ▼"
		l.TextColor3 = Color3.fromRGB(255, 240, 90)
	else
		bb.Size = UDim2.fromOffset(130, 30)
		bb.StudsOffsetWorldSpace = V3(0, 3.4, 0)
		bb.MaxDistance = 90
		local name = tostring(mb.ent.name)
		if mutDef then
			name = mutDef.glyph .. " " .. name
		end
		l.Text = name
		l.TextColor3 = Color3.new(1, 1, 1)
		if def then
			local g = Instance.new("UIGradient")
			g.Color = ColorSequence.new(Color3.new(1, 1, 1), UI.lighten(Tiers.get(def.tier).color, 0.2))
			g.Rotation = 90
			g.Parent = l
		end
	end
	l.Parent = bb
	bb.Parent = mb.built.glow
	-- the mutation tease: a cosmic/rainbow marble gets a second line everyone can read
	if mutDef and not mb.mine then
		local bb2 = Instance.new("BillboardGui")
		bb2.Name = "Mut"
		bb2.Adornee = mb.built.glow
		bb2.LightInfluence = 0
		bb2.Size = UDim2.fromOffset(150, 26)
		bb2.StudsOffsetWorldSpace = V3(0, 5.6, 0)
		bb2.MaxDistance = 160
		local m = Instance.new("TextLabel")
		m.BackgroundTransparency = 1
		m.Size = UDim2.fromScale(1, 1)
		m.Font = Enum.Font.LuckiestGuy
		m.TextScaled = true
		m.Text = string.upper(mutDef.name) .. " x" .. tostring(mutDef.mult)
		m.TextColor3 = mutDef.color
		local s2 = Instance.new("UIStroke")
		s2.Thickness = 2.5
		s2.Color = UI.INK
		s2.Parent = m
		m.Parent = bb2
		bb2.Parent = mb.built.glow
	end
end

local function makeTrail(part: BasePart, colors: { Color3 }, life: number, width: number, emission: number): Trail
	local a0 = Instance.new("Attachment")
	a0.Position = V3(0, width / 2, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = V3(0, -width / 2, 0)
	a1.Parent = part
	local t = Instance.new("Trail")
	t.Attachment0 = a0
	t.Attachment1 = a1
	if #colors >= 2 then
		local kps = {}
		for i, c in ipairs(colors) do
			table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
		end
		t.Color = ColorSequence.new(kps)
	else
		t.Color = ColorSequence.new(colors[1] or Color3.new(1, 1, 1))
	end
	t.Lifetime = life
	t.LightEmission = emission
	t.FaceCamera = true
	t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	t.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.1) })
	t.MinLength = 0.05
	t.Parent = part
	return t
end

local function buildMarble(rec: Rec, ent: { [string]: any }): MB
	local id = tostring(ent.id)
	local built = MarbleArt.build(id, ent.mut, D)
	built.model.Parent = rec.folder
	MarbleArt.sparkle(built, id, ent.mut)
	local mine = (not ent.bot) and ent.userId == player.UserId
	local mb: MB = {
		idx = ent.idx,
		ent = ent,
		built = built,
		def = Config.MarbleById[id],
		s = tonumber(ent.s0) or 0,
		u = tonumber(ent.u0) or 0,
		h = 0,
		f = 0,
		pos = Vector3.zero,
		mine = mine,
		boostTrail = makeTrail(built.glow, { Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 120, 30) }, 0.35, 1.6, 0.9),
		glowState = -1,
		finished = false,
		place = 0,
	}
	mb.boostTrail.Enabled = false
	local trailKey = ent.trail
	if type(trailKey) == "string" and Config.TrailByKey[trailKey] then
		makeTrail(built.glow, Config.TrailByKey[trailKey].colors, 0.7, 1.4, 0.6)
	end
	makeLabel(mb)
	return mb
end

-- Snapshots --------------------------------------------------------------------------------------------------
local function onSnap(b: buffer)
	if buffer.len(b) < 14 then
		return
	end
	local id = buffer.readu8(b, 0)
	local rec = races[id]
	if not rec then
		return
	end
	local t = buffer.readf64(b, 1)
	local n = buffer.readu8(b, 13)
	if n ~= #rec.marbles or buffer.len(b) < 14 + n * 5 then
		return
	end
	local snap: Snap = { t = t, s = table.create(n, 0), u = table.create(n, 0), h = table.create(n, 0), f = table.create(n, 0) }
	for i = 1, n do
		local o = 14 + (i - 1) * 5
		snap.s[i] = buffer.readu16(b, o) / 20
		snap.u[i] = buffer.readi8(b, o + 2) / 127
		snap.h[i] = buffer.readu8(b, o + 3) / 20
		snap.f[i] = buffer.readu8(b, o + 4)
	end
	-- keep the list ordered (unreliable packets can arrive out of order)
	local snaps = rec.snaps
	local k = #snaps
	while k >= 1 and snaps[k].t > t do
		k -= 1
	end
	if k >= 1 and snaps[k].t == t then
		snaps[k] = snap
	else
		table.insert(snaps, k + 1, snap)
	end
end

local function hasFlag(f: number, bit: number): boolean
	return math.floor(f / bit) % 2 == 1
end

-- Interpolated state for every marble at render time rt (server clock).
local function interpolate(rec: Rec, rt: number)
	local snaps = rec.snaps
	local n = #snaps
	if n == 0 then
		return
	end
	local a = n
	while a >= 1 and snaps[a].t > rt do
		a -= 1
	end
	if a < 1 then
		local s1 = snaps[1]
		for i, mb in ipairs(rec.marbles) do
			mb.s, mb.u, mb.h, mb.f = s1.s[i], s1.u[i], s1.h[i], s1.f[i]
		end
		return
	end
	local sa = snaps[a]
	local sb = snaps[a + 1]
	if sb then
		local alpha = (rt - sa.t) / math.max(1e-3, sb.t - sa.t)
		for i, mb in ipairs(rec.marbles) do
			mb.s = sa.s[i] + (sb.s[i] - sa.s[i]) * alpha
			mb.u = sa.u[i] + (sb.u[i] - sa.u[i]) * alpha
			mb.h = sa.h[i] + (sb.h[i] - sa.h[i]) * alpha
			mb.f = alpha < 0.5 and sa.f[i] or sb.f[i]
		end
	else
		-- past the newest snapshot: extrapolate a little along the track
		local prev = snaps[a - 1]
		local over = math.min(rt - sa.t, 0.25)
		for i, mb in ipairs(rec.marbles) do
			local v = 0
			if prev and sa.t > prev.t then
				v = (sa.s[i] - prev.s[i]) / (sa.t - prev.t)
			end
			if hasFlag(sa.f[i], 4) then
				v = 0
			end
			mb.s = sa.s[i] + math.clamp(v, 0, 90) * over
			mb.u, mb.h, mb.f = sa.u[i], sa.h[i], sa.f[i]
		end
	end
	-- drop snapshots we no longer need (keep one before the render time)
	while #snaps > 2 and snaps[2].t < rt - 1.5 do
		table.remove(snaps, 1)
	end
end

-- Effects -----------------------------------------------------------------------------------------------------
local function near(pos: Vector3, dist: number): boolean
	return (camera.CFrame.Position - pos).Magnitude < dist
end

local function feedback(q: string)
	local btnPos = boostBtn.AbsolutePosition + boostBtn.AbsoluteSize / 2 + game:GetService("GuiService"):GetGuiInset()
	local at = Vector2.new(btnPos.X - 60, btnPos.Y - 150)
	if q == "perfect" then
		UI.floater("PERFECT!", "gold", at, 56)
		Sfx.play("sparkle", 0.6, 1.1)
		UI.shake(0.35)
		camera.FieldOfView = math.min(camera.FieldOfView + 10, 92)
	elseif q == "mega" then
		UI.floater("MEGA BOOST!", "orange", at, 60)
		Sfx.play("magic", 0.7, 1)
		UI.shake(0.6)
		UI.flash("orange", 0.6)
		camera.FieldOfView = math.min(camera.FieldOfView + 16, 96)
	elseif q == "good" then
		UI.floater("GOOD!", "green", at, 48)
		Sfx.play("pop", 0.55, 1.2)
		camera.FieldOfView = math.min(camera.FieldOfView + 5, 88)
	elseif q == "miss" then
		UI.floater("TOO EARLY!", "grey", at, 40)
		Sfx.play("error", 0.35, 0.9)
		boostColor("red")
	end
end

local function startSlow(rec: Rec, kind: string, rate: number, seconds: number)
	if rec.slow then
		return
	end
	rec.slow = true
	rec.slowKind = kind
	rec.slowRate = rate
	rec.slowUntil = os.clock() + seconds
	Sfx.play("reveal", 0.35, 0.7, 2)
end

local function handleEvent(rec: Rec, ev: { any }, immediate: boolean)
	local kind = ev[2]
	local idx = tonumber(ev[3]) or 0
	local mb = rec.marbles[idx]
	local mine = mb ~= nil and mb.mine
	local isFocus = focus == rec
	if kind == "boost" then
		if mine then
			if immediate then
				local q = tostring(ev[4])
				feedback(q)
				rec.perfects += (q == "perfect" or q == "mega") and 1 or 0
				if rec.perfects > 0 then
					perfectLabel.Text = "⚡ x" .. rec.perfects .. " PERFECT"
				end
			end
		elseif mb and near(mb.pos, 80) then
			Fx.burst(mb.pos, { Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 150, 40) }, 5, 0.5)
		end
	elseif kind == "miss" then
		if mine and immediate then
			feedback("miss")
		end
	elseif kind == "power" then
		if mb then
			Fx.sparkle(mb.pos, Color3.fromRGB(255, 80, 90), 3, 1)
			if mine then
				UI.banner("🧲 MAGNET PULL!", "red", 1.2)
				Sfx.play("magic", 0.5, 1.3)
			end
		end
	elseif kind == "bump" then
		if mb and near(mb.pos, 70) then
			Fx.burst(mb.pos, { Color3.fromRGB(255, 80, 90), Color3.new(1, 1, 1) }, 6, 0.6)
			if mine then
				Sfx.play("pop", 0.5, 0.8)
			end
		end
	elseif kind == "air" then
		local peak = tonumber(ev[4]) or 0
		if mine then
			Sfx.play("whoosh", 0.5, 1.2, 1.5)
			if peak > 5 then
				UI.floater(peak > 9 and "MEGA AIR!" or "BIG AIR!", "sky", UI.center() - Vector2.new(0, 120), 54)
				if isFocus and not rec.myFinished then
					startSlow(rec, "air", 0.42, 0.75)
				end
			end
		elseif mb and peak > 6 and isFocus and near(mb.pos, 60) then
			Sfx.play("whoosh", 0.25, 1.4, 1.5)
		end
	elseif kind == "land" then
		if mb and near(mb.pos, 90) then
			local _, _, up = TrackView.frame(rec.view, mb.s)
			Fx.shockwave(mb.pos - up * (RAD - 0.1), mb.def and mb.def.c1 or Color3.new(1, 1, 1), 6)
			if mine then
				Sfx.play("thud", 0.5, 1.2)
				UI.shake(0.25)
			end
		end
	elseif kind == "finish" then
		local place = tonumber(ev[4]) or 0
		if mb then
			mb.finished = true
			mb.place = place
		end
		if place == 1 and isFocus then
			local fp = rec.view.finishCf.Position
			Fx.burst(fp + V3(0, 3, 0), { Color3.fromRGB(255, 90, 170), Color3.fromRGB(70, 200, 255), Color3.fromRGB(255, 214, 50), Color3.fromRGB(120, 230, 90) }, 26, 1.6)
			Sfx.play("cheer", 0.35, 1, 3)
		end
		if mine then
			rec.myFinished = true
			local col = place == 1 and "gold" or (place <= 3 and "orange" or "white")
			local medal = place == 1 and "🥇 " or (place == 2 and "🥈 " or (place == 3 and "🥉 " or ""))
			UI.banner(medal .. ordinal(place) .. " PLACE!", col, 2.2)
			if place <= 3 then
				UI.confetti(place == 1 and 90 or 50)
				Sfx.play(place == 1 and "victory" or "clap", 0.6)
			else
				Sfx.play("clap", 0.4)
			end
			if camMode == "follow" then
				setCam("finish")
			end
		end
	elseif kind == "photo" then
		rec.photo = true
		if isFocus and not rec.photoShown then
			rec.photoShown = true
			local gap = tonumber(ev[5]) or 0
			UI.flash("white", 0.1)
			Sfx.play("click", 0.8, 0.6)
			UI.banner(string.format("📸 PHOTO FINISH! (%.2fs)", math.max(0.01, gap)), "white", 2.4)
		end
	elseif kind == "jam" then
		if isFocus and rec.myIdx then
			local me = rec.marbles[rec.myIdx :: number]
			if me and Track.tagAt(rec.td, me.s) == TAG.FUNNEL then
				UI.floater("🚦 TRAFFIC JAM!", "orange", UI.center() - Vector2.new(0, 160), 40)
			end
		end
	end
end

-- Results card ----------------------------------------------------------------------------------------------------
local function showResults(rec: Rec)
	local res = rec.results
	if not res or rec.resultsShown then
		return
	end
	rec.resultsShown = true
	resToken += 1
	local my = resToken
	for _, c in ipairs(resPodium:GetChildren()) do
		c:Destroy()
	end
	for _, c in ipairs(resChips:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local title = rec.kind == "practice" and "WARM-UP RESULTS" or (rec.gp and "GRAND PRIX!" or "RACE RESULTS")
	resTitle.Text = title
	local hc = rec.gp and UI.colors.purple or (rec.kind == "practice" and UI.colors.sky or UI.colors.orange)
	resHeaderGrad.Color = ColorSequence.new(UI.lighten(hc, 0.1), UI.shade(hc, 0.7))
	local winnerT = res[1] and tonumber(res[1].time) or 0
	local slots = { { place = 2, x = 0.17, h = 150 }, { place = 1, x = 0.5, h = 190 }, { place = 3, x = 0.83, h = 120 } }
	for _, sl in ipairs(slots) do
		local r = res[sl.place]
		if r then
			local col = UI.frame(resPodium, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(sl.x, 0, 1, 0), Size = UDim2.fromOffset(170, 220), ZIndex = 31 })
			local blockCol = sl.place == 1 and UI.colors.gold or (sl.place == 2 and UI.colors.grey or UI.colors.orange)
			local block = UI.card(col, blockCol, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(120, sl.h - 80), ZIndex = 31 })
			UI.text(block, tostring(sl.place), { Size = UDim2.fromScale(0.8, 0.7), Position = UDim2.fromScale(0.1, 0.12), ZIndex = 32 })
			local icon = MarbleIcon.flat(col, tostring(r.id), r.mut, 64, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -(sl.h - 80) - 26), ZIndex = 33 })
			UI.punch(icon, 0.4)
			local isMe = (not r.bot) and r.userId == player.UserId
			UI.text(col, (isMe and "⭐ " or "") .. tostring(r.name), {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -(sl.h - 80) - 4),
				Size = UDim2.fromOffset(170, 24),
				TextColor3 = isMe and Color3.fromRGB(255, 230, 80) or Color3.new(1, 1, 1),
				ZIndex = 33,
			})
			local tt = tonumber(r.time) or 0
			local tstr = sl.place == 1 and string.format("%.2fs", tt) or string.format("+%.2fs", math.max(0, tt - winnerT))
			UI.text(col, tstr, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -(sl.h - 80) - 94), Size = UDim2.fromOffset(120, 22), Font = UI.BODY, ZIndex = 33 })
		end
	end
	local myRow = nil
	for _, r in ipairs(res) do
		if not r.bot and r.userId == player.UserId then
			myRow = r
		end
	end
	if myRow then
		resMine.Text = string.format("You finished %s of %d!", ordinal(tonumber(myRow.place) or 0), #res)
	else
		resMine.Text = "Next race soon - pick your marble!"
	end
	results.Visible = true
	results.Position = UDim2.fromScale(0.5, 0.58)
	UI.tween(results, 0.35, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back)
	UI.punch(results, -0.1)
	Sfx.play("open", 0.5)
	task.delay(RC.resultsTime + 1, function()
		if resToken == my then
			results.Visible = false
		end
	end)
end

local function showReward(rec: Rec)
	local info = rec.reward
	if not info or not rec.resultsShown then
		return
	end
	local coins = tonumber(info.coins) or 0
	local coinChip = chip("+0 🪙", "gold")
	chip("+" .. tostring(info.xp or 0) .. " XP", "purple")
	chip("+" .. tostring(info.league or 0) .. " 🏅", "sky")
	local v = Instance.new("NumberValue")
	v.Changed:Connect(function(x)
		coinChip.Text = "+" .. Fmt.commas(x) .. " 🪙"
	end)
	UI.tween(v, 0.9, { Value = coins }, Enum.EasingStyle.Quad)
	task.delay(1, function()
		v:Destroy()
	end)
	Sfx.play("cash", 0.5)
	local target = RaceView.coinTarget
	if target then
		local from = coinChip.AbsolutePosition + coinChip.AbsoluteSize / 2 + game:GetService("GuiService"):GetGuiInset()
		UI.fly(from, target, math.clamp(math.floor(coins / 8), 4, 14), "🪙")
	end
	if (tonumber(info.levelUps) or 0) > 0 then
		task.delay(0.9, function()
			UI.banner("⬆️ MARBLE LEVEL UP!", "green", 2)
			Sfx.play("unlock", 0.6)
		end)
	end
end

-- Race lifecycle -----------------------------------------------------------------------------------------------------
local function myRace(): Rec?
	-- a finished heat lingers a few seconds before removal: prefer the one still running (BOOST goes there)
	local fallback: Rec? = nil
	for _, r in pairs(races) do
		if r.myIdx and not r.removed then
			if not r.done then
				return r
			end
			fallback = fallback or r
		end
	end
	return fallback
end

local function setFocus(rec: Rec?)
	focus = rec
	for _, d in ipairs(dots) do
		d:Destroy()
	end
	table.clear(dots)
	if rec then
		for _, mb in ipairs(rec.marbles) do
			local size = mb.mine and 22 or 14
			local dcol = mb.def and mb.def.c1 or Color3.new(1, 1, 1)
			local d = UI.frame(strip, {
				Size = UDim2.fromOffset(size, size),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				BackgroundColor3 = dcol,
				ZIndex = mb.mine and 9 or 7,
			})
			UI.corner(d, size)
			UI.stroke(d, mb.mine and 3 or 1.5, mb.mine and Color3.new(1, 1, 1) or UI.INK)
			table.insert(dots, d)
		end
	end
end

function RaceView.add(desc: { [string]: any }, view: TrackView.View)
	local id = tonumber(desc.id) or 0
	local old = races[id]
	if old then
		old.removed = true
		old.folder:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Race" .. id
	folder.Parent = marblesFolder()
	local rec: Rec = {
		id = id,
		desc = desc,
		kind = tostring(desc.kind),
		view = view,
		td = view.td,
		goTime = tonumber(desc.goTime) or now(),
		marbles = {},
		snaps = {},
		events = {},
		myIdx = nil,
		done = desc.done == true,
		results = desc.results,
		photo = false,
		photoShown = false,
		offset = 0,
		slow = false,
		slowRate = 1,
		slowUntil = 0,
		slowKind = "",
		slowDone = false,
		folder = folder,
		renderSim = 0,
		lights = -1,
		gp = desc.gp == true,
		reward = nil,
		resultsShown = desc.done == true,
		myFinished = false,
		glowStart = nil,
		perfects = 0,
		leaderIdx = 0,
		removed = false,
	}
	for _, ent in ipairs((desc.entrants or {}) :: { { [string]: any } }) do
		local mb = buildMarble(rec, ent)
		rec.marbles[mb.idx] = mb
		if mb.mine then
			rec.myIdx = mb.idx
		end
	end
	races[id] = rec
	TrackView.gate(view, false)
	TrackView.lights(view, 0)
	if rec.myIdx and not rec.done then
		-- my race: camera on the start grid, then chase cam at GO
		preview = nil
		setFocus(rec)
		setCam("start")
		results.Visible = false
		perfectLabel.Text = ""
		if rec.gp then
			UI.banner("🏁 GRAND PRIX! 2x COINS!", "purple", 2.2)
		elseif rec.kind == "practice" then
			UI.banner("WARM-UP HEAT!", "sky", 1.8)
		end
	elseif not myRace() and rec.kind ~= "practice" then
		setFocus(rec)
	end
end

function RaceView.event(raceId: number, t: number, kind: string, ...: any)
	local rec = races[raceId]
	if not rec then
		return
	end
	if kind == "remove" then
		rec.removed = true
		races[raceId] = nil
		rec.folder:Destroy()
		if focus == rec then
			local nextRec = myRace()
			if not nextRec then
				for _, r in pairs(races) do
					if r.kind ~= "practice" then
						nextRec = r
					end
				end
			end
			setFocus(nextRec)
			if camMode ~= "free" and camMode ~= "preview" and (not nextRec or not nextRec.myIdx) then
				freeCamera()
			end
		end
		return
	end
	local ev = { t, kind, ... }
	local idx = tonumber(ev[3]) or 0
	local mb = rec.marbles[idx]
	if mb and mb.mine and (kind == "boost" or kind == "miss") then
		handleEvent(rec, ev, true) -- my own taps answer right away
	end
	table.insert(rec.events, ev)
end

function RaceView.finish(raceId: number, res: { { [string]: any } }, photo: boolean)
	local rec = races[raceId]
	if not rec then
		return
	end
	rec.done = true
	rec.results = res
	rec.photo = rec.photo or photo == true
	local mine = rec.myIdx ~= nil
	task.delay(1.2, function()
		if not rec.removed and (mine or focus == rec) then
			showResults(rec)
			showReward(rec)
		end
		local cb = RaceView.onRaceOver
		if cb and mine then
			cb(rec.kind == "practice")
		end
	end)
end

function RaceView.reward(raceId: number, info: { [string]: any })
	local rec = races[raceId]
	if rec then
		rec.reward = info
		if rec.resultsShown then
			showReward(rec)
		end
	end
	local cb = RaceView.onReward
	if cb then
		task.spawn(cb, raceId, info)
	end
end

-- Pick-phase flyover of the freshly built track.
function RaceView.preview(view: TrackView.View?, endsAt: number)
	if myRace() then
		return
	end
	if not view then
		preview = nil
		if camMode == "preview" then
			freeCamera()
		end
		return
	end
	preview = { view = view, t0 = os.clock(), endsAt = endsAt }
	setCam("preview")
end

function RaceView.snap(b: buffer)
	onSnap(b)
end

function RaceView.busy(): boolean
	return myRace() ~= nil
end

function RaceView.hideResults()
	results.Visible = false
end

-- Boost input -----------------------------------------------------------------------------------------------------
local lastTap = 0
local function tap()
	local rec = myRace()
	if not rec or rec.myFinished or not rec.myIdx then
		return
	end
	local t = os.clock()
	if t - lastTap < 0.2 then
		return
	end
	lastTap = t
	UI.punch(boostBtn, -0.12)
	local clientTime = rec.goTime + rec.renderSim
	boostRemote:FireServer(rec.id, clientTime)
end
boostBtn.MouseButton1Down:Connect(tap)

local bound = false
local function bindKeys(on: boolean)
	if on == bound then
		return
	end
	bound = on
	if on then
		ContextActionService:BindActionAtPriority("MarbleBoost", function(_name, state, _input)
			if state == Enum.UserInputState.Begin then
				tap()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.E, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2)
	else
		ContextActionService:UnbindAction("MarbleBoost")
	end
end

camBtn.button.MouseButton1Click:Connect(function()
	local rec = focus
	if not rec then
		return
	end
	local order: { string }
	if rec.myIdx and not rec.myFinished then
		order = { "follow", "leader", "overview", "free" }
	else
		order = { "leader", "overview", "finish", "free" }
	end
	local i = table.find(order, camMode) or 0
	local nextMode = order[i % #order + 1]
	setCam(nextMode)
	local names = { follow = "🎥 FOLLOW YOU", leader = "🎥 LEADER CAM", overview = "🎥 BIRD'S EYE", finish = "🎥 FINISH LINE", free = "🚶 WALK" }
	UI.toast(names[nextMode] or nextMode, "purple", 1.2)
end)

-- Render loop -----------------------------------------------------------------------------------------------------
local partsBuf: { BasePart } = {}
local cfBuf: { CFrame } = {}

local function place(rec: Rec, mb: MB, list: { BasePart }, cfs: { CFrame })
	local td = rec.td
	local s = math.max(0, mb.s)
	local x, y, z = Track.place(td, s, mb.u, mb.h, RAD)
	local _, _, _, rx, ry, rz, ux, uy, uz = Track.at(td, s)
	if Track.tagAt(td, s) == TAG.DROP then
		ux, uy, uz = 0, 1, 0
	end
	local pos = V3(x, y, z)
	mb.pos = pos
	local right = V3(rx, ry, rz)
	local up = V3(ux, uy, uz)
	if right.Magnitude < 0.01 or up.Magnitude < 0.01 then
		right, up = V3(1, 0, 0), V3(0, 1, 0)
	end
	local base = CFrame.fromMatrix(pos, right.Unit, up.Unit):Orthonormalize()
	local rolled = base * CFrame.Angles(-s / RAD, 0, 0)
	local b = mb.built
	for i, p in ipairs(b.parts) do
		table.insert(list, p)
		if p == b.glow then
			table.insert(cfs, base)
		else
			table.insert(cfs, rolled * b.offsets[i])
		end
	end
end

local function updateGlow(rec: Rec, mb: MB, t: number)
	local f = mb.f
	local glowing = hasFlag(f, 1) and not hasFlag(f, 4)
	local boosting = hasFlag(f, 2) or hasFlag(f, 32)
	local magnet = hasFlag(f, 8)
	local g = mb.built.glow
	local state = glowing and 1 or (boosting and 2 or (magnet and 3 or 0))
	if glowing then
		local base = mb.mine and 0.3 or 0.62
		g.Transparency = base + 0.18 * math.sin(t * 18)
	end
	if state ~= mb.glowState then
		mb.glowState = state
		if state == 1 then
			g.Color = Color3.fromRGB(255, 225, 60)
			if mb.mine then
				rec.glowStart = rec.renderSim
				Sfx.play("beep", 0.25, 1.6)
			end
		elseif state == 2 then
			g.Color = Color3.fromRGB(255, 140, 40)
			g.Transparency = 0.72
		elseif state == 3 then
			g.Color = Color3.fromRGB(255, 70, 90)
			g.Transparency = 0.8
		else
			g.Transparency = 1
		end
		mb.boostTrail.Enabled = boosting
	end
end

-- Hud's right column (Daily/GP/Luck/2x/Music) sits under the BOOST meter on phone-height screens: hide it while racing.
local sideCol: GuiObject? = nil
local function showSide(on: boolean)
	if not sideCol then
		sideCol = root:FindFirstChild("Side") :: GuiObject?
	end
	local sc = sideCol
	if sc and sc.Visible ~= on then
		sc.Visible = on
	end
end

local function updateRaceUi(rec: Rec?)
	if not rec then
		raceUi.Visible = false
		camBtn.button.Visible = false
		bindKeys(false)
		showSide(true)
		return
	end
	raceUi.Visible = true
	camBtn.button.Visible = true
	local td = rec.td
	local total = math.max(1, td.finishS)
	-- order for places
	local order = table.clone(rec.marbles)
	table.sort(order, function(a: MB, b: MB)
		if a.finished ~= b.finished then
			return a.finished
		end
		if a.finished then
			return a.place < b.place
		end
		return a.s > b.s
	end)
	local myPlace = 0
	for i, mb in ipairs(order) do
		if mb.mine then
			myPlace = i
		end
	end
	for i, mb in ipairs(rec.marbles) do
		local d = dots[i]
		if d then
			d.Position = UDim2.fromScale(math.clamp(mb.s / total, 0, 1), 0.5)
		end
	end
	local racing = rec.myIdx ~= nil and not rec.myFinished
	local inGrid = now() < rec.goTime
	if rec.myIdx then
		placeLabel.Text = myPlace > 0 and (ordinal(myPlace) .. " / " .. #rec.marbles) or ""
		placeLabel.TextColor3 = myPlace == 1 and Color3.fromRGB(255, 214, 50) or Color3.new(1, 1, 1)
		watchLabel.Text = inGrid and "GET READY - TAP BOOST WHEN YOU GLOW!" or ""
	else
		placeLabel.Text = ""
		local leader = order[1]
		watchLabel.Text = leader and ("👀 WATCHING  ·  👑 " .. tostring(leader.ent.name)) or ""
	end
	boostBtn.Visible = racing
	meter.Visible = racing
	bindKeys(racing)
	showSide(not racing)
	if racing then
		local me = rec.marbles[rec.myIdx :: number]
		local glowing = me and hasFlag(me.f, 1)
		if glowing and rec.glowStart then
			local k = (rec.renderSim - (rec.glowStart :: number)) / RC.glowDur
			needle.Position = UDim2.fromScale(math.clamp(k, 0, 1), 0.5)
			boostColor((k >= PERF_A and k <= PERF_B) and "gold" or "yellow")
			boostBtn.Text = "TAP!"
			boostHint.Text = "⚡"
			meter.BackgroundTransparency = 0
		else
			needle.Position = UDim2.fromScale(0, 0.5)
			if os.clock() - lastTap > 0.6 then
				boostColor(inGrid and "grey" or "blue")
			end
			boostBtn.Text = "BOOST"
			meter.BackgroundTransparency = 0.3
		end
	end
end

RunService:BindToRenderStep("MarbleRaces", Enum.RenderPriority.Camera.Value, function(dt: number)
	table.clear(partsBuf)
	table.clear(cfBuf)
	local tNow = now()
	local clock = os.clock()
	for _, rec in pairs(races) do
		-- time warp (slow-mo, then catch up)
		if rec.slow then
			rec.offset += (1 - rec.slowRate) * dt
			local leader = leaderOf(rec)
			local passed = rec.slowKind == "photo" and leader ~= nil and leader.s > rec.td.finishS + 3
			if clock > rec.slowUntil or passed then
				rec.slow = false
			end
		elseif rec.offset > 0 then
			rec.offset = math.max(0, rec.offset - 0.75 * dt)
		end
		rec.offset = math.min(rec.offset, 3)
		local rt = tNow - RC.interpDelay - rec.offset
		rec.renderSim = math.max(0, rt - rec.goTime)
		interpolate(rec, rt)
		-- countdown lights + gate
		local tg = rec.goTime - rt
		local n = tg <= 0 and 4 or (tg <= 1 and 3 or (tg <= 2 and 2 or (tg <= 3 and 1 or 0)))
		if n ~= rec.lights then
			local first = rec.lights == -1
			rec.lights = n
			TrackView.lights(rec.view, n)
			if n == 4 then
				TrackView.gate(rec.view, true)
			end
			if not first and focus == rec then
				if n == 4 then
					Sfx.play("whoosh", 0.6, 1)
					if rec.myIdx then
						UI.banner("GO!", "green", 1)
						UI.shake(0.3)
						if camMode == "start" then
							setCam("follow")
						end
					end
				elseif n > 0 then
					Sfx.play("beep", 0.5, n == 3 and 1.2 or 1)
					if rec.myIdx then
						UI.banner(tostring(4 - n), n == 3 and "yellow" or "red", 0.7)
					end
				end
			end
		end
		-- photo finish detection on the rendered view
		if not rec.slowDone and not rec.slow and focus == rec and tg < 0 then
			local a, b = -1, -1
			for _, mb in ipairs(rec.marbles) do
				if not hasFlag(mb.f, 4) then
					if mb.s > a then
						a, b = mb.s, a
					elseif mb.s > b then
						b = mb.s
					end
				end
			end
			local toGo = rec.td.finishS - a
			if a > 0 and b > 0 and toGo > 1.5 and toGo < 16 and a - b < 2.4 then
				rec.slowDone = true
				startSlow(rec, "photo", 0.26, 3.2)
				if camMode ~= "free" then
					setCam("finish")
				end
				UI.banner("IT'S CLOSE...", "white", 1.2)
			end
		end
		-- events due at this render time
		local evs = rec.events
		while #evs > 0 and (tonumber(evs[1][1]) or 0) <= rec.renderSim do
			local ev = table.remove(evs, 1) :: { any }
			handleEvent(rec, ev, false)
		end
		for _, mb in ipairs(rec.marbles) do
			place(rec, mb, partsBuf, cfBuf)
			updateGlow(rec, mb, clock)
			if hasFlag(mb.f, 4) and not mb.finished then
				mb.finished = true
			end
		end
	end
	if #partsBuf > 0 then
		workspace:BulkMoveTo(partsBuf, cfBuf, Enum.BulkMoveMode.FireCFrameChanged)
	end
	-- FOV eases back after boost kicks
	if camMode ~= "free" then
		local targetFov = camMode == "finish" and 55 or 70
		camera.FieldOfView += (targetFov - camera.FieldOfView) * (1 - exp(-dt * 3))
	end
	updateCamera(dt)
	updateRaceUi(focus)
end)

-- Make sure a respawn never leaves the camera stuck.
player.CharacterAdded:Connect(function()
	if camMode == "free" then
		task.defer(freeCamera)
	end
end)

return RaceView

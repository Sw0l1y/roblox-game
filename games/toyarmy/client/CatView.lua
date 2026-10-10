-- The house cat, drawn and animated on each client. It sleeps on the bed (breathing, Zzz), and when the server
-- sends a visit plan (keyframes in server time) it wakes, jumps down, stomps to the busiest zones and swipes
-- the armies there flying, then curls back up. The hero mesh replaces the primitive cat when it exists.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local World = require(Shared:WaitForChild("World"))
local Toys = require(Shared:WaitForChild("Toys"))
local ClientLib = ReplicatedStorage:WaitForChild("ClientLib")
local Fx = require(ClientLib:WaitForChild("Fx"))
local Sfx = require(ClientLib:WaitForChild("Sfx"))
local UI = require(ClientLib:WaitForChild("UI"))

local CatView = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local RAD = math.rad
local C = Config.C

type Item = { part: BasePart, group: string, rel: CFrame }
type Key = { t: number, p: Vector3, y: number, a: string }

local model: Model
local items: { Item } = {}
local parts: { BasePart } = {}
local eyesOpen: { BasePart } = {}
local eyesShut: { BasePart } = {}
local zzz: BillboardGui? = nil
local alert: BillboardGui? = nil
local keys: { Key }? = nil
local hooks: { [string]: (...any) -> () } = {}

-- Joints in model space (pivot at the floor under the body, facing -Z).
local JOINTS: { [string]: Vector3 } = {
	legFL = V(-7, 15, -14),
	legFR = V(7, 15, -14),
	legBL = V(-8, 15, 12),
	legBR = V(8, 15, 12),
	tail = V(0, 22, 19),
	head = V(0, 28, -18),
}

local function add(group: string, p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = model
	table.insert(items, { part = p, group = group, rel = p.CFrame })
	table.insert(parts, p)
end

local function ball(group: string, pos: Vector3, size: Vector3, color: Color3, rot: CFrame?): BasePart
	local p = World.part({ Name = "Cat", Shape = Enum.PartType.Ball, CFrame = CF(pos) * (rot or CFrame.identity), Size = size, Color = color })
	add(group, p)
	return p
end

local function box(group: string, cf: CFrame, size: Vector3, color: Color3): BasePart
	local p = World.part({ Name = "Cat", CFrame = cf, Size = size, Color = color, CastShadow = false })
	add(group, p)
	return p
end

local function legCyl(group: string, x: number, z: number)
	local p = World.part({
		Name = "Leg",
		Shape = Enum.PartType.Cylinder,
		CFrame = CF(x, 8.5, z) * ANG(0, 0, RAD(90)),
		Size = V(14, 7, 7),
		Color = C.catFur,
	})
	add(group, p)
	ball(group, V(x, 2.6, z - 1), V(8, 5.2, 9.5), C.catCream)
	box(group, CF(x, 9, z - 3.3), V(7.2, 1.2, 0.6), C.catStripe)
end

local function buildPrimitive()
	-- body, belly, chest
	ball("body", V(0, 20, 0), V(24, 21, 40), C.catFur)
	ball("body", V(0, 15.5, -2), V(18, 13, 30), C.catCream)
	ball("body", V(0, 22, -15), V(20, 20, 16), C.catCream)
	for i, z in ipairs({ -7, 1, 9 }) do
		ball("body", V(0, 25.5 - i * 0.4, z), V(24.6, 9, 4.2), C.catStripe)
	end
	-- legs
	legCyl("legFL", -7, -14)
	legCyl("legFR", 7, -14)
	legCyl("legBL", -8, 12)
	legCyl("legBR", 8, 12)
	-- tail: a curl of balls rising behind
	local tail = { V(0, 22, 20), V(0, 26, 24), V(0, 31, 26.5), V(0, 36, 27.5), V(0, 40.5, 26.5) }
	for i, p in ipairs(tail) do
		ball("tail", p, V(6.4 - i * 0.3, 6.4 - i * 0.3, 6.4 - i * 0.3), i == #tail and C.catCream or (i % 2 == 0 and C.catStripe or C.catFur))
	end
	-- head
	ball("head", V(0, 34, -24), V(22, 19, 19), C.catFur)
	ball("head", V(0, 29.5, -32), V(12, 8, 8), C.catCream)
	ball("head", V(0, 32.4, -35.6), V(2.6, 1.9, 1.6), C.catPink)
	box("head", CF(0, 40.5, -27), V(8, 1.4, 12), C.catStripe)
	for _, sx in ipairs({ -1, 1 }) do
		local eye = ball("head", V(sx * 5, 36, -32.4), V(4.2, 5, 2.2), C.catEye)
		eye.Material = Enum.Material.Neon
		table.insert(eyesOpen, eye)
		table.insert(eyesOpen, ball("head", V(sx * 5, 36, -33.5), V(1.4, 3.8, 0.8), C.ink))
		table.insert(eyesShut, box("head", CF(sx * 5, 35.4, -33.4) * ANG(0, 0, RAD(sx * 8)), V(4.6, 0.8, 0.6), C.ink))
		-- ears
		for _, w in ipairs(Toys.tri(model, CF(sx * 7, 45, -24) * ANG(0, 0, RAD(-sx * 14)), 8, 9, 2.4, C.catFur)) do
			add("head", w)
		end
		for _, w in ipairs(Toys.tri(model, CF(sx * 7, 44.4, -25.3) * ANG(0, 0, RAD(-sx * 14)), 4.8, 5.6, 0.4, C.catPink)) do
			add("head", w)
		end
		-- whiskers
		for k = -1, 1, 2 do
			box("head", CF(sx * 10, 30.6 + k * 0.9, -33) * ANG(0, 0, RAD(sx * k * 8)), V(9, 0.3, 0.3), C.white)
		end
	end
end

local function build()
	model = Instance.new("Model")
	model.Name = "HouseCat"
	local hero = Toys.heroMesh("Cat")
	if hero then
		hero.CFrame = CF(0, hero.Size.Y / 2, 0)
		add("body", hero)
	else
		buildPrimitive()
	end
	model.WorldPivot = CFrame.identity
	model.Parent = workspace
	local anchor = World.part({ Name = "CatLabelAnchor", CFrame = CF(0, 52, -24), Size = V(1, 1, 1), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	add("head", anchor)
	zzz = World.label(anchor, "💤 z z Z", { width = 10, height = 3, offset = V(0, 3, 0), maxDistance = 400, color = C.white })
	alert = World.label(anchor, "❗", { width = 6, height = 6, offset = V(0, 5, 0), maxDistance = 600, color = C.red, onTop = true })
	local a = alert
	if a then
		a.Enabled = false
	end
end

local function setEyes(open: boolean)
	for _, p in ipairs(eyesOpen) do
		p.Transparency = open and 0 or 1
	end
	for _, p in ipairs(eyesShut) do
		p.Transparency = open and 1 or 0
	end
	local z = zzz
	if z then
		z.Enabled = not open
	end
end

local function jointCF(group: string, angle: number, axis: string?): CFrame
	local j = JOINTS[group]
	if not j or angle == 0 then
		return CFrame.identity
	end
	local rot = axis == "y" and ANG(0, angle, 0) or ANG(angle, 0, 0)
	return CF(j) * rot * CF(-j)
end

-- Pose the whole cat: base CFrame plus joint angles.
type Pose = { legs: { number }, tail: number, head: number, tuck: number }
local function apply(base: CFrame, pose: Pose)
	local g: { [string]: CFrame } = {
		body = CFrame.identity,
		legFL = jointCF("legFL", pose.legs[1] + pose.tuck),
		legFR = jointCF("legFR", pose.legs[2] + pose.tuck),
		legBL = jointCF("legBL", pose.legs[3] - pose.tuck),
		legBR = jointCF("legBR", pose.legs[4] - pose.tuck),
		tail = jointCF("tail", pose.tail, "y"),
		head = jointCF("head", pose.head),
	}
	local cfs: { CFrame } = {}
	local ps: { BasePart } = {}
	for i, it in ipairs(items) do
		ps[i] = it.part
		cfs[i] = base * (g[it.group] or CFrame.identity) * it.rel
	end
	workspace:BulkMoveTo(ps, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function lerpAngle(a: number, b: number, k: number): number
	local d = (b - a + math.pi) % (math.pi * 2) - math.pi
	return a + d * k
end

local sleepBase = CF(Config.Cat.bedPos + V(0, -8, 0)) * ANG(0, math.atan2(-1, -0.4), 0)
local lastYaw = 0
local landed: { [number]: boolean } = {}
local swiped: { [number]: boolean } = {}

local function step()
	local t = os.clock()
	local ks = keys
	if not ks then
		-- asleep on the bed: slow breathing and a lazy tail
		local breathe = math.sin(t * 1.6) * 0.35
		apply(sleepBase + V(0, breathe, 0), { legs = { 0, 0, 0, 0 }, tail = math.sin(t * 0.7) * 0.25, head = 0.35, tuck = 1.1 })
		return
	end
	local st = now()
	local i = 1
	while i < #ks and ks[i + 1].t <= st do
		i += 1
	end
	local k = ks[i]
	local nk = ks[i + 1]
	local dur = nk and (nk.t - k.t) or 1
	local f = nk and math.clamp((st - k.t) / dur, 0, 1) or 1
	local yaw = nk and lerpAngle(k.y, nk.y, math.min(1, (st - k.t) / 0.35)) or k.y
	if k.a == "walk" and nk then
		yaw = k.y
	end
	lastYaw = yaw
	local pos = k.p
	local pose: Pose = { legs = { 0, 0, 0, 0 }, tail = math.sin(t * 3) * 0.35, head = 0, tuck = 0 }
	if k.a == "wake" then
		pose.head = -0.15 + math.sin(t * 6) * 0.05
		pos = k.p + V(0, -8 * (1 - f), 0)
	elseif k.a == "jump" and nk then
		pos = k.p:Lerp(nk.p, f) + V(0, math.sin(f * math.pi) * 26, 0)
		pose.tuck = 0.6
		pose.head = -0.2
		if f > 0.97 and not landed[i] then
			landed[i] = true
			local d = (camera.CFrame.Position - nk.p).Magnitude
			if d < 160 then
				UI.shake(math.clamp(1.2 - d / 160, 0.2, 1))
				Sfx.play("thud", 0.7, 0.7)
			end
			Fx.shockwave(nk.p + V(0, 0.5, 0), C.catFur, 26)
		end
	elseif k.a == "walk" and nk then
		pos = k.p:Lerp(nk.p, f)
		local s = math.sin(t * 9) * 0.55
		pose.legs = { s, -s, -s, s }
		pos += V(0, math.abs(math.sin(t * 9)) * 1.2, 0)
	elseif k.a == "swipe" then
		local e = st - k.t
		local paw = 0
		if e < 1.0 then
			paw = -1.7 * (e / 1.0)
		elseif e < 1.25 then
			paw = -1.7 + 2.0 * ((e - 1.0) / 0.25)
		elseif e < 1.9 then
			paw = 0.3
		else
			paw = 0.3 * (1 - math.clamp((e - 1.9) / 0.9, 0, 1))
		end
		pose.legs = { 0, paw, 0, 0 }
		pose.head = -0.25
		pose.tail = math.sin(t * 10) * 0.6
		if e >= 1.25 and not swiped[i] then
			swiped[i] = true
			local d = (camera.CFrame.Position - k.p).Magnitude
			if d < 220 then
				UI.shake(math.clamp(1.5 - d / 200, 0.3, 1.5))
			end
			Sfx.play("swipe", 0.8, 0.8)
			Sfx.play("thud", 0.6, 0.6)
		end
	elseif k.a == "sleep" then
		local base = CF(k.p + V(0, -8, 0)) * ANG(0, yaw, 0)
		sleepBase = base
		apply(base, { legs = { 0, 0, 0, 0 }, tail = 0, head = 0.35, tuck = 1.1 })
		return
	end
	apply(CF(pos) * ANG(0, yaw, 0), pose)
end

local function startRun(ks: { Key }, by: string)
	keys = ks
	landed = {}
	swiped = {}
	setEyes(true)
	local a = alert
	if a then
		a.Enabled = true
		task.delay(4, function()
			a.Enabled = false
		end)
	end
	Sfx.play("reveal", 0.6, 0.7)
	if by ~= "" then
		UI.banner("🐱 " .. string.upper(by) .. " CALLED THE CAT!", "pink", 3)
	else
		UI.banner("🐱 THE CAT IS AWAKE!", "orange", 3)
	end
	UI.flash("orange", 0.6)
	local cb = hooks.run
	if cb then
		cb(by)
	end
end

local function finish()
	keys = nil
	setEyes(false)
	local cb = hooks.done
	if cb then
		cb()
	end
end

-- hooks: run(by), done(), warn(at), swat(zoneId, n), queued()
function CatView.init(h: { [string]: (...any) -> () })
	hooks = h
	build()
	setEyes(false)
	step()
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		if keys then
			step()
		else
			acc += dt
			if acc >= 0.1 then
				acc = 0
				step()
			end
		end
	end)
	Net.event("Cat").OnClientEvent:Connect(function(kind, a, b, c)
		if kind == "run" and type(a) == "table" then
			startRun(a, tostring(b or ""))
		elseif kind == "done" then
			finish()
		elseif kind == "warn" then
			Sfx.play("beep", 0.5, 0.8)
			UI.banner("🐱 THE CAT IS WAKING UP! 🐱", "orange", 2.5)
			local cb = hooks.warn
			if cb then
				cb(a)
			end
		elseif kind == "swat" then
			local pos = typeof(b) == "Vector3" and b or nil
			if pos then
				Fx.shockwave(pos + V(0, 1, 0), C.catFur, 40)
				Fx.burst(pos + V(0, 6, 0), { C.catFur, C.catCream, C.white }, 18, 1.6)
			end
			local cb = hooks.swat
			if cb then
				cb(a, c)
			end
		elseif kind == "pickup" then
			local pos = typeof(a) == "Vector3" and a or nil
			if pos then
				Fx.burst(pos, { C.lime, C.yellow }, 10, 1)
				Fx.popup(pos + V(0, 3, 0), "🎒 " .. tostring(b), C.lime, 0.9)
			end
			Sfx.play("pop", 0.4, 1.2)
		elseif kind == "queued" then
			UI.toast("🐱 The cat is busy: your call is next in line!", "pink")
		end
	end)
	local _ = { lastYaw, player }
end

return CatView

-- Paid strikes, drawn on every client from the server's plan (Net "Strike": key, { by, team, zone, t, from } or,
-- for the dog, { path, hits }). Every visual is timed to land at the server time the hit happens, so the toys go
-- flying (Arena, Battle "strike") exactly when the rubber band, balloon, rocket, flashlight beam or dog arrives.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local World = require(Shared:WaitForChild("World"))
local ClientLib = ReplicatedStorage:WaitForChild("ClientLib")
local Fx = require(ClientLib:WaitForChild("Fx"))
local Sfx = require(ClientLib:WaitForChild("Sfx"))
local UI = require(ClientLib:WaitForChild("UI"))

local StrikeView = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local rng = Random.new()
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local C = Config.C

local folder = Instance.new("Folder")
folder.Name = "Strikes"
folder.Parent = workspace

-- Per-frame steps: each returns false when it is finished.
local steps: { (number) -> boolean } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function near(pos: Vector3, dist: number): boolean
	return (camera.CFrame.Position - pos).Magnitude < dist
end

local function part(props: { [string]: any }): BasePart
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	props.CastShadow = false
	props.Parent = props.Parent or folder
	return World.part(props)
end

-- A point on a hop from p0 to p1 (a = 0..1) peaking `h` studs above the straight line.
local function arc(p0: Vector3, p1: Vector3, a: number, h: number): Vector3
	return p0:Lerp(p1, a) + V(0, 4 * h * a * (1 - a), 0)
end

-- Fly a part along an arc between server times t0 and t1, nose first (spin = tumble instead), then land().
local function fly(p: BasePart, p0: Vector3, p1: Vector3, t0: number, t1: number, h: number, spin: boolean, land: (() -> ())?)
	p.Transparency = 1
	local base = p:GetAttribute("Alpha") or 0
	table.insert(steps, function(t: number): boolean
		if t < t0 then
			return true
		end
		local a = math.clamp((t - t0) / math.max(0.05, t1 - t0), 0, 1)
		local pos = arc(p0, p1, a, h)
		local ahead = arc(p0, p1, math.min(1, a + 0.02), h)
		p.Transparency = base :: number
		if spin then
			p.CFrame = CF(pos) * ANG(t * 9, t * 7, 0)
		elseif (ahead - pos).Magnitude > 0.01 then
			p.CFrame = CFrame.lookAt(pos, ahead)
		end
		if a >= 1 then
			p:Destroy()
			if land then
				task.spawn(land)
			end
			return false
		end
		return true
	end)
end

local function boom(pos: Vector3, colors: { Color3 }, size: number, sound: string?)
	Fx.burst(pos + V(0, 3, 0), colors, math.floor(8 + size * 0.5), 1 + size / 30)
	Fx.shockwave(pos + V(0, 0.6, 0), colors[1], size)
	if near(pos, 260) then
		Sfx.play(sound or "pop", 0.45, rng:NextNumber(0.6, 0.9))
	end
end

local function zonePos(id: string): Vector3?
	local def = Config.ZoneById[id]
	return def and def.pos or nil
end

local function scatter(c: Vector3, r: number): Vector3
	local a = rng:NextNumber(0, math.pi * 2)
	local d = rng:NextNumber(0, r)
	return c + V(math.cos(a) * d, 0, math.sin(a) * d)
end

-- The strikes ---------------------------------------------------------------------------------------------------------

local function rubber(from: Vector3, c: Vector3, t: number)
	local cols = { C.orange, Color3.fromRGB(255, 120, 160), C.yellow }
	for i = 1, 3 do
		local band = part({ Name = "RubberBand", Shape = Enum.PartType.Cylinder, Size = V(0.35, 3.4, 3.4), Color = cols[i] })
		local t1 = t + (i - 2) * 0.08
		local hit = scatter(c, 8) + V(0, 2, 0)
		fly(band, from + V(0, 5, 0), hit, t1 - 0.9, t1, 10, true, function()
			boom(hit, { cols[i], C.white }, 10)
		end)
	end
end

local function balloon(from: Vector3, c: Vector3, t: number)
	local b = part({ Name = "WaterBalloon", Shape = Enum.PartType.Ball, Size = V(9, 10, 9), Color = Color3.fromRGB(70, 150, 255), Material = Enum.Material.Glass })
	b:SetAttribute("Alpha", 0.25)
	fly(b, from + V(0, 8, 0), c + V(0, 4, 0), t - 1.4, t, 46, true, function()
		local blue = Color3.fromRGB(90, 170, 255)
		boom(c, { blue, C.white, Color3.fromRGB(170, 220, 255) }, 34, "pop")
		Fx.burst(c + V(0, 6, 0), { blue, C.white }, 24, 2)
		local puddle = part({ Name = "Puddle", Shape = Enum.PartType.Cylinder, CFrame = CF(c + V(0, 0.3, 0)) * ANG(0, 0, math.pi / 2), Size = V(0.2, 30, 30), Color = blue, Material = Enum.Material.Glass, Transparency = 0.45 })
		UI.tween(puddle, 4, { Transparency = 1 })
		task.delay(4.2, function()
			puddle:Destroy()
		end)
	end)
end

local function plane(c: Vector3, t: number, team: string)
	local dir = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
	dir = dir.Magnitude > 0.1 and dir.Unit or V(1, 0, 0)
	local over = t - 0.9 -- above the zone: the paratroopers jump
	local p0, p1 = c - dir * 300 + V(0, 58, 0), c + dir * 300 + V(0, 58, 0)
	local m = Instance.new("Model")
	m.Name = "RCPlane"
	local col = Config.teamColor(team)
	local body = part({ Name = "Body", Size = V(4, 4, 18), Color = col, Parent = m })
	local rel: { [BasePart]: CFrame } = {}
	local function add(name: string, cf: CFrame, size: Vector3, color: Color3)
		local p = part({ Name = name, Size = size, Color = color, Parent = m })
		rel[p] = cf
	end
	add("Wing", CF(0, 0.6, -1), V(26, 0.6, 5), C.white)
	add("Tail", CF(0, 1.5, 8), V(9, 0.5, 3), C.white)
	add("Fin", CF(0, 3.4, 8), V(0.5, 4, 3), col)
	add("Prop", CF(0, 0, -9.4), V(7, 0.6, 0.4), C.ink)
	add("Nose", CF(0, 0, -9.2), V(2.4, 2.4, 0.8), C.yellow)
	m.PrimaryPart = body
	m.Parent = folder
	local dropped = false
	local t0, t1 = over - 1.6, over + 1.6
	table.insert(steps, function(tn: number): boolean
		local a = math.clamp((tn - t0) / (t1 - t0), 0, 1)
		local pos = p0:Lerp(p1, a)
		local cf = CFrame.lookAt(pos, pos + dir) * ANG(0, 0, math.sin(tn * 3) * 0.15)
		body.CFrame = cf
		for p, r in pairs(rel) do
			p.CFrame = cf * r * (p.Name == "Prop" and ANG(0, 0, tn * 40) or CFrame.identity)
		end
		if not dropped and tn >= over then
			dropped = true
			if near(c, 300) then
				Sfx.play("whoosh", 0.4, 1.4)
			end
			for i = 1, 4 do
				local chute = part({ Name = "Chute", Shape = Enum.PartType.Ball, Size = V(5, 3, 5), Color = C.white })
				local land = scatter(c, 9) + V(0, 2, 0)
				fly(chute, pos + V(0, -2, 0), land + V(0, 3, 0), over + i * 0.05, t + i * 0.05, -2, false, function()
					Fx.popup(land + V(0, 5, 0), "🪂", col, 0.8)
				end)
			end
		end
		if a >= 1 then
			m:Destroy()
			return false
		end
		return true
	end)
end

local function rockets(from: Vector3, c: Vector3, t: number)
	for i = 1, 6 do
		local r = part({ Name = "Rocket", Shape = Enum.PartType.Cylinder, Size = V(5, 1.4, 1.4), Color = i % 2 == 0 and C.red or C.white })
		local flame = part({ Name = "Flame", Shape = Enum.PartType.Ball, Size = V(1.6, 1.6, 1.6), Color = C.orange, Material = Enum.Material.Neon, Parent = r })
		local hit = scatter(c, 12)
		local t1 = t - 0.3 + i * 0.1
		local p0 = from + V(rng:NextNumber(-3, 3), 6, rng:NextNumber(-3, 3))
		table.insert(steps, function(tn: number): boolean
			if r.Parent and tn >= t1 - 1.6 then
				local a = math.clamp((tn - (t1 - 1.6)) / 1.6, 0, 1)
				local pos = arc(p0, hit, a, 34)
				local ahead = arc(p0, hit, math.min(1, a + 0.02), 34)
				if (ahead - pos).Magnitude > 0.01 then
					r.CFrame = CFrame.lookAt(pos, ahead) * ANG(0, math.pi / 2, 0)
					flame.CFrame = r.CFrame * CF(2.8, 0, 0)
				end
			end
			return r.Parent ~= nil
		end)
		r.Transparency = 0
		r.CFrame = CF(0, -500, 0)
		flame.CFrame = CF(0, -500, 0)
		task.delay(math.max(0, t1 - now()), function()
			r:Destroy()
			boom(hit, { C.orange, C.yellow, C.red }, 16, "thud")
		end)
	end
	if near(c, 260) then
		task.delay(math.max(0, t - 0.2 - now()), function()
			UI.shake(0.6)
		end)
	end
end

local function flashlight(c: Vector3, t: number)
	local side = V(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
	side = side.Magnitude > 0.1 and side.Unit or V(1, 0, 0)
	local head = c + side * 46 + V(0, 74, 0)
	local cf = CFrame.lookAt(head, c)
	local torch = part({ Name = "Flashlight", Shape = Enum.PartType.Cylinder, Size = V(26, 8, 8), CFrame = cf * CF(0, 0, 13) * ANG(0, math.pi / 2, 0), Color = C.yellow, Transparency = 1 })
	local lens = part({ Name = "Lens", Shape = Enum.PartType.Cylinder, Size = V(1.2, 10, 10), CFrame = cf * ANG(0, math.pi / 2, 0), Color = C.white, Material = Enum.Material.Neon, Transparency = 1 })
	local a0 = Instance.new("Attachment")
	a0.Parent = lens
	local endPart = part({ Name = "BeamEnd", Size = V(1, 1, 1), CFrame = CF(c + V(0, 0.5, 0)), Transparency = 1 })
	local a1 = Instance.new("Attachment")
	a1.Parent = endPart
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 246, 190))
	beam.Transparency = NumberSequence.new(0.35, 0.75)
	beam.Width0, beam.Width1 = 8, 0.5
	beam.Enabled = false
	beam.Parent = lens
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Right
	light.Range = 60
	light.Angle = 45
	light.Brightness = 0
	light.Color = Color3.fromRGB(255, 240, 180)
	light.Parent = lens
	local t0, t2 = t - 1.4, t + 1.4
	local flashed = false
	table.insert(steps, function(tn: number): boolean
		if tn < t0 then
			return true
		end
		torch.Transparency = 0
		lens.Transparency = 0
		beam.Enabled = true
		local grow = math.clamp((tn - t0) / (t - t0), 0, 1)
		beam.Width1 = 0.5 + grow * 40
		light.Brightness = grow * 6
		if not flashed and tn >= t then
			flashed = true
			boom(c, { Color3.fromRGB(255, 246, 190), C.white, C.yellow }, 30, "magic")
			if near(c, 200) then
				UI.flash("yellow", 0.4)
			end
		end
		if tn >= t2 then
			torch:Destroy()
			lens:Destroy()
			endPart:Destroy()
			return false
		end
		return true
	end)
end

-- The dog: a big friendly puppy that runs in through the door, knocks every enemy zone over and runs back out.
local function dog(path: { { p: Vector3, t: number } }, hits: { { zone: string, t: number } })
	if #path < 2 then
		return
	end
	local m = Instance.new("Model")
	m.Name = "TheDog"
	local fur, dark = Color3.fromRGB(196, 140, 84), Color3.fromRGB(120, 78, 42)
	local items: { { p: BasePart, rel: CFrame, leg: number } } = {}
	local function add(name: string, rel: CFrame, size: Vector3, color: Color3, shape: Enum.PartType?, leg: number?)
		local p = part({ Name = name, Size = size, Color = color, Shape = shape or Enum.PartType.Block, Parent = m })
		table.insert(items, { p = p, rel = rel, leg = leg or 0 })
	end
	add("Body", CF(0, 17, 0), V(16, 12, 30), fur)
	add("Chest", CF(0, 16, -12), V(14, 12, 8), Color3.fromRGB(240, 220, 190))
	add("Head", CF(0, 27, -19), V(13, 12, 12), fur)
	add("Snout", CF(0, 24, -27), V(7, 5, 6), Color3.fromRGB(240, 220, 190))
	add("Nose", CF(0, 26, -30.2), V(3, 2.4, 1.4), C.ink)
	add("EyeL", CF(-3.4, 29.5, -25.2), V(1.8, 1.8, 0.6), C.ink)
	add("EyeR", CF(3.4, 29.5, -25.2), V(1.8, 1.8, 0.6), C.ink)
	add("EarL", CF(-7, 27, -18) * ANG(0, 0, 0.3), V(2, 10, 6), dark)
	add("EarR", CF(7, 27, -18) * ANG(0, 0, -0.3), V(2, 10, 6), dark)
	add("Tongue", CF(0, 21.4, -28) * ANG(0.4, 0, 0), V(3, 0.6, 4), Color3.fromRGB(255, 120, 150))
	add("Collar", CF(0, 21.5, -15), V(14.4, 2, 6), C.red)
	add("Tag", CF(0, 19.5, -18.4), V(2.4, 2.4, 0.4), C.gold)
	add("Tail", CF(0, 24, 16) * ANG(-0.7, 0, 0), V(3, 3, 12), fur, nil, 5)
	add("LegFL", CF(-5, 6, -11), V(4.5, 12, 4.5), fur, nil, 1)
	add("LegFR", CF(5, 6, -11), V(4.5, 12, 4.5), fur, nil, 2)
	add("LegBL", CF(-5, 6, 11), V(4.5, 12, 4.5), fur, nil, 2)
	add("LegBR", CF(5, 6, 11), V(4.5, 12, 4.5), fur, nil, 1)
	m.Parent = folder
	local barked: { [number]: boolean } = {}
	local yaw = 0
	local last = path[#path].t
	table.insert(steps, function(tn: number): boolean
		if tn < path[1].t then
			for _, it in ipairs(items) do
				it.p.CFrame = CF(0, -500, 0)
			end
			return true
		end
		-- where on the path are we
		local pos, moving = path[#path].p, false
		for i = 1, #path - 1 do
			local a, b = path[i], path[i + 1]
			if tn >= a.t and tn <= b.t then
				local f = (tn - a.t) / math.max(0.01, b.t - a.t)
				pos = a.p:Lerp(b.p, f)
				local d = Vector3.new(b.p.X - a.p.X, 0, b.p.Z - a.p.Z)
				if d.Magnitude > 0.5 then
					moving = true
					local want = math.atan2(-d.X, -d.Z)
					local diff = (want - yaw + math.pi) % (math.pi * 2) - math.pi
					yaw += diff * 0.25
				end
				break
			end
		end
		local bob = moving and math.abs(math.sin(tn * 14)) * 2 or 0
		local root = CF(pos + V(0, bob, 0)) * ANG(0, yaw, 0)
		local swing = moving and math.sin(tn * 14) * 0.6 or 0
		for _, it in ipairs(items) do
			local r = it.rel
			if it.leg == 1 or it.leg == 2 then
				local s = it.leg == 1 and swing or -swing
				r = r * CF(0, 6, 0) * ANG(s, 0, 0) * CF(0, -6, 0)
			elseif it.leg == 5 then
				r = r * ANG(0, math.sin(tn * 20) * 0.5, 0)
			end
			it.p.CFrame = root * r
		end
		for i, h in ipairs(hits) do
			if not barked[i] and tn >= h.t then
				barked[i] = true
				local zp = zonePos(h.zone) or pos
				Fx.popup(pos + V(0, 40, 0), "WOOF!", C.orange, 1.4)
				boom(V(zp.X, zp.Y, zp.Z), { fur, C.white, dark }, 34, "thud")
				if near(zp, 220) then
					UI.shake(1)
				end
			end
		end
		if tn > last then
			m:Destroy()
			return false
		end
		return true
	end)
end

-- Network -------------------------------------------------------------------------------------------------------------

local function onStrike(key: string, data: { [string]: any })
	local item = Config.Products[key]
	local by = tostring(data.by or "")
	local team = tostring(data.team or "Green")
	local from = typeof(data.from) == "Vector3" and data.from or Config.Spawn[team].pos
	local mineTeam = player:GetAttribute("Side") == team
	if key == "dog" then
		if type(data.path) ~= "table" or type(data.hits) ~= "table" then
			return
		end
		local path: { { p: Vector3, t: number } } = {}
		local rawPath: { any } = data.path :: any
		for _, w: any in ipairs(rawPath) do
			if type(w) == "table" and typeof(w.p) == "Vector3" and type(w.t) == "number" then
				table.insert(path, { p = w.p :: Vector3, t = w.t :: number })
			end
		end
		local hits: { { zone: string, t: number } } = {}
		local rawHits: { any } = data.hits :: any
		for _, h: any in ipairs(rawHits) do
			if type(h) == "table" and type(h.zone) == "string" and type(h.t) == "number" then
				table.insert(hits, { zone = h.zone :: string, t = h.t :: number })
			end
		end
		UI.banner("🐶 " .. string.upper(by) .. " LET THE DOG IN!", mineTeam and "gold" or "red", 3)
		Sfx.play("reveal", 0.6, 0.9)
		dog(path, hits)
		return
	end
	local c = type(data.zone) == "string" and zonePos(data.zone) or nil
	local t = tonumber(data.t) or now() + 1
	if not c then
		return
	end
	if key == "rubber" then
		rubber(from, c, t)
	elseif key == "balloon" then
		balloon(from, c, t)
	elseif key == "rcplane" then
		plane(c, t, team)
	elseif key == "rockets" then
		rockets(from, c, t)
	elseif key == "flashlight" then
		flashlight(c, t)
	end
	if item and (key == "rockets" or key == "flashlight") then
		UI.banner(item.glyph .. " " .. string.upper(item.name) .. "!", mineTeam and "gold" or "red", 2.2)
	end
end

function StrikeView.init()
	RunService.Heartbeat:Connect(function()
		if #steps == 0 then
			return
		end
		local t = now()
		for i = #steps, 1, -1 do
			local ok, keep = pcall(steps[i], t)
			if not ok or not keep then
				if not ok then
					warn("[StrikeView]", keep)
				end
				table.remove(steps, i)
			end
		end
	end)
	Net.event("Strike").OnClientEvent:Connect(function(key, data)
		if type(key) == "string" and type(data) == "table" then
			onStrike(key, data)
		end
	end)
end

return StrikeView

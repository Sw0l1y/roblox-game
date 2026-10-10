-- 3D effects drawn on the client only (no textures needed): part bursts, rising number popups,
-- expanding shockwave rings, and a sparkle ring around a model. The server triggers them with
-- Net.event("Fx"):FireAllClients(name, ...) and the client calls Fx[name](...).
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Fx = {}
local rng = Random.new()

local folder = Instance.new("Folder")
folder.Name = "ClientFx"
folder.Parent = workspace

local function tween(obj: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function bit(color: Color3, size: number, neon: boolean?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = Vector3.new(size, size, size)
	p.Parent = folder
	return p
end

-- Chunky confetti/debris burst: `n` little cubes and balls fly out and fall.
function Fx.burst(pos: Vector3, colors: { Color3 }, n: number?, power: number?)
	local count = n or 14
	local pw = power or 1
	for _ = 1, count do
		local p = bit(colors[rng:NextInteger(1, #colors)], rng:NextNumber(0.4, 0.9) * pw, rng:NextNumber() < 0.3)
		if rng:NextNumber() < 0.5 then
			p.Shape = Enum.PartType.Ball
		end
		p.CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.6, 1.6), rng:NextNumber(-1, 1)).Unit
		local up = pos + dir * rng:NextNumber(4, 9) * pw
		local t1 = rng:NextNumber(0.25, 0.4)
		tween(p, t1, { Position = up, Orientation = p.Orientation + Vector3.new(rng:NextNumber(-180, 180), rng:NextNumber(-180, 180), 0) })
		task.delay(t1, function()
			tween(p, 0.55, { Position = up - Vector3.new(0, 6 * pw, 0), Size = Vector3.new(0.05, 0.05, 0.05) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end)
		Debris:AddItem(p, t1 + 0.6)
	end
end

-- Flat neon ring that expands and fades (landing, level-up, launch).
function Fx.shockwave(pos: Vector3, color: Color3, radius: number?)
	local r = radius or 14
	local p = bit(color, 1, true)
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.3, 2, 2)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	p.Transparency = 0.15
	tween(p, 0.6, { Size = Vector3.new(0.3, r * 2, r * 2), Transparency = 1 })
	Debris:AddItem(p, 0.65)
end

-- Rising "+123" label at a world position.
function Fx.popup(pos: Vector3, text: string, color: Color3, size: number?)
	local anchor = bit(color, 0.1)
	anchor.Transparency = 1
	anchor.Position = pos
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(8 * (size or 1), 2.4 * (size or 1))
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 140
	bb.Adornee = anchor
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = Color3.fromRGB(28, 30, 48)
	s.Parent = l
	l.Parent = bb
	bb.Parent = anchor
	tween(anchor, 1.1, { Position = pos + Vector3.new(rng:NextNumber(-1, 1), 5, rng:NextNumber(-1, 1)) })
	task.delay(0.6, function()
		tween(l, 0.5, { TextTransparency = 1 })
		tween(s, 0.5, { Transparency = 1 })
	end)
	Debris:AddItem(anchor, 1.2)
end

-- Neon sparkles orbiting a point for a moment (rare reveal, upgrade).
function Fx.sparkle(pos: Vector3, color: Color3, radius: number?, seconds: number?)
	local r = radius or 4
	local t = seconds or 1.2
	for i = 1, 8 do
		local p = bit(color, 0.5, true)
		p.Shape = Enum.PartType.Ball
		local a0 = i / 8 * math.pi * 2
		local start = os.clock()
		task.spawn(function()
			while os.clock() - start < t and p.Parent do
				local k = (os.clock() - start) / t
				local a = a0 + k * math.pi * 3
				p.Position = pos + Vector3.new(math.cos(a) * r, k * r * 1.2, math.sin(a) * r)
				p.Transparency = k
				task.wait()
			end
			p:Destroy()
		end)
	end
end

-- Bounce a model's scale (squash and stretch) by tweening a NumberValue and re-scaling.
function Fx.boing(model: Model, amount: number?)
	local a = amount or 0.15
	local ok = pcall(function()
		local base = model:GetScale()
		local v = Instance.new("NumberValue")
		v.Value = base * (1 + a)
		v.Changed:Connect(function(x)
			pcall(function()
				model:ScaleTo(x)
			end)
		end)
		model:ScaleTo(base * (1 + a))
		local tw = tween(v, 0.35, { Value = base }, Enum.EasingStyle.Back)
		tw.Completed:Connect(function()
			v:Destroy()
		end)
	end)
	return ok
end

-- Hook up server-triggered effects.
task.spawn(function()
	local Net = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Net"))
	Net.event("Fx").OnClientEvent:Connect(function(name, ...)
		local fn = (Fx :: any)[name]
		if type(fn) == "function" then
			pcall(fn, ...)
		end
	end)
end)

return Fx

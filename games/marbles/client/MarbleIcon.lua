--!strict
-- Marble pictures for the UI. `flat` is a cheap 2D icon (a glossy circle whose bands, dots, eye or ring
-- follow the marble's pattern) for big grids; `view` is a live 3D ViewportFrame of the real MarbleArt
-- model, slowly spinning, for cards and reveals. `tierText` draws a rarity label with the tier gradient.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local MarbleArt = require(Shared:WaitForChild("MarbleArt"))
local UI = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("UI"))

local MarbleIcon = {}

local WHITE = Color3.new(1, 1, 1)
local INK = UI.INK

local function round(obj: GuiObject)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = obj
end

local function dot(parent: Instance, size: number, x: number, y: number, color: Color3, z: number, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency or 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromScale(size, size)
	f.Position = UDim2.fromScale(x, y)
	f.ZIndex = z
	round(f)
	f.Parent = parent
	return f
end

-- Hard colour bands (stripes) as a ColorSequence.
local function bands(cols: { Color3 }): ColorSequence
	local kps = {}
	local n = #cols
	for i, c in ipairs(cols) do
		local a = (i - 1) / n
		local b = i / n
		table.insert(kps, ColorSequenceKeypoint.new(i == 1 and 0 or a + 0.002, c))
		table.insert(kps, ColorSequenceKeypoint.new(b, c))
	end
	return ColorSequence.new(kps)
end

local RAINBOW = {
	Color3.fromRGB(255, 70, 70),
	Color3.fromRGB(255, 170, 40),
	Color3.fromRGB(255, 230, 60),
	Color3.fromRGB(70, 220, 110),
	Color3.fromRGB(70, 160, 255),
	Color3.fromRGB(170, 90, 255),
}

-- Flat icon: a square, transparent container holding the round marble picture.
function MarbleIcon.flat(parent: Instance, id: string, mut: string?, px: number, props: { [string]: any }?): Frame
	local def = Config.MarbleById[id] or Config.Marbles[1]
	local holder = Instance.new("Frame")
	holder.Name = "MarbleIcon"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(px, px)
	UI.set(holder, props)
	local z = holder.ZIndex + 1
	local ball = dot(holder, 1, 0.5, 0.5, WHITE, z)
	ball.Name = "Ball"
	ball.ClipsDescendants = true
	local stroke = UI.stroke(ball, math.max(2, px / 26), INK)
	local c1, c2, c3 = def.c1, def.c2, def.c3
	local g = Instance.new("UIGradient")
	local p = def.pattern
	if p == "swirl" then
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, c1),
			ColorSequenceKeypoint.new(0.35, c2),
			ColorSequenceKeypoint.new(0.6, c1),
			ColorSequenceKeypoint.new(0.85, c3),
			ColorSequenceKeypoint.new(1, c1),
		})
		g.Rotation = 35
	elseif p == "stripes" then
		g.Color = bands({ c1, c2, c3, c2, c1 })
		g.Rotation = 90
	elseif p == "rainbow" then
		g.Color = bands(RAINBOW)
		g.Rotation = 90
	elseif p == "candy" then
		g.Color = bands({ c1, c2, c3, c2, c1, c2 })
		g.Rotation = 0
	elseif p == "cateye" then
		g.Color = ColorSequence.new(c1:Lerp(WHITE, 0.82), c1:Lerp(WHITE, 0.6))
		g.Rotation = 90
	elseif p == "galaxy" then
		g.Color = ColorSequence.new(c1:Lerp(c3, 0.25), c1)
		g.Rotation = 120
	elseif p == "flame" or p == "gem" then
		g.Color = ColorSequence.new(c1:Lerp(WHITE, 0.25), c2)
		g.Rotation = 90
	else
		g.Color = ColorSequence.new(c1:Lerp(WHITE, 0.15), UI.shade(c1, 0.75))
		g.Rotation = 90
	end
	g.Parent = ball

	-- pattern details
	if p == "dots" then
		dot(ball, 0.2, 0.3, 0.62, c2, z + 1)
		dot(ball, 0.16, 0.66, 0.34, c2, z + 1)
		dot(ball, 0.14, 0.7, 0.7, c3, z + 1)
		dot(ball, 0.12, 0.42, 0.3, c3, z + 1)
		dot(ball, 0.15, 0.5, 0.86, c2, z + 1)
	elseif p == "eye" then
		dot(ball, 0.56, 0.5, 0.52, c1, z + 1)
		dot(ball, 0.26, 0.5, 0.52, c3, z + 2)
		dot(ball, 0.1, 0.56, 0.45, WHITE, z + 3)
	elseif p == "planet" then
		dot(ball, 0.56, 0.5, 0.5, c1, z + 1)
		local ring = Instance.new("Frame")
		ring.BorderSizePixel = 0
		ring.BackgroundColor3 = c2
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Size = UDim2.fromScale(1.05, 0.13)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.Rotation = -22
		ring.ZIndex = z + 2
		round(ring)
		ring.Parent = ball
	elseif p == "galaxy" then
		for k, pos in ipairs({ { 0.3, 0.35 }, { 0.62, 0.28 }, { 0.72, 0.6 }, { 0.4, 0.72 }, { 0.52, 0.5 }, { 0.22, 0.58 } }) do
			dot(ball, k % 2 == 0 and 0.09 or 0.06, pos[1], pos[2], k % 3 == 0 and c3 or c2, z + 1)
		end
	elseif p == "cateye" then
		for k, col in ipairs({ c1, c2, c3 }) do
			local vane = Instance.new("Frame")
			vane.BorderSizePixel = 0
			vane.BackgroundColor3 = col
			vane.AnchorPoint = Vector2.new(0.5, 0.5)
			vane.Size = UDim2.fromScale(0.78, 0.16)
			vane.Position = UDim2.fromScale(0.5, 0.5)
			vane.Rotation = (k - 1) * 60 + 15
			vane.ZIndex = z + k
			round(vane)
			vane.Parent = ball
		end
	elseif p == "flame" then
		dot(ball, 0.6, 0.5, 0.55, c1, z + 1, 0.05)
		dot(ball, 0.3, 0.5, 0.58, c3, z + 2)
	elseif p == "gem" then
		local d = Instance.new("Frame")
		d.BorderSizePixel = 0
		d.BackgroundColor3 = c3
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		d.Size = UDim2.fromScale(0.4, 0.4)
		d.Position = UDim2.fromScale(0.5, 0.52)
		d.Rotation = 45
		d.ZIndex = z + 1
		d.Parent = ball
	elseif p == "swirl" then
		dot(ball, 0.42, 0.55, 0.55, c1, z + 1, 0.15)
	end
	-- glass gloss
	dot(ball, 0.34, 0.33, 0.27, WHITE, z + 6, 0.45)
	dot(ball, 0.12, 0.26, 0.22, WHITE, z + 7, 0.1)

	-- mutation ring
	if mut == "gold" then
		stroke.Color = Color3.fromRGB(255, 196, 40)
		stroke.Thickness = math.max(3, px / 16)
	elseif mut == "rainbow" then
		stroke.Color = WHITE
		stroke.Thickness = math.max(3, px / 16)
		local sg = Instance.new("UIGradient")
		sg.Color = bands(RAINBOW)
		sg.Rotation = 45
		sg.Parent = stroke
	elseif mut == "cosmic" then
		stroke.Color = Color3.fromRGB(140, 82, 255)
		stroke.Thickness = math.max(3, px / 16)
		dot(ball, 0.06, 0.75, 0.25, WHITE, z + 8)
		dot(ball, 0.05, 0.2, 0.75, Color3.fromRGB(120, 230, 255), z + 8)
	end
	holder.Parent = parent
	return holder
end

-- Live 3D previews --------------------------------------------------------------------------------------
type Live = { vf: ViewportFrame, model: Model, phase: number, speed: number }
local live: { Live } = {}

RunService.RenderStepped:Connect(function()
	if #live == 0 then
		return
	end
	local t = os.clock()
	for i = #live, 1, -1 do
		local l = live[i]
		if not l.vf.Parent then
			table.remove(live, i)
		elseif l.vf.Visible and l.vf.AbsoluteSize.X > 2 then
			l.model:PivotTo(CFrame.Angles(0.35, t * l.speed + l.phase, 0.12))
		end
	end
end)

function MarbleIcon.view(parent: Instance, id: string, mut: string?, props: { [string]: any }?, spin: number?): ViewportFrame
	local vf = Instance.new("ViewportFrame")
	vf.Name = "MarbleView"
	vf.BackgroundTransparency = 1
	vf.Size = UDim2.fromOffset(120, 120)
	vf.Ambient = Color3.fromRGB(190, 190, 205)
	vf.LightColor = Color3.fromRGB(255, 255, 255)
	vf.LightDirection = Vector3.new(-1, -1.6, -0.8)
	UI.set(vf, props)
	local b = MarbleArt.build(id, mut, 3)
	b.model.Parent = vf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 34
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 0.6, 5.6), Vector3.zero)
	cam.Parent = vf
	vf.CurrentCamera = cam
	vf.Parent = parent
	table.insert(live, { vf = vf, model = b.model, phase = math.random() * 6, speed = spin or 0.9 })
	return vf
end

-- Rarity label with the tier gradient (animated rainbow for Secret).
function MarbleIcon.tierText(parent: Instance, tier: string, props: { [string]: any }?): TextLabel
	local t = Tiers.get(tier)
	local l = UI.text(parent, string.upper(t.name), props)
	if t.rainbow then
		UI.rainbow(l)
	else
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(UI.lighten(t.color, 0.25), t.color)
		g.Rotation = 90
		g.Parent = l
	end
	return l
end

-- Display name with mutation prefix ("Gold Galaxy").
function MarbleIcon.name(id: string, mut: string?): string
	local def = Config.MarbleById[id]
	local m = mut and Config.MutationByKey[mut]
	return (m and (m.name .. " ") or "") .. (def and def.name or id)
end

return MarbleIcon

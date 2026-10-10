-- Chunky primitive chef figures for NPC bakers and the judges (no catalog assets).
-- Npc.chef(parent, cf, opts) builds a ~5.5 stud figure standing at cf (feet), facing cf.LookVector.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared:WaitForChild("World"))

local Npc = {}

local V = Vector3.new
local CF = CFrame.new
local C = Color3.fromRGB
local INK = C(40, 30, 48)

export type ChefOpts = { name: string?, coat: Color3?, skin: Color3?, hat: string?, apron: Color3?, scale: number?, shades: boolean? }

local function part(m: Model, shape: Enum.PartType?, cf: CFrame, size: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Parent = m
	return p
end

function Npc.chef(parent: Instance, cf: CFrame, opts: ChefOpts?): Model
	local o: ChefOpts = opts or {}
	local sc = o.scale or 1
	local coat = o.coat or C(255, 255, 255)
	local skin = o.skin or C(255, 214, 180)
	local m = Instance.new("Model")
	m.Name = o.name or "Chef"

	local function at(x: number, y: number, z: number): CFrame
		return cf * CF(x * sc, y * sc, z * sc)
	end
	local function ball(x: number, y: number, z: number, d: number, col: Color3): Part
		return part(m, Enum.PartType.Ball, at(x, y, z), V(d, d, d) * sc, col)
	end
	local function upcyl(x: number, y: number, z: number, h: number, d: number, col: Color3): Part
		return part(m, Enum.PartType.Cylinder, at(x, y + h / 2, z) * CFrame.Angles(0, 0, math.rad(90)), V(h, d, d) * sc, col)
	end
	local function rod(a: Vector3, b: Vector3, d: number, col: Color3): Part
		local wa = (cf * CF(a * sc)).Position
		local wb = (cf * CF(b * sc)).Position
		local dir = (wb - wa).Unit
		local ref = if math.abs(dir.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
		local y = (ref - dir * ref:Dot(dir)).Unit
		return part(m, Enum.PartType.Cylinder, CFrame.fromMatrix((wa + wb) / 2, dir, y), V((wb - wa).Magnitude, d * sc, d * sc), col)
	end

	-- legs, body, apron
	upcyl(-0.45, 0, 0, 1.6, 0.75, C(70, 60, 80))
	upcyl(0.45, 0, 0, 1.6, 0.75, C(70, 60, 80))
	local body = upcyl(0, 1.45, 0, 2.5, 2.3, coat)
	body.Name = "Body"
	body.PivotOffset = body.CFrame:ToObjectSpace(cf) -- the model pivots at the feet
	part(m, nil, at(0, 2.45, -1.08), V(1.6, 1.8, 0.2) * sc, o.apron or C(255, 170, 200))
	ball(0, 3.55, -1.1, 0.24, C(255, 205, 70))
	ball(0, 3.15, -1.13, 0.24, C(255, 205, 70))
	-- arms and hands
	for _, sx in ipairs({ 1, -1 }) do
		rod(V(1.15 * sx, 3.6, 0), V(1.45 * sx, 2.55, -0.55), 0.6, coat)
		ball(1.5 * sx, 2.45, -0.62, 0.62, skin)
	end
	-- head and face
	local head = ball(0, 5.0, 0, 2.15, skin)
	head.Name = "Head"
	for _, sx in ipairs({ 1, -1 }) do
		ball(0.38 * sx, 5.15, -0.9, 0.3, INK)
		ball(0.42 * sx, 5.22, -1.0, 0.1, C(255, 255, 255))
		ball(0.66 * sx, 4.82, -0.78, 0.36, C(255, 150, 170))
	end
	part(m, nil, at(0, 4.62, -1.0), V(0.55, 0.12, 0.12) * sc, INK)
	if o.shades then
		part(m, nil, at(0, 5.16, -1.02), V(1.5, 0.36, 0.12) * sc, C(25, 25, 35))
	end
	-- hat
	local hat = o.hat or "chef"
	if hat == "beret" then
		part(m, Enum.PartType.Cylinder, at(0.25, 5.95, 0) * CFrame.Angles(0, 0, math.rad(80)), V(0.45, 2.1, 2.1) * sc, C(230, 60, 120))
		ball(0.35, 6.25, 0, 0.35, C(230, 60, 120))
	elseif hat == "top" then
		part(m, Enum.PartType.Cylinder, at(0, 5.95, 0) * CFrame.Angles(0, 0, math.rad(90)), V(0.14, 2.3, 2.3) * sc, C(35, 32, 45))
		upcyl(0, 5.95, 0, 1.5, 1.4, C(35, 32, 45))
		upcyl(0, 6.15, 0, 0.3, 1.43, C(255, 110, 180))
	else
		local hc = if hat == "gold" then C(255, 205, 70) else C(255, 255, 255)
		local band = upcyl(0, 5.75, 0, 0.9, 1.7, hc)
		local puffs = {
			ball(-0.45, 6.95, 0, 1.15, hc),
			ball(0.45, 6.95, 0, 1.15, hc),
			ball(0, 7.2, 0.1, 1.2, hc),
		}
		if hat == "gold" then
			band.Reflectance = 0.3
			for _, p in ipairs(puffs) do
				p.Reflectance = 0.3
			end
			local star = ball(0, 6.2, -0.85, 0.5, C(255, 255, 255))
			star.Material = Enum.Material.Neon
		end
	end

	m.PrimaryPart = body
	m.Parent = parent
	World.label(head, o.name or "Chef", { name = "NameTag", offset = V(0, 3.4 * sc, 0), width = 9, height = 1.5, maxDistance = 90, color = C(255, 255, 255) })
	return m
end

-- Score paddle held by a judge: a Model "Paddle" (board + handle) with "?" on both faces.
-- The server only builds it; clients lift and fill it when the judges vote.
function Npc.paddle(judge: Model, cf: CFrame, color: Color3): Model
	local m = Instance.new("Model")
	m.Name = "Paddle"
	local board = part(m, nil, cf * CF(0, 0.9, 0), V(1.7, 1.25, 0.14), Color3.fromRGB(255, 255, 255))
	board.Name = "Board"
	part(m, nil, cf * CF(0, 0.9, 0.08), V(1.85, 1.4, 0.06), color)
	part(m, Enum.PartType.Cylinder, cf * CF(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90)), V(1.2, 0.18, 0.18), C(150, 100, 70))
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sg = Instance.new("SurfaceGui")
		sg.Name = "Score" .. face.Name
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 60
		sg.LightInfluence = 0
		local l = Instance.new("TextLabel")
		l.Name = "Text"
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Font = Enum.Font.LuckiestGuy
		l.TextScaled = true
		l.Text = "?"
		l.TextColor3 = Color3.fromRGB(255, 120, 165)
		local s = Instance.new("UIStroke")
		s.Thickness = 3
		s.Color = INK
		s.Parent = l
		l.Parent = sg
		sg.Parent = board
	end
	m.PrimaryPart = board
	m.Parent = judge
	return m
end

return Npc

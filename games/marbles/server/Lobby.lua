--!strict
-- The world: a giant tabletop with a tower of giant books in the middle. The top book is the lobby deck
-- (spawn, start gates, Pack Machine, Shine Machine, shop, daily chest, winners' podium, league board,
-- tier showcase). Giant desk props stand around the table edges, outside every track's area, and a
-- giant golden trophy at the far end is the landmark seen from spawn. Tracks are built by the clients.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local World = require(Shared:WaitForChild("World"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local MarbleArt = require(Shared:WaitForChild("MarbleArt"))
local Net = require(Shared:WaitForChild("Net"))
local Assets = require(script.Parent:WaitForChild("Assets"))

local Lobby = {}

local V = Vector3.new
local CF = CFrame.new
local RAD = math.rad
local P = Config.Palette
local W = Config.World
local DY = W.deckY
local hex = Color3.fromHex

local root: Folder
local rng = Random.new(20261010)
local openRemote = Net.event("Open")

local podiumSlots: { { pos: Vector3, built: MarbleArt.Built?, label: BillboardGui? } } = {}
local boardRows: { TextLabel } = {}
local spawnLocation: SpawnLocation

local function decor(p: BasePart)
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

local function box(parent: Instance, cf: CFrame, size: Vector3, color: Color3, extra: { [string]: any }?): BasePart
	return World.box(parent, cf, size, color, extra)
end

-- Prompt that tells the client to open a panel.
local function prompt(parent: BasePart, name: string, action: string, object: string, panel: string)
	local pp = Instance.new("ProximityPrompt")
	pp.Name = name
	pp.ActionText = action
	pp.ObjectText = object
	pp.MaxActivationDistance = 14
	pp.RequiresLineOfSight = false
	pp.HoldDuration = 0
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.Parent = parent
	pp.Triggered:Connect(function(player)
		if Net.allow(player, "prompt", 0.4) then
			openRemote:FireClient(player, panel)
		end
	end)
end

-- Table ---------------------------------------------------------------------------------------------------

local function buildTable()
	local f = World.folder("Table", root)
	local x0, x1, z0, z1 = W.tableMinX, W.tableMaxX, W.tableMinZ, W.tableMaxZ
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local sx, sz = x1 - x0, z1 - z0
	box(f, CF(cx, -3, cz), V(sx, 6, sz), P.table, { Name = "TableTop", Variant = "MarbleTableTop" })
	-- rounded bullnose edge
	local e = -2.2
	World.rod(f, V(x0, e, z0), V(x1, e, z0), 7.5, P.tableEdge, { Name = "Edge" })
	World.rod(f, V(x0, e, z1), V(x1, e, z1), 7.5, P.tableEdge, { Name = "Edge" })
	World.rod(f, V(x0, e, z0), V(x0, e, z1), 7.5, P.tableEdge, { Name = "Edge" })
	World.rod(f, V(x1, e, z0), V(x1, e, z1), 7.5, P.tableEdge, { Name = "Edge" })
	-- apron and legs
	box(f, CF(cx, -22, z0 + 14), V(sx - 30, 32, 4), P.tableDark, { Name = "Apron" })
	box(f, CF(cx, -22, z1 - 14), V(sx - 30, 32, 4), P.tableDark, { Name = "Apron" })
	box(f, CF(x0 + 14, -22, cz), V(4, 32, sz - 30), P.tableDark, { Name = "Apron" })
	box(f, CF(x1 - 14, -22, cz), V(4, 32, sz - 30), P.tableDark, { Name = "Apron" })
	for _, c in ipairs({ { x0 + 40, z0 + 40 }, { x1 - 40, z0 + 40 }, { x0 + 40, z1 - 40 }, { x1 - 40, z1 - 40 } }) do
		World.cyl(f, V(c[1], -470, c[2]), 464, 44, P.tableDark, { Name = "Leg" })
	end
	-- the playroom floor far below (rug) so the void reads as a room
	box(f, CF(cx, -472, cz), V(2048, 4, 2048), hex("#86A8E0"), { Name = "Rug", Variant = "MarbleFeltMat", CastShadow = false })
	box(f, CF(cx, -469.6, cz), V(1300, 1, 1700), hex("#F2B5D4"), { Name = "RugInner", Variant = "MarbleFeltMat", CastShadow = false })
	for _, d in ipairs(f:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "TableTop" then
			decor(d :: BasePart)
		end
	end
end

-- Book tower + lobby deck -------------------------------------------------------------------------------

local function book(parent: Instance, center: Vector3, w: number, d: number, h: number, color: Color3, yaw: number, spineSide: number)
	local m = World.model("Book", parent)
	local rot = CFrame.Angles(0, RAD(yaw), 0)
	local base = CF(center) * rot
	local coverT = 1.1
	box(m, base * CF(0, coverT / 2, 0), V(w, coverT, d), color, { Name = "Cover" })
	box(m, base * CF(0, h - coverT / 2, 0), V(w, coverT, d), color, { Name = "Cover" })
	box(m, base * CF(spineSide * 1.5, h / 2, 0), V(w - 4, h - coverT * 2 + 0.05, d - 3), P.paper, { Name = "Pages" })
	box(m, base * CF(-spineSide * (w / 2 - 1), h / 2, 0), V(2, h, d), color, { Name = "Spine" })
	-- spine bands
	box(m, base * CF(-spineSide * (w / 2 - 0.9), h * 0.25, 0), V(2.1, 0.8, d + 0.05), P.rare, { Name = "Band" })
	box(m, base * CF(-spineSide * (w / 2 - 0.9), h * 0.75, 0), V(2.1, 0.8, d + 0.05), P.rare, { Name = "Band" })
	return m
end

local function crayon(parent: Instance, pos: Vector3, color: Color3, height: number)
	local m = World.model("Crayon", parent)
	World.cyl(m, pos, height, 2.4, color, { Name = "Body" })
	World.cyl(m, pos + V(0, height * 0.3, 0), height * 0.42, 2.55, color:Lerp(Color3.new(1, 1, 1), 0.55), { Name = "Wrapper" })
	World.cyl(m, pos + V(0, height, 0), 1.2, 1.7, color, { Name = "Tip" })
	World.ball(m, pos + V(0, height + 1.2, 0), 1.5, color, { Name = "TipBall" })
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			decor(d :: BasePart)
		end
	end
	return m
end

local CRAYONS = { hex("#FF4F5E"), hex("#FF8A3D"), hex("#FFC93C"), hex("#7BE05A"), hex("#42C2FF"), hex("#A774FF"), hex("#FF5AA8") }

local function buildTower()
	local f = World.folder("BookTower", root)
	local books = {
		{ 124, 108, 12, "#3F7BE0", 4 },
		{ 110, 98, 11, "#FF8A3D", -6 },
		{ 114, 100, 12, "#4FC36A", 3 },
		{ 104, 94, 11, "#A774FF", -3 },
		{ 106, 96, 12, "#FF5AA8", 2 },
	}
	local y = 0
	for i, b in ipairs(books :: { { any } }) do
		book(f, V(0, y, -7), b[1], b[2], b[3], hex(b[4]), b[5], i % 2 == 0 and 1 or -1)
		y += b[3]
	end
	-- the deck book (axis aligned): top cover at DY - 0.4, felt mat on top at DY
	local deck = book(f, V(0, y, -7), 100, 90, DY - 0.4 - y, hex("#2F5FD0"), 0, 1)
	deck.Name = "DeckBook"
	local mat = box(f, CF(0, DY - 0.2, -7), V(W.deckMaxX - W.deckMinX, 0.4, W.deckMaxZ - W.deckMinZ), hex("#79D17E"), { Name = "PlayMat", Variant = "MarbleFeltMat" })
	mat.CastShadow = false
	-- mat border
	local bc = hex("#FFFFFF")
	box(f, CF(0, DY - 0.15, W.deckMinZ + 1.5), V(W.deckMaxX - W.deckMinX - 2, 0.42, 1), bc, { Name = "MatLine" })
	box(f, CF(0, DY - 0.15, W.deckMaxZ - 1.5), V(W.deckMaxX - W.deckMinX - 2, 0.42, 1), bc, { Name = "MatLine" })
	box(f, CF(W.deckMinX + 1.5, DY - 0.15, -7), V(1, 0.42, W.deckMaxZ - W.deckMinZ - 2), bc, { Name = "MatLine" })
	box(f, CF(W.deckMaxX - 1.5, DY - 0.15, -7), V(1, 0.42, W.deckMaxZ - W.deckMinZ - 2), bc, { Name = "MatLine" })

	-- crayon fence with gaps at the two start gates
	local fence = World.folder("Fence", f)
	local x0, x1, z0, z1 = W.deckMinX + 1.8, W.deckMaxX - 1.8, W.deckMinZ + 1.8, W.deckMaxZ - 1.8
	local posts: { { Vector3 } } = {}
	local function edge(a: Vector3, b: Vector3, skip: (Vector3) -> boolean)
		local len = (b - a).Magnitude
		local n = math.max(1, math.floor(len / 9))
		local run: { Vector3 } = {}
		for k = 0, n do
			local p = a:Lerp(b, k / n)
			if skip(p) then
				if #run > 0 then
					table.insert(posts, run)
					run = {}
				end
			else
				table.insert(run, p)
			end
		end
		if #run > 0 then
			table.insert(posts, run)
		end
	end
	local function none(_p: Vector3): boolean
		return false
	end
	edge(V(x0, DY, z1), V(x1, DY, z1), function(p)
		return math.abs(p.X) < 13
	end)
	-- no crayon right behind the spawn, where it would block the default third-person camera
	edge(V(x0, DY, z0), V(x1, DY, z0), function(p)
		return math.abs(p.X) < 7
	end)
	edge(V(x1, DY, z0), V(x1, DY, z1), none)
	edge(V(x0, DY, z0), V(x0, DY, z1), function(p)
		return p.Z > -38 and p.Z < -10
	end)
	local ci = 0
	for _, run in ipairs(posts) do
		for k, p in ipairs(run) do
			ci += 1
			crayon(fence, p, CRAYONS[ci % #CRAYONS + 1], 6 + (ci % 3) * 0.8)
			if k > 1 then
				local rail = World.rod(fence, run[k - 1] + V(0, 3.4, 0), p + V(0, 3.4, 0), 0.9, P.structure, { Name = "Rail" })
				decor(rail)
			end
		end
	end
	-- invisible walls so nobody walks off the deck (or down a track)
	local wallH = 16
	local function wall(cf: CFrame, size: Vector3)
		local w = box(f, cf, size, Color3.new(1, 1, 1), { Name = "SafetyWall", Transparency = 1, CanQuery = false, CastShadow = false })
		w.CanTouch = false
	end
	wall(CF(0, DY + wallH / 2, W.deckMaxZ - 1), V(W.deckMaxX - W.deckMinX + 4, wallH, 2))
	wall(CF(0, DY + wallH / 2, W.deckMinZ + 0.5), V(W.deckMaxX - W.deckMinX + 4, wallH, 2))
	wall(CF(W.deckMinX + 0.5, DY + wallH / 2, -7), V(2, wallH, W.deckMaxZ - W.deckMinZ + 4))
	wall(CF(W.deckMaxX - 0.5, DY + wallH / 2, -7), V(2, wallH, W.deckMaxZ - W.deckMinZ + 4))

	-- runner from spawn to the start grid
	local path = World.path(f, { V(0, DY, -33), V(0, DY, 10) }, 9, hex("#FFF4DE"), nil, DY - 0.05)
	for _, d in ipairs(path:GetDescendants()) do
		if d:IsA("BasePart") then
			decor(d :: BasePart)
		end
	end
	-- spawn
	local sp = Instance.new("SpawnLocation")
	sp.Name = "Spawn"
	sp.Anchored = true
	sp.Size = V(12, 1, 12)
	sp.CFrame = CFrame.lookAt(V(0, DY - 0.2, -40), V(0, DY - 0.2, 0))
	sp.Color = P.accent
	sp.Material = Enum.Material.SmoothPlastic
	sp.TopSurface = Enum.SurfaceType.Smooth
	sp.Duration = 0
	sp.Neutral = true
	sp.Parent = f
	spawnLocation = sp
	World.pad(f, V(0, DY + 0.35, -40), 5, P.sky)
end

-- Stations -------------------------------------------------------------------------------------------------

local function label(adornee: Instance, text: string, color: Color3, opts: { [string]: any }?)
	local o: { [string]: any } = { width = 16, height = 4, offset = V(0, 9, 0), maxDistance = 160, gradient = ColorSequence.new(Color3.new(1, 1, 1), color) }
	for k, v in pairs(opts or {}) do
		o[k] = v
	end
	return World.label(adornee, text, o)
end

local function buildPackMachine()
	local m = World.model("PackMachine", root)
	local c = V(30, DY, -8)
	local red = hex("#FF4F5E")
	World.cyl(m, c, 3, 12, red, { Name = "Base" })
	World.cyl(m, c + V(0, 3, 0), 0.6, 12.6, P.rare, { Name = "BaseTrim" })
	local body = box(m, CF(c + V(0, 8.6, 0)), V(9.5, 11, 9.5), red, { Name = "Body" })
	box(m, CF(c + V(-4.85, 9.5, 0)), V(0.3, 4, 3), P.ink, { Name = "Chute" })
	box(m, CF(c + V(-4.85, 12.6, 0)), V(0.3, 1.6, 2.2), P.rare, { Name = "Slot" })
	World.cyl(m, c + V(0, 14.1, 0), 1.2, 10.5, P.rare, { Name = "Collar" })
	local globe = World.ball(m, c + V(0, 21.5, 0), 15, hex("#D8F3FF"), { Name = "Globe", Material = Enum.Material.Glass, Transparency = 0.55 })
	globe.CanCollide = true
	for k = 1, 28 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0, 5)
		local y = rng:NextNumber(-5.6, 1.5)
		local rr = math.min(r, math.sqrt(math.max(0, 5.6 * 5.6 - y * y)))
		local col = CRAYONS[(k % #CRAYONS) + 1]
		local b = World.ball(m, c + V(0, 21.5, 0) + V(math.cos(a) * rr, y, math.sin(a) * rr), 2.4, col, { Name = "Gumball" })
		decor(b)
	end
	World.cyl(m, c + V(0, 28.6, 0), 2, 6, red, { Name = "Cap" })
	World.ball(m, c + V(0, 31.2, 0), 2.6, P.rare, { Name = "Knob" })
	prompt(body, "PacksPrompt", "Open Packs", "Pack Machine", "Packs")
	label(globe, "🎁 PACKS", P.rare, { offset = V(0, 12, 0) })
end

local function buildShine()
	local m = World.model("ShineMachine", root)
	local c = V(30, DY, 20)
	local purple = hex("#8C52FF")
	World.cyl(m, c, 2, 15, purple, { Name = "Base" })
	World.cyl(m, c + V(0, 2, 0), 0.5, 13, hex("#FF8AD8"), { Name = "BaseTop" })
	local ped = World.cyl(m, c + V(0, 2.5, 0), 4, 4.5, P.structure, { Name = "Pedestal" })
	for k = 1, 3 do
		local a = k / 3 * math.pi * 2
		local p = c + V(math.cos(a) * 5.6, 2.5, math.sin(a) * 5.6)
		World.cyl(m, p, 10, 1.6, P.structure, { Name = "Pillar" })
		World.ball(m, p + V(0, 10.6, 0), 2.2, P.rare, { Name = "PillarTop", Material = Enum.Material.Neon })
	end
	for k = 1, 16 do
		local a = k / 16 * math.pi * 2
		local p = c + V(math.cos(a) * 6.2, 13.6, math.sin(a) * 6.2)
		local seg = box(m, CFrame.lookAt(p, c + V(0, 13.6, 0)), V(2.6, 0.9, 0.9), k % 2 == 0 and hex("#FF5AA8") or purple, { Name = "Ring", Material = Enum.Material.Neon })
		decor(seg)
	end
	local orb = World.ball(m, c + V(0, 9.5, 0), 4.2, P.rare, { Name = "Orb", Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Color = P.rare
	light.Range = 18
	light.Brightness = 1.4
	light.Parent = orb
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(P.rare, hex("#FF8AD8"))
	pe.LightEmission = 1
	pe.Rate = 8
	pe.Lifetime = NumberRange.new(0.8, 1.4)
	pe.Speed = NumberRange.new(2, 4)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	pe.Parent = orb
	prompt(ped, "ShinePrompt", "Shine a Marble", "Shine Machine", "Shine")
	label(orb, "✨ SHINE", hex("#FF8AD8"), { offset = V(0, 9, 0) })
end

local SHOWCASE = { { "Common", "blue" }, { "Uncommon", "beach" }, { "Rare", "eyeball" }, { "Epic", "galaxy" }, { "Legendary", "sunspark" }, { "Mythic", "blackhole" } }

local function buildShowcase()
	local f = World.folder("Showcase", root)
	for i, s in ipairs(SHOWCASE) do
		local z = -26 + (i - 1) * 10
		local c = V(42.5, DY, z)
		local t = Tiers.get(s[1])
		World.cyl(f, c, 3, 5, t.dark, { Name = "Pedestal" })
		local top = World.cyl(f, c + V(0, 3, 0), 0.4, 5.6, P.structure, { Name = "PedestalTop" })
		local b = MarbleArt.build(s[2], nil, 3.6)
		b.model.Parent = f
		MarbleArt.place(b, CF(c + V(0, 3.4 + 1.8, 0)))
		MarbleArt.sparkle(b, s[2], nil)
		label(top, t.name, t.color, { width = 8, height = 2, offset = V(0, 4.8, 0), maxDistance = 70, gradient = Tiers.gradient(s[1]) })
	end
end

local function buildShop()
	local m = World.model("Shop", root)
	local c = V(30, DY, -38)
	local counter = box(m, CF(c + V(0, 2.2, 0)), V(11, 4.4, 5), P.structure, { Name = "Counter" })
	box(m, CF(c + V(0, 4.6, 0)), V(11.6, 0.5, 5.6), P.accent, { Name = "CounterTop" })
	for _, x in ipairs({ -5, 5 }) do
		World.cyl(m, c + V(x, 0, 2.2), 11, 0.8, P.structure, { Name = "Pole" })
	end
	for k = 0, 6 do
		local col = k % 2 == 0 and P.accent or P.structure
		box(m, CF(c + V(-5.25 + k * 1.75, 11.2, 0.6)) * CFrame.Angles(RAD(-18), 0, 0), V(1.76, 0.4, 7.5), col, { Name = "Awning" })
	end
	prompt(counter, "ShopPrompt", "Shop", "Marble Shop", "Shop")
	label(counter, "🛒 SHOP", P.accent, { offset = V(0, 11, 0) })
end

local function buildDaily()
	local m = World.model("DailyChest", root)
	local c = V(-20, DY, -42)
	local wood = hex("#C9773A")
	local chest = box(m, CF(c + V(0, 1.8, 0)), V(6.5, 3.6, 4.4), wood, { Name = "Chest" })
	box(m, CF(c + V(0, 4.3, -0.4)) * CFrame.Angles(RAD(-14), 0, 0), V(6.6, 1.6, 4.5), wood, { Name = "Lid" })
	for _, x in ipairs({ -2.4, 2.4 }) do
		box(m, CF(c + V(x, 2.6, 0)), V(0.7, 5.4, 4.6), P.rare, { Name = "Band" })
	end
	box(m, CF(c + V(0, 3.2, 2.3)), V(1.2, 1.4, 0.4), P.rare, { Name = "Lock" })
	prompt(chest, "DailyPrompt", "Daily Reward", "Daily Chest", "Daily")
	label(chest, "📅 DAILY", P.rare, { offset = V(0, 7, 0) })
end

local function buildPodium()
	local m = World.model("WinnersPodium", root)
	local c = V(-26, DY, -2)
	local specs = {
		{ place = 2, x = -6.5, h = 3.4, color = hex("#D6DCE8") },
		{ place = 1, x = 0, h = 5, color = hex("#FFD23F") },
		{ place = 3, x = 6.5, h = 2.4, color = hex("#E89A5A") },
	}
	local slots = {}
	for _, s in ipairs(specs) do
		local blockCf = CFrame.lookAt(c + V(0, s.h / 2, s.x), c + V(10, s.h / 2, s.x))
		local blk = box(m, blockCf, V(6, s.h, 6), s.color, { Name = "Block" .. s.place })
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 30
		sg.LightInfluence = 0
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.LuckiestGuy
		t.TextScaled = true
		t.Text = tostring(s.place)
		t.TextColor3 = Color3.new(1, 1, 1)
		local st = Instance.new("UIStroke")
		st.Thickness = 4
		st.Color = P.ink
		st.Parent = t
		t.Parent = sg
		sg.Parent = blk
		slots[s.place] = { pos = c + V(0, s.h + 2.6, s.x), built = nil, label = nil }
	end
	podiumSlots = slots
	local sign = box(m, CF(c + V(-3.5, 11.5, 0)), V(0.6, 0.6, 0.6), P.rare, { Name = "SignAnchor", Transparency = 1, CanCollide = false })
	label(sign, "🏆 LAST RACE", P.rare, { offset = V(0, 2, 0), width = 18 })
end

local function buildBoard()
	local m = World.model("LeagueBoard", root)
	local cf = CFrame.lookAt(V(-40, DY + 9.5, 22), V(0, DY + 9.5, 22))
	local board = box(m, cf, V(22, 14, 1), P.ink, { Name = "Board" })
	box(m, cf * CF(0, 0, 0.1), V(23, 15, 0.8), P.rare, { Name = "Frame" })
	for _, x in ipairs({ -8, 8 }) do
		local p = (cf * CF(x, -7, 0.4)).Position
		World.cyl(m, V(p.X, DY, p.Z), 3, 1.2, P.structure, { Name = "Post" })
	end
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 24
	sg.LightInfluence = 0
	sg.MaxDistance = 200
	sg.Parent = board
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.16)
	title.Font = Enum.Font.LuckiestGuy
	title.TextScaled = true
	title.Text = "🏅 DAILY LEAGUE 🏅"
	title.TextColor3 = P.rare
	title.Parent = sg
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0.06, 0.18)
	list.Size = UDim2.fromScale(0.88, 0.8)
	list.Parent = sg
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	for i = 1, Config.League.boardSize do
		local row = Instance.new("TextLabel")
		row.BackgroundTransparency = 1
		row.Size = UDim2.fromScale(1, 0.1)
		row.Font = Enum.Font.FredokaOne
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = i <= 3 and P.rare or Color3.new(1, 1, 1)
		row.Text = i == 1 and "Race to get on the board!" or ""
		row.LayoutOrder = i
		row.Parent = list
		boardRows[i] = row
	end
end

-- Giant desk props, kept outside every track's area -----------------------------------------------------

local function pencil(parent: Instance, a: Vector3, b: Vector3, d: number, color: Color3)
	local dir = (b - a).Unit
	local len = (b - a).Magnitude
	World.rod(parent, a, a + dir * len * 0.86, d, color, { Name = "PencilBody" })
	World.rod(parent, a + dir * len * 0.86, a + dir * len * 0.95, d * 0.7, hex("#F2D3A2"), { Name = "PencilWood" })
	World.rod(parent, a + dir * len * 0.95, b, d * 0.32, P.ink, { Name = "PencilLead" })
	World.rod(parent, a - dir * d * 0.6, a, d * 1.02, hex("#C9CDD8"), { Name = "Ferrule" })
	World.rod(parent, a - dir * d * 1.5, a - dir * d * 0.6, d, hex("#FF9EC4"), { Name = "Eraser" })
end

local function buildProps()
	local f = World.folder("Props", root)
	-- desk lamp (right of the lobby)
	local lampC = V(175, 0, -140)
	World.cyl(f, lampC, 8, 56, P.ink, { Name = "LampBase" })
	World.cyl(f, lampC + V(0, 8, 0), 3, 40, hex("#FF5AA8"), { Name = "LampBaseTop" })
	local j1 = lampC + V(0, 11, 0)
	local j2 = lampC + V(-30, 120, 40)
	local j3 = lampC + V(-80, 150, 110)
	World.rod(f, j1, j2, 6, hex("#FF5AA8"), { Name = "LampArm" })
	World.rod(f, j2, j3, 6, hex("#FF5AA8"), { Name = "LampArm" })
	World.ball(f, j2, 10, P.ink, { Name = "LampJoint" })
	World.ball(f, j3, 10, P.ink, { Name = "LampJoint" })
	local headDir = (V(-20, 0, 220) - j3).Unit
	local hc = j3 + headDir * 18
	World.rod(f, j3, hc, 26, hex("#FF5AA8"), { Name = "LampHead" })
	World.rod(f, hc, hc + headDir * 10, 40, hex("#FF5AA8"), { Name = "LampShade" })
	local bulb = World.ball(f, hc + headDir * 9, 22, hex("#FFF6C8"), { Name = "LampBulb", Material = Enum.Material.Neon })
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Range = 60
	spot.Angle = 70
	spot.Brightness = 2
	spot.Color = hex("#FFF2C2")
	spot.Parent = bulb
	-- pencil cup
	local cup = V(95, 0, -70)
	World.cyl(f, cup, 44, 34, hex("#42C2FF"), { Name = "PencilCup" })
	World.cyl(f, cup + V(0, 44, 0), 2, 36, hex("#FFFFFF"), { Name = "CupRim" })
	for k = 1, 5 do
		local a = k / 5 * math.pi * 2
		local base = cup + V(math.cos(a) * 7, 10, math.sin(a) * 7)
		local tip = base + V(math.cos(a) * 26, 70 + k * 4, math.sin(a) * 26)
		pencil(f, tip, base, 5, CRAYONS[k + 1])
	end
	-- block towers along the right edge
	for k, z in ipairs({ 120, 380, 640 }) do
		for lvl = 0, 2 + k % 2 do
			local col = CRAYONS[(k + lvl) % #CRAYONS + 1]
			local s = 18
			local c = V(268, s / 2 + lvl * s, z + (lvl % 2) * 3)
			box(f, CF(c) * CFrame.Angles(0, RAD(lvl * 9), 0), V(s, s, s), col, { Name = "Block" })
			for sx = -1, 1, 2 do
				for sz = -1, 1, 2 do
					World.cyl(f, (CF(c) * CFrame.Angles(0, RAD(lvl * 9), 0) * CF(sx * 4.5, s / 2, sz * 4.5)).Position, 2, 5, col, { Name = "Stud" })
				end
			end
		end
	end
	-- crayon box (left side)
	local cb = V(-340, 0, 300)
	box(f, CF(cb + V(0, 30, 0)), V(70, 60, 26), hex("#FFC93C"), { Name = "CrayonBox" })
	box(f, CF(cb + V(0, 30, -13.2)), V(56, 24, 0.6), hex("#3F7BE0"), { Name = "CrayonBoxLabel" })
	for k = 1, 7 do
		local x = -27 + (k - 1) * 9
		local h = 64 + (k % 3) * 8
		World.cyl(f, cb + V(x, 0, 0), h, 8, CRAYONS[k], { Name = "BigCrayon" })
		World.cyl(f, cb + V(x, h, 0), 5, 5.5, CRAYONS[k], { Name = "BigCrayonTip" })
		World.ball(f, cb + V(x, h + 5, 0), 5.2, CRAYONS[k], { Name = "BigCrayonTipBall" })
	end
	-- dice
	for k, p in ipairs({ V(-300, 0, 560), V(-330, 0, 590) }) do
		local s = 26
		local cf = CF(p + V(0, s / 2, 0)) * CFrame.Angles(0, RAD(20 + k * 30), 0)
		box(f, cf, V(s, s, s), P.structure, { Name = "Die" })
		for _, pip in ipairs({ V(0, s / 2 + 0.1, 0), V(-6, s / 2 + 0.1, -6), V(6, s / 2 + 0.1, 6) }) do
			World.cyl(f, (cf * CF(pip)).Position - V(0, 0.4, 0), 0.6, 5, k == 1 and P.red or P.ink, { Name = "Pip" })
		end
	end
	-- apple
	local ap = V(-420, 0, 130)
	World.ball(f, ap + V(0, 26, 0), 52, hex("#FF4F5E"), { Name = "Apple" })
	World.cyl(f, ap + V(0, 50, 0), 10, 3, hex("#7A4A2A"), { Name = "AppleStem" })
	World.part({ Name = "AppleLeaf", Size = V(14, 1, 7), CFrame = CF(ap + V(6, 58, 0)) * CFrame.Angles(0, 0, RAD(25)), Color = hex("#4FC36A"), Parent = f })
	-- mug
	local mg = V(-330, 0, 820)
	World.cyl(f, mg, 60, 50, hex("#FFFFFF"), { Name = "Mug" })
	World.cyl(f, mg + V(0, 54, 0), 1, 44, hex("#7A4A2A"), { Name = "Cocoa" })
	World.cyl(f, mg + V(0, 22, 0), 14, 50.4, hex("#42C2FF"), { Name = "MugStripe" })
	World.rod(f, mg + V(25, 44, 0), mg + V(38, 30, 0), 7, hex("#FFFFFF"), { Name = "MugHandle" })
	World.rod(f, mg + V(38, 30, 0), mg + V(25, 14, 0), 7, hex("#FFFFFF"), { Name = "MugHandle" })
	-- pencils lying on the table edges
	pencil(f, V(-460, 4, -200), V(-300, 4, -235), 8, hex("#FFC93C"))
	pencil(f, V(150, 4, 900), V(260, 4, 760), 8, hex("#42C2FF"))
	for _, d in ipairs(f:GetDescendants()) do
		if d:IsA("BasePart") then
			decor(d :: BasePart)
		end
	end
end

-- Landmark: the Grand Trophy at the far end of the table.
local function buildTrophy()
	local m = World.model("GrandTrophy", root)
	local c = W.trophyPos
	local gold = hex("#FFC93C")
	local goldDark = hex("#E89A1F")
	box(m, CF(c + V(0, 8, 0)), V(56, 16, 56), P.ink, { Name = "Plinth" })
	box(m, CF(c + V(0, 17, 0)), V(46, 2, 46), gold, { Name = "PlinthTrim" })
	local mesh = Assets.get("Trophy")
	if mesh then
		mesh.CFrame = CF(c + V(0, 18 + mesh.Size.Y / 2, 0))
		mesh.Parent = m
	else
		World.cyl(m, c + V(0, 18, 0), 8, 30, goldDark, { Name = "Foot" })
		World.cyl(m, c + V(0, 26, 0), 26, 9, gold, { Name = "Stem" })
		World.ball(m, c + V(0, 40, 0), 16, goldDark, { Name = "Knot" })
		-- bowl: stacked widening discs
		local y = 44
		for k = 0, 6 do
			local d = 22 + k * 7
			World.cyl(m, c + V(0, y, 0), 6.2, d, k % 2 == 0 and gold or hex("#FFD84F"), { Name = "Bowl" })
			y += 6
		end
		World.cyl(m, c + V(0, y, 0), 3, 68, goldDark, { Name = "Lip" })
		-- handles
		for _, sx in ipairs({ -1, 1 }) do
			local a = c + V(sx * 30, 80, 0)
			local b = c + V(sx * 46, 70, 0)
			local d2 = c + V(sx * 40, 52, 0)
			World.rod(m, a, b, 6, gold, { Name = "Handle" })
			World.rod(m, b, d2, 6, gold, { Name = "Handle" })
			World.ball(m, b, 7, gold, { Name = "HandleJoint" })
		end
		local star = World.ball(m, c + V(0, y + 12, 0), 14, P.rare, { Name = "TopMarble", Material = Enum.Material.Neon })
		local light = Instance.new("PointLight")
		light.Color = P.rare
		light.Range = 40
		light.Brightness = 2
		light.Parent = star
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			decor(d :: BasePart)
		end
	end
	local anchor = box(m, CF(c + V(0, 130, 0)), V(1, 1, 1), P.rare, { Name = "TitleAnchor", Transparency = 1, CanCollide = false })
	World.label(anchor, "🏆 THE GRAND PRIX CUP", { width = 90, height = 16, offset = V(0, 0, 0), maxDistance = 2000, gradient = ColorSequence.new(Color3.new(1, 1, 1), P.rare), stroke = 4 })
end

local function buildClouds()
	local f = World.folder("Clouds", root)
	for k = 1, 9 do
		local a = k / 9 * math.pi * 2
		local p = V(-100 + math.cos(a) * 700, 230 + rng:NextNumber(-30, 40), 350 + math.sin(a) * 800)
		World.cloud(f, p, rng:NextNumber(2.2, 3.4), rng)
	end
end

function Lobby.build(): SpawnLocation
	root = World.folder("Lobby", workspace)
	buildTable()
	buildTower()
	buildPackMachine()
	buildShine()
	buildShowcase()
	buildShop()
	buildDaily()
	buildPodium()
	buildBoard()
	buildProps()
	buildTrophy()
	buildClouds()
	-- fall safety: anyone below the deck goes back to spawn
	task.spawn(function()
		while true do
			task.wait(1)
			for _, p in ipairs(Players:GetPlayers()) do
				local ch = p.Character
				local hrp = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp and hrp.Position.Y < DY - 20 then
					hrp.CFrame = spawnLocation.CFrame + V(0, 4, 0)
					hrp.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end
	end)
	return spawnLocation
end

-- Winners' podium: rows = { {name=, id=, mut=} } (places 1..3).
function Lobby.setPodium(rows: { { [string]: any } })
	for place = 1, 3 do
		local slot = podiumSlots[place]
		if slot then
			if slot.built then
				slot.built.model:Destroy()
				slot.built = nil
			end
			local r = rows[place]
			if r then
				local b = MarbleArt.build(r.id, r.mut, 4.6)
				b.model.Parent = root
				MarbleArt.place(b, CF(slot.pos))
				MarbleArt.sparkle(b, r.id, r.mut)
				local def = Config.MarbleById[r.id]
				World.label(b.shell, r.name, { width = 10, height = 2.2, offset = V(0, 4.2, 0), maxDistance = 90, gradient = def and Tiers.gradient(def.tier) or nil })
				slot.built = b
			end
		end
	end
end

-- League board rows: { {name=, pts=} }
function Lobby.setBoard(rows: { { [string]: any } })
	for i = 1, #boardRows do
		local r = rows[i]
		local medal = i == 1 and "🥇" or (i == 2 and "🥈" or (i == 3 and "🥉" or (tostring(i) .. ".")))
		boardRows[i].Text = r and string.format("%s  %s  —  %d pts", medal, r.name, r.pts) or (i == 1 and "Race to get on the board!" or "")
	end
end

function Lobby.spawn(): SpawnLocation
	return spawnLocation
end

return Lobby

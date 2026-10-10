-- Decorating: finds your bakery, guides you there (pink beam + "YOUR BAKERY" marker), then during the build
-- phase gives you an orbit camera around your cake and the decorating tray (shape, tiers, frosting, drips,
-- piping, toppings with size/turn/colour, undo, clear, DONE). Tap the cake to place the selected topping
-- (desktop shows a ghost preview); in the Cake tab, tapping a tier paints it. The server validates everything.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientLib = ReplicatedStorage:WaitForChild("ClientLib")
local Config = require(Shared:WaitForChild("Config"))
local CakeBuilder = require(Shared:WaitForChild("CakeBuilder"))
local Net = require(Shared:WaitForChild("Net"))
local Fmt = require(Shared:WaitForChild("Fmt"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local UI = require(ClientLib:WaitForChild("UI"))
local Sfx = require(ClientLib:WaitForChild("Sfx"))
local Fx = require(ClientLib:WaitForChild("Fx"))
local Own = require(ClientLib:WaitForChild("Own"))
local Widgets = require(ClientLib:WaitForChild("Widgets"))
local Rig = require(ClientLib:WaitForChild("Rig"))

local BuildMode = {}

type D = { [string]: any }

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local buildRemote = Net.event("Build")
local I = Config.Icons

local ctx: Own.Ctx = nil :: any
local state: Instance
local data: D? = nil

-- my station
local station: Model? = nil
local root: CFrame? = nil
local padPos: Vector3? = nil

-- mode
local active = false
local exited = false
local wasBuild = false
local page = "Cake"
local mode = "Frost" -- Frost | Drip | Piping
local target = 0 -- 0 = every tier
local lastColor = "Pink"
local selected = "Cherry"
local sizeIdx = 2
local rot = 0
local tint = "Auto"
local clearArmed = 0
local themeKey = ""

-- camera
local YAW_MAX = math.rad(110)
local yaw, pitch, dist = 0, math.rad(26), 21

-- input
local down: InputObject? = nil
local downPos = Vector2.zero
local lastPos = Vector2.zero
local dragging = false
local rdown = false

-- UI
local tray: Frame
local pages: { [string]: Frame } = {}
local cakeTab: TextButton
local topTab: TextButton
local countLabel: TextLabel
local doneBtn: TextButton
local goBtn: TextButton
local decorateBtn: TextButton
local shapeChips: { [string]: Widgets.Chip } = {}
local tierChips: { Widgets.Chip } = {}
local modeChips: { [string]: Widgets.Chip } = {}
local targetChips: { [number]: Widgets.Chip } = {}
local targetRow: Frame
local swatches: { Widgets.Swatch } = {}
local specialSwatch: { [string]: Widgets.Swatch } = {}
local topCards: { [string]: Widgets.GlyphCard } = {}
local sizeChips: { Widgets.Chip } = {}
local tintRow: ScrollingFrame
local tintSwatches: { Widgets.Swatch } = {}
local rotBtn: TextButton
local clearBtn: TextButton

-- world helpers
local fxFolder = Instance.new("Folder")
fxFolder.Name = "BakeryFx"
fxFolder.Parent = workspace
local pillar: Part
local ring: Part
local tagAnchor: Part
local beam: Beam
local beamEnd: Attachment
local beamStart: Attachment? = nil
local ghost: Model? = nil
local ghostKey = ""
local ghostRig: Rig.Rig? = nil

local function tut(n: number)
	ctx.tut(n)
end

local function phase(): string
	return tostring(state:GetAttribute("Phase") or "Waiting")
end

local function attr(name: string): any
	local st = station
	return if st then st:GetAttribute(name) else nil
end

local function tierCount(): number
	return math.clamp(tonumber(attr("Tiers")) or 2, 1, 4)
end

local function frostList(): { string }
	local out = {}
	local s = attr("Frost")
	if type(s) == "string" then
		for k in string.gmatch(s, "[^,]+") do
			table.insert(out, k)
		end
	end
	return out
end

local function hrp(): BasePart?
	local char = player.Character
	local p = char and char:FindFirstChild("HumanoidRootPart")
	return if p and p:IsA("BasePart") then p :: BasePart else nil
end

local function nearStation(): boolean
	local h = hrp()
	local p = padPos
	return h ~= nil and p ~= nil and (h.Position - p).Magnitude < 22
end

local function invis(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

-- Beacon --------------------------------------------------------------------------------------------------
local function buildBeacon()
	pillar = Instance.new("Part")
	pillar.Name = "Beacon"
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Material = Enum.Material.Neon
	pillar.Color = Config.Palette.pinkDeep
	pillar.Size = Vector3.new(90, 3.2, 3.2)
	pillar.Transparency = 0.55
	invis(pillar)
	ring = Instance.new("Part")
	ring.Name = "BeaconRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = Config.Palette.gold
	ring.Size = Vector3.new(0.2, 8, 8)
	ring.Transparency = 0.35
	invis(ring)
	beamEnd = Instance.new("Attachment")
	beamEnd.Name = "BeamEnd"
	beamEnd.Position = Vector3.new(1.4, 0, 0)
	beamEnd.Parent = ring
	tagAnchor = Instance.new("Part")
	tagAnchor.Name = "BakeryTag"
	tagAnchor.Size = Vector3.new(0.2, 0.2, 0.2)
	tagAnchor.Transparency = 1
	invis(tagAnchor)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Tag"
	bb.Size = UDim2.fromOffset(260, 74)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 1000
	bb.Parent = tagAnchor
	local l = UI.text(bb, "⬇ YOUR BAKERY ⬇", { Size = UDim2.fromScale(1, 1), TextColor3 = Color3.fromRGB(255, 236, 120) })
	l.Name = "Text"
	beam = Instance.new("Beam")
	beam.Name = "GuideBeam"
	beam.Attachment1 = beamEnd
	beam.Color = ColorSequence.new(Config.Palette.pinkDeep, Config.Palette.gold)
	beam.Transparency = NumberSequence.new(0.25)
	beam.LightEmission = 0.8
	beam.Width0 = 0.7
	beam.Width1 = 0.7
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Enabled = false
	beam.Parent = ring
end

local function placeBeacon()
	local p = padPos
	local r = root
	if not p or not r then
		pillar.Parent = nil
		ring.Parent = nil
		tagAnchor.Parent = nil
		return
	end
	pillar.CFrame = CFrame.new(p + Vector3.new(0, 45, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.CFrame = CFrame.new(p + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
	tagAnchor.CFrame = CFrame.new(r.Position + Vector3.new(0, 15, 0))
end

local function refreshStation()
	local folder = workspace:FindFirstChild("Stations")
	local found: Model? = nil
	if folder then
		for _, m in ipairs(folder:GetChildren()) do
			if m:IsA("Model") and m:GetAttribute("OwnerId") == player.UserId then
				found = m :: Model
				break
			end
		end
	end
	if found ~= station then
		station = found
		if found then
			local F = Config.stationCF(tonumber(found:GetAttribute("Index")) or 1)
			root = F * Config.Station.root
			padPos = (F * CFrame.new(Config.Station.pad)).Position
		else
			root, padPos = nil, nil
		end
		placeBeacon()
	end
end

-- Raycasts against my cake body ---------------------------------------------------------------------------
local function bodyParts(): { Instance }
	local st = station
	local cake = st and st:FindFirstChild("Cake")
	local body = cake and cake:FindFirstChild("Body")
	return if body then body:GetChildren() else {}
end

local function castAt(pos: Vector2): RaycastResult?
	local parts = bodyParts()
	if #parts == 0 then
		return nil
	end
	local ray = camera:ScreenPointToRay(pos.X, pos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = parts
	return workspace:Raycast(ray.Origin, ray.Direction * 250, params)
end

local function tierAtWorld(p: Vector3): number
	local r = root
	if not r then
		return 1
	end
	local y = r:PointToObjectSpace(p).Y
	local n = tierCount()
	for i, d in ipairs(CakeBuilder.dims(n)) do
		if y <= d.y0 + d.h + 0.05 then
			return i
		end
	end
	return n
end

-- Actions ------------------------------------------------------------------------------------------------------
local function locked(kind: string, key: string)
	if kind == "color" then
		local def = Config.ColorByKey[key]
		if def and def.pass then
			local pass = Config.Passes[def.pass]
			UI.toast(string.format("%s is in %s %s", def.name, pass.glyph, pass.name), "purple")
			ctx.buy("pass", def.pass)
			return
		end
		UI.toast(string.format("Unlock %s in the Shop for 🪙 %s", if def then def.name else key, Fmt.num(if def then def.price else 0)), "orange")
		ctx.openShop("Colours")
	elseif kind == "shape" or kind == "tier" then
		ctx.openShop("Upgrades")
	elseif kind == "topping" then
		local def = Config.ToppingById[key]
		if def and def.source == "box" then
			UI.toast(def.glyph .. " " .. def.name .. " only comes from Mystery Boxes!", "purple")
			ctx.openBox()
		elseif def and def.source == "vip" then
			ctx.buy("pass", "VIP")
		else
			ctx.openShop("Toppings")
		end
	end
	Sfx.play("error", 0.35)
end

local function frost(tierIdx: number, key: string)
	if not Own.color(data, key) then
		locked("color", key)
		return
	end
	lastColor = key
	buildRemote:FireServer("frost", tierIdx, key)
	Sfx.play("pop", 0.4, 0.8 + math.random() * 0.2)
	local r = root
	if r then
		local n = tierCount()
		local d = CakeBuilder.dims(n)[math.clamp(if tierIdx == 0 then n else tierIdx, 1, n)]
		Fx.burst(r.Position + Vector3.new(0, d.y0 + d.h, 0), { CakeBuilder.color(key, 1), Color3.new(1, 1, 1) }, 8, 0.6)
	end
	tut(1)
end

local function place(hit: RaycastResult)
	local d = data
	local r = root
	if not d or not r then
		return
	end
	local def = Config.ToppingById[selected]
	if not def then
		return
	end
	if not Own.topping(d, selected) then
		locked("topping", selected)
		return
	end
	local count = tonumber(attr("Count")) or 0
	if count >= Own.limit(d) then
		UI.toast("Your cake is full! Get more topping slots in the Shop 🛒", "orange")
		Sfx.play("error", 0.5)
		return
	end
	if def.topOnly and hit.Normal:Dot(r.UpVector) < 0.6 then
		UI.toast(def.glyph .. " " .. def.name .. " goes on TOP of a tier!", "orange")
		Sfx.play("error", 0.4)
		return
	end
	buildRemote:FireServer("place", selected, hit.Position, hit.Normal, rot, sizeIdx, tint)
	Sfx.play("pop", 0.45, 0.9 + math.random() * 0.35)
	Fx.burst(hit.Position + hit.Normal * 0.3, { def.tint or Config.Palette.pink, Config.Palette.cream, Config.Palette.gold }, 5, 0.45)
	tut(2)
end

local function tap(pos: Vector2)
	local hit = castAt(pos)
	if not hit then
		return
	end
	if page == "Toppings" then
		place(hit)
	else
		local t = tierAtWorld(hit.Position)
		if mode == "Frost" then
			target = t
			frost(t, lastColor)
		elseif mode == "Drip" then
			buildRemote:FireServer("drip", if lastColor ~= "" then lastColor else "Chocolate")
			Sfx.play("pop", 0.4)
		else
			buildRemote:FireServer("piping", lastColor)
			Sfx.play("pop", 0.4)
		end
	end
end

-- Ghost preview (mouse only) ----------------------------------------------------------------------------------
local function hideGhost()
	local g = ghost
	if g then
		g.Parent = nil
	end
end

local function ensureGhost(): Model?
	local key = selected .. "|" .. sizeIdx .. "|" .. tint
	if ghost and ghostKey == key then
		return ghost
	end
	if ghost then
		(ghost :: Model):Destroy()
		ghost = nil
	end
	if not Config.ToppingById[selected] then
		return nil
	end
	local m = CakeBuilder.topping(fxFolder, selected, CFrame.new(), Config.Cake.sizes[sizeIdx], tint, { ghost = 0.45, fx = false })
	m.Name = "Ghost"
	ghostRig = Rig.new(m, CFrame.new())
	ghost = m
	ghostKey = key
	return m
end

local function hover(pos: Vector2)
	local r = root
	if not active or page ~= "Toppings" or not r or not Own.topping(data, selected) then
		hideGhost()
		return
	end
	local hit = castAt(pos)
	if not hit then
		hideGhost()
		return
	end
	local def = Config.ToppingById[selected]
	if def and def.topOnly and hit.Normal:Dot(r.UpVector) < 0.6 then
		hideGhost()
		return
	end
	local m = ensureGhost()
	local gr = ghostRig
	if m and gr then
		Rig.pose(gr, CakeBuilder.surfaceCF(r, hit.Position, hit.Normal, rot))
		m.Parent = fxFolder
	end
end

-- Tray --------------------------------------------------------------------------------------------------------------
local function setPage(name: string)
	page = name
	for k, f in pairs(pages) do
		f.Visible = k == name
	end
	cakeTab.Size = if name == "Cake" then UDim2.fromOffset(132, 60) else UDim2.fromOffset(124, 54)
	topTab.Size = if name == "Toppings" then UDim2.fromOffset(132, 60) else UDim2.fromOffset(124, 54)
	if name ~= "Toppings" then
		hideGhost()
	end
end

local function sortedToppings(): { Config.ToppingDef }
	local list = table.clone(Config.Toppings)
	local theme = Config.ThemeByKey[themeKey]
	local d = data
	table.sort(list, function(a: Config.ToppingDef, b: Config.ToppingDef)
		local oa, ob = Own.topping(d, a.id), Own.topping(d, b.id)
		if oa ~= ob then
			return oa
		end
		local ta = theme ~= nil and table.find(theme.toppings, a.id) ~= nil
		local tb = theme ~= nil and table.find(theme.toppings, b.id) ~= nil
		if ta ~= tb then
			return ta
		end
		local ia, ib = Tiers.index[a.tier] or 0, Tiers.index[b.tier] or 0
		if ia ~= ib then
			return if oa then ia > ib else ia < ib
		end
		return a.price < b.price
	end)
	return list
end

local function refreshTray()
	local d = data
	if not d then
		return
	end
	local n = tierCount()
	local frostKeys = frostList()
	local shape = tostring(attr("Shape") or "Round")
	local count = tonumber(attr("Count")) or 0
	local limit = Own.limit(d)
	countLabel.Text = string.format("%s %d/%d", I.toppings, count, limit)
	countLabel.TextColor3 = if count >= limit then Color3.fromRGB(255, 140, 140) else Color3.fromRGB(255, 255, 255)
	local isReady = attr("Ready") == true
	doneBtn.Text = if isReady then "⏳ WAITING" else I.done .. " DONE"
	UI.recolor(doneBtn, if isReady then "grey" else "green")

	for key, chip in pairs(shapeChips) do
		chip.sel.Visible = key == shape
		chip.lock.Visible = not Own.shape(d, key)
	end
	local maxT = Own.maxTiers(d)
	for i, chip in ipairs(tierChips) do
		chip.sel.Visible = i == n
		chip.lock.Visible = i > maxT
	end
	for key, chip in pairs(modeChips) do
		chip.sel.Visible = key == mode
	end
	targetRow.Visible = mode == "Frost"
	if target > n then
		target = 0
	end
	for i, chip in pairs(targetChips) do
		chip.button.Visible = i <= n
		chip.sel.Visible = i == target
	end

	-- which swatch is "current"
	local current: string? = nil
	if mode == "Frost" then
		if target == 0 then
			current = frostKeys[1]
			for _, k in ipairs(frostKeys) do
				if k ~= frostKeys[1] then
					current = nil
					break
				end
			end
		else
			current = frostKeys[target]
		end
	elseif mode == "Drip" then
		current = tostring(attr("Drip") or "None")
	else
		current = tostring(attr("Piping") or "Auto")
	end
	specialSwatch.None.button.Visible = mode == "Drip"
	specialSwatch.Auto.button.Visible = mode == "Piping"
	specialSwatch.None.sel.Visible = current == "None"
	specialSwatch.Auto.sel.Visible = current == "Auto"
	local theme = Config.ThemeByKey[themeKey]
	for _, sw in ipairs(swatches) do
		local owned = Own.color(d, sw.key)
		sw.lock.Visible = not owned
		sw.sel.Visible = sw.key == current
		sw.button.LayoutOrder = (if owned then 0 else 1000) + (if theme and table.find(theme.colors, sw.key) then 0 else 100) + (table.find(Config.Colors, Config.ColorByKey[sw.key]) or 0)
	end

	-- toppings
	for i, def in ipairs(sortedToppings()) do
		local card = topCards[def.id]
		if card then
			local owned = Own.topping(d, def.id)
			card.button.LayoutOrder = i
			card.sel.Visible = def.id == selected
			card.glyph.TextTransparency = if owned then 0 else 0.5
			local isTheme = theme ~= nil and table.find(theme.toppings, def.id) ~= nil
			if owned then
				card.foot.Text = if isTheme then "🎯 THEME" else ""
			elseif def.source == "shop" then
				card.foot.Text = "🔒 " .. Fmt.num(def.price)
			elseif def.source == "box" then
				card.foot.Text = "🎁 Box"
			else
				card.foot.Text = "👑 VIP"
			end
			UI.recolor(card.button, if owned then Tiers.get(def.tier).color else "grey")
		end
	end
	for i, chip in ipairs(sizeChips) do
		chip.sel.Visible = i == sizeIdx
	end
	rotBtn.Text = I.rotate .. " " .. (rot * 360 // Config.Cake.rotSteps) .. "°"
	local sdef = Config.ToppingById[selected]
	tintRow.Visible = sdef ~= nil and sdef.tint ~= nil
	for _, sw in ipairs(tintSwatches) do
		sw.button.Visible = sw.key == "Auto" or Own.color(d, sw.key)
		sw.sel.Visible = sw.key == tint
	end
	clearBtn.Text = if os.clock() < clearArmed then "SURE?" else I.trash
end

local function hrow(parent: Instance, y: number, h: number, x: number?, w: number?): Frame
	local f = UI.frame(parent, { BackgroundTransparency = 1, Position = UDim2.fromOffset(x or 0, y), Size = if w then UDim2.fromOffset(w, h) else UDim2.new(1, -(x or 0), 0, h) })
	UI.list(f, 6, true, Enum.HorizontalAlignment.Left)
	return f
end

local function label(parent: Instance, text: string, x: number, y: number, w: number, h: number): TextLabel
	return UI.text(parent, text, { Font = UI.BODY, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), TextColor3 = Color3.fromRGB(255, 240, 200) })
end

local function buildTray()
	local rootUI = UI.root
	tray = UI.card(rootUI, "pink", { Name = "Tray", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromOffset(1010, 204), Visible = false })

	cakeTab = UI.button(tray, I.cake .. " CAKE", "pink", { Name = "CakeTab", Position = UDim2.fromOffset(10, 12), Size = UDim2.fromOffset(124, 54) })
	topTab = UI.button(tray, I.toppings .. " TOPPINGS", "orange", { Name = "ToppingsTab", Position = UDim2.fromOffset(10, 78), Size = UDim2.fromOffset(124, 54) })
	countLabel = UI.text(tray, "", { Font = UI.BODY, Position = UDim2.fromOffset(10, 146), Size = UDim2.fromOffset(124, 40) })
	cakeTab.MouseButton1Click:Connect(function()
		setPage("Cake")
		refreshTray()
	end)
	topTab.MouseButton1Click:Connect(function()
		setPage("Toppings")
		refreshTray()
	end)

	doneBtn = UI.button(tray, I.done .. " DONE", "green", { Name = "Done", Position = UDim2.fromOffset(870, 12), Size = UDim2.fromOffset(130, 72) })
	doneBtn.MouseButton1Click:Connect(function()
		local isReady = attr("Ready") == true
		buildRemote:FireServer("ready", not isReady)
		if not isReady then
			Sfx.play("unlock", 0.5)
			UI.toast("✅ Done! Waiting for the other bakers...", "green")
			tut(3)
		end
		task.delay(0.3, refreshTray)
	end)
	local walk = UI.button(tray, I.walk .. " WALK", "grey", { Name = "Walk", Position = UDim2.fromOffset(870, 94), Size = UDim2.fromOffset(130, 46) })
	walk.MouseButton1Click:Connect(function()
		exited = true
	end)
	label(tray, if UI.isMobile then "Drag to spin" else "Drag · wheel zoom", 870, 148, 130, 40)

	-- camera buttons above the tray
	local cam = hrow(tray, -62, 56, 1010 - 250, 250)
	local function camBtn(name: string, glyph: string, fn: () -> ())
		local b = UI.button(cam, glyph, "dark", { Name = name, Size = UDim2.fromOffset(56, 56) })
		b.Font = Enum.Font.GothamBold
		b.MouseButton1Click:Connect(fn)
	end
	camBtn("CamLeft", I.left, function()
		yaw = math.clamp(yaw + 0.6, -YAW_MAX, YAW_MAX)
	end)
	camBtn("CamRight", I.right, function()
		yaw = math.clamp(yaw - 0.6, -YAW_MAX, YAW_MAX)
	end)
	camBtn("ZoomIn", I.zoomIn, function()
		dist = math.clamp(dist - 4, 10, 34)
	end)
	camBtn("ZoomOut", I.zoomOut, function()
		dist = math.clamp(dist + 4, 10, 34)
	end)

	local area = UI.frame(tray, { Name = "Pages", BackgroundTransparency = 1, Position = UDim2.fromOffset(146, 8), Size = UDim2.fromOffset(714, 190) })
	local cakePage = UI.frame(area, { Name = "Cake", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	local topPage = UI.frame(area, { Name = "Toppings", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })
	pages.Cake = cakePage
	pages.Toppings = topPage

	-- Cake page: shapes + tiers
	label(cakePage, "SHAPE", 0, 12, 56, 26)
	local shapes = hrow(cakePage, 2, 50, 60, 340)
	for i, s in ipairs(Config.Shapes) do
		local chip = Widgets.chip(shapes, s.glyph, "white", 62, 48, i)
		chip.button.Name = "Shape" .. s.key
		chip.button.Font = Enum.Font.GothamBold
		chip.button.MouseButton1Click:Connect(function()
			if not Own.shape(data, s.key) then
				UI.toast(string.format("%s %s cakes unlock in the Shop for 🪙 %s", s.glyph, s.name, Fmt.num(s.price)), "orange")
				locked("shape", s.key)
				return
			end
			buildRemote:FireServer("shape", s.key)
			Sfx.play("whoosh", 0.35, 1.2)
		end)
		shapeChips[s.key] = chip
	end
	label(cakePage, "TIERS", 404, 12, 56, 26)
	local tiers = hrow(cakePage, 2, 50, 462, 240)
	for i = 1, 4 do
		local chip = Widgets.chip(tiers, tostring(i), "sky", 50, 48, i)
		chip.button.Name = "Tiers" .. i
		chip.button.MouseButton1Click:Connect(function()
			if i > Own.maxTiers(data) then
				UI.toast("🎂 4-tier cakes unlock in the Shop for 🪙 " .. Fmt.num(Config.Cake.tier4Price), "orange")
				locked("tier", "4")
				return
			end
			buildRemote:FireServer("tiers", i)
			Sfx.play("pop", 0.4, 0.8 + i * 0.1)
		end)
		tierChips[i] = chip
	end

	-- modes + paint target
	local modes = hrow(cakePage, 58, 44, 0, 340)
	for i, m in ipairs({ { "Frost", "FROSTING", "pink" }, { "Drip", "DRIP", "orange" }, { "Piping", "PIPING", "purple" } }) do
		local key = m[1]
		local chip = Widgets.chip(modes, m[2], m[3], if i == 1 then 124 else 100, 40, i)
		chip.button.Name = "Mode" .. key
		chip.button.MouseButton1Click:Connect(function()
			mode = key
			refreshTray()
		end)
		modeChips[key] = chip
	end
	targetRow = hrow(cakePage, 58, 44, 350, 360)
	local tl = label(targetRow, "PAINT", 0, 0, 56, 26)
	tl.LayoutOrder = 0
	for i = 0, 4 do
		local chip = Widgets.chip(targetRow, if i == 0 then "ALL" else tostring(i), "teal", if i == 0 then 64 else 44, 40, i + 1)
		chip.button.Name = "Target" .. i
		chip.button.MouseButton1Click:Connect(function()
			target = i
			refreshTray()
		end)
		targetChips[i] = chip
	end

	-- colour swatches
	local sw = UI.scroll(cakePage, {
		Name = "Swatches",
		Position = UDim2.fromOffset(0, 108),
		Size = UDim2.new(1, 0, 0, 80),
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 6,
	})
	UI.list(sw, 8, true, Enum.HorizontalAlignment.Left)
	for _, key in ipairs({ "None", "Auto" }) do
		local s = Widgets.swatch(sw, key, 58, -10)
		s.button.MouseButton1Click:Connect(function()
			if mode == "Drip" and key == "None" then
				buildRemote:FireServer("drip", "None")
			elseif mode == "Piping" and key == "Auto" then
				buildRemote:FireServer("piping", "Auto")
			end
			Sfx.play("pop", 0.35)
		end)
		specialSwatch[key] = s
	end
	for _, def in ipairs(Config.Colors) do
		local s = Widgets.swatch(sw, def.key, 58)
		s.button.MouseButton1Click:Connect(function()
			if not Own.color(data, def.key) then
				locked("color", def.key)
				return
			end
			if mode == "Frost" then
				frost(target, def.key)
			elseif mode == "Drip" then
				lastColor = def.key
				buildRemote:FireServer("drip", def.key)
				Sfx.play("pop", 0.4, 0.9)
			else
				lastColor = def.key
				buildRemote:FireServer("piping", def.key)
				Sfx.play("pop", 0.4, 1.1)
			end
		end)
		table.insert(swatches, s)
	end

	-- Toppings page: cards
	local tc = UI.scroll(topPage, {
		Name = "Cards",
		Size = UDim2.new(1, 0, 0, 124),
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 6,
	})
	UI.list(tc, 8, true, Enum.HorizontalAlignment.Left)
	for i, def in ipairs(Config.Toppings) do
		local card = Widgets.toppingCard(tc, def.id, 92, 110, i)
		card.button.MouseButton1Click:Connect(function()
			if not Own.topping(data, def.id) then
				locked("topping", def.id)
				return
			end
			selected = def.id
			if def.tint == nil then
				tint = "Auto"
			end
			Sfx.play("pop", 0.3, 1.2)
			UI.toast(def.glyph .. " " .. def.name .. (if def.topOnly then " · goes on top" else "") .. " · tap your cake!", Tiers.get(def.tier).color, 1.6)
			refreshTray()
		end)
		topCards[def.id] = card
	end

	local tools = hrow(topPage, 132, 52, 0, 714)
	for i, name in ipairs(Config.Cake.sizeNames) do
		local chip = Widgets.chip(tools, name, "sky", 46, 46, i)
		chip.button.Name = "Size" .. name
		chip.button.MouseButton1Click:Connect(function()
			sizeIdx = i
			refreshTray()
		end)
		sizeChips[i] = chip
	end
	rotBtn = UI.button(tools, I.rotate, "teal", { Name = "Rotate", Size = UDim2.fromOffset(84, 46), LayoutOrder = 10 })
	rotBtn.MouseButton1Click:Connect(function()
		rot = (rot + 1) % Config.Cake.rotSteps
		refreshTray()
	end)
	tintRow = UI.scroll(tools, {
		Name = "Tints",
		Size = UDim2.fromOffset(300, 50),
		LayoutOrder = 20,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 4,
	})
	UI.list(tintRow, 6, true, Enum.HorizontalAlignment.Left)
	local autoT = Widgets.swatch(tintRow, "Auto", 38, -1)
	autoT.button.MouseButton1Click:Connect(function()
		tint = "Auto"
		refreshTray()
	end)
	table.insert(tintSwatches, autoT)
	for i, def in ipairs(Config.Colors) do
		local s = Widgets.swatch(tintRow, def.key, 38, i)
		s.button.MouseButton1Click:Connect(function()
			if Own.color(data, def.key) then
				tint = def.key
				refreshTray()
			end
		end)
		table.insert(tintSwatches, s)
	end
	local undo = UI.button(tools, I.undo, "orange", { Name = "Undo", Size = UDim2.fromOffset(60, 46), LayoutOrder = 30 })
	undo.Font = Enum.Font.GothamBold
	undo.MouseButton1Click:Connect(function()
		buildRemote:FireServer("undo")
		Sfx.play("swipe", 0.4)
	end)
	clearBtn = UI.button(tools, I.trash, "red", { Name = "Clear", Size = UDim2.fromOffset(70, 46), LayoutOrder = 31 })
	clearBtn.MouseButton1Click:Connect(function()
		if os.clock() < clearArmed then
			clearArmed = 0
			buildRemote:FireServer("clear")
			Sfx.play("thud", 0.4)
		else
			clearArmed = os.clock() + 2.5
			UI.toast("Tap 🗑️ again to remove ALL toppings", "red", 2)
		end
		refreshTray()
	end)

	setPage("Cake")

	-- big prompts (outside the tray)
	goBtn = UI.button(rootUI, I.go .. " GO TO MY BAKERY", "pink", { Name = "GoToStation", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -120), Size = UDim2.fromOffset(380, 84), Visible = false })
	goBtn.MouseButton1Click:Connect(function()
		ctx.act("tp")
		Sfx.play("whoosh", 0.5)
		exited = false
	end)
	decorateBtn = UI.button(rootUI, I.cake .. " DECORATE!", "green", { Name = "Decorate", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -120), Size = UDim2.fromOffset(340, 84), Visible = false })
	decorateBtn.MouseButton1Click:Connect(function()
		exited = false
	end)
end

local function setActive(on: boolean)
	active = on
	tray.Visible = on
	if on then
		yaw, pitch, dist = 0, math.rad(26), 21
		Sfx.play("open", 0.5)
		UI.punch(tray, 0.12)
		local theme = Config.ThemeByKey[themeKey]
		if theme then
			UI.toast(theme.glyph .. " Theme: " .. theme.name .. " · look for 🎯 toppings!", "pink", 3)
		end
		refreshTray()
	else
		down = nil
		dragging = false
		rdown = false
		hideGhost()
	end
end

-- API ------------------------------------------------------------------------------------------------------------------
function BuildMode.isActive(): boolean
	return active
end

function BuildMode.camera(): CFrame?
	local r = root
	if not active or not r then
		return nil
	end
	local h = 0
	for i = 1, tierCount() do
		h += Config.Cake.tierH[i] or 0
	end
	local focus = r.Position + Vector3.new(0, h * 0.5 + 0.8, 0)
	local front = (r * CFrame.Angles(0, yaw, 0)).LookVector
	local dir = front * math.cos(pitch) + Vector3.yAxis * math.sin(pitch)
	return CFrame.lookAt(focus + dir * dist, focus)
end

function BuildMode.update(d: D)
	data = d
	if active then
		refreshTray()
	end
end

function BuildMode.onTheme(key: string)
	themeKey = key
end

-- Tip for the HUD tip pill (FTUE), or nil.
function BuildMode.tip(): string?
	local ph = phase()
	local d = data
	local t = if d then d.tut or 0 else 0
	if not station then
		return nil
	end
	if active then
		if t < 1 then
			return "🎨 Tap a colour to frost your cake (or tap a tier to paint it)!"
		elseif t < 2 then
			return "🍒 Open TOPPINGS, then tap your cake to place them!"
		elseif t < 3 then
			return "👆 Drag to spin your cake · press ✅ DONE when you're happy!"
		end
		return nil
	end
	if (ph == "Build" or ph == "Theme") and not nearStation() then
		return "🏃 Run to YOUR bakery: follow the pink beam!"
	end
	if (ph == "Lobby" or ph == "Waiting") and t < 1 then
		return "⏳ A round starts soon! Your bakery has the pink beam ⬇"
	end
	return nil
end

function BuildMode.tick(_dt: number)
	local ph = phase()
	local isBuild = ph == "Build"
	if isBuild and not wasBuild then
		exited = false
		target = 0
		page = "Cake"
		setPage("Cake")
		local tk = state:GetAttribute("Theme")
		if type(tk) == "string" then
			themeKey = tk
		end
	elseif wasBuild and not isBuild then
		local d = data
		if d and (d.tut or 0) == 2 then
			tut(3)
		end
	end
	wasBuild = isBuild
	local near = nearStation()
	local should = isBuild and station ~= nil and not exited and near
	if should ~= active then
		setActive(should)
	end
	goBtn.Visible = (ph == "Build" or ph == "Theme") and station ~= nil and not active and not near
	decorateBtn.Visible = isBuild and station ~= nil and not active and near

	-- beacon
	local show = station ~= nil and not active and (ph == "Waiting" or ph == "Lobby" or ph == "Theme" or ph == "Build")
	local parent: Instance? = if show then fxFolder else nil
	if pillar.Parent ~= parent then
		pillar.Parent = parent
		ring.Parent = parent
		tagAnchor.Parent = parent
	end
	if show then
		local t = os.clock()
		pillar.Transparency = 0.55 + 0.15 * math.sin(t * 3)
		ring.Size = Vector3.new(0.2, 8 + math.sin(t * 4) * 0.8, 8 + math.sin(t * 4) * 0.8)
	end
	local h = hrp()
	local wantBeam = show and (ph == "Theme" or ph == "Build") and h ~= nil and not near
	if wantBeam and h then
		local att = beamStart
		if not att or att.Parent ~= h then
			if att then
				att:Destroy()
			end
			local a = Instance.new("Attachment")
			a.Name = "GuideStart"
			a.Position = Vector3.new(0, -1.5, 0)
			a.Parent = h
			beamStart = a
			beam.Attachment0 = a
		end
	end
	beam.Enabled = wantBeam
	if active and os.clock() < clearArmed + 0.1 then
		clearBtn.Text = if os.clock() < clearArmed then "SURE?" else I.trash
	end
end

function BuildMode.init(c: Own.Ctx, stateFolder: Instance)
	ctx = c
	state = stateFolder
	buildBeacon()
	buildTray()

	task.spawn(function()
		while true do
			refreshStation()
			if active then
				refreshTray()
			end
			task.wait(0.4)
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, gp: boolean)
		if not active or gp then
			return
		end
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			if down then
				return
			end
			down = input
			downPos = Vector2.new(input.Position.X, input.Position.Y)
			lastPos = downPos
			dragging = false
		elseif t == Enum.UserInputType.MouseButton2 then
			rdown = true
			lastPos = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject, _gp: boolean)
		if not active then
			return
		end
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseWheel then
			dist = math.clamp(dist - input.Position.Z * 2.5, 10, 34)
			return
		end
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		local d = down
		local moving = false
		if t == Enum.UserInputType.MouseMovement then
			hover(pos)
			moving = rdown or (d ~= nil and d.UserInputType == Enum.UserInputType.MouseButton1)
		elseif t == Enum.UserInputType.Touch then
			moving = d ~= nil and input == d
		end
		if moving then
			if rdown or (pos - downPos).Magnitude > 12 then
				dragging = true
			end
			if dragging then
				local delta = pos - lastPos
				yaw = math.clamp(yaw - delta.X * 0.009, -YAW_MAX, YAW_MAX)
				pitch = math.clamp(pitch + delta.Y * 0.006, 0.05, 1.2)
				hideGhost()
			end
			lastPos = pos
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject, _gp: boolean)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton2 then
			rdown = false
			return
		end
		local d = down
		if d and (input == d or (t == Enum.UserInputType.MouseButton1 and d.UserInputType == Enum.UserInputType.MouseButton1)) then
			local wasDrag = dragging
			down = nil
			dragging = false
			if active and not wasDrag then
				tap(Vector2.new(input.Position.X, input.Position.Y))
			end
		end
	end)
end

return BuildMode

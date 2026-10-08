-- StarterPlayer.StarterPlayerScripts.Client ("Find the Dragon Eggs")
-- Egg counter on top, icon menu on the left, hints/gifts on the right, radar meter at the bottom.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local SocialService = game:GetService("SocialService")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local camera = workspace.CurrentCamera
local rng = Random.new()

local FONT = Enum.Font.FredokaOne
local okFont, luckiest = pcall(function()
	return Enum.Font.LuckiestGuy
end)
local TITLE = okFont and luckiest or FONT
local BLACK = Color3.fromRGB(20, 20, 30)
local WHITE = Color3.new(1, 1, 1)
local GREEN = Color3.fromRGB(70, 220, 90)
local GOLD = Color3.fromRGB(255, 205, 50)

local function get(key)
	return player:GetAttribute(key) or 0
end

local function action(...)
	remotes.Action:FireServer(...)
end

-- Sound effects come from one uploaded audio sprite (Kenney CC0); each name plays a region of it.
local okSounds, Sounds = pcall(function()
	return require(ReplicatedStorage:WaitForChild("Sounds", 5))
end)
if not okSounds or type(Sounds) ~= "table" then
	Sounds = nil
end
local sfxGroup = Instance.new("SoundGroup")
sfxGroup.Name = "SFX"
sfxGroup.Parent = SoundService
if Sounds then
	task.spawn(function()
		local warm = Instance.new("Sound")
		warm.SoundId = Sounds.Id
		warm.Parent = SoundService
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync({ warm })
		end)
	end)
end
local function sfx(name, volume, pitch)
	local s = Instance.new("Sound")
	s.Volume = volume or 0.5
	s.PlaybackSpeed = pitch or 1
	s.SoundGroup = sfxGroup
	local clip = Sounds and Sounds.Clips[name]
	local life = 3
	if clip then
		s.SoundId = Sounds.Id
		s.PlaybackRegionsEnabled = true
		s.PlaybackRegion = NumberRange.new(clip[1], clip[1] + clip[2])
		life = clip[2] / (pitch or 1) + 2
	else
		s.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	end
	s.Parent = SoundService
	s:Play()
	task.delay(life, function()
		s:Destroy()
	end)
end

-- Background music: licensed adventure tracks from Roblox's APM library, shuffled.
local MUSIC = { 1845266081, 1839807682, 1838005831 } -- Treasure Hunt, Treasure Hunter, Magic Carpet Ride (a)
local MUSIC_VOLUME = 0.22
local music = Instance.new("Sound")
music.Name = "Music"
music.Volume = MUSIC_VOLUME
music.Parent = SoundService
local musicOn = true
task.spawn(function()
	local i = rng:NextInteger(1, #MUSIC)
	while true do
		music.SoundId = "rbxassetid://" .. MUSIC[i]
		music:Play()
		local started = os.clock()
		task.wait(3)
		while music.IsPlaying and os.clock() - started < 400 do
			task.wait(1)
		end
		i = i % #MUSIC + 1
	end
end)

---------------------------------------------------------------------------
-- UI kit (thick outlines + gradients, the standard sim look)
---------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "MainGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(obj, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	c.Parent = obj
	return c
end

local function stroke(obj, thickness, color)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 3
	s.Color = color or BLACK
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = obj
	return s
end

local function gradient(obj, top, bottom)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = 90
	g.Parent = obj
	return g
end

local function shade(c, f)
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

local function text(parent, str, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextScaled = true
	l.TextColor3 = WHITE
	l.TextStrokeTransparency = 0
	l.TextStrokeColor3 = BLACK
	l.Text = str
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

-- Custom icon art (uploaded PNGs listed in ReplicatedStorage.Assets); falls back to an emoji until uploaded
local okAssets, Assets = pcall(function()
	return require(ReplicatedStorage:WaitForChild("Assets", 5))
end)
if not okAssets or type(Assets) ~= "table" then
	Assets = {}
end
local function icon(parent, key, emoji, props)
	local obj
	if Assets[key] then
		obj = Instance.new("ImageLabel")
		obj.BackgroundTransparency = 1
		obj.Image = Assets[key]
		obj.ScaleType = Enum.ScaleType.Fit
	else
		obj = Instance.new("TextLabel")
		obj.BackgroundTransparency = 1
		obj.Font = FONT
		obj.TextScaled = true
		obj.Text = emoji
	end
	for k, v in pairs(props or {}) do
		obj[k] = v
	end
	obj.Parent = parent
	return obj
end
local function setIcon(obj, key, emoji)
	if obj:IsA("ImageLabel") then
		obj.Image = Assets[key] or ""
	else
		obj.Text = emoji
	end
end

local function bubbleButton(parent, str, color, props)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = WHITE
	b.Font = FONT
	b.TextScaled = true
	b.TextColor3 = WHITE
	b.TextStrokeTransparency = 0
	b.TextStrokeColor3 = BLACK
	b.Text = str
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	b.Parent = parent
	corner(b, 14)
	stroke(b, 3)
	gradient(b, color, shade(color, 0.7))
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = b
	return b
end

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local scales = {}
local function punch(obj, amount)
	local sc = scales[obj]
	if not sc then
		sc = Instance.new("UIScale")
		sc.Parent = obj
		scales[obj] = sc
	end
	sc.Scale = 1 + (amount or 0.15)
	tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- hover / press bounce for every button we make
local function juicy(b)
	b.MouseEnter:Connect(function()
		punch(b, 0.06)
	end)
	b.MouseButton1Down:Connect(function()
		punch(b, -0.08)
		sfx("pop", 0.4, rng:NextNumber(0.95, 1.1))
	end)
	return b
end

---------------------------------------------------------------------------
-- Effects layer: floating text, confetti, banner, shake
---------------------------------------------------------------------------
local fxLayer = Instance.new("Frame")
fxLayer.BackgroundTransparency = 1
fxLayer.Size = UDim2.fromScale(1, 1)
fxLayer.ZIndex = 50
fxLayer.Parent = gui

local function floater(str, color, x, y, size)
	local l = text(fxLayer, str, {
		Font = TITLE,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size * 7, size),
		TextColor3 = color,
		Rotation = rng:NextNumber(-12, 12),
		ZIndex = 51,
	})
	punch(l, 0.6)
	tween(l, 1, { Position = UDim2.fromOffset(x + rng:NextNumber(-60, 60), y - 120) })
	tween(l, 1, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(1.05, function()
		l:Destroy()
	end)
end

local function confetti(n)
	local vp = camera.ViewportSize
	for _ = 1, n do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.Size = UDim2.fromOffset(rng:NextInteger(8, 16), rng:NextInteger(8, 16))
		f.BackgroundColor3 = Color3.fromHSV(rng:NextNumber(), 0.8, 1)
		local x = rng:NextNumber(0, vp.X)
		f.Position = UDim2.fromOffset(x, -20)
		f.Rotation = rng:NextNumber(0, 360)
		f.ZIndex = 49
		f.Parent = fxLayer
		local t = rng:NextNumber(1, 2.2)
		tween(f, t, { Position = UDim2.fromOffset(x + rng:NextNumber(-150, 150), vp.Y + 40), Rotation = f.Rotation + rng:NextNumber(-720, 720) },
			Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(t, function()
			f:Destroy()
		end)
	end
end

local shake = 0
RunService:BindToRenderStep("Shake", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if shake > 0.001 then
		camera.CFrame *= CFrame.new(rng:NextNumber(-1, 1) * shake, rng:NextNumber(-1, 1) * shake, 0)
		shake *= math.exp(-dt * 16)
	end
end)
local function kick(s)
	shake = math.min(shake + s, 1.2)
end

local banner = text(gui, "", {
	Font = TITLE,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.32),
	Size = UDim2.fromOffset(640, 80),
	TextTransparency = 1,
	TextStrokeTransparency = 1,
	ZIndex = 60,
})
local bannerToken = 0
local function showBanner(str, color)
	bannerToken += 1
	local my = bannerToken
	banner.Text = str
	banner.TextColor3 = color
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0
	banner.Rotation = rng:NextNumber(-5, 5)
	punch(banner, 0.7)
	task.delay(1.6, function()
		if my == bannerToken then
			tween(banner, 0.3, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
end

---------------------------------------------------------------------------
-- Top: egg counter + zone progress
---------------------------------------------------------------------------
local eggBar = Instance.new("Frame")
eggBar.AnchorPoint = Vector2.new(0.5, 0)
eggBar.Position = UDim2.new(0.5, 0, 0, 10)
eggBar.Size = UDim2.fromOffset(300, 56)
eggBar.BackgroundColor3 = WHITE
eggBar.ClipsDescendants = false
eggBar.Parent = gui
corner(eggBar, 28)
stroke(eggBar, 4)
gradient(eggBar, Color3.fromRGB(80, 70, 110), Color3.fromRGB(40, 34, 60))
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = WHITE
fill.Parent = eggBar
corner(fill, 28)
gradient(fill, Color3.fromRGB(255, 190, 60), Color3.fromRGB(240, 110, 40))
icon(eggBar, "egg", "🥚", { Position = UDim2.fromOffset(-20, -12), Size = UDim2.fromOffset(78, 78), Rotation = -10, ZIndex = 3 })
local countLbl = text(eggBar, "0 / " .. Config.TotalEggs, { Font = TITLE, Position = UDim2.fromOffset(60, 6), Size = UDim2.new(1, -76, 0, 44), ZIndex = 3 })
local zoneLbl = text(gui, "", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70),
	Size = UDim2.fromOffset(320, 26), TextColor3 = Color3.fromRGB(255, 240, 160) })

-- announcement feed under the cash bar
local feed = Instance.new("Frame")
feed.BackgroundTransparency = 1
feed.AnchorPoint = Vector2.new(0.5, 0)
feed.Position = UDim2.new(0.5, 0, 0, 100)
feed.Size = UDim2.fromOffset(620, 120)
feed.Parent = gui
local feedList = Instance.new("UIListLayout")
feedList.HorizontalAlignment = Enum.HorizontalAlignment.Center
feedList.SortOrder = Enum.SortOrder.LayoutOrder
feedList.Padding = UDim.new(0, 4)
feedList.Parent = feed
local feedN = 0
local function notify(str, color)
	feedN += 1
	local l = text(feed, str, { Size = UDim2.new(1, 0, 0, 28), TextColor3 = color or WHITE, LayoutOrder = feedN })
	punch(l, 0.3)
	local kids = {}
	for _, c in ipairs(feed:GetChildren()) do
		if c:IsA("TextLabel") then
			kids[#kids + 1] = c
		end
	end
	if #kids > 4 then
		table.sort(kids, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		kids[1]:Destroy()
	end
	task.delay(5, function()
		if l.Parent then
			tween(l, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
			task.delay(0.45, function()
				l:Destroy()
			end)
		end
	end)
end

---------------------------------------------------------------------------
-- Panels
---------------------------------------------------------------------------
local panels = {}
local function closeAll()
	for _, p in pairs(panels) do
		p.Visible = false
	end
end

local function makePanel(name, title, color, w, h)
	local p = Instance.new("Frame")
	p.Name = name
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Position = UDim2.fromScale(0.5, 0.52)
	p.Size = UDim2.fromOffset(w or 560, h or 400)
	p.BackgroundColor3 = WHITE
	p.Visible = false
	p.ZIndex = 20
	p.Parent = gui
	corner(p, 22)
	stroke(p, 5)
	gradient(p, Color3.fromRGB(70, 80, 120), Color3.fromRGB(35, 40, 70))
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, 56)
	bar.BackgroundColor3 = WHITE
	bar.ZIndex = 21
	bar.Parent = p
	corner(bar, 22)
	stroke(bar, 4)
	gradient(bar, color, shade(color, 0.65))
	text(bar, title, { Font = TITLE, Position = UDim2.fromOffset(16, 6), Size = UDim2.new(1, -90, 0, 44), ZIndex = 22,
		TextXAlignment = Enum.TextXAlignment.Left })
	local x = juicy(bubbleButton(bar, "X", Color3.fromRGB(255, 70, 70), {
		Position = UDim2.new(1, -60, 0, 4), Size = UDim2.fromOffset(48, 48), ZIndex = 22 }))
	x.Activated:Connect(function()
		p.Visible = false
	end)
	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(16, 68)
	body.Size = UDim2.new(1, -32, 1, -84)
	body.ZIndex = 21
	body.Parent = p
	panels[name] = p
	return p, body
end

local function open(name)
	local p = panels[name]
	local was = p.Visible
	closeAll()
	p.Visible = not was
	if p.Visible then
		punch(p, 0.12)
		sfx("open", 0.45)
	end
end

---------------------------------------------------------------------------
-- Egg lookups (eggs live in workspace.Eggs as models named Egg<id>)
---------------------------------------------------------------------------
local eggFolder = workspace:WaitForChild("Eggs")
local function eggModel(id)
	return eggFolder:FindFirstChild("Egg" .. id)
end
local function eggCenter(id)
	local m = eggModel(id)
	return m and m.PrimaryPart and m.PrimaryPart.Position
end
local function foundSet()
	return Config.ParseFound(player:GetAttribute("Found"))
end
local function zoneAt(pos)
	if pos.Z < 0 then
		return 0
	end
	return math.clamp(math.floor(pos.Z / 200) + 1, 1, #Config.Zones)
end
local function myRoot()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end
local function zoneFound(found, z)
	local n = 0
	for slot = 1, 20 do
		if found[(z - 1) * 20 + slot] then
			n += 1
		end
	end
	return n
end
local function nearestUnfound(found, maxZone, count)
	local root = myRoot()
	if not root then
		return {}
	end
	local list = {}
	for id, def in ipairs(Config.Eggs) do
		if not found[id] and def.Zone <= maxZone then
			local c = eggCenter(id)
			if c then
				table.insert(list, { Id = id, D = (c - root.Position).Magnitude })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.D < b.D
	end)
	local out = {}
	for i = 1, math.min(count, #list) do
		out[i] = list[i]
	end
	return out
end

---------------------------------------------------------------------------
-- Shop (tabs: Passes / Hints / Boosts)
---------------------------------------------------------------------------
local shopPanel, shopBody = makePanel("Shop", "🛒 SHOP", Color3.fromRGB(255, 170, 40), 600, 440)
local tabRow = Instance.new("Frame")
tabRow.BackgroundTransparency = 1
tabRow.Size = UDim2.new(1, 0, 0, 44)
tabRow.ZIndex = 21
tabRow.Parent = shopBody
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 10)
tabLayout.Parent = tabRow
local pages = {}
local tabs = {}
local function showTab(name)
	for n, pg in pairs(pages) do
		pg.Visible = n == name
		tabs[n].BackgroundTransparency = n == name and 0 or 0.4
	end
end
local function card(page, item, kind, color)
	local c = Instance.new("Frame")
	c.BackgroundColor3 = WHITE
	c.ZIndex = 22
	c.Parent = page
	corner(c, 16)
	stroke(c, 3)
	gradient(c, color, shade(color, 0.6))
	icon(c, item.Img, item.Icon, { Position = UDim2.new(0.5, -36, 0, -10), Size = UDim2.fromOffset(72, 72), ZIndex = 23 })
	text(c, item.Name, { Position = UDim2.fromOffset(6, 58), Size = UDim2.new(1, -12, 0, 26), ZIndex = 23 })
	text(c, item.Desc, { Position = UDim2.fromOffset(8, 86), Size = UDim2.new(1, -16, 0, 34), ZIndex = 23,
		TextColor3 = Color3.fromRGB(230, 230, 240), TextWrapped = true })
	local buy = juicy(bubbleButton(c, "R$ " .. item.Price, GREEN, {
		Position = UDim2.new(0, 10, 1, -48), Size = UDim2.new(1, -20, 0, 40), ZIndex = 23 }))
	buy.Activated:Connect(function()
		action("Buy", kind, item.Key)
	end)
	if kind == "Pass" then
		local function refresh()
			if player:GetAttribute("Pass_" .. item.Key) then
				buy.Text = "OWNED"
				buy.Active = false
			end
		end
		player:GetAttributeChangedSignal("Pass_" .. item.Key):Connect(refresh)
		refresh()
	end
end
local tabDefs = {
	{ Name = "Passes", Label = "⭐ Passes", Color = Color3.fromRGB(150, 90, 255) },
	{ Name = "Hints", Label = "🔍 Hints", Color = Color3.fromRGB(60, 170, 255) },
	{ Name = "Boosts", Label = "⚡ Boosts", Color = Color3.fromRGB(255, 120, 60) },
}
for _, t in ipairs(tabDefs) do
	local b = juicy(bubbleButton(tabRow, t.Label, t.Color, { Size = UDim2.fromOffset(170, 42), ZIndex = 22 }))
	b.Activated:Connect(function()
		showTab(t.Name)
	end)
	tabs[t.Name] = b
	local page = Instance.new("ScrollingFrame")
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.Position = UDim2.fromOffset(0, 54)
	page.Size = UDim2.new(1, 0, 1, -54)
	page.ScrollBarThickness = 6
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.CanvasSize = UDim2.new()
	page.ZIndex = 21
	page.Parent = shopBody
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(170, 190)
	grid.CellPadding = UDim2.fromOffset(12, 12)
	grid.Parent = page
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.Parent = page
	pages[t.Name] = page
end
for _, gp in ipairs(Config.GamePasses) do
	card(pages.Passes, gp, "Pass", Color3.fromRGB(150, 90, 255))
end
for _, prod in ipairs(Config.Products) do
	card(pages[prod.Tab], prod, "Product", prod.Tab == "Hints" and Color3.fromRGB(60, 150, 240) or Color3.fromRGB(255, 120, 60))
end
showTab("Passes")
local function openShop(tab)
	if not shopPanel.Visible then
		open("Shop")
	end
	showTab(tab or "Passes")
end

---------------------------------------------------------------------------
-- Egg index (tabs per zone, clues for eggs you haven't found)
---------------------------------------------------------------------------
local _, idxBody = makePanel("Index", "📖 EGG INDEX", Color3.fromRGB(70, 150, 255), 680, 470)
local zoneTabs = Instance.new("Frame")
zoneTabs.BackgroundTransparency = 1
zoneTabs.Size = UDim2.new(1, 0, 0, 40)
zoneTabs.ZIndex = 21
zoneTabs.Parent = idxBody
local ztLayout = Instance.new("UIListLayout")
ztLayout.FillDirection = Enum.FillDirection.Horizontal
ztLayout.Padding = UDim.new(0, 6)
ztLayout.Parent = zoneTabs
local idxScroll = Instance.new("ScrollingFrame")
idxScroll.BackgroundTransparency = 1
idxScroll.BorderSizePixel = 0
idxScroll.Position = UDim2.fromOffset(0, 48)
idxScroll.Size = UDim2.new(1, 0, 1, -48)
idxScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
idxScroll.CanvasSize = UDim2.new()
idxScroll.ScrollBarThickness = 6
idxScroll.ZIndex = 21
idxScroll.Parent = idxBody
local idxGrid = Instance.new("UIGridLayout")
idxGrid.CellSize = UDim2.fromOffset(118, 116)
idxGrid.CellPadding = UDim2.fromOffset(8, 8)
idxGrid.SortOrder = Enum.SortOrder.LayoutOrder
idxGrid.Parent = idxScroll
local idxCards = {}
local idxZone = 1
local zoneTabBtns = {}
for id, def in ipairs(Config.Eggs) do
	local r = Config.Rarities[def.RarityIndex]
	local c = Instance.new("Frame")
	c.BackgroundColor3 = WHITE
	c.ZIndex = 22
	c.LayoutOrder = id
	c.Visible = def.Zone == 1
	c.Parent = idxScroll
	corner(c, 14)
	stroke(c, 3)
	gradient(c, r.Color, shade(r.Color, 0.45))
	local eggIcon = Instance.new("Frame")
	eggIcon.AnchorPoint = Vector2.new(0.5, 0)
	eggIcon.Position = UDim2.new(0.5, 0, 0, 6)
	eggIcon.Size = UDim2.fromOffset(34, 44)
	eggIcon.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	eggIcon.ZIndex = 23
	eggIcon.Parent = c
	corner(eggIcon, 22)
	stroke(eggIcon, 2)
	local q = text(eggIcon, "?", { Size = UDim2.fromScale(1, 1), ZIndex = 24 })
	local nameL = text(c, "???", { Position = UDim2.fromOffset(4, 52), Size = UDim2.new(1, -8, 0, 22), ZIndex = 23 })
	local sub = text(c, def.Rarity, { Position = UDim2.fromOffset(4, 76), Size = UDim2.new(1, -8, 0, 32), ZIndex = 23,
		TextColor3 = Color3.fromRGB(235, 235, 235), TextWrapped = true })
	idxCards[id] = { Frame = c, Icon = eggIcon, Q = q, Name = nameL, Sub = sub }
end
local function refreshIndex()
	local found = foundSet()
	for id, cardT in pairs(idxCards) do
		local def = Config.Eggs[id]
		cardT.Frame.Visible = def.Zone == idxZone
		if found[id] then
			cardT.Name.Text = def.Name
			cardT.Sub.Text = def.Rarity .. " ✅"
			local m = eggModel(id)
			cardT.Icon.BackgroundColor3 = m and m.PrimaryPart and m.PrimaryPart.Color or WHITE
			cardT.Q.Text = ""
		else
			cardT.Name.Text = "???"
			local m = eggModel(id)
			local clue = m and m:GetAttribute("Clue")
			cardT.Sub.Text = "💡 " .. (clue and Config.Clues[clue] or "Somewhere...")
			cardT.Icon.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
			cardT.Q.Text = "?"
		end
	end
	for z, b in pairs(zoneTabBtns) do
		b.Text = Config.Zones[z].Emoji .. " " .. zoneFound(found, z) .. "/20"
		b.BackgroundTransparency = z == idxZone and 0 or 0.4
	end
end
for z, zone in ipairs(Config.Zones) do
	local b = juicy(bubbleButton(zoneTabs, zone.Emoji, zone.Color, { Size = UDim2.fromOffset(120, 38), ZIndex = 22 }))
	b.Activated:Connect(function()
		idxZone = z
		refreshIndex()
	end)
	zoneTabBtns[z] = b
end
player:GetAttributeChangedSignal("Found"):Connect(refreshIndex)
refreshIndex()

---------------------------------------------------------------------------
-- Teleport panel
---------------------------------------------------------------------------
local _, tpBody = makePanel("Teleport", "🌀 TELEPORT", Color3.fromRGB(90, 200, 220), 440, 470)
local tpList = Instance.new("UIListLayout")
tpList.Padding = UDim.new(0, 8)
tpList.Parent = tpBody
local tpBtns = {}
local hubBtn = juicy(bubbleButton(tpBody, "🏠 Hub", Color3.fromRGB(120, 200, 120), { Size = UDim2.new(1, 0, 0, 56), ZIndex = 22 }))
hubBtn.Activated:Connect(function()
	action("Teleport", 0)
	panels.Teleport.Visible = false
end)
for z, zone in ipairs(Config.Zones) do
	local b = juicy(bubbleButton(tpBody, "", zone.Color, { Size = UDim2.new(1, 0, 0, 56), ZIndex = 22 }))
	b.Activated:Connect(function()
		if get("Unlocked") >= z then
			action("Teleport", z)
			panels.Teleport.Visible = false
		else
			openShop("Boosts")
		end
	end)
	tpBtns[z] = b
end
local function refreshTeleport()
	local found = foundSet()
	for z, b in ipairs(tpBtns) do
		local zone = Config.Zones[z]
		if get("Unlocked") >= z then
			b.Text = zone.Emoji .. " " .. zone.Name .. "  " .. zoneFound(found, z) .. "/20"
		else
			b.Text = "🔒 " .. zone.Name .. " (find " .. zone.Need .. ")"
		end
	end
end
player:GetAttributeChangedSignal("Unlocked"):Connect(refreshTeleport)
player:GetAttributeChangedSignal("Found"):Connect(refreshTeleport)
refreshTeleport()

---------------------------------------------------------------------------
-- Left menu
---------------------------------------------------------------------------
local menu = Instance.new("Frame")
menu.BackgroundTransparency = 1
menu.AnchorPoint = Vector2.new(0, 0.5)
menu.Position = UDim2.new(0, 14, 0.5, 0)
menu.Size = UDim2.fromOffset(84, 380)
menu.Parent = gui
local menuList = Instance.new("UIListLayout")
menuList.Padding = UDim.new(0, 12)
menuList.Parent = menu
local function menuButton(img, emoji, label, color)
	local b = juicy(bubbleButton(menu, "", color, { Size = UDim2.fromOffset(80, 80) }))
	icon(b, img, emoji, { Position = UDim2.fromOffset(2, -14), Size = UDim2.new(1, -4, 0, 66) })
	text(b, label, { Position = UDim2.new(0, -4, 1, -26), Size = UDim2.new(1, 8, 0, 24) })
	return b
end
local shopBtn = menuButton("shop", "🛒", "SHOP", Color3.fromRGB(255, 170, 40))
local indexBtn = menuButton("index", "📖", "INDEX", Color3.fromRGB(70, 150, 255))
local tpBtn = menuButton("teleport", "🌀", "TELEPORT", Color3.fromRGB(90, 200, 220))
local dailyBtn = menuButton("daily", "📅", "DAILY", Color3.fromRGB(255, 80, 120))
shopBtn.Activated:Connect(function()
	openShop("Passes")
end)
indexBtn.Activated:Connect(function()
	local root = myRoot()
	if root and zoneAt(root.Position) > 0 then
		idxZone = zoneAt(root.Position)
	end
	refreshIndex()
	open("Index")
end)
tpBtn.Activated:Connect(function()
	refreshTeleport()
	open("Teleport")
end)
dailyBtn.Activated:Connect(function()
	action("Daily")
end)
local function badge(parent, str)
	local b = text(parent, str, { Position = UDim2.new(1, -18, 0, -10), Size = UDim2.fromOffset(28, 28), ZIndex = 5,
		BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(255, 40, 60) })
	corner(b, 14)
	stroke(b, 2)
	return b
end
local saleBadge = badge(shopBtn, "%")
local dailyBadge = badge(dailyBtn, "!")

---------------------------------------------------------------------------
-- Right side: hint button, free hint gift, glow, radar
---------------------------------------------------------------------------
local right = Instance.new("Frame")
right.BackgroundTransparency = 1
right.AnchorPoint = Vector2.new(1, 0.5)
right.Position = UDim2.new(1, -14, 0.5, 0)
right.Size = UDim2.fromOffset(120, 400)
right.Parent = gui
local rightList = Instance.new("UIListLayout")
rightList.Padding = UDim.new(0, 12)
rightList.HorizontalAlignment = Enum.HorizontalAlignment.Right
rightList.Parent = right
local hintBtn = juicy(bubbleButton(right, "", Color3.fromRGB(60, 170, 255), { Size = UDim2.fromOffset(110, 110) }))
icon(hintBtn, "hint", "🔍", { Position = UDim2.fromOffset(8, -18), Size = UDim2.new(1, -16, 0, 84) })
text(hintBtn, "HINT", { Position = UDim2.new(0, -4, 1, -32), Size = UDim2.new(1, 8, 0, 28) })
local hintCount = badge(hintBtn, "0")
hintCount.Size = UDim2.fromOffset(40, 34)
hintCount.Position = UDim2.new(1, -28, 0, -12)
hintCount.BackgroundColor3 = Color3.fromRGB(255, 160, 30)
hintBtn.Activated:Connect(function()
	action("Hint")
end)
local giftBtn = juicy(bubbleButton(right, "", Color3.fromRGB(255, 90, 160), { Size = UDim2.fromOffset(96, 96) }))
icon(giftBtn, "gift", "🎁", { Position = UDim2.fromOffset(6, -16), Size = UDim2.new(1, -12, 0, 74) })
local giftLbl = text(giftBtn, "", { Position = UDim2.new(0, -4, 1, -32), Size = UDim2.new(1, 8, 0, 28) })
giftBtn.Activated:Connect(function()
	action("Gift")
end)
local glowBtn = juicy(bubbleButton(right, Assets.glow and "    GLOW" or "✨ GLOW", Color3.fromRGB(255, 200, 60), { Size = UDim2.fromOffset(110, 50) }))
if Assets.glow then
	icon(glowBtn, "glow", "✨", { Position = UDim2.fromOffset(-18, -18), Size = UDim2.fromOffset(52, 52), Rotation = -12 })
end
glowBtn.Activated:Connect(function()
	action("Buy", "Product", "Glow")
end)
local radarBtn = juicy(bubbleButton(right, Assets.radar and "    RADAR" or "📡 RADAR", Color3.fromRGB(150, 90, 255), { Size = UDim2.fromOffset(110, 50) }))
if Assets.radar then
	icon(radarBtn, "radar", "📡", { Position = UDim2.fromOffset(-18, -18), Size = UDim2.fromOffset(52, 52), Rotation = -12 })
end
radarBtn.Activated:Connect(function()
	action("Buy", "Pass", "Radar")
end)

-- music on/off (bottom left)
local musicBtn = juicy(bubbleButton(gui, Assets.music and "" or "🎵", Color3.fromRGB(80, 150, 255), {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -14), Size = UDim2.fromOffset(56, 56) }))
local musicIcon = icon(musicBtn, "music", "", { Size = UDim2.fromScale(1, 1) })
musicBtn.Activated:Connect(function()
	musicOn = not musicOn
	music.Volume = musicOn and MUSIC_VOLUME or 0
	if Assets.music then
		setIcon(musicIcon, musicOn and "music" or "mute", "")
	else
		musicBtn.Text = musicOn and "🎵" or "🔇"
	end
end)

-- radar meter (bottom center); a locked teaser for players without the pass
local radar = Instance.new("Frame")
radar.AnchorPoint = Vector2.new(0.5, 1)
radar.Position = UDim2.new(0.5, 0, 1, -16)
radar.Size = UDim2.fromOffset(360, 54)
radar.BackgroundColor3 = WHITE
radar.Parent = gui
corner(radar, 27)
stroke(radar, 4)
gradient(radar, Color3.fromRGB(70, 70, 100), Color3.fromRGB(35, 35, 55))
local radarFill = Instance.new("Frame")
radarFill.Size = UDim2.fromScale(0.1, 1)
radarFill.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
radarFill.Parent = radar
corner(radarFill, 27)
local radarLbl = text(radar, "", { Font = TITLE, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 1, -12), ZIndex = 3 })
local radarClick = Instance.new("TextButton")
radarClick.BackgroundTransparency = 1
radarClick.Text = ""
radarClick.Size = UDim2.fromScale(1, 1)
radarClick.ZIndex = 4
radarClick.Parent = radar
radarClick.Activated:Connect(function()
	if not player:GetAttribute("Pass_Radar") then
		action("Buy", "Pass", "Radar")
	end
end)

local tip = text(gui, "Eggs are hidden EVERYWHERE • click or touch them • stuck? press HINT 🔍",
	{ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -80), Size = UDim2.fromOffset(700, 26),
		TextColor3 = Color3.fromRGB(255, 240, 150) })
task.delay(30, function()
	tip:Destroy()
end)

---------------------------------------------------------------------------
-- Offer pop-ups
---------------------------------------------------------------------------
local offer, offerBody = makePanel("Offer", "🔥 LIMITED OFFER 🔥", Color3.fromRGB(255, 60, 120), 420, 320)
local offerTitle = text(offerBody, "", { Size = UDim2.new(1, 0, 0, 50), TextColor3 = GOLD, ZIndex = 22 })
local offerPitch = text(offerBody, "", { Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 56), TextWrapped = true, ZIndex = 22 })
local offerTimer = text(offerBody, "", { Position = UDim2.fromOffset(0, 114), Size = UDim2.new(1, 0, 0, 26),
	TextColor3 = Color3.fromRGB(255, 120, 120), ZIndex = 22 })
local offerBuy = juicy(bubbleButton(offerBody, "BUY", GREEN, { Position = UDim2.new(0.5, -140, 0, 152), Size = UDim2.fromOffset(280, 62), ZIndex = 22 }))
local offerIcon = icon(offer, "starter", "🎒", { Position = UDim2.fromOffset(-34, -40), Size = UDim2.fromOffset(110, 110),
	Rotation = -14, ZIndex = 30 })
local currentOffer
local offerEnds = 0
local function showOffer(o)
	if not o or offer.Visible then
		return
	end
	local item = o.Kind == "Pass" and Config.Find(Config.GamePasses, o.Key) or Config.Find(Config.Products, o.Key)
	if not item or (o.Kind == "Pass" and player:GetAttribute("Pass_" .. o.Key)) then
		return
	end
	currentOffer = o
	offerTitle.Text = o.Title
	setIcon(offerIcon, item.Img, item.Icon)
	offerPitch.Text = o.Pitch
	offerBuy.Text = "BUY NOW  R$ " .. item.Price
	offerEnds = os.clock() + 300
	closeAll()
	offer.Visible = true
	punch(offer, 0.3)
	sfx("offer", 0.6)
end
offerBuy.Activated:Connect(function()
	if currentOffer then
		action("Buy", currentOffer.Kind, currentOffer.Key)
	end
	offer.Visible = false
end)
task.spawn(function()
	task.wait(Config.FirstOfferDelay)
	local i = 1
	while true do
		showOffer(Config.Offers[i])
		i = i % #Config.Offers + 1
		task.wait(Config.OfferInterval)
	end
end)

-- invite friends nudge
task.delay(180, function()
	local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
	if ok and can then
		pcall(SocialService.PromptGameInvite, SocialService, player)
	end
end)

---------------------------------------------------------------------------
-- Hints: a glowing beam from you to the egg + a marker over it
---------------------------------------------------------------------------
local hintToken = 0
local hintParts = {}
local function clearHint()
	for _, p in ipairs(hintParts) do
		p:Destroy()
	end
	hintParts = {}
end
local function showHint(id)
	clearHint()
	hintToken += 1
	local my = hintToken
	local m = eggModel(id)
	local root = myRoot()
	if not m or not m.PrimaryPart or not root then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Parent = m.PrimaryPart
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 0.6
	beam.Width1 = 0.6
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = 3
	beam.TextureSpeed = 2
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 230, 90), Color3.fromRGB(255, 120, 200))
	beam.Transparency = NumberSequence.new(0.2)
	beam.Parent = root
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(90, 90)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true -- the one marker that should show through walls
	bb.Adornee = m.PrimaryPart
	bb.Parent = gui
	local arrow = text(bb, "⬇️", { Size = UDim2.fromScale(1, 1) })
	local dist = text(bb, "", { Position = UDim2.new(0, -30, 1, -4), Size = UDim2.new(1, 60, 0, 26), TextColor3 = GOLD })
	hintParts = { a0, a1, beam, bb }
	sfx("rare", 0.5, 1.2)
	showBanner("🔍 FOLLOW THE BEAM!", Color3.fromRGB(255, 230, 90))
	task.spawn(function()
		local started = os.clock()
		while my == hintToken and os.clock() - started < Config.HintTime do
			if foundSet()[id] or not a0.Parent then
				break
			end
			local r = myRoot()
			if r then
				dist.Text = math.floor((r.Position - m.PrimaryPart.Position).Magnitude) .. " studs"
			end
			arrow.Position = UDim2.fromOffset(0, math.sin(os.clock() * 6) * 8)
			task.wait()
		end
		if my == hintToken then
			clearHint()
		end
	end)
end

---------------------------------------------------------------------------
-- Egg Glow: nearby eggs get a marker that shows through walls
---------------------------------------------------------------------------
local glowMarks = {}
local function clearGlow()
	for _, g in pairs(glowMarks) do
		g:Destroy()
	end
	glowMarks = {}
end
task.spawn(function()
	while true do
		task.wait(1)
		local active = get("GlowUntil") > workspace:GetServerTimeNow()
		if not active then
			if next(glowMarks) then
				clearGlow()
			end
		else
			local found = foundSet()
			local want = {}
			for _, e in ipairs(nearestUnfound(found, get("Unlocked"), 5)) do
				want[e.Id] = true
				if not glowMarks[e.Id] then
					local m = eggModel(e.Id)
					if m and m.PrimaryPart then
						local bb = Instance.new("BillboardGui")
						bb.Size = UDim2.fromOffset(46, 46)
						bb.AlwaysOnTop = true
						bb.Adornee = m.PrimaryPart
						bb.Parent = gui
						if Assets.glow then
							icon(bb, "glow", "✨", { Size = UDim2.fromScale(1, 1) })
						else
							text(bb, "✨", { Size = UDim2.fromScale(1, 1) })
						end
						glowMarks[e.Id] = bb
					end
				end
			end
			for id, g in pairs(glowMarks) do
				if not want[id] then
					g:Destroy()
					glowMarks[id] = nil
				end
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Found eggs turn into ghosts (only for you); gates open (only for you)
---------------------------------------------------------------------------
local ghosted = {}
local function refreshEggs()
	local found = foundSet()
	for id in pairs(found) do
		if not ghosted[id] then
			local m = eggModel(id)
			if m then
				ghosted[id] = true
				for _, d in ipairs(m:GetDescendants()) do
					if d:IsA("BasePart") then
						d.Transparency = 0.8
						d.CanTouch = false
					elseif d:IsA("ParticleEmitter") or d:IsA("PointLight") then
						d.Enabled = false
					elseif d:IsA("ClickDetector") then
						d.MaxActivationDistance = 0
					end
				end
			end
		end
	end
end
player:GetAttributeChangedSignal("Found"):Connect(refreshEggs)
eggFolder.ChildAdded:Connect(function()
	task.defer(refreshEggs)
end)
refreshEggs()

local function refreshGates()
	local unlocked = get("Unlocked")
	local count = get("FoundCount")
	for _, gate in ipairs(CollectionService:GetTagged("Gate")) do
		local z = gate:GetAttribute("Zone") or 99
		local open = unlocked >= z
		gate.CanCollide = not open
		gate.Transparency = open and 0.92 or 0.55
		local bb = gate:FindFirstChildOfClass("BillboardGui")
		if bb then
			local first = bb:FindFirstChildOfClass("TextLabel")
			if open then
				bb.Enabled = false
			elseif first then
				first.Text = "🔒 FIND " .. (gate:GetAttribute("Need") or 0) .. " EGGS (" .. count .. ")"
			end
		end
	end
end
player:GetAttributeChangedSignal("Unlocked"):Connect(refreshGates)
player:GetAttributeChangedSignal("FoundCount"):Connect(refreshGates)
CollectionService:GetInstanceAddedSignal("Gate"):Connect(function()
	task.defer(refreshGates)
end)
refreshGates()

---------------------------------------------------------------------------
-- Double jump (pass)
---------------------------------------------------------------------------
local airJumped = false
UserInputService.JumpRequest:Connect(function()
	if not player:GetAttribute("Pass_DoubleJump") then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local state = hum:GetState()
	if state == Enum.HumanoidStateType.Freefall and not airJumped then
		airJumped = true
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
		sfx("pop", 0.4, 1.4)
	end
end)
local function hookLanding(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if hum then
		hum.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
				airJumped = false
			end
		end)
	end
end
player.CharacterAdded:Connect(hookLanding)
if player.Character then
	task.spawn(hookLanding, player.Character)
end

---------------------------------------------------------------------------
-- Zone tracking: banner + color tint when you walk into a new zone
---------------------------------------------------------------------------
local tint = Lighting:WaitForChild("ZoneTint", 10)
local currentZone = -1
local lastFind = os.clock()
local nudged = false

---------------------------------------------------------------------------
-- Live updates
---------------------------------------------------------------------------
local shownCount = 0
RunService.RenderStepped:Connect(function(dt)
	local now = workspace:GetServerTimeNow()
	local found = foundSet()
	-- rolling egg counter + progress fill
	local target = get("FoundCount")
	if shownCount ~= target then
		shownCount += (target - shownCount) * math.min(dt * 8, 1)
		if math.abs(target - shownCount) < 0.05 then
			shownCount = target
		end
		countLbl.Text = math.floor(shownCount + 0.5) .. " / " .. Config.TotalEggs
		fill.Size = UDim2.fromScale(math.max(0.12, shownCount / Config.TotalEggs), 1)
	end
	hintCount.Text = tostring(get("Hints"))
	-- zone tracking
	local root = myRoot()
	if root then
		local z = zoneAt(root.Position)
		if z ~= currentZone then
			currentZone = z
			if z == 0 then
				if tint then
					tween(tint, 1.2, { TintColor = WHITE })
				end
			else
				local zone = Config.Zones[z]
				showBanner(zone.Emoji .. " " .. string.upper(zone.Name), zone.Color)
				sfx("bell", 0.35)
				if tint then
					tween(tint, 1.2, { TintColor = zone.Tint })
				end
			end
		end
		if z == 0 then
			zoneLbl.Text = "🏠 Hub • walk forward to start hunting!"
		else
			zoneLbl.Text = Config.Zones[z].Emoji .. " " .. Config.Zones[z].Name .. "  " .. zoneFound(found, z) .. "/20"
		end
	end
	-- gift
	local giftLeft = get("GiftAt") - now
	if giftLeft <= 0 then
		giftLbl.Text = "FREE!"
		giftBtn.Rotation = math.sin(os.clock() * 10) * 6
	else
		giftLbl.Text = string.format("%d:%02d", math.floor(giftLeft / 60), math.floor(giftLeft % 60))
		giftBtn.Rotation = 0
	end
	dailyBadge.Visible = now - get("LastDaily") >= 86400
	saleBadge.Rotation = math.sin(os.clock() * 4) * 15
	-- glow timer
	local glowLeft = get("GlowUntil") - now
	if glowLeft > 0 then
		glowBtn.Text = string.format(Assets.glow and "    %d:%02d" or "✨ %d:%02d", math.floor(glowLeft / 60), math.floor(glowLeft % 60))
	else
		glowBtn.Text = Assets.glow and "    GLOW" or "✨ GLOW"
	end
	radarBtn.Visible = not player:GetAttribute("Pass_Radar")
	-- hint button pulses when you've been stuck a while
	if os.clock() - lastFind > 120 and currentZone > 0 then
		hintBtn.Rotation = math.sin(os.clock() * 8) * 5
		if not nudged then
			nudged = true
			if get("Hints") > 0 then
				notify("Stuck? Press HINT 🔍 to find the closest egg!", GOLD)
			else
				showOffer({ Kind = "Product", Key = "Hints3", Title = "STUCK?", Pitch = "Grab 3 hints and find eggs FAST!" })
			end
		end
	else
		hintBtn.Rotation = 0
	end
	-- offer countdown
	if offer.Visible then
		offerIcon.Rotation = -14 + math.sin(os.clock() * 3) * 6
		local left = math.max(0, offerEnds - os.clock())
		offerTimer.Text = string.format("⏰ ENDS IN %d:%02d", math.floor(left / 60), math.floor(left % 60))
	end
end)

-- radar meter: hot/cold to the nearest egg in the zone you're in
task.spawn(function()
	while true do
		task.wait(0.25)
		local root = myRoot()
		if not player:GetAttribute("Pass_Radar") then
			radarLbl.Text = "📡 EGG RADAR 🔒  tap to unlock"
			radarFill.Size = UDim2.fromScale(0.12, 1)
			radarFill.BackgroundColor3 = Color3.fromRGB(120, 120, 140)
		elseif root then
			local found = foundSet()
			local list = nearestUnfound(found, get("Unlocked"), 1)
			local e = list[1]
			if not e then
				radarLbl.Text = "📡 No eggs left here!"
				radarFill.Size = UDim2.fromScale(1, 1)
			else
				local heat = math.clamp(1 - e.D / 120, 0.05, 1)
				tween(radarFill, 0.25, { Size = UDim2.fromScale(heat, 1) })
				local label, color
				if e.D < 15 then
					label, color = "🔥🔥 BURNING HOT!", Color3.fromRGB(255, 60, 60)
				elseif e.D < 35 then
					label, color = "🔥 HOT", Color3.fromRGB(255, 130, 40)
				elseif e.D < 70 then
					label, color = "🌤️ WARM", Color3.fromRGB(255, 210, 60)
				else
					label, color = "❄️ COLD", Color3.fromRGB(80, 160, 255)
				end
				radarLbl.Text = label
				radarFill.BackgroundColor3 = color
			end
		end
	end
end)

-- unfound eggs nearby gently bob and spin
local eggBase = {}
RunService.RenderStepped:Connect(function()
	local root = myRoot()
	if not root then
		return
	end
	local t = os.clock()
	for _, m in ipairs(eggFolder:GetChildren()) do
		local id = m:GetAttribute("EggId")
		local body = m.PrimaryPart
		if id and body and not ghosted[id] then
			if not eggBase[m] then
				eggBase[m] = m:GetPivot()
			end
			local base = eggBase[m]
			if (base.Position - root.Position).Magnitude < 70 then
				m:PivotTo(base * CFrame.new(0, math.sin(t * 2 + id) * 0.15, 0) * CFrame.Angles(0, t * 1.2 + id, 0))
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Server effects
---------------------------------------------------------------------------
local function center()
	local vp = camera.ViewportSize
	return vp.X / 2, vp.Y * 0.45
end

remotes:WaitForChild("Fx").OnClientEvent:Connect(function(kind, a, b)
	if kind == "Toast" then
		notify(a, WHITE)
		sfx("toast", 0.4)
	elseif kind == "Announce" then
		notify(a, b)
		sfx("bell", 0.45)
	elseif kind == "Found" then
		local def = Config.Eggs[a]
		if not def then
			return
		end
		lastFind = os.clock()
		nudged = false
		local r = Config.Rarities[def.RarityIndex]
		showBanner("FOUND " .. string.upper(def.Name) .. "!", def.RarityIndex == 7 and Color3.fromRGB(200, 90, 255) or r.Color)
		local x, y = center()
		floater("+1 🥚  " .. b .. "/" .. Config.TotalEggs, GOLD, x, y + 60, 50)
		punch(eggBar, 0.25)
		sfx("grab", 0.6, 1.1)
		sfx("coins", 0.4, 1.2)
		for i = 0, 3 do
			task.delay(i * 0.07, function()
				sfx("chip", 0.3, 1 + i * 0.15)
			end)
		end
		confetti(20 + def.RarityIndex * 12)
		kick(0.2 + def.RarityIndex * 0.08)
		if def.RarityIndex >= 4 then
			sfx("rare", 0.7)
			notify(def.Rarity .. " egg! ✨", r.Color)
		end
	elseif kind == "ZoneDone" then
		local zone = Config.Zones[a]
		showBanner("🏆 " .. string.upper(zone.Name) .. " COMPLETE! +SPEED", GOLD)
		sfx("win", 0.8)
		confetti(150)
		kick(1)
	elseif kind == "Unlocked" then
		local zone = Config.Zones[a]
		task.delay(1.4, function()
			showBanner("🔓 " .. string.upper(zone.Name) .. " UNLOCKED!", zone.Color)
			sfx("rebirth", 0.7)
			confetti(100)
			notify("Open TELEPORT 🌀 to jump there!", WHITE)
		end)
	elseif kind == "Hint" then
		showHint(a)
	elseif kind == "NoHints" then
		sfx("error", 0.5)
		showOffer({ Kind = "Product", Key = "Hints10", Title = "OUT OF HINTS!", Pitch = "Get 10 hints, or wait for the free gift 🎁" })
	elseif kind == "GotHints" then
		local x, y = center()
		floater("+" .. a .. " 🔍 HINT" .. (a > 1 and "S" or ""), Color3.fromRGB(120, 200, 255), x, y, 60)
		punch(hintBtn, 0.3)
		sfx("kaching", 0.5)
		confetti(30)
	elseif kind == "Lava" then
		showBanner("🔥 TOO HOT!", Color3.fromRGB(255, 100, 40))
		sfx("error", 0.6)
		kick(0.8)
	elseif kind == "Thanks" then
		showBanner("THANK YOU! 💖", Color3.fromRGB(255, 120, 200))
		sfx("thanks", 0.7)
		sfx("kaching", 0.5)
		confetti(120)
	elseif kind == "Welcome" then
		if a then
			task.delay(4, function()
				showBanner("🐉 FIND ALL 100 DRAGON EGGS!", GOLD)
			end)
			task.delay(20, function()
				showOffer(Config.Offers[1])
			end)
		end
	end
end)

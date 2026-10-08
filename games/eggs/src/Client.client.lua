-- StarterPlayer.StarterPlayerScripts.Client ("Steal a Dragon Egg")
-- Simulator-style UI: cash bar on top, icon menu on the left, gifts on the right, tabbed shop.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local SocialService = game:GetService("SocialService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local camera = workspace.CurrentCamera
local rng = Random.new()

local FONT = Enum.Font.FredokaOne
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
	end)
	return b
end

local function sound(id, volume, pitch)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.5
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	task.delay(4, function()
		s:Destroy()
	end)
end
local SND_PING = "rbxasset://sounds/electronicpingshort.wav"
local SND_CLICK = "rbxasset://sounds/clickfast.wav"
local SND_WHOOSH = "rbxasset://sounds/swoosh.wav"

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
-- Top: cash bar + income
---------------------------------------------------------------------------
local cashBar = Instance.new("Frame")
cashBar.AnchorPoint = Vector2.new(0.5, 0)
cashBar.Position = UDim2.new(0.5, 0, 0, 10)
cashBar.Size = UDim2.fromOffset(280, 56)
cashBar.BackgroundColor3 = WHITE
cashBar.Parent = gui
corner(cashBar, 28)
stroke(cashBar, 4)
gradient(cashBar, Color3.fromRGB(90, 230, 100), Color3.fromRGB(30, 150, 50))
local cashIcon = text(cashBar, "💵", { Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(44, 44) })
local cashLbl = text(cashBar, "$0", { Position = UDim2.fromOffset(56, 6), Size = UDim2.new(1, -110, 0, 44) })
local plusBtn = juicy(bubbleButton(cashBar, "+", Color3.fromRGB(255, 200, 40), {
	Position = UDim2.new(1, -50, 0, 6), Size = UDim2.fromOffset(44, 44) }))
local incomeLbl = text(gui, "+$0/s", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70),
	Size = UDim2.fromOffset(200, 26), TextColor3 = Color3.fromRGB(150, 255, 150) })
local _ = cashIcon

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
	text(bar, title, { Position = UDim2.fromOffset(16, 6), Size = UDim2.new(1, -90, 0, 44), ZIndex = 22,
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
		sound(SND_CLICK, 0.4, 1.2)
	end
end

---------------------------------------------------------------------------
-- Shop (tabs: Passes / Cash / Boosts)
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
	text(c, item.Icon, { Position = UDim2.new(0.5, -28, 0, 6), Size = UDim2.fromOffset(56, 52), ZIndex = 23 })
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
	{ Name = "Cash", Label = "💵 Cash", Color = Color3.fromRGB(60, 200, 90) },
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
	card(pages[prod.Tab], prod, "Product", prod.Tab == "Cash" and Color3.fromRGB(60, 190, 90) or Color3.fromRGB(255, 120, 60))
end
showTab("Passes")
local function openShop(tab)
	if not shopPanel.Visible then
		open("Shop")
	end
	showTab(tab or "Passes")
end
plusBtn.Activated:Connect(function()
	openShop("Cash")
end)

---------------------------------------------------------------------------
-- Rebirth panel
---------------------------------------------------------------------------
local _, rebBody = makePanel("Rebirth", "🔄 REBIRTH", Color3.fromRGB(190, 90, 255), 460, 330)
local rebInfo = text(rebBody, "", { Size = UDim2.new(1, 0, 0, 120), TextWrapped = true, ZIndex = 22 })
local rebBtn = juicy(bubbleButton(rebBody, "REBIRTH", Color3.fromRGB(190, 90, 255), {
	Position = UDim2.new(0.5, -130, 0, 140), Size = UDim2.fromOffset(260, 64), ZIndex = 22 }))
text(rebBody, "Resets cash and eggs. Keeps passes.", { Position = UDim2.fromOffset(0, 214), Size = UDim2.new(1, 0, 0, 24),
	TextColor3 = Color3.fromRGB(210, 210, 230), ZIndex = 22 })
rebBtn.Activated:Connect(function()
	action("Rebirth")
end)

---------------------------------------------------------------------------
-- Index panel (egg collection)
---------------------------------------------------------------------------
local _, idxBody = makePanel("Index", "📖 EGG INDEX", Color3.fromRGB(70, 150, 255), 600, 440)
local idxScroll = Instance.new("ScrollingFrame")
idxScroll.BackgroundTransparency = 1
idxScroll.BorderSizePixel = 0
idxScroll.Size = UDim2.fromScale(1, 1)
idxScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
idxScroll.CanvasSize = UDim2.new()
idxScroll.ScrollBarThickness = 6
idxScroll.ZIndex = 21
idxScroll.Parent = idxBody
local idxGrid = Instance.new("UIGridLayout")
idxGrid.CellSize = UDim2.fromOffset(128, 120)
idxGrid.CellPadding = UDim2.fromOffset(10, 10)
idxGrid.Parent = idxScroll
local idxCards = {}
for _, e in ipairs(Config.Eggs) do
	local r = Config.Rarity(e.Rarity)
	local c = Instance.new("Frame")
	c.BackgroundColor3 = WHITE
	c.ZIndex = 22
	c.Parent = idxScroll
	corner(c, 14)
	stroke(c, 3)
	gradient(c, r.Color, shade(r.Color, 0.45))
	local eggIcon = Instance.new("Frame")
	eggIcon.AnchorPoint = Vector2.new(0.5, 0)
	eggIcon.Position = UDim2.new(0.5, 0, 0, 8)
	eggIcon.Size = UDim2.fromOffset(40, 52)
	eggIcon.BackgroundColor3 = e.Color
	eggIcon.ZIndex = 23
	eggIcon.Parent = c
	corner(eggIcon, 26)
	stroke(eggIcon, 2)
	local nameL = text(c, "???", { Position = UDim2.fromOffset(4, 64), Size = UDim2.new(1, -8, 0, 24), ZIndex = 23 })
	text(c, e.Rarity .. " • $" .. Config.Format(e.Income) .. "/s", { Position = UDim2.fromOffset(4, 90), Size = UDim2.new(1, -8, 0, 20),
		ZIndex = 23, TextColor3 = Color3.fromRGB(230, 230, 230) })
	idxCards[e.Name] = { Icon = eggIcon, Name = nameL }
end
local function refreshIndex()
	local found = {}
	for name in string.gmatch(player:GetAttribute("Discovered") or "", "[^|]+") do
		found[name] = true
	end
	for name, c in pairs(idxCards) do
		c.Name.Text = found[name] and name or "???"
		c.Icon.BackgroundTransparency = found[name] and 0 or 0.85
	end
end
player:GetAttributeChangedSignal("Discovered"):Connect(refreshIndex)
refreshIndex()

---------------------------------------------------------------------------
-- Left menu
---------------------------------------------------------------------------
local menu = Instance.new("Frame")
menu.BackgroundTransparency = 1
menu.AnchorPoint = Vector2.new(0, 0.5)
menu.Position = UDim2.new(0, 14, 0.5, 0)
menu.Size = UDim2.fromOffset(84, 360)
menu.Parent = gui
local menuList = Instance.new("UIListLayout")
menuList.Padding = UDim.new(0, 12)
menuList.Parent = menu
local function menuButton(icon, label, color)
	local b = juicy(bubbleButton(menu, "", color, { Size = UDim2.fromOffset(80, 80) }))
	text(b, icon, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 0, 46) })
	text(b, label, { Position = UDim2.new(0, -4, 1, -26), Size = UDim2.new(1, 8, 0, 24) })
	return b
end
local shopBtn = menuButton("🛒", "SHOP", Color3.fromRGB(255, 170, 40))
local rebirthBtn = menuButton("🔄", "REBIRTH", Color3.fromRGB(190, 90, 255))
local indexBtn = menuButton("📖", "INDEX", Color3.fromRGB(70, 150, 255))
local dailyBtn = menuButton("📅", "DAILY", Color3.fromRGB(255, 80, 120))
shopBtn.Activated:Connect(function()
	openShop("Passes")
end)
rebirthBtn.Activated:Connect(function()
	open("Rebirth")
end)
indexBtn.Activated:Connect(function()
	open("Index")
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
-- Right side: free gift, server luck, lock status
---------------------------------------------------------------------------
local right = Instance.new("Frame")
right.BackgroundTransparency = 1
right.AnchorPoint = Vector2.new(1, 0.5)
right.Position = UDim2.new(1, -14, 0.5, 0)
right.Size = UDim2.fromOffset(110, 330)
right.Parent = gui
local rightList = Instance.new("UIListLayout")
rightList.Padding = UDim.new(0, 12)
rightList.HorizontalAlignment = Enum.HorizontalAlignment.Right
rightList.Parent = right
local giftBtn = juicy(bubbleButton(right, "", Color3.fromRGB(255, 90, 160), { Size = UDim2.fromOffset(100, 100) }))
text(giftBtn, "🎁", { Size = UDim2.new(1, 0, 0, 56) })
local giftLbl = text(giftBtn, "", { Position = UDim2.new(0, -4, 1, -34), Size = UDim2.new(1, 8, 0, 30) })
giftBtn.Activated:Connect(function()
	action("Gift")
end)
local luckLbl = text(right, "", { Size = UDim2.fromOffset(110, 44), BackgroundTransparency = 0,
	BackgroundColor3 = Color3.fromRGB(60, 200, 90), Visible = false })
corner(luckLbl, 12)
stroke(luckLbl, 3)
local boostBtn = juicy(bubbleButton(right, "🍀 LUCK", Color3.fromRGB(60, 200, 90), { Size = UDim2.fromOffset(100, 50) }))
boostBtn.Activated:Connect(function()
	openShop("Boosts")
end)

-- bottom status: lock + carrying
local status = text(gui, "", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.fromOffset(520, 40), Visible = false })
local hint = text(gui, "Hold E on conveyor eggs to BUY • step on the green pad to COLLECT • steal eggs from other bases!",
	{ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -70), Size = UDim2.fromOffset(700, 26),
		TextColor3 = Color3.fromRGB(255, 240, 150) })
task.delay(25, function()
	hint:Destroy()
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
	offerTitle.Text = item.Icon .. " " .. o.Title .. " " .. item.Icon
	offerPitch.Text = o.Pitch
	offerBuy.Text = "BUY NOW  R$ " .. item.Price
	offerEnds = os.clock() + 300
	closeAll()
	offer.Visible = true
	punch(offer, 0.3)
	sound(SND_WHOOSH, 0.8, 1.2)
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
task.delay(150, function()
	local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
	if ok and can then
		pcall(SocialService.PromptGameInvite, SocialService, player)
	end
end)

---------------------------------------------------------------------------
-- Live updates
---------------------------------------------------------------------------
local shownCash = 0
local brokeCount = 0
RunService.RenderStepped:Connect(function(dt)
	local now = workspace:GetServerTimeNow()
	-- rolling cash counter
	local target = get("Cash")
	if shownCash ~= target then
		shownCash += (target - shownCash) * math.min(dt * 10, 1)
		if math.abs(target - shownCash) < 1 then
			shownCash = target
		end
		cashLbl.Text = "$" .. Config.Format(shownCash)
	end
	incomeLbl.Text = "+$" .. Config.Format(get("Income")) .. "/s"
	-- gift
	local giftLeft = get("GiftAt") - now
	if giftLeft <= 0 then
		giftLbl.Text = "CLAIM!"
		giftBtn.Rotation = math.sin(os.clock() * 10) * 6
	else
		giftLbl.Text = string.format("%d:%02d", math.floor(giftLeft / 60), math.floor(giftLeft % 60))
		giftBtn.Rotation = 0
	end
	dailyBadge.Visible = now - get("LastDaily") >= 86400
	saleBadge.Rotation = math.sin(os.clock() * 4) * 15
	-- server luck
	local luckLeft = (workspace:GetAttribute("LuckUntil") or 0) - now
	luckLbl.Visible = luckLeft > 0
	if luckLeft > 0 then
		luckLbl.Text = string.format("🍀 x3 %d:%02d", math.floor(luckLeft / 60), math.floor(luckLeft % 60))
	end
	-- bottom status
	local carrying = player:GetAttribute("Carrying") or ""
	local lockLeft = get("LockedUntil") - now
	if carrying ~= "" then
		status.Visible = true
		status.Text = "🏃 RUN HOME with " .. carrying .. "!"
		status.TextColor3 = Color3.fromHSV((os.clock() * 2) % 1, 0.6, 1)
	elseif lockLeft > 0 then
		status.Visible = true
		status.Text = "🔒 Base locked " .. math.ceil(lockLeft) .. "s"
		status.TextColor3 = Color3.fromRGB(120, 190, 255)
	else
		status.Visible = false
	end
	-- offer countdown
	if offer.Visible then
		local left = math.max(0, offerEnds - os.clock())
		offerTimer.Text = string.format("⏰ ENDS IN %d:%02d", math.floor(left / 60), math.floor(left % 60))
	end
	-- rebirth info
	local reb = get("Rebirths")
	rebInfo.Text = "Rebirth " .. reb .. " → " .. (reb + 1) .. "\nIncome x" .. Config.RebirthMult(reb) .. " → x" .. Config.RebirthMult(reb + 1)
		.. "\nCost: $" .. Config.Format(Config.RebirthCost(reb))
end)

-- my own laser door never blocks me
local myDoor
RunService.Heartbeat:Connect(function()
	if not myDoor or myDoor:GetAttribute("OwnerId") ~= player.UserId then
		myDoor = nil
		local w = workspace:FindFirstChild("World")
		if w then
			for _, d in ipairs(w:GetChildren()) do
				if d.Name == "LaserDoor" and d:GetAttribute("OwnerId") == player.UserId then
					myDoor = d
				end
			end
		end
	end
	if myDoor then
		myDoor.CanCollide = false
	end
end)

-- show Steal on other people's eggs and Sell on mine
local function setupPrompt(p)
	if not p:IsA("ProximityPrompt") then
		return
	end
	local egg = p.Parent
	local function apply()
		local mine = egg:GetAttribute("OwnerId") == player.UserId
		if p.Name == "Steal" then
			p.Enabled = not mine
		elseif p.Name == "Sell" then
			p.Enabled = mine
		end
	end
	apply()
	egg:GetAttributeChangedSignal("OwnerId"):Connect(apply)
end
for _, d in ipairs(workspace:GetDescendants()) do
	setupPrompt(d)
end
workspace.DescendantAdded:Connect(setupPrompt)

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
		sound(SND_CLICK, 0.4, 0.8)
	elseif kind == "Announce" then
		notify(a, b)
		sound(SND_PING, 0.4, 1.4)
	elseif kind == "Collect" then
		local x, y = center()
		floater("+$" .. Config.Format(a), Color3.fromRGB(120, 255, 120), x, y, 70)
		punch(cashBar, 0.25)
		confetti(math.clamp(math.floor(math.log10(a + 1) * 10), 10, 80))
		for i = 0, 4 do
			task.delay(i * 0.05, function()
				sound(SND_PING, 0.35, 1.2 + i * 0.15)
			end)
		end
		kick(0.3)
	elseif kind == "Bought" then
		local r = Config.Rarity(b)
		showBanner("GOT " .. string.upper(a) .. "!", r.Color)
		sound(SND_WHOOSH, 0.7, 1.3)
		local _, ri = Config.Rarity(b)
		if ri >= 4 then
			confetti(60)
			kick(0.5)
		end
	elseif kind == "Broke" then
		notify("Need $" .. Config.Format(a) .. "!", Color3.fromRGB(255, 120, 120))
		punch(cashBar, 0.2)
		brokeCount += 1
		if brokeCount % 3 == 0 then
			showOffer({ Kind = "Product", Key = "CashM", Title = "NEED CASH?", Pitch = "Grab a Bag of Cash and buy that egg!" })
		end
	elseif kind == "StealStart" then
		showBanner("🦹 STOLEN! RUN HOME!", Color3.fromRGB(255, 80, 80))
		sound(SND_WHOOSH, 0.9, 0.8)
		kick(0.4)
	elseif kind == "StealSuccess" then
		showBanner("✅ " .. a .. " IS YOURS!", Color3.fromRGB(120, 255, 120))
		confetti(80)
		kick(0.5)
	elseif kind == "Stolen" then
		showBanner("🚨 " .. a .. " STOLE YOUR " .. string.upper(b) .. "! 🚨", Color3.fromRGB(255, 60, 60))
		notify("Touch them to get it back! Lock your base next time 🔒", Color3.fromRGB(255, 200, 200))
		kick(0.8)
		task.delay(2.5, function()
			showOffer({ Kind = "Product", Key = "Lock", Title = "PROTECT YOUR EGGS", Pitch = "Lock your base for 2 minutes instantly!" })
		end)
	elseif kind == "Retrieved" then
		showBanner("🛡️ GOT " .. string.upper(a) .. " BACK!", Color3.fromRGB(120, 200, 255))
		confetti(30)
	elseif kind == "Locked" then
		notify("🔒 Base locked for " .. a .. "s", Color3.fromRGB(120, 190, 255))
	elseif kind == "Rebirth" then
		showBanner("🔄 REBIRTH " .. a .. "!!!", Color3.fromRGB(200, 120, 255))
		confetti(150)
		kick(1)
		sound(SND_WHOOSH, 1, 0.6)
		panels.Rebirth.Visible = false
	elseif kind == "Thanks" then
		showBanner("THANK YOU! 💖", Color3.fromRGB(255, 120, 200))
		confetti(120)
	elseif kind == "Welcome" then
		task.delay(6, function()
			showOffer(Config.Offers[1])
		end)
	end
end)

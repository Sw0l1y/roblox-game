-- StarterPlayer.StarterPlayerScripts.Client ("Grow a Crystal Garden")
-- Simulator-style UI: coins bar + teleports + event bar on top, icon menu on the left, gift/weather on the right,
-- seed hotbar at the bottom (tap a soil tile to plant). Weather effects are drawn here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local SocialService = game:GetService("SocialService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
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
local PINK = Color3.fromRGB(255, 110, 190)
local GRAY = Color3.fromRGB(120, 120, 140)

local function get(key)
	return player:GetAttribute(key) or 0
end

local function action(...)
	remotes.Action:FireServer(...)
end

local function crystalKey(name)
	return string.lower(string.match(name, "^%S+") or name)
end

local function parseCounts(str)
	local t = {}
	for name, n in string.gmatch(str or "", "([^=|]+)=(%d+)") do
		t[name] = tonumber(n)
	end
	return t
end

---------------------------------------------------------------------------
-- Sound: one uploaded SFX sprite (Kenney CC0) + licensed music
---------------------------------------------------------------------------
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
local function sfx(name, volume, pitch, parent)
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
	if parent then
		s.RollOffMaxDistance = 250
		s.RollOffMinDistance = 20
	end
	s.Parent = parent or SoundService
	s:Play()
	task.delay(life, function()
		s:Destroy()
	end)
end

-- Background music: licensed tracks from Roblox's APM library, shuffled.
local MUSIC = { 1838596678, 1841593944, 1841594035, 1838612295 } -- Pixie Dust, Enchanted Kingdom, Mischievous Elves, Happiness Is Brighter
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

-- crystal picture: uploaded art if we have it, else a glowing gem shape in the crystal's color
local function gem(parent, def, props)
	if Assets[crystalKey(def.Name)] then
		return icon(parent, crystalKey(def.Name), "💎", props)
	end
	local f = Instance.new("Frame")
	f.BackgroundColor3 = def.Color
	f.Rotation = 45
	for k, v in pairs(props or {}) do
		f[k] = v
	end
	f.Parent = parent
	local inner = Instance.new("Frame")
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(0.62, 0.62)
	inner.BorderSizePixel = 0
	inner.BackgroundColor3 = WHITE
	inner.ZIndex = f.ZIndex
	inner.Parent = f
	corner(inner, 6)
	gradient(inner, WHITE, def.Color)
	corner(f, 8)
	stroke(f, 3)
	gradient(f, def.Color:Lerp(WHITE, 0.5), shade(def.Color, 0.6))
	-- keep the gem inside its box when rotated
	local sc = Instance.new("UIScale")
	sc.Scale = 0.7
	sc.Parent = f
	return f
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

local function recolor(b, color)
	local g = b:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = ColorSequence.new(color, shade(color, 0.7))
	end
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
-- own ScreenGui (no UIScale) so pixel positions from the viewport line up
local fxGui = Instance.new("ScreenGui")
fxGui.Name = "FxGui"
fxGui.ResetOnSpawn = false
fxGui.IgnoreGuiInset = true
fxGui.DisplayOrder = 5
fxGui.Parent = player:WaitForChild("PlayerGui")
local fxLayer = Instance.new("Frame")
fxLayer.BackgroundTransparency = 1
fxLayer.Size = UDim2.fromScale(1, 1)
fxLayer.ZIndex = 50
fxLayer.Parent = fxGui

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

local function confetti(n, palette)
	local vp = camera.ViewportSize
	for _ = 1, n do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.Size = UDim2.fromOffset(rng:NextInteger(8, 16), rng:NextInteger(8, 16))
		f.BackgroundColor3 = palette and palette[rng:NextInteger(1, #palette)] or Color3.fromHSV(rng:NextNumber(), 0.7, 1)
		local x = rng:NextNumber(0, vp.X)
		f.Position = UDim2.fromOffset(x, -20)
		f.Rotation = rng:NextNumber(0, 360)
		f.ZIndex = 49
		f.Parent = fxLayer
		corner(f, 3)
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
	Position = UDim2.fromScale(0.5, 0.36),
	Size = UDim2.fromOffset(680, 80),
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
	task.delay(1.8, function()
		if my == bannerToken then
			tween(banner, 0.3, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
end

---------------------------------------------------------------------------
-- Top: coins bar, teleports, event bar
---------------------------------------------------------------------------
local coinBar = Instance.new("Frame")
coinBar.AnchorPoint = Vector2.new(0.5, 0)
coinBar.Position = UDim2.new(0.5, 0, 0, 10)
coinBar.Size = UDim2.fromOffset(280, 56)
coinBar.BackgroundColor3 = WHITE
coinBar.Parent = gui
corner(coinBar, 28)
stroke(coinBar, 4)
gradient(coinBar, Color3.fromRGB(255, 215, 80), Color3.fromRGB(230, 140, 20))
icon(coinBar, "coins", "💰", { Position = UDim2.fromOffset(-16, -10), Size = UDim2.fromOffset(74, 74), Rotation = -8 })
local coinLbl = text(coinBar, "$0", { Font = TITLE, Position = UDim2.fromOffset(56, 6), Size = UDim2.new(1, -110, 0, 44) })
local plusBtn = juicy(bubbleButton(coinBar, Assets.plus and "" or "+", GREEN, {
	Position = UDim2.new(1, -50, 0, 6), Size = UDim2.fromOffset(44, 44) }))
if Assets.plus then
	icon(plusBtn, "plus", "+", { Size = UDim2.fromScale(1, 1) })
end

local tpRow = Instance.new("Frame")
tpRow.BackgroundTransparency = 1
tpRow.AnchorPoint = Vector2.new(0.5, 0)
tpRow.Position = UDim2.new(0.5, 0, 0, 74)
tpRow.Size = UDim2.fromOffset(372, 42)
tpRow.Parent = gui
local tpLayout = Instance.new("UIListLayout")
tpLayout.FillDirection = Enum.FillDirection.Horizontal
tpLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tpLayout.Padding = UDim.new(0, 8)
tpLayout.Parent = tpRow
local tpGarden = juicy(bubbleButton(tpRow, "🏡 GARDEN", Color3.fromRGB(90, 200, 120), { Size = UDim2.fromOffset(118, 40) }))
local tpSeeds = juicy(bubbleButton(tpRow, "🌱 SEEDS", Color3.fromRGB(80, 170, 255), { Size = UDim2.fromOffset(118, 40) }))
local tpSell = juicy(bubbleButton(tpRow, "💰 SELL", Color3.fromRGB(255, 170, 40), { Size = UDim2.fromOffset(118, 40) }))

local eventBar = Instance.new("TextButton")
eventBar.AutoButtonColor = false
eventBar.AnchorPoint = Vector2.new(0.5, 0)
eventBar.Position = UDim2.new(0.5, 0, 0, 122)
eventBar.Size = UDim2.fromOffset(400, 34)
eventBar.BackgroundColor3 = WHITE
eventBar.Text = ""
eventBar.Parent = gui
corner(eventBar, 17)
stroke(eventBar, 3)
local eventGrad = gradient(eventBar, Color3.fromRGB(110, 90, 170), Color3.fromRGB(60, 45, 110))
local eventLbl = text(eventBar, "", { Position = UDim2.fromOffset(10, 3), Size = UDim2.new(1, -20, 1, -6) })

-- announcement feed under the event bar
local feed = Instance.new("Frame")
feed.BackgroundTransparency = 1
feed.AnchorPoint = Vector2.new(0.5, 0)
feed.Position = UDim2.new(0.5, 0, 0, 164)
feed.Size = UDim2.fromOffset(640, 130)
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
	p.Position = UDim2.fromScale(0.5, 0.54)
	p.Size = UDim2.fromOffset(w or 560, h or 400)
	p.BackgroundColor3 = WHITE
	p.Visible = false
	p.ZIndex = 20
	p.Parent = gui
	corner(p, 22)
	stroke(p, 5)
	gradient(p, Color3.fromRGB(85, 70, 130), Color3.fromRGB(40, 32, 75))
	local fit = Instance.new("UISizeConstraint")
	fit.MaxSize = Vector2.new(w or 560, h or 400)
	fit.Parent = p
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

-- scale panels down on small (phone) screens
local uiScale = Instance.new("UIScale")
uiScale.Parent = gui
local function fitScreen()
	local vp = camera.ViewportSize
	uiScale.Scale = math.clamp(math.min(vp.X / 1000, vp.Y / 640), 0.55, 1)
end
fitScreen()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitScreen)

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

local function scroller(parent, cell, pad)
	local sf = Instance.new("ScrollingFrame")
	sf.BackgroundTransparency = 1
	sf.BorderSizePixel = 0
	sf.Size = UDim2.fromScale(1, 1)
	sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sf.CanvasSize = UDim2.new()
	sf.ScrollBarThickness = 6
	sf.ZIndex = 21
	sf.Parent = parent
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = cell
	grid.CellPadding = pad or UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = sf
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, 6)
	p.PaddingLeft = UDim.new(0, 6)
	p.Parent = sf
	return sf
end

---------------------------------------------------------------------------
-- Shop (tabs: Passes / Coins / Boosts / Weather)
---------------------------------------------------------------------------
local shopPanel, shopBody = makePanel("Shop", "🛒 SHOP", Color3.fromRGB(255, 170, 40), 640, 450)
local tabRow = Instance.new("Frame")
tabRow.BackgroundTransparency = 1
tabRow.Size = UDim2.new(1, 0, 0, 44)
tabRow.ZIndex = 21
tabRow.Parent = shopBody
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 8)
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
	{ Name = "Weather", Label = "🌈 Weather", Color = Color3.fromRGB(80, 170, 255) },
	{ Name = "Boosts", Label = "⚡ Boosts", Color = Color3.fromRGB(255, 120, 60) },
	{ Name = "Coins", Label = "💰 Coins", Color = Color3.fromRGB(255, 185, 40) },
}
for _, t in ipairs(tabDefs) do
	local b = juicy(bubbleButton(tabRow, t.Label, t.Color, { Size = UDim2.fromOffset(144, 42), ZIndex = 22 }))
	b.Activated:Connect(function()
		showTab(t.Name)
	end)
	tabs[t.Name] = b
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(0, 54)
	holder.Size = UDim2.new(1, 0, 1, -54)
	holder.ZIndex = 21
	holder.Parent = shopBody
	scroller(holder, UDim2.fromOffset(180, 190), UDim2.fromOffset(12, 12))
	pages[t.Name] = holder
end
local function page(name)
	return pages[name]:FindFirstChildOfClass("ScrollingFrame")
end
for _, gp in ipairs(Config.GamePasses) do
	card(page("Passes"), gp, "Pass", Color3.fromRGB(150, 90, 255))
end
local TAB_COLORS = { Coins = Color3.fromRGB(240, 170, 40), Boosts = Color3.fromRGB(255, 120, 60), Weather = Color3.fromRGB(70, 150, 255) }
for _, prod in ipairs(Config.Products) do
	card(page(prod.Tab), prod, "Product", TAB_COLORS[prod.Tab])
end
showTab("Passes")
local function openShop(tab)
	if not shopPanel.Visible then
		open("Shop")
	end
	showTab(tab or "Passes")
end
plusBtn.Activated:Connect(function()
	openShop("Coins")
end)
eventBar.Activated:Connect(function()
	openShop("Weather")
end)

---------------------------------------------------------------------------
-- Seed Shop panel
---------------------------------------------------------------------------
local seedsPanel, seedsBody = makePanel("Seeds", "🌱 SEED SHOP", Color3.fromRGB(90, 210, 120), 620, 470)
local restockLbl = text(seedsBody, "", { Size = UDim2.new(0.55, 0, 0, 34), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22,
	TextColor3 = Color3.fromRGB(200, 255, 210) })
local restockBtn = juicy(bubbleButton(seedsBody, "🔄 RESTOCK NOW  R$29", Color3.fromRGB(255, 120, 60), {
	Position = UDim2.new(0.57, 0, 0, 0), Size = UDim2.new(0.43, 0, 0, 36), ZIndex = 22 }))
restockBtn.Activated:Connect(function()
	action("Buy", "Product", "Restock")
end)
local seedsHolder = Instance.new("Frame")
seedsHolder.BackgroundTransparency = 1
seedsHolder.Position = UDim2.fromOffset(0, 46)
seedsHolder.Size = UDim2.new(1, 0, 1, -46)
seedsHolder.ZIndex = 21
seedsHolder.Parent = seedsBody
local seedsScroll = scroller(seedsHolder, UDim2.new(1, -16, 0, 74), UDim2.fromOffset(8, 8))
local seedRows = {}
for i, def in ipairs(Config.Crystals) do
	local r = Config.Rarity(def.Rarity)
	local row = Instance.new("Frame")
	row.BackgroundColor3 = WHITE
	row.LayoutOrder = i
	row.ZIndex = 22
	row.Parent = seedsScroll
	corner(row, 14)
	stroke(row, 3)
	gradient(row, r.Color:Lerp(Color3.fromRGB(60, 50, 100), 0.45), Color3.fromRGB(45, 38, 80))
	gem(row, def, { Position = UDim2.fromOffset(8, 5), Size = UDim2.fromOffset(64, 64), ZIndex = 23 })
	text(row, def.Name, { Position = UDim2.fromOffset(80, 6), Size = UDim2.new(0.36, 0, 0, 30), ZIndex = 23,
		TextXAlignment = Enum.TextXAlignment.Left })
	text(row, def.Rarity .. (def.Regrow and " • ♻️ Regrows" or "") .. " • ⏱ " .. Config.Time(def.Grow), {
		Position = UDim2.fromOffset(80, 38), Size = UDim2.new(0.45, 0, 0, 24), ZIndex = 23, TextColor3 = r.Color,
		TextXAlignment = Enum.TextXAlignment.Left })
	local stockL = text(row, "", { Position = UDim2.new(0.56, 0, 0, 8), Size = UDim2.new(0.16, 0, 0, 26), ZIndex = 23 })
	text(row, "Sells $" .. Config.Format(def.Value), { Position = UDim2.new(0.53, 0, 0, 40), Size = UDim2.new(0.21, 0, 0, 22), ZIndex = 23,
		TextColor3 = Color3.fromRGB(150, 255, 150) })
	local buy = juicy(bubbleButton(row, "$" .. Config.Format(def.Price), GREEN, {
		Position = UDim2.new(1, -150, 0, 12), Size = UDim2.fromOffset(140, 50), ZIndex = 23 }))
	buy.Activated:Connect(function()
		action("BuySeed", def.Name)
	end)
	seedRows[def.Name] = { Stock = stockL, Buy = buy }
end
local function refreshStock()
	local stock = parseCounts(player:GetAttribute("Stock"))
	for name, row in pairs(seedRows) do
		local n = stock[name] or 0
		row.Stock.Text = n > 0 and ("x" .. n .. " Stock") or "NO STOCK"
		row.Stock.TextColor3 = n > 0 and WHITE or Color3.fromRGB(255, 120, 120)
		recolor(row.Buy, n > 0 and GREEN or GRAY)
	end
end
player:GetAttributeChangedSignal("Stock"):Connect(refreshStock)
refreshStock()

---------------------------------------------------------------------------
-- Backpack panel
---------------------------------------------------------------------------
local _, bagBody = makePanel("Backpack", "🎒 BACKPACK", Color3.fromRGB(255, 110, 190), 620, 470)
local bagSummary = text(bagBody, "", { Size = UDim2.new(0.58, 0, 0, 36), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22 })
local sellAllBtn = juicy(bubbleButton(bagBody, "💰 SELL ALL", Color3.fromRGB(255, 185, 40), {
	Position = UDim2.new(0.6, 0, 0, 0), Size = UDim2.new(0.4, 0, 0, 40), ZIndex = 22 }))
sellAllBtn.Activated:Connect(function()
	action("Sell")
end)
local bagHolder = Instance.new("Frame")
bagHolder.BackgroundTransparency = 1
bagHolder.Position = UDim2.fromOffset(0, 50)
bagHolder.Size = UDim2.new(1, 0, 1, -50)
bagHolder.ZIndex = 21
bagHolder.Parent = bagBody
local bagScroll = scroller(bagHolder, UDim2.fromOffset(128, 132))
local bagDirty = true
local MUT_ICON = { Gold = "🟡", Rainbow = "🌈", Frozen = "❄️", Charged = "⚡", Cosmic = "🌌" }
local function rebuildBag()
	bagDirty = false
	for _, c in ipairs(bagScroll:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local ok, items = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("BagJson") or "[]")
	if not ok or type(items) ~= "table" then
		return
	end
	-- best first
	table.sort(items, function(a, b)
		return Config.Value(a.N, a.S, a.M) > Config.Value(b.N, b.S, b.M)
	end)
	for i, item in ipairs(items) do
		local def = Config.Crystal(item.N)
		if def and i <= 150 then
			local r = Config.Rarity(def.Rarity)
			local c = Instance.new("Frame")
			c.BackgroundColor3 = WHITE
			c.LayoutOrder = i
			c.ZIndex = 22
			c.Parent = bagScroll
			corner(c, 14)
			stroke(c, 3)
			gradient(c, r.Color, shade(r.Color, 0.45))
			gem(c, def, { Position = UDim2.new(0.5, -26, 0, 4), Size = UDim2.fromOffset(52, 52), ZIndex = 23 })
			local tag = ""
			for _, m in ipairs(item.M or {}) do
				tag ..= (MUT_ICON[m] or "")
			end
			text(c, (item.S >= 2.5 and "HUGE " or "") .. def.Name, { Position = UDim2.fromOffset(4, 58), Size = UDim2.new(1, -8, 0, 22), ZIndex = 23 })
			text(c, tag ~= "" and tag or string.format("%.1fkg", item.S * def.H), { Position = UDim2.fromOffset(4, 80), Size = UDim2.new(1, -8, 0, 20),
				ZIndex = 23, TextColor3 = Color3.fromRGB(230, 230, 240) })
			text(c, "$" .. Config.Format(Config.Value(item.N, item.S, item.M)), { Position = UDim2.fromOffset(4, 102), Size = UDim2.new(1, -8, 0, 24),
				ZIndex = 23, TextColor3 = Color3.fromRGB(140, 255, 140) })
		end
	end
end
player:GetAttributeChangedSignal("BagJson"):Connect(function()
	bagDirty = true
	if panels.Backpack.Visible then
		rebuildBag()
	end
end)

---------------------------------------------------------------------------
-- Index panel (crystal collection)
---------------------------------------------------------------------------
local _, idxBody = makePanel("Index", "📖 CRYSTAL INDEX", Color3.fromRGB(70, 150, 255), 620, 450)
local idxScroll = scroller(idxBody, UDim2.fromOffset(130, 128))
local idxCards = {}
for i, def in ipairs(Config.Crystals) do
	local r = Config.Rarity(def.Rarity)
	local c = Instance.new("Frame")
	c.BackgroundColor3 = WHITE
	c.LayoutOrder = i
	c.ZIndex = 22
	c.Parent = idxScroll
	corner(c, 14)
	stroke(c, 3)
	gradient(c, r.Color, shade(r.Color, 0.45))
	local g = gem(c, def, { Position = UDim2.new(0.5, -28, 0, 6), Size = UDim2.fromOffset(56, 56), ZIndex = 23 })
	local nameL = text(c, "???", { Position = UDim2.fromOffset(4, 66), Size = UDim2.new(1, -8, 0, 24), ZIndex = 23 })
	text(c, def.Rarity, { Position = UDim2.fromOffset(4, 94), Size = UDim2.new(1, -8, 0, 22), ZIndex = 23, TextColor3 = Color3.fromRGB(235, 235, 245) })
	idxCards[def.Name] = { Gem = g, Name = nameL }
end
local idxCount = text(idxBody, "", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -60, 0, -56), Size = UDim2.fromOffset(140, 40),
	ZIndex = 23, TextColor3 = GOLD })
local function refreshIndex()
	local found, n = {}, 0
	for name in string.gmatch(player:GetAttribute("Discovered") or "", "[^|]+") do
		found[name] = true
		n += 1
	end
	for name, c in pairs(idxCards) do
		c.Name.Text = found[name] and name or "???"
		if c.Gem:IsA("ImageLabel") then
			c.Gem.ImageColor3 = found[name] and WHITE or Color3.new(0, 0, 0)
			c.Gem.ImageTransparency = found[name] and 0 or 0.4
		else
			c.Gem.BackgroundTransparency = found[name] and 0 or 0.8
		end
	end
	idxCount.Text = n .. "/" .. #Config.Crystals
end
player:GetAttributeChangedSignal("Discovered"):Connect(refreshIndex)
refreshIndex()

---------------------------------------------------------------------------
-- Dig confirm
---------------------------------------------------------------------------
local confirmPanel, confirmBody = makePanel("Confirm", "⛏️ DIG UP?", Color3.fromRGB(255, 90, 90), 400, 250)
local confirmText = text(confirmBody, "", { Size = UDim2.new(1, 0, 0, 70), TextWrapped = true, ZIndex = 22 })
local confirmYes = juicy(bubbleButton(confirmBody, "DIG", Color3.fromRGB(255, 90, 90), {
	Position = UDim2.new(0, 10, 0, 90), Size = UDim2.new(0.5, -20, 0, 54), ZIndex = 22 }))
local confirmNo = juicy(bubbleButton(confirmBody, "KEEP", GREEN, {
	Position = UDim2.new(0.5, 10, 0, 90), Size = UDim2.new(0.5, -20, 0, 54), ZIndex = 22 }))
local digTile
confirmYes.Activated:Connect(function()
	if digTile then
		action("Dig", digTile)
	end
	confirmPanel.Visible = false
end)
confirmNo.Activated:Connect(function()
	confirmPanel.Visible = false
end)

---------------------------------------------------------------------------
-- Left menu
---------------------------------------------------------------------------
local menu = Instance.new("Frame")
menu.BackgroundTransparency = 1
menu.AnchorPoint = Vector2.new(0, 0.5)
menu.Position = UDim2.new(0, 14, 0.5, 0)
menu.Size = UDim2.fromOffset(84, 460)
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
local seedsBtn = menuButton("seeds", "🌱", "SEEDS", Color3.fromRGB(90, 210, 120))
local bagBtn = menuButton("backpack", "🎒", "BAG", Color3.fromRGB(255, 110, 190))
local indexBtn = menuButton("index", "📖", "INDEX", Color3.fromRGB(70, 150, 255))
local dailyBtn = menuButton("daily", "📅", "DAILY", Color3.fromRGB(255, 80, 120))
shopBtn.Activated:Connect(function()
	openShop("Passes")
end)
seedsBtn.Activated:Connect(function()
	open("Seeds")
end)
bagBtn.Activated:Connect(function()
	open("Backpack")
	if panels.Backpack.Visible and bagDirty then
		rebuildBag()
	end
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
local bagBadge = badge(bagBtn, "0")
bagBadge.Size = UDim2.fromOffset(40, 28)
bagBadge.Position = UDim2.new(1, -28, 0, -10)
local stockBadge = badge(seedsBtn, "!")

---------------------------------------------------------------------------
-- Right side: free gift, weather shop
---------------------------------------------------------------------------
local right = Instance.new("Frame")
right.BackgroundTransparency = 1
right.AnchorPoint = Vector2.new(1, 0.5)
right.Position = UDim2.new(1, -14, 0.5, 0)
right.Size = UDim2.fromOffset(110, 300)
right.Parent = gui
local rightList = Instance.new("UIListLayout")
rightList.Padding = UDim.new(0, 12)
rightList.HorizontalAlignment = Enum.HorizontalAlignment.Right
rightList.Parent = right
local giftBtn = juicy(bubbleButton(right, "", Color3.fromRGB(255, 90, 160), { Size = UDim2.fromOffset(100, 100) }))
icon(giftBtn, "gift", "🎁", { Position = UDim2.fromOffset(6, -16), Size = UDim2.new(1, -12, 0, 78) })
local giftLbl = text(giftBtn, "", { Position = UDim2.new(0, -4, 1, -34), Size = UDim2.new(1, 8, 0, 30) })
giftBtn.Activated:Connect(function()
	action("Gift")
end)
local weatherBtn = juicy(bubbleButton(right, "", Color3.fromRGB(80, 170, 255), { Size = UDim2.fromOffset(100, 100) }))
icon(weatherBtn, "aurora", "🌈", { Position = UDim2.fromOffset(6, -16), Size = UDim2.new(1, -12, 0, 78) })
text(weatherBtn, "WEATHER", { Position = UDim2.new(0, -4, 1, -30), Size = UDim2.new(1, 8, 0, 26) })
weatherBtn.Activated:Connect(function()
	openShop("Weather")
end)
local growBtn = juicy(bubbleButton(right, Assets.growall and "      GROW" or "✨ GROW", Color3.fromRGB(255, 200, 60), { Size = UDim2.fromOffset(100, 50) }))
if Assets.growall then
	icon(growBtn, "growall", "✨", { Position = UDim2.fromOffset(-18, -18), Size = UDim2.fromOffset(52, 52), Rotation = -12 })
end
growBtn.Activated:Connect(function()
	openShop("Boosts")
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

---------------------------------------------------------------------------
-- Hotbar: seeds you own + shovel. Pick one, then tap a soil tile.
---------------------------------------------------------------------------
local hotbar = Instance.new("Frame")
hotbar.BackgroundTransparency = 1
hotbar.AnchorPoint = Vector2.new(0.5, 1)
hotbar.Position = UDim2.new(0.5, 0, 1, -12)
hotbar.Size = UDim2.fromOffset(720, 84)
hotbar.Parent = gui
local hbLayout = Instance.new("UIListLayout")
hbLayout.FillDirection = Enum.FillDirection.Horizontal
hbLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
hbLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
hbLayout.SortOrder = Enum.SortOrder.LayoutOrder
hbLayout.Padding = UDim.new(0, 8)
hbLayout.Parent = hotbar
local hint = text(gui, "", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -102), Size = UDim2.fromOffset(620, 28),
	TextColor3 = Color3.fromRGB(255, 240, 150) })

local selected = nil -- seed name or "Shovel"
local slots = {}
local function setHint()
	if selected == "Shovel" then
		hint.Text = "⛏️ Tap a crystal in your garden to dig it up"
	elseif selected then
		hint.Text = "🌱 Tap an empty soil tile in your garden to plant " .. selected
	else
		local seeds = parseCounts(player:GetAttribute("Seeds"))
		hint.Text = next(seeds) and "Pick a seed below, then tap your soil to plant!" or "Out of seeds! Buy more at the 🌱 Seed Shop"
	end
end
local function selectSlot(name)
	if selected == name then
		selected = nil
	else
		selected = name
	end
	for n, b in pairs(slots) do
		local stk = b:FindFirstChildOfClass("UIStroke")
		if stk then
			stk.Color = n == selected and GOLD or BLACK
			stk.Thickness = n == selected and 5 or 3
		end
		if n == selected then
			punch(b, 0.12)
		end
	end
	setHint()
end
local function slotButton(name, order, color)
	local b = juicy(bubbleButton(hotbar, "", color, { Size = UDim2.fromOffset(74, 74), LayoutOrder = order }))
	b.Activated:Connect(function()
		selectSlot(name)
	end)
	slots[name] = b
	return b
end
local shovel = slotButton("Shovel", 100, Color3.fromRGB(150, 120, 90))
icon(shovel, "shovel", "⛏️", { Position = UDim2.fromOffset(4, -6), Size = UDim2.new(1, -8, 0, 54) })
text(shovel, "DIG", { Position = UDim2.new(0, 0, 1, -24), Size = UDim2.new(1, 0, 0, 22) })

local function refreshHotbar()
	local seeds = parseCounts(player:GetAttribute("Seeds"))
	for i, def in ipairs(Config.Crystals) do
		local n = seeds[def.Name] or 0
		local b = slots[def.Name]
		if n > 0 and not b then
			local r = Config.Rarity(def.Rarity)
			b = slotButton(def.Name, i, r.Color:Lerp(Color3.fromRGB(60, 50, 100), 0.35))
			gem(b, def, { Position = UDim2.fromOffset(8, -4), Size = UDim2.new(1, -16, 0, 50) })
			text(b, "", { Name = "Count", Position = UDim2.new(0, 0, 1, -24), Size = UDim2.new(1, 0, 0, 22) })
			punch(b, 0.4)
		end
		if b then
			if n <= 0 then
				b:Destroy()
				slots[def.Name] = nil
				if selected == def.Name then
					selected = nil
				end
			else
				local cnt = b:FindFirstChild("Count")
				if cnt then
					cnt.Text = "x" .. n
				end
			end
		end
	end
	setHint()
end
player:GetAttributeChangedSignal("Seeds"):Connect(refreshHotbar)
refreshHotbar()

-- keyboard: 1-9 pick hotbar slots, Q = shovel
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local k = input.KeyCode.Value - Enum.KeyCode.One.Value + 1
	if k >= 1 and k <= 9 then
		local ordered = {}
		for _, def in ipairs(Config.Crystals) do
			if slots[def.Name] then
				ordered[#ordered + 1] = def.Name
			end
		end
		if ordered[k] then
			selectSlot(ordered[k])
		end
	elseif input.KeyCode == Enum.KeyCode.Q then
		selectSlot("Shovel")
	end
end)

---------------------------------------------------------------------------
-- Planting: tap / click a soil tile in your own garden
---------------------------------------------------------------------------
local gardens = workspace:WaitForChild("World"):WaitForChild("Gardens")
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { gardens }

local function soilAt(pos) -- pos in viewport pixels
	local ray = camera:ViewportPointToRay(pos.X, pos.Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 400, rayParams)
	if hit and hit.Instance.Name == "Soil" then
		return hit.Instance
	end
	return nil
end

local function tapTile(soil)
	if soil:GetAttribute("Plot") ~= player:GetAttribute("Plot") then
		return
	end
	local n = soil:GetAttribute("Tile")
	if soil:GetAttribute("Locked") then
		notify("🔒 Locked! Expand your garden at the green sign by the gate.", Color3.fromRGB(255, 220, 150))
		sfx("error", 0.4)
		return
	end
	local seed = soil:GetAttribute("Seed")
	if seed then
		if selected == "Shovel" then
			digTile = n
			confirmText.Text = "Dig up your " .. seed .. "? You won't get the seed back."
			closeAll()
			confirmPanel.Visible = true
			punch(confirmPanel, 0.15)
		elseif workspace:GetServerTimeNow() >= (soil:GetAttribute("ReadyAt") or math.huge) then
			action("Harvest", n)
		end
		return
	end
	if selected and selected ~= "Shovel" then
		action("Plant", n, selected)
	elseif not selected then
		punch(hotbar, 0.15)
		setHint()
	end
end

-- a glowing plate under the cursor shows which tile you'd plant on
local ghost = Instance.new("Part")
ghost.Anchored = true
ghost.CanCollide = false
ghost.CanQuery = false
ghost.CanTouch = false
ghost.Material = Enum.Material.Neon
ghost.Color = Color3.fromRGB(150, 255, 180)
ghost.Transparency = 1
ghost.Size = Vector3.new(5, 0.2, 5)
ghost.Parent = workspace

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	local soil = soilAt(UserInputService:GetMouseLocation())
	if soil then
		tapTile(soil)
	end
end)
UserInputService.TouchTapInWorld:Connect(function(pos, processed)
	if processed then
		return
	end
	local soil = soilAt(pos)
	if soil then
		tapTile(soil)
	end
end)
RunService.RenderStepped:Connect(function()
	local soil = nil
	if UserInputService.MouseEnabled then
		soil = soilAt(UserInputService:GetMouseLocation())
	end
	if soil and selected and soil:GetAttribute("Plot") == player:GetAttribute("Plot") and not soil:GetAttribute("Locked") then
		local planted = soil:GetAttribute("Seed") ~= nil
		local ok = (selected == "Shovel") == planted
		ghost.CFrame = soil.CFrame * CFrame.new(0, 0.35, 0)
		ghost.Color = ok and Color3.fromRGB(150, 255, 180) or Color3.fromRGB(255, 120, 120)
		ghost.Transparency = 0.45 + math.sin(os.clock() * 6) * 0.1
	else
		ghost.Transparency = 1
	end
end)

---------------------------------------------------------------------------
-- Labels over my own crystals (timer / READY), only for my garden
---------------------------------------------------------------------------
local myLabels = {}
local function buildLabels()
	for _, l in pairs(myLabels) do
		l.Gui:Destroy()
	end
	myLabels = {}
	local plot = player:GetAttribute("Plot")
	local model = plot and gardens:FindFirstChild("Garden" .. plot)
	if not model then
		return
	end
	for _, soil in ipairs(model:GetChildren()) do
		if soil.Name == "Soil" then
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromScale(6, 2)
			bb.StudsOffset = Vector3.new(0, 4, 0)
			bb.AlwaysOnTop = false
			bb.LightInfluence = 0
			bb.MaxDistance = 60
			bb.ResetOnSpawn = false
			bb.Adornee = soil
			bb.Parent = player.PlayerGui
			local name = text(bb, "", { Size = UDim2.fromScale(1, 0.5) })
			local timer = text(bb, "", { Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromScale(1, 0.5) })
			myLabels[soil] = { Gui = bb, Name = name, Timer = timer }
		end
	end
end
player:GetAttributeChangedSignal("Plot"):Connect(buildLabels)
task.spawn(function()
	task.wait(2)
	buildLabels()
end)
local lastLabel = 0
RunService.Heartbeat:Connect(function()
	if os.clock() - lastLabel < 0.2 then
		return
	end
	lastLabel = os.clock()
	local now = workspace:GetServerTimeNow()
	for soil, l in pairs(myLabels) do
		local seed = soil:GetAttribute("Seed")
		local def = seed and Config.Crystal(seed)
		if def then
			l.Gui.Enabled = true
			local muts = soil:GetAttribute("Muts") or ""
			local tag = ""
			for m in string.gmatch(muts, "[^,]+") do
				tag ..= (MUT_ICON[m] or "")
			end
			l.Name.Text = tag .. ((soil:GetAttribute("Size") or 1) >= 2.5 and "HUGE " or "") .. def.Name
			l.Name.TextColor3 = Config.Rarity(def.Rarity).Color
			local left = (soil:GetAttribute("ReadyAt") or 0) - now
			l.Gui.StudsOffset = Vector3.new(0, 1.5 + def.H * math.min(soil:GetAttribute("Size") or 1, 1.7), 0)
			if left <= 0 then
				l.Timer.Text = "READY!"
				l.Timer.TextColor3 = Color3.fromHSV((os.clock() * 0.8) % 1, 0.5, 1)
			else
				l.Timer.Text = "⏱ " .. Config.Time(left)
				l.Timer.TextColor3 = WHITE
			end
		elseif soil:GetAttribute("Locked") then
			l.Gui.Enabled = false
		else
			l.Gui.Enabled = false
		end
	end
end)

-- owner-only world labels and prompts (expand sign, harvest)
local function ownerLabel(bb)
	if not bb:IsA("BillboardGui") or bb:GetAttribute("Plot") == nil then
		return
	end
	local function apply()
		bb.Enabled = bb:GetAttribute("Plot") == player:GetAttribute("Plot")
	end
	apply()
	player:GetAttributeChangedSignal("Plot"):Connect(apply)
end
local function ownerPrompt(p)
	if not p:IsA("ProximityPrompt") or (p.Name ~= "Harvest" and p.Name ~= "Expand") then
		return
	end
	local holder = p.Parent
	local function apply()
		p.Enabled = holder:GetAttribute("OwnerId") == player.UserId
	end
	apply()
	holder:GetAttributeChangedSignal("OwnerId"):Connect(apply)
end
for _, d in ipairs(workspace:GetDescendants()) do
	ownerLabel(d)
	ownerPrompt(d)
end
workspace.DescendantAdded:Connect(function(d)
	ownerLabel(d)
	ownerPrompt(d)
end)

-- rainbow crystals cycle through every color
local crystals = workspace:WaitForChild("World"):WaitForChild("Crystals")
local rainbow = {}
local function trackCrystal(m)
	if m:GetAttribute("Rainbow") then
		local parts = {}
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "Core" then
				parts[#parts + 1] = d
			end
		end
		rainbow[m] = parts
	end
end
for _, m in ipairs(crystals:GetChildren()) do
	task.defer(trackCrystal, m)
end
crystals.ChildAdded:Connect(function(m)
	task.delay(0.5, trackCrystal, m)
end)
crystals.ChildRemoved:Connect(function(m)
	rainbow[m] = nil
end)

---------------------------------------------------------------------------
-- Teleports
---------------------------------------------------------------------------
local function teleport(cf)
	local char = player.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		char:PivotTo(cf)
		sfx("open", 0.35, 1.3)
	end
end
tpGarden.Activated:Connect(function()
	local m = gardens:FindFirstChild("Garden" .. tostring(player:GetAttribute("Plot")))
	if m and m:GetAttribute("Spawn") then
		teleport(m:GetAttribute("Spawn"))
	end
end)
tpSeeds.Activated:Connect(function()
	teleport(CFrame.lookAt(Vector3.new(-13, 4, 0), Vector3.new(-26, 4, 0)))
	task.delay(0.2, function()
		if not seedsPanel.Visible then
			open("Seeds")
		end
	end)
end)
tpSell.Activated:Connect(function()
	teleport(CFrame.lookAt(Vector3.new(13, 4, 0), Vector3.new(26, 4, 0)))
end)

---------------------------------------------------------------------------
-- Offer pop-ups
---------------------------------------------------------------------------
local offer, offerBody = makePanel("Offer", "🔥 LIMITED OFFER 🔥", Color3.fromRGB(255, 60, 140), 420, 320)
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
task.delay(150, function()
	local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
	if ok and can then
		pcall(SocialService.PromptGameInvite, SocialService, player)
	end
end)

---------------------------------------------------------------------------
-- Weather effects (client side)
---------------------------------------------------------------------------
local fxFolder = Instance.new("Folder")
fxFolder.Name = "WeatherFx"
fxFolder.Parent = workspace
local skyEmitterPart = Instance.new("Part")
skyEmitterPart.Anchored = true
skyEmitterPart.CanCollide = false
skyEmitterPart.CanQuery = false
skyEmitterPart.CanTouch = false
skyEmitterPart.Transparency = 1
skyEmitterPart.Size = Vector3.new(160, 1, 160)
skyEmitterPart.Parent = fxFolder
local flash = Instance.new("ColorCorrectionEffect")
flash.Name = "Flash"
flash.Parent = Lighting

local function skyEmitter(props)
	local e = Instance.new("ParticleEmitter")
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Enabled = false
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = skyEmitterPart
	return e
end
local snow = skyEmitter({ Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(WHITE), LightEmission = 0.6,
	Size = NumberSequence.new(0.35), Lifetime = NumberRange.new(6, 8), Rate = 260, Speed = NumberRange.new(6, 9),
	SpreadAngle = Vector2.new(25, 25), Transparency = NumberSequence.new(0.1), RotSpeed = NumberRange.new(-60, 60) })
local rain = skyEmitter({ Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(190, 210, 255)),
	LightEmission = 0.3, Size = NumberSequence.new(0.12), Squash = NumberSequence.new(2.5), Lifetime = NumberRange.new(1.2, 1.5),
	Rate = 500, Speed = NumberRange.new(60, 70), Orientation = Enum.ParticleOrientation.VelocityParallel, Transparency = NumberSequence.new(0.35) })
local stars = skyEmitter({ Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(Color3.fromRGB(255, 230, 255)),
	LightEmission = 1, Size = NumberSequence.new(0.6, 0), Lifetime = NumberRange.new(4, 6), Rate = 60, Speed = NumberRange.new(4, 8),
	SpreadAngle = Vector2.new(40, 40) })

local activeEvent = ""
local ribbons = {}

local function lightning()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local target = root.Position + Vector3.new(rng:NextNumber(-90, 90), 0, rng:NextNumber(-90, 90))
	local top = target + Vector3.new(rng:NextNumber(-20, 20), 140, rng:NextNumber(-20, 20))
	local prev = top
	local segs = {}
	for i = 1, 8 do
		local t = i / 8
		local p = top:Lerp(target, t) + (i < 8 and Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8)) or Vector3.zero)
		local seg = Instance.new("Part")
		seg.Anchored = true
		seg.CanCollide = false
		seg.CanQuery = false
		seg.CanTouch = false
		seg.Material = Enum.Material.Neon
		seg.Color = Color3.fromRGB(255, 250, 190)
		seg.Size = Vector3.new(0.8, 0.8, (p - prev).Magnitude)
		seg.CFrame = CFrame.lookAt((p + prev) / 2, p)
		seg.Parent = fxFolder
		segs[#segs + 1] = seg
		prev = p
	end
	flash.Brightness = 0.45
	tween(flash, 0.5, { Brightness = 0 })
	sfx("thunder", 0.7, rng:NextNumber(0.85, 1.1))
	task.delay(0.18, function()
		for _, s in ipairs(segs) do
			s:Destroy()
		end
	end)
end

local function meteor()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local target = root.Position + Vector3.new(rng:NextNumber(-110, 110), 0, rng:NextNumber(-110, 110))
	target = Vector3.new(target.X, 0, target.Z)
	local from = target + Vector3.new(-70, 160, -40)
	local m = Instance.new("Part")
	m.Shape = Enum.PartType.Ball
	m.Anchored = true
	m.CanCollide = false
	m.CanQuery = false
	m.CanTouch = false
	m.Material = Enum.Material.Neon
	m.Color = Color3.fromHSV(rng:NextNumber(0.72, 0.95), 0.6, 1)
	local size = rng:NextNumber(2, 4)
	m.Size = Vector3.new(size, size, size)
	m.Position = from
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, size * 0.4, 0)
	a0.Parent = m
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -size * 0.4, 0)
	a1.Parent = m
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.5
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(m.Color, Color3.fromRGB(255, 200, 120))
	trail.Transparency = NumberSequence.new(0, 1)
	trail.FaceCamera = true
	trail.Parent = m
	local light = Instance.new("PointLight")
	light.Color = m.Color
	light.Range = 20
	light.Brightness = 3
	light.Parent = m
	m.Parent = fxFolder
	local t = rng:NextNumber(1.2, 1.8)
	tween(m, t, { Position = target }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(t, function()
		local boom = Instance.new("Part")
		boom.Shape = Enum.PartType.Ball
		boom.Anchored = true
		boom.CanCollide = false
		boom.CanQuery = false
		boom.CanTouch = false
		boom.Material = Enum.Material.Neon
		boom.Color = m.Color
		boom.Size = Vector3.new(2, 2, 2)
		boom.Position = target
		boom.Parent = fxFolder
		tween(boom, 0.5, { Size = Vector3.new(16, 16, 16), Transparency = 1 })
		sfx("meteor", 0.6, rng:NextNumber(0.85, 1.15), boom)
		m:Destroy()
		task.delay(0.6, function()
			boom:Destroy()
		end)
	end)
end

local function buildAurora()
	for _, r in ipairs(ribbons) do
		r.Part:Destroy()
	end
	ribbons = {}
	for k = 1, 3 do
		for i = 1, 36 do
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Material = Enum.Material.Neon
			p.Transparency = 0.55
			p.Size = Vector3.new(14, 30, 0.4)
			p.Parent = fxFolder
			ribbons[#ribbons + 1] = { Part = p, K = k, I = i }
		end
	end
end

local function setEvent(key)
	activeEvent = key
	snow.Enabled = key == "Frost"
	rain.Enabled = key == "Thunder"
	stars.Enabled = key == "Meteor" or key == "Aurora"
	if key == "Aurora" then
		buildAurora()
	else
		for _, r in ipairs(ribbons) do
			r.Part:Destroy()
		end
		ribbons = {}
	end
end
setEvent(workspace:GetAttribute("Event") or "")
workspace:GetAttributeChangedSignal("Event"):Connect(function()
	setEvent(workspace:GetAttribute("Event") or "")
end)

task.spawn(function()
	while true do
		if activeEvent == "Thunder" then
			lightning()
			task.wait(rng:NextNumber(2, 5))
		elseif activeEvent == "Meteor" then
			meteor()
			task.wait(rng:NextNumber(0.3, 0.8))
		else
			task.wait(0.5)
		end
	end
end)

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	skyEmitterPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 45, 0))
	for _, r in ipairs(ribbons) do
		local a = (r.I / 36) * math.pi * 1.4 + r.K * 0.9 + t * 0.05
		local rad = 260 + r.K * 30
		local yy = 110 + r.K * 18 + math.sin(t * 0.7 + r.I * 0.35 + r.K) * 10
		local pos = Vector3.new(math.cos(a) * rad, yy, math.sin(a) * rad)
		r.Part.CFrame = CFrame.lookAt(pos, Vector3.new(0, yy, 0))
		r.Part.Color = Color3.fromHSV((t * 0.08 + r.I / 36 + r.K * 0.2) % 1, 0.6, 1)
	end
	for _, parts in pairs(rainbow) do
		for i, p in ipairs(parts) do
			p.Color = Color3.fromHSV((t * 0.35 + i * 0.07) % 1, 0.55, 1)
		end
	end
end)

---------------------------------------------------------------------------
-- Live updates
---------------------------------------------------------------------------
local shownCoins = 0
local brokeCount = 0
local lastStockAt = 0
RunService.RenderStepped:Connect(function(dt)
	local now = workspace:GetServerTimeNow()
	-- rolling coin counter
	local target = get("Coins")
	if shownCoins ~= target then
		shownCoins += (target - shownCoins) * math.min(dt * 10, 1)
		if math.abs(target - shownCoins) < 1 then
			shownCoins = target
		end
		coinLbl.Text = "$" .. Config.Format(shownCoins)
	end
	-- event bar
	local ev = workspace:GetAttribute("Event") or ""
	if ev ~= "" then
		local e = Config.Event(ev)
		if e then
			local mut = Config.Mutation(e.Mutation)
			eventLbl.Text = e.Icon .. " " .. string.upper(e.Name) .. "  " .. Config.Time((workspace:GetAttribute("EventEnds") or 0) - now)
				.. "  •  " .. e.Mutation .. " x" .. (mut and mut.Mult or 1)
			local pulse = 0.75 + math.sin(os.clock() * 4) * 0.25
			eventGrad.Color = ColorSequence.new(e.Color:Lerp(WHITE, 0.1), shade(e.Color, 0.55 * pulse))
		end
	else
		local e = Config.Event(workspace:GetAttribute("NextEvent") or "")
		if e then
			eventLbl.Text = "Next: " .. e.Icon .. " " .. e.Name .. " in " .. Config.Time((workspace:GetAttribute("NextEventAt") or 0) - now)
		end
		eventGrad.Color = ColorSequence.new(Color3.fromRGB(110, 90, 170), Color3.fromRGB(60, 45, 110))
	end
	-- gift
	local giftLeft = get("GiftAt") - now
	if giftLeft <= 0 then
		giftLbl.Text = "CLAIM!"
		giftBtn.Rotation = math.sin(os.clock() * 10) * 6
	else
		giftLbl.Text = Config.Time(giftLeft)
		giftBtn.Rotation = 0
	end
	dailyBadge.Visible = now - get("LastDaily") >= 86400
	saleBadge.Rotation = math.sin(os.clock() * 4) * 15
	weatherBtn.Rotation = math.sin(os.clock() * 2.5) * 4
	local bc = get("BagCount")
	bagBadge.Visible = bc > 0
	bagBadge.Text = tostring(bc)
	-- restock
	local rLeft = (workspace:GetAttribute("RestockAt") or 0) - now
	restockLbl.Text = "🔄 New seeds in " .. Config.Time(rLeft)
	stockBadge.Visible = now - lastStockAt < 60
	stockBadge.Rotation = math.sin(os.clock() * 5) * 10
	-- offer countdown
	if offer.Visible then
		offerIcon.Rotation = -14 + math.sin(os.clock() * 3) * 6
		local left = math.max(0, offerEnds - os.clock())
		offerTimer.Text = "⏰ ENDS IN " .. Config.Time(left)
	end
	-- backpack summary
	if panels.Backpack.Visible then
		bagSummary.Text = bc .. "/" .. Config.BackpackMax .. " crystals • worth $" .. Config.Format(get("BagValue"))
	end
end)

---------------------------------------------------------------------------
-- Server effects
---------------------------------------------------------------------------
local function center()
	local vp = camera.ViewportSize
	return vp.X / 2, vp.Y * 0.45
end

local function coinBurst(amount)
	local x, y = center()
	floater("+$" .. Config.Format(amount), Color3.fromRGB(255, 225, 90), x, y, 70)
	punch(coinBar, 0.25)
	confetti(math.clamp(math.floor(math.log10(amount + 1) * 10), 10, 80), { GOLD, Color3.fromRGB(255, 240, 150), WHITE })
	sfx("coins", 0.7)
	sfx("kaching", 0.35, 1.1)
	for i = 0, 4 do
		task.delay(i * 0.06, function()
			sfx("chip", 0.3, 1 + i * 0.12)
		end)
	end
	kick(0.3)
end

remotes:WaitForChild("Fx").OnClientEvent:Connect(function(kind, a, b, c, d, e, f)
	if kind == "Toast" then
		notify(a, WHITE)
		sfx("toast", 0.4)
	elseif kind == "Announce" then
		notify(a, b)
		sfx("bell", 0.45)
	elseif kind == "Coins" then
		coinBurst(a)
	elseif kind == "Sold" then
		coinBurst(a)
		showBanner("SOLD " .. b .. " CRYSTALS!", GOLD)
		sfx("sell", 0.7)
	elseif kind == "Planted" then
		sfx("plant", 0.6, rng:NextNumber(0.9, 1.1))
	elseif kind == "BoughtSeed" then
		local r, ri = Config.Rarity(b)
		notify("+1 " .. a .. " seed", r.Color)
		sfx("seed", 0.55)
		if ri >= 5 then
			showBanner("GOT " .. string.upper(a) .. " SEED!", r.Color)
			sfx("rare", 0.7)
			confetti(60)
		end
		-- first seed of a kind: pick it for them
		if not selected then
			selectSlot(a)
		end
	elseif kind == "Harvested" then
		-- a = name, b = rarity, c = value, d = mutations, e = size, f = new to the index
		local r, ri = Config.Rarity(b)
		local x, y = center()
		local tag = ""
		for m in string.gmatch(d or "", "[^,]+") do
			tag ..= (MUT_ICON[m] or "") .. string.upper(m) .. " "
		end
		floater(tag .. ((e or 1) >= 2.5 and "HUGE " or "") .. a .. "  $" .. Config.Format(c), r.Color, x, y + 40, 44)
		sfx("harvest", 0.6, rng:NextNumber(0.95, 1.1))
		if f then
			showBanner("NEW CRYSTAL: " .. string.upper(a) .. "!", r.Color)
			sfx("rare", 0.6)
			confetti(50)
		elseif ri >= 4 or tag ~= "" then
			sfx("rare", 0.5)
			confetti(40)
			kick(0.4)
		end
	elseif kind == "Ripe" then
		sfx("ripe", 0.35, rng:NextNumber(1, 1.2))
	elseif kind == "Mutated" then
		local mut = Config.Mutation(b)
		notify((MUT_ICON[b] or "✨") .. " Your " .. a .. " turned " .. string.upper(b) .. "!", mut and mut.Color or WHITE)
		sfx("mutate", 0.55, rng:NextNumber(0.95, 1.1))
	elseif kind == "Dug" then
		sfx("dig", 0.6)
	elseif kind == "Broke" then
		notify("Need $" .. Config.Format(a) .. "!", Color3.fromRGB(255, 120, 120))
		punch(coinBar, 0.2)
		sfx("error", 0.5)
		brokeCount += 1
		if brokeCount % 3 == 0 then
			showOffer({ Kind = "Product", Key = "CoinsM", Title = "NEED COINS?", Pitch = "Grab a Chest of Coins and buy those seeds!" })
		end
	elseif kind == "NeedStand" then
		notify("💰 Sell at the Sell Stand (tap SELL up top) or get Sell Anywhere!", Color3.fromRGB(255, 220, 150))
		sfx("error", 0.4)
		showOffer({ Kind = "Pass", Key = "SellAnywhere", Title = "SELL ANYWHERE", Pitch = "Sell your whole backpack from anywhere, forever!" })
	elseif kind == "BagFull" then
		showOffer({ Kind = "Pass", Key = "SellAnywhere", Title = "BACKPACK FULL!", Pitch = "Sell from anywhere and never walk again!" })
	elseif kind == "OpenSeeds" then
		if not seedsPanel.Visible then
			open("Seeds")
		end
	elseif kind == "Restocked" then
		notify("🌱 Seed Shop restocked!", Color3.fromRGB(150, 255, 170))
		sfx("restock", 0.5)
		lastStockAt = workspace:GetServerTimeNow()
	elseif kind == "RareStock" then
		local r = Config.Rarity(b)
		notify("✨ " .. string.upper(b) .. " " .. a .. " seeds are in stock!", r.Color)
		lastStockAt = workspace:GetServerTimeNow()
	elseif kind == "Expanded" then
		showBanner("GARDEN EXPANDED! " .. a .. " TILES", Color3.fromRGB(150, 255, 170))
		sfx("expand", 0.7)
		confetti(80)
		kick(0.5)
	elseif kind == "EventStart" then
		local ev = Config.Event(a)
		if ev then
			showBanner(ev.Icon .. " " .. string.upper(ev.Name) .. "! " .. ev.Icon, ev.Color)
			notify(ev.Mutation .. " mutations are falling on every garden!", ev.Color)
			sfx("event", 0.8)
			kick(0.6)
		end
	elseif kind == "EventEnd" then
		notify("The weather cleared up.", Color3.fromRGB(220, 220, 240))
	elseif kind == "Thanks" then
		showBanner("THANK YOU! 💖", PINK)
		sfx("thanks", 0.7)
		sfx("kaching", 0.5)
		confetti(120)
	elseif kind == "Welcome" then
		showBanner("WELCOME TO YOUR GARDEN!", Color3.fromRGB(150, 255, 190))
		task.delay(3, function()
			notify("Pick the Quartz seed below and tap your soil to plant it!", Color3.fromRGB(255, 240, 150))
		end)
		task.delay(10, function()
			showOffer(Config.Offers[1])
		end)
	end
end)

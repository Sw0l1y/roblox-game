-- StarterPlayer.StarterPlayerScripts.Client ("Escape the Lava Wave")
-- Draws the lava wave from the server clock, the run meter, wave warnings, and the simulator UI.
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
local okFont, luckiest = pcall(function()
	return Enum.Font.LuckiestGuy
end)
local TITLE = okFont and luckiest or FONT
local BLACK = Color3.fromRGB(20, 20, 30)
local WHITE = Color3.new(1, 1, 1)
local GREEN = Color3.fromRGB(70, 220, 90)
local GOLD = Color3.fromRGB(255, 205, 50)
local LAVA = Color3.fromRGB(255, 110, 20)
local LAVA_HOT = Color3.fromRGB(255, 200, 70)
local HALF = Config.TrackWidth / 2

local function get(key)
	return player:GetAttribute(key) or 0
end

local function action(...)
	remotes.Action:FireServer(...)
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

---------------------------------------------------------------------------
-- Sound: one uploaded SFX sprite (Kenney CC0) played by region, plus licensed music
---------------------------------------------------------------------------
local okSounds, Sounds = pcall(function()
	return require(ReplicatedStorage:WaitForChild("Sounds", 5) :: ModuleScript)
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
		return
	end
	s.Parent = SoundService
	s:Play()
	task.delay(life, function()
		s:Destroy()
	end)
end

local MUSIC = (Sounds and Sounds.Music) or {}
local MUSIC_VOLUME = 0.2
local music = Instance.new("Sound")
music.Name = "Music"
music.Volume = MUSIC_VOLUME
music.Parent = SoundService
local musicOn = true
if #MUSIC > 0 then
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
end

-- low lava rumble that swells as the wave gets close
local rumble = Instance.new("Sound")
rumble.Looped = true
rumble.Volume = 0
rumble.SoundGroup = sfxGroup
rumble.Parent = SoundService
if Sounds and Sounds.Clips.rumble then
	rumble.SoundId = Sounds.Id
	rumble.PlaybackRegionsEnabled = true
	rumble.LoopRegion = NumberRange.new(Sounds.Clips.rumble[1], Sounds.Clips.rumble[1] + Sounds.Clips.rumble[2])
	rumble.PlaybackRegion = rumble.LoopRegion
	rumble:Play()
end

---------------------------------------------------------------------------
-- UI kit: thick outlines, gradients, bouncy buttons
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
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

-- custom icon art (uploaded PNGs in ReplicatedStorage.Assets); emoji until uploaded
local okAssets, Assets = pcall(function()
	return require(ReplicatedStorage:WaitForChild("Assets", 5) :: ModuleScript)
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
		(obj :: any)[k] = v
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
		(b :: any)[k] = v
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
-- Effects layer: floaters, confetti, banner, shake, screen flash, heat vignette
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

local function confetti(n, palette)
	local vp = camera.ViewportSize
	for _ = 1, n do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.Size = UDim2.fromOffset(rng:NextInteger(8, 16), rng:NextInteger(8, 16))
		f.BackgroundColor3 = palette and palette[rng:NextInteger(1, #palette)] or Color3.fromHSV(rng:NextNumber(), 0.8, 1)
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
		shake *= math.exp(-dt * 12)
	end
end)
local function kick(s)
	shake = math.min(shake + s, 1.4)
end

local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = LAVA
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.ZIndex = 45
flash.Parent = gui
local function screenFlash(color, from)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = from or 0.3
	tween(flash, 0.8, { BackgroundTransparency = 1 })
end

-- red heat around the screen edges while a wave is coming
local heat = Instance.new("Frame")
heat.Size = UDim2.fromScale(1, 1)
heat.BackgroundTransparency = 1
heat.ZIndex = 44
heat.Parent = gui
local heatEdges = {}
for i, spec in ipairs({
	{ UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0), 90 },
	{ UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0.78), -90 },
	{ UDim2.fromScale(0.16, 1), UDim2.fromScale(0, 0), 0 },
	{ UDim2.fromScale(0.16, 1), UDim2.fromScale(0.84, 0), 180 },
}) do
	local f = Instance.new("Frame")
	f.Size = spec[1]
	f.Position = spec[2]
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.fromRGB(255, 50, 20)
	f.ZIndex = 44
	f.Parent = heat
	local g = Instance.new("UIGradient")
	g.Rotation = spec[3]
	g.Transparency = NumberSequence.new(0, 1)
	g.Parent = f
	heatEdges[i] = f
end
local function setHeat(a)
	for _, f in ipairs(heatEdges) do
		f.BackgroundTransparency = 1 - a
	end
end
setHeat(0)

local banner = text(gui, "", {
	Font = TITLE,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.34),
	Size = UDim2.fromOffset(660, 80),
	TextTransparency = 1,
	TextStrokeTransparency = 1,
	ZIndex = 60,
})
local bannerToken = 0
local function showBanner(str, color, hold)
	bannerToken += 1
	local my = bannerToken
	banner.Text = str
	banner.TextColor3 = color
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0
	banner.Rotation = rng:NextNumber(-4, 4)
	punch(banner, 0.7)
	task.delay(hold or 1.6, function()
		if my == bannerToken then
			tween(banner, 0.3, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
end

-- big wave countdown in the middle of the screen
local countdown = text(gui, "", {
	Font = TITLE,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.2),
	Size = UDim2.fromOffset(720, 70),
	TextColor3 = Color3.fromRGB(255, 120, 60),
	Visible = false,
	ZIndex = 61,
})

---------------------------------------------------------------------------
-- Top: cash bar, income, run meter
---------------------------------------------------------------------------
local cashBar = Instance.new("Frame")
cashBar.AnchorPoint = Vector2.new(0, 0)
cashBar.Position = UDim2.new(0, 110, 0, 12)
cashBar.Size = UDim2.fromOffset(260, 54)
cashBar.BackgroundColor3 = WHITE
cashBar.Parent = gui
corner(cashBar, 27)
stroke(cashBar, 4)
gradient(cashBar, Color3.fromRGB(90, 230, 100), Color3.fromRGB(30, 150, 50))
icon(cashBar, "cash", "💵", { Position = UDim2.fromOffset(-18, -10), Size = UDim2.fromOffset(72, 72), Rotation = -8 })
local cashLbl = text(cashBar, "$0", { Font = TITLE, Position = UDim2.fromOffset(54, 6), Size = UDim2.new(1, -106, 0, 42) })
local plusBtn = juicy(bubbleButton(cashBar, Assets.plus and "" or "+", Color3.fromRGB(255, 200, 40), {
	Position = UDim2.new(1, -48, 0, 6), Size = UDim2.fromOffset(42, 42) }))
if Assets.plus then
	icon(plusBtn, "plus", "+", { Size = UDim2.fromScale(1, 1) })
end
local incomeLbl = text(gui, "+$0/s", { Position = UDim2.new(0, 160, 0, 68), Size = UDim2.fromOffset(170, 24),
	TextColor3 = Color3.fromRGB(150, 255, 150), TextXAlignment = Enum.TextXAlignment.Left })

-- run meter: the track from home to the volcano, with you and the wave on it
local meter = Instance.new("Frame")
meter.AnchorPoint = Vector2.new(0.5, 0)
meter.Position = UDim2.new(0.5, 0, 0, 16)
meter.Size = UDim2.fromOffset(440, 26)
meter.BackgroundColor3 = WHITE
meter.Parent = gui
corner(meter, 13)
stroke(meter, 4)
local zoneCount = #Config.ZoneNames
local meterSpan = Config.TrackEnd() + 70
local function meterX(x)
	return math.clamp(x / meterSpan, 0, 1)
end
do
	local g = Instance.new("UIGradient")
	local keys = { ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 230, 140)) }
	for i = 1, zoneCount do
		local x0 = meterX(Config.TrackStart + (i - 1) * Config.ZoneLength)
		keys[#keys + 1] = ColorSequenceKeypoint.new(math.clamp(x0 + 0.005, 0.001, 0.998), Config.Rarities[i].Color)
	end
	keys[#keys + 1] = ColorSequenceKeypoint.new(1, LAVA)
	table.sort(keys, function(a, b)
		return a.Time < b.Time
	end)
	g.Color = ColorSequence.new(keys)
	g.Parent = meter
end
for i = 1, zoneCount do
	local tick = Instance.new("Frame")
	tick.BorderSizePixel = 0
	tick.BackgroundColor3 = BLACK
	tick.BackgroundTransparency = 0.4
	tick.Position = UDim2.new(meterX(Config.TrackStart + (i - 1) * Config.ZoneLength), -1, 0, 0)
	tick.Size = UDim2.new(0, 2, 1, 0)
	tick.Parent = meter
end
icon(meter, "home", "🏠", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, -6, 0.5, 0), Size = UDim2.fromOffset(40, 40), ZIndex = 3 })
icon(meter, "volcano", "🌋", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, 8, 0.5, 0), Size = UDim2.fromOffset(44, 44), ZIndex = 3 })
local meVis = Instance.new("ImageLabel")
meVis.AnchorPoint = Vector2.new(0.5, 0.5)
meVis.Size = UDim2.fromOffset(34, 34)
meVis.Position = UDim2.fromScale(0, 0.5)
meVis.BackgroundColor3 = WHITE
meVis.ZIndex = 5
meVis.Parent = meter
corner(meVis, 17)
stroke(meVis, 3)
task.spawn(function()
	local ok, img = pcall(Players.GetUserThumbnailAsync, Players, player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
	if ok then
		meVis.Image = img
	end
end)
local waveVis = text(meter, "🔥", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(34, 34),
	Visible = false, ZIndex = 4 })
local waveTimer = text(gui, "", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46), Size = UDim2.fromOffset(300, 26),
	TextColor3 = Color3.fromRGB(255, 190, 120) })
local zoneLbl = text(gui, "", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 72), Size = UDim2.fromOffset(300, 22) })

-- announcement feed
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
	local l = text(feed, str, { Size = UDim2.new(1, 0, 0, 26), TextColor3 = color or WHITE, LayoutOrder = feedN })
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
	gradient(p, Color3.fromRGB(90, 60, 80), Color3.fromRGB(40, 26, 44))
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
-- Shop (tabs: Passes / Cash / Boosts)
---------------------------------------------------------------------------
local shopPanel, shopBody = makePanel("Shop", "🛒 SHOP", Color3.fromRGB(255, 150, 40), 600, 440)
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
		TextColor3 = Color3.fromRGB(235, 230, 240), TextWrapped = true })
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
-- Upgrades panel (speed + carry, bought with cash)
---------------------------------------------------------------------------
local _, upBody = makePanel("Upgrades", "⚡ UPGRADES", Color3.fromRGB(80, 160, 255), 560, 360)
local upgradeCards = {}
local function upgradeCard(kind, img, emoji, title, color, x)
	local c = Instance.new("Frame")
	c.Position = UDim2.new(x, x == 0 and 0 or 8, 0, 6)
	c.Size = UDim2.new(0.5, -8, 1, -12)
	c.BackgroundColor3 = WHITE
	c.ZIndex = 22
	c.Parent = upBody
	corner(c, 18)
	stroke(c, 3)
	gradient(c, color, shade(color, 0.55))
	icon(c, img, emoji, { Position = UDim2.new(0.5, -44, 0, -18), Size = UDim2.fromOffset(88, 88), ZIndex = 23 })
	text(c, title, { Font = TITLE, Position = UDim2.fromOffset(8, 70), Size = UDim2.new(1, -16, 0, 32), ZIndex = 23 })
	local lvl = text(c, "", { Position = UDim2.fromOffset(8, 104), Size = UDim2.new(1, -16, 0, 24), ZIndex = 23, TextColor3 = GOLD })
	local stat = text(c, "", { Position = UDim2.fromOffset(8, 130), Size = UDim2.new(1, -16, 0, 40), ZIndex = 23, TextWrapped = true })
	local buy = juicy(bubbleButton(c, "", GREEN, { Position = UDim2.new(0, 12, 1, -60), Size = UDim2.new(1, -24, 0, 48), ZIndex = 23 }))
	buy.Activated:Connect(function()
		action("Upgrade", kind)
	end)
	upgradeCards[kind] = { Level = lvl, Stat = stat, Buy = buy }
end
upgradeCard("Speed", "speed", "👟", "SPEED", Color3.fromRGB(80, 170, 255), 0)
upgradeCard("Carry", "carry", "🎒", "CARRY", Color3.fromRGB(255, 140, 60), 0.5)
local function refreshUpgrades()
	local sl, cl = get("SpeedLvl"), get("CarryLvl")
	local sp = upgradeCards.Speed
	local speedMult = player:GetAttribute("Pass_Speed") and 1.3 or 1
	sp.Level.Text = "Level " .. sl .. " / " .. Config.MaxSpeedLevel
	sp.Stat.Text = string.format("Speed %d → %d", (Config.BaseSpeed + sl * Config.SpeedPerLevel) * speedMult,
		(Config.BaseSpeed + math.min(sl + 1, Config.MaxSpeedLevel) * Config.SpeedPerLevel) * speedMult)
	sp.Buy.Text = sl >= Config.MaxSpeedLevel and "MAX" or "$" .. Config.Format(Config.SpeedCost(sl))
	local cr = upgradeCards.Carry
	local doubled = player:GetAttribute("Pass_DoubleCarry") == true
	cr.Level.Text = "Level " .. cl .. " / " .. Config.MaxCarryLevel
	cr.Stat.Text = "Carry " .. Config.Capacity(cl, doubled) .. " → " .. Config.Capacity(math.min(cl + 1, Config.MaxCarryLevel), doubled)
	cr.Buy.Text = cl >= Config.MaxCarryLevel and "MAX" or "$" .. Config.Format(Config.CarryCost(cl))
	local cash = get("Cash")
	sp.Buy.BackgroundTransparency = (sl < Config.MaxSpeedLevel and cash >= Config.SpeedCost(sl)) and 0 or 0.45
	cr.Buy.BackgroundTransparency = (cl < Config.MaxCarryLevel and cash >= Config.CarryCost(cl)) and 0 or 0.45
end
for _, k in ipairs({ "SpeedLvl", "CarryLvl", "Cash", "Pass_Speed", "Pass_DoubleCarry" }) do
	player:GetAttributeChangedSignal(k):Connect(refreshUpgrades)
end
refreshUpgrades()

---------------------------------------------------------------------------
-- Rebirth panel
---------------------------------------------------------------------------
local _, rebBody = makePanel("Rebirth", "🔄 REBIRTH", Color3.fromRGB(190, 90, 255), 460, 330)
local rebInfo = text(rebBody, "", { Size = UDim2.new(1, 0, 0, 120), TextWrapped = true, ZIndex = 22 })
local rebBtn = juicy(bubbleButton(rebBody, "REBIRTH", Color3.fromRGB(190, 90, 255), {
	Position = UDim2.new(0.5, -130, 0, 140), Size = UDim2.fromOffset(260, 64), ZIndex = 22 }))
text(rebBody, "Resets cash and base critters. Keeps upgrades & passes.", { Position = UDim2.fromOffset(0, 214), Size = UDim2.new(1, 0, 0, 24),
	TextColor3 = Color3.fromRGB(220, 210, 230), ZIndex = 22 })
rebBtn.Activated:Connect(function()
	action("Rebirth")
end)

---------------------------------------------------------------------------
-- Index panel (critter collection)
---------------------------------------------------------------------------
local _, idxBody = makePanel("Index", "📖 CRITTER INDEX", Color3.fromRGB(255, 90, 60), 620, 450)
local idxScroll = Instance.new("ScrollingFrame")
idxScroll.BackgroundTransparency = 1
idxScroll.BorderSizePixel = 0
idxScroll.Size = UDim2.new(1, 0, 1, -30)
idxScroll.Position = UDim2.fromOffset(0, 30)
idxScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
idxScroll.CanvasSize = UDim2.new()
idxScroll.ScrollBarThickness = 6
idxScroll.ZIndex = 21
idxScroll.Parent = idxBody
local idxCount = text(idxBody, "", { Size = UDim2.new(1, 0, 0, 26), ZIndex = 22, TextColor3 = GOLD })
local idxGrid = Instance.new("UIGridLayout")
idxGrid.CellSize = UDim2.fromOffset(132, 122)
idxGrid.CellPadding = UDim2.fromOffset(10, 10)
idxGrid.Parent = idxScroll
local idxCards = {}
for _, def in ipairs(Config.Critters) do
	local r = Config.Rarity(def.Rarity)
	local c = Instance.new("Frame")
	c.BackgroundColor3 = WHITE
	c.ZIndex = 22
	c.Parent = idxScroll
	corner(c, 14)
	stroke(c, 3)
	gradient(c, r.Color, shade(r.Color, 0.4))
	-- a little round critter face drawn in UI
	local blob = Instance.new("Frame")
	blob.AnchorPoint = Vector2.new(0.5, 0)
	blob.Position = UDim2.new(0.5, 0, 0, 8)
	blob.Size = UDim2.fromOffset(56, 50)
	blob.BackgroundColor3 = def.Color
	blob.ZIndex = 23
	blob.Parent = c
	corner(blob, 25)
	stroke(blob, 3)
	for _, ex in ipairs({ 0.32, 0.68 }) do
		local eye = Instance.new("Frame")
		eye.AnchorPoint = Vector2.new(0.5, 0.5)
		eye.Position = UDim2.fromScale(ex, 0.42)
		eye.Size = UDim2.fromOffset(12, 16)
		eye.BackgroundColor3 = BLACK
		eye.ZIndex = 24
		eye.Parent = blob
		corner(eye, 6)
	end
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.78)
	glow.Size = UDim2.fromOffset(18, 6)
	glow.BackgroundColor3 = def.Glow
	glow.ZIndex = 24
	glow.Parent = blob
	corner(glow, 3)
	local nameL = text(c, "???", { Position = UDim2.fromOffset(4, 64), Size = UDim2.new(1, -8, 0, 24), ZIndex = 23 })
	text(c, def.Rarity .. " • $" .. Config.Format(def.Income) .. "/s", { Position = UDim2.fromOffset(4, 92), Size = UDim2.new(1, -8, 0, 20),
		ZIndex = 23, TextColor3 = Color3.fromRGB(235, 235, 235) })
	idxCards[def.Name] = { Blob = blob, Name = nameL }
end
local function refreshIndex()
	local found, n = {}, 0
	for name in string.gmatch(player:GetAttribute("Discovered") or "", "[^|]+") do
		found[name] = true
		n += 1
	end
	for name, c in pairs(idxCards) do
		c.Name.Text = found[name] and name or "???"
		c.Blob.BackgroundTransparency = found[name] and 0 or 0.85
		for _, d in ipairs(c.Blob:GetChildren()) do
			if d:IsA("Frame") then
				d.Visible = found[name] == true
			end
		end
	end
	idxCount.Text = "Found " .. n .. " / " .. #Config.Critters
end
player:GetAttributeChangedSignal("Discovered"):Connect(refreshIndex)
refreshIndex()

---------------------------------------------------------------------------
-- Left menu, right column, bottom status
---------------------------------------------------------------------------
local menu = Instance.new("Frame")
menu.BackgroundTransparency = 1
menu.AnchorPoint = Vector2.new(0, 0.5)
menu.Position = UDim2.new(0, 14, 0.52, 0)
menu.Size = UDim2.fromOffset(84, 460)
menu.Parent = gui
local menuList = Instance.new("UIListLayout")
menuList.Padding = UDim.new(0, 10)
menuList.Parent = menu
local function menuButton(img, emoji, label, color)
	local b = juicy(bubbleButton(menu, "", color, { Size = UDim2.fromOffset(78, 78) }))
	icon(b, img, emoji, { Position = UDim2.fromOffset(2, -14), Size = UDim2.new(1, -4, 0, 64) })
	text(b, label, { Position = UDim2.new(0, -4, 1, -26), Size = UDim2.new(1, 8, 0, 24) })
	return b
end
local shopBtn = menuButton("shop", "🛒", "SHOP", Color3.fromRGB(255, 150, 40))
local upBtn = menuButton("upgrade", "⚡", "UPGRADE", Color3.fromRGB(80, 160, 255))
local indexBtn = menuButton("index", "📖", "INDEX", Color3.fromRGB(255, 90, 60))
local rebirthBtn = menuButton("rebirth", "🔄", "REBIRTH", Color3.fromRGB(190, 90, 255))
local dailyBtn = menuButton("daily", "📅", "DAILY", Color3.fromRGB(255, 80, 140))
shopBtn.Activated:Connect(function()
	openShop("Passes")
end)
upBtn.Activated:Connect(function()
	open("Upgrades")
end)
indexBtn.Activated:Connect(function()
	open("Index")
end)
rebirthBtn.Activated:Connect(function()
	open("Rebirth")
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
local upBadge = badge(upBtn, "!")
local dailyBadge = badge(dailyBtn, "!")

local right = Instance.new("Frame")
right.BackgroundTransparency = 1
right.AnchorPoint = Vector2.new(1, 0.5)
right.Position = UDim2.new(1, -14, 0.5, 0)
right.Size = UDim2.fromOffset(110, 400)
right.Parent = gui
local rightList = Instance.new("UIListLayout")
rightList.Padding = UDim.new(0, 12)
rightList.HorizontalAlignment = Enum.HorizontalAlignment.Right
rightList.Parent = right
local giftBtn = juicy(bubbleButton(right, "", Color3.fromRGB(255, 90, 160), { Size = UDim2.fromOffset(96, 96) }))
icon(giftBtn, "gift", "🎁", { Position = UDim2.fromOffset(6, -16), Size = UDim2.new(1, -12, 0, 74) })
local giftLbl = text(giftBtn, "", { Position = UDim2.new(0, -4, 1, -32), Size = UDim2.new(1, 8, 0, 28) })
giftBtn.Activated:Connect(function()
	action("Gift")
end)
local function sideButton(img, emoji, label, color)
	local b = juicy(bubbleButton(right, Assets[img] and "     " .. label or emoji .. " " .. label, color, { Size = UDim2.fromOffset(104, 48) }))
	if Assets[img] then
		icon(b, img, emoji, { Position = UDim2.fromOffset(-18, -16), Size = UDim2.fromOffset(50, 50), Rotation = -12 })
	end
	return b
end
local luckBtn = sideButton("luck", "🍀", "LUCK", Color3.fromRGB(60, 200, 90))
local freezeBtn = sideButton("freeze", "🧊", "FREEZE", Color3.fromRGB(90, 190, 255))
local reviveBtn = sideButton("revive", "💖", "SHIELD", Color3.fromRGB(255, 80, 120))
luckBtn.Activated:Connect(function()
	action("Buy", "Product", "Luck")
end)
freezeBtn.Activated:Connect(function()
	action("Buy", "Product", "Freeze")
end)
reviveBtn.Activated:Connect(function()
	openShop("Boosts")
end)
local luckLbl = text(right, "", { Size = UDim2.fromOffset(110, 36), Visible = false, TextColor3 = Color3.fromRGB(140, 255, 150) })
local shieldLbl = text(right, "", { Size = UDim2.fromOffset(110, 30), Visible = false, TextColor3 = Color3.fromRGB(255, 170, 200) })

-- music toggle (bottom left)
local musicBtn = juicy(bubbleButton(gui, Assets.music and "" or "🎵", Color3.fromRGB(80, 150, 255), {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -14), Size = UDim2.fromOffset(54, 54) }))
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

-- backpack counter + status line at the bottom
local bag = Instance.new("Frame")
bag.AnchorPoint = Vector2.new(0.5, 1)
bag.Position = UDim2.new(0.5, 0, 1, -16)
bag.Size = UDim2.fromOffset(190, 56)
bag.BackgroundColor3 = WHITE
bag.Parent = gui
corner(bag, 28)
stroke(bag, 4)
local bagGrad = gradient(bag, Color3.fromRGB(255, 160, 60), Color3.fromRGB(200, 80, 30))
icon(bag, "carry", "🎒", { Position = UDim2.fromOffset(-16, -14), Size = UDim2.fromOffset(72, 72), Rotation = -8 })
local bagLbl = text(bag, "0/1", { Font = TITLE, Position = UDim2.fromOffset(56, 6), Size = UDim2.new(1, -66, 0, 44) })
local status = text(gui, "", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -78), Size = UDim2.fromOffset(560, 34),
	Visible = false })
local hint = text(gui, "Run toward the volcano 🌋 • hold E to grab critters • hide in 🛡️ SAFE pockets when the lava comes!",
	{ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -118), Size = UDim2.fromOffset(720, 26),
		TextColor3 = Color3.fromRGB(255, 240, 150) })
task.delay(30, function()
	hint:Destroy()
end)

---------------------------------------------------------------------------
-- Offers (incl. the revive offer after a wipe-out)
---------------------------------------------------------------------------
local offer, offerBody = makePanel("Offer", "🔥 LIMITED OFFER 🔥", Color3.fromRGB(255, 60, 90), 420, 320)
local offerTitle = text(offerBody, "", { Size = UDim2.new(1, 0, 0, 50), TextColor3 = GOLD, ZIndex = 22, Font = TITLE })
local offerPitch = text(offerBody, "", { Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 56), TextWrapped = true, ZIndex = 22 })
local offerTimer = text(offerBody, "", { Position = UDim2.fromOffset(0, 114), Size = UDim2.new(1, 0, 0, 26),
	TextColor3 = Color3.fromRGB(255, 130, 130), ZIndex = 22 })
local offerBuy = juicy(bubbleButton(offerBody, "BUY", GREEN, { Position = UDim2.new(0.5, -140, 0, 152), Size = UDim2.fromOffset(280, 62), ZIndex = 22 }))
local offerIcon = icon(offer, "starter", "🎒", { Position = UDim2.fromOffset(-34, -40), Size = UDim2.fromOffset(110, 110),
	Rotation = -14, ZIndex = 30 })
local currentOffer
local offerEnds = 0
local function showOffer(o, seconds, force)
	if not o or (offer.Visible and not force) then
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
	offerEnds = os.clock() + (seconds or 300)
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
		-- don't cover the screen mid-run; wait until they're home
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		while root and root.Position.X > 0 do
			task.wait(2)
			root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		end
		showOffer(Config.Offers[i])
		i = i % #Config.Offers + 1
		task.wait(Config.OfferInterval)
	end
end)

task.delay(180, function()
	local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
	if ok and can then
		pcall(SocialService.PromptGameInvite, SocialService, player)
	end
end)

---------------------------------------------------------------------------
-- The lava wave (drawn locally from the server's clock so it moves perfectly smoothly)
---------------------------------------------------------------------------
local waveModel = Instance.new("Model")
waveModel.Name = "LavaWave"
local wavePieces = {}
local function wpart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	p.Parent = waveModel
	return p
end
local WAVE_W = Config.TrackWidth + 2
-- body: a tall slab with a rounded rolling crest in front and glowing cracks
wavePieces.Body = { P = wpart({ Size = Vector3.new(24, 1, WAVE_W), Color = Color3.fromRGB(230, 70, 15) }), Off = Vector3.new(14, 0, 0), H = 1 }
wavePieces.Crust = { P = wpart({ Size = Vector3.new(16, 1, WAVE_W + 0.4), Color = Color3.fromRGB(90, 30, 25), Material = Enum.Material.SmoothPlastic,
	Transparency = 0.15 }), Off = Vector3.new(22, 0.06, 0), H = 1 }
local crest = {}
for k = 0, 7 do
	local p = wpart({ Shape = Enum.PartType.Ball, Size = Vector3.new(10, 10, 10), Color = k % 2 == 0 and LAVA or LAVA_HOT })
	crest[#crest + 1] = { P = p, Z = -WAVE_W / 2 + 3.5 + k * (WAVE_W - 7) / 7, Phase = k * 0.9 }
end
local foam = {}
for k = 0, 13 do
	local p = wpart({ Shape = Enum.PartType.Ball, Size = Vector3.new(4, 4, 4), Color = LAVA_HOT })
	foam[#foam + 1] = { P = p, Z = -WAVE_W / 2 + 2 + k * (WAVE_W - 4) / 13, Phase = k * 1.7 }
end
local emit = wpart({ Size = Vector3.new(4, 1, WAVE_W), Transparency = 1 })
local fire = Instance.new("ParticleEmitter")
fire.Texture = "rbxasset://textures/particles/fire_main.dds"
fire.Color = ColorSequence.new(LAVA_HOT, LAVA)
fire.LightEmission = 1
fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 1) })
fire.Lifetime = NumberRange.new(0.6, 1.1)
fire.Rate = 120
fire.Speed = NumberRange.new(10, 20)
fire.SpreadAngle = Vector2.new(30, 30)
fire.EmissionDirection = Enum.NormalId.Top
fire.Parent = emit
local smoke = Instance.new("ParticleEmitter")
smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
smoke.Color = ColorSequence.new(Color3.fromRGB(80, 60, 60))
smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 22) })
smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
smoke.Lifetime = NumberRange.new(1.5, 2.5)
smoke.Rate = 30
smoke.Speed = NumberRange.new(6, 12)
smoke.EmissionDirection = Enum.NormalId.Top
smoke.Parent = emit
local spray = Instance.new("ParticleEmitter")
spray.Texture = "rbxasset://textures/particles/sparkles_main.dds"
spray.Color = ColorSequence.new(LAVA_HOT)
spray.LightEmission = 1
spray.Size = NumberSequence.new(1.2, 0)
spray.Lifetime = NumberRange.new(0.5, 1)
spray.Rate = 80
spray.Speed = NumberRange.new(20, 40)
spray.SpreadAngle = Vector2.new(40, 40)
spray.Acceleration = Vector3.new(0, -60, 0)
spray.EmissionDirection = Enum.NormalId.Left
spray.Parent = emit
local light = Instance.new("PointLight")
light.Color = LAVA
light.Range = 60
light.Brightness = 4
light.Parent = emit
waveModel.Parent = workspace

local baseTransparency = {}
for _, d in ipairs(waveModel:GetDescendants()) do
	if d:IsA("BasePart") then
		baseTransparency[d] = d.Transparency
	end
end
local function hideWave()
	for _, d in ipairs(waveModel:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = 1
		elseif d:IsA("ParticleEmitter") then
			d.Enabled = false
		elseif d:IsA("PointLight") then
			d.Enabled = false
		end
	end
end
local function showWave()
	for _, d in ipairs(waveModel:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = baseTransparency[d] or 0
		elseif d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			d.Enabled = true
		end
	end
end
hideWave()
local waveShown = false

local function placeWave(front, height, t)
	-- rises out of the crater during the first second
	local h = height
	local cx = front
	local body = wavePieces.Body
	body.P.Size = Vector3.new(24, h, WAVE_W)
	body.P.CFrame = CFrame.new(cx + 14, h / 2, 0)
	local crust = wavePieces.Crust
	crust.P.Size = Vector3.new(16, h * 0.7, WAVE_W + 0.4)
	crust.P.CFrame = CFrame.new(cx + 24, h * 0.35, 0)
	for _, c in ipairs(crest) do
		local r = h * 0.62 + math.sin(t * 5 + c.Phase) * 1.2
		c.P.Size = Vector3.new(r, r, r)
		c.P.CFrame = CFrame.new(cx + r * 0.3 + math.sin(t * 7 + c.Phase) * 0.8, h - r * 0.32, c.Z)
	end
	for _, f in ipairs(foam) do
		local y = h + 0.6 + math.abs(math.sin(t * 6 + f.Phase)) * 3
		f.P.CFrame = CFrame.new(cx + 2 + math.sin(t * 4 + f.Phase) * 2, y, f.Z)
	end
	emit.Size = Vector3.new(4, 1, WAVE_W)
	emit.CFrame = CFrame.new(cx, h, 0)
end

---------------------------------------------------------------------------
-- Live updates
---------------------------------------------------------------------------
local shownCash = 0
local brokeCount = 0
local lastZone = -1
local lastTick = -1
local wasWave = false
local heatA = 0
RunService.RenderStepped:Connect(function(dt)
	local now = serverNow()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local pos = root and root.Position or Vector3.zero
	-- cash
	local target = get("Cash")
	if shownCash ~= target then
		shownCash += (target - shownCash) * math.min(dt * 10, 1)
		if math.abs(target - shownCash) < 1 then
			shownCash = target
		end
		cashLbl.Text = "$" .. Config.Format(shownCash)
	end
	incomeLbl.Text = "+$" .. Config.Format(get("Income")) .. "/s"
	-- run meter
	meVis.Position = UDim2.fromScale(meterX(math.max(pos.X, 0)), 0.5)
	-- zone label
	local zone = Config.ZoneAt(pos.X)
	if pos.X < 0 then
		zone = -1
	end
	if zone ~= lastZone then
		lastZone = zone
		if zone >= 1 then
			local r = Config.Rarities[zone]
			zoneLbl.Text = "ZONE " .. zone .. ": " .. string.upper(Config.ZoneNames[zone])
			zoneLbl.TextColor3 = r.Color
			if zone > 1 then
				showBanner("ZONE " .. zone .. " • " .. string.upper(r.Name) .. " CRITTERS", r.Color, 1.2)
				sfx("tap", 0.5, 0.8 + zone * 0.08)
			end
		elseif zone == 0 then
			zoneLbl.Text = "STARTING LINE"
			zoneLbl.TextColor3 = WHITE
		else
			zoneLbl.Text = "🏠 HOME (safe)"
			zoneLbl.TextColor3 = Color3.fromRGB(140, 255, 170)
		end
	end
	-- wave
	local start = workspace:GetAttribute("WaveStart") or 0
	local speed = workspace:GetAttribute("WaveSpeed") or 60
	local height = workspace:GetAttribute("WaveHeight") or 18
	local from = workspace:GetAttribute("WaveFrom") or (Config.TrackEnd() + 70)
	local to = workspace:GetAttribute("WaveTo") or -6
	local frozen = (workspace:GetAttribute("FrozenUntil") or 0) - now
	local onTrack = pos.X > 0 and math.abs(pos.Z) < HALF + 0.5
	local heatTarget = 0
	if start > 0 and now < start + (from - to) / speed then
		local t = now - start
		if t < 0 then
			-- warning
			countdown.Visible = true
			local secs = math.ceil(-t)
			countdown.Text = "🌋 " .. string.upper(workspace:GetAttribute("WaveName") or "LAVA WAVE") .. " IN " .. secs .. "!"
			if secs ~= lastTick then
				lastTick = secs
				punch(countdown, 0.35)
				sfx("alarm", 0.35, 1 + (5 - secs) * 0.04)
			end
			heatTarget = onTrack and 0.35 + 0.15 * math.sin(os.clock() * 10) or 0.1
			waveTimer.Text = onTrack and "🛡️ GET TO A SAFE POCKET!" or "You're safe here"
			waveVis.Visible = true
			waveVis.Position = UDim2.fromScale(meterX(from), 0.5)
		else
			if not waveShown then
				waveShown = true
				showWave()
				sfx("whoosh", 0.7)
			end
			local front = from - speed * t
			local rise = math.clamp(t / 1.2, 0.15, 1)
			placeWave(front, height * rise, os.clock())
			waveVis.Visible = true
			waveVis.Position = UDim2.fromScale(meterX(front), 0.5)
			local d = pos.X - front
			countdown.Visible = onTrack and d < 0 and d > -260
			countdown.Text = "🔥 HIDE! 🔥"
			heatTarget = onTrack and math.clamp(1 - math.abs(d) / 200, 0.15, 0.85) or 0.05
			if d < 0 and d > -140 then
				kick(dt * (1 - (-d) / 140) * 2.5)
			end
			rumble.Volume = math.clamp(1 - math.abs(d) / 260, 0, 1) * 0.9
			waveTimer.Text = "🌋 " .. (workspace:GetAttribute("WaveName") or "LAVA WAVE") .. "!"
		end
		wasWave = true
	else
		if wasWave then
			wasWave = false
			waveShown = false
			hideWave()
			countdown.Visible = false
			waveVis.Visible = false
			rumble.Volume = 0
			lastTick = -1
			if root and pos.X > 0 then
				local h = char:FindFirstChildOfClass("Humanoid")
				if h and h.Health > 0 then
					showBanner("😮‍💨 SURVIVED!", Color3.fromRGB(140, 255, 170), 1)
					sfx("kaching", 0.4)
				end
			end
		end
		local nextWave = (workspace:GetAttribute("NextWave") or 0) - now
		if frozen > 0 then
			waveTimer.Text = string.format("🧊 LAVA FROZEN %d:%02d", math.floor(frozen / 60), math.floor(frozen % 60))
		elseif nextWave > 0 then
			waveTimer.Text = string.format("🌋 Next wave in %d", math.ceil(nextWave))
		else
			waveTimer.Text = ""
		end
	end
	heatA += (heatTarget - heatA) * math.min(dt * 6, 1)
	setHeat(heatA)
	-- backpack
	local carry, cap = get("Carry"), math.max(get("Capacity"), 1)
	bagLbl.Text = carry .. "/" .. cap
	if carry >= cap then
		bagGrad.Color = ColorSequence.new(Color3.fromRGB(255, 80, 80), Color3.fromRGB(180, 30, 40))
		bag.Rotation = math.sin(os.clock() * 12) * 3
	else
		bagGrad.Color = ColorSequence.new(Color3.fromRGB(255, 160, 60), Color3.fromRGB(200, 80, 30))
		bag.Rotation = 0
	end
	if carry > 0 and pos.X > 0 then
		status.Visible = true
		status.Text = carry >= cap and "🎒 FULL! RUN HOME TO BANK YOUR CRITTERS!" or "🏃 Bring them home to bank them!"
		status.TextColor3 = Color3.fromHSV((os.clock() * 1.5) % 1, 0.5, 1)
	else
		status.Visible = false
	end
	-- gift / daily / badges
	local giftLeft = get("GiftAt") - os.time()
	if giftLeft <= 0 then
		giftLbl.Text = "CLAIM!"
		giftBtn.Rotation = math.sin(os.clock() * 10) * 6
	else
		giftLbl.Text = string.format("%d:%02d", math.floor(giftLeft / 60), math.floor(giftLeft % 60))
		giftBtn.Rotation = 0
	end
	dailyBadge.Visible = os.time() - get("LastDaily") >= 86400
	saleBadge.Rotation = math.sin(os.clock() * 4) * 15
	local sl, cl, cash = get("SpeedLvl"), get("CarryLvl"), get("Cash")
	upBadge.Visible = (sl < Config.MaxSpeedLevel and cash >= Config.SpeedCost(sl)) or (cl < Config.MaxCarryLevel and cash >= Config.CarryCost(cl))
	local luckLeft = (workspace:GetAttribute("LuckUntil") or 0) - now
	luckLbl.Visible = luckLeft > 0
	if luckLeft > 0 then
		luckLbl.Text = string.format("🍀 x3 %d:%02d", math.floor(luckLeft / 60), math.floor(luckLeft % 60))
	end
	local shields = get("Shields")
	shieldLbl.Visible = shields > 0
	shieldLbl.Text = "🛡️ x" .. shields
	-- offer countdown
	if offer.Visible then
		offerIcon.Rotation = -14 + math.sin(os.clock() * 3) * 6
		local left = math.max(0, offerEnds - os.clock())
		offerTimer.Text = string.format("⏰ ENDS IN %d:%02d", math.floor(left / 60), math.floor(left % 60))
		if left <= 0 then
			offer.Visible = false
		end
	end
	local reb = get("Rebirths")
	rebInfo.Text = "Rebirth " .. reb .. " → " .. (reb + 1) .. "\nIncome x" .. Config.RebirthMult(reb) .. " → x" .. Config.RebirthMult(reb + 1)
		.. "\nCost: $" .. Config.Format(Config.RebirthCost(reb))
end)

-- wild critters bob and turn a little so the track feels alive
local bobbers = {}
local function track(m)
	if m:IsA("Model") and m:GetAttribute("Wild") then
		bobbers[m] = { Base = m:GetPivot(), Phase = rng:NextNumber(0, 6) }
	end
end
task.spawn(function()
	local folder = workspace:WaitForChild("World"):WaitForChild("Critters")
	for _, m in ipairs(folder:GetChildren()) do
		track(m)
	end
	folder.ChildAdded:Connect(function(m)
		task.wait()
		track(m)
	end)
	folder.ChildRemoved:Connect(function(m)
		bobbers[m] = nil
	end)
end)
RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for m, b in pairs(bobbers) do
		if m.Parent then
			m:PivotTo(b.Base * CFrame.new(0, math.abs(math.sin(t * 3 + b.Phase)) * 0.8, 0) * CFrame.Angles(0, math.sin(t * 1.3 + b.Phase) * 0.5, 0))
		end
	end
end)

-- base labels only show on my own base; sell prompts only on my own critters
local function baseLabel(bb)
	if not bb:IsA("BillboardGui") or bb:GetAttribute("Plot") == nil then
		return
	end
	local function apply()
		bb.Enabled = bb:GetAttribute("Plot") == player:GetAttribute("Plot") and not bb:GetAttribute("Unlocked")
	end
	apply()
	bb.AttributeChanged:Connect(apply)
	player:GetAttributeChangedSignal("Plot"):Connect(apply)
end
local function setupPrompt(p)
	if p:IsA("ProximityPrompt") and p.Name == "Sell" then
		local m = p:FindFirstAncestorOfClass("Model")
		p.Enabled = m ~= nil and m:GetAttribute("OwnerId") == player.UserId
	end
end
for _, d in ipairs(workspace:GetDescendants()) do
	baseLabel(d)
	setupPrompt(d)
end
workspace.DescendantAdded:Connect(function(d)
	baseLabel(d)
	task.defer(setupPrompt, d)
end)

---------------------------------------------------------------------------
-- Server effects
---------------------------------------------------------------------------
local function center()
	local vp = camera.ViewportSize
	return vp.X / 2, vp.Y * 0.45
end

remotes:WaitForChild("Fx").OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "Toast" then
		notify(a, WHITE)
		sfx("toast", 0.4)
	elseif kind == "Announce" then
		notify(a, b)
		sfx("bell", 0.4)
	elseif kind == "Collect" then
		local x, y = center()
		floater("+$" .. Config.Format(a), Color3.fromRGB(120, 255, 120), x, y, 70)
		punch(cashBar, 0.25)
		confetti(math.clamp(math.floor(math.log10(a + 1) * 10), 10, 80))
		sfx("coins", 0.7)
		for i = 0, 4 do
			task.delay(i * 0.06, function()
				sfx("chip", 0.3, 1 + i * 0.12)
			end)
		end
		kick(0.3)
	elseif kind == "Grabbed" then
		local r, ri = Config.Rarity(b)
		local x, y = center()
		floater("+1 " .. a, r.Color, x, y - 40, 44)
		punch(bag, 0.3)
		sfx("grab", 0.55, 1 + ri * 0.05)
		if c then
			notify("📖 NEW! " .. a .. " added to your Index", r.Color)
		end
		if ri >= 4 then
			showBanner("WOW! " .. string.upper(b) .. " " .. string.upper(a) .. "!", r.Color)
			sfx("rare", 0.7)
			confetti(50, { r.Color, WHITE, GOLD })
			kick(0.5)
		end
	elseif kind == "Full" then
		notify("🎒 Backpack full (" .. a .. ")! Run home, or upgrade CARRY", Color3.fromRGB(255, 180, 120))
		punch(bag, 0.4)
		sfx("error", 0.4)
	elseif kind == "Deposited" then
		local placed, sold, best = a, b, c
		local r = Config.Rarities[best] or Config.Rarities[1]
		if placed > 0 then
			showBanner("🏠 SAFE! +" .. placed .. " CRITTER" .. (placed == 1 and "" or "S"), r.Color)
		else
			showBanner("🏠 SAFE! SOLD FOR $" .. Config.Format(sold), r.Color)
		end
		if sold > 0 then
			notify("Base full! Sold extras for $" .. Config.Format(sold), Color3.fromRGB(255, 230, 120))
		end
		sfx("win", 0.7)
		confetti(40 + best * 15)
		kick(0.4)
	elseif kind == "WaveWarning" then
		sfx("siren", 0.6)
	elseif kind == "WipedOut" then
		screenFlash(LAVA, 0.1)
		showBanner("🔥 WIPED OUT! 🔥", Color3.fromRGB(255, 90, 40), 2)
		sfx("splash", 0.8)
		kick(1.2)
		if a > 0 then
			showOffer({ Kind = "Product", Key = "Revive", Title = "REVIVE?",
				Pitch = "Get your " .. a .. " critter" .. (a == 1 and "" or "s") .. " back and keep running!" }, 20, true)
		end
	elseif kind == "Shielded" then
		screenFlash(Color3.fromRGB(255, 120, 200), 0.3)
		showBanner("🛡️ SHIELD SAVED YOU!", Color3.fromRGB(255, 160, 220))
		sfx("shield", 0.7)
	elseif kind == "Revived" then
		screenFlash(Color3.fromRGB(255, 255, 255), 0.2)
		showBanner("💖 REVIVED! +" .. a .. " CRITTERS", Color3.fromRGB(255, 140, 200))
		sfx("thanks", 0.7)
		confetti(60)
	elseif kind == "Upgraded" then
		showBanner((a == "Speed" and "👟 SPEED " or "🎒 CARRY ") .. "LEVEL " .. b .. "!", a == "Speed" and Color3.fromRGB(120, 200, 255)
			or Color3.fromRGB(255, 170, 90))
		sfx("upgrade", 0.6)
		confetti(30)
	elseif kind == "OpenUpgrades" then
		if not panels.Upgrades.Visible then
			open("Upgrades")
		end
	elseif kind == "Broke" then
		notify("Need $" .. Config.Format(a) .. "!", Color3.fromRGB(255, 120, 120))
		punch(cashBar, 0.2)
		sfx("error", 0.5)
		brokeCount += 1
		if brokeCount % 3 == 0 then
			showOffer({ Kind = "Product", Key = "CashM", Title = "NEED CASH?", Pitch = "Grab a Bag of Cash and upgrade now!" })
		end
	elseif kind == "Rebirth" then
		showBanner("🔄 REBIRTH " .. a .. "!!!", Color3.fromRGB(200, 120, 255))
		confetti(150)
		kick(1)
		sfx("rebirth", 0.8)
		panels.Rebirth.Visible = false
	elseif kind == "Thanks" then
		showBanner("THANK YOU! 💖", Color3.fromRGB(255, 120, 200))
		sfx("thanks", 0.7)
		sfx("kaching", 0.5)
		confetti(120)
	elseif kind == "Welcome" then
		task.delay(8, function()
			showOffer(Config.Offers[1])
		end)
	end
end)

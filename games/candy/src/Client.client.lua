-- StarterPlayer.StarterPlayerScripts.Client (Candy Smash Simulator)
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local gui = Instance.new("ScreenGui")
gui.Name = "MainGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(obj, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	c.Parent = obj
end

local function label(parent, text, pos, size)
	local l = Instance.new("TextLabel")
	l.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	l.BackgroundTransparency = 0.25
	l.Position = pos
	l.Size = size
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Text = text
	l.Parent = parent
	corner(l)
	return l
end

local function button(parent, text, color, pos, size)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color
	b.Position = pos
	b.Size = size
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b)
	local s = Instance.new("UIStroke")
	s.Thickness = 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = b
	return b
end

-- Stats (top-left)
local powerLbl = label(gui, "", UDim2.new(0, 12, 0, 60), UDim2.fromOffset(220, 40))
local coinsLbl = label(gui, "", UDim2.new(0, 12, 0, 106), UDim2.fromOffset(220, 40))
local rebirthLbl = label(gui, "", UDim2.new(0, 12, 0, 152), UDim2.fromOffset(220, 40))

-- Main buttons (bottom-center)
local clickBtn = button(gui, "SMASH!", Color3.fromRGB(70, 140, 255), UDim2.new(0.5, -90, 1, -200), UDim2.fromOffset(180, 90))
local upgradeBtn = button(gui, "", Color3.fromRGB(60, 190, 90), UDim2.new(0.5, -290, 1, -100), UDim2.fromOffset(190, 70))
local rebirthBtn = button(gui, "", Color3.fromRGB(200, 70, 200), UDim2.new(0.5, -95, 1, -100), UDim2.fromOffset(190, 70))
local shopBtn = button(gui, "SHOP", Color3.fromRGB(255, 170, 30), UDim2.new(0.5, 100, 1, -100), UDim2.fromOffset(190, 70))

local hint = label(gui, "🍬 SPAM CLICK to smash candy, then SELL on the gold pad! 🍬", UDim2.new(0.5, -230, 0, 110), UDim2.fromOffset(460, 34))
task.delay(15, function()
	hint:Destroy()
end)

-- Shop panel
local shop = Instance.new("Frame")
shop.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
shop.Position = UDim2.new(0.5, -170, 0.5, -215)
shop.Size = UDim2.fromOffset(340, 430)
shop.Visible = false
shop.Parent = gui
corner(shop, 16)
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Parent = shop
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 10)
pad.Parent = shop

local function shopItem(name, color, onClick)
	local b = button(shop, name, color, UDim2.new(), UDim2.fromOffset(300, 54))
	b.Activated:Connect(onClick)
	return b
end

for _, gp in ipairs(Config.GamePasses) do
	local b = shopItem(gp.Name .. "  R$" .. gp.Price, Color3.fromRGB(80, 110, 230), function()
		remotes.Buy:FireServer("Pass", gp.Key)
	end)
	local function refresh()
		if player:GetAttribute("Pass_" .. gp.Key) then
			b.Text = gp.Name .. " (Owned)"
			b.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
		end
	end
	player:GetAttributeChangedSignal("Pass_" .. gp.Key):Connect(refresh)
	refresh()
end
for _, prod in ipairs(Config.Products) do
	shopItem(prod.Name .. "  R$" .. prod.Price, Color3.fromRGB(230, 160, 40), function()
		remotes.Buy:FireServer("Product", prod.Key)
	end)
end
shopItem("Close", Color3.fromRGB(180, 60, 60), function()
	shop.Visible = false
end)

-- Juice helpers
local camera = workspace.CurrentCamera
local rng = Random.new()

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function sound(id, volume, pitch)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.5
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
	task.delay(5, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end
local SND_CLICK = "rbxasset://sounds/electronicpingshort.wav"
local SND_TICK = "rbxasset://sounds/clickfast.wav"
local SND_WHOOSH = "rbxasset://sounds/swoosh.wav"

-- Bouncy scale on any GUI object
local scales = {}
local function punch(obj, amount)
	local sc = scales[obj]
	if not sc then
		sc = Instance.new("UIScale")
		sc.Parent = obj
		scales[obj] = sc
	end
	sc.Scale = 1 + (amount or 0.15)
	tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Screen shake + FOV kick
local shake = 0
local baseFov = camera.FieldOfView
local fovKick = 0
RunService:BindToRenderStep("Juice", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if shake > 0.001 then
		camera.CFrame *= CFrame.new(rng:NextNumber(-1, 1) * shake, rng:NextNumber(-1, 1) * shake, 0)
		shake *= math.exp(-dt * 18)
	end
	fovKick *= math.exp(-dt * 12)
	camera.FieldOfView = baseFov + fovKick
end)
local function kick(s, f)
	shake = math.min(shake + s, 1.2)
	fovKick = math.min(fovKick + f, 12)
end

-- Rainbow animated CLICK button
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 140)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 220)),
})
grad.Parent = clickBtn
clickBtn.BackgroundColor3 = Color3.new(1, 1, 1)
clickBtn.TextStrokeTransparency = 0
RunService.RenderStepped:Connect(function()
	grad.Rotation = (os.clock() * 120) % 360
end)
task.spawn(function()
	while true do
		punch(clickBtn, 0.06)
		task.wait(0.8)
	end
end)

-- Character sparkle burst
local burst
local function getBurst()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	if burst and burst.Parent and burst.Parent.Parent == root then
		return burst
	end
	local a = Instance.new("Attachment")
	a.Parent = root
	burst = Instance.new("ParticleEmitter")
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burst.Size = NumberSequence.new(0.8, 0)
	burst.Lifetime = NumberRange.new(0.4, 0.8)
	burst.Speed = NumberRange.new(12, 22)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.LightEmission = 1
	burst.Rate = 0
	burst.Parent = a
	return burst
end

-- Floating numbers
local fxLayer = Instance.new("Frame")
fxLayer.BackgroundTransparency = 1
fxLayer.Size = UDim2.fromScale(1, 1)
fxLayer.ZIndex = 50
fxLayer.Parent = gui

local function floater(text, color, x, y, size)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromOffset(x, y)
	l.Size = UDim2.fromOffset(size * 6, size)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	l.TextStrokeTransparency = 0
	l.Rotation = rng:NextNumber(-20, 20)
	l.ZIndex = 51
	l.Parent = fxLayer
	punch(l, 0.6)
	local dx = rng:NextNumber(-80, 80)
	tween(l, 0.9, { Position = UDim2.fromOffset(x + dx, y - rng:NextNumber(90, 160)), Rotation = l.Rotation * 2 })
	tween(l, 0.9, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.95, function()
		l:Destroy()
	end)
end

local function confetti(n, originY)
	local vp = camera.ViewportSize
	for _ = 1, n do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.Size = UDim2.fromOffset(rng:NextInteger(8, 16), rng:NextInteger(8, 16))
		f.BackgroundColor3 = Color3.fromHSV(rng:NextNumber(), 0.8, 1)
		local x = rng:NextNumber(0, vp.X)
		f.Position = UDim2.fromOffset(x, originY or -20)
		f.Rotation = rng:NextNumber(0, 360)
		f.ZIndex = 49
		f.Parent = fxLayer
		local t = rng:NextNumber(1, 2)
		tween(f, t, {
			Position = UDim2.fromOffset(x + rng:NextNumber(-150, 150), vp.Y + 40),
			Rotation = f.Rotation + rng:NextNumber(-720, 720),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(t, function()
			f:Destroy()
		end)
	end
end

-- Big center banner (combo milestones, crits, rebirth)
local banner = Instance.new("TextLabel")
banner.BackgroundTransparency = 1
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.fromScale(0.5, 0.3)
banner.Size = UDim2.fromOffset(600, 90)
banner.Font = Enum.Font.FredokaOne
banner.TextScaled = true
banner.TextStrokeTransparency = 0
banner.TextTransparency = 1
banner.TextStrokeTransparency = 1
banner.ZIndex = 60
banner.Parent = gui
local bannerToken = 0
local function showBanner(text, color)
	bannerToken += 1
	local my = bannerToken
	banner.Text = text
	banner.TextColor3 = color
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0
	banner.Rotation = rng:NextNumber(-8, 8)
	punch(banner, 0.8)
	task.delay(1.1, function()
		if my == bannerToken then
			tween(banner, 0.3, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
end

-- Combo meter (right of the click button)
local comboLbl = Instance.new("TextLabel")
comboLbl.BackgroundTransparency = 1
comboLbl.AnchorPoint = Vector2.new(0, 0.5)
comboLbl.Position = UDim2.new(0.5, 100, 1, -155)
comboLbl.Size = UDim2.fromOffset(220, 60)
comboLbl.Font = Enum.Font.FredokaOne
comboLbl.TextScaled = true
comboLbl.TextXAlignment = Enum.TextXAlignment.Left
comboLbl.TextStrokeTransparency = 0
comboLbl.TextColor3 = Color3.fromRGB(255, 230, 80)
comboLbl.Text = ""
comboLbl.Parent = gui
local comboBar = Instance.new("Frame")
comboBar.BorderSizePixel = 0
comboBar.BackgroundColor3 = Color3.fromRGB(255, 230, 80)
comboBar.Position = UDim2.new(0.5, 100, 1, -122)
comboBar.Size = UDim2.fromOffset(0, 8)
comboBar.Parent = gui
corner(comboBar, 4)
local lastComboTime = 0
RunService.RenderStepped:Connect(function()
	local left = 1 - (os.clock() - lastComboTime) / Config.ComboWindow
	if left <= 0 then
		comboLbl.Text = ""
		comboBar.Size = UDim2.fromOffset(0, 8)
	else
		comboBar.Size = UDim2.fromOffset(200 * left, 8)
	end
end)
local MILESTONES = { [10] = "COMBO x10!", [25] = "SUPER COMBO!", [50] = "MEGA COMBO!!", [100] = "ULTRA COMBO!!!", [200] = "GODLIKE!!!!" }

-- Clicking: button, anywhere on screen, space bar; hold to spam
local holding = false
local function doClick()
	remotes.Click:FireServer()
	punch(clickBtn, 0.18)
	kick(0.08, 1.2)
end

clickBtn.MouseButton1Down:Connect(function()
	holding = true
	doClick()
end)
clickBtn.MouseButton1Up:Connect(function()
	holding = false
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.Space and not processed then
		doClick()
	elseif not processed and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		holding = true
		doClick()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		holding = false
	end
end)
task.spawn(function()
	while true do
		task.wait(0.07)
		if holding then
			doClick()
		end
	end
end)

upgradeBtn.Activated:Connect(function()
	remotes.Upgrade:FireServer()
	punch(upgradeBtn)
end)
rebirthBtn.Activated:Connect(function()
	remotes.Rebirth:FireServer()
	punch(rebirthBtn)
end)
shopBtn.Activated:Connect(function()
	shop.Visible = not shop.Visible
	punch(shopBtn)
end)

local function get(key)
	return player:GetAttribute(key) or 0
end

-- Toasts
local toastLbl = label(gui, "", UDim2.new(0.5, -200, 0, 60), UDim2.fromOffset(400, 40))
toastLbl.Visible = false
toastLbl.ZIndex = 70
local toastToken = 0
local function toast(text)
	toastToken += 1
	local my = toastToken
	toastLbl.Text = text
	toastLbl.Visible = true
	punch(toastLbl, 0.3)
	task.delay(2.5, function()
		if my == toastToken then
			toastLbl.Visible = false
		end
	end)
end

-- Offer pop-ups ("aggressive advertising")
local offer = Instance.new("Frame")
offer.AnchorPoint = Vector2.new(0.5, 0.5)
offer.Position = UDim2.fromScale(0.5, 0.5)
offer.Size = UDim2.fromOffset(380, 260)
offer.BackgroundColor3 = Color3.fromRGB(255, 80, 160)
offer.Visible = false
offer.ZIndex = 80
offer.Parent = gui
corner(offer, 20)
local offerStroke = Instance.new("UIStroke")
offerStroke.Thickness = 5
offerStroke.Color = Color3.fromRGB(255, 240, 120)
offerStroke.Parent = offer
local function offerText(y, h, size)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(15, y)
	l.Size = UDim2.new(1, -30, 0, h)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0
	l.ZIndex = 81
	l.Parent = offer
	return l
end
local offerTitle = offerText(12, 50)
local offerPitch = offerText(66, 40)
local offerTimer = offerText(110, 26)
offerTimer.TextColor3 = Color3.fromRGB(255, 240, 120)
local offerBuy = button(offer, "BUY NOW", Color3.fromRGB(60, 210, 90), UDim2.new(0.5, -150, 0, 148), UDim2.fromOffset(300, 60))
offerBuy.ZIndex = 81
local offerNo = Instance.new("TextButton")
offerNo.BackgroundTransparency = 1
offerNo.Position = UDim2.new(0.5, -100, 0, 214)
offerNo.Size = UDim2.fromOffset(200, 30)
offerNo.Font = Enum.Font.FredokaOne
offerNo.TextScaled = true
offerNo.TextColor3 = Color3.fromRGB(255, 220, 240)
offerNo.Text = "no thanks"
offerNo.ZIndex = 81
offerNo.Parent = offer
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
	offerTitle.Text = "🔥 " .. o.Title .. " 🔥"
	offerPitch.Text = o.Pitch
	offerBuy.Text = "BUY NOW  R$" .. item.Price
	offerEnds = os.clock() + 300
	offer.Visible = true
	punch(offer, 0.4)
	sound(SND_WHOOSH, 0.8, 1.2)
end
offerBuy.Activated:Connect(function()
	if currentOffer then
		remotes.Buy:FireServer(currentOffer.Kind, currentOffer.Key)
	end
	offer.Visible = false
end)
offerNo.Activated:Connect(function()
	offer.Visible = false
end)
RunService.RenderStepped:Connect(function()
	if offer.Visible then
		local left = math.max(0, offerEnds - os.clock())
		offerTimer.Text = string.format("⏰ OFFER ENDS IN %d:%02d", math.floor(left / 60), math.floor(left % 60))
		offerStroke.Color = Color3.fromHSV((os.clock() * 0.8) % 1, 0.6, 1)
	end
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

-- SALE tag on the shop button
local saleTag = Instance.new("TextLabel")
saleTag.BackgroundColor3 = Color3.fromRGB(255, 40, 60)
saleTag.Position = UDim2.new(1, -40, 0, -14)
saleTag.Size = UDim2.fromOffset(56, 26)
saleTag.Rotation = 12
saleTag.Font = Enum.Font.FredokaOne
saleTag.TextScaled = true
saleTag.TextColor3 = Color3.new(1, 1, 1)
saleTag.Text = "SALE!"
saleTag.Parent = shopBtn
corner(saleTag, 8)
task.spawn(function()
	while true do
		punch(shopBtn, 0.12)
		punch(saleTag, 0.4)
		task.wait(1.2)
	end
end)

-- Invite friends nudge
task.delay(120, function()
	local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
	if ok and can then
		pcall(SocialService.PromptGameInvite, SocialService, player)
	end
end)

-- Zone gates open locally once you have enough rebirths
local function refreshGates()
	local world = workspace:FindFirstChild("CandyWorld")
	if not world then
		return
	end
	for _, gate in ipairs(world:GetChildren()) do
		if gate.Name == "Gate" then
			local open = get("Rebirths") >= (gate:GetAttribute("Rebirths") or 0)
			gate.CanCollide = not open
			gate.Transparency = open and 0.85 or 0.2
		end
	end
end
player:GetAttributeChangedSignal("Rebirths"):Connect(refreshGates)
task.spawn(function()
	workspace:WaitForChild("CandyWorld")
	task.wait(2)
	refreshGates()
end)

-- Zone + Sugar Rush status (top-center)
local zoneLbl = label(gui, "", UDim2.new(0.5, -160, 0, 12), UDim2.fromOffset(320, 40))
zoneLbl.TextColor3 = Color3.fromRGB(255, 240, 120)
local rushLbl = label(gui, "", UDim2.new(0, 12, 0, 198), UDim2.fromOffset(220, 36))
rushLbl.Visible = false
local lastZone
RunService.Heartbeat:Connect(function()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		local zone = Config.ZoneAt(root.Position.Z)
		if zone ~= lastZone then
			lastZone = zone
			zoneLbl.Text = zone.Name .. "  x" .. zone.Mult
			punch(zoneLbl, 0.3)
		end
	end
	local rush = (player:GetAttribute("RushUntil") or 0) - workspace:GetServerTimeNow()
	rushLbl.Visible = rush > 0
	if rush > 0 then
		rushLbl.Text = string.format("🔥 3x RUSH %d:%02d", math.floor(rush / 60), math.floor(rush % 60))
	end
end)

local sellCount, brokeCount = 0, 0

-- Server effects
local function popPoint()
	local m = UserInputService:GetMouseLocation()
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		local p = clickBtn.AbsolutePosition + clickBtn.AbsoluteSize / 2
		return p.X, p.Y
	end
	return m.X, m.Y
end

remotes:WaitForChild("Fx").OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "Click" then
		local gain, crit, comboCount = a, b, c
		local x, y = popPoint()
		if crit then
			floater("CRIT +" .. Config.Format(gain) .. "!", Color3.fromRGB(255, 70, 70), x, y, 54)
			sound(SND_CLICK, 0.7, 0.7)
			kick(0.5, 5)
			showBanner("CRITICAL!", Color3.fromRGB(255, 70, 70))
		else
			floater("+" .. Config.Format(gain), Color3.fromHSV((os.clock() * 0.5) % 1, 0.6, 1), x, y, 34)
		end
		local e = getBurst()
		if e then
			e.Color = ColorSequence.new(Color3.fromHSV(rng:NextNumber(), 0.7, 1))
			e:Emit(crit and 40 or 8)
		end
		punch(powerLbl, 0.12)
		if comboCount and comboCount > 0 then
			lastComboTime = os.clock()
			sound(SND_TICK, 0.35, math.min(0.8 + comboCount * 0.015, 2.2))
			comboLbl.Text = "x" .. comboCount .. "  (" .. Config.ComboMult(comboCount) .. "x)"
			comboLbl.TextColor3 = Color3.fromHSV(math.max(0.15 - comboCount / 1000, 0), 0.8, 1)
			punch(comboLbl, 0.3)
			local m = MILESTONES[comboCount]
			if m then
				showBanner(m, Color3.fromRGB(255, 230, 80))
				confetti(40)
				kick(0.4, 6)
				sound(SND_WHOOSH, 0.8, 1.3)
			end
		end
	elseif kind == "Sell" then
		local cx = camera.ViewportSize.X / 2
		floater("+" .. Config.Format(a) .. " COINS", Color3.fromRGB(255, 215, 40), cx, camera.ViewportSize.Y * 0.45, 80)
		confetti(math.clamp(math.floor(math.log10(a + 1) * 15), 20, 100))
		sound(SND_WHOOSH, 0.8, 1)
		for i = 0, 5 do
			task.delay(i * 0.05, function()
				sound(SND_CLICK, 0.4, 1.2 + i * 0.15)
			end)
		end
		kick(0.6, 8)
		punch(coinsLbl, 0.4)
	elseif kind == "Upgrade" then
		showBanner("LEVEL " .. a .. "!", Color3.fromRGB(80, 255, 140))
		sound(SND_CLICK, 0.6, 1.6)
		confetti(25)
		kick(0.3, 4)
	elseif kind == "Rebirth" then
		showBanner("REBIRTH " .. a .. "!!!", Color3.fromRGB(230, 100, 255))
		confetti(150)
		sound(SND_WHOOSH, 1, 0.6)
		kick(1.2, 12)
		task.delay(1.5, function()
			for _, zone in ipairs(Config.Zones) do
				if zone.Rebirths == a then
					showBanner("🔓 " .. zone.Name .. " UNLOCKED!", Color3.fromRGB(255, 200, 60))
				end
			end
		end)
	elseif kind == "Toast" then
		toast(a)
	elseif kind == "Bought" then
		showBanner("THANK YOU! 💖", Color3.fromRGB(255, 120, 200))
		confetti(120)
		sound(SND_WHOOSH, 1, 1.4)
	elseif kind == "Broke" then
		toast("Need " .. Config.Format(b) .. " coins to " .. a .. "!")
		brokeCount += 1
		if brokeCount % 3 == 0 then
			showOffer({ Kind = "Product", Key = "CoinPack", Title = "SHORT ON COINS?", Pitch = "Grab a Bag of Coins and keep going!" })
		end
	end
	if kind == "Sell" then
		sellCount += 1
		if sellCount % 6 == 0 and not player:GetAttribute("Pass_VIP") then
			showOffer(Config.Offers[4])
		end
	end
end)

-- Stats with rolling counters
local shown = { Power = 0, Coins = 0 }
RunService.RenderStepped:Connect(function(dt)
	for key, lbl in pairs({ Power = powerLbl, Coins = coinsLbl }) do
		local target = get(key)
		local cur = shown[key]
		if cur ~= target then
			cur += (target - cur) * math.min(dt * 12, 1)
			if math.abs(target - cur) < 1 then
				cur = target
			end
			shown[key] = cur
			lbl.Text = (key == "Power" and "🍬 " or "💰 ") .. Config.Format(cur)
		end
	end
end)

local function render()
	local rebirths = get("Rebirths")
	powerLbl.Text = "🍬 " .. Config.Format(shown.Power)
	coinsLbl.Text = "💰 " .. Config.Format(shown.Coins)
	rebirthLbl.Text = "Rebirths: " .. rebirths .. " (x" .. Config.RebirthMult(rebirths) .. ")"
	upgradeBtn.Text = "Upgrade\n" .. Config.Format(Config.UpgradeCost(get("Level"))) .. " Coins"
	rebirthBtn.Text = "Rebirth\n" .. Config.Format(Config.RebirthCost(rebirths)) .. " Coins"
	local canUp = get("Coins") >= Config.UpgradeCost(get("Level"))
	upgradeBtn.BackgroundColor3 = canUp and Color3.fromRGB(60, 220, 90) or Color3.fromRGB(60, 110, 70)
end

for _, key in ipairs({ "Power", "Coins", "Level", "Rebirths" }) do
	player:GetAttributeChangedSignal(key):Connect(render)
end
render()

-- Pulse the upgrade button when affordable
task.spawn(function()
	while true do
		task.wait(0.6)
		if get("Coins") >= Config.UpgradeCost(get("Level")) then
			punch(upgradeBtn, 0.1)
		end
	end
end)

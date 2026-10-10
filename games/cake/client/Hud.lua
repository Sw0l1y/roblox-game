-- HUD: coins + level + next goal (top left), phase/theme pill with timer and the Celebrity Judge countdown
-- (top centre), left icon menu, right gift/boost column, FTUE tip pill. Mobile-first sizes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientLib = ReplicatedStorage:WaitForChild("ClientLib")
local Config = require(Shared:WaitForChild("Config"))
local Fmt = require(Shared:WaitForChild("Fmt"))
local Net = require(Shared:WaitForChild("Net"))
local UI = require(ClientLib:WaitForChild("UI"))
local Sfx = require(ClientLib:WaitForChild("Sfx"))
local Own = require(ClientLib:WaitForChild("Own"))

local Hud = {}

local I = Config.Icons
local ctx: Own.Ctx = nil :: any
local coins: UI.Counter
local levelBar: UI.Bar
local goalLabel: TextLabel
local goalCard: Frame
local pill: Frame
local themeLabel: TextLabel
local phaseLabel: TextLabel
local timerFill: Frame
local eventLabel: TextLabel
local eventCard: Frame
local tipCard: Frame
local tipLabel: TextLabel
local buttons: { [string]: UI.IconButton } = {}
local pulsing: { [GuiObject]: boolean } = {}
local lastBeep = -1
local data: { [string]: any }? = nil

Hud.coinTarget = nil :: GuiObject?

local function pulse(obj: GuiObject, on: boolean)
	if on == (pulsing[obj] == true) then
		return
	end
	pulsing[obj] = on or nil
	if on then
		task.spawn(function()
			while pulsing[obj] and obj.Parent do
				UI.punch(obj, 0.12)
				task.wait(0.9)
			end
		end)
	end
end
Hud.pulse = pulse

function Hud.button(name: string): GuiButton?
	local b = buttons[name]
	return if b then b.button else nil
end

function Hud.tip(text: string?)
	if text and text ~= "" then
		if not tipCard.Visible or tipLabel.Text ~= text then
			tipLabel.Text = text
			tipCard.Visible = true
			UI.punch(tipCard, 0.15)
		end
	else
		tipCard.Visible = false
	end
end

function Hud.init(c: Own.Ctx)
	ctx = c
	local root = UI.root

	-- currency + level + next goal (below the Roblox top bar buttons)
	coins = UI.counter(root, I.coin, "gold", Fmt.commas, { Name = "Coins", Position = UDim2.fromOffset(52, 64), Size = UDim2.fromOffset(240, 54) })
	Hud.coinTarget = coins.icon
	levelBar = UI.bar(root, "purple", { Name = "Level", Position = UDim2.fromOffset(24, 126), Size = UDim2.fromOffset(268, 32) })
	levelBar.set(0, "Lv 1 · Kitchen Helper")
	goalCard = UI.card(root, "teal", { Name = "Goal", Position = UDim2.fromOffset(24, 166), Size = UDim2.fromOffset(268, 40) })
	goalLabel = UI.text(goalCard, "", { Font = UI.BODY, Size = UDim2.new(1, -16, 0.76, 0), Position = UDim2.new(0, 8, 0.12, 0) })
	local goalBtn = Instance.new("TextButton")
	goalBtn.Name = "GoalButton"
	goalBtn.BackgroundTransparency = 1
	goalBtn.Text = ""
	goalBtn.Size = UDim2.fromScale(1, 1)
	goalBtn.Parent = goalCard
	goalBtn.MouseButton1Click:Connect(function()
		Sfx.play("click", 0.4)
		ctx.openShop("Toppings")
	end)

	-- phase pill
	pill = UI.card(root, "pink", { Name = "Phase", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(420, 84) })
	themeLabel = UI.text(pill, "🎂 CAKE OFF!", { Size = UDim2.new(1, -24, 0, 40), Position = UDim2.fromOffset(12, 6) })
	phaseLabel = UI.text(pill, "", { Font = UI.BODY, Size = UDim2.new(1, -24, 0, 26), Position = UDim2.fromOffset(12, 46), TextColor3 = Color3.fromRGB(255, 240, 248) })
	local track = UI.frame(pill, { Name = "Track", BackgroundColor3 = UI.INK, BackgroundTransparency = 0.4, Size = UDim2.new(1, -28, 0, 6), Position = UDim2.new(0, 14, 1, -12) })
	UI.corner(track, 3)
	timerFill = UI.frame(track, { Name = "Fill", BackgroundColor3 = Color3.fromRGB(255, 240, 160), Size = UDim2.fromScale(1, 1) })
	UI.corner(timerFill, 3)
	eventCard = UI.card(root, "purple", { Name = "Event", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 100), Size = UDim2.fromOffset(340, 36) })
	eventLabel = UI.text(eventCard, "", { Font = UI.BODY, Size = UDim2.new(1, -16, 0.78, 0), Position = UDim2.new(0, 8, 0.11, 0) })

	-- left icon menu
	local left = UI.frame(root, { Name = "LeftMenu", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.52, 0), Size = UDim2.fromOffset(90, 400) })
	UI.list(left, 14)
	local function leftBtn(name: string, glyph: string, label: string, color: string, order: number, fn: () -> ())
		local b = UI.iconButton(left, glyph, label, color, { Name = name, LayoutOrder = order, Size = UDim2.fromOffset(80, 80) })
		b.button.MouseButton1Click:Connect(fn)
		buttons[name] = b
	end
	leftBtn("Shop", I.shop, "Shop", "green", 1, function()
		ctx.openShop()
	end)
	leftBtn("Index", I.index, "Index", "blue", 2, function()
		ctx.openIndex()
	end)
	leftBtn("Daily", I.daily, "Daily", "orange", 3, function()
		ctx.openDaily()
	end)
	leftBtn("Music", I.music, "Music", "grey", 4, function()
		local m = not Sfx.isMuted()
		Sfx.setMuted(m)
		buttons.Music.icon.Text = if m then I.mute else I.music
		Net.func("Act"):InvokeServer("mute", m)
	end)

	-- right gift/boost column
	local right = UI.frame(root, { Name = "RightMenu", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.46, 0), Size = UDim2.fromOffset(90, 300) })
	UI.list(right, 14)
	local function rightBtn(name: string, glyph: string, label: string, color: string, order: number, fn: () -> ())
		local b = UI.iconButton(right, glyph, label, color, { Name = name, LayoutOrder = order, Size = UDim2.fromOffset(80, 80) })
		b.button.MouseButton1Click:Connect(fn)
		buttons[name] = b
	end
	rightBtn("Box", I.box, "Box", "pink", 1, function()
		ctx.openBox()
	end)
	rightBtn("Boost", I.boost, "2x Coins", "gold", 2, function()
		ctx.openShop("Robux")
	end)
	rightBtn("Theme", I.theme, "Theme", "teal", 3, function()
		ctx.openTheme()
	end)

	-- FTUE tip pill (above the build tray, off screen centre)
	tipCard = UI.card(root, "dark", { Name = "Tip", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -278), Size = UDim2.fromOffset(620, 50), Visible = false })
	tipLabel = UI.text(tipCard, "", { Font = UI.BODY, Size = UDim2.new(1, -20, 0.74, 0), Position = UDim2.new(0, 10, 0.13, 0), TextColor3 = Color3.fromRGB(255, 236, 150) })
end

function Hud.update(d: { [string]: any })
	data = d
	coins.set(d.coins or 0)
	local need = Config.xpFor(d.level or 1)
	levelBar.set((d.xp or 0) / need, string.format("Lv %d · %s", d.level or 1, Config.title(d.level or 1)))
	local goal, price = Own.nextGoal(d)
	if goal and price then
		goalCard.Visible = true
		local have = math.min(d.coins or 0, price)
		goalLabel.Text = string.format("🎯 %s  %s/%s", goal, Fmt.num(have), Fmt.num(price))
		goalLabel.TextColor3 = if (d.coins or 0) >= price then Color3.fromRGB(180, 255, 170) else Color3.fromRGB(255, 255, 255)
	else
		goalCard.Visible = false
	end
	local boxes = d.boxes or 0
	buttons.Box.setBadge(if boxes > 0 then boxes else nil)
	pulse(buttons.Box.button, boxes > 0 and (d.boxesOpened or 0) == 0 and (d.rounds or 0) >= 1)
	local canDaily = os.time() - (d.dailyLast or 0) >= Config.DailyCooldown
	buttons.Daily.setBadge(if canDaily then true else nil)
	buttons.Theme.setBadge(if (d.themeTickets or 0) > 0 then d.themeTickets else nil)
	buttons.Boost.button.Visible = not Own.pass(d, "DoubleCoins")
	buttons.Music.icon.Text = if Sfx.isMuted() then I.mute else I.music
end

local function phaseText(phase: string, left: number, state: Instance): string
	if phase == "Waiting" then
		return "Waiting for bakers..."
	elseif phase == "Lobby" then
		return "Next round in " .. Fmt.time(left)
	elseif phase == "Theme" then
		return "Get ready to bake!"
	elseif phase == "Build" then
		local ot = state:GetAttribute("Overtime")
		return "DECORATE! " .. Fmt.time(left) .. (if type(ot) == "string" and ot ~= "" then "  ⏰+30s" else "")
	elseif phase == "Vote" then
		return string.format("Judging cake %d/%d", tonumber(state:GetAttribute("ShowIndex")) or 0, tonumber(state:GetAttribute("ShowTotal")) or 0)
	elseif phase == "Results" then
		return "And the winner is..."
	end
	return ""
end

-- Called every frame by Main.
function Hud.tick(state: Instance, now: number)
	local phase = tostring(state:GetAttribute("Phase") or "Waiting")
	local ends = tonumber(state:GetAttribute("PhaseEnds")) or 0
	local left = math.max(0, ends - now)
	local themeKey = tostring(state:GetAttribute("Theme") or "")
	local theme = Config.ThemeByKey[themeKey]
	local celeb = state:GetAttribute("Celebrity") == true
	if theme and phase ~= "Lobby" and phase ~= "Waiting" then
		themeLabel.Text = theme.glyph .. " " .. string.upper(theme.name)
	else
		themeLabel.Text = "🎂 CAKE OFF!"
	end
	phaseLabel.Text = phaseText(phase, left, state)
	local total = if phase == "Build" then Config.Round.build elseif phase == "Lobby" then Config.Round.intermission else 0
	if total > 0 then
		timerFill.Size = UDim2.fromScale(math.clamp(left / total, 0, 1), 1)
		timerFill.Visible = true
	else
		timerFill.Visible = false
	end
	local urgent = phase == "Build" and left <= 10
	phaseLabel.TextColor3 = if urgent then Color3.fromRGB(255, 120, 120) else Color3.fromRGB(255, 240, 248)
	if urgent and left > 0 then
		local s = math.ceil(left)
		if s ~= lastBeep and s <= 5 then
			lastBeep = s
			Sfx.play("beep", 0.35, 1 + (5 - s) * 0.08)
			UI.punch(pill, 0.1)
		end
	end
	UI.recolor(pill, if celeb then "gold" else "pink")

	local eventAt = tonumber(state:GetAttribute("EventAt")) or 0
	local untilEvent = eventAt - now
	if celeb and phase ~= "Lobby" and phase ~= "Waiting" then
		eventLabel.Text = "🌟 CELEBRITY JUDGE ROUND · 2x REWARDS!"
		UI.recolor(eventCard, "gold")
	elseif eventAt > 0 then
		UI.recolor(eventCard, "purple")
		if untilEvent <= 0 then
			eventLabel.Text = "🌟 Celebrity Judge: NEXT ROUND!"
		else
			eventLabel.Text = "🌟 Celebrity Judge in " .. Fmt.time(untilEvent)
		end
	else
		eventLabel.Text = "🌟 Celebrity Judge soon"
	end
	local d = data
	if d and (d.luckUntil or 0) > os.time() then
		buttons.Box.label.Text = "🍀 " .. Fmt.time((d.luckUntil :: number) - os.time())
	else
		buttons.Box.label.Text = "Box"
	end
end

-- Coins flying from a screen point into the counter.
function Hud.flyCoins(from: Vector2, amount: number)
	local target = Hud.coinTarget
	if target then
		UI.fly(from, target, math.clamp(math.floor(amount / 15), 4, 14), I.coin)
	end
end

-- Briefly highlight a HUD element.
function Hud.flash(obj: GuiObject)
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(255, 240, 120)
	s.Thickness = 6
	s.Parent = obj
	TweenService:Create(s, TweenInfo.new(1.2), { Transparency = 1 }):Play()
	task.delay(1.3, function()
		s:Destroy()
	end)
end

return Hud

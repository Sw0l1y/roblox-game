-- HUD: coin counter (top centre) with the MEGA BALLOON pill / server HP bar under it, the left icon menu
-- (Upgrades, Shop, Index, Zones, Rebirth), the right gift/boost column (Daily gift, Mega Darts, Lucky Boost,
-- Summon, Music) and the goal bar at the bottom. Main wires the button handlers through Hud.onButton.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Fmt = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Fmt"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Econ = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Econ"))
local UI = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("UI"))
local Sfx = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("Sfx"))
local State = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("State"))

local Hud = {}

local I = Config.Icons
local camera = workspace.CurrentCamera
local _player = Players.LocalPlayer

Hud.buttons = {} :: { [string]: UI.IconButton }
Hud.onButton = {} :: { [string]: () -> () }
Hud.megaArmed = false
Hud.indexNew = 0

local coin: UI.Counter
local multLabel: TextLabel
local pill: Frame
local pillText: TextLabel
local hpHolder: Frame
local hpBar: UI.Bar
local hpTitle: TextLabel
local goalHolder: Frame
local goalText: TextLabel
local goalBar: UI.Bar
local megaLocalUsed = 0

type Pulse = { arrow: TextLabel, token: number }
local pulses: { [string]: Pulse } = {}
local pulseToken = 0

local function column(side: string): Frame
	local f = UI.frame(UI.root, {
		Name = side .. "Menu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(side == "Left" and 0 or 1, 0.5),
		Position = side == "Left" and UDim2.new(0, 14, 0.47, 0) or UDim2.new(1, -14, 0.44, 0),
		Size = UDim2.fromOffset(84, 500),
	})
	UI.list(f, 14)
	return f
end

local function addButton(parent: Instance, key: string, glyph: string, label: string, color: string, order: number)
	local b = UI.iconButton(parent, glyph, label, color, { Size = UDim2.fromOffset(78, 78), LayoutOrder = order })
	b.button.Name = key .. "Button"
	b.button.MouseButton1Click:Connect(function()
		local f = Hud.onButton[key]
		if f then
			f()
		end
	end)
	Hud.buttons[key] = b
end

-- Bouncing arrow next to a HUD button (FTUE / "you can afford this").
function Hud.pulse(key: string, on: boolean)
	local b = Hud.buttons[key]
	if not b then
		return
	end
	local cur = pulses[key]
	if on and cur then
		return
	end
	if not on then
		if cur then
			pulses[key] = nil
			cur.arrow:Destroy()
		end
		return
	end
	pulseToken += 1
	local left = b.button.Parent and b.button.Parent.Name == "LeftMenu"
	local arrow = UI.text(b.button, left and "👈" or "👉", {
		Name = "PulseArrow",
		Font = Enum.Font.GothamBold,
		AnchorPoint = Vector2.new(left and 0 or 1, 0.5),
		Position = left and UDim2.new(1, 10, 0.5, 0) or UDim2.new(0, -10, 0.5, 0),
		Size = UDim2.fromOffset(52, 52),
		ZIndex = b.button.ZIndex + 5,
	})
	local p: Pulse = { arrow = arrow, token = pulseToken }
	pulses[key] = p
	task.spawn(function()
		local t0 = os.clock()
		local lastPunch = 0
		while pulses[key] == p and arrow.Parent do
			local t = os.clock() - t0
			local dx = math.sin(t * 9) * 8
			arrow.Position = left and UDim2.new(1, 10 + dx, 0.5, 0) or UDim2.new(0, -10 - dx, 0.5, 0)
			if t - lastPunch > 0.9 then
				lastPunch = t
				UI.punch(b.button, 0.12)
			end
			RunService.RenderStepped:Wait()
		end
	end)
end

function Hud.isPulsing(key: string): boolean
	return pulses[key] ~= nil
end

function Hud.coinTarget(): GuiObject
	return coin.icon
end

function Hud.punchCoins()
	UI.punch(coin.frame, 0.12)
end

-- Event pill under the coins ("🎈 MEGA BALLOON in 2:31").
function Hud.setPill(text: string?, color: any?)
	if not text then
		pill.Visible = false
		return
	end
	pill.Visible = true
	pillText.Text = text
	if color then
		UI.recolor(pill, color)
	end
end

function Hud.pillPunch()
	UI.punch(pill, 0.18)
end

-- Server-wide MEGA BALLOON HP bar. MegaView calls this every frame: only re-tween when the numbers change.
local shownHp, shownMax = -1, -1
function Hud.setMegaHp(visible: boolean, hp: number?, maxHp: number?, title: string?)
	hpHolder.Visible = visible
	if visible and hp and maxHp and (hp ~= shownHp or maxHp ~= shownMax) then
		shownHp, shownMax = hp, maxHp
		hpBar.set(hp / math.max(1, maxHp), "❤️ " .. Fmt.commas(math.max(0, math.ceil(hp))) .. " / " .. Fmt.commas(maxHp))
	end
	if title then
		hpTitle.Text = title
	end
end

function Hud.megaHit()
	UI.punch(hpHolder, 0.05)
end

-- Goal bar at the bottom: text plus an optional progress fraction.
function Hud.setGoal(text: string?, frac: number?, label: string?)
	if not text then
		goalHolder.Visible = false
		return
	end
	goalHolder.Visible = true
	if goalText.Text ~= text then
		goalText.Text = text
		UI.punch(goalHolder, 0.06)
	end
	if frac then
		goalBar.frame.Visible = true
		goalBar.set(frac, label or "")
	else
		goalBar.frame.Visible = false
	end
end

function Hud.markIndexNew()
	Hud.indexNew += 1
	Hud.buttons.Index.setBadge(Hud.indexNew)
end

function Hud.clearIndexNew()
	Hud.indexNew = 0
	Hud.buttons.Index.setBadge(nil)
end

-- A mega dart was just thrown (the data push that confirms it can lag a moment).
function Hud.usedMegaDart()
	megaLocalUsed += 1
	Hud.update()
end

function Hud.megaDarts(): number
	local d = State.data
	return math.max(0, (d and d.megaDarts or 0) - megaLocalUsed)
end

function Hud.toggleMega()
	if Hud.megaDarts() <= 0 then
		Hud.megaArmed = false
		UI.toast(I.megaDart .. " No Mega Darts! Get some in the Shop or from the daily gift.", "orange")
		Sfx.play("error", 0.4)
		local f = Hud.onButton.MegaShop
		if f then
			f()
		end
	else
		Hud.megaArmed = not Hud.megaArmed
		Sfx.play(Hud.megaArmed and "magic" or "click", 0.4)
		if Hud.megaArmed then
			UI.toast(I.megaDart .. " Mega Darts ON: each dart pops everything around the target!", "red", 2.5)
		end
	end
	Hud.update()
end

local lastCoins: number? = nil

function Hud.update()
	local d = State.data
	if not d then
		return
	end
	coin.set(d.coins or 0)
	if lastCoins and (d.coins or 0) < lastCoins then
		UI.punch(coin.frame, -0.06)
	end
	lastCoins = d.coins or 0
	local mult = Econ.coinMult(d)
	multLabel.Text = mult > 1.001 and string.format("x%.2f coins", mult) or ""

	-- mega darts
	local md = Hud.megaDarts()
	local mb = Hud.buttons.Mega
	mb.setBadge(md > 0 and md or nil)
	if md <= 0 then
		Hud.megaArmed = false
	end
	mb.label.Text = Hud.megaArmed and "ON!" or "Mega Dart"
	UI.recolor(mb.button, Hud.megaArmed and "orange" or "red")

	-- badges: anything affordable?
	local coins = d.coins or 0
	local canUp = false
	for _, key in ipairs(Config.UpgradeOrder) do
		local lvl = Econ.level(d, key)
		if lvl < Config.Upgrades[key].max and coins >= Econ.upgradeCost(key, lvl) then
			canUp = true
		end
	end
	Hud.buttons.Upgrades.setBadge(canUp and true or nil)
	local z = (d.zones or 1) + 1
	Hud.buttons.Zones.setBadge((Config.Zones[z] and coins >= Config.Zones[z].cost) and true or nil)
	Hud.buttons.Rebirth.setBadge(coins >= Econ.rebirthCost(d.rebirths or 0) and true or nil)
end

-- Once a second: timers on the right column.
local function tick()
	local d = State.data
	if not d then
		return
	end
	local now = math.floor(workspace:GetServerTimeNow()) -- the server's clock; a phone's own clock can be off
	local last = d.daily and tonumber(d.daily.last) or 0
	local left = Config.Daily.cooldown - (now - (last or 0))
	local db = Hud.buttons.Daily
	if left <= 0 then
		db.label.Text = "Claim!"
		db.setBadge(true)
	else
		db.label.Text = Fmt.time(left)
		db.setBadge(nil)
	end
	local bb = Hud.buttons.Boost
	local luckLeft = (tonumber(d.luckUntil) or 0) - now
	if luckLeft > 0 then
		bb.label.Text = Fmt.time(luckLeft)
		UI.recolor(bb.button, "teal")
	else
		bb.label.Text = "Luck x2"
		UI.recolor(bb.button, "green")
	end
end

function Hud.init()
	-- coins
	coin = UI.counter(UI.root, I.coin, "gold", function(n: number): string
		return Fmt.commas(math.floor(n))
	end, {
		Name = "Coins",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(270, 58),
	})
	multLabel = UI.text(coin.frame, "", {
		Font = UI.BODY,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 1, 2),
		Size = UDim2.fromOffset(110, 22),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = UI.colors.yellow,
		ZIndex = coin.frame.ZIndex + 3,
	})

	-- MEGA BALLOON pill / HP bar
	pill = UI.card(UI.root, "pink", {
		Name = "EventPill",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 76),
		Size = UDim2.fromOffset(360, 40),
		Visible = false,
	})
	pillText = UI.text(pill, "", { Size = UDim2.new(1, -20, 0.8, 0), Position = UDim2.new(0, 10, 0.1, 0) })
	hpHolder = UI.frame(UI.root, {
		Name = "MegaHp",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 72),
		Size = UDim2.fromOffset(560, 64),
		Visible = false,
	})
	hpTitle = UI.text(hpHolder, "🎈 MEGA BALLOON", { Size = UDim2.new(1, 0, 0, 26), TextColor3 = UI.colors.pink })
	hpBar = UI.bar(hpHolder, "pink", { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 28) })
	local plain = hpBar.fill:FindFirstChildOfClass("UIGradient")
	if plain then
		plain:Destroy()
	end
	UI.rainbow(hpBar.fill)

	-- move the kit's toasts below our top stack
	local toasts = UI.gui:FindFirstChild("Toasts")
	local function placeToasts()
		if toasts and toasts:IsA("GuiObject") then
			toasts.Position = UDim2.new(0.5, 0, 0, math.floor(146 * UI.scale()))
		end
	end
	placeToasts()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(placeToasts)

	-- left menu
	local left = column("Left")
	addButton(left, "Upgrades", I.upgrades, "Upgrades", "blue", 1)
	addButton(left, "Shop", I.shop, "Shop", "pink", 2)
	addButton(left, "Index", I.index, "Index", "purple", 3)
	addButton(left, "Zones", I.zones, "Zones", "teal", 4)
	addButton(left, "Rebirth", I.rebirth, "Rebirth", "orange", 5)

	-- right column
	local right = column("Right")
	addButton(right, "Daily", I.daily, "Gift", "green", 1)
	addButton(right, "Mega", I.megaDart, "Mega Dart", "red", 2)
	addButton(right, "Boost", I.luck, "Luck x2", "green", 3)
	addButton(right, "Summon", I.mega, "MEGA!", "pink", 4)
	addButton(right, "Mute", I.music, "Music", "grey", 5)

	-- goal bar
	goalHolder = UI.card(UI.root, "dark", {
		Name = "Goal",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(480, 70),
		Visible = false,
	})
	goalText = UI.text(goalHolder, "", { Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 6) })
	goalBar = UI.bar(goalHolder, "green", { Size = UDim2.new(1, -24, 0, 24), Position = UDim2.fromOffset(12, 40) })

	State.onChange(function()
		megaLocalUsed = 0
		Hud.update()
	end)
	task.spawn(function()
		while true do
			pcall(tick)
			task.wait(1)
		end
	end)
end

return Hud

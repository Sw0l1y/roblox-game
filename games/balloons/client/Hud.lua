-- HUD: coin counter (top centre) with the MEGA BALLOON pill / server HP bar and the zone's "popped %" boss
-- meter under it, the left icon grid (Shop, Upgrades, Index, Zones, FREE, Rebirth), the right gift/boost grid
-- (Mega Darts, Daily gift, Lucky Boost, Summon, Music, the Starter Pack timer) and the goal bar at the bottom.
-- Main wires the button handlers through Hud.onButton.
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
local meterHolder: Frame
local meterBar: UI.Bar
local meterZone = 0
local meterFull = false
local goalHolder: Frame
local goalText: TextLabel
local goalBar: UI.Bar
local megaLocalUsed = 0
local player = Players.LocalPlayer

Hud.zone = 0 -- the zone the player stands in (Main's zone loop), 0 on a bridge

type Pulse = { arrow: TextLabel, token: number }
local pulses: { [string]: Pulse } = {}
local pulseToken = 0

-- Side menus: a 2-column grid of buttons on each side at mid height. On desktop Roblox's chat window covers the
-- top-left ~40% of the screen and the player list the top-right, so the grids start below them. Phones show
-- neither by default, so there the grids sit a little higher to stay clear of the jump button (bottom-right).
local BTN = 78
local GAP_X, GAP_Y = 22, 16

local function menu(side: string): Frame
	local left = side == "Left"
	return UI.frame(UI.root, {
		Name = side .. "Menu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(left and 0 or 1, 0.5),
		Position = UDim2.new(left and 0 or 1, left and 14 or -14, UI.isMobile and 0.53 or 0.6, 0),
		Size = UDim2.fromOffset(BTN * 2 + GAP_X, BTN * 3 + GAP_Y * 2),
	})
end

-- col 0 or 1 (0.5 = centred under both columns), row 0..2.
local function addButton(parent: Instance, key: string, glyph: string, label: string, color: string, col: number, row: number)
	local b = UI.iconButton(parent, glyph, label, color, {
		Size = UDim2.fromOffset(BTN, BTN),
		Position = UDim2.fromOffset(col * (BTN + GAP_X), row * (BTN + GAP_Y)),
	})
	b.button.Name = key .. "Button"
	b.button.MouseButton1Click:Connect(function()
		local f = Hud.onButton[key]
		if f then
			f()
		end
	end)
	Hud.buttons[key] = b
end

-- Bouncing arrow next to a HUD button (FTUE / "you can afford this"), on the side facing the screen centre. The
-- buttons the guide pulses (Upgrades, Zones, Rebirth) sit in the left grid's inner column or alone in their row,
-- so the arrow never lands on a neighbouring button.
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
	if visible then
		meterHolder.Visible = false -- the boss meter sits where the HP bar goes
	end
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

-- The zone's "popped %" meter: fills with the zone's own pops; full = tap to summon the zone boss.
local function drawMeter(d: { [string]: any })
	local z = Hud.zone
	local zd = Config.Zones[z]
	local show = zd ~= nil and z <= (d.zones or 1) and (d.pops or 0) >= Config.Ftue.meterAfterPops and not hpHolder.Visible
	meterHolder.Visible = show
	if not show or not zd then
		return
	end
	local frac = Econ.meterFrac(d, z)
	local full = frac >= 1
	if z ~= meterZone or full ~= meterFull then
		meterZone = z
		meterFull = full
		UI.recolor(meterBar.fill, full and "red" or zd.accent)
		if full then
			UI.punch(meterHolder, 0.2)
		end
	end
	local name = string.upper(zd.name)
	if full then
		meterBar.set(1, I.boss .. " " .. (UI.isMobile and "TAP" or "CLICK") .. ": FIGHT THE " .. name .. " BOSS!")
	else
		local done = Econ.bossBeaten(d, z) > 0 and (" " .. I.check) or ""
		meterBar.set(frac, zd.glyph .. " " .. name .. " " .. math.floor(frac * 100) .. "% POPPED" .. done)
	end
end

function Hud.meterIsFull(): boolean
	return meterHolder.Visible and meterFull
end

function Hud.setZone(z: number)
	if z ~= Hud.zone then
		Hud.zone = z
		Hud.update()
	end
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
	local friends = tonumber(player:GetAttribute("Friends")) or 0
	local mult = Econ.incomeMult(d, 1 + (Config.Live.friendBonus or 0) * friends)
	multLabel.Text = mult > 1.001 and string.format("x%.2f coins", mult) or ""
	drawMeter(d)

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
	local isBlocked = player:GetAttribute("RandomBlocked") ~= false
	local icon = bb.icon
	if icon:IsA("TextLabel") then
		-- paid luck is not sold under the paid random item restriction: the slot sells server coin boosts then
		icon.Text = isBlocked and "⚡" or I.luck
	end
	if luckLeft > 0 then
		bb.label.Text = Fmt.time(luckLeft)
		UI.recolor(bb.button, "teal")
	elseif isBlocked then
		bb.label.Text = "2x Coins"
		UI.recolor(bb.button, "gold")
	else
		bb.label.Text = "Luck x2"
		UI.recolor(bb.button, "green")
	end
	-- Starter Pack: only in the first 10 minutes, shown from minute 2 with its countdown
	local starterLeft = Econ.starterLeft(d)
	local sb = Hud.buttons.Starter
	local showStarter = starterLeft > 0 and Hud.offersOpen
	sb.button.Visible = showStarter
	Hud.buttons.Mute.button.Position = UDim2.fromOffset((showStarter and 0 or 0.5) * (BTN + GAP_X), 2 * (BTN + GAP_Y))
	if showStarter then
		sb.label.Text = Fmt.time(math.floor(starterLeft))
	end
	drawMeter(d)
end

-- Main turns this on after minute 2 of the session (no offers in the first two minutes).
Hud.offersOpen = false

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
	-- coin multiplier ("x1.10 coins") beside the counter, not under it: the event pill / HP bar and the toasts
	-- stack right below the counter and used to cover it
	multLabel = UI.text(coin.frame, "", {
		Name = "Mult",
		Font = UI.BODY,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, 10, 0.5, 0),
		Size = UDim2.fromOffset(124, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
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

	-- zone boss meter (same slot as the HP bar, which hides it during the MEGA fight)
	meterHolder = UI.frame(UI.root, {
		Name = "ZoneMeter",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 122),
		Size = UDim2.fromOffset(400, 34),
		Visible = false,
	})
	meterBar = UI.bar(meterHolder, "pink", { Size = UDim2.fromScale(1, 1) })
	local meterButton = Instance.new("TextButton")
	meterButton.Name = "MeterButton"
	meterButton.BackgroundTransparency = 1
	meterButton.Text = ""
	meterButton.AutoButtonColor = false
	meterButton.Size = UDim2.fromScale(1, 1)
	meterButton.ZIndex = meterBar.frame.ZIndex + 4
	meterButton.Parent = meterHolder
	meterButton.MouseButton1Click:Connect(function()
		local f = Hud.onButton.Meter
		if f then
			f()
		end
	end)

	UI.setToastTop(164) -- toasts go below our top stack (coins, event pill, HP bar / boss meter)

	-- left grid: the inner (right-hand) column holds the buttons the guide points at
	local left = menu("Left")
	addButton(left, "Shop", I.shop, "Shop", "pink", 0, 0)
	addButton(left, "Upgrades", I.upgrades, "Upgrades", "blue", 1, 0)
	addButton(left, "Index", I.index, "Index", "purple", 0, 1)
	addButton(left, "Zones", I.zones, "Zones", "teal", 1, 1)
	addButton(left, "Free", I.free, "FREE", "green", 0, 2)
	addButton(left, "Rebirth", I.rebirth, "Rebirth", "orange", 1, 2)

	-- right grid
	local right = menu("Right")
	addButton(right, "Mega", I.megaDart, "Mega Dart", "red", 0, 0) -- inner column: the guide may pulse it
	addButton(right, "Daily", I.calendar, "Daily", "green", 1, 0)
	addButton(right, "Boost", I.luck, "Luck x2", "green", 0, 1)
	addButton(right, "Summon", I.mega, "MEGA!", "pink", 1, 1)
	addButton(right, "Mute", I.music, "Music", "grey", 0.5, 2)
	addButton(right, "Starter", "🎉", "Starter", "teal", 1, 2)
	Hud.buttons.Starter.button.Visible = false

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
	player:GetAttributeChangedSignal("Friends"):Connect(Hud.update)
	task.spawn(function()
		while true do
			pcall(tick)
			task.wait(1)
		end
	end)
end

return Hud

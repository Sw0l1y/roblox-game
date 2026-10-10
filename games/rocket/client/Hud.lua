-- HUD and menus: coin/strength counters, the rocket progress bar, supply-drop and boost pills, left menu
-- (Shop, Gear, Index, Crew, Skins, Mute), right gift/boost column (Daily, Fuel the Server, Robot Crew, VIP,
-- Party Popper), a mini crew board, the carry panel (strength vs weight, NEED A HAND, DROP) and every panel:
-- tabbed Shop, Gear upgrades, the parts x rarity Index with odds, Daily streak + Fuel Run quest, Crew stats,
-- and notices (landing summary, offline drones). Also turns every server event into juice.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local Fmt = require(Shared:WaitForChild("Fmt"))
local Net = require(Shared:WaitForChild("Net"))
local ClientLib = ReplicatedStorage:WaitForChild("ClientLib")
local UI = require(ClientLib:WaitForChild("UI"))
local Sfx = require(ClientLib:WaitForChild("Sfx"))
local State = require(ClientLib:WaitForChild("State"))
local Hub = require(ClientLib:WaitForChild("Hub"))

local Hud = {}

local T = Config.Tune
local I = Config.Icons
local player = Hub.player
local buyRemote = Net.event("Buy")
local upgradeRemote = Net.event("Upgrade")
local skinRemote = Net.event("Skin")
local dailyRemote = Net.event("Daily")
local popperRemote = Net.event("Popper")
local helpRemote = Net.event("Help")
local dropRemote = Net.event("Drop")

Hud.buttons = {} :: { [string]: UI.IconButton }

-- Helpers ------------------------------------------------------------------------------------------------------

local function data(): { [string]: any }?
	return State.data
end

local function owns(key: string): boolean
	local d = State.data
	if not d then
		return false
	end
	local passes: any = d.passes
	if type(passes) ~= "table" then
		return false
	end
	return (passes :: any)[key] == true
end

-- `once` products (Starter Pack) the server already sold to this player.
local function boughtOnce(d: { [string]: any }, key: string): boolean
	local b: any = d.bought
	if type(b) ~= "table" then
		return false
	end
	return (b :: any)[key] == true
end

local function buy(kind: string, key: string)
	local d = State.data
	local item = (if kind == "pass" then Config.Passes else Config.Products :: any)[key]
	if d and item and ((kind == "pass" and owns(key)) or (kind ~= "pass" and item.once == true and (boughtOnce(d, key) or (key == "StarterPack" and d.starter == true)))) then
		Sfx.play("error", 0.5)
		return
	end
	buyRemote:FireServer(kind, key)
end

-- Plain body text (Fredoka, ink, no outline) for light panels.
local function body(parent: Instance, str: string, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = UI.BODY
	l.TextScaled = true
	l.TextWrapped = true
	l.TextColor3 = UI.INK
	l.Text = str
	l.Size = UDim2.fromOffset(200, 30)
	UI.set(l, props)
	l.Parent = parent
	return l
end

local function strengthNow(): number
	local v = player:GetAttribute("Strength")
	if type(v) == "number" then
		return v
	end
	local d = State.data
	return d and tonumber(d.strengthShown) or T.baseStrength
end

local function bestMult(d: { [string]: any }): number
	return Config.planet(tonumber(d.bestPlanet) or 1).coins * Config.missionMult(tonumber(d.bestMission) or 1)
end

local function tierColor(key: string): Color3
	return Tiers.get(key).color
end

-- Top: counters, progress, pills -------------------------------------------------------------------------------

local top = UI.frame(UI.root, {
	Name = "Top",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(470, 56),
})
UI.list(top, 14, true)
local coinCounter = UI.counter(top, I.coin, "gold", Fmt.num, { Size = UDim2.fromOffset(220, 52), LayoutOrder = 1 })
local strCounter = UI.counter(top, I.strength, "orange", Fmt.num, { Size = UDim2.fromOffset(220, 52), LayoutOrder = 2 })
Hud.coinCounter = coinCounter
Hud.strCounter = strCounter

local progress = UI.bar(UI.root, "orange", {
	Name = "RocketProgress",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 70),
	Size = UDim2.fromOffset(440, 34),
})
Hud.progress = progress

local function pill(name: string, color: string, anchorX: number, x: number): (Frame, TextLabel)
	local f = UI.card(UI.root, color, {
		Name = name,
		AnchorPoint = Vector2.new(anchorX, 0),
		Position = UDim2.new(0.5, x, 0, 70),
		Size = UDim2.fromOffset(206, 34),
		Visible = false,
	})
	local l = UI.text(f, "", { Size = UDim2.new(1, -14, 0.8, 0), Position = UDim2.new(0, 7, 0.1, 0) })
	return f, l
end
local dropPill, dropText = pill("DropPill", "gold", 1, -232)
local boostPill, boostText = pill("BoostPill", "orange", 0, 232)

-- Hint line (bottom centre) -----------------------------------------------------------------------------------

local hint = UI.text(UI.root, "", {
	Name = "Hint",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.fromOffset(760, 38),
	TextColor3 = Color3.fromRGB(255, 240, 160),
	Visible = false,
})
local hintText = ""
function Hud.setHint(text: string?)
	local t = text or ""
	if t == hintText then
		return
	end
	hintText = t
	hint.Text = t
	hint.Visible = t ~= ""
	if t ~= "" then
		UI.punch(hint, 0.12)
	end
end

-- Left menu ---------------------------------------------------------------------------------------------------

local left = UI.frame(UI.root, {
	Name = "LeftMenu",
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 16, 0, 130),
	Size = UDim2.fromOffset(170, 260),
})
local leftGrid = UI.grid(left, UDim2.fromOffset(76, 76), 10)
leftGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left

local function menuButton(parent: Instance, key: string, glyph: string, label: string, color: string, order: number, size: number?): UI.IconButton
	local b = UI.iconButton(parent, glyph, label, color, { Size = UDim2.fromOffset(size or 76, size or 76), LayoutOrder = order, Name = key .. "Button" })
	Hud.buttons[key] = b
	return b
end

local shopBtn = menuButton(left, "Shop", I.shop, "SHOP", "green", 1)
local gearBtn = menuButton(left, "Gear", I.gear, "GEAR", "blue", 2)
local indexBtn = menuButton(left, "Index", I.index, "INDEX", "purple", 3)
local crewBtn = menuButton(left, "Crew", I.crew, "CREW", "gold", 4)
local skinsBtn = menuButton(left, "Skins", I.skins, "SKINS", "pink", 5)
local muteBtn = menuButton(left, "Mute", I.music, "MUSIC", "grey", 6)

-- Right column -------------------------------------------------------------------------------------------------

local board = UI.card(UI.root, "dark", {
	Name = "MiniBoard",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 120),
	Size = UDim2.fromOffset(236, 140),
})
UI.text(board, I.crew .. " CREW BOARD", { Size = UDim2.new(1, -16, 0, 24), Position = UDim2.fromOffset(8, 4), TextColor3 = UI.colors.gold })
local boardRows: { TextLabel } = {}
for i = 1, 5 do
	boardRows[i] = UI.text(board, "", {
		Font = UI.BODY,
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.fromOffset(8, 8 + i * 21),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local right = UI.frame(UI.root, {
	Name = "RightColumn",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 274),
	Size = UDim2.fromOffset(76, 420),
})
local rightList = UI.list(right, 9)
rightList.VerticalAlignment = Enum.VerticalAlignment.Top
rightList.HorizontalAlignment = Enum.HorizontalAlignment.Right

local dailyBtn = menuButton(right, "Daily", I.daily, "DAILY", "pink", 1, 70)
local fuelBtn = menuButton(right, "Fuel", I.fuel, "FUEL!", "orange", 2, 70)
local robotBtn = menuButton(right, "Robots", I.robot, "ROBOTS", "teal", 3, 70)
local vipBtn = menuButton(right, "VIP", I.vip, "VIP", "gold", 4, 70)
local popperBtn = menuButton(right, "Popper", I.popper, "POP!", "pink", 5, 70)
popperBtn.button.Visible = false

-- Carry panel ---------------------------------------------------------------------------------------------------

local carryFrame = UI.card(UI.root, "dark", {
	Name = "CarryPanel",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.fromOffset(570, 118),
	Visible = false,
})
local carryTitle = UI.text(carryFrame, "", {
	Size = UDim2.fromOffset(340, 34),
	Position = UDim2.fromOffset(14, 6),
	TextXAlignment = Enum.TextXAlignment.Left,
})
local carryTitleGrad = Instance.new("UIGradient")
carryTitleGrad.Rotation = 90
carryTitleGrad.Parent = carryTitle
local carryBar = UI.bar(carryFrame, "green", { Position = UDim2.fromOffset(14, 44), Size = UDim2.fromOffset(340, 30) })
local carryInfo = UI.text(carryFrame, "", {
	Font = UI.BODY,
	Size = UDim2.fromOffset(340, 28),
	Position = UDim2.fromOffset(14, 80),
	TextXAlignment = Enum.TextXAlignment.Left,
})
local helpBtn = UI.button(carryFrame, I.help .. " NEED A HAND!", "orange", { Position = UDim2.fromOffset(366, 8), Size = UDim2.fromOffset(192, 52) })
local dropBtn = UI.button(carryFrame, I.drop .. " DROP", "red", { Position = UDim2.fromOffset(366, 64), Size = UDim2.fromOffset(192, 46) })
Hud.carryFrame = carryFrame
Hud.helpButton = helpBtn

helpBtn.MouseButton1Click:Connect(function()
	helpRemote:FireServer()
	Sfx.play("notify", 0.5)
	UI.toast(I.help .. " Help ping sent! Crew bots and players are on the way.", "orange", 2.5)
end)
dropBtn.MouseButton1Click:Connect(function()
	dropRemote:FireServer()
end)

-- Panels: shared builders -------------------------------------------------------------------------------------

type Card = { frame: Frame, button: TextButton, sub: TextLabel, title: TextLabel }

local function shopCard(parent: Instance, glyph: string, title: string, desc: string, color: any, order: number, onBuy: () -> ()): Card
	local f = UI.card(parent, color, { LayoutOrder = order })
	UI.text(f, glyph, {
		Font = Enum.Font.GothamBold,
		Size = UDim2.new(0, 56, 0, 56),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
	})
	local t = UI.text(f, title, { Size = UDim2.new(1, -12, 0, 26), Position = UDim2.new(0, 6, 0, 60) })
	local sub = UI.text(f, desc, {
		Font = UI.BODY,
		TextWrapped = true,
		Size = UDim2.new(1, -14, 0, 34),
		Position = UDim2.new(0, 7, 0, 86),
		TextColor3 = Color3.fromRGB(240, 244, 255),
	})
	local b = UI.button(f, "BUY", "green", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -20, 0, 40),
	})
	b.MouseButton1Click:Connect(onBuy)
	return { frame = f, button = b, sub = sub, title = t }
end

local function setBuy(c: Card, ownedText: string?, priceText: string)
	if ownedText then
		c.button.Text = ownedText
		UI.recolor(c.button, "grey")
		c.button.Active = false
	else
		c.button.Text = priceText
		UI.recolor(c.button, "green")
		c.button.Active = true
	end
end

-- Shop ---------------------------------------------------------------------------------------------------------

local shop = UI.panel("Shop", I.shop .. " SHOP", "green", Vector2.new(820, 548))
local shopPages, shopSelect = UI.tabs(shop.body, { "Strength", "Passes", "Skins", "Coins" }, { "orange", "purple", "pink", "gold" })
Hud.shopSelect = shopSelect

local ladderCards: { [string]: Card } = {}
do
	local page = shopPages.Strength
	body(page, "Strength comes from hauling parts and Gear. A pass multiplies it forever (your best one counts)!", {
		Size = UDim2.new(1, 0, 0, 30),
	})
	local sc = UI.scroll(page, { Size = UDim2.new(1, 0, 1, -34), Position = UDim2.fromOffset(0, 34) })
	UI.grid(sc, UDim2.fromOffset(142, 168), 10)
	for i, key in ipairs(Config.Ladder) do
		local pass = (Config.Passes :: any)[key]
		local color = Tiers.list[math.clamp(math.ceil(i / 1.5), 1, #Tiers.list)].color
		ladderCards[key] = shopCard(sc, pass.icon, string.format("%dx", pass.mult), "STRENGTH", color, i, function()
			buy("pass", key)
		end)
	end
end

type ShopItem = { kind: string, key: string }
local passItems: { ShopItem } = {
	{ kind = "product", key = "FuelServer" },
	{ kind = "pass", key = "RobotCrew" },
	{ kind = "pass", key = "VIP" },
	{ kind = "pass", key = "MegaJetpack" },
	{ kind = "pass", key = "Coins2x" },
	{ kind = "product", key = "SupplyDrop" },
	{ kind = "product", key = "StarterPack" },
	{ kind = "product", key = "Boost15" },
	{ kind = "pass", key = "PartyPopper" },
	{ kind = "pass", key = "RainbowTrail" },
}
local passCards: { [string]: Card } = {}
do
	local sc = UI.scroll(shopPages.Passes)
	UI.grid(sc, UDim2.fromOffset(236, 176), 10)
	local colors = { "orange", "teal", "gold", "red", "yellow", "purple", "pink", "blue", "pink", "sky" }
	for i, it in ipairs(passItems) do
		local item = (if it.kind == "pass" then Config.Passes else Config.Products :: any)[it.key]
		passCards[it.key] = shopCard(sc, item.icon, string.upper(item.name), item.desc, colors[i] or "blue", i, function()
			buy(it.kind, it.key)
		end)
	end
end

local skinCards: { [string]: Card } = {}
do
	local sc = UI.scroll(shopPages.Skins)
	UI.grid(sc, UDim2.fromOffset(236, 176), 10)
	for i, sk in ipairs(Config.Skins) do
		local c = shopCard(sc, sk.icon, string.upper(sk.name), "", sk.accent, i, function()
			local d = data()
			if not d then
				return
			end
			local unlocked = sk.unlock == "free"
				or (sk.unlock == "launches" and (tonumber(d.launches) or 0) >= (sk.need or 0))
				or (sk.unlock == "planet" and (tonumber(d.bestPlanet) or 1) >= (sk.need or 99))
				or (sk.unlock == "pass" and sk.pass ~= nil and owns(sk.pass))
			if unlocked then
				skinRemote:FireServer(sk.key)
			elseif sk.unlock == "pass" and sk.pass then
				buy("pass", sk.pass)
			else
				Sfx.play("error", 0.5)
			end
		end)
		-- colour swatches
		local sw = UI.frame(c.frame, { BackgroundTransparency = 1, Size = UDim2.fromOffset(96, 22), Position = UDim2.new(0, 8, 0, 8) })
		UI.list(sw, 4, true, Enum.HorizontalAlignment.Left)
		for _, col in ipairs({ sk.body, sk.accent, sk.trim }) do
			local dot = UI.frame(sw, { Size = UDim2.fromOffset(20, 20), BackgroundColor3 = col })
			UI.corner(dot, 10)
			UI.stroke(dot, 2)
		end
		skinCards[sk.key] = c
	end
end

local coinCards: { [string]: Card } = {}
do
	local page = shopPages.Coins
	body(page, "Coin packs grow with your best planet. Spend coins on Gear to get stronger!", { Size = UDim2.new(1, 0, 0, 30) })
	local holder = UI.frame(page, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -40), Position = UDim2.fromOffset(0, 40) })
	UI.grid(holder, UDim2.fromOffset(178, 230), 12)
	for i, key in ipairs({ "CoinsS", "CoinsM", "CoinsL", "CoinsXL" }) do
		local item = (Config.Products :: any)[key]
		coinCards[key] = shopCard(holder, item.icon, string.upper(item.name), "", "gold", i, function()
			buy("product", key)
		end)
	end
end

local function refreshShop()
	local d = data()
	if not d then
		return
	end
	local best = 0
	for i, key in ipairs(Config.Ladder) do
		if owns(key) then
			best = i
		end
	end
	for i, key in ipairs(Config.Ladder) do
		local c = ladderCards[key]
		local pass = (Config.Passes :: any)[key]
		setBuy(c, if owns(key) then (if i == best then "ACTIVE ✅" else "OWNED") else nil, "R$ " .. pass.price)
		c.sub.Text = if i == best + 1 then "⭐ NEXT STEP" else "STRENGTH"
	end
	for _, it in ipairs(passItems) do
		local c = passCards[it.key]
		local item = (if it.kind == "pass" then Config.Passes else Config.Products :: any)[it.key]
		local bought = if it.kind == "pass" then owns(it.key) else (item.once == true and (d.starter == true and it.key == "StarterPack" or boughtOnce(d, it.key)))
		setBuy(c, if bought then "OWNED ✅" else nil, "R$ " .. item.price)
	end
	for _, sk in ipairs(Config.Skins) do
		local c = skinCards[sk.key]
		local equipped = d.skin == sk.key
		local unlocked = sk.unlock == "free"
			or (sk.unlock == "launches" and (tonumber(d.launches) or 0) >= (sk.need or 0))
			or (sk.unlock == "planet" and (tonumber(d.bestPlanet) or 1) >= (sk.need or 99))
			or (sk.unlock == "pass" and sk.pass ~= nil and owns(sk.pass))
		if sk.unlock == "launches" then
			c.sub.Text = string.format("Launch %d rockets (%d/%d)", sk.need or 0, math.min(tonumber(d.launches) or 0, sk.need or 0), sk.need or 0)
		elseif sk.unlock == "planet" then
			c.sub.Text = "Reach " .. Config.planet(sk.need or 4).name
		elseif sk.unlock == "pass" then
			c.sub.Text = "Top hauler's skin paints the rocket!"
		else
			c.sub.Text = "The classic white and orange."
		end
		if equipped then
			setBuy(c, "EQUIPPED ✅", "")
		elseif unlocked then
			c.button.Text = "EQUIP"
			UI.recolor(c.button, "blue")
			c.button.Active = true
		elseif sk.unlock == "pass" and sk.pass then
			local pass = (Config.Passes :: any)[sk.pass]
			setBuy(c, nil, "R$ " .. pass.price)
		else
			c.button.Text = I.lock .. " LOCKED"
			UI.recolor(c.button, "grey")
			c.button.Active = true
		end
	end
	local mult = bestMult(d)
	for key, c in pairs(coinCards) do
		local item = (Config.Products :: any)[key]
		c.sub.Text = I.coin .. " " .. Fmt.commas(item.coins * mult)
		setBuy(c, nil, "R$ " .. item.price)
	end
end
shop.onOpen = refreshShop

-- Gear ----------------------------------------------------------------------------------------------------------

local gear = UI.panel("Gear", I.gear .. " GEAR", "blue", Vector2.new(700, 520))
local gearTop = body(gear.body, "", { Size = UDim2.new(1, 0, 0, 30) })
type GearRow = { level: TextLabel, effect: TextLabel, button: TextButton, bar: UI.Bar }
local gearRows: { [string]: GearRow } = {}
do
	local holder = UI.frame(gear.body, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -38), Position = UDim2.fromOffset(0, 38) })
	local l = UI.list(holder, 10)
	l.VerticalAlignment = Enum.VerticalAlignment.Top
	local colors = { "sky", "purple", "orange", "teal" }
	for i, key in ipairs(Config.GearOrder) do
		local g = Config.Gear[key]
		local row = UI.card(holder, colors[i], { Size = UDim2.new(1, -8, 0, 96), LayoutOrder = i })
		UI.text(row, g.icon, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(70, 70), Position = UDim2.fromOffset(10, 13) })
		UI.text(row, string.upper(g.name), { Size = UDim2.fromOffset(250, 30), Position = UDim2.fromOffset(88, 8), TextXAlignment = Enum.TextXAlignment.Left })
		local level = UI.text(row, "", { Size = UDim2.fromOffset(90, 26), Position = UDim2.fromOffset(344, 10), TextColor3 = UI.colors.yellow })
		local effect = UI.text(row, "", {
			Font = UI.BODY,
			Size = UDim2.fromOffset(340, 24),
			Position = UDim2.fromOffset(88, 40),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local bar = UI.bar(row, "yellow", { Size = UDim2.fromOffset(340, 16), Position = UDim2.fromOffset(88, 70) })
		local b = UI.button(row, "", "green", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(196, 60) })
		b.MouseButton1Click:Connect(function()
			upgradeRemote:FireServer(key)
		end)
		gearRows[key] = { level = level, effect = effect, button = b, bar = bar }
	end
end

local function canAffordGear(d: { [string]: any }): boolean
	for _, key in ipairs(Config.GearOrder) do
		local cost = Config.gearCost(key, tonumber(d.gear[key]) or 1)
		if cost and (tonumber(d.coins) or 0) >= cost then
			return true
		end
	end
	return false
end

local function refreshGear()
	local d = data()
	if not d then
		return
	end
	gearTop.Text = string.format("%s Strength now: %s  ·  Gear multiplies everything you haul!", I.strength, Fmt.num(strengthNow()))
	for _, key in ipairs(Config.GearOrder) do
		local g = Config.Gear[key]
		local row = gearRows[key]
		local lv = math.clamp(tonumber(d.gear[key]) or 1, 1, #g.cost)
		row.level.Text = string.format("LV %d/%d", lv, #g.cost)
		row.bar.set(lv / #g.cost)
		local nextLv = lv + 1
		local maxed = g.cost[nextLv] == nil
		if key == "drones" then
			local rates = g.rate or {}
			local now = rates[lv] or 0
			row.effect.Text = if maxed then string.format("%s %s coins/min (max)", I.drone, Fmt.num(now)) else string.format("%s %s → %s coins/min (also offline)", I.drone, Fmt.num(now), Fmt.num(rates[nextLv] or now))
		else
			local extra = ""
			local jumps = g.jump
			if jumps and not maxed then
				extra = string.format("  ·  jump +%d", jumps[nextLv] or 0)
			end
			row.effect.Text = if maxed then string.format("%s x%s strength (max)", I.strength, tostring(g.mult[lv])) else string.format("%s x%s → x%s strength%s", I.strength, tostring(g.mult[lv]), tostring(g.mult[nextLv]), extra)
		end
		if maxed then
			row.button.Text = "MAXED " .. I.check
			UI.recolor(row.button, "grey")
		else
			local cost = g.cost[nextLv]
			row.button.Text = I.coin .. " " .. Fmt.num(cost)
			UI.recolor(row.button, if (tonumber(d.coins) or 0) >= cost then "green" else "grey")
		end
	end
end
gear.onOpen = refreshGear

-- Index -----------------------------------------------------------------------------------------------------------

local index = UI.panel("Index", I.index .. " INDEX", "purple", Vector2.new(840, 548))
local indexPages = UI.tabs(index.body, { "Parts", "Planets", "Ranks" }, { "purple", "sky", "gold" })
local indexCells: { [string]: { frame: Frame, label: TextLabel } } = {}
local indexFooter: TextLabel
do
	local page = indexPages.Parts
	local KW, CW, RH = 150, 82, 38
	for ti, r in ipairs(Config.Rarity) do
		local t = Tiers.get(r.key)
		local x = KW + (ti - 1) * CW
		local name = UI.text(page, string.upper(t.name), { Size = UDim2.fromOffset(CW - 4, 22), Position = UDim2.fromOffset(x, 0), TextColor3 = t.color })
		if t.rainbow then
			UI.rainbow(name)
		end
		body(page, Tiers.odds(Config.Rarity, r), { Size = UDim2.fromOffset(CW - 4, 18), Position = UDim2.fromOffset(x, 22) })
	end
	for ki, kind in ipairs(Config.KindOrder) do
		local k = Config.Kinds[kind]
		local y = 44 + (ki - 1) * RH
		UI.text(page, k.icon .. " " .. string.upper(k.name), {
			Size = UDim2.fromOffset(KW - 8, RH - 10),
			Position = UDim2.fromOffset(0, y + 5),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		for ti, r in ipairs(Config.Rarity) do
			local cell = UI.frame(page, {
				Size = UDim2.fromOffset(CW - 6, RH - 6),
				Position = UDim2.fromOffset(KW + (ti - 1) * CW, y + 3),
				BackgroundColor3 = Color3.fromRGB(196, 202, 216),
			})
			UI.corner(cell, 10)
			UI.stroke(cell, 2.5)
			local lab = UI.text(cell, "?", { Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.05, 0.1) })
			indexCells[kind .. ":" .. r.key] = { frame = cell, label = lab }
		end
	end
	indexFooter = body(page, "", { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 44 + #Config.KindOrder * RH + 4) })
end

local planetCards: { { frame: Frame, status: TextLabel } } = {}
do
	local page = indexPages.Planets
	local holder = UI.frame(page, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	UI.grid(holder, UDim2.fromOffset(186, 300), 10)
	for i, pl in ipairs(Config.Planets) do
		local c = UI.card(holder, pl.accent, { LayoutOrder = i })
		UI.text(c, pl.icon, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(80, 80), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6) })
		UI.text(c, pl.name, { Size = UDim2.new(1, -12, 0, 30), Position = UDim2.fromOffset(6, 88) })
		UI.text(c, pl.blurb, { Font = UI.BODY, TextWrapped = true, Size = UDim2.new(1, -16, 0, 50), Position = UDim2.fromOffset(8, 122) })
		UI.text(c, string.format("🌀 Gravity %d%%", math.floor(pl.gravity / 196.2 * 100 + 0.5)), { Font = UI.BODY, Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 178) })
		UI.text(c, string.format("%s x%s coins  %s x%s weight", I.coin, tostring(pl.coins), I.weight, tostring(pl.weight)), { Font = UI.BODY, Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 204) })
		local status = UI.text(c, "", { Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 240), TextColor3 = UI.colors.yellow })
		planetCards[i] = { frame = c, status = status }
	end
end

local rankRows: { Frame } = {}
do
	local page = indexPages.Ranks
	body(page, string.format("Haul weight to rank up. Every rank adds +%d%% strength and a new tag over your head!", math.floor(T.rankBonus * 100)), { Size = UDim2.new(1, 0, 0, 28) })
	local holder = UI.frame(page, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -34), Position = UDim2.fromOffset(0, 34) })
	local l = UI.list(holder, 6)
	l.VerticalAlignment = Enum.VerticalAlignment.Top
	for i, r in ipairs(Config.Ranks) do
		local row = UI.card(holder, Tiers.get(r.tier).color, { Size = UDim2.new(1, -20, 0, 40), LayoutOrder = i })
		local name = UI.text(row, r.icon .. " " .. string.upper(r.name), { Size = UDim2.fromOffset(300, 30), Position = UDim2.fromOffset(12, 5), TextXAlignment = Enum.TextXAlignment.Left })
		if Tiers.get(r.tier).rainbow then
			UI.rainbow(name)
		end
		UI.text(row, I.weight .. " " .. Fmt.commas(r.need) .. " hauled", { Font = UI.BODY, Size = UDim2.fromOffset(300, 26), Position = UDim2.new(1, -312, 0, 7), TextXAlignment = Enum.TextXAlignment.Right })
		rankRows[i] = row
	end
end

local function refreshIndex()
	local d = data()
	if not d then
		return
	end
	local found = 0
	for key, cell in pairs(indexCells) do
		local n = tonumber(d.index[key])
		local tier = string.match(key, ":(%w+)$") or "Common"
		if n and n > 0 then
			found += 1
			cell.frame.BackgroundColor3 = tierColor(tier)
			cell.label.Text = "x" .. Fmt.num(n)
		else
			cell.frame.BackgroundColor3 = Color3.fromRGB(150, 156, 172)
			cell.label.Text = "?"
		end
	end
	local total = #Config.KindOrder * #Config.Rarity
	indexFooter.Text = string.format("%s %d/%d found  ·  +%d%% strength (1%% per entry)  ·  odds per depot part", I.index, found, total, found)
	for i, c in ipairs(planetCards) do
		local pl = Config.Planets[i]
		local visited = i == 1 or d.planets[pl.key] == true
		c.status.Text = if Hub.planet() == i then "📍 YOU ARE HERE" elseif visited then I.check .. " VISITED" else I.lock .. " LAUNCH TO REACH"
	end
	local rankIdx = Config.rank(tonumber(d.hauled) or 0)
	for i, row in ipairs(rankRows) do
		row.BackgroundTransparency = if i <= rankIdx then 0 else 0.45
		local st = row:FindFirstChildOfClass("UIStroke")
		if st then
			st.Thickness = if i == rankIdx then 5 else 3.5
			st.Color = if i == rankIdx then UI.colors.yellow else UI.INK
		end
	end
end
index.onOpen = function()
	indexBtn.setBadge(nil)
	refreshIndex()
end

-- Daily --------------------------------------------------------------------------------------------------------

local daily = UI.panel("Daily", I.daily .. " DAILY", "pink", Vector2.new(720, 500))
local dayCards: { Frame } = {}
local dayChecks: { TextLabel } = {}
local claimBtn: TextButton
local questBar: UI.Bar
local questText: TextLabel
do
	local b = daily.body
	body(b, "Log in every day for bigger gifts! Day 3 and Day 7 add a 15 min 3x Strength boost.", { Size = UDim2.new(1, 0, 0, 28) })
	local row = UI.frame(b, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 130), Position = UDim2.fromOffset(0, 34) })
	UI.list(row, 8, true)
	for i, r in ipairs(Config.Daily) do
		local c = UI.card(row, if r.boost then "orange" else "sky", { Size = UDim2.fromOffset(88, 124), LayoutOrder = i })
		UI.text(c, "DAY " .. i, { Size = UDim2.new(1, -8, 0, 24), Position = UDim2.fromOffset(4, 4) })
		UI.text(c, if r.boost then I.boost else I.coin, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(44, 44), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 30) })
		UI.text(c, Fmt.num(r.coins), { Size = UDim2.new(1, -8, 0, 24), Position = UDim2.fromOffset(4, 76), TextColor3 = UI.colors.yellow })
		dayChecks[i] = UI.text(c, "", { Size = UDim2.new(1, -8, 0, 20), Position = UDim2.fromOffset(4, 100) })
		dayCards[i] = c
	end
	claimBtn = UI.button(b, "CLAIM!", "green", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 174), Size = UDim2.fromOffset(300, 60) })
	claimBtn.MouseButton1Click:Connect(function()
		dailyRemote:FireServer()
	end)
	local quest = UI.card(b, "orange", { Size = UDim2.new(1, -10, 0, 150), Position = UDim2.fromOffset(5, 248) })
	UI.text(quest, I.quest .. " DAILY FUEL RUN", { Size = UDim2.new(1, -20, 0, 32), Position = UDim2.fromOffset(10, 8) })
	questText = UI.text(quest, "", { Font = UI.BODY, Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, 44) })
	questBar = UI.bar(quest, "green", { Size = UDim2.new(1, -40, 0, 34), Position = UDim2.fromOffset(20, 84) })
end

local function dailyReady(d: { [string]: any }): (boolean, number, number)
	local last = tonumber(d.daily.last) or 0
	local wait = 20 * 3600 - (os.time() - last)
	local streak = tonumber(d.daily.streak) or 0
	if wait <= 0 then
		local day = if last == 0 or os.time() - last > 48 * 3600 then 1 else streak % #Config.Daily + 1
		return true, day, 0
	end
	return false, streak, wait
end

local function refreshDaily()
	local d = data()
	if not d then
		return
	end
	local ready, day, wait = dailyReady(d)
	for i, c in ipairs(dayCards) do
		local st = c:FindFirstChildOfClass("UIStroke")
		local isToday = i == day
		if st then
			st.Color = if isToday then UI.colors.yellow else UI.INK
			st.Thickness = if isToday then 6 else 3.5
		end
		if ready then
			dayChecks[i].Text = if i < day then I.check else (if isToday then "TODAY!" else "")
		else
			dayChecks[i].Text = if i <= day then I.check else ""
		end
	end
	if ready then
		claimBtn.Text = string.format("CLAIM DAY %d!", day)
		UI.recolor(claimBtn, "green")
	else
		claimBtn.Text = "NEXT IN " .. Fmt.time(wait)
		UI.recolor(claimBtn, "grey")
	end
	local q = d.quest
	local count = math.min(tonumber(q.count) or 0, T.questTarget)
	if q.date ~= Config.dateKey(os.time()) then
		count = 0
	end
	if q.claimed and q.date == Config.dateKey(os.time()) then
		questText.Text = I.check .. " Done for today! Come back tomorrow."
		questBar.set(1, "COMPLETE!")
	else
		questText.Text = string.format("Bolt on %d parts today → %s 1,200 x planet + %s 15 min 3x Strength", T.questTarget, I.coin, I.boost)
		questBar.set(count / T.questTarget, string.format("%d / %d", count, T.questTarget))
	end
end
daily.onOpen = refreshDaily

-- Crew -----------------------------------------------------------------------------------------------------------

local crew = UI.panel("Crew", I.crew .. " CREW", "gold", Vector2.new(640, 520))
local crewRows: { TextLabel } = {}
local statLabels: { [string]: TextLabel } = {}
local rankBar: UI.Bar
local rankText: TextLabel
do
	local b = crew.body
	local boardCard = UI.card(b, "dark", { Size = UDim2.new(1, -10, 0, 184), Position = UDim2.fromOffset(5, 0) })
	UI.text(boardCard, "THIS ROCKET'S TOP HAULERS", { Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, 6), TextColor3 = UI.colors.gold })
	for i = 1, 5 do
		crewRows[i] = UI.text(boardCard, "", {
			Font = UI.BODY,
			Size = UDim2.new(1, -24, 0, 26),
			Position = UDim2.fromOffset(12, 6 + i * 29),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
	rankText = UI.text(b, "", { Size = UDim2.new(1, -10, 0, 30), Position = UDim2.fromOffset(5, 192), TextColor3 = UI.colors.purple })
	rankBar = UI.bar(b, "purple", { Size = UDim2.new(1, -40, 0, 30), Position = UDim2.fromOffset(20, 226) })
	local grid = UI.frame(b, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 160), Position = UDim2.fromOffset(0, 266) })
	UI.grid(grid, UDim2.fromOffset(190, 64), 8)
	local stats = {
		{ "hauled", I.weight, "HAULED" },
		{ "delivered", I.rocket, "PARTS BOLTED" },
		{ "launches", I.launch, "LAUNCHES" },
		{ "mvps", "🥇", "MVP RIDES" },
		{ "crates", I.star, "STAR CRATES" },
		{ "bestPlanet", I.planet, "FARTHEST" },
	}
	for i, s in ipairs(stats) do
		local c = UI.card(grid, "sky", { LayoutOrder = i })
		UI.text(c, s[2] .. " " .. s[3], { Size = UDim2.new(1, -10, 0, 24), Position = UDim2.fromOffset(5, 4) })
		statLabels[s[1]] = UI.text(c, "0", { Size = UDim2.new(1, -10, 0, 28), Position = UDim2.fromOffset(5, 30), TextColor3 = UI.colors.yellow })
	end
end

type BoardEntry = { uid: number, name: string, weight: number }
local function boardEntries(): { BoardEntry }
	local out: { BoardEntry } = {}
	local raw = Hub.str("Board", "")
	for chunk in string.gmatch(raw, "[^;]+") do
		local uid, name, w = string.match(chunk, "^(%d+)|([^|]*)|(%d+)$")
		if uid and name and w then
			table.insert(out, { uid = tonumber(uid) or 0, name = name, weight = tonumber(w) or 0 })
		end
	end
	return out
end

local MEDALS = { "🥇", "🥈", "🥉", "4.", "5." }

local function refreshBoard()
	local list = boardEntries()
	for i, row in ipairs(boardRows) do
		local e = list[i]
		if e then
			row.Text = string.format("%s %s  %s%s", MEDALS[i], e.name, I.weight, Fmt.num(e.weight))
			row.TextColor3 = if e.uid == player.UserId then UI.colors.yellow else Color3.new(1, 1, 1)
		else
			row.Text = if i == 1 then "Haul a part to get on!" else ""
		end
	end
	if crew.isOpen() then
		for i, row in ipairs(crewRows) do
			local e = list[i]
			if e then
				row.Text = string.format("%s %s  %s %s%s", MEDALS[i], e.name, I.weight, Fmt.commas(e.weight), if i == 1 then "  (MVP seat on the nose!)" else "")
				row.TextColor3 = if e.uid == player.UserId then UI.colors.yellow else Color3.new(1, 1, 1)
			else
				row.Text = if i == 1 then "Nobody yet. Haul a part to the pad!" else ""
			end
		end
	end
end

local function refreshCrew()
	local d = data()
	if not d then
		return
	end
	refreshBoard()
	local hauled = tonumber(d.hauled) or 0
	local idx, rank = Config.rank(hauled)
	local nextRank = Config.Ranks[idx + 1]
	if nextRank then
		rankText.Text = string.format("%s %s  →  %s %s", rank.icon, string.upper(rank.name), nextRank.icon, string.upper(nextRank.name))
		local frac = (hauled - rank.need) / math.max(1, nextRank.need - rank.need)
		rankBar.set(frac, string.format("%s / %s", Fmt.num(hauled), Fmt.num(nextRank.need)))
	else
		rankText.Text = string.format("%s %s  (MAX RANK)", rank.icon, string.upper(rank.name))
		rankBar.set(1, Fmt.num(hauled))
	end
	for key, l in pairs(statLabels) do
		if key == "bestPlanet" then
			local pl = Config.planet(tonumber(d.bestPlanet) or 1)
			l.Text = pl.icon .. " " .. pl.name
		else
			l.Text = Fmt.num(tonumber(d[key]) or 0)
		end
	end
end
crew.onOpen = refreshCrew

-- Notice (landing summary, offline drones, quest) ----------------------------------------------------------------

local notice = UI.panel("Notice", "", "sky", Vector2.new(540, 420))
local noticeGlyph = UI.text(notice.body, "", {
	Font = Enum.Font.GothamBold,
	Size = UDim2.fromOffset(110, 110),
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 4),
})
local noticeText = UI.text(notice.body, "", {
	Font = UI.BODY,
	TextWrapped = true,
	Size = UDim2.new(1, -10, 0, 150),
	Position = UDim2.fromOffset(5, 118),
	TextColor3 = UI.INK,
})
local noticeStroke = noticeText:FindFirstChildOfClass("UIStroke")
if noticeStroke then
	noticeStroke.Enabled = false
end
local noticeOk = UI.button(notice.body, "AWESOME!", "green", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -4),
	Size = UDim2.fromOffset(260, 62),
})
local noticeCb: (() -> ())? = nil
noticeOk.MouseButton1Click:Connect(function()
	notice.close()
	local cb = noticeCb
	noticeCb = nil
	if cb then
		cb()
	end
end)

local function showNotice(title: string, glyph: string, text: string, cb: (() -> ())?)
	notice.title.Text = title
	noticeGlyph.Text = glyph
	noticeText.Text = text
	noticeCb = cb
	notice.open()
	UI.punch(noticeGlyph, 0.6)
end
Hud.showNotice = showNotice

-- Menu wiring -------------------------------------------------------------------------------------------------

shopBtn.button.MouseButton1Click:Connect(function()
	UI.toggle("Shop")
end)
gearBtn.button.MouseButton1Click:Connect(function()
	UI.toggle("Gear")
end)
indexBtn.button.MouseButton1Click:Connect(function()
	UI.toggle("Index")
end)
crewBtn.button.MouseButton1Click:Connect(function()
	UI.toggle("Crew")
end)
skinsBtn.button.MouseButton1Click:Connect(function()
	shop.open()
	shopSelect("Skins")
end)
muteBtn.button.MouseButton1Click:Connect(function()
	local m = not Sfx.isMuted()
	Sfx.setMuted(m)
	local icon = muteBtn.icon :: any
	icon.Text = if m then I.mute else I.music
	muteBtn.label.Text = if m then "MUTED" else "MUSIC"
end)
dailyBtn.button.MouseButton1Click:Connect(function()
	UI.toggle("Daily")
end)
fuelBtn.button.MouseButton1Click:Connect(function()
	buy("product", "FuelServer")
end)
robotBtn.button.MouseButton1Click:Connect(function()
	buy("pass", "RobotCrew")
end)
vipBtn.button.MouseButton1Click:Connect(function()
	buy("pass", "VIP")
end)
popperBtn.button.MouseButton1Click:Connect(function()
	popperRemote:FireServer()
end)

-- Kiosk prompts in the world open panels.
ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if who ~= player then
		return
	end
	local name = prompt:GetAttribute("OpenPanel")
	if type(name) == "string" then
		local p = UI.getPanel(name)
		if p then
			p.open()
		end
	end
end)

-- Live refresh -----------------------------------------------------------------------------------------------------

local function coinPos(): Vector2
	local f = coinCounter.frame
	return f.AbsolutePosition + f.AbsoluteSize / 2
end

local function refreshOpen()
	if shop.isOpen() then
		refreshShop()
	end
	if gear.isOpen() then
		refreshGear()
	end
	if index.isOpen() then
		refreshIndex()
	end
	if daily.isOpen() then
		refreshDaily()
	end
	if crew.isOpen() then
		refreshCrew()
	end
end

local function refreshButtons()
	local d = data()
	if not d then
		return
	end
	robotBtn.button.Visible = not owns("RobotCrew")
	vipBtn.button.Visible = not owns("VIP")
	popperBtn.button.Visible = owns("PartyPopper") or player:GetAttribute("Popper") == true
	local ready = dailyReady(d)
	dailyBtn.setBadge(ready)
	gearBtn.setBadge(canAffordGear(d))
end

local carryBarText = ""
local carryBarColor = ""
local progressText = ""

local function refreshCarry()
	local c = Hub.carry
	if not c or Hub.cinematic then
		if carryFrame.Visible then
			carryFrame.Visible = false
			hint.Position = UDim2.new(0.5, 0, 1, -24)
			carryBarText = ""
		end
		return
	end
	carryFrame.Visible = true
	hint.Position = UDim2.new(0.5, 0, 1, -142)
	local t = Tiers.get(c.tier)
	local k = Config.Kinds[c.kind]
	local name = if c.kind == "crate" then I.star .. " STAR CRATE" else (k and (k.icon .. " " .. (if Tiers.index[c.tier] and Tiers.index[c.tier] > 1 then string.upper(t.name) .. " " else "") .. string.upper(k.name)) or c.kind)
	if carryTitle.Text ~= name then
		carryTitle.Text = name
		carryTitleGrad.Color = if Tiers.index[c.tier] and Tiers.index[c.tier] > 1 then Tiers.gradient(c.tier) else ColorSequence.new(Color3.new(1, 1, 1))
	end
	local ratio = c.str / math.max(1, c.weight)
	local barText = string.format("%s %s / %s %s", I.strength, Fmt.num(c.str), I.weight, Fmt.num(c.weight))
	if barText ~= carryBarText then
		carryBarText = barText
		carryBar.set(math.min(1, ratio), barText)
	end
	local barColor = if c.speed <= 0 then "red" elseif ratio < 1 then "yellow" else "green"
	if barColor ~= carryBarColor then
		carryBarColor = barColor
		UI.recolor(carryBar.fill, barColor)
	end
	local lifters = string.format("%s %d/%d%s", I.people, c.holders + c.bots, c.cap, if c.bots > 0 then string.format(" (%s%d)", I.robot, c.bots) else "")
	if c.speed <= 0 then
		local need = math.max(0, math.ceil(c.weight * T.minRatio - c.str))
		carryInfo.Text = string.format("TOO HEAVY! Need %s%s more  ·  %s", I.strength, Fmt.num(need), lifters)
		carryInfo.TextColor3 = Color3.fromRGB(255, 140, 120)
		helpBtn.Rotation = math.sin(os.clock() * 10) * 4
	else
		carryInfo.Text = string.format("%s Speed %d  ·  %s", I.speed, math.floor(c.speed + 0.5), lifters)
		carryInfo.TextColor3 = Color3.new(1, 1, 1)
		helpBtn.Rotation = 0
	end
end

local function refreshTop()
	local phase = Hub.phase()
	local pl = Hub.planetInfo()
	local filled = Hub.num("Filled", 0)
	local total = math.max(1, Hub.num("Total", 1))
	local pText = if phase == "build" then string.format("%s %s ROCKET %d/%d", pl.icon, pl.name, filled, total) else I.launch .. " LAUNCHING!"
	if pText ~= progressText then
		progressText = pText
		progress.set(if phase == "build" then filled / total else 1, pText)
		UI.punch(progress.frame, 0.08)
	end
	local now = Hub.now()
	local dropAt = Hub.num("DropAt", 0)
	if phase == "build" and dropAt > now then
		dropPill.Visible = true
		dropText.Text = string.format("%s DROP %s", I.box, Fmt.time(dropAt - now))
	else
		dropPill.Visible = false
	end
	local boostUntil = Hub.num("BoostUntil", 0)
	local d = data()
	local personal = d and (tonumber(d.boostUntil) or 0) - os.time() or 0
	if boostUntil > now then
		boostPill.Visible = true
		boostText.Text = string.format("%s 2X SERVER %s", I.fuel, Fmt.time(boostUntil - now))
	elseif personal > 0 then
		boostPill.Visible = true
		boostText.Text = string.format("%s 3X STRENGTH %s", I.boost, Fmt.time(personal))
	else
		boostPill.Visible = false
	end
	strCounter.set(math.floor(strengthNow() * 10 + 0.5) / 10)
end

-- Server events -> juice ---------------------------------------------------------------------------------------------

local function fromWorld(pos: any): Vector2
	if typeof(pos) == "Vector3" then
		local sp = UI.screenPos(pos)
		if sp then
			return sp
		end
	end
	return UI.center()
end

local function onAnnounce(p: any)
	if type(p) ~= "table" or type(p.text) ~= "string" then
		return
	end
	UI.banner(p.text, p.color or "white", 2.8)
	Sfx.play(if type(p.sound) == "string" then p.sound else "notify", 0.6, 1, 4)
end

local function onReward(p: any)
	if type(p) ~= "table" then
		return
	end
	local coins = tonumber(p.coins) or 0
	local gain = tonumber(p.strength) or 0
	local from = fromWorld(p.pos)
	if coins > 0 then
		UI.fly(from, coinCounter.frame, math.clamp(math.floor(coins / 20) + 4, 4, 14), I.coin)
		UI.floater("+" .. Fmt.num(coins) .. " " .. I.coin, "gold", from, 46)
		Sfx.play("cash", 0.45)
	end
	if gain > 0 then
		task.delay(0.25, function()
			local sf = strCounter.frame
			UI.floater(string.format("+%s %s", Fmt.num(math.floor(gain * 10 + 0.5) / 10), I.strength), "orange", sf.AbsolutePosition + Vector2.new(sf.AbsoluteSize.X / 2, 70), 34)
		end)
	end
	if p.star then
		UI.banner(I.star .. " STAR CRATE! x" .. T.crateCoinMult .. " COINS!", "gold", 2)
		UI.confetti(50, { Config.Palette.gold, Config.Palette.white, Config.Palette.orange })
	end
	if p.new and type(p.kind) == "string" and type(p.tier) == "string" then
		local k = Config.Kinds[p.kind]
		local kname = if k then k.name else tostring(p.kind)
		UI.toast(string.format("%s NEW INDEX ENTRY: %s %s! (+1%% %s)", I.index, string.upper(Tiers.get(tostring(p.tier)).name), kname, I.strength), "purple", 3.5)
		indexBtn.setBadge(true)
		Sfx.play("unlock", 0.5)
	end
end

function Hud.init()
	State.onChange(function(d)
		coinCounter.set(tonumber(d.coins) or 0)
		refreshButtons()
		refreshOpen()
	end)
	player:GetAttributeChangedSignal("Strength"):Connect(function()
		strCounter.set(math.floor(strengthNow() * 10 + 0.5) / 10)
		if gear.isOpen() then
			refreshGear()
		end
	end)
	player:GetAttributeChangedSignal("Popper"):Connect(refreshButtons)
	Hub.state:GetAttributeChangedSignal("Board"):Connect(refreshBoard)
	refreshBoard()

	Hub.on("announce", onAnnounce)
	Hub.on("reward", onReward)
	Hub.on("rankup", function(p: any)
		if type(p) ~= "table" then
			return
		end
		UI.banner(string.format("RANK UP! %s %s", tostring(p.icon), string.upper(tostring(p.name))), Tiers.get(tostring(p.tier)).color, 3)
		UI.confetti(80)
		UI.flash("gold", 0.6)
		Sfx.play("victory", 0.6)
		UI.toast(string.format("+%d%% strength from your new rank!", math.floor(T.rankBonus * 100)), "purple", 3)
	end)
	Hub.on("quest", function(p: any)
		local coins = type(p) == "table" and tonumber(p.coins) or 0
		UI.banner(I.quest .. " FUEL RUN COMPLETE!", "orange", 2.6)
		UI.confetti(70)
		Sfx.play("victory", 0.6)
		UI.fly(UI.center(), coinCounter.frame, 14, I.coin)
		UI.toast(string.format("+%s %s and 15 min 3x Strength!", Fmt.num(coins or 0), I.coin), "orange", 4)
	end)
	Hub.on("gift", function(p: any)
		if type(p) ~= "table" then
			return
		end
		local k = Config.Kinds[tostring(p.kind)]
		UI.banner(string.format("🎁 A FREE %s %s ARRIVED!", string.upper(Tiers.get(tostring(p.tier)).name), string.upper(k and k.name or "PART")), Tiers.get(tostring(p.tier)).color, 3)
		Sfx.play("magic", 0.6)
		UI.flash("purple", 0.6)
	end)
	Hub.on("rare", function(p: any)
		if type(p) ~= "table" then
			return
		end
		local t = Tiers.get(tostring(p.tier))
		local k = Config.Kinds[tostring(p.kind)]
		local idx = Tiers.index[t.key] or 1
		UI.toast(string.format("✨ A %s %s is at the depot!", string.upper(t.name), k and k.name or "part"), t.color, 4)
		Sfx.play(if idx >= 5 then "reveal" else "sparkle", 0.5)
		if idx >= 5 then
			UI.banner(string.format("✨ %s %s SPOTTED!", string.upper(t.name), string.upper(k and k.name or "PART")), t.color, 2.4)
		end
	end)
	Hub.on("help", function(p: any)
		if type(p) ~= "table" or p.uid == player.UserId then
			return
		end
		local k = Config.Kinds[tostring(p.kind)]
		UI.toast(string.format("%s %s needs a hand with a %s!", I.help, tostring(p.name), k and k.name or "part"), "orange", 3.5)
		Sfx.play("notify", 0.4, 1.2)
	end)
	Hub.on("upgraded", function(p: any)
		if type(p) ~= "table" then
			return
		end
		local g = Config.Gear[tostring(p.track)]
		if g then
			UI.banner(string.format("%s %s LV %d!", g.icon, string.upper(g.name), tonumber(p.level) or 1), "sky", 2.2)
		end
		UI.confetti(40)
		Sfx.play("unlock", 0.6)
		Sfx.play("purchase", 0.4)
	end)
	Hub.on("nope", function()
		Sfx.play("error", 0.5)
		UI.shake(0.1)
	end)
	Hub.on("daily", function(p: any)
		if type(p) ~= "table" then
			return
		end
		UI.banner(string.format("%s DAY %d: +%s %s%s", I.daily, tonumber(p.day) or 1, Fmt.num(tonumber(p.coins) or 0), I.coin, if p.boost then " + 3X!" else ""), "pink", 2.8)
		UI.confetti(80)
		Sfx.play("victory", 0.6)
		UI.fly(UI.center(), coinCounter.frame, 14, I.coin)
	end)
	Hub.on("offline", function(p: any)
		if type(p) ~= "table" then
			return
		end
		local coins = tonumber(p.coins) or 0
		local minutes = tonumber(p.minutes) or 0
		task.delay(1, function()
			if Hub.cinematic then
				return
			end
			showNotice("WELCOME BACK!", I.drone, string.format("Your drones mined %s %s while you were away (%s).\nUpgrade Drone Crew in GEAR to earn more!", Fmt.commas(coins), I.coin, Fmt.time(minutes * 60)), function()
				UI.fly(UI.center(), coinCounter.frame, 12, I.coin)
			end)
		end)
	end)
	Hub.on("income", function(p: any)
		if type(p) ~= "table" then
			return
		end
		local pos = coinPos() + Vector2.new(0, 60)
		UI.floater(string.format("+%s %s %s", Fmt.num(tonumber(p.coins) or 0), I.coin, I.drone), "gold", pos, 30)
		Sfx.play("coin", 0.3)
	end)
	Hub.on("thanks", function(p: any)
		if type(p) ~= "table" then
			return
		end
		UI.banner(string.format("THANK YOU! %s %s", tostring(p.icon), string.upper(tostring(p.name))), "pink", 3)
		UI.confetti(100)
		Sfx.play("purchase", 0.6)
		Sfx.play("cheer", 0.4, 1, 3)
		refreshButtons()
	end)
	Hub.on("popper", function(p: any)
		if type(p) ~= "table" then
			return
		end
		local r = Hub.root()
		if r and typeof(p.pos) == "Vector3" and (r.Position - p.pos).Magnitude < 80 then
			UI.confetti(if p.uid == player.UserId then 90 else 40)
			Sfx.play("pop", 0.6)
			Sfx.play("clap", 0.4)
		end
	end)
	Hub.on("fuel", function(p: any)
		if type(p) ~= "table" then
			return
		end
		UI.flash("orange", 0.55)
		UI.confetti(60, { Config.Palette.orange, Config.Palette.gold, Config.Palette.white })
		UI.toast(string.format("%s %s fueled the server: 2X coins + strength for everyone!", I.fuel, tostring(p.by)), "orange", 4)
	end)
	Hub.on("dropWarn", function()
		UI.toast(I.box .. " SUPPLY DROP in 15s! Watch the sky!", "gold", 4)
		Sfx.play("notify", 0.5)
	end)
	Hub.on("landed", function(p: any)
		if type(p) ~= "table" then
			return
		end
		task.spawn(function()
			local t0 = os.clock()
			while Hub.phase() ~= "build" and os.clock() - t0 < 6 do
				task.wait(0.2)
			end
			task.wait(1.2)
			local pl = Config.planet(tonumber(p.planet) or Hub.planet())
			local lines = {
				string.format("Welcome to %s!", pl.name),
				string.format("+%s %s launch bonus", Fmt.commas(tonumber(p.coins) or 0), I.coin),
			}
			if p.mvp then
				table.insert(lines, "🥇 MVP! You rode the nose (+50% bonus)")
			end
			if p.firstVisit then
				table.insert(lines, "🆕 NEW PLANET: parts here pay x" .. tostring(pl.coins) .. " coins!")
			end
			table.insert(lines, string.format("%s Launches: %d", I.launch, tonumber(p.launches) or 0))
			showNotice("MISSION COMPLETE!", pl.icon, table.concat(lines, "\n"), function()
				UI.fly(UI.center(), coinCounter.frame, 14, I.coin)
			end)
			Sfx.play("victory", 0.6)
		end)
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		refreshCarry()
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		refreshTop()
		if daily.isOpen() then
			refreshDaily()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(5)
			refreshButtons()
		end
	end)
end

return Hud

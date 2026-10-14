-- The HUD: plastic / bags / rank counters, the war score and round timer, the server-boost pill, the left menu
-- (with STRIKE and FREE), the right column (daily, free gift, luck boost, the cat, auto-deploy, mute, supply drop,
-- the Starter Pack / Recruit Deal slot), the big bottom buttons (OPEN, DEPLOY with its counter hint, MERGE), the goal
-- bar with a pointing finger and 3D guide beam, the battle feed, rewards, banners and the (late, rare) offers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Fmt = require(Shared:WaitForChild("Fmt"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local ClientLib = ReplicatedStorage:WaitForChild("ClientLib")
local UI = require(ClientLib:WaitForChild("UI"))
local Sfx = require(ClientLib:WaitForChild("Sfx"))
local State = require(ClientLib:WaitForChild("State"))
local Fx = require(ClientLib:WaitForChild("Fx"))
local Game = require(ClientLib:WaitForChild("Game"))
local Arena = require(ClientLib:WaitForChild("Arena"))
local Panels = require(ClientLib:WaitForChild("Panels"))
local Reveal = require(ClientLib:WaitForChild("Reveal"))
local LiveUI = require(ClientLib:WaitForChild("LiveUI"))

local Hud = {}

local player = Players.LocalPlayer
local I = Config.Icons
type Dict = { [string]: any }

-- Top: counters, rank, war score ---------------------------------------------------------------------------------------
local top = UI.frame(UI.root, {
	Name = "Top",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(760, 56),
})
UI.list(top, 14, true)
local plastic = UI.counter(top, I.plastic, "yellow", function(n)
	return Fmt.commas(n)
end, { LayoutOrder = 1, Size = UDim2.fromOffset(240, 52) })
local bags = UI.counter(top, I.bag, "orange", function(n)
	return tostring(math.floor(n))
end, { LayoutOrder = 2, Size = UDim2.fromOffset(130, 52) })
local bagsBtn = Instance.new("TextButton")
bagsBtn.Name = "BagsCounterButton"
bagsBtn.BackgroundTransparency = 1
bagsBtn.Text = ""
bagsBtn.Size = UDim2.fromScale(1, 1)
bagsBtn.ZIndex = 5
bagsBtn.Parent = bags.frame
local rankPill = UI.card(top, "dark", { LayoutOrder = 3, Size = UDim2.fromOffset(300, 52) })
local rankText = UI.text(rankPill, "🔰 Recruit", { Size = UDim2.new(1, -16, 0, 24), Position = UDim2.fromOffset(8, 3) })
local xpBar = UI.bar(rankPill, "yellow", { Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 29) })

local score = UI.card(UI.root, "dark", {
	Name = "Score",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 72),
	Size = UDim2.fromOffset(380, 40),
})
-- running server boosts ("⚡ 2x PLASTIC 12:04") under the war score; toasts go under both
LiveUI.boostPill(UI.root, { plastic = "PLASTIC", luck = "LUCK" }, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 116), Size = UDim2.fromOffset(340, 32) })
UI.setToastTop(154)
local scoreG = UI.text(score, "GREEN 0", { Size = UDim2.fromOffset(130, 30), Position = UDim2.fromOffset(8, 5), TextColor3 = Config.C.green, TextXAlignment = Enum.TextXAlignment.Left })
local scoreT = UI.text(score, "0 TAN", { Size = UDim2.fromOffset(130, 30), Position = UDim2.new(1, -138, 0, 5), TextColor3 = Config.C.tan, TextXAlignment = Enum.TextXAlignment.Right })
local roundText = UI.text(score, "🏆 3:00", { Size = UDim2.fromOffset(110, 28), Position = UDim2.new(0.5, -55, 0, 6) })

-- Left menu -----------------------------------------------------------------------------------------------------------------
-- The side menus are 2-wide grids at left-middle / right-middle: on desktop Roblox's chat window covers the top-left
-- corner and the player list the top-right one, so both grids sit a little below the centre line there (MID).
-- Four rows of the left menu (STRIKE / FREE are the last row) need slightly smaller cells to clear the chat window.
local MID = UI.isMobile and 0 or 34
local CELL, CELL_GAP = 72, 12
local ROWS = 4
local left = UI.frame(UI.root, {
	Name = "Left",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 14, 0.5, MID),
	Size = UDim2.fromOffset(2 * CELL + CELL_GAP + 4, ROWS * CELL + (ROWS - 1) * CELL_GAP),
})
-- two per row, pinned: the 4 px of slack keeps a scaled-down frame from rounding to one column
local leftGrid = UI.grid(left, UDim2.fromOffset(CELL, CELL), CELL_GAP)
leftGrid.FillDirectionMaxCells = 2
leftGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left
local menu: { [string]: UI.IconButton } = {}
-- rows of two; BASE (the last tutorial goal) sits in the inner column so the guide finger can point at it from the
-- right without covering another button
local MENU = {
	{ "Army", I.army, "ARMY", "green" },
	{ "Bags", I.bag, "BAGS", "orange" },
	{ "Index", I.index, "INDEX", "purple" },
	{ "Upgrades", I.base, "BASE", "blue" },
	{ "Map", I.map, "MAP", "teal" },
	{ "Shop", I.shop, "SHOP", "pink" },
	{ "Strikes", I.strike, "STRIKE", "red" },
	{ "Free", I.free, "FREE", "green" },
}
for i, m in ipairs(MENU) do
	local b = UI.iconButton(left, m[2], m[3], m[4], { LayoutOrder = i, Size = UDim2.fromOffset(CELL, CELL) })
	b.button.Name = m[1] .. "Button"
	menu[m[1]] = b
	b.button.MouseButton1Click:Connect(function()
		if m[1] == "Free" then
			LiveUI.open()
		else
			Panels.toggle(m[1])
		end
	end)
end
-- the FREE badge: playtime gifts and finished quests waiting to be claimed
LiveUI.onClaimable(function(n)
	menu.Free.setBadge(n > 0 and n or nil)
end)

-- Right column ------------------------------------------------------------------------------------------------------------------
-- Six buttons make three rows centred like the left menu; a landed supply drop adds a fourth row underneath (so the
-- others never jump). Phones use smaller cells so that row stays clear of Roblox's touch jump button (bottom right).
local SIDE, SIDE_GAP = 70, 14
if UI.isMobile then
	SIDE, SIDE_GAP = 62, 10
end
local right = UI.frame(UI.root, {
	Name = "Right",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0.5, MID - (3 * SIDE + 2 * SIDE_GAP) / 2),
	Size = UDim2.fromOffset(2 * SIDE + SIDE_GAP + 4, 4 * SIDE + 3 * SIDE_GAP),
})
local rightGrid = UI.grid(right, UDim2.fromOffset(SIDE, SIDE), SIDE_GAP)
rightGrid.FillDirectionMaxCells = 2
rightGrid.HorizontalAlignment = Enum.HorizontalAlignment.Right
rightGrid.VerticalAlignment = Enum.VerticalAlignment.Top
local function side(order: number, glyph: string, label: string, color: any): UI.IconButton
	local b = UI.iconButton(right, glyph, label, color, { LayoutOrder = order, Size = UDim2.fromOffset(SIDE, SIDE) })
	return b
end
local dailyB = side(1, I.daily, "DAILY", "gold")
local giftB = side(2, I.gift, "GIFT", "teal")
local luckB = side(3, I.luck, "LUCK", "green")
local catB = side(4, I.cat, "CAT", "orange")
local autoB = side(5, I.ai, "AUTO", "blue")
local muteB = side(6, I.mute, "MUSIC", "dark")
local supplyB = side(7, I.supply, "SUPPLY", "green")
supplyB.button.Visible = false
-- the deal slot: the Starter Pack with its countdown (first 10 minutes of a first session), later the 9 R$ deal
local dealB = side(8, I.starter, "STARTER", "pink")
dealB.button.Name = "DealButton"
dealB.button.Visible = false

-- Bottom: goal bar and the three big buttons ----------------------------------------------------------------------------
-- (high enough to leave room for the counter hint and the mold-press pill above the big buttons)
local goal = UI.card(UI.root, "dark", {
	Name = "Goal",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -142),
	Size = UDim2.fromOffset(700, 44),
})
local goalText = UI.text(goal, "", { Size = UDim2.new(1, -20, 0, 32), Position = UDim2.fromOffset(10, 6), TextColor3 = Config.C.yellow })

local bottom = UI.frame(UI.root, {
	Name = "Bottom",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	Size = UDim2.fromOffset(720, 90),
})
UI.list(bottom, 16, true)
local openBtn = UI.button(bottom, "🎒 OPEN", "orange", { LayoutOrder = 1, Size = UDim2.fromOffset(190, 74) })
local deployBtn = UI.button(bottom, "⚔️ DEPLOY", "red", { LayoutOrder = 2, Size = UDim2.fromOffset(290, 88) })
local mergeBtn = UI.button(bottom, "🔀 MERGE", "purple", { LayoutOrder = 3, Size = UDim2.fromOffset(190, 74) })
local function badge(b: TextButton): TextLabel
	local l = UI.text(b, "", {
		Font = UI.BODY,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 4),
		Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 0,
		BackgroundColor3 = UI.colors.red,
		ZIndex = b.ZIndex + 4,
		Visible = false,
	})
	UI.corner(l, 17)
	UI.stroke(l, 2.5)
	return l
end
local openBadge = badge(openBtn)
local mergeBadge = badge(mergeBtn)
-- counter hint on the DEPLOY button: your squad's class vs the target's ("💂 vs 🚁 STRONG!")
local counterPill = UI.text(deployBtn, "", {
	Font = UI.BODY,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0, -4),
	Size = UDim2.fromOffset(250, 26),
	BackgroundTransparency = 0,
	BackgroundColor3 = UI.colors.dark,
	Visible = false,
	ZIndex = deployBtn.ZIndex + 4,
})
UI.corner(counterPill, 12)
local pressPill = UI.text(mergeBtn, "", {
	Font = UI.BODY,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0, -4),
	Size = UDim2.fromOffset(200, 26),
	BackgroundTransparency = 0,
	BackgroundColor3 = UI.colors.purple,
	Visible = false,
	ZIndex = mergeBtn.ZIndex + 4,
})
UI.corner(pressPill, 12)

-- Pointing finger for the current goal (lives on the unscaled effects layer).
local finger = UI.text(UI.fx, "👇", { Font = Enum.Font.GothamBold, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(56, 56), Visible = false, ZIndex = 54 })
local fingerTarget: GuiObject? = nil

-- Feed --------------------------------------------------------------------------------------------------------------------------
-- Under the left menu (newest line at the bottom): clear of the chat window and left of the goal bar / big buttons.
-- Lines are tall enough for a long message to wrap onto two lines instead of shrinking to a sliver.
local FEED_W, FEED_LINE, FEED_MAX = 270, 30, 4
local feed = UI.frame(UI.root, {
	Name = "Feed",
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 14, 0.5, MID + left.Size.Y.Offset / 2 + 14),
	Size = UDim2.fromOffset(FEED_W, FEED_MAX * FEED_LINE + (FEED_MAX - 1) * 3),
})
local fl = UI.list(feed, 3, false, Enum.HorizontalAlignment.Left)
fl.VerticalAlignment = Enum.VerticalAlignment.Top
local feedN = 0
local function addFeed(text: string, color: string?)
	feedN += 1
	local l = UI.text(feed, text, {
		Font = UI.BODY,
		Size = UDim2.fromOffset(FEED_W, FEED_LINE),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.lighten(UI.color(color or "white"), 0.25),
		LayoutOrder = feedN,
	})
	local kids: { TextLabel } = {}
	for _, k in ipairs(feed:GetChildren()) do
		if k:IsA("TextLabel") then
			table.insert(kids, k :: TextLabel)
		end
	end
	if #kids > FEED_MAX then
		table.sort(kids, function(a: TextLabel, b: TextLabel)
			return a.LayoutOrder < b.LayoutOrder
		end)
		kids[1]:Destroy()
	end
	task.delay(8, function()
		if l.Parent then
			UI.tween(l, 0.6, { TextTransparency = 1 })
			local s = l:FindFirstChildOfClass("UIStroke")
			if s then
				UI.tween(s, 0.6, { Transparency = 1 })
			end
			task.wait(0.65)
			l:Destroy()
		end
	end)
end

-- State -> HUD ----------------------------------------------------------------------------------------------------------------
local lastTut = 0
local goalButton: GuiObject? = nil

local function tokenOrder(d: Dict): string?
	for i = #Config.Bags, 1, -1 do
		local key = Config.Bags[i].key
		if (d.tokens[key] or 0) > 0 then
			return key
		end
	end
	return nil
end

local function zoneName(id: string?): string
	local def = id and Config.ZoneById[id]
	if not def then
		return "?"
	end
	if def.outpost then
		return "Outpost"
	end
	return def.name
end

-- The class (Config.Classes) with the most power in a list of { unit, power }.
type Power = { unit: string, power: number }
local function mainClass(list: { Power }): string?
	local sum: { [string]: number } = {}
	local best, bestPower = nil :: string?, 0
	for _, e in ipairs(list) do
		local c = Config.classOf(e.unit).key
		sum[c] = (sum[c] or 0) + e.power
		if sum[c] > bestPower then
			best, bestPower = c, sum[c]
		end
	end
	return best
end

-- "💂 vs 🚁 STRONG!" over the DEPLOY button: the squad it sends (strongest ready toys) against the target's toys.
local function updateCounter(d: Dict, target: string?, ready: number)
	local def = target and Config.ZoneById[target]
	local snap = target and Arena.snapshot(target)
	if ready <= 0 or not def or def.outpost or not snap or (snap.owner or "") == Game.side() then
		counterPill.Visible = false
		return
	end
	local enemy: { Power } = {}
	for _, u in ipairs((snap.units or {}) :: { { any } }) do
		table.insert(enemy, { unit = tostring(u[2]), power = tonumber(u[7]) or 0 })
	end
	local busy = Game.busy()
	local mine: { Power } = {}
	for stack in pairs(d.units) do
		local n = math.min(12, Game.ready(d, stack, busy))
		local u, m = Config.split(stack)
		for _ = 1, n do
			table.insert(mine, { unit = u, power = Config.power(u, m) })
		end
	end
	table.sort(mine, function(a: Power, b: Power)
		return a.power > b.power
	end)
	for i = #mine, Game.squadSize(d) + 1, -1 do
		table.remove(mine, i)
	end
	local a, b = mainClass(mine), mainClass(enemy)
	if not a or not b then
		counterPill.Visible = false
		return
	end
	local rel = Config.matchup(a, b)
	counterPill.Text = Config.Classes[a].glyph .. " vs " .. Config.Classes[b].glyph .. (rel == "strong" and "  STRONG! ✅" or rel == "weak" and "  WEAK! ⚠️" or "  EVEN")
	counterPill.BackgroundColor3 = rel == "strong" and UI.colors.green or rel == "weak" and UI.colors.red or UI.colors.dark
	counterPill.Visible = true
end

local function refresh()
	local d = Game.d()
	if not d then
		return
	end
	plastic.set(d.plastic or 0)
	local tokens = Game.tokens(d)
	bags.set(tokens)
	local r = Config.rankOf(d.xp or 0)
	local rk = Config.Ranks[r]
	local nx = Config.Ranks[r + 1]
	rankText.Text = rk.glyph .. " " .. rk.name
	if nx then
		xpBar.set((d.xp - rk.xp) / (nx.xp - rk.xp), Fmt.num(d.xp) .. " / " .. Fmt.num(nx.xp) .. " XP")
	else
		xpBar.set(1, "MAX RANK")
	end
	-- buttons
	openBadge.Visible = tokens > 0
	openBadge.Text = tostring(tokens)
	openBtn.Text = tokens > 0 and "🎒 OPEN FREE" or "🎒 BAGS"
	local merges = Game.mergeable(d)
	mergeBadge.Visible = #merges > 0
	mergeBadge.Text = tostring(#merges)
	UI.recolor(mergeBtn, #merges > 0 and "purple" or "grey")
	local m1 = d.merging[1]
	if m1 then
		local u, mu = Config.split(m1.key)
		pressPill.Visible = true
		pressPill.Text = "🔀 " .. Config.unitName(u, mu) .. " " .. Fmt.time(math.max(0, (m1.done or 0) - Game.now()))
	else
		pressPill.Visible = false
	end
	local ready = Game.readyTotal(d)
	local target = player:GetAttribute("Target") :: string?
	if ready > 0 then
		-- words, not "→": the arrow did not render in the title font in Studio, so the button read "DEPLOY OUTPOST"
		deployBtn.Text = "⚔️ DEPLOY TO " .. zoneName(target)
		UI.recolor(deployBtn, "red")
	else
		deployBtn.Text = Game.count(d) > 0 and "⚔️ ALL DEPLOYED" or "⚔️ NO SOLDIERS"
		UI.recolor(deployBtn, "grey")
	end
	updateCounter(d, target, ready)
	-- right column
	local daily = d.daily.last == 0 or Config.dayNumber(Game.now()) > Config.dayNumber(d.daily.last)
	dailyB.setBadge(daily and "!" or nil)
	supplyB.button.Visible = player:GetAttribute("SupplyReady") == true
	autoB.label.Text = Game.owns("autodeploy") and (d.settings.auto and "AUTO ON" or "AUTO OFF") or "AUTO"
	UI.recolor(autoB.button, (Game.owns("autodeploy") and d.settings.auto) and "green" or "blue")
	-- menu badges
	menu.Army.setBadge(#merges > 0 and #merges or nil)
	menu.Bags.setBadge(tokens > 0 and tokens or nil)
	local canUp = false
	for _, u in ipairs(Config.Upgrades) do
		local lvl = d.upgrades[u.key] or 0
		if lvl < u.max and d.plastic >= Config.upgradeCost(u.key, lvl) then
			canUp = true
		end
	end
	menu.Upgrades.setBadge(canUp and "!" or nil)
	-- goal
	local tut = d.tut or 1
	local guide: string? = nil
	goalButton = nil
	if tut < Config.TutDone then
		goalText.Text = "🎯 " .. tostring(Config.Tut[tut])
		if tut == 1 or tut == 4 or tut == 6 then
			guide = target
			goalButton = deployBtn
		elseif tut == 2 then
			goalButton = openBtn
		elseif tut == 3 then
			goalButton = mergeBtn
		elseif tut == 5 then
			goalButton = supplyB.button
		elseif tut == 7 then
			goalButton = menu.Upgrades.button
		end
	else
		if #merges > 0 then
			local u = Config.split(merges[1])
			local nx2 = Config.nextUnit(u)
			goalText.Text = "🎯 Merge 3 " .. (Config.UnitByKey[u] and Config.UnitByKey[u].name or u) .. "s into a " .. (nx2 and nx2.name or "?") .. "!"
		elseif ready > 0 then
			goalText.Text = "🎯 Capture " .. zoneName(target) .. "! Hold more zones to win the round 🏆"
		elseif tokens > 0 then
			goalText.Text = "🎯 Open your free bags! 🎒"
		else
			goalText.Text = "🎯 Your army is out fighting! Upgrade your Toy Box 📦"
		end
	end
	Arena.setGuide(guide)
	fingerTarget = goalButton
	if tut ~= lastTut then
		if lastTut ~= 0 then
			UI.punch(goal, 0.3)
		end
		lastTut = tut
	end
end

State.onChange(function()
	refresh()
end)
Arena.onChange(function(id)
	if id == player:GetAttribute("Target") then
		refresh()
	end
end)
for _, attr in ipairs({ "Busy", "Target", "SupplyReady" }) do
	player:GetAttributeChangedSignal(attr):Connect(refresh)
end

-- A HUD element's position on the effects layer. AbsolutePosition is measured from below Roblox's top bar while the
-- layer (IgnoreGuiInset) starts at the very top of the screen, so measure from the layer itself; using
-- AbsolutePosition as-is put the finger a top bar's height (58 px) too high, over the character.
local function onFx(g: GuiObject): Vector2
	return g.AbsolutePosition - UI.fx.AbsolutePosition
end

-- Finger bob at the goal button: from above for the bottom buttons, from the inside for the side menus (so it
-- doesn't cover the button above it in the grid).
task.spawn(function()
	local t = 0
	while true do
		task.wait(0.05)
		t += 0.05
		local b = fingerTarget
		if b and b.Visible and not Reveal.isOpen() then
			local p = onFx(b)
			local s = b.AbsoluteSize
			local bob = math.abs(math.sin(t * 5)) * 12
			if b:IsDescendantOf(left) then
				finger.Text = "👈"
				finger.AnchorPoint = Vector2.new(0, 0.5)
				finger.Position = UDim2.fromOffset(p.X + s.X + 2 + bob, p.Y + s.Y / 2)
			elseif b:IsDescendantOf(right) then
				finger.Text = "👉"
				finger.AnchorPoint = Vector2.new(1, 0.5)
				finger.Position = UDim2.fromOffset(p.X - 2 - bob, p.Y + s.Y / 2)
			else
				finger.Text = "👇"
				finger.AnchorPoint = Vector2.new(0.5, 1)
				finger.Position = UDim2.fromOffset(p.X + s.X / 2, p.Y - 2 - bob)
			end
			finger.Visible = true
		else
			finger.Visible = false
		end
	end
end)

-- Timers: round, gift, luck, cat, merge pill, the deal slot -----------------------------------------------------------------
local giftToasted = false
task.spawn(function()
	while true do
		task.wait(0.5)
		local now = Game.now()
		local re = workspace:GetAttribute("RoundEnd")
		if type(re) == "number" then
			roundText.Text = "🏆 " .. Fmt.time(re - now)
		end
		local g = workspace:GetAttribute("ZonesGreen")
		local t = workspace:GetAttribute("ZonesTan")
		scoreG.Text = "GREEN " .. tostring(g or 0)
		scoreT.Text = tostring(t or 0) .. " TAN"
		local gift = player:GetAttribute("GiftAt")
		if type(gift) == "number" then
			local left = gift - now
			giftB.label.Text = left > 0 and Fmt.time(left) or "FREE!"
			giftB.setBadge(left <= 0 and "!" or nil)
			if left <= 0 and not giftToasted then
				giftToasted = true
				UI.toast("🎁 Your FREE gift is ready! Tap GIFT ➡️", "teal", 4)
				UI.punch(giftB.button, 0.4)
				Sfx.play("notify", 0.5)
			elseif left > 0 then
				giftToasted = false
			end
		end
		local d = Game.d()
		if d then
			-- deal slot: Starter Pack countdown (first session, after minute 2), else the 9 R$ deal for new spenders
			local starter = Game.starterLeft(d)
			local late = Game.age() >= Config.NoOffersBefore
			if late and starter > 0 then
				dealB.button.Visible = true
				dealB.icon.Text = I.starter
				dealB.label.Text = Fmt.time(starter)
				dealB.setBadge("!")
			elseif late and Game.neverBought(d) then
				dealB.button.Visible = true
				dealB.icon.Text = I.deal
				dealB.label.Text = "R$" .. Config.Products.intro.price .. " DEAL"
				dealB.setBadge(nil)
			else
				dealB.button.Visible = false
			end
			local boost = (d.boosts.luck or 0) - now
			luckB.label.Text = boost > 0 and Fmt.time(boost) or "LUCK"
			local m1 = d.merging[1]
			if m1 then
				local u, mu = Config.split(m1.key)
				pressPill.Text = "🔀 " .. Config.unitName(u, mu) .. " " .. Fmt.time(math.max(0, (m1.done or 0) - now))
			end
		end
		if workspace:GetAttribute("CatActive") == true then
			catB.label.Text = "CAT!"
		else
			local cat = workspace:GetAttribute("CatAt")
			if type(cat) == "number" then
				catB.label.Text = Fmt.time(cat - now)
			end
		end
	end
end)

-- Actions --------------------------------------------------------------------------------------------------------------------
local act = Panels.act

local function openBag(key: string?)
	local d = Game.d()
	if not d then
		return
	end
	local k = key or tokenOrder(d)
	if k and (d.tokens[k] or 0) > 0 then
		act("open", k, true)
	elseif key then
		act("open", key, false)
	else
		Panels.open("Bags")
	end
end
Reveal.onAgain(function(label)
	openBag(label)
end)

openBtn.MouseButton1Click:Connect(function()
	openBag(nil)
end)
bagsBtn.MouseButton1Click:Connect(function()
	Panels.toggle("Bags")
end)

deployBtn.MouseButton1Click:Connect(function()
	local target = player:GetAttribute("Target")
	if type(target) ~= "string" or target == "" then
		Panels.open("Map")
		return
	end
	local ok = act("deploy", target)
	if ok then
		Sfx.play("whoosh", 0.5, 1.2)
		UI.punch(deployBtn, 0.2)
	end
end)

mergeBtn.MouseButton1Click:Connect(function()
	local d = Game.d()
	if not d then
		return
	end
	local list = Game.mergeable(d)
	if #list == 0 then
		UI.toast("Need 3 ready soldiers of the same kind to merge!", "purple")
		Panels.open("Army")
		return
	end
	local ok = act("merge", list[1])
	if ok then
		Sfx.play("magic", 0.5, 1.2)
		UI.punch(mergeBtn, 0.25)
	end
end)

dailyB.button.MouseButton1Click:Connect(function()
	Panels.toggle("Daily")
end)
giftB.button.MouseButton1Click:Connect(function()
	local gift = player:GetAttribute("GiftAt")
	if type(gift) == "number" and gift > Game.now() then
		UI.toast("⏰ Free bag in " .. Fmt.time(gift - Game.now()) .. "! Stay and play.", "teal")
		return
	end
	local ok = act("gift")
	if ok then
		Sfx.play("cash", 0.6)
		UI.banner("🎁 FREE GIFT!", "teal")
	end
end)
supplyB.button.MouseButton1Click:Connect(function()
	local ok = act("supply")
	if ok then
		UI.flash("green", 0.5)
	end
end)
luckB.button.MouseButton1Click:Connect(function()
	Panels.shopTab("BOOSTS")
end)
catB.button.MouseButton1Click:Connect(function()
	Panels.open("Strikes")
end)

-- The deal slot: the Starter Pack (first 10 minutes of the first session, with its countdown), else the R$9 intro deal.
local function starterOffer(d: { [string]: any }): boolean
	local left = Game.starterLeft(d)
	if left <= 0 then
		return false
	end
	UI.offer({
		title = "STARTER PACK!",
		text = Config.Products.starter.desc,
		glyph = I.starter,
		price = "R$ " .. Config.Products.starter.price,
		color = "pink",
		seconds = math.floor(left),
		onBuy = function()
			Game.buy("product", "starter")
		end,
	})
	return true
end

local function introOffer(d: { [string]: any }): boolean
	if not Game.neverBought(d) then
		return false
	end
	UI.offer({
		title = "RECRUIT DEAL!",
		text = Config.Products.intro.desc .. " Only once!",
		glyph = I.deal,
		price = "R$ " .. Config.Products.intro.price,
		color = "teal",
		onBuy = function()
			Game.buy("product", "intro")
		end,
	})
	return true
end

dealB.button.MouseButton1Click:Connect(function()
	local d = Game.d()
	if d and not starterOffer(d) and not introOffer(d) then
		dealB.button.Visible = false
	end
end)
autoB.button.MouseButton1Click:Connect(function()
	local d = Game.d()
	if not d then
		return
	end
	if Game.owns("autodeploy") then
		act("auto", not d.settings.auto)
	else
		Panels.shopTab("PASSES")
	end
end)
muteB.button.MouseButton1Click:Connect(function()
	local m = not Sfx.isMuted()
	Sfx.setMuted(m)
	muteB.icon.Text = m and I.muted or I.mute
	muteB.label.Text = m and "MUTED" or "MUSIC"
end)

-- Server events -------------------------------------------------------------------------------------------------------------
local PLASTIC_KINDS = { capture = "🚩", defend = "🛡️", drill = "🎯", income = "", purchase = "🛒", daily = "🎁", gift = "⏰", round = "🏆", supply = "🪂", debug = "🔧", plastic = "", offline = "🏭" }

Net.event("Reward").OnClientEvent:Connect(function(kind, amount, pos, extra)
	if PLASTIC_KINDS[kind] ~= nil then
		local n = tonumber(amount) or 0
		local text = "+" .. Fmt.num(n) .. " 🧱"
		if kind == "income" then
			UI.floater(text, "yellow", onFx(plastic.frame) + Vector2.new(plastic.frame.AbsoluteSize.X * 0.6, 60), 26)
			return
		end
		local from = (typeof(pos) == "Vector3" and UI.screenPos(pos)) or UI.center()
		UI.fly(from, plastic.frame, math.clamp(math.floor(n / 15), 3, 12), I.plastic)
		UI.floater(text, "yellow", from, 40)
		Sfx.play("coin", 0.4)
	elseif kind == "bag" then
		local from = (typeof(pos) == "Vector3" and UI.screenPos(pos)) or UI.center()
		UI.fly(from, openBtn, 3, Config.BagByKey[tostring(extra)] and Config.BagByKey[tostring(extra)].glyph or I.bag)
		UI.toast("🎒 +" .. tostring(amount) .. " free " .. (Config.BagByKey[tostring(extra)] and Config.BagByKey[tostring(extra)].name or "bag") .. "!", "orange")
		Sfx.play("pop", 0.5, 1.2)
		UI.punch(openBtn, 0.3)
	elseif kind == "rank" then
		local rk = Config.Ranks[tonumber(amount) or 1]
		if rk then
			UI.banner("⭐ PROMOTED: " .. string.upper(rk.name) .. "!", "yellow", 2.6)
			UI.confetti(70)
			Sfx.play("unlock", 0.7)
		end
	elseif kind == "tut" then
		local n = tonumber(amount) or 0
		if n >= Config.TutDone then
			UI.banner("🎖️ BASIC TRAINING COMPLETE!", "gold", 3)
			UI.confetti(90)
			Sfx.play("victory", 0.5)
		else
			UI.banner("✅ GOAL COMPLETE!", "green", 1.6)
			UI.confetti(30)
			Sfx.play("sparkle", 0.5)
		end
	elseif kind == "supply" then
		UI.toast("🪂 A SUPPLY DROP landed! Open it on the right ➡️", "green", 5)
		Sfx.play("notify", 0.6)
		UI.punch(supplyB.button, 0.5)
	end
end)

Net.event("BagResult").OnClientEvent:Connect(function(label, results)
	if type(results) == "table" then
		Reveal.show(tostring(label), results)
	end
end)

Net.event("Merged").OnClientEvent:Connect(function(r)
	if type(r) == "table" then
		Reveal.merged(r)
	end
end)

Net.event("Announce").OnClientEvent:Connect(function(text, tier)
	local t = Tiers.get(tostring(tier))
	UI.toast(tostring(text), t.color, 5)
	Sfx.play("notify", 0.5)
	addFeed(tostring(text), "yellow")
end)

Net.event("Feed").OnClientEvent:Connect(function(text, color)
	addFeed(tostring(text), tostring(color or "white"))
end)

local offered: { [string]: number } = {}
local function offer(key: string, o: { [string]: any })
	if Game.age() < 120 or (offered[key] and os.clock() - offered[key] < 600) then
		return
	end
	if Reveal.isOpen() then
		return
	end
	offered[key] = os.clock()
	UI.offer(o)
end

Net.event("Round").OnClientEvent:Connect(function(winner, g, t)
	local w = tostring(winner)
	local def = Config.Team[w]
	if def then
		local mine = w == Game.side()
		UI.banner("🏆 " .. string.upper(def.name) .. " WINS THE ROUND!", def.color, 3)
		if mine then
			UI.confetti(80)
			Sfx.play("victory", 0.5)
		else
			Sfx.play("thud", 0.4)
			local enemyLead = (w == "Green" and (g or 0) - (t or 0)) or ((t or 0) - (g or 0))
			if enemyLead >= 2 then
				local p = Config.Products.callcat
				offer("callcat", {
					title = "CALL THE CAT!",
					text = "The " .. def.name .. " is winning! Send the cat to swat their army!",
					glyph = I.cat,
					price = "R$ " .. p.price,
					color = "orange",
					seconds = 20,
					onBuy = function()
						Game.buy("product", "callcat")
					end,
				})
			end
		end
	else
		UI.banner("🤝 THE ROUND IS A TIE!", "white", 2.5)
	end
end)

Arena.onEnd(function(info)
	if not info.mineSide then
		return
	end
	if info.winner == "Cat" then
		UI.banner("🐱 SWATTED!", "orange", 2)
		return
	end
	local won = (info.mineSide == "att" and info.captured) or (info.mineSide == "def" and not info.captured)
	if info.drill then
		if won then
			UI.banner("🎯 DRILL COMPLETE!", "green", 1.8)
			Sfx.play("clap", 0.5)
		else
			UI.banner("💥 TRY AGAIN!", "red", 1.8)
		end
		return
	end
	if won then
		UI.banner(info.mineSide == "att" and "🚩 VICTORY! ZONE CAPTURED!" or "🛡️ DEFENDED!", "green", 2.4)
		UI.confetti(50)
		Sfx.play("victory", 0.5)
	else
		UI.banner("💥 DEFEAT! MERGE STRONGER TOYS!", "red", 2.4)
		Sfx.play("thud", 0.5)
		local d = Game.d()
		if d and not d.starterPack then
			local p = Config.Products.tanks
			offer("tanks", {
				title = "TANK BUNDLE!",
				text = "Get 2 Tanks + 1 GOLD Tank and take that zone back!",
				glyph = "🛡️",
				price = "R$ " .. p.price,
				color = "purple",
				seconds = 20,
				onBuy = function()
					Game.buy("product", "tanks")
				end,
			})
		end
	end
end)

-- Redraw the HUD now (live prices arrived).
function Hud.refresh()
	refresh()
end

-- Cat hooks for CatView
function Hud.catHooks(): { [string]: (...any) -> () }
	return {
		run = function()
			addFeed("🐱 The cat is on the prowl!", "pink")
		end,
		done = function()
			UI.toast("🐱 The cat went back to sleep. Re-deploy your army!", "orange", 4)
		end,
		warn = function() end,
		swat = function(_zone: any, n: any)
			if (tonumber(n) or 0) > 0 then
				Sfx.play("pop", 0.6, 0.8)
			end
		end,
	}
end

-- Offers never pop up in the first 2 minutes of a session. The Starter Pack pops up once just after that (only in
-- the first 10 minutes of the first session; its countdown stays on the deal button), the R$9 intro deal once a
-- session a few minutes later for players who never bought anything.
task.spawn(function()
	while Game.age() < Config.NoOffersBefore + 5 do
		task.wait(1)
	end
	local d = Game.d()
	if d and Game.starterLeft(d) > 30 and not Reveal.isOpen() then
		offered.starter = os.clock()
		starterOffer(d)
	end
	while Game.age() < 300 do
		task.wait(2)
	end
	d = Game.d()
	while d and Game.starterLeft(d) > 0 do
		task.wait(5)
		d = Game.d()
	end
	if d and Game.neverBought(d) then
		while Reveal.isOpen() or UI.getPanel("__offer") and (UI.getPanel("__offer") :: any).isOpen() do
			task.wait(2)
		end
		offered.intro = os.clock()
		introOffer(d)
	end
end)

function Hud.init()
	task.spawn(function()
		State.wait()
		refresh()
		local ok, info = Game.act("hello")
		if ok and type(info) == "table" then
			if info.first then
				UI.banner(Config.Title, "yellow", 3.5)
				Sfx.play("cheer", 0.35, 1, 3)
			elseif (tonumber(info.offline) or 0) > 0 then
				Panels.welcome(info)
			end
			if info.daily and not info.first then
				task.delay((tonumber(info.offline) or 0) > 0 and 0.2 or 1.5, function()
					local p = UI.getPanel("Welcome")
					while p and p.isOpen() do
						task.wait(0.5)
					end
					Panels.open("Daily")
				end)
			end
		end
	end)
	local _ = Fx
end

return Hud

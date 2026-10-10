-- The HUD: plastic / bags / rank counters, the war score and round timer, the left menu, the right column
-- (daily, free gift, supply drop, luck boost, the cat, auto-deploy, mute), the big bottom buttons (OPEN, DEPLOY,
-- MERGE), the goal bar with a pointing finger and 3D guide beam, the battle feed, rewards and banners.
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
local scoreG = UI.text(score, "GREEN 0", { Size = UDim2.fromOffset(130, 30), Position = UDim2.fromOffset(8, 5), TextColor3 = Config.C.green, TextXAlignment = Enum.TextXAlignment.Left })
local scoreT = UI.text(score, "0 TAN", { Size = UDim2.fromOffset(130, 30), Position = UDim2.new(1, -138, 0, 5), TextColor3 = Config.C.tan, TextXAlignment = Enum.TextXAlignment.Right })
local roundText = UI.text(score, "🏆 3:00", { Size = UDim2.fromOffset(110, 28), Position = UDim2.new(0.5, -55, 0, 6) })

-- Left menu -----------------------------------------------------------------------------------------------------------------
local left = UI.frame(UI.root, {
	Name = "Left",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 14, 0.5, 24),
	Size = UDim2.fromOffset(84, 540),
})
UI.list(left, 10)
local menu: { [string]: UI.IconButton } = {}
local MENU = {
	{ "Army", I.army, "ARMY", "green" },
	{ "Bags", I.bag, "BAGS", "orange" },
	{ "Upgrades", I.base, "BASE", "blue" },
	{ "Index", I.index, "INDEX", "purple" },
	{ "Map", I.map, "MAP", "teal" },
	{ "Shop", I.shop, "SHOP", "pink" },
}
for i, m in ipairs(MENU) do
	local b = UI.iconButton(left, m[2], m[3], m[4], { LayoutOrder = i, Size = UDim2.fromOffset(78, 78) })
	b.button.Name = m[1] .. "Button"
	menu[m[1]] = b
	b.button.MouseButton1Click:Connect(function()
		Panels.toggle(m[1])
	end)
end

-- Right column ------------------------------------------------------------------------------------------------------------------
local right = UI.frame(UI.root, {
	Name = "Right",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -14, 0.5, 20),
	Size = UDim2.fromOffset(78, 600),
})
local rightList = UI.list(right, 8)
local SIDE = 70
if UI.isMobile then
	-- phones: start the column under the top bar and keep it compact, so its bottom buttons stay clear of
	-- Roblox's touch jump button (bottom right) instead of covering it and eating jump taps
	SIDE = 62
	rightList.Padding = UDim.new(0, 4)
	rightList.VerticalAlignment = Enum.VerticalAlignment.Top
	right.AnchorPoint = Vector2.new(1, 0)
	right.Position = UDim2.new(1, -14, 0, 80)
	right.Size = UDim2.fromOffset(78, 7 * SIDE + 6 * 4)
end
local function side(order: number, glyph: string, label: string, color: any): UI.IconButton
	local b = UI.iconButton(right, glyph, label, color, { LayoutOrder = order, Size = UDim2.fromOffset(SIDE, SIDE) })
	return b
end
local dailyB = side(1, I.daily, "DAILY", "gold")
local giftB = side(2, I.gift, "GIFT", "teal")
local supplyB = side(3, I.supply, "SUPPLY", "green")
local luckB = side(4, I.luck, "LUCK", "green")
local catB = side(5, I.cat, "CAT", "orange")
local autoB = side(6, I.ai, "AUTO", "blue")
local muteB = side(7, I.mute, "MUSIC", "dark")
supplyB.button.Visible = false

-- Bottom: goal bar and the three big buttons ----------------------------------------------------------------------------
local goal = UI.card(UI.root, "dark", {
	Name = "Goal",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -112),
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
local feed = UI.frame(UI.root, {
	Name = "Feed",
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 110, 0, 130),
	Size = UDim2.fromOffset(420, 200),
})
local fl = UI.list(feed, 4, false, Enum.HorizontalAlignment.Left)
fl.VerticalAlignment = Enum.VerticalAlignment.Top
local feedN = 0
local function addFeed(text: string, color: string?)
	feedN += 1
	local l = UI.text(feed, text, {
		Font = UI.BODY,
		Size = UDim2.fromOffset(420, 26),
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
	if #kids > 5 then
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
		deployBtn.Text = "⚔️ DEPLOY ▸ " .. zoneName(target)
		UI.recolor(deployBtn, "red")
	else
		deployBtn.Text = Game.count(d) > 0 and "⚔️ ALL DEPLOYED" or "⚔️ NO SOLDIERS"
		UI.recolor(deployBtn, "grey")
	end
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
for _, attr in ipairs({ "Busy", "Target", "SupplyReady" }) do
	player:GetAttributeChangedSignal(attr):Connect(refresh)
end

-- Finger bob over the goal button.
task.spawn(function()
	local t = 0
	while true do
		task.wait(0.05)
		t += 0.05
		local b = fingerTarget
		if b and b.Visible and not Reveal.isOpen() then
			local p = b.AbsolutePosition
			local s = b.AbsoluteSize
			finger.Visible = true
			finger.Position = UDim2.fromOffset(p.X + s.X / 2, p.Y - 2 - math.abs(math.sin(t * 5)) * 12)
		else
			finger.Visible = false
		end
	end
end)

-- Timers: round, gift, luck, cat, merge pill -------------------------------------------------------------------------------
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
		end
		local d = Game.d()
		if d then
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
	local p = Config.Products.callcat
	UI.offer({
		title = "CALL THE CAT!",
		text = "Wake the cat NOW and send it to swat the enemy army! The whole server will see it.",
		glyph = I.cat,
		price = "R$ " .. p.price,
		color = "orange",
		onBuy = function()
			Game.buy("product", "callcat")
		end,
	})
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
			UI.floater(text, "yellow", plastic.frame.AbsolutePosition + Vector2.new(plastic.frame.AbsoluteSize.X * 0.6, 60), 26)
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

-- Starter pack offer once, after a few minutes of play (never before minute 2).
task.delay(250, function()
	local d = Game.d()
	if d and not d.starterPack then
		local p = Config.Products.starter
		offer("starter", {
			title = "STARTER PACK!",
			text = "1,000 plastic, a Medic and 3 Heavy Duffels. Only once!",
			glyph = "🎒",
			price = "R$ " .. p.price,
			color = "pink",
			seconds = 30,
			onBuy = function()
				Game.buy("product", "starter")
			end,
		})
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

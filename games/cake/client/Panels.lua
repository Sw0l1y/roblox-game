-- Menus: Shop (toppings, colours, upgrades, Robux), Topping Index, Mystery Sprinkle Box (odds + reveal),
-- Daily reward and the Pick-the-Theme menu. Every panel refreshes from the latest save data.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientLib = ReplicatedStorage:WaitForChild("ClientLib")
local Config = require(Shared:WaitForChild("Config"))
local Fmt = require(Shared:WaitForChild("Fmt"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local UI = require(ClientLib:WaitForChild("UI"))
local Sfx = require(ClientLib:WaitForChild("Sfx"))
local Own = require(ClientLib:WaitForChild("Own"))
local Widgets = require(ClientLib:WaitForChild("Widgets"))

local Panels = {}

type D = { [string]: any }

local ctx: Own.Ctx = nil :: any
local refreshers: { () -> () } = {}
local shop: UI.Panel
local shopSelect: (string) -> ()
local index: UI.Panel
local box: UI.Panel
local daily: UI.Panel
local theme: UI.Panel
local revealing = false

local function data(): D?
	return ctx.data()
end

local function act(action: string, a: any?, b: any?): any
	return ctx.act(action, a, b)
end

local function buy(kind: string, key: string)
	ctx.buy(kind, key)
end

-- Toast + sound for an Act result. Returns true on success.
local function result(r: any, okSound: string?): boolean
	if type(r) ~= "table" then
		UI.toast("Oops, try again!", "red")
		Sfx.play("error", 0.5)
		return false
	end
	if r.ok then
		if type(r.msg) == "string" then
			UI.toast(r.msg, "green")
		end
		Sfx.play(okSound or "purchase", 0.6)
		return true
	end
	UI.toast(tostring(r.msg or "Not right now"), "red")
	Sfx.play("error", 0.5)
	return false
end

local function refresh(fn: () -> ())
	table.insert(refreshers, fn)
end

local function dark(l: TextLabel): TextLabel
	l.TextColor3 = UI.INK
	local s = l:FindFirstChildOfClass("UIStroke")
	if s then
		s.Enabled = false
	end
	return l
end

-- Shop -------------------------------------------------------------------------------------------------
local function buildShop()
	shop = UI.panel("Shop", "🛒 BAKERY SHOP", "green", Vector2.new(900, 540))
	local pages, select = UI.tabs(shop.body, { "Toppings", "Colours", "Upgrades", "Robux" }, { "pink", "sky", "orange", "green" })
	shopSelect = select

	-- Toppings: everything sold for coins, cheapest first
	local tScroll = UI.scroll(pages.Toppings)
	UI.grid(tScroll, UDim2.fromOffset(150, 190), 12)
	local list: { Config.ToppingDef } = {}
	for _, t in ipairs(Config.Toppings) do
		if t.source == "shop" then
			table.insert(list, t)
		end
	end
	table.sort(list, function(a: Config.ToppingDef, b: Config.ToppingDef)
		return a.price < b.price
	end)
	for i, t in ipairs(list) do
		local card = Widgets.toppingCard(tScroll, t.id, 150, 190, i)
		card.glyph.Size = UDim2.new(1, 0, 0.36, 0)
		card.name.Position = UDim2.new(0, 4, 0.4, 0)
		card.name.Size = UDim2.new(1, -8, 0.14, 0)
		card.foot.Position = UDim2.new(0, 4, 0.55, 0)
		card.foot.Size = UDim2.new(1, -8, 0.11, 0)
		card.foot.Text = Tiers.get(t.tier).name
		local btn = UI.button(card.button, "", "green", { Name = "Buy", Size = UDim2.new(1, -16, 0, 44), Position = UDim2.new(0, 8, 1, -52), ZIndex = card.button.ZIndex + 2 })
		btn.MouseButton1Click:Connect(function()
			if Own.topping(data(), t.id) then
				UI.toast(t.glyph .. " " .. t.name .. " is already in your tray!", "blue")
				return
			end
			if result(act("unlock", "topping", t.id)) then
				UI.confetti(30)
			end
		end)
		refresh(function()
			local d = data()
			local owned = Own.topping(d, t.id)
			btn.Text = if owned then "OWNED ✔" else "🪙 " .. Fmt.num(t.price)
			UI.recolor(btn, if owned then "grey" elseif d and (d.coins or 0) >= t.price then "green" else "orange")
		end)
	end

	-- Colours: coin colours, then the pass colours
	local cScroll = UI.scroll(pages.Colours)
	UI.grid(cScroll, UDim2.fromOffset(124, 160), 12)
	for i, def in ipairs(Config.Colors) do
		if def.price > 0 or def.pass then
			local cell = UI.card(cScroll, "white", { Name = def.key, LayoutOrder = i })
			local sw = Widgets.swatch(cell, def.key, 62, 0)
			sw.button.Position = UDim2.new(0.5, -31, 0, 10)
			dark(UI.text(cell, def.name, { Font = UI.BODY, Size = UDim2.new(1, -10, 0, 24), Position = UDim2.fromOffset(5, 76) }))
			local btn = UI.button(cell, "", "green", { Name = "Buy", Size = UDim2.new(1, -14, 0, 42), Position = UDim2.new(0, 7, 1, -50) })
			local function go()
				if Own.color(data(), def.key) then
					UI.toast(def.name .. " is already yours!", "blue")
				elseif def.pass then
					buy("pass", def.pass)
				else
					result(act("unlock", "color", def.key))
				end
			end
			btn.MouseButton1Click:Connect(go)
			sw.button.MouseButton1Click:Connect(go)
			refresh(function()
				local d = data()
				local owned = Own.color(d, def.key)
				if owned then
					btn.Text = "OWNED ✔"
					UI.recolor(btn, "grey")
				elseif def.pass then
					btn.Text = "R$ " .. Config.Passes[def.pass].price
					UI.recolor(btn, "purple")
				else
					btn.Text = "🪙 " .. Fmt.num(def.price)
					UI.recolor(btn, if d and (d.coins or 0) >= def.price then "green" else "orange")
				end
			end)
		end
	end

	-- Upgrades: shapes, the 4th tier and topping slots
	local uScroll = UI.scroll(pages.Upgrades)
	UI.list(uScroll, 10)
	local function row(order: number, glyph: string, title: string, desc: string, color: string, onBuy: () -> (), state: () -> (string, string)): ()
		local card = UI.card(uScroll, color, { Name = title, LayoutOrder = order, Size = UDim2.new(1, -10, 0, 84) })
		UI.text(card, glyph, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(12, 10) })
		UI.text(card, title, { Size = UDim2.new(1, -330, 0, 36), Position = UDim2.fromOffset(88, 8), TextXAlignment = Enum.TextXAlignment.Left })
		UI.text(card, desc, { Font = UI.BODY, Size = UDim2.new(1, -330, 0, 28), Position = UDim2.fromOffset(88, 46), TextXAlignment = Enum.TextXAlignment.Left })
		local btn = UI.button(card, "", "green", { Name = "Buy", Size = UDim2.fromOffset(210, 60), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0) })
		btn.MouseButton1Click:Connect(onBuy)
		refresh(function()
			local text, col = state()
			btn.Text = text
			UI.recolor(btn, col)
		end)
	end
	local function priced(price: number, owned: boolean): (string, string)
		if owned then
			return "OWNED ✔", "grey"
		end
		local d = data()
		return "🪙 " .. Fmt.num(price), if d and (d.coins or 0) >= price then "green" else "orange"
	end
	for i, s in ipairs(Config.Shapes) do
		if s.price > 0 then
			row(i, s.glyph, s.name .. " Cakes", "Bake " .. string.lower(s.name) .. "-shaped tiers", "pink", function()
				if Own.shape(data(), s.key) then
					return
				end
				if result(act("unlock", "shape", s.key)) then
					UI.confetti(30)
				end
			end, function()
				return priced(s.price, Own.shape(data(), s.key))
			end)
		end
	end
	row(10, "🎂", "4-Tier Cakes", "Stack a fourth tier for towering cakes", "sky", function()
		local d = data()
		if d and d.tier4 then
			return
		end
		if result(act("unlock", "tier4")) then
			UI.confetti(30)
		end
	end, function()
		local d = data()
		return priced(Config.Cake.tier4Price, d ~= nil and d.tier4 == true)
	end)
	row(11, "🍬", "Topping Slots", "+" .. Config.Cake.slotStep .. " more toppings on every cake", "purple", function()
		result(act("unlock", "slots"))
	end, function()
		local d = data()
		local lvl = if d then d.slots or 0 else 0
		if lvl >= #Config.Cake.slotUpgrades then
			return "MAXED ✔", "grey"
		end
		return priced(Config.Cake.slotUpgrades[lvl + 1], false)
	end)

	-- Robux: passes (forever) then products
	local rScroll = UI.scroll(pages.Robux)
	UI.grid(rScroll, UDim2.fromOffset(260, 168), 12)
	local function robuxCard(kind: string, key: string, def: Config.ProductDef, order: number)
		local color = if kind == "pass" then (if key == "GoldenOven" then "gold" else "purple") else "teal"
		local card = UI.card(rScroll, color, { Name = key, LayoutOrder = order })
		UI.text(card, def.glyph, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(50, 50), Position = UDim2.fromOffset(10, 10) })
		UI.text(card, def.name, { Size = UDim2.new(1, -76, 0, 30), Position = UDim2.fromOffset(66, 12), TextXAlignment = Enum.TextXAlignment.Left })
		UI.text(card, def.desc, { Font = UI.BODY, Size = UDim2.new(1, -20, 0, 44), Position = UDim2.fromOffset(10, 62), TextWrapped = true })
		local btn = UI.button(card, "R$ " .. def.price, "green", { Name = "Buy", Size = UDim2.new(1, -20, 0, 46), Position = UDim2.new(0, 10, 1, -54) })
		btn.MouseButton1Click:Connect(function()
			if kind == "pass" and Own.pass(data(), key) then
				UI.toast("You already own " .. def.name .. "!", "blue")
				return
			end
			if key == "Starter" then
				local d = data()
				if d and d.starter then
					UI.toast("Starter Pack already claimed!", "blue")
					return
				end
			end
			buy(kind, key)
		end)
		if kind == "pass" or key == "Starter" then
			refresh(function()
				local d = data()
				local owned = if kind == "pass" then Own.pass(d, key) else (d ~= nil and d.starter == true)
				btn.Text = if owned then "OWNED ✔" else "R$ " .. def.price
				UI.recolor(btn, if owned then "grey" else "green")
			end)
		end
	end
	type Entry = { key: string, def: Config.ProductDef }
	local passes: { Entry } = {}
	for key, def in pairs(Config.Passes) do
		table.insert(passes, { key = key, def = def })
	end
	table.sort(passes, function(a: Entry, b: Entry)
		return a.def.order < b.def.order
	end)
	for i, p in ipairs(passes) do
		robuxCard("pass", p.key, p.def, i)
	end
	local products: { Entry } = {}
	for key, def in pairs(Config.Products) do
		table.insert(products, { key = key, def = def })
	end
	table.sort(products, function(a: Entry, b: Entry)
		return a.def.order < b.def.order
	end)
	for i, p in ipairs(products) do
		robuxCard("product", p.key, p.def, 100 + i)
	end
	shop.onOpen = function()
		Panels.refresh()
	end
end

-- Topping Index -----------------------------------------------------------------------------------------
local function buildIndex()
	index = UI.panel("Index", "📖 TOPPING INDEX", "blue", Vector2.new(900, 540))
	local body = index.body
	local bar = UI.bar(body, "blue", { Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 22) })
	local note = dark(UI.text(body, "", { Font = UI.BODY, Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 60) }))
	local scroll = UI.scroll(body, { Size = UDim2.new(1, 0, 1, -92), Position = UDim2.fromOffset(0, 92) })
	UI.grid(scroll, UDim2.fromOffset(118, 138), 10)
	local sorted = table.clone(Config.Toppings)
	table.sort(sorted, function(a: Config.ToppingDef, b: Config.ToppingDef)
		local ta, tb = Tiers.index[a.tier] or 0, Tiers.index[b.tier] or 0
		if ta ~= tb then
			return ta < tb
		end
		return a.price < b.price
	end)
	for i, t in ipairs(sorted) do
		local card = Widgets.toppingCard(scroll, t.id, 118, 138, i)
		card.button.MouseButton1Click:Connect(function()
			local d = data()
			if Own.topping(d, t.id) then
				UI.toast(t.glyph .. " " .. t.name .. " · " .. Tiers.get(t.tier).name, Tiers.get(t.tier).color)
			elseif t.source == "shop" then
				Panels.openShop("Toppings")
			elseif t.source == "box" then
				Panels.openBox()
			elseif t.source == "vip" then
				buy("pass", "VIP")
			end
		end)
		refresh(function()
			local d = data()
			local owned = Own.topping(d, t.id)
			local secret = t.tier == "Secret" and not owned
			card.glyph.Text = if secret then "❓" else t.glyph
			card.glyph.TextTransparency = if owned then 0 else 0.55
			card.name.Text = if secret then "???" else t.name
			if owned then
				card.foot.Text = "✔ " .. Tiers.get(t.tier).name
			elseif t.source == "shop" then
				card.foot.Text = "🪙 " .. Fmt.num(t.price)
			elseif t.source == "box" then
				card.foot.Text = "🎁 Box only"
			else
				card.foot.Text = "👑 VIP"
			end
			UI.recolor(card.button, if owned then Tiers.get(t.tier).color else "grey")
		end)
	end
	refresh(function()
		local d = data()
		local n = Own.indexCount(d)
		bar.set(n / #Config.Toppings, string.format("%d / %d toppings", n, #Config.Toppings))
		local nextM: number? = nil
		for _, m in ipairs(Config.Rewards.indexMilestones) do
			if n < m then
				nextM = m
				break
			end
		end
		note.Text = if nextM then string.format("Collect %d for a free 🎁 Mystery Box!", nextM) else "Every milestone reached! 🏆"
	end)
	index.onOpen = function()
		Panels.refresh()
	end
end

-- Mystery Sprinkle Box -----------------------------------------------------------------------------------
local function buildBox()
	box = UI.panel("Box", "🎁 MYSTERY BOX", "pink", Vector2.new(720, 480))
	local body = box.body
	-- left: the box and the open button
	local left = UI.frame(body, { BackgroundTransparency = 1, Size = UDim2.new(0.5, -10, 1, 0) })
	local glyph = UI.text(left, "🎁", { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(130, 130), Position = UDim2.new(0.5, -65, 0, 18) })
	local count = dark(UI.text(left, "", { Font = UI.BODY, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 154) }))
	local openBtn = UI.button(left, "OPEN!", "green", { Name = "Open", Size = UDim2.new(1, -30, 0, 70), Position = UDim2.fromOffset(15, 192) })
	local luck = UI.button(left, "🍀 2.5x Luck · R$ " .. Config.Products.Luck.price, "teal", { Name = "Luck", Size = UDim2.new(1, -30, 0, 50), Position = UDim2.fromOffset(15, 276) })
	local luckNote = dark(UI.text(left, "", { Font = UI.BODY, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 334) }))
	-- right: odds and Robux boxes
	local right = UI.frame(body, { BackgroundTransparency = 1, Size = UDim2.new(0.5, -10, 1, 0), Position = UDim2.new(0.5, 10, 0, 0) })
	dark(UI.text(right, "ODDS", { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 18) }))
	for i, e in ipairs(Config.Box.odds) do
		local t = Tiers.get(e.key)
		local r = UI.card(right, t.color, { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 18 + i * 38) })
		local name = UI.text(r, t.name, { Size = UDim2.new(0.6, 0, 0.8, 0), Position = UDim2.fromScale(0.04, 0.1), TextXAlignment = Enum.TextXAlignment.Left })
		if t.rainbow then
			UI.rainbow(name)
		end
		UI.text(r, Tiers.odds(Config.Box.odds, e), { Font = UI.BODY, Size = UDim2.new(0.36, 0, 0.8, 0), Position = UDim2.fromScale(0.62, 0.1), TextXAlignment = Enum.TextXAlignment.Right })
	end
	local b1 = UI.button(right, "🎁 1 Box · R$ " .. Config.Products.Box1.price, "purple", { Name = "Box1", Size = UDim2.new(1, 0, 0, 46), Position = UDim2.fromOffset(0, 290) })
	local b5 = UI.button(right, "🎁 5 Boxes · R$ " .. Config.Products.Box5.price, "purple", { Name = "Box5", Size = UDim2.new(1, 0, 0, 46), Position = UDim2.fromOffset(0, 342) })
	b1.MouseButton1Click:Connect(function()
		buy("product", "Box1")
	end)
	b5.MouseButton1Click:Connect(function()
		buy("product", "Box5")
	end)
	luck.MouseButton1Click:Connect(function()
		buy("product", "Luck")
	end)

	-- reveal overlay
	local over = UI.card(body, "dark", { Name = "Reveal", Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 30 })
	local rGlyph = UI.text(over, "🎁", { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(150, 150), Position = UDim2.new(0.5, -75, 0, 30), ZIndex = 31 })
	local rName = UI.text(over, "", { Size = UDim2.new(1, -40, 0, 50), Position = UDim2.fromOffset(20, 190), ZIndex = 31 })
	local rTier = UI.text(over, "", { Size = UDim2.new(1, -40, 0, 38), Position = UDim2.fromOffset(20, 244), ZIndex = 31 })
	local rNote = UI.text(over, "", { Font = UI.BODY, Size = UDim2.new(1, -40, 0, 30), Position = UDim2.fromOffset(20, 288), ZIndex = 31 })
	local rOk = UI.button(over, "AWESOME!", "green", { Name = "Ok", Size = UDim2.fromOffset(240, 64), Position = UDim2.new(0.5, -120, 1, -84), ZIndex = 32, Visible = false })
	local rainbowGrad: UIGradient? = nil
	rOk.MouseButton1Click:Connect(function()
		over.Visible = false
	end)

	local glyphs: { string } = {}
	for _, ids in pairs(Config.BoxPool) do
		for _, id in ipairs(ids) do
			table.insert(glyphs, Config.ToppingById[id].glyph)
		end
	end

	openBtn.MouseButton1Click:Connect(function()
		if revealing then
			return
		end
		local d = data()
		if not d then
			return
		end
		if (d.boxes or 0) <= 0 and (d.coins or 0) < Config.Box.price then
			UI.toast("Need 🪙 " .. Config.Box.price .. " or a free box. Win rounds to earn more!", "orange")
			Sfx.play("error", 0.5)
			UI.punch(b1, 0.2)
			return
		end
		revealing = true
		local r = act("box", true)
		if type(r) ~= "table" or not r.ok then
			revealing = false
			result(r)
			return
		end
		local id = tostring(r.id)
		local def = Config.ToppingById[id]
		if not def then
			revealing = false
			return
		end
		local tier = Tiers.get(def.tier)
		over.Visible = true
		rOk.Visible = false
		rName.Text = ""
		rTier.Text = ""
		rNote.Text = ""
		if rainbowGrad then
			rainbowGrad:Destroy()
			rainbowGrad = nil
		end
		UI.recolor(over, "dark")
		Sfx.play("reveal", 0.6)
		local rng = Random.new()
		for i = 1, 16 do
			rGlyph.Text = glyphs[rng:NextInteger(1, #glyphs)]
			UI.punch(rGlyph, 0.12)
			Sfx.play("swipe", 0.25, 1 + i * 0.04)
			task.wait(0.04 + i * 0.012)
		end
		rGlyph.Text = def.glyph
		UI.punch(rGlyph, 0.6)
		rName.Text = def.name
		rTier.Text = string.upper(tier.name)
		rTier.TextColor3 = tier.color
		if tier.rainbow then
			rainbowGrad = UI.rainbow(rTier)
		end
		UI.recolor(over, tier.dark)
		if r.dup then
			rNote.Text = "Already collected · +" .. tostring(r.refund or 0) .. " 🪙"
			Sfx.play("coin", 0.6)
		else
			rNote.Text = "NEW! Added to your tray 🎉"
			Sfx.play("unlock", 0.7)
		end
		local ti = Tiers.index[def.tier] or 1
		if ti >= 4 then
			UI.confetti(60 + ti * 10, { tier.color, tier.dark, Color3.new(1, 1, 1) })
			Sfx.play("magic", 0.7)
		end
		if ti >= 5 then
			UI.flash(tier.color, 0.25)
			UI.shake(0.3)
		end
		rOk.Visible = true
		revealing = false
	end)

	refresh(function()
		local d = data()
		local n: number = if d then d.boxes or 0 else 0
		count.Text = if n > 0 then string.format("You have %d box%s!", n, if n == 1 then "" else "es") else "No free boxes · win rounds for more"
		openBtn.Text = if n > 0 then "OPEN FREE BOX!" else "OPEN · 🪙 " .. Config.Box.price
		UI.recolor(openBtn, if n > 0 or (d and (d.coins or 0) >= Config.Box.price) then "green" else "grey")
		glyph.Rotation = if n > 0 then 6 else 0
		local left2 = if d then (d.luckUntil or 0) - os.time() else 0
		luckNote.Text = if left2 > 0 then "🍀 Lucky Sprinkles: " .. Fmt.time(left2) else "Luck shifts odds toward rarer tiers"
	end)
	box.onOpen = function()
		over.Visible = false
		Panels.refresh()
	end
end

-- Daily reward ---------------------------------------------------------------------------------------------
local function dailyState(d: D?): (boolean, number, number)
	if not d then
		return false, 1, 0
	end
	local now = os.time()
	local last = d.dailyLast or 0
	local streak = d.dailyStreak or 0
	if now - last > Config.DailyReset then
		streak = 0
	end
	return now - last >= Config.DailyCooldown, streak % #Config.Daily + 1, math.max(0, Config.DailyCooldown - (now - last))
end
Panels.dailyState = dailyState

local function buildDaily()
	daily = UI.panel("Daily", "📅 DAILY TREATS", "orange", Vector2.new(760, 360))
	local body = daily.body
	local row = UI.frame(body, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 140), Position = UDim2.fromOffset(0, 26) })
	UI.list(row, 10, true)
	local cells = {}
	for i, coins in ipairs(Config.Daily) do
		local c = UI.card(row, "white", { Name = "Day" .. i, LayoutOrder = i, Size = UDim2.fromOffset(88, 128) })
		dark(UI.text(c, "Day " .. i, { Size = UDim2.new(1, -8, 0, 26), Position = UDim2.fromOffset(4, 6) }))
		UI.text(c, if i == #Config.Daily then "🎁" else "🪙", { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0.5, -23, 0, 34) })
		dark(UI.text(c, Fmt.num(coins), { Font = UI.BODY, Size = UDim2.new(1, -8, 0, 26), Position = UDim2.fromOffset(4, 84) }))
		local tick = UI.text(c, "✔", { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(36, 36), Position = UDim2.new(1, -30, 0, -10), Visible = false, TextColor3 = UI.colors.green })
		cells[i] = { card = c, tick = tick }
	end
	local claim = UI.button(body, "CLAIM!", "green", { Name = "Claim", Size = UDim2.fromOffset(300, 70), Position = UDim2.new(0.5, -150, 0, 190) })
	claim.MouseButton1Click:Connect(function()
		local can = dailyState(data())
		if not can then
			UI.toast("Come back later for more treats!", "orange")
			return
		end
		local r = act("daily")
		if result(r, "cash") then
			UI.confetti(50)
			ctx.flyCoins(claim.AbsolutePosition + claim.AbsoluteSize / 2, tonumber(r.coins) or 50)
		end
	end)
	refresh(function()
		local can, day, wait = dailyState(data())
		for i, c in ipairs(cells) do
			c.tick.Visible = i < day
			UI.recolor(c.card, if i == day then (if can then "gold" else "sky") else "white")
		end
		claim.Text = if can then "CLAIM 🪙 " .. Config.Daily[day] else "⏳ " .. Fmt.time(wait)
		UI.recolor(claim, if can then "green" else "grey")
	end)
	daily.onOpen = function()
		Panels.refresh()
	end
end

-- Pick the next theme ------------------------------------------------------------------------------------------
local function buildTheme()
	theme = UI.panel("Theme", "🎡 PICK THE THEME", "teal", Vector2.new(820, 520))
	local body = theme.body
	local note = dark(UI.text(body, "", { Font = UI.BODY, Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 22) }))
	local grid = UI.frame(body, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -140), Position = UDim2.fromOffset(0, 60) })
	UI.grid(grid, UDim2.fromOffset(180, 86), 10)
	for i = 1, Config.RegularThemes do
		local t = Config.Themes[i]
		local b = UI.button(grid, "", "sky", { Name = t.key, LayoutOrder = i })
		Widgets.blank(b)
		UI.text(b, t.glyph, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0, 8, 0.5, -23), ZIndex = b.ZIndex + 1 })
		UI.text(b, t.name, { Size = UDim2.new(1, -66, 0.7, 0), Position = UDim2.new(0, 60, 0.15, 0), ZIndex = b.ZIndex + 1 })
		b.MouseButton1Click:Connect(function()
			local d = data()
			if d and (d.themeTickets or 0) > 0 then
				if result(act("pickTheme", t.key), "magic") then
					theme.close()
				end
			else
				buy("product", "PickTheme")
			end
		end)
	end
	local buyBtn = UI.button(body, "🎟️ BUY A PICK · R$ " .. Config.Products.PickTheme.price, "pink", { Name = "BuyPick", Size = UDim2.fromOffset(380, 60), Position = UDim2.new(0.5, -190, 1, -70) })
	buyBtn.MouseButton1Click:Connect(function()
		buy("product", "PickTheme")
	end)
	refresh(function()
		local d = data()
		local n: number = if d then d.themeTickets or 0 else 0
		note.Text = if n > 0 then string.format("🎟️ You have %d pick%s! Tap a theme for the next round.", n, if n == 1 then "" else "s") else "Choose the next round's theme for the whole server!"
	end)
	theme.onOpen = function()
		Panels.refresh()
	end
end

-- API ---------------------------------------------------------------------------------------------------------------
function Panels.refresh()
	for _, fn in ipairs(refreshers) do
		fn()
	end
end

function Panels.update(_d: D)
	if shop.isOpen() or index.isOpen() or box.isOpen() or daily.isOpen() or theme.isOpen() then
		Panels.refresh()
	end
end

function Panels.openShop(tab: string?)
	shop.open()
	shopSelect(tab or "Toppings")
	Panels.refresh()
end

function Panels.openIndex()
	index.open()
end

function Panels.openBox()
	box.open()
end

function Panels.openDaily()
	daily.open()
end

function Panels.openTheme()
	theme.open()
end

function Panels.init(c: Own.Ctx)
	ctx = c
	buildShop()
	buildIndex()
	buildBox()
	buildDaily()
	buildTheme()
	Panels.refresh()
end

return Panels

-- Menus: Shop (toppings, colours, upgrades, passes with gift buttons, Robux products in sections), Topping
-- Index (with each box topping's chance), Mystery Sprinkle Box (live percent odds, reveal, the paid-random
-- policy), Daily reward, Pick-the-Theme, the Caketober prize track, the starter / intro offers and the
-- first-minute welcome gift. Every panel refreshes from the latest save data and live Robux prices.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientLib = ReplicatedStorage:WaitForChild("ClientLib")
local Config = require(Shared:WaitForChild("Config"))
local Fmt = require(Shared:WaitForChild("Fmt"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local UI = require(ClientLib:WaitForChild("UI"))
local Sfx = require(ClientLib:WaitForChild("Sfx"))
local LiveUI = require(ClientLib:WaitForChild("LiveUI"))
local Own = require(ClientLib:WaitForChild("Own"))
local Widgets = require(ClientLib:WaitForChild("Widgets"))

local Panels = {}

type D = { [string]: any }
type ProductDef = Config.ProductDef

local player = Players.LocalPlayer
local ctx: Own.Ctx = nil :: any
local refreshers: { () -> () } = {}
local shop: UI.Panel
local shopSelect: (string) -> ()
local index: UI.Panel
local box: UI.Panel
local daily: UI.Panel
local theme: UI.Panel
local track: UI.Panel
local revealing = false
local welcome = false -- the box panel is showing the first-minute welcome gift
local openOne: () -> () = function() end
local trackScroll: ScrollingFrame? = nil

local function data(): D?
	return ctx.data()
end

local function act(action: string, a: any?, b: any?): any
	return ctx.act(action, a, b)
end

local function buy(kind: string, key: string)
	ctx.buy(kind, key)
end

-- Live price text ("R$ 49"): Config holds the planned price; kit Prices writes Roblox's live price into it.
local function price(kind: string, key: string): string
	local def = if kind == "pass" then Config.Passes[key] else Config.Products[key]
	return "R$ " .. (if def then def.price else 0)
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

local function blocked(): boolean
	return ctx.blocked()
end

-- Shop -------------------------------------------------------------------------------------------------
local function buildShop()
	shop = UI.panel("Shop", "🛒 BAKERY SHOP", "green", Vector2.new(900, 540))
	local pages, select = UI.tabs(shop.body, { "Toppings", "Colours", "Upgrades", "Passes", "Robux" }, { "pink", "sky", "orange", "purple", "green" })
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
			btn.Text = if owned then "OWNED ✔" else "💰 " .. Fmt.num(t.price)
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
					btn.Text = price("pass", def.pass)
					UI.recolor(btn, "purple")
				else
					btn.Text = "💰 " .. Fmt.num(def.price)
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
	local function priced(cost: number, owned: boolean): (string, string)
		if owned then
			return "OWNED ✔", "grey"
		end
		local d = data()
		return "💰 " .. Fmt.num(cost), if d and (d.coins or 0) >= cost then "green" else "orange"
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

	type Entry = { key: string, def: ProductDef }
	local function sorted(set: { [string]: ProductDef }, filter: ((ProductDef) -> boolean)?): { Entry }
		local out: { Entry } = {}
		for key, def in pairs(set) do
			if filter == nil or filter(def) then
				table.insert(out, { key = key, def = def })
			end
		end
		table.sort(out, function(a: Entry, b: Entry)
			return a.def.order < b.def.order
		end)
		return out
	end

	-- Passes (forever), each with a gift copy for a player in the server
	local pScroll = UI.scroll(pages.Passes)
	UI.grid(pScroll, UDim2.fromOffset(260, 196), 12)
	for i, p in ipairs(sorted(Config.Passes, nil)) do
		local key, def = p.key, p.def
		local card = UI.card(pScroll, if key == "GoldenOven" then "gold" elseif key == "Caketober" then "orange" else "purple", { Name = key, LayoutOrder = i })
		UI.text(card, def.glyph, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(50, 50), Position = UDim2.fromOffset(10, 10) })
		UI.text(card, def.name, { Size = UDim2.new(1, -76, 0, 30), Position = UDim2.fromOffset(66, 12), TextXAlignment = Enum.TextXAlignment.Left })
		UI.text(card, def.desc, { Font = UI.BODY, Size = UDim2.new(1, -20, 0, 66), Position = UDim2.fromOffset(10, 60), TextWrapped = true })
		local btn = UI.button(card, "", "green", { Name = "Buy", Size = UDim2.new(0.62, -12, 0, 48), Position = UDim2.new(0, 10, 1, -56) })
		local gift = UI.button(card, "🎁 GIFT", "pink", { Name = "Gift", Size = UDim2.new(0.38, -8, 0, 48), Position = UDim2.new(0.62, 2, 1, -56) })
		btn.MouseButton1Click:Connect(function()
			if Own.pass(data(), key) then
				UI.toast("You already own " .. def.name .. "!", "blue")
				return
			end
			buy("pass", key)
		end)
		gift.MouseButton1Click:Connect(function()
			if Config.Products["Gift" .. key] then
				LiveUI.gift("Gift" .. key, "GIFT " .. string.upper(def.name))
			end
		end)
		refresh(function()
			local d = data()
			local owned = Own.pass(d, key)
			card.Visible = key ~= "Caketober" or Config.trackLive() or owned
			btn.Text = if owned then "OWNED ✔" else price("pass", key)
			UI.recolor(btn, if owned then "grey" else "green")
			gift.Visible = Config.Products["Gift" .. key] ~= nil
		end)
	end

	-- Robux products by section
	local rScroll = UI.scroll(pages.Robux)
	UI.list(rScroll, 8)
	local COLS, CARD_H, GAP = 3, 168, 12
	local function visibleFor(key: string, def: ProductDef, d: D?): boolean
		if def.random and blocked() then
			return false -- paid random items are hidden from restricted players
		end
		if key == "Intro" then
			return Own.introOk(d)
		elseif key == "Starter" then
			return Own.starterLeft(d) > 0
		elseif key == "Coins6Deal" then
			return not Own.bought(d, "Coins6Deal")
		elseif def.section == "track" then
			return Config.trackLive()
		end
		return true
	end
	for si, sec in ipairs(Config.ShopSections) do
		local items = sorted(Config.Products, function(def: ProductDef): boolean
			return def.section == sec.key
		end)
		local header = UI.text(rScroll, sec.title, { LayoutOrder = si * 2 - 1, Size = UDim2.new(1, -8, 0, 34), TextXAlignment = Enum.TextXAlignment.Left })
		local holder = UI.frame(rScroll, { Name = "Section_" .. sec.key, BackgroundTransparency = 1, LayoutOrder = si * 2, Size = UDim2.new(1, -8, 0, CARD_H) })
		UI.grid(holder, UDim2.fromOffset(260, CARD_H), GAP)
		local cards: { { key: string, def: ProductDef, frame: Frame } } = {}
		for i, p in ipairs(items) do
			local key, def = p.key, p.def
			local card = UI.card(holder, if sec.key == "deal" then "pink" elseif sec.key == "boost" then "gold" else "teal", { Name = key, LayoutOrder = i })
			UI.text(card, def.glyph, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(50, 50), Position = UDim2.fromOffset(10, 10) })
			UI.text(card, def.name, { Size = UDim2.new(1, -76, 0, 30), Position = UDim2.fromOffset(66, 12), TextXAlignment = Enum.TextXAlignment.Left })
			local desc = UI.text(card, def.desc, { Font = UI.BODY, Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 58), TextWrapped = true })
			local btn = UI.button(card, "", "green", { Name = "Buy", Size = UDim2.new(1, -20, 0, 46), Position = UDim2.new(0, 10, 1, -54) })
			btn.MouseButton1Click:Connect(function()
				local d = data()
				if def.once and Own.bought(d, key) then
					UI.toast("You already got the " .. def.name .. "!", "blue")
					return
				end
				buy("product", key)
			end)
			table.insert(cards, { key = key, def = def, frame = card })
			refresh(function()
				local d = data()
				local text = price("product", key)
				local col = "green"
				local boost = def.boost
				if boost and boost.needs and Config.serverBoost(boost.kind) < boost.needs then
					text = "🔒 needs " .. boost.needs .. "x · " .. text
					col = "grey"
				end
				btn.Text = text
				UI.recolor(btn, col)
				if key == "Starter" then
					local base = if blocked() then Config.StarterBlocked.desc else def.desc
					desc.Text = base .. " · ⏳ " .. Fmt.time(Own.starterLeft(d))
				elseif key == "Overtime" and d and (d.overtime or 0) > 0 then
					desc.Text = "⏰ " .. d.overtime .. " ready! " .. def.desc
				elseif Config.Reactions[key] and Own.credits(d, key) > 0 then
					desc.Text = "x" .. Own.credits(d, key) .. " saved · " .. def.desc
				end
			end)
		end
		refresh(function()
			local d = data()
			local n = 0
			for _, c in ipairs(cards) do
				local vis = visibleFor(c.key, c.def, d)
				c.frame.Visible = vis
				if vis then
					n += 1
				end
			end
			header.Visible = n > 0
			holder.Visible = n > 0
			local rows = math.max(1, math.ceil(n / COLS))
			holder.Size = UDim2.new(1, -8, 0, rows * CARD_H + (rows - 1) * GAP)
		end)
	end
	shop.onOpen = function()
		Panels.refresh()
	end
end

-- Topping Index -----------------------------------------------------------------------------------------
local indexOdds: { [string]: TextLabel } = {}
local function boxPercents(luck: number): { [string]: number }
	local ps = Tiers.percents(Config.Box.odds, luck)
	local out = {}
	for i, e in ipairs(Config.Box.odds) do
		out[e.key] = ps[i]
	end
	return out
end

-- "🎁 0.82%": a box-only topping's chance per box with the player's current luck (Secret ones too).
local function boxItemText(d: D, id: string): string
	local luck = Config.boxLuck(d.luckUntil)
	local pct = Config.itemOdds(id, d.toppings or {}, luck, boxPercents(luck))
	return "🎁 " .. Tiers.pct(math.floor(pct * 1000 + 0.5) / 1000) .. (if luck > 1 then " 🍀" else "")
end

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
			elseif t.source == "event" then
				Panels.openTrack()
			elseif t.source == "vip" then
				if ctx.canPrompt() then
					buy("pass", "VIP")
				else
					Panels.openShop("Passes")
				end
			end
		end)
		if t.source == "box" then
			indexOdds[t.id] = card.foot
		end
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
				card.foot.Text = "💰 " .. Fmt.num(t.price)
			elseif t.source == "box" and d then
				card.foot.Text = boxItemText(d, t.id)
			elseif t.source == "event" then
				card.foot.Text = "🎃 " .. Config.Track.name
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

-- Each unowned box-only topping's exact chance per box, with the player's current luck.
local function refreshIndexOdds()
	local d = data()
	if not d then
		return
	end
	for id, label in pairs(indexOdds) do
		if not Own.topping(d, id) then
			label.Text = boxItemText(d, id)
		end
	end
end

-- Mystery Sprinkle Box -----------------------------------------------------------------------------------
local refreshBoxOdds: () -> () = function() end

local function buildBox()
	box = UI.panel("Box", "🎁 MYSTERY BOX", "pink", Vector2.new(760, 540))
	local body = box.body
	-- left: the box and the open button
	local left = UI.frame(body, { BackgroundTransparency = 1, Size = UDim2.new(0.5, -10, 1, 0) })
	local glyph = UI.text(left, "🎁", { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(120, 120), Position = UDim2.new(0.5, -60, 0, 14) })
	local count = dark(UI.text(left, "", { Font = UI.BODY, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 140) }))
	local firstNote = UI.text(left, "✨ Your first box is a guaranteed RARE!", { Font = UI.BODY, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 172), TextColor3 = Color3.fromRGB(80, 160, 255) })
	local openBtn = UI.button(left, "OPEN!", "green", { Name = "Open", Size = UDim2.new(1, -30, 0, 70), Position = UDim2.fromOffset(15, 204) })
	local luck = UI.button(left, "", "teal", { Name = "Luck", Size = UDim2.new(1, -30, 0, 50), Position = UDim2.fromOffset(15, 288) })
	local luckNote = dark(UI.text(left, "", { Font = UI.BODY, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 346) }))
	local freeNote = dark(UI.text(left, "", { Font = UI.BODY, Size = UDim2.new(1, -10, 0, 70), Position = UDim2.fromOffset(5, 380), TextWrapped = true }))
	-- right: odds (percent, sums to 100, live with luck) and Robux boxes
	local right = UI.frame(body, { BackgroundTransparency = 1, Size = UDim2.new(0.5, -10, 1, 0), Position = UDim2.new(0.5, 10, 0, 0) })
	local oddsTitle = dark(UI.text(right, "ODDS", { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 10) }))
	local oddsLabels: { TextLabel } = {}
	for i, e in ipairs(Config.Box.odds) do
		local t = Tiers.get(e.key)
		local r = UI.card(right, t.color, { Size = UDim2.new(1, 0, 0, 32), Position = UDim2.fromOffset(0, 10 + i * 36) })
		local name = UI.text(r, t.name, { Size = UDim2.new(0.34, 0, 0.8, 0), Position = UDim2.fromScale(0.03, 0.1), TextXAlignment = Enum.TextXAlignment.Left })
		if t.rainbow then
			UI.rainbow(name)
		end
		oddsLabels[i] = UI.text(r, "", { Font = UI.BODY, Size = UDim2.new(0.6, 0, 0.8, 0), Position = UDim2.fromScale(0.38, 0.1), TextXAlignment = Enum.TextXAlignment.Right })
	end
	dark(UI.text(right, "Every topping in a tier has the same chance; a duplicate re-rolls once.", { Font = UI.BODY, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 266), TextWrapped = true }))
	local b1 = UI.button(right, "", "purple", { Name = "Box1", Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 306) })
	local b5 = UI.button(right, "", "purple", { Name = "Box5", Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 356) })
	local b15 = UI.button(right, "", "purple", { Name = "Box15", Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 406) })
	b1.MouseButton1Click:Connect(function()
		buy("product", "Box1")
	end)
	b5.MouseButton1Click:Connect(function()
		buy("product", "Box5")
	end)
	b15.MouseButton1Click:Connect(function()
		buy("product", "Box15")
	end)
	luck.MouseButton1Click:Connect(function()
		buy("product", "Luck")
	end)

	refreshBoxOdds = function()
		local d = data()
		local l = Config.boxLuck(if d then d.luckUntil else 0)
		for i, e in ipairs(Config.Box.odds) do
			oddsLabels[i].Text = Tiers.oddsLive(Config.Box.odds, e, l)
		end
		oddsTitle.Text = if l > 1 then string.format("ODDS · 🍀 %gx LUCK", l) else "ODDS"
		local left2 = if d then (d.luckUntil or 0) - os.time() else 0
		local server = Config.serverBoost("luck")
		if left2 > 0 then
			luckNote.Text = "🍀 Lucky Sprinkles: " .. Fmt.time(left2) .. (if server > 1 then string.format(" · server %gx", server) else "")
		elseif server > 1 then
			luckNote.Text = string.format("🍀 Server luck %gx is on!", server)
		else
			luckNote.Text = if blocked() then "" else "Luck shifts odds toward rarer tiers"
		end
	end

	-- reveal overlay
	local over = UI.card(body, "dark", { Name = "Reveal", Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 30 })
	local rTitle = UI.text(over, "", { Size = UDim2.new(1, -40, 0, 40), Position = UDim2.fromOffset(20, 10), ZIndex = 31, TextColor3 = Config.Palette.gold })
	local rGlyph = UI.text(over, "🎁", { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(150, 150), Position = UDim2.new(0.5, -75, 0, 50), ZIndex = 31 })
	local rName = UI.text(over, "", { Size = UDim2.new(1, -40, 0, 50), Position = UDim2.fromOffset(20, 210), ZIndex = 31 })
	local rTier = UI.text(over, "", { Size = UDim2.new(1, -40, 0, 38), Position = UDim2.fromOffset(20, 264), ZIndex = 31 })
	local rNote = UI.text(over, "", { Font = UI.BODY, Size = UDim2.new(1, -40, 0, 30), Position = UDim2.fromOffset(20, 308), ZIndex = 31 })
	local rOk = UI.button(over, "AWESOME!", "green", { Name = "Ok", Size = UDim2.fromOffset(240, 64), Position = UDim2.new(0.5, -120, 1, -84), ZIndex = 32, Visible = false })
	local rainbowGrad: UIGradient? = nil
	rOk.MouseButton1Click:Connect(function()
		over.Visible = false
		if welcome then
			welcome = false
			box.close()
			UI.toast("🍒 Your new topping is in your tray: open TOPPINGS and tap your cake!", "pink", 4)
		end
	end)

	local glyphs: { string } = {}
	for _, ids in pairs(Config.BoxPool) do
		for _, id in ipairs(ids) do
			table.insert(glyphs, Config.ToppingById[id].glyph)
		end
	end

	openOne = function()
		if revealing then
			return
		end
		local d = data()
		if not d then
			return
		end
		local free = Own.freeBoxes(d)
		local paid = (d.boxes or 0) - free
		if free <= 0 and paid <= 0 then
			if blocked() then
				UI.toast("🎁 Get free boxes from Daily treats, quests, Index milestones and Celebrity wins!", "orange")
				Sfx.play("error", 0.5)
				return
			elseif (d.coins or 0) < Config.Box.price then
				UI.toast("Need 💰 " .. Config.Box.price .. " or a free box. Win rounds to earn more!", "orange")
				Sfx.play("error", 0.5)
				UI.punch(b1, 0.2)
				return
			end
		end
		revealing = true
		local r = act("box", true)
		if type(r) ~= "table" or not r.ok then
			revealing = false
			result(r)
			return
		end
		if r.swapped then
			revealing = false
			result(r, "cash")
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
		rTitle.Text = if welcome then "🎁 WELCOME GIFT!" else ""
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
			rNote.Text = "Already collected · +" .. tostring(r.refund or 0) .. " 💰"
			Sfx.play("coin", 0.6)
		else
			rNote.Text = "NEW! Added to your tray 🎉"
			Sfx.play("unlock", 0.7)
		end
		local ti = Tiers.index[def.tier] or 1
		if ti >= 3 then
			UI.confetti(40 + ti * 15, { tier.color, tier.dark, Color3.new(1, 1, 1) })
			Sfx.play("magic", 0.7)
		end
		if ti >= 5 then
			UI.flash(tier.color, 0.25)
			UI.shake(0.3)
		end
		rOk.Visible = true
		revealing = false
	end
	openBtn.MouseButton1Click:Connect(openOne)

	refresh(function()
		local d = data()
		local n: number = if d then d.boxes or 0 else 0
		local free = Own.freeBoxes(d)
		local isBlocked = blocked()
		count.Text = if n > 0 then string.format("You have %d box%s!", n, if n == 1 then "" else "es") else "No free boxes · win rounds for more"
		firstNote.Visible = d ~= nil and not d.firstBox
		if free > 0 then
			openBtn.Text = "OPEN FREE BOX!"
		elseif n > 0 then
			openBtn.Text = if isBlocked then "OPEN · → 💰 " .. Config.Box.blockedCoins else "OPEN BOX!"
		else
			openBtn.Text = if isBlocked then "FREE BOXES ONLY" else "OPEN · 💰 " .. Config.Box.price
		end
		UI.recolor(openBtn, if n > 0 or (not isBlocked and d and (d.coins or 0) >= Config.Box.price) then "green" else "grey")
		glyph.Rotation = if n > 0 then 6 else 0
		-- paid random items (Robux boxes, luck) are hidden from players under the paid-random restriction
		luck.Visible = not isBlocked
		b1.Visible = not isBlocked
		b5.Visible = not isBlocked
		b15.Visible = not isBlocked
		luck.Text = "🍀 2.5x Luck 15 min · " .. price("product", "Luck")
		b1.Text = "🎁 1 Box · " .. price("product", "Box1")
		b5.Text = "🎁 5 Boxes · " .. price("product", "Box5")
		b15.Text = "🎁 15 Boxes · " .. price("product", "Box15")
		freeNote.Text = if isBlocked then "🎁 Free boxes: Daily day 7, quests, playtime gifts, Index milestones and Celebrity wins." else ""
		refreshBoxOdds()
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
		UI.text(c, if i == #Config.Daily then "🎁" else "💰", { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0.5, -23, 0, 34) })
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
		claim.Text = if can then "CLAIM 💰 " .. Config.Daily[day] else "⏳ " .. Fmt.time(wait)
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
			elseif ctx.canPrompt() then
				buy("product", "PickTheme")
			else
				UI.toast("🎟️ Get a theme pick with the button below!", "pink")
			end
		end)
	end
	local buyBtn = UI.button(body, "", "pink", { Name = "BuyPick", Size = UDim2.fromOffset(380, 60), Position = UDim2.new(0.5, -190, 1, -70) })
	buyBtn.MouseButton1Click:Connect(function()
		buy("product", "PickTheme")
	end)
	refresh(function()
		local d = data()
		local n: number = if d then d.themeTickets or 0 else 0
		note.Text = if n > 0 then string.format("🎟️ You have %d pick%s! Tap a theme for the next round.", n, if n == 1 then "" else "s") else "Choose the next round's theme for the whole server!"
		buyBtn.Text = "🎟️ BUY A PICK · " .. price("product", "PickTheme")
	end)
	theme.onOpen = function()
		Panels.refresh()
	end
end

-- Caketober prize track -------------------------------------------------------------------------------------
local function buildTrack()
	track = UI.panel("Track", "🎃 " .. string.upper(Config.Track.name), "orange", Vector2.new(900, 540))
	local body = track.body
	local bar = UI.bar(body, "orange", { Size = UDim2.new(0.62, 0, 0, 36), Position = UDim2.fromOffset(0, 18) })
	local ends = dark(UI.text(body, "", { Font = UI.BODY, Size = UDim2.new(0.36, 0, 0, 30), Position = UDim2.new(0.64, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Right }))
	local claimAll = UI.button(body, "CLAIM ALL", "green", { Name = "ClaimAll", Size = UDim2.fromOffset(230, 52), Position = UDim2.fromOffset(0, 64) })
	local passBtn = UI.button(body, "", "orange", { Name = "Pass", Size = UDim2.fromOffset(300, 52), Position = UDim2.fromOffset(242, 64) })
	local giftBtn = UI.button(body, "🎁 GIFT PASS", "pink", { Name = "GiftPass", Size = UDim2.fromOffset(190, 52), Position = UDim2.fromOffset(554, 64) })
	claimAll.MouseButton1Click:Connect(function()
		if result(act("track"), "unlock") then
			UI.confetti(70, { Color3.fromRGB(255, 140, 30), Color3.fromRGB(120, 240, 70), Color3.fromRGB(110, 50, 160) })
		end
	end)
	passBtn.MouseButton1Click:Connect(function()
		if not Own.pass(data(), "Caketober") then
			buy("pass", "Caketober")
		end
	end)
	giftBtn.MouseButton1Click:Connect(function()
		LiveUI.gift("GiftCaketober", "GIFT CAKETOBER PASS")
	end)
	dark(UI.text(body, "FREE", { Size = UDim2.fromOffset(80, 30), Position = UDim2.fromOffset(0, 190) }))
	dark(UI.text(body, "🎃 PASS", { Size = UDim2.fromOffset(80, 30), Position = UDim2.fromOffset(0, 300) }))
	local scroll = UI.scroll(body, {
		Name = "Tiers",
		Size = UDim2.new(1, -86, 0, 284),
		Position = UDim2.fromOffset(86, 124),
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 8,
	})
	trackScroll = scroll
	UI.list(scroll, 8, true, Enum.HorizontalAlignment.Left)
	type Cell = { card: Frame, glyph: TextLabel, text: TextLabel, mark: TextLabel }
	local cols: { { head: TextLabel, free: Cell, premium: Cell } } = {}
	local function cell(parent: Instance, y: number, color: string): Cell
		local c = UI.card(parent, color, { Size = UDim2.fromOffset(112, 104), Position = UDim2.fromOffset(0, y) })
		local g = UI.text(c, "", { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0.5, -23, 0, 6) })
		local t = UI.text(c, "", { Font = UI.BODY, Size = UDim2.new(1, -8, 0, 34), Position = UDim2.fromOffset(4, 54), TextWrapped = true })
		local m = UI.text(c, "", { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -28, 0, -6), ZIndex = c.ZIndex + 2 })
		return { card = c, glyph = g, text = t, mark = m }
	end
	for k = 1, Config.Track.tiers do
		local col = UI.frame(scroll, { Name = "Tier" .. k, BackgroundTransparency = 1, LayoutOrder = k, Size = UDim2.fromOffset(112, 262) })
		local head = dark(UI.text(col, "TIER " .. k, { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 8) }))
		cols[k] = { head = head, free = cell(col, 44, "sky"), premium = cell(col, 154, "orange") }
	end
	local skipRow = UI.frame(body, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 54), Position = UDim2.new(0, 0, 1, -58) })
	UI.list(skipRow, 10, true, Enum.HorizontalAlignment.Left)
	dark(UI.text(skipRow, "SKIP AHEAD:", { Font = UI.BODY, LayoutOrder = 0, Size = UDim2.fromOffset(150, 40) }))
	local skips: { { key: string, btn: TextButton } } = {}
	for i, key in ipairs({ "Track1", "Track5", "Track10" }) do
		local b = UI.button(skipRow, "", "purple", { Name = key, LayoutOrder = i, Size = UDim2.fromOffset(200, 50) })
		b.MouseButton1Click:Connect(function()
			buy("product", key)
		end)
		table.insert(skips, { key = key, btn = b })
	end
	refresh(function()
		local d = data()
		local tier, into = Own.track(d)
		local live = Config.trackLive()
		local premium = Own.pass(d, "Caketober")
		local isBlocked = blocked()
		local t = (d and d.track) or {}
		if tier >= Config.Track.tiers then
			bar.set(1, "TIER " .. tier .. " · MAXED! 🎃")
		else
			bar.set(into / Config.Track.cost, string.format("TIER %d · 🍬 %d / %d", tier, into, Config.Track.cost))
		end
		local left = Config.Track.ends - os.time()
		ends.Text = if live then "⏳ Ends in " .. (if left > 86400 then math.floor(left / 86400) .. " days" else Fmt.time(left)) else "Caketober is over: claim what you earned!"
		passBtn.Visible = live or premium
		passBtn.Text = if premium then "🎃 PASS ✔" else "🎃 GET PASS · " .. price("pass", "Caketober")
		UI.recolor(passBtn, if premium then "grey" else "orange")
		giftBtn.Visible = live
		skipRow.Visible = live
		for _, s in ipairs(skips) do
			s.btn.Text = "+" .. ((Config.TrackSkips :: any)[s.key] or 1) .. " · " .. price("product", s.key)
		end
		for k, c in ipairs(cols) do
			local reached = k <= tier
			for _, which in ipairs({ "free", "premium" }) do
				local isPremium = which == "premium"
				local cl: Cell = if isPremium then c.premium else c.free
				local r = if isPremium then Config.Track.premium[k] else Config.Track.free[k]
				local g, text = Config.rewardText(r, isBlocked)
				cl.glyph.Text = g
				cl.text.Text = text
				local claimed = t[which] ~= nil and t[which][tostring(k)] == true
				local locked = isPremium and not premium
				cl.mark.Text = if claimed then "✔" elseif locked then "🔒" elseif reached then "!" else ""
				cl.card.BackgroundTransparency = if reached or claimed then 0 else 0.45
			end
			c.head.TextColor3 = if reached then Color3.fromRGB(230, 110, 20) else UI.INK
		end
	end)
	track.onOpen = function()
		Panels.refresh()
		local d = data()
		local tier = Own.track(d)
		scroll.CanvasPosition = Vector2.new(math.max(0, (tier - 2) * 120), 0)
	end
end

-- Offers (never in the first 2 minutes of a first session; Main checks ctx.canPrompt) -----------------------
local function offerPanel(name: string, title: string, glyph: string, text: string, priceKey: string, color: string, until_: (() -> number)?): ()
	local old = UI.getPanel(name)
	if old then
		old.frame:Destroy()
	end
	local p = UI.panel(name, title, color, Vector2.new(480, 360))
	local body = p.body
	UI.text(body, glyph, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(110, 110), Position = UDim2.new(0.5, -55, 0, 8) })
	dark(UI.text(body, text, { Font = UI.BODY, Size = UDim2.new(1, 0, 0, 64), Position = UDim2.fromOffset(0, 120), TextWrapped = true }))
	local timer = UI.text(body, "", { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 188), TextColor3 = UI.colors.red })
	local b = UI.button(body, price("product", priceKey), "green", { Size = UDim2.fromOffset(240, 64), Position = UDim2.new(0.5, -120, 1, -72) })
	b.MouseButton1Click:Connect(function()
		p.close()
		buy("product", priceKey)
	end)
	p.open()
	Sfx.play("notify", 0.5)
	if until_ then
		task.spawn(function()
			while p.isOpen() do
				local left = (until_ :: () -> number)()
				if left <= 0 then
					p.close()
					break
				end
				timer.Text = "⏳ Ends in " .. Fmt.time(left)
				task.wait(1)
			end
		end)
	else
		timer.Text = "First purchase only!"
	end
end

function Panels.starterOffer()
	local text = (if blocked() then Config.StarterBlocked.desc else "2,000 coins + 3 Mystery Boxes") .. " · new bakers only!"
	offerPanel("StarterOffer", "BAKER STARTER PACK", "🧁", text, "Starter", "pink", function(): number
		return Own.starterLeft(data())
	end)
end

function Panels.introOffer()
	offerPanel("IntroOffer", "BAKER'S TREAT", "🍰", "2,000 coins + 🧁 Mini Cupcake topping for just " .. price("product", "Intro") .. "!", "Intro", "green", nil)
end

-- The deal button: the starter pack while its window is open, else the intro offer.
function Panels.openDeal()
	local d = data()
	if Own.starterLeft(d) > 0 then
		Panels.starterOffer()
	elseif Own.introOk(d) then
		Panels.introOffer()
	else
		Panels.openShop("Robux")
	end
end

-- The first-minute free gift: opens the welcome box (guaranteed Rare) with a WELCOME GIFT reveal.
function Panels.welcomeGift(): boolean
	local d = data()
	if not d or d.firstBox or Own.freeBoxes(d) <= 0 or revealing then
		return false
	end
	welcome = true
	box.open()
	task.spawn(openOne)
	return true
end

-- API ---------------------------------------------------------------------------------------------------------------
function Panels.refresh()
	for _, fn in ipairs(refreshers) do
		fn()
	end
end

function Panels.update(_d: D)
	if shop.isOpen() or index.isOpen() or box.isOpen() or daily.isOpen() or theme.isOpen() or track.isOpen() then
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

function Panels.openTrack()
	track.open()
end

function Panels.anyOpen(): boolean
	return shop.isOpen() or index.isOpen() or box.isOpen() or daily.isOpen() or theme.isOpen() or track.isOpen()
end

function Panels.init(c: Own.Ctx)
	ctx = c
	buildShop()
	buildIndex()
	buildBox()
	buildDaily()
	buildTheme()
	buildTrack()
	Panels.refresh()
	-- live odds and countdowns: luck timers and server boosts change them without a save push
	task.spawn(function()
		while true do
			task.wait(1)
			if box.isOpen() then
				refreshBoxOdds()
			elseif index.isOpen() then
				refreshIndexOdds()
			elseif shop.isOpen() or track.isOpen() then
				Panels.refresh()
			end
		end
	end)
	player:GetAttributeChangedSignal("RandomBlocked"):Connect(Panels.refresh)
end

return Panels

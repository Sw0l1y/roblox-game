-- The menus: Toy Box (army + mold press), Bags (prices and exact odds), Upgrades, Index, Map, Shop, Daily and the
-- Welcome-back panel. Each panel refreshes in place while open (rows are cached, never rebuilt on every push).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local Fmt = require(Shared:WaitForChild("Fmt"))
local ClientLib = ReplicatedStorage:WaitForChild("ClientLib")
local UI = require(ClientLib:WaitForChild("UI"))
local Sfx = require(ClientLib:WaitForChild("Sfx"))
local State = require(ClientLib:WaitForChild("State"))
local Game = require(ClientLib:WaitForChild("Game"))
local Arena = require(ClientLib:WaitForChild("Arena"))

local Panels = {}

local player = Players.LocalPlayer
type Dict = { [string]: any }

local refreshers: { [string]: () -> () } = {}
local panelObjs: { [string]: UI.Panel } = {}

local function act(action: string, a: any?, b: any?): (boolean, any)
	local ok, msg = Game.act(action, a, b)
	if ok and type(msg) == "string" then
		UI.toast(msg, "green")
	end
	return ok, msg
end
Panels.act = act

local function body(t: string, props: { [string]: any }?): TextLabel
	local l = UI.text(UI.root, t, { Font = UI.BODY, TextColor3 = UI.INK })
	local s = l:FindFirstChildOfClass("UIStroke")
	if s then
		s.Enabled = false
	end
	UI.set(l, props)
	return l
end

local function panel(name: string, title: string, color: any, size: Vector2?): UI.Panel
	local p = UI.panel(name, title, color, size)
	panelObjs[name] = p
	p.onOpen = function()
		local r = refreshers[name]
		if r then
			r()
		end
	end
	return p
end

function Panels.open(name: string)
	local p = panelObjs[name]
	if p then
		p.open()
	end
end

function Panels.toggle(name: string)
	UI.toggle(name)
end

-- Refresh whichever panel is open.
function Panels.refresh()
	for name, p in pairs(panelObjs) do
		if p.isOpen() then
			local r = refreshers[name]
			if r then
				local ok, err = pcall(r)
				if not ok then
					warn("[Panels]", name, err)
				end
			end
		end
	end
end

-- Toy Box: the army and the mold press -----------------------------------------------------------------------------
do
	local p = panel("Army", "🪖 TOY BOX", "green", Vector2.new(700, 520))
	local head = body("", { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 4), TextXAlignment = Enum.TextXAlignment.Left })
	head.Parent = p.body
	local press = UI.frame(p.body, { BackgroundColor3 = Color3.fromRGB(232, 238, 252), Size = UDim2.new(1, 0, 0, 66), Position = UDim2.fromOffset(0, 38) })
	UI.corner(press, 14)
	UI.stroke(press, 2.5)
	local pressText = body("🔀 Mold press: idle. Merge 3 of a kind!", { Size = UDim2.new(1, -180, 0, 28), Position = UDim2.fromOffset(12, 6), TextXAlignment = Enum.TextXAlignment.Left })
	pressText.Parent = press
	local pressBar = UI.bar(press, "purple", { Size = UDim2.new(1, -180, 0, 22), Position = UDim2.fromOffset(12, 36) })
	local skip = UI.button(press, "⏩ SKIP  R$" .. Config.Products.skip.price, "purple", { Size = UDim2.fromOffset(150, 50), Position = UDim2.new(1, -160, 0, 8) })
	skip.MouseButton1Click:Connect(function()
		Game.buy("product", "skip")
	end)
	local list = UI.scroll(p.body, { Size = UDim2.new(1, 0, 1, -114), Position = UDim2.fromOffset(0, 112) })
	UI.list(list, 8)

	type Row = { frame: Frame, name: TextLabel, info: TextLabel, power: TextLabel, merge: TextButton }
	local rows: { [string]: Row } = {}

	local function makeRow(stack: string): Row
		local u, m = Config.split(stack)
		local def = Config.UnitByKey[u]
		local t = Tiers.get(def and def.tier or "Common")
		local f = UI.frame(list, { Size = UDim2.new(1, -8, 0, 76), BackgroundColor3 = UI.WHITE })
		UI.corner(f, 14)
		UI.stroke(f, 2.5, t.dark)
		UI.gradient(f, Color3.fromRGB(255, 255, 255), UI.lighten(t.color, 0.55))
		local icon = UI.frame(f, { BackgroundColor3 = UI.lighten(t.color, 0.3), Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(6, 6) })
		UI.corner(icon, 12)
		Game.viewport(icon, u, m)
		local name = UI.text(f, Game.unitTitle(u, m), { Size = UDim2.new(1, -330, 0, 32), Position = UDim2.fromOffset(80, 6), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.WHITE })
		local st = name:FindFirstChildOfClass("UIStroke")
		if st then
			st.Color = t.dark
		end
		if m == "Rainbow" or t.rainbow then
			UI.rainbow(name)
		end
		local info = body("", { Size = UDim2.new(1, -330, 0, 26), Position = UDim2.fromOffset(80, 42), TextXAlignment = Enum.TextXAlignment.Left })
		info.Parent = f
		local power = body("", { Size = UDim2.fromOffset(110, 30), Position = UDim2.new(1, -250, 0, 22) })
		power.Parent = f
		local merge = UI.button(f, "🔀 MERGE", "orange", { Size = UDim2.fromOffset(124, 54), Position = UDim2.new(1, -132, 0, 11) })
		merge.MouseButton1Click:Connect(function()
			local ok = act("merge", stack)
			if ok then
				Sfx.play("magic", 0.5, 1.2)
			end
		end)
		return { frame = f, name = name, info = info, power = power, merge = merge }
	end

	refreshers.Army = function()
		local d = Game.d()
		if not d then
			return
		end
		local busy = Game.busy()
		head.Text = string.format("🪖 %d / %d soldiers   ·   💪 %s power   ·   squad of %d", Game.count(d), Game.capacity(d), Fmt.num(Game.armyPower(d)), Game.squadSize(d))
		-- mold press
		local m1 = d.merging[1]
		if m1 then
			local u, mu = Config.split(m1.key)
			local left = math.max(0, (m1.done or 0) - Game.now())
			local total = math.max(1, (m1.done or 0) - (m1.start or 0))
			pressText.Text = "🔀 Molding " .. Config.unitName(u, mu) .. "  ·  " .. Fmt.time(left) .. (#d.merging > 1 and ("  (+" .. (#d.merging - 1) .. ")") or "")
			pressBar.set(1 - left / total, "")
			skip.Visible = true
		else
			pressText.Text = "🔀 Mold press ready: merge 3 of a kind into the next toy!" .. (Game.mergeSlots() > 1 and " (x2 press)" or "")
			pressBar.set(0, "")
			skip.Visible = false
		end
		-- rows
		type Entry = { stack: string, power: number }
		local entries: { Entry } = {}
		for stack, n in pairs(d.units) do
			if n > 0 then
				local u, m = Config.split(stack)
				table.insert(entries, { stack = stack, power = Config.power(u, m) })
			end
		end
		table.sort(entries, function(a: Entry, b: Entry)
			return a.power > b.power
		end)
		local seen: { [string]: boolean } = {}
		local mergeable: { [string]: boolean } = {}
		for _, st in ipairs(Game.mergeable(d)) do
			local u = Config.split(st)
			mergeable[u] = true
		end
		for i, e in ipairs(entries) do
			seen[e.stack] = true
			local r = rows[e.stack]
			if not r then
				r = makeRow(e.stack)
				rows[e.stack] = r
			end
			r.frame.LayoutOrder = i
			local n = d.units[e.stack] or 0
			local b = busy[e.stack]
			local parts = { "x" .. n }
			if b and b.out > 0 then
				table.insert(parts, b.out .. " deployed")
			end
			if b and b.rec > 0 then
				table.insert(parts, b.rec .. " getting up")
			end
			r.info.Text = table.concat(parts, "  ·  ")
			r.power.Text = "💪 " .. Fmt.num(e.power)
			local u = Config.split(e.stack)
			r.merge.Visible = mergeable[u] == true and Game.ready(d, e.stack, busy) > 0
		end
		for stack, r in pairs(rows) do
			if not seen[stack] then
				r.frame:Destroy()
				rows[stack] = nil
			end
		end
	end
end

-- Bags: prices, exact odds, free bags --------------------------------------------------------------------------------
do
	local p = panel("Bags", "🎒 BAGS OF SOLDIERS", "orange", Vector2.new(760, 520))
	local luckLine = body("", { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 1, -28) })
	luckLine.Parent = p.body
	local holder = UI.frame(p.body, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -34) })
	UI.list(holder, 12, true)
	type Card = { buy: TextButton, free: TextButton, price: TextLabel, lock: TextLabel }
	local cards: { [string]: Card } = {}
	for i, bag in ipairs(Config.Bags) do
		local c = UI.card(holder, bag.color, { Size = UDim2.fromOffset(170, 440), LayoutOrder = i })
		UI.text(c, bag.glyph, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(70, 70), Position = UDim2.new(0.5, -35, 0, 6) })
		UI.text(c, bag.name, { Size = UDim2.new(1, -12, 0, 30), Position = UDim2.fromOffset(6, 76) })
		local total = 0
		for _, o in ipairs(bag.odds) do
			total += o.weight
		end
		local y = 112
		for _, o in ipairs(bag.odds) do
			local def = Config.UnitByKey[o.key]
			local t = Tiers.get(def and def.tier or "Common")
			local nm = def and def.name or o.key
			if def and def.tier == "Secret" then
				nm = "??? SECRET"
			end
			local l = UI.text(c, nm .. "  " .. Tiers.odds(bag.odds, o), { Font = UI.BODY, Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, y), TextColor3 = UI.lighten(t.color, 0.25), TextXAlignment = Enum.TextXAlignment.Left })
			if t.rainbow then
				UI.rainbow(l)
			end
			y += 23
		end
		local price = UI.text(c, "🧱 " .. Fmt.commas(bag.price), { Size = UDim2.new(1, -12, 0, 30), Position = UDim2.new(0, 6, 1, -150) })
		local lock = UI.text(c, "🔒 " .. Config.Ranks[bag.rank].name, { Font = UI.BODY, Size = UDim2.new(1, -12, 0, 24), Position = UDim2.new(0, 6, 1, -118), TextColor3 = Config.C.yellow })
		local buy = UI.button(c, "BUY", "green", { Size = UDim2.new(1, -16, 0, 48), Position = UDim2.new(0, 8, 1, -114) })
		local free = UI.button(c, "FREE", "pink", { Size = UDim2.new(1, -16, 0, 48), Position = UDim2.new(0, 8, 1, -60) })
		buy.MouseButton1Click:Connect(function()
			act("open", bag.key, false)
		end)
		free.MouseButton1Click:Connect(function()
			act("open", bag.key, true)
		end)
		cards[bag.key] = { buy = buy, free = free, price = price, lock = lock }
	end
	refreshers.Bags = function()
		local d = Game.d()
		if not d then
			return
		end
		local rank = Game.rank()
		for _, bag in ipairs(Config.Bags) do
			local c = cards[bag.key]
			local locked = rank < bag.rank
			c.lock.Visible = locked
			c.buy.Visible = not locked
			c.buy.Text = d.plastic >= bag.price and "BUY" or "NEED 🧱"
			UI.recolor(c.buy, d.plastic >= bag.price and "green" or "grey")
			local n = d.tokens[bag.key] or 0
			c.free.Visible = n > 0
			c.free.Text = "OPEN FREE (" .. n .. ")"
		end
		local luck = 1 + 0.06 * (d.upgrades.lucky or 0)
		local boost = (d.boosts.luck or 0) - Game.now()
		luckLine.Text = "🍀 Bag luck x" .. string.format("%.2f", luck * (boost > 0 and 2 or 1)) .. (boost > 0 and ("  ·  LUCKY BOOST " .. Fmt.time(boost)) or "  ·  Upgrade Lucky Bags in your Toy Box!")
	end
end

-- Upgrades -------------------------------------------------------------------------------------------------------------
do
	local p = panel("Upgrades", "📦 UPGRADES", "blue", Vector2.new(660, 500))
	local list = UI.scroll(p.body)
	UI.list(list, 10)
	type Row = { level: TextLabel, buy: TextButton }
	local rows: { [string]: Row } = {}
	for i, u in ipairs(Config.Upgrades) do
		local f = UI.card(list, "sky", { Size = UDim2.new(1, -8, 0, 74), LayoutOrder = i })
		UI.text(f, u.glyph, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(8, 9) })
		UI.text(f, u.name, { Size = UDim2.new(1, -300, 0, 32), Position = UDim2.fromOffset(72, 6), TextXAlignment = Enum.TextXAlignment.Left })
		local desc = UI.text(f, u.desc, { Font = UI.BODY, Size = UDim2.new(1, -300, 0, 24), Position = UDim2.fromOffset(72, 40), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(230, 244, 255) })
		local level = UI.text(f, "", { Size = UDim2.fromOffset(90, 30), Position = UDim2.new(1, -250, 0, 22) })
		local buy = UI.button(f, "", "green", { Size = UDim2.fromOffset(150, 56), Position = UDim2.new(1, -158, 0, 9) })
		buy.MouseButton1Click:Connect(function()
			local ok = act("upgrade", u.key)
			if ok then
				Sfx.play("unlock", 0.5)
				UI.toast("📦 " .. u.name .. " upgraded!", "blue")
			end
		end)
		rows[u.key] = { level = level, buy = buy }
		local _ = desc
	end
	refreshers.Upgrades = function()
		local d = Game.d()
		if not d then
			return
		end
		for _, u in ipairs(Config.Upgrades) do
			local r = rows[u.key]
			local lvl = d.upgrades[u.key] or 0
			r.level.Text = "Lv " .. lvl .. "/" .. u.max
			if lvl >= u.max then
				r.buy.Text = "MAX ✅"
				UI.recolor(r.buy, "grey")
			else
				local cost = Config.upgradeCost(u.key, lvl)
				r.buy.Text = "🧱 " .. Fmt.num(cost)
				UI.recolor(r.buy, d.plastic >= cost and "green" or "grey")
			end
		end
	end
end

-- Index: every unit and mutation ------------------------------------------------------------------------------------------
do
	local p = panel("Index", "📖 TOY INDEX", "purple", Vector2.new(720, 540))
	local head = body("", { Size = UDim2.new(1, 0, 0, 28) })
	head.Parent = p.body
	local grid = UI.scroll(p.body, { Size = UDim2.new(1, 0, 1, -34), Position = UDim2.fromOffset(0, 34) })
	UI.grid(grid, UDim2.fromOffset(150, 150), 10)
	type Cell = { frame: Frame, found: boolean?, label: TextLabel }
	local cells: { [string]: Cell } = {}
	local variants = { "" }
	for _, m in ipairs(Config.Mutations) do
		table.insert(variants, m.key)
	end
	local order = 0
	for _, def in ipairs(Config.Units) do
		for _, mut in ipairs(variants) do
			order += 1
			local stack = Config.stack(def.key, mut)
			local t = Tiers.get(def.tier)
			local f = UI.frame(grid, { LayoutOrder = order, BackgroundColor3 = UI.WHITE })
			UI.corner(f, 14)
			UI.stroke(f, 2.5, t.dark)
			UI.gradient(f, UI.lighten(t.color, 0.35), t.color)
			local label = UI.text(f, "", { Size = UDim2.new(1, -8, 0, 26), Position = UDim2.new(0, 4, 1, -30), ZIndex = 3 })
			cells[stack] = { frame = f, found = nil, label = label }
		end
	end
	refreshers.Index = function()
		local d = Game.d()
		if not d then
			return
		end
		local found = 0
		for stack, c in pairs(cells) do
			local has = d.index[stack] == true
			if has then
				found += 1
			end
			if c.found ~= has then
				c.found = has
				local old = c.frame:FindFirstChild("Toy")
				if old then
					old:Destroy()
				end
				local u, m = Config.split(stack)
				local def = Config.UnitByKey[u]
				local vf = Game.viewport(c.frame, u, m, { Size = UDim2.new(1, -10, 1, -34), Position = UDim2.fromOffset(5, 4), ZIndex = 2 })
				if not has then
					Game.silhouette(vf)
					c.label.Text = (def and def.tier == "Secret") and "???" or ("❓ " .. Config.unitName(u, m))
				else
					c.label.Text = Config.unitName(u, m)
				end
			end
		end
		head.Text = string.format("Found %d / %d   ·   each new toy gives ⭐ XP", found, order)
	end
end

-- Map: every zone, its owner, deploy and recall -------------------------------------------------------------------------
do
	local p = panel("Map", "🗺️ BATTLE MAP", "teal", Vector2.new(700, 520))
	local list = UI.scroll(p.body)
	UI.list(list, 8)
	type Row = { owner: TextLabel, info: TextLabel, deploy: TextButton, recall: TextButton, frame: Frame }
	local rows: { [string]: Row } = {}
	local order = 0
	for _, def in ipairs(Config.Zones) do
		order += 1
		local f = UI.card(list, def.outpost and "grey" or "dark", { Size = UDim2.new(1, -8, 0, 74), LayoutOrder = def.outpost and 0 or order })
		UI.text(f, def.glyph, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(8, 11) })
		UI.text(f, def.name, { Size = UDim2.new(1, -360, 0, 30), Position = UDim2.fromOffset(68, 6), TextXAlignment = Enum.TextXAlignment.Left })
		local info = UI.text(f, "", { Font = UI.BODY, Size = UDim2.new(1, -360, 0, 24), Position = UDim2.fromOffset(68, 40), TextXAlignment = Enum.TextXAlignment.Left })
		local owner = UI.text(f, "", { Size = UDim2.fromOffset(110, 30), Position = UDim2.new(1, -290, 0, 22) })
		local deploy = UI.button(f, "⚔️ DEPLOY", "red", { Size = UDim2.fromOffset(120, 54), Position = UDim2.new(1, -176, 0, 10) })
		local recall = UI.button(f, "↩️", "blue", { Size = UDim2.fromOffset(48, 54), Position = UDim2.new(1, -52, 0, 10) })
		deploy.MouseButton1Click:Connect(function()
			act("deploy", def.id)
		end)
		recall.MouseButton1Click:Connect(function()
			act("recall", def.id)
		end)
		rows[def.id] = { owner = owner, info = info, deploy = deploy, recall = recall, frame = f }
	end
	refreshers.Map = function()
		local side = Game.side()
		for _, def in ipairs(Config.Zones) do
			local r = rows[def.id]
			if def.outpost then
				r.frame.Visible = def.outpost == side
				r.owner.Text = "DRILL"
				r.owner.TextColor3 = Config.teamColor(side)
				local cd = player:GetAttribute("DrillIn")
				r.info.Text = "Practice vs wind-up toys · " .. ((type(cd) == "number" and cd > 0) and ("ready in " .. cd .. "s") or "ready!")
				r.recall.Visible = false
				r.deploy.Text = "🎯 DRILL"
			else
				local snap = Arena.snapshot(def.id)
				local owner = snap and snap.owner or ""
				local tdef = Config.Team[owner]
				r.owner.Text = tdef and tdef.short or "NEUTRAL"
				r.owner.TextColor3 = tdef and tdef.color or Config.C.wild
				local mine = 0
				local units: { { any } } = snap and snap.units or {}
				for _, u in ipairs(units) do
					if u[6] == player.UserId then
						mine += 1
					end
				end
				local power: number = tonumber(snap and snap.power) or 0
				local fighting: boolean = snap ~= nil and snap.fight == true
				local yours: string = mine > 0 and (" · yours: " .. mine) or ""
				r.info.Text = "💪 " .. Fmt.num(power) .. " · " .. #units .. "/" .. def.cap .. " 🪖 · +" .. def.income .. " 🧱/5s" .. yours .. (fighting and " · ⚔️ BATTLE!" or "")
				r.recall.Visible = mine > 0 and not (snap and snap.fight)
				r.deploy.Text = owner == side and "🛡️ GUARD" or "⚔️ ATTACK"
			end
		end
	end
	Arena.onChange(function()
		if p.isOpen() then
			refreshers.Map()
		end
	end)
end

-- Shop -----------------------------------------------------------------------------------------------------------------------
do
	local p = panel("Shop", "🛒 SHOP", "pink", Vector2.new(780, 540))
	local pages, select = UI.tabs(p.body, { "PASSES", "BOOSTS", "PLASTIC" }, { "purple", "orange", "green" })
	type Item = { kind: string, key: string, btn: TextButton }
	local items: { Item } = {}
	local function grid(page: Frame): ScrollingFrame
		local s = UI.scroll(page)
		UI.grid(s, UDim2.fromOffset(220, 200), 12)
		return s
	end
	local function card(parent: Instance, kind: string, key: string, item: Config.ShopItem, order: number, color: any)
		local c = UI.card(parent, color, { LayoutOrder = order })
		UI.text(c, item.glyph, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(54, 54), Position = UDim2.new(0.5, -27, 0, 4) })
		UI.text(c, item.name, { Size = UDim2.new(1, -12, 0, 28), Position = UDim2.fromOffset(6, 58) })
		UI.text(c, item.desc, { Font = UI.BODY, Size = UDim2.new(1, -14, 0, 52), Position = UDim2.fromOffset(7, 88), TextColor3 = Color3.fromRGB(245, 245, 255) })
		local btn = UI.button(c, "R$ " .. item.price, "green", { Size = UDim2.new(1, -20, 0, 46), Position = UDim2.new(0, 10, 1, -54) })
		btn.MouseButton1Click:Connect(function()
			if kind == "pass" and Game.owns(key) then
				UI.toast("You already own " .. item.name .. "! ✅", "green")
				return
			end
			Game.buy(kind, key)
		end)
		table.insert(items, { kind = kind, key = key, btn = btn })
	end
	local passGrid = grid(pages.PASSES)
	for i, key in ipairs(Config.PassOrder) do
		card(passGrid, "pass", key, Config.Passes[key], i, key == "pro" and "gold" or "purple")
	end
	do -- Roblox Premium perk line
		local c = UI.card(passGrid, "blue", { LayoutOrder = #Config.PassOrder + 1 })
		UI.text(c, "⭐", { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(54, 54), Position = UDim2.new(0.5, -27, 0, 4) })
		UI.text(c, "Roblox Premium", { Size = UDim2.new(1, -12, 0, 28), Position = UDim2.fromOffset(6, 58) })
		UI.text(c, "Premium members get +10% plastic from everything. Thank you!", { Font = UI.BODY, Size = UDim2.new(1, -14, 0, 80), Position = UDim2.fromOffset(7, 92), TextColor3 = Color3.fromRGB(245, 245, 255) })
	end
	local boostGrid = grid(pages.BOOSTS)
	local plasticGrid = grid(pages.PLASTIC)
	for i, key in ipairs(Config.ProductOrder) do
		local isPlastic = string.sub(key, 1, 7) == "plastic"
		card(isPlastic and plasticGrid or boostGrid, "product", key, Config.Products[key], i, key == "callcat" and "pink" or (isPlastic and "green" or "orange"))
	end
	refreshers.Shop = function()
		for _, it in ipairs(items) do
			if it.kind == "pass" then
				local owned = Game.owns(it.key)
				it.btn.Text = owned and "OWNED ✅" or ("R$ " .. Config.Passes[it.key].price)
				UI.recolor(it.btn, owned and "grey" or "green")
			end
		end
	end
	Panels.shopTab = function(tab: string)
		Panels.open("Shop")
		select(tab)
	end
end

-- Daily streak --------------------------------------------------------------------------------------------------------------
do
	local p = panel("Daily", "🎁 DAILY REWARD", "gold", Vector2.new(720, 400))
	local holder = UI.frame(p.body, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 190), Position = UDim2.fromOffset(0, 10) })
	UI.list(holder, 8, true)
	local days: { Frame } = {}
	for i, r in ipairs(Config.Daily) do
		local bag = Config.BagByKey[r.bag]
		local c = UI.card(holder, i == 7 and "gold" or "sky", { Size = UDim2.fromOffset(86, 180), LayoutOrder = i })
		UI.text(c, "DAY " .. i, { Size = UDim2.new(1, -8, 0, 26), Position = UDim2.fromOffset(4, 6) })
		UI.text(c, bag and bag.glyph or "🎒", { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0.5, -23, 0, 36) })
		UI.text(c, "x" .. r.n, { Size = UDim2.new(1, -8, 0, 24), Position = UDim2.fromOffset(4, 84) })
		UI.text(c, "🧱" .. Fmt.num(r.plastic), { Font = UI.BODY, Size = UDim2.new(1, -8, 0, 24), Position = UDim2.fromOffset(4, 112) })
		days[i] = c
	end
	local status = body("", { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 206) })
	status.Parent = p.body
	local claim = UI.button(p.body, "CLAIM!", "green", { Size = UDim2.fromOffset(240, 64), Position = UDim2.new(0.5, -120, 1, -70) })
	claim.MouseButton1Click:Connect(function()
		local ok, streak = Game.act("daily")
		if ok then
			Sfx.play("cash", 0.6)
			UI.confetti(50)
			UI.banner("🎁 DAY " .. tostring(streak) .. " REWARD!", "gold")
			task.delay(0.8, function()
				if p.isOpen() then
					p.close()
				end
			end)
		end
	end)
	refreshers.Daily = function()
		local d = Game.d()
		if not d then
			return
		end
		local today = Config.dayNumber(Game.now())
		local last = d.daily.last or 0
		local ready = last == 0 or today > Config.dayNumber(last)
		local streak = d.daily.streak or 0
		local nextDay = streak
		if ready then
			nextDay = (last > 0 and today == Config.dayNumber(last) + 1) and streak + 1 or 1
		end
		for i, c in ipairs(days) do
			local sel = ((nextDay - 1) % 7 + 1) == i
			c.Size = sel and UDim2.fromOffset(96, 190) or UDim2.fromOffset(86, 180)
		end
		claim.Visible = ready
		status.Text = ready and ("Streak: " .. streak .. " day(s). Claim today's reward!") or ("Come back in " .. Fmt.time((today + 1) * 86400 - Game.now()) .. " for day " .. (streak % 7 + 1) .. "!")
	end
end

-- Welcome back -----------------------------------------------------------------------------------------------------------------
do
	local p = panel("Welcome", "👋 WELCOME BACK!", "green", Vector2.new(520, 330))
	local text = body("", { Size = UDim2.new(1, 0, 0, 120), Position = UDim2.fromOffset(0, 16) })
	text.Parent = p.body
	local collect = UI.button(p.body, "COLLECT 🧱", "green", { Size = UDim2.fromOffset(240, 64), Position = UDim2.new(0.5, -120, 1, -72) })
	collect.MouseButton1Click:Connect(function()
		Sfx.play("cash", 0.6)
		UI.confetti(30)
		p.close()
	end)
	Panels.welcome = function(info: Dict)
		local earned = tonumber(info.offline) or 0
		local away = tonumber(info.away) or 0
		text.Text = "Your Plastic Press kept working for " .. Fmt.time(away) .. " while you were away!\n\n🧱 +" .. Fmt.commas(earned) .. " plastic"
		p.open()
	end
end

State.onChange(function()
	Panels.refresh()
end)
player:GetAttributeChangedSignal("Busy"):Connect(function()
	Panels.refresh()
end)

return Panels

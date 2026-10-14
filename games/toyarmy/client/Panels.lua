-- The menus: Toy Box (army + mold press), Bags (prices and odds in %), Upgrades, Index, Map, Shop (passes, skins,
-- boosts, plastic), Strikes, Daily and the Welcome-back panel. Each panel refreshes in place while open (rows are cached, never rebuilt on every push).
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
local LiveUI = require(ClientLib:WaitForChild("LiveUI"))

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
	local p = panel("Army", "💂 TOY BOX", "green", Vector2.new(700, 520))
	local head = body("", { Size = UDim2.new(0.62, 0, 0, 30), Position = UDim2.fromOffset(0, 4), TextXAlignment = Enum.TextXAlignment.Left })
	head.Parent = p.body
	-- the counter triangle, so "beats" on every card makes sense
	local F, A, R = Config.Classes.Foot, Config.Classes.Air, Config.Classes.Armor
	local legend = body("COUNTERS: " .. F.glyph .. " > " .. A.glyph .. " > " .. R.glyph .. " > " .. F.glyph, { Size = UDim2.new(0.38, 0, 0, 30), Position = UDim2.new(0.62, 0, 0, 4), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(190, 40, 40) })
	legend.Parent = p.body
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
		head.Text = string.format("💂 %d / %d  ·  💪 %s  ·  squad of %d", Game.count(d), Game.capacity(d), Fmt.num(Game.armyPower(d)), Game.squadSize(d))
		skip.Text = "⏩ SKIP  R$" .. Config.Products.skip.price -- live price (Prices.sync)
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
			local u0 = Config.split(e.stack)
			local parts = { "x" .. n, Config.counterText(u0) }
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

-- Bags: prices, odds in % (base and with your luck right now), mutation odds, free bags -------------------------------
-- Under Roblox's paid random item rule a bag bought with plastic gives its fixed reward: the row says exactly what,
-- before the player buys. Free bags still roll, so their odds stay on screen.
do
	local p = panel("Bags", "🎒 BAGS OF SOLDIERS", "orange", Vector2.new(780, 540))
	local luckLine = body("", { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 0) })
	luckLine.Parent = p.body
	local mutLine = body("", { Size = UDim2.new(1, 0, 0, 44), Position = UDim2.new(0, 0, 1, -44), TextWrapped = true })
	mutLine.Parent = p.body
	local list = UI.scroll(p.body, { Size = UDim2.new(1, 0, 1, -78), Position = UDim2.fromOffset(0, 30) })
	UI.list(list, 10)
	local COL = 70
	type Odd = { base: TextLabel, live: TextLabel }
	type Row = { buy: TextButton, free: TextButton, price: TextLabel, lock: TextLabel, odds: { Odd }, fixed: TextLabel, oddsHead: TextLabel }
	local rows: { [string]: Row } = {}
	for i, bag in ipairs(Config.Bags) do
		local r = UI.card(list, bag.color, { Size = UDim2.new(1, -12, 0, 156), LayoutOrder = i })
		UI.text(r, bag.glyph, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(8, 6) })
		UI.text(r, bag.name, { Size = UDim2.fromOffset(150, 30), Position = UDim2.fromOffset(54, 10), TextXAlignment = Enum.TextXAlignment.Left })
		local price = UI.text(r, "🧱 " .. Fmt.commas(bag.price), { Size = UDim2.fromOffset(190, 26), Position = UDim2.fromOffset(8, 50) })
		local lock = UI.text(r, "🔒 " .. Config.Ranks[bag.rank].name, { Font = UI.BODY, Size = UDim2.fromOffset(190, 34), Position = UDim2.fromOffset(8, 80), TextColor3 = Config.C.yellow })
		local buy = UI.button(r, "BUY", "green", { Size = UDim2.fromOffset(184, 34), Position = UDim2.fromOffset(10, 78) })
		local free = UI.button(r, "FREE", "pink", { Size = UDim2.fromOffset(184, 34), Position = UDim2.fromOffset(10, 116) })
		buy.MouseButton1Click:Connect(function()
			act("open", bag.key, false)
		end)
		free.MouseButton1Click:Connect(function()
			act("open", bag.key, true)
		end)
		local oddsHead = UI.text(r, "", { Font = UI.BODY, Size = UDim2.new(1, -212, 0, 20), Position = UDim2.fromOffset(204, 4), TextXAlignment = Enum.TextXAlignment.Left })
		local odds: { Odd } = {}
		for j, o in ipairs(bag.odds) do
			local def = Config.UnitByKey[o.key]
			local t = Tiers.get(def and def.tier or "Common")
			local col = UI.frame(r, { BackgroundColor3 = UI.WHITE, Size = UDim2.fromOffset(COL - 6, 100), Position = UDim2.fromOffset(204 + (j - 1) * COL, 28) })
			UI.corner(col, 10)
			UI.stroke(col, 2, t.dark)
			UI.gradient(col, UI.lighten(t.color, 0.55), UI.lighten(t.color, 0.2))
			local secret = def ~= nil and def.tier == "Secret"
			local nm = secret and "??? SECRET" or ((def and def.glyph or "") .. " " .. (def and def.name or o.key))
			local name = body(nm, { Size = UDim2.new(1, -6, 0, 34), Position = UDim2.fromOffset(3, 3), TextWrapped = true })
			name.Parent = col
			if secret then
				UI.rainbow(name)
			end
			local base = body("", { Size = UDim2.new(1, -6, 0, 26), Position = UDim2.fromOffset(3, 40) })
			base.Parent = col
			local live = body("", { Size = UDim2.new(1, -6, 0, 26), Position = UDim2.fromOffset(3, 70), TextColor3 = Color3.fromRGB(20, 130, 40) })
			live.Parent = col
			-- its counter class (💂 / 🚁 / 🛡️), like on every other unit card
			UI.text(col, Config.classOf(o.key).glyph, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(-6, -6), ZIndex = 4 })
			odds[j] = { base = base, live = live }
		end
		local fixed = UI.text(r, "", { Font = UI.BODY, Size = UDim2.new(1, -212, 0, 22), Position = UDim2.new(0, 204, 1, -25), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Config.C.yellow })
		rows[bag.key] = { buy = buy, free = free, price = price, lock = lock, odds = odds, fixed = fixed, oddsHead = oddsHead }
	end
	refreshers.Bags = function()
		local d = Game.d()
		if not d then
			return
		end
		local rank = Game.rank()
		local luck, mutMult = Game.luck(d)
		local blocked = Game.randomBlocked()
		for _, bag in ipairs(Config.Bags) do
			local r = rows[bag.key]
			local locked = rank < bag.rank
			r.lock.Visible = locked
			r.buy.Visible = not locked
			local can = d.plastic >= bag.price
			r.buy.Text = can and (blocked and "BUY (FIXED)" or "BUY") or "NEED 🧱"
			UI.recolor(r.buy, can and "green" or "grey")
			local n = d.tokens[bag.key] or 0
			r.free.Visible = n > 0
			r.free.Text = "OPEN FREE (" .. n .. ")"
			r.oddsHead.Text = (blocked and "FREE bag odds" or "Odds per toy") .. (luck ~= 1 and "  ·  🍀 with your luck now" or "")
			local base = Tiers.percents(bag.odds)
			local boosted = Tiers.percents(bag.odds, luck)
			for j, o in ipairs(r.odds) do
				o.base.Text = Tiers.pct(base[j])
				o.live.Text = luck ~= 1 and ("🍀 " .. Tiers.pct(boosted[j])) or ""
			end
			r.fixed.Text = blocked and ("🧱 BUY gives exactly: " .. Config.fixedText(bag)) or ""
		end
		local own = (d.boosts.luck or 0) - Game.now()
		local server = Game.serverBoost("luck")
		local parts = { "🍀 Bag luck x" .. string.format("%.2f", luck) .. " (Lucky Bags Lv " .. (d.upgrades.lucky or 0) .. ")" }
		if own > 0 then
			table.insert(parts, "LUCKY BOOST x2 " .. Fmt.time(own))
		end
		if server > 1 then
			table.insert(parts, "⚡ SERVER LUCK x" .. server)
		end
		luckLine.Text = table.concat(parts, "  ·  ")
		-- mutations: one roll per toy, rarest first (the % add up to 100)
		local mo = Config.mutOdds(1)
		local ml = Config.mutOdds(mutMult)
		local mb, mlv = Tiers.percents(mo), Tiers.percents(ml)
		local bits = {}
		for j, e in ipairs(mo) do
			local m = Config.MutByKey[e.key]
			local label = m and (m.glyph .. " " .. m.name) or "none"
			local txt = label .. " " .. Tiers.pct(mb[j])
			if mutMult ~= 1 then
				txt ..= " → " .. Tiers.pct(mlv[j])
			end
			table.insert(bits, txt)
		end
		mutLine.Text = "Each toy can mutate" .. (blocked and " (free bags)" or "") .. ": " .. table.concat(bits, "  ·  ")
	end
	-- boosts run out while the panel is open: keep the % live
	task.spawn(function()
		while true do
			task.wait(1)
			if p.isOpen() then
				refreshers.Bags()
			end
		end
	end)
	player:GetAttributeChangedSignal("RandomBlocked"):Connect(function()
		if p.isOpen() then
			refreshers.Bags()
		end
	end)
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
	type Cell = { frame: Frame, found: boolean?, label: TextLabel, odds: TextLabel, unit: string, mut: string }
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
			UI.text(f, Config.classOf(def.key).glyph, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(4, 4), ZIndex = 4 })
			-- drop chance: the best bag for this toy (per toy, with the player's luck now), or the mutation's chance
			local odds = UI.text(f, "", { Size = UDim2.fromOffset(104, 22), Position = UDim2.new(1, -108, 0, 6), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4 })
			cells[stack] = { frame = f, found = nil, label = label, odds = odds, unit = def.key, mut = mut }
		end
	end
	refreshers.Index = function()
		local d = Game.d()
		if not d then
			return
		end
		local found = 0
		local luck, mutMult = Game.luck(d)
		local best: { [string]: { pct: number, glyph: string } } = {}
		for _, bag in ipairs(Config.Bags) do
			local pcts = Tiers.percents(bag.odds, luck)
			for j, e in ipairs(bag.odds) do
				local b = best[e.key]
				if not b or pcts[j] > b.pct then
					best[e.key] = { pct = pcts[j], glyph = bag.glyph }
				end
			end
		end
		local mo = Config.mutOdds(mutMult)
		local mp = Tiers.percents(mo)
		local mutPct: { [string]: number } = {}
		for j, e in ipairs(mo) do
			mutPct[e.key] = mp[j]
		end
		for _, c in pairs(cells) do
			if c.mut ~= "" then
				local m = Config.MutByKey[c.mut]
				c.odds.Text = (m and m.glyph or "✨") .. " " .. Tiers.pct(mutPct[c.mut] or 0)
			else
				local b = best[c.unit]
				c.odds.Text = b and (b.glyph .. " " .. Tiers.pct(b.pct)) or "🔀 MERGE"
			end
		end
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
				local vf = Game.viewport(c.frame, u, m, { Size = UDim2.new(1, -10, 1, -34), Position = UDim2.fromOffset(5, 4), ZIndex = 2, plain = true })
				if not has then
					Game.silhouette(vf)
					c.label.Text = (def and def.tier == "Secret") and "???" or ("❓ " .. Config.unitName(u, m))
				else
					c.label.Text = Config.unitName(u, m)
				end
			end
		end
		head.Text = string.format("Found %d / %d   ·   each new toy gives ⭐ XP   ·   %% = best bag per toy%s", found, order, luck ~= 1 and " (🍀 your luck)" or "")
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
				r.info.Text = "💪 " .. Fmt.num(power) .. " · " .. #units .. "/" .. def.cap .. " 💂 · +" .. def.income .. " 🧱/5s" .. yours .. (fighting and " · ⚔️ BATTLE!" or "")
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

-- Shop: passes (each with a 🎁 gift button), army skins, boosts and plastic. Prices are Roblox's live prices (kit
-- Prices): every refresh re-reads item.price. Random items are hidden under the paid random item rule.
do
	local p = panel("Shop", "🛒 SHOP", "pink", Vector2.new(800, 560))
	local pages, select = UI.tabs(p.body, { "PASSES", "SKINS", "BOOSTS", "PLASTIC" }, { "purple", "orange", "green", "teal" })
	type Item = { kind: string, key: string, btn: TextButton, card: Frame, desc: TextLabel? }
	local items: { Item } = {}
	local function grid(page: Frame): ScrollingFrame
		local sc = UI.scroll(page)
		UI.grid(sc, UDim2.fromOffset(224, 212), 12)
		return sc
	end
	local function giftButton(c: Frame, passKey: string)
		local giftKey = Config.GiftOf[passKey]
		if not giftKey then
			return
		end
		local g = UI.button(c, "🎁", "pink", { Size = UDim2.fromOffset(48, 44), Position = UDim2.new(1, -54, 0, 6), ZIndex = c.ZIndex + 3 })
		g.Name = "GiftButton"
		g.MouseButton1Click:Connect(function()
			LiveUI.gift(giftKey, "GIFT " .. string.upper(Config.Passes[passKey].name))
		end)
	end
	local function card(parent: Instance, kind: string, key: string, item: Config.ShopItem, order: number, color: any): Item
		local c = UI.card(parent, color, { LayoutOrder = order })
		UI.text(c, item.glyph, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(54, 54), Position = UDim2.new(0.5, -27, 0, 4) })
		UI.text(c, item.name, { Size = UDim2.new(1, -12, 0, 28), Position = UDim2.fromOffset(6, 58) })
		local desc = UI.text(c, item.desc, { Font = UI.BODY, Size = UDim2.new(1, -14, 0, 60), Position = UDim2.fromOffset(7, 88), TextColor3 = Color3.fromRGB(245, 245, 255), TextWrapped = true })
		local btn = UI.button(c, "R$ " .. item.price, "green", { Size = UDim2.new(1, -20, 0, 46), Position = UDim2.new(0, 10, 1, -54) })
		btn.MouseButton1Click:Connect(function()
			if kind == "pass" and Game.owns(key) then
				UI.toast("You already own " .. item.name .. "! ✅", "green")
				return
			end
			Game.buy(kind, key)
		end)
		if kind == "pass" then
			giftButton(c, key)
		end
		local it: Item = { kind = kind, key = key, btn = btn, card = c, desc = desc }
		table.insert(items, it)
		return it
	end
	-- PASSES
	local passGrid = grid(pages.PASSES)
	for i, key in ipairs(Config.PassOrder) do
		card(passGrid, "pass", key, Config.Passes[key], i, key == "pro" and "gold" or "purple")
	end
	do -- Roblox Premium perk line
		local c = UI.card(passGrid, "blue", { LayoutOrder = #Config.PassOrder + 1 })
		UI.text(c, "⭐", { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(54, 54), Position = UDim2.new(0.5, -27, 0, 4) })
		UI.text(c, "Roblox Premium", { Size = UDim2.new(1, -12, 0, 28), Position = UDim2.fromOffset(6, 58) })
		UI.text(c, "Premium members get +10% plastic from everything. Thank you!", { Font = UI.BODY, Size = UDim2.new(1, -14, 0, 80), Position = UDim2.fromOffset(7, 92), TextColor3 = Color3.fromRGB(245, 245, 255), TextWrapped = true })
	end
	-- SKINS: a live preview of your soldier (or tank) in the skin, BUY / EQUIP, and a gift button
	type SkinCard = { key: string, btn: TextButton }
	local skinCards: { SkinCard } = {}
	local skinGrid = grid(pages.SKINS)
	for i, key in ipairs(Config.SkinOrder) do
		local item = Config.Passes[key]
		local sk = Config.Skins[key]
		local c = UI.card(skinGrid, key == "skinPumpkin" and "orange" or (key == "skinGold" and "gold" or "dark"), { LayoutOrder = i })
		local view = UI.frame(c, { BackgroundTransparency = 1, Size = UDim2.new(1, -60, 0, 92), Position = UDim2.fromOffset(6, 4) })
		Game.viewport(view, sk.kind == "tank" and "Tank" or "Rifleman", "", { skin = key })
		UI.text(c, item.glyph .. " " .. item.name, { Size = UDim2.new(1, -12, 0, 28), Position = UDim2.fromOffset(6, 98) })
		UI.text(c, item.desc, { Font = UI.BODY, Size = UDim2.new(1, -14, 0, 46), Position = UDim2.fromOffset(7, 126), TextColor3 = Color3.fromRGB(245, 245, 255), TextWrapped = true })
		local btn = UI.button(c, "R$ " .. item.price, "green", { Size = UDim2.new(1, -20, 0, 40), Position = UDim2.new(0, 10, 1, -46) })
		btn.MouseButton1Click:Connect(function()
			local d = Game.d()
			if not Game.owns(key) then
				Game.buy("pass", key)
			elseif d and (d.skin == key or d.tankPaint == key) then
				act("skin", sk.kind == "tank" and key or "") -- the tank paint toggles off; an army skin goes back to plain
			else
				local ok = act("skin", key)
				if ok then
					Sfx.play("magic", 0.5, 1.2)
					UI.toast(item.glyph .. " " .. item.name .. " equipped!", "orange")
				end
			end
		end)
		giftButton(c, key)
		table.insert(skinCards, { key = key, btn = btn })
	end
	-- BOOSTS and PLASTIC
	local boostGrid = grid(pages.BOOSTS)
	for i, key in ipairs(Config.BoostOrder) do
		card(boostGrid, "product", key, Config.Products[key], i, (key == "intro" or key == "starter") and "pink" or "orange")
	end
	local plasticGrid = grid(pages.PLASTIC)
	for i, key in ipairs(Config.PlasticOrder) do
		card(plasticGrid, "product", key, Config.Products[key], i, key == "plasticFirst" and "pink" or "green")
	end
	refreshers.Shop = function()
		local d = Game.d()
		if not d then
			return
		end
		local blocked = Game.randomBlocked()
		local rank = Game.rank()
		local bought: { [string]: any } = d.bought or {}
		for _, it in ipairs(items) do
			if it.kind == "pass" then
				local item = Config.Passes[it.key]
				local owned = Game.owns(it.key)
				it.btn.Text = owned and "OWNED ✅" or ("R$ " .. item.price)
				UI.recolor(it.btn, owned and "grey" or "green")
			else
				local item = Config.Products[it.key]
				local show = not (blocked and item.random)
				if it.key == "intro" then
					show = Game.neverBought(d)
				elseif it.key == "starter" then
					show = Game.starterLeft(d) > 0
					local desc = it.desc
					if desc then
						desc.Text = item.desc .. " Ends in " .. Fmt.time(Game.starterLeft(d)) .. "!"
					end
				elseif item.once and bought[it.key] then
					show = false
				end
				it.card.Visible = show
				local b: { [string]: any } = item.boost or {}
				local needs = tonumber(b.needs)
				if needs and Game.serverBoost(tostring(b.kind)) < needs then
					it.btn.Text = "NEEDS " .. needs .. "x ON"
					UI.recolor(it.btn, "grey")
				else
					it.btn.Text = "R$ " .. item.price
					UI.recolor(it.btn, "green")
				end
				if item.base and it.desc then
					it.desc.Text = "🧱 " .. Fmt.commas(math.floor(item.base * Config.rankReward(rank))) .. " plastic at your rank" .. (it.key == "plasticFirst" and " (40% OFF, once!)" or "")
				end
			end
		end
		for _, sc in ipairs(skinCards) do
			local item = Config.Passes[sc.key]
			if not Game.owns(sc.key) then
				sc.btn.Text = "R$ " .. item.price
				UI.recolor(sc.btn, "green")
			elseif d.skin == sc.key or d.tankPaint == sc.key then
				sc.btn.Text = "EQUIPPED ✅"
				UI.recolor(sc.btn, "grey")
			else
				sc.btn.Text = "EQUIP"
				UI.recolor(sc.btn, "blue")
			end
		end
	end
	Panels.shopTab = function(tab: string)
		Panels.open("Shop")
		select(tab)
	end
	task.spawn(function() -- the Starter Pack countdown and boost locks tick while the shop is open
		while true do
			task.wait(1)
			if p.isOpen() then
				refreshers.Shop()
			end
		end
	end)
end

-- Strikes: pick an enemy zone, then a strike. The server hits it (Strikes.lua) and every client sees it land.
do
	local p = panel("Strikes", "💥 STRIKES", "red", Vector2.new(800, 560))
	local hint = body("Pick a target, then a strike. The whole server sees your name!", { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 0) })
	hint.Parent = p.body
	local targets = UI.frame(p.body, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 70), Position = UDim2.fromOffset(0, 30) })
	UI.list(targets, 10, true)
	local none = body("Your army holds every zone! Strikes you buy now are saved for later.", { Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 34), TextWrapped = true })
	none.Parent = p.body
	local gridFrame = UI.scroll(p.body, { Size = UDim2.new(1, 0, 1, -110), Position = UDim2.fromOffset(0, 108) })
	UI.grid(gridFrame, UDim2.fromOffset(176, 176), 10)
	local selected: string? = nil
	type ZoneBtn = { btn: TextButton, def: Config.ZoneDef }
	local zoneBtns: { [string]: ZoneBtn } = {}
	for i, def in ipairs(Config.Zones) do
		if not def.outpost then
			local b = UI.button(targets, def.glyph .. " " .. def.name, "dark", { Size = UDim2.fromOffset(140, 60), LayoutOrder = i })
			b.Name = "Target_" .. def.id
			b.MouseButton1Click:Connect(function()
				selected = def.id
				Sfx.play("click", 0.4)
				refreshers.Strikes()
			end)
			zoneBtns[def.id] = { btn = b, def = def }
		end
	end
	type StrikeCard = { key: string, btn: TextButton }
	local cards: { StrikeCard } = {}
	for i, key in ipairs(Config.StrikeOrder) do
		local item = Config.Products[key]
		local def = Config.Strikes[key]
		local c = UI.card(gridFrame, key == "dog" and "gold" or (key == "callcat" and "pink" or "red"), { LayoutOrder = i })
		UI.text(c, item.glyph, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(50, 50), Position = UDim2.new(0.5, -25, 0, 4) })
		UI.text(c, item.name, { Size = UDim2.new(1, -10, 0, 26), Position = UDim2.fromOffset(5, 54) })
		UI.text(c, def.line, { Font = UI.BODY, Size = UDim2.new(1, -12, 0, 42), Position = UDim2.fromOffset(6, 82), TextColor3 = Color3.fromRGB(245, 245, 255), TextWrapped = true })
		local btn = UI.button(c, "R$ " .. item.price, "green", { Size = UDim2.new(1, -16, 0, 42), Position = UDim2.new(0, 8, 1, -48) })
		btn.MouseButton1Click:Connect(function()
			local d = Game.d()
			local saved: { [string]: number } = d and d.strikeCredits or {}
			local credits = saved[key] or 0
			if key ~= "callcat" and key ~= "dog" and selected == nil then
				UI.toast("Pick a target zone first! 🎯", "orange")
				return
			end
			if credits > 0 then
				local ok = act("strike", key, selected)
				if ok then
					p.close()
				end
				return
			end
			if selected then
				Game.act("aim", selected)
			end
			Game.buy("product", key)
		end)
		table.insert(cards, { key = key, btn = btn })
	end
	refreshers.Strikes = function()
		local d = Game.d()
		if not d then
			return
		end
		local side = Game.side()
		local any = false
		local best, bestPower = nil :: string?, -1
		for id, zb in pairs(zoneBtns) do
			local snap = Arena.snapshot(id)
			local owner = snap and snap.owner or ""
			local units = snap and snap.units or {}
			local enemyHeld = owner ~= side and (#units > 0 or (snap ~= nil and snap.fight == true))
			zb.btn.Visible = enemyHeld
			if enemyHeld then
				any = true
				local power = tonumber(snap and snap.power) or 0
				local tdef = Config.Team[owner]
				zb.btn.Text = zb.def.glyph .. " " .. zb.def.name .. "\n" .. (tdef and tdef.short or "WIND-UP") .. " 💪" .. Fmt.num(power)
				UI.recolor(zb.btn, selected == id and "yellow" or (tdef and "red" or "grey"))
				local score = power + (tdef and 1e7 or 0)
				if score > bestPower then
					best, bestPower = id, score
				end
			end
		end
		if selected and not (zoneBtns[selected] and zoneBtns[selected].btn.Visible) then
			selected = nil
		end
		if not selected and best then
			selected = best
			UI.recolor(zoneBtns[best].btn, "yellow")
		end
		none.Visible = not any
		for _, c in ipairs(cards) do
			local credits = d.strikeCredits and d.strikeCredits[c.key] or 0
			c.btn.Text = credits > 0 and ("USE FREE (" .. credits .. ")") or ("R$ " .. Config.Products[c.key].price)
			UI.recolor(c.btn, credits > 0 and "pink" or "green")
		end
	end
	Arena.onChange(function()
		if p.isOpen() then
			refreshers.Strikes()
		end
	end)
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

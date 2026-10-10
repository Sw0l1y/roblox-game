--!strict
-- HUD and menus: top counters (coins, wins, index), the phase/timer pill, the next-goal pill with a
-- pointing arrow and a world beam to the right machine, the left menu (Marbles, Packs, Shine, League,
-- Shop) and right column (Daily, Grand Prix timer, Luck, 2x, mute), plus every panel: collection with
-- levels/stat points/tune-ups, the index, packs with numeric odds, the Shine Machine, the daily league,
-- the shop (passes, boosts, coins, trails) and the 7-day daily reward.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local Fmt = require(Shared:WaitForChild("Fmt"))
local ClientLib = ReplicatedStorage:WaitForChild("ClientLib")
local UI = require(ClientLib:WaitForChild("UI"))
local Sfx = require(ClientLib:WaitForChild("Sfx"))
local State = require(ClientLib:WaitForChild("State"))
local MarbleIcon = require(ClientLib:WaitForChild("MarbleIcon"))
local Reveal = require(ClientLib:WaitForChild("Reveal"))

local Hud = {}

local player = Players.LocalPlayer
local I = Config.Icons
local buyRemote = Net.event("Buy")
local upgradeRemote = Net.event("Upgrade")
local tuneRemote = Net.event("TuneUp")
local dailyRemote = Net.event("ClaimDaily")
local leagueRemote = Net.event("ClaimLeague")
local trailRemote = Net.event("SetTrail")
local favRemote = Net.event("Favorite")
local openPackFunc = Net.func("OpenPack")
local shineFunc = Net.func("Shine")

local root = UI.root
local data: { [string]: any } = {}
local sessionStart = os.clock()

local function now(): number
	return workspace:GetServerTimeNow()
end

local function today(): number
	return math.floor(os.time() / 86400)
end

local function noStroke(l: TextLabel)
	local s = l:FindFirstChildOfClass("UIStroke")
	if s then
		s.Enabled = false
	end
end

local function body(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local l = UI.text(parent, text, props)
	l.Font = UI.BODY
	l.TextColor3 = UI.INK
	noStroke(l)
	return l
end

local function clearKids(f: Instance)
	for _, c in ipairs(f:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function owns(pass: string): boolean
	local p = data.passes
	return type(p) == "table" and p[pass] == true
end

-- Effective stats of an owned marble entry (mirrors the server's Economy.stats).
local function stats(e: { [string]: any }): (number, number, number)
	local def = Config.MarbleById[tostring(e.id)] or Config.Marbles[1]
	local k = Config.Level.statPerPoint
	local cap = Config.Level.statCap
	return math.min(cap, def.spd + (e.spd or 0) * k), math.min(cap, def.grip + (e.grip or 0) * k), math.min(cap, def.wt + (e.wt or 0) * k)
end

local function power(e: { [string]: any }): number
	local s, g, w = stats(e)
	return s * 1.6 + g + w * 0.6
end

local function indexCount(): number
	local n = 0
	for k in pairs(data.index or {}) do
		if not string.find(tostring(k), ":") then
			n += 1
		end
	end
	return n
end

local function freePacks(): number
	local n = 0
	for _, v in pairs(data.packs or {}) do
		n += tonumber(v) or 0
	end
	return n
end

local function dailyReady(): boolean
	local d = data.daily
	return type(d) == "table" and d.last ~= today()
end

local function leaguePts(): number
	local l = data.league
	if type(l) == "table" and l.day == today() then
		return tonumber(l.pts) or 0
	end
	return 0
end

local function leagueClaimable(): number
	local n = 0
	local l = data.league
	local claimed = type(l) == "table" and l.day == today() and l.claimed or {}
	for i, t in ipairs(Config.League.tiers) do
		if leaguePts() >= t.pts and not claimed[tostring(i)] then
			n += 1
		end
	end
	return n
end

local function pointsLeft(): number
	local n = 0
	for _, e in pairs(data.marbles or {}) do
		n += tonumber((e :: any).pts) or 0
	end
	return n
end

-- Top bar ---------------------------------------------------------------------------------------------------
local top = UI.frame(root, { Name = "Top", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(900, 56) })
UI.list(top, 12, true)
local statusPill = UI.frame(top, { Size = UDim2.fromOffset(280, 52), LayoutOrder = 0 })
UI.corner(statusPill, 26)
UI.stroke(statusPill, 3.5)
local statusGrad = UI.gradient(statusPill, UI.shade(UI.colors.pink, 0.75), UI.shade(UI.colors.pink, 0.45))
local statusText = UI.text(statusPill, "", { Size = UDim2.new(1, -24, 0.72, 0), Position = UDim2.new(0, 12, 0.14, 0), ZIndex = 3 })
local coins = UI.counter(top, I.coins, "gold", Fmt.num, { LayoutOrder = 1, Size = UDim2.fromOffset(220, 52) })
local wins = UI.counter(top, I.trophy, "orange", function(n: number): string
	return Fmt.num(n)
end, { LayoutOrder = 2, Size = UDim2.fromOffset(150, 52) })
local indexCounter = UI.counter(top, I.marble, "purple", function(n: number): string
	return string.format("%d/%d", math.floor(n), #Config.Marbles)
end, { LayoutOrder = 3, Size = UDim2.fromOffset(170, 52) })

-- Next goal pill (top left, under the Roblox buttons)
local goalPill = UI.frame(root, { Name = "Goal", Position = UDim2.fromOffset(16, 112), Size = UDim2.fromOffset(430, 44), Visible = false })
UI.corner(goalPill, 18)
UI.stroke(goalPill, 3)
UI.gradient(goalPill, UI.shade(UI.colors.teal, 0.6), UI.shade(UI.colors.teal, 0.38))
local goalText = UI.text(goalPill, "", { Size = UDim2.new(1, -20, 0.72, 0), Position = UDim2.new(0, 10, 0.14, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 })

-- Left menu
local left = UI.frame(root, { Name = "Menu", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 40), Size = UDim2.fromOffset(84, 470) })
UI.list(left, 12)
local bMarbles = UI.iconButton(left, I.marbles, "Marbles", "purple", { LayoutOrder = 1 })
local bPacks = UI.iconButton(left, I.pack, "Packs", "green", { LayoutOrder = 2 })
local bShine = UI.iconButton(left, I.shine, "Shine", "gold", { LayoutOrder = 3 })
local bLeague = UI.iconButton(left, I.league, "League", "sky", { LayoutOrder = 4 })
local bShop = UI.iconButton(left, I.shop, "Shop", "pink", { LayoutOrder = 5 })

-- Right column
local rightCol = UI.frame(root, { Name = "Side", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.42, 0), Size = UDim2.fromOffset(84, 420) })
UI.list(rightCol, 12)
local bDaily = UI.iconButton(rightCol, I.daily, "Daily", "orange", { LayoutOrder = 1 })
local bGp = UI.iconButton(rightCol, I.gp, "GP", "purple", { LayoutOrder = 2 })
local bLuck = UI.iconButton(rightCol, I.luck, "Luck", "green", { LayoutOrder = 3 })
local bX2 = UI.iconButton(rightCol, I.x2, "2x", "gold", { LayoutOrder = 4 })
local bMute = UI.iconButton(rightCol, I.music, "Music", "teal", { LayoutOrder = 5 })
bLuck.button.Visible = false

-- Panels ------------------------------------------------------------------------------------------------------
local pMarbles = UI.panel("Marbles", "MY MARBLES", "purple", Vector2.new(820, 520))
local pPacks = UI.panel("Packs", "MARBLE PACKS", "green", Vector2.new(940, 500))
local pShine = UI.panel("Shine", "SHINE MACHINE", "gold", Vector2.new(780, 500))
local pLeague = UI.panel("League", "DAILY LEAGUE", "sky", Vector2.new(820, 500))
local pShop = UI.panel("Shop", "SHOP", "pink", Vector2.new(860, 520))
local pDaily = UI.panel("Daily", "DAILY REWARD", "orange", Vector2.new(700, 380))
local pWelcome = UI.panel("Welcome", "WELCOME BACK!", "teal", Vector2.new(480, 320))

bMarbles.button.MouseButton1Click:Connect(function()
	UI.toggle("Marbles")
end)
bPacks.button.MouseButton1Click:Connect(function()
	UI.toggle("Packs")
end)
bShine.button.MouseButton1Click:Connect(function()
	UI.toggle("Shine")
end)
bLeague.button.MouseButton1Click:Connect(function()
	UI.toggle("League")
end)
bShop.button.MouseButton1Click:Connect(function()
	UI.toggle("Shop")
end)
bDaily.button.MouseButton1Click:Connect(function()
	UI.toggle("Daily")
end)
bGp.button.MouseButton1Click:Connect(function()
	UI.toggle("League")
end)
bLuck.button.MouseButton1Click:Connect(function()
	UI.toggle("Packs")
end)
bX2.button.MouseButton1Click:Connect(function()
	UI.toggle("Shop")
end)
bMute.button.MouseButton1Click:Connect(function()
	local m = not Sfx.isMuted()
	Sfx.setMuted(m)
	local icon = bMute.icon :: any
	icon.Text = m and I.mute or I.music
	bMute.label.Text = m and "Muted" or "Music"
end)

local function buy(kind: string, key: string)
	buyRemote:FireServer(kind, key)
	Sfx.play("purchase", 0.4)
end

-- Marbles panel ------------------------------------------------------------------------------------------------
local mPages, mSelect = UI.tabs(pMarbles.body, { "Collection", "Index" }, { "purple", "blue" })
local collGrid = UI.scroll(mPages.Collection, { Size = UDim2.new(0, 470, 1, 0) })
UI.grid(collGrid, UDim2.fromOffset(104, 128), 8)
local detail = UI.frame(mPages.Collection, { BackgroundTransparency = 1, Size = UDim2.new(1, -486, 1, 0), Position = UDim2.new(0, 486, 0, 0) })
local selectedKey = ""
local refreshMarbles: () -> ()

local function sortedKeys(): { string }
	local keys: { string } = {}
	for k in pairs(data.marbles or {}) do
		table.insert(keys, tostring(k))
	end
	table.sort(keys, function(a: string, b: string)
		local ea, eb = data.marbles[a], data.marbles[b]
		local pa, pb = power(ea), power(eb)
		if pa ~= pb then
			return pa > pb
		end
		return a < b
	end)
	return keys
end

local function drawDetail()
	clearKids(detail)
	local e = data.marbles and data.marbles[selectedKey]
	if not e then
		body(detail, "Tap a marble to see it.", { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 120) })
		return
	end
	local id = tostring(e.id)
	local def = Config.MarbleById[id]
	local tier = def and def.tier or "Common"
	MarbleIcon.view(detail, id, e.mut, { Size = UDim2.fromOffset(150, 130), Position = UDim2.new(0.5, -75, 0, -6) }, 1)
	UI.text(detail, MarbleIcon.name(id, e.mut), { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 120) })
	MarbleIcon.tierText(detail, tier, { Size = UDim2.new(0.6, 0, 0, 22), Position = UDim2.fromOffset(0, 150), TextXAlignment = Enum.TextXAlignment.Left })
	body(detail, (e.n or 1) > 1 and ("x" .. tostring(e.n)) or "", { Size = UDim2.new(0.38, 0, 0, 22), Position = UDim2.new(0.62, 0, 0, 150), TextXAlignment = Enum.TextXAlignment.Right })
	local lvl = tonumber(e.lvl) or 1
	local xpBar = UI.bar(detail, "purple", { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 178) })
	if lvl >= Config.Level.max then
		xpBar.set(1, "LVL " .. lvl .. " (MAX)")
	else
		local need = Config.xpNeed(lvl)
		xpBar.set((tonumber(e.xp) or 0) / need, string.format("LVL %d  %d/%d XP", lvl, tonumber(e.xp) or 0, need))
	end
	local s, g, w = stats(e)
	local pts = tonumber(e.pts) or 0
	local rows: { { any } } = { { "spd", I.speed, "Speed", s, "sky" }, { "grip", I.grip, "Grip", g, "green" }, { "wt", I.weight, "Weight", w, "orange" } }
	for i, r in ipairs(rows) do
		local y = 210 + (i - 1) * 40
		UI.text(detail, r[2], { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(0, y + 2) })
		local bar = UI.bar(detail, r[5], { Size = UDim2.new(1, -90, 0, 26), Position = UDim2.fromOffset(32, y + 3) })
		bar.set((r[4] :: number) / Config.Level.statCap, string.format("%s %.1f", r[3], r[4]))
		if pts > 0 then
			local plus = UI.button(detail, "+", "green", { Size = UDim2.fromOffset(46, 34), Position = UDim2.new(1, -48, 0, y) })
			local stat = r[1] :: string
			plus.MouseButton1Click:Connect(function()
				upgradeRemote:FireServer(selectedKey, stat)
				Sfx.play("unlock", 0.4, 1.2)
			end)
		end
	end
	body(detail, pts > 0 and string.format("⭐ %d stat point%s to spend!", pts, pts == 1 and "" or "s") or "Win races to level up!", {
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 330),
	})
	local tune = UI.button(detail, string.format("TUNE-UP %d🪙", Config.TuneUp.cost), "blue", { Size = UDim2.new(0.5, -4, 0, 44), Position = UDim2.fromOffset(0, 358) })
	tune.MouseButton1Click:Connect(function()
		tuneRemote:FireServer(selectedKey)
	end)
	local isFav = data.favorite == selectedKey
	local fav = UI.button(detail, isFav and "⭐ FAVORITE" or "SET FAVORITE", isFav and "gold" or "grey", { Size = UDim2.new(0.5, -4, 0, 44), Position = UDim2.new(0.5, 4, 0, 358) })
	fav.MouseButton1Click:Connect(function()
		favRemote:FireServer(selectedKey)
	end)
	if not e.mut then
		local sh = UI.button(detail, "✨ SHINE IT", "gold", { Size = UDim2.new(1, 0, 0, 38), Position = UDim2.fromOffset(0, 408) })
		sh.MouseButton1Click:Connect(function()
			Hud.shineKey = selectedKey
			pShine.open()
		end)
	end
end

local function drawCollection()
	clearKids(collGrid)
	local keys = sortedKeys()
	if selectedKey == "" or not (data.marbles and data.marbles[selectedKey]) then
		selectedKey = keys[1] or ""
	end
	for i, key in ipairs(keys) do
		local e = data.marbles[key]
		local id = tostring(e.id)
		local def = Config.MarbleById[id]
		local tc = Tiers.get(def and def.tier or "Common")
		local cell = Instance.new("TextButton")
		cell.AutoButtonColor = false
		cell.Text = ""
		cell.LayoutOrder = i
		cell.BackgroundColor3 = Color3.new(1, 1, 1)
		cell.Parent = collGrid
		UI.corner(cell, 14)
		local st = UI.stroke(cell, key == selectedKey and 5 or 3, key == selectedKey and Color3.fromRGB(255, 214, 50) or UI.INK)
		local _ = st
		UI.gradient(cell, UI.lighten(tc.color, 0.5), UI.lighten(tc.color, 0.05))
		UI.juicy(cell)
		MarbleIcon.flat(cell, id, e.mut, 64, { Position = UDim2.new(0.5, -32, 0, 8) })
		UI.text(cell, def and def.name or id, { Size = UDim2.new(1, -8, 0, 20), Position = UDim2.new(0, 4, 0, 76) })
		UI.text(cell, "LV " .. tostring(e.lvl or 1), { Size = UDim2.new(1, -8, 0, 20), Position = UDim2.new(0, 4, 0, 98), TextColor3 = Color3.fromRGB(255, 240, 150) })
		if data.favorite == key then
			UI.text(cell, "⭐", { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(2, 2) })
		end
		if (tonumber(e.pts) or 0) > 0 then
			local b = UI.text(cell, tostring(e.pts), { Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -28, 0, 2), BackgroundTransparency = 0, BackgroundColor3 = UI.colors.green })
			UI.corner(b, 13)
		end
		cell.MouseButton1Click:Connect(function()
			selectedKey = key
			refreshMarbles()
		end)
	end
	drawDetail()
end

-- Index page
local idxHeader = body(mPages.Index, "", { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 0) })
local idxGrid = UI.scroll(mPages.Index, { Size = UDim2.new(1, 0, 1, -36), Position = UDim2.fromOffset(0, 36) })
UI.grid(idxGrid, UDim2.fromOffset(82, 100), 6)

local function drawIndex()
	clearKids(idxGrid)
	local n = indexCount()
	local nextR = nil
	for i, r in ipairs(Config.IndexRewards) do
		if not (data.indexClaimed or {})[tostring(i)] then
			nextR = r
			break
		end
	end
	idxHeader.Text = string.format("📖 %d / %d discovered", n, #Config.Marbles) .. (nextR and string.format("  ·  at %d: %s", nextR.count, nextR.text) or "  ·  all milestones done!")
	local idx = data.index or {}
	for i, def in ipairs(Config.Marbles) do
		local cell = UI.frame(idxGrid, { LayoutOrder = i, BackgroundTransparency = 1 })
		local known = idx[def.id] == true
		local tc = Tiers.get(def.tier)
		if known then
			MarbleIcon.flat(cell, def.id, nil, 58, { Position = UDim2.new(0.5, -29, 0, 2) })
			UI.text(cell, def.name, { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 62), TextColor3 = UI.lighten(tc.color, 0.3) })
			-- mutation dots
			local mx = 0
			for _, m in ipairs(Config.Mutations) do
				if idx[def.id .. ":" .. m.key] then
					UI.text(cell, m.glyph, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(4 + mx, 82) })
					mx += 18
				end
			end
		else
			local q = UI.frame(cell, { Size = UDim2.fromOffset(58, 58), Position = UDim2.new(0.5, -29, 0, 2), BackgroundColor3 = Color3.fromRGB(60, 64, 90) })
			UI.corner(q, 29)
			UI.stroke(q, 3, tc.color)
			UI.text(q, def.exclusive == "diamond" and "💎" or (def.exclusive == "gp" and "🏁" or "?"), { Font = Enum.Font.GothamBold, Size = UDim2.fromScale(0.6, 0.6), Position = UDim2.fromScale(0.2, 0.2) })
			UI.text(cell, tc.name, { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 62), TextColor3 = tc.color })
		end
	end
end

refreshMarbles = function()
	if pMarbles.isOpen() then
		drawCollection()
		drawIndex()
	end
end
pMarbles.onOpen = function()
	drawCollection()
	drawIndex()
end
local _ = mSelect

-- Packs panel ------------------------------------------------------------------------------------------------
local luckLine = body(pPacks.body, "", { Size = UDim2.new(1, -220, 0, 30), Position = UDim2.fromOffset(0, 0), TextXAlignment = Enum.TextXAlignment.Left })
local luckBuy = UI.button(pPacks.body, "🍀 LUCK x2  R$" .. Config.Products.LuckBoost.price, "green", { Size = UDim2.fromOffset(210, 36), Position = UDim2.new(1, -210, 0, -4) })
luckBuy.MouseButton1Click:Connect(function()
	buy("product", "LuckBoost")
end)
local packRow = UI.scroll(pPacks.body, {
	Size = UDim2.new(1, 0, 1, -40),
	Position = UDim2.fromOffset(0, 40),
	ScrollingDirection = Enum.ScrollingDirection.X,
	AutomaticCanvasSize = Enum.AutomaticSize.X,
})
UI.list(packRow, 12, true, Enum.HorizontalAlignment.Left)
local opening = false
local openPack: (string, number) -> ()

openPack = function(key: string, count: number)
	if opening then
		return
	end
	opening = true
	task.spawn(function()
		local ok, res = pcall(function()
			return openPackFunc:InvokeServer(key, count)
		end)
		opening = false
		if not ok or type(res) ~= "table" then
			UI.toast("Couldn't open that pack - try again!", "red")
			return
		end
		if not res.ok then
			UI.toast(tostring(res.err or "Can't open that"), "red")
			Sfx.play("error", 0.4)
			return
		end
		local items = res.items :: { { [string]: any } }
		local pack = Config.PackByKey[key]
		local canAgain = pack and (((data.packs or {})[key] or 0) > 0 or (pack.price > 0 and (data.coins or 0) >= pack.price))
		Reveal.packs(key, items, canAgain and function()
			openPack(key, count)
		end or nil)
	end)
end

local function drawPacks()
	clearKids(packRow)
	local lu = tonumber(data.luckUntil) or 0
	local luckLeft = lu - os.time()
	local luck = 1
	if owns("LuckyCharm") then
		luck *= Config.LuckyCharmMult
	end
	if luckLeft > 0 then
		luck *= Config.LuckBoostMult
	end
	luckLine.Text = luckLeft > 0 and string.format("🍀 Luck x%.2g active - %s left", luck, Fmt.time(luckLeft)) or (luck > 1 and string.format("🍀 Lucky Charm: luck x%.2g", luck) or "Odds shown per pull. Luck boosts shift them up!")
	local order = 0
	for _, pack in ipairs(Config.Packs) do
		local free = tonumber((data.packs or {})[pack.key]) or 0
		if pack.price > 0 or free > 0 then
			order += 1
			local c = UI.card(packRow, pack.color, { Size = UDim2.fromOffset(210, 400), LayoutOrder = pack.price == 0 and 0 or order })
			UI.text(c, pack.glyph, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(80, 80), Position = UDim2.new(0.5, -40, 0, 8) })
			UI.text(c, string.upper(pack.name), { Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(8, 90) })
			local d = UI.text(c, pack.desc, { Font = UI.BODY, Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 118), TextWrapped = true })
			local _ = d
			-- odds
			for i, o in ipairs(pack.odds) do
				local tc = Tiers.get(o.key)
				local y = 156 + (i - 1) * 24
				local row = UI.frame(c, { Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, y), BackgroundColor3 = UI.INK, BackgroundTransparency = 0.35 })
				UI.corner(row, 8)
				UI.text(row, tc.name, { Size = UDim2.new(0.6, -6, 0.86, 0), Position = UDim2.new(0, 6, 0.07, 0), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = tc.color })
				UI.text(row, Tiers.odds(pack.odds, o), { Size = UDim2.new(0.4, -6, 0.86, 0), Position = UDim2.new(0.6, 0, 0.07, 0), TextXAlignment = Enum.TextXAlignment.Right })
			end
			local label = free > 0 and string.format("OPEN FREE (%d)", free) or ("OPEN  " .. Fmt.num(pack.price) .. "🪙")
			local openB = UI.button(c, label, free > 0 and "orange" or "green", { Size = UDim2.new(1, -20, 0, 46), Position = UDim2.new(0, 10, 1, -102) })
			openB.MouseButton1Click:Connect(function()
				openPack(pack.key, 1)
			end)
			if owns("TripleOpen") then
				local t3 = UI.button(c, "OPEN x3", "purple", { Size = UDim2.new(1, -20, 0, 42), Position = UDim2.new(0, 10, 1, -52) })
				t3.MouseButton1Click:Connect(function()
					openPack(pack.key, 3)
				end)
			else
				local t3 = UI.button(c, "🔒 OPEN x3", "grey", { Size = UDim2.new(1, -20, 0, 42), Position = UDim2.new(0, 10, 1, -52) })
				t3.MouseButton1Click:Connect(function()
					pShop.open()
				end)
			end
		end
	end
	-- Robux pack
	local g = UI.card(packRow, "pink", { Size = UDim2.fromOffset(210, 400), LayoutOrder = 99 })
	UI.text(g, "🌌", { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(80, 80), Position = UDim2.new(0.5, -40, 0, 8) })
	UI.text(g, "GALAXY PACK", { Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(8, 90) })
	UI.text(g, "Epic-heavy odds, Secrets 1 in 125. Instant.", { Font = UI.BODY, Size = UDim2.new(1, -16, 0, 60), Position = UDim2.fromOffset(8, 124), TextWrapped = true })
	local gb = UI.button(g, "R$ " .. Config.Products.GalaxyPack.price, "green", { Size = UDim2.new(1, -20, 0, 50), Position = UDim2.new(0, 10, 1, -62) })
	gb.MouseButton1Click:Connect(function()
		buy("product", "GalaxyPack")
	end)
end
pPacks.onOpen = drawPacks

-- Shine panel ---------------------------------------------------------------------------------------------------
Hud.shineKey = ""
local shineGrid = UI.scroll(pShine.body, { Size = UDim2.new(0, 420, 1, 0) })
UI.grid(shineGrid, UDim2.fromOffset(92, 112), 8)
local shineSide = UI.frame(pShine.body, { BackgroundTransparency = 1, Size = UDim2.new(1, -436, 1, 0), Position = UDim2.new(0, 436, 0, 0) })
local shining = false
local drawShine: () -> ()

local function doShine()
	local key = Hud.shineKey
	local e = data.marbles and data.marbles[key]
	if shining or not e then
		return
	end
	shining = true
	task.spawn(function()
		local ok, res = pcall(function()
			return shineFunc:InvokeServer(key)
		end)
		shining = false
		if not ok or type(res) ~= "table" then
			UI.toast("The Shine Machine jammed - try again!", "red")
			return
		end
		if not res.ok then
			UI.toast(tostring(res.err), "red")
			Sfx.play("error", 0.4)
			return
		end
		if res.mut then
			Hud.shineKey = tostring(res.key)
		end
		local again = nil
		if (data.coins or 0) >= Config.Shine.cost then
			again = function()
				pShine.open()
			end
		end
		Reveal.shine(tostring(e.id), res, again)
	end)
end

drawShine = function()
	clearKids(shineGrid)
	clearKids(shineSide)
	local keys = sortedKeys()
	local plain = {}
	for _, k in ipairs(keys) do
		if not data.marbles[k].mut then
			table.insert(plain, k)
		end
	end
	if not (data.marbles and data.marbles[Hud.shineKey]) or data.marbles[Hud.shineKey].mut then
		Hud.shineKey = plain[1] or ""
	end
	for i, key in ipairs(plain) do
		local e = data.marbles[key]
		local id = tostring(e.id)
		local def = Config.MarbleById[id]
		local cell = Instance.new("TextButton")
		cell.AutoButtonColor = false
		cell.Text = ""
		cell.LayoutOrder = i
		cell.BackgroundColor3 = Color3.fromRGB(240, 242, 250)
		cell.Parent = shineGrid
		UI.corner(cell, 14)
		UI.stroke(cell, key == Hud.shineKey and 5 or 3, key == Hud.shineKey and Color3.fromRGB(255, 214, 50) or UI.INK)
		UI.juicy(cell)
		MarbleIcon.flat(cell, id, nil, 60, { Position = UDim2.new(0.5, -30, 0, 8) })
		UI.text(cell, def and def.name or id, { Size = UDim2.new(1, -8, 0, 20), Position = UDim2.new(0, 4, 0, 74) })
		cell.MouseButton1Click:Connect(function()
			Hud.shineKey = key
			drawShine()
		end)
	end
	local e = data.marbles and data.marbles[Hud.shineKey]
	if not e then
		body(shineSide, "All your marbles are already shiny!", { Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 120), TextWrapped = true })
		return
	end
	MarbleIcon.view(shineSide, tostring(e.id), nil, { Size = UDim2.fromOffset(160, 140), Position = UDim2.new(0.5, -80, 0, -4) }, 1.6)
	UI.text(shineSide, MarbleIcon.name(tostring(e.id), nil), { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 136) })
	local odds = Config.Shine.odds
	for i, o in ipairs(odds) do
		local m = Config.MutationByKey[o.key]
		local y = 170 + (i - 1) * 30
		local row = UI.frame(shineSide, { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, y), BackgroundColor3 = UI.INK, BackgroundTransparency = 0.2 })
		UI.corner(row, 8)
		UI.text(row, m and (m.glyph .. " " .. m.name .. "  x" .. m.mult .. " coins") or "No shine", {
			Size = UDim2.new(0.7, -6, 0.86, 0),
			Position = UDim2.new(0, 6, 0.07, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = m and m.color or Color3.fromRGB(190, 195, 210),
		})
		UI.text(row, Tiers.odds(odds, o), { Size = UDim2.new(0.3, -6, 0.86, 0), Position = UDim2.new(0.7, 0, 0.07, 0), TextXAlignment = Enum.TextXAlignment.Right })
	end
	local free = not (data.ftue and data.ftue.shine)
	if free then
		body(shineSide, "First shine is FREE and always GOLD!", { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 296), TextColor3 = Color3.fromRGB(200, 120, 0) })
	else
		body(shineSide, "Mutated marbles keep their level and earn more coins.", { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 292), TextWrapped = true })
	end
	local b = UI.button(shineSide, free and "SHINE FREE!" or ("SHINE  " .. Fmt.num(Config.Shine.cost) .. "🪙"), free and "orange" or "gold", {
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.new(0, 0, 1, -64),
	})
	b.MouseButton1Click:Connect(doShine)
end
pShine.onOpen = drawShine

-- League panel ----------------------------------------------------------------------------------------------------
local leagueLeft = UI.frame(pLeague.body, { BackgroundTransparency = 1, Size = UDim2.new(0.5, -10, 1, 0) })
local leagueRight = UI.frame(pLeague.body, { BackgroundTransparency = 1, Size = UDim2.new(0.5, -10, 1, 0), Position = UDim2.new(0.5, 10, 0, 0) })
local board: { { [string]: any } } = {}
local gpAt = 0
local gpInfo: { [string]: any } = {}

local function drawLeague()
	clearKids(leagueLeft)
	clearKids(leagueRight)
	local pts = leaguePts()
	UI.text(leagueLeft, string.format("🏅 %d POINTS TODAY", pts), { Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 0), TextColor3 = Color3.fromRGB(120, 220, 255) })
	body(leagueLeft, "Every race scores points. Resets at midnight UTC.", { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 38) })
	local l = data.league
	local claimed = type(l) == "table" and l.day == today() and l.claimed or {}
	for i, t in ipairs(Config.League.tiers) do
		local y = 70 + (i - 1) * 76
		local c = UI.card(leagueLeft, t.color, { Size = UDim2.new(1, 0, 0, 68), Position = UDim2.fromOffset(0, y) })
		UI.text(c, t.key .. " · " .. t.pts .. " pts", { Size = UDim2.new(0.6, 0, 0, 26), Position = UDim2.fromOffset(10, 4), TextXAlignment = Enum.TextXAlignment.Left })
		UI.text(c, t.text, { Font = UI.BODY, Size = UDim2.new(0.6, 0, 0, 22), Position = UDim2.fromOffset(10, 32), TextXAlignment = Enum.TextXAlignment.Left })
		local done = claimed[tostring(i)] == true
		if done then
			UI.text(c, "✅ CLAIMED", { Size = UDim2.new(0.38, 0, 0, 30), Position = UDim2.new(0.6, 0, 0, 18) })
		elseif pts >= t.pts then
			local b = UI.button(c, "CLAIM!", "green", { Size = UDim2.new(0.36, 0, 0, 46), Position = UDim2.new(0.62, 0, 0, 10) })
			local tierIndex = i
			b.MouseButton1Click:Connect(function()
				leagueRemote:FireServer(tierIndex)
				Sfx.play("cash", 0.5)
				UI.confetti(40)
			end)
		else
			local bar = UI.bar(c, "white", { Size = UDim2.new(0.36, 0, 0, 24), Position = UDim2.new(0.62, 0, 0, 22) })
			bar.set(pts / t.pts, string.format("%d/%d", pts, t.pts))
		end
	end
	-- top board
	UI.text(leagueRight, "🌍 TODAY'S TOP 10", { Size = UDim2.new(1, 0, 0, 32), Position = UDim2.fromOffset(0, 0), TextColor3 = Color3.fromRGB(255, 214, 50) })
	for i = 1, Config.League.boardSize do
		local r = board[i]
		local y = 36 + (i - 1) * 25
		local medal = i == 1 and "🥇" or (i == 2 and "🥈" or (i == 3 and "🥉" or (tostring(i) .. ".")))
		local isMe = r and r.userId == player.UserId
		local l2 = body(leagueRight, r and string.format("%s  %s  —  %d", medal, tostring(r.name), tonumber(r.pts) or 0) or (i == 1 and "Race to get on the board!" or ""), {
			Size = UDim2.new(1, 0, 0, 23),
			Position = UDim2.fromOffset(0, y),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		if isMe then
			l2.TextColor3 = Color3.fromRGB(220, 120, 0)
		end
	end
	-- Grand Prix box
	local gp = UI.card(leagueRight, "purple", { Size = UDim2.new(1, 0, 0, 120), Position = UDim2.new(0, 0, 1, -122) })
	local th = gpInfo
	UI.text(gp, "🏁 GRAND PRIX: " .. string.upper(tostring(th.name or "")), { Size = UDim2.new(1, -90, 0, 26), Position = UDim2.fromOffset(10, 6), TextXAlignment = Enum.TextXAlignment.Left })
	local left = math.max(0, gpAt - now())
	UI.text(gp, left > 0 and ("Next in " .. Fmt.time(left)) or "NEXT RACE!", { Font = UI.BODY, Size = UDim2.new(1, -90, 0, 24), Position = UDim2.fromOffset(10, 34), TextXAlignment = Enum.TextXAlignment.Left })
	UI.text(gp, "2x coins & points. Win it for this week's prize:", { Font = UI.BODY, Size = UDim2.new(1, -90, 0, 40), Position = UDim2.fromOffset(10, 60), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true })
	if th.marble then
		MarbleIcon.flat(gp, tostring(th.marble), nil, 70, { Position = UDim2.new(1, -80, 0, 10) })
		local def = Config.MarbleById[tostring(th.marble)]
		UI.text(gp, def and def.name or "", { Size = UDim2.fromOffset(90, 20), Position = UDim2.new(1, -90, 0, 84) })
	end
end
pLeague.onOpen = drawLeague

-- Shop panel ----------------------------------------------------------------------------------------------------
local shopPages = UI.tabs(pShop.body, { "Featured", "Passes", "Coins", "Trails" }, { "pink", "purple", "gold", "teal" })
local shopGrids: { [string]: ScrollingFrame } = {}
for name, page in pairs(shopPages) do
	local s = UI.scroll(page, {})
	UI.grid(s, UDim2.fromOffset(190, 210), 10)
	shopGrids[name] = s
end

local function shopCard(grid: Instance, order: number, glyph: string, name: string, desc: string, btnText: string, btnColor: any, onClick: () -> (), highlight: any?)
	local c = UI.card(grid, highlight or Color3.fromRGB(240, 242, 252), { LayoutOrder = order })
	UI.text(c, glyph, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(56, 56), Position = UDim2.new(0.5, -28, 0, 6) })
	UI.text(c, name, { Size = UDim2.new(1, -12, 0, 26), Position = UDim2.fromOffset(6, 62), TextWrapped = true })
	local d = UI.text(c, desc, { Font = UI.BODY, Size = UDim2.new(1, -14, 0, 56), Position = UDim2.fromOffset(7, 90), TextWrapped = true, TextColor3 = highlight and Color3.new(1, 1, 1) or UI.INK })
	if not highlight then
		noStroke(d)
	end
	local b = UI.button(c, btnText, btnColor, { Size = UDim2.new(1, -16, 0, 46), Position = UDim2.new(0, 8, 1, -54) })
	b.MouseButton1Click:Connect(onClick)
end

local function drawShop()
	for _, g in pairs(shopGrids) do
		clearKids(g)
	end
	local P, Pr = Config.Passes, Config.Products
	-- Featured
	local f = shopGrids.Featured
	if not data.starterBought then
		shopCard(f, 1, Pr.StarterPack.glyph, Pr.StarterPack.name, Pr.StarterPack.desc, "R$ " .. Pr.StarterPack.price, "green", function()
			buy("product", "StarterPack")
		end, "orange")
	end
	shopCard(f, 2, Pr.DiamondMarble.glyph, Pr.DiamondMarble.name, Pr.DiamondMarble.desc, "R$ " .. Fmt.commas(Pr.DiamondMarble.price), "sky", function()
		buy("product", "DiamondMarble")
	end, "purple")
	shopCard(f, 3, P.VIP.glyph, P.VIP.name, P.VIP.desc, owns("VIP") and "OWNED ✅" or ("R$ " .. P.VIP.price), owns("VIP") and "grey" or "green", function()
		if not owns("VIP") then
			buy("pass", "VIP")
		end
	end, "gold")
	shopCard(f, 4, Pr.StartGP.glyph, Pr.StartGP.name, Pr.StartGP.desc, "R$ " .. Pr.StartGP.price, "green", function()
		buy("product", "StartGP")
	end, "pink")
	shopCard(f, 5, Pr.LuckBoost.glyph, Pr.LuckBoost.name, Pr.LuckBoost.desc, "R$ " .. Pr.LuckBoost.price, "green", function()
		buy("product", "LuckBoost")
	end)
	shopCard(f, 6, Pr.GalaxyPack.glyph, Pr.GalaxyPack.name, Pr.GalaxyPack.desc, "R$ " .. Pr.GalaxyPack.price, "green", function()
		buy("product", "GalaxyPack")
	end)
	-- Passes
	local order = 0
	for _, key in ipairs({ "CoinsX2", "PowerSlot", "VIP", "TripleOpen", "LuckyCharm" }) do
		local p = (P :: any)[key]
		order += 1
		local have = owns(key)
		shopCard(shopGrids.Passes, order, p.glyph, p.name, p.desc, have and "OWNED ✅" or ("R$ " .. p.price), have and "grey" or "green", function()
			if not have then
				buy("pass", key)
			end
		end)
	end
	-- Coins
	order = 0
	for _, key in ipairs({ "CoinsS", "CoinsM", "CoinsL" }) do
		local p = (Pr :: any)[key]
		order += 1
		shopCard(shopGrids.Coins, order, p.glyph, p.name, p.desc, "R$ " .. p.price, "green", function()
			buy("product", key)
		end)
	end
	-- Trails
	order = 1
	shopCard(shopGrids.Trails, 0, "🚫", "No Trail", "Just the marble.", data.trail == "" and "EQUIPPED" or "EQUIP", data.trail == "" and "grey" or "blue", function()
		trailRemote:FireServer("")
	end)
	for _, t in ipairs(Config.Trails) do
		order += 1
		local have = (data.trails or {})[t.key] == true
		local equipped = data.trail == t.key
		local glyph = t.key == "sparkle" and "✨" or (t.key == "flame" and "🔥" or (t.key == "rainbow" and "🌈" or "👑"))
		local btn, col
		if equipped then
			btn, col = "EQUIPPED", "grey"
		elseif have then
			btn, col = "EQUIP", "blue"
		elseif t.pass then
			btn, col = "VIP PASS", "gold"
		else
			btn, col = "R$ " .. tostring(((Pr :: any)[t.product] or {}).price or "?"), "green"
		end
		shopCard(shopGrids.Trails, order, glyph, t.name, have and "Shows behind your marble in every race." or "Leave a trail behind your marble!", btn, col, function()
			if have then
				trailRemote:FireServer(t.key)
				Sfx.play("unlock", 0.4)
			elseif t.pass then
				buy("pass", "VIP")
			elseif t.product then
				buy("product", t.product)
			end
		end)
	end
end
pShop.onOpen = drawShop

-- Daily panel ----------------------------------------------------------------------------------------------------
local dailyRow = UI.frame(pDaily.body, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 150), Position = UDim2.fromOffset(0, 10) })
UI.list(dailyRow, 8, true)
local dailyBtn = UI.button(pDaily.body, "CLAIM!", "green", { Size = UDim2.fromOffset(260, 60), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10) })
local dailyNote = body(pDaily.body, "", { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 172) })
dailyBtn.MouseButton1Click:Connect(function()
	if dailyReady() then
		dailyRemote:FireServer()
		Sfx.play("cash", 0.6)
		UI.confetti(50)
		pDaily.close()
	end
end)

local function drawDaily()
	clearKids(dailyRow)
	local d = data.daily or { last = 0, streak = 0 }
	local streak = tonumber(d.streak) or 0
	local ready = dailyReady()
	-- the day you'd claim next
	local nextDay = (d.last == today() - 1 or d.last == today()) and streak + (ready and 1 or 0) or 1
	if not ready then
		nextDay = streak
	end
	local cur = (math.max(1, nextDay) - 1) % #Config.Daily + 1
	for i, r in ipairs(Config.Daily) do
		local isCur = i == cur
		local c = UI.card(dailyRow, isCur and "gold" or (i < cur and "green" or "grey"), { Size = UDim2.fromOffset(84, isCur and 146 or 128), LayoutOrder = i })
		UI.text(c, "DAY " .. i, { Size = UDim2.new(1, -8, 0, 22), Position = UDim2.fromOffset(4, 6) })
		UI.text(c, r.kind == "coins" and I.coins or I.pack, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0.5, -22, 0, 30) })
		UI.text(c, r.text, { Font = UI.BODY, Size = UDim2.new(1, -8, 0, 40), Position = UDim2.fromOffset(4, 78), TextWrapped = true })
		if i < cur or (isCur and not ready) then
			UI.text(c, "✅", { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -30, 0, 2) })
		end
	end
	if ready then
		dailyBtn.Visible = true
		dailyNote.Text = string.format("Streak: %d day%s. Come back every day for bigger rewards!", streak, streak == 1 and "" or "s")
	else
		dailyBtn.Visible = false
		local secs = (today() + 1) * 86400 - os.time()
		dailyNote.Text = "Claimed! Next reward in " .. Fmt.time(secs)
	end
end
pDaily.onOpen = drawDaily

-- Welcome back (offline earnings) -------------------------------------------------------------------------------
local welcomeText = body(pWelcome.body, "", { Size = UDim2.new(1, 0, 0, 120), Position = UDim2.fromOffset(0, 20), TextWrapped = true })
local welcomeBtn = UI.button(pWelcome.body, "COLLECT!", "green", { Size = UDim2.fromOffset(240, 60), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10) })
welcomeBtn.MouseButton1Click:Connect(function()
	pWelcome.close()
	local from = UI.center()
	UI.fly(from, coins.frame, 12, I.coins)
	Sfx.play("cash", 0.6)
end)

function Hud.offline(c: number, mins: number)
	welcomeText.Text = string.format("Your marbles kept practicing for %s while you were away and earned\n%s 🪙 coins!", Fmt.time(mins * 60), Fmt.commas(c))
	pWelcome.open()
end

-- Guide: next goal + arrow + beam ------------------------------------------------------------------------------
local arrow = UI.text(root, "👈", { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(54, 54), AnchorPoint = Vector2.new(0, 0.5), Visible = false, ZIndex = 9 })
local arrowTarget: GuiObject? = nil
local arrowFlip = false
local beam: Beam? = nil
local beamA0: Attachment? = nil
local beamA1: Attachment? = nil
local beamTarget = ""

local function stationPart(promptName: string): BasePart?
	local lobby = workspace:FindFirstChild("Lobby")
	if not lobby then
		return nil
	end
	local pp = lobby:FindFirstChild(promptName, true)
	if pp and pp.Parent and pp.Parent:IsA("BasePart") then
		return pp.Parent :: BasePart
	end
	return nil
end

local function setBeam(promptName: string)
	if promptName == beamTarget and beam and beam.Parent then
		return
	end
	beamTarget = promptName
	if beam then
		beam:Destroy()
		beam = nil
	end
	if beamA0 then
		beamA0:Destroy()
		beamA0 = nil
	end
	if beamA1 then
		beamA1:Destroy()
		beamA1 = nil
	end
	if promptName == "" then
		return
	end
	local ch = player.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	local target = stationPart(promptName)
	if not hrp or not target then
		beamTarget = ""
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, -1.5, 0)
	a0.Parent = hrp
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 2, 0)
	a1.Parent = target
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Color = ColorSequence.new(Color3.fromRGB(80, 255, 200), Color3.fromRGB(255, 240, 120))
	b.Transparency = NumberSequence.new(0.25)
	b.Width0 = 1.2
	b.Width1 = 1.2
	b.FaceCamera = true
	b.LightEmission = 0.7
	b.Segments = 24
	b.CurveSize0 = 4
	b.CurveSize1 = -4
	b.Parent = hrp
	beam, beamA0, beamA1 = b, a0, a1
end

type Goal = { text: string, button: GuiObject?, flip: boolean, station: string }

local function goal(): Goal?
	local f = data.ftue or {}
	if not f.raced then
		return { text = "🏁 Your first race is starting - tap BOOST when you glow!", button = nil, flip = false, station = "" }
	end
	if ((data.packs or {}).welcome or 0) > 0 then
		return { text = "🎁 Open your FREE Welcome Pack!", button = bPacks.button, flip = false, station = "PacksPrompt" }
	end
	if f.teased and not f.shine then
		return { text = "✨ Shine a marble FREE - guaranteed GOLD!", button = bShine.button, flip = false, station = "ShinePrompt" }
	end
	if dailyReady() then
		return { text = "📅 Claim your daily reward!", button = bDaily.button, flip = true, station = "DailyPrompt" }
	end
	if pointsLeft() > 0 then
		return { text = "⬆️ Spend your marble's stat points!", button = bMarbles.button, flip = false, station = "" }
	end
	if leagueClaimable() > 0 then
		return { text = "🏅 Claim your League reward!", button = bLeague.button, flip = false, station = "" }
	end
	if freePacks() > 0 then
		return { text = "🎁 You have free packs to open!", button = bPacks.button, flip = false, station = "PacksPrompt" }
	end
	if (data.coins or 0) >= Config.Packs[1].price and (data.packsOpened or 0) < 3 then
		return { text = "🎁 Buy a Basic Pack - collect them all!", button = bPacks.button, flip = false, station = "PacksPrompt" }
	end
	if not f.shine and (data.races or 0) >= 4 then
		return { text = "✨ Try the Shine Machine - first one's FREE!", button = bShine.button, flip = false, station = "ShinePrompt" }
	end
	local pts = leaguePts()
	for _, t in ipairs(Config.League.tiers) do
		if pts < t.pts then
			return { text = string.format("🏅 Reach %s League: %d/%d points today", t.key, pts, t.pts), button = nil, flip = false, station = "" }
		end
	end
	return { text = string.format("📖 Discover every marble: %d/%d", indexCount(), #Config.Marbles), button = nil, flip = false, station = "" }
end

local function updateGuide()
	local g = goal()
	if not g then
		goalPill.Visible = false
		arrow.Visible = false
		setBeam("")
		return
	end
	if goalText.Text ~= g.text then
		goalText.Text = g.text
		goalPill.Visible = true
		UI.punch(goalPill, 0.12)
	end
	arrowTarget = g.button
	arrowFlip = g.flip
	arrow.Text = g.flip and "👉" or "👈"
	setBeam(g.station)
end

RunService.RenderStepped:Connect(function()
	local t = arrowTarget
	if t and t.Visible and t.AbsoluteSize.X > 0 and not pMarbles.isOpen() and (rightCol.Visible or not t:IsDescendantOf(rightCol)) then
		local s = UI.scale()
		local bob = math.sin(os.clock() * 6) * 8
		local p = (t.AbsolutePosition - root.AbsolutePosition) / s
		local size = t.AbsoluteSize / s
		arrow.Visible = true
		if arrowFlip then
			arrow.AnchorPoint = Vector2.new(1, 0.5)
			arrow.Position = UDim2.fromOffset(p.X - 6 + bob, p.Y + size.Y / 2)
		else
			arrow.AnchorPoint = Vector2.new(0, 0.5)
			arrow.Position = UDim2.fromOffset(p.X + size.X + 6 - bob, p.Y + size.Y / 2)
		end
	else
		arrow.Visible = false
	end
end)

player.CharacterAdded:Connect(function()
	beamTarget = "?"
	task.delay(1, updateGuide)
end)

-- Right column timers ----------------------------------------------------------------------------------------------
task.spawn(function()
	while true do
		local left = gpAt - now()
		bGp.label.Text = left > 0 and Fmt.time(left) or "NOW!"
		local lu = (tonumber(data.luckUntil) or 0) - os.time()
		bLuck.button.Visible = lu > 0
		if lu > 0 then
			bLuck.label.Text = Fmt.time(lu)
		end
		bX2.button.Visible = owns("CoinsX2") or os.clock() - sessionStart > Config.NoOffersBefore
		bX2.label.Text = owns("CoinsX2") and "2x ON" or "2x"
		task.wait(0.5)
	end
end)

-- Data --------------------------------------------------------------------------------------------------------
State.onChange(function(d)
	local prev = data
	data = d
	coins.set(tonumber(d.coins) or 0)
	wins.set(tonumber(d.wins) or 0)
	indexCounter.set(indexCount())
	bPacks.setBadge(freePacks())
	bLeague.setBadge(leagueClaimable())
	bDaily.setBadge(dailyReady() and "!" or nil)
	bMarbles.setBadge(pointsLeft())
	bShine.setBadge(not (d.ftue and d.ftue.shine) and d.ftue and d.ftue.teased and "!" or nil)
	-- new discoveries flash the index counter
	local pidx = prev and (prev :: any).index
	if type(pidx) == "table" and indexCount() > 0 then
		local before = 0
		for k in pairs(pidx :: { [string]: any }) do
			if not string.find(tostring(k), ":") then
				before += 1
			end
		end
		if indexCount() > before and before > 0 then
			UI.punch(indexCounter.frame, 0.3)
		end
	end
	if pMarbles.isOpen() then
		drawCollection()
		drawIndex()
	end
	if pPacks.isOpen() and not Reveal.isOpen() then
		drawPacks()
	end
	if pShine.isOpen() and not Reveal.isOpen() then
		drawShine()
	end
	if pLeague.isOpen() then
		drawLeague()
	end
	if pShop.isOpen() then
		drawShop()
	end
	if pDaily.isOpen() then
		drawDaily()
	end
	updateGuide()
end)

-- Public ------------------------------------------------------------------------------------------------------------
function Hud.coinFrame(): GuiObject
	return coins.frame
end

function Hud.setStatus(text: string, color: any)
	statusText.Text = text
	local c = UI.color(color)
	statusGrad.Color = ColorSequence.new(UI.shade(c, 0.75), UI.shade(c, 0.45))
end

function Hud.setGp(at: number, info: { [string]: any })
	gpAt = at
	gpInfo = info
	if pLeague.isOpen() then
		drawLeague()
	end
end

function Hud.setBoard(rows: { { [string]: any } })
	board = rows
	if pLeague.isOpen() then
		drawLeague()
	end
end

function Hud.open(name: string)
	local p = UI.getPanel(name)
	if p and not Reveal.isOpen() then
		p.open()
	end
end

function Hud.refreshGuide()
	updateGuide()
end

-- Purchase offers: never in the first minutes, at most one every 6 minutes, only after a race ends.
local lastOffer = -1000
function Hud.maybeOffer(lost: boolean)
	local t = os.clock()
	if t - sessionStart < Config.NoOffersBefore or t - lastOffer < 360 or UI.getPanel("__offer") and (UI.getPanel("__offer") :: any).isOpen() then
		return
	end
	if Reveal.isOpen() then
		return
	end
	lastOffer = t
	if not data.starterBought then
		local p = Config.Products.StarterPack
		UI.offer({
			title = "STARTER PACK!",
			text = p.desc,
			glyph = p.glyph,
			price = "R$ " .. p.price,
			color = "orange",
			onBuy = function()
				buy("product", "StarterPack")
			end,
		})
	elseif not owns("CoinsX2") then
		local p = Config.Passes.CoinsX2
		UI.offer({
			title = lost and "DOUBLE YOUR COINS" or "2x COINS!",
			text = p.desc,
			glyph = p.glyph,
			price = "R$ " .. p.price,
			color = "gold",
			onBuy = function()
				buy("pass", "CoinsX2")
			end,
		})
	elseif not owns("PowerSlot") then
		local p = Config.Passes.PowerSlot
		UI.offer({
			title = "EXTRA POWER-UP!",
			text = p.desc,
			glyph = p.glyph,
			price = "R$ " .. p.price,
			color = "purple",
			onBuy = function()
				buy("pass", "PowerSlot")
			end,
		})
	end
end

local _ = Tiers
return Hud

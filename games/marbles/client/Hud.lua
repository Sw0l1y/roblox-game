--!strict
-- HUD and menus: top counters (coins, wins, index), the phase/timer pill, the next-goal pill with a
-- pointing arrow and a world beam to the right machine, the server-boost pill, the left menu grid (Marbles,
-- Packs, Shine, League, Shop, FREE) and right column (Daily, Grand Prix timer, Starter/2x offer, Luck, mute),
-- plus the panels: collection with levels/stat points/tune-ups, the index, packs with exact % odds that
-- follow the player's live luck (and an every-marble odds sheet), the Shine Machine, the daily league and
-- the 7-day daily reward with Keep Streak. The shop and purchase popups live in Store.
-- Players under Roblox's paid random item restriction (RandomBlocked) see fixed coin offers instead of rolls.
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
local Store = require(ClientLib:WaitForChild("Store"))
local LiveUI = require(ClientLib:WaitForChild("LiveUI"))
local Prices = require(ClientLib:WaitForChild("Prices"))

local Hud = {}

local player = Players.LocalPlayer
local I = Config.Icons
local buyRemote = Net.event("Buy")
local upgradeRemote = Net.event("Upgrade")
local tuneRemote = Net.event("TuneUp")
local dailyRemote = Net.event("ClaimDaily")
local leagueRemote = Net.event("ClaimLeague")
local favRemote = Net.event("Favorite")
local openPackFunc = Net.func("OpenPack")
local shineFunc = Net.func("Shine")

local root = UI.root
local data: { [string]: any } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

-- UTC day number on the server's clock (the server's Economy.today).
local function today(): number
	return math.floor(now() / 86400)
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

local function serverBoost(kind: string): number
	local ends = ReplicatedStorage:GetAttribute("BoostEnd_" .. kind)
	local m = ReplicatedStorage:GetAttribute("Boost_" .. kind)
	if type(ends) == "number" and ends > now() and type(m) == "number" then
		return m
	end
	return 1
end

-- The player's luck right now, the same product as the server's Economy.luck: Lucky Charm x Luck Boost x
-- server luck boost. Every odds screen uses it, so the shown % are exactly what the roll uses.
local function luck(): number
	local l = 1
	if owns("LuckyCharm") then
		l *= Config.LuckyCharmMult
	end
	if (tonumber(data.luckUntil) or 0) > now() then
		l *= Config.LuckBoostMult
	end
	return l * serverBoost("luck")
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

-- On desktop Roblox's chat window covers the top-left third of the screen (under its top bar) and the player
-- list the top-right corner, so nothing of ours goes there: the next-goal hint sits top centre under the
-- counters, and both menu columns start below those windows. Phones have neither open, so their columns
-- stay centred (clear of the thumbstick and the jump button).
local MOBILE = UI.isMobile

-- Next goal pill (top centre, under the counters)
local goalPill = UI.frame(root, { Name = "Goal", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 74), Size = UDim2.fromOffset(600, 40), Visible = false })
UI.corner(goalPill, 18)
UI.stroke(goalPill, 3)
UI.gradient(goalPill, UI.shade(UI.colors.teal, 0.6), UI.shade(UI.colors.teal, 0.38))
local goalText = UI.text(goalPill, "", { Size = UDim2.new(1, -24, 0.72, 0), Position = UDim2.new(0, 12, 0.14, 0), ZIndex = 3 })
-- server boosts (kit Boosts: "⚡ 2x COINS 12:04") and the round modifiers bought for the next race
LiveUI.boostPill(root, { coins = "COINS", luck = "LUCK" }, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 118), Size = UDim2.fromOffset(400, 34) })
local modsPill = UI.frame(root, { Name = "NextMods", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 156), Size = UDim2.fromOffset(460, 30), Visible = false })
UI.corner(modsPill, 14)
UI.stroke(modsPill, 3)
UI.gradient(modsPill, UI.shade(UI.colors.purple, 0.75), UI.shade(UI.colors.purple, 0.45))
local modsText = UI.text(modsPill, "", { Size = UDim2.new(1, -20, 0.76, 0), Position = UDim2.new(0, 10, 0.12, 0), ZIndex = 3 })
local function refreshMods()
	local t = ReplicatedStorage:GetAttribute("NextMods")
	modsPill.Visible = type(t) == "string" and t ~= ""
	modsText.Text = type(t) == "string" and ("NEXT RACE: " .. t) or ""
end
ReplicatedStorage:GetAttributeChangedSignal("NextMods"):Connect(refreshMods)
refreshMods()
UI.setToastTop(192) -- toasts stack under the hint and boost pills instead of over them

-- Left menu grid (2 x 3: 2 x 78 + 12 wide, 3 x 78 + 2 x 12 tall)
local left = UI.frame(root, {
	Name = "Menu",
	BackgroundTransparency = 1,
	AnchorPoint = MOBILE and Vector2.new(0, 0.5) or Vector2.new(0, 0),
	Position = MOBILE and UDim2.new(0, 16, 0.5, 40) or UDim2.new(0, 16, 0.34, 10),
	Size = UDim2.fromOffset(168, 258),
})
local leftGrid = UI.grid(left, UDim2.fromOffset(78, 78), 12)
leftGrid.FillDirectionMaxCells = 2
local bMarbles = UI.iconButton(left, I.marbles, "Marbles", "purple", { LayoutOrder = 1 })
local bPacks = UI.iconButton(left, I.pack, "Packs", "green", { LayoutOrder = 2 })
local bShine = UI.iconButton(left, I.shine, "Shine", "gold", { LayoutOrder = 3 })
local bLeague = UI.iconButton(left, I.league, "League", "sky", { LayoutOrder = 4 })
local bShop = UI.iconButton(left, I.shop, "Shop", "pink", { LayoutOrder = 5 })
local bFree = UI.iconButton(left, I.gift, "FREE", "green", { LayoutOrder = 6 })

-- Right column (3 to 5 buttons: the Starter/2x offer and Luck come and go)
local rightCol = UI.frame(root, {
	Name = "Side",
	BackgroundTransparency = 1,
	AnchorPoint = MOBILE and Vector2.new(1, 0.5) or Vector2.new(1, 0),
	Position = MOBILE and UDim2.new(1, -16, 0.42, 0) or UDim2.new(1, -16, 0.28, 40),
	Size = UDim2.fromOffset(84, 438),
})
UI.list(rightCol, 12).VerticalAlignment = MOBILE and Enum.VerticalAlignment.Center or Enum.VerticalAlignment.Top
local bDaily = UI.iconButton(rightCol, I.daily, "Daily", "orange", { LayoutOrder = 1 })
local bGp = UI.iconButton(rightCol, I.gp, "GP", "purple", { LayoutOrder = 2 })
local bLuck = UI.iconButton(rightCol, I.luck, "Luck", "green", { LayoutOrder = 3 })
local bX2 = UI.iconButton(rightCol, I.x2, "2x", "gold", { LayoutOrder = 4 })
local bMute = UI.iconButton(rightCol, I.music, "Music", "teal", { LayoutOrder = 5 })
bLuck.button.Visible = false
bX2.button.Visible = false

-- Panels ------------------------------------------------------------------------------------------------------
local pMarbles = UI.panel("Marbles", "MY MARBLES", "purple", Vector2.new(820, 520))
local pPacks = UI.panel("Packs", "MARBLE PACKS", "green", Vector2.new(940, 500))
local pShine = UI.panel("Shine", "SHINE MACHINE", "gold", Vector2.new(780, 500))
local pLeague = UI.panel("League", "DAILY LEAGUE", "sky", Vector2.new(820, 500))
local pDaily = UI.panel("Daily", "DAILY REWARD", "orange", Vector2.new(700, 420))
local pOdds = UI.panel("Odds", "ALL ODDS", "green", Vector2.new(820, 520))
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
	if Store.isOpen() then
		UI.closeAll()
	else
		Store.open()
	end
end)
bFree.button.MouseButton1Click:Connect(function()
	LiveUI.open()
end)
LiveUI.onClaimable(function(n: number)
	bFree.setBadge(n)
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
	Store.open(Store.starterLeft() > 0 and "Deals" or "Passes")
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
	local tune = UI.button(detail, string.format("TUNE-UP %d💰", Config.TuneUp.cost), "blue", { Size = UDim2.new(0.5, -4, 0, 44), Position = UDim2.fromOffset(0, 358) })
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
-- Every chance is an exact % from kit Tiers (they add up to 100) at the player's luck right now: with luck on,
-- each row shows the normal % in grey next to the boosted % in green, and the panel redraws as luck changes.
-- A restricted player's coin purchase shows the fixed marble of the day instead of odds.
local luckLine = body(pPacks.body, "", { Size = UDim2.new(1, -236, 0, 30), Position = UDim2.fromOffset(0, 0), TextXAlignment = Enum.TextXAlignment.Left })
local luckBuy = UI.button(pPacks.body, "", "green", { Size = UDim2.fromOffset(226, 36), Position = UDim2.new(1, -226, 0, -4) })
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
local GREY = Color3.fromRGB(190, 195, 210)
local GREEN = Color3.fromRGB(140, 255, 140)

-- Today's fixed marble when this coin purchase can't be a roll (paid random restriction), else nil.
local function fixedFor(key: string): string?
	local pack = Config.PackByKey[key]
	local free = tonumber((data.packs or {})[key]) or 0
	if Store.blocked() and pack and pack.price > 0 and free <= 0 then
		return Config.fixedMarble(key, today())
	end
	return nil
end

openPack = function(key: string, count: number)
	if opening then
		return
	end
	opening = true
	local expect = fixedFor(key)
	task.spawn(function()
		local ok, res = pcall(function()
			return openPackFunc:InvokeServer(key, count, expect)
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

-- One odds row: name, then the chance (with luck on: the normal chance in grey and the boosted one in green).
local function oddsRow(parent: Instance, pos: UDim2, size: UDim2, name: string, color: Color3, entries: { any }, entry: any, l: number): Frame
	local row = UI.frame(parent, { Size = size, Position = pos, BackgroundColor3 = UI.INK, BackgroundTransparency = 0.3 })
	UI.corner(row, 8)
	UI.text(row, name, { Size = UDim2.new(0.42, -6, 0.86, 0), Position = UDim2.new(0, 6, 0.07, 0), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color })
	if l > 1 then
		UI.text(row, Tiers.odds(entries, entry), { Font = UI.BODY, Size = UDim2.new(0.26, 0, 0.72, 0), Position = UDim2.new(0.42, 0, 0.14, 0), TextColor3 = GREY })
		UI.text(row, Tiers.odds(entries, entry, l), { Size = UDim2.new(0.32, -6, 0.86, 0), Position = UDim2.new(0.68, 0, 0.07, 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = GREEN })
	else
		UI.text(row, Tiers.odds(entries, entry), { Size = UDim2.new(0.58, -6, 0.86, 0), Position = UDim2.new(0.42, 0, 0.07, 0), TextXAlignment = Enum.TextXAlignment.Right })
	end
	return row
end

-- Mutation chances on every pack pull, one line ("🟡 4%  🌈 1%  🌌 0.25%"), boosted while lucky.
local function mutationText(l: number): string
	local parts: { string } = {}
	for _, o in ipairs(Config.PackMutations) do
		local m = Config.MutationByKey[o.key]
		if m then
			table.insert(parts, m.glyph .. " " .. Tiers.odds(Config.PackMutations, o, l))
		end
	end
	return table.concat(parts, "  ")
end

local function packCard(pack: Config.Pack, order: number, l: number, title: string?): Frame
	local c = UI.card(packRow, pack.color, { Size = UDim2.fromOffset(230, 400), LayoutOrder = order })
	UI.text(c, pack.glyph, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(60, 60), Position = UDim2.new(0.5, -30, 0, 4) })
	UI.text(c, title or string.upper(pack.name), { Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 64) })
	UI.text(c, pack.desc, { Font = UI.BODY, Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 90), TextWrapped = true })
	local fixed = if title then nil else fixedFor(pack.key)
	if fixed then
		local def = Config.MarbleById[fixed]
		UI.text(c, "TODAY YOU GET:", { Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 116) })
		MarbleIcon.flat(c, fixed, nil, 84, { Position = UDim2.new(0.5, -42, 0, 140) })
		UI.text(c, def and def.name or fixed, { Size = UDim2.new(1, -16, 0, 24), Position = UDim2.fromOffset(8, 228) })
		MarbleIcon.tierText(c, def and def.tier or "Common", { Size = UDim2.new(1, -40, 0, 20), Position = UDim2.fromOffset(20, 254) })
		UI.text(c, "The same marble all day.", { Font = UI.BODY, Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 276) })
	else
		for i, o in ipairs(pack.odds) do
			local tc = Tiers.get(o.key)
			oddsRow(c, UDim2.fromOffset(8, 114 + (i - 1) * 21), UDim2.new(1, -16, 0, 19), tc.name, tc.color, pack.odds, o, l)
		end
		UI.text(c, mutationText(l), { Font = UI.BODY, Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 116 + #pack.odds * 21), TextColor3 = l > 1 and GREEN or Color3.new(1, 1, 1) })
		local ob = UI.button(c, "ODDS", "white", { Size = UDim2.fromOffset(62, 28), Position = UDim2.new(1, -68, 0, 6) })
		ob.MouseButton1Click:Connect(function()
			pOdds.open()
		end)
	end
	return c
end

local shownLuck = 1
local function drawPacks()
	clearKids(packRow)
	local l = luck()
	shownLuck = l
	local isBlocked = Store.blocked()
	local lu = (tonumber(data.luckUntil) or 0) - now()
	local parts: { string } = {}
	if owns("LuckyCharm") then
		table.insert(parts, "Charm")
	end
	if lu > 0 then
		table.insert(parts, "Boost " .. Fmt.time(lu))
	end
	if serverBoost("luck") > 1 then
		table.insert(parts, string.format("Server x%g", serverBoost("luck")))
	end
	if l > 1 then
		luckLine.Text = string.format("🍀 Luck x%.3g (%s): grey = normal, green = your odds now", l, table.concat(parts, " + "))
	elseif isBlocked then
		luckLine.Text = "Coin packs give the marble shown. Free packs show their odds."
	else
		local gx = Config.PackByKey.galaxy
		local sec = gx.odds[#gx.odds]
		luckLine.Text = string.format("🍀 Luck x%g: Galaxy Pack SECRET %s → %s!", Config.LuckBoostMult, Tiers.odds(gx.odds, sec), Tiers.odds(gx.odds, sec, Config.LuckBoostMult))
	end
	luckBuy.Visible = not isBlocked
	luckBuy.Text = "🍀 LUCK x2  R$" .. Config.Products.LuckBoost.price
	local order = 0
	for _, pack in ipairs(Config.Packs) do
		local free = tonumber((data.packs or {})[pack.key]) or 0
		if pack.price > 0 or free > 0 then
			order += 1
			local c = packCard(pack, pack.price == 0 and 0 or order, l)
			local label = free > 0 and string.format("OPEN FREE (%d)", free) or ((fixedFor(pack.key) and "BUY  " or "OPEN  ") .. Fmt.num(pack.price) .. "💰")
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
					Store.open("Passes")
				end)
			end
		end
	end
	-- the Robux Galaxy Pack: a paid random item, so not shown under the restriction
	if not isBlocked then
		local g = packCard(Config.PackByKey.galaxy, 99, l, "GALAXY PACK (R$)")
		local gb = UI.button(g, "R$ " .. Config.Products.GalaxyPack.price .. "  INSTANT", "green", { Size = UDim2.new(1, -20, 0, 60), Position = UDim2.new(0, 10, 1, -72) })
		gb.MouseButton1Click:Connect(function()
			buy("product", "GalaxyPack")
		end)
	end
end
pPacks.onOpen = drawPacks

-- Every-marble odds sheet: per pack, each tier's % (live with luck), how many marbles share it and each
-- marble's own %, the names (Secret ones stay ??? until found), mutations, and the Shine Machine.
local oddsScroll = UI.scroll(pOdds.body, {})
UI.list(oddsScroll, 4)
local function drawOdds()
	clearKids(oddsScroll)
	local l = luck()
	local blockedNow = Store.blocked()
	local n = 0
	local function line(text: string, color: Color3?, small: boolean?, h: number?): TextLabel
		n += 1
		local t = UI.text(oddsScroll, text, {
			LayoutOrder = n,
			Size = UDim2.new(1, -10, 0, h or 26),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Font = small and UI.BODY or UI.TITLE,
			TextColor3 = color or UI.INK,
		})
		if small or not color then
			noStroke(t)
		end
		return t
	end
	line(l > 1 and string.format("🍀 Your luck now: x%.3g. Each line: normal %%  →  your %% now.", l) or "Exact chances per pull. In every pack they add up to 100%.", nil, true)
	if blockedNow then
		line("Coin purchases here give the fixed marble shown on each pack, and the Shine Machine a fixed Gold shine.", nil, true)
	end
	local idx = data.index or {}
	for _, pack in ipairs(Config.Packs) do
		line(pack.glyph .. " " .. string.upper(pack.name) .. (pack.price > 0 and ("  ·  " .. Fmt.num(pack.price) .. "💰") or "  ·  FREE") .. (pack.key == "galaxy" and "  (and the R$ Galaxy Pack)" or ""), Color3.fromRGB(255, 214, 50), false, 30)
		local ps = Tiers.percents(pack.odds, l)
		for i, o in ipairs(pack.odds) do
			local tc = Tiers.get(o.key)
			local list = Config.MarblesByTier[o.key] or {}
			local names: { string } = {}
			for _, def in ipairs(list) do
				table.insert(names, (o.key == "Secret" and not idx[def.id]) and "???" or def.name)
			end
			line(string.format("%s  %s   ·  %d marbles, %s each", tc.name, Tiers.oddsLive(pack.odds, o, l), #list, Tiers.pct(ps[i] / math.max(1, #list))), tc.color, false, 24)
			line(table.concat(names, ", "), nil, true, #names > 7 and 38 or 20)
		end
		line("Mutation on every pull:  " .. mutationText(l), nil, true)
	end
	line("✨ SHINE MACHINE  ·  " .. Fmt.num(Config.Shine.cost) .. "💰", Color3.fromRGB(255, 214, 50), false, 30)
	for _, o in ipairs(Config.Shine.odds) do
		local m = Config.MutationByKey[o.key]
		line((m and (m.glyph .. " " .. m.name .. " x" .. m.mult .. " coins") or "No shine") .. "   " .. Tiers.oddsLive(Config.Shine.odds, o, l), m and m.color or Color3.fromRGB(190, 195, 210), false, 24)
	end
end
pOdds.onOpen = drawOdds

-- Shine panel ---------------------------------------------------------------------------------------------------
Hud.shineKey = ""
local shineGrid = UI.scroll(pShine.body, { Size = UDim2.new(0, 420, 1, 0) })
UI.grid(shineGrid, UDim2.fromOffset(92, 112), 8)
local shineSide = UI.frame(pShine.body, { BackgroundTransparency = 1, Size = UDim2.new(1, -436, 1, 0), Position = UDim2.new(0, 436, 0, 0) })
local shining = false
local drawShine: () -> ()

-- Paid shines can't be a roll under the paid random item restriction: those players get a fixed Gold shine
-- (dearer, shown before paying). The first shine is free and always Gold for everyone.
local function shineFree(): boolean
	return not (data.ftue and data.ftue.shine)
end

local function shineFixed(): boolean
	return not shineFree() and Store.blocked()
end

local function doShine()
	local key = Hud.shineKey
	local e = data.marbles and data.marbles[key]
	if shining or not e then
		return
	end
	shining = true
	task.spawn(function()
		local fixed = shineFixed()
		local ok, res = pcall(function()
			return shineFunc:InvokeServer(key, fixed)
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
		if (data.coins or 0) >= (shineFixed() and Config.Shine.fixedCost or Config.Shine.cost) then
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
	local free = shineFree()
	local fixed = shineFixed()
	if fixed then
		local m = Config.MutationByKey[Config.Shine.fixedMut]
		UI.text(shineSide, "THIS MARBLE BECOMES:", { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 172) })
		UI.text(shineSide, m and (m.glyph .. " " .. string.upper(m.name) .. "  x" .. m.mult .. " coins") or "", { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 202), TextColor3 = m and m.color or Color3.new(1, 1, 1) })
		body(shineSide, "Every time. No luck needed.", { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 248) })
	else
		-- live odds: with luck on, the normal % in grey and the boosted % in green
		local l = luck()
		local odds = Config.Shine.odds
		for i, o in ipairs(odds) do
			local m = Config.MutationByKey[o.key]
			oddsRow(shineSide, UDim2.fromOffset(0, 170 + (i - 1) * 30), UDim2.new(1, 0, 0, 26), m and (m.glyph .. " " .. m.name .. " x" .. m.mult) or "No shine", m and m.color or GREY, odds, o, l)
		end
		if l > 1 and not free then
			body(shineSide, string.format("🍀 Luck x%.3g is on!", l), { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 292), TextColor3 = Color3.fromRGB(30, 150, 60) })
		end
	end
	if free then
		body(shineSide, "First shine is FREE and always GOLD!", { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 296), TextColor3 = Color3.fromRGB(200, 120, 0) })
	elseif not (luck() > 1 and not fixed) then
		body(shineSide, "Mutated marbles keep their level and earn more coins.", { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 292), TextWrapped = true })
	end
	local cost = fixed and Config.Shine.fixedCost or Config.Shine.cost
	local label = free and "SHINE FREE!" or ((fixed and "GOLD SHINE  " or "SHINE  ") .. Fmt.num(cost) .. "💰")
	local b = UI.button(shineSide, label, free and "orange" or "gold", {
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.new(0, 0, 1, -64),
	})
	b.MouseButton1Click:Connect(doShine)
	shownLuck = luck()
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

-- Keep Streak: after missing a day with a streak of 2+, the old streak can be kept for the rest of that day.
local keepCard = UI.card(pDaily.body, "red", { Size = UDim2.new(1, 0, 0, 64), Position = UDim2.fromOffset(0, 208), Visible = false })
local keepText = UI.text(keepCard, "", { Size = UDim2.new(1, -200, 0, 50), Position = UDim2.fromOffset(12, 7), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true })
local keepBtn = UI.button(keepCard, "", "green", { Size = UDim2.fromOffset(170, 48), Position = UDim2.new(1, -180, 0, 8) })
keepBtn.MouseButton1Click:Connect(function()
	buy("product", "KeepStreak")
end)

local function drawDaily()
	clearKids(dailyRow)
	local broken = (data.daily or {}).broken
	keepCard.Visible = type(broken) == "table" and broken.day == today()
	if keepCard.Visible then
		keepText.Text = string.format("🔥 You missed a day! Keep your %d-day streak?", tonumber(broken.streak) or 0)
		keepBtn.Text = "KEEP IT  R$ " .. Config.Products.KeepStreak.price
	end
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
		local secs = (today() + 1) * 86400 - now()
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
	welcomeText.Text = string.format("Your marbles kept practicing for %s while you were away and earned\n%s 💰 coins!", Fmt.time(mins * 60), Fmt.commas(c))
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
		return { text = "🏁 First race! Tap BOOST when you glow!", button = nil, flip = false, station = "" }
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
		local lu = (tonumber(data.luckUntil) or 0) - now()
		bLuck.button.Visible = lu > 0
		if lu > 0 then
			bLuck.label.Text = Fmt.time(lu)
		end
		-- the offer button: no offers in a session's first minutes; the Starter Pack (with its countdown)
		-- while it lasts, then 2x Coins
		local starter = Store.starterLeft()
		local icon = bX2.icon :: any
		if owns("CoinsX2") then
			bX2.button.Visible = true
			icon.Text = I.x2
			bX2.label.Text = "2x ON"
		elseif Store.canOffer() and starter > 0 then
			bX2.button.Visible = true
			icon.Text = Config.Products.StarterPack.glyph
			bX2.label.Text = Fmt.time(starter)
		else
			bX2.button.Visible = Store.canOffer()
			icon.Text = I.x2
			bX2.label.Text = "2x"
		end
		-- live odds: redraw open odds screens when luck starts or runs out
		if luck() ~= shownLuck and not Reveal.isOpen() then
			if pPacks.isOpen() then
				drawPacks()
			end
			if pShine.isOpen() then
				drawShine()
			end
			if pOdds.isOpen() then
				drawOdds()
			end
		end
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

-- Purchase offers (Store): never in a session's first minutes, spaced out, only after a race ends.
function Hud.maybeOffer(lost: boolean)
	if not Reveal.isOpen() then
		Store.maybeOffer(lost)
	end
end

-- Odds screens follow the paid random item restriction and live prices.
local function redrawOdds()
	if pPacks.isOpen() and not Reveal.isOpen() then
		drawPacks()
	end
	if pShine.isOpen() and not Reveal.isOpen() then
		drawShine()
	end
	if pOdds.isOpen() then
		drawOdds()
	end
	if pDaily.isOpen() then
		drawDaily()
	end
end
player:GetAttributeChangedSignal("RandomBlocked"):Connect(redrawOdds)
Prices.onChange(redrawOdds)

return Hud

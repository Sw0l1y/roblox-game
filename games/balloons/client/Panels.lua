-- Menus: Upgrades, Shop (Passes / Boosts / Coins), Balloon Index (per zone, 3D previews, odds, set bonuses),
-- Zones (unlock + teleport), Rebirth, Daily Gift and the Welcome Back (offline pump earnings) card.
-- Every button only asks the server (Action / Buy remotes); panels redraw from State on every data push.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local Fmt = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Fmt"))
local Tiers = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tiers"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Econ = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Econ"))
local BalloonArt = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalloonArt"))
local UI = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("UI"))
local Sfx = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("Sfx"))
local State = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("State"))
local Hud = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("Hud"))

local Panels = {}

type PData = { [string]: any }

local I = Config.Icons
local actionRemote = Net.event("Action")
local buyRemote = Net.event("Buy")

local refreshers: { [string]: (PData) -> () } = {}
local tabSelect: { [string]: (string) -> () } = {}

local function topList(parent: Instance, pad: number?): UIListLayout
	local l = UI.list(parent, pad or 10)
	l.VerticalAlignment = Enum.VerticalAlignment.Top
	return l
end

local function body(parent: Instance, str: string, props: { [string]: any }?): TextLabel
	local l = UI.text(parent, str, { Font = UI.BODY })
	UI.set(l, props)
	return l
end

-- Plain dark text without the white outline look (for light panel backgrounds).
local function ink(parent: Instance, str: string, props: { [string]: any }?): TextLabel
	local l = UI.text(parent, str, { Font = UI.BODY, TextColor3 = UI.INK })
	local s = l:FindFirstChildOfClass("UIStroke")
	if s then
		s.Enabled = false
	end
	UI.set(l, props)
	return l
end

local function setButton(b: TextButton, text: string, color: any)
	b.Text = text
	UI.recolor(b, color)
end

---------------------------------------------------------------------------------------------------------------
-- Upgrades
---------------------------------------------------------------------------------------------------------------

type UpRow = { info: TextLabel, buy: TextButton, level: TextLabel }

local function buildUpgrades()
	local p = UI.panel("Upgrades", I.upgrades .. " UPGRADES", "blue", Vector2.new(680, 500))
	local list = UI.scroll(p.body, { Size = UDim2.new(1, 0, 1, -6) })
	topList(list, 10)
	local rows: { [string]: UpRow } = {}
	for i, key in ipairs(Config.UpgradeOrder) do
		local u = Config.Upgrades[key]
		local row = UI.card(list, u.color, { Name = key, Size = UDim2.new(1, -10, 0, 78), LayoutOrder = i })
		UI.text(row, u.glyph, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(58, 58), Position = UDim2.fromOffset(10, 10) })
		UI.text(row, u.name, { Size = UDim2.fromOffset(250, 30), Position = UDim2.fromOffset(78, 6), TextXAlignment = Enum.TextXAlignment.Left })
		local level = UI.text(row, "", { Size = UDim2.fromOffset(110, 26), Position = UDim2.fromOffset(300, 8), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.colors.yellow })
		local info = body(row, "", { Size = UDim2.fromOffset(330, 28), Position = UDim2.fromOffset(78, 42), TextXAlignment = Enum.TextXAlignment.Left })
		local buy = UI.button(row, "", "green", {
			Name = "Buy",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(170, 58),
		})
		buy.MouseButton1Click:Connect(function()
			actionRemote:FireServer("upgrade", key)
		end)
		rows[key] = { info = info, buy = buy, level = level }
	end
	refreshers.Upgrades = function(d: PData)
		for _, key in ipairs(Config.UpgradeOrder) do
			local u = Config.Upgrades[key]
			local r = rows[key]
			local lvl = Econ.level(d, key)
			local cur = Econ.upgradeText(key, Econ.upgradeValue(key, lvl))
			r.level.Text = "Lv " .. lvl .. "/" .. u.max
			if lvl >= u.max then
				r.info.Text = u.desc .. ": " .. cur .. " (MAX)"
				setButton(r.buy, "MAX", "grey")
			else
				local nxt = Econ.upgradeText(key, Econ.upgradeValue(key, lvl + 1))
				if key == "power" and Econ.has(d, "GoldenDart") then
					cur, nxt = cur .. " x3", nxt .. " x3"
				end
				r.info.Text = u.desc .. ": " .. cur .. "  →  " .. nxt
				local cost = Econ.upgradeCost(key, lvl)
				setButton(r.buy, I.coin .. " " .. Fmt.num(cost), (d.coins or 0) >= cost and "green" or "grey")
			end
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Shop
---------------------------------------------------------------------------------------------------------------

type ShopCard = { kind: string, key: string, frame: Frame, buy: TextButton, desc: TextLabel }

-- Catalog keys in display order; `coins` picks the coin packs (keys "Coins1".."Coins3") or everything else.
local function sortedKeys(cat: { [string]: Config.CatalogItem }, coins: boolean?): { string }
	local keys: { string } = {}
	for k in pairs(cat) do
		local isCoins = string.sub(k, 1, 5) == "Coins"
		if coins == nil or isCoins == coins then
			table.insert(keys, k)
		end
	end
	table.sort(keys, function(a: string, b: string): boolean
		return cat[a].order < cat[b].order
	end)
	return keys
end

local function buildShop()
	local p = UI.panel("Shop", I.shop .. " SHOP", "pink", Vector2.new(760, 520))
	local pages, select = UI.tabs(p.body, { "Passes", "Boosts", "Coins" }, { "gold", "green", "orange" })
	tabSelect.Shop = select
	local cards: { ShopCard } = {}

	local function addCard(page: Instance, kind: string, key: string, item: Config.CatalogItem): ()
		local f = UI.card(page, item.color, { Name = key, LayoutOrder = item.order })
		UI.text(f, item.glyph, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(64, 64), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8) })
		UI.text(f, item.name, { Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(8, 74) })
		local desc = body(f, item.desc, { Size = UDim2.new(1, -16, 0, 52), Position = UDim2.fromOffset(8, 104), TextScaled = true })
		local buy = UI.button(f, "R$ " .. item.price, "green", {
			Name = "Buy",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -24, 0, 46),
		})
		buy.MouseButton1Click:Connect(function()
			buyRemote:FireServer(kind, key)
		end)
		table.insert(cards, { kind = kind, key = key, frame = f, buy = buy, desc = desc })
	end

	local function grid(page: Frame): ScrollingFrame
		local s = UI.scroll(page, { Size = UDim2.new(1, 0, 1, -24) })
		UI.grid(s, UDim2.fromOffset(214, 232), 12)
		return s
	end

	local passGrid = grid(pages.Passes)
	for _, k in ipairs(sortedKeys(Config.Passes, nil)) do
		addCard(passGrid, "pass", k, Config.Passes[k])
	end
	local boostGrid = grid(pages.Boosts)
	for _, k in ipairs(sortedKeys(Config.Products, false)) do
		addCard(boostGrid, "product", k, Config.Products[k])
	end
	local coinGrid = grid(pages.Coins)
	for _, k in ipairs(sortedKeys(Config.Products, true)) do
		addCard(coinGrid, "product", k, Config.Products[k])
	end
	ink(pages.Passes, "⭐ Roblox Premium members get +10% coins", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 20),
	})

	refreshers.Shop = function(d: PData)
		for _, c in ipairs(cards) do
			if c.kind == "pass" then
				if Econ.has(d, c.key) then
					setButton(c.buy, "OWNED " .. I.check, "grey")
				else
					setButton(c.buy, "R$ " .. Config.Passes[c.key].price, "green")
				end
			else
				local item = Config.Products[c.key]
				if c.key == "Starter" then
					c.frame.Visible = not d.starter
					c.desc.Text = I.coin .. " " .. Fmt.num(Econ.packCoins(item.base or 2000, d)) .. " + 15 Mega Darts + 30 min Lucky Boost (once!)"
				elseif item.base then
					c.desc.Text = I.coin .. " " .. Fmt.num(Econ.packCoins(item.base, d)) .. " coins"
				end
			end
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Balloon Index
---------------------------------------------------------------------------------------------------------------

type IndexCard = {
	key: string,
	frame: Frame,
	vp: ViewportFrame,
	name: TextLabel,
	count: TextLabel,
	shown: boolean?,
	model: Model?,
}

local indexBuilt = false

local function buildIndex()
	local p = UI.panel("Index", I.index .. " BALLOON INDEX", "purple", Vector2.new(800, 540))
	local names = {}
	for _, z in ipairs(Config.Zones) do
		table.insert(names, z.glyph .. " " .. (string.split(z.name, " ")[1]))
	end
	local pages, select = UI.tabs(p.body, names, { "green", "pink", "sky", "purple" })
	tabSelect.Index = select
	local cards: { IndexCard } = {}
	local headers: { TextLabel } = {}
	local locks: { Frame } = {}

	for zi, z in ipairs(Config.Zones) do
		local page = pages[names[zi]]
		headers[zi] = ink(page, "", { Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Center })
		local s = UI.scroll(page, { Size = UDim2.new(1, 0, 1, -30), Position = UDim2.fromOffset(0, 30) })
		UI.grid(s, UDim2.fromOffset(170, 196), 10)
		for ti, key in ipairs(Config.ZoneTypes[zi]) do
			local def = Config.Balloons[key]
			local tier = Tiers.get(def.tier)
			local f = UI.card(s, tier.color, { Name = key, LayoutOrder = ti })
			local vp = Instance.new("ViewportFrame")
			vp.BackgroundTransparency = 1
			vp.Size = UDim2.new(1, -12, 0, 104)
			vp.Position = UDim2.fromOffset(6, 4)
			vp.Ambient = Color3.fromRGB(190, 190, 200)
			vp.LightColor = Color3.fromRGB(255, 255, 255)
			vp.LightDirection = Vector3.new(-0.4, -1, 0.6)
			vp.ZIndex = f.ZIndex + 1
			vp.Parent = f
			local cam = Instance.new("Camera")
			cam.FieldOfView = 34
			cam.CFrame = CFrame.lookAt(Vector3.new(0.6, 0.2, -9), Vector3.new(0, -0.5, 0))
			cam.Parent = vp
			vp.CurrentCamera = cam
			local nm = UI.text(f, "???", { Size = UDim2.new(1, -10, 0, 24), Position = UDim2.fromOffset(5, 108), ZIndex = f.ZIndex + 2 })
			local tl = UI.text(f, string.upper(tier.name), { Size = UDim2.new(1, -10, 0, 22), Position = UDim2.fromOffset(5, 132), ZIndex = f.ZIndex + 2 })
			local g = Instance.new("UIGradient")
			g.Color = Tiers.gradient(def.tier)
			g.Rotation = 90
			g.Parent = tl
			local count = body(f, Econ.odds(key), { Size = UDim2.new(1, -10, 0, 22), Position = UDim2.fromOffset(5, 158), ZIndex = f.ZIndex + 2 })
			table.insert(cards, { key = key, frame = f, vp = vp, name = nm, count = count })
		end
		local lock = UI.frame(page, {
			Name = "Lock",
			BackgroundColor3 = Color3.fromRGB(20, 22, 40),
			BackgroundTransparency = 0.35,
			Size = UDim2.new(1, 0, 1, -30),
			Position = UDim2.fromOffset(0, 30),
			ZIndex = 40,
			Visible = false,
		})
		UI.corner(lock, 16)
		UI.text(lock, I.lock .. " Unlock " .. z.name .. " to discover these balloons", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.8, 0, 0, 44),
			ZIndex = 41,
		})
		locks[zi] = lock
	end

	local function setModel(c: IndexCard, found: boolean)
		if c.shown == found and c.model then
			return
		end
		c.shown = found
		if c.model then
			c.model:Destroy()
		end
		local def = Config.Balloons[c.key]
		local m = BalloonArt.build(def, { size = 3, noString = true, silhouette = not found, shadow = false })
		m:PivotTo(CFrame.Angles(0, math.rad(found and 18 or 0), 0))
		m.Parent = c.vp
		c.model = m
	end

	refreshers.Index = function(d: PData)
		if not indexBuilt then
			return
		end
		local index: { [string]: number } = d.index or {}
		for _, c in ipairs(cards) do
			local def = Config.Balloons[c.key]
			local n = index[c.key] or 0
			setModel(c, n > 0)
			c.name.Text = n > 0 and def.name or "???"
			c.count.Text = (n > 0 and ("x" .. Fmt.num(n) .. " · ") or "") .. Econ.odds(c.key)
		end
		for zi, z in ipairs(Config.Zones) do
			local found, total, secret = Econ.zoneProgress(d, zi)
			local bonus = math.floor((Config.Index.setBonus[zi] or 0) * 100 + 0.5)
			local done = found >= total
			headers[zi].Text = string.format("%s Found %d/%d  ·  Complete the set: +%d%% coins forever %s  ·  Secret: +%d%% %s",
				z.glyph, found, total, bonus, done and I.check or "", math.floor(Config.Index.secretBonus * 100), secret and I.check or "❔")
			locks[zi].Visible = zi > (d.zones or 1)
		end
	end
	p.onOpen = function()
		indexBuilt = true
		Hud.clearIndexNew()
		local d = State.data
		if d then
			refreshers.Index(d)
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Zones
---------------------------------------------------------------------------------------------------------------

local function buildZones()
	local p = UI.panel("Zones", I.zones .. " ZONES", "teal", Vector2.new(680, 520))
	local list = UI.scroll(p.body)
	topList(list, 10)
	type ZRow = { info: TextLabel, btn: TextButton }
	local rows: { ZRow } = {}
	for i, z in ipairs(Config.Zones) do
		local row = UI.card(list, z.accent, { Name = z.key, Size = UDim2.new(1, -10, 0, 92), LayoutOrder = i })
		UI.text(row, z.glyph, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(66, 66), Position = UDim2.fromOffset(10, 13) })
		UI.text(row, z.name, { Size = UDim2.fromOffset(300, 34), Position = UDim2.fromOffset(86, 8), TextXAlignment = Enum.TextXAlignment.Left })
		local info = body(row, string.format("Balloons x%s coins · x%s HP", Fmt.num(z.valueMult), Fmt.num(z.hpMult)), {
			Size = UDim2.fromOffset(330, 28),
			Position = UDim2.fromOffset(86, 50),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local btn = UI.button(row, "", "green", {
			Name = "Go",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(190, 60),
		})
		btn.MouseButton1Click:Connect(function()
			local d = State.data
			if not d then
				return
			end
			if i <= (d.zones or 1) then
				actionRemote:FireServer("teleport", i)
				UI.closeAll()
			elseif i == (d.zones or 1) + 1 then
				actionRemote:FireServer("unlock", i)
			else
				UI.toast(I.lock .. " Unlock " .. Config.Zones[i - 1].name .. " first!", "orange")
				Sfx.play("error", 0.4)
			end
		end)
		rows[i] = { info = info, btn = btn }
	end
	refreshers.Zones = function(d: PData)
		local cur = d.zones or 1
		for i, z in ipairs(Config.Zones) do
			local r = rows[i]
			if i <= cur then
				setButton(r.btn, "TELEPORT", "green")
			elseif i == cur + 1 then
				setButton(r.btn, I.lock .. " " .. I.coin .. " " .. Fmt.num(z.cost), (d.coins or 0) >= z.cost and "gold" or "grey")
			else
				setButton(r.btn, I.lock .. " LOCKED", "grey")
			end
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Rebirth
---------------------------------------------------------------------------------------------------------------

local function buildRebirth()
	local p = UI.panel("Rebirth", I.rebirth .. " REBIRTH", "orange", Vector2.new(580, 470))
	local b = p.body
	local now = UI.text(b, "", { Size = UDim2.new(1, 0, 0, 46), Position = UDim2.fromOffset(0, 26), TextColor3 = UI.colors.yellow })
	local arrow = UI.text(b, "", { Size = UDim2.new(1, 0, 0, 38), Position = UDim2.fromOffset(0, 78) })
	ink(b, "Rebirth resets your coins.\nYou KEEP upgrades, zones, the Index, Mega Darts and passes.\nEvery rebirth adds a permanent coin multiplier!", {
		Size = UDim2.new(1, -20, 0, 90),
		Position = UDim2.fromOffset(10, 124),
	})
	local bar = UI.bar(b, "orange", { Size = UDim2.new(1, -60, 0, 34), Position = UDim2.fromOffset(30, 226) })
	local btn = UI.button(b, "REBIRTH!", "orange", {
		Name = "RebirthNow",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(260, 66),
	})
	btn.MouseButton1Click:Connect(function()
		actionRemote:FireServer("rebirth")
	end)
	refreshers.Rebirth = function(d: PData)
		local n = d.rebirths or 0
		local cost = Econ.rebirthCost(n)
		now.Text = "Rebirths: " .. n .. "   ·   x" .. string.format("%.1f", Econ.rebirthMult(n)) .. " coins"
		arrow.Text = "Next: x" .. string.format("%.1f", Econ.rebirthMult(n + 1)) .. " coins forever"
		bar.set((d.coins or 0) / cost, I.coin .. " " .. Fmt.num(d.coins or 0) .. " / " .. Fmt.num(cost))
		UI.recolor(btn, (d.coins or 0) >= cost and "orange" or "grey")
	end
end

---------------------------------------------------------------------------------------------------------------
-- Daily gift
---------------------------------------------------------------------------------------------------------------

local function buildDaily()
	local p = UI.panel("Daily", I.daily .. " DAILY GIFT", "green", Vector2.new(720, 400))
	local b = p.body
	local row = UI.frame(b, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 150), Position = UDim2.fromOffset(0, 26) })
	UI.list(row, 8, true)
	local tiles: { Frame } = {}
	local tileText: { TextLabel } = {}
	for i, r in ipairs(Config.Daily.rewards) do
		local t = UI.card(row, i == #Config.Daily.rewards and "gold" or "green", { Name = "Day" .. i, Size = UDim2.fromOffset(86, 140), LayoutOrder = i })
		UI.text(t, "Day " .. i, { Size = UDim2.new(1, -8, 0, 24), Position = UDim2.fromOffset(4, 6) })
		local extra = (r.megaDarts and (I.megaDart .. r.megaDarts)) or (r.luckMinutes and (I.luck .. r.luckMinutes .. "m")) or I.coin
		UI.text(t, extra, { Font = Enum.Font.GothamBold, Size = UDim2.new(1, -8, 0, 46), Position = UDim2.fromOffset(4, 34) })
		tileText[i] = body(t, "", { Size = UDim2.new(1, -8, 0, 40), Position = UDim2.fromOffset(4, 90) })
		tiles[i] = t
	end
	local status = ink(b, "", { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 186) })
	local claim = UI.button(b, "CLAIM!", "green", {
		Name = "Claim",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(240, 64),
	})
	claim.MouseButton1Click:Connect(function()
		actionRemote:FireServer("daily")
	end)
	refreshers.Daily = function(d: PData)
		local now = math.floor(workspace:GetServerTimeNow()) -- server clock (the device clock can be off)
		local last = d.daily and tonumber(d.daily.last) or 0
		local streak = d.daily and tonumber(d.daily.streak) or 0
		local left = Config.Daily.cooldown - (now - (last or 0))
		local nextDay = ((now - (last or 0)) > Config.Daily.resetAfter) and 1 or ((streak or 0) % #Config.Daily.rewards + 1)
		for i, t in ipairs(tiles) do
			tileText[i].Text = I.coin .. Fmt.num(Econ.dailyCoins(i, d))
			t.BackgroundTransparency = (i < nextDay) and 0.5 or 0
			local s = t:FindFirstChildOfClass("UIStroke")
			if s then
				s.Color = (i == nextDay) and UI.colors.yellow or UI.INK
				s.Thickness = (i == nextDay) and 5 or 3.5
			end
		end
		if left <= 0 then
			status.Text = "Day " .. nextDay .. " gift is ready! Come back every day for bigger gifts."
			setButton(claim, "CLAIM!", "green")
		else
			status.Text = "Next gift in " .. Fmt.time(left) .. (Econ.has(d, "VIP") and "  ·  👑 VIP: 2x coins" or "")
			setButton(claim, I.clock .. " " .. Fmt.time(left), "grey")
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Welcome back (offline earnings)
---------------------------------------------------------------------------------------------------------------

local welcomeText: TextLabel? = nil

local function buildWelcome()
	local p = UI.panel("Welcome", "WELCOME BACK!", "green", Vector2.new(520, 330))
	UI.text(p.body, I.pump, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(84, 84), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20) })
	welcomeText = ink(p.body, "", { Size = UDim2.new(1, -20, 0, 90), Position = UDim2.fromOffset(10, 108) })
	local ok = UI.button(p.body, "AWESOME!", "green", {
		Name = "Ok",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(220, 60),
	})
	ok.MouseButton1Click:Connect(function()
		p.close()
	end)
end

function Panels.welcome(gain: number, away: number)
	local p = UI.getPanel("Welcome")
	local t = welcomeText
	if not p or not t then
		return
	end
	t.Text = "Your Balloon Pump filled up with " .. I.coin .. " " .. Fmt.num(gain) .. " while you were away (" .. Fmt.time(away) .. ")!\nWalk to your pump in the hub to collect it."
	p.open()
	Sfx.play("cash", 0.5)
end

---------------------------------------------------------------------------------------------------------------

function Panels.open(name: string, tab: string?)
	local p = UI.getPanel(name)
	if not p then
		return
	end
	p.open()
	local sel = tabSelect[name]
	if tab and sel then
		sel(tab)
	end
	local d = State.data
	local r = refreshers[name]
	if d and r then
		r(d)
	end
end

function Panels.toggle(name: string)
	local p = UI.getPanel(name)
	if p and p.isOpen() then
		p.close()
	else
		Panels.open(name)
	end
end

function Panels.isOpen(name: string): boolean
	local p = UI.getPanel(name)
	return p ~= nil and p.isOpen()
end

function Panels.anyOpen(): boolean
	for _, n in ipairs({ "Upgrades", "Shop", "Index", "Zones", "Rebirth", "Daily", "Welcome", "__offer" }) do
		if Panels.isOpen(n) then
			return true
		end
	end
	return false
end

function Panels.refresh()
	local d = State.data
	if not d then
		return
	end
	for name, fn in pairs(refreshers) do
		if name == "Index" or Panels.isOpen(name) then
			fn(d)
		end
	end
end

function Panels.init()
	buildUpgrades()
	buildShop()
	buildIndex()
	buildZones()
	buildRebirth()
	buildDaily()
	buildWelcome()
	State.onChange(function()
		Panels.refresh()
	end)
	-- the daily timer ticks while its panel is open
	task.spawn(function()
		while true do
			task.wait(1)
			local d = State.data
			if d and Panels.isOpen("Daily") and refreshers.Daily then
				refreshers.Daily(d)
			end
		end
	end)
end

return Panels

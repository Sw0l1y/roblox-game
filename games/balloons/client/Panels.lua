-- Menus: Upgrades, Shop (Passes with TRY / GIFT, Items, Server boosts, Coins), the live Odds sheet of every
-- luck item, the Starter Pack offer (first 10 minutes, with its countdown), Balloon Index (per zone, 3D previews,
-- live odds, set bonuses), Zones (unlock + teleport), Rebirth, Daily Gift and the Welcome Back card.
-- Every button only asks the server (Action / Buy remotes); panels redraw from State on every data push.
-- Paid random rule: luck is the only paid random in the game (it changes which balloons spawn). Luck items show
-- their live odds (NOW vs WITH IT) and are hidden for players under the paid random item restriction.
local Players = game:GetService("Players")
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
local LiveUI = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("LiveUI"))

local Panels = {}

type PData = { [string]: any }

local I = Config.Icons
local player = Players.LocalPlayer
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

-- Roblox's paid random item restriction for this player (kit Policy attribute; restricted until it loads).
local function blocked(): boolean
	return player:GetAttribute("RandomBlocked") ~= false
end

local function luckNow(d: PData?): number
	return Econ.luck(d, Econ.now(), blocked())
end

-- Planned price from Config until kit Prices.sync writes the live one (regional pricing) into the catalog.
local function robux(item: Config.CatalogItem): string
	return "R$ " .. Fmt.commas(item.price)
end

-- What each paid luck item adds (its odds sheet compares NOW with WITH IT).
local LUCK_WITH: { [string]: Econ.LuckWith } = {
	Lucky = { lucky = true },
	LuckBoost = { boost = true },
	Starter = { boost = true },
	LuckServer2 = { server = 2 },
	LuckServer4 = { server = 4 },
}

local function catalogItem(key: string): Config.CatalogItem?
	return Config.Passes[key] or Config.Products[key]
end

-- The zone whose odds we show: the one the player stands in, else their best zone.
local function oddsZoneFor(d: PData?): number
	local best = math.clamp(d and tonumber(d.zones) or 1, 1, #Config.Zones)
	if Hud.zone >= 1 and Hud.zone <= best then
		return Hud.zone
	end
	return best
end

-- "🌟 Secret 0.05% → 0.11% 🍀": the zone's rarest balloon now and with this luck item.
local function topOddsLine(d: PData?, key: string): string
	local z = oddsZoneFor(d)
	local now = Econ.zoneOdds(z, luckNow(d))
	local with = Econ.zoneOdds(z, Econ.luck(d, Econ.now(), blocked(), LUCK_WITH[key]))
	local top = now[#now]
	if not top then
		return ""
	end
	local a, b = Tiers.pct(top.pct), Tiers.pct(with[#with].pct)
	return "🌟 " .. Tiers.get(top.tier).name .. " " .. a .. (a ~= b and ("  →  " .. b .. " " .. I.luck) or "")
end

---------------------------------------------------------------------------------------------------------------
-- Upgrades
---------------------------------------------------------------------------------------------------------------

type UpRow = { frame: Frame, info: TextLabel, buy: TextButton, level: TextLabel }

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
		rows[key] = { frame = row, info = info, buy = buy, level = level }
	end
	refreshers.Upgrades = function(d: PData)
		for _, key in ipairs(Config.UpgradeOrder) do
			local u = Config.Upgrades[key]
			local r = rows[key]
			-- coins are sold for Robux, so coin-bought luck is paid random too: not offered under the restriction
			r.frame.Visible = not (key == "luck" and blocked())
			local lvl = Econ.level(d, key)
			local cur = Econ.upgradeText(key, Econ.upgradeValue(key, lvl))
			r.level.Text = "Lv " .. lvl .. "/" .. u.max
			if lvl >= u.max then
				r.info.Text = u.desc .. ": " .. cur .. " (MAX)"
				setButton(r.buy, "MAX", "grey")
			else
				local nxt = Econ.upgradeText(key, Econ.upgradeValue(key, lvl + 1))
				if key == "power" and Econ.perk(d, "GoldenDart") then
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

type ShopCard = {
	kind: string,
	key: string,
	frame: Frame,
	buy: TextButton,
	desc: TextLabel,
	extra: TextLabel,
	try: TextButton?,
	gift: TextButton?,
	odds: TextButton?,
}

-- Catalog keys of one shop tab (nil = passes) in display order.
local function sortedKeys(cat: { [string]: Config.CatalogItem }, tab: string?): { string }
	local keys: { string } = {}
	for k, item in pairs(cat) do
		if item.tab == tab then
			table.insert(keys, k)
		end
	end
	table.sort(keys, function(a: string, b: string): boolean
		return cat[a].order < cat[b].order
	end)
	return keys
end

-- "⚡ 2x COINS 12:04 left" for a running server boost of this kind, else nil.
local function boostRunning(kind: string): string?
	local ends = ReplicatedStorage:GetAttribute("BoostEnd_" .. kind)
	local m = Econ.boostMult(kind)
	if type(ends) ~= "number" or m <= 1 then
		return nil
	end
	return "⚡ " .. Fmt.num(m) .. "x running: " .. Fmt.time(math.max(0, math.floor(ends - Econ.now())))
end

local function buildShop()
	local p = UI.panel("Shop", I.shop .. " SHOP", "pink", Vector2.new(760, 560))
	local pages, select = UI.tabs(p.body, { "Passes", "Items", "Server", "Coins" }, { "gold", "pink", "purple", "orange" })
	tabSelect.Shop = select
	local cards: { ShopCard } = {}
	local notes: { [string]: TextLabel } = {}

	local function addCard(page: Instance, kind: string, key: string, item: Config.CatalogItem): ()
		local f = UI.card(page, item.color, { Name = key, LayoutOrder = item.order })
		UI.text(f, item.glyph, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(56, 56), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6) })
		UI.text(f, item.name, { Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 64) })
		local desc = body(f, item.desc, { Size = UDim2.new(1, -16, 0, 48), Position = UDim2.fromOffset(8, 92) })
		local extra = body(f, "", { Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 142), TextColor3 = UI.colors.yellow })
		-- small buttons: TRY (tool trial) and GIFT next to a pass, ODDS on every luck item
		local row = UI.frame(f, { Name = "Row", BackgroundTransparency = 1, Size = UDim2.new(1, -12, 0, 40), Position = UDim2.fromOffset(6, 164) })
		UI.list(row, 8, true, Enum.HorizontalAlignment.Center)
		local card: ShopCard = { kind = kind, key = key, frame = f, buy = nil :: any, desc = desc, extra = extra }
		local trialKey = kind == "pass" and Config.TrialFor[key]
		if trialKey then
			local t = UI.button(row, "TRY", "sky", { Name = "Try", Size = UDim2.fromOffset(92, 38), LayoutOrder = 1 })
			t.MouseButton1Click:Connect(function()
				buyRemote:FireServer("product", trialKey)
			end)
			card.try = t
		end
		if item.random then
			local o = UI.button(row, I.odds .. " ODDS", "teal", { Name = "Odds", Size = UDim2.fromOffset(92, 38), LayoutOrder = 2 })
			o.MouseButton1Click:Connect(function()
				Panels.showOdds(key)
			end)
			card.odds = o
		end
		local giftKey = kind == "pass" and Config.GiftFor[key]
		if giftKey then
			local g = UI.button(row, I.gift .. " GIFT", "pink", { Name = "Gift", Size = UDim2.fromOffset(92, 38), LayoutOrder = 3 })
			g.MouseButton1Click:Connect(function()
				LiveUI.gift(giftKey, "GIFT " .. string.upper(item.name))
			end)
			card.gift = g
		end
		local buy = UI.button(f, robux(item), "green", {
			Name = "Buy",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -24, 0, 46),
		})
		buy.MouseButton1Click:Connect(function()
			buyRemote:FireServer(kind, key)
		end)
		card.buy = buy
		table.insert(cards, card)
	end

	local function grid(page: Frame, note: string): ScrollingFrame
		local s = UI.scroll(page, { Size = UDim2.new(1, 0, 1, -26) })
		UI.grid(s, UDim2.fromOffset(214, 266), 12)
		notes[page.Name] = ink(page, note, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 22),
		})
		return s
	end

	local passGrid = grid(pages.Passes, "⭐ Premium: +10% coins  ·  TRY a pass for 15 min  ·  GIFT it to anyone here")
	for _, k in ipairs(sortedKeys(Config.Passes, nil)) do
		addCard(passGrid, "pass", k, Config.Passes[k])
	end
	local itemGrid = grid(pages.Items, "")
	for _, k in ipairs(sortedKeys(Config.Products, "items")) do
		addCard(itemGrid, "product", k, Config.Products[k])
	end
	local serverGrid = grid(pages.Server, "⚡ For EVERYONE here for 15 min. Bigger boosts unlock while a smaller one runs!")
	for _, k in ipairs(sortedKeys(Config.Products, "server")) do
		addCard(serverGrid, "product", k, Config.Products[k])
	end
	local coinGrid = grid(pages.Coins, I.coin .. " Packs grow with your best zone and your rebirths")
	for _, k in ipairs(sortedKeys(Config.Products, "coins")) do
		addCard(coinGrid, "product", k, Config.Products[k])
	end

	refreshers.Shop = function(d: PData)
		local isBlocked = blocked()
		notes.Items.Text = isBlocked and (I.megaDart .. " Mega Darts pop everything around the target")
			or (I.odds .. " Luck items show their live odds: tap ODDS")
		for _, c in ipairs(cards) do
			local item = catalogItem(c.key)
			if not item then
				continue
			end
			-- paid random (luck) is hidden for players under the restriction (the kit refuses it too)
			c.frame.Visible = not (item.random and isBlocked)
			local extra = ""
			if c.odds then
				extra = topOddsLine(d, c.key)
			end
			if c.kind == "pass" then
				local owned = Econ.has(d, c.key)
				if owned then
					setButton(c.buy, "OWNED " .. I.check, "grey")
				else
					setButton(c.buy, robux(item), "green")
				end
				local trialKey = Config.TrialFor[c.key]
				local t = c.try
				if t and trialKey then
					local left = Econ.trialLeft(d, c.key)
					t.Visible = not owned
					if left > 0 then
						setButton(t, I.clock .. " " .. Fmt.time(math.floor(left)), "teal")
						extra = "Trial: " .. Fmt.time(math.floor(left)) .. " left"
					else
						setButton(t, "TRY R$" .. Config.Products[trialKey].price, "sky")
					end
				end
				local g = c.gift
				local giftKey = Config.GiftFor[c.key]
				if g and giftKey then
					local credits = d.giftCredits and tonumber(d.giftCredits[c.key]) or 0
					g.Visible = not (Config.Products[giftKey].random and isBlocked)
					g.Text = (credits or 0) > 0 and (I.gift .. " SEND") or (I.gift .. " GIFT")
				end
			else
				local amount = item.base and Econ.packCoins(item.base, d)
				if c.key == "Starter" then
					local left = Econ.starterLeft(d)
					c.frame.Visible = left > 0
					c.desc.Text = I.coin .. " " .. Fmt.num(amount or 0) .. " + "
						.. (isBlocked and "25 Mega Darts (once!)" or "15 Mega Darts + 30 min Lucky Boost (once!)")
					extra = I.clock .. " Ends in " .. Fmt.time(math.floor(left))
				elseif c.key == "Intro" then
					c.frame.Visible = Econ.introOpen(d)
					c.desc.Text = I.coin .. " " .. Fmt.num(amount or 0) .. " + " .. (item.darts or 10) .. " Mega Darts. Only once, for new players!"
				elseif item.tab == "coins" and amount then
					c.desc.Text = I.coin .. " " .. Fmt.num(amount) .. " coins"
				elseif c.key == "LuckBoost" then
					local left = (tonumber(d.luckUntil) or 0) - Econ.now()
					if left > 0 then
						extra = I.luck .. " Running: " .. Fmt.time(math.floor(left)) .. " (buy more time)"
					end
				end
				local boost = item.boost
				local color = "green"
				if boost then
					if boost.needs and Econ.boostMult(boost.kind) < boost.needs then
						color = "grey"
						extra = I.lock .. " Unlocks while a " .. boost.needs .. "x runs"
					elseif not c.odds then
						extra = boostRunning(boost.kind) or ""
					end
				end
				setButton(c.buy, robux(item), color)
			end
			c.extra.Text = extra
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Odds sheet: every balloon of a zone with its spawn chance NOW and WITH a luck item (paid random rule)
---------------------------------------------------------------------------------------------------------------

type OddsRow = { frame: Frame, name: TextLabel, now: TextLabel, with: TextLabel }

local oddsKey: string? = nil
local oddsZone = 1

local function buildOdds()
	local p = UI.panel("Odds", I.odds .. " BALLOON ODDS", "teal", Vector2.new(660, 560))
	local b = p.body
	local zoneRow = UI.frame(b, { Name = "ZonePick", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 20) })
	UI.list(zoneRow, 10, true, Enum.HorizontalAlignment.Center)
	local zoneButtons: { TextButton } = {}
	for zi, z in ipairs(Config.Zones) do
		local zb = UI.button(zoneRow, z.glyph .. " " .. string.split(z.name, " ")[1], "sky", { Size = UDim2.fromOffset(132, 38), LayoutOrder = zi })
		zb.MouseButton1Click:Connect(function()
			oddsZone = zi
			local d = State.data
			local fn = refreshers.Odds
			if d and fn then
				fn(d)
			end
		end)
		zoneButtons[zi] = zb
	end
	local sub = ink(b, "", { Size = UDim2.new(1, -10, 0, 26), Position = UDim2.fromOffset(5, 66) })
	local head = UI.frame(b, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 96) })
	ink(head, "BALLOON", { Size = UDim2.new(0.5, -12, 1, 0), Position = UDim2.fromOffset(12, 0), TextXAlignment = Enum.TextXAlignment.Left })
	ink(head, "NOW", { Size = UDim2.new(0.22, 0, 1, 0), Position = UDim2.fromScale(0.5, 0) })
	local withHead = ink(head, "WITH IT", { Size = UDim2.new(0.26, 0, 1, 0), Position = UDim2.fromScale(0.73, 0) })
	local rows: { OddsRow } = {}
	for i = 1, #Config.TierOrder do
		local f = UI.card(b, "white", { Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 122 + (i - 1) * 40) })
		local nm = UI.text(f, "", { Font = UI.BODY, Size = UDim2.new(0.5, -14, 0, 26), Position = UDim2.new(0, 12, 0.5, -13), TextXAlignment = Enum.TextXAlignment.Left })
		local now = UI.text(f, "", { Font = UI.BODY, Size = UDim2.new(0.22, 0, 0, 26), Position = UDim2.new(0.5, 0, 0.5, -13) })
		local with = UI.text(f, "", { Font = UI.BODY, Size = UDim2.new(0.26, 0, 0, 26), Position = UDim2.new(0.73, 0, 0.5, -13), TextColor3 = UI.colors.yellow })
		rows[i] = { frame = f, name = nm, now = now, with = with }
	end
	local note = ink(b, "", { Size = UDim2.new(1, -10, 0, 22), Position = UDim2.fromOffset(5, 122 + #Config.TierOrder * 40) })
	local buy = UI.button(b, "", "green", {
		Name = "Buy",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.fromOffset(240, 46),
	})
	buy.MouseButton1Click:Connect(function()
		local key = oddsKey
		local item = key and catalogItem(key)
		if not key or not item then
			Panels.open("Shop", "Items")
			return
		end
		p.close()
		buyRemote:FireServer(Config.Passes[key] and "pass" or "product", key)
	end)

	refreshers.Odds = function(d: PData)
		local key = oddsKey
		local item = key and catalogItem(key)
		local isBlocked = blocked()
		local showWith = item ~= nil and not isBlocked
		local luck = luckNow(d)
		local withLuck = showWith and Econ.luck(d, Econ.now(), isBlocked, LUCK_WITH[key or ""]) or luck
		local now = Econ.zoneOdds(oddsZone, luck)
		local with = Econ.zoneOdds(oddsZone, withLuck)
		local index: { [string]: number } = d.index or {}
		for zi, zb in ipairs(zoneButtons) do
			UI.recolor(zb, zi == oddsZone and "gold" or "sky")
		end
		local zname = Config.Zones[oddsZone].name
		if showWith and item then
			sub.Text = item.name .. ": luck x" .. string.format("%.2f", luck) .. "  →  x" .. string.format("%.2f", withLuck) .. " in " .. zname
		else
			sub.Text = "Your luck: x" .. string.format("%.2f", luck) .. ". Chance of each balloon in " .. zname
		end
		withHead.Visible = showWith
		for i, r in ipairs(rows) do
			local e = now[i]
			r.frame.Visible = e ~= nil
			if e then
				local tier = Tiers.get(e.tier)
				local found = (index[e.key] or 0) > 0
				UI.recolor(r.frame, tier.color)
				-- names stay hidden until found (Secrets too), the chance is always shown
				r.name.Text = string.upper(tier.name) .. ": " .. (found and Config.Balloons[e.key].name or "???")
				r.now.Text = Tiers.pct(e.pct)
				r.with.Visible = showWith
				r.with.Text = Tiers.pct(with[i].pct) .. (with[i].pct > e.pct and (" " .. I.luck) or "")
			end
		end
		note.Text = "All " .. #now .. " add up to 100%. Luck makes rarer balloons spawn near you."
		if isBlocked then
			buy.Visible = false
		elseif key and item then
			buy.Visible = true
			local owned = Config.Passes[key] ~= nil and Econ.has(d, key)
			setButton(buy, owned and ("OWNED " .. I.check) or ("BUY " .. robux(item)), owned and "grey" or "green")
		else
			buy.Visible = true
			setButton(buy, I.luck .. " LUCK ITEMS", "pink")
		end
	end
end

-- Open the odds sheet for a luck item (nil = just the player's own odds) on the zone they are in.
function Panels.showOdds(key: string?)
	oddsKey = key
	oddsZone = oddsZoneFor(State.data)
	Panels.open("Odds")
end

---------------------------------------------------------------------------------------------------------------
-- Starter Pack offer (first 10 minutes after the first join, with its countdown)
---------------------------------------------------------------------------------------------------------------

local function buildStarter()
	local item = Config.Products.Starter
	local p = UI.panel("Starter", item.glyph .. " STARTER PACK", "teal", Vector2.new(540, 440))
	local b = p.body
	UI.text(b, item.glyph, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(84, 84), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 22) })
	local contents = ink(b, "", { Size = UDim2.new(1, -20, 0, 100), Position = UDim2.fromOffset(10, 110) })
	local timer = UI.text(b, "", { Size = UDim2.new(1, -20, 0, 32), Position = UDim2.fromOffset(10, 216), TextColor3 = UI.colors.red })
	local buy = UI.button(b, "", "green", {
		Name = "Buy",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(240, 64),
	})
	buy.MouseButton1Click:Connect(function()
		p.close()
		buyRemote:FireServer("product", "Starter")
	end)
	local odds = UI.button(b, I.odds .. " ODDS", "sky", {
		Name = "Odds",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -4, 1, -20),
		Size = UDim2.fromOffset(108, 46),
	})
	odds.MouseButton1Click:Connect(function()
		Panels.showOdds("Starter")
	end)
	refreshers.Starter = function(d: PData)
		local left = Econ.starterLeft(d)
		if left <= 0 then
			p.close()
			return
		end
		local isBlocked = blocked()
		local coins = I.coin .. " " .. Fmt.num(Econ.packCoins(item.base or 2000, d)) .. " coins"
		if isBlocked then
			contents.Text = coins .. "\n" .. I.megaDart .. " 25 Mega Darts\nOnly once!"
		else
			contents.Text = coins .. "\n" .. I.megaDart .. " " .. (item.darts or 15) .. " Mega Darts\n" .. I.luck .. " 30 min Lucky Boost (x2 luck)"
		end
		odds.Visible = not isBlocked
		timer.Text = I.clock .. " Only in your first 10 minutes: " .. Fmt.time(math.floor(left))
		setButton(buy, robux(item), "green")
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
	odds: TextLabel,
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
	local luckLines: { TextLabel } = {}
	local locks: { Frame } = {}

	for zi, z in ipairs(Config.Zones) do
		local page = pages[names[zi]]
		headers[zi] = ink(page, "", { Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center })
		luckLines[zi] = ink(page, "", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 25), TextXAlignment = Enum.TextXAlignment.Center })
		local s = UI.scroll(page, { Size = UDim2.new(1, 0, 1, -48), Position = UDim2.fromOffset(0, 48) })
		UI.grid(s, UDim2.fromOffset(170, 214), 10)
		for ti, key in ipairs(Config.ZoneTypes[zi]) do
			local def = Config.Balloons[key]
			local tier = Tiers.get(def.tier)
			local f = UI.card(s, tier.color, { Name = key, LayoutOrder = ti })
			local vp = Instance.new("ViewportFrame")
			vp.BackgroundTransparency = 1
			vp.Size = UDim2.new(1, -12, 0, 96)
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
			local nm = UI.text(f, "???", { Size = UDim2.new(1, -10, 0, 24), Position = UDim2.fromOffset(5, 100), ZIndex = f.ZIndex + 2 })
			local tl = UI.text(f, string.upper(tier.name), { Size = UDim2.new(1, -10, 0, 22), Position = UDim2.fromOffset(5, 124), ZIndex = f.ZIndex + 2 })
			local g = Instance.new("UIGradient")
			g.Color = Tiers.gradient(def.tier)
			g.Rotation = 90
			g.Parent = tl
			local count = body(f, "", { Size = UDim2.new(1, -10, 0, 22), Position = UDim2.fromOffset(5, 148), ZIndex = f.ZIndex + 2 })
			local odds = body(f, Econ.odds(key), { Size = UDim2.new(1, -10, 0, 26), Position = UDim2.fromOffset(5, 176), ZIndex = f.ZIndex + 2, TextColor3 = UI.colors.yellow })
			table.insert(cards, { key = key, frame = f, vp = vp, name = nm, count = count, odds = odds })
		end
		local lock = UI.frame(page, {
			Name = "Lock",
			BackgroundColor3 = Color3.fromRGB(20, 22, 40),
			BackgroundTransparency = 0.35,
			Size = UDim2.new(1, 0, 1, -48),
			Position = UDim2.fromOffset(0, 48),
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
		local luck = luckNow(d)
		for _, c in ipairs(cards) do
			local def = Config.Balloons[c.key]
			local n = index[c.key] or 0
			setModel(c, n > 0)
			c.name.Text = n > 0 and def.name or "???"
			c.count.Text = n > 0 and ("Popped x" .. Fmt.num(n)) or "Not found yet"
			c.odds.Text = Econ.odds(c.key, luck) -- base chance, then the chance at this player's luck
		end
		local luckText = I.luck .. " Your luck x" .. string.format("%.2f", luck) .. ": the chances show base  →  with your luck"
		if luck == 1 then
			luckText = I.odds .. " Chance of each balloon spawning in its zone (they add up to 100%)"
		end
		for zi, z in ipairs(Config.Zones) do
			local found, total, secret = Econ.zoneProgress(d, zi)
			local bonus = math.floor((Config.Index.setBonus[zi] or 0) * 100 + 0.5)
			local done = found >= total
			headers[zi].Text = string.format("%s Found %d/%d  ·  Complete the set: +%d%% coins forever %s  ·  Secret: +%d%% %s",
				z.glyph, found, total, bonus, done and I.check or "", math.floor(Config.Index.secretBonus * 100), secret and I.check or "❔")
			luckLines[zi].Text = luckText
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
	type ZRow = { info: TextLabel, btn: TextButton, stats: string }
	local rows: { ZRow } = {}
	for i, z in ipairs(Config.Zones) do
		local row = UI.card(list, z.accent, { Name = z.key, Size = UDim2.new(1, -10, 0, 92), LayoutOrder = i })
		UI.text(row, z.glyph, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(66, 66), Position = UDim2.fromOffset(10, 13) })
		UI.text(row, z.name, { Size = UDim2.fromOffset(300, 34), Position = UDim2.fromOffset(86, 8), TextXAlignment = Enum.TextXAlignment.Left })
		local stats = string.format("Balloons x%s coins · x%s HP", Fmt.num(z.valueMult), Fmt.num(z.hpMult))
		local info = body(row, stats, {
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
		rows[i] = { info = info, btn = btn, stats = stats }
	end
	refreshers.Zones = function(d: PData)
		local cur = d.zones or 1
		for i, z in ipairs(Config.Zones) do
			local r = rows[i]
			r.info.Text = r.stats
			if i <= cur then
				setButton(r.btn, "TELEPORT", "green")
			elseif i == cur + 1 then
				-- the free way in: beat the previous zone's boss (fill its "popped %" meter first)
				r.info.Text = "Buy it, or beat the " .. I.boss .. " " .. Config.Zones[i - 1].name .. " BOSS (" .. math.floor(Econ.meterFrac(d, i - 1) * 100) .. "%)"
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
	for _, n in ipairs({ "Upgrades", "Shop", "Odds", "Starter", "Index", "Zones", "Rebirth", "Daily", "Welcome", "Live", "LiveGift", "__offer" }) do
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
	buildOdds()
	buildStarter()
	buildIndex()
	buildZones()
	buildRebirth()
	buildDaily()
	buildWelcome()
	State.onChange(function()
		Panels.refresh()
	end)
	player:GetAttributeChangedSignal("RandomBlocked"):Connect(Panels.refresh)
	-- timers (daily gift, trials, boosts, the Starter countdown) and live odds tick while their panel is open
	task.spawn(function()
		while true do
			task.wait(1)
			local d = State.data
			if d then
				for _, name in ipairs({ "Daily", "Shop", "Odds", "Starter", "Index" }) do
					local fn = refreshers[name]
					if fn and Panels.isOpen(name) then
						fn(d)
					end
				end
			end
		end
	end)
end

return Panels

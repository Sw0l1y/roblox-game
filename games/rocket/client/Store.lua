-- The shop panel ("Shop": Strength / Boosts / Passes / Skins / Coins) and the buy helpers the HUD and offers use.
-- Strength steps are shown as skips of free launch unlocks; server boosts (coins, luck with live odds, a strength
-- ladder up to x1024), rocket products (fuel, +parts, the next rocket's tier, supply drop) and Zero-G minutes;
-- perk passes and skins each with a GIFT button (kit gift products); coin packs, the 9 R$ Rookie Deal (players who
-- never bought anything) and the Starter Pack (first 10 minutes of a player's first session, with a countdown).
-- Paid random items (luck boosts) are hidden for players under Roblox's paid random item restriction.
-- Prices are the live ones (kit Prices) and the open page redraws when they change.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local Fmt = require(Shared:WaitForChild("Fmt"))
local Net = require(Shared:WaitForChild("Net"))
local ClientLib = ReplicatedStorage:WaitForChild("ClientLib")
local UI = require(ClientLib:WaitForChild("UI"))
local Sfx = require(ClientLib:WaitForChild("Sfx"))
local State = require(ClientLib:WaitForChild("State"))
local LiveUI = require(ClientLib:WaitForChild("LiveUI"))
local Hub = require(ClientLib:WaitForChild("Hub"))

local Store = {}

local T = Config.Tune
local I = Config.Icons
local player = Players.LocalPlayer
local buyRemote = Net.event("Buy")
local skinRemote = Net.event("Skin")
local passes = Config.Passes :: { [string]: any }
local products = Config.Products :: { [string]: any }

-- Ownership and eligibility -------------------------------------------------------------------------------------

function Store.owns(key: string): boolean
	local d = State.data
	local p: any = d and d.passes
	return type(p) == "table" and p[key] == true
end

-- `once` products (Starter Pack, Rookie Deal, first top pack) this player already bought.
function Store.boughtOnce(key: string): boolean
	local d = State.data
	local b: any = d and d.bought
	return (type(b) == "table" and b[key] == true) or (key == "StarterPack" and d ~= nil and d.starter == true)
end

-- Seconds left to buy the Starter Pack: the first 10 minutes after the first join, first session only.
function Store.starterLeft(): number
	local d = State.data
	if not d or Store.boughtOnce("StarterPack") or (tonumber(d.sessions) or 1) > 1 then
		return 0
	end
	local first = tonumber(d.firstJoin)
	if not first then
		return 0
	end
	return math.max(0, first + T.starterWindow - os.time())
end

-- The 9 R$ Rookie Deal: only for players who never bought anything.
function Store.introOk(): boolean
	local d = State.data
	return d ~= nil and (tonumber(d.spent) or 0) == 0 and not Store.boughtOnce("Intro9")
end

function Store.randomBlocked(): boolean
	return player:GetAttribute("RandomBlocked") ~= false
end

function Store.buy(kind: string, key: string)
	local item = (if kind == "pass" then passes else products)[key]
	if not item then
		return
	end
	if (kind == "pass" and Store.owns(key)) or (kind ~= "pass" and item.once == true and Store.boughtOnce(key)) then
		Sfx.play("error", 0.5)
		return
	end
	if item.random and Store.randomBlocked() then
		UI.toast(item.name .. " isn't available in your region.", "orange", 3)
		Sfx.play("error", 0.5)
		return
	end
	buyRemote:FireServer(kind, key)
end

-- Gift a pass to a player in this server (kit gift products are named "Gift<PassKey>").
function Store.gift(passKey: string)
	local pass = passes[passKey]
	if pass and products["Gift" .. passKey] then
		LiveUI.gift("Gift" .. passKey, "GIFT " .. string.upper(pass.name))
	end
end

local function price(item: { [string]: any }): string
	return "R$ " .. Fmt.commas(tonumber(item.price) or 0)
end

-- Current server boost multiplier and seconds left (kit Boosts attributes).
local function boost(kind: string): (number, number)
	local ends = ReplicatedStorage:GetAttribute("BoostEnd_" .. kind)
	local m = ReplicatedStorage:GetAttribute("Boost_" .. kind)
	local now = workspace:GetServerTimeNow()
	if type(ends) == "number" and ends > now and type(m) == "number" then
		return m, ends - now
	end
	return 1, 0
end
Store.boost = boost

-- Cards -------------------------------------------------------------------------------------------------------

type Card = { frame: Frame, button: TextButton, sub: TextLabel, title: TextLabel, gift: TextButton? }

local function card(parent: Instance, glyph: string, title: string, desc: string, color: any, order: number, onBuy: () -> (), giftKey: string?): Card
	local f = UI.card(parent, color, { LayoutOrder = order })
	UI.text(f, glyph, {
		Font = Enum.Font.GothamBold,
		Size = UDim2.new(0, 52, 0, 52),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
	})
	local t = UI.text(f, title, { Size = UDim2.new(1, -12, 0, 26), Position = UDim2.new(0, 6, 0, 56) })
	local sub = UI.text(f, desc, {
		Font = UI.BODY,
		TextWrapped = true,
		Size = UDim2.new(1, -14, 1, -134),
		Position = UDim2.new(0, 7, 0, 84),
		TextColor3 = Color3.fromRGB(240, 244, 255),
	})
	local b = UI.button(f, "BUY", "green", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -20, 0, 40),
	})
	b.MouseButton1Click:Connect(onBuy)
	local g: TextButton? = nil
	if giftKey then
		local gb = UI.button(f, I.gift, "pink", {
			Name = "GiftButton",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(40, 36),
		})
		gb.MouseButton1Click:Connect(function()
			Store.gift(giftKey)
		end)
		g = gb
	end
	return { frame = f, button = b, sub = sub, title = t, gift = g }
end

local function setBuy(c: Card, ownedText: string?, priceText: string, color: string?)
	if ownedText then
		c.button.Text = ownedText
		UI.recolor(c.button, "grey")
		c.button.Active = false
	else
		c.button.Text = priceText
		UI.recolor(c.button, color or "green")
		c.button.Active = true
	end
end

local function note(parent: Instance, str: string, props: { [string]: any }?): TextLabel
	local l = UI.text(parent, str, { Font = UI.BODY, TextColor3 = UI.INK, TextWrapped = true, Size = UDim2.new(1, 0, 0, 30) })
	local s = l:FindFirstChildOfClass("UIStroke")
	if s then
		s.Enabled = false
	end
	UI.set(l, props)
	return l
end

-- Panel ----------------------------------------------------------------------------------------------------------

local shop = UI.panel("Shop", I.shop .. " SHOP", "green", Vector2.new(860, 560))
local pages, select = UI.tabs(shop.body, { "Strength", "Boosts", "Passes", "Skins", "Coins" }, { "orange", "gold", "purple", "pink", "green" })
Store.panel = shop

-- Strength: free at N launches, or skip now
local ladderCards: { [string]: Card } = {}
local ladderNote: TextLabel
do
	local page = pages.Strength
	ladderNote = note(page, "")
	local sc = UI.scroll(page, { Size = UDim2.new(1, 0, 1, -34), Position = UDim2.fromOffset(0, 34) })
	UI.grid(sc, UDim2.fromOffset(150, 204), 10)
	for i, key in ipairs(Config.Ladder) do
		local pass = passes[key]
		local color = Tiers.list[math.clamp(math.ceil(i / 1.5), 1, #Tiers.list)].color
		ladderCards[key] = card(sc, pass.icon, string.format("%dx", pass.mult), "", color, i, function()
			Store.buy("pass", key)
		end, key)
	end
end

-- Boosts: sections of product cards
type Section = { frame: Frame, cards: { [string]: Card }, keys: { string }, extra: TextLabel? }
local sections: { Section } = {}
local BOOST_CELL = Vector2.new(186, 196)
local BOOST_COLS = 4
do
	local sc = UI.scroll(pages.Boosts)
	UI.list(sc, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	local order = 0
	local colors = { "gold", "orange", "sky", "purple" }
	for si, sec in ipairs(Config.ShopBoosts) do
		order += 1
		UI.text(sc, sec.title, { LayoutOrder = order, Size = UDim2.new(1, -8, 0, 28), TextXAlignment = Enum.TextXAlignment.Left })
		local extra: TextLabel? = nil
		if si == 3 then
			order += 1
			extra = note(sc, "", { LayoutOrder = order, Size = UDim2.new(1, -8, 0, 26), TextXAlignment = Enum.TextXAlignment.Left })
		end
		order += 1
		local holder = UI.frame(sc, { BackgroundTransparency = 1, LayoutOrder = order, Size = UDim2.new(1, -8, 0, BOOST_CELL.Y) })
		UI.grid(holder, UDim2.fromOffset(BOOST_CELL.X, BOOST_CELL.Y), 10)
		local cards: { [string]: Card } = {}
		for i, key in ipairs(sec.keys) do
			local item = products[key]
			local b = item.boost
			local title = if b then string.format("%sx %s", tostring(b.mult), tostring(b.label)) else string.upper(item.name)
			cards[key] = card(holder, item.icon, title, item.desc, colors[si] or "blue", i, function()
				Store.buy("product", key)
			end, nil)
		end
		table.insert(sections, { frame = holder, cards = cards, keys = sec.keys, extra = extra })
	end
end

-- Passes: perks, each with a gift button
local passCards: { [string]: Card } = {}
do
	local sc = UI.scroll(pages.Passes)
	UI.grid(sc, UDim2.fromOffset(250, 186), 10)
	local colors = { "teal", "gold", "red", "yellow", "orange", "purple", "pink", "sky" }
	for i, key in ipairs(Config.ShopPasses) do
		local pass = passes[key]
		passCards[key] = card(sc, pass.icon, string.upper(pass.name), pass.desc, colors[i] or "blue", i, function()
			Store.buy("pass", key)
		end, key)
	end
end

-- Skins
local skinCards: { [string]: Card } = {}

local function skinUnlocked(d: { [string]: any }, sk: Config.Skin): boolean
	return sk.unlock == "free"
		or (sk.unlock == "launches" and (tonumber(d.launches) or 0) >= (sk.need or 0))
		or (sk.unlock == "planet" and (tonumber(d.bestPlanet) or 1) >= (sk.need or 99))
		or (sk.unlock == "pass" and sk.pass ~= nil and Store.owns(sk.pass))
end

do
	local sc = UI.scroll(pages.Skins)
	UI.grid(sc, UDim2.fromOffset(250, 186), 10)
	for i, sk in ipairs(Config.Skins) do
		local c = card(sc, sk.icon, string.upper(sk.name), "", sk.accent, i, function()
			local d = State.data
			if not d then
				return
			end
			if skinUnlocked(d, sk) then
				skinRemote:FireServer(sk.key)
			elseif sk.unlock == "pass" and sk.pass then
				Store.buy("pass", sk.pass)
			else
				Sfx.play("error", 0.5)
			end
		end, if sk.unlock == "pass" then sk.pass else nil)
		local sw = UI.frame(c.frame, { BackgroundTransparency = 1, Size = UDim2.fromOffset(96, 22), Position = UDim2.new(0, 8, 0, 8) })
		UI.list(sw, 4, true, Enum.HorizontalAlignment.Left)
		for _, col in ipairs({ sk.body, sk.accent, sk.trim }) do
			local dot = UI.frame(sw, { Size = UDim2.fromOffset(20, 20), BackgroundColor3 = col })
			UI.corner(dot, 10)
			UI.stroke(dot, 2)
		end
		skinCards[sk.key] = c
	end
end

-- Coins: Rookie Deal, Starter Pack (timed), coin packs
local coinCards: { [string]: Card } = {}
do
	local page = pages.Coins
	note(page, "Coin packs grow with your best planet. Spend coins on Gear to get stronger!")
	local sc = UI.scroll(page, { Size = UDim2.new(1, 0, 1, -34), Position = UDim2.fromOffset(0, 34) })
	UI.grid(sc, UDim2.fromOffset(186, 214), 10)
	for i, key in ipairs(Config.ShopCoins) do
		local item = products[key]
		local color = if item.intro then "teal" elseif key == "StarterPack" then "pink" else "gold"
		coinCards[key] = card(sc, item.icon, string.upper(item.name), "", color, i, function()
			Store.buy("product", key)
		end, nil)
	end
end

-- Refresh ----------------------------------------------------------------------------------------------------------

local function bestMult(d: { [string]: any }): number
	return Config.planet(tonumber(d.bestPlanet) or 1).coins * Config.missionMult(tonumber(d.bestMission) or 1)
end

-- "Legendary 1.2% → 2.4%" for a luck multiplier (same maths as the server's roll).
local function luckLine(tierKey: string, luck: number): string
	local r = Config.RarityByKey[tierKey]
	return string.format("%s %s \u{2192} %s", Tiers.get(tierKey).name, Tiers.odds(Config.Rarity, r), Tiers.odds(Config.Rarity, r, luck))
end

local function refreshStrength(d: { [string]: any })
	local launches = tonumber(d.launches) or 0
	local free = Config.freeMult(launches)
	local best = free
	for _, key in ipairs(Config.Ladder) do
		if Store.owns(key) then
			best = math.max(best, passes[key].mult)
		end
	end
	ladderNote.Text = string.format("Every step unlocks FREE with launches (you: %s %s). Skip ahead now! Active: %dx", I.launch, Fmt.commas(launches), best)
	local nextShown = false
	for _, key in ipairs(Config.Ladder) do
		local c = ladderCards[key]
		local pass = passes[key]
		local need = tonumber(pass.launches) or 0
		local freeOk = launches >= need
		if Store.owns(key) or freeOk then
			setBuy(c, if pass.mult == best then "ACTIVE " .. I.check else (if freeOk then "FREE " .. I.check else "OWNED"), "")
			c.sub.Text = if freeOk then "Unlocked with launches!" else "Owned"
		else
			setBuy(c, nil, "SKIP " .. price(pass), if not nextShown and pass.mult > best then "orange" else "green")
			c.sub.Text = string.format("FREE at %s %s launches (%s/%s)", I.launch, Fmt.commas(need), Fmt.commas(launches), Fmt.commas(need))
			if not nextShown and pass.mult > best then
				nextShown = true
				c.sub.Text = "\u{2B50} NEXT · " .. c.sub.Text
			end
		end
		if c.gift then
			(c.gift :: TextButton).Visible = true
		end
	end
end

local function refreshBoosts(_d: { [string]: any })
	local blocked = Store.randomBlocked()
	local luck = boost("luck")
	for si, sec in ipairs(sections) do
		local shown = 0
		for _, key in ipairs(sec.keys) do
			local c = sec.cards[key]
			local item = products[key]
			local b = item.boost
			local visible = not (item.random and blocked)
			c.frame.Visible = visible
			if visible then
				shown += 1
			end
			if b then
				local m, left = boost(b.kind)
				if b.kind == "luck" then
					c.sub.Text = luckLine("Legendary", b.mult) .. "\n" .. luckLine("Secret", b.mult)
				else
					c.sub.Text = item.desc
				end
				if m >= b.mult and left > 0 then
					c.sub.Text = string.format("RUNNING %s %s · buy to add time", I.check, Fmt.time(left))
					setBuy(c, nil, price(item), "teal")
				elseif b.needs and m < b.needs then
					c.sub.Text = string.format("%s Unlocks while %sx %s runs", I.lock, tostring(b.needs), tostring(b.label))
					setBuy(c, nil, price(item), "grey")
				else
					setBuy(c, nil, price(item), "green")
				end
			elseif item.tier then
				local tier = Config.rocketTier(item.tier)
				c.sub.Text = string.format("Bigger rocket, x%s launch rewards for EVERYONE. Shoutout!", tostring(tier.reward))
				setBuy(c, nil, price(item), "green")
			elseif item.train then
				local m, left = boost("train")
				c.sub.Text = if m > 1 then string.format("%s %dx gains now, %s left", I.zerog, m, Fmt.time(left)) else item.desc
				setBuy(c, nil, price(item), "green")
			else
				setBuy(c, nil, price(item), "green")
			end
		end
		local rows = math.max(1, math.ceil(shown / BOOST_COLS))
		sec.frame.Size = UDim2.new(1, -8, 0, rows * (BOOST_CELL.Y + 10))
		sec.frame.Visible = shown > 0
		local ex = sec.extra
		if ex and si == 3 then
			local parts = {}
			for _, t in ipairs(Config.RocketTiers) do
				table.insert(parts, string.format("%s %s %s", t.icon, t.name, Tiers.oddsLive(Config.RocketTiers, t, luck)))
			end
			local nextTier = Hub.str("NextTier", "")
			ex.Text = "Free roll for every new rocket: " .. table.concat(parts, " · ") .. (if nextTier ~= "" then "  ·  NEXT: " .. string.upper(nextTier) .. " (bought)" else "")
		end
	end
end

local function refreshPasses()
	for _, key in ipairs(Config.ShopPasses) do
		local c = passCards[key]
		setBuy(c, if Store.owns(key) then "OWNED " .. I.check else nil, price(passes[key]))
	end
end

local function refreshSkins(d: { [string]: any })
	for _, sk in ipairs(Config.Skins) do
		local c = skinCards[sk.key]
		local equipped = d.skin == sk.key
		local unlocked = skinUnlocked(d, sk)
		if sk.unlock == "launches" then
			c.sub.Text = string.format("Launch %d rockets (%d/%d)", sk.need or 0, math.min(tonumber(d.launches) or 0, sk.need or 0), sk.need or 0)
		elseif sk.unlock == "planet" then
			c.sub.Text = "Reach " .. Config.planet(sk.need or 4).name
		elseif sk.unlock == "pass" then
			c.sub.Text = if sk.key == "Pumpkin" then "Halloween! Top hauler's skin paints the rocket." else "Top hauler's skin paints the rocket!"
		else
			c.sub.Text = "The classic white and orange."
		end
		if equipped then
			setBuy(c, "EQUIPPED " .. I.check, "")
		elseif unlocked then
			setBuy(c, nil, "EQUIP", "blue")
		elseif sk.unlock == "pass" and sk.pass then
			setBuy(c, nil, price(passes[sk.pass]))
		else
			c.button.Text = I.lock .. " LOCKED"
			UI.recolor(c.button, "grey")
			c.button.Active = true
		end
	end
end

local function refreshCoins(d: { [string]: any })
	local mult = bestMult(d)
	local starter = Store.starterLeft()
	for _, key in ipairs(Config.ShopCoins) do
		local c = coinCards[key]
		local item = products[key]
		local visible = true
		if item.intro then
			visible = Store.introOk()
			c.sub.Text = string.format("FIRST PURCHASE ONLY!\n%s %s + 15 min 3x %s", I.coin, Fmt.commas(item.coins * mult), I.strength)
		elseif key == "StarterPack" then
			visible = starter > 0
			c.sub.Text = string.format("%s %s + Gloves + 3x %s\n%s ENDS IN %s", I.coin, Fmt.commas(item.coins * mult), I.strength, I.timer, Fmt.time(starter))
		elseif key == "CoinsXXLFirst" then
			visible = not Store.boughtOnce(key)
			c.sub.Text = string.format("%s %s\n-40%% FIRST TIME!", I.coin, Fmt.commas(item.coins * mult))
		elseif key == "CoinsXXL" then
			visible = Store.boughtOnce("CoinsXXLFirst")
			c.sub.Text = I.coin .. " " .. Fmt.commas(item.coins * mult)
		else
			c.sub.Text = I.coin .. " " .. Fmt.commas(item.coins * mult)
		end
		c.frame.Visible = visible
		setBuy(c, nil, price(item))
	end
end

function Store.refresh()
	local d = State.data
	if not d or not shop.isOpen() then
		return
	end
	refreshStrength(d)
	refreshBoosts(d)
	refreshPasses()
	refreshSkins(d)
	refreshCoins(d)
end

-- Open the shop on a tab ("Strength", "Boosts", "Passes", "Skins", "Coins").
function Store.open(tab: string?)
	shop.open()
	if tab then
		select(tab)
	end
	Store.refresh()
end

function Store.isOpen(): boolean
	return shop.isOpen()
end

shop.onOpen = Store.refresh

function Store.init()
	State.onChange(function()
		Store.refresh()
	end)
	player:GetAttributeChangedSignal("RandomBlocked"):Connect(Store.refresh)
	-- timers on the open page (boosts, starter countdown)
	task.spawn(function()
		while true do
			task.wait(1)
			if shop.isOpen() then
				Store.refresh()
			end
		end
	end)
end

return Store

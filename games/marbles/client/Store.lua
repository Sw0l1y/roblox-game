--!strict
-- The shop and every purchase offer: rotating daily marble deals (with the first-buy and Starter Pack offers
-- on top), passes each with a gift button, server boosts and luck, race modifiers (Start a Grand Prix, Chaos
-- and Ice Track, Custom Round), coin packs and trails. Prices are Roblox's live ones (kit Prices). Paid random
-- items are hidden from players under Roblox's paid random item restriction (RandomBlocked attribute, kit
-- Policy); they see the fixed versions instead. Purchase popups never come in a session's first minutes
-- (Config.NoOffersBefore) and the Starter Pack only shows during a player's first 10 minutes, with a timer.
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
local Prices = require(ClientLib:WaitForChild("Prices"))
local LiveUI = require(ClientLib:WaitForChild("LiveUI"))
local MarbleIcon = require(ClientLib:WaitForChild("MarbleIcon"))

local Store = {}

local player = Players.LocalPlayer
local buyRemote = Net.event("Buy")
local wantRemote = Net.event("Want")
local trailRemote = Net.event("SetTrail")
local data: { [string]: any } = {}
local sessionStart = os.clock()
local P: { [string]: any } = Config.Passes :: any
local Pr: { [string]: any } = Config.Products :: any

local function now(): number
	return workspace:GetServerTimeNow()
end

local function today(): number
	return math.floor(now() / 86400)
end

local function rs(price: number): string
	return "R$ " .. Fmt.commas(price)
end

local function noStroke(l: TextLabel)
	local s = l:FindFirstChildOfClass("UIStroke")
	if s then
		s.Enabled = false
	end
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

local function bought(product: string): boolean
	local b = data.bought
	return type(b) == "table" and b[product] == true
end

-- True while Roblox's paid random item restriction applies to this player (true until the lookup returns).
function Store.blocked(): boolean
	return player:GetAttribute("RandomBlocked") ~= false
end

local function buy(kind: string, key: string)
	buyRemote:FireServer(kind, key)
	Sfx.play("purchase", 0.4)
end

local function serverBoost(kind: string): number
	local ends = ReplicatedStorage:GetAttribute("BoostEnd_" .. kind)
	local m = ReplicatedStorage:GetAttribute("Boost_" .. kind)
	if type(ends) == "number" and ends > now() and type(m) == "number" then
		return m
	end
	return 1
end

-- Seconds left on the Starter Pack (on sale for the first 10 minutes of a player's first session, the
-- product's kit `window`); 0 = gone.
function Store.starterLeft(): number
	local fj = tonumber(data.firstJoin)
	if not fj or (tonumber(data.sessions) or 1) > 1 or data.starterBought or bought("StarterPack") then
		return 0
	end
	return math.max(0, fj + Config.StarterWindow - now())
end

-- The 9 R$ first-buy offer: only for players who never bought anything.
function Store.introOpen(): boolean
	return (tonumber(data.spent) or 0) == 0 and next(data.passes or {}) == nil and not bought("IntroEpic") and not bought("IntroEpicFixed")
end

-- No purchase popups or offer buttons in a session's first minutes.
function Store.canOffer(): boolean
	return os.clock() - sessionStart >= Config.NoOffersBefore
end

local function dealId(tier: string, salt: number): string
	return Config.dayPick(tier, today(), salt)
end

-- Panel ------------------------------------------------------------------------------------------------------
local pShop = UI.panel("Shop", "SHOP", "pink", Vector2.new(980, 540))
local TABS = { "Deals", "Passes", "Boosts", "Race", "Coins", "Trails" }
local pages, selectTab = UI.tabs(pShop.body, TABS, { "orange", "purple", "gold", "red", "green", "teal" })
local grids: { [string]: ScrollingFrame } = {}
for _, name in ipairs(TABS) do
	local s = UI.scroll(pages[name], {})
	UI.grid(s, UDim2.fromOffset(196, 222), 10)
	grids[name] = s
end
local timers: { { label: TextLabel, fn: () -> string } } = {}

type CardOpts = { glyph: string?, marble: string?, highlight: any?, tag: string?, tagColor: any?, enabled: boolean? }

-- One shop card: icon (emoji or a marble), name, description and a buy button. Returns the card.
local function card(grid: Instance, order: number, name: string, desc: string, btnText: string, btnColor: any, onClick: () -> (), o: CardOpts?): Frame
	local opts: CardOpts = o or {}
	local hl = opts.highlight
	local c = UI.card(grid, hl or Color3.fromRGB(240, 242, 252), { LayoutOrder = order })
	if opts.marble then
		MarbleIcon.flat(c, opts.marble :: string, nil, 58, { Position = UDim2.new(0.5, -29, 0, 6) })
	else
		UI.text(c, opts.glyph or "🎁", { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(56, 56), Position = UDim2.new(0.5, -28, 0, 6) })
	end
	UI.text(c, name, { Size = UDim2.new(1, -12, 0, 26), Position = UDim2.fromOffset(6, 64), TextWrapped = true })
	local d = UI.text(c, desc, { Font = UI.BODY, Size = UDim2.new(1, -14, 0, 54), Position = UDim2.fromOffset(7, 92), TextWrapped = true, TextColor3 = hl and Color3.new(1, 1, 1) or UI.INK })
	if not hl then
		noStroke(d)
	end
	if opts.tag then
		local t = UI.text(c, opts.tag :: string, { Size = UDim2.fromOffset(100, 22), Position = UDim2.fromOffset(4, 4), BackgroundTransparency = 0, BackgroundColor3 = UI.color(opts.tagColor or "red"), Rotation = -6, ZIndex = c.ZIndex + 3 })
		UI.corner(t, 8)
	end
	local b = UI.button(c, btnText, opts.enabled == false and "grey" or btnColor, { Size = UDim2.new(1, -16, 0, 46), Position = UDim2.new(0, 8, 1, -54) })
	b.MouseButton1Click:Connect(onClick)
	return c
end

-- A small live label above a card's button (countdowns), refreshed every second while the shop is open.
local function timer(parent: Instance, fn: () -> string)
	local l = UI.text(parent, fn(), { Font = UI.BODY, Size = UDim2.new(1, -12, 0, 20), Position = UDim2.new(0, 6, 1, -76), TextColor3 = Color3.fromRGB(255, 236, 120) })
	table.insert(timers, { label = l, fn = fn })
end

local function dealsLeft(): string
	local secs = (today() + 1) * 86400 - now()
	return "⏰ New deals in " .. Fmt.time(secs)
end

local drawCustom: () -> ()

local function drawShop()
	for _, g in pairs(grids) do
		clearKids(g)
	end
	table.clear(timers)
	local blocked = Store.blocked()

	-- Deals ---------------------------------------------------------------------------------------------
	local g = grids.Deals
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	if Store.introOpen() then
		if blocked then
			local it = Pr.IntroEpicFixed
			local id = Config.dayPick("Epic", today(), 9)
			local def = Config.MarbleById[id]
			card(g, nextOrder(), it.name, (def and def.name or "") .. " (Epic). First buy only!", rs(it.price), "green", function()
				buy("product", "IntroEpicFixed")
			end, { marble = id, highlight = "orange", tag = "FIRST BUY!" })
		else
			local it = Pr.IntroEpic
			card(g, nextOrder(), it.name, "Any Epic marble! First buy only.", rs(it.price), "green", function()
				buy("product", "IntroEpic")
			end, { glyph = it.glyph, highlight = "orange", tag = "FIRST BUY!" })
		end
	end
	if Store.starterLeft() > 0 then
		local it = Pr.StarterPack
		local c = card(g, nextOrder(), it.name, it.desc, rs(it.price), "green", function()
			buy("product", "StarterPack")
		end, { glyph = it.glyph, highlight = "green", tag = "-80% ONCE" })
		timer(c, function()
			return "⏰ Gone in " .. Fmt.time(Store.starterLeft())
		end)
	end
	for _, deal in ipairs(Config.Deals) do
		local it = Pr[deal.product]
		local id = dealId(deal.tier, deal.salt)
		local def = Config.MarbleById[id]
		local have = data.marbles and data.marbles[id] ~= nil
		local tc = Tiers.get(deal.tier)
		local c = card(g, nextOrder(), def and def.name or id, string.upper(tc.name) .. " · today only" .. (have and " (you have it: +XP)" or ""), rs(it.price), "green", function()
			wantRemote:FireServer(deal.product, id)
			buy("product", deal.product)
		end, { marble = id, highlight = tc.color, tag = "DAILY DEAL", tagColor = "orange" })
		timer(c, dealsLeft)
	end
	if Config.isHalloween(now()) and not bought("PumpkinMarble") then
		local it = Pr.PumpkinMarble
		card(g, nextOrder(), it.name, it.desc, rs(it.price), "green", function()
			buy("product", "PumpkinMarble")
		end, { marble = "pumpkin", highlight = "orange", tag = "🎃 HALLOWEEN" })
	end
	do
		local it = Pr.DiamondMarble
		card(g, nextOrder(), it.name, it.desc, rs(it.price), "sky", function()
			buy("product", "DiamondMarble")
		end, { marble = "diamond", highlight = "purple" })
	end

	-- Passes (each with a gift copy) --------------------------------------------------------------------
	order = 0
	for _, key in ipairs({ "CoinsX2", "PowerSlot", "VIP", "TripleOpen", "LuckyCharm" }) do
		local p = P[key]
		if p.random and blocked then
			continue
		end
		local have = owns(key)
		local c = card(grids.Passes, nextOrder(), p.name, p.desc, have and "OWNED ✅" or rs(p.price), have and "grey" or "green", function()
			if not have then
				buy("pass", key)
			end
		end, { glyph = p.glyph })
		local giftKey = "Gift" .. key
		local gp = Pr[giftKey]
		if gp then
			local gb = UI.button(c, "🎁 GIFT", "pink", { Size = UDim2.fromOffset(84, 30), Position = UDim2.new(1, -90, 0, 6) })
			gb.MouseButton1Click:Connect(function()
				LiveUI.gift(giftKey, "GIFT " .. string.upper(p.name) .. "  " .. rs(gp.price))
			end)
		end
	end

	-- Boosts: server-wide coins and luck, personal luck, the Galaxy Pack -----------------------------------
	order = 0
	for _, key in ipairs({ "ServerCoins2", "ServerCoins4", "ServerCoins8", "ServerLuck2", "ServerLuck4", "LuckBoost", "GalaxyPack" }) do
		local it = Pr[key]
		if it.random and blocked then
			continue
		end
		local b = it.boost
		local ok = not (b and b.needs) or serverBoost(b.kind) >= b.needs
		local btn = ok and rs(it.price) or ("🔒 needs " .. tostring(b and b.needs) .. "x")
		card(grids.Boosts, nextOrder(), it.name, it.desc, btn, "green", function()
			if ok then
				buy("product", key)
			else
				UI.toast("Start the " .. tostring(b and b.needs) .. "x boost first!", "orange")
			end
		end, { glyph = it.glyph, enabled = ok, highlight = b and (b.kind == "luck" and "green" or "gold") or nil })
	end

	-- Race: Grand Prix and round modifiers ----------------------------------------------------------------
	order = 0
	for _, key in ipairs({ "StartGP", "ChaosTrack", "IceTrack" }) do
		local it = Pr[key]
		card(grids.Race, nextOrder(), it.name, it.desc, rs(it.price), "green", function()
			buy("product", key)
		end, { glyph = it.glyph, highlight = key == "StartGP" and "purple" or nil })
	end
	do
		local it = Pr.CustomRound
		card(grids.Race, nextOrder(), it.name, it.desc, "PICK ▶", "blue", function()
			local cp = UI.getPanel("CustomRound")
			if cp then
				cp.open()
			end
		end, { glyph = it.glyph, highlight = "pink" })
	end

	-- Coins ------------------------------------------------------------------------------------------------
	order = 0
	for _, key in ipairs({ "CoinsS", "CoinsM", "CoinsL", "CoinsXL", "CoinsXXL" }) do
		local it = Pr[key]
		card(grids.Coins, nextOrder(), it.name, it.desc, rs(it.price), "green", function()
			buy("product", key)
		end, { glyph = it.glyph, tag = key == "CoinsXXL" and "BEST VALUE" or nil, tagColor = "green" })
	end

	-- Trails -----------------------------------------------------------------------------------------------
	card(grids.Trails, 0, "No Trail", "Just the marble.", data.trail == "" and "EQUIPPED" or "EQUIP", data.trail == "" and "grey" or "blue", function()
		trailRemote:FireServer("")
	end, { glyph = "🚫" })
	order = 0
	local glyphs: { [string]: string } = { sparkle = "✨", flame = "🔥", rainbow = "🌈", gold = "👑", spooky = "🎃" }
	for _, t in ipairs(Config.Trails) do
		local have = (data.trails or {})[t.key] == true
		if t.key == "spooky" and not have and not Config.isHalloween(now()) then
			continue
		end
		local equipped = data.trail == t.key
		local btn, col
		if equipped then
			btn, col = "EQUIPPED", "grey"
		elseif have then
			btn, col = "EQUIP", "blue"
		elseif t.pass then
			btn, col = "VIP PASS", "gold"
		else
			btn, col = rs(tonumber((Pr[t.product] or {}).price) or 0), "green"
		end
		local desc = have and "Shows behind your marble in every race." or (t.key == "spooky" and "Comes with the Jack-o'-Marble Bundle!" or "Leave a trail behind your marble!")
		card(grids.Trails, nextOrder(), t.name, desc, btn, col, function()
			if have then
				trailRemote:FireServer(t.key)
				Sfx.play("unlock", 0.4)
			elseif t.pass then
				buy("pass", "VIP")
			elseif t.product then
				buy("product", t.product)
			end
		end, { glyph = glyphs[t.key] or "✨" })
	end
	if drawCustom then
		drawCustom()
	end
end
pShop.onOpen = drawShop

-- Custom Round: pick the next race's theme and mode, then buy ---------------------------------------------
local pCustom = UI.panel("CustomRound", "🎨 CUSTOM ROUND", "pink", Vector2.new(700, 440))
local customTheme = "Volcano"
local customMode = "chaos"
local themeRow = UI.frame(pCustom.body, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 120), Position = UDim2.fromOffset(0, 34) })
UI.grid(themeRow, UDim2.fromOffset(200, 52), 10)
local modeRow = UI.frame(pCustom.body, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 196) })
UI.grid(modeRow, UDim2.fromOffset(150, 52), 10)
local themeTitle = UI.text(pCustom.body, "1. TRACK THEME", { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 2), TextXAlignment = Enum.TextXAlignment.Left })
local modeTitle = UI.text(pCustom.body, "2. MODE", { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 164), TextXAlignment = Enum.TextXAlignment.Left })
local customBuy = UI.button(pCustom.body, "", "green", { Size = UDim2.fromOffset(320, 60), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6) })
local customNote = UI.text(pCustom.body, "", { Font = UI.BODY, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 1, -100), TextColor3 = UI.INK })
noStroke(customNote)
local _ = themeTitle
local _2 = modeTitle

local MODE_TEXT: { [string]: string } = { none = "⚪ NORMAL", chaos = "🌪️ CHAOS", ice = "❄️ ICE", bigair = "🚀 BIG AIR" }

drawCustom = function()
	clearKids(themeRow)
	clearKids(modeRow)
	for i, th in ipairs(Config.CustomThemes) do
		local b = UI.button(themeRow, string.upper(th), th == customTheme and "orange" or "grey", { LayoutOrder = i })
		b.MouseButton1Click:Connect(function()
			customTheme = th
			drawCustom()
		end)
	end
	for i, m in ipairs(Config.CustomModes) do
		local b = UI.button(modeRow, MODE_TEXT[m] or m, m == customMode and "purple" or "grey", { LayoutOrder = i })
		b.MouseButton1Click:Connect(function()
			customMode = m
			drawCustom()
		end)
	end
	local modeName = string.gsub(MODE_TEXT[customMode] or customMode, "^%S+ ", "")
	customNote.Text = string.format("Next race for EVERYONE: %s track, %s mode.", customTheme, string.lower(modeName))
	customBuy.Text = "BUY  " .. rs(Pr.CustomRound.price)
end
customBuy.MouseButton1Click:Connect(function()
	wantRemote:FireServer("CustomRound", { mode = customMode, theme = customTheme })
	buy("product", "CustomRound")
	pCustom.close()
end)
pCustom.onOpen = drawCustom
drawCustom()

-- Open the shop on a tab.
function Store.open(tab: string?)
	pShop.open()
	if tab and pages[tab] then
		selectTab(tab)
	end
end

function Store.isOpen(): boolean
	return pShop.isOpen()
end

-- Purchase popups: never in a session's first minutes, at most one every Config.OfferGap, only after a race.
local lastOffer = -1000
function Store.maybeOffer(lost: boolean)
	local t = os.clock()
	local open = UI.getPanel("__offer")
	if not Store.canOffer() or t - lastOffer < Config.OfferGap or (open and open.isOpen()) then
		return
	end
	lastOffer = t
	local left = Store.starterLeft()
	if left > 5 then
		local p = Pr.StarterPack
		UI.offer({ title = "STARTER PACK!", text = p.desc, glyph = p.glyph, price = rs(p.price), color = "green", seconds = math.floor(left), onBuy = function()
			buy("product", "StarterPack")
		end })
	elseif Store.introOpen() then
		local key = Store.blocked() and "IntroEpicFixed" or "IntroEpic"
		local p = Pr[key]
		UI.offer({ title = "FIRST BUY: 9 R$!", text = p.desc, glyph = p.glyph, price = rs(p.price), color = "orange", onBuy = function()
			buy("product", key)
		end })
	elseif not owns("CoinsX2") then
		local p = P.CoinsX2
		UI.offer({ title = lost and "DOUBLE YOUR COINS" or "2x COINS!", text = p.desc, glyph = p.glyph, price = rs(p.price), color = "gold", onBuy = function()
			buy("pass", "CoinsX2")
		end })
	elseif not owns("PowerSlot") then
		local p = P.PowerSlot
		UI.offer({ title = "EXTRA POWER-UP!", text = p.desc, glyph = p.glyph, price = rs(p.price), color = "purple", onBuy = function()
			buy("pass", "PowerSlot")
		end })
	elseif serverBoost("coins") <= 1 then
		local p = Pr.ServerCoins2
		UI.offer({ title = "2x COINS FOR EVERYONE!", text = p.desc, glyph = p.glyph, price = rs(p.price), color = "gold", onBuy = function()
			buy("product", "ServerCoins2")
		end })
	end
end

-- Live -------------------------------------------------------------------------------------------------------
State.onChange(function(d)
	data = d
	if pShop.isOpen() then
		drawShop()
	end
end)
Prices.onChange(function()
	if pShop.isOpen() then
		drawShop()
	end
	drawCustom()
end)
player:GetAttributeChangedSignal("RandomBlocked"):Connect(function()
	if pShop.isOpen() then
		drawShop()
	end
end)
task.spawn(function()
	local lastBoost = 0
	while true do
		task.wait(1)
		if pShop.isOpen() then
			for _, tm in ipairs(timers) do
				if tm.label.Parent then
					tm.label.Text = tm.fn()
				end
			end
			-- a server boost started or ended: the "needs 2x" locks change
			local b = serverBoost("coins") * 10 + serverBoost("luck")
			if b ~= lastBoost then
				lastBoost = b
				drawShop()
			end
		end
	end
end)

return Store

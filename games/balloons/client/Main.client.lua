-- Pop All The Balloons! 🎈 — client entry point.
-- Builds the HUD and menus, starts the balloon / MEGA BALLOON views, the guide and the FREE panel (kit LiveUI),
-- routes server "Ui" messages to the right effects, and runs the small local systems: zone ambience, gates you
-- already own, booth pads that open their menu, the VIP chat tag, music + mute, the story intro and the offers
-- (none in the first two minutes; the Starter Pack only in the first 10 minutes; the 9 R$ Welcome Deal later).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local Fmt = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Fmt"))
local Tiers = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tiers"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Econ = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Econ"))
local UI = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("UI"))
local Sfx = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("Sfx"))
local Fx = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("Fx"))
local State = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("State"))
local Hud = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("Hud"))
local Panels = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("Panels"))
local MegaView = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("MegaView"))
local BalloonView = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("BalloonView"))
local Guide = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("Guide"))
local LiveUI = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("LiveUI"))
local Prices = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("Prices"))

local player = Players.LocalPlayer
local I = Config.Icons
local P = Config.Palette
local buyRemote = Net.event("Buy")
local actionRemote = Net.event("Action")

local function hrp(): BasePart?
	local c = player.Character
	local h = c and c:FindFirstChild("HumanoidRootPart")
	if h and h:IsA("BasePart") then
		return h :: BasePart
	end
	return nil
end

---------------------------------------------------------------------------------------------------------------
-- Build everything
---------------------------------------------------------------------------------------------------------------

Sfx.music(Config.Music, 0.2)
Hud.init()
Panels.init()
MegaView.init()
BalloonView.init()
Guide.init()
LiveUI.init(Config.Live)
-- live Robux prices (regional pricing) replace the planned ones in the catalog; redraw the open shop pages
Prices.sync(Config.Passes, Config.Products)
Prices.onChange(Panels.refresh)
-- running server boosts (bought ones and the hourly event), above the goal bar
LiveUI.boostPill(UI.root, { coins = "COINS", luck = "LUCK" }, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -96),
	Size = UDim2.fromOffset(380, 34),
})
LiveUI.onClaimable(function(n: number)
	Hud.buttons.Free.setBadge(n > 0 and n or nil)
end)

local function randomBlocked(): boolean
	return player:GetAttribute("RandomBlocked") ~= false
end

Hud.onButton.Free = function()
	LiveUI.open()
end
Hud.onButton.Starter = function()
	Panels.open("Starter")
end
-- the zone meter: full = summon the zone boss
Hud.onButton.Meter = function()
	local d = State.data
	if Hud.meterIsFull() then
		actionRemote:FireServer("boss")
	elseif d and Config.Zones[Hud.zone] then
		local pct = math.floor(Econ.meterFrac(d, Hud.zone) * 100)
		UI.toast(I.boss .. " Pop " .. (100 - pct) .. "% more " .. Config.Zones[Hud.zone].name .. " balloons to call its BOSS!", "orange", 3)
	end
end
Hud.onButton.Upgrades = function()
	Panels.toggle("Upgrades")
end
Hud.onButton.Shop = function()
	Panels.toggle("Shop")
end
Hud.onButton.Index = function()
	Panels.toggle("Index")
end
Hud.onButton.Zones = function()
	Panels.toggle("Zones")
end
Hud.onButton.Rebirth = function()
	Panels.toggle("Rebirth")
end
Hud.onButton.Daily = function()
	Panels.toggle("Daily")
end
Hud.onButton.Boost = function()
	-- paid luck is not sold to players under the paid random item restriction: this slot sells coin boosts then
	Panels.open("Shop", randomBlocked() and "Server" or "Items")
end
Hud.onButton.Summon = function()
	Panels.open("Shop", "Items")
end
Hud.onButton.MegaShop = function()
	Panels.open("Shop", "Items")
end
Hud.onButton.Mega = function()
	Hud.toggleMega()
end
Hud.onButton.Mute = function()
	local m = not Sfx.isMuted()
	Sfx.setMuted(m)
	local b = Hud.buttons.Mute
	local icon = b.icon
	if icon:IsA("TextLabel") then
		icon.Text = m and I.muted or I.music
	end
	b.label.Text = m and "Muted" or "Music"
end

---------------------------------------------------------------------------------------------------------------
-- Server UI messages
---------------------------------------------------------------------------------------------------------------

local function zoneName(z: any): string
	local zd = Config.Zones[tonumber(z) or 1]
	return zd and (zd.glyph .. " " .. string.upper(zd.name)) or ""
end

local handlers: { [string]: (...any) -> () } = {
	reward = BalloonView.onReward,
	boom = BalloonView.boom,
	megaPop = MegaView.onPop,
	megaReward = MegaView.onReward,
	rain = MegaView.onRain,
}

handlers.rareNear = function(id: any, key: any)
	if type(id) ~= "number" then
		return
	end
	Guide.setRare(id)
	BalloonView.markRare(id)
	local def = type(key) == "string" and Config.Balloons[key] or nil
	if def then
		local t = Tiers.get(def.tier)
		UI.toast(I.sparkle .. " A " .. t.name .. " " .. def.name .. " appeared right next to you!", t.color, 4)
	end
	Sfx.play("sparkle", 0.6)
end

handlers.announce = function(text: any, tier: any)
	if type(text) ~= "string" then
		return
	end
	local t = Tiers.get(type(tier) == "string" and tier or "Legendary")
	UI.toast(text, t.color, 5)
	Sfx.play("magic", 0.35, 1.1)
end

handlers.set = function(zone: any, bonus: any)
	local z = Config.Zones[tonumber(zone) or 1]
	if not z then
		return
	end
	local pct = math.floor((Config.Index.setBonus[tonumber(zone) or 1] or 0) * 100 + 0.5)
	UI.banner("📖 " .. string.upper(z.name) .. " INDEX COMPLETE!", "purple", 3)
	UI.toast("+" .. pct .. "% coins forever and " .. I.coin .. " " .. Fmt.num(tonumber(bonus) or 0) .. " bonus!", "purple", 5)
	UI.confetti(120)
	UI.fly(UI.center(), Hud.coinTarget(), 14, I.coin, Hud.punchCoins)
	Sfx.play("victory", 0.6)
end

handlers.pump = function(amount: any, top: any)
	local n = tonumber(amount) or 0
	if typeof(top) == "Vector3" then
		Fx.popup((top :: Vector3) + Vector3.new(0, 3, 0), "+" .. Fmt.num(n), P.yellow, 1.4)
		local sp = UI.screenPos(top :: Vector3)
		UI.fly(sp or UI.center(), Hud.coinTarget(), 10, I.coin, Hud.punchCoins)
	end
	UI.toast(I.pump .. " Collected " .. I.coin .. " " .. Fmt.num(n) .. " from your Balloon Pump!", "gold")
	Sfx.play("cash", 0.55)
end

handlers.offline = function(gain: any, away: any)
	local g, a = tonumber(gain) or 0, tonumber(away) or 0
	if g <= 0 then
		return
	end
	task.spawn(function()
		-- don't cover the first seconds of play
		while Panels.anyOpen() do
			task.wait(1)
		end
		Panels.welcome(g, a)
	end)
end

handlers.upgraded = function(key: any, lvl: any)
	local u = type(key) == "string" and Config.Upgrades[key] or nil
	if not u then
		return
	end
	Sfx.play("purchase", 0.5)
	UI.floater(u.glyph .. " " .. u.name .. " Lv " .. tostring(lvl), "green", UI.center() - Vector2.new(0, 80), 44)
	local r = hrp()
	if r then
		Fx.sparkle(r.Position, P.ui, 3.5, 0.9)
	end
	if tonumber(lvl) == 1 and key == "power" then
		UI.toast(I.upgrades .. " Nice! Stronger darts pop big balloons faster.", "blue", 3.5)
	end
end

handlers.need = function(missing: any)
	UI.toast("Need " .. I.coin .. " " .. Fmt.num(math.max(0, tonumber(missing) or 0)) .. " more!", "red", 2.2)
	Sfx.play("error", 0.45)
	Hud.punchCoins()
end

local gateWalls: { [Instance]: number } = {}

local function refreshGates()
	local d = State.data
	local zones = d and d.zones or 1
	for wall, z in pairs(gateWalls) do
		if wall:IsA("BasePart") then
			local open = z <= zones
			local w = wall :: BasePart
			w.CanCollide = not open
			w.Transparency = open and 1 or 0.6
			for _, c in ipairs(w:GetChildren()) do
				if c:IsA("SurfaceGui") then
					c.Enabled = not open
				elseif c:IsA("ProximityPrompt") then
					c.Enabled = not open
				end
			end
		end
	end
end

handlers.zone = function(z: any)
	local zi = tonumber(z) or 1
	UI.banner(zoneName(zi) .. " UNLOCKED!", "pink", 3)
	UI.confetti(120)
	Sfx.play("unlock", 0.7)
	Sfx.play("victory", 0.5)
	local zd = Config.Zones[zi]
	if zd and zd.gate then
		Fx.burst(zd.gate + Vector3.new(0, 6, 0), { zd.accent, P.white, P.yellow }, 40, 3)
	end
	task.defer(refreshGates)
	UI.closeAll()
end

handlers.teleported = function(z: any)
	UI.flash("white", 0.3)
	Sfx.play("whoosh", 0.5)
	UI.banner(zoneName(z), "sky", 1.6)
end

handlers.rebirth = function(n: any)
	UI.banner(I.rebirth .. " REBIRTH " .. tostring(n) .. "!", "orange", 3)
	UI.toast("Coins now x" .. string.format("%.1f", Econ.rebirthMult(tonumber(n) or 0)) .. " forever!", "orange", 4)
	UI.confetti(140)
	UI.flash("yellow", 0.3)
	Sfx.play("victory", 0.6)
	UI.closeAll()
end

handlers.daily = function(streak: any, coins: any, megaDarts: any, luck: any)
	local extra = ""
	if (tonumber(megaDarts) or 0) > 0 then
		extra ..= " + " .. I.megaDart .. " " .. tostring(megaDarts) .. " Mega Darts"
	end
	if (tonumber(luck) or 0) > 0 then
		extra ..= " + " .. I.luck .. " " .. tostring(luck) .. " min Lucky Boost"
	end
	UI.banner(I.daily .. " DAY " .. tostring(streak) .. " GIFT!", "green", 2.4)
	UI.toast(I.daily .. " Daily gift: " .. I.coin .. " " .. Fmt.num(tonumber(coins) or 0) .. " coins" .. extra, "green", 4)
	UI.fly(UI.center(), Hud.coinTarget(), 12, I.coin, Hud.punchCoins)
	UI.confetti(60)
	Sfx.play("cash", 0.6)
end

handlers.fell = function()
	UI.toast("Whoops! Back to solid ground.", "sky", 2)
	Sfx.play("whoosh", 0.4)
end

handlers.bought = function(key: any, amount: any)
	local item = type(key) == "string" and Config.Products[key] or nil
	if not item then
		return
	end
	local n = tonumber(amount) or 0
	local text = item.glyph .. " " .. item.name .. "!"
	if item.darts and not item.base then
		text = I.megaDart .. " +" .. n .. " Mega Darts! Tap the " .. I.megaDart .. " button to arm them."
	elseif key == "LuckBoost" then
		text = I.luck .. " Lucky Boost for " .. n .. " minutes: rarer balloons spawn near you!"
	elseif key ~= "SummonMega" then
		text = item.glyph .. " +" .. I.coin .. " " .. Fmt.num(n) .. (item.darts and (" + " .. I.megaDart .. " Mega Darts") or "") .. "!"
		UI.fly(UI.center(), Hud.coinTarget(), 14, I.coin, Hud.punchCoins)
	end
	UI.toast(text, item.color, 4)
	UI.confetti(50)
	Sfx.play("purchase", 0.6)
end

handlers.pass = function(key: any)
	local item = type(key) == "string" and Config.Passes[key] or nil
	if not item then
		return
	end
	UI.banner(item.glyph .. " " .. string.upper(item.name) .. "!", item.color, 2.6)
	UI.toast(item.desc, item.color, 4)
	UI.confetti(90)
	Sfx.play("purchase", 0.6)
	Sfx.play("victory", 0.4)
end

-- Free rewards: the FTUE welcome gift (before minute 1) and the FREE panel (playtime, quests, codes, group,
-- invites; the kit already toasts their text).
handlers.gift = function(coins: any, darts: any, luck: any, source: any)
	local c, md = tonumber(coins) or 0, tonumber(darts) or 0
	if source == "welcome" then
		UI.banner(I.gift .. " FREE GIFT!", "green", 2.4)
		UI.toast(I.megaDart .. " +" .. md .. " FREE Mega Darts! Each one pops everything around it.", "green", 5)
		Guide.hint(I.megaDart .. " Tap the " .. I.megaDart .. " button, then throw at a big balloon!", 10, "Mega")
	elseif (tonumber(luck) or 0) > 0 then
		UI.floater(I.luck .. " +" .. tostring(luck) .. " min Luck", "green", UI.center() - Vector2.new(0, 80), 40)
	end
	if c > 0 then
		UI.fly(UI.center(), Hud.coinTarget(), 12, I.coin, Hud.punchCoins)
	end
	if md > 0 then
		UI.punch(Hud.buttons.Mega.button, 0.25)
	end
	UI.confetti(60)
	Sfx.play("cash", 0.6)
end

handlers.meterFull = function(zone: any)
	UI.banner(I.boss .. " " .. zoneName(zone) .. " 100% POPPED!", "red", 2.6)
	UI.toast(I.boss .. " " .. (UI.isMobile and "Tap" or "Click") .. " the meter at the top to fight the BOSS!", "red", 5)
	Sfx.play("unlock", 0.6)
end

handlers.bossSpawned = function(id: any, zone: any)
	if type(id) ~= "number" then
		return
	end
	local zi = tonumber(zone) or 1
	Guide.setBoss(id, zi)
	BalloonView.markRare(id)
	UI.banner(I.boss .. " " .. string.upper(Config.Zones[zi] and Config.Zones[zi].name or "") .. " BOSS!", "red", 2.4)
	UI.shake(0.6)
	Sfx.play("reveal", 0.6, 0.8)
end

handlers.bossDown = function(zone: any, unlocked: any, darts: any, _count: any)
	Guide.setBoss(nil)
	UI.banner(I.boss .. " " .. zoneName(zone) .. " BOSS DEFEATED!", "gold", 3)
	UI.toast(I.megaDart .. " +" .. tostring(darts) .. " Mega Darts for beating the boss!", "gold", 4)
	UI.confetti(160)
	UI.flash("yellow", 0.3)
	Sfx.play("victory", 0.7)
	local u = tonumber(unlocked) or 0
	if u > 0 then
		task.delay(3, function()
			handlers.zone(u)
		end)
	end
	local d = State.data
	if d and not d.factory and Econ.bossCount(d) >= #Config.Zones then
		task.delay(6, function()
			UI.toast(I.factory .. " Balloons still pour out of somewhere... Find the secret Balloon Factory!", "purple", 6)
		end)
	end
end

handlers.bossEscaped = function(_zone: any)
	Guide.setBoss(nil)
	UI.toast(I.boss .. " The boss floated away! Your meter is still full: tap it to call the boss back.", "orange", 5)
	Sfx.play("whoosh", 0.4)
end

handlers.trial = function(pass: any, minutes: any)
	local item = type(pass) == "string" and Config.Passes[pass] or nil
	if not item then
		return
	end
	UI.banner(item.glyph .. " " .. string.upper(item.name) .. " ON!", item.color, 2.4)
	UI.toast(item.glyph .. " " .. item.name .. " for " .. tostring(minutes) .. " minutes. Love it? Keep it forever in the Shop!", item.color, 5)
	UI.confetti(60)
	Sfx.play("purchase", 0.6)
end

handlers.trialEnd = function(pass: any)
	local item = type(pass) == "string" and Config.Passes[pass] or nil
	if item then
		UI.toast(item.glyph .. " Your " .. item.name .. " trial ended. Keep it forever in the " .. I.shop .. " Shop!", item.color, 6)
	end
end

handlers.factory = function(coins: any, darts: any)
	UI.banner(I.factory .. " FACTORY SHUT DOWN!", "gold", 4)
	UI.toast(I.house .. " The town is safe: no more balloons carry it away! +" .. I.coin .. " " .. Fmt.num(tonumber(coins) or 0) .. " + " .. I.megaDart .. " " .. tostring(darts), "gold", 7)
	UI.confetti(220)
	UI.flash("white", 0.4)
	UI.fly(UI.center(), Hud.coinTarget(), 18, I.coin, Hud.punchCoins)
	Sfx.play("victory", 0.8)
end

handlers.hourly = function()
	UI.banner(I.clock .. " HOURLY MEGA BALLOON!", "gold", 3)
	UI.toast(I.clock .. " A GIANT MEGA BALLOON + " .. Config.Event.hourly.boost .. "x coins for everyone for " .. Config.Event.hourly.boostMinutes .. " minutes!", "gold", 5)
	Sfx.play("magic", 0.6)
end

Net.event("Ui").OnClientEvent:Connect(function(kind: any, ...: any)
	local f = type(kind) == "string" and handlers[kind] or nil
	if f then
		local ok, err = pcall(f, ...)
		if not ok then
			warn("[Ui]", kind, err)
		end
	end
end)

---------------------------------------------------------------------------------------------------------------
-- Gates you own open locally (the server still guards locked zones)
---------------------------------------------------------------------------------------------------------------

local function addGate(inst: Instance)
	local z = inst:GetAttribute("Zone")
	if type(z) == "number" then
		gateWalls[inst] = z
		refreshGates()
	end
end
for _, w in ipairs(CollectionService:GetTagged("ZoneGate")) do
	addGate(w)
end
CollectionService:GetInstanceAddedSignal("ZoneGate"):Connect(addGate)
CollectionService:GetInstanceRemovedSignal("ZoneGate"):Connect(function(inst)
	gateWalls[inst] = nil
end)
local lastZones = 0
State.onChange(function(d)
	if (d.zones or 1) ~= lastZones then
		lastZones = d.zones or 1
		refreshGates()
	end
end)

---------------------------------------------------------------------------------------------------------------
-- Zone ambience: each island cluster tints the sky; arrival banner
---------------------------------------------------------------------------------------------------------------

local currentZone = 0
local function applyZone(zi: number, instant: boolean)
	local z = Config.Zones[zi]
	if not z then
		return
	end
	local info = TweenInfo.new(instant and 0 or 2.5, Enum.EasingStyle.Sine)
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		TweenService:Create(atmo, info, { Color = z.sky.atmo, Decay = z.sky.decay, Density = z.sky.density, Haze = z.sky.haze }):Play()
	end
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if cc then
		TweenService:Create(cc, info, { TintColor = z.sky.tint }):Play()
	end
	TweenService:Create(Lighting, info, { ClockTime = z.sky.clock, OutdoorAmbient = z.sky.ambient }):Play()
end

task.spawn(function()
	while true do
		task.wait(0.5)
		local r = hrp()
		if r then
			local zi = Econ.zoneAt(r.Position)
			Hud.setZone(zi)
			if zi > 0 and zi ~= currentZone then
				local first = currentZone == 0
				currentZone = zi
				pcall(applyZone, zi, first)
				if not first then
					UI.banner(zoneName(zi), "sky", 1.8)
					Sfx.play("whoosh", 0.4, 1.1)
				end
			end
		end
	end
end)

---------------------------------------------------------------------------------------------------------------
-- Booth pads in the hub: step on the glowing pad to open that menu
---------------------------------------------------------------------------------------------------------------

type Pad = { pos: Vector3, panel: string, inside: boolean }
local pads: { Pad } = {}
for _, b in ipairs(Config.Hub.booths) do
	table.insert(pads, { pos = Config.boothPos(b.angle, Config.Hub.boothR - 8.5), panel = b.panel, inside = false })
end
task.spawn(function()
	while true do
		task.wait(0.15)
		local r = hrp()
		if r then
			local p = r.Position
			for _, pad in ipairs(pads) do
				local dx, dz = p.X - pad.pos.X, p.Z - pad.pos.Z
				local inside = dx * dx + dz * dz < 3.8 * 3.8 and math.abs(p.Y - pad.pos.Y) < 6
				if inside and not pad.inside then
					Panels.open(pad.panel)
				end
				pad.inside = inside
			end
		end
	end
end)

---------------------------------------------------------------------------------------------------------------
-- VIP chat tag
---------------------------------------------------------------------------------------------------------------

pcall(function()
	local TextChatService = game:GetService("TextChatService")
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local props = Instance.new("TextChatMessageProperties")
		local src = message.TextSource
		if src then
			local p = Players:GetPlayerByUserId(src.UserId)
			if p and p:GetAttribute("VIP") then
				props.PrefixText = "<font color='#FFD23F'>[👑 VIP]</font> " .. message.PrefixText
			end
		end
		return props
	end
end)

---------------------------------------------------------------------------------------------------------------
-- Story intro (first 10 seconds) and offers: none in the first two minutes of a session, never during the MEGA
-- event or over a menu. The Starter Pack only in the first 10 minutes after the first join (its own panel with
-- the countdown); the 9 R$ Welcome Deal once for players who never bought anything, after that window.
---------------------------------------------------------------------------------------------------------------

task.delay(1.5, function()
	UI.banner(string.upper(Config.Title), "pink", 2.6)
	Sfx.play("reveal", 0.4, 1.2)
end)
task.delay(4.5, function()
	UI.toast(I.house .. " " .. Config.Story .. " Pop them ALL to save it!", "pink", 5)
end)

task.spawn(function()
	while Guide.sessionTime() < Config.Ftue.offerAfter do
		task.wait(1)
	end
	Hud.offersOpen = true
	Hud.update()
	local starterDone, introDone = false, false
	while not (starterDone and introDone) do
		task.wait(5)
		local d = State.data
		if d then
			if Econ.starterLeft(d) <= 30 then
				starterDone = true
			end
			if not Econ.introOpen(d) then
				introDone = true
			end
			if not Panels.anyOpen() and MegaView.phase() == "idle" then
				if not starterDone then
					starterDone = true
					Panels.open("Starter")
				elseif not introDone and Econ.starterLeft(d) <= 0 and Guide.sessionTime() >= Config.Ftue.introAfter then
					introDone = true
					local item = Config.Products.Intro
					UI.offer({
						title = "WELCOME DEAL",
						text = I.coin .. " " .. Fmt.num(Econ.packCoins(item.base or 3000, d)) .. " coins + " .. I.megaDart .. " " .. (item.darts or 10) .. " Mega Darts. Only once, only for you!",
						glyph = item.glyph,
						price = "R$ " .. Fmt.commas(item.price),
						color = item.color,
						seconds = 30,
						onBuy = function()
							buyRemote:FireServer("product", "Intro")
						end,
					})
				end
			end
		end
	end
end)

print("[Balloons] client ready")

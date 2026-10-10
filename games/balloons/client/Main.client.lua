-- Pop All The Balloons! 🎈 — client entry point.
-- Builds the HUD and menus, starts the balloon / MEGA BALLOON views and the guide, routes server "Ui" messages
-- to the right effects, and runs the small local systems: zone ambience, gates you already own, booth pads that
-- open their menu, the VIP chat tag, music + mute and the one-time Starter Pack offer.
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

local player = Players.LocalPlayer
local I = Config.Icons
local P = Config.Palette
local buyRemote = Net.event("Buy")

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
	Panels.open("Shop", "Boosts")
end
Hud.onButton.Summon = function()
	Panels.open("Shop", "Boosts")
end
Hud.onButton.MegaShop = function()
	Panels.open("Shop", "Boosts")
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
	UI.toast(I.coin .. " " .. Fmt.num(tonumber(coins) or 0) .. extra, "green", 4)
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
	if key == "MegaDarts" then
		text = I.megaDart .. " +" .. n .. " Mega Darts! Tap the " .. I.megaDart .. " button to arm them."
	elseif key == "LuckBoost" then
		text = I.luck .. " Lucky Boost for " .. n .. " minutes: rarer balloons spawn near you!"
	elseif key ~= "SummonMega" then
		text = item.glyph .. " +" .. I.coin .. " " .. Fmt.num(n) .. "!"
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
-- Welcome and the one-time Starter Pack offer (never before minute 4, never during the event)
---------------------------------------------------------------------------------------------------------------

task.delay(1.5, function()
	UI.banner("POP ALL THE BALLOONS! " .. I.pop, "pink", 2.6)
	Sfx.play("reveal", 0.4, 1.2)
end)

task.spawn(function()
	local offered = false
	while not offered do
		task.wait(5)
		local d = State.data
		if d and not d.starter and Guide.sessionTime() >= Config.Ftue.offerAfter and not Panels.anyOpen() and MegaView.phase() == "idle" then
			offered = true
			local item = Config.Products.Starter
			UI.offer({
				title = "STARTER PACK",
				text = I.coin .. " " .. Fmt.num(Econ.packCoins(item.base or 2000, d)) .. " coins + 15 Mega Darts + 30 min Lucky Boost. Only once!",
				glyph = item.glyph,
				price = "R$ " .. item.price,
				color = item.color,
				onBuy = function()
					buyRemote:FireServer("product", "Starter")
				end,
			})
		elseif d and d.starter then
			offered = true
		end
	end
end)

print("[Balloons] client ready")

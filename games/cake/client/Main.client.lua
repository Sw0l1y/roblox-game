-- Client entry: HUD, menus, decorating, the show, one camera arbiter, music, server messages, the first
-- minute (warm-up decorating, first-coin rewards, the welcome gift), offers (never in a first session's first
-- 2 minutes), live Robux prices, the FREE panel and the VIP chat tag.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientLib = ReplicatedStorage:WaitForChild("ClientLib")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local UI = require(ClientLib:WaitForChild("UI"))
local Sfx = require(ClientLib:WaitForChild("Sfx"))
local _Fx = require(ClientLib:WaitForChild("Fx")) -- hooks server-triggered effects
local State = require(ClientLib:WaitForChild("State"))
local Prices = require(ClientLib:WaitForChild("Prices"))
local LiveUI = require(ClientLib:WaitForChild("LiveUI"))
local Own = require(ClientLib:WaitForChild("Own"))
local Hud = require(ClientLib:WaitForChild("Hud"))
local Panels = require(ClientLib:WaitForChild("Panels"))
local BuildMode = require(ClientLib:WaitForChild("BuildMode"))
local Showtime = require(ClientLib:WaitForChild("Showtime"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local state = ReplicatedStorage:WaitForChild("CakeState")
local actFunc = Net.func("Act")
local buyRemote = Net.event("Buy")

local function act(action: string, a: any?, b: any?): any
	local ok, res = pcall(function()
		return actFunc:InvokeServer(action, a, b)
	end)
	return if ok then res else nil
end

local function buy(kind: string, key: string)
	buyRemote:FireServer(kind, key)
end

local sessionStart = os.clock()

local ctx: { [string]: any } = {}
ctx.data = function(): { [string]: any }?
	return State.data
end
ctx.act = act
ctx.buy = buy
ctx.tut = function(n: number)
	local d = State.data
	if d and (d.tut or 0) < n then
		d.tut = n
		task.spawn(act, "tut", n)
	end
end
ctx.flyCoins = function(from: Vector2, amount: number)
	Hud.flyCoins(from, amount)
end
ctx.openShop = function(tab: string?)
	Panels.openShop(tab)
end
ctx.openIndex = function()
	Panels.openIndex()
end
ctx.openDaily = function()
	Panels.openDaily()
end
ctx.openBox = function()
	Panels.openBox()
end
ctx.openTheme = function()
	Panels.openTheme()
end
ctx.openFree = function()
	LiveUI.open()
end
ctx.openTrack = function()
	Panels.openTrack()
end
ctx.openDeal = function()
	Panels.openDeal()
end
ctx.sessionAge = function(): number
	return os.clock() - sessionStart
end
-- No purchase prompt or offer popup in the first 2 minutes of a player's first session.
ctx.canPrompt = function(): boolean
	local d = State.data
	if d and (d.sessions or 1) > 1 then
		return true
	end
	return os.clock() - sessionStart >= Config.PromptGrace
end
-- Paid random items are hidden until the server's policy lookup clears this player (kit Policy).
ctx.blocked = function(): boolean
	return player:GetAttribute("RandomBlocked") ~= false
end

Prices.sync(Config.Passes :: any, Config.Products :: any)
LiveUI.init(Config.Live)
Hud.init(ctx)
Panels.init(ctx)
BuildMode.init(ctx, state)
Showtime.init(ctx, state)
LiveUI.onClaimable(Hud.setFreeBadge)
Prices.onChange(function()
	Panels.refresh()
	local d = State.data
	if d then
		Hud.update(d)
	end
end)

Sfx.music(Config.Music)

-- Save data --------------------------------------------------------------------------------------------------
local first = true
State.onChange(function(d: { [string]: any }, _prev: { [string]: any }?)
	if first then
		first = false
		Sfx.setMuted(d.muted == true)
		if (d.rounds or 0) == 0 then
			UI.banner(Config.titleCaps(), "pink", 2.4)
			task.delay(1.2, function()
				UI.toast("Bake the best cake for the theme · everyone votes!", "pink", 4)
			end)
		else
			UI.toast("🎂 Welcome back, " .. player.DisplayName .. "!", "pink")
		end
	end
	Hud.update(d)
	Panels.update(d)
	BuildMode.update(d)
end)

-- Server messages ------------------------------------------------------------------------------------------------
Net.event("Round").OnClientEvent:Connect(function(kind: any, p: any)
	if type(kind) ~= "string" then
		return
	end
	if kind == "theme" and type(p) == "table" then
		BuildMode.onTheme(tostring(p.theme or ""))
	end
	Showtime.onRound(kind, p)
end)

Net.event("Reward").OnClientEvent:Connect(function(r: any)
	if type(r) ~= "table" then
		return
	end
	if r.kind == "round" then
		Showtime.onReward(r)
	elseif r.kind == "vote" then
		if r.fair then
			UI.floater("🎯 Fair judge! +" .. tostring(r.coins) .. " 💰", "green", UI.center() + Vector2.new(0, 60), 30)
		else
			UI.floater("+" .. tostring(r.coins) .. " 💰", "gold", UI.center() + Vector2.new(0, 120), 34)
		end
		Sfx.play("coin", 0.3)
	elseif r.kind == "ftue" then -- first frosting / first topping: the first coins within seconds
		local at = UI.center() + Vector2.new(0, -40)
		UI.floater("+" .. tostring(r.coins) .. " 💰", "gold", at, 44)
		UI.toast(if r.key == "frost" then "🎨 First decoration! Here are some coins" else "🍒 First topping! Keep decorating", "gold", 2.5)
		Hud.flyCoins(at, tonumber(r.coins) or 25)
		Sfx.play("cash", 0.5)
	elseif r.kind == "level" then
		task.delay(1.5, function()
			UI.banner("LEVEL UP! Lv " .. tostring(r.level), "gold", 2.4)
			UI.toast("⭐ New title: " .. tostring(r.title), "purple", 4)
			UI.confetti(90)
			Sfx.play("unlock", 0.6)
		end)
	end
end)

Net.event("Announce").OnClientEvent:Connect(function(text: any, color: any, big: any)
	if type(text) ~= "string" then
		return
	end
	if big then
		UI.banner(text, color or "gold", 2.8)
		Sfx.play("notify", 0.5)
	else
		UI.toast(text, color or "white", 3.5)
	end
end)

-- Camera arbiter: the show camera, else the build camera, else the normal follow camera -------------------
local scripted = false
local camCF = camera.CFrame
local saved: { speed: number, jump: number, height: number }? = nil

local function lockMovement(on: boolean)
	local char = player.Character
	local found = char and char:FindFirstChildOfClass("Humanoid")
	if not found then
		return
	end
	local hum = found :: Humanoid
	if on then
		if hum.WalkSpeed > 0 then
			saved = { speed = hum.WalkSpeed, jump = hum.JumpPower, height = hum.JumpHeight }
			hum.WalkSpeed = 0
			hum.JumpPower = 0
			hum.JumpHeight = 0
		end
	else
		local s = saved
		if s and hum.WalkSpeed == 0 then
			hum.WalkSpeed = s.speed
			hum.JumpPower = s.jump
			hum.JumpHeight = s.height
			saved = nil
		end
	end
end

RunService:BindToRenderStep("CakeCam", Enum.RenderPriority.Camera.Value, function(dt: number)
	-- decorating in your own Overtime beats the stage camera
	local want = (if BuildMode.overtimeLeft() > 0 then BuildMode.camera() else nil) or Showtime.camera() or BuildMode.camera()
	if want then
		if not scripted then
			scripted = true
			camCF = camera.CFrame
		end
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		camCF = camCF:Lerp(want, 1 - math.exp(-dt * 6))
		camera.CFrame = camCF
	elseif scripted then
		scripted = false
		camera.CameraType = Enum.CameraType.Custom
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			camera.CameraSubject = hum :: Humanoid
		end
	end
	lockMovement(want ~= nil)
end)

RunService.Heartbeat:Connect(function(dt: number)
	Hud.tick(state, workspace:GetServerTimeNow(), BuildMode.isActive(), Showtime.spinning(), BuildMode.overtime())
	BuildMode.tick(dt)
	Showtime.setHidden(BuildMode.overtimeLeft() > 0)
	Showtime.tick(dt)
	Hud.tip(Showtime.tip() or BuildMode.tip())
end)

-- The first minute's free gift: the welcome box (guaranteed Rare) opens itself at ~40 s, between moments, and by
-- ~55 s at the latest.
task.spawn(function()
	while true do
		task.wait(1)
		local d = State.data
		if d and (d.firstBox or Own.freeBoxes(d) <= 0 or (d.sessions or 1) > 1) then
			break
		end
		local age = ctx.sessionAge()
		local ph = tostring(state:GetAttribute("Phase") or "")
		local busy = ph == "Vote" or ph == "Results" or Panels.anyOpen()
		if d and age >= 40 and (not busy or age >= 55) and Panels.welcomeGift() then
			break
		end
	end
end)

-- Offers: the starter pack once (first 10 minutes after the first join, from minute 2.5, in a lobby), and the
-- 9 R$ intro for players who never bought anything, at most once a session after the starter window.
task.spawn(function()
	local introShown = false
	while true do
		task.wait(3)
		local d = State.data
		local ph = state:GetAttribute("Phase")
		local calm = (ph == "Lobby" or ph == "Waiting") and not Panels.anyOpen() and ctx.canPrompt()
		if d and calm then
			if not d.offerShown and Own.starterLeft(d) > 0 and ctx.sessionAge() >= Config.OfferAfter then
				d.offerShown = true
				task.spawn(act, "offerShown")
				Panels.starterOffer()
			elseif not introShown and Own.introOk(d) and Own.starterLeft(d) <= 0 and ctx.sessionAge() >= 240 then
				introShown = true
				Panels.introOffer()
			end
		end
	end
end)

-- VIP chat tag (TextChatService) ---------------------------------------------------------------------------------
pcall(function()
	local tcs = game:GetService("TextChatService") :: any
	tcs.OnIncomingMessage = function(msg: any)
		local props = Instance.new("TextChatMessageProperties")
		local src = msg.TextSource
		if src then
			local p = Players:GetPlayerByUserId(src.UserId)
			if p and p:GetAttribute("Golden") then
				props.PrefixText = "<font color='#FFC83C'>[🏆 GOLDEN]</font> " .. msg.PrefixText
			elseif p and p:GetAttribute("VIP") then
				props.PrefixText = "<font color='#FF78B4'>[👑 VIP]</font> " .. msg.PrefixText
			end
		end
		return props
	end
end)

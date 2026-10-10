-- Cake Off! 🎂 client entry: HUD, menus, decorating, the show, one camera arbiter, music, server messages,
-- FTUE tips, the one-time starter offer and the VIP chat tag.
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

Hud.init(ctx)
Panels.init(ctx)
BuildMode.init(ctx, state)
Showtime.init(ctx, state)

Sfx.music(Config.Music)

-- Save data --------------------------------------------------------------------------------------------------
local first = true
State.onChange(function(d: { [string]: any }, _prev: { [string]: any }?)
	if first then
		first = false
		Sfx.setMuted(d.muted == true)
		if (d.rounds or 0) == 0 then
			UI.banner("🎂 CAKE OFF!", "pink", 2.4)
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
		UI.floater("+" .. tostring(r.coins) .. " 🪙", "gold", UI.center() + Vector2.new(0, 120), 34)
		Sfx.play("coin", 0.3)
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
	local want = Showtime.camera() or BuildMode.camera()
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
	Hud.tick(state, workspace:GetServerTimeNow())
	BuildMode.tick(dt)
	Showtime.tick(dt)
	Hud.tip(Showtime.tip() or BuildMode.tip())
end)

-- One-time starter offer (never in the first minutes, never mid-round) ------------------------------------
task.spawn(function()
	local start = os.clock()
	while true do
		task.wait(5)
		local d = State.data
		local ph = state:GetAttribute("Phase")
		if d and (d.offerShown or d.starter) then
			break
		end
		if d and os.clock() - start >= Config.OfferAfter and (ph == "Lobby" or ph == "Waiting") then
			d.offerShown = true
			task.spawn(act, "offerShown")
			UI.offer({
				title = "BAKER STARTER PACK",
				text = "2,000 coins + 3 Mystery Boxes · one time only!",
				glyph = "🧁",
				price = "R$ " .. Config.Products.Starter.price,
				color = "pink",
				seconds = 30,
				onBuy = function()
					buy("product", "Starter")
				end,
			})
			break
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

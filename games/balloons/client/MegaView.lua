-- The MEGA BALLOON event on the client: the pill / countdown banner, the balloon inflating on the hub's Mega
-- Pump, rising with the server-wide HP bar, over-inflating and shaking as it loses HP, the explosion (the clip
-- moment), and the coin rain each player collects for themselves. Server state comes from the attributes on
-- ReplicatedStorage.GameState (Phase, NextAt, Hp, MaxHp, FightAt, PopAt, Summoner).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local Fmt = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Fmt"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local BalloonArt = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BalloonArt"))
local UI = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("UI"))
local Sfx = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("Sfx"))
local Fx = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("Fx"))
local Hud = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("Hud"))

local MegaView = {}

type Coin = { idx: number, part: BasePart, pos: Vector3, from: Vector3, landAt: number, t0: number, taken: boolean, gone: boolean }

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local P = Config.Palette
local H = Config.Hub
local E = Config.Event
local rng = Random.new()

local state: Instance? = nil
local model: Model? = nil
local scale = 1
local phase = "idle"
local countdownLen = 30
local lastSecond = -1
local wobble = 0
local center = H.megaPos
local radius = H.megaSize / 2
local folder: Folder
local coins: { Coin } = {}
local coinValue = 0
local coinsUntil = 0
local pendingCoins: { number } = {}
local lastSend = 0
local actionRemote = Net.event("Action")

local function now(): number
	return workspace:GetServerTimeNow()
end

local function attr(name: string, default: any): any
	local s = state
	if not s then
		return default
	end
	local v = s:GetAttribute(name)
	if v == nil then
		return default
	end
	return v
end

local function hrp(): BasePart?
	local c = player.Character
	local h = c and c:FindFirstChild("HumanoidRootPart")
	if h and h:IsA("BasePart") then
		return h :: BasePart
	end
	return nil
end

local function setScale(s: number)
	local m = model
	if not m or math.abs(s - scale) < 0.004 then
		return
	end
	scale = s
	pcall(function()
		m:ScaleTo(s)
	end)
end

local function show(on: boolean)
	local m = model
	if m then
		m.Parent = on and folder or nil
	end
end

---------------------------------------------------------------------------------------------------------------
-- Public: targeting and hits (BalloonView throws darts at the Mega Balloon as id 0)
---------------------------------------------------------------------------------------------------------------

function MegaView.phase(): string
	return phase
end

-- Position and radius while the Mega Balloon can be hit, else nil.
function MegaView.target(): (Vector3?, number)
	if phase == "fight" and model and model.Parent then
		return center, radius
	end
	return nil, 0
end

-- A point on the balloon's surface facing `from` (darts aim here).
function MegaView.aimPoint(from: Vector3, seed: number): Vector3
	local dir = from - center
	if dir.Magnitude < 0.1 then
		return center
	end
	local u = dir.Unit
	local side = u:Cross(Vector3.yAxis)
	if side.Magnitude < 0.1 then
		side = Vector3.xAxis
	end
	side = side.Unit
	local up = side:Cross(u).Unit
	local a = seed * math.pi * 2
	local off = (side * math.cos(a) + up * math.sin(a)) * radius * 0.45 * ((seed * 7.3) % 1)
	return center + u * radius * 0.82 + off
end

function MegaView.onHit(mega: boolean, mine: boolean)
	if phase ~= "fight" then
		return
	end
	wobble = math.min(1.5, wobble + (mega and 1.2 or 0.35))
	Hud.megaHit()
	if mine then
		local cam = camera.CFrame.Position
		local dir = cam - center
		local p = dir.Magnitude > 0.1 and (center + dir.Unit * radius * 0.9) or center
		Fx.burst(p, { P.pink, P.yellow, P.white }, mega and 14 or 3, mega and 2 or 0.6)
		Sfx.play("thud", 0.2, rng:NextNumber(0.8, 1), 0.5)
	end
end

---------------------------------------------------------------------------------------------------------------
-- Coin rain
---------------------------------------------------------------------------------------------------------------

local function clearCoins()
	for _, c in ipairs(coins) do
		if not c.gone then
			c.gone = true
			c.part:Destroy()
		end
	end
	coins = {}
	pendingCoins = {}
end

function MegaView.onRain(flat: any, value: any)
	if type(flat) ~= "table" then
		return
	end
	clearCoins()
	coinValue = tonumber(value) or 1
	coinsUntil = os.clock() + E.rainSeconds
	local n = math.floor(#flat / 3)
	local t = os.clock()
	for i = 1, n do
		local x, z, y = tonumber(flat[i * 3 - 2]) or 0, tonumber(flat[i * 3 - 1]) or 0, tonumber(flat[i * 3]) or 0
		local pos = Vector3.new(x, y + 1.4, z)
		local p = Instance.new("Part")
		p.Name = "RainCoin"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.45, 2.4, 2.4)
		p.Color = P.gold
		p.Material = Enum.Material.SmoothPlastic
		p.Reflectance = 0.25
		local from = center + Vector3.new(rng:NextNumber(-6, 6), rng:NextNumber(-4, 6), rng:NextNumber(-6, 6))
		p.CFrame = CFrame.new(from)
		p.Parent = folder
		table.insert(coins, { idx = i, part = p, pos = pos, from = from, landAt = t + 0.6 + rng:NextNumber(0, 1.4), t0 = t, taken = false, gone = false })
	end
end

local function stepCoins(dt: number)
	if #coins == 0 then
		return
	end
	local t = os.clock()
	local r = hrp()
	local me = r and r.Position
	if t > coinsUntil then
		clearCoins()
		return
	end
	for _, c in ipairs(coins) do
		if not c.gone then
			local p = c.part
			if c.taken then
				-- fly into the player
				local target = me or c.pos
				local cur = p.Position
				local nxt = cur:Lerp(target + Vector3.new(0, 1, 0), math.min(1, dt * 14))
				p.CFrame = CFrame.new(nxt) * CFrame.Angles(0, t * 12, 0)
				if (nxt - target).Magnitude < 2.2 then
					c.gone = true
					p:Destroy()
				end
			elseif t < c.landAt then
				local k = math.clamp((t - c.t0) / (c.landAt - c.t0), 0, 1)
				local pos = c.from:Lerp(c.pos, k) + Vector3.new(0, math.sin(k * math.pi) * 22, 0)
				p.CFrame = CFrame.new(pos) * CFrame.Angles(0, t * 9, 0)
			else
				local bob = math.sin(t * 3 + c.idx) * 0.3
				p.CFrame = CFrame.new(c.pos + Vector3.new(0, bob, 0)) * CFrame.Angles(0, t * 3 + c.idx, 0)
				if me then
					local dx, dz = c.pos.X - me.X, c.pos.Z - me.Z
					if dx * dx + dz * dz < 11 * 11 and math.abs(c.pos.Y - me.Y) < 9 then
						c.taken = true
						table.insert(pendingCoins, c.idx)
						Fx.popup(c.pos + Vector3.new(0, 2, 0), "+" .. Fmt.num(coinValue), P.yellow, 0.7)
						Sfx.play("coin", 0.25, 1 + rng:NextNumber(0, 0.3), 0.6)
						local sp = UI.screenPos(c.pos)
						if sp then
							UI.fly(sp, Hud.coinTarget(), 1, Config.Icons.coin, Hud.punchCoins)
						end
					end
				end
			end
		end
	end
	if #pendingCoins > 0 and t - lastSend > 0.2 then
		lastSend = t
		local batch = {}
		for i = 1, math.min(20, #pendingCoins) do
			table.insert(batch, table.remove(pendingCoins, 1))
		end
		actionRemote:FireServer("coin", batch)
	end
end

---------------------------------------------------------------------------------------------------------------
-- Explosion and messages
---------------------------------------------------------------------------------------------------------------

local function explode()
	local pos = center
	show(false)
	Hud.setMegaHp(false)
	local near = (pos - camera.CFrame.Position).Magnitude < 320
	if near then
		local cols = { P.pink, P.yellow, P.sky, P.white, P.mint, P.accent }
		Fx.burst(pos, cols, 60, 4.5)
		Fx.shockwave(pos, P.pink, 70)
		Fx.shockwave(pos + Vector3.new(0, 2, 0), P.yellow, 46)
		for i = 1, 6 do
			task.delay(i * 0.09, function()
				local off = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * radius * 0.8
				Fx.burst(pos + off, cols, 14, 2.5)
			end)
		end
		UI.shake(1.2)
	end
	UI.flash("white", 0.15)
	UI.confetti(130)
	UI.banner("💥 MEGA POP! 💥", "pink", 2.6)
	Sfx.play("pop", 1, 0.45, 2)
	Sfx.play("pop", 0.8, 0.7, 2)
	Sfx.play("cheer", 0.55, 1, 4)
	task.delay(0.35, function()
		Sfx.play("victory", 0.5)
	end)
end

function MegaView.onPop(name: any)
	if type(name) == "string" and name ~= "" then
		UI.toast("🎯 " .. name .. " landed the final dart!", "pink", 4)
	end
end

function MegaView.onReward(coinsGot: any, pct: any)
	local c = tonumber(coinsGot) or 0
	UI.toast(Config.Icons.mega .. " MEGA reward: " .. Config.Icons.coin .. " " .. Fmt.num(c) .. "  (you did " .. tostring(tonumber(pct) or 0) .. "% of the damage)", "gold", 4.5)
	UI.fly(UI.center(), Hud.coinTarget(), 12, Config.Icons.coin, Hud.punchCoins)
	Sfx.play("cash", 0.5)
end

---------------------------------------------------------------------------------------------------------------
-- Phase changes and per-frame update
---------------------------------------------------------------------------------------------------------------

local function onPhase()
	local p = attr("Phase", "idle")
	if p == phase then
		return
	end
	local prev = phase
	phase = p
	local t = now()
	if p == "countdown" then
		countdownLen = math.max(3, attr("NextAt", t + E.countdown) - t)
		lastSecond = -1
		setScale(0.12)
		show(true)
		local by = attr("Summoner", "")
		UI.banner(Config.Icons.mega .. " MEGA BALLOON INCOMING!", "pink", 2.4)
		UI.toast(by ~= "" and ("📣 " .. by .. " summoned the MEGA BALLOON! Get to the hub!") or "🎈 The MEGA BALLOON is inflating at the hub! Get there!", "pink", 4)
		Sfx.play("notify", 0.6)
		Sfx.play("reveal", 0.4)
	elseif p == "rise" then
		show(true)
		Hud.setPill(nil)
		Hud.setMegaHp(true, attr("Hp", 1), attr("MaxHp", 1), Config.Icons.mega .. " MEGA BALLOON")
		UI.banner("POP THE MEGA BALLOON!", "pink", 2.2)
		Sfx.play("reveal", 0.6, 0.9)
	elseif p == "fight" then
		show(true)
		Hud.setPill(nil)
		setScale(1)
		Hud.setMegaHp(true, attr("Hp", 1), attr("MaxHp", 1), Config.Icons.mega .. " MEGA BALLOON")
		if prev ~= "rise" then
			UI.toast("🎈 The MEGA BALLOON is up! Throw darts at it!", "pink", 3)
		end
	elseif p == "popped" then
		Hud.setMegaHp(false)
		if t - attr("PopAt", 0) < 4 then
			explode()
		else
			show(false)
		end
	else
		show(false)
		Hud.setMegaHp(false)
		clearCoins()
	end
end

local function step(dt: number)
	local t = now()
	local tc = os.clock()
	wobble = math.max(0, wobble - dt * 2.2)
	local m = model
	if phase == "countdown" then
		local nextAt = attr("NextAt", t)
		local left = math.max(0, nextAt - t)
		local k = 1 - math.clamp(left / math.max(1, countdownLen), 0, 1)
		setScale(0.12 + 0.43 * k)
		local d = H.megaSize * scale
		center = Vector3.new(0, H.nozzleTop + d * 0.575 - 0.3, 0)
		radius = d / 2
		local sec = math.ceil(left)
		if sec ~= lastSecond then
			lastSecond = sec
			Hud.setPill(Config.Icons.mega .. " MEGA BALLOON in " .. Fmt.time(sec) .. "!", "pink")
			Hud.pillPunch()
			if sec <= 5 and sec >= 1 then
				UI.banner(tostring(sec), "pink", 0.8)
				Sfx.play("beep", 0.5, 1 + (5 - sec) * 0.06)
			end
		end
		if m then
			local squash = 1 + math.sin(tc * 8) * 0.01
			m:PivotTo(CFrame.new(center) * CFrame.Angles(0, tc * 0.3, math.sin(tc * 2) * 0.03 * squash))
		end
	elseif phase == "rise" then
		local fightAt = attr("FightAt", t)
		local k = 1 - math.clamp((fightAt - t) / E.riseTime, 0, 1)
		local e = k * k * (3 - 2 * k)
		setScale(0.55 + 0.45 * e)
		local d = H.megaSize * scale
		local startY = H.nozzleTop + d * 0.575
		center = Vector3.new(0, startY + (H.megaPos.Y - startY) * e, 0)
		radius = d / 2
		if m then
			m:PivotTo(CFrame.new(center) * CFrame.Angles(0, tc * 0.3, math.sin(tc * 3) * 0.05))
		end
		Hud.setMegaHp(true, attr("Hp", 1), attr("MaxHp", 1))
	elseif phase == "fight" then
		local hp, maxHp = attr("Hp", 1), math.max(1, attr("MaxHp", 1))
		local frac = math.clamp(hp / maxHp, 0, 1)
		setScale(1 + 0.2 * (1 - frac))
		radius = H.megaSize * scale / 2
		local jitter = frac < 0.25 and (0.25 - frac) * 3 or 0
		local w = wobble
		center = H.megaPos + Vector3.new(math.sin(tc * 0.7) * 1.5, math.sin(tc * 1.3) * 1.2, math.cos(tc * 0.6) * 1.5)
		if m then
			local shake = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * jitter
			m:PivotTo(CFrame.new(center + shake) * CFrame.Angles(math.sin(tc * 30) * 0.05 * w, tc * 0.3, math.sin(tc * 26) * 0.06 * w))
		end
		Hud.setMegaHp(true, hp, maxHp)
		local by = attr("Summoner", "")
		Hud.setPill(nil)
		if by ~= "" then
			Hud.setMegaHp(true, nil, nil, Config.Icons.mega .. " MEGA BALLOON · summoned by " .. by)
		end
	elseif phase == "popped" then
		local sec = math.ceil(math.max(0, coinsUntil - os.clock()))
		if #coins > 0 then
			if sec ~= lastSecond then
				lastSecond = sec
				Hud.setPill(Config.Icons.coin .. " COIN RAIN at the hub! " .. sec .. "s", "gold")
			end
		else
			Hud.setPill(nil)
		end
	else
		local nextAt = attr("NextAt", 0)
		local left = math.max(0, nextAt - t)
		local sec = math.ceil(left)
		if sec ~= lastSecond then
			lastSecond = sec
			Hud.setPill(Config.Icons.mega .. " MEGA BALLOON in " .. Fmt.time(sec), "pink")
		end
	end
	stepCoins(dt)
end

function MegaView.init()
	folder = Instance.new("Folder")
	folder.Name = "ClientMega"
	folder.Parent = workspace
	local m = BalloonArt.build(Config.Mega, { size = H.megaSize, noString = true })
	BalloonArt.fx(m, Config.Mega, 3)
	model = m
	scale = 1
	task.spawn(function()
		local s = ReplicatedStorage:WaitForChild("GameState", 30)
		if not s then
			warn("[MegaView] no GameState")
			return
		end
		state = s
		s:GetAttributeChangedSignal("Phase"):Connect(onPhase)
		onPhase()
	end)
	local warned = 0
	RunService.RenderStepped:Connect(function(dt)
		local ok, err = pcall(step, dt)
		if not ok and warned < 5 then
			warned += 1
			warn("[MegaView]", err)
		end
	end)
end

return MegaView

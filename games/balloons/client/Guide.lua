-- "What next?" guidance: the goal bar at the bottom, a glowing beam + bouncing arrow in the world, and pulsing
-- HUD buttons. FTUE order: pop your first balloon -> buy your first upgrade -> pop the seeded rare -> fill the
-- zone meter and beat its boss (or buy the next zone) -> ... -> the secret Balloon Factory -> rebirth. Interrupts
-- for the MEGA BALLOON event, your zone boss, a short hint (e.g. the free gift), coin rain and a full Balloon Pump.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Fmt = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Fmt"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Econ = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Econ"))
local UI = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("UI"))
local State = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("State"))
local Hud = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("Hud"))
local Panels = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("Panels"))
local MegaView = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("MegaView"))
local BalloonView = require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("BalloonView"))

local Guide = {}

type PData = { [string]: any }
type Goal = { text: string, frac: number?, label: string?, target: Vector3?, pulse: string? }

local player = Players.LocalPlayer
local I = Config.Icons
local P = Config.Palette

local anchor: Part
local arrowGui: BillboardGui
local arrowText: TextLabel
local beam: Beam
local a1: Attachment
local a0: Attachment? = nil
local rareId: number? = nil
local rareUntil = 0
local bossId: number? = nil
local bossZone = 0
local hintText: string? = nil
local hintUntil = 0
local hintPulse: string? = nil
local pumpShownAt = -1000
local pulsing: string? = nil
local joinedAt = os.clock()

local function hrp(): BasePart?
	local c = player.Character
	local h = c and c:FindFirstChild("HumanoidRootPart")
	if h and h:IsA("BasePart") then
		return h :: BasePart
	end
	return nil
end

local function attach(c: Model)
	task.spawn(function()
		local h = c:WaitForChild("HumanoidRootPart", 10)
		if h and h:IsA("BasePart") then
			local a = Instance.new("Attachment")
			a.Name = "GuideBeam"
			a.Position = Vector3.new(0, -1.2, 0)
			a.Parent = h
			a0 = a
			beam.Attachment0 = a
		end
	end)
end

local function setTarget(pos: Vector3?)
	if not pos or not a0 then
		beam.Enabled = false
		arrowGui.Enabled = false
		return
	end
	anchor.CFrame = CFrame.new(pos)
	beam.Enabled = true
	arrowGui.Enabled = true
end

-- Next goal from the save data; nil fields = nothing to show.
local function compute(d: PData, pos: Vector3): Goal?
	local phase = MegaView.phase()
	local coins = d.coins or 0
	local hub = Vector3.new(0, 0, 0)
	local farFromHub = (Vector3.new(pos.X, 0, pos.Z) - hub).Magnitude > 70 or math.abs(pos.Y) > 20

	-- the MEGA BALLOON event beats everything
	if (phase == "countdown" or phase == "rise" or phase == "fight") and farFromHub then
		return { text = I.mega .. " MEGA BALLOON at the hub! Go go go!", target = Vector3.new(0, 4, 0), pulse = (Econ.zoneAt(pos) > 1) and "Zones" or nil }
	end

	-- a seeded rare just for you
	local rid = rareId
	if rid and os.clock() < rareUntil then
		local rp = BalloonView.posOf(rid)
		if rp then
			return { text = I.sparkle .. " A RARE balloon appeared near you! Pop it!", target = rp }
		end
		rareId = nil
	end

	-- your zone boss is out
	local bid = bossId
	if bid then
		local bp = BalloonView.posOf(bid)
		local bz = Config.Zones[bossZone]
		if bp and bz then
			return { text = I.boss .. " Pop the " .. string.upper(bz.name) .. " BOSS! Mega Darts hit hard", target = bp, pulse = Hud.megaDarts() > 0 and not Hud.megaArmed and "Mega" or nil }
		end
		bossId = nil
	end

	-- a short hint (free gift, trials)
	local hint = hintText
	if hint and os.clock() < hintUntil then
		return { text = hint, pulse = (hintPulse ~= "Mega" or not Hud.megaArmed) and hintPulse or nil }
	end

	-- first pop
	if (d.pops or 0) == 0 then
		local near = BalloonView.nearest(pos, 60)
		return { text = (UI.isMobile and "👆 Tap" or "🖱️ Click") .. " a balloon to throw a dart!", target = near }
	end

	-- first upgrade
	local ft = d.ftue or {}
	local anyUpgrade = ft.upgrade == true
	if not anyUpgrade and type(d.up) == "table" then
		for _, lvl in pairs(d.up) do
			if type(lvl) == "number" and lvl > 0 then
				anyUpgrade = true
				break
			end
		end
	end
	if not anyUpgrade then
		local cost = Econ.upgradeCost("power", Econ.level(d, "power"))
		if coins >= cost then
			return { text = I.upgrades .. " You can buy your first upgrade!", pulse = "Upgrades" }
		end
		return { text = I.coin .. " Pop balloons for your first upgrade!", frac = coins / cost, label = Fmt.num(coins) .. " / " .. Fmt.num(cost) }
	end

	-- the zone meter is full: fight the boss
	local zone = Econ.zoneAt(pos)
	if Hud.meterIsFull() and Config.Zones[zone] then
		return { text = I.boss .. " " .. string.upper(Config.Zones[zone].name) .. " 100% POPPED! " .. (UI.isMobile and "Tap" or "Click") .. " the meter to fight the BOSS" }
	end

	-- a full Balloon Pump (shown for a while every few minutes)
	local spot = player:GetAttribute("Pump")
	local rate = Econ.pumpRate(d)
	if type(spot) == "number" and zone == 1 and (d.pump or 0) >= rate * 300 then
		local tc = os.clock()
		if tc - pumpShownAt > 240 then
			pumpShownAt = tc
		end
		if tc - pumpShownAt < 25 then
			local sp = Config.Hub.pumpSpots[spot]
			if sp then
				return { text = I.pump .. " Your Balloon Pump has " .. I.coin .. " " .. Fmt.num(d.pump or 0) .. "! Collect it", target = sp + Vector3.new(0, 6, 0) }
			end
		end
	end

	-- next zone
	local zi = (d.zones or 1) + 1
	local z = Config.Zones[zi]
	if z then
		if coins >= z.cost then
			if zone == zi - 1 then
				return { text = z.glyph .. " Unlock " .. z.name .. "! Walk to the gate", target = (z.gate :: Vector3) + Vector3.new(0, 5, 0) }
			end
			return { text = z.glyph .. " You can unlock " .. z.name .. "!", pulse = "Zones" }
		end
		return { text = z.glyph .. " Next: " .. z.name .. "  (or beat the " .. I.boss .. " BOSS)", frac = coins / z.cost, label = I.coin .. " " .. Fmt.num(coins) .. " / " .. Fmt.num(z.cost) }
	end

	-- the secret ending: every zone boss beaten, the Balloon Factory behind Space is still running
	if not d.factory and Econ.bossCount(d) >= #Config.Zones then
		return { text = I.factory .. " Find the secret Balloon Factory and shut it down!", target = Config.Factory.pos + Vector3.new(0, 6, 16) }
	end

	-- rebirth
	local cost = Econ.rebirthCost(d.rebirths or 0)
	if coins >= cost then
		return { text = I.rebirth .. " Rebirth for x" .. string.format("%.1f", Econ.rebirthMult((d.rebirths or 0) + 1)) .. " coins forever!", pulse = "Rebirth" }
	end
	return { text = I.rebirth .. " Rebirth for x" .. string.format("%.1f", Econ.rebirthMult((d.rebirths or 0) + 1)) .. " coins", frac = coins / cost, label = I.coin .. " " .. Fmt.num(coins) .. " / " .. Fmt.num(cost) }
end

local function update()
	local d = State.data
	local r = hrp()
	if not d or not r then
		Hud.setGoal(nil)
		setTarget(nil)
		return
	end
	local g = compute(d, r.Position)
	if not g then
		Hud.setGoal(nil)
		setTarget(nil)
		return
	end
	Hud.setGoal(g.text, g.frac, g.label)
	local target = g.target
	if target and (target - r.Position).Magnitude < 7 then
		target = nil
	end
	setTarget(target)
	local want = g.pulse
	if want and Panels.anyOpen() then
		want = nil
	end
	if pulsing ~= want then
		if pulsing then
			Hud.pulse(pulsing, false)
		end
		pulsing = want
		if want then
			Hud.pulse(want, true)
		end
	end
end

-- Server seeded a rare near this player (FTUE): point at it for a while.
function Guide.setRare(id: number)
	rareId = id
	rareUntil = os.clock() + 40
end

-- The player's zone boss is out: point at it until it pops or floats away (nil clears it).
function Guide.setBoss(id: number?, zone: number?)
	bossId = id
	bossZone = zone or 0
end

-- Show a short line in the goal bar for a few seconds (after the FTUE steps that need it), optionally pulsing
-- a HUD button.
function Guide.hint(text: string, seconds: number?, pulse: string?)
	hintText = text
	hintUntil = os.clock() + (seconds or 8)
	hintPulse = pulse
end

function Guide.sessionTime(): number
	return os.clock() - joinedAt
end

function Guide.init()
	anchor = Instance.new("Part")
	anchor.Name = "GuideTarget"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(0, -500, 0)
	anchor.Parent = workspace
	a1 = Instance.new("Attachment")
	a1.Parent = anchor
	beam = Instance.new("Beam")
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(P.glow, P.white)
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(0.15, 0.3), NumberSequenceKeypoint.new(1, 0.15) })
	beam.Width0 = 0.5
	beam.Width1 = 0.9
	beam.FaceCamera = true
	beam.LightEmission = 0.7
	beam.Segments = 1
	beam.Enabled = false
	beam.Parent = anchor

	arrowGui = Instance.new("BillboardGui")
	arrowGui.Name = "GuideArrow"
	arrowGui.Size = UDim2.fromOffset(70, 70)
	arrowGui.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	arrowGui.AlwaysOnTop = true
	arrowGui.LightInfluence = 0
	arrowGui.Enabled = false
	arrowGui.Adornee = anchor
	arrowText = Instance.new("TextLabel")
	arrowText.BackgroundTransparency = 1
	arrowText.Size = UDim2.fromScale(1, 1)
	arrowText.Font = Enum.Font.GothamBold
	arrowText.TextScaled = true
	arrowText.Text = I.arrow
	arrowText.Parent = arrowGui
	arrowGui.Parent = anchor

	player.CharacterAdded:Connect(attach)
	if player.Character then
		attach(player.Character)
	end
	RunService.RenderStepped:Connect(function()
		if arrowGui.Enabled then
			arrowGui.StudsOffsetWorldSpace = Vector3.new(0, 3 + math.abs(math.sin(os.clock() * 4)) * 1.6, 0)
		end
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(update)
			if not ok then
				warn("[Guide]", err)
			end
			task.wait(0.25)
		end
	end)
end

return Guide

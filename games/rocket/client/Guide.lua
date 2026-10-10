-- First-time flow and "what next" guidance: a glowing beam + bouncing arrow to the current goal (the nose
-- cone at your feet, then the launch pad, then the depot, then the Gear kiosk when you can afford gloves),
-- a hint line, help-ping beams to crewmates who need a hand, a pulsing Gear button, and gentle offers that
-- only start after Config.Tune.offerAfter seconds (never before minute 2).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local ClientLib = ReplicatedStorage:WaitForChild("ClientLib")
local UI = require(ClientLib:WaitForChild("UI"))
local Sfx = require(ClientLib:WaitForChild("Sfx"))
local State = require(ClientLib:WaitForChild("State"))
local Hub = require(ClientLib:WaitForChild("Hub"))
local Render = require(ClientLib:WaitForChild("Render"))
local Hud = require(ClientLib:WaitForChild("Hud"))

local Guide = {}

local T = Config.Tune
local I = Config.Icons
local P = Config.Palette
local player = Hub.player
local buyRemote = Net.event("Buy")

-- Goal marker: an invisible anchor with a target attachment, a bouncing neon arrow and a ground ring.
local marker = Instance.new("Part")
marker.Name = "GuideTarget"
marker.Anchored = true
marker.CanCollide = false
marker.CanQuery = false
marker.CanTouch = false
marker.Transparency = 1
marker.Size = Vector3.new(1, 1, 1)
marker.Parent = workspace
local targetAtt = Instance.new("Attachment")
targetAtt.Parent = marker

local function neon(size: Vector3, color: Color3, shape: Enum.PartType?): BasePart
	local p = Instance.new("Part")
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = workspace
	return p
end

local arrowHead = Instance.new("WedgePart")
arrowHead.Size = Vector3.new(0.6, 2.4, 2.6)
arrowHead.Color = P.gold
arrowHead.Material = Enum.Material.Neon
arrowHead.Anchored = true
arrowHead.CanCollide = false
arrowHead.CanQuery = false
arrowHead.CanTouch = false
arrowHead.CastShadow = false
arrowHead.Parent = workspace
local arrowHead2 = (arrowHead:Clone() :: any) :: WedgePart
arrowHead2.Parent = workspace
local arrowStem = neon(Vector3.new(1, 2.6, 1), P.gold)
local ring = neon(Vector3.new(0.2, 9, 9), P.gold, Enum.PartType.Cylinder)
ring.Transparency = 0.45
local markerParts: { BasePart } = { arrowHead, arrowHead2, arrowStem, ring }

local beam = Instance.new("Beam")
beam.Attachment1 = targetAtt
beam.Color = ColorSequence.new(P.gold, Color3.fromRGB(255, 240, 170))
beam.Transparency = NumberSequence.new(0.15, 0.5)
beam.Width0 = 1.1
beam.Width1 = 1.1
beam.FaceCamera = true
beam.LightEmission = 0.7
beam.Segments = 12
beam.CurveSize0 = 0
beam.CurveSize1 = 0
beam.Enabled = false
beam.Parent = marker

local function showMarker(pos: Vector3?, color: Color3?, height: number?)
	local on = pos ~= nil
	beam.Enabled = on
	for i, p in ipairs(markerParts) do
		p.Transparency = if on then (if i == 4 then 0.45 else 0.05) else 1
	end
	if not pos then
		marker.CFrame = CFrame.new(0, -500, 0)
		return
	end
	local c = color or P.gold
	if arrowHead.Color ~= c then
		for _, p in ipairs(markerParts) do
			p.Color = c
		end
		beam.Color = ColorSequence.new(c, Color3.new(1, 1, 1):Lerp(c, 0.4))
	end
	local h = height or 6
	marker.CFrame = CFrame.new(pos + Vector3.new(0, 1.2, 0))
	local bob = math.sin(os.clock() * 4) * 0.8
	local top = pos + Vector3.new(0, h + 4 + bob, 0)
	local spin = CFrame.Angles(0, os.clock() * 1.6, 0)
	arrowStem.CFrame = CFrame.new(top + Vector3.new(0, 1.6, 0)) * spin
	-- two wedges back to back form a downward arrow head
	arrowHead.CFrame = CFrame.new(top - Vector3.new(0, 0.9, 0)) * spin * CFrame.new(0, 0, -0.65) * CFrame.Angles(math.rad(180), 0, 0)
	arrowHead2.CFrame = CFrame.new(top - Vector3.new(0, 0.9, 0)) * spin * CFrame.new(0, 0, 0.65) * CFrame.Angles(math.rad(180), math.rad(180), 0)
	local pulse = 8 + math.sin(os.clock() * 5) * 1.2
	ring.Size = Vector3.new(0.2, pulse, pulse)
	ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90))
end

local rootAtt: Attachment? = nil
local function attachBeam()
	local r = Hub.root()
	if not r then
		beam.Attachment0 = nil
		return
	end
	if rootAtt and rootAtt.Parent == r then
		return
	end
	local a = Instance.new("Attachment")
	a.Name = "GuideAttachment"
	a.Position = Vector3.new(0, -1.5, 0)
	a.Parent = r
	rootAtt = a
	beam.Attachment0 = a
end

-- Goal selection -------------------------------------------------------------------------------------------------

local helpPos: Vector3? = nil
local helpUntil = 0
local stuckSeen = 0
local idleSince = os.clock()

local function nearestPart(ftueOnly: boolean): Vector3?
	local r = Hub.root()
	if not r then
		return nil
	end
	local best: Vector3? = nil
	local bestD = math.huge
	for _, v in pairs(Render.vis) do
		if not v.flying and not v.orphanAt and v.cfg:GetAttribute("Mode") == "rest" then
			local isFtue = v.cfg:GetAttribute("Ftue") == true
			if not ftueOnly or isFtue then
				local d = (v.center - r.Position).Magnitude
				if isFtue then
					d -= 1000
				end
				if d < bestD then
					bestD = d
					best = v.center
				end
			end
		end
	end
	return best
end

local function groundOf(pos: Vector3): Vector3
	return Vector3.new(pos.X, Hub.origin().Y, pos.Z)
end

local function gearAffordable(d: { [string]: any }): boolean
	local cost = Config.gearCost("gloves", tonumber(d.gear.gloves) or 1)
	return cost ~= nil and (tonumber(d.coins) or 0) >= cost
end

type Goal = { pos: Vector3?, hint: string, color: Color3?, height: number? }

local function pick(): Goal
	local phase = Hub.phase()
	if phase ~= "build" or Hub.cinematic then
		return { pos = nil, hint = "" }
	end
	local d = State.data
	if not d then
		return { pos = nil, hint = "" }
	end
	local step = tonumber(d.ftue.step) or 0
	local delivered = tonumber(d.delivered) or 0
	local press = if UI.isMobile then "tap LIFT" else "press E"
	local carry = Hub.carry
	if carry then
		idleSince = os.clock()
		if carry.speed <= 0 then
			stuckSeen += 1
			return { pos = nil, hint = I.help .. " Too heavy! Tap NEED A HAND - crew bots and players will help lift." }
		end
		return {
			pos = groundOf(Hub.padCenter()),
			hint = if delivered < 3 then I.rocket .. " Carry it to the glowing ring on the launch pad!" else "",
			color = P.glow,
			height = 14,
		}
	end
	if helpPos and os.clock() < helpUntil then
		return { pos = groundOf(helpPos), hint = I.help .. " A crewmate needs a hand! Help lift it for coins.", color = P.orange, height = 8 }
	end
	if step < 1 then
		local p = nearestPart(true) or nearestPart(false)
		return { pos = p and groundOf(p), hint = string.format("%s Walk to the glowing Nose Cone and %s to LIFT it!", "👇", press), height = 6 }
	end
	if step >= 2 and step < 3 and gearAffordable(d) then
		return {
			pos = Hub.origin() + Config.Layout.gearKiosk,
			hint = I.gear .. " You can afford POWER GLOVES! Open GEAR to get stronger.",
			color = P.sky,
			height = 10,
		}
	end
	if delivered < 6 or os.clock() - idleSince > 12 then
		local p = nearestPart(false)
		if p then
			return {
				pos = groundOf(p),
				hint = if delivered < 6 then string.format("%s Grab the next part at the depot and %s!", I.box, press) else "",
				height = 6,
			}
		end
	end
	if step < 4 and delivered >= 6 then
		return { pos = nil, hint = string.format("%s Fill every slot to LAUNCH! (%d/%d)", I.launch, Hub.num("Filled", 0), Hub.num("Total", 1)) }
	end
	return { pos = nil, hint = "" }
end

-- Offers (never before T.offerAfter seconds; at most one every 5 minutes, 3 per session) ---------------------

local offersShown = 0
local lastOffer = 0

local function anyPanelOpen(): boolean
	for _, n in ipairs({ "Shop", "Gear", "Index", "Daily", "Crew", "Notice", "__offer" }) do
		local p = UI.getPanel(n)
		if p and p.isOpen() then
			return true
		end
	end
	return false
end

local function owns(key: string): boolean
	local d = State.data
	if not d then
		return false
	end
	local passes: any = d.passes
	if type(passes) ~= "table" then
		return false
	end
	return (passes :: any)[key] == true
end

local function maybeOffer()
	if offersShown >= 3 or os.clock() - Hub.joinedAt < T.offerAfter or os.clock() - lastOffer < 300 then
		return
	end
	if Hub.cinematic or Hub.phase() ~= "build" or Hub.carry ~= nil or anyPanelOpen() then
		return
	end
	local d = State.data
	if not d then
		return
	end
	local o: { [string]: any }? = nil
	if not d.starter then
		local item = Config.Products.StarterPack
		o = {
			title = "STARTER PACK",
			text = item.desc,
			glyph = item.icon,
			price = "R$ " .. item.price,
			color = "pink",
			seconds = 25,
			onBuy = function()
				buyRemote:FireServer("product", "StarterPack")
			end,
		}
	elseif stuckSeen > 20 then
		for _, key in ipairs(Config.Ladder) do
			if not owns(key) then
				local pass = (Config.Passes :: any)[key]
				o = {
					title = "TOO HEAVY?",
					text = string.format("%s forever. Lift the big boosters solo!", pass.name),
					glyph = pass.icon,
					price = "R$ " .. pass.price,
					color = "orange",
					seconds = 25,
					onBuy = function()
						buyRemote:FireServer("pass", key)
					end,
				}
				break
			end
		end
	elseif not owns("RobotCrew") then
		local pass = Config.Passes.RobotCrew
		o = {
			title = "ROBOT CREW",
			text = pass.desc,
			glyph = pass.icon,
			price = "R$ " .. pass.price,
			color = "teal",
			seconds = 25,
			onBuy = function()
				buyRemote:FireServer("pass", "RobotCrew")
			end,
		}
	end
	if o then
		offersShown += 1
		lastOffer = os.clock()
		stuckSeen = 0
		UI.offer(o)
		Sfx.play("sparkle", 0.4)
	end
end

function Guide.init()
	Hub.on("help", function(p: any)
		if type(p) ~= "table" or p.uid == player.UserId or typeof(p.pos) ~= "Vector3" then
			return
		end
		local r = Hub.root()
		if r and (r.Position - p.pos).Magnitude < 140 then
			helpPos = p.pos
			helpUntil = os.clock() + 8
		end
	end)
	Hub.on("bolt", function()
		helpPos = nil
	end)

	local acc = 0
	local pulseAt = 0
	local goal: Goal = { pos = nil, hint = "" }
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc >= 0.2 then
			acc = 0
			attachBeam()
			goal = pick()
			Hud.setHint(goal.hint)
			local d = State.data
			if d and (tonumber(d.ftue.step) or 0) == 2 and gearAffordable(d) and os.clock() > pulseAt then
				pulseAt = os.clock() + 1.2
				local b = Hud.buttons.Gear
				if b then
					UI.punch(b.button, 0.2)
				end
			end
		end
		showMarker(goal.pos, goal.color, goal.height)
	end)
	task.spawn(function()
		while true do
			task.wait(10)
			maybeOffer()
		end
	end)
	-- welcome
	task.delay(1.5, function()
		local d = State.wait()
		if (tonumber(d.ftue.step) or 0) < 1 then
			UI.banner(Config.Title, "orange", 2.6)
			Sfx.play("reveal", 0.5)
		else
			UI.banner(string.format("WELCOME BACK, %s!", string.upper(player.DisplayName)), "sky", 2.2)
		end
	end)
end

return Guide

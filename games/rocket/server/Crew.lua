-- Everything about a crew member: strength (hauling + gear + passes, never click-to-train), walk/haul speed,
-- the rank tag over your head, gear you can see on your avatar (gloves, jetpack, bubble helmet), coin
-- rewards for deliveries and this rocket's contribution board.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local Fmt = require(Shared:WaitForChild("Fmt"))
local Data = require(script.Parent:WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local Mission = require(script.Parent:WaitForChild("Mission"))

local Crew = {}

local T = Config.Tune
local carrySpeed: { [Player]: number } = {}
local cache: { [Player]: number } = {}

-- Contribution to the current rocket: userId -> { name, weight }.
Crew.contrib = {} :: { [number]: { name: string, weight: number } }
local boardDirty = true

local function humanoid(player: Player): Humanoid?
	local c = player.Character
	if not c then
		return nil
	end
	return (c:FindFirstChildOfClass("Humanoid") :: any) :: Humanoid?
end

function Crew.root(player: Player): BasePart?
	local c = player.Character
	if not c then
		return nil
	end
	local h = c:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 then
		return nil
	end
	local r = c:FindFirstChild("HumanoidRootPart")
	if r and r:IsA("BasePart") then
		return r :: BasePart
	end
	return nil
end

-- Strength ---------------------------------------------------------------------------------------------

function Crew.ladderMult(player: Player): number
	local best = 1
	for _, key in ipairs(Config.Ladder) do
		local pass = (Config.Passes :: any)[key]
		if pass and Shop.owns(player, key) then
			best = math.max(best, pass.mult or 1)
		end
	end
	return best
end

function Crew.indexCount(d: { [string]: any }): number
	local n = 0
	for _ in pairs(d.index or {}) do
		n += 1
	end
	return n
end

function Crew.gearMult(d: { [string]: any }): number
	local g = d.gear or {}
	local m = 1
	for _, key in ipairs({ "gloves", "suit", "jet" }) do
		local track = Config.Gear[key]
		m *= track.mult[math.clamp(g[key] or 1, 1, #track.mult)]
	end
	return m
end

-- Permanent strength (what the leaderboard shows).
function Crew.baseStrength(player: Player, d: { [string]: any }): number
	local rankIdx = Config.rank(d.hauled or 0)
	local mult = Crew.gearMult(d) * Crew.ladderMult(player) * (1 + T.indexBonus * Crew.indexCount(d)) * (1 + T.rankBonus * (rankIdx - 1))
	return (T.baseStrength + (d.strengthEarned or 0)) * mult
end

-- Effective strength right now (boosts, server fuel, planet suit floor).
function Crew.strength(player: Player): number
	local cached = cache[player]
	if cached then
		return cached
	end
	local d = Data.get(player)
	if not d then
		return T.baseStrength
	end
	local s = Crew.baseStrength(player, d)
	if (d.boostUntil or 0) > os.time() then
		s *= T.potionMult
	end
	if Mission.boosted() then
		s *= 2
	end
	s = math.max(s, T.baseStrength * Mission.weightMult())
	cache[player] = s
	return s
end

function Crew.invalidate(player: Player?)
	if player then
		cache[player] = nil
	else
		table.clear(cache)
	end
end

function Crew.coinMult(player: Player): number
	local m = 1
	if Shop.owns(player, "Coins2x") then
		m *= 2
	end
	if Shop.owns(player, "VIP") then
		m *= T.vipCoin
	end
	if player.MembershipType == Enum.MembershipType.Premium then
		m *= T.premiumCoin
	end
	if Mission.boosted() then
		m *= 2
	end
	return m
end

-- Movement ---------------------------------------------------------------------------------------------

function Crew.applyMovement(player: Player)
	local h = humanoid(player)
	local d = Data.get(player)
	if not h then
		return
	end
	local jetLevel = 1
	if d then
		jetLevel = d.gear.jet or 1
	end
	local jump = (Config.Gear.jet.jump :: { number })[math.clamp(jetLevel, 1, 6)] or 0
	h.UseJumpPower = true
	h.JumpPower = T.jumpPower + jump
	local cs = carrySpeed[player]
	if cs then
		local mult = Shop.owns(player, "MegaJetpack") and T.jetpackHaul or 1
		h.WalkSpeed = math.min(cs * mult, T.maxHaulSpeed * mult)
	else
		h.WalkSpeed = T.walkSpeed
	end
end

-- speed = haul speed while carrying (0 = stuck), nil = free.
function Crew.setCarrySpeed(player: Player, speed: number?)
	if carrySpeed[player] == speed then
		return
	end
	carrySpeed[player] = speed
	player:SetAttribute("Carrying", speed ~= nil)
	Crew.applyMovement(player)
end

-- Rank tag and gear visuals --------------------------------------------------------------------------------

local function tierColor(level: number): Color3
	return Tiers.list[math.clamp(level, 1, #Tiers.list)].color
end

function Crew.tag(player: Player)
	local c = player.Character
	local d = Data.get(player)
	if not c or not d then
		return
	end
	local head = c:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local h = c:FindFirstChildOfClass("Humanoid")
	if h then
		h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local old = head:FindFirstChild("CrewTag")
	if old then
		old:Destroy()
	end
	local rankIdx, rank = Config.rank(d.hauled or 0)
	local vip = Shop.owns(player, "VIP")
	local bb = Instance.new("BillboardGui")
	bb.Name = "CrewTag"
	bb.Size = UDim2.fromScale(8, 2.2)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	bb.Adornee = head
	local function line(y: number, h2: number, text: string, color: Color3, grad: ColorSequence?): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0, y)
		l.Size = UDim2.fromScale(1, h2)
		l.Font = Enum.Font.LuckiestGuy
		l.TextScaled = true
		l.Text = text
		l.TextColor3 = color
		local s = Instance.new("UIStroke")
		s.Thickness = 2.5
		s.Color = Color3.fromRGB(24, 26, 44)
		s.Parent = l
		if grad then
			local g = Instance.new("UIGradient")
			g.Color = grad
			g.Rotation = 90
			g.Parent = l
		end
		l.Parent = bb
		return l
	end
	local rankLine = line(0, 0.48, rank.icon .. " " .. string.upper(rank.name), Color3.new(1, 1, 1), Tiers.gradient(rank.tier))
	if Tiers.get(rank.tier).rainbow then
		rankLine:SetAttribute("Rainbow", true)
	end
	line(0.5, 0.42, (vip and "👑 " or "") .. player.DisplayName, vip and Config.Palette.gold or Color3.new(1, 1, 1), nil)
	bb.Parent = head
	player:SetAttribute("Rank", rankIdx)
end

local function gearPart(parent: Instance, props: { [string]: any }): BasePart
	local p = Instance.new(props.Class or "Part") :: any
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = false
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	for k, v in pairs(props) do
		if k ~= "Class" then
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function weldTo(p: BasePart, to: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = p
	w.Parent = p
end

local function limb(c: Model, names: { string }): BasePart?
	for _, n in ipairs(names) do
		local x = c:FindFirstChild(n)
		if x and x:IsA("BasePart") then
			return x :: BasePart
		end
	end
	return nil
end

-- Gloves (always), jetpack (Jetpack 2+ or Mega Jetpack), bubble helmet (Space Suit 2+ or off Earth).
function Crew.dress(player: Player)
	local c = player.Character
	local d = Data.get(player)
	if not c or not d then
		return
	end
	local old = c:FindFirstChild("GearFx")
	if old then
		old:Destroy()
	end
	local f = Instance.new("Model")
	f.Name = "GearFx"
	f.Parent = c
	local g = d.gear or {}
	local gloveCol = tierColor(g.gloves or 1)
	for _, side in ipairs({ { "RightHand", "Right Arm" }, { "LeftHand", "Left Arm" } }) do
		local hand = limb(c, side)
		if hand then
			local r6 = hand.Name:find("Arm") ~= nil
			local at = hand.CFrame * CFrame.new(0, r6 and -0.9 or -0.1, 0)
			local glove = gearPart(f, { Name = "Glove", Shape = Enum.PartType.Ball, Size = Vector3.new(1.25, 1.25, 1.25), CFrame = at, Color = gloveCol })
			weldTo(glove, hand)
			local cuff = gearPart(f, { Name = "Cuff", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 1.3, 1.3), CFrame = at * CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Config.Palette.orange })
			weldTo(cuff, hand)
		end
	end
	local torso = limb(c, { "UpperTorso", "Torso" })
	local jet = g.jet or 1
	if torso and (jet >= 2 or Shop.owns(player, "MegaJetpack")) then
		local col = Shop.owns(player, "MegaJetpack") and Config.Palette.gold or tierColor(jet)
		for _, x in ipairs({ -0.45, 0.45 }) do
			local at = torso.CFrame * CFrame.new(x, 0.1, 0.85)
			local tank = gearPart(f, { Name = "JetTank", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.9, 0.85, 0.85), CFrame = at * CFrame.Angles(0, 0, math.rad(90)), Color = Config.Palette.white })
			weldTo(tank, torso)
			local band = gearPart(f, { Name = "JetBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 0.92, 0.92), CFrame = at * CFrame.new(0, 0.45, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = col })
			weldTo(band, torso)
			local nozzle = gearPart(f, { Name = "JetNozzle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 0.6, 0.6), CFrame = at * CFrame.new(0, -1.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Config.Palette.padDark })
			weldTo(nozzle, torso)
			local flame = gearPart(f, { Name = "JetFlame", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.9, 0.5), CFrame = at * CFrame.new(0, -1.55, 0), Color = Config.Palette.orange, Material = Enum.Material.Neon, Transparency = 0.2 })
			weldTo(flame, torso)
		end
	end
	local suit = g.suit or 1
	local head = limb(c, { "Head" })
	if head and (suit >= 2 or Mission.planet ~= 1) then
		local bubble = gearPart(f, { Name = "Helmet", Shape = Enum.PartType.Ball, Size = Vector3.new(2.5, 2.5, 2.5), CFrame = head.CFrame * CFrame.new(0, 0.12, 0), Color = Color3.fromRGB(200, 240, 255), Material = Enum.Material.Glass, Transparency = 0.62 })
		weldTo(bubble, head)
		local collar = gearPart(f, { Name = "Collar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 2.2, 2.2), CFrame = head.CFrame * CFrame.new(0, -0.95, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = tierColor(suit) })
		weldTo(collar, head)
	end
end

-- Recompute strength, leaderstats and visuals after anything that changes them.
function Crew.refresh(player: Player)
	local d = Data.get(player)
	if not d then
		return
	end
	cache[player] = nil
	local s = Crew.baseStrength(player, d)
	d.strengthShown = math.floor(s * 10 + 0.5) / 10
	player:SetAttribute("Strength", Crew.strength(player))
	Data.dirty(player)
end

function Crew.addCoins(player: Player, n: number): number
	local d = Data.get(player)
	if not d then
		return 0
	end
	n = math.max(0, math.floor(n + 0.5))
	d.coins = (d.coins or 0) + n
	d.coinsTotal = (d.coinsTotal or 0) + n
	Data.dirty(player)
	return n
end

-- Contribution board ------------------------------------------------------------------------------------

function Crew.contribute(player: Player, weight: number)
	local c = Crew.contrib[player.UserId]
	if not c then
		c = { name = player.DisplayName, weight = 0 }
		Crew.contrib[player.UserId] = c
	end
	c.weight += weight
	boardDirty = true
end

function Crew.resetContrib()
	table.clear(Crew.contrib)
	boardDirty = true
end

function Crew.contribWeights(): { [number]: number }
	local out = {}
	for uid, c in pairs(Crew.contrib) do
		out[uid] = c.weight
	end
	return out
end

export type Entry = { uid: number, name: string, weight: number }

function Crew.top(): { Entry }
	local list: { Entry } = {}
	for uid, c in pairs(Crew.contrib) do
		table.insert(list, { uid = uid, name = c.name, weight = c.weight })
	end
	table.sort(list, function(a: Entry, b: Entry): boolean
		return a.weight > b.weight
	end)
	return list
end

local function updateBoard()
	boardDirty = false
	local list = Crew.top()
	local parts = {}
	for i = 1, math.min(5, #list) do
		local e = list[i]
		table.insert(parts, string.format("%d|%s|%d", e.uid, e.name:gsub("[|;]", ""), math.floor(e.weight)))
	end
	Mission.set("Board", table.concat(parts, ";"))
	local area = Mission.area()
	local medals = { "🥇", "🥈", "🥉", "4.", "5." }
	for i, row in ipairs(area.boardRows) do
		local e = list[i]
		if e then
			row.Text = string.format("%s %s  ⚖️%s", medals[i], e.name, Fmt.num(e.weight))
		else
			row.Text = i == 1 and "Haul a part to get on the board!" or ""
		end
	end
	area.boardTitle.Text = "🏆 CREW BOARD · " .. Mission.planetInfo().name
end

function Crew.init()
	Players.PlayerRemoving:Connect(function(p)
		carrySpeed[p] = nil
		cache[p] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if boardDirty then
				updateBoard()
			end
			-- strength depends on timed boosts: drop the cache once a second
			for _, p in ipairs(Players:GetPlayers()) do
				local before = cache[p]
				cache[p] = nil
				local now = Crew.strength(p)
				if before ~= now then
					p:SetAttribute("Strength", now)
				end
			end
		end
	end)
end

function Crew.markBoard()
	boardDirty = true
end

return Crew

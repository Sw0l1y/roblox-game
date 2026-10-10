-- Balloon Pumps: 16 pump spots ring the hub plaza; each joining player gets one with their name on it.
-- A pump slowly fills with coins while you play AND while you are offline (up to 8 hours); the balloon on top
-- grows as it fills. Walk up and press the prompt to collect. Rate scales with your best zone and rebirths.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local World = require(Shared:WaitForChild("World"))
local Fmt = require(Shared:WaitForChild("Fmt"))
local Config = require(Shared:WaitForChild("Config"))
local Econ = require(Shared:WaitForChild("Econ"))
local BalloonArt = require(Shared:WaitForChild("BalloonArt"))
local Data = require(script.Parent:WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local Progress = require(script.Parent:WaitForChild("Progress"))

local Pump = {}

type Spot = {
	index: number,
	pos: Vector3,
	owner: Player?,
	balloon: BasePart,
	nameLabel: TextLabel,
	coinLabel: TextLabel,
	prompt: ProximityPrompt,
	color: Color3,
	top: Vector3,
}

local spots: { Spot } = {}
local byPlayer: { [Player]: Spot } = {}
local fxRemote = Net.event("Fx")
local P = Config.Palette
local GREY = Color3.fromRGB(200, 200, 210)

local function buildSpot(parent: Instance, i: number, pos: Vector3): Spot
	local m = World.model("Pump" .. i, parent)
	local color = P.rainbow[(i - 1) % #P.rainbow + 1]
	local face = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
	World.disc(m, pos.X, pos.Z, 3, 0.26, 0.3, P.white)
	local ring = World.disc(m, pos.X, pos.Z, 3.4, 0.2, 0.2, color)
	ring.Material = Enum.Material.Neon
	local body = World.cyl(m, pos + Vector3.new(0, 0.3, 0), 2.6, 2, P.red, { Name = "PumpBody" })
	World.cyl(m, pos + Vector3.new(0, 1.2, 0), 0.4, 2.15, P.white)
	World.cyl(m, pos + Vector3.new(0, 2.9, 0), 0.5, 1.4, P.gold)
	World.cyl(m, pos + Vector3.new(0, 3.4, 0), 0.7, 0.5, P.gold)
	local lever = (face * CFrame.new(1.3, 0.3, 0)).Position
	World.rod(m, lever, lever + Vector3.new(0, 3.8, 0), 0.3, P.gold)
	World.rod(m, lever + Vector3.new(0, 3.8, 0) - face.LookVector * 0.9, lever + Vector3.new(0, 3.8, 0) + face.LookVector * 0.9, 0.4, P.ink)
	local top = pos + Vector3.new(0, 4.1, 0)
	local balloon = BalloonArt.ellip(m, "PumpBalloon", Vector3.new(1, 1.15, 1), CFrame.new(top + Vector3.new(0, 0.5, 0)), GREY)
	balloon.Reflectance = 0.06
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			(d :: BasePart).CanTouch = false;
			(d :: BasePart).CastShadow = false
		end
	end

	local bb = Instance.new("BillboardGui")
	bb.Name = "PumpLabel"
	bb.Size = UDim2.fromScale(7, 2.4)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
	bb.MaxDistance = 70
	bb.LightInfluence = 0
	bb.Adornee = body
	local function line(y: number, h: number, text: string, col: Color3): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0, y)
		l.Size = UDim2.fromScale(1, h)
		l.Font = Enum.Font.LuckiestGuy
		l.TextScaled = true
		l.Text = text
		l.TextColor3 = col
		local s = Instance.new("UIStroke")
		s.Thickness = 2.5
		s.Color = P.ink
		s.Parent = l
		l.Parent = bb
		return l
	end
	local nameLabel = line(0, 0.5, "Free Pump", P.white)
	local coinLabel = line(0.5, 0.5, "", P.yellow)
	bb.Parent = body

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CollectPrompt"
	prompt.ActionText = "Collect"
	prompt.ObjectText = "Balloon Pump"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = body

	local s: Spot = {
		index = i,
		pos = pos,
		owner = nil,
		balloon = balloon,
		nameLabel = nameLabel,
		coinLabel = coinLabel,
		prompt = prompt,
		color = color,
		top = top,
	}
	prompt.Triggered:Connect(function(player)
		Pump.collect(player, s)
	end)
	return s
end

local function render(s: Spot)
	local owner = s.owner
	local d = owner and Data.get(owner)
	if not owner or not d then
		s.nameLabel.Text = "Free Pump"
		s.coinLabel.Text = ""
		s.balloon.Size = Vector3.new(1, 1.15, 1)
		s.balloon.CFrame = CFrame.new(s.top + Vector3.new(0, 0.5, 0))
		s.balloon.Color = GREY
		return
	end
	local stored = d.pump or 0
	local fullAt = Econ.pumpRate(d) * Config.Pump.fullMinutes * 60
	local frac = math.clamp(stored / math.max(1, fullAt), 0, 1)
	local size = 1 + frac * 3.4
	s.balloon.Size = Vector3.new(size, size * 1.15, size)
	s.balloon.CFrame = CFrame.new(s.top + Vector3.new(0, size * 0.55, 0))
	s.balloon.Color = s.color
	s.nameLabel.Text = owner.DisplayName .. "'s Pump"
	s.coinLabel.Text = "🪙 " .. Fmt.num(stored)
end

function Pump.spotOf(player: Player): number?
	local s = byPlayer[player]
	return s and s.index or nil
end

function Pump.collect(player: Player, s: Spot?)
	local mine = byPlayer[player]
	if s and s ~= mine then
		local owner = s.owner
		Shop.notify(player, owner and ("This is " .. owner.DisplayName .. "'s pump! Yours has your name on it.") or "This pump is free.", "orange")
		return
	end
	local d = Data.get(player)
	if not d or not mine then
		return
	end
	local amount = math.floor(d.pump or 0)
	if amount < 1 then
		Shop.notify(player, "Your pump is still filling up! ⛽", "orange")
		return
	end
	d.pump = 0
	Progress.addCoins(player, d, amount)
	Progress.ui(player, "pump", amount, mine.top)
	fxRemote:FireAllClients("burst", mine.top + Vector3.new(0, 2, 0), { mine.color, P.yellow, P.white }, 22, 1.2)
	render(mine)
end

local function assign(player: Player)
	if byPlayer[player] then
		return
	end
	for _, s in ipairs(spots) do
		if not s.owner then
			s.owner = player
			byPlayer[player] = s
			player:SetAttribute("Pump", s.index)
			render(s)
			return
		end
	end
end

function Pump.init()
	local root = workspace:FindFirstChild("Map") or workspace
	local folder = World.folder("Pumps", root)
	for i, pos in ipairs(Config.Hub.pumpSpots) do
		table.insert(spots, buildSpot(folder, i, pos))
	end
	Data.onLoaded(function(player, d)
		assign(player)
		-- offline earnings since the last save
		local last = tonumber(d.lastSave) or 0
		if last > 0 then
			local away = math.clamp(os.time() - last, 0, Config.Pump.maxHours * 3600)
			if away >= 60 then
				local gain = math.floor(Econ.pumpRate(d) * away)
				d.pump = math.min(Econ.pumpCap(d), (d.pump or 0) + gain)
				task.delay(4, function()
					Progress.ui(player, "offline", gain, away)
				end)
			end
		end
		local s = byPlayer[player]
		if s then
			render(s)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local s = byPlayer[player]
		if s then
			s.owner = nil
			byPlayer[player] = nil
			render(s)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for player, s in pairs(byPlayer) do
				local d = Data.get(player)
				if d and player.Parent then
					d.pump = math.min(Econ.pumpCap(d), (d.pump or 0) + Econ.pumpRate(d))
					render(s)
				end
			end
		end
	end)
end

return Pump

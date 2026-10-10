-- Build the Rocket! 🚀  Client entry: starts the renderers, HUD, launch cinematic and guide, plays each
-- planet's music, keeps gravity in sync, gives Mega Jetpack owners a flaming double jump and animates
-- rainbow rank tags.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ClientLib = ReplicatedStorage:WaitForChild("ClientLib")
local UI = require(ClientLib:WaitForChild("UI"))
local Sfx = require(ClientLib:WaitForChild("Sfx"))
local Fx = require(ClientLib:WaitForChild("Fx"))
local Hub = require(ClientLib:WaitForChild("Hub"))
local Render = require(ClientLib:WaitForChild("Render"))
local Hud = require(ClientLib:WaitForChild("Hud"))
local Cinema = require(ClientLib:WaitForChild("Cinema"))
local Guide = require(ClientLib:WaitForChild("Guide"))

local player = Players.LocalPlayer
local P = Config.Palette

Render.init()
Hud.init()
Cinema.init()
Guide.init()

-- Music per planet (Earth tracks at home, space tracks out there).
-- Planets share track lists, so the music only restarts when the list really changes.
local musicList: { number }? = nil
local function updateMusic()
	local list = Hub.planetInfo().music
	if list ~= musicList then
		musicList = list
		Sfx.music(list, 0.22)
	end
end
updateMusic()
Hub.state:GetAttributeChangedSignal("Planet"):Connect(updateMusic)

-- Gravity is set by the server; mirror it locally so the low-gravity jumps feel right immediately.
local function syncGravity()
	local g = Hub.num("Gravity", 196.2)
	if math.abs(workspace.Gravity - g) > 0.01 then
		workspace.Gravity = g
	end
end
syncGravity()
Hub.state:GetAttributeChangedSignal("Gravity"):Connect(syncGravity)

-- Mega Jetpack: a second jump in mid-air with a burst of flame.
local usedDouble = false
UserInputService.JumpRequest:Connect(function()
	if player:GetAttribute("MegaJetpack") ~= true or Hub.cinematic or usedDouble then
		return
	end
	local hum = Hub.humanoid()
	local root = Hub.root()
	if not hum or not root or hum.Health <= 0 or root.Anchored then
		return
	end
	if hum:GetState() ~= Enum.HumanoidStateType.Freefall then
		return
	end
	usedDouble = true
	local v = root.AssemblyLinearVelocity
	local up = math.sqrt(2 * workspace.Gravity * 10)
	root.AssemblyLinearVelocity = Vector3.new(v.X, up, v.Z)
	Fx.burst(root.Position - Vector3.new(0, 2.5, 0), { P.orange, P.gold, Color3.fromRGB(255, 240, 170) }, 12, 0.8)
	Sfx.play("whoosh", 0.4, 1.5, 1)
end)

-- Rainbow rank tags (Legend rank) are animated on the client.
local function scanTags()
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local head = c and c:FindFirstChild("Head")
		local tag = head and head:FindFirstChild("CrewTag")
		if tag then
			for _, l in ipairs(tag:GetChildren()) do
				if l:IsA("TextLabel") and l:GetAttribute("Rainbow") == true and not l:FindFirstChild("RainbowGradient") then
					local old = l:FindFirstChildOfClass("UIGradient")
					if old then
						old:Destroy()
					end
					local g = UI.rainbow(l :: TextLabel)
					g.Name = "RainbowGradient"
				end
			end
		end
	end
end

local acc = 0
local tagAcc = 0
RunService.Heartbeat:Connect(function(dt)
	local hum = Hub.humanoid()
	if hum and hum.FloorMaterial ~= Enum.Material.Air then
		usedDouble = false
	end
	acc += dt
	tagAcc += dt
	if acc > 1 then
		acc = 0
		syncGravity()
	end
	if tagAcc > 3 then
		tagAcc = 0
		scanTags()
	end
end)

-- StarterPlayer.StarterPlayerScripts.Client
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local gui = Instance.new("ScreenGui")
gui.Name = "MainGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(obj, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	c.Parent = obj
end

local function label(parent, text, pos, size)
	local l = Instance.new("TextLabel")
	l.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	l.BackgroundTransparency = 0.25
	l.Position = pos
	l.Size = size
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Text = text
	l.Parent = parent
	corner(l)
	return l
end

local function button(parent, text, color, pos, size)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color
	b.Position = pos
	b.Size = size
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b)
	local s = Instance.new("UIStroke")
	s.Thickness = 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = b
	return b
end

-- Stats (top-left)
local powerLbl = label(gui, "", UDim2.new(0, 12, 0, 60), UDim2.fromOffset(220, 40))
local coinsLbl = label(gui, "", UDim2.new(0, 12, 0, 106), UDim2.fromOffset(220, 40))
local rebirthLbl = label(gui, "", UDim2.new(0, 12, 0, 152), UDim2.fromOffset(220, 40))

-- Main buttons (bottom-center)
local clickBtn = button(gui, "CLICK!", Color3.fromRGB(70, 140, 255), UDim2.new(0.5, -90, 1, -200), UDim2.fromOffset(180, 90))
local upgradeBtn = button(gui, "", Color3.fromRGB(60, 190, 90), UDim2.new(0.5, -290, 1, -100), UDim2.fromOffset(190, 70))
local rebirthBtn = button(gui, "", Color3.fromRGB(200, 70, 200), UDim2.new(0.5, -95, 1, -100), UDim2.fromOffset(190, 70))
local shopBtn = button(gui, "SHOP", Color3.fromRGB(255, 170, 30), UDim2.new(0.5, 100, 1, -100), UDim2.fromOffset(190, 70))

local hint = label(gui, "Click to gain Power, then walk onto the yellow pad to sell!", UDim2.new(0.5, -230, 0, 12), UDim2.fromOffset(460, 34))
task.delay(15, function()
	hint:Destroy()
end)

-- Shop panel
local shop = Instance.new("Frame")
shop.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
shop.Position = UDim2.new(0.5, -170, 0.5, -170)
shop.Size = UDim2.fromOffset(340, 340)
shop.Visible = false
shop.Parent = gui
corner(shop, 16)
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Parent = shop
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 10)
pad.Parent = shop

local function shopItem(name, color, onClick)
	local b = button(shop, name, color, UDim2.new(), UDim2.fromOffset(300, 54))
	b.Activated:Connect(onClick)
	return b
end

for _, gp in ipairs(Config.GamePasses) do
	local b = shopItem(gp.Name, Color3.fromRGB(80, 110, 230), function()
		if gp.Id ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, gp.Id)
		end
	end)
	local function refresh()
		if player:GetAttribute("Pass_" .. gp.Key) then
			b.Text = gp.Name .. " (Owned)"
			b.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
		end
	end
	player:GetAttributeChangedSignal("Pass_" .. gp.Key):Connect(refresh)
	refresh()
end
for _, prod in ipairs(Config.Products) do
	shopItem(prod.Name, Color3.fromRGB(230, 160, 40), function()
		if prod.Id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, prod.Id)
		end
	end)
end
shopItem("Close", Color3.fromRGB(180, 60, 60), function()
	shop.Visible = false
end)

-- Wiring
clickBtn.Activated:Connect(function()
	remotes.Click:FireServer()
end)
upgradeBtn.Activated:Connect(function()
	remotes.Upgrade:FireServer()
end)
rebirthBtn.Activated:Connect(function()
	remotes.Rebirth:FireServer()
end)
shopBtn.Activated:Connect(function()
	shop.Visible = not shop.Visible
end)

local function get(key)
	return player:GetAttribute(key) or 0
end

local function render()
	local rebirths = get("Rebirths")
	powerLbl.Text = "Power: " .. Config.Format(get("Power"))
	coinsLbl.Text = "Coins: " .. Config.Format(get("Coins"))
	rebirthLbl.Text = "Rebirths: " .. rebirths .. " (x" .. Config.RebirthMult(rebirths) .. ")"
	upgradeBtn.Text = "Upgrade\n" .. Config.Format(Config.UpgradeCost(get("Level"))) .. " Coins"
	rebirthBtn.Text = "Rebirth\n" .. Config.Format(Config.RebirthCost(rebirths)) .. " Coins"
end

for _, key in ipairs({ "Power", "Coins", "Level", "Rebirths" }) do
	player:GetAttributeChangedSignal(key):Connect(render)
end
render()

-- Toy Army client: music, the arena (garrisons, battles, the block tower), the house cat, paid strikes, the HUD and
-- menus, live Robux prices, the FREE menu (codes, gifts, quests) and chat tags for VIP / Pro Commanders.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local ClientLib = ReplicatedStorage:WaitForChild("ClientLib")
local Sfx = require(ClientLib:WaitForChild("Sfx"))
local Arena = require(ClientLib:WaitForChild("Arena"))
local CatView = require(ClientLib:WaitForChild("CatView"))
local Hud = require(ClientLib:WaitForChild("Hud"))
local Panels = require(ClientLib:WaitForChild("Panels"))
local StrikeView = require(ClientLib:WaitForChild("StrikeView"))
local Prices = require(ClientLib:WaitForChild("Prices"))
local LiveUI = require(ClientLib:WaitForChild("LiveUI"))

Sfx.music(Config.Music, 0.2)
Arena.init()
CatView.init(Hud.catHooks())
StrikeView.init()
Hud.init()
LiveUI.init(Config.Live)

-- Live prices (regional pricing / price tests): redraw whatever shop page is open when they arrive.
Prices.onChange(function()
	Panels.refresh()
	Hud.refresh()
end)
Prices.sync(Config.Passes, Config.Products)

-- Chat tags: [PRO] / [VIP] in front of their names.
pcall(function()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local props = Instance.new("TextChatMessageProperties")
		local src = message.TextSource
		local p = src and Players:GetPlayerByUserId(src.UserId)
		local tag = p and p:GetAttribute("Tag")
		if tag == "PRO" then
			props.PrefixText = "<font color='#FFC62C'>[👑 PRO]</font> " .. message.PrefixText
		elseif tag == "VIP" then
			props.PrefixText = "<font color='#FF92BA'>[🎖️ VIP]</font> " .. message.PrefixText
		end
		return props
	end
end)

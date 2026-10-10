-- Toy Army ⚔️ client: music, the arena (garrisons, battles, the block tower), the house cat, the HUD and menus,
-- and chat tags for VIP / Pro Commanders.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local ClientLib = ReplicatedStorage:WaitForChild("ClientLib")
local Sfx = require(ClientLib:WaitForChild("Sfx"))
local Arena = require(ClientLib:WaitForChild("Arena"))
local CatView = require(ClientLib:WaitForChild("CatView"))
local Hud = require(ClientLib:WaitForChild("Hud"))

Sfx.music(Config.Music, 0.2)
Arena.init()
CatView.init(Hud.catHooks())
Hud.init()

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

-- Per-player Roblox policy (PolicyService), looked up once on join and mirrored to player attributes so the
-- client can hide what a player may not buy:
--   RandomBlocked  = ArePaidRandomItemsRestricted: no paid random items (loot boxes) for this player, with Robux
--                    or with a currency that is sold for Robux. Games then show a fixed reward instead, or hide it.
--   TradeBlocked   = not IsPaidItemTradingAllowed.
-- Until the lookup returns (or if it fails) the player is treated as restricted: safe by default.
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local RunService = game:GetService("RunService")

local Policy = {}

local function load(player: Player)
	player:SetAttribute("RandomBlocked", true)
	player:SetAttribute("TradeBlocked", true)
	local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	if ok and type(info) == "table" then
		player:SetAttribute("RandomBlocked", info.ArePaidRandomItemsRestricted == true)
		player:SetAttribute("TradeBlocked", info.IsPaidItemTradingAllowed ~= true)
	elseif RunService:IsStudio() then
		player:SetAttribute("RandomBlocked", false) -- Studio has no policy service: test the normal path
		player:SetAttribute("TradeBlocked", false)
	end
end

function Policy.init()
	Players.PlayerAdded:Connect(load)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(load, p)
	end
end

-- True when this player may not get paid random items (from Robux or a Robux-bought currency).
function Policy.randomBlocked(player: Player): boolean
	return player:GetAttribute("RandomBlocked") ~= false
end

function Policy.tradeBlocked(player: Player): boolean
	return player:GetAttribute("TradeBlocked") ~= false
end

return Policy

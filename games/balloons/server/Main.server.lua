-- Pop All The Balloons! 🎈 — server entry point.
-- Order: remotes, lighting, world, data, shop, live features, then the game systems (balloons, MEGA BALLOON
-- event, zone bosses, pumps).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local Net = require(Shared:WaitForChild("Net"))
local Fmt = require(Shared:WaitForChild("Fmt"))
local Config = require(Shared:WaitForChild("Config"))
local Econ = require(Shared:WaitForChild("Econ"))
local Look = require(script.Parent:WaitForChild("Lib"):WaitForChild("Look"))
local Data = require(script.Parent:WaitForChild("Lib"):WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Lib"):WaitForChild("Shop"))
local Assets = require(script.Parent:WaitForChild("Lib"):WaitForChild("Assets"))
local Map = require(script.Parent:WaitForChild("Lib"):WaitForChild("Map"))
local Progress = require(script.Parent:WaitForChild("Lib"):WaitForChild("Progress"))
local Balloons = require(script.Parent:WaitForChild("Lib"):WaitForChild("Balloons"))
local Mega = require(script.Parent:WaitForChild("Lib"):WaitForChild("Mega"))
local Pump = require(script.Parent:WaitForChild("Lib"):WaitForChild("Pump"))
local Boss = require(script.Parent:WaitForChild("Lib"):WaitForChild("Boss"))
local Policy = require(script.Parent:WaitForChild("Lib"):WaitForChild("Policy"))
local Debug = require(script.Parent:WaitForChild("Lib"):WaitForChild("Debug"))
local Live = require(script.Parent:WaitForChild("Lib"):WaitForChild("Live"))

-- Create every remote up front so clients never wait on one that appears late.
for _, name in ipairs({ "Balloon", "Throw", "Ui", "Action", "Notify", "Data", "Fx", "Buy" }) do
	Net.event(name)
end
Net.fast("Dart")
Net.func("BalloonSync")

-- Bright cartoon day (preset A), lots of clouds, the house +0.06 brightness lift.
Look.apply({
	preset = "A",
	clouds = { Cover = 0.62, Density = 0.4, Color = Color3.fromRGB(255, 255, 255) },
	cc = { Brightness = 0.06, Saturation = 0.22 },
})

Map.build()

-- Hero mesh slot: when Config.Meshes.balloon has ids, round balloons use the generated mesh.
Assets.init(Config.Meshes :: any)
task.spawn(function()
	local mp = Assets.get("balloon")
	if mp then
		mp.Name = "BalloonMesh"
		mp.Parent = ReplicatedStorage
	end
end)

Data.init({
	name = Config.StoreName,
	defaults = Config.Defaults :: any,
	leaderstats = {
		{ name = "Coins", get = function(d)
			return Fmt.num(d.coins or 0)
		end },
		{ name = "Pops", get = function(d)
			return Fmt.num(d.pops or 0)
		end },
		{ name = "Rebirths", get = function(d)
			return tostring(d.rebirths or 0)
		end },
	},
})

Progress.init()

local function packGrant(key: string): (Player, { [string]: any }) -> boolean
	return function(player, d)
		local item = Config.Products[key]
		local coins = Progress.addCoins(player, d, Econ.packCoins(item.base or 1000, d))
		Progress.ui(player, "bought", key, coins)
		return true
	end
end

local function dartsGrant(key: string): (Player, { [string]: any }) -> boolean
	return function(player, d)
		local n = Config.Products[key].darts or 10
		d.megaDarts = (d.megaDarts or 0) + n
		Progress.touch(player)
		Progress.ui(player, "bought", key, n)
		return true
	end
end

local function trialGrant(key: string): (Player, { [string]: any }) -> boolean
	return function(player, d)
		local item = Config.Products[key]
		Progress.giveTrial(player, d, item.trial :: string, item.minutes or 15)
		return true
	end
end

-- Products the game grants itself (gift copies and server boosts are granted by the kit Shop).
local grants: { [string]: (Player, { [string]: any }) -> boolean } = {
	MegaDarts = dartsGrant("MegaDarts"),
	MegaDarts50 = dartsGrant("MegaDarts50"),
	LuckBoost = function(player, d)
		d.luckUntil = math.max(os.time(), tonumber(d.luckUntil) or 0) + 15 * 60
		Progress.touch(player)
		Progress.ui(player, "bought", "LuckBoost", 15)
		return true
	end,
	SummonMega = function(player, _d)
		return Mega.summon(player)
	end,
	Starter = function(player, d)
		local item = Config.Products.Starter
		local coins = Progress.addCoins(player, d, Econ.packCoins(item.base or 2000, d))
		if not d.starter then
			d.starter = true
			d.megaDarts = (d.megaDarts or 0) + (item.darts or 15)
			if Policy.randomBlocked(player) then
				d.megaDarts += 10 -- no paid luck under the paid random item rule: the fixed swap shown in the shop
			else
				d.luckUntil = math.max(os.time(), tonumber(d.luckUntil) or 0) + 30 * 60
			end
		end
		Progress.touch(player)
		Progress.ui(player, "bought", "Starter", coins)
		return true
	end,
	Intro = function(player, d)
		local item = Config.Products.Intro
		local coins = Progress.addCoins(player, d, Econ.packCoins(item.base or 3000, d))
		d.megaDarts = (d.megaDarts or 0) + (item.darts or 10)
		Progress.touch(player)
		Progress.ui(player, "bought", "Intro", coins)
		return true
	end,
}
for key, item in pairs(Config.Products) do
	if item.tab == "coins" then
		grants[key] = packGrant(key)
	elseif item.trial then
		grants[key] = trialGrant(key)
	end
end

Shop.init({
	passes = Config.Passes :: any,
	products = Config.Products :: any,
	grants = grants,
})

-- Live features: codes, group gift, playtime gifts, daily quests, badges, invites, friend bonus (Progress.income).
-- Coin rewards are pack sizes, scaled to the player's best zone and rebirths like the coin products.
Live.init({
	config = Config.Live,
	grant = function(player, d, reward, source)
		local coins = 0
		if reward.coins then
			coins = Progress.addCoins(player, d, Econ.packCoins(reward.coins, d))
		end
		if reward.megaDarts then
			d.megaDarts = (d.megaDarts or 0) + reward.megaDarts
		end
		if reward.luckMinutes then
			d.luckUntil = math.max(os.time(), tonumber(d.luckUntil) or 0) + reward.luckMinutes * 60
		end
		Progress.touch(player)
		Progress.ui(player, "gift", coins, reward.megaDarts or 0, reward.luckMinutes or 0, source)
	end,
})
-- Top of every hour: the HOURLY MEGA BALLOON and 10 minutes of 2x coins for the server.
Live.onHour(function(_hour)
	Mega.hourly()
end)

Balloons.init()
Mega.init()
Boss.init()
Pump.init()
Debug.init()

-- Darts and bumps: Mega Balloon is id 0.
Net.event("Throw").OnServerEvent:Connect(function(player, id, mega, bump)
	if type(id) ~= "number" then
		return
	end
	local d = Data.get(player)
	if not d then
		return
	end
	local isBump = bump == true
	if not Balloons.allowThrow(player, d, isBump) then
		return
	end
	if id == 0 then
		if not isBump then
			Mega.hit(player, d, mega == true)
		end
	else
		Balloons.hit(player, d, id, mega == true, isBump)
	end
end)

-- Everything else the client can ask for.
local handlers: { [string]: (Player, any) -> () } = {}
for k, f in pairs(Progress.actions) do
	handlers[k] = f
end
for k, f in pairs(Mega.actions) do
	handlers[k] = f
end
for k, f in pairs(Boss.actions) do
	handlers[k] = f
end
Net.event("Action").OnServerEvent:Connect(function(player, kind, arg)
	if type(kind) ~= "string" then
		return
	end
	local f = handlers[kind]
	if not f or not Net.allow(player, "act_" .. kind, 0.12) then
		return
	end
	f(player, arg)
end)

-- Zone gates: hold the prompt to unlock with coins.
for _, g in ipairs(Map.gates) do
	g.prompt.Triggered:Connect(function(player)
		Progress.unlockZone(player, g.zone)
	end)
end

-- The secret Balloon Factory (the ending).
local factoryPrompt = Map.factoryPrompt
if factoryPrompt then
	factoryPrompt.Triggered:Connect(function(player)
		Progress.factory(player)
	end)
end

print("[Balloons] server ready:", #Config.Order, "balloon types,", #Config.Zones, "zones, pump spots", #Config.Hub.pumpSpots, "pump module", Pump ~= nil)

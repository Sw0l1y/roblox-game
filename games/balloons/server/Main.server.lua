-- Pop All The Balloons! 🎈 — server entry point.
-- Order: remotes, lighting, world, data, shop, then the game systems (balloons, MEGA BALLOON event, pumps).
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
local Debug = require(script.Parent:WaitForChild("Lib"):WaitForChild("Debug"))

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

Shop.init({
	passes = Config.Passes :: any,
	products = Config.Products :: any,
	grants = {
		MegaDarts = function(player, d)
			d.megaDarts = (d.megaDarts or 0) + 10
			Progress.touch(player)
			Progress.ui(player, "bought", "MegaDarts", 10)
			return true
		end,
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
				d.megaDarts = (d.megaDarts or 0) + 15
				d.luckUntil = math.max(os.time(), tonumber(d.luckUntil) or 0) + 30 * 60
			end
			Progress.touch(player)
			Progress.ui(player, "bought", "Starter", coins)
			return true
		end,
		Coins1 = packGrant("Coins1"),
		Coins2 = packGrant("Coins2"),
		Coins3 = packGrant("Coins3"),
	},
})

Balloons.init()
Mega.init()
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

print("[Balloons] server ready:", #Config.Order, "balloon types,", #Config.Zones, "zones, pump spots", #Config.Hub.pumpSpots, "pump module", Pump ~= nil)

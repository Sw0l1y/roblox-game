-- Cake Off! 🎂 server entry: builds the plaza, wires save data, shop, stations, NPCs and the round loop.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Fmt = require(Shared:WaitForChild("Fmt"))
local Data = require(script.Parent:WaitForChild("Lib"):WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Lib"):WaitForChild("Shop"))
local Assets = require(script.Parent:WaitForChild("Lib"):WaitForChild("Assets"))
local Plaza = require(script.Parent:WaitForChild("Lib"):WaitForChild("Plaza"))
local Stations = require(script.Parent:WaitForChild("Lib"):WaitForChild("Stations"))
local Bots = require(script.Parent:WaitForChild("Lib"):WaitForChild("Bots"))
local Progress = require(script.Parent:WaitForChild("Lib"):WaitForChild("Progress"))
local Rounds = require(script.Parent:WaitForChild("Lib"):WaitForChild("Rounds"))
local Debug = require(script.Parent:WaitForChild("Lib"):WaitForChild("Debug"))

-- Remotes exist before any client asks for them.
local buildRemote = Net.event("Build")
local actFunc = Net.func("Act")
Net.event("Round")
Net.event("Reward")
Net.event("Announce")
Net.event("Vote")
Net.event("Fx")

local DEFAULTS = {
	coins = 0,
	totalCoins = 0,
	xp = 0,
	level = 1,
	wins = 0,
	rounds = 0,
	top3 = 0,
	bestScore = 0,
	votes = 0,
	toppings = { Sprinkles = true, Cherry = true, Candle = true, Pearls = true, Swirl = true },
	colors = { Vanilla = true },
	shapes = { Round = true, Square = true },
	tier4 = false,
	slots = 0,
	boxes = 1, -- welcome gift: the first box is guaranteed Rare or better
	firstBox = false,
	boxesOpened = 0,
	milestones = {},
	dailyStreak = 0,
	dailyLast = 0,
	luckUntil = 0,
	themeTickets = 0,
	starter = false,
	muted = false,
	tut = 0,
	offerShown = false,
}

-- Hero meshes (when generated) are copied where both server and clients can build toppings from them.
Assets.init(Config.Meshes)
local meshFolder = Instance.new("Folder")
meshFolder.Name = "CakeMeshes"
meshFolder.Parent = ReplicatedStorage
for key in pairs(Config.Meshes) do
	task.spawn(function()
		local mp = Assets.get(key)
		if mp then
			mp.Name = key
			mp.Parent = meshFolder
		end
	end)
end

local built = Plaza.build()

Data.init({
	name = Config.DataStore,
	defaults = DEFAULTS,
	leaderstats = {
		{ name = "Coins", get = function(d)
			return Fmt.num(d.coins or 0)
		end },
		{ name = "Wins", get = function(d)
			return tostring(d.wins or 0)
		end },
		{ name = "Level", get = function(d)
			return tostring(d.level or 1)
		end },
	},
})

local function grantCoins(n: number): (Player, { [string]: any }) -> boolean
	return function(player, d)
		d.coins = (d.coins or 0) + n
		d.totalCoins = (d.totalCoins or 0) + n
		Shop.notify(player, "🪙 +" .. Fmt.commas(n) .. " coins!", "gold")
		return true
	end
end
local function grantBoxes(n: number): (Player, { [string]: any }) -> boolean
	return function(player, d)
		d.boxes = (d.boxes or 0) + n
		Shop.notify(player, "🎁 +" .. n .. " Mystery Box" .. (if n > 1 then "es" else "") .. "!", "purple")
		return true
	end
end

Shop.init({
	passes = Config.Passes :: any, -- kit Catalog is the narrower { id, name, price }
	products = Config.Products :: any,
	grants = {
		Coins1 = grantCoins(1000),
		Coins2 = grantCoins(6000),
		Coins3 = grantCoins(18000),
		Box1 = grantBoxes(1),
		Box5 = grantBoxes(5),
		Starter = function(player, d)
			d.coins = (d.coins or 0) + 2000
			d.boxes = (d.boxes or 0) + 3
			d.starter = true
			Shop.notify(player, "🧁 Starter Pack: +2,000 coins, +3 boxes!", "gold")
			return true
		end,
		Luck = function(player, d)
			d.luckUntil = math.max(os.time(), d.luckUntil or 0) + Config.Box.luckSeconds
			Shop.notify(player, "🍀 Lucky Sprinkles active for 15 minutes!", "green")
			return true
		end,
		PickTheme = function(player, d)
			d.themeTickets = (d.themeTickets or 0) + 1
			Shop.notify(player, "🎡 Pick the next theme!", "pink")
			return true
		end,
	},
})

Shop.onPass(function(player, key)
	local d = Data.get(player)
	if not d then
		return
	end
	if key == "VIP" then
		player:SetAttribute("VIP", true)
		for _, t in ipairs(Config.Toppings) do
			if t.source == "vip" then
				Progress.grantTopping(player, d, t.id, true)
			end
		end
	elseif key == "GoldenOven" then
		player:SetAttribute("Golden", true)
		local st = Stations.byPlayer[player]
		if st then
			Stations.applyGolden(st, true)
		end
	end
	Progress.refreshTag(player)
	Data.dirty(player)
end)

Stations.init(built.stations)
Bots.init(built)
Progress.init()
Rounds.init(built)
Debug.init(DEFAULTS)

Data.onLoaded(function(player)
	Stations.assign(player)
end)
Players.PlayerRemoving:Connect(function(player)
	Stations.release(player)
end)

buildRemote.OnServerEvent:Connect(function(player, action, a, b, c, d, e, f)
	Stations.handle(player, action, a, b, c, d, e, f)
end)

local function act(player: Player, action: string, a: any, b: any): any
	local d = Data.get(player)
	if not d then
		return { ok = false, msg = "Still loading..." }
	end
	if action == "unlock" then
		if type(a) ~= "string" then
			return nil
		end
		return Progress.unlock(player, a, if type(b) == "string" then b else nil)
	elseif action == "box" then
		return Progress.openBox(player, a == true)
	elseif action == "daily" then
		return Progress.claimDaily(player)
	elseif action == "pickTheme" then
		if (d.themeTickets or 0) <= 0 then
			return { ok = false, msg = "Buy a theme pick first" }
		end
		if type(a) ~= "string" or not Rounds.queueTheme(a, player.DisplayName) then
			return { ok = false, msg = "Unknown theme" }
		end
		d.themeTickets -= 1
		Data.dirty(player)
		local t = Config.ThemeByKey[a]
		Shop.notifyAll("🎡 " .. player.DisplayName .. " picked an upcoming theme: " .. t.name .. " " .. t.glyph, "pink")
		return { ok = true }
	elseif action == "tp" then
		local st = Stations.byPlayer[player]
		local char = player.Character
		if st and char then
			local look = Vector3.new(st.root.Position.X, st.pad.Y + 3, st.root.Position.Z)
			char:PivotTo(CFrame.lookAt(st.pad + Vector3.new(0, 3, 0), look))
			return { ok = true }
		end
		return { ok = false }
	elseif action == "tut" then
		local n = tonumber(a)
		if n and n == n and n >= 0 and n <= 10 then
			d.tut = math.max(d.tut or 0, math.floor(n))
			Data.dirty(player)
		end
		return { ok = true }
	elseif action == "mute" then
		d.muted = a == true
		Data.dirty(player)
		return { ok = true }
	elseif action == "offerShown" then
		d.offerShown = true
		Data.dirty(player)
		return { ok = true }
	end
	return nil
end

-- known actions only: Net.allow keys on the action name, so unknown strings must not reach it
local ACTS = { unlock = true, box = true, daily = true, pickTheme = true, tp = true, tut = true, mute = true, offerShown = true }

actFunc.OnServerInvoke = function(player: Player, action: any, a: any, b: any): any
	if type(action) ~= "string" or not ACTS[action] then
		return nil
	end
	if not Net.allow(player, "act_" .. action, 0.12) then
		return { ok = false, msg = "Slow down!" }
	end
	local ok, res = pcall(act, player, action, a, b)
	if not ok then
		warn("[Act]", action, res)
		return { ok = false, msg = "Oops, try again" }
	end
	return res
end

task.spawn(Rounds.run)

-- Cake Off! 🎂 server entry: builds the plaza, wires save data, shop (passes, products, gifts, server boosts),
-- launch features (kit Live: codes, quests, playtime gifts, badges, invites, hourly gala), stations, NPCs and
-- the round loop.
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
local Live = require(script.Parent:WaitForChild("Lib"):WaitForChild("Live"))
local Boosts = require(script.Parent:WaitForChild("Lib"):WaitForChild("Boosts"))
local Policy = require(script.Parent:WaitForChild("Lib"):WaitForChild("Policy"))

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
	paidBoxes = 0, -- of `boxes`, how many were bought with Robux (never rolled for paid-random restricted players)
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
	ftueRw = {}, -- first-frosting / first-topping coins paid
	overtime = 0, -- Overtime tickets (used at the next build end)
	reacts = {}, -- reaction credits bought while no cake was on show
	candy = 0, -- Caketober candy
	track = { free = {}, premium = {} }, -- claimed Caketober tiers
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
		Shop.notify(player, "💰 +" .. Fmt.commas(n) .. " coins!", "gold")
		return true
	end
end
-- Paid boxes (counted in d.paidBoxes, see Progress.openBox).
local function grantBoxes(n: number): (Player, { [string]: any }) -> boolean
	return function(player, d)
		Progress.addPaidBoxes(d, n)
		Shop.notify(player, "🎁 +" .. n .. " Mystery Box" .. (if n > 1 then "es" else "") .. "!", "purple")
		return true
	end
end
-- Reactions: used on the cake on show now, else kept as a credit for the next one.
local function grantReact(key: string): (Player, { [string]: any }) -> boolean
	return function(player, d)
		if not Rounds.react(player, key) then
			d.reacts = d.reacts or {}
			d.reacts[key] = (d.reacts[key] or 0) + 1
			Shop.notify(player, Config.Reactions[key].glyph .. " Saved! Send it to the next cake in the judging", "pink")
		end
		return true
	end
end
-- Caketober skips: candy for n tiers (coins once the event is over).
local function grantTrack(n: number): (Player, { [string]: any }) -> boolean
	return function(player, d)
		if Progress.addCandy(player, d, n * Config.Track.cost) == 0 then
			Progress.addCoins(player, d, n * Config.Track.ownedCoins)
		end
		Shop.notify(player, "🎃 +" .. n .. " Caketober tier" .. (if n > 1 then "s" else "") .. "! Claim in 🎃", "orange")
		return true
	end
end

local grants: { [string]: (Player, { [string]: any }) -> boolean } = {
	Coins1 = grantCoins(1000),
	Coins2 = grantCoins(6000),
	Coins3 = grantCoins(18000),
	Coins4 = grantCoins(45000),
	Coins5 = grantCoins(110000),
	Coins6 = grantCoins(250000),
	Coins6Deal = grantCoins(250000),
	Box1 = grantBoxes(1),
	Box5 = grantBoxes(5),
	Box15 = grantBoxes(15),
	React1 = grantReact("React1"),
	React2 = grantReact("React2"),
	React3 = grantReact("React3"),
	Track1 = grantTrack(1),
	Track5 = grantTrack(5),
	Track10 = grantTrack(10),
	Intro = function(player, d)
		Progress.addCoins(player, d, 2000)
		local cupcake = Config.ToppingById.Cupcake
		if not Progress.grantTopping(player, d, cupcake.id) then
			Progress.addCoins(player, d, cupcake.price)
		end
		Shop.notify(player, "🍰 Baker's Treat: +2,000 coins + " .. cupcake.glyph .. " " .. cupcake.name .. "!", "gold")
		return true
	end,
	Starter = function(player, d)
		if Policy.randomBlocked(player) then -- the fixed pack shown to restricted players before they buy
			Progress.addCoins(player, d, Config.StarterBlocked.coins)
			Shop.notify(player, "🧁 Starter Pack: +" .. Fmt.commas(Config.StarterBlocked.coins) .. " coins!", "gold")
		else
			Progress.addCoins(player, d, 2000)
			Progress.addPaidBoxes(d, 3)
			Shop.notify(player, "🧁 Starter Pack: +2,000 coins, +3 boxes!", "gold")
		end
		d.starter = true
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
	Overtime = function(player, d)
		d.overtime = (d.overtime or 0) + 1
		local when = if Rounds.phase() == "Build" then "when the bell rings" else "on your next cake"
		Shop.notify(player, "⏰ Overtime ready: +" .. Config.Round.personal .. "s " .. when .. "!", "gold")
		return true
	end,
	SrvParty = function(player, _d)
		Boosts.add("coins", 2, 15 * 60, player.DisplayName)
		Boosts.add("xp", 2, 15 * 60, player.DisplayName)
		Shop.notifyAll("🎉 " .. player.DisplayName .. " started a BAKERY PARTY: 2x coins + 2x XP for EVERYONE!", "gold")
		return true
	end,
}

Shop.init({
	passes = Config.Passes :: any, -- kit Catalog is the narrower { id, name, price }
	products = Config.Products :: any,
	grants = grants,
})

Live.init({
	config = Config.Live,
	grant = function(player, d, reward, _source)
		if reward.coins then
			Progress.addCoins(player, d, reward.coins)
		end
		if reward.boxes then
			d.boxes = (d.boxes or 0) + reward.boxes -- free boxes
		end
		if reward.candy then
			Progress.addCandy(player, d, reward.candy)
		end
		Data.dirty(player)
	end,
})
Live.onHour(function(_hour: number)
	Rounds.hourly()
end)

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
	elseif key == "Caketober" and Config.trackLive() then
		local claimed = d.track and d.track.premium and d.track.premium["1"]
		if not claimed and Config.trackTier(d.candy or 0) > 0 then
			Shop.notify(player, "🎃 Caketober Pass: claim your premium rewards in 🎃!", "orange")
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

-- Every accepted decorating action: first-minute rewards and the decorating quests.
Stations.onEdit = function(player: Player, action: string, id: string?)
	if action == "frost" or action == "drip" or action == "piping" or action == "shape" or action == "tiers" then
		Progress.ftue(player, "frost") -- the first decorating tap of any kind pays (the first coins in seconds)
	elseif action == "place" and id then
		Progress.ftue(player, "topping")
		Live.quest(player, "toppings", 1)
		local theme = Config.ThemeByKey[Stations.theme]
		if theme and table.find(theme.toppings, id) then
			Live.quest(player, "theme", 1)
		end
	end
end
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
	elseif action == "track" then
		return Progress.claimTrack(player)
	elseif action == "react" then -- spend a saved reaction credit on the cake on show
		local credits = d.reacts or {}
		if type(a) ~= "string" or not Config.Reactions[a] or (credits[a] or 0) <= 0 then
			return { ok = false, msg = "No saved reactions" }
		end
		if not Rounds.react(player, a) then
			return { ok = false, msg = "Wait for a cake on the turntable!" }
		end
		credits[a] -= 1
		Data.dirty(player)
		return { ok = true }
	end
	return nil
end

-- known actions only: Net.allow keys on the action name, so unknown strings must not reach it
local ACTS = { unlock = true, box = true, daily = true, pickTheme = true, tp = true, tut = true, mute = true, offerShown = true, track = true, react = true }

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

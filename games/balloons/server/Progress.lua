-- Player progression on the server: coins, pop rewards and the Index, zone meters and zone bosses, upgrades,
-- zone unlocks and teleports, rebirth, daily gift, tool trials, the secret Balloon Factory ending, character
-- stats (walk speed, VIP tag, dart looks), zone tracking and fall recovery.
-- Every client request is validated here; the client only asks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local Fmt = require(Shared:WaitForChild("Fmt"))
local Config = require(Shared:WaitForChild("Config"))
local Econ = require(Shared:WaitForChild("Econ"))
local Data = require(script.Parent:WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local Map = require(script.Parent:WaitForChild("Map"))
local Live = require(script.Parent:WaitForChild("Live"))
local Boosts = require(script.Parent:WaitForChild("Boosts"))
local Policy = require(script.Parent:WaitForChild("Policy"))

local Progress = {}
Progress.actions = {} :: { [string]: (Player, any) -> () }

type PData = { [string]: any }

local uiRemote = Net.event("Ui")
local pending: { [Player]: boolean } = {}
local joinedAt: { [Player]: number } = {}
local zoneOf: { [Player]: number } = {}
local lastWarn: { [Player]: number } = {}

---------------------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------------------

function Progress.ui(player: Player, kind: string, ...: any)
	if player.Parent then
		uiRemote:FireClient(player, kind, ...)
	end
end

function Progress.uiAll(kind: string, ...: any)
	uiRemote:FireAllClients(kind, ...)
end

-- Throttled Data.dirty: the client copy refreshes at most 5 times a second per player.
function Progress.touch(player: Player)
	pending[player] = true
end

function Progress.root(player: Player): BasePart?
	local c = player.Character
	if not c then
		return nil
	end
	local h = c:FindFirstChild("HumanoidRootPart")
	if h and h:IsA("BasePart") then
		return h :: BasePart
	end
	return nil
end

function Progress.sessionTime(player: Player): number
	local t = joinedAt[player]
	return t and (os.clock() - t) or 0
end

function Progress.zoneOf(player: Player): number
	return zoneOf[player] or 0
end

-- Income multiplier on top of the save's own (Econ.coinMult): server coin boost x friends in the server.
function Progress.income(player: Player): number
	return Boosts.mult("coins") * Live.friendMult(player)
end

-- Spawn luck near this player (paid luck is off for players under the paid random item restriction).
function Progress.luck(player: Player, d: PData?): number
	return Econ.luck(d, os.time(), Policy.randomBlocked(player))
end

function Progress.addCoins(player: Player, d: PData, n: number): number
	n = math.max(0, math.floor(n))
	d.coins = (d.coins or 0) + n
	d.total = (d.total or 0) + n
	Progress.touch(player)
	return n
end

-- Character stats and public attributes (other clients read VIP / Golden for dart colours and chat tags).
function Progress.applyStats(player: Player)
	local d = Data.get(player)
	if not d then
		return
	end
	local vip = Econ.has(d, "VIP")
	player:SetAttribute("VIP", vip)
	player:SetAttribute("Golden", Econ.perk(d, "GoldenDart"))
	player:SetAttribute("Pumpkin", Econ.has(d, "Pumpkin"))
	local c = player.Character
	if not c then
		return
	end
	local hum = c:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = Econ.walk(d)
	end
	local head = c:FindFirstChild("Head")
	if vip and head and not head:FindFirstChild("VipTag") then
		local bb = Instance.new("BillboardGui")
		bb.Name = "VipTag"
		bb.Size = UDim2.fromOffset(110, 30)
		bb.StudsOffset = Vector3.new(0, 2.6, 0)
		bb.AlwaysOnTop = false
		bb.MaxDistance = 80
		bb.LightInfluence = 0
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Font = Enum.Font.LuckiestGuy
		l.TextScaled = true
		l.Text = "👑 VIP"
		l.TextColor3 = Color3.fromRGB(255, 215, 60)
		local s = Instance.new("UIStroke")
		s.Thickness = 2.5
		s.Color = Color3.fromRGB(60, 40, 10)
		s.Parent = l
		l.Parent = bb
		bb.Parent = head
	end
end

function Progress.teleport(player: Player, zone: number)
	local c = player.Character
	if c and Progress.root(player) then
		c:PivotTo(Map.zoneSpawn(zone))
	end
end

---------------------------------------------------------------------------------------------------------------
-- Pop rewards and the Index
---------------------------------------------------------------------------------------------------------------

export type RewardOpts = { id: number, pos: Vector3, share: number, shower: boolean?, aura: boolean?, owner: Player? }

-- A zone boss went down: its summoner clears the zone (the next zone opens for free the first time).
function Progress.bossDown(player: Player, d: PData, zone: number)
	d.meter = d.meter or { 0, 0, 0, 0 }
	d.bosses = d.bosses or { 0, 0, 0, 0 }
	d.meter[zone] = 0
	d.bosses[zone] = (tonumber(d.bosses[zone]) or 0) + 1
	d.megaDarts = (d.megaDarts or 0) + Config.Boss.darts
	local unlocked = 0
	if (d.zones or 1) == zone and zone < #Config.Zones then
		d.zones = zone + 1
		unlocked = zone + 1
	end
	Live.badge(player, "ZoneBoss")
	Progress.touch(player)
	Progress.ui(player, "bossDown", zone, unlocked, Config.Boss.darts, d.bosses[zone])
	local z = Config.Zones[zone]
	local extra = unlocked > 0 and (" " .. Config.Zones[unlocked].glyph .. " " .. Config.Zones[unlocked].name .. " is open!") or ""
	Shop.notifyAll(Config.Icons.boss .. " " .. player.DisplayName .. " beat the " .. z.name .. " BOSS!" .. extra, "pink")
end

function Progress.reward(player: Player, key: string, o: RewardOpts)
	local d = Data.get(player)
	local def = Config.Balloons[key]
	if not d or not def then
		return
	end
	local coins = math.max(1, math.floor(Econ.popValue(key, d, o.shower) * o.share * Progress.income(player)))
	if def.boss then
		Progress.addCoins(player, d, coins)
		Progress.ui(player, "reward", o.id, key, coins, o.pos, false, o.share < 1, false)
		if player == o.owner then
			Progress.bossDown(player, d, def.zone)
		end
		return
	end
	d.index = d.index or {}
	local wasComplete = Econ.zoneComplete(d, def.zone)
	local first = (d.index[key] or 0) == 0
	d.index[key] = (d.index[key] or 0) + 1
	d.pops = (d.pops or 0) + 1
	Progress.addCoins(player, d, coins)
	local ti = Tiers.index[def.tier] or 1
	if ti >= 3 then
		d.ftue = d.ftue or {}
		d.ftue.rare = true
	end
	Progress.ui(player, "reward", o.id, key, coins, o.pos, first, o.share < 1, o.aura == true)
	if o.share >= 1 then
		Live.quest(player, "pop", 1)
		if ti >= 3 then
			Live.quest(player, "rare", 1)
			Live.badge(player, "FirstRare")
		end
		if def.tier == "Secret" then
			Live.badge(player, "Secret")
		end
		-- the zone's "popped %" meter toward its boss (the zone's own balloons, not MEGA bonus ones)
		local goal = Config.Boss.goal[def.zone]
		if goal and not o.shower then
			d.meter = d.meter or { 0, 0, 0, 0 }
			local n = tonumber(d.meter[def.zone]) or 0
			if n < goal then
				d.meter[def.zone] = n + 1
				if n + 1 >= goal then
					Progress.ui(player, "meterFull", def.zone)
				end
			end
		end
	end

	if first and not wasComplete and Econ.zoneComplete(d, def.zone) then
		local z = Config.Zones[def.zone]
		local bonus = Progress.addCoins(player, d, (Config.Index.setReward[def.zone] or 500) * z.valueMult * Econ.coinMult(d))
		Progress.ui(player, "set", def.zone, bonus)
		Shop.notifyAll("📖 " .. player.DisplayName .. " completed the " .. z.name .. " Index!", "purple")
	end
	if ti >= 6 and o.share >= 1 then -- only the popper, not once per helper
		local t = Tiers.get(def.tier)
		Progress.uiAll("announce", player.DisplayName .. " popped a " .. t.name .. " " .. def.name .. "!", def.tier)
	end
end

---------------------------------------------------------------------------------------------------------------
-- Actions (client requests)
---------------------------------------------------------------------------------------------------------------

local function need(player: Player, d: PData, cost: number)
	Progress.ui(player, "need", cost - (d.coins or 0))
end

Progress.actions.upgrade = function(player: Player, key: any)
	if type(key) ~= "string" then
		return
	end
	local u = Config.Upgrades[key]
	local d = Data.get(player)
	if not u or not d then
		return
	end
	if key == "luck" and Policy.randomBlocked(player) then
		Shop.notify(player, u.name .. " isn't available in your region.", "orange")
		return
	end
	local lvl = Econ.level(d, key)
	if lvl >= u.max then
		Shop.notify(player, u.name .. " is maxed!", "green")
		return
	end
	local cost = Econ.upgradeCost(key, lvl)
	if (d.coins or 0) < cost then
		need(player, d, cost)
		return
	end
	d.coins -= cost
	d.up[key] = lvl + 1
	d.ftue = d.ftue or {}
	d.ftue.upgrade = true
	Progress.touch(player)
	Progress.applyStats(player)
	Progress.ui(player, "upgraded", key, lvl + 1)
	Live.quest(player, "upgrade", 1)
end

function Progress.unlockZone(player: Player, zone: number)
	local d = Data.get(player)
	if not d then
		return
	end
	zone = math.floor(zone)
	local cur = d.zones or 1
	if zone ~= zone or zone < 1 or zone > #Config.Zones then
		return
	end
	if zone <= cur then
		Shop.notify(player, "Already unlocked! Use 🗺️ Zones to teleport.", "green")
		return
	end
	if zone ~= cur + 1 then
		Shop.notify(player, "Unlock " .. Config.Zones[cur + 1].name .. " first!", "orange")
		return
	end
	local z = Config.Zones[zone]
	if (d.coins or 0) < z.cost then
		need(player, d, z.cost)
		return
	end
	d.coins -= z.cost
	d.zones = zone
	Progress.touch(player)
	Progress.ui(player, "zone", zone)
	Shop.notifyAll(z.glyph .. " " .. player.DisplayName .. " unlocked " .. z.name .. "!", "pink")
end

Progress.actions.unlock = function(player: Player, zone: any)
	if type(zone) == "number" then
		Progress.unlockZone(player, zone)
	end
end

Progress.actions.teleport = function(player: Player, zone: any)
	local d = Data.get(player)
	if not d or type(zone) ~= "number" then
		return
	end
	zone = math.floor(zone)
	if zone ~= zone or zone < 1 or zone > (d.zones or 1) then
		return
	end
	Progress.teleport(player, zone)
	Progress.ui(player, "teleported", zone)
end

Progress.actions.rebirth = function(player: Player)
	local d = Data.get(player)
	if not d then
		return
	end
	local cost = Econ.rebirthCost(d.rebirths or 0)
	if (d.coins or 0) < cost then
		need(player, d, cost)
		return
	end
	d.coins = 0
	d.rebirths = (d.rebirths or 0) + 1
	Progress.touch(player)
	Progress.ui(player, "rebirth", d.rebirths)
	Live.badge(player, "Rebirth")
	Shop.notifyAll("🔄 " .. player.DisplayName .. " rebirthed! Now x" .. string.format("%.1f", Econ.rebirthMult(d.rebirths)) .. " coins", "orange")
end

Progress.actions.daily = function(player: Player)
	local d = Data.get(player)
	if not d then
		return
	end
	local now = os.time()
	d.daily = d.daily or { last = 0, streak = 0 }
	local last = tonumber(d.daily.last) or 0
	if now - last < Config.Daily.cooldown then
		Shop.notify(player, "Next gift in " .. Fmt.time(Config.Daily.cooldown - (now - last)), "orange")
		return
	end
	local streak = (now - last > Config.Daily.resetAfter) and 1 or ((tonumber(d.daily.streak) or 0) % #Config.Daily.rewards + 1)
	d.daily.streak = streak
	d.daily.last = now
	local r = Config.Daily.rewards[streak]
	local coins = Progress.addCoins(player, d, Econ.dailyCoins(streak, d))
	if r.megaDarts then
		d.megaDarts = (d.megaDarts or 0) + r.megaDarts
	end
	if r.luckMinutes then
		d.luckUntil = math.max(now, tonumber(d.luckUntil) or 0) + r.luckMinutes * 60
	end
	Progress.touch(player)
	Progress.ui(player, "daily", streak, coins, r.megaDarts or 0, r.luckMinutes or 0)
end

-- Tool trial product: lend a pass's effect for some minutes (stacks).
function Progress.giveTrial(player: Player, d: PData, pass: string, minutes: number)
	d.trial = d.trial or {}
	local now = os.time()
	d.trial[pass] = math.max(now, tonumber(d.trial[pass]) or 0) + minutes * 60
	Progress.applyStats(player)
	Progress.touch(player)
	Progress.ui(player, "trial", pass, minutes)
end

-- The secret ending: the hidden Balloon Factory behind Space Rainbow shuts down once every zone boss is beaten.
function Progress.factory(player: Player)
	local d = Data.get(player)
	if not d then
		return
	end
	if d.factory then
		Shop.notify(player, Config.Icons.factory .. " You already shut down the Balloon Factory. The town is safe!", "green")
		return
	end
	local beaten = Econ.bossCount(d)
	if beaten < #Config.Zones then
		Shop.notify(player, Config.Icons.factory .. " The machines are too strong... Beat the BOSS of every zone first! (" .. beaten .. "/" .. #Config.Zones .. ")", "orange")
		return
	end
	d.factory = true
	local coins = Progress.addCoins(player, d, Econ.packCoins(Config.Factory.coins, d))
	d.megaDarts = (d.megaDarts or 0) + Config.Factory.darts
	Live.badge(player, "Factory")
	Progress.touch(player)
	Progress.ui(player, "factory", coins, Config.Factory.darts)
	Shop.notifyAll(Config.Icons.factory .. " " .. player.DisplayName .. " found the secret Balloon Factory and shut it down!", "gold")
end

---------------------------------------------------------------------------------------------------------------
-- Loops and lifecycle
---------------------------------------------------------------------------------------------------------------

local function onCharacter(player: Player, char: Model)
	task.defer(function()
		local hum = char:WaitForChild("Humanoid", 10)
		if hum and player.Parent then
			Progress.applyStats(player)
		end
	end)
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function(c)
		onCharacter(player, c)
	end)
	if player.Character then
		onCharacter(player, player.Character)
	end
end

-- Zone tracking, locked-zone guard and fall recovery (2x a second).
local function zoneStep()
	for _, p in ipairs(Players:GetPlayers()) do
		local d = Data.get(p)
		local hrp = Progress.root(p)
		if d and hrp then
			local pos = hrp.Position
			local zi = Econ.zoneAt(pos)
			zoneOf[p] = zi
			local best = d.zones or 1
			local nz = Econ.nearestZone(pos)
			if pos.Y < Config.Zones[nz].groundY - 45 then
				Progress.teleport(p, math.min(nz, best))
				Progress.ui(p, "fell")
			elseif zi > best then
				Progress.teleport(p, best)
				local now = os.clock()
				if now - (lastWarn[p] or 0) > 3 then
					lastWarn[p] = now
					Shop.notify(p, "🔒 Unlock " .. Config.Zones[best + 1].name .. " first!", "orange")
				end
			end
		end
	end
end

function Progress.init()
	Players.PlayerAdded:Connect(watch)
	for _, p in ipairs(Players:GetPlayers()) do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		pending[p] = nil
		joinedAt[p] = nil
		zoneOf[p] = nil
		lastWarn[p] = nil
	end)
	Data.onLoaded(function(player, d)
		joinedAt[player] = os.clock()
		-- old saves: make sure nested tables exist
		d.up = d.up or {}
		d.index = d.index or {}
		d.ftue = d.ftue or {}
		-- Roblox Premium perk: +10% coins (Econ.coinMult)
		local ok, premium = pcall(function()
			return player.MembershipType == Enum.MembershipType.Premium
		end)
		d.premium = ok and premium == true
		Progress.applyStats(player)
	end)
	Data.onLeaving(function(_player, d)
		d.lastSeen = os.time()
	end)
	Shop.onPass(function(player, key)
		Progress.applyStats(player)
		Progress.touch(player)
		-- Shop also runs this on join for passes already owned: only celebrate real purchases
		if Progress.sessionTime(player) > 3 then
			Progress.ui(player, "pass", key)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.2)
			for p in pairs(pending) do
				pending[p] = nil
				if p.Parent then
					Data.dirty(p)
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local ok, err = pcall(zoneStep)
			if not ok then
				warn("[Progress] zone step", err)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			for p, d in pairs(Data.all()) do
				if p.Parent then
					d.playTime = (d.playTime or 0) + 1
					-- tool trials that just ran out
					local t = d.trial
					if type(t) == "table" then
						for pass, ends in pairs(t) do
							if type(ends) ~= "number" or ends <= now then
								t[pass] = nil
								Progress.applyStats(p)
								Progress.touch(p)
								Progress.ui(p, "trialEnd", pass)
							end
						end
					end
				end
			end
		end
	end)
end

return Progress

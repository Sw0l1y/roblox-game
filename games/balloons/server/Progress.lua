-- Player progression on the server: coins, pop rewards and the Index, upgrades, zone unlocks and teleports,
-- rebirth, daily gift, character stats (walk speed, VIP tag), zone tracking and fall recovery.
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
	player:SetAttribute("Golden", Econ.has(d, "GoldenDart"))
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

export type RewardOpts = { id: number, pos: Vector3, share: number, shower: boolean?, aura: boolean? }

function Progress.reward(player: Player, key: string, o: RewardOpts)
	local d = Data.get(player)
	local def = Config.Balloons[key]
	if not d or not def then
		return
	end
	local coins = math.max(1, math.floor(Econ.popValue(key, d, o.shower) * o.share))
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

	if first and not wasComplete and Econ.zoneComplete(d, def.zone) then
		local z = Config.Zones[def.zone]
		local bonus = Progress.addCoins(player, d, (Config.Index.setReward[def.zone] or 500) * z.valueMult * Econ.coinMult(d))
		Progress.ui(player, "set", def.zone, bonus)
		Shop.notifyAll("📖 " .. player.DisplayName .. " completed the " .. z.name .. " Index!", "purple")
	end
	if ti >= 6 then
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
	if zone < 1 or zone > (d.zones or 1) then
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
			for p, d in pairs(Data.all()) do
				if p.Parent then
					d.playTime = (d.playTime or 0) + 1
				end
			end
		end
	end)
end

return Progress

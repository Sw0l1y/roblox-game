-- Economy and progression: coins, XP and baker levels, coin unlocks, the Mystery Sprinkle Box (numeric odds),
-- the Topping Index with milestone rewards, the daily reward, and the overhead baker tag.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local Net = require(Shared:WaitForChild("Net"))
local Data = require(script.Parent:WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Shop"))

local Progress = {}

local announce = Net.event("Announce")
local rewardRemote = Net.event("Reward")
local rng = Random.new()

type D = { [string]: any }
export type Result = { ok: boolean, msg: string?, id: string?, tier: string?, dup: boolean?, refund: number?, coins: number?, boxes: number?, day: number? }

function Progress.coinMult(player: Player): number
	local m = 1
	if Shop.owns(player, "DoubleCoins") then
		m *= 2
	end
	if Shop.owns(player, "VIP") then
		m *= Config.Rewards.vipMult
	end
	return m
end

function Progress.xpMult(player: Player): number
	return if Shop.owns(player, "GoldenOven") then Config.Rewards.goldenXp else 1
end

function Progress.addCoins(player: Player, d: D, n: number)
	n = math.floor(n)
	d.coins = (d.coins or 0) + n
	if n > 0 then
		d.totalCoins = (d.totalCoins or 0) + n
	end
	Data.dirty(player)
end

-- Overhead tag: "Lv 5 · Junior Baker" with VIP / Golden Oven marks.
function Progress.refreshTag(player: Player)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	local d = Data.get(player)
	if not head or not d then
		return
	end
	local bb = head:FindFirstChild("BakerTag") :: BillboardGui?
	local label: TextLabel
	if not bb then
		local nb = Instance.new("BillboardGui")
		nb.Name = "BakerTag"
		nb.Size = UDim2.fromScale(7, 1.1)
		nb.StudsOffset = Vector3.new(0, 2.7, 0)
		nb.MaxDistance = 70
		nb.LightInfluence = 0
		nb.Adornee = head :: any
		local l = Instance.new("TextLabel")
		l.Name = "Text"
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Font = Enum.Font.LuckiestGuy
		l.TextScaled = true
		local s = Instance.new("UIStroke")
		s.Thickness = 2.5
		s.Color = Config.Palette.ink
		s.Parent = l
		l.Parent = nb
		nb.Parent = head
		bb = nb
		label = l
	else
		label = (bb :: any):FindFirstChild("Text")
	end
	if not label then
		return
	end
	local prefix = ""
	if Shop.owns(player, "GoldenOven") then
		prefix ..= "🏆 "
	end
	if Shop.owns(player, "VIP") then
		prefix ..= "👑 "
	end
	label.Text = prefix .. "Lv " .. tostring(d.level) .. " · " .. Config.title(d.level)
	label.TextColor3 = if Shop.owns(player, "GoldenOven") then Config.Palette.gold else Color3.fromRGB(255, 200, 225)
end

-- Returns the number of levels gained.
function Progress.addXP(player: Player, d: D, n: number): number
	d.xp = (d.xp or 0) + math.floor(n)
	local gained = 0
	while d.xp >= Config.xpFor(d.level) do
		d.xp -= Config.xpFor(d.level)
		d.level += 1
		gained += 1
	end
	if gained > 0 then
		Progress.refreshTag(player)
		rewardRemote:FireClient(player, { kind = "level", level = d.level, title = Config.title(d.level) })
	end
	Data.dirty(player)
	return gained
end

-- Index ------------------------------------------------------------------------------------------------
function Progress.indexCount(player: Player, d: D): number
	local n = 0
	for _, t in ipairs(Config.Toppings) do
		if t.source == "free" or (d.toppings and d.toppings[t.id]) or (t.source == "vip" and Shop.owns(player, "VIP")) then
			n += 1
		end
	end
	return n
end

-- Adds a topping to the collection; returns true when it is new.
function Progress.grantTopping(player: Player, d: D, id: string, quiet: boolean?): boolean
	d.toppings = d.toppings or {}
	if d.toppings[id] then
		return false
	end
	d.toppings[id] = true
	if not quiet then
		Progress.addXP(player, d, Config.Rewards.newTopping)
	end
	d.milestones = d.milestones or {}
	local count = Progress.indexCount(player, d)
	for _, m in ipairs(Config.Rewards.indexMilestones) do
		local key = "m" .. m
		if count >= m and not d.milestones[key] then
			d.milestones[key] = true
			d.boxes = (d.boxes or 0) + 1
			Shop.notify(player, "📖 Index " .. m .. " toppings! +1 Mystery Box", "purple")
		end
	end
	Data.dirty(player)
	return true
end

-- Coin unlocks -----------------------------------------------------------------------------------------
function Progress.unlock(player: Player, kind: string, key: string?): Result
	local d = Data.get(player)
	if not d then
		return { ok = false, msg = "Still loading..." }
	end
	local price, name = 0, ""
	if kind == "topping" and key then
		local def = Config.ToppingById[key]
		if not def or def.source ~= "shop" then
			return { ok = false, msg = "Not for sale" }
		end
		if d.toppings[key] then
			return { ok = false, msg = "Already yours!" }
		end
		price, name = def.price, def.name
	elseif kind == "color" and key then
		local def = Config.ColorByKey[key]
		if not def or def.pass or def.price <= 0 then
			return { ok = false, msg = "Not for sale" }
		end
		if d.colors[key] then
			return { ok = false, msg = "Already yours!" }
		end
		price, name = def.price, def.name .. " frosting"
	elseif kind == "shape" and key then
		local def = Config.ShapeByKey[key]
		if not def or def.price <= 0 then
			return { ok = false, msg = "Not for sale" }
		end
		if d.shapes[key] then
			return { ok = false, msg = "Already yours!" }
		end
		price, name = def.price, def.name .. " cakes"
	elseif kind == "tier4" then
		if d.tier4 then
			return { ok = false, msg = "Already yours!" }
		end
		price, name = Config.Cake.tier4Price, "4-tier cakes"
	elseif kind == "slots" then
		local lvl = d.slots or 0
		if lvl >= #Config.Cake.slotUpgrades then
			return { ok = false, msg = "Maxed out!" }
		end
		price, name = Config.Cake.slotUpgrades[lvl + 1], "+" .. Config.Cake.slotStep .. " topping slots"
	else
		return { ok = false, msg = "?" }
	end
	if (d.coins or 0) < price then
		return { ok = false, msg = "Need " .. tostring(price - d.coins) .. " more coins" }
	end
	d.coins -= price
	if kind == "topping" and key then
		Progress.grantTopping(player, d, key)
	elseif kind == "color" and key then
		d.colors[key] = true
	elseif kind == "shape" and key then
		d.shapes[key] = true
	elseif kind == "tier4" then
		d.tier4 = true
	elseif kind == "slots" then
		d.slots = (d.slots or 0) + 1
	end
	Data.dirty(player)
	return { ok = true, msg = "Unlocked " .. name .. "!" }
end

-- Mystery Sprinkle Box ---------------------------------------------------------------------------------
function Progress.openBox(player: Player, useCoins: boolean): Result
	local d = Data.get(player)
	if not d then
		return { ok = false, msg = "Still loading..." }
	end
	if (d.boxes or 0) > 0 then
		d.boxes -= 1
	elseif useCoins and (d.coins or 0) >= Config.Box.price then
		d.coins -= Config.Box.price
	else
		return { ok = false, msg = "Need " .. Config.Box.price .. " coins or a box" }
	end
	local luck = if (d.luckUntil or 0) > os.time() then Config.Box.luck else 1
	local tierKey: string
	if not d.firstBox then
		tierKey = Config.Box.firstTier
		d.firstBox = true
	else
		tierKey = Tiers.roll(Config.Box.odds, rng, luck).key
	end
	local pool = Config.BoxPool[tierKey] or Config.BoxPool.Uncommon
	local id = pool[rng:NextInteger(1, #pool)]
	if d.toppings[id] then -- one free re-roll inside the tier to soften duplicates
		id = pool[rng:NextInteger(1, #pool)]
	end
	local def = Config.ToppingById[id]
	local dup = d.toppings[id] == true
	local refund = 0
	if dup then
		refund = Config.Box.refund[def.tier] or 20
		Progress.addCoins(player, d, refund)
	else
		Progress.grantTopping(player, d, id)
	end
	d.boxesOpened = (d.boxesOpened or 0) + 1
	Data.dirty(player)
	if (Tiers.index[def.tier] or 1) >= 5 then
		local t = Tiers.get(def.tier)
		announce:FireAllClients(string.format("🎁 %s unboxed a %s %s %s!", player.DisplayName, string.upper(t.name), def.name, def.glyph), "gold", false)
	end
	return { ok = true, id = id, tier = def.tier, dup = dup, refund = refund }
end

-- Daily reward -----------------------------------------------------------------------------------------
function Progress.dailyState(d: D): (boolean, number, number)
	local now = os.time()
	local last = d.dailyLast or 0
	local streak = d.dailyStreak or 0
	if now - last > Config.DailyReset then
		streak = 0
	end
	local can = now - last >= Config.DailyCooldown
	return can, streak % #Config.Daily + 1, math.max(0, Config.DailyCooldown - (now - last))
end

function Progress.claimDaily(player: Player): Result
	local d = Data.get(player)
	if not d then
		return { ok = false, msg = "Still loading..." }
	end
	local can, day = Progress.dailyState(d)
	if not can then
		return { ok = false, msg = "Come back later!" }
	end
	local coins = Config.Daily[day]
	Progress.addCoins(player, d, coins)
	local boxes = 0
	if day == #Config.Daily then
		boxes = 1
		d.boxes = (d.boxes or 0) + 1
	end
	if os.time() - (d.dailyLast or 0) > Config.DailyReset then
		d.dailyStreak = 0
	end
	d.dailyStreak = (d.dailyStreak or 0) + 1
	d.dailyLast = os.time()
	Data.dirty(player)
	return { ok = true, coins = coins, boxes = boxes, day = day }
end

function Progress.init()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			Progress.refreshTag(player)
		end)
		if player.Character then
			task.spawn(Progress.refreshTag, player)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
	Data.onLoaded(function(player)
		Progress.refreshTag(player)
	end)
end

return Progress

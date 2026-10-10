-- NPC bakers (fill low player counts so solo servers still compete), their live decorating, the judges at
-- the judges' table, the Celebrity Judge, and pretty display cakes on unused stations.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CakeBuilder = require(Shared:WaitForChild("CakeBuilder"))
local Stations = require(script.Parent:WaitForChild("Stations"))
local Npc = require(script.Parent:WaitForChild("Npc"))
local Plaza = require(script.Parent:WaitForChild("Plaza"))

type Station = Stations.Station
type Item = { id: string, mode: string, k: number, n: number, s: number, tint: string, rot: number }
type Plan = { shape: string, tiers: { string }, drip: string, piping: string, items: { Item } }

local Bots = {}
Bots.judgeModels = {} :: { Model }
Bots.celebModel = nil :: Model?

local rng = Random.new()
local judgesFolder: Folder? = nil
local usedNames: { [string]: boolean } = {}

local V = Vector3.new
local CF = CFrame.new

local COMMON_COLORS = { "Vanilla", "Pink", "Mint", "Sky", "Chocolate", "Lemon", "White", "Lavender", "Peach", "Bubblegum", "Cherry", "Caramel" }

local function pick<T>(list: { T }, r: Random): T
	return list[r:NextInteger(1, #list)]
end

-- Random topping weighted toward common tiers (ignores box/VIP-only items except via themes).
local function randomTopping(r: Random): string
	local pool: { { key: string, weight: number } } = {}
	for _, t in ipairs(Config.Toppings) do
		if t.source ~= "box" and t.source ~= "vip" then
			local w = ({ Common = 6, Uncommon = 4, Rare = 3, Epic = 1.5, Legendary = 0.6 })[t.tier] or 0
			if w > 0 then
				table.insert(pool, { key = t.id, weight = w })
			end
		end
	end
	local total = 0
	for _, e in ipairs(pool) do
		total += e.weight
	end
	local x = r:NextNumber() * total
	for _, e in ipairs(pool) do
		x -= e.weight
		if x <= 0 then
			return e.key
		end
	end
	return "Cherry"
end

-- A decorating plan for a theme and skill (0..1).
function Bots.plan(themeKey: string, skill: number, r: Random, maxToppings: number?): Plan
	local theme = Config.ThemeByKey[themeKey] or Config.Themes[1]
	local adherence = 0.3 + 0.6 * skill
	local nTiers = math.clamp(math.floor(1.6 + skill * 2.2 + r:NextNumber(-0.6, 0.6)), 1, 4)
	local shape = if r:NextNumber() < adherence * 0.6 then pick(theme.shapes, r) else pick(Config.Shapes, r).key
	local tiers = {}
	local themeCol = pick(theme.colors, r)
	for i = 1, nTiers do
		if r:NextNumber() < adherence then
			tiers[i] = if r:NextNumber() < 0.5 then themeCol else pick(theme.colors, r)
		else
			tiers[i] = pick(COMMON_COLORS, r)
		end
	end
	local drip = "None"
	if r:NextNumber() < 0.35 + skill * 0.4 then
		drip = if r:NextNumber() < adherence then pick(theme.colors, r) else pick({ "Chocolate", "White", "Caramel", "Pink" }, r)
	end
	local piping = if r:NextNumber() < 0.3 then pick(theme.colors, r) else "Auto"

	local items: { Item } = {}
	local total = math.clamp(math.floor(5 + skill * 16 + r:NextNumber(-2, 3)), 4, maxToppings or 26)
	local function choose(): string
		if r:NextNumber() < adherence then
			return pick(theme.toppings, r)
		end
		return randomTopping(r)
	end
	local function tintFor(): string
		return if r:NextNumber() < 0.3 then pick(theme.colors, r) else "Auto"
	end
	local function size(): number
		local x = r:NextNumber()
		return if x < 0.7 then 1 elseif x < 0.85 then 0.7 else 1.4
	end
	-- centrepiece on the top tier
	if r:NextNumber() < 0.65 then
		local tops: { string } = {}
		for _, id in ipairs(theme.toppings) do
			local def = Config.ToppingById[id]
			if def and def.topOnly then
				table.insert(tops, id)
			end
		end
		local id = if #tops > 0 and r:NextNumber() < adherence then pick(tops, r) else pick({ "Cherry", "Swirl", "Star", "Strawberry", "Cupcake" }, r)
		table.insert(items, { id = id, mode = "center", k = 0, n = 0, s = 1.3, tint = tintFor(), rot = 0 })
	end
	-- a neat ring around the top tier
	if r:NextNumber() < 0.55 + skill * 0.3 then
		local id = choose()
		local n = r:NextInteger(5, 8)
		local tint = tintFor()
		for k = 1, n do
			table.insert(items, { id = id, mode = "ring", k = k, n = n, s = 0.8, tint = tint, rot = 0 })
		end
	end
	-- a ring around the bottom tier's top edge when there is room
	if nTiers >= 2 and r:NextNumber() < 0.4 + skill * 0.3 then
		local id = choose()
		local n = r:NextInteger(6, 10)
		for k = 1, n do
			table.insert(items, { id = id, mode = "ring1", k = k, n = n, s = 0.9, tint = "Auto", rot = k })
		end
	end
	while #items < total do
		local id = choose()
		local def = Config.ToppingById[id]
		local mode = if (def and def.topOnly) or r:NextNumber() < 0.65 then "top" else "side"
		table.insert(items, { id = id, mode = mode, k = 0, n = 0, s = size(), tint = tintFor(), rot = r:NextInteger(0, 7) })
	end
	while #items > (maxToppings or 30) do
		table.remove(items, #items)
	end
	return { shape = shape, tiers = tiers, drip = drip, piping = piping, items = items }
end

-- Find a surface point for one plan item by raycasting the live cake body.
local function surfacePoint(st: Station, item: Item, r: Random): (Vector3?, Vector3?)
	local dims = CakeBuilder.dims(#st.cake.tiers)
	local topD = dims[#dims]
	local H = topD.y0 + topD.h
	local params = Stations.bodyParams(st)
	local root = st.root
	local down = -root.UpVector
	local function rayDown(x: number, z: number): (Vector3?, Vector3?)
		local o = (root * CF(x, H + 4, z)).Position
		local hit = workspace:Raycast(o, down * 20, params)
		if hit and hit.Normal:Dot(root.UpVector) > 0.7 then
			return hit.Position, hit.Normal
		end
		return nil, nil
	end
	if item.mode == "center" then
		return rayDown(0, 0)
	elseif item.mode == "ring" then
		local a = item.k / item.n * math.pi * 2
		local rr = topD.r * 0.62
		return rayDown(math.cos(a) * rr, math.sin(a) * rr)
	elseif item.mode == "ring1" then
		local a = (item.k + 0.5) / item.n * math.pi * 2
		local rr = (dims[1].r + dims[2].r) / 2 + 0.1
		return rayDown(math.cos(a) * rr, math.sin(a) * rr)
	elseif item.mode == "top" then
		for _ = 1, 6 do
			local t = r:NextInteger(1, #dims)
			local inner = if t < #dims then dims[t + 1].r + 0.5 else 0
			local outer = dims[t].r * 0.85
			if outer > inner then
				local a = r:NextNumber() * math.pi * 2
				local rr = r:NextNumber(inner, outer)
				local p, n = rayDown(math.cos(a) * rr, math.sin(a) * rr)
				if p then
					return p, n
				end
			end
		end
		return nil, nil
	else
		local t = r:NextInteger(1, #dims)
		local y = dims[t].y0 + dims[t].h * r:NextNumber(0.3, 0.75)
		local a = r:NextNumber() * math.pi * 2
		local o = (root * CF(math.cos(a) * (dims[t].r + 4), y, math.sin(a) * (dims[t].r + 4))).Position
		local dir = root:VectorToWorldSpace(V(-math.cos(a), 0, -math.sin(a))) * 8
		local hit = workspace:Raycast(o, dir, params)
		if hit then
			return hit.Position, hit.Normal
		end
		return nil, nil
	end
end

local function placeItem(st: Station, item: Item, r: Random): boolean
	local p, n = surfacePoint(st, item, r)
	if p and n then
		local ok = Stations.place(st, item.id, p, n, item.rot, item.s, item.tint)
		return ok
	end
	return false
end

local function applyBase(st: Station, plan: Plan)
	st.cake.shape = plan.shape
	st.cake.tiers = table.clone(plan.tiers)
	st.cake.drip = plan.drip
	st.cake.piping = plan.piping
	Stations.rebuild(st, true)
end

local function hop(st: Station)
	local m = st.botModel
	local home = st.botHome
	if m and home and m.Parent then
		m:PivotTo(home * CF(0, 0.7, 0))
		task.delay(0.14, function()
			if m.Parent and st.botModel == m then
				m:PivotTo(home)
			end
		end)
	end
end

-- Instant pretty cake for an unused station (dense plaza; replaced when someone takes the station).
function Bots.display(st: Station)
	local r = Random.new(st.index * 977 + os.time() % 1000)
	local plan = Bots.plan(Config.Themes[r:NextInteger(1, Config.RegularThemes)].key, r:NextNumber(0.3, 0.7), r, 9)
	local cake = CakeBuilder.newCake()
	Stations.setCake(st, cake)
	st.edits = 0
	applyBase(st, plan)
	for _, item in ipairs(plan.items) do
		placeItem(st, item, r)
	end
end

function Bots.spawn(st: Station, name: string, skill: number)
	Bots.remove(st)
	st.botName = name
	st.skill = skill
	usedNames[name] = true
	st.model:SetAttribute("OwnerName", name)
	st.model:SetAttribute("BotName", name)
	local home = st.cf * CF(Config.Station.pad) * CFrame.Angles(0, math.pi, 0)
	st.botHome = home
	st.botModel = Npc.chef(st.model, home, {
		name = name,
		skin = Config.BotSkin[rng:NextInteger(1, #Config.BotSkin)],
		apron = st.color,
		hat = "chef",
	})
	Stations.reset(st)
	Stations.updateSign(st)
end

function Bots.remove(st: Station)
	local name = st.botName
	if name then
		usedNames[name] = nil
	end
	local m = st.botModel
	if m then
		m:Destroy()
	end
	st.botModel = nil
	st.botHome = nil
	st.botName = nil
	st.model:SetAttribute("BotName", nil)
	if not st.owner then
		st.model:SetAttribute("OwnerName", "")
	end
	Stations.updateSign(st)
end

local function freeName(): string
	local names = table.clone(Config.BotNames)
	rng:Shuffle(names)
	for _, n in ipairs(names) do
		if not usedNames[n] then
			return n
		end
	end
	return names[1]
end

-- Top up the round with NPC bakers. `easy` lowers their skill (a first-time player is in the server).
function Bots.fill(target: number, easy: boolean): { Station }
	local humans = 0
	for _, st in ipairs(Stations.list) do
		if st.owner then
			humans += 1
		end
	end
	-- clear last round's bots first
	for _, st in ipairs(Stations.list) do
		if st.botName then
			Bots.remove(st)
		end
	end
	-- small servers always get a couple of NPC bakers too, so a round never shows just one cake
	local need = math.max(0, target - humans, if humans <= 6 then math.min(2, target) else 0)
	local out: { Station } = {}
	-- prefer stations on the far side so bots are visible across the stage
	local free: { Station } = {}
	for _, st in ipairs(Stations.list) do
		if not st.owner then
			table.insert(free, st)
		end
	end
	for i = #free, 1, -1 do
		if need <= 0 then
			break
		end
		local st = free[i]
		local skill = if easy then rng:NextNumber(0.15, 0.45) else rng:NextNumber(0.3, 0.8)
		Bots.spawn(st, freeName(), skill)
		table.insert(out, st)
		need -= 1
	end
	return out
end

-- Live decorating during the build phase. `alive()` turns false if the round is cancelled.
-- `deadline()` is the build phase end (server time); remaining items are placed at once when it passes.
function Bots.decorate(st: Station, themeKey: string, alive: () -> boolean, deadline: () -> number)
	local r = Random.new(rng:NextInteger(1, 1e6))
	local plan = Bots.plan(themeKey, st.skill, r)
	local start = workspace:GetServerTimeNow()
	task.wait(r:NextNumber(1.5, 4))
	if not alive() or st.botName == nil then
		return
	end
	applyBase(st, plan)
	hop(st)
	st.edits += 1
	local n = #plan.items
	for k, item in ipairs(plan.items) do
		while alive() and st.botName ~= nil do
			local span = math.max(10, deadline() - start - 8)
			local due = start + 5 + span * k / (n + 1)
			local now = workspace:GetServerTimeNow()
			if now >= due or not Stations.buildOpen then
				break
			end
			task.wait(math.min(0.5, due - now))
		end
		if not alive() or st.botName == nil then
			return
		end
		if placeItem(st, item, r) then
			st.edits += 1
			if Stations.buildOpen then
				hop(st)
			end
		end
	end
end

-- Judges ------------------------------------------------------------------------------------------------
function Bots.initJudges(built: Plaza.Built)
	judgesFolder = built.judges
	local W = Config.World
	local camFlat = V(W.voteCam.pos.X, 0, W.voteCam.pos.Z)
	local function seatCF(z: number): CFrame
		return CFrame.lookAt(V(W.judgeX + 1.7, W.stageTop, z), V(0, W.stageTop, z))
	end
	local function addPaddle(m: Model, cf: CFrame, col: Color3)
		local base = (cf * CF(1.6, 2.1, -0.9)).Position
		local flatTarget = V(camFlat.X, base.Y, camFlat.Z)
		Npc.paddle(m, CFrame.lookAt(base, flatTarget), col)
	end
	for i, j in ipairs(Config.Judges) do
		local cf = seatCF(W.judgeZ[i])
		local m = Npc.chef(built.judges, cf, { name = j.name, hat = j.hat, coat = j.coat, skin = j.skin, apron = Config.Palette.pink })
		m:SetAttribute("Judge", i)
		addPaddle(m, cf, Config.Palette.pinkDeep)
		table.insert(Bots.judgeModels, m)
	end
	local c = Config.Celebrity
	local ccf = seatCF(W.celebZ)
	local cm = Npc.chef(ServerStorage, ccf, { name = "🌟 " .. c.name, hat = c.hat, coat = c.coat, skin = c.skin, scale = 1.25, shades = true, apron = Config.Palette.gold })
	cm:SetAttribute("Judge", 4)
	addPaddle(cm, ccf, Config.Palette.gold)
	Bots.celebModel = cm
end

function Bots.celebrity(on: boolean)
	local cm = Bots.celebModel
	if cm then
		cm.Parent = if on then judgesFolder else ServerStorage
	end
end

-- Podium: move NPC bakers onto the steps and back home.
function Bots.toPodium(st: Station, top: Vector3)
	local m = st.botModel
	if m then
		m:PivotTo(CFrame.lookAt(top, top + V(0, 0, 10)))
	end
end

function Bots.goHome()
	for _, st in ipairs(Stations.list) do
		local m = st.botModel
		local home = st.botHome
		if m and home then
			m:PivotTo(home)
		end
	end
end

function Bots.init(built: Plaza.Built)
	Bots.initJudges(built)
	Stations.removeBot = Bots.remove
	Stations.onFree = Bots.display
	for _, st in ipairs(Stations.list) do
		if not st.owner then
			Bots.display(st)
		end
	end
end

return Bots

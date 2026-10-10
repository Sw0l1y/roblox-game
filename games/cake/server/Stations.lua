-- Bakery stations: who owns which station, the live cake data at each one, and the server-validated
-- build actions (clients only ask; every action is checked for phase, ownership, unlocks and distance).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CakeBuilder = require(Shared:WaitForChild("CakeBuilder"))
local Net = require(Shared:WaitForChild("Net"))
local Data = require(script.Parent:WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local Plaza = require(script.Parent:WaitForChild("Plaza"))

type Cake = CakeBuilder.Cake

export type Station = {
	index: number,
	model: Model,
	cf: CFrame,
	root: CFrame,
	pad: Vector3,
	sign: TextLabel,
	oven: { BasePart },
	ovenColors: { Color3 },
	plate: BasePart,
	padGlow: BasePart,
	color: Color3,
	owner: Player?,
	botName: string?,
	botModel: Model?,
	botHome: CFrame?,
	skill: number,
	cake: Cake,
	cakeModel: Model,
	topModels: { Model },
	edits: number,
	ready: boolean,
	golden: boolean,
	sparkle: ParticleEmitter?,
}

local Stations = {}
Stations.list = {} :: { Station }
Stations.byPlayer = {} :: { [Player]: Station }
Stations.buildOpen = false
Stations.onLateJoin = nil :: ((Player, Station) -> ())?
Stations.removeBot = nil :: ((Station) -> ())?
Stations.onFree = nil :: ((Station) -> ())?

local BOT_LIMIT = 30

function Stations.init(infos: { Plaza.StationInfo })
	for _, info in ipairs(infos) do
		local cakeModel = Instance.new("Model")
		cakeModel.Name = "Cake"
		cakeModel.Parent = info.model
		local cols = {}
		for i, p in ipairs(info.oven) do
			cols[i] = p.Color
		end
		local st: Station = {
			index = info.index,
			model = info.model,
			cf = info.cf,
			root = info.root,
			pad = info.pad,
			sign = info.sign,
			oven = info.oven,
			ovenColors = cols,
			plate = info.plate,
			padGlow = info.padGlow,
			color = info.color,
			owner = nil,
			botName = nil,
			botModel = nil,
			botHome = nil,
			skill = 0.5,
			cake = CakeBuilder.newCake(),
			cakeModel = cakeModel,
			topModels = {},
			edits = 0,
			ready = false,
			golden = false,
			sparkle = nil,
		}
		info.model:SetAttribute("Index", info.index)
		info.model:SetAttribute("OwnerId", 0)
		info.model:SetAttribute("OwnerName", "")
		info.model:SetAttribute("Golden", false)
		table.insert(Stations.list, st)
	end
	-- assignment order: nearest to the spawn first, so the first run is short
	table.sort(Stations.list, function(a: Station, b: Station)
		return (a.pad - Config.World.spawn).Magnitude < (b.pad - Config.World.spawn).Magnitude
	end)
end

-- Ownership checks (also mirrored on the client for the UI) ----------------------------------------
function Stations.ownsTopping(player: Player, d: { [string]: any }, id: string): boolean
	local def = Config.ToppingById[id]
	if not def then
		return false
	end
	if def.source == "free" then
		return true
	end
	if def.source == "vip" then
		return Shop.owns(player, "VIP")
	end
	return d.toppings ~= nil and d.toppings[id] == true
end

function Stations.ownsColor(player: Player, d: { [string]: any }, key: string): boolean
	local def = Config.ColorByKey[key]
	if not def then
		return false
	end
	if def.pass then
		return Shop.owns(player, def.pass)
	end
	return def.price == 0 or (d.colors ~= nil and d.colors[key] == true)
end

function Stations.ownsShape(d: { [string]: any }, key: string): boolean
	local def = Config.ShapeByKey[key]
	return def ~= nil and (def.price == 0 or (d.shapes ~= nil and d.shapes[key] == true))
end

function Stations.maxTiers(d: { [string]: any }): number
	return if d.tier4 then 4 else Config.Cake.freeTiers
end

function Stations.limitFor(player: Player): number
	local d = Data.get(player)
	local n = Config.Cake.baseLimit
	if d then
		n += Config.Cake.slotStep * (d.slots or 0)
	end
	if Shop.owns(player, "ExtraToppings") then
		n += Config.Cake.passSlots
	end
	return n
end

function Stations.limit(st: Station): number
	local owner = st.owner
	if owner then
		return Stations.limitFor(owner)
	end
	return BOT_LIMIT
end

-- Cake building --------------------------------------------------------------------------------------
local function bodyParams(st: Station): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = CakeBuilder.folder(st.cakeModel, "Body"):GetChildren()
	return params
end
Stations.bodyParams = bodyParams

-- The cake's look (not its toppings) as attributes on the station model, so the owner's tray can show it.
function Stations.publish(st: Station)
	local m = st.model
	m:SetAttribute("Shape", st.cake.shape)
	m:SetAttribute("Tiers", #st.cake.tiers)
	m:SetAttribute("Frost", table.concat(st.cake.tiers, ","))
	m:SetAttribute("Drip", st.cake.drip)
	m:SetAttribute("Piping", st.cake.piping)
	m:SetAttribute("Count", #st.cake.toppings)
	m:SetAttribute("Ready", st.ready)
end

-- Rebuild the body + deco; when the geometry changed, drop toppings that are no longer on an exposed surface.
function Stations.rebuild(st: Station, geometry: boolean)
	CakeBuilder.buildBody(st.cakeModel, st.cake, st.root)
	CakeBuilder.buildDeco(st.cakeModel, st.cake, st.root)
	if geometry and #st.cake.toppings > 0 then
		local params = bodyParams(st)
		local keep = {}
		for _, e in ipairs(st.cake.toppings) do
			local w = st.root * e.cf
			local up = w.UpVector
			local hit = workspace:Raycast(w.Position + up * 12, -up * 14, params)
			if hit and (hit.Position - w.Position).Magnitude < 0.45 then
				table.insert(keep, e)
			end
		end
		st.cake.toppings = keep
	end
	if geometry or #st.topModels ~= #st.cake.toppings then
		st.topModels = CakeBuilder.buildToppings(st.cakeModel, st.cake, st.root)
	end
end

function Stations.setCake(st: Station, cake: Cake)
	st.cake = cake
	CakeBuilder.build(st.cakeModel, cake, st.root)
	st.topModels = {}
	for _, m in ipairs(CakeBuilder.folder(st.cakeModel, "Toppings"):GetChildren()) do
		table.insert(st.topModels, m :: any)
	end
	Stations.publish(st)
end

function Stations.reset(st: Station)
	st.edits = 0
	st.ready = false
	Stations.setCake(st, CakeBuilder.newCake())
end

-- Place a topping at a surface point (pos/normal are hints; the server re-raycasts against the cake body).
function Stations.place(st: Station, id: string, pos: Vector3, normal: Vector3, rot: number, s: number, tint: string): (boolean, string?)
	if #st.cake.toppings >= Stations.limit(st) then
		return false, "full"
	end
	if (pos - st.root.Position).Magnitude > 16 then
		return false, "far"
	end
	local n = normal.Unit
	local hit = workspace:Raycast(pos + n * 1.5, -n * 3, bodyParams(st))
	if not hit then
		return false, "miss"
	end
	local def = Config.ToppingById[id]
	if def and def.topOnly and hit.Normal:Dot(st.root.UpVector) < 0.6 then
		return false, "top"
	end
	local world = CakeBuilder.surfaceCF(st.root, hit.Position, hit.Normal, rot)
	local entry = { id = id, cf = st.root:ToObjectSpace(world), s = s, tint = tint }
	table.insert(st.cake.toppings, entry)
	table.insert(st.topModels, CakeBuilder.addTopping(CakeBuilder.folder(st.cakeModel, "Toppings"), entry, st.root))
	return true, nil
end

function Stations.undo(st: Station): boolean
	local n = #st.cake.toppings
	if n == 0 then
		return false
	end
	table.remove(st.cake.toppings, n)
	local m = table.remove(st.topModels, #st.topModels)
	if m then
		m:Destroy()
	end
	return true
end

function Stations.clearToppings(st: Station)
	st.cake.toppings = {}
	st.topModels = CakeBuilder.buildToppings(st.cakeModel, st.cake, st.root)
end

function Stations.setTiers(st: Station, n: number)
	local tiers = st.cake.tiers
	while #tiers < n do
		table.insert(tiers, tiers[#tiers] or "Vanilla")
	end
	while #tiers > n do
		table.remove(tiers, #tiers)
	end
end

-- Signs, golden oven -----------------------------------------------------------------------------------
function Stations.updateSign(st: Station)
	local owner = st.owner
	if owner then
		st.sign.Text = owner.DisplayName .. "'s Bakery"
		st.sign.TextColor3 = if st.golden then Config.Palette.gold else Config.Palette.pinkDeep
	elseif st.botName then
		st.sign.Text = (st.botName :: string) .. "'s Bakery"
		st.sign.TextColor3 = Config.Palette.pinkDeep
	else
		st.sign.Text = "OPEN STATION"
		st.sign.TextColor3 = Config.Palette.pinkDeep
	end
end

function Stations.applyGolden(st: Station, on: boolean)
	if st.golden == on then
		return
	end
	st.golden = on
	st.model:SetAttribute("Golden", on)
	for i, p in ipairs(st.oven) do
		if on then
			p.Color = if i == 3 then Color3.fromRGB(255, 240, 160) else Config.Palette.gold
			p.Reflectance = if i == 3 then 0 else 0.3
		else
			p.Color = st.ovenColors[i]
			p.Reflectance = 0
		end
	end
	st.plate.Color = if on then Config.Palette.gold else Color3.fromRGB(255, 255, 255)
	st.plate.Reflectance = if on then 0.25 else 0
	if on and not st.sparkle then
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150), Config.Palette.gold)
		e.LightEmission = 1
		e.Rate = 6
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
		e.Speed = NumberRange.new(1, 2.5)
		e.Lifetime = NumberRange.new(0.8, 1.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Parent = st.oven[1]
		st.sparkle = e
	elseif not on and st.sparkle then
		(st.sparkle :: ParticleEmitter):Destroy()
		st.sparkle = nil
	end
	Stations.updateSign(st)
end

-- Assignment -------------------------------------------------------------------------------------------
function Stations.assign(player: Player): Station?
	local have = Stations.byPlayer[player]
	if have then
		return have
	end
	local best: Station? = nil
	for _, st in ipairs(Stations.list) do
		if not st.owner and not st.botName then
			best = st
			break
		end
	end
	if not best then
		-- full server with NPC bakers: a real player takes an NPC's station
		for _, st in ipairs(Stations.list) do
			if st.botName and not st.owner then
				local rm = Stations.removeBot
				if rm then
					rm(st)
				end
				best = st
				break
			end
		end
	end
	if not best then
		return nil
	end
	local st = best :: Station
	st.owner = player
	Stations.byPlayer[player] = st
	st.model:SetAttribute("OwnerId", player.UserId)
	st.model:SetAttribute("OwnerName", player.DisplayName)
	Stations.reset(st)
	Stations.applyGolden(st, Shop.owns(player, "GoldenOven"))
	Stations.updateSign(st)
	local late = Stations.onLateJoin
	if Stations.buildOpen and late then
		late(player, st)
	end
	return st
end

function Stations.release(player: Player)
	local st = Stations.byPlayer[player]
	if not st then
		return
	end
	Stations.byPlayer[player] = nil
	st.owner = nil
	st.edits = 0
	st.ready = false
	st.model:SetAttribute("OwnerId", 0)
	st.model:SetAttribute("OwnerName", "")
	Stations.applyGolden(st, false)
	Stations.updateSign(st)
	local cb = Stations.onFree
	if cb then
		cb(st)
	else
		Stations.reset(st)
	end
end

-- Remote handler for Build actions -------------------------------------------------------------------
-- a finite number from a remote argument (NaN and inf become the default)
local function num(x: any, default: number): number
	local n = tonumber(x)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return default
	end
	return n
end

local function near(player: Player, st: Station): boolean
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return hrp ~= nil and ((hrp :: BasePart).Position - st.pad).Magnitude < 60
end

function Stations.handle(player: Player, action: any, a: any, b: any, c: any, d4: any, e5: any, f6: any)
	if type(action) ~= "string" then
		return
	end
	local st = Stations.byPlayer[player]
	if not st or st.owner ~= player then
		return
	end
	if action == "ready" then
		if Stations.buildOpen then
			st.ready = a == true
			Stations.publish(st)
		end
		return
	end
	if not Stations.buildOpen then
		return
	end
	if not Net.allow(player, "build_" .. action, if action == "place" then 0.08 else 0.12) then
		return
	end
	local d = Data.get(player)
	if not d or not near(player, st) then
		return
	end

	if action == "shape" then
		if type(a) ~= "string" or not Stations.ownsShape(d, a) or st.cake.shape == a then
			return
		end
		st.cake.shape = a
		Stations.rebuild(st, true)
	elseif action == "tiers" then
		local n = math.floor(num(a, 0))
		if n < 1 or n > Stations.maxTiers(d) or n == #st.cake.tiers then
			return
		end
		Stations.setTiers(st, n)
		Stations.rebuild(st, true)
	elseif action == "frost" then
		local t = math.floor(num(a, -1))
		if type(b) ~= "string" or not Stations.ownsColor(player, d, b) then
			return
		end
		if t == 0 then
			for i = 1, #st.cake.tiers do
				st.cake.tiers[i] = b
			end
		elseif t >= 1 and t <= #st.cake.tiers then
			st.cake.tiers[t] = b
		else
			return
		end
		Stations.rebuild(st, false)
	elseif action == "drip" then
		if type(a) ~= "string" or (a ~= "None" and not Stations.ownsColor(player, d, a)) or st.cake.drip == a then
			return
		end
		st.cake.drip = a
		Stations.rebuild(st, false)
	elseif action == "piping" then
		if type(a) ~= "string" or (a ~= "Auto" and not Stations.ownsColor(player, d, a)) or st.cake.piping == a then
			return
		end
		st.cake.piping = a
		Stations.rebuild(st, false)
	elseif action == "place" then
		if type(a) ~= "string" or typeof(b) ~= "Vector3" or typeof(c) ~= "Vector3" then
			return
		end
		local pos = b :: Vector3
		local nrm = c :: Vector3
		if pos ~= pos or nrm ~= nrm or not (nrm.Magnitude >= 0.5 and nrm.Magnitude <= 2) then
			return
		end
		if not Stations.ownsTopping(player, d, a) then
			return
		end
		local rot = math.clamp(math.floor(num(d4, 0)), 0, Config.Cake.rotSteps - 1)
		local sizeIdx = math.clamp(math.floor(num(e5, 2)), 1, #Config.Cake.sizes)
		local tint = if type(f6) == "string" and (f6 == "Auto" or Stations.ownsColor(player, d, f6)) then f6 else "Auto"
		local ok, why = Stations.place(st, a, pos, nrm, rot, Config.Cake.sizes[sizeIdx], tint)
		if not ok then
			if why == "full" then
				Shop.notify(player, "Your cake is full! (" .. Stations.limitFor(player) .. " toppings)", "orange")
			elseif why == "top" then
				Shop.notify(player, "That one goes on TOP of a tier!", "orange")
			end
			return
		end
	elseif action == "undo" then
		if not Stations.undo(st) then
			return
		end
	elseif action == "clear" then
		if #st.cake.toppings == 0 then
			return
		end
		Stations.clearToppings(st)
	else
		return
	end
	st.edits += 1
	st.ready = false
	Stations.publish(st)
end

return Stations

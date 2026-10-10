-- Everything around the flags, drawn on this client from the server's numbers: garrisons standing guard, battles
-- (hop-in, shots, knock-overs, cheering), private outpost drills, the cat's swats sending toys flying, the block
-- tower that topples when someone captures it, and the guide beam that shows new players where to go.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Toys = require(Shared:WaitForChild("Toys"))
local World = require(Shared:WaitForChild("World"))
local Fmt = require(Shared:WaitForChild("Fmt"))
local ClientLib = ReplicatedStorage:WaitForChild("ClientLib")
local Fx = require(ClientLib:WaitForChild("Fx"))
local Sfx = require(ClientLib:WaitForChild("Sfx"))
local UI = require(ClientLib:WaitForChild("UI"))

local Arena = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local rng = Random.new()
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles

local SCALE = 1.5 -- toys on the floor are drawn a bit bigger than the toy-box showcase ones
local MAX_SHOTS = 18 -- projectiles drawn per volley (the rest still count)
local TOWER = V(0, 0, 174)

type Packed = { any } -- { id, unitKey, mut, team, ownerName, userId, power }
type Toy = { id: number, model: Model, side: string, alive: boolean, home: CFrame, mine: boolean, big: boolean, slot: number? }
type ZoneView = { def: Config.ZoneDef, snap: { [string]: any }?, toys: { [number]: Toy }, more: TextLabel? }
type FightView = {
	key: string,
	zone: string,
	attTeam: string,
	defTeam: string,
	dir: Vector3,
	toys: { [number]: Toy },
	sideOf: { [number]: string },
	alive: { [string]: { [number]: boolean } },
	queue: { [string]: { Packed } },
	slots: { [string]: number },
	label: TextLabel?,
	anchor: BasePart?,
	mineSide: string?,
	drill: boolean,
}
export type EndInfo = { key: string, zone: string, winner: string, captured: boolean, mineSide: string?, drill: boolean }

local folder = Instance.new("Folder")
folder.Name = "ArenaToys"
folder.Parent = workspace

local zones: { [string]: ZoneView } = {}
local fights: { [string]: FightView } = {}
local endHooks: { (EndInfo) -> () } = {}
local changeHooks: { (string) -> () } = {}
local rainbows: { Model } = {}

local function flat(v: Vector3): Vector3
	return V(v.X, 0, v.Z)
end

local function near(pos: Vector3, dist: number): boolean
	return (camera.CFrame.Position - pos).Magnitude < dist
end

-- Animation: one tween-like motion per model, driven every frame --------------------------------------------------
type Anim = { t0: number, dur: number, from: CFrame, to: CFrame, arc: number, axis: Vector3?, turns: number, done: (() -> ())? }
local anims: { [Model]: Anim } = {}

-- CFrame lerp that never produces NaN (slerping exactly opposite rotations can).
local function safeLerp(a: CFrame, b: CFrame, t: number): CFrame
	local r = a.Rotation:Lerp(b.Rotation, t)
	local _, _, _, r00, r01 = r:GetComponents()
	if r00 ~= r00 or r01 ~= r01 then
		r = t < 0.5 and a.Rotation or b.Rotation
	end
	return CFrame.new(a.Position:Lerp(b.Position, t)) * r
end

local function animate(m: Model, to: CFrame, dur: number, arc: number?, spinAxis: Vector3?, turns: number?, done: (() -> ())?)
	anims[m] = { t0 = os.clock(), dur = math.max(0.05, dur), from = m:GetPivot(), to = to, arc = arc or 0, axis = spinAxis, turns = turns or 0, done = done }
end

-- Move a model, first squaring up its PrimaryPart if float error has skewed its rotation (moving a model every frame
-- for a long time can otherwise slowly shear it).
local function moveModel(m: Model, cf: CFrame)
	local pp = m.PrimaryPart
	if pp then
		local c = pp.CFrame
		local x, y = c.XVector, c.YVector
		if math.abs(x:Dot(y)) > 1e-5 or math.abs(x.Magnitude - 1) > 1e-5 or math.abs(y.Magnitude - 1) > 1e-5 then
			pp.CFrame = CFrame.lookAt(c.Position, c.Position + c.LookVector, y)
		end
	end
	m:PivotTo(cf)
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for m, a in pairs(anims) do
		if not m.Parent then
			anims[m] = nil
		else
			local k = math.clamp((t - a.t0) / a.dur, 0, 1)
			local e = 1 - (1 - k) * (1 - k)
			local cf = safeLerp(a.from, a.to, e) + V(0, math.sin(k * math.pi) * a.arc, 0)
			if a.axis and a.turns ~= 0 then
				cf = cf * CFrame.fromAxisAngle(a.axis, k * a.turns * math.pi * 2)
			end
			moveModel(m, cf)
			if k >= 1 then
				anims[m] = nil
				local cb = a.done
				if cb then
					task.spawn(cb)
				end
			end
		end
	end
end)

local function fadeOut(m: Model, dur: number)
	anims[m] = nil
	task.spawn(function()
		local parts: { BasePart } = {}
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(parts, d :: BasePart)
			end
		end
		local base: { [BasePart]: number } = {}
		for _, p in ipairs(parts) do
			base[p] = p.Transparency
		end
		for i = 1, 6 do
			task.wait(dur / 6)
			for _, p in ipairs(parts) do
				p.Transparency = base[p] + (1 - base[p]) * i / 6
			end
		end
		m:Destroy()
	end)
end

-- Rainbow toys cycle their colours.
task.spawn(function()
	while true do
		task.wait(0.12)
		local h = (os.clock() * 0.35) % 1
		for i = #rainbows, 1, -1 do
			local m = rainbows[i]
			if not m.Parent then
				table.remove(rainbows, i)
			else
				local n = 0
				for _, d in ipairs(m:GetDescendants()) do
					if d:IsA("BasePart") then
						local pt = d:GetAttribute("Paint")
						if pt == "main" or pt == "dark" then
							n += 1
							(d :: BasePart).Color = Color3.fromHSV((h + n * 0.09) % 1, 0.72, pt == "dark" and 0.85 or 1)
						end
					end
				end
			end
		end
	end
end)

-- Toys -----------------------------------------------------------------------------------------------------------

local function makeToy(p: Packed, side: string, at: CFrame): Toy
	local unitKey, mut, team, userId = p[2] :: string, p[3] :: string, p[4] :: string, p[6] :: number
	local m = Toys.build(unitKey, { team = team, mut = mut, ring = true, scale = SCALE })
	m.Name = "Toy_" .. tostring(p[1])
	m:PivotTo(at)
	m.Parent = folder
	if m:GetAttribute("Rainbow") then
		table.insert(rainbows, m)
	end
	local mine = userId == player.UserId and userId ~= 0
	if mine then
		-- your own soldiers get a little name tag so you can find them in a crowd
		local root = m:FindFirstChild("Base")
		if root then
			World.label(root, "★", { width = 2, height = 2, offset = V(0, 7.5, 0), maxDistance = 90, color = Config.C.yellow })
		end
	end
	local idx = Config.UnitIndex[unitKey] or 1
	return { id = p[1] :: number, model = m, side = side, alive = true, home = at, mine = mine, big = idx >= 4 }
end

local function knock(t: Toy, dir: Vector3)
	t.alive = false
	local m = t.model
	local back = flat(dir).Magnitude > 0.01 and flat(dir).Unit or V(0, 0, 1)
	local to = (t.home + back * rng:NextNumber(5, 9)) * ANG(-math.pi / 2 * 0.95, 0, rng:NextNumber(-0.4, 0.4))
	animate(m, to, 0.45, 3, nil, 0, function()
		task.wait(0.6)
		fadeOut(m, 0.6)
	end)
	if near(t.home.Position, 110) and rng:NextNumber() < 0.6 then
		Sfx.play("pop", 0.18, rng:NextNumber(1.2, 1.6))
	end
end

local function fling(t: Toy, center: Vector3)
	t.alive = false
	local m = t.model
	local from = m:GetPivot().Position
	local away = flat(from - center)
	if away.Magnitude < 0.5 then
		away = V(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
	end
	local dist = rng:NextNumber(36, 70)
	local target = from + away.Unit * dist
	local axis = V(rng:NextNumber(-1, 1), rng:NextNumber(-0.3, 0.3), rng:NextNumber(-1, 1))
	if axis.Magnitude < 0.1 then
		axis = V(1, 0, 0)
	end
	animate(m, CF(V(target.X, 0.4, target.Z)) * ANG(math.pi / 2, rng:NextNumber(0, 6), 0), rng:NextNumber(1.2, 1.8), rng:NextNumber(30, 50), axis.Unit, rng:NextInteger(2, 4), function()
		task.wait(1.5)
		fadeOut(m, 0.8)
	end)
end

local function hop(t: Toy, times: number)
	task.spawn(function()
		for _ = 1, times do
			if not t.model.Parent then
				return
			end
			animate(t.model, t.home, 0.32, 2.4)
			task.wait(0.36)
		end
	end)
end

-- A plastic pellet from one toy to another.
local function shoot(a: Toy, b: Toy, color: Color3, big: boolean): number
	local p0 = Toys.muzzle(a.model)
	local h = (b.model:GetAttribute("Height") :: number?) or 3
	local p1 = b.model:GetPivot().Position + V(0, h * SCALE * 0.5, 0)
	local pellet = Instance.new("Part")
	pellet.Shape = Enum.PartType.Ball
	pellet.Size = big and V(1.4, 1.4, 1.4) or V(0.7, 0.7, 0.7)
	pellet.Material = Enum.Material.Neon
	pellet.Color = color
	pellet.Anchored = true
	pellet.CanCollide = false
	pellet.CanQuery = false
	pellet.CanTouch = false
	pellet.CastShadow = false
	pellet.CFrame = CF(p0)
	pellet.Parent = folder
	local dur = math.clamp((p1 - p0).Magnitude / 90, 0.12, 0.35)
	UI.tween(pellet, dur, { Position = p1 }, Enum.EasingStyle.Linear)
	task.delay(dur, function()
		pellet:Destroy()
	end)
	-- recoil
	local m = a.model
	if not anims[m] and a.alive then
		local back = (a.home.Position - p1)
		back = flat(back).Magnitude > 0.01 and flat(back).Unit * 0.6 or V()
		animate(m, a.home + back, 0.08, 0.3, nil, 0, function()
			if a.alive and m.Parent and not anims[m] then
				animate(m, a.home, 0.12)
			end
		end)
	end
	return dur
end

-- Garrisons --------------------------------------------------------------------------------------------------------

local function ringSpot(def: Config.ZoneDef, i: number, n: number, big: boolean): CFrame
	local a = (i - 1) / math.max(1, n) * math.pi * 2 + 0.4
	local r = (big and 13 or 10) + (n > 6 and 2 or 0)
	local c = def.pos
	local p = V(c.X + math.cos(a) * r, c.Y, c.Z + math.sin(a) * r)
	return CFrame.lookAt(p, p + flat(p - c))
end

local function setMore(zv: ZoneView, extra: number)
	if not zv.more then
		local anchor = World.part({
			Name = "MoreAnchor",
			CFrame = CF(zv.def.pos + V(0, 5, 0)),
			Size = V(1, 1, 1),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Parent = folder,
		})
		local bb = World.label(anchor, "", { width = 6, height = 2, offset = V(0, 3, 0), maxDistance = 140, color = Color3.new(1, 1, 1) })
		zv.more = bb:FindFirstChildOfClass("TextLabel") :: TextLabel?
	end
	local l = zv.more
	if l then
		l.Text = extra > 0 and ("+" .. extra .. " 🪖") or ""
	end
end

local function layoutGarrison(zv: ZoneView)
	local snap = zv.snap
	if not snap or snap.fight then
		return
	end
	local units: { Packed } = snap.units or {}
	local show: { Packed } = {}
	for i = 1, math.min(#units, Config.ShowPerSide) do
		table.insert(show, units[i])
	end
	local keep: { [number]: boolean } = {}
	for _, p in ipairs(show) do
		keep[p[1]] = true
	end
	for id, t in pairs(zv.toys) do
		if not keep[id] then
			zv.toys[id] = nil
			if t.alive then
				fadeOut(t.model, 0.4)
			end
		end
	end
	for i, p in ipairs(show) do
		local idx = Config.UnitIndex[p[2]] or 1
		local spot = ringSpot(zv.def, i, #show, idx >= 4)
		local t = zv.toys[p[1]]
		if t and t.model.Parent then
			t.home = spot
			animate(t.model, spot, 0.5, 1.5)
		else
			t = makeToy(p, "def", spot + V(0, 8, 0))
			t.home = spot
			zv.toys[p[1]] = t
			animate(t.model, spot, 0.35)
		end
	end
	setMore(zv, #units - #show)
end

local function clearGarrison(zv: ZoneView, keepFor: FightView?)
	for id, t in pairs(zv.toys) do
		if keepFor and keepFor.sideOf[id] == "def" and not keepFor.toys[id] then
			t.slot = nil
			keepFor.toys[id] = t
		else
			fadeOut(t.model, 0.3)
		end
	end
	zv.toys = {}
	setMore(zv, 0)
end

local function onZone(id: string, snap: { [string]: any })
	local zv = zones[id]
	if not zv then
		return
	end
	zv.snap = snap
	if not snap.fight then
		layoutGarrison(zv)
	else
		local fv = fights[id]
		if not fv then
			clearGarrison(zv, nil)
		end
	end
	for _, cb in ipairs(changeHooks) do
		task.spawn(cb, id)
	end
end

-- Fights ---------------------------------------------------------------------------------------------------------------

local function slotCF(fv: FightView, side: string, i: number): CFrame
	local def = Config.ZoneById[fv.zone]
	local c = def.pos
	local dir = fv.dir
	local right = V(-dir.Z, 0, dir.X)
	local row = math.floor((i - 1) / 4)
	local col = (i - 1) % 4
	local lateral = (col - 1.5) * 6.5 + (row % 2) * 3
	if side == "att" then
		local p = c - dir * (17 + row * 6) + right * lateral
		return CFrame.lookAt(p, p + dir)
	end
	local p = c - dir * (row == 0 and 8 or -8 - (row - 1) * 6) + right * lateral
	return CFrame.lookAt(p, p - dir)
end

local function aliveCount(fv: FightView, side: string): number
	local n = 0
	for _ in pairs(fv.alive[side]) do
		n += 1
	end
	return n
end

local function refreshLabel(fv: FightView)
	local l = fv.label
	if not l then
		return
	end
	local a, d = aliveCount(fv, "att"), aliveCount(fv, "def")
	local an = Config.Team[fv.attTeam] and Config.Team[fv.attTeam].short or "TOYS"
	local dn = Config.Team[fv.defTeam] and Config.Team[fv.defTeam].short or "WIND-UP"
	l.Text = string.format("%s %d  ⚔️  %d %s", an, a, d, dn)
end

local function renderedAlive(fv: FightView, side: string): number
	local n = 0
	for _, t in pairs(fv.toys) do
		if t.side == side and t.alive then
			n += 1
		end
	end
	return n
end

local function addToFight(fv: FightView, side: string, list: { Packed }, hopIn: boolean)
	for _, p in ipairs(list) do
		local id = p[1] :: number
		fv.sideOf[id] = side
		fv.alive[side][id] = true
		if (p[6] :: number) == player.UserId then
			fv.mineSide = fv.mineSide or side
		end
		table.insert(fv.queue[side], p)
	end
	-- draw up to ShowPerSide per side; the rest wait in the queue and step in as others fall
	while renderedAlive(fv, side) < Config.ShowPerSide and #fv.queue[side] > 0 do
		local p = table.remove(fv.queue[side], 1) :: Packed
		local id = p[1] :: number
		if fv.alive[side][id] then
			-- the lowest slot no standing toy is using, so the lines stay tight as toys fall and others step in
			local used: { [number]: boolean } = {}
			for _, o in pairs(fv.toys) do
				if o.side == side and o.alive and o.slot then
					used[o.slot] = true
				end
			end
			local slot = 1
			while used[slot] do
				slot += 1
			end
			fv.slots[side] = math.max(fv.slots[side], slot)
			local spot = slotCF(fv, side, slot)
			local t = fv.toys[id]
			if t and t.model.Parent then
				t.side = side
				t.home = spot
				t.slot = slot
				animate(t.model, spot, 0.5, 1.5)
			else
				local start = hopIn and (spot - fv.dir * (side == "att" and 26 or -14)) or spot + V(0, 6, 0)
				t = makeToy(p, side, start)
				t.home = spot
				t.slot = slot
				fv.toys[id] = t
				animate(t.model, spot, hopIn and 1.1 or 0.35, hopIn and 4 or 0)
			end
		end
	end
	refreshLabel(fv)
end

local function onStart(key: string, info: { [string]: any })
	local old = fights[key]
	if old then
		for _, t in pairs(old.toys) do
			fadeOut(t.model, 0.2)
		end
		if old.anchor then
			old.anchor:Destroy()
		end
	end
	local def = Config.ZoneById[info.zone]
	if not def then
		return
	end
	local from = Config.Spawn[info.attTeam] and Config.Spawn[info.attTeam].pos or (def.pos + V(0, 0, 40))
	local dir = flat(def.pos - from)
	dir = dir.Magnitude > 1 and dir.Unit or V(0, 0, -1)
	local fv: FightView = {
		key = key,
		zone = info.zone,
		attTeam = info.attTeam,
		defTeam = info.defTeam,
		dir = dir,
		toys = {},
		sideOf = {},
		alive = { att = {}, def = {} },
		queue = { att = {}, def = {} },
		slots = { att = 0, def = 0 },
		label = nil,
		anchor = nil,
		mineSide = nil,
		drill = string.sub(key, 1, 6) == "drill:",
	}
	fights[key] = fv
	local anchor = World.part({
		Name = "FightAnchor",
		CFrame = CF(def.pos + V(0, 3, 0)),
		Size = V(1, 1, 1),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = folder,
	})
	fv.anchor = anchor
	local bb = World.label(anchor, "", { width = 14, height = 2.6, offset = V(0, 9, 0), maxDistance = 200, color = Color3.new(1, 1, 1), onTop = true })
	fv.label = bb:FindFirstChildOfClass("TextLabel") :: TextLabel?
	-- defenders already standing guard keep their models
	local defList: { Packed } = info.def or {}
	local attList: { Packed } = info.att or {}
	for _, p in ipairs(defList) do
		fv.sideOf[p[1]] = "def"
	end
	local zv = zones[info.zone]
	if zv and not fv.drill then
		clearGarrison(zv, fv)
	end
	addToFight(fv, "def", defList, false)
	addToFight(fv, "att", attList, true)
	if near(def.pos, 160) or fv.mineSide then
		Sfx.play("whoosh", 0.35, 1.1)
	end
	Fx.shockwave(def.pos + V(0, 1, 0), Config.teamColor(info.attTeam), 22)
end

local function onJoin(key: string, side: string, list: { Packed })
	local fv = fights[key]
	if fv then
		addToFight(fv, side, list, true)
	end
end

local function pickAlive(fv: FightView, side: string?): Toy?
	if not side then
		return nil
	end
	local list: { Toy } = {}
	for _, t in pairs(fv.toys) do
		if t.side == side and t.alive then
			table.insert(list, t)
		end
	end
	if #list == 0 then
		return nil
	end
	return list[rng:NextInteger(1, #list)]
end

local function onVolley(key: string, events: { { number } })
	local fv = fights[key]
	if not fv then
		return
	end
	local shots = 0
	local popups = 0
	local nearby = near(Config.ZoneById[fv.zone].pos, 220) or fv.mineSide ~= nil
	for _, ev in ipairs(events) do
		local from, to, amount, flag = ev[1], ev[2], ev[3], ev[4]
		local tside = fv.sideOf[to]
		local B = fv.toys[to]
		if flag == 2 then
			if B and B.alive and nearby and popups < 6 then
				popups += 1
				local pos = B.model:GetPivot().Position + V(0, 6, 0)
				Fx.popup(pos, "+" .. Fmt.num(amount), Config.C.lime, 0.8)
			end
		else
			shots += 1
			local A = fv.toys[from]
			if not (A and A.alive) then
				A = pickAlive(fv, fv.sideOf[from])
			end
			if flag == 1 and tside then
				fv.alive[tside][to] = nil
			end
			if nearby and shots <= MAX_SHOTS and A and B and B.alive then
				local a, b = A :: Toy, B :: Toy
				local delay = (shots % 9) * 0.05
				local color = Config.teamColor(fv.sideOf[from] == "att" and fv.attTeam or fv.defTeam)
				task.delay(delay, function()
					if not (a.model.Parent and b.model.Parent) then
						return
					end
					local dur = shoot(a, b, color, a.big)
					task.delay(dur, function()
						if flag == 1 and b.alive then
							knock(b, b.home.Position - a.home.Position)
						end
						if (b.mine or a.mine or amount >= 1000) and popups < 6 then
							popups += 1
							Fx.popup(b.model:GetPivot().Position + V(0, 6, 0), "-" .. Fmt.num(amount), flag == 1 and Config.C.red or Color3.new(1, 1, 1), flag == 1 and 1 or 0.7)
						end
					end)
				end)
			elseif flag == 1 and B and B.alive then
				local b = B :: Toy
				task.delay(0.3, function()
					if b.alive then
						knock(b, b.home.Position - Config.ZoneById[fv.zone].pos)
					end
				end)
			end
		end
	end
	-- fallen toys make room for the next ones in line
	task.delay(0.5, function()
		if fights[key] == fv then
			addToFight(fv, "att", {}, true)
			addToFight(fv, "def", {}, true)
		end
	end)
	refreshLabel(fv)
end

local function onEnd(key: string, winner: string, captured: boolean)
	local fv = fights[key]
	if not fv then
		return
	end
	fights[key] = nil
	local def = Config.ZoneById[fv.zone]
	local anchor = fv.anchor
	if anchor then
		task.delay(1.2, function()
			anchor:Destroy()
		end)
	end
	if fv.label then
		local wTeam = Config.Team[winner]
		fv.label.Text = winner == "Cat" and "🐱 SWATTED!" or (wTeam and (wTeam.short .. " WINS!") or "WIND-UP TOYS WIN!")
	end
	if winner == "Cat" then
		for _, t in pairs(fv.toys) do
			if t.alive then
				fling(t, def.pos)
			end
		end
	else
		local winSide = captured and "att" or "def"
		local zv = zones[fv.zone]
		for id, t in pairs(fv.toys) do
			if t.alive and t.side == winSide then
				hop(t, 2)
				if zv and not fv.drill then
					zv.toys[id] = t -- winners stay on as the garrison
				else
					task.delay(1.4, function()
						fadeOut(t.model, 0.5)
					end)
				end
			elseif t.alive then
				fadeOut(t.model, 0.5)
			end
		end
		if captured and (near(def.pos, 200) or fv.mineSide) then
			Fx.burst(def.pos + V(0, 12, 0), { Config.teamColor(winner), Config.C.white, Config.C.yellow }, 22, 1.6)
			Fx.shockwave(def.pos + V(0, 1, 0), Config.teamColor(winner), 28)
		end
		if zv and zv.snap and not zv.snap.fight then
			layoutGarrison(zv)
		end
	end
	local info: EndInfo = { key = key, zone = fv.zone, winner = winner, captured = captured, mineSide = fv.mineSide, drill = fv.drill }
	for _, cb in ipairs(endHooks) do
		task.spawn(cb, info)
	end
end

local function onSwat(zoneId: string)
	local zv = zones[zoneId]
	if not zv then
		return
	end
	for _, t in pairs(zv.toys) do
		if t.alive then
			fling(t, zv.def.pos)
		end
	end
	zv.toys = {}
	setMore(zv, 0)
	if near(zv.def.pos, 160) then
		UI.shake(1)
	end
end

-- The block tower ----------------------------------------------------------------------------------------------------
type Block = { part: BasePart, home: CFrame, model: Model }
local blocks: { Block } = {}
local toppled = false

local function buildTower()
	local tf = Instance.new("Folder")
	tf.Name = "BlockTower"
	tf.Parent = folder
	local cols = { Config.C.red, Config.C.blue, Config.C.yellow, Config.C.lime, Config.C.purple, Config.C.orange }
	local letters = { "T", "O", "Y", "A", "R", "M", "Y", "★", "1", "2", "3", "★", "G", "O", "!", "★", "♥", "★" }
	local n = 0
	for level = 0, 8 do
		for k = 0, 1 do
			n += 1
			local off = (k - 0.5) * 8.2
			local pos = level % 2 == 0 and V(off, level * 8 + 4, 0) or V(0, level * 8 + 4, off)
			local m = Instance.new("Model")
			m.Name = "Block"
			local cf = CF(TOWER + pos) * ANG(0, (level % 2) * math.pi / 2 + rng:NextNumber(-0.05, 0.05), 0)
			local p = World.part({
				Name = "Block",
				CFrame = cf,
				Size = V(8, 8, 8),
				Color = cols[(n - 1) % #cols + 1],
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				Parent = m,
			})
			local sg = Instance.new("SurfaceGui")
			sg.Face = Enum.NormalId.Front
			sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			sg.PixelsPerStud = 16
			sg.LightInfluence = 0.3
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Size = UDim2.fromScale(1, 1)
			l.Font = Enum.Font.LuckiestGuy
			l.TextScaled = true
			l.Text = letters[(n - 1) % #letters + 1]
			l.TextColor3 = Color3.new(1, 1, 1)
			local st = Instance.new("UIStroke")
			st.Thickness = 3
			st.Color = Config.C.ink
			st.Parent = l
			l.Parent = sg
			sg.Parent = p
			m.PrimaryPart = p
			m.Parent = tf
			table.insert(blocks, { part = p, home = cf, model = m })
		end
	end
end

local function topple()
	if toppled then
		return
	end
	toppled = true
	if near(TOWER, 220) then
		Sfx.play("thud", 0.6, 0.8)
		UI.shake(0.6)
	end
	for i, b in ipairs(blocks) do
		local a = rng:NextNumber(-math.pi * 0.9, math.pi * 0.1) -- mostly away from the door
		local r = 10 + (b.home.Position.Y / 72) * 48 + rng:NextNumber(-6, 6)
		local p = TOWER + V(math.cos(a) * r, 4, math.sin(a) * r * 0.8)
		local to = CF(p) * ANG(0, rng:NextNumber(0, 6.28), 0) * ANG(math.pi / 2 * rng:NextInteger(0, 1), 0, 0)
		task.delay((#blocks - i) * 0.03, function()
			animate(b.model, to, rng:NextNumber(0.9, 1.4), rng:NextNumber(4, 12))
		end)
	end
	task.delay(24, function()
		for i, b in ipairs(blocks) do
			task.delay(i * 0.12, function()
				animate(b.model, b.home, 0.6, 6)
			end)
		end
		task.wait(#blocks * 0.12 + 0.7)
		toppled = false
	end)
end

-- Guide beam ------------------------------------------------------------------------------------------------------------
local guideZone: string? = nil
local guideAnchor: BasePart? = nil
local guideBeam: Beam? = nil
local guideA0: Attachment? = nil

function Arena.setGuide(zoneId: string?)
	if zoneId == guideZone then
		return
	end
	guideZone = zoneId
	if guideAnchor then
		guideAnchor:Destroy()
		guideAnchor = nil
		guideBeam = nil
	end
	if guideA0 then
		guideA0:Destroy()
		guideA0 = nil
	end
	local def = zoneId and Config.ZoneById[zoneId] or nil
	if not def then
		return
	end
	local anchor = World.part({
		Name = "GuideAnchor",
		CFrame = CF(def.pos + V(0, 22, 0)),
		Size = V(1, 1, 1),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = folder,
	})
	guideAnchor = anchor
	local a1 = Instance.new("Attachment")
	a1.Parent = anchor
	local bb = World.label(anchor, "⬇️ GO HERE! ⬇️", { width = 12, height = 3, offset = V(0, 6, 0), maxDistance = 600, color = Config.C.yellow, onTop = true })
	task.spawn(function()
		local t = 0
		while bb.Parent do
			t += 0.05
			bb.StudsOffset = V(0, 6 + math.sin(t * 5) * 1.2, 0)
			task.wait(0.05)
		end
	end)
	local beam = Instance.new("Beam")
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(Config.C.yellow, Config.teamColor(player:GetAttribute("Side") :: string?))
	beam.Width0 = 1.2
	beam.Width1 = 2.4
	beam.FaceCamera = true
	beam.LightEmission = 0.8
	beam.Transparency = NumberSequence.new(0.15, 0.45)
	beam.Segments = 24
	beam.CurveSize0 = 18
	beam.CurveSize1 = -6
	beam.Parent = anchor
	guideBeam = beam
end

-- keep the beam's near end on the current character
task.spawn(function()
	while true do
		task.wait(0.5)
		local beam = guideBeam
		if beam then
			local ch = player.Character
			local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
			local old = guideA0
			if hrp and (not old or old.Parent ~= hrp) then
				if old then
					old:Destroy()
				end
				local a0 = Instance.new("Attachment")
				a0.Position = V(0, -1.5, 0)
				a0.Parent = hrp
				guideA0 = a0
				beam.Attachment0 = a0
			end
		end
	end
end)

-- API ----------------------------------------------------------------------------------------------------------------------

function Arena.snapshot(zoneId: string): { [string]: any }?
	local zv = zones[zoneId]
	return zv and zv.snap or nil
end

function Arena.onChange(cb: (string) -> ())
	table.insert(changeHooks, cb)
end

function Arena.onEnd(cb: (EndInfo) -> ())
	table.insert(endHooks, cb)
end

-- Fights this player has soldiers in right now.
function Arena.myFights(): number
	local n = 0
	for _, fv in pairs(fights) do
		if fv.mineSide then
			n += 1
		end
	end
	return n
end

function Arena.init()
	for _, def in ipairs(Config.Zones) do
		zones[def.id] = { def = def, snap = nil, toys = {} }
	end
	buildTower()
	Net.event("Zone").OnClientEvent:Connect(function(id, snap)
		if type(id) == "string" and type(snap) == "table" then
			onZone(id, snap)
		end
	end)
	Net.event("Battle").OnClientEvent:Connect(function(kind, a, b, c)
		if kind == "start" then
			onStart(a :: string, b :: any)
		elseif kind == "join" then
			onJoin(a :: string, b :: string, c :: any)
		elseif kind == "volley" then
			onVolley(a :: string, b :: any)
		elseif kind == "end" then
			onEnd(a :: string, b :: string, c == true)
		elseif kind == "swat" then
			onSwat(a :: string)
		end
	end)
	Net.event("Topple").OnClientEvent:Connect(topple)
	task.spawn(function()
		local ok, all = pcall(function()
			return Net.func("Sync"):InvokeServer()
		end)
		if ok and type(all) == "table" then
			for id, snap in pairs(all :: { [string]: any }) do
				local zv = zones[id]
				if zv and not zv.snap and type(snap) == "table" then
					onZone(id, snap)
				end
			end
		end
	end)
	-- the enemy outpost's prompt is not for us
	task.spawn(function()
		for _ = 1, 40 do
			local s = player:GetAttribute("Side")
			local room = workspace:FindFirstChild("Room")
			local zf = room and room:FindFirstChild("Zones")
			if s and zf then
				local enemyOut = s == "Green" and "out_t" or "out_g"
				local flag = zf:FindFirstChild("Flag_" .. enemyOut)
				local cap = flag and flag:FindFirstChild("Cap")
				local prompt = cap and cap:FindFirstChild("DeployPrompt")
				if prompt and prompt:IsA("ProximityPrompt") then
					prompt.Enabled = false
					return
				end
			end
			task.wait(0.5)
		end
	end)
end

return Arena

-- Each player's toy box base along their team's stretch of the south wall: an open toy box that grows with the
-- "Bigger Box" upgrade (golden for Pro Commanders), a mold press that lights up while merging, a podium with the
-- three strongest soldiers, and a sign with the army size. Public progress everyone walks past.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local World = require(Shared:WaitForChild("World"))
local Fmt = require(Shared:WaitForChild("Fmt"))
local Toys = require(Shared:WaitForChild("Toys"))
local Data = require(script.Parent:WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local Army = require(script.Parent:WaitForChild("Army"))

local Bases = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local RAD = math.rad

type Base = {
	player: Player,
	team: string,
	slot: number,
	pos: Vector3,
	model: Model,
	dynamic: Folder,
	info: TextLabel?,
	press: BasePart?,
	sig: string,
}

local bases: { [Player]: Base } = {}
local used: { [string]: { [number]: Player } } = { Green = {}, Tan = {} }
local folder: Folder

local function clear(f: Instance)
	for _, c in ipairs(f:GetChildren()) do
		c:Destroy()
	end
end

-- The toy box itself (rebuilt when the box level or Pro status changes).
local function buildBox(b: Base, d: { [string]: any })
	local lvl = d.upgrades.box or 0
	local pro = Shop.owns(b.player, "pro")
	local s = 1 + math.min(lvl, 20) * 0.025
	local team = Config.Team[b.team]
	local body = pro and Config.C.gold or team.color
	local trim = pro and Config.C.white or Config.C.white
	local dark = pro and Config.C.goldDark or team.dark
	local f = b.dynamic
	local c = b.pos + V(0, 0, 6)
	local w, h, dd = 22 * s, 13 * s, 14 * s
	local t = 1.2
	local function part(cf: CFrame, size: Vector3, color: Color3, extra: { [string]: any }?)
		local props: { [string]: any } = { Name = "Box", CFrame = cf, Size = size, Color = color, CanTouch = false, CanQuery = false, Parent = f }
		for k, v in pairs(extra or {}) do
			props[k] = v
		end
		return World.part(props)
	end
	part(CF(c + V(0, t / 2, 0)), V(w, t, dd), dark)
	part(CF(c + V(0, h / 2, -dd / 2 + t / 2)), V(w, h, t), body)
	part(CF(c + V(0, h / 2, dd / 2 - t / 2)), V(w, h, t), body)
	part(CF(c + V(-w / 2 + t / 2, h / 2, 0)), V(t, h, dd), body)
	part(CF(c + V(w / 2 - t / 2, h / 2, 0)), V(t, h, dd), body)
	-- rim
	part(CF(c + V(0, h + 0.4, -dd / 2 + t / 2)), V(w + 0.6, 0.8, t + 0.6), trim, { CanCollide = false })
	part(CF(c + V(0, h + 0.4, dd / 2 - t / 2)), V(w + 0.6, 0.8, t + 0.6), trim, { CanCollide = false })
	part(CF(c + V(-w / 2 + t / 2, h + 0.4, 0)), V(t + 0.6, 0.8, dd), trim, { CanCollide = false })
	part(CF(c + V(w / 2 - t / 2, h + 0.4, 0)), V(t + 0.6, 0.8, dd), trim, { CanCollide = false })
	-- lid leaning back against the wall
	part(CF(c + V(0, h + h * 0.45, dd / 2 + 1.2)) * ANG(RAD(12), 0, 0), V(w, h * 0.95, t), dark, { CanCollide = false })
	-- front sticker: star + level
	local plate = part(CF(c + V(0, h * 0.5, -dd / 2 - 0.1)), V(w * 0.62, h * 0.62, 0.2), trim, { CanCollide = false })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 24
	sg.LightInfluence = 0.2
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.TextScaled = true
	l.Font = Enum.Font.LuckiestGuy
	l.Text = (pro and "👑" or "★") .. "\nLV " .. (lvl + 1)
	l.TextColor3 = body
	local st = Instance.new("UIStroke")
	st.Thickness = 4
	st.Color = Config.C.ink
	st.Parent = l
	l.Parent = sg
	sg.Parent = plate
	-- soldiers peeking over the rim (more with a bigger box)
	for i = 1, math.min(5, 2 + math.floor(lvl / 3)) do
		local x = (i - 3) * (w / 6)
		World.part({ Name = "Peek", Shape = Enum.PartType.Ball, CFrame = CF(c + V(x, h - 0.2, (i % 2) * 2 - 1)), Size = V(1.6, 1.6, 1.6), Color = team.color, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false, Parent = f })
		World.part({ Name = "Peek", Shape = Enum.PartType.Ball, CFrame = CF(c + V(x, h + 0.35, (i % 2) * 2 - 1)), Size = V(2, 1.1, 2), Color = team.dark, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false, Parent = f })
	end
end

-- Podium with the 3 strongest soldiers.
local function buildShowcase(b: Base, d: { [string]: any })
	type Entry = { u: string, m: string, p: number }
	local list: { Entry } = {}
	for stack, n in pairs(d.units) do
		if n > 0 then
			local u, m = Config.split(stack)
			table.insert(list, { u = u, m = m, p = Config.power(u, m) })
		end
	end
	table.sort(list, function(x: Entry, y: Entry)
		return x.p > y.p
	end)
	local spots: { { off: Vector3, h: number } } = { { off = V(0, 0, -11), h = 3 }, { off = V(-8, 0, -9), h = 2 }, { off = V(8, 0, -9), h = 1.2 } }
	local team = Config.Team[b.team]
	for i, sp in ipairs(spots) do
		local p = b.pos + sp.off
		local h = sp.h
		World.cyl(b.dynamic, p, h, 6.4, Config.C.white, { Name = "Podium", CanTouch = false })
		World.cyl(b.dynamic, p + V(0, h - 0.4, 0), 0.5, 6.8, team.color, { Name = "PodiumTrim", CanTouch = false, CanCollide = false, CanQuery = false })
		local e = list[i]
		if e then
			local m = Toys.build(e.u, { team = b.team, mut = e.m, shadows = true, scale = 1.1 })
			m:PivotTo(CFrame.lookAt(p + V(0, h, 0), p + V(0, h, -10)))
			m.Parent = b.dynamic
		end
	end
end

local function signature(b: Base, d: { [string]: any }): string
	local top = {}
	for stack, n in pairs(d.units) do
		if n > 0 then
			table.insert(top, stack)
		end
	end
	table.sort(top, function(x, y)
		local ux, mx = Config.split(x)
		local uy, my = Config.split(y)
		return Config.power(ux, mx) > Config.power(uy, my)
	end)
	return table.concat({ top[1] or "", top[2] or "", top[3] or "", tostring(d.upgrades.box or 0), tostring(Shop.owns(b.player, "pro")) }, "/")
end

local function refresh(b: Base)
	local d = Data.get(b.player)
	if not d then
		return
	end
	local sig = signature(b, d)
	if sig ~= b.sig then
		b.sig = sig
		clear(b.dynamic)
		buildBox(b, d)
		buildShowcase(b, d)
	end
	local info = b.info
	if info then
		info.Text = string.format("🪖 %d soldiers · 💪 %s", Army.count(d), Fmt.num(Army.armyPower(b.player, d)))
	end
	local press = b.press
	if press then
		local merging = #d.merging > 0
		press.Material = merging and Enum.Material.Neon or Enum.Material.SmoothPlastic
		press.Color = merging and Config.C.lime or Config.C.grey
	end
end

function Bases.assign(player: Player, team: string): Vector3?
	local slots = Config.BaseSlots[team]
	local slot = nil
	for i = 1, #slots do
		if not used[team][i] then
			slot = i
			break
		end
	end
	if not slot then
		return nil
	end
	used[team][slot] = player
	local pos = slots[slot]
	local model = World.model("Base_" .. player.UserId, folder)
	model:SetAttribute("OwnerId", player.UserId)
	model:SetAttribute("Team", team)
	local tc = Config.Team[team]
	-- floor mat
	local mat = World.disc(model, pos.X, pos.Z, 17, 0.3, 0.3, tc.color:Lerp(Color3.new(1, 1, 1), 0.55))
	mat.CanTouch = false
	mat.CastShadow = false
	local edge = World.disc(model, pos.X, pos.Z, 17.8, 0.24, 0.24, tc.dark)
	edge.CanTouch = false
	edge.CastShadow = false
	-- mold press next to the box
	local pp = pos + V(15.5, 0, 4)
	World.part({ Name = "PressBase", CFrame = CF(pp + V(0, 1.5, 0)), Size = V(7, 3, 7), Color = Config.C.purple, CanTouch = false, Parent = model })
	World.cyl(model, pp + V(0, 3, 0), 5, 2, Config.C.white, { Name = "PressRod", CanTouch = false })
	World.cyl(model, pp + V(0, 8, 0), 1.6, 7.4, Config.C.purple, { Name = "PressTop", CanTouch = false })
	local press = World.ball(model, pp + V(0, 10.6, 0), 2.6, Config.C.grey, { Name = "PressLight", CanCollide = false, CanTouch = false, CanQuery = false })
	World.label(press, "🔀 MOLD PRESS", { width = 9, height = 1.8, offset = V(0, 2.6, 0), maxDistance = 70, color = Config.C.white })
	-- name + army billboard
	local anchor = World.part({ Name = "SignAnchor", CFrame = CF(pos + V(0, 30, 6)), Size = V(1, 1, 1), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = model })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(26, 6)
	bb.MaxDistance = 160
	bb.LightInfluence = 0
	bb.Adornee = anchor
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 0.56)
	name.Font = Enum.Font.LuckiestGuy
	name.TextScaled = true
	name.TextColor3 = tc.color
	name.Text = player.DisplayName .. "'s Toy Box"
	local s1 = Instance.new("UIStroke")
	s1.Thickness = 3
	s1.Color = Config.C.ink
	s1.Parent = name
	name.Parent = bb
	local info = Instance.new("TextLabel")
	info.BackgroundTransparency = 1
	info.Position = UDim2.fromScale(0, 0.58)
	info.Size = UDim2.fromScale(1, 0.4)
	info.Font = Enum.Font.FredokaOne
	info.TextScaled = true
	info.TextColor3 = Color3.new(1, 1, 1)
	info.Text = "🪖 0 soldiers"
	local s2 = Instance.new("UIStroke")
	s2.Thickness = 2.5
	s2.Color = Config.C.ink
	s2.Parent = info
	info.Parent = bb
	bb.Parent = anchor
	local dynamic = Instance.new("Folder")
	dynamic.Name = "Dynamic"
	dynamic.Parent = model
	local b: Base = { player = player, team = team, slot = slot, pos = pos, model = model, dynamic = dynamic, info = info, press = press, sig = "" }
	bases[player] = b
	player:SetAttribute("BasePos", pos)
	refresh(b)
	return pos
end

function Bases.release(player: Player)
	local b = bases[player]
	if not b then
		return
	end
	bases[player] = nil
	if used[b.team][b.slot] == player then
		used[b.team][b.slot] = nil
	end
	b.model:Destroy()
end

function Bases.get(player: Player): Vector3?
	local b = bases[player]
	return b and b.pos or nil
end

function Bases.refreshNow(player: Player)
	local b = bases[player]
	if b then
		b.sig = ""
		refresh(b)
	end
end

function Bases.init(parent: Instance)
	folder = World.folder("Bases", parent)
	-- empty slots show a cardboard "free spot" mat so the rows never look broken
	for team, slots in pairs(Config.BaseSlots) do
		for _, p in ipairs(slots) do
			local m = World.disc(folder, p.X, p.Z, 16, 0.12, 0.12, Config.Team[team].dark:Lerp(Color3.new(1, 1, 1), 0.7))
			m.Name = "SlotMat"
			m.CanTouch = false
			m.CastShadow = false
		end
	end
	task.spawn(function()
		while true do
			task.wait(2)
			for _, b in pairs(bases) do
				if b.player.Parent then
					local ok, err = pcall(refresh, b)
					if not ok then
						warn("[Bases]", err)
					end
				end
			end
		end
	end)
end

return Bases

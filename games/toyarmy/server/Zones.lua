-- Territories: a flag on a bottle cap per zone, its garrison, fights, captures, income and cat swats.
-- Outposts are each team's drill ground: a private practice fight against wind-up toys (always winnable).
-- Clients get zone snapshots ("Zone"), fight streams ("Battle": start/join/volley/end/swat) and draw everything.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local World = require(Shared:WaitForChild("World"))
local Fmt = require(Shared:WaitForChild("Fmt"))
local Toys = require(Shared:WaitForChild("Toys"))
local Data = require(script.Parent:WaitForChild("Data"))
local Battle = require(script.Parent:WaitForChild("Battle"))
local Army = require(script.Parent:WaitForChild("Army"))

local Zones = {}

type Unit = Battle.Unit
type Fight = Battle.Fight

export type ZoneState = {
	def: Config.ZoneDef,
	owner: string?,
	garrison: { Unit },
	fight: Fight?,
	neutralAt: number,
	cloth: BasePart?,
	ring: BasePart?,
	title: TextLabel?,
	status: TextLabel?,
}

local states: { [string]: ZoneState } = {}
local drills: { [Player]: Fight } = {}
local drillReady: { [Player]: number } = {}
local resolvedHooks: { (Fight, string, boolean) -> () } = {}
local rng = Random.new()
local startClock = os.clock()

local promptHandler: ((Player, string) -> ())? = nil

local zoneRemote = Net.event("Zone")
local battleRemote = Net.event("Battle")
local syncFunc = Net.func("Sync")
local toppleRemote = Net.event("Topple")

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local RAD = math.rad

function Zones.onResolved(cb: (Fight, string, boolean) -> ())
	table.insert(resolvedHooks, cb)
end

-- What happens when someone uses a flag's proximity prompt (Main wires it to the same deploy as the HUD button).
function Zones.onPrompt(cb: (Player, string) -> ())
	promptHandler = cb
end

function Zones.get(id: string): ZoneState?
	return states[id]
end

function Zones.all(): { [string]: ZoneState }
	return states
end

function Zones.real(): { ZoneState }
	local out = {}
	for _, def in ipairs(Config.Zones) do
		local zs = states[def.id]
		if zs and not def.outpost then
			table.insert(out, zs)
		end
	end
	return out
end

function Zones.garrisonPower(zs: ZoneState): number
	return Battle.power(zs.garrison)
end

-- Flags ------------------------------------------------------------------------------------------------------

local function buildFlag(zs: ZoneState, parent: Instance)
	local def = zs.def
	local m = World.model("Flag_" .. def.id, parent)
	local p = def.pos
	-- bottle cap with crimped ridges
	local cap = World.cyl(m, p, 2.6, 11, def.cap1, { Name = "Cap", CanTouch = false })
	-- walk up to any flag and press E / tap to send your squad there
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DeployPrompt"
	prompt.ActionText = def.outpost and "Drill!" or "Deploy Squad"
	prompt.ObjectText = def.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 28
	prompt.RequiresLineOfSight = false
	prompt.Parent = cap
	prompt.Triggered:Connect(function(player: Player)
		local h = promptHandler
		if h then
			h(player, def.id)
		end
	end)
	World.disc(m, p.X, p.Z, 4.4, p.Y + 2.62, 0.1, Color3.fromRGB(250, 250, 250))
	for i = 0, 17 do
		local a = i / 18 * math.pi * 2
		local q = p + V(math.cos(a) * 5.55, 1.3, math.sin(a) * 5.55)
		World.part({ Name = "Ridge", CFrame = CFrame.lookAt(q, p + V(0, 1.3, 0)), Size = V(1.1, 2.6, 0.5), Color = def.cap1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Parent = m })
	end
	-- pencil flagpole
	World.cyl(m, p + V(0, 2.6, 0), 15, 1.2, Config.C.yellow, { Name = "Pole", CanTouch = false })
	World.cyl(m, p + V(0, 17.6, 0), 0.9, 1.25, Config.C.grey, { Name = "Band", CanTouch = false, CanQuery = false })
	World.cyl(m, p + V(0, 18.5, 0), 1.4, 1.25, Config.C.pink, { Name = "Eraser", CanTouch = false, CanQuery = false })
	local color = def.outpost and Config.teamColor(def.outpost) or Config.C.wild
	local cloth = World.part({
		Name = "Cloth",
		CFrame = CF(p + V(4, 16, 0)),
		Size = V(7, 4.6, 0.3),
		Color = color,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = m,
	})
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.LightInfluence = 0
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 20
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Text = "★"
		l.TextScaled = true
		l.Font = Enum.Font.GothamBold
		l.TextColor3 = Color3.new(1, 1, 1)
		l.Parent = sg
		sg.Parent = cloth
	end
	zs.cloth = cloth
	-- zone ring on the floor
	local ring = World.disc(m, p.X, p.Z, def.radius, p.Y + 0.75, 0.12, color)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.72
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Name = "ZoneRing"
	zs.ring = ring
	if def.outpost then
		-- sandbag ring in team colour
		for i = 0, 9 do
			local a = i / 10 * math.pi * 2 + 0.3
			if i ~= 2 and i ~= 3 then
				local q = p + V(math.cos(a) * (def.radius + 2), 1.6, math.sin(a) * (def.radius + 2))
				World.part({ Name = "Sandbag", Shape = Enum.PartType.Ball, CFrame = CFrame.lookAt(q, p + V(0, 1.6, 0)), Size = V(7, 3.4, 4), Color = Config.Team[def.outpost].dark, CanTouch = false, CanQuery = false, CastShadow = false, Parent = m })
			end
		end
	end
	-- label
	local bb = Instance.new("BillboardGui")
	bb.Name = "ZoneLabel"
	bb.Size = UDim2.fromScale(22, 6.5)
	bb.StudsOffsetWorldSpace = V(0, 25, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 230
	bb.LightInfluence = 0
	bb.Adornee = cloth
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.55)
	title.Font = Enum.Font.LuckiestGuy
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = def.glyph .. " " .. string.upper(def.name)
	local s1 = Instance.new("UIStroke")
	s1.Thickness = 3
	s1.Color = Config.C.ink
	s1.Parent = title
	title.Parent = bb
	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromScale(0, 0.56)
	status.Size = UDim2.fromScale(1, 0.4)
	status.Font = Enum.Font.FredokaOne
	status.TextScaled = true
	status.TextColor3 = color
	status.Text = def.outpost and "DRILL GROUND" or "NEUTRAL"
	local s2 = Instance.new("UIStroke")
	s2.Thickness = 2.5
	s2.Color = Config.C.ink
	s2.Parent = status
	status.Parent = bb
	bb.Parent = cloth
	zs.title = title
	zs.status = status
	m:SetAttribute("Zone", def.id)
end

-- Snapshots and labels -------------------------------------------------------------------------------------

local function snapshot(zs: ZoneState): { [string]: any }
	local units = Battle.pack(zs.garrison)
	table.sort(units, function(a: { any }, b: { any })
		return (a[7] :: number) > (b[7] :: number)
	end)
	return {
		owner = zs.owner or "",
		units = units,
		fight = zs.fight ~= nil,
		power = math.floor(Battle.power(zs.garrison)),
	}
end

local function refreshLabel(zs: ZoneState)
	local def = zs.def
	if def.outpost then
		return
	end
	local color = Config.teamColor(zs.owner)
	if zs.cloth then
		zs.cloth.Color = color
	end
	if zs.ring then
		zs.ring.Color = color
	end
	local status = zs.status
	if status then
		local n = 0
		for _, u in ipairs(zs.garrison) do
			if not u.gone then
				n += 1
			end
		end
		if zs.fight then
			status.Text = "⚔️ BATTLE! ⚔️"
			status.TextColor3 = Config.C.orange
		elseif zs.owner then
			status.Text = Config.Team[zs.owner].short .. " · 💪 " .. Fmt.num(Battle.power(zs.garrison)) .. " · " .. n .. " 🪖"
			status.TextColor3 = color
		elseif n > 0 then
			status.Text = "WIND-UP TOYS · 💪 " .. Fmt.num(Battle.power(zs.garrison))
			status.TextColor3 = Config.C.wild
		else
			status.Text = "NEUTRAL · FREE TO TAKE!"
			status.TextColor3 = Color3.new(1, 1, 1)
		end
	end
end

local function publishCounts()
	local g, t = 0, 0
	for _, zs in ipairs(Zones.real()) do
		if zs.owner == "Green" then
			g += 1
		elseif zs.owner == "Tan" then
			t += 1
		end
	end
	workspace:SetAttribute("ZonesGreen", g)
	workspace:SetAttribute("ZonesTan", t)
end

function Zones.publish(zs: ZoneState)
	refreshLabel(zs)
	zoneRemote:FireAllClients(zs.def.id, snapshot(zs))
	publishCounts()
end

function Zones.count(team: string): number
	local n = 0
	for _, zs in ipairs(Zones.real()) do
		if zs.owner == team then
			n += 1
		end
	end
	return n
end

-- Fights -------------------------------------------------------------------------------------------------

local function send(f: Fight, ...: any)
	if f.drill then
		if f.drill.Parent then
			battleRemote:FireClient(f.drill, ...)
		end
	else
		battleRemote:FireAllClients(...)
	end
end

local function markTanks(f: Fight, player: Player, squad: { Unit })
	for _, u in ipairs(squad) do
		if (Config.UnitIndex[u.unit] or 1) >= (Config.UnitIndex.Tank or 4) then
			f.usedTank[player] = true
		end
	end
end

local function rewardPlayer(player: Player, kind: string, def: Config.ZoneDef, f: Fight)
	local d = Data.get(player)
	if not d or not player.Parent then
		return
	end
	local rank = Army.rank(d)
	local pos = def.pos + V(0, 8, 0)
	d.stats.battles = (d.stats.battles or 0) + 1
	if kind == "capture" then
		Army.addPlastic(player, d, def.reward * Config.rankReward(rank), { pos = pos, kind = "capture" })
		Army.addTokens(player, d, "Basic", 1, pos)
		Army.addXp(player, d, Config.Xp.capturePerTier * def.tier)
		d.stats.captures = (d.stats.captures or 0) + 1
		d.stats.wins = (d.stats.wins or 0) + 1
	elseif kind == "defend" then
		Army.addPlastic(player, d, def.reward * 0.4 * Config.rankReward(rank), { pos = pos, kind = "defend" })
		Army.addXp(player, d, Config.Xp.defend)
		d.stats.defends = (d.stats.defends or 0) + 1
		d.stats.wins = (d.stats.wins or 0) + 1
	elseif kind == "drill" then
		Army.addPlastic(player, d, def.reward * Config.rankReward(rank), { pos = pos, kind = "drill" })
		Army.addXp(player, d, Config.Xp.drill)
		if (d.stats.drills or 0) == 0 then
			Army.addTokens(player, d, "Basic", 1, pos)
		end
		d.stats.drills = (d.stats.drills or 0) + 1
		d.stats.wins = (d.stats.wins or 0) + 1
	else
		Army.addXp(player, d, Config.Xp.lose)
	end
	Data.dirty(player)
end

local function resolve(f: Fight, winner: string)
	local def = Config.ZoneById[f.zoneId]
	-- knocked-over units go home to recover
	for _, list in ipairs({ f.att, f.def }) do
		for _, u in ipairs(list) do
			if u.hp <= 0 and u.kind == "P" and u.owner and not u.gone then
				Army.release(u.owner, u.stack, true)
			end
		end
	end
	if f.drill then
		local player = f.drill
		drills[player] = nil
		drillReady[player] = os.clock() + Config.DrillCooldown
		for _, u in ipairs(f.att) do
			if u.hp > 0 and u.kind == "P" and u.owner and not u.gone then
				Army.release(u.owner, u.stack, false)
			end
		end
		send(f, "end", f.key, winner, winner == f.attTeam)
		rewardPlayer(player, winner == f.attTeam and "drill" or "lose", def, f)
		for _, cb in ipairs(resolvedHooks) do
			task.spawn(cb, f, winner, winner == f.attTeam)
		end
		return
	end
	local zs = states[f.zoneId]
	zs.fight = nil
	local captured = winner == f.attTeam
	local keep: { Unit } = Battle.alive(captured and f.att or f.def)
	local goHome: { Unit } = Battle.alive(captured and f.def or f.att)
	if captured then
		zs.owner = f.attTeam
	end
	table.sort(keep, function(a: Unit, b: Unit)
		return a.power > b.power
	end)
	local garrison: { Unit } = {}
	for i, u in ipairs(keep) do
		if i <= def.cap and not (u.kind == "P" and (not u.owner or not (u.owner :: Player).Parent)) then
			u.hp = u.maxHp
			table.insert(garrison, u)
		else
			table.insert(goHome, u)
		end
	end
	for _, u in ipairs(goHome) do
		if u.kind == "P" and u.owner and not u.gone then
			Army.release(u.owner, u.stack, false)
		end
	end
	zs.garrison = garrison
	if #garrison == 0 and not captured and (zs.owner == nil) then
		zs.neutralAt = os.clock()
	end
	if captured and #garrison == 0 then
		-- attackers won with nobody left standing (timeout edge): the flag stays theirs but undefended
		zs.neutralAt = os.clock()
	end
	send(f, "end", f.key, winner, captured)
	Zones.publish(zs)
	for player, side in pairs(f.participants) do
		local won = (side == "att" and captured) or (side == "def" and not captured)
		rewardPlayer(player, won and (side == "att" and "capture" or "defend") or "lose", def, f)
	end
	if captured then
		local by = ""
		for player, side in pairs(f.participants) do
			if side == "att" then
				by = by == "" and player.DisplayName or by .. " & " .. player.DisplayName
			end
		end
		if by == "" then
			by = Config.Team[f.attTeam] and Config.Team[f.attTeam].ai or "Someone"
		end
		Army.feed("🚩 " .. by .. " captured " .. def.name .. " for the " .. (Config.Team[f.attTeam] and Config.Team[f.attTeam].name or f.attTeam) .. "!", f.attTeam == "Green" and "green" or "orange")
		if def.id == "tower" then
			toppleRemote:FireAllClients()
		end
	end
	for _, cb in ipairs(resolvedHooks) do
		task.spawn(cb, f, winner, captured)
	end
end

local function run(f: Fight)
	task.wait(1.3) -- attackers hop in
	local winner: string? = nil
	while not f.cancelled do
		local events, w = Battle.step(f, rng)
		if f.cancelled then
			return
		end
		send(f, "volley", f.key, events)
		if w then
			winner = w
			break
		end
		task.wait(Config.Volley)
	end
	if f.cancelled or not winner then
		return
	end
	task.wait(0.5)
	if not f.cancelled then
		resolve(f, winner)
	end
end

local function newFight(key: string, zoneId: string, attTeam: string, defTeam: string, att: { Unit }, def: { Unit }): Fight
	return {
		key = key,
		zoneId = zoneId,
		attTeam = attTeam,
		defTeam = defTeam,
		att = att,
		def = def,
		volley = 0,
		drill = nil,
		cancelled = false,
		participants = {},
		usedTank = {},
	}
end

local function startFight(zs: ZoneState, attTeam: string, squad: { Unit }, player: Player?)
	local f = newFight(zs.def.id, zs.def.id, attTeam, zs.owner or "Wild", squad, zs.garrison)
	for _, u in ipairs(zs.garrison) do
		local o = u.owner
		if u.kind == "P" and o and o.Parent then
			f.participants[o] = "def"
		end
	end
	if player then
		f.participants[player] = "att"
		markTanks(f, player, squad)
	end
	zs.fight = f
	Zones.publish(zs)
	send(f, "start", f.key, { zone = zs.def.id, att = Battle.pack(f.att), def = Battle.pack(f.def), attTeam = attTeam, defTeam = f.defTeam })
	task.spawn(run, f)
end

-- Player actions ------------------------------------------------------------------------------------------------

function Zones.drill(player: Player, def: Config.ZoneDef): (boolean, string?)
	local d = Data.get(player)
	if not d then
		return false, nil
	end
	if drills[player] then
		return false, "Your drill is still going!"
	end
	local ready = drillReady[player] or 0
	if ready > os.clock() then
		return false, "Drill again in " .. math.ceil(ready - os.clock()) .. "s"
	end
	local squad = Army.pickSquad(player, Army.squadSize(player, d))
	if #squad == 0 then
		return false, "No soldiers ready! Open a bag 🎒"
	end
	local budget = math.max(25, Battle.power(squad) * 0.5)
	local wild = Battle.compose(budget, math.clamp(#squad, 2, 5), "WILD", "Wild", "Wind-Up Toys", 1)
	local f = newFight("drill:" .. player.UserId, def.id, (player:GetAttribute("Side") :: string?) or "Green", "Wild", squad, wild)
	f.drill = player
	f.participants[player] = "att"
	markTanks(f, player, squad)
	drills[player] = f
	send(f, "start", f.key, { zone = def.id, att = Battle.pack(f.att), def = Battle.pack(f.def), attTeam = f.attTeam, defTeam = "Wild" })
	task.spawn(run, f)
	return true, "drill"
end

-- Deploy the player's strongest ready squad to a zone: attack, join a fight, reinforce, or drill at the outpost.
function Zones.deploy(player: Player, zoneId: string): (boolean, string?, Fight?)
	local d = Data.get(player)
	local def = Config.ZoneById[zoneId]
	local team = player:GetAttribute("Side") :: string?
	if not d or not def or not team then
		return false, nil, nil
	end
	if def.outpost then
		if def.outpost ~= team then
			return false, "That's the enemy outpost!", nil
		end
		local ok, why = Zones.drill(player, def)
		return ok, why, drills[player]
	end
	local zs = states[zoneId]
	local size = Army.squadSize(player, d)
	local f = zs.fight
	if f then
		local side = (team == f.attTeam) and "att" or (team == f.defTeam) and "def" or nil
		if not side then
			return false, "Battle in progress!", nil
		end
		local list = side == "att" and f.att or f.def
		local room = math.max(0, def.cap + 4 - #Battle.alive(list))
		local squad = Army.pickSquad(player, math.min(size, room))
		if #squad == 0 then
			return false, room == 0 and "Too crowded! Wait for the battle." or "No soldiers ready! Open a bag 🎒", nil
		end
		for _, u in ipairs(squad) do
			table.insert(list, u)
		end
		f.participants[player] = f.participants[player] or side
		markTanks(f, player, squad)
		send(f, "join", f.key, side, Battle.pack(squad))
		return true, "join", f
	end
	if zs.owner == team then
		local room = def.cap - #zs.garrison
		if room <= 0 then
			return false, def.name .. " is fully guarded!", nil
		end
		local squad = Army.pickSquad(player, math.min(size, room))
		if #squad == 0 then
			return false, "No soldiers ready! Open a bag 🎒", nil
		end
		for _, u in ipairs(squad) do
			table.insert(zs.garrison, u)
		end
		Zones.publish(zs)
		return true, "reinforce", nil
	end
	local squad = Army.pickSquad(player, size)
	if #squad == 0 then
		return false, "No soldiers ready! Open a bag 🎒", nil
	end
	startFight(zs, team, squad, player)
	Army.feed("⚔️ " .. player.DisplayName .. " attacks " .. def.name .. "!", team == "Green" and "green" or "orange")
	return true, "attack", zs.fight
end

-- Bring this player's soldiers home from a zone they hold.
function Zones.recall(player: Player, zoneId: string): boolean
	local zs = states[zoneId]
	if not zs or zs.fight then
		return false
	end
	local kept = {}
	local n = 0
	for _, u in ipairs(zs.garrison) do
		if u.owner == player then
			Army.release(player, u.stack, false)
			n += 1
		else
			table.insert(kept, u)
		end
	end
	if n > 0 then
		zs.garrison = kept
		if #kept == 0 then
			zs.neutralAt = os.clock()
		end
		Zones.publish(zs)
	end
	return n > 0
end

-- The AI commander deploys virtual units the same way.
function Zones.deployAI(team: string, zoneId: string, squad: { Unit }): boolean
	local zs = states[zoneId]
	if not zs or zs.def.outpost or #squad == 0 then
		return false
	end
	local f = zs.fight
	if f then
		local list = (team == f.attTeam) and f.att or (team == f.defTeam) and f.def or nil
		if not list then
			return false
		end
		for _, u in ipairs(squad) do
			table.insert(list, u)
		end
		send(f, "join", f.key, list == f.att and "att" or "def", Battle.pack(squad))
		return true
	end
	if zs.owner == team then
		for i, u in ipairs(squad) do
			if #zs.garrison < zs.def.cap then
				table.insert(zs.garrison, u)
			end
			if i > zs.def.cap then
				break
			end
		end
		Zones.publish(zs)
		return true
	end
	startFight(zs, team, squad, nil)
	return true
end

-- The cat swats a zone: every toy there flies, the flag goes neutral. Returns how many toys went flying.
function Zones.swat(zoneId: string): number
	local zs = states[zoneId]
	if not zs then
		return 0
	end
	local n = 0
	local f = zs.fight
	if f then
		f.cancelled = true
		zs.fight = nil
		for _, list in ipairs({ f.att, f.def }) do
			for _, u in ipairs(list) do
				if u.kind == "P" and u.owner and not u.gone and u.hp > 0 then
					Army.release(u.owner, u.stack, true)
					local d = Data.get(u.owner)
					if d then
						d.stats.swats = (d.stats.swats or 0) + 1
					end
				end
				if u.hp > 0 and not u.gone then
					n += 1
				end
			end
		end
		send(f, "end", f.key, "Cat", false)
	else
		for _, u in ipairs(zs.garrison) do
			if u.kind == "P" and u.owner and not u.gone then
				Army.release(u.owner, u.stack, true)
				local d = Data.get(u.owner)
				if d then
					d.stats.swats = (d.stats.swats or 0) + 1
				end
			end
			n += 1
		end
	end
	zs.garrison = {}
	zs.owner = nil
	zs.neutralAt = os.clock()
	battleRemote:FireAllClients("swat", zoneId)
	Zones.publish(zs)
	return n
end

function Zones.setOwner(zoneId: string, team: string?)
	local zs = states[zoneId]
	if not zs or zs.fight then
		return
	end
	for _, u in ipairs(zs.garrison) do
		if u.kind == "P" and u.owner then
			Army.release(u.owner, u.stack, false)
		end
	end
	zs.owner = team
	zs.garrison = {}
	if team then
		local squad = Battle.compose(zs.def.wild, 4, "AI", team, Config.Team[team].ai, 1)
		zs.garrison = squad
	end
	zs.neutralAt = os.clock()
	Zones.publish(zs)
end

-- A player left: take their soldiers out of every zone and fight.
function Zones.removePlayer(player: Player)
	local f = drills[player]
	if f then
		f.cancelled = true
		drills[player] = nil
	end
	drillReady[player] = nil
	for _, zs in pairs(states) do
		local changed = false
		local fight = zs.fight
		if fight then
			for _, list in ipairs({ fight.att, fight.def }) do
				for _, u in ipairs(list) do
					if u.owner == player then
						u.gone = true
						u.hp = 0
					end
				end
			end
			fight.participants[player] = nil
		end
		local kept = {}
		for _, u in ipairs(zs.garrison) do
			if u.owner == player then
				changed = true
			else
				table.insert(kept, u)
			end
		end
		if changed then
			zs.garrison = kept
			if not zs.fight then
				Zones.publish(zs)
			end
		end
	end
end

-- Units this player has in each zone: { zoneId = count }
function Zones.playerUnits(player: Player): { [string]: number }
	local out = {}
	for id, zs in pairs(states) do
		local n = 0
		for _, u in ipairs(zs.garrison) do
			if u.owner == player then
				n += 1
			end
		end
		if n > 0 then
			out[id] = n
		end
	end
	return out
end

function Zones.drillReadyIn(player: Player): number
	if drills[player] then
		return 99
	end
	return math.max(0, (drillReady[player] or 0) - os.clock())
end

-- Loops ---------------------------------------------------------------------------------------------------------

-- Neutral, empty zones get wind-up toys back after a while (stronger the longer the server runs).
local function regenWild()
	local minutes = (os.clock() - startClock) / 60
	local scale = math.min(3, 1 + minutes * 0.05)
	for _, zs in ipairs(Zones.real()) do
		if not zs.owner and not zs.fight and #zs.garrison == 0 and os.clock() - zs.neutralAt > 20 then
			zs.garrison = Battle.compose(zs.def.wild * scale, 4, "WILD", "Wild", "Wind-Up Toys", 1)
			Zones.publish(zs)
		end
	end
end

-- Pay zone income to the owning team: full share to players with soldiers there, a smaller share to the rest.
function Zones.payIncome(extra: (Player, { [string]: any }) -> number)
	local totals: { [Player]: number } = {}
	for _, zs in ipairs(Zones.real()) do
		local team = zs.owner
		if team and not zs.fight then
			local contributors: { [Player]: boolean } = {}
			for _, u in ipairs(zs.garrison) do
				if u.owner then
					contributors[u.owner] = true
				end
			end
			for _, p in ipairs(Army.teamPlayers(team)) do
				local d = Data.get(p)
				if d then
					local share = zs.def.income * (contributors[p] and 1 or Config.TeamShare) * Config.rankReward(Army.rank(d))
					totals[p] = (totals[p] or 0) + share
				end
			end
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		local d = Data.get(p)
		if d then
			local amount = (totals[p] or 0) + extra(p, d)
			if amount > 0 then
				Army.addPlastic(p, d, amount, { kind = "income" })
			end
		end
	end
end

function Zones.init(parent: Instance)
	local f = World.folder("Zones", parent)
	for _, def in ipairs(Config.Zones) do
		local zs: ZoneState = {
			def = def,
			owner = nil,
			garrison = {},
			fight = nil,
			neutralAt = -100,
			cloth = nil,
			ring = nil,
			title = nil,
			status = nil,
		}
		states[def.id] = zs
		buildFlag(zs, f)
		refreshLabel(zs)
	end
	regenWild()
	publishCounts()
	syncFunc.OnServerInvoke = function(_player)
		local out = {}
		for id, zs in pairs(states) do
			if not zs.def.outpost then
				out[id] = snapshot(zs)
			end
		end
		return out
	end
	task.spawn(function()
		while true do
			task.wait(2)
			regenWild()
		end
	end)
end

-- Silence "unused" for helpers some builds do not need.
local _ = { Toys, ANG, RAD }

return Zones

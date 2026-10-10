-- Services and the world for the simulator: DataModel, Players and characters, RunService, Workspace queries,
-- DataStores, Marketplace, CollectionService, TweenService and friends, plus the per-frame physics (character
-- movement, touches, simple movers) and the script runner (require, server/client environments).
local R = ...
local G = R.G
local S = R.STATE
local v3, v2, cf, c3 = R.v3, R.v2, R.cf, R.c3
local B = R.behavior
local IDENT = R.CF_IDENTITY
local nativeType = type

R.stats = { remoteIn = 0, remoteOut = 0, sounds = 0, dataGets = 0, dataSets = 0, purchases = 0 }

---------------------------------------------------------------------------------------------------- DataModel
local game = R.create("DataModel")
S[game].props.Name = "Game"
R.game = game
G.game = game
G.Game = game

local function service(className, name)
	local s = S[game]
	for _, c in ipairs(s.children) do
		if S[c].ClassName == className then
			return c
		end
	end
	local inst = R.create(className)
	local is = S[inst]
	is.props.Name = name or className
	R.setParent(inst, game)
	is.isService = true
	return inst
end
R.service = service

local DM = B("DataModel")
DM.m.GetService = function(self, name)
	if self ~= game then
		error("Expected ':' not '.' calling member function GetService", 2)
	end
	local data = R.API.classes[name]
	if not data or not data.svc then
		error("'" .. tostring(name) .. "' is not a valid Service name", 2)
	end
	return service(name)
end
DM.m.FindService = function(self, name)
	for _, c in ipairs(S[game].children) do
		if S[c].ClassName == name then
			return c
		end
	end
	return nil
end
DM.m.getService = DM.m.GetService
DM.m.BindToClose = function(self, fn)
	if nativeType(fn) ~= "function" then
		error("BindToClose expects a function", 2)
	end
	R.closeHandlers = R.closeHandlers or {}
	table.insert(R.closeHandlers, { fn = fn, ctx = R.CUR })
end
DM.m.IsLoaded = function()
	return true
end
DM.get.PlaceId = function()
	return 0
end
DM.get.GameId = function()
	return 0
end
DM.get.JobId = function()
	return ""
end
DM.get.CreatorId = function()
	return 0
end
DM.get.PlaceVersion = function()
	return 0
end
DM.get.PrivateServerId = function()
	return ""
end
DM.get.PrivateServerOwnerId = function()
	return 0
end

local workspace = service("Workspace")
R.workspace = workspace
G.workspace = workspace
G.Workspace = workspace
local terrain = R.create("Terrain")
S[terrain].props.Name = "Terrain"
R.setParent(terrain, workspace)
local camera = R.create("Camera")
S[camera].props.Name = "Camera"
R.setParent(camera, workspace)
S[workspace].props.CurrentCamera = camera

for _, n in ipairs({ "Players", "Lighting", "ReplicatedStorage", "ReplicatedFirst", "ServerScriptService", "ServerStorage", "StarterGui", "StarterPack", "StarterPlayer", "SoundService", "Teams", "MaterialService", "Chat", "TextChatService", "RunService", "TweenService", "CollectionService", "Debris", "HttpService", "DataStoreService", "MarketplaceService", "UserInputService", "ContextActionService", "GuiService", "TextService", "PhysicsService", "PathfindingService", "ProximityPromptService", "LocalizationService", "PolicyService", "BadgeService", "SocialService", "TeleportService", "MessagingService", "MemoryStoreService", "AssetService", "InsertService", "ContentProvider", "GroupService", "VRService", "HapticService", "Stats", "AvatarEditorService", "VoiceChatService", "AnalyticsService" }) do
	pcall(service, n)
end
local players = service("Players")
local starterPlayer = service("StarterPlayer")
local sps = R.create("StarterPlayerScripts")
S[sps].props.Name = "StarterPlayerScripts"
R.setParent(sps, starterPlayer)
local scs = R.create("StarterCharacterScripts")
S[scs].props.Name = "StarterCharacterScripts"
R.setParent(scs, starterPlayer)

G.settings = function()
	return setmetatable({}, { __index = function(_, k)
		return setmetatable({}, { __index = function()
			return 0
		end })
	end })
end
G.UserSettings = function()
	local gs = { SavedQualityLevel = R.enumItem("SavedQualitySetting", "Automatic"), MasterVolume = 1 }
	return { GetService = function()
		return setmetatable(gs, { __index = function()
			return function() end
		end })
	end }
end
G.version = function()
	return "0.700.0.0"
end
G.printidentity = function() end
G.stats = function()
	return service("Stats")
end
G.shared = {}
G.plugin = nil

---------------------------------------------------------------------------------------------------- RunService
local RS = B("RunService")
RS.events.Heartbeat = { immediate = true }
RS.events.Stepped = { immediate = true }
RS.events.PreSimulation = { immediate = true }
RS.events.PostSimulation = { immediate = true }
RS.events.PreAnimation = { immediate = true }
RS.events.PreRender = { immediate = true, only = "client" }
RS.events.RenderStepped = { immediate = true, only = "client" }
RS.m.IsServer = function()
	return R.CUR ~= nil and R.CUR.name == "server"
end
RS.m.IsClient = function()
	return R.CUR ~= nil and R.CUR.name == "client"
end
RS.m.IsStudio = function()
	return R.IS_STUDIO
end
RS.m.IsRunning = function()
	return true
end
RS.m.IsRunMode = function()
	return false
end
RS.m.IsEdit = function()
	return false
end
R.renderBinds = {}
RS.m.BindToRenderStep = function(self, name, priority, fn)
	if not R.CUR or R.CUR.name ~= "client" then
		error("BindToRenderStep can only be called from the client", 2)
	end
	R.renderBinds[name] = { fn = fn, ctx = R.CUR, priority = priority }
end
RS.m.UnbindFromRenderStep = function(self, name)
	R.renderBinds[name] = nil
end
local runService = service("RunService")
R.IS_STUDIO = true

---------------------------------------------------------------------------------------------------- Players, characters
local PL = B("Players")
PL.get.LocalPlayer = function()
	if R.CUR and R.CUR.name == "client" then
		return R.CLIENT and R.CLIENT.player
	end
	return nil
end
PL.m.GetPlayers = function(self)
	local out = {}
	for _, c in ipairs(S[players].children) do
		if S[c].ClassName == "Player" then
			table.insert(out, c)
		end
	end
	return out
end
PL.m.getPlayers = PL.m.GetPlayers
function R.playerList()
	return PL.m.GetPlayers(players)
end
PL.m.GetPlayerFromCharacter = function(self, ch)
	if ch == nil then
		return nil
	end
	for _, p in ipairs(R.playerList()) do
		if S[p].props.Character == ch then
			return p
		end
	end
	return nil
end
PL.m.GetPlayerByUserId = function(self, id)
	for _, p in ipairs(R.playerList()) do
		if S[p].props.UserId == id then
			return p
		end
	end
	return nil
end
PL.m.GetUserThumbnailAsync = function(self, id, t, size)
	R.sleep(0.05)
	return "rbxthumb://type=AvatarHeadShot&id=" .. tostring(id) .. "&w=150&h=150", true
end
PL.m.GetNameFromUserIdAsync = function(self, id)
	return "User" .. tostring(id)
end
PL.m.GetUserIdFromNameAsync = function()
	return 1
end
PL.m.GetHumanoidDescriptionFromUserId = function()
	return R.create("HumanoidDescription")
end
PL.m.GetHumanoidDescriptionFromOutfitId = PL.m.GetHumanoidDescriptionFromUserId
PL.m.GetCharacterAppearanceInfoAsync = function()
	return { assets = {}, bodyColors = {}, scales = {} }
end
PL.m.GetFriendsAsync = function()
	return { GetCurrentPage = function()
		return {}
	end, IsFinished = true, AdvanceToNextPageAsync = function() end }
end
PL.m.CreateHumanoidModelFromDescription = function(self, desc, rigType)
	return R.buildCharacter("NPC")
end
PL.m.CreateHumanoidModelFromUserId = function()
	return R.buildCharacter("NPC")
end
PL.m.BanAsync = function() end
PL.m.Chat = function() end

local P = B("Player")
P.m.GetMouse = function(self)
	local s = S[self]
	if not s.mouse then
		local m = R.create("PlayerMouse")
		S[m].props.Name = "Mouse"
		s.mouse = m
	end
	return s.mouse
end
local MOUSE = B("Mouse")
MOUSE.get.Hit = function()
	return cf(0, 0, -20, 1, 0, 0, 0, 1, 0, 0, 0, 1)
end
MOUSE.get.Origin = function()
	return R.rawGet(camera, "CFrame")
end
MOUSE.get.Target = function()
	return nil
end
MOUSE.get.UnitRay = function()
	return G.Ray.new(v3(0, 0, 0), v3(0, 0, -1))
end
MOUSE.get.ViewSizeX = function()
	return R.SCREEN.X
end
MOUSE.get.ViewSizeY = function()
	return R.SCREEN.Y
end
MOUSE.get.X = function()
	return 640
end
MOUSE.get.Y = function()
	return 360
end
P.m.Kick = function(self, msg)
	R.addLog("KICK", S[self].props.Name .. ": " .. tostring(msg))
	R.warn("player kicked: " .. tostring(msg))
	R.removePlayer(self)
end
P.m.IsInGroup = function()
	return false
end
P.m.GetRankInGroup = function()
	return 0
end
P.m.GetRoleInGroup = function()
	return "Guest"
end
P.m.IsFriendsWith = function()
	return false
end
P.m.HasAppearanceLoaded = function()
	return true
end
P.m.GetJoinData = function()
	return {}
end
P.m.GetFriendsOnline = function()
	return {}
end
P.m.GetNetworkPing = function()
	return 0.05
end
P.m.DistanceFromCharacter = function(self, pos)
	local ch = S[self].props.Character
	local hrp = ch and R.rawGetChild(ch, "HumanoidRootPart")
	if not hrp then
		return 0
	end
	return (R.partCF(hrp).Position - pos).Magnitude
end
P.m.RequestStreamAroundAsync = function() end
P.m.LoadCharacter = function(self)
	if R.CUR and R.CUR.name ~= "server" then
		error("LoadCharacter can only be called by the backend server", 2)
	end
	R.loadCharacter(self)
end
P.m.LoadCharacterAsync = P.m.LoadCharacter
P.m.ClearCharacterAppearance = function() end
P.m.SetSuperSafeChat = function() end
P.get.Character = function(inst, s)
	return s.props.Character
end

function R.rawGetChild(inst, name)
	for _, c in ipairs(S[inst].children) do
		if S[c].props.Name == name then
			return c
		end
	end
	return nil
end

local function mkPart(name, size, parent, cframe, transparency)
	local p = R.create("Part")
	local s = S[p]
	s.props.Name = name
	s.props.Size = size
	s.props.CFrame = cframe
	s.props.Transparency = transparency or 0
	s.props.Color = c3(0.96, 0.8, 0.6)
	R.setParent(p, parent)
	return p
end

function R.buildCharacter(name)
	local ch = R.create("Model")
	S[ch].props.Name = name
	local root = mkPart("HumanoidRootPart", v3(2, 2, 1), ch, IDENT, 1)
	local parts = {
		{ "Head", v3(1.2, 1.2, 1.2), v3(0, 1.75, 0) },
		{ "UpperTorso", v3(2, 1.4, 1), v3(0, 0.3, 0) },
		{ "LowerTorso", v3(2, 0.6, 1), v3(0, -0.7, 0) },
		{ "LeftFoot", v3(1, 0.4, 1), v3(-0.5, -2.8, 0) },
		{ "RightFoot", v3(1, 0.4, 1), v3(0.5, -2.8, 0) },
		{ "LeftHand", v3(0.6, 0.6, 0.6), v3(-1.4, -0.8, 0) },
		{ "RightHand", v3(0.6, 0.6, 0.6), v3(1.4, -0.8, 0) },
	}
	for _, d in ipairs(parts) do
		local p = mkPart(d[1], d[2], ch, cf(d[3].X, d[3].Y, d[3].Z, 1, 0, 0, 0, 1, 0, 0, 0, 1))
		local w = R.create("Motor6D")
		local ws = S[w]
		ws.props.Name = "Root" .. d[1]
		ws.props.Part0 = root
		ws.props.Part1 = p
		ws.props.C0 = cf(d[3].X, d[3].Y, d[3].Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
		ws.props.C1 = IDENT
		R.setParent(w, p)
		R.updateJoint(w)
	end
	local h = R.create("Humanoid")
	S[h].props.Name = "Humanoid"
	R.setParent(h, ch)
	local animator = R.create("Animator")
	S[animator].props.Name = "Animator"
	R.setParent(animator, h)
	S[ch].props.PrimaryPart = root
	return ch
end

local function spawnCFrame(player)
	local s = S[player]
	local spawnPart = s.props.RespawnLocation
	if not spawnPart then
		local best
		for p in pairs(R.WSPARTS) do
			if S[p].ClassName == "SpawnLocation" and R.rawGet(p, "Enabled") ~= false then
				best = best or p
				if R.rawGet(p, "Neutral") ~= false then
					best = p
					break
				end
			end
		end
		spawnPart = best
	end
	if spawnPart then
		local c = R.partCF(spawnPart)
		local sz = R.rawGet(spawnPart, "Size")
		return cf(c.X, c.Y + sz.Y / 2 + 3, c.Z, c.R00, c.R01, c.R02, c.R10, c.R11, c.R12, c.R20, c.R21, c.R22), true
	end
	return cf(0, 10, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), false
end

function R.loadCharacter(player)
	local s = S[player]
	local old = s.props.Character
	if old then
		R.fire(R.getSignal(s, "CharacterRemoving"), old)
		R.destroy(old)
	end
	-- ResetOnSpawn guis are wiped and StarterGui is copied again
	local pg = R.rawGetChild(player, "PlayerGui")
	if pg and s.spawnedOnce then
		for _, g in ipairs(table.clone(S[pg].children)) do
			local gs = S[g]
			if R.classIsA(gs.ClassName, "LayerCollector") and R.rawGet(g, "ResetOnSpawn") ~= false then
				R.addLog("GUI", "ResetOnSpawn removed " .. gs.props.Name .. " on respawn")
				R.stats.guiResets = (R.stats.guiResets or 0) + 1
				R.destroy(g)
			end
		end
	end
	if pg then
		for _, g in ipairs(S[service("StarterGui")].children) do
			if not s.spawnedOnce or R.rawGet(g, "ResetOnSpawn") ~= false then
				local c = R.clone(g, false)
				if c then
					R.setParent(c, pg)
					R.startScriptsIn(c, R.CLIENT and R.CLIENT.player == player and R.CLIENT or nil)
				end
			end
		end
	end
	local ch = R.buildCharacter(s.props.Name)
	local scf, hadSpawn = spawnCFrame(player)
	if not hadSpawn and not s.warnedSpawn then
		s.warnedSpawn = true
		R.warn("no SpawnLocation in Workspace: characters spawn at (0, 10, 0)")
	end
	local hum = R.rawGetChild(ch, "Humanoid")
	local sp = S[starterPlayer].props
	if sp.CharacterWalkSpeed then
		S[hum].props.WalkSpeed = sp.CharacterWalkSpeed
	end
	if sp.CharacterJumpPower then
		S[hum].props.JumpPower = sp.CharacterJumpPower
	end
	s.props.Character = ch
	R.modelPivotTo(ch, scf)
	R.setParent(ch, workspace)
	s.spawnedOnce = true
	R.firePropChanged(player, s, "Character", ch)
	R.fire(R.getSignal(s, "CharacterAdded"), ch)
	R.fire(R.getSignal(s, "CharacterAppearanceLoaded"), ch)
	for _, sc in ipairs(S[scs].children) do
		local c = R.clone(sc, false)
		if c then
			R.setParent(c, ch)
			R.startScriptsIn(c, R.CLIENT and R.CLIENT.player == player and R.CLIENT or nil)
		end
	end
	return ch
end

local userIds = 0
function R.addPlayer(name, withClient)
	userIds += 1
	local p = R.create("Player")
	local s = S[p]
	s.props.Name = name
	s.props.DisplayName = name
	s.props.UserId = userIds
	s.props.MembershipType = R.enumItem("MembershipType", "None")
	s.props.AccountAge = 30
	s.props.LocaleId = "en-us"
	for _, n in ipairs({ "Backpack", "PlayerGui", "StarterGear" }) do
		local c = R.create(n)
		S[c].props.Name = n
		R.setParent(c, p)
	end
	local pscripts = R.create("PlayerScripts")
	S[pscripts].props.Name = "PlayerScripts"
	R.setParent(pscripts, p)
	if withClient then
		R.CLIENT.player = p
	end
	R.setParent(p, players)
	R.fire(R.getSignal(S[players], "PlayerAdded"), p)
	-- client scripts start once the player exists
	if withClient then
		for _, sc in ipairs(S[sps].children) do
			local c = R.clone(sc, false)
			if c then
				R.setParent(c, pscripts)
			end
		end
		for _, sc in ipairs(S[service("ReplicatedFirst")].children) do
			R.startScriptsIn(sc, R.CLIENT)
		end
		R.startScriptsIn(pscripts, R.CLIENT)
	end
	if R.rawGet(players, "CharacterAutoLoads") ~= false then
		R.schedule(R.now + 0.1, R.newThread(function()
			if S[p].parent == players then
				R.loadCharacter(p)
			end
		end, R.SERVER))
	end
	return p
end

function R.removePlayer(p)
	local s = S[p]
	if s.parent ~= players then
		return
	end
	R.fire(R.getSignal(S[players], "PlayerRemoving"), p)
	local ch = s.props.Character
	if ch then
		R.fire(R.getSignal(s, "CharacterRemoving"), ch)
	end
	R.flushDeferred()
	if ch then
		R.destroy(ch)
	end
	R.setParent(p, nil)
	if R.CLIENT and R.CLIENT.player == p then
		R.CLIENT.dead = true
	end
end

-- Humanoid
local H = B("Humanoid")
H.set.Health = function(inst, s, v)
	local maxH = R.rawGet(inst, "MaxHealth")
	v = math.clamp(v, 0, maxH)
	local old = R.rawGet(inst, "Health")
	R.rawSet(inst, "Health", v)
	if old ~= v then
		R.fire(R.getSignal(s, "HealthChanged"), v)
	end
	if v <= 0 and old > 0 and not s.dead then
		s.dead = true
		R.fire(R.getSignal(s, "Died"))
		R.onHumanoidDied(inst)
	end
end
H.m.TakeDamage = function(self, amount)
	local s = S[self]
	if s.parent and R.rawGetChild(s.parent, "ForceField") then
		return
	end
	self.Health = R.rawGet(self, "Health") - amount
end
H.m.MoveTo = function(self, pos, part)
	local s = S[self]
	if R.typeof(pos) ~= "Vector3" then
		error("invalid argument #1 to 'MoveTo' (Vector3 expected)", 2)
	end
	s.moveTarget = pos
	s.moveStart = R.now
end
H.m.Move = function(self, dir)
	S[self].moveDir = dir
end
H.m.ChangeState = function(self, state)
	S[self].state = state
	if state and state.Name == "Dead" then
		self.Health = 0
	end
end
H.m.GetState = function(self)
	return S[self].state or R.enumItem("HumanoidStateType", "Running")
end
H.m.SetStateEnabled = function() end
H.m.GetStateEnabled = function()
	return true
end
H.m.LoadAnimation = function(self, anim)
	return B("Animator").m.LoadAnimation(self, anim)
end
H.m.GetPlayingAnimationTracks = function()
	return {}
end
H.m.ApplyDescription = function() end
H.m.ApplyDescriptionReset = function() end
H.m.GetAppliedDescription = function()
	return R.create("HumanoidDescription")
end
H.m.UnequipTools = function() end
H.m.EquipTool = function(self, tool)
	local ch = S[self].parent
	if ch then
		tool.Parent = ch
	end
end
H.m.AddAccessory = function(self, acc)
	acc.Parent = S[self].parent
end
H.m.RemoveAccessories = function() end
H.m.GetAccessories = function()
	return {}
end
H.m.BuildRigFromAttachments = function() end
H.m.GetLimb = function()
	return R.enumItem("Limb", "Unknown")
end
H.m.GetMoveVelocity = function()
	return v3(0, 0, 0)
end
H.get.RootPart = function(inst, s)
	local ch = s.parent
	return ch and R.rawGetChild(ch, "HumanoidRootPart")
end
H.get.MoveDirection = function(inst, s)
	return s.moveDir or v3(0, 0, 0)
end
H.get.FloorMaterial = function()
	return R.enumItem("Material", "Plastic")
end
H.get.SeatPart = function()
	return nil
end

function R.onHumanoidDied(h)
	local ch = S[h].parent
	if not ch then
		return
	end
	local player = PL.m.GetPlayerFromCharacter(players, ch)
	if player then
		R.stats.deaths = (R.stats.deaths or 0) + 1
		R.addLog("DIED", S[player].props.Name)
		if R.rawGet(players, "CharacterAutoLoads") ~= false then
			local respawn = R.rawGet(players, "RespawnTime") or 5
			R.schedule(R.now + respawn, R.newThread(function()
				if S[player].parent == players and S[player].props.Character == ch then
					R.loadCharacter(player)
				end
			end, R.SERVER))
		end
	end
end

---------------------------------------------------------------------------------------------------- Workspace spatial queries
local function filterOk(p, params)
	if not params then
		return true
	end
	local list = params.FilterDescendantsInstances or {}
	local inList = false
	for _, x in ipairs(list) do
		if p == x or R.isDescendantOf(p, x) then
			inList = true
			break
		end
	end
	local include = params.FilterType and params.FilterType.Name == "Include" or (params.FilterType and params.FilterType.Name == "Whitelist")
	if include then
		return inList
	end
	return not inList
end

local function rayPart(p, o, d)
	local c = R.partCF(p)
	local inv = R.cfInv(c)
	local lo = R.cfPoint(inv, o)
	local ld = R.cfVec(inv, d)
	local sz = R.rawGet(p, "Size")
	local shape = S[p].ClassName == "Part" and R.rawGet(p, "Shape")
	if shape and shape.Name == "Ball" then
		local r = math.min(sz.X, sz.Y, sz.Z) / 2
		local b = lo:Dot(ld)
		local cc = lo:Dot(lo) - r * r
		local a = ld:Dot(ld)
		local disc = b * b - a * cc
		if disc < 0 or a == 0 then
			return nil
		end
		local t = (-b - math.sqrt(disc)) / a
		if t < 0 then
			t = (-b + math.sqrt(disc)) / a
		end
		if t < 0 or t > 1 then
			return nil
		end
		local hit = lo + ld * t
		return t, R.cfVec(c, hit.Unit)
	end
	local h = { sz.X / 2, sz.Y / 2, sz.Z / 2 }
	local oo = { lo.X, lo.Y, lo.Z }
	local dd = { ld.X, ld.Y, ld.Z }
	local tmin, tmax = 0, 1
	local axis, sign = 0, 1
	for i = 1, 3 do
		if math.abs(dd[i]) < 1e-12 then
			if oo[i] < -h[i] or oo[i] > h[i] then
				return nil
			end
		else
			local t1 = (-h[i] - oo[i]) / dd[i]
			local t2 = (h[i] - oo[i]) / dd[i]
			local sgn = -1
			if t1 > t2 then
				t1, t2 = t2, t1
				sgn = 1
			end
			if t1 > tmin then
				tmin = t1
				axis = i
				sign = sgn
			end
			tmax = math.min(tmax, t2)
			if tmin > tmax then
				return nil
			end
		end
	end
	local n = v3(axis == 1 and sign or 0, axis == 2 and sign or 0, axis == 3 and sign or 0)
	return tmin, R.cfVec(c, n)
end

-- Spatial grid (XZ cells) over workspace parts so queries don't scan every part. Parts are re-filed lazily:
-- moves, resizes and reparents only mark them dirty (R.gridMark), the next query re-files them.
local CELL = 24
local cells = {} -- cell key -> { [part] = true }
local partKeys = {} -- part -> { keys } or BIG
local bigParts = {} -- parts spanning too many cells, checked by every query
local BIG = {}
local function cellKey(ix, iz)
	return ix * 131072 + iz
end
local function gridRemove(p)
	local keys = partKeys[p]
	if keys == BIG then
		bigParts[p] = nil
	elseif keys then
		for _, k in ipairs(keys) do
			local c = cells[k]
			if c then
				c[p] = nil
			end
		end
	end
	partKeys[p] = nil
end
local function gridFlush()
	local dirty = R.gridDirty
	if next(dirty) == nil then
		return
	end
	R.gridDirty = {}
	for p in pairs(dirty) do
		gridRemove(p)
		if R.WSPARTS[p] and not S[p].destroyed then
			local a, _, c, d, _, f = R.aabb(p)
			if a ~= a or c ~= c or d ~= d or f ~= f then
				bigParts[p] = true
				partKeys[p] = BIG
			else
				local ix0, iz0, ix1, iz1 = math.floor(a / CELL), math.floor(c / CELL), math.floor(d / CELL), math.floor(f / CELL)
				if (ix1 - ix0 + 1) * (iz1 - iz0 + 1) > 48 then
					bigParts[p] = true
					partKeys[p] = BIG
				else
					local keys = {}
					for ix = ix0, ix1 do
						for iz = iz0, iz1 do
							local k = cellKey(ix, iz)
							local cl = cells[k]
							if not cl then
								cl = {}
								cells[k] = cl
							end
							cl[p] = true
							table.insert(keys, k)
						end
					end
					partKeys[p] = keys
				end
			end
		end
	end
end
-- Parts whose XZ bounds may overlap [x0,x1]x[z0,z1]; nil means "too large an area, scan everything".
local function gridCandidates(x0, z0, x1, z1)
	gridFlush()
	local ix0, iz0, ix1, iz1 = math.floor(x0 / CELL), math.floor(z0 / CELL), math.floor(x1 / CELL), math.floor(z1 / CELL)
	if (ix1 - ix0 + 1) * (iz1 - iz0 + 1) > 64 or ix0 ~= ix0 or iz0 ~= iz0 then
		return nil
	end
	local out = {}
	for p in pairs(bigParts) do
		out[p] = true
	end
	for ix = ix0, ix1 do
		for iz = iz0, iz1 do
			local cl = cells[cellKey(ix, iz)]
			if cl then
				for p in pairs(cl) do
					out[p] = true
				end
			end
		end
	end
	return out
end
R.gridCandidates = gridCandidates

function R.raycast(origin, dir, params)
	local best, bt, bn
	local respectCollide = params and params.RespectCanCollide
	local ex = origin + dir
	local set = gridCandidates(math.min(origin.X, ex.X), math.min(origin.Z, ex.Z), math.max(origin.X, ex.X), math.max(origin.Z, ex.Z)) or R.WSPARTS
	for p in pairs(set) do
		if R.rawGet(p, "CanQuery") ~= false and (not respectCollide or R.rawGet(p, "CanCollide")) and filterOk(p, params) then
			local t, n = rayPart(p, origin, dir)
			if t and (not bt or t < bt) then
				best, bt, bn = p, t, n
			end
		end
	end
	if best then
		return R.raycastResult(best, origin + dir * bt, bn, R.rawGet(best, "Material"), (dir * bt).Magnitude)
	end
	return nil
end

local function aabbOverlap(a0, a1, a2, a3, a4, a5, b0, b1, b2, b3, b4, b5)
	return a0 <= b3 and a3 >= b0 and a1 <= b4 and a4 >= b1 and a2 <= b5 and a5 >= b2
end
function R.partsInBox(x0, y0, z0, x1, y1, z1, params, except)
	local out = {}
	local max = params and params.MaxParts or 0
	for p in pairs(gridCandidates(x0, z0, x1, z1) or R.WSPARTS) do
		if p ~= except and R.rawGet(p, "CanQuery") ~= false and filterOk(p, params) then
			local a, b, c, d, e, f = R.aabb(p)
			if aabbOverlap(a, b, c, d, e, f, x0, y0, z0, x1, y1, z1) then
				table.insert(out, p)
				if max > 0 and #out >= max then
					break
				end
			end
		end
	end
	return out
end
function R.partsOverlapping(part)
	local a, b, c, d, e, f = R.aabb(part)
	return R.partsInBox(a, b, c, d, e, f, nil, part)
end

local WS = B("Workspace")
WS.m.Raycast = function(self, origin, dir, params)
	if R.typeof(origin) ~= "Vector3" or R.typeof(dir) ~= "Vector3" then
		error("Raycast expects Vector3 origin and direction", 2)
	end
	if params ~= nil and R.typeof(params) ~= "RaycastParams" then
		error("invalid argument #3 to 'Raycast' (RaycastParams expected, got " .. R.typeof(params) .. ")", 2)
	end
	return R.raycast(origin, dir, params)
end
WS.m.Spherecast = function(self, origin, radius, dir, params)
	return R.raycast(origin, dir, params)
end
WS.m.Blockcast = function(self, c, size, dir, params)
	return R.raycast(c.Position, dir, params)
end
WS.m.Shapecast = function(self, part, dir, params)
	return R.raycast(R.partCF(part).Position, dir, params)
end
WS.m.GetPartBoundsInRadius = function(self, pos, r, params)
	if params ~= nil and R.typeof(params) ~= "OverlapParams" then
		error("invalid argument #3 to 'GetPartBoundsInRadius' (OverlapParams expected)", 2)
	end
	return R.partsInBox(pos.X - r, pos.Y - r, pos.Z - r, pos.X + r, pos.Y + r, pos.Z + r, params)
end
WS.m.GetPartBoundsInBox = function(self, c, size, params)
	local h = size / 2
	return R.partsInBox(c.X - h.X, c.Y - h.Y, c.Z - h.Z, c.X + h.X, c.Y + h.Y, c.Z + h.Z, params)
end
WS.m.GetPartsInPart = function(self, part, params)
	local a, b, c, d, e, f = R.aabb(part)
	return R.partsInBox(a, b, c, d, e, f, params, part)
end
WS.m.FindPartOnRay = function(self, ray, ignore)
	local params = G.RaycastParams.new()
	if ignore then
		params.FilterDescendantsInstances = { ignore }
	end
	local r = R.raycast(ray.Origin, ray.Direction, params)
	if r then
		return r.Instance, r.Position, r.Normal, r.Material
	end
	return nil, ray.Origin + ray.Direction, v3(0, 1, 0), R.enumItem("Material", "Air")
end
WS.m.FindPartOnRayWithIgnoreList = function(self, ray, list)
	local params = G.RaycastParams.new()
	params.FilterDescendantsInstances = list or {}
	local r = R.raycast(ray.Origin, ray.Direction, params)
	if r then
		return r.Instance, r.Position, r.Normal, r.Material
	end
	return nil, ray.Origin + ray.Direction, v3(0, 1, 0), R.enumItem("Material", "Air")
end
WS.m.GetServerTimeNow = function()
	return R.unixNow()
end
WS.m.GetRealPhysicsFPS = function()
	return 60
end
WS.m.BulkMoveTo = function(self, parts, cframes)
	for i, p in ipairs(parts) do
		R.movePart(p, cframes[i])
	end
end
WS.m.PGSIsEnabled = function()
	return true
end
WS.get.DistributedGameTime = function()
	return R.now
end

-- Terrain: accepted and ignored
local TER = B("Terrain")
for _, m in ipairs({ "FillBlock", "FillBall", "FillCylinder", "FillWedge", "FillRegion", "WriteVoxels", "WriteVoxelChannels", "Clear", "SetMaterialColor", "ReplaceMaterial", "PasteRegion" }) do
	TER.m[m] = function() end
end
TER.m.GetMaterialColor = function()
	return c3(0.5, 0.5, 0.5)
end
TER.m.ReadVoxels = function()
	return {}, {}
end

-- Camera
local CAM = B("Camera")
CAM.get.ViewportSize = function()
	return R.SCREEN
end
CAM.m.WorldToViewportPoint = function(self, p)
	local c = R.rawGet(self, "CFrame")
	local rel = R.cfPoint(R.cfInv(c), p)
	local onScreen = rel.Z < 0
	local f = 360 / math.tan(math.rad((R.rawGet(self, "FieldOfView") or 70) / 2))
	local depth = -rel.Z
	if depth <= 0.01 then
		return v3(640, 360, depth), false
	end
	local x = 640 + rel.X / depth * f
	local y = 360 - rel.Y / depth * f
	return v3(x, y, depth), onScreen and x >= 0 and x <= 1280 and y >= 0 and y <= 720
end
CAM.m.WorldToScreenPoint = CAM.m.WorldToViewportPoint
CAM.m.ViewportPointToRay = function(self, x, y, depth)
	local c = R.rawGet(self, "CFrame")
	return G.Ray.new(c.Position, c.LookVector)
end
CAM.m.ScreenPointToRay = CAM.m.ViewportPointToRay
CAM.m.GetPartsObscuringTarget = function()
	return {}
end
CAM.m.Interpolate = function() end

---------------------------------------------------------------------------------------------------- data stores
R.DATA = R.DATA or {} -- persists across server restarts inside one simulation
R.DATASTORE_MODE = "ok" -- "ok" | "unpublished"

local function checkStorable(v, path, seen)
	local t = nativeType(v)
	if t == "nil" or t == "boolean" or t == "string" then
		return
	end
	if t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then
			error("Cannot store NaN/inf in data store (at " .. path .. ")", 0)
		end
		return
	end
	if t == "table" and (getmetatable(v) == nil) then
		if seen[v] then
			error("Cannot store cyclic table in data store (at " .. path .. ")", 0)
		end
		seen[v] = true
		local n = #v
		local hasStr, hasNum = false, false
		for k, x in pairs(v) do
			if nativeType(k) == "string" then
				hasStr = true
			elseif nativeType(k) == "number" then
				hasNum = true
				if k < 1 or k > n or k % 1 ~= 0 then
					error("Cannot store array with holes / non-sequential number keys in data store (at " .. path .. "[" .. tostring(k) .. "])", 0)
				end
			else
				error("Cannot store table with " .. R.typeof(k) .. " keys in data store (at " .. path .. ")", 0)
			end
			checkStorable(x, path .. "." .. tostring(k), seen)
		end
		if hasStr and hasNum then
			error("Cannot store mixed table (array + dictionary) in data store (at " .. path .. ")", 0)
		end
		seen[v] = nil
		return
	end
	error("Cannot store " .. R.typeof(v) .. " in data store (at " .. path .. ")", 0)
end

local function deep(v)
	if nativeType(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in pairs(v) do
		out[k] = deep(x)
	end
	return out
end
R.deepCopy = deep

local function storeObj(name, scope, ordered)
	local key = (ordered and "O:" or "D:") .. name .. "/" .. (scope or "global")
	R.DATA[key] = R.DATA[key] or {}
	local data = R.DATA[key]
	local inst = R.create(ordered and "OrderedDataStore" or "DataStore")
	S[inst].props.Name = name
	S[inst].store = data
	return inst
end
local function dsGuard()
	if R.DATASTORE_MODE == "unpublished" then
		error("You must publish this place to the web to access DataStore.", 3)
	end
	if not R.CUR or R.CUR.name ~= "server" then
		error("DataStore can't be accessed from client", 3)
	end
	R.sleep(0.05)
end
local DSS = B("DataStoreService")
DSS.m.GetDataStore = function(self, name, scope)
	if R.DATASTORE_MODE == "unpublished" then
		error("You must publish this place to the web to access DataStore.", 2)
	end
	if not R.CUR or R.CUR.name ~= "server" then
		error("DataStore can't be accessed from client", 2)
	end
	return storeObj(name, scope, false)
end
DSS.m.GetGlobalDataStore = function(self)
	return storeObj("__global", nil, false)
end
DSS.m.GetOrderedDataStore = function(self, name, scope)
	if R.DATASTORE_MODE == "unpublished" then
		error("You must publish this place to the web to access DataStore.", 2)
	end
	return storeObj(name, scope, true)
end
DSS.m.GetRequestBudgetForRequestType = function()
	return 100
end
local GDS = B("GlobalDataStore")
GDS.m.GetAsync = function(self, key)
	dsGuard()
	R.stats.dataGets += 1
	return deep(S[self].store[tostring(key)]), nil
end
GDS.m.SetAsync = function(self, key, value)
	dsGuard()
	checkStorable(value, "value", {})
	R.stats.dataSets += 1
	S[self].store[tostring(key)] = deep(value)
	return "v1"
end
GDS.m.UpdateAsync = function(self, key, fn)
	dsGuard()
	if nativeType(fn) ~= "function" then
		error("UpdateAsync expects a function", 2)
	end
	local old = deep(S[self].store[tostring(key)])
	local new = fn(old, nil)
	if new == nil then
		return nil
	end
	checkStorable(new, "value", {})
	R.stats.dataSets += 1
	S[self].store[tostring(key)] = deep(new)
	return deep(new), nil
end
GDS.m.IncrementAsync = function(self, key, delta)
	dsGuard()
	local v = (S[self].store[tostring(key)] or 0) + (delta or 1)
	S[self].store[tostring(key)] = v
	return v
end
GDS.m.RemoveAsync = function(self, key)
	dsGuard()
	local v = S[self].store[tostring(key)]
	S[self].store[tostring(key)] = nil
	return v
end
local ODS = B("OrderedDataStore")
ODS.m.GetSortedAsync = function(self, ascending, pageSize, minV, maxV)
	dsGuard()
	local items = {}
	for k, v in pairs(S[self].store) do
		if nativeType(v) ~= "number" then
			error("OrderedDataStore values must be integers", 2)
		end
		table.insert(items, { key = k, value = v })
	end
	table.sort(items, function(a, b)
		if ascending then
			return a.value < b.value
		end
		return a.value > b.value
	end)
	local page = {}
	for i = 1, math.min(#items, pageSize or 50) do
		page[i] = items[i]
	end
	local pages = R.create("DataStorePages")
	S[pages].extra = { page = page }
	return pages
end
ODS.m.SetAsync = function(self, key, value)
	dsGuard()
	if nativeType(value) ~= "number" or value % 1 ~= 0 then
		error("OrderedDataStore:SetAsync value must be an integer", 2)
	end
	S[self].store[tostring(key)] = value
end
local PAGES = B("Pages")
PAGES.m.GetCurrentPage = function(self)
	return S[self].extra and S[self].extra.page or {}
end
PAGES.m.AdvanceToNextPageAsync = function(self)
	S[self].extra = { page = {} }
end
PAGES.get.IsFinished = function()
	return true
end

-- Memory stores (minimal)
local MSS = B("MemoryStoreService")
MSS.m.GetSortedMap = function(self, name)
	local m = R.create("MemoryStoreSortedMap")
	S[m].store = {}
	return m
end
MSS.m.GetHashMap = MSS.m.GetSortedMap
MSS.m.GetQueue = function()
	return R.create("MemoryStoreQueue")
end

---------------------------------------------------------------------------------------------------- Marketplace
R.OWNED_PASSES = {}
R.AUTO_BUY = true
local MPS = B("MarketplaceService")
local mps = service("MarketplaceService")
local function purchaseNote(kind, id)
	R.stats.purchases += 1
	R.addLog("BUY", kind .. " " .. tostring(id))
end
MPS.m.PromptGamePassPurchase = function(self, player, id)
	purchaseNote("pass", id)
	if R.AUTO_BUY then
		R.schedule(R.now + 0.5, R.newThread(function()
			R.OWNED_PASSES[tostring(S[player].props.UserId) .. ":" .. tostring(id)] = true
			R.fire(R.getSignal(S[mps], "PromptGamePassPurchaseFinished"), player, id, true)
		end, R.SERVER))
	end
end
MPS.m.PromptProductPurchase = function(self, player, id)
	purchaseNote("product", id)
	if not R.AUTO_BUY then
		return
	end
	R.schedule(R.now + 0.5, R.newThread(function()
		local cb = S[mps].callbacks.ProcessReceipt
		if not cb then
			R.warn("product purchased but MarketplaceService.ProcessReceipt is not set")
			return
		end
		R.purchaseSeq = (R.purchaseSeq or 0) + 1
		local receipt = { PlayerId = S[player].props.UserId, ProductId = id, PurchaseId = "sim-" .. R.purchaseSeq, CurrencySpent = 0, CurrencyType = R.enumItem("CurrencyType", "Robux"), PlaceIdWherePurchased = 0 }
		local ok, res = pcall(cb, receipt)
		if not ok then
			R.reportError("ProcessReceipt errored: " .. tostring(res))
		elseif res ~= R.enumItem("ProductPurchaseDecision", "PurchaseGranted") then
			R.warn("ProcessReceipt did not return PurchaseGranted for product " .. tostring(id) .. " (returned " .. tostring(res) .. ")")
		end
		R.fire(R.getSignal(S[mps], "PromptProductPurchaseFinished"), S[player].props.UserId, id, true)
	end, R.SERVER))
end
MPS.m.PromptPurchase = function(self, player, id)
	purchaseNote("asset", id)
end
MPS.m.PromptPremiumPurchase = function() end
MPS.m.PromptBundlePurchase = function() end
MPS.m.UserOwnsGamePassAsync = function(self, userId, id)
	R.sleep(0.05)
	return R.OWNED_PASSES[tostring(userId) .. ":" .. tostring(id)] == true
end
MPS.m.PlayerOwnsAsset = function()
	return false
end
MPS.m.PlayerOwnsBundle = function()
	return false
end
MPS.m.GetProductInfo = function(self, id, infoType)
	R.sleep(0.05)
	return { Name = "Item " .. tostring(id), Description = "", PriceInRobux = 99, IconImageAssetId = 0, AssetId = id, ProductId = id, IsForSale = true }
end
MPS.m.GetDeveloperProductsAsync = function()
	return R.create("Pages")
end

---------------------------------------------------------------------------------------------------- other services
local CS = B("CollectionService")
CS.m.AddTag = function(self, inst, tag)
	R.addTag(inst, tag)
end
CS.m.RemoveTag = function(self, inst, tag)
	R.removeTag(inst, tag)
end
CS.m.HasTag = function(self, inst, tag)
	return S[inst].tags[tag] == true
end
CS.m.GetTags = function(self, inst)
	return B("Instance").m.GetTags(inst)
end
CS.m.GetTagged = function(self, tag)
	local out = {}
	for inst in pairs(R.TAGGED[tag] or {}) do
		if R.inGame(inst) then
			table.insert(out, inst)
		end
	end
	return out
end
CS.m.GetInstanceAddedSignal = function(self, tag)
	return R.tagSigs(tag).added
end
CS.m.GetInstanceRemovedSignal = function(self, tag)
	return R.tagSigs(tag).removed
end
CS.m.GetAllTags = function()
	local out = {}
	for t in pairs(R.TAGGED) do
		table.insert(out, t)
	end
	return out
end

local TS = B("TweenService")
TS.m.Create = function(self, inst, info, goals)
	return R.tweenCreate(inst, info, goals)
end
TS.m.GetValue = function(self, alpha, style, dir)
	return R.ease(alpha, style, dir)
end

local DEB = B("Debris")
DEB.m.AddItem = function(self, inst, t)
	if not R.isInstance(inst) then
		error("invalid argument #1 to 'AddItem' (Instance expected)", 2)
	end
	R.schedule(R.now + (t or 10), R.newThread(function()
		if not S[inst].destroyed then
			R.destroy(inst)
		end
	end))
end
DEB.m.addItem = DEB.m.AddItem

local HS = B("HttpService")
HS.m.JSONEncode = function(self, v)
	return R.jsonEncode(v)
end
HS.m.JSONDecode = function(self, s)
	return R.jsonDecode(s)
end
local guidN = 0
HS.m.GenerateGUID = function(self, wrap)
	guidN += 1
	local g = string.format("%08X-0000-4000-8000-%012X", guidN, guidN * 7919)
	if wrap == false then
		return g
	end
	return "{" .. g .. "}"
end
HS.m.UrlEncode = function(self, s)
	return (tostring(s):gsub("[^%w%-_%.~]", function(c)
		return string.format("%%%02X", string.byte(c))
	end))
end
HS.m.GetAsync = function()
	error("Http requests are not enabled. Enable via game settings", 2)
end
HS.m.PostAsync = HS.m.GetAsync
HS.m.RequestAsync = HS.m.GetAsync

local TXS = B("TextService")
TXS.m.GetTextSize = function(self, text, size, font, frame)
	return v2(#tostring(text) * size * 0.5, size)
end
TXS.m.GetTextBoundsAsync = function(self, params)
	return v2(#tostring(params.Text or "") * (params.Size or 14) * 0.5, params.Size or 14)
end
TXS.m.FilterStringAsync = function(self, text)
	local r = { GetNonChatStringForBroadcastAsync = function()
		return text
	end, GetNonChatStringForUserAsync = function()
		return text
	end, GetChatForUserAsync = function()
		return text
	end }
	return r
end
B("Chat").m.FilterStringForBroadcast = function(self, text)
	return text
end
B("Chat").m.FilterStringAsync = function(self, text)
	return text
end
B("Chat").m.Chat = function() end

local UIS = B("UserInputService")
UIS.get.TouchEnabled = function()
	return R.MOBILE == true
end
UIS.get.KeyboardEnabled = function()
	return not R.MOBILE
end
UIS.get.MouseEnabled = function()
	return not R.MOBILE
end
UIS.get.GamepadEnabled = function()
	return false
end
UIS.get.VREnabled = function()
	return false
end
UIS.m.GetMouseLocation = function()
	return v2(640, 360)
end
UIS.m.IsKeyDown = function()
	return false
end
UIS.m.IsMouseButtonPressed = function()
	return false
end
UIS.m.GetLastInputType = function()
	return R.enumItem("UserInputType", R.MOBILE and "Touch" or "MouseButton1")
end
UIS.m.GetPlatform = function()
	return R.enumItem("Platform", R.MOBILE and "IOS" or "Windows")
end
UIS.m.GetKeysPressed = function()
	return {}
end
UIS.m.GetFocusedTextBox = function()
	return nil
end
UIS.m.GetConnectedGamepads = function()
	return {}
end
UIS.m.GetGamepadConnected = function()
	return false
end

local CAS = B("ContextActionService")
R.actions = {}
CAS.m.BindAction = function(self, name, fn, touch, ...)
	R.actions[name] = { fn = fn, ctx = R.CUR }
end
CAS.m.BindActionAtPriority = function(self, name, fn, touch, prio, ...)
	R.actions[name] = { fn = fn, ctx = R.CUR }
end
CAS.m.UnbindAction = function(self, name)
	R.actions[name] = nil
end
CAS.m.SetTitle = function() end
CAS.m.SetImage = function() end
CAS.m.SetPosition = function() end
CAS.m.SetDescription = function() end
CAS.m.GetButton = function()
	return nil
end

local GS = B("GuiService")
GS.m.GetGuiInset = function()
	return v2(0, R.GUI_INSET), v2(0, 0)
end
GS.get.TopbarInset = function()
	return G.Rect.new(0, 0, 1280, R.GUI_INSET)
end
GS.m.IsTenFootInterface = function()
	return false
end

local SG = B("StarterGui")
SG.m.SetCoreGuiEnabled = function(self, t, on)
	if R.CUR and R.CUR.name ~= "client" then
		error("SetCoreGuiEnabled can only be called from a LocalScript", 2)
	end
end
SG.m.GetCoreGuiEnabled = function()
	return true
end
SG.m.SetCore = function(self, name, value)
	if R.CUR and R.CUR.name ~= "client" then
		error("SetCore can only be called from a LocalScript", 2)
	end
end
SG.m.GetCore = function()
	return nil
end

local PHS = B("PhysicsService")
local groups = { Default = true }
PHS.m.RegisterCollisionGroup = function(self, name)
	groups[name] = true
end
PHS.m.CreateCollisionGroup = PHS.m.RegisterCollisionGroup
PHS.m.IsCollisionGroupRegistered = function(self, name)
	return groups[name] == true
end
PHS.m.CollisionGroupSetCollidable = function(self, a, b, on)
	if not groups[a] or not groups[b] then
		error("CollisionGroupSetCollidable: collision group not registered (" .. tostring(a) .. ", " .. tostring(b) .. ")", 2)
	end
end
PHS.m.CollisionGroupsAreCollidable = function()
	return true
end
PHS.m.GetRegisteredCollisionGroups = function()
	local out = {}
	for n in pairs(groups) do
		table.insert(out, { name = n })
	end
	return out
end
PHS.m.GetMaxCollisionGroups = function()
	return 32
end

local PFS = B("PathfindingService")
PFS.m.CreatePath = function()
	local p = R.create("Path")
	S[p].extra = { waypoints = {} }
	return p
end
PFS.m.FindPathAsync = function(self, a, b)
	local p = PFS.m.CreatePath(self)
	B("Path").m.ComputeAsync(p, a, b)
	return p
end
local PATH = B("Path")
PATH.m.ComputeAsync = function(self, a, b)
	R.sleep(0.05)
	local wps = {}
	for i = 0, 4 do
		local w = { Position = a:Lerp(b, i / 4), Action = R.enumItem("PathWaypointAction", "Walk"), Label = "" }
		table.insert(wps, w)
	end
	S[self].extra = { waypoints = wps }
	S[self].props.Status = R.enumItem("PathStatus", "Success")
end
PATH.m.GetWaypoints = function(self)
	return table.clone(S[self].extra and S[self].extra.waypoints or {})
end
PATH.m.CheckOcclusionAsync = function()
	return -1
end

B("LocalizationService").m.GetCountryRegionForPlayerAsync = function()
	return "US"
end
B("LocalizationService").m.GetTranslatorForPlayerAsync = function()
	error("no translator", 2)
end
B("PolicyService").m.GetPolicyInfoForPlayerAsync = function()
	return { AreAdsAllowed = true, ArePaidRandomItemsRestricted = false, AllowedExternalLinkReferences = {}, IsPaidItemTradingAllowed = true, IsSubjectToChinaPolicies = false, IsContentSharingAllowed = true }
end
B("BadgeService").m.AwardBadge = function()
	return true
end
B("BadgeService").m.UserHasBadgeAsync = function()
	return false
end
B("BadgeService").m.GetBadgeInfoAsync = function()
	return { Name = "Badge", IsEnabled = true }
end
B("SocialService").m.CanSendGameInviteAsync = function()
	return false
end
B("SocialService").m.PromptGameInvite = function() end
B("TeleportService").m.Teleport = function()
	R.warn("TeleportService:Teleport called (no-op in Studio)")
end
B("TeleportService").m.TeleportAsync = B("TeleportService").m.Teleport
B("TeleportService").m.TeleportToPrivateServer = B("TeleportService").m.Teleport
B("MessagingService").m.PublishAsync = function() end
B("MessagingService").m.SubscribeAsync = function()
	return { Disconnect = function() end }
end
B("ContentProvider").m.PreloadAsync = function(self, list, cb)
	R.sleep(0.05)
	if cb then
		for _, x in ipairs(list) do
			pcall(cb, nativeType(x) == "string" and x or "", R.enumItem("AssetFetchStatus", "Success"))
		end
	end
end
B("GroupService").m.GetGroupInfoAsync = function()
	return { Name = "Group", Owner = { Name = "Owner", Id = 1 } }
end
B("GroupService").m.GetGroupsAsync = function()
	return {}
end
B("InsertService").m.LoadAsset = function(self, id)
	R.noteAsset(tostring(id), "InsertService.LoadAsset")
	error("InsertService:LoadAsset is not allowed for assets you don't own (simulator)", 2)
end
local AS = B("AssetService")
AS.m.CreateMeshPartAsync = function(self, content, opts)
	R.sleep(0.2)
	local m = R.create("MeshPart")
	S[m].props.Size = v3(4, 4, 4)
	if R.typeof(content) == "Content" then
		S[m].props.MeshId = content.Uri or ""
	elseif nativeType(content) == "string" then
		R.noteAsset(content, "CreateMeshPartAsync")
		S[m].props.MeshId = content
	end
	return m
end
AS.m.CreateEditableImage = function()
	error("EditableImage not available in simulator", 2)
end
AS.m.SavePlaceAsync = function()
	error("SavePlaceAsync not available in Studio", 2)
end

B("ProximityPromptService").events.PromptTriggered = {}
B("Lighting").m.GetMinutesAfterMidnight = function(self)
	return (R.rawGet(self, "ClockTime") or 14) * 60
end
B("Lighting").m.SetMinutesAfterMidnight = function(self, m)
	R.rawSet(self, "ClockTime", (m / 60) % 24)
end
B("Lighting").m.GetSunDirection = function()
	return v3(0.5, 0.7, 0.3).Unit
end
B("Lighting").m.GetMoonDirection = function()
	return v3(-0.5, 0.7, -0.3).Unit
end
B("Stats").m.GetTotalMemoryUsageMb = function()
	return 500
end
B("Stats").m.GetMemoryUsageMbForTag = function()
	return 10
end
B("VoiceChatService").m.IsVoiceEnabledForUserIdAsync = function()
	return false
end
B("AnalyticsService").m.LogCustomEvent = function() end
B("AnalyticsService").m.LogEconomyEvent = function() end
B("AnalyticsService").m.LogFunnelStepEvent = function() end
B("AnalyticsService").m.LogOnboardingFunnelStepEvent = function() end
B("AnalyticsService").m.LogProgressionEvent = function() end
B("TextChatService").m.DisplayBubble = function() end

-- ProximityPrompt / ClickDetector extras
B("ProximityPrompt").m.InputHoldBegin = function() end
B("ProximityPrompt").m.InputHoldEnd = function() end

---------------------------------------------------------------------------------------------------- physics step
R.MOVERS = setmetatable({}, { __mode = "k" })
function R.onCreate(inst, s, fromClone)
	local cls = s.ClassName
	if R.classIsA(cls, "JointInstance") or cls == "WeldConstraint" then
		if fromClone then
			R.updateJoint(inst, false)
			if cls == "WeldConstraint" and s.extra and s.extra.rel == nil then
				R.updateJoint(inst)
			end
		end
	end
	if cls == "AlignPosition" or cls == "AlignOrientation" or cls == "LinearVelocity" or cls == "BodyPosition" or cls == "BodyVelocity" or cls == "BodyGyro" or cls == "AngularVelocity" or cls == "BodyAngularVelocity" then
		R.MOVERS[inst] = true
	end
	if cls == "Sound" then
		R.noteAsset(s.props.SoundId, "Sound")
	end
end
function R.onDestroy(inst, s)
	if R.JOINTS then
		for _, k in ipairs({ "_p0", "_p1" }) do
			local p = s[k]
			if p and R.JOINTS[p] then
				R.JOINTS[p][inst] = nil
			end
		end
	end
	R.MOVERS[inst] = nil
end

local function attachmentPart(att)
	if not att then
		return nil
	end
	local p = S[att].parent
	if p and R.classIsA(S[p].ClassName, "BasePart") then
		return p
	end
	return nil
end

local function stepMovers(dt)
	for m in pairs(R.MOVERS) do
		local s = S[m]
		if not s.destroyed and s.parent and R.rawGet(m, "Enabled") ~= false and R.inWorkspace(m) then
			local cls = s.ClassName
			if cls == "AlignPosition" then
				local a0 = s.props.Attachment0
				local part = attachmentPart(a0)
				if part and not R.isGrounded(part) then
					local target
					local mode = R.rawGet(m, "Mode")
					if mode and mode.Name == "OneAttachment" then
						target = R.rawGet(m, "Position")
					elseif s.props.Attachment1 then
						target = m.Attachment1.WorldPosition
					end
					if target then
						local cur = a0.WorldPosition
						local delta = target - cur
						local maxV = R.rawGet(m, "MaxVelocity")
						if not R.rawGet(m, "RigidityEnabled") and maxV and maxV < math.huge and delta.Magnitude > maxV * dt then
							delta = delta.Unit * maxV * dt
						end
						R.movePart(part, R.partCF(part) + delta)
					end
				end
			elseif cls == "LinearVelocity" then
				local part = attachmentPart(s.props.Attachment0)
				if part and not R.isGrounded(part) then
					local vel = R.rawGet(m, "VectorVelocity") or v3(0, 0, 0)
					R.movePart(part, R.partCF(part) + vel * dt)
				end
			elseif cls == "BodyPosition" then
				local part = s.parent
				if R.classIsA(S[part].ClassName, "BasePart") and not R.isGrounded(part) then
					local target = R.rawGet(m, "Position")
					local c = R.partCF(part)
					R.movePart(part, c + (target - c.Position) * math.min(1, dt * 5))
				end
			elseif cls == "BodyVelocity" then
				local part = s.parent
				if R.classIsA(S[part].ClassName, "BasePart") and not R.isGrounded(part) then
					R.movePart(part, R.partCF(part) + (R.rawGet(m, "Velocity") or v3(0, 0, 0)) * dt)
				end
			end
		end
	end
end

-- Characters walk (Humanoid:MoveTo), stand on the ground and fall into the void.
local function stepCharacters(dt)
	for _, p in ipairs(R.playerList()) do
		local ch = S[p].props.Character
		if ch and not S[ch].destroyed then
			local hrp = R.rawGetChild(ch, "HumanoidRootPart")
			local hum = R.rawGetChild(ch, "Humanoid")
			if hrp and hum and not S[hum].dead then
				local hs = S[hum]
				local c = R.partCF(hrp)
				local pos = c.Position
				local anchored = R.rawGet(hrp, "Anchored")
				local moved = false
				if hs.moveTarget and not anchored then
					local ws = R.rawGet(hum, "WalkSpeed")
					local d = hs.moveTarget - pos
					local flat = v3(d.X, 0, d.Z)
					local dist = flat.Magnitude
					if dist < 1 or R.now - hs.moveStart > 8 or ws <= 0 then
						local reached = dist < 1.5
						hs.moveTarget = nil
						R.fire(R.getSignal(hs, "MoveToFinished"), reached)
					else
						local step = math.min(dist, ws * dt)
						pos = pos + flat.Unit * step
						moved = true
						hs.moveDir = flat.Unit
					end
				else
					hs.moveDir = v3(0, 0, 0)
				end
				if not anchored and not hs.seated then
					-- stand on whatever is below (ignoring the character itself)
					-- (non-collidable parts are passed through, like Roblox physics)
					local params = G.RaycastParams.new()
					local skip = { ch }
					params.FilterDescendantsInstances = skip
					local hit = R.raycast(pos + v3(0, 2, 0), v3(0, -60, 0), params)
					for _ = 1, 8 do
						if not hit or R.rawGet(hit.Instance, "CanCollide") ~= false then
							break
						end
						table.insert(skip, hit.Instance)
						params.FilterDescendantsInstances = skip
						hit = R.raycast(pos + v3(0, 2, 0), v3(0, -60, 0), params)
					end
					local hipY = 3
					if hit and R.rawGet(hit.Instance, "CanCollide") ~= false then
						local gy = hit.Position.Y + hipY
						if pos.Y - gy > 0.5 then
							pos = v3(pos.X, math.max(gy, pos.Y - 60 * dt), pos.Z)
						else
							pos = v3(pos.X, gy, pos.Z)
						end
						hs.grounded = true
					else
						pos = v3(pos.X, pos.Y - 80 * dt, pos.Z)
						hs.grounded = false
						if pos.Y < (R.rawGet(workspace, "FallenPartsDestroyHeight") or -500) then
							R.addLog("VOID", S[p].props.Name .. " fell out of the world")
							R.stats.voidDeaths = (R.stats.voidDeaths or 0) + 1
							hum.Health = 0
						end
					end
					if moved or pos ~= c.Position then
						local look = hs.moveDir.Magnitude > 0 and hs.moveDir or c.LookVector
						local rot = R.cfInv(cf(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1))
						local newCF = G.CFrame.lookAt(pos, pos + v3(look.X, 0, look.Z))
						if newCF.X ~= newCF.X then
							newCF = c + (pos - c.Position)
						end
						R.movePart(hrp, newCF)
					end
				end
			end
		end
	end
end

-- Character parts touching parts with Touched listeners.
R.touching = {} -- part -> {charPart = true}
local touchFrame = 0
local function stepTouches()
	touchFrame += 1
	if touchFrame % 2 ~= 0 then
		return
	end
	local chars = {}
	for _, p in ipairs(R.playerList()) do
		local ch = S[p].props.Character
		if ch and not S[ch].destroyed then
			local hrp = R.rawGetChild(ch, "HumanoidRootPart")
			local foot = R.rawGetChild(ch, "LeftFoot")
			if hrp then
				local c = R.partCF(hrp)
				table.insert(chars, { ch = ch, hrp = hrp, foot = foot or hrp, x0 = c.X - 1.2, y0 = c.Y - 3.2, z0 = c.Z - 1.2, x1 = c.X + 1.2, y1 = c.Y + 2.6, z1 = c.Z + 1.2 })
			end
		end
	end
	local near = {}
	for part in pairs(R.touching) do
		near[part] = true
	end
	for _, info in ipairs(chars) do
		for part in pairs(gridCandidates(info.x0, info.z0, info.x1, info.z1) or R.WSPARTS) do
			near[part] = true
		end
	end
	for part in pairs(near) do
		local ps = S[part]
		local sig = ps.sigs.Touched
		local sigEnd = ps.sigs.TouchEnded
		if (sig and #sig._conns > 0) or (sigEnd and #sigEnd._conns > 0) then
			if R.rawGet(part, "CanTouch") ~= false then
				local a, b, c, d, e, f = R.aabb(part)
				local now = {}
				for _, info in ipairs(chars) do
					if not R.isDescendantOf(part, info.ch) and a <= info.x1 and d >= info.x0 and b <= info.y1 and e >= info.y0 and c <= info.z1 and f >= info.z0 then
						now[info.ch] = info
					end
				end
				local prev = R.touching[part] or {}
				for ch, info in pairs(now) do
					if not prev[ch] then
						R.stats.touches = (R.stats.touches or 0) + 1
						if sig then
							R.fire(sig, info.hrp)
							R.fire(sig, info.foot)
						end
					end
				end
				for ch, info in pairs(prev) do
					if not now[ch] and sigEnd then
						R.fire(sigEnd, info.hrp)
						R.fire(sigEnd, info.foot)
					end
				end
				R.touching[part] = next(now) and now or nil
			end
		end
	end
end

table.insert(R.preStep, function(dt)
	R.tweenStep()
end)
table.insert(R.preStep, stepMovers)
table.insert(R.preStep, stepCharacters)
table.insert(R.preStep, stepTouches)

local rsState = S[runService]
function R.onFrameStart(dt)
	-- RenderStepped (client) -> Stepped -> (timers) -> Heartbeat
	if R.CLIENT and R.CLIENT.player and not R.CLIENT.dead then
		local binds = {}
		for name, b in pairs(R.renderBinds) do
			table.insert(binds, b)
		end
		table.sort(binds, function(a, b)
			return (a.priority or 0) < (b.priority or 0)
		end)
		for _, b in ipairs(binds) do
			R.resume(R.newThread(b.fn, b.ctx), dt)
		end
		R.fire(rsState.sigs.RenderStepped, dt)
		R.fire(rsState.sigs.PreRender, dt)
	end
	R.fire(rsState.sigs.Stepped, R.now, dt)
	R.fire(rsState.sigs.PreSimulation, dt)
end
function R.onFrameEnd(dt)
	R.fire(rsState.sigs.PostSimulation, dt)
	R.fire(rsState.sigs.Heartbeat, dt)
end

---------------------------------------------------------------------------------------------------- scripts
R.SERVER = { name = "server", G = {}, modules = {} }
R.CLIENT = { name = "client", G = {}, modules = {}, player = nil }
R.CUR = R.SERVER

local envMeta = {}
local function scriptEnv(scriptInst, ctx)
	local env = setmetatable({ script = scriptInst, _G = ctx.G }, { __index = G })
	return env
end

local requireStack = {}
G.require = function(m)
	if nativeType(m) == "number" then
		error("require(assetId) is not supported in the simulator", 2)
	end
	if nativeType(m) == "string" then
		error("require(string) is not supported for Roblox scripts", 2)
	end
	if not R.isInstance(m) then
		error("Attempted to call require with invalid argument(s).", 2)
	end
	local ms = S[m]
	if ms.ClassName ~= "ModuleScript" then
		error("Attempted to call require with invalid argument(s).", 2)
	end
	local ctx = R.CUR
	local cache = ctx.modules
	local entry = cache[m]
	if entry then
		if entry.state == "done" then
			return entry.value
		elseif entry.state == "error" then
			error("Requested module experienced an error while loading", 2)
		else
			-- loading: recursive (same chain) or concurrent
			for _, x in ipairs(requireStack) do
				if x == m then
					error("Requested module was required recursively", 2)
				end
			end
			while entry.state == "loading" do
				R.sleep(R.FRAME)
			end
			if entry.state == "error" then
				error("Requested module experienced an error while loading", 2)
			end
			return entry.value
		end
	end
	entry = { state = "loading" }
	cache[m] = entry
	local chunk = __load(ms.source or "", "=" .. R.fullName(m), scriptEnv(m, ctx))
	if nativeType(chunk) ~= "function" then
		entry.state = "error"
		error("Syntax error in " .. R.fullName(m) .. ": " .. tostring(chunk), 2)
	end
	table.insert(requireStack, m)
	local res = table.pack(pcall(chunk))
	table.remove(requireStack)
	if not res[1] then
		entry.state = "error"
		error(res[2], 0)
	end
	if res.n ~= 2 then
		entry.state = "error"
		error("Module code did not return exactly one value: " .. R.fullName(m), 2)
	end
	entry.value = res[2]
	entry.state = "done"
	return entry.value
end

function R.runScript(scriptInst, ctx)
	local s = S[scriptInst]
	if s.started then
		return
	end
	s.started = true
	local chunk = __load(s.source or "", "=" .. R.fullName(scriptInst), scriptEnv(scriptInst, ctx))
	if nativeType(chunk) ~= "function" then
		R.reportError("Syntax error in " .. R.fullName(scriptInst) .. ": " .. tostring(chunk))
		return
	end
	R.addLog("RUN", ctx.name .. " " .. R.fullName(scriptInst))
	local co = R.newThread(chunk, ctx)
	R.deferThread(co)
end

-- Start Scripts (server) or LocalScripts (client ctx given) inside a container.
function R.startScriptsIn(root, clientCtx)
	local list = { root }
	for _, d in ipairs(R.descendants(root)) do
		table.insert(list, d)
	end
	for _, x in ipairs(list) do
		local xs = S[x]
		if xs.ClassName == "LocalScript" and clientCtx and R.rawGet(x, "Enabled") ~= false then
			R.runScript(x, clientCtx)
		elseif xs.ClassName == "Script" and R.rawGet(x, "Enabled") ~= false then
			local rc = R.rawGet(x, "RunContext")
			if rc and rc.Name == "Client" then
				if clientCtx then
					R.runScript(x, clientCtx)
				end
			elseif not clientCtx then
				R.runScript(x, R.SERVER)
			end
		end
	end
end

-- print / warn
G.print = function(...)
	local t = table.pack(...)
	for i = 1, t.n do
		t[i] = tostring(t[i])
	end
	R.addLog("print", table.concat(t, " ", 1, t.n))
end
G.warn = function(...)
	local t = table.pack(...)
	for i = 1, t.n do
		t[i] = tostring(t[i])
	end
	R.addLog("warn", table.concat(t, " ", 1, t.n))
	R.stats.scriptWarns = (R.stats.scriptWarns or 0) + 1
end
G.loadstring = nil
G.debug = setmetatable({ profilebegin = function() end, profileend = function() end, setmemorycategory = function() end, resetmemorycategory = function() end, dumpcodesize = function() end }, { __index = debug })
G.os = setmetatable({
	time = function(t)
		if t then
			return os.time(t)
		end
		return math.floor(R.unixNow())
	end,
	clock = function()
		return R.now
	end,
}, { __index = os })
local START_UNIX = os.time()
function R.unixNow()
	return START_UNIX + R.now + (R.timeOffset or 0)
end

return true

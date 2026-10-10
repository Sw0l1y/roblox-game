-- Instance behaviours for the simulator: hierarchy, events, clone/destroy, attributes, tags, parts and joints,
-- models, attachments, GUI geometry, values, remotes, bindables, sounds, animations and tweens.
local R = ...
local G = R.G
local S = R.STATE
local v3, v2, cf, c3 = R.v3, R.v2, R.cf, R.c3
local B = R.behavior
local fullName = R.fullName
local IDENT = R.CF_IDENTITY
local nativeType = type

local function st(inst, method)
	return R.getState(inst, method)
end

local function checkInstance(v, fname, idx)
	if not R.isInstance(v) then
		error(string.format("invalid argument #%d to '%s' (Instance expected, got %s)", idx, fname, R.typeof(v)), 3)
	end
end

---------------------------------------------------------------------------------------------------- defaults not in the dump
local D = R.DEFAULTS
D.Instance = { Archivable = true }
D.BasePart = {
	Size = v3(4, 1, 2), Color = c3(163 / 255, 162 / 255, 165 / 255), Transparency = 0, Reflectance = 0, Anchored = false,
	CanCollide = true, CanTouch = true, CanQuery = true, CastShadow = true, Locked = false, Massless = false,
	CFrame = IDENT, Material = function()
		return R.enumItem("Material", "Plastic")
	end,
}
D.Part = { Size = v3(4, 1, 2), Shape = function()
	return R.enumItem("PartType", "Block")
end }
D.MeshPart = { Size = v3(4, 4, 4) }
D.SpawnLocation = { Size = v3(12, 1, 12), Enabled = true, Duration = 10 }
D.Seat = { Size = v3(2, 1, 2) }
D.TrussPart = { Size = v3(2, 10, 2) }
D.WedgePart = { Size = v3(4, 1, 2) }
D.CornerWedgePart = { Size = v3(2, 2, 2) }
D.GuiObject = {
	Size = R.udim2(0, 100, 0, 100), Position = R.udim2(0, 0, 0, 0), BackgroundColor3 = c3(163 / 255, 162 / 255, 165 / 255),
	BackgroundTransparency = 0, Visible = true, ZIndex = 1, AnchorPoint = v2(0, 0), LayoutOrder = 0, Rotation = 0,
	BorderSizePixel = 1, Active = false, ClipsDescendants = false, Selectable = false, Interactable = true,
}
D.GuiButton = { AutoButtonColor = true, Active = true, Selectable = true, Modal = false }
D.TextLabel = { Text = "Label", TextSize = 14, TextColor3 = c3(0.106, 0.165, 0.208), TextTransparency = 0, TextScaled = false, TextWrapped = false }
D.TextButton = { Text = "Button", TextSize = 14, TextColor3 = c3(0.106, 0.165, 0.208), TextTransparency = 0, TextScaled = false, TextWrapped = false }
D.TextBox = { Text = "TextBox", TextSize = 14, TextColor3 = c3(0.106, 0.165, 0.208), TextTransparency = 0, TextScaled = false, ClearTextOnFocus = true, TextEditable = true }
D.LayerCollector = { Enabled = true, ResetOnSpawn = true }
D.BillboardGui = { MaxDistance = math.huge, Size = R.udim2(0, 0, 0, 0) }
D.Light = { Enabled = true, Brightness = 1, Color = c3(1, 1, 1) }
D.PointLight = { Range = 8 }
D.SpotLight = { Range = 16, Angle = 90 }
D.SurfaceLight = { Range = 16, Angle = 90 }
D.Constraint = { Enabled = true, Visible = false }
D.JointInstance = { Enabled = true, C0 = IDENT, C1 = IDENT }
D.WeldConstraint = { Enabled = true }
D.ParticleEmitter = { Enabled = true, Rate = 20 }
D.Beam = { Enabled = true }
D.Trail = { Enabled = true }
D.Highlight = { Enabled = true }
D.UIStroke = { Enabled = true, Thickness = 1, Color = c3(0, 0, 0), Transparency = 0 }
D.UIGradient = { Enabled = true }
D.Sound = { Volume = 0.5, PlaybackSpeed = 1, Looped = false, Playing = false }
D.ProximityPrompt = { Enabled = true, ActionText = "Interact", ObjectText = "", HoldDuration = 0, MaxActivationDistance = 10, RequiresLineOfSight = true }
D.ClickDetector = { MaxActivationDistance = 32 }
D.BaseScript = { Enabled = true }
D.Humanoid = { Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2, HipHeight = 2, UseJumpPower = true, AutoRotate = true }
D.Camera = { FieldOfView = 70, CFrame = R.cf(0, 20, 20, 1, 0, 0, 0, 1, 0, 0, 0, 1) }
D.Atmosphere = {}
D.Players = { MaxPlayers = 30, RespawnTime = 5, CharacterAutoLoads = true }
D.Workspace = { Gravity = 196.2, FallenPartsDestroyHeight = -500 }
D.Player = { CharacterAutoLoads = true, Neutral = true, AccountAge = 30 }
D.Model = { LevelOfDetail = function()
	return R.enumItem("ModelLevelOfDetail", "Automatic")
end }

---------------------------------------------------------------------------------------------------- hierarchy
local function isDescendantOf(inst, anc)
	local cur = S[inst].parent
	while cur do
		if cur == anc then
			return true
		end
		cur = S[cur].parent
	end
	return false
end
R.isDescendantOf = isDescendantOf

local function descendants(inst, out)
	out = out or {}
	for _, c in ipairs(S[inst].children) do
		table.insert(out, c)
		descendants(c, out)
	end
	return out
end
R.descendants = descendants

function R.inGame(inst)
	return R.game ~= nil and (inst == R.game or isDescendantOf(inst, R.game))
end
function R.inWorkspace(inst)
	return R.workspace ~= nil and (inst == R.workspace or isDescendantOf(inst, R.workspace))
end

R.WSPARTS = {} -- BaseParts currently under Workspace
R.TAGGED = {} -- tag -> {inst = true}
R.TAGSIGS = {} -- tag -> {added=, removed=}

local function tagSigs(tag)
	local t = R.TAGSIGS[tag]
	if not t then
		t = { added = R.newSignal("InstanceAdded:" .. tag), removed = R.newSignal("InstanceRemoved:" .. tag) }
		R.TAGSIGS[tag] = t
	end
	return t
end
R.tagSigs = tagSigs

local function onReparent(inst, wasInGame, wasInWS)
	local nowInWS = R.inWorkspace(inst)
	local nowInGame = R.inGame(inst)
	if wasInWS ~= nowInWS or wasInGame ~= nowInGame then
		local list = descendants(inst, { inst })
		for _, x in ipairs(list) do
			local xs = S[x]
			if wasInWS ~= nowInWS and R.classIsA(xs.ClassName, "BasePart") then
				R.WSPARTS[x] = nowInWS or nil
			end
			if wasInGame ~= nowInGame then
				for tag in pairs(xs.tags) do
					R.fire(nowInGame and tagSigs(tag).added or tagSigs(tag).removed, x)
				end
			end
			if R.onEnterWorld and nowInWS and not wasInWS then
				R.onEnterWorld(x, xs)
			end
		end
	end
end

local function fireDescendantSignals(ancestorStart, inst, sigName)
	local ancestors = {}
	local cur = ancestorStart
	while cur do
		local cs = S[cur]
		if cs.sigs[sigName] then
			table.insert(ancestors, cs.sigs[sigName])
		end
		cur = cs.parent
	end
	if #ancestors == 0 then
		return
	end
	local list = descendants(inst, { inst })
	for _, sig in ipairs(ancestors) do
		for _, x in ipairs(list) do
			R.fire(sig, x)
		end
	end
end

function R.setParent(inst, newParent, level)
	level = (level or 2) + 1
	local s = S[inst]
	if s.parentLocked then
		error(string.format("The Parent property of %s is locked, current parent: %s, new parent %s", s.props.Name, s.parent and S[s.parent].props.Name or "NULL", newParent and R.isInstance(newParent) and S[newParent].props.Name or "NULL"), level)
	end
	if newParent ~= nil and not R.isInstance(newParent) then
		error("Unable to assign property Parent. Instance expected, got " .. R.typeof(newParent), level)
	end
	if newParent == s.parent then
		return
	end
	if s.isService then
		error("Unable to change the Parent of a service", level)
	end
	if newParent and S[newParent].destroyed then
		error(string.format("The Parent property of %s is locked", S[newParent].props.Name), level)
	end
	local cur = newParent
	while cur do
		if cur == inst then
			error(string.format("Attempt to set parent of %s to %s would result in circular reference", fullName(inst), fullName(newParent)), level)
		end
		cur = S[cur].parent
	end
	local wasInGame, wasInWS = R.inGame(inst), R.inWorkspace(inst)
	local old = s.parent
	if old then
		local os_ = S[old]
		fireDescendantSignals(old, inst, "DescendantRemoving")
		local idx = table.find(os_.children, inst)
		if idx then
			table.remove(os_.children, idx)
		end
		R.fire(os_.sigs.ChildRemoved, inst)
	end
	s.parent = newParent
	if newParent then
		local ns = S[newParent]
		table.insert(ns.children, inst)
		R.fire(ns.sigs.ChildAdded, inst)
		fireDescendantSignals(newParent, inst, "DescendantAdded")
		local waiters = ns.childWaiters and ns.childWaiters[s.props.Name]
		if waiters then
			ns.childWaiters[s.props.Name] = nil
			for _, w in ipairs(waiters) do
				if not w.done then
					w.done = true
					R.deferThread(w.co, inst)
				end
			end
		end
	end
	R.firePropChanged(inst, s, "Parent", newParent)
	if s.sigs.AncestryChanged then
		R.fire(s.sigs.AncestryChanged, inst, newParent)
	end
	for _, d in ipairs(descendants(inst)) do
		local ds = S[d]
		if ds.sigs.AncestryChanged then
			R.fire(ds.sigs.AncestryChanged, inst, newParent)
		end
	end
	onReparent(inst, wasInGame, wasInWS)
end

---------------------------------------------------------------------------------------------------- Instance members
local I = B("Instance")
I.get.Name = function(inst, s)
	return s.props.Name
end
I.set.Name = function(inst, s, v)
	if nativeType(v) ~= "string" then
		error("Unable to assign property Name. string expected, got " .. R.typeof(v), 3)
	end
	local old = s.props.Name
	if old == v then
		return
	end
	s.props.Name = v
	R.firePropChanged(inst, s, "Name", v)
	local p = s.parent
	if p then
		local ps = S[p]
		local waiters = ps.childWaiters and ps.childWaiters[v]
		if waiters then
			ps.childWaiters[v] = nil
			for _, w in ipairs(waiters) do
				if not w.done then
					w.done = true
					R.deferThread(w.co, inst)
				end
			end
		end
	end
end
I.get.Parent = function(inst, s)
	return s.parent
end
I.set.Parent = function(inst, s, v)
	R.setParent(inst, v, 3)
end
I.get.ClassName = function(inst, s)
	return s.ClassName
end
I.get.className = I.get.ClassName

local function findChild(inst, name, recursive)
	for _, c in ipairs(S[inst].children) do
		if S[c].props.Name == name then
			return c
		end
	end
	if recursive then
		for _, c in ipairs(S[inst].children) do
			local r = findChild(c, name, true)
			if r then
				return r
			end
		end
	end
	return nil
end

I.m.FindFirstChild = function(self, name, recursive)
	st(self, "FindFirstChild")
	if name == nil then
		error("Argument 1 missing or nil", 2)
	end
	return findChild(self, tostring(name), recursive)
end
I.m.findFirstChild = I.m.FindFirstChild
I.m.FindFirstChildOfClass = function(self, cls)
	for _, c in ipairs(st(self, "FindFirstChildOfClass").children) do
		if S[c].ClassName == cls then
			return c
		end
	end
	return nil
end
local function whichIsA(inst, cls, recursive)
	for _, c in ipairs(S[inst].children) do
		if R.classIsA(S[c].ClassName, cls) then
			return c
		end
	end
	if recursive then
		for _, c in ipairs(S[inst].children) do
			local r = whichIsA(c, cls, true)
			if r then
				return r
			end
		end
	end
	return nil
end
I.m.FindFirstChildWhichIsA = function(self, cls, recursive)
	st(self, "FindFirstChildWhichIsA")
	return whichIsA(self, cls, recursive)
end
I.m.FindFirstAncestor = function(self, name)
	local cur = st(self, "FindFirstAncestor").parent
	while cur do
		if S[cur].props.Name == name then
			return cur
		end
		cur = S[cur].parent
	end
	return nil
end
I.m.FindFirstAncestorOfClass = function(self, cls)
	local cur = st(self, "FindFirstAncestorOfClass").parent
	while cur do
		if S[cur].ClassName == cls then
			return cur
		end
		cur = S[cur].parent
	end
	return nil
end
I.m.FindFirstAncestorWhichIsA = function(self, cls)
	local cur = st(self, "FindFirstAncestorWhichIsA").parent
	while cur do
		if R.classIsA(S[cur].ClassName, cls) then
			return cur
		end
		cur = S[cur].parent
	end
	return nil
end
I.m.FindFirstDescendant = function(self, name)
	st(self, "FindFirstDescendant")
	for _, d in ipairs(descendants(self)) do
		if S[d].props.Name == name then
			return d
		end
	end
	return nil
end
I.m.GetChildren = function(self)
	return table.clone(st(self, "GetChildren").children)
end
I.m.getChildren = I.m.GetChildren
I.m.children = I.m.GetChildren
I.m.GetDescendants = function(self)
	st(self, "GetDescendants")
	return descendants(self)
end
I.m.IsA = function(self, cls)
	return R.classIsA(st(self, "IsA").ClassName, cls)
end
I.m.isA = I.m.IsA
I.m.IsDescendantOf = function(self, anc)
	st(self, "IsDescendantOf")
	if anc == nil then
		return false
	end
	checkInstance(anc, "IsDescendantOf", 1)
	return isDescendantOf(self, anc)
end
I.m.isDescendantOf = I.m.IsDescendantOf
I.m.IsAncestorOf = function(self, d)
	st(self, "IsAncestorOf")
	if d == nil then
		return false
	end
	return isDescendantOf(d, self)
end
I.m.GetFullName = function(self)
	st(self, "GetFullName")
	return fullName(self)
end
I.m.GetDebugId = function()
	return "0"
end
I.m.GetActor = function()
	return nil
end
I.m.GetStyled = function(self, prop)
	return self[prop]
end

I.m.WaitForChild = function(self, name, timeout)
	local s = st(self, "WaitForChild")
	if nativeType(name) ~= "string" then
		error("Argument 1 missing or nil", 2)
	end
	local c = findChild(self, name)
	if c then
		return c
	end
	local co = coroutine.running()
	if not coroutine.isyieldable() then
		error("WaitForChild cannot yield here", 2)
	end
	local w = { co = co, done = false }
	s.childWaiters = s.childWaiters or {}
	s.childWaiters[name] = s.childWaiters[name] or {}
	table.insert(s.childWaiters[name], w)
	local where = fullName(self)
	local tb = debug.traceback("", 2)
	if timeout then
		R.schedule(R.now + timeout, R.newThread(function()
			if not w.done then
				w.done = true
				R.deferThread(co, nil)
			end
		end))
	else
		R.schedule(R.now + 5, R.newThread(function()
			if not w.done then
				R.warn(string.format('Infinite yield possible on \'%s:WaitForChild("%s")\'%s', where, name, tb:gsub("\n", " | ")), "WaitForChild:" .. where .. "." .. name)
			end
		end))
	end
	return R.suspend()
end
I.m.waitForChild = I.m.WaitForChild

function R.destroy(inst)
	local s = S[inst]
	if s.destroyed then
		return
	end
	if s.isService then
		error("Unable to destroy a service", 3)
	end
	if s.sigs.Destroying then
		R.fire(s.sigs.Destroying)
	end
	for _, c in ipairs(table.clone(s.children)) do
		R.destroy(c)
	end
	if s.parent then
		R.setParent(inst, nil)
	end
	s.parentLocked = true
	s.destroyed = true
	R.flushDeferred = R.flushDeferred -- keep queued Destroying handlers
	for _, sig in pairs(s.sigs) do
		if sig ~= s.sigs.Destroying then
			R.disconnectAll(sig)
		end
	end
	for _, sig in pairs(s.propSigs) do
		R.disconnectAll(sig)
	end
	for _, sig in pairs(s.attrSigs) do
		R.disconnectAll(sig)
	end
	R.allInstances[inst] = nil
	if R.onDestroy then
		R.onDestroy(inst, s)
	end
end
I.m.Destroy = function(self)
	st(self, "Destroy")
	R.destroy(self)
end
I.m.destroy = I.m.Destroy
I.m.Remove = function(self)
	st(self, "Remove")
	R.setParent(self, nil)
end
I.m.ClearAllChildren = function(self)
	for _, c in ipairs(table.clone(st(self, "ClearAllChildren").children)) do
		R.destroy(c)
	end
end

function R.clone(inst, ignoreArchivable)
	local s = S[inst]
	if not ignoreArchivable and s.props.Archivable == false then
		return nil
	end
	local map = {}
	local order = {}
	local function copy(src, force)
		local ss = S[src]
		if ss.props.Archivable == false and not force then
			return nil
		end
		local n = R.create(ss.ClassName, true)
		local ns = S[n]
		for k, v in pairs(ss.props) do
			ns.props[k] = v
		end
		for k, v in pairs(ss.attrs) do
			ns.attrs[k] = v
		end
		for k in pairs(ss.tags) do
			ns.tags[k] = true
		end
		if ss.extra then
			ns.extra = table.clone(ss.extra)
		end
		ns.source = ss.source
		ns.sourcePath = ss.sourcePath
		map[src] = n
		table.insert(order, n)
		for _, c in ipairs(ss.children) do
			local cc = copy(c, false)
			if cc then
				S[cc].parent = n
				table.insert(ns.children, cc)
			end
		end
		return n
	end
	local root = copy(inst, ignoreArchivable)
	for _, n in ipairs(order) do
		local ns = S[n]
		for k, v in pairs(ns.props) do
			if R.isInstance(v) and map[v] then
				ns.props[k] = map[v]
			end
		end
	end
	for _, n in ipairs(order) do
		if R.onCreate then
			R.onCreate(n, S[n], true)
		end
	end
	return root
end
I.m.Clone = function(self)
	st(self, "Clone")
	return R.clone(self, false)
end
I.m.clone = I.m.Clone

-- Attributes
local ATTR_TYPES = {
	boolean = true, number = true, string = true, UDim = true, UDim2 = true, BrickColor = true, Color3 = true, Vector2 = true,
	Vector3 = true, CFrame = true, NumberSequence = true, ColorSequence = true, NumberRange = true, Rect = true, Font = true, EnumItem = true,
}
I.m.SetAttribute = function(self, name, value)
	local s = st(self, "SetAttribute")
	if nativeType(name) ~= "string" then
		error("Argument 1 missing or nil", 2)
	end
	if #name > 100 or not name:match("^[%w_]+$") or name:sub(1, 3) == "RBX" then
		error("Attribute name '" .. name .. "' is invalid (letters, digits and underscores only, max 100, no RBX prefix)", 2)
	end
	if value ~= nil and not ATTR_TYPES[R.typeof(value)] then
		error("Unable to set attribute '" .. name .. "': type " .. R.typeof(value) .. " is not supported", 2)
	end
	if value ~= value then
		R.warn("NaN stored in attribute " .. name)
	end
	local old = s.attrs[name]
	s.attrs[name] = value
	if old ~= value then
		if s.sigs.AttributeChanged then
			R.fire(s.sigs.AttributeChanged, name)
		end
		if s.attrSigs[name] then
			R.fire(s.attrSigs[name])
		end
	end
end
I.m.GetAttribute = function(self, name)
	return st(self, "GetAttribute").attrs[name]
end
I.m.GetAttributes = function(self)
	return table.clone(st(self, "GetAttributes").attrs)
end
I.m.GetAttributeChangedSignal = function(self, name)
	local s = st(self, "GetAttributeChangedSignal")
	local sig = s.attrSigs[name]
	if not sig then
		sig = R.newSignal("AttributeChanged:" .. tostring(name))
		s.attrSigs[name] = sig
	end
	return sig
end
I.m.GetPropertyChangedSignal = function(self, prop)
	local s = st(self, "GetPropertyChangedSignal")
	local d = R.member(s.ClassName, prop)
	if not d or d.kind ~= "prop" then
		error(tostring(prop) .. " is not a valid property name.", 2)
	end
	local sig = s.propSigs[prop]
	if not sig then
		sig = R.newSignal("PropertyChanged:" .. prop)
		s.propSigs[prop] = sig
	end
	return sig
end

-- Tags
function R.addTag(inst, tag)
	local s = S[inst]
	if s.tags[tag] then
		return
	end
	s.tags[tag] = true
	R.TAGGED[tag] = R.TAGGED[tag] or setmetatable({}, { __mode = "k" })
	R.TAGGED[tag][inst] = true
	if R.inGame(inst) then
		R.fire(tagSigs(tag).added, inst)
	end
end
function R.removeTag(inst, tag)
	local s = S[inst]
	if not s.tags[tag] then
		return
	end
	s.tags[tag] = nil
	if R.TAGGED[tag] then
		R.TAGGED[tag][inst] = nil
	end
	if R.inGame(inst) then
		R.fire(tagSigs(tag).removed, inst)
	end
end
I.m.AddTag = function(self, tag)
	st(self, "AddTag")
	R.addTag(self, tag)
end
I.m.RemoveTag = function(self, tag)
	st(self, "RemoveTag")
	R.removeTag(self, tag)
end
I.m.HasTag = function(self, tag)
	return st(self, "HasTag").tags[tag] == true
end
I.m.GetTags = function(self)
	local out = {}
	for t in pairs(st(self, "GetTags").tags) do
		table.insert(out, t)
	end
	return out
end

---------------------------------------------------------------------------------------------------- assets used (proprietary-art check)
R.ASSETS = {}
function R.noteAsset(uri, where)
	if nativeType(uri) ~= "string" then
		return
	end
	local id = uri:match("rbxassetid://(%d+)") or uri:match("[?&]id=(%d+)") or uri:match("^(%d+)$")
	if id then
		local a = R.ASSETS[id]
		if not a then
			a = { where = {} }
			R.ASSETS[id] = a
		end
		a.where[where] = true
	end
end

---------------------------------------------------------------------------------------------------- parts, joints, CFrames
R.JOINTS = setmetatable({}, { __mode = "k" }) -- part -> {joint = true}
local function partCF(p)
	return S[p].props.CFrame or IDENT
end
R.partCF = partCF

local function jointActive(js)
	return js.props.Enabled ~= false and js.props.Part0 and js.props.Part1 and not js.destroyed and js.props.Part0 ~= js.props.Part1
end

local function setPartCFRaw(p, value)
	local s = S[p]
	local old = s.props.CFrame
	value = R.cfOrtho(value)
	s.props.CFrame = value
	if old ~= value then
		R.firePropChanged(p, s, "CFrame", value)
		if s.propSigs.Position then
			R.fire(s.propSigs.Position)
		end
		if s.propSigs.Orientation then
			R.fire(s.propSigs.Orientation)
		end
	end
end
R.setPartCFRaw = setPartCFRaw

-- Move a part and everything jointed to it.
function R.movePart(p, value)
	setPartCFRaw(p, value)
	if not R.JOINTS[p] then
		return
	end
	local visited = { [p] = true }
	local queue = { p }
	local qi = 1
	while qi <= #queue do
		local cur = queue[qi]
		qi += 1
		local js = R.JOINTS[cur]
		if js then
			for j in pairs(js) do
				local s = S[j]
				if jointActive(s) then
					local p0, p1 = s.props.Part0, s.props.Part1
					local other = p0 == cur and p1 or p0
					if not visited[other] then
						visited[other] = true
						local ncf
						if s.ClassName == "WeldConstraint" or s.ClassName == "NoCollisionConstraint" then
							if s.ClassName == "WeldConstraint" then
								local rel = s.extra and s.extra.rel or IDENT
								if other == p1 then
									ncf = R.cfMul(partCF(p0), rel)
								else
									ncf = R.cfMul(partCF(p1), R.cfInv(rel))
								end
							end
						else
							local c0 = s.props.C0 or IDENT
							local c1 = s.props.C1 or IDENT
							local tr = s.props.Transform or IDENT
							if other == p1 then
								ncf = R.cfMul(R.cfMul(R.cfMul(partCF(p0), c0), tr), R.cfInv(c1))
							else
								ncf = R.cfMul(R.cfMul(partCF(p1), c1), R.cfInv(R.cfMul(c0, tr)))
							end
						end
						if ncf then
							setPartCFRaw(other, ncf)
							table.insert(queue, other)
						end
					end
				end
			end
		end
	end
end

local function unregisterJoint(j, s)
	for _, k in ipairs({ "_p0", "_p1" }) do
		local p = s[k]
		if p and R.JOINTS[p] then
			R.JOINTS[p][j] = nil
		end
		s[k] = nil
	end
end

function R.updateJoint(j, snap)
	local s = S[j]
	unregisterJoint(j, s)
	if not jointActive(s) then
		return
	end
	local p0, p1 = s.props.Part0, s.props.Part1
	s._p0, s._p1 = p0, p1
	R.JOINTS[p0] = R.JOINTS[p0] or {}
	R.JOINTS[p1] = R.JOINTS[p1] or {}
	R.JOINTS[p0][j] = true
	R.JOINTS[p1][j] = true
	s.extra = s.extra or {}
	if s.ClassName == "WeldConstraint" then
		if snap ~= false then
			s.extra.rel = R.cfMul(R.cfInv(partCF(p0)), partCF(p1))
		end
	elseif s.ClassName ~= "NoCollisionConstraint" and snap ~= false then
		-- Weld/Motor6D/Snap: Part1 snaps to Part0 * C0 * C1^-1
		R.movePart(p0, partCF(p0))
	end
end

for _, cls in ipairs({ "JointInstance", "WeldConstraint", "NoCollisionConstraint" }) do
	local b = B(cls)
	for _, prop in ipairs({ "Part0", "Part1", "Enabled", "C0", "C1" }) do
		b.set[prop] = function(inst, s, v)
			local old = s.props[prop]
			s.props[prop] = v
			if old ~= v then
				R.firePropChanged(inst, s, prop, v)
				R.updateJoint(inst)
			end
		end
	end
end

local BP = B("BasePart")
BP.get.CFrame = function(inst, s)
	return s.props.CFrame or IDENT
end
BP.set.CFrame = function(inst, s, v)
	if v.X ~= v.X or v.Y ~= v.Y or v.Z ~= v.Z then
		R.warn("NaN CFrame assigned to " .. fullName(inst))
	end
	R.movePart(inst, v)
end
BP.get.Position = function(inst, s)
	local c = s.props.CFrame or IDENT
	return v3(c.X, c.Y, c.Z)
end
BP.set.Position = function(inst, s, v)
	local c = s.props.CFrame or IDENT
	R.movePart(inst, R.cf(v.X, v.Y, v.Z, c.R00, c.R01, c.R02, c.R10, c.R11, c.R12, c.R20, c.R21, c.R22))
end
BP.get.Orientation = function(inst, s)
	local rx, ry, rz = (s.props.CFrame or IDENT):ToOrientation()
	return v3(math.deg(rx), math.deg(ry), math.deg(rz))
end
BP.set.Orientation = function(inst, s, v)
	local c = s.props.CFrame or IDENT
	local r = R.anglesYXZ(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))
	R.movePart(inst, R.cf(c.X, c.Y, c.Z, r.R00, r.R01, r.R02, r.R10, r.R11, r.R12, r.R20, r.R21, r.R22))
end
BP.get.Rotation = function(inst, s)
	local rx, ry, rz = (s.props.CFrame or IDENT):ToEulerAnglesXYZ()
	return v3(math.deg(rx), math.deg(ry), math.deg(rz))
end
BP.set.Rotation = function(inst, s, v)
	local c = s.props.CFrame or IDENT
	local r = G.CFrame.Angles(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))
	R.movePart(inst, R.cf(c.X, c.Y, c.Z, r.R00, r.R01, r.R02, r.R10, r.R11, r.R12, r.R20, r.R21, r.R22))
end
BP.set.Size = function(inst, s, v)
	v = v3(math.max(v.X, 0.001), math.max(v.Y, 0.001), math.max(v.Z, 0.001))
	if v.X ~= v.X or v.Y ~= v.Y or v.Z ~= v.Z then
		R.warn("NaN Size assigned to " .. fullName(inst))
	end
	R.rawSet(inst, "Size", v)
end
BP.get.BrickColor = function(inst, s)
	return R.nearestBrick(R.rawGet(inst, "Color"))
end
BP.set.BrickColor = function(inst, s, v)
	R.rawSet(inst, "Color", v.Color)
end
BP.get.ExtentsCFrame = BP.get.CFrame
BP.get.AssemblyMass = function(inst, s)
	local sz = R.rawGet(inst, "Size")
	return sz.X * sz.Y * sz.Z * 0.7
end
BP.get.Mass = BP.get.AssemblyMass
BP.get.AssemblyRootPart = function(inst)
	return inst
end
BP.m.GetMass = function(self)
	local sz = R.rawGet(self, "Size")
	return sz.X * sz.Y * sz.Z * 0.7
end

local function connected(p)
	local out, seen, queue = {}, { [p] = true }, { p }
	local qi = 1
	while qi <= #queue do
		local cur = queue[qi]
		qi += 1
		local js = R.JOINTS[cur]
		if js then
			for j in pairs(js) do
				local s = S[j]
				if jointActive(s) and s.ClassName ~= "NoCollisionConstraint" then
					for _, o in ipairs({ s.props.Part0, s.props.Part1 }) do
						if not seen[o] then
							seen[o] = true
							table.insert(out, o)
							table.insert(queue, o)
						end
					end
				end
			end
		end
	end
	return out
end
R.connectedParts = connected
function R.isGrounded(p)
	if R.rawGet(p, "Anchored") then
		return true
	end
	for _, o in ipairs(connected(p)) do
		if R.rawGet(o, "Anchored") then
			return true
		end
	end
	return false
end
BP.m.GetConnectedParts = function(self)
	return connected(self)
end
BP.m.GetJoints = function(self)
	local out = {}
	for j in pairs(R.JOINTS[self] or {}) do
		table.insert(out, j)
	end
	return out
end
BP.m.GetRootPart = function(self)
	return self
end
BP.m.IsGrounded = function(self)
	return R.isGrounded(self)
end
BP.m.SetNetworkOwner = function(self, owner)
	if R.isGrounded(self) then
		error("Network Ownership API cannot be called on Anchored parts or parts welded to Anchored parts.", 2)
	end
	if R.CUR and R.CUR.name ~= "server" then
		error("SetNetworkOwner can only be called from the server", 2)
	end
	S[self].netOwner = owner
end
BP.m.SetNetworkOwnershipAuto = function(self)
	if R.isGrounded(self) then
		error("Network Ownership API cannot be called on Anchored parts or parts welded to Anchored parts.", 2)
	end
end
BP.m.GetNetworkOwner = function(self)
	return S[self].netOwner
end
BP.m.CanSetNetworkOwnership = function(self)
	if R.isGrounded(self) then
		return false, "Cannot change network ownership of anchored part"
	end
	return true, nil
end
BP.m.ApplyImpulse = function() end
BP.m.ApplyAngularImpulse = function() end
BP.m.ApplyImpulseAtPosition = function() end
BP.m.GetVelocityAtPosition = function()
	return v3(0, 0, 0)
end
BP.m.BreakJoints = function(self)
	for j in pairs(R.JOINTS[self] or {}) do
		R.destroy(j)
	end
end
BP.m.MakeJoints = function() end
BP.m.Resize = function()
	return true
end
BP.m.GetTouchingParts = function(self)
	return R.partsOverlapping(self)
end
BP.m.GetClosestPointOnSurface = function(self, p)
	return p
end
BP.m.SubtractAsync = function(self)
	R.note("CSG SubtractAsync used (simulated as a clone)")
	return R.clone(self, true)
end
BP.m.UnionAsync = BP.m.SubtractAsync
BP.m.IntersectAsync = BP.m.SubtractAsync

-- PVInstance pivots
local PV = B("PVInstance")
PV.m.GetPivot = function(self)
	local s = st(self, "GetPivot")
	if R.classIsA(s.ClassName, "BasePart") then
		return R.cfMul(partCF(self), R.rawGet(self, "PivotOffset") or IDENT)
	end
	return R.modelPivot(self)
end
PV.m.PivotTo = function(self, target)
	local s = st(self, "PivotTo")
	if R.typeof(target) ~= "CFrame" then
		error("invalid argument #1 to 'PivotTo' (CFrame expected, got " .. R.typeof(target) .. ")", 2)
	end
	if R.classIsA(s.ClassName, "BasePart") then
		local off = R.rawGet(self, "PivotOffset") or IDENT
		R.movePart(self, R.cfMul(target, R.cfInv(off)))
		return
	end
	R.modelPivotTo(self, target)
end

---------------------------------------------------------------------------------------------------- models
local function modelParts(model)
	local out = {}
	for _, d in ipairs(descendants(model)) do
		if R.classIsA(S[d].ClassName, "BasePart") then
			table.insert(out, d)
		end
	end
	return out
end
R.modelParts = modelParts

local function aabb(p)
	local c = partCF(p)
	local sz = R.rawGet(p, "Size")
	local hx, hy, hz = sz.X / 2, sz.Y / 2, sz.Z / 2
	local ex = math.abs(c.R00) * hx + math.abs(c.R01) * hy + math.abs(c.R02) * hz
	local ey = math.abs(c.R10) * hx + math.abs(c.R11) * hy + math.abs(c.R12) * hz
	local ez = math.abs(c.R20) * hx + math.abs(c.R21) * hy + math.abs(c.R22) * hz
	return c.X - ex, c.Y - ey, c.Z - ez, c.X + ex, c.Y + ey, c.Z + ez
end
R.aabb = aabb

local function bbox(parts)
	if #parts == 0 then
		return nil
	end
	local x0, y0, z0, x1, y1, z1 = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
	for _, p in ipairs(parts) do
		local a, b, c, d, e, f = aabb(p)
		x0, y0, z0 = math.min(x0, a), math.min(y0, b), math.min(z0, c)
		x1, y1, z1 = math.max(x1, d), math.max(y1, e), math.max(z1, f)
	end
	return v3((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), v3(x1 - x0, y1 - y0, z1 - z0)
end
R.bbox = bbox

function R.modelPivot(model)
	local s = S[model]
	local pp = s.props.PrimaryPart
	if pp and not S[pp].destroyed then
		return R.cfMul(partCF(pp), R.rawGet(pp, "PivotOffset") or IDENT)
	end
	if s.props.WorldPivot then
		return s.props.WorldPivot
	end
	local c = bbox(modelParts(model))
	if c then
		local piv = R.cf(c.X, c.Y, c.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
		s.props.WorldPivot = piv
		return piv
	end
	return IDENT
end

function R.modelPivotTo(model, target)
	local s = S[model]
	local piv = R.cfOrtho(R.modelPivot(model))
	target = R.cfOrtho(target)
	local delta = R.cfMul(target, R.cfInv(piv))
	for _, p in ipairs(modelParts(model)) do
		setPartCFRaw(p, R.cfMul(delta, partCF(p)))
	end
	if not s.props.PrimaryPart then
		s.props.WorldPivot = target
	end
	-- parts outside the model jointed to it follow
	for _, p in ipairs(modelParts(model)) do
		if R.JOINTS[p] then
			for j in pairs(R.JOINTS[p]) do
				local js = S[j]
				for _, o in ipairs({ js.props.Part0, js.props.Part1 }) do
					if o and not isDescendantOf(o, model) then
						R.movePart(p, partCF(p))
						break
					end
				end
			end
		end
	end
end

local M = B("Model")
M.get.WorldPivot = function(inst)
	return R.modelPivot(inst)
end
M.set.WorldPivot = function(inst, s, v)
	s.props.WorldPivot = v
end
M.m.GetBoundingBox = function(self)
	local c, size = bbox(modelParts(self))
	if not c then
		return IDENT, v3(0, 0, 0)
	end
	return R.cf(c.X, c.Y, c.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1), size
end
M.m.GetExtentsSize = function(self)
	local _, size = bbox(modelParts(self))
	return size or v3(0, 0, 0)
end
M.m.GetModelCFrame = function(self)
	return R.modelPivot(self)
end
M.m.MoveTo = function(self, pos)
	local piv = R.modelPivot(self)
	R.modelPivotTo(self, R.cf(pos.X, pos.Y, pos.Z, piv.R00, piv.R01, piv.R02, piv.R10, piv.R11, piv.R12, piv.R20, piv.R21, piv.R22))
end
M.m.TranslateBy = function(self, d)
	R.modelPivotTo(self, R.modelPivot(self) + d)
end
M.m.SetPrimaryPartCFrame = function(self, c)
	local s = st(self, "SetPrimaryPartCFrame")
	if not s.props.PrimaryPart then
		error("Model:SetPrimaryPartCFrame() failed because no PrimaryPart has been set, or the PrimaryPart no longer exists. Please set Model.PrimaryPart before using this.", 2)
	end
	R.modelPivotTo(self, R.cfMul(c, R.rawGet(s.props.PrimaryPart, "PivotOffset") or IDENT))
end
M.m.GetPrimaryPartCFrame = function(self)
	local s = st(self, "GetPrimaryPartCFrame")
	if not s.props.PrimaryPart then
		error("Model:GetPrimaryPartCFrame() failed because no PrimaryPart has been set", 2)
	end
	return partCF(s.props.PrimaryPart)
end
M.m.GetScale = function(self)
	local s = st(self, "GetScale")
	return s.extra and s.extra.scale or 1
end
M.m.ScaleTo = function(self, scale)
	local s = st(self, "ScaleTo")
	if nativeType(scale) ~= "number" or scale <= 0 or scale ~= scale then
		error("Model:ScaleTo() requires a positive number", 2)
	end
	s.extra = s.extra or {}
	local cur = s.extra.scale or 1
	local f = scale / cur
	local piv = R.modelPivot(self)
	local inv = R.cfInv(piv)
	for _, p in ipairs(modelParts(self)) do
		local rel = R.cfMul(inv, partCF(p))
		local scaled = R.cf(rel.X * f, rel.Y * f, rel.Z * f, rel.R00, rel.R01, rel.R02, rel.R10, rel.R11, rel.R12, rel.R20, rel.R21, rel.R22)
		setPartCFRaw(p, R.cfMul(piv, scaled))
		local sz = R.rawGet(p, "Size")
		R.rawSet(p, "Size", sz * f)
	end
	s.extra.scale = scale
end
M.m.BreakJoints = function() end
M.m.MakeJoints = function() end

---------------------------------------------------------------------------------------------------- attachments
local AT = B("Attachment")
local function attParentCF(inst)
	local p = S[inst].parent
	if p and R.classIsA(S[p].ClassName, "BasePart") then
		return partCF(p)
	end
	return IDENT
end
AT.get.WorldCFrame = function(inst, s)
	return R.cfMul(attParentCF(inst), s.props.CFrame or IDENT)
end
AT.set.WorldCFrame = function(inst, s, v)
	R.rawSet(inst, "CFrame", R.cfMul(R.cfInv(attParentCF(inst)), v))
end
AT.get.WorldPosition = function(inst, s)
	return R.cfPoint(attParentCF(inst), (s.props.CFrame or IDENT).Position)
end
AT.set.WorldPosition = function(inst, s, v)
	local c = s.props.CFrame or IDENT
	local lp = R.cfPoint(R.cfInv(attParentCF(inst)), v)
	R.rawSet(inst, "CFrame", R.cf(lp.X, lp.Y, lp.Z, c.R00, c.R01, c.R02, c.R10, c.R11, c.R12, c.R20, c.R21, c.R22))
end
AT.get.Position = function(inst, s)
	return (s.props.CFrame or IDENT).Position
end
AT.set.Position = function(inst, s, v)
	local c = s.props.CFrame or IDENT
	R.rawSet(inst, "CFrame", R.cf(v.X, v.Y, v.Z, c.R00, c.R01, c.R02, c.R10, c.R11, c.R12, c.R20, c.R21, c.R22))
end
AT.get.Orientation = function(inst, s)
	local rx, ry, rz = (s.props.CFrame or IDENT):ToOrientation()
	return v3(math.deg(rx), math.deg(ry), math.deg(rz))
end
AT.set.Orientation = function(inst, s, v)
	local c = s.props.CFrame or IDENT
	local r = R.anglesYXZ(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))
	R.rawSet(inst, "CFrame", R.cf(c.X, c.Y, c.Z, r.R00, r.R01, r.R02, r.R10, r.R11, r.R12, r.R20, r.R21, r.R22))
end
AT.get.WorldOrientation = function(inst, s)
	local rx, ry, rz = AT.get.WorldCFrame(inst, s):ToOrientation()
	return v3(math.deg(rx), math.deg(ry), math.deg(rz))
end
AT.get.Axis = function(inst, s)
	return (s.props.CFrame or IDENT).RightVector
end
AT.get.SecondaryAxis = function(inst, s)
	return (s.props.CFrame or IDENT).UpVector
end
AT.get.WorldAxis = function(inst, s)
	return AT.get.WorldCFrame(inst, s).RightVector
end
AT.get.WorldSecondaryAxis = function(inst, s)
	return AT.get.WorldCFrame(inst, s).UpVector
end

---------------------------------------------------------------------------------------------------- GUI geometry (approximate)
R.SCREEN = v2(1280, 720)
R.GUI_INSET = 58
local function guiRect(inst)
	local s = S[inst]
	if R.classIsA(s.ClassName, "LayerCollector") then
		if s.ClassName == "ScreenGui" then
			local inset = (R.rawGet(inst, "IgnoreGuiInset") or R.rawGet(inst, "ScreenInsets") == R.enumItem("ScreenInsets", "None")) and 0 or R.GUI_INSET
			return 0, inset, R.SCREEN.X, R.SCREEN.Y - inset
		end
		return 0, 0, 200, 60
	end
	local p = s.parent
	if not p or not R.classIsA(S[p].ClassName, "GuiBase2d") then
		return 0, 0, 0, 0
	end
	local px, py, pw, ph = guiRect(p)
	local size = R.rawGet(inst, "Size")
	local pos = R.rawGet(inst, "Position")
	local ap = R.rawGet(inst, "AnchorPoint") or v2(0, 0)
	local w = pw * size.X.Scale + size.X.Offset
	local h = ph * size.Y.Scale + size.Y.Offset
	for _, c in ipairs(s.children) do
		local cs = S[c]
		if cs.ClassName == "UIAspectRatioConstraint" then
			local ar = R.rawGet(c, "AspectRatio")
			if ar and ar > 0 and h > 0 then
				if w / h > ar then
					w = h * ar
				else
					h = w / ar
				end
			end
		elseif cs.ClassName == "UISizeConstraint" then
			local mn, mx = R.rawGet(c, "MinSize"), R.rawGet(c, "MaxSize")
			w = math.clamp(w, mn.X, math.max(mn.X, mx.X))
			h = math.clamp(h, mn.Y, math.max(mn.Y, mx.Y))
		end
	end
	local x = px + pw * pos.X.Scale + pos.X.Offset - w * ap.X
	local y = py + ph * pos.Y.Scale + pos.Y.Offset - h * ap.Y
	return x, y, w, h
end
R.guiRect = guiRect
local GB = B("GuiBase2d")
GB.get.AbsoluteSize = function(inst)
	local _, _, w, h = guiRect(inst)
	return v2(w, h)
end
GB.get.AbsolutePosition = function(inst)
	local x, y = guiRect(inst)
	return v2(x, y)
end
GB.get.AbsoluteRotation = function()
	return 0
end
local function textBounds(inst)
	local t = tostring(R.rawGet(inst, "Text") or "")
	local size = R.rawGet(inst, "TextSize") or 14
	return v2(#t * size * 0.5, size)
end
for _, cls in ipairs({ "TextLabel", "TextButton", "TextBox" }) do
	B(cls).get.TextBounds = textBounds
	B(cls).get.TextFits = function()
		return true
	end
	B(cls).get.ContentText = function(inst)
		return R.rawGet(inst, "Text")
	end
end
B("UIGridStyleLayout").get.AbsoluteContentSize = function(inst)
	local p = S[inst].parent
	if not p then
		return v2(0, 0)
	end
	local tw, th = 0, 0
	local horizontal = R.rawGet(inst, "FillDirection") == R.enumItem("FillDirection", "Horizontal")
	for _, c in ipairs(S[p].children) do
		if R.classIsA(S[c].ClassName, "GuiObject") and R.rawGet(c, "Visible") then
			local _, _, w, h = guiRect(c)
			if horizontal then
				tw += w
				th = math.max(th, h)
			else
				th += h
				tw = math.max(tw, w)
			end
		end
	end
	return v2(tw, th)
end
B("ScrollingFrame").get.AbsoluteCanvasSize = function(inst)
	local _, _, w, h = guiRect(inst)
	return v2(w, h)
end
B("ScrollingFrame").get.AbsoluteWindowSize = B("ScrollingFrame").get.AbsoluteCanvasSize
B("TextBox").m.CaptureFocus = function() end
B("TextBox").m.ReleaseFocus = function() end
B("TextBox").m.IsFocused = function()
	return false
end
local GO = B("GuiObject")
local function guiTween(self, props, info, callback)
	local t = R.tweenCreate(self, info, props)
	if callback then
		R.getSignal(S[t], "Completed"):Connect(function(state)
			callback(state)
		end)
	end
	R.tweenPlay(t)
	return true
end
GO.m.TweenPosition = function(self, pos, dir, style, time, override, callback)
	return guiTween(self, { Position = pos }, G.TweenInfo.new(time or 1, style, dir), callback)
end
GO.m.TweenSize = function(self, size, dir, style, time, override, callback)
	return guiTween(self, { Size = size }, G.TweenInfo.new(time or 1, style, dir), callback)
end
GO.m.TweenSizeAndPosition = function(self, size, pos, dir, style, time, override, callback)
	return guiTween(self, { Size = size, Position = pos }, G.TweenInfo.new(time or 1, style, dir), callback)
end
B("BasePlayerGui").m.GetGuiObjectsAtPosition = function()
	return {}
end

---------------------------------------------------------------------------------------------------- remotes & bindables
local REPLICATED_ROOTS = { Workspace = true, ReplicatedStorage = true, ReplicatedFirst = true, Players = true, Lighting = true, Teams = true, SoundService = true, StarterGui = true, StarterPack = true, StarterPlayer = true, MaterialService = true, TextChatService = true, Chat = true }
local function replicatesTo(inst, toCtx)
	local s = S[inst]
	if s.destroyed then
		return false
	end
	if toCtx == "client" then
		if s.createdBy == "client" then
			return true
		end
		local cur = inst
		while cur do
			local cs = S[cur]
			if cs.parent == R.game then
				return REPLICATED_ROOTS[cs.ClassName] == true
			end
			cur = cs.parent
		end
		return false
	else
		return s.createdBy ~= "client"
	end
end

-- Copy remote arguments the way Roblox serialises them.
local function ser(v, toCtx, seen, path, mode)
	local t = nativeType(v)
	if t == "table" then
		local mt = getmetatable(v)
		if mt and R.TYPENAME[mt] then
			return v
		end
		if seen[v] then
			error("tables cannot be cyclic", 0)
		end
		seen[v] = true
		local out = {}
		local n = #v
		local isArray = true
		local count = 0
		for k in pairs(v) do
			count += 1
			if nativeType(k) ~= "number" or k < 1 or k > n or k % 1 ~= 0 then
				isArray = false
			end
		end
		if mt and mode ~= "bindable" then
			R.warn("table with a metatable sent over " .. path .. " (metatable is dropped)", "remote metatable " .. path)
		end
		for k, x in pairs(v) do
			local key = k
			if not isArray and nativeType(k) ~= "string" then
				if mode == "remote" then
					if nativeType(k) == "number" then
						R.warn("table with non-string keys sent over " .. path .. " (Roblox converts them to strings or drops them)", "remote numeric keys " .. path)
						key = tostring(k)
					else
						R.warn("table with " .. R.typeof(k) .. " keys sent over " .. path .. " (Roblox drops them)", "remote keys " .. path)
						key = nil
					end
				end
			end
			if key ~= nil then
				out[key] = ser(x, toCtx, seen, path, mode)
			end
		end
		seen[v] = nil
		return out
	elseif t == "function" then
		if mode == "remote" then
			R.warn("function sent over " .. path .. " (Roblox sends nil)", "remote function " .. path)
			return nil
		end
		return v
	elseif t == "userdata" and R.isInstance(v) then
		if mode == "remote" and not replicatesTo(v, toCtx) then
			R.warn(string.format("instance %s sent over %s does not exist on the %s (arrives as nil)", fullName(v), path, toCtx), "remote inst " .. path)
			return nil
		end
		return v
	elseif t == "thread" then
		return nil
	end
	return v
end
function R.serializeArgs(toCtx, path, mode, ...)
	local n = select("#", ...)
	local args = { ... }
	local out = {}
	for i = 1, n do
		out[i] = ser(args[i], toCtx, {}, path, mode)
	end
	return out, n
end

local function requireCtx(name, method)
	if not R.CUR or R.CUR.name ~= name then
		error(method .. " can only be called from the " .. (name == "server" and "server" or "client"), 3)
	end
end

local RE = B("BaseRemoteEvent")
RE.events.OnServerEvent = { only = "server" }
RE.events.OnClientEvent = { only = "client" }
RE.m.FireServer = function(self, ...)
	local s = st(self, "FireServer")
	requireCtx("client", "FireServer")
	local player = R.CLIENT.player
	local args, n = R.serializeArgs("server", "RemoteEvent " .. s.props.Name, "remote", ...)
	R.stats.remoteIn += 1
	R.fire(R.getSignal(s, "OnServerEvent", { only = "server" }), player, table.unpack(args, 1, n))
end
local function sendToClient(s, player, ...)
	if not R.isInstance(player) or S[player].ClassName ~= "Player" then
		error("FireClient: player argument must be a Player object", 3)
	end
	R.stats.remoteOut += 1
	if not R.CLIENT or R.CLIENT.player ~= player then
		return
	end
	local args, n = R.serializeArgs("client", "RemoteEvent " .. s.props.Name, "remote", ...)
	R.fire(R.getSignal(s, "OnClientEvent", { only = "client" }), table.unpack(args, 1, n))
end
RE.m.FireClient = function(self, player, ...)
	local s = st(self, "FireClient")
	requireCtx("server", "FireClient")
	sendToClient(s, player, ...)
end
RE.m.FireAllClients = function(self, ...)
	local s = st(self, "FireAllClients")
	requireCtx("server", "FireAllClients")
	for _, p in ipairs(R.playerList()) do
		sendToClient(s, p, ...)
	end
end

local function waitCallback(s, key, label)
	local waited = 0
	while not s.callbacks[key] do
		waited += R.sleep(R.FRAME)
		if waited > 5 and not s.warnedCb then
			s.warnedCb = true
			R.warn(label .. " invoked but " .. key .. " is never set (caller yields forever)")
		end
	end
	return s.callbacks[key], s.callbackCtx[key]
end

local function invoke(cb, ctx, ...)
	local caller = coroutine.running()
	local co = R.newThread(function(...)
		local res = table.pack(pcall(cb, ...))
		R.deferThread(caller, res)
	end, ctx)
	R.resume(co, ...)
	local res = R.suspend()
	return res
end

local RF = B("RemoteFunction")
RF.m.InvokeServer = function(self, ...)
	local s = st(self, "InvokeServer")
	requireCtx("client", "InvokeServer")
	local args, n = R.serializeArgs("server", "RemoteFunction " .. s.props.Name, "remote", ...)
	local cb, ctx = waitCallback(s, "OnServerInvoke", "RemoteFunction " .. s.props.Name)
	R.stats.remoteIn += 1
	local res = invoke(cb, ctx, R.CLIENT.player, table.unpack(args, 1, n))
	if not res[1] then
		error(res[2], 2)
	end
	local out, m = R.serializeArgs("client", "RemoteFunction " .. s.props.Name .. " (return)", "remote", table.unpack(res, 2, res.n))
	return table.unpack(out, 1, m)
end
RF.m.InvokeClient = function(self, player, ...)
	local s = st(self, "InvokeClient")
	requireCtx("server", "InvokeClient")
	if not R.CLIENT or R.CLIENT.player ~= player then
		R.note("InvokeClient to a player without a simulated client returns nil")
		return nil
	end
	local args, n = R.serializeArgs("client", "RemoteFunction " .. s.props.Name, "remote", ...)
	local cb, ctx = waitCallback(s, "OnClientInvoke", "RemoteFunction " .. s.props.Name)
	local res = invoke(cb, ctx, table.unpack(args, 1, n))
	if not res[1] then
		error(res[2], 2)
	end
	return table.unpack(res, 2, res.n)
end

local BE = B("BindableEvent")
BE.m.Fire = function(self, ...)
	local s = st(self, "Fire")
	local args, n = R.serializeArgs(R.CUR and R.CUR.name or "server", "BindableEvent " .. s.props.Name, "bindable", ...)
	R.fire(R.getSignal(s, "Event"), table.unpack(args, 1, n))
end
local BF = B("BindableFunction")
BF.m.Invoke = function(self, ...)
	local s = st(self, "Invoke")
	local cb, ctx = waitCallback(s, "OnInvoke", "BindableFunction " .. s.props.Name)
	local res = invoke(cb, ctx, ...)
	if not res[1] then
		error(res[2], 2)
	end
	return table.unpack(res, 2, res.n)
end

---------------------------------------------------------------------------------------------------- sounds, particles, animation
local SND = B("Sound")
SND.get.IsPlaying = function(inst)
	return R.rawGet(inst, "Playing") == true
end
SND.get.IsLoaded = function()
	return true
end
SND.get.IsPaused = function(inst)
	return not R.rawGet(inst, "Playing")
end
SND.get.TimeLength = function(inst)
	return R.rawGet(inst, "SoundId") ~= "" and 2 or 0
end
SND.m.Play = function(self)
	local s = st(self, "Play")
	if R.rawGet(self, "SoundId") == "" then
		R.note("Sound played with an empty SoundId")
	end
	R.rawSet(self, "Playing", true)
	R.stats.sounds += 1
	s.playToken = (s.playToken or 0) + 1
	local token = s.playToken
	R.fire(R.getSignal(s, "Played"), R.rawGet(self, "SoundId"))
	if not R.rawGet(self, "Looped") then
		R.schedule(R.now + 2 / math.max(R.rawGet(self, "PlaybackSpeed") or 1, 0.05), R.newThread(function()
			if s.playToken == token and not s.destroyed and R.rawGet(self, "Playing") then
				R.rawSet(self, "Playing", false)
				R.fire(R.getSignal(s, "Ended"), R.rawGet(self, "SoundId"))
			end
		end))
	end
end
SND.m.Stop = function(self)
	local s = st(self, "Stop")
	R.rawSet(self, "Playing", false)
	s.playToken = (s.playToken or 0) + 1
	R.fire(R.getSignal(s, "Stopped"), R.rawGet(self, "SoundId"))
end
SND.m.Pause = function(self)
	R.rawSet(self, "Playing", false)
end
SND.m.Resume = function(self)
	R.rawSet(self, "Playing", true)
end
B("SoundService").m.PlayLocalSound = function(self, sound)
	R.stats.sounds += 1
end
B("ParticleEmitter").m.Emit = function(self, n)
	if n ~= nil and nativeType(n) ~= "number" then
		error("invalid argument #1 to 'Emit' (number expected)", 2)
	end
end
B("ParticleEmitter").m.Clear = function() end

local function newTrack(anim)
	local t = R.create("AnimationTrack")
	local ts = S[t]
	ts.props.Animation = anim
	ts.props.Name = anim and S[anim].props.Name or "Track"
	ts.props.Length = 1
	ts.props.Speed = 1
	ts.props.WeightCurrent = 1
	return t
end
local AT2 = B("AnimationTrack")
AT2.m.Play = function(self, fade, weight, speed)
	R.rawSet(self, "IsPlaying", true)
	if speed then
		R.rawSet(self, "Speed", speed)
	end
	local s = S[self]
	s.playToken = (s.playToken or 0) + 1
	local token = s.playToken
	if not R.rawGet(self, "Looped") then
		R.schedule(R.now + 1, R.newThread(function()
			if s.playToken == token and R.rawGet(self, "IsPlaying") then
				R.rawSet(self, "IsPlaying", false)
				R.fire(R.getSignal(s, "Stopped"))
				R.fire(R.getSignal(s, "Ended"))
			end
		end))
	end
end
AT2.m.Stop = function(self)
	local s = S[self]
	s.playToken = (s.playToken or 0) + 1
	if R.rawGet(self, "IsPlaying") then
		R.rawSet(self, "IsPlaying", false)
		R.fire(R.getSignal(s, "Stopped"))
	end
end
AT2.m.AdjustSpeed = function(self, sp)
	R.rawSet(self, "Speed", sp or 1)
end
AT2.m.AdjustWeight = function() end
AT2.m.GetMarkerReachedSignal = function(self, name)
	return R.newSignal("Marker:" .. tostring(name))
end
AT2.m.GetTimeOfKeyframe = function()
	return 0
end
B("Animator").m.LoadAnimation = function(self, anim)
	checkInstance(anim, "LoadAnimation", 1)
	if S[anim].ClassName ~= "Animation" then
		error("LoadAnimation requires an Animation object", 2)
	end
	R.noteAsset(R.rawGet(anim, "AnimationId"), "Animation.AnimationId")
	return newTrack(anim)
end
B("Animator").m.GetPlayingAnimationTracks = function()
	return {}
end
B("AnimationController").m.LoadAnimation = B("Animator").m.LoadAnimation

---------------------------------------------------------------------------------------------------- tweens
local EASE = {}
local pi = math.pi
EASE.Linear = function(t)
	return t
end
EASE.Sine = function(t)
	return 1 - math.cos(t * pi / 2)
end
EASE.Quad = function(t)
	return t * t
end
EASE.Cubic = function(t)
	return t * t * t
end
EASE.Quart = function(t)
	return t ^ 4
end
EASE.Quint = function(t)
	return t ^ 5
end
EASE.Exponential = function(t)
	return t == 0 and 0 or 2 ^ (10 * t - 10)
end
EASE.Circular = function(t)
	return 1 - math.sqrt(math.max(0, 1 - t * t))
end
EASE.Back = function(t)
	local c1 = 1.70158
	return (c1 + 1) * t ^ 3 - c1 * t * t
end
EASE.Elastic = function(t)
	if t == 0 or t == 1 then
		return t
	end
	return -(2 ^ (10 * t - 10)) * math.sin((t * 10 - 10.75) * (2 * pi / 3))
end
local function bounceOut(t)
	local n1, d1 = 7.5625, 2.75
	if t < 1 / d1 then
		return n1 * t * t
	elseif t < 2 / d1 then
		t -= 1.5 / d1
		return n1 * t * t + 0.75
	elseif t < 2.5 / d1 then
		t -= 2.25 / d1
		return n1 * t * t + 0.9375
	end
	t -= 2.625 / d1
	return n1 * t * t + 0.984375
end
EASE.Bounce = function(t)
	return 1 - bounceOut(1 - t)
end
function R.ease(alpha, style, dir)
	local f = EASE[style and style.Name or "Quad"] or EASE.Quad
	local d = dir and dir.Name or "Out"
	if d == "In" then
		return f(alpha)
	elseif d == "Out" then
		return 1 - f(1 - alpha)
	end
	if alpha < 0.5 then
		return f(alpha * 2) / 2
	end
	return 1 - f((1 - alpha) * 2) / 2
end

local TWEENABLE = { number = true, Vector3 = true, Vector2 = true, CFrame = true, Color3 = true, UDim2 = true, UDim = true, Rect = true, NumberRange = true, boolean = true }
local function lerp(a, b, t)
	local ty = R.typeof(a)
	if ty == "number" then
		return a + (b - a) * t
	elseif ty == "boolean" then
		return t >= 1 and b or a
	elseif ty == "Vector3" or ty == "Vector2" or ty == "Color3" or ty == "CFrame" or ty == "UDim2" then
		return a:Lerp(b, t)
	elseif ty == "UDim" then
		return R.udim(a.Scale + (b.Scale - a.Scale) * t, a.Offset + (b.Offset - a.Offset) * t)
	end
	return t >= 1 and b or a
end

R.TWEENS = {}
function R.tweenCreate(inst, info, goals)
	checkInstance(inst, "Create", 1)
	if R.typeof(info) ~= "TweenInfo" then
		error("invalid argument #2 to 'Create' (TweenInfo expected, got " .. R.typeof(info) .. ")", 3)
	end
	if nativeType(goals) ~= "table" then
		error("invalid argument #3 to 'Create' (table expected, got " .. R.typeof(goals) .. ")", 3)
	end
	local s = S[inst]
	for k, v in pairs(goals) do
		local d = R.member(s.ClassName, k)
		if not d or d.kind ~= "prop" then
			error(string.format("TweenService:Create no property named '%s' for object '%s'", tostring(k), s.props.Name), 3)
		end
		local cur = inst[k]
		local ty = R.typeof(v)
		if not TWEENABLE[ty] then
			error(string.format("TweenService:Create property named '%s' cannot be tweened due to type mismatch (property is a '%s', but given type is '%s')", k, R.typeof(cur), ty), 3)
		end
		if cur ~= nil and R.typeof(cur) ~= ty and not (R.typeof(cur) == "EnumItem") then
			error(string.format("TweenService:Create property named '%s' cannot be tweened due to type mismatch (property is a '%s', but given type is '%s')", k, R.typeof(cur), ty), 3)
		end
	end
	local t = R.create("Tween")
	local ts = S[t]
	ts.props.Instance = inst
	ts.props.TweenInfo = info
	ts.extra = { goals = table.clone(goals) }
	ts.props.PlaybackState = R.enumItem("PlaybackState", "Begin")
	return t
end
function R.tweenPlay(t)
	local ts = S[t]
	local e = ts.extra
	if e.active then
		return
	end
	-- a newer tween on the same property overrides older ones (Roblox cancels the old tween's properties)
	local target = ts.props.Instance
	for other in pairs(R.TWEENS) do
		local os_ = S[other]
		if os_.props.Instance == target and other ~= t then
			for k in pairs(e.goals) do
				os_.extra.goals[k] = nil
			end
		end
	end
	e.active = true
	e.start = R.now + (ts.props.TweenInfo.DelayTime or 0)
	e.from = nil
	e.iter = 0
	e.reverse = false
	ts.props.PlaybackState = R.enumItem("PlaybackState", e.start > R.now and "Delayed" or "Playing")
	R.TWEENS[t] = true
end
local function tweenFinish(t, state)
	local ts = S[t]
	ts.extra.active = false
	R.TWEENS[t] = nil
	ts.props.PlaybackState = R.enumItem("PlaybackState", state)
	R.fire(R.getSignal(ts, "Completed"), R.enumItem("PlaybackState", state))
end
function R.tweenStep()
	for t in pairs(R.TWEENS) do
		local ts = S[t]
		local e = ts.extra
		local inst = ts.props.Instance
		local info = ts.props.TweenInfo
		if S[inst].destroyed then
			R.TWEENS[t] = nil
			e.active = false
		elseif R.now >= e.start then
			if not e.from then
				e.from = {}
				for k in pairs(e.goals) do
					e.from[k] = inst[k]
				end
				ts.props.PlaybackState = R.enumItem("PlaybackState", "Playing")
			end
			local dur = math.max(info.Time, 1e-6)
			local raw = math.min((R.now - e.start) / dur, 1)
			local a = R.ease(raw, info.EasingStyle, info.EasingDirection)
			if e.reverse then
				a = 1 - a
			end
			for k, goal in pairs(e.goals) do
				local ok, err = pcall(function()
					inst[k] = lerp(e.from[k], goal, a)
				end)
				if not ok then
					R.reportError("Tween set " .. k .. ": " .. tostring(err))
					e.goals[k] = nil
				end
			end
			if raw >= 1 then
				if info.Reverses and not e.reverse then
					e.reverse = true
					e.start = R.now
				else
					e.iter += 1
					if info.RepeatCount < 0 or e.iter <= info.RepeatCount then
						e.reverse = false
						e.start = R.now + (info.DelayTime or 0)
					else
						tweenFinish(t, "Completed")
					end
				end
			end
		end
	end
end
local TW = B("Tween")
TW.m.Play = function(self)
	st(self, "Play")
	R.tweenPlay(self)
end
TW.m.Cancel = function(self)
	local s = st(self, "Cancel")
	if s.extra.active then
		tweenFinish(self, "Cancelled")
	end
end
TW.m.Pause = function(self)
	local s = st(self, "Pause")
	if s.extra.active then
		s.extra.active = false
		R.TWEENS[self] = nil
		s.props.PlaybackState = R.enumItem("PlaybackState", "Paused")
	end
end
B("TweenBase").get.PlaybackState = function(inst, s)
	return s.props.PlaybackState
end

---------------------------------------------------------------------------------------------------- values
for _, cls in ipairs({ "ValueBase" }) do
	B(cls).events.Changed = nil
end

return true

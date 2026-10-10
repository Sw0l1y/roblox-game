-- Simulator core: enums, virtual-time scheduler with server/client contexts, signals, and the Instance object
-- model driven by Roblox's API dump (so invalid members, read-only and wrongly typed assignments error like Roblox).
local R = ...
local G = R.G
local API = R.API
local TYPENAME = R.TYPENAME

---------------------------------------------------------------------------------------------------- typeof
local INSTANCE_STATE = setmetatable({}, { __mode = "k" }) -- proxy -> state
R.STATE = INSTANCE_STATE
local nativeTypeof = typeof
local nativeType = type
function R.typeof(v)
	local t = nativeType(v)
	if t == "table" then
		local mt = getmetatable(v)
		local n = mt and TYPENAME[mt]
		if n then
			return n
		end
		return "table"
	elseif t == "userdata" then
		if INSTANCE_STATE[v] then
			return "Instance"
		end
	end
	return nativeTypeof(v)
end
function R.isInstance(v)
	return nativeType(v) == "userdata" and INSTANCE_STATE[v] ~= nil
end
G.typeof = R.typeof
G.type = function(v)
	local t = nativeType(v)
	if t == "table" then
		local mt = getmetatable(v)
		if mt and TYPENAME[mt] then
			return mt == R.V3MT and "vector" or "userdata"
		end
	end
	return t
end

---------------------------------------------------------------------------------------------------- Enums
local ENUM_MT, ITEM_MT, ENUMS_MT = {}, {}, {}
TYPENAME[ENUM_MT] = "Enum"
TYPENAME[ITEM_MT] = "EnumItem"
TYPENAME[ENUMS_MT] = "Enums"
local enumCache = {}

local function getEnum(name)
	local e = enumCache[name]
	if e then
		return e
	end
	local data = API.enums[name]
	if not data then
		return nil
	end
	e = setmetatable({ _name = name, _items = {}, _list = {}, _byValue = {} }, ENUM_MT)
	for _, it in ipairs(data) do
		local item = setmetatable({ Name = it[1], Value = it[2], EnumType = e }, ITEM_MT)
		e._items[it[1]] = item
		table.insert(e._list, item)
		if e._byValue[it[2]] == nil then
			e._byValue[it[2]] = item
		end
	end
	enumCache[name] = e
	return e
end
R.getEnum = getEnum

ENUM_MT.__index = function(e, k)
	local item = rawget(e, "_items")[k]
	if item then
		return item
	end
	if k == "GetEnumItems" then
		return function(self)
			local out = {}
			for i, v in ipairs(self._list) do
				out[i] = v
			end
			return out
		end
	elseif k == "FromName" then
		return function(self, n)
			return self._items[n]
		end
	elseif k == "FromValue" then
		return function(self, v)
			return self._byValue[v]
		end
	end
	error(string.format('%s is not a valid member of "Enum.%s"', tostring(k), rawget(e, "_name")), 2)
end
ENUM_MT.__tostring = function(e)
	return e._name
end
ITEM_MT.__index = function(item, k)
	if k == "IsA" then
		return function(self, n)
			return self.EnumType._name == n
		end
	end
	error(string.format("%s is not a valid member of EnumItem", tostring(k)), 2)
end
ITEM_MT.__tostring = function(item)
	return "Enum." .. item.EnumType._name .. "." .. item.Name
end
ITEM_MT.__newindex = function()
	error("EnumItem cannot be modified", 2)
end

G.Enum = setmetatable({}, ENUMS_MT)
ENUMS_MT.__index = function(_, k)
	if k == "GetEnums" then
		return function()
			local out = {}
			for n in pairs(API.enums) do
				table.insert(out, getEnum(n))
			end
			return out
		end
	end
	local e = getEnum(k)
	if e then
		return e
	end
	error(string.format("%s is not a valid member of Enums", tostring(k)), 2)
end
ENUMS_MT.__newindex = function()
	error("Enums cannot be modified", 2)
end

function R.enumItem(enumName, itemName)
	local e = getEnum(enumName)
	return e and e._items[itemName]
end
function R.firstEnumItem(enumName)
	local e = getEnum(enumName)
	return e and e._list[1]
end
function R.isEnumItem(v)
	return nativeType(v) == "table" and getmetatable(v) == ITEM_MT
end

---------------------------------------------------------------------------------------------------- Logging
R.log = {}
R.errors = {} -- key -> {msg, trace, count, ctx, t}
R.errorOrder = {}
R.warnings = {}
R.warnOrder = {}
R.notes = {} -- one-off simulator notes (unmocked members etc.)
local MAX_LOG = 4000

function R.addLog(kind, text)
	if #R.log < MAX_LOG then
		table.insert(R.log, string.format("[%7.2f %s %s] %s", R.now or 0, R.CUR and R.CUR.name or "-", kind, text))
	end
end

function R.reportError(err, co)
	local msg = tostring(err)
	local trace = co and debug.traceback(co, msg) or debug.traceback(msg, 2)
	local key = msg:gsub("%d+%.%d+", "N")
	local e = R.errors[key]
	if e then
		e.count += 1
		return
	end
	R.errors[key] = { msg = msg, trace = trace, count = 1, ctx = R.CUR and R.CUR.name or "-", t = R.now }
	table.insert(R.errorOrder, key)
	R.addLog("ERROR", msg)
end

function R.warn(text, key)
	key = key or text
	local w = R.warnings[key]
	if w then
		w.count += 1
		return
	end
	R.warnings[key] = { msg = text, count = 1, ctx = R.CUR and R.CUR.name or "-", t = R.now }
	table.insert(R.warnOrder, key)
	R.addLog("WARN", text)
end

function R.note(text)
	if not R.notes[text] then
		R.notes[text] = true
	end
end

---------------------------------------------------------------------------------------------------- Scheduler
R.now = 0
R.frame = 0
R.FRAME = 1 / 30
local THREADCTX = setmetatable({}, { __mode = "k" })
local WAITING = setmetatable({}, { __mode = "k" })
local DEAD = setmetatable({}, { __mode = "k" })
R.THREADCTX = THREADCTX

-- binary heap of timers {t, seq, co, args}
local heap = {}
local seq = 0
local function heapLess(a, b)
	return a.t < b.t or (a.t == b.t and a.seq < b.seq)
end
local function heapPush(item)
	table.insert(heap, item)
	local i = #heap
	while i > 1 do
		local p = i // 2
		if heapLess(heap[i], heap[p]) then
			heap[i], heap[p] = heap[p], heap[i]
			i = p
		else
			break
		end
	end
end
local function heapPop()
	local top = heap[1]
	local last = table.remove(heap)
	if #heap > 0 then
		heap[1] = last
		local i = 1
		while true do
			local l, r = i * 2, i * 2 + 1
			local m = i
			if l <= #heap and heapLess(heap[l], heap[m]) then
				m = l
			end
			if r <= #heap and heapLess(heap[r], heap[m]) then
				m = r
			end
			if m == i then
				break
			end
			heap[i], heap[m] = heap[m], heap[i]
			i = m
		end
	end
	return top
end

local deferred = {} -- queue of {co, args, n}
local depth = 0

local function flushDeferred()
	local guard = 0
	while #deferred > 0 do
		local batch = deferred
		deferred = {}
		for _, d in ipairs(batch) do
			guard += 1
			R.resume(d.co, table.unpack(d.args, 1, d.n))
		end
		if guard > 200000 then
			R.warn("deferred event storm: more than 200000 deferred resumptions in one frame (event loop?)")
			deferred = {}
			break
		end
	end
end
R.flushDeferred = flushDeferred

function R.resume(co, ...)
	if DEAD[co] or coroutine.status(co) ~= "suspended" then
		return
	end
	WAITING[co] = nil
	local prev = R.CUR
	R.CUR = THREADCTX[co] or prev
	depth += 1
	local ok, err = coroutine.resume(co, ...)
	depth -= 1
	if not ok then
		R.reportError(err, co)
	elseif coroutine.status(co) == "suspended" and not WAITING[co] then
		if __timedout() then
			R.reportError("Script timeout: exhausted allowed execution time (infinite loop without a yield?)", co)
			DEAD[co] = true
			__arm(R.FRAME_BUDGET_MS or 8000)
		end
	end
	R.CUR = prev
	if depth == 0 then
		flushDeferred()
	end
end

function R.newThread(fn, ctx)
	local co = coroutine.create(fn)
	THREADCTX[co] = ctx or R.CUR
	return co
end

function R.spawn(fn, ...)
	local co = nativeType(fn) == "thread" and fn or R.newThread(fn)
	if THREADCTX[co] == nil then
		THREADCTX[co] = R.CUR
	end
	R.resume(co, ...)
	return co
end

function R.deferThread(co, ...)
	table.insert(deferred, { co = co, args = { ... }, n = select("#", ...) })
end

function R.deferCall(fn, ctx, ...)
	local co = R.newThread(fn, ctx)
	R.deferThread(co, ...)
	return co
end

function R.schedule(t, co, ...)
	seq += 1
	heapPush({ t = t, seq = seq, co = co, args = { ... }, n = select("#", ...) })
end

-- Suspend the running thread until something resumes it; returns the resume arguments.
function R.suspend()
	local co = coroutine.running()
	if not coroutine.isyieldable() then
		error("attempt to yield across metamethod/C-call boundary or from outside a coroutine", 3)
	end
	WAITING[co] = true
	if THREADCTX[co] == nil then
		THREADCTX[co] = R.CUR
	end
	return coroutine.yield()
end

function R.sleep(t)
	local co = coroutine.running()
	local start = R.now
	R.schedule(R.now + math.max(t or 0, R.FRAME * 0.5), co)
	R.suspend()
	return R.now - start
end

function R.cancel(co)
	DEAD[co] = true
	WAITING[co] = nil
end
function R.isDead(co)
	return DEAD[co] == true
end

local preStep = {} -- functions(dt) run each frame before timers (physics, tweens)
R.preStep = preStep

function R.step(dt)
	dt = dt or R.FRAME
	__arm(R.FRAME_BUDGET_MS or 8000)
	R.now += dt
	R.frame += 1
	for _, f in ipairs(preStep) do
		local ok, err = pcall(f, dt)
		if not ok then
			R.reportError("[simulator] " .. tostring(err))
		end
	end
	if R.onFrameStart then
		R.onFrameStart(dt)
	end
	while #heap > 0 and heap[1].t <= R.now + 1e-9 do
		local item = heapPop()
		R.resume(item.co, table.unpack(item.args, 1, item.n))
	end
	if R.onFrameEnd then
		R.onFrameEnd(dt)
	end
	flushDeferred()
end

function R.run(seconds, dt)
	dt = dt or R.FRAME
	local n = math.max(1, math.floor(seconds / dt + 0.5))
	for _ = 1, n do
		R.step(dt)
	end
end

---------------------------------------------------------------------------------------------------- task library
local function toThread(f)
	if nativeType(f) == "thread" then
		if THREADCTX[f] == nil then
			THREADCTX[f] = R.CUR
		end
		return f
	elseif nativeType(f) == "function" then
		return R.newThread(f)
	end
	error("invalid argument #1 (function or thread expected, got " .. R.typeof(f) .. ")", 3)
end

G.task = {
	spawn = function(f, ...)
		local co = toThread(f)
		R.resume(co, ...)
		return co
	end,
	defer = function(f, ...)
		local co = toThread(f)
		R.deferThread(co, ...)
		return co
	end,
	delay = function(t, f, ...)
		local co = toThread(f)
		R.schedule(R.now + math.max(tonumber(t) or 0, 0), co, ...)
		return co
	end,
	wait = function(t)
		if t ~= nil and nativeType(t) ~= "number" then
			error("invalid argument #1 to 'wait' (number expected, got " .. R.typeof(t) .. ")", 2)
		end
		return R.sleep(t or 0)
	end,
	cancel = function(co)
		if nativeType(co) ~= "thread" then
			error("invalid argument #1 to 'cancel' (thread expected)", 2)
		end
		if co == coroutine.running() then
			R.cancel(co)
			return
		end
		R.cancel(co)
		pcall(coroutine.close, co)
	end,
	synchronize = function() end,
	desynchronize = function() end,
}
G.wait = function(t)
	local e = R.sleep(math.max(tonumber(t) or 0, 0.029))
	return e, R.now
end
G.delay = function(t, f)
	return G.task.delay(t, f)
end
G.spawn = function(f)
	return G.task.defer(f)
end
G.tick = function()
	return R.unixNow()
end
G.time = function()
	return R.now
end
G.elapsedTime = function()
	return R.now
end

---------------------------------------------------------------------------------------------------- Signals
local SIG_MT, CONN_MT = {}, {}
TYPENAME[SIG_MT] = "RBXScriptSignal"
TYPENAME[CONN_MT] = "RBXScriptConnection"

local function newSignal(name, opts)
	return setmetatable({ _name = name, _conns = {}, _waiters = {}, _only = opts and opts.only, _immediate = opts and opts.immediate, _valueArg = opts and opts.valueArg }, SIG_MT)
end
R.newSignal = newSignal

local SIGm = {}
function SIGm.Connect(sig, fn)
	if getmetatable(sig) ~= SIG_MT then
		error("Expected ':' not '.' calling member function Connect", 2)
	end
	if nativeType(fn) ~= "function" then
		error("Attempt to connect failed: Passed value is not a function", 2)
	end
	if sig._only and (not R.CUR or R.CUR.name ~= sig._only) then
		error(sig._name .. " can only be used " .. (sig._only == "server" and "on the server" or "from local scripts / the client"), 2)
	end
	local c = setmetatable({ Connected = true, _sig = sig, _fn = fn, _ctx = R.CUR }, CONN_MT)
	table.insert(sig._conns, c)
	R.connCount = (R.connCount or 0) + 1
	if sig._onConnect then
		sig._onConnect(sig)
	end
	return c
end
SIGm.connect = SIGm.Connect
SIGm.ConnectParallel = SIGm.Connect
function SIGm.Once(sig, fn)
	local c
	c = SIGm.Connect(sig, function(...)
		if c.Connected then
			c:Disconnect()
			fn(...)
		end
	end)
	return c
end
function SIGm.Wait(sig)
	if getmetatable(sig) ~= SIG_MT then
		error("Expected ':' not '.' calling member function Wait", 2)
	end
	local co = coroutine.running()
	table.insert(sig._waiters, co)
	return R.suspend()
end
SIGm.wait = SIGm.Wait
SIG_MT.__index = function(sig, k)
	local m = SIGm[k]
	if m then
		return m
	end
	if string.sub(k, 1, 1) == "_" then
		return nil
	end
	error(tostring(k) .. " is not a valid member of RBXScriptSignal", 2)
end
SIG_MT.__tostring = function(sig)
	return "Signal " .. sig._name
end

local CONNm = {
	Disconnect = function(c)
		if not c.Connected then
			return
		end
		rawset(c, "Connected", false)
		local list = c._sig._conns
		for i, x in ipairs(list) do
			if x == c then
				table.remove(list, i)
				break
			end
		end
	end,
}
CONNm.disconnect = CONNm.Disconnect
CONN_MT.__index = function(c, k)
	local m = CONNm[k]
	if m then
		return m
	end
	error(tostring(k) .. " is not a valid member of RBXScriptConnection", 2)
end

-- Fire: deferred by default (Roblox SignalBehavior.Deferred); immediate signals run handlers right away.
function R.fire(sig, ...)
	if not sig then
		return
	end
	local n = select("#", ...)
	local args = { ... }
	if #sig._conns > 0 then
		local snapshot = table.clone(sig._conns)
		for _, c in ipairs(snapshot) do
			if c.Connected then
				local co = R.newThread(c._fn, c._ctx)
				if sig._immediate then
					R.resume(co, table.unpack(args, 1, n))
				else
					R.deferThread(co, table.unpack(args, 1, n))
				end
			end
		end
	end
	if #sig._waiters > 0 then
		local ws = sig._waiters
		sig._waiters = {}
		for _, co in ipairs(ws) do
			if sig._immediate then
				R.resume(co, table.unpack(args, 1, n))
			else
				R.deferThread(co, table.unpack(args, 1, n))
			end
		end
	end
end

function R.hasListeners(sig)
	return sig ~= nil and (#sig._conns > 0 or #sig._waiters > 0)
end

function R.disconnectAll(sig)
	for _, c in ipairs(table.clone(sig._conns)) do
		rawset(c, "Connected", false)
	end
	sig._conns = {}
	sig._waiters = {}
end

-- Plain table "signal-like" objects for script-facing userdata that is not an Instance (e.g. Tween.Completed)
R.SIG_MT = SIG_MT

---------------------------------------------------------------------------------------------------- Class info
local classCache = {}
local function classInfo(name)
	local c = classCache[name]
	if c then
		return c
	end
	local data = API.classes[name]
	if not data then
		return nil
	end
	c = { name = name, data = data, chain = {} }
	local cur = name
	while cur and API.classes[cur] do
		table.insert(c.chain, cur)
		cur = API.classes[cur].s
	end
	classCache[name] = c
	return c
end
R.classInfo = classInfo

function R.classIsA(className, base)
	local c = classInfo(className)
	if not c then
		return false
	end
	for _, n in ipairs(c.chain) do
		if n == base then
			return true
		end
	end
	return false
end

-- Behaviours (getters/setters/methods implemented by the simulator), registered per class name.
R.B = {}
function R.behavior(className)
	local b = R.B[className]
	if not b then
		b = { get = {}, set = {}, m = {}, events = {} }
		R.B[className] = b
	end
	return b
end

-- Default values not in the dump (inherited properties of abstract classes), per class.
R.DEFAULTS = {}

local memberCache = {}
local function member(className, key)
	local mc = memberCache[className]
	if not mc then
		mc = {}
		memberCache[className] = mc
	end
	local d = mc[key]
	if d ~= nil then
		return d
	end
	local ci = classInfo(className)
	d = false
	if ci then
		-- simulator behaviours first (they may add members the dump lacks)
		for _, cn in ipairs(ci.chain) do
			local b = R.B[cn]
			if b then
				if b.m[key] then
					d = { kind = "func", fn = b.m[key] }
					break
				elseif b.get[key] or b.set[key] then
					-- find the dump info for typing
					local pinfo
					for _, cn2 in ipairs(ci.chain) do
						local p = API.classes[cn2].p[key]
						if p then
							pinfo = p
							break
						end
					end
					d = { kind = "prop", get = b.get[key], set = b.set[key], pinfo = pinfo }
					break
				elseif b.events[key] then
					d = { kind = "event", opts = b.events[key] }
					break
				end
			end
			local data = API.classes[cn]
			if data.p[key] then
				d = { kind = "prop", pinfo = data.p[key] }
				-- a behaviour getter/setter further up the chain still applies
				for _, cn2 in ipairs(ci.chain) do
					local b2 = R.B[cn2]
					if b2 and (b2.get[key] or b2.set[key]) then
						d.get = d.get or b2.get[key]
						d.set = d.set or b2.set[key]
					end
				end
				break
			elseif data.f[key] then
				d = { kind = "func", fn = nil, owner = cn }
				for _, cn2 in ipairs(ci.chain) do
					local b2 = R.B[cn2]
					if b2 and b2.m[key] then
						d.fn = b2.m[key]
						break
					end
				end
				break
			elseif data.e[key] then
				d = { kind = "event" }
				for _, cn2 in ipairs(ci.chain) do
					local b2 = R.B[cn2]
					if b2 and b2.events[key] then
						d.opts = b2.events[key]
						break
					end
				end
				break
			elseif data.cb[key] then
				d = { kind = "cb" }
				break
			end
		end
	end
	if d and d.kind == "func" and not d.fn then
		local owner, k = d.owner, key
		d.fn = function(self, ...)
			R.note("unmocked method " .. owner .. ":" .. k)
			return nil
		end
	end
	mc[key] = d
	return d
end
R.member = member

local defaultCache = {}
local function propDefault(className, key, pinfo)
	local dc = defaultCache[className]
	if not dc then
		dc = {}
		defaultCache[className] = dc
	end
	local v = dc[key]
	if v ~= nil then
		return v ~= R.NIL and v or nil
	end
	local ci = classInfo(className)
	local found, value = false, nil
	for _, cn in ipairs(ci.chain) do
		local d = R.DEFAULTS[cn]
		if d and d[key] ~= nil then
			found, value = true, d[key]
			break
		end
	end
	if not found and pinfo then
		value = R.parseDefault(pinfo[1], pinfo[2], pinfo[3])
		if value == nil then
			value = R.typeDefault(pinfo[1], pinfo[2])
		end
		if pinfo[1] == "E" and pinfo[3] then
			value = R.enumItem(pinfo[2], pinfo[3]) or value
		end
	end
	if nativeType(value) == "function" then
		return value() -- fresh value each time (mutable tables)
	end
	dc[key] = value == nil and R.NIL or value
	return value
end
R.NIL = newproxy(false)

---------------------------------------------------------------------------------------------------- Instances
local function fullName(inst)
	local s = INSTANCE_STATE[inst]
	if not s then
		return "?"
	end
	local parts = {}
	local cur = inst
	while cur do
		local cs = INSTANCE_STATE[cur]
		if cs.ClassName == "DataModel" then
			break
		end
		table.insert(parts, 1, cs.props.Name)
		cur = cs.parent
	end
	return table.concat(parts, ".")
end
R.fullName = fullName

local function coerce(pinfo, value, key, className)
	if not pinfo then
		return value
	end
	local cat, tname = pinfo[1], pinfo[2]
	local function fail()
		error(string.format("Unable to assign property %s. %s expected, got %s", key, tname, R.typeof(value)), 4)
	end
	if cat == "P" then
		if tname == "bool" then
			if nativeType(value) ~= "boolean" then
				fail()
			end
		elseif tname == "string" then
			if nativeType(value) == "number" then
				return tostring(value)
			elseif nativeType(value) ~= "string" then
				fail()
			end
		elseif tname == "float" or tname == "double" or tname == "int" or tname == "int64" then
			if nativeType(value) == "string" and tonumber(value) then
				value = tonumber(value)
			end
			if nativeType(value) ~= "number" then
				fail()
			end
			if value ~= value then
				R.warn(string.format("NaN assigned to %s.%s", className, key))
			end
			if tname == "int" or tname == "int64" then
				return math.floor(value)
			end
		end
		return value
	elseif cat == "E" then
		if R.isEnumItem(value) then
			if value.EnumType._name ~= tname then
				error(string.format("Unable to assign property %s. EnumItem of type %s expected, got an EnumItem of type %s", key, tname, value.EnumType._name), 4)
			end
			return value
		end
		local e = getEnum(tname)
		if nativeType(value) == "number" and e and e._byValue[value] then
			return e._byValue[value]
		elseif nativeType(value) == "string" and e and e._items[value] then
			return e._items[value]
		end
		error(string.format("Unable to assign property %s. EnumItem, number, or string expected, got %s", key, R.typeof(value)), 4)
	elseif cat == "C" then
		if value == nil then
			return nil
		end
		if not R.isInstance(value) then
			fail()
		end
		if tname ~= "Instance" and not R.classIsA(INSTANCE_STATE[value].ClassName, tname) then
			error(string.format("Unable to assign property %s. %s expected, got %s", key, tname, INSTANCE_STATE[value].ClassName), 4)
		end
		return value
	else -- datatype
		if tname == "ContentId" or tname == "BinaryString" or tname == "ProtectedString" then
			if nativeType(value) == "number" then
				error(string.format("Unable to assign property %s. ContentId expected, got number", key), 4)
			end
			if nativeType(value) ~= "string" then
				fail()
			end
			return value
		end
		if tname == "PhysicalProperties" and value == nil then
			return nil
		end
		if tname == "OptionalCoordinateFrame" then
			if value ~= nil and R.typeof(value) ~= "CFrame" then
				fail()
			end
			return value
		end
		local vt = R.typeof(value)
		if tname == "Vector3int16" and vt == "Vector3" then
			return value
		end
		if tname == "Vector2int16" and vt == "Vector2" then
			return value
		end
		if vt ~= tname then
			fail()
		end
		return value
	end
end
R.coerce = coerce

local INSTANCE_MT_CACHE = {}

local function getState(inst, method)
	local s = INSTANCE_STATE[inst]
	if not s then
		error("Expected ':' not '.' calling member function " .. tostring(method), 3)
	end
	return s
end
R.getState = getState

local function getSignal(s, key, opts)
	local sig = s.sigs[key]
	if not sig then
		sig = newSignal(s.ClassName .. "." .. key, opts)
		s.sigs[key] = sig
	end
	return sig
end
R.getSignal = getSignal

local function firePropChanged(inst, s, key, value)
	if s.destroyed and key ~= "Parent" then
		return
	end
	local ps = s.propSigs[key]
	if ps then
		R.fire(ps)
	end
	local ch = s.sigs.Changed
	if ch then
		if s.isValue and key == "Value" then
			R.fire(ch, value)
		elseif not s.isValue then
			R.fire(ch, key)
		end
	end
end
R.firePropChanged = firePropChanged

-- set a property value directly (used by setters and internals), firing change signals when it changes
function R.rawSet(inst, key, value)
	local s = INSTANCE_STATE[inst]
	local old = s.props[key]
	s.props[key] = value
	if old ~= value then
		firePropChanged(inst, s, key, value)
	end
end

function R.rawGet(inst, key)
	local s = INSTANCE_STATE[inst]
	local v = s.props[key]
	if v == nil then
		local d = member(s.ClassName, key)
		if d and d.kind == "prop" then
			v = propDefault(s.ClassName, key, d.pinfo)
			if v ~= nil and nativeType(v) == "table" and getmetatable(v) == nil then
				s.props[key] = v
			end
		end
	end
	return v
end

local instanceIndex, instanceNewIndex

instanceIndex = function(inst, key)
	local s = INSTANCE_STATE[inst]
	local d = member(s.ClassName, key)
	if d then
		local kind = d.kind
		if kind == "prop" then
			if d.get then
				return d.get(inst, s)
			end
			local v = s.props[key]
			if v == nil then
				v = propDefault(s.ClassName, key, d.pinfo)
				if nativeType(v) == "table" and getmetatable(v) == nil then
					s.props[key] = v
				end
			end
			return v
		elseif kind == "func" then
			return d.fn
		elseif kind == "event" then
			return getSignal(s, key, d.opts)
		elseif kind == "cb" then
			error(string.format("%s is a callback member of %s; you can only set the callback value, get is not available", key, s.ClassName), 2)
		end
	end
	if nativeType(key) == "string" then
		for _, c in ipairs(s.children) do
			if INSTANCE_STATE[c].props.Name == key then
				return c
			end
		end
	end
	error(string.format('%s is not a valid member of %s "%s"', tostring(key), s.ClassName, fullName(inst)), 2)
end

instanceNewIndex = function(inst, key, value)
	local s = INSTANCE_STATE[inst]
	local d = member(s.ClassName, key)
	if not d then
		error(string.format('%s is not a valid member of %s "%s"', tostring(key), s.ClassName, fullName(inst)), 2)
	end
	if d.kind == "cb" then
		if value ~= nil and nativeType(value) ~= "function" then
			error(string.format("%s must be a function", key), 2)
		end
		s.callbacks[key] = value
		s.callbackCtx[key] = R.CUR
		return
	end
	if d.kind ~= "prop" then
		error(string.format("%s is not a valid member of %s or cannot be assigned", key, s.ClassName), 2)
	end
	if d.pinfo and d.pinfo[4] and not d.set then
		error(string.format("Unable to assign property %s. Property is read only", key), 2)
	end
	value = coerce(d.pinfo, value, key, s.ClassName)
	if d.pinfo and d.pinfo[1] == "D" and (d.pinfo[2] == "ContentId") and nativeType(value) == "string" and value ~= "" then
		R.noteAsset(value, s.ClassName .. "." .. key)
	end
	if d.set then
		d.set(inst, s, value, key)
		return
	end
	local old = s.props[key]
	s.props[key] = value
	if old ~= value then
		firePropChanged(inst, s, key, value)
	end
end

local function instanceTostring(inst)
	return INSTANCE_STATE[inst].props.Name
end

local function makeProxy()
	local p = newproxy(true)
	local mt = getmetatable(p)
	mt.__index = instanceIndex
	mt.__newindex = instanceNewIndex
	mt.__tostring = instanceTostring
	mt.__metatable = "The metatable is locked"
	return p
end

R.allInstances = setmetatable({}, { __mode = "k" })
R.instanceCount = 0

function R.create(className, skipInit)
	local ci = classInfo(className)
	if not ci then
		error("Unable to create an Instance of type \"" .. tostring(className) .. "\"", 3)
	end
	local inst = makeProxy()
	local s = {
		ClassName = className,
		parent = nil,
		children = {},
		props = { Name = className },
		attrs = {},
		tags = {},
		sigs = {},
		propSigs = {},
		attrSigs = {},
		callbacks = {},
		callbackCtx = {},
		destroyed = false,
		parentLocked = false,
		createdBy = R.CUR and R.CUR.name or "server",
		isValue = R.classIsA(className, "ValueBase"),
	}
	INSTANCE_STATE[inst] = s
	R.allInstances[inst] = true
	R.instanceCount += 1
	if not skipInit and R.onCreate then
		R.onCreate(inst, s)
	end
	return inst
end

G.Instance = {
	new = function(className, parent)
		if nativeType(className) ~= "string" then
			error("invalid argument #1 to 'new' (string expected, got " .. R.typeof(className) .. ")", 2)
		end
		local ci = API.classes[className]
		if not ci then
			error('Unable to create an Instance of type "' .. className .. '"', 2)
		end
		if ci.nc or ci.svc then
			error('Unable to create an Instance of type "' .. className .. '"', 2)
		end
		local inst = R.create(className)
		if parent ~= nil then
			R.warn("Instance.new(class, parent) is slow; set Parent after properties", "Instance.new with parent")
			inst.Parent = parent
		end
		return inst
	end,
	fromExisting = function(inst)
		return R.clone(inst, true)
	end,
}

return true

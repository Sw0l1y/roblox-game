-- Test-driver API on top of the simulator: load a game's place layout, start the server, add players, act like a
-- player (click every visible button, trigger prompts, walk onto touch pads), run debug commands, and report.
local R = ...
local G = R.G
local S = R.STATE
local v3 = R.v3
local nativeType = type

local Sim = {}

local function folder(parent, name, className)
	local existing = R.rawGetChild(parent, name)
	if existing then
		return existing
	end
	local f = R.create(className or "Folder")
	S[f].props.Name = name
	R.setParent(f, parent)
	return f
end

-- manifest: { items = { {container=, folder=, name=, class=, source=, path=} }, materials = { {name=, base=} }, walkSpeed=, jumpPower= }
function Sim.loadPlace(manifestJson)
	local m = R.jsonDecode(manifestJson)
	R.manifest = m
	for _, it in ipairs(m.items) do
		local root = R.service(it.container)
		local parent = root
		if it.container == "StarterPlayer" then
			parent = R.rawGetChild(root, "StarterPlayerScripts")
		end
		if it.folder and it.folder ~= "" then
			parent = folder(parent, it.folder)
		end
		local inst = R.create(it.class)
		S[inst].props.Name = it.name
		S[inst].source = it.source
		S[inst].sourcePath = it.path
		R.setParent(inst, parent)
	end
	local ms = R.service("MaterialService")
	for _, mat in ipairs(m.materials or {}) do
		local mv = R.create("MaterialVariant")
		S[mv].props.Name = mat.name
		S[mv].props.BaseMaterial = R.enumItem("Material", mat.base)
		R.setParent(mv, ms)
	end
	local sp = S[R.service("StarterPlayer")].props
	sp.CharacterWalkSpeed = m.walkSpeed or 16
	sp.CharacterJumpPower = m.jumpPower or 50
	R.CUR = R.SERVER
end

function Sim.startServer()
	R.CUR = R.SERVER
	R.startScriptsIn(R.service("ServerScriptService"), nil)
	R.startScriptsIn(R.workspace, nil)
	R.flushDeferred()
end

function Sim.addPlayer(name, withClient)
	R.CUR = R.SERVER
	local p = R.addPlayer(name, withClient)
	R.flushDeferred()
	return p
end

function Sim.removePlayer(p)
	R.CUR = R.SERVER
	R.removePlayer(p)
	R.flushDeferred()
end

function Sim.run(seconds)
	R.run(seconds)
end

function Sim.shutdown()
	R.CUR = R.SERVER
	for _, p in ipairs(R.playerList()) do
		R.removePlayer(p)
	end
	R.flushDeferred()
	R.run(1)
	local pending = 0
	for _, h in ipairs(R.closeHandlers or {}) do
		pending += 1
		local co = R.newThread(function()
			h.fn()
			pending -= 1
		end, h.ctx)
		R.resume(co)
	end
	local t = 0
	while pending > 0 and t < 30 do
		R.step(R.FRAME)
		t += R.FRAME
	end
	if pending > 0 then
		R.warn("BindToClose handlers still running after 30 s (Roblox kills the server)")
	end
end

---------------------------------------------------------------------------------------------------- player actions
local function character(p)
	local ch = S[p].props.Character
	if ch and not S[ch].destroyed then
		return ch, R.rawGetChild(ch, "HumanoidRootPart"), R.rawGetChild(ch, "Humanoid")
	end
	return nil
end
Sim.character = character

function Sim.teleport(p, pos)
	local ch, hrp = character(p)
	if hrp then
		R.CUR = R.SERVER
		R.movePart(hrp, R.cf(pos.X, pos.Y, pos.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1))
	end
end

local function visibleGui(inst)
	local cur = inst
	while cur do
		local s = S[cur]
		local cls = s.ClassName
		if R.classIsA(cls, "GuiObject") then
			if R.rawGet(cur, "Visible") == false then
				return false
			end
		elseif R.classIsA(cls, "LayerCollector") then
			return R.rawGet(cur, "Enabled") ~= false
		elseif cls == "PlayerGui" then
			return true
		end
		cur = s.parent
	end
	return false
end
Sim.visibleGui = visibleGui

local function layerOf(inst)
	local cur = inst
	while cur do
		if R.classIsA(S[cur].ClassName, "LayerCollector") then
			return cur
		end
		cur = S[cur].parent
	end
	return nil
end

function Sim.buttons(p)
	local pg = R.rawGetChild(p, "PlayerGui")
	local out = {}
	if not pg then
		return out
	end
	for _, d in ipairs(R.descendants(pg)) do
		local s = S[d]
		if R.classIsA(s.ClassName, "GuiButton") and visibleGui(d) then
			local layer = layerOf(d)
			if layer and S[layer].ClassName == "ScreenGui" then
				local x, y, w, h = R.guiRect(d)
				if w >= 2 and h >= 2 and x + w > 0 and y + h > 0 and x < R.SCREEN.X and y < R.SCREEN.Y then
					table.insert(out, d)
				end
			else
				table.insert(out, d)
			end
		end
	end
	return out
end

function Sim.click(btn)
	local s = S[btn]
	if s.destroyed then
		return
	end
	R.CUR = R.CLIENT
	local x, y, w, h = R.guiRect(btn)
	local input = R.create("InputObject")
	S[input].props.UserInputType = R.enumItem("UserInputType", R.MOBILE and "Touch" or "MouseButton1")
	S[input].props.UserInputState = R.enumItem("UserInputState", "Begin")
	S[input].props.Position = v3(x + w / 2, y + h / 2, 0)
	R.fire(s.sigs.InputBegan, input)
	R.fire(s.sigs.MouseButton1Down, x + w / 2, y + h / 2)
	R.fire(s.sigs.MouseButton1Up, x + w / 2, y + h / 2)
	R.fire(s.sigs.MouseButton1Click)
	R.fire(s.sigs.Activated, input, 1)
	S[input].props.UserInputState = R.enumItem("UserInputState", "End")
	R.fire(s.sigs.InputEnded, input)
	R.stats.clicks = (R.stats.clicks or 0) + 1
	R.flushDeferred()
	R.CUR = R.SERVER
end

function Sim.label(inst)
	local s = S[inst]
	local t = s.props.Text
	if t and t ~= "" then
		return t
	end
	for _, d in ipairs(R.descendants(inst)) do
		local ds = S[d]
		if (ds.ClassName == "TextLabel" or ds.ClassName == "TextButton") and ds.props.Text and ds.props.Text ~= "" and R.rawGet(d, "Visible") ~= false then
			return ds.props.Text
		end
	end
	return s.props.Name
end

-- Click every visible button once (in a seeded random order), letting the game react in between.
function Sim.monkey(p, opts)
	opts = opts or {}
	local rng = G.Random.new(opts.seed or 7)
	local clicked = {}
	local rounds = opts.rounds or 3
	for _ = 1, rounds do
		local btns = Sim.buttons(p)
		rng:Shuffle(btns)
		local n = 0
		for _, b in ipairs(btns) do
			if not clicked[b] and not S[b].destroyed and visibleGui(b) then
				clicked[b] = true
				n += 1
				Sim.click(b)
				R.run(opts.gap or 0.4)
				if opts.closeAfter then
					-- press any visible close buttons so the next button is reachable
					for _, c in ipairs(Sim.buttons(p)) do
						local lbl = string.lower(Sim.label(c))
						if lbl == "x" or lbl == "✕" or lbl == "close" or lbl == "×" then
							Sim.click(c)
							R.run(0.2)
						end
					end
				end
				if n >= (opts.maxPerRound or 60) then
					break
				end
			end
		end
		R.run(1)
	end
	local names = {}
	for b in pairs(clicked) do
		table.insert(names, Sim.label(b))
	end
	return names
end

function Sim.prompts()
	local out = {}
	for _, d in ipairs(R.descendants(R.workspace)) do
		if S[d].ClassName == "ProximityPrompt" and R.rawGet(d, "Enabled") ~= false then
			table.insert(out, d)
		end
	end
	return out
end

local function promptPos(prompt)
	local par = S[prompt].parent
	if not par then
		return nil
	end
	local cls = S[par].ClassName
	if R.classIsA(cls, "BasePart") then
		return R.partCF(par).Position
	elseif cls == "Attachment" then
		return par.WorldPosition
	elseif cls == "Model" then
		return R.modelPivot(par).Position
	end
	return nil
end

function Sim.triggerPrompt(p, prompt)
	local s = S[prompt]
	if s.destroyed or R.rawGet(prompt, "Enabled") == false then
		return false
	end
	local pos = promptPos(prompt)
	if not pos then
		R.warn("ProximityPrompt " .. R.fullName(prompt) .. " is not under a part, attachment or model (players never see it)")
		return false
	end
	Sim.teleport(p, pos + v3(0, 1, 3))
	R.run(0.2)
	R.CUR = R.SERVER
	local pps = R.service("ProximityPromptService")
	R.fire(s.sigs.PromptShown, R.enumItem("ProximityPromptInputType", "Keyboard"))
	R.fire(s.sigs.PromptButtonHoldBegan, p)
	local hold = R.rawGet(prompt, "HoldDuration") or 0
	if hold > 0 then
		R.run(hold)
	end
	R.fire(s.sigs.Triggered, p)
	R.fire(S[pps].sigs.PromptTriggered, prompt, p)
	R.fire(s.sigs.PromptButtonHoldEnded, p)
	R.fire(s.sigs.TriggerEnded, p)
	R.stats.prompts = (R.stats.prompts or 0) + 1
	R.flushDeferred()
	R.run(0.5)
	return true
end

function Sim.clickDetectors(p)
	local n = 0
	for _, d in ipairs(R.descendants(R.workspace)) do
		if S[d].ClassName == "ClickDetector" then
			R.CUR = R.SERVER
			R.fire(S[d].sigs.MouseClick, p)
			n += 1
			R.run(0.2)
		end
	end
	return n
end

function Sim.touchParts()
	local out = {}
	for part in pairs(R.WSPARTS) do
		local sig = S[part].sigs.Touched
		if sig and #sig._conns > 0 then
			table.insert(out, part)
		end
	end
	return out
end

function Sim.visitTouchParts(p, limit)
	local parts = Sim.touchParts()
	table.sort(parts, function(a, b)
		return R.fullName(a) < R.fullName(b)
	end)
	local n = 0
	for _, part in ipairs(parts) do
		if not S[part].destroyed and R.WSPARTS[part] then
			local c = R.partCF(part)
			local sz = R.rawGet(part, "Size")
			Sim.teleport(p, v3(c.X, c.Y + sz.Y / 2 + 2.9, c.Z))
			R.run(0.4)
			n += 1
			if limit and n >= limit then
				break
			end
		end
	end
	return n
end

function Sim.walkRandom(p, seconds, seed)
	local rng = G.Random.new(seed or 3)
	local _, hrp, hum = character(p)
	if not hum then
		return
	end
	local t = 0
	while t < seconds do
		local c = R.partCF(hrp)
		-- only walk to places with floor under them (players don't jump off the map on purpose)
		local target
		for _ = 1, 8 do
			local cand = c.Position + v3(rng:NextNumber(-40, 40), 0, rng:NextNumber(-40, 40))
			local hit = R.raycast(cand + v3(0, 20, 0), v3(0, -80, 0), nil)
			if hit then
				local mid = c.Position:Lerp(cand, 0.5)
				if R.raycast(mid + v3(0, 20, 0), v3(0, -80, 0), nil) then
					target = cand
					break
				end
			end
		end
		R.CUR = R.SERVER
		if target then
			hum:MoveTo(target)
		end
		R.run(2)
		t += 2
	end
end

function Sim.debug(cmd)
	local ss = R.service("ServerStorage")
	local f = R.rawGetChild(ss, "DebugCmd")
	if not f then
		return nil, "no ServerStorage.DebugCmd"
	end
	R.CUR = R.SERVER
	local result, ok, err
	local co = R.newThread(function()
		ok, result = pcall(function()
			return f:Invoke(cmd)
		end)
	end, R.SERVER)
	R.resume(co)
	local t = 0
	while ok == nil and t < 10 do
		R.step(R.FRAME)
		t += R.FRAME
	end
	if ok == false then
		R.reportError("DebugCmd '" .. cmd .. "' errored: " .. tostring(result))
		return nil, tostring(result)
	end
	return result
end

---------------------------------------------------------------------------------------------------- inspection
function Sim.uiTexts(p, max)
	local pg = R.rawGetChild(p, "PlayerGui")
	local out = {}
	if not pg then
		return out
	end
	for _, d in ipairs(R.descendants(pg)) do
		local s = S[d]
		if (s.ClassName == "TextLabel" or s.ClassName == "TextButton") and visibleGui(d) and (R.rawGet(d, "TextTransparency") or 0) < 0.98 then
			local txt = s.props.Text
			if txt == nil then
				txt = s.ClassName == "TextLabel" and "Label" or "Button"
			end
			if txt ~= "" then
				local x, y, w, h = R.guiRect(d)
				local layer = layerOf(d)
				table.insert(out, string.format("%s %s @%d,%d %dx%d%s", s.ClassName == "TextButton" and "[btn]" or "     ", txt:gsub("\n", " "):sub(1, 60), x, y, w, h, layer and S[layer].ClassName ~= "ScreenGui" and " (3D)" or ""))
				if #out >= (max or 200) then
					break
				end
			end
		end
	end
	return out
end

function Sim.leaderstats(p)
	local ls = R.rawGetChild(p, "leaderstats")
	local out = {}
	if ls then
		for _, c in ipairs(S[ls].children) do
			out[S[c].props.Name] = tostring(S[c].props.Value)
		end
	end
	return out
end

local function countClasses(root)
	local counts = {}
	for _, d in ipairs(R.descendants(root)) do
		local cls = S[d].ClassName
		counts[cls] = (counts[cls] or 0) + 1
	end
	return counts
end

function Sim.worldStats()
	local parts, unanchored, loose, noCollideBig = 0, 0, {}, 0
	local x0, y0, z0, x1, y1, z1 = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
	for part in pairs(R.WSPARTS) do
		parts += 1
		local a, b, c, d, e, f = R.aabb(part)
		x0, y0, z0 = math.min(x0, a), math.min(y0, b), math.min(z0, c)
		x1, y1, z1 = math.max(x1, d), math.max(y1, e), math.max(z1, f)
		if not R.rawGet(part, "Anchored") then
			unanchored += 1
			local inChar = false
			for _, p in ipairs(R.playerList()) do
				local ch = S[p].props.Character
				if ch and R.isDescendantOf(part, ch) then
					inChar = true
				end
			end
			if not inChar and not R.isGrounded(part) and #loose < 15 then
				table.insert(loose, R.fullName(part))
			end
		end
	end
	return {
		parts = parts,
		unanchored = unanchored,
		looseParts = loose,
		bounds = string.format("%.0f,%.0f,%.0f .. %.0f,%.0f,%.0f", x0, y0, z0, x1, y1, z1),
		classes = countClasses(R.workspace),
	}
end

-- Parts for the offline renderer: {cls, shape, cf(12), size(3), color(3), transparency, material}
function Sim.exportWorld()
	local out = {}
	for part in pairs(R.WSPARTS) do
		local s = S[part]
		local tr = R.rawGet(part, "Transparency")
		if tr < 0.98 then
			local c = R.partCF(part)
			local sz = R.rawGet(part, "Size")
			local col = R.rawGet(part, "Color")
			local shape = s.ClassName == "Part" and R.rawGet(part, "Shape").Name or (s.ClassName == "WedgePart" and "Wedge" or (s.ClassName == "CornerWedgePart" and "CornerWedge" or (s.ClassName == "MeshPart" and "Mesh" or "Block")))
			local mat = R.rawGet(part, "Material").Name
			local variant = R.rawGet(part, "MaterialVariant")
			-- SpecialMesh primitives change the drawn shape and size
			for _, ch in ipairs(s.children) do
				if S[ch].ClassName == "SpecialMesh" then
					local mt = R.rawGet(ch, "MeshType").Name
					local sc = R.rawGet(ch, "Scale")
					local off = R.rawGet(ch, "Offset")
					local map = { Sphere = "Ellipsoid", Head = "Ellipsoid", Cylinder = "Cylinder", Brick = "Block", Wedge = "Wedge" }
					if map[mt] then
						shape = map[mt]
						sz = v3(sz.X * sc.X, sz.Y * sc.Y, sz.Z * sc.Z)
						c = R.cfMul(c, R.cf(off.X, off.Y, off.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1))
					end
					break
				end
			end
			table.insert(out, { s.ClassName, shape, { c:GetComponents() }, { sz.X, sz.Y, sz.Z }, { col.R, col.G, col.B }, tr, mat, variant, R.fullName(part) })
		end
	end
	local cams = {}
	for part in pairs(R.WSPARTS) do
		if S[part].ClassName == "SpawnLocation" then
			cams.spawn = { R.partCF(part):GetComponents() }
			break
		end
	end
	for _, p in ipairs(R.playerList()) do
		local ch = S[p].props.Character
		local hrp = ch and R.rawGetChild(ch, "HumanoidRootPart")
		if hrp and S[p].props.Name == "Tester" then
			cams.char = { R.partCF(hrp):GetComponents() }
		end
	end
	local L = R.service("Lighting")
	local atm = L:FindFirstChildOfClass("Atmosphere")
	local light = {
		clock = R.rawGet(L, "ClockTime"),
		ambient = { R.rawGet(L, "Ambient").R, R.rawGet(L, "Ambient").G, R.rawGet(L, "Ambient").B },
		outdoor = { R.rawGet(L, "OutdoorAmbient").R, R.rawGet(L, "OutdoorAmbient").G, R.rawGet(L, "OutdoorAmbient").B },
		brightness = R.rawGet(L, "Brightness"),
		atmosphere = atm and { color = { atm.Color.R, atm.Color.G, atm.Color.B }, decay = { atm.Decay.R, atm.Decay.G, atm.Decay.B }, density = atm.Density, haze = atm.Haze } or nil,
	}
	return R.jsonEncodeLoose({ parts = out, cams = cams, light = light })
end

function Sim.lighting()
	local L = R.service("Lighting")
	local out = { ClockTime = R.rawGet(L, "ClockTime"), Brightness = R.rawGet(L, "Brightness"), Ambient = tostring(R.rawGet(L, "Ambient")), OutdoorAmbient = tostring(R.rawGet(L, "OutdoorAmbient")) }
	for _, c in ipairs(S[L].children) do
		local cs = S[c]
		out[cs.ClassName] = true
		if cs.ClassName == "Sky" then
			out.Sky = { R.rawGet(c, "SkyboxUp"), R.rawGet(c, "SkyboxFt") }
		elseif cs.ClassName == "Atmosphere" then
			out.Atmosphere = { Density = R.rawGet(c, "Density"), Haze = R.rawGet(c, "Haze"), Color = tostring(R.rawGet(c, "Color")) }
		end
	end
	return out
end

function Sim.report()
	local errs = {}
	for _, k in ipairs(R.errorOrder) do
		local e = R.errors[k]
		table.insert(errs, { msg = e.msg, count = e.count, ctx = e.ctx, t = e.t, trace = e.trace })
	end
	local warns = {}
	for _, k in ipairs(R.warnOrder) do
		local w = R.warnings[k]
		table.insert(warns, { msg = w.msg, count = w.count, ctx = w.ctx, t = w.t })
	end
	local notes = {}
	for n in pairs(R.notes) do
		table.insert(notes, n)
	end
	table.sort(notes)
	local assets = {}
	for id, a in pairs(R.ASSETS) do
		local where = {}
		for w in pairs(a.where) do
			table.insert(where, w)
		end
		assets[id] = table.concat(where, ", ")
	end
	return R.jsonEncodeLoose({
		errors = errs,
		warnings = warns,
		notes = notes,
		stats = R.stats,
		assets = assets,
		log = R.log,
		now = R.now,
		instances = R.instanceCount,
		connections = R.connCount,
	})
end

function Sim.dataDump()
	return R.jsonEncodeLoose(R.DATA)
end
function Sim.dataLoad(json)
	R.DATA = R.jsonDecode(json) or {}
end

Sim.R = R
return Sim

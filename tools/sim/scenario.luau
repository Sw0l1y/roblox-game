-- Playtest scenario run by tools/sim/run.mjs. "smoke": a full session (join, FTUE, click everything, prompts,
-- touch pads, debug commands, server events, long play, death, leave). "rejoin": loads the saved data and rejoins.
local Sim = _SIM
local R = Sim.R
local S = R.STATE
local opts = R.jsonDecode(OPTS)
R.MOBILE = opts.mobile
local phases = {}
local out = { phases = phases }

local function errCount()
	return #R.errorOrder
end

local function phase(name, player, info, withUi)
	table.insert(phases, {
		name = name,
		t = R.now,
		info = (info or "") .. string.format(" [errors so far: %d]", errCount()),
		leaderstats = player and Sim.leaderstats(player) or nil,
		ui = (withUi and player) and Sim.uiTexts(player, 120) or nil,
	})
	__stdout(string.format("%-28s t=%6.1f errors=%d", name, R.now, errCount()))
end

if opts.data then
	Sim.dataLoad(opts.data)
end
Sim.loadPlace(MANIFEST)
Sim.startServer()
Sim.run(3)
phase("server started", nil, string.format("instances=%d parts=%d", R.instanceCount, (function()
	local n = 0
	for _ in pairs(R.WSPARTS) do
		n += 1
	end
	return n
end)()))

local tester = Sim.addPlayer("Tester", true)

if opts.kind == "rejoin" then
	Sim.run(12)
	phase("rejoined", tester, "", true)
	Sim.shutdown()
	out.report = R.jsonDecode(Sim.report())
	return R.jsonEncodeLoose(out)
end

local botList = {}
for i = 1, opts.bots or 0 do
	table.insert(botList, Sim.addPlayer("Bot" .. i, false))
end
Sim.run(2)
phase("joined (2s)", tester, "", true)
Sim.run(10)
phase("FTUE (12s)", tester, "", true)

-- act like a new player: press everything on screen
local clicked = Sim.monkey(tester, { rounds = 2, closeAfter = true, seed = 1 })
phase("clicked buttons", tester, "clicked: " .. table.concat(clicked, " | "):sub(1, 1500), true)

local prompts = Sim.prompts()
local np = 0
for _, p in ipairs(prompts) do
	if np >= 40 then
		break
	end
	if Sim.triggerPrompt(tester, p) then
		np += 1
	end
end
local touched = Sim.visitTouchParts(tester, 60)
local nc = Sim.clickDetectors(tester)
phase("prompts/touch pads", tester, string.format("prompts=%d of %d, touch parts visited=%d, click detectors=%d", np, #prompts, touched, nc), false)

for i, b in ipairs(botList) do
	Sim.walkRandom(b, 6, i)
end

-- debug commands (Studio-only test hooks in each game)
local cmds = {}
for c in string.gmatch(opts.debug or "", "[^;]+") do
	table.insert(cmds, c)
end
local stateText = Sim.debug("state")
local debugLog = { "state -> " .. tostring(stateText) }
for _, c in ipairs(cmds) do
	local r, err = Sim.debug(c)
	table.insert(debugLog, c .. " -> " .. tostring(r or err))
	Sim.run(1)
end
phase("debug commands", tester, table.concat(debugLog, "\n"), false)

-- with money: press everything again (buy upgrades etc.)
Sim.monkey(tester, { rounds = 2, closeAfter = true, seed = 2 })
phase("clicked again (after debug)", tester, "", true)

-- long session with periodic actions
local long = opts.seconds or 240
local t = 0
local i = 0
while t < long do
	i += 1
	Sim.walkRandom(tester, 6, 100 + i)
	if i % 2 == 0 then
		Sim.monkey(tester, { rounds = 1, seed = 10 + i, closeAfter = true, maxPerRound = 12 })
	end
	if i % 3 == 0 then
		for k, p in ipairs(Sim.prompts()) do
			if k > 6 then
				break
			end
			Sim.triggerPrompt(tester, p)
		end
	end
	Sim.run(20)
	t += 30
end
phase(string.format("long play (%ds)", long), tester, Sim.debug("state") and ("state -> " .. tostring(Sim.debug("state"))) or "", true)

-- death and respawn: UI must survive
local _, _, hum = Sim.character(tester)
local resetsBefore = R.stats.guiResets or 0
if hum then
	R.CUR = R.SERVER
	hum.Health = 0
end
Sim.run(8)
phase("after death + respawn", tester, string.format("ResetOnSpawn guis wiped: %d", (R.stats.guiResets or 0) - resetsBefore), true)

out.worldStats = Sim.worldStats()
out.lighting = Sim.lighting()
out.world = Sim.exportWorld()
Sim.shutdown()
phase("left + shutdown", nil, "")
out.data = Sim.dataDump()
out.report = R.jsonDecode(Sim.report())
return R.jsonEncodeLoose(out)

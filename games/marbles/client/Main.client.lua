--!strict
-- Marble Mayhem client: wires the server's race cycle to the views. Builds each new track from its seed
-- as soon as the pick phase starts (with a camera flyover), shows the pick screen, hands live races to
-- RaceView, and routes rewards, the Grand Prix timer, the mutation tease, offline earnings, server
-- announcements and machine prompts to the HUD.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local ClientLib = ReplicatedStorage:WaitForChild("ClientLib")
local UI = require(ClientLib:WaitForChild("UI"))
local Sfx = require(ClientLib:WaitForChild("Sfx"))
local State = require(ClientLib:WaitForChild("State"))
local Fx = require(ClientLib:WaitForChild("Fx"))
local TrackView = require(ClientLib:WaitForChild("TrackView"))
local RaceView = require(ClientLib:WaitForChild("RaceView"))
local Picker = require(ClientLib:WaitForChild("Picker"))
local Hud = require(ClientLib:WaitForChild("Hud"))
local Reveal = require(ClientLib:WaitForChild("Reveal"))

local player = Players.LocalPlayer
local _ = Fx -- loaded for server-triggered effects

local function now(): number
	return workspace:GetServerTimeNow()
end

Sfx.music(Config.Music)
RaceView.coinTarget = Hud.coinFrame()

-- Tracks ---------------------------------------------------------------------------------------------------
local mainView: TrackView.View? = nil
local practiceView: TrackView.View? = nil

local function ensureTrack(kind: string, seed: number, theme: string): TrackView.View
	if kind == "practice" then
		local pv = practiceView
		if pv and pv.seed == seed then
			return pv
		end
		if pv then
			TrackView.destroy(pv)
		end
		local v = TrackView.build("practice", seed, "Classic")
		practiceView = v
		return v
	end
	local mv = mainView
	if mv and mv.seed == seed and mv.kind == kind then
		return mv
	end
	if mv then
		TrackView.destroy(mv)
	end
	local v = TrackView.build(kind, seed, theme)
	mainView = v
	return v
end

-- Music: the Grand Prix gets the week's theme track.
local gpMusic = false
local function setGpMusic(on: boolean)
	if on == gpMusic then
		return
	end
	gpMusic = on
	if on then
		local th = Config.gpTheme(os.time())
		Sfx.music({ th.music })
	else
		Sfx.music(Config.Music)
	end
end

-- Phase ------------------------------------------------------------------------------------------------------
local phase = "idle"
local phaseEnds = 0
local phaseInfo: { [string]: any } = {}

local function onPhase(p: string, endsAt: number, info: { [string]: any }?)
	local inf = info or {}
	local wasPhase = phase
	phase = p
	phaseEnds = endsAt
	if p == "pick" then
		phaseInfo = inf
		if type(inf.seed) == "number" then
			ensureTrack(tostring(inf.kind or "main"), inf.seed, tostring(inf.theme or "Classic"))
		end
		Picker.setEnds(endsAt)
		setGpMusic(inf.gp == true)
		if wasPhase ~= "pick" then
			RaceView.hideResults()
			if inf.gp then
				UI.banner("🏁 GRAND PRIX!", "purple", 2.4)
				Sfx.play("victory", 0.5)
			end
		end
	elseif p == "race" then
		Picker.hide()
		RaceView.preview(nil, 0)
	end
end

Net.event("Phase").OnClientEvent:Connect(function(p, endsAt, info)
	onPhase(tostring(p), tonumber(endsAt) or 0, info)
end)

Net.event("PickOffer").OnClientEvent:Connect(function(offer, endsAt)
	if type(offer) ~= "table" then
		return
	end
	local ends = tonumber(endsAt) or now()
	Picker.show(offer, ends, phaseInfo)
	if not RaceView.busy() and not Reveal.isOpen() then
		RaceView.preview(mainView, ends)
	end
end)

-- Races ------------------------------------------------------------------------------------------------------
Net.event("RaceStart").OnClientEvent:Connect(function(desc)
	if type(desc) ~= "table" then
		return
	end
	local view = ensureTrack(tostring(desc.kind), tonumber(desc.seed) or 0, tostring(desc.theme or "Classic"))
	RaceView.add(desc, view)
end)
Net.fast("RaceSnap").OnClientEvent:Connect(function(b)
	if type(b) == "buffer" then
		RaceView.snap(b)
	end
end)
Net.event("RaceEvt").OnClientEvent:Connect(function(raceId, t, kind, ...)
	if type(raceId) == "number" and type(kind) == "string" then
		RaceView.event(raceId, tonumber(t) or 0, kind, ...)
	end
end)
Net.event("RaceEnd").OnClientEvent:Connect(function(raceId, res, photo)
	if type(raceId) == "number" and type(res) == "table" then
		RaceView.finish(raceId, res, photo == true)
	end
end)
Net.event("Reward").OnClientEvent:Connect(function(raceId, info)
	if type(raceId) == "number" and type(info) == "table" then
		RaceView.reward(raceId, info)
	end
end)

RaceView.onReward = function(_raceId: number, info: { [string]: any })
	if info.firstRace then
		task.delay(2.6, function()
			UI.banner("🎉 FREE WELCOME PACK!", "orange", 2.4)
			Sfx.play("unlock", 0.6)
			UI.toast("Your first pack is FREE - tap 🎁 Packs or visit the Pack Machine!", "orange", 5)
			Hud.refreshGuide()
		end)
	end
	local gpMarble = info.gpMarble
	if type(gpMarble) == "string" then
		local def = Config.MarbleById[gpMarble]
		task.delay(2.2, function()
			Reveal.packs("galaxy", { { id = gpMarble, mut = nil, tier = def and def.tier or "Legendary", key = gpMarble, new = true, dupeXp = 0 } }, nil)
		end)
	end
end

RaceView.onRaceOver = function(practice: boolean)
	task.delay(4, function()
		if not RaceView.busy() and not Picker.isOpen() then
			Hud.maybeOffer(not practice)
		end
	end)
end

-- Meta ---------------------------------------------------------------------------------------------------------
Net.event("GP").OnClientEvent:Connect(function(at, info)
	if type(at) == "number" and type(info) == "table" then
		Hud.setGp(at, info)
	end
end)
Net.event("League").OnClientEvent:Connect(function(rows)
	if type(rows) == "table" then
		Hud.setBoard(rows)
	end
end)
Net.event("Announce").OnClientEvent:Connect(function(text, tier, mut)
	if type(text) == "string" then
		Reveal.announce(text, tier, mut)
	end
end)
Net.event("Open").OnClientEvent:Connect(function(panel)
	if type(panel) == "string" then
		Hud.open(panel)
	end
end)
Net.event("Offline").OnClientEvent:Connect(function(c, mins)
	if type(c) == "number" and c > 0 then
		Hud.offline(c, tonumber(mins) or 0)
	end
end)
Net.event("Tease").OnClientEvent:Connect(function(kind)
	if kind == "mutation" then
		task.delay(1.5, function()
			UI.banner("🌌 A COSMIC MARBLE!", "purple", 2.6)
			Sfx.play("magic", 0.6)
			UI.toast("Mutated marbles earn up to 3x coins. Your first Shine is FREE!", "purple", 6)
			Hud.refreshGuide()
		end)
	end
end)

-- Status pill -------------------------------------------------------------------------------------------------
task.spawn(function()
	while true do
		local left = math.max(0, math.ceil(phaseEnds - now()))
		local gp = phaseInfo.gp == true and phase ~= "idle"
		if RaceView.busy() then
			Hud.setStatus(gp and "🏁 GRAND PRIX!" or "🏁 RACING!", gp and "purple" or "orange")
		elseif phase == "pick" then
			Hud.setStatus((Picker.isOpen() and "PICK!  " or "NEXT RACE  ") .. left .. "s", gp and "purple" or "pink")
		elseif phase == "race" then
			Hud.setStatus("🏁 RACE ON!", gp and "purple" or "orange")
		elseif phase == "results" then
			Hud.setStatus("NEXT RACE  " .. (left + Config.Race.pickTime) .. "s", "blue")
		else
			Hud.setStatus(Config.TITLE, "pink")
		end
		task.wait(0.25)
	end
end)

-- Catch up with the server ---------------------------------------------------------------------------------
task.spawn(function()
	local ok, s = pcall(function()
		return Net.func("Sync"):InvokeServer()
	end)
	if not ok or type(s) ~= "table" then
		return
	end
	if type(s.practiceSeed) == "number" then
		ensureTrack("practice", s.practiceSeed, "Classic")
	end
	if type(s.gpAt) == "number" and type(s.gp) == "table" then
		Hud.setGp(s.gpAt, s.gp)
	end
	if type(s.board) == "table" then
		Hud.setBoard(s.board)
	end
	if phase == "idle" and type(s.phase) == "string" then
		onPhase(s.phase, tonumber(s.endsAt) or 0, s.info)
	end
	for _, desc in ipairs((s.races or {}) :: { { [string]: any } }) do
		local view = ensureTrack(tostring(desc.kind), tonumber(desc.seed) or 0, tostring(desc.theme or "Classic"))
		if not desc.done then
			RaceView.add(desc, view)
		end
	end
	if s.phase == "pick" and type(s.offer) == "table" and not Picker.isOpen() then
		Picker.show(s.offer, tonumber(s.endsAt) or now(), phaseInfo)
	end
end)

local _2 = State
local _3 = player

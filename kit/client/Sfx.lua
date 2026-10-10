-- Sound effects and music. Every id is a public, licensed Roblox library sound (ProSoundEffects or Roblox),
-- so nothing needs uploading. Games add their own with Sfx.add({ name = id }).
local SoundService = game:GetService("SoundService")

local Sfx = {}

local ids: { [string]: number } = {
	click = 15675059323, -- Roblox_UI_Bright_Click
	open = 15674975792, -- Roblox_UI_Whoosh_03
	notify = 9126073001, -- Synth sparkle bell ding
	coin = 9113849492, -- Coins jingle
	cash = 9113728049, -- Cash register
	purchase = 10066947742, -- RBLX UI Purchase
	pop = 9113263649, -- Balloon pop
	sparkle = 9116394545, -- Magic chiming hits
	magic = 9116384485, -- Magic burst
	reveal = 9125805579, -- Rising whoosh build-up
	whoosh = 9125805579,
	cheer = 9112766176, -- Crowd cheer and applause (long; play a slice)
	clap = 9113137945, -- Applause tight
	victory = 12222253,
	thud = 9113480915, -- Body fall thud
	beep = 9117060347, -- NASA beep
	error = 15675075163, -- Roblox_UI_Delete
	unlock = 9116323566,
	swipe = 15675037413,
}

local cache: { [string]: Sound } = {}
local folder = Instance.new("Folder")
folder.Name = "KitSfx"
folder.Parent = SoundService

function Sfx.add(more: { [string]: number })
	for k, v in pairs(more) do
		ids[k] = v
	end
end

local muted = false

function Sfx.play(name: string, volume: number?, pitch: number?, maxLength: number?)
	if muted then
		return
	end
	local id = ids[name]
	if not id then
		return
	end
	local base = cache[name]
	if not base then
		base = Instance.new("Sound")
		base.SoundId = "rbxassetid://" .. id
		base.Parent = folder
		cache[name] = base
	end
	local s = base:Clone()
	s.Volume = volume or 0.5
	s.PlaybackSpeed = pitch or 1
	s.Parent = folder
	s:Play()
	local life = maxLength or 4
	task.delay(life, function()
		if maxLength then
			s:Stop()
		end
		s:Destroy()
	end)
end

-- Background music: a list of licensed track ids played in a loop, with a mute toggle.
local music = Instance.new("Sound")
music.Name = "Music"
music.Volume = 0.22
music.Parent = SoundService
local tracks: { number } = {}
local trackIndex = 0

local function nextTrack()
	if #tracks == 0 then
		return
	end
	trackIndex = trackIndex % #tracks + 1
	music.SoundId = "rbxassetid://" .. tracks[trackIndex]
	music.TimePosition = 0
	if not muted then
		music:Play()
	end
end
music.Ended:Connect(nextTrack)

function Sfx.music(list: { number }, volume: number?)
	tracks = list
	music.Volume = volume or 0.22
	trackIndex = 0
	nextTrack()
end

function Sfx.setMuted(m: boolean)
	muted = m
	if m then
		music:Pause()
	elseif music.SoundId ~= "" then
		music:Resume()
	end
end

function Sfx.isMuted(): boolean
	return muted
end

return Sfx

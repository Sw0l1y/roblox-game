-- Launch-week retention and growth features every game shares: codes, the studio-group gift, playtime gifts,
-- daily quests, badges, friend invites, the friends-in-server bonus and an hourly event clock.
-- The game describes them in its shared Config.Live (read by kit/client/Live too) and pays rewards itself:
--
-- Config.Live = {
--   codes = { LAUNCH = { reward = R } },             -- upper-case; print current codes in the description
--   group = { id = 0, reward = R },                  -- id 0 until the studio group exists (claim says "soon")
--   playtime = { { minutes = 5, reward = R }, ... }, -- per day, counted while in game
--   quests = { { key = "pop", text = "Pop 50 balloons", goal = 50, reward = R }, ... }, -- 3 picked per day
--   badges = { Welcome = 0, FirstWin = 0 },          -- badge ids (0 = not created yet: skipped)
--   invite = { reward = R },                         -- both players, when someone joins from an invite
--   friendBonus = 0.1,                               -- +10% per friend in the server (Live.friendMult)
-- }
-- R is any table the game understands, plus `text` ("500 coins") for the UI.
local Players = game:GetService("Players")
local BadgeService = game:GetService("BadgeService")

local Net = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Net"))
local Data = require(script.Parent:WaitForChild("Data"))

local Live = {}

export type Reward = { [string]: any }
type Grant = (Player, { [string]: any }, Reward, string) -> ()

local cfg: { [string]: any } = {}
local grant: Grant = function() end
local remote = Net.event("Live")
local notify = Net.event("Notify")
local hourHooks: { (number) -> () } = {}
local friendCount: { [Player]: number } = {}

local function today(): string
	return os.date("!%Y-%m-%d") :: string
end

local function state(d: { [string]: any }): { [string]: any }
	d.live = d.live or {}
	local s = d.live
	s.codes = s.codes or {}
	s.badges = s.badges or {}
	if s.day ~= today() then -- new day: fresh playtime gifts and quests
		s.day = today()
		s.minutes = 0
		s.played = {}
		s.quests = nil
	end
	return s
end

-- 3 quests a day from the pool, the same 3 for a player all day.
local function quests(player: Player, s: { [string]: any }): { { [string]: any } }
	if s.quests then
		return s.quests
	end
	local pool = cfg.quests or {}
	local picks: { { [string]: any } } = {}
	local rng = Random.new(player.UserId + tonumber((today():gsub("-", ""))) :: number)
	local idx = {}
	for i = 1, #pool do
		idx[i] = i
	end
	for i = #idx, 2, -1 do
		local j = rng:NextInteger(1, i)
		idx[i], idx[j] = idx[j], idx[i]
	end
	for k = 1, math.min(3, #idx) do
		local q: { [string]: any } = { key = pool[idx[k]].key, i = idx[k], n = 0, done = false }
		table.insert(picks, q)
	end
	s.quests = picks
	return picks
end

local function pay(player: Player, d: { [string]: any }, reward: Reward, source: string)
	grant(player, d, reward, source)
	notify:FireClient(player, "\u{1F381} +" .. tostring(reward.text or "reward") .. "!", "gold")
	remote:FireClient(player, "paid", source)
end

local function redeem(player: Player, d: { [string]: any }, raw: any)
	if type(raw) ~= "string" then
		return
	end
	local code = (string.gsub(string.upper(raw), "%s", ""))
	local c = (cfg.codes or {})[code]
	local s = state(d)
	if not c or (c.expires and os.time() > c.expires) then
		notify:FireClient(player, "That code doesn't work. Check the game page for new codes!", "orange")
	elseif s.codes[code] then
		notify:FireClient(player, "You already used " .. code .. "!", "orange")
	else
		s.codes[code] = true
		pay(player, d, c.reward, "code")
	end
end

local function claimGroup(player: Player, d: { [string]: any })
	local g = cfg.group
	local s = state(d)
	if not g or g.id == 0 then
		notify:FireClient(player, "The group gift is coming soon!", "orange")
		return
	end
	if s.group then
		notify:FireClient(player, "You already got the group gift!", "orange")
		return
	end
	local ok, inGroup = pcall(player.IsInGroupAsync, player, g.id)
	if not ok or not inGroup then
		notify:FireClient(player, "Join the group first, then press CLAIM!", "orange")
		return
	end
	s.group = true
	pay(player, d, g.reward, "group")
end

function Live.init(opts: { config: any, grant: Grant })
	cfg = opts.config or {}
	grant = opts.grant

	remote.OnServerEvent:Connect(function(player, action, arg)
		if not Net.allow(player, "live", 0.4) then
			return
		end
		local d = Data.get(player)
		if not d or type(action) ~= "string" then
			return
		end
		local s = state(d)
		if action == "code" then
			redeem(player, d, arg)
		elseif action == "group" then
			claimGroup(player, d)
		elseif action == "play" and type(arg) == "number" then
			local gift = (cfg.playtime or {})[arg]
			if gift and not s.played[tostring(arg)] and (s.minutes or 0) >= gift.minutes then
				s.played[tostring(arg)] = true
				pay(player, d, gift.reward, "playtime")
			end
		elseif action == "quest" and type(arg) == "number" then
			local q = quests(player, s)[arg]
			local def = q and (cfg.quests or {})[q.i]
			if def and not q.done and q.n >= def.goal then
				q.done = true
				pay(player, d, def.reward, "quest")
			end
		end
		Data.dirty(player)
	end)

	Data.onLoaded(function(player, d)
		local s = state(d)
		quests(player, s)
		Live.badge(player, "Welcome")
		-- invites: the new player and the friend who invited them both get the invite reward
		local ok, join = pcall(player.GetJoinData, player)
		local ref = ok and type(join) == "table" and (join :: any).ReferredByPlayerId
		if cfg.invite and type(ref) == "number" and ref ~= 0 and ref ~= player.UserId and not s.referredBy then
			s.referredBy = ref
			pay(player, d, cfg.invite.reward, "invite")
			local friend = Players:GetPlayerByUserId(ref)
			local fd = friend and Data.get(friend)
			if friend and fd then
				pay(friend, fd, cfg.invite.reward, "invite")
				notify:FireClient(friend, player.DisplayName .. " joined from your invite!", "pink")
			end
		end
		Data.dirty(player)
	end)

	-- friends in the server (for the friend bonus), counted once per join
	local function recount()
		local list = Players:GetPlayers()
		for _, p in ipairs(list) do
			local n = 0
			for _, q in ipairs(list) do
				if q ~= p then
					local ok, f = pcall(p.IsFriendsWithAsync, p, q.UserId)
					if ok and f then
						n += 1
					end
				end
			end
			friendCount[p] = n
			p:SetAttribute("Friends", n)
		end
	end
	Players.PlayerAdded:Connect(function()
		task.defer(recount)
	end)
	Players.PlayerRemoving:Connect(function(p)
		friendCount[p] = nil
		task.defer(recount)
	end)

	-- playtime minutes and the hourly clock
	task.spawn(function()
		local lastHour = os.date("!*t").hour
		while true do
			task.wait(60)
			for p, d in pairs(Data.all()) do
				local s = state(d)
				s.minutes = (s.minutes or 0) + 1
				Data.dirty(p)
			end
			local t = os.date("!*t")
			if t.hour ~= lastHour then
				lastHour = t.hour
				for _, fn in ipairs(hourHooks) do
					task.spawn(fn, t.hour)
				end
			end
		end
	end)
end

-- Add progress to today's quests with this key (e.g. Live.quest(player, "pop", 1)).
function Live.quest(player: Player, key: string, n: number?)
	local d = Data.get(player)
	if not d then
		return
	end
	local s = state(d)
	local changed = false
	for _, q in ipairs(quests(player, s)) do
		if q.key == key and not q.done then
			local def = (cfg.quests or {})[q.i]
			local before = q.n
			q.n = math.min(def and def.goal or math.huge, q.n + (n or 1))
			changed = changed or q.n ~= before
			if def and before < def.goal and q.n >= def.goal then
				notify:FireClient(player, "\u{2705} Quest done: " .. def.text .. "! Claim it in FREE.", "green")
			end
		end
	end
	if changed then
		Data.dirty(player)
	end
end

-- Award a badge from Config.Live.badges once (no-op while its id is 0).
function Live.badge(player: Player, key: string)
	local id = (cfg.badges or {})[key]
	local d = Data.get(player)
	if not id or id == 0 or not d then
		return
	end
	local s = state(d)
	if s.badges[key] then
		return
	end
	s.badges[key] = true
	task.spawn(function()
		pcall(BadgeService.AwardBadgeAsync, BadgeService, player.UserId, id)
	end)
end

-- 1 + friendBonus per friend in the server (1.3 with 3 friends at 0.1).
function Live.friendMult(player: Player): number
	return 1 + (cfg.friendBonus or 0) * (friendCount[player] or 0)
end

-- fn(hourUtc) at the top of every hour, for the game's hourly event.
function Live.onHour(fn: (number) -> ())
	table.insert(hourHooks, fn)
end

return Live

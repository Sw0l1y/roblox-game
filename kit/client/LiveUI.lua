-- Client side of kit/server/Live: the FREE panel (playtime gifts, daily quests, codes, group gift, invites),
-- the server-boost pill, the gift-a-pass player picker and the notifications opt-in prompt.
-- LiveUI.init(Config.Live) once; then Live.open() from a menu button and Live.onClaimable(fn) for its "!" badge.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local UI = require(script.Parent:WaitForChild("UI"))
local State = require(script.Parent:WaitForChild("State"))

local Live = {}

local player = Players.LocalPlayer
local cfg: { [string]: any } = {}
local remote: RemoteEvent? = nil
local panel: UI.Panel? = nil
local refresh: (() -> ())? = nil
local claimListeners: { (number) -> () } = {}
local inGroup = false

local function live(): { [string]: any }
	local d = State.data
	return (d and d.live) or {}
end

local function fire(action: string, arg: any?)
	if remote then
		(remote :: RemoteEvent):FireServer(action, arg)
	end
end

-- How many gifts/quests are ready to claim right now.
function Live.claimable(): number
	local s = live()
	local n = 0
	for i, g in ipairs((cfg.playtime or {}) :: { any }) do
		if (s.minutes or 0) >= g.minutes and not (s.played and s.played[tostring(i)]) then
			n += 1
		end
	end
	for _, q in ipairs((s.quests or {}) :: { any }) do
		local def = (cfg.quests or {})[q.i]
		if def and not q.done and q.n >= def.goal then
			n += 1
		end
	end
	if cfg.group and cfg.group.id ~= 0 and inGroup and not s.group then
		n += 1
	end
	return n
end

function Live.onClaimable(fn: (number) -> ())
	table.insert(claimListeners, fn)
	fn(Live.claimable())
end

local function row(parent: Instance, order: number, height: number): Frame
	local f = UI.card(parent, "white", { LayoutOrder = order, Size = UDim2.new(1, -8, 0, height) })
	return f
end

local function heading(parent: Instance, order: number, str: string)
	UI.text(parent, str, { LayoutOrder = order, Size = UDim2.new(1, -8, 0, 34), TextXAlignment = Enum.TextXAlignment.Left })
end

local function ink(l: TextLabel): TextLabel
	l.TextColor3 = UI.INK
	local s = l:FindFirstChildOfClass("UIStroke")
	if s then
		s.Enabled = false
	end
	return l
end

local function build()
	local p = UI.panel("Live", "\u{1F381} FREE STUFF", "green", Vector2.new(660, 520))
	panel = p
	local scroll = UI.scroll(p.body)
	UI.list(scroll, 8)
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	-- playtime gifts
	local playButtons: { { button: TextButton, sub: TextLabel } } = {}
	if cfg.playtime and #cfg.playtime > 0 then
		heading(scroll, nextOrder(), "\u{23F0} PLAYTIME GIFTS (every day)")
		local strip = UI.frame(scroll, { BackgroundTransparency = 1, LayoutOrder = nextOrder(), Size = UDim2.new(1, -8, 0, 112) })
		UI.list(strip, 8, true)
		for i, g in ipairs(cfg.playtime :: { any }) do
			local cell = UI.card(strip, "sky", { LayoutOrder = i, Size = UDim2.fromOffset(112, 108) })
			UI.text(cell, tostring(g.reward.text or ""), { Font = UI.BODY, Size = UDim2.new(1, -8, 0, 40), Position = UDim2.fromOffset(4, 4), TextWrapped = true })
			local sub = UI.text(cell, "", { Font = UI.BODY, Size = UDim2.new(1, -8, 0, 20), Position = UDim2.fromOffset(4, 44) })
			local b = UI.button(cell, "CLAIM", "green", { Size = UDim2.new(1, -12, 0, 36), Position = UDim2.new(0, 6, 1, -42) })
			b.MouseButton1Click:Connect(function()
				fire("play", i)
			end)
			playButtons[i] = { button = b, sub = sub }
		end
	end

	-- daily quests
	local questRows: { { text: TextLabel, bar: UI.Bar, button: TextButton } } = {}
	if cfg.quests and #cfg.quests > 0 then
		heading(scroll, nextOrder(), "\u{2705} DAILY QUESTS")
		for i = 1, 3 do
			local r = row(scroll, nextOrder(), 64)
			local t = ink(UI.text(r, "", { Font = UI.BODY, Size = UDim2.new(0.62, -10, 0, 26), Position = UDim2.fromOffset(10, 4), TextXAlignment = Enum.TextXAlignment.Left }))
			local bar = UI.bar(r, "green", { Size = UDim2.new(0.62, -10, 0, 24), Position = UDim2.fromOffset(10, 34) })
			local b = UI.button(r, "CLAIM", "green", { Size = UDim2.new(0.36, -10, 0, 48), Position = UDim2.new(0.64, 0, 0, 8) })
			b.MouseButton1Click:Connect(function()
				fire("quest", i)
			end)
			questRows[i] = { text = t, bar = bar, button = b }
		end
	end

	-- codes
	heading(scroll, nextOrder(), "\u{1F511} CODES")
	local cr = row(scroll, nextOrder(), 64)
	local box = Instance.new("TextBox")
	box.PlaceholderText = "Type a code..."
	box.Text = ""
	box.ClearTextOnFocus = false
	box.Font = UI.BODY
	box.TextScaled = true
	box.TextColor3 = UI.INK
	box.BackgroundColor3 = Color3.fromRGB(240, 244, 252)
	box.Size = UDim2.new(0.62, -14, 0, 44)
	box.Position = UDim2.fromOffset(10, 10)
	box.ZIndex = cr.ZIndex + 1
	box.Parent = cr
	UI.corner(box, 12)
	UI.stroke(box, 2.5)
	local redeem = UI.button(cr, "REDEEM", "blue", { Size = UDim2.new(0.36, -10, 0, 48), Position = UDim2.new(0.64, 0, 0, 8) })
	redeem.MouseButton1Click:Connect(function()
		fire("code", box.Text)
		box.Text = ""
	end)

	-- group gift
	local groupButton: TextButton? = nil
	if cfg.group then
		heading(scroll, nextOrder(), "\u{1F465} GROUP GIFT")
		local gr = row(scroll, nextOrder(), 64)
		ink(UI.text(gr, "Join our group for " .. tostring(cfg.group.reward.text or "a gift") .. "!", { Font = UI.BODY, Size = UDim2.new(0.62, -10, 0, 48), Position = UDim2.fromOffset(10, 8), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left }))
		local gb = UI.button(gr, "CLAIM", "purple", { Size = UDim2.new(0.36, -10, 0, 48), Position = UDim2.new(0.64, 0, 0, 8) })
		gb.MouseButton1Click:Connect(function()
			fire("group")
		end)
		groupButton = gb
	end

	-- invites and friends
	heading(scroll, nextOrder(), "\u{1F91D} FRIENDS")
	local ir = row(scroll, nextOrder(), 64)
	local inviteText = "Invite a friend"
	if cfg.invite then
		inviteText ..= ": you BOTH get " .. tostring(cfg.invite.reward.text or "a gift")
	end
	if cfg.friendBonus then
		inviteText ..= ". +" .. math.floor(cfg.friendBonus * 100 + 0.5) .. "% per friend here!"
	end
	ink(UI.text(ir, inviteText, { Font = UI.BODY, Size = UDim2.new(0.62, -10, 0, 48), Position = UDim2.fromOffset(10, 8), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left }))
	local ib = UI.button(ir, "INVITE", "pink", { Size = UDim2.new(0.36, -10, 0, 48), Position = UDim2.new(0.64, 0, 0, 8) })
	ib.MouseButton1Click:Connect(function()
		pcall(SocialService.PromptGameInvite, SocialService, player, nil :: any)
	end)

	ink(UI.text(scroll, "\u{1F44D} Like and \u{2B50} Favorite for new updates every week!", { Font = UI.BODY, LayoutOrder = nextOrder(), Size = UDim2.new(1, -8, 0, 30) }))

	refresh = function()
		local s = live()
		local minutes = s.minutes or 0
		for i, pb in ipairs(playButtons) do
			local g = cfg.playtime[i]
			local claimed = s.played and s.played[tostring(i)]
			pb.button.Visible = not claimed and minutes >= g.minutes
			pb.sub.Text = claimed and "\u{2714} CLAIMED" or (minutes >= g.minutes and "READY!" or (g.minutes - minutes) .. " min left")
		end
		for i, qr in ipairs(questRows) do
			local q = s.quests and s.quests[i]
			local def = q and cfg.quests[q.i]
			qr.text.Text = def and (def.text .. "  \u{2192} " .. tostring(def.reward.text or "")) or ""
			qr.bar.set(def and q.n / def.goal or 0, def and (q.n .. " / " .. def.goal) or "")
			qr.button.Visible = def ~= nil and not q.done and q.n >= def.goal
			qr.bar.frame.Visible = def ~= nil
		end
		if groupButton then
			(groupButton :: TextButton).Text = s.group and "\u{2714}" or "CLAIM"
		end
	end
	p.onOpen = refresh
	refresh()
end

-- The gift picker for a `gift` product (kit Shop): pick a player in this server, then buy for them.
function Live.gift(productKey: string, title: string)
	local old = UI.getPanel("LiveGift")
	if old then
		old.frame:Destroy()
	end
	local p = UI.panel("LiveGift", "\u{1F381} " .. title, "pink", Vector2.new(460, 420))
	local scroll = UI.scroll(p.body)
	UI.list(scroll, 8)
	local any = false
	for i, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			any = true
			local b = UI.button(scroll, other.DisplayName, "blue", { LayoutOrder = i, Size = UDim2.new(1, -8, 0, 52) })
			b.MouseButton1Click:Connect(function()
				p.close()
				Net.event("Buy"):FireServer("product", productKey, other.UserId)
			end)
		end
	end
	if not any then
		ink(UI.text(scroll, "Nobody else is here yet. Invite a friend!", { Font = UI.BODY, Size = UDim2.new(1, -8, 0, 60), TextWrapped = true }))
	end
	p.open()
end

-- A pill that shows running server boosts ("⚡ 2x COINS 12:04"). labels: kind -> text ("COINS").
function Live.boostPill(parent: Instance, labels: { [string]: string }, props: { [string]: any }?): Frame
	local pill = UI.card(parent, "gold", { Name = "BoostPill", Size = UDim2.fromOffset(260, 34), Visible = false })
	UI.set(pill, props)
	local t = UI.text(pill, "", { Font = UI.BODY, Size = UDim2.new(1, -12, 0.8, 0), Position = UDim2.new(0, 6, 0.1, 0) })
	task.spawn(function()
		while pill.Parent do
			local parts = {}
			local now = workspace:GetServerTimeNow()
			for kind, label in pairs(labels) do
				local ends = ReplicatedStorage:GetAttribute("BoostEnd_" .. kind)
				local mult = ReplicatedStorage:GetAttribute("Boost_" .. kind)
				if type(ends) == "number" and ends > now and type(mult) == "number" then
					local left = math.floor(ends - now)
					table.insert(parts, string.format("\u{26A1} %sx %s %d:%02d", tostring(mult), label, left // 60, left % 60))
				end
			end
			pill.Visible = #parts > 0
			t.Text = table.concat(parts, "   ")
			task.wait(1)
		end
	end)
	return pill
end

function Live.open()
	if panel then
		(panel :: UI.Panel).open()
	end
end

function Live.init(config: any)
	cfg = config or {}
	remote = Net.event("Live")
	build()
	if cfg.group and cfg.group.id ~= 0 then
		task.spawn(function()
			local ok, res = pcall(player.IsInGroupAsync, player, cfg.group.id)
			inGroup = ok and res == true
		end)
	end
	local function changed()
		if refresh and panel and (panel :: UI.Panel).isOpen() then
			(refresh :: () -> ())()
		end
		local n = Live.claimable()
		for _, fn in ipairs(claimListeners) do
			task.spawn(fn, n)
		end
	end
	State.onChange(changed)
	-- experience notifications: ask once, from the 2nd visit, after 5 minutes of play
	task.delay(300, function()
		local d = State.data
		if not d or (d.sessions or 0) < 2 then
			return
		end
		local ok, ens = pcall(game.GetService, game, "ExperienceNotificationService")
		if ok and ens then
			local can = false
			pcall(function()
				can = (ens :: any):CanPromptOptInAsync()
			end)
			if can then
				pcall(function()
					(ens :: any):PromptOptIn()
				end)
			end
		end
	end)
end

return Live

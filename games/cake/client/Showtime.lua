-- Showtime: the theme reveal, the turntable showcase with 1-5 star voting, the judges' score paddles, the
-- score pop, the podium, your personal results card and the clip moment: the winning cake growing giant on
-- the plaza with fireworks. Owns the stage camera during Vote and Results.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientLib = ReplicatedStorage:WaitForChild("ClientLib")
local Config = require(Shared:WaitForChild("Config"))
local CakeBuilder = require(Shared:WaitForChild("CakeBuilder"))
local Net = require(Shared:WaitForChild("Net"))
local Fmt = require(Shared:WaitForChild("Fmt"))
local UI = require(ClientLib:WaitForChild("UI"))
local Sfx = require(ClientLib:WaitForChild("Sfx"))
local Fx = require(ClientLib:WaitForChild("Fx"))
local Own = require(ClientLib:WaitForChild("Own"))
local Rig = require(ClientLib:WaitForChild("Rig"))

local Showtime = {}

type D = { [string]: any }

local player = Players.LocalPlayer
local voteRemote = Net.event("Vote")
local W = Config.World
local rng = Random.new()

local ctx: Own.Ctx = nil :: any
local state: Instance

-- world
local fxFolder = Instance.new("Folder")
fxFolder.Name = "ShowFx"
fxFolder.Parent = workspace
local spinParts: { { part: BasePart, cf: CFrame } } = {}
local spinAngle = 0
local showcase: Model? = nil
local showStart = 0
local showEnds = 0
local showSlot = 6
local showOwn = false
local showIdx = 0
local myVote = 0
local giant: Model? = nil
local giantStart = 0
local giantUntil = 0
local giantLanded = false
local giantScale = W.giantScale
local podiumTags: { Instance } = {}
local paddleRigs: { [Instance]: Rig.Rig } = setmetatable({}, { __mode = "k" }) :: any
local paddleToken: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local showRig: Rig.Rig? = nil
local giantRig: Rig.Rig? = nil
local giantBase = CFrame.new()
local themeToken = 0
local resultToken = 0

-- UI
local themeCard: Frame
local themeTitle: TextLabel
local themeGlyph: TextLabel
local themeName: TextLabel
local themeIdeas: TextLabel
local voteCard: Frame
local voteTitle: TextLabel
local voteSub: TextLabel
local starBtns: { TextButton } = {}
local ownLabel: TextLabel
local voteBar: UI.Bar
local scoreCard: Frame
local scoreValue: TextLabel
local scoreStars: TextLabel
local scoreWord: TextLabel
local resultCard: Frame
local resultTitle: TextLabel
local resultScore: TextLabel
local resultReward: TextLabel
local resultExtra: TextLabel

local function now(): number
	return workspace:GetServerTimeNow()
end

local function phase(): string
	return tostring(state:GetAttribute("Phase") or "Waiting")
end

local function backOut(k: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (k - 1) ^ 3 + c1 * (k - 1) ^ 2
end

local function tut(n: number)
	ctx.tut(n)
end

local function starsText(score: number): string
	local full = math.floor(score + 0.5)
	return string.rep("⭐", full) .. string.rep("☆", 5 - full)
end

local function scoreColor(s: number): Color3
	if s >= 4.5 then
		return Config.Palette.gold
	elseif s >= 3.5 then
		return Color3.fromRGB(120, 230, 120)
	elseif s >= 2.5 then
		return Color3.fromRGB(255, 220, 90)
	end
	return Color3.fromRGB(255, 150, 90)
end

-- Turntable spin -------------------------------------------------------------------------------------------
local function collectSpin()
	if #spinParts >= 5 then
		return
	end
	local stage = workspace:FindFirstChild("Stage")
	if not stage then
		return
	end
	spinParts = {}
	for _, d in ipairs(stage:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("Spin") == true then
			local bp = d :: BasePart
			table.insert(spinParts, { part = bp, cf = bp.CFrame })
		end
	end
end

-- Judges' paddles --------------------------------------------------------------------------------------------
local function judgeModel(i: number): Model?
	local stage = workspace:FindFirstChild("Stage")
	local f = stage and stage:FindFirstChild("Judges")
	if not f then
		return nil
	end
	for _, m in ipairs(f:GetChildren()) do
		if m:IsA("Model") and m:GetAttribute("Judge") == i then
			return m :: Model
		end
	end
	return nil
end

local function paddleOf(m: Model): Model?
	local p = m:FindFirstChild("Paddle")
	return if p and p:IsA("Model") then p :: Model else nil
end

local function setPaddleText(paddle: Model, text: string, color: Color3)
	local board = paddle:FindFirstChild("Board")
	if not board then
		return
	end
	for _, sg in ipairs(board:GetChildren()) do
		local l = sg:FindFirstChild("Text")
		if l and l:IsA("TextLabel") then
			l.Text = text
			l.TextColor3 = color
		end
	end
end

local function movePaddle(paddle: Model, up: boolean)
	local r = paddleRigs[paddle]
	if not r then
		r = Rig.new(paddle, CFrame.new())
		paddleRigs[paddle] = r
	end
	local rig = r :: Rig.Rig
	local my = (paddleToken[paddle] or 0) + 1
	paddleToken[paddle] = my
	task.spawn(function()
		for k = 1, 8 do
			if paddleToken[paddle] ~= my then
				return
			end
			local a = if up then k / 8 else 1 - k / 8
			Rig.pose(rig, CFrame.new(0, 1.9 * math.sin(a * math.pi / 2), 0))
			task.wait(0.02)
		end
	end)
end

local function lowerPaddles()
	for i = 1, 4 do
		local m = judgeModel(i)
		local p = m and paddleOf(m)
		if p and paddleRigs[p] then
			movePaddle(p, false)
			setPaddleText(p, "?", Config.Palette.pinkDeep)
		end
	end
end

-- Showcase ----------------------------------------------------------------------------------------------------
local function clearShowcase()
	local m = showcase
	if m then
		m:Destroy()
		showcase = nil
	end
	showRig = nil
end

local function buildCake(name: string, cake: any, base: CFrame, golden: boolean): Model?
	local m = Instance.new("Model")
	m.Name = name
	local ok, err = pcall(function()
		CakeBuilder.build(m, cake, base, { collide = false })
	end)
	if not ok then
		warn("[Showtime] cake build failed:", err)
		m:Destroy()
		return nil
	end
	if golden then
		local ringP = Instance.new("Part")
		ringP.Name = "GoldenRing"
		ringP.Shape = Enum.PartType.Cylinder
		ringP.Material = Enum.Material.Neon
		ringP.Color = Config.Palette.gold
		ringP.Size = Vector3.new(0.15, 12, 12)
		ringP.CFrame = base * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90))
		ringP.Anchored = true
		ringP.CanCollide = false
		ringP.CanQuery = false
		ringP.CanTouch = false
		ringP.Parent = m
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	m.WorldPivot = base
	return m
end

local function setStars(n: number)
	for i, b in ipairs(starBtns) do
		local on = i <= n
		UI.recolor(b, if on then "gold" else "grey")
		b.TextTransparency = if on or n == 0 then 0 else 0.35
	end
end

local function onShow(p: D)
	clearShowcase()
	lowerPaddles()
	scoreCard.Visible = false
	local base = CFrame.new(W.turntable)
	local m = buildCake("Showcase", p.cake, base, p.golden == true)
	if m then
		local r = Rig.new(m, base)
		Rig.pose(r, base, 0.05)
		m.Parent = fxFolder
		showcase = m
		showRig = r
	end
	showStart = os.clock()
	showSlot = tonumber(p.slot) or 6
	showEnds = tonumber(p.ends) or (now() + showSlot)
	showOwn = p.ownerId == player.UserId
	showIdx = tonumber(p.idx) or 0
	myVote = 0
	setStars(0)
	local name = tostring(p.name or "?")
	voteTitle.Text = if showOwn then "🎂 YOUR CAKE!" else "⭐ Rate " .. name .. "'s cake!"
	voteSub.Text = string.format("Cake %d of %d%s", tonumber(p.idx) or 1, tonumber(p.total) or 1, if p.isBot then " · NPC baker" else "")
	ownLabel.Visible = showOwn
	for _, b in ipairs(starBtns) do
		b.Visible = not showOwn
	end
	voteCard.Visible = true
	UI.punch(voteCard, 0.15)
	Sfx.play("whoosh", 0.4)
	Fx.burst(W.turntable + Vector3.new(0, 2, 0), { Config.Palette.pink, Config.Palette.mint, Config.Palette.sky, Config.Palette.lemon }, 12, 0.8)
	if showOwn then
		UI.banner("🤞 YOUR CAKE IS UP!", "pink", 1.6)
	end
end

local function onJudges(p: D)
	local scores = p.scores
	if type(scores) ~= "table" then
		return
	end
	local function show(i: number, s: number, delay: number, big: boolean)
		task.delay(delay, function()
			local m = judgeModel(i)
			local paddle = m and paddleOf(m)
			if not m or not paddle then
				return
			end
			setPaddleText(paddle, tostring(s), scoreColor(s))
			movePaddle(paddle, true)
			Sfx.play("pop", 0.45, 0.8 + s * 0.08)
			UI.floatAt(paddle:GetPivot().Position + Vector3.new(0, 3, 0), "⭐" .. s, scoreColor(s), if big then 52 else 40)
			if big then
				Fx.sparkle(paddle:GetPivot().Position, Config.Palette.gold, 2.5, 1)
				Sfx.play("sparkle", 0.5)
			end
		end)
	end
	for i, s in ipairs(scores) do
		show(i, tonumber(s) or 3, (i - 1) * 0.28, false)
	end
	local c = tonumber(p.celeb)
	if c then
		show(4, c, 1.0, true)
	end
end

local function onScore(p: D)
	local s = tonumber(p.score) or 0
	scoreValue.Text = string.format("⭐ %.1f", s)
	scoreValue.TextColor3 = scoreColor(s)
	scoreStars.Text = starsText(s)
	scoreWord.Text = (if s >= 4.5 then "INCREDIBLE!" elseif s >= 4 then "DELICIOUS!" elseif s >= 3 then "TASTY!" elseif s >= 2 then "NOT BAD!" else "OOPS!") .. "  " .. tostring(p.name or "")
	scoreCard.Visible = true
	UI.punch(scoreCard, 0.5)
	if s >= 4 then
		Sfx.play("cheer", 0.35, 1, 2.2)
		Fx.burst(W.turntable + Vector3.new(0, 8, 0), { Config.Palette.gold, Config.Palette.pink, Color3.new(1, 1, 1) }, 18, 1.1)
	else
		Sfx.play("clap", 0.45)
	end
	if p.ownerId == player.UserId then
		UI.confetti(40)
	end
	voteCard.Visible = false
	task.delay(1.4, lowerPaddles)
end

-- Results + podium ----------------------------------------------------------------------------------------------
local function clearPodium()
	for _, t in ipairs(podiumTags) do
		t:Destroy()
	end
	podiumTags = {}
end

local function onResults(p: D)
	clearShowcase()
	voteCard.Visible = false
	scoreCard.Visible = false
	lowerPaddles()
	clearPodium()
	local medals = { "🥇", "🥈", "🥉" }
	if type(p.podium) == "table" then
		for place, e: any in ipairs(p.podium) do
			local top = W.podium[place]
			if top then
				local a = Instance.new("Part")
				a.Name = "PodiumTag" .. place
				a.Size = Vector3.new(0.2, 0.2, 0.2)
				a.Transparency = 1
				a.Anchored = true
				a.CanCollide = false
				a.CanQuery = false
				a.CanTouch = false
				a.CFrame = CFrame.new(top + Vector3.new(0, 7.6, 0))
				local bb = Instance.new("BillboardGui")
				bb.Size = UDim2.fromOffset(220, 74)
				bb.AlwaysOnTop = true
				bb.LightInfluence = 0
				bb.MaxDistance = 300
				bb.Parent = a
				UI.text(bb, medals[place] .. " " .. tostring(e.name), { Size = UDim2.new(1, 0, 0.58, 0), TextColor3 = if place == 1 then Config.Palette.gold else Color3.new(1, 1, 1) })
				UI.text(bb, string.format("⭐ %.1f", tonumber(e.score) or 0), { Font = UI.BODY, Size = UDim2.new(1, 0, 0.4, 0), Position = UDim2.fromScale(0, 0.6) })
				a.Parent = fxFolder
				table.insert(podiumTags, a)
				Fx.burst(top + Vector3.new(0, 1, 0), { Config.Palette.gold, Config.Palette.pink, Config.Palette.sky }, 10, 0.9)
			end
		end
	end
	UI.confetti(120, { Config.Palette.pink, Config.Palette.mint, Config.Palette.sky, Config.Palette.lemon, Config.Palette.gold })
	Sfx.play("victory", 0.5)
end

-- Personal results card (Reward "round").
function Showtime.onReward(r: D)
	resultToken += 1
	local my = resultToken
	local place = tonumber(r.place) or 0
	local medals = { "🥇 1ST PLACE!", "🥈 2ND PLACE!", "🥉 3RD PLACE!" }
	resultTitle.Text = medals[place] or string.format("#%d of %d", place, tonumber(r.of) or place)
	resultScore.Text = string.format("⭐ %.1f   %s", tonumber(r.score) or 0, starsText(tonumber(r.score) or 0))
	resultReward.Text = string.format("+%s 🪙    +%s XP", Fmt.commas(tonumber(r.coins) or 0), Fmt.commas(tonumber(r.xp) or 0))
	local extras = {}
	if r.celebrity then
		table.insert(extras, "🌟 Celebrity 2x!")
	end
	if r.box then
		table.insert(extras, "🎁 +1 Mystery Box!")
	end
	resultExtra.Text = table.concat(extras, "   ")
	UI.recolor(resultCard, if place == 1 then "gold" elseif place <= 3 then "sky" else "purple")
	resultCard.Visible = true
	UI.punch(resultCard, 0.4)
	Sfx.play("cash", 0.6)
	if place == 1 then
		UI.confetti(80)
		Sfx.play("cheer", 0.4, 1, 2.5)
	end
	task.delay(0.5, function()
		ctx.flyCoins(resultCard.AbsolutePosition + resultCard.AbsoluteSize / 2, tonumber(r.coins) or 30)
	end)
	task.delay(5, function()
		if resultToken == my then
			resultCard.Visible = false
		end
	end)
end

-- Giant winning cake (the clip moment) -------------------------------------------------------------------------
local function clearGiant()
	local m = giant
	if m then
		m:Destroy()
		giant = nil
	end
	giantRig = nil
end

local function onGiant(p: D)
	clearGiant()
	local base = CFrame.new(W.giant) * CFrame.Angles(0, math.pi, 0)
	local m = buildCake("GiantCake", p.cake, base, p.golden == true)
	if not m then
		return
	end
	local plate = Instance.new("Part")
	plate.Name = "GiantPlate"
	plate.Shape = Enum.PartType.Cylinder
	plate.Color = if p.golden then Config.Palette.gold else Color3.new(1, 1, 1)
	plate.Reflectance = 0.15
	plate.Size = Vector3.new(0.4, 12.4, 12.4)
	plate.CFrame = base * CFrame.new(0, -0.2, 0) * CFrame.Angles(0, 0, math.rad(90))
	plate.Anchored = true
	plate.CanCollide = false
	plate.CanQuery = false
	plate.Parent = m
	local r = Rig.new(m, base)
	Rig.pose(r, base, 0.25)
	m.Parent = fxFolder
	giant = m
	giantRig = r
	giantBase = base
	giantStart = os.clock()
	giantUntil = os.clock() + Config.Round.giant - 0.5
	giantLanded = false
	local theme = Config.ThemeByKey[tostring(p.theme or "")]
	UI.banner("🏆 " .. tostring(p.name or "?") .. "'S " .. (if theme then string.upper(theme.name) .. " " .. theme.glyph else "") .. " CAKE!", "gold", 3)
	Sfx.play("reveal", 0.6)
	task.spawn(function()
		local cols = { Config.Palette.pink, Config.Palette.mint, Config.Palette.sky, Config.Palette.lemon, Config.Palette.gold, Config.Palette.lavender }
		task.wait(2.2)
		while giant == m and os.clock() < giantUntil - 0.3 do
			local a = rng:NextNumber(0, math.pi * 2)
			local pos = W.giant + Vector3.new(math.cos(a) * rng:NextNumber(10, 22), rng:NextNumber(24, 40), math.sin(a) * rng:NextNumber(6, 14))
			Fx.burst(pos, { cols[rng:NextInteger(1, #cols)], cols[rng:NextInteger(1, #cols)], Color3.new(1, 1, 1) }, 16, 1.6)
			Fx.shockwave(pos, cols[rng:NextInteger(1, #cols)], 7)
			Sfx.play("pop", 0.35, rng:NextNumber(0.7, 1.2))
			task.wait(rng:NextNumber(0.22, 0.4))
		end
	end)
end

-- Theme reveal ------------------------------------------------------------------------------------------------------
local function onTheme(p: D)
	themeToken += 1
	local my = themeToken
	local t = Config.ThemeByKey[tostring(p.theme or "")]
	if not t then
		return
	end
	local celeb = p.celebrity == true
	clearPodium()
	clearGiant()
	resultCard.Visible = false
	UI.recolor(themeCard, if celeb then "gold" else "pink")
	themeTitle.Text = if celeb then "🌟 CELEBRITY JUDGE ROUND 🌟" else "THIS ROUND'S THEME"
	themeIdeas.Text = ""
	themeCard.Visible = true
	UI.punch(themeCard, 0.3)
	task.spawn(function()
		Sfx.play("reveal", 0.5)
		for i = 1, 14 do
			if themeToken ~= my then
				return
			end
			local r = Config.Themes[rng:NextInteger(1, Config.RegularThemes)]
			themeGlyph.Text = r.glyph
			themeName.Text = string.upper(r.name)
			Sfx.play("swipe", 0.2, 1 + i * 0.03)
			task.wait(0.05 + i * 0.01)
		end
		if themeToken ~= my then
			return
		end
		themeGlyph.Text = t.glyph
		themeName.Text = string.upper(t.name)
		UI.punch(themeName, 0.5)
		UI.punch(themeGlyph, 0.6)
		local ideas = {}
		for i, id in ipairs(t.toppings) do
			local def = Config.ToppingById[id]
			if def and i <= 6 then
				table.insert(ideas, def.glyph)
			end
		end
		themeIdeas.Text = (if celeb then "Chef Gateau judges · 2x coins & XP! · " else "Ideas: ") .. table.concat(ideas, " ")
		Sfx.play("magic", 0.6)
		UI.confetti(if celeb then 90 else 40)
		if celeb then
			UI.flash("gold", 0.4)
		end
		task.wait(3.2)
		if themeToken == my then
			themeCard.Visible = false
		end
	end)
end

-- UI ------------------------------------------------------------------------------------------------------------------
local function buildUI()
	local root = UI.root
	themeCard = UI.card(root, "pink", { Name = "ThemeReveal", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(560, 250), Visible = false, ZIndex = 15 })
	themeTitle = UI.text(themeCard, "", { Font = UI.BODY, Size = UDim2.new(1, -20, 0, 32), Position = UDim2.fromOffset(10, 12), ZIndex = 16 })
	themeGlyph = UI.text(themeCard, "🎂", { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(96, 96), Position = UDim2.new(0.5, -48, 0, 46), ZIndex = 16 })
	themeName = UI.text(themeCard, "", { Size = UDim2.new(1, -30, 0, 52), Position = UDim2.fromOffset(15, 144), ZIndex = 16 })
	themeIdeas = UI.text(themeCard, "", { Font = UI.BODY, Size = UDim2.new(1, -30, 0, 34), Position = UDim2.fromOffset(15, 200), ZIndex = 16, TextColor3 = Color3.fromRGB(255, 244, 200) })

	voteCard = UI.card(root, "purple", { Name = "Vote", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(660, 182), Visible = false })
	voteTitle = UI.text(voteCard, "", { Size = UDim2.new(1, -24, 0, 40), Position = UDim2.fromOffset(12, 8) })
	voteSub = UI.text(voteCard, "", { Font = UI.BODY, Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 48), TextColor3 = Color3.fromRGB(235, 220, 255) })
	local row = UI.frame(voteCard, { BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 80), Position = UDim2.fromOffset(12, 74) })
	UI.list(row, 12, true)
	for i = 1, 5 do
		local b = UI.button(row, "⭐", "grey", { Name = "Star" .. i, Size = UDim2.fromOffset(100, 78), LayoutOrder = i })
		b.Font = Enum.Font.GothamBold
		UI.text(b, tostring(i), { Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -24, 1, -24), ZIndex = b.ZIndex + 2 })
		b.MouseButton1Click:Connect(function()
			if showOwn or phase() ~= "Vote" or not showcase then
				return
			end
			myVote = i
			setStars(i)
			voteRemote:FireServer(i, showIdx)
			Sfx.play("pop", 0.5, 0.8 + i * 0.1)
			UI.punch(b, 0.3)
			if i == 5 then
				Fx.burst(W.turntable + Vector3.new(0, 9, 0), { Config.Palette.gold, Config.Palette.pink }, 8, 0.7)
			end
			tut(4)
		end)
		starBtns[i] = b
	end
	ownLabel = UI.text(voteCard, "🤞 Everyone is rating your cake right now...", { Font = UI.BODY, Size = UDim2.new(1, -40, 0, 50), Position = UDim2.fromOffset(20, 90), Visible = false })
	voteBar = UI.bar(voteCard, "gold", { Size = UDim2.new(1, -40, 0, 12), Position = UDim2.new(0, 20, 1, -22) })

	scoreCard = UI.card(root, "gold", { Name = "Score", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 146), Size = UDim2.fromOffset(420, 150), Visible = false })
	scoreValue = UI.text(scoreCard, "", { Size = UDim2.new(1, -20, 0, 64), Position = UDim2.fromOffset(10, 8) })
	scoreStars = UI.text(scoreCard, "", { Font = Enum.Font.GothamBold, Size = UDim2.new(1, -40, 0, 34), Position = UDim2.fromOffset(20, 72) })
	scoreWord = UI.text(scoreCard, "", { Font = UI.BODY, Size = UDim2.new(1, -20, 0, 32), Position = UDim2.fromOffset(10, 110) })

	resultCard = UI.card(root, "gold", { Name = "Result", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromOffset(500, 230), Visible = false, ZIndex = 12 })
	resultTitle = UI.text(resultCard, "", { Size = UDim2.new(1, -20, 0, 58), Position = UDim2.fromOffset(10, 12), ZIndex = 13 })
	resultScore = UI.text(resultCard, "", { Font = UI.BODY, Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(10, 74), ZIndex = 13 })
	resultReward = UI.text(resultCard, "", { Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 114), ZIndex = 13, TextColor3 = Color3.fromRGB(255, 240, 150) })
	resultExtra = UI.text(resultCard, "", { Font = UI.BODY, Size = UDim2.new(1, -20, 0, 32), Position = UDim2.fromOffset(10, 172), ZIndex = 13 })
end

-- API ---------------------------------------------------------------------------------------------------------------------
function Showtime.onRound(kind: string, p: any)
	if type(p) ~= "table" then
		return
	end
	if kind == "theme" then
		onTheme(p)
	elseif kind == "show" then
		onShow(p)
	elseif kind == "judges" then
		onJudges(p)
	elseif kind == "score" then
		onScore(p)
	elseif kind == "results" then
		onResults(p)
	elseif kind == "giant" then
		onGiant(p)
	end
end

function Showtime.camera(): CFrame?
	local t = os.clock()
	if giant then
		local c = W.giantCam
		local a = math.sin(t * 0.25) * 0.35
		local off = c.pos - c.look
		local rotated = CFrame.Angles(0, a, 0):VectorToWorldSpace(off)
		local lift = math.min(1, (os.clock() - giantStart) / 2.4)
		return CFrame.lookAt(c.look + rotated, c.look + Vector3.new(0, 4 * lift, 0))
	end
	local ph = phase()
	if ph == "Vote" then
		local c = W.voteCam
		local a = math.sin(t * 0.35) * 0.22
		local rotated = CFrame.Angles(0, a, 0):VectorToWorldSpace(c.pos - c.look)
		return CFrame.lookAt(c.look + rotated, c.look)
	elseif ph == "Results" then
		local c = W.resultCam
		return CFrame.lookAt(c.pos, c.look)
	end
	return nil
end

function Showtime.tip(): string?
	if themeCard.Visible then
		return "" -- hides the tip pill: on short phone screens it sits under the theme reveal card
	end
	local d = ctx.data()
	if phase() == "Vote" and voteCard.Visible and not showOwn and myVote == 0 and d and (d.tut or 0) < 4 then
		return "⭐ Tap the stars to rate this cake: you earn 🪙 for voting!"
	end
	return nil
end

function Showtime.tick(dt: number)
	local ph = phase()
	collectSpin()
	spinAngle += dt * (if ph == "Vote" then 0.9 else 0.25)
	local rotC = CFrame.Angles(0, spinAngle, 0)
	for _, e in ipairs(spinParts) do
		e.part.CFrame = rotC * e.cf
	end
	local m = showcase
	local sr = showRig
	if m and sr then
		local k = math.min(1, (os.clock() - showStart) / 0.5)
		Rig.pose(sr, CFrame.new(W.turntable) * rotC, if k < 1 then math.max(0.05, backOut(k)) else 1)
		if ph ~= "Vote" then
			clearShowcase()
			voteCard.Visible = false
		end
	end
	if voteCard.Visible then
		-- set directly: voteBar.set starts a new tween, which every frame would pile up Tween objects
		voteBar.fill.Size = UDim2.fromScale(math.clamp((showEnds - now()) / math.max(showSlot, 1), 0, 1), 1)
	end
	local gr = giantRig
	if giant and gr then
		local k = math.min(1, (os.clock() - giantStart) / 2.4)
		if os.clock() > giantUntil then
			local sc = gr.scale * (1 - math.min(1, dt * 6))
			if sc < 0.1 then
				clearGiant()
			else
				Rig.pose(gr, giantBase, sc)
			end
		elseif k < 1 then
			Rig.pose(gr, giantBase, math.max(0.2, 0.25 + (giantScale - 0.25) * backOut(k)))
		elseif not giantLanded then
			giantLanded = true
			Rig.pose(gr, giantBase, giantScale)
			Fx.shockwave(W.giant + Vector3.new(0, 0.5, 0), Config.Palette.gold, 40)
			UI.shake(0.35)
			Sfx.play("thud", 0.6)
			Sfx.play("victory", 0.5)
			UI.confetti(140)
		end
	end
	if ph ~= "Results" and #podiumTags > 0 then
		clearPodium()
	end
	if ph ~= "Results" and ph ~= "Vote" and scoreCard.Visible then
		scoreCard.Visible = false
	end
end

function Showtime.init(c: Own.Ctx, stateFolder: Instance)
	ctx = c
	state = stateFolder
	buildUI()
end

return Showtime

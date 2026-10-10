-- The bag-opening moment: the bag wobbles, pops, and the soldiers inside flip in one by one on rarity-coloured
-- cards (with the real toy model, NEW! stickers, mutation glyphs and a louder fanfare for rarer pulls).
-- Also the smaller "MERGED!" card when the mold press finishes a unit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local ClientLib = ReplicatedStorage:WaitForChild("ClientLib")
local UI = require(ClientLib:WaitForChild("UI"))
local Sfx = require(ClientLib:WaitForChild("Sfx"))
local Game = require(ClientLib:WaitForChild("Game"))

local Reveal = {}

type Result = { unit: string, mut: string, tier: string, new: boolean }
type Job = { label: string, results: { Result } }

local queue: { Job } = {}
local busy = false
local againHandler: ((string) -> ())? = nil

local overlay = UI.frame(UI.root, {
	Name = "Reveal",
	BackgroundColor3 = Color3.fromRGB(16, 18, 32),
	BackgroundTransparency = 0.35,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 30,
})
local title = UI.text(overlay, "", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 70),
	Size = UDim2.fromOffset(700, 70),
	ZIndex = 32,
})
local bagIcon = UI.text(overlay, "🎒", {
	Font = Enum.Font.GothamBold,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.48),
	Size = UDim2.fromOffset(200, 200),
	ZIndex = 33,
})
local row = UI.frame(overlay, {
	Name = "Cards",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(760, 320),
	ZIndex = 31,
})
UI.list(row, 22, true)
local buttons = UI.frame(overlay, {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -40),
	Size = UDim2.fromOffset(560, 70),
	ZIndex = 31,
})
UI.list(buttons, 20, true)
local okBtn = UI.button(buttons, "AWESOME!", "green", { Size = UDim2.fromOffset(230, 64), LayoutOrder = 1, ZIndex = 33 })
local againBtn = UI.button(buttons, "OPEN ANOTHER 🎒", "orange", { Size = UDim2.fromOffset(260, 64), LayoutOrder = 2, ZIndex = 33 })

local current: Job? = nil
local closeToken = 0

local function card(r: Result, order: number): Frame
	local t = Tiers.get(r.tier)
	local c = UI.card(row, t.color, { Size = UDim2.fromOffset(220, 300), LayoutOrder = order, ZIndex = 32 })
	local g = c:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = Tiers.gradient(r.tier)
	end
	local holder = UI.frame(c, { BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 180), Position = UDim2.fromOffset(10, 10), ZIndex = 33 })
	Game.viewport(holder, r.unit, r.mut, { ZIndex = 34 })
	local name = UI.text(c, Config.unitName(r.unit, r.mut), { Size = UDim2.new(1, -16, 0, 40), Position = UDim2.new(0, 8, 0, 190), ZIndex = 35 })
	local tier = UI.text(c, string.upper(t.name), { Font = UI.BODY, Size = UDim2.new(1, -16, 0, 30), Position = UDim2.new(0, 8, 0, 232), ZIndex = 35, TextColor3 = UI.lighten(t.color, 0.4) })
	if t.rainbow or r.mut == "Rainbow" then
		UI.rainbow(name)
	end
	local m = Config.MutByKey[r.mut]
	if m then
		UI.text(c, m.glyph .. " " .. string.upper(m.name) .. " x" .. m.mult, { Font = UI.BODY, Size = UDim2.new(1, -16, 0, 26), Position = UDim2.new(0, 8, 0, 264), ZIndex = 35, TextColor3 = m.color })
	end
	if r.new then
		local s = UI.text(c, "NEW!", { Size = UDim2.fromOffset(90, 38), Position = UDim2.new(1, -70, 0, -14), Rotation = 12, ZIndex = 36, TextColor3 = Config.C.yellow, BackgroundTransparency = 0, BackgroundColor3 = Config.C.red })
		UI.corner(s, 10)
		UI.stroke(s, 3)
	end
	local _ = tier
	return c
end

local function close()
	overlay.Visible = false
	for _, ch in ipairs(row:GetChildren()) do
		if ch:IsA("Frame") then
			ch:Destroy()
		end
	end
	current = nil
	busy = false
	if #queue > 0 then
		local job = table.remove(queue, 1) :: Job
		task.defer(function()
			Reveal.show(job.label, job.results)
		end)
	end
end

local function bagGlyph(label: string): (string, string)
	local bag = Config.BagByKey[label]
	if bag then
		return bag.glyph, string.upper(bag.name) .. "!"
	end
	if label == "Supply Drop" then
		return Config.Icons.supply, "🪂 SUPPLY DROP!"
	end
	return "🎁", string.upper(label) .. "!"
end

function Reveal.show(label: string, results: { Result })
	if busy then
		table.insert(queue, { label = label, results = results })
		return
	end
	busy = true
	current = { label = label, results = results }
	closeToken += 1
	local my = closeToken
	local glyph, head = bagGlyph(label)
	title.Text = head
	bagIcon.Text = glyph
	bagIcon.Visible = true
	bagIcon.Rotation = 0
	okBtn.Visible = false
	againBtn.Visible = false
	overlay.Visible = true
	UI.punch(title, 0.4)
	Sfx.play("reveal", 0.6)
	-- wobble, then pop
	task.spawn(function()
		for i = 1, 6 do
			UI.tween(bagIcon, 0.08, { Rotation = (i % 2 == 0) and -14 or 14 })
			task.wait(0.09)
		end
		bagIcon.Visible = false
		Sfx.play("pop", 0.6)
		UI.flash("white", 0.5)
		local best = 1
		for i, r in ipairs(results) do
			local c = card(r, i)
			UI.punch(c, 0.5)
			local ti = Tiers.index[r.tier] or 1
			best = math.max(best, ti)
			if ti >= 4 or r.mut ~= "" then
				Sfx.play("sparkle", 0.6)
			else
				Sfx.play("pop", 0.4, 1 + i * 0.1)
			end
			task.wait(0.32)
		end
		if best >= 5 then
			Sfx.play("victory", 0.5)
			UI.confetti(80)
			UI.shake(0.4)
		elseif best >= 4 then
			Sfx.play("magic", 0.6)
			UI.confetti(40)
		end
		if my == closeToken and current then
			okBtn.Visible = true
			againBtn.Visible = Config.BagByKey[label] ~= nil and againHandler ~= nil
		end
		task.wait(9)
		if my == closeToken and overlay.Visible then
			close()
		end
	end)
end

function Reveal.merged(r: Result)
	local t = Tiers.get(r.tier)
	local holder = UI.card(UI.root, t.color, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(240, 300),
		ZIndex = 28,
	})
	local g = holder:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = Tiers.gradient(r.tier)
	end
	UI.text(holder, "🔀 MERGED!", { Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 8), ZIndex = 30 })
	local box = UI.frame(holder, { BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 170), Position = UDim2.fromOffset(10, 48), ZIndex = 29 })
	Game.viewport(box, r.unit, r.mut, { ZIndex = 30 })
	local name = UI.text(holder, Config.unitName(r.unit, r.mut), { Size = UDim2.new(1, -16, 0, 38), Position = UDim2.new(0, 8, 0, 222), ZIndex = 30 })
	UI.text(holder, string.upper(t.name) .. (r.new and "  ·  NEW!" or ""), { Font = UI.BODY, Size = UDim2.new(1, -16, 0, 28), Position = UDim2.new(0, 8, 0, 262), ZIndex = 30, TextColor3 = UI.lighten(t.color, 0.4) })
	if t.rainbow or r.mut == "Rainbow" then
		UI.rainbow(name)
	end
	UI.punch(holder, 0.6)
	Sfx.play("magic", 0.6)
	if r.new then
		UI.confetti(40)
	end
	task.delay(2.6, function()
		UI.tween(holder, 0.25, { Position = UDim2.fromScale(0.5, 1.4) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.wait(0.3)
		holder:Destroy()
	end)
end

function Reveal.onAgain(cb: (string) -> ())
	againHandler = cb
end

function Reveal.isOpen(): boolean
	return overlay.Visible
end

okBtn.MouseButton1Click:Connect(function()
	closeToken += 1
	close()
end)

againBtn.MouseButton1Click:Connect(function()
	local job = current
	closeToken += 1
	close()
	local h = againHandler
	if job and h then
		h(job.label)
	end
end)

return Reveal

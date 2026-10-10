--!strict
-- The pick screen shown before every race: three marbles from your collection (or loaners) as live 3D
-- cards with their stats, the power-up cards dealt for this track (the one that suits the track is
-- marked), the track's features, and a countdown. Every change is sent to the server right away, so a
-- player who never taps READY still races with what they chose.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local ClientLib = ReplicatedStorage:WaitForChild("ClientLib")
local UI = require(ClientLib:WaitForChild("UI"))
local Sfx = require(ClientLib:WaitForChild("Sfx"))
local MarbleIcon = require(ClientLib:WaitForChild("MarbleIcon"))

local Picker = {}

local pickRemote = Net.event("Pick")

local sheet = UI.frame(UI.root, {
	Name = "Picker",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 30, 1, -14),
	Size = UDim2.fromOffset(1060, 380),
	Visible = false,
	ZIndex = 12,
})
UI.corner(sheet, 24)
UI.stroke(sheet, 4.5)
UI.gradient(sheet, Color3.fromRGB(250, 251, 255), Color3.fromRGB(210, 220, 242))

local header = UI.frame(sheet, { BackgroundTransparency = 1, Size = UDim2.new(1, -40, 0, 56), Position = UDim2.new(0, 20, 0, 8), ZIndex = 13 })
local title = UI.text(header, "PICK YOUR MARBLE!", {
	Size = UDim2.fromOffset(380, 46),
	Position = UDim2.new(0, 0, 0, 4),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(255, 214, 50),
	ZIndex = 14,
})
local features = UI.text(header, "", {
	Size = UDim2.new(1, -520, 0, 30),
	Position = UDim2.new(0, 390, 0, 13),
	Font = UI.BODY,
	TextColor3 = UI.INK,
	ZIndex = 14,
})
local featStroke = features:FindFirstChildOfClass("UIStroke")
if featStroke then
	featStroke.Enabled = false
end
local timerBg = UI.frame(header, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(110, 52), ZIndex = 14 })
UI.corner(timerBg, 18)
UI.stroke(timerBg, 3.5)
UI.gradient(timerBg, UI.lighten(UI.colors.red, 0.1), UI.shade(UI.colors.red, 0.7))
local timer = UI.text(timerBg, "10", { Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.05, 0.1), ZIndex = 15 })

local marbleRow = UI.frame(sheet, { BackgroundTransparency = 1, Size = UDim2.fromOffset(630, 300), Position = UDim2.new(0, 20, 0, 68), ZIndex = 13 })
UI.list(marbleRow, 14, true, Enum.HorizontalAlignment.Left)
local right = UI.frame(sheet, { BackgroundTransparency = 1, Size = UDim2.fromOffset(380, 300), Position = UDim2.new(1, -400, 0, 68), ZIndex = 13 })
local slotsLabel = UI.text(right, "POWER-UP", {
	Size = UDim2.fromOffset(220, 26),
	Position = UDim2.fromOffset(4, 0),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(255, 150, 40),
	ZIndex = 14,
})
local slotBtn = UI.button(right, "🔒 +1 SLOT", "purple", { Size = UDim2.fromOffset(140, 30), Position = UDim2.new(1, -140, 0, -2), ZIndex = 14 })
slotBtn.MouseButton1Click:Connect(function()
	local p = UI.getPanel("Shop")
	if p then
		p.open()
	end
end)
local cardCol = UI.frame(right, { BackgroundTransparency = 1, Size = UDim2.fromOffset(380, 210), Position = UDim2.fromOffset(0, 30), ZIndex = 13 })
local cl = UI.list(cardCol, 6)
cl.VerticalAlignment = Enum.VerticalAlignment.Top
local ready = UI.button(right, "READY!", "green", { Size = UDim2.fromOffset(380, 58), Position = UDim2.new(0, 0, 1, -58), ZIndex = 14 })

-- State ------------------------------------------------------------------------------------------------
type Offer = { marbles: { { [string]: any } }, cards: { string }, slots: number, hint: string, raceNo: number }
local offer: Offer? = nil
local endsAt = 0
local chosenKey = ""
local chosenCards: { string } = {}
local marbleCards: { [string]: TextButton } = {}
local powerCards: { [string]: TextButton } = {}
local lastSent = 0
local sendQueued = false
local locked = false
local token = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

local function send()
	local o = offer
	if not o then
		return
	end
	local wait = 0.3 - (os.clock() - lastSent)
	if wait > 0 then
		if not sendQueued then
			sendQueued = true
			task.delay(wait, function()
				sendQueued = false
				send()
			end)
		end
		return
	end
	lastSent = os.clock()
	pickRemote:FireServer(chosenKey, chosenCards, locked)
end

local function refresh()
	for key, b in pairs(marbleCards) do
		local on = key == chosenKey
		local st = b:FindFirstChild("Sel") :: UIStroke?
		if st then
			st.Enabled = on
		end
		local check = b:FindFirstChild("Check") :: TextLabel?
		if check then
			check.Visible = on
		end
	end
	for key, b in pairs(powerCards) do
		local on = table.find(chosenCards, key) ~= nil
		local card = Config.CardByKey[key]
		UI.recolor(b, on and (card and card.color or "orange") or Color3.fromRGB(235, 238, 248))
		local check = b:FindFirstChild("Check") :: TextLabel?
		if check then
			check.Visible = on
		end
	end
	local o = offer
	if o then
		slotsLabel.Text = o.slots >= 2 and string.format("POWER-UPS (%d/2)", #chosenCards) or "POWER-UP"
	end
end

local function statBar(parent: Instance, glyph: string, value: number, y: number, color: any)
	UI.text(parent, glyph, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(10, y), ZIndex = 16 })
	local bg = UI.frame(parent, { Size = UDim2.new(1, -78, 0, 14), Position = UDim2.fromOffset(38, y + 4), BackgroundColor3 = UI.INK, ZIndex = 16 })
	UI.corner(bg, 7)
	local fill = UI.frame(bg, { Size = UDim2.fromScale(math.clamp(value / Config.Level.statCap, 0.05, 1), 1), BackgroundColor3 = UI.color(color), ZIndex = 17 })
	UI.corner(fill, 7)
	UI.text(parent, string.format("%.1f", value), {
		Font = UI.BODY,
		Size = UDim2.fromOffset(36, 20),
		Position = UDim2.new(1, -38, 0, y + 1),
		ZIndex = 16,
	})
end

local function buildMarbleCard(m: { [string]: any }, order: number)
	local id = tostring(m.id)
	local def = Config.MarbleById[id]
	local tier = def and def.tier or "Common"
	local tc = Tiers.get(tier)
	local b = Instance.new("TextButton")
	b.Name = "Marble" .. order
	b.AutoButtonColor = false
	b.Text = ""
	b.Size = UDim2.fromOffset(196, 296)
	b.LayoutOrder = order
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.ZIndex = 14
	b.Parent = marbleRow
	UI.corner(b, 18)
	UI.stroke(b, 3.5)
	UI.gradient(b, UI.lighten(tc.color, 0.55), UI.lighten(tc.color, 0.05))
	local sel = UI.stroke(b, 6, Color3.fromRGB(255, 214, 50))
	sel.Name = "Sel"
	sel.Enabled = false
	UI.juicy(b)
	MarbleIcon.view(b, id, m.mut, { Size = UDim2.fromOffset(150, 132), Position = UDim2.new(0.5, -75, 0, 4), ZIndex = 15 }, 1.1)
	local nameL = UI.text(b, MarbleIcon.name(id, m.mut), { Size = UDim2.new(1, -16, 0, 28), Position = UDim2.new(0, 8, 0, 136), ZIndex = 16 })
	local _ = nameL
	MarbleIcon.tierText(b, tier, { Size = UDim2.new(0.62, 0, 0, 22), Position = UDim2.new(0, 8, 0, 166), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 16 })
	UI.text(b, "LVL " .. tostring(m.lvl or 1), {
		Size = UDim2.new(0.36, 0, 0, 22),
		Position = UDim2.new(0.62, 0, 0, 166),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(255, 240, 150),
		ZIndex = 16,
	})
	statBar(b, Config.Icons.speed, tonumber(m.spd) or 0, 196, "sky")
	statBar(b, Config.Icons.grip, tonumber(m.grip) or 0, 222, "green")
	statBar(b, Config.Icons.weight, tonumber(m.wt) or 0, 248, "orange")
	if m.loaner then
		local tag = UI.text(b, "LOANER", {
			Size = UDim2.fromOffset(96, 24),
			Position = UDim2.new(1, -100, 0, 6),
			BackgroundTransparency = 0,
			BackgroundColor3 = UI.colors.purple,
			ZIndex = 17,
		})
		UI.corner(tag, 8)
	elseif order == 1 then
		local tag = UI.text(b, "⭐ BEST", {
			Size = UDim2.fromOffset(86, 24),
			Position = UDim2.new(0, 6, 0, 6),
			BackgroundTransparency = 0,
			BackgroundColor3 = UI.colors.orange,
			ZIndex = 17,
		})
		UI.corner(tag, 8)
	end
	local check = UI.text(b, "✔", {
		Name = "Check",
		Font = Enum.Font.GothamBold,
		Size = UDim2.fromOffset(40, 40),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 1, -6),
		TextColor3 = Color3.fromRGB(120, 255, 120),
		Visible = false,
		ZIndex = 18,
	})
	local _2 = check
	local key = tostring(m.key)
	b.MouseButton1Click:Connect(function()
		chosenKey = key
		refresh()
		send()
	end)
	marbleCards[key] = b
end

local function buildPowerCard(key: string, hint: string, order: number)
	local card = Config.CardByKey[key]
	if not card then
		return
	end
	local b = UI.button(cardCol, "", Color3.fromRGB(235, 238, 248), { Size = UDim2.fromOffset(380, 66), LayoutOrder = order, ZIndex = 14 })
	local pad = b:FindFirstChildOfClass("UIPadding")
	if pad then
		pad:Destroy()
	end
	local gloss = b:FindFirstChild("Gloss")
	if gloss then
		gloss:Destroy()
	end
	UI.text(b, card.glyph, { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(50, 50), Position = UDim2.fromOffset(8, 8), ZIndex = 16 })
	UI.text(b, string.upper(card.name), {
		Size = UDim2.fromOffset(170, 26),
		Position = UDim2.fromOffset(64, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 16,
	})
	local d = UI.text(b, card.desc, {
		Font = UI.BODY,
		Size = UDim2.new(1, -72, 0, 26),
		Position = UDim2.fromOffset(64, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.INK,
		ZIndex = 16,
	})
	local ds = d:FindFirstChildOfClass("UIStroke")
	if ds then
		ds.Enabled = false
	end
	if key == hint then
		local tag = UI.text(b, "👍 GOOD HERE", {
			Size = UDim2.fromOffset(124, 22),
			Position = UDim2.new(1, -130, 0, 6),
			BackgroundTransparency = 0,
			BackgroundColor3 = UI.colors.green,
			ZIndex = 17,
		})
		UI.corner(tag, 8)
	end
	UI.text(b, "✔", {
		Name = "Check",
		Font = Enum.Font.GothamBold,
		Size = UDim2.fromOffset(34, 34),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -10, 1, -12),
		TextColor3 = Color3.fromRGB(120, 255, 120),
		Visible = false,
		ZIndex = 18,
	})
	b.MouseButton1Click:Connect(function()
		local o = offer
		if not o then
			return
		end
		local i = table.find(chosenCards, key)
		if i then
			if #chosenCards > 1 then
				table.remove(chosenCards, i)
			end
		elseif #chosenCards < o.slots then
			table.insert(chosenCards, key)
		else
			chosenCards[#chosenCards] = key
		end
		refresh()
		send()
	end)
	powerCards[key] = b
end

ready.MouseButton1Click:Connect(function()
	if not offer then
		return
	end
	locked = true
	send()
	ready.Text = "LOCKED IN ✔"
	UI.recolor(ready, "teal")
	Sfx.play("unlock", 0.5)
	UI.punch(sheet, 0.04)
end)

-- Public ------------------------------------------------------------------------------------------------
function Picker.show(o: { [string]: any }, ends: number, info: { [string]: any }?)
	token += 1
	local my = token
	offer = o :: any
	endsAt = ends
	locked = false
	for _, c in ipairs(marbleRow:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for _, c in ipairs(cardCol:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	table.clear(marbleCards)
	table.clear(powerCards)
	local marbles = (o.marbles or {}) :: { { [string]: any } }
	for i, m in ipairs(marbles) do
		buildMarbleCard(m, i)
	end
	local hint = tostring(o.hint or "")
	for i, c in ipairs((o.cards or {}) :: { string }) do
		buildPowerCard(c, hint, i)
	end
	chosenKey = marbles[1] and tostring(marbles[1].key) or ""
	chosenCards = {}
	if hint ~= "" then
		table.insert(chosenCards, hint)
	end
	local slots = tonumber(o.slots) or 1
	if slots >= 2 then
		for _, c in ipairs((o.cards or {}) :: { string }) do
			if c ~= hint and #chosenCards < 2 then
				table.insert(chosenCards, c)
			end
		end
	end
	slotBtn.Visible = slots < 2
	local inf: { [string]: any } = info or {}
	local feats = inf.features
	if type(feats) == "table" and #feats > 0 then
		features.Text = "THIS TRACK: " .. table.concat(feats :: { string }, " · ")
	else
		features.Text = ""
	end
	if inf.gp then
		title.Text = "🏁 GRAND PRIX PICK!"
		title.TextColor3 = Color3.fromRGB(200, 140, 255)
	else
		title.Text = "PICK YOUR MARBLE!"
		title.TextColor3 = Color3.fromRGB(255, 214, 50)
	end
	ready.Text = "READY!"
	UI.recolor(ready, "green")
	refresh()
	send()
	sheet.Visible = true
	sheet.Position = UDim2.new(0.5, 30, 1, 400)
	UI.tween(sheet, 0.4, { Position = UDim2.new(0.5, 30, 1, -14) }, Enum.EasingStyle.Back)
	Sfx.play("swipe", 0.5)
	task.spawn(function()
		local last = -1
		while token == my and sheet.Visible do
			local left = math.max(0, math.ceil(endsAt - now()))
			if left ~= last then
				last = left
				timer.Text = tostring(left)
				if left <= 3 and left > 0 then
					UI.punch(timerBg, 0.2)
					Sfx.play("beep", 0.3, 1.4)
				end
			end
			if left <= 0 then
				break
			end
			task.wait(0.1)
		end
	end)
end

-- The server moved the deadline (everyone locked in early).
function Picker.setEnds(ends: number)
	endsAt = ends
end

function Picker.hide()
	token += 1
	if not sheet.Visible then
		return
	end
	offer = nil
	UI.tween(sheet, 0.25, { Position = UDim2.new(0.5, 30, 1, 400) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local my = token
	task.delay(0.26, function()
		if token == my then
			sheet.Visible = false
		end
	end)
end

function Picker.isOpen(): boolean
	return sheet.Visible and offer ~= nil
end

function Picker.isLocked(): boolean
	return locked
end

return Picker

-- Small UI pieces shared by the build tray and the shop: colour swatches, selection rings, chips, glyph cards.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientLib = ReplicatedStorage:WaitForChild("ClientLib")
local Config = require(Shared:WaitForChild("Config"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local UI = require(ClientLib:WaitForChild("UI"))

local Widgets = {}

local SEL = Color3.fromRGB(255, 236, 90)

function Widgets.rainbowSeq(): ColorSequence
	local r = Config.Rainbow
	local kps = {}
	for i, c in ipairs(r) do
		table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (#r - 1), c))
	end
	return ColorSequence.new(kps)
end

-- Bright yellow ring shown around the selected chip/swatch.
function Widgets.selRing(parent: GuiObject, radius: number?): Frame
	local f = UI.frame(parent, {
		Name = "Sel",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 10, 1, 10),
		Visible = false,
		ZIndex = parent.ZIndex + 4,
	})
	UI.corner(f, radius or 16)
	local s = Instance.new("UIStroke")
	s.Color = SEL
	s.Thickness = 4
	s.Parent = f
	return f
end

-- Strip a kit button down to a blank clickable card (no padding, so children position freely).
function Widgets.blank(b: TextButton)
	local pad = b:FindFirstChildOfClass("UIPadding")
	if pad then
		pad:Destroy()
	end
	b.Text = ""
end

export type Swatch = { button: TextButton, lock: TextLabel, sel: Frame, key: string }

-- Round colour swatch button (Rainbow and Galaxy get gradients; "None" and "Auto" are special).
function Widgets.swatch(parent: Instance, key: string, size: number, order: number?): Swatch
	local def = Config.ColorByKey[key]
	local b = Instance.new("TextButton")
	b.Name = "Swatch_" .. key
	b.AutoButtonColor = false
	b.Text = ""
	b.BorderSizePixel = 0
	b.Size = UDim2.fromOffset(size, size)
	b.BackgroundColor3 = if def then def.color else Color3.fromRGB(255, 255, 255)
	b.LayoutOrder = order or 0
	UI.corner(b, math.floor(size / 2))
	UI.stroke(b, 3)
	if def and def.special == "rainbow" then
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		local g = Instance.new("UIGradient")
		g.Color = Widgets.rainbowSeq()
		g.Rotation = 45
		g.Parent = b
	elseif def and def.special == "galaxy" then
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		UI.gradient(b, Color3.fromRGB(150, 80, 220), Color3.fromRGB(30, 20, 80), 45)
		UI.text(b, "✨", { Font = Enum.Font.GothamBold, Size = UDim2.fromScale(0.6, 0.6), Position = UDim2.fromScale(0.2, 0.2), ZIndex = b.ZIndex + 1 })
	elseif def and def.neon then
		UI.text(b, "⚡", { Font = Enum.Font.GothamBold, Size = UDim2.fromScale(0.6, 0.6), Position = UDim2.fromScale(0.2, 0.2), ZIndex = b.ZIndex + 1 })
	elseif def and def.gloss then
		local shine = UI.frame(b, { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.25, Size = UDim2.fromScale(0.28, 0.28), Position = UDim2.fromScale(0.2, 0.16), ZIndex = b.ZIndex + 1 })
		UI.corner(shine, math.floor(size / 6))
	elseif key == "None" then
		UI.text(b, "🚫", { Font = Enum.Font.GothamBold, Size = UDim2.fromScale(0.62, 0.62), Position = UDim2.fromScale(0.19, 0.19), ZIndex = b.ZIndex + 1 })
	elseif key == "Auto" then
		UI.text(b, "✨", { Font = Enum.Font.GothamBold, Size = UDim2.fromScale(0.62, 0.62), Position = UDim2.fromScale(0.19, 0.19), ZIndex = b.ZIndex + 1 })
	end
	local lock = UI.text(b, "🔒", {
		Name = "Lock",
		Font = Enum.Font.GothamBold,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.62),
		Visible = false,
		ZIndex = b.ZIndex + 2,
	})
	local sel = Widgets.selRing(b, math.floor(size / 2) + 5)
	b.Parent = parent
	UI.juicy(b)
	return { button = b, lock = lock, sel = sel, key = key }
end

-- A small labelled chip button (text or glyph) with a selection ring.
export type Chip = { button: TextButton, sel: Frame, lock: TextLabel }
function Widgets.chip(parent: Instance, text: string, color: any, w: number, h: number, order: number?): Chip
	local b = UI.button(parent, text, color, { Size = UDim2.fromOffset(w, h), LayoutOrder = order or 0 })
	local lock = UI.text(b, "🔒", {
		Name = "Lock",
		Font = Enum.Font.GothamBold,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 8, 0, -10),
		Size = UDim2.fromOffset(22, 22),
		Visible = false,
		ZIndex = b.ZIndex + 3,
	})
	return { button = b, sel = Widgets.selRing(b, 16), lock = lock }
end

-- Glyph card for a topping (tray and Index): big glyph, name, tier-coloured background.
export type GlyphCard = { button: TextButton, glyph: TextLabel, name: TextLabel, foot: TextLabel, sel: Frame }
function Widgets.toppingCard(parent: Instance, id: string, w: number, h: number, order: number?): GlyphCard
	local def = Config.ToppingById[id]
	local tier = Tiers.get(def.tier)
	local b = UI.button(parent, "", tier.color, { Name = id, Size = UDim2.fromOffset(w, h), LayoutOrder = order or 0 })
	Widgets.blank(b)
	local glyph = UI.text(b, def.glyph, { Font = Enum.Font.GothamBold, Size = UDim2.new(1, 0, 0.5, 0), Position = UDim2.fromScale(0, 0.04), ZIndex = b.ZIndex + 1 })
	local name = UI.text(b, def.name, { Font = UI.BODY, Size = UDim2.new(1, -8, 0.2, 0), Position = UDim2.new(0, 4, 0.54, 0), ZIndex = b.ZIndex + 1 })
	local foot = UI.text(b, "", { Font = UI.BODY, Size = UDim2.new(1, -8, 0.2, 0), Position = UDim2.new(0, 4, 0.76, 0), ZIndex = b.ZIndex + 1, TextColor3 = Color3.fromRGB(255, 240, 150) })
	if tier.rainbow then
		UI.rainbow(name)
	end
	return { button = b, glyph = glyph, name = name, foot = foot, sel = Widgets.selRing(b, 16) }
end

return Widgets

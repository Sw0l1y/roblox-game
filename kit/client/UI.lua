-- Juicy simulator UI kit (PROTOCOL.md §3.5): thick dark outlines, top-to-bottom gradients, bubbly buttons that
-- bounce, rolling counters, toasts, banners, floaters, confetti, camera kick, coin fly-to-HUD, modal panels.
-- Everything sits under one ScreenGui; `UI.root` is scaled for phones, `UI.fx` (effects) is not.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Sfx = require(script.Parent:WaitForChild("Sfx"))

local UI = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local rng = Random.new()

UI.TITLE = Enum.Font.LuckiestGuy
UI.BODY = Enum.Font.FredokaOne
UI.WHITE = Color3.new(1, 1, 1)
UI.INK = Color3.fromRGB(28, 30, 48)
UI.colors = {
	green = Color3.fromRGB(80, 220, 90),
	blue = Color3.fromRGB(60, 160, 255),
	sky = Color3.fromRGB(90, 210, 255),
	orange = Color3.fromRGB(255, 150, 40),
	yellow = Color3.fromRGB(255, 214, 50),
	gold = Color3.fromRGB(255, 196, 40),
	red = Color3.fromRGB(255, 70, 70),
	pink = Color3.fromRGB(255, 100, 190),
	purple = Color3.fromRGB(170, 100, 255),
	teal = Color3.fromRGB(40, 210, 190),
	grey = Color3.fromRGB(150, 156, 170),
	white = Color3.fromRGB(255, 255, 255),
	dark = Color3.fromRGB(44, 48, 72),
}

function UI.color(c: any): Color3
	if typeof(c) == "Color3" then
		return c
	end
	return UI.colors[c] or UI.colors.white
end

-- ScreenGui, scaled root and the effects layer ------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "Main"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")
UI.gui = gui

local root = Instance.new("Frame")
root.Name = "Root"
root.BackgroundTransparency = 1
root.Size = UDim2.fromScale(1, 1)
root.Parent = gui
UI.root = root

local rootScale = Instance.new("UIScale")
rootScale.Parent = root
local function rescale()
	local vp = camera.ViewportSize
	-- phones get 10% bigger UI so buttons stay thumb-sized (~44 px instead of ~40 px)
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local s = math.clamp(math.min(vp.X / 1280, vp.Y / 760) * (touch and 1.1 or 1), 0.5, 1.1)
	rootScale.Scale = s
	-- keep the root covering the screen after scaling
	root.Size = UDim2.fromOffset(vp.X / s, vp.Y / s)
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()
UI.scale = function()
	return rootScale.Scale
end

local fx = Instance.new("Frame")
fx.Name = "Fx"
fx.BackgroundTransparency = 1
fx.Size = UDim2.fromScale(1, 1)
fx.ZIndex = 50
fx.Parent = gui
UI.fx = fx

UI.isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Primitives ------------------------------------------------------------------------------------------

function UI.tween(obj: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

function UI.shade(c: Color3, f: number): Color3
	return Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
end

function UI.lighten(c: Color3, f: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), f)
end

function UI.corner(obj: Instance, r: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 14)
	c.Parent = obj
	return c
end

function UI.stroke(obj: Instance, thickness: number?, color: Color3?, contextual: boolean?): UIStroke
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 3
	s.Color = color or UI.INK
	s.ApplyStrokeMode = contextual and Enum.ApplyStrokeMode.Contextual or Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = obj
	return s
end

function UI.gradient(obj: Instance, top: Color3, bottom: Color3, rotation: number?): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = rotation or 90
	g.Parent = obj
	return g
end

function UI.pad(obj: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = obj
end

function UI.set(obj: Instance, props: { [string]: any }?)
	for k, v in pairs(props or {}) do
		(obj :: any)[k] = v
	end
end

-- Outlined text (Luckiest Guy by default).
function UI.text(parent: Instance, str: string, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = UI.TITLE
	l.TextScaled = true
	l.TextColor3 = UI.WHITE
	l.Text = str
	l.Size = UDim2.fromOffset(200, 40)
	UI.stroke(l, 2.5, UI.INK, true)
	UI.set(l, props)
	l.Parent = parent
	return l
end

function UI.frame(parent: Instance, props: { [string]: any }?): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = UI.WHITE
	UI.set(f, props)
	f.Parent = parent
	return f
end

-- Rounded, outlined, gradient card.
function UI.card(parent: Instance, color: any, props: { [string]: any }?): Frame
	local c = UI.color(color)
	local f = UI.frame(parent, props)
	UI.corner(f, 16)
	UI.stroke(f, 3.5)
	UI.gradient(f, UI.lighten(c, 0.15), UI.shade(c, 0.72))
	return f
end

local scales: { [Instance]: UIScale } = setmetatable({}, { __mode = "k" }) :: any
function UI.punch(obj: GuiObject, amount: number?)
	local sc = scales[obj]
	if not sc then
		sc = Instance.new("UIScale")
		sc.Parent = obj
		scales[obj] = sc
	end
	sc.Scale = 1 + (amount or 0.15)
	UI.tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

function UI.juicy(b: GuiButton, sound: string?)
	b.MouseEnter:Connect(function()
		UI.punch(b, 0.06)
	end)
	b.MouseButton1Down:Connect(function()
		UI.punch(b, -0.08)
		Sfx.play(sound or "click", 0.5, rng:NextNumber(0.95, 1.08))
	end)
	return b
end

-- Bubbly gradient button with a thick outline and a glossy top highlight.
function UI.button(parent: Instance, str: string, color: any, props: { [string]: any }?): TextButton
	local c = UI.color(color)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = UI.WHITE
	b.Font = UI.TITLE
	b.TextScaled = true
	b.TextColor3 = UI.WHITE
	b.Text = str
	b.Size = UDim2.fromOffset(180, 56)
	UI.stroke(b, 2.5, UI.INK, true)
	UI.set(b, props)
	b.Parent = parent
	UI.corner(b, 14)
	UI.stroke(b, 3.5)
	UI.gradient(b, UI.lighten(c, 0.12), UI.shade(c, 0.68))
	local gloss = UI.frame(b, {
		Name = "Gloss",
		BackgroundTransparency = 0.72,
		Size = UDim2.new(1, -12, 0.36, 0),
		Position = UDim2.new(0, 6, 0, 4),
		ZIndex = b.ZIndex,
	})
	UI.corner(gloss, 10)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.14, 0)
	pad.PaddingBottom = UDim.new(0.14, 0)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = b
	UI.juicy(b)
	return b
end

function UI.recolor(b: GuiObject, color: any)
	local c = UI.color(color)
	local g = b:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = ColorSequence.new(UI.lighten(c, 0.12), UI.shade(c, 0.68))
	end
end

-- Square icon button with an emoji/glyph or image and a label underneath, plus a red badge.
export type IconButton = { button: TextButton, icon: TextLabel | ImageLabel, label: TextLabel, setBadge: (any) -> () }
function UI.iconButton(parent: Instance, glyph: string, label: string, color: any, props: { [string]: any }?): IconButton
	local b = UI.button(parent, "", color, props)
	b.Size = (props and props.Size) or UDim2.fromOffset(78, 78)
	local pad = b:FindFirstChildOfClass("UIPadding")
	if pad then
		pad:Destroy()
	end
	local icon: any
	if glyph:match("^rbxassetid://") then
		icon = Instance.new("ImageLabel")
		icon.BackgroundTransparency = 1
		icon.Image = glyph
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Size = UDim2.fromScale(0.78, 0.78)
		icon.Position = UDim2.fromScale(0.11, 0.04)
		icon.Parent = b
	else
		icon = UI.text(b, glyph, {
			Font = Enum.Font.GothamBold,
			Size = UDim2.fromScale(0.72, 0.62),
			Position = UDim2.fromScale(0.14, 0.06),
		})
	end
	icon.ZIndex = b.ZIndex + 1
	local l = UI.text(b, label, {
		Size = UDim2.new(1.2, 0, 0.32, 0),
		Position = UDim2.new(-0.1, 0, 0.72, 0),
		ZIndex = b.ZIndex + 2,
	})
	local badge = UI.text(b, "", {
		Font = UI.BODY,
		Size = UDim2.fromOffset(28, 28),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		BackgroundTransparency = 0,
		BackgroundColor3 = UI.colors.red,
		Visible = false,
		ZIndex = b.ZIndex + 3,
	})
	UI.corner(badge, 14)
	UI.stroke(badge, 2.5)
	local function setBadge(v: any)
		if v == nil or v == false or v == 0 or v == "" then
			badge.Visible = false
		else
			badge.Visible = true
			badge.Text = v == true and "!" or tostring(v)
		end
	end
	return { button = b, icon = icon, label = l, setBadge = setBadge }
end

-- Vertical or horizontal list layout.
function UI.list(parent: Instance, padding: number?, horizontal: boolean?, align: Enum.HorizontalAlignment?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding or 8)
	l.FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.HorizontalAlignment = align or Enum.HorizontalAlignment.Center
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.Parent = parent
	return l
end

function UI.grid(parent: Instance, cell: UDim2, padding: number?): UIGridLayout
	local g = Instance.new("UIGridLayout")
	g.CellSize = cell
	g.CellPadding = UDim2.fromOffset(padding or 10, padding or 10)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.HorizontalAlignment = Enum.HorizontalAlignment.Center
	g.Parent = parent
	return g
end

function UI.scroll(parent: Instance, props: { [string]: any }?): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 8
	s.ScrollBarImageColor3 = UI.INK
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.new()
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	s.Size = UDim2.fromScale(1, 1)
	UI.set(s, props)
	s.Parent = parent
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, 8)
	p.PaddingBottom = UDim.new(0, 8)
	p.PaddingLeft = UDim.new(0, 6)
	p.PaddingRight = UDim.new(0, 14)
	p.Parent = s
	return s
end

-- Progress bar --------------------------------------------------------------------------------------

export type Bar = { frame: Frame, fill: Frame, label: TextLabel, set: (number, string?) -> () }
function UI.bar(parent: Instance, color: any, props: { [string]: any }?): Bar
	local c = UI.color(color)
	local f = UI.frame(parent, { BackgroundColor3 = UI.INK, Size = UDim2.fromOffset(300, 30) })
	UI.set(f, props)
	UI.corner(f, 12)
	UI.stroke(f, 3)
	local fill = UI.frame(f, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = UI.WHITE })
	UI.corner(fill, 12)
	UI.gradient(fill, UI.lighten(c, 0.2), UI.shade(c, 0.75))
	local label = UI.text(f, "", { Size = UDim2.fromScale(1, 0.86), Position = UDim2.fromScale(0, 0.07), ZIndex = f.ZIndex + 2 })
	local function set(frac: number, str: string?)
		UI.tween(fill, 0.25, { Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1) })
		if str then
			label.Text = str
		end
	end
	return { frame = f, fill = fill, label = label, set = set }
end

-- Rolling counter ---------------------------------------------------------------------------------

export type Counter = { frame: Frame, value: TextLabel, icon: TextLabel, set: (number) -> (), get: () -> number }
function UI.counter(parent: Instance, glyph: string, color: any, format: (number) -> string, props: { [string]: any }?): Counter
	local c = UI.color(color)
	local f = UI.frame(parent, { Size = UDim2.fromOffset(230, 52), BackgroundColor3 = UI.WHITE })
	UI.set(f, props)
	UI.corner(f, 26)
	UI.stroke(f, 3.5)
	UI.gradient(f, UI.shade(c, 0.55), UI.shade(c, 0.32))
	local icon = UI.text(f, glyph, {
		Font = Enum.Font.GothamBold,
		Size = UDim2.fromOffset(64, 64),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		ZIndex = f.ZIndex + 2,
	})
	local value = UI.text(f, "0", {
		Size = UDim2.new(1, -56, 0.8, 0),
		Position = UDim2.new(0, 46, 0.1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.lighten(c, 0.35),
		ZIndex = f.ZIndex + 1,
	})
	local shown, target = 0, 0
	local holder = Instance.new("NumberValue")
	holder.Changed:Connect(function(v)
		shown = v
		value.Text = format(v)
	end)
	local function set(n: number)
		if n == target then
			return
		end
		local up = n > target
		target = n
		holder.Value = shown
		UI.tween(holder, 0.45, { Value = n }, Enum.EasingStyle.Quad)
		if up then
			UI.punch(icon :: any, 0.35)
		end
	end
	value.Text = format(0)
	return { frame = f, value = value, icon = icon, set = set, get = function()
		return target
	end }
end

-- Panels (one open at a time) -------------------------------------------------------------------------

export type Panel = { frame: Frame, body: Frame, title: TextLabel, open: () -> (), close: () -> (), isOpen: () -> boolean, onOpen: (() -> ())? }
local panels: { [string]: Panel } = {}
local openName: string? = nil

local dim = UI.frame(root, {
	Name = "Dim",
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 20,
})

function UI.closeAll()
	if openName then
		local p = panels[openName]
		openName = nil
		if p then
			p.close()
		end
	end
end

function UI.panel(name: string, title: string, color: any, size: Vector2?): Panel
	local c = UI.color(color)
	local sz = size or Vector2.new(640, 460)
	local f = UI.frame(root, {
		Name = name .. "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(sz.X, sz.Y),
		BackgroundColor3 = UI.WHITE,
		Visible = false,
		ZIndex = 21,
	})
	UI.corner(f, 22)
	UI.stroke(f, 4.5)
	UI.gradient(f, Color3.fromRGB(250, 251, 255), Color3.fromRGB(214, 222, 240))
	local header = UI.frame(f, {
		Name = "Header",
		Size = UDim2.new(0.62, 0, 0, 62),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 0),
		ZIndex = 23,
	})
	UI.corner(header, 18)
	UI.stroke(header, 4)
	UI.gradient(header, UI.lighten(c, 0.1), UI.shade(c, 0.7))
	local t = UI.text(header, title, { Size = UDim2.fromScale(0.9, 0.78), Position = UDim2.fromScale(0.05, 0.11), ZIndex = 24 })
	local x = UI.button(f, "X", "red", {
		Size = UDim2.fromOffset(54, 54),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -8, 0, 8),
		ZIndex = 25,
	})
	local body = UI.frame(f, {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -36, 1, -64),
		Position = UDim2.new(0, 18, 0, 46),
		ZIndex = 22,
	})
	local p: Panel
	p = {
		frame = f,
		body = body,
		title = t,
		open = function()
			if openName == name then
				return
			end
			UI.closeAll()
			openName = name
			f.Visible = true
			dim.Visible = true
			UI.tween(dim, 0.2, { BackgroundTransparency = 0.55 })
			f.Position = UDim2.fromScale(0.5, 0.6)
			UI.tween(f, 0.32, { Position = UDim2.fromScale(0.5, 0.52) }, Enum.EasingStyle.Back)
			UI.punch(f, -0.12)
			Sfx.play("open", 0.5)
			local cb = p.onOpen
			if cb then
				task.spawn(cb)
			end
		end,
		close = function()
			if openName == name then
				openName = nil
			end
			f.Visible = false
			if not openName then
				UI.tween(dim, 0.15, { BackgroundTransparency = 1 })
				task.delay(0.15, function()
					if not openName then
						dim.Visible = false
					end
				end)
			end
		end,
		isOpen = function()
			return openName == name
		end,
		onOpen = nil :: (() -> ())?,
	}
	x.MouseButton1Click:Connect(p.close)
	panels[name] = p
	return p
end

function UI.toggle(name: string)
	local p = panels[name]
	if p then
		if p.isOpen() then
			p.close()
		else
			p.open()
		end
	end
end

function UI.getPanel(name: string): Panel?
	return panels[name]
end

-- Tabs inside a panel body: returns pages by name and a select function.
function UI.tabs(parent: Instance, names: { string }, colors: { any }?): ({ [string]: Frame }, (string) -> ())
	local bar = UI.frame(parent, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48) })
	UI.list(bar, 10, true)
	local pages: { [string]: Frame } = {}
	local buttons: { [string]: TextButton } = {}
	local function select(n: string)
		for k, pg in pairs(pages) do
			pg.Visible = k == n
			buttons[k].Size = k == n and UDim2.fromOffset(150, 46) or UDim2.fromOffset(136, 40)
		end
	end
	for i, n in ipairs(names) do
		local b = UI.button(bar, n, colors and colors[i] or "blue", { Size = UDim2.fromOffset(136, 40), LayoutOrder = i })
		buttons[n] = b
		local pg = UI.frame(parent, {
			Name = n,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, -56),
			Position = UDim2.new(0, 0, 0, 56),
			Visible = false,
		})
		pages[n] = pg
		b.MouseButton1Click:Connect(function()
			select(n)
		end)
	end
	select(names[1])
	return pages, select
end

-- Effects -------------------------------------------------------------------------------------------

function UI.floater(str: string, color: any, pos: Vector2, size: number?)
	local s = size or 40
	local l = UI.text(fx, str, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		Size = UDim2.fromOffset(s * 8, s),
		TextColor3 = UI.color(color),
		Rotation = rng:NextNumber(-10, 10),
		ZIndex = 52,
	})
	UI.punch(l, 0.7)
	UI.tween(l, 1.1, { Position = UDim2.fromOffset(pos.X + rng:NextNumber(-50, 50), pos.Y - 110) })
	local st = l:FindFirstChildOfClass("UIStroke")
	UI.tween(l, 1.1, { TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	if st then
		UI.tween(st, 1.1, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	task.delay(1.15, function()
		l:Destroy()
	end)
end

-- Floater at a world position (falls back to screen centre if off screen).
function UI.floatAt(worldPos: Vector3, str: string, color: any, size: number?)
	local p, on = camera:WorldToViewportPoint(worldPos)
	local vp = camera.ViewportSize
	local pos = on and Vector2.new(p.X, p.Y) or Vector2.new(vp.X / 2, vp.Y * 0.45)
	UI.floater(str, color, pos, size)
end

function UI.confetti(n: number, palette: { Color3 }?)
	local vp = camera.ViewportSize
	for _ = 1, n do
		local f = UI.frame(fx, {
			Size = UDim2.fromOffset(rng:NextInteger(8, 16), rng:NextInteger(10, 20)),
			BackgroundColor3 = palette and palette[rng:NextInteger(1, #palette)] or Color3.fromHSV(rng:NextNumber(), 0.75, 1),
			Rotation = rng:NextNumber(0, 360),
			ZIndex = 49,
		})
		local x = rng:NextNumber(0, vp.X)
		f.Position = UDim2.fromOffset(x, -30)
		local t = rng:NextNumber(1.2, 2.4)
		UI.tween(f, t, {
			Position = UDim2.fromOffset(x + rng:NextNumber(-160, 160), vp.Y + 40),
			Rotation = f.Rotation + rng:NextNumber(-720, 720),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(t, function()
			f:Destroy()
		end)
	end
end

local shake = 0
RunService:BindToRenderStep("KitShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if shake > 0.001 then
		camera.CFrame *= CFrame.new(rng:NextNumber(-1, 1) * shake, rng:NextNumber(-1, 1) * shake, 0)
		shake *= math.exp(-dt * 12)
	end
end)
function UI.shake(s: number)
	shake = math.min(shake + s, 1.5)
end

local flash = UI.frame(gui, {
	Name = "Flash",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 45,
})
function UI.flash(color: any, from: number?)
	flash.BackgroundColor3 = UI.color(color)
	flash.BackgroundTransparency = from or 0.35
	UI.tween(flash, 0.7, { BackgroundTransparency = 1 })
end

local banner = UI.text(gui, "", {
	Name = "Banner",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.fromScale(0.7, 0.1),
	TextTransparency = 1,
	ZIndex = 60,
})
local bannerStroke = banner:FindFirstChildOfClass("UIStroke") :: UIStroke
bannerStroke.Thickness = 4
bannerStroke.Transparency = 1
local bannerToken = 0
function UI.banner(str: string, color: any, hold: number?)
	bannerToken += 1
	local my = bannerToken
	banner.Text = str
	banner.TextColor3 = UI.color(color)
	banner.TextTransparency = 0
	bannerStroke.Transparency = 0
	banner.Rotation = rng:NextNumber(-3, 3)
	UI.punch(banner, 0.8)
	task.delay(hold or 1.8, function()
		if my == bannerToken then
			UI.tween(banner, 0.3, { TextTransparency = 1 })
			UI.tween(bannerStroke, 0.3, { Transparency = 1 })
		end
	end)
end

-- Toasts (top centre, stacked).
local toastHolder = UI.frame(gui, {
	Name = "Toasts",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 96),
	Size = UDim2.fromOffset(520, 300),
	ZIndex = 55,
})
local tl = UI.list(toastHolder, 6)
tl.VerticalAlignment = Enum.VerticalAlignment.Top
function UI.toast(str: string, color: any, seconds: number?)
	local c = UI.color(color)
	local f = UI.frame(toastHolder, { Size = UDim2.fromOffset(480, 44), ZIndex = 55 })
	UI.corner(f, 14)
	UI.stroke(f, 3)
	UI.gradient(f, UI.shade(c, 0.5), UI.shade(c, 0.3))
	UI.text(f, str, { Size = UDim2.new(1, -20, 0.74, 0), Position = UDim2.new(0, 10, 0.13, 0), TextColor3 = UI.lighten(c, 0.5), ZIndex = 56 })
	UI.punch(f, 0.25)
	task.delay(seconds or 3, function()
		UI.tween(f, 0.25, { BackgroundTransparency = 1, Size = UDim2.fromOffset(480, 0) })
		task.wait(0.26)
		f:Destroy()
	end)
	local kids = toastHolder:GetChildren()
	local frames = 0
	for _, k in ipairs(kids) do
		if k:IsA("Frame") then
			frames += 1
		end
	end
	if frames > 4 then
		for _, k in ipairs(kids) do
			if k:IsA("Frame") then
				k:Destroy()
				break
			end
		end
	end
end

-- Coins/gems fly from a screen point into a HUD element.
function UI.fly(from: Vector2, target: GuiObject, n: number, glyph: string, onArrive: (() -> ())?)
	local tp = target.AbsolutePosition + target.AbsoluteSize / 2
	local inset = game:GetService("GuiService"):GetGuiInset()
	tp += inset
	for i = 1, n do
		local l = UI.text(fx, glyph, {
			Font = Enum.Font.GothamBold,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(38, 38),
			Position = UDim2.fromOffset(from.X, from.Y),
			ZIndex = 53,
		})
		local mid = from + Vector2.new(rng:NextNumber(-120, 120), rng:NextNumber(-120, 60))
		UI.tween(l, 0.25, { Position = UDim2.fromOffset(mid.X, mid.Y) }, Enum.EasingStyle.Quad)
		task.delay(0.25 + i * 0.03, function()
			UI.tween(l, 0.4, { Position = UDim2.fromOffset(tp.X, tp.Y), Size = UDim2.fromOffset(22, 22) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.wait(0.4)
			l:Destroy()
			if i == 1 and onArrive then
				onArrive()
			end
			if i % 3 == 1 then
				Sfx.play("coin", 0.25, 1 + i * 0.03)
			end
		end)
	end
end

-- Animated rainbow gradient on a text label (Secret/Mythic names, VIP).
function UI.rainbow(obj: GuiObject, seq: ColorSequence?)
	local g = Instance.new("UIGradient")
	g.Color = seq or ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 230, 120)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 90, 255)),
	})
	g.Parent = obj
	task.spawn(function()
		while g.Parent do
			g.Offset = Vector2.new(((os.clock() * 0.4) % 2) - 1, 0)
			RunService.RenderStepped:Wait()
		end
	end)
	return g
end

function UI.screenPos(worldPos: Vector3): Vector2?
	local p, on = camera:WorldToViewportPoint(worldPos)
	if not on then
		return nil
	end
	return Vector2.new(p.X, p.Y)
end

function UI.center(): Vector2
	return camera.ViewportSize / 2
end

-- Offer popup: { title, text, glyph, price ("R$ 99" or "FREE"), color, seconds?, onBuy }
function UI.offer(o: { [string]: any })
	local p = UI.getPanel("__offer")
	if p then
		p.frame:Destroy()
	end
	local panel = UI.panel("__offer", o.title or "SPECIAL OFFER", o.color or "pink", Vector2.new(460, 330))
	local body = panel.body
	UI.text(body, o.glyph or "🎁", { Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(110, 110), Position = UDim2.new(0.5, -55, 0, 6) })
	UI.text(body, o.text or "", { Font = UI.BODY, Size = UDim2.new(1, 0, 0, 64), Position = UDim2.new(0, 0, 0, 118), TextColor3 = UI.INK })
	local stroke = body:FindFirstChildOfClass("TextLabel")
	if stroke then
		local s2 = stroke:FindFirstChildOfClass("UIStroke")
		if s2 then
			s2.Enabled = false
		end
	end
	local buy = UI.button(body, o.price or "BUY", "green", { Size = UDim2.fromOffset(220, 62), Position = UDim2.new(0.5, -110, 1, -70) })
	buy.MouseButton1Click:Connect(function()
		panel.close()
		if type(o.onBuy) == "function" then
			(o.onBuy :: any)()
		end
	end)
	if o.seconds then
		local timer = UI.text(body, "", { Size = UDim2.fromOffset(200, 28), Position = UDim2.new(0.5, -100, 1, -100), TextColor3 = UI.colors.red })
		task.spawn(function()
			local t = tonumber(o.seconds) or 0
			while t > 0 and panel.isOpen() do
				timer.Text = "Ends in " .. t .. "s"
				task.wait(1)
				t -= 1
			end
			panel.close()
		end)
	end
	panel.open()
end

-- Server notifications (kit/server/Shop.notify) show as toasts.
task.spawn(function()
	local Net = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Net"))
	Net.event("Notify").OnClientEvent:Connect(function(text, color)
		UI.toast(text, color)
		Sfx.play("notify", 0.4)
	end)
end)

return UI

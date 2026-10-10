--!strict
-- Big moments: opening packs (the pack shakes, bursts, and each marble flips in as a spinning 3D card with
-- its rarity banner, NEW! badge and tier-scaled fanfare), the Shine Machine roll (a slot-machine spin of
-- mutation colours that lands on Gold / Rainbow / Cosmic or nothing), and server-wide announcements.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local ClientLib = ReplicatedStorage:WaitForChild("ClientLib")
local UI = require(ClientLib:WaitForChild("UI"))
local Sfx = require(ClientLib:WaitForChild("Sfx"))
local MarbleIcon = require(ClientLib:WaitForChild("MarbleIcon"))

local Reveal = {}

local overlay = UI.frame(UI.root, {
	Name = "Reveal",
	BackgroundColor3 = Color3.fromRGB(16, 18, 34),
	BackgroundTransparency = 0.25,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 40,
	Active = true,
})
local stage = UI.frame(overlay, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 41 })
local token = 0
local busy = false

local function clear()
	for _, c in ipairs(stage:GetChildren()) do
		c:Destroy()
	end
end

local function close()
	token += 1
	busy = false
	overlay.Visible = false
	clear()
end

function Reveal.isOpen(): boolean
	return overlay.Visible
end

local function tierRank(tier: string): number
	return Tiers.index[tier] or 1
end

local function closeButtons(again: (() -> ())?, againText: string?)
	local row = UI.frame(stage, { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40), Size = UDim2.fromOffset(520, 66), ZIndex = 45 })
	UI.list(row, 18, true)
	local ok = UI.button(row, "AWESOME!", "green", { Size = UDim2.fromOffset(230, 64), LayoutOrder = 1, ZIndex = 46 })
	ok.MouseButton1Click:Connect(close)
	if again then
		local b = UI.button(row, againText or "OPEN AGAIN", "orange", { Size = UDim2.fromOffset(230, 64), LayoutOrder = 2, ZIndex = 46 })
		b.MouseButton1Click:Connect(function()
			close()
			again()
		end)
	end
	UI.punch(row, 0.2)
end

local function card(item: { [string]: any }, x: number, delay: number, my: number)
	task.delay(delay, function()
		if token ~= my then
			return
		end
		local id = tostring(item.id)
		local def = Config.MarbleById[id]
		local tier = def and def.tier or "Common"
		local tc = Tiers.get(tier)
		local mut = item.mut
		local f = UI.frame(stage, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.48),
			Size = UDim2.fromOffset(270, 360),
			ZIndex = 42,
		})
		UI.corner(f, 22)
		UI.stroke(f, 4.5)
		local grad = UI.gradient(f, UI.lighten(tc.color, 0.35), UI.shade(tc.dark, 0.9))
		if tc.rainbow then
			grad:Destroy()
			UI.rainbow(f)
		end
		-- glow burst behind the card for big pulls
		if tierRank(tier) >= 4 or mut then
			local halo = UI.frame(stage, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(x, 0.48),
				Size = UDim2.fromOffset(330, 330),
				BackgroundColor3 = mut and (Config.MutationByKey[mut] and Config.MutationByKey[mut].color or tc.color) or tc.color,
				BackgroundTransparency = 0.45,
				ZIndex = 41,
			})
			UI.corner(halo, 165)
			UI.tween(halo, 0.8, { Size = UDim2.fromOffset(470, 470), BackgroundTransparency = 0.8 }, Enum.EasingStyle.Quad)
		end
		MarbleIcon.view(f, id, mut, { Size = UDim2.fromOffset(210, 190), Position = UDim2.new(0.5, -105, 0, 14), ZIndex = 43 }, 1.4)
		UI.text(f, MarbleIcon.name(id, mut), { Size = UDim2.new(1, -20, 0, 36), Position = UDim2.new(0, 10, 0, 206), ZIndex = 44 })
		MarbleIcon.tierText(f, tier, { Size = UDim2.new(1, -40, 0, 34), Position = UDim2.new(0, 20, 0, 244), ZIndex = 44 })
		local m = mut and Config.MutationByKey[mut]
		if m then
			UI.text(f, m.glyph .. " " .. string.upper(m.name) .. "  x" .. tostring(m.mult) .. " COINS", {
				Size = UDim2.new(1, -20, 0, 26),
				Position = UDim2.new(0, 10, 0, 282),
				TextColor3 = m.color,
				ZIndex = 44,
			})
		end
		if item.new then
			local tag = UI.text(f, "NEW!", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -18, 0, 14),
				Size = UDim2.fromOffset(84, 36),
				BackgroundTransparency = 0,
				BackgroundColor3 = UI.colors.red,
				Rotation = 12,
				ZIndex = 45,
			})
			UI.corner(tag, 10)
			UI.stroke(tag, 3)
		elseif (tonumber(item.dupeXp) or 0) > 0 then
			UI.text(f, "DUPE: +" .. tostring(item.dupeXp) .. " XP", {
				Size = UDim2.new(1, -20, 0, 24),
				Position = UDim2.new(0, 10, 1, -34),
				Font = UI.BODY,
				TextColor3 = Color3.fromRGB(220, 200, 255),
				ZIndex = 44,
			})
		end
		f.Size = UDim2.fromOffset(40, 360)
		UI.tween(f, 0.32, { Size = UDim2.fromOffset(270, 360) }, Enum.EasingStyle.Back)
		UI.punch(f, 0.3)
		local rank = tierRank(tier)
		if rank >= 6 or mut == "cosmic" or mut == "rainbow" then
			UI.flash(tc.rainbow and "white" or tc.color, 0.15)
			UI.confetti(120)
			UI.shake(0.8)
			Sfx.play("victory", 0.7)
			UI.banner(string.upper(tc.name) .. "!!", tc.color, 2.2)
		elseif rank >= 5 or mut then
			UI.flash(tc.color, 0.3)
			UI.confetti(70)
			UI.shake(0.5)
			Sfx.play("magic", 0.6)
			UI.banner(string.upper(tc.name) .. "!", tc.color, 1.8)
		elseif rank >= 3 then
			UI.confetti(30)
			Sfx.play("sparkle", 0.55)
		else
			Sfx.play("pop", 0.5)
		end
	end)
end

-- items: { {id, mut, tier, key, new, dupeXp} }
function Reveal.packs(packKey: string, items: { { [string]: any } }, again: (() -> ())?)
	token += 1
	local my = token
	busy = true
	clear()
	overlay.Visible = true
	local pack = Config.PackByKey[packKey]
	local glyph = UI.text(stage, pack and pack.glyph or "🎁", {
		Font = Enum.Font.GothamBold,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromOffset(220, 220),
		ZIndex = 42,
	})
	local name = UI.text(stage, pack and string.upper(pack.name) or "PACK", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.7),
		Size = UDim2.fromOffset(420, 50),
		ZIndex = 42,
	})
	Sfx.play("reveal", 0.6, 1, 2)
	-- best tier decides the build-up colour
	local best = 1
	for _, it in ipairs(items) do
		best = math.max(best, tierRank(tostring(it.tier)))
	end
	task.spawn(function()
		for k = 1, 4 do
			if token ~= my then
				return
			end
			UI.tween(glyph, 0.09, { Rotation = (k % 2 == 0 and -1 or 1) * (6 + k * 4) }, Enum.EasingStyle.Quad)
			UI.punch(glyph, 0.06 * k)
			task.wait(0.18)
		end
		if token ~= my then
			return
		end
		glyph:Destroy()
		name:Destroy()
		UI.flash(best >= 5 and Tiers.list[best].color or "white", 0.2)
		Sfx.play("pop", 0.7, 0.9)
		local n = #items
		for i, it in ipairs(items) do
			local x = n == 1 and 0.5 or (0.5 + (i - (n + 1) / 2) * 0.24)
			card(it, x, (i - 1) * 0.45, my)
		end
		task.wait((n - 1) * 0.45 + 0.6)
		if token == my then
			busy = false
			closeButtons(again, "OPEN AGAIN")
		end
	end)
end

-- Shine Machine roll. res = { ok, mut, key }.
function Reveal.shine(id: string, res: { [string]: any }, again: (() -> ())?)
	token += 1
	local my = token
	busy = true
	clear()
	overlay.Visible = true
	local ring = UI.frame(stage, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(330, 330),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.3,
		ZIndex = 41,
	})
	UI.corner(ring, 165)
	local ringStroke = UI.stroke(ring, 10, Color3.new(1, 1, 1))
	local view = MarbleIcon.view(stage, id, nil, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(300, 300),
		ZIndex = 42,
	}, 5)
	local label = UI.text(stage, "SHINING...", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.75),
		Size = UDim2.fromOffset(520, 60),
		ZIndex = 43,
	})
	Sfx.play("reveal", 0.6, 1.1, 2.5)
	task.spawn(function()
		local cols = { Config.MutationByKey.gold.color, Config.MutationByKey.rainbow.color, Config.MutationByKey.cosmic.color, Color3.fromRGB(200, 205, 220) }
		local delay = 0.06
		local k = 0
		while delay < 0.32 do
			if token ~= my then
				return
			end
			k += 1
			local c = cols[(k - 1) % #cols + 1]
			ring.BackgroundColor3 = c
			ringStroke.Color = c
			Sfx.play("click", 0.25, 1 + (k % 4) * 0.1)
			task.wait(delay)
			delay *= 1.12
		end
		if token ~= my then
			return
		end
		local mut = res.mut
		local m = mut and Config.MutationByKey[mut]
		view:Destroy()
		MarbleIcon.view(stage, id, mut, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(300, 300),
			ZIndex = 42,
		}, 1.4)
		if m then
			ring.BackgroundColor3 = m.color
			ringStroke.Color = m.color
			label.Text = m.glyph .. " " .. string.upper(m.name) .. "! x" .. tostring(m.mult) .. " COINS"
			label.TextColor3 = m.color
			UI.flash(m.color, 0.15)
			UI.confetti(mut == "gold" and 60 or 120)
			UI.shake(mut == "gold" and 0.4 or 0.8)
			Sfx.play(mut == "gold" and "magic" or "victory", 0.7)
			UI.banner(string.upper(m.name) .. "!", m.color, 2)
		else
			ring.BackgroundColor3 = Color3.fromRGB(120, 125, 140)
			ringStroke.Color = Color3.fromRGB(120, 125, 140)
			label.Text = "No shine this time..."
			label.TextColor3 = Color3.fromRGB(200, 205, 220)
			Sfx.play("error", 0.4)
		end
		UI.punch(label, 0.4)
		task.wait(0.6)
		if token == my then
			busy = false
			closeButtons(again, "SHINE AGAIN")
		end
	end)
end

-- Server-wide announcement (big pulls, Grand Prix winners).
function Reveal.announce(text: string, tier: string?, mut: string?)
	local col: Color3
	if tier == "GP" then
		col = UI.colors.purple
	else
		col = Tiers.get(tier or "Common").color
	end
	local m = mut and Config.MutationByKey[mut]
	if m then
		col = m.color
	end
	UI.toast("📣 " .. text, col, 5)
	Sfx.play("notify", 0.45)
end

-- Tapping the dark background never closes a reveal mid-animation; the buttons do.
local _ = busy
return Reveal

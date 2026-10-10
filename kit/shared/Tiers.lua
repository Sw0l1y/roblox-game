-- Rarity tiers shared by every game: colour, gradient, glow and label text.
local Tiers = {}

export type Tier = { key: string, name: string, color: Color3, dark: Color3, glow: boolean, rainbow: boolean }

Tiers.list = {
	{ key = "Common", name = "Common", color = Color3.fromRGB(196, 204, 214), dark = Color3.fromRGB(120, 128, 142), glow = false, rainbow = false },
	{ key = "Uncommon", name = "Uncommon", color = Color3.fromRGB(96, 220, 96), dark = Color3.fromRGB(40, 150, 60), glow = false, rainbow = false },
	{ key = "Rare", name = "Rare", color = Color3.fromRGB(70, 170, 255), dark = Color3.fromRGB(30, 90, 210), glow = false, rainbow = false },
	{ key = "Epic", name = "Epic", color = Color3.fromRGB(190, 100, 255), dark = Color3.fromRGB(110, 40, 200), glow = true, rainbow = false },
	{ key = "Legendary", name = "Legendary", color = Color3.fromRGB(255, 196, 40), dark = Color3.fromRGB(230, 120, 20), glow = true, rainbow = false },
	{ key = "Mythic", name = "Mythic", color = Color3.fromRGB(255, 70, 120), dark = Color3.fromRGB(180, 20, 80), glow = true, rainbow = false },
	{ key = "Secret", name = "SECRET", color = Color3.fromRGB(255, 255, 255), dark = Color3.fromRGB(40, 40, 60), glow = true, rainbow = true },
} :: { Tier }

Tiers.byKey = {} :: { [string]: Tier }
Tiers.index = {} :: { [string]: number }
for i, t in ipairs(Tiers.list) do
	Tiers.byKey[t.key] = t
	Tiers.index[t.key] = i
end

function Tiers.get(key: string): Tier
	return Tiers.byKey[key] or Tiers.list[1]
end

function Tiers.gradient(key: string): ColorSequence
	local t = Tiers.get(key)
	if t.rainbow then
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 60)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(90, 230, 90)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(70, 190, 255)),
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(170, 90, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 200)),
		})
	end
	return ColorSequence.new(t.color, t.dark)
end

-- Weighted pick from { {key=..., weight=...}, ... } using `rng`; luck > 1 shifts weight toward the end of the list.
function Tiers.roll(entries: { any }, rng: Random, luck: number?): any
	local l = luck or 1
	local total = 0
	local weights = {}
	for i, e in ipairs(entries) do
		local w = e.weight * (i > 1 and l ^ ((i - 1) / #entries * 2) or 1)
		weights[i] = w
		total += w
	end
	local r = rng:NextNumber() * total
	for i, e in ipairs(entries) do
		r -= weights[i]
		if r <= 0 then
			return e
		end
	end
	return entries[#entries]
end

-- "1 in 250" style odds text for a weight inside a list.
function Tiers.odds(entries: { any }, entry: any): string
	local total = 0
	for _, e in ipairs(entries) do
		total += e.weight
	end
	local p = entry.weight / total
	if p >= 0.1 then
		return string.format("%d%%", math.floor(p * 100 + 0.5))
	end
	return "1 in " .. tostring(math.floor(1 / p + 0.5))
end

return Tiers

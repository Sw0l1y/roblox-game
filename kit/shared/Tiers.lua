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

-- Effective weights after luck: luck > 1 shifts weight toward the end of the list (rarer tiers).
function Tiers.weights(entries: { any }, luck: number?): ({ number }, number)
	local l = luck or 1
	local total = 0
	local weights = {}
	for i, e in ipairs(entries) do
		local w = e.weight * (i > 1 and l ^ ((i - 1) / #entries * 2) or 1)
		weights[i] = w
		total += w
	end
	return weights, total
end

-- Weighted pick from { {key=..., weight=...}, ... } using `rng`, with the same luck maths as Tiers.weights.
function Tiers.roll(entries: { any }, rng: Random, luck: number?): any
	local weights, total = Tiers.weights(entries, luck)
	local r = rng:NextNumber() * total
	for i, e in ipairs(entries) do
		r -= weights[i]
		if r <= 0 then
			return e
		end
	end
	return entries[#entries]
end

-- Chance of every entry in percent, rounded to 0.001 with largest-remainder rounding so the shown numbers
-- add up to exactly 100 (Roblox's paid random item rule). Pass the player's current luck to show live odds.
function Tiers.percents(entries: { any }, luck: number?): { number }
	local weights, total = Tiers.weights(entries, luck)
	local units, used = 100000, 0
	local floors: { number } = {}
	local order: { { i: number, rem: number } } = {}
	for i, w in ipairs(weights) do
		local exact = w / total * units
		floors[i] = math.floor(exact)
		used += floors[i]
		order[i] = { i = i, rem = exact - floors[i] }
	end
	table.sort(order, function(a: { i: number, rem: number }, b: { i: number, rem: number }): boolean
		return a.rem > b.rem
	end)
	for k = 1, units - used do
		local o = order[(k - 1) % #order + 1]
		floors[o.i] += 1
	end
	local out = {}
	for i, f in ipairs(floors) do
		out[i] = f / 1000
	end
	return out
end

-- "12.5%" / "0.03%" for a percent from Tiers.percents (up to 3 decimals, trailing zeros dropped).
function Tiers.pct(p: number): string
	local s = string.format("%.3f", p):gsub("0+$", ""):gsub("%.$", "")
	return s .. "%"
end

-- Odds text for one entry of a list, as a percent ("1.25%"); luck shows the boosted chance.
function Tiers.odds(entries: { any }, entry: any, luck: number?): string
	local ps = Tiers.percents(entries, luck)
	for i, e in ipairs(entries) do
		if e == entry then
			return Tiers.pct(ps[i])
		end
	end
	return "0%"
end

-- "1.25%  →  2.6% 🍀" when luck changes the chance, else just "1.25%".
function Tiers.oddsLive(entries: { any }, entry: any, luck: number?): string
	local base = Tiers.odds(entries, entry)
	if not luck or luck == 1 then
		return base
	end
	return base .. "  \u{2192}  " .. Tiers.odds(entries, entry, luck) .. " \u{1F340}"
end

return Tiers

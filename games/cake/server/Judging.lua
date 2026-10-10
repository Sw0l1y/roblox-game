-- NPC judge scoring: a readable heuristic so judges reward effort, variety, theme match, structure and
-- rare toppings. Each judge has a focus and some noise; the Celebrity Judge cares most about the theme.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local CakeBuilder = require(Shared:WaitForChild("CakeBuilder"))

type Cake = CakeBuilder.Cake
export type Breakdown = { effort: number, variety: number, theme: number, struct: number, rarity: number }

local Judging = {}

local function set(list: { string }): { [string]: boolean }
	local s = {}
	for _, k in ipairs(list) do
		s[k] = true
	end
	return s
end

-- Quality in 0..1 and its parts.
function Judging.score(cake: Cake, themeKey: string): (number, Breakdown)
	local theme = Config.ThemeByKey[themeKey] or Config.Themes[1]
	local n = #cake.toppings
	local effort = math.min(1, n / 16)
	local distinct, dcount = {}, 0
	local tset, cset, sset = set(theme.toppings), set(theme.colors), set(theme.shapes)
	local themeTops, raritySum = 0, 0
	for _, e in ipairs(cake.toppings) do
		if not distinct[e.id] then
			distinct[e.id] = true
			dcount += 1
		end
		if tset[e.id] then
			themeTops += 1
		end
		local def = Config.ToppingById[e.id]
		if def then
			raritySum += ((Tiers.index[def.tier] or 1) - 1) / 6
		end
	end
	local variety = math.min(1, dcount / 5)
	local colorSlots, colorHits = #cake.tiers, 0
	for _, k in ipairs(cake.tiers) do
		if cset[k] then
			colorHits += 1
		end
	end
	if cake.drip ~= "None" then
		colorSlots += 1
		if cset[cake.drip] then
			colorHits += 1
		end
	end
	local colorScore = if colorSlots > 0 then colorHits / colorSlots else 0
	local themeScore = 0.5 * math.min(1, themeTops / 4) + 0.15 * (if n > 0 then themeTops / n else 0) + 0.35 * colorScore
	if sset[cake.shape] then
		themeScore += 0.1
	end
	local struct = ({ 0.35, 0.65, 0.85, 1 })[math.clamp(#cake.tiers, 1, 4)]
	if cake.drip ~= "None" then
		struct += 0.1
	end
	if cake.piping ~= "Auto" then
		struct += 0.05
	end
	local rarity = if n > 0 then math.min(1, raritySum / n * 2.2) else 0
	local parts = { effort = effort, variety = variety, theme = math.min(1, themeScore), struct = math.min(1, struct), rarity = rarity }
	local q = 0.3 * parts.effort + 0.12 * parts.variety + 0.3 * parts.theme + 0.13 * parts.struct + 0.15 * parts.rarity
	if n == 0 then
		q *= 0.35
	end
	return q, parts
end

-- Whole-star votes from the three judges, plus the Celebrity Judge when present.
function Judging.votes(cake: Cake, themeKey: string, rng: Random, celeb: boolean): ({ number }, number?)
	local q, p = Judging.score(cake, themeKey)
	local out = {}
	for i, j in ipairs(Config.Judges) do
		local focus
		if j.focus == "effort" then
			focus = p.effort * 0.6 + p.variety * 0.4
		elseif j.focus == "theme" then
			focus = p.theme
		else
			focus = p.rarity * 0.5 + p.variety * 0.3 + p.struct * 0.2
		end
		local qi = 0.6 * q + 0.4 * focus
		out[i] = math.clamp(math.floor(1 + 4.2 * qi + rng:NextNumber(-0.6, 0.6) + 0.5), 1, 5)
	end
	local c: number? = nil
	if celeb then
		c = math.clamp(math.floor(1 + 4.2 * (0.45 * q + 0.55 * p.theme) + rng:NextNumber(-0.5, 0.5) + 0.5), 1, 5)
	end
	return out, c
end

return Judging

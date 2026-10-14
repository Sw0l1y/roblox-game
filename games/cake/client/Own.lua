-- Client-side mirror of the server's unlock rules (for drawing locks and prices; the server re-checks).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Own = {}

type D = { [string]: any }

-- What Main hands every client module (callbacks into the other modules and the server).
export type Ctx = {
	data: () -> { [string]: any }?,
	act: (string, any?, any?) -> any,
	buy: (string, string) -> (),
	tut: (number) -> (),
	flyCoins: (Vector2, number) -> (),
	openShop: (string?) -> (),
	openIndex: () -> (),
	openDaily: () -> (),
	openBox: () -> (),
	openTheme: () -> (),
	openFree: () -> (),
	openTrack: () -> (),
	openDeal: () -> (),
	canPrompt: () -> boolean, -- false in the first 2 minutes of a first session (no purchase prompts then)
	sessionAge: () -> number,
	blocked: () -> boolean, -- Roblox's paid-random restriction applies to this player
}

function Own.pass(d: D?, key: string): boolean
	if not d then
		return false
	end
	local p = d.passes
	return type(p) == "table" and p[key] == true
end

function Own.topping(d: D?, id: string): boolean
	local def = Config.ToppingById[id]
	if not def or not d then
		return false
	end
	if def.source == "free" then
		return true
	end
	if def.source == "vip" then
		return Own.pass(d, "VIP")
	end
	return d.toppings ~= nil and d.toppings[id] == true
end

function Own.color(d: D?, key: string): boolean
	local def = Config.ColorByKey[key]
	if not def or not d then
		return false
	end
	if def.pass then
		return Own.pass(d, def.pass)
	end
	if def.event then
		return d.colors ~= nil and d.colors[key] == true
	end
	return def.price == 0 or (d.colors ~= nil and d.colors[key] == true)
end

function Own.shape(d: D?, key: string): boolean
	local def = Config.ShapeByKey[key]
	return def ~= nil and d ~= nil and (def.price == 0 or (d.shapes ~= nil and d.shapes[key] == true))
end

function Own.maxTiers(d: D?): number
	return if d and d.tier4 then 4 else Config.Cake.freeTiers
end

function Own.limit(d: D?): number
	local n = Config.Cake.baseLimit
	if d then
		n += Config.Cake.slotStep * (d.slots or 0)
		if Own.pass(d, "ExtraToppings") then
			n += Config.Cake.passSlots
		end
	end
	return n
end

function Own.indexCount(d: D?): number
	local n = 0
	for _, t in ipairs(Config.Toppings) do
		if Own.topping(d, t.id) then
			n += 1
		end
	end
	return n
end

-- The cheapest thing still locked, for the "next goal" chip: (label, price, shop tab) or nil.
function Own.nextGoal(d: D?): (string?, number?, string?)
	if not d then
		return nil, nil, nil
	end
	local best: string?, bestPrice: number?, bestTab: string? = nil, nil, nil
	local function consider(label: string, price: number, tab: string)
		if price > 0 and (bestPrice == nil or price < (bestPrice :: number)) then
			best, bestPrice, bestTab = label, price, tab
		end
	end
	for _, t in ipairs(Config.Toppings) do
		if t.source == "shop" and not Own.topping(d, t.id) then
			consider(t.glyph .. " " .. t.name, t.price, "Toppings")
		end
	end
	for _, s in ipairs(Config.Shapes) do
		if not Own.shape(d, s.key) then
			consider(s.glyph .. " " .. s.name .. " cakes", s.price, "Upgrades")
		end
	end
	if not d.tier4 then
		consider("🎂 4-tier cakes", Config.Cake.tier4Price, "Upgrades")
	end
	return best, bestPrice, bestTab
end

-- A one-time product this player already bought.
function Own.bought(d: D?, key: string): boolean
	local b = if d then d.bought else nil
	return type(b) == "table" and b[key] ~= nil and b[key] ~= false
end

-- Saved reaction credits for one reaction product.
function Own.credits(d: D?, key: string): number
	local r = if d then d.reacts else nil
	return if type(r) == "table" then tonumber(r[key]) or 0 else 0
end

-- Free (non-Robux) boxes: they open first and may always be rolled.
function Own.freeBoxes(d: D?): number
	if not d then
		return 0
	end
	return math.max(0, (d.boxes or 0) - (d.paidBoxes or 0))
end

-- Caketober: (tier reached, candy into the next tier, claimable tier rewards).
function Own.track(d: D?): (number, number, number)
	if not d then
		return 0, 0, 0
	end
	local candy = d.candy or 0
	local tier = Config.trackTier(candy)
	local claim = 0
	local t = d.track or {}
	local premium = Own.pass(d, "Caketober")
	for k = 1, tier do
		if not (t.free and t.free[tostring(k)]) then
			claim += 1
		end
		if premium and not (t.premium and t.premium[tostring(k)]) then
			claim += 1
		end
	end
	return tier, candy - tier * Config.Track.cost, claim
end

-- The starter pack's remaining window in seconds: the first 10 minutes of the first session (kit Shop `window`
-- refuses it after that), else 0; also 0 once bought.
function Own.starterLeft(d: D?): number
	if not d or d.starter or (d.bought and d.bought.Starter) or (d.sessions or 1) > 1 then
		return 0
	end
	local first = tonumber(d.firstJoin) or 0
	if first <= 0 then
		return 0
	end
	return math.max(0, first + Config.StarterWindow - os.time())
end

-- The 9 R$ intro offer: only for players who never bought anything.
function Own.introOk(d: D?): boolean
	return d ~= nil and (d.spent or 0) == 0 and not (d.bought and d.bought.Intro)
end

return Own

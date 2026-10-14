-- Server-wide timed boosts ("2x coins for everyone, thanks to Nathan!"), bought as dev products or granted by
-- events. One multiplier per kind: a bigger one replaces a smaller one, the same one adds time.
-- State lives in ReplicatedStorage attributes so clients can draw a pill without a remote:
--   Boost_<kind> = multiplier, BoostEnd_<kind> = os.time() it ends, BoostBy_<kind> = who started it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boosts = {}

local MAX_SECONDS = 4 * 3600
local listeners: { (string, number) -> () } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Current multiplier for a kind (1 when none is running).
function Boosts.mult(kind: string): number
	local ends = ReplicatedStorage:GetAttribute("BoostEnd_" .. kind)
	if type(ends) ~= "number" or ends <= now() then
		return 1
	end
	local m = ReplicatedStorage:GetAttribute("Boost_" .. kind)
	return if type(m) == "number" then m else 1
end

-- Seconds left on a kind's boost.
function Boosts.left(kind: string): number
	local ends = ReplicatedStorage:GetAttribute("BoostEnd_" .. kind)
	return type(ends) == "number" and math.max(0, ends - now()) or 0
end

-- Start or extend a boost. Returns the multiplier now running.
function Boosts.add(kind: string, mult: number, seconds: number, by: string?): number
	local cur = Boosts.mult(kind)
	local left = Boosts.left(kind)
	if mult > cur then
		left = seconds -- an upgrade restarts the clock at the new level
		cur = mult
	elseif mult == cur then
		left = math.min(MAX_SECONDS, left + seconds)
	else
		left = math.min(MAX_SECONDS, left + seconds * mult / cur) -- a smaller boost still buys some time
	end
	ReplicatedStorage:SetAttribute("Boost_" .. kind, cur)
	ReplicatedStorage:SetAttribute("BoostEnd_" .. kind, now() + left)
	ReplicatedStorage:SetAttribute("BoostBy_" .. kind, by or "")
	for _, fn in ipairs(listeners) do
		task.spawn(fn, kind, cur)
	end
	return cur
end

-- fn(kind, mult) whenever a boost starts or grows.
function Boosts.onChange(fn: (string, number) -> ())
	table.insert(listeners, fn)
end

return Boosts

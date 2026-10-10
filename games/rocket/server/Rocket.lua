-- The one giant rocket everyone sees grow. Each slot is a hologram until a part is bolted on, then it takes
-- the delivered part's rarity colours (and the server skin for Common parts). Reports progress to the
-- RocketState attributes and the big billboard over the pad, and fires onComplete when every slot is full.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Parts = require(Shared:WaitForChild("Parts"))
local Mission = require(script.Parent:WaitForChild("Mission"))

local Rocket = {}

export type SlotState = {
	i: number,
	kind: string,
	cf: CFrame,
	scale: number,
	pre: boolean,
	filled: boolean,
	tier: string,
	reserved: string?,
	model: Model,
}

Rocket.slots = {} :: { SlotState }
Rocket.layout = nil :: Parts.Layout?
Rocket.model = nil :: Model?
Rocket.base = CFrame.new()
Rocket.size = 1
Rocket.skin = "Classic"
Rocket.skinBy = ""
Rocket.complete = false
Rocket.builtAt = 0

local completeCallbacks: { () -> () } = {}
local paintToken: { [number]: number } = {}

function Rocket.onComplete(fn: () -> ())
	table.insert(completeCallbacks, fn)
end

function Rocket.counts(): (number, number)
	local n = 0
	for _, s in ipairs(Rocket.slots) do
		if s.filled then
			n += 1
		end
	end
	return n, #Rocket.slots
end

function Rocket.worldCF(i: number): CFrame
	local s = Rocket.slots[i]
	if not s then
		return Rocket.base
	end
	return Rocket.base * s.cf
end

local function updateProgress()
	local filled, total = Rocket.counts()
	Mission.set("Filled", filled)
	Mission.set("Total", total)
	local area = Mission.area()
	local pl = Mission.planetInfo()
	area.progressText.Text = string.format("%s ROCKET  %d/%d", pl.icon, filled, total)
	area.progressFill.Size = UDim2.fromScale(total > 0 and filled / total or 0, 1)
end
Rocket.updateProgress = updateProgress

local function solidify(s: SlotState)
	Parts.paint(s.model, Rocket.skin, s.tier)
	for _, d in ipairs(s.model:GetDescendants()) do
		if d:IsA("BasePart") then
			local bp = d :: BasePart
			local role = bp:GetAttribute("Role")
			bp.CanCollide = role ~= "fire" and role ~= "glow"
		end
	end
	s.model:SetAttribute("Filled", true)
	s.model:SetAttribute("Tier", s.tier)
end

-- Build (or rebuild) the rocket for a planet. size: 1 small, 2 medium, 3 large.
function Rocket.build(planetIndex: number, size: number)
	if Rocket.model then
		Rocket.model:Destroy()
	end
	local area = Mission.area()
	local layout = Parts.layout(planetIndex, size)
	Rocket.layout = layout
	Rocket.size = size
	Rocket.base = area.rocketBase
	Rocket.complete = false
	Rocket.builtAt = Mission.now()
	table.clear(paintToken)
	local m = Instance.new("Model")
	m.Name = "Rocket"
	local slots: { SlotState } = {}
	for _, sl in ipairs(layout.slots) do
		local pm = Parts.build(sl.kind, sl.scale)
		pm.Name = "Slot_" .. sl.i
		pm:SetAttribute("Slot", sl.i)
		pm:SetAttribute("Kind", sl.kind)
		pm:PivotTo(Rocket.base * sl.cf)
		pm.Parent = m
		local st: SlotState = {
			i = sl.i,
			kind = sl.kind,
			cf = sl.cf,
			scale = sl.scale,
			pre = sl.pre,
			filled = sl.pre,
			tier = "Common",
			reserved = nil,
			model = pm,
		}
		if sl.pre then
			solidify(st)
		else
			Parts.ghost(pm)
		end
		table.insert(slots, st)
	end
	Rocket.slots = slots
	m.WorldPivot = Rocket.base
	m.Parent = workspace
	Rocket.model = m
	area.progressGui.StudsOffsetWorldSpace = Vector3.new(0, layout.height + 12 * layout.scale, 0)
	Mission.set("Size", size)
	Mission.set("BaseCF", Rocket.base)
	Mission.set("Height", layout.height)
	Mission.set("Scale", layout.scale)
	updateProgress()
end

-- Lowest open slot that nothing is reserved for (optionally only these kinds, in kind preference order).
function Rocket.nextOpen(kinds: { string }?): SlotState?
	if Rocket.complete then
		return nil
	end
	if kinds then
		for _, k in ipairs(kinds) do
			for _, s in ipairs(Rocket.slots) do
				if not s.filled and not s.reserved and s.kind == k then
					return s
				end
			end
		end
		return nil
	end
	for _, s in ipairs(Rocket.slots) do
		if not s.filled and not s.reserved then
			return s
		end
	end
	return nil
end

function Rocket.reserve(i: number, id: string)
	local s = Rocket.slots[i]
	if s then
		s.reserved = id
	end
end

function Rocket.unreserve(i: number, id: string)
	local s = Rocket.slots[i]
	if s and s.reserved == id then
		s.reserved = nil
	end
end

-- Mark slot i bolted on now; it turns solid after `delay` (the client's fly-in animation).
function Rocket.fill(i: number, tier: string, delay: number)
	local s = Rocket.slots[i]
	if not s or s.filled then
		return
	end
	s.filled = true
	s.reserved = nil
	s.tier = tier
	local token = (paintToken[i] or 0) + 1
	paintToken[i] = token
	local model = s.model
	task.delay(delay, function()
		if paintToken[i] == token and model.Parent then
			solidify(s)
		end
	end)
	updateProgress()
	local filled, total = Rocket.counts()
	if filled >= total and not Rocket.complete then
		Rocket.complete = true
		for _, cb in ipairs(completeCallbacks) do
			task.delay(delay + 0.4, cb)
		end
	end
end

-- Every open slot, filled at once (Debug "fill"/"clip").
function Rocket.fillAll(tier: string)
	for _, s in ipairs(Rocket.slots) do
		if not s.filled then
			Rocket.fill(s.i, tier, 0.2)
		end
	end
end

local function repaintAll()
	for _, s in ipairs(Rocket.slots) do
		if s.filled then
			solidify(s)
		end
	end
end

-- Skin = the equipped skin of the top contributor who has one (else Classic).
function Rocket.pickSkin(contrib: { [number]: number }, skinOf: (Player) -> string?)
	local best: Player? = nil
	local bestW = -1
	for _, p in ipairs(Players:GetPlayers()) do
		local sk = skinOf(p)
		if sk and sk ~= "Classic" then
			local w = contrib[p.UserId] or 0
			if w > bestW then
				best, bestW = p, w
			end
		end
	end
	local key = "Classic"
	local by = ""
	if best then
		key = skinOf(best) or "Classic"
		by = best.DisplayName
	end
	if key ~= Rocket.skin or by ~= Rocket.skinBy then
		local changed = key ~= Rocket.skin
		Rocket.skin = key
		Rocket.skinBy = by
		Mission.set("Skin", key)
		Mission.set("SkinBy", by)
		if changed then
			repaintAll()
			if by ~= "" then
				local sk = Config.skin(key)
				Mission.announce(string.format("%s %s painted the rocket %s!", sk.icon, by, string.upper(sk.name)), "purple", "magic")
			end
		end
	end
end

-- Rainbow parts flag for clients that join late (tags replicate; this is a no-op helper for Debug).
function Rocket.rainbowCount(): number
	local n = 0
	if Rocket.model then
		for _, d in ipairs(Rocket.model:GetDescendants()) do
			if CollectionService:HasTag(d, "Rainbow") then
				n += 1
			end
		end
	end
	return n
end

Mission.set("Skin", "Classic")
Mission.set("SkinBy", "")

return Rocket

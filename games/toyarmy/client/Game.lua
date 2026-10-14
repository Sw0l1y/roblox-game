-- Client-side helpers shared by the HUD and panels: asking the server to act, reading the save copy and the
-- busy/recovering counts, bag luck (the same maths the server rolls with), the paid-random rule, offer timing,
-- unit cards (ViewportFrames with the real toy model, in your army skin), and small formatting helpers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Toys = require(Shared:WaitForChild("Toys"))
local Tiers = require(Shared:WaitForChild("Tiers"))
local ClientLib = ReplicatedStorage:WaitForChild("ClientLib")
local UI = require(ClientLib:WaitForChild("UI"))
local Sfx = require(ClientLib:WaitForChild("Sfx"))
local State = require(ClientLib:WaitForChild("State"))

local Game = {}

local player = Players.LocalPlayer
local actFunc = Net.func("Act")
local buyRemote = Net.event("Buy")
Game.started = os.clock()

type Dict = { [string]: any }

-- Ask the server to do something. Shows the server's reason as a toast when it says no.
function Game.act(action: string, a: any?, b: any?): (boolean, any)
	local ok, r1, r2 = pcall(function()
		return actFunc:InvokeServer(action, a, b)
	end)
	if not ok then
		return false, nil
	end
	if r1 ~= true and type(r2) == "string" then
		UI.toast(r2, "red")
		Sfx.play("error", 0.4)
	end
	return r1 == true, r2
end

function Game.buy(kind: string, key: string)
	buyRemote:FireServer(kind, key)
end

-- True while Roblox's paid random item rule applies to this player (kit Policy; true until the lookup returns):
-- bags bought with plastic then give their fixed reward, and random Robux items are hidden.
function Game.randomBlocked(): boolean
	return player:GetAttribute("RandomBlocked") ~= false
end

-- A server-wide boost multiplier (kit Boosts mirrors them to ReplicatedStorage attributes).
function Game.serverBoost(kind: string): number
	local ends = ReplicatedStorage:GetAttribute("BoostEnd_" .. kind)
	local m = ReplicatedStorage:GetAttribute("Boost_" .. kind)
	if type(ends) == "number" and ends > Game.now() and type(m) == "number" then
		return m
	end
	return 1
end

-- Bag luck right now: (tier luck, mutation multiplier), exactly what the server rolls with.
function Game.luck(d: Dict): (number, number)
	return Config.bagLuck(d.upgrades.lucky or 0, (d.boosts.luck or 0) > Game.now(), Game.serverBoost("luck"))
end

-- Nothing bought yet (dev products or passes): the 9 R$ Recruit Deal is for these players only.
function Game.neverBought(d: Dict): boolean
	if (tonumber(d.spent) or 0) > 0 or (d.bought and d.bought.intro) then
		return false
	end
	for _, owned in pairs(d.passes or {}) do
		if owned then
			return false
		end
	end
	return true
end

-- Seconds left in the Starter Pack window (first 10 minutes of the first session), or 0 when it is over.
function Game.starterLeft(d: Dict): number
	if d.starterPack or (d.bought and d.bought.starter) or (tonumber(d.sessions) or 1) > 1 then
		return 0
	end
	local first = tonumber(d.firstJoin) or Game.now()
	return math.max(0, first + Config.StarterWindow - Game.now())
end

function Game.d(): Dict?
	return State.data
end

function Game.side(): string
	return (player:GetAttribute("Side") :: string?) or "Green"
end

function Game.owns(pass: string): boolean
	local d = State.data :: any
	return d ~= nil and d.passes ~= nil and d.passes[pass] == true
end

function Game.now(): number
	return workspace:GetServerTimeNow()
end

-- Seconds since this client started (no purchase popups before minute 2).
function Game.age(): number
	return os.clock() - Game.started
end

function Game.rank(): number
	local d = State.data
	return Config.rankOf(d and d.xp or 0)
end

-- { [stack] = { out = busy count, rec = recovering count } } from the server's "Busy" attribute.
function Game.busy(): { [string]: { out: number, rec: number } }
	local out = {}
	local s = player:GetAttribute("Busy")
	if type(s) == "string" then
		for part in string.gmatch(s, "[^;]+") do
			local stack, v = string.match(part, "^(.*)=(%w+)$")
			if stack and v then
				local e = out[stack] or { out = 0, rec = 0 }
				if v == "r" then
					e.rec += 1
				else
					e.out += tonumber(v) or 0
				end
				out[stack] = e
			end
		end
	end
	return out
end

function Game.ready(d: Dict, stack: string, busy: { [string]: { out: number, rec: number } }?): number
	local b = (busy or Game.busy())[stack]
	local n = d.units[stack] or 0
	if b then
		n -= b.out + b.rec
	end
	return math.max(0, n)
end

function Game.count(d: Dict): number
	local n = #d.merging
	for _, c in pairs(d.units) do
		n += c
	end
	return n
end

function Game.capacity(d: Dict): number
	return Config.capacity(d.upgrades.box or 0, Game.owns("bigbox"))
end

function Game.squadSize(d: Dict): number
	return Config.squadSize(d.upgrades.squad or 0, Game.owns("pro"))
end

function Game.tokens(d: Dict): number
	local n = 0
	for _, c in pairs(d.tokens) do
		n += c
	end
	return n
end

function Game.armyPower(d: Dict): number
	local p = 0
	for stack, c in pairs(d.units) do
		local u, m = Config.split(stack)
		p += Config.power(u, m) * c
	end
	return p * Config.rankBonus(Config.rankOf(d.xp or 0)) * (Game.owns("pro") and 1.25 or 1)
end

function Game.readyTotal(d: Dict): number
	local busy = Game.busy()
	local n = 0
	for stack in pairs(d.units) do
		n += Game.ready(d, stack, busy)
	end
	return n
end

-- Unit types with at least 3 ready (any mutation) that can merge up, lowest tier first: { stack to merge }.
function Game.mergeable(d: Dict): { string }
	local busy = Game.busy()
	local byUnit: { [string]: number } = {}
	local pick: { [string]: string } = {}
	for stack in pairs(d.units) do
		local u, m = Config.split(stack)
		local n = Game.ready(d, stack, busy)
		if n > 0 then
			byUnit[u] = (byUnit[u] or 0) + n
			if m == "" or not pick[u] then
				pick[u] = stack
			end
		end
	end
	local out = {}
	for _, def in ipairs(Config.Units) do
		if (byUnit[def.key] or 0) >= 3 and Config.nextUnit(def.key) then
			table.insert(out, pick[def.key] or Config.stack(def.key, ""))
		end
	end
	return out
end

function Game.mergeSlots(): number
	return Game.owns("doublemold") and 2 or 1
end

-- Colours and labels ------------------------------------------------------------------------------------------------

function Game.tierColor(tier: string): Color3
	return Tiers.get(tier).color
end

function Game.unitTitle(unitKey: string, mut: string): string
	local def = Config.UnitByKey[unitKey]
	local m = Config.MutByKey[mut]
	return (m and (m.glyph .. " ") or "") .. Config.unitName(unitKey, mut) .. (def and (" " .. def.glyph) or "")
end

------------------------------------------------------------------------------------------------------------------------
-- Unit card: a ViewportFrame showing the real toy model, in your equipped army skin. props.plain = no skin (index),
-- props.skin = show that skin (skin previews in the shop).
function Game.viewport(parent: Instance, unitKey: string, mut: string, props: { [string]: any }?): ViewportFrame
	local vf = Instance.new("ViewportFrame")
	vf.Name = "Toy"
	vf.BackgroundTransparency = 1
	vf.Size = UDim2.fromScale(1, 1)
	vf.Ambient = Color3.fromRGB(170, 170, 180)
	vf.LightColor = Color3.fromRGB(255, 250, 240)
	vf.LightDirection = Vector3.new(-0.6, -1, -0.8)
	local plain = props ~= nil and props.plain == true
	local forced: string? = props and props.skin or nil
	if props then
		props.plain = nil
		props.skin = nil
	end
	UI.set(vf, props)
	local skin = forced or (not plain and (player:GetAttribute("Skin") :: string?) or nil)
	local paint = forced or (not plain and (player:GetAttribute("TankPaint") :: string?) or nil)
	local m = Toys.build(unitKey, { team = Game.side(), mut = mut, ring = false, skin = skin, tankPaint = paint })
	m.Parent = vf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vf
	vf.CurrentCamera = cam
	local cf, size = m:GetBoundingBox()
	local center = cf.Position
	local dist = math.max(size.X, size.Y, size.Z) * 2.3 + 1
	cam.CFrame = CFrame.lookAt(center + Vector3.new(-0.55, 0.35, -1).Unit * dist, center)
	vf.Parent = parent
	return vf
end

-- Silhouette version for undiscovered index entries.
function Game.silhouette(vf: ViewportFrame)
	vf.Ambient = Color3.new(0, 0, 0)
	vf.LightColor = Color3.new(0, 0, 0)
	vf.ImageColor3 = Color3.fromRGB(40, 44, 60)
end

return Game

-- Zone bosses (the end state of every zone): popping a zone's own balloons fills its "popped %" meter
-- (Progress.reward). At 100% the player can summon the zone's MEGA boss next to them: a giant angry balloon with a
-- crown, HP sized to everyone in the zone, that anyone can help pop (helpers get half its coins). When it pops
-- its summoner clears the zone: the meter resets, the next zone opens for free the first time (Progress.bossDown).
-- An unbeaten boss floats away after Config.Boss.life seconds; the meter stays full, so it can be summoned again.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Econ = require(Shared:WaitForChild("Econ"))
local Data = require(script.Parent:WaitForChild("Data"))
local Shop = require(script.Parent:WaitForChild("Shop"))
local Progress = require(script.Parent:WaitForChild("Progress"))
local Balloons = require(script.Parent:WaitForChild("Balloons"))

local Boss = {}
Boss.actions = {} :: { [string]: (Player, any) -> () }

type Active = { id: number, zone: number }
local active: { [Player]: Active } = {}

-- HP: about Config.Boss.hpSeconds of everyone in the zone throwing darts.
local function hpFor(zone: number): number
	local dps = 0
	for p, d in pairs(Data.all()) do
		if p.Parent and Progress.zoneOf(p) == zone then
			dps += Econ.power(d) / Econ.cooldown(d)
		end
	end
	return math.max(Config.Boss.minHp * Config.Zones[zone].hpMult, math.floor(dps * Config.Boss.hpSeconds))
end

-- Summon (client asks from the meter): the meter of the zone you stand in must be full.
function Boss.summon(player: Player): boolean
	local d = Data.get(player)
	if not d then
		return false
	end
	local zone = Progress.zoneOf(player)
	if zone < 1 or zone > (d.zones or 1) then
		Shop.notify(player, "Stand in a zone to fight its boss!", "orange")
		return false
	end
	local z = Config.Zones[zone]
	if Econ.meterFrac(d, zone) < 1 then
		Shop.notify(player, Config.Icons.boss .. " Pop more " .. z.name .. " balloons first! (" .. math.floor(Econ.meterFrac(d, zone) * 100) .. "%)", "orange")
		return false
	end
	local cur = active[player]
	if cur and Balloons.get(cur.id) then
		Shop.notify(player, Config.Icons.boss .. " Your boss is already here. Pop it!", "orange")
		Progress.ui(player, "bossSpawned", cur.id, cur.zone)
		return false
	end
	local b = Balloons.spawnNear(player, Config.BossKeys[zone], 18, { hp = hpFor(zone), life = Config.Boss.life, owner = player, quiet = true })
	if not b then
		Shop.notify(player, "No room for the boss here. Step into the open!", "orange")
		return false
	end
	active[player] = { id = b.id, zone = zone }
	Progress.ui(player, "bossSpawned", b.id, zone)
	Shop.notifyAll(Config.Icons.boss .. " " .. player.DisplayName .. " summoned the " .. z.name .. " BOSS! Help pop it!", "red")
	return true
end

Boss.actions.boss = function(player: Player, _arg: any)
	Boss.summon(player)
end

function Boss.init()
	Players.PlayerRemoving:Connect(function(p)
		active[p] = nil
	end)
	-- a boss that floated away (popped ones are handled by Progress.bossDown)
	task.spawn(function()
		while true do
			task.wait(1)
			for p, a in pairs(active) do
				if not Balloons.get(a.id) then
					active[p] = nil
					local d = Data.get(p)
					if p.Parent and d and Econ.meterFrac(d, a.zone) >= 1 then
						Progress.ui(p, "bossEscaped", a.zone)
					end
				end
			end
		end
	end)
end

return Boss

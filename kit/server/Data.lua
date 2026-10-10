-- Player save data: load with retries, reconcile defaults, autosave, save on leave and shutdown,
-- and push a copy to the owning client (kit/client/State) whenever the server marks it dirty.
-- In an unpublished Studio place DataStores fail; the player then plays on fresh in-memory data.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Net = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Net"))

local Data = {}

local store: GlobalDataStore? = nil
local defaults: { [string]: any } = {}
local profiles: { [Player]: { [string]: any } } = {}
local temp: { [Player]: boolean } = {}
local dirty: { [Player]: boolean } = {}
local loadedCallbacks: { (Player, { [string]: any }) -> () } = {}
local leaveCallbacks: { (Player, { [string]: any }) -> () } = {}
local leaderstats: { { name: string, get: ({ [string]: any }) -> any } } = {}
local pushRemote = Net.event("Data")

local function deepCopy(t: any): any
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in pairs(t) do
		c[k] = deepCopy(v)
	end
	return c
end

local function reconcile(target: { [string]: any }, template: { [string]: any })
	for k, v in pairs(template) do
		if target[k] == nil then
			target[k] = deepCopy(v)
		elseif type(v) == "table" and type(target[k]) == "table" and next(v) ~= nil and #v == 0 then
			reconcile(target[k], v)
		end
	end
end

local function retry(fn: () -> ...any, tries: number): (boolean, any)
	local ok, res
	for i = 1, tries do
		ok, res = pcall(fn)
		if ok then
			return true, res
		end
		if i < tries then
			task.wait(1.5 * i)
		end
	end
	return false, res
end

-- opts: { name = "Rocket_v1", defaults = {...}, leaderstats = { {name="Cash", get=function(d) return d.cash end} } }
function Data.init(opts: { name: string, defaults: { [string]: any }, leaderstats: { any }? })
	defaults = opts.defaults
	leaderstats = opts.leaderstats or {}
	local ok, s = pcall(function()
		return DataStoreService:GetDataStore(opts.name)
	end)
	if ok then
		store = s
	else
		warn("[Data] no DataStore (unpublished Studio place?):", s)
	end

	Players.PlayerAdded:Connect(Data._load)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(Data._load, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		local d = profiles[p]
		if d then
			for _, cb in ipairs(leaveCallbacks) do
				pcall(cb, p, d)
			end
			Data.save(p)
		end
		profiles[p] = nil
		temp[p] = nil
		dirty[p] = nil
	end)
	game:BindToClose(function()
		local pending = 0
		for p in pairs(profiles) do
			pending += 1
			task.spawn(function()
				Data.save(p)
				pending -= 1
			end)
		end
		local t = os.clock()
		while pending > 0 and os.clock() - t < 25 do
			task.wait(0.1)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(75)
			for p in pairs(profiles) do
				task.spawn(Data.save, p)
			end
		end
	end)
	RunService.Heartbeat:Connect(function()
		for p in pairs(dirty) do
			dirty[p] = nil
			local d = profiles[p]
			if d and p.Parent then
				pushRemote:FireClient(p, d)
				local ls = p:FindFirstChild("leaderstats")
				if ls then
					for _, l in ipairs(leaderstats) do
						local v = ls:FindFirstChild(l.name)
						if v then
							(v :: StringValue).Value = tostring(l.get(d))
						end
					end
				end
			end
		end
	end)
end

function Data._load(player: Player)
	local key = "u_" .. player.UserId
	local data
	if store then
		local ok, res = retry(function()
			return (store :: GlobalDataStore):GetAsync(key)
		end, 3)
		if ok then
			data = res
		else
			warn("[Data] load failed for", player.Name, res)
			temp[player] = true
		end
	else
		temp[player] = true
	end
	if type(data) ~= "table" then
		data = deepCopy(defaults)
		data.firstJoin = os.time()
	end
	reconcile(data, defaults)
	data.lastJoin = os.time()
	data.sessions = (data.sessions or 0) + 1
	if not player.Parent then
		return
	end
	profiles[player] = data

	if #leaderstats > 0 then
		local ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		for _, l in ipairs(leaderstats) do
			local v = Instance.new("StringValue")
			v.Name = l.name
			v.Value = tostring(l.get(data))
			v.Parent = ls
		end
		ls.Parent = player
	end
	for _, cb in ipairs(loadedCallbacks) do
		task.spawn(cb, player, data)
	end
	Data.dirty(player)
end

function Data.save(player: Player): boolean
	local d = profiles[player]
	if not d or temp[player] or not store then
		return false
	end
	d.lastSave = os.time()
	local ok, err = retry(function()
		(store :: GlobalDataStore):UpdateAsync("u_" .. player.UserId, function()
			return d
		end)
	end, 3)
	if not ok then
		warn("[Data] save failed for", player.Name, err)
	end
	return ok
end

function Data.get(player: Player): { [string]: any }?
	return profiles[player]
end

-- Waits up to `timeout` seconds (default 15) for the player's data.
function Data.wait(player: Player, timeout: number?): { [string]: any }?
	local t = os.clock()
	while not profiles[player] and player.Parent and os.clock() - t < (timeout or 15) do
		task.wait(0.1)
	end
	return profiles[player]
end

function Data.all(): { [Player]: { [string]: any } }
	return profiles
end

function Data.isTemp(player: Player): boolean
	return temp[player] == true
end

-- Mark changed: the client copy and leaderstats refresh on the next frame.
function Data.dirty(player: Player)
	dirty[player] = true
end

function Data.onLoaded(cb: (Player, { [string]: any }) -> ())
	table.insert(loadedCallbacks, cb)
	for p, d in pairs(profiles) do
		task.spawn(cb, p, d)
	end
end

function Data.onLeaving(cb: (Player, { [string]: any }) -> ())
	table.insert(leaveCallbacks, cb)
end

function Data.uuid(): string
	return HttpService:GenerateGUID(false)
end

Data.deepCopy = deepCopy

return Data

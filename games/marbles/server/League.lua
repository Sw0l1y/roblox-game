--!strict
-- Daily league board: every player's league points for today go into an OrderedDataStore (one per UTC
-- day); the top 10 across all servers is read back every minute and shown on the lobby board and in the
-- League panel. In an unpublished Studio place the store fails, so the board falls back to this server.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Data = require(script.Parent:WaitForChild("Data"))

local League = {}

export type Row = { name: string, pts: number, userId: number }

local boardRemote = Net.event("League")
local board: { Row } = {}
local names: { [number]: string } = {}
local written: { [number]: number } = {}
local listeners: { ({ Row }) -> () } = {}
local storeOk = true

local function today(): number
	return math.floor(os.time() / 86400)
end

local function store(): OrderedDataStore?
	if not storeOk then
		return nil
	end
	local ok, s = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.STORE .. "_League_" .. today())
	end)
	if ok then
		return s
	end
	storeOk = false
	return nil
end

local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		names[userId] = p.DisplayName
		return p.DisplayName
	end
	local ok, n = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local name = ok and type(n) == "string" and n or ("Racer" .. tostring(userId % 10000))
	names[userId] = name
	return name
end

local function localBoard(): { Row }
	local rows: { Row } = {}
	for p, d in pairs(Data.all()) do
		local pts = (d.league and d.league.day == today()) and d.league.pts or 0
		table.insert(rows, { name = p.DisplayName, pts = pts, userId = p.UserId })
	end
	table.sort(rows, function(a: Row, b: Row)
		return a.pts > b.pts
	end)
	while #rows > Config.League.boardSize do
		table.remove(rows)
	end
	return rows
end

function League.refresh()
	local s = store()
	-- write our players' points (only when changed)
	if s then
		-- snapshot: SetAsync yields, and players joining/leaving meanwhile would break a live pairs()
		for p, d in pairs(table.clone(Data.all())) do
			local pts = (d.league and d.league.day == today()) and math.floor(d.league.pts) or 0
			if pts > 0 and written[p.UserId] ~= pts then
				local ok = pcall(function()
					(s :: OrderedDataStore):SetAsync("u_" .. p.UserId, pts)
				end)
				if ok then
					written[p.UserId] = pts
				else
					break -- throttled or down: retry next refresh (only store() latches "no DataStores here")
				end
			end
		end
	end
	local rows: { Row } = {}
	local got = false
	if s and storeOk then
		local ok, pages = pcall(function()
			return (s :: OrderedDataStore):GetSortedAsync(false, Config.League.boardSize)
		end)
		if ok and pages then
			local ok2, page = pcall(function()
				return (pages :: DataStorePages):GetCurrentPage()
			end)
			if ok2 and type(page) == "table" then
				for _, item in ipairs(page :: { any }) do
					local uid = tonumber(string.match(tostring(item.key), "%d+")) or 0
					table.insert(rows, { name = nameOf(uid), pts = tonumber(item.value) or 0, userId = uid })
				end
				got = true
			end
		end
	end
	if not got then
		rows = localBoard()
	else
		-- live points for players here are fresher than the store
		for p, d in pairs(Data.all()) do
			local pts = (d.league and d.league.day == today()) and d.league.pts or 0
			local found = false
			for _, r in ipairs(rows) do
				if r.userId == p.UserId then
					r.pts = math.max(r.pts, pts)
					found = true
				end
			end
			if not found and pts > 0 then
				table.insert(rows, { name = p.DisplayName, pts = pts, userId = p.UserId })
			end
		end
		table.sort(rows, function(a: Row, b: Row)
			return a.pts > b.pts
		end)
		while #rows > Config.League.boardSize do
			table.remove(rows)
		end
	end
	board = rows
	boardRemote:FireAllClients(board)
	for _, cb in ipairs(listeners) do
		task.spawn(cb, board)
	end
end

-- Cheap refresh after each race: merge live points into the last board, no store calls.
function League.bump()
	local rows: { Row } = table.clone(board)
	for p, d in pairs(Data.all()) do
		local pts = (d.league and d.league.day == today()) and d.league.pts or 0
		local found = false
		for i, r in ipairs(rows) do
			if r.userId == p.UserId then
				rows[i] = { name = r.name, pts = math.max(r.pts, pts), userId = r.userId }
				found = true
			end
		end
		if not found and pts > 0 then
			table.insert(rows, { name = p.DisplayName, pts = pts, userId = p.UserId })
		end
	end
	table.sort(rows, function(a: Row, b: Row)
		return a.pts > b.pts
	end)
	while #rows > Config.League.boardSize do
		table.remove(rows)
	end
	board = rows
	boardRemote:FireAllClients(board)
	for _, cb in ipairs(listeners) do
		task.spawn(cb, board)
	end
end

function League.board(): { Row }
	return board
end

function League.onBoard(cb: ({ Row }) -> ())
	table.insert(listeners, cb)
end

function League.init()
	task.spawn(function()
		task.wait(5)
		while true do
			League.refresh()
			task.wait(Config.League.refresh)
		end
	end)
end

return League

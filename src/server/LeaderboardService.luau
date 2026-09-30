--!strict
-- Žebříčky na tabuli u spawnu: nejdelší skoky dnes na tomto serveru a nejdelší skoky všech
-- hráčů celkově (OrderedDataStore). Nový rekord serveru dostane hlášku pro všechny.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local FormatNumber = require(Shared.Util.FormatNumber)
local Net = require(Shared.Net)

local Registry = require(script.Parent.Registry)

type Session = any
type Entry = { UserId: number, Name: string, Distance: number }

local LeaderboardService = {}

local REFRESH_INTERVAL = 60
local TOP = 10

local store: OrderedDataStore? = nil
local today: { [number]: Entry } = {}
local todayKey = os.time() // 86400
local allTime: { Entry } = {}
local pending: { [number]: number } = {}
local nameCache: { [number]: string } = {}

local function sortedToday(): { Entry }
	local list = {}
	for _, entry in today do
		table.insert(list, entry)
	end
	table.sort(list, function(a, b)
		return a.Distance > b.Distance
	end)
	return list
end

local function render()
	local board = Registry.Map.Leaderboard
	local todayList = sortedToday()
	for i, row in board.TodayRows do
		local entry = todayList[i]
		row.Text = if entry then `{i}. {entry.Name} – {FormatNumber.Studs(entry.Distance)}` else `{i}. —`
	end
	for i, row in board.AllTimeRows do
		local entry = allTime[i]
		row.Text = if entry then `{i}. {entry.Name} – {FormatNumber.Studs(entry.Distance)}` else `{i}. —`
	end
end

local function payload(): { [string]: any }
	local todayList = sortedToday()
	local todayTop = {}
	for i = 1, math.min(TOP, #todayList) do
		table.insert(todayTop, todayList[i])
	end
	return { Today = todayTop, AllTime = allTime }
end

function LeaderboardService.SendTo(player: Player)
	Net.Event("Leaderboard"):FireClient(player, payload())
end

local function broadcast()
	render()
	Net.Event("Leaderboard"):FireAllClients(payload())
end

function LeaderboardService.OnJump(session: Session, distance: number)
	local player: Player = session.Player
	local key = os.time() // 86400
	if key ~= todayKey then
		todayKey = key
		today = {}
	end
	local previousTop = sortedToday()[1]
	local entry = today[player.UserId]
	if not entry or distance > entry.Distance then
		today[player.UserId] = { UserId = player.UserId, Name = player.DisplayName, Distance = distance }
		if previousTop and distance > previousTop.Distance then
			Registry.Player.Announce(`{player.DisplayName} set a new server record: {FormatNumber.Studs(distance)}!`, "Record")
		end
		broadcast()
	end
	if distance > (pending[player.UserId] or 0) and distance >= session.Data.BestJump then
		pending[player.UserId] = distance
	end
end

local function flush()
	if not store then
		return
	end
	local toSave = pending
	pending = {}
	for userId, distance in toSave do
		local ok, err = pcall(function()
			(store :: OrderedDataStore):UpdateAsync(tostring(userId), function(old: any): any
				local value = math.floor(distance)
				if old and old >= value then
					return nil
				end
				return value
			end)
		end)
		if not ok then
			warn("[Leaderboard] Save failed:", err)
		end
	end
end

local function nameOf(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and type(name) == "string" then name else "Player"
	nameCache[userId] = result
	return result
end

local function refresh()
	if not store then
		return
	end
	local ok, pages = pcall(function()
		return (store :: OrderedDataStore):GetSortedAsync(false, TOP)
	end)
	if not ok or not pages then
		return
	end
	local list = {}
	for _, item in (pages :: DataStorePages):GetCurrentPage() do
		local userId = tonumber(item.key)
		if userId then
			table.insert(list, { UserId = userId, Name = nameOf(userId), Distance = item.value })
		end
	end
	allTime = list
	broadcast()
end

function LeaderboardService.OnLeave(_session: Session)
	-- uložit hned, ať rekord nezmizí
	task.spawn(flush)
end

function LeaderboardService.Start()
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore("SlipperJump_LongestJumps_v1")
	end)
	if ok then
		store = result
	else
		warn("[Leaderboard] OrderedDataStore not available (enable API access in Studio):", result)
	end
	render()
	task.spawn(function()
		refresh()
		while true do
			task.wait(REFRESH_INTERVAL)
			flush()
			refresh()
		end
	end)
	game:BindToClose(flush)
end

return LeaderboardService

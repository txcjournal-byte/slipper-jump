--!strict
-- LEGEND RACE: každých pár minut se všichni na serveru utkají v jednom skoku.
-- 1) Countdown – oznámení a odpočet (hráči se postaví na molo)
-- 2) Open – po GO se počítá PRVNÍ skok každého hráče odstartovaný v okně
-- 3) Waiting – čeká se, až závodníci dopadnou (max. Grace sekund)
-- 4) Results – top 3 dostanou odměnu, vítěz má do příštího závodu korunku „LEGEND“ nad hlavou
-- Vzdálenost ověřil JumpService (stejně jako u Jump Contest).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Events = require(Shared.Config.Events)
local Quests = require(Shared.Config.Quests)
local FormatNumber = require(Shared.Util.FormatNumber)
local Net = require(Shared.Net)

local Registry = require(script.Parent.Registry)

type Session = any
type Entry = { UserId: number, Name: string, Distance: number?, At: number }

local cfg = Events.LegendRace

local LegendRaceService = {}

local state: "Idle" | "Countdown" | "Open" | "Waiting" | "Results" = "Idle"
local goAt = 0 -- čas startu (workspace:GetServerTimeNow – klient má stejné hodiny)
local windowEndsAt = 0
local entries: { [number]: Entry } = {} -- UserId → závodník (Distance = nil, dokud nedopadne)
local order = 0
local results: { { Name: string, Distance: number, UserId: number } } = {}
local legendUserId: number? = nil
local running = false

local function sorted(): { Entry }
	local list = {}
	for _, entry in entries do
		table.insert(list, entry)
	end
	table.sort(list, function(a, b)
		local da, db = a.Distance or -1, b.Distance or -1
		if da ~= db then
			return da > db
		end
		return a.At < b.At
	end)
	return list
end

local function payload(): { [string]: any }
	local top = {}
	local racers = 0
	for _, entry in sorted() do
		racers += 1
		if #top < 8 then
			table.insert(top, { UserId = entry.UserId, Name = entry.Name, Distance = entry.Distance })
		end
	end
	return {
		State = state,
		GoAt = goAt,
		WindowEndsAt = windowEndsAt,
		Top = top,
		Racers = racers,
		Results = if state == "Results" then results else nil,
		Title = cfg.Title,
	}
end

local function broadcast()
	Net.Event("LegendRace"):FireAllClients(payload())
end

function LegendRaceService.SendTo(player: Player)
	Net.Event("LegendRace"):FireClient(player, payload())
end

-- Je hráč aktuální LEGENDA? (AvatarService ukazuje korunku nad hlavou)
function LegendRaceService.IsLegend(player: Player): boolean
	return legendUserId == player.UserId
end

-- Volá JumpService při odrazu: vrátí true, pokud je tohle závodní skok
function LegendRaceService.Enter(session: Session): boolean
	if state ~= "Open" then
		return false
	end
	local player: Player = session.Player
	if entries[player.UserId] then
		return false -- počítá se jen první skok
	end
	order += 1
	entries[player.UserId] = { UserId = player.UserId, Name = player.DisplayName, Distance = nil, At = order }
	broadcast()
	return true
end

-- Volá JumpService po dopadu s ověřenou vzdáleností
function LegendRaceService.OnLand(session: Session, distance: number, isRace: boolean)
	if not isRace then
		return
	end
	local entry = entries[session.Player.UserId]
	if not entry or entry.Distance ~= nil then
		return
	end
	entry.Distance = distance
	broadcast()
end

function LegendRaceService.OnLeave(player: Player)
	if entries[player.UserId] then
		entries[player.UserId] = nil
		if state ~= "Idle" then
			broadcast()
		end
	end
	if legendUserId == player.UserId then
		legendUserId = nil
	end
end

local function setLegend(userId: number?)
	local previous = legendUserId
	legendUserId = userId
	for _, id in { previous, userId } do
		local player = id and Players:GetPlayerByUserId(id)
		local session = player and Registry.Player.Get(player)
		if session then
			Registry.Avatar.UpdateOverhead(session)
		end
	end
end

-- Letí ještě nějaký závodník?
local function pending(): boolean
	for userId, entry in entries do
		if entry.Distance == nil then
			local player = Players:GetPlayerByUserId(userId)
			local session = player and Registry.Player.Get(player)
			local flight = session and session.Flight
			if flight and flight.LegendRace and not flight.Finished then
				return true
			end
		end
	end
	return false
end

local function ordinal(place: number): string
	return if place == 1 then "1st" elseif place == 2 then "2nd" else "3rd"
end

local function award()
	results = {}
	local place = 0
	for _, entry in sorted() do
		local player = Players:GetPlayerByUserId(entry.UserId)
		local session = player and Registry.Player.Get(player)
		if session and entry.Distance then
			place += 1
			local scale = math.max(1, math.floor(session.Data.Level / Quests.MoneyLevelDivisor))
			local prize = cfg.Prizes[place]
			local money = (if prize then prize.Money else cfg.ParticipationMoney) * scale
			Registry.Economy.AddMoney(session, money)
			local text = if prize
				then `You placed {ordinal(place)} in the LEGEND RACE! +{FormatNumber.Money(money)}`
				else `Thanks for racing! +{FormatNumber.Money(money)}`
			if prize and prize.Spins and prize.Spins > 0 then
				Registry.Spinner.AddSpins(session, prize.Spins)
				text ..= ` +{prize.Spins} Spin{if prize.Spins > 1 then "s" else ""}`
			end
			Registry.Player.Notify(session.Player, text, "Success")
			Registry.Player.MarkDirty(session)
			if place <= 3 then
				table.insert(results, { Name = entry.Name, Distance = entry.Distance, UserId = entry.UserId })
			end
		end
	end
	if #results > 0 then
		local winner = results[1]
		setLegend(winner.UserId)
		Net.Event("PlayEffect"):FireAllClients("ContestWin", { UserId = winner.UserId, Name = winner.Name, Legend = true })
		local parts = {}
		for i, r in results do
			table.insert(parts, `{ordinal(i)} {r.Name} ({FormatNumber.Studs(r.Distance)})`)
		end
		Registry.Player.Announce("👑 LEGEND RACE: " .. table.concat(parts, ", "), "Record")
	else
		Registry.Player.Announce("The LEGEND RACE is over – nobody jumped! Next time jump on GO!", "Info")
	end
end

-- Jeden celý závod (blokuje, dokud neskončí)
local function runRace()
	running = true
	entries = {}
	order = 0
	results = {}
	state = "Countdown"
	goAt = workspace:GetServerTimeNow() + cfg.Warning
	windowEndsAt = goAt + cfg.Window
	Registry.Player.Announce(`👑 LEGEND RACE in {cfg.Warning} seconds! Get to the pier and jump on GO!`, "Gift")
	broadcast()
	task.wait(cfg.Warning)
	state = "Open"
	broadcast()
	task.wait(cfg.Window)
	state = "Waiting"
	broadcast()
	local waitUntil = os.clock() + cfg.Grace
	while pending() and os.clock() < waitUntil do
		task.wait(0.5)
	end
	state = "Results"
	-- chyba v odměnách nesmí zaseknout závody
	local ok: boolean, err: any = pcall(function()
		award()
	end)
	if not ok then
		warn("[LegendRace] award failed: " .. tostring(err))
	end
	broadcast()
	task.wait(cfg.ResultsTime)
	state = "Idle"
	entries = {}
	broadcast()
	running = false
end

-- Testovací panel ve Studiu: závod hned (i pro jednoho hráče)
function LegendRaceService.ForceStart(): boolean
	if running then
		return false
	end
	task.spawn(runRace)
	return true
end

function LegendRaceService.Start()
	Players.PlayerAdded:Connect(function(player)
		task.wait(3)
		if player.Parent then
			LegendRaceService.SendTo(player)
		end
	end)
	task.spawn(function()
		local nextAt = os.time() + cfg.FirstDelay
		while true do
			workspace:SetAttribute("NextLegendRaceAt", nextAt)
			task.wait(math.max(1, nextAt - os.time()))
			if not running and #Players:GetPlayers() >= cfg.MinPlayers and not Registry.ServerEvents.IsActive("JumpContest") then
				runRace()
				nextAt = os.time() + cfg.Interval
			else
				-- málo hráčů nebo zrovna běží Jump Contest: zkusit znovu za minutu
				nextAt = os.time() + 60
			end
		end
	end)
end

return LegendRaceService

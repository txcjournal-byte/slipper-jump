--!strict
-- Události na serveru každých pár minut: Golden Rings, Coin Storm, Treasure Tide,
-- Shark Holiday, Mega Jump, Jump Contest, Double XP, Rainbow Rings.
-- Oznámí se předem, běží omezenou dobu.
-- Jump Contest: počítá se nejlepší skok každého hráče (vzdálenost už ověřil JumpService),
-- všichni vidí živou tabulku top 3, na konci dostanou nejlepší odměny.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Events = require(Shared.Config.Events)
local Quests = require(Shared.Config.Quests)
local FormatNumber = require(Shared.Util.FormatNumber)
local Net = require(Shared.Net)

local Registry = require(script.Parent.Registry)

type Session = any
type ContestEntry = { UserId: number, Name: string, Distance: number, At: number }

local ServerEventService = {}

local active: Events.ServerEvent? = nil
local endsAt = 0

-- soutěž: UserId → nejlepší skok během soutěže
local contest: { [number]: ContestEntry } = {}
local contestOrder = 0 -- kdo dřív, ten výš při stejné vzdálenosti
-- soutěž běží od startu až do vyhlášení (i chvíli po konci, než dopadnou poslední skoky)
local contestRunning = false

local function payload(): { [string]: any }?
	if not active then
		return nil
	end
	return { Kind = active.Kind, Name = active.Name, Description = active.Description, Color = active.Color, EndsAt = endsAt }
end

function ServerEventService.IsActive(kind: string): boolean
	return active ~= nil and active.Kind == kind
end

-- Běží právě nějaká událost? (úkol „Jump during an event“)
function ServerEventService.AnyActive(): boolean
	return active ~= nil
end

local function sortedContest(): { ContestEntry }
	local list = {}
	for _, entry in contest do
		table.insert(list, entry)
	end
	table.sort(list, function(a, b)
		if a.Distance ~= b.Distance then
			return a.Distance > b.Distance
		end
		return a.At < b.At
	end)
	return list
end

local function contestPayload(): { [string]: any }?
	if not contestRunning then
		return nil
	end
	local list = sortedContest()
	local top = {}
	for i = 1, math.min(Events.ContestTop, #list) do
		local entry = list[i]
		table.insert(top, { UserId = entry.UserId, Name = entry.Name, Distance = entry.Distance })
	end
	return { Top = top, EndsAt = endsAt }
end

local function broadcastContest()
	Net.Event("ContestBoard"):FireAllClients(contestPayload())
end

function ServerEventService.SendTo(player: Player)
	Net.Event("ServerEvent"):FireClient(player, payload())
	Net.Event("ContestBoard"):FireClient(player, contestPayload())
end

-- Volá JumpService po dopadu s ověřenou vzdáleností.
-- startedInContest = hráč skočil během soutěže (počítá se, i když dopadne až po odpočtu)
function ServerEventService.OnJump(session: Session, distance: number, startedInContest: boolean)
	if not contestRunning or not (startedInContest or ServerEventService.IsActive("JumpContest")) then
		return
	end
	local player: Player = session.Player
	local entry = contest[player.UserId]
	if entry and entry.Distance >= distance then
		return
	end
	contestOrder += 1
	contest[player.UserId] = { UserId = player.UserId, Name = player.DisplayName, Distance = distance, At = contestOrder }
	broadcastContest()
end

-- Hráč odešel: z tabulky soutěže zmizí (odměnu by stejně nemohl dostat)
function ServerEventService.OnLeave(player: Player)
	if contest[player.UserId] then
		contest[player.UserId] = nil
		if contestRunning then
			broadcastContest()
		end
	end
end

local function ordinal(place: number): string
	return if place == 1 then "1st" elseif place == 2 then "2nd" else "3rd"
end

-- Letí ještě někdo, kdo skočil během soutěže?
local function contestFlightsPending(): boolean
	for _, session in Registry.Player.Sessions do
		local flight = session.Flight
		if flight and flight.Contest and not flight.Finished then
			return true
		end
	end
	return false
end

local function finishContest()
	local list = sortedContest()
	contest = {}
	local winners = {}
	for _, entry in list do
		if #winners >= #Events.ContestPrizes then
			break
		end
		-- odměnu dostane jen hráč, který je pořád na serveru
		local player = Players:GetPlayerByUserId(entry.UserId)
		local session = player and Registry.Player.Get(player)
		if session then
			local place = #winners + 1
			local prize = Events.ContestPrizes[place]
			local scale = math.max(1, math.floor(session.Data.Level / Quests.MoneyLevelDivisor))
			local money = prize.Money * scale
			Registry.Economy.AddMoney(session, money)
			local text = `You placed {ordinal(place)} in the Jump Contest! +{FormatNumber.Money(money)}`
			if prize.Spins and prize.Spins > 0 then
				Registry.Spinner.AddSpins(session, prize.Spins)
				text ..= ` +{prize.Spins} Spin{if prize.Spins > 1 then "s" else ""}`
			end
			Registry.Player.Notify(session.Player, text, "Success")
			Registry.Player.MarkDirty(session)
			table.insert(winners, `{ordinal(place)} {entry.Name} ({FormatNumber.Studs(entry.Distance)})`)
			if place == 1 then
				Net.Event("PlayEffect"):FireAllClients("ContestWin", { UserId = entry.UserId, Name = entry.Name })
			end
		end
	end
	if #winners == 0 then
		Registry.Player.Announce("The Jump Contest is over! Nobody jumped this time.", "Info")
	else
		Registry.Player.Announce("🏆 JUMP CONTEST: " .. table.concat(winners, ", "), "Record")
	end
end

local last: Events.ServerEvent? = nil
local running = false

-- Spustí událost a počká, až skončí (soutěž i s vyhlášením)
local function runEvent(nextEvent: Events.ServerEvent)
	running = true
	local duration = nextEvent.Duration or Events.ServerEventDuration
	contest = {}
	contestRunning = nextEvent.Kind == "JumpContest"
	active = nextEvent
	last = nextEvent
	endsAt = os.time() + duration
	Registry.Player.Announce(`{nextEvent.Name}! {nextEvent.Description}`, "Gift")
	Net.Event("ServerEvent"):FireAllClients(payload())
	broadcastContest()
	task.wait(duration)
	local wasContest = nextEvent.Kind == "JumpContest"
	active = nil
	Net.Event("ServerEvent"):FireAllClients(nil)
	if wasContest then
		-- počkat, až dopadnou skoky odstartované během soutěže (max. pár sekund)
		local waitUntil = os.clock() + Events.ContestGrace
		while contestFlightsPending() and os.clock() < waitUntil do
			task.wait(0.5)
		end
		contestRunning = false
		Net.Event("ContestBoard"):FireAllClients(nil)
		-- ve vlastním vlákně: chyba v odměnách nezastaví smyčku událostí
		task.spawn(finishContest)
	end
	running = false
end

-- Testovací panel ve Studiu: spustit konkrétní událost hned
function ServerEventService.ForceStart(kind: string): boolean
	if running then
		return false
	end
	for _, event in Events.ServerEvents do
		if event.Kind == kind then
			task.spawn(runEvent, event)
			return true
		end
	end
	return false
end

function ServerEventService.Start()
	Players.PlayerAdded:Connect(function(player)
		task.wait(3)
		if player.Parent then
			ServerEventService.SendTo(player)
		end
	end)
	task.spawn(function()
		while true do
			-- kdy začne další událost (klient ukazuje odpočet „Next event in 2:31“)
			workspace:SetAttribute("NextEventAt", os.time() + Events.ServerEventInterval)
			task.wait(Events.ServerEventInterval - Events.ServerEventWarning)
			if not running then
				local choices = {}
				for _, event in Events.ServerEvents do
					if event ~= last then
						table.insert(choices, event)
					end
				end
				local nextEvent = choices[math.random(1, #choices)]
				Registry.Player.Announce(`{nextEvent.Name} starts in {Events.ServerEventWarning} seconds! Get to the pier!`, "Info")
				task.wait(Events.ServerEventWarning)
				if not running then
					runEvent(nextEvent)
				end
			else
				task.wait(Events.ServerEventWarning)
			end
		end
	end)
end

return ServerEventService

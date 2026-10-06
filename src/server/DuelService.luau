--!strict
-- CHALLENGE souboje (Config/Duels): pozvánka hráče, trénink o samotě, 3 kola, výsledky a odměny.
-- Pohyb (rozběh, sjezd) hraje klient; server určuje časy (start, čára), ověří čas odrazu a spočítá metry
-- stejným vzorcem jako klient (Formulas.DuelMeters). Odměny dává hra, soupeři se nic nebere.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Duels = require(Shared.Config.Duels)
local Quests = require(Shared.Config.Quests)
local Formulas = require(Shared.Formulas)
local Net = require(Shared.Net)

local Registry = require(script.Parent.Registry)
local DuelArena = require(script.Parent.DuelArena)

type Session = any
type Attempt = { Meters: number, Foul: boolean, Perfect: boolean }
type Match = {
	Id: number,
	Game: string,
	Practice: boolean,
	Players: { Player },
	Lane: { [number]: number },
	Attempts: { [number]: { Attempt } },
	Pending: { [number]: boolean },
	Gear: { [number]: number },
	Round: number,
	BoardAt: number,
	Done: boolean,
}
type Invite = { Id: number, From: Player, To: Player, Game: string, Expires: number }

local DuelService = {}

local matchCounter = 0
local inviteCounter = 0
local invites: { [number]: Invite } = {}
local champions: { [number]: number } = {} -- UserId → výher v řadě (titul CHAMPION nad hlavou)
local stateEvent: RemoteEvent

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- Může hráč teď do souboje? (ne během skoku, plavání, úkolu, závodu, jiného souboje)
local function isFree(session: Session?): boolean
	-- dohraný souboj (čeká se jen na odchod z arény) nevadí: TRY AGAIN / REVENGE hned
	if session and session.Duel and session.Duel.Done then
		session.Duel = nil
		DuelArena.RemoveSkiGear(session.Player.Character)
	end
	return session ~= nil and session.Loaded and not session.Flight and not session.Swim and not session.Trial and not session.Duel and not session.Returning
end

function DuelService.ChampionStreak(player: Player): number
	return champions[player.UserId] or 0
end

local function scale(session: Session): number
	return math.max(1, math.floor((session.Data.Level or 1) / Quests.MoneyLevelDivisor))
end

local function best(list: { Attempt }): number
	local b = 0
	for _, a in list do
		if not a.Foul and a.Meters > b then
			b = a.Meters
		end
	end
	return b
end

-- stav pro klienty: jména, dráhy, pokusy
local function payload(match: Match, state: string, extra: { [string]: any }?): { [string]: any }
	local racers = {}
	for _, p in match.Players do
		local attempts = {}
		local list: { Attempt } = match.Attempts[p.UserId] or {}
		for _, a in list do
			table.insert(attempts, { Meters = a.Meters, Foul = a.Foul, Perfect = a.Perfect })
		end
		table.insert(racers, { UserId = p.UserId, Name = p.DisplayName, Lane = match.Lane[p.UserId], Attempts = attempts, Best = best(match.Attempts[p.UserId] or {}) })
	end
	local t: { [string]: any } = {
		Id = match.Id,
		State = state,
		Game = match.Game,
		Practice = match.Practice,
		Round = match.Round,
		Rounds = Duels.Attempts,
		Racers = racers,
		BoardAt = match.BoardAt,
	}
	if extra then
		for k, v in extra do
			t[k] = v
		end
	end
	return t
end

local function send(match: Match, state: string, extra: { [string]: any }?)
	local data = payload(match, state, extra)
	for _, p in match.Players do
		if p.Parent then
			stateEvent:FireClient(p, data)
		end
	end
end

local function place(player: Player, cf: CFrame)
	local root = Registry.Player.GetRoot(player)
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = cf
	end
end

local function finish(match: Match, forfeitBy: Player?)
	if match.Done then
		return
	end
	match.Done = true
	local results = {}
	local winner: Player? = nil
	if not match.Practice then
		local a, b = match.Players[1], match.Players[2]
		if forfeitBy then
			winner = if forfeitBy == a then b else a
		else
			local ba, bb = best(match.Attempts[a.UserId]), best(match.Attempts[b.UserId])
			if ba > bb then
				winner = a
			elseif bb > ba then
				winner = b
			end
		end
	end
	for _, p in match.Players do
		local session = Registry.Player.Get(p)
		if session then
			local myBest = best(match.Attempts[p.UserId] or {})
			local data = session.Data
			local recordKey = if match.Game == "LongJump" then "LongJumpBest" else "SkiJumpBest"
			local record = myBest > (data[recordKey] or 0)
			if record then
				data[recordKey] = myBest
			end
			local money = 0
			local spins = 0
			if not match.Practice then
				if winner == p then
					money = Duels.WinMoney * scale(session)
					spins = Duels.WinSpins
					data.DuelWins = (data.DuelWins or 0) + 1
					champions[p.UserId] = (champions[p.UserId] or 0) + 1
				else
					money = if winner then Duels.LoseMoney * scale(session) else math.floor(Duels.WinMoney * scale(session) / 2)
					champions[p.UserId] = nil
				end
				if money > 0 then
					Registry.Economy.AddMoney(session, money)
				end
				if spins > 0 then
					Registry.Spinner.AddSpins(session, spins)
				end
			end
			results[tostring(p.UserId)] = { Money = money, Spins = spins, Record = record, Best = myBest }
			Registry.Player.MarkDirty(session)
			Registry.Avatar.UpdateOverhead(session)
		end
	end
	send(match, "End", {
		Winner = if winner then winner.UserId else 0,
		WinnerName = if winner then winner.DisplayName else "",
		Forfeit = forfeitBy ~= nil,
		Results = results,
	})
	if winner and not match.Practice then
		local cfg = Duels.Games[match.Game]
		local loser = if winner == match.Players[1] then match.Players[2] else match.Players[1]
		Registry.Player.Announce(`{cfg.Icon} {winner.DisplayName} beat {loser.DisplayName} in {cfg.Name}!`, "Record")
	end
	task.delay(4.5, function()
		for _, p in match.Players do
			local session = Registry.Player.Get(p)
			if session and session.Duel == match then
				session.Duel = nil
				DuelArena.RemoveSkiGear(p.Character)
				place(p, DuelArena.ExitCFrame(match.Game))
			end
		end
	end)
end

-- Jedno kolo: odpočet, start, čekání na odrazy, výsledek
local function runRound(match: Match)
	match.Round += 1
	for _, p in match.Players do
		match.Pending[p.UserId] = true
		place(p, DuelArena.StartCFrame(match.Game, match.Lane[p.UserId]))
		if match.Game == "SandSki" then
			local kind = p:GetAttribute("SkiGear")
			DuelArena.EquipSkiGear(p.Character, if kind == "Board" then "Board" else "Skis")
		end
	end
	local cfg = Duels.Games[match.Game]
	local goAt = now() + Duels.CountdownTime
	match.BoardAt = goAt + cfg.RunTime
	send(match, "Run", { GoAt = goAt })
	-- čeká na odrazy (kdo neskočí včas, má faul)
	local deadline = match.BoardAt + Duels.FoulLate + 0.6
	while now() < deadline and not match.Done do
		local waiting = false
		for _, p in match.Players do
			if match.Pending[p.UserId] then
				waiting = true
			end
		end
		if not waiting then
			break
		end
		task.wait(0.1)
	end
	if match.Done then
		return
	end
	for _, p in match.Players do
		if match.Pending[p.UserId] then
			match.Pending[p.UserId] = false
			table.insert(match.Attempts[p.UserId], { Meters = 0, Foul = true, Perfect = false })
		end
	end
	-- počkat na dopad (animace letu u klienta), pak výsledek kola
	task.wait(cfg.FlightTime + 0.4)
	if not match.Done then
		send(match, "Round", {})
		task.wait(2.2)
	end
end

local function startMatch(gameKey: string, players: { Player }, practice: boolean)
	matchCounter += 1
	local match: Match = {
		Id = matchCounter,
		Game = gameKey,
		Practice = practice,
		Players = players,
		Lane = {},
		Attempts = {},
		Pending = {},
		Gear = {},
		Round = 0,
		BoardAt = 0,
		Done = false,
	}
	for i, p in players do
		local session = Registry.Player.Get(p)
		match.Lane[p.UserId] = i
		match.Attempts[p.UserId] = {}
		if session then
			session.Duel = match
			local data = session.Data
			match.Gear[p.UserId] = Formulas.DuelGear(data.EquippedSlippers, data.EquippedHat, session.Passes.SuperJumper == true)
		end
	end
	send(match, "Intro", {})
	task.spawn(function()
		task.wait(1.5)
		for _ = 1, Duels.Attempts do
			if match.Done then
				return
			end
			runRound(match)
		end
		finish(match, nil)
	end)
end

-- Klient nahlásil odraz: delta = čas odrazu vůči čáře podle klienta, gates = podíl branek (lyže)
local function onAction(player: Player, action: unknown, arg1: unknown, arg2: unknown)
	local session = Registry.Player.Get(player)
	if not session then
		return
	end
	if action == "Takeoff" then
		local match: Match? = session.Duel
		if not match or match.Done or not match.Pending[player.UserId] then
			return
		end
		match.Pending[player.UserId] = false
		local serverDelta = now() - match.BoardAt
		local delta = serverDelta
		if type(arg1) == "number" and arg1 == arg1 and math.abs(arg1 - serverDelta) <= Duels.ClientTolerance then
			delta = arg1
		end
		if serverDelta < -(Duels.Games[match.Game].RunTime + 0.5) then
			return -- ještě nestartoval
		end
		local gates = if type(arg2) == "number" and arg2 == arg2 then math.clamp(arg2, 0, 1) else 0
		local meters, foul, perfect = Formulas.DuelMeters(match.Game, match.Gear[player.UserId] or 100, delta, gates)
		table.insert(match.Attempts[player.UserId], { Meters = meters, Foul = foul, Perfect = perfect })
		send(match, "Jumped", { UserId = player.UserId, Meters = meters, Foul = foul, Perfect = perfect })
	elseif action == "Practice" and type(arg1) == "string" and Duels.Games[arg1] then
		if not isFree(session) then
			Registry.Player.Notify(player, "Finish what you're doing first!", "Warning")
			return
		end
		startMatch(arg1, { player }, true)
	elseif action == "SkiGear" and (arg1 == "Skis" or arg1 == "Board") then
		player:SetAttribute("SkiGear", arg1)
		local match: Match? = session.Duel
		if match and not match.Done and match.Game == "SandSki" and match.Pending[player.UserId] then
			DuelArena.EquipSkiGear(player.Character, arg1 :: string)
		end
	elseif action == "Leave" then
		local match: Match? = session.Duel
		if match and not match.Done then
			finish(match, if match.Practice then nil else player)
		end
	end
end

-- Výzva: hráč vybral hru a soupeře
local function onRequest(player: Player, targetId: unknown, gameKey: unknown)
	if type(targetId) ~= "number" or type(gameKey) ~= "string" or not Duels.Games[gameKey] then
		return
	end
	local target = Players:GetPlayerByUserId(targetId)
	if not target or target == player then
		return
	end
	local session = Registry.Player.Get(player)
	local targetSession = Registry.Player.Get(target)
	if not isFree(session) then
		Registry.Player.Notify(player, "Finish what you're doing first!", "Warning")
		return
	end
	if not isFree(targetSession) then
		Registry.Player.Notify(player, target.DisplayName .. " is busy right now. Try again in a moment!", "Info")
		return
	end
	for _, invite in invites do
		if invite.From == player and invite.To == target and invite.Expires > os.clock() then
			return -- už pozvaný
		end
	end
	inviteCounter += 1
	invites[inviteCounter] = { Id = inviteCounter, From = player, To = target, Game = gameKey, Expires = os.clock() + Duels.InviteTimeout }
	Net.Event("DuelInvite"):FireClient(target, { Id = inviteCounter, From = player.DisplayName, Game = gameKey, Timeout = Duels.InviteTimeout })
	Registry.Player.Notify(player, `Challenge sent to {target.DisplayName}!`, "Info")
end

local function onRespond(player: Player, inviteId: unknown, accept: unknown)
	if type(inviteId) ~= "number" then
		return
	end
	local invite = invites[inviteId]
	if not invite or invite.To ~= player then
		return
	end
	invites[inviteId] = nil
	if invite.Expires < os.clock() or not invite.From.Parent then
		return
	end
	if accept ~= true then
		Registry.Player.Notify(invite.From, `{player.DisplayName} declined your challenge.`, "Info")
		return
	end
	local a = Registry.Player.Get(invite.From)
	local b = Registry.Player.Get(player)
	if not isFree(a) or not isFree(b) then
		Registry.Player.Notify(player, "The challenge can't start right now.", "Info")
		return
	end
	startMatch(invite.Game, { invite.From, player }, false)
end

function DuelService.OnLeave(player: Player)
	champions[player.UserId] = nil
	for id, invite in invites do
		if invite.From == player or invite.To == player then
			invites[id] = nil
		end
	end
	local session = Registry.Player.Get(player)
	local match: Match? = session and session.Duel
	if match and not match.Done then
		finish(match, if match.Practice then nil else player)
	end
end

-- Prompt CHALLENGE na postavě hráče (volá AvatarService)
function DuelService.OnPrompt(challenger: Player, target: Player)
	if challenger == target then
		return
	end
	stateEvent:FireClient(challenger, { State = "Pick", TargetId = target.UserId, TargetName = target.DisplayName })
end

function DuelService.Init()
	stateEvent = Net.Event("DuelState")
end

function DuelService.Start()
	local prompts = DuelArena.Build(Registry.Map.Folder)
	for gameKey, prompt in prompts do
		prompt.Triggered:Connect(function(player)
			onAction(player, "Practice", gameKey)
		end)
	end
	Net.Event("DuelAction").OnServerEvent:Connect(onAction)
	Net.Event("DuelRequest").OnServerEvent:Connect(onRequest)
	Net.Event("DuelRespond").OnServerEvent:Connect(onRespond)
end

return DuelService

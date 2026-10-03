--!strict
-- Plavání zpět: po dopadu hráč plave k záchrannému voru a honí ho žralok.
-- O výsledku rozhoduje server podle pozic, které vidí (klient jen hýbe postavou a kreslí žraloka).
-- Doplave → bonus a předmět z vody. Chytí ho žralok (nebo nedoplave) → přijde o bonus i o předmět.
-- Na voru si hráč vybere: zpět na pláž, nebo skočit do vody a plavat k dalšímu voru (až 3 vory).
-- Další úsek = těžší slalom, rychlejší pronásledovatel, větší bonus a poklad; chycení = jen ztráta toho úseku.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Swim = require(Shared.Config.Swim)
local World = require(Shared.Config.World)
local Formulas = require(Shared.Formulas)
local Net = require(Shared.Net)

local Registry = require(script.Parent.Registry)

type Session = any

export type SwimState = {
	Flight: any,
	StartClock: number,
	StartX: number,
	Distance: number,
	Speed: number,
	SharkSpeed: number,
	CatchDistance: number, -- Swim.CatchDistance + dosah tvora (chapadla, velká tlama)
	NoShark: boolean,
	Done: boolean,
	Character: Model?, -- postava, se kterou hráč začal plavat (reset = prohra, ne doplavání)
	SharkDelay: number, -- kdy pronásledovatel vyrazí (delší plavba = později)
	Stage: number, -- kolikátý vor (1–3)
	LandDistance: number, -- kam hráč doskočil (tier pronásledovatele, poklady)
	UsedRepellent: boolean,
	Treasure: string?, -- poklad na voru 2 a 3 (dostane ho, až k voru doplave)
	Waiting: boolean, -- stojí na voru a vybírá si (dál / zpět)
	Dir: number, -- 1 = plave ke břehu (−X), −1 = na moře (+X, vory 2 a 3)
}

local SwimService = {}

local rng = Random.new()

export type SlalomGate = { X: number, Z: number, Gap: number, Amp: number, Speed: number, Phase: number }
export type SlalomObstacle = { Kind: string, X: number, Z: number, Amp: number, Speed: number, Phase: number }
export type SlalomLayout = { Name: string, Color: Color3, Gates: { SlalomGate }, Obstacles: { SlalomObstacle } }

-- Vylosuje slalom pro level hráče. X = vzdálenost od místa startu směrem k voru,
-- Z = posun do strany od dráhy (klient přičte StartZ). Mezery branek se střídají vlevo a vpravo,
-- překážky leží zhruba na spojnici dvou sousedních mezer, takže je hráč musí objet.
local function generateSlalom(level: number, distance: number): SlalomLayout?
	local tier = Formulas.SlalomTier(level)
	if not tier then
		return nil
	end
	local cfg = Swim.Slalom
	local gates: { SlalomGate } = {}
	local sign = if rng:NextNumber() < 0.5 then -1 else 1
	local moving = {}
	-- které branky se hýbou (náhodně vybrané)
	local order = {}
	for i = 1, tier.Gates do
		order[i] = i
	end
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	for k = 1, tier.Moving do
		if order[k] then
			moving[order[k]] = true
		end
	end
	local spacing = distance / (tier.Gates + 1)
	for i = 1, tier.Gates do
		local amp = if moving[i] then tier.MoveAmp else 0
		local maxCenter = cfg.LaneHalfWidth - 2 - tier.Gap / 2 - amp
		local z = sign * math.min(rng:NextNumber(tier.Offset * 0.45, tier.Offset), maxCenter)
		sign = -sign
		table.insert(gates, {
			X = spacing * i,
			Z = z,
			Gap = tier.Gap,
			Amp = amp,
			Speed = if moving[i] then tier.MoveSpeed * rng:NextNumber(0.85, 1.15) else 0,
			Phase = rng:NextNumber(0, math.pi * 2),
		})
	end
	-- překážky do úseků mezi brankami (úsek k = před k-tou brankou; poslední je mezi poslední brankou a vorem)
	local kinds: { string } = {}
	for _, kind in { "Rock", "Jellyfish", "Log", "Puffer" } do
		for _ = 1, tier.Obstacles[kind] or 0 do
			table.insert(kinds, kind)
		end
	end
	local obstacles: { SlalomObstacle } = {}
	local segments = tier.Gates + 1
	for n, kind in kinds do
		-- nejdřív úseky mezi brankami (2..Gates), pak úsek za poslední brankou
		local segment = ((n - 1) % math.max(1, segments - 1)) + 2
		local fromX = spacing * (segment - 1)
		local fromZ = if segment - 1 >= 1 then gates[segment - 1].Z else 0
		local toZ = if gates[segment] then gates[segment].Z else 0
		local pathZ = (fromZ + toZ) / 2
		local amp, speed = 0, 0
		if kind == "Jellyfish" then
			amp, speed = 6, rng:NextNumber(1.1, 1.6)
		elseif kind == "Log" then
			amp, speed = 10, rng:NextNumber(0.8, 1.1)
		end
		-- víc překážek v jednom úseku → rozložit podél úseku
		local slot = math.floor((n - 1) / math.max(1, segments - 1))
		local x = fromX + spacing * (0.5 + (if slot % 2 == 1 then 0.18 else 0)) + rng:NextNumber(-1.5, 1.5)
		table.insert(obstacles, {
			Kind = kind,
			X = math.clamp(x, 6, distance - 6),
			Z = math.clamp(pathZ + rng:NextNumber(-3, 3), -cfg.LaneHalfWidth + 8, cfg.LaneHalfWidth - 8),
			Amp = amp,
			Speed = speed,
			Phase = rng:NextNumber(0, math.pi * 2),
		})
	end
	return { Name = tier.Name, Color = tier.Color, Gates = gates, Obstacles = obstacles }
end

local startEvent: RemoteEvent
local resultEvent: RemoteEvent

local function returnLater(session: Session, flight: any, delay: number?)
	task.delay(delay or Swim.ReturnDelay, function()
		if session.Flight == flight then
			session.Flight = nil
			session.Swim = nil
			Registry.Player.ReturnToBeach(session)
			Registry.Player.MarkDirty(session)
		end
	end)
end

-- Předmět z vody, který čeká, až hráč doplave (JumpService ho uloží do flight.PendingItem).
-- Vrací id předmětu a pokud ho hráč dostal, i umístění.
local function settleItem(session: Session, flight: any, keep: boolean): (string?, string?)
	local itemId = flight and flight.PendingItem
	if not itemId then
		return nil, nil
	end
	flight.PendingItem = nil
	if keep then
		local _, placement = Registry.Items.Give(session, itemId)
		return itemId, placement
	end
	return itemId, nil
end

local startStage: (Session, SwimState?, any, number, number, boolean, boolean) -> ()

local function finish(session: Session, state: SwimState, success: boolean, reason: string)
	if state.Done then
		return
	end
	state.Done = true
	local stages = Swim.Stages
	-- vor 1: předmět z vody, vor 2 a 3: poklad
	local itemId, placement
	if state.Stage == 1 then
		itemId, placement = settleItem(session, state.Flight, success)
	elseif state.Treasure then
		itemId = state.Treasure
		state.Treasure = nil
		if success then
			local _, where = Registry.Items.Give(session, itemId :: string)
			placement = where
		end
	end
	local bonus = 0
	if success then
		local base = math.max(Swim.BonusMin, math.floor(Registry.Economy.IncomePerSecond(session) * Swim.BonusSeconds))
		bonus = base * (stages.BonusMultiplier[state.Stage] or 1)
		Registry.Economy.AddMoney(session, bonus)
		if not state.NoShark then
			Registry.Quests.Progress(session, "Escapes", 1)
		end
	end
	local canContinue = success and state.Stage < stages.Max
	resultEvent:FireClient(session.Player, {
		Success = success,
		Reason = reason,
		Bonus = bonus,
		Item = if success then itemId else nil, -- dostal do domečku / nad hlavu / do skladu
		Placement = placement,
		LostItem = if success then nil else itemId, -- o tenhle předmět přišel
		Stage = state.Stage,
		MaxStage = stages.Max,
		CanContinue = canContinue, -- může skočit do vody a plavat k dalšímu voru
		NextMultiplier = if canContinue then stages.BonusMultiplier[state.Stage + 1] else nil,
		ChoiceTime = stages.ChoiceTime,
	})
	if canContinue then
		-- čeká na rozhodnutí; když nic nevybere, vrátí se na pláž
		state.Waiting = true
		local flight = state.Flight
		task.delay(stages.ChoiceTime + 0.5, function()
			if session.Swim == state and state.Waiting then
				state.Waiting = false
				returnLater(session, flight, 0)
			end
		end)
	else
		returnLater(session, state.Flight)
	end
end

-- Spustí úsek plavání k voru číslo `stage` (1 = po dopadu, 2–3 = po skoku z voru)
startStage = function(session: Session, previous: SwimState?, flight: any, landDistance: number, stage: number, noShark: boolean, usedRepellent: boolean)
	local root = Registry.Player.GetRoot(session.Player)
	if not root then
		if stage == 1 then
			-- plavání nezačalo (postava zmizela) – hráč za to nemůže, předmět dostane
			settleItem(session, flight, true)
		end
		returnLater(session, flight)
		return
	end
	local data = session.Data
	local stages = Swim.Stages
	-- kdo hráče honí (čím dál skočil, tím strašidelnější tvor); na dalších vorech je rychlejší
	local chaser = Formulas.ChaserTier(landDistance)
	local speed = Formulas.SwimSpeed(data.SwimLevel, session.Passes.TurboFins == true)
	-- vor 1 je směrem ke břehu, vory 2 a 3 dál na moři (za nimi už je jen otevřená voda)
	local dir = if stage == 1 then 1 else -1
	local distance = Formulas.SwimDistance(data.SwimLevel)
	if dir == 1 then
		-- vor nesmí skončit pod molem ani na pláži (krátký skok)
		distance = math.max(60, math.min(distance, root.Position.X - World.PierEndX - 8))
	end
	-- delší plavba nesmí být nefér: pronásledovatel vyrazí o tolik později, kolik hráč plave navíc
	local sharkDelay = Swim.SharkDelay + math.max(0, distance - Swim.Distance) / speed
	local treasure: string? = nil
	if stage >= 2 then
		local luck = Registry.Items.Luck(session)
		treasure = Registry.Items.Roll(landDistance, nil, stages.TreasureZoneShift[stage] or 0, luck)
	end
	local state: SwimState = {
		Flight = flight,
		StartClock = os.clock(),
		StartX = root.Position.X,
		Distance = distance,
		Speed = speed,
		SharkSpeed = chaser.Speed * (1 + (stage - 1) * stages.ChaserSpeedUp),
		CatchDistance = Swim.CatchDistance + chaser.Reach,
		NoShark = noShark,
		Done = false,
		Character = session.Player.Character,
		SharkDelay = sharkDelay,
		Stage = stage,
		LandDistance = landDistance,
		UsedRepellent = usedRepellent,
		Treasure = treasure,
		Waiting = false,
		Dir = dir,
	}
	local _ = previous
	session.Swim = state
	Registry.Player.MarkDirty(session)
	startEvent:FireClient(session.Player, {
		StartX = state.StartX,
		StartZ = root.Position.Z,
		Y = World.WaterY,
		Distance = state.Distance,
		Speed = state.Speed,
		SharkSpeed = state.SharkSpeed,
		SharkDelay = state.SharkDelay,
		Chaser = chaser.Key, -- klient podle toho postaví model a texty
		ChaserName = chaser.Name,
		NoShark = noShark,
		UsedRepellent = usedRepellent and stage == 1,
		MaxTime = Swim.MaxTime,
		-- od levelu 2 branky a překážky na cestě k voru (na dalších vorech těžší)
		Slalom = generateSlalom((data.Level or 1) + (stage - 1) * stages.SlalomLevelBonus, distance),
		CanUpgrade = data.SwimLevel < #Swim.Upgrades,
		Stage = stage,
		MaxStage = stages.Max,
		Treasure = treasure, -- poklad na voru (klient ukáže truhlu)
		Dir = dir,
	})
end

-- Zavolá JumpService po dopadu do vody
function SwimService.Begin(session: Session, flight: any, landDistance: number)
	if session.Flight ~= flight then
		return
	end
	local data = session.Data
	local noShark = data.TotalJumps <= Swim.NoSharkFirstJumps or Registry.ServerEvents.IsActive("SharkHoliday")
	local usedRepellent = false
	if not noShark and data.Repellents > 0 then
		data.Repellents -= 1
		noShark = true
		usedRepellent = true
	end
	startStage(session, nil, flight, landDistance, 1, noShark, usedRepellent)
end

function SwimService.Init()
	startEvent = Net.Event("SwimStart")
	resultEvent = Net.Event("SwimResult")
	-- na voru: dál k dalšímu voru, nebo zpět na pláž
	Net.Event("SwimChoice").OnServerEvent:Connect(function(player, goOn)
		local session = Registry.Player.Get(player)
		local state: SwimState? = session and session.Swim
		if not session or not state or not state.Waiting or session.Flight ~= state.Flight then
			return
		end
		state.Waiting = false
		if goOn == true and state.Stage < Swim.Stages.Max then
			-- repelent i Shark Holiday platí pro celé plavání
			local noShark = state.NoShark or Registry.ServerEvents.IsActive("SharkHoliday")
			startStage(session, state, state.Flight, state.LandDistance, state.Stage + 1, noShark, state.UsedRepellent)
		else
			returnLater(session, state.Flight, 0.6)
		end
	end)
end

function SwimService.Start()
	RunService.Heartbeat:Connect(function()
		for _, session in Registry.Player.Sessions do
			local state: SwimState? = session.Swim
			if state and not state.Done then
				local elapsed = os.clock() - state.StartClock
				local root = Registry.Player.GetRoot(session.Player)
				if not root or session.Player.Character ~= state.Character then
					finish(session, state, false, "Lost")
				else
					-- postup k voru (nemůže být rychlejší, než dovolí rychlost plavání)
					local progress = math.clamp((state.StartX - root.Position.X) * state.Dir, 0, state.Speed * elapsed * 1.15 + 4)
					local shark = Formulas.SharkProgress(elapsed, state.SharkSpeed, state.SharkDelay)
					if progress >= state.Distance then
						finish(session, state, true, "Safe")
					elseif not state.NoShark and elapsed > state.SharkDelay and shark >= math.min(progress + state.Speed * Swim.LagGrace, state.Distance) - state.CatchDistance then
						-- důvod je vždy "Shark" (ať je to kdokoli) – na to slyší nabídky a úkoly
						finish(session, state, false, "Shark")
					elseif elapsed > Swim.MaxTime then
						finish(session, state, false, "Timeout")
					end
				end
			end
		end
	end)
end


return SwimService

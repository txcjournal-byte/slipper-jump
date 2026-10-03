--!strict
-- Plavání zpět: po dopadu hráč plave k záchrannému voru a honí ho žralok.
-- O výsledku rozhoduje server podle pozic, které vidí (klient jen hýbe postavou a kreslí žraloka).
-- Doplave → bonus a předmět z vody. Chytí ho žralok (nebo nedoplave) → přijde o bonus i o předmět.

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
}

local SwimService = {}

local rng = Random.new()

export type SlalomGate = { X: number, Z: number, Gap: number, Amp: number, Speed: number, Phase: number }
export type SlalomObstacle = { Kind: string, X: number, Z: number, Amp: number, Speed: number, Phase: number }
export type SlalomLayout = { Name: string, Color: Color3, Gates: { SlalomGate }, Obstacles: { SlalomObstacle } }

-- Vylosuje slalom pro level hráče. X = vzdálenost od místa startu směrem k voru,
-- Z = posun do strany od dráhy (klient přičte StartZ). Mezery branek se střídají vlevo a vpravo,
-- překážky leží zhruba na spojnici dvou sousedních mezer, takže je hráč musí objet.
local function generateSlalom(level: number): SlalomLayout?
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
	local spacing = Swim.Distance / (tier.Gates + 1)
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
			X = math.clamp(x, 6, Swim.Distance - 6),
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

local function returnLater(session: Session, flight: any)
	task.delay(Swim.ReturnDelay, function()
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

local function finish(session: Session, state: SwimState, success: boolean, reason: string)
	if state.Done then
		return
	end
	state.Done = true
	local itemId, placement = settleItem(session, state.Flight, success)
	local bonus = 0
	if success then
		bonus = math.max(Swim.BonusMin, math.floor(Registry.Economy.IncomePerSecond(session) * Swim.BonusSeconds))
		Registry.Economy.AddMoney(session, bonus)
		if not state.NoShark then
			Registry.Quests.Progress(session, "Escapes", 1)
		end
	end
	resultEvent:FireClient(session.Player, {
		Success = success,
		Reason = reason,
		Bonus = bonus,
		Item = if success then itemId else nil, -- dostal do domečku / nad hlavu / do skladu
		Placement = placement,
		LostItem = if success then nil else itemId, -- o tenhle předmět přišel
	})
	returnLater(session, state.Flight)
end

-- Zavolá JumpService po dopadu do vody
function SwimService.Begin(session: Session, flight: any, landDistance: number)
	if session.Flight ~= flight then
		return
	end
	local root = Registry.Player.GetRoot(session.Player)
	if not root then
		-- plavání nezačalo (postava zmizela) – hráč za to nemůže, předmět dostane
		settleItem(session, flight, true)
		returnLater(session, flight)
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
	-- kdo hráče honí (čím dál skočil, tím strašidelnější tvor); dva žraloci = jedna pozice, jen rychlejší
	local chaser = Formulas.ChaserTier(landDistance)
	local state: SwimState = {
		Flight = flight,
		StartClock = os.clock(),
		StartX = root.Position.X,
		Distance = Swim.Distance,
		Speed = Formulas.SwimSpeed(data.SwimLevel, session.Passes.TurboFins == true),
		SharkSpeed = chaser.Speed,
		CatchDistance = Swim.CatchDistance + chaser.Reach,
		NoShark = noShark,
		Done = false,
		Character = session.Player.Character,
	}
	session.Swim = state
	Registry.Player.MarkDirty(session)
	startEvent:FireClient(session.Player, {
		StartX = state.StartX,
		StartZ = root.Position.Z,
		Y = World.WaterY,
		Distance = state.Distance,
		Speed = state.Speed,
		SharkSpeed = state.SharkSpeed,
		SharkDelay = Swim.SharkDelay,
		Chaser = chaser.Key, -- klient podle toho postaví model a texty
		ChaserName = chaser.Name,
		NoShark = noShark,
		UsedRepellent = usedRepellent,
		MaxTime = Swim.MaxTime,
		Slalom = generateSlalom(data.Level or 1), -- od levelu 10 branky a překážky na cestě k voru
		CanUpgrade = data.SwimLevel < #Swim.Upgrades,
	})
end

function SwimService.Init()
	startEvent = Net.Event("SwimStart")
	resultEvent = Net.Event("SwimResult")
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
					local progress = math.clamp(state.StartX - root.Position.X, 0, state.Speed * elapsed * 1.15 + 4)
					local shark = Formulas.SharkProgress(elapsed, state.SharkSpeed)
					if progress >= state.Distance then
						finish(session, state, true, "Safe")
					elseif not state.NoShark and elapsed > Swim.SharkDelay and shark >= math.min(progress + state.Speed * Swim.LagGrace, state.Distance) - state.CatchDistance then
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

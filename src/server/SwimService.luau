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
	HasSlalom: boolean,
	Trial: string?, -- úkol z ostrova (kánoe) – po doplutí rozhodne TrialService
	Hits: number, -- nárazy ve slalomu (hlásí klient) → hvězdičky
	LastHit: number,
	StartZ: number, -- posun do strany počítají sbírací věci od tohoto Z
	Pickups: { [string]: SlalomPickup }, -- nesebrané sbírací věci ve slalomu
	Extra: number, -- turbo: o kolik studů může být hráč dál, než dovolí rychlost plavání
}

local SwimService = {}

local rng = Random.new()
local forcedStyle: string? = nil -- jen testovací panel ve Studiu

export type SlalomGate = { X: number, Z: number, Gap: number, Amp: number, Speed: number, Phase: number, Side: number? }
export type SlalomObstacle = { Kind: string, X: number, Z: number, Amp: number, Speed: number, Phase: number }
export type SlalomPickup = { Id: string, Kind: string, X: number, Z: number }
export type SlalomLayout = {
	Name: string,
	Color: Color3,
	Gates: { SlalomGate },
	Obstacles: { SlalomObstacle },
	Pickups: { SlalomPickup },
	Style: string, -- druh slalomu (Gates, Buoys, Hoops, Canyon, Whirlpool)
	Variant: string?, -- zvláštní druh slalomu (Storm, Night …)
	Hint: string?,
	Drift: number?, -- vlny posouvají hráče do stran (studů/s)
	Night: boolean?,
}

-- Vylosuje slalom pro level hráče. X = vzdálenost od místa startu směrem k voru,
-- Z = posun do strany od dráhy (klient přičte StartZ). Mezery branek se střídají vlevo a vpravo,
-- překážky leží zhruba na spojnici dvou sousedních mezer, takže je hráč musí objet.
local function generateSlalom(level: number, distance: number, stage: number, gapBonus: number?, noVariants: boolean?): SlalomLayout?
	local tier = Formulas.SlalomTier(level)
	if not tier then
		return nil
	end
	tier.Gap += gapBonus or 0
	local cfg = Swim.Slalom
	-- druh slalomu (branky, bójky, obruče, kaňon, víry) – závod na kánoi má vždy branky
	local style = "Gates"
	local styleCfg = nil
	if not noVariants and forcedStyle then
		for _, st in cfg.Styles do
			if st.Key == forcedStyle then
				style = st.Key
				styleCfg = st
			end
		end
	elseif not noVariants then
		local pool, total = {}, 0
		for _, st in cfg.Styles do
			if level >= st.MinLevel then
				table.insert(pool, st)
				total += st.Weight
			end
		end
		local r = rng:NextNumber() * total
		for _, st in pool do
			r -= st.Weight
			if r <= 0 then
				style = st.Key
				styleCfg = st
				break
			end
		end
	end
	-- občas zvláštní druh slalomu (čím dál k pláži, tím častěji) – jen u branek
	local variant: Swim.SlalomVariant? = nil
	local unlocked = {}
	for _, v in cfg.Variants do
		if level >= v.MinLevel then
			table.insert(unlocked, v)
		end
	end
	if not noVariants and style == "Gates" and #unlocked > 0 and rng:NextNumber() < (cfg.VariantChance[stage] or 0.5) then
		variant = unlocked[rng:NextInteger(1, #unlocked)]
	end
	if variant then
		tier.Name = variant.Name
		tier.Color = variant.Color
		tier.Gates = math.max(2, tier.Gates + (variant.GateDelta or 0))
		tier.Moving = math.min(tier.Moving, math.ceil(tier.Gates / 2))
		if variant.Kind then
			local total = variant.Extra or 0
			for _, n in tier.Obstacles do
				total += n
			end
			tier.Obstacles = { [variant.Kind] = math.max(total, 2) }
		end
	end
	-- úpravy podle druhu slalomu
	local function halveObstacles()
		for kind, n in tier.Obstacles do
			tier.Obstacles[kind] = math.floor(n / 2)
		end
	end
	if style == "Buoys" then
		tier.Gates = math.min(tier.Gates + 2, 10)
		tier.Moving = 0
		halveObstacles()
	elseif style == "Hoops" then
		tier.Gates = math.min(tier.Gates + 1, 9)
		tier.Gap = cfg.HoopSize + (gapBonus or 0)
		halveObstacles()
	elseif style == "Canyon" then
		tier.Gates = math.min(tier.Gates * 2 + 2, 14)
		tier.Moving = 0
		tier.Gap = math.max(tier.Gap, 14)
		tier.Obstacles = {}
	elseif style == "Whirlpool" then
		tier.Obstacles = { Whirlpool = math.clamp(2 + math.floor((level - 12) / 8), 2, 5) }
	end
	if styleCfg and styleCfg.Name then
		tier.Name = styleCfg.Name
		tier.Color = styleCfg.Color or tier.Color
	end
	local gates: { SlalomGate } = {}
	local sign = if rng:NextNumber() < 0.5 then -1 else 1
	local canyonPhase = rng:NextNumber(0, math.pi * 2)
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
		local side: number? = nil
		if style == "Buoys" then
			-- bójka kousek od středu, objíždí se z vnější strany (cik-cak)
			z = sign * rng:NextNumber(4, math.clamp(tier.Offset, 5, 10))
			side = sign
		elseif style == "Canyon" then
			-- plynule klikatý kanál
			z = math.clamp(tier.Offset * 0.9 * math.sin(i * 0.8 + canyonPhase), -maxCenter, maxCenter)
		end
		sign = -sign
		table.insert(gates, {
			X = spacing * i,
			Z = z,
			Gap = tier.Gap,
			Amp = amp,
			Speed = if moving[i] then tier.MoveSpeed * rng:NextNumber(0.85, 1.15) else 0,
			Phase = rng:NextNumber(0, math.pi * 2),
			Side = side,
		})
	end
	-- překážky do úseků mezi brankami (úsek k = před k-tou brankou; poslední je mezi poslední brankou a vorem)
	local kinds: { string } = {}
	for _, kind in { "Rock", "Jellyfish", "Log", "Puffer", "Whirlpool" } do
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
	-- sbírací věci: v každém úseku jedna, kousek za začátkem úseku a směrem k mezeře další branky
	local pc = cfg.Pickups
	local pickups: { SlalomPickup } = {}
	local hasTurbo = false
	for k = 1, segments do
		local nextGate = gates[k]
		local prevZ = if k > 1 then gates[k - 1].Z else 0
		local targetZ = if nextGate then nextGate.Z else prevZ
		local roll = rng:NextNumber()
		local kind = "Coin"
		if level >= pc.FreezeFromLevel and roll < pc.FreezeChance then
			kind = "Freeze"
		elseif roll < pc.FreezeChance + pc.TurboChance then
			kind = "Turbo"
		end
		-- aspoň jedno turbo v delším slalomu
		if k == segments and not hasTurbo and segments >= 3 then
			kind = "Turbo"
		end
		hasTurbo = hasTurbo or kind == "Turbo"
		table.insert(pickups, {
			Id = "p" .. k,
			Kind = kind,
			X = math.clamp(spacing * (k - 1) + spacing * 0.3, 5, distance - 5),
			Z = math.clamp(prevZ + (targetZ - prevZ) * 0.55 + rng:NextNumber(-3, 3), -cfg.LaneHalfWidth + 4, cfg.LaneHalfWidth - 4),
		})
	end
	return {
		Name = tier.Name,
		Color = tier.Color,
		Gates = gates,
		Obstacles = obstacles,
		Pickups = pickups,
		Style = style,
		Variant = if variant then variant.Key else nil,
		Hint = if variant then variant.Hint elseif styleCfg then styleCfg.Hint else nil,
		Drift = if variant then variant.Drift else nil,
		Night = if variant then variant.Night else nil,
	}
end

local function pickupMap(slalom: SlalomLayout?): { [string]: SlalomPickup }
	local map = {}
	if slalom then
		for _, p in slalom.Pickups do
			map[p.Id] = p
		end
	end
	return map
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
	if state.Trial then
		-- závod na kánoi z ostrova: žádný předmět ani bonus za vor – vyhodnotí TrialService
		resultEvent:FireClient(session.Player, { Success = success, Reason = reason, Trial = state.Trial, Bonus = 0, Stage = 1, MaxStage = 1, CanContinue = false })
		session.Swim = nil
		Registry.Trials.OnCanoeFinished(session, success)
		return
	end
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
	local stars: number? = nil
	local starBonus = 0
	if success then
		local base = math.max(Swim.BonusMin, math.floor(Registry.Economy.IncomePerSecond(session) * Swim.BonusSeconds))
		bonus = base * (stages.BonusMultiplier[state.Stage] or 1)
		-- hvězdičky za slalom (podle nárazů): ★★★ = bonus navíc
		if state.HasSlalom then
			local cfg = Swim.Slalom
			stars = if state.Hits <= cfg.StarHits.Three then 3 elseif state.Hits <= cfg.StarHits.Two then 2 else 1
			starBonus = math.floor(bonus * (cfg.StarBonus[stars :: number] or 0))
			bonus += starBonus
		end
		Registry.Economy.AddMoney(session, bonus)
		if not state.NoShark then
			Registry.Quests.Progress(session, "Escapes", 1)
		end
	end
	-- další vor: od levelu 5 a jen když je mezi vorem a molem dost vody
	local root = Registry.Player.GetRoot(session.Player)
	local room = if root then root.Position.X - World.PierEndX - 8 else 0
	local canContinue = success
		and state.Stage < stages.Max
		and (session.Data.Level or 1) >= stages.MinLevel
		and room >= stages.MinRoom
	resultEvent:FireClient(session.Player, {
		Success = success,
		Reason = reason,
		Bonus = bonus,
		Stars = stars,
		StarBonus = starBonus,
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
	-- všechny vory jsou směrem k pláži; slalom na dalších vorech jako by měl hráč o pár levelů víc
	local dir = 1
	local slalomLevel = (data.Level or 1) + (stage - 1) * stages.SlalomLevelBonus
	local distance = Formulas.SwimDistance(data.SwimLevel, slalomLevel)
	-- vor nesmí skončit pod molem ani na pláži (krátký skok)
	distance = math.max(60, math.min(distance, root.Position.X - World.PierEndX - 8))
	local slalom = generateSlalom(slalomLevel, distance, stage)
	-- delší plavba nesmí být nefér: pronásledovatel vyrazí o tolik později, kolik hráč plave navíc
	local sharkDelay = Swim.SharkDelay + math.max(0, distance - Swim.Distance) / speed
		+ (if slalom then math.min(#slalom.Gates, 8) * Swim.Slalom.DelayPerGate else 0)
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
		HasSlalom = slalom ~= nil,
		Hits = 0,
		LastHit = 0,
		StartZ = root.Position.Z,
		Pickups = pickupMap(slalom),
		-- obruče zrychlují: server musí povolit, že hráč bude o kus dál, než dovolí plavání
		Extra = if slalom and slalom.Style == "Hoops"
			then #slalom.Gates * speed * (Swim.Slalom.HoopBoostMultiplier - 1) * Swim.Slalom.HoopBoostTime
			else 0,
	}
	local _ = previous
	session.Swim = state
	local shield = if stage == 1 and flight.Shield then flight.Shield else 0
	if slalom and data.Shields > 0 then
		data.Shields -= 1
		shield += 1
	end
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
		Slalom = slalom,
		CanUpgrade = data.SwimLevel < #Swim.Upgrades,
		Stage = stage,
		MaxStage = stages.Max,
		Treasure = treasure, -- poklad na voru (klient ukáže truhlu)
		Dir = dir,
		-- štít z diamantu (Amethyst / Rainbow) na prvním úseku + Bubble Shield (Robux) na každý slalom
		Shield = shield,
	})
end

-- Závod na kánoi z dárkového ostrova (TrialService). Stejné jako plavání k voru, jen rychlejší,
-- s pevnou obtížností a cílem daleko na moři směrem k pláži.
function SwimService.StartTrial(session: Session, key: string, cfg: any, easy: boolean, waterStart: Vector3): boolean
	local root = Registry.Player.GetRoot(session.Player)
	if not root then
		return false
	end
	-- jen značka „hráč je v závodě“ (není to skutečný let): Finished = true, ať ji JumpService
	-- (záznam poloh letu) a AvatarService (respawn uprostřed letu) neberou jako rozletěný skok
	local flight = { Trial = key, Finished = true }
	session.Flight = flight
	local trials = require(Shared.Config.Trials)
	local slalom = generateSlalom(cfg.SlalomLevel, cfg.Distance, 1, if easy then trials.EasyGapBonus else 0, true)
	if slalom then
		local trialCfg = trials.Trials[key]
		slalom.Name = trialCfg.Name
		slalom.Hint = "Paddle with W / joystick, steer through the gates!"
		if cfg.Drift then
			slalom.Drift = cfg.Drift
		end
	end
	local chaser = Formulas.ChaserByKey(cfg.Chaser)
	local speed = cfg.Speed
	local sharkDelay = cfg.Delay + (if slalom then #slalom.Gates * Swim.Slalom.DelayPerGate else 0)
	local state: SwimState = {
		Flight = flight,
		StartClock = os.clock(),
		StartX = waterStart.X,
		Distance = cfg.Distance,
		Speed = speed,
		SharkSpeed = cfg.ChaserSpeed * (if easy then trials.EasyChaserFactor else 1),
		CatchDistance = Swim.CatchDistance + chaser.Reach,
		NoShark = false,
		Done = false,
		Character = session.Player.Character,
		SharkDelay = sharkDelay,
		Stage = 1,
		LandDistance = 0,
		UsedRepellent = false,
		Treasure = nil,
		Waiting = false,
		Dir = 1,
		HasSlalom = slalom ~= nil,
		Hits = 0,
		LastHit = 0,
		StartZ = waterStart.Z,
		Pickups = pickupMap(slalom),
		Extra = 0,
		Trial = key,
	}
	session.Swim = state
	startEvent:FireClient(session.Player, {
		StartX = waterStart.X,
		StartZ = waterStart.Z,
		Y = World.WaterY,
		Distance = cfg.Distance,
		Speed = speed,
		SharkSpeed = state.SharkSpeed,
		SharkDelay = sharkDelay,
		Chaser = chaser.Key,
		ChaserName = chaser.Name,
		NoShark = false,
		UsedRepellent = false,
		MaxTime = Swim.MaxTime,
		Slalom = slalom,
		CanUpgrade = false,
		Stage = 1,
		MaxStage = 1,
		Treasure = nil,
		Dir = 1,
		Shield = 0,
		Trial = key,
		Mode = "Canoe",
	})
	return true
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

-- Testovací panel ve Studiu: další slalomy budou tohoto druhu (nil = náhodně)
function SwimService.ForceStyle(style: string?)
	forcedStyle = style
end

function SwimService.Init()
	startEvent = Net.Event("SwimStart")
	resultEvent = Net.Event("SwimResult")
	-- klient hlásí náraz ve slalomu (kvůli hvězdičkám)
	Net.Event("SlalomHit").OnServerEvent:Connect(function(player)
		local session = Registry.Player.Get(player)
		local state: SwimState? = session and session.Swim
		if state and not state.Done and os.clock() - state.LastHit > 0.3 then
			state.LastHit = os.clock()
			state.Hits += 1
		end
	end)
	-- klient sebral věc ve slalomu: server ověří, že u ní hráč opravdu je, a použije ji
	Net.Event("SlalomPickup").OnServerEvent:Connect(function(player, id)
		local session = Registry.Player.Get(player)
		local state: SwimState? = session and session.Swim
		if not session or not state or state.Done or type(id) ~= "string" then
			return
		end
		local pickup = state.Pickups[id]
		local root = Registry.Player.GetRoot(player)
		if not pickup or not root then
			return
		end
		local progress = (state.StartX - root.Position.X) * state.Dir
		local pc = Swim.Slalom.Pickups
		-- rezerva na zpoždění sítě (server vidí polohu o ping později)
		if math.abs(progress - pickup.X) > pc.Radius + 6 or math.abs(root.Position.Z - (state.StartZ + pickup.Z)) > pc.Radius + 4 then
			return
		end
		state.Pickups[id] = nil
		if pickup.Kind == "Coin" then
			local money = math.max(pc.CoinMin, math.floor(Registry.Economy.IncomePerSecond(session) * pc.CoinSeconds))
			Registry.Economy.AddMoney(session, money)
			Registry.Player.MarkDirty(session)
			Net.Event("PlayEffect"):FireClient(player, "Collect", { Amount = money })
		elseif pickup.Kind == "Turbo" then
			state.Extra += state.Speed * (pc.TurboMultiplier - 1) * pc.TurboTime
		elseif pickup.Kind == "Freeze" then
			state.SharkDelay += pc.FreezeTime
		end
	end)
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
					local progress = math.clamp((state.StartX - root.Position.X) * state.Dir, 0, state.Speed * elapsed * 1.15 + 4 + state.Extra)
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

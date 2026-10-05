--!strict
-- Skok: server ověří, že hráč stojí na konci mola, zkontroluje hodnotu ukazatele síly,
-- spočítá vzdálenost, rozmístí mince a kruhy, sleduje let a na konci sám ověří,
-- co hráč opravdu posbíral. Pak dá předmět, XP, peníze a vrátí hráče na pláž.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Jump = require(Shared.Config.Jump)
local World = require(Shared.Config.World)
local Tutorial = require(Shared.Config.Tutorial)
local Events = require(Shared.Config.Events)
local Swim = require(Shared.Config.Swim)
local Products = require(Shared.Config.Products)
local Diamonds = require(Shared.Config.Diamonds)
local Formulas = require(Shared.Formulas)
local Catalog = require(Shared.Catalog)
local Net = require(Shared.Net)

local Registry = require(script.Parent.Registry)

type Session = any

export type Collectible = { Id: string, Position: Vector3 }

export type Sample = { X: number, Y: number, Z: number }

export type Flight = {
	Id: number,
	StartClock: number,
	StartPosition: Vector3,
	EndX: number,
	EndY: number,
	Height: number,
	Duration: number,
	BaseDistance: number,
	Cap: number,
	Tier: string,
	Coins: { [string]: Vector3 },
	Rings: { [string]: Vector3 },
	Diamonds: { [string]: { Position: Vector3, Type: string } },
	Balloons: { [string]: Vector3 }, -- poklad na balónku (předmět navíc)
	DiamondIncome: number, -- příjem za sekundu pro výpočet peněz za diamant
	Shield: number?, -- štít z diamantu pro slalom (SwimService)
	CoinValue: number,
	Samples: { Sample },
	Finished: boolean,
	SuperJump: boolean,
	RingBonus: number,
	PerfectStreak: number, -- série PERFECT skoků včetně tohoto (0 = bez série)
	XPMultiplier: number, -- Double XP (podle události při odrazu)
	DuringEvent: boolean, -- skok během události na serveru (úkol)
	Contest: boolean, -- skok během Jump Contest
	GiftAt: number, -- vzdálenost nejbližšího dárku (ostrov nebo Obří dárek)
	GiftIsland: string?, -- klíč dárkového ostrova (nil = Obří dárek)
	PendingItem: string?, -- předmět z vody: hráč ho dostane, až doplave k voru (chycení = přijde o něj)
}

local JumpService = {}

local rng = Random.new()
local flightCounter = 0

local flightStartEvent: RemoteEvent
local jumpResultEvent: RemoteEvent
local effectEvent: RemoteEvent

local function inJumpZone(root: BasePart): boolean
	local pos = root.Position
	return pos.X >= World.PierEndX - Jump.JumpZoneLength - 2
		and pos.X <= World.PierEndX + 3
		and math.abs(pos.Z) <= World.PierWidth / 2 + 2
		and pos.Y >= World.PierDeckY - 1
		and pos.Y <= World.PierDeckY + 12
end

local function meterPeriod(session: Session): number
	if not session.Data.TutorialDone and session.Data.TotalJumps == 0 then
		return Jump.Meter.TutorialPeriod
	end
	return Jump.Meter.Period
end

-- Vylosuje druh diamantu podle levelu (vyšší level = častěji vzácné)
local function rollDiamond(level: number, rareBoost: number): string
	local total = 0
	local pool = {}
	for _, t in Diamonds.Types do
		if level >= t.MinLevel then
			local w = t.Weight
			if t.Key ~= "Green" and t.Key ~= "Blue" then
				w *= (1 + level * Diamonds.RareBoostPerLevel) * rareBoost
			end
			total += w
			table.insert(pool, { Key = t.Key, W = w })
		end
	end
	local r = rng:NextNumber() * total
	for _, e in pool do
		r -= e.W
		if r <= 0 then
			return e.Key
		end
	end
	return "Green"
end

-- Najde Z (a Y) hráče ve chvíli, kdy míjel dané X – z pozic, které viděl server
local function lateralAt(samples: { Sample }, x: number): (number?, number?)
	local previous: Sample? = nil
	for _, sample in samples do
		if previous and previous.X <= x and sample.X >= x then
			local span = sample.X - previous.X
			local alpha = if span > 0.001 then (x - previous.X) / span else 0
			return previous.Z + (sample.Z - previous.Z) * alpha, previous.Y + (sample.Y - previous.Y) * alpha
		end
		previous = sample
	end
	return nil, nil
end

local function verify(flight: Flight, position: Vector3, radius: number): boolean
	local z, y = lateralAt(flight.Samples, position.X)
	if not z or not y then
		return false
	end
	local tolerance = Jump.Collectibles.ServerTolerance
	return math.abs(z - position.Z) <= radius + tolerance and math.abs(y - position.Y) <= radius + tolerance * 2
end

function JumpService.Charge(player: Player)
	local session = Registry.Player.Get(player)
	if not session or session.Flight or session.Returning then
		return
	end
	local root = Registry.Player.GetRoot(player)
	if not root or not inJumpZone(root) then
		return
	end
	if session.Data.Carried then
		Registry.Player.Notify(player, "Your hands are full! Put the item in your house, sell it or gift it first.", "Warning")
		return
	end
	session.Charge = { Start = os.clock(), Period = meterPeriod(session) }
end

function JumpService.Release(player: Player, clientValue: unknown)
	local session = Registry.Player.Get(player)
	if not session or session.Flight or session.Returning then
		return
	end
	local charge = session.Charge
	session.Charge = nil
	if not charge then
		return
	end
	if os.clock() - session.LastJump < Jump.Cooldown then
		return
	end
	local root = Registry.Player.GetRoot(player)
	if not root or not inJumpZone(root) then
		return
	end
	if session.Data.Carried then
		return
	end
	local elapsed = os.clock() - charge.Start
	if elapsed > Jump.Meter.MaxHoldTime then
		return
	end
	-- kontrola hodnoty ukazatele: klient smí být jen trochu mimo odhad serveru (ping)
	local expected = Formulas.MeterValue(elapsed, charge.Period)
	local value = expected
	if type(clientValue) == "number" and clientValue == clientValue and clientValue >= 0 and clientValue <= 1 then
		if math.abs(clientValue - expected) <= Jump.Meter.Tolerance then
			value = clientValue
		end
	end
	local tier, bonus = Formulas.PowerTier(value)

	-- série PERFECT skoků (jen pro tuto session, neukládá se)
	local streak = if tier == "Perfect" then (session.PerfectStreak or 0) + 1 else 0
	session.PerfectStreak = streak
	local streakBonus = Formulas.PerfectStreakBonus(streak)

	local data = session.Data
	-- jednorázové bonusy: nejdřív Mega Jump (+50 %), jinak Super Jump (+20 %) – nikdy oba naráz
	local megaJump = data.MegaJumps > 0
	local superJump = false
	if megaJump then
		data.MegaJumps -= 1
	elseif data.SuperJumps > 0 then
		data.SuperJumps -= 1
		superJump = true
	end
	local distance = Formulas.BaseJump(data.EquippedSlippers, data.EquippedHat)
		* (1 + bonus)
		* (1 + rng:NextNumber(-Jump.RandomSpread, Jump.RandomSpread))
		* Formulas.PassJumpMultiplier(session.Passes.SuperJumper == true)
		* (if megaJump then 1 + Products.MegaJumpBonus elseif superJump then 1 + Jump.SuperJumpBonus else 1)
		* (if Registry.ServerEvents.IsActive("MegaJump") then 1 + Events.MegaJumpBonus else 1)
		* (1 + streakBonus)
	local cap = if Catalog.IsBestShoe(data.EquippedSlippers) then Jump.MaxDistance else Jump.MaxDistanceWithoutBest
	-- nejbližší dárkový ostrov, který hráč ještě nezískal: skok se u něj zastaví a hráč na něm přistane
	local island = Formulas.NextGiftIsland(data.ClaimedGifts)
	local giftAt = if island then island.Distance else World.GiftDistance
	local giftLanding: Vector3 = if island then Registry.Map.IslandLandings[island.Key] else Registry.Map.GiftLanding
	if island then
		cap = math.min(cap, island.Distance)
	end
	distance = math.clamp(distance, 10, cap)

	local startPosition = root.Position
	local endX = World.PierEndX + distance
	local reachesGift = distance >= giftAt
	local endY = if reachesGift then giftLanding.Y + 3 else World.WaterY + 1.5
	local duration = Formulas.FlightDuration(distance)
	local height = Formulas.FlightHeight(distance)

	-- mince a kruhy (pro každého hráče zvlášť)
	local c = Jump.Collectibles
	local coins: { [string]: Vector3 } = {}
	local rings: { [string]: Vector3 } = {}
	local coinList: { Collectible } = {}
	local ringList: { Collectible } = {}
	local span = c.EndFraction - c.StartFraction
	local rows = math.clamp(math.floor(distance / c.StudsPerCoinRow), 2, c.CoinRows)
	local ringMultiplier = if Registry.ServerEvents.IsActive("RainbowRings") then Events.RainbowRingsMultiplier else 1
	local ringCount = math.clamp(math.floor(distance * ringMultiplier / c.StudsPerRing), 1, c.Rings * ringMultiplier)
	local spacing = math.max(distance * c.CoinRowSpacing, c.MinCoinSpacing) / distance
	for row = 1, rows do
		local p0 = c.StartFraction + span * (row - 0.5) / rows
		local z = rng:NextNumber(-c.CoinLateral, c.CoinLateral)
		for k = 1, c.CoinsPerRow do
			local p = p0 + (k - (c.CoinsPerRow + 1) / 2) * spacing
			local x, y = Formulas.Trajectory(p, startPosition.X, endX, startPosition.Y, endY, height)
			local id = "c" .. row .. "_" .. k
			local pos = Vector3.new(x, y, z)
			coins[id] = pos
			table.insert(coinList, { Id = id, Position = pos })
		end
	end
	for index = 1, ringCount do
		local p = c.StartFraction + span * index / (ringCount + 1)
		local x, y = Formulas.Trajectory(p, startPosition.X, endX, startPosition.Y, endY, height)
		local id = "r" .. index
		local pos = Vector3.new(x, y, rng:NextNumber(-c.RingLateral, c.RingLateral))
		rings[id] = pos
		table.insert(ringList, { Id = id, Position = pos })
	end

	-- barevné diamanty mezi kruhy (od levelu 3 nebo po 5 skocích)
	local diamonds: { [string]: { Position: Vector3, Type: string } } = {}
	local diamondList = {}
	local level = data.Level or 1
	local rush = Registry.ServerEvents.IsActive("DiamondRush")
	local hunter = session.Passes.TreasureHunter == true
	if level >= Diamonds.MinLevel or data.TotalJumps >= Diamonds.MinJumps or rush then
		local extra = (if rush then Diamonds.RushExtra else 0) + (if hunter then Diamonds.HunterExtra else 0)
		local rareBoost = (if rush then Diamonds.RushRareBoost else 1) * (if hunter then Diamonds.HunterRareBoost else 1)
		local count = math.min(Diamonds.BaseCount + math.floor(level / Diamonds.LevelsPerExtra), Diamonds.MaxCount, ringCount + 1) + extra
		for index = 1, count do
			-- mezi kruhy (posunuto o půl mezery) a kousek do strany, ať se pro ně musí kormidlovat
			local p = c.StartFraction + span * (index - 0.5) / (count + 0.5) + span * 0.04
			p = math.clamp(p, c.StartFraction, c.EndFraction)
			local x, y = Formulas.Trajectory(p, startPosition.X, endX, startPosition.Y, endY, height)
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local pos = Vector3.new(x, y + rng:NextNumber(-2, 3), side * rng:NextNumber(8, Diamonds.Lateral))
			local id = "d" .. index
			local kind = rollDiamond(level, rareBoost)
			diamonds[id] = { Position = pos, Type = kind }
			table.insert(diamondList, { Id = id, Position = pos, Type = kind })
		end
	end

	-- poklad na balónku (občas; během Balloon Party vždy a víc)
	local balloons: { [string]: Vector3 } = {}
	local balloonList = {}
	local b = Diamonds.Balloon
	local party = Registry.ServerEvents.IsActive("BalloonParty")
	local balloonCount = 0
	if party then
		balloonCount = b.PartyCount
	elseif level >= b.MinLevel and rng:NextNumber() < (if hunter then b.HunterChance else b.Chance) then
		balloonCount = 1
	end
	for index = 1, balloonCount do
		local p = rng:NextNumber(0.3, 0.8)
		local x, y = Formulas.Trajectory(p, startPosition.X, endX, startPosition.Y, endY, height)
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local pos = Vector3.new(x, y, side * rng:NextNumber(4, b.Lateral))
		local id = "b" .. index
		balloons[id] = pos
		table.insert(balloonList, { Id = id, Position = pos })
	end

	flightCounter += 1
	local flight: Flight = {
		Id = flightCounter,
		StartClock = os.clock(),
		StartPosition = startPosition,
		EndX = endX,
		EndY = endY,
		Height = height,
		Duration = duration,
		BaseDistance = distance,
		Cap = cap,
		Tier = tier,
		Coins = coins,
		Rings = rings,
		Diamonds = diamonds,
		Balloons = balloons,
		DiamondIncome = math.max(Diamonds.MinIncome, Registry.Economy.IncomePerSecond(session)),
		CoinValue = math.max(1, Registry.Economy.IncomePerSecond(session) * c.CoinValueSeconds)
			* (if Registry.ServerEvents.IsActive("CoinStorm") then Events.CoinStormMultiplier else 1),
		Samples = {},
		Finished = false,
		SuperJump = superJump,
		RingBonus = c.RingBonus * (if Registry.ServerEvents.IsActive("GoldenRings") then Events.GoldenRingsMultiplier else 1),
		PerfectStreak = streak,
		XPMultiplier = if Registry.ServerEvents.IsActive("DoubleXP") then Events.DoubleXPMultiplier else 1,
		DuringEvent = Registry.ServerEvents.AnyActive(),
		Contest = Registry.ServerEvents.IsActive("JumpContest"),
		GiftAt = giftAt,
		GiftIsland = if island then island.Key else nil,
	}
	session.Flight = flight
	session.LastJump = os.clock()
	Registry.Avatar.SetFlightEffects(session, true)
	Registry.Player.MarkDirty(session)

	flightStartEvent:FireClient(player, {
		Id = flight.Id,
		StartPosition = startPosition,
		EndX = endX,
		EndY = endY,
		Height = height,
		Duration = duration,
		BaseDistance = distance,
		Cap = cap,
		GiftAt = giftAt, -- kde je nejbližší dárek (klient podle toho přistane na ostrově)
		GiftName = if island then island.Name else "GIANT GIFT",
		GiftLandY = giftLanding.Y + 3,
		PierEndX = World.PierEndX,
		Tier = tier,
		Coins = coinList,
		Rings = ringList,
		Diamonds = diamondList,
		Balloons = balloonList,
		CoinValue = flight.CoinValue,
		SuperJump = superJump,
		MegaJump = megaJump,
		RingBonus = flight.RingBonus,
		PerfectStreak = streak,
		StreakBonus = streakBonus,
	})
	effectEvent:FireAllClients("Takeoff", { UserId = player.UserId, Tier = tier, Slippers = data.EquippedSlippers })

	-- pojistka: když klient nenahlásí dopad, server skok dokončí sám
	local maxTime = duration + Jump.Flight.ExtraGlideMax + 6
	task.delay(maxTime, function()
		if session.Flight == flight and not flight.Finished then
			JumpService.Finish(session, flight, {}, {}, {}, {})
		end
	end)
end

function JumpService.Finish(session: Session, flight: Flight, coinIds: { string }, ringIds: { string }, diamondIds: { string }, balloonIds: { string })
	if flight.Finished then
		return
	end
	flight.Finished = true
	local player: Player = session.Player
	local data = session.Data
	local c = Jump.Collectibles

	-- ověření mincí a kruhů podle pozic, které viděl server
	local coinCount = 0
	local seen: { [string]: boolean } = {}
	for _, id in coinIds do
		local pos = flight.Coins[id]
		if pos and not seen[id] and verify(flight, pos, c.CoinRadius) then
			seen[id] = true
			coinCount += 1
		end
	end
	local ringCount = 0
	for _, id in ringIds do
		local pos = flight.Rings[id]
		if pos and not seen[id] and verify(flight, pos, c.RingRadius) then
			seen[id] = true
			ringCount += 1
		end
	end

	-- diamanty: peníze a bonusy
	local diamondMoney = 0
	local xpBonus = 0
	local coinMultiplier = 1
	local distanceBonus = 0
	local shield = 0
	local collected = {}
	for _, id in diamondIds do
		local d = flight.Diamonds[id]
		if d and not seen[id] and verify(flight, d.Position, Diamonds.Radius) then
			seen[id] = true
			local t = Diamonds.ByKey[d.Type]
			if t then
				local money = math.floor(flight.DiamondIncome * t.MoneySeconds)
				diamondMoney += money
				xpBonus += t.XPBonus or 0
				shield += t.Shield or 0
				coinMultiplier = math.max(coinMultiplier, t.CoinMultiplier or 1)
				distanceBonus += t.DistanceBonus or 0
				table.insert(collected, { Type = t.Key, Money = money })
			end
		end
	end
	flight.Shield = if shield > 0 then shield else nil
	Registry.Economy.AddMoney(session, diamondMoney)

	-- balónky s truhlou: předmět navíc hned do domečku + peníze
	local balloonPrizes = {}
	for _, id in balloonIds do
		local pos = flight.Balloons[id]
		if pos and not seen[id] and verify(flight, pos, Diamonds.Balloon.Radius) then
			seen[id] = true
			local luck = Registry.Items.Luck(session)
			local prize = Registry.Items.Roll(math.max(flight.BaseDistance, 100), nil, Diamonds.Balloon.ZoneShift, luck)
			local _, placement = Registry.Items.Give(session, prize)
			local money = math.floor(flight.DiamondIncome * Diamonds.Balloon.MoneySeconds)
			Registry.Economy.AddMoney(session, money)
			table.insert(balloonPrizes, { Item = prize, Placement = placement, Money = money })
		end
	end

	local distance = math.min(flight.BaseDistance * (1 + flight.RingBonus * ringCount + distanceBonus), flight.Cap)
	local reachedGift = distance >= flight.GiftAt
	if reachedGift then
		distance = flight.GiftAt
	end
	local islandKey = if reachedGift then flight.GiftIsland else nil
	distance = math.floor(distance)

	-- XP, peníze za mince
	local xp = math.floor(Formulas.XPForJump(distance) * flight.XPMultiplier * (1 + xpBonus))
	local coinMoney = math.floor(coinCount * flight.CoinValue * coinMultiplier)
	Registry.Economy.AddMoney(session, coinMoney)

	-- předmět z vody (první skok je vždy Uncommon)
	local forced: string? = nil
	if data.TotalJumps == 0 then
		forced = Tutorial.FirstItemRarity
	end
	-- předmět z vody se jen vylosuje; do domečku ho hráč dostane, až doplave k voru (SwimService)
	local itemId: string? = nil
	local isNew = false
	if not reachedGift then
		local zoneShift = if Registry.ServerEvents.IsActive("TreasureTide") then 1 else 0
		local luck = Registry.Items.Luck(session)
		itemId = Registry.Items.Roll(distance, forced, zoneShift, luck)
		isNew = not data.Discovered[itemId :: string]
		flight.PendingItem = itemId
	end

	data.TotalJumps += 1
	local personalRecord = distance > data.BestJump
	if personalRecord then
		data.BestJump = distance
	end
	Registry.Leaderboard.OnJump(session, distance)
	Registry.ServerEvents.OnJump(session, distance, flight.Contest)
	Registry.Level.AddXP(session, xp)
	Registry.Tutorial.OnJumped(session)
	Registry.Quests.Progress(session, "Jumps", 1)
	Registry.Quests.Progress(session, "Coins", coinCount)
	Registry.Quests.Progress(session, "Rings", ringCount)
	Registry.Quests.Progress(session, "Distance", distance)
	if flight.Tier == "Perfect" then
		Registry.Quests.Progress(session, "Perfects", 1)
	end
	Registry.Quests.Reach(session, "PerfectStreak", flight.PerfectStreak)
	if flight.DuringEvent then
		Registry.Quests.Progress(session, "EventJumps", 1)
	end

	local cfg = if itemId then Catalog.Item(itemId) else nil
	jumpResultEvent:FireClient(player, {
		FlightId = flight.Id,
		Distance = distance,
		Tier = flight.Tier,
		Coins = coinCount,
		CoinMoney = coinMoney,
		Rings = ringCount,
		Diamonds = collected,
		DiamondMoney = diamondMoney,
		Balloons = balloonPrizes,
		CoinMultiplier = coinMultiplier,
		Item = if itemId then { Id = itemId, Income = if cfg then cfg.Income else 0 } else nil,
		Placement = if itemId then "Pending" else nil,
		IsNew = isNew,
		XP = xp,
		DoubleXP = flight.XPMultiplier > 1,
		PersonalRecord = personalRecord,
		ReachedGift = reachedGift,
		GiftIsland = islandKey,
	})
	effectEvent:FireAllClients("Splash", { UserId = player.UserId, Position = Vector3.new(World.PierEndX + distance, World.WaterY, 0), Gift = reachedGift })

	if reachedGift then
		if islandKey then
			Registry.Rebirth.OnIslandReached(session, islandKey)
		else
			Registry.Rebirth.OnGiftReached(session)
		end
	end

	session.Returning = true
	Registry.Avatar.SetFlightEffects(session, false)
	if reachedGift then
		-- po otevření dárku zůstane hráč na ostrově a dostane úkol na cestu domů (TrialService)
		task.delay(Jump.GiftReturnDelay, function()
			if session.Flight == flight then
				session.Flight = nil
				session.Returning = false
				Registry.Trials.Offer(session, islandKey or "Giant")
				Registry.Player.MarkDirty(session)
			end
		end)
	else
		-- plavání zpět k voru (honí ho žralok)
		task.delay(Swim.StartDelay, function()
			Registry.Swim.Begin(session, flight, distance)
		end)
	end
end

function JumpService.Landed(player: Player, flightId: unknown, coinIds: unknown, ringIds: unknown, diamondIds: unknown, balloonIds: unknown)
	local session = Registry.Player.Get(player)
	local flight: Flight? = session and session.Flight
	if not session or not flight or flight.Finished or flightId ~= flight.Id then
		return
	end
	local function sanitize(list: unknown, limit: number): { string }
		local result = {}
		if type(list) == "table" then
			for _, value in list :: { any } do
				if type(value) == "string" and #result < limit then
					table.insert(result, value)
				end
			end
		end
		return result
	end
	local coins = sanitize(coinIds, Jump.Collectibles.CoinRows * Jump.Collectibles.CoinsPerRow)
	local rings = sanitize(ringIds, Jump.Collectibles.Rings * Events.RainbowRingsMultiplier)
	local gems = sanitize(diamondIds, Diamonds.MaxCount + Diamonds.RushExtra + Diamonds.HunterExtra)
	local pops = sanitize(balloonIds, Diamonds.Balloon.PartyCount)
	-- klient nesmí přistát dřív, než by let doopravdy trval
	local remaining = flight.Duration * 0.9 - (os.clock() - flight.StartClock)
	if remaining > 0 then
		task.delay(remaining, function()
			if session.Flight == flight then
				JumpService.Finish(session, flight, coins, rings, gems, pops)
			end
		end)
	else
		JumpService.Finish(session, flight, coins, rings, gems, pops)
	end
end

function JumpService.Init()
	flightStartEvent = Net.Event("FlightStart")
	jumpResultEvent = Net.Event("JumpResult")
	effectEvent = Net.Event("PlayEffect")
end

function JumpService.Start()
	Net.Event("JumpCharge").OnServerEvent:Connect(JumpService.Charge)
	Net.Event("JumpRelease").OnServerEvent:Connect(JumpService.Release)
	Net.Event("FlightLanded").OnServerEvent:Connect(JumpService.Landed)

	-- server si zaznamenává pozice letících hráčů (pro kontrolu mincí a kruhů)
	RunService.Heartbeat:Connect(function()
		for _, session in Registry.Player.Sessions do
			local flight: Flight? = session.Flight
			if flight and not flight.Finished and #flight.Samples < 4000 then
				local root = Registry.Player.GetRoot(session.Player)
				if root then
					local pos = root.Position
					local last = flight.Samples[#flight.Samples]
					if not last or pos.X > last.X + 0.05 then
						table.insert(flight.Samples, { X = pos.X, Y = pos.Y, Z = pos.Z })
					end
				end
			end
		end
	end)
end

return JumpService

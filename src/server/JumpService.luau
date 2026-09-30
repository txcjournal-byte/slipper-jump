--!strict
-- Skok: server ověří, že hráč stojí na konci mola, zkontroluje hodnotu ukazatele síly,
-- spočítá vzdálenost, rozmístí mince a kruhy, sleduje let a na konci sám ověří,
-- co hráč opravdu posbíral. Pak dá předmět, XP, peníze a vrátí hráče na pláž.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Jump = require(Shared.Config.Jump)
local World = require(Shared.Config.World)
local Tutorial = require(Shared.Config.Tutorial)
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
	CoinValue: number,
	Samples: { Sample },
	Finished: boolean,
	SuperJump: boolean,
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

	local data = session.Data
	local superJump = data.SuperJumps > 0
	if superJump then
		data.SuperJumps -= 1
	end
	local distance = Formulas.BaseJump(data.EquippedSlippers, data.EquippedHat)
		* (1 + bonus)
		* (1 + rng:NextNumber(-Jump.RandomSpread, Jump.RandomSpread))
		* (if superJump then 1 + Jump.SuperJumpBonus else 1)
	local cap = if data.EquippedSlippers == Jump.BestSlippersId then Jump.MaxDistance else Jump.MaxDistanceWithoutBest
	distance = math.clamp(distance, 10, cap)

	local startPosition = root.Position
	local endX = World.PierEndX + distance
	local reachesGift = distance >= World.GiftDistance
	local endY = if reachesGift then Registry.Map.GiftLanding.Y + 3 else World.WaterY + 1.5
	local duration = Formulas.FlightDuration(distance)
	local height = Formulas.FlightHeight(distance)

	-- mince a kruhy (pro každého hráče zvlášť)
	local c = Jump.Collectibles
	local coins: { [string]: Vector3 } = {}
	local rings: { [string]: Vector3 } = {}
	local coinList: { Collectible } = {}
	local ringList: { Collectible } = {}
	local span = c.EndFraction - c.StartFraction
	for row = 1, c.CoinRows do
		local p0 = c.StartFraction + span * (row - 0.5) / c.CoinRows
		local z = rng:NextNumber(-c.CoinLateral, c.CoinLateral)
		for k = 1, c.CoinsPerRow do
			local p = p0 + (k - (c.CoinsPerRow + 1) / 2) * c.CoinRowSpacing
			local x, y = Formulas.Trajectory(p, startPosition.X, endX, startPosition.Y, endY, height)
			local id = "c" .. row .. "_" .. k
			local pos = Vector3.new(x, y, z)
			coins[id] = pos
			table.insert(coinList, { Id = id, Position = pos })
		end
	end
	for index = 1, c.Rings do
		local p = c.StartFraction + span * index / (c.Rings + 1)
		local x, y = Formulas.Trajectory(p, startPosition.X, endX, startPosition.Y, endY, height)
		local id = "r" .. index
		local pos = Vector3.new(x, y, rng:NextNumber(-c.RingLateral, c.RingLateral))
		rings[id] = pos
		table.insert(ringList, { Id = id, Position = pos })
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
		CoinValue = Registry.Economy.IncomePerSecond(session) * c.CoinValueSeconds,
		Samples = {},
		Finished = false,
		SuperJump = superJump,
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
		PierEndX = World.PierEndX,
		Tier = tier,
		Coins = coinList,
		Rings = ringList,
		CoinValue = flight.CoinValue,
		SuperJump = superJump,
	})
	effectEvent:FireAllClients("Takeoff", { UserId = player.UserId, Tier = tier, Slippers = data.EquippedSlippers })

	-- pojistka: když klient nenahlásí dopad, server skok dokončí sám
	local maxTime = duration + Jump.Flight.ExtraGlideMax + 6
	task.delay(maxTime, function()
		if session.Flight == flight and not flight.Finished then
			JumpService.Finish(session, flight, {}, {})
		end
	end)
end

function JumpService.Finish(session: Session, flight: Flight, coinIds: { string }, ringIds: { string })
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

	local distance = math.min(flight.BaseDistance * (1 + c.RingBonus * ringCount), flight.Cap)
	local reachedGift = distance >= World.GiftDistance
	if reachedGift then
		distance = World.GiftDistance
	end
	distance = math.floor(distance)

	-- XP, peníze za mince
	local xp = Formulas.XPForJump(distance)
	local coinMoney = math.floor(coinCount * flight.CoinValue)
	Registry.Economy.AddMoney(session, coinMoney)

	-- předmět z vody (první skok je vždy Uncommon)
	local forced: string? = nil
	if data.TotalJumps == 0 then
		forced = Tutorial.FirstItemRarity
	end
	local item, placement, isNew
	if not reachedGift then
		item, placement, isNew = Registry.Items.Give(session, Registry.Items.Roll(distance, forced))
	end

	data.TotalJumps += 1
	local personalRecord = distance > data.BestJump
	if personalRecord then
		data.BestJump = distance
	end
	Registry.Leaderboard.OnJump(session, distance)
	Registry.Level.AddXP(session, xp)
	Registry.Tutorial.OnJumped(session)

	local cfg = item and Catalog.Item(item.Id)
	jumpResultEvent:FireClient(player, {
		FlightId = flight.Id,
		Distance = distance,
		Tier = flight.Tier,
		Coins = coinCount,
		CoinMoney = coinMoney,
		Rings = ringCount,
		Item = if item then { Id = item.Id, Uid = item.Uid, Income = if cfg then cfg.Income else 0 } else nil,
		Placement = placement,
		IsNew = isNew,
		XP = xp,
		PersonalRecord = personalRecord,
		ReachedGift = reachedGift,
	})
	effectEvent:FireAllClients("Splash", { UserId = player.UserId, Position = Vector3.new(World.PierEndX + distance, World.WaterY, 0), Gift = reachedGift })

	if reachedGift then
		Registry.Rebirth.OnGiftReached(session)
	end

	session.Returning = true
	Registry.Avatar.SetFlightEffects(session, false)
	task.delay(if reachedGift then Jump.GiftReturnDelay else Jump.ReturnDelay, function()
		if session.Flight == flight then
			session.Flight = nil
			Registry.Player.ReturnToBeach(session)
			Registry.Player.MarkDirty(session)
		end
	end)
end

function JumpService.Landed(player: Player, flightId: unknown, coinIds: unknown, ringIds: unknown)
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
	local rings = sanitize(ringIds, Jump.Collectibles.Rings)
	-- klient nesmí přistát dřív, než by let doopravdy trval
	local remaining = flight.Duration * 0.9 - (os.clock() - flight.StartClock)
	if remaining > 0 then
		task.delay(remaining, function()
			if session.Flight == flight then
				JumpService.Finish(session, flight, coins, rings)
			end
		end)
	else
		JumpService.Finish(session, flight, coins, rings)
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

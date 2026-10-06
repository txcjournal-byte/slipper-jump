--!strict
-- Události (po vydání): násobič příjmu v daném čase + sezónní věci.
-- Start/End = os.time() v UTC (např. os.time({year=2026, month=12, day=24, hour=0})).
-- WeekendDoubleMoney = každý víkend (sobota a neděle UTC) automaticky 2× peníze.

export type Event = { Name: string, Start: number, End: number, IncomeMultiplier: number }

local Scheduled: { Event } = {
	-- { Name = "Summer Splash", Start = os.time({year = 2027, month = 7, day = 1, hour = 0}), End = os.time({year = 2027, month = 7, day = 8, hour = 0}), IncomeMultiplier = 2 },
}

-- Události na serveru každých pár minut (aby se pořád něco dělo)
export type ServerEventKind =
	"GoldenRings"
	| "CoinStorm"
	| "TreasureTide"
	| "SharkHoliday"
	| "MegaJump"
	| "JumpContest"
	| "DoubleXP"
	| "RainbowRings"
	| "DiamondRush"
	| "BalloonParty"
-- Duration = vlastní délka události (jinak ServerEventDuration)
export type ServerEvent = { Kind: ServerEventKind, Name: string, Description: string, Color: Color3, Duration: number? }
-- Odměna v soutěži o nejdelší skok ($ se násobí levelem ÷ Quests.MoneyLevelDivisor, min. 1×)
export type ContestPrize = { Money: number, Spins: number? }

local Rotation: { ServerEvent } = {
	{ Kind = "GoldenRings", Name = "GOLDEN RINGS", Description = "Rings give double distance!", Color = Color3.fromRGB(255, 200, 40) },
	{ Kind = "CoinStorm", Name = "COIN STORM", Description = "Coins in the air are worth 3x!", Color = Color3.fromRGB(255, 160, 40) },
	{ Kind = "TreasureTide", Name = "TREASURE TIDE", Description = "Rarer items from the water!", Color = Color3.fromRGB(170, 90, 255) },
	{ Kind = "SharkHoliday", Name = "SHARK HOLIDAY", Description = "No sharks or sea monsters! Swim back safely!", Color = Color3.fromRGB(60, 170, 255) },
	{ Kind = "MegaJump", Name = "MEGA JUMP", Description = "Everyone jumps 25% farther!", Color = Color3.fromRGB(80, 220, 120) },
	{ Kind = "JumpContest", Name = "JUMP CONTEST", Description = "Longest jump wins prizes!", Color = Color3.fromRGB(255, 110, 150), Duration = 120 },
	{ Kind = "DoubleXP", Name = "DOUBLE XP", Description = "2x XP from every jump!", Color = Color3.fromRGB(80, 200, 255) },
	{ Kind = "RainbowRings", Name = "RAINBOW RINGS", Description = "Lots more golden rings in the air!", Color = Color3.fromRGB(255, 120, 220) },
	{ Kind = "DiamondRush", Name = "DIAMOND RUSH", Description = "More diamonds in the air - and rarer ones!", Color = Color3.fromRGB(120, 220, 255) },
	{ Kind = "BalloonParty", Name = "BALLOON PARTY", Description = "Treasure balloons on every jump! Hit them for free items!", Color = Color3.fromRGB(255, 90, 120) },
}

-- Soutěž: 1., 2. a 3. místo
local ContestPrizes: { ContestPrize } = {
	{ Money = 5_000, Spins = 2 },
	{ Money = 2_500 },
	{ Money = 1_000 },
}

-- LEGEND RACE: všichni na serveru skočí naráz – kdo doletí nejdál, je do příštího závodu LEGENDA
-- (korunka nad hlavou). Počítá se první skok odstartovaný v okně po GO.
local LegendRace = {
	FirstDelay = 150, -- první závod pár minut po startu serveru
	Interval = 7 * 60, -- sekund mezi závody
	Warning = 30, -- odpočet před startem
	Window = 20, -- jak dlouho po GO se dá odstartovat závodní skok
	Grace = 25, -- max. čekání na dopad posledních závodníků
	MinPlayers = 2, -- závod jen když je na serveru aspoň tolik hráčů
	ResultsTime = 10, -- jak dlouho visí výsledky
	Prizes = { -- 1., 2., 3. místo ($ se násobí levelem ÷ Quests.MoneyLevelDivisor, min. 1×)
		{ Money = 8_000, Spins = 3 },
		{ Money = 4_000, Spins = 1 },
		{ Money = 2_000 },
	} :: { ContestPrize },
	ParticipationMoney = 500, -- ostatní závodníci dostanou aspoň něco
	Title = "👑 LEGEND",
}

return {
	ServerEvents = Rotation,
	LegendRace = LegendRace,
	ServerEventInterval = 5 * 60, -- sekund mezi událostmi
	ServerEventDuration = 90, -- jak dlouho událost běží
	ServerEventWarning = 15, -- oznámení předem
	GoldenRingsMultiplier = 2,
	CoinStormMultiplier = 3,
	MegaJumpBonus = 0.25,
	DoubleXPMultiplier = 2,
	RainbowRingsMultiplier = 2, -- kolikrát víc kruhů při skoku
	ContestPrizes = ContestPrizes,
	ContestTop = 3, -- kolik míst ukazuje živá tabulka v HUD
	ContestGrace = 15, -- max. sekund po konci soutěže, než dopadnou poslední skoky
	WeekendDoubleMoney = false,
	WeekendMultiplier = 2,
	Scheduled = Scheduled,
	-- Sezónní pantofle a předměty: Id, které se objeví jen během události (přidejte je i do Slippers/Items).
	SeasonalItems = {} :: { [string]: { string } },
}

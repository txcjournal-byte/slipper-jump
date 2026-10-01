--!strict
-- Události (po vydání): násobič příjmu v daném čase + sezónní věci.
-- Start/End = os.time() v UTC (např. os.time({year=2026, month=12, day=24, hour=0})).
-- WeekendDoubleMoney = každý víkend (sobota a neděle UTC) automaticky 2× peníze.

export type Event = { Name: string, Start: number, End: number, IncomeMultiplier: number }

local Scheduled: { Event } = {
	-- { Name = "Summer Splash", Start = os.time({year = 2027, month = 7, day = 1, hour = 0}), End = os.time({year = 2027, month = 7, day = 8, hour = 0}), IncomeMultiplier = 2 },
}

-- Události na serveru každých pár minut (aby se pořád něco dělo)
export type ServerEventKind = "GoldenRings" | "CoinStorm" | "TreasureTide" | "SharkHoliday" | "MegaJump"
export type ServerEvent = { Kind: ServerEventKind, Name: string, Description: string, Color: Color3 }

local Rotation: { ServerEvent } = {
	{ Kind = "GoldenRings", Name = "GOLDEN RINGS", Description = "Rings give double distance!", Color = Color3.fromRGB(255, 200, 40) },
	{ Kind = "CoinStorm", Name = "COIN STORM", Description = "Coins in the air are worth 3x!", Color = Color3.fromRGB(255, 160, 40) },
	{ Kind = "TreasureTide", Name = "TREASURE TIDE", Description = "Rarer items from the water!", Color = Color3.fromRGB(170, 90, 255) },
	{ Kind = "SharkHoliday", Name = "SHARK HOLIDAY", Description = "No sharks! Swim back safely!", Color = Color3.fromRGB(60, 170, 255) },
	{ Kind = "MegaJump", Name = "MEGA JUMP", Description = "Everyone jumps 25% farther!", Color = Color3.fromRGB(80, 220, 120) },
}

return {
	ServerEvents = Rotation,
	ServerEventInterval = 5 * 60, -- sekund mezi událostmi
	ServerEventDuration = 90, -- jak dlouho událost běží
	ServerEventWarning = 15, -- oznámení předem
	GoldenRingsMultiplier = 2,
	CoinStormMultiplier = 3,
	MegaJumpBonus = 0.25,
	WeekendDoubleMoney = false,
	WeekendMultiplier = 2,
	Scheduled = Scheduled,
	-- Sezónní pantofle a předměty: Id, které se objeví jen během události (přidejte je i do Slippers/Items).
	SeasonalItems = {} :: { [string]: { string } },
}

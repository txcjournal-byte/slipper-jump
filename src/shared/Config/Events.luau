--!strict
-- Události (po vydání): násobič příjmu v daném čase + sezónní věci.
-- Start/End = os.time() v UTC (např. os.time({year=2026, month=12, day=24, hour=0})).
-- WeekendDoubleMoney = každý víkend (sobota a neděle UTC) automaticky 2× peníze.

export type Event = { Name: string, Start: number, End: number, IncomeMultiplier: number }

local Scheduled: { Event } = {
	-- { Name = "Summer Splash", Start = os.time({year = 2027, month = 7, day = 1, hour = 0}), End = os.time({year = 2027, month = 7, day = 8, hour = 0}), IncomeMultiplier = 2 },
}

return {
	WeekendDoubleMoney = false,
	WeekendMultiplier = 2,
	Scheduled = Scheduled,
	-- Sezónní pantofle a předměty: Id, které se objeví jen během události (přidejte je i do Slippers/Items).
	SeasonalItems = {} :: { [string]: { string } },
}

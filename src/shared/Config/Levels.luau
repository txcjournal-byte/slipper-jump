--!strict
-- Levely: XP za skok = XPBase + floor(vzdálenost ÷ XPDistanceDivisor).
-- XP na další level = XPPerLevel × aktuální level. Odměna za level = MoneyPerLevel × nový level.

export type Milestone = {
	Spins: number?,
	Slots: number?,
	Hat: string?,
	Rarity: string?, -- zaručený předmět
	Title: string?,
}

local Milestones: { [number]: Milestone } = {
	[5] = { Spins = 1 },
	[10] = { Slots = 1 },
	[15] = { Hat = "CaptainHat" },
	[20] = { Slots = 1, Spins = 2 },
	[25] = { Rarity = "Epic" },
	[30] = { Slots = 1 },
	[35] = { Hat = "PirateHat" },
	[40] = { Slots = 2 },
	[45] = { Rarity = "Legendary" },
	[50] = { Title = "Pier Legend", Slots = 1 },
}

return {
	MaxLevel = 50,
	XPBase = 25, -- level 2 po ~4 skocích (dřív 10 skoků)
	XPDistanceDivisor = 200,
	XPPerLevel = 100,
	MoneyPerLevel = 100,
	Milestones = Milestones,
}

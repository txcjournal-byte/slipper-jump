--!strict
-- Barevné diamanty ve vzduchu (mezi kruhy). Objeví se od levelu MinLevel nebo po MinJumps skocích.
-- Každý diamant dá peníze (= příjem domečku za MoneySeconds sekund, aspoň MinIncome za sekundu)
-- a vzácnější i bonusy: XP navíc, štít proti jednomu nárazu ve slalomu, dvojnásobek mincí,
-- delší skok. Sedm barev (zelený, tyrkysový, modrý, červený, fialový, zlatý, duhový).
-- Čím vyšší level, tím víc diamantů a tím častěji ty vzácné.

export type DiamondType = {
	Key: string,
	Name: string,
	Color: Color3,
	Weight: number, -- šance (relativní)
	MinLevel: number, -- od kterého levelu se může objevit
	MoneySeconds: number,
	XPBonus: number?, -- +X × XP za skok
	Shield: number?, -- štít proti nárazům ve slalomu (počet)
	CoinMultiplier: number?, -- násobí peníze za mince v tomto skoku
	DistanceBonus: number?, -- +X ke vzdálenosti (jako kruhy)
	Text: string, -- co hráč uvidí po sebrání
}

local Types: { DiamondType } = {
	{ Key = "Green", Name = "Emerald", Color = Color3.fromRGB(40, 235, 100), Weight = 50, MinLevel = 1, MoneySeconds = 15, Text = "CASH!" },
	{ Key = "Aqua", Name = "Aquamarine", Color = Color3.fromRGB(40, 235, 235), Weight = 30, MinLevel = 1, MoneySeconds = 20, Text = "CASH!" },
	{ Key = "Blue", Name = "Sapphire", Color = Color3.fromRGB(50, 120, 255), Weight = 24, MinLevel = 1, MoneySeconds = 30, XPBonus = 0.5, Text = "CASH + XP!" },
	{ Key = "Ruby", Name = "Ruby", Color = Color3.fromRGB(255, 40, 70), Weight = 14, MinLevel = 3, MoneySeconds = 40, DistanceBonus = 0.05, Text = "+5% DISTANCE!" },
	{ Key = "Purple", Name = "Amethyst", Color = Color3.fromRGB(190, 80, 255), Weight = 10, MinLevel = 5, MoneySeconds = 55, Shield = 1, Text = "SLALOM SHIELD!" },
	{ Key = "Gold", Name = "Golden Diamond", Color = Color3.fromRGB(255, 205, 40), Weight = 3.5, MinLevel = 8, MoneySeconds = 110, CoinMultiplier = 2, Text = "DOUBLE COINS!" },
	{ Key = "Rainbow", Name = "Rainbow Diamond", Color = Color3.fromRGB(255, 120, 220), Weight = 0.8, MinLevel = 12, MoneySeconds = 280, XPBonus = 1, Shield = 1, CoinMultiplier = 2, DistanceBonus = 0.1, Text = "EVERYTHING x2!" },
}

local byKey: { [string]: DiamondType } = {}
for _, t in Types do
	byKey[t.Key] = t
end

return {
	Types = Types,
	ByKey = byKey,
	MinLevel = 2, -- diamanty od levelu 2 …
	MinJumps = 3, -- … nebo po 3 skocích (co nastane dřív)
	BaseCount = 1, -- diamantů ve skoku na začátku
	LevelsPerExtra = 6, -- +1 diamant každých 6 levelů (level 6 = 2, level 12 = 3 …)
	MaxCount = 5,
	RareBoostPerLevel = 0.03, -- vzácnější diamanty (Purple+) jsou s každým levelem o 3 % častější
	MinIncome = 5, -- peníze za diamant počítají aspoň s tímhle příjmem za sekundu
	Radius = 10, -- jak blízko musí hráč proletět
	Lateral = 26, -- jak daleko do strany od středu dráhy
	-- události a pass: Diamond Rush (+2 diamanty, vzácné 3× častěji), Treasure Hunter (+1, vzácné 2×)
	RushExtra = 2,
	RushRareBoost = 3,
	HunterExtra = 1,
	HunterRareBoost = 2,
	-- Poklad na balónku: občas visí ve vzduchu balónek s truhlou – kdo ho trefí, dostane předmět navíc
	-- (hned do domečku, o ten už nepřijde) a peníze.
	Balloon = {
		MinLevel = 4,
		Chance = 0.25, -- šance v jednom skoku
		HunterChance = 0.45, -- s passem Treasure Hunter
		PartyCount = 2, -- během události Balloon Party (pokaždé)
		Radius = 8,
		Lateral = 18,
		MoneySeconds = 60,
		ZoneShift = 1, -- předmět z balónku je o zónu vzácnější
	},
}

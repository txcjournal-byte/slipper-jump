--!strict
-- Denní úkoly (3 denně) a odměna za sérii přihlášení.
-- Odměny v $ se násobí levelem ÷ 5 (min. 1×), stejně jako u kola štěstí.

export type QuestKind = "Jumps" | "Coins" | "Rings" | "Perfects" | "Escapes" | "Sells" | "Spins" | "Distance" | "PerfectStreak" | "EventJumps"
export type QuestTemplate = { Kind: QuestKind, Text: string, Goal: number, Money: number, Spins: number? }

local Pool: { QuestTemplate } = {
	{ Kind = "Jumps", Text = "Jump %d times", Goal = 15, Money = 1_500 },
	{ Kind = "Jumps", Text = "Jump %d times", Goal = 40, Money = 4_000, Spins = 1 },
	{ Kind = "Coins", Text = "Collect %d coins in the air", Goal = 50, Money = 2_500 },
	{ Kind = "Rings", Text = "Fly through %d golden rings", Goal = 10, Money = 3_000 },
	{ Kind = "Perfects", Text = "Get %d PERFECT jumps", Goal = 8, Money = 3_000 },
	{ Kind = "Escapes", Text = "Escape sea creatures %d times", Goal = 5, Money = 3_500, Spins = 1 },
	{ Kind = "Sells", Text = "Sell %d items", Goal = 3, Money = 2_000 },
	{ Kind = "Spins", Text = "Spin the Lucky Wheel %d times", Goal = 1, Money = 1_000 },
	{ Kind = "Distance", Text = "Jump %d studs in total", Goal = 5_000, Money = 2_500 },
	-- nové úkoly přidávat jen na konec (uložená data odkazují na pořadí v seznamu)
	{ Kind = "PerfectStreak", Text = "Get a PERFECT streak of %d", Goal = 3, Money = 3_500, Spins = 1 },
	{ Kind = "EventJumps", Text = "Jump during an event %d times", Goal = 10, Money = 3_000 },
}

return {
	Pool = Pool,
	PerDay = 3,
	-- série přihlášení: den → odměna (poslední se opakuje)
	Streak = {
		{ Money = 500 },
		{ Money = 1_000 },
		{ Money = 1_500, Spins = 1 },
		{ Money = 2_500 },
		{ Money = 4_000, Spins = 1 },
		{ Money = 6_000 },
		{ Money = 10_000, Spins = 3, LuckMinutes = 15 }, -- 7. den: i Lucky Potion zdarma
	},
	MoneyLevelDivisor = 5,
}

--!strict
-- Denní kolo štěstí. Weight = šance v procentech (musí být vidět u kola, tlačítko "i").
-- Peněžní odměny se násobí levelem ÷ MoneyLevelDivisor (minimálně 1×).

export type Reward = { Money: number?, Rarity: string?, BoostMinutes: number? }
export type Segment = { Label: string, Weight: number, Color: Color3, Reward: Reward }

local Segments: { Segment } = {
	{ Label = "$500", Weight = 25, Color = Color3.fromRGB(255, 205, 50), Reward = { Money = 500 } },
	{ Label = "$2,000", Weight = 20, Color = Color3.fromRGB(80, 200, 120), Reward = { Money = 2_000 } },
	{ Label = "Uncommon Item", Weight = 18, Color = Color3.fromRGB(60, 190, 255), Reward = { Rarity = "Uncommon" } },
	{ Label = "Rare Item", Weight = 15, Color = Color3.fromRGB(80, 110, 255), Reward = { Rarity = "Rare" } },
	{ Label = "2x Money (15 min)", Weight = 10, Color = Color3.fromRGB(255, 120, 60), Reward = { BoostMinutes = 15 } },
	{ Label = "$10,000", Weight = 7, Color = Color3.fromRGB(255, 90, 150), Reward = { Money = 10_000 } },
	{ Label = "Epic Item", Weight = 4, Color = Color3.fromRGB(170, 80, 255), Reward = { Rarity = "Epic" } },
	{ Label = "Legendary Item", Weight = 1, Color = Color3.fromRGB(255, 170, 20), Reward = { Rarity = "Legendary" } },
}

return {
	Segments = Segments,
	Cooldown = 24 * 60 * 60, -- sekund mezi denními točeními
	DailySpins = 1,
	VipDailySpins = 1, -- VIP navíc
	MoneyLevelDivisor = 5,
	SpinTime = 4, -- délka animace
}

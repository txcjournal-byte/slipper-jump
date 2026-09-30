--!strict
-- Obří dárek na 100 000 studech a znovuzrození.

return {
	FirstMoney = 1_000_000,
	FirstItem = "GoldenSplash",
	FirstTitle = "Pier Master",
	FirstHat = "GoldenBowHat",
	RepeatMoney = 100_000,
	RepeatRarity = "Legendary",
	-- Barva dárku podle počtu znovuzrození (poslední se opakuje)
	Colors = {
		Color3.fromRGB(255, 200, 40), -- zlatá
		Color3.fromRGB(200, 210, 225), -- stříbrná
		Color3.fromRGB(255, 110, 200), -- duhová (růžová základ)
		Color3.fromRGB(90, 230, 255), -- diamantová
		Color3.fromRGB(170, 90, 255), -- galaktická
		Color3.fromRGB(60, 60, 70), -- obsidiánová
	},
	RainbowFromRebirth = 2,
	-- Titulek podle počtu znovuzrození (poslední se opakuje s číslem)
	RebirthTitles = { "Reborn Jumper", "Splash Hero", "Wave Rider", "Ocean Star", "Sea Legend", "Slipper King" },
}

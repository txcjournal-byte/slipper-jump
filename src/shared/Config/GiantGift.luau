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
	-- Dárkové ostrovy cestou k Obřímu dárku (mezicíle). Kdo k ostrovu ještě nedoskočil, přistane na něm
	-- (skok se u něj zastaví) a dostane odměnu. Po znovuzrození se dají získat znovu.
	Islands = {
		{
			Key = "Bronze",
			Distance = 10_000,
			Name = "BRONZE GIFT",
			Color = Color3.fromRGB(215, 135, 60),
			Ribbon = Color3.fromRGB(60, 160, 255),
			Money = 250_000,
			Rarity = "Epic",
			Hat = "PropellerCap",
			Title = nil,
		},
		{
			Key = "Silver",
			Distance = 40_000,
			Name = "SILVER GIFT",
			Color = Color3.fromRGB(200, 210, 225),
			Ribbon = Color3.fromRGB(170, 90, 255),
			Money = 3_000_000,
			Rarity = "Legendary",
			Hat = nil,
			Title = "Island Hopper",
		},
	} :: { { Key: string, Distance: number, Name: string, Color: Color3, Ribbon: Color3, Money: number, Rarity: string, Hat: string?, Title: string? } },
	-- Titulek podle počtu znovuzrození (poslední se opakuje s číslem)
	RebirthTitles = { "Reborn Jumper", "Splash Hero", "Wave Rider", "Ocean Star", "Sea Legend", "Slipper King" },
}

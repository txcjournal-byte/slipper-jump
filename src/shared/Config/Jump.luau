--!strict
-- Vše kolem skoku: ukazatel síly, let, mince, kruhy, limity.

return {
	BaseDistance = 100, -- studů s Basic Black Slippers bez bonusů
	MaxDistance = 100_000, -- dál už je jen dárek
	MaxDistanceWithoutBest = 95_000, -- limit bez nejlepších pantoflí
	BestSlippersId = "RoyalDiamondSlippers",
	RandomSpread = 0.05, -- ± 5 % náhody

	Meter = {
		Period = 1.1, -- sekundy z dola nahoru
		TutorialPeriod = 2.2, -- pomalejší ukazatel při prvním skoku
		GoodMin = 0.72, -- žlutá zóna od
		PerfectMin = 0.92, -- zelená zóna od (až do 1.0)
		GoodBonus = 0.10,
		PerfectBonus = 0.25,
		Tolerance = 0.3, -- jak moc se smí hodnota klienta lišit od odhadu serveru
		MaxHoldTime = 20,
	},

	Flight = {
		MinTime = 3,
		MaxTime = 10,
		HeightFactor = 0.18, -- výška paraboly = vzdálenost × faktor
		MinHeight = 25,
		MaxHeight = 450,
		CorridorHalfWidth = 50, -- koridor mezi bójkami
		SteerLimit = 44, -- jak daleko do strany může hráč uhnout
		SteerSpeed = 48, -- studů za sekundu
		ExtraGlideMin = 0.8, -- dolet díky kruhům: minimální čas
		ExtraGlideMax = 2.2,
		ExtraGlideHeight = 0.25, -- výška doletu = délka doletu × faktor
		ExtraGlideMaxHeight = 60,
		CameraFov = 70,
		CameraFlightFov = 95,
	},

	Collectibles = {
		CoinRows = 6,
		CoinsPerRow = 5,
		CoinRowSpacing = 0.012, -- rozestup mincí v řadě (podíl vzdálenosti)
		CoinRadius = 6,
		CoinLateral = 36, -- mince až takhle daleko do strany
		CoinValueSeconds = 1, -- mince = příjem domečku za X sekund
		Rings = 4,
		RingRadius = 10,
		RingLateral = 30,
		RingBonus = 0.05, -- každý kruh +5 % ke vzdálenosti
		ServerTolerance = 7, -- tolerance serverové kontroly (studů)
		StartFraction = 0.12,
		EndFraction = 0.88,
	},

	JumpZoneLength = 22, -- posledních X studů mola, kde jde skákat
	SuperJumpBonus = 0.20,
	ReturnDelay = 2.6, -- sekund po dopadu, než se hráč vrátí na pláž
	GiftReturnDelay = 7,
	Cooldown = 1.5,
}

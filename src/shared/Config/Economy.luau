--!strict
-- Peníze a obecná pravidla ekonomiky.

return {
	StartingMoney = 0,
	SellMultiplier = 10, -- prodejní cena = 10 × příjem/s
	RebirthIncomeBonus = 0.5, -- +50 % příjmu za každé znovuzrození
	OfflineMaxSeconds = 2 * 60 * 60,
	OfflineMinSeconds = 60,
	GiftsPerDay = 20,
	GiftOfferTimeout = 20,
	SaveInterval = 60,
	IncomeTick = 1,
}

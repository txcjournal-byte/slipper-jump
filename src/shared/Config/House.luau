--!strict
-- Domečky na pláži (8 kusů, 4 vlevo a 4 vpravo od cesty na molo).

return {
	Count = 8,
	BaseSlots = 10,
	MaxSlots = 22, -- 10 + 6 z levelů + 5 z game passu (+1 rezerva)
	SlotsPerSide = 11,
	Width = 32,
	Length = 118,
	WallHeight = 15,
	Gap = 5,
	PickHoldTime = 1,
	-- Úrovně domečku: domek se vylepší sám, když hráč splní podmínku (level NEBO dárkový ostrov).
	-- Dosažená úroveň zůstává i po rebirthu (Data.HouseTier). Gift = klíč dárkového ostrova,
	-- Giant = otevřel Obří dárek. Vzhled staví server (HouseTiers.luau).
	Tiers = {
		{ Name = "Beach Shack", Hint = "Your first little shack!" },
		{ Name = "Cottage", MinLevel = 5, Hint = "Reach level 5" },
		{ Name = "Beach House", MinLevel = 15, Gift = "Bronze", Hint = "Reach the Bronze Gift island or level 15" },
		{ Name = "Villa", MinLevel = 30, Gift = "Silver", Hint = "Reach the Silver Gift island or level 30" },
		{ Name = "Palace", Giant = true, Hint = "Open the GIANT GIFT" },
	} :: { { Name: string, MinLevel: number?, Gift: string?, Giant: boolean?, Hint: string } },
	Names = { "Sunny", "Coral", "Ocean", "Breeze", "Shell", "Wave", "Tropical", "Seaside" },
	Colors = {
		Color3.fromRGB(255, 150, 190),
		Color3.fromRGB(255, 165, 110),
		Color3.fromRGB(100, 180, 255),
		Color3.fromRGB(120, 225, 180),
		Color3.fromRGB(255, 220, 90),
		Color3.fromRGB(175, 130, 255),
		Color3.fromRGB(255, 120, 160),
		Color3.fromRGB(90, 160, 240),
	},
}

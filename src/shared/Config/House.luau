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

--!strict
-- Rozměry mapy. Osa X = směr skoku. Střed světa (0,0,0) je uprostřed vody (50 000 studů),
-- aby nejvzdálenější bod nebyl dál než 50 000 studů od středu (přesnost float).

local PierEndX = -50_000

return {
	PierEndX = PierEndX, -- konec mola = vzdálenost 0
	PierLength = 150,
	PierWidth = 14,
	PierDeckY = 5, -- horní plocha mola
	WaterY = 0, -- hladina
	SandY = 3, -- horní plocha písku
	BeachFrontX = PierEndX - 150, -- kde končí písek a začíná voda
	BeachBackX = PierEndX - 550,
	BeachHalfWidth = 420,
	SpawnX = PierEndX - 458, -- začátek cesty (domečky začínají 40 studů za ním, zadní vchody 150 studů před molem)
	ReturnX = PierEndX - 150 - 45, -- po skoku se hráč objeví kousek před molem
	WalkSpeed = 26, -- rychlejší chůze po pláži (Roblox výchozí je 16)
	TeleportCooldown = 2,
	PathHalfWidth = 11,
	GiftDistance = 100_000,
	GiftIslandRadius = 190,
	GiftHeight = 300,
	WaterHalfWidth = 1_000,
	TerrainWaterLength = 2_400, -- prvních X studů je skutečná Roblox voda (vlny, odlesky), dál ploché díly
	TerrainWaterDepth = 10,
	-- Značky vzdálenosti: { do, krok }
	MarkerRanges = {
		{ UpTo = 1_000, Step = 100 },
		{ UpTo = 10_000, Step = 500 },
		{ UpTo = 20_000, Step = 1_000 },
		{ UpTo = 100_000, Step = 10_000 },
	},
	-- Rozestup bójek podél koridoru
	BuoyRanges = {
		{ UpTo = 1_000, Step = 25 },
		{ UpTo = 10_000, Step = 250 },
		{ UpTo = 100_000, Step = 1_000 },
	},
	-- Barevné zóny vody (od světle tyrkysové po tmavě modrou)
	WaterZones = {
		{ UpTo = 1_000, Color = Color3.fromRGB(64, 224, 230) },
		{ UpTo = 5_000, Color = Color3.fromRGB(40, 196, 225) },
		{ UpTo = 20_000, Color = Color3.fromRGB(28, 150, 215) },
		{ UpTo = 60_000, Color = Color3.fromRGB(22, 105, 190) },
		{ UpTo = 102_048, Color = Color3.fromRGB(16, 60, 150) },
	},
	HorizonGiftDistance = 1_600, -- zmenšená kopie dárku na obzoru (od kamery)
	RealGiftShowDistance = 2_500, -- skutečný dárek se ukáže, když je hráč blíž
	OutOfBoundsX = PierEndX + 3, -- kdo se dostane dál bez skoku, vrátí se na pláž
}

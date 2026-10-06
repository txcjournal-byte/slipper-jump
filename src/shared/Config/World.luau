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
	-- (cedule jsou vidět pořád, až k dárku – viz MapBuilder, model je Persistent)
	MarkerRanges = {
		{ UpTo = 1_000, Step = 100 },
		{ UpTo = 10_000, Step = 500 },
		{ UpTo = 30_000, Step = 1_000 },
		{ UpTo = 99_000, Step = 2_500 },
	},
	-- Rozestup bójek podél koridoru
	BuoyRanges = {
		{ UpTo = 1_000, Step = 25 },
		{ UpTo = 10_000, Step = 250 },
		{ UpTo = 100_000, Step = 1_000 },
	},
	-- Barevné zóny vody (od světle tyrkysové po tmavě modrou)
	WaterZones = {
		-- paleta: mělká #67E2D9 / #2CC4BF → hluboká #3FB0FF / #0082D6 / #00508F
		{ UpTo = 1_000, Color = Color3.fromRGB(44, 196, 191) },
		{ UpTo = 5_000, Color = Color3.fromRGB(63, 176, 255) },
		{ UpTo = 20_000, Color = Color3.fromRGB(0, 130, 214) },
		{ UpTo = 60_000, Color = Color3.fromRGB(0, 104, 178) },
		{ UpTo = 102_048, Color = Color3.fromRGB(0, 80, 143) },
	},
	HorizonGiftDistance = 260, -- zmenšená kopie dárku na obzoru (od kamery; na nízké kvalitě grafiky Roblox dál než ~300 studů nekreslí)
	RealGiftShowDistance = 280, -- skutečný dárek se ukáže, když je hráč blíž (do té doby kopie na obzoru)
	OutOfBoundsX = PierEndX + 3, -- kdo se dostane dál bez skoku, vrátí se na pláž
}

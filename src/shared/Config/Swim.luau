--!strict
-- Plavání zpět k záchrannému voru, zatímco hráče honí žralok.
-- Doplave → bonus. Žralok ho chytí → jen přijde o bonus (předmět si nechá).

export type Upgrade = { Id: string, Name: string, Speed: number, Price: number, Color: Color3 }

local Upgrades: { Upgrade } = {
	{ Id = "Flippers", Name = "Flippers", Speed = 19, Price = 1_000, Color = Color3.fromRGB(255, 200, 40) },
	{ Id = "SnorkelSet", Name = "Snorkel Set", Speed = 22, Price = 25_000, Color = Color3.fromRGB(60, 170, 255) },
	{ Id = "ProFins", Name = "Pro Fins", Speed = 26, Price = 300_000, Color = Color3.fromRGB(80, 210, 120) },
	{ Id = "MermaidTail", Name = "Mermaid Tail", Speed = 30, Price = 3_000_000, Color = Color3.fromRGB(80, 220, 200) },
	{ Id = "JetFins", Name = "Jet Fins", Speed = 35, Price = 20_000_000, Color = Color3.fromRGB(255, 120, 60) },
	{ Id = "TurboPropeller", Name = "Turbo Propeller", Speed = 41, Price = 80_000_000, Color = Color3.fromRGB(170, 90, 255) },
}

-- Kdo hráče honí: čím dál skočí, tím strašidelnější (a rychlejší) tvor.
-- Key = který model klient postaví, Speed = studů za sekundu, Reach = o kolik dál "dosáhne"
-- (přičte se k CatchDistance – chapadla a velké tlamy), Count = kolik tvorů je vidět.
-- Ladění: vor je 100 studů daleko, tvor vyrazí po 2 s. Hráč uteče, když
-- (100 / rychlost hráče − 2) × Speed < 100 − CatchDistance − Reach. Nejnižší potřebná rychlost:
--   Shark 18 → 13,4 (stačí základ 16)            Whale 24 → 16,5 (Flippers 19)
--   Two Sharks 29 → 18,5 (Flippers 19, Snorkel 22 v klidu)
--   Giant Octopus 36 → 21,3 (Snorkel Set 22)      Kraken 42 → 23,3 (Pro Fins 26 / Snorkel + Turbo Fins)
--   Megalodon 48 → 24,9 (Pro Fins 26, Mermaid Tail 30 v klidu)
-- (výpočet je bez zpoždění sítě; server navíc přičítá rezervu LagGrace, viz níže)
export type ChaserTier = {
	Key: string,
	MinDistance: number,
	Name: string,
	Speed: number,
	Reach: number,
	Count: number,
	Color: Color3,
	Warning: string,
	Caught: string,
}

local Chasers: { ChaserTier } = {
	{
		Key = "Shark",
		MinDistance = 0,
		Name = "SHARK",
		Speed = 18,
		Reach = 0,
		Count = 1,
		Color = Color3.fromRGB(255, 95, 90),
		Warning = "SHARK!!! SWIM FASTER!",
		Caught = "CHOMP! The shark got you!",
	},
	{
		Key = "Whale",
		MinDistance = 1_000,
		Name = "WHALE",
		Speed = 24,
		Reach = 0.5,
		Count = 1,
		Color = Color3.fromRGB(90, 170, 255),
		Warning = "WHALE!!! SWIM FASTER!",
		Caught = "GULP! The whale got you!",
	},
	{
		Key = "TwoSharks",
		MinDistance = 5_000,
		Name = "TWO SHARKS",
		Speed = 29,
		Reach = 0,
		Count = 2,
		Color = Color3.fromRGB(255, 120, 70),
		Warning = "TWO SHARKS!!! SWIM FASTER!",
		Caught = "CHOMP CHOMP! The sharks got you!",
	},
	{
		Key = "Octopus",
		MinDistance = 15_000,
		Name = "GIANT OCTOPUS",
		Speed = 36,
		Reach = 1.5,
		Count = 1,
		Color = Color3.fromRGB(200, 90, 255),
		Warning = "GIANT OCTOPUS!!! SWIM FASTER!",
		Caught = "SPLAT! The giant octopus got you!",
	},
	{
		Key = "Kraken",
		MinDistance = 35_000,
		Name = "KRAKEN",
		Speed = 42,
		Reach = 2,
		Count = 1,
		Color = Color3.fromRGB(40, 220, 190),
		Warning = "THE KRAKEN!!! SWIM FASTER!",
		Caught = "The Kraken got you!",
	},
	{
		Key = "Megalodon",
		MinDistance = 70_000,
		Name = "SEA MONSTER", -- poslední, nejstrašnější: obří mořská příšera
		Speed = 48,
		Reach = 1.5,
		Count = 1,
		Color = Color3.fromRGB(255, 60, 60),
		Warning = "SEA MONSTER!!! SWIM FOR YOUR LIFE!",
		Caught = "MEGA CHOMP! The Sea Monster got you!",
	},
}

-- ===== Slalomy na cestě zpět k voru (od levelu 2) =====
-- Přes dráhu vedou bariéry z bójek s jednou mezerou (branka). Kdo do bariéry narazí, zastaví se,
-- musí najet do mezery a ztrácí čas – pronásledovatel se blíží. Mezi brankami jsou překážky
-- (náraz = krátké omráčení a odhození zpět). Čím vyšší level, tím užší a pohyblivější branky
-- a víc překážek. Rozložení losuje server, klient ho postaví a hlídá nárazy.
-- Gap = šířka mezery, Offset = jak daleko od středu dráhy mezera může být,
-- Moving = kolik branek se hýbe do stran (Amp studů, Speed rad/s),
-- Obstacles = { druh = počet }: Rock (kámen), Jellyfish (medúza, pluje do stran),
-- Log (kláda, jezdí do stran), Puffer (ježík, nafukuje se).
export type SlalomTier = {
	MinLevel: number,
	Name: string,
	Color: Color3,
	Gates: number,
	Gap: number,
	Offset: number,
	Moving: number,
	MoveAmp: number,
	MoveSpeed: number,
	Obstacles: { [string]: number },
}

-- Názvy a barvy slalomu podle (efektivního) levelu – parametry se ale mění plynule s každým levelem
-- (Formulas.SlalomTier): víc branek, užší mezery, delší trať, pohyblivé branky a víc překážek.
local SlalomNames = {
	{ MinLevel = 2, Name = "MINI SLALOM", Color = Color3.fromRGB(90, 200, 255) },
	{ MinLevel = 7, Name = "BUOY SLALOM", Color = Color3.fromRGB(80, 220, 120) },
	{ MinLevel = 12, Name = "ROCKY SLALOM", Color = Color3.fromRGB(255, 200, 60) },
	{ MinLevel = 20, Name = "JELLYFISH SLALOM", Color = Color3.fromRGB(255, 120, 200) },
	{ MinLevel = 30, Name = "STORM SLALOM", Color = Color3.fromRGB(170, 110, 255) },
	{ MinLevel = 42, Name = "MEGA STORM SLALOM", Color = Color3.fromRGB(255, 80, 80) },
}

local Slalom = {
	Names = SlalomNames,
	StartLevel = 2, -- od kterého levelu se slalom objeví
	-- plynulý růst s levelem L (viz Formulas.SlalomTier)
	GatesBase = 2, -- branek na levelu 2, pak +1 každých GatesEvery levelů
	GatesEvery = 5,
	MaxGates = 8,
	GapStart = 22, -- šířka mezery na levelu 2, každým levelem o GapPerLevel užší
	GapPerLevel = 0.3,
	MinGap = 10,
	OffsetStart = 6, -- jak daleko od středu může mezera být
	OffsetPerLevel = 0.25,
	MaxOffset = 16,
	MovingFromLevel = 10, -- od tohoto levelu se některé branky hýbou do stran
	ObstaclesFromLevel = 4, -- od tohoto levelu přibývají překážky (1 za každé 3 levely, nejvýš 10)
	MaxObstacles = 10,
	-- od kterého levelu se která překážka může objevit
	ObstacleUnlock = { Rock = 4, Jellyfish = 15, Log = 25, Puffer = 30 } :: { [string]: number },
	ExtraDistancePerLevel = 2, -- trať je s každým levelem o kousek delší (nejvýš MaxExtraLevelDistance)
	MaxExtraLevelDistance = 80,
	DelayPerGate = 0.3, -- pronásledovatel vyrazí o tolik sekund později za každou branku (kličkování zdržuje)
	LaneHalfWidth = 40, -- jak daleko do stran může hráč plavat (stejné jako dřív)
	SteerFactor = 1, -- rychlost do stran = rychlost plavání × tohle (bez slalomu 0,5)
	BumpStun = 0.4, -- náraz do bariéry: chvíli nejde plavat dopředu
	HitStun = 0.7, -- náraz do překážky
	KnockBack = 3, -- o kolik studů překážka odhodí zpět
	-- velikost překážek (poloměr zásahu) a pohyb
	ObstacleRadius = { Rock = 3, Jellyfish = 2.6, Log = 1.6, Puffer = 2.4 } :: { [string]: number },
	LogLength = 12,
}

return {
	BaseSpeed = 16, -- studů za sekundu bez vylepšení
	Distance = 100, -- jak daleko je vor od místa dopadu
	StartDelay = 2.2, -- po dopadu (karta s předmětem), než se začne plavat
	SharkDelay = 2, -- žralok vyrazí až po této době (u delší plavby o čas, který hráč plave navíc)
	-- s lepší plaveckou výbavou je vor o kousek dál (o DistancePerSwimLevel za každé vylepšení, nejvýš MaxExtraDistance)
	DistancePerSwimLevel = 6,
	MaxExtraDistance = 36,
	-- Víc vorů za sebou (od levelu 5): na voru si hráč vybere, jestli se vrátí na pláž, nebo skočí zpátky
	-- do vody a plave dál směrem k pláži k dalšímu voru (těžší slalom, rychlejší pronásledovatel, větší bonus a poklad navíc).
	-- Když ho na dalším úseku chytí, přijde jen o odměnu toho úseku, co už získal, mu zůstane.
	Stages = {
		MinLevel = 5, -- od tohoto levelu může hráč z voru plavat dál k dalším vorům
		MinRoom = 70, -- další vor jen když je mezi vorem a molem aspoň tolik vody
		Max = 3,
		BonusMultiplier = { 1, 2, 3 }, -- bonus za doplavání k voru 1, 2, 3
		ChaserSpeedUp = 0.08, -- pronásledovatel je na každém dalším úseku o 8 % rychlejší
		SlalomLevelBonus = 8, -- slalom na dalším úseku jako by měl hráč o 8 levelů víc
		TreasureZoneShift = { 0, 0, 1 }, -- poklad na voru 2 a 3 (na třetím vzácnější)
		ChoiceTime = 12, -- kolik sekund má hráč na rozhodnutí (pak se vrátí na pláž)
	},
	-- pronásledovatelé podle vzdálenosti dopadu (seřazení podle MinDistance)
	Chasers = Chasers,
	TurboFinsBonus = 0.3, -- game pass: +30 % rychlost
	RepellentSwims = 3, -- Shark Repellent: kolik plavání bez žraloka
	NoSharkFirstJumps = 1, -- první skok bez žraloka (tutoriál)
	BonusSeconds = 25, -- bonus = příjem domečku za X sekund
	BonusMin = 60,
	MaxTime = 30, -- pak plavání skončí bez bonusu
	ReturnDelay = 1.8,
	CatchDistance = 1.5, -- žralok chytí hráče, když je blíž než tohle
	-- Rezerva na zpoždění sítě: server vidí polohu hráče asi o ping později, proto mu k postupu
	-- přičte tolik sekund plavání (jinak by hráč s minimální výbavou a pingem nad ~0,15 s prohrál,
	-- i když u sebe doplaval včas)
	LagGrace = 0.2,
	Upgrades = Upgrades,
	Slalom = Slalom,
}

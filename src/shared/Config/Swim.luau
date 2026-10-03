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

-- ===== Slalomy na cestě zpět k voru (od levelu 10) =====
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

local SlalomTiers: { SlalomTier } = {
	{
		MinLevel = 10,
		Name = "BUOY SLALOM",
		Color = Color3.fromRGB(80, 220, 120),
		Gates = 3,
		Gap = 18,
		Offset = 9,
		Moving = 0,
		MoveAmp = 0,
		MoveSpeed = 0,
		Obstacles = {},
	},
	{
		MinLevel = 20,
		Name = "ROCKY SLALOM",
		Color = Color3.fromRGB(255, 200, 60),
		Gates = 4,
		Gap = 15,
		Offset = 12,
		Moving = 0,
		MoveAmp = 0,
		MoveSpeed = 0,
		Obstacles = { Rock = 3 },
	},
	{
		MinLevel = 30,
		Name = "JELLYFISH SLALOM",
		Color = Color3.fromRGB(255, 120, 200),
		Gates = 4,
		Gap = 13,
		Offset = 13,
		Moving = 2,
		MoveAmp = 4,
		MoveSpeed = 1.2,
		Obstacles = { Jellyfish = 3, Rock = 1 },
	},
	{
		MinLevel = 40,
		Name = "STORM SLALOM",
		Color = Color3.fromRGB(170, 110, 255),
		Gates = 5,
		Gap = 11,
		Offset = 14,
		Moving = 3,
		MoveAmp = 5,
		MoveSpeed = 1.5,
		Obstacles = { Log = 2, Puffer = 2, Jellyfish = 1 },
	},
}

local Slalom = {
	Tiers = SlalomTiers,
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
	SharkDelay = 2, -- žralok vyrazí až po této době
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

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
}

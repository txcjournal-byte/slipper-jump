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

return {
	BaseSpeed = 16, -- studů za sekundu bez vylepšení
	Distance = 100, -- jak daleko je vor od místa dopadu
	StartDelay = 2.2, -- po dopadu (karta s předmětem), než se začne plavat
	SharkDelay = 2, -- žralok vyrazí až po této době
	-- rychlost žraloka podle zóny dopadu (hlubší voda = rychlejší žralok)
	SharkSpeeds = { 18, 24, 30, 36, 44 },
	TurboFinsBonus = 0.3, -- game pass: +30 % rychlost
	RepellentSwims = 3, -- Shark Repellent: kolik plavání bez žraloka
	NoSharkFirstJumps = 1, -- první skok bez žraloka (tutoriál)
	BonusSeconds = 25, -- bonus = příjem domečku za X sekund
	BonusMin = 60,
	MaxTime = 30, -- pak plavání skončí bez bonusu
	ReturnDelay = 1.8,
	CatchDistance = 1.5, -- žralok chytí hráče, když je blíž než tohle
	Upgrades = Upgrades,
}

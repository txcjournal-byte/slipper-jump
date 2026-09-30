--!strict
-- Čepice: bonus ke skoku (JumpBonus) nebo k příjmu (IncomeBonus). Price = nil → nedá se koupit.

export type Shape = "Cap" | "Brim" | "Dome" | "Goggles" | "Chef" | "Hood" | "Crown" | "Pointy" | "Helmet" | "Horns" | "Halo" | "Wig" | "Buddy" | "Propeller" | "Bow"

export type Hat = {
	Id: string,
	Name: string,
	Price: number?,
	JumpBonus: number,
	IncomeBonus: number,
	Color: Color3,
	Accent: Color3,
	Shape: Shape,
	Source: string?, -- jak se získá, když se nedá koupit
}

local Hats: { Hat } = {
	{ Id = "BaseballCap", Name = "Baseball Cap", Price = 500, JumpBonus = 0.02, IncomeBonus = 0, Color = Color3.fromRGB(230, 50, 50), Accent = Color3.fromRGB(255, 255, 255), Shape = "Cap" },
	{ Id = "StrawHat", Name = "Straw Hat", Price = 1_500, JumpBonus = 0, IncomeBonus = 0.02, Color = Color3.fromRGB(235, 200, 120), Accent = Color3.fromRGB(200, 60, 60), Shape = "Brim" },
	{ Id = "SwimCap", Name = "Swim Cap", Price = 4_000, JumpBonus = 0.04, IncomeBonus = 0, Color = Color3.fromRGB(60, 170, 255), Accent = Color3.fromRGB(255, 255, 255), Shape = "Dome" },
	{ Id = "DivingGoggles", Name = "Diving Goggles", Price = 10_000, JumpBonus = 0, IncomeBonus = 0.05, Color = Color3.fromRGB(40, 40, 50), Accent = Color3.fromRGB(120, 220, 255), Shape = "Goggles" },
	{ Id = "FishingHat", Name = "Fishing Hat", Price = 25_000, JumpBonus = 0.06, IncomeBonus = 0, Color = Color3.fromRGB(120, 140, 90), Accent = Color3.fromRGB(255, 150, 60), Shape = "Brim" },
	{ Id = "PropellerCap", Name = "Propeller Cap", Price = 60_000, JumpBonus = 0.08, IncomeBonus = 0, Color = Color3.fromRGB(255, 210, 50), Accent = Color3.fromRGB(230, 60, 60), Shape = "Propeller" },
	{ Id = "ChefHat", Name = "Chef Hat", Price = 120_000, JumpBonus = 0, IncomeBonus = 0.08, Color = Color3.fromRGB(250, 250, 250), Accent = Color3.fromRGB(230, 230, 230), Shape = "Chef" },
	{ Id = "CowboyHat", Name = "Cowboy Hat", Price = 250_000, JumpBonus = 0.10, IncomeBonus = 0, Color = Color3.fromRGB(150, 95, 50), Accent = Color3.fromRGB(90, 55, 30), Shape = "Brim" },
	{ Id = "SharkHood", Name = "Shark Hood", Price = 500_000, JumpBonus = 0, IncomeBonus = 0.12, Color = Color3.fromRGB(110, 130, 150), Accent = Color3.fromRGB(255, 255, 255), Shape = "Hood" },
	{ Id = "FlowerCrown", Name = "Flower Crown", Price = 1_000_000, JumpBonus = 0.12, IncomeBonus = 0, Color = Color3.fromRGB(90, 180, 80), Accent = Color3.fromRGB(255, 130, 200), Shape = "Crown" },
	{ Id = "WizardHat", Name = "Wizard Hat", Price = 2_000_000, JumpBonus = 0, IncomeBonus = 0.15, Color = Color3.fromRGB(80, 60, 190), Accent = Color3.fromRGB(255, 230, 90), Shape = "Pointy" },
	{ Id = "KnightHelmet", Name = "Knight Helmet", Price = 4_000_000, JumpBonus = 0.15, IncomeBonus = 0, Color = Color3.fromRGB(180, 185, 195), Accent = Color3.fromRGB(230, 60, 60), Shape = "Helmet" },
	{ Id = "VikingHelmet", Name = "Viking Helmet", Price = 8_000_000, JumpBonus = 0, IncomeBonus = 0.18, Color = Color3.fromRGB(160, 160, 170), Accent = Color3.fromRGB(250, 240, 210), Shape = "Horns" },
	{ Id = "AstronautHelmet", Name = "Astronaut Helmet", Price = 15_000_000, JumpBonus = 0.20, IncomeBonus = 0, Color = Color3.fromRGB(245, 245, 250), Accent = Color3.fromRGB(80, 170, 255), Shape = "Helmet" },
	{ Id = "OctopusBuddy", Name = "Octopus Buddy", Price = 25_000_000, JumpBonus = 0, IncomeBonus = 0.22, Color = Color3.fromRGB(255, 120, 170), Accent = Color3.fromRGB(255, 255, 255), Shape = "Buddy" },
	{ Id = "Halo", Name = "Halo", Price = 40_000_000, JumpBonus = 0.25, IncomeBonus = 0, Color = Color3.fromRGB(255, 240, 140), Accent = Color3.fromRGB(255, 255, 255), Shape = "Halo" },
	{ Id = "DragonHorns", Name = "Dragon Horns", Price = 60_000_000, JumpBonus = 0, IncomeBonus = 0.28, Color = Color3.fromRGB(200, 40, 60), Accent = Color3.fromRGB(255, 200, 60), Shape = "Horns" },
	{ Id = "RainbowWig", Name = "Rainbow Wig", Price = 90_000_000, JumpBonus = 0.30, IncomeBonus = 0, Color = Color3.fromRGB(255, 90, 200), Accent = Color3.fromRGB(90, 220, 255), Shape = "Wig" },
	{ Id = "IceCrown", Name = "Ice Crown", Price = 150_000_000, JumpBonus = 0, IncomeBonus = 0.35, Color = Color3.fromRGB(170, 230, 255), Accent = Color3.fromRGB(255, 255, 255), Shape = "Crown" },
	{ Id = "SeaKingCrown", Name = "Sea King Crown", Price = 250_000_000, JumpBonus = 0.40, IncomeBonus = 0.40, Color = Color3.fromRGB(255, 205, 50), Accent = Color3.fromRGB(60, 200, 230), Shape = "Crown" },
	-- Nedají se koupit:
	{ Id = "CaptainHat", Name = "Captain Hat", Price = nil, JumpBonus = 0.05, IncomeBonus = 0.05, Color = Color3.fromRGB(250, 250, 250), Accent = Color3.fromRGB(30, 40, 90), Shape = "Cap", Source = "Reach level 15" },
	{ Id = "PirateHat", Name = "Pirate Hat", Price = nil, JumpBonus = 0.10, IncomeBonus = 0.10, Color = Color3.fromRGB(35, 35, 40), Accent = Color3.fromRGB(255, 255, 255), Shape = "Brim", Source = "Reach level 35" },
	{ Id = "GoldenBowHat", Name = "Golden Bow Hat", Price = nil, JumpBonus = 0.20, IncomeBonus = 0.20, Color = Color3.fromRGB(255, 205, 50), Accent = Color3.fromRGB(230, 40, 50), Shape = "Bow", Source = "Open the Giant Gift" },
}

return Hats

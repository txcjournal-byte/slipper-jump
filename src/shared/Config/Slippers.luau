--!strict
-- Pantofle: určují délku skoku. Vzdálenost = BaseDistance (Jump.luau) × Multiplier × bonus čepice.
-- Id = název modelu v ReplicatedStorage.Assets.Slippers (když chybí, postaví se dočasný model).

export type Effect = "None" | "Drops" | "Seeds" | "Fluff" | "Fin" | "Squeak" | "Leaves" | "Snow" | "Rainbow"
	| "Sparks" | "Boing" | "Smoke" | "Footprints" | "Crystals" | "Steam" | "Clouds" | "Leds" | "Stars" | "Flames" | "Crown"

export type Slipper = {
	Id: string,
	Name: string,
	Price: number,
	Multiplier: number,
	Color: Color3,
	Accent: Color3,
	TrailColor: Color3,
	Effect: Effect,
	EffectText: string,
}

local Slippers: { Slipper } = {
	{ Id = "BasicBlackSlippers", Name = "Basic Black Slippers", Price = 0, Multiplier = 1, Color = Color3.fromRGB(40, 40, 45), Accent = Color3.fromRGB(90, 90, 95), TrailColor = Color3.fromRGB(200, 200, 200), Effect = "None", EffectText = "No effect" },
	{ Id = "BeachBlueSlippers", Name = "Beach Blue Slippers", Price = 100, Multiplier = 1.5, Color = Color3.fromRGB(40, 140, 255), Accent = Color3.fromRGB(255, 255, 255), TrailColor = Color3.fromRGB(120, 200, 255), Effect = "Drops", EffectText = "Water drops" },
	{ Id = "WatermelonSlippers", Name = "Watermelon Slippers", Price = 350, Multiplier = 2, Color = Color3.fromRGB(255, 80, 100), Accent = Color3.fromRGB(60, 180, 70), TrailColor = Color3.fromRGB(255, 120, 140), Effect = "Seeds", EffectText = "Seeds" },
	{ Id = "FluffyBunnySlippers", Name = "Fluffy Bunny Slippers", Price = 800, Multiplier = 3, Color = Color3.fromRGB(255, 220, 235), Accent = Color3.fromRGB(255, 160, 200), TrailColor = Color3.fromRGB(255, 240, 250), Effect = "Fluff", EffectText = "Fluff" },
	{ Id = "SharkSlippers", Name = "Shark Slippers", Price = 2_000, Multiplier = 4.5, Color = Color3.fromRGB(110, 130, 150), Accent = Color3.fromRGB(240, 240, 240), TrailColor = Color3.fromRGB(150, 180, 210), Effect = "Fin", EffectText = "Shark fin in the water" },
	{ Id = "RubberDuckSlippers", Name = "Rubber Duck Slippers", Price = 4_500, Multiplier = 6, Color = Color3.fromRGB(255, 215, 40), Accent = Color3.fromRGB(255, 140, 20), TrailColor = Color3.fromRGB(255, 230, 90), Effect = "Squeak", EffectText = "Duck squeaks" },
	{ Id = "PineappleSlippers", Name = "Pineapple Slippers", Price = 9_000, Multiplier = 9, Color = Color3.fromRGB(255, 190, 40), Accent = Color3.fromRGB(70, 170, 60), TrailColor = Color3.fromRGB(120, 200, 80), Effect = "Leaves", EffectText = "Pineapple leaves" },
	{ Id = "PenguinSlippers", Name = "Penguin Slippers", Price = 18_000, Multiplier = 13, Color = Color3.fromRGB(30, 35, 50), Accent = Color3.fromRGB(255, 255, 255), TrailColor = Color3.fromRGB(220, 240, 255), Effect = "Snow", EffectText = "Snowflakes" },
	{ Id = "RainbowSlippers", Name = "Rainbow Slippers", Price = 35_000, Multiplier = 18, Color = Color3.fromRGB(255, 90, 200), Accent = Color3.fromRGB(90, 200, 255), TrailColor = Color3.fromRGB(255, 255, 255), Effect = "Rainbow", EffectText = "Rainbow trail" },
	{ Id = "GoldenSlippers", Name = "Golden Slippers", Price = 70_000, Multiplier = 26, Color = Color3.fromRGB(255, 200, 40), Accent = Color3.fromRGB(255, 240, 150), TrailColor = Color3.fromRGB(255, 215, 80), Effect = "Sparks", EffectText = "Golden sparks" },
	{ Id = "SpringSlippers", Name = "Spring Slippers", Price = 140_000, Multiplier = 38, Color = Color3.fromRGB(80, 220, 160), Accent = Color3.fromRGB(180, 180, 190), TrailColor = Color3.fromRGB(140, 255, 200), Effect = "Boing", EffectText = "\"Boing\" on takeoff" },
	{ Id = "RocketSlippers", Name = "Rocket Slippers", Price = 280_000, Multiplier = 55, Color = Color3.fromRGB(230, 60, 50), Accent = Color3.fromRGB(230, 230, 240), TrailColor = Color3.fromRGB(255, 170, 60), Effect = "Smoke", EffectText = "Rocket smoke" },
	{ Id = "DinoSlippers", Name = "Dino Slippers", Price = 550_000, Multiplier = 78, Color = Color3.fromRGB(90, 190, 80), Accent = Color3.fromRGB(250, 230, 120), TrailColor = Color3.fromRGB(130, 220, 110), Effect = "Footprints", EffectText = "Dino footprints" },
	{ Id = "CrystalSlippers", Name = "Crystal Slippers", Price = 1_100_000, Multiplier = 110, Color = Color3.fromRGB(170, 230, 255), Accent = Color3.fromRGB(255, 255, 255), TrailColor = Color3.fromRGB(200, 245, 255), Effect = "Crystals", EffectText = "Sparkling crystals" },
	{ Id = "LavaSlippers", Name = "Lava Slippers", Price = 2_200_000, Multiplier = 160, Color = Color3.fromRGB(255, 90, 20), Accent = Color3.fromRGB(60, 30, 30), TrailColor = Color3.fromRGB(255, 140, 40), Effect = "Steam", EffectText = "Steam over the water" },
	{ Id = "CloudWingSlippers", Name = "Cloud Wing Slippers", Price = 4_500_000, Multiplier = 230, Color = Color3.fromRGB(245, 250, 255), Accent = Color3.fromRGB(170, 210, 255), TrailColor = Color3.fromRGB(255, 255, 255), Effect = "Clouds", EffectText = "Little clouds" },
	{ Id = "RobotSlippers", Name = "Robot Slippers", Price = 9_000_000, Multiplier = 340, Color = Color3.fromRGB(150, 160, 175), Accent = Color3.fromRGB(60, 255, 120), TrailColor = Color3.fromRGB(60, 255, 120), Effect = "Leds", EffectText = "Blinking LEDs" },
	{ Id = "GalaxySlippers", Name = "Galaxy Slippers", Price = 18_000_000, Multiplier = 480, Color = Color3.fromRGB(60, 30, 120), Accent = Color3.fromRGB(255, 120, 255), TrailColor = Color3.fromRGB(160, 110, 255), Effect = "Stars", EffectText = "Stars and planets" },
	{ Id = "DragonSlippers", Name = "Dragon Slippers", Price = 40_000_000, Multiplier = 650, Color = Color3.fromRGB(200, 40, 60), Accent = Color3.fromRGB(255, 200, 60), TrailColor = Color3.fromRGB(255, 120, 60), Effect = "Flames", EffectText = "Cute little flames" },
	{ Id = "RoyalDiamondSlippers", Name = "Royal Diamond Slippers", Price = 100_000_000, Multiplier = 1000, Color = Color3.fromRGB(120, 220, 255), Accent = Color3.fromRGB(255, 215, 60), TrailColor = Color3.fromRGB(255, 240, 150), Effect = "Crown", EffectText = "Crown and confetti" },
}

return Slippers

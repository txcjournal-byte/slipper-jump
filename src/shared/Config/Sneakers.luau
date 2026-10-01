--!strict
-- Tenisky: druhá řada bot se STEJNOU silou jako pantofle na stejné pozici (cena i násobič).
-- Od nejošklivějších (zablácené, slepené páskou) po nejkrásnější zlaté. Žádné skutečné značky!

local Slippers = require(script.Parent.Slippers)

type Look = { Id: string, Name: string, Color: Color3, Accent: Color3, TrailColor: Color3, Effect: Slippers.Effect, EffectText: string, HighTop: boolean?, Worn: boolean? }

local LOOKS: { Look } = {
	{ Id = "MuddyOldSneakers", Name = "Muddy Old Sneakers", Color = Color3.fromRGB(120, 95, 70), Accent = Color3.fromRGB(80, 65, 50), TrailColor = Color3.fromRGB(140, 110, 80), Effect = "None", EffectText = "Smells a bit...", Worn = true },
	{ Id = "TapedUpTrainers", Name = "Taped-Up Trainers", Color = Color3.fromRGB(150, 150, 155), Accent = Color3.fromRGB(230, 220, 160), TrailColor = Color3.fromRGB(190, 190, 190), Effect = "Drops", EffectText = "Held together by tape", Worn = true },
	{ Id = "CanvasKicks", Name = "Canvas Kicks", Color = Color3.fromRGB(235, 235, 230), Accent = Color3.fromRGB(200, 60, 60), TrailColor = Color3.fromRGB(240, 240, 240), Effect = "Seeds", EffectText = "Classic canvas" },
	{ Id = "StreetRunners", Name = "Street Runners", Color = Color3.fromRGB(50, 110, 220), Accent = Color3.fromRGB(255, 255, 255), TrailColor = Color3.fromRGB(110, 170, 255), Effect = "Fluff", EffectText = "Dust clouds" },
	{ Id = "SkateLows", Name = "Skate Lows", Color = Color3.fromRGB(35, 35, 40), Accent = Color3.fromRGB(240, 70, 60), TrailColor = Color3.fromRGB(240, 90, 80), Effect = "Fin", EffectText = "Skater sparks" },
	{ Id = "CourtClassics", Name = "Court Classics", Color = Color3.fromRGB(250, 250, 250), Accent = Color3.fromRGB(40, 170, 80), TrailColor = Color3.fromRGB(120, 230, 140), Effect = "Squeak", EffectText = "Court squeak", HighTop = true },
	{ Id = "NeonSprinters", Name = "Neon Sprinters", Color = Color3.fromRGB(190, 255, 40), Accent = Color3.fromRGB(30, 30, 35), TrailColor = Color3.fromRGB(200, 255, 60), Effect = "Leaves", EffectText = "Neon streaks" },
	{ Id = "GraffitiHighTops", Name = "Graffiti High-Tops", Color = Color3.fromRGB(255, 120, 200), Accent = Color3.fromRGB(80, 220, 255), TrailColor = Color3.fromRGB(255, 150, 220), Effect = "Snow", EffectText = "Spray paint dots", HighTop = true },
	{ Id = "LightningLows", Name = "Lightning Lows", Color = Color3.fromRGB(255, 215, 40), Accent = Color3.fromRGB(30, 30, 40), TrailColor = Color3.fromRGB(255, 230, 80), Effect = "Rainbow", EffectText = "Lightning trail" },
	{ Id = "IceBreakers", Name = "Ice Breakers", Color = Color3.fromRGB(170, 225, 255), Accent = Color3.fromRGB(255, 255, 255), TrailColor = Color3.fromRGB(200, 240, 255), Effect = "Sparks", EffectText = "Frosty sparks", HighTop = true },
	{ Id = "RocketBoosters", Name = "Rocket Boosters", Color = Color3.fromRGB(230, 60, 50), Accent = Color3.fromRGB(240, 240, 245), TrailColor = Color3.fromRGB(255, 160, 60), Effect = "Boing", EffectText = "Booster pop" },
	{ Id = "LavaStompers", Name = "Lava Stompers", Color = Color3.fromRGB(40, 30, 30), Accent = Color3.fromRGB(255, 100, 20), TrailColor = Color3.fromRGB(255, 120, 40), Effect = "Smoke", EffectText = "Smoking soles", HighTop = true },
	{ Id = "ThunderDunks", Name = "Thunder Dunks", Color = Color3.fromRGB(70, 40, 160), Accent = Color3.fromRGB(255, 230, 60), TrailColor = Color3.fromRGB(150, 110, 255), Effect = "Footprints", EffectText = "Thunder steps", HighTop = true },
	{ Id = "CrystalCourts", Name = "Crystal Courts", Color = Color3.fromRGB(190, 240, 255), Accent = Color3.fromRGB(255, 255, 255), TrailColor = Color3.fromRGB(210, 250, 255), Effect = "Crystals", EffectText = "Crystal shards" },
	{ Id = "GalaxyRunners", Name = "Galaxy Runners", Color = Color3.fromRGB(40, 25, 100), Accent = Color3.fromRGB(255, 120, 255), TrailColor = Color3.fromRGB(170, 120, 255), Effect = "Steam", EffectText = "Nebula mist" },
	{ Id = "CyberSteppers", Name = "Cyber Steppers", Color = Color3.fromRGB(30, 35, 45), Accent = Color3.fromRGB(0, 255, 230), TrailColor = Color3.fromRGB(0, 255, 230), Effect = "Leds", EffectText = "Glowing circuits" },
	{ Id = "DragonScaleHighs", Name = "Dragon Scale Highs", Color = Color3.fromRGB(30, 140, 80), Accent = Color3.fromRGB(255, 200, 60), TrailColor = Color3.fromRGB(90, 220, 120), Effect = "Clouds", EffectText = "Dragon breath", HighTop = true },
	{ Id = "PhantomGlides", Name = "Phantom Glides", Color = Color3.fromRGB(245, 245, 255), Accent = Color3.fromRGB(150, 160, 255), TrailColor = Color3.fromRGB(230, 230, 255), Effect = "Stars", EffectText = "Ghostly stars" },
	{ Id = "SkyDunkLegends", Name = "Sky Dunk Legends", Color = Color3.fromRGB(200, 30, 40), Accent = Color3.fromRGB(20, 20, 25), TrailColor = Color3.fromRGB(255, 80, 80), Effect = "Flames", EffectText = "Legendary flames", HighTop = true },
	{ Id = "GoldenAirKings", Name = "Golden Air Kings", Color = Color3.fromRGB(255, 200, 40), Accent = Color3.fromRGB(120, 230, 255), TrailColor = Color3.fromRGB(255, 235, 140), Effect = "Crown", EffectText = "Gold and diamonds", HighTop = true },
}

local Sneakers: { Slippers.Slipper } = {}
for index, look in LOOKS do
	local tier = Slippers[index]
	table.insert(Sneakers, {
		Id = look.Id,
		Name = look.Name,
		Price = tier.Price,
		Multiplier = tier.Multiplier,
		Color = look.Color,
		Accent = look.Accent,
		TrailColor = look.TrailColor,
		Effect = look.Effect,
		EffectText = look.EffectText,
		Style = "Sneaker",
		HighTop = look.HighTop,
		Worn = look.Worn,
	})
end

return Sneakers

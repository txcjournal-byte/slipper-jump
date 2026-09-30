--!strict
-- Předměty z vody. Income = $ za sekundu v domečku. Prodejní cena = Economy.SellMultiplier × Income.

export type RarityName = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret"

export type Rarity = {
	Name: RarityName,
	Order: number,
	Color: Color3,
	Pulse: boolean, -- rámeček pulzuje
	Rainbow: boolean, -- rámeček s duhovou září
	ConfirmSell: boolean, -- ptát se před prodejem
	Fanfare: boolean, -- delší animace a fanfára při nálezu
}

export type ItemShape = "Shell" | "Ball" | "Block" | "Stick" | "Ring" | "Star" | "Duck" | "Bucket" | "Umbrella"
	| "Bottle" | "Chest" | "Creature" | "Statue" | "Trident" | "Map" | "Anchor" | "Crown" | "Egg" | "Ufo"

export type Item = {
	Id: string,
	Name: string,
	Rarity: RarityName,
	Income: number,
	Color: Color3,
	Shape: ItemShape,
	CanDrop: boolean?, -- false = nepadá z vody (např. Golden Splash)
	CanSell: boolean?,
	CanGift: boolean?,
}

local Rarities: { Rarity } = {
	{ Name = "Common", Order = 1, Color = Color3.fromRGB(170, 175, 185), Pulse = false, Rainbow = false, ConfirmSell = false, Fanfare = false },
	{ Name = "Uncommon", Order = 2, Color = Color3.fromRGB(80, 210, 90), Pulse = false, Rainbow = false, ConfirmSell = false, Fanfare = false },
	{ Name = "Rare", Order = 3, Color = Color3.fromRGB(60, 150, 255), Pulse = false, Rainbow = false, ConfirmSell = false, Fanfare = false },
	{ Name = "Epic", Order = 4, Color = Color3.fromRGB(170, 80, 255), Pulse = false, Rainbow = false, ConfirmSell = false, Fanfare = true },
	{ Name = "Legendary", Order = 5, Color = Color3.fromRGB(255, 195, 30), Pulse = false, Rainbow = false, ConfirmSell = true, Fanfare = true },
	{ Name = "Mythic", Order = 6, Color = Color3.fromRGB(255, 90, 200), Pulse = true, Rainbow = false, ConfirmSell = true, Fanfare = true },
	{ Name = "Secret", Order = 7, Color = Color3.fromRGB(20, 20, 25), Pulse = false, Rainbow = true, ConfirmSell = true, Fanfare = true },
}

local Items: { Item } = {
	-- Common (1–3 $/s)
	{ Id = "Seashell", Name = "Seashell", Rarity = "Common", Income = 1, Color = Color3.fromRGB(255, 220, 200), Shape = "Shell" },
	{ Id = "Pebble", Name = "Pebble", Rarity = "Common", Income = 1, Color = Color3.fromRGB(150, 150, 150), Shape = "Ball" },
	{ Id = "PlasticShovel", Name = "Plastic Shovel", Rarity = "Common", Income = 2, Color = Color3.fromRGB(255, 120, 40), Shape = "Stick" },
	{ Id = "OldSock", Name = "Old Sock", Rarity = "Common", Income = 2, Color = Color3.fromRGB(220, 220, 200), Shape = "Block" },
	{ Id = "Seaweed", Name = "Seaweed", Rarity = "Common", Income = 3, Color = Color3.fromRGB(60, 150, 70), Shape = "Stick" },
	-- Uncommon (5–10 $/s)
	{ Id = "Starfish", Name = "Starfish", Rarity = "Uncommon", Income = 5, Color = Color3.fromRGB(255, 120, 80), Shape = "Star" },
	{ Id = "RubberDuck", Name = "Rubber Duck", Rarity = "Uncommon", Income = 6, Color = Color3.fromRGB(255, 220, 40), Shape = "Duck" },
	{ Id = "SandBucket", Name = "Sand Bucket", Rarity = "Uncommon", Income = 7, Color = Color3.fromRGB(60, 160, 255), Shape = "Bucket" },
	{ Id = "SwimRing", Name = "Swim Ring", Rarity = "Uncommon", Income = 8, Color = Color3.fromRGB(255, 80, 90), Shape = "Ring" },
	{ Id = "BeachUmbrella", Name = "Beach Umbrella", Rarity = "Uncommon", Income = 10, Color = Color3.fromRGB(255, 90, 90), Shape = "Umbrella" },
	-- Rare (20–50 $/s)
	{ Id = "MessageInABottle", Name = "Message in a Bottle", Rarity = "Rare", Income = 20, Color = Color3.fromRGB(120, 200, 150), Shape = "Bottle" },
	{ Id = "Pearl", Name = "Pearl", Rarity = "Rare", Income = 25, Color = Color3.fromRGB(250, 245, 240), Shape = "Ball" },
	{ Id = "CrabInAHat", Name = "Crab in a Hat", Rarity = "Rare", Income = 32, Color = Color3.fromRGB(240, 70, 50), Shape = "Creature" },
	{ Id = "GoldfishInABag", Name = "Goldfish in a Bag", Rarity = "Rare", Income = 40, Color = Color3.fromRGB(255, 150, 40), Shape = "Bottle" },
	{ Id = "Compass", Name = "Compass", Rarity = "Rare", Income = 50, Color = Color3.fromRGB(200, 160, 80), Shape = "Ring" },
	-- Epic (100–250 $/s)
	{ Id = "CoinChest", Name = "Coin Chest", Rarity = "Epic", Income = 100, Color = Color3.fromRGB(150, 90, 40), Shape = "Chest" },
	{ Id = "ShipInABottle", Name = "Ship in a Bottle", Rarity = "Epic", Income = 130, Color = Color3.fromRGB(140, 210, 230), Shape = "Bottle" },
	{ Id = "OctopusWithGlasses", Name = "Octopus with Glasses", Rarity = "Epic", Income = 160, Color = Color3.fromRGB(200, 100, 220), Shape = "Creature" },
	{ Id = "DolphinStatue", Name = "Dolphin Statue", Rarity = "Epic", Income = 200, Color = Color3.fromRGB(110, 170, 230), Shape = "Statue" },
	{ Id = "Trident", Name = "Trident", Rarity = "Epic", Income = 250, Color = Color3.fromRGB(80, 220, 210), Shape = "Trident" },
	-- Legendary (500–1 500 $/s)
	{ Id = "PirateMap", Name = "Pirate Map", Rarity = "Legendary", Income = 500, Color = Color3.fromRGB(235, 210, 160), Shape = "Map" },
	{ Id = "GoldenAnchor", Name = "Golden Anchor", Rarity = "Legendary", Income = 700, Color = Color3.fromRGB(255, 200, 40), Shape = "Anchor" },
	{ Id = "GlowingJellyfish", Name = "Glowing Jellyfish", Rarity = "Legendary", Income = 900, Color = Color3.fromRGB(120, 230, 255), Shape = "Creature" },
	{ Id = "FishKingCrown", Name = "Fish King Crown", Rarity = "Legendary", Income = 1_200, Color = Color3.fromRGB(255, 210, 60), Shape = "Crown" },
	{ Id = "MermaidStatue", Name = "Mermaid Statue", Rarity = "Legendary", Income = 1_500, Color = Color3.fromRGB(80, 210, 180), Shape = "Statue" },
	-- Mythic (3 000–8 000 $/s)
	{ Id = "SeaDragonEgg", Name = "Sea Dragon Egg", Rarity = "Mythic", Income = 3_000, Color = Color3.fromRGB(60, 200, 170), Shape = "Egg" },
	{ Id = "RainbowPearl", Name = "Rainbow Pearl", Rarity = "Mythic", Income = 5_000, Color = Color3.fromRGB(255, 160, 230), Shape = "Ball" },
	{ Id = "PlushKraken", Name = "Plush Kraken", Rarity = "Mythic", Income = 8_000, Color = Color3.fromRGB(190, 70, 160), Shape = "Creature" },
	-- Secret (20 000–50 000 $/s) – v katalogu jen "???", dokud je hráč nenajde
	{ Id = "WaterUnicorn", Name = "Water Unicorn", Rarity = "Secret", Income = 20_000, Color = Color3.fromRGB(150, 220, 255), Shape = "Creature" },
	{ Id = "DeepSeaUFO", Name = "Deep Sea UFO", Rarity = "Secret", Income = 35_000, Color = Color3.fromRGB(120, 255, 170), Shape = "Ufo" },
	{ Id = "MegaSplashDuck", Name = "Mega Splash Duck", Rarity = "Secret", Income = 50_000, Color = Color3.fromRGB(255, 230, 60), Shape = "Duck" },
	-- Unikát z obřího dárku
	{ Id = "GoldenSplash", Name = "Golden Splash", Rarity = "Secret", Income = 100_000, Color = Color3.fromRGB(255, 205, 40), Shape = "Statue", CanDrop = false, CanSell = false, CanGift = false },
}

-- Šance podle zóny dopadu (v procentech). MinDistance = začátek zóny ve studech.
export type Zone = { MinDistance: number, Chances: { [string]: number } }

local Zones: { Zone } = {
	{ MinDistance = 0, Chances = { Common = 80, Uncommon = 18, Rare = 2 } },
	{ MinDistance = 1_000, Chances = { Common = 50, Uncommon = 35, Rare = 12, Epic = 3 } },
	{ MinDistance = 5_000, Chances = { Common = 25, Uncommon = 35, Rare = 28, Epic = 10, Legendary = 2 } },
	{ MinDistance = 20_000, Chances = { Common = 10, Uncommon = 25, Rare = 35, Epic = 22, Legendary = 7.5, Mythic = 0.5 } },
	{ MinDistance = 60_000, Chances = { Uncommon = 10, Rare = 30, Epic = 35, Legendary = 20, Mythic = 4.9, Secret = 0.1 } },
}

return {
	Rarities = Rarities,
	Items = Items,
	Zones = Zones,
}

--!strict
-- Robux obchod. Id zkopírujte z Creator Dashboard (Monetization → Passes / Developer Products).
-- Id = 0 znamená "ještě nezaloženo" – tlačítko v obchodě jen ukáže hlášku.

export type GamePass = { Key: string, Id: number, Name: string, Price: number, Description: string, Color: Color3 }
export type DevProduct = { Key: string, Id: number, Name: string, Price: number, Description: string, Color: Color3, ShowOdds: boolean? }

local GamePasses: { GamePass } = {
	{ Key = "RainbowTrail", Id = 0, Name = "Rainbow Trail", Price = 49, Description = "A rainbow trail behind every jump", Color = Color3.fromRGB(255, 110, 200) },
	{ Key = "AutoCollect", Id = 0, Name = "Auto Collect", Price = 99, Description = "Money from your house is collected automatically", Color = Color3.fromRGB(80, 200, 120) },
	{ Key = "PlusSlots", Id = 0, Name = "+5 Slots", Price = 149, Description = "5 more item spots in your house", Color = Color3.fromRGB(60, 160, 255) },
	{ Key = "DoubleMoney", Id = 0, Name = "2x Money", Price = 199, Description = "Double money from everything, forever", Color = Color3.fromRGB(255, 200, 40) },
	{ Key = "VIP", Id = 0, Name = "VIP", Price = 249, Description = "Golden name and +1 daily spin", Color = Color3.fromRGB(255, 170, 30) },
}

local DevProducts: { DevProduct } = {
	{ Key = "SuperJump", Id = 0, Name = "Super Jump", Price = 15, Description = "Your next jump goes 20% farther", Color = Color3.fromRGB(80, 220, 255) },
	{ Key = "Spin1", Id = 0, Name = "1 Spin", Price = 25, Description = "One extra spin of the wheel", Color = Color3.fromRGB(255, 120, 60), ShowOdds = true },
	{ Key = "Boost30", Id = 0, Name = "2x Money (30 min)", Price = 49, Description = "Double money for 30 minutes", Color = Color3.fromRGB(255, 200, 40) },
	{ Key = "MoneyBag", Id = 0, Name = "Money Bag", Price = 49, Description = "Money equal to 15 minutes of house income", Color = Color3.fromRGB(80, 200, 120) },
	{ Key = "Spins5", Id = 0, Name = "5 Spins", Price = 99, Description = "Five extra spins of the wheel", Color = Color3.fromRGB(255, 90, 150), ShowOdds = true },
	{ Key = "MoneyChest", Id = 0, Name = "Money Chest", Price = 149, Description = "Money equal to 1 hour of house income", Color = Color3.fromRGB(170, 80, 255) },
}

return {
	GamePasses = GamePasses,
	DevProducts = DevProducts,
	-- Hodnoty produktů
	BoostMinutes = 30,
	MoneyBagSeconds = 15 * 60,
	MoneyChestSeconds = 60 * 60,
	MinMoneyPack = 500, -- aby balíček měl smysl i na úplném začátku
	PassSlots = 5,
	VipExtraDailySpins = 1,
}

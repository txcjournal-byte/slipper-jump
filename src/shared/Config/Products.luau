--!strict
-- Robux obchod. Id zkopírujte z Creator Dashboard (Monetization → Passes / Developer Products).
-- Id = 0 znamená "ještě nezaloženo" – tlačítko v obchodě jen ukáže hlášku.

export type GamePass = { Key: string, Id: number, Name: string, Price: number, Description: string, Color: Color3 }
export type DevProduct = { Key: string, Id: number, Name: string, Price: number, Description: string, Color: Color3, ShowOdds: boolean?, OneTime: boolean? }

local GamePasses: { GamePass } = {
	{ Key = "RainbowTrail", Id = 0, Name = "Rainbow Trail", Price = 49, Description = "A rainbow trail behind every jump", Color = Color3.fromRGB(255, 110, 200) },
	{ Key = "AutoCollect", Id = 0, Name = "Auto Collect", Price = 99, Description = "Money from your house is collected automatically", Color = Color3.fromRGB(80, 200, 120) },
	{ Key = "PlusSlots", Id = 0, Name = "+5 Slots", Price = 149, Description = "5 more item spots in your house", Color = Color3.fromRGB(60, 160, 255) },
	{ Key = "DoubleMoney", Id = 0, Name = "2x Money", Price = 199, Description = "Double money from everything, forever", Color = Color3.fromRGB(255, 200, 40) },
	{ Key = "TurboFins", Id = 0, Name = "Turbo Fins", Price = 149, Description = "Swim 30% faster, forever. Outswim every shark!", Color = Color3.fromRGB(60, 200, 255) },
	{ Key = "VIP", Id = 0, Name = "VIP", Price = 249, Description = "Golden name and +1 daily spin", Color = Color3.fromRGB(255, 170, 30) },
}

local DevProducts: { DevProduct } = {
	{ Key = "StarterPack", Id = 0, Name = "Starter Pack", Price = 49, Description = "$5,000 + 3 Spins + 3 Shark Repellents. Once per player!", Color = Color3.fromRGB(255, 120, 180), OneTime = true },
	{ Key = "SharkRepellent", Id = 0, Name = "Shark Repellent", Price = 29, Description = "No shark for your next 3 swims", Color = Color3.fromRGB(80, 200, 160) },
	{ Key = "SuperJump", Id = 0, Name = "Super Jump", Price = 15, Description = "Your next jump goes 20% farther", Color = Color3.fromRGB(80, 220, 255) },
	{ Key = "Spin1", Id = 0, Name = "1 Spin", Price = 25, Description = "One extra spin of the wheel", Color = Color3.fromRGB(255, 120, 60), ShowOdds = true },
	{ Key = "Boost30", Id = 0, Name = "2x Money (30 min)", Price = 49, Description = "Double money for 30 minutes", Color = Color3.fromRGB(255, 200, 40) },
	{ Key = "MoneyBag", Id = 0, Name = "Money Bag", Price = 49, Description = "Money equal to 15 minutes of house income", Color = Color3.fromRGB(80, 200, 120) },
	{ Key = "Spins5", Id = 0, Name = "5 Spins", Price = 99, Description = "Five extra spins of the wheel", Color = Color3.fromRGB(255, 90, 150), ShowOdds = true },
	{ Key = "MoneyChest", Id = 0, Name = "Money Chest", Price = 149, Description = "Money equal to 1 hour of house income", Color = Color3.fromRGB(170, 80, 255) },
}

-- Je aspoň jeden produkt nebo pass založený? (jinak se Robux obchod ve hře vůbec neukáže)
local function anyConfigured(): boolean
	for _, pass in GamePasses do
		if pass.Id ~= 0 then
			return true
		end
	end
	for _, product in DevProducts do
		if product.Id ~= 0 then
			return true
		end
	end
	return false
end

local function isConfigured(key: string): boolean
	for _, pass in GamePasses do
		if pass.Key == key then
			return pass.Id ~= 0
		end
	end
	for _, product in DevProducts do
		if product.Key == key then
			return product.Id ~= 0
		end
	end
	return false
end

return {
	AnyConfigured = anyConfigured,
	IsConfigured = isConfigured,
	GamePasses = GamePasses,
	DevProducts = DevProducts,
	-- Hodnoty produktů
	BoostMinutes = 30,
	MoneyBagSeconds = 15 * 60,
	MoneyChestSeconds = 60 * 60,
	MinMoneyPack = 500, -- aby balíček měl smysl i na úplném začátku
	PassSlots = 5,
	VipExtraDailySpins = 1,
	StarterPack = { Money = 5_000, Spins = 3, Repellents = 3 },
}

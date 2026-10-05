--!strict
-- Robux obchod. Id zkopírujte z Creator Dashboard (Monetization → Passes / Developer Products).
-- Id = 0 znamená "ještě nezaloženo" – ve zveřejněné hře se takový produkt neukáže.
-- Ve Studiu se ukazuje všechno a nákup se jen "nasimuluje" zdarma (StudioTestPurchase), aby šlo vše vyzkoušet.

local RunService = game:GetService("RunService")

export type GamePass = { Key: string, Id: number, Name: string, Price: number, Description: string, Color: Color3 }
export type DevProduct = { Key: string, Id: number, Name: string, Price: number, Description: string, Color: Color3, ShowOdds: boolean?, OneTime: boolean?, Hidden: boolean?, Random: boolean? }

local GamePasses: { GamePass } = {
	{ Key = "RainbowTrail", Id = 2005617527, Name = "Rainbow Trail", Price = 49, Description = "A rainbow trail behind every jump", Color = Color3.fromRGB(255, 110, 200) },
	{ Key = "AutoCollect", Id = 2006823498, Name = "Auto Collect", Price = 99, Description = "Money from your house is collected automatically", Color = Color3.fromRGB(80, 200, 120) },
	{ Key = "PlusSlots", Id = 2006403514, Name = "+5 Slots", Price = 149, Description = "5 more item spots in your house", Color = Color3.fromRGB(60, 160, 255) },
	{ Key = "DoubleMoney", Id = 2007609413, Name = "2x Money", Price = 199, Description = "Double money from everything, forever", Color = Color3.fromRGB(255, 200, 40) },
	{ Key = "TurboFins", Id = 2006985504, Name = "Turbo Fins", Price = 149, Description = "Swim 30% faster, forever. Outswim every sea monster!", Color = Color3.fromRGB(60, 200, 255) },
	{ Key = "SuperJumper", Id = 2006637483, Name = "Super Jumper", Price = 199, Description = "+25% jump distance, forever", Color = Color3.fromRGB(80, 220, 255) },
	{ Key = "LuckyCharm", Id = 2007627481, Name = "Lucky Charm", Price = 179, Description = "Rarer items from the water, forever (1.5x luck)", Color = Color3.fromRGB(90, 220, 140) },
	{ Key = "VIP", Id = 2004969517, Name = "VIP", Price = 249, Description = "Golden name and +1 daily spin", Color = Color3.fromRGB(255, 170, 30) },
	{ Key = "TreasureHunter", Id = 2006997458, Name = "Treasure Hunter", Price = 149, Description = "+1 diamond every jump, rarer diamonds and more treasure balloons, forever!", Color = Color3.fromRGB(120, 220, 255) },
	{ Key = "AllSneakers", Id = 2005863531, Name = "All Sneaker Skins", Price = 299, Description = "Unlock all 20 sneaker skins, forever!", Color = Color3.fromRGB(255, 90, 160) },
}

local DevProducts: { DevProduct } = {
	{ Key = "StarterPack", Id = 0, Name = "Starter Pack", Price = 49, Description = "$5,000 + 3 Spins + 3 Shark Repellents + Street Runners skin. Once per player!", Color = Color3.fromRGB(255, 120, 180), OneTime = true, Random = true }, -- obsahuje točení = náhodná odměna
	{ Key = "SharkRepellent", Id = 0, Name = "Shark Repellent", Price = 29, Description = "No sharks or sea monsters for your next 3 swims", Color = Color3.fromRGB(80, 200, 160) },
	{ Key = "BubbleShield", Id = 0, Name = "Bubble Shield", Price = 25, Description = "Your next 5 slaloms: one free bump each (no stun)", Color = Color3.fromRGB(190, 120, 255) },
	-- úkoly na cestu z dárkových ostrovů (nabízí se jen tam, v obchodě skryté)
	{ Key = "TrialEasy", Id = 0, Name = "Easy Path", Price = 19, Description = "Easier island challenge: wider gates, slower chaser, respawn right where you fell", Color = Color3.fromRGB(80, 200, 255), Hidden = true },
	{ Key = "TrialSkip", Id = 0, Name = "Skip Challenge", Price = 39, Description = "Go home right now and still get the challenge bonus", Color = Color3.fromRGB(255, 180, 40), Hidden = true },
	{ Key = "SuperJump", Id = 0, Name = "Super Jump", Price = 15, Description = "Your next jump goes 20% farther", Color = Color3.fromRGB(80, 220, 255) },
	{ Key = "MegaJumpPack", Id = 0, Name = "Mega Jump Pack", Price = 39, Description = "Your next 3 jumps go 50% farther", Color = Color3.fromRGB(255, 140, 60) },
	{ Key = "Spin1", Id = 0, Name = "1 Spin", Price = 25, Description = "One extra spin of the wheel", Color = Color3.fromRGB(255, 120, 60), ShowOdds = true, Random = true },
	{ Key = "Boost30", Id = 0, Name = "2x Money (30 min)", Price = 49, Description = "Double money for 30 minutes", Color = Color3.fromRGB(255, 200, 40) },
	{ Key = "LuckyPotion", Id = 0, Name = "Lucky Potion", Price = 39, Description = "2x luck for rarer items for 15 minutes", Color = Color3.fromRGB(120, 230, 120) },
	{ Key = "MoneyBag", Id = 0, Name = "Money Bag", Price = 49, Description = "Money equal to 15 minutes of house income", Color = Color3.fromRGB(80, 200, 120) },
	{ Key = "Spins5", Id = 0, Name = "5 Spins", Price = 99, Description = "Five extra spins of the wheel", Color = Color3.fromRGB(255, 90, 150), ShowOdds = true, Random = true },
	{ Key = "MoneyChest", Id = 0, Name = "Money Chest", Price = 149, Description = "Money equal to 1 hour of house income", Color = Color3.fromRGB(170, 80, 255) },
	{ Key = "Spins10", Id = 0, Name = "10 Spins", Price = 179, Description = "Ten extra spins of the wheel (best value!)", Color = Color3.fromRGB(255, 60, 120), ShowOdds = true, Random = true },
	-- Skiny tenisek: jeden produkt na cenovou skupinu, který skin hráč chce, si server pamatuje (SelectSkin)
	{ Key = "SkinTier1", Id = 0, Name = "Sneaker Skin", Price = 19, Description = "One sneaker skin (looks only)", Color = Color3.fromRGB(120, 180, 255), Hidden = true },
	{ Key = "SkinTier2", Id = 0, Name = "Cool Sneaker Skin", Price = 39, Description = "One sneaker skin (looks only)", Color = Color3.fromRGB(120, 220, 140), Hidden = true },
	{ Key = "SkinTier3", Id = 0, Name = "Epic Sneaker Skin", Price = 69, Description = "One sneaker skin (looks only)", Color = Color3.fromRGB(180, 110, 255), Hidden = true },
	{ Key = "SkinTier4", Id = 0, Name = "Legendary Sneaker Skin", Price = 99, Description = "One sneaker skin (looks only)", Color = Color3.fromRGB(255, 200, 40), Hidden = true },
}

-- Je aspoň jeden produkt nebo pass založený? (jinak se Robux obchod ve hře vůbec neukáže)
local function anyConfigured(): boolean
	if RunService:IsStudio() then
		return true
	end
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
	if RunService:IsStudio() then
		return true -- ve Studiu jde vyzkoušet všechno
	end
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
	StarterPack = { Money = 5_000, Spins = 3, Repellents = 3, Skin = "StreetRunners" },
	FreeSkin = "MuddyOldSneakers", -- první skin má každý zdarma
	-- cenová skupina skinu podle pozice tenisky v řadě (1 = zdarma)
	SkinTier = function(index: number): number
		if index <= 1 then
			return 0
		elseif index <= 5 then
			return 1
		elseif index <= 10 then
			return 2
		elseif index <= 15 then
			return 3
		end
		return 4
	end,
	-- Nové passy a produkty (efekty počítá jen server)
	SuperJumperBonus = 0.25, -- pass Super Jumper: +25 % ke vzdálenosti (limity vzdálenosti platí dál)
	LuckyCharmLuck = 1.5, -- pass Lucky Charm: násobič štěstí natrvalo
	LuckyPotionLuck = 2, -- produkt Lucky Potion: 2× štěstí
	LuckyPotionMinutes = 15, -- čas se sčítá (jako 2x Money boost)
	BubbleShieldCharges = 5, -- produkt Bubble Shield: na kolik slalomů
	MegaJumpCharges = 3, -- produkt Mega Jump Pack: počet skoků
	MegaJumpBonus = 0.50, -- +50 % ke vzdálenosti
	PremiumIncomeBonus = 0.10, -- Roblox Premium: +10 % peněz
	OfferCooldown = 10 * 60, -- kontextová nabídka nejvýš jednou za 10 minut
}

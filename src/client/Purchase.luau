--!strict
-- Jedno místo pro všechny nákupy za Robux (game passy i developer products).
-- Ve Studiu se nezaložený produkt (Id = 0) "koupí" zdarma přes StudioTestPurchase, aby šlo vše vyzkoušet.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Products = require(Shared.Config.Products)
local Net = require(Shared.Net)

local Purchase = {}

-- Vrací false, když produkt není založený (a nejsme ve Studiu)
function Purchase.Prompt(key: string): boolean
	local player = Players.LocalPlayer
	for _, pass in Products.GamePasses do
		if pass.Key == key then
			if pass.Id ~= 0 then
				MarketplaceService:PromptGamePassPurchase(player, pass.Id)
				return true
			end
			break
		end
	end
	for _, product in Products.DevProducts do
		if product.Key == key then
			if product.Id ~= 0 then
				MarketplaceService:PromptProductPurchase(player, product.Id)
				return true
			end
			break
		end
	end
	if RunService:IsStudio() then
		Net.Event("StudioTestPurchase"):FireServer(key)
		return true
	end
	return false
end

function Purchase.Price(key: string): number
	for _, pass in Products.GamePasses do
		if pass.Key == key then
			return pass.Price
		end
	end
	for _, product in Products.DevProducts do
		if product.Key == key then
			return product.Price
		end
	end
	return 0
end

-- Skin tenisek: řekneme serveru, který chceme, a otevřeme nákup jeho cenové skupiny
function Purchase.Skin(id: string, index: number): boolean
	local tier = Products.SkinTier(index)
	if tier <= 0 then
		return false
	end
	Net.Event("SelectSkin"):FireServer(id)
	return Purchase.Prompt("SkinTier" .. tier)
end

return Purchase

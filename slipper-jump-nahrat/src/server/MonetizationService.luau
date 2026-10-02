--!strict
-- Game passy a developer products. ProcessReceipt je chráněný proti dvojímu připsání:
-- PurchaseId se uloží do profilu a nákup se potvrdí až po úspěšném uložení.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Products = require(Shared.Config.Products)
local Swim = require(Shared.Config.Swim)
local Catalog = require(Shared.Catalog)
local FormatNumber = require(Shared.Util.FormatNumber)
local Net = require(Shared.Net)

local Registry = require(script.Parent.Registry)

type Session = any

local MonetizationService = {}

local passByKey: { [string]: Products.GamePass } = {}
local passById: { [number]: Products.GamePass } = {}
for _, pass in Products.GamePasses do
	passByKey[pass.Key] = pass
	if pass.Id ~= 0 then
		passById[pass.Id] = pass
	end
end

local productById: { [number]: Products.DevProduct } = {}
for _, product in Products.DevProducts do
	if product.Id ~= 0 then
		productById[product.Id] = product
	end
end

local MAX_PURCHASE_IDS = 50

local function applyPass(session: Session, key: string)
	session.Passes[key] = true
	if key == "PlusSlots" then
		Registry.House.Render(session)
		Registry.Items.FlushStorage(session)
	elseif key == "VIP" then
		Registry.Avatar.UpdateOverhead(session)
	elseif key == "RainbowTrail" then
		Registry.Avatar.ApplySlippers(session)
	elseif key == "AutoCollect" then
		Registry.Economy.CollectPiggy(session)
	elseif key == "AllSneakers" then
		Registry.Avatar.ApplySlippers(session)
	end
	Registry.House.Render(session)
	Registry.Player.MarkDirty(session)
end

function MonetizationService.LoadPasses(session: Session)
	local player: Player = session.Player
	for _, pass in Products.GamePasses do
		if pass.Id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok and owns then
				session.Passes[pass.Key] = true
			end
		end
	end
end

function MonetizationService.HasPass(session: Session, key: string): boolean
	return session.Passes[key] == true and passByKey[key] ~= nil
end

-- Peněžní balíček podle aktuálního příjmu (aby byl užitečný na začátku i na konci hry)
local function moneyPack(session: Session, seconds: number): number
	local income = Registry.Economy.IncomePerSecond(session)
	return math.max(Products.MinMoneyPack, math.floor(income * seconds))
end

-- Skin tenisek z cenové skupiny: přednostně ten, který si hráč vybral (SelectSkin), jinak první nevlastněný
local function grantSkinTier(session: Session, tier: number)
	local player: Player = session.Player
	local chosen: string? = nil
	local pending = session.PendingSkin
	if pending then
		local index = Catalog.SlipperIndex(pending)
		if Products.SkinTier(index) == tier and not Registry.Shop.OwnsSkin(session, pending) then
			chosen = pending
		end
	end
	if not chosen then
		for index, cfg in Catalog.Sneakers do
			if Products.SkinTier(index) == tier and not Registry.Shop.OwnsSkin(session, cfg.Id) then
				chosen = cfg.Id
				break
			end
		end
	end
	session.PendingSkin = nil
	if chosen then
		Registry.Shop.GrantSkin(session, chosen)
		local cfg = Catalog.Slipper(chosen)
		Registry.Player.Notify(player, "New skin: " .. (if cfg then cfg.Name else chosen) .. "! You're wearing it now.", "Success")
		Net.Event("PlayEffect"):FireClient(player, "Purchase", { Id = chosen })
	else
		-- všechny skiny skupiny už má → aspoň peníze, ať nákup nepropadne
		local amount = moneyPack(session, Products.MoneyBagSeconds)
		Registry.Economy.AddMoney(session, amount)
		Registry.Player.Notify(player, "You already own all these skins! Here is " .. FormatNumber.Money(amount) .. " instead.", "Money")
	end
end

local function grantProduct(session: Session, product: Products.DevProduct)
	local player: Player = session.Player
	local key = product.Key
	local skinTier = string.match(key, "^SkinTier(%d)$")
	if skinTier then
		grantSkinTier(session, tonumber(skinTier) or 1)
	elseif key == "StarterPack" then
		local pack = Products.StarterPack
		session.Data.StarterPackBought = true
		Registry.Economy.AddMoney(session, pack.Money)
		Registry.Spinner.AddSpins(session, pack.Spins)
		session.Data.Repellents += pack.Repellents
		Registry.Shop.GrantSkin(session, pack.Skin)
		Registry.Player.Notify(player, "Starter Pack unlocked! Have fun!", "Success")
	elseif key == "SharkRepellent" then
		session.Data.Repellents += Swim.RepellentSwims
		Registry.Player.Notify(player, "Shark Repellent! No sharks or sea monsters for your next " .. Swim.RepellentSwims .. " swims.", "Success")
	elseif key == "SuperJump" then
		session.Data.SuperJumps += 1
		Registry.Player.Notify(player, "Super Jump ready! Your next jump goes 20% farther.", "Success")
	elseif key == "MegaJumpPack" then
		session.Data.MegaJumps += Products.MegaJumpCharges
		Registry.Player.Notify(player, "Mega Jumps ready! Your next " .. Products.MegaJumpCharges .. " jumps go 50% farther.", "Success")
	elseif key == "LuckyPotion" then
		Registry.Economy.AddLuck(session, Products.LuckyPotionMinutes)
		Registry.Player.Notify(player, "Lucky Potion! 2x luck for " .. Products.LuckyPotionMinutes .. " minutes.", "Success")
	elseif key == "Spin1" then
		Registry.Spinner.AddSpins(session, 1)
		Registry.Player.Notify(player, "+1 Spin!", "Success")
	elseif key == "Spins5" then
		Registry.Spinner.AddSpins(session, 5)
		Registry.Player.Notify(player, "+5 Spins!", "Success")
	elseif key == "Spins10" then
		Registry.Spinner.AddSpins(session, 10)
		Registry.Player.Notify(player, "+10 Spins!", "Success")
	elseif key == "Boost30" then
		Registry.Economy.AddBoost(session, Products.BoostMinutes)
		Registry.Player.Notify(player, "2x Money for " .. Products.BoostMinutes .. " minutes!", "Success")
	elseif key == "MoneyBag" then
		local amount = moneyPack(session, Products.MoneyBagSeconds)
		Registry.Economy.AddMoney(session, amount)
		Registry.Player.Notify(player, "+" .. FormatNumber.Money(amount) .. "!", "Money")
	elseif key == "MoneyChest" then
		local amount = moneyPack(session, Products.MoneyChestSeconds)
		Registry.Economy.AddMoney(session, amount)
		Registry.Player.Notify(player, "+" .. FormatNumber.Money(amount) .. "!", "Money")
	end
	Registry.Player.MarkDirty(session)
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- počkat, až se načtou data hráče
	local session = Registry.Player.Get(player)
	local waited = 0
	while not session and waited < 10 and player.Parent == Players do
		task.wait(0.5)
		waited += 0.5
		session = Registry.Player.Get(player)
	end
	local product = productById[receipt.ProductId]
	if not session or not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = session.Profile
	if not profile:IsActive() then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	local ids = session.Data.PurchaseIds
	if not table.find(ids, purchaseId) then
		while #ids >= MAX_PURCHASE_IDS do
			table.remove(ids, 1)
		end
		table.insert(ids, purchaseId)
		grantProduct(session, product)
	end
	-- potvrdit až po uložení (ochrana proti dvojímu připsání i ztrátě nákupu)
	local result: Enum.ProductPurchaseDecision? = nil
	local function check(savedData: any)
		local saved = savedData and savedData.PurchaseIds
		if saved and table.find(saved, purchaseId) then
			result = Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	check(profile.LastSavedData)
	if result == nil then
		local connection = profile.OnAfterSave:Connect(check)
		profile:Save()
		local timeout = os.clock() + 30
		while result == nil and profile:IsActive() and os.clock() < timeout do
			task.wait()
		end
		connection:Disconnect()
	end
	return result or Enum.ProductPurchaseDecision.NotProcessedYet
end

function MonetizationService.Start()
	MarketplaceService.ProcessReceipt = processReceipt
	-- hráč si v obchodě vybral konkrétní skin, pak se otevře nákup jeho cenové skupiny
	Net.Event("SelectSkin").OnServerEvent:Connect(function(player, id)
		local session = Registry.Player.Get(player)
		if session and type(id) == "string" and Catalog.Slipper(id) then
			session.PendingSkin = id
		end
	end)
	-- jen ve Studiu: "nákup" zdarma, aby šlo všechno vyzkoušet bez založených produktů
	Net.Event("StudioTestPurchase").OnServerEvent:Connect(function(player, key)
		if not RunService:IsStudio() or type(key) ~= "string" then
			return
		end
		local session = Registry.Player.Get(player)
		if not session then
			return
		end
		local pass = passByKey[key]
		if pass then
			applyPass(session, key)
			Registry.Player.Notify(player, "[Studio test] " .. pass.Name .. " is now active!", "Success")
			return
		end
		for _, product in Products.DevProducts do
			if product.Key == key then
				grantProduct(session, product)
				return
			end
		end
	end)
	-- Roblox Premium (+10 % peněz): po koupi nebo zrušení Premium během hry přepočítat příjem
	Players.PlayerMembershipChanged:Connect(function(player)
		local session = Registry.Player.Get(player)
		if session then
			Registry.House.Render(session)
			Registry.Player.MarkDirty(session)
		end
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local pass = passById[passId]
		local session = Registry.Player.Get(player)
		if pass and session then
			applyPass(session, pass.Key)
			Registry.Player.Notify(player, "Thank you! " .. pass.Name .. " is now active!", "Success")
		end
	end)
end


return MonetizationService

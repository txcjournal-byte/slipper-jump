--!strict
-- Stánek SHOP (pantofle a čepice) a stánek SELL (prodej předmětu, který hráč nese nad hlavou).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog = require(Shared.Catalog)
local Swim = require(Shared.Config.Swim)
local Formulas = require(Shared.Formulas)
local FormatNumber = require(Shared.Util.FormatNumber)
local Net = require(Shared.Net)

local Registry = require(script.Parent.Registry)

type Session = any
type Result = { Ok: boolean, Message: string }

local ShopService = {}

local SHOP_RANGE = 45

local function nearShop(player: Player): boolean
	local root = Registry.Player.GetRoot(player)
	return root ~= nil and (root.Position - Registry.Map.ShopPosition).Magnitude <= SHOP_RANGE
end

local function buySlippers(session: Session, id: string): Result
	local cfg = Catalog.Slipper(id)
	if not cfg then
		return { Ok = false, Message = "Unknown slippers." }
	end
	local data = session.Data
	if table.find(data.OwnedSlippers, id) then
		return { Ok = false, Message = "You already own these!" }
	end
	if not nearShop(session.Player) then
		return { Ok = false, Message = "Buy slippers at the SHOP on the beach!" }
	end
	if not Registry.Economy.Spend(session, cfg.Price) then
		return { Ok = false, Message = "Not enough money! You need " .. FormatNumber.Money(cfg.Price) .. "." }
	end
	table.insert(data.OwnedSlippers, id)
	data.EquippedSlippers = id
	Registry.Avatar.ApplySlippers(session)
	Registry.Tutorial.OnPurchase(session)
	Net.Event("PlayEffect"):FireClient(session.Player, "Purchase", { Id = id })
	return { Ok = true, Message = "You bought " .. cfg.Name .. "!" }
end

local function buyHat(session: Session, id: string): Result
	local cfg = Catalog.Hat(id)
	if not cfg then
		return { Ok = false, Message = "Unknown hat." }
	end
	local data = session.Data
	if table.find(data.OwnedHats, id) then
		return { Ok = false, Message = "You already own this hat!" }
	end
	local price = cfg.Price
	if price == nil then
		return { Ok = false, Message = cfg.Source or "This hat can't be bought." }
	end
	if not nearShop(session.Player) then
		return { Ok = false, Message = "Buy hats at the SHOP on the beach!" }
	end
	if not Registry.Economy.Spend(session, price) then
		return { Ok = false, Message = "Not enough money! You need " .. FormatNumber.Money(price) .. "." }
	end
	table.insert(data.OwnedHats, id)
	data.EquippedHat = id
	Registry.Avatar.ApplyHat(session)
	Registry.House.Render(session)
	Net.Event("PlayEffect"):FireClient(session.Player, "Purchase", { Id = id })
	return { Ok = true, Message = "You bought " .. cfg.Name .. "!" }
end

-- vylepšení plavání se kupují postupně (vždy jen to další)
local function buySwim(session: Session, id: string): Result
	local data = session.Data
	local nextUpgrade = Swim.Upgrades[data.SwimLevel + 1]
	if not nextUpgrade then
		return { Ok = false, Message = "You already swim as fast as possible!" }
	end
	if nextUpgrade.Id ~= id then
		return { Ok = false, Message = "Buy " .. nextUpgrade.Name .. " first!" }
	end
	if not nearShop(session.Player) then
		return { Ok = false, Message = "Buy swim gear at the SHOP on the beach!" }
	end
	if not Registry.Economy.Spend(session, nextUpgrade.Price) then
		return { Ok = false, Message = "Not enough money! You need " .. FormatNumber.Money(nextUpgrade.Price) .. "." }
	end
	data.SwimLevel += 1
	Net.Event("PlayEffect"):FireClient(session.Player, "Purchase", { Id = id })
	return { Ok = true, Message = "You bought " .. nextUpgrade.Name .. "! You swim faster now." }
end

function ShopService.GrantHat(session: Session, id: string)
	local data = session.Data
	if Catalog.Hat(id) and not table.find(data.OwnedHats, id) then
		table.insert(data.OwnedHats, id)
		Registry.Player.MarkDirty(session)
	end
end

local function handleAction(player: Player, action: unknown, kind: unknown, id: unknown): Result
	local session = Registry.Player.Get(player)
	if not session or type(action) ~= "string" or type(kind) ~= "string" or type(id) ~= "string" then
		return { Ok = false, Message = "Try again." }
	end
	local data = session.Data
	local result: Result
	if action == "Buy" and kind == "Slippers" then
		result = buySlippers(session, id)
	elseif action == "Buy" and kind == "Hats" then
		result = buyHat(session, id)
	elseif action == "Buy" and kind == "Swim" then
		result = buySwim(session, id)
	elseif action == "Equip" and kind == "Slippers" then
		if not table.find(data.OwnedSlippers, id) then
			return { Ok = false, Message = "You don't own these yet." }
		end
		data.EquippedSlippers = id
		Registry.Avatar.ApplySlippers(session)
		result = { Ok = true, Message = "Equipped!" }
	elseif action == "Equip" and kind == "Hats" then
		if id ~= "" and not table.find(data.OwnedHats, id) then
			return { Ok = false, Message = "You don't own this hat yet." }
		end
		data.EquippedHat = id
		Registry.Avatar.ApplyHat(session)
		Registry.House.Render(session)
		result = { Ok = true, Message = if id == "" then "Hat removed." else "Equipped!" }
	else
		result = { Ok = false, Message = "Unknown action." }
	end
	Registry.Player.MarkDirty(session)
	return result
end

-- ===== Prodej =====

local pendingConfirm: { [Player]: number } = {}

function ShopService.Sell(session: Session, confirmed: boolean)
	local player: Player = session.Player
	local carried = session.Data.Carried
	if not carried then
		Registry.Player.Notify(player, "Pick up an item in your house and bring it here to sell it!", "Info")
		return
	end
	local cfg = Catalog.Item(carried.Id)
	if not cfg or cfg.CanSell == false then
		Registry.Player.Notify(player, "This item is too special to sell!", "Warning")
		return
	end
	local price = math.floor(Formulas.SellPrice(carried.Id) * Registry.Economy.Multiplier(session))
	local rarity = Catalog.Rarity(cfg.Rarity)
	if rarity.ConfirmSell and not confirmed then
		pendingConfirm[player] = carried.Uid
		Net.Event("ConfirmSell"):FireClient(player, { Uid = carried.Uid, Id = carried.Id, Price = price })
		return
	end
	Registry.Items.TakeCarried(session)
	Registry.Economy.AddMoney(session, price)
	Registry.Quests.Progress(session, "Sells", 1)
	Registry.Player.Notify(player, "Sold " .. cfg.Name .. " for " .. FormatNumber.Money(price) .. "!", "Money")
	Net.Event("PlayEffect"):FireClient(player, "Collect", { Amount = price })
end

function ShopService.Start()
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		pendingConfirm[player] = nil
	end)
	Net.Function("ShopAction").OnServerInvoke = handleAction
	Registry.Map.SellPrompt.Triggered:Connect(function(player)
		local session = Registry.Player.Get(player)
		if session and not session.Flight then
			ShopService.Sell(session, false)
		end
	end)
	Registry.Map.ShopPrompt.Triggered:Connect(function(player)
		Net.Event("OpenUI"):FireClient(player, "Shop")
	end)
	Net.Event("ConfirmSell").OnServerEvent:Connect(function(player, uid, accepted)
		local session = Registry.Player.Get(player)
		local expected = pendingConfirm[player]
		pendingConfirm[player] = nil
		if not session or accepted ~= true or expected == nil or uid ~= expected then
			return
		end
		local carried = session.Data.Carried
		local root = Registry.Player.GetRoot(player)
		local sellPart = Registry.Map.SellPrompt.Parent
		if carried and carried.Uid == uid and root and sellPart and sellPart:IsA("BasePart") and (root.Position - sellPart.Position).Magnitude < 30 then
			ShopService.Sell(session, true)
		end
	end)
end

return ShopService

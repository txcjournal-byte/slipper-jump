--!strict
-- Domečky: přidělení hráči, podstavce s předměty, kasička u vchodu, zelený teleport k SELL.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog = require(Shared.Catalog)
local Formulas = require(Shared.Formulas)
local FormatNumber = require(Shared.Util.FormatNumber)
local Models = require(Shared.Models)

local Registry = require(script.Parent.Registry)
local HouseTiers = require(script.Parent.HouseTiers)
local House = require(Shared.Config.House)
local Net = require(Shared.Net)

type Session = any

local HouseService = {}

local owners: { [number]: Session } = {}

local function playerFromHit(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")
	if character then
		return Players:GetPlayerFromCharacter(character)
	end
	return nil
end

function HouseService.Assign(session: Session)
	for _, house in Registry.Map.Houses do
		if owners[house.Index] == nil then
			owners[house.Index] = session
			session.House = house
			house.Model:SetAttribute("OwnerUserId", session.Player.UserId)
			for _, label in house.OwnerLabels do
				label.Text = session.Player.DisplayName
			end
			HouseService.Render(session)
			HouseService.CheckTier(session, false)
			HouseTiers.Apply(house, session.Data.HouseTier or 1)
			return
		end
	end
	warn("[HouseService] No free house for", session.Player.Name)
	Registry.Player.Notify(session.Player, "All houses are taken on this server. Your items are safe – join another server to get a house!", "Warning")
end

function HouseService.Release(session: Session)
	local house = session.House
	if not house then
		return
	end
	owners[house.Index] = nil
	session.House = nil
	house.Model:SetAttribute("OwnerUserId", 0)
	for _, label in house.OwnerLabels do
		label.Text = "Free House"
	end
	house.PiggyLabel.Text = "$0"
	HouseTiers.Apply(house, 0)
	for _, pedestal in house.Pedestals do
		local old = pedestal.Part:FindFirstChild("ItemModel")
		if old then
			old:Destroy()
		end
		pedestal.Label.Text = ""
		pedestal.Prompt:SetAttribute("Active", false)
		pedestal.Part.Transparency = 0
	end
end

function HouseService.UpdatePiggy(session: Session)
	local house = session.House
	if house then
		if session.Passes.AutoCollect then
			house.PiggyLabel.Text = "AUTO"
		else
			house.PiggyLabel.Text = FormatNumber.Money(session.Data.PendingCash)
		end
	end
end

-- Aktualizuje texty a stav výzev (Pick Up / Place / Swap) podle toho, co hráč nese
function HouseService.UpdatePrompts(session: Session)
	local house = session.House
	if not house then
		return
	end
	local data = session.Data
	local total = Formulas.TotalSlots(data.Level, session.Passes.PlusSlots == true)
	local carrying = data.Carried ~= nil
	for _, pedestal in house.Pedestals do
		local item = data.HouseSlots[tostring(pedestal.Index)]
		local prompt = pedestal.Prompt
		local unlocked = pedestal.Index <= total
		local active = false
		if unlocked then
			if carrying then
				active = true
				prompt.ActionText = if item then "Swap" else "Place"
			elseif item then
				active = true
				prompt.ActionText = "Pick Up"
			end
		end
		local cfg = item and Catalog.Item(item.Id)
		prompt.ObjectText = if cfg then cfg.Name else ""
		prompt:SetAttribute("Active", active)
	end
end

-- Zkontroluje, jestli si hráč nezasloužil lepší domeček (level, dárkový ostrov, Obří dárek).
-- Úroveň nikdy neklesá (ani po rebirthu). celebrate = oslava a oznámení (při přihlášení ne).
function HouseService.CheckTier(session: Session, celebrate: boolean?)
	local data = session.Data
	local current = data.HouseTier or 1
	local earned = HouseTiers.Earned(data)
	if earned <= current then
		data.HouseTier = current
		return
	end
	data.HouseTier = earned
	Registry.Player.MarkDirty(session)
	if session.House then
		HouseTiers.Apply(session.House, earned)
	end
	if celebrate ~= false then
		local name = House.Tiers[earned].Name
		-- chvíli počkat, ať oslava nepřekryje okno s odměnou (level up / dárek)
		task.delay(3.5, function()
			if session.Player.Parent then
				Net.Event("PlayEffect"):FireClient(session.Player, "HouseUpgrade", { Tier = earned, Name = name })
			end
		end)
		if earned >= 4 then
			Registry.Player.Announce(`🏠 {session.Player.DisplayName} upgraded their house to a {string.upper(name)}!`, "Gift")
		end
	end
end

-- Testovací panel ve Studiu: nastavit vzhled domečku natvrdo
function HouseService.SetTier(session: Session, tier: number)
	session.Data.HouseTier = math.clamp(math.floor(tier), 1, #House.Tiers)
	if session.House then
		HouseTiers.Apply(session.House, session.Data.HouseTier)
	end
end

-- Postaví modely předmětů na podstavce
function HouseService.Render(session: Session)
	local house = session.House
	if not house then
		return
	end
	local data = session.Data
	local total = Formulas.TotalSlots(data.Level, session.Passes.PlusSlots == true)
	local multiplier = Registry.Economy.Multiplier(session)
	for _, pedestal in house.Pedestals do
		local item = data.HouseSlots[tostring(pedestal.Index)]
		local old = pedestal.Part:FindFirstChild("ItemModel")
		local unlocked = pedestal.Index <= total
		pedestal.Part.Transparency = if unlocked then 0 else 0.6
		local top = pedestal.Part:FindFirstChild("Top")
		if top and top:IsA("BasePart") then
			top.Transparency = if unlocked then 0 else 0.6
			-- horní deska svítí barvou vzácnosti předmětu
			if top:GetAttribute("BaseColor") == nil then
				top:SetAttribute("BaseColor", top.Color)
			end
			local itemCfg = item and Catalog.Item(item.Id)
			if itemCfg and Catalog.Rarity(itemCfg.Rarity).Order >= 3 then
				local rarity = Catalog.Rarity(itemCfg.Rarity)
				top.Color = if rarity.Name == "Secret" then Color3.fromRGB(170, 90, 255) else rarity.Color
				top.Material = Enum.Material.Neon
			else
				top.Color = top:GetAttribute("BaseColor") :: Color3
				top.Material = Enum.Material.SmoothPlastic
			end
		end
		if item then
			if not old or old:GetAttribute("Uid") ~= item.Uid then
				if old then
					old:Destroy()
				end
				local m = Models.Item(item.Id)
				Models.Anchor(m)
				m.Name = "ItemModel"
				m:SetAttribute("Uid", item.Uid)
				m:PivotTo(pedestal.ItemCFrame)
				m.Parent = pedestal.Part
				CollectionService:AddTag(m, "SpinItem")
				local itemCfg = Catalog.Item(item.Id)
				if itemCfg then
					Models.AddRarityFx(m, itemCfg.Rarity)
				end
			end
			local cfg = Catalog.Item(item.Id)
			if cfg then
				local rarity = Catalog.Rarity(cfg.Rarity)
				pedestal.Label.Text = "+" .. FormatNumber.Money(cfg.Income * multiplier) .. "/s"
				pedestal.Label.TextColor3 = if rarity.Name == "Secret" then Color3.fromRGB(255, 255, 255) elseif rarity.Name == "Common" then Color3.fromRGB(150, 255, 150) else rarity.Color
			end
		else
			if old then
				old:Destroy()
			end
			pedestal.Label.Text = if unlocked then "" else "LOCKED"
			pedestal.Label.TextColor3 = Color3.fromRGB(200, 200, 210)
		end
	end
	HouseService.UpdatePrompts(session)
	HouseService.UpdatePiggy(session)
end

function HouseService.IsInside(session: Session, position: Vector3): boolean
	local house = session.House
	if not house then
		return false
	end
	local localPos = house.Center:PointToObjectSpace(position)
	local half = house.Size / 2
	return math.abs(localPos.X) <= half.X and math.abs(localPos.Z) <= half.Z and math.abs(localPos.Y) <= half.Y + 4
end

function HouseService.Start()
	for _, house in Registry.Map.Houses do
		for _, pedestal in house.Pedestals do
			pedestal.Prompt.Triggered:Connect(function(player)
				local session = Registry.Player.Get(player)
				if session and owners[house.Index] == session then
					Registry.Items.SlotAction(session, pedestal.Index)
				end
			end)
		end
		for _, pad in { house.CollectPad, house.BackCollectPad } do
			pad.Touched:Connect(function(hit)
				local player = playerFromHit(hit)
				local session = player and Registry.Player.Get(player)
				if session and owners[house.Index] == session and os.clock() - session.LastCollect > 1 then
					session.LastCollect = os.clock()
					Registry.Economy.CollectPiggy(session)
				end
			end)
		end
		house.TeleportPad.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			local session = player and Registry.Player.Get(player)
			if session and not session.Flight and os.clock() - session.LastTeleport > 2 then
				session.LastTeleport = os.clock()
				local character = player and player.Character
				if character then
					character:PivotTo(Registry.Map.SellTeleport)
				end
			end
		end)
	end
end

return HouseService

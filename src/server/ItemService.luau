--!strict
-- Předměty: losování podle místa dopadu, umístění do domečku / nad hlavu / do skladu,
-- zvedání, pokládání a výměna na podstavcích.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog = require(Shared.Catalog)
local ItemsConfig = require(Shared.Config.Items)
local Formulas = require(Shared.Formulas)
local Net = require(Shared.Net)

local Registry = require(script.Parent.Registry)
local DataService = require(script.Parent.DataService)

type Session = any
type ItemData = DataService.ItemData

export type Placement = "House" | "Carried" | "Storage"

local ItemService = {}

local rng = Random.new()

local rarityOrders: { [string]: number } = {}
for _, rarity in Catalog.Rarities do
	rarityOrders[rarity.Name] = rarity.Order
end

-- luck > 1 posune šance k vzácnějším raritám (Lucky Charm, Lucky Potion), viz Formulas.LuckyChances
function ItemService.RollRarity(distance: number, zoneShift: number?, luck: number?): string
	local zone = Catalog.Zones[math.min(Formulas.ZoneIndex(distance) + (zoneShift or 0), #Catalog.Zones)]
	local chances = Formulas.LuckyChances(zone.Chances, rarityOrders, luck or 1)
	local total = 0
	for _, chance in chances do
		total += chance
	end
	local roll = rng:NextNumber(0, total)
	-- pevné pořadí rarit, aby výsledek nezávisel na pořadí v tabulce
	for _, rarity in Catalog.Rarities do
		local chance = chances[rarity.Name]
		if chance then
			roll -= chance
			if roll <= 0 then
				return rarity.Name
			end
		end
	end
	return "Common"
end

function ItemService.RandomOfRarity(rarity: string): string
	local list = Catalog.DroppableItems(rarity)
	if #list == 0 then
		list = Catalog.DroppableItems("Common")
	end
	return list[rng:NextInteger(1, #list)].Id
end

function ItemService.Roll(distance: number, forcedRarity: string?, zoneShift: number?, luck: number?): string
	return ItemService.RandomOfRarity(forcedRarity or ItemService.RollRarity(distance, zoneShift, luck))
end

-- Aktuální štěstí hráče (počítá jen server)
function ItemService.Luck(session: Session): number
	return Formulas.LuckMultiplier(session.Passes.LuckyCharm == true, session.Data.LuckUntil, os.time())
end

function ItemService.FreeSlot(session: Session): number?
	local total = Formulas.TotalSlots(session.Data.Level, session.Passes.PlusSlots == true)
	for i = 1, total do
		if session.Data.HouseSlots[tostring(i)] == nil then
			return i
		end
	end
	return nil
end

local function newItem(session: Session, id: string): ItemData
	local uid = session.Data.NextUid
	session.Data.NextUid += 1
	return { Id = id, Uid = uid }
end

-- Vloží hotový předmět: první volný podstavec → nad hlavu → sklad
function ItemService.Store(session: Session, item: ItemData): Placement
	local data = session.Data
	local slot = ItemService.FreeSlot(session)
	local placement: Placement
	if slot then
		data.HouseSlots[tostring(slot)] = item
		placement = "House" :: Placement
	elseif data.Carried == nil then
		data.Carried = item
		placement = "Carried" :: Placement
	else
		table.insert(data.Storage, item)
		placement = "Storage" :: Placement
	end
	Registry.House.Render(session)
	Registry.Avatar.UpdateCarried(session)
	Registry.Player.MarkDirty(session)
	return placement
end

-- Album: hráč našel nový předmět → když má celou vzácnost, dostane (jednou) točení
function ItemService.CheckIndex(session: Session, id: string)
	local cfg = Catalog.Item(id)
	if not cfg then
		return
	end
	local data = session.Data
	local spins = ItemsConfig.IndexRewardSpins[cfg.Rarity]
	if not spins or data.IndexRewards[cfg.Rarity] then
		return
	end
	for _, other in Catalog.Items do
		if other.Rarity == cfg.Rarity and other.CanDrop ~= false and not data.Discovered[other.Id] then
			return
		end
	end
	data.IndexRewards[cfg.Rarity] = true
	Registry.Spinner.AddSpins(session, spins)
	Registry.Player.Notify(session.Player, `📖 You found every {cfg.Rarity} item! +{spins} Spin{if spins == 1 then "" else "s"}!`, "Success")
	Registry.Player.MarkDirty(session)
end

-- Nový předmět (drop, spinner, odměna). Vrací umístění a jestli je to první nález.
function ItemService.Give(session: Session, id: string): (ItemData, Placement, boolean)
	local item = newItem(session, id)
	local isNew = not session.Data.Discovered[id]
	session.Data.Discovered[id] = true
	local placement: Placement = ItemService.Store(session, item)
	if isNew then
		ItemService.CheckIndex(session, id)
	end
	local cfg = Catalog.Item(id)
	if cfg then
		local rarity = Catalog.Rarity(cfg.Rarity)
		if rarity.Order >= 6 then
			Registry.Player.Announce(`{session.Player.DisplayName} found a {rarity.Name} item: {if rarity.Name == "Secret" and isNew then "???" else cfg.Name}!`, rarity.Name)
		end
	end
	if placement == "Carried" then
		Registry.Player.Notify(session.Player, "Your house is full! Swap it for a weaker item, sell it or gift it.", "Warning")
	elseif placement == "Storage" then
		Registry.Player.Notify(session.Player, "Your hands are full, so the item went to your storage.", "Warning")
	end
	return item, placement, isNew
end

function ItemService.GiveRandom(session: Session, rarity: string): (ItemData, Placement, boolean)
	return ItemService.Give(session, ItemService.RandomOfRarity(rarity))
end

-- Pick Up / Place / Swap na podstavci
function ItemService.SlotAction(session: Session, slot: number)
	local data = session.Data
	if session.Flight then
		return
	end
	local total = Formulas.TotalSlots(data.Level, session.Passes.PlusSlots == true)
	if slot < 1 or slot > total then
		return
	end
	local key = tostring(slot)
	local onPedestal = data.HouseSlots[key]
	local carried = data.Carried
	if carried then
		data.HouseSlots[key] = carried
		data.Carried = onPedestal -- výměna (nebo nil, když byl podstavec prázdný)
	elseif onPedestal then
		data.Carried = onPedestal
		data.HouseSlots[key] = nil
	else
		return
	end
	Registry.House.Render(session)
	Registry.Avatar.UpdateCarried(session)
	Registry.Player.MarkDirty(session)
end

function ItemService.TakeCarried(session: Session): ItemData?
	local item = session.Data.Carried
	session.Data.Carried = nil
	Registry.House.UpdatePrompts(session)
	Registry.Avatar.UpdateCarried(session)
	Registry.Player.MarkDirty(session)
	return item
end

-- Ze skladu na volné podstavce (po přidání míst nebo při připojení)
function ItemService.FlushStorage(session: Session)
	local data = session.Data
	local changed = false
	while #data.Storage > 0 do
		local slot = ItemService.FreeSlot(session)
		if not slot then
			break
		end
		data.HouseSlots[tostring(slot)] = table.remove(data.Storage, 1)
		changed = true
	end
	if changed then
		Registry.House.Render(session)
		Registry.Player.MarkDirty(session)
	end
end

function ItemService.OnJoin(session: Session)
	-- odstranit neznámé předměty (např. smazané z Configu)
	for key, item in session.Data.HouseSlots do
		if not Catalog.Item(item.Id) then
			session.Data.HouseSlots[key] = nil
		end
	end
	ItemService.FlushStorage(session)
end

function ItemService.Start()
	-- vzít předmět ze skladu nad hlavu
	Net.Event("HoldStoredItem").OnServerEvent:Connect(function(player, uid)
		local session = Registry.Player.Get(player)
		if not session or type(uid) ~= "number" or session.Data.Carried or session.Flight then
			return
		end
		for index, item in session.Data.Storage do
			if item.Uid == uid then
				table.remove(session.Data.Storage, index)
				session.Data.Carried = item
				Registry.House.UpdatePrompts(session)
				Registry.Avatar.UpdateCarried(session)
				Registry.Player.MarkDirty(session)
				return
			end
		end
	end)
end

return ItemService

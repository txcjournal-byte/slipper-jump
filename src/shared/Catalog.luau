--!strict
-- Rychlé vyhledávání v Config modulech podle Id.

local Config = script.Parent.Config
local Slippers = require(Config.Slippers)
local Hats = require(Config.Hats)
local ItemsConfig = require(Config.Items)

local Catalog = {}

local slipperById: { [string]: Slippers.Slipper } = {}
local slipperIndex: { [string]: number } = {}
for index, slipper in Slippers do
	slipperById[slipper.Id] = slipper
	slipperIndex[slipper.Id] = index
end

local hatById: { [string]: Hats.Hat } = {}
for _, hat in Hats do
	hatById[hat.Id] = hat
end

local itemById: { [string]: ItemsConfig.Item } = {}
local itemsByRarity: { [string]: { ItemsConfig.Item } } = {}
for _, item in ItemsConfig.Items do
	itemById[item.Id] = item
	if item.CanDrop ~= false then
		local list = itemsByRarity[item.Rarity]
		if not list then
			list = {}
			itemsByRarity[item.Rarity] = list
		end
		table.insert(list, item)
	end
end

local rarityByName: { [string]: ItemsConfig.Rarity } = {}
for _, rarity in ItemsConfig.Rarities do
	rarityByName[rarity.Name] = rarity
end

Catalog.Slippers = Slippers
Catalog.Hats = Hats
Catalog.Items = ItemsConfig.Items
Catalog.Rarities = ItemsConfig.Rarities
Catalog.Zones = ItemsConfig.Zones

function Catalog.Slipper(id: string): Slippers.Slipper?
	return slipperById[id]
end

function Catalog.SlipperIndex(id: string): number
	return slipperIndex[id] or 1
end

function Catalog.Hat(id: string): Hats.Hat?
	return hatById[id]
end

function Catalog.Item(id: string): ItemsConfig.Item?
	return itemById[id]
end

function Catalog.Rarity(name: string): ItemsConfig.Rarity
	return rarityByName[name] or ItemsConfig.Rarities[1]
end

function Catalog.DroppableItems(rarity: string): { ItemsConfig.Item }
	return itemsByRarity[rarity] or {}
end

return Catalog

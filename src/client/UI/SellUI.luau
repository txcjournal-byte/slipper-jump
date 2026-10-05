--!strict
-- Prodejní okno u stánku SELL: všechny předměty hráče (domeček, sklad, ruce) s cenou.
-- U každého tlačítko SELL, nahoře „prodat vše běžné“ (Common + Uncommon) a „do Rare“.
-- Vzácné předměty (Legendary a výš) se prodávají jen po potvrzení.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog = require(Shared.Catalog)
local Models = require(Shared.Models)
local Formulas = require(Shared.Formulas)
local FormatNumber = require(Shared.Util.FormatNumber)
local Net = require(Shared.Net)
local Kit = require(script.Parent.Kit)
local HUD = require(script.Parent.HUD)
local Dialogs = require(script.Parent.Dialogs)
local ClientState = require(script.Parent.Parent.ClientState)
local Sound = require(script.Parent.Parent.Sound)

local SellUI = {}

type Entry = { Uid: number, Id: string, Where: string, Price: number, Order: number, Income: number, Confirm: boolean }

local window: Kit.Window
local grid: ScrollingFrame
local summary: TextLabel
local sellItems = Net.Function("SellItems")
local dirty = true
local busy = false

local WHERE_TEXT: { [string]: string } = { House = "🏠 In house", Storage = "📦 Storage", Carried = "✋ In hands" }

local function collect(data: { [string]: any }): { Entry }
	local list: { Entry } = {}
	local multiplier = data.Multiplier or 1
	local function add(item: any, where: string)
		local cfg = item and Catalog.Item(item.Id)
		if cfg and cfg.CanSell ~= false then
			local rarity = Catalog.Rarity(cfg.Rarity)
			table.insert(list, {
				Uid = item.Uid,
				Id = item.Id,
				Where = where,
				Price = math.floor(Formulas.SellPrice(item.Id) * multiplier),
				Order = rarity.Order,
				Income = cfg.Income,
				Confirm = rarity.ConfirmSell,
			})
		end
	end
	for _, item in data.HouseItems or {} do
		add(item, "House")
	end
	for _, item in data.Storage or {} do
		add(item, "Storage")
	end
	if data.Carried then
		add(data.Carried, "Carried")
	end
	-- nejhorší nahoře (ty se prodávají nejčastěji)
	table.sort(list, function(a, b)
		if a.Order ~= b.Order then
			return a.Order < b.Order
		end
		return a.Income < b.Income
	end)
	return list
end

local function sell(uids: { number }, confirmRare: boolean)
	if busy or #uids == 0 then
		return
	end
	busy = true
	local ok, result = pcall(function()
		return sellItems:InvokeServer(uids, confirmRare)
	end)
	busy = false
	if ok and type(result) == "table" then
		HUD.Notify(result.Message, if result.Ok then "Money" else "Warning")
		if result.Ok then
			Sound.Play("Buy")
		end
	end
end

-- prodat jeden předmět (vzácný až po potvrzení)
local function sellOne(entry: Entry)
	local cfg = Catalog.Item(entry.Id)
	if entry.Confirm and cfg then
		Dialogs.Show({
			Title = "Sell " .. cfg.Name .. "?",
			Text = `This is a {cfg.Rarity} item! Sell it for {FormatNumber.Money(entry.Price)}?`,
			Color = Kit.Colors.Coral,
			Buttons = {
				{ Text = "SELL", Color = Kit.Colors.Coral, Callback = function()
					sell({ entry.Uid }, true)
				end },
				{ Text = "KEEP", Color = Kit.Colors.Green },
			},
		})
	else
		sell({ entry.Uid }, false)
	end
end

-- prodat všechno do dané vzácnosti (včetně)
local function sellUpTo(maxOrder: number, label: string)
	local list = collect(ClientState.Get())
	local uids, total = {}, 0
	for _, entry in list do
		if entry.Order <= maxOrder then
			table.insert(uids, entry.Uid)
			total += entry.Price
		end
	end
	if #uids == 0 then
		HUD.Notify("No " .. label .. " items to sell.", "Info")
		return
	end
	Dialogs.Show({
		Title = "Sell " .. #uids .. " items?",
		Text = `Sell all {label} items for {FormatNumber.Money(total)}?`,
		Color = Kit.Colors.Orange,
		Buttons = {
			{ Text = "SELL ALL", Color = Kit.Colors.Green, Callback = function()
				sell(uids, false)
			end },
			{ Text = "CANCEL", Color = Kit.Colors.Gray },
		},
	})
end

local function rebuild()
	dirty = false
	for _, child in grid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local list = collect(ClientState.Get())
	local total = 0
	for _, entry in list do
		total += entry.Price
	end
	summary.Text = if #list == 0 then "You have no items to sell. Jump into the sea to find some!" else `{#list} {if #list == 1 then "item" else "items"}  •  worth {FormatNumber.Money(total)} in total`
	for index, entry in list do
		local cfg = Catalog.Item(entry.Id)
		if cfg then
			local rarity = Catalog.Rarity(cfg.Rarity)
			local frame = Kit.Panel(grid, { BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = index, StrokeThickness = 3, Radius = 16 })
			local top = Kit.new("Frame", { BackgroundColor3 = if rarity.Name == "Secret" then Color3.fromRGB(70, 60, 90) else rarity.Color, Size = UDim2.new(1, -12, 0, 96), Position = UDim2.fromOffset(6, 6), Parent = frame })
			Kit.Corner(top, 12)
			Kit.Gradient(top, Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))
			Kit.Viewport(top, Models.Item(cfg.Id))
			Kit.Text(frame, { Text = cfg.Name, Size = UDim2.new(1, -12, 0, 24), Position = UDim2.fromOffset(6, 106), TextColor3 = Kit.Colors.Text, NoStroke = true })
			Kit.Text(frame, { Text = `{rarity.Name}  •  +{FormatNumber.Money(cfg.Income)}/s`, Size = UDim2.new(1, -12, 0, 20), Position = UDim2.fromOffset(6, 130), TextColor3 = if rarity.Name == "Secret" then Color3.fromRGB(120, 60, 200) else rarity.Color, StrokeThickness = 1.5 })
			Kit.Text(frame, { Text = WHERE_TEXT[entry.Where] or "", Size = UDim2.new(1, -12, 0, 18), Position = UDim2.fromOffset(6, 152), TextColor3 = Kit.Colors.Gray, NoStroke = true })
			Kit.Button(frame, { Text = "SELL " .. FormatNumber.Money(entry.Price), Size = UDim2.new(1, -16, 0, 46), Position = UDim2.new(0, 8, 1, -52), Color = if entry.Confirm then Kit.Colors.Coral else Kit.Colors.Green }, function()
				Sound.Play("Click")
				sellOne(entry)
			end)
		end
	end
end

function SellUI.Init(screen: ScreenGui)
	window = Kit.Window(screen, "SELL SHOP", UDim2.fromOffset(980, 640), Kit.Colors.Green)
	local bar = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 56), Parent = window.Content })
	summary = Kit.Text(bar, { Text = "", Size = UDim2.new(0.42, 0, 1, -10), Position = UDim2.fromOffset(4, 5), TextColor3 = Kit.Colors.Text, NoStroke = true, TextXAlignment = Enum.TextXAlignment.Left })
	Kit.Button(bar, { Text = "SELL ALL COMMON", Size = UDim2.new(0.28, -8, 1, -4), Position = UDim2.new(0.43, 0, 0, 2), Color = Kit.Colors.Orange }, function()
		Sound.Play("Click")
		sellUpTo(2, "Common & Uncommon")
	end)
	Kit.Button(bar, { Text = "SELL ALL UP TO RARE", Size = UDim2.new(0.28, -8, 1, -4), Position = UDim2.new(0.72, 0, 0, 2), Color = Kit.Colors.Blue }, function()
		Sound.Play("Click")
		sellUpTo(3, "Common, Uncommon & Rare")
	end)
	local body = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -66), Position = UDim2.fromOffset(0, 66), Parent = window.Content })
	grid = Kit.Grid(body, UDim2.fromOffset(200, 232))
	ClientState.Changed:Connect(function()
		dirty = true
		if window.IsOpen() then
			-- (jedno překreslení za chvilku, i když přijde víc změn najednou)
			task.delay(0.15, function()
				if dirty and window.IsOpen() then
					rebuild()
				end
			end)
		end
	end)
end

function SellUI.Open()
	rebuild()
	window.Open()
end

return SellUI

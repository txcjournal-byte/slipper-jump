--!strict
-- Robux obchod (tlačítko s košíkem). Všechno, co ovlivňuje hru, jde získat i hraním –
-- Robuxy jen zrychlují nebo přidávají vzhled.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Products = require(Shared.Config.Products)
local Spinner = require(Shared.Config.Spinner)
local Kit = require(script.Parent.Kit)
local HUD = require(script.Parent.HUD)
local ClientState = require(script.Parent.Parent.ClientState)
local Purchase = require(script.Parent.Parent.Purchase)

local RobuxShop = {}

local window: Kit.Window
local passButtons: { [string]: TextButton } = {}
local starterCard: GuiObject? = nil

local function oddsText(): string
	local total = 0
	for _, segment in Spinner.Segments do
		total += segment.Weight
	end
	local parts = {}
	for _, segment in Spinner.Segments do
		table.insert(parts, segment.Label .. " " .. string.format("%g", segment.Weight / total * 100) .. "%")
	end
	return "Chances: " .. table.concat(parts, " • ")
end

local function item(parent: Instance, order: number, name: string, description: string, price: number, color: Color3, onBuy: () -> ()): TextButton
	local frame = Kit.Panel(parent, { BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = order, StrokeThickness = 3, Radius = 16 })
	local top = Kit.new("Frame", { BackgroundColor3 = color, Size = UDim2.new(1, -12, 0, 58), Position = UDim2.fromOffset(6, 6), Parent = frame })
	Kit.Corner(top, 12)
	Kit.Gradient(top, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200))
	Kit.Text(top, { Text = name, Size = UDim2.new(1, -12, 1, -10), Position = UDim2.fromOffset(6, 5) })
	Kit.Text(frame, { Text = description, Size = UDim2.new(1, -16, 0, 60), Position = UDim2.fromOffset(8, 70), TextColor3 = Kit.Colors.Text, NoStroke = true, TextWrapped = true })
	return Kit.Button(frame, { Text = "R$ " .. price, Color = Kit.Colors.Green, Size = UDim2.new(1, -16, 0, 50), Position = UDim2.new(0, 8, 1, -58) }, onBuy)
end

function RobuxShop.Init(screen: ScreenGui)
	window = Kit.Window(screen, "STORE", UDim2.fromOffset(980, 620), Kit.Colors.Green)
	local scroll = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 10,
		Parent = window.Content,
	})
	Kit.new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	-- odznak pro hráče s Roblox Premium (bonus počítá server, tady se jen ukazuje)
	local premiumBadge = Kit.Panel(scroll, {
		Size = UDim2.fromOffset(330, 44),
		LayoutOrder = 0,
		BackgroundColor3 = Kit.Colors.Yellow,
		StrokeThickness = 3,
		Radius = 22,
		Visible = false,
	})
	Kit.Text(premiumBadge, { Text = "⭐ Premium +" .. math.floor(Products.PremiumIncomeBonus * 100 + 0.5) .. "% money", Size = UDim2.new(1, -16, 1, -10), Position = UDim2.fromOffset(8, 5) })
	Kit.Text(scroll, { Text = "GAME PASSES (forever)", Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 1, TextColor3 = Kit.Colors.Yellow, TextXAlignment = Enum.TextXAlignment.Left })
	local passGrid = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = scroll })
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(220, 200), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = passGrid })
	for i, pass in Products.GamePasses do
		if not Products.IsConfigured(pass.Key) then
			continue -- nezaložené passy se ve zveřejněné hře neukazují
		end
		passButtons[pass.Key] = item(passGrid, i, pass.Name, pass.Description, pass.Price, pass.Color, function()
			RobuxShop.PromptKey(pass.Key)
		end)
	end
	Kit.Text(scroll, { Text = "BOOSTS & ITEMS", Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 3, TextColor3 = Kit.Colors.Yellow, TextXAlignment = Enum.TextXAlignment.Left })
	local productGrid = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, Parent = scroll })
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(220, 200), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = productGrid })
	for i, product in Products.DevProducts do
		if product.Hidden or not Products.IsConfigured(product.Key) then
			continue -- skiny se kupují v záložce Sneakers
		end
		local button = item(productGrid, i, product.Name, product.Description, product.Price, product.Color, function()
			RobuxShop.PromptKey(product.Key)
		end)
		if product.Key == "StarterPack" then
			starterCard = button.Parent :: GuiObject
		end
	end
	Kit.Text(scroll, { Text = "👟 Sneaker skins: open ITEMS → Sneakers", Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 5, TextColor3 = Kit.Colors.Purple, NoStroke = true, TextXAlignment = Enum.TextXAlignment.Left })
	-- šance pro placená točení musí být vidět
	Kit.Text(scroll, { Text = oddsText(), Size = UDim2.new(1, 0, 0, 60), LayoutOrder = 6, TextColor3 = Kit.Colors.Text, NoStroke = true, TextWrapped = true })

	ClientState.Changed:Connect(function(data)
		if starterCard then
			starterCard.Visible = data.StarterPackBought ~= true
		end
		premiumBadge.Visible = data.Premium == true
		for key, button in passButtons do
			if data.Passes and data.Passes[key] then
				Kit.SetButtonText(button, "OWNED")
				button.BackgroundColor3 = Kit.Colors.Gray
				button.Active = false
			end
		end
	end)
end

-- Nákup podle klíče – game pass i developer product (např. z kontextové nabídky)
function RobuxShop.PromptKey(key: string)
	if not Purchase.Prompt(key) then
		HUD.Notify("This is not available yet. Check back soon!", "Warning")
	end
end

function RobuxShop.Prompt(key: string)
	RobuxShop.PromptKey(key)
end

function RobuxShop.Toggle()
	if window.IsOpen() then
		window.Close()
	else
		window.Open()
	end
end

return RobuxShop

--!strict
-- Testovací panel – jen ve Studiu (ve zveřejněné hře se tlačítko vůbec neukáže a server požadavky ignoruje).
-- Spustit událost, nastavit level, přidat peníze, obout pantofle, plavecká výbava, štíty, reset ostrovů.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Events = require(Shared.Config.Events)
local Net = require(Shared.Net)
local Kit = require(script.Parent.Kit)
local Sound = require(script.Parent.Parent.Sound)

local TestPanel = {}

local window: Kit.Window

local function send(action: string, value: any)
	Sound.Play("Click")
	Net.Event("StudioTest"):FireServer(action, value)
end

local function section(parent: Instance, order: number, title: string): Frame
	Kit.Text(parent, { Text = title, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = order * 2 - 1, TextColor3 = Kit.Colors.Yellow, TextXAlignment = Enum.TextXAlignment.Left })
	local row = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order * 2, Parent = parent })
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(170, 44), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
	return row
end

local function button(row: Frame, text: string, color: Color3, onClick: () -> ())
	Kit.Button(row, { Text = text, Color = color, Size = UDim2.fromOffset(170, 44), Radius = 10 }, onClick)
end

function TestPanel.Init(screen: ScreenGui, hudScreen: ScreenGui)
	if not RunService:IsStudio() then
		return
	end
	window = Kit.Window(screen, "TEST PANEL (Studio only)", UDim2.fromOffset(940, 620), Kit.Colors.Purple)
	local scroll = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 10,
		Parent = window.Content,
	})
	Kit.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })

	local events = section(scroll, 1, "START EVENT NOW")
	for _, event in Events.ServerEvents do
		button(events, event.Name, event.Color, function()
			send("Event", event.Kind)
			window.Close()
		end)
	end
	local levels = section(scroll, 2, "SET LEVEL")
	for _, level in { 1, 3, 5, 10, 15, 20, 30, 40, 50 } do
		button(levels, "Level " .. level, Kit.Colors.Blue, function()
			send("Level", level)
		end)
	end
	local money = section(scroll, 3, "ADD MONEY")
	type MoneyEntry = { Text: string, Amount: number }
	local amounts: { MoneyEntry } = { { Text = "+$10K", Amount = 10_000 }, { Text = "+$1M", Amount = 1_000_000 }, { Text = "+$100M", Amount = 100_000_000 } }
	for _, entry in amounts do
		button(money, entry.Text, Kit.Colors.Green, function()
			send("Money", entry.Amount)
		end)
	end
	local shoes = section(scroll, 4, "WEAR SLIPPERS")
	for _, entry in { { "Basic", "BasicBlackSlippers" }, { "Golden", "GoldenSlippers" }, { "Crystal", "CrystalSlippers" }, { "Cloud Wing", "CloudWingSlippers" }, { "Robot", "RobotSlippers" }, { "Galaxy", "GalaxySlippers" }, { "Dragon", "DragonSlippers" }, { "Royal Diamond", "RoyalDiamondSlippers" } } do
		button(shoes, entry[1] :: string, Kit.Colors.Orange, function()
			send("Slippers", entry[2])
		end)
	end
	local other = section(scroll, 5, "SWIM & OTHER")
	for _, level in { 0, 2, 4, 6 } do
		button(other, "Swim gear " .. level, Kit.Colors.Turquoise, function()
			send("Swim", level)
		end)
	end
	button(other, "+5 Bubble Shields", Kit.Colors.Purple, function()
		send("Shields", true)
	end)
	button(other, "+6 random items", Kit.Colors.Green, function()
		send("Items", true)
	end)
	for _, key in { "Bronze", "Silver", "Giant" } do
		button(other, "Challenge: " .. key, Kit.Colors.Pink, function()
			send("Trial", key)
			window.Close()
		end)
	end
	for _, style in { "Random", "Gates", "Buoys", "Hoops", "Canyon", "Whirlpool" } do
		button(other, "Slalom: " .. style, Kit.Colors.Turquoise, function()
			send("SlalomStyle", style)
		end)
	end
	for tier = 1, 5 do
		button(other, "House tier " .. tier, Kit.Colors.Blue, function()
			send("HouseTier", tier)
		end)
	end
	button(other, "LEGEND RACE now", Kit.Colors.Yellow, function()
		send("LegendRace", true)
		window.Close()
	end)
	button(other, "Reset gift islands", Kit.Colors.Coral, function()
		send("ResetGifts", true)
	end)

	-- malé fialové tlačítko TEST dole uprostřed
	local open = Kit.Button(hudScreen, { Text = "TEST", Color = Kit.Colors.Purple, Size = UDim2.fromOffset(90, 40), Position = UDim2.new(0.5, 0, 1, -6), AnchorPoint = Vector2.new(0.5, 1), Radius = 10 }, function()
		Sound.Play("Click")
		if window.IsOpen() then
			window.Close()
		else
			window.Open()
		end
	end)
	open.ZIndex = 20
end

return TestPanel

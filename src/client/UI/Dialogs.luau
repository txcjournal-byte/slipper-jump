--!strict
-- Dialogová okna: potvrzení prodeje, nabídka daru, příjem offline, level up, obří dárek, rebirth.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog = require(Shared.Catalog)
local Economy = require(Shared.Config.Economy)
local FormatNumber = require(Shared.Util.FormatNumber)
local Net = require(Shared.Net)
local Kit = require(script.Parent.Kit)
local HUD = require(script.Parent.HUD)
local Sound = require(script.Parent.Parent.Sound)
local Effects = require(script.Parent.Parent.Effects.Effects)

local Dialogs = {}

type Button = { Text: string, Color: Color3, Callback: (() -> ())? }
type Request = { Title: string, Text: string, Buttons: { Button }, Color: Color3?, Timeout: number? }

local screen: ScreenGui
local queue: { Request } = {}
local showing = false

local function showNext()
	if showing or #queue == 0 then
		return
	end
	showing = true
	local request = table.remove(queue, 1) :: Request
	local shade = Kit.new("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 30,
		Parent = screen,
	})
	local panel = Kit.Panel(shade, {
		Size = UDim2.fromOffset(620, 330),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 31,
	})
	local header = Kit.new("Frame", { BackgroundColor3 = request.Color or Kit.Colors.Turquoise, Size = UDim2.new(1, 0, 0, 64), ZIndex = 31, Parent = panel })
	Kit.Corner(header, 18)
	Kit.Gradient(header, Color3.new(1, 1, 1), Color3.fromRGB(210, 210, 210))
	Kit.Text(header, { Text = request.Title, Size = UDim2.new(1, -30, 1, -14), Position = UDim2.fromOffset(15, 7), StrokeThickness = 3, ZIndex = 32 })
	Kit.Text(panel, {
		Text = request.Text,
		Size = UDim2.new(1, -40, 0, 150),
		Position = UDim2.fromOffset(20, 78),
		TextColor3 = Kit.Colors.Text,
		NoStroke = true,
		TextWrapped = true,
		ZIndex = 32,
	})
	local row = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -40, 0, 70), Position = UDim2.new(0, 20, 1, -86), ZIndex = 32, Parent = panel })
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 20), Parent = row })
	local closed = false
	local function close(callback: (() -> ())?)
		if closed then
			return
		end
		closed = true
		shade:Destroy()
		showing = false
		if callback then
			task.spawn(callback)
		end
		showNext()
	end
	for _, button in request.Buttons do
		local b = Kit.Button(row, { Text = button.Text, Color = button.Color, Size = UDim2.fromOffset(240, 66) }, function()
			Sound.Play("Click")
			close(button.Callback)
		end)
		b.ZIndex = 33
	end
	Kit.Pop(panel, 0.8)
	local timeout = request.Timeout
	if timeout then
		local last = request.Buttons[#request.Buttons]
		task.delay(timeout, function()
			close(last and last.Callback)
		end)
	end
end

function Dialogs.Show(request: Request)
	table.insert(queue, request)
	showNext()
end

function Dialogs.Info(title: string, text: string, color: Color3?)
	Dialogs.Show({ Title = title, Text = text, Color = color, Buttons = { { Text = "OK", Color = Kit.Colors.Green } } })
end

function Dialogs.Init()
	screen = Kit.Screen("Dialogs", 40)

	Net.Event("ConfirmSell").OnClientEvent:Connect(function(info)
		local cfg = Catalog.Item(info.Id)
		local name = if cfg then cfg.Name else info.Id
		Dialogs.Show({
			Title = "Are you sure you want to sell this?",
			Text = `{name} is very rare! You will get {FormatNumber.Money(info.Price)}.`,
			Color = Kit.Colors.Orange,
			Buttons = {
				{ Text = "SELL", Color = Kit.Colors.Coral, Callback = function()
					Net.Event("ConfirmSell"):FireServer(info.Uid, true)
				end },
				{ Text = "KEEP IT", Color = Kit.Colors.Green, Callback = function()
					Net.Event("ConfirmSell"):FireServer(info.Uid, false)
				end },
			},
		})
	end)

	Net.Event("GiftOffer").OnClientEvent:Connect(function(offer)
		local cfg = Catalog.Item(offer.ItemId)
		local name = if cfg then cfg.Name else offer.ItemId
		local rarity = if cfg then Catalog.Rarity(cfg.Rarity).Name else ""
		Dialogs.Show({
			Title = "A GIFT FOR YOU!",
			Text = `{offer.From} wants to give you {name} ({rarity}).`,
			Color = Kit.Colors.Pink,
			Timeout = offer.Timeout,
			Buttons = {
				{ Text = "ACCEPT", Color = Kit.Colors.Green, Callback = function()
					Net.Event("GiftRespond"):FireServer(offer.OfferId, true)
				end },
				{ Text = "DECLINE", Color = Kit.Colors.Coral, Callback = function()
					Net.Event("GiftRespond"):FireServer(offer.OfferId, false)
				end },
			},
		})
	end)

	Net.Event("WelcomeBack").OnClientEvent:Connect(function(amount: number, seconds: number)
		Dialogs.Info("Welcome back!", `You earned {FormatNumber.Money(amount)} while you were away ({FormatNumber.Time(seconds)}).`, Kit.Colors.Yellow)
		Sound.Play("Coin")
	end)

	Net.Event("LevelUp").OnClientEvent:Connect(function(info)
		Effects.BigText("LEVEL " .. info.Level .. "!", Kit.Colors.Turquoise, 1.6, 0.22)
		Effects.ScreenConfetti(40)
		Sound.Play("LevelUp")
		HUD.Notify("+" .. FormatNumber.Money(info.Money) .. " level reward!", "Money")
		for _, reward in info.Rewards do
			HUD.Notify("Level reward: " .. reward, "Success")
		end
	end)
end

function Dialogs.GiftOpened(info: { Rewards: { string }, First: boolean, Title: string?, Next: string? })
	Effects.ScreenConfetti(140)
	Sound.Play("Fanfare")
	local text = "You got: " .. table.concat(info.Rewards, ", ") .. "!"
	if info.First then
		text ..= "\nYou can now REBIRTH for +50% money forever!"
	end
	if info.Next then
		text ..= "\n" .. info.Next
	end
	Dialogs.Info(info.Title or "YOU REACHED THE GIANT GIFT!", text, Kit.Colors.Yellow)
end

function Dialogs.ConfirmRebirth()
	Dialogs.Show({
		Title = "REBIRTH?",
		Text = `You lose your slippers and money, but keep your items in the house and get +{math.floor(Economy.RebirthIncomeBonus * 100)}% money forever. The Giant Gift will change color!`,
		Color = Kit.Colors.Purple,
		Buttons = {
			{ Text = "REBIRTH!", Color = Kit.Colors.Purple, Callback = function()
				Net.Event("Rebirth"):FireServer()
			end },
			{ Text = "NOT YET", Color = Kit.Colors.Gray },
		},
	})
end

return Dialogs

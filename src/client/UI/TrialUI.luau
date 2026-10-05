--!strict
-- Úkol na cestu domů z dárkového ostrova: panel s nabídkou (START / EASY PATH / SKIP / GO HOME),
-- šipka ke kánoi nebo ke startu dráhy, průběh dráhy (vlaječky) a oslava na konci.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local FormatNumber = require(Shared.Util.FormatNumber)
local Products = require(Shared.Config.Products)
local Net = require(Shared.Net)
local Kit = require(script.Parent.Kit)
local HUD = require(script.Parent.HUD)
local Dialogs = require(script.Parent.Dialogs)
local RobuxShop = require(script.Parent.RobuxShop)
local Sound = require(script.Parent.Parent.Sound)
local Effects = require(script.Parent.Parent.Effects.Effects)
local JumpController = require(script.Parent.Parent.Controllers.JumpController)

local TrialUI = {}

local player = Players.LocalPlayer

local panel: Frame
local titleLabel: TextLabel
local descLabel: TextLabel
local bonusLabel: TextLabel
local failLabel: TextLabel
local easyButton: TextButton
local progress: Frame
local progressLabel: TextLabel
local arrowFolder: Folder? = nil
local currentName = ""
local currentIcon = ""

local function price(key: string): number
	for _, product in Products.DevProducts do
		if product.Key == key then
			return product.Price
		end
	end
	return 0
end

local function clearArrow()
	if arrowFolder then
		arrowFolder:Destroy()
		arrowFolder = nil
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local att = root and root:FindFirstChild("TrialArrowFrom")
	if att then
		att:Destroy()
	end
end

-- Žlutý paprsek od hráče ke startu + svítící značka „START HERE“
local function showArrow(target: Vector3)
	clearArrow()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "TrialArrow"
	folder.Parent = Workspace
	arrowFolder = folder
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(target + Vector3.new(0, 2, 0))
	anchor.Parent = folder
	local to = Instance.new("Attachment")
	to.Parent = anchor
	local from = Instance.new("Attachment")
	from.Name = "TrialArrowFrom"
	from.Position = Vector3.new(0, -2, 0)
	from.Parent = root
	local beam = Instance.new("Beam")
	beam.Attachment0 = from
	beam.Attachment1 = to
	beam.Width0 = 1.2
	beam.Width1 = 1.2
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Color = ColorSequence.new(Kit.Colors.Yellow)
	beam.Transparency = NumberSequence.new(0.2)
	beam.Parent = folder
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 60)
	gui.StudsOffset = Vector3.new(0, 6, 0)
	gui.AlwaysOnTop = true
	gui.Parent = anchor
	Kit.Text(gui, { Text = "⬇ START HERE", Size = UDim2.fromScale(1, 1), TextColor3 = Kit.Colors.Yellow, StrokeThickness = 3 })
end

local function hideAll()
	panel.Visible = false
	progress.Visible = false
	clearArrow()
end

local function onOffer(info: { [string]: any })
	currentName = info.Name
	currentIcon = info.Icon
	titleLabel.Text = `{info.Icon} ISLAND CHALLENGE: {info.Name}`
	descLabel.Text = info.Description
	local title = if typeof(info.Title) == "string" then ` + title "{info.Title}"` else ""
	bonusLabel.Text = `🎁 Bonus: {FormatNumber.Money(info.Money)} + {info.Spins} Spins{title}`
	if info.Failed then
		failLabel.Text = `So close! Try again (attempts: {info.Fails})` .. (if info.Fails >= 3 then " – or take the Easy Path!" else "")
		failLabel.Visible = true
	else
		failLabel.Visible = false
	end
	easyButton.Visible = not info.Easy
	panel.Visible = true
	progress.Visible = false
	Kit.Pop(panel, 1.06)
	if typeof(info.Target) == "Vector3" then
		task.delay(0.3, showArrow, info.Target)
	end
end

local function onState(info: { [string]: any })
	local state = info.State
	if state == "Running" then
		panel.Visible = false
		clearArrow()
		if info.Kind == "Obby" then
			progress.Visible = true
			progressLabel.Text = `{currentIcon} {currentName}   🚩 {info.Checkpoint}/{info.Total}`
			Effects.BigText("GO! Get back home!", Kit.Colors.Green, 1.2, 0.3)
		end
	elseif state == "Checkpoint" then
		progressLabel.Text = `{currentIcon} {currentName}   🚩 {info.Checkpoint}/{info.Total}`
		Kit.Pop(progress, 1.15)
		Sound.Play("Ring", 1.3)
		Effects.FloatText("CHECKPOINT!", Kit.Colors.Green)
	elseif state == "Respawn" then
		Effects.BigText(info.Text or "Try again!", Kit.Colors.Coral, 1, 0.3)
		Sound.Play("Splash", 0.9)
	elseif state == "Easy" then
		HUD.Notify("Easy Path active!", "Success")
	elseif state == "Complete" then
		hideAll()
		JumpController.EndTrialRace()
		Effects.ScreenConfetti(150)
		Sound.Play("Confetti")
		task.delay(2.6, function()
			Dialogs.Show({
				Title = "CHALLENGE COMPLETE!",
				Text = `{info.Icon} {info.Name} done! You got: ` .. table.concat(info.Rewards or {}, ", "),
				Color = Kit.Colors.Green,
				Buttons = { { Text = "AWESOME!", Color = Kit.Colors.Green } },
			})
		end)
	elseif state == "End" then
		hideAll()
		JumpController.EndTrialRace()
	end
end

function TrialUI.Init(screen: ScreenGui)
	panel = Kit.Panel(screen, {
		Name = "TrialPanel",
		Size = UDim2.fromOffset(720, 250),
		Position = UDim2.new(0.5, 0, 1, -110),
		AnchorPoint = Vector2.new(0.5, 1),
		Visible = false,
		StrokeThickness = 4,
	})
	local header = Kit.new("Frame", { BackgroundColor3 = Kit.Colors.Turquoise, BorderSizePixel = 0, Size = UDim2.new(1, -12, 0, 50), Position = UDim2.fromOffset(6, 6), Parent = panel })
	Kit.Corner(header, 12)
	Kit.Gradient(header, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200))
	titleLabel = Kit.Text(header, { Text = "", Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5) })
	descLabel = Kit.Text(panel, { Text = "", Size = UDim2.new(1, -24, 0, 48), Position = UDim2.fromOffset(12, 60), TextColor3 = Kit.Colors.Text, NoStroke = true, TextWrapped = true })
	bonusLabel = Kit.Text(panel, { Text = "", Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 110), TextColor3 = Color3.fromRGB(40, 160, 70), StrokeThickness = 1.5 })
	failLabel = Kit.Text(panel, { Text = "", Size = UDim2.new(1, -24, 0, 26), Position = UDim2.fromOffset(12, 140), TextColor3 = Kit.Colors.Coral, StrokeThickness = 1.5, Visible = false })
	local row = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 60), Position = UDim2.new(0, 12, 1, -70), Parent = panel })
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
	Kit.Button(row, { Text = "START", Color = Kit.Colors.Green, Size = UDim2.fromOffset(150, 58), LayoutOrder = 1 }, function()
		Sound.Play("Click")
		Net.Event("TrialAction"):FireServer("Start")
	end)
	easyButton = Kit.Button(row, { Text = "EASY PATH R$ " .. price("TrialEasy"), Color = Kit.Colors.Blue, Size = UDim2.fromOffset(170, 58), LayoutOrder = 2 }, function()
		Sound.Play("Click")
		RobuxShop.PromptKey("TrialEasy")
	end)
	Kit.Button(row, { Text = "SKIP + BONUS R$ " .. price("TrialSkip"), Color = Kit.Colors.Orange, Size = UDim2.fromOffset(190, 58), LayoutOrder = 3 }, function()
		Sound.Play("Click")
		RobuxShop.PromptKey("TrialSkip")
	end)
	Kit.Button(row, { Text = "GO HOME (no bonus)", Color = Kit.Colors.Gray, Size = UDim2.fromOffset(150, 58), LayoutOrder = 4 }, function()
		Sound.Play("Click")
		Net.Event("TrialAction"):FireServer("GoHome")
	end)

	-- průběh dráhy nahoře uprostřed
	progress = Kit.Panel(screen, {
		Name = "TrialProgress",
		Size = UDim2.fromOffset(520, 60),
		Position = UDim2.new(0.5, 0, 0, 70),
		AnchorPoint = Vector2.new(0.5, 0),
		Visible = false,
		BackgroundColor3 = Kit.Colors.Purple,
		Radius = 30,
	})
	progressLabel = Kit.Text(progress, { Text = "", Size = UDim2.new(1, -200, 1, -12), Position = UDim2.fromOffset(16, 6), TextXAlignment = Enum.TextXAlignment.Left })
	Kit.Button(progress, { Text = "SKIP R$ " .. price("TrialSkip"), Color = Kit.Colors.Orange, Size = UDim2.fromOffset(84, 46), Position = UDim2.new(1, -184, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Radius = 12 }, function()
		RobuxShop.PromptKey("TrialSkip")
	end)
	Kit.Button(progress, { Text = "HOME", Color = Kit.Colors.Gray, Size = UDim2.fromOffset(84, 46), Position = UDim2.new(1, -94, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Radius = 12 }, function()
		Net.Event("TrialAction"):FireServer("GoHome")
	end)

	Net.Event("TrialOffer").OnClientEvent:Connect(onOffer)
	Net.Event("TrialState").OnClientEvent:Connect(onState)
	player.CharacterAdded:Connect(function()
		hideAll()
	end)
end

return TrialUI

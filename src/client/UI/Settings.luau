--!strict
-- Nastavení: hudba, zvuky, kód, přeskočit tutoriál.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Kit = require(script.Parent.Kit)
local HUD = require(script.Parent.HUD)
local ClientState = require(script.Parent.Parent.ClientState)

local Settings = {}

local window: Kit.Window
local musicButton: TextButton
local sfxButton: TextButton
local skipButton: TextButton

local function toggleButton(button: TextButton, label: string, on: boolean)
	Kit.SetButtonText(button, label .. ": " .. (if on then "ON" else "OFF"))
	button.BackgroundColor3 = if on then Kit.Colors.Green else Kit.Colors.Gray
end

local function refresh(data: { [string]: any })
	local settings = data.Settings or { Music = true, Sfx = true }
	toggleButton(musicButton, "MUSIC", settings.Music)
	toggleButton(sfxButton, "SOUNDS", settings.Sfx)
	skipButton.Visible = data.TutorialDone ~= true
end

function Settings.Init(screen: ScreenGui)
	window = Kit.Window(screen, "SETTINGS", UDim2.fromOffset(560, 470), Kit.Colors.Blue)
	local content = window.Content
	Kit.new("UIListLayout", { Padding = UDim.new(0, 14), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = content })
	musicButton = Kit.Button(content, { Text = "MUSIC", Size = UDim2.fromOffset(460, 64), LayoutOrder = 1 }, function()
		local settings = ClientState.Get().Settings or {}
		Net.Event("SetSetting"):FireServer("Music", not settings.Music)
	end)
	sfxButton = Kit.Button(content, { Text = "SOUNDS", Size = UDim2.fromOffset(460, 64), LayoutOrder = 2 }, function()
		local settings = ClientState.Get().Settings or {}
		Net.Event("SetSetting"):FireServer("Sfx", not settings.Sfx)
	end)
	local codeRow = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(460, 64), LayoutOrder = 3, Parent = content })
	local box = Kit.new("TextBox", {
		PlaceholderText = "Enter code",
		Text = "",
		Font = Kit.Font,
		TextScaled = true,
		TextColor3 = Kit.Colors.Text,
		PlaceholderColor3 = Kit.Colors.Gray,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, -150, 1, 0),
		ClearTextOnFocus = false,
		Parent = codeRow,
	})
	Kit.Corner(box, 14)
	Kit.Stroke(box, 3, Kit.Colors.Outline, true)
	Kit.Padding(box, 10)
	Kit.Button(codeRow, { Text = "REDEEM", Color = Kit.Colors.Yellow, Size = UDim2.new(0, 140, 1, 0), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0) }, function()
		local result = Net.Function("RedeemCode"):InvokeServer(box.Text)
		if result then
			HUD.Notify(result.Message, if result.Ok then "Success" else "Warning")
			if result.Ok then
				box.Text = ""
			end
		end
	end)
	skipButton = Kit.Button(content, { Text = "SKIP TUTORIAL", Color = Kit.Colors.Coral, Size = UDim2.fromOffset(460, 64), LayoutOrder = 4 }, function()
		Net.Event("SkipTutorial"):FireServer()
	end)
	ClientState.Changed:Connect(refresh)
	refresh(ClientState.Get())
end

function Settings.Toggle()
	if window.IsOpen() then
		window.Close()
	else
		window.Open()
	end
end

return Settings

--!strict
-- Denní úkoly a série přihlášení.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local FormatNumber = require(Shared.Util.FormatNumber)
local Kit = require(script.Parent.Kit)
local ClientState = require(script.Parent.Parent.ClientState)

local QuestsUI = {}

local window: Kit.Window
local streakLabel: TextLabel
local rows: { { Frame: Frame, Text: TextLabel, Fill: Frame, Count: TextLabel, Reward: TextLabel } } = {}

local function refresh(data: { [string]: any })
	if not window then
		return
	end
	streakLabel.Text = "🔥 Login streak: " .. (data.LoginStreak or 0) .. " day" .. (if (data.LoginStreak or 0) == 1 then "" else "s") .. " – come back tomorrow for a bigger reward!"
	local quests = data.Quests or {}
	for i, row in rows do
		local quest = quests[i]
		row.Frame.Visible = quest ~= nil
		if quest then
			row.Text.Text = (if quest.Done then "✅ " else "") .. quest.Text
			row.Fill.Size = UDim2.fromScale(math.clamp(quest.Progress / quest.Goal, 0, 1), 1)
			row.Fill.BackgroundColor3 = if quest.Done then Kit.Colors.Green else Kit.Colors.Turquoise
			row.Count.Text = FormatNumber.Short(quest.Progress) .. " / " .. FormatNumber.Short(quest.Goal)
			row.Reward.Text = FormatNumber.Money(quest.Money) .. (if quest.Spins > 0 then " + " .. quest.Spins .. " Spin" else "")
		end
	end
end

function QuestsUI.Init(screen: ScreenGui)
	window = Kit.Window(screen, "DAILY QUESTS", UDim2.fromOffset(760, 500), Kit.Colors.Orange)
	local content = window.Content
	streakLabel = Kit.Text(content, { Text = "", Size = UDim2.new(1, 0, 0, 36), TextColor3 = Kit.Colors.Orange, StrokeThickness = 2 })
	for i = 1, 3 do
		local frame = Kit.Panel(content, { Size = UDim2.new(1, 0, 0, 100), Position = UDim2.fromOffset(0, 50 + (i - 1) * 112), BackgroundColor3 = Color3.new(1, 1, 1), StrokeThickness = 3 })
		local text = Kit.Text(frame, { Text = "", Size = UDim2.new(0.7, 0, 0, 36), Position = UDim2.fromOffset(14, 8), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Kit.Colors.Text, NoStroke = true })
		local reward = Kit.Text(frame, { Text = "", Size = UDim2.new(0.3, -24, 0, 36), Position = UDim2.new(0.7, 10, 0, 8), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(40, 160, 70), NoStroke = true })
		local bar = Kit.new("Frame", { BackgroundColor3 = Color3.fromRGB(60, 70, 100), Size = UDim2.new(1, -28, 0, 34), Position = UDim2.fromOffset(14, 54), Parent = frame })
		Kit.Corner(bar, 14)
		local fill = Kit.new("Frame", { BackgroundColor3 = Kit.Colors.Turquoise, Size = UDim2.fromScale(0, 1), Parent = bar })
		Kit.Corner(fill, 14)
		local count = Kit.Text(bar, { Text = "", Size = UDim2.new(1, -10, 1, -6), Position = UDim2.fromOffset(5, 3), ZIndex = 2 })
		rows[i] = { Frame = frame, Text = text, Fill = fill, Count = count, Reward = reward }
	end
	Kit.Text(content, { Text = "New quests every day!", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 1, -30), TextColor3 = Kit.Colors.Gray, NoStroke = true })
	ClientState.Changed:Connect(refresh)
	refresh(ClientState.Get())
end

function QuestsUI.Toggle()
	if window.IsOpen() then
		window.Close()
	else
		window.Open()
	end
end


return QuestsUI

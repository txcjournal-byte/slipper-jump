--!strict
-- Okno QUESTS se dvěma záložkami:
--  🏝️ JOURNEY – cíl hry: cesta od chatrče k paláci (úrovně domečku), co splnit pro další krok, dárkové ostrovy
--  📜 DAILY   – denní úkoly a série přihlášení

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local FormatNumber = require(Shared.Util.FormatNumber)
local House = require(Shared.Config.House)
local GiantGift = require(Shared.Config.GiantGift)
local Kit = require(script.Parent.Kit)
local ClientState = require(script.Parent.Parent.ClientState)

local QuestsUI = {}

local window: Kit.Window
local streakLabel: TextLabel
local rows: { { Frame: Frame, Text: TextLabel, Fill: Frame, Count: TextLabel, Reward: TextLabel } } = {}
local dailyPage: Frame
local journeyPage: Frame
local journeyTab: TextButton
local dailyTab: TextButton
local tierRows: { { Frame: Frame, Icon: TextLabel, Name: TextLabel, Hint: TextLabel } } = {}
local giftsLabel: TextLabel

local TIER_ICONS = { "⛺", "🏡", "🏖️", "🏰", "👑" }

local function showTab(journey: boolean)
	journeyPage.Visible = journey
	dailyPage.Visible = not journey
	journeyTab.BackgroundColor3 = if journey then Kit.Colors.Turquoise else Kit.Colors.Gray
	dailyTab.BackgroundColor3 = if journey then Kit.Colors.Gray else Kit.Colors.Orange
end

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
	-- cesta domečku: hotové ✅, další cíl 👉 (zvýrazněný), zbytek 🔒
	local tier = data.HouseTier or 1
	for i, row in tierRows do
		local cfg = House.Tiers[i]
		local done = i <= tier
		local isNext = i == tier + 1
		row.Icon.Text = TIER_ICONS[i] or "🏠"
		row.Name.Text = (if done then "✅ " elseif isNext then "👉 " else "🔒 ") .. cfg.Name .. (if i == tier then "  (your house)" else "")
		row.Hint.Text = if done then "Done!" else cfg.Hint
		row.Frame.BackgroundColor3 = if i == tier then Color3.fromRGB(215, 250, 225) elseif isNext then Color3.fromRGB(255, 244, 205) else Color3.new(1, 1, 1)
	end
	-- dárkové ostrovy v tomto životě (po rebirthu se dají získat znovu)
	local claimed = data.ClaimedGifts or {}
	local parts = {}
	for _, island in GiantGift.Islands do
		table.insert(parts, (if claimed[island.Key] then "✅ " else "🎁 ") .. island.Name .. " " .. FormatNumber.Studs(island.Distance))
	end
	table.insert(parts, (if data.CanRebirth then "✅ " else "🎁 ") .. "GIANT GIFT 100K studs")
	giftsLabel.Text = table.concat(parts, "   ")
end

function QuestsUI.Init(screen: ScreenGui)
	window = Kit.Window(screen, "QUESTS & GOALS", UDim2.fromOffset(760, 500), Kit.Colors.Orange)
	local content = window.Content
	journeyTab = Kit.Button(content, { Text = "🏝️ JOURNEY", Color = Kit.Colors.Turquoise, Size = UDim2.fromOffset(220, 44), Position = UDim2.fromOffset(0, 0) }, function()
		showTab(true)
	end)
	dailyTab = Kit.Button(content, { Text = "📜 DAILY", Color = Kit.Colors.Gray, Size = UDim2.fromOffset(220, 44), Position = UDim2.fromOffset(232, 0) }, function()
		showTab(false)
	end)

	-- ===== DAILY =====
	dailyPage = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -52), Position = UDim2.fromOffset(0, 52), Parent = content })
	streakLabel = Kit.Text(dailyPage, { Text = "", Size = UDim2.new(1, 0, 0, 32), TextColor3 = Kit.Colors.Orange, StrokeThickness = 2 })
	for i = 1, 3 do
		local frame = Kit.Panel(dailyPage, { Size = UDim2.new(1, 0, 0, 96), Position = UDim2.fromOffset(0, 38 + (i - 1) * 106), BackgroundColor3 = Color3.new(1, 1, 1), StrokeThickness = 3 })
		local text = Kit.Text(frame, { Text = "", Size = UDim2.new(0.7, 0, 0, 34), Position = UDim2.fromOffset(14, 6), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Kit.Colors.Text, NoStroke = true })
		local reward = Kit.Text(frame, { Text = "", Size = UDim2.new(0.3, -24, 0, 34), Position = UDim2.new(0.7, 10, 0, 6), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(40, 160, 70), NoStroke = true })
		local bar = Kit.new("Frame", { BackgroundColor3 = Color3.fromRGB(60, 70, 100), Size = UDim2.new(1, -28, 0, 32), Position = UDim2.fromOffset(14, 52), Parent = frame })
		Kit.Corner(bar, 14)
		local fill = Kit.new("Frame", { BackgroundColor3 = Kit.Colors.Turquoise, Size = UDim2.fromScale(0, 1), Parent = bar })
		Kit.Corner(fill, 14)
		local count = Kit.Text(bar, { Text = "", Size = UDim2.new(1, -10, 1, -6), Position = UDim2.fromOffset(5, 3), ZIndex = 2 })
		rows[i] = { Frame = frame, Text = text, Fill = fill, Count = count, Reward = reward }
	end

	-- ===== JOURNEY (cíl hry) =====
	journeyPage = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -52), Position = UDim2.fromOffset(0, 52), Parent = content })
	Kit.Text(journeyPage, {
		Text = "Become the ISLAND LEGEND! Jump farther, reach the gift islands and turn your shack into a PALACE.",
		Size = UDim2.new(1, 0, 0, 44),
		TextColor3 = Kit.Colors.Text,
		NoStroke = true,
		TextWrapped = true,
	})
	for i = 1, #House.Tiers do
		local frame = Kit.Panel(journeyPage, { Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 50 + (i - 1) * 56), BackgroundColor3 = Color3.new(1, 1, 1), StrokeThickness = 2, Radius = 12 })
		local icon = Kit.Text(frame, { Text = "", Size = UDim2.fromOffset(44, 40), Position = UDim2.fromOffset(8, 5), NoStroke = true })
		local name = Kit.Text(frame, { Text = "", Size = UDim2.new(0.42, -60, 0, 34), Position = UDim2.fromOffset(58, 8), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Kit.Colors.Text, NoStroke = true })
		local hint = Kit.Text(frame, { Text = "", Size = UDim2.new(0.58, -16, 0, 28), Position = UDim2.new(0.42, 4, 0, 11), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(90, 95, 120), NoStroke = true })
		tierRows[i] = { Frame = frame, Icon = icon, Name = name, Hint = hint }
	end
	giftsLabel = Kit.Text(journeyPage, { Text = "", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 1, -26), TextColor3 = Kit.Colors.Orange, StrokeThickness = 1.5 })

	showTab(true)
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

-- Otevřít rovnou na záložce s cílem hry (např. po vylepšení domečku)
function QuestsUI.OpenJourney()
	showTab(true)
	window.Open()
end

return QuestsUI

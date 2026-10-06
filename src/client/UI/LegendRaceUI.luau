--!strict
-- LEGEND RACE: panel vpravo (odpočet, živé pořadí závodníků), odpočet 5-4-3-2-1-GO uprostřed
-- obrazovky a na konci stupně vítězů. Vlastní ScreenGui – je vidět i během letu (HUD se schovává).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local FormatNumber = require(Shared.Util.FormatNumber)
local Net = require(Shared.Net)
local Kit = require(script.Parent.Kit)
local Sound = require(script.Parent.Parent.Sound)
local Effects = require(script.Parent.Parent.Effects.Effects)

local LegendRaceUI = {}

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 200, 40)
local ROWS = 5

local panel: Frame
local titleLabel: TextLabel
local timerLabel: TextLabel
local hintLabel: TextLabel
local rows: { TextLabel } = {}
local pierButton: TextButton
local podium: Frame
local podiumRows: { TextLabel } = {}

local info: { [string]: any }? = nil
local lastCount = -1 -- poslední ohlášené číslo odpočtu (5…1, 0 = GO)

local function fmtTime(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

local function renderRows(top: { any })
	for i, row in rows do
		local entry = top[i]
		if entry then
			local mine = entry.UserId == player.UserId
			local dist = if entry.Distance then FormatNumber.Studs(entry.Distance) else "flying… ✈"
			row.Text = `{i}. {entry.Name} – {dist}`
			row.TextColor3 = if mine then Kit.Colors.Yellow else Kit.Colors.White
			row.Visible = true
		else
			row.Visible = false
		end
	end
end

local function showPodium(results: { any })
	local medals = { "🥇", "🥈", "🥉" }
	for i, row in podiumRows do
		local r = results[i]
		row.Text = if r then `{medals[i]} {r.Name}  {FormatNumber.Studs(r.Distance)}` else ""
		row.Visible = r ~= nil
	end
	podium.Visible = #results > 0
	if #results > 0 then
		Kit.Pop(podium, 1.15)
		task.delay(8, function()
			podium.Visible = false
		end)
	end
end

local function onState(newInfo: { [string]: any })
	local previous = info and info.State
	info = newInfo
	local state = newInfo.State
	if state == "Idle" then
		panel.Visible = false
		return
	end
	panel.Visible = true
	pierButton.Visible = state == "Countdown"
	local top = newInfo.Top or {}
	renderRows(top)
	-- výška panelu podle počtu řádků (bez prázdného místa)
	panel.Size = UDim2.fromOffset(330, 96 + math.min(#top, ROWS) * 24 + (if pierButton.Visible then 58 else 6))
	if state == "Countdown" then
		titleLabel.Text = "👑 LEGEND RACE"
		hintLabel.Text = "Go to the pier! Jump on GO – longest jump wins!"
		if previous ~= "Countdown" then
			lastCount = -1
			Kit.Pop(panel, 1.2)
			Sound.Play("Perfect", 0.8)
			Effects.BigText("👑 LEGEND RACE SOON!", GOLD, 1.6, 0.3)
		end
	elseif state == "Open" then
		titleLabel.Text = "👑 JUMP NOW!"
		hintLabel.Text = "Only your FIRST jump counts!"
	elseif state == "Waiting" then
		titleLabel.Text = "👑 LEGEND RACE"
		timerLabel.Text = ""
		hintLabel.Text = "Waiting for the last racers to land…"
	elseif state == "Results" then
		titleLabel.Text = "👑 RESULTS"
		timerLabel.Text = ""
		hintLabel.Text = if (newInfo.Racers or 0) > 0 then "Next race in a few minutes!" else "Nobody jumped – next time jump on GO!"
		if previous ~= "Results" then
			showPodium(newInfo.Results or {})
		end
	end
end

-- odpočet v panelu a velká čísla 5-4-3-2-1-GO
local function update()
	if not info or not panel.Visible then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local state = info.State
	if state == "Countdown" then
		local left = (info.GoAt or now) - now
		timerLabel.Text = "Starts in " .. fmtTime(left)
		local count = math.ceil(left)
		if count <= 5 and count >= 1 and count ~= lastCount then
			lastCount = count
			Effects.BigText(tostring(count), GOLD, 0.8, 0.4)
			Sound.Play("Click", 1.2)
		end
	elseif state == "Open" then
		timerLabel.Text = "Jump within " .. fmtTime((info.WindowEndsAt or now) - now)
		if lastCount ~= 0 then
			lastCount = 0
			Effects.BigText("GO! GO! GO!", Kit.Colors.Green, 1.2, 0.4)
			Sound.Play("Perfect", 1.2)
			Effects.Shake(0.2)
		end
	end
end

function LegendRaceUI.Init()
	local screen = Kit.Screen("LegendRace", 12)
	panel = Kit.Panel(screen, {
		Name = "LegendRacePanel",
		Size = UDim2.fromOffset(330, 236),
		Position = UDim2.new(1, -16, 0, 222),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(70, 45, 120),
		Visible = false,
	})
	Kit.Gradient(panel, Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 200))
	titleLabel = Kit.Text(panel, { Text = "👑 LEGEND RACE", Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 6), TextColor3 = GOLD, StrokeThickness = 3 })
	timerLabel = Kit.Text(panel, { Text = "", Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 40) })
	hintLabel = Kit.Text(panel, { Text = "", Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 68), TextColor3 = Color3.fromRGB(220, 220, 255), StrokeThickness = 1.5 })
	for i = 1, ROWS do
		rows[i] = Kit.Text(panel, { Text = "", Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 92 + (i - 1) * 24), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 1.5, Visible = false })
	end
	pierButton = Kit.Button(panel, { Text = "GO TO PIER", Color = Kit.Colors.Green, Size = UDim2.new(1, -24, 0, 46), Position = UDim2.new(0, 12, 1, -54) }, function()
		Sound.Play("Click")
		Net.Event("Teleport"):FireServer("Pier")
	end)

	-- stupně vítězů uprostřed obrazovky
	podium = Kit.Panel(screen, {
		Name = "LegendPodium",
		Size = UDim2.fromOffset(460, 200),
		Position = UDim2.fromScale(0.5, 0.3),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(70, 45, 120),
		Visible = false,
	})
	Kit.Gradient(podium, Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 200))
	Kit.Text(podium, { Text = "👑 LEGEND RACE 👑", Size = UDim2.new(1, -20, 0, 44), Position = UDim2.fromOffset(10, 8), TextColor3 = GOLD, StrokeThickness = 3 })
	for i = 1, 3 do
		podiumRows[i] = Kit.Text(podium, { Text = "", Size = UDim2.new(1, -30, 0, if i == 1 then 46 else 36), Position = UDim2.fromOffset(15, if i == 1 then 56 else 62 + (i - 1) * 40), TextColor3 = if i == 1 then GOLD else Kit.Colors.White, StrokeThickness = 2.5 })
	end

	Net.Event("LegendRace").OnClientEvent:Connect(onState)
	RunService.Heartbeat:Connect(update)
end

return LegendRaceUI

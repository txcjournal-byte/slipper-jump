--!strict
-- HUD: peníze, příjem, level, boost, tlačítka (předměty, kolo, Robux košík, nastavení, rebirth),
-- hlášky a oznámení pro celý server, událost na serveru, živá tabulka Jump Contest
-- a série PERFECT skoků.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local FormatNumber = require(Shared.Util.FormatNumber)
local Formulas = require(Shared.Formulas)
local World = require(Shared.Config.World)
local Catalog = require(Shared.Catalog)
local Products = require(Shared.Config.Products)
local Net = require(Shared.Net)
local Kit = require(script.Parent.Kit)
local Purchase = require(script.Parent.Parent.Purchase)
local ClientState = require(script.Parent.Parent.ClientState)
local Sound = require(script.Parent.Parent.Sound)

local HUD = {}

local screen: ScreenGui
local moneyLabel: TextLabel
local incomeLabel: TextLabel
local levelLabel: TextLabel
local xpFill: Frame
local xpText: TextLabel
local jumpLabel: TextLabel
local goalFill: Frame
local goalText: TextLabel
local boostPill: Frame
local boostLabel: TextLabel
local luckPill: Frame
local luckLabel: TextLabel
local carryPanel: Frame
local carryLabel: TextLabel
local quickSellButton: TextButton
local toastHolder: Frame
local announceHolder: Frame
local spinBadge: TextLabel
local rebirthButton: TextButton
local superJumpLabel: TextLabel
local eventPanel: Frame
local eventName: TextLabel
local eventDesc: TextLabel
local nextEventPill: Frame
local nextEventLabel: TextLabel
local eventEndsAt = 0
local eventTitle = ""
local starterButton: TextButton
local questBadge: Frame
local contestPanel: Frame
local contestRows: { TextLabel } = {}
local contestVisible = false
local streakPill: Frame
local streakLabel: TextLabel
local streakCount = 0

local callbacks: { [string]: () -> () } = {}
local displayedMoney = 0

function HUD.Bind(name: string, fn: () -> ())
	callbacks[name] = fn
end

local function call(name: string)
	return function()
		Sound.Play("Click")
		local fn = callbacks[name]
		if fn then
			fn()
		end
	end
end

local KIND_COLORS: { [string]: Color3 } = {
	Info = Kit.Colors.Turquoise,
	Success = Kit.Colors.Green,
	Warning = Kit.Colors.Orange,
	Money = Kit.Colors.Yellow,
	Record = Kit.Colors.Pink,
	Gift = Kit.Colors.Yellow,
	Mythic = Color3.fromRGB(255, 90, 200),
	Secret = Color3.fromRGB(40, 40, 50),
}

function HUD.Notify(text: string, kind: string?)
	local color = KIND_COLORS[kind or "Info"] or Kit.Colors.Turquoise
	local toast = Kit.Panel(toastHolder, {
		Size = UDim2.fromOffset(560, 54),
		BackgroundColor3 = color,
		StrokeThickness = 3,
		Radius = 14,
	})
	Kit.Text(toast, {
		Text = text,
		Size = UDim2.new(1, -24, 1, -12),
		Position = UDim2.fromOffset(12, 6),
	})
	Kit.Pop(toast, 1.2)
	task.delay(3.5, function()
		TweenService:Create(toast, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		for _, d in toast:GetDescendants() do
			if d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			end
		end
		Debris:AddItem(toast, 0.35)
	end)
end

function HUD.Announce(text: string, kind: string?)
	local color = KIND_COLORS[kind or "Info"] or Kit.Colors.Yellow
	local banner = Kit.Panel(announceHolder, {
		Size = UDim2.fromOffset(760, 70),
		BackgroundColor3 = color,
		Radius = 20,
	})
	Kit.Gradient(banner, Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215))
	Kit.Text(banner, {
		Text = text,
		Size = UDim2.new(1, -30, 1, -14),
		Position = UDim2.fromOffset(15, 7),
		StrokeThickness = 3,
	})
	Kit.Pop(banner, 1.3)
	task.delay(5, function()
		TweenService:Create(banner, TweenInfo.new(0.4), { Position = banner.Position - UDim2.fromOffset(0, 30), BackgroundTransparency = 1 }):Play()
		for _, d in banner:GetDescendants() do
			if d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
		end
		Debris:AddItem(banner, 0.45)
	end)
end

-- Mobil / tablet (dotyk bez klávesnice): větší tlačítka v mřížce, aby se vešla nad joystick a tlačítko skoku
local TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local SIDE_SIZE = if TOUCH then 96 else 78

local function sideButton(parent: Instance, icon: string, text: string, color: Color3, order: number, action: string): TextButton
	local button = Kit.Button(parent, { Text = "", Color = color, Size = UDim2.fromOffset(SIDE_SIZE, SIDE_SIZE), LayoutOrder = order, Radius = 20, Name = action }, call(action))
	Kit.Text(button, { Text = icon, Size = UDim2.new(1, 0, 0.62, 0), Position = UDim2.fromScale(0, 0.04), NoStroke = true, ZIndex = 2 })
	Kit.Text(button, { Text = text, Size = UDim2.new(1, -6, 0.3, 0), Position = UDim2.new(0, 3, 0.66, 0), ZIndex = 2 })
	return button
end

function HUD.Init()
	screen = Kit.Screen("HUD", 5)

	-- ===== Peníze a level (vlevo nahoře) =====
	local moneyPanel = Kit.Panel(screen, {
		Size = UDim2.fromOffset(330, 92),
		Position = UDim2.fromOffset(16, 14),
		BackgroundColor3 = Color3.fromRGB(255, 248, 225),
	})
	local coin = Kit.new("Frame", {
		BackgroundColor3 = Kit.Colors.Yellow,
		Size = UDim2.fromOffset(68, 68),
		Position = UDim2.fromOffset(12, 12),
		Parent = moneyPanel,
	})
	Kit.Corner(coin, 34)
	Kit.Stroke(coin, 3, Color3.fromRGB(200, 140, 20), true)
	Kit.Text(coin, { Text = "$", Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), TextColor3 = Color3.fromRGB(255, 255, 230), StrokeColor = Color3.fromRGB(180, 120, 10) })
	moneyLabel = Kit.Text(moneyPanel, {
		Text = "$0",
		Size = UDim2.new(1, -100, 0, 50),
		Position = UDim2.fromOffset(90, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Kit.Colors.Yellow,
		StrokeThickness = 3,
	})
	incomeLabel = Kit.Text(moneyPanel, {
		Text = "+$0/s",
		Size = UDim2.new(1, -100, 0, 28),
		Position = UDim2.fromOffset(92, 56),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(130, 255, 140),
	})

	local levelPanel = Kit.Panel(screen, {
		Size = UDim2.fromOffset(330, 56),
		Position = UDim2.fromOffset(16, 114),
		BackgroundColor3 = Color3.fromRGB(235, 245, 255),
	})
	local badge = Kit.new("Frame", {
		BackgroundColor3 = Kit.Colors.Blue,
		Size = UDim2.fromOffset(90, 40),
		Position = UDim2.fromOffset(8, 8),
		Parent = levelPanel,
	})
	Kit.Corner(badge, 12)
	levelLabel = Kit.Text(badge, { Text = "Lv. 1", Size = UDim2.new(1, -8, 1, -6), Position = UDim2.fromOffset(4, 3) })
	local bar = Kit.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(60, 70, 100),
		Size = UDim2.new(1, -118, 0, 30),
		Position = UDim2.fromOffset(108, 13),
		Parent = levelPanel,
	})
	Kit.Corner(bar, 12)
	xpFill = Kit.new("Frame", {
		BackgroundColor3 = Kit.Colors.Turquoise,
		Size = UDim2.fromScale(0, 1),
		Parent = bar,
	})
	Kit.Corner(xpFill, 12)
	Kit.Gradient(xpFill, Color3.fromRGB(120, 240, 255), Color3.fromRGB(20, 170, 230))
	xpText = Kit.Text(bar, { Text = "0 / 100 XP", Size = UDim2.new(1, -10, 1, -6), Position = UDim2.fromOffset(5, 3), ZIndex = 2 })

	jumpLabel = Kit.Text(screen, {
		Text = "",
		Size = UDim2.fromOffset(330, 30),
		Position = UDim2.fromOffset(20, 176),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(200, 240, 255),
	})
	-- další cíl nahoře uprostřed: nejbližší dárek a jak daleko k němu (podle nejlepšího skoku)
	local goalBar = Kit.Panel(screen, {
		Size = UDim2.fromOffset(380, 34),
		Position = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(40, 60, 110),
		Radius = 17,
		StrokeThickness = 3,
	})
	goalFill = Kit.new("Frame", { BackgroundColor3 = Kit.Colors.Yellow, Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, Parent = goalBar })
	Kit.Corner(goalFill, 17)
	Kit.Gradient(goalFill, Color3.fromRGB(255, 230, 110), Color3.fromRGB(255, 160, 40))
	goalText = Kit.Text(goalBar, { Text = "", Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), ZIndex = 3, StrokeThickness = 2.5 })

	superJumpLabel = Kit.Text(screen, {
		Text = "",
		Size = UDim2.fromOffset(560, 28),
		Position = UDim2.fromOffset(20, 206),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(120, 230, 255),
		Visible = false,
	})

	boostPill = Kit.Panel(screen, {
		Size = UDim2.fromOffset(220, 44),
		Position = UDim2.fromOffset(16, 240),
		BackgroundColor3 = Kit.Colors.Orange,
		Visible = false,
		Radius = 22,
	})
	boostLabel = Kit.Text(boostPill, { Text = "2x MONEY", Size = UDim2.new(1, -16, 1, -10), Position = UDim2.fromOffset(8, 5) })
	-- Lucky Potion (vedle 2x Money; když boost neběží, posune se na jeho místo)
	luckPill = Kit.Panel(screen, {
		Size = UDim2.fromOffset(200, 44),
		Position = UDim2.fromOffset(244, 240),
		BackgroundColor3 = Kit.Colors.Green,
		Visible = false,
		Radius = 22,
	})
	luckLabel = Kit.Text(luckPill, { Text = "2x LUCK", Size = UDim2.new(1, -16, 1, -10), Position = UDim2.fromOffset(8, 5) })

	-- ===== Tlačítka vlevo =====
	local left = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(110, 620),
		Position = UDim2.fromOffset(16, 292), -- pod penězi, levelem a boostem
		AnchorPoint = Vector2.new(0, 0),
		Parent = screen,
	})
	if TOUCH then
		-- 3 sloupce × 2 řady (jinak by spodní tlačítka zakryl joystick nebo by se nevešla)
		left.Size = UDim2.fromOffset(3 * (SIDE_SIZE + 10), 2 * (SIDE_SIZE + 10))
		left.Position = UDim2.fromOffset(16, 244)
		Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(SIDE_SIZE, SIDE_SIZE), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = left })
	else
		Kit.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = left })
	end
	sideButton(left, "👟", "ITEMS", Kit.Colors.Turquoise, 1, "Inventory")
	local spinButton = sideButton(left, "🎡", "SPIN", Kit.Colors.Pink, 2, "Spinner")
	local badgeFrame = Kit.new("Frame", {
		BackgroundColor3 = Kit.Colors.Coral,
		Size = UDim2.fromOffset(38, 38),
		Position = UDim2.new(1, 8, 0, -8),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 5,
		Visible = false,
		Parent = spinButton,
	})
	Kit.Corner(badgeFrame, 19)
	Kit.Stroke(badgeFrame, 3, Kit.Colors.Outline, true)
	spinBadge = Kit.Text(badgeFrame, { Text = "1", Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), ZIndex = 6 })
	local questButton = sideButton(left, "📜", "QUESTS", Kit.Colors.Orange, 3, "Quests")
	questBadge = Kit.new("Frame", {
		BackgroundColor3 = Kit.Colors.Coral,
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(1, 6, 0, -6),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 5,
		Visible = false,
		Parent = questButton,
	})
	Kit.Corner(questBadge, 13)
	Kit.Stroke(questBadge, 3, Kit.Colors.Outline, true)
	sideButton(left, "🏠", "HOUSE", Kit.Colors.Green, 4, "TeleportHouse")
	sideButton(left, "🌊", "PIER", Kit.Colors.Blue, 5, "TeleportPier")
	rebirthButton = sideButton(left, "♻", "REBIRTH", Kit.Colors.Purple, 6, "Rebirth")
	rebirthButton.Visible = false

	-- ===== Tlačítka vpravo (Robux košík, nastavení) =====
	local right = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(110, 330),
		Position = UDim2.new(1, -16, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Parent = screen,
	})
	if TOUCH then
		-- 2 × 2 výš nad tlačítkem skoku Robloxu
		right.Size = UDim2.fromOffset(2 * (SIDE_SIZE + 10), 2 * (SIDE_SIZE + 10))
		right.Position = UDim2.new(1, -16, 0.42, 0)
		Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(SIDE_SIZE, SIDE_SIZE), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = right })
	else
		Kit.new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = right })
	end
	local storeButton = sideButton(right, "🛒", "STORE", Kit.Colors.Green, 1, "RobuxShop")
	storeButton.Visible = Products.AnyConfigured()
	sideButton(right, "⚙", "SETTINGS", Kit.Colors.Gray, 2, "Settings")
	sideButton(right, "💰", "SELL", Kit.Colors.Orange, 3, "TeleportSell")
	starterButton = sideButton(right, "🎁", "STARTER", Kit.Colors.Pink, 0, "StarterPack")
	starterButton.Visible = false

	-- ===== Událost na serveru (vpravo nahoře) =====
	eventPanel = Kit.Panel(screen, {
		Size = UDim2.fromOffset(330, 92),
		Position = UDim2.new(1, -16, 0, 14),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Kit.Colors.Yellow,
		Visible = false,
	})
	Kit.Gradient(eventPanel, Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215))
	eventName = Kit.Text(eventPanel, { Text = "", Size = UDim2.new(1, -20, 0, 42), Position = UDim2.fromOffset(10, 6), StrokeThickness = 3 })
	eventDesc = Kit.Text(eventPanel, { Text = "", Size = UDim2.new(1, -20, 0, 32), Position = UDim2.fromOffset(10, 50), StrokeThickness = 2 })

	-- odpočet do další události (když zrovna žádná neběží) – ať hráči vědí, že se vyplatí zůstat
	nextEventPill = Kit.Panel(screen, {
		Size = UDim2.fromOffset(330, 44),
		Position = UDim2.new(1, -16, 0, 14),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Kit.Colors.Navy,
		Visible = false,
		Radius = 22,
	})
	nextEventLabel = Kit.Text(nextEventPill, { Text = "", Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5), StrokeThickness = 2.5 })

	-- ===== Jump Contest: živá tabulka top 3 (pod událostí) =====
	contestPanel = Kit.Panel(screen, {
		Size = UDim2.fromOffset(330, 104),
		Position = UDim2.new(1, -16, 0, 112),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(255, 240, 248),
		Visible = false,
	})
	Kit.Text(contestPanel, { Text = "🏆 CONTEST TOP 3", Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 4), TextColor3 = Kit.Colors.Pink, StrokeThickness = 2 })
	local placeColors = { Kit.Colors.Yellow, Color3.fromRGB(215, 220, 235), Color3.fromRGB(230, 150, 90) }
	for i = 1, 3 do
		contestRows[i] = Kit.Text(contestPanel, {
			Text = "",
			Size = UDim2.new(1, -24, 0, 22),
			Position = UDim2.fromOffset(12, 30 + (i - 1) * 24),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = placeColors[i],
			StrokeThickness = 2,
		})
	end

	-- ===== Série PERFECT skoků =====
	streakPill = Kit.Panel(screen, {
		Size = UDim2.fromOffset(260, 42),
		Position = UDim2.new(1, -16, 0, 14),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Kit.Colors.Pink,
		Visible = false,
		Radius = 21,
	})
	streakLabel = Kit.Text(streakPill, { Text = "", Size = UDim2.new(1, -16, 1, -10), Position = UDim2.fromOffset(8, 5) })

	-- ===== Co nese hráč =====
	carryPanel = Kit.Panel(screen, {
		Size = UDim2.fromOffset(620, 76),
		Position = UDim2.new(0.5, 0, 1, -170),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Color3.fromRGB(255, 245, 210),
		Visible = false,
	})
	carryLabel = Kit.Text(carryPanel, {
		Text = "",
		Size = UDim2.new(1, -150, 0.5, -4),
		Position = UDim2.fromOffset(12, 6),
		TextColor3 = Kit.Colors.Yellow,
	})
	Kit.Text(carryPanel, {
		Text = "Place or swap it in your house, sell it at SELL, or gift it to a player",
		Size = UDim2.new(1, -150, 0.4, -4),
		Position = UDim2.new(0, 12, 0.55, 0),
		TextColor3 = Kit.Colors.White,
		StrokeThickness = 2,
	})

	-- rychlý prodej běžných předmětů (nemusí se chodit ke stánku)
	quickSellButton = Kit.Button(carryPanel, {
		Text = "SELL",
		Color = Kit.Colors.Coral,
		Size = UDim2.fromOffset(120, 56),
		Position = UDim2.new(1, -10, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Name = "QuickSell",
	}, function()
		Sound.Play("Click")
		Net.Event("QuickSell"):FireServer()
	end)

	-- ===== Hlášky =====
	-- vlastní obrazovka, aby hlášky byly vidět i během skoku, kdy je HUD schovaný
	local toastScreen = Kit.Screen("Toasts", 9)
	toastHolder = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(560, 300),
		Position = UDim2.new(0.5, 0, 0, 184), -- pod pruhem tutoriálu, ať ho nepřekrývají
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = toastScreen,
	})
	Kit.new("UIListLayout", { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = toastHolder })
	announceHolder = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(760, 160),
		Position = UDim2.new(0.5, 0, 0, 16),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = toastScreen,
	})
	Kit.new("UIListLayout", { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = announceHolder })

	ClientState.Changed:Connect(HUD.Refresh)

	-- plynulé přičítání peněz + odpočty
	task.spawn(function()
		while true do
			local data = ClientState.Data
			if data then
				local target = data.Money :: number
				if math.abs(target - displayedMoney) < 1 then
					displayedMoney = target
				else
					displayedMoney += (target - displayedMoney) * 0.35
				end
				moneyLabel.Text = FormatNumber.Money(displayedMoney)
				local eventLeft = eventEndsAt - ClientState.ServerNow()
				eventPanel.Visible = eventLeft > 0
				if eventLeft > 0 then
					eventName.Text = "⚡ " .. eventTitle .. "  " .. FormatNumber.Time(eventLeft)
				end
				local nextAt = workspace:GetAttribute("NextEventAt")
				local nextLeft = if typeof(nextAt) == "number" then nextAt - ClientState.ServerNow() else 0
				nextEventPill.Visible = eventLeft <= 0 and nextLeft > 0
				if nextEventPill.Visible then
					nextEventLabel.Text = "⏳ Next event in " .. FormatNumber.Time(nextLeft)
				end
				-- panely vpravo nahoře pod sebou: událost (nebo odpočet) → soutěž → série
				local y = if eventPanel.Visible then 112 elseif nextEventPill.Visible then 66 else 14
				contestPanel.Visible = contestVisible
				contestPanel.Position = UDim2.new(1, -16, 0, y)
				if contestVisible then
					y += 112
				end
				streakPill.Position = UDim2.new(1, -16, 0, y)
				local boostLeft = (data.BoostUntil :: number) - ClientState.ServerNow()
				boostPill.Visible = boostLeft > 0
				if boostLeft > 0 then
					boostLabel.Text = "2x MONEY " .. FormatNumber.Time(boostLeft)
				end
				local luckLeft = ((data.LuckUntil or 0) :: number) - ClientState.ServerNow()
				luckPill.Visible = luckLeft > 0
				if luckLeft > 0 then
					luckLabel.Text = "🍀 2x LUCK " .. FormatNumber.Time(luckLeft)
					luckPill.Position = UDim2.fromOffset(if boostLeft > 0 then 244 else 16, 240)
				end
			end
			task.wait(0.05)
		end
	end)
end

function HUD.Refresh(data: { [string]: any })
	local previous = displayedMoney
	if data.Money > previous + 0.5 then
		Kit.Pop(moneyLabel, 1.08)
	end
	incomeLabel.Text = "+" .. FormatNumber.Money(data.IncomePerSecond) .. "/s" .. (if data.Multiplier > 1 then "  (x" .. string.format("%.1f", data.Multiplier) .. ")" else "")
	levelLabel.Text = "Lv. " .. data.Level
	local ratio = if data.XPToNext > 0 then math.clamp(data.XP / data.XPToNext, 0, 1) else 1
	TweenService:Create(xpFill, TweenInfo.new(0.3), { Size = UDim2.fromScale(ratio, 1) }):Play()
	xpText.Text = if data.Level >= 50 then "MAX LEVEL" else FormatNumber.Short(data.XP) .. " / " .. FormatNumber.Short(data.XPToNext) .. " XP"
	local passes = data.Passes or {}
	local base = Formulas.BaseJump(data.EquippedSlippers, if data.EquippedHat ~= "" then data.EquippedHat else nil)
		* Formulas.PassJumpMultiplier(passes.SuperJumper == true)
	jumpLabel.Text = "Jump: ~" .. FormatNumber.Studs(math.floor(base)) .. "   Best: " .. FormatNumber.Studs(data.BestJump)
	-- další cíl: nejbližší dárek, který hráč v tomto životě ještě nemá
	local island = Formulas.NextGiftIsland(data.ClaimedGifts)
	local goalDistance = if island then island.Distance else World.GiftDistance
	local goalName = if island then island.Name else "GIANT GIFT"
	if data.CanRebirth then
		goalText.Text = "🎁 GIANT GIFT OPENED! REBIRTH READY!"
		goalFill.Size = UDim2.fromScale(1, 1)
	else
		-- jak daleko teď hráč doskočí se svými pantoflemi (po znovuzrození se starý rekord nepočítá)
		local reach = base
		goalText.Text = `🎁 NEXT: {goalName} at {FormatNumber.Studs(goalDistance)}  ({math.floor(math.clamp(reach / goalDistance, 0, 1) * 100)}%)`
		TweenService:Create(goalFill, TweenInfo.new(0.4), { Size = UDim2.fromScale(math.clamp(reach / goalDistance, 0.04, 1), 1) }):Play()
	end
	-- jednorázové skoky: Mega Jump se použije dřív než Super Jump
	local megaJumps: number = data.MegaJumps or 0
	local charges = {}
	if megaJumps > 0 then
		table.insert(charges, "🚀 Mega Jump x" .. megaJumps)
	end
	if data.SuperJumps > 0 then
		table.insert(charges, "⚡ Super Jump x" .. data.SuperJumps)
	end
	-- štíty do slalomu (Bubble Shield) a repelenty proti žralokům – ať hráč vidí, co koupil
	if (data.Shields or 0) > 0 then
		table.insert(charges, "💜 Shield x" .. data.Shields)
	end
	if (data.Repellents or 0) > 0 then
		table.insert(charges, "🦈 Repellent x" .. data.Repellents)
	end
	superJumpLabel.Visible = #charges > 0
	superJumpLabel.Text = table.concat(charges, "   ")
	local spins = data.DailySpins + data.ExtraSpins
	spinBadge.Text = tostring(spins)
	local badgeFrame = spinBadge.Parent :: Frame
	badgeFrame.Visible = spins > 0
	rebirthButton.Visible = data.CanRebirth == true
	starterButton.Visible = data.StarterPackBought ~= true and Products.IsConfigured("StarterPack") and Purchase.Allowed("StarterPack")
	local unfinished = false
	for _, quest in data.Quests or {} do
		if not quest.Done then
			unfinished = true
		end
	end
	questBadge.Visible = unfinished
	local streak = data.PerfectStreak or 0
	streakPill.Visible = streak >= 2
	if streak >= 2 then
		local bonus = math.floor(Formulas.PerfectStreakBonus(streak) * 100 + 0.5)
		streakLabel.Text = "PERFECT STREAK x" .. streak .. "  +" .. bonus .. "%"
		if streak ~= streakCount then
			Kit.Pop(streakPill, 1.2)
		end
	end
	streakCount = streak
	local carried = data.Carried
	carryPanel.Visible = carried ~= nil
	if carried then
		local cfg = Catalog.Item(carried.Id)
		if cfg then
			local rarity = Catalog.Rarity(cfg.Rarity)
			carryLabel.Text = "Carrying: " .. cfg.Name .. " (" .. rarity.Name .. ", +" .. FormatNumber.Money(cfg.Income) .. "/s)"
			carryLabel.TextColor3 = if rarity.Name == "Secret" or rarity.Name == "Common" then Kit.Colors.White else rarity.Color
			quickSellButton.Visible = rarity.Order <= 3
		end
	end
end

function HUD.SetServerEvent(info: { [string]: any }?)
	if info then
		eventEndsAt = info.EndsAt
		eventTitle = info.Name
		eventName.Text = "⚡ " .. info.Name
		eventDesc.Text = info.Description
		eventPanel.BackgroundColor3 = info.Color
		Kit.Pop(eventPanel, 1.2)
	else
		eventEndsAt = 0
		eventPanel.Visible = false
	end
end

-- Živá tabulka soutěže (nil = soutěž skončila)
function HUD.SetContestBoard(info: { [string]: any }?)
	contestVisible = info ~= nil
	contestPanel.Visible = contestVisible
	if not info then
		return
	end
	local top = info.Top or {}
	for i, row in contestRows do
		local entry = top[i]
		row.Text = if entry then `{i}. {entry.Name} – {FormatNumber.Studs(entry.Distance)}` else `{i}. —`
	end
end

function HUD.SetVisible(visible: boolean)
	screen.Enabled = visible
end

function HUD.Screen(): ScreenGui
	return screen
end

return HUD

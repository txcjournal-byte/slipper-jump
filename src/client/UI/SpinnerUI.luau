--!strict
-- Kolo štěstí v UI: 3D kolo (ViewportFrame), šance u kola (Roblox je vyžaduje u placených točení),
-- tlačítko SPIN s odpočtem a nákup extra točení.

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Spinner = require(Shared.Config.Spinner)
local Products = require(Shared.Config.Products)
local FormatNumber = require(Shared.Util.FormatNumber)
local Signal = require(Shared.Util.Signal)
local Net = require(Shared.Net)
local Kit = require(script.Parent.Kit)
local HUD = require(script.Parent.HUD)
local ClientState = require(script.Parent.Parent.ClientState)
local Sound = require(script.Parent.Parent.Sound)
local Effects = require(script.Parent.Parent.Effects.Effects)
local Purchase = require(script.Parent.Parent.Purchase)

local SpinnerUI = {}

SpinnerUI.Spun = Signal.new() :: Signal.Signal<number>

local window: Kit.Window
local wheel: Model
local wheelCenter = Vector3.zero
local spinButton: TextButton
local resultLabel: TextLabel
local spinning = false
local spinFunction = Net.Function("Spin")

local RADIUS = 10
-- kamera kola: ze vzdálenosti 34 s FOV 40 je vidět ±12,37 studu → převod na měřítko okna
local VIEW_HALF = 34 * math.tan(math.rad(20))

-- krátký popisek na dílek kola (dlouhý je v tabulce šancí vedle)
local function shortLabel(segment: Spinner.Segment): string
	local reward = segment.Reward
	if reward.Rarity then
		return if reward.Rarity == "Legendary" then "⭐ LEGEND" else string.upper(reward.Rarity)
	elseif reward.BoostMinutes then
		return "2x 💰"
	end
	return segment.Label
end

-- 2D popisky nad 3D kolem (SurfaceGui se ve ViewportFrame nevykresluje): každý snímek
-- se dopočítá střed dílku a popisek se posune s ním, takže se točí spolu s kolem
local function attachLabels(holder: Instance, model: Model)
	local labels: { TextLabel } = {}
	for i, segment in Spinner.Segments do
		labels[i] = Kit.Text(holder, {
			Text = shortLabel(segment),
			Size = UDim2.fromScale(0.2, 0.08),
			AnchorPoint = Vector2.new(0.5, 0.5),
			TextColor3 = Kit.Colors.White,
			StrokeThickness = 2.5,
			ZIndex = 2,
		})
	end
	RunService.RenderStepped:Connect(function()
		if not (holder :: GuiObject).Visible then
			return
		end
		local sums: { Vector3 } = {}
		for _, child in model:GetChildren() do
			local index = tonumber(string.match(child.Name, "^Segment_(%d+)$"))
			if index and child:IsA("BasePart") then
				sums[index] = (sums[index] or Vector3.zero) + child.Position
			end
		end
		for i, label in labels do
			local sum = sums[i]
			if sum then
				local flat = Vector3.new(sum.X, sum.Y, 0)
				local p = if flat.Magnitude > 0 then flat.Unit * RADIUS * 0.63 else Vector3.zero
				-- kamera se dívá ve směru +Z, takže +X světa je na obrazovce vlevo
				label.Position = UDim2.fromScale(0.5 - p.X / (2 * VIEW_HALF), 0.5 - p.Y / (2 * VIEW_HALF))
			end
		end
	end)
end

local function buildWheel(parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = "Wheel"
	local center = CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -1))
	local count = #Spinner.Segments
	local halfAngle = math.pi / count
	local halfWidth = RADIUS * math.tan(halfAngle)
	local normal = center.LookVector
	local hub = Instance.new("Part")
	hub.Shape = Enum.PartType.Cylinder
	hub.Size = Vector3.new(1.2, 3, 3)
	hub.CFrame = CFrame.new(normal * 0.6) * CFrame.Angles(0, math.rad(90), 0)
	hub.Color = Color3.fromRGB(255, 215, 60)
	hub.Material = Enum.Material.Metal
	hub.Anchored = true
	hub.Parent = m
	m.PrimaryPart = hub
	for i, segment in Spinner.Segments do
		local phi = (i - 1) * (2 * math.pi / count)
		local up, right = center.UpVector, center.RightVector
		local v = up * math.cos(phi) + right * math.sin(phi)
		local u = -up * math.sin(phi) + right * math.cos(phi)
		for _, s in { 1, -1 } do
			local yAxis = u * s
			local xAxis = yAxis:Cross(v)
			local w = Instance.new("WedgePart")
			w.Size = Vector3.new(0.6, halfWidth, RADIUS)
			w.CFrame = CFrame.fromMatrix(u * s * (halfWidth / 2) + v * (RADIUS / 2), xAxis, yAxis, v)
			w.Color = segment.Color
			w.Material = Enum.Material.SmoothPlastic
			w.Anchored = true
			w.Name = "Segment_" .. i
			w.Parent = m
		end
		local edge = up * math.cos(phi + halfAngle) + right * math.sin(phi + halfAngle)
		local line = Instance.new("Part")
		line.Size = Vector3.new(0.25, 0.25, RADIUS)
		line.CFrame = CFrame.lookAt(edge * RADIUS / 2 + normal * 0.35, edge * RADIUS + normal * 0.35)
		line.Color = Color3.new(1, 1, 1)
		line.Anchored = true
		line.Parent = m
	end
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		local dir = center.UpVector * math.cos(a) + center.RightVector * math.sin(a)
		local bulb = Instance.new("Part")
		bulb.Shape = Enum.PartType.Ball
		bulb.Size = Vector3.one * 1.1
		bulb.CFrame = CFrame.new(dir * (RADIUS + 0.5))
		bulb.Color = if i % 2 == 0 then Color3.fromRGB(255, 240, 150) else Color3.fromRGB(255, 160, 40)
		bulb.Material = Enum.Material.Neon
		bulb.Anchored = true
		bulb.Parent = m
	end
	m.Parent = parent
	return m
end

-- Úhel, o který se musí kolo otočit, aby byl dílek `index` nahoře pod ukazatelem
function SpinnerUI.AngleToTop(model: Model, center: Vector3, axis: Vector3, index: number): number
	local sum, n = Vector3.zero, 0
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name == "Segment_" .. index then
			sum += child.Position
			n += 1
		end
	end
	if n == 0 then
		return 0
	end
	local v = sum / n - center
	v -= axis * v:Dot(axis)
	local up = Vector3.yAxis - axis * Vector3.yAxis:Dot(axis)
	return math.atan2(v:Cross(up):Dot(axis), v:Dot(up))
end

-- Animace otočení modelu kolem osy procházející středem
function SpinnerUI.Animate(model: Model, center: Vector3, axis: Vector3, index: number, duration: number)
	local angle = SpinnerUI.AngleToTop(model, center, axis, index)
	if angle < 0 then
		angle += math.pi * 2
	end
	local total = angle + math.pi * 2 * 5
	local startPivot = model:GetPivot()
	local value = Instance.new("NumberValue")
	value.Value = 0
	value.Changed:Connect(function(alpha)
		local rotation = CFrame.new(center) * CFrame.fromAxisAngle(axis, total * alpha) * CFrame.new(-center)
		model:PivotTo(rotation * startPivot)
	end)
	local tween = TweenService:Create(value, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Value = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		value:Destroy()
	end)
end

local function priceOf(key: string): number
	for _, product in Products.DevProducts do
		if product.Key == key then
			return product.Price
		end
	end
	return 0
end

local function promptProduct(key: string)
	if not Purchase.Prompt(key) then
		HUD.Notify("This is not available yet. Check back soon!", "Warning")
	end
end

local function refresh()
	local data = ClientState.Data
	if not data or spinning then
		return
	end
	local total = data.DailySpins + data.ExtraSpins
	if total > 0 then
		Kit.SetButtonText(spinButton, "SPIN! (" .. total .. ")")
		spinButton.BackgroundColor3 = Kit.Colors.Green
	else
		Kit.SetButtonText(spinButton, "FREE SPIN IN " .. FormatNumber.Time(data.NextFreeSpin - ClientState.ServerNow()))
		spinButton.BackgroundColor3 = Kit.Colors.Gray
	end
end

local function doSpin()
	if spinning then
		return
	end
	local result = spinFunction:InvokeServer()
	if not result or not result.Ok then
		HUD.Notify(if result then result.Message else "Try again.", "Warning")
		return
	end
	spinning = true
	Sound.Play("Spin")
	resultLabel.Text = "Spinning..."
	Kit.SetButtonText(spinButton, "...")
	SpinnerUI.Animate(wheel, wheelCenter, Vector3.new(0, 0, -1), result.Index, Spinner.SpinTime)
	SpinnerUI.Spun:Fire(result.Index)
	task.delay(Spinner.SpinTime, function()
		spinning = false
		resultLabel.Text = "You won: " .. result.RewardText .. "!"
		Kit.Pop(resultLabel, 1.4)
		Effects.ScreenConfetti(50)
		Sound.Play("Fanfare")
		refresh()
	end)
end

function SpinnerUI.Init(screen: ScreenGui)
	window = Kit.Window(screen, "LUCKY WHEEL", UDim2.fromOffset(900, 600), Kit.Colors.Pink)
	local content = window.Content
	-- kolo
	local viewportHolder = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(420, 420), Position = UDim2.fromOffset(0, 10), Parent = content })
	local viewport = Kit.Viewport(viewportHolder, nil)
	wheel = buildWheel(viewport)
	wheelCenter = Vector3.zero
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, -34), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	attachLabels(viewportHolder, wheel)
	Kit.Text(viewportHolder, { Text = "▼", Size = UDim2.fromOffset(60, 60), Position = UDim2.new(0.5, 0, 0, -18), AnchorPoint = Vector2.new(0.5, 0), TextColor3 = Kit.Colors.Coral, StrokeThickness = 3, ZIndex = 3 })
	resultLabel = Kit.Text(content, { Text = "Spin the wheel!", Size = UDim2.fromOffset(420, 44), Position = UDim2.fromOffset(0, 440), TextColor3 = Kit.Colors.Yellow, StrokeThickness = 3 })

	-- šance (i)
	local oddsPanel = Kit.Panel(content, { Size = UDim2.new(0, 400, 0, 380), Position = UDim2.new(1, 0, 0, 10), AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = Kit.Colors.PanelDark })
	Kit.Text(oddsPanel, { Text = "ⓘ CHANCES", Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 6), TextColor3 = Kit.Colors.Navy, NoStroke = true })
	local list = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -20, 1, -56), Position = UDim2.fromOffset(10, 50), Parent = oddsPanel })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local totalWeight = 0
	for _, segment in Spinner.Segments do
		totalWeight += segment.Weight
	end
	for i, segment in Spinner.Segments do
		local row = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = i, Parent = list })
		local swatch = Kit.new("Frame", { BackgroundColor3 = segment.Color, Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(0, 4), Parent = row })
		Kit.Corner(swatch, 8)
		Kit.Stroke(swatch, 2, Kit.Colors.Outline, true)
		Kit.Text(row, { Text = segment.Label, Size = UDim2.new(1, -120, 1, -6), Position = UDim2.fromOffset(38, 3), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Kit.Colors.Text, NoStroke = true })
		local percent = segment.Weight / totalWeight * 100
		Kit.Text(row, { Text = (if percent == math.floor(percent) then tostring(percent) else string.format("%.1f", percent)) .. "%", Size = UDim2.new(0, 80, 1, -6), Position = UDim2.new(1, -80, 0, 3), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Kit.Colors.Blue, NoStroke = true })
	end
	Kit.Text(content, { Text = "Money rewards grow with your level!", Size = UDim2.fromOffset(400, 26), Position = UDim2.new(1, 0, 0, 396), AnchorPoint = Vector2.new(1, 0), TextColor3 = Kit.Colors.Gray, NoStroke = true })

	spinButton = Kit.Button(content, { Text = "SPIN!", Color = Kit.Colors.Green, Size = UDim2.fromOffset(420, 70), Position = UDim2.new(0, 0, 1, -4), AnchorPoint = Vector2.new(0, 1) }, doSpin)
	if Products.IsConfigured("Spin1") then
		local buy1 = Kit.Button(content, { Text = "+1 Spin  R$" .. priceOf("Spin1"), Color = Kit.Colors.Orange, Size = UDim2.fromOffset(195, 60), Position = UDim2.new(1, -205, 1, -4), AnchorPoint = Vector2.new(1, 1) }, function()
			promptProduct("Spin1")
		end)
		buy1.Visible = false
		Purchase.OnPolicy(function()
			buy1.Visible = Purchase.Allowed("Spin1")
		end)
	end
	if Products.IsConfigured("Spins5") then
		local buy5 = Kit.Button(content, { Text = "+5 Spins  R$" .. priceOf("Spins5"), Color = Kit.Colors.Pink, Size = UDim2.fromOffset(195, 60), Position = UDim2.new(1, 0, 1, -4), AnchorPoint = Vector2.new(1, 1) }, function()
			promptProduct("Spins5")
		end)
		buy5.Visible = false
		Purchase.OnPolicy(function()
			buy5.Visible = Purchase.Allowed("Spins5")
		end)
	end

	ClientState.Changed:Connect(refresh)
	task.spawn(function()
		while true do
			if window.IsOpen() then
				refresh()
			end
			task.wait(1)
		end
	end)
end

function SpinnerUI.Open()
	refresh()
	window.Open()
end

function SpinnerUI.Toggle()
	if window.IsOpen() then
		window.Close()
	else
		SpinnerUI.Open()
	end
end

return SpinnerUI

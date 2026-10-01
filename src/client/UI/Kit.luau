--!strict
-- Stavebnice UI: veselé zaoblené panely a velká tlačítka (min. 60 px na mobilu), písmo Fredoka One.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local spinning: { [Model]: ViewportFrame } = setmetatable({}, { __mode = "k" }) :: any

local Kit = {}

Kit.Font = Enum.Font.FredokaOne

Kit.Colors = {
	Turquoise = Color3.fromRGB(20, 190, 230),
	Blue = Color3.fromRGB(45, 120, 245),
	Navy = Color3.fromRGB(25, 40, 80),
	Yellow = Color3.fromRGB(255, 205, 50),
	Orange = Color3.fromRGB(255, 150, 40),
	Coral = Color3.fromRGB(255, 95, 90),
	Green = Color3.fromRGB(70, 210, 100),
	Purple = Color3.fromRGB(160, 90, 255),
	Pink = Color3.fromRGB(255, 110, 190),
	White = Color3.new(1, 1, 1),
	Panel = Color3.fromRGB(255, 250, 238),
	PanelDark = Color3.fromRGB(240, 228, 205),
	Gray = Color3.fromRGB(160, 165, 175),
	Text = Color3.fromRGB(40, 45, 70),
	Outline = Color3.fromRGB(25, 30, 55),
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

export type Props = { [string]: any }

function Kit.new(className: string, props: Props?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent: Instance? = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Kit.Corner(parent: Instance, radius: number?): UICorner
	return Kit.new("UICorner", { CornerRadius = UDim.new(0, radius or 16), Parent = parent })
end

function Kit.Stroke(parent: Instance, thickness: number?, color: Color3?, border: boolean?): UIStroke
	return Kit.new("UIStroke", {
		Thickness = thickness or 3,
		Color = color or Kit.Colors.Outline,
		ApplyStrokeMode = if border then Enum.ApplyStrokeMode.Border else Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
end

function Kit.Gradient(parent: Instance, top: Color3, bottom: Color3): UIGradient
	return Kit.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = 90,
		Parent = parent,
	})
end

function Kit.Padding(parent: Instance, pixels: number): UIPadding
	return Kit.new("UIPadding", {
		PaddingLeft = UDim.new(0, pixels),
		PaddingRight = UDim.new(0, pixels),
		PaddingTop = UDim.new(0, pixels),
		PaddingBottom = UDim.new(0, pixels),
		Parent = parent,
	})
end

function Kit.Screen(name: string, order: number?): ScreenGui
	local gui = Kit.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		DisplayOrder = order or 0,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	-- automatické zmenšení na malých obrazovkách
	local scale = Kit.new("UIScale", { Parent = gui })
	local function update()
		local camera = Workspace.CurrentCamera
		if camera then
			local size = camera.ViewportSize
			scale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 760), 0.55, 1.25)
		end
	end
	update()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	return gui
end

function Kit.Text(parent: Instance, props: Props): TextLabel
	local label = Kit.new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Kit.Font,
		TextColor3 = Kit.Colors.White,
		TextScaled = true,
		Parent = parent,
	})
	for key, value in props do
		if key ~= "NoStroke" and key ~= "StrokeThickness" and key ~= "StrokeColor" then
			(label :: any)[key] = value
		end
	end
	if props.NoStroke ~= true then
		Kit.Stroke(label, props.StrokeThickness or 2.5, props.StrokeColor)
	end
	return label
end

function Kit.Panel(parent: Instance, props: Props): Frame
	local frame = Kit.new("Frame", {
		BackgroundColor3 = Kit.Colors.Panel,
		BorderSizePixel = 0,
		Parent = parent,
	})
	for key, value in props do
		if key ~= "Radius" and key ~= "StrokeThickness" then
			(frame :: any)[key] = value
		end
	end
	Kit.Corner(frame, props.Radius or 18)
	Kit.Stroke(frame, props.StrokeThickness or 4, Kit.Colors.Outline, true)
	return frame
end

function Kit.Pop(object: GuiObject, amount: number?)
	local scale = object:FindFirstChildOfClass("UIScale")
	if not scale then
		local created = Kit.new("UIScale", { Name = "PopScale", Parent = object })
		scale = created
	end
	assert(scale)
	scale.Scale = amount or 1.15
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

function Kit.Button(parent: Instance, props: Props, onClick: (() -> ())?): TextButton
	local color: Color3 = props.Color or Kit.Colors.Turquoise
	local button = Kit.new("TextButton", {
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Text = "",
		Size = props.Size or UDim2.fromOffset(160, 64),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		Name = props.Name or "Button",
		Parent = parent,
	})
	Kit.Corner(button, props.Radius or 14)
	Kit.Stroke(button, 3.5, Kit.Colors.Outline, true)
	Kit.Gradient(button, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200))
	-- světlý odlesk nahoře
	local shine = Kit.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 6, 0, 4),
		Size = UDim2.new(1, -12, 0.28, 0),
		Name = "Shine",
		Parent = button,
	})
	Kit.Corner(shine, 10)
	local label = Kit.Text(button, {
		Name = "Label",
		Text = props.Text or "",
		Size = UDim2.new(1, -12, 1, -10),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = props.TextColor or Kit.Colors.White,
		ZIndex = 2,
	})
	label.ZIndex = 2
	local scale = Kit.new("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.06 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.08), { Scale = 0.93 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

function Kit.SetButtonText(button: TextButton, text: string)
	local label = button:FindFirstChild("Label") :: TextLabel?
	if label then
		label.Text = text
	end
end

-- ===== Okna (vždy jen jedno otevřené) =====

export type Window = {
	Frame: Frame,
	Content: Frame,
	Title: TextLabel,
	Open: () -> (),
	Close: () -> (),
	IsOpen: () -> boolean,
	OnClose: (() -> ())?,
}

local openWindow: Window? = nil

function Kit.Window(screen: ScreenGui, title: string, size: UDim2, color: Color3?): Window
	local frame = Kit.Panel(screen, {
		Name = title .. "Window",
		Size = size,
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		ZIndex = 10,
	})
	local header = Kit.new("Frame", {
		BackgroundColor3 = color or Kit.Colors.Turquoise,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 64),
		Name = "Header",
		Parent = frame,
	})
	Kit.Corner(header, 18)
	Kit.Gradient(header, Color3.new(1, 1, 1), Color3.fromRGB(210, 210, 210))
	-- spodní rovná hrana hlavičky
	Kit.new("Frame", {
		BackgroundColor3 = color or Kit.Colors.Turquoise,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -18),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = header,
	})
	local titleLabel = Kit.Text(header, {
		Text = title,
		Size = UDim2.new(1, -140, 0, 46),
		Position = UDim2.fromOffset(20, 9),
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
		ZIndex = 2,
	})
	local content = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 76),
		Size = UDim2.new(1, -32, 1, -90),
		Name = "Content",
		Parent = frame,
	})
	local window: Window
	local closeButton = Kit.Button(frame, {
		Text = "X",
		Color = Kit.Colors.Coral,
		Size = UDim2.fromOffset(60, 60),
		Position = UDim2.new(1, 12, 0, -14),
		AnchorPoint = Vector2.new(1, 0),
		Name = "Close",
	})
	closeButton.ZIndex = 5
	local scale = Kit.new("UIScale", { Parent = frame })
	window = {
		Frame = frame,
		Content = content,
		Title = titleLabel,
		OnClose = nil,
		Open = function()
			if openWindow and openWindow ~= window then
				openWindow.Close()
			end
			openWindow = window
			frame.Visible = true
			scale.Scale = 0.8
			TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end,
		Close = function()
			if frame.Visible then
				frame.Visible = false
				if openWindow == window then
					openWindow = nil
				end
				if window.OnClose then
					window.OnClose()
				end
			end
		end,
		IsOpen = function()
			return frame.Visible
		end,
	}
	closeButton.Activated:Connect(function()
		window.Close()
	end)
	return window
end

function Kit.CloseAll()
	if openWindow then
		openWindow.Close()
	end
end

-- Karta s mřížkou (ScrollingFrame + UIGridLayout)
function Kit.Grid(parent: Instance, cellSize: UDim2, padding: number?): ScrollingFrame
	local scroll = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 10,
		ScrollBarImageColor3 = Kit.Colors.Navy,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = parent,
	})
	Kit.new("UIGridLayout", {
		CellSize = cellSize,
		CellPadding = UDim2.fromOffset(padding or 12, padding or 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = scroll,
	})
	Kit.Padding(scroll, 8)
	return scroll
end

-- 3D náhled modelu v UI
function Kit.Viewport(parent: Instance, model: Model?, props: Props?): ViewportFrame
	local viewport = Kit.new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(200, 200, 200),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
		Parent = parent,
	})
	if props then
		for key, value in props do
			(viewport :: any)[key] = value
		end
	end
	if model then
		model:PivotTo(CFrame.identity)
		model.Parent = viewport
		local camera = Instance.new("Camera")
		camera.FieldOfView = 40
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		local _, size = model:GetBoundingBox()
		local radius = size.Magnitude / 2
		local distance = radius / math.tan(math.rad(20)) * 1.05
		camera.CFrame = CFrame.lookAt(Vector3.new(distance * 0.55, distance * 0.45, -distance * 0.7), Vector3.zero)
		spinning[model] = viewport
	end
	return viewport
end

-- modely v náhledech (obchod, karty) se pomalu otáčejí
RunService.RenderStepped:Connect(function(dt: number)
	for model, viewport in spinning do
		if not model.Parent then
			spinning[model] = nil
		elseif viewport.Visible and viewport:FindFirstAncestorWhichIsA("LayerCollector") then
			model:PivotTo(model:GetPivot() * CFrame.Angles(0, dt * 0.8, 0))
		end
	end
end)

return Kit

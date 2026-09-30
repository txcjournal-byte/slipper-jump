--!strict
-- Efekty: konfety (na obrazovce i ve světě), šplouchnutí, velké nápisy (PERFECT!), zatmění obrazovky.

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Kit = require(script.Parent.Parent.UI.Kit)

local Effects = {}

local screen: ScreenGui
local fadeFrame: Frame
local rng = Random.new()

local CONFETTI_COLORS = {
	Color3.fromRGB(255, 80, 90),
	Color3.fromRGB(255, 205, 50),
	Color3.fromRGB(70, 210, 100),
	Color3.fromRGB(40, 170, 255),
	Color3.fromRGB(190, 90, 255),
	Color3.fromRGB(255, 130, 200),
}

function Effects.Init()
	screen = Kit.Screen("Effects", 50)
	screen.IgnoreGuiInset = true
	fadeFrame = Kit.new("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 100,
		Parent = screen,
	})
end

-- Konfety padající přes obrazovku
function Effects.ScreenConfetti(count: number?)
	for _ = 1, count or 70 do
		local size = rng:NextInteger(10, 20)
		local piece = Kit.new("Frame", {
			BackgroundColor3 = CONFETTI_COLORS[rng:NextInteger(1, #CONFETTI_COLORS)],
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(size, size * 0.6),
			Position = UDim2.new(rng:NextNumber(0.05, 0.95), 0, -0.05, 0),
			Rotation = rng:NextNumber(0, 360),
			ZIndex = 50,
			Parent = screen,
		})
		local duration = rng:NextNumber(1.6, 3)
		TweenService:Create(piece, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(piece.Position.X.Scale + rng:NextNumber(-0.15, 0.15), 0, 1.1, 0),
			Rotation = piece.Rotation + rng:NextNumber(-540, 540),
		}):Play()
		Debris:AddItem(piece, duration)
	end
end

-- Konfety ve 3D světě
function Effects.WorldConfetti(position: Vector3, count: number?, spread: number?)
	local folder = Instance.new("Folder")
	folder.Name = "Confetti"
	folder.Parent = Workspace
	for _ = 1, count or 40 do
		local p = Instance.new("Part")
		p.Size = Vector3.new(0.5, 0.08, 0.35) * (spread or 1)
		p.Color = CONFETTI_COLORS[rng:NextInteger(1, #CONFETTI_COLORS)]
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Anchored = true
		p.CastShadow = false
		p.CFrame = CFrame.new(position)
		p.Parent = folder
		local target = position + Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(4, 16), rng:NextNumber(-12, 12)) * (spread or 1)
		local tween = TweenService:Create(p, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(target) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
		})
		tween:Play()
		tween.Completed:Connect(function()
			TweenService:Create(p, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
				CFrame = CFrame.new(target - Vector3.new(0, 12, 0) * (spread or 1)) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
				Transparency = 1,
			}):Play()
		end)
	end
	Debris:AddItem(folder, 2.6)
end

-- Šplouchnutí na hladině
function Effects.Splash(position: Vector3, big: boolean?)
	local scale = if big then 2 else 1
	local folder = Instance.new("Folder")
	folder.Name = "Splash"
	folder.Parent = Workspace
	for ringIndex = 1, 2 do
		local ring = Instance.new("Part")
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.3, 4, 4)
		ring.CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Color = Color3.new(1, 1, 1)
		ring.Material = Enum.Material.SmoothPlastic
		ring.Transparency = 0.2
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.Parent = folder
		TweenService:Create(ring, TweenInfo.new(0.9 + ringIndex * 0.3, Enum.EasingStyle.Quad), {
			Size = Vector3.new(0.3, 30 * scale * ringIndex, 30 * scale * ringIndex),
			Transparency = 1,
		}):Play()
	end
	for _ = 1, 26 do
		local drop = Instance.new("Part")
		drop.Shape = Enum.PartType.Ball
		drop.Size = Vector3.one * rng:NextNumber(0.8, 1.8) * scale
		drop.CFrame = CFrame.new(position)
		drop.Color = Color3.fromRGB(200, 240, 255)
		drop.Material = Enum.Material.SmoothPlastic
		drop.Anchored = true
		drop.CanCollide = false
		drop.CanQuery = false
		drop.CanTouch = false
		drop.Parent = folder
		local up = position + Vector3.new(rng:NextNumber(-6, 6), rng:NextNumber(8, 18), rng:NextNumber(-6, 6)) * scale
		local tween = TweenService:Create(drop, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(up) })
		tween:Play()
		tween.Completed:Connect(function()
			TweenService:Create(drop, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = CFrame.new(up.X, position.Y - 1, up.Z),
				Transparency = 0.8,
			}):Play()
		end)
	end
	Debris:AddItem(folder, 2)
end

-- Velký nápis uprostřed obrazovky ("PERFECT!", "GOOD!", vzdálenost...)
function Effects.BigText(text: string, color: Color3, duration: number?, yScale: number?)
	local label = Kit.Text(screen, {
		Text = text,
		TextColor3 = color,
		Size = UDim2.fromOffset(700, 110),
		Position = UDim2.fromScale(0.5, yScale or 0.3),
		AnchorPoint = Vector2.new(0.5, 0.5),
		StrokeThickness = 5,
		ZIndex = 40,
		Rotation = -4,
	})
	Kit.Pop(label, 1.8)
	task.delay(duration or 1.2, function()
		local tween = TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1, Position = UDim2.fromScale(0.5, (yScale or 0.3) - 0.05) })
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		end
		tween:Play()
		Debris:AddItem(label, 0.35)
	end)
end

-- Malý stoupající text ("+$123")
function Effects.FloatText(text: string, color: Color3)
	local label = Kit.Text(screen, {
		Text = text,
		TextColor3 = color,
		Size = UDim2.fromOffset(300, 54),
		Position = UDim2.fromScale(0.5, 0.62),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 40,
	})
	Kit.Pop(label, 1.4)
	TweenService:Create(label, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(0.5, 0.5), TextTransparency = 1 }):Play()
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(1.2), { Transparency = 1 }):Play()
	end
	Debris:AddItem(label, 1.3)
end

function Effects.Fade(toBlack: boolean, duration: number)
	TweenService:Create(fadeFrame, TweenInfo.new(duration), { BackgroundTransparency = if toBlack then 0 else 1 }):Play()
end

return Effects

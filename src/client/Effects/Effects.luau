--!strict
-- Efekty: konfety (na obrazovce i ve světě), šplouchnutí, velké nápisy (PERFECT!), zatmění obrazovky,
-- „šťáva“ kamery (otřes, FOV rána), rychlostní čáry a vítr během letu, vlny po dopadu.

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Kit = require(script.Parent.Parent.UI.Kit)

local Effects = {}

local screen: ScreenGui
local fadeFrame: Frame
local rng = Random.new()

-- na mobilech méně kousků (výkon)
local LOW_END = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
Effects.LowEnd = LOW_END

-- ===== Kamera: otřes a FOV rána =====
local trauma = 0 -- 0..1, otřes = trauma²
local fovKick = 0
local shakeOffset = CFrame.identity
local MAX_SHAKE_ANGLE = math.rad(2.2)
local MAX_SHAKE_MOVE = 0.7

-- ===== Rychlost: čáry na obrazovce a vítr ve 3D =====
type SpeedLine = { Frame: Frame, Angle: number, Radius: number, Speed: number, Length: number }
type WindStreak = { Part: Part, X: number, Y: number, Z: number, Speed: number }

local speedTarget = 0
local speedCurrent = 0
local speedHolder: Frame
local speedLines: { SpeedLine } = {}
local windFolder: Folder
local windStreaks: { WindStreak } = {}
local SPEED_LINE_COUNT = if LOW_END then 12 else 20
local WIND_STREAK_COUNT = if LOW_END then 8 else 14

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
	speedHolder = Kit.new("Frame", {
		Name = "SpeedLines",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 5,
		Parent = screen,
	})
	for _ = 1, SPEED_LINE_COUNT do
		local frame = Kit.new("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 5,
			Parent = speedHolder,
		})
		table.insert(speedLines, { Frame = frame, Angle = rng:NextNumber(0, math.pi * 2), Radius = rng:NextNumber(0.4, 1), Speed = rng:NextNumber(1.2, 2.2), Length = rng:NextNumber(70, 190) })
	end
	windFolder = Instance.new("Folder")
	windFolder.Name = "WindStreaks"
	for _ = 1, WIND_STREAK_COUNT do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Color3.fromRGB(235, 248, 255)
		p.Size = Vector3.new(0.07, 0.07, rng:NextNumber(5, 10))
		p.Transparency = 1
		p.Parent = windFolder
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(5, 14)
		table.insert(windStreaks, { Part = p, X = math.cos(a) * r, Y = math.sin(a) * r, Z = rng:NextNumber(-90, 0), Speed = rng:NextNumber(110, 170) })
	end
	RunService.RenderStepped:Connect(Effects.Update)
end

-- Otřes kamery (0..1, sčítá se)
function Effects.Shake(amount: number)
	trauma = math.min(1, trauma + amount)
end

-- Krátké „roztažení“ zorného pole (stupně, sčítá se)
function Effects.FovKick(amount: number)
	fovKick = math.min(fovKick + amount, 22)
end

-- Aktuální posun kamery z otřesu (volající ho přinásobí ke svému CFrame kamery)
function Effects.CameraOffset(): CFrame
	return shakeOffset
end

function Effects.FovOffset(): number
	return fovKick
end

-- Intenzita rychlostních čar a větru 0..1 (plynule se dorovná)
function Effects.SetSpeed(intensity: number)
	speedTarget = math.clamp(intensity, 0, 1)
end

local function updateSpeed(dt: number)
	speedCurrent += (speedTarget - speedCurrent) * (1 - math.exp(-dt * 4))
	local active = speedCurrent > 0.02
	speedHolder.Visible = active and speedCurrent > 0.25
	local camera = Workspace.CurrentCamera
	if not active or not camera then
		if windFolder.Parent then
			windFolder.Parent = nil
		end
		return
	end
	-- čáry na obrazovce letí od středu ven (jen při velké rychlosti)
	if speedHolder.Visible then
		local size = speedHolder.AbsoluteSize
		local aspect = if size.Y > 0 then size.X / size.Y else 1
		local lineAlpha = math.clamp((speedCurrent - 0.25) / 0.75, 0, 1)
		for _, line in speedLines do
			line.Radius += line.Speed * dt * (0.6 + speedCurrent)
			if line.Radius > 1.15 then
				line.Radius = rng:NextNumber(0.4, 0.55)
				line.Angle = rng:NextNumber(0, math.pi * 2)
			end
			local dx, dy = math.cos(line.Angle), math.sin(line.Angle)
			line.Frame.Position = UDim2.fromScale(0.5 + dx * line.Radius * 0.5, 0.5 + dy * line.Radius * 0.5)
			line.Frame.Size = UDim2.fromOffset(line.Length * (0.5 + lineAlpha * 0.7), 3)
			line.Frame.Rotation = math.deg(math.atan2(dy, dx * aspect))
			line.Frame.BackgroundTransparency = 1 - 0.5 * lineAlpha * math.clamp((line.Radius - 0.4) * 3, 0, 1)
		end
	end
	-- 3D vítr: tenké proužky letí kolem kamery
	if windFolder.Parent ~= camera then
		windFolder.Parent = camera
	end
	local camCf = camera.CFrame
	for _, streak in windStreaks do
		streak.Z += streak.Speed * dt * (0.5 + speedCurrent)
		if streak.Z > 6 then
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(5, 14)
			streak.X = math.cos(a) * r
			streak.Y = math.sin(a) * r
			streak.Z = rng:NextNumber(-90, -60)
		end
		streak.Part.CFrame = camCf * CFrame.new(streak.X, streak.Y, streak.Z)
		streak.Part.Transparency = 1 - 0.6 * speedCurrent
	end
end

function Effects.Update(dt: number)
	-- otřes: plynulý šum, slábne s časem
	if trauma > 0 then
		trauma = math.max(0, trauma - dt * 1.4)
		local power = trauma * trauma
		local t = os.clock() * 22
		shakeOffset = CFrame.new(math.noise(t, 1.3) * MAX_SHAKE_MOVE * power, math.noise(t, 7.1) * MAX_SHAKE_MOVE * power, 0)
			* CFrame.Angles(math.noise(t, 3.7) * MAX_SHAKE_ANGLE * power, math.noise(t, 5.9) * MAX_SHAKE_ANGLE * power, math.noise(t, 9.2) * MAX_SHAKE_ANGLE * power)
	else
		shakeOffset = CFrame.identity
	end
	fovKick *= math.exp(-dt * 5)
	if fovKick < 0.05 then
		fovKick = 0
	end
	updateSpeed(dt)
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

local function fxPart(parent: Instance, shape: Enum.PartType, size: Vector3, cf: CFrame, color: Color3, transparency: number): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Transparency = transparency
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local FLAT = CFrame.Angles(0, 0, math.rad(90)) -- válec položený na hladinu
local FOAM = Color3.fromRGB(235, 250, 255)

-- Velké šplouchnutí po dopadu: sloup vody, pěna a několik vln, které se rozbíhají po hladině
function Effects.LandingSplash(position: Vector3, power: number)
	local scale = 1 + math.clamp(power, 0, 1) * 1.2
	Effects.Splash(position, power > 0.5)
	local folder = Instance.new("Folder")
	folder.Name = "LandingSplash"
	folder.Parent = Workspace
	local surface = Vector3.new(position.X, position.Y + 0.25, position.Z)
	-- sloup vody (válec postavený svisle: osa X = výška)
	local column = fxPart(folder, Enum.PartType.Cylinder, Vector3.new(2, 5 * scale, 5 * scale), CFrame.new(surface) * FLAT, FOAM, 0.15)
	local columnHeight = 16 * scale
	local rise = TweenService:Create(column, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(columnHeight, 3 * scale, 3 * scale),
		CFrame = CFrame.new(surface + Vector3.new(0, columnHeight / 2, 0)) * FLAT,
	})
	rise:Play()
	rise.Completed:Connect(function()
		TweenService:Create(column, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = Vector3.new(1, 7 * scale, 7 * scale),
			CFrame = CFrame.new(surface) * FLAT,
			Transparency = 1,
		}):Play()
	end)
	-- pěna
	local foam = fxPart(folder, Enum.PartType.Cylinder, Vector3.new(0.2, 6 * scale, 6 * scale), CFrame.new(surface) * FLAT, FOAM, 0.1)
	TweenService:Create(foam, TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.2, 26 * scale, 26 * scale), Transparency = 1 }):Play()
	-- vlny (kruhy), postupně jedna za druhou
	for i = 1, if LOW_END then 2 else 3 do
		task.delay((i - 1) * 0.28, function()
			if not folder.Parent then
				return
			end
			local ring = fxPart(folder, Enum.PartType.Cylinder, Vector3.new(0.25, 6, 6), CFrame.new(surface + Vector3.new(0, 0.05 * i, 0)) * FLAT, Color3.new(1, 1, 1), 0.2)
			local inner = fxPart(folder, Enum.PartType.Cylinder, Vector3.new(0.3, 4.8, 4.8), CFrame.new(surface + Vector3.new(0, 0.05 * i + 0.02, 0)) * FLAT, Color3.fromRGB(60, 190, 225), 0.35)
			local final = (34 + i * 26) * scale
			local info = TweenInfo.new(1.5 + i * 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(ring, info, { Size = Vector3.new(0.25, final, final), Transparency = 1 }):Play()
			TweenService:Create(inner, info, { Size = Vector3.new(0.3, final - 2.5, final - 2.5), Transparency = 1 }):Play()
		end)
	end
	Debris:AddItem(folder, 3.5)
end

-- Malé čeření na hladině (ryba, delfín…)
function Effects.Ripple(position: Vector3, size: number?)
	local s = size or 1
	local folder = Instance.new("Folder")
	folder.Name = "Ripple"
	folder.Parent = Workspace
	local surface = Vector3.new(position.X, position.Y + 0.2, position.Z)
	local ring = fxPart(folder, Enum.PartType.Cylinder, Vector3.new(0.2, 2 * s, 2 * s), CFrame.new(surface) * FLAT, Color3.new(1, 1, 1), 0.25)
	TweenService:Create(ring, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.2, 12 * s, 12 * s), Transparency = 1 }):Play()
	for _ = 1, if LOW_END then 3 else 6 do
		local drop = fxPart(folder, Enum.PartType.Ball, Vector3.one * rng:NextNumber(0.4, 0.8) * s, CFrame.new(surface), FOAM, 0.1)
		local up = surface + Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(2.5, 5), rng:NextNumber(-2, 2)) * s
		local tween = TweenService:Create(drop, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(up) })
		tween:Play()
		tween.Completed:Connect(function()
			TweenService:Create(drop, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(up.X, surface.Y - 0.5, up.Z), Transparency = 1 }):Play()
		end)
	end
	Debris:AddItem(folder, 1.3)
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

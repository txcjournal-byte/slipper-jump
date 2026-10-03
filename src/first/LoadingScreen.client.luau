--!strict
-- Načítací obrazovka pro hráče, kteří se právě připojují (běží z ReplicatedFirst jako úplně první).
-- Místo výchozího Roblox načítání ukáže pláž s mořem, sluníčkem a vlnkami, velký nápis hry,
-- otáčející se duhový pantofel s obřím dárkem, ukazatel načítání a tipy.
-- Zmizí, až je hra načtená a klient má data hráče (atribut "SlipperJumpReady" na hráči),
-- nejpozději po MAX_WAIT sekundách.
--
-- Vlastní obrázek: nahraj ho do Creator Hubu (Decals/Images) a jeho ID vlož do LOADING_IMAGE,
-- např. "rbxassetid://1234567890". Obrázek se pak ukáže uprostřed místo 3D pantoflíčku.

local LOADING_IMAGE = ""

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MIN_TIME = 2.5 -- obrazovka zůstane aspoň takhle dlouho (ať není jen bliknutí)
local MAX_WAIT = 30
local FONT = Enum.Font.FredokaOne

local TIPS = {
	"Let go of JUMP in the green zone for a PERFECT jump!",
	"Fly through rings to jump even farther!",
	"Swim back to the raft to keep the item you found!",
	"Better slippers = longer jumps. Visit the SHOP!",
	"Items in your house earn money every second.",
	"Reach the Giant Gift 100,000 studs away!",
	"From level 2, slaloms wait for you on the way back!",
	"Safe on the raft? Swim on to the next raft for a treasure!",
	"Spin the wheel every day for free rewards!",
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

ReplicatedFirst:RemoveDefaultLoadingScreen()
-- pojistka: kdyby se cokoli pokazilo, obrazovka nesmí zůstat viset přes hru
task.delay(MAX_WAIT + 5, function()
	if gui.Parent then
		gui:Destroy()
	end
end)

local function new(className: string, props: { [string]: any }, parent: Instance): any
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	inst.Parent = parent
	return inst
end

local function corner(parent: Instance, radius: number?)
	new("UICorner", { CornerRadius = if radius then UDim.new(0, radius) else UDim.new(1, 0) }, parent)
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = FONT,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
	}, parent)
	for key, value in props do
		if key ~= "StrokeThickness" then
			(label :: any)[key] = value
		end
	end
	local stroke = new("UIStroke", { Color = Color3.fromRGB(25, 40, 80), Thickness = props.StrokeThickness or 3 }, label)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	return label
end

-- ===== Obrázek: nebe, slunce, moře, vlny, pláž =====
local root = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(110, 205, 255), BorderSizePixel = 0 }, gui)
new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 170, 255)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(160, 225, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 235, 200)),
	}),
}, root)

-- slunce se září
local sun = new("Frame", { Size = UDim2.fromScale(0.16, 0.16), Position = UDim2.fromScale(0.86, 0.13), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(255, 225, 90), BorderSizePixel = 0 }, root)
new("UIAspectRatioConstraint", { AspectRatio = 1 }, sun)
corner(sun)
local sunGlow = new("Frame", { Size = UDim2.fromScale(1.7, 1.7), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(255, 240, 160), BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = 0 }, sun)
corner(sunGlow)

-- mraky
local clouds = {}
for i, spec in { { 0.12, 0.12, 0.2 }, { 0.42, 0.07, 0.14 }, { 0.66, 0.24, 0.17 } } do
	local cloud = new("Frame", { Size = UDim2.fromScale(spec[3], spec[3] * 0.32), Position = UDim2.fromScale(spec[1], spec[2]), BackgroundTransparency = 1 }, root)
	for _, puff in { { 0, 0.35, 0.5 }, { 0.25, 0, 0.55 }, { 0.5, 0.25, 0.5 } } do
		local p = new("Frame", { Size = UDim2.fromScale(puff[3], 1.2), Position = UDim2.fromScale(puff[1], puff[2] - 0.2), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, cloud)
		corner(p)
	end
	clouds[i] = cloud
end

-- moře a vlny
local sea = new("Frame", { Size = UDim2.fromScale(1, 0.42), Position = UDim2.fromScale(0, 0.58), BackgroundColor3 = Color3.fromRGB(40, 190, 225), BorderSizePixel = 0 }, root)
new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new(Color3.fromRGB(70, 220, 235), Color3.fromRGB(20, 120, 200)),
}, sea)
local waves = {}
for row = 0, 2 do
	local strip = new("Frame", { Size = UDim2.fromScale(1.2, 0.08), Position = UDim2.fromScale(-0.1, row * 0.25 + 0.02), BackgroundTransparency = 1 }, sea)
	for k = 0, 11 do
		local crest = new("Frame", { Size = UDim2.fromScale(0.06, 0.5), Position = UDim2.fromScale(k / 12 + (row % 2) * 0.04, 0.2), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.35 + row * 0.15, BorderSizePixel = 0 }, strip)
		corner(crest)
	end
	waves[row + 1] = strip
end
-- pláž dole
local beach = new("Frame", { Size = UDim2.fromScale(1.2, 0.16), Position = UDim2.fromScale(-0.1, 0.9), BackgroundColor3 = Color3.fromRGB(250, 222, 160), BorderSizePixel = 0 }, root)
corner(beach, 400)

-- ===== Nápis hry =====
local title = text(root, {
	Text = "SLIPPER JUMP!",
	Size = UDim2.fromScale(0.8, 0.16),
	Position = UDim2.fromScale(0.5, 0.16),
	AnchorPoint = Vector2.new(0.5, 0.5),
	TextColor3 = Color3.fromRGB(255, 215, 60),
	StrokeThickness = 6,
	ZIndex = 5,
})
new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new(Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 150, 40)),
}, title)
new("UITextSizeConstraint", { MaxTextSize = 110 }, title)
local subtitle = text(root, {
	Text = "Jump from the pier. Find treasure. Reach the Giant Gift!",
	Size = UDim2.fromScale(0.7, 0.05),
	Position = UDim2.fromScale(0.5, 0.27),
	AnchorPoint = Vector2.new(0.5, 0.5),
	StrokeThickness = 2.5,
	ZIndex = 5,
})
new("UITextSizeConstraint", { MaxTextSize = 30 }, subtitle)

-- ===== Obrázek uprostřed: vlastní obrázek, nebo 3D pantofel a dárek =====
local picture = new("Frame", { Size = UDim2.fromScale(0.42, 0.4), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 4 }, root)
new("UIAspectRatioConstraint", { AspectRatio = 1.4 }, picture)
local spinModel: Model? = nil
local spinCamera: Camera? = nil
if LOADING_IMAGE ~= "" then
	local image = new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = LOADING_IMAGE, ScaleType = Enum.ScaleType.Fit, ZIndex = 4 }, picture)
	corner(image, 24)
else
	-- 3D náhled (pantofel ze sdílených modelů, jakmile se načtou)
	local viewport = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromRGB(200, 200, 210), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-1, -2, -1), ZIndex = 4 }, picture)
	task.spawn(function()
		local ok, result = pcall(function(): Model?
			local shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared", 20)
			if not shared then
				return nil
			end
			local Models = require(shared:WaitForChild("Models", 10) :: ModuleScript) :: any
			local holder = Instance.new("Model")
			-- jen duhový pantofel (velký, šikmo, aby byl vidět svrchu)
			local slipper = Models.Slipper("RainbowSlippers")
			slipper:PivotTo(CFrame.Angles(math.rad(-30), 0, math.rad(12)))
			slipper.Parent = holder
			return holder
		end)
		if ok and result then
			local holder = result :: Model
			for _, d in holder:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
				end
			end
			holder.Parent = viewport
			local camera = Instance.new("Camera")
			local cf, size = holder:GetBoundingBox()
			local distance = size.Magnitude * 0.85
			camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(distance * 0.2, distance * 0.35, distance), cf.Position)
			camera.FieldOfView = 40
			camera.Parent = viewport
			viewport.CurrentCamera = camera
			spinModel = holder
			spinCamera = camera
		end
	end)
end

-- ===== Ukazatel načítání a tipy =====
local barBack = new("Frame", { Size = UDim2.fromScale(0.5, 0.035), Position = UDim2.fromScale(0.5, 0.79), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(25, 40, 80), BorderSizePixel = 0, ZIndex = 5 }, root)
corner(barBack)
new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 3 }, barBack)
local barFill = new("Frame", { Size = UDim2.fromScale(0.04, 1), BackgroundColor3 = Color3.fromRGB(80, 220, 120), BorderSizePixel = 0, ZIndex = 6 }, barBack)
corner(barFill)
new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(120, 240, 140), Color3.fromRGB(40, 190, 230)) }, barFill)
local status = text(root, { Text = "Loading the beach...", Size = UDim2.fromScale(0.5, 0.04), Position = UDim2.fromScale(0.5, 0.735), AnchorPoint = Vector2.new(0.5, 0.5), StrokeThickness = 2.5, ZIndex = 5 })
new("UITextSizeConstraint", { MaxTextSize = 28 }, status)
local tip = text(root, { Text = "TIP: " .. TIPS[math.random(1, #TIPS)], Size = UDim2.fromScale(0.8, 0.045), Position = UDim2.fromScale(0.5, 0.86), AnchorPoint = Vector2.new(0.5, 0.5), StrokeThickness = 2.5, ZIndex = 5 })
new("UITextSizeConstraint", { MaxTextSize = 26 }, tip)

-- ===== Animace =====
local startClock = os.clock()
local animation = RunService.RenderStepped:Connect(function(dt: number)
	local t = os.clock() - startClock
	for i, strip in waves do
		strip.Position = UDim2.fromScale(-0.1 + math.sin(t * (0.8 + i * 0.25) + i) * 0.05, (i - 1) * 0.25 + 0.02)
	end
	for i, cloud in clouds do
		local x = ((t * 0.012 * (1 + i * 0.3) + i * 0.33) % 1.3) - 0.2
		cloud.Position = UDim2.fromScale(x, cloud.Position.Y.Scale)
	end
	sunGlow.Size = UDim2.fromScale(1.6 + math.sin(t * 2) * 0.12, 1.6 + math.sin(t * 2) * 0.12)
	title.Rotation = math.sin(t * 1.6) * 2.5
	title.Size = UDim2.fromScale(0.8 + math.sin(t * 3.2) * 0.012, 0.16)
	local model, camera = spinModel, spinCamera
	if model and camera then
		local cf = model:GetBoundingBox()
		model:PivotTo(CFrame.new(cf.Position) * CFrame.Angles(0, dt * 1.1, 0) * CFrame.new(-cf.Position) * model:GetPivot())
	end
end)

local tipThread = task.spawn(function()
	while true do
		task.wait(4)
		tip.Text = "TIP: " .. TIPS[math.random(1, #TIPS)]
	end
end)

local function setProgress(target: number, label: string)
	status.Text = label
	TweenService:Create(barFill, TweenInfo.new(0.4), { Size = UDim2.fromScale(math.max(0.04, target), 1) }):Play()
end

-- ===== Čekání na načtení =====
local function waitFor(condition: () -> boolean, timeout: number)
	local deadline = os.clock() + timeout
	while not condition() and os.clock() < deadline do
		task.wait(0.1)
	end
end

local deadline = startClock + MAX_WAIT
setProgress(0.15, "Loading the beach...")
if not game:IsLoaded() then
	game.Loaded:Wait()
end
setProgress(0.45, "Filling the ocean...")
waitFor(function()
	return ContentProvider.RequestQueueSize == 0
end, math.max(1, deadline - os.clock()) * 0.5)
setProgress(0.7, "Polishing your slippers...")
waitFor(function()
	return player:GetAttribute("SlipperJumpReady") == true
end, math.max(1, deadline - os.clock()))
setProgress(1, "Let's jump!")
local remaining = MIN_TIME - (os.clock() - startClock)
task.wait(math.max(0.9, remaining))

-- ===== Odchod: vše se rozplyne =====
task.cancel(tipThread)
local fade = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
for _, d in root:GetDescendants() do
	if d:IsA("Frame") then
		TweenService:Create(d, fade, { BackgroundTransparency = 1 }):Play()
	elseif d:IsA("TextLabel") then
		TweenService:Create(d, fade, { TextTransparency = 1 }):Play()
	elseif d:IsA("UIStroke") then
		TweenService:Create(d, fade, { Transparency = 1 }):Play()
	elseif d:IsA("ImageLabel") then
		TweenService:Create(d, fade, { ImageTransparency = 1 }):Play()
	elseif d:IsA("ViewportFrame") then
		TweenService:Create(d, fade, { ImageTransparency = 1 }):Play()
	end
end
TweenService:Create(root, fade, { BackgroundTransparency = 1 }):Play()
task.wait(0.65)
animation:Disconnect()
gui:Destroy()

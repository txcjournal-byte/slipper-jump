--!strict
-- Skok na straně klienta: tlačítko JUMP na konci mola, ukazatel síly nad hlavou,
-- let po parabole (hráč uhýbá A/D nebo joystickem), mince a kruhy, kamera s efektem rychlosti,
-- šplouchnutí, karta s předmětem a návrat na pláž.
-- O všem důležitém rozhoduje server – klient jen ukazuje a hlásí, co posbíral.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Jump = require(Shared.Config.Jump)
local Swim = require(Shared.Config.Swim)
local World = require(Shared.Config.World)
local Formulas = require(Shared.Formulas)
local Catalog = require(Shared.Catalog)
local Models = require(Shared.Models)
local FormatNumber = require(Shared.Util.FormatNumber)
local Net = require(Shared.Net)
local Kit = require(script.Parent.Parent.UI.Kit)
local HUD = require(script.Parent.Parent.UI.HUD)
local ClientState = require(script.Parent.Parent.ClientState)
local Sound = require(script.Parent.Parent.Sound)
local Effects = require(script.Parent.Parent.Effects.Effects)

local JumpController = {}

local updateSwim: (any, BasePart, number) -> ()

local player = Players.LocalPlayer

type Collectible = { Id: string, Position: Vector3, Part: Model?, Taken: boolean }

type FlightState = {
	Id: number,
	Info: { [string]: any },
	StartClock: number,
	Phase: "Main" | "Glide" | "Landed" | "Swim" | "Returned",
	Z: number,
	Coins: { Collectible },
	Rings: { Collectible },
	CollectedCoins: { string },
	CollectedRings: { string },
	FinalDistance: number,
	GlideStart: number,
	GlideDuration: number,
	LastX: number,
	LandPosition: Vector3?,
	Folder: Folder,
	-- plavání zpět
	SwimInfo: { [string]: any }?,
	SwimStart: number,
	SwimProgress: number,
	SwimEnded: boolean,
	Shark: Model?,
	ExpectedPosition: Vector3?,
}

local screen: ScreenGui
local jumpButton: TextButton
local meterGui: BillboardGui?
local meterFill: Frame?
local meterMarker: Frame?
local flightHud: Frame
local distanceLabel: TextLabel
local coinsLabel: TextLabel
local ringsLabel: TextLabel
local steerHint: TextLabel

local inZone = false
local charging = false
local chargeStart = 0
local chargePeriod = Jump.Meter.Period
local flight: FlightState? = nil
local awaitingFlight = false

-- ===== Ukazatel síly nad hlavou =====

local function destroyMeter()
	if meterGui then
		meterGui:Destroy()
		meterGui = nil
		meterFill = nil
		meterMarker = nil
	end
end

local function createMeter()
	destroyMeter()
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = Kit.new("BillboardGui", {
		Name = "PowerMeter",
		Size = UDim2.fromOffset(70, 210),
		StudsOffset = Vector3.new(2.8, 2, 0),
		AlwaysOnTop = true,
		Parent = head,
	})
	local bar = Kit.new("Frame", { BackgroundColor3 = Color3.fromRGB(40, 45, 70), Size = UDim2.new(0, 34, 1, -8), Position = UDim2.fromOffset(18, 4), Parent = gui })
	Kit.Corner(bar, 12)
	Kit.Stroke(bar, 3, Color3.new(1, 1, 1), true)
	local goodHeight = Jump.Meter.PerfectMin - Jump.Meter.GoodMin
	local good = Kit.new("Frame", { BackgroundColor3 = Kit.Colors.Yellow, Size = UDim2.fromScale(1, goodHeight), Position = UDim2.fromScale(0, 1 - Jump.Meter.PerfectMin), BorderSizePixel = 0, Parent = bar })
	good.ZIndex = 2
	local perfect = Kit.new("Frame", { BackgroundColor3 = Kit.Colors.Green, Size = UDim2.fromScale(1, 1 - Jump.Meter.PerfectMin), Position = UDim2.fromScale(0, 0), BorderSizePixel = 0, Parent = bar })
	perfect.ZIndex = 2
	Kit.Corner(perfect, 12)
	local fill = Kit.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, Size = UDim2.fromScale(1, 0), Position = UDim2.fromScale(0, 1), AnchorPoint = Vector2.new(0, 1), BorderSizePixel = 0, Parent = bar })
	fill.ZIndex = 3
	Kit.Corner(fill, 12)
	local marker = Kit.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 22, 0, 8), Position = UDim2.new(0, -11, 1, 0), AnchorPoint = Vector2.new(0, 0.5), BorderSizePixel = 0, Parent = bar })
	marker.ZIndex = 4
	Kit.Corner(marker, 4)
	Kit.Stroke(marker, 2, Kit.Colors.Outline, true)
	meterGui = gui
	meterFill = fill
	meterMarker = marker
end

-- ===== Tlačítko JUMP =====

local function startCharge()
	if charging or flight or awaitingFlight or not inZone then
		return
	end
	local data = ClientState.Get()
	if data.Carried then
		HUD.Notify("Your hands are full! Put the item in your house, sell it or gift it first.", "Warning")
		return
	end
	charging = true
	chargeStart = os.clock()
	chargePeriod = if data.TutorialDone ~= true and (data.BestJump or 0) == 0 then Jump.Meter.TutorialPeriod else Jump.Meter.Period
	createMeter()
	Net.Event("JumpCharge"):FireServer()
end

local function releaseCharge()
	if not charging then
		return
	end
	charging = false
	local value = Formulas.MeterValue(os.clock() - chargeStart, chargePeriod)
	destroyMeter()
	awaitingFlight = true
	Net.Event("JumpRelease"):FireServer(value)
	task.delay(2, function()
		awaitingFlight = false
	end)
end

local function jumpAction(_: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if not inZone or flight then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		startCharge()
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		releaseCharge()
	end
	return Enum.ContextActionResult.Sink
end

local function setInZone(value: boolean)
	if inZone == value then
		return
	end
	inZone = value
	jumpButton.Visible = value
	if value then
		Kit.Pop(jumpButton, 1.3)
		ContextActionService:BindActionAtPriority("SlipperJump", jumpAction, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	else
		ContextActionService:UnbindAction("SlipperJump")
		if charging then
			charging = false
			destroyMeter()
		end
	end
end

local function zoneCheck(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local pos = root.Position
	return pos.X >= World.PierEndX - Jump.JumpZoneLength and pos.X <= World.PierEndX + 2 and math.abs(pos.Z) <= World.PierWidth / 2 + 1 and pos.Y > World.PierDeckY - 1 and pos.Y < World.PierDeckY + 10
end

-- ===== Mince a kruhy =====

local function coinModel(position: Vector3, parent: Instance): Model
	local m = Instance.new("Model")
	local coin = Instance.new("Part")
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.5, 3.6, 3.6)
	coin.CFrame = CFrame.new(position)
	coin.Color = Color3.fromRGB(255, 205, 40)
	coin.Material = Enum.Material.Metal
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanQuery = false
	coin.CanTouch = false
	coin.Parent = m
	local inner = coin:Clone()
	inner.Size = Vector3.new(0.7, 2.3, 2.3)
	inner.Color = Color3.fromRGB(255, 235, 120)
	inner.Material = Enum.Material.Neon
	inner.Parent = m
	m.PrimaryPart = coin
	m.Parent = parent
	return m
end

local function ringModel(position: Vector3, parent: Instance): Model
	local m = Instance.new("Model")
	local radius = Jump.Collectibles.RingRadius
	local count = 18
	for i = 0, count - 1 do
		local a = i / count * math.pi * 2
		local p = Instance.new("Part")
		p.Size = Vector3.new(1.4, 1.4, 2 * math.pi * radius / count + 0.4)
		p.CFrame = CFrame.new(position + Vector3.new(0, math.sin(a) * radius, math.cos(a) * radius)) * CFrame.Angles(-(a + math.pi / 2), 0, 0)
		p.Color = Color3.fromRGB(255, 200, 40)
		p.Material = Enum.Material.Neon
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Parent = m
		if i == 0 then
			m.PrimaryPart = p
		end
	end
	local light = Instance.new("PointLight")
	light.Range = 20
	light.Color = Color3.fromRGB(255, 220, 100)
	light.Parent = m.PrimaryPart
	m.Parent = parent
	return m
end

local function collectEffect(model: Model?, color: Color3)
	if not model then
		return
	end
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			TweenService:Create(part, TweenInfo.new(0.25), { Transparency = 1, Size = part.Size * 1.6, Color = color }):Play()
		end
	end
	task.delay(0.3, function()
		model:Destroy()
	end)
end

-- Prošel hráč mezi minulou a současnou pozicí kolem sběratelné věci?
local function checkCollect(state: FlightState, fromX: number, toX: number, y: number)
	local c = Jump.Collectibles
	for _, coin in state.Coins do
		if not coin.Taken and coin.Position.X >= fromX and coin.Position.X <= toX then
			if math.abs(coin.Position.Z - state.Z) <= c.CoinRadius and math.abs(coin.Position.Y - y) <= c.CoinRadius + 2 then
				coin.Taken = true
				table.insert(state.CollectedCoins, coin.Id)
				collectEffect(coin.Part, Color3.fromRGB(255, 255, 200))
				Sound.Play("Coin", 1 + #state.CollectedCoins * 0.02)
				coinsLabel.Text = "Coins: " .. #state.CollectedCoins
				Kit.Pop(coinsLabel, 1.25)
			end
		end
	end
	for _, ring in state.Rings do
		if not ring.Taken and ring.Position.X >= fromX and ring.Position.X <= toX then
			if math.abs(ring.Position.Z - state.Z) <= c.RingRadius and math.abs(ring.Position.Y - y) <= c.RingRadius then
				ring.Taken = true
				table.insert(state.CollectedRings, ring.Id)
				collectEffect(ring.Part, Color3.fromRGB(255, 255, 255))
				Sound.Play("Ring")
				local ringBonus = state.Info.RingBonus or c.RingBonus
				ringsLabel.Text = "⭕ " .. #state.CollectedRings .. "  (+" .. math.floor(#state.CollectedRings * ringBonus * 100 + 0.5) .. "%)"
				Kit.Pop(ringsLabel, 1.3)
				Effects.BigText("+" .. math.floor(ringBonus * 100 + 0.5) .. "% DISTANCE!", Kit.Colors.Yellow, 0.7, 0.36)
			end
		end
	end
end

-- ===== Let =====

local function getControls(): any?
	local ok, module = pcall(function()
		local playerModule = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
		return if playerModule then (require :: any)(playerModule) else nil
	end)
	if ok and module then
		return (module :: any):GetControls()
	end
	return nil
end

local controls: any? = nil

local function steerInput(): number
	if not controls then
		controls = getControls()
	end
	if controls then
		local move = controls:GetMoveVector()
		return math.clamp(move.X, -1, 1)
	end
	return 0
end

local function setCharacterFlying(flying: boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = flying
		humanoid.AutoRotate = not flying
	end
end

local function endFlightVisuals()
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		TweenService:Create(camera, TweenInfo.new(0.5), { FieldOfView = Jump.Flight.CameraFov }):Play()
	end
	flightHud.Visible = false
	HUD.SetVisible(true)
end

local function finishFlight(state: FlightState)
	state.Phase = "Landed"
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		state.LandPosition = root.Position
	end
	Net.Event("FlightLanded"):FireServer(state.Id, state.CollectedCoins, state.CollectedRings)
	Sound.Play("Splash")
end

local function startFlight(info: { [string]: any })
	awaitingFlight = false
	charging = false
	destroyMeter()
	if flight then
		flight.Folder:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "FlightCollectibles"
	folder.Parent = Workspace
	local coins: { Collectible } = {}
	for _, coin in info.Coins do
		table.insert(coins, { Id = coin.Id, Position = coin.Position, Part = coinModel(coin.Position, folder), Taken = false })
	end
	local rings: { Collectible } = {}
	for _, ring in info.Rings do
		table.insert(rings, { Id = ring.Id, Position = ring.Position, Part = ringModel(ring.Position, folder), Taken = false })
	end
	local state: FlightState = {
		Id = info.Id,
		Info = info,
		StartClock = os.clock(),
		Phase = "Main",
		Z = info.StartPosition.Z,
		Coins = coins,
		Rings = rings,
		CollectedCoins = {},
		CollectedRings = {},
		FinalDistance = info.BaseDistance,
		GlideStart = 0,
		GlideDuration = 0,
		LastX = info.StartPosition.X,
		LandPosition = nil,
		Folder = folder,
		SwimInfo = nil,
		SwimStart = 0,
		SwimProgress = 0,
		SwimEnded = false,
		Shark = nil,
		ExpectedPosition = nil,
	}
	flight = state
	setInZone(false)
	setCharacterFlying(true)
	HUD.SetVisible(false)
	flightHud.Visible = true
	coinsLabel.Text = "Coins: 0"
	ringsLabel.Text = "⭕ 0"
	steerHint.Visible = true
	task.delay(2.5, function()
		steerHint.Visible = false
	end)
	if info.Tier == "Perfect" then
		Effects.BigText("PERFECT!", Kit.Colors.Green, 1.1)
		Effects.ScreenConfetti(60)
		Sound.Play("Perfect")
	elseif info.Tier == "Good" then
		Effects.BigText("GOOD!", Kit.Colors.Yellow, 0.9)
		Sound.Play("Good")
	end
	if info.MegaJump then
		HUD.Notify("MEGA JUMP! +50%", "Success")
	elseif info.SuperJump then
		HUD.Notify("SUPER JUMP! +20%", "Success")
	end
	-- série PERFECT skoků (bonus spočítal server)
	local streak = info.PerfectStreak or 0
	if streak >= 2 then
		local bonus = math.floor((info.StreakBonus or 0) * 100 + 0.5)
		task.delay(0.7, function()
			Effects.BigText("PERFECT STREAK x" .. streak .. "  +" .. bonus .. "%", Kit.Colors.Pink, 1.2, 0.3)
		end)
	end
	local slipper = Catalog.Slipper(ClientState.Get().EquippedSlippers or "")
	if slipper and slipper.Effect == "Boing" then
		Sound.Play("Boing")
	elseif slipper and slipper.Effect == "Squeak" then
		Sound.Play("Squeak")
	end
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
		TweenService:Create(camera, TweenInfo.new(0.8), { FieldOfView = Jump.Flight.CameraFlightFov }):Play()
	end
end

-- ===== Plavání zpět (vor a žralok) =====

local swimHud: Frame
local swimBarYou: Frame
local swimBarShark: Frame
local swimHint: TextLabel

local function raftModel(position: Vector3, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = "Raft"
	local function add(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.Wood
		p.Shape = shape or Enum.PartType.Block
		p.Parent = m
		return p
	end
	for i = -3, 3 do
		-- kulatiny (válec leží podél osy X)
		add(Vector3.new(14, 1.6, 1.6), CFrame.new(position + Vector3.new(0, 0.3, i * 1.9)), Color3.fromRGB(190, 135, 80), Enum.Material.Wood, Enum.PartType.Cylinder)
	end
	add(Vector3.new(0.4, 9, 0.4), CFrame.new(position + Vector3.new(0, 5, 0)), Color3.fromRGB(110, 75, 45))
	local flag = add(Vector3.new(0.2, 3, 5), CFrame.new(position + Vector3.new(0, 8, 2.6)), Color3.fromRGB(80, 220, 110), Enum.Material.SmoothPlastic)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 60)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = flag
	local label = Kit.Text(gui, { Text = "SAFE!", Size = UDim2.fromScale(1, 1), TextColor3 = Kit.Colors.Green, StrokeThickness = 3 })
	label.Name = "SafeLabel"
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(120, 255, 150)
	light.Range = 20
	light.Parent = flag
	m.Parent = parent
	return m
end

local function sharkModel(parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = "Shark"
	local gray = Color3.fromRGB(110, 125, 145)
	local function add(className: string, size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?): BasePart
		local p = Instance.new(className) :: BasePart
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		if shape and p:IsA("Part") then
			p.Shape = shape
		end
		p.Parent = m
		return p
	end
	-- žralok pluje ve směru -Z modelu
	local body = add("Part", Vector3.new(4.5, 3.6, 12), CFrame.new(0, -0.8, 0), gray, Enum.PartType.Ball)
	add("Part", Vector3.new(3.4, 1.6, 9), CFrame.new(0, -1.8, -0.5), Color3.fromRGB(235, 235, 240), Enum.PartType.Ball)
	add("WedgePart", Vector3.new(0.6, 3.6, 3.2), CFrame.new(0, 2.4, 0.6), gray)
	add("WedgePart", Vector3.new(0.5, 3, 2.4), CFrame.new(0, 0.2, 7) * CFrame.Angles(math.rad(180), 0, 0), gray)
	for _, side in { -1, 1 } do
		add("Part", Vector3.new(0.7, 0.7, 0.7), CFrame.new(side * 1.6, 0, -4.2), Color3.fromRGB(20, 20, 25), Enum.PartType.Ball)
	end
	-- usměvavé zuby (kreslený styl, nic strašidelného)
	add("Part", Vector3.new(2.6, 0.35, 0.3), CFrame.new(0, -1.2, -5.6), Color3.new(1, 1, 1))
	m.PrimaryPart = body
	m.Parent = parent
	return m
end

local function startSwim(info: { [string]: any })
	local state = flight
	if not state or state.Phase == "Returned" then
		return
	end
	state.Phase = "Swim"
	state.SwimInfo = info
	state.SwimStart = os.clock()
	state.SwimProgress = 0
	state.SwimEnded = false
	state.Z = info.StartZ
	raftModel(Vector3.new(info.StartX - info.Distance, info.Y, info.StartZ), state.Folder)
	if not info.NoShark then
		local shark = sharkModel(state.Folder)
		shark:PivotTo(CFrame.new(0, -500, 0))
		state.Shark = shark
	end
	swimHud.Visible = true
	swimBarShark.Visible = not info.NoShark
	flightHud.Visible = false
	if info.NoShark then
		Effects.BigText(if info.UsedRepellent then "SHARK REPELLENT! SWIM!" else "SWIM TO THE RAFT!", Kit.Colors.Turquoise, 1.4, 0.25)
	else
		Effects.BigText("SWIM TO THE RAFT!", Kit.Colors.Turquoise, 1.2, 0.25)
		task.delay(info.SharkDelay, function()
			if flight == state and not state.SwimEnded then
				Effects.BigText("SHARK!!! SWIM FASTER!", Kit.Colors.Coral, 1.2, 0.3)
				Sound.Play("Fanfare", 0.6)
			end
		end)
	end
	swimHint.Visible = true
	task.delay(3, function()
		swimHint.Visible = false
	end)
end

updateSwim = function(state: FlightState, root: BasePart, dt: number)
	local info = state.SwimInfo
	if not info then
		return
	end
	local elapsed = os.clock() - state.SwimStart
	if not state.SwimEnded then
		if not controls then
			controls = getControls()
		end
		local move = if controls then controls:GetMoveVector() else Vector3.zero
		local forward = math.clamp(-move.Z, 0, 1)
		state.SwimProgress = math.min(info.Distance, state.SwimProgress + info.Speed * forward * dt)
		state.Z = math.clamp(state.Z - move.X * info.Speed * 0.5 * dt, -40, 40)
	end
	local position = Vector3.new(info.StartX - state.SwimProgress, info.Y + 0.4 + math.sin(os.clock() * 6) * 0.15, state.Z)
	state.ExpectedPosition = position
	-- plavecká poloha: břichem dolů, hlavou k voru (-X)
	root.CFrame = CFrame.lookAt(position, position - Vector3.xAxis) * CFrame.Angles(math.rad(-80), 0, math.sin(os.clock() * 8) * 0.2)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	-- žralok
	local sharkProgress = Formulas.SharkProgress(elapsed, info.SharkSpeed)
	local shark = state.Shark
	if shark then
		if elapsed < info.SharkDelay then
			-- ploutev se blíží zezadu
			local behind = Vector3.new(info.StartX + 30 - (elapsed / info.SharkDelay) * 30, info.Y - 1.6, state.Z + 6)
			shark:PivotTo(CFrame.lookAt(behind, behind - Vector3.xAxis))
		else
			local sx = info.StartX - math.min(sharkProgress, state.SwimProgress + 2)
			local sharkPos = Vector3.new(sx, info.Y + 0.6, state.Z + math.sin(os.clock() * 3) * 1.5)
			shark:PivotTo(CFrame.lookAt(sharkPos, sharkPos - Vector3.xAxis))
		end
	end
	-- ukazatel: ty vs. žralok
	swimBarYou.Size = UDim2.fromScale(math.clamp(state.SwimProgress / info.Distance, 0, 1), 1)
	swimBarShark.Position = UDim2.fromScale(math.clamp(sharkProgress / info.Distance, 0, 1), 0.5)
	-- kamera za hráčem (vidí žraloka i vor)
	local camera = Workspace.CurrentCamera
	if camera then
		local camPos = position + Vector3.new(24, 11, 0)
		camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(camPos, position - Vector3.new(18, 2, 0)), 0.15)
	end
end

local function endSwim(result: { [string]: any })
	local state = flight
	if not state then
		return
	end
	state.SwimEnded = true
	if result.Success then
		Effects.BigText("SAFE! +" .. FormatNumber.Money(result.Bonus), Kit.Colors.Green, 1.4, 0.28)
		Effects.ScreenConfetti(60)
		Sound.Play("Coin")
	elseif result.Reason == "Shark" then
		Effects.BigText("CHOMP! The shark got you!", Kit.Colors.Coral, 1.4, 0.28)
		local pos = state.ExpectedPosition
		if pos then
			Effects.Splash(pos, true)
		end
		if state.SwimInfo and state.SwimInfo.CanUpgrade then
			HUD.Notify("Swim faster! Buy swim gear in the SHOP (Swim tab).", "Info")
		end
	else
		Effects.BigText("Too slow!", Kit.Colors.Orange, 1.2, 0.28)
	end
	task.delay(Swim.ReturnDelay - 0.45, function()
		Effects.Fade(true, 0.35)
	end)
	task.delay(Swim.ReturnDelay + 0.15, function()
		if flight == state then
			state.Folder:Destroy()
			flight = nil
		end
		swimHud.Visible = false
		setCharacterFlying(false)
		endFlightVisuals()
		Effects.Fade(false, 0.5)
	end)
end

local function updateFlight(dt: number)
	local state = flight
	if not state then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	if state.Phase == "Returned" then
		return
	end
	-- server hráče přenesl na pláž → přestat řídit postavu
	local expected = if state.Phase == "Swim" then state.ExpectedPosition else state.LandPosition
	if (state.Phase == "Landed" or state.Phase == "Swim") and expected and (root.Position - expected).Magnitude > 40 then
		state.Phase = "Returned"
		return
	end
	if state.Phase == "Swim" then
		updateSwim(state, root, dt)
		return
	end
	local info = state.Info
	local elapsed = os.clock() - state.StartClock
	local x, y: number
	local limit = Jump.Flight.SteerLimit
	if state.Phase ~= "Landed" then
		state.Z = math.clamp(state.Z + steerInput() * Jump.Flight.SteerSpeed * dt, -limit, limit)
	end
	local lean = 0
	if state.Phase == "Main" then
		local p = math.clamp(elapsed / info.Duration, 0, 1)
		x, y = Formulas.Trajectory(p, info.StartPosition.X, info.EndX, info.StartPosition.Y, info.EndY, info.Height)
		lean = steerInput()
		if p >= 1 then
			-- dolet díky kruhům
			local c = Jump.Collectibles
			local final = math.min(info.BaseDistance * (1 + (info.RingBonus or c.RingBonus) * #state.CollectedRings), info.Cap)
			state.FinalDistance = final
			local extra = final - info.BaseDistance
			if extra > 1 then
				state.Phase = "Glide"
				state.GlideStart = os.clock()
				state.GlideDuration = Formulas.ExtraGlideTime(extra, info.BaseDistance)
				Effects.BigText("RING BOOST!", Kit.Colors.Yellow, 0.8, 0.36)
			else
				finishFlight(state)
			end
		end
	elseif state.Phase == "Glide" then
		local final = state.FinalDistance
		local extra = final - info.BaseDistance
		local g = math.clamp((os.clock() - state.GlideStart) / state.GlideDuration, 0, 1)
		x = info.EndX + extra * g
		local endY = if final >= World.GiftDistance then World.WaterY + 7 else World.WaterY + 1.5
		y = info.EndY + (endY - info.EndY) * g + Formulas.ExtraGlideHeight(extra) * 4 * g * (1 - g)
		if g >= 1 then
			finishFlight(state)
		end
	else
		local land = state.LandPosition or root.Position
		x = land.X
		y = land.Y + math.sin(os.clock() * 3) * 0.3
	end
	assert(x and y)
	checkCollect(state, state.LastX, x, y)
	state.LastX = x
	-- směr pohybu (natočení postavy)
	local position = Vector3.new(x, y, state.Z)
	local forward = Vector3.new(1, 0, 0)
	local cf = CFrame.lookAt(position, position + forward) * CFrame.Angles(0, 0, -lean * 0.35)
	if state.Phase == "Main" then
		cf *= CFrame.Angles(math.rad(-55), 0, 0)
	end
	root.CFrame = cf
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	-- kamera za hráčem
	local camera = Workspace.CurrentCamera
	if camera and state.Phase ~= "Landed" then
		local behind = position + Vector3.new(-22, 9, 0)
		camera.CFrame = CFrame.lookAt(behind, position + Vector3.new(30, -2, 0))
	elseif camera then
		local behind = position + Vector3.new(-26, 12, 10)
		camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(behind, position), 0.1)
	end
	-- vzdálenost od konce mola
	local distance = math.max(0, x - World.PierEndX)
	distanceLabel.Text = FormatNumber.Studs(math.floor(distance))
end

-- ===== Výsledek skoku =====

local function showResult(result: { [string]: any })
	local state = flight
	local landing = if state and state.LandPosition then state.LandPosition else Vector3.new(World.PierEndX + result.Distance, World.WaterY, 0)
	Effects.Splash(Vector3.new(landing.X, World.WaterY, landing.Z), result.Distance > 10_000)
	Effects.BigText(FormatNumber.Studs(result.Distance) .. "!", Kit.Colors.White, 2.2, 0.2)
	if result.PersonalRecord then
		HUD.Notify("NEW PERSONAL BEST!", "Record")
	end
	if result.CoinMoney > 0 then
		Effects.FloatText("+" .. FormatNumber.Money(result.CoinMoney) .. " from coins", Kit.Colors.Yellow)
	end
	if result.DoubleXP then
		Effects.FloatText("DOUBLE XP! +" .. FormatNumber.Short(result.XP) .. " XP", Color3.fromRGB(120, 220, 255))
	end
	-- předmět vyplave z vody
	local item = result.Item
	if item then
		local cfg = Catalog.Item(item.Id)
		local model = Models.Item(item.Id)
		Models.Anchor(model)
		local start = CFrame.new(landing.X + 8, World.WaterY - 3, landing.Z)
		model:PivotTo(start)
		model.Parent = Workspace
		local value = Instance.new("NumberValue")
		value.Changed:Connect(function(alpha)
			model:PivotTo(start * CFrame.new(0, alpha * 7, 0) * CFrame.Angles(0, alpha * math.pi * 2, 0))
		end)
		TweenService:Create(value, TweenInfo.new(1.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 1 }):Play()
		task.delay(4, function()
			model:Destroy()
			value:Destroy()
		end)
		if cfg then
			JumpController.ShowItemCard(item.Id, result.IsNew, result.Placement)
		end
	end
	if result.ReachedGift then
		Effects.WorldConfetti(landing + Vector3.new(60, 40, 0), 120, 6)
		Effects.ScreenConfetti(150)
	end
	if not result.ReachedGift then
		return -- dál pokračuje plavání (SwimStart / SwimResult)
	end
	local delayTime = Jump.GiftReturnDelay
	task.delay(delayTime - 0.45, function()
		Effects.Fade(true, 0.35)
	end)
	task.delay(delayTime + 0.15, function()
		if flight == state and state then
			state.Folder:Destroy()
			flight = nil
		end
		setCharacterFlying(false)
		endFlightVisuals()
		Effects.Fade(false, 0.5)
	end)
end

function JumpController.ShowItemCard(itemId: string, isNew: boolean?, placement: string?)
	local cfg = Catalog.Item(itemId)
	if not cfg then
		return
	end
	local rarity = Catalog.Rarity(cfg.Rarity)
	local frameColor = if rarity.Name == "Secret" then Color3.fromRGB(30, 30, 40) else rarity.Color
	local cardFrame = Kit.Panel(screen, {
		Size = UDim2.fromOffset(340, 400),
		Position = UDim2.fromScale(0.5, 0.58),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = frameColor,
		Radius = 26,
		StrokeThickness = 6,
	})
	local inner = Kit.Panel(cardFrame, { Size = UDim2.new(1, -24, 1, -24), Position = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.fromRGB(255, 252, 240), StrokeThickness = 2 })
	if rarity.Rainbow then
		local gradient = Kit.new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 60)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 200, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)),
			}),
			Parent = cardFrame:FindFirstChildOfClass("UIStroke"),
		})
		TweenService:Create(gradient, TweenInfo.new(1.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 }):Play()
	end
	if rarity.Pulse then
		local stroke = cardFrame:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Thickness = 12 }):Play()
		end
	end
	Kit.Text(inner, { Text = if isNew then "NEW! " .. rarity.Name else rarity.Name, Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 8), TextColor3 = if rarity.Name == "Secret" then Color3.fromRGB(150, 90, 255) else rarity.Color, StrokeThickness = 2.5 })
	local holder = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 210), Position = UDim2.fromOffset(10, 50), Parent = inner })
	local model = Models.Item(itemId)
	Kit.Viewport(holder, model)
	Kit.Text(inner, { Text = cfg.Name, Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 262), TextColor3 = Kit.Colors.Text, NoStroke = true })
	Kit.Text(inner, { Text = "+" .. FormatNumber.Money(cfg.Income) .. "/s", Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 302), TextColor3 = Color3.fromRGB(40, 170, 70), NoStroke = true })
	local where = if placement == "Carried" then "House full! Carry it over your head." elseif placement == "Storage" then "Sent to storage." else "Placed in your house!"
	Kit.Text(inner, { Text = where, Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 338), TextColor3 = Kit.Colors.Gray, NoStroke = true })
	Kit.Pop(cardFrame, 0.4)
	if rarity.Fanfare then
		Sound.Play("Fanfare")
		Effects.ScreenConfetti(if rarity.Order >= 6 then 120 else 50)
	end
	-- pomalé otáčení modelu v kartě
	local spin = RunService.RenderStepped:Connect(function(dt: number)
		if model.Parent then
			model:PivotTo(model:GetPivot() * CFrame.Angles(0, dt * 1.5, 0))
		end
	end)
	task.delay(if rarity.Fanfare then 3 else 2, function()
		spin:Disconnect()
		TweenService:Create(cardFrame, TweenInfo.new(0.25), { Position = UDim2.fromScale(0.5, 1.3) }):Play()
		task.delay(0.3, function()
			cardFrame:Destroy()
		end)
	end)
end

function JumpController.Init(parentScreen: ScreenGui)
	screen = parentScreen
	jumpButton = Kit.Button(screen, {
		Text = "JUMP!",
		Color = Kit.Colors.Coral,
		Size = UDim2.fromOffset(260, 110),
		Position = UDim2.new(0.5, 0, 1, -40),
		AnchorPoint = Vector2.new(0.5, 1),
		Radius = 30,
		Name = "JumpButton",
	})
	jumpButton.Visible = false
	Kit.Text(jumpButton, { Text = "HOLD & RELEASE", Size = UDim2.new(1, -20, 0, 22), Position = UDim2.new(0, 10, 1, -26), ZIndex = 3, StrokeThickness = 2 })
	jumpButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			startCharge()
		end
	end)
	jumpButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			releaseCharge()
		end
	end)

	flightHud = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = screen })
	distanceLabel = Kit.Text(flightHud, { Text = "0 studs", Size = UDim2.fromOffset(520, 80), Position = UDim2.new(0.5, 0, 0, 20), AnchorPoint = Vector2.new(0.5, 0), StrokeThickness = 4 })
	coinsLabel = Kit.Text(flightHud, { Text = "Coins: 0", Size = UDim2.fromOffset(260, 54), Position = UDim2.new(0, 24, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Kit.Colors.Yellow })
	ringsLabel = Kit.Text(flightHud, { Text = "⭕ 0", Size = UDim2.fromOffset(340, 54), Position = UDim2.new(0, 24, 0, 90), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 230, 120) })
	steerHint = Kit.Text(flightHud, { Text = "Steer with A / D or the joystick!", Size = UDim2.fromOffset(600, 44), Position = UDim2.new(0.5, 0, 1, -60), AnchorPoint = Vector2.new(0.5, 1), TextColor3 = Kit.Colors.White })

	swimHud = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = screen })
	local bar = Kit.Panel(swimHud, { Size = UDim2.fromOffset(560, 44), Position = UDim2.new(0.5, 0, 0, 30), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromRGB(40, 80, 140), Radius = 20 })
	swimBarYou = Kit.new("Frame", { BackgroundColor3 = Kit.Colors.Green, Size = UDim2.fromScale(0, 1), Parent = bar })
	Kit.Corner(swimBarYou, 20)
	Kit.Text(bar, { Text = "YOU  >>>  RAFT", Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5), ZIndex = 3 })
	swimBarShark = Kit.Text(bar, { Text = "SHARK", Size = UDim2.fromOffset(90, 36), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), TextColor3 = Kit.Colors.Coral, StrokeThickness = 3, ZIndex = 4 }) :: any
	swimHint = Kit.Text(swimHud, { Text = "Hold W / joystick forward to swim!", Size = UDim2.fromOffset(640, 46), Position = UDim2.new(0.5, 0, 1, -60), AnchorPoint = Vector2.new(0.5, 1) })
	Net.Event("SwimStart").OnClientEvent:Connect(startSwim)
	Net.Event("SwimResult").OnClientEvent:Connect(endSwim)

	Net.Event("FlightStart").OnClientEvent:Connect(startFlight)
	Net.Event("JumpResult").OnClientEvent:Connect(function(result)
		local state = flight
		if state and state.Phase ~= "Landed" then
			-- server skončil dřív (pojistka) – přistát hned
			finishFlight(state)
		end
		showResult(result)
	end)

	-- ukazatel síly + zóna na konci mola
	RunService.RenderStepped:Connect(function(dt)
		if flight then
			updateFlight(dt)
			return
		end
		setInZone(zoneCheck())
		if charging and meterFill and meterMarker then
			local value = Formulas.MeterValue(os.clock() - chargeStart, chargePeriod)
			meterFill.Size = UDim2.fromScale(1, value)
			meterMarker.Position = UDim2.new(0, -11, 1 - value, 0)
		end
	end)

	player.CharacterAdded:Connect(function()
		if flight then
			flight.Folder:Destroy()
			flight = nil
		end
		swimHud.Visible = false
		charging = false
		destroyMeter()
		endFlightVisuals()
	end)

end

return JumpController

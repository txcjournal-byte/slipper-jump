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
local Diamonds = require(Shared.Config.Diamonds)
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
local Slalom = require(script.Parent.Slalom)

local JumpController = {}

local updateSwim: (any, BasePart, number) -> ()
local returnToBeach: (any, number) -> ()
local hideRaftChoice: () -> ()
local showRaftChoice: (any, { [string]: any }) -> ()

local player = Players.LocalPlayer

type Collectible = { Id: string, Position: Vector3, Part: Model?, Taken: boolean }
type Gem = { Id: string, Position: Vector3, Type: string, Part: Model, Taken: boolean }
type Balloon = { Id: string, Position: Vector3, Part: Model, Taken: boolean }

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
	Gems: { Gem },
	CollectedGems: { string },
	GemDistanceBonus: number, -- Rainbow diamant: delší skok
	Balloons: { Balloon },
	PoppedBalloons: { string },
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
	Chasers: { Model }, -- pronásledovatelé (žralok, velryba, chobotnice…)
	Slalom: Slalom.Run?, -- branky a překážky na cestě k voru (od levelu 2)
	OnRaft: boolean, -- doplaval a stojí na voru (vybírá: dál / zpět)
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
local gemsLabel: TextLabel
local steerHint: TextLabel
-- ukazatel cesty k Obřímu dárku (pod vzdáleností)
local giftBar: Frame
local giftFill: Frame
local giftIcon: TextLabel
local giftMessage: TextLabel
local giftStage = 0 -- 0 = nic, 1 = „Almost there“ (80 %), 2 = „SO CLOSE“ (95 %), 3 = dárek

local inZone = false
local charging = false
local chargeStart = 0
local chargePeriod = Jump.Meter.Period
local flight: FlightState? = nil
local awaitingFlight = false

-- kamera během letu: základní CFrame (bez otřesu) a plynulé zorné pole
local cameraBase: CFrame? = nil
local flightFov = Jump.Flight.CameraFov
local flightFovTarget = Jump.Flight.CameraFlightFov
local lastStroke = 0

-- Nastaví kameru: základ + otřes a FOV rána z Effects (otřes se nesčítá do dalšího snímku)
local function applyCamera(camera: Camera, base: CFrame, dt: number)
	cameraBase = base
	flightFov += (flightFovTarget - flightFov) * (1 - math.exp(-dt * 3))
	camera.CFrame = base * Effects.CameraOffset()
	camera.FieldOfView = math.clamp(flightFov + Effects.FovOffset(), 40, 120)
end

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

-- Barevný diamant: broušený kámen (dvě pyramidy z klínů) se zářícím jádrem, světlem a jiskřičkami
local function diamondModel(position: Vector3, kind: string, parent: Instance): Model
	local t = Diamonds.ByKey[kind] or Diamonds.Types[1]
	local m = Instance.new("Model")
	m.Name = "Diamond"
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.one * 1.6
	core.Material = Enum.Material.Neon
	core.Color = t.Color
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.CFrame = CFrame.new(position)
	core.Parent = m
	m.PrimaryPart = core
	-- 8 stěn: 4 klíny nahoře (koruna, nízká) a 4 dole (špička, vysoká)
	for i = 0, 3 do
		local yaw = CFrame.Angles(0, i * math.pi / 2, 0)
		for _, top in { true, false } do
			local w = Instance.new("WedgePart")
			local h = if top then 1.6 else 3.2
			w.Size = Vector3.new(3.4, h, 1.7)
			w.Material = Enum.Material.Glass
			w.Transparency = 0.15
			w.Reflectance = 0.25
			w.Color = t.Color
			w.Anchored = true
			w.CanCollide = false
			w.CanQuery = false
			w.CanTouch = false
			local offset = if top then CFrame.new(0, h / 2, -0.85) else CFrame.new(0, -h / 2, -0.85) * CFrame.Angles(0, 0, math.pi)
			w:SetAttribute("Offset", offset)
			w:SetAttribute("Yaw", i * math.pi / 2)
			w.CFrame = CFrame.new(position) * yaw * offset
			w.Parent = m
		end
	end
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 2
	light.Color = t.Color
	light.Parent = core
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Rate = if kind == "Rainbow" or kind == "Gold" then 30 else 14
	sparkle.Lifetime = NumberRange.new(0.5, 1)
	sparkle.Speed = NumberRange.new(2, 5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Color = ColorSequence.new(Color3.new(1, 1, 1), t.Color)
	sparkle.Parent = core
	m.Parent = parent
	return m
end

-- Balónek s truhlou: velký lesklý balónek, provázek a malá zlatá truhla pod ním
local BALLOON_COLORS = { Color3.fromRGB(255, 70, 110), Color3.fromRGB(255, 170, 40), Color3.fromRGB(80, 200, 255), Color3.fromRGB(150, 230, 90) }
local function balloonModel(position: Vector3, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = "TreasureBalloon"
	local function add(className: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): BasePart
		local p = Instance.new(className) :: BasePart
		if shape and p:IsA("Part") then
			p.Shape = shape
		end
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Parent = m
		return p
	end
	local color = BALLOON_COLORS[math.random(1, #BALLOON_COLORS)]
	local ball = add("Part", Vector3.new(6, 7, 6), CFrame.new(position + Vector3.new(0, 4.5, 0)), color, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	ball.Reflectance = 0.15
	add("Part", Vector3.new(0.7, 0.7, 0.7), CFrame.new(position + Vector3.new(0, 0.9, 0)), color, nil, Enum.PartType.Ball)
	add("Part", Vector3.new(0.12, 3, 0.12), CFrame.new(position + Vector3.new(0, -0.6, 0)), Color3.fromRGB(240, 240, 240))
	-- truhla
	add("Part", Vector3.new(2.6, 1.5, 1.8), CFrame.new(position + Vector3.new(0, -2.8, 0)), Color3.fromRGB(150, 90, 40), Enum.Material.Wood)
	add("Part", Vector3.new(2.7, 0.7, 1.9), CFrame.new(position + Vector3.new(0, -1.8, 0)), Color3.fromRGB(130, 75, 35), Enum.Material.Wood)
	add("Part", Vector3.new(2.75, 0.25, 1.95), CFrame.new(position + Vector3.new(0, -2.15, 0)), Color3.fromRGB(255, 205, 60), Enum.Material.Metal)
	local lock = add("Part", Vector3.new(0.5, 0.6, 0.2), CFrame.new(position + Vector3.new(0, -2.4, -0.98)), Color3.fromRGB(255, 220, 90), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Range = 14
	light.Color = Color3.fromRGB(255, 220, 120)
	light.Parent = lock
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Rate = 12
	sparkle.Lifetime = NumberRange.new(0.6, 1)
	sparkle.Speed = NumberRange.new(1, 3)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120))
	sparkle.Parent = lock
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(150, 40)
	gui.StudsOffset = Vector3.new(0, 9.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 400
	gui.Parent = ball
	Kit.Text(gui, { Text = "🎁 TREASURE", Size = UDim2.fromScale(1, 1), TextColor3 = Kit.Colors.Yellow, StrokeThickness = 3 })
	m.PrimaryPart = ball
	m.Parent = parent
	return m
end

-- Diamanty se točí a pomalu pohupují (duhový mění barvu)
local function animateGems(state: FlightState)
	local now = os.clock()
	for i, gem in state.Gems do
		if not gem.Taken and gem.Part.Parent then
			local base = CFrame.new(gem.Position + Vector3.new(0, math.sin(now * 2 + i) * 0.6, 0)) * CFrame.Angles(0, now * 2.2 + i, 0)
			local rainbow = if gem.Type == "Rainbow" then Color3.fromHSV((now * 0.4 + i * 0.2) % 1, 0.75, 1) else nil
			for _, part in gem.Part:GetChildren() do
				if part:IsA("BasePart") then
					local offset = part:GetAttribute("Offset")
					local yaw = part:GetAttribute("Yaw")
					if typeof(offset) == "CFrame" and typeof(yaw) == "number" then
						part.CFrame = base * CFrame.Angles(0, yaw, 0) * offset
					else
						part.CFrame = base
					end
					if rainbow then
						part.Color = rainbow
					end
				end
			end
		end
	end
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
				Effects.FovKick(1.5)
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
				Effects.FovKick(9)
				Effects.Shake(0.12)
				local ringBonus = state.Info.RingBonus or c.RingBonus
				ringsLabel.Text = "⭕ " .. #state.CollectedRings .. "  (+" .. math.floor(#state.CollectedRings * ringBonus * 100 + 0.5) .. "%)"
				Kit.Pop(ringsLabel, 1.3)
				Effects.BigText("+" .. math.floor(ringBonus * 100 + 0.5) .. "% DISTANCE!", Kit.Colors.Yellow, 0.7, 0.36)
			end
		end
	end
	for _, gem in state.Gems do
		if not gem.Taken and gem.Position.X >= fromX - 1 and gem.Position.X <= toX + 1 then
			if math.abs(gem.Position.Z - state.Z) <= Diamonds.Radius and math.abs(gem.Position.Y - y) <= Diamonds.Radius + 1 then
				gem.Taken = true
				table.insert(state.CollectedGems, gem.Id)
				local t = Diamonds.ByKey[gem.Type] or Diamonds.Types[1]
				state.GemDistanceBonus += t.DistanceBonus or 0
				collectEffect(gem.Part, Color3.new(1, 1, 1))
				local rare = gem.Type == "Gold" or gem.Type == "Rainbow" or gem.Type == "Purple"
				Sound.Play("Diamond", if rare then 1.25 else 1)
				if rare then
					Sound.Play("Perfect", 1.4)
					Effects.ScreenConfetti(if gem.Type == "Rainbow" then 80 else 35)
				end
				Effects.FovKick(10)
				Effects.Shake(0.15)
				gemsLabel.Text = "💎 " .. #state.CollectedGems
				gemsLabel.Visible = true
				Kit.Pop(gemsLabel, 1.4)
				Effects.BigText(`{string.upper(t.Name)}! {t.Text}`, t.Color, 1, 0.42)
			end
		end
	end
	for _, balloon in state.Balloons do
		if not balloon.Taken and balloon.Position.X >= fromX - 1.5 and balloon.Position.X <= toX + 1.5 then
			if math.abs(balloon.Position.Z - state.Z) <= Diamonds.Balloon.Radius and math.abs(balloon.Position.Y - y) <= Diamonds.Balloon.Radius + 2 then
				balloon.Taken = true
				table.insert(state.PoppedBalloons, balloon.Id)
				collectEffect(balloon.Part, Color3.new(1, 1, 1))
				Sound.Play("Splash", 2.2) -- „prásk“
				Sound.Play("Perfect", 1.1)
				Effects.ScreenConfetti(70)
				Effects.Shake(0.25)
				Effects.FovKick(12)
				Effects.BigText("POP! TREASURE BALLOON!", Kit.Colors.Yellow, 1.2, 0.42)
			end
		end
	end
	animateGems(state)
end

-- ===== Cesta k Obřímu dárku =====

-- Nejbližší dárek pro aktuální skok (dárkový ostrov nebo Obří dárek) – posílá server ve FlightStart
local giftTarget = World.GiftDistance
local giftTargetName = "Giant Gift"
-- nejlepší skok před tímto skokem (kvůli oslavě nových "rekordních zón")
local bestBefore = 0
local RECORD_ZONES = { 500, 1_000, 2_500, 5_000, 10_000, 20_000, 30_000, 40_000, 60_000, 80_000 }

-- Podíl délky pruhu: napůl logaritmicky (i krátké skoky jsou vidět), napůl lineárně (konec je napínavý)
local function giftBarFraction(distance: number): number
	local p = math.clamp(distance / giftTarget, 0, 1)
	local logPart = math.log10(1 + 999 * p) / 3
	return math.clamp(0.5 * logPart + 0.5 * p, 0, 1)
end

local function resetGiftProgress()
	giftStage = 0
	giftFill.Size = UDim2.fromScale(0, 1)
	giftFill.BackgroundColor3 = Kit.Colors.Yellow
	giftMessage.Visible = false
	giftIcon.Rotation = 0
end

local function updateGiftProgress(distance: number)
	local p = distance / giftTarget
	giftFill.Size = UDim2.fromScale(giftBarFraction(distance), 1)
	local stage = if p >= 1 then 3 elseif p >= 0.95 then 2 elseif p >= 0.8 then 1 else 0
	local left = FormatNumber.Commas(math.max(1, math.ceil(giftTarget - distance)))
	if stage == 1 then
		giftMessage.Text = "Almost there! " .. left .. " studs to the " .. giftTargetName .. "!"
	elseif stage == 2 then
		giftMessage.Text = "SO CLOSE! Just " .. left .. " more studs!"
	elseif stage == 3 then
		giftMessage.Text = string.upper(giftTargetName) .. "!!!"
	end
	if stage ~= giftStage then
		-- nový stupeň: barva, zvětšení a krátký „pop“
		giftStage = stage
		giftMessage.Visible = stage > 0
		giftMessage.TextColor3 = if stage == 1 then Kit.Colors.Yellow elseif stage == 2 then Kit.Colors.Pink else Kit.Colors.Green
		giftFill.BackgroundColor3 = if stage >= 2 then Kit.Colors.Pink elseif stage == 1 then Kit.Colors.Orange else Kit.Colors.Yellow
		if stage > 0 then
			Kit.Pop(giftMessage, 1.4)
			Kit.Pop(giftIcon, 1.6)
		end
	end
	-- dárek se vrtí, čím blíž, tím víc
	giftIcon.Rotation = if stage > 0 then math.sin(os.clock() * (8 + stage * 4)) * (6 + stage * 5) else 0
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
	cameraBase = nil
	Effects.SetSpeed(0)
	Sound.SetLoop("Wind", false)
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
	Net.Event("FlightLanded"):FireServer(state.Id, state.CollectedCoins, state.CollectedRings, state.CollectedGems, state.PoppedBalloons)
	Sound.Play("Splash")
	Sound.SetLoop("Wind", false)
	Effects.SetSpeed(0)
	-- velké šplouchnutí s vlnami a otřes podle délky skoku (100 studů → 0, 100 000 → 1)
	local power = math.clamp((math.log10(math.max(state.FinalDistance, 100)) - 2) / 3, 0, 1)
	local land = state.LandPosition
	if land and state.FinalDistance < (state.Info.GiftAt or World.GiftDistance) then
		Effects.LandingSplash(Vector3.new(land.X, World.WaterY, land.Z), power)
	end
	Effects.Shake(0.3 + power * 0.3)
	Effects.FovKick(-6)
end

local function startFlight(info: { [string]: any })
	giftTarget = if typeof(info.GiftAt) == "number" then info.GiftAt else World.GiftDistance
	bestBefore = ClientState.Get().BestJump or 0
	giftTargetName = "Giant Gift"
	if typeof(info.GiftName) == "string" then
		-- "BRONZE GIFT" → "Bronze Gift"
		local words = {}
		for word in string.gmatch(info.GiftName, "%S+") do
			table.insert(words, string.upper(string.sub(word, 1, 1)) .. string.lower(string.sub(word, 2)))
		end
		giftTargetName = table.concat(words, " ")
	end
	awaitingFlight = false
	charging = false
	destroyMeter()
	if flight then
		if flight.Slalom then
			Slalom.Destroy(flight.Slalom)
		end
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
	local gems: { Gem } = {}
	if typeof(info.Diamonds) == "table" then
		for _, d in info.Diamonds do
			table.insert(gems, { Id = d.Id, Position = d.Position, Type = d.Type, Part = diamondModel(d.Position, d.Type, folder), Taken = false })
		end
	end
	local balloons: { Balloon } = {}
	if typeof(info.Balloons) == "table" then
		for _, b in info.Balloons do
			table.insert(balloons, { Id = b.Id, Position = b.Position, Part = balloonModel(b.Position, folder), Taken = false })
		end
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
		Gems = gems,
		CollectedGems = {},
		GemDistanceBonus = 0,
		Balloons = balloons,
		PoppedBalloons = {},
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
		Chasers = {},
		Slalom = nil,
		OnRaft = false,
		ExpectedPosition = nil,
	}
	flight = state
	setInZone(false)
	setCharacterFlying(true)
	HUD.SetVisible(false)
	flightHud.Visible = true
	coinsLabel.Text = "Coins: 0"
	ringsLabel.Text = "⭕ 0"
	gemsLabel.Text = "💎 0"
	gemsLabel.Visible = #gems > 0
	resetGiftProgress()
	steerHint.Visible = true
	task.delay(2.5, function()
		steerHint.Visible = false
	end)
	Sound.Play("Takeoff")
	if info.Tier == "Perfect" then
		Effects.BigText("PERFECT!", Kit.Colors.Green, 1.1)
		Effects.ScreenConfetti(60)
		Sound.Play("Perfect")
		Effects.Shake(0.45)
		Effects.FovKick(16)
	elseif info.Tier == "Good" then
		Effects.BigText("GOOD!", Kit.Colors.Yellow, 0.9)
		Sound.Play("Good")
		Effects.Shake(0.2)
		Effects.FovKick(12)
	else
		Effects.FovKick(9)
	end
	Sound.SetLoop("Wind", true, 0.3)
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
		-- FOV se roztahuje plynule v applyCamera (+ rána z Effects.FovKick)
		cameraBase = camera.CFrame
		flightFov = camera.FieldOfView
		flightFovTarget = Jump.Flight.CameraFlightFov
	end
end

-- ===== Plavání zpět (vor a žralok) =====

local swimHud: Frame
local swimBarYou: Frame
local swimBarShark: TextLabel
local swimHint: TextLabel
local dangerVignette: CanvasGroup
local lastBeat = 0
local lastDangerText = 0

-- Žraločí alarm: červené okraje obrazovky a tlukot srdce, čím blíž pronásledovatel je (0–1)
local function setDanger(danger: number)
	if danger < 0.05 then
		dangerVignette.Visible = false
		return
	end
	local now = os.clock()
	dangerVignette.Visible = true
	local pulse = 0.75 + 0.25 * math.sin(now * (4 + danger * 8))
	dangerVignette.GroupTransparency = 1 - (0.2 + 0.6 * danger) * pulse
	local interval = 0.95 - 0.6 * danger
	if danger > 0.12 and now - lastBeat > interval then
		lastBeat = now
		Sound.Play("Heartbeat", 1 + danger * 0.3)
		task.delay(0.17, function()
			Sound.Play("Heartbeat", 0.85 + danger * 0.2)
		end)
		if danger > 0.7 then
			Sound.Play("DangerBeep", 1 + danger * 0.4)
		end
	end
end

local function raftModel(position: Vector3, parent: Instance, treasure: boolean?): Model
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
	if treasure then
		-- truhla s pokladem na voru 2 a 3 (svítí a třpytí se)
		local chestCF = CFrame.new(position + Vector3.new(-3.5, 2.3, -2.5))
		add(Vector3.new(3, 1.8, 2.2), chestCF, Color3.fromRGB(150, 95, 45), Enum.Material.Wood)
		add(Vector3.new(3.1, 0.35, 2.3), chestCF * CFrame.new(0, 0.4, 0), Color3.fromRGB(255, 200, 40), Enum.Material.Metal)
		local lid = add(Vector3.new(3, 0.9, 2.2), chestCF * CFrame.new(0, 1.35, 0), Color3.fromRGB(170, 110, 55), Enum.Material.Wood)
		local gold = add(Vector3.new(2.6, 0.5, 1.8), chestCF * CFrame.new(0, 0.95, 0), Color3.fromRGB(255, 220, 70), Enum.Material.Neon)
		local sparkle = Instance.new("Sparkles")
		sparkle.SparkleColor = Color3.fromRGB(255, 230, 120)
		sparkle.Parent = gold
		local _ = lid
	end
	m.Parent = parent
	return m
end

-- ===== Pronásledovatelé z dílů (žralok, velryba, dva žraloci, chobotnice, kraken, megalodon) =====
-- Každý tvor je Model z ukotvených dílů s neviditelným kořenem (PrimaryPart) v počátku.
-- Tvor pluje ve směru -Z. Díly patří do "segmentů" (Body, Rear, Tail, Jaw, chapadla…);
-- animace spočítá CFrame každého segmentu a všechny díly přesune najednou přes BulkMoveTo.
-- Model se staví v jednotkovém měřítku a rigAdd vše násobí rig.Scale (větší tvorové = větší model).
type RigPart = { Part: BasePart, Offset: CFrame, Seg: string }
-- chapadlo = řetěz segmentů; každý kloub se ohýbá kolem osy Axis (už v měřítku rigu)
type Tentacle = { Segs: { string }, Joints: { Vector3 }, Axis: Vector3, Phase: number, Amp: number, Rising: boolean }
type ChaserRig = {
	Kind: string,
	Root: BasePart,
	Parts: { RigPart },
	Teeth: { BasePart },
	Attack: number,
	TeethShown: boolean,
	Scale: number,
	Shift: CFrame, -- posun modelu vůči bodu, kde je pronásledovatel (do strany / výš / dozadu)
	Phase: number, -- posun fáze animace (dva žraloci se nehýbou stejně)
	Clock: number, -- nastřádaný čas animace (tempo se mění plynule, bez skoků při útoku)
	Tentacles: { Tentacle },
	Spout: ParticleEmitter?,
	NextSpout: number,
}

local chaserRigs: { [Model]: ChaserRig } = setmetatable({}, { __mode = "k" }) :: any

local function newRig(kind: string, scale: number, parent: Instance): (Model, ChaserRig)
	local m = Instance.new("Model")
	m.Name = kind
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Transparency = 1
	root.Size = Vector3.new(1, 1, 1)
	root.CFrame = CFrame.identity
	root.Parent = m
	m.PrimaryPart = root
	local rig: ChaserRig = {
		Kind = kind,
		Root = root,
		Parts = {},
		Teeth = {},
		Attack = 0,
		TeethShown = true,
		Scale = scale,
		Shift = CFrame.identity,
		Phase = math.random() * 6,
		Clock = 0,
		Tentacles = {},
		Spout = nil,
		NextSpout = 0,
	}
	chaserRigs[m] = rig
	m.Parent = parent
	return m, rig
end

-- díl rigu; pozice i rozměr se násobí měřítkem rigu
local function rigAdd(m: Model, rig: ChaserRig, className: string, size: Vector3, cf: CFrame, color: Color3, seg: string): BasePart
	local k = rig.Scale
	local offset = CFrame.new(cf.Position * k) * cf.Rotation
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size * k
	p.CFrame = offset
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = m
	table.insert(rig.Parts, { Part = p, Offset = offset, Seg = seg })
	return p
end

-- elipsoid = blok + SpecialMesh koule (koule se roztáhne na celý rozměr dílu)
local function rigEllipsoid(m: Model, rig: ChaserRig, size: Vector3, cf: CFrame, color: Color3, seg: string): BasePart
	local p = rigAdd(m, rig, "Part", size, cf, color, seg)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function rigBall(m: Model, rig: ChaserRig, diameter: number, position: Vector3, color: Color3, seg: string): Part
	local p = rigAdd(m, rig, "Part", Vector3.new(diameter, diameter, diameter), CFrame.new(position), color, seg) :: Part
	p.Shape = Enum.PartType.Ball
	return p
end

-- svítící díl (oči megalodona a krakena)
local function makeGlow(p: BasePart, color: Color3, range: number)
	p.Material = Enum.Material.Neon
	p.Color = color
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = 2
	light.Parent = p
end

-- otočení kolem kloubu (v souřadnicích modelu)
local function aroundHinge(hinge: Vector3, rotation: CFrame): CFrame
	return CFrame.new(hinge) * rotation * CFrame.new(-hinge)
end

-- ---- Žralok (a megalodon = velký tmavý žralok se svítícíma očima) ----
-- Torpédové tělo z elipsoidů, šedomodrý hřbet a bílé břicho, vysoká hřbetní ploutev,
-- prsní ploutve, srpovitá ocasní ploutev, žábry, oči a tlama se zuby (~37 dílů).
-- Tělo je posunuté pod kořen, takže u hladiny čouhá z vody hlavně hřbetní ploutev.
type SharkLook = { Kind: string, Scale: number, Top: Color3, Fin: Color3, Belly: Color3, Glow: Color3?, Shift: CFrame }

local SHARK_Y = -1.9 -- výška osy těla pod kořenem
local SHARK_REAR_HINGE = Vector3.new(0, SHARK_Y, 2)
local SHARK_TAIL_HINGE = Vector3.new(0, SHARK_Y + 0.15, 6.7)
local SHARK_JAW_HINGE = Vector3.new(0, SHARK_Y - 0.8, -3.2)
local SHARK_FIN_HINGE = Vector3.new(1.4, SHARK_Y - 0.75, -1.6)

local SHARK_LOOK: SharkLook = {
	Kind = "Shark",
	Scale = 1,
	Top = Color3.fromRGB(92, 112, 134), -- šedomodrý hřbet
	Fin = Color3.fromRGB(80, 98, 120),
	Belly = Color3.fromRGB(236, 238, 240), -- světlé břicho (protistínování)
	Glow = nil,
	Shift = CFrame.identity,
}
-- megalodon: 2,3× větší, tmavý, svítící oči; posunutý dozadu, aby čenich byl tam, kde u žraloka,
-- a trochu do strany, aby velká ploutev nezakrývala hráče z kamery
local MEGALODON_LOOK: SharkLook = {
	Kind = "Megalodon",
	Scale = 2.3,
	Top = Color3.fromRGB(52, 60, 74),
	Fin = Color3.fromRGB(40, 46, 58),
	Belly = Color3.fromRGB(196, 202, 210),
	Glow = Color3.fromRGB(255, 90, 40),
	Shift = CFrame.new(-4, 0.9, 10),
}

local function sharkModel(parent: Instance, look: SharkLook?): Model
	local style = look or SHARK_LOOK
	local m, rig = newRig(style.Kind, style.Scale, parent)
	rig.Shift = style.Shift
	local top = style.Top
	local finColor = style.Fin
	local belly = style.Belly
	local yc = SHARK_Y

	local function add(className: string, size: Vector3, cf: CFrame, color: Color3, seg: string): BasePart
		return rigAdd(m, rig, className, size, cf, color, seg)
	end
	local function ellipsoid(size: Vector3, position: Vector3, color: Color3, seg: string): BasePart
		return rigEllipsoid(m, rig, size, CFrame.new(position), color, seg)
	end
	-- tenký proužek mezi dvěma body (žábry)
	local function strip(a: Vector3, b: Vector3, thickness: number, color: Color3, seg: string): BasePart
		return add("Part", Vector3.new(thickness, thickness, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, seg)
	end
	-- šířka středního elipsoidu těla v dané výšce a hloubce (aby žábry seděly na povrchu)
	local function midHalfWidth(y: number, z: number): number
		local ry = (y - yc) / 1.65
		local rz = (z + 0.4) / 4
		return 1.9 * math.sqrt(math.max(0, 1 - ry * ry - rz * rz))
	end

	-- tělo: čenich → hlava → trup → zadek → ocasní násadec (zužuje se jako torpédo)
	ellipsoid(Vector3.new(2, 1.6, 3.6), Vector3.new(0, yc + 0.25, -5.9), top, "Body")
	ellipsoid(Vector3.new(3.2, 2.4, 6), Vector3.new(0, yc + 0.3, -3.4), top, "Body")
	ellipsoid(Vector3.new(3.8, 3.3, 8), Vector3.new(0, yc, -0.4), top, "Body")
	ellipsoid(Vector3.new(2.6, 2.3, 6), Vector3.new(0, yc + 0.05, 3), top, "Rear")
	ellipsoid(Vector3.new(1.2, 1.3, 4), Vector3.new(0, yc + 0.15, 5.6), top, "Rear")
	-- bílé břicho trochu níž, aby vykukovalo zespodu a po bocích
	ellipsoid(Vector3.new(2.6, 2, 4.4), Vector3.new(0, yc - 0.75, -1.4), belly, "Body")
	ellipsoid(Vector3.new(3.3, 2.6, 8), Vector3.new(0, yc - 0.65, 0.6), belly, "Body")
	ellipsoid(Vector3.new(2, 1.4, 5), Vector3.new(0, yc - 0.5, 3.8), belly, "Rear")

	-- vysoká trojúhelníková hřbetní ploutev (přední šikmá hrana + krátká zadní)
	add("WedgePart", Vector3.new(0.3, 3.4, 2.8), CFrame.new(0, yc + 3.1, -0.2), finColor, "Body")
	add("WedgePart", Vector3.new(0.3, 3.4, 0.7), CFrame.new(0, yc + 3.1, 1.55) * CFrame.Angles(0, math.pi, 0), finColor, "Body")
	-- malá druhá hřbetní a řitní ploutev u ocasu
	add("WedgePart", Vector3.new(0.2, 0.7, 0.8), CFrame.new(0, yc + 1.1, 4.6), finColor, "Rear")
	add("WedgePart", Vector3.new(0.2, 0.6, 0.8), CFrame.new(0, yc - 0.75, 4.4) * CFrame.Angles(0, 0, math.pi), finColor, "Rear")

	-- prsní ploutve: tenké trojúhelníky do stran, mírně dolů a dozadu
	for _, side in { -1, 1 } do
		local hinge = Vector3.new(side * SHARK_FIN_HINGE.X, SHARK_FIN_HINGE.Y, SHARK_FIN_HINGE.Z)
		local cf = CFrame.new(hinge) * CFrame.Angles(0, 0, -side * math.rad(110)) * CFrame.Angles(math.rad(25), 0, 0) * CFrame.new(0, 1.6, 0)
		add("WedgePart", Vector3.new(0.2, 3.2, 2.2), cf, finColor, if side < 0 then "FinL" else "FinR")
	end

	-- srpovitá ocasní ploutev: delší horní a kratší dolní lalok, vnitřní hrany tvoří vidlici
	add("WedgePart", Vector3.new(0.22, 3.6, 1.6), CFrame.new(0, yc + 0.25, 6.9) * CFrame.Angles(math.rad(48), 0, 0) * CFrame.new(0, 1.8, 0), finColor, "Tail")
	add("WedgePart", Vector3.new(0.22, 2.4, 1.3), CFrame.new(0, yc + 0.05, 6.9) * CFrame.Angles(math.rad(125), 0, 0) * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, 1.2, 0), finColor, "Tail")

	-- žaberní štěrbiny (4 na každé straně)
	local gill = Color3.fromRGB(45, 55, 68)
	for _, side in { -1, 1 } do
		for i = 0, 3 do
			local z = -2.4 + i * 0.35
			local a = Vector3.new(side * (midHalfWidth(yc + 0.55, z) + 0.02), yc + 0.55, z)
			local b = Vector3.new(side * (midHalfWidth(yc - 0.45, z + 0.15) + 0.02), yc - 0.45, z + 0.15)
			strip(a, b, 0.1, gill, "Body")
		end
	end

	-- oči: u žraloka malá černá lesklá, u megalodona větší a svítící
	for _, side in { -1, 1 } do
		local eye = rigBall(m, rig, if style.Glow then 0.6 else 0.42, Vector3.new(side * 1.35, yc + 0.45, -4.7), Color3.fromRGB(12, 12, 16), "Body")
		eye.Reflectance = 0.3
		local glow = style.Glow
		if glow then
			eye.Reflectance = 0
			makeGlow(eye, glow, 10)
		end
	end

	-- tlama: tmavá linka (vnitřek tlamy) mezi hlavou a bílou dolní čelistí
	ellipsoid(Vector3.new(1.7, 0.3, 2.6), Vector3.new(0, yc - 0.8, -4.6), Color3.fromRGB(90, 25, 35), "Body")
	ellipsoid(Vector3.new(2, 0.6, 2.6), Vector3.new(0, yc - 1.05, -4.4), belly, "Jaw")
	-- zuby: horní řada visí dolů, dolní stojí na čelisti; ukážou se, až je žralok blízko
	local white = Color3.fromRGB(250, 250, 245)
	for _, u in { -1, -0.33, 0.33, 1 } do
		local cf = CFrame.new(0.6 * math.sin(u), yc - 0.78, -4.4 - 0.95 * math.cos(u)) * CFrame.Angles(0, u, 0) * CFrame.Angles(math.pi, 0, 0)
		table.insert(rig.Teeth, add("WedgePart", Vector3.new(0.1, 0.32, 0.18), cf, white, "Body"))
	end
	for _, u in { -0.7, 0, 0.7 } do
		local cf = CFrame.new(0.55 * math.sin(u), yc - 0.72, -4.4 - 0.9 * math.cos(u)) * CFrame.Angles(0, u, 0)
		table.insert(rig.Teeth, add("WedgePart", Vector3.new(0.1, 0.28, 0.18), cf, white, "Jaw"))
	end
	return m
end

-- ---- Velryba: velké modré tělo, bílé břicho, vodorovná ocasní ploutev, gejzír z nozder (~24 dílů) ----
local WHALE_REAR_HINGE = Vector3.new(0, -2.1, 3)
local WHALE_TAIL_HINGE = Vector3.new(0, -1.7, 8.2)
local WHALE_FIN_HINGE = Vector3.new(2.9, -3.3, -2.6)
local WHALE_JAW_HINGE = Vector3.new(0, -3, -3.5)

local function whaleModel(parent: Instance): Model
	local m, rig = newRig("Whale", 1.15, parent)
	-- celá velryba je za bodem pronásledování, aby tlama byla zhruba tam, kde u žraloka čenich
	rig.Shift = CFrame.new(0, 0.8, 4)
	local blue = Color3.fromRGB(70, 125, 205)
	local dark = Color3.fromRGB(45, 85, 160)
	local belly = Color3.fromRGB(235, 242, 250)
	local function ell(size: Vector3, position: Vector3, color: Color3, seg: string): BasePart
		return rigEllipsoid(m, rig, size, CFrame.new(position), color, seg)
	end
	-- hlava a trup (hřbet těsně nad hladinou)
	ell(Vector3.new(6, 5, 8.5), Vector3.new(0, -2, -5.6), blue, "Body")
	ell(Vector3.new(7, 5.6, 10), Vector3.new(0, -2.2, 0), blue, "Body")
	ell(Vector3.new(5.6, 3.4, 12), Vector3.new(0, -3.5, -2.5), belly, "Body")
	-- spodní čelist (bílá, otevře se při útoku)
	ell(Vector3.new(4.8, 2, 6.5), Vector3.new(0, -3.8, -6.8), belly, "Jaw")
	-- úsměv: tmavé linky tlamy po stranách
	for _, side in { -1, 1 } do
		local a = Vector3.new(side * 2.55, -3, -9.4)
		local b = Vector3.new(side * 3.25, -2.6, -4.2)
		rigAdd(m, rig, "Part", Vector3.new(0.2, 0.2, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), dark, "Body")
	end
	-- velké přátelské oči (bílé oko + černá zornička + odlesk)
	for _, side in { -1, 1 } do
		rigBall(m, rig, 1.1, Vector3.new(side * 2.6, -1, -4.4), Color3.fromRGB(250, 250, 250), "Body")
		local pupil = rigBall(m, rig, 0.6, Vector3.new(side * 2.98, -1, -4.6), Color3.fromRGB(15, 15, 25), "Body")
		pupil.Reflectance = 0.25
	end
	-- nozdra na temeni + malá hřbetní ploutev
	local blowhole = ell(Vector3.new(0.9, 0.35, 0.6), Vector3.new(0, 0.55, -4.3), dark, "Body")
	rigAdd(m, rig, "WedgePart", Vector3.new(0.5, 1.1, 2.2), CFrame.new(0, 0.8, 3.2), dark, "Rear")
	-- prsní ploutve (dlouhé, do stran)
	for _, side in { -1, 1 } do
		local hinge = Vector3.new(side * WHALE_FIN_HINGE.X, WHALE_FIN_HINGE.Y, WHALE_FIN_HINGE.Z)
		local cf = CFrame.new(hinge) * CFrame.Angles(0, -side * 0.35, -side * 0.45) * CFrame.new(side * 2.2, 0, 0)
		rigEllipsoid(m, rig, Vector3.new(4.8, 0.45, 1.7), cf, dark, if side < 0 then "FinL" else "FinR")
	end
	-- zadek a ocasní násadec
	ell(Vector3.new(5, 4.2, 7), Vector3.new(0, -2.05, 5.8), blue, "Rear")
	ell(Vector3.new(3.6, 2.4, 6), Vector3.new(0, -3, 5.4), belly, "Rear")
	ell(Vector3.new(2.6, 2.2, 6), Vector3.new(0, -1.7, 10.2), blue, "Tail")
	-- vodorovná ocasní ploutev (dva laloky do stran + střed)
	for _, side in { -1, 1 } do
		local cf = CFrame.new(side * 2.3, -1.5, 13.4) * CFrame.Angles(0, side * 0.45, 0)
		rigEllipsoid(m, rig, Vector3.new(5.2, 0.5, 2.6), cf, dark, "Tail")
	end
	ell(Vector3.new(1.6, 0.6, 2), Vector3.new(0, -1.55, 12.6), dark, "Tail")
	-- gejzír z nozder: kapky vystřelí nahoru a spadnou zpátky
	local spout = Instance.new("ParticleEmitter")
	spout.Texture = "rbxasset://textures/particles/smoke_main.dds"
	spout.Color = ColorSequence.new(Color3.fromRGB(235, 250, 255), Color3.fromRGB(170, 220, 255))
	spout.LightEmission = 0.3
	spout.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3) })
	spout.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	spout.Lifetime = NumberRange.new(0.8, 1.2)
	spout.Speed = NumberRange.new(22, 30)
	spout.SpreadAngle = Vector2.new(10, 10)
	spout.Acceleration = Vector3.new(0, -35, 0)
	spout.EmissionDirection = Enum.NormalId.Top
	spout.Rate = 0
	spout.Parent = blowhole
	rig.Spout = spout
	return m
end

-- ---- Chobotnice a kraken: kulatá hlava, velké oči, vlnící se chapadla ----
-- Chobotnice (~41 dílů): fialová, 8 chapadel po 4 článcích kolem hlavy.
-- Kraken (~43 dílů): větší, tmavě červený s tyrkysovými skvrnami, svítící žluté oči,
-- 6 chapadel pod hlavou a 4 obří chapadla, která se zvedají z vody kolem hráče.
local function octopusModel(parent: Instance, kraken: boolean): Model
	local m, rig = newRig(if kraken then "Kraken" else "Octopus", if kraken then 1.9 else 1.4, parent)
	-- hlava hlouběji ve vodě (ať nezakrývá hráče), chapadla vepředu sahají k hráči
	rig.Shift = if kraken then CFrame.new(0, -0.6, 3) else CFrame.new(0, -0.4, 1.5)
	local k = rig.Scale
	local head = if kraken then Color3.fromRGB(150, 30, 50) else Color3.fromRGB(170, 70, 205)
	local spot = if kraken then Color3.fromRGB(40, 200, 180) else Color3.fromRGB(225, 140, 240)
	local arm = if kraken then Color3.fromRGB(125, 25, 45) else Color3.fromRGB(150, 60, 190)
	local tip = if kraken then Color3.fromRGB(40, 170, 160) else Color3.fromRGB(240, 160, 230)

	-- hlava (plášť) nakloněná dozadu + spodní část hlavy
	rigEllipsoid(m, rig, Vector3.new(5, 6, 5.5), CFrame.new(0, 1.3, 1.1) * CFrame.Angles(math.rad(-25), 0, 0), head, "Body")
	rigEllipsoid(m, rig, Vector3.new(4.6, 2.8, 4.6), CFrame.new(0, -0.9, 0), head, "Body")
	-- skvrny na hlavě
	for _, s in { Vector3.new(1.5, 2.6, 1.6), Vector3.new(-1.3, 3, 2.1), Vector3.new(0.2, 3.6, 2.8) } do
		rigEllipsoid(m, rig, Vector3.new(1.1, 1.1, 0.6), CFrame.lookAt(s, s * 2), spot, "Body")
	end
	-- velké oči po stranách hlavy (vidět i z kamery za hráčem)
	for _, side in { -1, 1 } do
		local eyePos = Vector3.new(side * 1.75, 1, -1.2)
		local white = rigBall(m, rig, 1.7, eyePos, if kraken then Color3.fromRGB(255, 215, 60) else Color3.fromRGB(250, 250, 250), "Body")
		if kraken then
			makeGlow(white, Color3.fromRGB(255, 215, 60), 12)
			-- svislá zornička
			rigEllipsoid(m, rig, Vector3.new(0.35, 1.2, 0.5), CFrame.new(eyePos + Vector3.new(side * 0.55, 0, -0.45)), Color3.fromRGB(20, 10, 15), "Body")
		else
			local pupil = rigBall(m, rig, 0.85, eyePos + Vector3.new(side * 0.5, 0.05, -0.5), Color3.fromRGB(15, 10, 25), "Body")
			pupil.Reflectance = 0.25
		end
	end

	-- chapadla pod hlavou: řetěz článků od hlavy ven, konce se stáčejí nahoru
	local lowerCount = if kraken then 6 else 8
	local segCount = if kraken then 3 else 4
	for i = 1, lowerCount do
		local angle = (i - 0.5) / lowerCount * math.pi * 2
		local dir = Vector3.new(math.sin(angle), 0, -math.cos(angle))
		local tentacle: Tentacle = { Segs = {}, Joints = {}, Axis = Vector3.new(-dir.Z, 0, dir.X), Phase = i * 0.9, Amp = 0.32, Rising = false }
		local start = dir * 1.6 + Vector3.new(0, -0.7, 0)
		for j = 1, segCount do
			local length = 1.9 - j * 0.2
			local width = 1.25 - j * 0.2
			-- první články skoro vodorovně, konec se stáčí nahoru
			local rise = 0.8 * ((j - 1) / (segCount - 1)) ^ 1.5 - 0.05
			local a = start
			local b = a + dir * length + Vector3.new(0, rise, 0)
			local seg = "T" .. i .. "_" .. j
			rigEllipsoid(m, rig, Vector3.new(width, width * 0.85, length + 0.5), CFrame.lookAt((a + b) / 2, b), if j == segCount then tip else arm, seg)
			table.insert(tentacle.Segs, seg)
			table.insert(tentacle.Joints, a * k)
			start = b
		end
		table.insert(rig.Tentacles, tentacle)
	end

	-- kraken: obří chapadla vystupující z vody po stranách (a trochu před ním)
	if kraken then
		local spots = { Vector3.new(-6.5, -1.2, -3.5), Vector3.new(6.5, -1.2, -3.5), Vector3.new(-5.5, -1.2, 3), Vector3.new(5.5, -1.2, 3) }
		for i, base in spots do
			local side = if base.X < 0 then -1 else 1
			local tentacle: Tentacle = { Segs = {}, Joints = {}, Axis = Vector3.zAxis, Phase = i * 1.3, Amp = 0.22, Rising = true }
			local start = base
			for j = 1, 4 do
				local length = 2.1 - j * 0.15
				local width = 1.5 - j * 0.25
				-- nahoru a na konci zahnuté dovnitř (k hráči)
				local b = start + Vector3.new(-side * (j - 1) * 0.35, length, 0)
				local seg = "R" .. i .. "_" .. j
				rigEllipsoid(m, rig, Vector3.new(width, length + 0.5, width), CFrame.new((start + b) / 2) * CFrame.Angles(0, 0, side * (j - 1) * 0.17), if j == 4 then tip else arm, seg)
				table.insert(tentacle.Segs, seg)
				table.insert(tentacle.Joints, start * k)
				start = b
			end
			table.insert(rig.Tentacles, tentacle)
		end
	end
	return m
end

-- Postaví pronásledovatele pro daný tier (klíč z Config/Swim → Chasers); neznámý klíč = žralok
local function chaserModels(key: string, parent: Instance): { Model }
	if key == "Whale" then
		return { whaleModel(parent) }
	elseif key == "TwoSharks" then
		local first = table.clone(SHARK_LOOK)
		first.Shift = CFrame.new(3.5, 0, 0)
		local second = table.clone(SHARK_LOOK)
		second.Top = Color3.fromRGB(78, 98, 122)
		second.Shift = CFrame.new(-4, 0, 5)
		return { sharkModel(parent, first), sharkModel(parent, second) }
	elseif key == "Octopus" then
		return { octopusModel(parent, false) }
	elseif key == "Kraken" then
		return { octopusModel(parent, true) }
	elseif key == "Megalodon" then
		return { sharkModel(parent, MEGALODON_LOOK) }
	end
	return { sharkModel(parent, nil) }
end

-- Animace pronásledovatele (volá se po nastavení kořene): vlnění těla, ocas, ploutve, chapadla.
-- Když je blízko hráče, "zaútočí" – žralok vynoří hlavu a ukáže zuby, velryba otevře tlamu,
-- chobotnice natáhne chapadla.
local function animateChaser(model: Model, target: Vector3, dt: number)
	local rig = chaserRigs[model]
	if not rig then
		return
	end
	local k = rig.Scale
	local root = rig.Root.CFrame
	local distance = (root.Position - target).Magnitude
	local want = math.clamp((14 * k - distance) / (8 * k), 0, 1)
	rig.Attack += (want - rig.Attack) * (1 - math.exp(-dt * 6))
	local a = rig.Attack
	local now = os.clock() + rig.Phase
	-- tempo vlnění se mění s útokem; čas se proto střádá po snímcích (now * tempo by při změně
	-- tempa skákal o stovky radiánů a tvor by sebou házel)
	local function advance(rate: number): number
		rig.Clock += dt * rate
		return rig.Clock + rig.Phase
	end
	local frames: { [string]: CFrame } = {}
	local kind = rig.Kind

	if kind == "Shark" or kind == "Megalodon" then
		local t = advance((6 + a * 4) / math.sqrt(k))
		local base = root * CFrame.new(0, a * 1.1 * k, 0) * CFrame.Angles(a * 0.28, 0, 0)
		local body = base * CFrame.Angles(0, 0.06 * math.sin(t + 0.8), 0)
		local rear = body * aroundHinge(SHARK_REAR_HINGE * k, CFrame.Angles(0, 0.2 * math.sin(t - 0.9), 0))
		local tail = rear * aroundHinge(SHARK_TAIL_HINGE * k, CFrame.Angles(0, 0.45 * math.sin(t - 1.9), 0))
		-- megalodon má tlamu pořád pootevřenou a cvaká
		local idle = if kind == "Megalodon" then 0.18 + 0.1 * math.sin(now * 3) else 0
		local gape = idle + a * 0.55 + a * 0.12 * math.sin(now * 9)
		local jaw = body * aroundHinge(SHARK_JAW_HINGE * k, CFrame.Angles(-gape, 0, 0))
		local flap = 0.12 * math.sin(t * 0.5)
		local finHinge = SHARK_FIN_HINGE * k
		frames.Body = body
		frames.Rear = rear
		frames.Tail = tail
		frames.Jaw = jaw
		frames.FinL = body * aroundHinge(Vector3.new(-finHinge.X, finHinge.Y, finHinge.Z), CFrame.Angles(0, 0, flap))
		frames.FinR = body * aroundHinge(finHinge, CFrame.Angles(0, 0, -flap))
	elseif kind == "Whale" then
		-- velryba plave vlněním nahoru a dolů (ocas mává svisle)
		local t = advance(3.2 + a * 1.5)
		local base = root * CFrame.new(0, a * 1.2 * k + 0.3 * math.sin(t * 0.5), 0) * CFrame.Angles(a * 0.15, 0, 0)
		local body = base * CFrame.Angles(0.03 * math.sin(t + 0.6), 0, 0)
		local rear = body * aroundHinge(WHALE_REAR_HINGE * k, CFrame.Angles(0.12 * math.sin(t - 0.8), 0, 0))
		local tail = rear * aroundHinge(WHALE_TAIL_HINGE * k, CFrame.Angles(0.4 * math.sin(t - 1.8), 0, 0))
		local finHinge = WHALE_FIN_HINGE * k
		local flap = 0.25 * math.sin(t * 0.8)
		frames.Body = body
		frames.Rear = rear
		frames.Tail = tail
		frames.Jaw = body * aroundHinge(WHALE_JAW_HINGE * k, CFrame.Angles(-a * 0.35, 0, 0))
		frames.FinL = body * aroundHinge(Vector3.new(-finHinge.X, finHinge.Y, finHinge.Z), CFrame.Angles(0, 0, flap))
		frames.FinR = body * aroundHinge(finHinge, CFrame.Angles(0, 0, -flap))
		local spout = rig.Spout
		if spout and os.clock() >= rig.NextSpout then
			rig.NextSpout = os.clock() + 2.4 - a
			spout:Emit(28)
		end
	else
		-- chobotnice / kraken: hlava se pohupuje, chapadla se vlní (vlna běží od hlavy ke konci)
		local t = advance(2.6 + a * 2)
		local body = root * CFrame.new(0, (0.35 * math.sin(t * 0.7) + a * 0.8) * k, 0) * CFrame.Angles(0.06 * math.sin(t * 0.7), 0, 0)
		frames.Body = body
		for _, tentacle in rig.Tentacles do
			local frame = body
			for j, seg in tentacle.Segs do
				local wave = math.sin(t + tentacle.Phase - j * 0.9)
				local rotation: CFrame
				if tentacle.Rising then
					-- obří chapadla se kývají a při útoku se nakloní nad hráče
					local lean = if tentacle.Joints[j].X < 0 then -1 else 1
					rotation = CFrame.Angles(tentacle.Amp * math.sin(t * 0.8 + tentacle.Phase - j * 0.7), 0, lean * (tentacle.Amp * wave + a * 0.12))
				else
					-- konce se zvedají z vody, při útoku se chapadla víc natahují
					rotation = CFrame.fromAxisAngle(tentacle.Axis, (tentacle.Amp + a * 0.15) * wave) * CFrame.Angles(0, 0.15 * math.sin(t * 0.6 + tentacle.Phase + j), 0)
				end
				frame = frame * aroundHinge(tentacle.Joints[j], rotation)
				frames[seg] = frame
			end
		end
	end

	local parts: { BasePart } = table.create(#rig.Parts)
	local cframes: { CFrame } = table.create(#rig.Parts)
	for i, entry in rig.Parts do
		parts[i] = entry.Part
		cframes[i] = (frames[entry.Seg] or root) * entry.Offset
	end
	Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	-- zuby: žralok je ukáže až zblízka, megalodon pořád
	if #rig.Teeth > 0 then
		local show = a > 0.25 or kind == "Megalodon"
		if show ~= rig.TeethShown then
			rig.TeethShown = show
			for _, tooth in rig.Teeth do
				tooth.Transparency = if show then 0 else 1
			end
		end
	end
end

local function startSwim(info: { [string]: any })
	local state = flight
	if not state or state.Phase == "Returned" then
		return
	end
	state.Phase = "Swim"
	-- další vor: uklidit pronásledovatele a slalom z minulého úseku
	for _, old in state.Chasers do
		old:Destroy()
	end
	if state.Slalom then
		Slalom.Destroy(state.Slalom)
		state.Slalom = nil
	end
	state.OnRaft = false
	hideRaftChoice()
	-- starý vor (odkud hráč skáče) už nemá svítit "SAFE!" – cílem je nový vor
	for _, old in state.Folder:GetChildren() do
		if old.Name == "Raft" then
			old.Name = "OldRaft"
			for _, d in old:GetDescendants() do
				if d:IsA("BillboardGui") then
					d:Destroy()
				end
			end
		end
	end
	local stage = if typeof(info.Stage) == "number" then info.Stage else 1
	state.SwimInfo = info
	state.SwimStart = os.clock()
	state.SwimProgress = 0
	state.SwimEnded = false
	state.Z = info.StartZ
	-- směr plavání: 1 = ke břehu (−X), −1 = na moře (+X, vory 2 a 3)
	local dir = if info.Dir == -1 then -1 else 1
	info.Dir = dir
	raftModel(Vector3.new(info.StartX - dir * info.Distance, info.Y, info.StartZ), state.Folder, info.Treasure ~= nil)
	-- slalom (od levelu 10): branky a překážky mezi hráčem a vorem
	local slalom = info.Slalom
	local shield = if typeof(info.Shield) == "number" then info.Shield else 0
	state.Slalom = if typeof(slalom) == "table" then Slalom.Start(slalom, info.StartX, info.StartZ, info.Y, state.Folder, dir, shield) else nil
	lastDangerText = os.clock()
	-- kdo honí: tier podle klíče ze serveru (chybí / neznámý → žralok)
	local tier = Formulas.ChaserByKey(info.Chaser)
	info.Tier = tier
	state.Chasers = {}
	if not info.NoShark then
		for _, model in chaserModels(tier.Key, state.Folder) do
			model:PivotTo(CFrame.new(0, -500, 0))
			table.insert(state.Chasers, model)
		end
	end
	swimHud.Visible = true
	swimBarShark.Visible = not info.NoShark
	swimBarShark.Text = tier.Name
	swimBarShark.TextColor3 = tier.Color
	flightHud.Visible = false
	local swimText = if stage > 1 then `SWIM TO RAFT {stage}/{info.MaxStage or 3}!` else "SWIM TO THE RAFT!"
	if stage > 1 then
		Sound.Play("Splash")
		Effects.Splash(Vector3.new(info.StartX, info.Y, info.StartZ), true)
	end
	if info.NoShark then
		Effects.BigText(if info.UsedRepellent then "SHARK REPELLENT! SWIM!" else swimText, Kit.Colors.Turquoise, 1.4, 0.25)
	else
		Effects.BigText(swimText, Kit.Colors.Turquoise, 1.2, 0.25)
		task.delay(info.SharkDelay, function()
			if flight == state and not state.SwimEnded then
				Effects.BigText(tier.Warning, tier.Color, 1.2, 0.3)
				Sound.Play("SharkAlert")
			end
		end)
	end
	if state.Slalom then
		local layout = state.Slalom.Layout
		task.delay(1.3, function()
			if flight == state and not state.SwimEnded then
				Effects.BigText(layout.Name .. "!", layout.Color, 1.3, 0.36)
			end
		end)
		swimHint.Text = layout.Hint or "Steer with A / D (joystick) through the gaps!"
		if state.Slalom.Shield > 0 then
			task.delay(2.4, function()
				if flight == state and not state.SwimEnded then
					Effects.FloatText(`💜 SHIELD x{shield} - {if shield == 1 then "one free bump" else `{shield} free bumps`}!`, Color3.fromRGB(200, 140, 255))
				end
			end)
		end
	else
		swimHint.Text = "Hold W / joystick forward to swim!"
	end
	swimHint.Visible = true
	task.delay(if state.Slalom then 4 else 3, function()
		swimHint.Visible = false
	end)
end

updateSwim = function(state: FlightState, root: BasePart, dt: number)
	local info = state.SwimInfo
	if not info then
		return
	end
	local elapsed = os.clock() - state.SwimStart
	local dir: number = info.Dir or 1
	local ahead = -dir * Vector3.xAxis -- směr k voru
	if not state.SwimEnded then
		if not controls then
			controls = getControls()
		end
		local move = if controls then controls:GetMoveVector() else Vector3.zero
		local forward = math.clamp(-move.Z, 0, 1)
		local run = state.Slalom
		local stunned = run ~= nil and Slalom.Stunned(run)
		if stunned then
			forward = 0 -- po nárazu chvíli nejde plavat dopředu (do stran napůl)
		end
		local steer = (if run then Swim.Slalom.SteerFactor else 0.5) * (if stunned then 0.5 else 1)
		local lane = Swim.Slalom.LaneHalfWidth
		-- doprava na obrazovce = doprava ve světě i při plavání opačným směrem (kamera je vždy za hráčem)
		-- bouřkový slalom: vlny posouvají hráče do stran (střídavě)
		local drift = if run and run.Layout.Drift then run.Layout.Drift * math.sin(elapsed * 0.9) else 0
		state.Z = math.clamp(state.Z - move.X * dir * info.Speed * steer * dt + drift * dt, info.StartZ - lane, info.StartZ + lane)
		local progress = math.min(info.Distance, state.SwimProgress + info.Speed * forward * dt)
		if run then
			progress = Slalom.Resolve(run, elapsed, state.SwimProgress, progress, state.Z - info.StartZ)
		end
		state.SwimProgress = progress
		-- tempa: zvuk a čeření
		if forward > 0.2 and os.clock() - lastStroke > 0.55 then
			lastStroke = os.clock()
			Sound.Play("Swim", 0.9 + math.random() * 0.2)
			Effects.Ripple(Vector3.new(info.StartX - dir * state.SwimProgress, info.Y, state.Z), 0.7)
		end
	end
	if state.Slalom then
		Slalom.Animate(state.Slalom, elapsed)
	end
	local position = Vector3.new(info.StartX - dir * state.SwimProgress, info.Y + 0.4 + math.sin(os.clock() * 6) * 0.15, state.Z)
	if state.OnRaft then
		-- stojí na voru čelem k dalšímu voru (k pláži), kousek vedle vlajky, ať ji nemá před sebou
		position = Vector3.new(info.StartX - dir * info.Distance, info.Y + 4.1, info.StartZ - 2.5) + ahead * 3
		root.CFrame = CFrame.lookAt(position, position + ahead)
	else
		-- plavecká poloha: břichem dolů, hlavou k voru
		root.CFrame = CFrame.lookAt(position, position + ahead) * CFrame.Angles(math.rad(-80), 0, math.sin(os.clock() * 8) * 0.2)
	end
	state.ExpectedPosition = position
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	-- pronásledovatel(é): server počítá jednu pozici, druhý žralok je jen posunutý do strany a dozadu (rig.Shift)
	-- po úspěšném doplavání se pronásledovatel zastaví a zanoří (nehoní hráče na voru)
	local escapedAt = info.EscapedAt
	local chaseElapsed = if typeof(escapedAt) == "number" then math.min(elapsed, escapedAt) else elapsed
	local dive = if typeof(escapedAt) == "number" then math.max(0, elapsed - escapedAt) * 6 else 0
	local sharkProgress = Formulas.SharkProgress(chaseElapsed, info.SharkSpeed)
	-- jak blízko je pronásledovatel (0 = daleko, 1 = těsně za hráčem)
	local danger = 0
	if not info.NoShark and not state.SwimEnded and elapsed >= info.SharkDelay then
		danger = 1 - math.clamp((state.SwimProgress - sharkProgress - 3) / 28, 0, 1)
		-- (ne hned po startu pronásledovatele – tam už svítí jeho vlastní varování)
		if danger > 0.8 and elapsed > info.SharkDelay + 2.5 and os.clock() - lastDangerText > 5 then
			lastDangerText = os.clock()
			local tier = info.Tier or Formulas.ChaserByKey(nil)
			Effects.BigText(`{string.upper(tier.Name)} RIGHT BEHIND YOU!`, Kit.Colors.Coral, 1, 0.5)
		end
	end
	setDanger(danger)
	for _, model in state.Chasers do
		local chaserCFrame: CFrame
		if elapsed < info.SharkDelay then
			-- ploutev se blíží zezadu
			local behind = Vector3.new(info.StartX + dir * (30 - (elapsed / info.SharkDelay) * 30), info.Y - 1.6, state.Z + 6)
			chaserCFrame = CFrame.lookAt(behind, behind + ahead)
		else
			local sx = info.StartX - dir * math.min(sharkProgress, state.SwimProgress + 2)
			-- oba žraloci se vlní stejně (jinak by se o sebe otírali), liší se jen posunem v rig.Shift
			local sharkPos = Vector3.new(sx, info.Y + 0.6 - dive, state.Z + math.sin(os.clock() * 3) * 1.5)
			chaserCFrame = CFrame.lookAt(sharkPos, sharkPos + ahead)
		end
		local rig = chaserRigs[model]
		if rig then
			-- stačí posunout kořen, animace pak přesune všechny díly najednou
			rig.Root.CFrame = chaserCFrame * rig.Shift
			animateChaser(model, position, dt)
		else
			model:PivotTo(chaserCFrame)
		end
	end
	-- ukazatel: ty vs. žralok
	swimBarYou.Size = UDim2.fromScale(math.clamp(state.SwimProgress / info.Distance, 0, 1), 1)
	swimBarShark.Position = UDim2.fromScale(math.clamp(sharkProgress / info.Distance, 0, 1), 0.5)
	-- kamera za hráčem (vidí žraloka i vor)
	local camera = Workspace.CurrentCamera
	if camera then
		-- kamera za hráčem směrem k (dalšímu) voru
		local look = ahead
		local camPos = position - look * 24 + Vector3.new(0, 11, 0)
		flightFovTarget = Jump.Flight.CameraFov + 8
		applyCamera(camera, (cameraBase or camera.CFrame):Lerp(CFrame.lookAt(camPos, position + look * 18 - Vector3.new(0, 2, 0)), 0.15), dt)
	end
end

-- Návrat na pláž po plavání (zatmívačka, úklid). delay = za jak dlouho (server mezitím hráče přesune).
returnToBeach = function(state: FlightState, delay: number)
	task.delay(math.max(0, delay - 0.45), function()
		Effects.Fade(true, 0.35)
	end)
	task.delay(delay + 0.15, function()
		if state.Slalom then
			-- uklidit i tmu/bouřku (filtr v Lighting není ve složce letu)
			Slalom.Destroy(state.Slalom)
			state.Slalom = nil
		end
		if flight == state then
			state.Folder:Destroy()
			flight = nil
		end
		hideRaftChoice()
		swimHud.Visible = false
		setCharacterFlying(false)
		endFlightVisuals()
		Effects.Fade(false, 0.5)
	end)
end

-- Panel na voru: zpět na pláž, nebo skočit do vody a plavat k dalšímu voru
local raftChoice: Frame? = nil
local raftChoiceToken = 0

hideRaftChoice = function()
	raftChoiceToken += 1
	if raftChoice then
		raftChoice:Destroy()
		raftChoice = nil
	end
end

showRaftChoice = function(state: FlightState, result: { [string]: any })
	hideRaftChoice()
	raftChoiceToken += 1
	local token = raftChoiceToken
	local stage = result.Stage or 1
	local maxStage = result.MaxStage or 3
	local panel = Kit.Panel(swimHud, {
		Size = UDim2.fromOffset(560, 230),
		Position = UDim2.new(0.5, 0, 1, -40),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Kit.Colors.Panel,
		Radius = 22,
		StrokeThickness = 4,
	})
	raftChoice = panel
	Kit.Text(panel, { Text = `SAFE ON RAFT {stage}/{maxStage}!`, Size = UDim2.new(1, -24, 0, 44), Position = UDim2.fromOffset(12, 10), TextColor3 = Kit.Colors.Green, StrokeThickness = 3 })
	Kit.Text(panel, {
		Text = `Swim on to treasure raft {stage + 1}: x{result.NextMultiplier or stage + 1} bonus + a treasure chest! The chaser comes back faster…`,
		Size = UDim2.new(1, -30, 0, 46),
		Position = UDim2.fromOffset(15, 56),
		TextColor3 = Kit.Colors.Text,
		NoStroke = true,
	})
	local function choose(goOn: boolean)
		if token ~= raftChoiceToken or flight ~= state then
			return
		end
		Sound.Play("Click")
		hideRaftChoice()
		Net.Event("SwimChoice"):FireServer(goOn)
		if not goOn then
			returnToBeach(state, 0.6)
		end
	end
	local back = Kit.Button(panel, { Text = "BACK TO BEACH", Size = UDim2.new(0.5, -24, 0, 70), Position = UDim2.new(0, 16, 1, -86), Color = Kit.Colors.Turquoise })
	back.Activated:Connect(function()
		choose(false)
	end)
	local onward = Kit.Button(panel, { Text = "SWIM ON!", Size = UDim2.new(0.5, -24, 0, 70), Position = UDim2.new(0.5, 8, 1, -86), Color = Kit.Colors.Orange })
	onward.Activated:Connect(function()
		choose(true)
	end)
	local timer = Kit.Text(panel, { Text = "", Size = UDim2.new(1, -24, 0, 24), Position = UDim2.new(0, 12, 1, -112), TextColor3 = Kit.Colors.Gray, NoStroke = true })
	Kit.Pop(panel, 0.3)
	-- odpočet; když se nerozhodne, vrátí se na pláž (server ho přesune sám)
	task.spawn(function()
		local left = result.ChoiceTime or 10
		while left > 0 and token == raftChoiceToken do
			timer.Text = `Back to the beach in {math.ceil(left)}…`
			task.wait(0.25)
			left -= 0.25
		end
		if token == raftChoiceToken then
			choose(false)
		end
	end)
end

local function endSwim(result: { [string]: any })
	local state = flight
	if not state then
		return
	end
	state.SwimEnded = true
	setDanger(0)
	if result.Success then
		if state.SwimInfo then
			state.SwimInfo.EscapedAt = os.clock() - state.SwimStart
		end
		Effects.BigText("SAFE! +" .. FormatNumber.Money(result.Bonus), Kit.Colors.Green, 1.4, 0.28)
		if typeof(result.Stars) == "number" then
			local stars = result.Stars :: number
			local text = string.rep("★", stars) .. string.rep("☆", 3 - stars)
			local extra = if typeof(result.StarBonus) == "number" and result.StarBonus > 0 then `  +{FormatNumber.Money(result.StarBonus)}` else ""
			local label = if stars == 3 then "PERFECT SLALOM!" elseif stars == 2 then "GREAT SLALOM!" else "SLALOM DONE"
			task.delay(0.9, function()
				Effects.BigText(`{text} {label}{extra}`, if stars == 3 then Kit.Colors.Yellow else Kit.Colors.White, 1.6, 0.4)
				if stars == 3 then
					Sound.Play("Perfect", 1.2)
				end
			end)
		end
		local kept = if typeof(result.Item) == "string" then Catalog.Item(result.Item) else nil
		if kept then
			local where = if result.Placement == "Carried" then "carry it home!" elseif result.Placement == "Storage" then "sent to storage." else "placed in your house!"
			Effects.FloatText(kept.Name .. " " .. where, Kit.Colors.Green)
			if (result.Stage or 1) >= 2 then
				-- poklad z truhly na voru
				JumpController.ShowItemCard(result.Item, false, result.Placement)
			end
		end
		Effects.ScreenConfetti(60)
		Sound.Play("Coin")
		Sound.Play("Land")
		Effects.FovKick(6)
	elseif result.Reason == "Shark" then
		local tier = if state.SwimInfo and state.SwimInfo.Tier then state.SwimInfo.Tier else Formulas.ChaserByKey(nil)
		Effects.BigText(tier.Caught, tier.Color, 1.4, 0.28)
		local pos = state.ExpectedPosition
		if pos then
			Effects.Splash(pos, true)
		end
		Sound.Play("Splash", 0.8)
		Effects.Shake(0.55)
		if state.SwimInfo and state.SwimInfo.CanUpgrade then
			HUD.Notify("Swim faster! Buy swim gear in the SHOP (Swim tab).", "Info")
		end
	else
		Effects.BigText("Too slow!", Kit.Colors.Orange, 1.2, 0.28)
	end
	-- nedoplaval → předmět z vody je pryč (klesne ke dnu)
	local lost = if not result.Success and typeof(result.LostItem) == "string" then Catalog.Item(result.LostItem) else nil
	if lost then
		local lostId = result.LostItem :: string
		task.delay(0.5, function()
			Effects.BigText("You lost your " .. lost.Name .. "!", Kit.Colors.Coral, 1.6, 0.42)
		end)
		local pos = state.ExpectedPosition
		if pos then
			local model = Models.Item(lostId)
			Models.Anchor(model)
			local start = CFrame.new(pos + Vector3.new(-3, 1.5, 0))
			model:PivotTo(start)
			model.Parent = state.Folder
			local value = Instance.new("NumberValue")
			value.Changed:Connect(function(alpha)
				if model.Parent then
					model:PivotTo(start * CFrame.new(0, -alpha * 9, 0) * CFrame.Angles(alpha * 1.2, alpha * 4, 0))
				end
			end)
			TweenService:Create(value, TweenInfo.new(Swim.ReturnDelay, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = 1 }):Play()
			task.delay(Swim.ReturnDelay + 0.2, function()
				value:Destroy()
			end)
		end
	end
	if result.Success and result.CanContinue then
		-- vylezl na vor: pronásledovatel odplave, hráč si vybere, jestli plave dál
		task.delay(0.6, function()
			if flight == state and state.SwimEnded then
				state.OnRaft = true
				showRaftChoice(state, result)
			end
		end)
		return
	end
	returnToBeach(state, Swim.ReturnDelay)
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
			local final = math.min(info.BaseDistance * (1 + (info.RingBonus or c.RingBonus) * #state.CollectedRings + state.GemDistanceBonus), info.Cap)
			state.FinalDistance = final
			local extra = final - info.BaseDistance
			if extra > 1 then
				state.Phase = "Glide"
				state.GlideStart = os.clock()
				state.GlideDuration = Formulas.ExtraGlideTime(extra, info.BaseDistance)
				Effects.BigText("RING BOOST!", Kit.Colors.Yellow, 0.8, 0.36)
				Effects.FovKick(12)
				Effects.Shake(0.2)
				Sound.Play("Perfect", 1.3)
			else
				finishFlight(state)
			end
		end
	elseif state.Phase == "Glide" then
		local final = state.FinalDistance
		local extra = final - info.BaseDistance
		local g = math.clamp((os.clock() - state.GlideStart) / state.GlideDuration, 0, 1)
		x = info.EndX + extra * g
		local endY = if final >= (info.GiftAt or World.GiftDistance) then (info.GiftLandY or World.WaterY + 7) else World.WaterY + 1.5
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
	-- rychlost → čáry, vítr, zorné pole (krátký skok ≈ 0, dlouhé skoky = 1)
	local speed = 0
	if state.Phase == "Main" or state.Phase == "Glide" then
		local horizontal = math.abs(x - state.LastX) / math.max(dt, 1 / 240)
		speed = math.clamp(0.15 + (horizontal - 30) / 260, 0.15, 1)
		Effects.SetSpeed(speed)
		Sound.SetLoop("Wind", true, 0.3 + speed * 0.7, 0.8 + speed * 0.45)
		flightFovTarget = Jump.Flight.CameraFlightFov - 5 + speed * 10
	end
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
		-- při velké rychlosti kamera trochu odjede dozadu a nakloní se do zatáčky
		local behind = position + Vector3.new(-22 - speed * 5, 9 + speed * 2, 0)
		applyCamera(camera, CFrame.lookAt(behind, position + Vector3.new(30, -2, 0)) * CFrame.Angles(0, 0, -lean * 0.06), dt)
	elseif camera then
		local behind = position + Vector3.new(-26, 12, 10)
		flightFovTarget = Jump.Flight.CameraFov + 5
		applyCamera(camera, (cameraBase or camera.CFrame):Lerp(CFrame.lookAt(behind, position), 0.1), dt)
	end
	-- vzdálenost od konce mola
	local distance = math.max(0, x - World.PierEndX)
	distanceLabel.Text = FormatNumber.Studs(math.floor(distance))
	updateGiftProgress(distance)
end

-- ===== Výsledek skoku =====

local function showResult(result: { [string]: any })
	local state = flight
	local landing = if state and state.LandPosition then state.LandPosition else Vector3.new(World.PierEndX + result.Distance, World.WaterY, 0)
	if not (state and state.LandPosition) then
		-- velké šplouchnutí už udělal finishFlight; tohle je jen pojistka
		Effects.Splash(Vector3.new(landing.X, World.WaterY, landing.Z), result.Distance > 10_000)
	end
	-- překonaná "rekordní zóna" (500, 1 000, 2 500 … studů) → hlavní nápis se změní na oslavu
	-- (jen jeden velký text, ať se nepřekrývá s nápisy plavání a slalomu)
	local zone = 0
	if result.PersonalRecord and not result.ReachedGift then
		for _, z in RECORD_ZONES do
			if bestBefore < z and result.Distance >= z then
				zone = z
			end
		end
	end
	if zone > 0 then
		Effects.BigText(`NEW RECORD! {FormatNumber.Studs(result.Distance)}!`, Kit.Colors.Pink, 2.4, 0.2)
		Effects.ScreenConfetti(90)
		Sound.Play("Fanfare")
	else
		Effects.BigText(FormatNumber.Studs(result.Distance) .. "!", Kit.Colors.White, 2.2, 0.2)
		if result.PersonalRecord and not result.ReachedGift then
			HUD.Notify("NEW PERSONAL BEST!", "Record")
		end
	end
	if result.ReachedGift then
		-- poslední snímek letu mohl skončit těsně před cílem („SO CLOSE…“) → schovat
		giftMessage.Visible = false
	end
	-- skok skončil kousek před dárkem → povzbudit
	if not result.ReachedGift and result.Distance >= giftTarget * 0.8 and result.Distance < giftTarget then
		local left = FormatNumber.Commas(math.max(1, math.ceil(giftTarget - result.Distance)))
		task.delay(0.6, function()
			Effects.BigText("Only " .. left .. " studs from the " .. giftTargetName .. "!", Kit.Colors.Yellow, 2.4, 0.42)
		end)
	end
	if result.CoinMoney > 0 then
		local x2 = if typeof(result.CoinMultiplier) == "number" and result.CoinMultiplier > 1 then ` (x{result.CoinMultiplier}!)` else ""
		Effects.FloatText("+" .. FormatNumber.Money(result.CoinMoney) .. " from coins" .. x2, Kit.Colors.Yellow)
	end
	if typeof(result.Balloons) == "table" then
		for i, prize in result.Balloons do
			local cfg = if typeof(prize.Item) == "string" then Catalog.Item(prize.Item) else nil
			if cfg then
				local name = cfg.Name
				task.delay(0.8 + i * 0.6, function()
					Effects.FloatText(`🎈 Treasure: {name}! (+{FormatNumber.Money(prize.Money)})`, Kit.Colors.Yellow)
				end)
			end
		end
	end
	if typeof(result.DiamondMoney) == "number" and result.DiamondMoney > 0 then
		local n = if typeof(result.Diamonds) == "table" then #result.Diamonds else 0
		task.delay(0.4, function()
			Effects.FloatText(`💎 +{FormatNumber.Money(result.DiamondMoney)} from {n} diamond{if n == 1 then "" else "s"}`, Color3.fromRGB(150, 230, 255))
		end)
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
		Sound.Play("Confetti")
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
	local pending = placement == "Pending"
	local where = if pending then "Swim to the raft to keep it!" elseif placement == "Carried" then "House full! Carry it over your head." elseif placement == "Storage" then "Sent to storage." else "Placed in your house!"
	Kit.Text(inner, { Text = where, Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 338), TextColor3 = if pending then Kit.Colors.Orange else Kit.Colors.Gray, NoStroke = true })
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
			-- puštění se počítá i když prst/myš mezitím sjede z tlačítka
			local connection: RBXScriptConnection
			connection = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End or input.UserInputState == Enum.UserInputState.Cancel then
					connection:Disconnect()
					releaseCharge()
				end
			end)
		end
	end)

	flightHud = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = screen })
	distanceLabel = Kit.Text(flightHud, { Text = "0 studs", Size = UDim2.fromOffset(520, 80), Position = UDim2.new(0.5, 0, 0, 20), AnchorPoint = Vector2.new(0.5, 0), StrokeThickness = 4 })
	coinsLabel = Kit.Text(flightHud, { Text = "Coins: 0", Size = UDim2.fromOffset(260, 54), Position = UDim2.new(0, 24, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Kit.Colors.Yellow })
	ringsLabel = Kit.Text(flightHud, { Text = "⭕ 0", Size = UDim2.fromOffset(340, 54), Position = UDim2.new(0, 24, 0, 90), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 230, 120) })
	gemsLabel = Kit.Text(flightHud, { Text = "💎 0", Size = UDim2.fromOffset(340, 54), Position = UDim2.new(0, 24, 0, 150), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(150, 230, 255) })
	-- pruh cesty k Obřímu dárku: hned pod vzdáleností, dárek na konci
	giftBar = Kit.Panel(flightHud, { Size = UDim2.fromOffset(360, 20), Position = UDim2.new(0.5, -20, 0, 106), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromRGB(30, 50, 95), Radius = 10, StrokeThickness = 3 })
	giftFill = Kit.new("Frame", { BackgroundColor3 = Kit.Colors.Yellow, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), ZIndex = 2, Parent = giftBar })
	Kit.Corner(giftFill, 10)
	Kit.new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215)), Rotation = 90, Parent = giftFill })
	giftIcon = Kit.Text(giftBar, { Text = "🎁", Size = UDim2.fromOffset(46, 46), Position = UDim2.new(1, 6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), NoStroke = true, ZIndex = 3 })
	giftMessage = Kit.Text(flightHud, { Text = "", Size = UDim2.fromOffset(620, 40), Position = UDim2.new(0.5, 0, 0, 136), AnchorPoint = Vector2.new(0.5, 0), TextColor3 = Kit.Colors.Yellow, StrokeThickness = 3, Visible = false })
	steerHint = Kit.Text(flightHud, { Text = "Steer with A / D or the joystick!", Size = UDim2.fromOffset(600, 44), Position = UDim2.new(0.5, 0, 1, -60), AnchorPoint = Vector2.new(0.5, 1), TextColor3 = Kit.Colors.White })

	swimHud = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = screen })
	local bar = Kit.Panel(swimHud, { Size = UDim2.fromOffset(560, 44), Position = UDim2.new(0.5, 0, 0, 30), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromRGB(40, 80, 140), Radius = 20 })
	swimBarYou = Kit.new("Frame", { BackgroundColor3 = Kit.Colors.Green, Size = UDim2.fromScale(0, 1), Parent = bar })
	Kit.Corner(swimBarYou, 20)
	Kit.Text(bar, { Text = "YOU  >>>  RAFT", Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5), ZIndex = 3 })
	swimBarShark = Kit.Text(bar, { Text = "SHARK", Size = UDim2.fromOffset(150, 36), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), TextColor3 = Kit.Colors.Coral, StrokeThickness = 3, ZIndex = 4 }) :: any
	swimHint = Kit.Text(swimHud, { Text = "Hold W / joystick forward to swim!", Size = UDim2.fromOffset(640, 46), Position = UDim2.new(0.5, 0, 1, -60), AnchorPoint = Vector2.new(0.5, 1) })
	-- červené okraje obrazovky (žraločí alarm)
	dangerVignette = Instance.new("CanvasGroup")
	dangerVignette.Name = "DangerVignette"
	dangerVignette.BackgroundTransparency = 1
	dangerVignette.Size = UDim2.fromScale(1, 1)
	dangerVignette.GroupTransparency = 1
	dangerVignette.Visible = false
	dangerVignette.ZIndex = 0
	dangerVignette.Parent = swimHud
	type Edge = { Size: UDim2, Position: UDim2, Rotation: number }
	local edges: { Edge } = {
		{ Size = UDim2.fromScale(1, 0.22), Position = UDim2.fromScale(0, 0), Rotation = 90 },
		{ Size = UDim2.fromScale(1, 0.22), Position = UDim2.fromScale(0, 0.78), Rotation = 270 },
		{ Size = UDim2.fromScale(0.16, 1), Position = UDim2.fromScale(0, 0), Rotation = 0 },
		{ Size = UDim2.fromScale(0.16, 1), Position = UDim2.fromScale(0.84, 0), Rotation = 180 },
	}
	for _, edge in edges do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.fromRGB(230, 20, 30)
		f.Size = edge.Size
		f.Position = edge.Position
		f.Parent = dangerVignette
		local g = Instance.new("UIGradient")
		g.Rotation = edge.Rotation
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = f
	end
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
			if flight.Slalom then
				Slalom.Destroy(flight.Slalom)
			end
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

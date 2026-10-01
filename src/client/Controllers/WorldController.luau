--!strict
-- Lokální věci ve světě:
--  • oceán, který jede s kamerou (voda je vidět i daleko, kam StreamingEnabled ještě nedoletěl)
--  • zmenšený obří dárek na obzoru + paprsek (skutečný model je 100 000 studů daleko)
--  • barva dárku podle počtu znovuzrození
--  • otáčení a vznášení předmětů na podstavcích a nad hlavou, ruce nahoře při nošení
--  • zapínání výzev (Pick Up / Place / Swap jen ve vlastním domečku, Gift a Sell jen s předmětem)
--  • časovač na kole štěstí a animace kola

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local World = require(Shared.Config.World)
local GiantGift = require(Shared.Config.GiantGift)
local FormatNumber = require(Shared.Util.FormatNumber)
local Net = require(Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)
local SpinnerUI = require(script.Parent.Parent.UI.SpinnerUI)
local Effects = require(script.Parent.Parent.Effects.Effects)
local Kit = require(script.Parent.Parent.UI.Kit)

local WorldController = {}

local player = Players.LocalPlayer

-- ===== Oceán =====

local ocean: Part
local function createOcean()
	ocean = Instance.new("Part")
	ocean.Name = "LocalOcean"
	ocean.Anchored = true
	ocean.CanCollide = false
	ocean.CanQuery = false
	ocean.CanTouch = false
	ocean.CastShadow = false
	ocean.Size = Vector3.new(2048, 1, 2048)
	ocean.Material = Enum.Material.SmoothPlastic
	ocean.Reflectance = 0.05
	ocean.Parent = Workspace
end

local function waterColor(distance: number): Color3
	for _, zone in World.WaterZones do
		if distance < zone.UpTo then
			return zone.Color
		end
	end
	return World.WaterZones[#World.WaterZones].Color
end

-- ===== Dárek na obzoru =====

local horizonGift: Model
local horizonBodies: { BasePart } = {}

local function createHorizonGift()
	local m = Instance.new("Model")
	m.Name = "HorizonGift"
	local function add(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Shape = shape or Enum.PartType.Block
		p.Parent = m
		return p
	end
	local gold = Color3.fromRGB(255, 200, 40)
	local red = Color3.fromRGB(230, 40, 50)
	local box = add(Vector3.new(60, 70, 60), CFrame.new(0, 35, 0), gold)
	local lid = add(Vector3.new(66, 12, 66), CFrame.new(0, 76, 0), gold)
	table.insert(horizonBodies, box)
	table.insert(horizonBodies, lid)
	add(Vector3.new(62, 84, 10), CFrame.new(0, 41, 0), red)
	add(Vector3.new(10, 84, 62), CFrame.new(0, 41, 0), red)
	add(Vector3.new(24, 14, 12), CFrame.new(0, 88, 9), red, nil, Enum.PartType.Ball)
	add(Vector3.new(24, 14, 12), CFrame.new(0, 88, -9), red, nil, Enum.PartType.Ball)
	local beam = add(Vector3.new(1400, 14, 14), CFrame.new(0, 780, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 240, 170), Enum.Material.Neon, Enum.PartType.Cylinder)
	beam.Transparency = 0.4
	-- ostrůvek
	add(Vector3.new(4, 140, 140), CFrame.new(0, -1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(246, 222, 160), Enum.Material.Sand, Enum.PartType.Cylinder)
	m.PrimaryPart = box
	m.Parent = Workspace
	horizonGift = m
end

local function giftColor(rebirths: number): Color3
	local colors = GiantGift.Colors
	if rebirths == GiantGift.RainbowFromRebirth then
		return Color3.fromHSV((os.clock() * 0.15) % 1, 0.6, 1)
	end
	return colors[math.min(rebirths + 1, #colors)]
end

-- ===== Otáčení předmětů =====

local spinBase: { [Model]: CFrame } = {}
local carryBase: { [Weld]: CFrame } = {}

local function trackSpin(instance: Instance)
	if instance:IsA("Model") then
		spinBase[instance] = instance:GetPivot()
		instance.AncestryChanged:Connect(function()
			if not instance:IsDescendantOf(Workspace) then
				spinBase[instance] = nil
			end
		end)
	end
end

local function trackCarry(instance: Instance)
	if instance:IsA("Weld") then
		carryBase[instance] = instance.C0
		instance.AncestryChanged:Connect(function()
			if not instance:IsDescendantOf(Workspace) then
				carryBase[instance] = nil
			end
		end)
	end
end

-- ===== Výzvy =====

local function ownsHouseOf(instance: Instance): boolean
	local house = instance:FindFirstAncestorWhichIsA("Model")
	while house and house:GetAttribute("HouseIndex") == nil do
		house = house:FindFirstAncestorWhichIsA("Model")
	end
	return house ~= nil and house:GetAttribute("OwnerUserId") == player.UserId
end

local function refreshPrompts()
	local data = ClientState.Get()
	local carrying = data.Carried ~= nil
	local flying = data.Flying == true
	for _, prompt in CollectionService:GetTagged("HousePrompt") do
		if prompt:IsA("ProximityPrompt") then
			prompt.Enabled = not flying and prompt:GetAttribute("Active") == true and ownsHouseOf(prompt)
		end
	end
	for _, prompt in CollectionService:GetTagged("GiftPrompt") do
		if prompt:IsA("ProximityPrompt") then
			prompt.Enabled = carrying and not flying and prompt:GetAttribute("OwnerUserId") ~= player.UserId
		end
	end
	for _, prompt in CollectionService:GetTagged("SellPrompt") do
		if prompt:IsA("ProximityPrompt") then
			prompt.Enabled = carrying and not flying
		end
	end
end

local function watchPrompt(prompt: Instance)
	prompt:GetAttributeChangedSignal("Active"):Connect(refreshPrompts)
	local house = prompt:FindFirstAncestorWhichIsA("Model")
	while house and house:GetAttribute("HouseIndex") == nil do
		house = house:FindFirstAncestorWhichIsA("Model")
	end
	if house then
		house:GetAttributeChangedSignal("OwnerUserId"):Connect(refreshPrompts)
	end
	refreshPrompts()
end

-- ===== Ruce nahoře při nošení předmětu =====

local function poseCarrying()
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if character and character:GetAttribute("Carrying") == true then
			for _, name in { "RightUpperArm", "LeftUpperArm" } do
				local arm = character:FindFirstChild(name)
				local motor = arm and arm:FindFirstChild(if name == "RightUpperArm" then "RightShoulder" else "LeftShoulder")
				if motor and motor:IsA("Motor6D") then
					motor.Transform = CFrame.Angles(math.rad(165), 0, 0)
				end
			end
			local torso = character:FindFirstChild("Torso")
			if torso then
				for _, name in { "Right Shoulder", "Left Shoulder" } do
					local motor = torso:FindFirstChild(name)
					if motor and motor:IsA("Motor6D") then
						motor.Transform = CFrame.Angles(0, 0, math.rad(if name == "Right Shoulder" then 165 else -165))
					end
				end
			end
		end
	end
end

-- ===== Efekty od serveru =====

local function onEffect(kind: string, info: { [string]: any })
	if kind == "Splash" then
		if info.UserId ~= player.UserId then
			local camera = Workspace.CurrentCamera
			if camera and (camera.CFrame.Position - info.Position).Magnitude < 1500 then
				Effects.Splash(info.Position, false)
			end
		end
	elseif kind == "Collect" then
		Effects.FloatText("+" .. FormatNumber.Money(info.Amount), Kit.Colors.Yellow)
	elseif kind == "Purchase" then
		Effects.ScreenConfetti(50)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			Effects.WorldConfetti(root.Position + Vector3.new(0, 3, 0), 40)
		end
	elseif kind == "Quest" then
		Effects.ScreenConfetti(40)
	elseif kind == "Rebirth" then
		Effects.BigText("REBIRTH " .. info.Rebirths .. "!", Kit.Colors.Purple, 2)
		Effects.ScreenConfetti(150)
	end
end

function WorldController.Init()
	createOcean()
	createHorizonGift()

	for _, instance in CollectionService:GetTagged("SpinItem") do
		trackSpin(instance)
	end
	CollectionService:GetInstanceAddedSignal("SpinItem"):Connect(trackSpin)
	for _, instance in CollectionService:GetTagged("CarryWeld") do
		trackCarry(instance)
	end
	CollectionService:GetInstanceAddedSignal("CarryWeld"):Connect(trackCarry)
	for _, tag in { "HousePrompt", "GiftPrompt", "SellPrompt" } do
		for _, prompt in CollectionService:GetTagged(tag) do
			watchPrompt(prompt)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(watchPrompt)
	end
	ClientState.Changed:Connect(refreshPrompts)

	Net.Event("PlayEffect").OnClientEvent:Connect(onEffect)

	-- animace kola ve světě, když hráč točí
	SpinnerUI.Spun:Connect(function(index)
		local wheel = CollectionService:GetTagged("SpinnerWheel")[1]
		if wheel and wheel:IsA("Model") and wheel.PrimaryPart then
			local hub = wheel.PrimaryPart
			SpinnerUI.Animate(wheel, hub.Position, hub.CFrame.XVector, index, 4)
		end
	end)

	RunService.Stepped:Connect(poseCarrying)

	local lastTimerUpdate = 0
	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local camPos = camera.CFrame.Position
		local t = os.clock()
		-- oceán pod kamerou (kousek pod skutečnou vodou, aby neblikal)
		local distance = camPos.X - World.PierEndX
		if distance > World.TerrainWaterLength - 1024 then
			ocean.CFrame = CFrame.new(camPos.X, World.WaterY - 0.6, camPos.Z)
			ocean.Color = waterColor(distance)
			ocean.Transparency = 0
		else
			ocean.Transparency = 1
		end
		-- dárek na obzoru
		local data = ClientState.Get()
		local rebirths = data.Rebirths or 0
		local giftPosition = Vector3.new(World.PierEndX + World.GiftDistance + 130, World.WaterY, 0)
		local toGift = giftPosition - camPos
		local flat = Vector3.new(toGift.X, 0, toGift.Z)
		if flat.Magnitude > World.RealGiftShowDistance then
			local dir = flat.Unit
			local horizonPos = Vector3.new(camPos.X, World.WaterY - 4, camPos.Z) + dir * World.HorizonGiftDistance
			horizonGift:PivotTo(CFrame.lookAt(horizonPos, horizonPos - dir) * CFrame.new(0, 35, 0))
		else
			horizonGift:PivotTo(CFrame.new(0, -2000, 0))
		end
		local color = giftColor(rebirths)
		for _, part in horizonBodies do
			part.Color = color
		end
		for _, part in CollectionService:GetTagged("GiftBody") do
			if part:IsA("BasePart") then
				part.Color = color
			end
		end
		-- otáčení předmětů
		for model, base in spinBase do
			model:PivotTo(base * CFrame.new(0, math.sin(t * 2 + base.X) * 0.4, 0) * CFrame.Angles(0, t * 1.2, 0))
		end
		for weld, base in carryBase do
			weld.C0 = base * CFrame.new(0, math.sin(t * 3) * 0.3, 0) * CFrame.Angles(0, t * 2, 0)
		end
		-- časovač kola štěstí
		if t - lastTimerUpdate > 0.5 then
			lastTimerUpdate = t
			for _, label in CollectionService:GetTagged("SpinnerTimer") do
				if label:IsA("TextLabel") then
					local spins = (data.DailySpins or 0) + (data.ExtraSpins or 0)
					if spins > 0 then
						label.Text = if spins == 1 then "FREE SPIN!" else spins .. " SPINS READY!"
					else
						label.Text = "Next spin: " .. FormatNumber.Time((data.NextFreeSpin or 0) - ClientState.ServerNow())
					end
				end
			end
		end
	end)
end

return WorldController

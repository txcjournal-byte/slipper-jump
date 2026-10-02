--!strict
-- Lokální věci ve světě:
--  • oceán, který jede s kamerou (voda je vidět i daleko, kam StreamingEnabled ještě nedoletěl)
--  • zmenšený obří dárek na obzoru + paprsek (skutečný model je 100 000 studů daleko)
--  • barva dárku podle počtu znovuzrození
--  • otáčení a vznášení předmětů na podstavcích a nad hlavou, ruce nahoře při nošení
--  • zapínání výzev (Pick Up / Place / Swap jen ve vlastním domečku, Gift a Sell jen s předmětem)
--  • časovač na kole štěstí, animace kola a blikající žárovky kolem něj
--  • záložní hlava s obličejem, když se hlava avatara nenačte

local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
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
-- Zmenšenina skutečného ostrova s dárkem (MapBuilder.buildGift). Počátek modelu = střed dárku u hladiny,
-- lokální −Z míří ke kameře (skutečné −X), lokální +X je skutečné −Z.
local HORIZON_SCALE = 0.85 -- větší, aby byl dárek na obzoru dobře vidět
local HORIZON_BASE_Y = 5 -- horní plocha ostrůvku (počátek je 4 study pod hladinou)
local HORIZON_BOX_HEIGHT = 300 * HORIZON_SCALE
local HORIZON_BOX_Y = HORIZON_BASE_Y + HORIZON_BOX_HEIGHT / 2 -- střed krabice (PrimaryPart)

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
	local S = HORIZON_SCALE
	local UP = CFrame.Angles(0, 0, math.rad(90)) -- válec postavený svisle
	local gold = Color3.fromRGB(255, 200, 40)
	local ribbon = Color3.fromRGB(255, 50, 80)
	local leaf = Color3.fromRGB(60, 160, 70)
	local top = HORIZON_BASE_Y
	-- ostrůvek: mělčina, písek a tráva (střed ostrova je 40 studů před dárkem)
	add(Vector3.new(1, 470 * S, 470 * S), CFrame.new(0, top - 1.2, -40 * S) * UP, Color3.fromRGB(110, 230, 235), nil, Enum.PartType.Cylinder)
	add(Vector3.new(8, 380 * S, 380 * S), CFrame.new(0, top - 4, -40 * S) * UP, Color3.fromRGB(246, 222, 160), Enum.Material.Sand, Enum.PartType.Cylinder)
	add(Vector3.new(1, 240 * S, 240 * S), CFrame.new(0, top, 10 * S) * UP, Color3.fromRGB(110, 200, 80), Enum.Material.Grass, Enum.PartType.Cylinder)
	-- dárek
	local box = add(Vector3.new(220 * S, HORIZON_BOX_HEIGHT, 220 * S), CFrame.new(0, HORIZON_BOX_Y, 0), gold)
	local lidY = top + HORIZON_BOX_HEIGHT + 20 * S
	local lid = add(Vector3.new(236 * S, 40 * S, 236 * S), CFrame.new(0, lidY, 0), gold)
	table.insert(horizonBodies, box)
	table.insert(horizonBodies, lid)
	local ribbonHeight = HORIZON_BOX_HEIGHT + 42 * S
	add(Vector3.new(222 * S, ribbonHeight, 36 * S), CFrame.new(0, top + ribbonHeight / 2, 0), ribbon, Enum.Material.Neon)
	add(Vector3.new(36 * S, ribbonHeight, 222 * S), CFrame.new(0, top + ribbonHeight / 2, 0), ribbon, Enum.Material.Neon)
	local bowY = top + HORIZON_BOX_HEIGHT + 40 * S
	for _, s in { -1, 1 } do
		-- smyčky mašle (kolečka natočená ke kameře)
		add(Vector3.new(28 * S, 80 * S, 80 * S), CFrame.new(s * 40 * S, bowY + 34 * S, 0) * CFrame.Angles(0, math.rad(90), 0), ribbon, Enum.Material.Neon, Enum.PartType.Cylinder)
	end
	add(Vector3.one * 40 * S, CFrame.new(0, bowY + 16 * S, 0), ribbon, Enum.Material.Neon, Enum.PartType.Ball)
	-- paprsek do nebe: jádro + široká záře
	local beamBottom = bowY
	local beam = add(Vector3.new(1600, 18, 18), CFrame.new(0, beamBottom + 800, 0) * UP, Color3.fromRGB(255, 240, 170), Enum.Material.Neon, Enum.PartType.Cylinder)
	beam.Transparency = 0.3
	local glow = add(Vector3.new(1600, 54, 54), CFrame.new(0, beamBottom + 800, 0) * UP, Color3.fromRGB(255, 245, 200), Enum.Material.Neon, Enum.PartType.Cylinder)
	glow.Transparency = 0.8
	-- maják (o něco větší než skutečný, aby byl z dálky vidět)
	local lighthouse = Vector3.new(150 * S, top, -120 * S)
	add(Vector3.new(36, 7, 7), CFrame.new(lighthouse + Vector3.new(0, 18, 0)) * UP, Color3.new(1, 1, 1), nil, Enum.PartType.Cylinder)
	add(Vector3.new(10, 7.4, 7.4), CFrame.new(lighthouse + Vector3.new(0, 14, 0)) * UP, Color3.fromRGB(235, 50, 55), nil, Enum.PartType.Cylinder)
	add(Vector3.new(10, 7.4, 7.4), CFrame.new(lighthouse + Vector3.new(0, 32, 0)) * UP, Color3.fromRGB(235, 50, 55), nil, Enum.PartType.Cylinder)
	add(Vector3.one * 8, CFrame.new(lighthouse + Vector3.new(0, 40, 0)), Color3.fromRGB(255, 240, 150), Enum.Material.Neon, Enum.PartType.Ball)
	-- siluety palem
	for _, pos in { Vector3.new(94, 0, -169), Vector3.new(-94, 0, -169), Vector3.new(152, 0, 9), Vector3.new(-152, 0, 9) } do
		local base = Vector3.new(pos.X * S, top, pos.Z * S)
		add(Vector3.new(16, 1.6, 1.6), CFrame.new(base + Vector3.new(0, 8, 0)) * UP, Color3.fromRGB(170, 115, 70), Enum.Material.Wood, Enum.PartType.Cylinder)
		add(Vector3.new(12, 2.5, 12), CFrame.new(base + Vector3.new(0, 16.5, 0)), leaf, Enum.Material.Grass)
	end
	m.PrimaryPart = box
	m.Parent = Workspace
	horizonGift = m
end

-- ===== Blikající žárovky kolem kola štěstí =====
-- Žárovky (tag "WheelBulb", atribut BulbIndex) staví MapBuilder; tady jim jen dokola měníme barvu (běžící světla).
local WHEEL_BULB_COLORS = {
	Color3.fromRGB(255, 90, 90),
	Color3.fromRGB(255, 210, 60),
	Color3.fromRGB(90, 220, 120),
	Color3.fromRGB(80, 180, 255),
	Color3.fromRGB(255, 130, 220),
}
local TWINKLE_INTERVAL = 0.3
local twinkleStep = 0

local function twinkleWheelBulbs()
	twinkleStep += 1
	for _, bulb in CollectionService:GetTagged("WheelBulb") do
		if bulb:IsA("BasePart") then
			local index = bulb:GetAttribute("BulbIndex")
			local i = if typeof(index) == "number" then index else 0
			bulb.Color = WHEEL_BULB_COLORS[(i + twinkleStep) % #WHEEL_BULB_COLORS + 1]
			-- každá třetí žárovka na chvíli pohasne
			bulb.Transparency = if (i + twinkleStep) % 3 == 0 then 0.6 else 0
		end
	end
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
	elseif kind == "ContestWin" then
		-- vítěz soutěže: konfety pro všechny, u vítěze ještě víc
		local winner = Players:GetPlayerByUserId(info.UserId)
		local character = winner and winner.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			Effects.WorldConfetti(root.Position + Vector3.new(0, 4, 0), 80)
		end
		if info.UserId == player.UserId then
			Effects.BigText("YOU WON THE JUMP CONTEST!", Kit.Colors.Yellow, 2.2)
			Effects.ScreenConfetti(150)
		else
			Effects.ScreenConfetti(40)
		end
	elseif kind == "Rebirth" then
		Effects.BigText("REBIRTH " .. info.Rebirths .. "!", Kit.Colors.Purple, 2)
		Effects.ScreenConfetti(150)
	end
end

-- ===== Záložní hlava =====
-- Když se 3D hlava avatara nestáhne (stává se ve Studiu, když vyprší přihlášení), postava je bez hlavy
-- a bez obličeje. Jen tady na klientovi jí pak přidáme klasickou hlavu s úsměvem.
local function ensureVisibleHead(character: Model)
	local head = character:WaitForChild("Head", 10)
	if not head or not head:IsA("MeshPart") then
		return
	end
	local meshPart = head :: MeshPart
	if meshPart.MeshId == "" then
		return
	end
	local failed = false
	pcall(function()
		ContentProvider:PreloadAsync({ meshPart.MeshId }, function(_, status)
			if status == Enum.AssetFetchStatus.Failure then
				failed = true
			end
		end)
	end)
	if not failed or not meshPart.Parent or meshPart:FindFirstChild("FallbackHead") then
		return
	end
	local fallback = Instance.new("Part")
	fallback.Name = "FallbackHead"
	fallback.Size = meshPart.Size
	fallback.Color = meshPart.Color
	fallback.CanCollide = false
	fallback.CanQuery = false
	fallback.CanTouch = false
	fallback.Massless = true
	fallback.CFrame = meshPart.CFrame
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Parent = fallback
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = fallback
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = meshPart
	weld.Part1 = fallback
	weld.Parent = fallback
	fallback.Parent = meshPart
end

local function watchHeads(other: Player)
	other.CharacterAdded:Connect(function(character)
		task.spawn(ensureVisibleHead, character)
	end)
	if other.Character then
		task.spawn(ensureVisibleHead, other.Character)
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

	for _, other in Players:GetPlayers() do
		watchHeads(other)
	end
	Players.PlayerAdded:Connect(watchHeads)

	local lastTimerUpdate = 0
	local lastTwinkle = 0
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
			horizonGift:PivotTo(CFrame.lookAt(horizonPos, horizonPos - dir) * CFrame.new(0, HORIZON_BOX_Y, 0))
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
		-- blikání žárovek kolem kola štěstí
		if t - lastTwinkle > TWINKLE_INTERVAL then
			lastTwinkle = t
			twinkleWheelBulbs()
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

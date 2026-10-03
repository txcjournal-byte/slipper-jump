--!strict
-- Lokální věci ve světě:
--  • oceán, který jede s kamerou (voda je vidět i daleko, kam StreamingEnabled ještě nedoletěl)
--  • zmenšený obří dárek na obzoru se září, šikmými paprsky, třpytkami a hvězdami (skutečný model je 100 000 studů daleko)
--  • pomalé otáčení ozdob s tagem "DecorSpin" (paprsky a hvězdy u dárku, obří pantofel a mince na stáncích)
--  • barva dárku podle počtu znovuzrození
--  • otáčení a vznášení předmětů na podstavcích a nad hlavou, ruce nahoře při nošení
--  • zapínání výzev (Pick Up / Place / Swap jen ve vlastním domečku, Gift a Sell jen s předmětem)
--  • časovač na kole štěstí, animace kola a blikající žárovky kolem něj a kolem cedulí stánků
--  • záložní hlava s obličejem, když se hlava avatara nenačte

local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local World = require(Shared.Config.World)
local Formulas = require(Shared.Formulas)
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
local horizonRayHub: BasePart
type HorizonStar = { Parts: { BasePart }, Phase: number, Height: number }
local horizonStars: { HorizonStar } = {}
-- Zmenšenina skutečného ostrova s dárkem (MapBuilder.buildGift). Počátek modelu = střed dárku u hladiny,
-- lokální −Z míří ke kameře (skutečné −X), lokální +X je skutečné −Z.
local HORIZON_SCALE = 0.85 -- větší, aby byl dárek na obzoru dobře vidět
local HORIZON_BASE_Y = 5 -- horní plocha ostrůvku (počátek je 4 study pod hladinou)
local HORIZON_BOX_HEIGHT = 300 * HORIZON_SCALE
local HORIZON_BOX_Y = HORIZON_BASE_Y + HORIZON_BOX_HEIGHT / 2 -- střed krabice (PrimaryPart)
local HORIZON_RAY_Y = HORIZON_BASE_Y + HORIZON_BOX_HEIGHT + 40 * HORIZON_SCALE + 45 -- střed paprsků nad mašlí
local HORIZON_STAR_RADIUS = 165
-- Zmenšenina se postaví ve velikosti pro 1 600 studů a pak se celá zmenší (Model:ScaleTo), aby mohla
-- stát blíž ke kameře: na nižší kvalitě grafiky Roblox vzdálené díly nevykreslí a dárek na obzoru zmizel.
-- Na menší vzdálenosti a ve zmenšeném měřítku vypadá stejně velký.
local HORIZON_SHRINK = World.HorizonGiftDistance / 1_600
local GLOW_WHITE = Color3.new(1, 1, 1)

-- Šikmé paprsky světla (Beam mezi dvěma Attachmenty v hub dílu), stejné jako u skutečného dárku v MapBuilderu
local function addGiftRays(hub: BasePart, count: number, startRadius: number, longLength: number, shortLength: number, width0: number, width1: number)
	for i = 0, count - 1 do
		local yaw = i / count * math.pi * 2
		local tilt = math.rad(if i % 2 == 0 then 38 else 62) -- odklon od svislice
		local dir = Vector3.new(math.cos(yaw) * math.sin(tilt), math.cos(tilt), math.sin(yaw) * math.sin(tilt))
		local length = if i % 2 == 0 then longLength else shortLength
		local a0 = Instance.new("Attachment")
		a0.Position = dir * startRadius
		a0.Parent = hub
		local a1 = Instance.new("Attachment")
		a1.Position = dir * (startRadius + length)
		a1.Parent = hub
		local ray = Instance.new("Beam")
		ray.Name = "Ray"
		ray.Attachment0 = a0
		ray.Attachment1 = a1
		ray.FaceCamera = true
		ray.Width0 = width0
		ray.Width1 = width1
		ray.Segments = 8
		ray.LightEmission = 1
		ray.LightInfluence = 0
		ray.Color = ColorSequence.new(Color3.fromRGB(255, 252, 225), Color3.fromRGB(255, 215, 110))
		ray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(0.5, 0.7), NumberSequenceKeypoint.new(1, 1) })
		ray.Parent = hub
	end
end

-- Velké třpytky stoupající nad dárkem (na obzoru musí být větší, aby byly z dálky vidět)
local function addRisingSparkles(source: BasePart)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "RisingSparkles"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 14
	emitter.Lifetime = NumberRange.new(5, 8)
	emitter.Speed = NumberRange.new(18, 30)
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = Vector3.new(0, 3, 0)
	emitter.RotSpeed = NumberRange.new(-60, 60)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(0.25, 16), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.7, 0.4), NumberSequenceKeypoint.new(1, 1) })
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 235, 140), GLOW_WHITE)
	emitter.LightEmission = 1
	emitter.LockedToPart = true
	emitter.Parent = source
end

-- Třpytky poblikávající po povrchu neviditelného dílu kolem dárku
local function addTwinkles(source: BasePart)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Twinkles"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 22
	emitter.Lifetime = NumberRange.new(1.2, 2.2)
	emitter.Speed = NumberRange.new(1, 4)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 14), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new(0.1)
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 245, 190))
	emitter.LightEmission = 1
	emitter.LockedToPart = true
	emitter.Parent = source
end

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
	-- (bez průsvitných svítících skořápek kolem krabice – přebíjely barvu dárku i mašle)
	local glowHeight = HORIZON_BOX_HEIGHT + 40 * S
	-- kulatá záře za dárkem (kotouče natočené ke kameře, jako slunce za dárkem)
	for k, diameter in { 470, 320 } do
		local disc = add(Vector3.new(1, diameter, diameter), CFrame.new(0, 205, 122 + k) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(255, 228, 140), Enum.Material.Neon, Enum.PartType.Cylinder)
		disc.Transparency = if k == 1 then 0.86 else 0.74
	end
	-- šikmé paprsky rozevřené od mašle do stran a nahoru (otáčí je RenderStepped)
	horizonRayHub = add(Vector3.one * 2, CFrame.new(0, HORIZON_RAY_Y, 0), Color3.new(1, 1, 1))
	horizonRayHub.Transparency = 1
	addGiftRays(horizonRayHub, 10, 40, 470, 320, 16, 100)
	-- stoupající třpytky nad víkem a poblikávání kolem celého dárku (LockedToPart: putují s dárkem)
	local riseSource = add(Vector3.new(190, 2, 190), CFrame.new(0, bowY + 2, 0), Color3.new(1, 1, 1))
	riseSource.Transparency = 1
	addRisingSparkles(riseSource)
	local twinkleSource = add(Vector3.new(236 * S + 40, glowHeight + 40, 236 * S + 40), CFrame.new(0, top + glowHeight / 2, 0), Color3.new(1, 1, 1))
	twinkleSource.Transparency = 1
	addTwinkles(twinkleSource)
	-- zlaté hvězdy obíhající kolem dárku (pozice počítá RenderStepped)
	for k = 0, 3 do
		local parts: { BasePart } = {}
		local core = add(Vector3.one * 12, CFrame.new(), Color3.fromRGB(255, 205, 50), Enum.Material.Neon, Enum.PartType.Ball)
		table.insert(parts, core)
		for _, size in { Vector3.new(3, 34, 3), Vector3.new(30, 3, 3), Vector3.new(3, 3, 30) } do
			local arm = add(size, CFrame.new(), Color3.fromRGB(255, 240, 170), Enum.Material.Neon)
			arm.Transparency = 0.25
			table.insert(parts, arm)
		end
		table.insert(horizonStars, { Parts = parts, Phase = k / 4 * math.pi * 2, Height = 100 + (k % 2) * 110 + k * 12 })
	end
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
	m:ScaleTo(HORIZON_SHRINK)
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
	for _, tag in { "WheelBulb", "StallBulb" } do
		for _, bulb in CollectionService:GetTagged(tag) do
			if bulb:IsA("BasePart") then
				local index = bulb:GetAttribute("BulbIndex")
				local i = if typeof(index) == "number" then index else 0
				bulb.Color = WHEEL_BULB_COLORS[(i + twinkleStep) % #WHEEL_BULB_COLORS + 1]
				-- každá třetí žárovka na chvíli pohasne
				bulb.Transparency = if (i + twinkleStep) % 3 == 0 then 0.6 else 0
			end
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

-- ===== Pomalé otáčení ozdob (tag "DecorSpin", atributy SpinSpeed v rad/s a volitelně SpinAxis) =====
-- MapBuilder tak označuje paprsky a hvězdy u obřího dárku a obří pantofel / minci na stáncích.

type DecorSpinInfo = { Base: CFrame, Axis: Vector3, Speed: number }
local decorSpin: { [Instance]: DecorSpinInfo } = {}

local function trackDecorSpin(instance: Instance)
	local base: CFrame
	if instance:IsA("Model") then
		base = instance:GetPivot()
	elseif instance:IsA("BasePart") then
		base = instance.CFrame
	else
		return
	end
	local axis = instance:GetAttribute("SpinAxis")
	local speed = instance:GetAttribute("SpinSpeed")
	decorSpin[instance] = {
		Base = base,
		Axis = if typeof(axis) == "Vector3" and axis.Magnitude > 0 then axis.Unit else Vector3.yAxis,
		Speed = if typeof(speed) == "number" then speed else 1,
	}
	instance.AncestryChanged:Connect(function()
		if not instance:IsDescendantOf(Workspace) then
			decorSpin[instance] = nil
		end
	end)
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
	for _, instance in CollectionService:GetTagged("DecorSpin") do
		trackDecorSpin(instance)
	end
	CollectionService:GetInstanceAddedSignal("DecorSpin"):Connect(trackDecorSpin)
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
		-- na obzoru je vždy nejbližší dárek, který hráč ještě nemá (bronzový, stříbrný, pak Obří)
		local nextIsland = Formulas.NextGiftIsland(data.ClaimedGifts)
		local giftPosition = if nextIsland
			then Vector3.new(World.PierEndX + nextIsland.Distance + 90, World.WaterY, 0)
			else Vector3.new(World.PierEndX + World.GiftDistance + 130, World.WaterY, 0)
		local toGift = giftPosition - camPos
		local flat = Vector3.new(toGift.X, 0, toGift.Z)
		if flat.Magnitude > World.RealGiftShowDistance then
			local dir = flat.Unit
			local horizonPos = Vector3.new(camPos.X, World.WaterY - 4 * HORIZON_SHRINK, camPos.Z) + dir * World.HorizonGiftDistance
			horizonGift:PivotTo(CFrame.lookAt(horizonPos, horizonPos - dir) * CFrame.new(0, HORIZON_BOX_Y * HORIZON_SHRINK, 0))
		else
			horizonGift:PivotTo(CFrame.new(0, -2000, 0))
		end
		-- otáčející se paprsky a obíhající hvězdy (počítané od počátku zmenšeniny)
		local horizonOrigin = horizonGift:GetPivot() * CFrame.new(0, -HORIZON_BOX_Y * HORIZON_SHRINK, 0)
		horizonRayHub.CFrame = horizonOrigin * CFrame.new(0, HORIZON_RAY_Y * HORIZON_SHRINK, 0) * CFrame.Angles(0, t * 0.12, 0)
		for _, star in horizonStars do
			local starCF = horizonOrigin * CFrame.Angles(0, t * 0.25 + star.Phase, 0) * CFrame.new(HORIZON_STAR_RADIUS * HORIZON_SHRINK, (star.Height + math.sin(t * 1.3 + star.Phase) * 8) * HORIZON_SHRINK, 0)
			for _, part in star.Parts do
				part.CFrame = starCF
			end
		end
		local color = giftColor(rebirths)
		local horizonColor = if nextIsland then nextIsland.Color else color
		for _, part in horizonBodies do
			part.Color = horizonColor
		end
		for _, part in CollectionService:GetTagged("GiftBody") do
			if part:IsA("BasePart") then
				part.Color = color
			end
		end
		-- pomalé otáčení ozdob
		for instance, info in decorSpin do
			local cf = info.Base * CFrame.fromAxisAngle(info.Axis, t * info.Speed)
			if instance:IsA("Model") then
				instance:PivotTo(cf)
			elseif instance:IsA("BasePart") then
				instance.CFrame = cf
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

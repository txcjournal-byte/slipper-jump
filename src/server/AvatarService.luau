--!strict
-- Vzhled hráče: pantofle na nohou (se stopou a efektem při letu), čepice, předmět nad hlavou,
-- cedulka nad hlavou (jméno, level, titulek), výzva "Gift" a kolizní skupina.

local PhysicsService = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog = require(Shared.Catalog)
local World = require(Shared.Config.World)
local Models = require(Shared.Models)

local Registry = require(script.Parent.Registry)

type Session = any

local AvatarService = {}

local PLAYER_GROUP = "Players"
local SHOE_SCALE = 1.15
local IDLE_SPARKLE_TIER = 9 -- od této boty v řadě boty pořád jiskří
local GLOW_SOLE_TIER = 13 -- od této boty zářící podrážka

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 170, 40)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 240, 60)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 220, 90)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(60, 150, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 80, 255)),
})

-- Vzhled částic podle efektu pantoflí
type ParticleStyle = { Size: number, Speed: number, Rate: number, Lifetime: number, Color: Color3?, Gravity: number?, Light: boolean? }
local PARTICLES: { [string]: ParticleStyle } = {
	Drops = { Size = 0.35, Speed = 4, Rate = 30, Lifetime = 0.6, Color = Color3.fromRGB(150, 220, 255), Gravity = -20 },
	Seeds = { Size = 0.25, Speed = 3, Rate = 25, Lifetime = 0.8, Color = Color3.fromRGB(30, 30, 30), Gravity = -15 },
	Fluff = { Size = 0.6, Speed = 1.5, Rate = 25, Lifetime = 1.4, Color = Color3.fromRGB(255, 255, 255), Gravity = 1 },
	Fin = { Size = 0.4, Speed = 3, Rate = 20, Lifetime = 0.7, Color = Color3.fromRGB(170, 230, 255) },
	Squeak = { Size = 0.5, Speed = 2, Rate = 12, Lifetime = 0.8, Color = Color3.fromRGB(255, 230, 60) },
	Leaves = { Size = 0.5, Speed = 3, Rate = 20, Lifetime = 1.2, Color = Color3.fromRGB(90, 200, 70), Gravity = -5 },
	Snow = { Size = 0.4, Speed = 2, Rate = 35, Lifetime = 1.5, Color = Color3.fromRGB(240, 250, 255), Gravity = -3 },
	Rainbow = { Size = 0.5, Speed = 2, Rate = 30, Lifetime = 1, Light = true },
	Sparks = { Size = 0.35, Speed = 5, Rate = 45, Lifetime = 0.6, Color = Color3.fromRGB(255, 215, 60), Light = true },
	Boing = { Size = 0.5, Speed = 3, Rate = 15, Lifetime = 0.6, Color = Color3.fromRGB(140, 255, 200) },
	Smoke = { Size = 1.2, Speed = 3, Rate = 40, Lifetime = 1.2, Color = Color3.fromRGB(200, 200, 205), Gravity = 2 },
	Footprints = { Size = 0.6, Speed = 1, Rate = 10, Lifetime = 1.5, Color = Color3.fromRGB(90, 190, 80) },
	Crystals = { Size = 0.4, Speed = 3, Rate = 35, Lifetime = 1, Color = Color3.fromRGB(190, 240, 255), Light = true },
	Steam = { Size = 1.4, Speed = 2, Rate = 35, Lifetime = 1.4, Color = Color3.fromRGB(240, 240, 240), Gravity = 3 },
	Clouds = { Size = 1.6, Speed = 1, Rate = 20, Lifetime = 1.6, Color = Color3.fromRGB(255, 255, 255) },
	Leds = { Size = 0.3, Speed = 2, Rate = 40, Lifetime = 0.5, Color = Color3.fromRGB(60, 255, 120), Light = true },
	Stars = { Size = 0.45, Speed = 3, Rate = 40, Lifetime = 1.2, Color = Color3.fromRGB(200, 160, 255), Light = true },
	Flames = { Size = 0.7, Speed = 4, Rate = 45, Lifetime = 0.6, Color = Color3.fromRGB(255, 130, 40), Light = true, Gravity = 4 },
	Crown = { Size = 0.5, Speed = 5, Rate = 50, Lifetime = 1.2, Color = Color3.fromRGB(255, 220, 80), Light = true, Gravity = -8 },
}

local function setCollisionGroup(instance: Instance)
	if instance:IsA("BasePart") then
		instance.CollisionGroup = PLAYER_GROUP
	end
end

local function findFeet(character: Model): { BasePart }
	local feet = {}
	for _, name in { "LeftFoot", "RightFoot", "Left Leg", "Right Leg" } do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			table.insert(feet, part)
		end
	end
	return feet
end

function AvatarService.ApplySlippers(session: Session)
	local character = session.Player.Character
	if not character then
		return
	end
	for _, old in character:GetChildren() do
		if old.Name == "SlipperModel" then
			old:Destroy()
		end
	end
	local id = session.Data.EquippedSlippers
	local cfg = Catalog.Slipper(id)
	if not cfg then
		return
	end
	local rainbow = session.Passes.RainbowTrail == true
	for _, foot in findFeet(character) do
		local m = Models.Slipper(id)
		m.Name = "SlipperModel"
		-- větší, kreslené boty, aby byly na postavě dobře vidět
		Models.Scale(m, SHOE_SCALE)
		local handle = m.PrimaryPart :: BasePart
		local isR6 = foot.Size.Y > 1.5
		-- spodek boty kousek pod chodidlem (podrážka), ať bota nestojí ve vzduchu ani není zabořená
		local boxCFrame, boxSize = m:GetBoundingBox()
		local bottom = boxCFrame.Position.Y - boxSize.Y / 2 - handle.Position.Y
		local y = -foot.Size.Y / 2 - bottom - 0.15
		local offset = CFrame.new(0, y, if isR6 then -0.2 else -0.15)
		m:PivotTo(foot.CFrame * offset)
		local weld = Instance.new("Weld")
		weld.Part0 = foot
		weld.Part1 = handle
		weld.C0 = offset
		weld.Parent = handle
		for _, part in m:GetDescendants() do
			if part:IsA("BasePart") then
				part.CollisionGroup = PLAYER_GROUP
			end
		end
		-- stopa za pantoflí (zapíná se jen při letu)
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.35, 0.8)
		a0.Parent = handle
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.35, 0.8)
		a1.Parent = handle
		local trail = Instance.new("Trail")
		trail.Name = "FlightTrail"
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = if rainbow then 1.2 else 0.7
		trail.MinLength = 0.2
		trail.LightEmission = 0.4
		trail.FaceCamera = true
		trail.WidthScale = NumberSequence.new(if rainbow then 3 else 1.6, 0.2)
		trail.Transparency = NumberSequence.new(0.1, 1)
		trail.Color = if rainbow or cfg.Effect == "Rainbow" then RAINBOW else ColorSequence.new(cfg.TrailColor)
		trail.Enabled = false
		trail.Parent = handle
		CollectionService:AddTag(trail, "FlightFx")
		local style = PARTICLES[cfg.Effect]
		if style then
			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = "FlightParticles"
			emitter.Rate = style.Rate
			emitter.Lifetime = NumberRange.new(style.Lifetime * 0.7, style.Lifetime)
			emitter.Speed = NumberRange.new(style.Speed * 0.5, style.Speed)
			emitter.SpreadAngle = Vector2.new(180, 180)
			emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, style.Size), NumberSequenceKeypoint.new(1, style.Size * 0.2) })
			emitter.Transparency = NumberSequence.new(0, 1)
			emitter.Acceleration = Vector3.new(0, style.Gravity or 0, 0)
			emitter.Color = if style.Color then ColorSequence.new(style.Color) else RAINBOW
			emitter.LightEmission = if style.Light then 0.8 else 0.2
			emitter.Enabled = false
			emitter.Parent = handle
			CollectionService:AddTag(emitter, "FlightFx")
		end
		-- lepší boty jsou vidět už z dálky: jiskry a zářící podrážka i při chůzi
		local tier = Catalog.SlipperIndex(id)
		if tier >= IDLE_SPARKLE_TIER then
			local aura = Instance.new("ParticleEmitter")
			aura.Name = "ShoeAura"
			aura.Rate = 3 + (tier - IDLE_SPARKLE_TIER) * 1.5
			aura.Lifetime = NumberRange.new(0.6, 1.2)
			aura.Speed = NumberRange.new(0.5, 1.5)
			aura.SpreadAngle = Vector2.new(180, 180)
			aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
			aura.LightEmission = 1
			aura.Color = if rainbow or cfg.Effect == "Rainbow" then RAINBOW else ColorSequence.new(cfg.TrailColor)
			aura.Parent = handle
		end
		if tier >= GLOW_SOLE_TIER then
			local sole = Instance.new("Part")
			sole.Name = "GlowSole"
			sole.Shape = Enum.PartType.Cylinder
			local _, size = m:GetBoundingBox()
			local soleWidth = math.max(size.X, size.Z) * 0.85
			sole.Size = Vector3.new(0.12, soleWidth, soleWidth)
			sole.Color = cfg.TrailColor
			sole.Material = Enum.Material.Neon
			sole.Transparency = 0.35
			sole.CanCollide = false
			sole.CanQuery = false
			sole.CanTouch = false
			sole.Massless = true
			sole.CastShadow = false
			sole.CFrame = handle.CFrame * CFrame.new(0, -size.Y / 2 - 0.05, 0) * CFrame.Angles(0, 0, math.rad(90))
			local soleWeld = Instance.new("WeldConstraint")
			soleWeld.Part0 = handle
			soleWeld.Part1 = sole
			soleWeld.Parent = sole
			sole.Parent = m
			local light = Instance.new("PointLight")
			light.Color = cfg.TrailColor
			light.Range = 6
			light.Brightness = 1.5
			light.Parent = sole
		end
		m.Parent = character
	end
end

-- Stopa a částice pantoflí jen během letu (vidí je všichni)
function AvatarService.SetFlightEffects(session: Session, enabled: boolean)
	local character = session.Player.Character
	if not character then
		return
	end
	for _, descendant in character:GetDescendants() do
		if (descendant:IsA("Trail") or descendant:IsA("ParticleEmitter")) and CollectionService:HasTag(descendant, "FlightFx") then
			descendant.Enabled = enabled
		end
	end
end

function AvatarService.ApplyHat(session: Session)
	local character = session.Player.Character
	local head = character and character:FindFirstChild("Head")
	if not character or not head or not head:IsA("BasePart") then
		return
	end
	local old = character:FindFirstChild("HatModel")
	if old then
		old:Destroy()
	end
	local id = session.Data.EquippedHat
	if id == "" or not Catalog.Hat(id) then
		return
	end
	local m = Models.Hat(id)
	m.Name = "HatModel"
	local handle = m.PrimaryPart :: BasePart
	local offset = CFrame.new(0, head.Size.Y / 2 - 0.25, 0)
	m:PivotTo(head.CFrame * offset)
	local weld = Instance.new("Weld")
	weld.Part0 = head
	weld.Part1 = handle
	weld.C0 = offset
	weld.Parent = handle
	m.Parent = character
end

function AvatarService.UpdateCarried(session: Session)
	local character = session.Player.Character
	local head = character and character:FindFirstChild("Head")
	if not character or not head or not head:IsA("BasePart") then
		return
	end
	local old = character:FindFirstChild("CarriedItem")
	if old then
		old:Destroy()
	end
	local carried = session.Data.Carried
	character:SetAttribute("Carrying", carried ~= nil)
	-- jméno a level nad předmětem v rukou, ne schované za ním
	local overhead = head:FindFirstChild("Overhead") :: BillboardGui?
	if overhead then
		overhead.StudsOffset = Vector3.new(0, if carried then 7 else 3.2, 0)
	end
	if not carried then
		return
	end
	local m = Models.Item(carried.Id)
	m.Name = "CarriedItem"
	local handle = m.PrimaryPart :: BasePart
	local offset = CFrame.new(0, head.Size.Y / 2 + 3.2, 0)
	m:PivotTo(head.CFrame * offset)
	local weld = Instance.new("Weld")
	weld.Name = "CarryWeld"
	weld.Part0 = head
	weld.Part1 = handle
	weld.C0 = offset
	weld.Parent = handle
	CollectionService:AddTag(weld, "CarryWeld")
	m.Parent = character
end

function AvatarService.UpdateOverhead(session: Session)
	local character = session.Player.Character
	local head = character and character:FindFirstChild("Head")
	if not character or not head then
		return
	end
	local gui = head:FindFirstChild("Overhead") :: BillboardGui?
	if not gui then
		local newGui = Instance.new("BillboardGui")
		newGui.Name = "Overhead"
		newGui.Size = UDim2.fromOffset(220, 80)
		newGui.StudsOffset = Vector3.new(0, if character:GetAttribute("Carrying") then 7 else 3.2, 0)
		newGui.MaxDistance = 120
		newGui.LightInfluence = 0
		newGui.Parent = head
		local function label(name: string, y: number, height: number, color: Color3): TextLabel
			local l = Instance.new("TextLabel")
			l.Name = name
			l.BackgroundTransparency = 1
			l.Position = UDim2.fromScale(0, y)
			l.Size = UDim2.fromScale(1, height)
			l.Font = Enum.Font.FredokaOne
			l.TextScaled = true
			l.TextColor3 = color
			l.Parent = newGui
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 2
			stroke.Color = Color3.fromRGB(25, 25, 35)
			stroke.Parent = l
			return l
		end
		label("Title", 0, 0.3, Color3.fromRGB(255, 150, 230))
		label("Name", 0.3, 0.42, Color3.new(1, 1, 1))
		label("Level", 0.72, 0.28, Color3.fromRGB(130, 220, 255))
		gui = newGui
	end
	assert(gui)
	local data = session.Data
	local nameLabel = gui:FindFirstChild("Name") :: TextLabel
	local levelLabel = gui:FindFirstChild("Level") :: TextLabel
	local titleLabel = gui:FindFirstChild("Title") :: TextLabel
	nameLabel.Text = session.Player.DisplayName .. (if session.Passes.VIP then " [VIP]" else "")
	nameLabel.TextColor3 = if session.Passes.VIP then Color3.fromRGB(255, 210, 50) else Color3.new(1, 1, 1)
	levelLabel.Text = "Lv. " .. data.Level .. (if data.Rebirths > 0 then "  ♻" .. data.Rebirths else "")
	titleLabel.Text = data.Title
	titleLabel.Visible = data.Title ~= ""
end

local function setupGiftPrompt(session: Session, root: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GiftPrompt"
	prompt.ActionText = "Gift"
	prompt.ObjectText = session.Player.DisplayName
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.G
	prompt.Enabled = true -- klient ji lokálně skryje, když hráč nic nenese
	prompt:SetAttribute("OwnerUserId", session.Player.UserId)
	prompt.Parent = root
	CollectionService:AddTag(prompt, "GiftPrompt")
	prompt.Triggered:Connect(function(giver)
		Registry.Gifting.Request(giver, session.Player)
	end)
end

function AvatarService.ApplyAll(session: Session)
	AvatarService.ApplySlippers(session)
	AvatarService.ApplyHat(session)
	AvatarService.UpdateCarried(session)
	AvatarService.UpdateOverhead(session)
end

-- Když avatar nemá obličej (žádný obličej na hlavě ani dynamickou hlavu), dáme mu klasický úsměv
local function ensureFace(character: Model)
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") or not head.Parent then
		return
	end
	if head:FindFirstChildWhichIsA("Decal") or head:FindFirstChildOfClass("FaceControls") then
		return
	end
	if head:IsA("MeshPart") and head.TextureID ~= "" then
		return -- dynamická hlava má obličej v textuře
	end
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head
end

local function onCharacter(session: Session, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	character:WaitForChild("Head", 10)
	if not humanoid or not root or session.Player.Character ~= character then
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = World.WalkSpeed
	for _, descendant in character:GetDescendants() do
		setCollisionGroup(descendant)
	end
	character.DescendantAdded:Connect(setCollisionGroup)
	-- R15 načítá díly postupně, chvíli počkat na nohy
	task.wait(0.2)
	AvatarService.ApplyAll(session)
	-- vzhled avatara se načítá chvíli, obličej zkontrolujeme až potom
	task.delay(3, ensureFace, character)
	setupGiftPrompt(session, root)
	if session.Flight and not session.Flight.Finished then
		Registry.Jump.Finish(session, session.Flight, {}, {})
	end
	session.Flight = nil
	session.Swim = nil
	session.Returning = false
	Registry.Player.MarkDirty(session)
end

function AvatarService.OnSessionLoaded(session: Session)
	local player: Player = session.Player
	player.CharacterAdded:Connect(function(character)
		onCharacter(session, character)
	end)
	if player.Character then
		task.spawn(onCharacter, session, player.Character)
	end
end

function AvatarService.Init()
	PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	PhysicsService:CollisionGroupSetCollidable(PLAYER_GROUP, PLAYER_GROUP, false)
end

return AvatarService

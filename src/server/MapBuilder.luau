--!strict
-- Staví mapu z dočasných dílů: pláž, cesta, molo, vodní koridor s bójkami a značkami,
-- 8 domečků (4 + 4), stánky SHOP a SELL, kolo štěstí, žebříček a ostrůvek s obřím dárkem.
-- Hezké modely z ReplicatedStorage.Assets.Map (ShopStall, SellStall, Spinner, GiantGift, Palm, Umbrella)
-- se použijí automaticky, pokud existují (pozor: musí mít stejné pojmenované díly, viz README).

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local World = require(Shared.Config.World)
local House = require(Shared.Config.House)
local Jump = require(Shared.Config.Jump)
local SpinnerConfig = require(Shared.Config.Spinner)
local FormatNumber = require(Shared.Util.FormatNumber)
local Models = require(Shared.Models)

export type Pedestal = {
	Index: number,
	Part: BasePart,
	Prompt: ProximityPrompt,
	ItemCFrame: CFrame,
	Label: TextLabel,
}

export type HouseInfo = {
	Index: number,
	Name: string,
	Model: Model,
	Pedestals: { Pedestal },
	PiggyBank: BasePart,
	PiggyLabel: TextLabel,
	CollectPad: BasePart,
	BackCollectPad: BasePart,
	TeleportPad: BasePart,
	OwnerLabel: TextLabel,
	HouseNameLabel: TextLabel,
	Center: CFrame,
	Size: Vector3,
	Entrance: CFrame,
}

export type LeaderboardInfo = {
	TodayRows: { TextLabel },
	AllTimeRows: { TextLabel },
}

export type MapInfo = {
	Folder: Folder,
	Spawn: CFrame,
	ReturnPoint: CFrame,
	SpawnLocation: SpawnLocation,
	ShopPrompt: ProximityPrompt,
	ShopPosition: Vector3,
	SellPrompt: ProximityPrompt,
	SellTeleport: CFrame,
	SpinnerPrompt: ProximityPrompt,
	Houses: { HouseInfo },
	Leaderboard: LeaderboardInfo,
	GiftLanding: Vector3,
	GiftModel: Model,
}

local MapBuilder = {}

-- ===== Barvy =====
local SAND = Color3.fromRGB(246, 222, 160)
local SAND_DARK = Color3.fromRGB(232, 200, 130)
local WOOD = Color3.fromRGB(170, 115, 70)
local WOOD_DARK = Color3.fromRGB(125, 82, 50)
local WOOD_LIGHT = Color3.fromRGB(205, 150, 95)
local WHITE = Color3.new(1, 1, 1)
local CORAL = Color3.fromRGB(240, 80, 70)
local ROYAL = Color3.fromRGB(40, 110, 230)
local LEAF = Color3.fromRGB(70, 175, 70)
local LEAF_DARK = Color3.fromRGB(45, 140, 60)
local ROCK = Color3.fromRGB(140, 140, 150)
local BUOY_RED = Color3.fromRGB(235, 50, 55)
local WARM_LIGHT = Color3.fromRGB(255, 214, 130) -- teplé světlo v oknech a lucernách
local GOLD = Color3.fromRGB(255, 205, 50)

local BALL = Enum.PartType.Ball
local BLOCK = Enum.PartType.Block
local CYL = Enum.PartType.Cylinder
local UP = CFrame.Angles(0, 0, math.rad(90)) -- válec postavený svisle

-- ===== Pomocníci =====

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?, name: string?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Shape = shape or BLOCK
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name = name or "Part"
	p.Parent = parent
	return p
end

local function wedge(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): WedgePart
	local p = Instance.new("WedgePart")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function deco(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

-- Drobná ozdoba: bez kolizí a bez stínu (žárovky, kytky, provázky…)
local function tiny(p: BasePart): BasePart
	deco(p)
	p.CastShadow = false
	return p
end

-- Třpytky (ParticleEmitter) pro ozdoby
local function sparkles(parent: BasePart, rate: number, size: number, speed: number, color: Color3)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Sparkles"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(1, 2)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.8) })
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Parent = parent
end

local function model(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function surfaceLabel(target: BasePart, face: Enum.NormalId, text: string, textColor: Color3, strokeColor: Color3?, pixelsPerStud: number?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 40
	gui.LightInfluence = 0.3
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = textColor
	label.Parent = gui
	if strokeColor then
		local stroke = Instance.new("UIStroke")
		stroke.Color = strokeColor
		stroke.Thickness = 3
		stroke.Parent = label
	end
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)
	padding.Parent = label
	return label
end

local function billboard(adornee: Instance, offset: Vector3, size: UDim2, text: string, color: Color3, maxDistance: number?): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffsetWorldSpace = offset
	gui.AlwaysOnTop = false
	gui.MaxDistance = maxDistance or 80
	gui.LightInfluence = 0
	gui.Parent = adornee
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(30, 30, 40)
	stroke.Parent = label
	return label
end

-- Směr "přední strany" (lokální -Z) → otočení kolem Y
local function facing(position: Vector3, direction: Vector3): CFrame
	return CFrame.lookAt(position, position + Vector3.new(direction.X, 0, direction.Z))
end

-- ===== Dekorace =====

local function palm(parent: Instance, base: Vector3, height: number, lean: number, yaw: number)
	local custom = Models.MapAsset("Palm")
	if custom then
		custom:PivotTo(CFrame.new(base) * CFrame.Angles(0, yaw, 0))
		custom.Parent = parent
		return
	end
	local m = model("Palm", parent)
	local segments = 6
	local pos = base
	local dir = (CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(lean), 0, 0)).UpVector
	local segLength = height / segments
	for i = 1, segments do
		local bend = CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(lean * (0.5 + i / segments)), 0, 0)
		dir = bend.UpVector
		local nextPos = pos + dir * segLength
		local width = 2.2 - i * 0.15
		local seg = part(m, Vector3.new(segLength + 0.3, width, width), CFrame.lookAt((pos + nextPos) / 2, nextPos) * CFrame.Angles(0, math.rad(90), 0), if i % 2 == 0 then WOOD else WOOD_LIGHT, Enum.Material.Wood, CYL)
		deco(seg).CanCollide = i <= 2
		pos = nextPos
	end
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + yaw
		local leafDir = Vector3.new(math.cos(a), 0, math.sin(a))
		local leafLength = 9
		local center = pos + leafDir * (leafLength / 2 - 0.5) + Vector3.new(0, 0.2 - (i % 2) * 0.6, 0)
		local leaf = part(m, Vector3.new(3.2, 0.3, leafLength), CFrame.lookAt(center, center + leafDir) * CFrame.Angles(math.rad(-18), 0, 0), if i % 2 == 0 then LEAF else LEAF_DARK, Enum.Material.Grass)
		deco(leaf)
	end
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		deco(part(m, Vector3.one * 1.3, CFrame.new(pos + Vector3.new(math.cos(a) * 0.9, -1, math.sin(a) * 0.9)), Color3.fromRGB(110, 75, 40), Enum.Material.SmoothPlastic, BALL))
	end
end

local function umbrella(parent: Instance, base: Vector3, color: Color3, yaw: number)
	local custom = Models.MapAsset("Umbrella")
	if custom then
		custom:PivotTo(CFrame.new(base) * CFrame.Angles(0, yaw, 0))
		custom.Parent = parent
		return
	end
	local m = model("Umbrella", parent)
	local tilt = CFrame.new(base) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(8), 0, 0)
	deco(part(m, Vector3.new(9, 0.4, 0.4), tilt * CFrame.new(0, 4.5, 0) * UP, WHITE, nil, CYL))
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		deco(wedge(m, Vector3.new(3.6, 2, 4.6), tilt * CFrame.new(0, 8.4, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 2.3), if i % 2 == 0 then color else WHITE))
	end
	deco(part(m, Vector3.one * 0.8, tilt * CFrame.new(0, 9.5, 0), color, nil, BALL))
	-- ručník
	local towelColor = if yaw > 0 then Color3.fromRGB(80, 170, 255) else Color3.fromRGB(255, 120, 150)
	deco(part(m, Vector3.new(5, 0.1, 9), CFrame.new(base + Vector3.new(4, 0.05, 0)) * CFrame.Angles(0, yaw, 0), towelColor, Enum.Material.Fabric))
	deco(part(m, Vector3.new(5, 0.12, 1.2), CFrame.new(base + Vector3.new(4, 0.06, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, 2), WHITE, Enum.Material.Fabric))
end

local function rockCluster(parent: Instance, center: Vector3, scale: number, withSand: boolean, rng: Random)
	local m = model("RockIsland", parent)
	if withSand then
		deco(part(m, Vector3.new(3, scale * 3.2, scale * 3.2), CFrame.new(center + Vector3.new(0, 0.6, 0)) * UP, SAND, Enum.Material.Sand, CYL))
	end
	for i = 1, 5 do
		local offset = Vector3.new(rng:NextNumber(-1, 1) * scale * 0.7, 0, rng:NextNumber(-1, 1) * scale * 0.7)
		local size = scale * rng:NextNumber(0.6, 1.2)
		local rock = part(m, Vector3.new(size * 1.3, size * rng:NextNumber(0.8, 1.6), size), CFrame.new(center + offset + Vector3.new(0, size * 0.35, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)), ROCK:Lerp(Color3.fromRGB(110, 110, 125), rng:NextNumber()), Enum.Material.Slate, BALL)
		deco(rock)
	end
	if withSand then
		palm(m, center + Vector3.new(scale * 0.8, 1.5, scale * 0.6), scale * 0.9 + 8, 12, rng:NextNumber(0, 6))
	end
end

local function cloud(parent: Instance, center: Vector3, scale: number, rng: Random)
	local m = model("Cloud", parent)
	for i = 1, 6 do
		local offset = Vector3.new(rng:NextNumber(-1.6, 1.6) * scale, rng:NextNumber(-0.3, 0.5) * scale, rng:NextNumber(-0.7, 0.7) * scale)
		deco(part(m, Vector3.one * scale * rng:NextNumber(1.2, 2), CFrame.new(center + offset), WHITE, Enum.Material.SmoothPlastic, BALL)).CastShadow = false
	end
end

local function floatingDuck(parent: Instance, position: Vector3, scale: number)
	local m = model("FloatingDuck", parent)
	local yellow = Color3.fromRGB(255, 220, 40)
	deco(part(m, Vector3.new(4, 3, 5) * scale, CFrame.new(position + Vector3.new(0, 0.8, 0) * scale), yellow, nil, BALL))
	deco(part(m, Vector3.new(2.6, 2.6, 2.6) * scale, CFrame.new(position + Vector3.new(0, 3, -1.2) * scale), yellow, nil, BALL))
	deco(wedge(m, Vector3.new(1.2, 0.6, 1) * scale, CFrame.new(position + Vector3.new(0, 2.8, -2.8) * scale) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(255, 140, 20)))
	for _, side in { -1, 1 } do
		deco(part(m, Vector3.one * 0.5 * scale, CFrame.new(position + Vector3.new(side * 0.6, 3.4, -2.3) * scale), Color3.fromRGB(25, 25, 30), nil, BALL))
	end
end

local function floatingChest(parent: Instance, position: Vector3, yaw: number)
	local m = model("FloatingChest", parent)
	local cf = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	deco(part(m, Vector3.new(6, 3, 4), cf * CFrame.new(0, 1, 0), WOOD, Enum.Material.Wood))
	deco(part(m, Vector3.new(6, 4, 4), cf * CFrame.new(0, 2.5, 0), WOOD_DARK, Enum.Material.Wood, CYL))
	deco(part(m, Vector3.new(0.8, 1, 0.3), cf * CFrame.new(0, 2.2, -2.05), Color3.fromRGB(255, 205, 40), Enum.Material.Metal))
end

local function starfish(parent: Instance, position: Vector3, color: Color3, yaw: number)
	local m = model("Starfish", parent)
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2 + yaw
		deco(part(m, Vector3.new(0.6, 0.3, 1.6), CFrame.new(position + Vector3.new(math.cos(a) * 0.8, 0.15, math.sin(a) * 0.8)) * CFrame.Angles(0, -a + math.rad(90), 0), color))
	end
end

-- Lucerny na tyčích nad kůly mola, mezi nimi řetězy barevných žárovek a vlajky na konci mola.
-- Jen dekorace (bez kolizí), nic nepřekáží skoku: vše je po stranách mola, nad koncem nic nevisí.
local BULB_COLORS = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 210, 60), Color3.fromRGB(90, 220, 120), Color3.fromRGB(80, 180, 255), Color3.fromRGB(255, 130, 220) }

local function buildPierLights(pier: Model, startX: number, endX: number, deckY: number, width: number)
	local lights = model("PierLights", pier)
	local poleTop = deckY + 9
	local wire = Color3.fromRGB(50, 45, 40)
	local posts: { number } = {}
	local postX = startX - 10
	while postX <= endX do
		table.insert(posts, postX)
		postX += 15
	end
	for _, side in { -1, 1 } do
		local z = side * (width / 2 + 0.4)
		for index, x in posts do
			-- tenká tyč na kůlu + lucerna
			deco(part(lights, Vector3.new(poleTop - (deckY + 4), 0.4, 0.4), CFrame.new(x, (poleTop + deckY + 4) / 2, z) * UP, WOOD_DARK, Enum.Material.Wood, CYL))
			deco(part(lights, Vector3.new(1, 1.3, 1), CFrame.new(x, poleTop + 0.6, z), Color3.fromRGB(255, 225, 140), Enum.Material.Neon))
			deco(part(lights, Vector3.new(1.4, 0.3, 1.4), CFrame.new(x, poleTop + 1.4, z), wire, Enum.Material.Metal))
			-- řetěz žárovek k další tyči (prověšený do V)
			local nextX = posts[index + 1]
			if nextX then
				local sag = 1.4
				local a = Vector3.new(x, poleTop, z)
				local b = Vector3.new(nextX, poleTop, z)
				local mid = (a + b) / 2 - Vector3.new(0, sag, 0)
				for _, pair in { { a, mid }, { mid, b } } do
					local from, to = pair[1], pair[2]
					deco(part(lights, Vector3.new(0.12, 0.12, (to - from).Magnitude), CFrame.lookAt((from + to) / 2, to), wire, Enum.Material.SmoothPlastic))
				end
				for bulb = 1, 3 do
					local t = bulb / 4
					local p = a:Lerp(b, t) - Vector3.new(0, sag * (1 - math.abs(1 - 2 * t)) + 0.35, 0)
					local bulbPart = deco(part(lights, Vector3.one * 0.6, CFrame.new(p), BULB_COLORS[(index + bulb) % #BULB_COLORS + 1], Enum.Material.Neon, BALL))
					bulbPart.CastShadow = false
				end
			end
		end
	end
	-- vlajky na konci mola (vlají směrem k pláži)
	for _, side in { -1, 1 } do
		local z = side * (width / 2 + 0.4)
		local x = endX - 1
		local poleHeight = 16
		deco(part(lights, Vector3.new(poleHeight, 0.5, 0.5), CFrame.new(x, deckY + poleHeight / 2, z) * UP, WHITE, Enum.Material.Metal, CYL))
		deco(part(lights, Vector3.one * 0.9, CFrame.new(x, deckY + poleHeight + 0.3, z), Color3.fromRGB(255, 205, 40), Enum.Material.Metal, BALL))
		local flagColor = if side == 1 then CORAL else ROYAL
		deco(part(lights, Vector3.new(5.5, 3.2, 0.15), CFrame.new(x - 3, deckY + poleHeight - 1.8, z) * CFrame.Angles(0, math.rad(side * 8), 0), flagColor, Enum.Material.Fabric))
		deco(part(lights, Vector3.new(5.5, 0.8, 0.2), CFrame.new(x - 3, deckY + poleHeight - 1.8, z) * CFrame.Angles(0, math.rad(side * 8), 0), WHITE, Enum.Material.Fabric))
	end
end

-- Plavčická věž na pláži (vlevo od mola, mimo cesty a stánky)
local function lifeguardTower(parent: Instance, base: Vector3)
	local m = model("LifeguardTower", parent)
	local legHeight = 10
	local red = Color3.fromRGB(230, 60, 55)
	for _, dx in { -3.2, 3.2 } do
		for _, dz in { -3.2, 3.2 } do
			part(m, Vector3.new(0.8, legHeight, 0.8), CFrame.new(base + Vector3.new(dx, legHeight / 2, dz)), WHITE, Enum.Material.Wood, BLOCK, "Leg")
		end
	end
	local floorY = base.Y + legHeight
	part(m, Vector3.new(8, 0.6, 8), CFrame.new(base.X, floorY + 0.3, base.Z), WOOD, Enum.Material.WoodPlanks, BLOCK, "Platform")
	-- kabina s nápisem směrem k moři (+X)
	local cabin = deco(part(m, Vector3.new(5, 4.5, 6), CFrame.new(base.X - 1, floorY + 2.85, base.Z), WHITE, Enum.Material.WoodPlanks))
	surfaceLabel(cabin, Enum.NormalId.Right, "LIFEGUARD", red, WHITE, 30)
	deco(part(m, Vector3.new(5.2, 0.6, 6.2), CFrame.new(base.X - 1, floorY + 1.6, base.Z), red))
	-- sedlová střecha (hřeben podél X; vysoká strana klínu míří ke středu)
	for _, side in { -1, 1 } do
		deco(wedge(m, Vector3.new(5.8, 2, 3.4), CFrame.new(base.X - 1, floorY + 6.1, base.Z + side * 1.7) * CFrame.Angles(0, if side == 1 then math.pi else 0, 0), red))
	end
	-- zábradlí vpředu
	deco(part(m, Vector3.new(0.3, 0.3, 8), CFrame.new(base.X + 3.85, floorY + 1.8, base.Z), red))
	for _, dz in { -3.85, 3.85 } do
		deco(part(m, Vector3.new(8, 0.3, 0.3), CFrame.new(base.X, floorY + 1.8, base.Z + dz), red))
	end
	-- žebřík na straně k moři
	for _, dz in { -0.9, 0.9 } do
		deco(part(m, Vector3.new(0.3, legHeight + 1, 0.3), CFrame.new(base.X + 4.3, base.Y + (legHeight + 1) / 2, base.Z + dz), WOOD_LIGHT, Enum.Material.Wood))
	end
	for rung = 1, 5 do
		deco(part(m, Vector3.new(0.25, 0.25, 1.8), CFrame.new(base.X + 4.3, base.Y + rung * 1.8, base.Z), WOOD_LIGHT, Enum.Material.Wood))
	end
	-- vlajka
	deco(part(m, Vector3.new(6, 0.25, 0.25), CFrame.new(base.X - 3, floorY + 8, base.Z + 2.6) * UP, WHITE, Enum.Material.Metal, CYL))
	deco(part(m, Vector3.new(2.8, 1.8, 0.12), CFrame.new(base.X - 1.5, floorY + 10, base.Z + 2.6), red, Enum.Material.Fabric))
	-- záchranný kruh na noze
	deco(part(m, Vector3.new(0.5, 2.4, 2.4), CFrame.new(base.X + 3.75, base.Y + 5, base.Z - 3.2), Color3.fromRGB(255, 120, 40), nil, CYL))
	deco(part(m, Vector3.new(0.55, 1.2, 1.2), CFrame.new(base.X + 3.75, base.Y + 5, base.Z - 3.2), WHITE, nil, CYL))
end

-- ===== Pláž, cesta, molo =====

local function buildBeach(root: Instance, rng: Random): Model
	local beach = model("Beach", root)
	beach.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local front, back = World.BeachFrontX, World.BeachBackX
	local halfWidth = World.BeachHalfWidth
	local sandThickness = 6
	local length = front - back
	-- písek (díly max. 2048)
	part(beach, Vector3.new(length, sandThickness, halfWidth * 2), CFrame.new((front + back) / 2, World.SandY - sandThickness / 2, 0), SAND, Enum.Material.Sand, BLOCK, "Sand")
	-- svah do vody
	local slope = wedge(beach, Vector3.new(halfWidth * 2, sandThickness + 2, 30), CFrame.new(front + 15, World.SandY - (sandThickness + 2) / 2, 0) * CFrame.Angles(0, math.rad(-90), 0), SAND_DARK, Enum.Material.Sand)
	slope.Name = "Shore"
	-- mokrý písek podél vody
	deco(part(beach, Vector3.new(8, 0.2, halfWidth * 2), CFrame.new(front - 4, World.SandY + 0.05, 0), SAND_DARK, Enum.Material.Sand))

	-- cesta z prken od spawnu na molo
	local pathStart = World.SpawnX - 40
	local pathEnd = World.BeachFrontX
	local pathLength = pathEnd - pathStart
	local path = part(beach, Vector3.new(pathLength, 0.4, World.PathHalfWidth * 2 - 4), CFrame.new((pathStart + pathEnd) / 2, World.SandY + 0.2, 0), WOOD_LIGHT, Enum.Material.WoodPlanks, BLOCK, "Path")
	path.CanCollide = true
	-- plot z kůlů a provazu podél cesty (mezi domečky)
	for _, side in { -1, 1 } do
		local z = side * (World.PathHalfWidth - 0.5)
		-- jen podél domečků, aby se ke stánkům a kolu dalo volně dojít
		local fenceFrom = World.SpawnX + 50
		local fenceTo = World.SpawnX + 40 + House.Length - 6
		local x = fenceFrom
		while x <= fenceTo do
			deco(part(beach, Vector3.new(4, 1.2, 1.2), CFrame.new(x, World.SandY + 2, z) * UP, WOOD_DARK, Enum.Material.Wood, CYL))
			x += 16
		end
		deco(part(beach, Vector3.new(fenceTo - fenceFrom, 0.25, 0.25), CFrame.new((fenceFrom + fenceTo) / 2, World.SandY + 3.3, z), Color3.fromRGB(200, 170, 120), Enum.Material.Fabric, CYL))
	end

	-- palmy a deštníky
	for i = 1, 26 do
		local side = if i % 2 == 0 then 1 else -1
		local x = rng:NextNumber(back + 20, front - 20)
		local z = side * rng:NextNumber(175, halfWidth - 20)
		palm(beach, Vector3.new(x, World.SandY, z), rng:NextNumber(16, 26), rng:NextNumber(6, 18), rng:NextNumber(0, math.pi * 2))
	end
	for _, pos in { Vector3.new(-50240, 0, 120), Vector3.new(-50280, 0, -195), Vector3.new(-50200, 0, -110), Vector3.new(-50360, 0, 190), Vector3.new(-50480, 0, 90), Vector3.new(-50490, 0, -110) } do
		local palmBase = Vector3.new(pos.X, World.SandY, pos.Z + 12)
		palm(beach, palmBase, rng:NextNumber(18, 24), rng:NextNumber(8, 14), rng:NextNumber(0, 6))
	end
	local umbrellaColors = { CORAL, ROYAL, Color3.fromRGB(150, 90, 230), Color3.fromRGB(255, 170, 40) }
	for i, pos in { Vector3.new(-50215, 0, -30), Vector3.new(-50230, 0, 40), Vector3.new(-50470, 0, 45), Vector3.new(-50350, 0, -200), Vector3.new(-50195, 0, 160), Vector3.new(-50510, 0, 35), Vector3.new(-50505, 0, -55) } do
		umbrella(beach, Vector3.new(pos.X, World.SandY, pos.Z), umbrellaColors[(i % #umbrellaColors) + 1], rng:NextNumber(-0.5, 0.5))
	end
	-- hvězdice, pískový hrad, kameny
	for i = 1, 30 do
		local colors = { Color3.fromRGB(255, 120, 80), Color3.fromRGB(255, 90, 120), Color3.fromRGB(255, 170, 60) }
		starfish(beach, Vector3.new(rng:NextNumber(back + 10, front - 5), World.SandY, rng:NextNumber(-halfWidth + 10, halfWidth - 10)), colors[(i % 3) + 1], rng:NextNumber(0, 6))
	end
	local castle = model("SandCastle", beach)
	local castlePos = Vector3.new(-50225, World.SandY, 95)
	deco(part(castle, Vector3.new(8, 4, 8), CFrame.new(castlePos + Vector3.new(0, 2, 0)), SAND_DARK, Enum.Material.Sand))
	for _, offset in { Vector3.new(-4, 0, -4), Vector3.new(4, 0, -4), Vector3.new(-4, 0, 4), Vector3.new(4, 0, 4) } do
		deco(part(castle, Vector3.new(7, 3, 3), CFrame.new(castlePos + offset + Vector3.new(0, 3.5, 0)) * UP, SAND_DARK, Enum.Material.Sand, CYL))
	end
	deco(part(castle, Vector3.new(5, 4, 4), CFrame.new(castlePos + Vector3.new(0, 6, 0)) * UP, SAND_DARK, Enum.Material.Sand, CYL))
	deco(part(castle, Vector3.new(0.2, 3, 0.2), CFrame.new(castlePos + Vector3.new(0, 9.5, 0)), WHITE))
	deco(wedge(castle, Vector3.new(0.1, 1, 1.5), CFrame.new(castlePos + Vector3.new(0, 10.3, -0.8)), CORAL))
	-- plavčická věž u vody (vlevo, daleko od domečků, stánků a cesty)
	lifeguardTower(beach, Vector3.new(World.BeachFrontX - 25, World.SandY, -150))
	return beach
end

local function buildPier(root: Instance): Model
	local pier = model("Pier", root)
	pier.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local endX = World.PierEndX
	local startX = endX - World.PierLength
	local deckY = World.PierDeckY
	local width = World.PierWidth
	-- prkna
	local x = startX - 12
	local i = 0
	while x < endX do
		local plankLength = math.min(2, endX - x)
		local plank = part(pier, Vector3.new(plankLength - 0.15, 1, width), CFrame.new(x + plankLength / 2, deckY - 0.5, 0), if i % 3 == 0 then WOOD_LIGHT else WOOD, Enum.Material.Wood, BLOCK, "Plank")
		plank.CanQuery = true
		x += plankLength
		i += 1
	end
	-- nájezd z písku
	local rampLength = 14
	wedge(pier, Vector3.new(width, deckY - World.SandY, rampLength), CFrame.new(startX - 12 - rampLength / 2, (deckY + World.SandY) / 2, 0) * CFrame.Angles(0, math.rad(90), 0), WOOD, Enum.Material.Wood).Name = "Ramp"
	-- kůly a zábradlí z provazu
	local postX = startX - 10
	while postX <= endX do
		for _, side in { -1, 1 } do
			deco(part(pier, Vector3.new(deckY + 6, 1.6, 1.6), CFrame.new(postX, (deckY + 4) / 2 - 1, side * (width / 2 + 0.4)) * UP, WOOD_DARK, Enum.Material.Wood, CYL))
		end
		postX += 15
	end
	for _, side in { -1, 1 } do
		deco(part(pier, Vector3.new(World.PierLength + 10, 0.3, 0.3), CFrame.new(startX - 5 + (World.PierLength + 10) / 2, deckY + 2.5, side * (width / 2 + 0.4)), Color3.fromRGB(200, 170, 120), Enum.Material.Fabric, CYL))
	end
	-- konec mola: značka odrazu (neviditelná oblast pro klienta a tutoriál)
	local zone = part(pier, Vector3.new(Jump.JumpZoneLength, 8, width), CFrame.new(endX - Jump.JumpZoneLength / 2, deckY + 4, 0), Color3.fromRGB(80, 255, 120), nil, BLOCK, "JumpZone")
	zone.Transparency = 1
	zone.CanCollide = false
	zone.CanQuery = false
	zone.CanTouch = false
	CollectionService:AddTag(zone, "JumpZone")
	-- světlá čára na konci
	deco(part(pier, Vector3.new(1, 0.1, width), CFrame.new(endX - 0.6, deckY + 0.02, 0), WHITE, Enum.Material.Neon))
	-- neviditelné zábrany po stranách mola (aby hráč nespadl do vody)
	for _, side in { -1, 1 } do
		local wall = part(pier, Vector3.new(World.PierLength, 10, 1), CFrame.new(startX + World.PierLength / 2, deckY + 5, side * (width / 2 + 1)), WHITE, nil, BLOCK, "Rail")
		wall.Transparency = 1
	end
	buildPierLights(pier, startX, endX, deckY, width)
	return pier
end

-- ===== Voda, bójky, značky =====

local function markerDistances(): { number }
	local list = {}
	local previous = 0
	for _, range in World.MarkerRanges do
		local d = previous + range.Step
		while d <= range.UpTo do
			table.insert(list, d)
			d += range.Step
		end
		previous = range.UpTo
	end
	return list
end

local function buildWater(root: Instance, rng: Random)
	local water = Instance.new("Folder")
	water.Name = "Water"
	water.Parent = root
	-- skutečná Roblox voda u pláže (vlny, odlesky, průhledná na písčité dno)
	local terrain = workspace.Terrain
	local fromX = World.BeachBackX - 250
	local toX = World.PierEndX + World.TerrainWaterLength
	local depth = World.TerrainWaterDepth
	local tx = fromX
	while tx < toX do
		local length = math.min(512, toX - tx)
		local z = -World.WaterHalfWidth
		while z < World.WaterHalfWidth do
			local width = math.min(512, World.WaterHalfWidth - z)
			terrain:FillBlock(CFrame.new(tx + length / 2, World.WaterY - depth / 2, z + width / 2), Vector3.new(length, depth, width), Enum.Material.Water)
			-- písčité dno
			terrain:FillBlock(CFrame.new(tx + length / 2, World.WaterY - depth - 2, z + width / 2), Vector3.new(length, 4, width), Enum.Material.Sand)
			z += width
		end
		tx += length
	end
	-- pod pláží žádná voda (jen písek)
	terrain:FillBlock(CFrame.new((World.BeachFrontX + World.BeachBackX) / 2, World.WaterY - depth / 2, 0), Vector3.new(World.BeachFrontX - World.BeachBackX, depth, World.BeachHalfWidth * 2), Enum.Material.Sand)
	-- mělčina u břehu
	terrain:FillWedge(CFrame.new(World.BeachFrontX + 40, World.WaterY - depth + 3, 0) * CFrame.Angles(0, math.rad(-90), 0), Vector3.new(World.BeachHalfWidth * 2, 6, 80), Enum.Material.Sand)
	terrain.WaterColor = Color3.fromRGB(40, 200, 220)
	terrain.WaterTransparency = 0.55
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.18
	terrain.WaterWaveSpeed = 9

	local startDistance = World.TerrainWaterLength
	local previous = startDistance
	for _, zone in World.WaterZones do
		local d = previous
		while d < zone.UpTo do
			local chunk = math.min(2000, zone.UpTo - d)
			local p = part(water, Vector3.new(chunk, 4, World.WaterHalfWidth * 2), CFrame.new(World.PierEndX + d + chunk / 2, World.WaterY - 2, 0), zone.Color, Enum.Material.SmoothPlastic, BLOCK, "Water")
			p.Reflectance = 0.08
			p.CastShadow = false
			d += chunk
		end
		previous = zone.UpTo
	end

	-- bójky podél koridoru
	local buoys = Instance.new("Folder")
	buoys.Name = "Buoys"
	buoys.Parent = root
	local half = Jump.Flight.CorridorHalfWidth
	local previousRange = 0
	for _, range in World.BuoyRanges do
		local d = previousRange + range.Step
		while d <= range.UpTo do
			for _, side in { -1, 1 } do
				local m = model("Buoy", buoys)
				local pos = Vector3.new(World.PierEndX + d, World.WaterY + 0.8, side * half)
				deco(part(m, Vector3.one * 3.2, CFrame.new(pos), BUOY_RED, nil, BALL))
				deco(part(m, Vector3.new(1.2, 2.2, 2.2), CFrame.new(pos + Vector3.new(0, 1.5, 0)) * UP, WHITE, nil, CYL))
			end
			d += range.Step
		end
		previousRange = range.UpTo
	end

	-- provazy s bójkami a cedulemi na značkách
	local markers = Instance.new("Folder")
	markers.Name = "Markers"
	markers.Parent = root
	for _, distance in markerDistances() do
		local m = model("Marker_" .. distance, markers)
		local x = World.PierEndX + distance
		deco(part(m, Vector3.new(half * 2, 0.5, 0.5), CFrame.new(x, World.WaterY + 0.6, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(200, 170, 120), Enum.Material.Fabric, CYL))
		for i = -3, 3 do
			deco(part(m, Vector3.one * 1.8, CFrame.new(x, World.WaterY + 0.6, i * half / 4), if i % 2 == 0 then WHITE else BUOY_RED, nil, BALL))
		end
		-- dřevěná cedule s číslem (plovoucí uprostřed)
		local width = if distance >= 10_000 then 16 else 13
		local float = deco(part(m, Vector3.new(4, 1.4, width + 2), CFrame.new(x, World.WaterY + 0.4, 0), WOOD_DARK, Enum.Material.Wood))
		local sign = part(m, Vector3.new(0.8, 5, width), CFrame.new(x, World.WaterY + 3.6, 0), WOOD, Enum.Material.Wood, BLOCK, "Sign")
		deco(sign)
		local text = if distance >= 10_000 then FormatNumber.Short(distance) else FormatNumber.Commas(distance)
		surfaceLabel(sign, Enum.NormalId.Left, text, WHITE, Color3.fromRGB(70, 40, 20), 30)
		surfaceLabel(sign, Enum.NormalId.Right, text, WHITE, Color3.fromRGB(70, 40, 20), 30)
		float.Name = "Float"
	end

	-- skalnaté ostrůvky, kachny a truhly ve vodě kolem koridoru
	local props = Instance.new("Folder")
	props.Name = "OceanProps"
	props.Parent = root
	for i = 1, 16 do
		local side = if i % 2 == 0 then 1 else -1
		local d = rng:NextNumber(150, 2500)
		rockCluster(props, Vector3.new(World.PierEndX + d, World.WaterY, side * rng:NextNumber(180, 900)), rng:NextNumber(10, 28), i % 3 ~= 0, rng)
	end
	for i = 1, 14 do
		local side = if i % 2 == 0 then 1 else -1
		floatingDuck(props, Vector3.new(World.PierEndX + rng:NextNumber(40, 1500), World.WaterY, side * rng:NextNumber(70, 450)), rng:NextNumber(0.9, 1.6))
	end
	for i = 1, 8 do
		local side = if i % 2 == 0 then 1 else -1
		floatingChest(props, Vector3.new(World.PierEndX + rng:NextNumber(100, 1800), World.WaterY - 0.8, side * rng:NextNumber(80, 500)), rng:NextNumber(0, 6))
	end
	for i = 1, 22 do
		cloud(props, Vector3.new(World.PierEndX + rng:NextNumber(-600, 6000), rng:NextNumber(220, 420), rng:NextNumber(-900, 900)), rng:NextNumber(14, 30), rng)
	end
end

-- ===== Domečky =====

local function buildHouse(root: Instance, index: number, frontX: number, zCenter: number): HouseInfo
	local name = House.Names[index] or ("House " .. index)
	local color = House.Colors[index] or WHITE
	local roofColor = color:Lerp(Color3.new(1, 1, 1), 0.25)
	local trim = WHITE
	local m = model("House_" .. index, root)
	m:SetAttribute("HouseIndex", index)
	m:SetAttribute("OwnerUserId", 0)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local W, L, H = House.Width, House.Length, House.WallHeight
	local floorY = World.SandY
	local backX = frontX + L
	local centerX = frontX + L / 2
	local entranceWidth = 16

	-- podlaha
	part(m, Vector3.new(L, 1, W), CFrame.new(centerX, floorY + 0.5, zCenter), Color3.fromRGB(235, 205, 160), Enum.Material.WoodPlanks, BLOCK, "Floor")
	-- boční stěny
	for _, side in { -1, 1 } do
		part(m, Vector3.new(L, H, 1), CFrame.new(centerX, floorY + 1 + H / 2, zCenter + side * (W / 2 - 0.5)), color, Enum.Material.WoodPlanks, BLOCK, "Wall")
		-- bílé lemování
		deco(part(m, Vector3.new(L + 0.2, 0.8, 1.3), CFrame.new(centerX, floorY + 1 + H, zCenter + side * (W / 2 - 0.5)), trim))
		-- okna: bílý rám, teple svítící sklo a příčka
		for w = 0, 2 do
			local windowCF = CFrame.new(frontX + 25 + w * 32, floorY + 1 + H * 0.6, zCenter + side * (W / 2 - 0.5))
			deco(part(m, Vector3.new(9.6, 6.6, 1.3), windowCF, trim))
			local window = deco(part(m, Vector3.new(8, 5, 1.5), windowCF, WARM_LIGHT, Enum.Material.Neon))
			window.Transparency = 0.25
			window.CastShadow = false
			tiny(part(m, Vector3.new(0.4, 5, 1.7), windowCF, trim))
		end
	end
	-- přední i zadní stěna s širokým vchodem (domeček je průchozí z obou stran)
	local sideWidth = (W - entranceWidth) / 2
	local lintelHeight = 3
	for _, wallX in { frontX + 0.5, backX - 0.5 } do
		local trimX = if wallX < centerX then wallX - 0.2 else wallX + 0.2
		for _, side in { -1, 1 } do
			part(m, Vector3.new(1, H, sideWidth), CFrame.new(wallX, floorY + 1 + H / 2, zCenter + side * (entranceWidth / 2 + sideWidth / 2)), color, Enum.Material.WoodPlanks, BLOCK, "Wall")
			deco(part(m, Vector3.new(1.4, H, 1), CFrame.new(trimX, floorY + 1 + H / 2, zCenter + side * (entranceWidth / 2 + 0.5)), trim))
		end
		part(m, Vector3.new(1, lintelHeight, entranceWidth), CFrame.new(wallX, floorY + 1 + H - lintelHeight / 2, zCenter), color, Enum.Material.WoodPlanks, BLOCK, "Wall")
	end
	-- schůdek u obou vchodů (podlaha je o 1 stud výš než písek)
	for _, stepX in { frontX - 1.5, backX + 1.5 } do
		local step = Instance.new("WedgePart")
		step.Anchored = true
		step.Size = Vector3.new(entranceWidth, 1, 3)
		step.CFrame = CFrame.new(stepX, floorY + 0.5, zCenter) * CFrame.Angles(0, if stepX < centerX then math.rad(90) else math.rad(-90), 0)
		step.Color = Color3.fromRGB(235, 205, 160)
		step.Material = Enum.Material.WoodPlanks
		step.Parent = m
	end
	-- štíty (trojúhelníky nad přední a zadní stěnou)
	local gableHeight = 9
	for _, gx in { frontX + 0.5, backX - 0.5 } do
		for _, side in { -1, 1 } do
			local cf = CFrame.new(gx, floorY + 1 + H + gableHeight / 2, zCenter + side * W / 4)
			if side == 1 then
				cf *= CFrame.Angles(0, math.pi, 0)
			end
			wedge(m, Vector3.new(1, gableHeight, W / 2), cf, color, Enum.Material.WoodPlanks)
		end
	end
	-- střecha (dvě šikmé desky)
	local roofAngle = math.atan2(gableHeight, W / 2)
	local slopeLength = math.sqrt((W / 2) ^ 2 + gableHeight ^ 2) + 2
	for _, side in { -1, 1 } do
		local cf = CFrame.new(centerX, floorY + 1 + H + gableHeight / 2 + 0.6, zCenter + side * W / 4) * CFrame.Angles(side * roofAngle, 0, 0)
		part(m, Vector3.new(L + 3, 1, slopeLength), cf, roofColor, Enum.Material.SmoothPlastic, BLOCK, "Roof")
	end
	deco(part(m, Vector3.new(L + 3.4, 1.4, 1.4), CFrame.new(centerX, floorY + 1 + H + gableHeight + 0.4, zCenter), trim, nil, CYL))

	-- cedule nad vchodem: název domečku + jméno hráče
	local sign = part(m, Vector3.new(0.6, 6, 18), CFrame.new(frontX - 0.2, floorY + 1 + H + 3.2, zCenter), WHITE, Enum.Material.SmoothPlastic, BLOCK, "Sign")
	deco(sign)
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Left
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.PixelsPerStud = 40
	signGui.LightInfluence = 0.2
	signGui.Parent = sign
	local houseNameLabel = Instance.new("TextLabel")
	houseNameLabel.BackgroundTransparency = 1
	houseNameLabel.Size = UDim2.fromScale(1, 0.4)
	houseNameLabel.Font = Enum.Font.FredokaOne
	houseNameLabel.TextScaled = true
	houseNameLabel.Text = name
	houseNameLabel.TextColor3 = color:Lerp(Color3.new(0, 0, 0), 0.35)
	houseNameLabel.Parent = signGui
	local ownerLabel = Instance.new("TextLabel")
	ownerLabel.BackgroundTransparency = 1
	ownerLabel.Position = UDim2.fromScale(0, 0.4)
	ownerLabel.Size = UDim2.fromScale(1, 0.6)
	ownerLabel.Font = Enum.Font.FredokaOne
	ownerLabel.TextScaled = true
	ownerLabel.Text = "Free House"
	ownerLabel.TextColor3 = Color3.fromRGB(40, 40, 50)
	ownerLabel.Parent = signGui
	local ownerPadding = Instance.new("UIPadding")
	ownerPadding.PaddingLeft = UDim.new(0.05, 0)
	ownerPadding.PaddingRight = UDim.new(0.05, 0)
	ownerPadding.PaddingBottom = UDim.new(0.08, 0)
	ownerPadding.Parent = ownerLabel

	-- podstavce: liché vlevo, sudé vpravo, od vchodu dozadu
	local pedestals: { Pedestal } = {}
	for slot = 1, House.MaxSlots do
		local side = if slot % 2 == 1 then -1 else 1
		local row = math.ceil(slot / 2) - 1
		local px = frontX + 16 + row * 9
		local pz = zCenter + side * (W / 2 - 5)
		local base = part(m, Vector3.new(5, 2.4, 5), CFrame.new(px, floorY + 1 + 1.2, pz), Color3.fromRGB(250, 245, 235), Enum.Material.SmoothPlastic, BLOCK, "Pedestal_" .. slot)
		local top = deco(part(m, Vector3.new(5.4, 0.3, 5.4), CFrame.new(px, floorY + 1 + 2.55, pz), color, Enum.Material.SmoothPlastic))
		top.Name = "Top"
		top.Parent = base
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SlotPrompt"
		prompt.ActionText = "Pick Up"
		prompt.ObjectText = ""
		prompt.HoldDuration = House.PickHoldTime
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Enabled = true -- klient ji lokálně skryje v cizích domečcích
		prompt:SetAttribute("Active", false)
		prompt:SetAttribute("HouseIndex", index)
		prompt:SetAttribute("Slot", slot)
		prompt.Parent = base
		CollectionService:AddTag(prompt, "HousePrompt")
		local label = billboard(base, Vector3.new(0, 7.5, 0), UDim2.fromOffset(160, 50), "", Color3.fromRGB(120, 255, 120), 50)
		table.insert(pedestals, {
			Index = slot,
			Part = base :: BasePart,
			Prompt = prompt,
			ItemCFrame = CFrame.new(px, floorY + 1 + 2.4 + 2.6, pz) * CFrame.Angles(0, if side == -1 then math.rad(-90) else math.rad(90), 0),
			Label = label,
		})
	end

	-- kasička u vchodu
	local piggyPos = Vector3.new(frontX + 6, floorY + 1, zCenter - entranceWidth / 2 - 2)
	local piggyModel = model("PiggyBank", m)
	local stand = part(piggyModel, Vector3.new(4, 2, 4), CFrame.new(piggyPos + Vector3.new(0, 1, 0)), WOOD, Enum.Material.Wood, BLOCK, "Stand")
	stand.CanCollide = true
	local pink = Color3.fromRGB(255, 150, 185)
	local body = part(piggyModel, Vector3.new(4.4, 3.4, 3.4), CFrame.new(piggyPos + Vector3.new(0, 3.7, 0)), pink, nil, BALL, "Body")
	deco(body)
	deco(part(piggyModel, Vector3.new(0.6, 1.4, 1.4), CFrame.new(piggyPos + Vector3.new(-2.25, 3.7, 0)), Color3.fromRGB(255, 120, 160), nil, CYL))
	for _, s in { -1, 1 } do
		deco(wedge(piggyModel, Vector3.new(0.3, 0.9, 0.9), CFrame.new(piggyPos + Vector3.new(-1.2, 5.4, s * 0.8)) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(255, 120, 160)))
		deco(part(piggyModel, Vector3.one * 0.45, CFrame.new(piggyPos + Vector3.new(-1.9, 4.3, s * 0.7)), Color3.fromRGB(30, 30, 35), nil, BALL))
	end
	deco(part(piggyModel, Vector3.new(0.3, 0.3, 1.4), CFrame.new(piggyPos + Vector3.new(0, 5.4, 0)), Color3.fromRGB(80, 50, 60)))
	local piggyLabel = billboard(body, Vector3.new(0, 4.5, 0), UDim2.fromOffset(200, 60), "$0", Color3.fromRGB(255, 230, 90), 90)
	CollectionService:AddTag(body, "PiggyBank")
	body:SetAttribute("HouseIndex", index)

	-- neviditelná oblast vchodu: projde → vybere kasičku
	local collectPad = part(m, Vector3.new(8, 7, entranceWidth + 8), CFrame.new(frontX + 4, floorY + 4.5, zCenter), Color3.new(1, 1, 0), nil, BLOCK, "CollectPad")
	collectPad.Transparency = 1
	collectPad.CanCollide = false
	collectPad.CanQuery = false
	-- i u zadního vchodu
	local backCollectPad = collectPad:Clone()
	backCollectPad.Name = "BackCollectPad"
	backCollectPad.CFrame = CFrame.new(backX - 4, floorY + 4.5, zCenter)
	backCollectPad.Parent = m

	-- zelené teleportační kolečko u zadní stěny → stánek SELL
	-- v rohu u zadního vchodu, aby přes něj nikdo nešel omylem
	local padPos = Vector3.new(backX - 6, floorY + 1.1, zCenter + W / 2 - 5)
	local teleportPad = part(m, Vector3.new(0.3, 6, 6), CFrame.new(padPos) * UP, Color3.fromRGB(60, 255, 110), Enum.Material.Neon, CYL, "TeleportPad")
	teleportPad.CanCollide = false
	local ring = deco(part(m, Vector3.new(0.2, 7.2, 7.2), CFrame.new(padPos - Vector3.new(0, 0.05, 0)) * UP, WHITE, nil, CYL))
	ring.Name = "PadRing"
	local padLight = Instance.new("PointLight")
	padLight.Color = Color3.fromRGB(80, 255, 120)
	padLight.Range = 14
	padLight.Parent = teleportPad
	billboard(teleportPad, Vector3.new(0, 4, 0), UDim2.fromOffset(180, 40), "To SELL", Color3.fromRGB(120, 255, 150), 60)

	-- ===== Ozdoby domečku =====
	-- Vše jen dekorace bez kolizí. Nic nestojí ve vchodu (z = ±8), na podstavcích, u kasičky ani na teleportu.
	local darkColor = color:Lerp(Color3.new(0, 0, 0), 0.3)
	local flowerColors = { Color3.fromRGB(255, 90, 140), Color3.fromRGB(255, 220, 60), Color3.fromRGB(255, 110, 70), Color3.fromRGB(190, 110, 255), WHITE }
	-- přední (outward = -1) i zadní (outward = 1) průčelí – zadní je vidět ze spawnu
	for _, facadeInfo in { { frontX + 0.5, -1 }, { backX - 0.5, 1 } } do
		local wallX, outward = facadeInfo[1], facadeInfo[2]
		local outerX = wallX + outward * 0.5
		for _, s in { -1, 1 } do
			-- okno s truhlíkem plným kytek po každé straně vchodu
			local wz = zCenter + s * 12.5
			local windowCF = CFrame.new(wallX, floorY + 9.5, wz)
			deco(part(m, Vector3.new(1.3, 5.6, 5), windowCF, trim))
			local pane = deco(part(m, Vector3.new(1.5, 4.4, 3.8), windowCF, WARM_LIGHT, Enum.Material.Neon))
			pane.Transparency = 0.25
			pane.CastShadow = false
			deco(part(m, Vector3.new(1.4, 1.2, 5.2), CFrame.new(outerX + outward * 0.7, floorY + 6.6, wz), darkColor, Enum.Material.Wood))
			for f = -1, 1, 2 do
				tiny(part(m, Vector3.one * 1.5, CFrame.new(outerX + outward * 0.7, floorY + 7.6, wz + f * 1.3), flowerColors[(index + f + s + 2) % #flowerColors + 1], Enum.Material.SmoothPlastic, BALL))
			end
			-- svítící lucerna na zdi vedle vchodu
			tiny(part(m, Vector3.new(0.9, 1.3, 0.9), CFrame.new(outerX + outward * 0.85, floorY + 11.2, zCenter + s * 9.2), WARM_LIGHT, Enum.Material.Neon))
			-- květináč s kulatým keříkem (vedle schůdku, mimo vchod)
			local potPos = Vector3.new(outerX + outward * 2, floorY, zCenter + s * (entranceWidth / 2 + 3))
			deco(part(m, Vector3.new(2.4, 2.4, 2.4), CFrame.new(potPos + Vector3.new(0, 1.2, 0)) * UP, Color3.fromRGB(200, 110, 70), nil, CYL))
			deco(part(m, Vector3.one * 2.8, CFrame.new(potPos + Vector3.new(0, 3.3, 0)), if s == 1 then LEAF else LEAF_DARK, Enum.Material.Grass, BALL))
		end
		-- pruhovaná stříška nad vchodem (barva domečku + bílá)
		local tilt = CFrame.Angles(0, 0, -outward * math.rad(22))
		for stripe = 0, 3 do
			deco(part(m, Vector3.new(5, 0.35, 5), CFrame.new(outerX + outward * 2.3, floorY + 14.6, zCenter - 7.5 + stripe * 5) * tilt, if stripe % 2 == 0 then color else trim))
		end
		-- rohožka před schůdkem (placatá, nepřekáží)
		tiny(part(m, Vector3.new(3, 0.12, 9), CFrame.new(outerX + outward * 4.6, floorY + 0.06, zCenter), darkColor, Enum.Material.Fabric))
	end
	-- barevné žárovky podél hran střechy na obou štítech
	local roofTopY = floorY + 1 + H + gableHeight / 2 + 0.6 + 0.5 / math.cos(roofAngle)
	for _, edgeX in { frontX - 1.5, backX + 1.5 } do
		for _, s in { -1, 1 } do
			for b = 0, 3 do
				local zOffset = 15 - b * 4.2
				local bulbY = roofTopY + (W / 4 - zOffset) * math.tan(roofAngle)
				tiny(part(m, Vector3.one * 0.8, CFrame.new(edgeX, bulbY, zCenter + s * zOffset), BULB_COLORS[(b + index + (if s == 1 then 2 else 0)) % #BULB_COLORS + 1], Enum.Material.Neon, BALL))
			end
		end
	end
	-- komín s kouřem (na střeše vzadu)
	-- (spodek komína sedí přesně na střeše, aby nečouhal dovnitř domečku)
	local chimneyCF = CFrame.new(backX - 22, floorY + 1 + H + 10.2, zCenter + 7)
	deco(part(m, Vector3.new(4, 9, 3), chimneyCF, Color3.fromRGB(190, 90, 70), Enum.Material.Brick))
	local chimneyCap = deco(part(m, Vector3.new(5, 1, 4), chimneyCF * CFrame.new(0, 5, 0), Color3.fromRGB(80, 70, 70)))
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Rate = 1.5
	smoke.Lifetime = NumberRange.new(3, 4)
	smoke.Speed = NumberRange.new(3, 5)
	smoke.SpreadAngle = Vector2.new(10, 10)
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 5) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	smoke.Color = ColorSequence.new(Color3.fromRGB(240, 240, 245))
	smoke.Parent = chimneyCap

	return {
		Index = index,
		Name = name,
		Model = m,
		Pedestals = pedestals,
		PiggyBank = body,
		PiggyLabel = piggyLabel,
		CollectPad = collectPad,
		BackCollectPad = backCollectPad,
		TeleportPad = teleportPad,
		OwnerLabel = ownerLabel,
		HouseNameLabel = houseNameLabel,
		Center = CFrame.new(centerX, floorY + 1 + H / 2, zCenter),
		Size = Vector3.new(L, H + 2, W),
		Entrance = CFrame.lookAt(Vector3.new(frontX - 6, floorY + 3, zCenter), Vector3.new(frontX + 10, floorY + 3, zCenter)),
	}
end

-- ===== Stánky =====

local function buildStall(root: Instance, name: string, text: string, stripeColor: Color3, origin: CFrame, rng: Random): (Model, BasePart)
	local custom = Models.MapAsset(if name == "SHOP" then "ShopStall" else "SellStall")
	if custom then
		custom:PivotTo(origin)
		custom.Parent = root
		local counter = custom:FindFirstChild("Counter", true)
		if counter and counter:IsA("BasePart") then
			return custom, counter
		end
		warn("[MapBuilder] Custom stall model needs a part called 'Counter'")
		custom:Destroy()
	end
	local m = model(name .. "Stall", root)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local y = World.SandY
	-- pult
	local counter = part(m, Vector3.new(18, 4.5, 5), origin * CFrame.new(0, y + 2.25, -3), WOOD, Enum.Material.Wood, BLOCK, "Counter")
	deco(part(m, Vector3.new(19, 0.6, 6), origin * CFrame.new(0, y + 4.8, -3), WOOD_LIGHT, Enum.Material.Wood))
	-- zadní stěna a sloupky
	part(m, Vector3.new(18, 12, 1), origin * CFrame.new(0, y + 6, 5), WOOD_DARK, Enum.Material.WoodPlanks, BLOCK, "Back")
	for _, sx in { -9, 9 } do
		for _, sz in { -5, 5 } do
			part(m, Vector3.new(1, 13, 1), origin * CFrame.new(sx, y + 6.5, sz), WOOD_DARK, Enum.Material.Wood, BLOCK, "Post")
		end
	end
	-- pruhovaná markýza
	local stripes = 10
	for i = 0, stripes - 1 do
		local sx = -10 + (i + 0.5) * (20 / stripes)
		deco(part(m, Vector3.new(20 / stripes, 0.5, 13), origin * CFrame.new(sx, y + 13.6, -0.5) * CFrame.Angles(math.rad(-14), 0, 0), if i % 2 == 0 then stripeColor else WHITE))
		deco(wedge(m, Vector3.new(20 / stripes, 1.4, 0.6), origin * CFrame.new(sx, y + 11.6, -7) * CFrame.Angles(math.rad(180), 0, 0), if i % 2 == 0 then stripeColor else WHITE))
	end
	-- cedule s nápisem
	local sign = part(m, Vector3.new(14, 4.5, 0.8), origin * CFrame.new(0, y + 17, -1), WOOD, Enum.Material.Wood, BLOCK, "Sign")
	deco(sign)
	surfaceLabel(sign, Enum.NormalId.Front, text, WHITE, Color3.fromRGB(70, 40, 20), 40)
	deco(part(m, Vector3.new(15, 5.3, 0.6), origin * CFrame.new(0, y + 17, -0.7), stripeColor))
	-- zboží na pultu
	if name == "SHOP" then
		local ids = { "BeachBlueSlippers", "WatermelonSlippers", "SharkSlippers", "RubberDuckSlippers", "PineappleSlippers", "RainbowSlippers" }
		for i, id in ids do
			local slipper = Models.Slipper(id)
			Models.Anchor(slipper)
			slipper:PivotTo(origin * CFrame.new(-7.5 + (i - 1) * 3, y + 5.3, -3) * CFrame.Angles(0, math.rad(rng:NextNumber(-20, 20)), 0))
			slipper.Parent = m
		end
		for i, id in { "StrawHat", "BaseballCap", "CowboyHat" } do
			local hat = Models.Hat(id)
			Models.Anchor(hat)
			hat:PivotTo(origin * CFrame.new(-6 + (i - 1) * 6, y + 8, 4.2))
			hat.Parent = m
		end
	else
		for i, id in { "RubberDuck", "Starfish", "Seashell", "RubberDuck" } do
			local item = Models.Item(id)
			Models.Anchor(item)
			Models.Scale(item, 0.6)
			item:PivotTo(origin * CFrame.new(-6 + (i - 1) * 4, y + 6.3, -3))
			item.Parent = m
		end
		-- sudy vedle stánku
		for i = 0, 1 do
			deco(part(m, Vector3.new(4, 3, 3), origin * CFrame.new(11.5, y + 2 + i * 0.1, -2 + i * 3.5) * UP, WOOD_DARK, Enum.Material.Wood, CYL))
		end
	end
	return m, counter
end

-- ===== Kolo štěstí =====

local function buildSpinner(root: Instance, origin: CFrame): (Model, BasePart)
	local m = model("Spinner", root)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local y = World.SandY
	local radius = 12
	local centerHeight = y + 17
	-- podstavec
	local standPart = part(m, Vector3.new(16, 3, 8), origin * CFrame.new(0, y + 1.5, 0), WOOD_DARK, Enum.Material.Wood, BLOCK, "Stand")
	part(m, Vector3.new(3, centerHeight - y - 3, 3), origin * CFrame.new(0, (centerHeight + y + 3) / 2, 1.5), WOOD, Enum.Material.Wood, BLOCK, "Pole")
	-- kolo (samostatný model, klient ho otáčí)
	local wheel = model("Wheel", m)
	local center = origin * CFrame.new(0, centerHeight, 0)
	local hub = part(wheel, Vector3.new(1.4, 3.4, 3.4), center * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(255, 215, 60), Enum.Material.Metal, CYL, "Hub")
	wheel.PrimaryPart = hub
	local segments = SpinnerConfig.Segments
	local count = #segments
	local halfAngle = math.pi / count
	local halfWidth = radius * math.tan(halfAngle)
	local normal = center.LookVector
	for i, segment in segments do
		-- úhel středu dílku (0 = nahoře, po směru hodinových ručiček z pohledu hráče)
		local phi = (i - 1) * (2 * math.pi / count)
		local up, right = center.UpVector, center.RightVector
		local v = up * math.cos(phi) + right * math.sin(phi)
		local u = -up * math.sin(phi) + right * math.cos(phi)
		for _, s in { 1, -1 } do
			local yAxis = u * s
			local zAxis = v
			local xAxis = yAxis:Cross(zAxis)
			local pos = center.Position + u * s * (halfWidth / 2) + v * (radius / 2) + normal * 0.1
			local w = Instance.new("WedgePart")
			w.Anchored = true
			w.Size = Vector3.new(0.8, halfWidth, radius)
			w.CFrame = CFrame.fromMatrix(pos, xAxis, yAxis, zAxis)
			w.Color = segment.Color
			w.Material = Enum.Material.SmoothPlastic
			w.Name = "Segment_" .. i
			w.Parent = wheel
			deco(w)
		end
		-- dělicí čára
		local edgeDir = up * math.cos(phi + halfAngle) + right * math.sin(phi + halfAngle)
		deco(part(wheel, Vector3.new(0.3, 0.3, radius), CFrame.lookAt(center.Position + edgeDir * radius / 2 + normal * 0.5, center.Position + edgeDir * radius + normal * 0.5), WHITE))
	end
	-- okraj se žárovkami
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		local dir = center.UpVector * math.cos(a) + center.RightVector * math.sin(a)
		deco(part(wheel, Vector3.new(1.6, 1.6, 1.6), CFrame.new(center.Position + dir * (radius + 0.6)), Color3.fromRGB(255, 170, 40), Enum.Material.SmoothPlastic, BALL))
		local bulb = deco(part(wheel, Vector3.one * 0.9, CFrame.new(center.Position + dir * (radius + 0.6) + normal * 0.7), Color3.fromRGB(255, 245, 180), Enum.Material.Neon, BALL))
		bulb.Name = "Bulb"
	end
	-- ukazatel nahoře
	local pointer = wedge(m, Vector3.new(1, 3, 2.4), center * CFrame.new(0, radius + 2.2, -1) * CFrame.Angles(math.rad(180), 0, 0), CORAL)
	deco(pointer)
	CollectionService:AddTag(wheel, "SpinnerWheel")
	-- výzva
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SpinPrompt"
	prompt.ActionText = "Spin"
	prompt.ObjectText = "Lucky Wheel"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = standPart
	-- časovač (text nastavuje klient)
	local timerAnchor = deco(part(m, Vector3.one, center * CFrame.new(0, radius + 6, 0), WHITE, nil, BLOCK, "TimerAnchor"))
	timerAnchor.Transparency = 1
	local timer = billboard(timerAnchor, Vector3.zero, UDim2.fromOffset(260, 60), "FREE SPIN!", Color3.fromRGB(255, 240, 120), 120)
	timer.Name = "TimerLabel"
	CollectionService:AddTag(timer, "SpinnerTimer")

	-- ===== Ozdoby kola (statické, mimo model Wheel, takže se při točení nehýbou) =====
	local decor = model("Decor", m)
	local red = Color3.fromRGB(210, 30, 45)
	-- kulaté pódium se zlatým lemem (o 1 stud výš než písek, dá se na něj vyjít)
	local stage = part(decor, Vector3.new(1, 40, 40), origin * CFrame.new(0, y + 0.5, 0) * UP, Color3.fromRGB(150, 60, 200), Enum.Material.SmoothPlastic, CYL, "Stage")
	stage.CanTouch = false
	deco(part(decor, Vector3.new(0.9, 41.2, 41.2), origin * CFrame.new(0, y + 0.45, 0) * UP, GOLD, Enum.Material.Metal, CYL))
	-- červený koberec od kola k hráčům
	tiny(part(decor, Vector3.new(7, 0.1, 16), origin * CFrame.new(0, y + 1.05, -12), red, Enum.Material.Fabric))
	tiny(part(decor, Vector3.new(7, 0.1, 16), origin * CFrame.new(0, y + 0.05, -28), red, Enum.Material.Fabric))
	-- fialová deska se zlatým okrajem za kolem + třpytky
	local backDisc = deco(part(decor, Vector3.new(0.6, 32, 32), center * CFrame.new(0, 0, 0.9) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(110, 40, 170), Enum.Material.SmoothPlastic, CYL))
	deco(part(decor, Vector3.new(0.4, 33.6, 33.6), center * CFrame.new(0, 0, 1.3) * CFrame.Angles(0, math.rad(90), 0), GOLD, Enum.Material.Metal, CYL))
	sparkles(backDisc, 6, 1.4, 3, Color3.fromRGB(255, 240, 160))
	-- prstenec barevných žárovek kolem kola (klient je nechá blikat, tag "WheelBulb")
	local bulbCount = 28
	for i = 0, bulbCount - 1 do
		local a = (i + 0.5) / bulbCount * math.pi * 2 -- posun o půl kroku, aby žádná nebyla pod ukazatelem
		local dir = center.UpVector * math.cos(a) + center.RightVector * math.sin(a)
		local bulb = tiny(part(decor, Vector3.one * 1.3, CFrame.new(center.Position + dir * 14.7 - normal * 0.1), BULB_COLORS[i % #BULB_COLORS + 1], Enum.Material.Neon, BALL, "WheelBulb"))
		bulb:SetAttribute("BulbIndex", i)
		CollectionService:AddTag(bulb, "WheelBulb")
	end
	-- dva sloupy jako cukrová hůlka a oblouk mezi nimi
	local pillarTop = y + 34
	local pillarHeight = pillarTop - (y + 1)
	for _, sx in { -18, 18 } do
		deco(part(decor, Vector3.new(pillarHeight, 2.4, 2.4), origin * CFrame.new(sx, y + 1 + pillarHeight / 2, 0.5) * UP, WHITE, nil, CYL))
		for band = 1, 3 do
			tiny(part(decor, Vector3.new(1.4, 2.7, 2.7), origin * CFrame.new(sx, y + 1 + pillarHeight * band / 4, 0.5) * UP, red, nil, CYL))
		end
		deco(part(decor, Vector3.one * 3.2, origin * CFrame.new(sx, pillarTop, 0.5), GOLD, Enum.Material.Metal, BALL))
	end
	local archRise = 10
	local archSegments = 8
	local function archPoint(t: number): Vector3
		return (origin * CFrame.new(18 * math.cos(t), pillarTop + archRise * math.sin(t), 0.5)).Position
	end
	for k = 0, archSegments - 1 do
		local p0 = archPoint(math.pi * (1 - k / archSegments))
		local p1 = archPoint(math.pi * (1 - (k + 1) / archSegments))
		deco(part(decor, Vector3.new(1.8, 1.8, (p1 - p0).Magnitude + 0.6), CFrame.lookAt((p0 + p1) / 2, p1), if k % 2 == 0 then GOLD else CORAL))
	end
	-- velká cedule LUCKY WHEEL na oblouku (nad časovačem)
	local signCF = origin * CFrame.new(0, pillarTop + 8, -0.6)
	deco(part(decor, Vector3.new(25.2, 7.2, 0.5), signCF * CFrame.new(0, 0, 0.4), GOLD, Enum.Material.Metal))
	local wheelSign = deco(part(decor, Vector3.new(24, 6, 0.6), signCF, Color3.fromRGB(200, 30, 70), Enum.Material.SmoothPlastic, BLOCK, "WheelSign"))
	surfaceLabel(wheelSign, Enum.NormalId.Front, "LUCKY WHEEL", Color3.fromRGB(255, 235, 90), Color3.fromRGB(90, 20, 40), 30)
	-- zlatá hvězda na vrcholu oblouku
	local starCF = origin * CFrame.new(0, pillarTop + archRise + 4.5, 0.5)
	for arm = 0, 4 do
		tiny(part(decor, Vector3.new(1.6, 3.6, 0.8), starCF * CFrame.Angles(0, 0, arm / 5 * math.pi * 2) * CFrame.new(0, 1.8, 0), GOLD, Enum.Material.Neon))
	end
	local starCore = tiny(part(decor, Vector3.one * 2.4, starCF, GOLD, Enum.Material.Neon, BALL))
	sparkles(starCore, 10, 2, 6, Color3.fromRGB(255, 230, 120))
	local starLight = Instance.new("PointLight")
	starLight.Color = Color3.fromRGB(255, 220, 120)
	starLight.Range = 20
	starLight.Brightness = 2
	starLight.Parent = starCore
	-- trsy balónků uvázané na sloupech
	local balloonColors = { CORAL, ROYAL, Color3.fromRGB(255, 210, 50), Color3.fromRGB(110, 220, 120), Color3.fromRGB(255, 120, 200), Color3.fromRGB(170, 100, 255) }
	for si, sx in { -18, 18 } do
		local knot = origin * CFrame.new(sx, pillarTop + 1.5, 0.5)
		for b = 0, 2 do
			local balloonCF = knot * CFrame.new(math.sign(sx) * (2 + b * 1.6), 6 + (b % 2) * 2.2, (b - 1) * 1.8)
			tiny(part(decor, Vector3.one * 2.8, balloonCF, balloonColors[(si * 3 + b) % #balloonColors + 1], Enum.Material.SmoothPlastic, BALL))
			local from = knot.Position
			local to = (balloonCF * CFrame.new(0, -1.4, 0)).Position
			tiny(part(decor, Vector3.new(0.1, 0.1, (to - from).Magnitude), CFrame.lookAt((from + to) / 2, to), WHITE))
		end
	end
	return m, standPart
end

-- ===== Žebříček =====

local function buildLeaderboard(root: Instance, origin: CFrame): LeaderboardInfo
	local m = model("Leaderboard", root)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local y = World.SandY
	for _, sx in { -17, 17 } do
		part(m, Vector3.new(2, 26, 2), origin * CFrame.new(sx, y + 13, 0.8), WOOD_DARK, Enum.Material.Wood, BLOCK, "Post")
	end
	local board = part(m, Vector3.new(34, 22, 1), origin * CFrame.new(0, y + 15, 0), Color3.fromRGB(30, 60, 110), Enum.Material.SmoothPlastic, BLOCK, "Board")
	deco(part(m, Vector3.new(35.5, 23.5, 0.8), origin * CFrame.new(0, y + 15, 0.3), Color3.fromRGB(255, 205, 60)))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.13)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.Text = "LONGEST JUMPS"
	title.TextColor3 = Color3.fromRGB(255, 220, 80)
	title.Parent = gui
	local function column(x: number, heading: string): { TextLabel }
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = Color3.fromRGB(20, 40, 80)
		frame.Position = UDim2.fromScale(x, 0.14)
		frame.Size = UDim2.fromScale(0.47, 0.83)
		frame.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.04, 0)
		corner.Parent = frame
		local head = Instance.new("TextLabel")
		head.BackgroundTransparency = 1
		head.Size = UDim2.fromScale(1, 0.12)
		head.Font = Enum.Font.FredokaOne
		head.TextScaled = true
		head.Text = heading
		head.TextColor3 = Color3.fromRGB(130, 220, 255)
		head.Parent = frame
		local rows = {}
		for i = 1, 10 do
			local row = Instance.new("TextLabel")
			row.BackgroundTransparency = 1
			row.Position = UDim2.fromScale(0.04, 0.13 + (i - 1) * 0.086)
			row.Size = UDim2.fromScale(0.92, 0.08)
			row.Font = Enum.Font.FredokaOne
			row.TextScaled = true
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.Text = i .. ". —"
			row.TextColor3 = if i == 1 then Color3.fromRGB(255, 215, 60) elseif i == 2 then Color3.fromRGB(220, 225, 235) elseif i == 3 then Color3.fromRGB(230, 160, 100) else WHITE
			row.Parent = frame
			table.insert(rows, row)
		end
		return rows
	end
	return {
		TodayRows = column(0.02, "TODAY (THIS SERVER)"),
		AllTimeRows = column(0.51, "ALL TIME"),
	}
end

-- ===== Obří dárek =====
-- Ostrov s dárkem na 100 000 studech. Dopad hráče řeší JumpService jen podle vzdálenosti
-- (GiftLanding = landingX, výška písku). Proto je v místě dopadu jen placaté molo (horní plocha
-- o 0,15 studu nad pískem) a na přistávací dráze (z = ±50 před dopadem) nestojí nic vysokého.

local function miniGift(parent: Instance, position: Vector3, size: number, boxColor: Color3, ribbonColor: Color3, yaw: number)
	local cf = CFrame.new(position + Vector3.new(0, size / 2, 0)) * CFrame.Angles(0, yaw, 0)
	deco(part(parent, Vector3.one * size, cf, boxColor))
	deco(part(parent, Vector3.new(size + 0.2, size + 0.2, size * 0.22), cf, ribbonColor))
	deco(part(parent, Vector3.new(size * 0.22, size + 0.2, size + 0.2), cf, ribbonColor))
end

local function buildLighthouse(parent: Instance, base: Vector3)
	local lh = model("Lighthouse", parent)
	part(lh, Vector3.new(3, 20, 20), CFrame.new(base + Vector3.new(0, 1.5, 0)) * UP, ROCK, Enum.Material.Slate, CYL, "LighthouseBase")
	-- věž z červenobílých pruhů
	local towerY = base.Y + 3
	local bandHeight = 12
	local bands = 5
	for k = 0, bands - 1 do
		local d = 14 - k
		deco(part(lh, Vector3.new(bandHeight, d, d), CFrame.new(base.X, towerY + bandHeight * (k + 0.5), base.Z) * UP, if k % 2 == 0 then WHITE else BUOY_RED, nil, CYL))
	end
	local galleryY = towerY + bands * bandHeight
	deco(part(lh, Vector3.new(1, 15, 15), CFrame.new(base.X, galleryY + 0.5, base.Z) * UP, Color3.fromRGB(60, 60, 70), Enum.Material.Metal, CYL))
	-- svítící lucerna nahoře
	local lamp = deco(part(lh, Vector3.new(7, 8, 8), CFrame.new(base.X, galleryY + 4.5, base.Z) * UP, Color3.fromRGB(255, 240, 150), Enum.Material.Neon, CYL, "Lamp"))
	lamp.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 235, 150)
	light.Range = 60
	light.Brightness = 4
	light.Parent = lamp
	-- střecha
	deco(part(lh, Vector3.new(2, 11, 11), CFrame.new(base.X, galleryY + 9.5, base.Z) * UP, BUOY_RED, nil, CYL))
	deco(part(lh, Vector3.new(2, 6, 6), CFrame.new(base.X, galleryY + 11.5, base.Z) * UP, BUOY_RED, nil, CYL))
	deco(part(lh, Vector3.one * 2.4, CFrame.new(base.X, galleryY + 13.4, base.Z), GOLD, Enum.Material.Metal, BALL))
end

local function buildGift(root: Instance): (Model, Vector3)
	local landingX = World.PierEndX + World.GiftDistance
	local islandCenter = Vector3.new(landingX + 90, World.WaterY, 0)
	local radius = World.GiftIslandRadius
	local m = model("GiantGift", root)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local rng = Random.new(100)

	-- ostrov: tyrkysová mělčina, mokrý písek, písečný ostrov (pochozí) a tráva pod dárkem
	local islandTop = World.WaterY + 4
	part(m, Vector3.new(8, radius * 2, radius * 2), CFrame.new(islandCenter + Vector3.new(0, islandTop - 4, 0)) * UP, SAND, Enum.Material.Sand, CYL, "Island")
	tiny(part(m, Vector3.new(2, radius * 2 + 90, radius * 2 + 90), CFrame.new(islandCenter + Vector3.new(0, World.WaterY - 0.85, 0)) * UP, Color3.fromRGB(110, 230, 235), nil, CYL))
	deco(part(m, Vector3.new(3, radius * 2 + 28, radius * 2 + 28), CFrame.new(islandCenter + Vector3.new(0, World.WaterY - 0.2, 0)) * UP, SAND_DARK, Enum.Material.Sand, CYL))
	-- tráva začíná až 20 studů za místem dopadu (dopad je na písku / molu)
	local grassCenter = islandCenter + Vector3.new(50, 0, 0)
	local grass = part(m, Vector3.new(1, 240, 240), CFrame.new(grassCenter + Vector3.new(0, islandTop - 0.3, 0)) * UP, Color3.fromRGB(110, 200, 80), Enum.Material.Grass, CYL, "Grass")
	grass.CanTouch = false

	-- přistávací molo v místě dopadu + dřevěná lávka k vodě a kus mola do moře
	local deckTop = islandTop + 0.15
	local deck = part(m, Vector3.new(30, 0.6, 26), CFrame.new(landingX, deckTop - 0.3, 0), WOOD_LIGHT, Enum.Material.WoodPlanks, BLOCK, "LandingDeck")
	deck.CanTouch = false
	local walkFrom, walkTo = landingX - 140, landingX - 15
	local walk = part(m, Vector3.new(walkTo - walkFrom, 0.6, 10), CFrame.new((walkFrom + walkTo) / 2, deckTop - 0.3, 0), WOOD, Enum.Material.WoodPlanks, BLOCK, "Boardwalk")
	walk.CanTouch = false
	for k = 0, 2 do
		for _, side in { -1, 1 } do
			local postHeight = deckTop - (World.WaterY - 3) + 1
			deco(part(m, Vector3.new(postHeight, 1.4, 1.4), CFrame.new(landingX - 110 - k * 14, World.WaterY - 3 + postHeight / 2, side * 5.6) * UP, WOOD_DARK, Enum.Material.Wood, CYL))
		end
	end
	-- nízké lucerny podél lávky (mimo přistávací dráhu, nejvýš 5 studů nad pískem)
	for k = 0, 2 do
		for _, side in { -1, 1 } do
			local x = landingX - 30 - k * 25
			deco(part(m, Vector3.new(4, 0.5, 0.5), CFrame.new(x, islandTop + 2, side * 7.5) * UP, WOOD_DARK, Enum.Material.Wood, CYL))
			tiny(part(m, Vector3.new(1, 1.4, 1), CFrame.new(x, islandTop + 4.6, side * 7.5), WARM_LIGHT, Enum.Material.Neon))
		end
	end
	-- uvítací cedule vedle místa dopadu
	local signOrigin = facing(Vector3.new(landingX - 4, 0, -19), Vector3.new(-1, 0, 0.35))
	for _, sx in { -5.5, 5.5 } do
		deco(part(m, Vector3.new(0.8, 7, 0.8), signOrigin * CFrame.new(sx, islandTop + 3.5, 0), WOOD_DARK, Enum.Material.Wood))
	end
	local welcome = deco(part(m, Vector3.new(13, 4.5, 0.6), signOrigin * CFrame.new(0, islandTop + 5.5, 0), WOOD, Enum.Material.Wood, BLOCK, "WelcomeSign"))
	surfaceLabel(welcome, Enum.NormalId.Front, "GIANT GIFT ISLAND", WHITE, Color3.fromRGB(70, 40, 20), 30)

	-- maják na kraji ostrova (vpravo, daleko od přistávací dráhy)
	buildLighthouse(m, Vector3.new(landingX + 10, islandTop, -150))

	-- palmy po obvodu (vynechané jsou ty na přistávací dráze a uvnitř dárku)
	for _, i in { 2, 3, 4, 6, 7, 8 } do
		local a = i / 10 * math.pi * 2
		palm(m, islandCenter + Vector3.new(math.cos(a) * 160, islandTop, math.sin(a) * 160), rng:NextNumber(22, 32), 10, a)
	end
	for _, side in { -1, 1 } do
		palm(m, Vector3.new(landingX - 45, islandTop, side * 62), rng:NextNumber(18, 24), 12, if side == 1 then 1.2 else -1.2)
	end
	-- kameny na břehu
	for _, a in { 0.35, -0.35, 0.75, -0.75 } do
		local angle = a * math.pi
		rockCluster(m, islandCenter + Vector3.new(math.cos(angle) * 188, World.WaterY + 1, math.sin(angle) * 188), rng:NextNumber(9, 14), false, rng)
	end
	-- malé dárečky kolem
	local miniColors = { Color3.fromRGB(80, 180, 255), Color3.fromRGB(255, 120, 200), Color3.fromRGB(120, 220, 120), Color3.fromRGB(180, 120, 255) }
	for i, pos in { Vector3.new(landingX + 6, 0, 26), Vector3.new(landingX + 14, 0, -32), Vector3.new(landingX + 70, 0, 135), Vector3.new(landingX + 150, 0, -132) } do
		miniGift(m, Vector3.new(pos.X, islandTop, pos.Z), rng:NextNumber(6, 10), miniColors[i], if i % 2 == 0 then GOLD else WHITE, rng:NextNumber(0, 6))
	end

	-- dárek
	local custom = Models.MapAsset("GiantGift")
	local giftCenter = islandCenter + Vector3.new(40, 0, 0)
	local boxHeight = World.GiftHeight
	if custom then
		custom:PivotTo(CFrame.new(giftCenter + Vector3.new(0, islandTop, 0)))
		custom.Parent = m
	else
		-- přední stěna krabice je 20 studů za místem dopadu
		local boxSize = 220
		local lidHeight = 40
		local gold = Color3.fromRGB(255, 200, 40)
		local ribbon = Color3.fromRGB(255, 50, 80)
		local boxBottom = islandTop
		local lidY = boxBottom + boxHeight + lidHeight / 2
		local box = part(m, Vector3.new(boxSize, boxHeight, boxSize), CFrame.new(giftCenter + Vector3.new(0, boxBottom + boxHeight / 2, 0)), gold, Enum.Material.SmoothPlastic, BLOCK, "Box")
		CollectionService:AddTag(box, "GiftBody")
		local lid = part(m, Vector3.new(boxSize + 16, lidHeight, boxSize + 16), CFrame.new(giftCenter + Vector3.new(0, lidY, 0)), gold, Enum.Material.SmoothPlastic, BLOCK, "Lid")
		CollectionService:AddTag(lid, "GiftBody")
		-- svítící mašle přes celý dárek
		local ribbonHeight = boxHeight + lidHeight + 2
		for _, size in { Vector3.new(boxSize + 2, ribbonHeight, 36), Vector3.new(36, ribbonHeight, boxSize + 2) } do
			tiny(part(m, size, CFrame.new(giftCenter + Vector3.new(0, boxBottom + ribbonHeight / 2, 0)), ribbon, Enum.Material.Neon))
		end
		for _, size in { Vector3.new(boxSize + 18, lidHeight + 2, 36), Vector3.new(36, lidHeight + 2, boxSize + 18) } do
			tiny(part(m, size, CFrame.new(giftCenter + Vector3.new(0, lidY, 0)), ribbon, Enum.Material.Neon))
		end
		-- velká mašle nahoře (dvě smyčky + uzel)
		local bowY = boxBottom + boxHeight + lidHeight
		for _, s in { -1, 1 } do
			tiny(part(m, Vector3.new(28, 80, 80), CFrame.new(giftCenter + Vector3.new(0, bowY + 34, s * 40)), ribbon, Enum.Material.Neon, CYL))
		end
		tiny(part(m, Vector3.one * 40, CFrame.new(giftCenter + Vector3.new(0, bowY + 16, 0)), ribbon, Enum.Material.Neon, BALL))
		-- světla a třpytky
		local light = Instance.new("PointLight")
		light.Range = 60
		light.Brightness = 4
		light.Color = Color3.fromRGB(255, 230, 150)
		light.Parent = lid
		local frontLight = Instance.new("SurfaceLight")
		frontLight.Face = Enum.NormalId.Left -- strana k místu dopadu (−X)
		frontLight.Range = 60
		frontLight.Brightness = 3
		frontLight.Angle = 120
		frontLight.Color = Color3.fromRGB(255, 225, 150)
		frontLight.Parent = box
		local glitter = Instance.new("ParticleEmitter")
		glitter.Name = "Sparkles"
		glitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		glitter.Rate = 40
		glitter.Lifetime = NumberRange.new(2, 3)
		glitter.Speed = NumberRange.new(15, 30)
		glitter.SpreadAngle = Vector2.new(35, 35)
		glitter.EmissionDirection = Enum.NormalId.Top
		glitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 7), NumberSequenceKeypoint.new(1, 0) })
		glitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.7) })
		glitter.Color = ColorSequence.new(Color3.fromRGB(255, 240, 170))
		glitter.LightEmission = 1
		glitter.Parent = lid
	end
	-- keříky u paty dárku (mimo krabici i mimo přistávací molo)
	for k, pos in { Vector3.new(12, 0, 60), Vector3.new(12, 0, -70), Vector3.new(14, 0, 100), Vector3.new(10, 0, -96), Vector3.new(100, 0, 126), Vector3.new(200, 0, -126) } do
		local bush = deco(part(m, Vector3.one * rng:NextNumber(8, 12), CFrame.new(landingX + pos.X, islandTop + 2, pos.Z), if k % 2 == 0 then LEAF else LEAF_DARK, Enum.Material.Grass, BALL))
		bush.CastShadow = false
	end

	-- svítící paprsek do nebe (jádro + široká průsvitná záře)
	local beamBottom = islandTop + boxHeight + 40 -- od víka nahoru
	local beam = tiny(part(m, Vector3.new(2048, 40, 40), CFrame.new(giftCenter + Vector3.new(0, beamBottom + 1024, 0)) * UP, Color3.fromRGB(255, 240, 170), Enum.Material.Neon, CYL, "Beam"))
	beam.Transparency = 0.35
	local halo = tiny(part(m, Vector3.new(2048, 110, 110), CFrame.new(giftCenter + Vector3.new(0, beamBottom + 1024, 0)) * UP, Color3.fromRGB(255, 245, 200), Enum.Material.Neon, CYL, "BeamGlow"))
	halo.Transparency = 0.82
	CollectionService:AddTag(m, "GiantGift")
	return m, Vector3.new(landingX, islandTop, 0)
end

-- ===== Hlavní funkce =====

function MapBuilder.Build(): MapInfo
	local existing = workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Map"
	root.Parent = workspace
	local rng = Random.new(20260930)

	buildBeach(root, rng)
	buildPier(root)
	buildWater(root, rng)

	-- domečky: 4 vlevo a 4 vpravo od cesty, vchody směrem ke spawnu
	local houses: { HouseInfo } = {}
	local frontX = World.SpawnX + 40
	local housesFolder = Instance.new("Folder")
	housesFolder.Name = "Houses"
	housesFolder.Parent = root
	for i = 1, House.Count do
		local sideIndex = (i - 1) % 4
		local side = if i <= 4 then -1 else 1
		-- vlevo od nejvzdálenějšího k cestě, vpravo od cesty ven (jako na obrázku)
		local slot = if side == -1 then 3 - sideIndex else sideIndex
		local z = side * (World.PathHalfWidth + 6 + House.Width / 2 + slot * (House.Width + House.Gap))
		table.insert(houses, buildHouse(housesFolder, i, frontX, z))
	end

	-- stánky SHOP a SELL vlevo od cesty (čelem k cestě), kolo štěstí vpravo
	local stallX = World.BeachFrontX - 95
	local shopOrigin = facing(Vector3.new(stallX, 0, -52), Vector3.new(0.35, 0, 1))
	local sellOrigin = facing(Vector3.new(stallX + 45, 0, -48), Vector3.new(-0.2, 0, 1))
	local _, shopCounter = buildStall(root, "SHOP", "SHOP", CORAL, shopOrigin, rng)
	local _, sellCounter = buildStall(root, "SELL", "SELL", ROYAL, sellOrigin, rng)

	local shopPrompt = Instance.new("ProximityPrompt")
	shopPrompt.Name = "ShopPrompt"
	shopPrompt.ActionText = "Open Shop"
	shopPrompt.ObjectText = "SHOP"
	shopPrompt.HoldDuration = 0
	shopPrompt.MaxActivationDistance = 14
	shopPrompt.RequiresLineOfSight = false
	shopPrompt.Parent = shopCounter
	CollectionService:AddTag(shopCounter, "ShopStall")

	local sellPrompt = Instance.new("ProximityPrompt")
	sellPrompt.Name = "SellPrompt"
	sellPrompt.ActionText = "Sell"
	sellPrompt.ObjectText = "SELL"
	sellPrompt.HoldDuration = 1
	sellPrompt.MaxActivationDistance = 14
	sellPrompt.RequiresLineOfSight = false
	sellPrompt.Parent = sellCounter
	CollectionService:AddTag(sellPrompt, "SellPrompt")
	CollectionService:AddTag(sellCounter, "SellStall")

	local spinnerOrigin = facing(Vector3.new(stallX + 15, 0, 60), Vector3.new(-0.5, 0, -1))
	local _, spinnerStand = buildSpinner(root, spinnerOrigin)
	local spinnerPrompt = spinnerStand:FindFirstChild("SpinPrompt") :: ProximityPrompt

	-- žebříček mezi kolem štěstí a domečky
	local boardOrigin = facing(Vector3.new(World.BeachFrontX - 120, 0, 52), Vector3.new(0.3, 0, -1))
	local leaderboard = buildLeaderboard(root, boardOrigin)

	-- spawn
	-- hráč začíná kousek před molem
	local spawnCFrame = CFrame.lookAt(Vector3.new(World.ReturnX - 12, World.SandY + 3, 0), Vector3.new(World.ReturnX, World.SandY + 3, 0))
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "Spawn"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(10, 0.4, 10)
	spawnLocation.CFrame = CFrame.new(World.ReturnX - 12, World.SandY + 0.45, 0)
	spawnLocation.Color = Color3.fromRGB(255, 225, 120)
	spawnLocation.Material = Enum.Material.SmoothPlastic
	spawnLocation.Transparency = 0.2
	spawnLocation.Duration = 0
	spawnLocation.Neutral = true
	spawnLocation.Parent = root

	local giftModel, giftLanding = buildGift(root)

	return {
		Folder = root,
		Spawn = spawnCFrame,
		ReturnPoint = CFrame.lookAt(Vector3.new(World.ReturnX, World.SandY + 3, 0), Vector3.new(World.ReturnX + 10, World.SandY + 3, 0)),
		SpawnLocation = spawnLocation,
		ShopPrompt = shopPrompt,
		ShopPosition = shopCounter.Position,
		SellPrompt = sellPrompt,
		SellTeleport = CFrame.lookAt(sellCounter.Position + sellCounter.CFrame.LookVector * 9 + Vector3.new(0, 1, 0), sellCounter.Position + Vector3.new(0, 1, 0)),
		SpinnerPrompt = spinnerPrompt,
		Houses = houses,
		Leaderboard = leaderboard,
		GiftLanding = giftLanding,
		GiftModel = giftModel,
	}
end

return MapBuilder

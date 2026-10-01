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
		local x = World.SpawnX + 50
		while x < World.BeachFrontX - 30 do
			deco(part(beach, Vector3.new(4, 1.2, 1.2), CFrame.new(x, World.SandY + 2, z) * UP, WOOD_DARK, Enum.Material.Wood, CYL))
			x += 16
		end
		deco(part(beach, Vector3.new(World.BeachFrontX - 30 - (World.SpawnX + 50), 0.25, 0.25), CFrame.new((World.BeachFrontX - 30 + World.SpawnX + 50) / 2, World.SandY + 3.3, z) * CFrame.Angles(0, 0, 0), Color3.fromRGB(200, 170, 120), Enum.Material.Fabric, CYL))
	end

	-- palmy a deštníky
	for i = 1, 26 do
		local side = if i % 2 == 0 then 1 else -1
		local x = rng:NextNumber(back + 20, front - 20)
		local z = side * rng:NextNumber(175, halfWidth - 20)
		palm(beach, Vector3.new(x, World.SandY, z), rng:NextNumber(16, 26), rng:NextNumber(6, 18), rng:NextNumber(0, math.pi * 2))
	end
	for _, pos in { Vector3.new(-50240, 0, 120), Vector3.new(-50300, 0, -150), Vector3.new(-50200, 0, -110), Vector3.new(-50360, 0, 150), Vector3.new(-50600, 0, 90), Vector3.new(-50610, 0, -110) } do
		local palmBase = Vector3.new(pos.X, World.SandY, pos.Z + 12)
		palm(beach, palmBase, rng:NextNumber(18, 24), rng:NextNumber(8, 14), rng:NextNumber(0, 6))
	end
	local umbrellaColors = { CORAL, ROYAL, Color3.fromRGB(150, 90, 230), Color3.fromRGB(255, 170, 40) }
	for i, pos in { Vector3.new(-50215, 0, -30), Vector3.new(-50230, 0, 40), Vector3.new(-50380, 0, 60), Vector3.new(-50350, 0, -160), Vector3.new(-50195, 0, 160), Vector3.new(-50630, 0, 40), Vector3.new(-50620, 0, -60) } do
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
		-- okna
		for w = 0, 2 do
			local window = deco(part(m, Vector3.new(8, 5, 1.2), CFrame.new(frontX + 25 + w * 32, floorY + 1 + H * 0.6, zCenter + side * (W / 2 - 0.5)), Color3.fromRGB(170, 225, 255), Enum.Material.Glass))
			window.Transparency = 0.3
		end
	end
	-- zadní stěna
	part(m, Vector3.new(1, H, W), CFrame.new(backX - 0.5, floorY + 1 + H / 2, zCenter), color, Enum.Material.WoodPlanks, BLOCK, "Wall")
	-- přední stěna s širokým vchodem
	local sideWidth = (W - entranceWidth) / 2
	for _, side in { -1, 1 } do
		part(m, Vector3.new(1, H, sideWidth), CFrame.new(frontX + 0.5, floorY + 1 + H / 2, zCenter + side * (entranceWidth / 2 + sideWidth / 2)), color, Enum.Material.WoodPlanks, BLOCK, "Wall")
		deco(part(m, Vector3.new(1.4, H, 1), CFrame.new(frontX + 0.3, floorY + 1 + H / 2, zCenter + side * (entranceWidth / 2 + 0.5)), trim))
	end
	local lintelHeight = 3
	part(m, Vector3.new(1, lintelHeight, entranceWidth), CFrame.new(frontX + 0.5, floorY + 1 + H - lintelHeight / 2, zCenter), color, Enum.Material.WoodPlanks, BLOCK, "Wall")
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

	-- zelené teleportační kolečko u zadní stěny → stánek SELL
	local padPos = Vector3.new(backX - 8, floorY + 1.1, zCenter)
	local teleportPad = part(m, Vector3.new(0.3, 9, 9), CFrame.new(padPos) * UP, Color3.fromRGB(60, 255, 110), Enum.Material.Neon, CYL, "TeleportPad")
	teleportPad.CanCollide = false
	local ring = deco(part(m, Vector3.new(0.2, 10.5, 10.5), CFrame.new(padPos - Vector3.new(0, 0.05, 0)) * UP, WHITE, nil, CYL))
	ring.Name = "PadRing"
	local padLight = Instance.new("PointLight")
	padLight.Color = Color3.fromRGB(80, 255, 120)
	padLight.Range = 14
	padLight.Parent = teleportPad
	billboard(teleportPad, Vector3.new(0, 4, 0), UDim2.fromOffset(180, 40), "To SELL", Color3.fromRGB(120, 255, 150), 60)

	-- rostliny a surfy u vchodu
	for _, s in { -1, 1 } do
		local potPos = Vector3.new(frontX - 2, floorY, zCenter + s * (entranceWidth / 2 + 3))
		deco(part(m, Vector3.new(2.4, 2.4, 2.4), CFrame.new(potPos + Vector3.new(0, 1.2, 0)) * UP, Color3.fromRGB(200, 110, 70), nil, CYL))
		for leaf = 0, 3 do
			deco(part(m, Vector3.new(0.8, 3, 0.3), CFrame.new(potPos + Vector3.new(0, 3.6, 0)) * CFrame.Angles(0, leaf * math.pi / 2, math.rad(25)) * CFrame.new(0.6, 0, 0), LEAF, Enum.Material.Grass))
		end
	end

	return {
		Index = index,
		Name = name,
		Model = m,
		Pedestals = pedestals,
		PiggyBank = body,
		PiggyLabel = piggyLabel,
		CollectPad = collectPad,
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
			item:ScaleTo(0.6)
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

local function buildGift(root: Instance): (Model, Vector3)
	local landingX = World.PierEndX + World.GiftDistance
	local islandCenter = Vector3.new(landingX + 90, World.WaterY, 0)
	local m = model("GiantGift", root)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	-- ostrůvek
	local islandTop = World.WaterY + 4
	part(m, Vector3.new(8, World.GiftIslandRadius * 2, World.GiftIslandRadius * 2), CFrame.new(islandCenter + Vector3.new(0, islandTop - 4, 0)) * UP, SAND, Enum.Material.Sand, CYL, "Island")
	deco(part(m, Vector3.new(2, World.GiftIslandRadius * 2 + 16, World.GiftIslandRadius * 2 + 16), CFrame.new(islandCenter + Vector3.new(0, World.WaterY - 0.2, 0)) * UP, Color3.fromRGB(120, 230, 240), nil, CYL))
	local rng = Random.new(100)
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		palm(m, islandCenter + Vector3.new(math.cos(a) * 160, islandTop, math.sin(a) * 160), rng:NextNumber(22, 32), 10, a)
	end
	-- dárek
	local custom = Models.MapAsset("GiantGift")
	local giftCenter = islandCenter + Vector3.new(40, 0, 0)
	if custom then
		custom:PivotTo(CFrame.new(giftCenter + Vector3.new(0, islandTop, 0)))
		custom.Parent = m
	else
		local boxSize = 200
		local boxHeight = 250
		local gold = Color3.fromRGB(255, 200, 40)
		local red = Color3.fromRGB(230, 40, 50)
		local box = part(m, Vector3.new(boxSize, boxHeight, boxSize), CFrame.new(giftCenter + Vector3.new(0, islandTop + boxHeight / 2, 0)), gold, Enum.Material.SmoothPlastic, BLOCK, "Box")
		CollectionService:AddTag(box, "GiftBody")
		local lid = part(m, Vector3.new(boxSize + 16, 36, boxSize + 16), CFrame.new(giftCenter + Vector3.new(0, islandTop + boxHeight + 18, 0)), gold, Enum.Material.SmoothPlastic, BLOCK, "Lid")
		CollectionService:AddTag(lid, "GiftBody")
		-- mašle přes celý dárek
		deco(part(m, Vector3.new(boxSize + 2, boxHeight + 38, 34), CFrame.new(giftCenter + Vector3.new(0, islandTop + (boxHeight + 36) / 2, 0)), red, Enum.Material.SmoothPlastic))
		deco(part(m, Vector3.new(34, boxHeight + 38, boxSize + 18), CFrame.new(giftCenter + Vector3.new(0, islandTop + (boxHeight + 36) / 2, 0)), red, Enum.Material.SmoothPlastic))
		deco(part(m, Vector3.new(boxSize + 18, 38, 34), CFrame.new(giftCenter + Vector3.new(0, islandTop + boxHeight + 18, 0)), red))
		-- velká mašle nahoře
		for _, s in { -1, 1 } do
			deco(part(m, Vector3.new(70, 44, 36), CFrame.new(giftCenter + Vector3.new(0, islandTop + boxHeight + 58, s * 34)) * CFrame.Angles(math.rad(s * 25), 0, 0), red, Enum.Material.SmoothPlastic, BALL))
		end
		deco(part(m, Vector3.new(34, 34, 34), CFrame.new(giftCenter + Vector3.new(0, islandTop + boxHeight + 50, 0)), red, Enum.Material.SmoothPlastic, BALL))
		local light = Instance.new("PointLight")
		light.Range = 60
		light.Brightness = 3
		light.Color = Color3.fromRGB(255, 230, 150)
		light.Parent = lid
	end
	-- svítící paprsek do nebe
	local beam = deco(part(m, Vector3.new(2048, 40, 40), CFrame.new(giftCenter + Vector3.new(0, 1024 + 250, 0)) * UP, Color3.fromRGB(255, 240, 170), Enum.Material.Neon, CYL, "Beam"))
	beam.Transparency = 0.35
	beam.CastShadow = false
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

	-- žebříček u spawnu
	local boardOrigin = facing(Vector3.new(World.SpawnX - 5, 0, 48), Vector3.new(0.35, 0, -1))
	local leaderboard = buildLeaderboard(root, boardOrigin)

	-- spawn
	local spawnCFrame = CFrame.lookAt(Vector3.new(World.SpawnX, World.SandY + 3, 0), Vector3.new(World.SpawnX + 10, World.SandY + 3, 0))
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "Spawn"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(10, 0.4, 10)
	spawnLocation.CFrame = CFrame.new(World.SpawnX, World.SandY + 0.25, 0)
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

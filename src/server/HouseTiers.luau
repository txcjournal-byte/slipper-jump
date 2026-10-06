--!strict
-- Vzhled domečku podle úrovně (Config/House → Tiers):
--  1 Beach Shack – chatrč: slaměná střecha, vybledlé zdi, přibitá prkna
--  2 Cottage     – původní barevný domek + plotek a palmy u vchodu
--  3 Beach House – vyhlídková věžička na střeše s vlajkou, surfy, světýlka
--  4 Villa       – světlé omítnuté zdi, terakotová střecha, dvě věže a sloupy u vchodu
--  5 Palace      – bílý mramor, zlatá střecha, věže se zlatými kopulemi, koruna, červený koberec, třpytky
-- Staví se jen ozdoby (bez kolizí) do složky TierDeco v modelu domečku; zdi a střecha se jen přebarví.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local House = require(Shared.Config.House)

local HouseTiers = {}

local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 185, 25)
local WOOD = Color3.fromRGB(150, 105, 65)
local LEAF = Color3.fromRGB(70, 175, 70)
local WARM = Color3.fromRGB(255, 214, 130)
local TERRACOTTA = Color3.fromRGB(200, 95, 60)
local MARBLE = Color3.fromRGB(250, 246, 236)
local THATCH = Color3.fromRGB(205, 172, 105)
local BULBS = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 210, 60), Color3.fromRGB(90, 220, 120), Color3.fromRGB(80, 180, 255), Color3.fromRGB(255, 130, 220) }
local UP = CFrame.Angles(0, 0, math.rad(90)) -- válec postavený svisle

local function P(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function light(p: BasePart, color: Color3, range: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = 1.5
	l.Parent = p
end

-- jednoduchá palma: zahnutý kmen a osm listů
local function palm(parent: Instance, base: Vector3, height: number, yaw: number)
	local pos = base
	local segments = 5
	for i = 1, segments do
		local dir = (CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(4 + i * 3), 0, 0)).UpVector
		local nextPos = pos + dir * (height / segments)
		local w = 1.7 - i * 0.12
		P(parent, Vector3.new(height / segments + 0.3, w, w), CFrame.lookAt((pos + nextPos) / 2, nextPos) * CFrame.Angles(0, math.rad(90), 0), if i % 2 == 0 then WOOD else WOOD:Lerp(WHITE, 0.15), Enum.Material.Wood, Enum.PartType.Cylinder)
		pos = nextPos
	end
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local leafDir = Vector3.new(math.cos(a), -0.35, math.sin(a)).Unit
		P(parent, Vector3.new(0.3, 1.8, 7), CFrame.lookAt(pos + leafDir * 3.2, pos + leafDir * 6.4), if i % 2 == 0 then LEAF else LEAF:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Grass)
	end
	P(parent, Vector3.one * 1.1, CFrame.new(pos + Vector3.new(0.6, -0.8, 0)), Color3.fromRGB(110, 70, 40), nil, Enum.PartType.Ball)
end

-- kulatá věž s okny; roof = "Cone" (terakota) nebo "Dome" (zlatá kopule s vlajkou)
local function tower(parent: Instance, base: Vector3, height: number, radius: number, wall: Color3, roof: string)
	P(parent, Vector3.new(height, radius * 2, radius * 2), CFrame.new(base + Vector3.new(0, height / 2, 0)) * UP, wall, Enum.Material.Plaster, Enum.PartType.Cylinder)
	-- prstenec pod střechou a okna po obvodu
	P(parent, Vector3.new(1, radius * 2 + 0.8, radius * 2 + 0.8), CFrame.new(base + Vector3.new(0, height, 0)) * UP, if roof == "Dome" then GOLD else WHITE, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local w = P(parent, Vector3.new(0.4, 3.2, 1.8), CFrame.lookAt(base + Vector3.new(0, height * 0.65, 0) + dir * (radius + 0.05), base + Vector3.new(0, height * 0.65, 0) + dir * (radius + 1)), WARM, Enum.Material.Neon)
		w.Size = Vector3.new(1.8, 3.2, 0.4)
	end
	local top = base + Vector3.new(0, height, 0)
	if roof == "Dome" then
		local dome = P(parent, Vector3.one * (radius * 2 + 0.6), CFrame.new(top + Vector3.new(0, 0.6, 0)), GOLD, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		dome.Reflectance = 0.25
		P(parent, Vector3.new(0.3, 6, 0.3), CFrame.new(top + Vector3.new(0, radius + 3.5, 0)), WHITE)
		local flag = P(parent, Vector3.new(0.15, 2, 3.2), CFrame.new(top + Vector3.new(0, radius + 5.4, 1.6)), Color3.fromRGB(220, 40, 60))
		flag.Name = "Flag"
	else
		-- kužel ze zmenšujících se válců
		for k = 0, 5 do
			local r = radius * 1.15 * (1 - k / 6)
			P(parent, Vector3.new(1.4, r * 2, r * 2), CFrame.new(top + Vector3.new(0, 0.7 + k * 1.3, 0)) * UP, TERRACOTTA, Enum.Material.Slate, Enum.PartType.Cylinder)
		end
	end
end

type Geo = { L: number, W: number, H: number, CX: number, Z: number, FloorY: number, FrontX: number, BackX: number, PeakY: number, Color: Color3 }

local function geometry(house: any): Geo
	local size: Vector3 = house.Size
	local center: CFrame = house.Center
	local H = size.Y - 2
	local floorY = center.Y - 1 - H / 2
	return {
		L = size.X,
		W = size.Z,
		H = H,
		CX = center.X,
		Z = center.Z,
		FloorY = floorY,
		FrontX = center.X - size.X / 2,
		BackX = center.X + size.X / 2,
		PeakY = floorY + 1 + H + 9,
		Color = House.Colors[house.Index] or WHITE,
	}
end

-- zdi, štíty a střecha: přebarvit podle úrovně (původní vzhled si pamatují v atributech)
local function restyle(model: Model, g: Geo, tier: number)
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") and (d.Name == "Wall" or d.Name == "Gable" or d.Name == "Roof" or d.Name == "Ridge") then
			if d:GetAttribute("BaseColor") == nil then
				d:SetAttribute("BaseColor", d.Color)
				d:SetAttribute("BaseMaterial", d.Material.Name)
			end
			local baseColor = d:GetAttribute("BaseColor") :: Color3
			local baseMaterial = (Enum.Material :: any)[d:GetAttribute("BaseMaterial") :: string] :: Enum.Material
			local color, material, reflect = baseColor, baseMaterial, 0
			if d.Name == "Roof" then
				if tier == 1 then
					color, material = THATCH, Enum.Material.Grass
				elseif tier == 4 then
					color, material = TERRACOTTA, Enum.Material.Slate
				elseif tier == 5 then
					color, material, reflect = GOLD, Enum.Material.Foil, 0.15
				end
			elseif d.Name == "Ridge" then
				color = if tier == 5 then GOLD elseif tier == 1 then WOOD else baseColor
			else
				if tier == 1 then
					color = baseColor:Lerp(Color3.fromRGB(160, 130, 95), 0.55)
				elseif tier == 4 then
					color, material = baseColor:Lerp(WHITE, 0.65), Enum.Material.Plaster
				elseif tier == 5 then
					color, material = MARBLE, Enum.Material.Marble
				end
			end
			d.Color = color
			d.Material = material
			d.Reflectance = reflect
		end
	end
end

local function build(folder: Folder, g: Geo, tier: number)
	local front = g.FrontX
	local z = g.Z
	local halfW = g.W / 2
	local y0 = g.FloorY
	if tier == 1 then
		-- chatrč: šikmo přibitá prkna na zdech a kbelík u vchodu
		for _, s in { -1, 1 } do
			for k = 0, 1 do
				P(folder, Vector3.new(7, 1.1, 0.4), CFrame.new(front + 10 + k * 40, y0 + 6 + k * 3, z + s * (halfW + 0.1)) * CFrame.Angles(0, 0, math.rad(if k == 0 then 12 else -9)), WOOD, Enum.Material.WoodPlanks)
			end
		end
		P(folder, Vector3.new(1.6, 1.8, 1.6), CFrame.new(front - 3, y0 + 0.9, z + 13.5) * UP, Color3.fromRGB(120, 125, 135), Enum.Material.Metal, Enum.PartType.Cylinder)
		return
	end
	-- od chatky výš: dvě palmy u předních rohů
	for _, s in { -1, 1 } do
		palm(folder, Vector3.new(front - 2.5, y0, z + s * (halfW + 1.2)), 14 + tier, if s == 1 then 0.3 else 3.4)
	end
	if tier <= 3 then
		-- bílý laťkový plotek vedle vchodu
		for _, s in { -1, 1 } do
			P(folder, Vector3.new(0.5, 0.5, 5), CFrame.new(front - 5, y0 + 2.2, z + s * 13.6), WHITE)
			P(folder, Vector3.new(0.5, 0.5, 5), CFrame.new(front - 5, y0 + 1.1, z + s * 13.6), WHITE)
			for k = 0, 4 do
				P(folder, Vector3.new(0.4, 3, 0.7), CFrame.new(front - 5, y0 + 1.5, z + s * (11.6 + k)), WHITE)
			end
		end
	end
	if tier >= 3 then
		-- světýlka podél přední zdi
		for k = 0, 9 do
			local bulb = P(folder, Vector3.one * 0.8, CFrame.new(front - 0.6, y0 + 16.4 + math.sin(k / 9 * math.pi) * -1, z - halfW + 1.5 + k * (g.W - 3) / 9), BULBS[k % #BULBS + 1], Enum.Material.Neon, Enum.PartType.Ball)
			bulb.CastShadow = false
		end
	end
	if tier == 3 then
		-- vyhlídková věžička na hřebeni střechy
		local cx = g.CX - g.L * 0.25
		local baseY = g.PeakY - 1
		P(folder, Vector3.new(10, 7, 10), CFrame.new(cx, baseY + 3.5, z), g.Color, Enum.Material.WoodPlanks)
		for _, f in { -1, 1 } do
			local w1 = P(folder, Vector3.new(0.3, 3, 5), CFrame.new(cx + f * 5.05, baseY + 4.2, z), WARM, Enum.Material.Neon)
			w1.CastShadow = false
			local w2 = P(folder, Vector3.new(5, 3, 0.3), CFrame.new(cx, baseY + 4.2, z + f * 5.05), WARM, Enum.Material.Neon)
			w2.CastShadow = false
		end
		P(folder, Vector3.new(12, 0.8, 12), CFrame.new(cx, baseY + 7.4, z), WHITE)
		P(folder, Vector3.new(0.3, 7, 0.3), CFrame.new(cx, baseY + 11.3, z), WHITE)
		P(folder, Vector3.new(0.15, 2.2, 3.6), CFrame.new(cx, baseY + 13.6, z + 1.8), g.Color, Enum.Material.Fabric).Name = "Flag"
		-- surfy opřené o přední zeď
		for i, s in { -1, 1 } do
			P(folder, Vector3.new(0.4, 8, 2.2), CFrame.new(front - 0.9, y0 + 4, z + s * 15) * CFrame.Angles(0, 0, math.rad(-12)), BULBS[i * 2], Enum.Material.SmoothPlastic, Enum.PartType.Block)
		end
	end
	if tier >= 4 then
		local wall = if tier == 5 then MARBLE else g.Color:Lerp(WHITE, 0.7)
		-- věže na předních rozích
		for _, s in { -1, 1 } do
			tower(folder, Vector3.new(front + 2, y0, z + s * (halfW - 1)), g.H + 13, 4, wall, if tier == 5 then "Dome" else "Cone")
		end
		-- sloupy u vchodu
		for _, s in { -1, 1 } do
			P(folder, Vector3.new(g.H, 2.2, 2.2), CFrame.new(front - 2.5, y0 + 1 + g.H / 2, z + s * 9.6) * UP, WHITE, Enum.Material.Marble, Enum.PartType.Cylinder)
			P(folder, Vector3.new(1, 3.2, 3.2), CFrame.new(front - 2.5, y0 + 1.5, z + s * 9.6) * UP, if tier == 5 then GOLD else WHITE, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			P(folder, Vector3.new(1, 3.2, 3.2), CFrame.new(front - 2.5, y0 + g.H + 0.5, z + s * 9.6) * UP, if tier == 5 then GOLD else WHITE, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			local lamp = P(folder, Vector3.new(1.2, 1.6, 1.2), CFrame.new(front - 2.5, y0 + g.H + 2, z + s * 9.6), WARM, Enum.Material.Neon)
			light(lamp, WARM, 16)
		end
		-- stříška nad vchodem mezi sloupy
		P(folder, Vector3.new(5, 1, 22), CFrame.new(front - 2.5, y0 + g.H + 1.4, z), if tier == 5 then GOLD else WHITE)
	end
	if tier == 5 then
		-- velká zlatá koruna nad předním štítem (vidět z pláže)
		local crownC = Vector3.new(front + 4, g.PeakY + 3.4, z)
		local band = P(folder, Vector3.new(3.4, 10, 10), CFrame.new(crownC) * UP, GOLD, Enum.Material.Foil, Enum.PartType.Cylinder)
		band.Reflectance = 0.2
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			local tip = crownC + Vector3.new(math.cos(a) * 4.3, 3.4, math.sin(a) * 4.3)
			P(folder, Vector3.new(1.6, 3.6, 1.6), CFrame.new(tip), GOLD, Enum.Material.Foil)
			P(folder, Vector3.one * 1.4, CFrame.new(tip + Vector3.new(0, 2.4, 0)), BULBS[k % #BULBS + 1], Enum.Material.Neon, Enum.PartType.Ball)
		end
		-- zadní věže (palác má čtyři)
		for _, s in { -1, 1 } do
			tower(folder, Vector3.new(g.BackX - 2, y0, z + s * (halfW - 1)), g.H + 13, 4, MARBLE, "Dome")
		end
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Rate = 12
		sparkle.Lifetime = NumberRange.new(1, 2)
		sparkle.Speed = NumberRange.new(1, 3)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
		sparkle.Color = ColorSequence.new(GOLD)
		sparkle.LightEmission = 1
		sparkle.Parent = band
		light(band, GOLD, 30)
		-- červený koberec ke vchodu se zlatým lemem
		P(folder, Vector3.new(14, 0.12, 9), CFrame.new(front - 8, y0 + 0.08, z), Color3.fromRGB(190, 25, 40), Enum.Material.Fabric)
		for _, s in { -1, 1 } do
			P(folder, Vector3.new(14, 0.14, 0.5), CFrame.new(front - 8, y0 + 0.09, z + s * 4.6), GOLD)
		end
	end
end

-- Nastaví vzhled domečku (tier 0 = volný domek bez majitele: původní vzhled bez ozdob)
function HouseTiers.Apply(house: any, tier: number)
	local model: Model = house.Model
	local old = model:FindFirstChild("TierDeco")
	if old then
		old:Destroy()
	end
	local g = geometry(house)
	restyle(model, g, if tier == 0 then 2 else tier)
	local tierCfg = House.Tiers[tier]
	local baseName = House.Names[house.Index] or ("House " .. house.Index)
	for _, label in house.HouseNameLabels or {} do
		label.Text = if tierCfg and tier ~= 2 then `{baseName} {tierCfg.Name}` else baseName
	end
	if tier >= 1 then
		local folder = Instance.new("Folder")
		folder.Name = "TierDeco"
		build(folder, g, tier)
		folder.Parent = model
	end
end

-- Jakou úroveň si hráč zaslouží (podle levelu, dárkových ostrovů a Obřího dárku)
function HouseTiers.Earned(data: any): number
	local best = 1
	for i, t in House.Tiers do
		local ok = (t.MinLevel ~= nil and (data.Level or 1) >= t.MinLevel)
			or (t.Gift ~= nil and data.ClaimedGifts and data.ClaimedGifts[t.Gift] == true)
			or (t.Giant == true and data.GiftEverOpened == true)
		if i == 1 or ok then
			best = math.max(best, i)
		end
	end
	return best
end

return HouseTiers

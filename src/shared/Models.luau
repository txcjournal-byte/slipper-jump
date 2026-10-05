--!strict
-- Továrna na modely. Nejdřív hledá hezký model v ReplicatedStorage.Assets.<Kategorie>.<Id>,
-- když tam není, postaví dočasný model z dílů (low-poly, zaoblené tvary, jasné barvy).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollectionService = game:GetService("CollectionService")

local Catalog = require(script.Parent.Catalog)

local Models = {}

type Builder = {
	Model: Model,
	Handle: BasePart,
	Add: (self: Builder, shape: Enum.PartType | string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?) -> BasePart,
}

local function newBuilder(name: string, handleSize: Vector3, color: Color3, shape: Enum.PartType?, material: Enum.Material?): Builder
	local model = Instance.new("Model")
	model.Name = name
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = shape or Enum.PartType.Block
	handle.Size = handleSize
	handle.Color = color
	handle.Material = material or Enum.Material.SmoothPlastic
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.CFrame = CFrame.identity
	handle.Parent = model
	model.PrimaryPart = handle

	local builder = { Model = model, Handle = handle } :: any
	function builder.Add(self: Builder, partShape: Enum.PartType | string, size: Vector3, cf: CFrame, partColor: Color3, partMaterial: Enum.Material?): BasePart
		local part: BasePart
		if partShape == "Wedge" then
			part = Instance.new("WedgePart")
		elseif partShape == "CornerWedge" then
			part = Instance.new("CornerWedgePart")
		else
			local p = Instance.new("Part")
			p.Shape = partShape :: Enum.PartType
			part = p
		end
		part.Size = size
		part.CFrame = cf
		part.Color = partColor
		part.Material = partMaterial or Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = self.Model
		return part
	end
	return builder
end

-- Všechny díly: bez kolizí, nehmotné, přivařené k Handle
local function finalize(model: Model): Model
	local handle = model.PrimaryPart :: BasePart
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
			descendant.CastShadow = descendant.Size.Magnitude > 1.5
			if descendant ~= handle then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = descendant
				weld.Parent = descendant
			end
		end
	end
	return model
end

-- Zvětší/zmenší model (násobí současnou velikost). Kulaté a válcové SpecialMeshe mají Scale relativní
-- k velikosti dílu, takže jim ho po ScaleTo vrátíme, aby se nezvětšily dvakrát.
function Models.Scale(model: Model, factor: number)
	local meshScales: { [SpecialMesh]: Vector3 } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("SpecialMesh") and descendant.MeshType ~= Enum.MeshType.FileMesh then
			meshScales[descendant] = descendant.Scale
		end
	end
	model:ScaleTo(model:GetScale() * factor)
	for mesh, scale in meshScales do
		mesh.Scale = scale
	end
end

-- Cílová velikost hezkých modelů (nejdelší rozměr ve studech) – vygenerované modely se přizpůsobí samy
local TARGET_SIZE: { [string]: number } = { Slippers = 2.3, Hats = 2.6, Items = 3.8 }

local function fromAssets(category: string, id: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild(category)
	local template = folder and folder:FindFirstChild(id)
	if not template then
		return nil
	end
	-- přijme Model, ale i samotný MeshPart / Part (např. vygenerovaný Assistantem)
	local clone: Model
	if template:IsA("Model") then
		clone = template:Clone()
	elseif template:IsA("BasePart") then
		clone = Instance.new("Model")
		template:Clone().Parent = clone
	else
		return nil
	end
	clone.Name = id
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy() -- bezpečnost: modely z Toolboxu nesmí mít skripty
		elseif descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") then
			descendant:Destroy() -- spojíme si to po svém
		end
	end
	if #clone:GetDescendants() == 0 then
		return nil
	end
	-- AI / importované modely mívají pivot nebo PrimaryPart natočený (např. -90° kolem X).
	-- Srovnáme pivot se světem, aby RotateY, velikost i spodní okraj počítaly se svislou osou Y.
	clone.PrimaryPart = nil
	clone.WorldPivot = CFrame.new(clone:GetPivot().Position)
	-- volitelné otočení (atribut RotateY ve stupních na modelu v Assets), když špička nemíří dopředu
	local rotate = template:GetAttribute("RotateY")
	if type(rotate) == "number" and rotate ~= 0 then
		clone:PivotTo(clone:GetPivot() * CFrame.Angles(0, math.rad(rotate), 0))
	end
	-- díl "Attach" = model je ve skutečné velikosti a Attach říká, kde je úchyt (u čepic 0,25 pod temenem hlavy)
	local attach = clone:FindFirstChild("Attach")
	local attachPosition: Vector3? = nil
	if attach and attach:IsA("BasePart") then
		attachPosition = attach.Position
		attach:Destroy()
	else
		-- automatická velikost
		local _, size = clone:GetBoundingBox()
		local longest = math.max(size.X, size.Y, size.Z)
		local target = TARGET_SIZE[category] or 3
		if longest > 0 then
			Models.Scale(clone, target / longest)
		end
	end
	-- vlastní neviditelný Handle: boty a předměty uprostřed, čepice u spodního okraje
	local boxCFrame, boxSize = clone:GetBoundingBox()
	local anchor = if attachPosition
		then CFrame.new(attachPosition)
		elseif category == "Hats" then boxCFrame * CFrame.new(0, -boxSize.Y / 2, 0)
		else boxCFrame
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.2, 0.2, 0.2)
	handle.Transparency = 1
	handle.CFrame = CFrame.new(anchor.Position)
	handle.Parent = clone
	clone.PrimaryPart = handle
	clone:PivotTo(CFrame.identity)
	return finalize(clone)
end

local BALL = Enum.PartType.Ball
local BLOCK = Enum.PartType.Block
local CYL = Enum.PartType.Cylinder
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.fromRGB(25, 25, 30)
local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass
local METAL = Enum.Material.Metal

local function eyes(b: Builder, y: number, z: number, spread: number, size: number)
	for _, side in { -1, 1 } do
		b:Add(BALL, Vector3.one * size, CFrame.new(side * spread, y, z), WHITE)
		b:Add(BALL, Vector3.one * size * 0.5, CFrame.new(side * spread, y, z - size * 0.35), BLACK)
	end
end

-- ===== Vytuněné drahé boty =====
-- Čím dražší bota (pozice v řadě 1–20), tím víc „tuningu“: neonové lemy, drahokamy, chromová pata,
-- křídla, svítící prstenec, ostny a obří drahokam. Díly s tagem ShoeRainbow klient přebarvuje dokola
-- (duhově se přelévají).
local function tagPart(part: BasePart, tag: string)
	CollectionService:AddTag(part, tag)
end

local function tune(b: Builder, cfg: any, tier: number, isSneaker: boolean)
	if tier < 10 or cfg.Worn then
		return
	end
	local glow = cfg.TrailColor
	local accent = cfg.Accent
	local e = cfg.Effect
	local halfW = if isSneaker then 0.69 else 0.64
	local soleY = if isSneaker then 0.02 else 0
	local length = if isSneaker then 3.3 else 3.2
	local topY = if isSneaker then (if cfg.HighTop then 1.9 else 1.15) else 0.7
	local cycle = tier >= 18 -- nejdražší boty se duhově přelévají
	-- 1) neonový lem kolem podrážky (od Golden)
	for _, side in { -1, 1 } do
		local strip = b:Add(BLOCK, Vector3.new(0.09, 0.12, length - 0.6), CFrame.new(side * halfW, soleY, 0), glow, NEON)
		if cycle then
			tagPart(strip, "ShoeRainbow")
		end
	end
	local toe = b:Add(BLOCK, Vector3.new(halfW * 2 - 0.2, 0.12, 0.09), CFrame.new(0, soleY, -length / 2 + 0.05), glow, NEON)
	local heel = b:Add(BLOCK, Vector3.new(halfW * 2 - 0.2, 0.12, 0.09), CFrame.new(0, soleY, length / 2 - 0.05), glow, NEON)
	if cycle then
		tagPart(toe, "ShoeRainbow")
		tagPart(heel, "ShoeRainbow")
	end
	-- 2) drahokamy po stranách (od Rocket)
	if tier >= 12 then
		for _, side in { -1, 1 } do
			for i = 0, 2 do
				b:Add(BLOCK, Vector3.one * 0.2, CFrame.new(side * (halfW + 0.04), soleY + 0.28, -0.6 + i * 0.6) * CFrame.Angles(math.rad(45), 0, math.rad(45)), glow, GLASS)
			end
		end
	end
	-- 3) chromová pata a svítící tečky nahoře (od Crystal)
	if tier >= 14 then
		b:Add(BLOCK, Vector3.new(halfW * 2 + 0.06, 0.45, 0.35), CFrame.new(0, soleY + 0.35, length / 2 - 0.35), accent, METAL)
		for i = -1, 1 do
			local dot = b:Add(BALL, Vector3.one * 0.16, CFrame.new(i * 0.3, topY + 0.02, 0.35), glow, NEON)
			if cycle then
				tagPart(dot, "ShoeRainbow")
			end
		end
	end
	-- 4) křídla po stranách (od Cloud Wing), u Cloud Wing obří a bílá
	if tier >= 16 then
		local big = e == "Clouds"
		local wingColor = if big then Color3.fromRGB(250, 252, 255) else accent
		for _, side in { -1, 1 } do
			for k = 0, 2 do
				local len = (if big then 1.6 else 1.1) - k * 0.25
				local h = (if big then 0.9 else 0.6) - k * 0.12
				local part = b:Add("Wedge", Vector3.new(0.08, h, len), CFrame.new(side * (halfW + 0.12), topY * 0.6 + k * 0.16, 0.55 + k * 0.12) * CFrame.Angles(math.rad(-25 - k * 10), math.rad(side * 15), 0), wingColor, if big then Enum.Material.SmoothPlastic else METAL)
				if k == 0 and not big then
					part.Material = NEON
					part.Color = glow
					if cycle then
						tagPart(part, "ShoeRainbow")
					end
				end
			end
		end
	end
	-- Robot: anténa se svítící kuličkou
	if e == "Leds" and tier >= 16 then
		b:Add(CYL, Vector3.new(0.9, 0.08, 0.08), CFrame.new(0.3, topY + 0.45, 0.5) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(180, 185, 195), METAL)
		b:Add(BALL, Vector3.one * 0.25, CFrame.new(0.3, topY + 0.92, 0.5), glow, NEON)
	end
	-- 5) svítící prstenec kolem boty, který se točí (od Galaxy)
	if tier >= 18 then
		local count = 14
		for i = 0, count - 1 do
			local a = i / count * math.pi * 2
			local seg = b:Add(BLOCK, Vector3.new(0.12, 0.08, 0.42), CFrame.new(math.cos(a) * 1.15, soleY + 0.1, math.sin(a) * 1.85) * CFrame.Angles(0, -a, 0), glow, NEON)
			seg.Transparency = 0.15
			tagPart(seg, "ShoeRainbow")
		end
		-- Galaxy: malá planeta s prstencem na patě
		if e == "Stars" then
			b:Add(BALL, Vector3.one * 0.55, CFrame.new(0, topY + 0.3, 0.75), Color3.fromRGB(255, 150, 80))
			b:Add(CYL, Vector3.new(0.05, 1.0, 1.0), CFrame.new(0, topY + 0.3, 0.75) * CFrame.Angles(math.rad(20), 0, math.rad(90)), Color3.fromRGB(200, 170, 255), NEON)
		end
	end
	-- 6) ostny podél hřbetu a rohy (Dragon a výš)
	if tier >= 19 then
		for i = 0, 3 do
			local spike = b:Add("Wedge", Vector3.new(0.1, 0.45 - i * 0.05, 0.4), CFrame.new(0, topY + 0.15, 0.2 + i * 0.32), accent, METAL)
			spike.Color = if e == "Flames" then Color3.fromRGB(255, 200, 60) else accent
		end
		if e == "Flames" then
			for _, side in { -1, 1 } do
				b:Add("Wedge", Vector3.new(0.12, 0.55, 0.3), CFrame.new(side * 0.35, topY + 0.2, -0.95) * CFrame.Angles(0, 0, math.rad(side * -15)), Color3.fromRGB(250, 240, 220))
				b:Add(BALL, Vector3.one * 0.16, CFrame.new(side * 0.25, topY - 0.05, -1.2), Color3.fromRGB(255, 60, 30), NEON)
			end
		end
	end
	-- 7) obří drahokam a zlatá korunka (nejlepší boty)
	if tier >= 20 then
		local gem = b:Add(BLOCK, Vector3.one * 0.6, CFrame.new(0, topY + 0.55, -0.4) * CFrame.Angles(math.rad(45), math.rad(45), 0), Color3.fromRGB(150, 235, 255), GLASS)
		gem.Reflectance = 0.4
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			b:Add("Wedge", Vector3.new(0.1, 0.32, 0.2), CFrame.new(math.cos(a) * 0.42, topY + 0.15, -0.4 + math.sin(a) * 0.42) * CFrame.Angles(0, -a, 0), Color3.fromRGB(255, 210, 60), METAL)
		end
	end
end

-- ===== Tenisky (jeden kus, špička míří na -Z) =====

local function sneaker(id: string, cfg: any): Model
	local color, accent = cfg.Color, cfg.Accent
	local e = cfg.Effect
	local upperMaterial = Enum.Material.SmoothPlastic
	if e == "Crown" then
		upperMaterial = METAL
	elseif e == "Crystals" or e == "Stars" then
		upperMaterial = GLASS
	elseif cfg.Worn then
		upperMaterial = Enum.Material.Fabric
	end
	local soleColor = if cfg.Worn then Color3.fromRGB(150, 130, 105) elseif e == "Crown" then Color3.fromRGB(255, 240, 200) else WHITE
	local b = newBuilder(id, Vector3.new(1.35, 0.42, 2.5), soleColor, BLOCK)
	-- podrážka se zaoblenou špičkou a pruhem
	b:Add(CYL, Vector3.new(0.42, 1.35, 1.35), CFrame.new(0, 0, -1.2) * CFrame.Angles(0, 0, math.rad(90)), soleColor)
	b:Add(BLOCK, Vector3.new(1.38, 0.1, 2.5), CFrame.new(0, -0.12, 0), if cfg.Worn then Color3.fromRGB(110, 95, 80) else accent)
	-- svršek
	b:Add(BLOCK, Vector3.new(1.22, 0.8, 1.9), CFrame.new(0, 0.6, 0.25), color, upperMaterial)
	b:Add(BALL, Vector3.new(1.22, 0.9, 1.3), CFrame.new(0, 0.42, -0.75), color, upperMaterial)
	-- jazyk a tkaničky
	b:Add(BLOCK, Vector3.new(0.7, 0.5, 0.9), CFrame.new(0, 1.05, -0.1) * CFrame.Angles(math.rad(-20), 0, 0), accent)
	for i = 0, 2 do
		b:Add(BLOCK, Vector3.new(0.9, 0.1, 0.12), CFrame.new(0, 1.0 + i * 0.03, -0.45 + i * 0.28), if cfg.Worn then Color3.fromRGB(170, 160, 140) else WHITE)
	end
	-- boční pruh (vlastní design, žádné logo)
	for _, side in { -1, 1 } do
		b:Add("Wedge", Vector3.new(0.08, 0.45, 1.3), CFrame.new(side * 0.62, 0.55, 0.3), accent, if e == "Leds" or e == "Crown" then NEON else Enum.Material.SmoothPlastic)
	end
	if cfg.HighTop then
		b:Add(BLOCK, Vector3.new(1.18, 0.9, 1.1), CFrame.new(0, 1.35, 0.6), color, upperMaterial)
		b:Add(BLOCK, Vector3.new(1.22, 0.2, 1.14), CFrame.new(0, 1.82, 0.6), accent)
	end
	if cfg.Worn then
		-- izolepa a bláto
		b:Add(BLOCK, Vector3.new(1.3, 0.25, 0.3), CFrame.new(0, 0.55, -0.4) * CFrame.Angles(0, math.rad(12), 0), Color3.fromRGB(200, 200, 200))
		b:Add(BLOCK, Vector3.new(1.3, 0.25, 0.3), CFrame.new(0, 0.5, 0.6) * CFrame.Angles(0, math.rad(-10), 0), Color3.fromRGB(200, 200, 200))
		for i = 0, 2 do
			b:Add(BALL, Vector3.new(0.5, 0.3, 0.6), CFrame.new(-0.5 + i * 0.45, 0.3, 0.9 - i * 0.6), Color3.fromRGB(90, 70, 45))
		end
	end
	if e == "Crown" then
		b:Add(CYL, Vector3.new(0.3, 0.7, 0.7), CFrame.new(0, 2.0, 0.6) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 215, 60), METAL)
		for i = 0, 3 do
			b:Add(BALL, Vector3.one * 0.22, CFrame.new(-0.45 + i * 0.3, 0.55, -1.25), accent, GLASS)
		end
	elseif e == "Flames" or e == "Clouds" then
		for i = 0, 2 do
			b:Add("Wedge", Vector3.new(0.1, 0.5, 0.4), CFrame.new(0.63, 0.5, 0.9 - i * 0.4), accent)
		end
	elseif e == "Boing" then
		b:Add(CYL, Vector3.new(0.6, 0.5, 0.5), CFrame.new(0, 0.7, 1.35) * CFrame.Angles(0, math.rad(90), 0), accent, METAL)
	end
	tune(b, cfg, Catalog.SlipperIndex(id), true)
	return finalize(b.Model)
end

-- ===== Pantofle (jeden kus, špička míří na -Z) =====

function Models.Slipper(id: string): Model
	local existing = fromAssets("Slippers", id)
	if existing then
		return existing
	end
	local cfg = Catalog.Slipper(id) or Catalog.Slippers[1]
	if cfg.Style == "Sneaker" then
		return sneaker(id, cfg)
	end
	local color, accent = cfg.Color, cfg.Accent
	local material = Enum.Material.SmoothPlastic
	if cfg.Effect == "Sparks" or cfg.Effect == "Crown" then
		material = METAL
	elseif cfg.Effect == "Crystals" then
		material = GLASS
	elseif cfg.Effect == "Fluff" or cfg.Effect == "Clouds" then
		material = Enum.Material.Fabric
	end
	local b = newBuilder(id, Vector3.new(1.25, 0.32, 2.3), color, BLOCK, material)
	-- zaoblená špička a pata
	b:Add(CYL, Vector3.new(0.32, 1.25, 1.25), CFrame.new(0, 0, -1.15) * CFrame.Angles(0, 0, math.rad(90)), color, material)
	b:Add(CYL, Vector3.new(0.32, 1.2, 1.2), CFrame.new(0, 0, 1.15) * CFrame.Angles(0, 0, math.rad(90)), color, material)
	-- pásek přes nárt
	b:Add(BLOCK, Vector3.new(1.35, 0.55, 0.9), CFrame.new(0, 0.38, -0.55), accent, material)
	local e = cfg.Effect
	if e == "Fin" then
		b:Add("Wedge", Vector3.new(0.18, 0.9, 0.9), CFrame.new(0, 0.95, 0.1), color)
	elseif e == "Fluff" then
		for _, side in { -1, 1 } do
			b:Add(BLOCK, Vector3.new(0.25, 1.1, 0.4), CFrame.new(side * 0.35, 1.1, -0.2) * CFrame.Angles(0, 0, math.rad(-side * 12)), color, material)
			b:Add(BLOCK, Vector3.new(0.12, 0.8, 0.25), CFrame.new(side * 0.35, 1.1, -0.36) * CFrame.Angles(0, 0, math.rad(-side * 12)), accent)
		end
		eyes(b, 0.55, -1.0, 0.28, 0.25)
	elseif e == "Squeak" then
		b:Add(BALL, Vector3.new(0.9, 0.8, 0.9), CFrame.new(0, 0.85, -0.7), color)
		b:Add("Wedge", Vector3.new(0.45, 0.2, 0.4), CFrame.new(0, 0.8, -1.25) * CFrame.Angles(0, math.rad(180), 0), accent)
		eyes(b, 1.0, -1.05, 0.2, 0.18)
	elseif e == "Leaves" then
		for i = 0, 4 do
			b:Add("Wedge", Vector3.new(0.12, 0.7, 0.3), CFrame.new(-0.4 + i * 0.2, 0.95, -0.55) * CFrame.Angles(0, 0, math.rad(-20 + i * 10)), accent)
		end
	elseif e == "Snow" then
		b:Add(BLOCK, Vector3.new(0.9, 0.2, 1.2), CFrame.new(0, 0.2, 0.3), accent)
		b:Add("Wedge", Vector3.new(0.35, 0.18, 0.35), CFrame.new(0, 0.7, -1.1) * CFrame.Angles(0, math.rad(180), 0), Color3.fromRGB(255, 170, 40))
		eyes(b, 0.8, -1.0, 0.22, 0.2)
	elseif e == "Rainbow" then
		local rainbow = { Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 170, 40), Color3.fromRGB(255, 230, 60), Color3.fromRGB(80, 210, 90), Color3.fromRGB(60, 150, 255), Color3.fromRGB(170, 80, 255) }
		for i, c in rainbow do
			b:Add(BLOCK, Vector3.new(1.28, 0.08, 2.3), CFrame.new(0, -0.18 + i * 0.001 - 0.05 * i, 0), c)
		end
	elseif e == "Boing" then
		for i = 0, 2 do
			b:Add(CYL, Vector3.new(0.12, 0.8, 0.8), CFrame.new(0, -0.3 - i * 0.18, 0.3) * CFrame.Angles(0, 0, math.rad(90)), accent, METAL)
		end
	elseif e == "Smoke" then
		b:Add(CYL, Vector3.new(0.7, 0.55, 0.55), CFrame.new(0, 0.35, 1.3) * CFrame.Angles(0, math.rad(90), 0), accent, METAL)
		b:Add(CYL, Vector3.new(0.1, 0.4, 0.4), CFrame.new(0, 0.35, 1.68) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(255, 150, 40), NEON)
	elseif e == "Footprints" then
		for i = 0, 3 do
			b:Add("Wedge", Vector3.new(0.14, 0.4, 0.35), CFrame.new(0, 0.3, 0.1 + i * 0.35), accent)
		end
		eyes(b, 0.6, -1.0, 0.3, 0.25)
	elseif e == "Crystals" then
		for i = -1, 1 do
			b:Add(BLOCK, Vector3.new(0.3, 0.6, 0.3), CFrame.new(i * 0.35, 0.6, -0.55) * CFrame.Angles(math.rad(45), math.rad(45), 0), accent, GLASS)
		end
	elseif e == "Steam" then
		b:Add(BLOCK, Vector3.new(1.28, 0.1, 2.0), CFrame.new(0, 0.17, 0), accent)
		b:Add(BLOCK, Vector3.new(0.6, 0.12, 0.3), CFrame.new(0.2, 0.2, 0.4), Color3.fromRGB(255, 200, 60), NEON)
	elseif e == "Clouds" then
		for _, side in { -1, 1 } do
			b:Add("Wedge", Vector3.new(0.12, 0.6, 1.0), CFrame.new(side * 0.75, 0.55, 0.5) * CFrame.Angles(0, 0, math.rad(side * 40)), accent)
		end
		b:Add(BALL, Vector3.new(0.9, 0.6, 0.9), CFrame.new(0, 0.7, -0.6), color, material)
	elseif e == "Leds" then
		for i = -1, 1 do
			b:Add(BLOCK, Vector3.new(0.2, 0.2, 0.2), CFrame.new(i * 0.4, 0.68, -0.55), accent, NEON)
		end
	elseif e == "Stars" then
		for i = 0, 4 do
			local a = i * 1.3
			b:Add(BALL, Vector3.one * 0.18, CFrame.new(math.cos(a) * 0.45, 0.2, math.sin(a) * 0.8), accent, NEON)
		end
		b:Add(BALL, Vector3.one * 0.4, CFrame.new(0, 0.75, -0.55), Color3.fromRGB(255, 180, 60))
	elseif e == "Flames" then
		for i = 0, 3 do
			b:Add("Wedge", Vector3.new(0.14, 0.4, 0.35), CFrame.new(0, 0.3, 0.1 + i * 0.35), accent)
		end
		for _, side in { -1, 1 } do
			b:Add("Wedge", Vector3.new(0.15, 0.45, 0.25), CFrame.new(side * 0.35, 0.85, -0.6), accent)
		end
	elseif e == "Crown" then
		b:Add(CYL, Vector3.new(0.35, 0.8, 0.8), CFrame.new(0, 0.8, -0.55) * CFrame.Angles(0, 0, math.rad(90)), accent, METAL)
		for i = 0, 4 do
			local a = i / 5 * math.pi * 2
			b:Add("Wedge", Vector3.new(0.1, 0.3, 0.2), CFrame.new(math.cos(a) * 0.35, 1.1, -0.55 + math.sin(a) * 0.35) * CFrame.Angles(0, -a, 0), accent, METAL)
		end
		b:Add(BALL, Vector3.one * 0.25, CFrame.new(0, 0.8, -0.98), Color3.fromRGB(255, 60, 90), GLASS)
	elseif e == "Seeds" then
		b:Add(BLOCK, Vector3.new(1.28, 0.1, 2.3), CFrame.new(0, 0.2, 0), Color3.fromRGB(255, 245, 230))
		for i = 0, 5 do
			b:Add(BALL, Vector3.new(0.12, 0.05, 0.2), CFrame.new(-0.4 + (i % 3) * 0.4, 0.27, 0.2 + (i // 3) * 0.5), BLACK)
		end
	elseif e == "Drops" then
		b:Add(BALL, Vector3.new(0.4, 0.3, 0.4), CFrame.new(0, 0.7, -0.55), Color3.fromRGB(255, 220, 80))
	end
	tune(b, cfg, Catalog.SlipperIndex(id), false)
	return finalize(b.Model)
end

-- ===== Čepice (spodní okraj v y = 0) =====

function Models.Hat(id: string): Model
	local existing = fromAssets("Hats", id)
	if existing then
		return existing
	end
	local cfg = Catalog.Hat(id) or Catalog.Hats[1]
	local color, accent = cfg.Color, cfg.Accent
	local shape = cfg.Shape
	local b = newBuilder(id, Vector3.new(0.4, 0.4, 0.4), color, BLOCK)
	b.Handle.Transparency = 1
	if shape == "Cap" or shape == "Propeller" then
		b:Add(BALL, Vector3.new(2.2, 1.4, 2.2), CFrame.new(0, 0.2, 0), color)
		b:Add(CYL, Vector3.new(0.15, 1.6, 1.8), CFrame.new(0, 0.05, -1.1) * CFrame.Angles(0, 0, math.rad(90)), accent)
		if shape == "Propeller" then
			b:Add(CYL, Vector3.new(0.6, 0.15, 0.15), CFrame.new(0, 1.15, 0) * CFrame.Angles(0, 0, math.rad(90)), BLACK)
			b:Add(BLOCK, Vector3.new(2.4, 0.08, 0.35), CFrame.new(0, 1.45, 0), accent)
			b:Add(BLOCK, Vector3.new(0.35, 0.08, 2.4), CFrame.new(0, 1.45, 0), Color3.fromRGB(60, 150, 255))
		end
	elseif shape == "Brim" then
		b:Add(CYL, Vector3.new(0.15, 3.4, 3.4), CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), color)
		b:Add(CYL, Vector3.new(1.2, 2.0, 2.0), CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.rad(90)), color)
		b:Add(CYL, Vector3.new(0.3, 2.05, 2.05), CFrame.new(0, 0.35, 0) * CFrame.Angles(0, 0, math.rad(90)), accent)
	elseif shape == "Dome" then
		b:Add(BALL, Vector3.new(2.3, 1.6, 2.3), CFrame.new(0, 0.25, 0), color)
		b:Add(BALL, Vector3.new(0.5, 0.5, 0.5), CFrame.new(0.9, 0.3, -0.5), accent)
	elseif shape == "Goggles" then
		b:Add(BLOCK, Vector3.new(2.2, 0.3, 2.2), CFrame.new(0, -0.3, 0), color)
		for _, side in { -1, 1 } do
			b:Add(CYL, Vector3.new(0.3, 0.8, 0.8), CFrame.new(side * 0.45, -0.35, -1.1) * CFrame.Angles(0, math.rad(90), 0), accent, GLASS)
		end
	elseif shape == "Chef" then
		b:Add(CYL, Vector3.new(1.2, 2.0, 2.0), CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), color)
		b:Add(BALL, Vector3.new(2.6, 1.6, 2.6), CFrame.new(0, 1.5, 0), color)
	elseif shape == "Hood" then
		b:Add(BALL, Vector3.new(2.6, 2.0, 2.6), CFrame.new(0, 0.1, 0.1), color)
		b:Add("Wedge", Vector3.new(0.3, 1.2, 1.2), CFrame.new(0, 1.4, 0.3), color)
		eyes(b, 0.3, -1.15, 0.7, 0.4)
		b:Add(BLOCK, Vector3.new(1.6, 0.25, 0.2), CFrame.new(0, -0.3, -1.2), accent)
	elseif shape == "Crown" then
		b:Add(CYL, Vector3.new(0.7, 2.2, 2.2), CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), color, if id == "FlowerCrown" then Enum.Material.Grass else METAL)
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			local pos = Vector3.new(math.cos(a) * 1.0, 0.85, math.sin(a) * 1.0)
			if id == "FlowerCrown" then
				b:Add(BALL, Vector3.one * 0.55, CFrame.new(pos), if i % 2 == 0 then accent else Color3.fromRGB(255, 240, 90))
			else
				b:Add("Wedge", Vector3.new(0.2, 0.6, 0.45), CFrame.new(pos) * CFrame.Angles(0, -a + math.rad(90), 0), color, METAL)
				b:Add(BALL, Vector3.one * 0.25, CFrame.new(pos + Vector3.new(0, -0.3, 0)), accent, GLASS)
			end
		end
	elseif shape == "Pointy" then
		b:Add(CYL, Vector3.new(0.15, 3.2, 3.2), CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), color)
		for i = 0, 4 do
			local s = 2.0 - i * 0.4
			b:Add(CYL, Vector3.new(0.6, s, s), CFrame.new(0, 0.4 + i * 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)), color)
		end
		b:Add(BALL, Vector3.one * 0.45, CFrame.new(0.5, 1.2, -0.7), accent, NEON)
	elseif shape == "Helmet" then
		b:Add(BALL, Vector3.new(2.8, 2.6, 2.8), CFrame.new(0, 0, 0), color, if id == "KnightHelmet" then METAL else Enum.Material.SmoothPlastic)
		if id == "AstronautHelmet" then
			b:Add(BALL, Vector3.new(2.0, 1.6, 1.0), CFrame.new(0, -0.3, -1.05), accent, GLASS)
		else
			b:Add(BLOCK, Vector3.new(1.6, 0.25, 0.3), CFrame.new(0, -0.3, -1.3), BLACK)
			b:Add("Wedge", Vector3.new(0.25, 1.0, 1.4), CFrame.new(0, 1.6, 0.2), accent)
		end
	elseif shape == "Horns" then
		if id == "VikingHelmet" then
			b:Add(BALL, Vector3.new(2.5, 1.8, 2.5), CFrame.new(0, 0.2, 0), color, METAL)
		end
		for _, side in { -1, 1 } do
			b:Add("Wedge", Vector3.new(0.4, 1.3, 0.6), CFrame.new(side * 1.2, 0.8, 0) * CFrame.Angles(0, math.rad(90 * side), math.rad(side * -25)), accent)
		end
	elseif shape == "Halo" then
		for i = 0, 11 do
			local a = i / 12 * math.pi * 2
			b:Add(BLOCK, Vector3.new(0.3, 0.2, 0.65), CFrame.new(math.cos(a) * 1.1, 1.3, math.sin(a) * 1.1) * CFrame.Angles(0, -a, 0), color, NEON)
		end
	elseif shape == "Wig" then
		local colors = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 170, 40), Color3.fromRGB(255, 230, 60), Color3.fromRGB(80, 210, 90), Color3.fromRGB(60, 150, 255), Color3.fromRGB(170, 80, 255) }
		for i, c in colors do
			local a = i / #colors * math.pi * 2
			b:Add(BALL, Vector3.one * 1.3, CFrame.new(math.cos(a) * 0.8, 0.3 + (i % 2) * 0.3, math.sin(a) * 0.8), c)
		end
		b:Add(BALL, Vector3.one * 1.4, CFrame.new(0, 0.9, 0), Color3.fromRGB(255, 120, 220))
	elseif shape == "Buddy" then
		b:Add(BALL, Vector3.new(2.0, 1.8, 2.0), CFrame.new(0, 1.0, 0), color)
		eyes(b, 1.1, -0.9, 0.4, 0.45)
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			b:Add(CYL, Vector3.new(1.0, 0.35, 0.35), CFrame.new(math.cos(a) * 1.0, 0.1, math.sin(a) * 1.0) * CFrame.Angles(0, -a, math.rad(-30)), color)
		end
	elseif shape == "Bow" then
		b:Add(BLOCK, Vector3.new(2.2, 0.6, 2.2), CFrame.new(0, 0.3, 0), color, METAL)
		for _, side in { -1, 1 } do
			b:Add(BALL, Vector3.new(1.2, 0.9, 0.6), CFrame.new(side * 0.6, 1.0, 0) * CFrame.Angles(0, 0, math.rad(side * 20)), accent)
		end
		b:Add(BALL, Vector3.one * 0.55, CFrame.new(0, 0.95, 0), accent)
	end
	return finalize(b.Model)
end

-- ===== Předměty z vody (cca 3,5 studu velké, střed v počátku) =====

function Models.Item(id: string): Model
	local existing = fromAssets("Items", id)
	if existing then
		return existing
	end
	local cfg = Catalog.Item(id) or Catalog.Items[1]
	local c = cfg.Color
	local shape = cfg.Shape
	local rarity = Catalog.Rarity(cfg.Rarity)
	local b = newBuilder(id, Vector3.new(0.5, 0.5, 0.5), c, BLOCK)
	b.Handle.Transparency = 1
	local shine = if rarity.Order >= 5 then Enum.Material.Metal else Enum.Material.SmoothPlastic
	if shape == "Shell" then
		for i = 0, 4 do
			b:Add("Wedge", Vector3.new(0.5, 1.8, 1.4), CFrame.Angles(0, 0, math.rad(-40 + i * 20)) * CFrame.new(0, 0.9, 0), if i % 2 == 0 then c else c:Lerp(WHITE, 0.4))
		end
	elseif shape == "Ball" then
		b:Add(BALL, Vector3.one * 2.6, CFrame.identity, c, if cfg.Rarity == "Common" then Enum.Material.Slate else Enum.Material.Glass)
		if cfg.Rarity == "Mythic" then
			b:Add(BALL, Vector3.one * 2.2, CFrame.identity, Color3.fromRGB(120, 220, 255), NEON)
		end
	elseif shape == "Block" then
		b:Add(BLOCK, Vector3.new(1.2, 2.2, 1.0), CFrame.new(0, 0.3, 0), c, Enum.Material.Fabric)
		b:Add(BLOCK, Vector3.new(1.2, 1.0, 2.0), CFrame.new(0, -0.9, -0.5), c, Enum.Material.Fabric)
		b:Add(BLOCK, Vector3.new(1.25, 0.3, 1.05), CFrame.new(0, 1.2, 0), Color3.fromRGB(230, 90, 90), Enum.Material.Fabric)
	elseif shape == "Stick" then
		if id == "Seaweed" then
			for i = -1, 1 do
				b:Add(BLOCK, Vector3.new(0.4, 3.2, 0.2), CFrame.new(i * 0.5, 0, 0) * CFrame.Angles(0, 0, math.rad(i * 12)), c, Enum.Material.Grass)
			end
		else
			b:Add(CYL, Vector3.new(2.4, 0.3, 0.3), CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)), c)
			b:Add(BLOCK, Vector3.new(1.3, 1.1, 0.2), CFrame.new(0, -1.0, 0), c)
		end
	elseif shape == "Ring" then
		if id == "Compass" then
			b:Add(CYL, Vector3.new(0.4, 2.6, 2.6), CFrame.Angles(0, math.rad(90), 0), c, METAL)
			b:Add(CYL, Vector3.new(0.45, 2.2, 2.2), CFrame.Angles(0, math.rad(90), 0), WHITE)
			b:Add(BLOCK, Vector3.new(0.2, 1.8, 0.5), CFrame.new(0, 0, -0.1), Color3.fromRGB(230, 50, 50))
		else
			for i = 0, 11 do
				local a = i / 12 * math.pi * 2
				b:Add(BALL, Vector3.one * 1.0, CFrame.new(math.cos(a) * 1.3, math.sin(a) * 1.3, 0), if i % 3 == 0 then WHITE else c)
			end
		end
	elseif shape == "Star" then
		for i = 0, 4 do
			local a = i / 5 * math.pi * 2
			b:Add("Wedge", Vector3.new(0.5, 0.4, 1.6), CFrame.Angles(0, 0, a) * CFrame.new(0, 0.9, 0) * CFrame.Angles(math.rad(90), 0, 0), c)
		end
		b:Add(CYL, Vector3.new(0.5, 1.0, 1.0), CFrame.Angles(0, math.rad(90), 0), c)
	elseif shape == "Duck" then
		local scale = if cfg.Rarity == "Secret" then 1.2 else 1
		b:Add(BALL, Vector3.new(2.4, 1.8, 2.8) * scale, CFrame.new(0, -0.4, 0.2), c)
		b:Add(BALL, Vector3.new(1.5, 1.5, 1.5) * scale, CFrame.new(0, 0.9 * scale, -0.6 * scale), c)
		b:Add("Wedge", Vector3.new(0.8, 0.35, 0.6) * scale, CFrame.new(0, 0.75 * scale, -1.5 * scale) * CFrame.Angles(0, math.rad(180), 0), Color3.fromRGB(255, 140, 20))
		eyes(b, 1.1 * scale, -1.25 * scale, 0.35, 0.3)
		if cfg.Rarity == "Secret" then
			b:Add(CYL, Vector3.new(0.4, 1.0, 1.0), CFrame.new(0, 1.9, -0.6) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 205, 40), NEON)
		end
	elseif shape == "Bucket" then
		b:Add(CYL, Vector3.new(2.2, 2.2, 2.2), CFrame.Angles(0, 0, math.rad(90)), c)
		b:Add(CYL, Vector3.new(0.3, 2.0, 2.0), CFrame.new(0, 1.0, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(245, 215, 150), Enum.Material.Sand)
		b:Add(BLOCK, Vector3.new(0.15, 1.2, 0.15), CFrame.new(1.1, 1.6, 0), BLACK)
	elseif shape == "Umbrella" then
		b:Add(CYL, Vector3.new(3.2, 0.2, 0.2), CFrame.Angles(0, 0, math.rad(90)), WHITE)
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			b:Add("Wedge", Vector3.new(0.9, 0.7, 1.4), CFrame.new(0, 1.5, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 0.7), if i % 2 == 0 then c else WHITE)
		end
	elseif shape == "Bottle" then
		b:Add(CYL, Vector3.new(2.4, 1.4, 1.4), CFrame.Angles(0, 0, math.rad(90)), c, GLASS).Transparency = 0.35
		b:Add(CYL, Vector3.new(0.8, 0.6, 0.6), CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), c, GLASS).Transparency = 0.35
		b:Add(CYL, Vector3.new(0.35, 0.65, 0.65), CFrame.new(0, 2.0, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(150, 100, 60), Enum.Material.Wood)
		if id == "MessageInABottle" then
			b:Add(CYL, Vector3.new(1.2, 0.5, 0.5), CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(245, 235, 200))
		elseif id == "GoldfishInABag" then
			b:Add(BALL, Vector3.new(0.5, 0.5, 0.9), CFrame.new(0, -0.2, 0), Color3.fromRGB(255, 130, 20))
		else
			b:Add(BLOCK, Vector3.new(0.2, 0.9, 0.7), CFrame.new(0, 0, 0), WHITE)
			b:Add(BLOCK, Vector3.new(0.4, 0.3, 1.0), CFrame.new(0, -0.55, 0), Color3.fromRGB(150, 90, 40), Enum.Material.Wood)
		end
	elseif shape == "Chest" then
		b:Add(BLOCK, Vector3.new(2.8, 1.6, 1.8), CFrame.new(0, -0.3, 0), c, Enum.Material.Wood)
		b:Add(CYL, Vector3.new(2.8, 1.8, 1.8), CFrame.new(0, 0.5, 0), c, Enum.Material.Wood)
		b:Add(BLOCK, Vector3.new(0.4, 0.5, 0.2), CFrame.new(0, 0.3, -0.95), Color3.fromRGB(255, 205, 40), METAL)
		for i = -1, 1 do
			b:Add(CYL, Vector3.new(0.12, 0.6, 0.6), CFrame.new(i * 0.6, 1.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 205, 40), METAL)
		end
	elseif shape == "Creature" then
		b:Add(BALL, Vector3.new(2.4, 2.2, 2.2), CFrame.new(0, 0.4, 0), c, if id == "GlowingJellyfish" then NEON else Enum.Material.SmoothPlastic)
		eyes(b, 0.6, -1.0, 0.45, 0.5)
		if id == "CrabInAHat" then
			for _, side in { -1, 1 } do
				b:Add(BALL, Vector3.new(0.9, 0.7, 0.7), CFrame.new(side * 1.5, 0.2, -0.4), c)
			end
			b:Add(CYL, Vector3.new(0.8, 1.1, 1.1), CFrame.new(0, 1.8, 0) * CFrame.Angles(0, 0, math.rad(90)), BLACK)
			b:Add(CYL, Vector3.new(0.1, 1.8, 1.8), CFrame.new(0, 1.35, 0) * CFrame.Angles(0, 0, math.rad(90)), BLACK)
		elseif id == "WaterUnicorn" then
			b:Add(BALL, Vector3.new(1.3, 1.3, 1.6), CFrame.new(0, 1.7, -0.6), c)
			b:Add(CYL, Vector3.new(1.2, 0.3, 0.3), CFrame.new(0, 2.6, -1.0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(0, 0, math.rad(20)), Color3.fromRGB(255, 220, 90), NEON)
			b:Add(BLOCK, Vector3.new(0.3, 1.2, 1.4), CFrame.new(0, 1.5, 0.5), Color3.fromRGB(255, 120, 220))
		else
			for i = 0, 5 do
				local a = i / 6 * math.pi * 2
				b:Add(CYL, Vector3.new(1.4, 0.35, 0.35), CFrame.new(math.cos(a) * 0.7, -1.0, math.sin(a) * 0.7) * CFrame.Angles(0, 0, math.rad(90)), c)
			end
			if id == "OctopusWithGlasses" then
				for _, side in { -1, 1 } do
					b:Add(CYL, Vector3.new(0.1, 0.8, 0.8), CFrame.new(side * 0.45, 0.6, -1.25) * CFrame.Angles(0, math.rad(90), 0), BLACK)
				end
			end
		end
	elseif shape == "Statue" then
		b:Add(CYL, Vector3.new(0.6, 2.4, 2.4), CFrame.new(0, -1.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(230, 225, 215), Enum.Material.Marble)
		b:Add(BALL, Vector3.new(1.4, 2.4, 1.4), CFrame.new(0, 0.1, 0) * CFrame.Angles(math.rad(-20), 0, 0), c, shine)
		b:Add(BALL, Vector3.one * 1.1, CFrame.new(0, 1.5, -0.3), c, shine)
		if id == "DolphinStatue" then
			b:Add("Wedge", Vector3.new(0.2, 0.8, 0.8), CFrame.new(0, 0.9, 0.5), c, shine)
		elseif id == "GoldenSplash" then
			for i = 0, 7 do
				local a = i / 8 * math.pi * 2
				b:Add(BALL, Vector3.one * 0.6, CFrame.new(math.cos(a) * 1.4, 0.2 + (i % 2) * 0.8, math.sin(a) * 1.4), Color3.fromRGB(255, 225, 90), NEON)
			end
		else
			b:Add(BLOCK, Vector3.new(1.4, 0.3, 0.8), CFrame.new(0, -0.9, 0.6), c, shine)
		end
	elseif shape == "Trident" then
		b:Add(CYL, Vector3.new(3.4, 0.25, 0.25), CFrame.Angles(0, 0, math.rad(90)), c, METAL)
		b:Add(BLOCK, Vector3.new(1.4, 0.25, 0.25), CFrame.new(0, 1.2, 0), c, METAL)
		for i = -1, 1 do
			b:Add("Wedge", Vector3.new(0.25, 0.9, 0.3), CFrame.new(i * 0.6, 1.8, 0), c, METAL)
		end
	elseif shape == "Map" then
		b:Add(BLOCK, Vector3.new(2.6, 2.0, 0.08), CFrame.identity, c, Enum.Material.Fabric)
		for _, side in { -1, 1 } do
			b:Add(CYL, Vector3.new(2.3, 0.35, 0.35), CFrame.new(side * 1.35, 0, 0) * CFrame.Angles(0, 0, 0), Color3.fromRGB(200, 170, 120), Enum.Material.Wood).CFrame = CFrame.new(side * 1.35, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
		end
		b:Add(BLOCK, Vector3.new(0.5, 0.1, 0.1), CFrame.new(0.4, -0.3, -0.05) * CFrame.Angles(0, 0, math.rad(45)), Color3.fromRGB(220, 40, 40))
		b:Add(BLOCK, Vector3.new(0.5, 0.1, 0.1), CFrame.new(0.4, -0.3, -0.05) * CFrame.Angles(0, 0, math.rad(-45)), Color3.fromRGB(220, 40, 40))
	elseif shape == "Anchor" then
		b:Add(BLOCK, Vector3.new(0.4, 2.6, 0.4), CFrame.identity, c, METAL)
		b:Add(BLOCK, Vector3.new(1.6, 0.3, 0.3), CFrame.new(0, 0.8, 0), c, METAL)
		b:Add(CYL, Vector3.new(0.3, 0.8, 0.8), CFrame.new(0, 1.5, 0) * CFrame.Angles(0, math.rad(90), 0), c, METAL)
		for _, side in { -1, 1 } do
			b:Add(BLOCK, Vector3.new(1.2, 0.35, 0.35), CFrame.new(side * 0.6, -1.1, 0) * CFrame.Angles(0, 0, math.rad(side * 30)), c, METAL)
			b:Add("Wedge", Vector3.new(0.35, 0.5, 0.4), CFrame.new(side * 1.2, -0.7, 0), c, METAL)
		end
	elseif shape == "Crown" then
		b:Add(CYL, Vector3.new(1.0, 2.6, 2.6), CFrame.Angles(0, 0, math.rad(90)), c, METAL)
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			b:Add("Wedge", Vector3.new(0.25, 0.9, 0.6), CFrame.new(math.cos(a) * 1.15, 0.9, math.sin(a) * 1.15) * CFrame.Angles(0, -a + math.rad(90), 0), c, METAL)
			b:Add(BALL, Vector3.one * 0.35, CFrame.new(math.cos(a) * 1.3, 0, math.sin(a) * 1.3), if i % 2 == 0 then Color3.fromRGB(255, 60, 90) else Color3.fromRGB(60, 200, 255), GLASS)
		end
	elseif shape == "Egg" then
		b:Add(BALL, Vector3.new(2.2, 3.0, 2.2), CFrame.identity, c)
		for i = 0, 5 do
			b:Add(BALL, Vector3.one * 0.5, CFrame.new(math.cos(i) * 1.0, -0.8 + i * 0.3, math.sin(i) * 1.0), Color3.fromRGB(255, 230, 120), NEON)
		end
	elseif shape == "Ufo" then
		b:Add(CYL, Vector3.new(0.6, 3.4, 3.4), CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(180, 190, 200), METAL)
		b:Add(BALL, Vector3.new(1.8, 1.3, 1.8), CFrame.new(0, 0.5, 0), c, GLASS)
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			b:Add(BALL, Vector3.one * 0.3, CFrame.new(math.cos(a) * 1.6, -0.1, math.sin(a) * 1.6), c, NEON)
		end
	end
	-- vzácné věci svítí
	if rarity.Order >= 5 then
		local light = Instance.new("PointLight")
		light.Color = rarity.Color
		light.Range = 10
		light.Brightness = 1.5
		light.Parent = b.Handle
	end
	return finalize(b.Model)
end

-- Rekvizita mapy z Assets.Map (když existuje). Nevaří díly dohromady.
function Models.MapAsset(name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Map")
	local template = folder and folder:FindFirstChild(name)
	if template and template:IsA("Model") and template.PrimaryPart then
		local clone = template:Clone()
		for _, descendant in clone:GetDescendants() do
			if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript") then
				descendant:Destroy()
			end
		end
		return clone
	end
	return nil
end

-- Efekty podle vzácnosti: jiskry (Rare+), záře (Epic+), světelný sloup (Legendary+)
function Models.AddRarityFx(model: Model, rarityName: string)
	local rarity = Catalog.Rarity(rarityName)
	local handle = model.PrimaryPart
	if not handle or rarity.Order < 3 then
		return
	end
	local color = if rarity.Name == "Secret" then Color3.fromRGB(200, 120, 255) else rarity.Color
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "RarityFx"
	sparkles.Rate = 4 + rarity.Order * 3
	sparkles.Lifetime = NumberRange.new(0.8, 1.6)
	sparkles.Speed = NumberRange.new(1, 3)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	sparkles.LightEmission = 1
	sparkles.Color = if rarity.Rainbow
		then ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 220, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)),
		})
		else ColorSequence.new(color)
	sparkles.Parent = handle
	if rarity.Order >= 4 then
		local light = handle:FindFirstChildOfClass("PointLight") or Instance.new("PointLight")
		light.Color = color
		light.Range = 8 + rarity.Order * 2
		light.Brightness = 2
		light.Parent = handle
	end
	if rarity.Order >= 5 then
		-- světelný sloup nad předmětem
		local beam = Instance.new("Part")
		beam.Name = "LightPillar"
		beam.Shape = Enum.PartType.Cylinder
		beam.Size = Vector3.new(14, 2.6, 2.6)
		beam.CFrame = handle.CFrame * CFrame.new(0, 7, 0) * CFrame.Angles(0, 0, math.rad(90))
		beam.Color = color
		beam.Material = NEON
		beam.Transparency = 0.75
		beam.Anchored = handle.Anchored
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.CastShadow = false
		beam.Parent = model
		if not handle.Anchored then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = beam
			weld.Parent = beam
		end
	end
end

-- Pomocník pro anchored rekvizity (předměty na podstavcích, ve vodě)
-- Dřevěná kánoe (špička míří na -Z), sedí na hladině (dno v y = 0). Kánoe na ostrovní úkoly.
function Models.Canoe(): Model
	local wood = Color3.fromRGB(176, 110, 58)
	local dark = Color3.fromRGB(120, 72, 38)
	local b = newBuilder("Canoe", Vector3.new(3.2, 0.6, 9), wood, BLOCK, Enum.Material.Wood)
	b.Handle.CFrame = CFrame.new(0, 0.3, 0)
	-- boky a lemy (červeno-bílý pruh)
	for _, side in { -1, 1 } do
		b:Add(BLOCK, Vector3.new(0.35, 1.4, 9), CFrame.new(side * 1.6, 0.9, 0), wood, Enum.Material.Wood)
		b:Add(BLOCK, Vector3.new(0.45, 0.22, 9.1), CFrame.new(side * 1.62, 1.62, 0), Color3.fromRGB(220, 60, 50))
		b:Add(BLOCK, Vector3.new(0.47, 0.1, 9.1), CFrame.new(side * 1.63, 1.4, 0), WHITE)
	end
	-- špičatá příď a záď (kosočtverec otočený o 45°)
	for _, z in { -4.6, 4.6 } do
		b:Add(BLOCK, Vector3.new(2.3, 1.75, 2.3), CFrame.new(0, 0.95, z) * CFrame.Angles(0, math.rad(45), 0), wood, Enum.Material.Wood)
		b:Add(BLOCK, Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 1.95, z + (if z < 0 then -0.9 else 0.9)), Color3.fromRGB(220, 60, 50))
	end
	-- vnitřek, sedátko a pádlo
	b:Add(BLOCK, Vector3.new(2.85, 0.2, 8.6), CFrame.new(0, 0.7, 0), dark, Enum.Material.Wood)
	b:Add(BLOCK, Vector3.new(2.9, 0.25, 0.9), CFrame.new(0, 1.15, 1.2), dark, Enum.Material.Wood)
	b:Add(CYL, Vector3.new(5.2, 0.22, 0.22), CFrame.new(1.2, 1.9, -0.6) * CFrame.Angles(0, math.rad(20), math.rad(35)), Color3.fromRGB(150, 100, 60))
	b:Add(BLOCK, Vector3.new(0.15, 1.3, 0.75), CFrame.new(2.85, 0.55, -1.2) * CFrame.Angles(0, math.rad(20), math.rad(35)), Color3.fromRGB(255, 200, 60))
	return finalize(b.Model)
end

function Models.Anchor(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
end

return Models

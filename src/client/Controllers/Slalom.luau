--!strict
-- Slalom na cestě zpět k voru (od levelu 10). Rozložení posílá server ve SwimStart (info.Slalom):
-- branky = bariéry z bójek s jednou mezerou, překážky = kameny, medúzy, klády a ježíci.
-- Tady se slalom postaví, hýbe se pohyblivými brankami a překážkami a hlídá nárazy:
--  • bariéra: hráč nemůže proplavat jinudy než mezerou (zastaví se a chvíli nemůže dopředu),
--  • překážka: krátké omráčení a odhození o kus zpět.
-- Souřadnice ze serveru: X = vzdálenost od místa startu směrem k voru, Z = posun do strany od StartZ.

local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Swim = require(Shared.Config.Swim)
local Net = require(Shared.Net)
local Kit = require(script.Parent.Parent.UI.Kit)
local Sound = require(script.Parent.Parent.Sound)
local Effects = require(script.Parent.Parent.Effects.Effects)

local Slalom = {}

type GateData = { X: number, Z: number, Gap: number, Amp: number, Speed: number, Phase: number, Side: number? }
type ObstacleData = { Kind: string, X: number, Z: number, Amp: number, Speed: number, Phase: number }
type PickupData = { Id: string, Kind: string, X: number, Z: number }
type Layout = {
	Name: string,
	Color: Color3,
	Gates: { GateData },
	Obstacles: { ObstacleData },
	Pickups: { PickupData }?,
	Style: string?, -- Gates, Buoys, Hoops, Canyon, Whirlpool
	Variant: string?,
	Hint: string?,
	Drift: number?,
	Night: boolean?,
}

type Gate = { Data: GateData, Model: Model, Passed: boolean, LastBump: number }
type Obstacle = { Data: ObstacleData, Model: Model, LastHit: number, Bob: number }
type Pickup = { Data: PickupData, Model: Model, Taken: boolean }

export type Run = {
	Layout: Layout,
	StartX: number,
	StartZ: number,
	Dir: number, -- 1 = plave se k −X (ke břehu), −1 = k +X (na moře)
	Y: number,
	Gates: { Gate },
	Obstacles: { Obstacle },
	Pickups: { Pickup },
	Combo: number, -- branky za sebou bez nárazu
	BoostUntil: number, -- zrychlení z obruče (Hoop Dash)
	HitsAtGate: number,
	StunUntil: number,
	Passed: number,
	Folder: Folder,
	Hits: number, -- nárazy (hvězdičky: 0 = ★★★)
	Shield: number, -- štít z diamantu: tolik nárazů se nepočítá
	Mood: ColorCorrectionEffect?, -- tma / bouřka (jen u tohoto hráče)
}

local PLAYER_HALF_WIDTH = 0.9
local WHITE = Color3.new(1, 1, 1)

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
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
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function newModel(name: string, parent: Instance): (Model, Part)
	local m = Instance.new("Model")
	m.Name = name
	local root = part(m, Vector3.one, CFrame.identity, WHITE)
	root.Name = "Root"
	root.Transparency = 1
	m.PrimaryPart = root
	m.Parent = parent
	return m, root
end

local UP = CFrame.Angles(0, 0, math.rad(90)) -- válec postavený svisle
local ALONG_Z = CFrame.Angles(0, math.rad(90), 0) -- válec ležící podél osy Z

-- ===== Modely (staví se kolem počátku, pak se jen posouvají) =====

-- Branka: v mezeře dva pruhované sloupky s obloukem a praporky, do stran řada bójek na laně
-- Branka: dobře viditelná červeno-bílá bariéra (plováky jako na závodní dráze v bazénu) přes celou šířku,
-- v ní jedna mezera se dvěma vysokými červeno-bílými sloupy, svítícím obloukem a nápisem GATE n/N.
-- Mezera svítí zeleně (sem plav), po proplavání zezlátne.
local RED = Color3.fromRGB(235, 40, 45)
local GO_GREEN = Color3.fromRGB(70, 230, 110)

local function gateModel(parent: Instance, gap: number, color: Color3, index: number, total: number): Model
	local m = newModel("SlalomGate", parent)
	local half = gap / 2
	for _, side in { -1, 1 } do
		-- vysoký sloup (střídavě červená a bílá) se svítící koulí nahoře
		for k = 0, 5 do
			part(m, Vector3.new(1.6, 1.1, 1.1), CFrame.new(0, 0.6 + k * 1.6, side * half) * UP, if k % 2 == 0 then RED else WHITE, nil, Enum.PartType.Cylinder)
		end
		part(m, Vector3.one * 2, CFrame.new(0, 10.2, side * half), RED, Enum.Material.Neon, Enum.PartType.Ball)
		part(m, Vector3.one * 3, CFrame.new(0, 0.1, side * half), RED, nil, Enum.PartType.Ball)
		-- bariéra: plováky ležící podél lana, střídavě červený a bílý, až daleko do stran
		local z = half + 1.5
		local n = 0
		while z < half + 50 do
			part(m, Vector3.new(2.8, 1.7, 1.7), CFrame.new(0, 0.45, side * (z + 1.4)) * ALONG_Z, if n % 2 == 0 then RED else WHITE, nil, Enum.PartType.Cylinder)
			z += 3
			n += 1
		end
		-- výstražné tyčky s červenými praporky na bariéře (vidět i z dálky)
		for _, dz in { 8, 20, 34 } do
			part(m, Vector3.new(0.25, 4, 0.25), CFrame.new(0, 2.3, side * (half + dz)), WHITE)
			local flag = Instance.new("WedgePart")
			flag.Anchored = true
			flag.CanCollide = false
			flag.CanQuery = false
			flag.CanTouch = false
			flag.CastShadow = false
			flag.Size = Vector3.new(0.12, 1.4, 1.6)
			flag.CFrame = CFrame.new(0, 3.6, side * (half + dz + 0.9)) * CFrame.Angles(0, 0, 0)
			flag.Color = RED
			flag.Parent = m
		end
	end
	-- svítící oblouk nad mezerou v barvě slalomu a cedulka s číslem branky
	-- (bez cedulky s číslem – svítící oblouk a zelená mezera stačí, obrazovka zůstane přehledná)
	part(m, Vector3.new(0.6, 0.6, gap + 1), CFrame.new(0, 10.2, 0), color, Enum.Material.Neon)
	-- zelená záře v mezeře: sem plav
	local glow = part(m, Vector3.new(0.3, 8.4, gap - 1.6), CFrame.new(0, 4.6, 0), GO_GREEN, Enum.Material.Neon)
	glow.Transparency = 0.7
	glow.Name = "Glow"
	local floor = part(m, Vector3.new(4, 0.2, gap - 1.6), CFrame.new(0, 0.15, 0), GO_GREEN, Enum.Material.Neon)
	floor.Transparency = 0.45
	floor.Name = "GlowFloor"
	return m
end

local function rockModel(parent: Instance): Model
	local m = newModel("SlalomRock", parent)
	local grey = Color3.fromRGB(120, 120, 128)
	part(m, Vector3.new(5.4, 3.6, 5), CFrame.new(0, 0.4, 0), grey, Enum.Material.Slate, Enum.PartType.Ball)
	part(m, Vector3.new(3, 2.6, 3.2), CFrame.new(1.6, 1.4, -1.2), grey:Lerp(WHITE, 0.15), Enum.Material.Slate, Enum.PartType.Ball)
	part(m, Vector3.new(2.6, 2, 2.4), CFrame.new(-1.8, 0.9, 1.4), grey:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Slate, Enum.PartType.Ball)
	part(m, Vector3.new(1.2, 0.4, 1.2), CFrame.new(0.4, 2.3, 0.3), Color3.fromRGB(90, 170, 80), Enum.Material.Grass, Enum.PartType.Ball) -- mech
	return m
end

local function jellyfishModel(parent: Instance): Model
	local m = newModel("SlalomJellyfish", parent)
	local pink = Color3.fromRGB(255, 120, 210)
	local dome = part(m, Vector3.new(4.4, 3.2, 4.4), CFrame.new(0, 0.9, 0), pink, Enum.Material.Glass, Enum.PartType.Ball)
	dome.Transparency = 0.25
	part(m, Vector3.new(2.4, 1.6, 2.4), CFrame.new(0, 1.1, 0), Color3.fromRGB(255, 200, 240), Enum.Material.Neon, Enum.PartType.Ball)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local tentacle = part(m, Vector3.new(0.3, 2.6, 0.3), CFrame.new(math.cos(a) * 1.3, -0.6, math.sin(a) * 1.3) * CFrame.Angles(math.sin(a) * 0.25, 0, math.cos(a) * 0.25), pink, Enum.Material.Neon)
		tentacle.Transparency = 0.2
	end
	-- oči (veselá medúza)
	for _, side in { -1, 1 } do
		part(m, Vector3.one * 0.45, CFrame.new(-2.05, 1.4, side * 0.6), Color3.fromRGB(30, 20, 40), nil, Enum.PartType.Ball)
	end
	local light = Instance.new("PointLight")
	light.Color = pink
	light.Range = 10
	light.Brightness = 1.2
	light.Parent = dome
	return m
end

local function logModel(parent: Instance): Model
	local m = newModel("SlalomLog", parent)
	local length = Swim.Slalom.LogLength
	local wood = Color3.fromRGB(140, 95, 55)
	part(m, Vector3.new(length, 2.4, 2.4), CFrame.new(0, 0.3, 0) * ALONG_Z, wood, Enum.Material.Wood, Enum.PartType.Cylinder)
	for _, side in { -1, 1 } do
		part(m, Vector3.new(0.2, 2, 2), CFrame.new(0, 0.3, side * length / 2) * ALONG_Z, Color3.fromRGB(215, 175, 120), Enum.Material.Wood, Enum.PartType.Cylinder)
	end
	-- pahýl větve a lísteček
	part(m, Vector3.new(1.6, 0.6, 0.6), CFrame.new(0, 1.6, 2) * UP, wood, Enum.Material.Wood, Enum.PartType.Cylinder)
	part(m, Vector3.new(0.9, 0.2, 0.6), CFrame.new(0, 2.5, 2.3), Color3.fromRGB(90, 190, 80), Enum.Material.Grass)
	return m
end

local function pufferModel(parent: Instance): Model
	local m = newModel("SlalomPuffer", parent)
	local yellow = Color3.fromRGB(255, 205, 60)
	part(m, Vector3.one * 3.6, CFrame.new(0, 0.8, 0), yellow, nil, Enum.PartType.Ball)
	-- bodliny kolem dokola
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		local tilt = if k % 2 == 0 then 0.35 else -0.25
		local dir = Vector3.new(math.cos(a) * math.cos(tilt), math.sin(tilt), math.sin(a) * math.cos(tilt))
		local center = Vector3.new(0, 0.8, 0) + dir * 2
		part(m, Vector3.new(0.25, 0.25, 0.9), CFrame.lookAt(center, center + dir), Color3.fromRGB(230, 150, 40))
	end
	-- oči a pusa (tvář směrem k hráči, tj. +X)
	for _, side in { -1, 1 } do
		part(m, Vector3.one * 0.8, CFrame.new(1.55, 1.4, side * 0.7), WHITE, nil, Enum.PartType.Ball)
		part(m, Vector3.one * 0.4, CFrame.new(1.85, 1.4, side * 0.7), Color3.fromRGB(20, 20, 30), nil, Enum.PartType.Ball)
	end
	part(m, Vector3.new(0.3, 0.5, 0.5), CFrame.new(1.75, 0.6, 0) * UP, Color3.fromRGB(220, 90, 90), nil, Enum.PartType.Cylinder)
	return m
end

-- ===== Další druhy slalomu =====

-- Bójka (Buoy Weave): vysoká pruhovaná bójka se šipkou, ze které strany ji objet.
-- side = na kterou stranu (±Z) ji hráč objíždí, dir = směr plavání (šipka je „vlevo/vpravo na obrazovce“)
local function buoyModel(parent: Instance, side: number, dir: number, index: number, total: number): Model
	local m = newModel("SlalomBuoy", parent)
	local color = if side > 0 then Color3.fromRGB(255, 190, 30) else Color3.fromRGB(255, 110, 40)
	part(m, Vector3.new(2.2, 3.2, 3.2), CFrame.new(0, 0.4, 0) * UP, color, nil, Enum.PartType.Cylinder)
	for k = 0, 3 do
		part(m, Vector3.new(1.4, 1.8 - k * 0.25, 1.8 - k * 0.25), CFrame.new(0, 2 + k * 1.4, 0) * UP, if k % 2 == 0 then WHITE else color, nil, Enum.PartType.Cylinder)
	end
	local top = part(m, Vector3.one * 1.6, CFrame.new(0, 7.6, 0), color, Enum.Material.Neon, Enum.PartType.Ball)
	-- zelený pruh na vodě: tudy kolem bójky
	local lane = part(m, Vector3.new(4, 0.2, 7), CFrame.new(0, 0.12, side * 4.6), GO_GREEN, Enum.Material.Neon)
	lane.Transparency = 0.45
	lane.Name = "GlowFloor"
	-- šipka: doprava na obrazovce = −Z při plavání ke břehu (dir = 1)
	local screenRight = side * -dir > 0
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(60, 44)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.MaxDistance = 90
	gui.Parent = top
	local label = Kit.Text(gui, { Text = if screenRight then "➡" else "⬅", Size = UDim2.fromScale(1, 1), TextColor3 = WHITE, StrokeThickness = 3 })
	label.BackgroundTransparency = 0.1
	label.BackgroundColor3 = color
	Kit.Corner(label, 14)
	return m
end

-- Obruč (Hoop Dash): svítící kruh napůl ve vodě, proplavat středem = zrychlení
local function hoopModel(parent: Instance, size: number, color: Color3): Model
	local m = newModel("SlalomHoop", parent)
	local r = size / 2
	local n = 18
	for k = 0, n - 1 do
		local a = k / n * math.pi * 2
		local a2 = (k + 1) / n * math.pi * 2
		local p1 = Vector3.new(0, math.sin(a) * r + 1.5, math.cos(a) * r)
		local p2 = Vector3.new(0, math.sin(a2) * r + 1.5, math.cos(a2) * r)
		if p1.Y > -0.5 or p2.Y > -0.5 then
			local seg = part(m, Vector3.new(0.9, 0.9, (p2 - p1).Magnitude + 0.3), CFrame.lookAt((p1 + p2) / 2, p2), if k % 2 == 0 then color else WHITE, Enum.Material.Neon)
			seg.Name = "Ring"
		end
	end
	local glow = part(m, Vector3.new(0.2, size - 1.5, size - 1.5), CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(0, math.rad(90), 0), color, Enum.Material.Neon, Enum.PartType.Cylinder)
	glow.Transparency = 0.85
	glow.Name = "Glow"
	return m
end

-- Kaňon (Rock Canyon): místo bójek řada skal od kraje mezery až daleko do strany
local function canyonModel(parent: Instance, gap: number): Model
	local m = newModel("SlalomCanyon", parent)
	local half = gap / 2
	local grey = Color3.fromRGB(105, 102, 98)
	for _, side in { -1, 1 } do
		local z = half + 2.2
		local k = 0
		while z < half + 44 do
			local h = if k == 0 then 9 else 4 + (k * 37 % 5)
			local w = 4.4 + (k * 13 % 3)
			part(m, Vector3.new(w, h, w), CFrame.new(0, h / 2 - 1, side * z) * CFrame.Angles(0, k * 0.7, 0), grey:Lerp(WHITE, (k % 3) * 0.06), Enum.Material.Slate)
			z += w - 0.6
			k += 1
		end
		-- svítící tyčka na kraji kanálu
		local pole = part(m, Vector3.new(0.5, 8, 0.5), CFrame.new(0, 4, side * (half + 0.6)), GO_GREEN, Enum.Material.Neon)
		pole.Name = "Glow"
	end
	local floor = part(m, Vector3.new(4, 0.2, gap - 1.6), CFrame.new(0, 0.15, 0), GO_GREEN, Enum.Material.Neon)
	floor.Transparency = 0.6
	floor.Name = "GlowFloor"
	return m
end

-- Vír (Whirlpool Bay): točící se tmavé kruhy na hladině s pěnou
local function whirlpoolModel(parent: Instance): Model
	local m = newModel("SlalomWhirlpool", parent)
	for k = 0, 3 do
		local d = 16 - k * 3.6
		local ring = part(m, Vector3.new(0.2, d, d), CFrame.new(0, 0.1 + k * 0.03, 0) * UP, if k % 2 == 0 then Color3.fromRGB(20, 70, 140) else Color3.fromRGB(230, 245, 255), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		ring.Transparency = 0.25 + k * 0.1
	end
	-- spirálová ramena (točí se s modelem)
	for k = 0, 3 do
		local a = k * math.pi / 2
		part(m, Vector3.new(0.6, 0.25, 6), CFrame.new(math.cos(a) * 4, 0.3, math.sin(a) * 4) * CFrame.Angles(0, -a + 0.6, 0), WHITE, Enum.Material.Neon).Transparency = 0.3
	end
	part(m, Vector3.new(0.3, 3, 3), CFrame.new(0, 0.25, 0) * UP, Color3.fromRGB(5, 20, 50), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	return m
end

-- Sbírací věc: zářící koule se znakem nad vodou (mince / blesk / vločka), točí se a pohupuje
local PICKUP_LOOK: { [string]: { Color: Color3, Icon: string } } = {
	Coin = { Color = Color3.fromRGB(255, 205, 40), Icon = "💰" },
	Turbo = { Color = Color3.fromRGB(255, 120, 30), Icon = "⚡" },
	Freeze = { Color = Color3.fromRGB(120, 220, 255), Icon = "❄️" },
}
local function pickupModel(parent: Instance, kind: string): Model
	local look = PICKUP_LOOK[kind] or PICKUP_LOOK.Coin
	local m, root = newModel("SlalomPickup", parent)
	local orb = part(m, Vector3.one * 2.6, CFrame.new(0, 2.2, 0), look.Color, Enum.Material.Neon, Enum.PartType.Ball)
	orb.Transparency = 0.25
	orb.Name = "Orb"
	local ring = part(m, Vector3.new(0.3, 4.2, 4.2), CFrame.new(0, 0.15, 0) * UP, look.Color, Enum.Material.Neon, Enum.PartType.Cylinder)
	ring.Transparency = 0.5
	local light = Instance.new("PointLight")
	light.Range = 14
	light.Brightness = 2.5
	light.Color = look.Color
	light.Parent = orb
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Rate = 14
	sparkle.Lifetime = NumberRange.new(0.4, 0.8)
	sparkle.Speed = NumberRange.new(2, 4)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Color = ColorSequence.new(WHITE, look.Color)
	sparkle.Parent = orb
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(54, 54)
	gui.StudsOffset = Vector3.new(0, 4.2, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.Parent = root
	Kit.Text(gui, { Text = look.Icon, Size = UDim2.fromScale(1, 1), NoStroke = true })
	return m
end

local BUILDERS: { [string]: (Instance) -> Model } = {
	Rock = rockModel,
	Jellyfish = jellyfishModel,
	Log = logModel,
	Puffer = pufferModel,
	Whirlpool = whirlpoolModel,
}

-- ===== Pozice =====

local function gateZ(g: GateData, t: number): number
	return g.Z + g.Amp * math.sin(g.Speed * t + g.Phase)
end

local function obstacleZ(o: ObstacleData, t: number): number
	return o.Z + o.Amp * math.sin(o.Speed * t + o.Phase)
end

-- poloviční rozměr zásahu překážky podél dráhy (X) a do strany (Z)
local function obstacleExtent(kind: string): (number, number)
	local r = Swim.Slalom.ObstacleRadius[kind] or 2.5
	if kind == "Log" then
		return r, Swim.Slalom.LogLength / 2
	end
	return r, r
end

function Slalom.Start(layout: Layout, startX: number, startZ: number, y: number, parent: Instance, dir: number?, shield: number?): Run
	local folder = Instance.new("Folder")
	folder.Name = "Slalom"
	folder.Parent = parent
	local run: Run = {
		Layout = layout,
		StartX = startX,
		StartZ = startZ,
		Dir = dir or 1,
		Y = y,
		Gates = {},
		Obstacles = {},
		Pickups = {},
		Combo = 0,
		BoostUntil = 0,
		HitsAtGate = 0,
		StunUntil = 0,
		Passed = 0,
		Folder = folder,
		Hits = 0,
		Shield = shield or 0,
		Mood = nil,
	}
	-- noční slalom = tma, bouřka = šero (barevná korekce jen u tohoto hráče)
	-- (pojistka: starý filtr z minulého slalomu pryč)
	for _, old in Lighting:GetChildren() do
		if old.Name == "SlalomMood" then
			old:Destroy()
		end
	end
	if layout.Night or layout.Drift then
		local mood = Instance.new("ColorCorrectionEffect")
		mood.Name = "SlalomMood"
		mood.Brightness = if layout.Night then -0.32 else -0.12
		mood.Contrast = if layout.Night then 0.15 else 0.05
		mood.Saturation = if layout.Night then -0.35 else -0.25
		mood.TintColor = if layout.Night then Color3.fromRGB(150, 170, 255) else Color3.fromRGB(200, 210, 230)
		mood.Parent = Lighting
		run.Mood = mood
	end
	for _, g in layout.Gates do
		local style = layout.Style or "Gates"
		local index = #run.Gates + 1
		local model = if style == "Buoys" then buoyModel(folder, g.Side or 1, run.Dir, index, #layout.Gates)
			elseif style == "Hoops" then hoopModel(folder, g.Gap, layout.Color)
			elseif style == "Canyon" then canyonModel(folder, g.Gap)
			else gateModel(folder, g.Gap, layout.Color, index, #layout.Gates)
		table.insert(run.Gates, { Data = g, Model = model, Passed = false, LastBump = 0 })
	end
	for _, o in layout.Obstacles do
		local build = BUILDERS[o.Kind]
		if build then
			local model = build(folder)
			if layout.Night then
				-- v noci překážky trochu svítí, ať jdou vidět
				local light = Instance.new("PointLight")
				light.Range = 12
				light.Brightness = 1.5
				light.Color = Color3.fromRGB(255, 190, 150)
				light.Parent = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
			end
			table.insert(run.Obstacles, { Data = o, Model = model, LastHit = 0, Bob = math.random() * 6 })
		end
	end
	local pickups: { PickupData } = layout.Pickups or {}
	for _, p in pickups do
		table.insert(run.Pickups, { Data = p, Model = pickupModel(folder, p.Kind), Taken = false })
	end
	Slalom.Animate(run, 0)
	return run
end

function Slalom.Destroy(run: Run)
	run.Folder:Destroy()
	if run.Mood then
		run.Mood:Destroy()
		run.Mood = nil
	end
end

-- Náraz: se štítem se nic nestane, jinak se započítá (hvězdičky) a server se to dozví.
-- Vrací true, když náraz zachytil štít.
local function registerHit(run: Run, progress: number, z: number): boolean
	if run.Shield > 0 then
		run.Shield -= 1
		local pos = Vector3.new(run.StartX - run.Dir * progress, run.Y + 2, run.StartZ + z)
		Effects.Splash(pos, false)
		Sound.Play("Ring", 0.7)
		Effects.FloatText(if run.Shield > 0 then `SHIELD! ({run.Shield} left)` else "SHIELD SAVED YOU!", Color3.fromRGB(190, 120, 255))
		return true
	end
	run.Hits += 1
	Net.Event("SlalomHit"):FireServer()
	return false
end

function Slalom.Stunned(run: Run): boolean
	return os.clock() < run.StunUntil
end

-- Posune branky a překážky (t = čas od začátku plavání)
function Slalom.Animate(run: Run, t: number)
	for _, gate in run.Gates do
		local g = gate.Data
		gate.Model:PivotTo(CFrame.new(run.StartX - run.Dir * g.X, run.Y, run.StartZ + gateZ(g, t)))
	end
	for _, obstacle in run.Obstacles do
		local o = obstacle.Data
		local bob = math.sin(t * 2 + obstacle.Bob)
		-- (otočené čelem k hráči: model počítá s tím, že hráč připlouvá z +X)
		local cf = CFrame.new(run.StartX - run.Dir * o.X, run.Y + bob * 0.25, run.StartZ + obstacleZ(o, t)) * (if run.Dir < 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity)
		if o.Kind == "Jellyfish" then
			cf *= CFrame.new(0, bob * 0.4, 0) * CFrame.Angles(0, 0, bob * 0.08)
		elseif o.Kind == "Log" then
			cf *= CFrame.Angles(bob * 0.06, 0, 0)
		elseif o.Kind == "Puffer" then
			cf *= CFrame.Angles(0, t * 0.8, 0)
		elseif o.Kind == "Whirlpool" then
			cf = CFrame.new(run.StartX - run.Dir * o.X, run.Y, run.StartZ + obstacleZ(o, t)) * CFrame.Angles(0, -t * 2.5, 0)
		end
		obstacle.Model:PivotTo(cf)
	end
	for i, pickup in run.Pickups do
		if not pickup.Taken then
			local p = pickup.Data
			pickup.Model:PivotTo(CFrame.new(run.StartX - run.Dir * p.X, run.Y + math.sin(t * 3 + i) * 0.4, run.StartZ + p.Z) * CFrame.Angles(0, t * 2, 0))
		end
	end
end

-- Sebere věci, kolem kterých hráč proplaval. Vrací druhy sebraných věcí (server je ověří a použije).
function Slalom.Collect(run: Run, progress: number, z: number): { string }
	local got = {}
	local r = Swim.Slalom.Pickups.Radius
	for _, pickup in run.Pickups do
		local p = pickup.Data
		if not pickup.Taken and math.abs(progress - p.X) < r and math.abs(z - p.Z) < r then
			pickup.Taken = true
			pickup.Model:Destroy()
			Net.Event("SlalomPickup"):FireServer(p.Id)
			local look = PICKUP_LOOK[p.Kind] or PICKUP_LOOK.Coin
			Effects.Ripple(Vector3.new(run.StartX - run.Dir * progress, run.Y, run.StartZ + z), 1.2)
			Effects.FovKick(6)
			Sound.Play(if p.Kind == "Coin" then "Coin" else "Perfect", if p.Kind == "Freeze" then 1.4 else 1.1)
			if p.Kind == "Turbo" then
				Effects.FloatText("⚡ TURBO!", look.Color)
			elseif p.Kind == "Freeze" then
				Effects.FloatText("❄️ FREEZE!", look.Color)
			end
			table.insert(got, p.Kind)
		end
	end
	return got
end

local function bumpEffect(run: Run, progress: number, z: number, text: string, color: Color3)
	local pos = Vector3.new(run.StartX - run.Dir * progress, run.Y, run.StartZ + z)
	Effects.Splash(pos, false)
	Effects.Shake(0.25)
	Sound.Play("Boing", 0.8)
	Effects.FloatText(text, color)
end

-- Upraví postup hráče podle branek a překážek. prev/new = postup v minulém a tomto snímku,
-- z = posun hráče do strany od StartZ, t = čas od začátku plavání. Vrací opravený postup.
function Slalom.Resolve(run: Run, t: number, prev: number, new: number, z: number): number
	local now = os.clock()
	local result = new
	local style = run.Layout.Style or "Gates"
	-- proplavaná branka / bójka / obruč: zvuk, combo, rozsvícení
	local function passed(gate: Gate)
		gate.Passed = true
		run.Passed += 1
		Sound.Play("Ring", 1.2 + run.Passed * 0.08)
		-- combo: branky za sebou bez jediného nárazu
		run.Combo = if run.Hits == run.HitsAtGate then run.Combo + 1 else 1
		run.HitsAtGate = run.Hits
		-- v kaňonu jsou branky hustě za sebou: combo hlásit jen po trojicích, ať text nezahltí obrazovku
		-- přehlednost: žádné nápisy u každé branky, combo jen po trojicích a na konci
		if run.Combo >= 3 and (run.Combo % 3 == 0 or run.Passed == #run.Gates) then
			Effects.FloatText(`COMBO x{run.Combo}!`, Kit.Colors.Yellow)
		end
		for _, name in { "Glow", "GlowFloor" } do
			local glow = gate.Model:FindFirstChild(name) :: BasePart?
			if glow then
				glow.Color = Kit.Colors.Yellow
				glow.Transparency = 0.8
			end
		end
	end
	local function blocked(gate: Gate, g: GateData, text: string)
		result = math.min(result, g.X - 1.2)
		if now - gate.LastBump > 0.7 then
			gate.LastBump = now
			if not registerHit(run, result, z) then
				run.StunUntil = math.max(run.StunUntil, now + Swim.Slalom.BumpStun)
				bumpEffect(run, result, z, text, Kit.Colors.Orange)
			end
		end
	end
	for _, gate in run.Gates do
		local g = gate.Data
		if not gate.Passed and prev < g.X and result >= g.X - 0.5 then
			local center = gateZ(g, t)
			if style == "Buoys" then
				-- objet z vyznačené strany; skrz bójku to nejde, z druhé strany = chyba (bez zastavení)
				local side = g.Side or 1
				if math.abs(z - center) < Swim.Slalom.BuoyRadius + PLAYER_HALF_WIDTH then
					blocked(gate, g, "BUMP! Go around the buoy!")
				elseif (z - center) * side >= Swim.Slalom.BuoyPass then
					passed(gate)
				else
					gate.Passed = true
					run.Combo = 0
					if not registerHit(run, result, z) then
						run.StunUntil = math.max(run.StunUntil, now + 0.25)
						bumpEffect(run, result, z, "MISSED! Follow the arrow!", Kit.Colors.Orange)
					end
				end
			elseif style == "Hoops" then
				-- obruč: středem = zrychlení, vedle = jen konec comba (žádná bariéra)
				gate.Passed = true
				if math.abs(z - center) <= g.Gap / 2 - PLAYER_HALF_WIDTH then
					passed(gate)
					run.BoostUntil = now + Swim.Slalom.HoopBoostTime
					Effects.FovKick(10)
				else
					run.Combo = 0
				end
			elseif math.abs(z - center) <= g.Gap / 2 - PLAYER_HALF_WIDTH then
				passed(gate)
			else
				blocked(gate, g, if style == "Canyon" then "BONK! Stay in the channel!" else "BUMP! Swim through the gap!")
			end
		end
	end
	-- překážky: náraz = omráčení a odhození zpět
	for _, obstacle in run.Obstacles do
		local o = obstacle.Data
		local ex, ez = obstacleExtent(o.Kind)
		if now - obstacle.LastHit > 1 and math.abs(result - o.X) < ex + PLAYER_HALF_WIDTH and math.abs(z - obstacleZ(o, t)) < ez + PLAYER_HALF_WIDTH then
			obstacle.LastHit = now
			if registerHit(run, result, z) then
				continue
			end
			run.StunUntil = math.max(run.StunUntil, now + Swim.Slalom.HitStun)
			result = math.max(0, result - Swim.Slalom.KnockBack)
			local text = if o.Kind == "Jellyfish" then "ZAP! Jellyfish!" elseif o.Kind == "Puffer" then "OUCH! Pufferfish!" elseif o.Kind == "Log" then "BONK! Log!" elseif o.Kind == "Whirlpool" then "WHOOSH! Whirlpool!" else "BONK! Rock!"
			bumpEffect(run, result, z, text, Kit.Colors.Coral)
		end
	end
	return result
end

-- Víry stahují hráče do strany k sobě (vrací posun v Z za tento snímek)
function Slalom.Pull(run: Run, t: number, progress: number, z: number, dt: number): number
	local dz = 0
	local range = Swim.Slalom.WhirlpoolRange
	for _, obstacle in run.Obstacles do
		local o = obstacle.Data
		if o.Kind == "Whirlpool" then
			local dx = math.abs(progress - o.X)
			local oz = obstacleZ(o, t)
			local d = math.sqrt(dx * dx + (z - oz) ^ 2)
			if d < range and d > 0.5 then
				local strength = Swim.Slalom.WhirlpoolPull * (1 - d / range)
				dz += math.sign(oz - z) * strength * dt
			end
		end
	end
	return dz
end

-- Zrychlení z obruče (Hoop Dash)
function Slalom.Boost(run: Run): number
	return if os.clock() < run.BoostUntil then Swim.Slalom.HoopBoostMultiplier else 1
end

return Slalom

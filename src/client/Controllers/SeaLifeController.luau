--!strict
-- Mořský život (jen na klientovi, nic se nereplikuje):
--  • kreslení delfíni, kteří u mola vyskakují z vody v obloucích (a doprovází hráče i na otevřeném moři)
--  • hejna barevných rybek těsně pod hladinou, občas některá vyskočí
--  • rackové kroužící nad pláží
--  • třpytky na hladině kolem kamery
-- Všechno je z dílů (elipsoidy = Block + SpecialMesh Sphere), ukotvené a bez kolizí.
-- Když je kamera daleko (let až 100 000 studů), skupiny se odpojí ze Workspace a nepočítají se.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local World = require(Shared.Config.World)
local Effects = require(script.Parent.Parent.Effects.Effects)

local SeaLifeController = {}

local LOW_END = Effects.LowEnd
local CENTER = Vector3.new(World.PierEndX - 40, World.WaterY, 0) -- střed „živé“ oblasti u mola
local NEAR_DISTANCE = 1100 -- dál od středu se rybky a rackové schovají
local COMPANION_MIN_X = World.PierEndX + 400 -- odtud dál delfíni doprovází kameru
local COMPANION_MAX_HEIGHT = 160 -- jen když kamera letí nízko nad vodou
local SPARKLE_MAX_HEIGHT = 260
local HIDDEN = CFrame.new(0, -500, 0)
local WATER_MIN_X = World.BeachFrontX + 70 -- blíž ke břehu je mělčina

local rng = Random.new()

type Piece = { Part: BasePart, Offset: CFrame }

type Dolphin = {
	Pieces: { Piece },
	Leaping: boolean,
	NextLeap: number,
	Start: number,
	Duration: number,
	From: Vector3,
	To: Vector3,
	Height: number,
	Roll: number,
	SplashedIn: boolean,
	SplashedOut: boolean,
	Hidden: boolean,
}

type Fish = { Pieces: { Piece }, Angle: number, Radius: number, Depth: number, Speed: number, Hop: number }
type School = { Fish: { Fish }, Center: Vector3, Drift: number, Direction: number }

type Gull = {
	Body: { Piece },
	Wings: { { Part: BasePart, Side: number, Outer: boolean } },
	Center: Vector3,
	Radius: number,
	Height: number,
	Speed: number,
	Angle: number,
	Phase: number,
}

type Sparkle = { Part: Part, Born: number, Life: number, Size: number }

local root: Folder
local nearFolder: Folder
local dolphinFolder: Folder
local sparkleFolder: Folder

local dolphins: { Dolphin } = {}
local schools: { School } = {}
local gulls: { Gull } = {}
local sparkles: { Sparkle } = {}

-- dávkové posouvání dílů (jedno volání BulkMoveTo za snímek)
local moveParts: { BasePart } = {}
local moveFrames: { CFrame } = {}

local function queue(part: BasePart, cf: CFrame)
	table.insert(moveParts, part)
	table.insert(moveFrames, cf)
end

local function queueRig(pieces: { Piece }, cf: CFrame)
	for _, piece in pieces do
		queue(piece.Part, cf * piece.Offset)
	end
end

-- ===== Stavba dílů =====

local function newPart(parent: Instance, size: Vector3, color: Color3, shape: Enum.PartType?, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = HIDDEN
	p.Parent = parent
	return p
end

-- elipsoid: kvádr s kulovým meshem (mesh se roztáhne podle velikosti dílu)
local function ellipsoid(parent: Instance, size: Vector3, color: Color3): Part
	local p = newPart(parent, size, color)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function piece(pieces: { Piece }, part: BasePart, offset: CFrame)
	table.insert(pieces, { Part = part, Offset = offset })
end

-- ===== Delfíni =====

-- model pluje ve směru -Z (jako CFrame.lookAt)
local function buildDolphin(parent: Instance, tint: Color3): { Piece }
	local pieces: { Piece } = {}
	local belly = Color3.fromRGB(225, 238, 248)
	piece(pieces, ellipsoid(parent, Vector3.new(3.2, 3, 10.5), tint), CFrame.identity)
	piece(pieces, ellipsoid(parent, Vector3.new(2.6, 1.8, 8.4), belly), CFrame.new(0, -0.8, -0.6))
	piece(pieces, ellipsoid(parent, Vector3.new(2.8, 2.6, 4), tint), CFrame.new(0, 0.35, -4.1))
	piece(pieces, ellipsoid(parent, Vector3.new(1.2, 1, 3), tint), CFrame.new(0, -0.45, -6.3))
	piece(pieces, ellipsoid(parent, Vector3.new(1.5, 1.4, 4.2), tint), CFrame.new(0, 0.15, 5.6))
	-- hřbetní ploutev (šikmá strana dopředu)
	local fin = Instance.new("WedgePart")
	fin.Anchored = true
	fin.CanCollide = false
	fin.CanQuery = false
	fin.CanTouch = false
	fin.CastShadow = false
	fin.Size = Vector3.new(0.4, 2.2, 2.6)
	fin.Color = tint
	fin.Material = Enum.Material.SmoothPlastic
	fin.CFrame = HIDDEN
	fin.Parent = parent
	piece(pieces, fin, CFrame.new(0, 2.2, 0.9))
	-- ocasní ploutve
	for _, side in { -1, 1 } do
		piece(pieces, ellipsoid(parent, Vector3.new(3, 0.35, 1.5), tint), CFrame.new(side * 1.3, 0.25, 7.6) * CFrame.Angles(0, side * math.rad(28), 0))
		piece(pieces, ellipsoid(parent, Vector3.new(2.2, 0.3, 1.1), tint), CFrame.new(side * 1.8, -0.9, -1.8) * CFrame.Angles(0, side * math.rad(-25), side * math.rad(-25)))
		piece(pieces, newPart(parent, Vector3.one * 0.45, Color3.fromRGB(20, 25, 35), Enum.PartType.Ball), CFrame.new(side * 1.2, 0.55, -5))
	end
	return pieces
end

local function hideDolphin(d: Dolphin)
	if not d.Hidden then
		d.Hidden = true
		queueRig(d.Pieces, HIDDEN)
	end
end

-- naplánuje skok: buď u mola, nebo kousek před kamerou na otevřeném moři
local function planLeap(d: Dolphin, now: number, companion: Vector3?)
	local from: Vector3
	local dir: Vector3
	if companion then
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		from = Vector3.new(companion.X + rng:NextNumber(90, 240), World.WaterY - 4, companion.Z + side * rng:NextNumber(25, 90))
		local a = rng:NextNumber(-0.5, 0.5)
		dir = Vector3.new(math.cos(a), 0, math.sin(a))
	else
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		from = Vector3.new(rng:NextNumber(WATER_MIN_X, World.PierEndX + 260), World.WaterY - 4, side * rng:NextNumber(24, 150))
		-- skok vždy od mola (nikdy přes molo a hráče na něm)
		local a = rng:NextNumber(0, math.pi)
		dir = Vector3.new(math.cos(a), 0, side * math.sin(a))
	end
	local length = rng:NextNumber(26, 40)
	local to = from + dir * length
	if not companion and to.X < WATER_MIN_X then
		-- neskákat na mělčinu: otočit směr podél osy X
		to = from + Vector3.new(-dir.X, 0, dir.Z) * length
	end
	d.From = from
	d.To = to
	d.Height = rng:NextNumber(9, 15)
	d.Duration = rng:NextNumber(1.4, 1.8)
	d.Start = now
	d.Roll = if rng:NextNumber() < 0.25 then math.pi * 2 else 0
	d.Leaping = true
	d.Hidden = false
	d.SplashedIn = false
	d.SplashedOut = false
end

local function updateDolphin(d: Dolphin, now: number, companion: Vector3?, near: boolean)
	if not d.Leaping then
		hideDolphin(d)
		if now >= d.NextLeap and (near or companion) then
			planLeap(d, now, companion)
		end
		return
	end
	local t = (now - d.Start) / d.Duration
	if t >= 1 then
		d.Leaping = false
		d.NextLeap = now + rng:NextNumber(2.5, 7)
		hideDolphin(d)
		return
	end
	local flat = d.To - d.From
	local pos = d.From + flat * t + Vector3.yAxis * (4 * d.Height * t * (1 - t))
	local velocity = flat + Vector3.yAxis * (4 * d.Height * (1 - 2 * t))
	local cf = CFrame.lookAt(pos, pos + velocity) * CFrame.Angles(0, 0, d.Roll * t)
	queueRig(d.Pieces, cf)
	-- šplouchnutí při výskoku a dopadu
	if not d.SplashedIn and t > 0.12 then
		d.SplashedIn = true
		Effects.Ripple(Vector3.new(pos.X, World.WaterY, pos.Z), 1.2)
	elseif not d.SplashedOut and t > 0.88 then
		d.SplashedOut = true
		Effects.Ripple(Vector3.new(pos.X, World.WaterY, pos.Z), 1.4)
	end
end

-- ===== Rybky =====

local FISH_COLORS = {
	Color3.fromRGB(255, 140, 40),
	Color3.fromRGB(255, 220, 50),
	Color3.fromRGB(80, 200, 255),
	Color3.fromRGB(255, 90, 160),
	Color3.fromRGB(120, 240, 140),
}

local function buildFish(parent: Instance, color: Color3): { Piece }
	local pieces: { Piece } = {}
	piece(pieces, ellipsoid(parent, Vector3.new(0.6, 1, 2), color), CFrame.identity)
	piece(pieces, ellipsoid(parent, Vector3.new(0.15, 1, 0.9), color:Lerp(Color3.new(1, 1, 1), 0.35)), CFrame.new(0, 0, 1.2))
	return pieces
end

local function updateSchool(school: School, now: number, dt: number)
	-- hejno se pomalu přesouvá po velkém kruhu
	school.Drift += dt * 0.05
	local center = school.Center + Vector3.new(math.cos(school.Drift) * 12, 0, math.sin(school.Drift) * 12)
	for _, fish in school.Fish do
		fish.Angle += fish.Speed * dt * school.Direction
		local a = fish.Angle
		local pos = center + Vector3.new(math.cos(a) * fish.Radius, 0, math.sin(a) * fish.Radius)
		local y = World.WaterY - fish.Depth + math.sin(now * 3 + a) * 0.25
		local hopping = now < fish.Hop + 0.7 and now >= fish.Hop
		if hopping then
			local h = (now - fish.Hop) / 0.7
			y = World.WaterY - 1 + 4 * 3.2 * h * (1 - h)
		end
		pos = Vector3.new(pos.X, y, pos.Z)
		local tangent = Vector3.new(-math.sin(a), 0, math.cos(a)) * school.Direction
		-- vlnění ocasu + naklonění (třpyt ve světle)
		local cf = CFrame.lookAt(pos, pos + tangent) * CFrame.Angles(0, math.sin(now * 12 + a * 3) * 0.25, math.sin(now * 2 + a) * 0.5)
		queueRig(fish.Pieces, cf)
	end
end

-- ===== Rackové =====

local function buildGull(parent: Instance): ({ Piece }, { { Part: BasePart, Side: number, Outer: boolean } })
	local body: { Piece } = {}
	local white = Color3.fromRGB(250, 250, 250)
	local gray = Color3.fromRGB(150, 160, 175)
	piece(body, ellipsoid(parent, Vector3.new(1.2, 1.1, 3), white), CFrame.identity)
	piece(body, newPart(parent, Vector3.one * 1.05, white, Enum.PartType.Ball), CFrame.new(0, 0.45, -1.5))
	piece(body, ellipsoid(parent, Vector3.new(0.35, 0.3, 0.9), Color3.fromRGB(255, 180, 40)), CFrame.new(0, 0.35, -2.3))
	piece(body, ellipsoid(parent, Vector3.new(0.9, 0.2, 1.3), gray), CFrame.new(0, 0.1, 1.8))
	local wings = {}
	for _, side in { -1, 1 } do
		table.insert(wings, { Part = ellipsoid(parent, Vector3.new(2, 0.16, 1.3), white) :: BasePart, Side = side, Outer = false })
		table.insert(wings, { Part = ellipsoid(parent, Vector3.new(2, 0.12, 0.9), gray) :: BasePart, Side = side, Outer = true })
	end
	return body, wings
end

local function updateGull(gull: Gull, now: number, dt: number)
	gull.Angle += gull.Speed * dt
	local a = gull.Angle
	local dir = if gull.Speed > 0 then 1 else -1
	local pos = gull.Center + Vector3.new(math.cos(a) * gull.Radius, gull.Height + math.sin(now * 0.7 + gull.Phase) * 3, math.sin(a) * gull.Radius)
	local tangent = Vector3.new(-math.sin(a), 0, math.cos(a)) * dir
	local cf = CFrame.lookAt(pos, pos + tangent) * CFrame.Angles(0, 0, dir * 0.35)
	queueRig(gull.Body, cf)
	-- mávání: chvíli mává, chvíli plachtí
	local cycle = (now + gull.Phase) % 5
	local flap = if cycle < 2 then math.sin(now * 9 + gull.Phase) * 0.55 else 0.12 + math.sin(now * 1.5) * 0.05
	for _, wing in gull.Wings do
		local side = wing.Side
		local hinge = cf * CFrame.new(side * 0.45, 0.3, -0.1) * CFrame.Angles(0, 0, side * flap)
		if wing.Outer then
			queue(wing.Part, hinge * CFrame.new(side * 1.9, 0, 0.15) * CFrame.Angles(0, 0, side * flap * 0.7) * CFrame.new(side * 0.9, 0, 0))
		else
			queue(wing.Part, hinge * CFrame.new(side * 0.95, 0, 0))
		end
	end
end

-- ===== Třpytky na hladině =====

local function updateSparkles(now: number, camPos: Vector3, active: boolean)
	for _, s in sparkles do
		local age = now - s.Born
		if age >= s.Life then
			if not active then
				if s.Part.Transparency < 1 then
					s.Part.Transparency = 1
				end
				continue
			end
			-- nové místo na vodě kolem kamery
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(30, 170)
			local x = camPos.X + math.cos(a) * r
			local z = camPos.Z + math.sin(a) * r
			if x < WATER_MIN_X or math.abs(z) > World.WaterHalfWidth - 10 then
				s.Born = now + rng:NextNumber(0, 0.5)
				s.Life = 0
				s.Part.Transparency = 1
				continue
			end
			s.Born = now
			s.Life = rng:NextNumber(0.45, 0.9)
			s.Size = rng:NextNumber(0.5, 1.1)
			s.Part.Transparency = 0.05
			queue(s.Part, CFrame.new(x, World.WaterY + 0.15, z) * CFrame.Angles(0, math.rad(45), 0))
			age = 0
		end
		local k = math.sin(math.pi * math.clamp(age / math.max(s.Life, 0.01), 0, 1))
		s.Part.Size = Vector3.new(s.Size * k + 0.05, 0.05, s.Size * k + 0.05)
	end
end

-- ===== Start =====

function SeaLifeController.Init()
	root = Instance.new("Folder")
	root.Name = "SeaLife"
	root.Parent = Workspace
	nearFolder = Instance.new("Folder")
	nearFolder.Name = "NearBeach"
	nearFolder.Parent = root
	dolphinFolder = Instance.new("Folder")
	dolphinFolder.Name = "Dolphins"
	dolphinFolder.Parent = root
	sparkleFolder = Instance.new("Folder")
	sparkleFolder.Name = "Sparkles"
	sparkleFolder.Parent = root

	local tints = { Color3.fromRGB(95, 150, 215), Color3.fromRGB(120, 170, 225), Color3.fromRGB(80, 135, 200) }
	for i = 1, if LOW_END then 2 else 3 do
		table.insert(dolphins, {
			Pieces = buildDolphin(dolphinFolder, tints[i]),
			Leaping = false,
			NextLeap = os.clock() + i * 1.3,
			Start = 0,
			Duration = 1,
			From = Vector3.zero,
			To = Vector3.zero,
			Height = 0,
			Roll = 0,
			SplashedIn = false,
			SplashedOut = false,
			Hidden = true, -- díly vznikly na HIDDEN
		})
	end

	local fishPerSchool = if LOW_END then 4 else 6
	local schoolCenters = {
		Vector3.new(World.PierEndX - 95, World.WaterY, 24),
		Vector3.new(World.PierEndX - 40, World.WaterY, -28),
		Vector3.new(World.PierEndX + 35, World.WaterY, 20),
	}
	for index, center in schoolCenters do
		local school: School = { Fish = {}, Center = center, Drift = rng:NextNumber(0, 6), Direction = if index % 2 == 0 then -1 else 1 }
		local color = FISH_COLORS[(index - 1) % #FISH_COLORS + 1]
		for i = 1, fishPerSchool do
			local fishColor = if i % 3 == 0 then FISH_COLORS[(index + 1) % #FISH_COLORS + 1] else color
			table.insert(school.Fish, {
				Pieces = buildFish(nearFolder, fishColor),
				Angle = i / fishPerSchool * math.pi * 2 + rng:NextNumber(-0.2, 0.2),
				Radius = rng:NextNumber(3, 6),
				Depth = rng:NextNumber(1, 2),
				Speed = rng:NextNumber(0.7, 1),
				Hop = -10,
			})
		end
		table.insert(schools, school)
	end

	local gullSpots = {
		Vector3.new(World.BeachFrontX - 20, World.SandY, 45),
		Vector3.new(World.PierEndX - 80, World.SandY, -55),
		Vector3.new(World.PierEndX + 20, World.SandY, 60),
		Vector3.new(World.BeachFrontX - 110, World.SandY, -10),
		Vector3.new(World.PierEndX - 30, World.SandY, 10),
	}
	for i = 1, if LOW_END then 3 else #gullSpots do
		local body, wings = buildGull(nearFolder)
		table.insert(gulls, {
			Body = body,
			Wings = wings,
			Center = gullSpots[i],
			Radius = rng:NextNumber(22, 45),
			Height = rng:NextNumber(34, 52),
			Speed = rng:NextNumber(0.22, 0.38) * (if i % 2 == 0 then -1 else 1),
			Angle = rng:NextNumber(0, math.pi * 2),
			Phase = rng:NextNumber(0, 5),
		})
	end

	for _ = 1, if LOW_END then 6 else 12 do
		local p = newPart(sparkleFolder, Vector3.new(0.6, 0.05, 0.6), Color3.fromRGB(255, 255, 240), nil, Enum.Material.Neon)
		p.Transparency = 1
		table.insert(sparkles, { Part = p, Born = 0, Life = 0, Size = 1 })
	end

	local nextHop = os.clock() + 3
	RunService.Heartbeat:Connect(function(dt: number)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local now = os.clock()
		local camPos = camera.CFrame.Position
		local flat = Vector3.new(camPos.X - CENTER.X, 0, camPos.Z - CENTER.Z)
		local near = flat.Magnitude < NEAR_DISTANCE
		local companion: Vector3? = if not near and camPos.X > COMPANION_MIN_X and camPos.Y < COMPANION_MAX_HEIGHT then camPos else nil
		table.clear(moveParts)
		table.clear(moveFrames)

		-- rybky a rackové jen u pláže
		if near then
			if nearFolder.Parent ~= root then
				nearFolder.Parent = root
			end
			if now >= nextHop and #schools > 0 then
				nextHop = now + rng:NextNumber(2.5, 5.5)
				local school = schools[rng:NextInteger(1, #schools)]
				local fish = school.Fish[rng:NextInteger(1, #school.Fish)]
				fish.Hop = now
				task.delay(0.08, function()
					Effects.Ripple(school.Center + Vector3.new(math.cos(school.Drift) * 12, 0, math.sin(school.Drift) * 12) + Vector3.new(math.cos(fish.Angle) * fish.Radius, 0, math.sin(fish.Angle) * fish.Radius), 0.45)
				end)
			end
			for _, school in schools do
				updateSchool(school, now, dt)
			end
			for _, gull in gulls do
				updateGull(gull, now, dt)
			end
		elseif nearFolder.Parent ~= nil then
			nearFolder.Parent = nil
		end

		-- delfíni u mola nebo jako doprovod na moři
		if near or companion then
			if dolphinFolder.Parent ~= root then
				dolphinFolder.Parent = root
			end
			for _, d in dolphins do
				updateDolphin(d, now, companion, near)
			end
		else
			-- schovat přímo (odpojené díly už BulkMoveTo neposouvá)
			for _, d in dolphins do
				if d.Leaping or not d.Hidden then
					d.Leaping = false
					d.Hidden = true
					for _, p in d.Pieces do
						p.Part.CFrame = HIDDEN
					end
				end
			end
			if dolphinFolder.Parent ~= nil then
				dolphinFolder.Parent = nil
			end
		end

		-- třpytky kdekoli nad vodou, když je kamera nízko
		updateSparkles(now, camPos, camPos.Y < SPARKLE_MAX_HEIGHT and camPos.X > WATER_MIN_X - 200)

		if #moveParts > 0 then
			Workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return SeaLifeController

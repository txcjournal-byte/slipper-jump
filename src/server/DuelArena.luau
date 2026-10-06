--!strict
-- Areny pro CHALLENGE souboje na pláži:
--  🏃 BEACH LONG JUMP – červená tartanová dráha se dvěma drahami, bílá odrazová čára, doskočiště z písku
--     s metry, startovní bloky, tribunka a praporky
--  🏂 SAND SKI JUMP – vysoká písečná duna s praporky, startovní věž nahoře, můstek na kraji vody
--     a bóje s metry na hladině
-- U každé areny je cedule s výzvou PRACTICE (trénink o samotě). Souboj s hráčem = výzva CHALLENGE u hráče.

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Duels = require(Shared.Config.Duels)
local World = require(Shared.Config.World)

local DuelArena = {}

local WHITE = Color3.new(1, 1, 1)
local TARTAN = Color3.fromRGB(196, 72, 52)
local SAND_LIGHT = Color3.fromRGB(245, 222, 170)
local WOOD = Color3.fromRGB(150, 100, 60)
local UP = CFrame.Angles(0, 0, math.rad(90))

local function P(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanQuery = collide == true
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

local function label(parent: BasePart, face: Enum.NormalId, text: string, color: Color3, ppm: number?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppm or 30
	gui.LightInfluence = 0.2
	gui.Parent = parent
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color
	t.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(30, 30, 45)
	stroke.Parent = t
end

local function flagLine(parent: Instance, from: Vector3, to: Vector3, count: number)
	local colors = { Color3.fromRGB(255, 80, 90), Color3.fromRGB(255, 210, 50), Color3.fromRGB(80, 200, 255), Color3.fromRGB(110, 220, 120) }
	for i = 0, count - 1 do
		local pos = from:Lerp(to, i / math.max(1, count - 1))
		P(parent, Vector3.new(0.3, 9, 0.3), CFrame.new(pos + Vector3.new(0, 4.5, 0)), WHITE)
		local flag = Instance.new("WedgePart")
		flag.Anchored = true
		flag.CanCollide = false
		flag.CanQuery = false
		flag.CanTouch = false
		flag.Size = Vector3.new(0.15, 1.6, 2.4)
		flag.CFrame = CFrame.new(pos + Vector3.new(0, 8, 1.2))
		flag.Color = colors[i % #colors + 1]
		flag.Parent = parent
	end
end

-- Cedule s názvem hry a výzvou PRACTICE
local function sign(parent: Instance, pos: Vector3, facingDir: Vector3, gameKey: string): ProximityPrompt
	local cfg = Duels.Games[gameKey]
	local board = P(parent, Vector3.new(16, 7, 0.6), CFrame.lookAt(pos + Vector3.new(0, 9, 0), pos + Vector3.new(0, 9, 0) + facingDir), Color3.fromRGB(255, 248, 230), Enum.Material.SmoothPlastic, nil, true)
	for _, dx in { -7, 7 } do
		P(parent, Vector3.new(0.7, 9, 0.7), board.CFrame * CFrame.new(dx, -5, 0), WOOD, Enum.Material.Wood)
	end
	label(board, Enum.NormalId.Front, `{cfg.Icon} {cfg.Name}`, Color3.fromRGB(255, 120, 60))
	label(board, Enum.NormalId.Back, `{cfg.Icon} {cfg.Name}`, Color3.fromRGB(255, 120, 60))
	local sub = P(parent, Vector3.new(15, 2.2, 0.62), board.CFrame * CFrame.new(0, -2.3, 0), Color3.fromRGB(255, 248, 230))
	label(sub, Enum.NormalId.Front, "Challenge a player (press C near them) or PRACTICE here!", Color3.fromRGB(50, 50, 70))
	label(sub, Enum.NormalId.Back, "Challenge a player (press C near them) or PRACTICE here!", Color3.fromRGB(50, 50, 70))
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DuelPracticePrompt"
	prompt.ActionText = "Practice"
	prompt.ObjectText = cfg.Name
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("Game", gameKey)
	prompt.Parent = board
	CollectionService:AddTag(prompt, "DuelPracticePrompt")
	return prompt
end

local function buildLongJump(root: Instance): (Instance, ProximityPrompt)
	local cfg = Duels.Games.LongJump
	local m = Instance.new("Model")
	m.Name = "LongJumpArena"
	m.Parent = root
	local y = World.SandY
	local z0 = cfg.Z
	local runLen = cfg.BoardX - cfg.StartX
	local pitLen = cfg.PitEndX - cfg.BoardX
	local width = 26
	-- rozběhová dráha (tartan) s bílými čarami drah
	P(m, Vector3.new(runLen + 8, 0.3, width), CFrame.new(cfg.StartX - 8 + (runLen + 8) / 2, y + 0.15, z0), TARTAN, Enum.Material.Fabric, nil, true)
	for _, lz in { -12.5, 0, 12.5 } do
		P(m, Vector3.new(runLen + 8, 0.05, 0.4), CFrame.new(cfg.StartX - 8 + (runLen + 8) / 2, y + 0.32, z0 + lz), WHITE)
	end
	-- startovní bloky a čísla drah
	for i, lane in cfg.Lanes do
		P(m, Vector3.new(1.2, 0.8, 1.6), CFrame.new(cfg.StartX - 1, y + 0.6, z0 + lane - 0.9), Color3.fromRGB(60, 60, 70))
		P(m, Vector3.new(1.2, 0.8, 1.6), CFrame.new(cfg.StartX - 2.5, y + 0.6, z0 + lane + 0.9), Color3.fromRGB(60, 60, 70))
		local num = P(m, Vector3.new(4, 0.06, 4), CFrame.new(cfg.StartX + 4, y + 0.33, z0 + lane), WHITE)
		label(num, Enum.NormalId.Top, tostring(i), TARTAN, 40)
	end
	-- odrazové prkno (bílé) a červená zóna přešlapu
	P(m, Vector3.new(1.2, 0.12, width), CFrame.new(cfg.BoardX - 0.6, y + 0.36, z0), WHITE, Enum.Material.SmoothPlastic)
	P(m, Vector3.new(0.6, 0.13, width), CFrame.new(cfg.BoardX + 0.3, y + 0.36, z0), Color3.fromRGB(230, 40, 40), Enum.Material.Neon)
	-- doskočiště: světlejší písek s rámem a čarami po metrech
	P(m, Vector3.new(pitLen, 0.2, width), CFrame.new(cfg.BoardX + pitLen / 2, y + 0.1, z0), SAND_LIGHT, Enum.Material.Sand, nil, true)
	for _, side in { -1, 1 } do
		P(m, Vector3.new(pitLen, 0.6, 0.8), CFrame.new(cfg.BoardX + pitLen / 2, y + 0.3, z0 + side * (width / 2 + 0.4)), WHITE, Enum.Material.Concrete, nil, true)
	end
	local meters = math.floor(pitLen / cfg.StudsPerMeter)
	for mtr = 1, meters do
		local x = cfg.BoardX + mtr * cfg.StudsPerMeter
		P(m, Vector3.new(0.25, 0.05, width), CFrame.new(x, y + 0.22, z0), Color3.fromRGB(255, 255, 255))
		if mtr % 2 == 0 then
			local tag = P(m, Vector3.new(0.4, 2.4, 3.6), CFrame.new(x, y + 1.2, z0 + width / 2 + 3), WHITE, nil, nil, false)
			label(tag, Enum.NormalId.Left, `{mtr} m`, Color3.fromRGB(40, 60, 120))
			label(tag, Enum.NormalId.Right, `{mtr} m`, Color3.fromRGB(40, 60, 120))
		end
	end
	-- tribunka podél dráhy
	for row = 0, 2 do
		P(m, Vector3.new(70, 1.4, 3), CFrame.new(cfg.BoardX - 10, y + 0.7 + row * 1.4, z0 - width / 2 - 6 - row * 3), Color3.fromRGB(80, 140, 230), Enum.Material.SmoothPlastic, nil, true)
	end
	flagLine(m, Vector3.new(cfg.StartX, y, z0 + width / 2 + 2), Vector3.new(cfg.PitEndX, y, z0 + width / 2 + 2), 9)
	local prompt = sign(m, Vector3.new(cfg.StartX - 14, y, z0 - 18), Vector3.new(-1, 0, -0.3).Unit, "LongJump")
	return m, prompt
end

local function buildSandSki(root: Instance): (Instance, ProximityPrompt)
	local cfg = Duels.Games.SandSki
	local m = Instance.new("Model")
	m.Name = "SandSkiArena"
	m.Parent = root
	local y = World.SandY
	local z0 = cfg.Z
	local width = 34
	local run = cfg.LipX - cfg.TopX
	local drop = cfg.TopY - cfg.LipY
	-- duna: klín od vrcholu ke hraně můstku a pod ní podklad až na písek
	local slope = Instance.new("WedgePart")
	slope.Anchored = true
	slope.Size = Vector3.new(width, drop, run)
	slope.CFrame = CFrame.new(cfg.TopX + run / 2, cfg.LipY + drop / 2, z0) * CFrame.Angles(0, math.rad(-90), 0)
	slope.Color = Color3.fromRGB(236, 205, 140)
	slope.Material = Enum.Material.Sand
	slope.Parent = m
	P(m, Vector3.new(run, cfg.LipY - y, width), CFrame.new(cfg.TopX + run / 2, y + (cfg.LipY - y) / 2, z0), Color3.fromRGB(226, 195, 130), Enum.Material.Sand, nil, true)
	-- startovní plošina a věž
	P(m, Vector3.new(16, cfg.TopY - y, width), CFrame.new(cfg.TopX - 8, y + (cfg.TopY - y) / 2, z0), Color3.fromRGB(226, 195, 130), Enum.Material.Sand, nil, true)
	for _, dz in { -width / 2 + 1, width / 2 - 1 } do
		P(m, Vector3.new(0.8, 12, 0.8), CFrame.new(cfg.TopX - 2, cfg.TopY + 6, z0 + dz), WOOD, Enum.Material.Wood)
	end
	local gate = P(m, Vector3.new(1, 3, width), CFrame.new(cfg.TopX - 2, cfg.TopY + 12, z0), Color3.fromRGB(255, 120, 60), Enum.Material.SmoothPlastic)
	label(gate, Enum.NormalId.Left, "🏂 SAND SKI JUMP", WHITE)
	label(gate, Enum.NormalId.Right, "🏂 SAND SKI JUMP", WHITE)
	-- můstek: krátký klín nahoru na hraně
	local kicker = Instance.new("WedgePart")
	kicker.Anchored = true
	kicker.Size = Vector3.new(width - 6, 2.5, 10)
	kicker.CFrame = CFrame.new(cfg.LipX - 3, cfg.LipY + 1.25, z0) * CFrame.Angles(0, math.rad(90), 0)
	kicker.Color = Color3.fromRGB(255, 255, 255)
	kicker.Material = Enum.Material.WoodPlanks
	kicker.Parent = m
	P(m, Vector3.new(0.6, 0.2, width - 6), CFrame.new(cfg.LipX + 2, cfg.LipY + 2.6, z0), Color3.fromRGB(230, 40, 40), Enum.Material.Neon)
	-- sloupy pod můstkem až na písek / do vody
	for _, dz in { -width / 2 + 4, width / 2 - 4 } do
		P(m, Vector3.new(cfg.LipY + 4, 1.4, 1.4), CFrame.new(cfg.LipX, (cfg.LipY - 4) / 2 + 1, z0 + dz) * UP, WOOD, Enum.Material.Wood)
	end
	-- praporky (branky) pro obě dráhy
	local slopeAt = function(t: number): Vector3
		return Vector3.new(cfg.TopX + run * t, cfg.TopY - drop * t, z0)
	end
	for _, lane in cfg.Lanes do
		for i, g in cfg.Gates do
			local base = slopeAt(g.At) + Vector3.new(0, 0, lane + g.Offset)
			local color = if i % 2 == 0 then Color3.fromRGB(60, 140, 255) else Color3.fromRGB(255, 70, 80)
			for _, side in { -1, 1 } do
				local pz = side * cfg.GateHalfWidth
				P(m, Vector3.new(0.3, 4, 0.3), CFrame.new(base + Vector3.new(0, 2, pz)), WHITE)
				P(m, Vector3.new(0.2, 1.4, 1.4), CFrame.new(base + Vector3.new(0, 3.4, pz + side * 0.7)), color, Enum.Material.Fabric)
			end
		end
	end
	-- dělicí čára mezi drahami
	local mid = Instance.new("Part")
	mid.Anchored = true
	mid.CanCollide = false
	mid.CanQuery = false
	mid.Size = Vector3.new(run, 0.1, 0.5)
	mid.CFrame = CFrame.lookAt(slopeAt(0.5) + Vector3.new(0, 0.1, 0), slopeAt(1) + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, math.rad(90), 0)
	mid.Color = WHITE
	mid.Material = Enum.Material.Neon
	mid.Transparency = 0.3
	mid.Parent = m
	-- bóje s metry na vodě
	for _, mtr in { 25, 50, 75, 100 } do
		local x = cfg.LipX + mtr * cfg.StudsPerMeter
		for _, lane in cfg.Lanes do
			local buoy = P(m, Vector3.new(2.4, 2.4, 2.4), CFrame.new(x, World.WaterY + 0.6, z0 + lane + 6), Color3.fromRGB(255, 200, 40), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromOffset(80, 32)
			gui.StudsOffset = Vector3.new(0, 2.6, 0)
			gui.MaxDistance = 250
			gui.Parent = buoy
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1, 1)
			t.Font = Enum.Font.FredokaOne
			t.TextScaled = true
			t.Text = `{mtr} m`
			t.TextColor3 = WHITE
			t.Parent = gui
			local s = Instance.new("UIStroke")
			s.Thickness = 2
			s.Parent = t
		end
	end
	flagLine(m, Vector3.new(cfg.TopX - 14, y, z0 + width / 2 + 3), Vector3.new(cfg.LipX - 12, y, z0 + width / 2 + 3), 8)
	local prompt = sign(m, Vector3.new(cfg.TopX - 22, y, z0 + 20), Vector3.new(-1, 0, 0.3).Unit, "SandSki")
	return m, prompt
end

-- Postaví obě areny a vrátí výzvy PRACTICE (klíč = hra)
function DuelArena.Build(parent: Instance): { [string]: ProximityPrompt }
	local folder = Instance.new("Folder")
	folder.Name = "DuelArenas"
	folder.Parent = parent
	local _, ljPrompt = buildLongJump(folder)
	local _, skiPrompt = buildSandSki(folder)
	return { LongJump = ljPrompt, SandSki = skiPrompt }
end

-- Kam hráče postavit na start (dráha 1 nebo 2) a kam ho po souboji vrátit
function DuelArena.StartCFrame(gameKey: string, lane: number): CFrame
	local cfg = Duels.Games[gameKey]
	local z = cfg.Z + cfg.Lanes[lane]
	if gameKey == "LongJump" then
		return CFrame.lookAt(Vector3.new(cfg.StartX, cfg.Y, z), Vector3.new(cfg.StartX + 10, cfg.Y, z))
	end
	return CFrame.lookAt(Vector3.new(cfg.TopX - 3, cfg.TopY + cfg.Y, z), Vector3.new(cfg.TopX + 10, cfg.TopY + cfg.Y, z))
end

function DuelArena.ExitCFrame(gameKey: string): CFrame
	local cfg = Duels.Games[gameKey]
	local x = if gameKey == "LongJump" then cfg.StartX - 12 else cfg.TopX - 30
	local pos = Vector3.new(x, World.SandY + 3, cfg.Z + (if gameKey == "LongJump" then -34 else 36))
	return CFrame.lookAt(pos, pos + Vector3.new(1, 0, 0))
end

-- ===== Lyže / snowboard pod nohama (Sand Ski) =====

local GEAR_NAME = "DuelSkiGear"
-- uložené původní polohy kloubů (Motor6D.C0 nebo torzový Attachment u AnimationConstraint)
local savedJoints: { [Instance]: CFrame } = {}

-- postoj na snowboardu: nohy od sebe (jedna vpředu, druhá vzadu), ruce rozpažené kvůli rovnováze
local STANCE: { { R15: string, R6: string, Angle: number } } = {
	{ R15 = "LeftHip", R6 = "Left Hip", Angle = -16 },
	{ R15 = "RightHip", R6 = "Right Hip", Angle = 16 },
	{ R15 = "LeftShoulder", R6 = "Left Shoulder", Angle = -70 },
	{ R15 = "RightShoulder", R6 = "Right Shoulder", Angle = 70 },
}

-- klouby postavy: klasický Motor6D (C0) i nový AnimationConstraint (jeho Attachment0 na trupu)
local function stanceJoints(character: Model): { [Instance]: number }
	local found: { [Instance]: number } = {}
	for _, d in character:GetDescendants() do
		for _, row in STANCE do
			if d.Name == row.R15 or d.Name == row.R6 then
				if d:IsA("Motor6D") then
					found[d] = row.Angle
				elseif d:IsA("AnimationConstraint") and d.Attachment0 then
					found[d.Attachment0 :: Attachment] = row.Angle
				end
			end
		end
	end
	return found
end

local function getJoint(joint: Instance): CFrame
	return if joint:IsA("Motor6D") then joint.C0 else (joint :: Attachment).CFrame
end

local function setJoint(joint: Instance, cf: CFrame)
	if joint:IsA("Motor6D") then
		joint.C0 = cf
	else
		(joint :: Attachment).CFrame = cf
	end
end

local function setStance(character: Model, on: boolean)
	for joint, angle in stanceJoints(character) do
		local original = savedJoints[joint]
		if on then
			if not original then
				original = getJoint(joint)
				savedJoints[joint] = original
			end
			-- otočení kolem kloubu v prostoru trupu
			local c0 = original :: CFrame
			setJoint(joint, CFrame.new(c0.Position) * CFrame.Angles(0, 0, math.rad(angle)) * c0.Rotation)
		elseif original then
			setJoint(joint, original)
			savedJoints[joint] = nil
		end
	end
end

function DuelArena.RemoveSkiGear(character: Model?)
	local old = character and character:FindFirstChild(GEAR_NAME)
	if old then
		old:Destroy()
	end
	if character then
		setStance(character, false)
	end
	-- uklidit záznamy po zničených postavách
	for joint in savedJoints do
		if not joint.Parent then
			savedJoints[joint] = nil
		end
	end
end

-- kind = "Skis" | "Board"; díly jsou přivařené k HumanoidRootPart (klient s ním hýbe po svahu)
function DuelArena.EquipSkiGear(character: Model?, kind: string)
	if not character then
		return
	end
	DuelArena.RemoveSkiGear(character)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local ground = if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight + root.Size.Y / 2 else 3
	local model = Instance.new("Model")
	model.Name = GEAR_NAME
	local base = root.CFrame * CFrame.new(0, -ground + 0.07, 0)
	local function part(size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?)
		local p = Instance.new("Part")
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.Shape = shape or Enum.PartType.Block
		p.Size = size
		p.CFrame = base * offset
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
	end
	if kind == "Board" then
		-- prkno napříč postavou: jezdec stojí bokem (klient ho natočí), jedna noha vpředu, druhá vzadu
		local teal = Color3.fromRGB(30, 190, 200)
		local deck = Color3.fromRGB(255, 120, 60)
		part(Vector3.new(4.4, 0.16, 1.6), CFrame.new(0, 0, 0), teal)
		for _, x in { -2.2, 2.2 } do
			-- zakulacené špičky
			part(Vector3.new(0.16, 1.6, 1.6), CFrame.new(x, 0, 0) * CFrame.Angles(0, 0, math.rad(90)), teal, Enum.PartType.Cylinder)
		end
		part(Vector3.new(0.5, 0.17, 1.62), CFrame.new(-1.6, 0.005, 0), deck)
		part(Vector3.new(0.5, 0.17, 1.62), CFrame.new(1.6, 0.005, 0), deck)
		for _, x in { -1.05, 1.05 } do
			part(Vector3.new(0.7, 0.35, 1.25), CFrame.new(x, 0.25, 0) * CFrame.Angles(0, math.rad(if x < 0 then 12 else -12), 0), Color3.fromRGB(35, 35, 40))
		end
		setStance(character, true)
	else
		local red = Color3.fromRGB(220, 45, 50)
		for _, x in { -0.55, 0.55 } do
			part(Vector3.new(0.45, 0.12, 6.4), CFrame.new(x, 0, -0.4), red)
			part(Vector3.new(0.14, 0.12, 5.4), CFrame.new(x, 0.02, -0.6), WHITE)
			-- zahnutá špička vpředu
			part(Vector3.new(0.45, 0.12, 1.0), CFrame.new(x, 0, -3.6) * CFrame.Angles(math.rad(28), 0, 0) * CFrame.new(0, 0, -0.45), red)
			-- vázání
			part(Vector3.new(0.55, 0.4, 1.2), CFrame.new(x, 0.25, 0), Color3.fromRGB(35, 35, 40))
		end
	end
	model.Parent = character
end

return DuelArena

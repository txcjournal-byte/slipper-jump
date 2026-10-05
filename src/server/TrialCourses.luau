--!strict
-- Stavby pro úkoly na cestu zpět z dárkových ostrovů:
--  • Bronze a Obří dárek: dřevěné molo s kánoí (závod na kánoi domů – voda, branky, pronásledovatel),
--  • Silver: barevná dráha nad mořem (skákací „obby“) s vlaječkami, mizejícími plošinami,
--    otáčejícími se tyčemi a kládami. Spadnutí do vody = zpět na poslední vlaječku.
-- Vrací pro každý ostrov místo startu (a u dráhy kontrolní body, cíl a pohyblivé části).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local World = require(Shared.Config.World)
local TrialsConfig = require(Shared.Config.Trials)
local Models = require(Shared.Models)

local TrialCourses = {}

export type Sweeper = { Bar: BasePart, Center: Vector3, Length: number, Speed: number, Phase: number }
export type Fader = { Part: BasePart, Phase: number, Color: Color3 }
export type Spot = {
	Key: string,
	Kind: string,
	Start: CFrame, -- kde hráč stojí na začátku (a kam se vrací po neúspěchu)
	Prompt: ProximityPrompt,
	Target: Vector3, -- kam ukazuje šipka
	WaterStart: Vector3?, -- kánoe: odkud se pádluje
	Checkpoints: { CFrame }, -- dráha: vlaječky (1 = start)
	CheckpointX: { number },
	Finish: Vector3?,
	Sweepers: { Sweeper },
	Faders: { Fader },
}

local RAINBOW = {
	Color3.fromRGB(255, 80, 90),
	Color3.fromRGB(255, 160, 50),
	Color3.fromRGB(255, 220, 60),
	Color3.fromRGB(90, 210, 100),
	Color3.fromRGB(60, 160, 255),
	Color3.fromRGB(170, 100, 255),
}
local WOOD_DARK = Color3.fromRGB(125, 82, 50)
local WHITE = Color3.new(1, 1, 1)
local UP = CFrame.Angles(0, 0, math.rad(90))

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?, name: string?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Shape = shape or Enum.PartType.Block
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

local function deco(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function sign(parent: Instance, position: Vector3, text: string, color: Color3)
	local board = deco(part(parent, Vector3.new(0.6, 4.5, 14), CFrame.new(position), color, Enum.Material.SmoothPlastic, nil, "Sign"))
	for _, z in { -5.5, 5.5 } do
		deco(part(parent, Vector3.new(0.6, 6, 0.6), CFrame.new(position + Vector3.new(0, -3.5, z)), WOOD_DARK, Enum.Material.Wood))
	end
	-- nápis z obou stran
	for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 0
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = text
		label.TextColor3 = WHITE
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Color3.fromRGB(40, 30, 20)
		stroke.Parent = label
	end
end

local function prompt(parent: BasePart, action: string, object: string): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = "TrialPrompt"
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = 16
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

-- Molo s kánoí na západním břehu ostrova (směrem k molu na pláži)
local function canoeDock(root: Instance, key: string, title: string, deckFromX: number, deckTop: number): Spot
	local m = Instance.new("Model")
	m.Name = key .. "CanoeDock"
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = root
	local length = 34
	local endX = deckFromX - length
	part(m, Vector3.new(length, 0.6, 9), CFrame.new(deckFromX - length / 2, deckTop - 0.3, 0), Color3.fromRGB(205, 150, 95), Enum.Material.WoodPlanks, nil, "CanoeDock")
	for k = 0, 3 do
		for _, side in { -1, 1 } do
			local h = deckTop - (World.WaterY - 3)
			deco(part(m, Vector3.new(h, 1.2, 1.2), CFrame.new(deckFromX - 4 - k * 10, World.WaterY - 3 + h / 2, side * 4.6) * UP, WOOD_DARK, Enum.Material.Wood, Enum.PartType.Cylinder))
		end
	end
	sign(m, Vector3.new(deckFromX - 6, deckTop + 6.5, 7.5), title .. "  ➜  HOME", Color3.fromRGB(40, 140, 220))
	-- kánoe na vodě u konce mola
	local canoe = Models.Canoe()
	Models.Anchor(canoe)
	canoe:PivotTo(CFrame.lookAt(Vector3.new(endX - 6, World.WaterY + 0.1, 0), Vector3.new(endX - 20, World.WaterY + 0.1, 0)))
	for _, d in canoe:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	canoe.Parent = m
	local handle = canoe.PrimaryPart :: BasePart
	local p = prompt(handle, "Start Canoe Race", title)
	return {
		Key = key,
		Kind = "Canoe",
		Start = CFrame.lookAt(Vector3.new(endX + 4, deckTop + 3, 0), Vector3.new(endX - 10, deckTop + 3, 0)),
		Prompt = p,
		Target = Vector3.new(endX - 6, World.WaterY + 1, 0),
		WaterStart = Vector3.new(endX - 10, World.WaterY, 0),
		Checkpoints = {},
		CheckpointX = {},
		Finish = nil,
		Sweepers = {},
		Faders = {},
	}
end

-- Barevná dráha nad mořem (Silver): vede z ostrova na západ
local function skyPath(root: Instance, key: string, title: string, fromX: number, islandTop: number): Spot
	local m = Instance.new("Model")
	m.Name = key .. "SkyPath"
	m.Parent = root
	local deckY = World.WaterY + TrialsConfig.ObbyDeckY
	local colorIndex = 0
	local function nextColor(): Color3
		colorIndex += 1
		return RAINBOW[(colorIndex - 1) % #RAINBOW + 1]
	end
	local function pad(x: number, z: number, size: Vector3, color: Color3?, name: string?): Part
		local p = part(m, size, CFrame.new(x, deckY - size.Y / 2, z), color or nextColor(), Enum.Material.SmoothPlastic, nil, name or "PathPad")
		p.Material = Enum.Material.SmoothPlastic
		return p
	end
	local checkpoints: { CFrame } = {}
	local checkpointX: { number } = {}
	local function checkpoint(x: number, number: number)
		local p = pad(x, 0, Vector3.new(14, 1, 14), Color3.fromRGB(245, 245, 250), "Checkpoint")
		-- vlaječka
		deco(part(m, Vector3.new(0.4, 8, 0.4), CFrame.new(x, deckY + 4, 6), WHITE))
		local flag = deco(part(m, Vector3.new(0.2, 2.4, 3.6), CFrame.new(x, deckY + 6.8, 7.9), Color3.fromRGB(255, 90, 90), Enum.Material.Neon, nil, "Flag"))
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(120, 40)
		gui.StudsOffset = Vector3.new(0, 3, 0)
		gui.MaxDistance = 200
		gui.Parent = flag
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = WHITE
		label.TextStrokeTransparency = 0
		label.Text = "🚩 " .. number
		label.Parent = gui
		local _ = p
		table.insert(checkpoints, CFrame.lookAt(Vector3.new(x, deckY + 3, 0), Vector3.new(x - 10, deckY + 3, 0)))
		table.insert(checkpointX, x)
	end

	local x = fromX
	-- nájezd z ostrova (rampa) a startovní plošina
	local ramp = Instance.new("WedgePart")
	ramp.Anchored = true
	ramp.Size = Vector3.new(16, deckY - islandTop, 12)
	ramp.CFrame = CFrame.new(x + 6, islandTop + (deckY - islandTop) / 2, 0) * CFrame.Angles(0, math.rad(90), 0)
	ramp.Color = RAINBOW[5]
	ramp.Material = Enum.Material.SmoothPlastic
	ramp.Parent = m
	local startPad = pad(x - 10, 0, Vector3.new(20, 1, 16), RAINBOW[1], "StartPad")
	sign(m, Vector3.new(x - 4, deckY + 6.5, 9), title .. "  ➜  HOME", Color3.fromRGB(150, 90, 230))
	local p = prompt(startPad, "Start Sky Path", title)
	table.insert(checkpoints, CFrame.lookAt(Vector3.new(x - 10, deckY + 3, 0), Vector3.new(x - 20, deckY + 3, 0)))
	table.insert(checkpointX, x - 10)
	x -= 20

	-- 1) kameny přes vodu (střídavě vlevo a vpravo)
	for i = 1, 6 do
		x -= 6
		pad(x - 3.5, if i % 2 == 0 then 4 else -4, Vector3.new(7, 1, 7))
		x -= 7
	end
	x -= 6
	checkpoint(x - 7, 1)
	x -= 14

	-- 2) úzká kladina a schody nahoru a dolů
	x -= 4
	pad(x - 18, 0, Vector3.new(36, 1, 2.4))
	x -= 36
	for i = 1, 4 do
		x -= 4
		local rise = if i <= 2 then i * 2 else (5 - i) * 2
		local step = part(m, Vector3.new(7, 1, 8), CFrame.new(x - 3.5, deckY - 0.5 + rise, 0), nextColor(), Enum.Material.SmoothPlastic, nil, "PathPad")
		local _ = step
		x -= 7
	end
	x -= 5
	checkpoint(x - 7, 2)
	x -= 14

	-- 3) mizející plošiny
	local faders: { Fader } = {}
	for i = 1, 6 do
		x -= 5
		local color = nextColor()
		local f = pad(x - 4, if i % 2 == 0 then 3 else -3, Vector3.new(8, 1, 8), color, "FadingPad")
		table.insert(faders, { Part = f :: BasePart, Phase = i * 0.55, Color = color })
		x -= 8
	end
	x -= 5
	checkpoint(x - 7, 3)
	x -= 14

	-- 4) dlouhá plošina s otáčejícími se tyčemi (přeskoč je!)
	x -= 4
	local platformLength = 66
	pad(x - platformLength / 2, 0, Vector3.new(platformLength, 1, 12), Color3.fromRGB(60, 70, 110))
	local sweepers: { Sweeper } = {}
	for i, frac in { 0.28, 0.72 } do
		local center = Vector3.new(x - platformLength * frac, deckY + 1.6, 0)
		deco(part(m, Vector3.new(3.4, 1.6, 1.6), CFrame.new(center.X, deckY + 0.9, 0) * UP, Color3.fromRGB(40, 40, 50), Enum.Material.Metal, Enum.PartType.Cylinder))
		local bar = deco(part(m, Vector3.new(11.5, 0.9, 0.9), CFrame.new(center), if i == 1 then Color3.fromRGB(255, 70, 70) else Color3.fromRGB(255, 200, 40), Enum.Material.Neon, nil, "Sweeper"))
		table.insert(sweepers, { Bar = bar, Center = center, Length = 11.5, Speed = if i == 1 then 1.7 else -2.1, Phase = i * 1.3 })
	end
	x -= platformLength
	x -= 4
	checkpoint(x - 7, 4)
	x -= 14

	-- 5) barevné klády přes vodu (jako hrazda) – přeskakuj z jedné na druhou
	for i = 1, 7 do
		x -= 3.5
		part(m, Vector3.new(10, 2.4, 2.4), CFrame.new(x - 1.2, deckY - 1.2, 0) * CFrame.Angles(0, math.rad(90), 0), nextColor(), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, "PathPad")
		x -= 2.4
		local _ = i
	end
	x -= 5

	-- cíl: velká plošina s obloukem
	local finishX = x - 12
	pad(finishX, 0, Vector3.new(24, 1, 18), Color3.fromRGB(255, 215, 60), "FinishPad")
	for _, z in { -8, 8 } do
		deco(part(m, Vector3.new(1.2, 14, 1.2), CFrame.new(finishX, deckY + 7, z), RAINBOW[if z > 0 then 2 else 4], Enum.Material.Neon))
	end
	local arch = deco(part(m, Vector3.new(1.2, 1.2, 17.2), CFrame.new(finishX, deckY + 14, 0), RAINBOW[6], Enum.Material.Neon, nil, "FinishArch"))
	local _ = arch
	sign(m, Vector3.new(finishX + 2, deckY + 11, 0), "🏁 FINISH  ➜  HOME", Color3.fromRGB(40, 170, 90))

	return {
		Key = key,
		Kind = "Obby",
		Start = checkpoints[1],
		Prompt = p,
		Target = Vector3.new(fromX - 10, deckY + 1, 0),
		WaterStart = nil,
		Checkpoints = checkpoints,
		CheckpointX = checkpointX,
		Finish = Vector3.new(finishX, deckY + 3, 0),
		Sweepers = sweepers,
		Faders = faders,
	}
end

-- landings = místa dopadu na ostrovech (z MapBuilderu), giantLanding = Obří dárek
function TrialCourses.Build(root: Instance, landings: { [string]: Vector3 }, giantLanding: Vector3): { [string]: Spot }
	local folder = Instance.new("Folder")
	folder.Name = "IslandTrials"
	folder.Parent = root
	local spots: { [string]: Spot } = {}
	local trials = TrialsConfig.Trials
	local bronze = landings.Bronze
	if bronze then
		-- západní břeh ostrova: střed je 60 za místem dopadu, poloměr 115
		spots.Bronze = canoeDock(folder, "Bronze", trials.Bronze.Name, bronze.X - 50, World.WaterY + 2.6)
	end
	local silver = landings.Silver
	if silver then
		spots.Silver = skyPath(folder, "Silver", trials.Silver.Name, silver.X - 50, World.WaterY + 4)
	end
	-- Obří dárek: lávka z ostrova končí 140 studů před místem dopadu
	spots.Giant = canoeDock(folder, "Giant", trials.Giant.Name, giantLanding.X - 140, giantLanding.Y + 0.15)
	return spots
end

return TrialCourses

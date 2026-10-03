--!strict
-- Slalom na cestě zpět k voru (od levelu 10). Rozložení posílá server ve SwimStart (info.Slalom):
-- branky = bariéry z bójek s jednou mezerou, překážky = kameny, medúzy, klády a ježíci.
-- Tady se slalom postaví, hýbe se pohyblivými brankami a překážkami a hlídá nárazy:
--  • bariéra: hráč nemůže proplavat jinudy než mezerou (zastaví se a chvíli nemůže dopředu),
--  • překážka: krátké omráčení a odhození o kus zpět.
-- Souřadnice ze serveru: X = vzdálenost od místa startu směrem k voru, Z = posun do strany od StartZ.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Swim = require(Shared.Config.Swim)
local Kit = require(script.Parent.Parent.UI.Kit)
local Sound = require(script.Parent.Parent.Sound)
local Effects = require(script.Parent.Parent.Effects.Effects)

local Slalom = {}

type GateData = { X: number, Z: number, Gap: number, Amp: number, Speed: number, Phase: number }
type ObstacleData = { Kind: string, X: number, Z: number, Amp: number, Speed: number, Phase: number }
type Layout = { Name: string, Color: Color3, Gates: { GateData }, Obstacles: { ObstacleData } }

type Gate = { Data: GateData, Model: Model, Passed: boolean, LastBump: number }
type Obstacle = { Data: ObstacleData, Model: Model, LastHit: number, Bob: number }

export type Run = {
	Layout: Layout,
	StartX: number,
	StartZ: number,
	Dir: number, -- 1 = plave se k −X (ke břehu), −1 = k +X (na moře)
	Y: number,
	Gates: { Gate },
	Obstacles: { Obstacle },
	StunUntil: number,
	Passed: number,
	Folder: Folder,
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
local function gateModel(parent: Instance, gap: number, color: Color3): Model
	local m = newModel("SlalomGate", parent)
	local half = gap / 2
	for _, side in { -1, 1 } do
		-- sloupek (střídavě barva slalomu a bílá)
		for k = 0, 3 do
			part(m, Vector3.new(1.6, 0.8, 0.8), CFrame.new(0, 0.8 + k * 1.6, side * half) * UP, if k % 2 == 0 then color else WHITE, nil, Enum.PartType.Cylinder)
		end
		part(m, Vector3.one * 1.3, CFrame.new(0, 7.1, side * half), color, Enum.Material.Neon, Enum.PartType.Ball)
		-- velká bójka u paty sloupku
		part(m, Vector3.one * 2.2, CFrame.new(0, 0.2, side * half), WHITE, nil, Enum.PartType.Ball)
		-- řada bójek na laně až daleko do stran (tudy se neproplave)
		local rope = part(m, Vector3.new(0.18, 0.18, 46), CFrame.new(0, 0.35, side * (half + 23)), Color3.fromRGB(240, 240, 240))
		rope.Material = Enum.Material.Fabric
		local z = half + 2.6
		local n = 0
		while z < half + 46 do
			part(m, Vector3.one * 1.3, CFrame.new(0, 0.3, side * z), if n % 2 == 0 then color else WHITE, nil, Enum.PartType.Ball)
			z += 3
			n += 1
		end
	end
	-- oblouk nad mezerou (svítící tyč) a praporky
	part(m, Vector3.new(0.35, 0.35, gap + 0.6), CFrame.new(0, 7.1, 0), color, Enum.Material.Neon)
	local flags = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 210, 60), Color3.fromRGB(90, 200, 255), Color3.fromRGB(120, 230, 120) }
	local count = math.max(3, math.floor(gap / 2.5))
	for k = 1, count do
		local z = -half + gap * k / (count + 1)
		local flag = Instance.new("WedgePart")
		flag.Anchored = true
		flag.CanCollide = false
		flag.CanQuery = false
		flag.CanTouch = false
		flag.CastShadow = false
		flag.Size = Vector3.new(0.1, 1.1, 0.9)
		flag.CFrame = CFrame.new(0, 6.3, z) * CFrame.Angles(math.pi, 0, 0)
		flag.Color = flags[k % #flags + 1]
		flag.Material = Enum.Material.Fabric
		flag.Parent = m
	end
	-- jemná záře v mezeře, ať je jasné, kudy plavat
	local glow = part(m, Vector3.new(0.2, 5.6, gap - 1.4), CFrame.new(0, 3.4, 0), color, Enum.Material.Neon)
	glow.Transparency = 0.82
	glow.Name = "Glow"
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

local BUILDERS: { [string]: (Instance) -> Model } = {
	Rock = rockModel,
	Jellyfish = jellyfishModel,
	Log = logModel,
	Puffer = pufferModel,
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

function Slalom.Start(layout: Layout, startX: number, startZ: number, y: number, parent: Instance, dir: number?): Run
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
		StunUntil = 0,
		Passed = 0,
		Folder = folder,
	}
	for _, g in layout.Gates do
		local model = gateModel(folder, g.Gap, layout.Color)
		table.insert(run.Gates, { Data = g, Model = model, Passed = false, LastBump = 0 })
	end
	for _, o in layout.Obstacles do
		local build = BUILDERS[o.Kind]
		if build then
			table.insert(run.Obstacles, { Data = o, Model = build(folder), LastHit = 0, Bob = math.random() * 6 })
		end
	end
	Slalom.Animate(run, 0)
	return run
end

function Slalom.Destroy(run: Run)
	run.Folder:Destroy()
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
		end
		obstacle.Model:PivotTo(cf)
	end
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
	-- branky: bariérou se neproplave, jen mezerou
	for _, gate in run.Gates do
		local g = gate.Data
		if not gate.Passed and prev < g.X and result >= g.X - 0.5 then
			local center = gateZ(g, t)
			if math.abs(z - center) <= g.Gap / 2 - PLAYER_HALF_WIDTH then
				gate.Passed = true
				run.Passed += 1
				Sound.Play("Ring", 1.2 + run.Passed * 0.08)
				Effects.FloatText(`GATE {run.Passed}/{#run.Gates}`, run.Layout.Color)
				local glow = gate.Model:FindFirstChild("Glow") :: BasePart?
				if glow then
					glow.Color = Kit.Colors.Green
					glow.Transparency = 0.6
				end
			else
				result = math.min(result, g.X - 1.2)
				if now - gate.LastBump > 0.7 then
					gate.LastBump = now
					run.StunUntil = math.max(run.StunUntil, now + Swim.Slalom.BumpStun)
					bumpEffect(run, result, z, "BUMP! Swim through the gap!", Kit.Colors.Orange)
				end
			end
		end
	end
	-- překážky: náraz = omráčení a odhození zpět
	for _, obstacle in run.Obstacles do
		local o = obstacle.Data
		local ex, ez = obstacleExtent(o.Kind)
		if now - obstacle.LastHit > 1 and math.abs(result - o.X) < ex + PLAYER_HALF_WIDTH and math.abs(z - obstacleZ(o, t)) < ez + PLAYER_HALF_WIDTH then
			obstacle.LastHit = now
			run.StunUntil = math.max(run.StunUntil, now + Swim.Slalom.HitStun)
			result = math.max(0, result - Swim.Slalom.KnockBack)
			local text = if o.Kind == "Jellyfish" then "ZAP! Jellyfish!" elseif o.Kind == "Puffer" then "OUCH! Pufferfish!" elseif o.Kind == "Log" then "BONK! Log!" else "BONK! Rock!"
			bumpEffect(run, result, z, text, Kit.Colors.Coral)
		end
	end
	return result
end

return Slalom

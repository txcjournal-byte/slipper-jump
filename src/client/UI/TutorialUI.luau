--!strict
-- Tutoriál: věta nahoře na obrazovce, velká šipka na zemi u hráče a skákající šipka nad cílem.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tutorial = require(Shared.Config.Tutorial)
local Net = require(Shared.Net)
local Kit = require(script.Parent.Kit)
local ClientState = require(script.Parent.Parent.ClientState)

local TutorialUI = {}

local player = Players.LocalPlayer
local banner: Frame
local bannerText: TextLabel
local groundArrow: Model
local targetArrow: Model
local YELLOW = Color3.fromRGB(255, 220, 60)

local function arrowModel(name: string, flat: boolean): Model
	local m = Instance.new("Model")
	m.Name = name
	local function add(p: BasePart)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Color = YELLOW
		p.Material = Enum.Material.Neon
		p.Parent = m
	end
	-- šipka míří na lokální -Z
	local shaft = Instance.new("Part")
	shaft.Size = if flat then Vector3.new(2.2, 0.2, 6) else Vector3.new(1.4, 1.4, 5)
	shaft.CFrame = CFrame.new(0, 0, 2.5)
	add(shaft)
	for _, side in { -1, 1 } do
		local head = Instance.new("WedgePart")
		-- dvě poloviny trojúhelníkového hrotu
		head.Size = Vector3.new(if flat then 0.2 else 1.4, 1.6, 3)
		head.CFrame = CFrame.new(side * 0.8, 0, -1.5) * CFrame.Angles(0, 0, math.rad(-90 * side))
		add(head)
	end
	m.PrimaryPart = shaft
	m.Parent = Workspace
	return m
end

local function findTarget(step: number): Vector3?
	local info = Tutorial.Steps[step]
	if not info then
		return nil
	end
	local target = info.Target
	if target == "Pier" then
		local zone = CollectionService:GetTagged("JumpZone")[1]
		if zone and zone:IsA("BasePart") then
			return zone.Position
		end
	elseif target == "House" then
		local map = Workspace:FindFirstChild("Map")
		local houses = map and map:FindFirstChild("Houses")
		if houses then
			for _, house in houses:GetChildren() do
				if house:GetAttribute("OwnerUserId") == player.UserId then
					local pad = house:FindFirstChild("CollectPad")
					if pad and pad:IsA("BasePart") then
						return pad.Position + Vector3.new(20, 0, 0)
					end
				end
			end
		end
	elseif target == "PiggyBank" then
		local houseIndex = ClientState.Get().HouseIndex
		for _, piggy in CollectionService:GetTagged("PiggyBank") do
			if piggy:IsA("BasePart") and piggy:GetAttribute("HouseIndex") == houseIndex then
				return piggy.Position
			end
		end
	elseif target == "Shop" then
		local shop = CollectionService:GetTagged("ShopStall")[1]
		if shop and shop:IsA("BasePart") then
			return shop.Position
		end
	end
	return nil
end

local function hideArrows()
	groundArrow:PivotTo(CFrame.new(0, -500, 0))
	targetArrow:PivotTo(CFrame.new(0, -500, 0))
end

function TutorialUI.Init(screen: ScreenGui)
	banner = Kit.Panel(screen, {
		-- užší a kousek doprava, ať na malých telefonech nepřekrývá peníze a level vlevo nahoře
		Size = UDim2.fromOffset(640, 84),
		Position = UDim2.new(0.5, 40, 0, 90),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Kit.Colors.Yellow,
		Visible = false,
		Radius = 22,
	})
	Kit.Gradient(banner, Color3.new(1, 1, 1), Color3.fromRGB(220, 220, 220))
	bannerText = Kit.Text(banner, { Text = "", Size = UDim2.new(1, -170, 1, -18), Position = UDim2.fromOffset(18, 9), StrokeThickness = 3 })
	Kit.Button(banner, { Text = "SKIP", Color = Kit.Colors.Coral, Size = UDim2.fromOffset(130, 58), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5) }, function()
		Net.Event("SkipTutorial"):FireServer()
	end)
	groundArrow = arrowModel("TutorialGroundArrow", true)
	targetArrow = arrowModel("TutorialTargetArrow", false)
	hideArrows()

	local lastStep = 0
	ClientState.Changed:Connect(function(data)
		local active = data.TutorialDone ~= true
		banner.Visible = active and not data.Flying
		if active and data.TutorialStep ~= lastStep then
			lastStep = data.TutorialStep
			local info = Tutorial.Steps[data.TutorialStep]
			bannerText.Text = `({data.TutorialStep}/{#Tutorial.Steps}) {if info then info.Text else ""}`
			Kit.Pop(banner, 1.1)
		end
		if not active then
			hideArrows()
		end
	end)

	RunService.RenderStepped:Connect(function()
		local data = ClientState.Data
		if not data or data.TutorialDone or data.Flying then
			return
		end
		local target = findTarget(data.TutorialStep)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not target or not root then
			hideArrows()
			return
		end
		local t = os.clock()
		targetArrow:PivotTo(CFrame.new(target + Vector3.new(0, 12 + math.sin(t * 4) * 1.5, 0)) * CFrame.Angles(0, t * 2, 0) * CFrame.Angles(math.rad(-90), 0, 0))
		local flat = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
		if flat.Magnitude < 14 then
			groundArrow:PivotTo(CFrame.new(0, -500, 0))
		else
			local dir = flat.Unit
			local pos = root.Position + dir * (7 + math.sin(t * 5) * 0.8) - Vector3.new(0, 2.8, 0)
			groundArrow:PivotTo(CFrame.lookAt(pos, pos + dir))
		end
	end)
end

return TutorialUI

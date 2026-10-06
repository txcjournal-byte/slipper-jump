--!strict
-- Spouštěč klienta: UI, ovládání skoku, efekty ve světě.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local ClientState = require(script.Parent.ClientState)
local Sound = require(script.Parent.Sound)
local Kit = require(script.Parent.UI.Kit)
local HUD = require(script.Parent.UI.HUD)
local Shop = require(script.Parent.UI.Shop)
local SpinnerUI = require(script.Parent.UI.SpinnerUI)
local RobuxShop = require(script.Parent.UI.RobuxShop)
local Settings = require(script.Parent.UI.Settings)
local Dialogs = require(script.Parent.UI.Dialogs)
local TutorialUI = require(script.Parent.UI.TutorialUI)
local QuestsUI = require(script.Parent.UI.QuestsUI)
local Offers = require(script.Parent.UI.Offers)
local SellUI = require(script.Parent.UI.SellUI)
local TestPanel = require(script.Parent.UI.TestPanel)
local TrialUI = require(script.Parent.UI.TrialUI)
local LegendRaceUI = require(script.Parent.UI.LegendRaceUI)
local Effects = require(script.Parent.Effects.Effects)
local JumpController = require(script.Parent.Controllers.JumpController)
local WorldController = require(script.Parent.Controllers.WorldController)
local SeaLifeController = require(script.Parent.Controllers.SeaLifeController)
local DuelController = require(script.Parent.Controllers.DuelController)

ClientState.Start()
Sound.Start()
Effects.Init()
HUD.Init()

local windows = Kit.Screen("Windows", 20)
Shop.Init(windows)
SpinnerUI.Init(windows)
RobuxShop.Init(windows)
Settings.Init(windows)
QuestsUI.Init(windows)
SellUI.Init(windows)
TestPanel.Init(windows, HUD.Screen())
TrialUI.Init(HUD.Screen())
LegendRaceUI.Init()
Dialogs.Init()
TutorialUI.Init(HUD.Screen())
Offers.Init(HUD.Screen())
JumpController.Init(Kit.Screen("Jump", 8))
WorldController.Init()
SeaLifeController.Init()
DuelController.Init()

HUD.Bind("Inventory", Shop.Toggle)
HUD.Bind("Spinner", SpinnerUI.Toggle)
HUD.Bind("RobuxShop", RobuxShop.Toggle)
HUD.Bind("Settings", Settings.Toggle)
HUD.Bind("Rebirth", Dialogs.ConfirmRebirth)
HUD.Bind("Quests", QuestsUI.Toggle)
HUD.Bind("TeleportHouse", function()
	Net.Event("Teleport"):FireServer("House")
end)
HUD.Bind("TeleportPier", function()
	Net.Event("Teleport"):FireServer("Pier")
	-- server postaví hráče na konec mola čelem k moři; kamera se otočí za něj, ať vidí vodu a může hned skočit
	task.spawn(function()
		local World = require(Shared.Config.World)
		local player = game:GetService("Players").LocalPlayer
		local deadline = os.clock() + 2
		while os.clock() < deadline do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and root.Position.X > World.PierEndX - 40 and math.abs(root.Position.Z) < 12 then
				local camera = workspace.CurrentCamera
				if camera then
					local at = root.Position
					camera.CFrame = CFrame.lookAt(at + Vector3.new(-16, 7, 0), at + Vector3.new(20, 2, 0))
				end
				return
			end
			task.wait()
		end
	end)
end)
HUD.Bind("TeleportSell", function()
	Net.Event("Teleport"):FireServer("Sell")
end)
HUD.Bind("StarterPack", function()
	RobuxShop.Prompt("StarterPack")
end)
Net.Event("ServerEvent").OnClientEvent:Connect(function(info)
	HUD.SetServerEvent(info)
end)
Net.Event("ContestBoard").OnClientEvent:Connect(function(info)
	HUD.SetContestBoard(info)
end)

Net.Event("Notify").OnClientEvent:Connect(function(text: string, kind: string?)
	HUD.Notify(text, kind)
end)
Net.Event("Announce").OnClientEvent:Connect(function(text: string, kind: string?)
	HUD.Announce(text, kind)
end)
Net.Event("OpenUI").OnClientEvent:Connect(function(name: string, info: any)
	if name == "Shop" then
		Shop.Open(true, "Slippers")
	elseif name == "Sell" then
		SellUI.Open()
	elseif name == "Spinner" then
		SpinnerUI.Open()
	elseif name == "GiftOpened" then
		Dialogs.GiftOpened(info)
	elseif name == "DailyReward" then
		Dialogs.Info("DAY " .. info.Streak .. " STREAK!", "Daily reward: $" .. info.Money .. (if info.Spins > 0 then " + " .. info.Spins .. " Spin" .. (if info.Spins > 1 then "s" else "") else "") .. ". Your daily quests are ready!", Kit.Colors.Orange)
	end
end)

-- data žebříčku ukazuje tabule ve světě; posluchač jen kvůli frontě zpráv
Net.Event("Leaderboard").OnClientEvent:Connect(function() end)

-- načítací obrazovka (ReplicatedFirst) zmizí, až je UI postavené a přišla data hráče
local function markReady()
	game:GetService("Players").LocalPlayer:SetAttribute("SlipperJumpReady", true)
end
if ClientState.Data then
	markReady()
else
	ClientState.Loaded:Connect(markReady)
end

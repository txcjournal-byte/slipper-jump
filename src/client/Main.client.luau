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
local Effects = require(script.Parent.Effects.Effects)
local JumpController = require(script.Parent.Controllers.JumpController)
local WorldController = require(script.Parent.Controllers.WorldController)

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
Dialogs.Init()
TutorialUI.Init(HUD.Screen())
JumpController.Init(Kit.Screen("Jump", 8))
WorldController.Init()

HUD.Bind("Inventory", Shop.Toggle)
HUD.Bind("Spinner", SpinnerUI.Toggle)
HUD.Bind("RobuxShop", RobuxShop.Toggle)
HUD.Bind("Settings", Settings.Toggle)
HUD.Bind("Rebirth", Dialogs.ConfirmRebirth)
HUD.Bind("Quests", QuestsUI.Toggle)
HUD.Bind("StarterPack", function()
	RobuxShop.Prompt("StarterPack")
end)
Net.Event("ServerEvent").OnClientEvent:Connect(function(info)
	HUD.SetServerEvent(info)
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

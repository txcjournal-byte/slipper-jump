--!strict
-- Spouštěč serveru: postaví mapu a spustí všechny služby.

local Registry = require(script.Parent.Registry)
local MapBuilder = require(script.Parent.MapBuilder)

require(script.Parent.Atmosphere).Apply()
Registry.Map = MapBuilder.Build()

local services: { [string]: any } = {
	Player = require(script.Parent.PlayerService),
	Economy = require(script.Parent.EconomyService),
	House = require(script.Parent.HouseService),
	Items = require(script.Parent.ItemService),
	Avatar = require(script.Parent.AvatarService),
	Jump = require(script.Parent.JumpService),
	Shop = require(script.Parent.ShopService),
	Gifting = require(script.Parent.GiftService),
	Spinner = require(script.Parent.SpinnerService),
	Level = require(script.Parent.LevelService),
	Rebirth = require(script.Parent.RebirthService),
	Leaderboard = require(script.Parent.LeaderboardService),
	Codes = require(script.Parent.CodeService),
	Tutorial = require(script.Parent.TutorialService),
	Monetization = require(script.Parent.MonetizationService),
	Data = require(script.Parent.DataService),
	Swim = require(script.Parent.SwimService),
	ServerEvents = require(script.Parent.ServerEventService),
	LegendRace = require(script.Parent.LegendRaceService),
	Duels = require(script.Parent.DuelService),
	Quests = require(script.Parent.QuestService),
	TestPanel = require(script.Parent.TestPanelService),
	Trials = require(script.Parent.TrialService),
}

for name, service in services do
	Registry[name] = service
end

-- Init (vytvoření remotů, kolizních skupin) → Start (připojení událostí)
for _, service in services do
	local init = (service :: any).Init
	if init then
		init()
	end
end
for name, service in services do
	if name ~= "Player" then
		local start = (service :: any).Start
		if start then
			start()
		end
	end
end
-- hráče připojit až nakonec, když vše ostatní běží
services.Player.Start()

print("[Slipper Jump: Island Legend] Server ready")

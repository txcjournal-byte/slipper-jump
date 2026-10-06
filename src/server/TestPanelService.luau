--!strict
-- Testovací panel – funguje JEN ve Studiu (ve zveřejněné hře server tyhle požadavky ignoruje).
-- Klient (UI/TestPanel) posílá: spustit událost, nastavit level, přidat peníze, dát pantofle, plavání, štíty.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog = require(Shared.Catalog)
local Swim = require(Shared.Config.Swim)
local Levels = require(Shared.Config.Levels)
local FormatNumber = require(Shared.Util.FormatNumber)
local Net = require(Shared.Net)

local Registry = require(script.Parent.Registry)

local TestPanelService = {}

function TestPanelService.Start()
	Net.Event("StudioTest").OnServerEvent:Connect(function(player, action, value)
		if not RunService:IsStudio() or type(action) ~= "string" then
			return
		end
		local session = Registry.Player.Get(player)
		if not session then
			return
		end
		local data = session.Data
		local message: string
		if action == "Event" and type(value) == "string" then
			message = if Registry.ServerEvents.ForceStart(value) then "Event started: " .. value else "An event is already running - wait until it ends."
		elseif action == "Level" and type(value) == "number" then
			data.Level = math.clamp(math.floor(value), 1, Levels.MaxLevel)
			data.XP = 0
			Registry.House.Render(session)
			Registry.Avatar.UpdateOverhead(session)
			message = "Level set to " .. data.Level
		elseif action == "Money" and type(value) == "number" then
			Registry.Economy.AddMoney(session, math.max(0, value))
			message = "+" .. FormatNumber.Money(value)
		elseif action == "Slippers" and type(value) == "string" and Catalog.Slipper(value) then
			if not table.find(data.OwnedSlippers, value) then
				table.insert(data.OwnedSlippers, value)
			end
			data.EquippedSlippers = value
			data.EquippedSkin = "" -- ať jsou pantofle vidět (ne skin tenisek)
			Registry.Avatar.ApplySlippers(session)
			message = "Wearing " .. value
		elseif action == "Swim" and type(value) == "number" then
			data.SwimLevel = math.clamp(math.floor(value), 0, #Swim.Upgrades)
			message = "Swim gear level " .. data.SwimLevel
		elseif action == "Shields" then
			data.Shields += 5
			message = "+5 Bubble Shields"
		elseif action == "Items" then
			for _, rarity in { "Common", "Common", "Uncommon", "Rare", "Epic", "Legendary" } do
				Registry.Items.GiveRandom(session, rarity)
			end
			message = "+6 random items"
		elseif action == "Trial" and (value == "Bronze" or value == "Silver" or value == "Giant") then
			-- přenést na ostrov a nabídnout úkol na cestu domů
			local landing = if value == "Giant" then Registry.Map.GiftLanding else Registry.Map.IslandLandings[value]
			local character = player.Character
			if character and landing then
				if session.Flight or session.Swim then
					return
				end
				-- úkol nejdřív, ať hráče hlídač hranic mezitím nevrátí na pláž
				Registry.Trials.Offer(session, value)
				character:PivotTo(CFrame.new(landing + Vector3.new(0, 4, 0)))
			end
			message = "Island challenge: " .. value
		elseif action == "HouseTier" and type(value) == "number" then
			Registry.House.SetTier(session, value)
			message = "House tier " .. data.HouseTier
		elseif action == "SlalomStyle" and type(value) == "string" then
			Registry.Swim.ForceStyle(if value == "Random" then nil else value)
			message = "Next slaloms: " .. value
		elseif action == "LegendRace" then
			message = if Registry.LegendRace.ForceStart() then "LEGEND RACE starting!" else "A race is already running."
		elseif action == "ResetGifts" then
			data.ClaimedGifts = {}
			message = "Gift islands reset"
		else
			return
		end
		Registry.Player.MarkDirty(session)
		Registry.Player.Notify(player, "[TEST] " .. message, "Success")
	end)
end

return TestPanelService

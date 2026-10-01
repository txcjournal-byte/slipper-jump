--!strict
-- Události na serveru každých pár minut: Golden Rings, Coin Storm, Treasure Tide,
-- Shark Holiday, Mega Jump. Oznámí se předem, běží omezenou dobu.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Events = require(Shared.Config.Events)
local Net = require(Shared.Net)

local Registry = require(script.Parent.Registry)

local ServerEventService = {}

local active: Events.ServerEvent? = nil
local endsAt = 0

local function payload(): { [string]: any }?
	if not active then
		return nil
	end
	return { Kind = active.Kind, Name = active.Name, Description = active.Description, Color = active.Color, EndsAt = endsAt }
end

function ServerEventService.IsActive(kind: string): boolean
	return active ~= nil and active.Kind == kind
end

function ServerEventService.SendTo(player: Player)
	Net.Event("ServerEvent"):FireClient(player, payload())
end

function ServerEventService.Start()
	Players.PlayerAdded:Connect(function(player)
		task.wait(3)
		if player.Parent then
			ServerEventService.SendTo(player)
		end
	end)
	task.spawn(function()
		local last: Events.ServerEvent? = nil
		while true do
			task.wait(Events.ServerEventInterval - Events.ServerEventWarning)
			local choices = {}
			for _, event in Events.ServerEvents do
				if event ~= last then
					table.insert(choices, event)
				end
			end
			local nextEvent = choices[math.random(1, #choices)]
			Registry.Player.Announce(`{nextEvent.Name} starts in {Events.ServerEventWarning} seconds! Get to the pier!`, "Info")
			task.wait(Events.ServerEventWarning)
			active = nextEvent
			last = nextEvent
			endsAt = os.time() + Events.ServerEventDuration
			Registry.Player.Announce(`{nextEvent.Name}! {nextEvent.Description}`, "Gift")
			Net.Event("ServerEvent"):FireAllClients(payload())
			task.wait(Events.ServerEventDuration)
			active = nil
			Net.Event("ServerEvent"):FireAllClients(nil)
		end
	end)
end

return ServerEventService

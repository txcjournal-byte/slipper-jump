--!strict
-- Poslední stav hráče od serveru + signál při změně.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

local ClientState = {}

ClientState.Data = nil :: { [string]: any }?
ClientState.Changed = Signal.new() :: Signal.Signal<{ [string]: any }>
ClientState.Loaded = Signal.new() :: Signal.Signal<{ [string]: any }>

-- rozdíl mezi časem serveru a klienta (pro odpočty)
local timeOffset = 0

function ClientState.ServerNow(): number
	return os.time() + timeOffset
end

function ClientState.Get(): { [string]: any }
	return ClientState.Data or {}
end

function ClientState.Start()
	Net.Event("State").OnClientEvent:Connect(function(state: { [string]: any })
		local first = ClientState.Data == nil
		timeOffset = (state.ServerTime or os.time()) - os.time()
		ClientState.Data = state
		if first then
			ClientState.Loaded:Fire(state)
		end
		ClientState.Changed:Fire(state)
	end)
end

return ClientState

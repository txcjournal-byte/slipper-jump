--!strict
-- Plavání zpět: po dopadu hráč plave k záchrannému voru a honí ho žralok.
-- O výsledku rozhoduje server podle pozic, které vidí (klient jen hýbe postavou a kreslí žraloka).
-- Doplave → bonus. Chytí ho žralok → jen přijde o bonus.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Swim = require(Shared.Config.Swim)
local World = require(Shared.Config.World)
local Formulas = require(Shared.Formulas)
local Net = require(Shared.Net)

local Registry = require(script.Parent.Registry)

type Session = any

export type SwimState = {
	Flight: any,
	StartClock: number,
	StartX: number,
	Distance: number,
	Speed: number,
	SharkSpeed: number,
	NoShark: boolean,
	Done: boolean,
}

local SwimService = {}

local startEvent: RemoteEvent
local resultEvent: RemoteEvent

local function returnLater(session: Session, flight: any)
	task.delay(Swim.ReturnDelay, function()
		if session.Flight == flight then
			session.Flight = nil
			session.Swim = nil
			Registry.Player.ReturnToBeach(session)
			Registry.Player.MarkDirty(session)
		end
	end)
end

local function finish(session: Session, state: SwimState, success: boolean, reason: string)
	if state.Done then
		return
	end
	state.Done = true
	local bonus = 0
	if success then
		bonus = math.max(Swim.BonusMin, math.floor(Registry.Economy.IncomePerSecond(session) * Swim.BonusSeconds))
		Registry.Economy.AddMoney(session, bonus)
		if not state.NoShark then
			Registry.Quests.Progress(session, "Escapes", 1)
		end
	end
	resultEvent:FireClient(session.Player, { Success = success, Reason = reason, Bonus = bonus })
	returnLater(session, state.Flight)
end

-- Zavolá JumpService po dopadu do vody
function SwimService.Begin(session: Session, flight: any, landDistance: number)
	if session.Flight ~= flight then
		return
	end
	local root = Registry.Player.GetRoot(session.Player)
	if not root then
		returnLater(session, flight)
		return
	end
	local data = session.Data
	local noShark = data.TotalJumps <= Swim.NoSharkFirstJumps or Registry.ServerEvents.IsActive("SharkHoliday")
	local usedRepellent = false
	if not noShark and data.Repellents > 0 then
		data.Repellents -= 1
		noShark = true
		usedRepellent = true
	end
	local state: SwimState = {
		Flight = flight,
		StartClock = os.clock(),
		StartX = root.Position.X,
		Distance = Swim.Distance,
		Speed = Formulas.SwimSpeed(data.SwimLevel, session.Passes.TurboFins == true),
		SharkSpeed = Formulas.SharkSpeed(landDistance),
		NoShark = noShark,
		Done = false,
	}
	session.Swim = state
	Registry.Player.MarkDirty(session)
	startEvent:FireClient(session.Player, {
		StartX = state.StartX,
		StartZ = root.Position.Z,
		Y = World.WaterY,
		Distance = state.Distance,
		Speed = state.Speed,
		SharkSpeed = state.SharkSpeed,
		SharkDelay = Swim.SharkDelay,
		NoShark = noShark,
		UsedRepellent = usedRepellent,
		MaxTime = Swim.MaxTime,
		CanUpgrade = data.SwimLevel < #Swim.Upgrades,
	})
end

function SwimService.Init()
	startEvent = Net.Event("SwimStart")
	resultEvent = Net.Event("SwimResult")
end

function SwimService.Start()
	RunService.Heartbeat:Connect(function()
		for _, session in Registry.Player.Sessions do
			local state: SwimState? = session.Swim
			if state and not state.Done then
				local elapsed = os.clock() - state.StartClock
				local root = Registry.Player.GetRoot(session.Player)
				if not root then
					finish(session, state, false, "Lost")
				else
					-- postup k voru (nemůže být rychlejší, než dovolí rychlost plavání)
					local progress = math.clamp(state.StartX - root.Position.X, 0, state.Speed * elapsed * 1.15 + 4)
					local shark = Formulas.SharkProgress(elapsed, state.SharkSpeed)
					if progress >= state.Distance then
						finish(session, state, true, "Safe")
					elseif not state.NoShark and elapsed > Swim.SharkDelay and shark >= progress - Swim.CatchDistance then
						finish(session, state, false, "Shark")
					elseif elapsed > Swim.MaxTime then
						finish(session, state, false, "Timeout")
					end
				end
			end
		end
	end)
end


return SwimService

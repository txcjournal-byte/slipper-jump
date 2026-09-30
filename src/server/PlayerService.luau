--!strict
-- Příchod a odchod hráčů, session, odesílání stavu klientovi, leaderstats,
-- návrat na pláž a hlídání, aby hráč nevlezl do vody bez skoku.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local World = require(Shared.Config.World)
local Spinner = require(Shared.Config.Spinner)
local Economy = require(Shared.Config.Economy)
local Formulas = require(Shared.Formulas)
local Net = require(Shared.Net)

local Registry = require(script.Parent.Registry)
local DataService = require(script.Parent.DataService)

export type Session = {
	Player: Player,
	Profile: any,
	Data: DataService.Data,
	House: any?, -- MapBuilder.HouseInfo
	Passes: { [string]: boolean },
	Flight: any?, -- JumpService.Flight
	Charge: { Start: number, Period: number }?,
	LastJump: number,
	Returning: boolean,
	Dirty: boolean,
	Loaded: boolean,
	LastCollect: number,
	LastTeleport: number,
	Leaderstats: { Money: NumberValue, Level: IntValue, Best: NumberValue }?,
}

local PlayerService = {}
PlayerService.Sessions = {} :: { [Player]: Session }

local stateEvent: RemoteEvent
local notifyEvent: RemoteEvent
local announceEvent: RemoteEvent

function PlayerService.Get(player: Player): Session?
	local session = PlayerService.Sessions[player]
	if session and session.Loaded then
		return session
	end
	return nil
end

function PlayerService.MarkDirty(session: Session)
	session.Dirty = true
end

function PlayerService.Notify(player: Player, text: string, kind: string?)
	notifyEvent:FireClient(player, text, kind or "Info")
end

function PlayerService.Announce(text: string, kind: string?)
	announceEvent:FireAllClients(text, kind or "Info")
end

function PlayerService.GetRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function PlayerService.SpinStatus(session: Session): (number, number)
	local data = session.Data
	local now = os.time()
	local dailyMax = Spinner.DailySpins + (if session.Passes.VIP then Spinner.VipDailySpins else 0)
	local periodOver = now - data.DailyPeriodStart >= Spinner.Cooldown
	local available = if periodOver then dailyMax else math.max(0, dailyMax - data.DailySpinsUsed)
	local nextFree = if periodOver then now else data.DailyPeriodStart + Spinner.Cooldown
	return available, nextFree
end

-- Snapshot pro klienta (UI)
function PlayerService.BuildState(session: Session): { [string]: any }
	local data = session.Data
	local economy = Registry.Economy
	local dailyAvailable, nextFree = PlayerService.SpinStatus(session)
	local slotsTotal = Formulas.TotalSlots(data.Level, session.Passes.PlusSlots == true)
	local slotsUsed = 0
	for _ in data.HouseSlots do
		slotsUsed += 1
	end
	local day = os.time() // 86400
	return {
		Money = data.Money,
		PendingCash = data.PendingCash,
		IncomePerSecond = economy.IncomePerSecond(session),
		Multiplier = economy.Multiplier(session),
		Level = data.Level,
		XP = data.XP,
		XPToNext = Formulas.XPToNext(data.Level),
		Rebirths = data.Rebirths,
		OwnedSlippers = data.OwnedSlippers,
		EquippedSlippers = data.EquippedSlippers,
		OwnedHats = data.OwnedHats,
		EquippedHat = data.EquippedHat,
		Carried = data.Carried,
		Storage = data.Storage,
		SlotsTotal = slotsTotal,
		SlotsUsed = slotsUsed,
		BestJump = data.BestJump,
		DailySpins = dailyAvailable,
		NextFreeSpin = nextFree,
		ExtraSpins = data.ExtraSpins,
		BoostUntil = data.BoostUntil,
		TutorialDone = data.TutorialDone,
		TutorialStep = data.TutorialStep,
		Settings = data.Settings,
		Passes = session.Passes,
		Discovered = data.Discovered,
		CanRebirth = data.GiftOpenedThisLife,
		Title = data.Title,
		HouseIndex = if session.House then session.House.Index else 0,
		SuperJumps = data.SuperJumps,
		GiftsLeftToday = Economy.GiftsPerDay - (if data.GiftsSentDay == day then data.GiftsSentToday else 0),
		ServerTime = os.time(),
		Flying = session.Flight ~= nil,
	}
end

function PlayerService.SendState(session: Session)
	session.Dirty = false
	stateEvent:FireClient(session.Player, PlayerService.BuildState(session))
	local stats = session.Leaderstats
	if stats then
		stats.Money.Value = session.Data.Money
		stats.Level.Value = session.Data.Level
		stats.Best.Value = math.floor(session.Data.BestJump)
	end
end

local function createLeaderstats(session: Session)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local money = Instance.new("NumberValue")
	money.Name = "Money"
	money.Parent = folder
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Parent = folder
	local best = Instance.new("NumberValue")
	best.Name = "Best Jump"
	best.Parent = folder
	folder.Parent = session.Player
	session.Leaderstats = { Money = money, Level = level, Best = best }
end

-- Návrat na pláž (začátek cesty k molu)
function PlayerService.ReturnToBeach(session: Session)
	local character = session.Player.Character
	if not character then
		return
	end
	local map = Registry.Map
	local offset = Vector3.new(math.random(-3, 3), 0, math.random(-4, 4))
	character:PivotTo(map.Spawn + offset)
	local root = PlayerService.GetRoot(session.Player)
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
	session.Returning = false
end

local function onPlayerAdded(player: Player)
	local profile = DataService.Load(player)
	if not profile then
		return
	end
	local session: Session = {
		Player = player,
		Profile = profile,
		Data = profile.Data,
		House = nil,
		Passes = {},
		Flight = nil,
		Charge = nil,
		LastJump = 0,
		Returning = false,
		Dirty = true,
		Loaded = false,
		LastCollect = 0,
		LastTeleport = 0,
		Leaderstats = nil,
	}
	PlayerService.Sessions[player] = session
	Registry.Monetization.LoadPasses(session)
	createLeaderstats(session)
	Registry.House.Assign(session)
	Registry.Items.OnJoin(session)
	session.Loaded = true
	Registry.Economy.ApplyOffline(session)
	Registry.Avatar.OnSessionLoaded(session)
	Registry.Tutorial.OnJoin(session)
	PlayerService.SendState(session)
	Registry.Leaderboard.SendTo(player)
	-- jen pro testování ve Studiu: game.Players.<jméno>:SetAttribute("DevMoney", 1e9) v Command Baru (Server)
	if RunService:IsStudio() then
		player:GetAttributeChangedSignal("DevMoney"):Connect(function()
			local amount = player:GetAttribute("DevMoney")
			if type(amount) == "number" and amount > 0 then
				Registry.Economy.AddMoney(session, amount)
				player:SetAttribute("DevMoney", nil)
			end
		end)
	end
end

local function onPlayerRemoving(player: Player)
	local session = PlayerService.Sessions[player]
	PlayerService.Sessions[player] = nil
	if session then
		session.Data.LastLogout = os.time()
		Registry.Gifting.OnLeave(player)
		Registry.House.Release(session)
		Registry.Leaderboard.OnLeave(session)
	end
	DataService.Release(player)
end

-- Kdo se bez skoku dostane do vody nebo za konec mola, vrátí se na pláž
local function boundsLoop()
	while true do
		task.wait(0.5)
		for _, session in PlayerService.Sessions do
			if session.Loaded and not session.Flight and not session.Returning then
				local root = PlayerService.GetRoot(session.Player)
				if root then
					local pos = root.Position
					-- stojí na vodě (HRP je nad pískem i molem výš než hladina + 4,5)
					local inWater = pos.Y < World.WaterY + 4.5 or pos.X > World.OutOfBoundsX
					if inWater or math.abs(pos.Z) > World.BeachHalfWidth + 150 or pos.X < World.BeachBackX - 150 then
						PlayerService.ReturnToBeach(session)
					end
					Registry.Tutorial.CheckPosition(session, pos)
				end
			end
		end
	end
end

function PlayerService.Init()
	stateEvent = Net.Event("State")
	notifyEvent = Net.Event("Notify")
	announceEvent = Net.Event("Announce")
end

function PlayerService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	-- odesílání změněného stavu (max. 4× za sekundu)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.25 then
			return
		end
		accumulator = 0
		for _, session in PlayerService.Sessions do
			if session.Loaded and session.Dirty then
				PlayerService.SendState(session)
			end
		end
	end)
	task.spawn(boundsLoop)

	Net.Event("SetSetting").OnServerEvent:Connect(function(player, key, value)
		local session = PlayerService.Get(player)
		if session and (key == "Music" or key == "Sfx") and type(value) == "boolean" then
			session.Data.Settings[key] = value
			PlayerService.MarkDirty(session)
		end
	end)
end

return PlayerService

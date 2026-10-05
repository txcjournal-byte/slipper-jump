--!strict
-- Úkoly na cestu zpět z dárkových ostrovů (Bronze = kánoe, Silver = dráha nad mořem, Obří dárek = bouřková kánoe).
-- Po doskoku na ostrov a otevření dárku zůstane hráč na ostrově a dostane nabídku úkolu:
--   START (zdarma) • EASY PATH (Robux) • SKIP + BONUS (Robux) • GO HOME (zdarma, bez bonusu).
-- Dárek už má – úkol je jen bonus. Neúspěch = zkusit znovu (nebo jít domů).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local TrialsConfig = require(Shared.Config.Trials)
local World = require(Shared.Config.World)
local Swim = require(Shared.Config.Swim)
local FormatNumber = require(Shared.Util.FormatNumber)
local Net = require(Shared.Net)

local Registry = require(script.Parent.Registry)

type Session = any

export type TrialState = {
	Key: string,
	State: string, -- "Offer" | "Canoe" | "Obby" | "Done"
	Fails: number,
	Easy: boolean,
	Checkpoint: number,
	LastSafe: CFrame?,
	LastSafeAt: number,
	Character: Model?,
	Busy: boolean, -- právě se teleportuje / vyhodnocuje
}

local TrialService = {}

local offerEvent: RemoteEvent
local stateEvent: RemoteEvent

local function spot(key: string): any
	return Registry.Map.Trials[key]
end

local function bonusMoney(session: Session, key: string): number
	local cfg = TrialsConfig.Trials[key]
	return math.max(cfg.MinMoney, math.floor(Registry.Economy.IncomePerSecond(session) * cfg.MoneySeconds))
end

-- Pošle klientovi nabídku (panel s tlačítky a šipku ke startu)
local function sendOffer(session: Session, failed: boolean)
	local trial: TrialState = session.Trial
	local cfg = TrialsConfig.Trials[trial.Key]
	local s = spot(trial.Key)
	offerEvent:FireClient(session.Player, {
		Key = trial.Key,
		Name = cfg.Name,
		Icon = cfg.Icon,
		Kind = cfg.Kind,
		Description = cfg.Description,
		Money = bonusMoney(session, trial.Key),
		Spins = cfg.Spins,
		Title = cfg.Title,
		Target = s and s.Target,
		Fails = trial.Fails,
		Failed = failed,
		Easy = trial.Easy,
	})
end

local function clear(session: Session)
	session.Trial = nil
	stateEvent:FireClient(session.Player, { State = "End" })
end

-- Domů na pláž (s krátkou zatmívačkou na klientovi)
local function sendHome(session: Session, delay: number)
	task.delay(delay, function()
		if session.Flight and session.Flight.Trial then
			session.Flight = nil
		end
		session.Swim = nil
		Registry.Player.ReturnToBeach(session)
		Registry.Player.MarkDirty(session)
	end)
end

-- Zavolá JumpService po doskoku na ostrov (a otevření dárku)
function TrialService.Offer(session: Session, key: string)
	if not TrialsConfig.Trials[key] or not spot(key) then
		Registry.Player.ReturnToBeach(session)
		return
	end
	session.Trial = {
		Key = key,
		State = "Offer",
		Fails = 0,
		Easy = false,
		Checkpoint = 1,
		LastSafe = nil,
		LastSafeAt = 0,
		Character = session.Player.Character,
		Busy = false,
	} :: TrialState
	sendOffer(session, false)
end

-- Úkol splněn: bonus a domů
function TrialService.Complete(session: Session, homeDelay: number?, skipped: boolean?)
	local trial: TrialState? = session.Trial
	if not trial or trial.State == "Done" then
		return
	end
	trial.State = "Done"
	local cfg = TrialsConfig.Trials[trial.Key]
	local money = bonusMoney(session, trial.Key)
	Registry.Economy.AddMoney(session, money)
	Registry.Spinner.AddSpins(session, cfg.Spins)
	local rewards = { FormatNumber.Money(money), `{cfg.Spins} Spins` }
	if cfg.Title then
		Registry.Level.AddTitle(session, cfg.Title)
		table.insert(rewards, `Title "{cfg.Title}"`)
	end
	Registry.Player.MarkDirty(session)
	if not skipped then
		-- (přeskočení za Robux se celému serveru nehlásí – úkol hráč nesplnil)
		Registry.Player.Announce(`{session.Player.DisplayName} completed the {cfg.Name}!`, "Record")
	end
	stateEvent:FireClient(session.Player, { State = "Complete", Name = cfg.Name, Icon = cfg.Icon, Rewards = rewards })
	session.Trial = nil
	sendHome(session, homeDelay or 2.2)
end

-- Vzdát úkol bez přesunu (hráč se teleportuje tlačítkem HOUSE / PIER / SELL – přesun řeší PlayerService)
function TrialService.Abandon(session: Session)
	if not session.Trial then
		return
	end
	if session.Swim and session.Swim.Trial then
		session.Swim.Done = true
		session.Swim = nil
	end
	if session.Flight and session.Flight.Trial then
		session.Flight = nil
	end
	clear(session)
end

-- Domů bez bonusu (tlačítko GO HOME, teleport tlačítky, odchod)
function TrialService.GoHome(session: Session)
	if not session.Trial then
		return
	end
	if session.Swim and session.Swim.Trial then
		session.Swim.Done = true
	end
	clear(session)
	sendHome(session, 0.4)
end

-- Kánoe dojela (SwimService)
function TrialService.OnCanoeFinished(session: Session, success: boolean)
	local trial: TrialState? = session.Trial
	if not trial then
		return
	end
	if success then
		task.delay(Swim.ReturnDelay - 0.2, function()
			if session.Trial == trial then
				-- (klient má právě zatmívačku – rovnou domů)
				TrialService.Complete(session, 0)
			end
		end)
		return
	end
	local character = session.Player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character ~= trial.Character or not humanoid or humanoid.Health <= 0 then
		-- resetoval se během závodu (nebo právě umírá) → objeví se na pláži, úkol končí
		clear(session)
		if session.Flight and session.Flight.Trial then
			session.Flight = nil
		end
		session.Swim = nil
		return
	end
	-- nevyšlo: zpátky na molo s kánoí a zkusit znovu
	-- (až klient za tmou přestane řídit kánoi – jinak by hráče hned vrátil zpátky na vodu)
	trial.Fails += 1
	trial.State = "Offer"
	task.delay(Swim.ReturnDelay + 0.3, function()
		if session.Trial ~= trial then
			return
		end
		if session.Flight and session.Flight.Trial then
			session.Flight = nil
		end
		session.Swim = nil
		local character = session.Player.Character
		local s = spot(trial.Key)
		if character and s then
			character:PivotTo(s.Start)
		end
		sendOffer(session, true)
	end)
end

local function start(session: Session)
	local trial: TrialState? = session.Trial
	if not trial or trial.State ~= "Offer" or trial.Busy then
		return
	end
	local cfg = TrialsConfig.Trials[trial.Key]
	local s = spot(trial.Key)
	local character = session.Player.Character
	if not s or not character then
		return
	end
	if cfg.Kind == "Canoe" and cfg.Canoe and s.WaterStart then
		trial.State = "Canoe"
		character:PivotTo(CFrame.lookAt(s.WaterStart + Vector3.new(0, 2.6, 0), s.WaterStart + Vector3.new(-10, 2.6, 0)))
		stateEvent:FireClient(session.Player, { State = "Running", Kind = "Canoe" })
		local ok = Registry.Swim.StartTrial(session, trial.Key, cfg.Canoe, trial.Easy, s.WaterStart)
		if not ok then
			trial.State = "Offer"
			sendOffer(session, false)
		end
	else
		trial.State = "Obby"
		trial.Checkpoint = 1
		trial.LastSafe = nil
		character:PivotTo(s.Start)
		stateEvent:FireClient(session.Player, { State = "Running", Kind = "Obby", Checkpoint = 1, Total = #s.Checkpoints, Easy = trial.Easy })
	end
end

-- Robux: Easy Path (na tento úkol)
function TrialService.ApplyEasy(session: Session): boolean
	local trial: TrialState? = session.Trial
	if not trial then
		return false
	end
	trial.Easy = true
	Registry.Player.Notify(session.Player, "Easy Path active! Wider gates, slower chaser, and you respawn right where you fell.", "Success")
	if trial.State == "Offer" then
		sendOffer(session, false)
	else
		stateEvent:FireClient(session.Player, { State = "Easy" })
	end
	return true
end

-- Robux: přeskočit úkol a dostat bonus
function TrialService.ApplySkip(session: Session): boolean
	local trial: TrialState? = session.Trial
	if not trial then
		return false
	end
	if session.Swim and session.Swim.Trial then
		session.Swim.Done = true
	end
	TrialService.Complete(session, nil, true)
	return true
end

function TrialService.Active(session: Session): boolean
	return session.Trial ~= nil
end

-- ===== Dráha nad mořem: kontrolní body, pády, tyče, cíl =====

local function respawn(session: Session, trial: TrialState, s: any, text: string)
	local character = session.Player.Character
	if not character then
		return
	end
	local target = if trial.Easy and trial.LastSafe then trial.LastSafe else s.Checkpoints[trial.Checkpoint]
	character:PivotTo(target)
	local root = Registry.Player.GetRoot(session.Player)
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
	stateEvent:FireClient(session.Player, { State = "Respawn", Text = text, Checkpoint = trial.Checkpoint, Total = #s.Checkpoints })
end

local function sweeperHit(s: any, pos: Vector3, t: number): boolean
	for _, sw in s.Sweepers do
		local angle = sw.Speed * t + sw.Phase
		local dir = Vector3.new(math.cos(angle), 0, -math.sin(angle))
		local rel = Vector3.new(pos.X - sw.Center.X, 0, pos.Z - sw.Center.Z)
		local along = math.clamp(rel:Dot(dir), -sw.Length / 2, sw.Length / 2)
		local closest = dir * along
		local deckY = sw.Center.Y - 1.6
		if (rel - closest).Magnitude < TrialsConfig.SweeperHitRadius and pos.Y - deckY < TrialsConfig.SweeperHitHeight then
			return true
		end
	end
	return false
end

local function obbyTick(t: number)
	for _, session in Registry.Player.Sessions do
		local trial: TrialState? = session.Trial
		if trial and trial.State == "Offer" and session.Player.Character ~= trial.Character then
			-- resetoval se na ostrově → je na pláži, úkol končí
			clear(session)
		elseif trial and trial.State == "Obby" and not trial.Busy then
			local s = spot(trial.Key)
			local root = Registry.Player.GetRoot(session.Player)
			if session.Player.Character ~= trial.Character then
				-- hráč se resetoval (je zpátky na pláži)
				clear(session)
			elseif root and s then
				local pos = root.Position
				-- kontrolní body (dráha vede na západ = k menšímu X)
				for i = trial.Checkpoint + 1, #s.CheckpointX do
					if pos.X <= s.CheckpointX[i] + 6 and pos.Y > s.Checkpoints[i].Position.Y - 6 and math.abs(pos.Z) < 9 then
						trial.Checkpoint = i
						stateEvent:FireClient(session.Player, { State = "Checkpoint", Checkpoint = i, Total = #s.Checkpoints })
					end
				end
				-- poslední bezpečné místo (Easy Path)
				local humanoid = session.Player.Character and session.Player.Character:FindFirstChildOfClass("Humanoid")
				if trial.Easy and humanoid and humanoid.FloorMaterial ~= Enum.Material.Air and os.clock() - trial.LastSafeAt > 0.4 then
					trial.LastSafeAt = os.clock()
					-- jen pevné plošiny (ne mizející), ať se hráč neobjeví nad dírou
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = { session.Player.Character :: Instance }
					local hit = Workspace:Raycast(pos, Vector3.new(0, -6, 0), params)
					if hit and hit.Instance.Name ~= "FadingPad" then
						trial.LastSafe = CFrame.lookAt(pos + Vector3.new(0, 0.5, 0), pos + Vector3.new(-10, 0.5, 0))
					end
				end
				if s.Finish and (pos - s.Finish).Magnitude < 13 then
					TrialService.Complete(session)
				elseif pos.Y < World.WaterY + TrialsConfig.ObbyFallY then
					respawn(session, trial, s, "SPLASH! Back to the flag!")
				elseif not trial.Easy and sweeperHit(s, pos, t) then
					respawn(session, trial, s, "BONK! Jump over the bars!")
				end
			end
		end
	end
end

function TrialService.Init()
	offerEvent = Net.Event("TrialOffer")
	stateEvent = Net.Event("TrialState")
end

function TrialService.Start()
	Net.Event("TrialAction").OnServerEvent:Connect(function(player, action)
		local session = Registry.Player.Get(player)
		if not session or not session.Trial then
			return
		end
		if action == "Start" then
			start(session)
		elseif action == "GoHome" then
			TrialService.GoHome(session)
		end
	end)
	-- prompty u kánoe a na startu dráhy
	for key, s in Registry.Map.Trials do
		s.Prompt.Triggered:Connect(function(player)
			local session = Registry.Player.Get(player)
			if session and session.Trial and session.Trial.Key == key then
				start(session)
			end
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		local session = Registry.Player.Get(player)
		if session then
			session.Trial = nil
		end
	end)
	-- pohyblivé části dráhy (počítá server, aby sedělo vyhodnocení nárazů)
	local startClock = os.clock()
	local lastObby = 0
	RunService.Heartbeat:Connect(function()
		local t = os.clock() - startClock
		for _, s in Registry.Map.Trials do
			for _, sw in s.Sweepers do
				local angle = sw.Speed * t + sw.Phase
				sw.Bar.CFrame = CFrame.new(sw.Center) * CFrame.Angles(0, angle, 0)
			end
			for _, f in s.Faders do
				-- 2,4 s pevná, 0,6 s bliká (varování), 1,2 s není
				local cycle = (t + f.Phase) % 4.2
				local part = f.Part
				if cycle < 2.4 then
					if part.Transparency ~= 0 then
						part.Transparency = 0
						part.CanCollide = true
						part.Color = f.Color
					end
				elseif cycle < 3.0 then
					part.Transparency = 0.45
					part.Color = if math.floor(cycle * 8) % 2 == 0 then Color3.new(1, 1, 1) else f.Color
				elseif part.CanCollide then
					part.CanCollide = false
					part.Transparency = 0.9
				end
			end
		end
		if t - lastObby > 0.1 then
			lastObby = t
			obbyTick(t)
		end
	end)
end

return TrialService

--!strict
-- CHALLENGE souboje na pláži (klient): výběr hry, pozvánka, rozběh / sjezd, odraz, let, výsledky.
-- Server určuje časy (GoAt, BoardAt) a počítá metry; klient je spočítá stejným vzorcem dopředu,
-- aby skok mohl hned letět tam, kam doopravdy dopadne.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Duels = require(Shared.Config.Duels)
local World = require(Shared.Config.World)
local Formulas = require(Shared.Formulas)
local Net = require(Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)
local Kit = require(script.Parent.Parent.UI.Kit)
local Dialogs = require(script.Parent.Parent.UI.Dialogs)
local Sound = require(script.Parent.Parent.Sound)
local Effects = require(script.Parent.Parent.Effects.Effects)

local DuelController = {}

local player = Players.LocalPlayer

type Run = {
	Game: string,
	GoAt: number,
	BoardAt: number,
	Lane: number,
	LaneZ: number,
	Z: number, -- lyže: posun do strany
	Gates: number, -- projeté branky (lyže)
	NextGate: number,
	Pressed: boolean,
	Meters: number,
	Foul: boolean,
	TakeoffPos: Vector3?,
	TakeoffAt: number,
	LandPos: Vector3?,
	Finished: boolean,
	LastCount: number,
}

local screen: ScreenGui
local board: Frame
local boardTitle: TextLabel
local boardRows: { TextLabel } = {}
local jumpButton: TextButton
local leaveButton: TextButton
local picker: Frame
local pickerTitle: TextLabel
local pickTargetId = 0
local results: Frame
local resultsTitle: TextLabel
local resultsText: TextLabel
local revengeButton: TextButton
local againButton: TextButton
local run: Run? = nil
local controls: any? = nil
local inDuel = false
local gearPanel: Frame
local gearButtons: { [string]: TextButton } = {}
local GEAR_LABELS = { Skis = "🎿 SKIS", Board = "🏂 SNOWBOARD" }
local gearKind = "Skis"

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function getControls(): any?
	local ok, module = pcall(function()
		local playerModule = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
		return if playerModule then (require :: any)(playerModule) else nil
	end)
	if ok and module then
		return (module :: any):GetControls()
	end
	return nil
end

local function myGear(): number
	local data = ClientState.Get()
	local passes = data.Passes or {}
	return Formulas.DuelGear(data.EquippedSlippers or "BasicBlackSlippers", data.EquippedHat, passes.SuperJumper == true)
end

local function fmt(m: number): string
	return string.format("%.2f m", m)
end

-- ===== Tabulka nahoře =====

local function renderBoard(state: { [string]: any })
	local cfg = Duels.Games[state.Game]
	boardTitle.Text = `{cfg.Icon} {cfg.Name}` .. (if state.Practice then "  (PRACTICE)" else "") .. `   Round {math.max(1, state.Round or 1)}/{state.Rounds}`
	for i, row in boardRows do
		local r = state.Racers[i]
		if r then
			local parts = {}
			for k = 1, state.Rounds do
				local a = r.Attempts[k]
				table.insert(parts, if not a then "–" elseif a.Foul then "❌" else string.format("%.2f", a.Meters))
			end
			row.Text = `{r.Name}:  {table.concat(parts, "  |  ")}   ⭐ {if r.Best > 0 then fmt(r.Best) else "–"}`
			row.TextColor3 = if r.UserId == player.UserId then Kit.Colors.Yellow else Kit.Colors.White
			row.Visible = true
		else
			row.Visible = false
		end
	end
	board.Size = UDim2.fromOffset(620, 54 + #state.Racers * 34)
	board.Visible = true
end

-- ===== Pohyb =====

local function laneZ(gameKey: string, lane: number): number
	local cfg = Duels.Games[gameKey]
	return cfg.Z + (cfg.Lanes[lane] or 0)
end

-- poloha na dráze v čase t od startu (před odrazem)
local function runPosition(r: Run, t: number): Vector3
	local cfg = Duels.Games[r.Game]
	local p = math.max(0, t) / cfg.RunTime
	if r.Game == "LongJump" then
		-- plynulé zrychlení, za čárou stejnou rychlostí dál
		local s = if p <= 1 then p ^ 1.3 else 1 + (p - 1) * 1.3
		local x = cfg.StartX + (cfg.BoardX - cfg.StartX) * s
		return Vector3.new(x, cfg.Y, r.LaneZ)
	end
	local s = if p <= 1 then p ^ 1.6 else 1 + (p - 1) * 1.6
	local x = cfg.TopX + (cfg.LipX - cfg.TopX) * s
	local ground = cfg.TopY + (cfg.LipY - cfg.TopY) * math.min(s, 1)
	return Vector3.new(x, ground + cfg.Y, r.LaneZ + r.Z)
end

local function setRoot(pos: Vector3, look: Vector3, velocity: Vector3)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	if run and run.Game == "SandSki" and gearKind == "Board" then
		-- snowboard: stojí bokem (levá noha vpředu), ne čelem dolů
		look = Vector3.new(0, 0, 1)
	end
	root.CFrame = CFrame.lookAt(pos, pos + look)
	-- rychlost kvůli animaci běhu (fyzika ji stejně každý snímek přepíše)
	root.AssemblyLinearVelocity = velocity
	root.AssemblyAngularVelocity = Vector3.zero
end

local function takeoff(r: Run)
	if r.Pressed or r.Finished then
		return
	end
	r.Pressed = true
	local delta = now() - r.BoardAt
	local gatesRatio = r.Gates / #Duels.Games.SandSki.Gates
	local meters, foul, perfect = Formulas.DuelMeters(r.Game, myGear(), delta, gatesRatio)
	r.Meters = meters
	r.Foul = foul
	Net.Event("DuelAction"):FireServer("Takeoff", delta, gatesRatio)
	local cfg = Duels.Games[r.Game]
	r.TakeoffAt = os.clock()
	r.TakeoffPos = runPosition(r, now() - r.GoAt)
	if foul then
		Effects.BigText(if r.Game == "LongJump" then "FOUL! ❌" else "WIPEOUT! ❌", Kit.Colors.Coral, 1, 0.35)
		Sound.Play("Boing", 0.6)
		return
	end
	if perfect then
		Effects.BigText("PERFECT TAKEOFF!", Kit.Colors.Green, 0.9, 0.35)
		Sound.Play("Perfect")
	else
		Sound.Play("Good")
	end
	local start = r.TakeoffPos :: Vector3
	if r.Game == "LongJump" then
		r.LandPos = Vector3.new(cfg.BoardX + meters * cfg.StudsPerMeter, cfg.Y - 1.5, start.Z)
	else
		r.LandPos = Vector3.new(cfg.LipX + meters * cfg.StudsPerMeter, World.WaterY + 1, start.Z)
	end
end

local function jumpInput(_: string, inputState: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin and run and not run.Pressed and now() >= run.GoAt then
		takeoff(run)
	end
	return Enum.ContextActionResult.Sink
end

local function setControlsActive(active: boolean)
	if active then
		ContextActionService:BindActionAtPriority("DuelJump", jumpInput, false, Enum.ContextActionPriority.High.Value + 20, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	else
		ContextActionService:UnbindAction("DuelJump")
	end
	jumpButton.Visible = active
end

local function refreshGear()
	for kind, button in gearButtons do
		Kit.SetButtonText(button, (if kind == gearKind then "✔ " else "") .. GEAR_LABELS[kind])
	end
end

local function pickGear(kind: string)
	gearKind = kind
	refreshGear()
	Net.Event("DuelAction"):FireServer("SkiGear", kind)
	Sound.Play("Click")
end

local function update(dt: number)
	local r = run
	if not r then
		return
	end
	local cfg = Duels.Games[r.Game]
	local t = now() - r.GoAt
	local forward = Vector3.new(1, 0, 0)
	if t < 0 then
		-- odpočet na startu
		local count = math.ceil(-t)
		if count ~= r.LastCount and count <= 3 then
			r.LastCount = count
			Effects.BigText(tostring(count), Kit.Colors.Yellow, 0.7, 0.4)
			Sound.Play("Click", 1.2)
		end
		gearPanel.Visible = r.Game == "SandSki"
		setRoot(runPosition(r, 0), forward, Vector3.zero)
		return
	end
	gearPanel.Visible = false
	if r.LastCount ~= 0 then
		r.LastCount = 0
		Effects.BigText(if r.Game == "LongJump" then "RUN!" else "GO!", Kit.Colors.Green, 0.6, 0.4)
	end
	if not r.Pressed then
		-- lyže: kormidlování mezi praporky
		if r.Game == "SandSki" then
			if not controls then
				controls = getControls()
			end
			local move = if controls then controls:GetMoveVector() else Vector3.zero
			r.Z = math.clamp(r.Z + move.X * cfg.SteerSpeed * dt, -cfg.LaneHalfWidth, cfg.LaneHalfWidth)
			local gate = cfg.Gates[r.NextGate]
			if gate then
				local gateX = cfg.TopX + (cfg.LipX - cfg.TopX) * gate.At
				if runPosition(r, t).X >= gateX then
					r.NextGate += 1
					if math.abs(r.Z - gate.Offset) <= cfg.GateHalfWidth then
						r.Gates += 1
						Sound.Play("Ring", 1.1 + r.Gates * 0.1)
						Effects.FloatText(`GATE {r.Gates}/{#cfg.Gates} ✓`, Kit.Colors.Green)
					else
						Effects.FloatText("Missed the gate!", Kit.Colors.Coral)
					end
				end
			end
		end
		local pos = runPosition(r, t)
		local ahead = runPosition(r, t + 0.05)
		-- na lyžích/prkně se jen klouže (bez animace běhu)
		setRoot(pos, Vector3.new(1, 0, 0), if r.Game == "SandSki" then Vector3.zero else (ahead - pos) / 0.05)
		-- nikdo nezmáčkl: přešlap / pád z můstku
		if now() > r.BoardAt + Duels.FoulLate then
			takeoff(r)
		end
		return
	end
	-- po odrazu: oblouk na místo dopadu (nebo faul)
	local since = os.clock() - r.TakeoffAt
	local start = r.TakeoffPos :: Vector3
	if r.Foul or not r.LandPos then
		-- faul: doběhne/sklouzne kus za čáru a zastaví se
		local stop = if r.Game == "LongJump" then Vector3.new(cfg.BoardX + 6, cfg.Y - 1, start.Z) else Vector3.new(cfg.LipX + 8, World.WaterY + 1, start.Z)
		local p = math.clamp(since / 0.8, 0, 1)
		local pos = start:Lerp(stop, p)
		if r.Game == "SandSki" then
			pos += Vector3.new(0, 4 * p * (1 - p), 0)
		end
		setRoot(pos, forward, Vector3.zero)
		if p >= 1 and not r.Finished then
			r.Finished = true
			Effects.Splash(pos, false)
		end
		return
	end
	local land = r.LandPos :: Vector3
	local p = math.clamp(since / cfg.FlightTime, 0, 1)
	local pos = start:Lerp(land, p) + Vector3.new(0, 4 * cfg.FlightHeight * p * (1 - p), 0)
	setRoot(pos, forward, Vector3.zero)
	if p >= 1 and not r.Finished then
		r.Finished = true
		Effects.Splash(land, r.Game == "SandSki")
		Effects.Shake(0.3)
		Effects.BigText(fmt(r.Meters) .. "!", Kit.Colors.Yellow, 1.2, 0.3)
	end
end

-- ===== Stav ze serveru =====

local function myLane(state: { [string]: any }): number?
	for _, r in state.Racers or {} do
		if r.UserId == player.UserId then
			return r.Lane
		end
	end
	return nil
end

local function endDuel()
	inDuel = false
	gearPanel.Visible = false
	run = nil
	setControlsActive(false)
	leaveButton.Visible = false
	task.delay(4, function()
		if not inDuel then
			board.Visible = false
		end
	end)
end

local function onState(state: { [string]: any })
	local s = state.State
	if s == "Pick" then
		pickTargetId = state.TargetId
		pickerTitle.Text = `⚔️ Challenge {state.TargetName}!`
		picker.Visible = true
		Kit.Pop(picker, 1.1)
		return
	end
	if s == "Intro" then
		inDuel = true
		results.Visible = false
		picker.Visible = false
		leaveButton.Visible = true
		renderBoard(state)
		local cfg = Duels.Games[state.Game]
		Effects.BigText(`{cfg.Icon} {cfg.Name}!`, Kit.Colors.Orange, 1.4, 0.3)
		if state.Game == "SandSki" then
			refreshGear()
			gearPanel.Visible = true
			Net.Event("DuelAction"):FireServer("SkiGear", gearKind)
		end
		Sound.Play("Perfect", 0.8)
	elseif s == "Run" then
		renderBoard(state)
		local lane = myLane(state)
		if lane then
			run = {
				Game = state.Game,
				GoAt = state.GoAt,
				BoardAt = state.BoardAt,
				Lane = lane,
				LaneZ = laneZ(state.Game, lane),
				Z = 0,
				Gates = 0,
				NextGate = 1,
				Pressed = false,
				Meters = 0,
				Foul = false,
				TakeoffPos = nil,
				TakeoffAt = 0,
				LandPos = nil,
				Finished = false,
				LastCount = -1,
			}
			setControlsActive(true)
			Kit.SetButtonText(jumpButton, if state.Game == "LongJump" then "JUMP! (at the line)" else "JUMP! (at the ramp)")
		end
	elseif s == "Jumped" then
		renderBoard(state)
		if state.UserId ~= player.UserId then
			local name = ""
			for _, r in state.Racers do
				if r.UserId == state.UserId then
					name = r.Name
				end
			end
			Effects.FloatText(if state.Foul then `{name}: FOUL!` else `{name}: {fmt(state.Meters)}`, Kit.Colors.White)
		end
		if state.UserId == player.UserId then
			setControlsActive(false)
		end
	elseif s == "Round" then
		renderBoard(state)
		setControlsActive(false)
	elseif s == "End" then
		renderBoard(state)
		local mine = state.Results and state.Results[tostring(player.UserId)] or {}
		local cfg = Duels.Games[state.Game]
		local won = state.Winner == player.UserId
		if state.Practice then
			resultsTitle.Text = `{cfg.Icon} PRACTICE DONE`
			resultsText.Text = `Your best: {fmt(mine.Best or 0)}` .. (if mine.Record then "  🎉 NEW PERSONAL RECORD!" else "") .. "\nChallenge a friend: walk up to them and press C!"
		elseif won then
			resultsTitle.Text = "🏆 YOU WIN!"
			resultsText.Text = `Best: {fmt(mine.Best or 0)}` .. (if state.Forfeit then " (opponent left)" else "") .. `\nReward: $ +{mine.Money or 0}` .. (if (mine.Spins or 0) > 0 then ` + {mine.Spins} Spin` else "") .. "\nYou are the CHAMPION! 🏆"
			Effects.ScreenConfetti(150)
			Sound.Play("Fanfare")
		elseif state.Winner == 0 then
			resultsTitle.Text = "🤝 DRAW!"
			resultsText.Text = `Best: {fmt(mine.Best or 0)}\nReward: $ +{mine.Money or 0}`
		else
			resultsTitle.Text = `😤 {state.WinnerName} WINS!`
			resultsText.Text = `Your best: {fmt(mine.Best or 0)}\nReward: $ +{mine.Money or 0}\nBetter slippers = longer jumps! Want a REVENGE?`
		end
		revengeButton.Visible = not state.Practice and not won and state.Winner ~= 0
		revengeButton:SetAttribute("TargetId", state.Winner)
		revengeButton:SetAttribute("Game", state.Game)
		againButton.Visible = state.Practice
		againButton:SetAttribute("Game", state.Game)
		results.Visible = true
		Kit.Pop(results, 1.1)
		endDuel()
	end
end

-- ===== UI =====

function DuelController.Init()
	screen = Kit.Screen("Duels", 15)
	board = Kit.Panel(screen, {
		Name = "DuelBoard",
		Size = UDim2.fromOffset(620, 122),
		Position = UDim2.new(0.5, 0, 0, 70),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(40, 60, 110),
		Visible = false,
	})
	boardTitle = Kit.Text(board, { Text = "", Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(10, 6), TextColor3 = Kit.Colors.Orange, StrokeThickness = 3 })
	for i = 1, 2 do
		boardRows[i] = Kit.Text(board, { Text = "", Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 44 + (i - 1) * 34), StrokeThickness = 2, Visible = false })
	end
	jumpButton = Kit.Button(screen, { Text = "JUMP!", Color = Kit.Colors.Green, Size = UDim2.fromOffset(300, 110), Position = UDim2.new(0.5, 0, 1, -40), AnchorPoint = Vector2.new(0.5, 1) }, function()
		if run and not run.Pressed and now() >= run.GoAt then
			takeoff(run)
		end
	end)
	jumpButton.Visible = false
	leaveButton = Kit.Button(screen, { Text = "LEAVE", Color = Kit.Colors.Gray, Size = UDim2.fromOffset(120, 50), Position = UDim2.new(1, -16, 1, -40), AnchorPoint = Vector2.new(1, 1) }, function()
		Net.Event("DuelAction"):FireServer("Leave")
	end)
	leaveButton.Visible = false

	-- lyže nebo snowboard (vybírá se během odpočtu)
	gearPanel = Kit.Panel(screen, { Size = UDim2.fromOffset(420, 120), Position = UDim2.new(0.5, 0, 1, -170), AnchorPoint = Vector2.new(0.5, 1), Visible = false })
	Kit.Text(gearPanel, { Text = "Ride down on:", Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 6), TextColor3 = Kit.Colors.Text, NoStroke = true })
	for i, kind in { "Skis", "Board" } do
		gearButtons[kind] = Kit.Button(gearPanel, { Text = GEAR_LABELS[kind], Color = if kind == "Skis" then Kit.Colors.Coral else Kit.Colors.Turquoise, Size = UDim2.fromOffset(190, 70), Position = UDim2.new(0, 14 + (i - 1) * 202, 1, -80) }, function()
			pickGear(kind)
		end)
	end

	-- výběr hry pro výzvu
	picker = Kit.Panel(screen, { Size = UDim2.fromOffset(560, 230), Position = UDim2.fromScale(0.5, 0.45), AnchorPoint = Vector2.new(0.5, 0.5), Visible = false })
	pickerTitle = Kit.Text(picker, { Text = "", Size = UDim2.new(1, -80, 0, 50), Position = UDim2.fromOffset(16, 12), TextColor3 = Kit.Colors.Orange, StrokeThickness = 3 })
	Kit.Text(picker, { Text = "Pick a game – 3 tries each, best jump wins!", Size = UDim2.new(1, -40, 0, 28), Position = UDim2.fromOffset(20, 64), TextColor3 = Kit.Colors.Text, NoStroke = true })
	for i, key in Duels.Order do
		local cfg = Duels.Games[key]
		Kit.Button(picker, { Text = `{cfg.Icon} {string.upper(if key == "LongJump" then "Long Jump" else "Ski Jump")}`, Color = if i == 1 then Kit.Colors.Orange else Kit.Colors.Turquoise, Size = UDim2.fromOffset(250, 90), Position = UDim2.new(0, 20 + (i - 1) * 270, 1, -110) }, function()
			picker.Visible = false
			Net.Event("DuelRequest"):FireServer(pickTargetId, key)
		end)
	end
	Kit.Button(picker, { Text = "X", Color = Kit.Colors.Coral, Size = UDim2.fromOffset(50, 50), Position = UDim2.new(1, -62, 0, 12) }, function()
		picker.Visible = false
	end)

	-- výsledky
	results = Kit.Panel(screen, { Size = UDim2.fromOffset(560, 290), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Visible = false })
	resultsTitle = Kit.Text(results, { Text = "", Size = UDim2.new(1, -40, 0, 56), Position = UDim2.fromOffset(20, 12), TextColor3 = Kit.Colors.Orange, StrokeThickness = 3 })
	resultsText = Kit.Text(results, { Text = "", Size = UDim2.new(1, -40, 0, 110), Position = UDim2.fromOffset(20, 72), TextColor3 = Kit.Colors.Text, NoStroke = true, TextWrapped = true })
	revengeButton = Kit.Button(results, { Text = "😤 REVENGE!", Color = Kit.Colors.Coral, Size = UDim2.fromOffset(230, 70), Position = UDim2.new(0, 20, 1, -86) }, function()
		results.Visible = false
		Net.Event("DuelRequest"):FireServer(revengeButton:GetAttribute("TargetId"), revengeButton:GetAttribute("Game"))
	end)
	againButton = Kit.Button(results, { Text = "TRY AGAIN", Color = Kit.Colors.Green, Size = UDim2.fromOffset(230, 70), Position = UDim2.new(0, 20, 1, -86) }, function()
		results.Visible = false
		Net.Event("DuelAction"):FireServer("Practice", againButton:GetAttribute("Game"))
	end)
	Kit.Button(results, { Text = "CLOSE", Color = Kit.Colors.Gray, Size = UDim2.fromOffset(230, 70), Position = UDim2.new(1, -250, 1, -86) }, function()
		results.Visible = false
	end)

	-- pozvánka od jiného hráče
	Net.Event("DuelInvite").OnClientEvent:Connect(function(invite)
		local cfg = Duels.Games[invite.Game]
		Dialogs.Show({
			Title = "⚔️ CHALLENGE!",
			Text = `{invite.From} challenges you to {cfg.Icon} {cfg.Name}! 3 tries each – the longest jump wins.`,
			Color = Kit.Colors.Orange,
			Timeout = invite.Timeout,
			Buttons = {
				{ Text = "ACCEPT", Color = Kit.Colors.Green, Callback = function()
					Net.Event("DuelRespond"):FireServer(invite.Id, true)
				end },
				{ Text = "DECLINE", Color = Kit.Colors.Coral, Callback = function()
					Net.Event("DuelRespond"):FireServer(invite.Id, false)
				end },
			},
		})
	end)
	Net.Event("DuelState").OnClientEvent:Connect(onState)
	RunService.RenderStepped:Connect(update)

	-- vlastní výzvu CHALLENGE na sobě skrýt (a během souboje i ostatní)
	local function refresh(prompt: Instance)
		if prompt:IsA("ProximityPrompt") then
			prompt.Enabled = prompt:GetAttribute("OwnerUserId") ~= player.UserId and not inDuel and ClientState.Get().Flying ~= true
		end
	end
	local function refreshAll()
		for _, prompt in CollectionService:GetTagged("DuelPrompt") do
			refresh(prompt)
		end
	end
	CollectionService:GetInstanceAddedSignal("DuelPrompt"):Connect(refresh)
	ClientState.Changed:Connect(refreshAll)
	task.spawn(function()
		while true do
			refreshAll()
			task.wait(1)
		end
	end)
end

return DuelController

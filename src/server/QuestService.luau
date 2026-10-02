--!strict
-- Denní úkoly (3 denně, nové každý den o půlnoci UTC) a odměna za sérii přihlášení.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Quests = require(Shared.Config.Quests)
local FormatNumber = require(Shared.Util.FormatNumber)
local Net = require(Shared.Net)

local Registry = require(script.Parent.Registry)

type Session = any

local QuestService = {}

local function today(): number
	return os.time() // 86400
end

local function scale(session: Session): number
	return math.max(1, math.floor(session.Data.Level / Quests.MoneyLevelDivisor))
end

local function ensureDay(session: Session)
	local data = session.Data
	local day = today()
	if data.Quests.Day == day then
		return
	end
	local indexes = {}
	for i = 1, #Quests.Pool do
		table.insert(indexes, i)
	end
	local list = {}
	for _ = 1, math.min(Quests.PerDay, #indexes) do
		local pick = table.remove(indexes, math.random(1, #indexes)) :: number
		table.insert(list, { Index = pick, Progress = 0, Done = false })
	end
	data.Quests = { Day = day, List = list }
	Registry.Player.MarkDirty(session)
end

-- Společná část: nastaví postup úkolů daného druhu a při splnění dá odměnu.
-- update(starý postup) → nový postup
local function advance(session: Session, kind: string, update: (number) -> number)
	ensureDay(session)
	for _, quest in session.Data.Quests.List do
		local template = Quests.Pool[quest.Index]
		if template and template.Kind == kind and not quest.Done then
			local progress = math.min(template.Goal, update(quest.Progress))
			if progress <= quest.Progress then
				continue
			end
			quest.Progress = progress
			if quest.Progress >= template.Goal then
				quest.Done = true
				local money = template.Money * scale(session)
				Registry.Economy.AddMoney(session, money)
				local text = "Quest complete! +" .. FormatNumber.Money(money)
				if template.Spins then
					Registry.Spinner.AddSpins(session, template.Spins)
					text ..= " +" .. template.Spins .. " Spin"
				end
				Registry.Player.Notify(session.Player, text, "Success")
				Net.Event("PlayEffect"):FireClient(session.Player, "Quest", {})
			end
			Registry.Player.MarkDirty(session)
		end
	end
end

-- Přičte postup (např. +1 skok)
function QuestService.Progress(session: Session, kind: string, amount: number)
	if amount <= 0 then
		return
	end
	advance(session, kind, function(progress)
		return progress + amount
	end)
end

-- Postup = nejlepší dosažená hodnota (např. série PERFECT skoků)
function QuestService.Reach(session: Session, kind: string, value: number)
	if value <= 0 then
		return
	end
	advance(session, kind, function(progress)
		return math.max(progress, value)
	end)
end

function QuestService.BuildState(session: Session): { { [string]: any } }
	ensureDay(session)
	local list = {}
	for _, quest in session.Data.Quests.List do
		local template = Quests.Pool[quest.Index]
		if template then
			table.insert(list, {
				Text = string.format(template.Text, template.Goal),
				Progress = quest.Progress,
				Goal = template.Goal,
				Done = quest.Done,
				Money = template.Money * scale(session),
				Spins = template.Spins or 0,
			})
		end
	end
	return list
end

function QuestService.OnJoin(session: Session)
	ensureDay(session)
	local data = session.Data
	local day = today()
	if data.LoginDay == day then
		return
	end
	data.LoginStreak = if data.LoginDay == day - 1 then data.LoginStreak + 1 else 1
	data.LoginDay = day
	local reward = Quests.Streak[math.min(data.LoginStreak, #Quests.Streak)]
	local money = reward.Money * scale(session)
	Registry.Economy.AddMoney(session, money)
	if reward.Spins then
		Registry.Spinner.AddSpins(session, reward.Spins)
	end
	Net.Event("OpenUI"):FireClient(session.Player, "DailyReward", { Streak = data.LoginStreak, Money = money, Spins = reward.Spins or 0 })
	Registry.Player.MarkDirty(session)
end

return QuestService

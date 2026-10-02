--!strict
-- Peníze: násobiče, příjem domečku každou sekundu, kasička, příjem offline.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Catalog = require(Shared.Catalog)
local Formulas = require(Shared.Formulas)
local Net = require(Shared.Net)

local Registry = require(script.Parent.Registry)

type Session = any

local EconomyService = {}

-- Má hráč Roblox Premium? (čte se pokaždé znovu – členství se může změnit i během hry)
function EconomyService.IsPremium(session: Session): boolean
	local player: Player = session.Player
	return player.MembershipType == Enum.MembershipType.Premium
end

-- Násobič příjmu (znovuzrození, čepice, 2x Money pass, dočasný boost, Premium, událost)
function EconomyService.Multiplier(session: Session): number
	local data = session.Data
	return Formulas.IncomeMultiplier({
		Rebirths = data.Rebirths,
		HatId = data.EquippedHat,
		DoubleMoneyPass = session.Passes.DoubleMoney == true,
		BoostUntil = data.BoostUntil,
		Premium = EconomyService.IsPremium(session),
		Now = os.time(),
	})
end

-- Součet příjmů předmětů v domečku (bez násobičů)
function EconomyService.BaseIncome(session: Session): number
	local total = 0
	for _, item in session.Data.HouseSlots do
		local cfg = Catalog.Item(item.Id)
		if cfg then
			total += cfg.Income
		end
	end
	return total
end

function EconomyService.IncomePerSecond(session: Session): number
	return math.floor(EconomyService.BaseIncome(session) * EconomyService.Multiplier(session) * 10) / 10
end

function EconomyService.AddMoney(session: Session, amount: number)
	if amount <= 0 or amount ~= amount then
		return
	end
	session.Data.Money += amount
	session.Data.TotalEarned += amount
	Registry.Player.MarkDirty(session)
end

function EconomyService.Spend(session: Session, amount: number): boolean
	if amount < 0 or session.Data.Money < amount then
		return false
	end
	session.Data.Money -= amount
	Registry.Player.MarkDirty(session)
	return true
end

function EconomyService.AddBoost(session: Session, minutes: number)
	local now = os.time()
	session.Data.BoostUntil = math.max(now, session.Data.BoostUntil) + minutes * 60
	Registry.Player.MarkDirty(session)
	Registry.House.Render(session)
end

-- Lucky Potion: čas se sčítá stejně jako u 2x Money boostu
function EconomyService.AddLuck(session: Session, minutes: number)
	local now = os.time()
	session.Data.LuckUntil = math.max(now, session.Data.LuckUntil) + minutes * 60
	Registry.Player.MarkDirty(session)
end

function EconomyService.CollectPiggy(session: Session)
	local amount = session.Data.PendingCash
	session.Data.PendingCash = 0
	if amount > 0 then
		EconomyService.AddMoney(session, amount)
		Net.Event("PlayEffect"):FireClient(session.Player, "Collect", { Amount = amount })
	end
	Registry.House.UpdatePiggy(session)
	Registry.Tutorial.OnCollect(session)
	Registry.Player.MarkDirty(session)
end

function EconomyService.ApplyOffline(session: Session)
	local data = session.Data
	if data.LastLogout <= 0 then
		return
	end
	local away = math.clamp(os.time() - data.LastLogout, 0, Economy.OfflineMaxSeconds)
	data.LastLogout = 0
	if away < Economy.OfflineMinSeconds then
		return
	end
	-- plný příjem domečku (bez dočasných boostů)
	local income = EconomyService.BaseIncome(session) * Formulas.IncomeMultiplier({
		Rebirths = data.Rebirths,
		HatId = data.EquippedHat,
		DoubleMoneyPass = session.Passes.DoubleMoney == true,
		BoostUntil = 0,
		Premium = EconomyService.IsPremium(session),
		Now = os.time(),
	})
	local earned = math.floor(income * away)
	if earned > 0 then
		EconomyService.AddMoney(session, earned)
		Net.Event("WelcomeBack"):FireClient(session.Player, earned, away)
	end
end

function EconomyService.Start()
	task.spawn(function()
		while true do
			task.wait(Economy.IncomeTick)
			for _, session in Registry.Player.Sessions do
				if session.Loaded then
					local income = EconomyService.IncomePerSecond(session) * Economy.IncomeTick
					if income > 0 then
						if session.Passes.AutoCollect then
							EconomyService.AddMoney(session, income)
						else
							session.Data.PendingCash += income
							Registry.Player.MarkDirty(session)
						end
					end
					Registry.House.UpdatePiggy(session)
				end
			end
		end
	end)
end


return EconomyService

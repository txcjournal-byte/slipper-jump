--!strict
-- Levely 1–50: XP za skoky, odměna 100 $ × level, milníky (točení, místa, čepice, předměty, titulek).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Levels = require(Shared.Config.Levels)
local Formulas = require(Shared.Formulas)
local Catalog = require(Shared.Catalog)
local Net = require(Shared.Net)

local Registry = require(script.Parent.Registry)

type Session = any

local LevelService = {}

function LevelService.AddTitle(session: Session, title: string)
	local data = session.Data
	if not table.find(data.Titles, title) then
		table.insert(data.Titles, title)
	end
	data.Title = title
	Registry.Avatar.UpdateOverhead(session)
	Registry.Player.MarkDirty(session)
end

local function applyMilestone(session: Session, level: number): { string }
	local milestone = Levels.Milestones[level]
	local rewards = {}
	if not milestone then
		return rewards
	end
	if milestone.Spins then
		Registry.Spinner.AddSpins(session, milestone.Spins)
		table.insert(rewards, `+{milestone.Spins} Spin{if milestone.Spins > 1 then "s" else ""}`)
	end
	if milestone.Slots then
		table.insert(rewards, `+{milestone.Slots} House Slot{if milestone.Slots > 1 then "s" else ""}`)
	end
	if milestone.Hat then
		Registry.Shop.GrantHat(session, milestone.Hat)
		local hat = Catalog.Hat(milestone.Hat)
		table.insert(rewards, if hat then hat.Name else milestone.Hat)
	end
	if milestone.Rarity then
		local item = Registry.Items.GiveRandom(session, milestone.Rarity)
		local cfg = Catalog.Item(item.Id)
		table.insert(rewards, if cfg then cfg.Name else milestone.Rarity .. " Item")
	end
	if milestone.Title then
		LevelService.AddTitle(session, milestone.Title)
		table.insert(rewards, `Title "{milestone.Title}"`)
	end
	return rewards
end

function LevelService.AddXP(session: Session, amount: number)
	local data = session.Data
	if data.Level >= Levels.MaxLevel then
		data.XP = 0
		return
	end
	data.XP += amount
	local leveled = false
	while data.Level < Levels.MaxLevel and data.XP >= Formulas.XPToNext(data.Level) do
		data.XP -= Formulas.XPToNext(data.Level)
		data.Level += 1
		leveled = true
		local money = Levels.MoneyPerLevel * data.Level
		Registry.Economy.AddMoney(session, money)
		local rewards = applyMilestone(session, data.Level)
		Net.Event("LevelUp"):FireClient(session.Player, { Level = data.Level, Money = money, Rewards = rewards })
	end
	if data.Level >= Levels.MaxLevel then
		data.XP = 0
	end
	if leveled then
		Registry.Avatar.UpdateOverhead(session)
		Registry.House.Render(session)
		Registry.House.CheckTier(session)
		Registry.Items.FlushStorage(session)
	end
	Registry.Player.MarkDirty(session)
end

return LevelService

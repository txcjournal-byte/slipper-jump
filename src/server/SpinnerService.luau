--!strict
-- Kolo štěstí: 1 točení zdarma každých 24 h (VIP +1), extra točení z levelů, kódů a Robux.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Spinner = require(Shared.Config.Spinner)
local Formulas = require(Shared.Formulas)
local Catalog = require(Shared.Catalog)
local FormatNumber = require(Shared.Util.FormatNumber)
local Net = require(Shared.Net)

local Registry = require(script.Parent.Registry)

type Session = any

local SpinnerService = {}

local rng = Random.new()
local spinning: { [Player]: boolean } = {}

local function chooseSegment(): number
	local total = 0
	for _, segment in Spinner.Segments do
		total += segment.Weight
	end
	local roll = rng:NextNumber(0, total)
	for index, segment in Spinner.Segments do
		roll -= segment.Weight
		if roll <= 0 then
			return index
		end
	end
	return 1
end

function SpinnerService.AddSpins(session: Session, count: number)
	session.Data.ExtraSpins += count
	Registry.Player.MarkDirty(session)
end

local function spin(player: Player): { [string]: any }
	local session = Registry.Player.Get(player)
	if not session then
		return { Ok = false, Message = "Try again." }
	end
	if spinning[player] then
		return { Ok = false, Message = "The wheel is already spinning!" }
	end
	local data = session.Data
	local available = Registry.Player.SpinStatus(session)
	if available > 0 then
		local now = os.time()
		if now - data.DailyPeriodStart >= Spinner.Cooldown then
			data.DailyPeriodStart = now
			data.DailySpinsUsed = 1
		else
			data.DailySpinsUsed += 1
		end
	elseif data.ExtraSpins > 0 then
		data.ExtraSpins -= 1
	else
		return { Ok = false, Message = "No spins left! Come back later." }
	end
	spinning[player] = true
	local index = chooseSegment()
	local segment = Spinner.Segments[index]
	local reward = segment.Reward
	local rewardText = segment.Label
	local itemId: string? = nil
	if reward.Money then
		local amount = reward.Money * Formulas.SpinnerMoneyScale(data.Level)
		Registry.Economy.AddMoney(session, amount)
		rewardText = FormatNumber.Money(amount)
	elseif reward.Rarity then
		local item = Registry.Items.GiveRandom(session, reward.Rarity)
		itemId = item.Id
		local cfg = Catalog.Item(item.Id)
		rewardText = if cfg then cfg.Name else reward.Rarity .. " Item"
	elseif reward.BoostMinutes then
		Registry.Economy.AddBoost(session, reward.BoostMinutes)
	end
	Registry.Player.MarkDirty(session)
	task.delay(Spinner.SpinTime, function()
		spinning[player] = nil
	end)
	return { Ok = true, Index = index, Label = segment.Label, RewardText = rewardText, ItemId = itemId }
end

function SpinnerService.Start()
	Net.Function("Spin").OnServerInvoke = spin
	Registry.Map.SpinnerPrompt.Triggered:Connect(function(player)
		Net.Event("OpenUI"):FireClient(player, "Spinner")
	end)
end

return SpinnerService

--!strict
-- Výpočty sdílené serverem i klientem (klient je používá jen pro zobrazení).

local Config = script.Parent.Config
local Jump = require(Config.Jump)
local Levels = require(Config.Levels)
local Economy = require(Config.Economy)
local Events = require(Config.Events)
local Spinner = require(Config.Spinner)
local House = require(Config.House)
local Products = require(Config.Products)
local Swim = require(Config.Swim)
local GiantGift = require(Config.GiantGift)
local Catalog = require(script.Parent.Catalog)

local Formulas = {}

export type PowerTier = "Perfect" | "Good" | "None"

-- Ukazatel síly jezdí 0 → 1 → 0 (trojúhelníková vlna)
function Formulas.MeterValue(elapsed: number, period: number): number
	local phase = (elapsed / period) % 2
	return if phase <= 1 then phase else 2 - phase
end

function Formulas.PowerTier(value: number): (PowerTier, number)
	if value >= Jump.Meter.PerfectMin then
		return "Perfect", Jump.Meter.PerfectBonus
	elseif value >= Jump.Meter.GoodMin then
		return "Good", Jump.Meter.GoodBonus
	end
	return "None", 0
end

-- Bonus za sérii PERFECT skoků: první PERFECT nic, každý další +Step až do MaxBonus
function Formulas.PerfectStreakBonus(streak: number): number
	local cfg = Jump.PerfectStreak
	return math.clamp((streak - 1) * cfg.Step, 0, cfg.MaxBonus)
end

function Formulas.HatBonuses(hatId: string?): (number, number)
	local hat = if hatId then Catalog.Hat(hatId) else nil
	if not hat then
		return 0, 0
	end
	return hat.JumpBonus, hat.IncomeBonus
end

-- Skok bez bonusů za načasování, kruhy a náhodu
function Formulas.BaseJump(slipperId: string, hatId: string?): number
	local slipper = Catalog.Slipper(slipperId)
	local multiplier = if slipper then slipper.Multiplier else 1
	local jumpBonus = Formulas.HatBonuses(hatId)
	return Jump.BaseDistance * multiplier * (1 + jumpBonus)
end

-- Trvalý bonus ke vzdálenosti z game passu Super Jumper
function Formulas.PassJumpMultiplier(superJumper: boolean): number
	return if superJumper then 1 + Products.SuperJumperBonus else 1
end

function Formulas.CapDistance(distance: number, slipperId: string): number
	local cap = if Catalog.IsBestShoe(slipperId) then Jump.MaxDistance else Jump.MaxDistanceWithoutBest
	return math.clamp(distance, 1, cap)
end

-- 100 studů → MinTime, 100 000 studů → MaxTime (logaritmicky)
function Formulas.FlightDuration(distance: number): number
	local t = math.clamp((math.log10(math.max(distance, 100)) - 2) / 3, 0, 1)
	return Jump.Flight.MinTime + (Jump.Flight.MaxTime - Jump.Flight.MinTime) * t
end

function Formulas.FlightHeight(distance: number): number
	return math.clamp(distance * Jump.Flight.HeightFactor, Jump.Flight.MinHeight, Jump.Flight.MaxHeight)
end

function Formulas.ExtraGlideTime(extra: number, base: number): number
	if extra <= 0 then
		return 0
	end
	return math.clamp(Jump.Flight.ExtraGlideMin + (extra / math.max(base, 1)) * 4, Jump.Flight.ExtraGlideMin, Jump.Flight.ExtraGlideMax)
end

function Formulas.ExtraGlideHeight(extra: number): number
	return math.min(extra * Jump.Flight.ExtraGlideHeight, Jump.Flight.ExtraGlideMaxHeight)
end

-- Pozice na hlavní parabole (p = 0..1). Vrací X a Y; Z řídí hráč.
function Formulas.Trajectory(p: number, startX: number, endX: number, startY: number, endY: number, height: number): (number, number)
	local x = startX + (endX - startX) * p
	local y = startY + (endY - startY) * p + height * 4 * p * (1 - p)
	return x, y
end

function Formulas.XPForJump(distance: number): number
	return Levels.XPBase + math.floor(distance / Levels.XPDistanceDivisor)
end

function Formulas.XPToNext(level: number): number
	return Levels.XPPerLevel * level
end

function Formulas.LevelSlots(level: number): number
	local slots = 0
	for milestoneLevel, milestone in Levels.Milestones do
		if milestoneLevel <= level and milestone.Slots then
			slots += milestone.Slots
		end
	end
	return slots
end

function Formulas.TotalSlots(level: number, hasSlotsPass: boolean): number
	local total = House.BaseSlots + Formulas.LevelSlots(level) + (if hasSlotsPass then Products.PassSlots else 0)
	return math.min(total, House.MaxSlots)
end

function Formulas.SpinnerMoneyScale(level: number): number
	return math.max(1, math.floor(level / Spinner.MoneyLevelDivisor))
end

function Formulas.EventMultiplier(now: number): number
	local multiplier = 1
	if Events.WeekendDoubleMoney then
		local weekday = tonumber(os.date("!%w", now)) or 1
		if weekday == 0 or weekday == 6 then
			multiplier *= Events.WeekendMultiplier
		end
	end
	for _, event in Events.Scheduled do
		if now >= event.Start and now < event.End then
			multiplier *= event.IncomeMultiplier
		end
	end
	return multiplier
end

export type MultiplierInput = {
	Rebirths: number,
	HatId: string?,
	DoubleMoneyPass: boolean,
	BoostUntil: number,
	Premium: boolean?,
	Now: number,
}

-- Násobič všech příjmů (znovuzrození, čepice, 2x pass, dočasný boost, událost)
function Formulas.IncomeMultiplier(input: MultiplierInput): number
	local _, incomeBonus = Formulas.HatBonuses(input.HatId)
	local multiplier = (1 + Economy.RebirthIncomeBonus * input.Rebirths) * (1 + incomeBonus)
	if input.DoubleMoneyPass then
		multiplier *= 2
	end
	if input.BoostUntil > input.Now then
		multiplier *= 2
	end
	if input.Premium then
		multiplier *= 1 + Products.PremiumIncomeBonus
	end
	return multiplier * Formulas.EventMultiplier(input.Now)
end

-- Násobič štěstí (pass Lucky Charm × aktivní Lucky Potion)
function Formulas.LuckMultiplier(luckyCharm: boolean, luckUntil: number, now: number): number
	local luck = 1
	if luckyCharm then
		luck *= Products.LuckyCharmLuck
	end
	if luckUntil > now then
		luck *= Products.LuckyPotionLuck
	end
	return luck
end

-- Šance zóny upravené štěstím: nejběžnější rarita v zóně zůstává ×1, nejvzácnější dostane ×luck,
-- ostatní plynule mezi tím (geometricky). Vzácné věci tedy padají až "luck"-krát častěji,
-- ale nic nového se neodemkne (žádná rarita, která v zóně není).
-- orders = pořadí rarit (Order), aby výsledek nezávisel na pořadí v tabulce.
function Formulas.LuckyChances(chances: { [string]: number }, orders: { [string]: number }, luck: number): { [string]: number }
	if luck <= 1 then
		return chances
	end
	local minOrder, maxOrder = math.huge, -math.huge
	for name in chances do
		local order = orders[name] or 1
		minOrder = math.min(minOrder, order)
		maxOrder = math.max(maxOrder, order)
	end
	local result: { [string]: number } = {}
	for name, chance in chances do
		local t = if maxOrder > minOrder then ((orders[name] or 1) - minOrder) / (maxOrder - minOrder) else 0
		result[name] = chance * luck ^ t
	end
	return result
end

function Formulas.ZoneIndex(distance: number): number
	local index = 1
	for i, zone in Catalog.Zones do
		if distance >= zone.MinDistance then
			index = i
		end
	end
	return index
end

function Formulas.SwimSpeed(swimLevel: number, turboFins: boolean): number
	local upgrade = Swim.Upgrades[swimLevel]
	local speed = if upgrade then upgrade.Speed else Swim.BaseSpeed
	return speed * (if turboFins then 1 + Swim.TurboFinsBonus else 1)
end

-- Kdo hráče honí po dopadu v dané vzdálenosti (poslední tier, jehož MinDistance hráč překonal)
function Formulas.ChaserTier(distance: number): Swim.ChaserTier
	local tier = Swim.Chasers[1]
	for _, t in Swim.Chasers do
		if distance >= t.MinDistance then
			tier = t
		end
	end
	return tier
end

-- Tier podle klíče (např. ze serveru); neznámý nebo chybějící klíč = žralok
function Formulas.ChaserByKey(key: any): Swim.ChaserTier
	for _, t in Swim.Chasers do
		if t.Key == key then
			return t
		end
	end
	return Swim.Chasers[1]
end

-- Nejbližší dárkový ostrov, který hráč v tomto životě ještě nezískal (nil = zbývá jen Obří dárek)
function Formulas.NextGiftIsland(claimed: { [string]: boolean }?): any
	for _, island in GiantGift.Islands do
		if not (claimed and claimed[island.Key]) then
			return island
		end
	end
	return nil
end

-- Jak daleko je vor: s lepší plaveckou výbavou a vyšším levelem (delší slalom) o kousek dál
function Formulas.SwimDistance(swimLevel: number, level: number?): number
	local gear = math.min(swimLevel * Swim.DistancePerSwimLevel, Swim.MaxExtraDistance)
	local cfg = Swim.Slalom
	local lv = level or 1
	local slalom = if lv >= cfg.StartLevel then math.min((lv - 1) * cfg.ExtraDistancePerLevel, cfg.MaxExtraLevelDistance) else 0
	return Swim.Distance + gear + slalom
end

-- Slalom pro (efektivní) level hráče – plynule těžší s každým levelem (nil = pod levelem 2, bez slalomu)
function Formulas.SlalomTier(level: number): Swim.SlalomTier?
	local cfg = Swim.Slalom
	if level < cfg.StartLevel then
		return nil
	end
	local l = level - cfg.StartLevel
	local gates = math.min(cfg.GatesBase + math.floor(l / cfg.GatesEvery), cfg.MaxGates)
	local name, color = cfg.Names[1].Name, cfg.Names[1].Color
	for _, entry in cfg.Names do
		if level >= entry.MinLevel then
			name, color = entry.Name, entry.Color
		end
	end
	local moving = if level >= cfg.MovingFromLevel then math.min(1 + math.floor((level - cfg.MovingFromLevel) / 6), math.ceil(gates / 2)) else 0
	-- překážky: počet roste s levelem, druhy se odemykají postupně
	local obstacles: { [string]: number } = {}
	local count = if level >= cfg.ObstaclesFromLevel then math.min(1 + math.floor((level - cfg.ObstaclesFromLevel) / 3), cfg.MaxObstacles) else 0
	local kinds: { string } = {}
	for _, kind in { "Rock", "Jellyfish", "Log", "Puffer" } do
		if level >= (cfg.ObstacleUnlock[kind] or math.huge) then
			table.insert(kinds, kind)
		end
	end
	for i = 1, count do
		-- novější (těžší) druhy se střídají se staršími
		local kind = kinds[#kinds - ((i - 1) % #kinds)]
		obstacles[kind] = (obstacles[kind] or 0) + 1
	end
	return {
		MinLevel = level,
		Name = name,
		Color = color,
		Gates = gates,
		Gap = math.max(cfg.GapStart - l * cfg.GapPerLevel, cfg.MinGap),
		Offset = math.min(cfg.OffsetStart + l * cfg.OffsetPerLevel, cfg.MaxOffset),
		Moving = moving,
		MoveAmp = math.min(2 + level * 0.08, 6),
		MoveSpeed = math.min(0.8 + level * 0.015, 1.6),
		Obstacles = obstacles,
	}
end

function Formulas.SharkSpeed(distance: number): number
	return Formulas.ChaserTier(distance).Speed
end

-- Kde je žralok (studů od místa dopadu směrem k voru) v čase od začátku plavání
function Formulas.SharkProgress(elapsed: number, sharkSpeed: number, delay: number?): number
	return math.max(0, elapsed - (delay or Swim.SharkDelay)) * sharkSpeed
end

function Formulas.SellPrice(itemId: string): number
	local item = Catalog.Item(itemId)
	return if item then item.Income * Economy.SellMultiplier else 0
end

return Formulas

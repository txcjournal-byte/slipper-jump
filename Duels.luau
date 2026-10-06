--!strict
-- CHALLENGE souboje na pláži (2 hráči nebo trénink o samotě):
--  LongJump – olympijský skok do dálky: rozběh, odrazová čára (přešlap = FAUL), písek s metry
--  SandSki  – sjezd z písečné duny mezi praporky a skok z můstku do vody
-- Každý má 3 pokusy (oba běží naráz), počítá se nejlepší. Výsledek = výbava (pantofle, čepice)
-- + načasování odrazu (+ u lyží projeté branky). Odměny dává hra – soupeři se nic nebere.

local World = require(script.Parent.World)

export type GameKey = "LongJump" | "SandSki"

local SAND = World.SandY

local LongJump = {
	Name = "BEACH LONG JUMP",
	Icon = "🏃",
	Z = 300, -- střed areny
	Lanes = { -6, 6 }, -- posun drah od středu
	StartX = World.BeachFrontX - 350, -- začátek rozběhu
	BoardX = World.BeachFrontX - 230, -- odrazová čára
	PitEndX = World.BeachFrontX - 80, -- konec doskočiště
	Y = SAND + 3, -- výška HumanoidRootPart při běhu
	StudsPerMeter = 8,
	RunTime = 2.6, -- jak dlouho trvá rozběh (s)
	FlightTime = 1.0,
	FlightHeight = 7,
	-- metry = BaseMeters + GearMeters × log10(skok s výbavou ve studech)
	BaseMeters = 4.5,
	GearMeters = 1.5,
	RunMetersPerSecond = 10, -- dřívější odraz = kratší skok (o tolik metrů za sekundu)
}

local SandSki = {
	Name = "SAND SKI JUMP",
	Icon = "🏂",
	Z = -300,
	Lanes = { -8, 8 },
	TopX = World.BeachFrontX - 260, -- start nahoře na duně
	TopY = SAND + 40,
	LipX = World.BeachFrontX - 22, -- hrana můstku
	LipY = SAND + 7,
	Y = 3, -- výška HumanoidRootPart nad svahem
	StudsPerMeter = 1.2, -- let nad vodou
	RunTime = 4.2,
	FlightTime = 2.6,
	FlightHeight = 26,
	SteerSpeed = 16, -- studů/s do strany
	LaneHalfWidth = 7,
	-- praporky: kde na svahu (0 = start, 1 = můstek) a jak daleko do strany od středu dráhy
	Gates = {
		{ At = 0.18, Offset = -4 },
		{ At = 0.34, Offset = 4 },
		{ At = 0.5, Offset = -4 },
		{ At = 0.66, Offset = 4 },
		{ At = 0.82, Offset = 0 },
	},
	GateHalfWidth = 2.6,
	BaseMeters = 20,
	GearMeters = 12,
	GateWeight = 0.3, -- projeté branky: 0 % = ×0,7 … 100 % = ×1,0
}

return {
	Games = { LongJump = LongJump, SandSki = SandSki } :: { [string]: any },
	Order = { "LongJump", "SandSki" },
	Attempts = 3,
	CountdownTime = 3,
	PerfectWindow = 0.06, -- odraz do 0,06 s před čárou = PERFECT (+5 %)
	PerfectBonus = 0.05,
	FoulLate = 0.08, -- odraz víc než 0,08 s po čáře = FAUL
	MaxEarly = 0.9, -- odraz dřív než tohle = jen kousek skoku
	InviteTimeout = 15,
	ClientTolerance = 0.4, -- jak moc se smí čas odrazu klienta lišit od serveru
	PromptDistance = 12,
	-- odměny (× level ÷ Quests.MoneyLevelDivisor, min. 1×)
	WinMoney = 3_000,
	WinSpins = 1,
	LoseMoney = 500,
	ChampionTitle = "🏆 CHAMPION",
}

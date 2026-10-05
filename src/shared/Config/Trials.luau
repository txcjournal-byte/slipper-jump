--!strict
-- Úkoly na cestu zpět z dárkových ostrovů (po doskoku na Bronze, Silver a Obří dárek).
-- Dárek hráč dostal už při doskoku – úkol je BONUS navíc (peníze, točení, titulek).
-- Kdo nechce, může se kdykoli vrátit domů zdarma (bez bonusu), nebo si za Robux koupit
-- Easy Path (snazší cesta) či Skip (hned na pláži i s bonusem).

export type Canoe = {
	Distance: number, -- délka trati na vodě
	Speed: number, -- rychlost kánoe (studů/s)
	SlalomLevel: number, -- obtížnost branek a překážek (jako level slalomu)
	Chaser: string, -- kdo honí (klíč z Swim.Chasers)
	ChaserSpeed: number,
	Delay: number, -- za kolik sekund vyrazí pronásledovatel
	Drift: number?, -- bouře: vlny posouvají do stran
}

export type Trial = {
	Key: string,
	Name: string,
	Kind: "Canoe" | "Obby",
	Icon: string,
	Description: string,
	MoneySeconds: number, -- bonus = příjem domečku za X sekund …
	MinMoney: number, -- … ale aspoň tolik
	Spins: number,
	Title: string?,
	Canoe: Canoe?,
}

local Trials: { [string]: Trial } = {
	Bronze = {
		Key = "Bronze",
		Name = "CANOE RACE",
		Kind = "Canoe",
		Icon = "🛶",
		Description = "Paddle the canoe back home! Weave through the buoys - a shark is right behind you!",
		MoneySeconds = 180,
		MinMoney = 20_000,
		Spins = 2,
		Title = "Canoe Champ",
		Canoe = { Distance = 420, Speed = 34, SlalomLevel = 18, Chaser = "Shark", ChaserSpeed = 28, Delay = 3 },
	},
	Silver = {
		Key = "Silver",
		Name = "SKY PATH",
		Kind = "Obby",
		Icon = "🌈",
		Description = "Cross the rainbow path over the sea! Fall in and you go back to the last flag.",
		MoneySeconds = 300,
		MinMoney = 250_000,
		Spins = 3,
		Title = "Sky Walker",
	},
	Giant = {
		Key = "Giant",
		Name = "STORM ESCAPE",
		Kind = "Canoe",
		Icon = "🌪",
		Description = "Escape the Kraken through the storm! The waves push you around - stay in control!",
		MoneySeconds = 600,
		MinMoney = 2_000_000,
		Spins = 5,
		Title = "Island Legend",
		Canoe = { Distance = 520, Speed = 38, SlalomLevel = 40, Chaser = "Kraken", ChaserSpeed = 31, Delay = 3.5, Drift = 7 },
	},
}

return {
	Trials = Trials,
	-- Easy Path (Robux): pomalejší pronásledovatel, širší branky; v dráze návrat jen kousek zpět a tyče nesrazí
	EasyChaserFactor = 0.8,
	EasyGapBonus = 10,
	-- dráha nad mořem (Silver)
	ObbyDeckY = 8, -- výška plošin nad hladinou
	ObbyFallY = 5, -- kořen hráče pod touto výškou = spadl do vody (voda daleko na moři je pevná plocha v y = 0)
	ObbyPlayerHalfHeight = 3, -- HumanoidRootPart nad podlahou
	SweeperHitHeight = 4.6, -- tyč srazí hráče, když je kořen níž než podlaha + tohle
	SweeperHitRadius = 1.8,
}

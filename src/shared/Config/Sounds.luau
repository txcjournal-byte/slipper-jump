--!strict
-- Zvuky: vložte "rbxassetid://123..." z Creator Store (Audio). Prázdný řetězec = zvuk se nehraje.
-- Zatím jsou použité jen zvuky, které jsou přímo součástí Roblox klienta (rbxasset://sounds/...),
-- takže fungují vždy a nic se nemusí nahrávat. Hezčí zvuky z Creator Store je můžou kdykoli nahradit.

local PING = "rbxasset://sounds/electronicpingshort.wav"
-- (rbxasset://sounds/swoosh.wav Roblox nepovolí – "Asset is not approved" – proto svist z Creator Store)
local SWOOSH = "rbxassetid://9126229267"

return {
	-- Hudba: licencovaná hudba z Creator Store (APM Music) – hraje dokola za sebou
	MusicPlaylist = {
		"rbxassetid://1845913205", -- Walking On The Beach (havajské ukulele)
		"rbxassetid://1840007391", -- Lucky 7 (veselá kytara)
	},
	Music = "", -- (staré nastavení jedné skladby; používá se MusicPlaylist)
	Waves = "rbxassetid://99082731841653", -- vlny na pobřeží (smyčka)
	Seagulls = "rbxassetid://9112870701", -- racci v dálce (smyčka, Pro Sound Effects)
	Fanfare = "rbxassetid://9041792228", -- vzácný předmět / dárek (krátká radostná znělka, APM)
	Confetti = "rbxassetid://1839982934", -- velká oslava (funky znělka, APM)

	Splash = "rbxasset://sounds/impact_water.mp3", -- "žbluňk" při dopadu
	Coin = PING,
	Ring = PING,
	Perfect = SWOOSH,
	Good = SWOOSH,
	Squeak = PING, -- Rubber Duck Slippers (vysoký tón)
	Boing = "rbxasset://sounds/action_jump.mp3", -- Spring Slippers
	Buy = PING,
	Click = PING,
	LevelUp = "rbxassetid://9045119921", -- level up (veselá znělka, APM)
	Spin = SWOOSH,
	Takeoff = "rbxassetid://9126229267", -- odraz z mola (svist, Pro Sound Effects)
	Wind = "rbxasset://sounds/action_falling.mp3", -- vítr během letu (smyčka)
	Swim = "rbxasset://sounds/action_swim.mp3", -- tempa při plavání
	Land = "rbxasset://sounds/action_jump_land.mp3", -- doskok na vor
	SharkAlert = PING, -- varování před žralokem (hluboký tón)
	Diamond = PING, -- sebraný diamant (vysoký cinkot)
	Heartbeat = "rbxasset://sounds/action_jump_land.mp3", -- tlukot srdce, když se blíží žralok
	DangerBeep = PING, -- pípání, když je žralok těsně za hráčem

	-- Výchozí výška tónu (když volající žádnou nepředá; jinak se násobí)
	Pitch = {
		Coin = 1.3,
		Ring = 1.6,
		Click = 2,
		Buy = 1.15,
		Squeak = 2.6,
		Good = 1.2,
		Perfect = 0.9,
		Spin = 0.8,
		SharkAlert = 0.45,
		Diamond = 2.3,
		Heartbeat = 0.5,
		DangerBeep = 0.75,
	} :: { [string]: number },
	-- Hlasitost jednotlivých zvuků (násobí SfxVolume)
	Volume = {
		Splash = 1.2,
		Click = 0.5,
		Wind = 0.5,
		Swim = 0.7,
		Waves = 0.45,
		Seagulls = 0.18,
		Fanfare = 0.9,
		LevelUp = 0.9,
		Heartbeat = 1.6,
		DangerBeep = 0.5,
	} :: { [string]: number },

	MusicVolume = 0.3,
	SfxVolume = 0.6,
}

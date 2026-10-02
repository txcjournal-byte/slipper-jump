--!strict
-- Zvuky: vložte "rbxassetid://123..." z Creator Store (Audio). Prázdný řetězec = zvuk se nehraje.
-- Zatím jsou použité jen zvuky, které jsou přímo součástí Roblox klienta (rbxasset://sounds/...),
-- takže fungují vždy a nic se nemusí nahrávat. Hezčí zvuky z Creator Store je můžou kdykoli nahradit.

local PING = "rbxasset://sounds/electronicpingshort.wav"
local SWOOSH = "rbxasset://sounds/swoosh.wav"

return {
	-- Hudba a smyčky: vestavěný klient nic vhodného nemá → vložte ID z Creator Store
	Music = "", -- veselá ukulele hudba (smyčka)
	Waves = "", -- vlny (smyčka)
	Seagulls = "", -- racci (smyčka)
	Fanfare = "", -- vzácný předmět (fanfára) – vložte ID z Creator Store
	Confetti = "", -- „prásk“ konfet – vložte ID z Creator Store

	Splash = "rbxasset://sounds/impact_water.mp3", -- "žbluňk" při dopadu
	Coin = PING,
	Ring = PING,
	Perfect = SWOOSH,
	Good = SWOOSH,
	Squeak = PING, -- Rubber Duck Slippers (vysoký tón)
	Boing = "rbxasset://sounds/action_jump.mp3", -- Spring Slippers
	Buy = PING,
	Click = PING,
	LevelUp = PING,
	Spin = SWOOSH,
	Takeoff = "rbxasset://sounds/action_jump.mp3", -- odraz z mola
	Wind = "rbxasset://sounds/action_falling.mp3", -- vítr během letu (smyčka)
	Swim = "rbxasset://sounds/action_swim.mp3", -- tempa při plavání
	Land = "rbxasset://sounds/action_jump_land.mp3", -- doskok na vor

	-- Výchozí výška tónu (když volající žádnou nepředá; jinak se násobí)
	Pitch = {
		Coin = 1.3,
		Ring = 1.6,
		Click = 2,
		Buy = 1.15,
		LevelUp = 0.8,
		Squeak = 2.6,
		Good = 1.2,
		Perfect = 0.9,
		Spin = 0.8,
		Takeoff = 0.9,
	} :: { [string]: number },
	-- Hlasitost jednotlivých zvuků (násobí SfxVolume)
	Volume = {
		Splash = 1.2,
		Click = 0.5,
		Wind = 0.5,
		Swim = 0.7,
	} :: { [string]: number },

	MusicVolume = 0.35,
	SfxVolume = 0.6,
}

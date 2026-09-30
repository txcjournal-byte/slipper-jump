--!strict
-- Kódy (velikost písmen nerozhoduje). Každý kód jde použít jednou na hráče.
-- Expires = nepovinný os.time(), po kterém kód přestane platit.

export type Code = { Money: number?, Spins: number?, BoostMinutes: number?, Expires: number? }

local Codes: { [string]: Code } = {
	SPLASH = { Money = 500 },
	SLIPPERS = { Spins = 1 },
	BIGGIFT = { BoostMinutes = 15 },
}

return Codes

--!strict
-- Kódy z Config/Codes.luau. Každý kód jde použít jednou na hráče.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Codes = require(Shared.Config.Codes)
local FormatNumber = require(Shared.Util.FormatNumber)
local Net = require(Shared.Net)

local Registry = require(script.Parent.Registry)

local CodeService = {}

local lastAttempt: { [Player]: number } = {}

local function redeem(player: Player, raw: unknown): { Ok: boolean, Message: string }
	local session = Registry.Player.Get(player)
	if not session or type(raw) ~= "string" or #raw > 40 then
		return { Ok = false, Message = "Invalid code." }
	end
	if os.clock() - (lastAttempt[player] or 0) < 1 then
		return { Ok = false, Message = "Slow down!" }
	end
	lastAttempt[player] = os.clock()
	local code = string.upper((string.gsub(raw, "%s", "")))
	local reward = Codes[code]
	if not reward or (reward.Expires and os.time() > reward.Expires) then
		return { Ok = false, Message = "That code doesn't work." }
	end
	if session.Data.UsedCodes[code] then
		return { Ok = false, Message = "You already used this code!" }
	end
	session.Data.UsedCodes[code] = true
	local parts = {}
	if reward.Money then
		Registry.Economy.AddMoney(session, reward.Money)
		table.insert(parts, FormatNumber.Money(reward.Money))
	end
	if reward.Spins then
		Registry.Spinner.AddSpins(session, reward.Spins)
		table.insert(parts, reward.Spins .. " Spin" .. (if reward.Spins > 1 then "s" else ""))
	end
	if reward.BoostMinutes then
		Registry.Economy.AddBoost(session, reward.BoostMinutes)
		table.insert(parts, "2x Money for " .. reward.BoostMinutes .. " min")
	end
	Registry.Player.MarkDirty(session)
	return { Ok = true, Message = "Code redeemed: " .. table.concat(parts, ", ") .. "!" }
end

function CodeService.Start()
	Net.Function("RedeemCode").OnServerInvoke = redeem
end

return CodeService

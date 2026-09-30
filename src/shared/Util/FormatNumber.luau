--!strict
-- Zkracování čísel: 1500 → "1.5K", 2300000 → "2.3M".

local FormatNumber = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx" }

function FormatNumber.Short(value: number): string
	local negative = value < 0
	local n = math.abs(value)
	if n < 1000 then
		local text = if n == math.floor(n) then tostring(math.floor(n)) else string.format("%.1f", n)
		return (if negative then "-" else "") .. text
	end
	local index = 1
	while n >= 1000 and index < #SUFFIXES do
		n /= 1000
		index += 1
	end
	local text: string
	if n >= 100 then
		text = tostring(math.floor(n))
	else
		text = string.format("%.1f", math.floor(n * 10) / 10)
		text = string.gsub(text, "%.0$", "")
	end
	return (if negative then "-" else "") .. text .. SUFFIXES[index]
end

function FormatNumber.Money(value: number): string
	return "$" .. FormatNumber.Short(value)
end

function FormatNumber.Commas(value: number): string
	local text = tostring(math.floor(math.abs(value)))
	local result = text
	while true do
		local replaced, count = string.gsub(result, "^(%d+)(%d%d%d)", "%1,%2")
		result = replaced
		if count == 0 then
			break
		end
	end
	return (if value < 0 then "-" else "") .. result
end

function FormatNumber.Studs(value: number): string
	if value < 10_000 then
		return FormatNumber.Commas(value) .. " studs"
	end
	return FormatNumber.Short(value) .. " studs"
end

function FormatNumber.Time(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local h = s // 3600
	local m = (s % 3600) // 60
	local sec = s % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, sec)
	end
	return string.format("%d:%02d", m, sec)
end

return FormatNumber

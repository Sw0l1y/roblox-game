-- Number and time formatting for HUDs: 1.2K, 34.5M, 1:05.
local Fmt = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Fmt.num(n: number): string
	if n ~= n then
		return "0"
	end
	local neg = n < 0
	n = math.abs(n)
	local i = 1
	while n >= 1000 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	local s
	if i == 1 then
		s = tostring(math.floor(n))
	elseif n < 10 then
		s = string.format("%.2f", math.floor(n * 100) / 100):gsub("%.?0+$", "")
	elseif n < 100 then
		s = string.format("%.1f", math.floor(n * 10) / 10):gsub("%.0$", "")
	else
		s = tostring(math.floor(n))
	end
	return (neg and "-" or "") .. s .. SUFFIXES[i]
end

function Fmt.commas(n: number): string
	local s = tostring(math.floor(math.abs(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return (n < 0 and "-" or "") .. out
end

function Fmt.time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = math.floor(seconds / 3600)
	local m = math.floor(seconds % 3600 / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%dh %02dm", h, m)
	end
	return string.format("%d:%02d", m, s)
end

function Fmt.pct(f: number): string
	return tostring(math.floor(f * 100 + 0.5)) .. "%"
end

return Fmt

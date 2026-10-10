-- JSON encode/decode (HttpService rules) for the simulator.
local R = ...
local nativeType = type

local escapes = { ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
local function encodeString(s)
	return '"' .. s:gsub('[%c"\\]', function(c)
		return escapes[c] or string.format("\\u%04x", string.byte(c))
	end) .. '"'
end

local function encode(v, seen, strict)
	local t = nativeType(v)
	if v == nil then
		return "null"
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then
			if strict then
				error("Can't convert to JSON (NaN/inf)", 0)
			end
			return "null"
		end
		if v == math.floor(v) and math.abs(v) < 1e15 then
			return string.format("%d", v)
		end
		return string.format("%.14g", v)
	elseif t == "string" then
		return encodeString(v)
	elseif t == "table" then
		if getmetatable(v) and R.TYPENAME[getmetatable(v)] then
			if strict then
				error("Can't convert to JSON: " .. R.typeof(v), 0)
			end
			return encodeString(tostring(v))
		end
		if seen[v] then
			error("Can't convert to JSON: cyclic table", 0)
		end
		seen[v] = true
		local n = #v
		local isArray = true
		local count = 0
		for k in pairs(v) do
			count += 1
			if nativeType(k) ~= "number" or k < 1 or k > n or k % 1 ~= 0 then
				isArray = false
			end
		end
		local out = {}
		if isArray and (n > 0 or count == 0) then
			for i = 1, n do
				out[i] = encode(v[i], seen, strict)
			end
			seen[v] = nil
			return "[" .. table.concat(out, ",") .. "]"
		end
		local keys = {}
		for k in pairs(v) do
			table.insert(keys, k)
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		for _, k in ipairs(keys) do
			table.insert(out, encodeString(tostring(k)) .. ":" .. encode(v[k], seen, strict))
		end
		seen[v] = nil
		return "{" .. table.concat(out, ",") .. "}"
	elseif t == "userdata" and R.isInstance(v) then
		if strict then
			error("Can't convert to JSON: Instance", 0)
		end
		return encodeString(R.fullName(v))
	end
	if strict then
		error("Can't convert to JSON: " .. R.typeof(v), 0)
	end
	return encodeString(tostring(v))
end
function R.jsonEncode(v)
	return encode(v, {}, true)
end
function R.jsonEncodeLoose(v)
	return encode(v, {}, false)
end

function R.jsonDecode(str)
	if nativeType(str) ~= "string" then
		error("Can't parse JSON", 2)
	end
	local pos = 1
	local function ws()
		pos = str:find("[^ \t\r\n]", pos) or #str + 1
	end
	local value
	local function err(m)
		error("Can't parse JSON: " .. m .. " at " .. pos, 0)
	end
	local function parseString()
		pos += 1
		local out = {}
		while true do
			local c = str:sub(pos, pos)
			if c == "" then
				err("unterminated string")
			elseif c == '"' then
				pos += 1
				break
			elseif c == "\\" then
				local n = str:sub(pos + 1, pos + 1)
				local map = { b = "\b", f = "\f", n = "\n", r = "\r", t = "\t", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
				if map[n] then
					table.insert(out, map[n])
					pos += 2
				elseif n == "u" then
					local hex = str:sub(pos + 2, pos + 5)
					table.insert(out, utf8.char(tonumber(hex, 16) or 63))
					pos += 6
				else
					err("bad escape")
				end
			else
				table.insert(out, c)
				pos += 1
			end
		end
		return table.concat(out)
	end
	function value()
		ws()
		local c = str:sub(pos, pos)
		if c == "{" then
			pos += 1
			local obj = {}
			ws()
			if str:sub(pos, pos) == "}" then
				pos += 1
				return obj
			end
			while true do
				ws()
				if str:sub(pos, pos) ~= '"' then
					err("expected key")
				end
				local k = parseString()
				ws()
				if str:sub(pos, pos) ~= ":" then
					err("expected :")
				end
				pos += 1
				obj[k] = value()
				ws()
				local d = str:sub(pos, pos)
				pos += 1
				if d == "}" then
					break
				elseif d ~= "," then
					err("expected , or }")
				end
			end
			return obj
		elseif c == "[" then
			pos += 1
			local arr = {}
			ws()
			if str:sub(pos, pos) == "]" then
				pos += 1
				return arr
			end
			while true do
				table.insert(arr, value())
				ws()
				local d = str:sub(pos, pos)
				pos += 1
				if d == "]" then
					break
				elseif d ~= "," then
					err("expected , or ]")
				end
			end
			return arr
		elseif c == '"' then
			return parseString()
		elseif str:sub(pos, pos + 3) == "true" then
			pos += 4
			return true
		elseif str:sub(pos, pos + 4) == "false" then
			pos += 5
			return false
		elseif str:sub(pos, pos + 3) == "null" then
			pos += 4
			return nil
		end
		local num = str:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
		if num and #num > 0 then
			pos += #num
			return tonumber(num)
		end
		err("unexpected '" .. c .. "'")
		return nil
	end
	local v = value()
	return v
end

return true

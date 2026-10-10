-- Roblox datatypes for the headless simulator: Vector3, Vector2, CFrame, Color3, UDim/UDim2, Rect, ranges,
-- sequences, TweenInfo, Random, BrickColor, Ray, Font, Content, DateTime, Raycast/OverlapParams and more.
-- Every value is a table with a shared metatable; R.TYPENAME maps metatables to typeof() names.
local R = ...
R.TYPENAME = R.TYPENAME or {}
local TYPENAME = R.TYPENAME
local G = R.G -- globals exposed to game scripts

local sqrt, abs, sin, cos, atan2, asin, acos = math.sqrt, math.abs, math.sin, math.cos, math.atan2, math.asin, math.acos
local floor = math.floor

local function badMember(tname, k)
	error(string.format("%s is not a valid member of %s", tostring(k), tname), 3)
end

local function fmt(n: number): string
	if n == floor(n) and abs(n) < 1e15 then
		return string.format("%d", n)
	end
	return string.format("%.7g", n)
end

local function typeErr(fname, idx, expected, got)
	error(string.format("invalid argument #%d to '%s' (%s expected, got %s)", idx, fname, expected, R.typeof(got)), 3)
end

local function num(v, fname, idx, default)
	if v == nil then
		if default ~= nil then
			return default
		end
		typeErr(fname, idx, "number", v)
	end
	if type(v) == "number" then
		return v
	end
	local n = tonumber(v)
	if n then
		return n
	end
	typeErr(fname, idx, "number", v)
	return 0
end

---------------------------------------------------------------------------------------------------- Vector3
local V3 = {}
TYPENAME[V3] = "Vector3"
R.V3MT = V3
local function v3(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, V3)
end
R.v3 = v3
local function isV3(v)
	return getmetatable(v) == V3
end
R.isV3 = isV3

local V3methods = {}
function V3methods.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function V3methods.Cross(a, b)
	return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function V3methods.Lerp(a, b, t)
	return v3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t)
end
function V3methods.FuzzyEq(a, b, eps)
	eps = eps or 1e-5
	return abs(a.X - b.X) <= eps and abs(a.Y - b.Y) <= eps and abs(a.Z - b.Z) <= eps
end
function V3methods.Abs(a)
	return v3(abs(a.X), abs(a.Y), abs(a.Z))
end
function V3methods.Ceil(a)
	return v3(math.ceil(a.X), math.ceil(a.Y), math.ceil(a.Z))
end
function V3methods.Floor(a)
	return v3(floor(a.X), floor(a.Y), floor(a.Z))
end
function V3methods.Sign(a)
	return v3(math.sign(a.X), math.sign(a.Y), math.sign(a.Z))
end
function V3methods.Max(a, ...)
	local x, y, z = a.X, a.Y, a.Z
	for _, b in ipairs({ ... }) do
		x, y, z = math.max(x, b.X), math.max(y, b.Y), math.max(z, b.Z)
	end
	return v3(x, y, z)
end
function V3methods.Min(a, ...)
	local x, y, z = a.X, a.Y, a.Z
	for _, b in ipairs({ ... }) do
		x, y, z = math.min(x, b.X), math.min(y, b.Y), math.min(z, b.Z)
	end
	return v3(x, y, z)
end
function V3methods.Angle(a, b, axis)
	local m = sqrt(V3methods.Dot(a, a) * V3methods.Dot(b, b))
	if m == 0 then
		return 0
	end
	local ang = acos(math.clamp(V3methods.Dot(a, b) / m, -1, 1))
	if axis and V3methods.Dot(V3methods.Cross(a, b), axis) < 0 then
		ang = -ang
	end
	return ang
end
V3.__index = function(v, k)
	if k == "Magnitude" or k == "magnitude" then
		return sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" or k == "unit" then
		local m = sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		if m == 0 then
			return v3(0 / 0, 0 / 0, 0 / 0)
		end
		return v3(v.X / m, v.Y / m, v.Z / m)
	elseif k == "x" then
		return v.X
	elseif k == "y" then
		return v.Y
	elseif k == "z" then
		return v.Z
	end
	local m = V3methods[k]
	if m then
		return m
	end
	badMember("Vector3", k)
end
V3.__newindex = function(_, k)
	error(tostring(k) .. " cannot be assigned to", 2)
end
V3.__add = function(a, b)
	if not isV3(a) or not isV3(b) then
		error("attempt to perform arithmetic (add) on " .. R.typeof(a) .. " and " .. R.typeof(b), 2)
	end
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	if not isV3(a) or not isV3(b) then
		error("attempt to perform arithmetic (sub) on " .. R.typeof(a) .. " and " .. R.typeof(b), 2)
	end
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	elseif isV3(a) and isV3(b) then
		return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
	end
	error("attempt to perform arithmetic (mul) on " .. R.typeof(a) .. " and " .. R.typeof(b), 2)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	elseif type(a) == "number" then
		return v3(a / b.X, a / b.Y, a / b.Z)
	elseif isV3(a) and isV3(b) then
		return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
	end
	error("attempt to perform arithmetic (div) on " .. R.typeof(a) .. " and " .. R.typeof(b), 2)
end
V3.__idiv = function(a, b)
	local q = V3.__div(a, b)
	return v3(floor(q.X), floor(q.Y), floor(q.Z))
end
V3.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3.__tostring = function(v)
	return fmt(v.X) .. ", " .. fmt(v.Y) .. ", " .. fmt(v.Z)
end

local NORMALS = { Right = { 1, 0, 0 }, Top = { 0, 1, 0 }, Back = { 0, 0, 1 }, Left = { -1, 0, 0 }, Bottom = { 0, -1, 0 }, Front = { 0, 0, -1 } }
G.Vector3 = {
	new = function(x, y, z)
		return v3(num(x, "Vector3.new", 1, 0), num(y, "Vector3.new", 2, 0), num(z, "Vector3.new", 3, 0))
	end,
	zero = v3(0, 0, 0),
	one = v3(1, 1, 1),
	xAxis = v3(1, 0, 0),
	yAxis = v3(0, 1, 0),
	zAxis = v3(0, 0, 1),
	FromNormalId = function(n)
		local t = NORMALS[n.Name]
		return v3(t[1], t[2], t[3])
	end,
	FromAxis = function(a)
		local n = a.Name
		return n == "X" and v3(1, 0, 0) or n == "Y" and v3(0, 1, 0) or v3(0, 0, 1)
	end,
}
G.Vector3int16 = { new = function(x, y, z)
	return v3(floor(x or 0), floor(y or 0), floor(z or 0))
end }

---------------------------------------------------------------------------------------------------- Vector2
local V2 = {}
TYPENAME[V2] = "Vector2"
local function v2(x, y)
	return setmetatable({ X = x, Y = y }, V2)
end
R.v2 = v2
local function isV2(v)
	return getmetatable(v) == V2
end
local V2methods = {
	Dot = function(a, b)
		return a.X * b.X + a.Y * b.Y
	end,
	Cross = function(a, b)
		return a.X * b.Y - a.Y * b.X
	end,
	Lerp = function(a, b, t)
		return v2(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t)
	end,
	FuzzyEq = function(a, b, eps)
		eps = eps or 1e-5
		return abs(a.X - b.X) <= eps and abs(a.Y - b.Y) <= eps
	end,
	Abs = function(a)
		return v2(abs(a.X), abs(a.Y))
	end,
	Ceil = function(a)
		return v2(math.ceil(a.X), math.ceil(a.Y))
	end,
	Floor = function(a)
		return v2(floor(a.X), floor(a.Y))
	end,
	Sign = function(a)
		return v2(math.sign(a.X), math.sign(a.Y))
	end,
	Max = function(a, b)
		return v2(math.max(a.X, b.X), math.max(a.Y, b.Y))
	end,
	Min = function(a, b)
		return v2(math.min(a.X, b.X), math.min(a.Y, b.Y))
	end,
	Angle = function(a, b, signed)
		local ang = atan2(a.X * b.Y - a.Y * b.X, a.X * b.X + a.Y * b.Y)
		return signed and ang or abs(ang)
	end,
}
V2.__index = function(v, k)
	if k == "Magnitude" or k == "magnitude" then
		return sqrt(v.X * v.X + v.Y * v.Y)
	elseif k == "Unit" or k == "unit" then
		local m = sqrt(v.X * v.X + v.Y * v.Y)
		return v2(v.X / m, v.Y / m)
	elseif k == "x" then
		return v.X
	elseif k == "y" then
		return v.Y
	end
	local m = V2methods[k]
	if m then
		return m
	end
	badMember("Vector2", k)
end
V2.__newindex = V3.__newindex
V2.__add = function(a, b)
	return v2(a.X + b.X, a.Y + b.Y)
end
V2.__sub = function(a, b)
	return v2(a.X - b.X, a.Y - b.Y)
end
V2.__mul = function(a, b)
	if type(a) == "number" then
		return v2(a * b.X, a * b.Y)
	elseif type(b) == "number" then
		return v2(a.X * b, a.Y * b)
	end
	return v2(a.X * b.X, a.Y * b.Y)
end
V2.__div = function(a, b)
	if type(b) == "number" then
		return v2(a.X / b, a.Y / b)
	elseif type(a) == "number" then
		return v2(a / b.X, a / b.Y)
	end
	return v2(a.X / b.X, a.Y / b.Y)
end
V2.__idiv = function(a, b)
	local q = V2.__div(a, b)
	return v2(floor(q.X), floor(q.Y))
end
V2.__unm = function(a)
	return v2(-a.X, -a.Y)
end
V2.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
V2.__tostring = function(v)
	return fmt(v.X) .. ", " .. fmt(v.Y)
end
G.Vector2 = {
	new = function(x, y)
		return v2(num(x, "Vector2.new", 1, 0), num(y, "Vector2.new", 2, 0))
	end,
	zero = v2(0, 0),
	one = v2(1, 1),
	xAxis = v2(1, 0),
	yAxis = v2(0, 1),
}
G.Vector2int16 = { new = function(x, y)
	return v2(floor(x or 0), floor(y or 0))
end }
R.isV2 = isV2

---------------------------------------------------------------------------------------------------- CFrame
-- Fields: X, Y, Z position and rotation matrix R00..R22 (rows).
local CF = {}
TYPENAME[CF] = "CFrame"
local function cf(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
	return setmetatable({
		X = x, Y = y, Z = z,
		R00 = r00, R01 = r01, R02 = r02,
		R10 = r10, R11 = r11, R12 = r12,
		R20 = r20, R21 = r21, R22 = r22,
	}, CF)
end
R.cf = cf
local function isCF(v)
	return getmetatable(v) == CF
end
R.isCF = isCF

local function mul(a, b) -- CFrame * CFrame
	return cf(
		a.R00 * b.X + a.R01 * b.Y + a.R02 * b.Z + a.X,
		a.R10 * b.X + a.R11 * b.Y + a.R12 * b.Z + a.Y,
		a.R20 * b.X + a.R21 * b.Y + a.R22 * b.Z + a.Z,
		a.R00 * b.R00 + a.R01 * b.R10 + a.R02 * b.R20, a.R00 * b.R01 + a.R01 * b.R11 + a.R02 * b.R21, a.R00 * b.R02 + a.R01 * b.R12 + a.R02 * b.R22,
		a.R10 * b.R00 + a.R11 * b.R10 + a.R12 * b.R20, a.R10 * b.R01 + a.R11 * b.R11 + a.R12 * b.R21, a.R10 * b.R02 + a.R11 * b.R12 + a.R12 * b.R22,
		a.R20 * b.R00 + a.R21 * b.R10 + a.R22 * b.R20, a.R20 * b.R01 + a.R21 * b.R11 + a.R22 * b.R21, a.R20 * b.R02 + a.R21 * b.R12 + a.R22 * b.R22
	)
end
local function point(a, v)
	return v3(a.R00 * v.X + a.R01 * v.Y + a.R02 * v.Z + a.X, a.R10 * v.X + a.R11 * v.Y + a.R12 * v.Z + a.Y, a.R20 * v.X + a.R21 * v.Y + a.R22 * v.Z + a.Z)
end
local function vec(a, v)
	return v3(a.R00 * v.X + a.R01 * v.Y + a.R02 * v.Z, a.R10 * v.X + a.R11 * v.Y + a.R12 * v.Z, a.R20 * v.X + a.R21 * v.Y + a.R22 * v.Z)
end
local function inverse(a)
	-- rotation is orthonormal: inverse = transpose
	local x, y, z = a.X, a.Y, a.Z
	return cf(
		-(a.R00 * x + a.R10 * y + a.R20 * z), -(a.R01 * x + a.R11 * y + a.R21 * z), -(a.R02 * x + a.R12 * y + a.R22 * z),
		a.R00, a.R10, a.R20,
		a.R01, a.R11, a.R21,
		a.R02, a.R12, a.R22
	)
end
R.cfMul, R.cfPoint, R.cfVec, R.cfInv = mul, point, vec, inverse

-- Re-square the rotation (Gram-Schmidt on the columns), as Roblox does when a part's CFrame is stored,
-- so float error from repeated multiplies can't grow into skew.
function R.cfOrtho(a)
	local ax, ay, az = a.R00, a.R10, a.R20
	local m = sqrt(ax * ax + ay * ay + az * az)
	if m < 1e-9 or m ~= m then
		return a
	end
	ax, ay, az = ax / m, ay / m, az / m
	local bx, by, bz = a.R01, a.R11, a.R21
	local d = ax * bx + ay * by + az * bz
	bx, by, bz = bx - d * ax, by - d * ay, bz - d * az
	m = sqrt(bx * bx + by * by + bz * bz)
	if m < 1e-9 then
		return a
	end
	bx, by, bz = bx / m, by / m, bz / m
	local cx, cy, cz = ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
	if math.abs(ax - a.R00) + math.abs(by - a.R11) + math.abs(cz - a.R22) + math.abs(bx - a.R01) + math.abs(cx - a.R02) + math.abs(cy - a.R12) < 1e-12 then
		return a
	end
	return cf(a.X, a.Y, a.Z, ax, bx, cx, ay, by, cy, az, bz, cz)
end

local function fromQuat(x, y, z, qx, qy, qz, qw)
	local m = sqrt(qx * qx + qy * qy + qz * qz + qw * qw)
	if m == 0 then
		return cf(x, y, z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	end
	qx, qy, qz, qw = qx / m, qy / m, qz / m, qw / m
	return cf(x, y, z,
		1 - 2 * (qy * qy + qz * qz), 2 * (qx * qy - qz * qw), 2 * (qx * qz + qy * qw),
		2 * (qx * qy + qz * qw), 1 - 2 * (qx * qx + qz * qz), 2 * (qy * qz - qx * qw),
		2 * (qx * qz - qy * qw), 2 * (qy * qz + qx * qw), 1 - 2 * (qx * qx + qy * qy))
end
local function toQuat(a)
	local t = a.R00 + a.R11 + a.R22
	local qw, qx, qy, qz
	if t > 0 then
		local s = sqrt(t + 1) * 2
		qw, qx, qy, qz = 0.25 * s, (a.R21 - a.R12) / s, (a.R02 - a.R20) / s, (a.R10 - a.R01) / s
	elseif a.R00 > a.R11 and a.R00 > a.R22 then
		local s = sqrt(1 + a.R00 - a.R11 - a.R22) * 2
		qw, qx, qy, qz = (a.R21 - a.R12) / s, 0.25 * s, (a.R01 + a.R10) / s, (a.R02 + a.R20) / s
	elseif a.R11 > a.R22 then
		local s = sqrt(1 + a.R11 - a.R00 - a.R22) * 2
		qw, qx, qy, qz = (a.R02 - a.R20) / s, (a.R01 + a.R10) / s, 0.25 * s, (a.R12 + a.R21) / s
	else
		local s = sqrt(1 + a.R22 - a.R00 - a.R11) * 2
		qw, qx, qy, qz = (a.R10 - a.R01) / s, (a.R02 + a.R20) / s, (a.R12 + a.R21) / s, 0.25 * s
	end
	return qx, qy, qz, qw
end

local function angles(rx, ry, rz) -- Rx * Ry * Rz
	local cx, sx, cy, sy, cz, sz = cos(rx), sin(rx), cos(ry), sin(ry), cos(rz), sin(rz)
	return cf(0, 0, 0,
		cy * cz, -cy * sz, sy,
		cx * sz + sx * sy * cz, cx * cz - sx * sy * sz, -sx * cy,
		sx * sz - cx * sy * cz, sx * cz + cx * sy * sz, cx * cy)
end
local function anglesYXZ(rx, ry, rz) -- Ry * Rx * Rz
	local cx, sx, cy, sy, cz, sz = cos(rx), sin(rx), cos(ry), sin(ry), cos(rz), sin(rz)
	return cf(0, 0, 0,
		cy * cz + sy * sx * sz, -cy * sz + sy * sx * cz, sy * cx,
		cx * sz, cx * cz, -sx,
		-sy * cz + cy * sx * sz, sy * sz + cy * sx * cz, cy * cx)
end
R.anglesYXZ = anglesYXZ

local function lookAt(at, target, up)
	up = up or v3(0, 1, 0)
	local f = target - at
	local m = f.Magnitude
	if m < 1e-9 then
		return cf(at.X, at.Y, at.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	end
	f = f / m
	local r = f:Cross(up)
	if r.Magnitude < 1e-6 then
		r = f:Cross(v3(0, 0, 1))
		if r.Magnitude < 1e-6 then
			r = f:Cross(v3(1, 0, 0))
		end
	end
	r = r.Unit
	local u = r:Cross(f)
	-- columns: right, up, back(-look)
	return cf(at.X, at.Y, at.Z, r.X, u.X, -f.X, r.Y, u.Y, -f.Y, r.Z, u.Z, -f.Z)
end

local function fromMatrix(pos, vx, vy, vz)
	if not vz then
		vz = vx:Cross(vy).Unit
	end
	return cf(pos.X, pos.Y, pos.Z, vx.X, vy.X, vz.X, vx.Y, vy.Y, vz.Y, vx.Z, vy.Z, vz.Z)
end

local function axisAngle(axis, ang)
	local u = axis.Unit
	local s = sin(ang / 2)
	return fromQuat(0, 0, 0, u.X * s, u.Y * s, u.Z * s, cos(ang / 2))
end

local CFmethods = {}
function CFmethods.Inverse(a)
	return inverse(a)
end
function CFmethods.Lerp(a, b, t)
	local ax, ay, az, aw = toQuat(a)
	local bx, by, bz, bw = toQuat(b)
	local d = ax * bx + ay * by + az * bz + aw * bw
	if d < 0 then
		bx, by, bz, bw, d = -bx, -by, -bz, -bw, -d
	end
	local qx, qy, qz, qw
	if d > 0.9995 then
		qx, qy, qz, qw = ax + (bx - ax) * t, ay + (by - ay) * t, az + (bz - az) * t, aw + (bw - aw) * t
	else
		local th = acos(d)
		local s = sin(th)
		local wa, wb = sin((1 - t) * th) / s, sin(t * th) / s
		qx, qy, qz, qw = ax * wa + bx * wb, ay * wa + by * wb, az * wa + bz * wb, aw * wa + bw * wb
	end
	return fromQuat(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t, qx, qy, qz, qw)
end
function CFmethods.ToWorldSpace(a, ...)
	local out = {}
	for i, b in ipairs({ ... }) do
		out[i] = mul(a, b)
	end
	return table.unpack(out)
end
function CFmethods.ToObjectSpace(a, ...)
	local inv = inverse(a)
	local out = {}
	for i, b in ipairs({ ... }) do
		out[i] = mul(inv, b)
	end
	return table.unpack(out)
end
function CFmethods.PointToWorldSpace(a, ...)
	local out = {}
	for i, v in ipairs({ ... }) do
		out[i] = point(a, v)
	end
	return table.unpack(out)
end
function CFmethods.PointToObjectSpace(a, ...)
	local inv = inverse(a)
	local out = {}
	for i, v in ipairs({ ... }) do
		out[i] = point(inv, v)
	end
	return table.unpack(out)
end
function CFmethods.VectorToWorldSpace(a, ...)
	local out = {}
	for i, v in ipairs({ ... }) do
		out[i] = vec(a, v)
	end
	return table.unpack(out)
end
function CFmethods.VectorToObjectSpace(a, ...)
	local inv = inverse(a)
	local out = {}
	for i, v in ipairs({ ... }) do
		out[i] = vec(inv, v)
	end
	return table.unpack(out)
end
function CFmethods.GetComponents(a)
	return a.X, a.Y, a.Z, a.R00, a.R01, a.R02, a.R10, a.R11, a.R12, a.R20, a.R21, a.R22
end
CFmethods.components = CFmethods.GetComponents
function CFmethods.ToEulerAnglesXYZ(a)
	local ry = asin(math.clamp(a.R02, -1, 1))
	local rx = atan2(-a.R12, a.R22)
	local rz = atan2(-a.R01, a.R00)
	return rx, ry, rz
end
function CFmethods.ToEulerAnglesYXZ(a)
	local rx = asin(math.clamp(-a.R12, -1, 1))
	local ry = atan2(a.R02, a.R22)
	local rz = atan2(a.R10, a.R11)
	return rx, ry, rz
end
CFmethods.ToOrientation = CFmethods.ToEulerAnglesYXZ
function CFmethods.ToAxisAngle(a)
	local qx, qy, qz, qw = toQuat(a)
	local ang = 2 * acos(math.clamp(qw, -1, 1))
	local s = sqrt(math.max(0, 1 - qw * qw))
	if s < 1e-6 then
		return v3(1, 0, 0), 0
	end
	return v3(qx / s, qy / s, qz / s), ang
end
function CFmethods.Orthonormalize(a)
	return fromMatrix(v3(a.X, a.Y, a.Z), v3(a.R00, a.R10, a.R20).Unit, v3(a.R01, a.R11, a.R21).Unit)
end
function CFmethods.FuzzyEq(a, b, eps)
	eps = eps or 1e-5
	for _, k in ipairs({ "X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22" }) do
		if abs(a[k] - b[k]) > eps then
			return false
		end
	end
	return true
end
function CFmethods.AngleBetween(a, b)
	local _, ang = CFmethods.ToAxisAngle(mul(inverse(a), b))
	return ang
end

CF.__index = function(a, k)
	if k == "Position" or k == "p" then
		return v3(a.X, a.Y, a.Z)
	elseif k == "LookVector" or k == "lookVector" then
		return v3(-a.R02, -a.R12, -a.R22)
	elseif k == "RightVector" or k == "rightVector" or k == "XVector" then
		return v3(a.R00, a.R10, a.R20)
	elseif k == "UpVector" or k == "upVector" or k == "YVector" then
		return v3(a.R01, a.R11, a.R21)
	elseif k == "ZVector" then
		return v3(a.R02, a.R12, a.R22)
	elseif k == "Rotation" then
		return cf(0, 0, 0, a.R00, a.R01, a.R02, a.R10, a.R11, a.R12, a.R20, a.R21, a.R22)
	elseif k == "x" then
		return a.X
	elseif k == "y" then
		return a.Y
	elseif k == "z" then
		return a.Z
	end
	local m = CFmethods[k]
	if m then
		return m
	end
	badMember("CFrame", k)
end
CF.__newindex = V3.__newindex
CF.__mul = function(a, b)
	if isCF(b) then
		return mul(a, b)
	elseif isV3(b) then
		return point(a, b)
	end
	error("invalid argument #2 to '__mul' (CFrame or Vector3 expected, got " .. R.typeof(b) .. ")", 2)
end
CF.__add = function(a, b)
	if not isV3(b) then
		error("invalid argument #2 to '__add' (Vector3 expected, got " .. R.typeof(b) .. ")", 2)
	end
	return cf(a.X + b.X, a.Y + b.Y, a.Z + b.Z, a.R00, a.R01, a.R02, a.R10, a.R11, a.R12, a.R20, a.R21, a.R22)
end
CF.__sub = function(a, b)
	if not isV3(b) then
		error("invalid argument #2 to '__sub' (Vector3 expected, got " .. R.typeof(b) .. ")", 2)
	end
	return cf(a.X - b.X, a.Y - b.Y, a.Z - b.Z, a.R00, a.R01, a.R02, a.R10, a.R11, a.R12, a.R20, a.R21, a.R22)
end
CF.__eq = function(a, b)
	return CFmethods.FuzzyEq(a, b, 0)
end
CF.__tostring = function(a)
	local t = { a:GetComponents() }
	for i, v in ipairs(t) do
		t[i] = fmt(v)
	end
	return table.concat(t, ", ")
end

local IDENT = cf(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
R.CF_IDENTITY = IDENT
G.CFrame = {
	new = function(...)
		local n = select("#", ...)
		local a, b = ...
		if n == 0 then
			return IDENT
		elseif n == 1 then
			if not isV3(a) then
				typeErr("CFrame.new", 1, "Vector3", a)
			end
			return cf(a.X, a.Y, a.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
		elseif n == 2 and isV3(a) and isV3(b) then
			return lookAt(a, b)
		elseif n == 3 then
			return cf(num(a, "CFrame.new", 1), num(b, "CFrame.new", 2), num(select(3, ...), "CFrame.new", 3), 1, 0, 0, 0, 1, 0, 0, 0, 1)
		elseif n == 7 then
			return fromQuat(...)
		elseif n == 12 then
			return cf(...)
		end
		error("Invalid number of arguments: " .. n, 2)
	end,
	Angles = function(rx, ry, rz)
		return angles(num(rx, "CFrame.Angles", 1, 0), num(ry, "CFrame.Angles", 2, 0), num(rz, "CFrame.Angles", 3, 0))
	end,
	fromEulerAnglesXYZ = function(rx, ry, rz)
		return angles(rx or 0, ry or 0, rz or 0)
	end,
	fromEulerAnglesYXZ = function(rx, ry, rz)
		return anglesYXZ(rx or 0, ry or 0, rz or 0)
	end,
	fromEulerAngles = function(rx, ry, rz, order)
		if order and order.Name == "YXZ" then
			return anglesYXZ(rx, ry, rz)
		end
		return angles(rx, ry, rz)
	end,
	fromOrientation = function(rx, ry, rz)
		return anglesYXZ(rx or 0, ry or 0, rz or 0)
	end,
	lookAt = function(at, target, up)
		return lookAt(at, target, up)
	end,
	lookAlong = function(at, dir, up)
		return lookAt(at, at + dir, up)
	end,
	fromMatrix = fromMatrix,
	fromAxisAngle = function(axis, ang)
		return axisAngle(axis, ang)
	end,
	identity = IDENT,
}

---------------------------------------------------------------------------------------------------- Color3
local C3 = {}
TYPENAME[C3] = "Color3"
local function c3(r, g, b)
	return setmetatable({ R = r, G = g, B = b }, C3)
end
R.c3 = c3
local function toHSV(c)
	local r, g, b = c.R, c.G, c.B
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	local d = mx - mn
	local h = 0
	if d > 0 then
		if mx == r then
			h = ((g - b) / d) % 6
		elseif mx == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h = h / 6
	end
	local s = mx == 0 and 0 or d / mx
	return h, s, mx
end
local function fromHSV(h, s, v)
	h = (h % 1) * 6
	local i = floor(h)
	local f = h - i
	local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
	if i == 0 then
		return c3(v, t, p)
	elseif i == 1 then
		return c3(q, v, p)
	elseif i == 2 then
		return c3(p, v, t)
	elseif i == 3 then
		return c3(p, q, v)
	elseif i == 4 then
		return c3(t, p, v)
	end
	return c3(v, p, q)
end
local C3methods = {
	Lerp = function(a, b, t)
		return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
	end,
	ToHSV = toHSV,
	ToHex = function(c)
		return string.format("%02X%02X%02X", math.clamp(floor(c.R * 255 + 0.5), 0, 255), math.clamp(floor(c.G * 255 + 0.5), 0, 255), math.clamp(floor(c.B * 255 + 0.5), 0, 255))
	end,
}
C3.__index = function(c, k)
	if k == "r" then
		return c.R
	elseif k == "g" then
		return c.G
	elseif k == "b" then
		return c.B
	end
	local m = C3methods[k]
	if m then
		return m
	end
	badMember("Color3", k)
end
C3.__newindex = V3.__newindex
C3.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end
C3.__tostring = function(c)
	return fmt(c.R) .. ", " .. fmt(c.G) .. ", " .. fmt(c.B)
end
G.Color3 = {
	new = function(r, g, b)
		return c3(num(r, "Color3.new", 1, 0), num(g, "Color3.new", 2, 0), num(b, "Color3.new", 3, 0))
	end,
	fromRGB = function(r, g, b)
		return c3(num(r, "Color3.fromRGB", 1, 0) / 255, num(g, "Color3.fromRGB", 2, 0) / 255, num(b, "Color3.fromRGB", 3, 0) / 255)
	end,
	fromHSV = function(h, s, v)
		return fromHSV(num(h, "Color3.fromHSV", 1), num(s, "Color3.fromHSV", 2), num(v, "Color3.fromHSV", 3))
	end,
	toHSV = toHSV,
	fromHex = function(hex)
		hex = tostring(hex):gsub("#", "")
		if #hex == 3 then
			hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2)
		end
		local r, g, b = tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
		if not (r and g and b) then
			error("Unable to convert characters to hex value", 2)
		end
		return c3(r / 255, g / 255, b / 255)
	end,
}

---------------------------------------------------------------------------------------------------- UDim / UDim2
local UD = {}
TYPENAME[UD] = "UDim"
local function udim(s, o)
	return setmetatable({ Scale = s, Offset = o }, UD)
end
UD.__index = function(_, k)
	badMember("UDim", k)
end
UD.__newindex = V3.__newindex
UD.__add = function(a, b)
	return udim(a.Scale + b.Scale, a.Offset + b.Offset)
end
UD.__sub = function(a, b)
	return udim(a.Scale - b.Scale, a.Offset - b.Offset)
end
UD.__unm = function(a)
	return udim(-a.Scale, -a.Offset)
end
UD.__eq = function(a, b)
	return a.Scale == b.Scale and a.Offset == b.Offset
end
UD.__tostring = function(u)
	return fmt(u.Scale) .. ", " .. fmt(u.Offset)
end
G.UDim = { new = function(s, o)
	return udim(num(s, "UDim.new", 1, 0), num(o, "UDim.new", 2, 0))
end }
R.udim = udim

local UD2 = {}
TYPENAME[UD2] = "UDim2"
local function udim2(xs, xo, ys, yo)
	return setmetatable({ X = udim(xs, xo), Y = udim(ys, yo) }, UD2)
end
R.udim2 = udim2
UD2.__index = function(u, k)
	if k == "Width" then
		return u.X
	elseif k == "Height" then
		return u.Y
	elseif k == "Lerp" then
		return function(a, b, t)
			return udim2(a.X.Scale + (b.X.Scale - a.X.Scale) * t, a.X.Offset + (b.X.Offset - a.X.Offset) * t, a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t, a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t)
		end
	end
	badMember("UDim2", k)
end
UD2.__newindex = V3.__newindex
UD2.__add = function(a, b)
	return udim2(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
end
UD2.__sub = function(a, b)
	return udim2(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset)
end
UD2.__unm = function(a)
	return udim2(-a.X.Scale, -a.X.Offset, -a.Y.Scale, -a.Y.Offset)
end
UD2.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
UD2.__tostring = function(u)
	return "{" .. tostring(u.X) .. "}, {" .. tostring(u.Y) .. "}"
end
G.UDim2 = {
	new = function(a, b, c, d)
		if getmetatable(a) == UD then
			return setmetatable({ X = a, Y = b or udim(0, 0) }, UD2)
		end
		return udim2(num(a, "UDim2.new", 1, 0), num(b, "UDim2.new", 2, 0), num(c, "UDim2.new", 3, 0), num(d, "UDim2.new", 4, 0))
	end,
	fromScale = function(x, y)
		return udim2(num(x, "UDim2.fromScale", 1, 0), 0, num(y, "UDim2.fromScale", 2, 0), 0)
	end,
	fromOffset = function(x, y)
		return udim2(0, num(x, "UDim2.fromOffset", 1, 0), 0, num(y, "UDim2.fromOffset", 2, 0))
	end,
}

---------------------------------------------------------------------------------------------------- Rect, ranges, sequences
local function simpleType(name, fields, extra)
	local mt = {}
	TYPENAME[mt] = name
	mt.__index = function(t, k)
		if extra and extra[k] then
			return extra[k](t)
		end
		badMember(name, k)
	end
	mt.__newindex = V3.__newindex
	mt.__tostring = function(t)
		local parts = {}
		for _, f in ipairs(fields) do
			parts[#parts + 1] = tostring(rawget(t, f))
		end
		return table.concat(parts, " ")
	end
	mt.__eq = function(a, b)
		for _, f in ipairs(fields) do
			if rawget(a, f) ~= rawget(b, f) then
				return false
			end
		end
		return true
	end
	return mt
end
R.simpleType = simpleType

local RECT = simpleType("Rect", { "Min", "Max" }, {
	Width = function(t)
		return t.Max.X - t.Min.X
	end,
	Height = function(t)
		return t.Max.Y - t.Min.Y
	end,
})
G.Rect = { new = function(a, b, c, d)
	if isV2(a) then
		return setmetatable({ Min = a, Max = b }, RECT)
	end
	return setmetatable({ Min = v2(a or 0, b or 0), Max = v2(c or 0, d or 0) }, RECT)
end }

local NR = simpleType("NumberRange", { "Min", "Max" })
G.NumberRange = { new = function(a, b)
	a = num(a, "NumberRange.new", 1)
	return setmetatable({ Min = a, Max = b or a }, NR)
end }

local NSK = simpleType("NumberSequenceKeypoint", { "Time", "Value", "Envelope" })
G.NumberSequenceKeypoint = { new = function(t, v, e)
	return setmetatable({ Time = t, Value = v, Envelope = e or 0 }, NSK)
end }
local NS = simpleType("NumberSequence", { "Keypoints" })
G.NumberSequence = { new = function(a, b)
	if type(a) == "table" and getmetatable(a) == nil then
		if #a < 2 then
			error("NumberSequence: requires at least 2 keypoints", 2)
		end
		if a[1].Time ~= 0 or a[#a].Time ~= 1 then
			error("NumberSequence: must start at time=0.0 and end at time=1.0", 2)
		end
		return setmetatable({ Keypoints = a }, NS)
	end
	a = num(a, "NumberSequence.new", 1)
	return setmetatable({ Keypoints = { G.NumberSequenceKeypoint.new(0, a), G.NumberSequenceKeypoint.new(1, b or a) } }, NS)
end }

local CSK = simpleType("ColorSequenceKeypoint", { "Time", "Value" })
G.ColorSequenceKeypoint = { new = function(t, v)
	if getmetatable(v) ~= C3 then
		typeErr("ColorSequenceKeypoint.new", 2, "Color3", v)
	end
	return setmetatable({ Time = t, Value = v }, CSK)
end }
local CS = simpleType("ColorSequence", { "Keypoints" })
G.ColorSequence = { new = function(a, b)
	if type(a) == "table" and getmetatable(a) == nil then
		if #a < 2 then
			error("ColorSequence: requires at least 2 keypoints", 2)
		end
		if a[1].Time ~= 0 or a[#a].Time ~= 1 then
			error("ColorSequence: must start at time=0.0 and end at time=1.0", 2)
		end
		for i = 2, #a do
			if a[i].Time < a[i - 1].Time then
				error("ColorSequence: all keypoints must be ordered by time", 2)
			end
		end
		return setmetatable({ Keypoints = a }, CS)
	end
	if getmetatable(a) ~= C3 then
		typeErr("ColorSequence.new", 1, "Color3", a)
	end
	return setmetatable({ Keypoints = { G.ColorSequenceKeypoint.new(0, a), G.ColorSequenceKeypoint.new(1, b or a) } }, CS)
end }

---------------------------------------------------------------------------------------------------- TweenInfo
local TI = simpleType("TweenInfo", { "Time", "EasingStyle", "EasingDirection", "RepeatCount", "Reverses", "DelayTime" })
G.TweenInfo = { new = function(t, style, dir, rep, rev, delay)
	return setmetatable({
		Time = t or 1,
		EasingStyle = style or R.enumItem("EasingStyle", "Quad"),
		EasingDirection = dir or R.enumItem("EasingDirection", "Out"),
		RepeatCount = rep or 0,
		Reverses = rev or false,
		DelayTime = delay or 0,
	}, TI)
end }

---------------------------------------------------------------------------------------------------- Random
local RAND = {}
TYPENAME[RAND] = "Random"
local function nextRaw(self) -- xorshift32 -> [0, 1)
	local x = self._s
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self._s = x
	return x / 4294967296
end
local RANDmethods = {
	NextNumber = function(self, a, b)
		a, b = a or 0, b or 1
		return a + (b - a) * nextRaw(self)
	end,
	NextInteger = function(self, a, b)
		if a == nil or b == nil then
			error("missing argument #1 or #2 to 'NextInteger' (number expected)", 2)
		end
		a, b = math.ceil(a), floor(b)
		if b < a then
			error("invalid argument #2 to 'NextInteger' (interval is empty)", 2)
		end
		return a + floor(nextRaw(self) * (b - a + 1))
	end,
	NextUnitVector = function(self)
		local z = 2 * nextRaw(self) - 1
		local t = 2 * math.pi * nextRaw(self)
		local r = sqrt(1 - z * z)
		return v3(r * cos(t), r * sin(t), z)
	end,
	Shuffle = function(self, t)
		for i = #t, 2, -1 do
			local j = 1 + floor(nextRaw(self) * i)
			t[i], t[j] = t[j], t[i]
		end
	end,
	Clone = function(self)
		return setmetatable({ _s = self._s }, RAND)
	end,
}
RAND.__index = function(_, k)
	local m = RANDmethods[k]
	if m then
		return m
	end
	badMember("Random", k)
end
local seedCounter = 12345
G.Random = { new = function(seed)
	if seed == nil then
		seedCounter = seedCounter + 7919
		seed = seedCounter
	end
	local s = floor(abs(seed) * 2654435761 % 4294967296)
	if s == 0 then
		s = 2463534242
	end
	local r = setmetatable({ _s = s }, RAND)
	for _ = 1, 4 do
		nextRaw(r)
	end
	return r
end }

---------------------------------------------------------------------------------------------------- BrickColor
local BC = simpleType("BrickColor", { "Name" }, {
	r = function(t)
		return t.Color.R
	end,
	g = function(t)
		return t.Color.G
	end,
	b = function(t)
		return t.Color.B
	end,
})
local BRICKS = {
	["White"] = { 1, 242, 243, 243 }, ["Black"] = { 26, 27, 42, 53 }, ["Bright red"] = { 21, 196, 40, 28 },
	["Bright blue"] = { 23, 13, 105, 172 }, ["Bright green"] = { 37, 75, 151, 75 }, ["Bright yellow"] = { 24, 245, 205, 48 },
	["Medium stone grey"] = { 194, 163, 162, 165 }, ["Dark stone grey"] = { 199, 99, 95, 98 }, ["Really red"] = { 1004, 255, 0, 0 },
	["Lime green"] = { 1020, 0, 255, 0 }, ["Really blue"] = { 1010, 0, 0, 255 }, ["Institutional white"] = { 1001, 248, 248, 248 },
	["Bright orange"] = { 106, 218, 133, 65 }, ["Gold"] = { 333, 239, 184, 56 }, ["Hot pink"] = { 1032, 255, 0, 191 },
	["Toothpaste"] = { 1019, 0, 255, 255 }, ["Royal purple"] = { 1031, 98, 37, 209 }, ["Teal"] = { 1018, 18, 238, 212 },
	["Light blue"] = { 45, 180, 210, 228 }, ["Pastel blue"] = { 1024, 175, 221, 255 }, ["Sand red"] = { 153, 149, 121, 119 },
}
local function brick(name, d)
	return setmetatable({ Name = name, Number = d[1], Color = c3(d[2] / 255, d[3] / 255, d[4] / 255) }, BC)
end
local function nearestBrick(c)
	local best, bd = "Medium stone grey", math.huge
	for name, d in pairs(BRICKS) do
		local dist = (c.R - d[2] / 255) ^ 2 + (c.G - d[3] / 255) ^ 2 + (c.B - d[4] / 255) ^ 2
		if dist < bd then
			best, bd = name, dist
		end
	end
	return brick(best, BRICKS[best])
end
R.nearestBrick = nearestBrick
G.BrickColor = {
	new = function(a, b, c)
		if type(a) == "string" then
			return brick(BRICKS[a] and a or "Medium stone grey", BRICKS[a] or BRICKS["Medium stone grey"])
		elseif getmetatable(a) == C3 then
			return nearestBrick(a)
		elseif type(a) == "number" and b then
			return nearestBrick(c3(a, b, c))
		elseif type(a) == "number" then
			for name, d in pairs(BRICKS) do
				if d[1] == a then
					return brick(name, d)
				end
			end
			return brick("Medium stone grey", BRICKS["Medium stone grey"])
		end
		return brick("Medium stone grey", BRICKS["Medium stone grey"])
	end,
	random = function()
		return brick("Bright red", BRICKS["Bright red"])
	end,
	palette = function()
		return brick("White", BRICKS.White)
	end,
}
for fname, bname in pairs({ White = "White", Black = "Black", Red = "Bright red", Blue = "Bright blue", Green = "Bright green", Yellow = "Bright yellow", Gray = "Medium stone grey", DarkGray = "Dark stone grey" }) do
	G.BrickColor[fname] = function()
		return brick(bname, BRICKS[bname])
	end
end

---------------------------------------------------------------------------------------------------- Ray, Region3, PhysicalProperties, Faces, Axes
local RAY = simpleType("Ray", { "Origin", "Direction" }, {
	Unit = function(t)
		return setmetatable({ Origin = t.Origin, Direction = t.Direction.Unit }, getmetatable(t))
	end,
})
local RAYm = {
	ClosestPoint = function(r, p)
		local d = r.Direction.Unit
		local t = math.max(0, (p - r.Origin):Dot(d))
		return r.Origin + d * t
	end,
	Distance = function(r, p)
		local d = r.Direction.Unit
		local t = math.max(0, (p - r.Origin):Dot(d))
		return (p - (r.Origin + d * t)).Magnitude
	end,
}
local rayIndex = RAY.__index
RAY.__index = function(t, k)
	if RAYm[k] then
		return RAYm[k]
	end
	return rayIndex(t, k)
end
G.Ray = { new = function(o, d)
	return setmetatable({ Origin = o, Direction = d }, RAY)
end }

local REG = simpleType("Region3", { "CFrame", "Size" })
G.Region3 = { new = function(a, b)
	local c = (a + b) / 2
	return setmetatable({ CFrame = cf(c.X, c.Y, c.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1), Size = (b - a):Abs() }, REG)
end }
G.Region3int16 = { new = function()
	return setmetatable({ CFrame = IDENT, Size = v3(0, 0, 0) }, REG)
end }

local PP = simpleType("PhysicalProperties", { "Density", "Friction", "Elasticity", "FrictionWeight", "ElasticityWeight" })
G.PhysicalProperties = { new = function(d, f, e, fw, ew)
	if type(d) ~= "number" then
		return setmetatable({ Density = 0.7, Friction = 0.3, Elasticity = 0.5, FrictionWeight = 1, ElasticityWeight = 1 }, PP)
	end
	return setmetatable({ Density = d, Friction = f or 0.3, Elasticity = e or 0.5, FrictionWeight = fw or 1, ElasticityWeight = ew or 1 }, PP)
end }

local FACES = simpleType("Faces", {})
G.Faces = { new = function(...)
	return setmetatable({ _items = { ... } }, FACES)
end }
local AXES = simpleType("Axes", {})
G.Axes = { new = function(...)
	return setmetatable({ _items = { ... } }, AXES)
end }

---------------------------------------------------------------------------------------------------- Font, Content
local FONT = simpleType("Font", { "Family", "Weight", "Style" }, {
	Bold = function(t)
		return t.Weight == R.enumItem("FontWeight", "Bold")
	end,
})
local function font(family, weight, style)
	return setmetatable({
		Family = family or "rbxasset://fonts/families/SourceSansPro.json",
		Weight = weight or R.enumItem("FontWeight", "Regular"),
		Style = style or R.enumItem("FontStyle", "Normal"),
	}, FONT)
end
G.Font = {
	new = font,
	fromEnum = function(e)
		return font("rbxasset://fonts/families/" .. e.Name .. ".json")
	end,
	fromName = function(n, w, s)
		return font("rbxasset://fonts/families/" .. n .. ".json", w, s)
	end,
	fromId = function(id, w, s)
		return font("rbxassetid://" .. tostring(id), w, s)
	end,
}
R.font = font

local CONTENT = simpleType("Content", { "SourceType", "Uri" }, {
	Object = function()
		return nil
	end,
})
local function content(uri)
	return setmetatable({ SourceType = uri and R.enumItem("ContentSourceType", "Uri") or R.enumItem("ContentSourceType", "None"), Uri = uri }, CONTENT)
end
R.contentNone = content(nil)
G.Content = {
	fromAssetId = function(id)
		if type(id) ~= "number" then
			typeErr("Content.fromAssetId", 1, "number", id)
		end
		R.noteAsset("rbxassetid://" .. tostring(id), "Content.fromAssetId")
		return content("rbxassetid://" .. tostring(id))
	end,
	fromUri = function(uri)
		R.noteAsset(uri, "Content.fromUri")
		return content(uri)
	end,
	fromObject = function()
		return content(nil)
	end,
	none = R.contentNone,
}

---------------------------------------------------------------------------------------------------- DateTime
local DT = simpleType("DateTime", { "UnixTimestampMillis" }, {
	UnixTimestamp = function(t)
		return floor(t.UnixTimestampMillis / 1000)
	end,
})
local DTm = {
	ToIsoDate = function(t)
		return os.date("!%Y-%m-%dT%H:%M:%SZ", floor(t.UnixTimestampMillis / 1000))
	end,
	ToUniversalTime = function(t)
		local d = os.date("!*t", floor(t.UnixTimestampMillis / 1000)) :: any
		return { Year = d.year, Month = d.month, Day = d.day, Hour = d.hour, Minute = d.min, Second = d.sec, Millisecond = t.UnixTimestampMillis % 1000 }
	end,
	ToLocalTime = function(t)
		local d = os.date("*t", floor(t.UnixTimestampMillis / 1000)) :: any
		return { Year = d.year, Month = d.month, Day = d.day, Hour = d.hour, Minute = d.min, Second = d.sec, Millisecond = t.UnixTimestampMillis % 1000 }
	end,
	FormatUniversalTime = function(t, f)
		return os.date("!%Y-%m-%d %H:%M", floor(t.UnixTimestampMillis / 1000))
	end,
	FormatLocalTime = function(t, f)
		return os.date("%Y-%m-%d %H:%M", floor(t.UnixTimestampMillis / 1000))
	end,
}
local dtIndex = DT.__index
DT.__index = function(t, k)
	if DTm[k] then
		return DTm[k]
	end
	return dtIndex(t, k)
end
G.DateTime = {
	now = function()
		return setmetatable({ UnixTimestampMillis = floor(R.unixNow() * 1000) }, DT)
	end,
	fromUnixTimestamp = function(s)
		return setmetatable({ UnixTimestampMillis = floor(s * 1000) }, DT)
	end,
	fromUnixTimestampMillis = function(ms)
		return setmetatable({ UnixTimestampMillis = floor(ms) }, DT)
	end,
	fromUniversalTime = function(y, mo, d, h, mi, s, ms)
		local t = os.time({ year = y or 1970, month = mo or 1, day = d or 1, hour = h or 0, min = mi or 0, sec = s or 0 })
		return setmetatable({ UnixTimestampMillis = t * 1000 + (ms or 0) }, DT)
	end,
	fromLocalTime = function(y, mo, d, h, mi, s, ms)
		local t = os.time({ year = y or 1970, month = mo or 1, day = d or 1, hour = h or 0, min = mi or 0, sec = s or 0 })
		return setmetatable({ UnixTimestampMillis = t * 1000 + (ms or 0) }, DT)
	end,
	fromIsoDate = function()
		return setmetatable({ UnixTimestampMillis = 0 }, DT)
	end,
}

---------------------------------------------------------------------------------------------------- Raycast / Overlap params
local function paramsType(name, defaults)
	local mt = {}
	TYPENAME[mt] = name
	mt.__index = function(t, k)
		if k == "AddToFilter" then
			return function(self, x)
				local f = rawget(self, "FilterDescendantsInstances")
				if type(x) == "table" and not R.isInstance(x) then
					for _, v in ipairs(x) do
						table.insert(f, v)
					end
				else
					table.insert(f, x)
				end
			end
		end
		badMember(name, k)
	end
	mt.__newindex = function(t, k, v)
		if defaults[k] == nil then
			badMember(name, k)
		end
		if k == "FilterDescendantsInstances" then
			if type(v) ~= "table" then
				error("Unable to assign property FilterDescendantsInstances. Array expected", 2)
			end
			local copy = {}
			for i, x in ipairs(v) do
				copy[i] = x
			end
			v = copy
		end
		rawset(t, k, v)
	end
	return {
		new = function()
			local t = setmetatable({}, mt)
			for k, v in pairs(defaults) do
				rawset(t, k, type(v) == "function" and v() or v)
			end
			return t
		end,
	}
end
G.RaycastParams = paramsType("RaycastParams", {
	FilterDescendantsInstances = function()
		return {}
	end,
	FilterType = function()
		return R.enumItem("RaycastFilterType", "Exclude")
	end,
	IgnoreWater = false,
	CollisionGroup = "Default",
	RespectCanCollide = false,
	BruteForceAllSlow = false,
})
G.OverlapParams = paramsType("OverlapParams", {
	FilterDescendantsInstances = function()
		return {}
	end,
	FilterType = function()
		return R.enumItem("RaycastFilterType", "Exclude")
	end,
	MaxParts = 0,
	CollisionGroup = "Default",
	RespectCanCollide = false,
	BruteForceAllSlow = false,
})
local RR = simpleType("RaycastResult", { "Instance", "Position", "Normal", "Material", "Distance" })
function R.raycastResult(inst, pos, normal, material, dist)
	return setmetatable({ Instance = inst, Position = pos, Normal = normal, Material = material, Distance = dist }, RR)
end

-- Parse an API-dump default string into a value of the given datatype (nil when unknown).
function R.parseDefault(cat, tname, s)
	if s == nil then
		return nil
	end
	if cat == "P" then
		if tname == "bool" then
			return s == "true"
		elseif tname == "string" or tname == "Content" then
			return s
		end
		if s == "INF" then
			return math.huge
		elseif s == "-INF" then
			return -math.huge
		end
		return tonumber(s)
	end
	local nums = {}
	for n in string.gmatch(s, "[-%d%.e]+") do
		nums[#nums + 1] = tonumber(n)
	end
	if tname == "Vector3" and #nums == 3 then
		return v3(nums[1], nums[2], nums[3])
	elseif tname == "Vector2" and #nums == 2 then
		return v2(nums[1], nums[2])
	elseif tname == "Color3" and #nums == 3 then
		return c3(nums[1], nums[2], nums[3])
	elseif tname == "CFrame" and #nums == 12 then
		return cf(table.unpack(nums))
	elseif tname == "UDim2" and #nums == 4 then
		return udim2(nums[1], nums[2], nums[3], nums[4])
	elseif tname == "UDim" and #nums == 2 then
		return udim(nums[1], nums[2])
	elseif tname == "NumberRange" and #nums >= 2 then
		return G.NumberRange.new(nums[1], nums[2])
	elseif tname == "ContentId" then
		return s
	end
	return nil
end

-- Default value for a property of a given datatype when the dump has none.
function R.typeDefault(cat, tname)
	if cat == "P" then
		if tname == "bool" then
			return false
		elseif tname == "string" then
			return ""
		end
		return 0
	elseif cat == "E" then
		return R.firstEnumItem(tname)
	elseif cat == "C" then
		return nil
	end
	if tname == "Vector3" then
		return v3(0, 0, 0)
	elseif tname == "Vector2" then
		return v2(0, 0)
	elseif tname == "CFrame" then
		return IDENT
	elseif tname == "Color3" then
		return c3(0, 0, 0)
	elseif tname == "UDim2" then
		return udim2(0, 0, 0, 0)
	elseif tname == "UDim" then
		return udim(0, 0)
	elseif tname == "ContentId" or tname == "string" then
		return ""
	elseif tname == "Content" then
		return R.contentNone
	elseif tname == "NumberRange" then
		return G.NumberRange.new(0, 0)
	elseif tname == "NumberSequence" then
		return G.NumberSequence.new(0)
	elseif tname == "ColorSequence" then
		return G.ColorSequence.new(c3(1, 1, 1))
	elseif tname == "Rect" then
		return G.Rect.new(0, 0, 0, 0)
	elseif tname == "Font" then
		return font()
	elseif tname == "BrickColor" then
		return G.BrickColor.new("Medium stone grey")
	elseif tname == "Faces" then
		return G.Faces.new()
	elseif tname == "Axes" then
		return G.Axes.new()
	elseif tname == "PhysicalProperties" then
		return nil
	elseif tname == "Ray" then
		return G.Ray.new(v3(0, 0, 0), v3(0, 0, 0))
	elseif tname == "Vector3int16" then
		return v3(0, 0, 0)
	elseif tname == "Vector2int16" then
		return v2(0, 0)
	elseif tname == "Region3int16" then
		return G.Region3int16.new()
	elseif tname == "OptionalCoordinateFrame" then
		return nil
	end
	return nil
end

return true

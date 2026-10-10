--!strict
-- Marble models built from parts: a Glass shell around a coloured core with a per-marble pattern
-- (cat's-eye vanes, swirl bands, stripes, dots, candy meridians, eye, planet ring, galaxy specks,
-- glowing flame/gem cores). Mutations restyle the shell (gold, rainbow, cosmic).
-- If the server has loaded the AI sphere mesh (ReplicatedStorage.MarbleMeshes.Sphere) and a marble has
-- its own texture id, the core becomes that textured mesh instead of the primitive pattern.
-- Used by the server (lobby podium, showcase) and clients (race marbles, previews).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MarbleArt = {}

local V3 = Vector3.new
local CF = CFrame.new
local RAD = math.rad
local WHITE = Color3.new(1, 1, 1)

export type Built = { model: Model, shell: BasePart, parts: { BasePart }, offsets: { CFrame }, rainbow: { BasePart }, glow: BasePart }

local TIER_NEON = { Epic = true, Legendary = true, Mythic = true, Secret = true }

local function newPart(model: Model, shape: Enum.PartType, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function ball(model: Model, d: number, pos: Vector3, color: Color3, material: Enum.Material?): Part
	return newPart(model, Enum.PartType.Ball, V3(d, d, d), CF(pos), color, material)
end

-- Thin disc (cylinder) whose flat faces point along `normalCf`'s X axis.
local function disc(model: Model, dia: number, thick: number, cf: CFrame, color: Color3, material: Enum.Material?): Part
	return newPart(model, Enum.PartType.Cylinder, V3(thick, dia, dia), cf, color, material)
end

-- Evenly spread points on a sphere (Fibonacci).
local function sphere(n: number, r: number, seed: number): { Vector3 }
	local out = {}
	local golden = math.pi * (3 - math.sqrt(5))
	for i = 0, n - 1 do
		local y = 1 - (i + 0.5) / n * 2
		local rr = math.sqrt(1 - y * y)
		local a = golden * i + seed
		table.insert(out, V3(math.cos(a) * rr * r, y * r, math.sin(a) * rr * r))
	end
	return out
end

function MarbleArt.mutationColor(mut: string?): Color3?
	local m = mut and Config.MutationByKey[mut]
	return m and m.color or nil
end

-- Build a marble of diameter d at the origin. Returns the model plus every part and its offset from the
-- shell, so movers can BulkMoveTo all parts in one call.
function MarbleArt.build(id: string, mut: string?, d: number): Built
	local def = Config.MarbleById[id] or Config.Marbles[1]
	local model = Instance.new("Model")
	model.Name = def.name
	local c1, c2, c3 = def.c1, def.c2, def.c3
	local neon = TIER_NEON[def.tier] and Enum.Material.Neon or Enum.Material.SmoothPlastic
	local rainbow: { BasePart } = {}
	local rc = d * 0.36 -- core radius

	-- shell
	local shellColor = c1:Lerp(WHITE, 0.72)
	local shellT = 0.42
	if def.pattern == "cateye" then
		shellColor = c1:Lerp(WHITE, 0.85)
		shellT = 0.5
	elseif def.pattern == "gem" then
		shellColor = c2:Lerp(WHITE, 0.4)
		shellT = 0.35
	end
	if mut == "gold" then
		shellColor = Color3.fromRGB(255, 214, 80)
		shellT = 0.28
	elseif mut == "rainbow" then
		shellColor = Color3.fromRGB(255, 220, 245)
		shellT = 0.38
	elseif mut == "cosmic" then
		shellColor = Color3.fromRGB(70, 30, 140)
		shellT = 0.3
	end
	local shell = newPart(model, Enum.PartType.Ball, V3(d, d, d), CFrame.identity, shellColor, Enum.Material.Glass)
	shell.Name = "Shell"
	shell.Transparency = shellT
	shell.Reflectance = 0.08
	shell.CastShadow = true
	model.PrimaryPart = shell

	-- textured mesh core (AI skin), when available
	local meshes = ReplicatedStorage:FindFirstChild("MarbleMeshes")
	local sphereMesh = meshes and meshes:FindFirstChild("Sphere")
	local usedMesh = false
	if sphereMesh and sphereMesh:IsA("MeshPart") and def.texture ~= 0 then
		local ok = pcall(function()
			local mp = sphereMesh:Clone() :: MeshPart
			mp.Size = V3(d * 0.86, d * 0.86, d * 0.86)
			mp.CFrame = CFrame.identity
			mp.Anchored = true
			mp.CanCollide = false
			mp.CanQuery = false
			mp.CanTouch = false
			mp.CastShadow = false
			mp.TextureContent = Content.fromAssetId(def.texture)
			mp.Parent = model
		end)
		usedMesh = ok
	end

	local p = def.pattern
	if not usedMesh then
		if p == "cateye" then
			for k, col in ipairs({ c1, c2, c3 }) do
				local v = disc(model, d * 0.8, d * 0.07, CFrame.Angles(0, RAD(60 * (k - 1)), RAD(8 * k)), col, neon)
				v.Name = "Vane"
			end
		elseif p == "swirl" then
			local core = ball(model, rc * 2, Vector3.zero, c1)
			core.Name = "Core"
			table.insert(rainbow, core)
			disc(model, rc * 2.06, d * 0.13, CFrame.Angles(0, 0, RAD(35)), c2)
			disc(model, rc * 2.06, d * 0.13, CFrame.Angles(RAD(70), RAD(40), RAD(-35)), c2)
			disc(model, rc * 2.06, d * 0.07, CFrame.Angles(RAD(20), RAD(100), RAD(80)), c3)
		elseif p == "stripes" or p == "rainbow" then
			local core = ball(model, rc * 2, Vector3.zero, p == "rainbow" and WHITE or c1)
			core.Name = "Core"
			table.insert(rainbow, core)
			local cols: { Color3 } = p == "rainbow"
					and { Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 170, 40), Color3.fromRGB(255, 230, 60), Color3.fromRGB(70, 220, 110), Color3.fromRGB(70, 160, 255) }
				or { c2, c3, c2 }
			local n = #cols
			for k, col in ipairs(cols) do
				local y = (k - (n + 1) / 2) * rc * (p == "rainbow" and 0.36 or 0.5)
				local r = math.sqrt(math.max(0.01, rc * rc - y * y))
				disc(model, r * 2.08, d * (p == "rainbow" and 0.08 or 0.1), CF(0, y, 0) * CFrame.Angles(0, 0, RAD(90)), col, p == "rainbow" and neon or nil)
			end
		elseif p == "dots" then
			local core = ball(model, rc * 2, Vector3.zero, c1)
			core.Name = "Core"
			table.insert(rainbow, core)
			for k, pos in ipairs(sphere(9, rc * 0.96, def.order)) do
				ball(model, d * (k % 3 == 0 and 0.14 or 0.18), pos, k % 4 == 0 and c3 or c2)
			end
		elseif p == "candy" then
			local core = ball(model, rc * 2, Vector3.zero, c2)
			core.Name = "Core"
			for k = 0, 3 do
				disc(model, rc * 2.06, d * 0.11, CFrame.Angles(0, RAD(45 * k), 0), k % 2 == 0 and c1 or c3)
			end
		elseif p == "eye" then
			local core = ball(model, rc * 2, Vector3.zero, c2)
			core.Name = "Core"
			disc(model, rc * 0.95, d * 0.06, CF(0, 0, -rc * 0.97) * CFrame.Angles(0, RAD(90), 0), c1, neon)
			disc(model, rc * 0.45, d * 0.06, CF(0, 0, -rc * 1.01) * CFrame.Angles(0, RAD(90), 0), c3)
			ball(model, d * 0.07, V3(rc * 0.18, rc * 0.2, -rc * 1.02), WHITE, Enum.Material.Neon)
			-- second eye on the back so it reads from every side as it rolls
			disc(model, rc * 0.95, d * 0.06, CF(0, 0, rc * 0.97) * CFrame.Angles(0, RAD(90), 0), c1, neon)
			disc(model, rc * 0.45, d * 0.06, CF(0, 0, rc * 1.01) * CFrame.Angles(0, RAD(90), 0), c3)
		elseif p == "planet" then
			local core = ball(model, d * 0.5, Vector3.zero, c1)
			core.Name = "Core"
			table.insert(rainbow, core)
			disc(model, d * 0.86, d * 0.04, CFrame.Angles(0, 0, RAD(90 - 24)), c2)
			disc(model, d * 0.66, d * 0.05, CFrame.Angles(0, 0, RAD(90 - 24)), c3)
		elseif p == "galaxy" then
			local core = ball(model, rc * 2.05, Vector3.zero, c1)
			core.Name = "Core"
			for k, pos in ipairs(sphere(14, rc * 1.0, def.order * 1.7)) do
				ball(model, d * (k % 4 == 0 and 0.09 or 0.06), pos, k % 3 == 0 and c3 or c2, Enum.Material.Neon)
			end
			disc(model, rc * 2.1, d * 0.05, CFrame.Angles(RAD(25), 0, RAD(65)), c3, Enum.Material.Neon)
		elseif p == "flame" then
			local core = ball(model, d * 0.62, Vector3.zero, c1, Enum.Material.Neon)
			core.Name = "Core"
			table.insert(rainbow, core)
			for k, pos in ipairs(sphere(7, d * 0.3, def.order)) do
				ball(model, d * (k % 2 == 0 and 0.16 or 0.12), pos, c2)
			end
			local light = Instance.new("PointLight")
			light.Color = c1
			light.Range = d * 3
			light.Brightness = 1.2
			light.Parent = core
		elseif p == "gem" then
			local core = ball(model, d * 0.5, Vector3.zero, c1, Enum.Material.Neon)
			core.Name = "Core"
			table.insert(rainbow, core)
			for _, pos in ipairs(sphere(4, d * 0.33, def.order)) do
				ball(model, d * 0.1, pos, c3, Enum.Material.Neon)
			end
			disc(model, d * 0.7, d * 0.05, CFrame.Angles(0, RAD(45), RAD(90)), c2, Enum.Material.Neon)
		else
			local core = ball(model, rc * 2, Vector3.zero, c1)
			core.Name = "Core"
		end
	end

	-- mutation extras
	if mut == "gold" then
		local band = disc(model, d * 0.96, d * 0.06, CFrame.Angles(0, 0, RAD(90)), Color3.fromRGB(255, 200, 40), Enum.Material.Neon)
		band.Name = "GoldBand"
	elseif mut == "rainbow" then
		local band = disc(model, d * 0.96, d * 0.07, CFrame.Angles(0, 0, RAD(90)), Color3.fromRGB(255, 120, 200), Enum.Material.Neon)
		band.Name = "RainbowBand"
		table.insert(rainbow, band)
	elseif mut == "cosmic" then
		for k, pos in ipairs(sphere(12, d * 0.44, 3.3)) do
			ball(model, d * 0.06, pos, k % 2 == 0 and WHITE or Color3.fromRGB(120, 230, 255), Enum.Material.Neon)
		end
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(160, 90, 255)
		light.Range = d * 3.5
		light.Brightness = 1.5
		light.Parent = shell
	end

	-- glow halo (shown when the marble is in its BOOST window)
	local glow = newPart(model, Enum.PartType.Ball, V3(d * 1.3, d * 1.3, d * 1.3), CFrame.identity, Color3.fromRGB(255, 220, 60), Enum.Material.Neon)
	glow.Name = "Glow"
	glow.Transparency = 1

	local parts: { BasePart } = {}
	local offsets: { CFrame } = {}
	for _, c in ipairs(model:GetDescendants()) do
		if c:IsA("BasePart") then
			table.insert(parts, c :: BasePart)
			table.insert(offsets, (c :: BasePart).CFrame)
		end
	end
	return { model = model, shell = shell, parts = parts, offsets = offsets, rainbow = rainbow, glow = glow }
end

-- Add sparkle particles for rare tiers and mutations (podium, showcase, reveals).
function MarbleArt.sparkle(b: Built, id: string, mut: string?)
	local def = Config.MarbleById[id]
	local ranks: { [string]: number } = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7 }
	local tierRank: number = def and ranks[def.tier] or 1
	if tierRank < 5 and not mut then
		return
	end
	local col = MarbleArt.mutationColor(mut) or (def and def.c1) or WHITE
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(col, WHITE)
	pe.LightEmission = 0.8
	pe.Rate = mut and 6 or 4
	pe.Lifetime = NumberRange.new(0.6, 1.2)
	pe.Speed = NumberRange.new(1, 2.5)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	pe.Parent = b.shell
end

-- Move a built marble so its centre is at cf.
function MarbleArt.place(b: Built, cf: CFrame)
	local cfs: { CFrame } = {}
	for i, off in ipairs(b.offsets) do
		cfs[i] = cf * off
	end
	workspace:BulkMoveTo(b.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

return MarbleArt

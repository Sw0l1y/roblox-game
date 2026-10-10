-- AI-generated hero meshes (Studio generate_mesh / generate_texture, owned by the experience owner),
-- built at runtime from their asset ids. Config.Meshes = { key = { mesh = id, texture = id?, size = Vector3? } }.
-- Assets.get(key) returns a fresh MeshPart clone, or nil when the id is missing or fails to load,
-- so every caller keeps a primitive fallback.
local AssetService = game:GetService("AssetService")

local Assets = {}

local registry: { [string]: { mesh: number, texture: number?, size: Vector3? } } = {}
local templates: { [string]: MeshPart | false } = {}
local loading: { [string]: boolean } = {}

function Assets.init(meshes: { [string]: any }?)
	registry = meshes or {}
end

local function load(key: string): MeshPart | false
	local info = registry[key]
	if not info or not info.mesh or info.mesh == 0 then
		return false
	end
	local ok, part = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromAssetId(info.mesh))
	end)
	if not ok or not part then
		warn("[Assets] mesh failed", key, part)
		return false
	end
	local mp = part :: MeshPart
	if info.texture and info.texture ~= 0 then
		pcall(function()
			(mp :: any).TextureContent = Content.fromAssetId(info.texture :: number)
		end)
	end
	mp.Anchored = true
	mp.Name = key
	if info.size then
		local s = mp.Size
		local f = math.min(info.size.X / s.X, info.size.Y / s.Y, info.size.Z / s.Z)
		mp.Size = s * f
	end
	return mp
end

function Assets.get(key: string): MeshPart?
	while loading[key] do
		task.wait()
	end
	if templates[key] == nil then
		loading[key] = true
		templates[key] = load(key)
		loading[key] = nil
	end
	local t = templates[key]
	if t then
		return (t :: MeshPart):Clone() :: any
	end
	return nil
end

-- Preload every registered mesh in parallel (call once at server start).
function Assets.preload()
	for key in pairs(registry) do
		task.spawn(Assets.get, key)
	end
end

return Assets

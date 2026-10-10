-- Lighting presets from PROTOCOL.md §3.4, applied at server start (they replicate to clients).
-- A: bright cartoon day (simulators), B: cozy sunset/indoor warm, C: spooky night, D: space.
local Lighting = game:GetService("Lighting")

local Look = {}

local PRESETS = {
	A = {
		ClockTime = 14, Brightness = 2.5, ExposureCompensation = 0.1,
		Ambient = Color3.fromRGB(110, 110, 120), OutdoorAmbient = Color3.fromRGB(155, 155, 165),
		atmosphere = { Density = 0.25, Offset = 0.15, Haze = 0.5, Glare = 0, Color = Color3.fromRGB(199, 225, 255), Decay = Color3.fromRGB(106, 150, 210) },
		bloom = { Intensity = 0.4, Size = 24, Threshold = 1.6 },
		cc = { Brightness = 0.06, Contrast = 0.1, Saturation = 0.2, TintColor = Color3.new(1, 1, 1) },
		sunRays = { Intensity = 0.04, Spread = 0.6 },
	},
	B = {
		ClockTime = 17.6, Brightness = 2, ExposureCompensation = 0.2,
		Ambient = Color3.fromRGB(90, 70, 80), OutdoorAmbient = Color3.fromRGB(165, 120, 110),
		atmosphere = { Density = 0.35, Offset = 0.25, Haze = 1.8, Glare = 0.3, Color = Color3.fromRGB(255, 200, 170), Decay = Color3.fromRGB(190, 120, 140) },
		bloom = { Intensity = 0.6, Size = 32, Threshold = 1.2 },
		cc = { Brightness = 0.02, Contrast = 0.12, Saturation = 0.15, TintColor = Color3.fromRGB(255, 246, 236) },
		sunRays = { Intensity = 0.08, Spread = 0.7 },
	},
	C = {
		ClockTime = 0.5, Brightness = 0.6, ExposureCompensation = -0.2,
		Ambient = Color3.fromRGB(20, 22, 35), OutdoorAmbient = Color3.fromRGB(45, 50, 75),
		atmosphere = { Density = 0.45, Offset = 0, Haze = 2.5, Glare = 0, Color = Color3.fromRGB(60, 70, 110), Decay = Color3.fromRGB(30, 30, 60) },
		bloom = { Intensity = 1, Size = 40, Threshold = 0.9 },
		cc = { Brightness = -0.03, Contrast = 0.2, Saturation = -0.25, TintColor = Color3.fromRGB(220, 230, 255) },
		sunRays = { Intensity = 0, Spread = 0 },
	},
	D = { -- space: dark sky, strong key light, coloured haze
		ClockTime = 14, Brightness = 3, ExposureCompensation = 0.1,
		Ambient = Color3.fromRGB(70, 70, 100), OutdoorAmbient = Color3.fromRGB(110, 110, 150),
		atmosphere = { Density = 0.3, Offset = 0, Haze = 0, Glare = 0, Color = Color3.fromRGB(80, 60, 140), Decay = Color3.fromRGB(20, 10, 50) },
		bloom = { Intensity = 0.7, Size = 30, Threshold = 1.2 },
		cc = { Brightness = 0.04, Contrast = 0.15, Saturation = 0.25, TintColor = Color3.new(1, 1, 1) },
		sunRays = { Intensity = 0.02, Spread = 0.5 },
	},
}

local function set(obj: Instance, props: { [string]: any })
	for k, v in pairs(props) do
		pcall(function()
			(obj :: any)[k] = v
		end)
	end
end

local function child(className: string): Instance
	local c = Lighting:FindFirstChildOfClass(className)
	if not c then
		c = Instance.new(className)
		c.Parent = Lighting
	end
	return c :: Instance
end

-- opts: { preset = "A", overrides = { ClockTime = 15, ... }, sky = { bk=, dn=, ft=, lf=, rt=, up= } (image ids),
--         clouds = { Cover = 0.5, Density = 0.4, Color = ... } or false }
function Look.apply(opts: { [string]: any })
	local p = PRESETS[opts.preset or "A"]
	set(Lighting, {
		ClockTime = p.ClockTime, Brightness = p.Brightness, ExposureCompensation = p.ExposureCompensation,
		Ambient = p.Ambient, OutdoorAmbient = p.OutdoorAmbient, GlobalShadows = true,
		EnvironmentDiffuseScale = 0.5, EnvironmentSpecularScale = 0.3,
	})
	pcall(function()
		(Lighting :: any).ShadowSoftness = 0.25
	end)
	set(Lighting, opts.overrides or {})
	set(child("Atmosphere"), p.atmosphere)
	set(child("BloomEffect"), p.bloom)
	set(child("ColorCorrectionEffect"), p.cc)
	set(child("SunRaysEffect"), p.sunRays)
	if opts.atmosphere then
		set(child("Atmosphere"), opts.atmosphere)
	end
	if opts.cc then
		set(child("ColorCorrectionEffect"), opts.cc)
	end

	if opts.sky then
		local sky = child("Sky") :: Sky
		local s = opts.sky
		local function id(v: any): string
			return type(v) == "number" and ("rbxassetid://" .. v) or tostring(v)
		end
		sky.SkyboxBk, sky.SkyboxDn, sky.SkyboxFt = id(s.bk), id(s.dn), id(s.ft)
		sky.SkyboxLf, sky.SkyboxRt, sky.SkyboxUp = id(s.lf), id(s.rt), id(s.up)
		sky.CelestialBodiesShown = s.sun ~= false
		sky.StarCount = s.stars or 0
		sky.SunAngularSize = s.sunSize or 14
	end

	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		local clouds = terrain:FindFirstChildOfClass("Clouds")
		if opts.clouds == false then
			if clouds then
				clouds:Destroy()
			end
		else
			if not clouds then
				clouds = Instance.new("Clouds")
				clouds.Parent = terrain
			end
			set(clouds :: Instance, opts.clouds or { Cover = 0.45, Density = 0.35, Color = Color3.fromRGB(255, 255, 255) })
		end
		if opts.water then
			set(terrain, opts.water)
		end
	end
end

return Look

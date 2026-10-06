--!strict
-- Profi vzhled bez modelů: atmosféra s oparem na obzoru, obloha, mraky, záře, sytější barvy.

local Lighting = game:GetService("Lighting")

local Atmosphere = {}

local function ensure(className: string, parent: Instance): Instance
	local existing = parent:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local created = Instance.new(className)
	created.Parent = parent
	return created
end

function Atmosphere.Apply()
	Lighting.ClockTime = 14.2
	Lighting.GeographicLatitude = 20
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(120, 130, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 160, 175)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 240, 215)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true

	local atmosphere = ensure("Atmosphere", Lighting) :: Atmosphere
	atmosphere.Density = 0.24
	atmosphere.Offset = 0.15
	-- paleta oblohy: #D6EEFF (opar u obzoru), #7CC8FF / #1EA0FF (modrá)
	atmosphere.Color = Color3.fromRGB(214, 238, 255)
	atmosphere.Decay = Color3.fromRGB(124, 200, 255)
	atmosphere.Glare = 0.35
	atmosphere.Haze = 0.8

	local sky = ensure("Sky", Lighting) :: Sky
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 8
	sky.StarCount = 0

	local bloom = ensure("BloomEffect", Lighting) :: BloomEffect
	bloom.Intensity = 0.45
	bloom.Size = 24
	bloom.Threshold = 1.4

	local color = ensure("ColorCorrectionEffect", Lighting) :: ColorCorrectionEffect
	color.Saturation = 0.18
	color.Contrast = 0.06
	color.Brightness = 0.02
	color.TintColor = Color3.fromRGB(255, 252, 245)

	local rays = ensure("SunRaysEffect", Lighting) :: SunRaysEffect
	rays.Intensity = 0.05
	rays.Spread = 0.6

	-- pohyblivé mraky na obloze
	local clouds = ensure("Clouds", workspace.Terrain) :: Clouds
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(255, 255, 255)
end

return Atmosphere

--!nonstrict
-- LightingRig.luau — the house look. Dim, warm, low contrast.
--
-- Explicit brief: no strong lights, nothing that flashes. So: exposure pulled
-- down, bloom barely above threshold, saturation slightly cut, and a warm haze
-- that lets the spot wash read as volume instead of glare. The rig never
-- animates during a round — no strobes, no colour swings, not even on a
-- sabotage. The audio carries the chaos; the light stays still.

local Lighting = game:GetService("Lighting")
local Palette = require(game.ReplicatedStorage.Shared.Palette)

local LightingRig = {}

local function clear(className)
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA(className) then
			child:Destroy()
		end
	end
end

function LightingRig.apply()
	Lighting.Technology = Enum.Technology.Future
	Lighting.Ambient = Color3.fromRGB(26, 22, 24)
	Lighting.OutdoorAmbient = Color3.fromRGB(18, 16, 19)
	Lighting.Brightness = 1.1
	Lighting.ClockTime = 21
	Lighting.GeographicLatitude = 0
	Lighting.EnvironmentDiffuseScale = 0.22
	Lighting.EnvironmentSpecularScale = 0.14
	Lighting.ExposureCompensation = -0.18
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.75
	Lighting.FogEnd = 320

	clear("Atmosphere")
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(176, 158, 150)
	atmosphere.Decay = Color3.fromRGB(88, 76, 74)
	atmosphere.Glare = 0.08
	atmosphere.Haze = 1.25
	atmosphere.Parent = Lighting

	clear("BloomEffect")
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.32
	bloom.Size = 26
	bloom.Threshold = 1.7   -- only the neon practicals cross it
	bloom.Parent = Lighting

	clear("ColorCorrectionEffect")
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Brightness = -0.015
	cc.Contrast = 0.045
	cc.Saturation = -0.07
	cc.TintColor = Color3.fromRGB(255, 247, 238)
	cc.Parent = Lighting

	clear("SunRaysEffect")   -- indoors; nothing to flare
	clear("BlurEffect")

	local depth = Instance.new("DepthOfFieldEffect")
	depth.FarIntensity = 0.1
	depth.NearIntensity = 0.04
	depth.FocusDistance = 28
	depth.InFocusRadius = 22
	depth.Parent = Lighting

	-- Keyed to the practicals so the warm wash is consistent room-wide.
	Lighting.ColorShift_Top = Palette.Practical:Lerp(Color3.new(0, 0, 0), 0.72)
	Lighting.ColorShift_Bottom = Color3.fromRGB(20, 17, 20)
end

return LightingRig

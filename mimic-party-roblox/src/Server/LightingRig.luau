--!nonstrict
-- LightingRig.luau — the house look. Warm, saturated, cartoon.
--
-- Two instructions, and they are not in conflict: "no strong lights, nothing
-- that flashes", and "make the colours more cartoon". Bright is not harsh. So
-- exposure comes back up to neutral, saturation goes POSITIVE, and the haze
-- thins out so colour survives distance — while the rig still never animates
-- during a round. No strobes, no colour swings, not even on a sabotage. The
-- audio carries the chaos; the light stays still, in colour.

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
	-- Ambient is the single biggest cartoon lever: it lifts every surface off
	-- black so a colour stays a colour in shadow instead of going to mud.
	Lighting.Ambient = Color3.fromRGB(74, 56, 62)
	Lighting.OutdoorAmbient = Color3.fromRGB(58, 44, 52)
	Lighting.Brightness = 2.1
	Lighting.ClockTime = 21
	Lighting.GeographicLatitude = 0
	Lighting.EnvironmentDiffuseScale = 0.42
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.ExposureCompensation = 0
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.6
	Lighting.FogEnd = 420

	clear("Atmosphere")
	local atmosphere = Instance.new("Atmosphere")
	-- Thin: enough for the spot wash to read as volume, not enough to grey out
	-- the back of the room.
	atmosphere.Density = 0.17
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(236, 196, 172)
	atmosphere.Decay = Color3.fromRGB(150, 96, 92)
	atmosphere.Glare = 0.1
	atmosphere.Haze = 0.7
	atmosphere.Parent = Lighting

	clear("BloomEffect")
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.42
	bloom.Size = 30
	bloom.Threshold = 1.55   -- still only the neon practicals cross it
	bloom.Parent = Lighting

	clear("ColorCorrectionEffect")
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Brightness = 0.015
	cc.Contrast = 0.09
	cc.Saturation = 0.22      -- the cartoon dial; was −0.07
	cc.TintColor = Color3.fromRGB(255, 246, 240)
	cc.Parent = Lighting

	clear("SunRaysEffect")   -- indoors; nothing to flare
	clear("BlurEffect")

	local depth = Instance.new("DepthOfFieldEffect")
	depth.FarIntensity = 0.05
	depth.NearIntensity = 0.04
	depth.FocusDistance = 28
	depth.InFocusRadius = 22
	depth.Parent = Lighting

	-- Keyed to the practicals so the warm wash is consistent room-wide.
	Lighting.ColorShift_Top = Palette.Practical:Lerp(Color3.new(0, 0, 0), 0.5)
	Lighting.ColorShift_Bottom = Color3.fromRGB(56, 36, 44)
end

return LightingRig

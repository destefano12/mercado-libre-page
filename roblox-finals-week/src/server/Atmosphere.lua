--!strict
--[[
	Atmosphere
	------------------------------------------------------------------
	Iluminacion, cielo y post-proceso. Todo lo que hace que el colegio
	no se vea como un juego plano de Roblox.

	Una aclaracion importante antes que nada, porque se malinterpreta
	seguido: la tecnologia de iluminacion NO esta en Workspace y NO se
	puede escribir desde un script — `Lighting.Technology` es de solo
	lectura en runtime. Se define en el archivo del lugar, y aca eso lo
	hace tools/build_studio.py leyendo Config.Estilo.Tecnologia. Este
	modulo lo verifica al arrancar y avisa si quedo en Voxel.

	Otra: no existe un objeto `AmbientOcclusion` en Roblox. La oclusion
	ambiental viene incluida en Future — es una de las razones para
	usarlo. Con ShadowMap no hay SSAO y el colegio se ve mas chato.

	Lo que si se crea aca:
	  Sky              cielo con el sol suavizado y sin estrellas
	  Atmosphere       la neblina gris que apaga los colores a lo lejos
	  Clouds           nubes volumetricas (van en Terrain, sin assets)
	  BloomEffect      solo los tubos fluorescentes florecen
	  ColorCorrection  el look lavado y frio, por clima
	  DepthOfField     desenfoque suave, para que no parezca maqueta
	  SunRaysEffect    un toque, casi imperceptible
--]]

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Style = require(Shared:WaitForChild("Style"))

local E = Config.Estilo

local Atmosphere = {}

local correction: ColorCorrectionEffect? = nil
local mood = "pasillo"

local function replace(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = Lighting
	return instance
end

-- ── cielo y niebla ─────────────────────────────────────────────────

local function buildSky()
	local sky = replace("Sky", "Cielo") :: Sky
	-- Sin textura propia queda el cielo por defecto; la Atmosphere y
	-- las nubes lo apagan hasta que lee como dia nublado. Si subis un
	-- skybox propio, sus seis caras van en este objeto.
	sky.CelestialBodiesShown = true
	sky.StarCount = 0
	sky.SunAngularSize = 9
	sky.MoonAngularSize = 0
end

local function buildAtmosphere()
	local A = E.Atmosfera
	local atmosphere = replace("Atmosphere", "Atmosfera") :: Atmosphere
	atmosphere.Density = A.densidad
	atmosphere.Offset = A.desplazamiento
	atmosphere.Color = A.color
	atmosphere.Decay = A.decaimiento
	atmosphere.Glare = A.brillo
	atmosphere.Haze = A.neblina
end

--- Nubes volumetricas de verdad, sin subir nada: viven en Terrain.
local function buildClouds()
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if not terrain then
		return
	end
	local existing = terrain:FindFirstChildOfClass("Clouds")
	if existing then
		existing:Destroy()
	end
	local clouds = Instance.new("Clouds")
	clouds.Cover = E.Nubes.cobertura
	clouds.Density = E.Nubes.densidad
	clouds.Color = Color3.fromRGB(206, 208, 214)
	clouds.Enabled = true
	clouds.Parent = terrain
end

-- ── post-proceso ───────────────────────────────────────────────────

local function buildPost()
	local bloom = replace("BloomEffect", "Bloom") :: BloomEffect
	-- Umbral alto: solo los tubos fluorescentes y el neon florecen.
	-- Con el umbral bajo se lava todo y vuelve el look de juguete.
	bloom.Intensity = E.Bloom.intensidad
	bloom.Size = E.Bloom.tamano
	bloom.Threshold = E.Bloom.umbral

	local dof = replace("DepthOfFieldEffect", "Profundidad") :: DepthOfFieldEffect
	dof.FarIntensity = E.Profundidad.lejos
	dof.FocusDistance = E.Profundidad.foco
	dof.InFocusRadius = E.Profundidad.radio
	dof.NearIntensity = E.Profundidad.cerca

	local rays = replace("SunRaysEffect", "RayosSol") :: SunRaysEffect
	rays.Intensity = E.RayosSol.intensidad
	rays.Spread = E.RayosSol.dispersion

	correction = replace("ColorCorrectionEffect", "Correccion") :: ColorCorrectionEffect
	Atmosphere.setMood("pasillo", true)
end

--- Cambia el clima de color. Es lo que hace que el aula "se sienta"
--- distinta del pasillo sin tocar una sola luz.
function Atmosphere.setMood(name: string, instant: boolean?)
	local preset = (E.Climas :: any)[name]
	if not preset or not correction then
		return
	end
	mood = name

	local goal = {
		Brightness = preset.brillo,
		Contrast = preset.contraste,
		Saturation = preset.saturacion,
		TintColor = preset.tinte,
	}

	if instant then
		for key, value in goal do
			(correction :: any)[key] = value
		end
		return
	end
	TweenService:Create(correction, TweenInfo.new(1.4, Enum.EasingStyle.Sine), goal):Play()
end

function Atmosphere.mood(): string
	return mood
end

-- ── luminarias ─────────────────────────────────────────────────────

--- Una luminaria empotrada en el falso techo: marco de aluminio,
--- difusor neon y una SurfaceLight que baña hacia abajo.
---
--- SurfaceLight y no PointLight a proposito: una luz puntual dentro de
--- un panel largo hace un charco redondo en el piso; la de superficie
--- reparte parejo, que es como se ve un fluorescente de verdad.
function Atmosphere.troffer(parent: Instance, cframe: CFrame, width: number,
	length: number, shadows: boolean): BasePart
	local frame = Instance.new("Part")
	frame.Name = "Luminaria"
	frame.Anchored = true
	frame.CanCollide = false
	frame.Size = Vector3.new(width, 0.4, length)
	frame.CFrame = cframe
	Style.paint(frame, Style.Color.Rejilla, Style.Material.MetalLiso, 0.1)
	frame.Parent = parent

	local diffuser = Instance.new("Part")
	diffuser.Name = "Difusor"
	diffuser.Anchored = true
	diffuser.CanCollide = false
	diffuser.CastShadow = false
	diffuser.Size = Vector3.new(width - 0.5, 0.16, length - 0.5)
	diffuser.CFrame = cframe * CFrame.new(0, -0.24, 0)
	Style.paint(diffuser, Style.Color.Tubo, Style.Material.Neon)
	diffuser.Parent = parent

	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 110
	light.Range = 30
	light.Brightness = 1.35
	light.Color = Style.Color.LuzFria
	-- Solo algunas proyectan sombra: en Future cada luz con sombra
	-- cuesta, y con todas encendidas el colegio no corre en una
	-- maquina modesta.
	light.Shadows = shadows
	light.Parent = diffuser

	return frame
end

--- Cartel de SALIDA: el unico rojo del pasillo. Ancla la vista y da
--- escala en un corredor largo y monotono.
function Atmosphere.exitSign(parent: Instance, cframe: CFrame): BasePart
	local box = Instance.new("Part")
	box.Name = "Salida"
	box.Anchored = true
	box.CanCollide = false
	box.Size = Vector3.new(3.2, 1.1, 0.35)
	box.CFrame = cframe
	Style.paint(box, Style.Color.Salida, Style.Material.Neon)
	box.Parent = parent

	local glow = Instance.new("PointLight")
	glow.Brightness = 0.5
	glow.Range = 9
	glow.Color = Style.Color.Salida
	glow.Shadows = false
	glow.Parent = box

	return box
end

-- ── entrada ────────────────────────────────────────────────────────

function Atmosphere.apply()
	-- Lo que si se puede escribir en runtime.
	Lighting.Brightness = E.Brillo
	Lighting.ClockTime = E.Hora
	Lighting.GeographicLatitude = E.Latitud
	Lighting.ExposureCompensation = E.Exposicion
	Lighting.EnvironmentDiffuseScale = E.DifusaEntorno
	Lighting.EnvironmentSpecularScale = E.EspecularEntorno
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(28, 30, 34)
	Lighting.OutdoorAmbient = Color3.fromRGB(86, 92, 104)
	Lighting.FogEnd = 1200

	pcall(function()
		-- Solo existe con Future; con ShadowMap no molesta.
		Lighting.ShadowSoftness = E.SuavidadSombras
	end)

	buildSky()
	buildAtmosphere()
	buildClouds()
	buildPost()

	-- Verificacion honesta: si el lugar quedo en Voxel, no hay sombras
	-- proyectadas y todo el trabajo de arriba se ve la mitad de bien.
	local technology = Lighting.Technology.Name
	if technology ~= "Future" and technology ~= "ShadowMap" then
		warn(string.format(
			"[Luz] Lighting.Technology esta en %s. Ponelo en %s "
				.. "(Lighting > Technology en Studio): es de solo lectura "
				.. "desde un script y sin eso no hay sombras reales.",
			technology, E.Tecnologia))
	else
		print(string.format("[Luz] %s, nubes al %d%%, look desaturado.",
			technology, math.floor(E.Nubes.cobertura * 100)))
	end
end

return Atmosphere

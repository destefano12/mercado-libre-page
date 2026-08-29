--!strict
--[[
	Style
	------------------------------------------------------------------
	La direccion de arte del colegio, en un solo archivo.

	El objetivo es que NO parezca Roblox: nada de plastico saturado.
	Tres decisiones sostienen el look entero:

	  1. Paleta desaturada y fria. Ningun color pasa de ~60% de
	     saturacion. Los unicos acentos calidos son la madera de los
	     pupitres y el oxido: todo lo demas tira a gris verdoso.
	  2. Materiales PBR del motor, no SmoothPlastic. Concrete, Brick,
	     CeramicTiles, WoodPlanks y Metal ya traen mapas de rugosidad y
	     normales de verdad; con Future se ven como superficies, no
	     como bloques pintados.
	  3. El desgaste es geometria. Manchas, rayones y oxido son piezas
	     finisimas encima de la superficie base — asi se ve gastado sin
	     tener que subir una sola textura.

	Si subis tus propias texturas PBR, poné los ids en Config.Texturas
	y `Style.applySurface` las aplica encima de todo esto.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Style = {}

-- ── paleta exacta ──────────────────────────────────────────────────
-- Los RGB son literales a proposito: esta tabla ES la identidad
-- visual del juego y tiene que poder copiarse a mano en Studio.
Style.Color = {
	-- muros
	MuroAlto = Color3.fromRGB(214, 208, 191),      -- crema institucional
	MuroBajo = Color3.fromRGB(47, 66, 58),         -- friso verde oscuro
	MuroFranja = Color3.fromRGB(92, 112, 96),      -- linea de acento
	MuroSucio = Color3.fromRGB(178, 172, 156),     -- manchas de roce

	-- techos
	Placa = Color3.fromRGB(226, 224, 214),         -- placa acustica
	PlacaSucia = Color3.fromRGB(206, 200, 184),    -- filtracion
	Rejilla = Color3.fromRGB(158, 160, 163),       -- perfil de aluminio
	Losa = Color3.fromRGB(120, 118, 112),

	-- pisos
	Baldosa = Color3.fromRGB(150, 146, 136),
	BaldosaAlterna = Color3.fromRGB(132, 128, 119),
	BaldosaGastada = Color3.fromRGB(118, 114, 106),
	Cera = Color3.fromRGB(168, 165, 155),          -- brillo del encerado

	-- casilleros
	Casillero = Color3.fromRGB(40, 74, 82),        -- verde azulado
	CasilleroLuz = Color3.fromRGB(58, 96, 104),
	Rayon = Color3.fromRGB(96, 116, 120),
	Oxido = Color3.fromRGB(122, 76, 48),
	Manija = Color3.fromRGB(186, 188, 190),

	-- mobiliario
	Madera = Color3.fromRGB(168, 130, 84),         -- roble viejo
	MaderaGastada = Color3.fromRGB(138, 104, 66),
	MaderaOscura = Color3.fromRGB(104, 76, 48),
	Metal = Color3.fromRGB(74, 78, 84),
	MetalClaro = Color3.fromRGB(122, 126, 132),
	Asiento = Color3.fromRGB(38, 54, 72),

	-- aula
	Pizarra = Color3.fromRGB(38, 62, 52),
	MarcoPizarra = Color3.fromRGB(176, 176, 172),
	Tiza = Color3.fromRGB(228, 232, 226),
	Puerta = Color3.fromRGB(116, 84, 54),
	MarcoPuerta = Color3.fromRGB(96, 100, 106),
	Vidrio = Color3.fromRGB(178, 196, 206),

	-- luz
	Tubo = Color3.fromRGB(246, 250, 236),
	LuzFria = Color3.fromRGB(226, 238, 255),
	LuzCalida = Color3.fromRGB(255, 236, 206),
	Salida = Color3.fromRGB(226, 66, 54),          -- cartel de salida
}

-- ── materiales ─────────────────────────────────────────────────────
-- Todos son PBR del motor: traen normal y rugosidad reales.
Style.Material = {
	MuroAlto = Enum.Material.Concrete,
	MuroBajo = Enum.Material.Brick,
	Placa = Enum.Material.Plaster,
	Rejilla = Enum.Material.Metal,
	Piso = Enum.Material.CeramicTiles,
	PisoGastado = Enum.Material.Pavement,
	Casillero = Enum.Material.Metal,
	Oxido = Enum.Material.CorrodedMetal,
	Madera = Enum.Material.WoodPlanks,
	MaderaLisa = Enum.Material.Wood,
	Metal = Enum.Material.DiamondPlate,
	MetalLiso = Enum.Material.Metal,
	Pizarra = Enum.Material.Slate,
	Vidrio = Enum.Material.Glass,
	Tela = Enum.Material.Fabric,
	Neon = Enum.Material.Neon,
}

-- ── reflectancia ───────────────────────────────────────────────────
-- El suelo encerado es lo unico que refleja de verdad. Un colegio con
-- todo brillante parece un shopping.
Style.Reflectance = {
	Piso = 0.06,
	Casillero = 0.04,
	Pizarra = 0.02,
	Vidrio = 0.25,
	Manija = 0.18,
}

--- Aplica color + material + reflectancia de una sola vez.
function Style.paint(part: BasePart, color: Color3, material: Enum.Material, reflectance: number?)
	part.Color = color
	part.Material = material
	part.Reflectance = reflectance or 0
end

-- ── texturas propias ───────────────────────────────────────────────

local function assetUrl(id: string): string
	if id == "" then
		return ""
	end
	return string.find(id, "://") and id or ("rbxassetid://" .. id)
end

--- Cuelga un SurfaceAppearance de la parte si Config.Texturas tiene
--- ids cargados para esa familia. Sin ids, no hace nada y la parte se
--- queda con el material PBR del motor.
---
--- SurfaceAppearance manda sobre Material: por eso el color base pasa
--- a ser el del ColorMap y `part.Color` deja de verse. Es lo esperado.
function Style.applySurface(part: BasePart, family: string): boolean
	local textures = (Config.Texturas :: any)[family]
	if not textures or textures.color == "" then
		return false
	end
	if part:FindFirstChildOfClass("SurfaceAppearance") then
		return true
	end

	local ok = pcall(function()
		local surface = Instance.new("SurfaceAppearance")
		surface.Name = "PBR"
		surface.ColorMap = assetUrl(textures.color)
		if textures.normal ~= "" then
			surface.NormalMap = assetUrl(textures.normal)
		end
		if textures.rugosidad ~= "" then
			surface.RoughnessMap = assetUrl(textures.rugosidad)
		end
		if textures.metalidad ~= "" then
			surface.MetalnessMap = assetUrl(textures.metalidad)
		end
		surface.Parent = part
	end)
	return ok
end

--- Recorre un modelo y aplica las texturas propias por nombre de pieza.
function Style.applySurfaces(root: Instance, mapping: { [string]: string })
	local applied = 0
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			local family = mapping[descendant.Name]
			if family and Style.applySurface(descendant, family) then
				applied += 1
			end
		end
	end
	return applied
end

--- Que familia de textura le toca a cada pieza del mapa.
Style.SurfaceMap = {
	Pared = "Pared",
	ParedLateral = "Pared",
	ParedFondo = "Pared",
	ParedPasillo = "Pared",
	Fondo = "Pared",
	Dintel = "Pared",
	Piso = "Piso",
	Baldosa = "Piso",
	Cuerpo = "Casillero",
	PuertaCasillero = "Casillero",
	Pupitre = "Pupitre",
	EscritorioProfesor = "Pupitre",
	Placa = "Techo",
}

table.freeze(Style.Color)
table.freeze(Style.Material)
return Style

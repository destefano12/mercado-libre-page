--!strict
--[[
	Previews
	------------------------------------------------------------------
	Miniaturas 3D de los articulos de la tienda.

	Por que existe en vez de reutilizar `Templates`: las herramientas de
	verdad las arma `src/server/Templates.lua` dentro de ServerStorage,
	y el cliente no puede leer de ahi — es codigo de servidor y ademas
	ServerStorage no se replica. Replicarlas solo para dibujar una
	tarjeta seria mandar Tools completos, con sus ProximityPrompt y sus
	atributos, para mostrar un dibujito.

	Asi que aca viven siluetas: las mismas medidas y los mismos colores
	que la herramienta real, con tres o cuatro partes en vez de quince.
	Lo que el jugador tiene que reconocer es la forma, no el mecanismo.

	Cada modelo sale centrado en el origen y entra en un cubo de ~2
	studs, para que la camara del ViewportFrame no tenga que ajustarse
	por articulo.
--]]

local Previews = {}

local function part(parent: Instance, size: Vector3, offset: CFrame, color: Color3,
	material: Enum.Material?): BasePart
	local piece = Instance.new("Part")
	piece.Size = size
	piece.CFrame = offset
	piece.Color = color
	piece.Material = material or Enum.Material.SmoothPlastic
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Parent = parent
	return piece
end

local function rounded(piece: BasePart, shape: Enum.PartType)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = shape == Enum.PartType.Ball and Enum.MeshType.Sphere or Enum.MeshType.Cylinder
	mesh.Parent = piece
end

--[[
	La cabeza de maniqui.

	En el trailer las casillas de la grilla no muestran el peinado
	suelto: muestran una cabeza puesta, con el pelo encima. Tiene
	sentido — un peinado desprendido de la cabeza no se entiende, y dos
	peinados distintos flotando se parecen entre si.

	Sale gris palido a proposito: la casilla es de fondo tostado y lo
	que tiene que resaltar es la prenda, no el maniqui.
--]]
local MANIQUI = Color3.fromRGB(236, 232, 226)
local HAIR = Color3.fromRGB(126, 88, 62)

local function head(model: Model): BasePart
	local skull = part(model, Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, -0.1, 0), MANIQUI)
	rounded(skull, Enum.PartType.Ball)
	return skull
end

--[[
	Ojos y boca del maniqui.

	Las casillas de cejas y marcas son rasgos planos: sobre una esfera
	lisa no se entiende ni cual es el derecho de la cabeza, y una ceja
	flotando sobre nada no se lee como una ceja. Con dos ojos dibujados,
	si.
--]]
local function face(model: Model)
	head(model)
	for _, side in { -1, 1 } do
		part(model, Vector3.new(0.26, 0.36, 0.06), CFrame.new(side * 0.26, 0, -0.62),
			Color3.fromRGB(252, 252, 250))
		part(model, Vector3.new(0.13, 0.18, 0.05), CFrame.new(side * 0.26, -0.05, -0.65),
			Color3.fromRGB(28, 26, 34))
	end
	part(model, Vector3.new(0.3, 0.06, 0.06), CFrame.new(0, -0.46, -0.62),
		Color3.fromRGB(126, 62, 68))
end

--- Un par de cejas simetricas sobre los ojos de `face`.
local function brow(model: Model, width: number, thick: number, angle: number,
	offsetX: number?, offsetY: number?)
	for _, side in { -1, 1 } do
		part(model, Vector3.new(width, thick, 0.06),
			CFrame.new(side * (offsetX or 0.26), 0.3 + (offsetY or 0), -0.64)
				* CFrame.Angles(0, 0, math.rad(side * angle)),
			HAIR)
	end
end

-- Cada constructor recibe el modelo vacio y le cuelga las piezas.
local BUILDERS: { [string]: (Model) -> () } = {
	nota = function(model)
		part(model, Vector3.new(1.6, 0.08, 1.2), CFrame.new(0, 0, 0),
			Color3.fromRGB(250, 248, 240))
		part(model, Vector3.new(1.6, 0.06, 0.3), CFrame.new(0, 0.06, -0.42),
			Color3.fromRGB(226, 222, 210))
	end,

	avion = function(model)
		part(model, Vector3.new(0.16, 0.36, 1.7), CFrame.new(0, 0, 0),
			Color3.fromRGB(248, 246, 238))
		for _, side in { -1, 1 } do
			part(model, Vector3.new(0.06, 0.44, 1.2),
				CFrame.new(side * 0.32, -0.02, 0.1) * CFrame.Angles(0, 0, side * 0.5),
				Color3.fromRGB(240, 238, 230))
		end
	end,

	bolita = function(model)
		local ball = part(model, Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 0, 0),
			Color3.fromRGB(244, 242, 234))
		rounded(ball, Enum.PartType.Ball)
	end,

	chuleta = function(model)
		part(model, Vector3.new(1.9, 0.06, 0.7), CFrame.new(0, 0, 0),
			Color3.fromRGB(252, 250, 236))
		for i = 0, 2 do
			part(model, Vector3.new(1.4, 0.02, 0.06),
				CFrame.new(0, 0.05, -0.2 + i * 0.2), Color3.fromRGB(40, 60, 130))
		end
	end,

	walkie = function(model)
		part(model, Vector3.new(0.62, 1.5, 0.42), CFrame.new(0, -0.1, 0),
			Color3.fromRGB(32, 34, 40))
		part(model, Vector3.new(0.1, 0.7, 0.1), CFrame.new(0.18, 0.92, 0),
			Color3.fromRGB(18, 18, 22))
		part(model, Vector3.new(0.4, 0.24, 0.05), CFrame.new(-0.05, 0.36, -0.22),
			Color3.fromRGB(94, 232, 122), Enum.Material.Neon)
		part(model, Vector3.new(0.44, 0.3, 0.04), CFrame.new(-0.05, -0.06, -0.22),
			Color3.fromRGB(58, 62, 70), Enum.Material.DiamondPlate)
	end,

	prismaticos = function(model)
		part(model, Vector3.new(1.15, 0.6, 0.78), CFrame.new(0, 0, 0),
			Color3.fromRGB(28, 30, 36))
		for _, side in { -1, 1 } do
			part(model, Vector3.new(0.5, 0.5, 0.9),
				CFrame.new(side * 0.34, 0, 0.1), Color3.fromRGB(22, 24, 30))
			part(model, Vector3.new(0.42, 0.42, 0.06),
				CFrame.new(side * 0.34, 0, 0.56), Color3.fromRGB(150, 200, 232),
				Enum.Material.Glass)
		end
	end,

	celular = function(model)
		-- Ladrillo noventoso: LCD verde chico arriba y teclado abajo.
		part(model, Vector3.new(0.8, 1.7, 0.32), CFrame.new(0, 0, 0),
			Color3.fromRGB(96, 100, 106))
		part(model, Vector3.new(0.56, 0.48, 0.06), CFrame.new(0, 0.48, -0.17),
			Color3.fromRGB(126, 208, 108), Enum.Material.Neon)
		for row = 0, 2 do
			part(model, Vector3.new(0.58, 0.14, 0.06),
				CFrame.new(0, -0.02 - row * 0.22, -0.17),
				Color3.fromRGB(58, 60, 68))
		end
		part(model, Vector3.new(0.1, 0.44, 0.1), CFrame.new(0.28, 1.05, 0),
			Color3.fromRGB(38, 40, 46))
	end,

	libro = function(model)
		part(model, Vector3.new(1.5, 2, 0.36), CFrame.new(0, 0, 0),
			Color3.fromRGB(126, 44, 52))
		part(model, Vector3.new(1.4, 1.88, 0.32), CFrame.new(0.06, 0, 0),
			Color3.fromRGB(246, 244, 234))
		part(model, Vector3.new(0.12, 2, 0.38), CFrame.new(-0.7, 0, 0),
			Color3.fromRGB(96, 32, 40))
	end,

	aerosol = function(model)
		local can = part(model, Vector3.new(0.7, 1.5, 0.7), CFrame.new(0, -0.1, 0),
			Color3.fromRGB(210, 66, 66))
		rounded(can, Enum.PartType.Cylinder)
		part(model, Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 0.78, 0),
			Color3.fromRGB(238, 238, 232))
		part(model, Vector3.new(0.66, 0.22, 0.66), CFrame.new(0, 0.34, 0),
			Color3.fromRGB(238, 238, 232))
	end,

	gorra = function(model)
		head(model)
		local dome = part(model, Vector3.new(1.42, 0.86, 1.42), CFrame.new(0, 0.42, 0),
			Color3.fromRGB(226, 84, 72))
		rounded(dome, Enum.PartType.Ball)
		part(model, Vector3.new(1.42, 0.14, 0.8), CFrame.new(0, 0.24, -0.82),
			Color3.fromRGB(198, 66, 58))
	end,

	boina = function(model)
		head(model)
		local disc = part(model, Vector3.new(1.66, 0.3, 1.66), CFrame.new(0, 0.5, 0.08),
			Color3.fromRGB(58, 76, 172))
		rounded(disc, Enum.PartType.Cylinder)
		part(model, Vector3.new(0.16, 0.24, 0.16), CFrame.new(0, 0.68, 0.08),
			Color3.fromRGB(42, 58, 140))
	end,

	vincha = function(model)
		head(model)
		local band = part(model, Vector3.new(1.44, 0.26, 1.44), CFrame.new(0, 0.36, 0),
			Color3.fromRGB(238, 96, 148))
		rounded(band, Enum.PartType.Cylinder)
		part(model, Vector3.new(0.3, 0.3, 0.12), CFrame.new(0.5, 0.42, -0.5),
			Color3.fromRGB(252, 206, 92))
	end,

	antifaz = function(model)
		head(model)
		part(model, Vector3.new(1.24, 0.42, 0.2), CFrame.new(0, 0.06, -0.62),
			Color3.fromRGB(32, 32, 46))
		for _, side in { -1, 1 } do
			part(model, Vector3.new(0.34, 0.2, 0.06), CFrame.new(side * 0.26, 0.08, -0.72),
				Color3.fromRGB(238, 238, 242))
		end
	end,

	bufanda = function(model)
		head(model)
		local loop = part(model, Vector3.new(1.5, 0.44, 1.5), CFrame.new(0, -0.86, 0),
			Color3.fromRGB(198, 62, 78))
		rounded(loop, Enum.PartType.Cylinder)
		part(model, Vector3.new(0.42, 0.9, 0.24), CFrame.new(-0.34, -1.32, -0.4),
			Color3.fromRGB(176, 48, 66))
	end,

	mochila = function(model)
		part(model, Vector3.new(1.4, 1.6, 0.75), CFrame.new(0, 0, 0),
			Color3.fromRGB(58, 96, 72))
		part(model, Vector3.new(1.2, 0.5, 0.3), CFrame.new(0, -0.42, -0.5),
			Color3.fromRGB(44, 76, 56))
		for _, side in { -1, 1 } do
			part(model, Vector3.new(0.22, 1.4, 0.16),
				CFrame.new(side * 0.44, 0.06, 0.44), Color3.fromRGB(38, 66, 48))
		end
	end,

	anteojos = function(model)
		head(model)
		for _, side in { -1, 1 } do
			part(model, Vector3.new(0.5, 0.42, 0.06),
				CFrame.new(side * 0.3, 0.04, -0.66), Color3.fromRGB(168, 208, 232),
				Enum.Material.Glass)
			part(model, Vector3.new(0.54, 0.06, 0.06),
				CFrame.new(side * 0.3, 0.26, -0.66), Color3.fromRGB(52, 50, 66))
			part(model, Vector3.new(0.06, 0.06, 0.5),
				CFrame.new(side * 0.54, 0.14, -0.42), Color3.fromRGB(52, 50, 66))
		end
		part(model, Vector3.new(0.14, 0.06, 0.06), CFrame.new(0, 0.14, -0.66),
			Color3.fromRGB(52, 50, 66))
	end,

	--[[
		Los seis peinados. Se dibujan con el mismo tono de castano para
		todos a proposito: en el carnet lo que hay que comparar es la
		SILUETA, y seis colores distintos harian que el jugador elija por
		color y despues se lleve una sorpresa (el color del pelo sale de
		su UserId, no de la casilla).
	--]]
	pelo_corto = function(model)
		head(model)
		local cap = part(model, Vector3.new(1.36, 1.36, 1.36), CFrame.new(0, 0.14, 0), HAIR)
		rounded(cap, Enum.PartType.Ball)
		part(model, Vector3.new(1.24, 0.34, 0.26), CFrame.new(0, 0.3, -0.6), HAIR)
	end,

	pelo_rulos = function(model)
		head(model)
		for _, spot in {
			Vector3.new(0, 0.62, 0), Vector3.new(-0.46, 0.42, 0.16),
			Vector3.new(0.46, 0.42, 0.16), Vector3.new(-0.32, 0.36, -0.44),
			Vector3.new(0.32, 0.36, -0.44), Vector3.new(0, 0.3, 0.56),
		} do
			local curl = part(model, Vector3.new(0.68, 0.68, 0.68), CFrame.new(spot), HAIR)
			rounded(curl, Enum.PartType.Ball)
		end
	end,

	pelo_largo = function(model)
		head(model)
		local cap = part(model, Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, 0.16, 0), HAIR)
		rounded(cap, Enum.PartType.Ball)
		for _, side in { -1, 1 } do
			part(model, Vector3.new(0.34, 1.3, 0.9), CFrame.new(side * 0.6, -0.5, 0.1), HAIR)
		end
		part(model, Vector3.new(1.2, 0.3, 0.24), CFrame.new(0, 0.34, -0.62), HAIR)
	end,

	pelo_cresta = function(model)
		head(model)
		part(model, Vector3.new(0.22, 0.9, 1.34), CFrame.new(0, 0.66, 0.04), HAIR)
		part(model, Vector3.new(0.9, 0.28, 1.3), CFrame.new(0, 0.24, 0.04), HAIR)
	end,

	pelo_coletas = function(model)
		head(model)
		local cap = part(model, Vector3.new(1.36, 1.36, 1.36), CFrame.new(0, 0.14, 0), HAIR)
		rounded(cap, Enum.PartType.Ball)
		for _, side in { -1, 1 } do
			local tail = part(model, Vector3.new(0.62, 0.62, 0.62),
				CFrame.new(side * 0.86, 0.16, 0.2), HAIR)
			rounded(tail, Enum.PartType.Ball)
			part(model, Vector3.new(0.2, 0.2, 0.2), CFrame.new(side * 0.62, 0.3, 0.2),
				Color3.fromRGB(238, 96, 148))
		end
	end,

	pelo_afro = function(model)
		head(model)
		local puff = part(model, Vector3.new(2, 1.9, 2), CFrame.new(0, 0.28, 0), HAIR)
		rounded(puff, Enum.PartType.Ball)
	end,

	--[[
		Cejas y marcas.

		Se dibujan sobre la MISMA cabeza de maniqui que los peinados, y
		girada un poco hacia el costado no se entenderian: son rasgos
		planos sobre la cara. Por eso la camara del carnet las mira de
		frente y el giro al senalar con el cursor es leve.

		Los ojos van en todas: una ceja flotando sobre una esfera lisa
		no se lee como una ceja.
	--]]
	cejas_rectas = function(model)
		face(model)
		brow(model, 0.34, 0.07, 0)
	end,
	cejas_finas = function(model)
		face(model)
		brow(model, 0.36, 0.04, 4)
	end,
	cejas_gruesas = function(model)
		face(model)
		brow(model, 0.4, 0.14, 3)
	end,
	cejas_arqueadas = function(model)
		face(model)
		brow(model, 0.28, 0.06, -16)
		-- La cola que baja por fuera: sin ella el tramo inclinado se
		-- lee como un acento, no como un arco.
		brow(model, 0.16, 0.06, -48, 0.44, -0.06)
	end,
	cejas_enojadas = function(model)
		face(model)
		brow(model, 0.34, 0.08, 24)
	end,
	cejas_unica = function(model)
		face(model)
		part(model, Vector3.new(0.84, 0.08, 0.06), CFrame.new(0, 0.3, -0.66), HAIR)
	end,

	lunar = function(model)
		face(model)
		part(model, Vector3.new(0.07, 0.07, 0.06), CFrame.new(0.4, -0.34, -0.62),
			Color3.fromRGB(64, 40, 42))
	end,
	pecas = function(model)
		face(model)
		for _, side in { -1, 1 } do
			for i = 0, 2 do
				part(model, Vector3.new(0.05, 0.05, 0.06),
					CFrame.new(side * (0.26 + i * 0.08), -0.2 + (i % 2) * 0.06, -0.63),
					Color3.fromRGB(178, 116, 96))
			end
		end
	end,
	rubor = function(model)
		face(model)
		for _, side in { -1, 1 } do
			part(model, Vector3.new(0.22, 0.13, 0.05), CFrame.new(side * 0.38, -0.24, -0.62),
				Color3.fromRGB(240, 138, 152))
		end
	end,
	cicatriz = function(model)
		face(model)
		part(model, Vector3.new(0.05, 0.42, 0.06),
			CFrame.new(0.26, 0.18, -0.64) * CFrame.Angles(0, 0, math.rad(14)),
			Color3.fromRGB(198, 128, 122))
	end,
	tirita = function(model)
		face(model)
		part(model, Vector3.new(0.36, 0.11, 0.06),
			CFrame.new(-0.32, -0.2, -0.64) * CFrame.Angles(0, 0, math.rad(-22)),
			Color3.fromRGB(238, 206, 168))
		part(model, Vector3.new(0.14, 0.08, 0.05),
			CFrame.new(-0.32, -0.2, -0.67) * CFrame.Angles(0, 0, math.rad(-22)),
			Color3.fromRGB(250, 244, 236))
	end,
	bigote = function(model)
		face(model)
		for _, side in { -1, 1 } do
			part(model, Vector3.new(0.22, 0.08, 0.07),
				CFrame.new(side * 0.12, -0.34, -0.64) * CFrame.Angles(0, 0, math.rad(side * -12)),
				HAIR)
		end
	end,

	campera = function(model)
		part(model, Vector3.new(1.5, 1.5, 0.6), CFrame.new(0, 0, 0),
			Color3.fromRGB(96, 32, 42))
		for _, side in { -1, 1 } do
			part(model, Vector3.new(0.42, 1.3, 0.5),
				CFrame.new(side * 0.94, -0.08, 0), Color3.fromRGB(84, 28, 36))
		end
		part(model, Vector3.new(0.16, 1.4, 0.06), CFrame.new(0, 0, -0.3),
			Color3.fromRGB(198, 198, 202), Enum.Material.Metal)
	end,
}

--[[
	Devuelve el modelo del articulo, o `nil` si no hay ninguno definido
	para ese id. La tienda dibuja un icono plano cuando esto da nil, asi
	que agregar un articulo nuevo no rompe la tarjeta — solo se ve mas
	pobre hasta que alguien le escriba la silueta.
--]]
function Previews.build(id: string): Model?
	local builder = BUILDERS[id]
	if not builder then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = id
	builder(model)
	local first = model:FindFirstChildWhichIsA("BasePart")
	if first then
		model.PrimaryPart = first
	end
	return model
end

function Previews.has(id: string): boolean
	return BUILDERS[id] ~= nil
end

return Previews

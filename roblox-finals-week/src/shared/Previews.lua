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
		part(model, Vector3.new(1.5, 0.62, 1.5), CFrame.new(0, 0.1, 0),
			Color3.fromRGB(44, 92, 148))
		part(model, Vector3.new(1.5, 0.12, 0.85), CFrame.new(0, -0.2, -0.9),
			Color3.fromRGB(32, 70, 118))
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
		for _, side in { -1, 1 } do
			part(model, Vector3.new(0.62, 0.5, 0.06),
				CFrame.new(side * 0.38, 0, 0), Color3.fromRGB(168, 208, 232),
				Enum.Material.Glass)
			part(model, Vector3.new(0.14, 0.1, 0.6),
				CFrame.new(side * 0.66, 0.14, 0.3), Color3.fromRGB(28, 30, 36))
		end
		part(model, Vector3.new(0.2, 0.08, 0.06), CFrame.new(0, 0, 0),
			Color3.fromRGB(28, 30, 36))
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

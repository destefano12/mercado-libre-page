--!strict
--[[
	MapBuilder
	------------------------------------------------------------------
	Arma el instituto entero por codigo, modular y en piezas nombradas
	para que el resto del juego no tenga que adivinar donde esta nada:

		Workspace/Instituto/Pasillo      casilleros + zona de recreo
		Workspace/Instituto/Aulas/Aula1  filas fijas de pupitres,
		                                 tarima, pizarra y puerta
		Workspace/Instituto/Castigo      la sala de castigo
		Workspace/Personajes             alumnos y el NPC del profesor
		Workspace/Objetos                cosas interactivas del mapa
		Workspace/Proyectiles            lo que vuela por el aire

	Todo se construye con la geometria de Config.Escuela: cambiando
	esos numeros cambia el colegio, no hay medidas escritas a mano.

	Cada pieza va dentro de su propio pcall: si una silla explota, el
	resto del colegio se construye igual y el Output dice cual fallo.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Theme = require(Shared:WaitForChild("Theme"))
local Util = require(Shared:WaitForChild("Util"))

local E = Config.Escuela

local MapBuilder = {}

export type Desk = {
	seat: Seat,
	desk: BasePart,
	paper: BasePart,
	fila: number,
	asiento: number,
	aula: number,
}

export type Classroom = {
	index: number,
	model: Model,
	center: Vector3,
	dir: Vector3,          -- de la pizarra hacia el fondo del aula
	desks: { Desk },
	door: BasePart,
	blackboard: BasePart,
	podium: BasePart,
	patrol: { Vector3 },   -- puntos de patrullaje del profesor
	spawn: Vector3,        -- donde aparece el profesor
}

export type Map = {
	root: Model,
	hallway: Model,
	classrooms: { Classroom },
	lockers: { Model },
	shop: BasePart,
	detention: BasePart,
	bell: BasePart,
	spawns: { Vector3 },
}

-- ── helpers ────────────────────────────────────────────────────────

local function block(parent: Instance, name: string, size: Vector3, cf: CFrame,
	color: Color3, material: Enum.Material): BasePart
	local part = Util.part({
		Name = name,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = material,
		Parent = parent,
	})
	return part
end

local function safely(label: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn(string.format("[Mapa] %s fallo: %s", label, tostring(err)))
	end
end

--- Un cartel de texto pegado a una pared (para nombres de aula, etc).
local function sign(parent: Instance, text: string, size: Vector2, cf: CFrame, face: Enum.NormalId)
	local plate = block(parent, "Cartel", Vector3.new(size.X, size.Y, 0.2), cf,
		Color3.fromRGB(28, 32, 40), Enum.Material.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 48
	gui.LightInfluence = 0.2
	gui.Parent = plate

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Theme.FontBold
	label.Text = text
	label.TextColor3 = Color3.fromRGB(238, 240, 246)
	label.TextScaled = true
	label.Parent = gui
end

-- ── pasillo ────────────────────────────────────────────────────────

local function buildLocker(parent: Instance, cf: CFrame, index: number): Model
	local model = Instance.new("Model")
	model.Name = "Casillero" .. index
	model.Parent = parent

	local body = block(model, "Cuerpo",
		Vector3.new(E.CasilleroAncho, E.CasilleroAlto, E.CasilleroFondo), cf,
		E.ColorCasillero, Enum.Material.Metal)
	model.PrimaryPart = body

	-- Puerta un poco mas clara, con rejilla y manija.
	local door = block(model, "Puerta",
		Vector3.new(E.CasilleroAncho - 0.25, E.CasilleroAlto - 0.3, 0.18),
		cf * CFrame.new(0, 0, E.CasilleroFondo / 2 + 0.09),
		E.ColorCasillero:Lerp(Color3.new(1, 1, 1), 0.16), Enum.Material.Metal)
	door.CanCollide = false

	block(model, "Rejilla", Vector3.new(E.CasilleroAncho - 1.4, 0.9, 0.08),
		cf * CFrame.new(0, E.CasilleroAlto / 2 - 1.1, E.CasilleroFondo / 2 + 0.19),
		Color3.fromRGB(24, 30, 38), Enum.Material.DiamondPlate).CanCollide = false

	block(model, "Manija", Vector3.new(0.22, 1.1, 0.16),
		cf * CFrame.new(E.CasilleroAncho / 2 - 0.55, -0.4, E.CasilleroFondo / 2 + 0.2),
		Color3.fromRGB(206, 210, 216), Enum.Material.Metal).CanCollide = false

	local number = Instance.new("SurfaceGui")
	number.Face = Enum.NormalId.Front
	number.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	number.PixelsPerStud = 40
	number.Parent = door
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 42)
	label.Position = UDim2.new(0, 0, 0, 8)
	label.BackgroundTransparency = 1
	label.Font = Theme.FontBold
	label.Text = string.format("%03d", index)
	label.TextColor3 = Color3.fromRGB(224, 230, 240)
	label.TextScaled = true
	label.Parent = number

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Abrir"
	prompt.ActionText = "Abrir"
	prompt.ObjectText = "Casillero " .. index
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = door

	model:SetAttribute("Indice", index)
	return model
end

local function buildRecreation(parent: Instance, zStart: number): BasePart
	local half = E.PasilloAncho / 2

	-- Bancos largos contra las paredes.
	for i = 0, 2 do
		local z = zStart + 6 + i * 10
		for _, side in { -1, 1 } do
			local x = side * (half - 3)
			block(parent, "Banco", Vector3.new(2.4, 0.4, 7),
				CFrame.new(x, 1.8, z), Color3.fromRGB(148, 108, 62), Enum.Material.WoodPlanks)
			block(parent, "PataBanco", Vector3.new(2, 1.6, 0.5),
				CFrame.new(x, 0.9, z - 2.6), Color3.fromRGB(74, 78, 88), Enum.Material.Metal)
			block(parent, "PataBanco", Vector3.new(2, 1.6, 0.5),
				CFrame.new(x, 0.9, z + 2.6), Color3.fromRGB(74, 78, 88), Enum.Material.Metal)
		end
	end

	-- Maquinas expendedoras.
	for i, side in { -1, 1 } do
		local x = side * (half - 1.6)
		local body = block(parent, "Expendedora", Vector3.new(2.6, 8, 4.4),
			CFrame.new(x, 4, zStart + 2 + i * 4), Color3.fromRGB(180, 46, 52), Enum.Material.Metal)
		block(parent, "Vidrio", Vector3.new(0.2, 5.6, 3.4),
			body.CFrame * CFrame.new(-side * 1.35, 0.6, 0),
			Color3.fromRGB(160, 200, 220), Enum.Material.Glass).Transparency = 0.55
	end

	-- Mesa de ping pong en el centro del recreo.
	local table_ = block(parent, "MesaPingPong", Vector3.new(9, 0.4, 5),
		CFrame.new(0, 3, zStart + 18), Color3.fromRGB(24, 92, 62), Enum.Material.SmoothPlastic)
	block(parent, "Red", Vector3.new(0.2, 1.1, 5),
		table_.CFrame * CFrame.new(0, 0.75, 0), Color3.fromRGB(235, 238, 244), Enum.Material.Fabric).CanCollide = false
	for _, dx in { -3.8, 3.8 } do
		for _, dz in { -2, 2 } do
			block(parent, "PataMesa", Vector3.new(0.4, 3, 0.4),
				CFrame.new(dx, 1.5, zStart + 18 + dz), Color3.fromRGB(64, 68, 78), Enum.Material.Metal)
		end
	end

	-- Plantas y tachos, para que el pasillo no sea un tubo vacio.
	for i = 0, 3 do
		local z = zStart + 4 + i * 8
		local side = (i % 2 == 0) and -1 or 1
		local pot = block(parent, "Maceta", Vector3.new(2, 2, 2),
			CFrame.new(side * (half - 2.4), 1, z), Color3.fromRGB(126, 92, 68), Enum.Material.Slate)
		local leaves = block(parent, "Planta", Vector3.new(3.4, 4, 3.4),
			pot.CFrame * CFrame.new(0, 2.8, 0), Color3.fromRGB(56, 118, 62), Enum.Material.Grass)
		leaves.Shape = Enum.PartType.Ball
		leaves.CanCollide = false
	end

	-- Kiosco de la tienda: el mostrador con el prompt.
	local counter = block(parent, "Tienda", Vector3.new(10, 4, 3),
		CFrame.new(0, 2, zStart + 30), Color3.fromRGB(206, 168, 92), Enum.Material.WoodPlanks)
	sign(parent, "TIENDA", Vector2.new(9, 2),
		CFrame.new(0, 6.4, zStart + 30), Enum.NormalId.Front)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Tienda"
	prompt.ActionText = "Tienda"
	prompt.ObjectText = "Kiosco"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	return counter
end

local function buildHallway(root: Model): (Model, { Model }, BasePart, BasePart, { Vector3 })
	local hall = Instance.new("Model")
	hall.Name = "Pasillo"
	hall.Parent = root

	local halfW = E.PasilloAncho / 2
	local halfL = E.PasilloLargo / 2

	block(hall, "Piso", Vector3.new(E.PasilloAncho, 1, E.PasilloLargo),
		CFrame.new(0, -0.5, 0), E.ColorPiso, Enum.Material.CeramicTiles)
	block(hall, "Techo", Vector3.new(E.PasilloAncho, 1, E.PasilloLargo),
		CFrame.new(0, E.AlturaPiso, 0), Color3.fromRGB(238, 238, 236), Enum.Material.Plaster)

	-- Paredes largas. Las aulas les abren huecos despues.
	for _, side in { -1, 1 } do
		block(hall, "Pared", Vector3.new(E.EspesorPared, E.AlturaPiso, E.PasilloLargo),
			CFrame.new(side * halfW, E.AlturaPiso / 2, 0), E.ColorParedes, Enum.Material.Concrete)
		block(hall, "Zocalo", Vector3.new(0.35, 1.2, E.PasilloLargo),
			CFrame.new(side * (halfW - 0.6), 0.6, 0), E.ColorZocalo, Enum.Material.SmoothPlastic).CanCollide = false
	end
	-- Tapas de los dos extremos.
	for _, side in { -1, 1 } do
		block(hall, "Fondo", Vector3.new(E.PasilloAncho + 2, E.AlturaPiso, E.EspesorPared),
			CFrame.new(0, E.AlturaPiso / 2, side * halfL), E.ColorParedes, Enum.Material.Concrete)
	end

	-- Luces de tubo cada 12 studs.
	local lights = math.floor(E.PasilloLargo / 12)
	for i = 0, lights do
		local z = -halfL + 6 + i * 12
		local tube = block(hall, "Tubo", Vector3.new(2, 0.3, 6),
			CFrame.new(0, E.AlturaPiso - 0.7, z), Color3.fromRGB(255, 252, 238), Enum.Material.Neon)
		tube.CanCollide = false
		local light = Instance.new("PointLight")
		light.Brightness = 1.1
		light.Range = 26
		light.Color = Color3.fromRGB(255, 250, 236)
		light.Parent = tube
	end

	-- Casilleros: banda central del pasillo, los dos lados.
	local lockers: { Model } = {}
	local bandStart = -halfL + 30
	for side_i, side in { -1, 1 } do
		for i = 0, E.CasillerosPorLado - 1 do
			local z = bandStart + i * (E.CasilleroAncho + 0.15)
			local cf = CFrame.new(side * (halfW - E.CasilleroFondo / 2 - 0.6),
				E.CasilleroAlto / 2, z)
				* CFrame.Angles(0, side < 0 and math.rad(90) or math.rad(-90), 0)
			local index = (side_i - 1) * E.CasillerosPorLado + i + 1
			table.insert(lockers, buildLocker(hall, cf, index))
		end
	end

	local shop = buildRecreation(hall, halfL - E.ZonaRecreoLargo)

	-- La campana, arriba del todo, al lado de la tienda.
	local bell = block(hall, "Campana", Vector3.new(2.2, 2.2, 2.2),
		CFrame.new(0, E.AlturaPiso - 2.6, halfL - 4),
		Color3.fromRGB(196, 156, 62), Enum.Material.Metal)
	bell.Shape = Enum.PartType.Ball
	bell.CanCollide = false

	-- Puntos de aparicion, repartidos en la zona de recreo.
	local spawns: { Vector3 } = {}
	for i = 0, 11 do
		local x = ((i % 4) - 1.5) * 5
		local z = halfL - 8 - math.floor(i / 4) * 6
		table.insert(spawns, Vector3.new(x, 4, z))
	end

	return hall, lockers, shop, bell, spawns
end

-- ── aulas ──────────────────────────────────────────────────────────

local function buildDesk(parent: Instance, position: Vector3, look: Vector3,
	aula: number, fila: number, asiento: number): Desk
	local face = CFrame.lookAt(position, position + look)

	local desk = block(parent, "Pupitre", Vector3.new(4.4, 0.28, 2.6),
		face * CFrame.new(0, 3, -1.4), Color3.fromRGB(214, 190, 148), Enum.Material.WoodPlanks)
	block(parent, "BordePupitre", Vector3.new(4.5, 0.35, 0.25),
		desk.CFrame * CFrame.new(0, -0.08, -1.2), Color3.fromRGB(70, 74, 84), Enum.Material.Metal).CanCollide = false
	for _, dx in { -1.8, 1.8 } do
		block(parent, "PataPupitre", Vector3.new(0.22, 3, 0.22),
			desk.CFrame * CFrame.new(dx, -1.5, -0.9), Color3.fromRGB(74, 78, 88), Enum.Material.Metal)
		block(parent, "PataPupitre", Vector3.new(0.22, 3, 0.22),
			desk.CFrame * CFrame.new(dx, -1.5, 0.9), Color3.fromRGB(74, 78, 88), Enum.Material.Metal)
	end
	-- Bandeja de abajo, donde se esconden las chuletas.
	block(parent, "Bandeja", Vector3.new(3.8, 0.15, 2),
		desk.CFrame * CFrame.new(0, -1.1, 0), Color3.fromRGB(160, 138, 104), Enum.Material.Wood).CanCollide = false

	-- La silla: un Seat de verdad, asi Occupant nos dice quien esta sentado.
	local seat = Instance.new("Seat")
	seat.Name = "Asiento"
	seat.Size = Vector3.new(2.6, 0.4, 2.6)
	seat.CFrame = face * CFrame.new(0, 2.2, 1.1)
	seat.Anchored = true
	seat.CanCollide = true
	seat.Color = Color3.fromRGB(46, 60, 84)
	seat.Material = Enum.Material.SmoothPlastic
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.Parent = parent

	block(parent, "Respaldo", Vector3.new(2.6, 2.6, 0.3),
		seat.CFrame * CFrame.new(0, 1.4, 1.15), Color3.fromRGB(46, 60, 84), Enum.Material.SmoothPlastic).CanCollide = false
	for _, dx in { -1, 1 } do
		block(parent, "PataSilla", Vector3.new(0.2, 2.2, 0.2),
			seat.CFrame * CFrame.new(dx, -1.1, -0.9), Color3.fromRGB(74, 78, 88), Enum.Material.Metal)
		block(parent, "PataSilla", Vector3.new(0.2, 2.2, 0.2),
			seat.CFrame * CFrame.new(dx, -1.1, 0.9), Color3.fromRGB(74, 78, 88), Enum.Material.Metal)
	end

	-- La hoja del examen apoyada en el pupitre. La UI la dibuja el
	-- servidor via SurfaceGui: se ve desde afuera (por eso se puede espiar).
	local paper = block(parent, "Hoja", Vector3.new(2.4, 0.05, 1.7),
		desk.CFrame * CFrame.new(0, 0.17, -0.1), Color3.fromRGB(250, 248, 242), Enum.Material.SmoothPlastic)
	paper.CanCollide = false
	paper.CastShadow = false

	seat:SetAttribute("Aula", aula)
	seat:SetAttribute("Fila", fila)
	seat:SetAttribute("Asiento", asiento)

	return { seat = seat, desk = desk, paper = paper, fila = fila, asiento = asiento, aula = aula }
end

local function buildClassroom(root: Instance, index: number): Classroom
	local model = Instance.new("Model")
	model.Name = "Aula" .. index
	model.Parent = root

	-- Impares a la izquierda del pasillo, pares a la derecha; cada par
	-- de aulas baja un tramo en Z.
	local side = (index % 2 == 1) and -1 or 1
	local row = math.floor((index - 1) / 2)
	local halfW = E.AulaAncho / 2
	local halfL = E.AulaLargo / 2
	local cx = side * (E.PasilloAncho / 2 + halfW)
	local cz = -25 - row * (E.AulaLargo + 10)
	local center = Vector3.new(cx, 0, cz)

	-- dir: de la pizarra hacia el fondo. La puerta da al pasillo.
	local dir = Vector3.new(-side, 0, 0)
	local look = -dir  -- los alumnos miran a la pizarra

	block(model, "Piso", Vector3.new(E.AulaAncho, 1, E.AulaLargo),
		CFrame.new(cx, -0.5, cz), Color3.fromRGB(178, 172, 160), Enum.Material.CeramicTiles)
	block(model, "Techo", Vector3.new(E.AulaAncho, 1, E.AulaLargo),
		CFrame.new(cx, E.AlturaPiso, cz), Color3.fromRGB(240, 240, 238), Enum.Material.Plaster)

	-- Paredes: la del pasillo lleva el hueco de la puerta.
	block(model, "ParedFondo", Vector3.new(E.EspesorPared, E.AlturaPiso, E.AulaLargo),
		CFrame.new(cx - dir.X * halfW, E.AlturaPiso / 2, cz), E.ColorParedes, Enum.Material.Concrete)
	for _, dz in { -1, 1 } do
		block(model, "ParedLateral", Vector3.new(E.AulaAncho, E.AlturaPiso, E.EspesorPared),
			CFrame.new(cx, E.AlturaPiso / 2, cz + dz * halfL), E.ColorParedes, Enum.Material.Concrete)
	end
	-- Pared del pasillo partida en dos, dejando el vano de la puerta.
	local doorWidth, doorHeight = 8, 10
	local wallX = cx + dir.X * halfW
	local sidePiece = (E.AulaLargo - doorWidth) / 2
	for _, dz in { -1, 1 } do
		block(model, "ParedPasillo", Vector3.new(E.EspesorPared, E.AlturaPiso, sidePiece),
			CFrame.new(wallX, E.AlturaPiso / 2, cz + dz * (doorWidth / 2 + sidePiece / 2)),
			E.ColorParedes, Enum.Material.Concrete)
	end
	block(model, "Dintel", Vector3.new(E.EspesorPared, E.AlturaPiso - doorHeight, doorWidth),
		CFrame.new(wallX, doorHeight + (E.AlturaPiso - doorHeight) / 2, cz),
		E.ColorParedes, Enum.Material.Concrete)

	-- La puerta: durante el examen se traba (CanCollide + opaca).
	local door = block(model, "Puerta", Vector3.new(0.4, doorHeight, doorWidth),
		CFrame.new(wallX, doorHeight / 2, cz), Color3.fromRGB(126, 92, 58), Enum.Material.WoodPlanks)
	door.CanCollide = false
	door.Transparency = 1
	door:SetAttribute("Trabada", false)

	sign(model, "AULA " .. index, Vector2.new(6, 1.8),
		CFrame.new(wallX + dir.X * 0.8, doorHeight + 1.6, cz)
			* CFrame.Angles(0, side < 0 and math.rad(90) or math.rad(-90), 0),
		Enum.NormalId.Front)

	-- Ventanas en la pared del fondo, para que entre luz.
	for i = -1, 1 do
		local glass = block(model, "Ventana", Vector3.new(0.3, 5, 8),
			CFrame.new(cx - dir.X * (halfW - 0.2), 8, cz + i * 12),
			Color3.fromRGB(190, 214, 232), Enum.Material.Glass)
		glass.Transparency = 0.55
		glass.CanCollide = false
	end

	-- Pizarra + tarima del profesor.
	local boardX = cx - dir.X * (halfW - 0.7)
	local blackboard = block(model, "Pizarra", Vector3.new(0.4, 7, 26),
		CFrame.new(boardX, 7.5, cz), E.ColorPizarra, Enum.Material.Slate)
	block(model, "MarcoPizarra", Vector3.new(0.5, 7.6, 26.6),
		CFrame.new(boardX + dir.X * 0.1, 7.5, cz),
		Color3.fromRGB(150, 116, 72), Enum.Material.Wood).CanCollide = false
	blackboard.CFrame = CFrame.new(boardX, 7.5, cz)

	local podium = block(model, "Tarima", Vector3.new(10, 1, E.AulaLargo - 8),
		CFrame.new(boardX + dir.X * 5.5, 0.5, cz),
		Color3.fromRGB(132, 96, 62), Enum.Material.WoodPlanks)

	local deskTeacher = block(model, "EscritorioProfesor", Vector3.new(3.4, 0.35, 8),
		CFrame.new(boardX + dir.X * 7, 4, cz), Color3.fromRGB(112, 82, 54), Enum.Material.Wood)
	for _, dz in { -3.4, 3.4 } do
		block(model, "PataEscritorio", Vector3.new(3, 3.4, 0.4),
			deskTeacher.CFrame * CFrame.new(0, -1.9, dz), Color3.fromRGB(96, 70, 46), Enum.Material.Wood)
	end

	-- Filas fijas de pupitres.
	local desks: { Desk } = {}
	for fila = 1, E.FilasDePupitres do
		for asiento = 1, E.PupitresPorFila do
			local offsetX = 13 + (fila - 1) * E.PupitreSeparacionX
			local offsetZ = (asiento - (E.PupitresPorFila + 1) / 2) * E.PupitreSeparacionZ
			local position = Vector3.new(boardX + dir.X * offsetX, 0, cz + offsetZ)
			safely(string.format("pupitre A%d F%d P%d", index, fila, asiento), function()
				table.insert(desks, buildDesk(model, position, look, index, fila, asiento))
			end)
		end
	end

	-- Ruta de patrullaje: sube y baja por los pasillos entre filas,
	-- mas una parada en la pizarra.
	local patrol: { Vector3 } = {}
	local lanes = E.FilasDePupitres
	for fila = 1, lanes do
		local x = boardX + dir.X * (13 + (fila - 1) * E.PupitreSeparacionX + E.PupitreSeparacionX / 2)
		local edge = (E.PupitresPorFila / 2) * E.PupitreSeparacionZ + 1
		local a = Vector3.new(x, 3, cz - edge)
		local b = Vector3.new(x, 3, cz + edge)
		if fila % 2 == 0 then
			a, b = b, a
		end
		table.insert(patrol, a)
		table.insert(patrol, b)
	end

	local spawn = Vector3.new(boardX + dir.X * 5, 4, cz)

	-- Luces del aula.
	for i = -1, 1 do
		local tube = block(model, "Tubo", Vector3.new(8, 0.3, 2),
			CFrame.new(cx, E.AlturaPiso - 0.7, cz + i * 12),
			Color3.fromRGB(255, 252, 240), Enum.Material.Neon)
		tube.CanCollide = false
		local light = Instance.new("PointLight")
		light.Brightness = 1.3
		light.Range = 34
		light.Parent = tube
	end

	model.PrimaryPart = blackboard

	return {
		index = index,
		model = model,
		center = center,
		dir = dir,
		desks = desks,
		door = door,
		blackboard = blackboard,
		podium = podium,
		patrol = patrol,
		spawn = spawn,
	}
end

-- ── sala de castigo ────────────────────────────────────────────────

local function buildDetention(root: Instance): BasePart
	local model = Instance.new("Model")
	model.Name = "Castigo"
	model.Parent = root

	local c = E.SalaDeCastigo
	local size = 24
	block(model, "Piso", Vector3.new(size, 1, size),
		CFrame.new(c.X, -0.5, c.Z), Color3.fromRGB(120, 118, 112), Enum.Material.Concrete)
	block(model, "Techo", Vector3.new(size, 1, size),
		CFrame.new(c.X, 12, c.Z), Color3.fromRGB(150, 148, 142), Enum.Material.Concrete)
	for _, offset in { Vector3.new(size / 2, 0, 0), Vector3.new(-size / 2, 0, 0) } do
		block(model, "Pared", Vector3.new(1, 12, size),
			CFrame.new(c.X + offset.X, 6, c.Z), Color3.fromRGB(138, 136, 130), Enum.Material.Concrete)
	end
	for _, offset in { size / 2, -size / 2 } do
		block(model, "Pared", Vector3.new(size, 12, 1),
			CFrame.new(c.X, 6, c.Z + offset), Color3.fromRGB(138, 136, 130), Enum.Material.Concrete)
	end

	local chair = block(model, "Banquito", Vector3.new(3, 0.4, 3),
		CFrame.new(c.X, 3, c.Z), Color3.fromRGB(96, 70, 46), Enum.Material.Wood)
	sign(model, "SALA DE CASTIGO", Vector2.new(12, 2.4),
		CFrame.new(c.X, 8, c.Z - size / 2 + 0.8), Enum.NormalId.Front)

	local bulb = block(model, "Foco", Vector3.new(1, 1, 1),
		CFrame.new(c.X, 10.6, c.Z), Color3.fromRGB(255, 240, 200), Enum.Material.Neon)
	bulb.Shape = Enum.PartType.Ball
	bulb.CanCollide = false
	local light = Instance.new("PointLight")
	light.Brightness = 1
	light.Range = 20
	light.Color = Color3.fromRGB(255, 226, 180)
	light.Parent = bulb

	return chair
end

-- ── entrada ────────────────────────────────────────────────────────

function MapBuilder.build(): Map
	local previous = workspace:FindFirstChild("Instituto")
	if previous then
		previous:Destroy()
	end

	local root = Instance.new("Model")
	root.Name = "Instituto"
	root.Parent = workspace

	-- Carpetas que el resto del juego da por hechas.
	for _, name in { "Personajes", "Objetos", "Proyectiles" } do
		if not workspace:FindFirstChild(name) then
			local folder = Instance.new("Folder")
			folder.Name = name
			folder.Parent = workspace
		end
	end

	local hall, lockers, shop, bell, spawns = buildHallway(root)

	local aulas = Instance.new("Model")
	aulas.Name = "Aulas"
	aulas.Parent = root

	local classrooms: { Classroom } = {}
	for i = 1, E.Aulas do
		safely("aula " .. i, function()
			table.insert(classrooms, buildClassroom(aulas, i))
		end)
	end

	local detention = buildDetention(root)

	-- El baseplate de emergencia del archivo del lugar ya no hace falta.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	local totalDesks = 0
	for _, room in classrooms do
		totalDesks += #room.desks
	end
	print(string.format("[Mapa] Instituto listo: %d aulas, %d pupitres, %d casilleros.",
		#classrooms, totalDesks, #lockers))

	return {
		root = root,
		hallway = hall,
		classrooms = classrooms,
		lockers = lockers,
		shop = shop,
		detention = detention,
		bell = bell,
		spawns = spawns,
	}
end

return MapBuilder

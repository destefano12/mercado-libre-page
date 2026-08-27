--!strict
--[[
	ClassroomBuilder
	------------------------------------------------------------------
	Construye el aula entera por codigo: piso, paredes, ventanas,
	luminarias, pizarron, escritorio del profe, y la grilla de bancos
	con su silla, su hoja de prueba y su lugar para el celular.

	Todo es 3D real y a escala de personaje (nada de planos ni sprites).
	Devuelve las referencias que necesitan los demas servicios:
	bancos, nodos de patrullaje, posicion del pizarron y spawn del profe.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local ClassroomBuilder = {}

export type Desk = {
	index: number,
	row: number,
	column: number,
	model: Model,
	seat: Seat,
	paper: BasePart,
	deskTop: BasePart,
	position: Vector3,
}

export type Classroom = {
	model: Model,
	desks: { Desk },
	patrolNodes: { CFrame },
	boardStand: CFrame,
	teacherSpawn: CFrame,
	studentSpawn: CFrame,
	roomCenter: Vector3,
	width: number,
	depth: number,
}

local C = Config.Classroom

-- ─────────────────────────────────────────────────────────────
-- Piezas basicas
-- ─────────────────────────────────────────────────────────────

local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): BasePart
	return Util.part({
		Name = name,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = material,
		Parent = parent,
	})
end

local function buildFloorAndCeiling(model: Model, width: number, depth: number, center: Vector3)
	local floor = block(model, "Piso", Vector3.new(width, 1, depth),
		CFrame.new(center.X, -0.5, center.Z), C.FloorColor, C.FloorMaterial)
	floor.TopSurface = Enum.SurfaceType.Smooth

	-- Zocalo de goma alrededor del piso
	block(model, "Ceiling", Vector3.new(width, 1, depth),
		CFrame.new(center.X, C.WallHeight + 0.5, center.Z), Color3.fromRGB(240, 240, 236), Enum.Material.Plaster)
end

local function buildWall(model: Model, name: string, size: Vector3, cf: CFrame)
	local wall = block(model, name, size, cf, C.WallColor, C.WallMaterial)
	wall.CastShadow = true
	return wall
end

local function buildWindowWall(model: Model, wallX: number, zStart: number, zEnd: number, height: number, thickness: number, facingSign: number)
	-- Ventanal lateral: la pared se construye por segmentos para que los
	-- huecos sean huecos de verdad (y entre luz natural al aula).
	local windowWidth = 8
	local windowHeight = 7
	local sillHeight = 5
	local count = 3
	local span = zEnd - zStart
	local step = span / (count + 1)
	local frameColor = C.TrimColor

	local centers: { number } = {}
	for i = 1, count do
		table.insert(centers, zStart + step * i)
	end

	-- Segmentos macizos entre ventanas (y en los extremos del muro)
	local edges: { number } = { zStart }
	for _, z in centers do
		table.insert(edges, z - windowWidth / 2)
		table.insert(edges, z + windowWidth / 2)
	end
	table.insert(edges, zEnd)

	for i = 1, #edges - 1, 2 do
		local a, b = edges[i], edges[i + 1]
		if b - a > 0.05 then
			buildWall(model, "ParedVentanal", Vector3.new(thickness, height, b - a),
				CFrame.new(wallX, height / 2, (a + b) / 2))
		end
	end

	for _, z in centers do
		-- Antepecho y dintel del hueco
		buildWall(model, "Antepecho", Vector3.new(thickness, sillHeight, windowWidth),
			CFrame.new(wallX, sillHeight / 2, z))
		local lintelHeight = height - (sillHeight + windowHeight)
		if lintelHeight > 0.05 then
			buildWall(model, "Dintel", Vector3.new(thickness, lintelHeight, windowWidth),
				CFrame.new(wallX, height - lintelHeight / 2, z))
		end

		local frameCF = CFrame.new(wallX, sillHeight + windowHeight / 2, z)

		local glass = block(model, "Vidrio", Vector3.new(0.35, windowHeight, windowWidth), frameCF,
			Color3.fromRGB(198, 226, 240), Enum.Material.Glass)
		glass.Transparency = 0.72
		glass.Reflectance = 0.08
		glass.CastShadow = false

		block(model, "Marco", Vector3.new(0.6, 0.5, windowWidth + 0.6), frameCF * CFrame.new(0, windowHeight / 2, 0), frameColor, Enum.Material.Metal)
		block(model, "Marco", Vector3.new(0.6, 0.5, windowWidth + 0.6), frameCF * CFrame.new(0, -windowHeight / 2, 0), frameColor, Enum.Material.Metal)
		block(model, "Marco", Vector3.new(0.6, windowHeight, 0.5), frameCF * CFrame.new(0, 0, windowWidth / 2), frameColor, Enum.Material.Metal)
		block(model, "Marco", Vector3.new(0.6, windowHeight, 0.5), frameCF * CFrame.new(0, 0, -windowWidth / 2), frameColor, Enum.Material.Metal)
		block(model, "Cruceta", Vector3.new(0.45, windowHeight, 0.3), frameCF, frameColor, Enum.Material.Metal)

		block(model, "Alfeizar", Vector3.new(1.8, 0.4, windowWidth + 1.4),
			CFrame.new(wallX - facingSign * 0.7, sillHeight - 0.15, z), Color3.fromRGB(236, 234, 228), Enum.Material.Marble)

		local light = Instance.new("SurfaceLight")
		light.Face = facingSign > 0 and Enum.NormalId.Left or Enum.NormalId.Right
		light.Brightness = 1.6
		light.Range = 32
		light.Angle = 120
		light.Color = Color3.fromRGB(255, 246, 224)
		light.Parent = glass
	end
end

local function buildBoard(model: Model, wallZ: number, width: number): CFrame
	local boardWidth = math.min(width - 12, 26)
	-- Rotado 180°: la cara Front del pizarron mira a los alumnos (+Z global).
	local boardCF = CFrame.new(0, 8, wallZ + 0.7) * CFrame.Angles(0, math.pi, 0)

	block(model, "MarcoPizarron", Vector3.new(boardWidth + 1.2, 9.2, 0.5), boardCF,
		Color3.fromRGB(96, 74, 52), Enum.Material.Wood)
	local board = block(model, "Pizarron", Vector3.new(boardWidth, 8, 0.35), boardCF * CFrame.new(0, 0, -0.2),
		Color3.fromRGB(26, 54, 42), Enum.Material.Slate)
	board.Name = "Pizarron"

	-- Bandeja de tizas
	block(model, "BandejaTizas", Vector3.new(boardWidth, 0.35, 1),
		boardCF * CFrame.new(0, -4.4, -0.5), Color3.fromRGB(120, 96, 68), Enum.Material.Wood)
	for i = -2, 2 do
		local chalk = block(model, "Tiza", Vector3.new(0.9, 0.22, 0.22),
			boardCF * CFrame.new(i * 2.2, -4.05, -0.6), Color3.fromRGB(248, 248, 240), Enum.Material.Sand)
		chalk.CanCollide = false
		chalk.Shape = Enum.PartType.Cylinder
		chalk.Orientation = Vector3.new(0, 0, 0)
	end

	-- Texto tizado: el enunciado general de la prueba
	local surface = Instance.new("SurfaceGui")
	surface.Name = "TextoPizarron"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(1000, 320)
	surface.LightInfluence = 0.35
	surface.Adornee = board
	surface.Parent = board

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.42)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.PermanentMarker
	title.Text = "EVALUACION DE MATEMATICA"
	title.TextColor3 = Color3.fromRGB(238, 240, 232)
	title.TextScaled = true
	title.Parent = surface

	local subtitle = Instance.new("TextLabel")
	subtitle.Position = UDim2.fromScale(0, 0.44)
	subtitle.Size = UDim2.fromScale(1, 0.3)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.PermanentMarker
	subtitle.Text = "Prohibido el uso de celulares"
	subtitle.TextColor3 = Color3.fromRGB(196, 214, 200)
	subtitle.TextScaled = true
	subtitle.Parent = surface

	return boardCF
end

local function buildTeacherDesk(model: Model, wallZ: number): CFrame
	local deskCF = CFrame.new(-9, 0, wallZ + 5)
	local topCF = deskCF * CFrame.new(0, 3.1, 0)

	block(model, "EscritorioProfe", Vector3.new(8, 0.35, 3.4), topCF, Color3.fromRGB(118, 88, 60), Enum.Material.Wood)
	block(model, "FrenteEscritorio", Vector3.new(8, 2.6, 0.3), deskCF * CFrame.new(0, 1.6, -1.5),
		Color3.fromRGB(104, 78, 54), Enum.Material.Wood)
	for _, offset in { Vector3.new(-3.6, 0, 0), Vector3.new(3.6, 0, 0) } do
		block(model, "PataEscritorio", Vector3.new(0.4, 3, 3.2), deskCF * CFrame.new(offset.X, 1.5, 0),
			Color3.fromRGB(88, 66, 46), Enum.Material.Wood)
	end

	-- Pila de pruebas corregidas + mate del profe
	for i = 1, 4 do
		local sheet = block(model, "Pruebas", Vector3.new(2.4, 0.06, 1.8),
			topCF * CFrame.new(2.2 + math.random() * 0.1, 0.2 + i * 0.07, math.random() * 0.1),
			Color3.fromRGB(250, 248, 240), Enum.Material.SmoothPlastic)
		sheet.CanCollide = false
	end
	local mate = block(model, "Mate", Vector3.new(1, 1.1, 1), topCF * CFrame.new(-2.6, 0.75, 0),
		Color3.fromRGB(86, 62, 42), Enum.Material.Wood)
	mate.Shape = Enum.PartType.Cylinder
	mate.Orientation = Vector3.new(0, 0, 90)
	mate.CanCollide = false

	return deskCF
end

local function buildLighting(model: Model, width: number, depth: number, center: Vector3)
	local rows, cols = 3, 2
	for r = 1, rows do
		for c = 1, cols do
			local x = center.X + (c - (cols + 1) / 2) * (width / cols) * 0.7
			local z = center.Z + (r - (rows + 1) / 2) * (depth / rows) * 0.72
			local fixture = block(model, "Luminaria", Vector3.new(6, 0.4, 1.4),
				CFrame.new(x, C.WallHeight - 0.6, z), Color3.fromRGB(238, 240, 245), Enum.Material.Metal)
			fixture.CanCollide = false

			local tube = block(model, "Tubo", Vector3.new(5.6, 0.25, 1),
				CFrame.new(x, C.WallHeight - 0.9, z), Color3.fromRGB(255, 252, 240), Enum.Material.Neon)
			tube.CanCollide = false
			tube.CastShadow = false

			local light = Instance.new("SurfaceLight")
			light.Face = Enum.NormalId.Bottom
			light.Brightness = 3
			light.Range = 34
			light.Angle = 150
			light.Color = Color3.fromRGB(255, 250, 235)
			light.Parent = tube
		end
	end
end

local function buildDoor(model: Model, wallZ: number, width: number): CFrame
	local doorCF = CFrame.new(width / 2 - 6, 0, wallZ - 0.4)
	block(model, "MarcoPuerta", Vector3.new(6.4, 10.4, 0.6), doorCF * CFrame.new(0, 5.2, 0),
		C.TrimColor, Enum.Material.Wood)
	local door = block(model, "Puerta", Vector3.new(5.6, 9.6, 0.3), doorCF * CFrame.new(0, 4.8, -0.2),
		Color3.fromRGB(142, 104, 68), Enum.Material.Wood)
	local knob = block(model, "Picaporte", Vector3.new(0.5, 0.5, 0.5), doorCF * CFrame.new(2.2, 4.6, -0.5),
		Color3.fromRGB(205, 178, 96), Enum.Material.Metal)
	knob.Shape = Enum.PartType.Ball
	knob.CanCollide = false
	door.CanCollide = true
	return doorCF
end

-- ─────────────────────────────────────────────────────────────
-- Banco del alumno
-- ─────────────────────────────────────────────────────────────

local function buildDesk(parent: Instance, index: number, row: number, column: number, position: Vector3): Desk
	local model = Instance.new("Model")
	model.Name = string.format("Banco_%02d", index)
	model.Parent = parent

	local base = CFrame.new(position)
	local topHeight = 3.0

	local deskTop = block(model, "Tabla", Vector3.new(4.6, 0.28, 2.8), base * CFrame.new(0, topHeight, 0),
		Color3.fromRGB(196, 158, 108), Enum.Material.WoodPlanks)
	block(model, "BordeTabla", Vector3.new(4.7, 0.12, 2.9), base * CFrame.new(0, topHeight - 0.2, 0),
		Color3.fromRGB(70, 74, 82), Enum.Material.Metal)

	for _, offset in { Vector3.new(-2, 0, -1.1), Vector3.new(2, 0, -1.1), Vector3.new(-2, 0, 1.1), Vector3.new(2, 0, 1.1) } do
		local leg = block(model, "Pata", Vector3.new(0.22, topHeight, 0.22),
			base * CFrame.new(offset.X, topHeight / 2, offset.Z), Color3.fromRGB(74, 78, 86), Enum.Material.Metal)
		leg.CanCollide = false
	end
	-- Estante bajo la tabla (mochilas, y el celu escondido)
	local shelf = block(model, "Estante", Vector3.new(4, 0.15, 2), base * CFrame.new(0, 1.2, 0.1),
		Color3.fromRGB(150, 120, 84), Enum.Material.Wood)
	shelf.CanCollide = false

	-- Silla + Seat (el Seat es lo que engancha al jugador a su banco)
	local chairBase = base * CFrame.new(0, 0, 2.6)
	local seat = Instance.new("Seat")
	seat.Name = "Asiento"
	seat.Size = Vector3.new(2.6, 0.35, 2.4)
	seat.CFrame = chairBase * CFrame.new(0, 2.1, 0)
	seat.Anchored = true
	seat.Color = Color3.fromRGB(58, 96, 156)
	seat.Material = Enum.Material.Fabric
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.Parent = model

	block(model, "Respaldo", Vector3.new(2.6, 2.4, 0.28), chairBase * CFrame.new(0, 3.3, 1.1),
		Color3.fromRGB(58, 96, 156), Enum.Material.Fabric)
	for _, offset in { Vector3.new(-1.1, 0, -1), Vector3.new(1.1, 0, -1), Vector3.new(-1.1, 0, 1), Vector3.new(1.1, 0, 1) } do
		local leg = block(model, "PataSilla", Vector3.new(0.18, 2.1, 0.18),
			chairBase * CFrame.new(offset.X, 1.05, offset.Z), Color3.fromRGB(74, 78, 86), Enum.Material.Metal)
		leg.CanCollide = false
	end

	-- La hoja de la prueba: parte fisica sobre la tabla, con la UI
	-- montada en su cara superior (la arma el cliente sobre este Adornee).
	local paper = Util.part({
		Name = "HojaDePrueba",
		Size = Vector3.new(3.2, 0.05, 2.3),
		CFrame = base * CFrame.new(0, topHeight + 0.17, 0.1) * CFrame.Angles(0, math.rad(-2), 0),
		Color = Color3.fromRGB(250, 249, 244),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = model,
	})

	-- Lapicera al costado, puro detalle
	local pen = Util.part({
		Name = "Lapicera",
		Size = Vector3.new(0.16, 0.16, 1.4),
		CFrame = base * CFrame.new(1.75, topHeight + 0.22, -0.4) * CFrame.Angles(0, math.rad(18), math.rad(90)),
		Color = Color3.fromRGB(32, 46, 120),
		Material = Enum.Material.Plastic,
		CanCollide = false,
		Parent = model,
	})
	pen.Shape = Enum.PartType.Cylinder

	model.PrimaryPart = deskTop

	return {
		index = index,
		row = row,
		column = column,
		model = model,
		seat = seat,
		paper = paper,
		deskTop = deskTop,
		position = position,
	}
end

-- ─────────────────────────────────────────────────────────────
-- Build
-- ─────────────────────────────────────────────────────────────

function ClassroomBuilder.build(parent: Instance): Classroom
	local existing = parent:FindFirstChild("Aula")
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "Aula"

	local lastRowZ = C.FirstRowOffsetZ + (C.Rows - 1) * C.DeskSpacingZ
	local halfWidth = (C.Columns - 1) / 2 * C.DeskSpacingX + C.Padding
	local frontZ = -3
	local backZ = lastRowZ + C.Padding
	local width = halfWidth * 2
	local depth = backZ - frontZ
	local center = Vector3.new(0, 0, (frontZ + backZ) / 2)

	buildFloorAndCeiling(model, width, depth, center)

	local h = C.WallHeight
	local t = C.WallThickness
	buildWall(model, "ParedFrente", Vector3.new(width, h, t), CFrame.new(0, h / 2, frontZ))
	buildWall(model, "ParedFondo", Vector3.new(width, h, t), CFrame.new(0, h / 2, backZ))
	buildWall(model, "ParedIzq", Vector3.new(t, h, depth), CFrame.new(-halfWidth, h / 2, center.Z))
	buildWindowWall(model, halfWidth, frontZ, backZ, h, t, 1)

	-- Zocalos
	for _, spec in {
		{ Vector3.new(width, 1.2, t + 0.3), CFrame.new(0, 0.6, frontZ) },
		{ Vector3.new(width, 1.2, t + 0.3), CFrame.new(0, 0.6, backZ) },
		{ Vector3.new(t + 0.3, 1.2, depth), CFrame.new(-halfWidth, 0.6, center.Z) },
		{ Vector3.new(t + 0.3, 1.2, depth), CFrame.new(halfWidth, 0.6, center.Z) },
	} do
		block(model, "Zocalo", spec[1] :: Vector3, spec[2] :: CFrame, C.TrimColor, Enum.Material.Wood)
	end

	local boardCF = buildBoard(model, frontZ, width)
	buildTeacherDesk(model, frontZ)
	buildLighting(model, width, depth, center)
	buildDoor(model, backZ, width)

	-- Grilla de bancos
	local desksFolder = Instance.new("Folder")
	desksFolder.Name = "Bancos"
	desksFolder.Parent = model

	local desks: { Desk } = {}
	local index = 0
	for row = 1, C.Rows do
		for column = 1, C.Columns do
			index += 1
			local x = (column - (C.Columns + 1) / 2) * C.DeskSpacingX
			local z = C.FirstRowOffsetZ + (row - 1) * C.DeskSpacingZ
			desks[index] = buildDesk(desksFolder, index, row, column, Vector3.new(x, 0, z))
		end
	end

	-- Nodos de patrullaje: el profe recorre pasillo por pasillo.
	-- Pasillos entre columnas + los dos laterales.
	local aisleX: { number } = {}
	for column = 1, C.Columns - 1 do
		table.insert(aisleX, (column - (C.Columns + 1) / 2 + 0.5) * C.DeskSpacingX)
	end
	table.insert(aisleX, -halfWidth + 4.5)
	table.insert(aisleX, halfWidth - 4.5)
	table.sort(aisleX)

	local patrolNodes: { CFrame } = {}
	local frontLane = C.FirstRowOffsetZ - 6
	local backLane = lastRowZ + 5
	for i, x in aisleX do
		local goingBack = i % 2 == 1
		local startZ = goingBack and frontLane or backLane
		local endZ = goingBack and backLane or frontLane
		local steps = C.Rows + 1
		for s = 0, steps do
			local alpha = s / steps
			local z = startZ + (endZ - startZ) * alpha
			-- Mira hacia donde camina: +Z (hacia el fondo) o -Z (hacia el pizarron).
			local facing = goingBack and math.pi or 0
			table.insert(patrolNodes, CFrame.new(x, 0, z) * CFrame.Angles(0, facing, 0))
		end
	end

	model.Parent = parent

	return {
		model = model,
		desks = desks,
		patrolNodes = patrolNodes,
		boardStand = CFrame.new(boardCF.Position.X, 0, boardCF.Position.Z + 4),
		teacherSpawn = CFrame.new(-9, 3, frontZ + 9) * CFrame.Angles(0, math.pi, 0),
		studentSpawn = CFrame.new(0, 3, backZ - 6),
		roomCenter = center,
		width = width,
		depth = depth,
	}
end

return ClassroomBuilder

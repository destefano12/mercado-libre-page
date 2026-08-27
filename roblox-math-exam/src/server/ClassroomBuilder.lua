--!strict
--[[
	ClassroomBuilder
	------------------------------------------------------------------
	Un aula de secundaria estadounidense, construida por codigo y con
	criterio minimalista: pocos materiales, paleta corta, nada de
	adornos que no estarian de verdad en un aula.

	Lo que la hace leerse como aula de Estados Unidos:
		· pupitres combo (silla y tabla en un mismo caño cromado)
		· cesto de alambre abajo de la tabla
		· pizarron verde con marco de madera y bandeja de tizas
		· cielorraso de placas con luminarias empotradas
		· piso de linoleo claro y paredes de bloque pintado
		· puerta con ventanita vertical y reloj de pared

	Devuelve las referencias que usan los demas servicios: bancos,
	nodos de patrullaje, posicion del pizarron y spawns.
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

-- Paleta corta: cinco colores y se terminó.
local CHROME = Color3.fromRGB(188, 192, 200)
local LAMINATE = Color3.fromRGB(212, 190, 156)
local SEAT = Color3.fromRGB(196, 186, 170)
local DARK = Color3.fromRGB(62, 66, 74)
local WHITE = Color3.fromRGB(246, 245, 241)

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

--- Caño cromado. El eje del cilindro es X, asi que la rotacion viene
--- puesta en el CFrame y no se pisa despues con Orientation.
local function tube(parent: Instance, name: string, length: number, diameter: number, cf: CFrame, color: Color3?): BasePart
	local part = block(parent, name, Vector3.new(length, diameter, diameter), cf, color or CHROME, Enum.Material.Metal)
	part.Shape = Enum.PartType.Cylinder
	part.Reflectance = 0.12
	part.CanCollide = false
	part.CastShadow = false
	return part
end

local VERTICAL = CFrame.Angles(0, 0, math.rad(90))   -- eje X -> Y
local ALONG_Z = CFrame.Angles(0, math.rad(90), 0)    -- eje X -> Z

-- ─────────────────────────────────────────────────────────────
-- Envolvente: piso, cielorraso de placas, paredes
-- ─────────────────────────────────────────────────────────────

local function buildShell(model: Model, width: number, depth: number, center: Vector3, frontZ: number, backZ: number, halfWidth: number)
	local h = C.WallHeight
	local t = C.WallThickness

	-- Piso de linoleo
	local floor = block(model, "Piso", Vector3.new(width, 1, depth),
		CFrame.new(center.X, -0.5, center.Z), C.FloorColor, Enum.Material.Pebble)
	floor.TopSurface = Enum.SurfaceType.Smooth

	-- Cielorraso de placas: grilla clara con perfiles finos
	local tile = 6
	local cols = math.ceil(width / tile)
	local rows = math.ceil(depth / tile)
	for row = 1, rows do
		for col = 1, cols do
			local x = center.X - width / 2 + (col - 0.5) * tile
			local z = center.Z - depth / 2 + (row - 0.5) * tile
			local plate = block(model, "Placa", Vector3.new(tile - 0.12, 0.3, tile - 0.12),
				CFrame.new(x, h + 0.15, z), Color3.fromRGB(238, 237, 231), Enum.Material.Concrete)
			plate.CastShadow = false
		end
	end
	block(model, "Losa", Vector3.new(width, 0.6, depth),
		CFrame.new(center.X, h + 0.6, center.Z), DARK, Enum.Material.Concrete)

	-- Paredes de bloque pintado + zocalo
	local function wall(name: string, size: Vector3, cf: CFrame)
		return block(model, name, size, cf, C.WallColor, C.WallMaterial)
	end
	wall("ParedFrente", Vector3.new(width, h, t), CFrame.new(0, h / 2, frontZ))
	wall("ParedFondo", Vector3.new(width, h, t), CFrame.new(0, h / 2, backZ))
	wall("ParedIzq", Vector3.new(t, h, depth), CFrame.new(-halfWidth, h / 2, center.Z))

	for _, spec in {
		{ Vector3.new(width, 0.9, t + 0.25), CFrame.new(0, 0.45, frontZ) },
		{ Vector3.new(width, 0.9, t + 0.25), CFrame.new(0, 0.45, backZ) },
		{ Vector3.new(t + 0.25, 0.9, depth), CFrame.new(-halfWidth, 0.45, center.Z) },
		{ Vector3.new(t + 0.25, 0.9, depth), CFrame.new(halfWidth, 0.45, center.Z) },
	} do
		block(model, "Zocalo", spec[1] :: Vector3, spec[2] :: CFrame, C.TrimColor, Enum.Material.SmoothPlastic)
	end

	return wall
end

--- Pared del ventanal: se arma por segmentos para que los huecos sean
--- huecos de verdad y entre luz.
local function buildWindowWall(model: Model, wallX: number, zStart: number, zEnd: number, height: number, thickness: number)
	local windowWidth = 9
	local windowHeight = 7
	local sillHeight = 4.5
	local count = 3
	local step = (zEnd - zStart) / (count + 1)

	local centers = {}
	for i = 1, count do
		table.insert(centers, zStart + step * i)
	end

	local edges = { zStart }
	for _, z in centers do
		table.insert(edges, z - windowWidth / 2)
		table.insert(edges, z + windowWidth / 2)
	end
	table.insert(edges, zEnd)

	for i = 1, #edges - 1, 2 do
		local a, b = edges[i], edges[i + 1]
		if b - a > 0.05 then
			block(model, "ParedVentanal", Vector3.new(thickness, height, b - a),
				CFrame.new(wallX, height / 2, (a + b) / 2), C.WallColor, C.WallMaterial)
		end
	end

	for _, z in centers do
		block(model, "Antepecho", Vector3.new(thickness, sillHeight, windowWidth),
			CFrame.new(wallX, sillHeight / 2, z), C.WallColor, C.WallMaterial)
		local lintel = height - (sillHeight + windowHeight)
		if lintel > 0.05 then
			block(model, "Dintel", Vector3.new(thickness, lintel, windowWidth),
				CFrame.new(wallX, height - lintel / 2, z), C.WallColor, C.WallMaterial)
		end

		local frameCF = CFrame.new(wallX, sillHeight + windowHeight / 2, z)
		local glass = block(model, "Vidrio", Vector3.new(0.3, windowHeight, windowWidth), frameCF,
			Color3.fromRGB(206, 226, 236), Enum.Material.Glass)
		glass.Transparency = 0.78
		glass.Reflectance = 0.06
		glass.CastShadow = false

		-- Carpinteria de aluminio, dos hojas
		for _, piece in {
			{ Vector3.new(0.5, 0.35, windowWidth), CFrame.new(0, windowHeight / 2, 0) },
			{ Vector3.new(0.5, 0.35, windowWidth), CFrame.new(0, -windowHeight / 2, 0) },
			{ Vector3.new(0.5, windowHeight, 0.35), CFrame.new(0, 0, windowWidth / 2) },
			{ Vector3.new(0.5, windowHeight, 0.35), CFrame.new(0, 0, -windowWidth / 2) },
			{ Vector3.new(0.5, windowHeight, 0.25), CFrame.new(0, 0, 0) },
		} do
			block(model, "Carpinteria", piece[1] :: Vector3, frameCF * (piece[2] :: CFrame),
				Color3.fromRGB(168, 172, 178), Enum.Material.Metal)
		end

		block(model, "Alfeizar", Vector3.new(1.5, 0.3, windowWidth + 1),
			CFrame.new(wallX - 0.6, sillHeight - 0.1, z), WHITE, Enum.Material.SmoothPlastic)

		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Left
		light.Brightness = 1.5
		light.Range = 30
		light.Angle = 130
		light.Color = Color3.fromRGB(255, 248, 232)
		light.Parent = glass
	end
end

-- ─────────────────────────────────────────────────────────────
-- Frente del aula
-- ─────────────────────────────────────────────────────────────

local function buildBoard(model: Model, wallZ: number, width: number): CFrame
	local boardWidth = math.min(width - 14, 26)
	local boardCF = CFrame.new(0, 8, wallZ + 0.7) * CFrame.Angles(0, math.pi, 0)

	block(model, "MarcoPizarron", Vector3.new(boardWidth + 0.9, 8.9, 0.45), boardCF,
		Color3.fromRGB(122, 96, 68), Enum.Material.Wood)
	local board = block(model, "Pizarron", Vector3.new(boardWidth, 8, 0.3), boardCF * CFrame.new(0, 0, -0.2),
		C.BoardColor, Enum.Material.Slate)

	block(model, "BandejaTizas", Vector3.new(boardWidth, 0.3, 0.9),
		boardCF * CFrame.new(0, -4.5, -0.55), Color3.fromRGB(142, 112, 80), Enum.Material.Wood)
	for i = -1, 1 do
		local chalk = block(model, "Tiza", Vector3.new(0.85, 0.2, 0.2),
			boardCF * CFrame.new(i * 3.2, -4.2, -0.65), WHITE, Enum.Material.Sand)
		chalk.CanCollide = false
		chalk.CastShadow = false
	end
	local eraser = block(model, "Borrador", Vector3.new(1.6, 0.5, 0.7),
		boardCF * CFrame.new(boardWidth / 2 - 2, -4.15, -0.65), DARK, Enum.Material.Fabric)
	eraser.CanCollide = false

	-- Lo escrito en el pizarron es escenografia: queda en ingles.
	local surface = Instance.new("SurfaceGui")
	surface.Name = "TextoPizarron"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(1200, 380)
	surface.LightInfluence = 0.4
	surface.Adornee = board
	surface.Parent = board

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.4)
	title.Position = UDim2.fromScale(0, 0.1)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.PermanentMarker
	title.Text = "MATH  ·  PERIOD 3"
	title.TextColor3 = Color3.fromRGB(236, 238, 232)
	title.TextScaled = true
	title.Parent = surface

	local subtitle = Instance.new("TextLabel")
	subtitle.Position = UDim2.fromScale(0, 0.52)
	subtitle.Size = UDim2.fromScale(1, 0.26)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.PermanentMarker
	subtitle.Text = "Phones off. Show your work."
	subtitle.TextColor3 = Color3.fromRGB(190, 208, 194)
	subtitle.TextScaled = true
	subtitle.Parent = surface

	return boardCF
end

local function buildTeacherDesk(model: Model, wallZ: number): CFrame
	local deskCF = CFrame.new(-11, 0, wallZ + 5.5)
	local topCF = deskCF * CFrame.new(0, 2.9, 0)

	block(model, "EscritorioProfe", Vector3.new(8.5, 0.3, 3.6), topCF, LAMINATE, Enum.Material.Wood)
	block(model, "CuerpoEscritorio", Vector3.new(8.2, 2.6, 3.3), deskCF * CFrame.new(0, 1.45, 0), DARK, Enum.Material.Metal)
	for _, x in { -3.4, 3.4 } do
		block(model, "Cajonera", Vector3.new(0.12, 2, 3), deskCF * CFrame.new(x, 1.6, 0),
			Color3.fromRGB(150, 154, 162), Enum.Material.Metal)
	end

	local stack = block(model, "Pruebas", Vector3.new(2.6, 0.4, 2), topCF * CFrame.new(2.4, 0.35, 0), WHITE, Enum.Material.SmoothPlastic)
	stack.CanCollide = false
	local mug = block(model, "Taza", Vector3.new(0.9, 1, 0.9), topCF * CFrame.new(-2.8, 0.65, 0.4), Color3.fromRGB(158, 62, 58), Enum.Material.SmoothPlastic)
	mug.Shape = Enum.PartType.Cylinder
	mug.CFrame = topCF * CFrame.new(-2.8, 0.65, 0.4) * VERTICAL
	mug.CanCollide = false

	return deskCF
end

local function buildDoor(model: Model, wallZ: number, width: number)
	local doorCF = CFrame.new(width / 2 - 7, 0, wallZ - 0.45)
	block(model, "MarcoPuerta", Vector3.new(6, 10.2, 0.5), doorCF * CFrame.new(0, 5.1, 0), C.TrimColor, Enum.Material.Metal)
	block(model, "Puerta", Vector3.new(5.2, 9.4, 0.28), doorCF * CFrame.new(0, 4.7, -0.2),
		Color3.fromRGB(158, 124, 86), Enum.Material.Wood)
	-- Ventanita vertical, muy de escuela americana
	local pane = block(model, "VentanaPuerta", Vector3.new(0.9, 4.4, 0.34), doorCF * CFrame.new(-1.4, 5.8, -0.2),
		Color3.fromRGB(206, 226, 236), Enum.Material.Glass)
	pane.Transparency = 0.72
	pane.CastShadow = false
	local handle = block(model, "Picaporte", Vector3.new(0.9, 0.22, 0.22), doorCF * CFrame.new(1.9, 4.6, -0.42), CHROME, Enum.Material.Metal)
	handle.Shape = Enum.PartType.Cylinder
	handle.CFrame = doorCF * CFrame.new(1.9, 4.6, -0.42) * ALONG_Z
	handle.CanCollide = false
end

local function buildCeilingLights(model: Model, width: number, depth: number, center: Vector3)
	local rows, cols = 3, 2
	for r = 1, rows do
		for c = 1, cols do
			local x = center.X + (c - (cols + 1) / 2) * (width / cols) * 0.62
			local z = center.Z + (r - (rows + 1) / 2) * (depth / rows) * 0.74
			local troffer = block(model, "Luminaria", Vector3.new(5.8, 0.28, 2.4),
				CFrame.new(x, C.WallHeight - 0.18, z), Color3.fromRGB(226, 228, 232), Enum.Material.Metal)
			troffer.CanCollide = false
			troffer.CastShadow = false

			local diffuser = block(model, "Difusor", Vector3.new(5.4, 0.16, 2), CFrame.new(x, C.WallHeight - 0.36, z),
				Color3.fromRGB(255, 253, 246), Enum.Material.Neon)
			diffuser.CanCollide = false
			diffuser.CastShadow = false

			local light = Instance.new("SurfaceLight")
			light.Face = Enum.NormalId.Bottom
			light.Brightness = 2.6
			light.Range = 34
			light.Angle = 160
			light.Color = Color3.fromRGB(255, 251, 238)
			light.Parent = diffuser
		end
	end
end

-- ─────────────────────────────────────────────────────────────
-- Laminas y reloj (lo justo, sin saturar la pared)
-- ─────────────────────────────────────────────────────────────

local POSTERS = {
	{ title = "ORDER OF OPERATIONS", accent = Color3.fromRGB(46, 92, 158),
	  lines = { "P E M D A S", "Parentheses · Exponents", "Multiply · Divide", "Add · Subtract" } },
	{ title = "THE QUADRATIC FORMULA", accent = Color3.fromRGB(52, 116, 96),
	  lines = { "x = (-b ± √(b² - 4ac)) / 2a", "Δ = b² - 4ac", "Δ > 0  two roots", "Δ = 0  one   ·   Δ < 0  none" } },
	{ title = "PYTHAGOREAN THEOREM", accent = Color3.fromRGB(158, 88, 44),
	  lines = { "a² + b² = c²", "c is the hypotenuse", "3 · 4 · 5      5 · 12 · 13", "8 · 15 · 17    7 · 24 · 25" } },
}

local function buildPoster(model: Model, cf: CFrame, spec: any)
	local width, height = 7, 5
	local sheet = block(model, "Lamina", Vector3.new(width, height, 0.08), cf, WHITE, Enum.Material.SmoothPlastic)
	sheet.CastShadow = false

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 90
	gui.LightInfluence = 0.55
	gui.MaxDistance = 70
	gui.Adornee = sheet
	gui.Parent = sheet

	local pad = Instance.new("Frame")
	pad.Size = UDim2.fromScale(1, 1)
	pad.BackgroundColor3 = WHITE
	pad.BorderSizePixel = 0
	pad.Parent = gui

	local rule = Instance.new("Frame")
	rule.Size = UDim2.new(0, 60, 0, 5)
	rule.Position = UDim2.fromOffset(34, 52)
	rule.BackgroundColor3 = spec.accent
	rule.BorderSizePixel = 0
	rule.Parent = pad

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -68, 0, 30)
	title.Position = UDim2.fromOffset(34, 16)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = spec.title
	title.TextColor3 = Color3.fromRGB(38, 42, 52)
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = pad

	local body = Instance.new("Frame")
	body.Size = UDim2.new(1, -68, 1, -110)
	body.Position = UDim2.fromOffset(34, 82)
	body.BackgroundTransparency = 1
	body.Parent = pad

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 14)
	layout.Parent = body

	for index, text in spec.lines do
		local line = Instance.new("TextLabel")
		line.LayoutOrder = index
		line.Size = UDim2.new(1, 0, 0, 32)
		line.BackgroundTransparency = 1
		line.Font = index == 1 and Enum.Font.GothamBold or Enum.Font.Gotham
		line.Text = text
		line.TextColor3 = index == 1 and spec.accent or Color3.fromRGB(84, 90, 102)
		line.TextScaled = true
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.Parent = body
	end
end

local function buildClock(model: Model, cf: CFrame)
	block(model, "AroReloj", Vector3.new(3.4, 3.4, 0.35), cf, DARK, Enum.Material.Metal)
	local dial = block(model, "Esfera", Vector3.new(3, 3, 0.1), cf * CFrame.new(0, 0, -0.2), WHITE, Enum.Material.SmoothPlastic)
	dial.CastShadow = false

	-- Angulo positivo sobre Z local = sentido horario visto desde el aula.
	for hour = 1, 12 do
		local angle = math.rad(hour * 30)
		local marker = block(model, "Marca", Vector3.new(0.1, hour % 3 == 0 and 0.4 or 0.22, 0.05),
			cf * CFrame.Angles(0, 0, angle) * CFrame.new(0, 1.2, -0.27), DARK, Enum.Material.SmoothPlastic)
		marker.CastShadow = false
	end

	local hourHand = block(model, "AgujaHora", Vector3.new(0.12, 0.85, 0.04), cf * CFrame.new(0, 0, -0.3), DARK, Enum.Material.SmoothPlastic)
	local minuteHand = block(model, "AgujaMinuto", Vector3.new(0.09, 1.2, 0.04), cf * CFrame.new(0, 0, -0.34), DARK, Enum.Material.SmoothPlastic)
	hourHand.CastShadow = false
	minuteHand.CastShadow = false

	task.spawn(function()
		while hourHand.Parent do
			local now = os.date("*t")
			minuteHand.CFrame = cf * CFrame.Angles(0, 0, math.rad(now.min * 6)) * CFrame.new(0, 0.6, -0.34)
			hourHand.CFrame = cf * CFrame.Angles(0, 0, math.rad((now.hour % 12) * 30 + now.min * 0.5)) * CFrame.new(0, 0.42, -0.3)
			task.wait(5)
		end
	end)
end

-- ─────────────────────────────────────────────────────────────
-- Pupitre combo estilo americano
-- ─────────────────────────────────────────────────────────────

local function buildDesk(parent: Instance, index: number, row: number, column: number, position: Vector3): Desk
	local model = Instance.new("Model")
	model.Name = string.format("Banco_%02d", index)
	model.Parent = parent

	local base = CFrame.new(position)
	local topY = 3.0     -- altura de la tabla
	local seatY = 1.95   -- altura del asiento
	local seatZ = 2.25   -- el asiento va detras de la tabla

	-- Tabla con canto oscuro
	local deskTop = block(model, "Tabla", Vector3.new(4.4, 0.16, 2.5), base * CFrame.new(0, topY, 0), LAMINATE, Enum.Material.Wood)
	block(model, "Canto", Vector3.new(4.5, 0.1, 2.6), base * CFrame.new(0, topY - 0.11, 0), DARK, Enum.Material.SmoothPlastic)

	-- Estructura de caño: dos patas adelante, dos atras y los largueros
	for _, x in { -1.75, 1.75 } do
		tube(model, "PataFrente", topY, 0.22, base * CFrame.new(x, topY / 2, -0.95) * VERTICAL)
		tube(model, "PataAtras", seatY, 0.22, base * CFrame.new(x * 0.62, seatY / 2, seatZ + 0.85) * VERTICAL)
		tube(model, "Larguero", seatZ + 1.9, 0.2, base * CFrame.new(x * 0.8, 0.22, seatZ * 0.5 - 0.2) * ALONG_Z)
		tube(model, "Columna", topY - seatY + 0.6, 0.22, base * CFrame.new(x * 0.72, seatY + 0.3, seatZ - 0.9) * VERTICAL)
	end
	tube(model, "TravesanoFrente", 3.5, 0.2, base * CFrame.new(0, 0.22, -0.95))

	-- Asiento y respaldo de plastico moldeado
	block(model, "Asiento", Vector3.new(2.6, 0.26, 2.2), base * CFrame.new(0, seatY, seatZ), SEAT, Enum.Material.Plastic)
	block(model, "BordeAsiento", Vector3.new(2.7, 0.14, 2.3), base * CFrame.new(0, seatY - 0.14, seatZ), SEAT, Enum.Material.Plastic)
	block(model, "Respaldo", Vector3.new(2.6, 1.5, 0.24),
		base * CFrame.new(0, seatY + 1.25, seatZ + 1.2) * CFrame.Angles(math.rad(9), 0, 0), SEAT, Enum.Material.Plastic)

	-- Cesto de alambre abajo de la tabla
	local basketY = 1.55
	block(model, "CestoBase", Vector3.new(3.4, 0.1, 1.9), base * CFrame.new(0, basketY, 0), DARK, Enum.Material.DiamondPlate).CanCollide = false
	for _, spec in {
		{ Vector3.new(3.4, 0.7, 0.08), CFrame.new(0, basketY + 0.35, -0.9) },
		{ Vector3.new(3.4, 0.7, 0.08), CFrame.new(0, basketY + 0.35, 0.9) },
		{ Vector3.new(0.08, 0.7, 1.9), CFrame.new(-1.7, basketY + 0.35, 0) },
		{ Vector3.new(0.08, 0.7, 1.9), CFrame.new(1.7, basketY + 0.35, 0) },
	} do
		local side = block(model, "CestoLado", spec[1] :: Vector3, base * (spec[2] :: CFrame), DARK, Enum.Material.DiamondPlate)
		side.CanCollide = false
		side.CastShadow = false
	end

	-- Mochila apoyada al costado
	local backpack = block(model, "Mochila", Vector3.new(1.7, 1.8, 1),
		base * CFrame.new(-2.5, 0.9, 1.4) * CFrame.Angles(0, math.rad(14), 0),
		({ Color3.fromRGB(52, 66, 96), Color3.fromRGB(102, 54, 58), Color3.fromRGB(58, 74, 68), DARK })[(index - 1) % 4 + 1],
		Enum.Material.Fabric)
	backpack.CanCollide = false

	-- El Seat es lo que engancha al jugador a su banco
	local seat = Instance.new("Seat")
	seat.Name = "Asiento"
	seat.Size = Vector3.new(2.4, 0.3, 2)
	seat.CFrame = base * CFrame.new(0, seatY + 0.2, seatZ)
	seat.Anchored = true
	seat.Transparency = 1
	seat.CanCollide = false
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.Parent = model

	-- La hoja de la prueba, apoyada donde la tendrias vos
	-- Vertical, como una hoja de prueba de verdad (no apaisada).
	local paper = Util.part({
		Name = "HojaDePrueba",
		Size = Vector3.new(2.3, 0.04, 3.1),
		CFrame = base * CFrame.new(0, topY + 0.11, 0.25) * CFrame.Angles(0, math.rad(-2), 0),
		Color = WHITE,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = model,
	})

	local pencil = block(model, "Lapiz", Vector3.new(0.12, 0.12, 1.2),
		base * CFrame.new(1.65, topY + 0.14, -0.55) * CFrame.Angles(0, math.rad(16), 0),
		Color3.fromRGB(226, 178, 60), Enum.Material.SmoothPlastic)
	pencil.CanCollide = false

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

	-- Todo se construye aislado. Ya paso dos veces que un detalle
	-- cosmetico (un material que no existe, una propiedad de solo
	-- lectura) tirara abajo el aula entera y dejara al jugador flotando
	-- en el vacio sin ninguna pista. No vuelve a pasar: si una pieza
	-- falla, avisa por el Output y el resto se construye igual.
	local function decorate(name: string, build: () -> ())
		local ok, err = pcall(build)
		if not ok then
			warn(string.format("[Aula] No se pudo construir %s: %s", name, tostring(err)))
		end
		return ok
	end

	local shellOk = decorate("la envolvente", function()
		buildShell(model, width, depth, center, frontZ, backZ, halfWidth)
		buildWindowWall(model, halfWidth, frontZ, backZ, C.WallHeight, C.WallThickness)
	end)

	if not shellOk then
		-- Piso de emergencia: sin esto no hay donde pararse.
		block(model, "PisoEmergencia", Vector3.new(width, 1, depth),
			CFrame.new(center.X, -0.5, center.Z), C.FloorColor, Enum.Material.SmoothPlastic)
	end

	local boardCF = CFrame.new(0, 8, frontZ + 0.7) * CFrame.Angles(0, math.pi, 0)
	decorate("el pizarron", function()
		boardCF = buildBoard(model, frontZ, width)
	end)

	decorate("el escritorio del profesor", function()
		buildTeacherDesk(model, frontZ)
	end)
	decorate("las luminarias", function()
		buildCeilingLights(model, width, depth, center)
	end)
	decorate("la puerta", function()
		buildDoor(model, backZ, width)
	end)
	decorate("las laminas", function()
		-- Tres laminas sobre la pared ciega y nada mas. Menos es mas.
		for index, spec in POSTERS do
			local z = frontZ + 12 + (index - 1) * ((depth - 24) / math.max(1, #POSTERS - 1))
			buildPoster(model, CFrame.new(-halfWidth + 0.58, 9, z) * CFrame.Angles(0, math.rad(-90), 0), spec)
		end
	end)
	decorate("el reloj", function()
		buildClock(model, CFrame.new(0, 13.2, frontZ + 0.72) * CFrame.Angles(0, math.pi, 0))
	end)
	decorate("el sacapuntas", function()
		block(model, "Sacapuntas", Vector3.new(0.8, 1, 0.7),
			CFrame.new(width / 2 - 11, 6.5, backZ - 0.9), Color3.fromRGB(120, 124, 132), Enum.Material.Metal)
	end)

	-- Grilla de pupitres
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
			-- Un banco roto es un banco menos, no un aula menos.
			local ok, desk = pcall(buildDesk, desksFolder, index, row, column, Vector3.new(x, 0, z))
			if ok then
				table.insert(desks, desk)
			else
				warn(string.format("[Aula] No se pudo construir el banco %d: %s", index, tostring(desk)))
			end
		end
	end

	-- Nodos de patrullaje: un pasillo entre cada par de columnas, mas los laterales.
	local aisleX: { number } = {}
	for column = 1, C.Columns - 1 do
		table.insert(aisleX, (column - (C.Columns + 1) / 2 + 0.5) * C.DeskSpacingX)
	end
	table.insert(aisleX, -halfWidth + 4)
	table.insert(aisleX, halfWidth - 4)
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
			local z = startZ + (endZ - startZ) * (s / steps)
			table.insert(patrolNodes, CFrame.new(x, 0, z) * CFrame.Angles(0, goingBack and math.pi or 0, 0))
		end
	end

	model.Parent = parent

	return {
		model = model,
		desks = desks,
		patrolNodes = patrolNodes,
		boardStand = CFrame.new(boardCF.Position.X, 0, boardCF.Position.Z + 4),
		teacherSpawn = CFrame.new(-11, 3, frontZ + 10) * CFrame.Angles(0, math.pi, 0),
		studentSpawn = CFrame.new(0, 3, backZ - 6),
		roomCenter = center,
		width = width,
		depth = depth,
	}
end

return ClassroomBuilder

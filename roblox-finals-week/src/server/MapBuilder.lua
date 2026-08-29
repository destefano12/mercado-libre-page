--!strict
--[[
	MapBuilder
	------------------------------------------------------------------
	Arma el instituto entero por codigo, con la direccion de arte de
	Style.lua y las proporciones de Config.Escuela.

		Workspace/Instituto/Pasillo      casilleros + zona de recreo
		Workspace/Instituto/Aulas/Aula1  filas fijas de pupitres,
		                                 tarima, pizarra y puerta
		Workspace/Instituto/Castigo      la sala de castigo

	Tres decisiones de arquitectura visual sostienen el look:

	  * El pasillo mide 16 studs de ancho y 11 de alto, con el falso
	    techo a 9.4. Es estrecho a proposito: dos personas cruzandose
	    ya se rozan, y correr por el se siente arriesgado.
	  * Nada de losas planas gigantes. El piso es un damero de baldosas
	    de 4 studs (una de cada doce, gastada) y el techo es una grilla
	    de placas acusticas de 6 con perfiles de aluminio entre medio.
	    Esa repeticion es lo que le da escala al pasillo y lo que hace
	    que se lea como un colegio y no como una caja.
	  * El desgaste es geometria: rayones en los casilleros, oxido en
	    las bases, manchas en las paredes, placas de techo manchadas.
	    Nada de eso necesita una textura subida.

	Cada pieza va en su propio pcall: si una silla explota, el resto
	del colegio se construye igual y el Output dice cual fallo.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Style = require(Shared:WaitForChild("Style"))
local Theme = require(Shared:WaitForChild("Theme"))
local Util = require(Shared:WaitForChild("Util"))

local Atmosphere = require(script.Parent:WaitForChild("Atmosphere"))

local E = Config.Escuela
local C = Style.Color
local M = Style.Material

local MapBuilder = {}

local rng = Random.new(20240607)

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
	dir: Vector3,
	desks: { Desk },
	door: BasePart,
	blackboard: BasePart,
	podium: BasePart,
	patrol: { Vector3 },
	spawn: Vector3,
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
	color: Color3, material: Enum.Material, reflectance: number?): BasePart
	local part = Util.part({
		Name = name,
		Size = size,
		CFrame = cf,
		Parent = parent,
	})
	Style.paint(part, color, material, reflectance)
	return part
end

local function decor(parent: Instance, name: string, size: Vector3, cf: CFrame,
	color: Color3, material: Enum.Material): BasePart
	local part = block(parent, name, size, cf, color, material)
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	return part
end

local function safely(label: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn(string.format("[Mapa] %s fallo: %s", label, tostring(err)))
	end
end

local function sign(parent: Instance, text: string, size: Vector2, cf: CFrame,
	face: Enum.NormalId, color: Color3?)
	local plate = decor(parent, "Cartel", Vector3.new(size.X, size.Y, 0.2), cf,
		color or Color3.fromRGB(28, 32, 40), M.MetalLiso)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 48
	gui.LightInfluence = 0.4
	gui.Parent = plate

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Theme.FontBold
	label.Text = text
	label.TextColor3 = Color3.fromRGB(232, 234, 238)
	label.TextScaled = true
	label.Parent = gui
end

-- ── piso y techo ───────────────────────────────────────────────────

--- Damero de baldosas. Una de cada doce sale gastada y una de cada
--- treinta lleva una mancha: alcanza para que el suelo no se lea
--- como una superficie plana infinita.
local function tiledFloor(parent: Instance, center: Vector3, width: number, length: number)
	local side = E.BaldosaLado
	local cols = math.max(1, math.floor(width / side))
	local rows = math.max(1, math.floor(length / side))
	local originX = center.X - (cols * side) / 2 + side / 2
	local originZ = center.Z - (rows * side) / 2 + side / 2

	for i = 0, cols - 1 do
		for j = 0, rows - 1 do
			local checker = (i + j) % 2 == 0
			local color = checker and C.Baldosa or C.BaldosaAlterna
			local material = M.Piso
			local roll = rng:NextNumber()
			if roll < 0.085 then
				color = C.BaldosaGastada
				material = M.PisoGastado
			end
			local tile = block(parent, "Baldosa", Vector3.new(side, 1, side),
				CFrame.new(originX + i * side, center.Y - 0.5, originZ + j * side),
				color, material, Style.Reflectance.Piso)
			tile.CastShadow = false

			if roll > 0.972 then
				-- Mancha de roce: una lamina finita, apenas mas oscura.
				decor(parent, "Mancha", Vector3.new(side * 0.7, 0.06, side * 0.55),
					tile.CFrame * CFrame.new(0, 0.53, 0) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
					C.BaldosaGastada, M.PisoGastado).Transparency = 0.35
			end
		end
	end
end

--- Falso techo: placas acusticas con perfiles de aluminio entre
--- medio, y luminarias empotradas cada SeparacionLuces.
--- `shadowEvery` dice cada cuantas luminarias una proyecta sombra.
local function dropCeiling(parent: Instance, center: Vector3, width: number, length: number,
	height: number, shadowEvery: number)
	local side = E.PlacaTecho
	local cols = math.max(1, math.floor(width / side))
	local rows = math.max(1, math.floor(length / side))
	local originX = center.X - (cols * side) / 2 + side / 2
	local originZ = center.Z - (rows * side) / 2 + side / 2

	local lightRow = math.max(1, math.floor(E.SeparacionLuces / side))
	local lights = 0

	for i = 0, cols - 1 do
		for j = 0, rows - 1 do
			local x = originX + i * side
			local z = originZ + j * side
			local cf = CFrame.new(x, height, z)

			-- Cada `lightRow` placas, en la columna del medio, va una
			-- luminaria en lugar de una placa.
			if j % lightRow == 0 and i == math.floor(cols / 2) then
				lights += 1
				Atmosphere.troffer(parent, cf, side - 0.6, side - 1.4,
					lights % shadowEvery == 0)
			else
				local stained = rng:NextNumber() < 0.09
				local plate = block(parent, "Placa", Vector3.new(side - 0.25, 0.3, side - 0.25),
					cf, stained and C.PlacaSucia or C.Placa, M.Placa)
				plate.CanCollide = false
			end
		end
	end

	-- Perfiles de aluminio: la grilla que sostiene las placas.
	for i = 0, cols do
		decor(parent, "Perfil", Vector3.new(0.2, 0.34, length),
			CFrame.new(originX - side / 2 + i * side, height, center.Z), C.Rejilla, M.Rejilla)
	end
	for j = 0, rows do
		decor(parent, "Perfil", Vector3.new(width, 0.34, 0.2),
			CFrame.new(center.X, height, originZ - side / 2 + j * side), C.Rejilla, M.Rejilla)
	end
end

--- Friso de media pared: la franja oscura que llevan los pasillos de
--- instituto. Es lo que mas rapido saca el look de "caja pintada".
local function wainscot(parent: Instance, cf: CFrame, length: number, axis: string)
	local thickness = 0.22
	local size = axis == "Z"
		and Vector3.new(thickness, E.AlturaZocalo, length)
		or Vector3.new(length, E.AlturaZocalo, thickness)
	decor(parent, "Friso", size, cf * CFrame.new(0, E.AlturaZocalo / 2, 0), C.MuroBajo, M.MuroBajo)

	local stripSize = axis == "Z"
		and Vector3.new(thickness + 0.06, 0.3, length)
		or Vector3.new(length, 0.3, thickness + 0.06)
	decor(parent, "Franja", stripSize,
		cf * CFrame.new(0, E.AlturaZocalo + 0.15, 0), C.MuroFranja, M.MetalLiso)
end

-- ── pasillo ────────────────────────────────────────────────────────

local function buildLocker(parent: Instance, cf: CFrame, index: number): Model
	local model = Instance.new("Model")
	model.Name = "Casillero" .. index
	model.Parent = parent

	local body = block(model, "Cuerpo",
		Vector3.new(E.CasilleroAncho, E.CasilleroAlto, E.CasilleroFondo), cf,
		C.Casillero, M.Casillero, Style.Reflectance.Casillero)
	model.PrimaryPart = body

	local door = block(model, "PuertaCasillero",
		Vector3.new(E.CasilleroAncho - 0.2, E.CasilleroAlto - 0.28, 0.16),
		cf * CFrame.new(0, 0, E.CasilleroFondo / 2 + 0.08),
		C.CasilleroLuz, M.Casillero, Style.Reflectance.Casillero)
	door.CanCollide = false

	decor(model, "Rejilla", Vector3.new(E.CasilleroAncho - 1.2, 0.75, 0.07),
		cf * CFrame.new(0, E.CasilleroAlto / 2 - 0.95, E.CasilleroFondo / 2 + 0.17),
		Color3.fromRGB(24, 30, 38), M.Metal)

	decor(model, "Manija", Vector3.new(0.2, 0.95, 0.14),
		cf * CFrame.new(E.CasilleroAncho / 2 - 0.5, -0.35, E.CasilleroFondo / 2 + 0.18),
		C.Manija, M.MetalLiso).Reflectance = Style.Reflectance.Manija

	-- Desgaste: rayones al azar y oxido en la base. Sin esto, veinte
	-- casilleros identicos se leen como un patron de papel pintado.
	for _ = 1, rng:NextInteger(0, 3) do
		decor(model, "Rayon",
			Vector3.new(rng:NextNumber(0.3, 1.6), rng:NextNumber(0.06, 0.16), 0.05),
			cf * CFrame.new(
				rng:NextNumber(-E.CasilleroAncho / 2 + 0.4, E.CasilleroAncho / 2 - 0.4),
				rng:NextNumber(-E.CasilleroAlto / 2 + 0.6, E.CasilleroAlto / 2 - 0.6),
				E.CasilleroFondo / 2 + 0.18)
				* CFrame.Angles(0, 0, rng:NextNumber(-0.5, 0.5)),
			C.Rayon, M.MetalLiso)
	end
	if rng:NextNumber() < 0.35 then
		decor(model, "Oxido",
			Vector3.new(E.CasilleroAncho - 0.5, rng:NextNumber(0.5, 1.3), 0.06),
			cf * CFrame.new(0, -E.CasilleroAlto / 2 + 0.7, E.CasilleroFondo / 2 + 0.17),
			C.Oxido, M.Oxido)
	end

	local number = Instance.new("SurfaceGui")
	number.Face = Enum.NormalId.Front
	number.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	number.PixelsPerStud = 40
	number.LightInfluence = 0.8
	number.Parent = door
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 36)
	label.Position = UDim2.new(0, 0, 0, 6)
	label.BackgroundTransparency = 1
	label.Font = Theme.FontBold
	label.Text = string.format("%03d", index)
	label.TextColor3 = Color3.fromRGB(206, 214, 220)
	label.TextTransparency = 0.25
	label.TextScaled = true
	label.Parent = number

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Abrir"
	prompt.ActionText = "Abrir"
	prompt.ObjectText = "Casillero " .. index
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = door

	model:SetAttribute("Indice", index)
	return model
end

local function buildRecreation(parent: Instance, zStart: number): BasePart
	local half = E.PasilloAncho / 2

	-- Bancos corridos contra el friso.
	for i = 0, 2 do
		local z = zStart + 6 + i * 10
		for _, side in { -1, 1 } do
			local x = side * (half - 2.4)
			block(parent, "Banco", Vector3.new(1.9, 0.35, 6.5),
				CFrame.new(x, 1.7, z), C.MaderaGastada, M.Madera)
			for _, dz in { -2.4, 2.4 } do
				decor(parent, "PataBanco", Vector3.new(1.6, 1.5, 0.4),
					CFrame.new(x, 0.85, z + dz), C.Metal, M.MetalLiso)
			end
		end
	end

	-- Maquinas expendedoras: el unico mueble alto del recreo.
	for i, side in { -1, 1 } do
		local x = side * (half - 1.3)
		local body = block(parent, "Expendedora", Vector3.new(2.2, 7, 3.8),
			CFrame.new(x, 3.5, zStart + 2 + i * 4), Color3.fromRGB(122, 44, 46), M.MetalLiso)
		local glass = decor(parent, "Vidrio", Vector3.new(0.18, 4.8, 3),
			body.CFrame * CFrame.new(-side * 1.15, 0.5, 0), C.Vidrio, M.Vidrio)
		glass.Transparency = 0.55
		glass.Reflectance = Style.Reflectance.Vidrio
	end

	-- Tachos y una fuente: cosas a la altura de la vista.
	for i = 0, 3 do
		local z = zStart + 5 + i * 8
		local side = (i % 2 == 0) and -1 or 1
		block(parent, "Tacho", Vector3.new(1.8, 2.6, 1.8),
			CFrame.new(side * (half - 1.9), 1.3, z), C.Metal, M.MetalLiso)
	end

	-- Kiosco: mostrador bajo con la persiana arriba.
	local counter = block(parent, "Tienda", Vector3.new(8, 3.4, 2.4),
		CFrame.new(0, 1.7, zStart + 28), C.MaderaOscura, M.Madera)
	decor(parent, "Persiana", Vector3.new(8.4, 3, 0.3),
		CFrame.new(0, 5.6, zStart + 28), C.Rejilla, M.Metal)
	sign(parent, "TIENDA", Vector2.new(6, 1.4),
		CFrame.new(0, 7.4, zStart + 28), Enum.NormalId.Front)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Tienda"
	prompt.ActionText = "Tienda"
	prompt.ObjectText = "Kiosco"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 11
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

	tiledFloor(hall, Vector3.new(0, 0, 0), E.PasilloAncho, E.PasilloLargo)
	block(hall, "Losa", Vector3.new(E.PasilloAncho + 2, 1, E.PasilloLargo),
		CFrame.new(0, E.AlturaPiso, 0), C.Losa, M.MuroAlto)

	for _, side in { -1, 1 } do
		local wall = block(hall, "Pared", Vector3.new(E.EspesorPared, E.AlturaPiso, E.PasilloLargo),
			CFrame.new(side * halfW, E.AlturaPiso / 2, 0), C.MuroAlto, M.MuroAlto)
		wainscot(hall, CFrame.new(side * (halfW - 0.55), 0, 0), E.PasilloLargo, "Z")

		-- Manchas de roce a la altura del hombro, salteadas.
		for _ = 1, 14 do
			decor(hall, "ManchaPared",
				Vector3.new(0.08, rng:NextNumber(0.6, 2.2), rng:NextNumber(1, 4)),
				CFrame.new(side * (halfW - 0.55), rng:NextNumber(4.5, 8),
					rng:NextNumber(-halfL + 4, halfL - 4)),
				C.MuroSucio, M.MuroAlto).Transparency = 0.45
		end
		wall.Reflectance = 0
	end

	for _, side in { -1, 1 } do
		block(hall, "Fondo", Vector3.new(E.PasilloAncho + 2, E.AlturaPiso, E.EspesorPared),
			CFrame.new(0, E.AlturaPiso / 2, side * halfL), C.MuroAlto, M.MuroAlto)
		wainscot(hall, CFrame.new(0, 0, side * (halfL - 0.55)), E.PasilloAncho, "X")
		Atmosphere.exitSign(hall, CFrame.new(0, E.AlturaFalsoTecho - 1.4, side * (halfL - 0.9)))
	end

	dropCeiling(hall, Vector3.new(0, 0, 0), E.PasilloAncho, E.PasilloLargo,
		E.AlturaFalsoTecho, 3)

	-- Casilleros: banda central, los dos lados.
	local lockers: { Model } = {}
	local bandStart = -halfL + 34
	for side_i, side in { -1, 1 } do
		for i = 0, E.CasillerosPorLado - 1 do
			local z = bandStart + i * (E.CasilleroAncho + 0.12)
			local cf = CFrame.new(side * (halfW - E.CasilleroFondo / 2 - 0.75),
				E.CasilleroAlto / 2, z)
				* CFrame.Angles(0, side < 0 and math.rad(90) or math.rad(-90), 0)
			local index = (side_i - 1) * E.CasillerosPorLado + i + 1
			table.insert(lockers, buildLocker(hall, cf, index))
		end
	end

	local shop = buildRecreation(hall, halfL - E.ZonaRecreoLargo)

	local bell = decor(hall, "Campana", Vector3.new(1.6, 1.6, 0.7),
		CFrame.new(0, E.AlturaFalsoTecho - 1.6, halfL - 3),
		Color3.fromRGB(158, 128, 62), M.MetalLiso)

	local spawns: { Vector3 } = {}
	for i = 0, 11 do
		local x = ((i % 3) - 1) * 3.6
		local z = halfL - 8 - math.floor(i / 3) * 5
		table.insert(spawns, Vector3.new(x, 4, z))
	end

	return hall, lockers, shop, bell, spawns
end

-- ── aulas ──────────────────────────────────────────────────────────

local function buildDesk(parent: Instance, position: Vector3, look: Vector3,
	aula: number, fila: number, asiento: number): Desk
	local face = CFrame.lookAt(position, position + look)

	local desk = block(parent, "Pupitre", Vector3.new(3.9, 0.26, 2.3),
		face * CFrame.new(0, 2.7, -1.25), C.Madera, M.Madera)
	decor(parent, "BordePupitre", Vector3.new(4, 0.3, 0.22),
		desk.CFrame * CFrame.new(0, -0.06, -1.05), C.Metal, M.MetalLiso)

	-- Marcas de uso en la tapa: nadie estudia sin rayar el pupitre.
	for _ = 1, rng:NextInteger(1, 3) do
		decor(parent, "Marca",
			Vector3.new(rng:NextNumber(0.2, 1.1), 0.03, rng:NextNumber(0.05, 0.3)),
			desk.CFrame * CFrame.new(rng:NextNumber(-1.6, 1.6), 0.15, rng:NextNumber(-0.9, 0.9))
				* CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			C.MaderaGastada, M.MaderaLisa)
	end

	for _, dx in { -1.6, 1.6 } do
		for _, dz in { -0.8, 0.8 } do
			decor(parent, "PataPupitre", Vector3.new(0.2, 2.7, 0.2),
				desk.CFrame * CFrame.new(dx, -1.35, dz), C.Metal, M.MetalLiso)
		end
	end
	decor(parent, "Bandeja", Vector3.new(3.3, 0.14, 1.7),
		desk.CFrame * CFrame.new(0, -1, 0), C.MaderaGastada, M.MaderaLisa)

	local seat = Instance.new("Seat")
	seat.Name = "Asiento"
	seat.Size = Vector3.new(2.3, 0.35, 2.3)
	seat.CFrame = face * CFrame.new(0, 2, 1)
	seat.Anchored = true
	seat.CanCollide = true
	seat.TopSurface = Enum.SurfaceType.Smooth
	Style.paint(seat, C.Asiento, M.MaderaLisa)
	seat.Parent = parent

	decor(parent, "Respaldo", Vector3.new(2.3, 2.3, 0.26),
		seat.CFrame * CFrame.new(0, 1.25, 1), C.Asiento, M.MaderaLisa)
	for _, dx in { -0.9, 0.9 } do
		for _, dz in { -0.8, 0.8 } do
			decor(parent, "PataSilla", Vector3.new(0.18, 2, 0.18),
				seat.CFrame * CFrame.new(dx, -1, dz), C.Metal, M.MetalLiso)
		end
	end

	local paper = decor(parent, "Hoja", Vector3.new(2.2, 0.04, 1.55),
		desk.CFrame * CFrame.new(0, 0.16, -0.05), Color3.fromRGB(248, 246, 238),
		Enum.Material.SmoothPlastic)

	seat:SetAttribute("Aula", aula)
	seat:SetAttribute("Fila", fila)
	seat:SetAttribute("Asiento", asiento)

	return { seat = seat, desk = desk, paper = paper, fila = fila, asiento = asiento, aula = aula }
end

local function buildClassroom(root: Instance, index: number): Classroom
	local model = Instance.new("Model")
	model.Name = "Aula" .. index
	model.Parent = root

	local side = (index % 2 == 1) and -1 or 1
	local row = math.floor((index - 1) / 2)
	local halfW = E.AulaAncho / 2
	local halfL = E.AulaLargo / 2
	local height = E.AulaAltura
	local cx = side * (E.PasilloAncho / 2 + halfW)
	local cz = -22 - row * (E.AulaLargo + 10)
	local center = Vector3.new(cx, 0, cz)

	local dir = Vector3.new(-side, 0, 0)
	local look = -dir

	tiledFloor(model, center, E.AulaAncho, E.AulaLargo)
	block(model, "Losa", Vector3.new(E.AulaAncho, 1, E.AulaLargo),
		CFrame.new(cx, height, cz), C.Losa, M.MuroAlto)

	block(model, "ParedFondo", Vector3.new(E.EspesorPared, height, E.AulaLargo),
		CFrame.new(cx - dir.X * halfW, height / 2, cz), C.MuroAlto, M.MuroAlto)
	for _, dz in { -1, 1 } do
		block(model, "ParedLateral", Vector3.new(E.AulaAncho, height, E.EspesorPared),
			CFrame.new(cx, height / 2, cz + dz * halfL), C.MuroAlto, M.MuroAlto)
		wainscot(model, CFrame.new(cx, 0, cz + dz * (halfL - 0.55)), E.AulaAncho, "X")
	end

	local doorWidth, doorHeight = 6, 8.5
	local wallX = cx + dir.X * halfW
	local sidePiece = (E.AulaLargo - doorWidth) / 2
	for _, dz in { -1, 1 } do
		block(model, "ParedPasillo", Vector3.new(E.EspesorPared, height, sidePiece),
			CFrame.new(wallX, height / 2, cz + dz * (doorWidth / 2 + sidePiece / 2)),
			C.MuroAlto, M.MuroAlto)
	end
	block(model, "Dintel", Vector3.new(E.EspesorPared, height - doorHeight, doorWidth),
		CFrame.new(wallX, doorHeight + (height - doorHeight) / 2, cz), C.MuroAlto, M.MuroAlto)

	local door = block(model, "Puerta", Vector3.new(0.35, doorHeight, doorWidth),
		CFrame.new(wallX, doorHeight / 2, cz), C.Puerta, M.Madera)
	door.CanCollide = false
	door.Transparency = 1
	door:SetAttribute("Trabada", false)
	decor(model, "MarcoPuerta", Vector3.new(0.5, doorHeight + 0.4, doorWidth + 0.7),
		CFrame.new(wallX, doorHeight / 2, cz), C.MarcoPuerta, M.MetalLiso)

	sign(model, "AULA " .. index, Vector2.new(4.4, 1.3),
		CFrame.new(wallX + dir.X * 0.7, doorHeight + 0.9, cz)
			* CFrame.Angles(0, side < 0 and math.rad(90) or math.rad(-90), 0),
		Enum.NormalId.Front)

	-- Ventanas altas y angostas en la pared del fondo: dejan entrar
	-- luz de tarde pero no dejan ver afuera desde el pupitre.
	for i = -1, 1 do
		local glass = decor(model, "Ventana", Vector3.new(0.28, 4, 6),
			CFrame.new(cx - dir.X * (halfW - 0.2), 6.4, cz + i * 9), C.Vidrio, M.Vidrio)
		glass.Transparency = 0.5
		glass.Reflectance = Style.Reflectance.Vidrio
		decor(model, "MarcoVentana", Vector3.new(0.36, 4.4, 6.5),
			CFrame.new(cx - dir.X * (halfW - 0.22), 6.4, cz + i * 9), C.MarcoPuerta, M.MetalLiso)
	end

	local boardX = cx - dir.X * (halfW - 0.7)
	local blackboard = block(model, "Pizarra", Vector3.new(0.35, 6, 20),
		CFrame.new(boardX, 6.4, cz), C.Pizarra, M.Pizarra, Style.Reflectance.Pizarra)
	decor(model, "MarcoPizarra", Vector3.new(0.42, 6.5, 20.6),
		CFrame.new(boardX + dir.X * 0.08, 6.4, cz), C.MarcoPizarra, M.MetalLiso)
	decor(model, "Bandeja", Vector3.new(0.55, 0.22, 20),
		CFrame.new(boardX + dir.X * 0.3, 3.2, cz), C.MarcoPizarra, M.MetalLiso)

	local podium = block(model, "Tarima", Vector3.new(8, 0.8, E.AulaLargo - 8),
		CFrame.new(boardX + dir.X * 4.4, 0.4, cz), C.MaderaOscura, M.Madera)

	local deskTeacher = block(model, "EscritorioProfesor", Vector3.new(3, 0.3, 7),
		CFrame.new(boardX + dir.X * 6, 3.7, cz), C.MaderaOscura, M.Madera)
	for _, dz in { -3, 3 } do
		decor(model, "PataEscritorio", Vector3.new(2.6, 3.2, 0.35),
			deskTeacher.CFrame * CFrame.new(0, -1.75, dz), C.MaderaOscura, M.MaderaLisa)
	end

	local desks: { Desk } = {}
	for fila = 1, E.FilasDePupitres do
		for asiento = 1, E.PupitresPorFila do
			local offsetX = 11 + (fila - 1) * E.PupitreSeparacionX
			local offsetZ = (asiento - (E.PupitresPorFila + 1) / 2) * E.PupitreSeparacionZ
			local position = Vector3.new(boardX + dir.X * offsetX, 0, cz + offsetZ)
			safely(string.format("pupitre A%d F%d P%d", index, fila, asiento), function()
				table.insert(desks, buildDesk(model, position, look, index, fila, asiento))
			end)
		end
	end

	local patrol: { Vector3 } = {}
	for fila = 1, E.FilasDePupitres do
		local x = boardX + dir.X * (11 + (fila - 1) * E.PupitreSeparacionX
			+ E.PupitreSeparacionX / 2)
		local edge = (E.PupitresPorFila / 2) * E.PupitreSeparacionZ + 0.5
		local a = Vector3.new(x, 3, cz - edge)
		local b = Vector3.new(x, 3, cz + edge)
		if fila % 2 == 0 then
			a, b = b, a
		end
		table.insert(patrol, a)
		table.insert(patrol, b)
	end

	-- Techo del aula: mismo sistema que el pasillo, con TODAS las
	-- luminarias proyectando sombra. Es la unica sala donde importa
	-- que las sombras de los pupitres se vean nitidas.
	dropCeiling(model, center, E.AulaAncho, E.AulaLargo, height - 1.2, 1)

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
		spawn = Vector3.new(boardX + dir.X * 4.5, 4, cz),
	}
end

-- ── sala de castigo ────────────────────────────────────────────────

local function buildDetention(root: Instance): BasePart
	local model = Instance.new("Model")
	model.Name = "Castigo"
	model.Parent = root

	local c = E.SalaDeCastigo
	local size = 18
	tiledFloor(model, Vector3.new(c.X, 0, c.Z), size, size)
	block(model, "Losa", Vector3.new(size, 1, size),
		CFrame.new(c.X, 10, c.Z), C.Losa, M.MuroAlto)
	for _, offset in { size / 2, -size / 2 } do
		block(model, "Pared", Vector3.new(1, 10, size),
			CFrame.new(c.X + offset, 5, c.Z), C.MuroAlto, M.MuroAlto)
		block(model, "Pared", Vector3.new(size, 10, 1),
			CFrame.new(c.X, 5, c.Z + offset), C.MuroAlto, M.MuroAlto)
	end

	local chair = block(model, "Banquito", Vector3.new(2.4, 0.35, 2.4),
		CFrame.new(c.X, 2.6, c.Z), C.MaderaOscura, M.MaderaLisa)
	sign(model, "SALA DE CASTIGO", Vector2.new(9, 1.8),
		CFrame.new(c.X, 7, c.Z - size / 2 + 0.7), Enum.NormalId.Front)

	-- Un solo tubo, parpadeando: es la sala donde te dejan pensar.
	local troffer = Atmosphere.troffer(model, CFrame.new(c.X, 8.6, c.Z), 4, 6, true)
	local diffuser = model:FindFirstChild("Difusor")
	if diffuser and diffuser:IsA("BasePart") then
		local light = diffuser:FindFirstChildOfClass("SurfaceLight")
		task.spawn(function()
			while diffuser.Parent do
				task.wait(rng:NextNumber(2, 7))
				if light then
					light.Brightness = 0.2
					diffuser.Material = Enum.Material.SmoothPlastic
					task.wait(0.09)
					light.Brightness = 1.35
					diffuser.Material = Enum.Material.Neon
				end
			end
		end)
	end
	troffer.Name = "Luminaria"

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

	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	-- Texturas PBR propias, si el usuario cargo ids en Config.Texturas.
	local applied = Style.applySurfaces(root, Style.SurfaceMap)
	if applied > 0 then
		print(string.format("[Mapa] %d piezas con textura propia.", applied))
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

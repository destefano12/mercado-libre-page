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

	  * El pasillo es un atrio: 46 studs de ancho y 22 de alto, sin falso
	    techo, con claraboya a lo largo del eje y una estatua en el
	    medio. (Antes media 16 de ancho con el techo a 9.4, hecho
	    estrecho a proposito — la referencia mostro lo contrario.)
	  * Nada de losas planas gigantes. El atrio es un damero de baldosas
	    de 4 studs y el aula un piso de tablones. Esa repeticion es lo
	    que le da escala y lo que hace que se lea como un edificio.
	  * Las superficies estan limpias y son de color plano. El desgaste
	    geometrico que habia antes — rayones, oxido, manchas — se
	    elimino: empujaba el look hacia lo realista, que es justo lo
	    contrario de la referencia.

	Cada aula toma un esquema de color distinto de `Style.Aulas`.

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

	--[[
		Damero limpio. La version anterior gastaba una baldosa de cada
		doce y le tiraba manchas de roce encima: en la referencia el piso
		esta impecable, y la mugre era justo lo que empujaba el look
		hacia lo realista.
	--]]
	for i = 0, cols - 1 do
		for j = 0, rows - 1 do
			local checker = (i + j) % 2 == 0
			local tile = block(parent, "Baldosa", Vector3.new(side, 1, side),
				CFrame.new(originX + i * side, center.Y - 0.5, originZ + j * side),
				checker and C.Baldosa or C.BaldosaAlterna, M.Piso, Style.Reflectance.Piso)
			tile.CastShadow = false
		end
	end
end

--- Piso de tablones para el aula: listones largos en dos tonos de miel.
local function plankFloor(parent: Instance, center: Vector3, width: number, length: number)
	local plank = E.TablonAncho
	local cols = math.max(1, math.floor(width / plank))
	local originX = center.X - (cols * plank) / 2 + plank / 2

	for i = 0, cols - 1 do
		local board = block(parent, "Tablon", Vector3.new(plank - 0.08, 1, length),
			CFrame.new(originX + i * plank, center.Y - 0.5, center.Z),
			i % 2 == 0 and C.Tablon or C.TablonAlterno, M.Madera)
		board.CastShadow = false
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
				-- Sin placas manchadas: la filtracion de humedad era
				-- parte del look sucio que ya no va.
				local plate = block(parent, "Placa", Vector3.new(side - 0.25, 0.3, side - 0.25),
					cf, C.Placa, M.Placa)
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
--- `band` deja elegir el color: en el atrio es la banda turquesa de la
--- referencia, en el aula es el zocalo crema bajo el verde salvia.
local function wainscot(parent: Instance, cf: CFrame, length: number, axis: string,
	band: Color3?, edge: Color3?)
	local thickness = 0.22
	local size = axis == "Z"
		and Vector3.new(thickness, E.AlturaZocalo, length)
		or Vector3.new(length, E.AlturaZocalo, thickness)
	decor(parent, "Friso", size, cf * CFrame.new(0, E.AlturaZocalo / 2, 0),
		band or C.MuroBajo, M.MuroBajo)

	local stripSize = axis == "Z"
		and Vector3.new(thickness + 0.06, 0.3, length)
		or Vector3.new(length, 0.3, thickness + 0.06)
	decor(parent, "Franja", stripSize,
		cf * CFrame.new(0, E.AlturaZocalo + 0.15, 0), edge or C.MuroFranja, M.MetalLiso)
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

	-- La rejilla de ventilacion. Era casi negra, que sobre una puerta
	-- celeste hace un agujero; ahora es el mismo azul un tono abajo.
	decor(model, "Rejilla", Vector3.new(E.CasilleroAncho - 1.2, 0.75, 0.07),
		cf * CFrame.new(0, E.CasilleroAlto / 2 - 0.95, E.CasilleroFondo / 2 + 0.17),
		C.Rayon, M.Casillero)

	decor(model, "Manija", Vector3.new(0.2, 0.95, 0.14),
		cf * CFrame.new(E.CasilleroAncho / 2 - 0.5, -0.35, E.CasilleroFondo / 2 + 0.18),
		C.Manija, M.MetalLiso).Reflectance = Style.Reflectance.Manija

	--[[
		Aca iban de cero a tres rayones al azar por puerta y oxido en la
		base de uno de cada tres casilleros. En la referencia los
		casilleros estan limpios y son de un celeste parejo; lo que
		rompe la repeticion es el numero pintado, no la mugre.
	--]]

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
	-- Numero oscuro: la puerta ahora es clara.
	label.TextColor3 = Color3.fromRGB(58, 84, 132)
	label.TextTransparency = 0.15
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

--[[
	La estatua del centro del atrio: figuras apiladas sobre un pedestal
	redondo. Sale marcada como pintable igual que las paredes, asi que
	la mecanica de "decorar estatuas" es el sistema de grafiti que ya
	existe apuntado a otra superficie.

	Es tambien la unica geometria no-caja del mapa: hasta ahora todo el
	instituto eran prismas alineados a los ejes, y eso solo ya delataba
	que estaba hecho a las apuradas.
--]]
local function buildStatue(parent: Instance, center: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Estatua"
	model.Parent = parent

	local function shaped(name: string, size: Vector3, cf: CFrame, color: Color3,
		mesh: Enum.MeshType): BasePart
		local part = block(model, name, size, cf, color, M.Piedra)
		local special = Instance.new("SpecialMesh")
		special.MeshType = mesh
		special.Parent = part
		return part
	end

	--[[
		Todas las piezas del cuerpo se llaman "Estatua" a proposito:
		`GraffitiService.markMap` marca lo pintable por nombre exacto de
		pieza, asi que nombrarlas Cuerpo1/Cabeza1 las habria dejado fuera
		y la mecanica de decorar la estatua no existiria.
	--]]
	local radius = E.EstatuaRadio
	shaped("Pedestal", Vector3.new(radius * 2, 1.6, radius * 2),
		CFrame.new(center.X, 0.8, center.Z), C.Pedestal, Enum.MeshType.Cylinder)
	shaped("Estatua", Vector3.new(radius * 1.5, 1, radius * 1.5),
		CFrame.new(center.X, 1.9, center.Z), C.Estatua, Enum.MeshType.Cylinder)

	-- Cuatro cuerpos apilados, cada uno mas chico y girado.
	local height = 2.4
	local levels = 4
	local step = (E.EstatuaAltura - height) / levels
	for i = 1, levels do
		local shrink = 1 - (i - 1) * 0.17
		local turn = i * 0.9
		shaped("Estatua", Vector3.new(2.6 * shrink, step * 0.72, 1.7 * shrink),
			CFrame.new(center.X, height + (i - 1) * step + step * 0.4, center.Z)
				* CFrame.Angles(0, turn, 0),
			C.Estatua, Enum.MeshType.Sphere)
		shaped("Estatua", Vector3.new(1.5 * shrink, 1.5 * shrink, 1.5 * shrink),
			CFrame.new(center.X, height + (i - 1) * step + step * 0.92, center.Z)
				* CFrame.Angles(0, turn, 0),
			C.Estatua, Enum.MeshType.Sphere)
	end

	return model
end

local function buildHallway(root: Model): (Model, { Model }, BasePart, BasePart, { Vector3 })
	local hall = Instance.new("Model")
	hall.Name = "Pasillo"
	hall.Parent = root

	local halfW = E.PasilloAncho / 2
	local halfL = E.PasilloLargo / 2
	local top = E.AlturaPiso

	--[[
		Esto era un corredor de 16 studs con falso techo a 9.4, hecho
		angosto a proposito. La referencia muestra un atrio ancho y de
		techo alto, asi que se va el falso techo entero: el techo que
		ves ahora es la losa, a 22, y las luminarias cuelgan de ahi en
		vez de estar empotradas.
	--]]
	tiledFloor(hall, Vector3.new(0, 0, 0), E.PasilloAncho, E.PasilloLargo)
	block(hall, "Losa", Vector3.new(E.PasilloAncho + 2, 1, E.PasilloLargo),
		CFrame.new(0, top, 0), C.Losa, M.MuroAlto)

	for _, side in { -1, 1 } do
		block(hall, "Pared", Vector3.new(E.EspesorPared, top, E.PasilloLargo),
			CFrame.new(side * halfW, top / 2, 0), C.MuroAlto, M.MuroAlto)
		wainscot(hall, CFrame.new(side * (halfW - 0.55), 0, 0), E.PasilloLargo, "Z")
	end

	for _, side in { -1, 1 } do
		block(hall, "Fondo", Vector3.new(E.PasilloAncho + 2, top, E.EspesorPared),
			CFrame.new(0, top / 2, side * halfL), C.MuroAlto, M.MuroAlto)
		wainscot(hall, CFrame.new(0, 0, side * (halfL - 0.55)), E.PasilloAncho, "X")
		-- Iba a AlturaFalsoTecho, que ya no existe: ahora cuelga sobre
		-- las puertas del fondo, a una altura de cartel de verdad.
		Atmosphere.exitSign(hall, CFrame.new(0, 10.5, side * (halfL - 0.9)))
	end

	--[[
		Claraboya: una franja de neon a lo largo del eje del atrio. Es
		de donde viene la sensacion de dia que tiene la referencia — un
		atrio de techo alto iluminado solo por luminarias se lee como un
		estacionamiento.
	--]]
	local skylight = decor(hall, "Claraboya", Vector3.new(10, 0.4, E.PasilloLargo - 24),
		CFrame.new(0, top - 0.7, 0), C.Tubo, M.Neon)
	local sun = Instance.new("SurfaceLight")
	sun.Face = Enum.NormalId.Bottom
	sun.Angle = 150
	sun.Range = 60
	sun.Brightness = 2.2
	sun.Color = C.LuzCalida
	sun.Shadows = false
	sun.Parent = skylight

	-- Luminarias colgadas, en dos filas a los lados de la claraboya.
	local lightRows = math.max(1, math.floor(E.PasilloLargo / E.SeparacionLuces))
	for row = 0, lightRows - 1 do
		local z = -halfL + E.SeparacionLuces * (row + 0.5)
		for _, side in { -1, 1 } do
			Atmosphere.troffer(hall, CFrame.new(side * 13, top - 1.2, z), 4, 8, row % 3 == 0)
		end
	end

	-- Casilleros contra las dos paredes largas.
	local lockers: { Model } = {}
	local bandStart = -halfL + 26
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

	buildStatue(hall, Vector3.new(0, 0, 0))

	local shop = buildRecreation(hall, halfL - E.ZonaRecreoLargo)

	local bell = decor(hall, "Campana", Vector3.new(1.6, 1.6, 0.7),
		CFrame.new(0, 11.5, halfL - 3), C.Dorado, M.MetalLiso)

	-- Los puntos de aparicion se abren con el atrio: en un espacio de 46
	-- de ancho, tres columnas a 3.6 dejaban a todos amontonados.
	local spawns: { Vector3 } = {}
	for i = 0, 11 do
		local x = ((i % 4) - 1.5) * 7
		local z = halfL - 10 - math.floor(i / 4) * 6
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

	-- Aca iban una a tres marcas talladas al azar en la tapa. Van fuera
	-- por lo mismo que los rayones de los casilleros: la referencia
	-- tiene mobiliario limpio y de color parejo.

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

	--[[
		Banqueta redonda pegada al pupitre, no una silla suelta con
		respaldo. Es lo que se ve en el trailer y cambia bastante la
		lectura del aula: un pupitre con su banqueta es una sola pieza de
		mobiliario escolar, dos muebles sueltos parecen una cafeteria.
	--]]
	local stool = decor(parent, "Banqueta", Vector3.new(2.1, 0.34, 2.1),
		seat.CFrame, C.Asiento, M.MaderaLisa)
	local stoolMesh = Instance.new("SpecialMesh")
	stoolMesh.MeshType = Enum.MeshType.Cylinder
	stoolMesh.Parent = stool

	-- Un solo pie central que sale del brazo del pupitre.
	decor(parent, "PataBanqueta", Vector3.new(0.34, 2, 0.34),
		seat.CFrame * CFrame.new(0, -1, 0), C.Metal, M.MetalLiso)
	decor(parent, "BrazoBanqueta", Vector3.new(0.32, 0.32, 2.2),
		seat.CFrame * CFrame.new(0, -1.85, -1.1), C.Metal, M.MetalLiso)

	--[[
		La hoja. Era de 2.2 x 1.55, que a 60 pixeles por stud da un lienzo
		de 132x93 — no entra texto legible ahi. En el trailer la hoja es
		el centro del examen: se lee y se marca en primera persona, con el
		lapiz en la mano. Asi que crece para poder cumplir ese papel.
	--]]
	local paper = decor(parent, "Hoja", Vector3.new(3.2, 0.04, 2.3),
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

	--[[
		Cada aula con su esquema de color. En el trailer no hay una
		paleta de aula sino varias — una periwinkle, otra verde salvia —
		y pintarlas todas iguales hacia que el colegio se leyera como un
		pasillo repetido.
	--]]
	local scheme = Style.Aulas[(index - 1) % #Style.Aulas + 1]

	-- Piso de tablones terracota, no baldosa: el aula de la referencia
	-- tiene parquet y es lo que la separa del atrio.
	plankFloor(model, center, E.AulaAncho, E.AulaLargo)
	block(model, "Losa", Vector3.new(E.AulaAncho, 1, E.AulaLargo),
		CFrame.new(cx, height, cz), C.Losa, M.MuroAlto)

	--[[
		Las dos paredes laterales. Una es maciza; la otra lleva el
		ventanal.

		Antes las ventanas eran tres paneles angostos y translucidos
		pegados sobre una pared maciza: entraba luz pero no se veia
		nada, y estaba escrito a proposito ("no dejan ver afuera desde
		el pupitre"). En la referencia el aula tiene un ventanal grande
		con vista real — cielo, agua y montanas — y esa vista es la
		mitad de por que el aula se siente luminosa. Asi que la pared se
		arma en cuatro pedazos alrededor de un hueco de verdad.
	--]]
	local sill, headHeight = 5, 11
	local glassSpan = 20
	local jamb = (E.AulaAncho - glassSpan) / 2

	block(model, "ParedLateral", Vector3.new(E.AulaAncho, height, E.EspesorPared),
		CFrame.new(cx, height / 2, cz + halfL), scheme.alta, M.MuroAlto)
	wainscot(model, CFrame.new(cx, 0, cz + halfL - 0.55), E.AulaAncho, "X",
		scheme.baja, scheme.baja)

	local windowZ = cz - halfL
	block(model, "ParedLateral", Vector3.new(E.AulaAncho, sill, E.EspesorPared),
		CFrame.new(cx, sill / 2, windowZ), scheme.alta, M.MuroAlto)
	block(model, "ParedLateral", Vector3.new(E.AulaAncho, height - headHeight, E.EspesorPared),
		CFrame.new(cx, headHeight + (height - headHeight) / 2, windowZ), scheme.alta, M.MuroAlto)
	for _, dx in { -1, 1 } do
		block(model, "ParedLateral",
			Vector3.new(jamb, headHeight - sill, E.EspesorPared),
			CFrame.new(cx + dx * (glassSpan / 2 + jamb / 2), (sill + headHeight) / 2, windowZ),
			scheme.alta, M.MuroAlto)
	end
	wainscot(model, CFrame.new(cx, 0, windowZ + 0.55), E.AulaAncho, "X",
		scheme.baja, scheme.baja)

	local glass = decor(model, "Ventana",
		Vector3.new(glassSpan, headHeight - sill, 0.2),
		CFrame.new(cx, (sill + headHeight) / 2, windowZ), C.Vidrio, M.Vidrio)
	glass.Transparency = 0.72
	glass.Reflectance = Style.Reflectance.Vidrio

	-- Marco y dos parteluces: sin ellos el hueco se lee como un agujero
	-- en la pared, no como una ventana.
	for _, dx in { -1, 1 } do
		decor(model, "MarcoVentana", Vector3.new(0.5, headHeight - sill + 0.5, 0.34),
			CFrame.new(cx + dx * glassSpan / 2, (sill + headHeight) / 2, windowZ),
			C.MarcoVentana, M.MetalLiso)
	end
	for _, dy in { sill, headHeight } do
		decor(model, "MarcoVentana", Vector3.new(glassSpan + 0.5, 0.5, 0.34),
			CFrame.new(cx, dy, windowZ), C.MarcoVentana, M.MetalLiso)
	end
	for _, dx in { -glassSpan / 6, glassSpan / 6 } do
		decor(model, "Parteluz", Vector3.new(0.32, headHeight - sill, 0.3),
			CFrame.new(cx + dx, (sill + headHeight) / 2, windowZ), C.MarcoVentana, M.MetalLiso)
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

	-- La pared del pizarron, maciza: el ventanal esta enfrentado, en la
	-- lateral, como en la referencia.
	block(model, "ParedFondo", Vector3.new(E.EspesorPared, height, E.AulaLargo),
		CFrame.new(cx - dir.X * halfW, height / 2, cz), scheme.alta, M.MuroAlto)

	local boardX = cx - dir.X * (halfW - 0.7)
	local blackboard = block(model, "Pizarra", Vector3.new(0.35, 6, 20),
		CFrame.new(boardX, 6.4, cz), C.Pizarra, M.Pizarra, Style.Reflectance.Pizarra)

	-- Marco de madera grueso, no un perfil de aluminio fino: en la
	-- referencia el pizarron esta enmarcado en madera calida y ancha, y
	-- eso solo ya lo saca del registro institucional.
	for _, dz in { -1, 1 } do
		decor(model, "MarcoPizarra", Vector3.new(0.5, 7.2, 0.6),
			CFrame.new(boardX + dir.X * 0.1, 6.4, cz + dz * 10.3), C.MarcoPizarra, M.Madera)
	end
	for _, dy in { -3.3, 3.3 } do
		decor(model, "MarcoPizarra", Vector3.new(0.5, 0.6, 21.2),
			CFrame.new(boardX + dir.X * 0.1, 6.4 + dy, cz), C.MarcoPizarra, M.Madera)
	end
	decor(model, "Bandeja", Vector3.new(0.7, 0.24, 20),
		CFrame.new(boardX + dir.X * 0.35, 2.9, cz), C.MarcoPizarra, M.Madera)

	--[[
		La pantalla de proyector, enrollada sobre el pizarron. Va marcada
		como pintable igual que las paredes: en la referencia los alumnos
		dibujan encima, y con eso la mecanica sale del sistema de
		grafiti que ya existe.
	--]]
	decor(model, "TuboPantalla", Vector3.new(0.7, 0.7, 15),
		CFrame.new(boardX + dir.X * 1.1, height - 1.6, cz), C.MarcoVentana, M.MetalLiso)
	local screen = block(model, "Pantalla", Vector3.new(0.16, 7.5, 14.4),
		CFrame.new(boardX + dir.X * 1.1, height - 5.6, cz), C.Pantalla, M.Placa)
	screen.CanCollide = false

	local podium = block(model, "Tarima", Vector3.new(8, 0.8, E.AulaLargo - 8),
		CFrame.new(boardX + dir.X * 4.4, 0.4, cz), C.MaderaOscura, M.Madera)

	local deskTeacher = block(model, "EscritorioProfesor", Vector3.new(3, 0.3, 7),
		CFrame.new(boardX + dir.X * 6, 3.7, cz), C.Madera, M.Madera)
	for _, dz in { -3, 3 } do
		decor(model, "PataEscritorio", Vector3.new(2.6, 3.2, 0.35),
			deskTeacher.CFrame * CFrame.new(0, -1.75, dz), C.Madera, M.MaderaLisa)
	end

	--[[
		Los trastos del escritorio: un monitor de tubo con papeles
		apilados encima y un globo terraqueo en la punta. Son cuatro
		piezas que no hacen nada, pero un escritorio vacio se lee como un
		bloque de madera y con esto se lee como el escritorio de alguien.
	--]]
	local screenBody = decor(model, "Monitor", Vector3.new(2, 1.8, 2.2),
		deskTeacher.CFrame * CFrame.new(0, 1.05, -1.6), Color3.fromRGB(226, 218, 198),
		M.MetalLiso)
	decor(model, "MonitorVidrio", Vector3.new(0.12, 1.3, 1.7),
		screenBody.CFrame * CFrame.new(dir.X * -1.02, 0.05, 0),
		Color3.fromRGB(96, 112, 118), M.MetalLiso)
	decor(model, "Papeles", Vector3.new(1.5, 0.35, 1.8),
		deskTeacher.CFrame * CFrame.new(0, 0.34, 1.4), C.Pantalla, M.Placa)

	local globe = decor(model, "Globo", Vector3.new(1.3, 1.3, 1.3),
		deskTeacher.CFrame * CFrame.new(0, 0.95, 2.6),
		Color3.fromRGB(96, 158, 202), M.MuroAlto)
	local globeMesh = Instance.new("SpecialMesh")
	globeMesh.MeshType = Enum.MeshType.Sphere
	globeMesh.Parent = globe
	decor(model, "GloboPie", Vector3.new(0.7, 0.3, 0.7),
		deskTeacher.CFrame * CFrame.new(0, 0.32, 2.6), C.Laton, M.MetalLiso)

	--[[
		Los cajones del escritorio, con tirador dorado. Es una mecanica
		confirmada del juego real: adentro esta la hoja de respuestas, y
		abrirlos delante del profesor es la jugada mas cara del examen.
		El `ProximityPrompt` se llama "Cajon" para que ItemService lo
		distinga del de los casilleros.
	--]]
	for i = 0, 1 do
		local drawer = block(model, "Cajon", Vector3.new(2.7, 1.15, 3),
			deskTeacher.CFrame * CFrame.new(0, -0.85 - i * 1.3, -1.7),
			C.MaderaGastada, M.Madera)
		drawer.CanCollide = false
		decor(model, "Tirador", Vector3.new(0.34, 0.26, 1.1),
			drawer.CFrame * CFrame.new(dir.X * 1.45, 0, 0), C.Dorado, M.MetalLiso)

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Cajon"
		prompt.ActionText = "Abrir"
		prompt.ObjectText = "Escritorio"
		prompt.HoldDuration = 1.1
		prompt.MaxActivationDistance = 7
		prompt.RequiresLineOfSight = false
		prompt.Parent = drawer
		drawer:SetAttribute("Aula", index)
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

	--[[
		Las aulas estaban peladas: cuatro paredes, pupitres y pizarron.
		En la referencia son salas habitadas — hay estanterias con libros
		al fondo, una cartelera con papeles pinchados, un reloj y un mapa
		enrollable. Son props que no hacen nada y sostienen media
		ambientacion.
	--]]
	local propColors = {
		Color3.fromRGB(198, 96, 168), Color3.fromRGB(146, 108, 210),
		Color3.fromRGB(226, 104, 88), Color3.fromRGB(96, 164, 214),
		Color3.fromRGB(120, 190, 150), Color3.fromRGB(238, 168, 96),
	}

	-- Estanteria baja contra la pared del atrio, a un costado del vano.
	local shelfZ = cz + doorWidth / 2 + 6
	block(model, "EstanteAula", Vector3.new(1.5, 5, 8),
		CFrame.new(wallX - dir.X * 1.2, 2.5, shelfZ), C.Madera, M.Madera)
	for level = 0, 2 do
		local y = 1.3 + level * 1.5
		local z = shelfZ - 3.4
		local guard = 0
		while z < shelfZ + 3.4 and guard < 40 do
			guard += 1
			local thick = rng:NextNumber(0.18, 0.36)
			local tall = rng:NextNumber(0.9, 1.3)
			decor(model, "Lomo", Vector3.new(1, tall, thick),
				CFrame.new(wallX - dir.X * 1.2, y + tall / 2, z + thick / 2),
				propColors[rng:NextInteger(1, #propColors)], M.MuroAlto)
			z += thick + 0.05
		end
	end

	-- Cartelera con papeles pinchados, del otro lado del vano.
	local boardZ = cz - doorWidth / 2 - 6
	decor(model, "Cartelera", Vector3.new(0.3, 4.5, 7),
		CFrame.new(wallX - dir.X * 0.6, 6.5, boardZ), C.MaderaOscura, M.Madera)
	decor(model, "CarteleraFondo", Vector3.new(0.2, 3.9, 6.4),
		CFrame.new(wallX - dir.X * 0.75, 6.5, boardZ),
		Color3.fromRGB(196, 172, 138), M.Tela)
	for _ = 1, 7 do
		decor(model, "Papel", Vector3.new(0.1, rng:NextNumber(0.9, 1.5),
			rng:NextNumber(0.8, 1.3)),
			CFrame.new(wallX - dir.X * 0.85, 6.5 + rng:NextNumber(-1.4, 1.4),
				boardZ + rng:NextNumber(-2.6, 2.6))
				* CFrame.Angles(rng:NextNumber(-0.1, 0.1), 0, 0),
			C.Pantalla, M.Placa)
	end

	-- Reloj sobre el pizarron.
	local clockFace = decor(model, "Reloj", Vector3.new(0.3, 2.2, 2.2),
		CFrame.new(boardX + dir.X * 0.2, height - 2.4, cz), C.Pantalla, M.Placa)
	decor(model, "RelojMarco", Vector3.new(0.22, 2.6, 2.6),
		clockFace.CFrame * CFrame.new(dir.X * 0.06, 0, 0), C.MaderaOscura, M.Madera)
	for _, hand in { Vector3.new(0.12, 0.14, 0.8), Vector3.new(0.12, 0.6, 0.12) } do
		decor(model, "Aguja", hand,
			clockFace.CFrame * CFrame.new(-dir.X * 0.1, 0.1, 0.2),
			Color3.fromRGB(48, 46, 56), M.MetalLiso)
	end

	-- Mapa enrollable colgado en una pared lateral.
	decor(model, "TuboMapa", Vector3.new(6.5, 0.5, 0.5),
		CFrame.new(cx + 5, height - 1.8, cz + halfL - 0.9), C.MaderaOscura, M.Madera)
	decor(model, "Mapa", Vector3.new(6.2, 4.2, 0.16),
		CFrame.new(cx + 5, height - 4.1, cz + halfL - 0.9),
		Color3.fromRGB(226, 214, 186), M.Placa)

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

-- ── biblioteca ─────────────────────────────────────────────────────

--[[
	La biblioteca, con su seccion secreta.

	Va en `x = -41, z = +18`. No es un lugar arbitrario: las aulas ocupan
	`z ∈ [-37, -7]` a los dos lados del atrio y la zona de recreo
	`z ∈ [41, 75]`, asi que este es el unico hueco pegado al atrio que no
	pisa nada. Comparte pared con el atrio, igual que las aulas.

	Lo que la hace distinta de un cuarto decorativo es el fondo: una
	estanteria que se corre y deja ver una alcoba con la hoja de
	respuestas. El reparto lo hace `ExamService.openStash` — aca solo se
	construye el mueble y se le cuelga el prompt.
--]]
local function buildLibrary(root: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Biblioteca"
	model.Parent = root

	local halfW = E.AulaAncho / 2
	local halfL = E.AulaLargo / 2
	-- Casi el doble que un aula: la biblioteca es de dos plantas y su
	-- altura es la mitad de lo que la hace imponente.
	local height = E.AulaAltura * 1.75
	local cx = -(E.PasilloAncho / 2 + halfW)
	local cz = 18
	local center = Vector3.new(cx, 0, cz)
	-- El atrio queda hacia +X desde aca.
	local toHall = 1

	plankFloor(model, center, E.AulaAncho, E.AulaLargo)
	block(model, "Losa", Vector3.new(E.AulaAncho, 1, E.AulaLargo),
		CFrame.new(cx, height, cz), C.Losa, M.MuroAlto)

	-- Paredes: el fondo y las dos laterales, macizas.
	block(model, "ParedFondo", Vector3.new(E.EspesorPared, height, E.AulaLargo),
		CFrame.new(cx - halfW, height / 2, cz), C.MuroAlto, M.MuroAlto)
	for _, dz in { -1, 1 } do
		block(model, "ParedLateral", Vector3.new(E.AulaAncho, height, E.EspesorPared),
			CFrame.new(cx, height / 2, cz + dz * halfL), C.MuroAlto, M.MuroAlto)
		wainscot(model, CFrame.new(cx, 0, cz + dz * (halfL - 0.55)), E.AulaAncho, "X")
	end

	-- La pared del atrio, con su vano.
	local doorWidth, doorHeight = 6, 8.5
	local wallX = cx + halfW
	local sidePiece = (E.AulaLargo - doorWidth) / 2
	for _, dz in { -1, 1 } do
		block(model, "ParedPasillo", Vector3.new(E.EspesorPared, height, sidePiece),
			CFrame.new(wallX, height / 2, cz + dz * (doorWidth / 2 + sidePiece / 2)),
			C.MuroAlto, M.MuroAlto)
	end
	block(model, "Dintel", Vector3.new(E.EspesorPared, height - doorHeight, doorWidth),
		CFrame.new(wallX, doorHeight + (height - doorHeight) / 2, cz), C.MuroAlto, M.MuroAlto)
	decor(model, "MarcoPuerta", Vector3.new(0.5, doorHeight + 0.4, doorWidth + 0.7),
		CFrame.new(wallX, doorHeight / 2, cz), C.MarcoPuerta, M.MetalLiso)
	sign(model, "BIBLIOTECA", Vector2.new(6.4, 1.4),
		CFrame.new(wallX + toHall * 0.7, doorHeight + 0.9, cz)
			* CFrame.Angles(0, math.rad(-90), 0),
		Enum.NormalId.Front)

	--[[
		Una estanteria: el cuerpo, cuatro estantes y los lomos de los
		libros. Los lomos son laminas finas de colores en la paleta
		saturada; son lo que hace que la sala se lea como biblioteca y no
		como un deposito de cajas.
	--]]
	local spineColors = {
		Color3.fromRGB(198, 96, 168), Color3.fromRGB(146, 108, 210),
		Color3.fromRGB(226, 104, 88), Color3.fromRGB(96, 164, 214),
		Color3.fromRGB(120, 190, 150), Color3.fromRGB(238, 168, 96),
	}

	--[[
		Una estanteria de caoba del piso al techo.

		La version anterior las hacia de 8.5 studs en madera clara, o sea
		muebles bajos en una sala luminosa. En la referencia la
		biblioteca es lo contrario: caoba oscura, de doble altura, con
		los estantes trepando hasta el techo. Es el espacio mas imponente
		del juego y lo que lo hace imponente es justamente la altura.
	--]]
	local function shelf(name: string, cf: CFrame, width: number, tall: number): Model
		local unit = Instance.new("Model")
		unit.Name = name
		unit.Parent = model

		block(unit, "Estante", Vector3.new(width, tall, 1.6), cf * CFrame.new(0, tall / 2, 0),
			C.Caoba, M.Madera)

		local levels = math.max(2, math.floor(tall / 2))
		for level = 1, levels do
			local y = 1.2 + (level - 1) * ((tall - 1.6) / levels)
			if y + 1.7 > tall then
				break
			end
			decor(unit, "Balda", Vector3.new(width - 0.2, 0.16, 1.7),
				cf * CFrame.new(0, y, 0), C.CaobaClara, M.Madera)

			-- Los lomos, apretados uno contra otro sobre cada balda.
			local x = -width / 2 + 0.5
			local guard = 0
			while x < width / 2 - 0.5 and guard < 60 do
				guard += 1
				local thick = rng:NextNumber(0.16, 0.34)
				local tallBook = rng:NextNumber(1, 1.45)
				decor(unit, "Lomo", Vector3.new(thick, tallBook, 1.1),
					cf * CFrame.new(x + thick / 2, y + tallBook / 2 + 0.08, 0),
					spineColors[rng:NextInteger(1, #spineColors)], M.MuroAlto)
				x += thick + 0.04
			end
		end
		return unit
	end

	-- Contra las paredes, del piso al techo.
	for _, dz in { -1, 1 } do
		for i = -1, 1 do
			shelf("Estanteria",
				CFrame.new(cx + i * 10, 0, cz + dz * (halfL - 1.2))
					* CFrame.Angles(0, dz > 0 and math.pi or 0, 0), 8, height - 1)
		end
	end
	-- Islas centrales, mas bajas para no tapar la sala.
	for _, dz in { -6, 6 } do
		shelf("Estanteria", CFrame.new(cx - 5, 0, cz + dz) * CFrame.Angles(0, math.pi / 2, 0),
			12, 9)
	end

	--[[
		El entrepiso: una pasarela angosta contra tres paredes con su
		baranda de balaustres, y una escalera para subir. Es lo que
		convierte la sala en una biblioteca de dos plantas en vez de un
		cuarto alto.
	--]]
	local deckY = height * 0.52
	local deckWidth = 4.5

	for _, dz in { -1, 1 } do
		block(model, "Entrepiso", Vector3.new(E.AulaAncho - 2, 0.5, deckWidth),
			CFrame.new(cx, deckY, cz + dz * (halfL - deckWidth / 2 - 1)), C.Caoba, M.Madera)
	end
	block(model, "Entrepiso", Vector3.new(deckWidth, 0.5, E.AulaLargo - 2 - deckWidth * 2),
		CFrame.new(cx - halfW + deckWidth / 2 + 1, deckY, cz), C.Caoba, M.Madera)

	-- Baranda: pasamanos corrido y balaustres cada stud y medio.
	local function railing(from: Vector3, to: Vector3)
		local span = (to - from).Magnitude
		local middle = from:Lerp(to, 0.5)
		local facing = CFrame.lookAt(middle, to)
		decor(model, "Pasamanos", Vector3.new(0.25, 0.25, span),
			facing * CFrame.new(0, 2.5, 0), C.CaobaClara, M.Madera)
		local count = math.max(2, math.floor(span / 1.5))
		for i = 0, count do
			decor(model, "Balaustre", Vector3.new(0.18, 2.4, 0.18),
				facing * CFrame.new(0, 1.25, -span / 2 + i * (span / count)),
				C.CaobaClara, M.Madera)
		end
	end

	local inner = halfL - deckWidth - 1
	for _, dz in { -1, 1 } do
		railing(Vector3.new(cx - halfW + 1, deckY, cz + dz * inner),
			Vector3.new(cx + halfW - 1, deckY, cz + dz * inner))
	end
	railing(Vector3.new(cx - halfW + deckWidth + 1, deckY, cz - inner),
		Vector3.new(cx - halfW + deckWidth + 1, deckY, cz + inner))

	-- Escalera al entrepiso, contra la pared del atrio.
	local steps = 12
	for i = 1, steps do
		block(model, "Escalon", Vector3.new(4, 0.4, 1.4),
			CFrame.new(cx + halfW - 3, (deckY / steps) * i, cz - halfL + 3 + i * 1.4),
			C.Caoba, M.Madera)
	end

	--[[
		Mesas de lectura con lamparas de banquero: pantalla verde y una
		luz calida adentro. Es el detalle que mas dice "biblioteca" de
		toda la sala — antes eran lamparas doradas genericas.
	--]]
	for _, dz in { -8, 8 } do
		local table_ = block(model, "MesaLectura", Vector3.new(7, 0.3, 3.4),
			CFrame.new(cx + 8, 3.4, cz + dz), C.Caoba, M.Madera)
		for _, dx in { -3, 3 } do
			for _, dd in { -1.4, 1.4 } do
				decor(model, "PataMesa", Vector3.new(0.26, 3.4, 0.26),
					table_.CFrame * CFrame.new(dx, -1.85, dd), C.Caoba, M.MaderaLisa)
			end
		end
		for _, dx in { -2, 2 } do
			decor(model, "PieLampara", Vector3.new(0.22, 0.9, 0.22),
				table_.CFrame * CFrame.new(dx, 0.6, 0), C.Laton, M.MetalLiso)
			local shade = decor(model, "Lampara", Vector3.new(1.9, 0.5, 0.9),
				table_.CFrame * CFrame.new(dx, 1.15, 0), C.PantallaLampara, M.MetalLiso)
			local glow = Instance.new("PointLight")
			glow.Brightness = 1.4
			glow.Range = 16
			glow.Color = C.LuzCalida
			glow.Shadows = false
			glow.Parent = shade
		end
	end

	--[[
		La estanteria movible del fondo y lo que esconde.

		El prompt se llama "Alcoba" y lo engancha `ExamService.bindStashes`
		para repartir las respuestas. Aca se le suma una segunda conexion,
		puramente visual, que corre el mueble y lo devuelve solo: son dos
		conexiones al mismo Triggered y cada una hace lo suyo, sin que la
		presentacion se meta con la mecanica.
	--]]
	local alcoveZ = cz
	local backX = cx - halfW

	block(model, "Alcoba", Vector3.new(3, 5, 8),
		CFrame.new(backX + 1.6, 2.5, alcoveZ), C.MaderaOscura, M.Madera)
	local paper = decor(model, "HojaRespuestas", Vector3.new(1.6, 0.06, 2.2),
		CFrame.new(backX + 1.8, 3.2, alcoveZ), C.Pantalla, M.Placa)
	paper.Color = Color3.fromRGB(250, 248, 238)

	-- Va mas baja que las de pared: tiene que poder correrse por debajo
	-- del entrepiso, y ademas una que llega al techo no se leeria como
	-- un mueble que se mueve.
	local movable = shelf("EstanteriaMovible",
		CFrame.new(backX + 1.5, 0, alcoveZ) * CFrame.Angles(0, math.pi / 2, 0), 8, 9)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Alcoba"
	prompt.ActionText = "Correr"
	prompt.ObjectText = "Estanteria"
	prompt.HoldDuration = 1.4
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	local anchor = movable:FindFirstChild("Estante")
	prompt.Parent = anchor or movable

	local sliding = false
	prompt.Triggered:Connect(function()
		if sliding then
			return
		end
		sliding = true
		local origin = movable:GetPivot()
		local aside = origin * CFrame.new(0, 0, -7)
		local steps = 26
		for i = 1, steps do
			movable:PivotTo(origin:Lerp(aside, i / steps))
			task.wait(0.012)
		end
		task.wait(4)
		for i = 1, steps do
			movable:PivotTo(aside:Lerp(origin, i / steps))
			task.wait(0.012)
		end
		sliding = false
	end)

	-- Techo con luminarias, como el aula.
	dropCeiling(model, center, E.AulaAncho, E.AulaLargo, height - 1.2, 2)

	return model
end

-- ── salas especiales ───────────────────────────────────────────────

--[[
	Un cuarto colgado del atrio, con su vano y su cartel. Es el molde que
	comparten el laboratorio y la sala de computacion: la biblioteca ya
	repetia estas mismas veinte lineas y no habia razon para una tercera
	copia.

	`side` dice de que lado del atrio cuelga y `cz` a que altura.
--]]
local function buildAnnex(root: Instance, name: string, label: string, side: number,
	cz: number, wall: Color3, floorPlanks: boolean): (Model, number, number, number)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = root

	local halfW = E.AulaAncho / 2
	local halfL = E.AulaLargo / 2
	local height = E.AulaAltura
	local cx = side * (E.PasilloAncho / 2 + halfW)
	local center = Vector3.new(cx, 0, cz)
	-- Hacia donde queda el atrio desde este cuarto.
	local toHall = -side

	if floorPlanks then
		plankFloor(model, center, E.AulaAncho, E.AulaLargo)
	else
		tiledFloor(model, center, E.AulaAncho, E.AulaLargo)
	end
	block(model, "Losa", Vector3.new(E.AulaAncho, 1, E.AulaLargo),
		CFrame.new(cx, height, cz), C.Losa, M.MuroAlto)

	block(model, "ParedFondo", Vector3.new(E.EspesorPared, height, E.AulaLargo),
		CFrame.new(cx - toHall * halfW, height / 2, cz), wall, M.MuroAlto)
	for _, dz in { -1, 1 } do
		block(model, "ParedLateral", Vector3.new(E.AulaAncho, height, E.EspesorPared),
			CFrame.new(cx, height / 2, cz + dz * halfL), wall, M.MuroAlto)
		wainscot(model, CFrame.new(cx, 0, cz + dz * (halfL - 0.55)), E.AulaAncho, "X",
			C.MuroAulaBajo, C.MuroAulaBajo)
	end

	local doorWidth, doorHeight = 6, 8.5
	local wallX = cx + toHall * halfW
	local sidePiece = (E.AulaLargo - doorWidth) / 2
	for _, dz in { -1, 1 } do
		block(model, "ParedPasillo", Vector3.new(E.EspesorPared, height, sidePiece),
			CFrame.new(wallX, height / 2, cz + dz * (doorWidth / 2 + sidePiece / 2)),
			wall, M.MuroAlto)
	end
	block(model, "Dintel", Vector3.new(E.EspesorPared, height - doorHeight, doorWidth),
		CFrame.new(wallX, doorHeight + (height - doorHeight) / 2, cz), wall, M.MuroAlto)
	decor(model, "MarcoPuerta", Vector3.new(0.5, doorHeight + 0.4, doorWidth + 0.7),
		CFrame.new(wallX, doorHeight / 2, cz), C.MarcoPuerta, M.MetalLiso)
	sign(model, label, Vector2.new(6.4, 1.4),
		CFrame.new(wallX + toHall * 0.7, doorHeight + 0.9, cz)
			* CFrame.Angles(0, toHall > 0 and math.rad(-90) or math.rad(90), 0),
		Enum.NormalId.Front)

	dropCeiling(model, center, E.AulaAncho, E.AulaLargo, height - 1.2, 2)
	return model, cx, cz, height
end

--[[
	El laboratorio de ciencias: mesadas con equipo y, sobre todo, las
	maquetas de planetas colgando del techo. Ese detalle es lo que lo
	identifica de un vistazo en la referencia.
--]]
local function buildLab(root: Instance)
	local model, cx, cz, height = buildAnnex(root, "Laboratorio", "LABORATORIO",
		1, 18, C.MuroAula, false)

	-- Mesadas con su equipo.
	for _, dz in { -7, 0, 7 } do
		local bench = block(model, "Mesada", Vector3.new(12, 0.4, 3),
			CFrame.new(cx, 3.4, cz + dz), C.MuroAulaBajo, M.MuroAlto)
		for _, dx in { -5, 0, 5 } do
			decor(model, "PataMesada", Vector3.new(0.4, 3.2, 2.6),
				bench.CFrame * CFrame.new(dx, -1.8, 0), C.MaderaOscura, M.MaderaLisa)
		end
		-- Frascos y matraces.
		for i = -2, 2 do
			decor(model, "Frasco", Vector3.new(0.5, rng:NextNumber(0.7, 1.2), 0.5),
				bench.CFrame * CFrame.new(i * 2.2, 0.7, rng:NextNumber(-0.6, 0.6)),
				Color3.fromRGB(168, 214, 200), M.Vidrio).Transparency = 0.4
		end
	end

	--[[
		Los planetas. Cuelgan de un hilo fino a distintas alturas; el mas
		grande lleva sus anillos, que es lo que hace que se lea como un
		sistema solar y no como pelotas sueltas.
	--]]
	local planets = {
		{ size = 2.6, color = Color3.fromRGB(226, 176, 108), rings = true },
		{ size = 3.2, color = Color3.fromRGB(212, 136, 92), rings = false },
		{ size = 1.6, color = Color3.fromRGB(96, 148, 210), rings = false },
		{ size = 1.3, color = Color3.fromRGB(198, 96, 84), rings = false },
	}
	for i, planet in planets do
		local x = cx - 9 + (i - 1) * 6
		local z = cz - 4 + ((i % 2 == 0) and 7 or 0)
		local y = height - 3.4 - (i % 3) * 1.2

		local ball = decor(model, "Planeta",
			Vector3.new(planet.size, planet.size, planet.size),
			CFrame.new(x, y, z), planet.color, M.MuroAlto)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = ball

		decor(model, "Hilo", Vector3.new(0.06, height - y - 0.5, 0.06),
			CFrame.new(x, (y + planet.size / 2 + height) / 2, z),
			Color3.fromRGB(224, 224, 220), M.MetalLiso)

		if planet.rings then
			local ring = decor(model, "Anillo",
				Vector3.new(planet.size * 2.1, 0.12, planet.size * 2.1),
				CFrame.new(x, y, z) * CFrame.Angles(math.rad(18), 0, math.rad(12)),
				Color3.fromRGB(232, 210, 168), M.MuroAlto)
			local ringMesh = Instance.new("SpecialMesh")
			ringMesh.MeshType = Enum.MeshType.Cylinder
			ringMesh.Parent = ring
		end
	end
end

--- La sala de computacion: monitores de tubo en fila sobre las mesas.
local function buildComputerRoom(root: Instance)
	local model, cx, cz = buildAnnex(root, "Computacion", "COMPUTACION",
		-1, -58, C.MuroAula, true)

	for _, dz in { -8, 0, 8 } do
		local bench = block(model, "MesaPC", Vector3.new(13, 0.4, 3.4),
			CFrame.new(cx, 3.4, cz + dz), C.Madera, M.Madera)
		for _, dx in { -5.6, 5.6 } do
			decor(model, "PataMesaPC", Vector3.new(0.4, 3.2, 3),
				bench.CFrame * CFrame.new(dx, -1.8, 0), C.MaderaOscura, M.MaderaLisa)
		end

		for i = -1, 1 do
			local seat = bench.CFrame * CFrame.new(i * 4.4, 0, 0)
			-- Monitor de tubo: cuerpo hondo y pantalla apenas hundida.
			local box = decor(model, "Monitor", Vector3.new(2.4, 2.2, 2.6),
				seat * CFrame.new(0, 1.3, -0.2), Color3.fromRGB(226, 218, 198),
				M.MetalLiso)
			decor(model, "MonitorVidrio", Vector3.new(1.8, 1.5, 0.12),
				box.CFrame * CFrame.new(0, 0.1, 1.34),
				Color3.fromRGB(88, 108, 116), M.MetalLiso)
			decor(model, "Teclado", Vector3.new(2.2, 0.2, 0.9),
				seat * CFrame.new(0, 0.3, 1.3), Color3.fromRGB(214, 208, 190),
				M.MetalLiso)
		end
	end
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

--[[
	El exterior. No es decoracion gratuita: el aula tiene un ventanal de
	verdad, y sin nada afuera se ve el vacio celeste del skybox y el
	efecto se cae. Con un prado, una franja de agua y unas colinas
	lejanas, la ventana pasa a tener profundidad.

	Todo es `CanCollide = false` y esta lejisimos: no se puede llegar
	caminando y no interfiere con nada del juego.
--]]
local function buildOutdoors(root: Instance)
	local outside = Instance.new("Model")
	outside.Name = "Exterior"
	outside.Parent = root

	local ground = decor(outside, "Prado", Vector3.new(2400, 2, 2400),
		CFrame.new(0, -1, 0), Color3.fromRGB(142, 190, 118), M.MuroAlto)
	ground.CastShadow = false

	-- Franja de agua a media distancia.
	local water = decor(outside, "Agua", Vector3.new(2400, 1, 500),
		CFrame.new(0, -0.4, -700), Color3.fromRGB(104, 176, 214), M.MuroAlto)
	water.CastShadow = false

	-- Colinas: esferas achatadas, repartidas en un arco lejano para que
	-- cualquier ventana del instituto de a algo.
	local hills = Random.new(90210)
	for i = 1, 14 do
		local angle = (i / 14) * math.pi * 2
		local distance = hills:NextNumber(760, 1080)
		local scale = hills:NextNumber(120, 260)
		local hill = decor(outside, "Colina",
			Vector3.new(scale * 2.2, scale, scale * 2.2),
			CFrame.new(math.cos(angle) * distance, -scale * 0.28,
				math.sin(angle) * distance),
			Color3.fromRGB(112, 158, 106):Lerp(Color3.fromRGB(148, 176, 196),
				hills:NextNumber(0, 0.55)),
			M.MuroAlto)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = hill
		hill.CastShadow = false
	end
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

	safely("biblioteca", function()
		buildLibrary(root)
	end)
	safely("laboratorio", function()
		buildLab(root)
	end)
	safely("sala de computacion", function()
		buildComputerRoom(root)
	end)

	local detention = buildDetention(root)

	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	-- El paisaje que se ve por el ventanal del aula.
	safely("exterior", function()
		buildOutdoors(root)
	end)

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

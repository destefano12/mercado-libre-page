--!strict
--[[
	ClassroomAsset
	------------------------------------------------------------------
	Trae un aula del catalogo de Roblox y la usa de escenario, en lugar
	de la que construye ClassroomBuilder por codigo.

	Dos caminos, en este orden:

		1. Si ya hay un modelo insertado en Workspace (por vos, desde el
		   Toolbox), lo usa. Alcanza con que se llame "AulaImportada" o
		   que tenga "classroom" o "aula" en el nombre.
		2. Si no, lo pide con InsertService:LoadAsset(AssetId).

	Si los dos fallan, devuelve nil y el juego construye el aula de
	siempre. Nunca se queda sin aula.

	Lo que no puede adivinar: donde estan el pizarron y el frente del
	aula del modelo. Por eso los bancos se ubican con los numeros de
	Config.Classroom (AssetRotation y AssetOffset): si quedan mirando
	para el lado equivocado, se corrigen ahi y listo.
--]]

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local ClassroomAsset = {}

local C = Config.Classroom

local function countParts(model: Model): number
	local total = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			total += 1
		end
	end
	return total
end

--- Reconoce un aula insertada a mano, se llame como se llame. Por
--- nombre primero, y si no, por forma: un modelo grande, con muchas
--- partes y sin Humanoid es un edificio, no un personaje.
local function looksLikeClassroom(instance: Instance): boolean
	if not instance:IsA("Model") or instance.Name == "Aula" then
		return false
	end
	if instance:FindFirstChildOfClass("Humanoid") then
		return false
	end

	local name = string.lower(instance.Name)
	if name == "aulaimportada" or string.find(name, "classroom") or string.find(name, "aula") then
		return true
	end

	if countParts(instance) < 20 then
		return false
	end
	local ok, _, dimensions = pcall(function()
		return instance:GetBoundingBox()
	end)
	return ok and dimensions ~= nil and dimensions.X >= 35 and dimensions.Z >= 35
end

local function findInserted(): Model?
	for _, instance in workspace:GetChildren() do
		if looksLikeClassroom(instance) then
			return instance :: Model
		end
	end
	return nil
end

local function loadFromCatalog(): Model?
	if C.AssetId == 0 then
		return nil
	end

	local ok, result = pcall(function()
		return InsertService:LoadAsset(C.AssetId)
	end)
	if not ok or not result then
		warn(string.format(
			"[Aula] No se pudo bajar el modelo %d: %s\n"
				.. "       Insertalo a mano desde el Toolbox y llamalo \"AulaImportada\": "
				.. "el juego lo va a usar igual.",
			C.AssetId, tostring(result)))
		return nil
	end

	-- LoadAsset devuelve un contenedor con el modelo adentro.
	local model = result:FindFirstChildOfClass("Model")
	if not model then
		result:Destroy()
		return nil
	end
	model.Parent = workspace
	result:Destroy()
	return model
end

--- Deja el modelo apoyado en el piso, centrado donde queremos y anclado.
local function place(model: Model): Vector3
	-- Todo anclado: un aula del catalogo puede venir con partes sueltas
	-- que se desarman apenas arranca la fisica.
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end

	-- Primero se gira, despues se mueve: al reves el giro corre la caja.
	if C.AssetRotation ~= 0 then
		model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.rad(C.AssetRotation), 0))
	end

	local box, size = model:GetBoundingBox()
	local goal = Vector3.new(C.AssetOffset.Position.X, size.Y / 2, C.AssetOffset.Position.Z)
	model:PivotTo(model:GetPivot() + (goal - box.Position))

	return size
end

--- Saca los bancos y sillas que traiga el modelo: los nuestros son los
--- que tienen hoja, asiento y logica.
local function clearFurniture(model: Model)
	if not C.HideAssetFurniture then
		return
	end
	local patterns = { "desk", "chair", "table", "stool", "seat", "banco", "silla", "pupitre", "mesa" }
	for _, descendant in model:GetDescendants() do
		local name = string.lower(descendant.Name)
		for _, pattern in patterns do
			if string.find(name, pattern) then
				if descendant:IsA("Model") or descendant:IsA("BasePart") then
					descendant:Destroy()
				end
				break
			end
		end
	end
end

--- Un nombre que suene a aula de matematica, mirando el asiento y todo
--- lo que lo contiene.
local function inMathRoom(seat: Instance): boolean
	local node: Instance? = seat
	local depth = 0
	while node and depth < 8 do
		local name = string.lower(node.Name)
		if string.find(name, "math") or string.find(name, "matem")
			or string.find(name, "classroom") or string.find(name, "aula") then
			return true
		end
		node = node.Parent
		depth += 1
	end
	return false
end

--- Agrupa asientos que estan cerca entre si: cada grupo es una sala.
local function cluster(seats: { Seat }, radius: number): { { Seat } }
	local groups: { { Seat } } = {}
	local taken: { [Seat]: boolean } = {}

	for _, seat in seats do
		if not taken[seat] then
			-- Crece el grupo por vecindad, tipo mancha de aceite.
			local group = { seat }
			taken[seat] = true
			local index = 1
			while index <= #group do
				local current = group[index]
				for _, other in seats do
					if not taken[other] and (other.Position - current.Position).Magnitude <= radius then
						taken[other] = true
						table.insert(group, other)
					end
				end
				index += 1
			end
			table.insert(groups, group)
		end
	end

	return groups
end

local function footprint(group: { Seat }): number
	local minX, maxX = math.huge, -math.huge
	local minZ, maxZ = math.huge, -math.huge
	for _, seat in group do
		minX = math.min(minX, seat.Position.X)
		maxX = math.max(maxX, seat.Position.X)
		minZ = math.min(minZ, seat.Position.Z)
		maxZ = math.max(maxZ, seat.Position.Z)
	end
	return math.max(maxX - minX, maxZ - minZ)
end

--- Los asientos del AULA, no los de la tribuna.
---
--- Una escuela entera puede tener cientos de asientos: gradas, salon de
--- actos, comedor. Si los agarramos todos, la prueba termina rindiendose
--- en un estadio. Asi que se agrupan por cercania y se elige el grupo
--- que se parece a un aula: pocos asientos y juntos.
---
--- Si en tu escuela hay una parte llamada "AulaDeMatematica", gana esa
--- sin discusion: es la forma de decidirlo vos en diez segundos.
function ClassroomAsset.findSeats(model: Model): { Seat }
	local all: { Seat } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Seat") then
			table.insert(all, descendant)
		end
	end
	if #all == 0 then
		return all
	end

	-- 1. Marcador puesto a mano: manda sobre todo lo demas.
	local marker = workspace:FindFirstChild(C.RoomMarkerName, true)
	if marker and marker:IsA("BasePart") then
		local picked: { Seat } = {}
		for _, seat in all do
			if (seat.Position - marker.Position).Magnitude <= C.RoomMarkerRadius then
				table.insert(picked, seat)
			end
		end
		if #picked > 0 then
			print(string.format("[Aula] %d asientos alrededor de %q.", #picked, C.RoomMarkerName))
			return picked
		end
	end

	-- 2. Por nombre: si algo se llama "math" o "classroom", es ese.
	local named: { Seat } = {}
	for _, seat in all do
		if inMathRoom(seat) then
			table.insert(named, seat)
		end
	end
	if #named >= 2 then
		print(string.format("[Aula] %d asientos en una sala que se llama como un aula.", #named))
		return named
	end

	-- 3. Por forma: el grupo mas parecido a un aula gana.
	local best: { Seat }? = nil
	local bestScore = -math.huge
	for _, group in cluster(all, C.SeatClusterRadius) do
		local count = #group
		local spread = footprint(group)

		-- Un aula tiene entre 6 y 40 bancos y entra en unos 60 studs.
		-- Una tribuna tiene muchos mas y ocupa el doble o el triple.
		local score = 0
		score += (count >= 6 and count <= 40) and 40 or -math.abs(count - 20)
		score -= math.max(0, spread - 60) * 0.6
		score += math.min(count, 30)

		if score > bestScore then
			bestScore, best = score, group
		end
	end

	if best then
		print(string.format("[Aula] Elegida la sala de %d asientos (%.0f studs de ancho) entre %d asientos de toda la escuela.",
			#best, footprint(best), #all))
		return best
	end
	return all
end

--- Muebles que parecen bancos: el plan B cuando el aula no trae Seats.
function ClassroomAsset.findDeskParts(model: Model): { BasePart }
	local matches: { BasePart } = {}
	local patterns = { "desk", "pupitre", "banco", "table", "mesa" }

	for _, descendant in model:GetDescendants() do
		local name = string.lower(descendant.Name)
		local hit = false
		for _, pattern in patterns do
			if string.find(name, pattern) then
				hit = true
				break
			end
		end
		if hit then
			local part = if descendant:IsA("BasePart")
				then descendant :: BasePart
				elseif descendant:IsA("Model") then descendant.PrimaryPart or descendant:FindFirstChildWhichIsA("BasePart")
				else nil
			-- Una mesa es ancha y baja: descarta paredes y pisos enteros.
			if part and part.Size.X < 12 and part.Size.Z < 12 and part.Size.Y < 6 then
				table.insert(matches, part)
			end
		end
	end
	return matches
end

function ClassroomAsset.clearFurniture(model: Model)
	clearFurniture(model)
end

--- Devuelve el modelo, su tamaño y su centro. Un aula insertada a mano
--- NO se mueve: se respeta donde la pusiste y los bancos van ahi.
function ClassroomAsset.load(): (Model?, Vector3?, Vector3?)
	if not C.UseAsset then
		return nil, nil, nil
	end

	local model = findInserted()
	local fromCatalog = false
	if not model then
		model = loadFromCatalog()
		fromCatalog = true
	end
	if not model then
		return nil, nil, nil
	end

	local ok, err = pcall(function()
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
			end
		end
		-- Solo se acomoda la que bajamos nosotros: cae en cualquier lado.
		if fromCatalog then
			place(model)
		end
	end)
	if not ok then
		warn("[Aula] El modelo importado no se pudo preparar: " .. tostring(err))
		return nil, nil, nil
	end

	local box, size = model:GetBoundingBox()

	print(string.format("[Aula] Usando el aula importada \"%s\" (%s): %.0f x %.0f studs, %d asientos propios.",
		model.Name, fromCatalog and "del catalogo" or "puesta por vos",
		size.X, size.Z, #ClassroomAsset.findSeats(model)))

	return model, size, box.Position
end

return ClassroomAsset

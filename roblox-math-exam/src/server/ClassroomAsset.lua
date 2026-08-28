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

--- Los asientos que ya trae el aula. Si los tiene, son la mejor guia
--- que hay: nos dicen donde se sienta cada alumno Y para donde mira,
--- que es justo lo que el codigo no puede adivinar solo.
function ClassroomAsset.findSeats(model: Model): { Seat }
	local seats: { Seat } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Seat") then
			table.insert(seats, descendant)
		end
	end
	return seats
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

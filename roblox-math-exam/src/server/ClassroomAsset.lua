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

local function looksLikeClassroom(instance: Instance): boolean
	if not instance:IsA("Model") or instance.Name == "Aula" then
		return false
	end
	local name = string.lower(instance.Name)
	return name == "aulaimportada"
		or string.find(name, "classroom") ~= nil
		or string.find(name, "aula") ~= nil
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

--- Devuelve el modelo ya puesto y su tamaño, o nil si no hay ninguno.
function ClassroomAsset.load(): (Model?, Vector3?)
	if not C.UseAsset then
		return nil, nil
	end

	local model = findInserted()
	local fromCatalog = false
	if not model then
		model = loadFromCatalog()
		fromCatalog = true
	end
	if not model then
		return nil, nil
	end

	model.Name = "AulaImportada"

	local ok, size = pcall(function()
		clearFurniture(model)
		local dimensions = place(model)
		return dimensions
	end)
	if not ok then
		warn("[Aula] El modelo importado no se pudo acomodar: " .. tostring(size))
		model:Destroy()
		return nil, nil
	end

	print(string.format("[Aula] Usando el aula importada (%s), %.0f x %.0f studs.",
		fromCatalog and "del catalogo" or "ya insertada",
		(size :: Vector3).X, (size :: Vector3).Z))

	return model, size :: Vector3
end

return ClassroomAsset

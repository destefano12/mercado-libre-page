--!strict
--[[
	Templates
	------------------------------------------------------------------
	Las plantillas de las herramientas equipables viven en
	ReplicatedStorage/Templates: el cliente necesita verlas para
	dibujar la tienda y el inventario, y el servidor las clona cuando
	un alumno saca algo del casillero o lo compra.

	Ninguna plantilla lleva logica adentro: todo lo decide el servidor
	(ItemService). Aca solo esta la forma.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Templates = {}

local FOLDER = "Templates"

local function handle(tool: Tool, size: Vector3, color: Color3, material: Enum.Material,
	shape: Enum.PartType?): BasePart
	local part = Instance.new("Part")
	part.Name = "Handle"
	part.Size = size
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		part.Shape = shape
	end
	part.Parent = tool
	return part
end

local function tool(name: string, itemId: string): Tool
	local instance = Instance.new("Tool")
	instance.Name = name
	instance.RequiresHandle = true
	instance.CanBeDropped = false
	instance.ManualActivationOnly = false
	instance:SetAttribute("Item", itemId)
	return instance
end

--- Papel doblado: se escribe y se lanza.
local function buildNota(): Tool
	local item = tool("Nota", "nota")
	local body = handle(item, Vector3.new(0.9, 0.12, 0.7), Color3.fromRGB(250, 248, 240),
		Enum.Material.SmoothPlastic)
	body.Name = "Handle"

	local fold = Instance.new("Part")
	fold.Name = "Pliegue"
	fold.Size = Vector3.new(0.9, 0.05, 0.16)
	fold.Color = Color3.fromRGB(226, 222, 210)
	fold.Material = Enum.Material.SmoothPlastic
	fold.CanCollide = false
	fold.CFrame = body.CFrame * CFrame.new(0, 0.08, 0)
	fold.Parent = item
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = fold
	weld.Parent = body

	local text = Instance.new("StringValue")
	text.Name = "Texto"
	text.Value = ""
	text.Parent = item

	item:SetAttribute("Lanzable", true)
	item:SetAttribute("Alcance", 1)
	item.Grip = CFrame.new(0, -0.1, 0)
	return item
end

--- Avioncito: vuela mas lejos y mas derecho.
local function buildAvion(): Tool
	local item = tool("Avion", "avion")
	local wedge = Instance.new("WedgePart")
	wedge.Name = "Handle"
	wedge.Size = Vector3.new(0.25, 0.4, 1.6)
	wedge.Color = Color3.fromRGB(248, 246, 238)
	wedge.Material = Enum.Material.SmoothPlastic
	wedge.CanCollide = false
	wedge.Parent = item

	for _, side in { -1, 1 } do
		local wing = Instance.new("WedgePart")
		wing.Name = "Ala"
		wing.Size = Vector3.new(0.08, 0.5, 1.3)
		wing.Color = Color3.fromRGB(240, 238, 230)
		wing.Material = Enum.Material.SmoothPlastic
		wing.CanCollide = false
		wing.CFrame = wedge.CFrame * CFrame.new(side * 0.45, -0.05, -0.1)
			* CFrame.Angles(0, 0, math.rad(side * 22))
		wing.Parent = item
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = wedge
		weld.Part1 = wing
		weld.Parent = wedge
	end

	local text = Instance.new("StringValue")
	text.Name = "Texto"
	text.Value = ""
	text.Parent = item

	item:SetAttribute("Lanzable", true)
	item:SetAttribute("Alcance", Config.Objetos.AvionMultiplicador)
	item.Grip = CFrame.new(0, 0, 0.3)
	return item
end

--- Bolita de papel: hace ruido donde cae y el profe va a mirar.
local function buildBolita(): Tool
	local item = tool("Bolita", "bolita")
	local ball = handle(item, Vector3.new(0.6, 0.6, 0.6), Color3.fromRGB(244, 242, 234),
		Enum.Material.Plastic, Enum.PartType.Ball)
	ball.Reflectance = 0.02
	item:SetAttribute("Lanzable", true)
	item:SetAttribute("Alcance", 1)
	item:SetAttribute("Ruido", Config.Objetos.BolitaRuido)
	return item
end

--- Chuleta: no se lanza, se usa y revela respuestas.
local function buildChuleta(): Tool
	local item = tool("Chuleta", "chuleta")
	local strip = handle(item, Vector3.new(1.3, 0.06, 0.4), Color3.fromRGB(252, 250, 236),
		Enum.Material.SmoothPlastic)

	local ink = Instance.new("SurfaceGui")
	ink.Face = Enum.NormalId.Top
	ink.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	ink.PixelsPerStud = 90
	ink.Parent = strip
	local scribble = Instance.new("TextLabel")
	scribble.Size = UDim2.fromScale(1, 1)
	scribble.BackgroundTransparency = 1
	scribble.Font = Enum.Font.Code
	scribble.Text = "1B 2A 3D 4C"
	scribble.TextColor3 = Color3.fromRGB(40, 60, 130)
	scribble.TextScaled = true
	scribble.Parent = ink

	item:SetAttribute("Lanzable", false)
	item:SetAttribute("Usos", Config.Objetos.ChuletaUsos)
	item.Grip = CFrame.new(0, -0.05, 0)
	return item
end

local BUILDERS: { [string]: () -> Tool } = {
	nota = buildNota,
	avion = buildAvion,
	bolita = buildBolita,
	chuleta = buildChuleta,
}

function Templates.folder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(FOLDER)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	folder.Parent = ReplicatedStorage
	return folder
end

function Templates.build()
	local folder = Templates.folder()
	folder:ClearAllChildren()
	for id, builder in BUILDERS do
		local ok, result = pcall(builder)
		if ok and result then
			result.Parent = folder
		else
			warn(string.format("[Templates] %q fallo: %s", id, tostring(result)))
		end
	end
	print(string.format("[Templates] %d herramientas listas.", #folder:GetChildren()))
end

--- Un clon nuevo de la plantilla de `itemId`, o nil si no existe.
function Templates.clone(itemId: string): Tool?
	local folder = Templates.folder()
	for _, child in folder:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("Item") == itemId then
			return child:Clone()
		end
	end
	return nil
end

--- Los ids de objeto que se pueden llevar en la mano (no esteticos).
function Templates.usableIds(): { string }
	local ids = {}
	for _, entry in Config.Economia.Tienda do
		if entry.tipo == "objeto" then
			table.insert(ids, entry.id :: string)
		end
	end
	return ids
end

return Templates

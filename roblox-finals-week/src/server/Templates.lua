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

local function makeTool(name: string, itemId: string): Tool
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
	local item = makeTool("Nota", "nota")
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
	local item = makeTool("Avion", "avion")
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
	local item = makeTool("Bolita", "bolita")
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
	local item = makeTool("Chuleta", "chuleta")
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

--- Walkie-talkie: habla con todos los walkies del colegio.
local function buildWalkie(): Tool
	local item = makeTool("Walkie", "walkie")
	local body = handle(item, Vector3.new(0.55, 1.5, 0.38), Color3.fromRGB(32, 34, 40),
		Enum.Material.SmoothPlastic)

	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3,
		material: Enum.Material)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = material
		part.CanCollide = false
		part.Massless = true
		part.CFrame = body.CFrame * offset
		part.Parent = item
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = part
		weld.Parent = body
	end

	piece("Antena", Vector3.new(0.1, 0.9, 0.1), CFrame.new(0.18, 1.1, 0),
		Color3.fromRGB(18, 18, 22), Enum.Material.SmoothPlastic)
	piece("Rejilla", Vector3.new(0.4, 0.4, 0.06), CFrame.new(0, 0.42, -0.22),
		Color3.fromRGB(58, 62, 70), Enum.Material.DiamondPlate)
	piece("Luz", Vector3.new(0.12, 0.12, 0.06), CFrame.new(-0.16, 0.66, -0.22),
		Color3.fromRGB(94, 232, 122), Enum.Material.Neon)

	item:SetAttribute("Lanzable", false)
	item:SetAttribute("Radio", "walkie")
	item.Grip = CFrame.new(0, -0.2, 0)
	return item
end

--- Prismaticos: acercan la imagen y dejan leer una hoja de lejos.
local function buildPrismaticos(): Tool
	local item = makeTool("Prismaticos", "prismaticos")
	local body = handle(item, Vector3.new(1.05, 0.55, 0.7), Color3.fromRGB(28, 30, 36),
		Enum.Material.SmoothPlastic)

	for _, side in { -1, 1 } do
		local barrel = Instance.new("Part")
		barrel.Name = "Tubo"
		barrel.Shape = Enum.PartType.Cylinder
		barrel.Size = Vector3.new(0.8, 0.48, 0.48)
		barrel.Color = Color3.fromRGB(22, 24, 30)
		barrel.Material = Enum.Material.Metal
		barrel.CanCollide = false
		barrel.Massless = true
		barrel.CFrame = body.CFrame * CFrame.new(side * 0.27, 0, -0.1)
			* CFrame.Angles(0, math.rad(90), 0)
		barrel.Parent = item
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = barrel
		weld.Parent = body

		local lens = Instance.new("Part")
		lens.Name = "Lente"
		lens.Shape = Enum.PartType.Cylinder
		lens.Size = Vector3.new(0.06, 0.4, 0.4)
		lens.Color = Color3.fromRGB(150, 200, 232)
		lens.Material = Enum.Material.Glass
		lens.CanCollide = false
		lens.Massless = true
		lens.CFrame = body.CFrame * CFrame.new(side * 0.27, 0, -0.5)
			* CFrame.Angles(0, math.rad(90), 0)
		lens.Parent = item
		local lensWeld = Instance.new("WeldConstraint")
		lensWeld.Part0 = body
		lensWeld.Part1 = lens
		lensWeld.Parent = body
	end

	item:SetAttribute("Lanzable", false)
	item:SetAttribute("Zoom", true)
	item.Grip = CFrame.new(0, -0.15, 0.2)
	return item
end

--- Celular: le sopla una respuesta a UN companero cercano.
local function buildCelular(): Tool
	local item = makeTool("Celular", "celular")
	local body = handle(item, Vector3.new(0.62, 1.24, 0.09), Color3.fromRGB(22, 24, 30),
		Enum.Material.SmoothPlastic)

	local screen = Instance.new("Part")
	screen.Name = "Pantalla"
	screen.Size = Vector3.new(0.54, 1.08, 0.03)
	screen.Color = Color3.fromRGB(96, 168, 240)
	screen.Material = Enum.Material.Neon
	screen.CanCollide = false
	screen.Massless = true
	screen.CFrame = body.CFrame * CFrame.new(0, 0.04, -0.06)
	screen.Parent = item
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = screen
	weld.Parent = body

	item:SetAttribute("Lanzable", false)
	item:SetAttribute("Radio", "celular")
	item.Grip = CFrame.new(0, -0.1, 0)
	return item
end

--- Libro de texto: leerlo en el recreo te ensena respuestas de verdad.
local function buildLibro(): Tool
	local item = makeTool("Libro", "libro")
	local cover = handle(item, Vector3.new(1.5, 2, 0.34), Color3.fromRGB(126, 44, 52),
		Enum.Material.Fabric)

	local pages = Instance.new("Part")
	pages.Name = "Hojas"
	pages.Size = Vector3.new(1.42, 1.9, 0.3)
	pages.Color = Color3.fromRGB(246, 244, 234)
	pages.Material = Enum.Material.SmoothPlastic
	pages.CanCollide = false
	pages.Massless = true
	pages.CFrame = cover.CFrame * CFrame.new(0.06, 0, 0)
	pages.Parent = item
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = cover
	weld.Part1 = pages
	weld.Parent = cover

	item:SetAttribute("Lanzable", false)
	item:SetAttribute("Libro", true)
	item.Grip = CFrame.new(0, -0.3, 0)
	return item
end

--- Aerosol: pinta cualquier pared marcada como pintable.
local function buildAerosol(): Tool
	local item = makeTool("Aerosol", "aerosol")
	local can = handle(item, Vector3.new(0.55, 1.4, 0.55), Color3.fromRGB(210, 66, 66),
		Enum.Material.Metal, Enum.PartType.Cylinder)
	-- Un cilindro nace acostado sobre X: se lo pone de pie.
	can.Size = Vector3.new(1.4, 0.55, 0.55)
	can.CFrame = can.CFrame * CFrame.Angles(0, 0, math.rad(90))

	local cap = Instance.new("Part")
	cap.Name = "Boquilla"
	cap.Size = Vector3.new(0.22, 0.24, 0.22)
	cap.Color = Color3.fromRGB(238, 238, 232)
	cap.Material = Enum.Material.SmoothPlastic
	cap.CanCollide = false
	cap.Massless = true
	cap.CFrame = can.CFrame * CFrame.new(0.82, 0, 0)
	cap.Parent = item
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = can
	weld.Part1 = cap
	weld.Parent = can

	item:SetAttribute("Lanzable", false)
	item:SetAttribute("Pintar", true)
	item.Grip = CFrame.new(0, -0.2, 0)
	return item
end

local BUILDERS: { [string]: () -> Tool } = {
	nota = buildNota,
	avion = buildAvion,
	bolita = buildBolita,
	chuleta = buildChuleta,
	walkie = buildWalkie,
	prismaticos = buildPrismaticos,
	celular = buildCelular,
	libro = buildLibro,
	aerosol = buildAerosol,
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

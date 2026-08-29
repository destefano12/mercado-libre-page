--!strict
--[[
	GraffitiService
	------------------------------------------------------------------
	Pintar en las paredes del colegio.

	El truco: cada superficie pintable lleva un SurfaceGui con un Frame
	vacio adentro, y cada pincelada es un circulito (Frame + UICorner)
	posicionado en coordenadas de escala. Eso quiere decir que el
	dibujo se replica solo, se ve igual para todos y no necesita
	EditableImage ni ningun asset subido.

	Lo unico que manda el cliente es una DIRECCION y que color/tamano
	eligio. El servidor tira el rayo, decide contra que pego, calcula
	las coordenadas UV de esa cara y estampa. Asi nadie puede pintar
	del otro lado del mapa ni sobre una superficie que no toca.

	Convencion de caras: mirando una cara desde afuera, la "derecha"
	del SurfaceGui no siempre es +X. Esta tabla es la parte que hay que
	acertar si o si; esta derivada, no adivinada:

		Front  (-Z)   derecha = -X    alto = Y
		Back   (+Z)   derecha = +X    alto = Y
		Right  (+X)   derecha = -Z    alto = Y
		Left   (-X)   derecha = +Z    alto = Y
		Top    (+Y)   derecha = +X    alto = Z (hacia +Z)
		Bottom (-Y)   derecha = +X    alto = Z (hacia -Z)
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local G = Config.Grafiti

local GraffitiService = {}

local ATRIBUTO = "Pintable"
local CANVAS = "Grafiti"

local budget: { [Player]: number } = {}
local lastTick: { [Player]: number } = {}

-- ── caras ──────────────────────────────────────────────────────────

type Face = {
	id: Enum.NormalId,
	-- (u, v) a partir de la posicion local; ancho y alto en studs
	uv: (Vector3, Vector3) -> (number, number),
	extent: (Vector3) -> (number, number),
}

local FACES: { Face } = {
	{
		id = Enum.NormalId.Front,
		uv = function(p, s) return (s.X / 2 - p.X) / s.X, (s.Y / 2 - p.Y) / s.Y end,
		extent = function(s) return s.X, s.Y end,
	},
	{
		id = Enum.NormalId.Back,
		uv = function(p, s) return (p.X + s.X / 2) / s.X, (s.Y / 2 - p.Y) / s.Y end,
		extent = function(s) return s.X, s.Y end,
	},
	{
		id = Enum.NormalId.Right,
		uv = function(p, s) return (s.Z / 2 - p.Z) / s.Z, (s.Y / 2 - p.Y) / s.Y end,
		extent = function(s) return s.Z, s.Y end,
	},
	{
		id = Enum.NormalId.Left,
		uv = function(p, s) return (p.Z + s.Z / 2) / s.Z, (s.Y / 2 - p.Y) / s.Y end,
		extent = function(s) return s.Z, s.Y end,
	},
	{
		id = Enum.NormalId.Top,
		uv = function(p, s) return (p.X + s.X / 2) / s.X, (p.Z + s.Z / 2) / s.Z end,
		extent = function(s) return s.X, s.Z end,
	},
	{
		id = Enum.NormalId.Bottom,
		uv = function(p, s) return (p.X + s.X / 2) / s.X, (s.Z / 2 - p.Z) / s.Z end,
		extent = function(s) return s.X, s.Z end,
	},
}

-- Normales locales de cada cara, en el mismo orden que FACES.
local NORMALS = {
	Vector3.new(0, 0, -1),
	Vector3.new(0, 0, 1),
	Vector3.new(1, 0, 0),
	Vector3.new(-1, 0, 0),
	Vector3.new(0, 1, 0),
	Vector3.new(0, -1, 0),
}

--- Que cara es la que mira hacia `worldNormal`.
local function faceFromNormal(part: BasePart, worldNormal: Vector3): Face?
	local local_ = part.CFrame:VectorToObjectSpace(worldNormal)
	local best, bestDot = nil, 0.5
	for index, normal in NORMALS do
		local dot = normal:Dot(local_)
		if dot > bestDot then
			bestDot = dot
			best = FACES[index]
		end
	end
	return best
end

-- ── lienzo ─────────────────────────────────────────────────────────

function GraffitiService.markPaintable(part: BasePart)
	part:SetAttribute(ATRIBUTO, true)
end

local function canvasName(face: Face): string
	return CANVAS .. face.id.Name
end

local function ensureCanvas(part: BasePart, face: Face): Frame
	local existing = part:FindFirstChild(canvasName(face))
	if existing and existing:IsA("SurfaceGui") then
		return existing:FindFirstChild("Lienzo") :: Frame
	end

	local width, height = face.extent(part.Size)

	local gui = Instance.new("SurfaceGui")
	gui.Name = canvasName(face)
	gui.Face = face.id
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	-- Pocos pixeles por stud: las paredes son enormes y no hace falta
	-- resolucion, hace falta que no se coma la memoria del cliente.
	gui.PixelsPerStud = G.PixelesPorStud
	gui.LightInfluence = 0.6
	gui.AlwaysOnTop = false
	gui.MaxDistance = 140
	gui.ZOffset = 0.02
	gui.Parent = part

	local canvas = Instance.new("Frame")
	canvas.Name = "Lienzo"
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.BackgroundTransparency = 1
	canvas.BorderSizePixel = 0
	canvas.ClipsDescendants = true
	canvas:SetAttribute("Siguiente", 0)
	canvas:SetAttribute("Ancho", width)
	canvas:SetAttribute("Alto", height)
	canvas.Parent = gui

	return canvas
end

--- Estampa un punto. Cuando se pasa del maximo, borra el mas viejo:
--- una pared se puede repintar para siempre sin que el cliente muera.
local function stamp(canvas: Frame, u: number, v: number, color: Color3, pixels: number)
	local index = (canvas:GetAttribute("Siguiente") :: number) + 1
	canvas:SetAttribute("Siguiente", index)

	local old = canvas:FindFirstChild("D" .. (index - G.MaximoPorSuperficie))
	if old then
		old:Destroy()
	end

	local dot = Instance.new("Frame")
	dot.Name = "D" .. index
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(u, v)
	dot.Size = UDim2.fromOffset(pixels, pixels)
	dot.BackgroundColor3 = color
	dot.BorderSizePixel = 0
	dot.ZIndex = 1 + (index % 3)
	dot.Parent = canvas

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot
end

-- ── presupuesto por jugador ────────────────────────────────────────

--- Cubeta simple: se rellena con el tiempo y cada pincelada gasta uno.
--- Sin esto, un cliente modificado pinta mil puntos por segundo.
local function spend(player: Player): boolean
	local now = os.clock()
	local last = lastTick[player] or now
	lastTick[player] = now

	local available = math.min(G.PuntosPorSegundo,
		(budget[player] or G.PuntosPorSegundo) + (now - last) * G.PuntosPorSegundo)
	if available < 1 then
		budget[player] = available
		return false
	end
	budget[player] = available - 1
	return true
end

-- ── entrada ────────────────────────────────────────────────────────

local paintParams = RaycastParams.new()
paintParams.FilterType = Enum.RaycastFilterType.Exclude

--- Se llama con cada pincelada. Devuelve por que no se pudo, si fallo.
function GraffitiService.paint(player: Player, direction: any, colorIndex: any, sizeIndex: any): any
	if not G.Habilitado then
		return { ok = false }
	end
	if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.05 then
		return { ok = false }
	end

	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return { ok = false }
	end
	if not spend(player) then
		return { ok = false }
	end

	local color = G.Paleta[math.clamp(tonumber(colorIndex) or 1, 1, #G.Paleta)]
	-- El grosor viene en studs y se convierte a pixeles del lienzo:
	-- asi una brocha mide lo mismo en una pared de 190 studs que en la
	-- puerta de un casillero de 3.
	local studs = G.Tamanos[math.clamp(tonumber(sizeIndex) or 2, 1, #G.Tamanos)]
	local pixels = math.max(2, math.round(studs * G.PixelesPorStud))

	paintParams.FilterDescendantsInstances = {
		character,
		workspace:FindFirstChild("Proyectiles") :: any,
		workspace:FindFirstChild("Personajes") :: any,
	}
	local hit = workspace:Raycast(head.Position, direction.Unit * G.Alcance, paintParams)
	if not hit or not hit.Instance:IsA("BasePart") then
		return { ok = false, reason = { key = "paint.wall" } }
	end

	local part = hit.Instance
	if part:GetAttribute(ATRIBUTO) ~= true then
		return { ok = false, reason = { key = "paint.wall" } }
	end

	local face = faceFromNormal(part, hit.Normal)
	if not face then
		return { ok = false, reason = { key = "paint.wall" } }
	end

	local localPoint = part.CFrame:PointToObjectSpace(hit.Position)
	local u, v = face.uv(localPoint, part.Size)
	if u < 0 or u > 1 or v < 0 or v > 1 then
		return { ok = false }
	end

	local canvas = ensureCanvas(part, face)
	stamp(canvas, u, v, color, pixels)
	return { ok = true, pintado = true }
end

--- Borra todo lo pintado (se llama al empezar una semana nueva).
function GraffitiService.clearAll()
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("SurfaceGui") and string.sub(descendant.Name, 1, #CANVAS) == CANVAS then
			descendant:Destroy()
		end
	end
end

--- Deja pintable todo lo que el mapa marco como pared o casillero.
function GraffitiService.markMap(map: any)
	if not map then
		return
	end
	local marked = 0
	for _, descendant in map.root:GetDescendants() do
		if descendant:IsA("BasePart") then
			local name = descendant.Name
			if name == "Pared" or name == "ParedLateral" or name == "ParedFondo"
				or name == "ParedPasillo" or name == "Puerta" or name == "Cuerpo"
				or name == "PuertaCasillero" or name == "Fondo" or name == "Dintel"
				or name == "Baldosa" or name == "Friso" or name == "Tienda"
				or name == "Pizarra" then
				GraffitiService.markPaintable(descendant)
				marked += 1
			end
		end
	end
	print(string.format("[Grafiti] %d superficies pintables.", marked))
end

function GraffitiService.start(onPaintedInClass: ((Player) -> ())?)
	Net.event(Net.Events.Paint).OnServerEvent:Connect(function(player, direction, colorIndex, sizeIndex)
		local result = GraffitiService.paint(player, direction, colorIndex, sizeIndex)
		if result.pintado and onPaintedInClass then
			onPaintedInClass(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		budget[player] = nil
		lastTick[player] = nil
	end)
end

return GraffitiService

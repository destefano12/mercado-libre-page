--!strict
--[[
	BookService
	------------------------------------------------------------------
	Los libros de texto del pasillo.

	Son la ruta honesta: leer uno en el recreo te deja aprendidas de
	verdad unas cuantas respuestas del examen que viene, y aparecen ya
	marcadas en tu hoja cuando te sentas. No es trampa — es la
	alternativa a la trampa, y por eso existe: sin ella copiar no seria
	una eleccion, seria la unica opcion.

	Cada libro tiene su propio enfriamiento, asi que no se puede
	exprimir el mismo tomo cuatro veces seguidas: hay que recorrer el
	pasillo, y recorrer el pasillo es tiempo que no pasas preparando
	otra cosa.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local ExamService = require(script.Parent:WaitForChild("ExamService"))

local H = Config.Herramientas

local BookService = {}

local COLORES = {
	Color3.fromRGB(126, 44, 52),
	Color3.fromRGB(42, 74, 118),
	Color3.fromRGB(58, 96, 62),
	Color3.fromRGB(120, 92, 44),
	Color3.fromRGB(78, 54, 104),
}

local cooldown: { [Instance]: number } = {}
local playerCooldown: { [Player]: number } = {}
local phase = "espera"

function BookService.setPhase(name: string)
	phase = name
end

local function canRead(player: Player): (boolean, any)
	if phase ~= "recreo" and phase ~= "espera" then
		return false, { key = "book.only_recess" }
	end
	local now = os.clock()
	if now - (playerCooldown[player] or -math.huge) < H.LibroEnfriamiento then
		return false, { key = "book.busy" }
	end
	return true, nil
end

local function grant(player: Player)
	playerCooldown[player] = os.clock()
	ExamService.grantKnowledge(player, H.LibroRevela)
	Net.event(Net.Events.Notify):FireClient(player, {
		key = "book.learned",
		args = { n = H.LibroRevela },
	})
end

--- Leer el libro que llevas en la mano (la herramienta comprada).
function BookService.readTool(player: Player): any
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if not tool or tool:GetAttribute("Libro") ~= true then
		return { ok = false, reason = { key = "cheat.none" } }
	end
	local ok, reason = canRead(player)
	if not ok then
		return { ok = false, reason = reason }
	end
	grant(player)
	return { ok = true }
end

-- ── libros del mapa ────────────────────────────────────────────────

--[[
	Pasarle el libro a un companero.

	Es la mecanica cooperativa del que estudio repartiendo: el libro es
	un recurso escaso del pasillo, y quien lo junto puede quedarselo o
	hacerlo circular. Encaja con el "aprueban o reprueban juntos", porque
	el promedio del curso es lo que decide el dia.

	El cliente dice a quien apunta y el servidor comprueba la distancia,
	igual que hacen los prismaticos.
--]]
function BookService.pass(player: Player, target: Player): any
	if target == player then
		return { ok = false }
	end

	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if not tool or tool:GetAttribute("Libro") ~= true then
		return { ok = false, reason = { key = "book.none" } }
	end

	local from = character and character:FindFirstChild("HumanoidRootPart")
	local targetCharacter = target.Character
	local to = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
	if not from or not from:IsA("BasePart") or not to or not to:IsA("BasePart") then
		return { ok = false }
	end
	if (from.Position - to.Position).Magnitude > H.AlcancePase then
		return { ok = false, reason = { key = "book.too_far" } }
	end

	-- La mochila, no el personaje: si va al personaje queda equipado a la
	-- fuerza en medio de lo que el otro estuviera haciendo.
	local backpack = target:FindFirstChildOfClass("Backpack")
	if not backpack then
		return { ok = false }
	end
	tool.Parent = backpack

	Net.event(Net.Events.Notify):FireClient(target, {
		key = "book.received",
		args = { name = player.DisplayName },
	})
	return { ok = true, reason = { key = "book.passed", args = { name = target.DisplayName } } }
end

local function buildBook(parent: Instance, cf: CFrame, index: number): Model
	local model = Instance.new("Model")
	model.Name = "Libro" .. index
	model.Parent = parent

	local color = COLORES[((index - 1) % #COLORES) + 1]
	local cover = Util.part({
		Name = "Tapa",
		Size = Vector3.new(1.6, 0.4, 2.1),
		CFrame = cf,
		Color = color,
		Material = Enum.Material.Fabric,
		Parent = model,
	})
	Util.part({
		Name = "Hojas",
		Size = Vector3.new(1.5, 0.32, 2),
		CFrame = cf * CFrame.new(0.06, 0.02, 0),
		Color = Color3.fromRGB(246, 244, 234),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	}).CanCollide = false

	model.PrimaryPart = cover

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Leer"
	prompt.ActionText = "Leer"
	prompt.ObjectText = "Libro de texto"
	prompt.HoldDuration = H.LibroSegundos
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = cover

	prompt.Triggered:Connect(function(player)
		local now = os.clock()
		if now - (cooldown[model] or -math.huge) < H.LibroEnfriamiento then
			Net.event(Net.Events.Notify):FireClient(player, { key = "book.busy" })
			return
		end
		local ok, reason = canRead(player)
		if not ok then
			Net.event(Net.Events.Notify):FireClient(player, reason)
			return
		end
		cooldown[model] = now
		grant(player)
		Util.playSound(Config.Sonidos.Papel, cover, 0.3, 0.9)
	end)

	return model
end

--- Reparte los libros por los bancos y el suelo del pasillo.
function BookService.build(map: any)
	if not map then
		return
	end
	local parent = workspace:FindFirstChild("Objetos") or workspace
	local previous = parent:FindFirstChild("Libros")
	if previous then
		previous:Destroy()
	end

	local holder = Instance.new("Model")
	holder.Name = "Libros"
	holder.Parent = parent

	local halfW = Config.Escuela.PasilloAncho / 2
	local halfL = Config.Escuela.PasilloLargo / 2

	-- Repartidos a lo largo del pasillo, alternando de lado: obliga a
	-- caminar para juntarlos.
	-- Misma correccion que en NerdNPCs: la franja sale de la config, no
	-- de las constantes 40 y 70 calibradas contra el pasillo viejo.
	local spots = 6
	local bandStart = -halfL + 18
	local bandEnd = halfL - Config.Escuela.ZonaRecreoLargo - 6
	local step = (bandEnd - bandStart) / spots

	for i = 1, spots do
		local side = (i % 2 == 0) and 1 or -1
		local z = bandStart + (i - 0.5) * step
		local cf = CFrame.new(side * (halfW - 4.2), 2.3, z)
			* CFrame.Angles(0, math.rad(20 * i), 0)
		local ok, err = pcall(function()
			buildBook(holder, cf, i)
		end)
		if not ok then
			warn("[Libros] " .. tostring(err))
		end
	end

	print(string.format("[Libros] %d libros de texto en el pasillo.", spots))
end

function BookService.start()
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		playerCooldown[player] = nil
	end)
end

return BookService

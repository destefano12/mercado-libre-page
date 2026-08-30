--!strict
--[[
	Servidor — arranque de Finals Week
	------------------------------------------------------------------
	El orden importa y esta pensado:

		1. Net.build()   los remotes tienen que existir antes de que
		                 cualquier cliente los busque
		2. ServerStorage banco de preguntas, penalizaciones y modelos
		                 de respaldo, fuera del alcance del cliente
		3. Templates     plantillas de herramientas en ReplicatedStorage
		4. Atmosphere    luz, cielo y post-proceso ANTES del mapa, para
		                 que las luminarias nazcan ya configuradas
		5. MapBuilder    el instituto entero
		6. pasillo       grafiti, pelota, libros y empollones
		7. servicios     examenes, objetos, sospecha, castigos, radio
		8. TeacherAI     la vision arranca ya; los profesores aparecen
		                 al empezar cada examen
		9. RoundManager  el bucle escolar

	Cada paso va en su pcall con un print: si algo falla, el Output
	dice exactamente cual y el resto del juego sigue de pie. Aprendido
	a la mala: una propiedad de solo lectura al principio del arranque
	te deja parado en el vacio sin ninguna pista.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local MapBuilder = require(script:WaitForChild("MapBuilder"))
local QuestionBank = require(script:WaitForChild("QuestionBank"))
local Templates = require(script:WaitForChild("Templates"))
local DataService = require(script:WaitForChild("DataService"))
local CharacterService = require(script:WaitForChild("CharacterService"))
local SuspicionService = require(script:WaitForChild("SuspicionService"))
local ExamService = require(script:WaitForChild("ExamService"))
local ItemService = require(script:WaitForChild("ItemService"))
local TeacherAI = require(script:WaitForChild("TeacherAI"))
local PunishService = require(script:WaitForChild("PunishService"))
local ShopService = require(script:WaitForChild("ShopService"))
local RoundManager = require(script:WaitForChild("RoundManager"))
local LobbyService = require(script:WaitForChild("LobbyService"))
local Atmosphere = require(script:WaitForChild("Atmosphere"))
local GraffitiService = require(script:WaitForChild("GraffitiService"))
local PlaygroundService = require(script:WaitForChild("PlaygroundService"))
local BookService = require(script:WaitForChild("BookService"))
local NerdNPCs = require(script:WaitForChild("NerdNPCs"))
local RadioService = require(script:WaitForChild("RadioService"))
local KnockoutService = require(script:WaitForChild("KnockoutService"))

local function step(label: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		print("[Finals Week] " .. label)
	else
		warn(string.format("[Finals Week] %s FALLO: %s", label, tostring(err)))
	end
end

-- ── 1. red ─────────────────────────────────────────────────────────
step("remotes listos", function()
	Net.build()
end)

-- ── 2-4. contenido ─────────────────────────────────────────────────
step("banco de preguntas en ServerStorage", function()
	QuestionBank.install()
end)

step("plantillas de herramientas", function()
	Templates.build()
end)

step("modelos de respaldo en ServerStorage", function()
	CharacterService.installBackup()
end)

--[[
	Va antes de que entre nadie: un StarterCharacter colgado de
	StarterPlayer reemplaza el avatar de Roblox de cada jugador por el
	cuerpo caricaturesco. Es la unica forma que funciona tambien por el
	.rbxmx todo-en-uno, donde un script no puede tocar el tipo de avatar
	del lugar.
--]]
step("cuerpo del jugador", function()
	CharacterService.installStarterCharacter()
end)

step("iluminacion y post-proceso", function()
	Atmosphere.apply()
end)

local map: any = nil
step("instituto construido", function()
	map = MapBuilder.build()
end)

step("paredes pintables", function()
	GraffitiService.markMap(map)
	GraffitiService.start(function(player)
		-- Pintar dentro del aula durante el examen es una infraccion
		-- como cualquier otra.
		if ExamService.isRunning() then
			SuspicionService.infraction(player, Config.Grafiti.SospechaPorPintar, "paint")
		end
	end)
end)

step("pasillo: pelota, libros y empollones", function()
	PlaygroundService.build(map)
	PlaygroundService.start(function(player, credits)
		DataService.addCredits(player, credits)
	end)
	BookService.build(map)
	BookService.start()
	NerdNPCs.spawn(map)
end)

step("comunicaciones", function()
	RadioService.start()
end)

step("empujones y nocaut", function()
	KnockoutService.start()
	KnockoutService.onNerdDown(function(player, model)
		NerdNPCs.dropSheet(player, model)
	end)
end)

-- ── 5. servicios ───────────────────────────────────────────────────
step("datos y economia", function()
	DataService.start()
	ShopService.start()
	ShopService.bindKiosk(map and map.shop)
end)

step("examenes", function()
	ExamService.setMap(map)
	ExamService.start()
	-- Cajones del escritorio y alcoba secreta de la biblioteca. Sin esta
	-- linea sus ProximityPrompt existen y no hacen nada.
	if map then
		ExamService.bindStashes(map.root)
	end
end)

step("objetos y casilleros", function()
	ItemService.start()
	ItemService.onReadBook = function(player)
		return BookService.readTool(player)
	end
	ItemService.onPassBook = function(player, target)
		return BookService.pass(player, target)
	end
	if map then
		ItemService.bindLockers(map.lockers)
	end
	ItemService.onNoise(function(position, source)
		TeacherAI.hearNoise(position, source)
	end)
end)

step("sospecha", function()
	SuspicionService.start()
end)

step("castigos", function()
	PunishService.start()
	PunishService.setDetention(map and map.detention)
	TeacherAI.onPunish(function(player, teacher)
		PunishService.apply(player, teacher)
	end)
	-- La goma de borrar no expulsa a nadie: aturde y descuenta.
	TeacherAI.onStun(function(player, points)
		PunishService.addPenalty(player, points)
	end)
end)

-- ── 6. el profesor ─────────────────────────────────────────────────
step("IA del profesor", function()
	TeacherAI.start()
end)

-- ── 7. jugadores ───────────────────────────────────────────────────

local function onCharacter(player: Player, character: Model)
	local profile = DataService.get(player) or DataService.load(player)

	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 48   -- saltar es la unica forma de dejar un Seat
		humanoid.UseJumpPower = true
	end

	CharacterService.dressStudent(player, character, profile.estetica)

	-- Aparecer en el pasillo, no en el vacio.
	if map and #map.spawns > 0 then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local point = map.spawns[math.random(1, #map.spawns)]
			root.CFrame = CFrame.new(point)
		end
	end

	SuspicionService.setSight(player, false, math.huge)
end

step("jugadores", function()
	Players.CharacterAutoLoads = true

	local function bind(player: Player)
		DataService.load(player)
		DataService.push(player)
		if player.Character then
			task.defer(onCharacter, player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			task.defer(function()
				local ok, err = pcall(onCharacter, player, character)
				if not ok then
					warn("[Finals Week] personaje: " .. tostring(err))
				end
			end)
		end)
	end

	for _, player in Players:GetPlayers() do
		task.spawn(bind, player)
	end
	Players.PlayerAdded:Connect(function(player)
		task.spawn(bind, player)
	end)
end)

-- ── 8. remotes de consulta ─────────────────────────────────────────
step("consultas del cliente", function()
	Net.func(Net.Functions.GetState).OnServerInvoke = function(player)
		local profile = DataService.get(player)
		return {
			examen = ExamService.state(player),
			billetera = profile and {
				creditos = profile.creditos,
				comprados = profile.comprados,
				objeto = profile.objeto,
				estetica = profile.estetica,
				semanas = profile.semanas,
				mejorPromedio = profile.mejorPromedio,
			} or nil,
			tienda = Config.Economia.Tienda,
			salas = LobbyService.isAvailable(),
		}
	end

	Net.func(Net.Functions.SubmitAnswer).OnServerInvoke = function(player, index, option)
		return ExamService.submit(player, tonumber(index) or 0, tonumber(option) or 0)
	end

	Net.func(Net.Functions.SubmitSequence).OnServerInvoke = function(player, index, typed)
		return ExamService.submitSequence(player, tonumber(index) or 0, tostring(typed))
	end

	Net.func(Net.Functions.ChooseMode).OnServerInvoke = function(player, mode)
		-- "solo" y "publico" se juegan en este mismo servidor; "amigos"
		-- lo resuelve el buscador de salas.
		player:SetAttribute("Modo", tostring(mode))
		return { ok = true }
	end
end)

-- ── 9. salas ───────────────────────────────────────────────────────
step("salas", function()
	LobbyService.start()
end)

-- ── 10. bucle escolar ──────────────────────────────────────────────
step("ciclo escolar", function()
	RoundManager.setMap(map)
	RoundManager.start()
end)

print("[Finals Week] Servidor listo.")

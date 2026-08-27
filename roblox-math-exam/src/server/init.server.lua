--!strict
--[[
	SERVIDOR — punto de entrada
	------------------------------------------------------------------
	Con Rojo, esta carpeta se convierte en un Script llamado "Server"
	dentro de ServerScriptService, y los demas archivos quedan como
	ModuleScripts hijos de este Script.

	Orden de arranque:
		1. remotes
		2. aula (todo el 3D)
		3. servicios (prueba / celular / sospecha)
		4. profesor
		5. ronda
--]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

Net.build()

local ClassroomBuilder = require(script:WaitForChild("ClassroomBuilder"))
local ExamService = require(script:WaitForChild("ExamService"))
local PhoneService = require(script:WaitForChild("PhoneService"))
local SuspicionService = require(script:WaitForChild("SuspicionService"))
local RoundService = require(script:WaitForChild("RoundService"))
local StudentNPCs = require(script:WaitForChild("StudentNPCs"))
local TeacherAI = require(script:WaitForChild("TeacherAI"))

-- ─────────────────────────────────────────────────────────────
-- 1. Aula
-- ─────────────────────────────────────────────────────────────

-- El baseplate del lugar vacio queda a la misma altura que el piso del
-- aula y pelean por el mismo pixel. El aula trae su propio piso.
local baseplate = Workspace:FindFirstChild("Baseplate")
if baseplate and baseplate:IsA("BasePart") then
	baseplate:Destroy()
end

local classroom = ClassroomBuilder.build(Workspace)
print("[Aula] Aula construida.")

-- Spawn de los alumnos: adentro del aula, no en el vacio.
local spawnLocation = Workspace:FindFirstChildOfClass("SpawnLocation")
if not spawnLocation then
	spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Parent = Workspace
end
spawnLocation.Name = "EntradaAula"
spawnLocation.Size = Vector3.new(8, 1, 8)
spawnLocation.CFrame = classroom.studentSpawn * CFrame.new(0, -2.4, 0)
spawnLocation.Anchored = true
spawnLocation.Transparency = 1
spawnLocation.CanCollide = false
spawnLocation.Neutral = true

-- ─────────────────────────────────────────────────────────────
-- 2. Servicios
-- ─────────────────────────────────────────────────────────────

ExamService.init(classroom)

-- Cada pieza va en su propio pcall: si el rig del profe o los companeros
-- fallan por algo del entorno, el aula y la prueba tienen que seguir
-- funcionando igual (y el Output tiene que decir por que).
local teacher
local built, teacherError = pcall(function()
	teacher = TeacherAI.new(classroom, function(player)
		RoundService.handleCatch(player)
		-- Todo el curso se da vuelta a mirar. Es media la gracia.
		StudentNPCs.reactAll("sorprendido", 3.5)
	end)
	teacher:start()
end)
if built then
	print("[Aula] Profesor en el aula.")
else
	warn("[Aula] No se pudo crear al profesor: " .. tostring(teacherError))
end

-- El aula se llena de companeros, y cada jugador que entra se lleva el
-- banco de uno (ese NPC se levanta y se va).
local filled, npcError = pcall(function()
	StudentNPCs.init(classroom, teacher)
	StudentNPCs.fillAll()
	StudentNPCs.start()
end)
if filled then
	print("[Aula] Companeros sentados.")
else
	warn("[Aula] No se pudieron sentar los companeros: " .. tostring(npcError))
end

ExamService.onDeskAssigned = StudentNPCs.vacate
ExamService.onDeskReleased = StudentNPCs.occupy

if teacher then
	SuspicionService.init(teacher, function(player)
		-- Riesgo al maximo: el profe deja lo que estaba haciendo y viene.
		teacher:confront(player)
	end)
	SuspicionService.start()
end
PhoneService.start()

-- ─────────────────────────────────────────────────────────────
-- 3. Remotes
-- ─────────────────────────────────────────────────────────────

Net.func(Net.Functions.GetExam).OnServerInvoke = function(player)
	RoundService.pushTo(player)
	return ExamService.snapshot(player)
end

Net.func(Net.Functions.SubmitAnswer).OnServerInvoke = function(player, questionId, choice)
	if RoundService.getPhase() ~= "Prueba" then
		return { ok = false, reason = { key = "notify.notRunning" } }
	end
	return ExamService.submitAnswer(player, questionId, choice)
end

Net.func(Net.Functions.TakePhoto).OnServerInvoke = function(player, questionId)
	if RoundService.getPhase() ~= "Prueba" then
		return { ok = false, reason = { key = "error.nothingToShoot" } }
	end
	return PhoneService.takePhoto(player, questionId)
end

Net.func(Net.Functions.AskRoGPT).OnServerInvoke = function(player, photoId)
	return PhoneService.askRoGPT(player, photoId)
end

-- Solo / con amigos: se reserva un servidor privado y se manda al
-- jugador ahi. En Studio no existe (PlaceId = 0) y se avisa sin drama.
Net.func(Net.Functions.ChooseMode).OnServerInvoke = function(player, mode)
	if mode ~= "solo" and mode ~= "friends" then
		return { ok = true, stay = true }
	end

	local placeId = game.PlaceId
	if placeId == 0 then
		return { ok = false, reason = { key = "menu.mode.unavailable" } }
	end

	local reserved, code = pcall(function()
		return TeleportService:ReserveServer(placeId)
	end)
	if not reserved then
		return { ok = false, reason = { key = "menu.mode.unavailable" } }
	end

	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code

	local sent = pcall(function()
		TeleportService:TeleportAsync(placeId, { player }, options)
	end)
	if not sent then
		return { ok = false, reason = { key = "menu.mode.unavailable" } }
	end

	return { ok = true }
end

Net.event(Net.Events.PhoneState).OnServerEvent:Connect(function(player, out)
	if typeof(out) ~= "boolean" then
		return
	end
	if RoundService.getPhase() ~= "Prueba" then
		PhoneService.setOut(player, false)
		return
	end
	PhoneService.setOut(player, out)
end)

-- ─────────────────────────────────────────────────────────────
-- 4. Jugadores
-- ─────────────────────────────────────────────────────────────

local function onPlayerAdded(player: Player)
	RoundService.addPlayer(player)
	player.CharacterAdded:Connect(function(character)
		RoundService.onCharacter(player, character)
	end)
	if player.Character then
		RoundService.onCharacter(player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	PhoneService.reset(player)
	SuspicionService.reset(player)
end)

-- ─────────────────────────────────────────────────────────────
-- 5. Ronda
-- ─────────────────────────────────────────────────────────────

RoundService.start(classroom, teacher)

-- ─────────────────────────────────────────────────────────────
-- 6. Iluminacion de interior
-- ─────────────────────────────────────────────────────────────
--
-- Va ultimo y adentro de un pcall a proposito: es puro adorno, y si
-- alguna propiedad no se deja escribir en la version de Roblox que
-- tengas, no me interesa que se lleve puesto el aula entera.
--
-- Lighting.Technology NO se toca desde aca: es de solo lectura en
-- runtime. Viene puesta en ShadowMap desde el archivo del lugar, y si
-- abris esto en un lugar tuyo la ponés a mano en Lighting > Technology.
local ok, err = pcall(function()
	Lighting.Ambient = Color3.fromRGB(90, 92, 102)
	Lighting.OutdoorAmbient = Color3.fromRGB(115, 120, 132)
	Lighting.Brightness = 2.2
	Lighting.ClockTime = 10.5
	Lighting.GeographicLatitude = -34.6
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	Lighting.FogEnd = 400

	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.28
		atmosphere.Haze = 1.2
		atmosphere.Glare = 0.15
		atmosphere.Color = Color3.fromRGB(215, 220, 232)
		atmosphere.Parent = Lighting
	end
end)
if not ok then
	warn("[Aula] No se pudo ajustar la iluminacion: " .. tostring(err))
end

print(string.format("[Aula] Listo: %d bancos, %d nodos de patrullaje, prueba de %d ejercicios.",
	#classroom.desks, #classroom.patrolNodes, Config.Exam.QuestionCount))

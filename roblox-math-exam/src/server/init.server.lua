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
local TeacherAI = require(script:WaitForChild("TeacherAI"))

-- ─────────────────────────────────────────────────────────────
-- 0. Escenario base
-- ─────────────────────────────────────────────────────────────

-- Iluminacion de interior. Se aplica por codigo para que el juego se
-- vea igual venga de Rojo, del .rbxmx o de copiar y pegar a mano.
local function applyLighting()
	Lighting.Technology = Enum.Technology.ShadowMap
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
end

applyLighting()

-- El baseplate del lugar vacio queda a la misma altura que el piso del
-- aula y pelean por el mismo pixel. El aula trae su propio piso.
local baseplate = Workspace:FindFirstChild("Baseplate")
if baseplate and baseplate:IsA("BasePart") then
	baseplate:Destroy()
end

-- ─────────────────────────────────────────────────────────────
-- 1. Aula
-- ─────────────────────────────────────────────────────────────

local classroom = ClassroomBuilder.build(Workspace)

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

local teacher = TeacherAI.new(classroom, function(player)
	RoundService.handleCatch(player)
end)

SuspicionService.init(teacher, function(player)
	-- Riesgo al maximo: el profe deja lo que estaba haciendo y viene.
	teacher:confront(player)
end)

SuspicionService.start()
PhoneService.start()
teacher:start()

-- ─────────────────────────────────────────────────────────────
-- 3. Remotes
-- ─────────────────────────────────────────────────────────────

Net.func(Net.Functions.GetExam).OnServerInvoke = function(player)
	RoundService.pushTo(player)
	return ExamService.snapshot(player)
end

Net.func(Net.Functions.SubmitAnswer).OnServerInvoke = function(player, questionId, choice)
	if RoundService.getPhase() ~= "Prueba" then
		return { ok = false, reason = "La prueba no esta en curso." }
	end
	return ExamService.submitAnswer(player, questionId, choice)
end

Net.func(Net.Functions.TakePhoto).OnServerInvoke = function(player, questionId)
	if RoundService.getPhase() ~= "Prueba" then
		return { ok = false, reason = "No hay nada para fotografiar todavia." }
	end
	return PhoneService.takePhoto(player, questionId)
end

Net.func(Net.Functions.AskRoGPT).OnServerInvoke = function(player, photoId)
	return PhoneService.askRoGPT(player, photoId)
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

print(string.format("[Aula] Listo: %d bancos, %d nodos de patrullaje, prueba de %d ejercicios.",
	#classroom.desks, #classroom.patrolNodes, Config.Exam.QuestionCount))

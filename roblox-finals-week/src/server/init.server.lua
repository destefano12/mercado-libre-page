--!strict
--[[
	Servidor — arranque de Finals Week
	------------------------------------------------------------------
	El orden importa y esta pensado:

		1. Net.build()          los remotes tienen que existir antes de
		                        que cualquier cliente los busque
		2. ServerStorage        banco de preguntas y penalizaciones,
		                        fuera del alcance del cliente
		3. Templates            plantillas de herramientas en
		                        ReplicatedStorage (el cliente las lee)
		4. MapBuilder           el instituto entero
		5. servicios            examenes, objetos, sospecha, castigos
		6. TeacherAI            la vision arranca ya, los profesores
		                        aparecen al empezar cada examen
		7. RoundManager         el bucle escolar

	Cada paso va en su pcall con un print: si algo falla, el Output
	dice exactamente cual y el resto del juego sigue de pie. Aprendido
	a la mala: una propiedad de solo lectura al principio del arranque
	te deja parado en el vacio sin ninguna pista.
--]]

local Lighting = game:GetService("Lighting")
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

local map: any = nil
step("instituto construido", function()
	map = MapBuilder.build()
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
end)

step("objetos y casilleros", function()
	ItemService.start()
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

-- ── 11. luz ────────────────────────────────────────────────────────
-- Al final y en pcall: Lighting.Technology es de solo lectura desde un
-- script y va en el archivo del lugar, no aca.
pcall(function()
	Lighting.Brightness = 2
	Lighting.ClockTime = 9.5
	Lighting.Ambient = Color3.fromRGB(82, 84, 96)
	Lighting.OutdoorAmbient = Color3.fromRGB(112, 118, 132)
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	Lighting.FogEnd = 900

	if not Lighting:FindFirstChild("Atmosfera") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "Atmosfera"
		atmosphere.Density = 0.28
		atmosphere.Haze = 0.9
		atmosphere.Glare = 0.1
		atmosphere.Parent = Lighting
	end
end)

print("[Finals Week] Servidor listo.")

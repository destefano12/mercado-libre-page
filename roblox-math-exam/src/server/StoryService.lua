--!strict
--[[
	StoryService
	------------------------------------------------------------------
	El dia no termina cuando entregás la prueba.

		Timbre    -> el profe corta, los alumnos se paran y salen
		Salida    -> cinematica: el pasillo, la puerta, el saludo
		Casa      -> negro, y aparecés en tu casa con tu viejo
		Charla    -> te pregunta como te fue. Ahi se juega todo: podés
		             decir la verdad o mentir, y despues te pide el
		             celular (donde esta la app de la escuela)
		Epilogo   -> la placa final

	Todo el texto viaja como clave: cada uno lo lee en su idioma.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local CharacterArt = require(Shared:WaitForChild("CharacterArt"))

local ExamService = require(script.Parent:WaitForChild("ExamService"))
local HomeBuilder = require(script.Parent:WaitForChild("HomeBuilder"))
local PhoneService = require(script.Parent:WaitForChild("PhoneService"))
local StudentNPCs = require(script.Parent:WaitForChild("StudentNPCs"))
local SuspicionService = require(script.Parent:WaitForChild("SuspicionService"))

local S = Config.Story

local StoryService = {}

local home: HomeBuilder.Home? = nil
local dad: Model? = nil
local classroom: any = nil
local choices: { [Player]: string } = {}

-- ─────────────────────────────────────────────────────────────
-- Utilidades
-- ─────────────────────────────────────────────────────────────

local function everyone(): { Player }
	return Players:GetPlayers()
end

local function cinematic(player: Player?, payload: any)
	local remote = Net.event(Net.Events.Cinematic)
	if player then
		remote:FireClient(player, payload)
	else
		remote:FireAllClients(payload)
	end
end

local function say(player: Player?, key: string, args: { [string]: any }?, duration: number?)
	local remote = Net.event(Net.Events.StoryLine)
	local payload = { key = key, args = args, duration = duration or 4 }
	if player then
		remote:FireClient(player, payload)
	else
		remote:FireAllClients(payload)
	end
end

local function teleport(player: Player, target: CFrame)
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.SeatPart then
			humanoid.Sit = false
		end
		task.wait(0.1)
		character:PivotTo(target)
	end
end

--- Espera la eleccion del jugador, con limite: si no contesta, decide
--- el silencio (que en una charla con tu viejo tambien es una respuesta).
local function ask(player: Player, promptKey: string, options: { { id: string, key: string } }, timeout: number): string
	choices[player] = ""
	cinematic(player, { sequence = "prompt", promptKey = promptKey, options = options })

	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		if choices[player] ~= "" then
			local answer = choices[player]
			choices[player] = ""
			return answer
		end
		task.wait(0.1)
	end
	choices[player] = ""
	return options[#options].id
end

function StoryService.submitChoice(player: Player, id: string)
	if typeof(id) == "string" then
		choices[player] = id
	end
end

-- ─────────────────────────────────────────────────────────────
-- El viejo
-- ─────────────────────────────────────────────────────────────

local function spawnDad()
	if dad and dad.Parent then
		return
	end
	if not home then
		return
	end

	local ok, model = pcall(function()
		local description = Instance.new("HumanoidDescription")
		description.HeightScale = 1.05
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		return
	end

	model.Name = "Papa"
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local head = model:FindFirstChild("Head") :: BasePart?
	if humanoid then
		humanoid.DisplayName = "?"
		humanoid.WalkSpeed = 0
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end

	for _, name in { "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm" } do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Color = Color3.fromRGB(92, 98, 112)
		end
	end

	if head then
		pcall(function()
			CharacterArt.attachFace(head, Color3.fromRGB(226, 190, 156))
			CharacterArt.attachOldHair(head, Color3.fromRGB(96, 88, 84))
		end)
	end

	model.Parent = workspace
	model:PivotTo((home :: HomeBuilder.Home).dadStand)

	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = true
	end
	dad = model
end

-- ─────────────────────────────────────────────────────────────
-- Actos
-- ─────────────────────────────────────────────────────────────

--- Suena el timbre: los companeros se paran y se van, y la camara se
--- toma su tiempo para mirarlos salir.
function StoryService.dismissal(teacher: any)
	if teacher then
		teacher:say("story.bell", 4)
	end

	local exit = classroom and classroom.studentSpawn or CFrame.new()
	pcall(StudentNPCs.dismiss, exit.Position)

	for _, player in everyone() do
		PhoneService.setOut(player, false)
		SuspicionService.reset(player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.SeatPart then
			humanoid.Sit = false
		end
		cinematic(player, {
			sequence = "salida",
			exit = exit,
			board = classroom and classroom.boardStand or nil,
		})
	end

	say(nil, "story.leaving", nil, 5)
	task.wait(S.DismissalDuration * 0.45)
	say(nil, "story.goodbye", nil, 4)
	task.wait(S.DismissalDuration * 0.3)
	say(nil, "story.walkingHome", nil, 4)
	task.wait(S.DismissalDuration * 0.25)
end

--- Negro, y estas en tu casa. Tu viejo ya sabe que llegaste.
function StoryService.atHome()
	if not home then
		return
	end
	local scene = home :: HomeBuilder.Home
	spawnDad()

	for _, player in everyone() do
		cinematic(player, { sequence = "fade", to = 1, duration = S.FadeTime })
	end
	task.wait(S.FadeTime + 0.2)

	for _, player in everyone() do
		teleport(player, scene.playerSpawn)
		cinematic(player, {
			sequence = "casa",
			wide = scene.cameraWide,
			close = scene.cameraClose,
		})
	end

	task.wait(1.5)
	say(nil, "story.homeArrival", nil, 3)
	task.wait(2.5)

	-- La charla, uno por uno: cada jugador tiene su nota y su historia.
	for _, player in everyone() do
		task.spawn(function()
			local entry = ExamService.get(player)
			local grade = ExamService.getGrade(player)
			local failed = grade < Config.Exam.PassingGrade
			local cheated = entry and entry.cheated or 0
			local caught = entry and entry.catches or 0

			say(player, "story.dad.greet", nil, 4)
			task.wait(3.5)

			local told = ask(player, "story.dad.greet", {
				{ id = "truth", key = "story.choice.truth" },
				{ id = "lie", key = "story.choice.lie" },
			}, 14)

			task.wait(0.6)
			say(player, "story.dad.askPhone", nil, 4)
			task.wait(3)

			local phone = ask(player, "story.dad.askPhone", {
				{ id = "give", key = "story.choice.give" },
				{ id = "hide", key = "story.choice.hide" },
			}, 14)

			-- El desenlace: mentir solo aguanta si le das el celular y
			-- no te pillaron copiandote.
			local resultKey
			if told == "truth" then
				resultKey = failed and "story.result.truthFail" or "story.result.truthPass"
			elseif phone == "give" and (not failed or caught > 0) then
				resultKey = "story.result.lieCaught"
			elseif phone == "give" and failed then
				resultKey = "story.result.lieCaught"
			else
				resultKey = "story.result.lieHeld"
			end

			say(player, resultKey, nil, 5)
			task.wait(4)

			if phone == "give" or caught > 0 then
				say(player, "story.result.phoneTaken", nil, 4)
			end

			StoryService.lastOutcome = StoryService.lastOutcome or {}
			StoryService.lastOutcome[player] = {
				told = told,
				phone = phone,
				grade = grade,
				cheated = cheated,
				caught = caught,
			}
		end)
	end

	task.wait(S.HomeDuration)
end

--- La placa del final. Es la unica moraleja del juego y va sola, en
--- negro, sin musiquita ni confeti.
function StoryService.epilogue()
	for _, player in everyone() do
		local entry = ExamService.get(player)
		cinematic(player, {
			sequence = "epilogo",
			titleKey = "story.epilogue.title",
			grade = string.format("%.1f", ExamService.getGrade(player)),
			cheated = entry and entry.cheated or 0,
			caught = entry and entry.catches or 0,
		})
	end
	task.wait(S.EpilogueDuration)
end

--- De vuelta a la escuela para el dia siguiente.
function StoryService.backToSchool()
	if dad then
		dad:Destroy()
		dad = nil
	end
	for _, player in everyone() do
		cinematic(player, { sequence = "fade", to = 1, duration = S.FadeTime })
	end
	task.wait(S.FadeTime + 0.2)
	for _, player in everyone() do
		cinematic(player, { sequence = "libre" })
	end
end

function StoryService.init(classroomRef: any)
	classroom = classroomRef
	local ok, scene = pcall(HomeBuilder.build, workspace)
	if ok then
		home = scene
	else
		warn("[Aula] No se pudo construir la casa: " .. tostring(scene))
	end
end

function StoryService.getHome(): HomeBuilder.Home?
	return home
end

Players.PlayerRemoving:Connect(function(player)
	choices[player] = nil
end)

return StoryService

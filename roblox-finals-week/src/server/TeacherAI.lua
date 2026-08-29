--!strict
--[[
	TeacherAI
	------------------------------------------------------------------
	Un profesor por aula, corriendo entero en el servidor.

	Vision:
	  se calcula con vectores, no con magia. Para cada alumno del aula
	  se mide el angulo entre el frente del profesor y la direccion al
	  alumno (producto punto), se descarta si esta fuera del cono o
	  mas lejos de DistanciaVision, y recien ahi se tira un Raycast
	  para confirmar que no hay una pared o un pupitre en el medio.

	Cerebro (una corrutina, un estado a la vez):
	  patrullar  camina los pasillos entre filas con PathfindingService
	  pizarra    se da vuelta a escribir: la ventana para hacer trampa
	  ruido      va al punto donde cayo algo
	  perseguir  corre hacia el que se paso de la raya
	  castigar   aplica la sancion y vuelve a patrullar

	La sospecha no la calcula este modulo: la reporta. Quien castiga es
	PunishService. Asi se puede tocar el balance sin tocar la IA.
--]]

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local CharacterService = require(script.Parent:WaitForChild("CharacterService"))
local SuspicionService = require(script.Parent:WaitForChild("SuspicionService"))
local ExamService = require(script.Parent:WaitForChild("ExamService"))

local P = Config.Profesor

local TeacherAI = {}

type Teacher = {
	aula: number,
	name: string,
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	room: any,
	state: string,
	target: Vector3?,
	chasing: Player?,
	alive: boolean,
	nextLine: number,
	animation: RBXScriptConnection?,
}

local teachers: { [number]: Teacher } = {}
local rng = Random.new()
local vision: RBXScriptConnection? = nil
local punishHandler: ((Player, Teacher) -> ())? = nil
local examMode = false

local COS_FOV = math.cos(math.rad(P.AnguloVision))

-- ── voz ────────────────────────────────────────────────────────────

local function say(teacher: Teacher, key: string, args: { [string]: any }?, only: Player?)
	local packet = { key = key, args = args, profesor = teacher.name, aula = teacher.aula }
	local remote = Net.event(Net.Events.TeacherSay)
	if only then
		remote:FireClient(only, packet)
	else
		remote:FireAllClients(packet)
	end
end

-- ── pizarra ────────────────────────────────────────────────────────

local CHALK = {
	"x = (-b +- raiz(b^2 - 4ac)) / 2a",
	"a^2 + b^2 = c^2",
	"v = d / t",
	"A = pi r^2",
	"sen^2 + cos^2 = 1",
	"E = m c^2",
	"3x + 5 = 20",
	"log(a b) = log a + log b",
}

local function chalkboard(room: any, text: string)
	local board: BasePart = room.blackboard
	local gui = board:FindFirstChild("Tiza")
	if not gui or not gui:IsA("SurfaceGui") then
		local created = Instance.new("SurfaceGui")
		created.Name = "Tiza"
		created.Face = Enum.NormalId.Right
		created.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		created.PixelsPerStud = 26
		created.LightInfluence = 0.3
		created.Parent = board

		local label = Instance.new("TextLabel")
		label.Name = "Texto"
		label.Size = UDim2.fromScale(0.9, 0.6)
		label.Position = UDim2.fromScale(0.05, 0.2)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.PermanentMarker
		label.TextColor3 = Color3.fromRGB(232, 236, 232)
		label.TextScaled = true
		label.TextTransparency = 0.12
		label.Parent = created
		gui = created
	end
	local label = gui:FindFirstChild("Texto")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

--- La pizarra puede estar en la cara Right o Left segun el lado del
--- pasillo en el que este el aula; se elige la que mira a los alumnos.
local function orientChalkboard(room: any)
	local gui = room.blackboard:FindFirstChild("Tiza")
	if gui and gui:IsA("SurfaceGui") then
		gui.Face = room.dir.X > 0 and Enum.NormalId.Right or Enum.NormalId.Left
	end
end

-- ── vision ─────────────────────────────────────────────────────────

local visionParams = RaycastParams.new()
visionParams.FilterType = Enum.RaycastFilterType.Exclude

--- ¿El profesor ve a este alumno? Angulo primero (barato), rayo despues.
local function canSee(teacher: Teacher, character: Model): (boolean, number)
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return false, math.huge
	end

	local eye = teacher.root.Position + Vector3.new(0, P.AlturaOjos, 0)
	local offset = head.Position - eye
	local distance = offset.Magnitude
	if distance > P.DistanciaVision then
		return false, distance
	end

	local forward = teacher.root.CFrame.LookVector
	if forward:Dot(offset.Unit) < COS_FOV then
		return false, distance
	end

	visionParams.FilterDescendantsInstances = {
		teacher.model, character, workspace:FindFirstChild("Proyectiles") :: any,
	}
	local hit = workspace:Raycast(eye, offset, visionParams)
	if hit then
		-- Los pupitres tapan a medias: si lo que corta el rayo es un
		-- mueble bajo, igual te ve la cabeza.
		local blockedHeight = hit.Position.Y
		if blockedHeight > eye.Y - 0.6 then
			return false, distance
		end
	end
	return true, distance
end

local function playersOfRoom(aula: number): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local sitting = ExamService.sitting(player)
		if sitting and sitting.aula == aula then
			table.insert(list, player)
		elseif not sitting and not examMode then
			table.insert(list, player)
		end
	end
	return list
end

local function visionStep()
	for _, teacher in teachers do
		if not teacher.alive or not teacher.root.Parent then
			continue
		end
		for _, player in playersOfRoom(teacher.aula) do
			local character = player.Character
			if character then
				local seen, distance = canSee(teacher, character)
				SuspicionService.setSight(player, seen, distance)
			else
				SuspicionService.setSight(player, false, math.huge)
			end
		end
	end
end

-- ── movimiento ─────────────────────────────────────────────────────

local function walkTo(teacher: Teacher, destination: Vector3, timeout: number?): boolean
	local humanoid = teacher.humanoid
	if not humanoid.Parent then
		return false
	end

	local path = PathfindingService:CreatePath({
		AgentRadius = 2.4,
		AgentHeight = 5.5,
		AgentCanJump = false,
		WaypointSpacing = 4,
	})

	local ok = pcall(function()
		path:ComputeAsync(teacher.root.Position, destination)
	end)

	local deadline = os.clock() + (timeout or 12)

	if ok and path.Status == Enum.PathStatus.Success then
		for _, waypoint in path:GetWaypoints() do
			if not teacher.alive or os.clock() > deadline then
				return false
			end
			humanoid:MoveTo(waypoint.Position)
			local reached = humanoid.MoveToFinished:Wait()
			if not reached then
				break
			end
		end
		return true
	end

	-- Sin ruta calculada, se va derecho: el aula es un rectangulo
	-- vacio, casi siempre alcanza.
	humanoid:MoveTo(destination)
	humanoid.MoveToFinished:Wait()
	return true
end

local function facePoint(teacher: Teacher, point: Vector3)
	local from = teacher.root.Position
	local flat = Vector3.new(point.X, from.Y, point.Z)
	if (flat - from).Magnitude > 0.2 then
		teacher.root.CFrame = CFrame.lookAt(from, flat)
	end
end

-- ── cerebro ────────────────────────────────────────────────────────

local function nearestSuspect(teacher: Teacher): (Player?, number)
	local best: Player? = nil
	local bestValue = Config.Sospecha.UmbralAviso
	for _, player in playersOfRoom(teacher.aula) do
		local value = SuspicionService.value(player)
		if value >= bestValue then
			bestValue = value
			best = player
		end
	end
	return best, bestValue
end

--- El punto de patrulla mas cercano a una posicion.
local function closestPatrolPoint(room: any, position: Vector3): Vector3
	local best = room.patrol[1]
	local bestDistance = math.huge
	for _, point in room.patrol do
		local distance = (point - position).Magnitude
		if distance < bestDistance then
			bestDistance = distance
			best = point
		end
	end
	return best
end

local function doPatrol(teacher: Teacher)
	local room = teacher.room
	if #room.patrol == 0 then
		task.wait(1)
		return
	end
	local point = room.patrol[rng:NextInteger(1, #room.patrol)]

	-- Si alguien ya viene raro pero todavia no cruzo el umbral, el
	-- profesor se va acercando a esa fila. Es el aviso justo: se ve
	-- venir y todavia se puede parar la mano.
	local suspect = nearestSuspect(teacher)
	if suspect then
		local character = suspect.Character
		local suspectRoot = character and character:FindFirstChild("HumanoidRootPart")
		if suspectRoot and suspectRoot:IsA("BasePart") then
			point = closestPatrolPoint(room, suspectRoot.Position)
		end
	end
	teacher.humanoid.WalkSpeed = P.VelocidadPatrulla
	walkTo(teacher, point, 14)
	if not teacher.alive then
		return
	end

	-- Se planta y mira la fila un momento: es cuando mas peligroso es
	-- moverse, y le da ritmo al examen.
	facePoint(teacher, room.center)
	task.wait(Util.randomInRange(P.PausaEnFila, rng))

	if os.clock() > teacher.nextLine and rng:NextNumber() < 0.35 then
		teacher.nextLine = os.clock() + 18
		local lines = { "teacher.silence", "teacher.eyes_on_paper" }
		say(teacher, lines[rng:NextInteger(1, #lines)])
	end
end

local function doBlackboard(teacher: Teacher)
	local room = teacher.room
	local spot = room.blackboard.Position + room.dir * 4.5
	teacher.humanoid.WalkSpeed = P.VelocidadPatrulla
	walkTo(teacher, Vector3.new(spot.X, teacher.root.Position.Y, spot.Z), 12)
	if not teacher.alive then
		return
	end

	-- De espaldas al aula: la ventana para copiar.
	facePoint(teacher, room.blackboard.Position)
	chalkboard(room, CHALK[rng:NextInteger(1, #CHALK)])
	orientChalkboard(room)
	say(teacher, "teacher.blackboard")
	Util.playSound(Config.Sonidos.Tiza, room.blackboard, 0.25, 1.5)

	task.wait(Util.randomInRange(P.PausaEnPizarra, rng))
end

local function doNoise(teacher: Teacher)
	local target = teacher.target
	if not target then
		return
	end
	teacher.target = nil
	teacher.humanoid.WalkSpeed = P.VelocidadPatrulla * 1.5
	say(teacher, "teacher.noise")
	walkTo(teacher, target, 10)
	if teacher.alive then
		facePoint(teacher, target)
		task.wait(1.6)
	end
end

local function doChase(teacher: Teacher)
	local player = teacher.chasing
	if not player or not player.Parent then
		teacher.chasing = nil
		return
	end

	teacher.humanoid.WalkSpeed = P.VelocidadPersecucion
	say(teacher, "teacher.caught", { name = player.DisplayName })

	local deadline = os.clock() + 9
	while teacher.alive and os.clock() < deadline do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			break
		end
		local distance = (root.Position - teacher.root.Position).Magnitude
		if distance <= 6 then
			facePoint(teacher, root.Position)
			local handler = punishHandler
			if handler then
				handler(player, teacher)
			end
			break
		end
		teacher.humanoid:MoveTo(root.Position)
		task.wait(P.IntervaloRepensar)
	end

	teacher.chasing = nil
	teacher.humanoid.WalkSpeed = P.VelocidadPatrulla
end

local function brain(teacher: Teacher)
	while teacher.alive do
		local ok, err = pcall(function()
			if teacher.chasing then
				doChase(teacher)
			elseif teacher.target then
				doNoise(teacher)
			elseif examMode and rng:NextNumber() < P.ProbabilidadPizarra then
				doBlackboard(teacher)
			else
				doPatrol(teacher)
			end
		end)
		if not ok then
			warn("[Profesor] " .. tostring(err))
			task.wait(1)
		end
		task.wait(0.1)
	end
end

-- ── entrada ────────────────────────────────────────────────────────

function TeacherAI.onPunish(handler: (Player, any) -> ())
	punishHandler = handler :: any
end

function TeacherAI.spawn(room: any)
	TeacherAI.despawn(room.index)

	local name = CharacterService.randomTeacherName()
	local model = CharacterService.teacher(name, room.spawn)
	model.Name = "Profesor" .. room.index
	model.Parent = CharacterService.folder()

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model.PrimaryPart :: BasePart

	local teacher: Teacher = {
		aula = room.index,
		name = name,
		model = model,
		humanoid = humanoid,
		root = root,
		room = room,
		state = "patrullar",
		target = nil,
		chasing = nil,
		alive = true,
		nextLine = 0,
		animation = CharacterService.animate(model),
	}
	teachers[room.index] = teacher

	chalkboard(room, CHALK[rng:NextInteger(1, #CHALK)])
	orientChalkboard(room)

	task.spawn(brain, teacher)
	return teacher
end

function TeacherAI.despawn(aula: number)
	local teacher = teachers[aula]
	if not teacher then
		return
	end
	teacher.alive = false
	if teacher.animation then
		teacher.animation:Disconnect()
	end
	if teacher.model.Parent then
		teacher.model:Destroy()
	end
	teachers[aula] = nil
end

function TeacherAI.despawnAll()
	for aula in teachers do
		TeacherAI.despawn(aula)
	end
end

function TeacherAI.get(aula: number): any
	return teachers[aula]
end

function TeacherAI.setExamMode(on: boolean)
	examMode = on
	for _, teacher in teachers do
		if on then
			say(teacher, "teacher.start_exam", { s = Config.Ronda.SegundosExamen })
		end
	end
end

--- Alguien tiro algo: el profesor del aula mas cercana va a mirar.
function TeacherAI.hearNoise(position: Vector3, _source: Player?)
	local best: Teacher? = nil
	local bestDistance = P.RadioAlerta
	for _, teacher in teachers do
		local distance = (teacher.root.Position - position).Magnitude
		if distance < bestDistance then
			bestDistance = distance
			best = teacher
		end
	end
	if best and not best.chasing then
		best.target = position
	end
end

--- El alumno cruzo el umbral: el profesor de su aula sale a buscarlo.
function TeacherAI.pursue(player: Player)
	local sitting = ExamService.sitting(player)
	local aula = sitting and sitting.aula or 1
	local teacher = teachers[aula]
	if not teacher then
		for _, candidate in teachers do
			teacher = candidate
			break
		end
	end
	if teacher and not teacher.chasing then
		teacher.chasing = player
		teacher.target = nil
	end
end

function TeacherAI.sayAll(key: string, args: { [string]: any }?)
	for _, teacher in teachers do
		say(teacher, key, args)
	end
end

function TeacherAI.start()
	if vision then
		return
	end
	local accumulator = 0
	vision = RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		accumulator = 0
		local ok, err = pcall(visionStep)
		if not ok then
			warn("[Profesor] vision: " .. tostring(err))
		end
	end)

	SuspicionService.onThreshold(function(player, _reason)
		TeacherAI.pursue(player)
	end)
end

return TeacherAI

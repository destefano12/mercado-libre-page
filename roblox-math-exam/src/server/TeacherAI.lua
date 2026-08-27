--!strict
--[[
	TeacherAI
	------------------------------------------------------------------
	El profesor. Es lo unico que separa al alumno de un 10 facil.

	Ciclo de comportamiento:
		Patrullando  -> recorre pasillo por pasillo entre los bancos
		Revisando    -> frena en un banco, se planta y mira la prueba
		Pizarron     -> se da vuelta a escribir (ventana segura para copiarse)
		Confrontando -> te vio con el celu y viene derecho a tu banco

	Vision:
		cono de FOV configurable + raycast real (los bancos y las paredes
		tapan). La cabeza gira (Motor6D del cuello), asi que el cono que
		ve el jugador en pantalla coincide con lo que "ve" el profe.
--]]

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterArt = require(Shared:WaitForChild("CharacterArt"))
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local T = Config.Teacher

local TeacherAI = {}
TeacherAI.__index = TeacherAI

export type Teacher = typeof(setmetatable({} :: any, TeacherAI))

local PHRASES = {
	patrol = {
		"Sin hablar, por favor.",
		"Tienen que justificar todos los pasos.",
		"Les quedan pocos minutos.",
		"El que copia se lleva un uno.",
	},
	board = {
		"Ojo con el signo del segundo termino.",
		"Anoto la formula en el pizarron.",
		"Ejercicio 5, presten atencion.",
	},
	inspect = {
		"A ver esa hoja...",
		"Mmm. Ese planteo no cierra.",
		"Muy bien ese desarrollo.",
	},
	caught = {
		"Dame ese telefono. Ahora.",
		"Te vi. Guardalo o te llevas un uno.",
		"En serio? Con el celular en la prueba?",
	},
}

local function pick(list: { string }): string
	return list[math.random(1, #list)]
end

local INSPECT_NPC = {
	"Bien ese planteo.",
	"Prolijo, me gusta.",
	"Che, esa cuenta esta mal.",
	"Seguí asi.",
	"Menos borrones, por favor.",
}

-- ─────────────────────────────────────────────────────────────
-- Rig
-- ─────────────────────────────────────────────────────────────

local function buildFallbackRig(): Model
	-- Rig estilizado por si no se puede crear un avatar real
	-- (Studio sin acceso a la API de avatares).
	local model = Instance.new("Model")
	model.Name = "Profesor"

	local root = Util.part({
		Name = "HumanoidRootPart",
		Size = Vector3.new(2, 2, 1),
		CFrame = CFrame.new(0, 3, 0),
		Transparency = 1,
		Anchored = false,
		CanCollide = true,
		Parent = model,
	})

	local function bodyPart(name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material)
		local part = Util.part({
			Name = name,
			Size = size,
			CFrame = root.CFrame * CFrame.new(offset),
			Color = color,
			Material = material,
			Anchored = false,
			CanCollide = false,
			Parent = model,
		})
		Util.weld(root, part)
		return part
	end

	local suit = Color3.fromRGB(58, 62, 76)
	local torso = bodyPart("Torso", Vector3.new(2.2, 2.4, 1.1), Vector3.new(0, 0.2, 0), suit, Enum.Material.Fabric)
	bodyPart("Camisa", Vector3.new(0.9, 2.2, 1.2), Vector3.new(0, 0.25, -0.02), Color3.fromRGB(232, 236, 242), Enum.Material.Fabric)
	bodyPart("Corbata", Vector3.new(0.35, 1.6, 1.3), Vector3.new(0, 0.1, -0.02), Color3.fromRGB(122, 38, 44), Enum.Material.Fabric)
	local head = bodyPart("Head", Vector3.new(1.5, 1.5, 1.5), Vector3.new(0, 2.1, 0), Color3.fromRGB(226, 190, 156), Enum.Material.SmoothPlastic)

	-- La cabeza cuelga de un Motor6D "Neck": asi tambien gira en el rig
	-- de respaldo y el cono de vision coincide con lo que se ve.
	for _, weld in root:GetChildren() do
		if weld:IsA("WeldConstraint") then
			if (weld :: WeldConstraint).Part1 == head then
				weld:Destroy()
			end
		end
	end
	local neck = Instance.new("Motor6D")
	neck.Name = "Neck"
	neck.Part0 = torso
	neck.Part1 = head
	neck.C0 = CFrame.new(0, 1.2, 0)
	neck.C1 = CFrame.new(0, -0.7, 0)
	neck.Parent = torso
	bodyPart("BrazoIzq", Vector3.new(0.9, 2.2, 0.9), Vector3.new(-1.6, 0.2, 0), suit, Enum.Material.Fabric)
	bodyPart("BrazoDer", Vector3.new(0.9, 2.2, 0.9), Vector3.new(1.6, 0.2, 0), suit, Enum.Material.Fabric)
	bodyPart("PiernaIzq", Vector3.new(0.9, 2.4, 0.9), Vector3.new(-0.55, -2.2, 0), Color3.fromRGB(42, 46, 58), Enum.Material.Fabric)
	bodyPart("PiernaDer", Vector3.new(0.9, 2.4, 0.9), Vector3.new(0.55, -2.2, 0), Color3.fromRGB(42, 46, 58), Enum.Material.Fabric)

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 3.4
	humanoid.Parent = model

	model.PrimaryPart = root
	head.Name = "Head"
	return model
end

local function buildAvatarRig(): Model?
	local description = Instance.new("HumanoidDescription")
	description.HeightScale = 1.05
	description.BodyTypeScale = 0.4
	description.ProportionScale = 0.6
	description.HeadColor = Color3.fromRGB(226, 190, 156)
	description.TorsoColor = Color3.fromRGB(58, 62, 76)
	description.LeftArmColor = Color3.fromRGB(226, 190, 156)
	description.RightArmColor = Color3.fromRGB(226, 190, 156)
	description.LeftLegColor = Color3.fromRGB(42, 46, 58)
	description.RightLegColor = Color3.fromRGB(42, 46, 58)

	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if ok and model then
		return model
	end
	return nil
end

-- ─────────────────────────────────────────────────────────────
-- Constructor
-- ─────────────────────────────────────────────────────────────

function TeacherAI.new(classroom, onCatch: (Player) -> ())
	local self = setmetatable({}, TeacherAI)

	self.classroom = classroom
	self.onCatch = onCatch
	self.state = "Patrullando"
	self.gazeYaw = 0
	self.targetGazeYaw = 0
	self.inspectTarget = nil :: Player?
	self.confrontTarget = nil :: Player?
	self.running = false
	self.rng = Random.new(os.clock() * 1000)
	self.nodeIndex = 1

	local model = buildAvatarRig() or buildFallbackRig()
	model.Name = "Profesor"

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	assert(humanoid, "El rig del profesor no tiene Humanoid")
	humanoid.WalkSpeed = T.WalkSpeed
	humanoid.DisplayName = T.DisplayName
	humanoid.NameDisplayDistance = 60
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false

	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	assert(root, "El rig del profesor no tiene HumanoidRootPart")

	self.model = model
	self.humanoid = humanoid
	self.root = root
	self.head = (model:FindFirstChild("Head") :: BasePart?) or root
	self.neck = model:FindFirstChild("Neck", true)
	self.neckBase = if self.neck and self.neck:IsA("Motor6D") then self.neck.C0 else nil

	model.Parent = workspace
	model:PivotTo(classroom.teacherSpawn)

	-- Cara, canas y anteojos. El profe tiene que leerse de lejos: si esta
	-- contento o hecho una furia se tiene que ver desde el fondo del aula.
	local skin = Color3.fromRGB(226, 190, 156)
	self.face = CharacterArt.attachFace(self.head, skin)
	CharacterArt.attachOldHair(self.head)
	CharacterArt.attachGlasses(self.head)

	self.mood = "neutral"
	self.moodUntil = 0
	self.alertUntil = 0
	self.nextBlink = os.clock() + 3

	self:_setupAnimations()
	self:_buildBubble()

	return self
end

function TeacherAI:_setupAnimations()
	local animator = self.humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", self.humanoid)
	local function load(id: string): AnimationTrack?
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		return ok and track or nil
	end

	self.animations = {
		idle = load("rbxassetid://507766666"),
		walk = load("rbxassetid://507777826"),
		write = load("rbxassetid://507770239"),
	}
	if self.animations.idle then
		self.animations.idle:Play(0.3)
	end
end

function TeacherAI:_playAnim(name: string)
	if self.currentAnim == name then
		return
	end
	self.currentAnim = name
	for key, track in self.animations do
		if track then
			if key == name then
				track:Play(0.25)
			else
				track:Stop(0.25)
			end
		end
	end
end

function TeacherAI:_buildBubble()
	local billboard = Util.billboard(self.head, UDim2.fromScale(9, 2.4), Vector3.new(0, 3.2, 0))
	billboard.Name = "Dialogo"
	billboard.AlwaysOnTop = true
	billboard.Enabled = false
	billboard.MaxDistance = 90
	billboard.Parent = self.head

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	frame.BackgroundTransparency = 0.12
	frame.Parent = billboard
	Util.roundify(frame, 14, Color3.fromRGB(90, 96, 112), 2)

	local label = Instance.new("TextLabel")
	label.Name = "Texto"
	label.Size = UDim2.fromScale(0.9, 0.7)
	label.Position = UDim2.fromScale(0.05, 0.15)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(240, 242, 248)
	label.TextScaled = true
	label.Text = ""
	label.Parent = frame

	self.bubble = billboard
	self.bubbleLabel = label
end

function TeacherAI:say(text: string, duration: number?)
	self.bubbleLabel.Text = text
	self.bubble.Enabled = true
	self.speechToken = (self.speechToken or 0) + 1
	local token = self.speechToken
	task.delay(duration or 3.2, function()
		if self.speechToken == token and self.bubble then
			self.bubble.Enabled = false
		end
	end)
end

--- Le fuerza una expresion por unos segundos (por ejemplo al retar a alguien).
function TeacherAI:setMood(name: string, duration: number?)
	self.mood = name
	self.moodUntil = os.clock() + (duration or 2.5)
end

--- "Algo raro vi": lo pone en cara de sospecha un ratito.
function TeacherAI:alert(duration: number?)
	self.alertUntil = math.max(self.alertUntil, os.clock() + (duration or 0.8))
end

--- Expresion que corresponde a lo que esta haciendo y viendo.
function TeacherAI:_currentExpression(now: number): string
	if now < self.moodUntil then
		return self.mood
	end
	if self.state == "Confrontando" then
		return "enojado"
	end
	if now < self.alertUntil then
		return "sospecha"
	end
	if self.state == "Pizarron" then
		return "contento"
	end
	if self.state == "Revisando" then
		return self.inspectMood or "contento"
	end
	return "neutral"
end

-- ─────────────────────────────────────────────────────────────
-- Movimiento
-- ─────────────────────────────────────────────────────────────

function TeacherAI:_moveTo(goal: Vector3, timeout: number?): boolean
	local humanoid: Humanoid = self.humanoid
	local root: BasePart = self.root
	local deadline = os.clock() + (timeout or 14)

	local path = PathfindingService:CreatePath({
		AgentRadius = 2.6,
		AgentHeight = 6,
		AgentCanJump = false,
		WaypointSpacing = 4,
	})

	local ok = pcall(function()
		path:ComputeAsync(root.Position, goal)
	end)

	local waypoints: { Vector3 } = {}
	if ok and path.Status == Enum.PathStatus.Success then
		for i, waypoint in path:GetWaypoints() do
			if i > 1 then
				table.insert(waypoints, waypoint.Position)
			end
		end
	end
	if #waypoints == 0 then
		waypoints = { goal }
	end

	for _, point in waypoints do
		humanoid:MoveTo(point)
		local lastDistance = math.huge
		local stuckFor = 0
		while self.running do
			local distance = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(point.X, 0, point.Z)).Magnitude
			if distance < 2.2 then
				break
			end
			if os.clock() > deadline then
				return false
			end
			if distance > lastDistance - 0.05 then
				stuckFor += 0.1
				if stuckFor > 2 then
					return false
				end
			else
				stuckFor = 0
			end
			lastDistance = distance
			humanoid:MoveTo(point)
			task.wait(0.1)
		end
	end
	return true
end

function TeacherAI:_faceTowards(position: Vector3, duration: number?)
	local root: BasePart = self.root
	local elapsed = 0
	local total = duration or 0.45
	local start = root.CFrame
	local flat = Vector3.new(position.X, root.Position.Y, position.Z)
	if (flat - root.Position).Magnitude < 0.1 then
		return
	end
	local goal = CFrame.lookAt(root.Position, flat)
	while elapsed < total and self.running do
		local dt = task.wait()
		elapsed += dt
		local alpha = math.clamp(elapsed / total, 0, 1)
		root.CFrame = start:Lerp(goal, alpha)
	end
end

-- ─────────────────────────────────────────────────────────────
-- Vision
-- ─────────────────────────────────────────────────────────────

function TeacherAI:getGazeCFrame(): CFrame
	local head: BasePart = self.head
	local root: BasePart = self.root
	local origin = head.Position
	local look = (root.CFrame * CFrame.Angles(0, self.gazeYaw, 0)).LookVector
	return CFrame.lookAt(origin, origin + look)
end

--- Devuelve visible (bool) y factor 0..1 (1 = de frente y cerca).
function TeacherAI:canSee(position: Vector3, ignore: { Instance }?): (boolean, number)
	if self.state == "Pizarron" then
		-- De espaldas: literalmente no puede ver nada del aula.
		return false, 0
	end

	local gaze = self:getGazeCFrame()
	local delta = position - gaze.Position
	local distance = delta.Magnitude
	if distance > T.ViewDistance or distance < 0.05 then
		return false, 0
	end

	local direction = delta.Unit
	local dot = direction:Dot(gaze.LookVector)
	local halfFov = math.rad(T.FieldOfView / 2)
	local angle = math.acos(math.clamp(dot, -1, 1))
	if angle > halfFov then
		return false, 0
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filter: { Instance } = { self.model }
	if ignore then
		for _, instance in ignore do
			table.insert(filter, instance)
		end
	end
	params.FilterDescendantsInstances = filter
	params.IgnoreWater = true

	local result = workspace:Raycast(gaze.Position, direction * distance, params)
	if result then
		return false, 0
	end

	-- Centro del cono = 1, borde = PeripheralFactor. Lejos = menos.
	local focus = 1 - (angle / halfFov)
	local proximity = 1 - (distance / T.ViewDistance) * 0.65
	local factor = math.clamp((T.PeripheralFactor + (1 - T.PeripheralFactor) * focus) * proximity, 0, 1)
	return true, factor
end

function TeacherAI:isInspecting(player: Player): boolean
	return self.inspectTarget == player
end

function TeacherAI:getState(): string
	return self.state
end

-- ─────────────────────────────────────────────────────────────
-- Comportamiento
-- ─────────────────────────────────────────────────────────────

function TeacherAI:_nearestDeskWithStudent(position: Vector3, maxDistance: number)
	local best, bestDistance = nil, maxDistance
	for _, desk in self.classroom.desks do
		local occupant = desk.seat.Occupant or desk.model:GetAttribute("Ocupado")
		if occupant then
			local distance = (desk.seat.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = desk, distance
			end
		end
	end
	return best
end

function TeacherAI:_inspect(desk)
	local occupant = desk.seat.Occupant
	local character = occupant and occupant.Parent
	local player = character and Players:GetPlayerFromCharacter(character)

	-- Tambien frena en los bancos de los companeros: eso es lo que hace
	-- que pase por al lado tuyo sin que sea siempre por vos.
	if not player then
		self.state = "Revisando"
		self.inspectMood = "contento"
		self:_playAnim("idle")
		self:_faceTowards(desk.seat.Position, 0.4)
		self.targetGazeYaw = 0
		if self.rng:NextNumber() < 0.6 then
			self:say(INSPECT_NPC[self.rng:NextInteger(1, #INSPECT_NPC)], 2.4)
		end
		local wait = Util.randomInRange(T.InspectDuration, self.rng) * 0.7
		local spent = 0
		while spent < wait and self.running and self.state == "Revisando" do
			spent += task.wait(0.1)
		end
		if self.state == "Revisando" then
			self.state = "Patrullando"
		end
		return
	end

	self.state = "Revisando"
	self.inspectTarget = player
	self.inspectMood = "contento"
	self:_playAnim("idle")
	self:_faceTowards(desk.seat.Position, 0.4)
	self.targetGazeYaw = 0
	if self.rng:NextNumber() < 0.5 then
		local phrase = pick(PHRASES.inspect)
		self:say(phrase, 2.6)
		self.inspectMood = phrase:find("no cierra") and "sospecha" or "contento"
	end

	local duration = Util.randomInRange(T.InspectDuration, self.rng)
	local elapsed = 0
	while elapsed < duration and self.running and self.state == "Revisando" do
		elapsed += task.wait(0.1)
	end

	self.inspectTarget = nil
	if self.state == "Revisando" then
		self.state = "Patrullando"
	end
end

function TeacherAI:_goToBoard()
	self.state = "Pizarron"
	self.inspectTarget = nil
	self:_playAnim("walk")
	self:_moveTo(self.classroom.boardStand.Position, 12)
	self:_faceTowards(self.classroom.boardStand.Position + self.classroom.boardStand.LookVector * 6, 0.5)
	self.targetGazeYaw = 0
	self:_playAnim("write")
	self:say(pick(PHRASES.board), 3)

	local duration = Util.randomInRange(T.BoardDuration, self.rng)
	local elapsed = 0
	while elapsed < duration and self.running and self.state == "Pizarron" do
		elapsed += task.wait(0.1)
	end

	if self.state == "Pizarron" then
		self.state = "Patrullando"
	end
end

function TeacherAI:_patrolStep()
	local nodes = self.classroom.patrolNodes
	if #nodes == 0 then
		task.wait(1)
		return
	end

	self.nodeIndex = self.nodeIndex % #nodes + 1
	local node = nodes[self.nodeIndex]

	self.state = "Patrullando"
	self:_playAnim("walk")
	self:_moveTo(node.Position, 12)
	self:_playAnim("idle")

	if not self.running or self.state == "Confrontando" then
		return
	end

	-- Frena a mirar un banco cercano
	if self.rng:NextNumber() < T.InspectChance then
		local desk = self:_nearestDeskWithStudent(self.root.Position, 12)
		if desk then
			self:_inspect(desk)
			return
		end
	end

	if self.rng:NextNumber() < 0.12 then
		self:say(pick(PHRASES.patrol), 3)
	end

	task.wait(Util.randomInRange(T.IdleAtWaypoint, self.rng))
end

--- Interrumpe todo y va derecho al banco del jugador.
function TeacherAI:confront(player: Player)
	if self.state == "Confrontando" then
		return
	end
	self.confrontTarget = player
	self.state = "Confrontando"
	self.inspectTarget = nil

	task.spawn(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		self.humanoid.WalkSpeed = T.ChaseSpeed
		self:_playAnim("walk")
		self:setMood("enojado", 6)
		self:say(pick(PHRASES.caught), 3.4)

		if root then
			local approach = root.Position + (self.root.Position - root.Position).Unit * 4
			self:_moveTo(Vector3.new(approach.X, root.Position.Y, approach.Z), 10)
			self:_faceTowards(root.Position, 0.35)
		end

		self:_playAnim("idle")
		self.humanoid.WalkSpeed = T.WalkSpeed
		self.onCatch(player)

		task.wait(1.6)
		self.confrontTarget = nil
		if self.state == "Confrontando" then
			self.state = "Patrullando"
		end
	end)
end

-- ─────────────────────────────────────────────────────────────
-- Loop
-- ─────────────────────────────────────────────────────────────

function TeacherAI:start()
	if self.running then
		return
	end
	self.running = true

	-- Cerebro
	task.spawn(function()
		while self.running do
			if self.state == "Confrontando" then
				task.wait(0.2)
			elseif os.clock() - (self.lastBoardAt or 0) > 28 and self.rng:NextNumber() < T.BoardChance then
				self.lastBoardAt = os.clock()
				self:_goToBoard()
			else
				self:_patrolStep()
			end
		end
	end)

	-- Cabeza: barrido lateral mientras camina, fija cuando revisa.
	self.gazeConnection = RunService.Heartbeat:Connect(function(dt)
		if self.state == "Patrullando" then
			self.targetGazeYaw = math.sin(os.clock() * 0.85) * math.rad(38)
		elseif self.state == "Revisando" or self.state == "Confrontando" then
			self.targetGazeYaw = 0
		elseif self.state == "Pizarron" then
			self.targetGazeYaw = 0
		end

		self.gazeYaw = Util.lerpAngle(self.gazeYaw, self.targetGazeYaw, math.clamp(dt * T.HeadTurnSpeed, 0, 1))

		if self.face then
			local now = os.clock()
			self.face.setExpression(self:_currentExpression(now))
			-- Los ojos siguen el barrido de la cabeza, medio paso adelante.
			self.face.look(math.clamp(self.gazeYaw * 1.6, -1, 1), 0)
			if now > self.nextBlink then
				self.nextBlink = now + math.random(3, 7)
				self.face.blink()
			end
		end

		if self.neck and self.neckBase then
			(self.neck :: Motor6D).C0 = self.neckBase * CFrame.Angles(0, self.gazeYaw, 0)
		end
	end)
end

function TeacherAI:destroy()
	self.running = false
	if self.gazeConnection then
		self.gazeConnection:Disconnect()
	end
	if self.model then
		self.model:Destroy()
	end
end

return TeacherAI

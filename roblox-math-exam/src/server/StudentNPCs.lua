--!strict
--[[
	StudentNPCs
	------------------------------------------------------------------
	Los compañeros de curso. El aula llena cambia todo: el profe frena
	en bancos que no son el tuyo, hay alguien al lado tuyo escribiendo,
	y cuando el profe se acerca se pone nervioso medio curso.

	Son rigs sentados hechos a mano y anclados: no tienen Humanoid ni
	fisica, asi que doce alumnos no cuestan nada. Se animan moviendo
	unas pocas partes (mano que escribe, cabeza que se gira, cara que
	cambia de humor) desde un solo loop.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterArt = require(Shared:WaitForChild("CharacterArt"))
local Util = require(Shared:WaitForChild("Util"))

local StudentNPCs = {}

local NAMES = {
	"Sofi", "Tomi", "Nacho", "Cami", "Juli", "Fran", "Mati", "Lupe",
	"Bauti", "Emi", "Vale", "Santi", "Pipa", "Joaco", "Ari", "Nico",
}

local SKINS = {
	Color3.fromRGB(238, 200, 168),
	Color3.fromRGB(222, 178, 140),
	Color3.fromRGB(198, 148, 110),
	Color3.fromRGB(152, 106, 74),
	Color3.fromRGB(108, 74, 52),
	Color3.fromRGB(248, 218, 192),
}

local HAIR_COLORS = {
	Color3.fromRGB(38, 30, 26),
	Color3.fromRGB(72, 48, 32),
	Color3.fromRGB(120, 82, 46),
	Color3.fromRGB(186, 146, 82),
	Color3.fromRGB(96, 42, 34),
	Color3.fromRGB(28, 26, 30),
}

local SWEATERS = {
	Color3.fromRGB(44, 62, 118),
	Color3.fromRGB(126, 46, 54),
	Color3.fromRGB(48, 96, 82),
	Color3.fromRGB(72, 66, 88),
	Color3.fromRGB(38, 42, 52),
	Color3.fromRGB(158, 96, 52),
}

type Student = {
	desk: any,
	model: Model,
	face: any,
	head: BasePart,
	headBase: CFrame,
	forearm: BasePart,
	forearmBase: CFrame,
	hand: BasePart,
	handBase: CFrame,
	torso: BasePart,
	torsoBase: CFrame,
	phase: number,
	writeSpeed: number,
	mood: string,
	moodUntil: number,
	glanceUntil: number,
	lastYaw: number,
	lastPitch: number,
}

local students: { [any]: Student } = {}
local classroom: any = nil
local teacher: any = nil
local running = false
local rng = Random.new(os.time())

-- ─────────────────────────────────────────────────────────────
-- Rig sentado
-- ─────────────────────────────────────────────────────────────

local function piece(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	return Util.part({
		Name = name,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Anchored = true,
		CanCollide = false,
		Parent = model,
	})
end

local function buildStudent(desk: any, index: number): Student
	local model = Instance.new("Model")
	model.Name = "Alumno_" .. index

	-- Origen = la superficie del asiento, mirando al pizarron.
	local origin = desk.seat.CFrame * CFrame.new(0, 0.18, 0)

	local skin = SKINS[rng:NextInteger(1, #SKINS)]
	local sweater = SWEATERS[rng:NextInteger(1, #SWEATERS)]
	local hairColor = HAIR_COLORS[rng:NextInteger(1, #HAIR_COLORS)]
	local style = CharacterArt.HairStyles[rng:NextInteger(1, #CharacterArt.HairStyles)]
	local guardapolvo = rng:NextNumber() < 0.45

	local shirtColor = guardapolvo and Color3.fromRGB(246, 246, 242) or sweater

	-- Cadera y torso (con una leve inclinacion hacia adelante, escribiendo)
	piece(model, "Cadera", Vector3.new(1.9, 0.7, 1.1), origin * CFrame.new(0, 0.35, 0),
		Color3.fromRGB(42, 46, 60), Enum.Material.Fabric)

	local torsoCF = origin * CFrame.new(0, 1.7, -0.05) * CFrame.Angles(math.rad(-7), 0, 0)
	local torso = piece(model, "Torso", Vector3.new(2.0, 2.0, 1.15), torsoCF, shirtColor, Enum.Material.Fabric)
	if guardapolvo then
		piece(model, "Cuello", Vector3.new(1.1, 0.3, 1.2), torsoCF * CFrame.new(0, 0.95, 0),
			Color3.fromRGB(214, 216, 222), Enum.Material.Fabric)
	end

	-- Piernas: muslo hacia adelante, pantorrilla hacia abajo, zapatilla
	for _, side in { -1, 1 } do
		piece(model, "Muslo", Vector3.new(0.85, 0.7, 1.7), origin * CFrame.new(side * 0.55, 0.05, -0.85),
			Color3.fromRGB(42, 46, 60), Enum.Material.Fabric)
		piece(model, "Pantorrilla", Vector3.new(0.8, 1.7, 0.8), origin * CFrame.new(side * 0.55, -0.85, -1.6),
			Color3.fromRGB(42, 46, 60), Enum.Material.Fabric)
		piece(model, "Zapatilla", Vector3.new(0.9, 0.35, 1.15), origin * CFrame.new(side * 0.55, -1.85, -1.85),
			Color3.fromRGB(30, 32, 40), Enum.Material.Fabric)
	end

	-- Brazo izquierdo apoyado, derecho escribiendo
	piece(model, "BrazoIzq", Vector3.new(0.7, 1.3, 0.7), origin * CFrame.new(-1.3, 1.75, -0.15), shirtColor, Enum.Material.Fabric)
	piece(model, "AntebrazoIzq", Vector3.new(0.65, 0.65, 1.5), origin * CFrame.new(-1.15, 1.05, -1.0), shirtColor, Enum.Material.Fabric)
	piece(model, "ManoIzq", Vector3.new(0.6, 0.42, 0.7), origin * CFrame.new(-1.05, 1.02, -1.75), skin)

	piece(model, "BrazoDer", Vector3.new(0.7, 1.3, 0.7), origin * CFrame.new(1.3, 1.75, -0.15), shirtColor, Enum.Material.Fabric)
	local forearm = piece(model, "AntebrazoDer", Vector3.new(0.65, 0.65, 1.5), origin * CFrame.new(1.15, 1.05, -1.0), shirtColor, Enum.Material.Fabric)
	local hand = piece(model, "ManoDer", Vector3.new(0.6, 0.42, 0.7), origin * CFrame.new(1.0, 1.02, -1.75), skin)
	piece(model, "Lapicera", Vector3.new(0.13, 0.13, 0.95),
		origin * CFrame.new(0.95, 0.98, -2.05) * CFrame.Angles(math.rad(-35), 0, 0),
		Color3.fromRGB(32, 46, 120))

	-- Cabeza
	local headCF = origin * CFrame.new(0, 3.3, -0.2)
	local head = piece(model, "Head", Vector3.new(1.35, 1.35, 1.35), headCF, skin)
	local face = CharacterArt.attachFace(head, skin)
	CharacterArt.attachHair(head, style, hairColor)
	if rng:NextNumber() < 0.25 then
		CharacterArt.attachGlasses(head, Color3.fromRGB(52, 56, 68))
	end

	-- Cartelito con el nombre
	local billboard = Util.billboard(head, UDim2.fromScale(4, 1), Vector3.new(0, 1.4, 0))
	billboard.Name = "Nombre"
	billboard.MaxDistance = 32
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.Text = NAMES[((index - 1) % #NAMES) + 1]
	label.TextColor3 = Color3.fromRGB(238, 240, 246)
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.Parent = billboard

	model.PrimaryPart = torso
	model.Parent = classroom.model

	return {
		desk = desk,
		model = model,
		face = face,
		head = head,
		headBase = headCF,
		forearm = forearm,
		forearmBase = forearm.CFrame,
		hand = hand,
		handBase = hand.CFrame,
		torso = torso,
		torsoBase = torsoCF,
		phase = rng:NextNumber() * math.pi * 2,
		writeSpeed = rng:NextNumber(2.2, 3.6),
		mood = "concentrado",
		moodUntil = 0,
		glanceUntil = 0,
		lastYaw = 0,
		lastPitch = 0,
	}
end

-- ─────────────────────────────────────────────────────────────
-- Alta y baja
-- ─────────────────────────────────────────────────────────────

function StudentNPCs.init(classroomRef: any, teacherRef: any)
	classroom = classroomRef
	teacher = teacherRef
end

--- Sienta un compañero en un banco vacio.
function StudentNPCs.occupy(desk: any)
	if not classroom or students[desk] then
		return
	end
	students[desk] = buildStudent(desk, desk.index)
	desk.model:SetAttribute("Ocupado", true)
end

--- Lo levanta y le deja el banco a un jugador.
function StudentNPCs.vacate(desk: any)
	local student = students[desk]
	if not student then
		return
	end
	student.model:Destroy()
	students[desk] = nil
	desk.model:SetAttribute("Ocupado", false)
end

function StudentNPCs.fillAll()
	for _, desk in classroom.desks do
		StudentNPCs.occupy(desk)
	end
end

--- Le cambia la cara a todo el curso (por ejemplo cuando pillan a alguien).
function StudentNPCs.reactAll(mood: string, duration: number)
	local until_ = os.clock() + duration
	for _, student in students do
		student.mood = mood
		student.moodUntil = until_
	end
end

-- ─────────────────────────────────────────────────────────────
-- Animacion
-- ─────────────────────────────────────────────────────────────

function StudentNPCs.start()
	if running then
		return
	end
	running = true

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		accumulator = 0

		local now = os.clock()
		local teacherPosition = teacher and teacher.root and teacher.root.Position
		local teacherState = teacher and teacher:getState() or "Patrullando"

		for _, student in students do
			-- Mano que escribe: circulitos chicos sobre la hoja. Se mueve la
			-- mano y nada mas: veinte alumnos moviendo medio cuerpo cada
			-- frame es plata tirada en replicacion.
			local t = now * student.writeSpeed + student.phase
			student.hand.CFrame = student.handBase * CFrame.new(math.sin(t) * 0.12, 0, math.cos(t * 1.7) * 0.09)

			-- La cabeza: mira la hoja, salvo que el profe este cerca
			local yaw, pitch = 0, math.rad(18)
			local mood = "concentrado"

			if teacherPosition then
				local distance = (teacherPosition - student.head.Position).Magnitude
				if distance < 14 then
					local flat = Vector3.new(teacherPosition.X, student.head.Position.Y, teacherPosition.Z)
					local direction = student.headBase:PointToObjectSpace(flat)
					yaw = math.clamp(math.atan2(-direction.X, -direction.Z), -1.1, 1.1)
					pitch = 0
					mood = distance < 8 and "nervioso" or "sospecha"
				end
			end

			if teacherState == "Confrontando" then
				mood = "sorprendido"
				pitch = 0
			end

			-- Miradita de reojo al banco de al lado, que para eso estamos
			if now > student.glanceUntil then
				student.glanceUntil = now + rng:NextNumber(6, 16)
				if rng:NextNumber() < 0.35 then
					student.face.look(rng:NextInteger(0, 1) == 0 and -1 or 1, 0)
					task.delay(1.2, function()
						if student.model.Parent then
							student.face.look(0, 0.2)
						end
					end)
				elseif rng:NextNumber() < 0.5 then
					student.face.blink()
				end
			end

			if now < student.moodUntil then
				mood = student.mood
			end

			student.face.setExpression(mood)

			-- La cabeza solo se reescribe si de verdad se movio.
			if math.abs(yaw - student.lastYaw) > 0.02 or math.abs(pitch - student.lastPitch) > 0.02 then
				student.lastYaw, student.lastPitch = yaw, pitch
				student.head.CFrame = student.headBase * CFrame.Angles(pitch, yaw, 0)
			end
		end
	end)
end

return StudentNPCs

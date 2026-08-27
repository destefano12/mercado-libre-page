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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

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
	Color3.fromRGB(58, 74, 112),
	Color3.fromRGB(118, 60, 62),
	Color3.fromRGB(62, 96, 86),
	Color3.fromRGB(78, 74, 92),
	Color3.fromRGB(46, 50, 60),
	Color3.fromRGB(152, 106, 68),
	Color3.fromRGB(186, 188, 192),
}

local PANTS = {
	Color3.fromRGB(56, 66, 88),     -- jean
	Color3.fromRGB(42, 46, 56),     -- negro
	Color3.fromRGB(96, 92, 84),     -- caqui
	Color3.fromRGB(72, 82, 104),
}

local SNEAKERS = {
	Color3.fromRGB(236, 236, 232),
	Color3.fromRGB(44, 48, 58),
	Color3.fromRGB(132, 56, 56),
	Color3.fromRGB(60, 82, 118),
}

type Student = {
	desk: any,
	model: Model,
	face: any,
	neck: Motor6D?,
	neckBase: CFrame?,
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

-- Un solo avatar de verdad y despues clones: pedirle veinte a Roblox
-- de a uno tarda una eternidad al arrancar.
local template: Model? = nil
local templateTried = false

local function avatarTemplate(): Model?
	if templateTried then
		return template
	end
	templateTried = true

	local ok, model = pcall(function()
		local description = Instance.new("HumanoidDescription")
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if ok and model then
		model.Name = "PlantillaAlumno"
		model.Parent = ServerStorage
		template = model
	end
	return template
end

local SIT_ANIMATION = "rbxassetid://2506281703"

--- Alumno con avatar de Roblox: cuerpo real, sentado en el banco.
local function buildAvatarStudent(desk: any, index: number): Student?
	local source = avatarTemplate()
	if not source then
		return nil
	end

	local model = source:Clone()
	model.Name = "Alumno_" .. index

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local head = model:FindFirstChild("Head") :: BasePart?
	if not humanoid or not head then
		model:Destroy()
		return nil
	end

	local skin = SKINS[rng:NextInteger(1, #SKINS)]
	local shirt = SWEATERS[rng:NextInteger(1, #SWEATERS)]
	local pants = PANTS[rng:NextInteger(1, #PANTS)]
	local shoes = SNEAKERS[rng:NextInteger(1, #SNEAKERS)]

	local COLORS = {
		Head = skin, LeftHand = skin, RightHand = skin, LeftLowerArm = skin, RightLowerArm = skin,
		UpperTorso = shirt, LowerTorso = shirt, LeftUpperArm = shirt, RightUpperArm = shirt,
		LeftUpperLeg = pants, RightUpperLeg = pants, LeftLowerLeg = pants, RightLowerLeg = pants,
		LeftFoot = shoes, RightFoot = shoes,
	}
	for name, color in COLORS do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Color = color
		end
	end

	CharacterArt.attachHair(head, CharacterArt.HairStyles[rng:NextInteger(1, #CharacterArt.HairStyles)],
		HAIR_COLORS[rng:NextInteger(1, #HAIR_COLORS)])

	humanoid.DisplayName = NAMES[((index - 1) % #NAMES) + 1]
	humanoid.NameDisplayDistance = 32
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0

	model.Parent = classroom.model
	model:PivotTo(desk.seat.CFrame * CFrame.new(0, 2.6, 0))

	-- Sentarlo y ponerle la pose de sentado del propio Roblox
	task.defer(function()
		if desk.seat and humanoid.Parent then
			desk.seat:Sit(humanoid)
		end
		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
		pcall(function()
			local animation = Instance.new("Animation")
			animation.AnimationId = SIT_ANIMATION
			local track = animator:LoadAnimation(animation)
			track.Priority = Enum.AnimationPriority.Idle
			track.Looped = true
			track:Play()
		end)
	end)

	local neck = model:FindFirstChild("Neck", true)

	return {
		desk = desk,
		model = model,
		face = nil,
		head = head,
		headBase = head.CFrame,
		neck = if neck and neck:IsA("Motor6D") then neck else nil,
		neckBase = if neck and neck:IsA("Motor6D") then neck.C0 else nil,
		forearm = head,
		forearmBase = head.CFrame,
		hand = head,
		handBase = head.CFrame,
		torso = head,
		torsoBase = head.CFrame,
		phase = rng:NextNumber() * math.pi * 2,
		writeSpeed = rng:NextNumber(2.2, 3.6),
		mood = "concentrado",
		moodUntil = 0,
		glanceUntil = 0,
		lastYaw = 0,
		lastPitch = 0,
	}
end

local function buildStudent(desk: any, index: number): Student
	local model = Instance.new("Model")
	model.Name = "Alumno_" .. index

	-- Origen = la superficie del asiento, mirando al pizarron.
	local origin = desk.seat.CFrame * CFrame.new(0, 0.18, 0)

	local skin = SKINS[rng:NextInteger(1, #SKINS)]
	local hairColor = HAIR_COLORS[rng:NextInteger(1, #HAIR_COLORS)]
	local style = CharacterArt.HairStyles[rng:NextInteger(1, #CharacterArt.HairStyles)]

	-- Tres pintas: buzo con capucha, remera y camisa clara. Nada de
	-- uniformes: en una escuela publica de Estados Unidos cada uno viene
	-- con lo suyo, pero la paleta se mantiene corta para que no sea un
	-- carnaval.
	local roll = rng:NextNumber()
	local hoodie = roll < 0.45
	local guardapolvo = roll >= 0.45 and roll < 0.62
	local shirtColor = guardapolvo and Color3.fromRGB(240, 240, 236) or SWEATERS[rng:NextInteger(1, #SWEATERS)]
	local pantsColor = PANTS[rng:NextInteger(1, #PANTS)]
	local sneakerColor = SNEAKERS[rng:NextInteger(1, #SNEAKERS)]

	-- Cadera y torso, con una leve inclinacion adelante (estan escribiendo)
	piece(model, "Cadera", Vector3.new(1.7, 0.65, 1.05), origin * CFrame.new(0, 0.32, 0),
		Color3.fromRGB(48, 52, 64), Enum.Material.Fabric)

	local torsoCF = origin * CFrame.new(0, 1.65, -0.05) * CFrame.Angles(math.rad(-8), 0, 0)
	local torso = piece(model, "Torso", Vector3.new(1.8, 1.95, 1.0), torsoCF, shirtColor, Enum.Material.Fabric)
	piece(model, "Hombros", Vector3.new(2.05, 0.42, 1.05), torsoCF * CFrame.new(0, 0.85, 0), shirtColor, Enum.Material.Fabric)
	piece(model, "Cuello", Vector3.new(0.65, 0.4, 0.65), torsoCF * CFrame.new(0, 1.12, 0.02), skin)

	if hoodie then
		-- Capucha caida sobre la espalda: lee "secundario" al instante
		piece(model, "Capucha", Vector3.new(1.5, 0.75, 0.55), torsoCF * CFrame.new(0, 0.82, 0.58), shirtColor, Enum.Material.Fabric)
		piece(model, "Bolsillo", Vector3.new(1.1, 0.5, 0.14), torsoCF * CFrame.new(0, -0.55, -0.55),
			shirtColor:Lerp(Color3.new(0, 0, 0), 0.12), Enum.Material.Fabric)
	elseif guardapolvo then
		piece(model, "Cierre", Vector3.new(0.1, 1.8, 0.12), torsoCF * CFrame.new(0, 0, -0.52),
			Color3.fromRGB(206, 208, 214), Enum.Material.Fabric)
	else
		piece(model, "Estampa", Vector3.new(0.85, 0.6, 0.12), torsoCF * CFrame.new(0, 0.05, -0.52),
			shirtColor:Lerp(Color3.new(1, 1, 1), 0.55), Enum.Material.Fabric)
	end

	-- Piernas: muslo adelante, pantorrilla abajo, zapatilla con suela
	for _, side in { -1, 1 } do
		piece(model, "Muslo", Vector3.new(0.78, 0.65, 1.7), origin * CFrame.new(side * 0.5, 0.02, -0.85),
			pantsColor, Enum.Material.Fabric)
		piece(model, "Pantorrilla", Vector3.new(0.72, 1.7, 0.72), origin * CFrame.new(side * 0.5, -0.9, -1.6),
			pantsColor, Enum.Material.Fabric)
		piece(model, "Zapatilla", Vector3.new(0.82, 0.32, 1.15), origin * CFrame.new(side * 0.5, -1.86, -1.85),
			sneakerColor, Enum.Material.Fabric)
		piece(model, "Suela", Vector3.new(0.86, 0.16, 1.2), origin * CFrame.new(side * 0.5, -2.05, -1.87),
			Color3.fromRGB(240, 240, 236), Enum.Material.SmoothPlastic)
	end

	-- Brazos: el izquierdo apoyado sujetando la hoja, el derecho escribiendo
	local sleeve = hoodie and shirtColor or (guardapolvo and shirtColor or skin)
	piece(model, "BrazoIzq", Vector3.new(0.62, 1.25, 0.62), origin * CFrame.new(-1.15, 1.7, -0.15), sleeve, Enum.Material.Fabric)
	piece(model, "AntebrazoIzq", Vector3.new(0.58, 0.58, 1.45), origin * CFrame.new(-1.02, 1.05, -1.0), sleeve, Enum.Material.Fabric)
	piece(model, "ManoIzq", Vector3.new(0.54, 0.38, 0.66), origin * CFrame.new(-0.95, 1.02, -1.72), skin)

	piece(model, "BrazoDer", Vector3.new(0.62, 1.25, 0.62), origin * CFrame.new(1.15, 1.7, -0.15), sleeve, Enum.Material.Fabric)
	local forearm = piece(model, "AntebrazoDer", Vector3.new(0.58, 0.58, 1.45), origin * CFrame.new(1.02, 1.05, -1.0), sleeve, Enum.Material.Fabric)
	local hand = piece(model, "ManoDer", Vector3.new(0.54, 0.38, 0.66), origin * CFrame.new(0.9, 1.02, -1.72), skin)
	piece(model, "Lapiz", Vector3.new(0.11, 0.11, 0.9),
		origin * CFrame.new(0.86, 0.98, -2.02) * CFrame.Angles(math.rad(-35), 0, 0),
		Color3.fromRGB(226, 178, 60))

	-- Cabeza
	local headCF = origin * CFrame.new(0, 3.25, -0.22)
	local head = piece(model, "Head", Vector3.new(1.25, 1.3, 1.25), headCF, skin)
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
		neck = nil,
		neckBase = nil,
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
	students[desk] = buildAvatarStudent(desk, desk.index) or buildStudent(desk, desk.index)
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
			-- Mano que escribe: circulitos chicos sobre la hoja. Solo en
			-- el rig propio; el avatar ya tiene su animacion de sentado.
			if not student.neck then
				local t = now * student.writeSpeed + student.phase
				student.hand.CFrame = student.handBase * CFrame.new(math.sin(t) * 0.12, 0, math.cos(t * 1.7) * 0.09)
			end

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
				if student.face and rng:NextNumber() < 0.35 then
					student.face.look(rng:NextInteger(0, 1) == 0 and -1 or 1, 0)
					task.delay(1.2, function()
						if student.model.Parent then
							student.face.look(0, 0.2)
						end
					end)
				elseif student.face and rng:NextNumber() < 0.5 then
					student.face.blink()
				end
			end

			if now < student.moodUntil then
				mood = student.mood
			end

			if student.face then
				student.face.setExpression(mood)
			end

			-- La cabeza solo se reescribe si de verdad se movio.
			if math.abs(yaw - student.lastYaw) > 0.02 or math.abs(pitch - student.lastPitch) > 0.02 then
				student.lastYaw, student.lastPitch = yaw, pitch
				if student.neck and student.neckBase then
					-- Avatar: la cabeza cuelga del cuello, no se mueve suelta.
					student.neck.C0 = student.neckBase * CFrame.Angles(pitch * 0.5, yaw, 0)
				else
					student.head.CFrame = student.headBase * CFrame.Angles(pitch, yaw, 0)
				end
			end
		end
	end)
end

return StudentNPCs

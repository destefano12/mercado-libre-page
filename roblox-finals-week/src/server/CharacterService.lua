--!strict
--[[
	CharacterService
	------------------------------------------------------------------
	La estetica de instituto: uniforme para los alumnos, el NPC del
	profesor armado hueso por hueso, las esteticas compradas en la
	tienda y el cono de la verguenza.

	El profesor se construye entero por codigo (rig R6 con Motor6D) en
	vez de usar un modelo del catalogo, por dos razones:
	  * no depende de ningun asset que pueda faltar o cambiar;
	  * podemos animarlo a mano (los NPC no caminan solos sin un script
	    Animate, y ese script solo existe en los avatares de jugador).
--]]

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Theme = require(Shared:WaitForChild("Theme"))
local Util = require(Shared:WaitForChild("Util"))

local P = Config.Profesor

local CharacterService = {}

local rng = Random.new()

-- ── uniforme del alumno ────────────────────────────────────────────

local UNIFORME = {
	Camisa = Color3.fromRGB(236, 238, 244),
	Sueter = Color3.fromRGB(52, 72, 116),
	Pantalon = Color3.fromRGB(44, 48, 60),
	Zapato = Color3.fromRGB(28, 30, 36),
}

local TORSOS = { "Torso", "UpperTorso", "LowerTorso" }
local BRAZOS = { "Left Arm", "Right Arm", "LeftUpperArm", "RightUpperArm",
	"LeftLowerArm", "RightLowerArm" }
local PIERNAS = { "Left Leg", "Right Leg", "LeftUpperLeg", "RightUpperLeg",
	"LeftLowerLeg", "RightLowerLeg" }
local PIES = { "LeftFoot", "RightFoot" }

local function paint(character: Model, names: { string }, color: Color3)
	for _, name in names do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Color = color
			part.Material = Enum.Material.SmoothPlastic
		end
	end
end

--- Un accesorio simple soldado a una parte del personaje.
local function attach(character: Model, anchorName: string, name: string,
	size: Vector3, offset: CFrame, color: Color3, material: Enum.Material): BasePart?
	local anchor = character:FindFirstChild(anchorName)
	if not anchor or not anchor:IsA("BasePart") then
		return nil
	end
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = anchor.CFrame * offset
	part.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
	return part
end

local ESTETICAS: { [string]: (Model) -> () } = {
	gorra = function(character)
		attach(character, "Head", "Gorra", Vector3.new(2.1, 0.55, 2.1),
			CFrame.new(0, 0.75, 0), Color3.fromRGB(168, 42, 52), Enum.Material.Fabric)
		attach(character, "Head", "Visera", Vector3.new(2.1, 0.16, 1.1),
			CFrame.new(0, 0.5, -1.05), Color3.fromRGB(140, 34, 44), Enum.Material.Fabric)
	end,
	anteojos = function(character)
		attach(character, "Head", "Anteojos", Vector3.new(1.9, 0.42, 0.14),
			CFrame.new(0, 0.06, -0.62), Color3.fromRGB(30, 32, 38), Enum.Material.SmoothPlastic)
	end,
	mochila = function(character)
		local anchor = character:FindFirstChild("UpperTorso") and "UpperTorso" or "Torso"
		attach(character, anchor, "Mochila", Vector3.new(1.7, 1.9, 0.85),
			CFrame.new(0, 0.1, 0.78), Color3.fromRGB(52, 92, 128), Enum.Material.Fabric)
		attach(character, anchor, "Correa", Vector3.new(0.3, 1.7, 0.2),
			CFrame.new(-0.55, 0.1, 0.42), Color3.fromRGB(38, 66, 94), Enum.Material.Fabric)
		attach(character, anchor, "Correa", Vector3.new(0.3, 1.7, 0.2),
			CFrame.new(0.55, 0.1, 0.42), Color3.fromRGB(38, 66, 94), Enum.Material.Fabric)
	end,
	campera = function(character)
		paint(character, TORSOS, Color3.fromRGB(96, 32, 42))
		paint(character, BRAZOS, Color3.fromRGB(96, 32, 42))
	end,
}

--- Cartel con el nombre arriba de la cabeza, discreto.
local function nameTag(character: Model, text: string, color: Color3)
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local existing = head:FindFirstChild("Etiqueta")
	if existing then
		existing:Destroy()
	end
	local billboard = Util.billboard(head, UDim2.new(0, 200, 0, 34), Vector3.new(0, 2.4, 0))
	billboard.Name = "Etiqueta"
	billboard.MaxDistance = 45
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Theme.FontBold
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextScaled = true
	label.Parent = billboard
end

--- Viste al alumno con el uniforme y le pone lo que tenga equipado.
function CharacterService.dressStudent(player: Player, character: Model, estetica: { [string]: boolean }?)
	local ok, err = pcall(function()
		paint(character, TORSOS, UNIFORME.Sueter)
		paint(character, BRAZOS, UNIFORME.Camisa)
		paint(character, PIERNAS, UNIFORME.Pantalon)
		paint(character, PIES, UNIFORME.Zapato)

		-- Corbata del colegio.
		local torso = character:FindFirstChild("UpperTorso") and "UpperTorso" or "Torso"
		attach(character, torso, "Corbata", Vector3.new(0.34, 1.1, 0.14),
			CFrame.new(0, 0.25, -0.55), Color3.fromRGB(122, 32, 44), Enum.Material.Fabric)

		for id, on in (estetica or {}) do
			if on and ESTETICAS[id] then
				ESTETICAS[id](character)
			end
		end

		nameTag(character, player.DisplayName, Color3.fromRGB(226, 232, 244))
	end)
	if not ok then
		warn("[Personajes] uniforme fallo: " .. tostring(err))
	end
end

-- ── cono de la verguenza ───────────────────────────────────────────

--- Un cono hecho con discos: no depende de ningun mesh.
function CharacterService.attachCone(character: Model)
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	if character:FindFirstChild("ConoDeLaVerguenza") then
		return
	end
	local cone = Instance.new("Model")
	cone.Name = "ConoDeLaVerguenza"
	cone.Parent = character

	local layers = 6
	for i = 0, layers - 1 do
		local alpha = i / layers
		local disc = Instance.new("Part")
		disc.Name = "Anillo" .. i
		disc.Shape = Enum.PartType.Cylinder
		disc.Size = Vector3.new(0.42, 2.2 * (1 - alpha) + 0.25, 2.2 * (1 - alpha) + 0.25)
		disc.Color = i % 2 == 0 and Color3.fromRGB(228, 74, 62) or Color3.fromRGB(246, 246, 240)
		disc.Material = Enum.Material.SmoothPlastic
		disc.CanCollide = false
		disc.CanQuery = false
		disc.Massless = true
		disc.CFrame = head.CFrame * CFrame.new(0, 0.75 + i * 0.4, 0) * CFrame.Angles(0, 0, math.rad(90))
		disc.Parent = cone

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = disc
		weld.Parent = disc
	end
end

function CharacterService.removeCone(character: Model)
	local cone = character:FindFirstChild("ConoDeLaVerguenza")
	if cone then
		cone:Destroy()
	end
end

-- ── el profesor ────────────────────────────────────────────────────

local function limb(model: Model, name: string, size: Vector3, color: Color3): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.Parent = model
	return part
end

local function motor(parent: BasePart, child: BasePart, name: string, c0: CFrame, c1: CFrame): Motor6D
	local joint = Instance.new("Motor6D")
	joint.Name = name
	joint.Part0 = parent
	joint.Part1 = child
	joint.C0 = c0
	joint.C1 = c1
	joint.Parent = parent
	return joint
end

--- Las seis uniones de un rig R6. Los C0/C1 no son decorativos: si
--- alguno esta mal, el Humanoid camina desarmado. Estan una sola vez
--- para que profesor y alumnos compartan exactamente el mismo
--- esqueleto.
local function wireJoints(root: BasePart, torso: BasePart, head: BasePart,
	leftArm: BasePart, rightArm: BasePart, leftLeg: BasePart, rightLeg: BasePart)
	wireJoints(root, torso, head, leftArm, rightArm, leftLeg, rightLeg)
end

--- Cara enojada dibujada con partes: cejas caidas, ojos y boca torcida.
local function angryFace(head: BasePart)
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.CanQuery = false
		part.Massless = true
		part.CFrame = head.CFrame * offset
		part.Parent = head.Parent
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = part
		weld.Parent = part
	end

	for _, side in { -1, 1 } do
		piece("Ojo", Vector3.new(0.24, 0.24, 0.1),
			CFrame.new(side * 0.32, 0.06, -0.52), Color3.fromRGB(22, 24, 30))
		piece("Ceja", Vector3.new(0.5, 0.11, 0.1),
			CFrame.new(side * 0.34, 0.3, -0.52) * CFrame.Angles(0, 0, math.rad(side * 18)),
			Color3.fromRGB(38, 32, 28))
	end
	piece("Boca", Vector3.new(0.62, 0.09, 0.1),
		CFrame.new(0, -0.3, -0.52), Color3.fromRGB(60, 34, 34))
	piece("Anteojos", Vector3.new(1.05, 0.3, 0.08),
		CFrame.new(0, 0.06, -0.56), Color3.fromRGB(30, 32, 38))
end

--- Arma el rig R6 completo del profesor, listo para Humanoid:MoveTo.
function CharacterService.buildTeacher(name: string, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Profesor"

	local root = limb(model, "HumanoidRootPart", Vector3.new(2, 2, 1), P.ColorTraje)
	root.Transparency = 1
	root.CanCollide = false

	local torso = limb(model, "Torso", Vector3.new(2, 2, 1), P.ColorTraje)
	torso.CanCollide = true

	local head = limb(model, "Head", Vector3.new(2, 1, 1), P.ColorPiel)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head

	local leftArm = limb(model, "Left Arm", Vector3.new(1, 2, 1), P.ColorTraje)
	local rightArm = limb(model, "Right Arm", Vector3.new(1, 2, 1), P.ColorTraje)
	local leftLeg = limb(model, "Left Leg", Vector3.new(1, 2, 1), Color3.fromRGB(30, 33, 42))
	local rightLeg = limb(model, "Right Leg", Vector3.new(1, 2, 1), Color3.fromRGB(30, 33, 42))

	-- Como cualquier R6: todo colisiona menos la raiz. Con las piernas
	-- atravesables el Humanoid se hunde en el piso al primer paso.
	for _, part in { torso, head, leftArm, rightArm, leftLeg, rightLeg } do
		part.CanCollide = true
	end

	root.CFrame = CFrame.new(position)
	torso.CFrame = root.CFrame
	head.CFrame = root.CFrame * CFrame.new(0, 1.5, 0)
	leftArm.CFrame = root.CFrame * CFrame.new(-1.5, 0, 0)
	rightArm.CFrame = root.CFrame * CFrame.new(1.5, 0, 0)
	leftLeg.CFrame = root.CFrame * CFrame.new(-0.5, -2, 0)
	rightLeg.CFrame = root.CFrame * CFrame.new(0.5, -2, 0)

	local flip = CFrame.Angles(-math.pi / 2, 0, math.pi)
	motor(root, torso, "RootJoint", flip, flip)
	motor(torso, head, "Neck", CFrame.new(0, 1, 0) * flip, CFrame.new(0, -0.5, 0) * flip)
	motor(torso, rightArm, "Right Shoulder",
		CFrame.new(1, 0.5, 0) * CFrame.Angles(0, math.pi / 2, 0),
		CFrame.new(-0.5, 0.5, 0) * CFrame.Angles(0, math.pi / 2, 0))
	motor(torso, leftArm, "Left Shoulder",
		CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -math.pi / 2, 0),
		CFrame.new(0.5, 0.5, 0) * CFrame.Angles(0, -math.pi / 2, 0))
	motor(torso, rightLeg, "Right Hip",
		CFrame.new(1, -1, 0) * CFrame.Angles(0, math.pi / 2, 0),
		CFrame.new(0.5, 1, 0) * CFrame.Angles(0, math.pi / 2, 0))
	motor(torso, leftLeg, "Left Hip",
		CFrame.new(-1, -1, 0) * CFrame.Angles(0, -math.pi / 2, 0),
		CFrame.new(-0.5, 1, 0) * CFrame.Angles(0, -math.pi / 2, 0))

	-- Camisa, corbata y saco: capas finas encima del torso.
	local function layer(part: BasePart, lname: string, size: Vector3, offset: CFrame, color: Color3)
		local piece = Instance.new("Part")
		piece.Name = lname
		piece.Size = size
		piece.Color = color
		piece.Material = Enum.Material.Fabric
		piece.CanCollide = false
		piece.CanQuery = false
		piece.Massless = true
		piece.CFrame = part.CFrame * offset
		piece.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = part
		weld.Part1 = piece
		weld.Parent = piece
	end

	layer(torso, "Camisa", Vector3.new(0.9, 1.9, 0.14), CFrame.new(0, 0, -0.5), P.ColorCamisa)
	layer(torso, "Corbata", Vector3.new(0.3, 1.4, 0.1), CFrame.new(0, 0.1, -0.6), P.ColorCorbata)
	layer(torso, "Solapa", Vector3.new(0.42, 1.1, 0.1),
		CFrame.new(-0.45, 0.4, -0.56) * CFrame.Angles(0, 0, math.rad(12)), P.ColorTraje)
	layer(torso, "Solapa", Vector3.new(0.42, 1.1, 0.1),
		CFrame.new(0.45, 0.4, -0.56) * CFrame.Angles(0, 0, math.rad(-12)), P.ColorTraje)
	layer(head, "Pelo", Vector3.new(2.05, 0.42, 1.05), CFrame.new(0, 0.45, 0.02),
		Color3.fromRGB(58, 48, 42))

	angryFace(head)

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.WalkSpeed = P.VelocidadPatrulla
	humanoid.JumpPower = 0
	humanoid.AutoRotate = true
	humanoid.MaxHealth = 1000
	humanoid.Health = 1000
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	model.PrimaryPart = root

	nameTag(model, name, Color3.fromRGB(244, 206, 122))

	return model
end

--- Cara neutra de alumno: ojos y una boca chiquita. Sin cejas
--- caidas, que esas son del profesor.
local function calmFace(head: BasePart)
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.CanQuery = false
		part.Massless = true
		part.CFrame = head.CFrame * offset
		part.Parent = head.Parent
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = part
		weld.Parent = part
	end

	for _, side in { -1, 1 } do
		piece("Ojo", Vector3.new(0.22, 0.26, 0.1),
			CFrame.new(side * 0.3, 0.08, -0.52), Color3.fromRGB(26, 28, 34))
	end
	piece("Boca", Vector3.new(0.3, 0.08, 0.1),
		CFrame.new(0, -0.26, -0.52), Color3.fromRGB(70, 44, 44))
end

--- Un alumno NPC: el mismo esqueleto que el profesor, con uniforme y
--- un libro bajo el brazo. Son los que estudiaron — a los que se les
--- pide (o se les quita) la respuesta.
function CharacterService.buildStudent(name: string, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Alumno"

	local skin = Color3.fromRGB(222, 184, 150)
	local sweater = Config.Empollones.ColorSueter

	local root = limb(model, "HumanoidRootPart", Vector3.new(2, 2, 1), sweater)
	root.Transparency = 1
	root.CanCollide = false

	local torso = limb(model, "Torso", Vector3.new(2, 2, 1), sweater)
	local head = limb(model, "Head", Vector3.new(2, 1, 1), skin)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head

	local leftArm = limb(model, "Left Arm", Vector3.new(1, 2, 1), skin)
	local rightArm = limb(model, "Right Arm", Vector3.new(1, 2, 1), skin)
	local leftLeg = limb(model, "Left Leg", Vector3.new(1, 2, 1), Color3.fromRGB(48, 52, 66))
	local rightLeg = limb(model, "Right Leg", Vector3.new(1, 2, 1), Color3.fromRGB(48, 52, 66))

	root.CFrame = CFrame.new(position)
	torso.CFrame = root.CFrame
	head.CFrame = root.CFrame * CFrame.new(0, 1.5, 0)
	leftArm.CFrame = root.CFrame * CFrame.new(-1.5, 0, 0)
	rightArm.CFrame = root.CFrame * CFrame.new(1.5, 0, 0)
	leftLeg.CFrame = root.CFrame * CFrame.new(-0.5, -2, 0)
	rightLeg.CFrame = root.CFrame * CFrame.new(0.5, -2, 0)

	for _, part in { torso, head, leftArm, rightArm, leftLeg, rightLeg } do
		part.CanCollide = true
	end

	wireJoints(root, torso, head, leftArm, rightArm, leftLeg, rightLeg)

	local function layer(anchor: BasePart, lname: string, size: Vector3, offset: CFrame,
		color: Color3, material: Enum.Material)
		local piece = Instance.new("Part")
		piece.Name = lname
		piece.Size = size
		piece.Color = color
		piece.Material = material
		piece.CanCollide = false
		piece.CanQuery = false
		piece.Massless = true
		piece.CFrame = anchor.CFrame * offset
		piece.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = anchor
		weld.Part1 = piece
		weld.Parent = piece
	end

	layer(torso, "Camisa", Vector3.new(0.85, 1.85, 0.14), CFrame.new(0, 0, -0.5),
		Color3.fromRGB(238, 240, 244), Enum.Material.Fabric)
	layer(torso, "Corbata", Vector3.new(0.28, 1.2, 0.1), CFrame.new(0, 0.1, -0.6),
		Color3.fromRGB(122, 32, 44), Enum.Material.Fabric)
	layer(head, "Pelo", Vector3.new(2.05, 0.5, 1.08), CFrame.new(0, 0.42, 0.04),
		Color3.fromRGB(46, 36, 30), Enum.Material.SmoothPlastic)
	layer(head, "Anteojos", Vector3.new(1.5, 0.34, 0.08), CFrame.new(0, 0.08, -0.56),
		Color3.fromRGB(38, 40, 48), Enum.Material.SmoothPlastic)
	-- El libro bajo el brazo: es la razon por la que sabe las respuestas.
	layer(leftArm, "Libro", Vector3.new(0.4, 1.3, 1), CFrame.new(-0.45, -0.2, 0),
		Color3.fromRGB(126, 44, 52), Enum.Material.Fabric)

	calmFace(head)

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.WalkSpeed = 8
	humanoid.JumpPower = 0
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	model.PrimaryPart = root
	nameTag(model, name, Color3.fromRGB(186, 224, 168))

	return model
end

--- Animacion procedural: sin esto el NPC se desliza rigido, porque el
--- script Animate solo viene en los avatares de jugador.
function CharacterService.animate(model: Model): RBXScriptConnection?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local torso = model:FindFirstChild("Torso")
	if not humanoid or not torso or not torso:IsA("BasePart") then
		return nil
	end

	local joints: { [string]: Motor6D } = {}
	for _, name in { "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip", "Neck" } do
		local joint = torso:FindFirstChild(name)
		if joint and joint:IsA("Motor6D") then
			joints[name] = joint
		end
	end

	local base: { [string]: CFrame } = {}
	for name, joint in joints do
		base[name] = joint.C0
	end

	local phase = 0
	return RunService.Heartbeat:Connect(function(dt)
		if not model.Parent then
			return
		end
		local speed = humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed
		phase += dt * math.max(1.2, speed * 0.7)
		local swing = math.sin(phase) * math.clamp(speed / 12, 0.08, 0.75)

		if joints["Right Shoulder"] then
			joints["Right Shoulder"].C0 = base["Right Shoulder"] * CFrame.Angles(swing, 0, 0)
		end
		if joints["Left Shoulder"] then
			joints["Left Shoulder"].C0 = base["Left Shoulder"] * CFrame.Angles(-swing, 0, 0)
		end
		if joints["Right Hip"] then
			joints["Right Hip"].C0 = base["Right Hip"] * CFrame.Angles(-swing * 0.9, 0, 0)
		end
		if joints["Left Hip"] then
			joints["Left Hip"].C0 = base["Left Hip"] * CFrame.Angles(swing * 0.9, 0, 0)
		end
		if joints["Neck"] then
			-- Mira despacio de un lado al otro cuando esta quieto: da
			-- la sensacion de que esta vigilando.
			local idle = speed < 1 and math.sin(phase * 0.35) * 0.35 or 0
			joints["Neck"].C0 = base["Neck"] * CFrame.Angles(0, 0, idle)
		end
	end)
end

--- Deja un profesor ya armado en ServerStorage/Respaldo.
--- Clonarlo es bastante mas barato que rehacer 30 partes y 6 Motor6D
--- cada vez que empieza un examen, y ademas cumple con tener los
--- modelos de respaldo fuera del alcance del cliente.
function CharacterService.installBackup()
	local previous = ServerStorage:FindFirstChild("Respaldo")
	if previous then
		previous:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "Respaldo"
	folder.Parent = ServerStorage

	local ok, model = pcall(function()
		return CharacterService.buildTeacher("...", Vector3.new(0, 500, 0))
	end)
	if ok and model then
		model.Name = "ProfesorBase"
		model.Parent = folder
	else
		warn("[Personajes] no se pudo guardar el profesor de respaldo: " .. tostring(model))
	end
end

--- Un profesor listo para usar: clona el respaldo si existe, y si no,
--- lo construye en el momento.
function CharacterService.teacher(name: string, position: Vector3): Model
	local backup = ServerStorage:FindFirstChild("Respaldo")
	local template = backup and backup:FindFirstChild("ProfesorBase")
	if template and template:IsA("Model") then
		local clone = template:Clone()
		clone:PivotTo(CFrame.new(position))
		nameTag(clone, name, Color3.fromRGB(244, 206, 122))
		return clone
	end
	return CharacterService.buildTeacher(name, position)
end

function CharacterService.randomTeacherName(): string
	return P.NombresPosibles[rng:NextInteger(1, #P.NombresPosibles)]
end

--- Carpeta donde viven los personajes que no son jugadores.
function CharacterService.folder(): Folder
	local existing = workspace:FindFirstChild("Personajes")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "Personajes"
	folder.Parent = workspace
	return folder
end

return CharacterService

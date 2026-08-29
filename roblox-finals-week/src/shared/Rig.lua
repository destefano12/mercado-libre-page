--!strict
--[[
	Rig
	------------------------------------------------------------------
	El cuerpo, en un solo lugar: proporciones, esqueleto y cara.

	Dos razones para que exista este archivo.

	La primera es de forma. Los personajes eran R6 estandar — un
	monigote de Roblox con la cabeza a escala 1.25. En la referencia del
	juego real los alumnos son caricaturas: cabeza enorme (cerca de un
	tercio de la altura), cuerpo chico, miembros cortos y gruesos, y la
	piel de colores que no existen en una persona — violeta, rosa, rojo,
	celeste. Eso ultimo es lo mas reconocible de todo el juego.

	La segunda es un bug. `CharacterService.wireJoints` se llamaba a si
	misma:

	    local function wireJoints(root, torso, head, ...)
	        wireJoints(root, torso, head, ...)   -- <-- desbordaba la pila
	    end

	Era la unica llamada de `buildStudent`, asi que **todos los NPC
	empollones reventaban al nacer**. `NerdNPCs.spawn` lo envolvia en
	`pcall` y solo hacia `warn`, de modo que el pasillo quedaba con cero
	empollones y en el Output no habia mas que una linea suelta. El
	compilador no lo ve porque una `local function` recursiva es Luau
	perfectamente valido.

	Al mover el esqueleto aca, el bug no se "arregla": deja de poder
	existir, porque hay un solo sitio donde se arman las uniones y lo
	usan el jugador, el profesor y los NPC.

	Sobre los offsets: los C0/C1 de un R6 no son magia, salen de las
	medidas de las piezas. Antes estaban escritos como numeros sueltos
	(1, 0.5, -1...) calibrados contra un torso de 2x2x1; aca se derivan
	de la tabla de proporciones, asi que cambiar el cuerpo no descoloca
	los brazos.
--]]

local Rig = {}

export type Proportions = {
	cabeza: Vector3,
	escalaCabeza: number,
	torso: Vector3,
	brazo: Vector3,
	pierna: Vector3,
}

--[[
	Alumno: cabezon. Con la cabeza a 1.7 de alto sobre un total de ~4.8
	studs, la cabeza es un tercio del personaje — que es la proporcion
	que se ve en la referencia.
--]]
Rig.Alumno = {
	cabeza = Vector3.new(2, 1.7, 1.6),
	escalaCabeza = 1.55,
	torso = Vector3.new(1.9, 1.7, 1),
	brazo = Vector3.new(0.8, 1.6, 0.8),
	pierna = Vector3.new(0.85, 1.5, 0.85),
} :: Proportions

--- El profesor es mas alto y menos cabezon: se lee como adulto sin
--- salirse del estilo.
Rig.Profesor = {
	cabeza = Vector3.new(1.9, 1.5, 1.5),
	escalaCabeza = 1.4,
	torso = Vector3.new(2, 2.1, 1.05),
	brazo = Vector3.new(0.85, 2, 0.85),
	pierna = Vector3.new(0.9, 2, 0.9),
} :: Proportions

-- ── piezas ─────────────────────────────────────────────────────────

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

local function motor(parent: BasePart, child: BasePart, name: string,
	c0: CFrame, c1: CFrame): Motor6D
	local joint = Instance.new("Motor6D")
	joint.Name = name
	joint.Part0 = parent
	joint.Part1 = child
	joint.C0 = c0
	joint.C1 = c1
	joint.Parent = parent
	return joint
end

--- Pega una pieza decorativa a otra con WeldConstraint.
function Rig.attach(anchor: BasePart, name: string, size: Vector3, offset: CFrame,
	color: Color3, material: Enum.Material?): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.Massless = true
	part.CFrame = anchor.CFrame * offset
	part.Parent = anchor.Parent

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
	return part
end

-- ── esqueleto ──────────────────────────────────────────────────────

--[[
	Las seis uniones de un R6, derivadas de las medidas. Esta es la
	funcion que antes se llamaba a si misma.
--]]
local function wireJoints(prop: Proportions, root: BasePart, torso: BasePart,
	head: BasePart, leftArm: BasePart, rightArm: BasePart,
	leftLeg: BasePart, rightLeg: BasePart)
	local flip = CFrame.Angles(-math.pi / 2, 0, math.pi)
	local halfTorsoX = prop.torso.X / 2
	local halfTorsoY = prop.torso.Y / 2

	motor(root, torso, "RootJoint", flip, flip)

	motor(torso, head, "Neck",
		CFrame.new(0, halfTorsoY, 0) * flip,
		CFrame.new(0, -prop.cabeza.Y / 2, 0) * flip)

	-- Los brazos cuelgan del cuarto superior del torso; los C1 los
	-- enganchan por su propio cuarto superior.
	for _, entry in {
		{ name = "Right Shoulder", part = rightArm, side = 1 },
		{ name = "Left Shoulder", part = leftArm, side = -1 },
	} do
		local turn = CFrame.Angles(0, entry.side * math.pi / 2, 0)
		motor(torso, entry.part, entry.name,
			CFrame.new(entry.side * halfTorsoX, prop.torso.Y / 4, 0) * turn,
			CFrame.new(-entry.side * prop.brazo.X / 2, prop.brazo.Y / 4, 0) * turn)
	end

	for _, entry in {
		{ name = "Right Hip", part = rightLeg, side = 1 },
		{ name = "Left Hip", part = leftLeg, side = -1 },
	} do
		local turn = CFrame.Angles(0, entry.side * math.pi / 2, 0)
		motor(torso, entry.part, entry.name,
			CFrame.new(entry.side * halfTorsoX, -halfTorsoY, 0) * turn,
			CFrame.new(entry.side * prop.pierna.X / 2, prop.pierna.Y / 2, 0) * turn)
	end
end

export type Skin = {
	piel: Color3,
	pelo: Color3,
	camisa: Color3,
	pantalon: Color3,
	zapato: Color3,
}

--[[
	Arma un cuerpo entero y devuelve el modelo. No lo parenta: quien
	llama decide donde va y cuando.
--]]
function Rig.build(name: string, prop: Proportions, skin: Skin): Model
	local model = Instance.new("Model")
	model.Name = name

	local root = limb(model, "HumanoidRootPart", prop.torso, skin.camisa)
	root.Transparency = 1
	root.CanCollide = false

	local torso = limb(model, "Torso", prop.torso, skin.camisa)
	local head = limb(model, "Head", prop.cabeza, skin.piel)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(prop.escalaCabeza, prop.escalaCabeza, prop.escalaCabeza)
	mesh.Parent = head

	-- Los brazos van del color de la piel: en la referencia las mangas
	-- son cortas y lo que se ve del brazo es piel de color.
	local leftArm = limb(model, "Left Arm", prop.brazo, skin.piel)
	local rightArm = limb(model, "Right Arm", prop.brazo, skin.piel)
	local leftLeg = limb(model, "Left Leg", prop.pierna, skin.pantalon)
	local rightLeg = limb(model, "Right Leg", prop.pierna, skin.pantalon)

	--[[
		Como cualquier R6: todo colisiona menos la raiz. Con las piernas
		atravesables el Humanoid se hunde en el piso al primer paso.
	--]]
	for _, part in { torso, head, leftArm, rightArm, leftLeg, rightLeg } do
		part.CanCollide = true
	end

	local hipY = prop.pierna.Y + prop.torso.Y / 2
	root.CFrame = CFrame.new(0, hipY, 0)
	torso.CFrame = root.CFrame
	head.CFrame = root.CFrame * CFrame.new(0, (prop.torso.Y + prop.cabeza.Y) / 2, 0)
	leftArm.CFrame = root.CFrame
		* CFrame.new(-(prop.torso.X + prop.brazo.X) / 2, 0, 0)
	rightArm.CFrame = root.CFrame
		* CFrame.new((prop.torso.X + prop.brazo.X) / 2, 0, 0)
	leftLeg.CFrame = root.CFrame
		* CFrame.new(-prop.pierna.X / 2, -(prop.torso.Y + prop.pierna.Y) / 2, 0)
	rightLeg.CFrame = root.CFrame
		* CFrame.new(prop.pierna.X / 2, -(prop.torso.Y + prop.pierna.Y) / 2, 0)

	wireJoints(prop, root, torso, head, leftArm, rightArm, leftLeg, rightLeg)

	-- Zapatos y pelo: dos piezas que cambian mucho la silueta por lo
	-- poco que cuestan.
	for _, leg in { leftLeg, rightLeg } do
		Rig.attach(leg, "Zapato",
			Vector3.new(prop.pierna.X + 0.12, 0.4, prop.pierna.Z + 0.3),
			CFrame.new(0, -prop.pierna.Y / 2 + 0.16, -0.1), skin.zapato)
	end

	Rig.attach(head, "Pelo",
		Vector3.new(prop.cabeza.X * 1.02, prop.cabeza.Y * 0.62, prop.cabeza.Z * 1.02),
		CFrame.new(0, prop.cabeza.Y * 0.42, 0), skin.pelo)
	Rig.attach(head, "Flequillo",
		Vector3.new(prop.cabeza.X * 1.02, prop.cabeza.Y * 0.34, 0.3),
		CFrame.new(0, prop.cabeza.Y * 0.2, -prop.cabeza.Z * 0.52), skin.pelo)

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.NameDisplayDistance = 0
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = model

	model.PrimaryPart = root
	return model
end

-- ── cara ───────────────────────────────────────────────────────────

--[[
	Ojos grandes y ovalados con esclerotica blanca y pupila oscura, mas
	cejas. La version anterior dibujaba solo un cuadradito oscuro por
	ojo: a esta escala de cabeza, el ojo es el rasgo que define al
	personaje y tiene que tener blanco.

	`angry` inclina las cejas: es la unica diferencia entre la cara del
	profesor y la de un alumno.
--]]
function Rig.face(head: BasePart, prop: Proportions, angry: boolean)
	local front = -prop.cabeza.Z * 0.5 - 0.02
	local eyeX = prop.cabeza.X * 0.19
	local eyeY = prop.cabeza.Y * 0.06

	for _, side in { -1, 1 } do
		Rig.attach(head, "Ojo",
			Vector3.new(prop.cabeza.X * 0.2, prop.cabeza.Y * 0.34, 0.08),
			CFrame.new(side * eyeX, eyeY, front),
			Color3.fromRGB(252, 252, 250))
		Rig.attach(head, "Pupila",
			Vector3.new(prop.cabeza.X * 0.1, prop.cabeza.Y * 0.16, 0.06),
			CFrame.new(side * eyeX, eyeY - prop.cabeza.Y * 0.03, front - 0.03),
			Color3.fromRGB(28, 26, 34))
		Rig.attach(head, "Ceja",
			Vector3.new(prop.cabeza.X * 0.24, prop.cabeza.Y * 0.06, 0.07),
			CFrame.new(side * eyeX, eyeY + prop.cabeza.Y * 0.26, front)
				* CFrame.Angles(0, 0, math.rad(side * (angry and 20 or 4))),
			Color3.fromRGB(48, 38, 44))
	end

	Rig.attach(head, "Boca",
		Vector3.new(prop.cabeza.X * 0.24, prop.cabeza.Y * 0.05, 0.07),
		CFrame.new(0, -prop.cabeza.Y * 0.24, front),
		Color3.fromRGB(126, 62, 68))
end

return Rig

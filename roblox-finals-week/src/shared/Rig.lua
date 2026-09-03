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
	-- La cabeza es UNA medida: lo que mide es lo que se ve. Ver abajo
	-- por que esto merece un comentario.
	cabeza: Vector3,
	torso: Vector3,
	brazo: Vector3,
	pierna: Vector3,
	-- Largo del cuello, en studs. Solo el profesor lo tiene: el alumno
	-- lleva la cabeza apoyada directamente sobre los hombros.
	cuello: number?,
}

--[[
	Alumno: cabezon, pero menos de lo que yo tenia.

	La primera version daba 1.7 de cabeza sobre 4.9 de alto — o sea unas
	2.9 cabezas, casi un bebe. Midiendo contra los fotogramas del trailer
	los personajes son mas esbeltos: rondan las 3.5 cabezas, con la
	cabeza grande pero el cuerpo mas largo y los miembros claramente mas
	finos.

	1.5 de cabeza sobre 5.3 de alto total da 3.5 cabezas justas.
--]]
Rig.Alumno = {
	cabeza = Vector3.new(1.9, 1.5, 1.5),
	torso = Vector3.new(1.8, 1.9, 0.95),
	brazo = Vector3.new(0.7, 1.8, 0.7),
	pierna = Vector3.new(0.8, 1.9, 0.8),
} :: Proportions

--[[
	El profesor no es "un alumno mas alto": es otra criatura.

	Yo lo tenia como un adulto proporcionado — 2.3 de torso, brazos y
	piernas apenas mas largos que los del alumno. En `f013` del trailer
	es una figura larguisima y flaquisima: cuello finisimo que le empuja
	la cabeza hacia adelante, hombros angostos, brazos que le llegan
	casi a las rodillas y piernas que son la mitad de su altura. Da
	miedo por la silueta, antes de hacer nada.

	Medido sobre ese fotograma, en fracciones de su altura total:
	cabeza 0.22, cuello 0.07, torso 0.22, piernas 0.45. Sobre 8.6 studs
	de alto, eso da los numeros de abajo — un tercio mas alto que el
	alumno y con los miembros a poco mas de la mitad de grosor.
--]]
Rig.Profesor = {
	cabeza = Vector3.new(2.1, 1.7, 1.7),
	torso = Vector3.new(1.5, 2.2, 0.8),
	brazo = Vector3.new(0.42, 3, 0.42),
	pierna = Vector3.new(0.5, 4, 0.5),
	cuello = 0.7,
} :: Proportions

--[[
	Una nota sobre la cabeza, porque aca vivio un bug caro.

	Habia DOS numeros para el tamano de la cabeza: `cabeza`, que era la
	caja, y `escalaCabeza`, que agrandaba la malla un 35% encima. Los
	ojos, las cejas, la boca, el pelo y las catorce cosmeticas de cabeza
	se colocaban todas contra la caja — o sea contra el numero chico —,
	asi que la cara entera quedaba metida DENTRO de la cabeza que se
	dibujaba. Y el numero que yo habia medido contra el trailer, "3.5
	cabezas de alto", tampoco era el que salia en pantalla: con la malla
	agrandada el personaje renderizaba a 2.75.

	Ninguna de las dos cuentas estaba mal por separado; lo que estaba mal
	era que hubiera dos. Asi que ahora hay una: `cabeza` es lo que mide
	la cabeza y es lo que se ve. Cualquier cosa que se apoye en ella se
	coloca contra ese numero y no hay un segundo numero con el que
	confundirlo.
--]]

-- ── piezas ─────────────────────────────────────────────────────────

--[[
	Redondear una pieza.

	Este es el cambio que mas acerca los personajes a la referencia, y
	es una sola linea por pieza. En el trailer **no hay una sola arista
	dura en ningun cuerpo**: el torso es un barril redondeado, los
	brazos y las piernas son tubos con las puntas romas, y las manos y
	los pies son bollos. Con partes cuadradas el parecido se cae por
	mas que las proporciones esten bien.

	Un `SpecialMesh` de tipo Sphere no agrega partes: deforma la que ya
	esta para llenar su caja como elipsoide. `Scale` multiplica sobre
	esa caja, asi que un 1.06 en X/Z engorda el torso lo justo para que
	llegue a los hombros — un elipsoide exacto se afina en los costados
	y dejaba un hueco donde nacen los brazos.

	La caja de colision NO cambia: sigue siendo el bloque. Para un
	personaje eso es lo que uno quiere, porque una capsula rodando por
	el piso camina peor que un bloque.
--]]
function Rig.round(part: BasePart, scale: Vector3?): SpecialMesh
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = scale or Vector3.new(1, 1, 1)
	mesh.Parent = part
	return mesh
end

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

	-- El cuello separa la cabeza de los hombros. La articulacion sigue
	-- llamandose `Neck` y sigue yendo de Torso a Head: la pieza visible
	-- del cuello se suelda aparte, para que `animate` y las cosmeticas
	-- de cabeza no tengan que saber nada de esto.
	motor(torso, head, "Neck",
		CFrame.new(0, halfTorsoY + (prop.cuello or 0), 0) * flip,
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
	Rig.round(head)

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
	head.CFrame = root.CFrame
		* CFrame.new(0, (prop.torso.Y + prop.cabeza.Y) / 2 + (prop.cuello or 0), 0)
	leftArm.CFrame = root.CFrame
		* CFrame.new(-(prop.torso.X + prop.brazo.X) / 2, 0, 0)
	rightArm.CFrame = root.CFrame
		* CFrame.new((prop.torso.X + prop.brazo.X) / 2, 0, 0)
	leftLeg.CFrame = root.CFrame
		* CFrame.new(-prop.pierna.X / 2, -(prop.torso.Y + prop.pierna.Y) / 2, 0)
	rightLeg.CFrame = root.CFrame
		* CFrame.new(prop.pierna.X / 2, -(prop.torso.Y + prop.pierna.Y) / 2, 0)

	wireJoints(prop, root, torso, head, leftArm, rightArm, leftLeg, rightLeg)

	--[[
		Y ahora se redondea todo. El torso va un pelin mas ancho para
		llegar a los hombros; los miembros van al ras de su caja, que
		con esta relacion de lados da una capsula.
	--]]
	Rig.round(torso, Vector3.new(1.06, 1, 1.12))
	for _, part in { leftArm, rightArm, leftLeg, rightLeg } do
		Rig.round(part)
	end

	--[[
		Manos y zapatos: bollos en la punta de cada miembro.

		Aparte de estar en la referencia — los guantes amarillos se ven
		en cada plano en primera persona —, tapan la unica debilidad del
		elipsoide, que es que termina en punta. Con un bollo en el
		extremo el brazo se lee como una capsula.
	--]]
	local GUANTE = Color3.fromRGB(240, 196, 78)
	for _, arm in { leftArm, rightArm } do
		local hand = Rig.attach(arm, "Mano",
			Vector3.new(prop.brazo.X * 1.15, prop.brazo.X * 1.15, prop.brazo.X * 1.15),
			CFrame.new(0, -prop.brazo.Y / 2 + prop.brazo.X * 0.4, 0), GUANTE)
		Rig.round(hand)
	end

	for _, leg in { leftLeg, rightLeg } do
		local shoe = Rig.attach(leg, "Zapato",
			Vector3.new(prop.pierna.X + 0.12, 0.46, prop.pierna.Z + 0.4),
			CFrame.new(0, -prop.pierna.Y / 2 + 0.18, -0.12), skin.zapato)
		Rig.round(shoe)
	end

	--[[
		El cuello, cuando lo hay.

		Va soldado a la CABEZA y no al torso, que es lo que hace que se
		incline con ella. Es todo el chiste del profesor: cuando camina,
		`CharacterService.animate` le rota el `Neck` hacia adelante y el
		cuello entero se estira en esa direccion, como en el trailer. Si
		lo soldaramos al torso quedaria un palo vertical con la cabeza
		flotando adelante.
	--]]
	if prop.cuello then
		local neck = Rig.attach(head, "Cuello",
			Vector3.new(prop.brazo.X * 1.1, prop.cuello + prop.cabeza.Y * 0.4,
				prop.brazo.X * 1.1),
			CFrame.new(0, -(prop.cabeza.Y + prop.cuello) / 2, 0), skin.piel)
		Rig.round(neck)
	end

	-- El pelo de fabrica: un casquete y un flequillo, los dos redondos.
	-- Tambien contra la cabeza visible, o quedaba de peluca interior.
	Rig.round(Rig.attach(head, "Pelo",
		Vector3.new(prop.cabeza.X * 1.04, prop.cabeza.Y * 0.7, prop.cabeza.Z * 1.04),
		CFrame.new(0, prop.cabeza.Y * 0.34, 0), skin.pelo))
	Rig.round(Rig.attach(head, "Flequillo",
		Vector3.new(prop.cabeza.X * 1.0, prop.cabeza.Y * 0.4, 0.4),
		CFrame.new(0, prop.cabeza.Y * 0.16, -prop.cabeza.Z * 0.48), skin.pelo))

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
	Donde termina la cara a la altura de un rasgo.

	Con la cabeza cuadrada esto era una constante: todo se apoyaba en la
	cara de adelante de la caja. Redondeada ya no sirve — la superficie
	se va hacia atras a medida que uno se aleja del centro, asi que una
	ceja colocada a la Z del centro le queda flotando dos decimas de
	stud por delante del rostro, y una boca abajo, otro tanto.

	Es la ecuacion del elipsoide despejada en Z. El `max` con 0.05 evita
	la raiz de un negativo si alguien pide un rasgo por fuera del borde:
	en vez de reventar, lo pega contra el costado.
--]]
function Rig.faceZ(prop: Proportions, x: number, y: number): number
	local ax, ay, az = prop.cabeza.X / 2, prop.cabeza.Y / 2, prop.cabeza.Z / 2
	local k = 1 - (x / ax) ^ 2 - (y / ay) ^ 2
	return -az * math.sqrt(math.max(k, 0.05))
end

--[[
	Ojos grandes y ovalados con esclerotica blanca y pupila oscura, mas
	cejas. La version anterior dibujaba solo un cuadradito oscuro por
	ojo: a esta escala de cabeza, el ojo es el rasgo que define al
	personaje y tiene que tener blanco.

	`angry` inclina las cejas: es la unica diferencia entre la cara del
	profesor y la de un alumno.
--]]
function Rig.face(head: BasePart, prop: Proportions, angry: boolean)
	local eyeX = prop.cabeza.X * 0.19
	local eyeY = prop.cabeza.Y * 0.06
	local browY = eyeY + prop.cabeza.Y * 0.26
	local mouthY = -prop.cabeza.Y * 0.24

	for _, side in { -1, 1 } do
		-- Ojo y pupila van redondos: en la referencia son ovalos, y un
		-- rectangulo blanco sobre una cabeza esferica se ve pegado.
		Rig.round(Rig.attach(head, "Ojo",
			Vector3.new(prop.cabeza.X * 0.2, prop.cabeza.Y * 0.34, 0.08),
			CFrame.new(side * eyeX, eyeY, Rig.faceZ(prop, eyeX, eyeY) - 0.02),
			Color3.fromRGB(252, 252, 250)))
		Rig.round(Rig.attach(head, "Pupila",
			Vector3.new(prop.cabeza.X * 0.1, prop.cabeza.Y * 0.16, 0.06),
			CFrame.new(side * eyeX, eyeY - prop.cabeza.Y * 0.03,
				Rig.faceZ(prop, eyeX, eyeY) - 0.05),
			Color3.fromRGB(28, 26, 34)))
		Rig.attach(head, "Ceja",
			Vector3.new(prop.cabeza.X * 0.24, prop.cabeza.Y * 0.06, 0.07),
			CFrame.new(side * eyeX, browY, Rig.faceZ(prop, eyeX, browY) - 0.02)
				* CFrame.Angles(0, 0, math.rad(side * (angry and 20 or 4))),
			Color3.fromRGB(48, 38, 44))
	end

	Rig.attach(head, "Boca",
		Vector3.new(prop.cabeza.X * 0.24, prop.cabeza.Y * 0.05, 0.07),
		CFrame.new(0, mouthY, Rig.faceZ(prop, 0, mouthY) - 0.02),
		Color3.fromRGB(126, 62, 68))
end

return Rig

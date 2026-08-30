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
local Rig = require(Shared:WaitForChild("Rig"))

local P = Config.Profesor

local CharacterService = {}

local rng = Random.new()

-- ── uniforme del alumno ────────────────────────────────────────────

local UNIFORME = {
	Camisa = Color3.fromRGB(246, 242, 228),
	Pantalon = Color3.fromRGB(92, 116, 186),
	Zapato = Color3.fromRGB(58, 58, 74),
	Corbata = Color3.fromRGB(228, 140, 96),
}

--[[
	La piel y el pelo salen del UserId, no de un valor guardado.

	Podria persistirse en DataService, pero derivarlo del id es mejor en
	todo sentido: es estable entre partidas sin ocupar almacenamiento,
	funciona en Studio sin acceso a la API de DataStore, y dos jugadores
	distintos casi nunca coinciden. El `% #tabla` con dos primos
	distintos evita que piel y pelo queden correlacionados.
--]]
function CharacterService.skinFor(userId: number): Rig.Skin
	local pieles = Config.Personaje.Pieles
	local pelos = Config.Personaje.Pelos
	local id = math.abs(userId)
	return {
		piel = pieles[(id * 7) % #pieles + 1],
		pelo = pelos[(id * 13) % #pelos + 1],
		camisa = UNIFORME.Camisa,
		pantalon = UNIFORME.Pantalon,
		zapato = UNIFORME.Zapato,
	}
end

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
	-- La marca que permite que `dressStudent` sea idempotente: sin ella
	-- cada compra en la tienda apilaba otra corbata.
	part:SetAttribute("Accesorio", true)
	part.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
	return part
end

--[[
	Las cosmeticas de la tienda. Todos estos offsets estaban calibrados
	contra una cabeza de 2x1x1 y un torso de 2x2x1 — el R6 estandar. Con
	el cuerpo caricaturesco la cabeza es mucho mas grande, asi que ahora
	se derivan de `Rig.Alumno` y siguen cualquier cambio de proporciones.
--]]
local A = Rig.Alumno

local ESTETICAS: { [string]: (Model) -> () } = {
	gorra = function(character)
		attach(character, "Head", "Gorra",
			Vector3.new(A.cabeza.X * 1.06, A.cabeza.Y * 0.34, A.cabeza.Z * 1.06),
			CFrame.new(0, A.cabeza.Y * 0.5, 0),
			Color3.fromRGB(226, 84, 72), Enum.Material.SmoothPlastic)
		attach(character, "Head", "Visera",
			Vector3.new(A.cabeza.X * 1.06, 0.16, A.cabeza.Z * 0.7),
			CFrame.new(0, A.cabeza.Y * 0.34, -A.cabeza.Z * 0.72),
			Color3.fromRGB(198, 66, 58), Enum.Material.SmoothPlastic)
	end,
	anteojos = function(character)
		attach(character, "Head", "Anteojos",
			Vector3.new(A.cabeza.X * 0.86, A.cabeza.Y * 0.22, 0.14),
			CFrame.new(0, A.cabeza.Y * 0.05, -A.cabeza.Z * 0.55),
			Color3.fromRGB(52, 50, 66), Enum.Material.SmoothPlastic)
	end,
	mochila = function(character)
		local anchor = character:FindFirstChild("UpperTorso") and "UpperTorso" or "Torso"
		attach(character, anchor, "Mochila",
			Vector3.new(A.torso.X * 0.8, A.torso.Y * 1, A.torso.Z * 0.8),
			CFrame.new(0, 0.1, A.torso.Z * 0.78),
			Color3.fromRGB(96, 176, 128), Enum.Material.SmoothPlastic)
		for _, side in { -1, 1 } do
			attach(character, anchor, "Correa",
				Vector3.new(0.26, A.torso.Y * 0.9, 0.18),
				CFrame.new(side * A.torso.X * 0.28, 0.1, A.torso.Z * 0.42),
				Color3.fromRGB(72, 148, 104), Enum.Material.SmoothPlastic)
		end
	end,
	campera = function(character)
		paint(character, TORSOS, Color3.fromRGB(214, 92, 76))
		-- Solo el torso: los brazos son piel de color y taparlos borra
		-- lo mas identificable del personaje.
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

--[[
	Viste al alumno y le pone lo que tenga equipado.

	Antes esto no era idempotente: `ShopService` la vuelve a llamar cada
	vez que comprás una cosmética, y `attach` no deduplicaba, así que se
	apilaban corbatas y gorras una encima de otra hasta que el personaje
	quedaba con seis. Ahora todo lo que cuelga sale marcado y se limpia
	al principio.
--]]
local function stripAccessories(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("Accesorio") then
			child:Destroy()
		end
	end
end

function CharacterService.dressStudent(player: Player, character: Model, estetica: { [string]: boolean }?)
	local ok, err = pcall(function()
		stripAccessories(character)

		-- La piel de color es lo mas identificable del juego, y sale del
		-- UserId: el mismo jugador se ve igual en todas las partidas.
		local skin = CharacterService.skinFor(player.UserId)
		paint(character, TORSOS, skin.camisa)
		paint(character, BRAZOS, skin.piel)
		paint(character, PIERNAS, skin.pantalon)
		paint(character, PIES, skin.zapato)

		local head = character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			head.Color = skin.piel
			--[[
				La cara es pintable. Es el mismo atributo que usan las
				paredes, asi que dibujarle a alguien encima sale del
				sistema de grafiti que ya existia — `GraffitiService`
				nunca filtro a los otros jugadores del raycast, solo les
				faltaba estar marcados.

				Se borra solo al reaparecer: la cabeza es nueva y el
				lienzo se fue con la vieja.
			--]]
			head:SetAttribute("Pintable", true)
			for _, child in character:GetChildren() do
				if child:IsA("BasePart")
					and (child.Name == "Pelo" or child.Name == "Flequillo") then
					child.Color = skin.pelo
				end
			end
		end

		local torso = character:FindFirstChild("UpperTorso") and "UpperTorso" or "Torso"
		attach(character, torso, "Corbata", Vector3.new(0.34, 1, 0.14),
			CFrame.new(0, 0.2, -0.55), UNIFORME.Corbata, Enum.Material.SmoothPlastic)

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

--[[
	Fuerza el cuerpo caricaturesco para todos los jugadores.

	Un modelo llamado `StarterCharacter` colgado de `StarterPlayer`
	reemplaza el avatar de Roblox de cada jugador por este rig. Es el
	unico metodo que sirve por las dos vias de instalacion: el tipo de
	avatar del lugar es una opcion de Game Settings que un script no
	puede tocar, asi que por el `.rbxmx` todo-en-uno no habria forma de
	imponerlo. Un modelo, en cambio, se crea en runtime.

	El color se lo pone `dressStudent` por jugador; de aca sale solo la
	forma.
--]]
function CharacterService.installStarterCharacter()
	local StarterPlayer = game:GetService("StarterPlayer")
	local previous = StarterPlayer:FindFirstChild("StarterCharacter")
	if previous then
		previous:Destroy()
	end

	local model = Rig.build("StarterCharacter", Rig.Alumno, {
		piel = Config.Personaje.Pieles[1],
		pelo = Config.Personaje.Pelos[1],
		camisa = UNIFORME.Camisa,
		pantalon = UNIFORME.Pantalon,
		zapato = UNIFORME.Zapato,
	})

	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		Rig.face(head, Rig.Alumno, false)
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	model.Parent = StarterPlayer
	print("[Personajes] cuerpo caricaturesco instalado (StarterCharacter).")
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

	-- El ancho y la altura salen de la cabeza: con el cuerpo
	-- caricaturesco un cono de 2.2 studs quedaba de sombrerito.
	local widest = Rig.Alumno.cabeza.X * 1.7
	local layers = 6
	local step = Rig.Alumno.cabeza.Y * 0.3
	for i = 0, layers - 1 do
		local alpha = i / layers
		local disc = Instance.new("Part")
		disc.Name = "Anillo" .. i
		disc.Shape = Enum.PartType.Cylinder
		disc.Size = Vector3.new(0.42, widest * (1 - alpha) + 0.3, widest * (1 - alpha) + 0.3)
		disc.Color = i % 2 == 0 and Color3.fromRGB(228, 74, 62) or Color3.fromRGB(246, 246, 240)
		disc.Material = Enum.Material.SmoothPlastic
		disc.CanCollide = false
		disc.CanQuery = false
		disc.Massless = true
		disc.CFrame = head.CFrame
			* CFrame.new(0, Rig.Alumno.cabeza.Y * 0.45 + i * step, 0)
			* CFrame.Angles(0, 0, math.rad(90))
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

--[[
	Aca vivian `limb`, `motor`, `wireJoints` y `angryFace`, mas una copia
	entera del esqueleto R6 dentro de `buildTeacher` y otra dentro de
	`buildStudent`. Todo eso se mudo a `shared/Rig.lua`.

	El motivo no es solo el orden: `wireJoints` se llamaba a si misma y
	desbordaba la pila, era la unica llamada de `buildStudent`, y por eso
	**ningun NPC empollon llegaba a existir**. Con un solo constructor
	compartido ese error deja de ser posible.
--]]

--- Arma el rig del profesor, listo para Humanoid:MoveTo.
function CharacterService.buildTeacher(name: string, position: Vector3): Model
	local prop = Rig.Profesor
	local model = Rig.build("Profesor", prop, {
		piel = P.ColorPiel,
		pelo = Color3.fromRGB(88, 62, 74),
		camisa = P.ColorTraje,
		pantalon = Color3.fromRGB(58, 62, 88),
		zapato = Color3.fromRGB(46, 44, 56),
	})
	model:PivotTo(CFrame.new(position))

	local torso = model:FindFirstChild("Torso") :: BasePart
	local head = model:FindFirstChild("Head") :: BasePart

	-- Camisa, corbata y solapas: capas finas encima del torso.
	Rig.attach(torso, "Camisa", Vector3.new(prop.torso.X * 0.46, prop.torso.Y * 0.9, 0.14),
		CFrame.new(0, 0, -prop.torso.Z / 2), P.ColorCamisa)
	Rig.attach(torso, "Corbata", Vector3.new(0.3, prop.torso.Y * 0.66, 0.1),
		CFrame.new(0, 0.1, -prop.torso.Z / 2 - 0.06), P.ColorCorbata)
	for _, side in { -1, 1 } do
		Rig.attach(torso, "Solapa", Vector3.new(0.42, prop.torso.Y * 0.52, 0.1),
			CFrame.new(side * 0.45, 0.4, -prop.torso.Z / 2 - 0.02)
				* CFrame.Angles(0, 0, math.rad(-side * 12)), P.ColorTraje)
	end
	Rig.attach(head, "Anteojos",
		Vector3.new(prop.cabeza.X * 0.62, prop.cabeza.Y * 0.18, 0.08),
		CFrame.new(0, prop.cabeza.Y * 0.06, -prop.cabeza.Z * 0.54),
		Color3.fromRGB(46, 44, 58))

	Rig.face(head, prop, true)

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.WalkSpeed = P.VelocidadPatrulla
	humanoid.JumpPower = 0
	humanoid.AutoRotate = true
	humanoid.MaxHealth = 1000
	humanoid.Health = 1000
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	nameTag(model, name, Color3.fromRGB(244, 206, 122))

	return model
end

--[[
	Un alumno NPC: el mismo esqueleto que el profesor, con uniforme y un
	libro bajo el brazo. Son los que estudiaron — a los que se les pide
	(o se les quita) la respuesta.

	Esta es la funcion que no llegaba a terminar: su unica llamada al
	viejo `wireJoints` desbordaba la pila y el `pcall` de NerdNPCs se
	comia el error, asi que el pasillo quedaba sin un solo empollon.

	Cada uno sale con una combinacion distinta de piel y pelo — el
	indice del nombre alcanza como semilla y ademas los hace
	distinguibles entre si de un vistazo.
--]]
function CharacterService.buildStudent(name: string, position: Vector3): Model
	local prop = Rig.Alumno
	local pieles = Config.Personaje.Pieles
	local pelos = Config.Personaje.Pelos
	local seed = #name + string.byte(name, 1)

	local model = Rig.build("Alumno", prop, {
		piel = pieles[seed % #pieles + 1],
		pelo = pelos[(seed * 5) % #pelos + 1],
		camisa = UNIFORME.Camisa,
		pantalon = Config.Empollones.ColorSueter,
		zapato = UNIFORME.Zapato,
	})
	model:PivotTo(CFrame.new(position))

	local torso = model:FindFirstChild("Torso") :: BasePart
	local head = model:FindFirstChild("Head") :: BasePart
	local leftArm = model:FindFirstChild("Left Arm") :: BasePart

	Rig.attach(torso, "Corbata", Vector3.new(0.28, prop.torso.Y * 0.62, 0.1),
		CFrame.new(0, 0.1, -prop.torso.Z / 2 - 0.06), UNIFORME.Corbata)
	Rig.attach(head, "Anteojos",
		Vector3.new(prop.cabeza.X * 0.66, prop.cabeza.Y * 0.16, 0.08),
		CFrame.new(0, prop.cabeza.Y * 0.06, -prop.cabeza.Z * 0.54),
		Color3.fromRGB(52, 50, 66))
	-- El libro bajo el brazo: es la razon por la que sabe las respuestas.
	Rig.attach(leftArm, "Libro", Vector3.new(0.4, 1.1, 0.9),
		CFrame.new(-0.4, -0.2, 0), Color3.fromRGB(126, 44, 52))

	Rig.face(head, prop, false)

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.WalkSpeed = 8
	humanoid.JumpPower = 0
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

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

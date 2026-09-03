--!strict
--[[
	Viewmodel
	------------------------------------------------------------------
	Primera persona: la camara trabada y un par de brazos propios que
	sostienen lo que llevas.

	El juego real es en primera persona — en el trailer se ve una mano
	sosteniendo un libro abierto y otra un lapiz gigante. Esta version
	estaba en tercera, que era probablemente la diferencia mas grande
	entre lo que teniamos y lo que se ve en la referencia.

	Como funciona
	-------------
	`CameraMode = LockFirstPerson` traba la camara, pero en primera
	persona Roblox no te muestra nada de tu propio cuerpo: la pantalla
	queda vacia y las herramientas se ven flotando de costado. La
	solucion estandar es un *viewmodel*: un par de brazos que no son el
	personaje, viven en el espacio de la camara y se dibujan encima de
	todo.

	Van parentados a `workspace.CurrentCamera`. Eso es a proposito: lo
	que cuelga de la camara se renderiza pero no se replica, no colisiona
	y no le aparece a nadie mas. Son tuyos y de nadie mas.

	Dos detalles que hacen la diferencia entre "brazos pegados a la
	pantalla" y algo que se siente:

	  bob   al caminar, los brazos suben y bajan en ocho, no en linea
	        recta. Un bob vertical puro se lee como un ascensor.
	  sway  al girar la camara, los brazos se quedan atras un instante y
	        despues alcanzan. Es lo que da peso.

	Lo que Roblox no deja hacer: no hay un paso de render aparte para el
	viewmodel, asi que si te pegas a una pared los brazos la atraviesan.
	Se compensa manteniendolos cerca del cuerpo y retrayendolos cuando
	hay algo enfrente.
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rig = require(Shared:WaitForChild("Rig"))

local player = Players.LocalPlayer

local Viewmodel = {}

local model: Model? = nil
local leftArm: BasePart? = nil
local rightArm: BasePart? = nil
local held: BasePart? = nil
local pencil: BasePart? = nil

local bobPhase = 0
local swayX, swayY = 0, 0
local lastLook: Vector3? = nil

-- Donde se plantan los brazos respecto de la camara.
local BASE = CFrame.new(0, -1.5, -0.9)
local ARM_SPREAD = 0.85
local ARM_FORWARD = -0.7

local function newArm(name: string, side: number, color: Color3): BasePart
	local prop = Rig.Alumno
	local arm = Instance.new("Part")
	arm.Name = name
	arm.Size = Vector3.new(prop.brazo.X, prop.brazo.Y * 1.15, prop.brazo.Z)
	arm.Color = color
	arm.Material = Enum.Material.SmoothPlastic
	arm.Anchored = true
	arm.CanCollide = false
	arm.CanQuery = false
	arm.CastShadow = false
	arm.TopSurface = Enum.SurfaceType.Smooth
	arm.BottomSurface = Enum.SurfaceType.Smooth
	-- Sin esto Roblox lo oculta como oculta tu propio cuerpo en primera
	-- persona, y todo el modulo no serviria de nada.
	arm.LocalTransparencyModifier = 0
	--[[
		Redondo, como el resto del cuerpo. Y aca importa mas que en
		ningun otro lado: es la unica parte del personaje que el jugador
		mira todo el rato, y era la ultima que quedaba cuadrada.
	--]]
	Rig.round(arm)
	return arm
end

--[[
	Las manos son guantes amarillos, no piel.

	En el trailer, todo lo que se sostiene en primera persona — el libro,
	el lapiz, la hoja — se sostiene con un guante amarillo. Es lo primero
	que ve el jugador y estaba mostrando el color de piel de cada uno.
--]]
local GLOVE = Color3.fromRGB(240, 196, 78)

local function skinColor(): Color3
	return GLOVE
end

function Viewmodel.build()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if model then
		model:Destroy()
	end

	local holder = Instance.new("Model")
	holder.Name = "Viewmodel"

	local color = skinColor()
	local left = newArm("BrazoIzquierdo", -1, color)
	local right = newArm("BrazoDerecho", 1, color)
	left.Parent = holder
	right.Parent = holder

	holder.Parent = camera
	model = holder
	leftArm = left
	rightArm = right
end

--[[
	Muestra en la mano una copia de lo que tengas equipado. Es una copia
	visual y nada mas: la herramienta de verdad sigue en el personaje y
	es la que el servidor mira. Si esta copia se pierde no se rompe
	ninguna mecanica.
--]]
local function refreshHeld()
	if held then
		held:Destroy()
		held = nil
	end
	local character = player.Character
	if not character then
		return
	end
	local tool = character:FindFirstChildOfClass("Tool")
	local handle = tool and tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return
	end

	local copy = handle:Clone()
	-- Un Handle clonado se trae las soldaduras al personaje viejo y los
	-- prompts; sin limpiarlos, el clon arrastra cosas al espacio de la
	-- camara.
	for _, child in copy:GetDescendants() do
		if child:IsA("WeldConstraint") or child:IsA("Weld") or child:IsA("Motor6D")
			or child:IsA("ProximityPrompt") or child:IsA("Attachment") then
			child:Destroy()
		end
	end
	copy.Anchored = true
	copy.CanCollide = false
	copy.CanQuery = false
	copy.CastShadow = false
	copy.LocalTransparencyModifier = 0
	copy.Parent = model
	held = copy
end

--[[
	El lapiz del examen.

	Mientras estas sentado rindiendo, la mano derecha sostiene un lapiz
	desproporcionadamente grande. Es de las cosas que mas identifican al
	juego: no es un cursor, es un objeto que se ve moverse.
--]]
function Viewmodel.setPencil(on: boolean)
	if pencil then
		pencil:Destroy()
		pencil = nil
	end
	if not on or not model then
		return
	end

	local shaft = Instance.new("Part")
	shaft.Name = "Lapiz"
	shaft.Size = Vector3.new(0.28, 0.28, 3.4)
	shaft.Color = Color3.fromRGB(240, 186, 62)
	shaft.Material = Enum.Material.SmoothPlastic
	shaft.Anchored = true
	shaft.CanCollide = false
	shaft.CanQuery = false
	shaft.CastShadow = false
	shaft.LocalTransparencyModifier = 0
	shaft.Parent = model

	-- La punta y la goma, para que se lea como lapiz y no como un palo.
	local tip = Instance.new("Part")
	tip.Name = "Punta"
	tip.Size = Vector3.new(0.26, 0.26, 0.5)
	tip.Color = Color3.fromRGB(226, 196, 158)
	tip.Material = Enum.Material.SmoothPlastic
	tip.Anchored = true
	tip.CanCollide = false
	tip.CanQuery = false
	tip.CastShadow = false
	tip.LocalTransparencyModifier = 0
	tip.Parent = shaft

	local rubber = Instance.new("Part")
	rubber.Name = "Goma"
	rubber.Size = Vector3.new(0.3, 0.3, 0.34)
	rubber.Color = Color3.fromRGB(228, 132, 148)
	rubber.Material = Enum.Material.SmoothPlastic
	rubber.Anchored = true
	rubber.CanCollide = false
	rubber.CanQuery = false
	rubber.CastShadow = false
	rubber.LocalTransparencyModifier = 0
	rubber.Parent = shaft

	pencil = shaft
end

local function update(dt: number)
	local camera = workspace.CurrentCamera
	local character = player.Character
	if not camera or not model or not leftArm or not rightArm then
		return
	end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	-- ── sway: los brazos alcanzan a la camara con retraso ──
	local look = camera.CFrame.LookVector
	if lastLook then
		local delta = look - lastLook
		swayX += (-delta.X * 6 - swayX) * math.min(1, dt * 9)
		swayY += (-delta.Y * 6 - swayY) * math.min(1, dt * 9)
	end
	lastLook = look
	swayX = math.clamp(swayX, -0.25, 0.25)
	swayY = math.clamp(swayY, -0.25, 0.25)

	-- ── bob: figura de ocho al caminar ──
	local speed = 0
	if humanoid then
		speed = humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed
	end
	bobPhase += dt * (4 + speed * 0.55)
	local amount = math.clamp(speed / 16, 0, 1) * 0.09
	local bobX = math.sin(bobPhase) * amount
	local bobY = math.abs(math.cos(bobPhase)) * amount * 0.8

	--[[
		Retraccion: si hay algo justo delante de la camara, los brazos se
		acercan al cuerpo. No arregla el atravesado — Roblox no tiene un
		paso de render aparte para esto — pero evita el caso feo, que es
		quedar mirando el interior de una pared.
	--]]
	local retreat = 0
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character :: any, model :: any }
	local hit = workspace:Raycast(camera.CFrame.Position, look * 3, params)
	if hit then
		retreat = (1 - hit.Distance / 3) * 0.8
	end

	local base = camera.CFrame
		* BASE
		* CFrame.new(bobX + swayX, bobY + swayY, retreat)
		* CFrame.Angles(swayY * 1.2, swayX * 1.2, 0)

	leftArm.CFrame = base
		* CFrame.new(-ARM_SPREAD, 0, ARM_FORWARD)
		* CFrame.Angles(math.rad(-72), 0, math.rad(9))
	rightArm.CFrame = base
		* CFrame.new(ARM_SPREAD, 0, ARM_FORWARD)
		* CFrame.Angles(math.rad(-72), 0, math.rad(-9))

	if held then
		held.CFrame = rightArm.CFrame * CFrame.new(0, -0.9, -0.2)
	end

	if pencil then
		-- Inclinado y adelantado, como quien esta por apoyarlo en la
		-- hoja. La punta y la goma cuelgan de el.
		pencil.CFrame = rightArm.CFrame
			* CFrame.new(0, -1.1, -0.5)
			* CFrame.Angles(math.rad(-58), 0, math.rad(12))
		local tip = pencil:FindFirstChild("Punta")
		if tip and tip:IsA("BasePart") then
			tip.CFrame = pencil.CFrame * CFrame.new(0, 0, -1.9)
		end
		local rubber = pencil:FindFirstChild("Goma")
		if rubber and rubber:IsA("BasePart") then
			rubber.CFrame = pencil.CFrame * CFrame.new(0, 0, 1.85)
		end
	end
end

function Viewmodel.mount()
	-- Primera persona, trabada: es como se juega el original.
	player.CameraMode = Enum.CameraMode.LockFirstPerson

	Viewmodel.build()

	player.CharacterAdded:Connect(function(character)
		task.wait(0.4)
		Viewmodel.build()
		refreshHeld()
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				task.wait(0.1)
				refreshHeld()
			end
		end)
		character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				refreshHeld()
			end
		end)
	end)

	local character = player.Character
	if character then
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				task.wait(0.1)
				refreshHeld()
			end
		end)
		character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				refreshHeld()
			end
		end)
	end

	-- Despues del paso de camara del motor: si corriera antes, la camara
	-- se moveria despues de que colocamos los brazos y quedarian un
	-- fotograma atrasados.
	RunService:BindToRenderStep("FinalsWeekViewmodel",
		Enum.RenderPriority.Camera.Value + 2, update)
end

--- El menu de inicio toma la camara: mientras tanto los brazos estorban.
function Viewmodel.setVisible(visible: boolean)
	if not model then
		return
	end
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = visible and 0 or 1
			part.Transparency = visible and 0 or 1
		end
	end
end

return Viewmodel

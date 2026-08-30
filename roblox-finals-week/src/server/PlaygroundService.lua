--!strict
--[[
	PlaygroundService
	------------------------------------------------------------------
	El pasillo antes del examen: la pelota de basquet, el aro y el
	marcador. Es la valvula de escape del juego — los tres minutos de
	recreo son para hacer el tonto, y sin algo con lo que jugar el
	pasillo es solo una sala de espera.

	La pelota es una parte fisica de verdad (densidad, friccion y
	rebote reales), no un efecto. Se agarra con E, se suelta con clic:
	al agarrarla se suelda a la mano y deja de colisionar; al tirarla
	se despega y se le da velocidad con un poco de elevacion, que es lo
	que hace que un tiro se sienta un tiro y no un disparo.

	La canasta se detecta por direccion, no por contacto: el sensor
	debajo del aro solo cuenta si la pelota lo cruza BAJANDO. Si no,
	pegarle al aro desde abajo valdria tres puntos.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local P = Config.Pasillo

local PlaygroundService = {}

local ball: BasePart? = nil
local home = Vector3.new(0, 6, 0)
--[[
	Antes habia un unico `holder: Player?`, porque habia una unica pelota
	en todo el colegio. Con las de beisbol hay varias cosas agarrables a
	la vez, asi que el estado pasa a ser "quien lleva que":

	  carrying   jugador -> pieza que tiene en la mano
	  grabbable  todas las piezas que se pueden levantar

	Cada pieza lleva un atributo `Tipo` ("basquet" o "beisbol") y de ahi
	salen su fuerza, su elevacion y si aturde al impactar.
--]]
local carrying: { [Player]: BasePart } = {}
local grabbable: { BasePart } = {}
local origins: { [BasePart]: Vector3 } = {}
local lastThrower: Player? = nil
local lastThrow: { [Player]: number } = {}
local scores: { [Player]: number } = {}
local onScore: ((Player, number) -> ())? = nil

local function folder(): Folder
	local existing = workspace:FindFirstChild("Objetos")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "Objetos"
	created.Parent = workspace
	return created
end

-- ── construccion ───────────────────────────────────────────────────

local function buildHoop(parent: Instance, position: Vector3, facing: Vector3): BasePart
	local look = CFrame.lookAt(position, position + facing)

	--[[
		El aro va montado en la pared, no sobre un poste.

		En la referencia la cancha es un hall con el tablero atornillado
		al muro del fondo; un poste exento en el medio del atrio se lee
		como una plaza, no como un colegio. En vez del poste van dos
		brazos de soporte que salen de la pared.
	--]]
	for _, dx in { -2.6, 2.6 } do
		local arm = Instance.new("Part")
		arm.Name = "Soporte"
		arm.Anchored = true
		arm.Size = Vector3.new(0.4, 0.4, 3.4)
		arm.CFrame = look * CFrame.new(dx, P.CanastaAltura + 1.4, 2.6)
		arm.Color = Color3.fromRGB(78, 82, 92)
		arm.Material = Enum.Material.Metal
		arm.CanCollide = false
		arm.Parent = parent
	end

	local board = Instance.new("Part")
	board.Name = "Tablero"
	board.Anchored = true
	board.Size = Vector3.new(11, 6.5, 0.4)
	board.CFrame = look * CFrame.new(0, P.CanastaAltura + 2, 1.2)
	board.Color = Color3.fromRGB(236, 236, 230)
	board.Material = Enum.Material.SmoothPlastic
	board.Parent = parent

	local square = Instance.new("Part")
	square.Name = "Recuadro"
	square.Anchored = true
	square.Size = Vector3.new(4.2, 3.2, 0.1)
	square.CFrame = board.CFrame * CFrame.new(0, -0.8, -0.26)
	square.Color = Color3.fromRGB(200, 62, 52)
	square.Material = Enum.Material.SmoothPlastic
	square.CanCollide = false
	square.Parent = parent

	-- El aro: catorce cilindros en circulo. Un Torus no existe en
	-- Roblox sin mesh, y esto rebota igual de bien.
	local center = look * CFrame.new(0, P.CanastaAltura, -P.CanastaRadio + 0.6)
	local segments = 14
	for i = 0, segments - 1 do
		local angle = (i / segments) * math.pi * 2
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * P.CanastaRadio
		local segment = Instance.new("Part")
		segment.Name = "Aro"
		segment.Anchored = true
		segment.Shape = Enum.PartType.Cylinder
		segment.Size = Vector3.new(P.CanastaRadio * 0.5, 0.32, 0.32)
		segment.CFrame = CFrame.new(center.Position + offset)
			* CFrame.Angles(0, -angle, 0)
		segment.Color = Color3.fromRGB(226, 108, 44)
		segment.Material = Enum.Material.Metal
		segment.Parent = parent
	end

	-- La red: cortinas finas colgando, sin colision.
	for i = 0, 9 do
		local angle = (i / 10) * math.pi * 2
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (P.CanastaRadio - 0.2)
		local strand = Instance.new("Part")
		strand.Name = "Red"
		strand.Anchored = true
		strand.CanCollide = false
		strand.Size = Vector3.new(0.12, 2.4, 0.12)
		strand.CFrame = CFrame.new(center.Position + offset - Vector3.new(0, 1.2, 0))
		strand.Color = Color3.fromRGB(238, 238, 234)
		strand.Material = Enum.Material.Fabric
		strand.Transparency = 0.15
		strand.Parent = parent
	end

	-- El sensor de canasta, justo debajo del aro.
	local sensor = Instance.new("Part")
	sensor.Name = "Canasta"
	sensor.Anchored = true
	sensor.CanCollide = false
	sensor.CanTouch = true
	sensor.Transparency = 1
	sensor.Size = Vector3.new(P.CanastaRadio * 1.6, 0.4, P.CanastaRadio * 1.6)
	sensor.CFrame = CFrame.new(center.Position - Vector3.new(0, 1.1, 0))
	sensor.Parent = parent

	return sensor
end

local function buildBall(parent: Instance, position: Vector3): BasePart
	local part = Instance.new("Part")
	part.Name = "Pelota"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(P.PelotaRadio * 2, P.PelotaRadio * 2, P.PelotaRadio * 2)
	part.Position = position
	part.Color = Color3.fromRGB(206, 104, 42)
	part.Material = Enum.Material.Pebble
	part.Anchored = false
	part.CanCollide = true
	-- densidad, friccion, rebote, y cuanto pesan esos dos ultimos
	-- frente al material del suelo.
	part.CustomPhysicalProperties = PhysicalProperties.new(
		0.6, P.PelotaFriccion, P.PelotaRebote, 1, 1)
	part.Parent = parent

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Agarrar"
	prompt.ActionText = "Agarrar"
	prompt.ObjectText = "Pelota"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = P.AlcanceAgarre
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	return part
end

--[[
	Una pelota de beisbol: chica, rapida y casi sin rebote. No tiene aro
	ni marcador — tirarla es el fin en si mismo, y si le pega a alguien
	lo aturde un momento. El atributo `Tipo` es lo que despues consulta
	`shoot` para saber con cuanta fuerza sale.
--]]
local function buildBaseball(parent: Instance, position: Vector3): BasePart
	local part = Instance.new("Part")
	part.Name = "Beisbol"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(P.BeisbolRadio * 2, P.BeisbolRadio * 2, P.BeisbolRadio * 2)
	part.Position = position
	part.Color = Color3.fromRGB(248, 246, 238)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = false
	part.CanCollide = true
	part.CustomPhysicalProperties = PhysicalProperties.new(
		0.9, P.BeisbolFriccion, P.BeisbolRebote, 1, 1)
	part:SetAttribute("Tipo", "beisbol")
	part.Parent = parent

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Agarrar"
	prompt.ActionText = "Agarrar"
	prompt.ObjectText = "Pelota de beisbol"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = P.AlcanceAgarre
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	return part
end

--- El cesto donde viven las pelotas de beisbol.
local function buildCrate(parent: Instance, position: Vector3): BasePart
	local crate = Instance.new("Part")
	crate.Name = "Cesto"
	crate.Size = Vector3.new(4.4, 2.2, 4.4)
	crate.Position = position + Vector3.new(0, 1.1, 0)
	crate.Color = Color3.fromRGB(196, 148, 96)
	crate.Material = Enum.Material.SmoothPlastic
	crate.Anchored = true
	crate.TopSurface = Enum.SurfaceType.Smooth
	crate.BottomSurface = Enum.SurfaceType.Smooth
	crate.Parent = parent
	return crate
end

-- ── llevarla y tirarla ─────────────────────────────────────────────

--[[
	Registra una pieza como agarrable y recuerda de donde salio, para
	poder devolverla si se pierde. El prompt se engancha aca mismo, asi
	que agregar una pelota nueva es una sola llamada.
--]]
local function registerGrabbable(part: BasePart, origin: Vector3)
	table.insert(grabbable, part)
	origins[part] = origin

	local prompt = part:FindFirstChild("Agarrar")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function(player)
			PlaygroundService.grab(player)
		end)
	end
end

local function handOf(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	for _, name in { "RightHand", "Right Arm" } do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

local function release(player: Player)
	local part = carrying[player]
	if not part then
		return
	end
	local weld = part:FindFirstChild("Agarre")
	if weld then
		weld:Destroy()
	end
	part.CanCollide = true
	part.Massless = false
	carrying[player] = nil
end

--- Quien lleva esta pieza, si es que alguien la lleva.
local function bearerOf(part: BasePart): Player?
	for player, carried in carrying do
		if carried == part and player.Parent then
			return player
		end
	end
	return nil
end

--- La pieza agarrable mas cercana a la mano que no tenga dueno.
local function nearestGrabbable(hand: BasePart): BasePart?
	local best: BasePart? = nil
	local bestDistance = P.AlcanceAgarre
	for _, part in grabbable do
		if part.Parent and not bearerOf(part) then
			local distance = (part.Position - hand.Position).Magnitude
			if distance <= bestDistance then
				best = part
				bestDistance = distance
			end
		end
	end
	return best
end

--[[
	Una pelota de beisbol en el aire aturde a quien le pegue. Tres
	cuidados, todos aprendidos de la goma del profesor:

	  * se cobra una sola vez por tiro, si no un rebote pega dos veces;
	  * solo por encima de una velocidad, si no aturde rodando por el
	    piso al primero que la pise;
	  * nunca al que la tiro, que si no es imposible tirar de cerca.

	La conexion se corta sola a los cinco segundos: pasado ese rato la
	pelota ya es un objeto quieto, no un proyectil.
--]]
local function stunOnImpact(part: BasePart, thrower: Player)
	local spent = false
	local connection: RBXScriptConnection? = nil

	connection = part.Touched:Connect(function(hit)
		if spent then
			return
		end
		if part.AssemblyLinearVelocity.Magnitude < P.BeisbolVelocidadMinima then
			return
		end
		local model = hit:FindFirstAncestorOfClass("Model")
		local victim = model and Players:GetPlayerFromCharacter(model) or nil
		if not victim or victim == thrower then
			return
		end
		spent = true

		Net.event(Net.Events.Stunned):FireClient(victim, {
			motivo = "pelotazo",
			segundos = P.BeisbolAturde,
		})
		Net.event(Net.Events.Notify):FireClient(victim, {
			key = "ball.hit",
			args = { name = thrower.DisplayName },
		})

		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.PlatformStand = true
			task.delay(P.BeisbolAturde, function()
				if humanoid.Parent then
					humanoid.PlatformStand = false
				end
			end)
		end
	end)

	task.delay(5, function()
		if connection then
			connection:Disconnect()
		end
	end)
end

function PlaygroundService.grab(player: Player): any
	local hand = handOf(player)
	if not hand then
		return { ok = false }
	end
	if carrying[player] then
		-- Ya lleva algo: no se acumulan pelotas en la mano.
		return { ok = false }
	end

	local part = nearestGrabbable(hand)
	if not part then
		return { ok = false, reason = { key = "ball.taken" } }
	end

	carrying[player] = part
	part.CanCollide = false
	part.Massless = true
	part.CFrame = hand.CFrame * CFrame.new(0, -1.6, -0.6)

	local weld = Instance.new("Weld")
	weld.Name = "Agarre"
	weld.Part0 = hand
	weld.Part1 = part
	weld.C0 = CFrame.new(0, -1.6, -0.6)
	weld.Parent = part

	Net.event(Net.Events.Notify):FireClient(player, { key = "ball.throw" })
	return { ok = true }
end

function PlaygroundService.shoot(player: Player, direction: any): any
	local part = carrying[player]
	if not part then
		return { ok = false }
	end
	if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.05 then
		return { ok = false }
	end
	local now = os.clock()
	if now - (lastThrow[player] or -math.huge) < P.EnfriamientoTiro then
		return { ok = false }
	end
	lastThrow[player] = now

	local baseball = part:GetAttribute("Tipo") == "beisbol"
	release(player)
	if not baseball then
		lastThrower = player
	end

	--[[
		Un poco hacia arriba: sin elevacion, un tiro de basquet es un
		pase raso y nunca entra. La de beisbol se eleva mucho menos y
		sale mucho mas rapido — es un tiro tenso, no un lanzamiento.
	--]]
	local lift = baseball and P.BeisbolAlturaTiro or P.PelotaAlturaTiro
	local force = baseball and P.BeisbolFuerza or P.PelotaFuerza
	local aim = (direction.Unit + Vector3.new(0, lift, 0)).Unit
	part.AssemblyLinearVelocity = aim * force
	part.AssemblyAngularVelocity = Vector3.new(0, 0, baseball and -26 or -12)

	Util.playSound(Config.Sonidos.Impacto, part, 0.3, baseball and 1.9 or 1.5)

	if baseball then
		stunOnImpact(part, player)
	end
	return { ok = true }
end

-- ── canasta ────────────────────────────────────────────────────────

local function bindBasket(sensor: BasePart)
	local cooling = false
	sensor.Touched:Connect(function(hit)
		if cooling or hit ~= ball then
			return
		end
		-- Solo cuenta si viene BAJANDO: pegarle al aro desde abajo no
		-- es una canasta.
		if hit.AssemblyLinearVelocity.Y > -4 then
			return
		end
		local scorer = lastThrower
		if not scorer or not scorer.Parent then
			return
		end
		cooling = true
		task.delay(1.5, function()
			cooling = false
		end)

		scores[scorer] = (scores[scorer] or 0) + P.PuntosPorCanasta
		Util.playSound(Config.Sonidos.Silbato, sensor, 0.5, 1.3)

		Net.event(Net.Events.Notify):FireAllClients({
			key = "ball.basket",
			args = { name = scorer.DisplayName, n = P.PuntosPorCanasta },
		})
		Net.event(Net.Events.Score):FireAllClients({
			jugador = scorer.DisplayName,
			puntos = scores[scorer],
		})
		if onScore then
			onScore(scorer, P.CreditosPorCanasta)
		end
	end)
end

-- ── entrada ────────────────────────────────────────────────────────

function PlaygroundService.build(map: any)
	if not map then
		return
	end
	local parent = folder()
	for _, child in parent:GetChildren() do
		if child.Name == "Pelota" or child.Name == "Cancha"
			or child.Name == "Beisbol" or child.Name == "Cesto" then
			child:Destroy()
		end
	end
	table.clear(grabbable)
	table.clear(origins)
	table.clear(carrying)

	local court = Instance.new("Model")
	court.Name = "Cancha"
	court.Parent = parent

	-- La cancha vive en el extremo del pasillo contrario al de la
	-- tienda: asi el recreo tiene dos polos y la gente se reparte.
	local half = Config.Escuela.PasilloLargo / 2
	local z = -half + 14
	local hoopPosition = Vector3.new(0, 0, z)
	local sensor = buildHoop(court, hoopPosition, Vector3.new(0, 0, 1))
	bindBasket(sensor)

	home = Vector3.new(0, P.PelotaRadio + 3, z + P.CanastaDistancia)
	ball = buildBall(parent, home)
	registerGrabbable(ball :: BasePart, home)

	--[[
		El cesto de pelotas de beisbol, en el lado opuesto del atrio: la
		cancha esta contra una punta y la tienda contra la otra, asi que
		esto va al costado, contra la pared, donde no compite con
		ninguno de los dos polos.
	--]]
	local crateZ = -half + 40
	local crateX = -(Config.Escuela.PasilloAncho / 2) + 6
	buildCrate(parent, Vector3.new(crateX, 0, crateZ))

	for i = 1, P.BeisbolCantidad do
		local angle = (i / P.BeisbolCantidad) * math.pi * 2
		local spot = Vector3.new(
			crateX + math.cos(angle) * 1.4,
			P.BeisbolRadio + 2.4,
			crateZ + math.sin(angle) * 1.4)
		registerGrabbable(buildBaseball(parent, spot), spot)
	end
end

--- Si una pelota se pierde (se cae del mapa o queda trabada), vuelve.
function PlaygroundService.watch()
	task.spawn(function()
		while true do
			task.wait(4)
			for _, part in grabbable do
				local origin = origins[part]
				if part.Parent and origin and not bearerOf(part)
					and part.Position.Y < -30 then
					part.AssemblyLinearVelocity = Vector3.zero
					part.CFrame = CFrame.new(origin)
				end
			end
		end
	end)
end

--- Al empezar el examen todo vuelve a su sitio y nadie lleva nada.
function PlaygroundService.reset()
	for player in carrying do
		release(player)
	end
	lastThrower = nil
	for _, part in grabbable do
		local origin = origins[part]
		if part.Parent and origin then
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
			part.CFrame = CFrame.new(origin)
		end
	end
end

function PlaygroundService.start(reward: ((Player, number) -> ())?)
	onScore = reward

	Net.event(Net.Events.Ball).OnServerEvent:Connect(function(player, action, direction)
		if action == "grab" then
			local result = PlaygroundService.grab(player)
			if result.reason then
				Net.event(Net.Events.Notify):FireClient(player, result.reason)
			end
		elseif action == "shoot" then
			PlaygroundService.shoot(player, direction)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		if holder == player then
			release()
		end
		scores[player] = nil
		lastThrow[player] = nil
	end)

	PlaygroundService.watch()
end

return PlaygroundService

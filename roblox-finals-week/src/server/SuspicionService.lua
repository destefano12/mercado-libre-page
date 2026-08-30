--!strict
--[[
	SuspicionService
	------------------------------------------------------------------
	La sospecha es un numero de 0 a 1 por alumno. Sube cuando el
	profesor te ve haciendo algo que no corresponde y baja sola si te
	portas bien un rato.

	Lo importante es que una infraccion pesa segun si te vieron:
	  * en el cono de vision  -> pesa entero, y mas si esta cerca;
	  * fuera del cono        -> pesa un 15% (alguien pudo escucharte).

	Cuando alguien cruza el umbral, este modulo no castiga: avisa.
	El castigo lo decide PunishService, para no mezclar las dos cosas.
--]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Theme = require(Shared:WaitForChild("Theme"))
local Util = require(Shared:WaitForChild("Util"))

local S = Config.Sospecha

local SuspicionService = {}

type Entry = {
	value: number,
	peak: number,
	visible: boolean,
	distance: number,
	frozen: boolean,      -- durante recreo / boletin no se acumula
	lastPush: number,
}

local entries: { [Player]: Entry } = {}
local listeners: { (Player, string) -> () } = {}
local active = false

local function entry(player: Player): Entry
	local existing = entries[player]
	if existing then
		return existing
	end
	local created: Entry = {
		value = 0,
		peak = 0,
		visible = false,
		distance = math.huge,
		frozen = true,
		lastPush = 0,
	}
	entries[player] = created
	return created
end

local function push(player: Player, data: Entry)
	Net.event(Net.Events.SuspicionUpdate):FireClient(player, {
		valor = data.value,
		cerca = data.distance <= Config.Profesor.DistanciaCercania,
		visible = data.visible,
		distancia = math.min(data.distance, 999),
	})
end

--- Registra a quien avisar cuando alguien llega al umbral.
function SuspicionService.onThreshold(callback: (Player, string) -> ())
	table.insert(listeners, callback)
end

function SuspicionService.value(player: Player): number
	return entry(player).value
end

function SuspicionService.peak(player: Player): number
	return entry(player).peak
end

function SuspicionService.isVisible(player: Player): boolean
	return entry(player).visible
end

function SuspicionService.distance(player: Player): number
	return entry(player).distance
end

--[[
	El signo de admiracion rojo sobre la cabeza.

	En la referencia, cuando el profesor te fija aparece un `!` rojo
	flotando encima tuyo — y lo ven todos, no solo vos. Es lo que
	convierte "me estan mirando" en informacion publica: tus companeros
	saben que estas quemado y se alejan.

	La barra de sospecha del HUD sigue estando; esto es la senal en el
	mundo, que es la que cambia como juega el resto.
--]]
local function alertMarker(player: Player, on: boolean)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end

	local existing = head:FindFirstChild("Alerta")
	if not on then
		if existing then
			existing:Destroy()
		end
		return
	end
	if existing then
		return
	end

	local billboard = Util.billboard(head, UDim2.fromOffset(70, 90), Vector3.new(0, 3.2, 0))
	billboard.Name = "Alerta"
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 90
	billboard.LightInfluence = 0
	billboard.Parent = head

	local mark = Instance.new("TextLabel")
	mark.Size = UDim2.fromScale(1, 1)
	mark.BackgroundTransparency = 1
	mark.Font = Theme.FontBlack
	mark.Text = "!"
	mark.TextColor3 = Color3.fromRGB(232, 58, 48)
	mark.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	mark.TextStrokeTransparency = 0.15
	mark.TextScaled = true
	mark.Parent = billboard
end

--- Lo llama TeacherAI en cada tick de vision.
function SuspicionService.setSight(player: Player, visible: boolean, distance: number)
	local data = entry(player)
	local changed = data.visible ~= visible
	data.visible = visible
	data.distance = distance
	if changed then
		pcall(alertMarker, player, visible)
	end
end

--- Congela/descongela la acumulacion (recreo, boletin, castigo).
function SuspicionService.setFrozen(player: Player, frozen: boolean)
	entry(player).frozen = frozen
end

function SuspicionService.freezeAll(frozen: boolean)
	for _, player in Players:GetPlayers() do
		entry(player).frozen = frozen
	end
end

function SuspicionService.reset(player: Player)
	local data = entry(player)
	data.value = 0
	data.peak = 0
	push(player, data)
end

function SuspicionService.resetAll()
	for player in entries do
		SuspicionService.reset(player)
	end
end

--- Suma directa, sin mirar si lo vieron (la usa el propio profesor
--- cuando te pilla de frente).
function SuspicionService.add(player: Player, amount: number, reason: string)
	local data = entry(player)
	if data.frozen then
		return
	end
	local before = data.value
	data.value = math.clamp(data.value + amount, 0, S.Umbral)
	data.peak = math.max(data.peak, data.value)
	push(player, data)

	if before < S.Umbral and data.value >= S.Umbral then
		data.value = S.Umbral
		for _, listener in listeners do
			task.spawn(listener, player, reason)
		end
	end
end

--- Una infraccion: pesa segun si el profesor la vio y desde donde.
function SuspicionService.infraction(player: Player, amount: number, reason: string)
	local data = entry(player)
	if data.frozen then
		return
	end
	local weight = 0.15
	if data.visible then
		local near = math.clamp(1 - data.distance / Config.Profesor.DistanciaVision, 0, 1)
		weight = 1 + near * (S.MultiplicadorDistancia - 1)
	end
	SuspicionService.add(player, amount * weight, reason)
end

function SuspicionService.start()
	if active then
		return
	end
	active = true

	Players.PlayerRemoving:Connect(function(player)
		entries[player] = nil
	end)

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for player, data in entries do
			if not player.Parent then
				entries[player] = nil
				continue
			end

			if data.value > 0 and data.value < S.Umbral then
				local rate = data.visible and S.Decaimiento or S.DecaimientoFueraDeVista
				data.value = math.max(0, data.value - rate * dt)
			end

			-- Estar en el cono del profesor mientras dura el examen ya
			-- pone nervioso: sube muy despacio y solo si estas cerca.
			if data.visible and not data.frozen
				and data.distance <= Config.Profesor.DistanciaCercania then
				data.value = math.min(S.Umbral, data.value + S.PorSegundoEnMira * dt * 0.35)
				data.peak = math.max(data.peak, data.value)
			end

			-- El HUD se refresca ~8 veces por segundo: alcanza para que
			-- la barra se vea fluida sin inundar la red.
			if now - data.lastPush >= 0.12 then
				data.lastPush = now
				push(player, data)
			end
		end
	end)
end

return SuspicionService

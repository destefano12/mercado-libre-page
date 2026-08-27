--!strict
--[[
	SuspicionService
	------------------------------------------------------------------
	El termometro del juego. Cada tick mira, para cada alumno:

		* tiene el celu afuera?
		* el profe lo tiene dentro del cono de vision (con raycast real)?
		* ademas le esta revisando la prueba de cerca?

	Y mueve la barra de riesgo. Si llega a 1 -> el profe lo confronta.
	El riesgo se replica al cliente para dibujar el medidor y decidir
	si el boton de "sacar foto" se puede apretar tranquilo.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local T = Config.Teacher

local SuspicionService = {}

type Entry = {
	risk: number,
	phoneOut: boolean,
	seen: boolean,
	factor: number,
	lastPush: number,
	immuneUntil: number,
}

local entries: { [Player]: Entry } = {}
local teacher: any = nil
local onCaught: ((Player) -> ())? = nil
local active = false

local function ensure(player: Player): Entry
	local entry = entries[player]
	if not entry then
		entry = {
			risk = 0,
			phoneOut = false,
			seen = false,
			factor = 0,
			lastPush = 0,
			immuneUntil = 0,
		}
		entries[player] = entry
	end
	return entry
end

function SuspicionService.init(teacherRef: any, caughtCallback: (Player) -> ())
	teacher = teacherRef
	onCaught = caughtCallback
end

function SuspicionService.setPhoneOut(player: Player, out: boolean)
	ensure(player).phoneOut = out
end

function SuspicionService.isPhoneOut(player: Player): boolean
	return ensure(player).phoneOut
end

function SuspicionService.getRisk(player: Player): number
	return ensure(player).risk
end

--- Ventana de gracia (por ejemplo justo despues de que te pillan).
function SuspicionService.pardon(player: Player, seconds: number)
	local entry = ensure(player)
	entry.risk = 0
	entry.immuneUntil = os.clock() + seconds
end

function SuspicionService.reset(player: Player)
	local entry = ensure(player)
	entry.risk = 0
	entry.phoneOut = false
	entry.seen = false
	entry.factor = 0
end

local function targetPosition(player: Player): (Vector3?, Instance?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local head = character:FindFirstChild("Head") :: BasePart?
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local reference = head or root
	if not reference then
		return nil, nil
	end
	-- El celu se mira a la altura del pecho, apenas sobre la tabla del banco.
	return reference.Position - Vector3.new(0, 0.6, 0), character
end

local function push(player: Player, entry: Entry, force: boolean?)
	local now = os.clock()
	if not force and now - entry.lastPush < 0.12 then
		return
	end
	entry.lastPush = now
	Net.event(Net.Events.RiskUpdate):FireClient(player, {
		risk = entry.risk,
		seen = entry.seen,
		inspecting = teacher ~= nil and teacher:isInspecting(player),
		teacherState = teacher and teacher:getState() or "Patrullando",
	})
end

function SuspicionService.start()
	if active then
		return
	end
	active = true

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		if not teacher or not active then
			return
		end
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		local step = accumulator
		accumulator = 0

		local now = os.clock()

		for _, player in Players:GetPlayers() do
			local entry = ensure(player)
			local position, character = targetPosition(player)

			local seen, factor = false, 0
			if position and teacher.canSee then
				seen, factor = teacher:canSee(position, character and { character } or nil)
			end
			entry.seen = seen
			entry.factor = factor

			if now < entry.immuneUntil then
				entry.risk = 0
			elseif entry.phoneOut then
				local inspecting = teacher:isInspecting(player)
				local gain
				if seen and inspecting then
					gain = T.RiskGainInspect * factor
					teacher:alert(1.2)
				elseif seen then
					gain = T.RiskGainSeen * factor
					teacher:alert(0.8)
				else
					gain = T.RiskGainHidden
				end
				entry.risk = math.clamp(entry.risk + gain * step, 0, 1)
				if not seen then
					-- Nervios, sí; pero si nadie te vio, nadie te puede pillar.
					entry.risk = math.min(entry.risk, 0.85)
				end
			else
				-- Guardado: baja mas rapido si el profe ni te mira.
				local decay = T.RiskDecay * (seen and 0.55 or 1.6)
				entry.risk = math.clamp(entry.risk - decay * step, 0, 1)
			end

			if entry.risk >= T.RiskCaught and onCaught then
				entry.risk = 0
				entry.immuneUntil = now + 3
				push(player, entry, true)
				onCaught(player)
			else
				push(player, entry)
			end
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	entries[player] = nil
end)

return SuspicionService

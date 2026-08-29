--!strict
--[[
	KnockoutService
	------------------------------------------------------------------
	Dejar KO al que no suelta las respuestas.

	No es un golpe instantaneo: son empujones. Tres seguidos dentro de
	la ventana y el otro se va al piso; uno solo por la espalda cuenta
	casi por dos. Eso lo convierte en algo que se ve venir y de lo que
	te podes escapar, en vez de un boton de "ganar".

	Al caer, el que empujo se lleva UNA herramienta de la victima. Si
	la victima es un empollon (NPC), se le cae la chuleta: ahi esta el
	premio de verdad.

	En el pasillo es gratis y es la parte tonta del juego. En pleno
	examen es la infraccion mas cara que existe.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local ExamService = require(script.Parent:WaitForChild("ExamService"))
local SuspicionService = require(script.Parent:WaitForChild("SuspicionService"))

local K = Config.Nocaut

local KnockoutService = {}

type Tally = { count: number, expires: number }

local tally: { [Player]: { [Instance]: Tally } } = {}
local lastShove: { [Player]: number } = {}
local downUntil: { [Model]: number } = {}
local nerdHandler: ((Player, Model) -> ())? = nil

function KnockoutService.onNerdDown(handler: (Player, Model) -> ())
	nerdHandler = handler
end

--- Todos los personajes con Humanoid que hay cerca: jugadores y NPC.
local function candidates(): { Model }
	local list: { Model } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	local folder = workspace:FindFirstChild("Personajes")
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("Model") and child:GetAttribute("Empollon") == true then
				table.insert(list, child)
			end
		end
	end
	return list
end

--- El mas cercano que este DELANTE del que empuja.
local function targetOf(player: Player): (Model?, number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil, 0
	end

	local origin = root.Position
	local forward = root.CFrame.LookVector
	local best: Model? = nil
	local bestDistance = K.Alcance
	local bestBack = 0

	for _, model in candidates() do
		if model ~= character then
			local otherRoot = model:FindFirstChild("HumanoidRootPart")
			if otherRoot and otherRoot:IsA("BasePart") then
				local offset = otherRoot.Position - origin
				local distance = offset.Magnitude
				if distance <= bestDistance and forward:Dot(offset.Unit) > 0.35 then
					bestDistance = distance
					best = model
					-- Cuanto coincide su espalda con mi direccion: 1 es
					-- justo por detras.
					bestBack = otherRoot.CFrame.LookVector:Dot(forward)
				end
			end
		end
	end
	return best, bestBack
end

local function playerOf(model: Model): Player?
	return Players:GetPlayerFromCharacter(model)
end

--- Le quita una herramienta al caido y se la da al que lo tiro.
local function steal(from: Model, to: Player)
	local tool = from:FindFirstChildOfClass("Tool")
	if not tool then
		local victim = playerOf(from)
		local backpack = victim and victim:FindFirstChildOfClass("Backpack")
		if backpack then
			tool = backpack:FindFirstChildOfClass("Tool")
		end
	end
	if not tool then
		return
	end
	local backpack = to:FindFirstChildOfClass("Backpack")
	if backpack then
		tool.Parent = backpack
	end
end

local function knockDown(model: Model, by: Player)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return
	end
	if downUntil[model] and os.clock() < downUntil[model] then
		return
	end
	downUntil[model] = os.clock() + K.SegundosKO

	local attackerRoot = by.Character and by.Character:FindFirstChild("HumanoidRootPart")
	local push = attackerRoot and attackerRoot:IsA("BasePart")
		and attackerRoot.CFrame.LookVector or Vector3.new(0, 0, -1)

	humanoid.Sit = false
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = (push + Vector3.new(0, 0.55, 0)).Unit * K.Impulso

	Util.playSound(Config.Sonidos.Impacto, root, 0.5, 0.75)

	local victim = playerOf(model)
	if victim then
		steal(model, by)
		Net.event(Net.Events.Stunned):FireClient(victim, {
			motivo = "ko",
			segundos = K.SegundosKO,
		})
		Net.event(Net.Events.Notify):FireClient(victim, { key = "ko.you" })
		Net.event(Net.Events.Notify):FireAllClients({
			key = "ko.down",
			args = { name = victim.DisplayName },
		})
	elseif model:GetAttribute("Empollon") == true then
		if nerdHandler then
			nerdHandler(by, model)
		end
	end

	task.delay(K.SegundosKO, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
		end
		downUntil[model] = nil
	end)
end

--- Un empujon. Devuelve el motivo si no se pudo.
function KnockoutService.shove(player: Player): any
	local now = os.clock()
	if now - (lastShove[player] or -math.huge) < K.Enfriamiento then
		return { ok = false }
	end

	local target, back = targetOf(player)
	if not target then
		return { ok = false, reason = { key = "ko.nobody" } }
	end
	lastShove[player] = now

	-- Empujar en pleno examen es lo mas caro del juego.
	if ExamService.isRunning() then
		SuspicionService.infraction(player, K.SospechaEnExamen, "ko")
		Net.event(Net.Events.Notify):FireClient(player, { key = "ko.in_class" })
	end

	local mine = tally[player]
	if not mine then
		mine = {}
		tally[player] = mine
	end
	local entry = mine[target]
	if not entry or now > entry.expires then
		entry = { count = 0, expires = now + K.VentanaEmpujones }
		mine[target] = entry
	end

	-- Por la espalda cuenta casi doble: pillarlo desprevenido es medio
	-- KO de entrada.
	entry.count += (back >= K.PorLaEspalda) and 2 or 1
	entry.expires = now + K.VentanaEmpujones

	local humanoid = target:FindFirstChildOfClass("Humanoid")
	local root = target:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") and humanoid then
		local attackerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local push = attackerRoot and attackerRoot:IsA("BasePart")
			and attackerRoot.CFrame.LookVector or Vector3.new(0, 0, -1)
		root.AssemblyLinearVelocity += push * 16 + Vector3.new(0, 6, 0)
	end

	if entry.count >= K.EmpujonesParaKO then
		mine[target] = nil
		knockDown(target, player)
		return { ok = true, ko = true }
	end

	local name = playerOf(target)
	Net.event(Net.Events.Notify):FireClient(player, {
		key = "ko.push",
		args = { name = name and name.DisplayName or target.Name },
	})
	return { ok = true, ko = false }
end

function KnockoutService.start()
	Net.event(Net.Events.Knock).OnServerEvent:Connect(function(player)
		local result = KnockoutService.shove(player)
		if result.reason then
			Net.event(Net.Events.Notify):FireClient(player, result.reason)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		tally[player] = nil
		lastShove[player] = nil
	end)
end

return KnockoutService

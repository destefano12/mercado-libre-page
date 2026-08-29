--!strict
--[[
	NerdNPCs
	------------------------------------------------------------------
	Los alumnos que si estudiaron.

	Estan en el pasillo, con el libro bajo el brazo, y saben respuestas
	del examen que viene. Hay dos formas de sacarselas:

	  pedirselas   gratis, rapido, y a veces te dicen que no
	  tirarlos     siempre funciona, se les cae la chuleta, y en pleno
	               examen te cuesta carisimo

	Esa es toda la mecanica: la via amable es incierta y la via bruta
	es segura pero cara. Si pedir siempre funcionara, nadie empujaria a
	nadie; si nunca funcionara, no habria decision.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local CharacterService = require(script.Parent:WaitForChild("CharacterService"))
local ExamService = require(script.Parent:WaitForChild("ExamService"))

local E = Config.Empollones

local NerdNPCs = {}

local nerds: { Model } = {}
local askCooldown: { [Model]: { [Player]: number } } = {}
local animations: { RBXScriptConnection } = {}
local rng = Random.new()

local function nameFor(index: number): string
	return E.Nombres[((index - 1) % #E.Nombres) + 1]
end

local function bindPrompt(model: Model, index: number)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Pedir"
	prompt.ActionText = "Pedir respuestas"
	prompt.ObjectText = nameFor(index)
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	prompt.Triggered:Connect(function(player)
		local perModel = askCooldown[model]
		if not perModel then
			perModel = {}
			askCooldown[model] = perModel
		end
		local now = os.clock()
		if now - (perModel[player] or -math.huge) < E.EnfriamientoPedir then
			Net.event(Net.Events.Notify):FireClient(player, {
				key = "nerd.wait",
				args = { name = nameFor(index) },
			})
			return
		end
		perModel[player] = now

		if rng:NextNumber() > E.ProbabilidadDeCeder then
			Net.event(Net.Events.Notify):FireClient(player, {
				key = "nerd.refused",
				args = { name = nameFor(index) },
			})
			Util.playSound(Config.Sonidos.Error, root, 0.3, 0.9)
			return
		end

		ExamService.grantKnowledge(player, 1)
		Net.event(Net.Events.Notify):FireClient(player, {
			key = "book.learned",
			args = { n = 1 },
		})
		Util.playSound(Config.Sonidos.Acierto, root, 0.3, 1.2)
	end)
end

--- Se le cayo la chuleta: el que lo tiro se lleva varias respuestas.
function NerdNPCs.dropSheet(player: Player, model: Model)
	ExamService.grantKnowledge(player, E.RespuestasAlCaer)
	Net.event(Net.Events.Notify):FireAllClients({
		key = "nerd.dropped",
		args = { name = model:GetAttribute("Alumno") or model.Name },
	})
	Net.event(Net.Events.Notify):FireClient(player, {
		key = "book.learned",
		args = { n = E.RespuestasAlCaer },
	})
end

function NerdNPCs.despawn()
	for _, connection in animations do
		connection:Disconnect()
	end
	animations = {}
	for _, model in nerds do
		if model.Parent then
			model:Destroy()
		end
	end
	nerds = {}
	askCooldown = {}
end

--- Los reparte por el pasillo, mirando hacia el centro.
function NerdNPCs.spawn(map: any)
	NerdNPCs.despawn()
	if not map then
		return
	end

	local parent = CharacterService.folder()
	local halfW = Config.Escuela.PasilloAncho / 2
	local halfL = Config.Escuela.PasilloLargo / 2

	--[[
		La franja donde se paran, derivada de la config en vez de las
		constantes 46 y 86 que habia antes: esas estaban calibradas a
		mano contra un pasillo de 190 de largo y al reproporcionar el
		atrio dejaban a los empollones encimados o fuera del piso.

		Van entre la pared del fondo y donde arranca la zona de recreo,
		pegados a los casilleros.
	--]]
	local bandStart = -halfL + 24
	local bandEnd = halfL - Config.Escuela.ZonaRecreoLargo - 8
	local step = (bandEnd - bandStart) / math.max(1, E.Cantidad)

	for i = 1, E.Cantidad do
		local side = (i % 2 == 0) and 1 or -1
		local z = bandStart + (i - 0.5) * step
		local position = Vector3.new(side * (halfW - 5.5), 3, z)

		local ok, err = pcall(function()
			local model = CharacterService.buildStudent(nameFor(i), position)
			model.Name = "Empollon" .. i
			model:SetAttribute("Empollon", true)
			model:SetAttribute("Alumno", nameFor(i))
			model.Parent = parent

			-- Mirando hacia el centro del pasillo, como quien espera.
			local root = model.PrimaryPart
			if root then
				root.CFrame = CFrame.lookAt(position, Vector3.new(0, 3, z))
			end

			bindPrompt(model, i)
			local connection = CharacterService.animate(model)
			if connection then
				table.insert(animations, connection)
			end
			table.insert(nerds, model)
		end)
		if not ok then
			warn("[Empollones] " .. tostring(err))
		end
	end

	print(string.format("[Empollones] %d alumnos estudiosos en el pasillo.", #nerds))
end

function NerdNPCs.list(): { Model }
	return nerds
end

return NerdNPCs

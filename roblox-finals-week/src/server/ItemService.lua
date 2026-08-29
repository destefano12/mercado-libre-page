--!strict
--[[
	ItemService
	------------------------------------------------------------------
	Todo lo que se lleva en la mano: inventario, casilleros, notas
	escritas y objetos que vuelan por el aire.

	El lanzamiento es fisico de verdad, no un efecto:
	  1. el cliente manda solo una direccion (nunca una posicion);
	  2. el servidor la normaliza y tira un Raycast corto para no
	     crear el proyectil dentro de una pared;
	  3. se clona el Handle de la plantilla, se le da velocidad y se le
	     resta gravedad con un VectorForce (Config.Objetos);
	  4. el Touched decide: si pego a un alumno, le entrega la nota;
	     si pego a cualquier otra cosa, hace ruido y el profesor va.

	Nada de esto confia en el cliente: la direccion se valida, el
	enfriamiento se mide en el servidor y el objeto se descuenta ahi.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local Templates = require(script.Parent:WaitForChild("Templates"))
local ExamService = require(script.Parent:WaitForChild("ExamService"))
local SuspicionService = require(script.Parent:WaitForChild("SuspicionService"))

local O = Config.Objetos

local ItemService = {}

type NotePayload = { indice: number?, opcion: number?, texto: string }

local lastThrow: { [Player]: number } = {}
local lockerCooldown: { [Model]: number } = {}
local noiseListeners: { (Vector3, Player?) -> () } = {}
local notes: { [Player]: NotePayload } = {}

local rng = Random.new()

local LOOT = { "nota", "nota", "bolita", "bolita", "avion", "chuleta" }

--- Avisa a TeacherAI de que sono algo en un punto del mapa.
function ItemService.onNoise(callback: (Vector3, Player?) -> ())
	table.insert(noiseListeners, callback)
end

local function noise(position: Vector3, source: Player?)
	for _, listener in noiseListeners do
		task.spawn(listener, position, source)
	end
end

local function projectileFolder(): Folder
	local existing = workspace:FindFirstChild("Proyectiles")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "Proyectiles"
	folder.Parent = workspace
	return folder
end

-- ── inventario ─────────────────────────────────────────────────────

function ItemService.give(player: Player, itemId: string): Tool?
	local tool = Templates.clone(itemId)
	if not tool then
		return nil
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		tool:Destroy()
		return nil
	end
	tool.Parent = backpack

	if itemId == "chuleta" then
		ExamService.grantSheetUses(player, O.ChuletaUsos)
	end
	return tool
end

function ItemService.clearInventory(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in backpack:GetChildren() do
			if child:IsA("Tool") then
				child:Destroy()
			end
		end
	end
	local character = player.Character
	if character then
		for _, child in character:GetChildren() do
			if child:IsA("Tool") then
				child:Destroy()
			end
		end
	end
end

--- Cuenta cuantos de un objeto tiene encima (mochila + mano).
local function countItem(player: Player, itemId: string): number
	local total = 0
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in backpack:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("Item") == itemId then
				total += 1
			end
		end
	end
	local character = player.Character
	if character then
		for _, child in character:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("Item") == itemId then
				total += 1
			end
		end
	end
	return total
end

--- La herramienta que tiene equipada ahora mismo (la que esta en la mano).
local function equipped(player: Player): Tool?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Tool")
end

-- ── casilleros ─────────────────────────────────────────────────────

function ItemService.bindLockers(lockers: { Model })
	for _, locker in lockers do
		local door = locker:FindFirstChild("Puerta")
		local prompt = door and door:FindFirstChild("Abrir")
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(player)
				local now = os.clock()
				local last = lockerCooldown[locker] or -math.huge
				if now - last < O.CasilleroEnfriamiento then
					Net.event(Net.Events.Notify):FireClient(player, { key = "notify.locker_wait" })
					return
				end
				lockerCooldown[locker] = now

				Util.playSound(Config.Sonidos.Casillero, door :: BasePart, 0.4,
					rng:NextNumber(0.9, 1.1))

				-- Un casillero de cada cuatro esta vacio: si siempre
				-- dieran algo, no valdria la pena elegir cual abrir.
				if rng:NextNumber() < 0.25 then
					Net.event(Net.Events.Notify):FireClient(player, { key = "notify.locker_empty" })
					return
				end

				local itemId = LOOT[rng:NextInteger(1, #LOOT)]
				if ItemService.give(player, itemId) then
					Net.event(Net.Events.Notify):FireClient(player, {
						key = "notify.locker",
						args = { item = "@item." .. itemId },
					})
				end
			end)
		end
	end
end

-- ── notas escritas ─────────────────────────────────────────────────

function ItemService.setNote(player: Player, payload: any)
	if type(payload) ~= "table" then
		return
	end
	local text = tostring(payload.texto or "")
	if #text > O.NotaCaracteres then
		text = string.sub(text, 1, O.NotaCaracteres)
	end
	local index = tonumber(payload.indice)
	local option = tonumber(payload.opcion)
	notes[player] = {
		indice = index and math.floor(index) or nil,
		opcion = option and math.floor(option) or nil,
		texto = text,
	}

	local tool = equipped(player)
	if tool then
		local value = tool:FindFirstChild("Texto")
		if value and value:IsA("StringValue") then
			value.Value = text
		end
	end
end

-- ── lanzamiento ────────────────────────────────────────────────────

local function deliver(target: Player, thrower: Player, payload: NotePayload?)
	if not payload then
		return
	end
	Net.event(Net.Events.NoteReceived):FireClient(target, {
		de = thrower.DisplayName,
		texto = payload.texto,
		indice = payload.indice,
		opcion = payload.opcion,
	})
	Net.event(Net.Events.Notify):FireClient(target, {
		key = "note.received",
		args = { name = thrower.DisplayName },
	})
	if payload.indice and payload.opcion then
		ExamService.applyNote(target, payload.indice, payload.opcion)
	end
end

--- Lanza el objeto que el jugador tiene en la mano.
function ItemService.throw(player: Player, direction: any): any
	local tool = equipped(player)
	if not tool then
		return { ok = false, reason = { key = "cheat.none" } }
	end
	if tool:GetAttribute("Lanzable") ~= true then
		return { ok = false, reason = { key = "cheat.none" } }
	end

	local now = os.clock()
	if now - (lastThrow[player] or -math.huge) < O.EnfriamientoLanzar then
		return { ok = false, reason = { key = "cheat.cooldown" } }
	end

	if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.05 then
		return { ok = false, reason = { key = "error.generic" } }
	end
	local aim = direction.Unit

	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return { ok = false, reason = { key = "error.generic" } }
	end

	lastThrow[player] = now

	-- Raycast corto: si hay una pared pegada a la cara, el proyectil
	-- nace justo antes de ella y no atraviesa el aula.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, projectileFolder() }
	local clearance = 2.2
	local blocked = workspace:Raycast(head.Position, aim * clearance, params)
	local origin = head.Position + aim * (blocked and math.max(0.4, blocked.Distance - 0.3) or clearance)

	local handle = tool:FindFirstChild("Handle")
	local body: BasePart
	if handle and handle:IsA("BasePart") then
		body = handle:Clone()
	else
		body = Instance.new("Part")
		body.Size = Vector3.new(0.6, 0.6, 0.6)
	end
	body.Name = "Proyectil"
	-- El Handle original puede traer welds a piezas decorativas que no
	-- se clonan (el pliegue de la nota, las alas del avion): esas
	-- uniones apuntarian a partes destruidas.
	for _, child in body:GetChildren() do
		if child:IsA("WeldConstraint") or child:IsA("Weld") or child:IsA("Motor6D") then
			child:Destroy()
		end
	end
	body.Anchored = false
	body.CanCollide = true
	body.CanTouch = true
	body.Massless = false
	body.CFrame = CFrame.lookAt(origin, origin + aim)
	body.Parent = projectileFolder()

	local reach = tonumber(tool:GetAttribute("Alcance")) or 1
	body.AssemblyLinearVelocity = aim * O.VelocidadLanzamiento * reach
	body.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), 0)

	-- Menos gravedad: el papel flota, no cae como una piedra.
	local attachment = Instance.new("Attachment")
	attachment.Parent = body
	local lift = Instance.new("VectorForce")
	lift.Attachment0 = attachment
	lift.RelativeTo = Enum.ActuatorRelativeTo.World
	lift.Force = Vector3.new(0, body.AssemblyMass * workspace.Gravity * (1 - O.GravedadProyectil), 0)
	lift.Parent = body

	local payload = notes[player]
	local isNoise = tool:GetAttribute("Ruido") ~= nil

	-- Lanzar en pleno examen es la infraccion mas cara.
	if ExamService.isRunning() then
		SuspicionService.infraction(player, Config.Sospecha.PorLanzar, "throw")
	end

	Util.playSound(Config.Sonidos.Papel, body, 0.3, rng:NextNumber(1.1, 1.4))

	local spent = false
	local function land(position: Vector3, hitPlayer: Player?)
		if spent then
			return
		end
		spent = true
		if hitPlayer and hitPlayer ~= player then
			deliver(hitPlayer, player, payload)
			Net.event(Net.Events.Notify):FireClient(hitPlayer, { key = "notify.hit" })
		end
		if isNoise then
			noise(position, player)
		end
		Util.playSound(Config.Sonidos.Impacto, workspace :: any, 0.25, 1.6)
		task.delay(1.2, function()
			if body.Parent then
				body:Destroy()
			end
		end)
	end

	body.Touched:Connect(function(hit)
		if spent then
			return
		end
		local model = hit:FindFirstAncestorOfClass("Model")
		local hitPlayer = model and Players:GetPlayerFromCharacter(model) or nil
		if hitPlayer == player then
			return
		end
		land(body.Position, hitPlayer)
	end)

	task.delay(O.VidaProyectil, function()
		if not spent then
			land(body.Position, nil)
		end
		if body.Parent then
			body:Destroy()
		end
	end)

	tool:Destroy()
	notes[player] = nil
	return { ok = true, reason = { key = "note.sent" } }
end

-- ── remotes ────────────────────────────────────────────────────────

function ItemService.start()
	Net.event(Net.Events.Throw).OnServerEvent:Connect(function(player, direction)
		local result = ItemService.throw(player, direction)
		if not result.ok and result.reason then
			Net.event(Net.Events.Notify):FireClient(player, result.reason)
		end
	end)

	Net.event(Net.Events.NoteText).OnServerEvent:Connect(function(player, payload)
		ItemService.setNote(player, payload)
	end)

	Net.event(Net.Events.Cheat).OnServerEvent:Connect(function(player, action, index, extra)
		local i = tonumber(index) and math.floor(tonumber(index) :: number) or 1
		local result: any
		if action == "peek" then
			result = ExamService.peek(player, i)
		elseif action == "whisper" then
			result = ExamService.whisper(player, i)
		elseif action == "sheet" then
			result = ExamService.useSheet(player)
		elseif action == "book" then
			result = ItemService.onReadBook(player)
		elseif action == "zoom" then
			-- El cliente dice a QUIEN apunta; el servidor comprueba que
			-- esten en la misma aula y dentro del alcance del aparato.
			local target = ItemService.playerFromId(extra)
			if target then
				result = ExamService.peekAt(player, target, i,
					Config.Herramientas.PrismaticosAlcance)
			else
				result = { ok = false, reason = { key = "zoom.no_target" } }
			end
		else
			result = { ok = false, reason = { key = "error.generic" } }
		end
		if result.reason then
			Net.event(Net.Events.Notify):FireClient(player, result.reason)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastThrow[player] = nil
		notes[player] = nil
	end)
end

function ItemService.countOf(player: Player, itemId: string): number
	return countItem(player, itemId)
end

--- Lo rellena init.server con BookService.readTool: ItemService no
--- tiene por que saber como funcionan los libros.
ItemService.onReadBook = function(_player: Player): any
	return { ok = false, reason = { key = "cheat.none" } }
end

function ItemService.playerFromId(userId: any): Player?
	local id = tonumber(userId)
	if not id then
		return nil
	end
	for _, player in Players:GetPlayers() do
		if player.UserId == id then
			return player
		end
	end
	return nil
end

return ItemService

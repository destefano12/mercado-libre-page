--!strict
--[[
	LobbyService
	------------------------------------------------------------------
	Salas para jugar con amigos: crear una, buscarla por nombre y
	entrar, con contrasena si la queres privada.

	Roblox no tiene "salas", tiene servidores. Lo que hace esto:

		crear  -> TeleportService:ReserveServer() devuelve el codigo de
		          un servidor nuevo y vacio del mismo juego, y ese
		          codigo se publica en un MemoryStore que todos los
		          servidores del juego pueden leer
		entrar -> se lee el codigo del MemoryStore y se teletransporta

	La sala avisa que sigue viva desde adentro: el servidor reservado
	recibe su propio codigo por TeleportData, actualiza cuanta gente
	hay y borra el aviso al quedar vacio. Sin eso el listado se
	llenaria de salas fantasma.

	Nada de esto existe en Studio (no hay servidores que reservar): ahi
	devuelve "no disponible" y se juega local igual.
--]]

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local L = Config.Salas

local LobbyService = {}

local LIMITE_NOMBRE = 24
local LIMITE_CLAVE = 16

local UNAVAILABLE = { ok = false, reason = { key = "room.unavailable" } }

local rooms: SortedMap? = nil
local myCode: string? = nil

local function store(): SortedMap?
	if rooms then
		return rooms
	end
	local ok, map = pcall(function()
		return MemoryStoreService:GetSortedMap(L.MapaMemoria)
	end)
	if ok then
		rooms = map
	end
	return rooms
end

local function available(): boolean
	return game.PlaceId ~= 0 and store() ~= nil
end

local function clean(text: any, limit: number): string
	if typeof(text) ~= "string" then
		return ""
	end
	local trimmed = string.gsub(text, "^%s+", "")
	trimmed = string.gsub(trimmed, "%s+$", "")
	return string.sub(trimmed, 1, limit)
end

local function capacities(): (number, number)
	local list = L.CapacidadesPosibles
	local min, max = list[1], list[1]
	for _, value in list do
		min = math.min(min, value)
		max = math.max(max, value)
	end
	return min, max
end

-- ── listar ─────────────────────────────────────────────────────────

function LobbyService.list(_player: Player, query: any): any
	if not available() then
		return UNAVAILABLE
	end

	local map = store() :: SortedMap
	local ok, entries = pcall(function()
		return map:GetRangeAsync(Enum.SortDirection.Ascending, L.MaximoListado)
	end)
	if not ok then
		return UNAVAILABLE
	end

	local needle = string.lower(clean(query, LIMITE_NOMBRE))
	local list = {}

	for _, entry in entries do
		local room = entry.value
		if typeof(room) == "table" and room.name then
			local matches = needle == ""
				or string.find(string.lower(room.name), needle, 1, true) ~= nil
			if matches then
				table.insert(list, {
					code = entry.key,
					name = room.name,
					host = room.host,
					count = room.count or 0,
					maxPlayers = room.maxPlayers or L.CapacidadPorDefecto,
					-- La clave nunca sale del servidor: solo si tiene o no.
					locked = (room.password or "") ~= "",
				})
			end
		end
	end

	table.sort(list, function(a, b)
		return a.count > b.count
	end)

	return { ok = true, rooms = list }
end

-- ── crear ──────────────────────────────────────────────────────────

function LobbyService.create(player: Player, options: any): any
	if not available() then
		return UNAVAILABLE
	end
	if typeof(options) ~= "table" then
		return { ok = false, reason = { key = "room.name" } }
	end

	local name = clean(options.name, LIMITE_NOMBRE)
	if name == "" then
		return { ok = false, reason = { key = "room.name" } }
	end

	local password = clean(options.password, LIMITE_CLAVE)
	local min, max = capacities()
	local maxPlayers = math.clamp(
		typeof(options.maxPlayers) == "number" and math.floor(options.maxPlayers)
			or L.CapacidadPorDefecto,
		min, max)

	local reserved, code = pcall(function()
		return TeleportService:ReserveServer(game.PlaceId)
	end)
	if not reserved then
		return UNAVAILABLE
	end

	local map = store() :: SortedMap
	local saved = pcall(function()
		map:SetAsync(code, {
			name = name,
			host = player.DisplayName,
			password = password,
			maxPlayers = maxPlayers,
			count = 0,
		}, L.VidaEntrada)
	end)
	if not saved then
		return UNAVAILABLE
	end

	return LobbyService.send(player, code)
end

-- ── entrar ─────────────────────────────────────────────────────────

--- Manda al jugador al servidor de la sala, con el codigo adentro del
--- TeleportData para que esa sala sepa cual es su propio aviso.
function LobbyService.send(player: Player, code: string): any
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	options:SetTeleportData({ roomCode = code })

	local sent = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not sent then
		return UNAVAILABLE
	end
	return { ok = true, code = code, reason = { key = "room.created", args = { code = code } } }
end

function LobbyService.join(player: Player, code: any, password: any): any
	if not available() then
		return UNAVAILABLE
	end
	if typeof(code) ~= "string" then
		return { ok = false, reason = { key = "room.gone" } }
	end

	local map = store() :: SortedMap
	local ok, room = pcall(function()
		return map:GetAsync(code)
	end)
	if not ok or typeof(room) ~= "table" then
		return { ok = false, reason = { key = "room.gone" } }
	end

	if (room.password or "") ~= "" and clean(password, LIMITE_CLAVE) ~= room.password then
		return { ok = false, reason = { key = "room.wrong_password" } }
	end
	if (room.count or 0) >= (room.maxPlayers or L.CapacidadPorDefecto) then
		return { ok = false, reason = { key = "room.full" } }
	end

	return LobbyService.send(player, code)
end

-- ── desde adentro de la sala ───────────────────────────────────────

local function findMyCode(): string?
	for _, player in Players:GetPlayers() do
		local ok, data = pcall(function()
			return player:GetJoinData().TeleportData
		end)
		if ok and typeof(data) == "table" and typeof(data.roomCode) == "string" then
			return data.roomCode
		end
	end
	return nil
end

--- Si este servidor es una sala, mantiene vivo su aviso con la gente
--- que hay adentro, y lo borra cuando se vacia.
function LobbyService.startHeartbeat()
	if not available() then
		return
	end

	task.spawn(function()
		while true do
			myCode = myCode or findMyCode()
			if myCode then
				local map = store() :: SortedMap
				local count = #Players:GetPlayers()
				pcall(function()
					map:UpdateAsync(myCode :: string, function(room)
						if typeof(room) ~= "table" then
							return nil
						end
						room.count = count
						return room
					end, L.VidaEntrada)
				end)

				if count == 0 then
					pcall(function()
						map:RemoveAsync(myCode :: string)
					end)
					myCode = nil
				end
			end
			task.wait(L.Latido)
		end
	end)
end

function LobbyService.isAvailable(): boolean
	return available()
end

function LobbyService.start()
	Net.func(Net.Functions.ListRooms).OnServerInvoke = function(player, query)
		return LobbyService.list(player, query)
	end
	Net.func(Net.Functions.CreateRoom).OnServerInvoke = function(player, options)
		return LobbyService.create(player, options)
	end
	Net.func(Net.Functions.JoinRoom).OnServerInvoke = function(player, code, password)
		return LobbyService.join(player, code, password)
	end
	LobbyService.startHeartbeat()
end

return LobbyService

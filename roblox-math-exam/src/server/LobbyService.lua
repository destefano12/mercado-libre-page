--!strict
--[[
	LobbyService
	------------------------------------------------------------------
	Salas: crear una, buscarla por nombre y entrar, con contraseña si
	querés que sea privada.

	Roblox no tiene "salas" — tiene servidores. Lo que hace esto:

		crear  -> TeleportService:ReserveServer() da el codigo de un
		          servidor nuevo y vacio del mismo juego, y el codigo se
		          publica en un MemoryStore que todos los servidores ven
		entrar -> se lee el codigo del MemoryStore y se teletransporta

	La sala avisa que sigue viva desde adentro: el servidor reservado
	recibe su propio codigo por TeleportData, actualiza cuanta gente hay
	y borra el aviso cuando queda vacio. Sin eso el listado se llenaria
	de salas fantasma.

	Nada de esto existe en Studio (no hay servidores que reservar), asi
	que ahi devuelve "no disponible" y se sigue jugando local.
--]]

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local L = Config.Lobby

local LobbyService = {}

local UNAVAILABLE = { ok = false, reason = { key = "lobby.unavailable" } }

local rooms: SortedMap? = nil
local myCode: string? = nil

local function store(): SortedMap?
	if rooms then
		return rooms
	end
	local ok, map = pcall(function()
		return MemoryStoreService:GetSortedMap("AulaSalas")
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

-- ─────────────────────────────────────────────────────────────
-- Listar
-- ─────────────────────────────────────────────────────────────

function LobbyService.list(player: Player, query: any)
	if not available() then
		return UNAVAILABLE
	end

	local map = store() :: SortedMap
	local ok, entries = pcall(function()
		return map:GetRangeAsync(Enum.SortDirection.Ascending, L.MaxRooms)
	end)
	if not ok then
		return UNAVAILABLE
	end

	local needle = string.lower(clean(query, L.NameLimit))
	local list = {}

	for _, entry in entries do
		local room = entry.value
		if typeof(room) == "table" and room.name then
			local matches = needle == "" or string.find(string.lower(room.name), needle, 1, true) ~= nil
			if matches then
				table.insert(list, {
					code = entry.key,
					name = room.name,
					host = room.host,
					count = room.count or 0,
					maxPlayers = room.maxPlayers or L.DefaultMaxPlayers,
					-- La contraseña nunca sale del servidor: solo si tiene.
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

-- ─────────────────────────────────────────────────────────────
-- Crear
-- ─────────────────────────────────────────────────────────────

function LobbyService.create(player: Player, options: any)
	if not available() then
		return UNAVAILABLE
	end
	if typeof(options) ~= "table" then
		return { ok = false, reason = { key = "lobby.needName" } }
	end

	local name = clean(options.name, L.NameLimit)
	if name == "" then
		return { ok = false, reason = { key = "lobby.needName" } }
	end

	local password = clean(options.password, L.PasswordLimit)
	local maxPlayers = math.clamp(
		typeof(options.maxPlayers) == "number" and math.floor(options.maxPlayers) or L.DefaultMaxPlayers,
		L.MinPlayers, L.MaxPlayers)

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
		}, L.RoomTTL)
	end)
	if not saved then
		return UNAVAILABLE
	end

	return LobbyService.send(player, code)
end

-- ─────────────────────────────────────────────────────────────
-- Entrar
-- ─────────────────────────────────────────────────────────────

--- Manda al jugador al servidor de una sala, con el codigo adentro del
--- TeleportData para que esa sala sepa cual es su propio aviso.
function LobbyService.send(player: Player, code: string)
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	options:SetTeleportData({ roomCode = code })

	local sent = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not sent then
		return UNAVAILABLE
	end
	return { ok = true }
end

function LobbyService.join(player: Player, code: any, password: any)
	if not available() then
		return UNAVAILABLE
	end
	if typeof(code) ~= "string" then
		return { ok = false, reason = { key = "lobby.gone" } }
	end

	local map = store() :: SortedMap
	local ok, room = pcall(function()
		return map:GetAsync(code)
	end)
	if not ok or typeof(room) ~= "table" then
		return { ok = false, reason = { key = "lobby.gone" } }
	end

	if (room.password or "") ~= "" and clean(password, L.PasswordLimit) ~= room.password then
		return { ok = false, reason = { key = "lobby.wrongPassword" } }
	end
	if (room.count or 0) >= (room.maxPlayers or L.DefaultMaxPlayers) then
		return { ok = false, reason = { key = "lobby.full" } }
	end

	return LobbyService.send(player, code)
end

-- ─────────────────────────────────────────────────────────────
-- Desde adentro de la sala
-- ─────────────────────────────────────────────────────────────

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
					map:UpdateAsync(myCode, function(room)
						if typeof(room) ~= "table" then
							return nil
						end
						room.count = count
						return room
					end, L.RoomTTL)
				end)

				if count == 0 then
					pcall(function()
						map:RemoveAsync(myCode :: string)
					end)
					myCode = nil
				end
			end
			task.wait(L.HeartbeatEvery)
		end
	end)
end

function LobbyService.isAvailable(): boolean
	return available()
end

return LobbyService

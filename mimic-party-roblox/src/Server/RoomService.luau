--!nonstrict
-- RoomService.luau — private rooms, by code, on real separate servers.
--
-- How a room actually works:
--
--   host presses CREAR
--     → TeleportService:ReserveServerAsync(game.PlaceId) returns an access code
--       for a brand new, empty server of THIS SAME place
--     → a short 5-character human code is claimed in a DataStore, pointing at
--       that access code
--     → the host is teleported into it, carrying the room's settings in the
--       teleport data
--
--   someone types the code
--     → the DataStore turns it back into the access code
--     → TeleportAsync with ReservedServerAccessCode drops them into the very
--       same server the host is in
--
-- So "distintas salas" are distinct servers, not channels inside one server.
-- That is what makes five simultaneous parties possible, and it is why the code
-- has to live somewhere both servers can read — hence the DataStore.
--
-- The host owns exactly two things: which sound packs are in play, and who is
-- allowed to stay. Deliberately nothing else: no score editing, no skipping a
-- round, no muting an individual. A host who could mute people would break the
-- one rule the game is built on.

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Shared = game.ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Rooms = require(Shared.Rooms)
local SoundLibrary = require(Shared.SoundLibrary)

local RoomService = {}
local R = Config.ROOM

-- ── state ────────────────────────────────────────────────────────────────────

local state = {
	isRoom = false,          -- is this server a reserved room?
	code = nil,
	hostUserId = nil,
	packs = {},              -- packId → true
	createdAt = os.time(),
	joinOrder = {},          -- userId → monotonic counter, for host inheritance
	_order = 0,
}

local lastCreate = {}        -- userId → os.clock()
local lastJoin = {}

local store
local storeError
local storeProbed = false

local function dataStore()
	if store or storeError then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Rooms.DATASTORE)
	end)
	if ok and result then
		store = result
	else
		storeError = tostring(result)
		warn("[RoomService] DataStore unavailable: " .. storeError)
	end
	return store
end

-- GetDataStore hands back a handle even in Studio with API access switched off:
-- only a real read tells you whether rooms can actually work. Probed once at
-- boot so the UI can disable CREAR SALA with a reason instead of failing on the
-- host's click.
local function probeDataStore()
	if storeProbed then
		return store ~= nil and storeError == nil
	end
	storeProbed = true
	local ds = dataStore()
	if not ds then
		return false
	end
	local ok, err = pcall(function()
		ds:GetAsync("__probe")
	end)
	if not ok then
		storeError = tostring(err)
		warn("[RoomService] DataStore read refused: " .. storeError)
		return false
	end
	return true
end

local function roomsAvailable()
	return storeProbed and store ~= nil and storeError == nil
end

-- Every pack on by default.
local function defaultPacks()
	local packs = {}
	for _, pack in ipairs(SoundLibrary.packs()) do
		packs[pack.id] = true
	end
	return packs
end

state.packs = defaultPacks()

-- ── reserved-server detection ────────────────────────────────────────────────

-- A reserved server has a PrivateServerId but no owner; a VIP/private server
-- has both. Only the first is a room we created.
local function detectRoom()
	local privateId = game.PrivateServerId
	local ownerId = game.PrivateServerOwnerId
	return type(privateId) == "string" and privateId ~= "" and (ownerId == nil or ownerId == 0)
end

-- ── broadcast ────────────────────────────────────────────────────────────────

local function roster()
	local out = {}
	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(out, {
			userId = player.UserId,
			name = player.DisplayName,
			isHost = player.UserId == state.hostUserId,
		})
	end
	table.sort(out, function(a, b)
		return (state.joinOrder[a.userId] or 0) < (state.joinOrder[b.userId] or 0)
	end)
	return out
end

local function packList()
	local out = {}
	for _, pack in ipairs(SoundLibrary.packs()) do
		local count = 0
		for _ in ipairs(pack.sounds) do
			count += 1
		end
		table.insert(out, {
			id = pack.id,
			name = pack.name,
			blurb = pack.blurb,
			sounds = count,
			enabled = state.packs[pack.id] == true,
		})
	end
	return out
end

function RoomService.broadcast()
	Net.fireAll(Net.RoomState, {
		isRoom = state.isRoom,
		code = state.code,
		display = state.code and Rooms.display(state.code) or nil,
		hostUserId = state.hostUserId,
		packs = packList(),
		roster = roster(),
		canCreate = roomsAvailable(),
		-- Published-game-only features fail loudly rather than silently.
		unavailable = (not roomsAvailable())
			and "Las salas necesitan acceso a DataStores: publicá el juego, o en Studio activá Game Settings → Security → Enable Studio Access to API Services."
			or nil,
	})
end

local function broadcastTo(player)
	Net.fireClient(Net.RoomState, player, {
		isRoom = state.isRoom,
		code = state.code,
		display = state.code and Rooms.display(state.code) or nil,
		hostUserId = state.hostUserId,
		packs = packList(),
		roster = roster(),
		canCreate = roomsAvailable(),
	})
end

-- ── create ───────────────────────────────────────────────────────────────────

-- Claims a code atomically. UpdateAsync is the only way two servers racing for
-- the same five characters cannot both win.
local function claimCode(accessCode, hostUserId, packs)
	local ds = dataStore()
	if not ds then
		return nil, "Las salas necesitan DataStores habilitados."
	end

	for attempt = 1, R.MAX_CREATE_ATTEMPTS do
		local code = Rooms.generate()
		local claimed = false

		local ok, err = pcall(function()
			ds:UpdateAsync(Rooms.key(code), function(existing)
				if existing and type(existing) == "table" then
					-- Taken, unless it has aged out.
					if (os.time() - (existing.createdAt or 0)) < Rooms.TTL then
						return nil   -- abort this write, try another code
					end
				end
				claimed = true
				return {
					accessCode = accessCode,
					hostUserId = hostUserId,
					packs = packs,
					createdAt = os.time(),
					placeId = game.PlaceId,
				}
			end)
		end)

		if not ok then
			return nil, "No se pudo reservar el código: " .. tostring(err)
		end
		if claimed then
			return code
		end
	end

	return nil, "No se pudo encontrar un código libre. Probá de nuevo."
end

function RoomService.createRoom(player)
	local now = os.clock()
	if lastCreate[player.UserId] and now - lastCreate[player.UserId] < R.CREATE_COOLDOWN then
		return false, ("Esperá %d segundos."):format(
			math.ceil(R.CREATE_COOLDOWN - (now - lastCreate[player.UserId])))
	end
	lastCreate[player.UserId] = now

	if game.PlaceId == 0 then
		return false, "Publicá el juego una vez: un lugar sin publicar no puede reservar servidores."
	end

	local ok, accessCode = pcall(function()
		return TeleportService:ReserveServerAsync(game.PlaceId)
	end)
	if not ok or type(accessCode) ~= "string" then
		return false, "Roblox no entregó un servidor reservado. Probá de nuevo."
	end

	-- The room inherits the pack selection the creator is looking at.
	local packs = {}
	for id, on in pairs(state.packs) do
		packs[id] = on
	end

	local code, reason = claimCode(accessCode, player.UserId, packs)
	if not code then
		return false, reason
	end

	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCode
	options:SetTeleportData({
		roomCode = code,
		hostUserId = player.UserId,
		packs = packs,
	})

	local sent = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not sent then
		return false, "No se pudo mandarte a la sala."
	end

	return true, code
end

-- ── join ─────────────────────────────────────────────────────────────────────

function RoomService.joinRoom(player, rawCode)
	local now = os.clock()
	if lastJoin[player.UserId] and now - lastJoin[player.UserId] < R.JOIN_COOLDOWN then
		return false, "Esperá un segundo."
	end
	lastJoin[player.UserId] = now

	local code, reason = Rooms.normalise(rawCode)
	if not code then
		return false, reason
	end

	local ds = dataStore()
	if not ds then
		return false, "Las salas necesitan DataStores habilitados."
	end

	local ok, record = pcall(function()
		return ds:GetAsync(Rooms.key(code))
	end)
	if not ok then
		return false, "No se pudo leer el código."
	end
	if type(record) ~= "table" or type(record.accessCode) ~= "string" then
		return false, ("No existe la sala %s."):format(Rooms.display(code))
	end
	if (os.time() - (record.createdAt or 0)) >= Rooms.TTL then
		return false, ("La sala %s expiró."):format(Rooms.display(code))
	end

	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = record.accessCode
	options:SetTeleportData({
		roomCode = code,
		hostUserId = record.hostUserId,
		packs = record.packs,
	})

	local sent = pcall(function()
		TeleportService:TeleportAsync(record.placeId or game.PlaceId, { player }, options)
	end)
	if not sent then
		return false, "No se pudo mandarte a la sala."
	end

	return true, code
end

-- ── host controls ────────────────────────────────────────────────────────────

local function isHost(player)
	return state.isRoom and state.hostUserId ~= nil and player.UserId == state.hostUserId
end

RoomService.isHost = isHost

function RoomService.setPackEnabled(player, packId, enabled)
	if not isHost(player) then
		return false, "Solo el anfitrión cambia los paquetes."
	end
	local found = false
	for _, pack in ipairs(SoundLibrary.packs()) do
		if pack.id == packId then
			found = true
		end
	end
	if not found then
		return false, "Ese paquete no existe."
	end

	-- Refuse to turn off the last one: an empty library is not a valid room.
	if not enabled then
		local remaining = 0
		for _, pack in ipairs(SoundLibrary.packs()) do
			if pack.id ~= packId and state.packs[pack.id] then
				remaining += 1
			end
		end
		if remaining == 0 then
			return false, "Tiene que quedar al menos un paquete activo."
		end
	end

	state.packs[packId] = enabled and true or nil
	RoomService.broadcast()
	return true
end

function RoomService.kick(player, targetUserId)
	if not isHost(player) then
		return false, "Solo el anfitrión saca jugadores."
	end
	if targetUserId == player.UserId then
		return false, "No podés sacarte a vos mismo."
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target then
		return false, "Ese jugador ya no está."
	end
	target:Kick(("El anfitrión te sacó de la sala %s."):format(Rooms.display(state.code or "")))
	return true, target.DisplayName
end

-- The packs a match should draw from, in the shape SoundLibrary.playlist wants.
function RoomService.enabledPacks()
	local any = false
	for _, on in pairs(state.packs) do
		if on then
			any = true
		end
	end
	return any and state.packs or nil
end

function RoomService.code()
	return state.code
end

function RoomService.isRoomServer()
	return state.isRoom
end

-- ── lifecycle ────────────────────────────────────────────────────────────────

-- A room learns what it is from the first arrival's teleport data. Later
-- arrivals carry the same payload, so it is read defensively and never
-- overwrites a host that is already established.
local function adoptJoinData(player)
	state._order += 1
	state.joinOrder[player.UserId] = state._order

	if not state.isRoom then
		return
	end

	local ok, data = pcall(function()
		local joinData = player:GetJoinData()
		return joinData and joinData.TeleportData
	end)
	if not ok or type(data) ~= "table" then
		return
	end

	if not state.code and type(data.roomCode) == "string" then
		local code = Rooms.normalise(data.roomCode)
		state.code = code
	end

	if not state.hostUserId and type(data.hostUserId) == "number" then
		state.hostUserId = data.hostUserId
	end

	if type(data.packs) == "table" then
		local packs = {}
		local any = false
		for _, pack in ipairs(SoundLibrary.packs()) do
			if data.packs[pack.id] then
				packs[pack.id] = true
				any = true
			end
		end
		if any then
			state.packs = packs
		end
	end
end

function RoomService.onPlayerAdded(player)
	adoptJoinData(player)
	RoomService.broadcast()
	task.delay(1, function()
		if player.Parent then
			broadcastTo(player)
		end
	end)
end

function RoomService.onPlayerRemoving(player)
	state.joinOrder[player.UserId] = nil
	lastCreate[player.UserId] = nil
	lastJoin[player.UserId] = nil

	-- The host left. Hand the room to whoever has been here longest, so a dead
	-- connection does not leave the room unmanageable.
	if R.INHERIT_HOST and state.isRoom and player.UserId == state.hostUserId then
		local heir, heirOrder = nil, math.huge
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player then
				local order = state.joinOrder[other.UserId] or math.huge
				if order < heirOrder then
					heir, heirOrder = other, order
				end
			end
		end
		if heir then
			state.hostUserId = heir.UserId
			Net.fireAll(Net.Toast, {
				text = ("%s es el nuevo anfitrión."):format(heir.DisplayName),
				tone = "warn",
			})
		else
			state.hostUserId = nil
		end
	end

	RoomService.broadcast()
end

function RoomService.bindRemotes()
	Net.onServer(Net.CreateRoom, function(player)
		local ok, result = RoomService.createRoom(player)
		if not ok then
			Net.fireClient(Net.Toast, player, { text = result, tone = "bad" })
		end
	end)

	Net.onServer(Net.JoinRoom, function(player, payload)
		local code = type(payload) == "table" and payload.code or nil
		local ok, result = RoomService.joinRoom(player, code)
		if not ok then
			Net.fireClient(Net.Toast, player, { text = result, tone = "bad" })
		end
	end)

	Net.onServer(Net.SetPackEnabled, function(player, payload)
		if type(payload) ~= "table" then
			return
		end
		local ok, reason = RoomService.setPackEnabled(player, payload.packId, payload.enabled == true)
		if not ok then
			Net.fireClient(Net.Toast, player, { text = reason, tone = "warn" })
		end
	end)

	Net.onServer(Net.KickPlayer, function(player, payload)
		if type(payload) ~= "table" or type(payload.userId) ~= "number" then
			return
		end
		local ok, result = RoomService.kick(player, payload.userId)
		if ok then
			Net.fireAll(Net.Toast, { text = ("%s salió de la sala."):format(result), tone = "warn" })
		else
			Net.fireClient(Net.Toast, player, { text = result, tone = "warn" })
		end
	end)
end

function RoomService.start()
	-- Off the boot thread: GetAsync can take seconds, and everything after
	-- this call (the voice graph, the match loop) would wait behind it.
	task.spawn(function()
		probeDataStore()
		RoomService.broadcast()
	end)

	state.isRoom = detectRoom()
	if state.isRoom then
		print("[RoomService] servidor reservado: esta es una sala privada")
	else
		print("[RoomService] servidor público")
	end

	-- Nudge a host whose room nobody joined, once.
	if state.isRoom then
		task.delay(R.LONELY_AFTER, function()
			if #Players:GetPlayers() <= 1 and state.code then
				Net.fireAll(Net.Toast, {
					text = ("Nadie entró todavía. El código es %s."):format(Rooms.display(state.code)),
					tone = "neutral",
				})
			end
		end)
	end
end

return RoomService

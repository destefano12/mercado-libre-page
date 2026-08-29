--!strict
--[[
	Net
	------------------------------------------------------------------
	Creacion / acceso tipado a los remotes de Finals Week. El servidor llama Net.build()
	una sola vez; el cliente usa Net.event() / Net.func() y espera solo.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local FOLDER_NAME = "Net"

local EVENTS: { [string]: string } = {
	RoundUpdate = "RoundUpdate",     -- S->C  fase, dia, reloj, nota del trimestre
	ExamUpdate = "ExamUpdate",       -- S->C  estado completo del examen del alumno
	SuspicionUpdate = "SuspicionUpdate", -- S->C  barra de sospecha + cercania del profe
	Notify = "Notify",               -- S->C  aviso corto en pantalla
	TeacherSay = "TeacherSay",       -- S->C  el profe dice algo (burbuja 3D)
	Punish = "Punish",               -- S->C  arranca un castigo (cono, expulsion)
	Wallet = "Wallet",               -- S->C  creditos + objetos desbloqueados
	Report = "Report",               -- S->C  boletin del dia / de la semana
	Cheat = "Cheat",                 -- C->S  espiar, soplar, usar chuleta
	Throw = "Throw",                 -- C->S  lanzar un objeto (origen + direccion)
	NoteText = "NoteText",           -- C->S  escribir la nota que llevas en la mano
	NoteReceived = "NoteReceived",   -- S->C  te llego una nota de un companero
	Locker = "Locker",               -- C->S  abrir un casillero
	Music = "Music",                 -- S->C  cambio de clima musical
}

local FUNCTIONS: { [string]: string } = {
	GetState = "GetState",           -- C->S  estado inicial al entrar
	SubmitAnswer = "SubmitAnswer",   -- C->S  responder una pregunta
	SubmitSequence = "SubmitSequence", -- C->S  minijuego de escritura rapida
	Buy = "Buy",                     -- C->S  comprar en la tienda
	Equip = "Equip",                 -- C->S  equipar objeto / estetica
	ChooseMode = "ChooseMode",       -- C->S  solo / amigos / publico
	ListRooms = "ListRooms",         -- C->S  salas abiertas
	CreateRoom = "CreateRoom",       -- C->S  abrir una sala
	JoinRoom = "JoinRoom",           -- C->S  entrar a una sala
}

-- Se exponen como campos del modulo, pero se declaran como locales
-- tipados para poder recorrerlos con `for _, name in ...`.
Net.Events = EVENTS
Net.Functions = FUNCTIONS

local function getFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		return existing :: Folder
	end
	if RunService:IsServer() then
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME, 30) :: Folder
end

-- Solo servidor: crea todos los remotes declarados arriba.
function Net.build()
	assert(RunService:IsServer(), "Net.build() es solo del servidor")
	local folder = getFolder()

	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end

	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

-- Cache: RiskUpdate se dispara ~10 veces por segundo por jugador,
-- no tiene sentido buscar el remote en el arbol cada vez.
local cache: { [string]: Instance } = {}

local function lookup(name: string, className: string): Instance
	local cached = cache[name]
	if cached and cached.Parent then
		return cached
	end
	local folder = getFolder()
	local remote = folder:WaitForChild(name, 30)
	assert(remote and remote:IsA(className), ("%s %q no existe"):format(className, name))
	cache[name] = remote
	return remote
end

function Net.event(name: string): RemoteEvent
	return lookup(name, "RemoteEvent") :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	return lookup(name, "RemoteFunction") :: RemoteFunction
end

return Net

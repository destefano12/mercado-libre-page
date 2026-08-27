--!strict
--[[
	Net
	------------------------------------------------------------------
	Creacion / acceso tipado a los remotes. El servidor llama Net.build()
	una sola vez; el cliente usa Net.event() / Net.func() y espera solo.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local FOLDER_NAME = "Net"

Net.Events = {
	RiskUpdate = "RiskUpdate",       -- S->C  estado de riesgo del jugador
	ExamUpdate = "ExamUpdate",       -- S->C  estado completo de la prueba
	RoundUpdate = "RoundUpdate",     -- S->C  fase / tiempo / nota
	PhoneState = "PhoneState",       -- C->S  el jugador saco o guardo el celu
	Notify = "Notify",               -- S->C  toast 3D ("te pillo", "aprobaste", ...)
	Caught = "Caught",               -- S->C  el profe te agarro
	TeacherSay = "TeacherSay",       -- S->C  dialogo del profe (burbuja 3D)
}

Net.Functions = {
	SubmitAnswer = "SubmitAnswer",   -- C->S  responder una pregunta
	TakePhoto = "TakePhoto",         -- C->S  sacar foto a la prueba
	AskRoGPT = "AskRoGPT",           -- C->S  mandar la foto al chat
	GetExam = "GetExam",             -- C->S  pedir el estado inicial
}

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

	for _, name in Net.Events do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end

	for _, name in Net.Functions do
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

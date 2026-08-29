--!strict
--[[
	Instalador
	------------------------------------------------------------------
	Esto es lo unico que tenes que insertar en tu lugar. Adentro viene
	Finals Week entero, y al arrancar se acomoda solo:

		Shared -> ReplicatedStorage
		Client -> StarterPlayer/StarterPlayerScripts
		Server -> ServerScriptService

	Roblox obliga a que el codigo del servidor y el del cliente vivan
	en servicios distintos (si no, cualquiera podria leer las
	respuestas del examen), pero eso no es problema tuyo: lo hace este
	script.

	El "Server" viene apagado a proposito y se prende recien cuando
	"Shared" ya esta en su lugar, porque lo primero que hace es
	buscarlo.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local container = script.Parent
if not container then
	return
end

local function install(name: string, destination: Instance): Instance?
	local item = container:FindFirstChild(name)
	if not item then
		warn(string.format("[Instalador] Falta %q adentro del paquete.", name))
		return nil
	end

	-- Si ya habia una version vieja instalada, se reemplaza.
	local previous = destination:FindFirstChild(name)
	if previous and previous ~= item then
		previous:Destroy()
	end

	item.Parent = destination
	return item
end

install("Shared", ReplicatedStorage)
install("Client", StarterPlayer:WaitForChild("StarterPlayerScripts"))

local server = install("Server", ServerScriptService)
if server and server:IsA("Script") then
	server.Disabled = false
	print("[Instalador] Listo: Finals Week quedo instalado en este lugar.")
else
	warn("[Instalador] No se pudo instalar el servidor.")
end

-- El paquete vacio ya no hace falta.
task.defer(function()
	if container and container.Parent then
		container:Destroy()
	end
end)

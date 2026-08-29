--!strict
--[[
	DataService
	------------------------------------------------------------------
	Guardado persistente con DataStoreService: creditos, objetos
	comprados, esteticas equipadas y el historial de semanas.

	Reglas que sigue este modulo:
	  * en Studio sin API habilitada, DataStore tira error: se juega
	    igual con un perfil en memoria y se avisa una sola vez;
	  * nunca se pisa un perfil que no se pudo leer (si la lectura
	    falla, ese jugador no guarda en esa sesion);
	  * se guarda al salir, cada Config.Economia.GuardadoAutomatico
	    segundos, y en BindToClose antes de que cierre el servidor.
--]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local DataService = {}

export type Profile = {
	creditos: number,
	comprados: { [string]: boolean },
	objeto: string,              -- el objeto equipado para la proxima ronda
	estetica: { [string]: boolean },
	semanas: number,
	mejorPromedio: number,
	guardable: boolean,          -- false si la lectura fallo: no se pisa
}

local store: DataStore? = nil
local profiles: { [Player]: Profile } = {}
local warned = false

local function defaults(): Profile
	return {
		creditos = 60,
		comprados = { nota = true, bolita = true },
		objeto = "nota",
		estetica = {},
		semanas = 0,
		mejorPromedio = 0,
		guardable = true,
	}
end

--- Mezcla lo leido con los valores por defecto: si manana agregamos un
--- campo nuevo, los perfiles viejos no se rompen.
local function merge(raw: any): Profile
	local profile = defaults()
	if type(raw) ~= "table" then
		return profile
	end
	if type(raw.creditos) == "number" then
		profile.creditos = math.max(0, math.floor(raw.creditos))
	end
	if type(raw.comprados) == "table" then
		for id, owned in raw.comprados do
			if type(id) == "string" and owned == true then
				profile.comprados[id] = true
			end
		end
	end
	if type(raw.objeto) == "string" then
		profile.objeto = raw.objeto
	end
	if type(raw.estetica) == "table" then
		for id, on in raw.estetica do
			if type(id) == "string" and on == true then
				profile.estetica[id] = true
			end
		end
	end
	if type(raw.semanas) == "number" then
		profile.semanas = math.floor(raw.semanas)
	end
	if type(raw.mejorPromedio) == "number" then
		profile.mejorPromedio = math.floor(raw.mejorPromedio)
	end
	return profile
end

local function key(player: Player): string
	return "u_" .. player.UserId
end

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Economia.ClaveDataStore)
	end)
	if ok then
		store = result
		return store
	end
	return nil
end

--- Reintenta hasta 3 veces: DataStore falla por throttling, no por error real.
local function retry<T>(fn: () -> T): (boolean, T?)
	for attempt = 1, 3 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		if attempt == 3 then
			if not warned then
				warned = true
				warn("[Datos] DataStore no disponible (en Studio hay que habilitar "
					.. "el acceso a la API). Se juega con progreso en memoria.")
			end
		else
			task.wait(attempt * 1.5)
		end
	end
	return false, nil
end

function DataService.load(player: Player): Profile
	local existing = profiles[player]
	if existing then
		return existing
	end

	local profile = defaults()
	local dataStore = getStore()
	if dataStore and not RunService:IsStudio() then
		local ok, raw = retry(function()
			return dataStore:GetAsync(key(player))
		end)
		if ok then
			profile = merge(raw)
		else
			profile.guardable = false
		end
	end

	profiles[player] = profile
	return profile
end

function DataService.get(player: Player): Profile?
	return profiles[player]
end

function DataService.save(player: Player)
	local profile = profiles[player]
	if not profile or not profile.guardable then
		return
	end
	local dataStore = getStore()
	if not dataStore or RunService:IsStudio() then
		return
	end
	retry(function()
		dataStore:SetAsync(key(player), {
			creditos = profile.creditos,
			comprados = profile.comprados,
			objeto = profile.objeto,
			estetica = profile.estetica,
			semanas = profile.semanas,
			mejorPromedio = profile.mejorPromedio,
		})
		return true
	end)
end

function DataService.release(player: Player)
	DataService.save(player)
	profiles[player] = nil
end

--- Suma creditos y avisa al cliente. Devuelve el total nuevo.
function DataService.addCredits(player: Player, amount: number): number
	local profile = profiles[player]
	if not profile then
		return 0
	end
	profile.creditos = math.max(0, profile.creditos + amount)
	DataService.push(player)
	return profile.creditos
end

--- Manda al cliente la billetera entera (creditos + inventario).
function DataService.push(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	Net.event(Net.Events.Wallet):FireClient(player, {
		creditos = profile.creditos,
		comprados = profile.comprados,
		objeto = profile.objeto,
		estetica = profile.estetica,
		semanas = profile.semanas,
		mejorPromedio = profile.mejorPromedio,
	})
end

function DataService.start()
	Players.PlayerRemoving:Connect(function(player)
		DataService.release(player)
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Economia.GuardadoAutomatico)
			for player in profiles do
				if player.Parent then
					DataService.save(player)
				end
			end
		end
	end)

	game:BindToClose(function()
		for player in profiles do
			DataService.save(player)
		end
		if not RunService:IsStudio() then
			task.wait(2)
		end
	end)
end

return DataService

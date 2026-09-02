--!strict
--[[
	ShopService
	------------------------------------------------------------------
	La economia: creditos ganados por rendimiento, compras en el
	kiosco del pasillo y esteticas equipadas.

	Todo se valida en el servidor. El cliente no manda precios ni
	saldos: manda "quiero comprar X" y el servidor decide.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local ItemService = require(script.Parent:WaitForChild("ItemService"))
local CharacterService = require(script.Parent:WaitForChild("CharacterService"))

local ShopService = {}

local openDuringPhase = "recreo"
local currentPhase = "espera"

local function entryOf(id: string): any
	for _, entry in Config.Economia.Tienda do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

--[[
	Las categorias exclusivas del carnet: `pelo`, `gorro`, `anteojos`.

	Sin esto un jugador podia tener los seis peinados puestos a la vez —
	`equip` solo alternaba una bandera por id y nadie miraba el resto —,
	y el resultado era una bola de pelo con seis siluetas encimadas. Lo
	decide el servidor y no el carnet: el cliente puede mandar dos
	`Equip` seguidos.
--]]
local function exclusiveCategory(id: string): string?
	local entry = entryOf(id)
	if not entry or not entry.categoria then
		return nil
	end
	for _, tab in Config.Carnet.Pestanas do
		if tab.categoria == entry.categoria and tab.exclusiva then
			return tab.categoria
		end
	end
	return nil
end

function ShopService.setPhase(phase: string)
	currentPhase = phase
end

function ShopService.isOpen(): boolean
	return currentPhase == openDuringPhase or currentPhase == "espera" or currentPhase == "boletin"
end

--[[
	Devuelve el aviso de por que un articulo esta bloqueado, o `nil` si
	esta disponible.

	Vive aca y no en el cliente porque es el servidor quien decide; la
	tienda dibuja el candado con los mismos numeros, pero solo para que
	el jugador se entere antes de hacer clic.
--]]
function ShopService.missingRequirement(profile: any, entry: any): any
	local needs = entry.requiere
	if not needs then
		return nil
	end
	if needs.semanas and (profile.semanas or 0) < needs.semanas then
		return { key = "shop.need_weeks", args = { n = needs.semanas } }
	end
	if needs.promedio and (profile.mejorPromedio or 0) < needs.promedio then
		return { key = "shop.need_grade", args = { n = needs.promedio } }
	end
	return nil
end

--- Compra: descuenta creditos y marca el objeto como propio.
function ShopService.buy(player: Player, id: any): any
	if type(id) ~= "string" then
		return { ok = false, reason = { key = "error.generic" } }
	end
	local entry = entryOf(id)
	if not entry then
		return { ok = false, reason = { key = "error.generic" } }
	end
	if not ShopService.isOpen() then
		return { ok = false, reason = { key = "shop.closed" } }
	end

	local profile = DataService.get(player)
	if not profile then
		return { ok = false, reason = { key = "error.generic" } }
	end

	-- Las esteticas se compran una vez; los objetos se pueden recomprar.
	if entry.tipo == "estetica" and profile.comprados[id] then
		return { ok = false, reason = { key = "shop.owned" } }
	end

	--[[
		La estetica no se compra sola: hay que habersela ganado. En el
		juego real la ropa se desbloquea aprobando, no pagando, y esto es
		lo que traduce esa idea — los creditos siguen haciendo falta,
		pero primero hay que cumplir el requisito.

		`semanas` son semanas finales sobrevividas y `promedio` es el
		mejor promedio que sacaste alguna vez; las dos ya viven en el
		perfil desde siempre.
	--]]
	local needed = ShopService.missingRequirement(profile, entry)
	if needed then
		return { ok = false, reason = needed }
	end

	if profile.creditos < entry.precio then
		return { ok = false, reason = { key = "shop.cannot" } }
	end

	profile.creditos -= entry.precio
	profile.comprados[id] = true

	if entry.tipo == "objeto" then
		profile.objeto = id
		-- Si estamos en el recreo, te lo llevas puesto ya mismo.
		if currentPhase == "recreo" then
			ItemService.give(player, id)
		end
	end

	DataService.push(player)
	return { ok = true, reason = { key = "shop.bought", args = { item = "@item." .. id } } }
end

--- Equipar: objetos (uno) o esteticas (varias, se alternan).
function ShopService.equip(player: Player, id: any): any
	if type(id) ~= "string" then
		return { ok = false, reason = { key = "error.generic" } }
	end
	local entry = entryOf(id)
	local profile = DataService.get(player)
	if not entry or not profile then
		return { ok = false, reason = { key = "error.generic" } }
	end
	if not profile.comprados[id] then
		return { ok = false, reason = { key = "shop.cannot" } }
	end

	if entry.tipo == "objeto" then
		profile.objeto = id
	else
		local turningOn = not profile.estetica[id]
		profile.estetica[id] = turningOn or nil

		if turningOn then
			local category = exclusiveCategory(id)
			if category then
				for _, other in Config.Economia.Tienda do
					if other.id ~= id and other.categoria == category then
						profile.estetica[other.id] = nil
					end
				end
			end
		end

		local character = player.Character
		if character then
			-- Repintar en caliente: se ve el cambio sin reaparecer.
			CharacterService.dressStudent(player, character, profile.estetica)
		end
	end

	DataService.push(player)
	return { ok = true, reason = { key = "shop.equipped" } }
end

--- Le da a cada uno el objeto que tiene equipado. Se llama al empezar
--- el recreo: es el "kit" con el que arrancas el dia.
function ShopService.grantLoadout(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local id = profile.objeto
	if id and profile.comprados[id] then
		ItemService.give(player, id)
	else
		ItemService.give(player, "nota")
	end
end

--- Premios al terminar el dia.
function ShopService.reward(player: Player, correct: number, passed: boolean, punishments: number): number
	local total = correct * Config.Economia.CreditosPorAcierto
	if passed then
		total += Config.Economia.CreditosPorAprobar
	end
	if punishments == 0 then
		total += Config.Economia.CreditosSinCastigos
	end
	if total > 0 then
		DataService.addCredits(player, total)
		Net.event(Net.Events.Notify):FireClient(player, {
			key = "notify.credits",
			args = { n = total },
		})
	end
	return total
end

function ShopService.bindKiosk(part: BasePart?)
	if not part then
		return
	end
	local prompt = part:FindFirstChild("Tienda")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function(player)
			-- La billetera lleva `abrir` para que el cliente sepa que
			-- tiene que mostrar la tienda: asi no hace falta un remote
			-- extra solo para eso.
			local profile = DataService.get(player)
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
				abrir = true,
				puedeComprar = ShopService.isOpen(),
			})
		end)
	end
end

function ShopService.start()
	Net.func(Net.Functions.Buy).OnServerInvoke = function(player, id)
		return ShopService.buy(player, id)
	end
	Net.func(Net.Functions.Equip).OnServerInvoke = function(player, id)
		return ShopService.equip(player, id)
	end

	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			DataService.load(player)
			DataService.push(player)
		end)
	end)
end

return ShopService

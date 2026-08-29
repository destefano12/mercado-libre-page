--!strict
--[[
	RadioService
	------------------------------------------------------------------
	Las dos herramientas de comunicacion a distancia:

	  walkie   transmite a TODOS los que tengan un walkie en la mano,
	           en cualquier punto del colegio. Es la herramienta de
	           equipo: el que ya termino le dicta al resto.
	  celular  le manda el mensaje a UN companero cercano. Menos
	           alcance, pero mucho mas discreto... salvo que el
	           profesor te vea con el telefono en la mano.

	Las dos suben la sospecha al usarlas dentro del examen, y el
	celular mucho mas que el walkie: sacar el telefono en un examen es
	lo mas descarado que podes hacer.

	Todo el texto pasa por TextFilter antes de salir. Si el filtro
	falla, el mensaje no se manda.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local TextFilter = require(script.Parent:WaitForChild("TextFilter"))
local ExamService = require(script.Parent:WaitForChild("ExamService"))
local SuspicionService = require(script.Parent:WaitForChild("SuspicionService"))

local H = Config.Herramientas

local RadioService = {}

local lastUse: { [Player]: number } = {}

--- La herramienta que tiene en la mano, si es una radio de las nuestras.
local function radioInHand(player: Player, kind: string): Tool?
	local character = player.Character
	if not character then
		return nil
	end
	local tool = character:FindFirstChildOfClass("Tool")
	if tool and tool:GetAttribute("Radio") == kind then
		return tool
	end
	return nil
end

local function holdersOf(kind: string): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if radioInHand(player, kind) then
			table.insert(list, player)
		end
	end
	return list
end

local function nearestListener(player: Player, range: number): Player?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local best: Player? = nil
	local bestDistance = range
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local otherCharacter = other.Character
			local otherRoot = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart")
			if otherRoot and otherRoot:IsA("BasePart") then
				local distance = (otherRoot.Position - root.Position).Magnitude
				if distance < bestDistance then
					bestDistance = distance
					best = other
				end
			end
		end
	end
	return best
end

--- Manda un mensaje. `kind` es "walkie" o "celular".
function RadioService.send(player: Player, kind: any, text: any): any
	if kind ~= "walkie" and kind ~= "celular" then
		return { ok = false, reason = { key = "error.generic" } }
	end
	if not radioInHand(player, kind) then
		return { ok = false, reason = { key = "radio.need_tool" } }
	end

	local cooldown = kind == "walkie" and H.RadioEnfriamiento or H.CelularEnfriamiento
	local now = os.clock()
	if now - (lastUse[player] or -math.huge) < cooldown then
		return { ok = false, reason = { key = "cheat.cooldown" } }
	end

	local raw = TextFilter.trim(text, H.RadioCaracteres)
	if raw == "" then
		return { ok = false, reason = { key = "note.empty" } }
	end
	local safe = TextFilter.forBroadcast(raw, player.UserId)
	if not safe then
		return { ok = false, reason = { key = "error.generic" } }
	end

	lastUse[player] = now

	-- Usar la radio en pleno examen se paga, y el celular mucho mas.
	if ExamService.isRunning() then
		SuspicionService.infraction(player,
			kind == "walkie" and H.RadioSospecha or H.CelularSospecha, kind)
	end

	if kind == "walkie" then
		local listeners = holdersOf("walkie")
		local reached = 0
		for _, other in listeners do
			if other ~= player then
				reached += 1
				Net.event(Net.Events.Radio):FireClient(other, {
					tipo = "walkie",
					de = player.DisplayName,
					texto = safe,
				})
			end
		end
		if reached == 0 then
			return { ok = true, reason = { key = "radio.nobody" } }
		end
		return { ok = true, reason = { key = "radio.sent", args = { n = reached } } }
	end

	local target = nearestListener(player, H.CelularAlcance)
	if not target then
		return { ok = false, reason = { key = "radio.nobody" } }
	end
	Net.event(Net.Events.Radio):FireClient(target, {
		tipo = "celular",
		de = player.DisplayName,
		texto = safe,
	})
	return { ok = true, reason = { key = "radio.sent", args = { n = 1 } } }
end

function RadioService.start()
	Net.event(Net.Events.Radio).OnServerEvent:Connect(function(player, kind, text)
		local result = RadioService.send(player, kind, text)
		if result.reason then
			Net.event(Net.Events.Notify):FireClient(player, result.reason)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
	end)
end

return RadioService

--!strict
--[[
	PunishService
	------------------------------------------------------------------
	Que pasa cuando el profesor te pilla. Escala: la primera vez te
	pone el cono de la verguenza y te descuenta nota; a la segunda te
	manda a la sala de castigo y te perdes lo que queda del examen.

	Despues de cada sancion hay unos segundos de inmunidad: sin eso el
	profesor te castigaria tres veces seguidas en el mismo lugar y el
	juego se volveria injusto.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local CharacterService = require(script.Parent:WaitForChild("CharacterService"))
local SuspicionService = require(script.Parent:WaitForChild("SuspicionService"))
local ExamService = require(script.Parent:WaitForChild("ExamService"))

local C = Config.Castigo

local PunishService = {}

type Record = {
	count: number,
	penalty: number,
	immuneUntil: number,
	detained: boolean,
}

local records: { [Player]: Record } = {}
local detentionPoint = Config.Escuela.SalaDeCastigo

local function record(player: Player): Record
	local existing = records[player]
	if existing then
		return existing
	end
	local created: Record = { count = 0, penalty = 0, immuneUntil = 0, detained = false }
	records[player] = created
	return created
end

function PunishService.setDetention(part: BasePart?)
	if part then
		detentionPoint = part.Position + Vector3.new(0, 4, 0)
	end
end

function PunishService.count(player: Player): number
	return record(player).count
end

function PunishService.penalty(player: Player): number
	return record(player).penalty
end

function PunishService.isDetained(player: Player): boolean
	return record(player).detained
end

function PunishService.resetAll()
	for player in records do
		records[player] = { count = 0, penalty = 0, immuneUntil = 0, detained = false }
	end
end

local function slowDown(player: Player, seconds: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local original = humanoid.WalkSpeed
	humanoid.WalkSpeed = C.VelocidadReducida
	task.delay(seconds, function()
		if humanoid.Parent then
			humanoid.WalkSpeed = original
		end
	end)
end

--- El cono: tapa parte de la pantalla y te frena. Es vergonzoso y
--- molesto a proposito, pero no te saca del examen.
local function coneOfShame(player: Player)
	local character = player.Character
	if not character then
		return
	end
	CharacterService.attachCone(character)
	slowDown(player, C.SegundosCono)

	Net.event(Net.Events.Punish):FireClient(player, {
		tipo = "cono",
		segundos = C.SegundosCono,
	})

	task.delay(C.SegundosCono, function()
		local current = player.Character
		if current then
			CharacterService.removeCone(current)
		end
		Net.event(Net.Events.Punish):FireClient(player, { tipo = "fin" })
	end)
end

--- Expulsion: a la sala de castigo, y de vuelta al pupitre al volver.
local function detention(player: Player)
	local data = record(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	data.detained = true
	CharacterService.removeCone(character :: Model)
	SuspicionService.setFrozen(player, true)

	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.SeatPart then
		humanoid.Sit = false
		task.wait(0.1)
	end
	root.CFrame = CFrame.new(detentionPoint)

	Net.event(Net.Events.Punish):FireClient(player, {
		tipo = "expulsion",
		segundos = C.SegundosExpulsion,
	})

	task.delay(C.SegundosExpulsion, function()
		data.detained = false
		local sitting = ExamService.sitting(player)
		local current = player.Character
		local currentRoot = current and current:FindFirstChild("HumanoidRootPart")
		if sitting and currentRoot and currentRoot:IsA("BasePart") then
			currentRoot.CFrame = sitting.desk.seat.CFrame * CFrame.new(0, 3, 0)
			local currentHumanoid = current and current:FindFirstChildOfClass("Humanoid")
			if currentHumanoid then
				pcall(function()
					sitting.desk.seat:Sit(currentHumanoid)
				end)
			end
		end
		SuspicionService.setFrozen(player, false)
		SuspicionService.reset(player)
		Net.event(Net.Events.Punish):FireClient(player, { tipo = "fin" })
		Net.event(Net.Events.Notify):FireClient(player, { key = "punish.back" })
	end)
end

--- La sancion completa. La llama TeacherAI cuando te alcanza.
function PunishService.apply(player: Player, teacher: any)
	local data = record(player)
	local now = os.clock()
	if now < data.immuneUntil or data.detained then
		return
	end
	data.immuneUntil = now + C.SegundosExpulsion + C.SegundosInmunidad
	data.count += 1
	data.penalty += C.PenalizacionNota

	SuspicionService.reset(player)

	local teacherRoot = teacher and teacher.root
	if teacherRoot then
		Util.playSound(Config.Sonidos.Silbato, teacherRoot, 0.5, 0.8)
	end

	if data.count >= C.InfraccionesParaExpulsion then
		detention(player)
		Net.event(Net.Events.Notify):FireAllClients({
			key = "punish.detention",
			args = { name = player.DisplayName },
		})
	else
		data.immuneUntil = now + C.SegundosCono * 0.5 + C.SegundosInmunidad
		coneOfShame(player)
		Net.event(Net.Events.Notify):FireAllClients({
			key = "punish.cone",
			args = { name = player.DisplayName },
		})
		Net.event(Net.Events.Notify):FireClient(player, {
			key = "punish.grade",
			args = { n = C.PenalizacionNota },
		})
	end
end

--- Limpia todo lo que quedo puesto al terminar un examen.
function PunishService.clearVisuals()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			CharacterService.removeCone(character)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.WalkSpeed < 16 then
				humanoid.WalkSpeed = 16
			end
		end
		Net.event(Net.Events.Punish):FireClient(player, { tipo = "fin" })
	end
end

function PunishService.start()
	Players.PlayerRemoving:Connect(function(player)
		records[player] = nil
	end)
end

return PunishService

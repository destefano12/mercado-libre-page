--!strict
--[[
	PhoneService
	------------------------------------------------------------------
	El celular es autoritativo del lado del servidor: bateria, cooldown
	de la camara, confiscacion y el contenido de la foto.

	Flujo:
		1. El cliente pide TakePhoto(questionId)  -> el server valida que
		   ese ejercicio sea el que el jugador tiene delante y devuelve un
		   "photoId" (un ticket de un solo uso) con el texto fotografiado.
		2. El cliente pide AskRoGPT(photoId)      -> el server consume el
		   ticket, marca el ejercicio como "resuelto con ayuda" y devuelve
		   la resolucion paso a paso.

	Asi el cliente nunca tiene las respuestas antes de tiempo: primero
	tiene que arriesgarse a sacar la foto.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local PhoneModel = require(Shared:WaitForChild("PhoneModel"))

local ExamService = require(script.Parent:WaitForChild("ExamService"))
local SuspicionService = require(script.Parent:WaitForChild("SuspicionService"))

local P = Config.Phone

local PhoneService = {}

type Photo = {
	id: string,
	questionId: number,
	takenAt: number,
	used: boolean,
}

type PhoneData = {
	battery: number,
	out: boolean,
	confiscatedUntil: number,
	nextPhotoAt: number,
	photos: { [string]: Photo },
	photoCount: number,
	dirty: boolean,
	model: Model?,
	weld: Weld?,
}

local phones: { [Player]: PhoneData } = {}

local function ensure(player: Player): PhoneData
	local data = phones[player]
	if not data then
		data = {
			battery = P.BatteryMax,
			out = false,
			confiscatedUntil = 0,
			nextPhotoAt = 0,
			photos = {},
			photoCount = 0,
			dirty = true,
			model = nil,
			weld = nil,
		}
		phones[player] = data
	end
	return data
end

local function snapshot(player: Player, data: PhoneData)
	local now = os.clock()
	return {
		battery = math.floor(data.battery + 0.5),
		batteryMax = P.BatteryMax,
		out = data.out,
		confiscated = now < data.confiscatedUntil,
		confiscatedFor = math.max(0, data.confiscatedUntil - now),
		cooldown = math.max(0, data.nextPhotoAt - now),
		photos = data.photoCount,
	}
end

local function push(player: Player)
	local data = ensure(player)
	Net.event(Net.Events.PhoneState):FireClient(player, snapshot(player, data))
	data.dirty = false
end

function PhoneService.isAvailable(player: Player): (boolean, any?)
	local data = ensure(player)
	if os.clock() < data.confiscatedUntil then
		return false, { key = "error.confiscated", args = { seconds = math.ceil(data.confiscatedUntil - os.clock()) } }
	end
	if data.battery <= 1 then
		return false, { key = "error.battery" }
	end
	return true, nil
end

--- Crea (o recrea) el celular fisico soldado al alumno. Lo llama el
--- servidor cada vez que aparece un personaje nuevo.
function PhoneService.equip(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end
	local data = ensure(player)
	if data.model and data.model.Parent == character then
		return true
	end
	local model, weld = PhoneModel.attach(character)
	data.model = model
	data.weld = weld
	data.out = false
	SuspicionService.setPhoneOut(player, false)
	push(player)
	return model ~= nil
end

local function applyPose(data: PhoneData)
	if data.weld and data.weld.Parent then
		PhoneModel.setRaised(data.weld, data.out)
	end
end

--- El cliente avisa que saco / guardo el celu. Esto es lo que mira el profe.
function PhoneService.setOut(player: Player, out: boolean): boolean
	local data = ensure(player)
	if out then
		local ok = PhoneService.isAvailable(player)
		if not ok then
			data.out = false
			applyPose(data)
			SuspicionService.setPhoneOut(player, false)
			push(player)
			return false
		end
	end
	data.out = out
	applyPose(data)
	SuspicionService.setPhoneOut(player, out)
	push(player)
	return true
end

function PhoneService.confiscate(player: Player)
	local data = ensure(player)
	data.out = false
	data.confiscatedUntil = os.clock() + P.ConfiscationTime
	data.photos = {}
	data.photoCount = 0
	if data.model then
		data.model:Destroy()
		data.model = nil
		data.weld = nil
	end
	-- Se lo devuelve cuando termina la confiscacion.
	task.delay(P.ConfiscationTime, function()
		if player.Parent and os.clock() >= data.confiscatedUntil then
			PhoneService.equip(player)
		end
	end)
	SuspicionService.setPhoneOut(player, false)
	push(player)
end

function PhoneService.reset(player: Player)
	local data = ensure(player)
	data.battery = P.BatteryMax
	if data.weld and data.weld.Parent then
		data.out = false
		applyPose(data)
	end
	data.out = false
	data.confiscatedUntil = 0
	data.nextPhotoAt = 0
	data.photos = {}
	data.photoCount = 0
	SuspicionService.setPhoneOut(player, false)
	push(player)
end

-- ─────────────────────────────────────────────────────────────
-- Sacar la foto
-- ─────────────────────────────────────────────────────────────

local function newPhotoId(player: Player, data: PhoneData): string
	data.photoCount += 1
	return string.format("IMG_%d_%03d", player.UserId % 100000, data.photoCount)
end

function PhoneService.takePhoto(player: Player, questionId: number)
	local data = ensure(player)
	local now = os.clock()

	local available, reason = PhoneService.isAvailable(player)
	if not available then
		return { ok = false, reason = reason }
	end
	if not data.out then
		return { ok = false, reason = { key = "error.phoneAway" } }
	end
	if now < data.nextPhotoAt then
		return { ok = false, reason = { key = "error.cooldown" } }
	end
	if typeof(questionId) ~= "number" or questionId % 1 ~= 0 then
		return { ok = false, reason = { key = "error.badOption" } }
	end

	local entry = ExamService.get(player)
	if not entry then
		return { ok = false, reason = { key = "error.notSitting" } }
	end
	if entry.finished then
		return { ok = false, reason = { key = "error.finished" } }
	end
	if entry.answers[questionId] then
		return { ok = false, reason = { key = "error.answered" } }
	end

	local question = ExamService.getQuestion(questionId)
	if not question then
		return { ok = false, reason = { key = "error.noQuestion" } }
	end

	data.battery = math.max(0, data.battery - P.BatteryPerPhoto)
	data.nextPhotoAt = now + P.PhotoCooldown

	-- El celu se inclina hacia la hoja mientras dispara.
	if data.weld and data.weld.Parent then
		PhoneModel.aimAtPaper(data.weld)
	end

	local photo: Photo = {
		id = newPhotoId(player, data),
		questionId = questionId,
		takenAt = now,
		used = false,
	}
	data.photos[photo.id] = photo
	push(player)

	return {
		ok = true,
		photoId = photo.id,
		questionId = questionId,
		promptKey = question.promptKey,
		promptArgs = question.promptArgs,
		topicKey = question.topicKey,
		choices = question.choices,
		uploadTime = Random.new():NextNumber(P.UploadTime.Min, P.UploadTime.Max),
	}
end

-- ─────────────────────────────────────────────────────────────
-- Mandarsela a RoGPT
-- ─────────────────────────────────────────────────────────────

function PhoneService.askRoGPT(player: Player, photoId: string)
	local data = ensure(player)

	local available, reason = PhoneService.isAvailable(player)
	if not available then
		return { ok = false, reason = reason }
	end
	if typeof(photoId) ~= "string" then
		return { ok = false, reason = { key = "error.noPhoto" } }
	end

	local photo = data.photos[photoId]
	if not photo then
		return { ok = false, reason = { key = "error.noPhoto" } }
	end
	if photo.used then
		return { ok = false, reason = { key = "error.photoUsed" } }
	end

	local question = ExamService.getQuestion(photo.questionId)
	if not question then
		return { ok = false, reason = { key = "error.blurry" } }
	end

	photo.used = true
	ExamService.markPhoneUsed(player, photo.questionId)

	local rng = Random.new()
	return {
		ok = true,
		model = P.ModelName,
		photoId = photoId,
		questionId = photo.questionId,
		topicKey = question.topicKey,
		promptKey = question.promptKey,
		promptArgs = question.promptArgs,
		steps = question.steps,
		answer = question.choices[question.answerIndex],
		thinkTime = rng:NextNumber(P.ThinkTime.Min, P.ThinkTime.Max),
	}
end

-- ─────────────────────────────────────────────────────────────
-- Bateria
-- ─────────────────────────────────────────────────────────────

function PhoneService.start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.5 then
			return
		end
		local step = accumulator
		accumulator = 0

		local now = os.clock()
		for player, data in phones do
			local before = data.battery
			if data.out then
				data.battery = math.max(0, data.battery - P.BatteryDrainPerSecond * step)
				if data.battery <= 0 then
					PhoneService.setOut(player, false)
				end
			else
				data.battery = math.min(P.BatteryMax, data.battery + P.BatteryRechargePerSecond * step)
			end
			if math.floor(before) ~= math.floor(data.battery) or (data.confiscatedUntil > 0 and now < data.confiscatedUntil + 1) then
				push(player)
			end
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	phones[player] = nil
end)

return PhoneService

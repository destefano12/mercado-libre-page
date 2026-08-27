--!strict
--[[
	ExamService
	------------------------------------------------------------------
	Dueño de la prueba: genera el examen de la ronda (el mismo para
	todos, si no copiarse no tendria gracia), reparte bancos, recibe
	respuestas, lleva el puntaje y calcula la nota final.

	Nunca manda al cliente la respuesta correcta: la hoja viaja
	"sanitizada". La unica forma de ver la resolucion es el celular.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local MathEngine = require(Shared:WaitForChild("MathEngine"))
local Net = require(Shared:WaitForChild("Net"))

local E = Config.Exam

local ExamService = {}

-- Ganchos opcionales: los usa el arranque para levantar al companero NPC
-- que estaba sentado en ese banco (y volver a sentarlo cuando se libera).
ExamService.onDeskAssigned = nil :: ((any) -> ())?
ExamService.onDeskReleased = nil :: ((any) -> ())?

export type AnswerRecord = {
	choice: number,
	correct: boolean,
	usedPhone: boolean,
	at: number,
}

export type PlayerExam = {
	player: Player,
	desk: any,
	answers: { [number]: AnswerRecord },
	answered: number,
	correct: number,
	cheated: number,
	catches: number,
	points: number,
	finished: boolean,
	phoneUsedOn: { [number]: boolean },
}

local state = {
	classroom = nil :: any,
	questions = {} :: { MathEngine.Question },
	publicQuestions = {} :: { any },
	seed = 0,
	players = {} :: { [Player]: PlayerExam },
}

-- ─────────────────────────────────────────────────────────────
-- Ronda
-- ─────────────────────────────────────────────────────────────

function ExamService.init(classroom)
	state.classroom = classroom
end

function ExamService.newRound(seed: number)
	state.seed = seed
	state.questions = MathEngine.buildExam(seed, E.QuestionCount, E.DifficultyCurve)
	state.publicQuestions = {}
	for index, question in state.questions do
		state.publicQuestions[index] = MathEngine.sanitize(question)
	end

	for player in state.players do
		ExamService.resetPlayer(player)
	end
end

function ExamService.getPublicExam()
	return state.publicQuestions
end

function ExamService.getQuestion(id: number): MathEngine.Question?
	return state.questions[id]
end

-- ─────────────────────────────────────────────────────────────
-- Jugadores
-- ─────────────────────────────────────────────────────────────

local function freeDesk(): any
	if not state.classroom then
		return nil
	end
	local taken: { [any]: boolean } = {}
	for _, entry in state.players do
		if entry.desk then
			taken[entry.desk] = true
		end
	end
	for _, desk in state.classroom.desks do
		if not taken[desk] then
			return desk
		end
	end
	return nil
end

function ExamService.addPlayer(player: Player): PlayerExam
	local desk = freeDesk()
	local entry: PlayerExam = {
		player = player,
		desk = desk,
		answers = {},
		answered = 0,
		correct = 0,
		cheated = 0,
		catches = 0,
		points = 0,
		finished = false,
		phoneUsedOn = {},
	}
	state.players[player] = entry

	if desk then
		desk.paper:SetAttribute("OwnerUserId", player.UserId)
		desk.seat:SetAttribute("OwnerUserId", player.UserId)
		if ExamService.onDeskAssigned then
			ExamService.onDeskAssigned(desk)
		end
	end

	return entry
end

function ExamService.removePlayer(player: Player)
	local entry = state.players[player]
	if entry and entry.desk then
		entry.desk.paper:SetAttribute("OwnerUserId", 0)
		entry.desk.seat:SetAttribute("OwnerUserId", 0)
		if ExamService.onDeskReleased then
			ExamService.onDeskReleased(entry.desk)
		end
	end
	state.players[player] = nil
end

function ExamService.get(player: Player): PlayerExam?
	return state.players[player]
end

function ExamService.resetPlayer(player: Player)
	local entry = state.players[player]
	if not entry then
		return
	end
	entry.answers = {}
	entry.answered = 0
	entry.correct = 0
	entry.cheated = 0
	entry.catches = 0
	entry.points = 0
	entry.finished = false
	entry.phoneUsedOn = {}
	ExamService.push(player)
end

--- Sienta al jugador en su banco y lo deja listo para rendir.
function ExamService.seatPlayer(player: Player)
	local entry = state.players[player]
	if not entry or not entry.desk then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	character:PivotTo(entry.desk.seat.CFrame * CFrame.new(0, 3, 0))
	task.wait(0.1)
	entry.desk.seat:Sit(humanoid)
end

-- ─────────────────────────────────────────────────────────────
-- Responder
-- ─────────────────────────────────────────────────────────────

local function grade(entry: PlayerExam): number
	local total = #state.questions
	if total == 0 then
		return 1
	end
	local raw = entry.correct / total
	local value = 1 + raw * (E.MaxGrade - 1)
	value -= entry.catches * Config.Penalty.GradePerCatch
	return math.clamp(math.floor(value * 10 + 0.5) / 10, 1, E.MaxGrade)
end

function ExamService.getGrade(player: Player): number
	local entry = state.players[player]
	return entry and grade(entry) or 1
end

function ExamService.markPhoneUsed(player: Player, questionId: number)
	local entry = state.players[player]
	if not entry then
		return
	end
	entry.phoneUsedOn[questionId] = true
end

function ExamService.submitAnswer(player: Player, questionId: number, choice: number)
	local entry = state.players[player]
	if not entry then
		return { ok = false, reason = "Todavia no estas rindiendo." }
	end
	if entry.finished then
		return { ok = false, reason = "Ya entregaste la prueba." }
	end
	local question = state.questions[questionId]
	if not question then
		return { ok = false, reason = "Ese ejercicio no existe." }
	end
	if entry.answers[questionId] then
		return { ok = false, reason = "Ya respondiste ese ejercicio." }
	end
	if typeof(choice) ~= "number" or choice < 1 or choice > #question.choices or choice % 1 ~= 0 then
		return { ok = false, reason = "Opcion invalida." }
	end

	local correct = choice == question.answerIndex
	local usedPhone = entry.phoneUsedOn[questionId] == true

	entry.answers[questionId] = {
		choice = choice,
		correct = correct,
		usedPhone = usedPhone,
		at = os.clock(),
	}
	entry.answered += 1
	if correct then
		entry.correct += 1
		entry.points += usedPhone and E.PointsCorrect or E.PointsCorrectSolo
	else
		entry.points += E.PointsWrong
	end
	if usedPhone then
		entry.cheated += 1
	end

	if entry.answered >= #state.questions then
		entry.finished = true
	end

	ExamService.push(player)

	return {
		ok = true,
		correct = correct,
		answerIndex = question.answerIndex,
		finished = entry.finished,
		grade = grade(entry),
	}
end

function ExamService.registerCatch(player: Player)
	local entry = state.players[player]
	if not entry then
		return
	end
	entry.catches += 1
	if entry.catches >= Config.Penalty.MaxCatches then
		entry.finished = true
	end
	ExamService.push(player)
end

-- ─────────────────────────────────────────────────────────────
-- Replicacion
-- ─────────────────────────────────────────────────────────────

function ExamService.snapshot(player: Player)
	local entry = state.players[player]
	if not entry then
		return nil
	end

	local answers: { [number]: any } = {}
	for id, record in entry.answers do
		answers[id] = { choice = record.choice, correct = record.correct, usedPhone = record.usedPhone }
	end

	return {
		questions = state.publicQuestions,
		answers = answers,
		answered = entry.answered,
		correct = entry.correct,
		cheated = entry.cheated,
		catches = entry.catches,
		points = entry.points,
		grade = grade(entry),
		finished = entry.finished,
		seatIndex = entry.desk and entry.desk.index or 0,
	}
end

function ExamService.push(player: Player)
	local snapshot = ExamService.snapshot(player)
	if snapshot then
		Net.event(Net.Events.ExamUpdate):FireClient(player, snapshot)
	end
end

function ExamService.pushAll()
	for player in state.players do
		ExamService.push(player)
	end
end

function ExamService.allPlayers(): { [Player]: PlayerExam }
	return state.players
end

Players.PlayerRemoving:Connect(function(player)
	ExamService.removePlayer(player)
end)

return ExamService

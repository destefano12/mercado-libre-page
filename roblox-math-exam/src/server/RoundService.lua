--!strict
--[[
	RoundService
	------------------------------------------------------------------
	Ciclo de la clase:

		Preparacion -> los alumnos entran, se sientan, el profe reparte
		Prueba      -> corre el reloj, se puede responder (y copiarse)
		Resultados  -> notas, ranking y quien se copio sin que lo vean

	Tambien mantiene leaderstats (Nota / Copiadas / Pillado) y es quien
	decide que pasa cuando el profe agarra a alguien con el celular.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local ExamService = require(script.Parent:WaitForChild("ExamService"))
local PhoneService = require(script.Parent:WaitForChild("PhoneService"))
local SuspicionService = require(script.Parent:WaitForChild("SuspicionService"))
local ToolService = require(script.Parent:WaitForChild("ToolService"))

local E = Config.Exam

local RoundService = {}

local state = {
	phase = "Preparacion",
	timeLeft = 0,
	roundNumber = 0,
	classroom = nil :: any,
	teacher = nil :: any,
	results = {} :: { any },
}

-- ─────────────────────────────────────────────────────────────
-- leaderstats
-- ─────────────────────────────────────────────────────────────

local function setupStats(player: Player)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		return stats
	end
	stats = Instance.new("Folder")
	stats.Name = "leaderstats"

	local grade = Instance.new("NumberValue")
	grade.Name = "Nota"
	grade.Value = 1
	grade.Parent = stats

	local cheats = Instance.new("IntValue")
	cheats.Name = "Copiadas"
	cheats.Parent = stats

	local catches = Instance.new("IntValue")
	catches.Name = "Pillado"
	catches.Parent = stats

	stats.Parent = player
	return stats
end

local function syncStats(player: Player)
	local entry = ExamService.get(player)
	local stats = player:FindFirstChild("leaderstats")
	if not entry or not stats then
		return
	end
	local grade = stats:FindFirstChild("Nota") :: NumberValue?
	local cheats = stats:FindFirstChild("Copiadas") :: IntValue?
	local catches = stats:FindFirstChild("Pillado") :: IntValue?
	if grade then
		grade.Value = ExamService.getGrade(player)
	end
	if cheats then
		cheats.Value = entry.cheated
	end
	if catches then
		catches.Value = entry.catches
	end
end

-- ─────────────────────────────────────────────────────────────
-- Replicacion de la ronda
-- ─────────────────────────────────────────────────────────────

local function pushRound(target: Player?)
	local payload = {
		phase = state.phase,
		timeLeft = math.max(0, math.floor(state.timeLeft)),
		roundNumber = state.roundNumber,
		questionCount = E.QuestionCount,
		results = state.results,
	}
	if target then
		Net.event(Net.Events.RoundUpdate):FireClient(target, payload)
	else
		Net.event(Net.Events.RoundUpdate):FireAllClients(payload)
	end
end

--- Manda un aviso como clave de idioma: el cliente lo escribe en el suyo.
function RoundService.notify(player: Player, key: string, kind: string?, args: { [string]: any }?)
	Net.event(Net.Events.Notify):FireClient(player, { key = key, args = args, kind = kind or "info" })
end

-- ─────────────────────────────────────────────────────────────
-- Jugadores
-- ─────────────────────────────────────────────────────────────

function RoundService.addPlayer(player: Player)
	setupStats(player)
	local entry = ExamService.addPlayer(player)
	if not entry.desk then
		RoundService.notify(player, "notify.roomFull", "warn")
	end
	PhoneService.reset(player)
	SuspicionService.reset(player)
	pushRound(player)
	ExamService.push(player)

	task.spawn(function()
		task.wait(0.5)
		ExamService.seatPlayer(player)
		if state.phase == "Prueba" then
			RoundService.notify(player, "notify.lateJoin", "info")
		end
	end)
end

function RoundService.onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0 -- en clase no se salta
	humanoid.WalkSpeed = 14

	-- El celular fisico se suelda al cuerpo apenas aparece el personaje,
	-- y el lapiz y el celular entran a la mochila.
	PhoneService.equip(player)
	ToolService.give(player)

	humanoid.Died:Connect(function()
		SuspicionService.reset(player)
		PhoneService.setOut(player, false)
	end)

	-- Siempre a su banco: es una clase, no un lobby.
	task.spawn(function()
		task.wait(0.6)
		ExamService.seatPlayer(player)
	end)
end

--- Lo agarraron con el celu.
function RoundService.handleCatch(player: Player)
	PhoneService.confiscate(player)
	ExamService.registerCatch(player)
	SuspicionService.pardon(player, 4)
	syncStats(player)

	local entry = ExamService.get(player)
	local catches = entry and entry.catches or 1
	local expelled = catches >= Config.Penalty.MaxCatches

	Net.event(Net.Events.Caught):FireClient(player, {
		catches = catches,
		maxCatches = Config.Penalty.MaxCatches,
		confiscatedFor = Config.Phone.ConfiscationTime,
		gradePenalty = Config.Penalty.GradePerCatch,
		expelled = expelled,
	})

	if expelled then
		RoundService.notify(player, "notify.expelled", "danger")
	else
		RoundService.notify(player, "notify.caught", "danger", {
			penalty = string.format("%.1f", Config.Penalty.GradePerCatch),
			seconds = Config.Phone.ConfiscationTime,
		})
	end
end

-- ─────────────────────────────────────────────────────────────
-- Ciclo
-- ─────────────────────────────────────────────────────────────

local function buildResults()
	local results = {}
	for player, entry in ExamService.allPlayers() do
		table.insert(results, {
			name = player.DisplayName,
			userId = player.UserId,
			grade = ExamService.getGrade(player),
			correct = entry.correct,
			answered = entry.answered,
			cheated = entry.cheated,
			catches = entry.catches,
			points = entry.points,
		})
	end
	table.sort(results, function(a, b)
		if a.grade == b.grade then
			return a.points > b.points
		end
		return a.grade > b.grade
	end)
	return results
end

local function runPhase(name: string, duration: number, onTick: ((number) -> ())?)
	state.phase = name
	state.timeLeft = duration
	pushRound()

	local lastWhole = math.floor(duration)
	while state.timeLeft > 0 do
		local dt = task.wait(0.25)
		state.timeLeft = math.max(0, state.timeLeft - dt)
		if onTick then
			onTick(dt)
		end
		local whole = math.floor(state.timeLeft)
		if whole ~= lastWhole then
			lastWhole = whole
			pushRound()
		end
	end
	state.timeLeft = 0
	pushRound()
end

function RoundService.start(classroom, teacher)
	state.classroom = classroom
	state.teacher = teacher

	task.spawn(function()
		local firstRound = true
		while true do
			-- ── Preparacion ─────────────────────────────
			-- La primera ronda arranca ya: nadie quiere entrar a un
			-- juego y mirar una hoja en blanco veinte segundos.
			if not firstRound then
				state.results = {}
				for _, player in Players:GetPlayers() do
					PhoneService.reset(player)
					SuspicionService.reset(player)
				end
				runPhase("Preparacion", E.IntermissionDuration)
			end
			firstRound = false

			-- ── Prueba ──────────────────────────────────
			state.roundNumber += 1
			ExamService.newRound(os.time() + state.roundNumber * 977)
			for _, player in Players:GetPlayers() do
				ExamService.resetPlayer(player)
				task.spawn(ExamService.seatPlayer, player)
			end
			if teacher then
				teacher:say("teacher.start", 4)
			end

			local syncAccumulator = 0
			runPhase("Prueba", E.RoundDuration, function(dt)
				syncAccumulator += dt
				if syncAccumulator >= 1 then
					syncAccumulator = 0
					for _, player in Players:GetPlayers() do
						syncStats(player)
					end
				end
			end)

			-- ── Resultados ──────────────────────────────
			for _, player in Players:GetPlayers() do
				PhoneService.setOut(player, false)
				SuspicionService.reset(player)
				syncStats(player)
				local grade = ExamService.getGrade(player)
				if grade >= E.PassingGrade then
					RoundService.notify(player, "notify.passed", "success", { grade = string.format("%.1f", grade) })
				else
					RoundService.notify(player, "notify.failed", "warn", { grade = string.format("%.1f", grade) })
				end
			end
			state.results = buildResults()
			if teacher then
				teacher:say("teacher.end", 5)
			end
			runPhase("Resultados", 15)
		end
	end)
end

function RoundService.getPhase(): string
	return state.phase
end

function RoundService.pushTo(player: Player)
	pushRound(player)
end

return RoundService

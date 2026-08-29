--!strict
--[[
	RoundManager
	------------------------------------------------------------------
	El ciclo escolar. Un dia son tres fases seguidas:

		recreo   el pasillo, los casilleros, la tienda, preparate
		examen   al pupitre, puertas trabadas, el profesor patrulla
		boletin  la nota del dia y los creditos

	Cinco dias hacen la Semana Final. Cada dia sube la dificultad
	(mas preguntas, mas duras) y si el curso desaprueba
	Config.Ronda.SuspensosParaExpulsion dias, se termina la partida y
	la semana vuelve a empezar.

	Este modulo es el unico que sabe en que fase estamos. Todos los
	demas preguntan o reciben el aviso; ninguno decide por su cuenta.
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Grades = require(Shared:WaitForChild("Grades"))
local Util = require(Shared:WaitForChild("Util"))

local ExamService = require(script.Parent:WaitForChild("ExamService"))
local TeacherAI = require(script.Parent:WaitForChild("TeacherAI"))
local SuspicionService = require(script.Parent:WaitForChild("SuspicionService"))
local PunishService = require(script.Parent:WaitForChild("PunishService"))
local ShopService = require(script.Parent:WaitForChild("ShopService"))
local ItemService = require(script.Parent:WaitForChild("ItemService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local Atmosphere = require(script.Parent:WaitForChild("Atmosphere"))
local BookService = require(script.Parent:WaitForChild("BookService"))
local PlaygroundService = require(script.Parent:WaitForChild("PlaygroundService"))

local R = Config.Ronda

local RoundManager = {}

local map: any = nil
local phase = "espera"
local day = 1
local clock = 0
local total = 0
local fails = 0
local history: { [Player]: { number } } = {}
local standing: { [Player]: boolean } = {}
local running = false

-- ── difusion de estado ─────────────────────────────────────────────

local function termGrade(player: Player): number
	local list = history[player]
	if not list or #list == 0 then
		return Config.Notas.Inicial
	end
	return math.floor(Grades.average(list) + 0.5)
end

local function statePacket(player: Player?): any
	local grade = player and termGrade(player) or Config.Notas.Inicial
	return {
		fase = phase,
		dia = day,
		dias = R.DiasPorSemana,
		nombreDia = "day." .. (R.NombreDias[day] or "lunes"),
		restante = math.max(0, math.floor(clock + 0.5)),
		total = total,
		nota = grade,
		letra = Grades.letter(grade),
		suspensos = fails,
		maxSuspensos = R.SuspensosParaExpulsion,
		jugadores = #Players:GetPlayers(),
	}
end

local function broadcast()
	local remote = Net.event(Net.Events.RoundUpdate)
	for _, player in Players:GetPlayers() do
		remote:FireClient(player, statePacket(player))
	end
end

function RoundManager.pushTo(player: Player)
	Net.event(Net.Events.RoundUpdate):FireClient(player, statePacket(player))
end

function RoundManager.phase(): string
	return phase
end

function RoundManager.day(): number
	return day
end

-- ── mapa ───────────────────────────────────────────────────────────

function RoundManager.setMap(newMap: any)
	map = newMap
end

local function lockDoors(locked: boolean)
	if not map then
		return
	end
	for _, room in map.classrooms do
		local door: BasePart = room.door
		door.CanCollide = locked
		door.Transparency = locked and 0.05 or 1
		door:SetAttribute("Trabada", locked)
	end
end

local function ringBell()
	if map and map.bell then
		Util.playSound(Config.Sonidos.Campana, map.bell, 0.8, 0.7)
		Util.playSound(Config.Sonidos.Campana, map.bell, 0.6, 1.05)
	end
	Net.event(Net.Events.Notify):FireAllClients({ key = "notify.bell" })
end

local function sendToHallway(player: Player)
	if not map or #map.spawns == 0 then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.SeatPart then
		humanoid.Sit = false
		task.wait(0.05)
	end
	if root and root:IsA("BasePart") then
		local point = map.spawns[math.random(1, #map.spawns)]
		root.CFrame = CFrame.new(point + Vector3.new(math.random(-2, 2), 0, math.random(-2, 2)))
	end
end

-- ── vigilancia del aula ────────────────────────────────────────────
-- Levantarse del pupitre en pleno examen es una infraccion. Se mide
-- aca porque es el unico modulo que sabe que estamos en examen.

local nextSeatCheck = 0

--- Cuatro veces por segundo alcanza: levantarse de una silla no es un
--- evento de un solo frame, y esto corre con el examen entero encima.
local function watchSeats()
	local now = os.clock()
	if now < nextSeatCheck then
		return
	end
	nextSeatCheck = now + 0.25

	for _, player in Players:GetPlayers() do
		local sitting = ExamService.sitting(player)
		if not sitting or PunishService.isDetained(player) then
			continue
		end
		local seated = ExamService.isSeated(player)
		if not seated and not standing[player] then
			standing[player] = true
			SuspicionService.infraction(player, Config.Sospecha.PorLevantarse, "stand")
		elseif seated and standing[player] then
			standing[player] = false
		end

		if not seated then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and root.AssemblyLinearVelocity.Magnitude > 14 then
				SuspicionService.infraction(player, Config.Sospecha.PorCorrerEnExamen * 0.1, "run")
			end
		end
	end
end

-- ── fases ──────────────────────────────────────────────────────────

local function runPhase(name: string, seconds: number, onTick: (() -> ())?)
	phase = name
	total = seconds
	clock = seconds
	ShopService.setPhase(name)
	BookService.setPhase(name)
	-- El clima de color cambia con la fase: el pasillo es lavado y
	-- frio, el aula es mas contrastada y el final de examen vira.
	pcall(function()
		Atmosphere.setMood(name == "examen" and "examen" or "pasillo")
	end)
	broadcast()

	local warned = false
	local lastBroadcast = 0
	while clock > 0 do
		local dt = RunService.Heartbeat:Wait()
		clock -= dt
		if onTick then
			onTick()
		end
		if not warned and name == "recreo" and clock <= R.AvisoCampana then
			warned = true
			Net.event(Net.Events.Notify):FireAllClients({
				key = "notify.bell_soon",
				args = { s = R.AvisoCampana },
			})
		end
		lastBroadcast += dt
		if lastBroadcast >= 0.5 then
			lastBroadcast = 0
			broadcast()
		end
	end
	clock = 0
	broadcast()
end

local function phaseRecess()
	lockDoors(false)
	TeacherAI.setExamMode(false)
	SuspicionService.freezeAll(true)
	SuspicionService.resetAll()
	PunishService.clearVisuals()
	ExamService.clear()

	for _, player in Players:GetPlayers() do
		ItemService.clearInventory(player)
		sendToHallway(player)
		ShopService.grantLoadout(player)
		standing[player] = false
	end

	runPhase("recreo", R.SegundosRecreo)
	ringBell()
end

local function phaseExam()
	local players = Players:GetPlayers()
	ExamService.begin(day, players)

	Net.event(Net.Events.Notify):FireAllClients({ key = "notify.doors_locked" })
	PlaygroundService.reset()
	ExamService.seatEveryone()
	task.wait(1.2)
	lockDoors(true)

	if map then
		for _, room in map.classrooms do
			TeacherAI.spawn(room)
		end
	end
	TeacherAI.setExamMode(true)
	SuspicionService.freezeAll(false)
	PunishService.resetAll()

	Net.event(Net.Events.Notify):FireAllClients({ key = "notify.exam_start" })
	Net.event(Net.Events.Music):FireAllClients({ clima = "examen" })

	local halfWarned = false
	runPhase("examen", R.SegundosExamen, function()
		watchSeats()
		if not halfWarned and clock <= 30 then
			halfWarned = true
			TeacherAI.sayAll("teacher.time_left", { s = 30 })
			Net.event(Net.Events.Music):FireAllClients({ clima = "tension" })
			pcall(function()
				Atmosphere.setMood("tension")
			end)
		end
	end)

	TeacherAI.sayAll("teacher.finish")
	ringBell()
	SuspicionService.freezeAll(true)
	TeacherAI.setExamMode(false)
	TeacherAI.despawnAll()
	lockDoors(false)
end

local function phaseReport()
	local results = ExamService.finish()
	PunishService.clearVisuals()
	Net.event(Net.Events.Music):FireAllClients({ clima = "pasillo" })

	local sum, count = 0, 0
	for _, player in Players:GetPlayers() do
		local result = results[player] or { correct = 0, wrong = 0, blank = 0 }
		local punishments = PunishService.count(player)
		local peak = SuspicionService.peak(player)
		local report = Grades.report(result.correct, result.wrong, result.blank, punishments, peak)

		history[player] = history[player] or {}
		table.insert(history[player], report.final)

		sum += report.final
		count += 1

		local credits = ShopService.reward(player, result.correct, report.aprobado, punishments)

		Net.event(Net.Events.Report):FireClient(player, {
			dia = day,
			dias = R.DiasPorSemana,
			examen = report.examen,
			conducta = report.conducta,
			final = report.final,
			letra = report.letra,
			aprobado = report.aprobado,
			aciertos = report.aciertos,
			total = report.total,
			castigos = punishments,
			creditos = credits,
			promedio = termGrade(player),
			suspensos = fails,
			maxSuspensos = R.SuspensosParaExpulsion,
			semana = false,
		})
		Net.event(Net.Events.Notify):FireClient(player, {
			key = report.aprobado and "notify.passed" or "notify.failed",
			args = { grade = report.letra },
		})
	end

	-- El curso desaprueba el dia si el promedio de la clase no llega.
	local classAverage = count > 0 and sum / count or 0
	if count > 0 and not Grades.passed(classAverage) then
		fails += 1
	end

	runPhase("boletin", R.SegundosBoletin)
end

local function endOfWeek(expelled: boolean)
	phase = "boletin"
	for _, player in Players:GetPlayers() do
		local average = termGrade(player)
		local profile = DataService.get(player)
		if profile then
			profile.semanas += 1
			profile.mejorPromedio = math.max(profile.mejorPromedio, average)
			if not expelled then
				DataService.addCredits(player, Config.Economia.CreditosPorSemana)
			end
			DataService.push(player)
		end

		Net.event(Net.Events.Report):FireClient(player, {
			dia = R.DiasPorSemana,
			dias = R.DiasPorSemana,
			examen = average,
			conducta = average,
			final = average,
			letra = Grades.letter(average),
			aprobado = not expelled and Grades.passed(average),
			aciertos = 0,
			total = 0,
			castigos = 0,
			creditos = expelled and 0 or Config.Economia.CreditosPorSemana,
			promedio = average,
			suspensos = fails,
			maxSuspensos = R.SuspensosParaExpulsion,
			semana = true,
			expulsado = expelled,
		})
		Net.event(Net.Events.Notify):FireClient(player, {
			key = expelled and "notify.expelled" or "notify.week_done",
		})
	end

	task.wait(R.SegundosBoletin)

	day = 1
	fails = 0
	history = {}
	broadcast()
end

-- ── bucle ──────────────────────────────────────────────────────────

local function loop()
	while true do
		-- Espera a que haya alguien. Sin esto, un servidor vacio
		-- avanzaria dias enteros solo.
		while #Players:GetPlayers() < R.MinimoJugadores do
			phase = "espera"
			clock = 0
			total = 0
			broadcast()
			Net.event(Net.Events.Notify):FireAllClients({ key = "notify.waiting" })
			task.wait(3)
		end

		local ok, err = pcall(function()
			phaseRecess()
			phaseExam()
			phaseReport()
		end)
		if not ok then
			warn("[Ronda] " .. tostring(err))
			-- Que se rompa un dia no puede dejar el colegio trabado:
			-- se limpia y se sigue con el dia siguiente.
			pcall(function()
				TeacherAI.despawnAll()
				ExamService.clear()
				lockDoors(false)
			end)
			task.wait(2)
		end

		if fails >= R.SuspensosParaExpulsion then
			endOfWeek(true)
		elseif day >= R.DiasPorSemana then
			endOfWeek(false)
		else
			day += 1
			runPhase("intermedio", R.SegundosIntermedio)
		end
	end
end

function RoundManager.start()
	if running then
		return
	end
	running = true

	Players.PlayerRemoving:Connect(function(player)
		history[player] = nil
		standing[player] = nil
	end)

	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			task.wait(1)
			RoundManager.pushTo(player)
		end)
	end)

	task.spawn(loop)
end

return RoundManager

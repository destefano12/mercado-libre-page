--!nonstrict
-- SoloRunner.luau — Supervivencia, Suelto, Racha Diaria y Pasá el Micro.
--
-- These run entirely on the client against the same Scoring module the server
-- uses for party rounds, which is the whole point: a 740 in Supervivencia and
-- a 740 in a party round mean the same performance.

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Modes = require(Shared.Modes)
local Scoring = require(Shared.Scoring)
local SoundLibrary = require(Shared.SoundLibrary)
local Roulette = require(Shared.Roulette)

local AudioEngine = require(script.Parent.AudioEngine)
local Booth = require(script.Parent.Booth)
local CameraDirector = require(script.Parent.CameraDirector)

local SoloRunner = {}

local running = false

local function modeById(id)
	for _, m in ipairs(Modes) do
		if m.id == id then
			return m
		end
	end
	return nil
end

-- Same four sounds for everybody, keyed to the UTC date. Rolls over at 00:00 UTC.
local function dailySeed()
	local t = os.date("!*t", os.time())
	return t.year * 10000 + t.month * 100 + t.day
end

-- One round: reference, count-in, take, grade. Shared by every solo mode.
local function runRound(ui, sound, round, rounds, header)
	ui.stage:setSound(sound, round, rounds)
	ui.stage:setVisible(true)
	ui.stage:hideCard()
	ui:setPhase("reference")
	if header then
		ui.stage:setHint(header)
	end

	CameraDirector.setShot("CamWide", 2.4)

	-- Reference.
	local done = false
	AudioEngine.playReference(sound, {
		onFrame = function(alpha)
			ui.stage:setReferencePlayhead(alpha)
		end,
		onFinish = function()
			done = true
		end,
	})
	repeat
		task.wait(0.05)
	until done
	ui.stage:setReferencePlayhead(nil)
	task.wait(Config.PHASE.REFERENCE_PAD)

	-- Take.
	ui:setPhase("record")
	CameraDirector.setShot("CamBooth", 3.0)
	local take = Booth.record(sound, {
		onMode = function(mode, reason)
			ui.stage:setInputMode(mode, reason)
		end,
		onCalibrate = function(level)
			ui.stage:setMicLevel(level, true)
		end,
		onCountIn = function(n)
			ui.stage:showCountIn(n)
		end,
		onFrame = function(alpha, pitch, voiced, index, level, raw)
			ui.stage:onRecordFrame(alpha, pitch, voiced, index, level)
			ui.stage:setMicLevel(raw or level, false)
		end,
	})

	ui.stage:showTake(take, sound.duration)
	ui.stage:setReferencePlayhead(nil)
	ui.stage:setMicLevel(0, false)

	-- Grade and play it back against the reference, as the original does.
	-- Same module, same weights-per-mode rule the server uses.
	local grade = Scoring.grade(sound, take, Booth.weightsFor(take.mode))
	ui:setPhase("playback")
	CameraDirector.focusMark(3, 2.6)
	AudioEngine.playTake(take, sound.duration, nil)
	ui.stage:showCard({
		name = Players.LocalPlayer.DisplayName,
		grade = grade,
		awarded = grade.total,
		verdict = Scoring.verdict(grade.total),
	})
	task.wait(sound.duration + 1.4)

	return grade
end

-- ── Supervivencia ────────────────────────────────────────────────────────────
local function survival(ui)
	local cfg = Config.SURVIVAL
	local playlist = SoundLibrary.playlist(os.time(), cfg.SOUNDS)
	local lives = cfg.LIVES
	local total = 0

	for round = 1, cfg.SOUNDS do
		local target = math.min(cfg.TARGET_CAP, cfg.TARGET_START + (round - 1) * cfg.TARGET_STEP)
		local grade = runRound(ui, playlist[round], round, cfg.SOUNDS,
			("OBJETIVO %d  ·  VIDAS %s"):format(target, string.rep("●", lives)))
		total += grade.total

		if grade.total < target then
			lives -= 1
			ui:showToast(("%d < %d. Te queda%s %d vida%s.")
				:format(grade.total, target, lives == 1 and "" or "n", lives, lives == 1 and "" or "s"),
				lives > 0 and "warn" or "bad")
			if lives <= 0 then
				ui:showToast(("Fin. %d rondas, %d puntos."):format(round, total), "bad")
				return total, round
			end
		else
			ui:showToast(("%d ≥ %d. Seguís."):format(grade.total, target), "good")
		end
		task.wait(1.2)
	end

	AudioEngine.applause()
	ui:showToast(("Las %d. %d puntos."):format(cfg.SOUNDS, total), "good")
	return total, cfg.SOUNDS
end

-- ── Suelto ───────────────────────────────────────────────────────────────────
local function justPlay(ui)
	local mode = modeById("justplay")
	local playlist = SoundLibrary.playlist(os.time(), Config.JUST_PLAY.ROUNDS)
	local total = 0

	for round = 1, Config.JUST_PLAY.ROUNDS do
		-- Route choice before the sound: the bet is made blind, on purpose.
		local route = mode.routes[1]
		local picked = false
		ui:showToast("Elegí ruta: 1 Segura · 2 Arriesgada · 3 Enfocada", "neutral")
		local conn
		conn = game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
			if processed or picked then
				return
			end
			local map = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3 }
			local index = map[input.KeyCode]
			if index then
				route = mode.routes[index]
				picked = true
			end
		end)
		local deadline = os.clock() + 5
		repeat
			task.wait(0.1)
		until picked or os.clock() > deadline
		conn:Disconnect()

		ui:showToast(("Ruta %s · %s"):format(route.name, route.blurb), "neutral")
		task.wait(0.8)

		local grade = runRound(ui, playlist[round], round, Config.JUST_PLAY.ROUNDS,
			("RUTA %s  ·  ×%s"):format(route.name:upper(), route.mult))

		local base = route.axis and grade[route.axis] or grade.total
		local awarded = math.floor(base * route.mult + 0.5)
		if route.floor and grade.total < route.floor then
			awarded = 0
			ui:showToast(("Por debajo de %d. La ruta arriesgada no paga."):format(route.floor), "bad")
		end
		total += awarded

		-- Bonus wheel between rounds, same wheel, points only.
		if round < Config.JUST_PLAY.ROUNDS then
			local rng = Random.new(os.clock() * 1e6 % 2 ^ 31)
			local index, segment = Roulette.spin(rng)
			ui.roulette:spin({ {
				userId = Players.LocalPlayer.UserId,
				name = Players.LocalPlayer.DisplayName,
				segmentIndex = index, segmentId = segment.id,
				kind = segment.kind, label = segment.label,
			} }, Config.PHASE.ROULETTE_SPIN, Players.LocalPlayer.UserId)
			ui:setPhase("roulette")
			CameraDirector.setShot("CamRoulette", 3.4)
			task.wait(Config.PHASE.ROULETTE_SPIN + 0.6)
			if segment.kind == "points" then
				total += segment.amount
			end
			ui.roulette:hide()
		end
	end

	ui:showToast(("Suelto: %d puntos."):format(total), "good")
	return total
end

-- ── Racha Diaria ─────────────────────────────────────────────────────────────
local function daily(ui)
	local playlist = SoundLibrary.playlist(dailySeed(), Config.DAILY.SOUNDS)
	local total = 0
	for round = 1, Config.DAILY.SOUNDS do
		local grade = runRound(ui, playlist[round], round, Config.DAILY.SOUNDS, "RACHA DIARIA")
		total += grade.total
	end
	ui:showToast(("Racha de hoy: %d puntos. Se reinicia a las 00:00 UTC."):format(total), "good")
	return total
end

-- ── Pasá el Micro ────────────────────────────────────────────────────────────
-- Several people, one device, taking turns. Local results, no server involved.
local function passTheMic(ui)
	local turns = 4
	local playlist = SoundLibrary.playlist(os.time(), turns)
	local results = {}

	for turn = 1, turns do
		ui:showToast(("Turno %d de %d. Pasá el micro y apretá para empezar."):format(turn, turns), "neutral")
		local ready = false
		local conn
		conn = game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
			if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
				ready = true
			end
		end)
		repeat
			task.wait(0.1)
		until ready
		conn:Disconnect()
		task.wait(0.4)

		local grade = runRound(ui, playlist[turn], turn, turns, ("JUGADOR %d"):format(turn))
		table.insert(results, { name = ("Jugador %d"):format(turn), score = grade.total })
	end

	table.sort(results, function(a, b)
		return a.score > b.score
	end)
	ui:setPhase("results")
	ui:showResults(results)
	AudioEngine.applause()
	task.wait(Config.PHASE.RESULTS)
	return results[1] and results[1].score or 0
end

local RUNNERS = {
	survival = survival,
	justplay = justPlay,
	daily = daily,
	passthemic = passTheMic,
}

function SoloRunner.isRunning()
	return running
end

-- Returns immediately; the mode plays out in its own coroutine.
function SoloRunner.start(modeId, ui, onFinish)
	if running then
		return false
	end
	local runner = RUNNERS[modeId]
	if not runner then
		return false
	end
	running = true

	task.spawn(function()
		local ok, err = pcall(runner, ui)
		if not ok then
			warn("[SoloRunner] " .. tostring(err))
			ui:showToast("Se cortó el modo solo. Volvés al lobby.", "bad")
		end
		running = false
		ui.stage:setVisible(false)
		ui.stage:hideCard()
		ui.roulette:hide()
		ui:setPhase("lobby")
		CameraDirector.setShot("CamHouse", 2.0)
		if onFinish then
			onFinish()
		end
	end)

	return true
end

return SoloRunner

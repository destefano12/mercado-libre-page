--!nonstrict
-- init.client.luau — wiring. The server owns truth; this file owns the show.
--
-- Every phase transition arrives as one State payload with an absolute
-- deadline, so the client never negotiates timing: it renders, it records when
-- told, and it submits once.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local Shared = game.ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local SoundLibrary = require(Shared.SoundLibrary)
local Modes = require(Shared.Modes)
local Sabotages = require(Shared.Sabotages)
local Roulette = require(Shared.Roulette)

local CameraDirector = require(script.CameraDirector)
local AudioEngine = require(script.AudioEngine)
local Booth = require(script.Booth)
local SoloRunner = require(script.SoloRunner)
local Root = require(script.UI.Root)

local localPlayer = Players.LocalPlayer

-- The stage has to exist before the camera can be framed against it.
local anchors do
	local venue = workspace:WaitForChild("Venue", 60)
	anchors = venue and venue:WaitForChild("StageAnchors", 20)
end

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

CameraDirector.init(anchors)

local lastSabotageWon = nil
local state = { phase = "boot", round = 0, rounds = Config.ROUNDS_PER_PARTY, endsAt = 0, soundId = nil }
local selectedMode = "party"
local armedMode = nil
local referenceHandle
local recording = false

local ui

local function modeById(id)
	for _, m in ipairs(Modes) do
		if m.id == id then
			return m
		end
	end
	return nil
end

ui = Root.new({
	onMode = function(id)
		local mode = modeById(id)
		selectedMode = id
		if not mode then
			return
		end
		AudioEngine.click()

		if not mode.solo then
			armedMode = nil
			ui.menu:setStatus("Fiesta online. Arranca sola cuando haya 2 jugadores en la sala.")
			return
		end

		if armedMode == id then
			-- Second click on an armed mode starts it.
			armedMode = nil
			ui.menu:setStatus("")
			AudioEngine.confirm()
			SoloRunner.start(id, ui, function()
				ui.menu:setStatus("")
			end)
		else
			armedMode = id
			ui.menu:setStatus(("%s — tocá otra vez para empezar."):format(mode.name))
		end
	end,

	onCharacter = function(id)
		AudioEngine.click()
		ui.menu:setCharacter(id)
		Net.fireServer(Net.ChooseCharacter, { characterId = id })
	end,
})

ui:setPhase("lobby")
ui.menu:setStatus("Fiesta online. Arranca sola cuando haya 2 jugadores en la sala.")

-- ── the take ───────────────────────────────────────────────────────────────────
-- Started by the record phase, submitted exactly once, never retried.
local function runTake(sound)
	if recording or SoloRunner.isRunning() then
		return
	end
	recording = true

	local ok, take = pcall(Booth.record, sound, {
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

	recording = false

	if not ok then
		warn("[Client] take failed: " .. tostring(take))
		Net.fireServer(Net.SubmitTake, { notes = {} })
		return
	end

	ui.stage:showTake(take, sound.duration)
	ui.stage:setHint("TOMA ENVIADA")
	ui.stage:setMicLevel(0, false)
	-- Only the contour travels. The server grades it, on the axes this input
	-- mode could actually drive.
	Net.fireServer(Net.SubmitTake, { notes = take.notes, mode = take.mode })
end

-- ── phase handling ─────────────────────────────────────────────────────────────
local function onPhase(payload)
	local phase = payload.phase
	local sound = payload.soundId and SoundLibrary.get(payload.soundId)

	if SoloRunner.isRunning() then
		return   -- a solo run owns the screen until it finishes
	end

	CameraDirector.onPhase(phase)
	ui:setPhase(phase)
	ui.scoreboard:update(payload.scores)

	if phase == "lobby" then
		local need = math.max(0, (payload.minPlayers or 2) - (payload.playerCount or 0))
		if need > 0 then
			ui.menu:setStatus(("Falta%s %d jugador%s para arrancar la fiesta.")
				:format(need == 1 and "" or "n", need, need == 1 and "" or "es"))
		elseif payload.endsAt and payload.endsAt > 0 then
			ui.menu:setStatus("Sala lista. Arrancando.")
		end
		ui:setVoiceGated(false)

	elseif phase == "round_intro" then
		ui.stage:setSound(sound, payload.round, payload.rounds)
		ui.stage:setHint("ESCUCHÁ LA REFERENCIA")

	elseif phase == "reference" then
		ui.stage:setSound(sound, payload.round, payload.rounds)
		if referenceHandle then
			referenceHandle:stop()
		end
		if sound then
			referenceHandle = AudioEngine.playReference(sound, {
				onFrame = function(alpha)
					ui.stage:setReferencePlayhead(alpha)
				end,
				onFinish = function()
					ui.stage:setReferencePlayhead(nil)
				end,
			})
		end

	elseif phase == "record" then
		if sound then
			task.spawn(runTake, sound)
		end

	elseif phase == "playback" then
		ui.stage:setHint("")
		ui:setVoiceGated(true)

	elseif phase == "roulette" then
		ui:setVoiceGated(false)

	elseif phase == "sabotage_pick" then
		-- Only a player who actually won a sabotage gets the picker.
		local isPicker = false
		for _, userId in ipairs(payload.sabotagePickers or {}) do
			if userId == localPlayer.UserId then
				isPicker = true
			end
		end
		if isPicker then
			local candidates = {}
			for _, entry in ipairs(payload.scores or {}) do
				if entry.userId ~= localPlayer.UserId then
					table.insert(candidates, entry)
				end
			end
			ui.roulette.root.Visible = true
			ui.roulette:showTargetPicker(lastSabotageWon, candidates, function(userId)
				Net.fireServer(Net.ChooseSabotageTarget, { userId = userId })
			end)
		end

	elseif phase == "results" then
		ui:showResults(payload.scores)
		AudioEngine.applause()
		ui:setVoiceGated(false)
	end

	state = payload
end

Net.onClient(Net.State, onPhase)

Net.onClient(Net.Playback, function(payload)
	if SoloRunner.isRunning() then
		return
	end

	local sound = SoundLibrary.get(payload.soundId)
	if not sound then
		return
	end

	-- Push in on whoever is up.
	local entry
	for _, s in ipairs(state.scores or {}) do
		if s.userId == payload.userId then
			entry = s
		end
	end
	CameraDirector.focusMark(entry and entry.markIndex or 3, 2.6)

	ui.stage:setSound(sound, state.round, state.rounds)
	ui.stage:showTake(payload.take or { notes = {} }, sound.duration)
	ui.stage:showCard(payload)
	ui:setVoiceGated(payload.voiceGated == true)

	if payload.sabotage and payload.userId == localPlayer.UserId then
		local def = Sabotages.get(payload.sabotage)
		ui:showToast(("Te sabotearon: %s%s"):format(
			def and def.name or "?",
			payload.sabotageFrom and (" — " .. payload.sabotageFrom) or ""), "bad")
	end

	-- The whole table hears the same take, sabotage included.
	AudioEngine.playTake(payload.take or { notes = {} }, sound.duration, payload.sabotage, {
		onFrame = function(alpha)
			ui.stage.yours:setPlayhead(alpha)
		end,
		onFinish = function()
			ui.stage.yours:setPlayhead(nil)
		end,
	})
end)

Net.onClient(Net.RouletteSpin, function(payload)
	if SoloRunner.isRunning() then
		return
	end
	-- Remember which sabotage we won, so the picker that follows knows what it
	-- is aiming. The server already holds the authoritative copy.
	lastSabotageWon = nil
	for _, r in ipairs(payload.results or {}) do
		if r.userId == localPlayer.UserId and r.kind == "sabotage" then
			for _, seg in ipairs(Roulette.segments()) do
				if seg.id == r.segmentId then
					lastSabotageWon = seg.sabotage
				end
			end
		end
	end
	ui.roulette:spin(payload.results, payload.spin or Config.PHASE.ROULETTE_SPIN, localPlayer.UserId)
end)

Net.onClient(Net.Scores, function(payload)
	ui.scoreboard:update(payload.scores)
end)

Net.onClient(Net.Toast, function(payload)
	ui:showToast(payload.text, payload.tone)
end)

Net.onClient(Net.SabotageHit, function(payload)
	if payload.aimed then
		ui:showToast(("Apuntado a %s. No lo sabe todavía."):format(payload.at or "?"), "warn")
	end
end)

-- ── the clock ──────────────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
	if not state.endsAt or state.endsAt <= 0 then
		ui:setClock(nil)
		return
	end
	ui:setClock(state.endsAt - workspace:GetServerTimeNow())
end)

-- Escape closes a solo run's menus; it must never cancel a take in progress.
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape and Booth.isRecording() then
		ui:showToast("Una sola toma. No se puede cancelar.", "warn")
	end
end)

print("[Mimic Party] client ready.")

--!nonstrict
-- Booth.luau — the recording booth. This is the input half of the game.
--
-- You sing, shout, bark or beatbox into your actual microphone and the game
-- hears you. What it can hear is bounded by the engine, not by this code:
--
--   loudness, per audio buffer   →  available (AudioAnalyzer.RmsLevel, client)
--   frequency / pitch            →  blocked (GetSpectrum returns an empty array
--                                   for AudioDeviceInput, by design, privacy)
--
-- So the microphone drives the envelope, the attacks and the rhythm — the real
-- shape of what you just performed — and pitch, which the engine will not give
-- up, is taken from how high you hold the pointer. Three input modes:
--
--   "voice"       mic + pointer height for pitch        (default)
--   "voice_only"  mic alone; the melody axis is dropped and its weight is
--                 redistributed, so totals stay comparable
--   "pointer"     no mic available: hold to vocalise, pointer for pitch
--
-- Every mode produces the identical { t, dur, pitch } note list, so Scoring
-- never learns which one was used.

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Shared = game.ReplicatedStorage.Shared
local Config = require(Shared.Config)
local SoundLibrary = require(Shared.SoundLibrary)

local AudioEngine = require(script.Parent.AudioEngine)
local VoiceInput = require(script.Parent.VoiceInput)

local Booth = {}

local PITCH_RANGE = Config.TAKE.PITCH_RANGE
local MIN_NOTE = Config.TAKE.MIN_NOTE
local MAX_NOTES = Config.TAKE.MAX_NOTES
local SAMPLES = Config.TAKE.ENVELOPE_SAMPLES

local active = false
local preferred = Config.INPUT.DEFAULT
local probed, probeOk, probeReason = false, false, nil

-- ── mode resolution ──────────────────────────────────────────────────────────

-- Probed once per session: opening the mic graph is cheap but not free, and the
-- answer cannot change mid-session.
local function probe()
	if not probed then
		probeOk, probeReason = VoiceInput.probe()
		probed = true
	end
	return probeOk, probeReason
end

function Booth.setPreferredMode(mode)
	if mode == "voice" or mode == "voice_only" or mode == "pointer" then
		preferred = mode
	end
end

function Booth.preferredMode()
	return preferred
end

-- What this take will actually use, and why, in words a player can read.
function Booth.resolveMode()
	if preferred == "pointer" then
		return "pointer", "Puntero: mantené apretado."
	end
	local ok, reason = probe()
	if not ok then
		return "pointer", reason or "Sin micrófono. Usás el puntero."
	end
	return preferred, nil
end

function Booth.micAvailable()
	local ok = probe()
	return ok
end

function Booth.micReason()
	local _, reason = probe()
	return reason
end

-- The scoring weights that match an input mode. The server is told the mode and
-- applies the same table, so nobody is graded on an axis they could not drive.
function Booth.weightsFor(mode)
	if mode == "voice_only" then
		return Config.SCORING_VOICE_ONLY
	end
	return nil
end

-- ── pointer pitch ────────────────────────────────────────────────────────────

local function pitchFromPointer()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize
	if not viewport or viewport.Y <= 0 then
		return 0
	end
	local y = UserInputService:GetMouseLocation().Y
	-- The usable band is the middle 70% of the screen, so the extremes are
	-- reachable without hunting for the last pixel.
	local alpha = math.clamp((y / viewport.Y - 0.15) / 0.7, 0, 1)
	return (0.5 - alpha) * 2 * PITCH_RANGE
end

local function pointerHeld()
	return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		or UserInputService:IsKeyDown(Enum.KeyCode.Space)
		or UserInputService:IsKeyDown(Enum.KeyCode.ButtonA)
end

-- ── note builder ─────────────────────────────────────────────────────────────
-- Shared by every mode: open a note, bend it, close it, drop the accidents.

local function newBuilder(duration)
	return {
		notes = {},
		openNote = nil,
		duration = duration,

		open = function(self, t, pitch)
			if #self.notes >= MAX_NOTES or self.openNote then
				return
			end
			self.openNote = { t = t, dur = MIN_NOTE, pitch = pitch }
			table.insert(self.notes, self.openNote)
		end,

		bend = function(self, t, pitch)
			local n = self.openNote
			if not n then
				return
			end
			-- A held attack tracks the pointer: the note bends with your hand,
			-- which is what makes a contour possible at all.
			n.pitch = n.pitch * 0.72 + pitch * 0.28
			n.dur = math.max(MIN_NOTE, t - n.t)
		end,

		close = function(self, t)
			local n = self.openNote
			if not n then
				return
			end
			n.dur = math.max(MIN_NOTE, t - n.t)
			if n.t + n.dur > self.duration then
				n.dur = math.max(MIN_NOTE, self.duration - n.t)
			end
			self.openNote = nil
		end,

		finish = function(self)
			local out = {}
			for _, n in ipairs(self.notes) do
				if n.dur >= MIN_NOTE then
					table.insert(out, { t = n.t, dur = n.dur, pitch = n.pitch })
				end
			end
			return out
		end,
	}
end

-- ── the take ─────────────────────────────────────────────────────────────────
-- Blocking; call from a coroutine.
--   hooks.onCountIn(n)                      3 · 2 · 1 · 0 (= GO)
--   hooks.onCalibrate(level, floor)         while the room is being measured
--   hooks.onMode(mode, reason)              resolved input mode, before count-in
--   hooks.onFrame(alpha, pitch, voiced, i, level)
--   hooks.onClose()
function Booth.record(sound, hooks)
	assert(not active, "[Booth] a take is already being recorded")
	active = true
	hooks = hooks or {}

	local mode, reason = Booth.resolveMode()
	local session, openReason

	if mode ~= "pointer" then
		session, openReason = VoiceInput.open()
		if not session then
			mode = Config.INPUT.FALLBACK
			reason = openReason
		end
	end

	if hooks.onMode then
		hooks.onMode(mode, reason)
	end

	-- ── count-in, which is also the calibration window ──
	-- The room is measured while the player is counted in, so calibration costs
	-- nothing: by "GO" the gate is already tuned to their mic and their room.
	local countIn = Config.PHASE.COUNT_IN
	local calibrated = false

	if session then
		task.spawn(function()
			session:calibrate(math.min(Config.VOICE.CALIBRATE_FOR, countIn), function(level)
				if hooks.onCalibrate then
					hooks.onCalibrate(level, session.floor)
				end
			end)
			calibrated = true
		end)
	else
		calibrated = true
	end

	for n = countIn, 1, -1 do
		if hooks.onCountIn then
			hooks.onCountIn(n)
		end
		AudioEngine.tick()
		task.wait(1)
	end
	if hooks.onCountIn then
		hooks.onCountIn(0)
	end

	-- Calibration runs inside the count-in, but never start the take before it
	-- has actually produced a floor.
	local guard = os.clock() + 0.5
	while session and not calibrated and os.clock() < guard do
		task.wait(0.02)
	end

	-- ── record ──
	local duration = sound.duration
	local builder = newBuilder(duration)
	local envelope = table.create(SAMPLES, 0)
	local monitor = (mode == "pointer") and AudioEngine.openMonitor() or nil

	local gate
	if session then
		local openAt, closeAt = session:thresholds()
		gate = VoiceInput.Gate.new(openAt, closeAt)
	end

	local started = os.clock()
	local lastFrame = started
	local touchHeld = false

	local touchBegan, touchEnded
	if mode ~= "voice_only" then
		touchBegan = UserInputService.TouchStarted:Connect(function()
			touchHeld = true
		end)
		touchEnded = UserInputService.TouchEnded:Connect(function()
			touchHeld = false
		end)
	end

	local conn
	conn = RunService.RenderStepped:Connect(function()
		local nowClock = os.clock()
		local t = nowClock - started
		local dt = nowClock - lastFrame
		lastFrame = nowClock
		if t >= duration then
			return
		end

		local voiced, level, pitch

		if session then
			-- ── real microphone ──
			local rms = session:rms()
			level = session:level(rms, dt)
			local event, at
			voiced, event, at = gate:step(rms, t)

			-- Pitch: the pointer in "voice", nothing in "voice_only".
			pitch = (mode == "voice") and pitchFromPointer() or 0

			if event == "onset" then
				builder:open(at or t, pitch)
			elseif event == "end" then
				builder:close(at or t)
			elseif voiced then
				builder:bend(t, pitch)
			end
		else
			-- ── pointer ──
			voiced = pointerHeld() or touchHeld
			pitch = pitchFromPointer()
			level = voiced and 1 or 0

			if voiced and not builder.openNote then
				builder:open(t, pitch)
			elseif voiced then
				builder:bend(t, pitch)
			elseif builder.openNote then
				builder:close(t)
			end

			if monitor then
				monitor:set(builder.openNote and builder.openNote.pitch or pitch, voiced)
			end
		end

		-- The envelope is the real loudness curve when the mic is driving it,
		-- which is why the green waveform looks like a voice and not a square.
		local index = math.clamp(math.floor(t / duration * SAMPLES) + 1, 1, SAMPLES)
		envelope[index] = math.max(envelope[index], voiced and math.max(level, 0.25) or 0)

		if hooks.onFrame then
			hooks.onFrame(t / duration, pitch, voiced, index, envelope[index], level)
		end
	end)

	task.wait(duration)

	-- Hard stop. One take.
	conn:Disconnect()
	if touchBegan then touchBegan:Disconnect() end
	if touchEnded then touchEnded:Disconnect() end
	if gate then gate:forceClose(duration) end
	builder:close(duration)
	if monitor then monitor:close() end
	if session then session:close() end

	if hooks.onClose then
		hooks.onClose()
	end
	active = false

	return {
		notes = builder:finish(),
		envelope = envelope,
		mode = mode,
	}
end

function Booth.isRecording()
	return active
end

-- The envelope the waveform should draw for a finished take. A take recorded
-- with a microphone carries its own measured envelope; a pointer take is
-- reconstructed from its notes.
function Booth.envelopeFor(take, duration)
	if take.envelope then
		return take.envelope
	end
	return SoundLibrary.envelope(take.notes, duration, SAMPLES)
end

return Booth

--!nonstrict
-- Booth.luau — the recording booth. This is the input half of the game.
--
-- Roblox cannot read a microphone: no script can reach the audio samples, so a
-- real voice cannot be scored on this platform. What is preserved instead is
-- the thing that was actually being measured — melody, rhythm and attacks —
-- with the mouse standing in for the throat:
--
--     hold  (mouse / Space / touch) → you are vocalising
--     move  up / down               → pitch, ±9 semitones
--     release                       → that attack ends
--
-- Everything else behaves exactly like the original: one countdown, one take,
-- a hard stop at the end of the window, and no retry. You monitor yourself
-- live while recording, and the take is submitted the instant it closes.

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage.Shared
local Config = require(Shared.Config)
local SoundLibrary = require(Shared.SoundLibrary)

local AudioEngine = require(script.Parent.AudioEngine)

local Booth = {}

local PITCH_RANGE = Config.TAKE.PITCH_RANGE
local MIN_NOTE = Config.TAKE.MIN_NOTE
local MAX_NOTES = Config.TAKE.MAX_NOTES
local SAMPLES = Config.TAKE.ENVELOPE_SAMPLES

local active = false

-- Screen Y → semitones. Inverted, because up should mean higher.
local function pitchFromPointer()
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
	if not viewport or viewport.Y <= 0 then
		return 0
	end
	local y = UserInputService:GetMouseLocation().Y
	-- The usable band is the middle 70% of the screen, so the extremes are
	-- reachable without hunting for the last pixel.
	local alpha = math.clamp((y / viewport.Y - 0.15) / 0.7, 0, 1)
	return (0.5 - alpha) * 2 * PITCH_RANGE
end

local function isHeld()
	return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		or UserInputService:IsKeyDown(Enum.KeyCode.Space)
		or UserInputService:IsKeyDown(Enum.KeyCode.ButtonA)
end

-- Runs one take. Blocking (call from a coroutine).
--   sound    the reference being imitated
--   hooks    { onCountIn(n), onFrame(alpha, pitch, voiced, envelopeIndex, level), onClose() }
-- Returns the take: { notes = { {t, dur, pitch}, ... } }
function Booth.record(sound, hooks)
	assert(not active, "[Booth] a take is already being recorded")
	active = true
	hooks = hooks or {}

	-- ── count-in ──
	for n = Config.PHASE.COUNT_IN, 1, -1 do
		if hooks.onCountIn then
			hooks.onCountIn(n)
		end
		AudioEngine.tick()
		task.wait(1)
	end
	if hooks.onCountIn then
		hooks.onCountIn(0)   -- "GO"
	end

	-- ── the take ──
	local duration = sound.duration
	local notes = {}
	local envelope = table.create(SAMPLES, 0)
	local monitor = AudioEngine.openMonitor()

	local openNote = nil
	local started = os.clock()
	local touchHeld = false

	-- Touch devices have no mouse button to hold: a finger down is the hold.
	local touchBegan = UserInputService.TouchStarted:Connect(function()
		touchHeld = true
	end)
	local touchEnded = UserInputService.TouchEnded:Connect(function()
		touchHeld = false
	end)

	local function closeNote(at)
		if not openNote then
			return
		end
		openNote.dur = math.max(MIN_NOTE, at - openNote.t)
		if openNote.t + openNote.dur > duration then
			openNote.dur = math.max(MIN_NOTE, duration - openNote.t)
		end
		openNote = nil
	end

	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t >= duration then
			return
		end

		local held = isHeld() or touchHeld
		local pitch = pitchFromPointer()

		if held and not openNote and #notes < MAX_NOTES then
			openNote = { t = t, dur = MIN_NOTE, pitch = pitch }
			table.insert(notes, openNote)
		elseif held and openNote then
			-- A held attack tracks the pointer: the note bends with your hand,
			-- which is what makes a contour possible at all.
			openNote.pitch = openNote.pitch * 0.72 + pitch * 0.28
			openNote.dur = math.max(MIN_NOTE, t - openNote.t)
		elseif not held and openNote then
			closeNote(t)
		end

		local index = math.clamp(math.floor(t / duration * SAMPLES) + 1, 1, SAMPLES)
		local level = held and 1 or 0
		envelope[index] = math.max(envelope[index], level)

		monitor:set(openNote and openNote.pitch or pitch, held)

		if hooks.onFrame then
			hooks.onFrame(t / duration, openNote and openNote.pitch or pitch, held, index, level)
		end
	end)

	task.wait(duration)

	-- Hard stop. One take.
	conn:Disconnect()
	touchBegan:Disconnect()
	touchEnded:Disconnect()
	closeNote(duration)
	monitor:close()

	-- Drop accidental taps: a 2-frame click is not an attack.
	local cleaned = {}
	for _, n in ipairs(notes) do
		if n.dur >= MIN_NOTE then
			table.insert(cleaned, { t = n.t, dur = n.dur, pitch = n.pitch })
		end
	end

	if hooks.onClose then
		hooks.onClose()
	end
	active = false

	return { notes = cleaned, envelope = envelope }
end

function Booth.isRecording()
	return active
end

-- The envelope the waveform should draw for a finished take.
function Booth.envelopeFor(take, duration)
	return SoundLibrary.envelope(take.notes, duration, SAMPLES)
end

return Booth

--!nonstrict
-- AudioEngine.luau — renders a contour as audible sound, and ruins it on cue.
--
-- There is no audio file per reference. One sustained tone is pitch-shifted
-- per note and gated by the envelope, which means the entire 36-sound library
-- plays with zero uploads, and a take sounds like the same instrument as the
-- reference it is being compared to — which is the fair way to do it.
--
-- Sabotages are applied to the live Sound as real SoundEffects, so a saturated
-- take is genuinely clipping and a chopped one is genuinely being cut.

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = game.ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Sabotages = require(Shared.Sabotages)

local AudioEngine = {}

local group = Instance.new("SoundGroup")
group.Name = "MimicPartyVoices"
group.Volume = 0.85
group.Parent = SoundService

local function newTone(volume)
	local s = Instance.new("Sound")
	s.SoundId = Config.AUDIO.VOICE_TONE
	s.Looped = true
	s.Volume = 0
	s.RollOffMode = Enum.RollOffMode.Linear
	s.SoundGroup = group
	s.Parent = SoundService
	s:Play()
	s.Volume = 0
	s.TimePosition = 0
	s.Volume = volume or 0
	return s
end

local function semitonesToSpeed(semitones)
	return 2 ^ (semitones / 12)
end

-- Renders `notes` over `duration`. Returns a handle: :stop(), .done (bool),
-- and an optional per-frame callback for the playhead.
function AudioEngine.playPattern(notes, duration, opts)
	opts = opts or {}
	local tone = newTone(0)
	local cleanupSabotage = Sabotages.applyTo(tone, opts.sabotage)

	local handle = { done = false }
	local started = os.clock()
	local baseVolume = opts.volume or 0.52
	local conn

	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t >= duration or handle.done then
			if conn then
				conn:Disconnect()
				conn = nil
			end
			handle.done = true
			cleanupSabotage()
			tone:Stop()
			tone:Destroy()
			if opts.onFinish then
				opts.onFinish()
			end
			return
		end

		local active
		for _, n in ipairs(notes) do
			if t >= n.t and t <= n.t + n.dur then
				active = n
				break
			end
		end

		if active then
			-- Short attack / release so each note has an edge instead of a click.
			local localT = (t - active.t) / math.max(active.dur, 1e-3)
			local shape = math.min(1, localT / 0.1) * math.min(1, (1 - localT) / 0.14 + 0.4)
			tone.PlaybackSpeed = semitonesToSpeed(active.pitch) * (opts.speed or 1)
			tone.Volume = baseVolume * math.clamp(shape, 0, 1)
		else
			tone.Volume = 0
		end

		if opts.onFrame then
			opts.onFrame(t / duration, active and active.pitch or nil, active ~= nil)
		end
	end)

	function handle:stop()
		self.done = true
		if conn then
			conn:Disconnect()
			conn = nil
		end
		cleanupSabotage()
		if tone.Parent then
			tone:Stop()
			tone:Destroy()
		end
	end

	return handle
end

function AudioEngine.playReference(sound, opts)
	opts = opts or {}
	opts.volume = opts.volume or 0.6
	return AudioEngine.playPattern(sound.notes, sound.duration, opts)
end

-- Plays somebody's take, honouring the sabotage aimed at them.
-- `swap` short-circuits the whole thing: the table hears the SFX, not the voice.
function AudioEngine.playTake(take, duration, sabotageId, opts)
	opts = opts or {}
	local def = sabotageId and Sabotages.get(sabotageId)

	if def and def.replacesTake then
		local s = Instance.new("Sound")
		s.SoundId = Config.AUDIO.SWAP_SFX
		s.Volume = 0.65
		s.SoundGroup = group
		s.Parent = SoundService
		s:Play()
		task.delay(math.max(duration, 1.2), function()
			s:Destroy()
			if opts.onFinish then
				opts.onFinish()
			end
		end)
		local handle = { done = false }
		function handle:stop()
			self.done = true
			if s.Parent then
				s:Destroy()
			end
		end
		return handle
	end

	opts.sabotage = sabotageId
	opts.volume = opts.volume or 0.55
	return AudioEngine.playPattern(take.notes, duration, opts)
end

-- Live monitoring while you record: you hear your own contour as you make it.
function AudioEngine.openMonitor()
	local tone = newTone(0)
	tone.Volume = 0
	local monitor = {}

	function monitor:set(pitch, voiced)
		if not tone.Parent then
			return
		end
		tone.PlaybackSpeed = semitonesToSpeed(pitch or 0)
		tone.Volume = voiced and 0.4 or 0
	end

	function monitor:close()
		if tone.Parent then
			tone:Stop()
			tone:Destroy()
		end
	end

	return monitor
end

local uiCache = {}
function AudioEngine.ui(assetId, volume)
	local s = uiCache[assetId]
	if not s or not s.Parent then
		s = Instance.new("Sound")
		s.SoundId = assetId
		s.Volume = volume or 0.3
		s.Parent = SoundService
		uiCache[assetId] = s
	end
	s.TimePosition = 0
	s:Play()
end

function AudioEngine.click()
	AudioEngine.ui(Config.AUDIO.UI_CLICK, 0.22)
end

function AudioEngine.confirm()
	AudioEngine.ui(Config.AUDIO.UI_CONFIRM, 0.28)
end

function AudioEngine.tick()
	AudioEngine.ui(Config.AUDIO.COUNT_TICK, 0.3)
end

function AudioEngine.applause()
	AudioEngine.ui(Config.AUDIO.APPLAUSE, 0.35)
end

return AudioEngine

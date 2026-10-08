--!nonstrict
-- Config.luau — single source of truth for every tunable in Mimic Party.
-- Nothing else in the codebase hardcodes a number that belongs here.

local Config = {}

-- ─── Match shape ──────────────────────────────────────────────────────────────
Config.MIN_PLAYERS = 2
Config.MAX_PLAYERS = 5
Config.ROUNDS_PER_PARTY = 4

-- ─── Phase durations (seconds) ────────────────────────────────────────────────
Config.PHASE = {
	LOBBY_COUNTDOWN = 20,  -- shortens to QUICK_START once the room is full
	QUICK_START = 6,
	PROCESSION = 7.5,      -- players walk from the house to their marks
	ROUND_INTRO = 2.6,
	REFERENCE_PAD = 1.1,   -- breathing room before/after the reference plays
	COUNT_IN = 3,          -- 3 · 2 · 1 · GO
	TAKE_TAIL = 0.45,      -- grace after the take window closes
	PLAYBACK_GAP = 1.5,    -- reaction window between takes
	ROULETTE_SPIN = 4.2,
	SABOTAGE_PICK = 7,
	RESULTS = 11,
}

-- ─── Rooms ────────────────────────────────────────────────────────────────────
-- A private room is a reserved server of this same place. The host creates one,
-- gets a code, and anyone who types that code is teleported into it. The host
-- owns the sound packs and can remove players; nothing else.
Config.ROOM = {
	-- How long a freshly created room waits for people before the host is told
	-- nobody came. Does not kick anyone; it is only a nudge.
	LONELY_AFTER = 120,
	MAX_CREATE_ATTEMPTS = 6,    -- code-collision retries before giving up
	JOIN_COOLDOWN = 3,          -- per player, seconds between join attempts
	CREATE_COOLDOWN = 10,       -- per player, seconds between room creations
	-- A host who leaves hands the room to whoever has been there longest, so a
	-- room does not become unmanageable because one person's wifi died.
	INHERIT_HOST = true,
}

-- ─── Voice chat ───────────────────────────────────────────────────────────────
-- Voice is the point of this game, so the graph is explicit rather than left to
-- the engine's defaults:
--
--   AudioDeviceInput (per player, .Player = them)
--        └─ Wire ─→ AudioEmitter (on their head)
--                        └─ heard by AudioListener (SoundService.ListenerLocation)
--                                 └─ AudioDeviceOutput (engine-provided)
--
-- Owning the wires is what makes the rest possible: muting the table during
-- playback is a real mute on a real input, not a label.
Config.VOICE_CHAT = {
	-- Volume over distance, in studs. The house is ~45 studs deep, so a voice on
	-- stage has to carry to the back row without the five performers turning
	-- into mud when they are all talking at once.
	ATTENUATION = {
		{ 0, 1 },
		{ 18, 0.92 },
		{ 40, 0.68 },
		{ 70, 0.34 },
		{ 100, 0 },
	},
	INPUT_VOLUME = 1,
	-- Set false to let the engine's default voice routing stand untouched.
	CUSTOM_ROUTING = true,
}

-- ─── Input ────────────────────────────────────────────────────────────────────
-- Three ways to perform a take, picked per player at record time:
--   "voice"      real microphone drives loudness/attacks/rhythm, pointer height
--                drives pitch (the melody axis). The default when voice works.
--   "voice_only" real microphone drives everything; melody is dropped and its
--                weight is redistributed. For players who will not touch a mouse.
--   "pointer"    no microphone available: hold to vocalise, as before.
Config.INPUT = {
	DEFAULT = "voice",
	FALLBACK = "pointer",
}

-- ─── Microphone ───────────────────────────────────────────────────────────────
-- Roblox exposes RmsLevel/PeakLevel on a live AudioDeviceInput (client only),
-- but GetSpectrum() is blocked for microphone inputs, so there is no pitch to
-- read. Everything below is about turning a loudness stream into clean onsets.
Config.VOICE = {
	-- The noise floor is measured during the count-in, per player, per take, so
	-- a loud room or a hot mic calibrates itself instead of needing a setting.
	CALIBRATE_FOR = 2.0,
	FLOOR_MIN = 0.0035,       -- never trust a floor quieter than this
	FLOOR_HEADROOM = 1.35,    -- measured floor is scaled by this before gating

	-- Hysteresis: opening and closing on the same threshold chatters badly on
	-- a breathy voice, so the gate opens high and closes low.
	GATE_OPEN = 3.1,          -- × floor
	GATE_CLOSE = 1.7,         -- × floor

	-- These two are set against the library, not by feel. The tightest gap in
	-- SoundLibrary is 90 ms (nothing shorter is articulable by a human voice or
	-- visible to a 60 fps sampler), so:
	--   BRIDGE_GAP  must be comfortably under 90 ms, or a fast pattern collapses
	--               into one attack and the attacks axis — a quarter of the
	--               score — reads zero.
	--   BRIDGE_GAP  must be over ~2 frames (33 ms), or a breathy voice chatters
	--               the gate and one word counts as four.
	-- 40 ms sits in that window with 50 ms of margin on the library side.
	REFRACTORY = 0.05,
	BRIDGE_GAP = 0.04,

	-- RmsLevel is roughly 0..1 but a shout sits far below 1, so the envelope is
	-- normalised against a running peak for the drawing and the level meter.
	LEVEL_CEILING_MIN = 0.05,
	LEVEL_DECAY = 0.75,       -- per second, how fast the running peak falls back
}

-- ─── Recording ────────────────────────────────────────────────────────────────
Config.TAKE = {
	-- One shot. No retries, no undo. This flag exists to be read, never flipped.
	ALLOW_RETRY = false,
	PITCH_RANGE = 9,       -- ± semitones the player can reach with the mouse
	MIN_NOTE = 0.05,       -- shorter than this is a click, not an attack
	MAX_NOTES = 48,
	ENVELOPE_SAMPLES = 96, -- waveform resolution
}

-- ─── Scoring ──────────────────────────────────────────────────────────────────
-- Faithful to the original: melody, rhythm and attacks. Never timbre, never
-- absolute pitch — contours are mean-normalised so registers score equally.
Config.SCORING = {
	WEIGHT_MELODY = 0.40,
	WEIGHT_RHYTHM = 0.35,
	WEIGHT_ATTACKS = 0.25,
	MELODY_SAMPLES = 64,
	MELODY_TOLERANCE = 7.0,  -- semitones of contour error that zeroes the axis
	RHYTHM_TOLERANCE = 0.35, -- seconds of onset error that zeroes the axis
	MAX_SCORE = 1000,
}

-- When a player performs without pitch control ("voice_only"), the melody axis
-- has nothing to measure, so it is dropped and its weight is split between the
-- two axes their voice does drive. Scoring renormalises; totals stay comparable.
Config.SCORING_VOICE_ONLY = {
	WEIGHT_MELODY = 0,
	WEIGHT_RHYTHM = 0.58,
	WEIGHT_ATTACKS = 0.42,
}

-- ─── Roulette ─────────────────────────────────────────────────────────────────
Config.ROULETTE = {
	SABOTAGE_POINT_PENALTY = 120,
	MULTIPLIER_DECAY = 1,    -- multipliers last this many rounds
}

-- ─── Solo modes ───────────────────────────────────────────────────────────────
Config.SURVIVAL = { SOUNDS = 50, LIVES = 3, TARGET_START = 300, TARGET_STEP = 25, TARGET_CAP = 720 }
Config.JUST_PLAY = { ROUNDS = 3 }
Config.DAILY = { SOUNDS = 4 }

-- ─── Presentation ─────────────────────────────────────────────────────────────
Config.STAGE_MARKS = 5
Config.CAMERA_FOV = { HOUSE = 58, WIDE = 52, BOOTH = 36, ROULETTE = 44, CLOSE = 30 }

-- ─── Audio assets ─────────────────────────────────────────────────────────────
-- Every sound in the library runs through a synthesised fallback voice, so the
-- game is fully playable with zero uploads. Drop your own ids here to replace it.
Config.AUDIO = {
	-- A sustained, pitch-neutral tone. The engine pitch-shifts it per note.
	VOICE_TONE = "rbxassetid://9112854440",
	UI_CLICK = "rbxassetid://6042053626",
	UI_CONFIRM = "rbxassetid://6042583426",
	COUNT_TICK = "rbxassetid://9118823101",
	WHEEL_TICK = "rbxassetid://9118823101",
	-- The sabotage that replaces a whole take. Yes, that one.
	SWAP_SFX = "rbxassetid://5338534197",
	APPLAUSE = "rbxassetid://9125573137",
}

return Config

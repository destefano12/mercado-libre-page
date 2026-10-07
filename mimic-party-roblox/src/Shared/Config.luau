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

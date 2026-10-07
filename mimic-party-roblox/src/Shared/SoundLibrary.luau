--!nonstrict
-- SoundLibrary.luau — the reference sounds, authored as pitch/time patterns.
--
-- A reference is not a waveform here: it is a *contour*. Each note is
-- { t = onset seconds, dur = length seconds, pitch = semitones from centre }.
-- The audio engine renders it through one sustained tone, so the whole library
-- plays with no uploaded assets; set `asset` on any entry to use real audio
-- instead and the pattern keeps driving the scoring and the waveform.

local Config = require(script.Parent.Config)

local SoundLibrary = {}

local packs = {}
local byId = {}

local function pack(id, name, blurb, entries)
	local p = { id = id, name = name, blurb = blurb, sounds = {} }
	for _, e in ipairs(entries) do
		local notes = {}
		local duration = 0
		for _, n in ipairs(e[4]) do
			local note = { t = n[1], dur = n[2], pitch = n[3] }
			table.insert(notes, note)
			duration = math.max(duration, note.t + note.dur)
		end
		local sound = {
			id = e[1],
			name = e[2],
			difficulty = e[3],     -- 1 easy · 2 medium · 3 hard
			notes = notes,
			duration = duration + 0.12,
			pack = id,
			asset = e[5],
		}
		table.insert(p.sounds, sound)
		byId[sound.id] = sound
	end
	table.insert(packs, p)
	return p
end

-- ── Reaction Studio ──────────────────────────────────────────────────────────
pack("reaction", "Reaction Studio", "Meme reflexes. Short, sharp, merciless.", {
	{ "nice",      "Nice",                1, { {0,0.30,2}, {0.34,0.44,-2} } },
	{ "bruh",      "Bruh",                1, { {0,0.62,-4} } },
	{ "hello",     "Hello There",         2, { {0,0.26,0}, {0.28,0.22,3}, {0.56,0.50,-1} } },
	{ "yeet",      "Yeet",                1, { {0,0.18,-2}, {0.19,0.34,7} } },
	{ "wow",       "Wow",                 1, { {0,0.50,-1}, {0.52,0.40,4} } },
	{ "bababooey", "Bababooey",           3, { {0,0.16,0}, {0.18,0.16,0}, {0.36,0.16,2}, {0.54,0.18,2}, {0.74,0.42,-3} } },
	{ "damage",    "Emotional Damage",    3, { {0,0.22,4}, {0.24,0.20,4}, {0.46,0.26,6}, {0.74,0.46,1} } },
	{ "running",   "Why Are You Running", 3, { {0,0.20,1}, {0.22,0.18,3}, {0.42,0.18,1}, {0.62,0.20,3}, {0.84,0.44,-2} } },
	{ "getout",    "Get Out",             2, { {0,0.30,5}, {0.34,0.54,-4} } },
})

-- ── Wild Voices ──────────────────────────────────────────────────────────────
pack("wild", "Wild Voices", "Animals. The pack that breaks dignity first.", {
	{ "catchirp",  "Cat Chirp",       2, { {0,0.14,6}, {0.16,0.12,9}, {0.30,0.18,4} } },
	{ "sneeze",    "Puppy Sneeze",    1, { {0,0.10,2}, {0.12,0.30,-5} } },
	{ "owl",       "Night Owl",       1, { {0,0.44,-2}, {0.60,0.52,-5} } },
	{ "seal",      "Seal Bark",       2, { {0,0.18,-3}, {0.26,0.18,-3}, {0.52,0.22,-5} } },
	{ "bigbird",   "Big Bird",        2, { {0,0.26,8}, {0.30,0.22,5}, {0.56,0.30,8} } },
	{ "hohoho",    "Ho Ho Ho",        1, { {0,0.24,-6}, {0.30,0.24,-6}, {0.60,0.38,-7} } },
	{ "sheep",     "Screaming Sheep", 3, { {0,0.30,3}, {0.32,0.16,8}, {0.50,0.60,5} } },
	{ "peacock",   "Peacock Call",    3, { {0,0.22,7}, {0.26,0.26,2}, {0.56,0.22,7}, {0.82,0.34,1} } },
	{ "frogs",     "Frog Chorus",     3, { {0,0.14,-4}, {0.22,0.14,-4}, {0.44,0.14,-2}, {0.62,0.14,-4}, {0.84,0.14,-6}, {1.02,0.22,-4} } },
})

-- ── Rhythm Lab ───────────────────────────────────────────────────────────────
pack("rhythm", "Rhythm Lab", "Machines. Timing is the whole grade here.", {
	{ "radiobeep", "Radio Beep",      1, { {0,0.16,4}, {0.32,0.16,4}, {0.64,0.30,4} } },
	{ "notif",     "Notification",    1, { {0,0.18,2}, {0.22,0.30,7} } },
	{ "errchime",  "Error Chime",     2, { {0,0.22,0}, {0.26,0.22,-5}, {0.52,0.34,-5} } },
	{ "doorbell",  "Doorbell Dance",  2, { {0,0.26,5}, {0.30,0.38,0}, {0.72,0.26,5}, {1.02,0.38,0} } },
	{ "badumtss",  "Ba Dum Tss",      1, { {0,0.16,-4}, {0.24,0.16,-2}, {0.48,0.34,6} } },
	{ "printer",   "Printer Rhythm",  3, { {0,0.10,0}, {0.14,0.10,0}, {0.28,0.10,2}, {0.42,0.10,0}, {0.56,0.10,2}, {0.70,0.26,-2} } },
	{ "beatbox",   "Beatbox Fill",    3, { {0,0.12,-6}, {0.18,0.10,4}, {0.32,0.12,-6}, {0.46,0.10,4}, {0.58,0.10,4}, {0.74,0.24,-6} } },
	{ "dialup",    "Dial-Up Song",    3, { {0,0.22,3}, {0.26,0.18,-2}, {0.48,0.30,6}, {0.82,0.44,-4}, {1.30,0.52,1} } },
	{ "glitch",    "Computer Glitch", 3, { {0,0.08,8}, {0.10,0.08,-6}, {0.22,0.08,8}, {0.32,0.08,-6}, {0.42,0.20,2} } },
})

-- ── Melody Club ──────────────────────────────────────────────────────────────
pack("melody", "Melody Club", "Longer lines. Contour carries the score.", {
	{ "slowmel",   "Slow Melody",     1, { {0,0.50,0}, {0.56,0.50,4}, {1.12,0.70,2} } },
	{ "kazoo",     "Kazoo Fanfare",   2, { {0,0.26,0}, {0.30,0.26,4}, {0.60,0.26,7}, {0.90,0.58,9} } },
	{ "synth",     "Synth Steps",     2, { {0,0.24,0}, {0.28,0.24,2}, {0.56,0.24,4}, {0.84,0.24,5}, {1.12,0.40,7} } },
	{ "dancehook", "Dance Hook",      3, { {0,0.22,7}, {0.26,0.22,5}, {0.52,0.22,2}, {0.78,0.22,5}, {1.04,0.46,0} } },
	{ "retro",     "Retro Chorus",    3, { {0,0.30,2}, {0.34,0.30,5}, {0.68,0.30,9}, {1.02,0.30,5}, {1.36,0.56,2} } },
	{ "blues",     "Blues Riff",      3, { {0,0.26,0}, {0.30,0.20,3}, {0.54,0.26,-2}, {0.84,0.20,3}, {1.08,0.52,-5} } },
	{ "heyya",     "Hey Ya",          2, { {0,0.28,4}, {0.32,0.24,4}, {0.60,0.34,-1}, {0.98,0.46,2} } },
	{ "opera",     "Opera Moment",    3, { {0,0.62,-3}, {0.68,0.46,4}, {1.18,0.40,9}, {1.62,0.90,7} } },
	{ "comeback",  "Comeback Hook",   3, { {0,0.20,-5}, {0.24,0.20,0}, {0.48,0.20,4}, {0.72,0.20,7}, {0.96,0.24,9}, {1.24,0.62,4} } },
})

function SoundLibrary.packs()
	return packs
end

function SoundLibrary.get(id)
	return byId[id]
end

function SoundLibrary.all()
	local out = {}
	for _, p in ipairs(packs) do
		for _, s in ipairs(p.sounds) do
			table.insert(out, s)
		end
	end
	return out
end

-- A deterministic shuffle so every client in a room can derive the same order
-- from a single seed the server sends, instead of replicating whole playlists.
function SoundLibrary.playlist(seed, count, packFilter)
	local pool = {}
	for _, p in ipairs(packs) do
		if not packFilter or packFilter == p.id then
			for _, s in ipairs(p.sounds) do
				table.insert(pool, s)
			end
		end
	end
	local rng = Random.new(seed)
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local out = {}
	for i = 1, math.min(count, #pool) do
		out[i] = pool[i]
	end
	-- Survival asks for more sounds than the library holds: wrap, reshuffling.
	while #out < count do
		local extra = SoundLibrary.playlist(seed + #out, math.min(count - #out, #pool), packFilter)
		for _, s in ipairs(extra) do
			table.insert(out, s)
		end
	end
	return out
end

-- Envelope used by both the waveform renderer and the audio engine.
function SoundLibrary.envelope(notes, duration, samples)
	samples = samples or Config.TAKE.ENVELOPE_SAMPLES
	local out = table.create(samples, 0)
	for i = 1, samples do
		local t = (i - 0.5) / samples * duration
		for _, n in ipairs(notes) do
			if t >= n.t and t <= n.t + n.dur then
				-- Soft attack, soft release: reads as a voice, not a square gate.
				local local_t = (t - n.t) / math.max(n.dur, 1e-3)
				local shape = math.min(1, local_t / 0.18) * math.min(1, (1 - local_t) / 0.22 + 0.35)
				out[i] = math.clamp(0.35 + 0.65 * shape, 0, 1)
				break
			end
		end
	end
	return out
end

return SoundLibrary

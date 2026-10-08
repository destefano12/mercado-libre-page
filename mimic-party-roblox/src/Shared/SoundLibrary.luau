--!nonstrict
-- SoundLibrary.luau — the reference sounds.
--
-- Two things define an entry:
--
--   notes    the contour, as { t = onset, dur = length, pitch = semitones }.
--            This drives the scoring and both waveforms, always, in every mode.
--   search   keywords handed to Roblox's own audio library at boot
--            (AssetService:SearchAudioAsync). Whatever comes back is what you
--            actually hear.
--
-- No name here is a meme, a song title or a catchphrase, and no audio file is
-- bundled: the audio is Roblox's, pulled from Roblox's library at runtime, and
-- preference is given to assets Roblox marks as endorsed. If a search returns
-- nothing playable, the contour is rendered through a synthesised tone instead,
-- so a missing asset degrades the sound and never breaks the round.
--
-- To pin an exact asset, set `asset = "rbxassetid://…"` on the entry: the search
-- is skipped and the contour keeps doing everything else.

local Config = require(script.Parent.Config)

local SoundLibrary = {}

local packs = {}
local byId = {}

local function pack(id, name, blurb, entries)
	local p = { id = id, name = name, blurb = blurb, sounds = {} }
	for _, e in ipairs(entries) do
		local notes = {}
		local duration = 0
		for _, n in ipairs(e.notes) do
			local note = { t = n[1], dur = n[2], pitch = n[3] }
			table.insert(notes, note)
			duration = math.max(duration, note.t + note.dur)
		end
		local sound = {
			id = e.id,
			name = e.name,
			difficulty = e.difficulty,     -- 1 easy · 2 medium · 3 hard
			notes = notes,
			duration = duration + 0.12,
			pack = id,
			search = e.search,             -- keywords for the Roblox audio library
			asset = e.asset,               -- set to pin an exact asset
		}
		table.insert(p.sounds, sound)
		byId[sound.id] = sound
	end
	table.insert(packs, p)
	return p
end

-- ── Voces ────────────────────────────────────────────────────────────────────
-- Short vocal shapes. Named for what the contour does, not for any catchphrase.
pack("voces", "Voces", "Formas vocales cortas. Afilado y sin piedad.", {
	{ id = "dosnotas",  name = "Dos Notas",      difficulty = 1, search = { "voice up down", "human voice short" },
	  notes = { {0,0.3,2}, {0.39,0.44,-2} } },
	{ id = "gravelargo", name = "Grave Largo",   difficulty = 1, search = { "deep voice groan", "male voice low" },
	  notes = { {0,0.62,-4} } },
	{ id = "saludo",    name = "Saludo",         difficulty = 2, search = { "voice greeting", "person talking short" },
	  notes = { {0,0.26,0}, {0.35,0.22,3}, {0.66,0.5,-1} } },
	{ id = "latigazo",  name = "Latigazo",       difficulty = 1, search = { "whoosh voice", "swoosh up" },
	  notes = { {0,0.18,-2}, {0.27,0.34,7} } },
	{ id = "asombro",   name = "Asombro",        difficulty = 1, search = { "crowd gasp", "surprise voice" },
	  notes = { {0,0.5,-1}, {0.59,0.4,4} } },
	{ id = "cincogolpes", name = "Cinco Golpes", difficulty = 3, search = { "voice stutter", "chatter short" },
	  notes = { {0,0.16,0}, {0.25,0.16,0}, {0.5,0.16,2}, {0.75,0.18,2}, {1.02,0.42,-3} } },
	{ id = "reproche",  name = "Reproche",       difficulty = 3, search = { "angry voice short", "scold" },
	  notes = { {0,0.22,4}, {0.31,0.2,4}, {0.6,0.26,6}, {0.95,0.46,1} } },
	{ id = "pregunta",  name = "Pregunta",       difficulty = 3, search = { "questioning voice", "voice rising" },
	  notes = { {0,0.2,1}, {0.29,0.18,3}, {0.56,0.18,1}, {0.83,0.2,3}, {1.12,0.44,-2} } },
	{ id = "portazo",   name = "Portazo",        difficulty = 2, search = { "shout down", "voice command" },
	  notes = { {0,0.3,5}, {0.39,0.54,-4} } },
})

-- ── Animales ─────────────────────────────────────────────────────────────────
pack("animales", "Animales", "El paquete que te quita la dignidad primero.", {
	{ id = "gato",     name = "Gato",            difficulty = 2, search = { "cat meow", "kitten" },
	  notes = { {0,0.14,6}, {0.23,0.12,9}, {0.44,0.18,4} } },
	{ id = "estornudo", name = "Estornudo",      difficulty = 1, search = { "dog sneeze", "sneeze" },
	  notes = { {0,0.1,2}, {0.19,0.3,-5} } },
	{ id = "buho",     name = "Búho",            difficulty = 1, search = { "owl hoot", "owl night" },
	  notes = { {0,0.44,-2}, {0.6,0.52,-5} } },
	{ id = "foca",     name = "Foca",            difficulty = 2, search = { "seal bark", "sea lion" },
	  notes = { {0,0.18,-3}, {0.27,0.18,-3}, {0.54,0.22,-5} } },
	{ id = "pajaro",   name = "Pájaro Grande",   difficulty = 2, search = { "large bird call", "squawk" },
	  notes = { {0,0.26,8}, {0.35,0.22,5}, {0.66,0.3,8} } },
	{ id = "risagrave", name = "Risa Grave",     difficulty = 1, search = { "deep laugh", "belly laugh" },
	  notes = { {0,0.24,-6}, {0.33,0.24,-6}, {0.66,0.38,-7} } },
	{ id = "oveja",    name = "Oveja",           difficulty = 3, search = { "sheep bleat", "goat" },
	  notes = { {0,0.3,3}, {0.39,0.16,8}, {0.64,0.6,5} } },
	{ id = "pavoreal", name = "Pavo Real",       difficulty = 3, search = { "peacock call", "exotic bird" },
	  notes = { {0,0.22,7}, {0.31,0.26,2}, {0.66,0.22,7}, {0.97,0.34,1} } },
	{ id = "ranas",    name = "Coro de Ranas",   difficulty = 3, search = { "frog croak", "frogs pond" },
	  notes = { {0,0.14,-4}, {0.23,0.14,-4}, {0.46,0.14,-2}, {0.69,0.14,-4}, {0.92,0.14,-6}, {1.15,0.22,-4} } },
})

-- ── Máquinas ─────────────────────────────────────────────────────────────────
pack("maquinas", "Máquinas", "Acá el ritmo es toda la nota.", {
	{ id = "pitido",   name = "Pitido Triple",   difficulty = 1, search = { "radio beep", "beep beep" },
	  notes = { {0,0.16,4}, {0.32,0.16,4}, {0.64,0.3,4} } },
	{ id = "aviso",    name = "Aviso",           difficulty = 1, search = { "notification", "ui ding" },
	  notes = { {0,0.18,2}, {0.27,0.3,7} } },
	{ id = "error",    name = "Error",           difficulty = 2, search = { "error sound", "buzzer wrong" },
	  notes = { {0,0.22,0}, {0.31,0.22,-5}, {0.62,0.34,-5} } },
	{ id = "timbre",   name = "Timbre",          difficulty = 2, search = { "doorbell", "door chime" },
	  notes = { {0,0.26,5}, {0.35,0.38,0}, {0.82,0.26,5}, {1.17,0.38,0} } },
	{ id = "remate",   name = "Remate",          difficulty = 1, search = { "drum rimshot", "comedy drum" },
	  notes = { {0,0.16,-4}, {0.25,0.16,-2}, {0.5,0.34,6} } },
	{ id = "impresora", name = "Impresora",      difficulty = 3, search = { "printer", "dot matrix" },
	  notes = { {0,0.1,0}, {0.19,0.1,0}, {0.38,0.1,2}, {0.57,0.1,0}, {0.76,0.1,2}, {0.95,0.26,-2} } },
	{ id = "percusion", name = "Percusión",      difficulty = 3, search = { "drum fill", "percussion loop" },
	  notes = { {0,0.12,-6}, {0.21,0.1,4}, {0.4,0.12,-6}, {0.61,0.1,4}, {0.8,0.1,4}, {0.99,0.24,-6} } },
	{ id = "modem",    name = "Módem",           difficulty = 3, search = { "dial up modem", "fax" },
	  notes = { {0,0.22,3}, {0.31,0.18,-2}, {0.58,0.3,6}, {0.97,0.44,-4}, {1.5,0.52,1} } },
	{ id = "glitch",   name = "Glitch",          difficulty = 3, search = { "glitch", "digital error" },
	  notes = { {0,0.1,8}, {0.19,0.1,-6}, {0.38,0.1,8}, {0.57,0.1,-6}, {0.76,0.2,2} } },
})

-- ── Melodías ─────────────────────────────────────────────────────────────────
pack("melodias", "Melodías", "Líneas más largas. El contorno lleva el puntaje.", {
	{ id = "lenta",    name = "Lenta",           difficulty = 1, search = { "simple melody", "soft chime melody" },
	  notes = { {0,0.5,0}, {0.59,0.5,4}, {1.18,0.7,2} } },
	{ id = "fanfarria", name = "Fanfarria",      difficulty = 2, search = { "fanfare", "trumpet short" },
	  notes = { {0,0.26,0}, {0.35,0.26,4}, {0.7,0.26,7}, {1.05,0.58,9} } },
	{ id = "escalera", name = "Escalera",        difficulty = 2, search = { "synth arpeggio up", "scale up" },
	  notes = { {0,0.24,0}, {0.33,0.24,2}, {0.66,0.24,4}, {0.99,0.24,5}, {1.32,0.4,7} } },
	{ id = "gancho",   name = "Gancho",          difficulty = 3, search = { "dance hook", "electronic riff" },
	  notes = { {0,0.22,7}, {0.31,0.22,5}, {0.62,0.22,2}, {0.93,0.22,5}, {1.24,0.46,0} } },
	{ id = "retro",    name = "Retro",           difficulty = 3, search = { "chiptune melody", "8 bit tune" },
	  notes = { {0,0.3,2}, {0.39,0.3,5}, {0.78,0.3,9}, {1.17,0.3,5}, {1.56,0.56,2} } },
	{ id = "blues",    name = "Blues",           difficulty = 3, search = { "blues guitar riff", "blues lick" },
	  notes = { {0,0.26,0}, {0.35,0.2,3}, {0.64,0.26,-2}, {0.99,0.2,3}, {1.28,0.52,-5} } },
	{ id = "vaiven",   name = "Vaivén",          difficulty = 2, search = { "two note melody", "simple riff" },
	  notes = { {0,0.28,4}, {0.37,0.24,4}, {0.7,0.34,-1}, {1.13,0.46,2} } },
	{ id = "opera",    name = "Ópera",           difficulty = 3, search = { "opera singing", "soprano" },
	  notes = { {0,0.62,-3}, {0.71,0.46,4}, {1.26,0.4,9}, {1.75,0.9,7} } },
	{ id = "remontada", name = "Remontada",      difficulty = 3, search = { "rising melody", "build up melody" },
	  notes = { {0,0.2,-5}, {0.29,0.2,0}, {0.58,0.2,4}, {0.87,0.2,7}, {1.16,0.24,9}, {1.49,0.62,4} } },
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
--
-- `enabled` is either nil (every pack), a pack id, or a set { [packId] = true }
-- — which is what a host's pack toggles produce. A set that turns everything
-- off falls back to every pack rather than producing an empty match.
function SoundLibrary.playlist(seed, count, enabled)
	local function allows(packId)
		if enabled == nil then
			return true
		end
		if type(enabled) == "string" then
			return enabled == packId
		end
		if type(enabled) == "table" then
			return enabled[packId] == true
		end
		return true
	end

	local pool = {}
	for _, p in ipairs(packs) do
		if allows(p.id) then
			for _, s in ipairs(p.sounds) do
				table.insert(pool, s)
			end
		end
	end

	-- Every pack off, or a filter that matched nothing: use the whole library.
	if #pool == 0 then
		for _, p in ipairs(packs) do
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
		local extra = SoundLibrary.playlist(seed + #out, math.min(count - #out, #pool), enabled)
		for _, s in ipairs(extra) do
			table.insert(out, s)
		end
	end
	return out
end

-- Envelope used by the waveform renderer and by the synthesised fallback voice.
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

--!nonstrict
-- Modes.luau — every way to play, in one table.
-- Party runs on the server state machine; the four solo modes run client-side
-- against the same Scoring module, so a solo score and a party score mean
-- exactly the same thing.

local Config = require(script.Parent.Config)

return {
	{
		id = "party",
		name = "Fiesta",
		players = "2–5 · online",
		blurb = "Cuatro rondas. Todos graban a la vez, una sola toma, y la ruleta decide el resto.",
		solo = false,
		rounds = Config.ROUNDS_PER_PARTY,
	},
	{
		id = "passthemic",
		name = "Pasá el Micro",
		players = "2–5 · un dispositivo",
		blurb = "Por turnos en la misma pantalla. Cuatro rondas, resultados locales.",
		solo = true,
		rounds = 4,
		local_turns = true,
	},
	{
		id = "survival",
		name = "Supervivencia",
		players = "1 jugador",
		blurb = ("%d sonidos, %d vidas, y el objetivo sube cada ronda."):format(
			Config.SURVIVAL.SOUNDS, Config.SURVIVAL.LIVES),
		solo = true,
		rounds = Config.SURVIVAL.SOUNDS,
	},
	{
		id = "justplay",
		name = "Suelto",
		players = "1 jugador",
		blurb = "Tres rondas rápidas con ruleta de bonus y rutas: segura, arriesgada o enfocada.",
		solo = true,
		rounds = Config.JUST_PLAY.ROUNDS,
		routes = {
			{ id = "safe",    name = "Segura",    blurb = "Puntaje tal cual.",                     mult = 1.0 },
			{ id = "risky",   name = "Arriesgada", blurb = "×2, pero por debajo de 500 no cuenta.", mult = 2.0, floor = 500 },
			{ id = "focused", name = "Enfocada",  blurb = "Solo melodía, ×1.5.",                    mult = 1.5, axis = "melody" },
		},
	},
	{
		id = "daily",
		name = "Racha Diaria",
		players = "1 jugador",
		blurb = ("%d sonidos iguales para todo el mundo. Se reinicia a las 00:00 UTC."):format(Config.DAILY.SOUNDS),
		solo = true,
		rounds = Config.DAILY.SOUNDS,
		daily = true,
	},
}

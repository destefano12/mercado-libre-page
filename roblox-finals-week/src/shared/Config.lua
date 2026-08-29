--!strict
--[[
	Config
	------------------------------------------------------------------
	Todo lo que se toca sin abrir el resto del codigo vive aca.
	Cada seccion es un `Config.X = { ... }` y las claves de primer
	nivel llevan UN tab: tools/check.py las lee asi para verificar que
	nadie escriba una clave que no existe.
--]]

local Config = {}

-- ── Instituto ──────────────────────────────────────────────────────
-- El mapa se arma por codigo y es modular: un pasillo central con
-- casilleros a los dos lados y N aulas colgadas del pasillo.
Config.Escuela = {
	Origen = Vector3.new(0, 0, 0),
	PasilloLargo = 190,
	PasilloAncho = 26,
	AlturaPiso = 15,
	EspesorPared = 1,
	CasillerosPorLado = 18,
	CasilleroAncho = 3.4,
	CasilleroAlto = 7,
	CasilleroFondo = 2.2,
	Aulas = 2,
	AulaAncho = 46,
	AulaLargo = 40,
	FilasDePupitres = 4,
	PupitresPorFila = 5,
	PupitreSeparacionX = 7.2,
	PupitreSeparacionZ = 7.6,
	ZonaRecreoLargo = 34,
	SalaDeCastigo = Vector3.new(150, 0, -80),
	ColorPiso = Color3.fromRGB(196, 192, 182),
	ColorParedes = Color3.fromRGB(222, 219, 210),
	ColorZocalo = Color3.fromRGB(64, 76, 92),
	ColorCasillero = Color3.fromRGB(52, 92, 128),
	ColorPizarra = Color3.fromRGB(34, 52, 44),
}

-- ── Ciclo escolar ──────────────────────────────────────────────────
-- Un "dia" = recreo + examen + boletin. Cinco dias = Semana Final.
Config.Ronda = {
	DiasPorSemana = 5,
	SegundosRecreo = 55,
	SegundosExamen = 165,
	SegundosBoletin = 22,
	SegundosIntermedio = 6,
	MinimoJugadores = 1,
	AvisoCampana = 10,
	NombreDias = { "lunes", "martes", "miercoles", "jueves", "viernes" },
	CurvaDificultad = { 1.0, 1.15, 1.35, 1.6, 2.0 },
	SuspensosParaExpulsion = 3,
}

-- ── Examen ─────────────────────────────────────────────────────────
Config.Examen = {
	PreguntasBase = 8,
	PreguntasPorDia = 2,
	MaximoPreguntas = 18,
	PuntosPorAcierto = 10,
	PuntosPorError = -4,
	PuntosSinResponder = -2,
	ProbabilidadEscritura = 0.3,
	LargoSecuencia = NumberRange.new(4, 7),
	SegundosSecuencia = 6,
	OpcionesPorPregunta = 4,
	CopiarSegundos = 1.8,
	CopiarAcierto = 0.72,
	CopiarAlcance = 11,
}

-- ── Profesor (IA del servidor) ─────────────────────────────────────
Config.Profesor = {
	VelocidadPatrulla = 7,
	VelocidadPersecucion = 19,
	AlturaOjos = 1.6,
	AnguloVision = 62,
	DistanciaVision = 34,
	DistanciaCercania = 12,
	PausaEnFila = NumberRange.new(1.6, 3.4),
	PausaEnPizarra = NumberRange.new(4, 8),
	ProbabilidadPizarra = 0.28,
	IntervaloRepensar = 0.35,
	NombresPosibles = { "Sr. Vidal", "Sra. Ferrer", "Sr. Kovacs", "Sra. Nieto", "Sr. Aldana" },
	ColorTraje = Color3.fromRGB(38, 42, 54),
	ColorCamisa = Color3.fromRGB(232, 234, 240),
	ColorCorbata = Color3.fromRGB(122, 32, 44),
	ColorPiel = Color3.fromRGB(215, 176, 140),
	RadioAlerta = 26,
}

-- ── Sospecha ───────────────────────────────────────────────────────
-- Es por jugador, de 0 a 1. Sube por infracciones vistas y baja sola.
Config.Sospecha = {
	Decaimiento = 0.055,
	DecaimientoFueraDeVista = 0.09,
	PorLevantarse = 0.42,
	PorLanzar = 0.5,
	PorEspiar = 0.30,
	PorChuleta = 0.26,
	PorSoplar = 0.2,
	PorCorrerEnExamen = 0.18,
	PorSegundoEnMira = 0.06,
	Umbral = 1.0,
	UmbralAviso = 0.55,
	MultiplicadorDistancia = 1.6,
}

-- ── Castigos ───────────────────────────────────────────────────────
Config.Castigo = {
	SegundosCono = 18,
	PenalizacionNota = 22,
	SegundosExpulsion = 20,
	InfraccionesParaExpulsion = 2,
	SegundosInmunidad = 3,
	VelocidadReducida = 9,
}

-- ── Objetos y trampas ──────────────────────────────────────────────
Config.Objetos = {
	VelocidadLanzamiento = 76,
	GravedadProyectil = 0.55,
	VidaProyectil = 12,
	AlcanceRecoger = 9,
	EnfriamientoLanzar = 1.2,
	ChuletaRevela = 3,
	ChuletaUsos = 2,
	SoplarAlcance = 14,
	SoplarEnfriamiento = 8,
	NotaCaracteres = 60,
	AvionMultiplicador = 1.45,
	BolitaRuido = 1,
	CasilleroEnfriamiento = 25,
}

-- ── Notas / calificaciones ─────────────────────────────────────────
Config.Notas = {
	Inicial = 60,
	Minima = 0,
	Maxima = 100,
	Aprobado = 60,
	Escala = { { 90, "A" }, { 80, "B" }, { 70, "C" }, { 60, "D" }, { 0, "F" } },
	PesoExamen = 0.75,
	PesoConducta = 0.25,
}

-- ── Economia y guardado ────────────────────────────────────────────
Config.Economia = {
	ClaveDataStore = "FinalsWeek_Alumnos_v1",
	CreditosPorAcierto = 4,
	CreditosPorAprobar = 45,
	CreditosPorSemana = 120,
	CreditosSinCastigos = 30,
	GuardadoAutomatico = 90,
	Tienda = {
		{ id = "chuleta", precio = 40, tipo = "objeto" },
		{ id = "avion", precio = 25, tipo = "objeto" },
		{ id = "bolita", precio = 15, tipo = "objeto" },
		{ id = "nota", precio = 10, tipo = "objeto" },
		{ id = "gorra", precio = 90, tipo = "estetica" },
		{ id = "mochila", precio = 130, tipo = "estetica" },
		{ id = "anteojos", precio = 75, tipo = "estetica" },
		{ id = "campera", precio = 160, tipo = "estetica" },
	},
}

-- ── Salas multijugador ─────────────────────────────────────────────
Config.Salas = {
	MapaMemoria = "FinalsWeekSalas",
	VidaEntrada = 240,
	Latido = 25,
	MaximoListado = 40,
	CapacidadPorDefecto = 8,
	CapacidadesPosibles = { 2, 4, 6, 8, 12 },
	LargoCodigo = 5,
}

-- ── Sonido ─────────────────────────────────────────────────────────
-- Todo sale de los archivos que ya trae el motor: no hay que subir nada.
Config.Sonidos = {
	Campana = "rbxasset://sounds/electronicpingshort.wav",
	Click = "rbxasset://sounds/switch3.wav",
	Acierto = "rbxasset://sounds/electronicpingshort.wav",
	Error = "rbxasset://sounds/snap.mp3",
	Papel = "rbxasset://sounds/snap.mp3",
	Impacto = "rbxasset://sounds/impact_water.mp3",
	Silbato = "rbxasset://sounds/electronicpingshort.wav",
	Casillero = "rbxasset://sounds/metal.ogg",
	Tiza = "rbxasset://sounds/snap.mp3",
	NotaBaja = "rbxasset://sounds/bass.wav",
	VolumenBase = 0.45,
}

-- ── Musica (se sintetiza con los sonidos del motor) ────────────────
Config.Musica = {
	Habilitada = true,
	Volumen = 0.32,
	Bpm = { pasillo = 96, examen = 104, tension = 126, persecucion = 152 },
	IdPersonalizado = { pasillo = "", examen = "", tension = "", persecucion = "" },
}

-- ── Camara ─────────────────────────────────────────────────────────
Config.Camara = {
	AlturaOjos = Vector3.new(0, 1.5, 0),
	LlenadoHoja = 0.8,
	SegundosTransicion = 0.85,
	FovMinimo = 18,
	FovMaximo = 74,
}

table.freeze(Config)
return Config

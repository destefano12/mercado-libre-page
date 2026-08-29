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
	-- Pasillo estrecho y techo bajo: es lo que hace que el colegio se
	-- sienta cerrado en vez de un galpon. 16 de ancho es poco menos de
	-- tres personas de hombro a hombro.
	PasilloLargo = 190,
	PasilloAncho = 16,
	AlturaPiso = 11,                -- losa
	AlturaFalsoTecho = 9.4,         -- las placas del cielorraso
	EspesorPared = 1,
	AlturaZocalo = 3.6,             -- el friso oscuro de media pared
	CasillerosPorLado = 20,
	CasilleroAncho = 3.1,
	CasilleroAlto = 6.4,
	CasilleroFondo = 1.9,
	Aulas = 2,
	AulaAncho = 36,
	AulaLargo = 30,
	AulaAltura = 10,
	FilasDePupitres = 4,
	PupitresPorFila = 5,
	PupitreSeparacionX = 6.4,
	PupitreSeparacionZ = 6.0,
	ZonaRecreoLargo = 34,
	SalaDeCastigo = Vector3.new(150, 0, -80),
	BaldosaLado = 4,                -- damero del piso
	PlacaTecho = 4,                 -- placas del falso techo (16 / 4 = 4 justas)
	SeparacionLuces = 14,
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
		{ id = "walkie", precio = 110, tipo = "objeto" },
		{ id = "prismaticos", precio = 95, tipo = "objeto" },
		{ id = "celular", precio = 140, tipo = "objeto" },
		{ id = "aerosol", precio = 30, tipo = "objeto" },
		{ id = "libro", precio = 55, tipo = "objeto" },
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

-- ── El pasillo: pelota, canasta y cosas para tirar ─────────────────
Config.Pasillo = {
	PelotaRadio = 1.5,
	PelotaRebote = 0.72,
	PelotaFriccion = 0.35,
	PelotaFuerza = 96,
	PelotaAlturaTiro = 0.32,          -- cuanto se levanta el tiro (0-1)
	CanastaAltura = 6.4,              -- por debajo del falso techo (9.4)
	CanastaRadio = 2.4,               -- el pasillo mide 16 de ancho
	CanastaDistancia = 20,            -- del tablero a donde nace la pelota
	PuntosPorCanasta = 3,
	CreditosPorCanasta = 6,
	AlcanceAgarre = 8,
	EnfriamientoTiro = 0.4,
}

-- ── Grafiti: dibujar en las paredes ────────────────────────────────
Config.Grafiti = {
	Habilitado = true,
	MaximoPorSuperficie = 450,        -- despues borra las mas viejas
	PuntosPorSegundo = 18,            -- limite del servidor por jugador
	Alcance = 26,
	PixelesPorStud = 12,              -- resolucion del lienzo
	Tamanos = { 0.4, 0.8, 1.5, 2.5 }, -- diametro de la brocha, EN STUDS
	Paleta = {
		Color3.fromRGB(240, 62, 62),
		Color3.fromRGB(250, 176, 44),
		Color3.fromRGB(246, 232, 62),
		Color3.fromRGB(64, 204, 108),
		Color3.fromRGB(52, 150, 244),
		Color3.fromRGB(168, 96, 240),
		Color3.fromRGB(248, 248, 248),
		Color3.fromRGB(24, 24, 28),
	},
	SospechaPorPintar = 0.22,         -- si lo haces en el aula
}

-- ── Herramientas de comunicacion ───────────────────────────────────
Config.Herramientas = {
	RadioAlcance = 0,                 -- 0 = todo el mapa (es una radio)
	RadioCaracteres = 90,
	RadioEnfriamiento = 2.5,
	RadioSospecha = 0.34,
	CelularAlcance = 22,
	CelularEnfriamiento = 6,
	CelularSospecha = 0.46,
	CelularRevela = 1,
	PrismaticosFov = 16,
	PrismaticosAlcance = 46,          -- espiar hojas lejanas
	PrismaticosSospecha = 0.24,
	LibroRevela = 2,
	LibroSegundos = 3.5,
	LibroEnfriamiento = 20,
}

-- ── Dejar KO ───────────────────────────────────────────────────────
Config.Nocaut = {
	Alcance = 6.5,
	Enfriamiento = 1.1,
	EmpujonesParaKO = 3,
	VentanaEmpujones = 3.5,
	PorLaEspalda = 0.55,              -- coseno: mas alto = mas de atras
	SegundosKO = 4.5,
	Impulso = 42,
	SospechaEnExamen = 0.85,
	CreditosRobados = 0,
}

-- ── Alumnos que estudiaron (NPC) ───────────────────────────────────
Config.Empollones = {
	Cantidad = 4,
	Nombres = { "Nadia", "Bruno", "Iris", "Teo", "Mila", "Simon" },
	ProbabilidadDeCeder = 0.35,
	RespuestasQueSaben = 4,
	RespuestasAlCaer = 3,
	EnfriamientoPedir = 8,
	ColorSueter = Color3.fromRGB(96, 128, 72),
}

-- ── La goma de borrar del profesor ─────────────────────────────────
Config.Goma = {
	Habilitada = true,
	DistanciaMinima = 9,              -- mas cerca que esto, va y te agarra
	DistanciaMaxima = 40,
	Velocidad = 88,
	Enfriamiento = 3.2,
	Punteria = 0.86,                  -- 1 = perfecta; abajo, dispersion
	SegundosAturdido = 1.8,
	PenalizacionNota = 6,
}

-- ── Direccion de arte ──────────────────────────────────────────────
-- La tecnologia de iluminacion NO se puede escribir desde un script:
-- es de solo lectura en runtime. Este valor lo lee tools/build_studio.py
-- y lo escribe en el archivo del lugar, que es donde Roblox lo acepta.
Config.Estilo = {
	Tecnologia = "Future",          -- "Future" | "ShadowMap"
	Brillo = 1.55,
	Hora = 15.2,                    -- media tarde de semana de examenes
	Latitud = 41,
	Exposicion = -0.12,
	SuavidadSombras = 0.35,         -- solo Future
	DifusaEntorno = 0.35,
	EspecularEntorno = 0.22,
	Nubes = { cobertura = 0.86, densidad = 0.68 },
	Bloom = { intensidad = 0.5, tamano = 18, umbral = 1.62 },
	Profundidad = { lejos = 0.06, foco = 18, radio = 26, cerca = 0.1 },
	RayosSol = { intensidad = 0.03, dispersion = 0.9 },
	-- Un ColorCorrection por clima. Saturacion negativa = el look
	-- lavado de instituto; el tinte frio es la luz fluorescente.
	Climas = {
		pasillo = { brillo = -0.02, contraste = 0.12, saturacion = -0.26,
			tinte = Color3.fromRGB(236, 241, 248) },
		examen = { brillo = -0.05, contraste = 0.2, saturacion = -0.36,
			tinte = Color3.fromRGB(230, 238, 248) },
		tension = { brillo = -0.08, contraste = 0.28, saturacion = -0.46,
			tinte = Color3.fromRGB(248, 234, 232) },
	},
	Atmosfera = {
		densidad = 0.32,
		desplazamiento = 0.1,
		color = Color3.fromRGB(188, 192, 198),
		decaimiento = Color3.fromRGB(110, 118, 130),
		brillo = 0.22,
		neblina = 1.7,
	},
}

-- ── Texturas PBR propias (opcional) ────────────────────────────────
-- SurfaceAppearance necesita imagenes SUBIDAS a Roblox: no hay forma
-- de generarlas por codigo. Subilas en Studio (Asset Manager >
-- Images), copia sus ids aca y el juego las aplica solo al arrancar.
-- Con los campos vacios se usan los materiales PBR que ya trae el
-- motor, que con Future se ven bien igual.
Config.Texturas = {
	Pared = { color = "", normal = "", rugosidad = "", metalidad = "" },
	Piso = { color = "", normal = "", rugosidad = "", metalidad = "" },
	Casillero = { color = "", normal = "", rugosidad = "", metalidad = "" },
	Pupitre = { color = "", normal = "", rugosidad = "", metalidad = "" },
	Techo = { color = "", normal = "", rugosidad = "", metalidad = "" },
}

table.freeze(Config)
return Config

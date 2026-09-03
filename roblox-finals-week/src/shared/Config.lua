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
	--[[
		Esto era un pasillo de 16 de ancho y techo a 9.4, hecho angosto a
		proposito para que el colegio se sintiera cerrado. La referencia
		del juego real muestra lo contrario: un atrio ancho, de techo
		alto y muy luminoso, con una estatua en el medio. Asi que las
		proporciones se dan vuelta — es el cambio de mas impacto visual
		de todo el proyecto.
	--]]
	PasilloLargo = 150,             -- el atrio es ancho, no largo
	PasilloAncho = 46,
	AlturaPiso = 22,                -- techo alto y abierto
	EspesorPared = 1,
	AlturaZocalo = 4.2,             -- la banda turquesa de media pared
	CasillerosPorLado = 16,
	CasilleroAncho = 3.1,
	CasilleroAlto = 6.4,
	CasilleroFondo = 1.9,
	Aulas = 2,
	AulaAncho = 36,
	AulaLargo = 30,
	AulaAltura = 13,
	FilasDePupitres = 4,
	PupitresPorFila = 5,
	PupitreSeparacionX = 6.4,
	PupitreSeparacionZ = 6.0,
	ZonaRecreoLargo = 34,
	SalaDeCastigo = Vector3.new(150, 0, -80),
	BaldosaLado = 4,                -- damero del piso del atrio
	PlacaTecho = 4,                 -- solo el cielorraso del aula
	TablonAncho = 2,                -- tablones de madera del aula
	SeparacionLuces = 20,
	EstatuaAltura = 9,              -- la del centro del atrio
	EstatuaRadio = 5.2,
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
	--[[
		Los dos escondites con la hoja de respuestas.

		El cajon esta en el escritorio del profesor, o sea al alcance de
		la mano durante el examen: revela poco y cuesta carisimo en
		sospecha. La alcoba de la biblioteca revela el doble y no cuesta
		sospecha ninguna, pero esta del otro lado del atrio — lo que
		pagas es el recreo entero yendo y volviendo.
	--]]
	CajonRevela = 2,
	CajonEnfriamiento = 25,
	AlcobaRevela = 4,
	AlcobaEnfriamiento = 40,
}

-- ── Profesor (IA del servidor) ─────────────────────────────────────
Config.Profesor = {
	VelocidadPatrulla = 7,
	VelocidadPersecucion = 19,
	--[[
		Altura de los ojos POR ENCIMA DE LA RAIZ, no del piso: de ahi
		sale el rayo de vision y de ahi sale la goma que tira.

		Con el profesor reproporcionado la cabeza le quedo a 2.65 de la
		raiz (1.1 de medio torso + 0.7 de cuello + 0.85 de media
		cabeza). Dejarlo en 1.6 significaba que miraba desde el pecho:
		un pupitre que la cabeza pasa de sobra le tapaba la vista, y el
		profesor no veia copiar a alguien que tenia delante.
	--]]
	AlturaOjos = 2.65,
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
	-- Meter la mano en el escritorio del profesor, delante suyo, es la
	-- jugada mas cara del juego: casi te delata sola.
	PorCajon = 0.85,
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
	--[[
		`categoria` es la pestana del carnet donde cae el articulo (ver
		`Config.Carnet`). No cambia ninguna regla del servidor: la
		economia sigue mirando `tipo`. Es puro ordenamiento.
	--]]
	Tienda = {
		{ id = "chuleta", precio = 40, tipo = "objeto", categoria = "trampa" },
		{ id = "avion", precio = 25, tipo = "objeto", categoria = "trampa" },
		{ id = "bolita", precio = 15, tipo = "objeto", categoria = "trampa" },
		{ id = "nota", precio = 10, tipo = "objeto", categoria = "trampa" },
		{ id = "aerosol", precio = 30, tipo = "objeto", categoria = "trampa" },
		{ id = "walkie", precio = 110, tipo = "objeto", categoria = "aparato" },
		{ id = "prismaticos", precio = 95, tipo = "objeto", categoria = "aparato" },
		{ id = "celular", precio = 140, tipo = "objeto", categoria = "aparato" },
		{ id = "libro", precio = 55, tipo = "objeto", categoria = "aparato" },
		--[[
			La estetica no se compra sola: hay que haberse ganado el
			derecho. `semanas` son semanas finales sobrevividas y
			`promedio` es el mejor promedio que sacaste alguna vez, dos
			cosas que ya viven en el perfil de DataService.

			El pelo corto y la gorra quedan libres para que el carnet no
			se vea todo bloqueado la primera vez que se abre.
		--]]
		{ id = "pelo_corto", precio = 0, tipo = "estetica", categoria = "pelo" },
		{ id = "pelo_rulos", precio = 45, tipo = "estetica", categoria = "pelo" },
		{ id = "pelo_largo", precio = 60, tipo = "estetica", categoria = "pelo" },
		{ id = "pelo_cresta", precio = 85, tipo = "estetica", categoria = "pelo",
			requiere = { promedio = 60 } },
		{ id = "pelo_coletas", precio = 70, tipo = "estetica", categoria = "pelo" },
		{ id = "pelo_afro", precio = 95, tipo = "estetica", categoria = "pelo",
			requiere = { semanas = 1 } },
		{ id = "gorra", precio = 90, tipo = "estetica", categoria = "gorro" },
		{ id = "boina", precio = 65, tipo = "estetica", categoria = "gorro" },
		{ id = "vincha", precio = 40, tipo = "estetica", categoria = "gorro" },
		{ id = "anteojos", precio = 75, tipo = "estetica", categoria = "anteojos",
			requiere = { promedio = 70 } },
		{ id = "antifaz", precio = 120, tipo = "estetica", categoria = "anteojos",
			requiere = { semanas = 1 } },
		{ id = "mochila", precio = 130, tipo = "estetica", categoria = "ropa",
			requiere = { semanas = 1 } },
		{ id = "campera", precio = 160, tipo = "estetica", categoria = "ropa",
			requiere = { semanas = 2, promedio = 80 } },
		{ id = "bufanda", precio = 55, tipo = "estetica", categoria = "ropa" },
		--[[
			La pagina de ACCESSORIES del trailer no son accesorios: son
			RASGOS DE CARA — cejas de formas distintas, un lunar, pecas.
			Van en dos categorias porque se comportan distinto: de cejas
			se lleva un par (exclusiva), de marcas se llevan las que uno
			quiera a la vez.

			Ninguna cuesta mucho. Son lo primero que alguien toca al
			abrir el carnet y dejarlas todas bloqueadas seria decirle
			que vuelva en tres semanas.
		--]]
		{ id = "cejas_rectas", precio = 0, tipo = "estetica", categoria = "cejas" },
		{ id = "cejas_finas", precio = 20, tipo = "estetica", categoria = "cejas" },
		{ id = "cejas_gruesas", precio = 20, tipo = "estetica", categoria = "cejas" },
		{ id = "cejas_arqueadas", precio = 35, tipo = "estetica", categoria = "cejas" },
		{ id = "cejas_enojadas", precio = 35, tipo = "estetica", categoria = "cejas" },
		{ id = "cejas_unica", precio = 50, tipo = "estetica", categoria = "cejas" },
		{ id = "lunar", precio = 15, tipo = "estetica", categoria = "marcas" },
		{ id = "pecas", precio = 25, tipo = "estetica", categoria = "marcas" },
		{ id = "rubor", precio = 25, tipo = "estetica", categoria = "marcas" },
		{ id = "cicatriz", precio = 45, tipo = "estetica", categoria = "marcas",
			requiere = { semanas = 1 } },
		{ id = "tirita", precio = 30, tipo = "estetica", categoria = "marcas" },
		{ id = "bigote", precio = 60, tipo = "estetica", categoria = "marcas",
			requiere = { promedio = 60 } },
	},
}

--[[
	── Carnet de estudiante ───────────────────────────────────────────
	La cosmetica no es un panel de tienda: es una libreta que se abre en
	primera persona, con la credencial a la izquierda y una grilla de
	articulos a la derecha. Del canto derecho asoman pestanas de colores,
	una por categoria, y la elegida se corre hacia afuera.

	Los colores estan muestreados de los fotogramas del trailer, tab por
	tab y de arriba hacia abajo. El orden de esta lista ES el orden en
	que se apilan las pestanas.

	`exclusiva` significa que solo una cosa de esa categoria puede estar
	puesta a la vez — no se puede llevar dos peinados. Lo hace cumplir el
	servidor en ShopService.equip; el cliente solo lo dibuja.
--]]
Config.Carnet = {
	Filas = 5,                      -- la grilla del video es de 4x5
	Columnas = 4,
	--[[
		La clave se llama `categoria` y no `id` a proposito:
		`tools/check.py` recorre este archivo buscando `{ id = "..."` para
		verificar que cada articulo de la tienda tenga su nombre y su
		descripcion en los tres idiomas, y con `id` aca adentro pediria
		un `item.trampa` que no tiene sentido que exista.
	--]]
	--[[
		Las ocho, en el orden y con los colores exactos en que estan
		apiladas en el canto del carnet del trailer, muestreadas de
		arriba hacia abajo sobre `f030`. El orden de esta lista ES el
		orden en que se dibujan.
	--]]
	Pestanas = {
		{ categoria = "trampa", color = Color3.fromRGB(130, 78, 210), icono = "lapiz" },
		{ categoria = "aparato", color = Color3.fromRGB(200, 105, 222), icono = "radio" },
		{ categoria = "pelo", color = Color3.fromRGB(232, 192, 102), icono = "pelo",
			exclusiva = true },
		{ categoria = "gorro", color = Color3.fromRGB(208, 84, 94), icono = "gorra",
			exclusiva = true },
		{ categoria = "cejas", color = Color3.fromRGB(78, 152, 192), icono = "ojo",
			exclusiva = true },
		{ categoria = "anteojos", color = Color3.fromRGB(118, 222, 220), icono = "anteojos",
			exclusiva = true },
		{ categoria = "marcas", color = Color3.fromRGB(94, 232, 144), icono = "boca" },
		{ categoria = "ropa", color = Color3.fromRGB(196, 214, 120), icono = "campera" },
	},
	-- Paleta del carnet en si, tambien muestreada del video.
	Papel = Color3.fromRGB(243, 226, 196),
	PapelSombra = Color3.fromRGB(228, 208, 176),
	Casilla = Color3.fromRGB(196, 178, 162),
	Tinta = Color3.fromRGB(48, 44, 52),
	Cinta = Color3.fromRGB(182, 168, 209),
	Credencial = Color3.fromRGB(176, 42, 58),
	CredencialFondo = Color3.fromRGB(206, 232, 238),
	Remache = Color3.fromRGB(43, 40, 38),
	Seleccion = Color3.fromRGB(226, 62, 74),
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
	-- Estaba en 6.4 solo porque el falso techo estaba a 9.4. Sin falso
	-- techo vuelve a una altura de aro normal.
	CanastaAltura = 10,
	CanastaRadio = 2.4,
	CanastaDistancia = 20,            -- del tablero a donde nace la pelota
	PuntosPorCanasta = 3,
	CreditosPorCanasta = 6,
	AlcanceAgarre = 8,
	EnfriamientoTiro = 0.4,
	--[[
		Pelotas de beisbol. A diferencia de la de basquet no hay aro ni
		marcador: tirar es el fin en si mismo. Son mas chicas, mas
		rapidas y casi no rebotan, y si le pegas a alguien lo aturdis un
		momento — que es exactamente para lo que se usan.
	--]]
	BeisbolCantidad = 5,
	BeisbolRadio = 0.55,
	BeisbolRebote = 0.35,
	BeisbolFriccion = 0.55,
	BeisbolFuerza = 155,
	BeisbolAlturaTiro = 0.1,
	BeisbolAturde = 1.1,              -- segundos que aturde el impacto
	BeisbolVelocidadMinima = 45,      -- por debajo de esto no aturde
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
	-- Pasarle el libro a un companero: a distancia de brazo, no a
	-- distancia de grito.
	AlcancePase = 14,
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
--[[
	Estos numeros estaban calibrados para un instituto lavado y frio:
	saturacion negativa, tinte azul, bloom alto y profundidad de campo
	fuerte. La referencia del juego real es lo contrario — mate, plano,
	calido y saturado, con sombras blandas y contraste bajo. Se invierte
	todo el bloque.

	Se mantiene Future por la oclusion ambiental, pero suavizada: sin
	SSAO las esquinas del atrio se aplanan tanto que se pierde la
	profundidad.
--]]
--[[
	La luz.

	Muestreando `f001`, `f009` y `f013`: el piso del pasillo iluminado
	da (232,147,130) y la pared (210,173,163). Dos cosas salen de ahi.

	La primera es que **no hay nada quemado**. El punto mas claro de un
	plano interior anda por 240 en el rojo pero por 155 en el verde: es
	un salmon saturado, no un blanco. Con `Brillo` en 2.1 y exposicion
	positiva los colores se iban hacia el blanco y se perdia justamente
	lo que hace reconocible al juego.

	La segunda es que **el rango entre luz y sombra es angosto**. Casi
	no hay zonas oscuras. Eso no se consigue subiendo el sol: se
	consigue subiendo el ambiente, que es lo que convierte una sombra en
	un tono pintado en vez de en falta de luz. Es el truco del sombreado
	de dibujo, y ademas es la unica forma de bajar el brillo sin que la
	escena se ponga sucia.
--]]
Config.Estilo = {
	Tecnologia = "Future",          -- "Future" | "ShadowMap"
	Brillo = 1.45,                  -- el sol pega menos; el ambiente compensa
	Hora = 13.6,                    -- mediodia largo, sol alto
	Latitud = 18,                   -- sombras cortas: aplana la escena
	Exposicion = -0.05,             -- un pelo por debajo: sostiene la saturacion
	SuavidadSombras = 1,            -- solo Future; al maximo = sombras blandas
	DifusaEntorno = 1,              -- ambiente al maximo: sombreado de dibujo
	EspecularEntorno = 0.04,        -- casi nada: las superficies son mates
	Nubes = { cobertura = 0.32, densidad = 0.22 },
	Bloom = { intensidad = 0.12, tamano = 24, umbral = 2.1 },
	RayosSol = { intensidad = 0, dispersion = 1 },
	--[[
		Un ColorCorrection por clima. Ahora la saturacion es POSITIVA y
		el tinte calido. La tension no se comunica lavando la imagen
		sino subiendo el contraste y tirando el tinte a rosa.
	--]]
	Climas = {
		pasillo = { brillo = 0.02, contraste = 0.06, saturacion = 0.16,
			tinte = Color3.fromRGB(255, 250, 242) },
		examen = { brillo = 0, contraste = 0.1, saturacion = 0.12,
			tinte = Color3.fromRGB(252, 248, 240) },
		tension = { brillo = -0.02, contraste = 0.2, saturacion = 0.04,
			tinte = Color3.fromRGB(255, 236, 232) },
	},
	--[[
		La neblina baja: en los planos interiores del trailer el fondo de
		la biblioteca se ve nitido a treinta metros. La densidad anterior
		metia un velo gris que apagaba los lomos de colores del fondo,
		que son justamente lo que llena esa sala.
	--]]
	Atmosfera = {
		densidad = 0.1,
		desplazamiento = 0.25,
		color = Color3.fromRGB(238, 234, 228),
		decaimiento = Color3.fromRGB(186, 178, 172),
		brillo = 0,
		neblina = 0.25,
	},
}

-- ── Personajes ─────────────────────────────────────────────────────
--[[
	La piel de colores no humanos es el rasgo mas reconocible del juego:
	violeta, rosa, rojo, celeste. Cada jugador recibe una combinacion al
	entrar y se le guarda en el perfil, asi que te reconocen entre
	partidas.
--]]
Config.Personaje = {
	-- Tonos afinados contra los fotogramas del trailer: ahi se ven
	-- pieles amarillas, verdes, violetas y tostadas.
	Pieles = {
		Color3.fromRGB(240, 200, 92),   -- amarillo
		Color3.fromRGB(146, 108, 210),  -- violeta
		Color3.fromRGB(126, 184, 108),  -- verde
		Color3.fromRGB(206, 148, 110),  -- tostado
		Color3.fromRGB(198, 96, 168),   -- magenta
		Color3.fromRGB(96, 164, 214),   -- celeste
		Color3.fromRGB(232, 148, 176),  -- rosa
		Color3.fromRGB(226, 104, 88),   -- coral
	},
	Pelos = {
		Color3.fromRGB(72, 96, 208),    -- azul
		Color3.fromRGB(158, 74, 190),   -- violeta
		Color3.fromRGB(72, 178, 140),   -- verde
		Color3.fromRGB(218, 76, 122),   -- magenta
		Color3.fromRGB(240, 190, 72),   -- amarillo
		Color3.fromRGB(240, 128, 88),   -- naranja
		Color3.fromRGB(64, 188, 208),   -- turquesa
		Color3.fromRGB(48, 48, 62),     -- casi negro
	},
}

table.freeze(Config)
return Config

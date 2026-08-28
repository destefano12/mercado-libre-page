--!strict
--[[
	Config
	------------------------------------------------------------------
	Todos los numeros que definen el "feeling" del juego viven aca.
	Si queres que el profe sea mas duro, que la prueba sea mas larga o
	que el celu tarde mas en responder, tocas SOLO este archivo.
--]]

export type RiskState = {
	risk: number,      -- 0..1
	seen: boolean,     -- el profe te tiene en su cono de vision
	inspecting: boolean,
	teacherState: string,
}

local Config = {}

-- ─────────────────────────────────────────────────────────────
-- AULA (todo se construye por codigo, en 3D, a escala real)
-- ─────────────────────────────────────────────────────────────
Config.Classroom = {
	Origin = CFrame.new(0, 0, 0),

	-- ── Aula importada del catalogo ───────────────────────────
	-- Si UseAsset esta en true, el juego usa este modelo de escenario
	-- en vez de construir el aula por codigo. Si no lo puede bajar,
	-- busca uno ya insertado en Workspace que se llame "AulaImportada"
	-- (o que tenga "classroom" en el nombre). Si tampoco, construye la
	-- suya y no pasa nada.
	--
	-- Los bancos se ubican por codigo adentro del modelo. Si quedan
	-- mirando para el lado equivocado, girá AssetRotation de a 90.
	UseAsset = true,
	AssetId = 14664582891,
	AssetRotation = 0,              -- grados: 0, 90, 180 o 270
	AssetOffset = CFrame.new(0, 0, 20),
	AssetGridInset = 0.62,          -- cuanto del aula ocupa la grilla de bancos
	HideAssetFurniture = true,      -- saca los bancos que traiga el modelo

	Rows = 5,              -- filas de bancos (de adelante hacia atras)
	Columns = 4,           -- bancos por fila
	DeskSpacingX = 8,      -- separacion entre columnas (pasillos)
	DeskSpacingZ = 7.5,    -- separacion entre filas
	FirstRowOffsetZ = 14,  -- distancia del pizarron a la primera fila

	WallHeight = 15,
	WallThickness = 1,
	Padding = 10,          -- aire entre el ultimo banco y la pared del fondo

	-- Paleta de aula americana: linoleo claro, bloque pintado, verde
	-- pizarron. Corta a proposito.
	FloorColor = Color3.fromRGB(198, 196, 188),
	WallMaterial = Enum.Material.Concrete,
	WallColor = Color3.fromRGB(232, 230, 222),
	TrimColor = Color3.fromRGB(96, 102, 112),
	BoardColor = Color3.fromRGB(48, 104, 74),
}

-- ─────────────────────────────────────────────────────────────
-- PRUEBA
-- ─────────────────────────────────────────────────────────────
Config.Exam = {
	QuestionCount = 8,
	RoundDuration = 300,        -- segundos de prueba
	IntermissionDuration = 12,  -- entre rondas
	MaxGrade = 10,              -- escala 1..10
	PassingGrade = 6,

	-- Progresion de dificultad a lo largo de la prueba (indice -> dificultad)
	DifficultyCurve = { 1, 1, 2, 2, 3, 3, 4, 4, 5, 5 },

	WriteDuration = 2.4,        -- cuanto dura el gesto de escribir con el lapiz

	PointsCorrect = 100,
	PointsCorrectSolo = 160,    -- responder sin usar el celu vale mas
	PointsWrong = -40,
}

-- ─────────────────────────────────────────────────────────────
-- PROFESOR
-- ─────────────────────────────────────────────────────────────
Config.Teacher = {
	DisplayName = "Mr. Hollis",

	-- Camina despacio y parejo: es un tipo formal, no persigue a nadie
	-- hasta que hace falta.
	WalkSpeed = 6.2,
	ChaseSpeed = 12,

	-- Vision. Es estricto: ve lejos y abre bastante el cono.
	FieldOfView = 118,          -- grados totales del cono
	ViewDistance = 54,
	PeripheralFactor = 0.6,     -- cuanto "cuenta" lo que ve de reojo

	-- Comportamiento
	InspectChance = 0.68,       -- prob. de frenar en un banco al pasar
	InspectDuration = NumberRange.new(3.0, 6.0),
	BoardChance = 0.22,         -- prob. de irse al pizarron (ventana segura)
	BoardDuration = NumberRange.new(5.0, 8.5),
	BoardCooldown = 34,         -- segundos minimos entre dos idas al pizarron
	IdleAtWaypoint = NumberRange.new(0.8, 2.2),
	HeadTurnSpeed = 2.6,        -- gira la cabeza despacio, con intencion
	ScanChance = 0.3,           -- prob. de frenar a barrer el aula con la vista

	-- Sospecha (0..1 por jugador)
	RiskGainSeen = 0.55,        -- por segundo, celu visible y a la vista
	RiskGainInspect = 1.1,      -- por segundo, ademas te esta revisando la prueba
	RiskGainHidden = 0.05,      -- por segundo, celu afuera pero no te ve
	RiskDecay = 0.2,            -- por segundo, celu guardado
	RiskDecayWriting = 0.55,    -- por segundo, si ademas estas escribiendo
	RiskCaught = 1.0,
	RiskWarning = 0.5,          -- desde aca el HUD se pone rojo
}

-- ─────────────────────────────────────────────────────────────
-- CELULAR / RoGPT
-- ─────────────────────────────────────────────────────────────
Config.Phone = {
	RaiseTime = 0.35,           -- tween de sacar el celu
	PhotoCooldown = 2.0,
	BatteryMax = 100,
	BatteryPerPhoto = 8,
	BatteryDrainPerSecond = 0.6,
	BatteryRechargePerSecond = 1.4, -- se recarga guardado (bolsillo con powerbank, cero realismo)

	ConfiscationTime = 35,      -- segundos sin celu despues de que te pillan

	-- RoGPT no es magia: a veces no hay señal y a veces se manda una
	-- macana. Es lo que hace que copiarse no sea gratis.
	NoInternetChance = 0.18,
	WrongAnswerChance = 0.12,

	-- RoGPT "pensando"
	UploadTime = NumberRange.new(0.6, 1.2),
	ThinkTime = NumberRange.new(1.4, 2.8),
	TypeSpeed = 55,             -- caracteres por segundo al escribir la respuesta
	ModelName = "RoGPT-4o",
}

-- ─────────────────────────────────────────────────────────────
-- CAMARA (todo el juego es 3D: la camara acompaña, no hay pantallas planas)
-- ─────────────────────────────────────────────────────────────
Config.Camera = {
	-- La camara de "hoja" y "celu" sale de los ojos del personaje: se
	-- planta un poco adelante de la cara y apunta al objeto. Si la
	-- anclás al objeto y la tirás para atras, termina adentro de tu
	-- propia cabeza y no se ve nada.
	EyeOffset = CFrame.new(0, 0.3, -0.6),

	BlendTime = 0.35,
	FieldOfView = 70,
	PaperFieldOfView = 60,
	PhoneFieldOfView = 46,
	MenuFieldOfView = 42,
	CineFieldOfView = 38,   -- un poco de teleobjetivo: se lee mas a pelicula
}

-- Sonidos. Son los que vienen adentro del motor de Roblox
-- (rbxasset://), asi que existen siempre y no hay nada que subir.
-- Si tenes efectos propios, cambia estos por tus rbxassetid.
Config.Sounds = {
	Shutter = "rbxasset://sounds/switch3.wav",              -- click de la camara
	Send = "rbxasset://sounds/button.wav",                  -- mensaje enviado
	Reply = "rbxasset://sounds/electronicpingshort.wav",    -- RoGPT contesta
	Correct = "rbxasset://sounds/electronicpingshort.wav",  -- respuesta correcta
	Wrong = "rbxasset://sounds/switch.wav",                 -- respuesta incorrecta
	Caught = "rbxasset://sounds/snap.mp3",                  -- te pillaron
	PhoneOut = "rbxasset://sounds/switch.wav",              -- sacar el celular
	Write = "rbxasset://sounds/switch3.wav",                -- escribir con el lapiz
}

-- ─────────────────────────────────────────────────────────────
-- HISTORIA
-- ─────────────────────────────────────────────────────────────
-- El dia no termina cuando entregas la prueba: suena el timbre, salis
-- del aula con todos, y despues tenes que llegar a tu casa y que tu
-- viejo no se entere de como te fue.
Config.Story = {
	DismissalDuration = 20,     -- salida del aula y de la escuela
	HomeDuration = 75,          -- la escena en casa
	EpilogueDuration = 14,      -- la placa final

	HomeOrigin = CFrame.new(1200, 0, 1200),
	FadeTime = 1.2,
	LetterboxTime = 0.8,

	PassingLie = 5,             -- de aca para abajo, mentir tiene sentido
}

-- ─────────────────────────────────────────────────────────────
-- SALAS
-- ─────────────────────────────────────────────────────────────
Config.Lobby = {
	MaxRooms = 40,          -- cuantas se listan
	RoomTTL = 1800,         -- segundos que vive una sala sin señales de vida
	HeartbeatEvery = 25,    -- cada cuanto la sala avisa que sigue viva
	DefaultMaxPlayers = 8,
	MinPlayers = 2,
	MaxPlayers = 20,
	NameLimit = 24,
	PasswordLimit = 16,
}

Config.Penalty = {
	GradePerCatch = 2,          -- puntos de nota que te descuenta cada vez que te pillan
	MaxCatches = 2,             -- a la segunda te saca de la prueba
}

table.freeze(Config)
return Config

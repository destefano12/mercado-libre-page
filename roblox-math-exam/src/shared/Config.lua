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

	Rows = 4,              -- filas de bancos (de adelante hacia atras)
	Columns = 3,           -- bancos por fila
	DeskSpacingX = 9,      -- separacion entre columnas (pasillos)
	DeskSpacingZ = 8,      -- separacion entre filas
	FirstRowOffsetZ = 14,  -- distancia del pizarron a la primera fila

	WallHeight = 16,
	WallThickness = 1,
	Padding = 12,          -- aire entre el ultimo banco y la pared del fondo

	FloorMaterial = Enum.Material.WoodPlanks,
	FloorColor = Color3.fromRGB(150, 118, 84),
	WallMaterial = Enum.Material.Concrete,
	WallColor = Color3.fromRGB(226, 222, 210),
	TrimColor = Color3.fromRGB(72, 92, 110),
}

-- ─────────────────────────────────────────────────────────────
-- PRUEBA
-- ─────────────────────────────────────────────────────────────
Config.Exam = {
	QuestionCount = 8,
	RoundDuration = 300,        -- segundos de prueba
	IntermissionDuration = 20,  -- entre rondas
	MaxGrade = 10,              -- escala 1..10
	PassingGrade = 6,

	-- Progresion de dificultad a lo largo de la prueba (indice -> dificultad)
	DifficultyCurve = { 1, 1, 2, 2, 3, 3, 4, 4, 5, 5 },

	PointsCorrect = 100,
	PointsCorrectSolo = 160,    -- responder sin usar el celu vale mas
	PointsWrong = -40,
}

-- ─────────────────────────────────────────────────────────────
-- PROFESOR
-- ─────────────────────────────────────────────────────────────
Config.Teacher = {
	DisplayName = "Prof. Battaglia",

	WalkSpeed = 7.5,
	ChaseSpeed = 13,

	-- Vision
	FieldOfView = 105,          -- grados totales del cono
	ViewDistance = 46,
	PeripheralFactor = 0.55,    -- cuanto "cuenta" lo que ve de reojo

	-- Comportamiento
	InspectChance = 0.55,       -- prob. de frenar en un banco al pasar
	InspectDuration = NumberRange.new(2.5, 5.0),
	BoardChance = 0.30,         -- prob. de irse al pizarron (ventana segura)
	BoardDuration = NumberRange.new(6.0, 11.0),
	IdleAtWaypoint = NumberRange.new(0.4, 1.6),
	HeadTurnSpeed = 4.0,

	-- Sospecha (0..1 por jugador)
	RiskGainSeen = 0.42,        -- por segundo, celu visible y a la vista
	RiskGainInspect = 0.85,     -- por segundo, ademas te esta revisando la prueba
	RiskGainHidden = 0.05,      -- por segundo, celu afuera pero no te ve
	RiskDecay = 0.22,           -- por segundo, celu guardado
	RiskCaught = 1.0,
	RiskWarning = 0.55,         -- desde aca el HUD se pone rojo
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

	-- RoGPT "pensando"
	UploadTime = NumberRange.new(0.6, 1.2),
	ThinkTime = NumberRange.new(1.4, 2.8),
	TypeSpeed = 55,             -- caracteres por segundo al escribir la respuesta
	ModelName = "RoGPT-4o",
	Greeting = "Hola. Mandame la foto del ejercicio y te lo resuelvo paso a paso.",
}

-- ─────────────────────────────────────────────────────────────
-- CAMARA (todo el juego es 3D: la camara acompaña, no hay pantallas planas)
-- ─────────────────────────────────────────────────────────────
Config.Camera = {
	DeskOffset = Vector3.new(0, 3.2, 5.4),   -- sobre el hombro, mirando la prueba
	DeskLookOffset = Vector3.new(0, 1.1, 0),
	PhoneOffset = Vector3.new(0.9, 2.4, 2.6),-- acercada al celu
	BlendTime = 0.45,
	FieldOfView = 68,
	PhoneFieldOfView = 52,
}

-- Sonidos: dejalos vacios y no suena nada (sin warnings en consola).
-- Pone tus propios rbxassetid cuando tengas los efectos subidos.
Config.Sounds = {
	Shutter = "",       -- click de la camara
	Send = "",          -- mensaje enviado
	Reply = "",         -- RoGPT contesta
	Correct = "",       -- respuesta correcta
	Wrong = "",         -- respuesta incorrecta
	Caught = "",        -- te pillaron
	PhoneOut = "",      -- roce de sacar el celular
}

Config.Penalty = {
	GradePerCatch = 1.5,        -- puntos de nota que te descuenta cada vez que te pillan
	MaxCatches = 3,             -- a la tercera te saca de la prueba
}

table.freeze(Config)
return Config

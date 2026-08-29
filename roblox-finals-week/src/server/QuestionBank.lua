--!strict
--[[
	QuestionBank
	------------------------------------------------------------------
	El banco de preguntas vive en el servidor y nada mas: el cliente
	recibe el enunciado y las opciones, nunca la respuesta correcta.
	Por eso este modulo esta en ServerScriptService y ademas deja una
	copia de las penalizaciones en ServerStorage (fuera del alcance
	del cliente, como pide la arquitectura).

	Las preguntas son procedurales y simbolicas a proposito: una cuenta
	se lee igual en espanol, ingles y portugues, asi que el examen
	funciona en los tres idiomas sin traducir nada.
--]]

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local QuestionBank = {}

export type Question = {
	i: number,
	tipo: string,        -- "opcion" | "escritura"
	texto: string,
	opciones: { string },
	secuencia: string?,
	respuesta: number,   -- indice correcto (NO se manda al cliente)
	tema: string,        -- clave de idioma: topic.math, ...
}

local TEMAS = { "topic.math", "topic.science", "topic.math", "topic.geography", "topic.language" }

local rng = Random.new()

-- ── generadores ────────────────────────────────────────────────────
-- Cada uno devuelve enunciado + valor correcto. `nivel` va de 1 a ~2.

local function aritmetica(nivel: number): (string, number)
	local scale = math.floor(9 * nivel)
	local a = rng:NextInteger(2, 9 + scale)
	local b = rng:NextInteger(2, 6 + scale)
	local ops = { "+", "-", "x" }
	if nivel > 1.2 then
		table.insert(ops, "x")
	end
	local op = ops[rng:NextInteger(1, #ops)]
	if op == "+" then
		return string.format("%d + %d", a, b), a + b
	elseif op == "-" then
		return string.format("%d - %d", a + b, b), a
	end
	return string.format("%d x %d", a, b), a * b
end

local function ecuacion(nivel: number): (string, number)
	local x = rng:NextInteger(2, 6 + math.floor(8 * nivel))
	local m = rng:NextInteger(2, 3 + math.floor(5 * nivel))
	local c = rng:NextInteger(1, 9 + math.floor(10 * nivel))
	return string.format("%dx + %d = %d    x = ?", m, c, m * x + c), x
end

local function porcentaje(nivel: number): (string, number)
	local pct = ({ 10, 20, 25, 50, 15, 5, 40, 75 })[rng:NextInteger(1, nivel > 1.3 and 8 or 5)]
	local base = rng:NextInteger(2, 10 + math.floor(20 * nivel)) * 20
	return string.format("%d%% de %d", pct, base), math.floor(base * pct / 100)
end

local function secuencia(nivel: number): (string, number)
	local start = rng:NextInteger(1, 8)
	if nivel > 1.3 and rng:NextNumber() < 0.5 then
		local ratio = rng:NextInteger(2, 3)
		local values = { start }
		for i = 2, 4 do
			values[i] = values[i - 1] * ratio
		end
		return string.format("%d, %d, %d, %d, ?", values[1], values[2], values[3], values[4]),
			values[4] * ratio
	end
	local step = rng:NextInteger(2, 4 + math.floor(6 * nivel))
	local values = {}
	for i = 1, 4 do
		values[i] = start + (i - 1) * step
	end
	return string.format("%d, %d, %d, %d, ?", values[1], values[2], values[3], values[4]),
		values[4] + step
end

local function unidades(_: number): (string, number)
	local cases = {
		{ "%d km = ? m", 1000 },
		{ "%d m = ? cm", 100 },
		{ "%d kg = ? g", 1000 },
		{ "%d h = ? min", 60 },
		{ "%d min = ? s", 60 },
	}
	local case = cases[rng:NextInteger(1, #cases)]
	local value = rng:NextInteger(2, 12)
	return string.format(case[1] :: string, value), value * (case[2] :: number)
end

local function potencias(nivel: number): (string, number)
	if nivel > 1.4 and rng:NextNumber() < 0.4 then
		local root = rng:NextInteger(4, 15)
		return string.format("raiz(%d)", root * root), root
	end
	local base = rng:NextInteger(2, 9)
	local exp = rng:NextInteger(2, nivel > 1.3 and 3 or 2)
	return string.format("%d^%d", base, exp), base ^ exp
end

local function area(nivel: number): (string, number)
	local w = rng:NextInteger(3, 8 + math.floor(10 * nivel))
	local h = rng:NextInteger(3, 8 + math.floor(10 * nivel))
	if rng:NextNumber() < 0.4 then
		return string.format("perimetro de %d x %d", w, h), 2 * (w + h)
	end
	return string.format("area de %d x %d", w, h), w * h
end

local GENERADORES = { aritmetica, ecuacion, porcentaje, secuencia, unidades, potencias, area }

-- ── opciones ───────────────────────────────────────────────────────

--- Distractores creibles: cerca del valor bueno, sin repetirse.
local function opciones(correct: number): ({ string }, number)
	local values = { correct }
	local spread = math.max(2, math.floor(math.abs(correct) * 0.25))
	local guard = 0
	while #values < Config.Examen.OpcionesPorPregunta and guard < 80 do
		guard += 1
		local delta = rng:NextInteger(1, spread) * (rng:NextNumber() < 0.5 and -1 or 1)
		local candidate = correct + delta
		if candidate ~= correct and candidate >= 0 then
			local repeated = false
			for _, value in values do
				if value == candidate then
					repeated = true
					break
				end
			end
			if not repeated then
				table.insert(values, candidate)
			end
		end
	end
	-- Si el numero era muy chico y no salieron distractores, se rellena.
	local filler = correct + 1
	while #values < Config.Examen.OpcionesPorPregunta do
		filler += 1
		table.insert(values, filler)
	end

	-- Fisher-Yates, y nos guardamos donde quedo la buena.
	for i = #values, 2, -1 do
		local j = rng:NextInteger(1, i)
		values[i], values[j] = values[j], values[i]
	end

	local answer = 1
	local text = {}
	for i, value in values do
		text[i] = tostring(value)
		if value == correct then
			answer = i
		end
	end
	return text, answer
end

local LETRAS = { "Q", "W", "E", "R", "T", "A", "S", "D", "F", "G", "Z", "X", "C", "V" }

local function escritura(nivel: number): Question
	local length = math.clamp(
		math.floor(Config.Examen.LargoSecuencia.Min + (Config.Examen.LargoSecuencia.Max - Config.Examen.LargoSecuencia.Min) * (nivel - 1)),
		Config.Examen.LargoSecuencia.Min,
		Config.Examen.LargoSecuencia.Max
	)
	local letters = {}
	for i = 1, length do
		letters[i] = LETRAS[rng:NextInteger(1, #LETRAS)]
	end
	local sequence = table.concat(letters)
	return {
		i = 0,
		tipo = "escritura",
		texto = sequence,
		opciones = {},
		secuencia = sequence,
		respuesta = 0,
		tema = "topic.language",
	}
end

-- ── entrada ────────────────────────────────────────────────────────

function QuestionBank.difficulty(day: number): number
	local curve = Config.Ronda.CurvaDificultad
	return curve[math.clamp(day, 1, #curve)] or curve[#curve]
end

function QuestionBank.count(day: number): number
	return math.min(
		Config.Examen.PreguntasBase + (day - 1) * Config.Examen.PreguntasPorDia,
		Config.Examen.MaximoPreguntas
	)
end

--- Un examen entero para un alumno. Cada uno recibe el suyo: asi
--- copiar tiene sentido solo si el vecino tuvo la misma pregunta.
function QuestionBank.generate(day: number): { Question }
	local nivel = QuestionBank.difficulty(day)
	local total = QuestionBank.count(day)
	local questions: { Question } = {}

	for i = 1, total do
		if rng:NextNumber() < Config.Examen.ProbabilidadEscritura then
			local question = escritura(nivel)
			question.i = i
			questions[i] = question
		else
			local generator = GENERADORES[rng:NextInteger(1, #GENERADORES)]
			local texto, correct = generator(nivel)
			local text, answer = opciones(math.floor(correct))
			questions[i] = {
				i = i,
				tipo = "opcion",
				texto = texto,
				opciones = text,
				secuencia = nil,
				respuesta = answer,
				tema = TEMAS[((i - 1) % #TEMAS) + 1],
			}
		end
	end

	return questions
end

--- La version que puede ver el cliente: sin `respuesta`.
function QuestionBank.publicView(questions: { Question }): { any }
	local out = {}
	for i, q in questions do
		out[i] = {
			i = q.i,
			tipo = q.tipo,
			texto = q.texto,
			opciones = q.opciones,
			secuencia = q.secuencia,
			tema = q.tema,
		}
	end
	return out
end

--- Deja en ServerStorage lo que la arquitectura pide tener fuera del
--- alcance del cliente: penalizaciones y una marca del banco.
function QuestionBank.install()
	local previous = ServerStorage:FindFirstChild("BancoDePreguntas")
	if previous then
		previous:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "BancoDePreguntas"
	folder:SetAttribute("Generadores", #GENERADORES)
	folder:SetAttribute("MaximoPreguntas", Config.Examen.MaximoPreguntas)
	folder.Parent = ServerStorage

	local penalties = Instance.new("Configuration")
	penalties.Name = "Penalizaciones"
	penalties:SetAttribute("PenalizacionNota", Config.Castigo.PenalizacionNota)
	penalties:SetAttribute("SegundosCono", Config.Castigo.SegundosCono)
	penalties:SetAttribute("SegundosExpulsion", Config.Castigo.SegundosExpulsion)
	penalties:SetAttribute("InfraccionesParaExpulsion", Config.Castigo.InfraccionesParaExpulsion)
	penalties.Parent = ServerStorage
end

return QuestionBank

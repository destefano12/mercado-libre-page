--!strict
--[[
	MathEngine
	------------------------------------------------------------------
	Genera los ejercicios de la prueba y, para cada uno, la resolucion
	paso a paso que despues escupe RoGPT en la pantalla del celular.

	Cada generador devuelve:
		prompt      : el enunciado tal cual va impreso en la hoja
		answer      : la respuesta correcta (texto)
		distractors : errores tipicos (para las opciones)
		steps       : { {title, body}, ... }  resolucion del "modelo"
		topic       : etiqueta para el chat
--]]

export type Step = { title: string, body: string }

export type Question = {
	id: number,
	topic: string,
	prompt: string,
	choices: { string },
	answerIndex: number,
	steps: { Step },
	difficulty: number,
}

local MathEngine = {}

-- ─────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────

local function gcd(a: number, b: number): number
	a, b = math.abs(a), math.abs(b)
	while b > 0 do
		a, b = b, a % b
	end
	return a == 0 and 1 or a
end

local function frac(n: number, d: number): string
	if d < 0 then
		n, d = -n, -d
	end
	local g = gcd(n, d)
	n, d = n // g, d // g
	if d == 1 then
		return tostring(n)
	end
	return string.format("%d/%d", n, d)
end

local function num(value: number): string
	if math.abs(value - math.round(value)) < 1e-9 then
		return tostring(math.round(value))
	end
	return (string.format("%.2f", value):gsub("%.?0+$", ""))
end

local function signed(value: number): string
	return value >= 0 and ("+ " .. num(value)) or ("- " .. num(-value))
end

-- "+ 3x" / "- 3x" para escribir polinomios prolijos
local function signedTerm(value: number, variable: string): string
	local coefficient = math.abs(value)
	local body = if coefficient == 1 then variable else num(coefficient) .. variable
	return (value >= 0 and "+ " or "- ") .. body
end

-- "3x" / "-x" / "x": coeficiente al frente de una variable, sin el 1 de mas.
local function term(value: number, variable: string): string
	if value == 1 then
		return variable
	elseif value == -1 then
		return "-" .. variable
	end
	return num(value) .. variable
end

local function shuffle(list: { any }, rng: Random)
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

-- ─────────────────────────────────────────────────────────────
-- Generadores por dificultad
-- ─────────────────────────────────────────────────────────────

type Raw = {
	topic: string,
	prompt: string,
	answer: string,
	distractors: { string },
	steps: { Step },
}

local generators: { { (Random) -> Raw } } = {}

-- Dificultad 1 ─ jerarquia de operaciones
generators[1] = {
	function(rng: Random): Raw
		local a, b, c, d = rng:NextInteger(3, 12), rng:NextInteger(2, 9), rng:NextInteger(2, 9), rng:NextInteger(2, 12)
		local result = a + b * c - d
		return {
			topic = "Jerarquia de operaciones",
			prompt = string.format("Resolve: %d + %d x %d - %d", a, b, c, d),
			answer = num(result),
			distractors = { num((a + b) * c - d), num(a + b * (c - d)), num(result + b) },
			steps = {
				{ title = "1. Primero la multiplicacion",
				  body = string.format("%d x %d = %d", b, c, b * c) },
				{ title = "2. Ahora sumas y restas de izquierda a derecha",
				  body = string.format("%d + %d - %d = %d", a, b * c, d, result) },
				{ title = "3. Resultado",
				  body = string.format("= %d", result) },
			},
		}
	end,
	function(rng: Random): Raw
		local a, b, c = rng:NextInteger(2, 9), rng:NextInteger(2, 9), rng:NextInteger(2, 12)
		local result = a * (b + c)
		return {
			topic = "Propiedad distributiva",
			prompt = string.format("Resolve: %d x (%d + %d)", a, b, c),
			answer = num(result),
			distractors = { num(a * b + c), num(a + b * c), num(result - a) },
			steps = {
				{ title = "1. Resolves el parentesis",
				  body = string.format("%d + %d = %d", b, c, b + c) },
				{ title = "2. Multiplicas",
				  body = string.format("%d x %d = %d", a, b + c, result) },
				{ title = "3. Verificacion (distributiva)",
				  body = string.format("%d x %d + %d x %d = %d + %d = %d", a, b, a, c, a * b, a * c, result) },
			},
		}
	end,
}

-- Dificultad 2 ─ ecuacion lineal simple
generators[2] = {
	function(rng: Random): Raw
		local a = rng:NextInteger(2, 9)
		local x = rng:NextInteger(-8, 12)
		local b = rng:NextInteger(-15, 15)
		if b == 0 then
			b = rng:NextInteger(3, 15)
		end
		local c = a * x + b
		return {
			topic = "Ecuacion de primer grado",
			prompt = string.format("Despeja x:   %dx %s = %d", a, signed(b), c),
			answer = string.format("x = %d", x),
			distractors = {
				string.format("x = %s", num((c + b) / a)),
				string.format("x = %s", num(c - b)),
				string.format("x = %s", num((c - b) / (a + 1))),
			},
			steps = {
				{ title = "1. Pasas el termino independiente",
				  body = string.format("%dx = %d %s", a, c, signed(-b)) },
				{ title = "2. Te queda",
				  body = string.format("%dx = %d", a, c - b) },
				{ title = "3. Dividis por el coeficiente",
				  body = string.format("x = %d / %d = %d", c - b, a, x) },
				{ title = "4. Verificacion",
				  body = string.format("%d x (%d) %s = %d ✓", a, x, signed(b), c) },
			},
		}
	end,
	function(rng: Random): Raw
		local total = rng:NextInteger(4, 40) * 10
		local pct = ({ 5, 10, 15, 20, 25, 30, 40, 50, 75 })[rng:NextInteger(1, 9)]
		local result = total * pct / 100
		return {
			topic = "Porcentaje",
			prompt = string.format("Cuanto es el %d%% de %d?", pct, total),
			answer = num(result),
			distractors = { num(total * pct / 10), num(total / pct), num(result + pct) },
			steps = {
				{ title = "1. El porcentaje es una fraccion sobre 100",
				  body = string.format("%d%% = %d/100 = %s", pct, pct, num(pct / 100)) },
				{ title = "2. Multiplicas por el total",
				  body = string.format("%s x %d = %s", num(pct / 100), total, num(result)) },
				{ title = "3. Resultado",
				  body = string.format("El %d%% de %d es %s", pct, total, num(result)) },
			},
		}
	end,
}

-- Dificultad 3 ─ fracciones y proporciones
generators[3] = {
	function(rng: Random): Raw
		-- Fracciones propias: se leen mejor en la hoja.
		local b, d = rng:NextInteger(2, 9), rng:NextInteger(2, 9)
		local a, c = rng:NextInteger(1, b - 1), rng:NextInteger(1, d - 1)
		local n, den = a * d + c * b, b * d
		return {
			topic = "Suma de fracciones",
			prompt = string.format("Resolve:   %d/%d + %d/%d", a, b, c, d),
			answer = frac(n, den),
			distractors = { frac(a + c, b + d), frac(n + 1, den), frac(a * c, b * d) },
			steps = {
				{ title = "1. Denominador comun",
				  body = string.format("%d x %d = %d", b, d, den) },
				{ title = "2. Amplificas cada fraccion",
				  body = string.format("%d/%d = %d/%d   y   %d/%d = %d/%d", a, b, a * d, den, c, d, c * b, den) },
				{ title = "3. Sumas los numeradores",
				  body = string.format("(%d + %d)/%d = %d/%d", a * d, c * b, den, n, den) },
				{ title = "4. Simplificas",
				  body = string.format("= %s", frac(n, den)) },
			},
		}
	end,
	function(rng: Random): Raw
		local k = rng:NextInteger(2, 9)
		local a = rng:NextInteger(2, 9)
		local b = a * k
		local c = rng:NextInteger(2, 12)
		if c == a then
			c += 1
		end
		local x = c * k
		return {
			topic = "Proporcionalidad",
			prompt = string.format("Si %d/%d = %d/x, cuanto vale x?", a, b, c),
			answer = string.format("x = %d", x),
			distractors = {
				string.format("x = %d", math.max(1, c - k)),
				string.format("x = %d", a * c),
				string.format("x = %d", b - c),
			},
			steps = {
				{ title = "1. Multiplicacion cruzada",
				  body = string.format("%d x x = %d x %d", a, b, c) },
				{ title = "2. Te queda",
				  body = string.format("%dx = %d", a, b * c) },
				{ title = "3. Despejas",
				  body = string.format("x = %d / %d = %d", b * c, a, x) },
			},
		}
	end,
}

-- Dificultad 4 ─ ecuaciones con parentesis / sistemas 2x2
generators[4] = {
	function(rng: Random): Raw
		local a, b = rng:NextInteger(2, 6), rng:NextInteger(1, 8)
		local c = rng:NextInteger(2, 6)
		if a == c then
			c += 1
		end
		local x = rng:NextInteger(-6, 9)
		-- a(x + b) = cx + k  ->  k = a*x + a*b - c*x
		local k = a * x + a * b - c * x
		local right = if k == 0 then string.format("%dx", c) else string.format("%dx %s", c, signed(k))
		return {
			topic = "Ecuacion con parentesis",
			prompt = string.format("Despeja x:   %d(x + %d) = %s", a, b, right),
			answer = string.format("x = %d", x),
			distractors = {
				string.format("x = %s", num((k + a * b) / (a - c))),
				string.format("x = %s", num((k - a * b) / (a + c))),
				string.format("x = %d", x + 2),
			},
			steps = {
				{ title = "1. Distribuis el parentesis",
				  body = string.format("%dx + %d = %s", a, a * b, right) },
				{ title = "2. Agrupas las x de un lado",
				  body = string.format("%dx - %dx = %d - %d", a, c, k, a * b) },
				{ title = "3. Operas",
				  body = string.format("%s = %d", term(a - c, "x"), k - a * b) },
				{ title = "4. Despejas",
				  body = string.format("x = %d / %d = %d", k - a * b, a - c, x) },
			},
		}
	end,
	function(rng: Random): Raw
		local x, y = rng:NextInteger(1, 9), rng:NextInteger(1, 9)
		local s = x + y
		local a = rng:NextInteger(2, 5)
		local d = a * x - y
		return {
			topic = "Sistema de ecuaciones 2x2",
			prompt = string.format("x + y = %d ;  %dx - y = %d.  Cuanto vale x?", s, a, d),
			answer = string.format("x = %d", x),
			distractors = {
				string.format("x = %d", y),
				string.format("x = %d", math.max(1, s - a)),
				string.format("x = %s", num(s / 2)),
			},
			steps = {
				{ title = "1. Sumas las dos ecuaciones (se cancela y)",
				  body = string.format("(x + y) + (%dx - y) = %d + %d", a, s, d) },
				{ title = "2. Queda solo x",
				  body = string.format("%dx = %d", 1 + a, s + d) },
				{ title = "3. Despejas x",
				  body = string.format("x = %d / %d = %d", s + d, 1 + a, x) },
				{ title = "4. Y de yapa, y",
				  body = string.format("y = %d - %d = %d", s, x, y) },
			},
		}
	end,
}

-- Dificultad 5 ─ cuadraticas y Pitagoras
generators[5] = {
	function(rng: Random): Raw
		local r1 = rng:NextInteger(-7, 7)
		local r2 = rng:NextInteger(-7, 7)
		if r2 == r1 then
			r2 += 1
		end
		local b, c = -(r1 + r2), r1 * r2
		local big = math.max(r1, r2)
		return {
			topic = "Ecuacion cuadratica",
			prompt = string.format("x² %s %s = 0.  Cual es la raiz mayor?", signedTerm(b, "x"), signed(c)),
			answer = string.format("x = %d", big),
			distractors = {
				string.format("x = %d", math.min(r1, r2)),
				string.format("x = %d", -big),
				string.format("x = %s", num(b / 2)),
			},
			steps = {
				{ title = "1. Formula resolvente",
				  body = string.format("x = (-b ± √(b² - 4ac)) / 2a,  con a = 1, b = %d, c = %d", b, c) },
				{ title = "2. Discriminante",
				  body = string.format("Δ = (%d)² - 4·1·(%d) = %d - %d = %d", b, c, b * b, 4 * c, b * b - 4 * c) },
				{ title = "3. Raices",
				  body = string.format("x = (%d ± %s) / 2  →  x₁ = %d,  x₂ = %d", -b, num(math.sqrt(b * b - 4 * c)), math.max(r1, r2), math.min(r1, r2)) },
				{ title = "4. Te pide la mayor",
				  body = string.format("x = %d", big) },
			},
		}
	end,
	function(rng: Random): Raw
		local triples = { { 3, 4, 5 }, { 6, 8, 10 }, { 5, 12, 13 }, { 8, 15, 17 }, { 9, 12, 15 }, { 7, 24, 25 } }
		local t = triples[rng:NextInteger(1, #triples)]
		local a, b, c = t[1], t[2], t[3]
		return {
			topic = "Teorema de Pitagoras",
			prompt = string.format("Un triangulo rectangulo tiene catetos de %d y %d cm. Cuanto mide la hipotenusa?", a, b),
			answer = string.format("%d cm", c),
			distractors = {
				string.format("%d cm", a + b),
				string.format("%d cm", c + 1),
				string.format("%s cm", num(math.sqrt(math.abs(b * b - a * a)))),
			},
			steps = {
				{ title = "1. Planteo",
				  body = "h² = cateto₁² + cateto₂²" },
				{ title = "2. Reemplazas",
				  body = string.format("h² = %d² + %d² = %d + %d = %d", a, b, a * a, b * b, a * a + b * b) },
				{ title = "3. Raiz cuadrada",
				  body = string.format("h = √%d = %d", a * a + b * b, c) },
				{ title = "4. Respuesta",
				  body = string.format("La hipotenusa mide %d cm", c) },
			},
		}
	end,
}

-- ─────────────────────────────────────────────────────────────
-- API
-- ─────────────────────────────────────────────────────────────

--- Arma una pregunta unica y reproducible para una dificultad dada.
function MathEngine.buildQuestion(id: number, difficulty: number, rng: Random): Question
	difficulty = math.clamp(difficulty, 1, #generators)
	local pool = generators[difficulty]
	local raw = pool[rng:NextInteger(1, #pool)](rng)

	-- Opciones: la correcta + 3 distractores unicos.
	local choices = { raw.answer }
	local used = { [raw.answer] = true }
	for _, option in raw.distractors do
		if not used[option] and #choices < 4 then
			used[option] = true
			table.insert(choices, option)
		end
	end
	-- Relleno por si algun distractor colisiono con la respuesta correcta.
	local fillers = { "Ninguna de las anteriores", "No se puede determinar", "Faltan datos" }
	for _, option in fillers do
		if #choices >= 4 then
			break
		end
		if not used[option] then
			used[option] = true
			table.insert(choices, option)
		end
	end

	shuffle(choices, rng)
	local answerIndex = table.find(choices, raw.answer) or 1

	return {
		id = id,
		topic = raw.topic,
		prompt = raw.prompt,
		choices = choices,
		answerIndex = answerIndex,
		steps = raw.steps,
		difficulty = difficulty,
	}
end

--- Prueba completa. El seed hace que la prueba sea igual para todos
--- los alumnos de la ronda (asi tiene sentido copiarse, ojo).
function MathEngine.buildExam(seed: number, count: number, curve: { number }): { Question }
	local rng = Random.new(seed)
	local exam = table.create(count)
	for i = 1, count do
		local difficulty = curve[math.min(i, #curve)] or 1
		exam[i] = MathEngine.buildQuestion(i, difficulty, rng)
	end
	return exam
end

--- Version "publica" de una pregunta: sin la respuesta ni los pasos.
function MathEngine.sanitize(question: Question)
	return {
		id = question.id,
		topic = question.topic,
		prompt = question.prompt,
		choices = question.choices,
		difficulty = question.difficulty,
	}
end

return MathEngine

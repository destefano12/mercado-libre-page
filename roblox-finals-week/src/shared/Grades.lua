--!strict
--[[
	Grades
	------------------------------------------------------------------
	La aritmetica de las notas, en un solo lugar, porque la usan el
	servidor (para calcular el boletin) y el cliente (para pintarla).
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Grades = {}

export type Boletin = {
	examen: number,
	conducta: number,
	final: number,
	letra: string,
	aprobado: boolean,
	aciertos: number,
	total: number,
	castigos: number,
}

function Grades.clamp(value: number): number
	return math.clamp(value, Config.Notas.Minima, Config.Notas.Maxima)
end

--- Letra que le corresponde a un puntaje de 0 a 100.
function Grades.letter(score: number): string
	for _, tier in Config.Notas.Escala do
		if score >= tier[1] then
			return tier[2] :: string
		end
	end
	return "F"
end

function Grades.passed(score: number): boolean
	return score >= Config.Notas.Aprobado
end

--- Puntaje del examen a partir de aciertos / errores / sin responder.
function Grades.examScore(correct: number, wrong: number, blank: number): number
	local total = correct + wrong + blank
	if total <= 0 then
		return Config.Notas.Inicial
	end
	local raw = correct * Config.Examen.PuntosPorAcierto
		+ wrong * Config.Examen.PuntosPorError
		+ blank * Config.Examen.PuntosSinResponder
	local best = total * Config.Examen.PuntosPorAcierto
	return Grades.clamp((raw / best) * 100)
end

--- Nota de conducta: arranca en 100 y le restan los castigos y la sospecha.
function Grades.behaviourScore(punishments: number, peakSuspicion: number): number
	local score = 100 - punishments * Config.Castigo.PenalizacionNota - peakSuspicion * 18
	return Grades.clamp(score)
end

--- El boletin del dia: examen + conducta, con los pesos de Config.
function Grades.report(correct: number, wrong: number, blank: number, punishments: number, peak: number): Boletin
	local examen = Grades.examScore(correct, wrong, blank)
	local conducta = Grades.behaviourScore(punishments, peak)
	local final = Grades.clamp(examen * Config.Notas.PesoExamen + conducta * Config.Notas.PesoConducta)
	return {
		examen = math.floor(examen + 0.5),
		conducta = math.floor(conducta + 0.5),
		final = math.floor(final + 0.5),
		letra = Grades.letter(final),
		aprobado = Grades.passed(final),
		aciertos = correct,
		total = correct + wrong + blank,
		castigos = punishments,
	}
end

--- Promedio del trimestre a partir de los boletines de la semana.
function Grades.average(reports: { number }): number
	if #reports == 0 then
		return Config.Notas.Inicial
	end
	local sum = 0
	for _, value in reports do
		sum += value
	end
	return Grades.clamp(sum / #reports)
end

return Grades

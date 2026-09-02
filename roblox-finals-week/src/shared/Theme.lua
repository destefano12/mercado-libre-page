--!strict
--[[
	Theme
	------------------------------------------------------------------
	Paleta unica de todo el juego. Estetica de instituto: papel crema,
	tinta azul, verde pizarra y el rojo de la libreta de sanciones.
--]]

local Theme = {}

Theme.Font = Enum.Font.GothamMedium
Theme.FontBold = Enum.Font.GothamBold
Theme.FontBlack = Enum.Font.GothamBlack
Theme.FontMono = Enum.Font.Code
-- Para lo que en el mundo esta escrito a mano: el nombre en el carnet,
-- las notas que se pasan los alumnos. No para interfaz de sistema.
Theme.FontHand = Enum.Font.PatrickHand

-- Hoja del examen sobre el pupitre.
Theme.Paper = {
	Background = Color3.fromRGB(249, 247, 240),
	Ink = Color3.fromRGB(34, 38, 48),
	InkSoft = Color3.fromRGB(112, 119, 133),
	Line = Color3.fromRGB(204, 208, 218),
	Accent = Color3.fromRGB(28, 92, 186),
	Correct = Color3.fromRGB(30, 142, 84),
	Wrong = Color3.fromRGB(198, 52, 52),
	Highlight = Color3.fromRGB(252, 232, 140),
}

-- HUD: barra oscura translucida, tipo overlay de juego moderno.
Theme.Hud = {
	Panel = Color3.fromRGB(15, 16, 21),
	PanelSoft = Color3.fromRGB(26, 28, 35),
	Line = Color3.fromRGB(54, 58, 70),
	Text = Color3.fromRGB(238, 241, 247),
	Muted = Color3.fromRGB(140, 147, 160),
	Safe = Color3.fromRGB(52, 196, 122),
	Warn = Color3.fromRGB(242, 178, 52),
	Danger = Color3.fromRGB(233, 62, 62),
	Credit = Color3.fromRGB(246, 200, 84),
	Clock = Color3.fromRGB(226, 232, 244),
}

-- Menu de inicio y tienda.
Theme.Menu = {
	Scrim = Color3.fromRGB(9, 10, 13),
	Panel = Color3.fromRGB(16, 17, 22),
	PanelAlt = Color3.fromRGB(24, 26, 33),
	Line = Color3.fromRGB(56, 60, 71),
	Text = Color3.fromRGB(240, 242, 246),
	Muted = Color3.fromRGB(136, 143, 156),
	Accent = Color3.fromRGB(226, 228, 234),
	Locked = Color3.fromRGB(88, 93, 105),
}

-- Acentos de instituto noventoso. Son los unicos colores saturados
-- del juego y estan para que la interfaz no sea una escala de grises.
Theme.Brand = {
	Teal = Color3.fromRGB(38, 166, 178),
	Mustard = Color3.fromRGB(240, 186, 62),
	Tomato = Color3.fromRGB(228, 84, 62),
	Grape = Color3.fromRGB(126, 92, 178),
	Mint = Color3.fromRGB(96, 198, 148),
	Cream = Color3.fromRGB(246, 238, 214),
	Chalk = Color3.fromRGB(232, 240, 236),
}

-- Chrome de la interfaz nueva: cinco niveles de profundidad en vez de
-- los cinco valores sueltos de transparencia que habia antes.
Theme.Surface = {
	Deep = Color3.fromRGB(12, 14, 19),
	Base = Color3.fromRGB(19, 22, 29),
	Raised = Color3.fromRGB(28, 32, 41),
	Hover = Color3.fromRGB(38, 43, 54),
	Line = Color3.fromRGB(58, 64, 78),
	Text = Color3.fromRGB(240, 243, 248),
	Muted = Color3.fromRGB(146, 154, 168),
	Faint = Color3.fromRGB(96, 103, 116),
}

Theme.Grade = {
	A = Color3.fromRGB(52, 196, 122),
	B = Color3.fromRGB(120, 196, 96),
	C = Color3.fromRGB(242, 196, 68),
	D = Color3.fromRGB(238, 146, 52),
	F = Color3.fromRGB(233, 62, 62),
}

function Theme.suspicionColor(value: number): Color3
	if value < 0.4 then
		return Theme.Hud.Safe:Lerp(Theme.Hud.Warn, value / 0.4)
	end
	return Theme.Hud.Warn:Lerp(Theme.Hud.Danger, math.clamp((value - 0.4) / 0.6, 0, 1))
end

function Theme.gradeColor(letter: string): Color3
	return (Theme.Grade :: any)[letter] or Theme.Hud.Muted
end

table.freeze(Theme)
return Theme

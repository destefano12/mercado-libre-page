--!strict
--[[
	Theme
	------------------------------------------------------------------
	Paleta unica para todo lo que se dibuja sobre superficies 3D
	(hoja de la prueba, pantalla del celular, HUD de accion).
--]]

local Theme = {}

Theme.Font = Enum.Font.GothamMedium
Theme.FontBold = Enum.Font.GothamBold
Theme.FontMono = Enum.Font.Code

Theme.Paper = {
	Background = Color3.fromRGB(250, 249, 244),
	Ink = Color3.fromRGB(38, 42, 52),
	InkSoft = Color3.fromRGB(108, 116, 130),
	Line = Color3.fromRGB(206, 210, 219),
	Accent = Color3.fromRGB(28, 96, 190),
	Correct = Color3.fromRGB(31, 145, 84),
	Wrong = Color3.fromRGB(196, 54, 54),
}

-- Pantalla del celular: interfaz de RoGPT (oscura, tipo app de chat)
Theme.Phone = {
	Background = Color3.fromRGB(16, 17, 21),
	Surface = Color3.fromRGB(28, 30, 36),
	SurfaceAlt = Color3.fromRGB(38, 41, 48),
	Text = Color3.fromRGB(238, 240, 245),
	TextSoft = Color3.fromRGB(150, 156, 168),
	Accent = Color3.fromRGB(16, 163, 127),   -- verde "asistente"
	User = Color3.fromRGB(45, 95, 210),
	Danger = Color3.fromRGB(220, 66, 66),
	Battery = Color3.fromRGB(94, 216, 130),
}

Theme.Hud = {
	Safe = Color3.fromRGB(52, 199, 123),
	Warn = Color3.fromRGB(240, 178, 52),
	Danger = Color3.fromRGB(232, 62, 62),
	Panel = Color3.fromRGB(18, 19, 24),
	Text = Color3.fromRGB(240, 242, 247),
}

-- Menu de inicio: casi monocromo, tipografia fina, mucho aire.
Theme.Menu = {
	Scrim = Color3.fromRGB(10, 11, 14),
	Panel = Color3.fromRGB(16, 17, 21),
	Line = Color3.fromRGB(58, 62, 72),
	Text = Color3.fromRGB(240, 242, 246),
	Muted = Color3.fromRGB(138, 144, 156),
	Accent = Color3.fromRGB(226, 228, 234),
}

function Theme.riskColor(risk: number): Color3
	if risk < 0.35 then
		return Theme.Hud.Safe:Lerp(Theme.Hud.Warn, risk / 0.35)
	end
	return Theme.Hud.Warn:Lerp(Theme.Hud.Danger, math.clamp((risk - 0.35) / 0.65, 0, 1))
end

table.freeze(Theme)
return Theme

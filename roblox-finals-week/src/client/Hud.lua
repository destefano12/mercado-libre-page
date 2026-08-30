--!strict
--[[
	Hud
	------------------------------------------------------------------
	La capa que ves siempre: reloj del examen, barra de sospecha, nota
	del trimestre, creditos, avisos, lo que dice el profesor, el cono
	tapandote la pantalla y el boletin del dia.

	Todo lo que llega del servidor viene como { key = ..., args = ... }
	y se dibuja con Strings.get: por eso el HUD entero cambia de idioma
	con el idioma que cada jugador tenga puesto en Roblox.

	Lo que cambio respecto de la version anterior:

	- Los paneles eran rectangulos con texto. Ahora cada uno lleva su
	  icono vectorial (`UI.icon`) — sin subir un solo asset.
	- Los creditos saltaban de 120 a 165. Ahora suben contando: el
	  salto seco no comunica que ganaste algo.
	- La barra de sospecha era una barra lisa. Ahora tiene marcas de
	  segmento y late al cruzar el umbral, que es donde importa.
	- Los avisos aparecian de golpe. Ahora entran deslizando y llevan
	  icono segun el tipo.
	- El boletin se reconstruia entero con `ClearAllChildren()` en cada
	  llamada — lo que borraba tambien su UICorner y su UIStroke, que
	  habia que volver a crear. Ahora se arma una sola vez en `mount` y
	  `report` solo rellena texto; las filas entran escalonadas.
	- `LayoutOrder` de los avisos era `os.clock()*1000 % 100000`, que da
	  la vuelta cada ~100 segundos y da vuelta el orden de apilado. Ahora
	  es un contador que solo sube.
--]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Strings = require(Shared:WaitForChild("Strings"))
local Config = require(Shared:WaitForChild("Config"))
local UI = require(Shared:WaitForChild("UI"))

local Hud = {}

local root: ScreenGui
local clockLabel: TextLabel
local phaseLabel: TextLabel
local dayLabel: TextLabel
local gradeValue: TextLabel
local creditLabel: TextLabel
local scoreLabel: TextLabel
local suspicionFill: Frame
local suspicionLabel: TextLabel
local objective: TextLabel
local warning: TextLabel
local vignette: Frame
local toasts: Frame
local subtitle: Frame
local subtitleText: TextLabel
local coneOverlay: Frame
local punishLabel: TextLabel
local reportCard: Frame

-- Piezas del boletin, creadas una vez y rellenadas despues.
local reportTitle: TextLabel
local reportSubtitle: TextLabel
local reportClass: TextLabel
local reportGrade: TextLabel
local reportRows: { { line: TextLabel, value: TextLabel } } = {}
local reportFoot: TextLabel

local state = { fase = "espera", cerca = false, valor = 0 }
local pulse = 0
local hudVisible = true
local lastCredits = 0
local lastGrade = ""
local toastOrder = 0

local REPORT_ROWS = 6

-- ── helpers ────────────────────────────────────────────────────────

local function clockText(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", math.floor(total / 60), total % 60)
end

local function hudPanel(name: string, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local frame = UI.panel({
		parent = root,
		name = name,
		size = size,
		position = position,
		anchor = anchor,
		color = Theme.Surface.Deep,
		transparency = 0.14,
		radius = UI.Radius.md,
		layer = UI.Layer.Hud,
	})
	return frame :: Frame
end

local function hudLabel(parent: Instance, name: string, text: string, size: UDim2,
	position: UDim2, font: Enum.Font, textSize: number, color: Color3,
	align: Enum.TextXAlignment?): TextLabel
	return UI.label({
		parent = parent,
		name = name,
		text = text,
		size = size,
		position = position,
		font = font,
		textSize = textSize,
		color = color,
		align = align or Enum.TextXAlignment.Left,
		layer = UI.Layer.Hud + 1,
	})
end

--[[
	La vinaeta roja de "te esta mirando": cuatro tiras con degradado
	hacia adentro. Sigue siendo la solucion correcta — una imagen de
	vinaeta habria que subirla y no escalaria a cualquier resolucion.
--]]
local function buildVignette(parent: Instance): Frame
	local holder = UI.new("Frame", {
		Name = "Vinaeta",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = UI.Layer.Overlay,
		Parent = parent,
	})

	local edges = {
		{ UDim2.new(1, 0, 0, 130), UDim2.fromScale(0, 0), Vector2.new(0, 0), 90 },
		{ UDim2.new(1, 0, 0, 130), UDim2.fromScale(0, 1), Vector2.new(0, 1), 270 },
		{ UDim2.new(0, 160, 1, 0), UDim2.fromScale(0, 0), Vector2.new(0, 0), 0 },
		{ UDim2.new(0, 160, 1, 0), UDim2.fromScale(1, 0), Vector2.new(1, 0), 180 },
	}
	for _, edge in edges do
		local strip = UI.new("Frame", {
			Size = edge[1],
			Position = edge[2],
			AnchorPoint = edge[3],
			BackgroundColor3 = Theme.Hud.Danger,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			ZIndex = UI.Layer.Overlay,
			Parent = holder,
		})
		UI.new("UIGradient", {
			Rotation = edge[4],
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = strip,
		})
	end
	return holder
end

--- El cono de la verguenza tapandote media pantalla.
local function buildCone(parent: Instance): Frame
	local holder = UI.new("Frame", {
		Name = "Cono",
		Size = UDim2.fromScale(1, 0.42),
		Position = UDim2.fromScale(0, 0.58),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = UI.Layer.Overlay,
		Parent = parent,
	})

	local band = UI.new("Frame", {
		Name = "Ala",
		Size = UDim2.new(1.4, 0, 1, 0),
		Position = UDim2.fromScale(0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(228, 74, 62),
		BorderSizePixel = 0,
		ZIndex = UI.Layer.Overlay,
		Parent = holder,
	})
	UI.new("UICorner", { CornerRadius = UDim.new(0, 400), Parent = band })

	for i = 0, 7 do
		UI.new("Frame", {
			Size = UDim2.new(0.06, 0, 1, 0),
			Position = UDim2.fromScale(i * 0.14, 0),
			BackgroundColor3 = Color3.fromRGB(246, 246, 240),
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			ZIndex = UI.Layer.Overlay + 1,
			Parent = band,
		})
	end
	return holder
end

-- Icono y color del aviso segun de que habla la clave. Es una
-- heuristica por prefijo, no un campo del paquete: el servidor manda
-- claves y no deberia tener que saber como las dibuja el cliente.
local function toastLook(key: string): (string, Color3)
	if string.find(key, "^shop%.") then
		return "moneda", Theme.Hud.Credit
	elseif string.find(key, "^ball%.") then
		return "pelota", Theme.Brand.Mustard
	elseif string.find(key, "^radio%.") then
		return "radio", Theme.Brand.Teal
	elseif string.find(key, "^book%.") or string.find(key, "^nerd%.") then
		return "libro", Theme.Brand.Grape
	elseif string.find(key, "punish") or string.find(key, "castigo")
		or string.find(key, "^error%.") then
		return "alerta", Theme.Hud.Danger
	elseif string.find(key, "passed") or string.find(key, "bought") then
		return "tilde", Theme.Brand.Mint
	end
	return "campana", Theme.Surface.Muted
end

-- ── construccion ───────────────────────────────────────────────────

function Hud.mount(parent: ScreenGui)
	root = parent

	-- Reloj y fase, arriba al centro.
	local top = hudPanel("Reloj", UDim2.fromOffset(248, 80),
		UDim2.new(0.5, 0, 0, 14), Vector2.new(0.5, 0))
	UI.icon(top, "reloj", 16, Theme.Surface.Muted, UI.Layer.Hud + 1).Position =
		UDim2.fromOffset(12, 9)
	phaseLabel = hudLabel(top, "Fase", "", UDim2.new(1, -24, 0, 18),
		UDim2.fromOffset(12, 8), Theme.FontBold, UI.Type.small, Theme.Surface.Muted,
		Enum.TextXAlignment.Center)
	clockLabel = hudLabel(top, "Tiempo", "00:00", UDim2.new(1, -24, 0, 36),
		UDim2.fromOffset(12, 26), Theme.FontBlack, UI.Type.display, Theme.Hud.Clock,
		Enum.TextXAlignment.Center)
	dayLabel = hudLabel(top, "Dia", "", UDim2.new(1, -24, 0, 16),
		UDim2.fromOffset(12, 60), Theme.Font, UI.Type.small, Theme.Surface.Muted,
		Enum.TextXAlignment.Center)

	-- Nota y creditos, arriba a la izquierda.
	local left = hudPanel("Nota", UDim2.fromOffset(196, 80),
		UDim2.fromOffset(14, 14), Vector2.new(0, 0))
	hudLabel(left, "Titulo", Strings.get("hud.grade"), UDim2.new(1, -24, 0, 16),
		UDim2.fromOffset(14, 9), Theme.FontBold, UI.Type.micro, Theme.Surface.Muted)
	gradeValue = hudLabel(left, "Valor", "60  D", UDim2.new(1, -24, 0, 30),
		UDim2.fromOffset(14, 25), Theme.FontBlack, UI.Type.display - 4, Theme.Surface.Text)
	UI.icon(left, "moneda", 13, Theme.Hud.Credit, UI.Layer.Hud + 1).Position =
		UDim2.fromOffset(14, 58)
	creditLabel = hudLabel(left, "Creditos", "0 cr", UDim2.new(1, -44, 0, 16),
		UDim2.fromOffset(32, 57), Theme.FontBold, UI.Type.small, Theme.Hud.Credit)

	-- Marcador de canastas del recreo.
	local court = hudPanel("Canastas", UDim2.fromOffset(196, 36),
		UDim2.fromOffset(14, 100), Vector2.new(0, 0))
	court.Visible = false
	UI.icon(court, "pelota", 14, Theme.Brand.Mustard, UI.Layer.Hud + 1).Position =
		UDim2.fromOffset(14, 11)
	scoreLabel = hudLabel(court, "Valor", "", UDim2.new(1, -44, 1, 0),
		UDim2.fromOffset(34, 0), Theme.FontBold, UI.Type.small, Theme.Surface.Text)

	-- Barra de sospecha, abajo al centro.
	local bottom = hudPanel("Sospecha", UDim2.fromOffset(340, 56),
		UDim2.new(0.5, 0, 1, -18), Vector2.new(0.5, 1))
	UI.icon(bottom, "ojo", 14, Theme.Surface.Muted, UI.Layer.Hud + 1).Position =
		UDim2.fromOffset(14, 9)
	suspicionLabel = hudLabel(bottom, "Titulo", Strings.get("hud.suspicion"),
		UDim2.new(1, -50, 0, 14), UDim2.fromOffset(34, 9), Theme.FontBold,
		UI.Type.micro, Theme.Surface.Muted)

	local track = UI.new("Frame", {
		Name = "Barra",
		Size = UDim2.new(1, -28, 0, 12),
		Position = UDim2.fromOffset(14, 30),
		BackgroundColor3 = Theme.Surface.Raised,
		BorderSizePixel = 0,
		ZIndex = UI.Layer.Hud + 1,
		Parent = bottom,
	})
	UI.corner(track, 6)

	suspicionFill = UI.new("Frame", {
		Name = "Relleno",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Hud.Safe,
		BorderSizePixel = 0,
		ZIndex = UI.Layer.Hud + 2,
		Parent = track,
	})
	UI.corner(suspicionFill, 6)

	-- Marcas de segmento: dan escala a la barra. Sin ellas, "medio
	-- llena" y "tres cuartos" se ven casi igual.
	for i = 1, 7 do
		UI.new("Frame", {
			Name = "Marca" .. i,
			Size = UDim2.new(0, 1, 1, -4),
			Position = UDim2.new(i / 8, 0, 0, 2),
			BackgroundColor3 = Theme.Surface.Deep,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			ZIndex = UI.Layer.Hud + 3,
			Parent = track,
		})
	end

	-- Objetivo y teclas, abajo a la izquierda.
	local guide = hudPanel("Objetivo", UDim2.fromOffset(330, 62),
		UDim2.new(0, 14, 1, -18), Vector2.new(0, 1))
	objective = hudLabel(guide, "Texto", "", UDim2.new(1, -28, 0, 20),
		UDim2.fromOffset(14, 9), Theme.FontBold, UI.Type.body, Theme.Surface.Text)
	hudLabel(guide, "Teclas", Strings.get("hud.keys"), UDim2.new(1, -28, 0, 16),
		UDim2.fromOffset(14, 34), Theme.Font, UI.Type.micro, Theme.Surface.Muted)

	-- Aviso grande de "te esta mirando".
	warning = hudLabel(root, "Aviso", Strings.get("hud.close_call"),
		UDim2.new(1, 0, 0, 30), UDim2.fromOffset(0, 104), Theme.FontBlack,
		UI.Type.title + 2, Theme.Hud.Danger, Enum.TextXAlignment.Center)
	warning.Visible = false
	warning.ZIndex = UI.Layer.Overlay + 2

	vignette = buildVignette(root)

	-- Avisos cortos, apilados a la derecha.
	toasts = UI.new("Frame", {
		Name = "Avisos",
		Size = UDim2.fromOffset(310, 300),
		Position = UDim2.new(1, -14, 0, 104),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		ZIndex = UI.Layer.Toast,
		Parent = root,
	})
	UI.new("UIListLayout", {
		Padding = UDim.new(0, UI.Space.xs + 2),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = toasts,
	})

	-- Lo que dice el profesor.
	subtitle = hudPanel("Profesor", UDim2.fromOffset(470, 48),
		UDim2.new(0.5, 0, 1, -88), Vector2.new(0.5, 1))
	subtitle.Visible = false
	subtitleText = hudLabel(subtitle, "Texto", "", UDim2.new(1, -28, 1, 0),
		UDim2.fromOffset(14, 0), Theme.Font, UI.Type.subtitle - 1, Theme.Surface.Text,
		Enum.TextXAlignment.Center)

	coneOverlay = buildCone(root)
	punishLabel = hudLabel(root, "Castigo", "", UDim2.new(1, 0, 0, 24),
		UDim2.fromOffset(0, 152), Theme.FontBold, UI.Type.subtitle, Theme.Hud.Warn,
		Enum.TextXAlignment.Center)
	punishLabel.Visible = false
	punishLabel.ZIndex = UI.Layer.Overlay + 2

	-- El boletin: se arma aca una sola vez.
	reportCard = UI.panel({
		parent = root,
		name = "Boletin",
		-- Mas alto que antes: ahora el boletin encabeza con el resultado
		-- del curso y despues va el tuyo.
		size = UDim2.fromOffset(400, 366),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		color = Theme.Surface.Base,
		radius = UI.Radius.lg,
		layer = UI.Layer.Modal,
	}) :: Frame
	reportCard.Visible = false

	reportTitle = UI.label({
		parent = reportCard,
		name = "Titulo",
		text = Strings.get("report.title"),
		size = UDim2.new(1, -36, 0, 20),
		position = UDim2.fromOffset(18, 16),
		font = Theme.FontBold,
		textSize = UI.Type.small,
		color = Theme.Surface.Muted,
		layer = UI.Layer.Modal + 1,
	})
	reportSubtitle = UI.label({
		parent = reportCard,
		name = "Subtitulo",
		size = UDim2.new(1, -36, 0, 26),
		position = UDim2.fromOffset(18, 36),
		font = Theme.FontBlack,
		textSize = UI.Type.title + 2,
		color = Theme.Surface.Text,
		layer = UI.Layer.Modal + 1,
	})
	--[[
		El resultado del CURSO, encabezando el boletin.

		Aprobar es colectivo: el dia se pierde si el promedio de la clase
		no llega, sin importar como te fue a vos. Eso ya funcionaba, pero
		el boletin solo mostraba tu nota, asi que la regla era invisible.
		Va arriba de todo, antes que tu propio resultado.
	--]]
	reportClass = UI.label({
		parent = reportCard,
		name = "Curso",
		size = UDim2.new(1, -36, 0, 22),
		position = UDim2.fromOffset(18, 64),
		font = Theme.FontBold,
		textSize = UI.Type.subtitle,
		color = Theme.Surface.Muted,
		layer = UI.Layer.Modal + 1,
	})

	reportGrade = UI.label({
		parent = reportCard,
		name = "Nota",
		size = UDim2.new(1, -36, 0, 56),
		position = UDim2.fromOffset(18, 88),
		font = Theme.FontBlack,
		textSize = UI.Type.hero,
		color = Theme.Surface.Text,
		layer = UI.Layer.Modal + 1,
	})

	for i = 1, REPORT_ROWS do
		local y = 156 + (i - 1) * 24
		reportRows[i] = {
			line = UI.label({
				parent = reportCard,
				name = "Fila" .. i,
				size = UDim2.new(1, -36, 0, 20),
				position = UDim2.fromOffset(18, y),
				font = Theme.Font,
				textSize = UI.Type.body,
				color = Theme.Surface.Muted,
				layer = UI.Layer.Modal + 1,
			}),
			value = UI.label({
				parent = reportCard,
				name = "Valor" .. i,
				size = UDim2.fromOffset(64, 20),
				position = UDim2.new(1, -82, 0, y),
				font = Theme.FontBold,
				textSize = UI.Type.body,
				color = Theme.Surface.Text,
				align = Enum.TextXAlignment.Right,
				layer = UI.Layer.Modal + 1,
			}),
		}
	end

	reportFoot = UI.label({
		parent = reportCard,
		name = "Pie",
		size = UDim2.new(1, -36, 0, 36),
		position = UDim2.new(0, 18, 1, -48),
		font = Theme.FontBold,
		textSize = UI.Type.body,
		color = Theme.Surface.Text,
		align = Enum.TextXAlignment.Center,
		wrapped = true,
		layer = UI.Layer.Modal + 1,
	})

	RunService.RenderStepped:Connect(function(dt)
		pulse += dt
		-- El bucle tambien se apaga con el HUD: antes seguia latiendo
		-- con el menu abierto encima.
		if hudVisible and state.cerca and state.fase == "examen" then
			local alpha = 0.5 + 0.5 * math.sin(pulse * 7)
			vignette.Visible = true
			for _, strip in vignette:GetChildren() do
				if strip:IsA("Frame") then
					strip.BackgroundTransparency = 0.25 + alpha * 0.35
				end
			end
			warning.Visible = true
			warning.TextTransparency = 0.15 + alpha * 0.5
		else
			vignette.Visible = false
			warning.Visible = false
		end
	end)
end

-- ── actualizaciones ────────────────────────────────────────────────

local OBJETIVOS = {
	espera = "notify.waiting",
	recreo = "hud.hint_recess",
	examen = "hud.hint_exam",
	boletin = "hud.hint_report",
	intermedio = "hud.hint_report",
}

function Hud.setRound(data: any)
	if not clockLabel then
		return
	end
	state.fase = data.fase

	phaseLabel.Text = Strings.get("phase." .. tostring(data.fase))
	clockLabel.Text = clockText(data.restante or 0)
	clockLabel.TextColor3 = (data.fase == "examen" and (data.restante or 0) <= 30)
		and Theme.Hud.Danger or Theme.Hud.Clock
	dayLabel.Text = Strings.get("hud.day", {
		n = data.dia,
		day = Strings.get(data.nombreDia or "day.lunes"),
	})

	local letter = data.letra or "D"
	gradeValue.Text = string.format("%d  %s", data.nota or 60, letter)
	gradeValue.TextColor3 = Theme.gradeColor(letter)

	-- La nota da un golpecito cuando cambia de letra. Es el unico
	-- momento en que ese numero merece que lo mires.
	if letter ~= lastGrade and lastGrade ~= "" then
		local scale = UI.scaler(gradeValue)
		scale.Scale = 1.35
		TweenService:Create(scale, UI.Motion.enter, { Scale = 1 }):Play()
	end
	lastGrade = letter

	objective.Text = Strings.get(OBJETIVOS[data.fase] or "hud.hint_recess")

	if data.fase ~= "examen" then
		subtitle.Visible = false
	end
end

function Hud.setSuspicion(data: any)
	if not suspicionFill then
		return
	end
	local value = math.clamp(data.valor or 0, 0, 1)
	state.valor = value
	state.cerca = data.cerca == true
	TweenService:Create(suspicionFill, UI.Motion.snap, {
		Size = UDim2.fromScale(value, 1),
		BackgroundColor3 = Theme.suspicionColor(value),
	}):Play()
	suspicionLabel.Text = string.format("%s  %d%%",
		Strings.get("hud.suspicion"), math.floor(value * 100 + 0.5))
end

function Hud.setWallet(data: any)
	if not creditLabel then
		return
	end
	local credits = data.creditos or 0
	UI.countTo(creditLabel, lastCredits, credits, 0.5, function(n: number): string
		return Strings.get("shop.price", { n = n })
	end)
	lastCredits = credits
end

function Hud.notify(packet: any)
	if not toasts or not packet or not packet.key then
		return
	end
	local args = packet.args
	if args then
		-- Los args pueden traer "@item.nota": se resuelven tambien.
		local resolved = {}
		for name, value in args do
			resolved[name] = typeof(value) == "string" and Strings.resolve(value) or value
		end
		args = resolved
	end

	local iconName, accent = toastLook(packet.key)
	toastOrder += 1

	local toast = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.Surface.Deep,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		LayoutOrder = toastOrder,
		ZIndex = UI.Layer.Toast,
		Parent = toasts,
	})
	UI.corner(toast, UI.Radius.sm)
	UI.stroke(toast, accent, 1, 0.55)

	UI.icon(toast, iconName, 14, accent, UI.Layer.Toast + 1).Position =
		UDim2.fromOffset(10, 10)

	local text = UI.label({
		parent = toast,
		name = "Texto",
		text = Strings.get(packet.key, args),
		size = UDim2.new(1, -40, 1, 0),
		position = UDim2.fromOffset(32, 0),
		font = Theme.Font,
		textSize = UI.Type.small,
		color = Theme.Surface.Text,
		layer = UI.Layer.Toast + 1,
	})
	text.TextTruncate = Enum.TextTruncate.AtEnd

	-- Entrada desde la derecha. Antes aparecian de golpe.
	toast.Position = UDim2.fromOffset(30, 0)
	TweenService:Create(toast, UI.Motion.base, { Position = UDim2.fromOffset(0, 0) }):Play()

	task.delay(3.6, function()
		if not toast.Parent then
			return
		end
		TweenService:Create(toast, UI.Motion.base, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(text, UI.Motion.base, { TextTransparency = 1 }):Play()
		task.wait(0.3)
		toast:Destroy()
	end)
end

function Hud.teacherSay(packet: any)
	if not subtitle or not packet then
		return
	end
	subtitleText.Text = string.format("%s: %s",
		packet.profesor or "", Strings.get(packet.key, packet.args))
	subtitle.Visible = true
	local token = os.clock()
	subtitle:SetAttribute("Token", token)
	task.delay(4, function()
		if subtitle:GetAttribute("Token") == token then
			subtitle.Visible = false
		end
	end)
end

--- Canastas metidas en el recreo.
function Hud.setScore(data: any)
	if not scoreLabel then
		return
	end
	local court = scoreLabel.Parent
	if court and court:IsA("GuiObject") and not court.Visible then
		court.Visible = true
		UI.show(court, 0.85)
	end
	scoreLabel.Text = Strings.get("ball.score", { n = data.puntos or 0 })
end

local PUNISH_KEY = { cono = "hud.cone", expulsion = "hud.detention" }

function Hud.punish(data: any)
	if not coneOverlay then
		return
	end
	if data.tipo == "fin" then
		coneOverlay.Visible = false
		punishLabel.Visible = false
		return
	end

	local key = PUNISH_KEY[data.tipo]
	if not key then
		-- Aturdido por la goma o por un empujon: dura poco y ya se
		-- avisa con el aviso corto y la sacudida de camara.
		return
	end
	local seconds = math.floor(data.segundos or 0)
	punishLabel.Visible = true

	if data.tipo == "cono" then
		coneOverlay.Visible = true
		-- El cono baja a la pantalla en vez de aparecer puesto.
		coneOverlay.Position = UDim2.fromScale(0, 1)
		TweenService:Create(coneOverlay, UI.Motion.enter, {
			Position = UDim2.fromScale(0, 0.58),
		}):Play()
	end

	task.spawn(function()
		for remaining = seconds, 1, -1 do
			if not punishLabel.Visible then
				return
			end
			punishLabel.Text = Strings.get(key, { s = remaining })
			task.wait(1)
		end
		coneOverlay.Visible = false
		punishLabel.Visible = false
	end)
end

-- ── boletin ────────────────────────────────────────────────────────

function Hud.report(data: any)
	if not reportCard then
		return
	end

	local subtitleText2 = data.semana and Strings.get("report.week")
		or Strings.get("report.day", { n = data.dia })
	reportTitle.Text = Strings.get("report.title")
	reportSubtitle.Text = subtitleText2

	--[[
		El curso primero. En el boletin semanal no hay promedio de clase
		que mostrar, asi que la linea se apaga en vez de mentir un cero.
	--]]
	if data.promedioClase then
		reportClass.Visible = true
		reportClass.Text = Strings.get(
			data.claseAprobo and "report.class_passed" or "report.class_failed",
			{ n = data.promedioClase })
		reportClass.TextColor3 = data.claseAprobo and Theme.Hud.Safe or Theme.Hud.Danger
	else
		reportClass.Visible = false
	end

	reportGrade.Text = tostring(data.final) .. "  " .. tostring(data.letra)
	reportGrade.TextColor3 = Theme.gradeColor(data.letra)

	local rows = {
		{ Strings.get("report.exam"), tostring(data.examen) },
		{ Strings.get("report.behaviour"), tostring(data.conducta) },
		{ Strings.get("report.correct", { ok = data.aciertos, n = data.total }), "" },
		{ Strings.get("report.punishments", { n = data.castigos }), "" },
		{ Strings.get("shop.price", { n = data.creditos }), "" },
		{ Strings.get("report.fails", { n = data.suspensos, max = data.maxSuspensos }), "" },
	}
	for i = 1, REPORT_ROWS do
		local entry = reportRows[i]
		local content = rows[i]
		entry.line.Text = content and content[1] or ""
		entry.value.Text = content and content[2] or ""
	end

	local footKey = "report.next"
	local footArgs: any = { s = Config.Ronda.SegundosBoletin }
	if data.semana then
		footKey = data.expulsado and "report.expelled" or "report.survived"
		footArgs = nil
	end
	reportFoot.Text = Strings.get(footKey, footArgs)
	reportFoot.TextColor3 = data.aprobado and Theme.Hud.Safe or Theme.Hud.Danger

	UI.show(reportCard, 0.88)

	-- La nota se estampa: entra grande y se asienta.
	local gradeScale = UI.scaler(reportGrade)
	gradeScale.Scale = 1.6
	task.delay(0.12, function()
		TweenService:Create(gradeScale, UI.Motion.enter, { Scale = 1 }):Play()
	end)

	-- Y las filas entran una detras de otra.
	local lines: { GuiObject } = {}
	for i = 1, REPORT_ROWS do
		table.insert(lines, reportRows[i].line)
	end
	UI.stagger(lines, 0.04)

	task.delay(Config.Ronda.SegundosBoletin, function()
		UI.hide(reportCard)
	end)
end

--[[
	Apaga/enciende el HUD de juego (lo usa el menu de inicio).

	La lista vieja solo cubria los seis paneles y dejaba encendidos la
	vinaeta, el aviso del profesor, el cono y el contador de castigo,
	que quedaban dibujados por encima del menu.
--]]
local PANELES = { "Reloj", "Nota", "Sospecha", "Objetivo", "Avisos", "Canastas" }

function Hud.setVisible(visible: boolean)
	if not root then
		return
	end
	hudVisible = visible
	for _, name in PANELES do
		local child = root:FindFirstChild(name)
		if child and child:IsA("GuiObject") then
			-- El marcador solo reaparece si ya hubo alguna canasta.
			if name == "Canastas" then
				child.Visible = visible and scoreLabel ~= nil and scoreLabel.Text ~= ""
			else
				child.Visible = visible
			end
		end
	end
	if not visible then
		for _, overlay in { subtitle, reportCard, coneOverlay, vignette } do
			if overlay then
				overlay.Visible = false
			end
		end
		if punishLabel then
			punishLabel.Visible = false
		end
		if warning then
			warning.Visible = false
		end
	end
end

return Hud

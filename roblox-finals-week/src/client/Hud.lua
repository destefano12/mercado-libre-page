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
--]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Strings = require(Shared:WaitForChild("Strings"))
local Config = require(Shared:WaitForChild("Config"))

local Hud = {}

local root: ScreenGui
local clockLabel: TextLabel
local phaseLabel: TextLabel
local dayLabel: TextLabel
local gradeValue: TextLabel
local creditLabel: TextLabel
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

local state = { fase = "espera", cerca = false, valor = 0 }
local pulse = 0

-- ── helpers ────────────────────────────────────────────────────────

local function new(class: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(class)
	for key, value in props do
		(instance :: any)[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function corner(gui: GuiObject, radius: number)
	new("UICorner", { CornerRadius = UDim.new(0, radius) }, gui)
end

local function stroke(gui: GuiObject, color: Color3, thickness: number?)
	new("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Transparency = 0.35,
	}, gui)
end

local function panel(parent: Instance, name: string, size: UDim2, position: UDim2,
	anchor: Vector2): Frame
	local frame = new("Frame", {
		Name = name,
		Size = size,
		Position = position,
		AnchorPoint = anchor,
		BackgroundColor3 = Theme.Hud.Panel,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
	}, parent)
	corner(frame, 10)
	stroke(frame, Theme.Hud.Line)
	return frame
end

local function label(parent: Instance, name: string, text: string, size: UDim2,
	position: UDim2, font: Enum.Font, textSize: number, color: Color3,
	align: Enum.TextXAlignment?): TextLabel
	return new("TextLabel", {
		Name = name,
		Text = text,
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
		Font = font,
		TextSize = textSize,
		TextColor3 = color,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, parent)
end

local function clockText(seconds: number): string
	local minutes = math.floor(seconds / 60)
	return string.format("%02d:%02d", minutes, math.floor(seconds % 60))
end

-- ── construccion ───────────────────────────────────────────────────

--- La viñeta roja: cuatro tiras con degradado hacia adentro. No usa
--- ninguna imagen, asi que no depende de subir ningun asset.
local function buildVignette(parent: Instance): Frame
	local holder = new("Frame", {
		Name = "Vinieta",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 2,
	}, parent)

	local edges = {
		{ UDim2.new(1, 0, 0, 130), UDim2.fromScale(0, 0), Vector2.new(0, 0), 90 },
		{ UDim2.new(1, 0, 0, 130), UDim2.fromScale(0, 1), Vector2.new(0, 1), 270 },
		{ UDim2.new(0, 160, 1, 0), UDim2.fromScale(0, 0), Vector2.new(0, 0), 0 },
		{ UDim2.new(0, 160, 1, 0), UDim2.fromScale(1, 0), Vector2.new(1, 0), 180 },
	}
	for i, edge in edges do
		local strip = new("Frame", {
			Name = "Borde" .. i,
			Size = edge[1],
			Position = edge[2],
			AnchorPoint = edge[3],
			BackgroundColor3 = Theme.Hud.Danger,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, holder)
		new("UIGradient", {
			Rotation = edge[4],
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, strip)
	end
	return holder
end

--- El cono de la verguenza visto desde adentro: una franja arriba con
--- las rayas del cono, que efectivamente te tapa parte de la pantalla.
local function buildCone(parent: Instance): Frame
	local holder = new("Frame", {
		Name = "Cono",
		Size = UDim2.new(1, 0, 0.26, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 6,
	}, parent)

	local band = new("Frame", {
		Name = "Ala",
		Size = UDim2.new(1.4, 0, 1, 0),
		Position = UDim2.fromScale(0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(228, 74, 62),
		BorderSizePixel = 0,
		ZIndex = 6,
	}, holder)
	new("UICorner", { CornerRadius = UDim.new(0, 400) }, band)

	-- Rayas blancas, como el cono de verdad.
	for i = 0, 7 do
		new("Frame", {
			Name = "Raya" .. i,
			Size = UDim2.new(0.06, 0, 1, 0),
			Position = UDim2.fromScale(i * 0.14, 0),
			BackgroundColor3 = Color3.fromRGB(246, 246, 240),
			BorderSizePixel = 0,
			ZIndex = 7,
		}, band)
	end

	return holder
end

function Hud.mount(parent: ScreenGui)
	root = parent

	-- Reloj y fase, arriba al centro.
	local top = panel(root, "Reloj", UDim2.new(0, 240, 0, 76),
		UDim2.new(0.5, 0, 0, 12), Vector2.new(0.5, 0))
	phaseLabel = label(top, "Fase", "", UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 0, 6),
		Theme.FontBold, 13, Theme.Hud.Muted, Enum.TextXAlignment.Center)
	clockLabel = label(top, "Tiempo", "00:00", UDim2.new(1, -20, 0, 34), UDim2.new(0, 10, 0, 24),
		Theme.FontBlack, 32, Theme.Hud.Clock, Enum.TextXAlignment.Center)
	dayLabel = label(top, "Dia", "", UDim2.new(1, -20, 0, 16), UDim2.new(0, 10, 0, 56),
		Theme.Font, 12, Theme.Hud.Muted, Enum.TextXAlignment.Center)

	-- Nota y creditos, arriba a la izquierda.
	local left = panel(root, "Nota", UDim2.new(0, 186, 0, 76),
		UDim2.new(0, 12, 0, 12), Vector2.new(0, 0))
	label(left, "Titulo", Strings.get("hud.grade"),
		UDim2.new(1, -20, 0, 16), UDim2.new(0, 12, 0, 8),
		Theme.FontBold, 11, Theme.Hud.Muted)
	gradeValue = label(left, "Valor", "60  D", UDim2.new(1, -20, 0, 30), UDim2.new(0, 12, 0, 24),
		Theme.FontBlack, 26, Theme.Hud.Text)
	creditLabel = label(left, "Creditos", "0 cr", UDim2.new(1, -20, 0, 16), UDim2.new(0, 12, 0, 54),
		Theme.FontBold, 13, Theme.Hud.Credit)

	-- Barra de sospecha, abajo al centro.
	local bottom = panel(root, "Sospecha", UDim2.new(0, 320, 0, 52),
		UDim2.new(0.5, 0, 1, -18), Vector2.new(0.5, 1))
	suspicionLabel = label(bottom, "Titulo", Strings.get("hud.suspicion"),
		UDim2.new(1, -24, 0, 14), UDim2.new(0, 12, 0, 7),
		Theme.FontBold, 11, Theme.Hud.Muted)
	local track = new("Frame", {
		Name = "Barra",
		Size = UDim2.new(1, -24, 0, 12),
		Position = UDim2.new(0, 12, 0, 26),
		BackgroundColor3 = Theme.Hud.PanelSoft,
		BorderSizePixel = 0,
	}, bottom)
	corner(track, 6)
	suspicionFill = new("Frame", {
		Name = "Relleno",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Hud.Safe,
		BorderSizePixel = 0,
	}, track)
	corner(suspicionFill, 6)

	-- Objetivo y teclas, abajo a la izquierda.
	local guide = panel(root, "Objetivo", UDim2.new(0, 320, 0, 60),
		UDim2.new(0, 12, 1, -18), Vector2.new(0, 1))
	objective = label(guide, "Texto", "", UDim2.new(1, -24, 0, 20), UDim2.new(0, 12, 0, 8),
		Theme.FontBold, 14, Theme.Hud.Text)
	label(guide, "Teclas", Strings.get("hud.keys"),
		UDim2.new(1, -24, 0, 16), UDim2.new(0, 12, 0, 32),
		Theme.Font, 11, Theme.Hud.Muted)

	-- Aviso grande de "te esta mirando".
	warning = label(root, "Aviso", Strings.get("hud.close_call"),
		UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 100),
		Theme.FontBlack, 22, Theme.Hud.Danger, Enum.TextXAlignment.Center)
	warning.Visible = false
	warning.ZIndex = 3

	vignette = buildVignette(root)

	-- Avisos cortos, apilados a la derecha.
	toasts = new("Frame", {
		Name = "Avisos",
		Size = UDim2.new(0, 300, 0, 300),
		Position = UDim2.new(1, -14, 0, 100),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
	}, root)
	new("UIListLayout", {
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, toasts)

	-- Lo que dice el profesor.
	subtitle = panel(root, "Profesor", UDim2.new(0, 460, 0, 46),
		UDim2.new(0.5, 0, 1, -84), Vector2.new(0.5, 1))
	subtitle.Visible = false
	subtitleText = label(subtitle, "Texto", "", UDim2.new(1, -24, 1, 0), UDim2.new(0, 12, 0, 0),
		Theme.Font, 15, Theme.Hud.Text, Enum.TextXAlignment.Center)

	coneOverlay = buildCone(root)
	punishLabel = label(root, "Castigo", "", UDim2.new(1, 0, 0, 24),
		UDim2.new(0, 0, 0, 150), Theme.FontBold, 16, Theme.Hud.Warn,
		Enum.TextXAlignment.Center)
	punishLabel.Visible = false
	punishLabel.ZIndex = 7

	-- El boletin.
	reportCard = panel(root, "Boletin", UDim2.new(0, 380, 0, 300),
		UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	reportCard.BackgroundTransparency = 0.04
	reportCard.Visible = false
	reportCard.ZIndex = 8

	RunService.RenderStepped:Connect(function(dt)
		pulse += dt
		if state.cerca and state.fase == "examen" then
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

	gradeValue.Text = string.format("%d  %s", data.nota or 60, data.letra or "D")
	gradeValue.TextColor3 = Theme.gradeColor(data.letra or "D")
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
	TweenService:Create(suspicionFill, TweenInfo.new(0.12), {
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
	creditLabel.Text = Strings.get("shop.price", { n = data.creditos or 0 })
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

	local toast = new("Frame", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Theme.Hud.Panel,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		LayoutOrder = math.floor(os.clock() * 1000) % 100000,
	}, toasts)
	corner(toast, 8)
	stroke(toast, Theme.Hud.Line)

	local text = label(toast, "Texto", Strings.get(packet.key, args),
		UDim2.new(1, -20, 1, 0), UDim2.new(0, 10, 0, 0),
		Theme.Font, 13, Theme.Hud.Text, Enum.TextXAlignment.Left)
	text.TextTruncate = Enum.TextTruncate.AtEnd

	task.delay(3.6, function()
		if not toast.Parent then
			return
		end
		TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(text, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.45)
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

function Hud.punish(data: any)
	if not coneOverlay then
		return
	end
	if data.tipo == "fin" then
		coneOverlay.Visible = false
		punishLabel.Visible = false
		return
	end

	local seconds = math.floor(data.segundos or 0)
	local key = data.tipo == "cono" and "hud.cone" or "hud.detention"
	coneOverlay.Visible = data.tipo == "cono"
	punishLabel.Visible = true

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
	reportCard:ClearAllChildren()
	corner(reportCard, 12)
	stroke(reportCard, Theme.Hud.Line)

	local title = data.semana and Strings.get("report.week")
		or Strings.get("report.day", { n = data.dia })
	label(reportCard, "Titulo", Strings.get("report.title"),
		UDim2.new(1, -32, 0, 20), UDim2.new(0, 16, 0, 14),
		Theme.FontBold, 12, Theme.Hud.Muted).ZIndex = 9
	label(reportCard, "Subtitulo", title, UDim2.new(1, -32, 0, 26), UDim2.new(0, 16, 0, 32),
		Theme.FontBlack, 22, Theme.Hud.Text).ZIndex = 9

	local big = label(reportCard, "Nota", tostring(data.final) .. "  " .. tostring(data.letra),
		UDim2.new(1, -32, 0, 54), UDim2.new(0, 16, 0, 64),
		Theme.FontBlack, 46, Theme.gradeColor(data.letra))
	big.ZIndex = 9

	local rows = {
		{ Strings.get("report.exam"), tostring(data.examen) },
		{ Strings.get("report.behaviour"), tostring(data.conducta) },
		{ Strings.get("report.correct", { ok = data.aciertos, n = data.total }), "" },
		{ Strings.get("report.punishments", { n = data.castigos }), "" },
		{ Strings.get("shop.price", { n = data.creditos }), "" },
		{ Strings.get("report.fails", { n = data.suspensos, max = data.maxSuspensos }), "" },
	}
	for i, row in rows do
		local y = 128 + (i - 1) * 22
		local line = label(reportCard, "Fila" .. i, row[1],
			UDim2.new(1, -32, 0, 20), UDim2.new(0, 16, 0, y),
			Theme.Font, 14, Theme.Hud.Muted)
		line.ZIndex = 9
		if row[2] ~= "" then
			local value = label(reportCard, "Valor" .. i, row[2],
				UDim2.new(0, 60, 0, 20), UDim2.new(1, -76, 0, y),
				Theme.FontBold, 14, Theme.Hud.Text, Enum.TextXAlignment.Right)
			value.ZIndex = 9
		end
	end

	local footKey = "report.next"
	local footArgs: any = { s = Config.Ronda.SegundosBoletin }
	if data.semana then
		footKey = data.expulsado and "report.expelled" or "report.survived"
		footArgs = nil
	end
	local foot = label(reportCard, "Pie", Strings.get(footKey, footArgs),
		UDim2.new(1, -32, 0, 34), UDim2.new(0, 16, 1, -44),
		Theme.FontBold, 14, data.aprobado and Theme.Hud.Safe or Theme.Hud.Danger,
		Enum.TextXAlignment.Center)
	foot.TextWrapped = true
	foot.ZIndex = 9

	reportCard.Visible = true
	task.delay(Config.Ronda.SegundosBoletin, function()
		reportCard.Visible = false
	end)
end

--- Apaga/enciende el HUD de juego (lo usa el menu de inicio).
local PANELES = { "Reloj", "Nota", "Sospecha", "Objetivo", "Avisos" }

function Hud.setVisible(visible: boolean)
	if not root then
		return
	end
	for _, name in PANELES do
		local child = root:FindFirstChild(name)
		if child and child:IsA("GuiObject") then
			child.Visible = visible
		end
	end
	if not visible then
		if subtitle then
			subtitle.Visible = false
		end
		if reportCard then
			reportCard.Visible = false
		end
	end
end

return Hud

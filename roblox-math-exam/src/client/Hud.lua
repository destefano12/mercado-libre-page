--!strict
--[[
	Hud
	------------------------------------------------------------------
	Lo unico que vive pegado a la camara, y a proposito: son los
	controles y el medidor de riesgo. Todo el resto del juego (la hoja,
	el celular, RoGPT) pasa en objetos 3D adentro del aula.

		arriba   -> estado del profe + barra de riesgo + reloj de la prueba
		abajo    -> el boton grande de accion (sacar el celu / sacar foto)
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Strings = require(Shared:WaitForChild("Strings"))
local Theme = require(Shared:WaitForChild("Theme"))
local Util = require(Shared:WaitForChild("Util"))

local player = Players.LocalPlayer

local Hud = {}
Hud.onPrimary = nil :: (() -> ())?
Hud.onStash = nil :: (() -> ())?
Hud.onPaper = nil :: (() -> ())?
Hud.onMenu = nil :: (() -> ())?

local refs: { [string]: any } = {}
local phoneOut = false
local hasPhoto = false
local lastRisk = 0
local lastDanger = false
local flashToken = 0
local confiscated = false

local function el(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local STATE_KEY = {
	Patrullando = "hud.state.patrol",
	Barriendo = "hud.state.patrol",
	Revisando = "hud.state.inspect",
	Pizarron = "hud.state.board",
	Confrontando = "hud.state.confront",
}

-- Ultimo estado recibido, para poder reescribir todo si cambia el idioma.
local last = {
	risk = nil :: any,
	round = nil :: any,
	exam = nil :: any,
	phone = nil :: any,
}

-- ─────────────────────────────────────────────────────────────
-- Construccion
-- ─────────────────────────────────────────────────────────────

function Hud.mount()
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("AulaHud")
	if existing then
		existing:Destroy()
	end

	local screen = el("ScreenGui", {
		Name = "AulaHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	refs.screen = screen

	-- ── Panel del profesor ────────────────────────────────
	local teacher = el("Frame", {
		Name = "Profesor",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 18),
		Size = UDim2.fromOffset(420, 78),
		BackgroundColor3 = Theme.Hud.Panel,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, screen)
	Util.roundify(teacher, 14, Color3.fromRGB(58, 62, 74), 1)

	el("TextLabel", {
		Size = UDim2.new(1, -28, 0, 20),
		Position = UDim2.fromOffset(14, 10),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		Text = string.upper(Config.Teacher.DisplayName),
		TextColor3 = Theme.Hud.Text,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, teacher)

	refs.teacherState = el("TextLabel", {
		Size = UDim2.new(1, -28, 0, 18),
		Position = UDim2.fromOffset(14, 30),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = Strings.get("hud.state.patrol"),
		TextColor3 = Color3.fromRGB(168, 174, 188),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, teacher)

	local track = el("Frame", {
		Size = UDim2.new(1, -28, 0, 10),
		Position = UDim2.new(0, 14, 1, -20),
		BackgroundColor3 = Color3.fromRGB(42, 45, 54),
		BorderSizePixel = 0,
	}, teacher)
	Util.roundify(track, 5)

	refs.riskBar = el("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Hud.Safe,
		BorderSizePixel = 0,
	}, track)
	Util.roundify(refs.riskBar, 5)

	refs.riskText = el("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(120, 20),
		Position = UDim2.new(1, -14, 0, 10),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		Text = Strings.get("hud.risk.safe"),
		TextColor3 = Theme.Hud.Safe,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, teacher)

	-- ── Reloj / progreso ──────────────────────────────────
	local round = el("Frame", {
		Name = "Ronda",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 18),
		Size = UDim2.fromOffset(190, 78),
		BackgroundColor3 = Theme.Hud.Panel,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, screen)
	Util.roundify(round, 14, Color3.fromRGB(58, 62, 74), 1)

	refs.phase = el("TextLabel", {
		Size = UDim2.new(1, -24, 0, 18),
		Position = UDim2.fromOffset(12, 10),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = Strings.get("hud.phase.prep"),
		TextColor3 = Color3.fromRGB(168, 174, 188),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, round)

	refs.timer = el("TextLabel", {
		Size = UDim2.new(1, -24, 0, 30),
		Position = UDim2.fromOffset(12, 26),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		Text = "00:00",
		TextColor3 = Theme.Hud.Text,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, round)

	refs.progress = el("TextLabel", {
		Size = UDim2.new(1, -24, 0, 16),
		Position = UDim2.new(0, 12, 1, -22),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = "",
		TextColor3 = Color3.fromRGB(150, 156, 168),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, round)

	-- ── Aviso grande "te esta mirando" ────────────────────
	refs.warning = el("TextLabel", {
		Name = "Aviso",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 108),
		Size = UDim2.fromOffset(460, 44),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		Text = "",
		TextColor3 = Theme.Hud.Danger,
		TextSize = 30,
		TextTransparency = 1,
	}, screen)

	-- ── Barra de acciones (abajo) ─────────────────────────
	local bottom = el("Frame", {
		Name = "Acciones",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -26),
		Size = UDim2.fromOffset(620, 78),
		BackgroundTransparency = 1,
	}, screen)

	el("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, bottom)

	local function button(name: string, text: string, order: number, width: number, color: Color3, textSize: number): TextButton
		local instance = el("TextButton", {
			Name = name,
			LayoutOrder = order,
			Size = UDim2.fromOffset(width, 62),
			BackgroundColor3 = color,
			AutoButtonColor = true,
			Font = Theme.FontBold,
			Text = text,
			TextColor3 = Theme.Hud.Text,
			TextSize = textSize,
			BorderSizePixel = 0,
		}, bottom)
		Util.roundify(instance, 16, Color3.fromRGB(255, 255, 255), 0)
		local stroke = instance:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = 0.85
		end
		return instance
	end

	refs.paperButton = button("Hoja", Strings.get("hud.button.paper") .. "  [E]", 1, 200, Color3.fromRGB(38, 42, 52), 18)
	refs.primaryButton = button("Principal", Strings.get("hud.button.phoneOut"), 2, 300, Theme.Hud.Safe, 22)
	refs.stashButton = button("Guardar", Strings.get("hud.button.stash") .. "  [Q]", 3, 180, Color3.fromRGB(38, 42, 52), 18)
	refs.stashButton.Visible = false

	refs.hint = el("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(700, 18),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = Strings.get("hud.hint.default"),
		TextColor3 = Color3.fromRGB(150, 156, 168),
		TextSize = 14,
	}, screen)

	refs.primaryButton.MouseButton1Click:Connect(function()
		if Hud.onPrimary then
			Hud.onPrimary()
		end
	end)
	refs.stashButton.MouseButton1Click:Connect(function()
		if Hud.onStash then
			Hud.onStash()
		end
	end)
	refs.paperButton.MouseButton1Click:Connect(function()
		if Hud.onPaper then
			Hud.onPaper()
		end
	end)

	-- ── Menu ──────────────────────────────────────────────
	local menuButton = el("TextButton", {
		Name = "Menu",
		Position = UDim2.fromOffset(18, 18),
		Size = UDim2.fromOffset(96, 34),
		BackgroundColor3 = Theme.Hud.Panel,
		BackgroundTransparency = 0.25,
		AutoButtonColor = false,
		Font = Theme.Font,
		Text = "☰  [M]",
		TextColor3 = Color3.fromRGB(190, 196, 208),
		TextSize = 15,
		BorderSizePixel = 0,
	}, screen)
	Util.roundify(menuButton, 10, Color3.fromRGB(58, 62, 74), 1)
	menuButton.MouseButton1Click:Connect(function()
		if Hud.onMenu then
			Hud.onMenu()
		end
	end)

	-- ── Toasts ────────────────────────────────────────────
	refs.toasts = el("Frame", {
		Name = "Avisos",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(18, 62),
		Size = UDim2.fromOffset(330, 300),
		BackgroundTransparency = 1,
	}, screen)
	el("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, refs.toasts)

	-- ── Flash de "te pillaron" ────────────────────────────
	refs.flash = el("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Hud.Danger,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 10,
		Visible = true,
	}, screen)

	refs.flashText = el("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(800, 90),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		Text = "",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 54,
		TextTransparency = 1,
		ZIndex = 11,
	}, screen)

	return screen
end

-- ─────────────────────────────────────────────────────────────
-- Actualizaciones
-- ─────────────────────────────────────────────────────────────

function Hud.setRisk(data: any)
	last.risk = data
	if not refs.riskBar then
		return
	end
	local risk = data.risk or 0
	lastRisk = risk
	local color = Theme.riskColor(risk)

	TweenService:Create(refs.riskBar, TweenInfo.new(0.18), {
		Size = UDim2.fromScale(math.clamp(risk, 0, 1), 1),
		BackgroundColor3 = color,
	}):Play()

	refs.teacherState.Text = Strings.get(STATE_KEY[data.teacherState] or "hud.state.patrol")
	if data.inspecting then
		refs.teacherState.Text = Strings.get("hud.state.atYourDesk")
	end

	local key
	if data.teacherState == "Pizarron" then
		key = "hud.risk.backTurned"
	elseif data.seen then
		key = "hud.risk.seen"
	elseif risk > Config.Teacher.RiskWarning then
		key = "hud.risk.suspicious"
	else
		key = "hud.risk.safe"
	end
	refs.riskText.Text = Strings.get(key)
	refs.riskText.TextColor3 = color

	local danger = (data.seen and phoneOut) == true
	if danger ~= lastDanger then
		lastDanger = danger
		refs.warning.Text = danger and Strings.get("hud.warning") or ""
		TweenService:Create(refs.warning, TweenInfo.new(0.2), {
			TextTransparency = danger and 0 or 1,
		}):Play()
	end

	Hud.refreshPrimary()
end

--- El boton grande es contextual: sacar el celu, sacar la foto o
--- mandarsela a RoGPT.
function Hud.setHasPhoto(value: boolean)
	hasPhoto = value
	Hud.refreshPrimary()
end

function Hud.setPhoneOut(out: boolean)
	phoneOut = out
	if refs.stashButton then
		refs.stashButton.Visible = out
	end
	Hud.refreshPrimary()
end

function Hud.refreshPrimary()
	local button = refs.primaryButton
	if not button or confiscated then
		return
	end

	if phoneOut then
		button.Text = Strings.get(hasPhoto and "hud.button.send" or "hud.button.photo")
		button.Size = UDim2.fromOffset(hasPhoto and 300 or 260, 62)
	else
		button.Text = Strings.get("hud.button.phoneOut")
		button.Size = UDim2.fromOffset(300, 62)
	end

	-- Verde = momento seguro; rojo = te va a ver.
	local color = Theme.riskColor(lastRisk)
	button.BackgroundColor3 = color:Lerp(Color3.fromRGB(20, 22, 28), 0.15)
end

function Hud.setPhoneState(state: any)
	last.phone = state
	if not refs.hint then
		return
	end
	confiscated = state.confiscated == true
	if confiscated then
		refs.hint.Text = Strings.get("hud.hint.confiscated", { seconds = math.ceil(state.confiscatedFor) })
		refs.primaryButton.AutoButtonColor = false
		refs.primaryButton.BackgroundColor3 = Color3.fromRGB(48, 50, 58)
		refs.primaryButton.Text = Strings.get("hud.button.noPhone")
	else
		refs.primaryButton.AutoButtonColor = true
		refs.hint.Text = Strings.get("hud.hint.battery", { battery = state.battery })
		Hud.refreshPrimary()
	end
end

local PHASE_KEY = {
	Preparacion = "hud.phase.prep",
	Prueba = "hud.phase.exam",
	Resultados = "hud.phase.results",
	Salida = "hud.phase.dismissal",
	Casa = "hud.phase.home",
	Epilogo = "hud.phase.epilogue",
}

function Hud.setRound(data: any)
	last.round = data
	if not refs.timer then
		return
	end
	refs.timer.Text = string.format("%02d:%02d", math.floor(data.timeLeft / 60), data.timeLeft % 60)
	refs.phase.Text = Strings.get(PHASE_KEY[data.phase] or "hud.phase.prep")
	refs.phase.TextColor3 = data.phase == "Prueba" and Theme.Hud.Safe or Color3.fromRGB(168, 174, 188)
end

function Hud.setExam(snapshot: any)
	last.exam = snapshot
	if not refs.progress then
		return
	end
	refs.progress.Text = Strings.get("hud.progress", {
		answered = snapshot.answered,
		total = #snapshot.questions,
		grade = string.format("%.1f", snapshot.grade),
	})
end

--- Los avisos llegan del servidor como clave: se escriben aca, en el
--- idioma del jugador.
function Hud.notify(key: string, kind: string?, args: { [string]: any }?)
	if not refs.toasts then
		return
	end
	local text = Strings.get(key, args)
	local color = Theme.Hud.Safe
	if kind == "danger" then
		color = Theme.Hud.Danger
	elseif kind == "warn" then
		color = Theme.Hud.Warn
	elseif kind == "info" then
		color = Color3.fromRGB(92, 148, 232)
	end

	local toast = el("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Hud.Panel,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		LayoutOrder = -os.time(),
	}, refs.toasts)
	Util.roundify(toast, 12, color, 2)
	el("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}, toast)
	el("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = text,
		TextColor3 = Theme.Hud.Text,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, toast)

	task.delay(5, function()
		if toast.Parent then
			TweenService:Create(toast, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
			task.wait(0.35)
			toast:Destroy()
		end
	end)
end

--- Golpe de color a pantalla completa: rojo cuando te pillan,
--- blanco cuando dispara el flash de la camara.
function Hud.flash(text: string, color: Color3?)
	if not refs.flash then
		return
	end
	refs.flash.BackgroundColor3 = color or Theme.Hud.Danger
	refs.flashText.Text = text
	refs.flash.BackgroundTransparency = color and 0.2 or 0.45
	refs.flashText.TextTransparency = 0

	TweenService:Create(refs.flash, TweenInfo.new(1.1), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(refs.flashText, TweenInfo.new(1.6), { TextTransparency = 1 }):Play()

	-- Red de seguridad: si un tween se pisa con otro, el velo blanco se
	-- puede quedar tapando la pantalla. Esto lo apaga si o si.
	flashToken += 1
	local mine = flashToken
	task.delay(1.8, function()
		if flashToken == mine and refs.flash then
			refs.flash.BackgroundTransparency = 1
			refs.flashText.TextTransparency = 1
		end
	end)
end

--- Se apaga entero mientras esta abierto el menu de inicio.
function Hud.setVisible(visible: boolean)
	if refs.screen then
		refs.screen.Enabled = visible
	end
end

--- Reescribe todo lo visible cuando el jugador cambia el idioma.
function Hud.refreshTexts()
	if not refs.screen then
		return
	end
	refs.paperButton.Text = Strings.get("hud.button.paper") .. "  [E]"
	refs.stashButton.Text = Strings.get("hud.button.stash") .. "  [Q]"
	if last.risk then
		Hud.setRisk(last.risk)
	end
	if last.round then
		Hud.setRound(last.round)
	end
	if last.exam then
		Hud.setExam(last.exam)
	end
	if last.phone then
		Hud.setPhoneState(last.phone)
	else
		refs.hint.Text = Strings.get("hud.hint.default")
	end
	Hud.refreshPrimary()
end

return Hud

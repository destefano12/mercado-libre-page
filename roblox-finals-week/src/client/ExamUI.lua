--!strict
--[[
	ExamUI
	------------------------------------------------------------------
	La hoja del examen, en pantalla, mientras estas sentado.

	Dos tipos de pregunta:
	  opcion      cuatro alternativas, se contesta con el mouse o con
	              las teclas 1-4
	  escritura   una secuencia de letras que hay que teclear entera
	              antes de que se acabe la barra: es el minijuego de
	              "escribir rapido" y es donde mas expuesto estas,
	              porque no podes mirar al profesor mientras tecleas

	Los botones de trampa (espiar / soplar / chuleta) estan aca abajo
	a proposito: la trampa es parte del examen, no un menu aparte.
--]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Strings = require(Shared:WaitForChild("Strings"))
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local ExamUI = {}

local LETRAS = { "A", "B", "C", "D", "E", "F" }

local root: Frame
local titleLabel: TextLabel
local progressLabel: TextLabel
local questionLabel: TextLabel
local topicLabel: TextLabel
local optionButtons: { TextButton } = {}
local navGrid: Frame
local sheetButton: TextButton
local typingPanel: Frame
local typingLabel: TextLabel
local typingProgress: Frame

local state: any = { activo = false, preguntas = {}, respuestas = {}, reveladas = {} }
local current = 1
local typing: { activa: boolean, objetivo: string, escrito: string, hasta: number, indice: number } = {
	activa = false, objetivo = "", escrito = "", hasta = 0, indice = 0,
}

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

local function click()
	Util.playSound(Config.Sonidos.Click, workspace :: any, 0.25, 1.2)
end

-- ── construccion ───────────────────────────────────────────────────

function ExamUI.mount(parent: ScreenGui)
	root = new("Frame", {
		Name = "Examen",
		Size = UDim2.new(0, 400, 0, 470),
		Position = UDim2.new(1, -16, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Theme.Paper.Background,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 4,
	}, parent)
	corner(root, 12)
	new("UIStroke", { Color = Theme.Paper.Line, Thickness = 2 }, root)

	-- Cabecera de la hoja.
	titleLabel = new("TextLabel", {
		Name = "Titulo",
		Text = "",
		Size = UDim2.new(1, -28, 0, 24),
		Position = UDim2.new(0, 14, 0, 12),
		BackgroundTransparency = 1,
		Font = Theme.FontBlack,
		TextSize = 18,
		TextColor3 = Theme.Paper.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
	}, root)
	progressLabel = new("TextLabel", {
		Name = "Progreso",
		Text = "",
		Size = UDim2.new(1, -28, 0, 16),
		Position = UDim2.new(0, 14, 0, 34),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextSize = 12,
		TextColor3 = Theme.Paper.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
	}, root)

	new("Frame", {
		Name = "Linea",
		Size = UDim2.new(1, -28, 0, 1),
		Position = UDim2.new(0, 14, 0, 54),
		BackgroundColor3 = Theme.Paper.Line,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, root)

	-- Navegador: un cuadradito por pregunta.
	navGrid = new("Frame", {
		Name = "Navegador",
		Size = UDim2.new(1, -28, 0, 62),
		Position = UDim2.new(0, 14, 0, 62),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, root)
	new("UIGridLayout", {
		CellSize = UDim2.new(0, 26, 0, 26),
		CellPadding = UDim2.new(0, 4, 0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, navGrid)

	topicLabel = new("TextLabel", {
		Name = "Tema",
		Text = "",
		Size = UDim2.new(1, -28, 0, 14),
		Position = UDim2.new(0, 14, 0, 132),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		TextSize = 11,
		TextColor3 = Theme.Paper.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
	}, root)

	questionLabel = new("TextLabel", {
		Name = "Enunciado",
		Text = "",
		Size = UDim2.new(1, -28, 0, 70),
		Position = UDim2.new(0, 14, 0, 150),
		BackgroundTransparency = 1,
		Font = Theme.FontMono,
		TextSize = 26,
		TextColor3 = Theme.Paper.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		ZIndex = 5,
	}, root)

	-- Las cuatro alternativas.
	for i = 1, Config.Examen.OpcionesPorPregunta do
		local button = new("TextButton", {
			Name = "Opcion" .. i,
			Text = "",
			Size = UDim2.new(1, -28, 0, 40),
			Position = UDim2.new(0, 14, 0, 226 + (i - 1) * 46),
			BackgroundColor3 = Color3.fromRGB(242, 240, 232),
			AutoButtonColor = false,
			Font = Theme.FontBold,
			TextSize = 16,
			TextColor3 = Theme.Paper.Ink,
			TextXAlignment = Enum.TextXAlignment.Left,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, root)
		corner(button, 8)
		new("UIPadding", { PaddingLeft = UDim.new(0, 14) }, button)
		button.MouseButton1Click:Connect(function()
			ExamUI.answer(i)
		end)
		optionButtons[i] = button
	end

	-- Minijuego de escritura, se superpone a las alternativas.
	typingPanel = new("Frame", {
		Name = "Escritura",
		Size = UDim2.new(1, -28, 0, 180),
		Position = UDim2.new(0, 14, 0, 226),
		BackgroundColor3 = Color3.fromRGB(242, 240, 232),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 6,
	}, root)
	corner(typingPanel, 8)
	new("TextLabel", {
		Name = "Aviso",
		Text = Strings.get("exam.type_prompt"),
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.new(0, 10, 0, 12),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		TextSize = 13,
		TextColor3 = Theme.Paper.InkSoft,
		ZIndex = 7,
	}, typingPanel)
	typingLabel = new("TextLabel", {
		Name = "Secuencia",
		Text = "",
		Size = UDim2.new(1, -20, 0, 60),
		Position = UDim2.new(0, 10, 0, 46),
		BackgroundTransparency = 1,
		Font = Theme.FontMono,
		TextSize = 40,
		TextColor3 = Theme.Paper.Ink,
		ZIndex = 7,
	}, typingPanel)
	local track = new("Frame", {
		Name = "Barra",
		Size = UDim2.new(1, -20, 0, 10),
		Position = UDim2.new(0, 10, 0, 128),
		BackgroundColor3 = Theme.Paper.Line,
		BorderSizePixel = 0,
		ZIndex = 7,
	}, typingPanel)
	corner(track, 5)
	typingProgress = new("Frame", {
		Name = "Relleno",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Paper.Accent,
		BorderSizePixel = 0,
		ZIndex = 8,
	}, track)
	corner(typingProgress, 5)

	-- Botones de trampa, en una fila abajo del todo.
	local cheats = new("Frame", {
		Name = "Trampas",
		Size = UDim2.new(1, -28, 0, 32),
		Position = UDim2.new(0, 14, 1, -44),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, root)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, cheats)

	local acciones = {
		{ key = "cheat.peek", accion = "peek", color = Theme.Paper.Accent },
		{ key = "cheat.whisper", accion = "whisper", color = Theme.Paper.Correct },
		{ key = "item.chuleta", accion = "sheet", color = Theme.Paper.Wrong },
	}
	for i, entry in acciones do
		local button = new("TextButton", {
			Name = "Trampa" .. i,
			LayoutOrder = i,
			Text = Strings.get(entry.key),
			Size = UDim2.new(0.32, 0, 1, 0),
			BackgroundColor3 = entry.color,
			BackgroundTransparency = 0.86,
			AutoButtonColor = false,
			Font = Theme.FontBold,
			TextSize = 12,
			TextColor3 = entry.color,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, cheats)
		corner(button, 8)
		new("UIStroke", { Color = entry.color, Thickness = 1, Transparency = 0.5 }, button)
		button.MouseButton1Click:Connect(function()
			ExamUI.cheat(entry.accion)
		end)
		if entry.accion == "sheet" then
			sheetButton = button
		end
	end

	ExamUI.bindInput()
end

-- ── datos ──────────────────────────────────────────────────────────

local function questionAt(index: number): any
	return state.preguntas and state.preguntas[index]
end

local function refreshNav()
	if not navGrid then
		return
	end
	local total = state.preguntas and #state.preguntas or 0
	for _, child in navGrid:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for i = 1, total do
		-- El servidor manda arrays densos: 0 es "sin responder".
		local answered = (state.respuestas[i] or 0) > 0
		local revealed = (state.reveladas[i] or 0) > 0
		local button = new("TextButton", {
			Name = "N" .. i,
			LayoutOrder = i,
			Text = tostring(i),
			BackgroundColor3 = i == current and Theme.Paper.Ink
				or (revealed and Theme.Paper.Highlight
					or (answered and Theme.Paper.Accent or Color3.fromRGB(236, 234, 226))),
			AutoButtonColor = false,
			Font = Theme.FontBold,
			TextSize = 12,
			TextColor3 = (i == current or answered) and Color3.fromRGB(250, 250, 246)
				or Theme.Paper.InkSoft,
			BorderSizePixel = 0,
			ZIndex = 6,
		}, navGrid)
		corner(button, 6)
		button.MouseButton1Click:Connect(function()
			click()
			ExamUI.show(i)
		end)
	end
end

local function stopTyping()
	typing.activa = false
	typingPanel.Visible = false
	for _, button in optionButtons do
		button.Visible = true
	end
end

local function startTyping(index: number, sequence: string)
	typing.activa = true
	typing.objetivo = string.upper(sequence)
	typing.escrito = ""
	typing.indice = index
	typing.hasta = os.clock() + Config.Examen.SegundosSecuencia
	typingPanel.Visible = true
	typingLabel.Text = typing.objetivo
	typingProgress.Size = UDim2.fromScale(1, 1)
	for _, button in optionButtons do
		button.Visible = false
	end
end

function ExamUI.show(index: number)
	local question = questionAt(index)
	if not question then
		return
	end
	current = index
	stopTyping()

	topicLabel.Text = string.upper(Strings.get(question.tema or "topic.math"))
	questionLabel.Text = question.texto
	progressLabel.Text = Strings.get("exam.question", { i = index, n = #state.preguntas })

	if question.tipo == "escritura" then
		startTyping(index, question.secuencia or question.texto)
	else
		for i, button in optionButtons do
			local option = question.opciones[i]
			button.Visible = option ~= nil
			if option then
				local chosen = state.respuestas[index] == i
				local revealed = state.reveladas[index] == i
				button.Text = string.format("%s.   %s", LETRAS[i] or "?", option)
				button.BackgroundColor3 = revealed and Theme.Paper.Highlight
					or (chosen and Theme.Paper.Accent or Color3.fromRGB(242, 240, 232))
				button.TextColor3 = chosen and Color3.fromRGB(250, 250, 246) or Theme.Paper.Ink
			end
		end
	end

	refreshNav()
end

function ExamUI.setState(data: any)
	state = data
	state.respuestas = data.respuestas or {}
	state.reveladas = data.reveladas or {}
	state.preguntas = data.preguntas or {}

	if not data.activo or #state.preguntas == 0 then
		root.Visible = false
		stopTyping()
		return
	end

	root.Visible = true
	titleLabel.Text = Strings.get("exam.title", {
		subject = Strings.get((state.preguntas[1] and state.preguntas[1].tema) or "topic.math"),
	})

	local answered = 0
	for i = 1, #state.preguntas do
		if (state.respuestas[i] or 0) > 0 then
			answered += 1
		end
	end
	sheetButton.Text = string.format("%s (%d)", Strings.get("item.chuleta"), data.chuleta or 0)

	current = math.clamp(current, 1, #state.preguntas)
	ExamUI.show(current)
	progressLabel.Text = Strings.get("exam.progress", {
		done = answered, total = #state.preguntas,
	})
end

--- La pregunta en la que esta parado el alumno: la usan los atajos de
--- teclado para espiar/soplar la que esta mirando, no la primera.
function ExamUI.currentIndex(): number
	return current
end

function ExamUI.isOpen(): boolean
	return root ~= nil and root.Visible
end

-- ── acciones ───────────────────────────────────────────────────────

function ExamUI.answer(option: number)
	local question = questionAt(current)
	if not question or question.tipo ~= "opcion" then
		return
	end
	click()
	ExamUI.onWrite()
	state.respuestas[current] = option
	ExamUI.show(current)

	task.spawn(function()
		local ok, result = pcall(function()
			return Net.func(Net.Functions.SubmitAnswer):InvokeServer(current, option)
		end)
		if ok and result and not result.ok and result.reason then
			ExamUI.onNotify(result.reason)
		end
	end)
end

function ExamUI.cheat(action: string)
	click()
	Net.event(Net.Events.Cheat):FireServer(action, current)
end

--- Los rellena el init del cliente para no acoplar ExamUI con el HUD
--- ni con las animaciones.
ExamUI.onNotify = function(_packet: any) end
ExamUI.onWrite = function() end

-- ── entrada de teclado ─────────────────────────────────────────────

local NUMEROS = {
	[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4,
}

function ExamUI.bindInput()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not root or not root.Visible then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		if typing.activa then
			local char = string.upper(tostring(input.KeyCode.Name))
			if #char == 1 then
				local expected = string.sub(typing.objetivo, #typing.escrito + 1, #typing.escrito + 1)
				if char == expected then
					ExamUI.onWrite()
					typing.escrito ..= char
					typingLabel.Text = string.rep(" ", 0) .. typing.objetivo
					local done = #typing.escrito
					typingLabel.Text = string.format('<font color="#1C5CBA">%s</font>%s',
						string.sub(typing.objetivo, 1, done),
						string.sub(typing.objetivo, done + 1))
					typingLabel.RichText = true
					if typing.escrito == typing.objetivo then
						ExamUI.finishTyping(true)
					end
				else
					ExamUI.finishTyping(false)
				end
			end
			return
		end

		local option = NUMEROS[input.KeyCode]
		if option then
			ExamUI.answer(option)
		elseif input.KeyCode == Enum.KeyCode.Left then
			ExamUI.show(math.max(1, current - 1))
		elseif input.KeyCode == Enum.KeyCode.Right then
			ExamUI.show(math.min(#state.preguntas, current + 1))
		end
	end)
end

function ExamUI.finishTyping(success: boolean)
	if not typing.activa then
		return
	end
	local index = typing.indice
	local typed = success and typing.objetivo or typing.escrito
	typing.activa = false
	typingPanel.Visible = false

	state.respuestas[index] = success and 1 or 2
	refreshNav()

	task.spawn(function()
		local ok, result = pcall(function()
			return Net.func(Net.Functions.SubmitSequence):InvokeServer(index, typed)
		end)
		if ok and result and result.reason then
			ExamUI.onNotify(result.reason)
		end
	end)

	Util.playSound(success and Config.Sonidos.Acierto or Config.Sonidos.Error,
		workspace :: any, 0.3, success and 1.4 or 0.7)
end

--- Se llama desde el RenderStepped del cliente: la barra del minijuego.
function ExamUI.step()
	if not typing.activa then
		return
	end
	local left = typing.hasta - os.clock()
	if left <= 0 then
		ExamUI.finishTyping(false)
		return
	end
	typingProgress.Size = UDim2.fromScale(left / Config.Examen.SegundosSecuencia, 1)
	typingProgress.BackgroundColor3 = left < 2 and Theme.Paper.Wrong or Theme.Paper.Accent
end

function ExamUI.setVisible(visible: boolean)
	if root then
		root.Visible = visible and state.activo == true
	end
end

return ExamUI

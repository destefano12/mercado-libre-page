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

	Lo que cambio respecto de la version anterior: era un rectangulo
	color crema con texto encima. Ahora es una hoja — renglones, margen
	rojo y grano de papel, todo con degradados y Frames, sin subir
	ninguna imagen. Las alternativas llevan su letra en una chapita y
	se marcan con un tilde en vez de solo cambiar de color de fondo. Y
	el navegador de preguntas dejo de destruir y recrear todos sus
	botones en cada `show`: ahora reusa los que ya existen.
--]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Strings = require(Shared:WaitForChild("Strings"))
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local UI = require(Shared:WaitForChild("UI"))

local ExamUI = {}

local LETRAS = { "A", "B", "C", "D", "E", "F" }

-- Color del papel manchado, un punto mas calido que el fondo. No esta
-- en Theme porque solo lo usa esta hoja.
local PAPER_WARM = Color3.fromRGB(242, 237, 222)
local RULE = Color3.fromRGB(206, 214, 228)
local MARGIN_RED = Color3.fromRGB(216, 128, 124)

local root: Frame
local titleLabel: TextLabel
local progressLabel: TextLabel
local questionLabel: TextLabel
local topicLabel: TextLabel
local optionRows: { { button: TextButton, badge: Frame, letter: TextLabel, text: TextLabel, tick: Frame } } = {}
local navGrid: Frame
local navButtons: { TextButton } = {}
local sheetButton: TextButton
local typingPanel: Frame
local typingLabel: TextLabel
local typingProgress: Frame

local state: any = { activo = false, preguntas = {}, respuestas = {}, reveladas = {} }
local current = 1
local typing: { activa: boolean, objetivo: string, escrito: string, hasta: number, indice: number } = {
	activa = false, objetivo = "", escrito = "", hasta = 0, indice = 0,
}

local OPTION_TOP = 238
local OPTION_STEP = 50

-- ── el papel ───────────────────────────────────────────────────────

--[[
	Renglones y margen. Van en un contenedor de fondo con ZIndex por
	debajo del contenido, y `ClipsDescendants` para que las lineas no se
	salgan de las esquinas redondeadas.
--]]
local function buildPaper(parent: Frame)
	local sheet = UI.new("Frame", {
		Name = "Papel",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = UI.Layer.Panel,
		Parent = parent,
	})

	-- Grano: un degradado diagonal muy leve entre dos cremas. Es lo que
	-- evita que la hoja se lea como un rectangulo de color plano.
	local grain = UI.new("Frame", {
		Name = "Grano",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = PAPER_WARM,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		ZIndex = UI.Layer.Panel,
		Parent = sheet,
	})
	UI.new("UIGradient", {
		Rotation = 32,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(0.5, 0.75),
			NumberSequenceKeypoint.new(1, 0.4),
		}),
		Parent = grain,
	})

	-- Renglones cada 24 px, desde debajo de la cabecera.
	for y = 150, 470, 24 do
		UI.new("Frame", {
			Name = "Renglon",
			Size = UDim2.new(1, -60, 0, 1),
			Position = UDim2.fromOffset(46, y),
			BackgroundColor3 = RULE,
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			ZIndex = UI.Layer.Panel,
			Parent = sheet,
		})
	end

	-- El margen rojo de toda hoja de cuaderno.
	UI.new("Frame", {
		Name = "Margen",
		Size = UDim2.new(0, 1, 1, -70),
		Position = UDim2.fromOffset(40, 62),
		BackgroundColor3 = MARGIN_RED,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = UI.Layer.Panel,
		Parent = sheet,
	})

	-- Dos agujeros de carpeta arriba a la izquierda.
	for _, y in { 92, 300 } do
		local hole = UI.new("Frame", {
			Name = "Agujero",
			Size = UDim2.fromOffset(13, 13),
			Position = UDim2.fromOffset(14, y),
			BackgroundColor3 = Color3.fromRGB(222, 216, 200),
			BorderSizePixel = 0,
			ZIndex = UI.Layer.Panel,
			Parent = sheet,
		})
		UI.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = hole })
	end
end

--- Una alternativa: chapita con la letra, el texto, y un tilde.
local function buildOption(index: number)
	local layer = UI.Layer.Panel + 1
	local button: TextButton = UI.new("TextButton", {
		Name = "Opcion" .. index,
		Text = "",
		Size = UDim2.new(1, -60, 0, 44),
		Position = UDim2.fromOffset(46, OPTION_TOP + (index - 1) * OPTION_STEP),
		BackgroundColor3 = Color3.fromRGB(246, 243, 233),
		BackgroundTransparency = 0.25,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = layer,
		Parent = root,
	})
	UI.corner(button, UI.Radius.sm)
	UI.stroke(button, Theme.Paper.Line, 1, 0.35)

	local badge = UI.new("Frame", {
		Name = "Chapa",
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.fromOffset(9, 9),
		BackgroundColor3 = Color3.fromRGB(232, 228, 216),
		BorderSizePixel = 0,
		ZIndex = layer + 1,
		Parent = button,
	})
	UI.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })

	local letter = UI.label({
		parent = badge,
		name = "Letra",
		size = UDim2.fromScale(1, 1),
		font = Theme.FontBold,
		textSize = UI.Type.small,
		color = Theme.Paper.InkSoft,
		align = Enum.TextXAlignment.Center,
		layer = layer + 2,
	})

	local text = UI.label({
		parent = button,
		name = "Texto",
		size = UDim2.new(1, -84, 1, 0),
		position = UDim2.fromOffset(46, 0),
		font = Theme.FontBold,
		textSize = UI.Type.subtitle,
		color = Theme.Paper.Ink,
		layer = layer + 1,
	})

	local tick = UI.icon(button, "tilde", 18, Theme.Paper.Correct, layer + 1)
	tick.Name = "Tilde"
	tick.Position = UDim2.new(1, -30, 0.5, -9)
	tick.Visible = false

	button.MouseEnter:Connect(function()
		TweenService:Create(button, UI.Motion.snap, { BackgroundTransparency = 0.05 }):Play()
	end)
	button.MouseLeave:Connect(function()
		local chosen = state.respuestas and state.respuestas[current] == index
		TweenService:Create(button, UI.Motion.snap, {
			BackgroundTransparency = chosen and 0 or 0.25,
		}):Play()
	end)
	button.MouseButton1Click:Connect(function()
		ExamUI.answer(index)
	end)

	optionRows[index] = {
		button = button, badge = badge, letter = letter, text = text, tick = tick,
	}
end

-- ── construccion ───────────────────────────────────────────────────

function ExamUI.mount(parent: ScreenGui)
	root = UI.new("Frame", {
		Name = "Examen",
		Size = UDim2.fromOffset(430, 500),
		Position = UDim2.new(1, -18, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Theme.Paper.Background,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = UI.Layer.Panel,
		Parent = parent,
	})
	UI.corner(root, UI.Radius.md)
	UI.stroke(root, Theme.Paper.Line, 2, 0.1)

	buildPaper(root)

	titleLabel = UI.label({
		parent = root,
		name = "Titulo",
		size = UDim2.new(1, -60, 0, 24),
		position = UDim2.fromOffset(46, 14),
		font = Theme.FontBlack,
		textSize = UI.Type.title,
		color = Theme.Paper.Ink,
		layer = UI.Layer.Panel + 1,
	})
	progressLabel = UI.label({
		parent = root,
		name = "Progreso",
		size = UDim2.new(1, -60, 0, 16),
		position = UDim2.fromOffset(46, 38),
		font = Theme.Font,
		textSize = UI.Type.small,
		color = Theme.Paper.InkSoft,
		layer = UI.Layer.Panel + 1,
	})

	UI.new("Frame", {
		Name = "Linea",
		Size = UDim2.new(1, -60, 0, 1),
		Position = UDim2.fromOffset(46, 60),
		BackgroundColor3 = Theme.Paper.Line,
		BorderSizePixel = 0,
		ZIndex = UI.Layer.Panel + 1,
		Parent = root,
	})

	-- Navegador: un cuadradito por pregunta.
	navGrid = UI.new("Frame", {
		Name = "Navegador",
		Size = UDim2.new(1, -60, 0, 62),
		Position = UDim2.fromOffset(46, 70),
		BackgroundTransparency = 1,
		ZIndex = UI.Layer.Panel + 1,
		Parent = root,
	})
	UI.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(26, 26),
		CellPadding = UDim2.fromOffset(5, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = navGrid,
	})

	topicLabel = UI.label({
		parent = root,
		name = "Tema",
		size = UDim2.new(1, -60, 0, 14),
		position = UDim2.fromOffset(46, 140),
		font = Theme.FontBold,
		textSize = UI.Type.micro,
		color = Theme.Paper.Accent,
		layer = UI.Layer.Panel + 1,
	})

	questionLabel = UI.label({
		parent = root,
		name = "Enunciado",
		size = UDim2.new(1, -60, 0, 72),
		position = UDim2.fromOffset(46, 158),
		font = Theme.FontMono,
		textSize = UI.Type.display - 4,
		color = Theme.Paper.Ink,
		wrapped = true,
		layer = UI.Layer.Panel + 1,
	})

	for i = 1, Config.Examen.OpcionesPorPregunta do
		buildOption(i)
	end

	-- Minijuego de escritura, se superpone a las alternativas.
	typingPanel = UI.new("Frame", {
		Name = "Escritura",
		Size = UDim2.new(1, -60, 0, 186),
		Position = UDim2.fromOffset(46, OPTION_TOP),
		BackgroundColor3 = Color3.fromRGB(244, 241, 231),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = UI.Layer.Panel + 3,
		Parent = root,
	})
	UI.corner(typingPanel, UI.Radius.sm)
	UI.stroke(typingPanel, Theme.Paper.Accent, 1, 0.6)

	UI.label({
		parent = typingPanel,
		name = "Aviso",
		text = Strings.get("exam.type_prompt"),
		size = UDim2.new(1, -20, 0, 20),
		position = UDim2.fromOffset(10, 12),
		font = Theme.FontBold,
		textSize = UI.Type.small,
		color = Theme.Paper.InkSoft,
		align = Enum.TextXAlignment.Center,
		layer = UI.Layer.Panel + 4,
	})
	typingLabel = UI.label({
		parent = typingPanel,
		name = "Secuencia",
		size = UDim2.new(1, -20, 0, 62),
		position = UDim2.fromOffset(10, 48),
		font = Theme.FontMono,
		textSize = UI.Type.hero - 8,
		color = Theme.Paper.Ink,
		align = Enum.TextXAlignment.Center,
		layer = UI.Layer.Panel + 4,
	})

	local track = UI.new("Frame", {
		Name = "Barra",
		Size = UDim2.new(1, -20, 0, 10),
		Position = UDim2.fromOffset(10, 132),
		BackgroundColor3 = Theme.Paper.Line,
		BorderSizePixel = 0,
		ZIndex = UI.Layer.Panel + 4,
		Parent = typingPanel,
	})
	UI.corner(track, 5)
	typingProgress = UI.new("Frame", {
		Name = "Relleno",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Paper.Accent,
		BorderSizePixel = 0,
		ZIndex = UI.Layer.Panel + 5,
		Parent = track,
	})
	UI.corner(typingProgress, 5)

	-- Botones de trampa, en una fila abajo del todo.
	local cheats = UI.new("Frame", {
		Name = "Trampas",
		Size = UDim2.new(1, -60, 0, 34),
		Position = UDim2.new(0, 46, 1, -46),
		BackgroundTransparency = 1,
		ZIndex = UI.Layer.Panel + 1,
		Parent = root,
	})
	UI.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, UI.Space.sm),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = cheats,
	})

	local acciones = {
		{ key = "cheat.peek", accion = "peek", color = Theme.Paper.Accent, icon = "ojo" },
		{ key = "cheat.whisper", accion = "whisper", color = Theme.Paper.Correct, icon = "radio" },
		{ key = "item.chuleta", accion = "sheet", color = Theme.Paper.Wrong, icon = "libro" },
	}
	for i, entry in acciones do
		local button = UI.button({
			parent = cheats,
			name = "Trampa" .. i,
			text = Strings.get(entry.key),
			size = UDim2.new(0.32, 0, 1, 0),
			order = i,
			color = entry.color,
			ghost = true,
			textSize = UI.Type.small,
			radius = UI.Radius.sm,
			layer = UI.Layer.Panel + 1,
			onClick = function()
				ExamUI.cheat(entry.accion)
			end,
		})
		if entry.accion == "sheet" then
			sheetButton = button.instance
		end
	end

	ExamUI.bindInput()
end

-- ── datos ──────────────────────────────────────────────────────────

local function questionAt(index: number): any
	return state.preguntas and state.preguntas[index]
end

--[[
	Refresca el navegador reusando los botones. Antes destruia todos y
	los volvia a crear en cada `show`, que ademas de tirar basura hacia
	parpadear la fila entera al cambiar de pregunta.
--]]
local function refreshNav()
	if not navGrid then
		return
	end
	local total = state.preguntas and #state.preguntas or 0

	for i = 1, total do
		local button = navButtons[i]
		if not button then
			button = UI.new("TextButton", {
				Name = "N" .. i,
				LayoutOrder = i,
				Text = tostring(i),
				AutoButtonColor = false,
				Font = Theme.FontBold,
				TextSize = UI.Type.small,
				BorderSizePixel = 0,
				ZIndex = UI.Layer.Panel + 2,
				Parent = navGrid,
			})
			UI.corner(button, UI.Radius.sm)
			local index = i
			button.MouseButton1Click:Connect(function()
				UI.click()
				ExamUI.show(index)
			end)
			navButtons[i] = button
		end

		-- El servidor manda arrays densos: 0 es "sin responder".
		local answered = (state.respuestas[i] or 0) > 0
		local revealed = (state.reveladas[i] or 0) > 0
		button.Visible = true
		button.BackgroundColor3 = i == current and Theme.Paper.Ink
			or (revealed and Theme.Paper.Highlight
				or (answered and Theme.Paper.Accent or Color3.fromRGB(236, 234, 226)))
		button.TextColor3 = (i == current or answered) and Color3.fromRGB(250, 250, 246)
			or Theme.Paper.InkSoft
	end

	-- Los sobrantes de un examen mas largo se esconden, no se destruyen.
	for i = total + 1, #navButtons do
		navButtons[i].Visible = false
	end
end

local function stopTyping()
	typing.activa = false
	typingPanel.Visible = false
	for _, row in optionRows do
		row.button.Visible = true
	end
end

local function startTyping(index: number, sequence: string)
	typing.activa = true
	typing.objetivo = string.upper(sequence)
	typing.escrito = ""
	typing.indice = index
	typing.hasta = os.clock() + Config.Examen.SegundosSecuencia
	typingPanel.Visible = true
	typingLabel.RichText = false
	typingLabel.Text = typing.objetivo
	typingProgress.Size = UDim2.fromScale(1, 1)
	for _, row in optionRows do
		row.button.Visible = false
	end
end

--- Pinta una alternativa segun su estado.
local function paintOption(index: number, option: string?, chosen: boolean, revealed: boolean)
	local row = optionRows[index]
	if not row then
		return
	end
	row.button.Visible = option ~= nil
	if not option then
		return
	end
	row.letter.Text = LETRAS[index] or "?"
	row.text.Text = option
	row.tick.Visible = chosen

	local fill = revealed and Theme.Paper.Highlight
		or (chosen and Theme.Paper.Accent or Color3.fromRGB(246, 243, 233))
	row.button.BackgroundColor3 = fill
	row.button.BackgroundTransparency = (chosen or revealed) and 0 or 0.25
	row.text.TextColor3 = chosen and Color3.fromRGB(250, 250, 246) or Theme.Paper.Ink
	row.badge.BackgroundColor3 = chosen and Color3.fromRGB(250, 250, 246)
		or Color3.fromRGB(232, 228, 216)
	row.letter.TextColor3 = chosen and Theme.Paper.Accent or Theme.Paper.InkSoft
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
		for i = 1, #optionRows do
			paintOption(i, question.opciones[i],
				state.respuestas[index] == i, state.reveladas[index] == i)
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

	if not root.Visible then
		UI.show(root, 0.94)
	end
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
	UI.click()
	ExamUI.onWrite()
	state.respuestas[current] = option
	ExamUI.show(current)

	-- La chapita de la letra da un golpecito: confirma el clic sin
	-- esperar la respuesta del servidor.
	local row = optionRows[option]
	if row then
		local scale = UI.scaler(row.badge)
		scale.Scale = 1.4
		TweenService:Create(scale, UI.Motion.enter, { Scale = 1 }):Play()
	end

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
					local done = #typing.escrito
					typingLabel.RichText = true
					typingLabel.Text = string.format('<font color="#1C5CBA">%s</font>%s',
						string.sub(typing.objetivo, 1, done),
						string.sub(typing.objetivo, done + 1))
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

	UI.sound(success and Config.Sonidos.Acierto or Config.Sonidos.Error,
		0.3, success and 1.4 or 0.7)
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

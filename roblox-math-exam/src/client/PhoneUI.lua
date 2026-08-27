--!strict
--[[
	PhoneUI — la app RoGPT
	------------------------------------------------------------------
	Interfaz montada sobre la pantalla fisica del celular 3D que el
	alumno tiene soldado al cuerpo. No hay ninguna pantalla pegada a la
	camara: si el celular esta abajo del banco, la app esta abajo del
	banco, y para leerla hay que levantarlo (y arriesgarse).

	Flujo completo:
		sacar foto  ->  se ve la miniatura de la hoja
		enviar      ->  "Subiendo imagen..." + "RoGPT esta escribiendo"
		respuesta   ->  resolucion paso a paso, tipeada en vivo
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Strings = require(Shared:WaitForChild("Strings"))
local Theme = require(Shared:WaitForChild("Theme"))
local Util = require(Shared:WaitForChild("Util"))

local player = Players.LocalPlayer
local P = Config.Phone

local PhoneUI = {}
PhoneUI.onTakePhoto = nil :: (() -> ())?
PhoneUI.onSend = nil :: (() -> ())?
PhoneUI.onClose = nil :: (() -> ())?

local gui: SurfaceGui? = nil
local refs: { [string]: any } = {}
local busy = false
local pendingPhoto: any = nil
local lastPhoneState: any = nil
local typingToken = 0

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

local function scrollToBottom()
	task.defer(function()
		if refs.chat then
			refs.chat.CanvasPosition = Vector2.new(0, math.max(0, refs.chat.AbsoluteCanvasSize.Y))
		end
	end)
end

-- ─────────────────────────────────────────────────────────────
-- Construccion
-- ─────────────────────────────────────────────────────────────

function PhoneUI.mount(screenPart: BasePart)
	if gui then
		gui:Destroy()
	end
	local playerGui = player:WaitForChild("PlayerGui")

	gui = el("SurfaceGui", {
		Name = "RoGPT",
		Adornee = screenPart,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 600,
		LightInfluence = 0,
		Brightness = 2,
		MaxDistance = 25,
		Active = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})

	local screen = el("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Phone.Background,
		BorderSizePixel = 0,
	}, gui)

	-- ── Barra de estado ───────────────────────────────────
	local status = el("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
	}, screen)

	refs.clock = el("TextLabel", {
		Size = UDim2.new(0.4, 0, 1, 0),
		Position = UDim2.fromOffset(16, 0),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		Text = "10:24",
		TextColor3 = Theme.Phone.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, status)

	refs.battery = el("TextLabel", {
		Size = UDim2.new(0.5, -16, 1, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = "▮▮▮  100%",
		TextColor3 = Theme.Phone.Battery,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, status)

	-- ── Header de la app ──────────────────────────────────
	local header = el("Frame", {
		Size = UDim2.new(1, 0, 0, 62),
		Position = UDim2.fromOffset(0, 34),
		BackgroundColor3 = Theme.Phone.Surface,
		BorderSizePixel = 0,
	}, screen)

	local logo = el("Frame", {
		Size = UDim2.fromOffset(38, 38),
		Position = UDim2.fromOffset(14, 12),
		BackgroundColor3 = Theme.Phone.Accent,
		BorderSizePixel = 0,
	}, header)
	Util.roundify(logo, 12)

	el("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		Text = "R",
		TextColor3 = Color3.fromRGB(12, 14, 18),
		TextSize = 22,
	}, logo)

	el("TextLabel", {
		Size = UDim2.new(1, -70, 0, 22),
		Position = UDim2.fromOffset(62, 12),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		Text = "RoGPT",
		TextColor3 = Theme.Phone.Text,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, header)

	refs.subtitle = el("TextLabel", {
		Size = UDim2.new(1, -70, 0, 18),
		Position = UDim2.fromOffset(62, 32),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = Strings.get("phone.online", { model = P.ModelName }),
		TextColor3 = Theme.Phone.Accent,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, header)

	-- ── Chat ──────────────────────────────────────────────
	refs.chat = el("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -196),
		Position = UDim2.fromOffset(0, 96),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Phone.SurfaceAlt,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.Never,
	}, screen)

	el("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, refs.chat)

	el("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}, refs.chat)

	-- ── Barra de acciones ─────────────────────────────────
	local bar = el("Frame", {
		Size = UDim2.new(1, 0, 0, 100),
		Position = UDim2.new(0, 0, 1, -100),
		BackgroundColor3 = Theme.Phone.Surface,
		BorderSizePixel = 0,
	}, screen)

	local function actionButton(name: string, text: string, order: number, color: Color3): TextButton
		local button = el("TextButton", {
			Name = name,
			LayoutOrder = order,
			Size = UDim2.new(0, 0, 0, 46),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = color,
			AutoButtonColor = true,
			Font = Theme.FontBold,
			Text = text,
			TextColor3 = Theme.Phone.Text,
			TextSize = 17,
			BorderSizePixel = 0,
		}, bar)
		Util.roundify(button, 12)
		el("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, button)
		return button
	end

	el("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, bar)

	refs.photoButton = actionButton("Foto", Strings.get("phone.button.photo"), 1, Theme.Phone.SurfaceAlt)
	refs.sendButton = actionButton("Enviar", Strings.get("phone.button.send"), 2, Theme.Phone.Accent)
	refs.closeButton = actionButton("Guardar", Strings.get("phone.button.close"), 3, Theme.Phone.SurfaceAlt)

	refs.photoButton.MouseButton1Click:Connect(function()
		if PhoneUI.onTakePhoto then
			PhoneUI.onTakePhoto()
		end
	end)
	refs.sendButton.MouseButton1Click:Connect(function()
		if PhoneUI.onSend then
			PhoneUI.onSend()
		end
	end)
	refs.closeButton.MouseButton1Click:Connect(function()
		if PhoneUI.onClose then
			PhoneUI.onClose()
		end
	end)

	PhoneUI.reset()
	return gui
end

-- ─────────────────────────────────────────────────────────────
-- Mensajes
-- ─────────────────────────────────────────────────────────────

local order = 0

local function bubble(side: string, color: Color3): Frame
	order += 1
	local holder = el("Frame", {
		Name = "Msg",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, refs.chat)

	local frame = el("Frame", {
		Name = "Bubble",
		Size = UDim2.new(0.88, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = side == "user" and UDim2.new(1, 0, 0, 0) or UDim2.new(0, 0, 0, 0),
		AnchorPoint = side == "user" and Vector2.new(1, 0) or Vector2.new(0, 0),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, holder)
	Util.roundify(frame, 14)
	el("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}, frame)
	el("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, frame)

	return frame
end

local function line(parent: Frame, text: string, size: number, color: Color3, font: Enum.Font?, layoutOrder: number?): TextLabel
	return el("TextLabel", {
		LayoutOrder = layoutOrder or 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = font or Theme.Font,
		Text = text,
		TextColor3 = color,
		TextSize = size,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
end

function PhoneUI.assistant(text: string): Frame
	local frame = bubble("assistant", Theme.Phone.Surface)
	line(frame, text, 16, Theme.Phone.Text)
	scrollToBottom()
	return frame
end

function PhoneUI.user(text: string): Frame
	local frame = bubble("user", Theme.Phone.User)
	line(frame, text, 16, Theme.Phone.Text)
	scrollToBottom()
	return frame
end

function PhoneUI.system(text: string)
	order += 1
	el("TextLabel", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = text,
		TextColor3 = Theme.Phone.TextSoft,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, refs.chat)
	scrollToBottom()
end

--- Miniatura de la foto: la hoja fotografiada, con su enunciado.
function PhoneUI.photo(photoData: any): Frame
	local frame = bubble("user", Theme.Phone.User)

	local sheet = el("Frame", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 118),
		BackgroundColor3 = Theme.Paper.Background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, frame)
	Util.roundify(sheet, 8)
	el("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(214, 214, 206)),
		Rotation = 65,
	}, sheet)

	el("TextLabel", {
		Size = UDim2.new(1, -20, 0, 14),
		Position = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = Strings.get("phone.sheetHeader"),
		TextColor3 = Theme.Paper.InkSoft,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, sheet)

	el("TextLabel", {
		Size = UDim2.new(1, -20, 0, 70),
		Position = UDim2.fromOffset(10, 30),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		Text = Strings.get(photoData.promptKey, photoData.promptArgs),
		TextColor3 = Theme.Paper.Ink,
		TextSize = 15,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, sheet)

	el("TextLabel", {
		Size = UDim2.new(1, -20, 0, 12),
		Position = UDim2.new(0, 10, 1, -20),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = photoData.photoId .. ".jpg",
		TextColor3 = Theme.Paper.InkSoft,
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, sheet)

	line(frame, Strings.get("phone.caption"), 15, Theme.Phone.Text, nil, 2)
	scrollToBottom()
	return frame
end

--- Burbuja "escribiendo..." con los tres puntitos animados.
function PhoneUI.typing(): (Frame, () -> ())
	local frame = bubble("assistant", Theme.Phone.Surface)
	local typingText = Strings.get("phone.typing")
	local label = line(frame, typingText, 16, Theme.Phone.TextSoft)
	scrollToBottom()

	local alive = true
	task.spawn(function()
		local dots = 0
		while alive and label.Parent do
			dots = (dots + 1) % 4
			label.Text = typingText .. string.rep(".", dots)
			task.wait(0.35)
		end
	end)

	return frame, function()
		alive = false
		local holder = frame.Parent
		if holder then
			holder:Destroy()
		end
	end
end

-- ─────────────────────────────────────────────────────────────
-- Respuesta tipeada
-- ─────────────────────────────────────────────────────────────

local function typeInto(label: TextLabel, text: string, token: number)
	local speed = P.TypeSpeed
	local shown = 0
	local total = #text
	while shown < total do
		if typingToken ~= token or not label.Parent then
			label.Text = text
			return
		end
		local dt = RunService.Heartbeat:Wait()
		shown = math.min(total, shown + speed * dt)
		label.Text = string.sub(text, 1, math.floor(shown))
		scrollToBottom()
	end
	label.Text = text
end

--- Escribe la resolucion completa, paso por paso, como si la fuera pensando.
function PhoneUI.answer(response: any)
	typingToken += 1
	local token = typingToken

	local frame = bubble("assistant", Theme.Phone.Surface)
	line(frame, Strings.get(response.topicKey), 12, Theme.Phone.Accent, Theme.FontBold, 0)

	task.spawn(function()
		local index = 1
		for _, step in response.steps do
			if typingToken ~= token then
				return
			end
			index += 1
			local stepTitle = Strings.get(step.titleKey)
			local title = line(frame, stepTitle, 15, Theme.Phone.Text, Theme.FontBold, index)
			title.Text = ""
			typeInto(title, stepTitle, token)

			index += 1
			local body = line(frame, step.body, 15, Theme.Phone.TextSoft, Theme.FontMono, index)
			body.Text = ""
			typeInto(body, step.body, token)
			task.wait(0.12)
		end

		if typingToken ~= token then
			return
		end

		index += 1
		local result = el("Frame", {
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = Theme.Phone.Accent,
			BorderSizePixel = 0,
		}, frame)
		Util.roundify(result, 10)
		el("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Theme.FontBold,
			Text = Strings.get("phone.answer", { answer = Strings.choice(tostring(response.answer)) }),
			TextColor3 = Color3.fromRGB(10, 14, 16),
			TextSize = 18,
		}, result)

		index += 1
		line(frame, Strings.get("phone.markIt"), 13, Theme.Phone.TextSoft, nil, index)
		scrollToBottom()
	end)
end

-- ─────────────────────────────────────────────────────────────
-- Estado
-- ─────────────────────────────────────────────────────────────

function PhoneUI.reset()
	typingToken += 1
	pendingPhoto = nil
	busy = false
	if refs.chat then
		for _, child in refs.chat:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end
	order = 0
	if refs.chat then
		PhoneUI.system(Strings.get("phone.today", { model = P.ModelName }))
		PhoneUI.assistant(Strings.get("phone.greeting"))
	end
	PhoneUI.refreshButtons()
end

function PhoneUI.setPendingPhoto(photoData: any)
	pendingPhoto = photoData
	PhoneUI.refreshButtons()
end

function PhoneUI.getPendingPhoto(): any
	return pendingPhoto
end

function PhoneUI.setBusy(value: boolean)
	busy = value
	PhoneUI.refreshButtons()
end

function PhoneUI.refreshButtons()
	if not refs.sendButton then
		return
	end
	local hasPhoto = pendingPhoto ~= nil
	refs.sendButton.BackgroundColor3 = (hasPhoto and not busy) and Theme.Phone.Accent or Theme.Phone.SurfaceAlt
	refs.sendButton.TextColor3 = (hasPhoto and not busy) and Theme.Phone.Text or Theme.Phone.TextSoft
	refs.sendButton.Text = Strings.get(hasPhoto and "phone.button.sendPhoto" or "phone.button.send")
	refs.photoButton.Text = busy and "···" or Strings.get("phone.button.photo")
end

function PhoneUI.setPhoneState(state: any)
	lastPhoneState = state
	if not refs.battery then
		return
	end
	local bars = math.clamp(math.ceil(state.battery / 34), 0, 3)
	refs.battery.Text = string.format("%s%s  %d%%", string.rep("▮", bars), string.rep("▯", 3 - bars), state.battery)
	refs.battery.TextColor3 = state.battery > 20 and Theme.Phone.Battery or Theme.Phone.Danger

	if state.confiscated then
		refs.subtitle.Text = Strings.get("phone.noSignal")
		refs.subtitle.TextColor3 = Theme.Phone.Danger
	else
		refs.subtitle.Text = Strings.get("phone.online", { model = P.ModelName })
		refs.subtitle.TextColor3 = Theme.Phone.Accent
	end
end

function PhoneUI.setClock(text: string)
	if refs.clock then
		refs.clock.Text = text
	end
end

function PhoneUI.setEnabled(enabled: boolean)
	if gui then
		gui.Enabled = enabled
	end
end

--- Reescribe lo fijo de la pantalla cuando cambia el idioma. El chat
--- ya escrito se queda como estaba: es una conversacion pasada.
function PhoneUI.refreshTexts()
	if not refs.sendButton then
		return
	end
	refs.closeButton.Text = Strings.get("phone.button.close")
	PhoneUI.refreshButtons()
	if lastPhoneState then
		PhoneUI.setPhoneState(lastPhoneState)
	end
end

function PhoneUI.destroy()
	typingToken += 1
	if gui then
		gui:Destroy()
		gui = nil
	end
	refs = {}
end

return PhoneUI

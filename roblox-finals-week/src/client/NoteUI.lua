--!strict
--[[
	NoteUI
	------------------------------------------------------------------
	Escribir una nota y lanzarla.

	La nota lleva dos cosas: un texto libre (lo que se lee al recibirla)
	y, opcional, un par pregunta/opcion. Si trae el par, al impactar la
	respuesta se escribe sola en la hoja del que la recibio: eso es lo
	que hace que pasar papelitos sea util y no decorativo.

	El cliente NUNCA manda una posicion de impacto: manda la direccion
	en la que apunta la camara y el servidor hace el resto.
--]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Strings = require(Shared:WaitForChild("Strings"))
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local player = Players.LocalPlayer

local NoteUI = {}

local LETRAS = { "A", "B", "C", "D" }

local root: Frame
local textBox: TextBox
local questionLabel: TextLabel
local optionButtons: { TextButton } = {}
local crosshair: Frame
local incoming: Frame
local incomingText: TextLabel

--- Lo rellena el init del cliente: dispara la animacion de lanzar.
NoteUI.onThrow = function() end

local draft = { indice = 1, opcion = 0, texto = "" }
local equipped: Tool? = nil

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

local function send()
	Net.event(Net.Events.NoteText):FireServer({
		indice = draft.opcion > 0 and draft.indice or nil,
		opcion = draft.opcion > 0 and draft.opcion or nil,
		texto = draft.texto,
	})
end

local function refresh()
	questionLabel.Text = Strings.get("exam.question",
		{ i = draft.indice, n = Config.Examen.MaximoPreguntas })
	for i, button in optionButtons do
		local on = draft.opcion == i
		button.BackgroundColor3 = on and Theme.Paper.Accent or Color3.fromRGB(238, 236, 228)
		button.TextColor3 = on and Color3.fromRGB(250, 250, 246) or Theme.Paper.Ink
	end
end

-- ── construccion ───────────────────────────────────────────────────

function NoteUI.mount(parent: ScreenGui)
	root = new("Frame", {
		Name = "Nota",
		Size = UDim2.new(0, 300, 0, 196),
		Position = UDim2.new(0, 16, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Paper.Background,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 4,
	}, parent)
	corner(root, 12)
	new("UIStroke", { Color = Theme.Paper.Line, Thickness = 2 }, root)

	new("TextLabel", {
		Name = "Titulo",
		Text = Strings.get("note.write"),
		Size = UDim2.new(1, -24, 0, 22),
		Position = UDim2.new(0, 12, 0, 10),
		BackgroundTransparency = 1,
		Font = Theme.FontBlack,
		TextSize = 16,
		TextColor3 = Theme.Paper.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
	}, root)

	textBox = new("TextBox", {
		Name = "Texto",
		Text = "",
		PlaceholderText = Strings.get("note.placeholder"),
		Size = UDim2.new(1, -24, 0, 42),
		Position = UDim2.new(0, 12, 0, 36),
		BackgroundColor3 = Color3.fromRGB(240, 238, 230),
		Font = Theme.Font,
		TextSize = 13,
		TextColor3 = Theme.Paper.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ClearTextOnFocus = false,
		MultiLine = true,
		TextWrapped = true,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, root)
	corner(textBox, 8)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 6) }, textBox)
	textBox:GetPropertyChangedSignal("Text"):Connect(function()
		if #textBox.Text > Config.Objetos.NotaCaracteres then
			textBox.Text = string.sub(textBox.Text, 1, Config.Objetos.NotaCaracteres)
		end
		draft.texto = textBox.Text
		send()
	end)

	-- Selector de pregunta: dos flechas y el numero.
	local minus = new("TextButton", {
		Name = "Menos", Text = "-",
		Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(0, 12, 0, 88),
		BackgroundColor3 = Color3.fromRGB(238, 236, 228), AutoButtonColor = false,
		Font = Theme.FontBlack, TextSize = 18, TextColor3 = Theme.Paper.Ink,
		BorderSizePixel = 0, ZIndex = 5,
	}, root)
	corner(minus, 8)
	local plus = new("TextButton", {
		Name = "Mas", Text = "+",
		Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(0, 168, 0, 88),
		BackgroundColor3 = Color3.fromRGB(238, 236, 228), AutoButtonColor = false,
		Font = Theme.FontBlack, TextSize = 18, TextColor3 = Theme.Paper.Ink,
		BorderSizePixel = 0, ZIndex = 5,
	}, root)
	corner(plus, 8)
	questionLabel = new("TextLabel", {
		Name = "Pregunta", Text = "",
		Size = UDim2.new(0, 120, 0, 28), Position = UDim2.new(0, 44, 0, 88),
		BackgroundTransparency = 1, Font = Theme.FontBold, TextSize = 13,
		TextColor3 = Theme.Paper.InkSoft, ZIndex = 5,
	}, root)

	minus.MouseButton1Click:Connect(function()
		draft.indice = math.max(1, draft.indice - 1)
		refresh()
		send()
	end)
	plus.MouseButton1Click:Connect(function()
		draft.indice = math.min(Config.Examen.MaximoPreguntas, draft.indice + 1)
		refresh()
		send()
	end)

	-- Las cuatro letras.
	for i = 1, 4 do
		local button = new("TextButton", {
			Name = "Letra" .. i,
			Text = LETRAS[i],
			Size = UDim2.new(0, 32, 0, 32),
			Position = UDim2.new(0, 12 + (i - 1) * 38, 0, 122),
			BackgroundColor3 = Color3.fromRGB(238, 236, 228),
			AutoButtonColor = false,
			Font = Theme.FontBlack,
			TextSize = 15,
			TextColor3 = Theme.Paper.Ink,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, root)
		corner(button, 8)
		button.MouseButton1Click:Connect(function()
			draft.opcion = draft.opcion == i and 0 or i
			refresh()
			send()
		end)
		optionButtons[i] = button
	end

	new("TextLabel", {
		Name = "Pie",
		Text = Strings.get("note.throw"),
		Size = UDim2.new(1, -24, 0, 20),
		Position = UDim2.new(0, 12, 1, -28),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextSize = 12,
		TextColor3 = Theme.Paper.InkSoft,
		ZIndex = 5,
	}, root)

	-- Mira: solo cuando tenes algo lanzable en la mano.
	crosshair = new("Frame", {
		Name = "Mira",
		Size = UDim2.new(0, 4, 0, 4),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(250, 250, 246),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 4,
	}, parent)
	corner(crosshair, 2)

	-- La nota que te llega.
	incoming = new("Frame", {
		Name = "NotaRecibida",
		Size = UDim2.new(0, 300, 0, 76),
		Position = UDim2.new(0.5, 0, 0, 96),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.Paper.Background,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 9,
	}, parent)
	corner(incoming, 10)
	new("UIStroke", { Color = Theme.Paper.Accent, Thickness = 2 }, incoming)
	incomingText = new("TextLabel", {
		Name = "Texto",
		Text = "",
		Size = UDim2.new(1, -20, 1, -12),
		Position = UDim2.new(0, 10, 0, 6),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextSize = 13,
		TextColor3 = Theme.Paper.Ink,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 10,
	}, incoming)

	refresh()
	NoteUI.watchTools()
	NoteUI.bindInput()
end

-- ── herramienta equipada ───────────────────────────────────────────

local function isThrowable(tool: Tool?): boolean
	return tool ~= nil and tool:GetAttribute("Lanzable") == true
end

local function isWritable(tool: Tool?): boolean
	return tool ~= nil and tool:FindFirstChild("Texto") ~= nil
end

local function onCharacter(character: Model)
	local function check()
		equipped = character:FindFirstChildOfClass("Tool")
		root.Visible = isWritable(equipped)
		crosshair.Visible = isThrowable(equipped)
	end
	character.ChildAdded:Connect(check)
	character.ChildRemoved:Connect(check)
	check()
end

function NoteUI.watchTools()
	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

-- ── lanzar ─────────────────────────────────────────────────────────

function NoteUI.throw()
	if not isThrowable(equipped) then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	NoteUI.onThrow()
	-- Solo la direccion: el servidor decide de donde sale y a donde llega.
	Net.event(Net.Events.Throw):FireServer(camera.CFrame.LookVector)
end

function NoteUI.bindInput()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F then
			NoteUI.throw()
		end
	end)
end

function NoteUI.received(data: any)
	if not incoming then
		return
	end
	local pieces = { Strings.get("note.received", { name = data.de or "?" }) }
	if data.texto and data.texto ~= "" then
		table.insert(pieces, Strings.get("note.read") .. " " .. data.texto)
	end
	if data.indice and data.opcion then
		table.insert(pieces, string.format("%d -> %s", data.indice, LETRAS[data.opcion] or "?"))
	end
	incomingText.Text = table.concat(pieces, "\n")
	incoming.Visible = true

	local token = os.clock()
	incoming:SetAttribute("Token", token)
	task.delay(6, function()
		if incoming:GetAttribute("Token") == token then
			incoming.Visible = false
		end
	end)
end

function NoteUI.setVisible(visible: boolean)
	if root then
		root.Visible = visible and isWritable(equipped)
	end
	if crosshair then
		crosshair.Visible = visible and isThrowable(equipped)
	end
end

return NoteUI

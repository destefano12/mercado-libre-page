--!strict
--[[
	MainMenu
	------------------------------------------------------------------
	El menu de inicio: jugar, salas, tienda, ajustes y creditos.

	Se abre solo la primera vez que entras y despues con Esc/M. Mientras
	esta abierto el HUD se apaga: el menu no es un overlay mas, es una
	pantalla.
--]]

local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Strings = require(Shared:WaitForChild("Strings"))
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local MainMenu = {}

local root: Frame
local pages: { [string]: Frame } = {}

local settings = { brillo = 2, volumen = 0.6, musica = true, sensibilidad = 0.5 }

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
	Util.playSound(Config.Sonidos.Click, workspace :: any, 0.3, 1.1)
end

-- Callbacks que rellena el init del cliente.
MainMenu.onPlay = function(_mode: string) end
MainMenu.onRooms = function() end
MainMenu.onShop = function() end
MainMenu.onMusic = function(_on: boolean) end
MainMenu.onVisible = function(_open: boolean) end

-- ── piezas ─────────────────────────────────────────────────────────

local function bigButton(parent: Instance, order: number, key: string, descKey: string?,
	callback: () -> ()): TextButton
	local button = new("TextButton", {
		Name = key,
		LayoutOrder = order,
		Text = "",
		Size = UDim2.new(1, 0, 0, descKey and 58 or 44),
		BackgroundColor3 = Theme.Menu.PanelAlt,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 21,
	}, parent)
	corner(button, 10)
	new("UIStroke", { Color = Theme.Menu.Line, Thickness = 1, Transparency = 0.55 }, button)

	new("TextLabel", {
		Text = Strings.get(key),
		Size = UDim2.new(1, -28, 0, 22),
		Position = UDim2.new(0, 16, 0, descKey and 10 or 11),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		TextSize = 16,
		TextColor3 = Theme.Menu.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 22,
	}, button)

	if descKey then
		new("TextLabel", {
			Text = Strings.get(descKey),
			Size = UDim2.new(1, -28, 0, 18),
			Position = UDim2.new(0, 16, 0, 32),
			BackgroundTransparency = 1,
			Font = Theme.Font,
			TextSize = 12,
			TextColor3 = Theme.Menu.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 22,
		}, button)
	end

	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = Theme.Menu.Line
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = Theme.Menu.PanelAlt
	end)
	button.MouseButton1Click:Connect(function()
		click()
		callback()
	end)
	return button
end

--- Un deslizador simple hecho con dos frames y arrastre del mouse.
local function slider(parent: Instance, order: number, key: string, value: number,
	callback: (number) -> ())
	local holder = new("Frame", {
		Name = key,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundTransparency = 1,
		ZIndex = 21,
	}, parent)

	local title = new("TextLabel", {
		Text = Strings.get(key),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		TextSize = 13,
		TextColor3 = Theme.Menu.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 22,
	}, holder)

	local track = new("TextButton", {
		Name = "Barra",
		Text = "",
		Size = UDim2.new(1, 0, 0, 10),
		Position = UDim2.new(0, 0, 0, 28),
		BackgroundColor3 = Theme.Menu.PanelAlt,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 22,
	}, holder)
	corner(track, 5)

	local fill = new("Frame", {
		Name = "Relleno",
		Size = UDim2.fromScale(value, 1),
		BackgroundColor3 = Theme.Menu.Accent,
		BorderSizePixel = 0,
		ZIndex = 23,
	}, track)
	corner(fill, 5)

	local function setFrom(x: number)
		local absolute = track.AbsolutePosition.X
		local width = math.max(1, track.AbsoluteSize.X)
		local alpha = math.clamp((x - absolute) / width, 0, 1)
		fill.Size = UDim2.fromScale(alpha, 1)
		title.Text = string.format("%s  %d%%", Strings.get(key), math.floor(alpha * 100 + 0.5))
		callback(alpha)
	end

	local dragging = false
	track.MouseButton1Down:Connect(function(x)
		dragging = true
		setFrom(x)
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			setFrom(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	title.Text = string.format("%s  %d%%", Strings.get(key), math.floor(value * 100 + 0.5))
end

local function page(name: string, titleKey: string): Frame
	local frame = new("Frame", {
		Name = name,
		Size = UDim2.new(0, 420, 1, -160),
		Position = UDim2.new(0.5, 0, 0, 130),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 21,
	}, root)

	if titleKey ~= "" then
		new("TextLabel", {
			Text = Strings.get(titleKey),
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 1,
			Font = Theme.FontBlack,
			TextSize = 18,
			TextColor3 = Theme.Menu.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 22,
		}, frame)
	end

	local body = new("Frame", {
		Name = "Cuerpo",
		Size = UDim2.new(1, 0, 1, titleKey ~= "" and -38 or 0),
		Position = UDim2.new(0, 0, 0, titleKey ~= "" and 38 or 0),
		BackgroundTransparency = 1,
		ZIndex = 21,
	}, frame)
	new("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, body)

	pages[name] = frame
	return body
end

local function goTo(name: string)
	for id, frame in pages do
		frame.Visible = id == name
	end
end

-- ── construccion ───────────────────────────────────────────────────

function MainMenu.mount(parent: ScreenGui)
	root = new("Frame", {
		Name = "Menu",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Menu.Scrim,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 20,
	}, parent)

	new("TextLabel", {
		Name = "Titulo",
		Text = Strings.get("menu.title"),
		Size = UDim2.new(1, 0, 0, 54),
		Position = UDim2.new(0, 0, 0, 46),
		BackgroundTransparency = 1,
		Font = Theme.FontBlack,
		TextSize = 44,
		TextColor3 = Theme.Menu.Text,
		ZIndex = 21,
	}, root)
	new("TextLabel", {
		Name = "Subtitulo",
		Text = Strings.get("menu.subtitle"),
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 0, 98),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextSize = 14,
		TextColor3 = Theme.Menu.Muted,
		ZIndex = 21,
	}, root)

	-- Inicio
	local home = page("inicio", "")
	bigButton(home, 1, "menu.play", "menu.public_desc", function()
		MainMenu.onPlay("publico")
		MainMenu.close()
	end)
	bigButton(home, 2, "menu.rooms", "menu.friends_desc", function()
		MainMenu.onRooms()
	end)
	bigButton(home, 3, "menu.shop", nil, function()
		MainMenu.onShop()
	end)
	bigButton(home, 4, "menu.settings", nil, function()
		goTo("ajustes")
	end)
	bigButton(home, 5, "menu.credits", nil, function()
		goTo("creditos")
	end)

	-- Ajustes
	local options = page("ajustes", "menu.settings")
	slider(options, 1, "menu.brightness", 0.5, function(alpha)
		settings.brillo = alpha * 4
		pcall(function()
			Lighting.Brightness = settings.brillo
		end)
	end)
	slider(options, 2, "menu.volume", 0.6, function(alpha)
		settings.volumen = alpha
		for _, name in { "Master", "Musica" } do
			local group = SoundService:FindFirstChild(name)
			if group and group:IsA("SoundGroup") then
				group.Volume = name == "Musica"
					and Config.Musica.Volumen * alpha * 2 or alpha
			end
		end
	end)
	slider(options, 3, "menu.sensitivity", 0.5, function(alpha)
		settings.sensibilidad = alpha
		pcall(function()
			local userSettings = UserSettings():GetService("UserGameSettings")
			userSettings.MouseSensitivity = 0.2 + alpha * 1.6
		end)
	end)
	bigButton(options, 4, "menu.music", nil, function()
		settings.musica = not settings.musica
		MainMenu.onMusic(settings.musica)
	end)
	bigButton(options, 5, "menu.back", nil, function()
		goTo("inicio")
	end)

	-- Creditos
	local credits = page("creditos", "credits.title")
	new("TextLabel", {
		LayoutOrder = 1,
		Text = Strings.get("credits.body"),
		Size = UDim2.new(1, 0, 0, 70),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextSize = 14,
		TextColor3 = Theme.Menu.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		ZIndex = 22,
	}, credits)
	new("TextLabel", {
		LayoutOrder = 2,
		Text = Strings.get("credits.thanks"),
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		TextSize = 14,
		TextColor3 = Theme.Menu.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		ZIndex = 22,
	}, credits)
	bigButton(credits, 3, "menu.back", nil, function()
		goTo("inicio")
	end)

	goTo("inicio")

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.M then
			if root.Visible then
				MainMenu.close()
			else
				MainMenu.open()
			end
		elseif input.KeyCode == Enum.KeyCode.Escape and root.Visible then
			MainMenu.close()
		end
	end)
end

function MainMenu.open()
	if not root then
		return
	end
	goTo("inicio")
	root.Visible = true
	MainMenu.onVisible(true)
end

function MainMenu.close()
	if not root then
		return
	end
	root.Visible = false
	MainMenu.onVisible(false)
	task.spawn(function()
		pcall(function()
			Net.func(Net.Functions.ChooseMode):InvokeServer("publico")
		end)
	end)
end

function MainMenu.isOpen(): boolean
	return root ~= nil and root.Visible
end

function MainMenu.musicEnabled(): boolean
	return settings.musica
end

return MainMenu

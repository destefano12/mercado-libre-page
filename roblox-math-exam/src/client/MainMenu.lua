--!strict
--[[
	MainMenu
	------------------------------------------------------------------
	Menu de inicio, minimalista: fondo casi negro, una columna de
	opciones y el aula girando despacio atras. Nada de botones enormes
	ni degradados.

		Jugar     -> entra al aula
		Partida   -> solo / con amigos / con todos
		Ajustes   -> brillo, volumen, idioma, nombres
		Creditos

	Los ajustes se guardan en memoria del cliente: se pierden al salir
	del juego, que para dos sliders y un idioma alcanza.
--]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local Theme = require(Shared:WaitForChild("Theme"))
local Util = require(Shared:WaitForChild("Util"))

local LobbyUI = require(script.Parent:WaitForChild("LobbyUI"))

local player = Players.LocalPlayer

local MainMenu = {}
MainMenu.onPlay = nil :: (() -> ())?
MainMenu.onLocaleChanged = nil :: (() -> ())?
MainMenu.open = false

MainMenu.settings = {
	brightness = 0.32,
	volume = 0.7,
	locale = "auto",
	names = true,
	mode = "public",
}

local refs: { [string]: any } = {}
local rebuilders: { () -> () } = {}

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

-- ─────────────────────────────────────────────────────────────
-- Ajustes aplicados
-- ─────────────────────────────────────────────────────────────

local function applyBrightness()
	-- Los cambios de Lighting hechos desde el cliente son locales:
	-- cada uno ve el aula con el brillo que eligio.
	-- Arranca en 0.32 = exposicion 0. Antes el valor por defecto sumaba
	-- exposicion encima de la del servidor y quemaba el aula entera.
	Lighting.ExposureCompensation = -0.5 + MainMenu.settings.brightness * 1.56
end

local function applyVolume()
	local group = SoundService:FindFirstChild("Master")
	if not group then
		group = el("SoundGroup", { Name = "Master", Parent = SoundService })
	end
	;(group :: SoundGroup).Volume = MainMenu.settings.volume
end

function MainMenu.applyAll()
	applyBrightness()
	applyVolume()
end

-- ─────────────────────────────────────────────────────────────
-- Piezas de UI
-- ─────────────────────────────────────────────────────────────

local function label(parent: Instance, text: string, size: number, color: Color3, order: number, font: Enum.Font?): TextLabel
	return el("TextLabel", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, math.floor(size * 1.5)),
		BackgroundTransparency = 1,
		Font = font or Theme.Font,
		Text = text,
		TextColor3 = color,
		TextSize = size,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}, parent)
end

--- Slider fino, sin adornos: una linea, un punto y el valor a la derecha.
local function slider(parent: Instance, order: number, key: string, get: () -> number, set: (number) -> ())
	local row = el("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundTransparency = 1,
	}, parent)

	local name = el("TextLabel", {
		Size = UDim2.new(1, -60, 0, 20),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = Strings.get(key),
		TextColor3 = Theme.Menu.Muted,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local value = el("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(60, 20),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		Text = "",
		TextColor3 = Theme.Menu.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, row)

	local track = el("TextButton", {
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = Theme.Menu.Line,
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
	}, row)
	Util.roundify(track, 2)

	local fill = el("Frame", {
		Size = UDim2.fromScale(get(), 1),
		BackgroundColor3 = Theme.Menu.Accent,
		BorderSizePixel = 0,
	}, track)
	Util.roundify(fill, 2)

	local knob = el("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(get(), 0.5),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Theme.Menu.Accent,
		BorderSizePixel = 0,
	}, track)
	Util.roundify(knob, 7)

	local function refresh()
		local alpha = get()
		fill.Size = UDim2.fromScale(alpha, 1)
		knob.Position = UDim2.fromScale(alpha, 0.5)
		value.Text = string.format("%d%%", math.floor(alpha * 100 + 0.5))
		name.Text = Strings.get(key)
	end
	refresh()
	table.insert(rebuilders, refresh)

	local dragging = false
	local function update(x: number)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		set(alpha)
		refresh()
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			update(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			update(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

--- Fila que cicla entre opciones al tocarla.
local function cycler(parent: Instance, order: number, key: string, options: { string }, get: () -> string, set: (string) -> (), display: (string) -> string)
	local row = el("TextButton", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
	}, parent)

	local name = el("TextLabel", {
		Size = UDim2.new(0.6, 0, 1, 0),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = Strings.get(key),
		TextColor3 = Theme.Menu.Muted,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local value = el("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0.4, 0, 1, 0),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		Text = "",
		TextColor3 = Theme.Menu.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, row)

	el("Frame", {
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Menu.Line,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
	}, row)

	local function refresh()
		name.Text = Strings.get(key)
		value.Text = display(get())
	end
	refresh()
	table.insert(rebuilders, refresh)

	row.MouseButton1Click:Connect(function()
		local index = table.find(options, get()) or 1
		set(options[index % #options + 1])
		refresh()
	end)
end

-- ─────────────────────────────────────────────────────────────
-- Paneles
-- ─────────────────────────────────────────────────────────────

local function clearPanel()
	-- Los refrescos pertenecen a los controles del panel: si no se
	-- limpian, cada vez que abris Ajustes se apilan de nuevo.
	table.clear(rebuilders)
	for _, child in refs.panel:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function panelList(): Frame
	clearPanel()
	local list = el("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, refs.panel)
	el("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, list)
	return list
end

local function showSettings()
	local list = panelList()
	label(list, Strings.get("menu.settings"), 24, Theme.Menu.Text, 1, Theme.FontBold)
	slider(list, 2, "menu.settings.brightness",
		function() return MainMenu.settings.brightness end,
		function(v) MainMenu.settings.brightness = v applyBrightness() end)
	slider(list, 3, "menu.settings.volume",
		function() return MainMenu.settings.volume end,
		function(v) MainMenu.settings.volume = v applyVolume() end)
	cycler(list, 4, "menu.settings.language", { "auto", "es", "en", "pt" },
		function() return MainMenu.settings.locale end,
		function(v)
			MainMenu.settings.locale = v
			if MainMenu.onLocaleChanged then
				MainMenu.onLocaleChanged()
			end
		end,
		function(v)
			return v == "auto" and Strings.get("menu.settings.language.auto") or string.upper(v)
		end)
	cycler(list, 5, "menu.settings.names", { "on", "off" },
		function() return MainMenu.settings.names and "on" or "off" end,
		function(v) MainMenu.settings.names = v == "on" end,
		function(v) return Strings.get(v == "on" and "menu.settings.on" or "menu.settings.off") end)
end

local function showModes()
	clearPanel()
	-- El buscador de salas se dibuja solo adentro del panel.
	LobbyUI.render(refs.panel)
end

local function showCredits()
	local list = panelList()
	label(list, Strings.get("menu.credits"), 24, Theme.Menu.Text, 1, Theme.FontBold)
	local body = label(list, Strings.get("menu.credits.body"), 16, Theme.Menu.Muted, 2)
	body.Size = UDim2.new(1, 0, 0, 220)
	body.TextYAlignment = Enum.TextYAlignment.Top
end

-- ─────────────────────────────────────────────────────────────
-- Montaje
-- ─────────────────────────────────────────────────────────────

function MainMenu.mount()
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("AulaMenu")
	if existing then
		existing:Destroy()
	end

	local screen = el("ScreenGui", {
		Name = "AulaMenu",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 20,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	refs.screen = screen

	-- El aula tiene que verse atras: el velo es suave y solo se oscurece
	-- del lado donde va el texto.
	local scrim = el("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Menu.Scrim,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
	}, screen)
	refs.scrim = scrim

	local shade = el("Frame", {
		Size = UDim2.fromScale(0.55, 1),
		BackgroundColor3 = Theme.Menu.Scrim,
		BorderSizePixel = 0,
	}, scrim)
	el("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.6, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, shade)

	-- Columna izquierda: titulo y opciones
	local left = el("Frame", {
		Position = UDim2.fromScale(0.08, 0),
		Size = UDim2.new(0, 340, 1, 0),
		BackgroundTransparency = 1,
	}, scrim)

	local stack = el("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 420),
		BackgroundTransparency = 1,
	}, left)
	el("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, stack)

	refs.title = label(stack, Strings.get("menu.title"), 34, Theme.Menu.Text, 1, Theme.FontBold)
	refs.subtitle = label(stack, Strings.get("menu.subtitle"), 16, Theme.Menu.Muted, 2)

	el("Frame", {
		LayoutOrder = 3,
		Size = UDim2.new(0, 48, 0, 1),
		BackgroundColor3 = Theme.Menu.Line,
		BorderSizePixel = 0,
	}, stack)

	el("Frame", { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1 }, stack)

	local entries = {
		{ key = "menu.play", action = function()
			MainMenu.hide()
			if MainMenu.onPlay then
				MainMenu.onPlay()
			end
		end },
		{ key = "menu.mode", action = showModes },
		{ key = "menu.settings", action = showSettings },
		{ key = "menu.credits", action = showCredits },
	}

	refs.entries = {}
	for index, entry in entries do
		local button = el("TextButton", {
			LayoutOrder = 10 + index,
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Font = index == 1 and Theme.FontBold or Theme.Font,
			Text = Strings.get(entry.key),
			TextColor3 = index == 1 and Theme.Menu.Text or Theme.Menu.Muted,
			TextSize = index == 1 and 26 or 20,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, stack)

		button.MouseEnter:Connect(function()
			TweenService:Create(button, TweenInfo.new(0.15), { TextColor3 = Theme.Menu.Text }):Play()
		end)
		button.MouseLeave:Connect(function()
			TweenService:Create(button, TweenInfo.new(0.15), {
				TextColor3 = index == 1 and Theme.Menu.Text or Theme.Menu.Muted,
			}):Play()
		end)
		button.MouseButton1Click:Connect(entry.action)

		refs.entries[index] = { button = button, key = entry.key }
	end

	refs.hint = label(stack, Strings.get("menu.hint"), 13, Theme.Menu.Line, 30)

	-- Columna derecha: el panel que cambia
	refs.panel = el("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -80, 0.5, 0),
		Size = UDim2.new(0, 380, 0, 460),
		BackgroundTransparency = 1,
	}, scrim)

	MainMenu.applyAll()
	MainMenu.open = true
	return screen
end

--- Reescribe todo lo visible cuando cambia el idioma.
function MainMenu.refreshTexts()
	if not refs.screen then
		return
	end
	refs.title.Text = Strings.get("menu.title")
	refs.subtitle.Text = Strings.get("menu.subtitle")
	refs.hint.Text = Strings.get("menu.hint")
	for _, entry in refs.entries do
		entry.button.Text = Strings.get(entry.key)
	end
	for _, refresh in rebuilders do
		pcall(refresh)
	end
end

function MainMenu.hide()
	MainMenu.open = false
	if not refs.screen then
		return
	end
	refs.screen.Enabled = false
end

function MainMenu.show()
	MainMenu.open = true
	if refs.screen then
		refs.screen.Enabled = true
	end
end

return MainMenu

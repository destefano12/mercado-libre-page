--!strict
--[[
	MainMenu
	------------------------------------------------------------------
	La pantalla de titulo. Jugar, salas, tienda, ajustes y creditos.

	Lo que cambio respecto de la version anterior, y por que:

	- Antes el jugador caia al mundo y *despues* le tapaban la pantalla
	  con un scrim al 94%: se veia el personaje parado en el pasillo
	  detras de un vidrio sucio. Ahora la camara se desengancha del
	  personaje y se planta en una toma compuesta del corredor, con un
	  dolly lento. Es una pantalla de titulo, no un overlay.

	- El scrim ocupaba todo. Ahora es una columna a la izquierda con
	  degradado: la escuela queda a la vista a la derecha, que es para
	  lo que se construyo.

	- Los botones cambiaban de color de golpe al pasar el mouse y no
	  hacian nada al presionar. Eso ahora lo resuelve `UI.button`.

	- `goTo` prendia y apagaba `.Visible`. Ahora las paginas entran y
	  salen con deslizamiento y fundido.
--]]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Strings = require(Shared:WaitForChild("Strings"))
local Config = require(Shared:WaitForChild("Config"))
local UI = require(Shared:WaitForChild("UI"))

local MainMenu = {}

local root: Frame
local column: Frame
local pages: { [string]: CanvasGroup } = {}
local currentPage = "inicio"

local blur: BlurEffect? = nil
local cameraLoop: RBXScriptConnection? = nil
local savedCamera: CFrame? = nil
local savedSubject: Humanoid? = nil

local settings = { brillo = 2, volumen = 0.6, musica = true, sensibilidad = 0.5 }

-- Se elige modo una sola vez por sesion: al tocar Jugar, o al cerrar
-- el menu sin haberlo tocado.
local modeChosen = false

-- Ancho de la columna de la izquierda. Todo lo demas es escuela.
local COLUMN = 430

-- Callbacks que rellena el init del cliente.
MainMenu.onPlay = function(_mode: string) end
MainMenu.onRooms = function() end
MainMenu.onShop = function() end
MainMenu.onMusic = function(_on: boolean) end
MainMenu.onVisible = function(_open: boolean) end

-- ── la toma de la camara ───────────────────────────────────────────

--[[
	Busca el pasillo y arma una toma en tres cuartos: la camara mira a
	lo largo del corredor, apenas descentrada, para que los casilleros
	se vayan en fuga hacia el punto de vista. Si el mapa todavia no
	existe (el servidor lo construye al arrancar) cae en una posicion
	fija y no se rompe nada.
--]]
local function shotFrame(): (CFrame, CFrame)
	local instituto = workspace:FindFirstChild("Instituto")
	local hall = instituto and instituto:FindFirstChild("Pasillo")
	if hall and hall:IsA("Model") then
		local ok, box = pcall(function()
			local cf, size = hall:GetBoundingBox()
			return { cf = cf, size = size }
		end)
		if ok and box then
			local centre = box.cf.Position
			local half = box.size.Z * 0.5
			local eye = Vector3.new(centre.X + 3.2, 5.6, centre.Z - half + 16)
			local look = Vector3.new(centre.X - 1.5, 4.4, centre.Z + half * 0.35)
			local finish = Vector3.new(centre.X + 1.4, 5.2, centre.Z - half + 34)
			return CFrame.lookAt(eye, look), CFrame.lookAt(finish, look)
		end
	end
	local eye = Vector3.new(3.2, 5.6, -79)
	local look = Vector3.new(-1.5, 4.4, 33)
	return CFrame.lookAt(eye, look), CFrame.lookAt(Vector3.new(1.4, 5.2, -61), look)
end

local function startCamera()
	local camera = workspace.CurrentCamera
	if not camera or cameraLoop then
		return
	end
	savedCamera = camera.CFrame
	savedSubject = camera.CameraSubject :: any
	camera.CameraType = Enum.CameraType.Scriptable

	local from, to = shotFrame()
	local elapsed = 0
	camera.CFrame = from

	-- Dolly de veinte segundos que despues vuelve. No hace falta que
	-- sea un bucle perfecto: nadie se queda mirando tanto el menu.
	cameraLoop = RunService.RenderStepped:Connect(function(dt: number)
		elapsed += dt
		local alpha = (math.sin(elapsed * 0.16 - math.pi * 0.5) + 1) * 0.5
		camera.CFrame = from:Lerp(to, alpha)
	end)
end

local function stopCamera()
	if cameraLoop then
		cameraLoop:Disconnect()
		cameraLoop = nil
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Custom
	if savedSubject then
		camera.CameraSubject = savedSubject
	end
	if savedCamera then
		camera.CFrame = savedCamera
	end
	savedCamera = nil
	savedSubject = nil
end

local function setBlur(on: boolean)
	if not blur then
		local existing = Lighting:FindFirstChild("MenuBlur")
		if existing and existing:IsA("BlurEffect") then
			blur = existing
		else
			blur = UI.new("BlurEffect", { Name = "MenuBlur", Size = 0, Parent = Lighting })
		end
	end
	local effect = blur
	if not effect then
		return
	end
	TweenService:Create(effect, UI.Motion.slow, { Size = on and 14 or 0 }):Play()
end

-- ── piezas ─────────────────────────────────────────────────────────

--[[
	Titulo en capas: una copia desplazada hace de sombra, el relleno
	lleva un degradado que va de tiza a mostaza, y el contorno lo da un
	UIStroke. Un solo TextLabel plano se lee como marcador de posicion;
	tres capas se leen como un logo.
--]]
local function buildTitle(parent: Instance)
	local holder = UI.new("Frame", {
		Name = "Titulo",
		Size = UDim2.new(1, 0, 0, 92),
		Position = UDim2.fromOffset(0, 54),
		BackgroundTransparency = 1,
		ZIndex = UI.Layer.Menu + 1,
		Parent = parent,
	})

	local shadow = UI.label({
		parent = holder,
		name = "Sombra",
		text = Strings.get("menu.title"),
		size = UDim2.new(1, 0, 0, 58),
		position = UDim2.fromOffset(3, 3),
		font = Theme.FontBlack,
		textSize = UI.Type.hero,
		color = Color3.fromRGB(0, 0, 0),
		layer = UI.Layer.Menu + 1,
	})
	shadow.TextTransparency = 0.55

	local fill = UI.label({
		parent = holder,
		name = "Relleno",
		text = Strings.get("menu.title"),
		size = UDim2.new(1, 0, 0, 58),
		font = Theme.FontBlack,
		textSize = UI.Type.hero,
		color = Theme.Brand.Cream,
		layer = UI.Layer.Menu + 2,
	})
	UI.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Theme.Brand.Cream),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Theme.Brand.Mustard),
		}),
		Rotation = 8,
		Parent = fill,
	})
	UI.new("UIStroke", {
		Color = Color3.fromRGB(18, 20, 26),
		Thickness = 2.5,
		Transparency = 0.25,
		Parent = fill,
	})

	UI.label({
		parent = holder,
		name = "Subtitulo",
		text = Strings.get("menu.subtitle"),
		size = UDim2.new(1, 0, 0, 20),
		position = UDim2.fromOffset(3, 62),
		font = Theme.Font,
		textSize = UI.Type.body,
		color = Theme.Surface.Muted,
		layer = UI.Layer.Menu + 1,
	})

	-- Una barra de acento debajo, que es lo que ata el titulo a la
	-- columna en vez de dejarlo flotando.
	UI.new("Frame", {
		Name = "Acento",
		Size = UDim2.fromOffset(64, 4),
		Position = UDim2.fromOffset(3, 88),
		BackgroundColor3 = Theme.Brand.Tomato,
		BorderSizePixel = 0,
		ZIndex = UI.Layer.Menu + 1,
		Parent = holder,
	}, { UI.new("UICorner", { CornerRadius = UDim.new(0, 2) }) })
end

local function menuButton(parent: Instance, order: number, key: string, descKey: string?,
	iconName: string, accent: Color3, callback: () -> ()): TextButton
	local button = UI.button({
		parent = parent,
		name = key,
		text = "",
		size = UDim2.new(1, 0, 0, descKey and 62 or 48),
		order = order,
		color = accent,
		radius = UI.Radius.md,
		layer = UI.Layer.Menu + 1,
		onClick = callback,
	})

	local instance = button.instance
	UI.icon(instance, iconName, 22, accent, UI.Layer.Menu + 2).Position =
		UDim2.new(0, 18, 0.5, -11)

	UI.label({
		parent = instance,
		name = "Nombre",
		text = Strings.get(key),
		size = UDim2.new(1, -76, 0, 22),
		position = UDim2.fromOffset(54, descKey and 12 or 13),
		font = Theme.FontBold,
		textSize = UI.Type.subtitle,
		color = Theme.Surface.Text,
		layer = UI.Layer.Menu + 2,
	})

	if descKey then
		UI.label({
			parent = instance,
			name = "Detalle",
			text = Strings.get(descKey),
			size = UDim2.new(1, -76, 0, 18),
			position = UDim2.fromOffset(54, 34),
			font = Theme.Font,
			textSize = UI.Type.small,
			color = Theme.Surface.Muted,
			layer = UI.Layer.Menu + 2,
		})
	end

	-- Un filete del color del acento en el borde izquierdo: da a cada
	-- entrada una identidad sin cargar un icono de color completo.
	UI.new("Frame", {
		Name = "Filete",
		Size = UDim2.new(0, 3, 0.55, 0),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = UI.Layer.Menu + 2,
		Parent = instance,
	}, { UI.new("UICorner", { CornerRadius = UDim.new(0, 2) }) })

	return instance
end

local function slider(parent: Instance, order: number, key: string, value: number,
	callback: (number) -> ())
	local holder = UI.new("Frame", {
		Name = key,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundTransparency = 1,
		ZIndex = UI.Layer.Menu + 1,
		Parent = parent,
	})

	local title = UI.label({
		parent = holder,
		name = "Nombre",
		size = UDim2.new(1, 0, 0, 18),
		font = Theme.FontBold,
		textSize = UI.Type.small,
		color = Theme.Surface.Text,
		layer = UI.Layer.Menu + 2,
	})

	local track: TextButton = UI.new("TextButton", {
		Name = "Barra",
		Text = "",
		Size = UDim2.new(1, 0, 0, 10),
		Position = UDim2.fromOffset(0, 30),
		BackgroundColor3 = Theme.Surface.Raised,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = UI.Layer.Menu + 2,
		Parent = holder,
	})
	UI.corner(track, 5)

	local fill = UI.new("Frame", {
		Name = "Relleno",
		Size = UDim2.fromScale(value, 1),
		BackgroundColor3 = Theme.Brand.Teal,
		BorderSizePixel = 0,
		ZIndex = UI.Layer.Menu + 3,
		Parent = track,
	})
	UI.corner(fill, 5)

	local knob = UI.new("Frame", {
		Name = "Perilla",
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.fromScale(value, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Brand.Cream,
		BorderSizePixel = 0,
		ZIndex = UI.Layer.Menu + 4,
		Parent = track,
	})
	UI.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })

	local function setFrom(x: number)
		local absolute = track.AbsolutePosition.X
		local width = math.max(1, track.AbsoluteSize.X)
		local alpha = math.clamp((x - absolute) / width, 0, 1)
		fill.Size = UDim2.fromScale(alpha, 1)
		knob.Position = UDim2.fromScale(alpha, 0.5)
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
	local frame: CanvasGroup = UI.new("CanvasGroup", {
		Name = name,
		Size = UDim2.new(1, 0, 1, -190),
		Position = UDim2.fromOffset(0, 168),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		ZIndex = UI.Layer.Menu + 1,
		Parent = column,
	})

	local top = 0
	if titleKey ~= "" then
		UI.label({
			parent = frame,
			name = "Encabezado",
			text = Strings.get(titleKey),
			size = UDim2.new(1, 0, 0, 26),
			font = Theme.FontBlack,
			textSize = UI.Type.title,
			color = Theme.Surface.Text,
			layer = UI.Layer.Menu + 2,
		})
		top = 40
	end

	local body = UI.new("Frame", {
		Name = "Cuerpo",
		Size = UDim2.new(1, 0, 1, -top),
		Position = UDim2.fromOffset(0, top),
		BackgroundTransparency = 1,
		ZIndex = UI.Layer.Menu + 1,
		Parent = frame,
	})
	UI.list(body, UI.Space.md)

	pages[name] = frame
	return body
end

--[[
	Transicion entre paginas: la que sale se desliza y se funde, la que
	entra llega desde el otro lado. Antes esto era `frame.Visible = id
	== name` para las tres a la vez.
--]]
local function goTo(name: string, instant: boolean?)
	local target = pages[name]
	if not target then
		return
	end
	local previous = pages[currentPage]
	currentPage = name

	if instant then
		for id, frame in pages do
			frame.Visible = id == name
			frame.GroupTransparency = id == name and 0 or 1
			frame.Position = UDim2.fromOffset(0, 168)
		end
		return
	end

	if previous and previous ~= target and previous.Visible then
		local out = TweenService:Create(previous, UI.Motion.exit, {
			GroupTransparency = 1,
			Position = UDim2.fromOffset(-26, 168),
		})
		out.Completed:Once(function()
			previous.Visible = false
		end)
		out:Play()
	end

	target.Position = UDim2.fromOffset(26, 168)
	target.GroupTransparency = 1
	target.Visible = true
	TweenService:Create(target, UI.Motion.base, {
		GroupTransparency = 0,
		Position = UDim2.fromOffset(0, 168),
	}):Play()
end

-- ── construccion ───────────────────────────────────────────────────

function MainMenu.mount(parent: ScreenGui)
	root = UI.new("Frame", {
		Name = "Menu",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = UI.Layer.Menu,
		Parent = parent,
	})

	-- Un velo suave sobre toda la escena: baja el contraste de la
	-- escuela para que el texto de la izquierda se lea, sin taparla.
	UI.new("Frame", {
		Name = "Velo",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Surface.Deep,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = UI.Layer.Menu,
		Parent = root,
	})

	-- La columna: opaca a la izquierda, transparente al llegar a la
	-- escuela. El degradado es lo que evita el corte duro.
	column = UI.new("Frame", {
		Name = "Columna",
		Size = UDim2.new(0, COLUMN, 1, 0),
		BackgroundColor3 = Theme.Surface.Deep,
		BorderSizePixel = 0,
		ZIndex = UI.Layer.Menu,
		Parent = root,
	})
	UI.new("UIGradient", {
		Rotation = 0,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.04),
			NumberSequenceKeypoint.new(0.62, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = column,
	})
	UI.new("UIPadding", {
		PaddingLeft = UDim.new(0, 44),
		PaddingRight = UDim.new(0, 74),
		Parent = column,
	})

	buildTitle(column)

	-- Inicio
	local home = page("inicio", "")
	menuButton(home, 1, "menu.play", "menu.public_desc", "tilde", Theme.Brand.Mint, function()
		modeChosen = true
		MainMenu.onPlay("publico")
		MainMenu.close()
	end)
	menuButton(home, 2, "menu.rooms", "menu.friends_desc", "radio", Theme.Brand.Teal, function()
		MainMenu.onRooms()
	end)
	menuButton(home, 3, "menu.shop", "menu.shop_desc", "moneda", Theme.Brand.Mustard, function()
		MainMenu.onShop()
	end)
	menuButton(home, 4, "menu.settings", "menu.settings_desc", "reloj", Theme.Brand.Grape, function()
		goTo("ajustes")
	end)
	menuButton(home, 5, "menu.credits", "menu.credits_desc", "libro", Theme.Brand.Tomato, function()
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
	menuButton(options, 4, "menu.music", nil, "campana", Theme.Brand.Mint, function()
		settings.musica = not settings.musica
		MainMenu.onMusic(settings.musica)
	end)
	menuButton(options, 5, "menu.back", nil, "prismaticos", Theme.Surface.Muted, function()
		goTo("inicio")
	end)

	-- Creditos
	local credits = page("creditos", "credits.title")
	UI.label({
		parent = credits,
		name = "Cuerpo",
		text = Strings.get("credits.body"),
		size = UDim2.new(1, 0, 0, 76),
		font = Theme.Font,
		textSize = UI.Type.body,
		color = Theme.Surface.Muted,
		wrapped = true,
		layer = UI.Layer.Menu + 2,
	}).TextYAlignment = Enum.TextYAlignment.Top
	UI.label({
		parent = credits,
		name = "Gracias",
		text = Strings.get("credits.thanks"),
		size = UDim2.new(1, 0, 0, 54),
		font = Theme.FontBold,
		textSize = UI.Type.body,
		color = Theme.Surface.Text,
		wrapped = true,
		layer = UI.Layer.Menu + 2,
	}).TextYAlignment = Enum.TextYAlignment.Top
	menuButton(credits, 3, "menu.back", nil, "prismaticos", Theme.Surface.Muted, function()
		goTo("inicio")
	end)

	goTo("inicio", true)

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
	if not root or root.Visible then
		return
	end
	goTo("inicio", true)
	root.Visible = true
	startCamera()
	setBlur(true)
	MainMenu.onVisible(true)

	-- La columna entra desde la izquierda y los botones en cascada.
	column.Position = UDim2.fromOffset(-40, 0)
	TweenService:Create(column, UI.Motion.base, { Position = UDim2.fromOffset(0, 0) }):Play()

	local home = pages.inicio
	if home then
		local body = home:FindFirstChild("Cuerpo")
		if body then
			local buttons: { GuiObject } = {}
			for _, child in body:GetChildren() do
				if child:IsA("GuiObject") then
					table.insert(buttons, child)
				end
			end
			table.sort(buttons, function(a: any, b: any)
				return a.LayoutOrder < b.LayoutOrder
			end)
			UI.stagger(buttons, 0.05)
		end
	end
end

--[[
	Cerrar el menu sin haber elegido modo cuenta como elegir el publico
	— es lo que hacia la version anterior, pero llamando al remote desde
	aca adentro. Ahora sale por `onPlay`, que es el unico camino: el
	cliente manda intenciones y el init es el que habla con el servidor.
--]]
function MainMenu.close()
	if not root or not root.Visible then
		return
	end
	root.Visible = false
	stopCamera()
	setBlur(false)
	MainMenu.onVisible(false)
	if not modeChosen then
		modeChosen = true
		MainMenu.onPlay("publico")
	end
end

function MainMenu.isOpen(): boolean
	return root ~= nil and root.Visible
end

function MainMenu.musicEnabled(): boolean
	return settings.musica
end

return MainMenu

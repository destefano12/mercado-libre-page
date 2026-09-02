--!strict
--[[
	UI
	------------------------------------------------------------------
	El sistema de diseno. Antes de este archivo, el helper `new` estaba
	copiado *literal* en nueve archivos de cliente y `corner` en cinco,
	no habia escala tipografica (catorce TextSize sueltos), no habia
	tokens de espaciado ni de radio, y en toda la interfaz habia cuatro
	tweens contados: el menu, la tienda y el lobby abrian con un
	`.Visible = true` pelado y ningun boton daba respuesta al hacer clic
	porque `AutoButtonColor` estaba en false en todos lados.

	Aca vive todo eso una sola vez:

	  tokens      Space / Radius / Type / Motion / Layer
	  primitivas  panel, label, button, ghost, textBox, scroller...
	  iconos      vectoriales, armados con Frames — no se sube nada
	  motion      show / hide animados, con CanvasGroup cuando se puede

	Sobre los iconos: Roblox no deja dibujar un poligono arbitrario en
	una GUI, asi que todo se compone de rectangulos y circulos
	(`UICorner` con radio gigante) mas rotacion. Un triangulo es un
	cuadrado rotado 45 grados dentro de un padre con ClipsDescendants.
	Es feo de escribir y queda perfecto en pantalla, que es lo que
	importa — y no pasa por moderacion de assets.
--]]

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent.Config)
local Theme = require(script.Parent.Theme)

local UI = {}

-- ── tokens ─────────────────────────────────────────────────────────

UI.Space = table.freeze({ xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32 })

UI.Radius = table.freeze({ sm = 6, md = 10, lg = 14, xl = 20, pill = 999 })

-- Escala tipografica real. Cada paso es perceptiblemente distinto del
-- anterior; con catorce tamanos sueltos ninguno lo era.
UI.Type = table.freeze({
	micro = 11,
	small = 12,
	body = 14,
	subtitle = 16,
	title = 20,
	display = 32,
	hero = 48,
})

--[[
	Capas con nombre. El bug que arreglan: la tienda vivia en ZIndex 12
	y el scrim del menu en 20, asi que abrir la tienda desde el menu la
	dibujaba *detras* del menu. Los modales tienen que estar por encima
	del menu, no por debajo.
--]]
UI.Layer = table.freeze({
	Hud = 10,
	Panel = 20,
	Tool = 40,
	Overlay = 60,
	Menu = 100,
	Modal = 200,
	Toast = 300,
	Fade = 400,
})

UI.Motion = table.freeze({
	snap = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	base = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	enter = TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	exit = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	slow = TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
})

-- Ancho de diseno de referencia: todas las medidas en pixeles de este
-- archivo estan pensadas para 1280x720 y se escalan desde ahi.
local DESIGN_WIDTH = 1280
local DESIGN_HEIGHT = 720

-- ── base ───────────────────────────────────────────────────────────

function UI.new(class: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(class)
	local parent: Instance? = nil
	if props then
		parent = props.Parent
		for key, value in props do
			if key ~= "Parent" then
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UI.corner(gui: GuiObject, radius: number): UICorner
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius), Parent = gui })
end

function UI.stroke(gui: GuiObject, color: Color3, thickness: number?, transparency: number?): UIStroke
	return UI.new("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = gui,
	})
end

function UI.padding(gui: GuiObject, all: number, horizontal: number?): UIPadding
	local h = horizontal or all
	return UI.new("UIPadding", {
		PaddingTop = UDim.new(0, all),
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, h),
		PaddingRight = UDim.new(0, h),
		Parent = gui,
	})
end

function UI.list(gui: GuiObject, padding: number, direction: Enum.FillDirection?): UIListLayout
	return UI.new("UIListLayout", {
		Padding = UDim.new(0, padding),
		FillDirection = direction or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = gui,
	})
end

--- Devuelve el UIScale del objeto, creandolo si no lo tiene.
function UI.scaler(gui: GuiObject): UIScale
	local existing = gui:FindFirstChildOfClass("UIScale")
	if existing then
		return existing
	end
	return UI.new("UIScale", { Parent = gui })
end

-- ── sonido ─────────────────────────────────────────────────────────

--[[
	Los clicks eran sonido *posicional* en el origen del mundo:
	`Util.playSound` los parentaba a `workspace` con
	RollOffMaxDistance 80, asi que el volumen del menu dependia de
	donde estuviera parado tu personaje. Parentado a SoundService es 2D
	y suena igual siempre.
--]]
function UI.sound(soundId: string, volume: number?, speed: number?)
	if soundId == "" then
		return
	end
	local sound = UI.new("Sound", {
		SoundId = soundId,
		Volume = volume or 0.3,
		PlaybackSpeed = speed or 1,
	})
	local group = SoundService:FindFirstChild("Master")
	if group and group:IsA("SoundGroup") then
		sound.SoundGroup = group
	end
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(6, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

function UI.click()
	UI.sound(Config.Sonidos.Click, 0.3, 1.1)
end

function UI.hover()
	UI.sound(Config.Sonidos.Click, 0.09, 1.9)
end

-- ── motion ─────────────────────────────────────────────────────────

--[[
	Apertura y cierre animados. Si la raiz es un CanvasGroup podemos
	fundir el subarbol entero con una sola propiedad
	(`GroupTransparency`); si no, animamos solo la escala. Los modales
	que llevan ViewportFrame adentro usan Frame comun a proposito: un
	ViewportFrame dentro de un CanvasGroup se rasteriza aparte y el
	resultado es impredecible entre versiones del motor.
--]]
function UI.show(gui: GuiObject, scaleFrom: number?)
	local scale = UI.scaler(gui)
	scale.Scale = scaleFrom or 0.92
	if gui:IsA("CanvasGroup") then
		gui.GroupTransparency = 1
	end
	gui.Visible = true
	TweenService:Create(scale, UI.Motion.enter, { Scale = 1 }):Play()
	if gui:IsA("CanvasGroup") then
		TweenService:Create(gui, UI.Motion.base, { GroupTransparency = 0 }):Play()
	end
end

function UI.hide(gui: GuiObject)
	if not gui.Visible then
		return
	end
	local scale = UI.scaler(gui)
	TweenService:Create(scale, UI.Motion.exit, { Scale = 0.95 }):Play()
	if gui:IsA("CanvasGroup") then
		local fade = TweenService:Create(gui, UI.Motion.exit, { GroupTransparency = 1 })
		fade.Completed:Once(function()
			gui.Visible = false
		end)
		fade:Play()
		return
	end
	task.delay(UI.Motion.exit.Time, function()
		gui.Visible = false
	end)
end

--- Entrada en cascada: cada hijo entra un pelin despues del anterior.
function UI.stagger(children: { GuiObject }, step: number?)
	local delay = step or 0.045
	for index, child in children do
		local scale = UI.scaler(child)
		scale.Scale = 0.9
		child.Visible = false
		task.delay(delay * (index - 1), function()
			if not child.Parent then
				return
			end
			child.Visible = true
			TweenService:Create(scale, UI.Motion.enter, { Scale = 1 }):Play()
		end)
	end
end

--[[
	Cuenta un numero hacia su valor nuevo en vez de saltar. Se usa en
	los creditos y en el marcador: ver "120 -> 165" subiendo comunica
	que algo pasó; el salto seco no.
--]]
function UI.countTo(label: TextLabel, from: number, to: number, seconds: number, format: (number) -> string)
	local elapsed = 0
	local duration = math.max(0.01, seconds)
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function(dt: number)
		if not label.Parent then
			if connection then
				connection:Disconnect()
			end
			return
		end
		elapsed += dt
		local alpha = math.clamp(elapsed / duration, 0, 1)
		-- Quint-out a mano: arranca rapido y frena.
		local eased = 1 - (1 - alpha) ^ 5
		label.Text = format(math.floor(from + (to - from) * eased + 0.5))
		if alpha >= 1 and connection then
			connection:Disconnect()
		end
	end)
end

-- ── primitivas ─────────────────────────────────────────────────────

export type PanelOptions = {
	parent: Instance,
	name: string,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	color: Color3?,
	transparency: number?,
	radius: number?,
	stroke: Color3?,
	layer: number?,
	canvas: boolean?,
}

function UI.panel(options: PanelOptions): GuiObject
	local frame = UI.new(options.canvas and "CanvasGroup" or "Frame", {
		Name = options.name,
		Size = options.size,
		Position = options.position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = options.anchor or Vector2.new(0.5, 0.5),
		BackgroundColor3 = options.color or Theme.Surface.Base,
		BackgroundTransparency = options.transparency or 0,
		BorderSizePixel = 0,
		ZIndex = options.layer or UI.Layer.Panel,
		Parent = options.parent,
	})
	UI.corner(frame, options.radius or UI.Radius.lg)
	UI.stroke(frame, options.stroke or Theme.Surface.Line, 1, 0.4)
	return frame
end

export type LabelOptions = {
	parent: Instance,
	name: string?,
	text: string?,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	font: Enum.Font?,
	textSize: number?,
	color: Color3?,
	align: Enum.TextXAlignment?,
	wrapped: boolean?,
	layer: number?,
}

function UI.label(options: LabelOptions): TextLabel
	return UI.new("TextLabel", {
		Name = options.name or "Label",
		Text = options.text or "",
		Size = options.size,
		Position = options.position or UDim2.fromOffset(0, 0),
		AnchorPoint = options.anchor or Vector2.new(0, 0),
		BackgroundTransparency = 1,
		Font = options.font or Theme.Font,
		TextSize = options.textSize or UI.Type.body,
		TextColor3 = options.color or Theme.Surface.Text,
		TextXAlignment = options.align or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = options.wrapped or false,
		ZIndex = options.layer or UI.Layer.Panel,
		Parent = options.parent,
	})
end

export type ButtonOptions = {
	parent: Instance,
	name: string?,
	text: string,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	color: Color3?,
	textColor: Color3?,
	font: Enum.Font?,
	textSize: number?,
	radius: number?,
	layer: number?,
	order: number?,
	ghost: boolean?,
	onClick: (() -> ())?,
}

export type Button = {
	instance: TextButton,
	setEnabled: (boolean) -> (),
	setText: (string) -> (),
}

--[[
	El boton con estados de verdad. Antes: `AutoButtonColor = false` y
	un cambio instantaneo de BackgroundColor3 al pasar el mouse, nada
	al presionar. Ahora hover, press y disabled, todos tweened, con
	sonido distinto en hover y en click.

	`ghost` es el idioma visual que ya usaba el proyecto en tres sitios
	distintos reimplementado a mano cada vez: fondo del color del
	acento casi transparente, texto y borde del mismo color.
--]]
function UI.button(options: ButtonOptions): Button
	local accent = options.color or Theme.Brand.Teal
	local ghost = options.ghost == true
	local baseColor = ghost and accent or Theme.Surface.Raised
	local baseTransparency = ghost and 0.86 or 0

	local button: TextButton = UI.new("TextButton", {
		Name = options.name or options.text,
		Text = options.text,
		Size = options.size,
		Position = options.position or UDim2.fromOffset(0, 0),
		AnchorPoint = options.anchor or Vector2.new(0, 0),
		LayoutOrder = options.order or 0,
		BackgroundColor3 = baseColor,
		BackgroundTransparency = baseTransparency,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Font = options.font or Theme.FontBold,
		TextSize = options.textSize or UI.Type.body,
		TextColor3 = options.textColor or (ghost and accent or Theme.Surface.Text),
		ZIndex = options.layer or UI.Layer.Panel,
		Parent = options.parent,
	})
	UI.corner(button, options.radius or UI.Radius.md)
	local stroke = UI.stroke(button, accent, 1, ghost and 0.5 or 0.72)
	local scale = UI.scaler(button)

	local enabled = true
	local pressed = false

	local function paint(target: Color3, transparency: number, strokeTransparency: number, scaleTo: number)
		TweenService:Create(button, UI.Motion.snap, {
			BackgroundColor3 = target,
			BackgroundTransparency = transparency,
		}):Play()
		TweenService:Create(stroke, UI.Motion.snap, { Transparency = strokeTransparency }):Play()
		TweenService:Create(scale, UI.Motion.snap, { Scale = scaleTo }):Play()
	end

	local function rest()
		paint(baseColor, baseTransparency, ghost and 0.5 or 0.72, 1)
	end

	button.MouseEnter:Connect(function()
		if not enabled then
			return
		end
		UI.hover()
		paint(ghost and accent or Theme.Surface.Hover, ghost and 0.74 or 0, 0.15, 1.03)
	end)

	button.MouseLeave:Connect(function()
		if not enabled then
			return
		end
		pressed = false
		rest()
	end)

	button.MouseButton1Down:Connect(function()
		if not enabled then
			return
		end
		pressed = true
		paint(ghost and accent or Theme.Surface.Hover, ghost and 0.66 or 0, 0.05, 0.97)
	end)

	button.MouseButton1Up:Connect(function()
		if not enabled or not pressed then
			return
		end
		pressed = false
		paint(ghost and accent or Theme.Surface.Hover, ghost and 0.74 or 0, 0.15, 1.03)
	end)

	button.MouseButton1Click:Connect(function()
		if not enabled then
			return
		end
		UI.click()
		if options.onClick then
			options.onClick()
		end
	end)

	local function setEnabled(value: boolean)
		enabled = value
		-- Active/Selectable, no AutoLocalize: esa propiedad controla la
		-- traduccion, no la interactividad.
		button.Active = value
		button.Selectable = value
		if value then
			button.TextColor3 = options.textColor or (ghost and accent or Theme.Surface.Text)
			rest()
		else
			button.TextColor3 = Theme.Surface.Faint
			paint(Theme.Surface.Raised, ghost and 0.94 or 0.4, 0.85, 1)
		end
	end

	local function setText(value: string)
		button.Text = value
	end

	return { instance = button, setEnabled = setEnabled, setText = setText }
end

function UI.closeButton(parent: Instance, layer: number, onClick: () -> ()): TextButton
	local button = UI.button({
		parent = parent,
		name = "Cerrar",
		text = "\u{00D7}",
		size = UDim2.fromOffset(30, 30),
		position = UDim2.new(1, -UI.Space.md, 0, UI.Space.md),
		anchor = Vector2.new(1, 0),
		color = Theme.Brand.Tomato,
		ghost = true,
		textSize = UI.Type.title,
		radius = UI.Radius.sm,
		layer = layer,
		onClick = onClick,
	})
	return button.instance
end

export type TextBoxOptions = {
	parent: Instance,
	name: string,
	placeholder: string,
	size: UDim2,
	position: UDim2?,
	layer: number?,
	order: number?,
}

function UI.textBox(options: TextBoxOptions): TextBox
	local box: TextBox = UI.new("TextBox", {
		Name = options.name,
		Text = "",
		PlaceholderText = options.placeholder,
		PlaceholderColor3 = Theme.Surface.Faint,
		Size = options.size,
		Position = options.position or UDim2.fromOffset(0, 0),
		LayoutOrder = options.order or 0,
		BackgroundColor3 = Theme.Surface.Raised,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Theme.Font,
		TextSize = UI.Type.body,
		TextColor3 = Theme.Surface.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = options.layer or UI.Layer.Panel,
		Parent = options.parent,
	})
	UI.corner(box, UI.Radius.sm)
	local stroke = UI.stroke(box, Theme.Surface.Line, 1, 0.5)
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, UI.Space.md), Parent = box })

	box.Focused:Connect(function()
		TweenService:Create(stroke, UI.Motion.snap, {
			Color = Theme.Brand.Teal,
			Transparency = 0.1,
		}):Play()
	end)
	box.FocusLost:Connect(function()
		TweenService:Create(stroke, UI.Motion.snap, {
			Color = Theme.Surface.Line,
			Transparency = 0.5,
		}):Play()
	end)
	return box
end

--- ScrollingFrame que se mide sola. Se acabo el CanvasSize a mano.
function UI.scroller(parent: Instance, size: UDim2, position: UDim2, layer: number, padding: number): ScrollingFrame
	local scroller: ScrollingFrame = UI.new("ScrollingFrame", {
		Name = "Lista",
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Surface.Line,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		ZIndex = layer,
		Parent = parent,
	})
	UI.list(scroller, padding)
	return scroller
end

function UI.divider(parent: Instance, layer: number, order: number?): Frame
	return UI.new("Frame", {
		Name = "Linea",
		Size = UDim2.new(1, 0, 0, 1),
		LayoutOrder = order or 0,
		BackgroundColor3 = Theme.Surface.Line,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		ZIndex = layer,
		Parent = parent,
	})
end

-- ── responsive ─────────────────────────────────────────────────────

--[[
	Toda la interfaz vieja estaba en pixeles fijos: el lobby mide
	720x470 y en un telefono se sale de la pantalla. Un UIScale en la
	raiz, derivado del viewport contra el tamano de diseno, arregla el
	caso entero sin tocar una sola medida de los paneles.
--]]
function UI.responsive(root: ScreenGui): UIScale
	local scale = UI.new("UIScale", { Parent = root })

	local function fit()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		local factor = math.min(viewport.X / DESIGN_WIDTH, viewport.Y / DESIGN_HEIGHT)
		scale.Scale = math.clamp(factor, 0.62, 1.15)
	end

	fit()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local fresh = workspace.CurrentCamera
		if fresh then
			fresh:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
			fit()
		end
	end)
	return scale
end

-- ── iconos ─────────────────────────────────────────────────────────

local function holder(parent: Instance, size: number, layer: number): Frame
	return UI.new("Frame", {
		Name = "Icono",
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = layer,
		Parent = parent,
	})
end

local function dot(parent: Instance, size: UDim2, position: UDim2, color: Color3, layer: number): Frame
	local frame: Frame = UI.new("Frame", {
		Size = size,
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = layer,
		Parent = parent,
	})
	UI.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = frame })
	return frame
end

local function bar(parent: Instance, size: UDim2, position: UDim2, color: Color3, rotation: number, layer: number): Frame
	local frame: Frame = UI.new("Frame", {
		Size = size,
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = rotation,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = layer,
		Parent = parent,
	})
	UI.new("UICorner", { CornerRadius = UDim.new(0, 2), Parent = frame })
	return frame
end

local function ring(parent: Instance, inset: number, color: Color3, thickness: number, layer: number): Frame
	local frame: Frame = UI.new("Frame", {
		Size = UDim2.new(1, -inset, 1, -inset),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = layer,
		Parent = parent,
	})
	UI.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = frame })
	UI.new("UIStroke", {
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = frame,
	})
	return frame
end

--[[
	Cada entrada dibuja un icono dentro de un cuadrado. Son todos
	rectangulos, circulos y rotaciones — ni un asset, ni una espera de
	moderacion, y escalan sin pixelarse.
--]]
local ICONS: { [string]: (Frame, Color3, number) -> () } = {
	reloj = function(root, color, layer)
		ring(root, 2, color, 1.6, layer)
		bar(root, UDim2.fromScale(0.08, 0.3), UDim2.fromScale(0.5, 0.36), color, 0, layer + 1)
		bar(root, UDim2.fromScale(0.28, 0.08), UDim2.fromScale(0.6, 0.5), color, 0, layer + 1)
	end,
	moneda = function(root, color, layer)
		dot(root, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), color, layer)
		ring(root, 7, Theme.Surface.Deep, 1.4, layer + 1)
	end,
	ojo = function(root, color, layer)
		local lens = UI.new("Frame", {
			Size = UDim2.fromScale(1, 0.62),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = layer,
			Parent = root,
		})
		UI.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = lens })
		UI.new("UIStroke", { Color = color, Thickness = 1.6, Parent = lens })
		dot(root, UDim2.fromScale(0.34, 0.34), UDim2.fromScale(0.5, 0.5), color, layer + 1)
	end,
	aerosol = function(root, color, layer)
		UI.new("Frame", {
			Size = UDim2.fromScale(0.5, 0.66),
			Position = UDim2.fromScale(0.42, 0.66),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = layer,
			Parent = root,
		}, { UI.new("UICorner", { CornerRadius = UDim.new(0, 3) }) })
		bar(root, UDim2.fromScale(0.26, 0.16), UDim2.fromScale(0.42, 0.2), color, 0, layer)
		dot(root, UDim2.fromScale(0.12, 0.12), UDim2.fromScale(0.78, 0.16), color, layer)
		dot(root, UDim2.fromScale(0.1, 0.1), UDim2.fromScale(0.9, 0.34), color, layer)
	end,
	libro = function(root, color, layer)
		UI.new("Frame", {
			Size = UDim2.fromScale(0.86, 0.7),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = layer,
			Parent = root,
		}, { UI.new("UICorner", { CornerRadius = UDim.new(0, 2) }) })
		bar(root, UDim2.fromScale(0.06, 0.7), UDim2.fromScale(0.5, 0.5), Theme.Surface.Deep, 0, layer + 1)
	end,
	radio = function(root, color, layer)
		UI.new("Frame", {
			Size = UDim2.fromScale(0.56, 0.66),
			Position = UDim2.fromScale(0.5, 0.68),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = layer,
			Parent = root,
		}, { UI.new("UICorner", { CornerRadius = UDim.new(0, 3) }) })
		bar(root, UDim2.fromScale(0.1, 0.36), UDim2.fromScale(0.66, 0.2), color, 12, layer)
	end,
	prismaticos = function(root, color, layer)
		ring(root, 12, color, 1.5, layer)
		local left = ring(root, 12, color, 1.5, layer)
		left.Position = UDim2.fromScale(0.28, 0.58)
		left.Size = UDim2.fromScale(0.46, 0.46)
		local right = ring(root, 12, color, 1.5, layer)
		right.Position = UDim2.fromScale(0.72, 0.58)
		right.Size = UDim2.fromScale(0.46, 0.46)
		bar(root, UDim2.fromScale(0.24, 0.1), UDim2.fromScale(0.5, 0.5), color, 0, layer)
	end,
	pelota = function(root, color, layer)
		ring(root, 2, color, 1.6, layer)
		bar(root, UDim2.fromScale(0.06, 0.92), UDim2.fromScale(0.5, 0.5), color, 0, layer)
		bar(root, UDim2.fromScale(0.92, 0.06), UDim2.fromScale(0.5, 0.5), color, 0, layer)
	end,
	cono = function(root, color, layer)
		-- Triangulo: un cuadrado rotado 45 grados, recortado por el padre.
		local clip = UI.new("Frame", {
			Size = UDim2.fromScale(1, 0.72),
			Position = UDim2.fromScale(0.5, 0.62),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = layer,
			Parent = root,
		})
		UI.new("Frame", {
			Size = UDim2.fromScale(0.78, 0.78),
			Position = UDim2.fromScale(0.5, 1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = 45,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = layer,
			Parent = clip,
		})
	end,
	campana = function(root, color, layer)
		UI.new("Frame", {
			Size = UDim2.fromScale(0.66, 0.6),
			Position = UDim2.fromScale(0.5, 0.46),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = layer,
			Parent = root,
		}, { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		bar(root, UDim2.fromScale(0.86, 0.1), UDim2.fromScale(0.5, 0.74), color, 0, layer)
		dot(root, UDim2.fromScale(0.16, 0.16), UDim2.fromScale(0.5, 0.9), color, layer)
	end,
	candado = function(root, color, layer)
		ring(root, 16, color, 1.6, layer).Position = UDim2.fromScale(0.5, 0.3)
		UI.new("Frame", {
			Size = UDim2.fromScale(0.8, 0.5),
			Position = UDim2.fromScale(0.5, 0.7),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = layer + 1,
			Parent = root,
		}, { UI.new("UICorner", { CornerRadius = UDim.new(0, 3) }) })
	end,
	alerta = function(root, color, layer)
		local clip = UI.new("Frame", {
			Size = UDim2.fromScale(1, 0.78),
			Position = UDim2.fromScale(0.5, 0.6),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = layer,
			Parent = root,
		})
		UI.new("Frame", {
			Size = UDim2.fromScale(0.76, 0.76),
			Position = UDim2.fromScale(0.5, 1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = 45,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = layer,
			Parent = clip,
		})
		bar(root, UDim2.fromScale(0.08, 0.26), UDim2.fromScale(0.5, 0.6), Theme.Surface.Deep, 0, layer + 2)
		dot(root, UDim2.fromScale(0.1, 0.1), UDim2.fromScale(0.5, 0.82), Theme.Surface.Deep, layer + 2)
	end,
	tilde = function(root, color, layer)
		bar(root, UDim2.fromScale(0.1, 0.4), UDim2.fromScale(0.36, 0.62), color, -45, layer)
		bar(root, UDim2.fromScale(0.1, 0.78), UDim2.fromScale(0.6, 0.44), color, 45, layer)
	end,

	--[[
		Los seis de abajo son los glifos de las pestanas del carnet. En
		el trailer son siluetas negras chiquitas sobre la lengueta de
		color, asi que se dibujan al mismo tamano y con la misma idea:
		una forma reconocible de un vistazo, sin detalle interno.
	--]]
	lapiz = function(root, color, layer)
		bar(root, UDim2.fromScale(0.24, 0.9), UDim2.fromScale(0.5, 0.5), color, 42, layer)
		-- La punta: un cuadrado girado que sobresale del cuerpo.
		bar(root, UDim2.fromScale(0.2, 0.2), UDim2.fromScale(0.78, 0.24), color, 45, layer + 1)
	end,
	pelo = function(root, color, layer)
		-- Media luna de pelo apoyada sobre una cara vacia.
		local clip = UI.new("Frame", {
			Size = UDim2.fromScale(0.9, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = layer,
			Parent = root,
		})
		UI.new("Frame", {
			Size = UDim2.fromScale(1, 2),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = layer,
			Parent = clip,
		}, { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		for _, side in { -1, 1 } do
			bar(root, UDim2.fromScale(0.16, 0.44), UDim2.fromScale(0.5 + side * 0.34, 0.6),
				color, 0, layer)
		end
	end,
	gorra = function(root, color, layer)
		local clip = UI.new("Frame", {
			Size = UDim2.fromScale(0.72, 0.4),
			Position = UDim2.fromScale(0.5, 0.42),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = layer,
			Parent = root,
		})
		UI.new("Frame", {
			Size = UDim2.fromScale(1, 2),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = layer,
			Parent = clip,
		}, { UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		bar(root, UDim2.fromScale(0.94, 0.12), UDim2.fromScale(0.44, 0.64), color, 0, layer)
	end,
	anteojos = function(root, color, layer)
		for _, side in { -1, 1 } do
			local lens = ring(root, 10, color, 1.5, layer)
			lens.Position = UDim2.fromScale(0.5 + side * 0.27, 0.5)
			lens.Size = UDim2.fromScale(0.44, 0.44)
		end
		bar(root, UDim2.fromScale(0.16, 0.08), UDim2.fromScale(0.5, 0.5), color, 0, layer)
	end,
	campera = function(root, color, layer)
		UI.new("Frame", {
			Size = UDim2.fromScale(0.56, 0.68),
			Position = UDim2.fromScale(0.5, 0.56),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = layer,
			Parent = root,
		}, { UI.new("UICorner", { CornerRadius = UDim.new(0, 3) }) })
		for _, side in { -1, 1 } do
			bar(root, UDim2.fromScale(0.18, 0.5), UDim2.fromScale(0.5 + side * 0.36, 0.5),
				color, side * 8, layer)
		end
		bar(root, UDim2.fromScale(0.34, 0.16), UDim2.fromScale(0.5, 0.26), color, 0, layer + 1)
	end,
	flecha = function(root, color, layer)
		-- Triangulo apuntando a la derecha: el "pasar de pagina".
		local clip = UI.new("Frame", {
			Size = UDim2.fromScale(0.58, 1),
			Position = UDim2.fromScale(0.42, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ZIndex = layer,
			Parent = root,
		})
		UI.new("Frame", {
			Size = UDim2.fromScale(1.1, 1.1),
			Position = UDim2.fromScale(0, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = 45,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = layer,
			Parent = clip,
		})
	end,
}

--[[
	Devuelve un icono vectorial. Si el nombre no existe cae en un punto
	neutro en vez de romper: un icono faltante no deberia tirar abajo
	un panel entero.
--]]
function UI.icon(parent: Instance, name: string, size: number, color: Color3, layer: number?): Frame
	local depth = layer or UI.Layer.Panel
	local root = holder(parent, size, depth)
	local draw = ICONS[name]
	if draw then
		draw(root, color, depth)
	else
		dot(root, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.5, 0.5), color, depth)
	end
	return root
end

function UI.iconNames(): { string }
	local names = {}
	for name in ICONS do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

return UI

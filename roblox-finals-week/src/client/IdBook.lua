--!strict
--[[
	IdBook — el carnet de estudiante
	------------------------------------------------------------------
	Reemplaza a `ShopUI`, que era un panel oscuro de tienda con dos
	pestanas de texto y tarjetas en fila. Funcionaba, pero no se parecia
	a nada de lo que hay en el juego de referencia.

	En el trailer la cosmetica no se compra en un panel: se abre una
	libreta. Pagina izquierda, la credencial — nombre escrito a mano,
	foto tuya, codigo de barras y `STUDENT ID` girado en el canto.
	Pagina derecha, una grilla de 4x5 con lo que hay en esa categoria y
	un contador de paginas abajo. Del canto derecho asoman lenguetas de
	colores, una por categoria, y la elegida se corre hacia afuera.

	Todas las medidas y todos los colores salen de los fotogramas
	`f029` y `f030`, muestreados pixel a pixel; los colores viven en
	`Config.Carnet` para que se toquen sin abrir este archivo.

	Lo que cambia respecto de la version anterior, aparte del aspecto:

	- Las trece miniaturas giraban todas a la vez en un RenderStepped.
	  En la referencia las casillas estan quietas: ahora gira solo la
	  que senala el cursor, que ademas es como se lee cual esta por
	  elegirse.
	- La grilla pagina de verdad. Con seis peinados, tres gorros y
	  cinco objetos de trampa, una lista sola dejo de alcanzar.
	- La foto es un clon del personaje del jugador, con los brazos
	  arriba como en la foto del carnet del trailer.

	Quien decide sigue siendo el servidor: esto manda "quiero esto" y
	dibuja lo que vuelve.
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Strings = require(Shared:WaitForChild("Strings"))
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local UI = require(Shared:WaitForChild("UI"))
local Previews = require(Shared:WaitForChild("Previews"))

local IdBook = {}

local player = Players.LocalPlayer
local C = Config.Carnet

-- ── medidas ────────────────────────────────────────────────────────
-- Todo en pixeles de diseno de 1280x720; `UI.responsive` los escala.

local PAGE_H = 400
local LEFT_W, RIGHT_W, SPINE_W = 290, 300, 10
local TAB_W, TAB_H, TAB_GAP = 46, 46, 8
local SLOT, SLOT_GAP = 52, 10
local MARGIN = 18

local COLS, ROWS = C.Columnas, C.Filas
local PER_PAGE = COLS * ROWS
local GRID_W = COLS * SLOT + (COLS - 1) * SLOT_GAP
local GRID_H = ROWS * SLOT + (ROWS - 1) * SLOT_GAP

local ROOT_W = MARGIN + LEFT_W + SPINE_W + RIGHT_W + TAB_W + MARGIN
local ROOT_H = MARGIN * 2 + PAGE_H

--[[
	Las capas. Con `ZIndexBehavior.Sibling` (lo que pone
	`init.client.lua`) el ZIndex solo ordena entre hermanos, y los hijos
	van siempre encima de su padre, con su propio ZIndex o sin el. Asi
	que alcanza con ordenar los cuatro hijos directos de la raiz y cada
	subarbol viaja con su padre.

	Las lenguetas van ENCIMA de las paginas: en reposo arrancan justo en
	el canto derecho del papel, y la elegida se corre hacia la izquierda
	montandose sobre la hoja. Es lo que en el video hace que se vea cual
	esta abierta.
--]]
local Z_SPINE, Z_PAGE, Z_TABS, Z_CHROME = 1, 2, 3, 4

-- ── estado ─────────────────────────────────────────────────────────

local root: Frame
local rightPage: Frame
local portrait: ViewportFrame
local portraitCamera: Camera
local titleLabel: TextLabel
local hintLabel: TextLabel
local counterLabel: TextLabel
local creditLabel: TextLabel
local gridHolder: Frame
local nextArrow: Frame

type Tab = { button: TextButton, color: Color3 }
local tabs: { [string]: Tab } = {}

local currentTab: string = C.Pestanas[1].categoria
local currentPage = 1

local wallet: any = { creditos = 0, comprados = {}, estetica = {}, objeto = "nota" }

-- Solo gira la miniatura que el cursor esta senalando.
local hovered: Model? = nil
local spinLoop: RBXScriptConnection? = nil

IdBook.onNotify = function(_packet: any) end

-- ── datos ──────────────────────────────────────────────────────────

local function entriesFor(category: string): { any }
	local list = {}
	for _, entry in Config.Economia.Tienda do
		if entry.categoria == category then
			table.insert(list, entry)
		end
	end
	return list
end

local function pageCount(category: string): number
	return math.max(1, math.ceil(#entriesFor(category) / PER_PAGE))
end

--[[
	Por que esta prenda esta bloqueada, o `nil` si esta disponible.

	Es la misma cuenta que hace `ShopService.missingRequirement`,
	repetida aca para poder avisar ANTES del clic. Si las dos difirieran
	manda el servidor y el jugador ve un rechazo: molesto, pero no
	explotable.
--]]
local function lockOf(entry: any): any?
	if wallet.comprados and wallet.comprados[entry.id] then
		return nil
	end
	local needs = entry.requiere
	if not needs then
		return nil
	end
	if needs.semanas and (wallet.semanas or 0) < needs.semanas then
		return { key = "shop.need_weeks", args = { n = needs.semanas } }
	end
	if needs.promedio and (wallet.mejorPromedio or 0) < needs.promedio then
		return { key = "shop.need_grade", args = { n = needs.promedio } }
	end
	return nil
end

local function isEquipped(entry: any): boolean
	if entry.tipo == "objeto" then
		return wallet.objeto == entry.id
	end
	return wallet.estetica ~= nil and wallet.estetica[entry.id] == true
end

-- ── giro de la miniatura senalada ───────────────────────────────────

local function startSpin()
	if spinLoop then
		return
	end
	local angle = 0
	spinLoop = RunService.RenderStepped:Connect(function(dt: number)
		local model = hovered
		if not model or not model.Parent then
			return
		end
		angle += dt * 1.2
		model:PivotTo(CFrame.Angles(math.sin(angle * 0.6) * 0.14, angle, 0))
	end)
end

local function stopSpin()
	if spinLoop then
		spinLoop:Disconnect()
		spinLoop = nil
	end
	hovered = nil
end

-- ── piezas de la credencial ────────────────────────────────────────

--[[
	El codigo de barras.

	Sale de `Random.new(UserId)`: el mismo jugador tiene siempre el
	mismo carnet, en todas las partidas y sin guardar nada. Es el mismo
	truco que usa `CharacterService.skinFor` para la piel.
--]]
local function barcode(parent: Instance, width: number, height: number, position: UDim2)
	local strip = UI.new("Frame", {
		Name = "Codigo",
		Size = UDim2.fromOffset(width, height),
		Position = position,
		BackgroundTransparency = 1,
		Parent = parent,
	})

	local rng = Random.new(player.UserId)
	local x = 0
	while x < width - 2 do
		local barWidth = rng:NextInteger(1, 4)
		if x + barWidth > width then
			break
		end
		UI.new("Frame", {
			Size = UDim2.fromOffset(barWidth, height),
			Position = UDim2.fromOffset(x, 0),
			BackgroundColor3 = C.Tinta,
			BorderSizePixel = 0,
			Parent = strip,
		})
		x += barWidth + rng:NextInteger(1, 3)
	end
end

--[[
	La foto del carnet.

	Es un clon del personaje real dentro de un ViewportFrame. Tres
	cosas que hay que hacer si o si:

	  * `Archivable = true` — los personajes de jugador vienen con el
	    clonado desactivado y `:Clone()` devolveria nil;
	  * sacarle el Humanoid y los BillboardGui — el cartel del nombre
	    flotando dentro de la foto se ve pesimo;
	  * `PivotTo(CFrame.new())` para normalizar la pose, porque el
	    personaje puede estar mirando a cualquier lado cuando se abre
	    el carnet.

	Los brazos se levantan girandolos sobre su hombro: es la pose de la
	foto del trailer, y ademas tapa que el clon esta congelado.
--]]
local function raiseArms(model: Model)
	local torso = model:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then
		return
	end
	for _, entry in { { name = "Right Arm", side = 1 }, { name = "Left Arm", side = -1 } } do
		local arm = model:FindFirstChild(entry.name)
		if arm and arm:IsA("BasePart") then
			local shoulder = torso.CFrame
				* CFrame.new(entry.side * (torso.Size.X + arm.Size.X) / 2, torso.Size.Y / 2, 0)
			arm.CFrame = shoulder
				* CFrame.Angles(0, 0, entry.side * 2.2)
				* CFrame.new(0, -arm.Size.Y / 2, 0)
		end
	end
end

local function refreshPortrait()
	if not portrait then
		return
	end
	for _, child in portrait:GetChildren() do
		if child:IsA("Model") then
			child:Destroy()
		end
	end

	local character = player.Character
	if not character then
		return
	end

	local ok, clone = pcall(function(): Model
		character.Archivable = true
		return character:Clone()
	end)
	if not ok or not clone then
		return
	end

	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("Humanoid") or descendant:IsA("BillboardGui")
			or descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end

	clone:PivotTo(CFrame.new())
	raiseArms(clone)
	clone.Parent = portrait

	--[[
		El rig mira a -Z, asi que la camara se planta de ese lado. Y se
		planta LEJOS: con los brazos arriba el personaje mide unos cinco
		studs de ancho, y a la distancia con la que se encuadra una
		cabeza sola las manos quedaban fuera del recorte.

		El foco es fijo, no la posicion de la cabeza: despues del
		`PivotTo` la raiz esta en el origen y el pecho cae siempre a la
		misma altura, sea cual sea la pose con la que se abrio el
		carnet.
	--]]
	local focus = Vector3.new(0, 1.1, 0)
	portraitCamera.CFrame = CFrame.lookAt(focus + Vector3.new(0, 0, -9), focus)
end

-- ── casillas de la grilla ──────────────────────────────────────────

--[[
	Las cuatro esquinas rojas de lo que esta puesto.

	En el video la seleccion no es un borde entero: son cuatro angulos
	discontinuos en las esquinas de la casilla, que dejan ver el fondo
	entre medio. Un `UIStroke` daria un marco cerrado y se veria como
	otra cosa.
--]]
local function selectionCorners(parent: Instance)
	local arm, thick, inset = 15, 3, -2
	for _, corner in {
		{ x = 0, y = 0, dx = 1, dy = 1 },
		{ x = 1, y = 0, dx = -1, dy = 1 },
		{ x = 0, y = 1, dx = 1, dy = -1 },
		{ x = 1, y = 1, dx = -1, dy = -1 },
	} do
		for _, leg in {
			{ w = arm, h = thick },
			{ w = thick, h = arm },
		} do
			UI.new("Frame", {
				Name = "Esquina",
				Size = UDim2.fromOffset(leg.w, leg.h),
				Position = UDim2.new(
					corner.x, corner.dx > 0 and inset or -(leg.w + inset),
					corner.y, corner.dy > 0 and inset or -(leg.h + inset)
				),
				BackgroundColor3 = C.Seleccion,
				BorderSizePixel = 0,
				Parent = parent,
			}, { UI.new("UICorner", { CornerRadius = UDim.new(0, 1) }) })
		end
	end
end

local function slotPreview(parent: Instance, id: string): Model?
	local model = Previews.build(id)
	if not model then
		UI.icon(parent, "moneda", 22, C.Tinta).Position = UDim2.new(0.5, -11, 0.5, -11)
		return nil
	end

	local viewport: ViewportFrame = UI.new("ViewportFrame", {
		Name = "Vista",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(196, 190, 182),
		LightColor = Color3.fromRGB(255, 252, 244),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
		Parent = parent,
	})
	local camera = UI.new("Camera", {
		CFrame = CFrame.lookAt(Vector3.new(0, 0.5, 4.6), Vector3.new(0, 0.15, 0)),
		FieldOfView = 44,
		Parent = viewport,
	})
	viewport.CurrentCamera = camera
	model.Parent = viewport
	return model
end

local function buildSlot(entry: any, index: number)
	local column = (index - 1) % COLS
	local rowIndex = math.floor((index - 1) / COLS)

	local owned = wallet.comprados ~= nil and wallet.comprados[entry.id] == true
	local locked = lockOf(entry)
	local credits = wallet.creditos or 0
	local affordable = owned or (credits >= entry.precio and not locked)
	local equipped = owned and isEquipped(entry)

	local cell = UI.new("TextButton", {
		Name = entry.id,
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(SLOT, SLOT),
		Position = UDim2.fromOffset(
			column * (SLOT + SLOT_GAP),
			rowIndex * (SLOT + SLOT_GAP)
		),
		BackgroundColor3 = C.Casilla,
		BackgroundTransparency = affordable and 0 or 0.45,
		BorderSizePixel = 0,
		Parent = gridHolder,
	})
	UI.corner(cell, 14)

	local model = slotPreview(cell, entry.id)

	if equipped then
		selectionCorners(cell)
	end

	if locked then
		UI.icon(cell, "candado", 18, C.Tinta).Position = UDim2.new(0.5, -9, 0.5, -9)
	elseif not owned then
		-- El precio va DENTRO de la casilla, chiquito y abajo: es la
		-- unica forma de que la grilla siga leyendose como grilla y no
		-- como una lista de precios.
		UI.label({
			parent = cell,
			name = "Precio",
			text = entry.precio > 0 and tostring(entry.precio)
				or Strings.get("carnet.free"),
			size = UDim2.new(1, 0, 0, 13),
			position = UDim2.new(0, 0, 1, -15),
			font = Theme.FontBold,
			textSize = UI.Type.micro,
			color = affordable and C.Tinta or C.Seleccion,
			align = Enum.TextXAlignment.Center,
		})
	end

	--[[
		Al pasar por encima: el nombre en el pie de la pagina y, si esta
		bloqueada, POR QUE. Un candado sin explicacion es peor que
		ningun candado.
	--]]
	cell.MouseEnter:Connect(function()
		hovered = model
		hintLabel.Text = locked and Strings.render(locked)
			or Strings.get("item." .. entry.id)
		hintLabel.TextColor3 = locked and C.Seleccion or C.Tinta
		UI.hover()
	end)
	cell.MouseLeave:Connect(function()
		if hovered == model then
			hovered = nil
			if model then
				model:PivotTo(CFrame.new())
			end
		end
		hintLabel.Text = ""
	end)

	if locked or (not owned and not affordable) then
		cell.Active = false
		cell.Selectable = false
		return
	end

	local pending = false
	cell.Activated:Connect(function()
		if pending then
			return
		end
		pending = true
		UI.click()
		task.spawn(function()
			local remote = owned and Net.func(Net.Functions.Equip) or Net.func(Net.Functions.Buy)
			local ok, result = pcall(function()
				return remote:InvokeServer(entry.id)
			end)
			pending = false
			if not ok or not result then
				return
			end
			if result.reason then
				IdBook.onNotify(result.reason)
			end
			if result.ok and cell.Parent then
				-- La grilla se rehace sola cuando llega la billetera
				-- nueva, pero el servidor puede tardar y el silencio se
				-- lee como que el clic no entro.
				TweenService:Create(cell, UI.Motion.snap, {
					BackgroundColor3 = C.Seleccion,
				}):Play()
				task.delay(0.16, function()
					if cell.Parent then
						TweenService:Create(cell, UI.Motion.base, {
							BackgroundColor3 = C.Casilla,
						}):Play()
					end
				end)
			end
		end)
	end)
end

local function rebuildGrid()
	if not gridHolder then
		return
	end
	hovered = nil
	gridHolder:ClearAllChildren()

	local list = entriesFor(currentTab)
	local total = pageCount(currentTab)
	currentPage = math.clamp(currentPage, 1, total)

	local first = (currentPage - 1) * PER_PAGE
	for offset = 1, PER_PAGE do
		local entry = list[first + offset]
		if entry then
			buildSlot(entry, offset)
		end
	end

	titleLabel.Text = string.upper(Strings.get("carnet.tab_" .. currentTab))
	counterLabel.Text = Strings.get("carnet.page", { a = currentPage, b = total })
	nextArrow.Visible = total > 1
	hintLabel.Text = ""
	creditLabel.Text = Strings.get("shop.price", { n = wallet.creditos or 0 })
end

-- ── lenguetas ──────────────────────────────────────────────────────

local function selectTab(category: string)
	if currentTab ~= category then
		currentPage = 1
	end
	currentTab = category

	for id, tab in tabs do
		local on = id == category
		-- La elegida se corre hacia afuera y se aclara. El trozo que
		-- sobresale hacia la pagina queda tapado por el papel, que es
		-- exactamente lo que se ve en el trailer.
		TweenService:Create(tab.button, UI.Motion.base, {
			Position = UDim2.fromOffset(
				on and -14 or 0,
				tab.button.Position.Y.Offset
			),
			BackgroundColor3 = on and tab.color:Lerp(Color3.new(1, 1, 1), 0.3) or tab.color,
		}):Play()
	end

	rebuildGrid()
end

-- ── construccion ───────────────────────────────────────────────────

local function buildLeftPage(parent: Instance)
	local page = UI.new("Frame", {
		Name = "PaginaIzquierda",
		Size = UDim2.fromOffset(LEFT_W, PAGE_H),
		Position = UDim2.fromOffset(MARGIN, MARGIN),
		BackgroundColor3 = C.Papel,
		BorderSizePixel = 0,
		ZIndex = Z_PAGE,
		Parent = parent,
	})
	UI.corner(page, UI.Radius.lg)

	-- La sombra del lomo: el degradado que hace que la pagina se lea
	-- curvandose hacia adentro en vez de plana.
	UI.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.82, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, C.PapelSombra),
		}),
		Parent = page,
	})

	-- La cinta lila del marcapaginas.
	UI.new("Frame", {
		Name = "Cinta",
		Size = UDim2.fromOffset(26, PAGE_H),
		Position = UDim2.fromOffset(44, 0),
		BackgroundColor3 = C.Cinta,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Parent = page,
	})

	-- ── la credencial ──
	local card = UI.new("Frame", {
		Name = "Credencial",
		Size = UDim2.fromOffset(200, 300),
		Position = UDim2.fromOffset(74, 40),
		BackgroundColor3 = C.Credencial,
		BorderSizePixel = 0,
		Parent = page,
	})
	UI.corner(card, UI.Radius.md)

	local inner = UI.new("Frame", {
		Name = "Interior",
		Size = UDim2.fromOffset(168, 284),
		Position = UDim2.fromOffset(8, 8),
		BackgroundColor3 = C.CredencialFondo,
		BorderSizePixel = 0,
		Parent = card,
	})
	UI.corner(inner, UI.Radius.sm)

	-- "STUDENT ID" girado 90 grados sobre el canto carmesi.
	UI.label({
		parent = card,
		name = "Titulo",
		text = string.upper(Strings.get("carnet.student_id")),
		size = UDim2.fromOffset(284, 24),
		position = UDim2.fromOffset(188, 150),
		anchor = Vector2.new(0.5, 0.5),
		font = Theme.FontBlack,
		textSize = UI.Type.subtitle,
		color = Color3.fromRGB(252, 246, 244),
		align = Enum.TextXAlignment.Center,
	}).Rotation = 90

	UI.label({
		parent = inner,
		name = "Nombre",
		text = player.DisplayName,
		size = UDim2.fromOffset(136, 22),
		position = UDim2.fromOffset(16, 12),
		font = Theme.FontHand,
		textSize = UI.Type.subtitle,
		color = C.Tinta,
	})
	UI.new("Frame", {
		Name = "Renglon",
		Size = UDim2.fromOffset(136, 2),
		Position = UDim2.fromOffset(16, 34),
		BackgroundColor3 = C.Tinta,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Parent = inner,
	})

	local frame = UI.new("Frame", {
		Name = "Foto",
		Size = UDim2.fromOffset(136, 160),
		Position = UDim2.fromOffset(16, 46),
		BackgroundColor3 = Color3.fromRGB(226, 240, 244),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = inner,
	})
	UI.corner(frame, UI.Radius.sm)

	portrait = UI.new("ViewportFrame", {
		Name = "Retrato",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(190, 196, 206),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.3, -1, -0.5),
		Parent = frame,
	})
	portraitCamera = UI.new("Camera", { FieldOfView = 40, Parent = portrait })
	portrait.CurrentCamera = portraitCamera

	barcode(inner, 136, 34, UDim2.fromOffset(16, 220))

	UI.icon(page, "moneda", 16, Theme.Hud.Credit).Position = UDim2.fromOffset(74, 352)
	creditLabel = UI.label({
		parent = page,
		name = "Creditos",
		text = "0 cr",
		size = UDim2.fromOffset(170, 18),
		position = UDim2.fromOffset(96, 351),
		font = Theme.FontBold,
		textSize = UI.Type.small,
		color = C.Tinta,
	})

	-- El remache de abajo a la izquierda. En el video son dos botones
	-- metalicos que sujetan las tapas; el de la derecha ademas pasa de
	-- pagina, este es solo adorno.
	UI.new("Frame", {
		Name = "Remache",
		Size = UDim2.fromOffset(22, 22),
		Position = UDim2.fromOffset(22, 356),
		BackgroundColor3 = C.Remache,
		BorderSizePixel = 0,
		Parent = page,
	}, { UI.new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
end

local function buildRightPage(parent: Instance)
	local left = MARGIN + LEFT_W + SPINE_W

	rightPage = UI.new("Frame", {
		Name = "PaginaDerecha",
		Size = UDim2.fromOffset(RIGHT_W, PAGE_H),
		Position = UDim2.fromOffset(left, MARGIN),
		BackgroundColor3 = C.Papel,
		BorderSizePixel = 0,
		ZIndex = Z_PAGE,
		Parent = parent,
	})
	UI.corner(rightPage, UI.Radius.lg)

	UI.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C.PapelSombra),
			ColorSequenceKeypoint.new(0.18, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
		}),
		Parent = rightPage,
	})

	titleLabel = UI.label({
		parent = rightPage,
		name = "Categoria",
		text = "",
		size = UDim2.fromOffset(RIGHT_W - 40, 24),
		position = UDim2.fromOffset(20, 16),
		font = Theme.FontBlack,
		textSize = UI.Type.subtitle,
		color = C.Tinta,
		align = Enum.TextXAlignment.Right,
	})

	gridHolder = UI.new("Frame", {
		Name = "Grilla",
		Size = UDim2.fromOffset(GRID_W, GRID_H),
		Position = UDim2.fromOffset((RIGHT_W - GRID_W) / 2, 48),
		BackgroundTransparency = 1,
		Parent = rightPage,
	})

	hintLabel = UI.label({
		parent = rightPage,
		name = "Detalle",
		text = "",
		size = UDim2.fromOffset(RIGHT_W - 40, 18),
		position = UDim2.fromOffset(20, PAGE_H - 48),
		font = Theme.Font,
		textSize = UI.Type.small,
		color = C.Tinta,
		align = Enum.TextXAlignment.Center,
	})

	counterLabel = UI.label({
		parent = rightPage,
		name = "Paginas",
		text = "1/1",
		size = UDim2.fromOffset(80, 18),
		position = UDim2.fromOffset(RIGHT_W / 2 - 46, PAGE_H - 26),
		font = Theme.FontBold,
		textSize = UI.Type.small,
		color = C.Tinta,
		align = Enum.TextXAlignment.Center,
	})

	nextArrow = UI.icon(rightPage, "flecha", 12, C.Cinta)
	nextArrow.Position = UDim2.fromOffset(RIGHT_W / 2 + 38, PAGE_H - 23)
	nextArrow.Visible = false

	--[[
		El remache de la derecha pasa de pagina. En el trailer lleva un
		chevron adentro y esta en la esquina, justo donde uno apoyaria
		el pulgar para dar vuelta la hoja.
	--]]
	local turn = UI.new("TextButton", {
		Name = "Pasar",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.fromOffset(RIGHT_W - 46, PAGE_H - 34),
		BackgroundColor3 = C.Remache,
		BorderSizePixel = 0,
		Parent = rightPage,
	}, { UI.new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	UI.icon(turn, "flecha", 11, Color3.fromRGB(226, 222, 216)).Position =
		UDim2.fromOffset(8, 7)

	turn.Activated:Connect(function()
		local total = pageCount(currentTab)
		currentPage = currentPage % total + 1
		UI.click()
		rebuildGrid()
	end)
end

local function buildTabs(parent: Instance)
	-- Arrancan pegadas al canto derecho de la pagina; la elegida se
	-- monta sobre ella.
	local left = MARGIN + LEFT_W + SPINE_W + RIGHT_W
	local top = MARGIN + 34

	for index, tab in C.Pestanas do
		--[[
			El marco lleva la posicion fija de la lengueta y el boton se
			mueve DENTRO de el. Asi el tween de seleccion toca una sola
			coordenada — la horizontal — y no hay que recalcular la
			vertical, que depende del indice, en cada cambio de pestana.
		--]]
		local holder = UI.new("Frame", {
			Name = tab.categoria .. "Marco",
			Size = UDim2.fromOffset(TAB_W + 14, TAB_H),
			Position = UDim2.fromOffset(left, top + (index - 1) * (TAB_H + TAB_GAP)),
			BackgroundTransparency = 1,
			ZIndex = Z_TABS,
			Parent = parent,
		})

		local button = UI.new("TextButton", {
			Name = tab.categoria,
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromOffset(0, 0),
			BackgroundColor3 = tab.color,
			BorderSizePixel = 0,
			Parent = holder,
		})
		UI.corner(button, UI.Radius.sm)

		UI.icon(button, tab.icono, 20, Color3.fromRGB(28, 26, 32)).Position =
			UDim2.fromOffset((TAB_W + 14 - 20) / 2, (TAB_H - 20) / 2)

		tabs[tab.categoria] = { button = button, color = tab.color }
		button.Activated:Connect(function()
			UI.click()
			selectTab(tab.categoria)
		end)
	end
end

function IdBook.mount(parent: ScreenGui)
	root = UI.new("Frame", {
		Name = "Carnet",
		Size = UDim2.fromOffset(ROOT_W, ROOT_H),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		-- La libreta no esta recta: en el video el jugador la sostiene
		-- con una mano y cae un par de grados.
		Rotation = -1.5,
		Visible = false,
		ZIndex = UI.Layer.Modal,
		Parent = parent,
	})

	-- El lomo, entre las dos paginas.
	UI.new("Frame", {
		Name = "Lomo",
		Size = UDim2.fromOffset(SPINE_W, PAGE_H - 24),
		Position = UDim2.fromOffset(MARGIN + LEFT_W, MARGIN + 12),
		BackgroundColor3 = C.PapelSombra,
		BorderSizePixel = 0,
		ZIndex = Z_SPINE,
		Parent = root,
	})

	buildTabs(root)
	buildLeftPage(root)
	buildRightPage(root)

	local close = UI.closeButton(root, Z_CHROME, function()
		IdBook.close()
	end)
	close.BackgroundTransparency = 1
	close.TextColor3 = C.Tinta

	--[[
		El carnet se puede abrir desde el menu, antes de que el jugador
		tenga cuerpo: ahi la foto sale vacia. Y se puede quedar abierto
		mientras al jugador lo expulsan del aula y reaparece, con lo
		cual la foto muestra el personaje viejo, que ya no existe.

		Las dos cosas las arregla lo mismo: rehacer la foto cuando llega
		un cuerpo nuevo, si el carnet esta a la vista.
	--]]
	player.CharacterAdded:Connect(function()
		task.wait(0.4)
		if root and root.Visible then
			refreshPortrait()
		end
	end)

	selectTab(currentTab)
end

function IdBook.setWallet(data: any)
	wallet = data
	if root and root.Visible then
		rebuildGrid()
	elseif creditLabel then
		creditLabel.Text = Strings.get("shop.price", { n = data.creditos or 0 })
	end
end

function IdBook.open()
	if not root or root.Visible then
		return
	end
	refreshPortrait()
	rebuildGrid()
	startSpin()
	UI.sound(Config.Sonidos.Papel, 0.5, 0.9)
	UI.show(root)
end

function IdBook.close()
	if not root or not root.Visible then
		return
	end
	stopSpin()
	UI.hide(root)
end

function IdBook.isOpen(): boolean
	return root ~= nil and root.Visible
end

return IdBook

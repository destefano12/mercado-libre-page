--!strict
--[[
	ShopUI
	------------------------------------------------------------------
	La tienda del pasillo: dos pestanas, objetos de trampa y estetica.

	El cliente solo dibuja precios y manda "quiero esto". Quien decide
	si alcanza la plata, si ya lo tenias y si la tienda esta abierta es
	el servidor (ShopService).

	Lo que cambio respecto de la version anterior:

	- Cada articulo tenia una tarjeta de texto plano. Ahora tiene un
	  ViewportFrame con el modelo 3D girando (ver `shared/Previews`).
	- El boton de precio se veia igual tuvieras o no tuvieras los
	  creditos: te enterabas de que no alcanzaba *despues* de hacer
	  clic, por un aviso generico. Ahora la tarjeta lo dice antes.
	- No habia estado de "esperando al servidor": se podia disparar la
	  compra cinco veces seguidas. Ahora el boton se apaga mientras el
	  remote viaja.
	- Vivia en ZIndex 12, debajo del scrim del menu (20), asi que
	  abrirla desde el menu la dibujaba por detras. Ahora esta en
	  UI.Layer.Modal, por encima.
--]]

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

local ShopUI = {}

local root: Frame
local creditLabel: TextLabel
local list: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}
local tabUnderline: Frame
local currentTab = "objeto"
local wallet: any = { creditos = 0, comprados = {}, estetica = {}, objeto = "nota" }

-- Los modelos que hay que girar. Una sola conexion para todas las
-- tarjetas: una por tarjeta serian trece Heartbeat en paralelo.
local spinning: { Model } = {}
local spinLoop: RBXScriptConnection? = nil

local CARD_HEIGHT = 96
local THUMB = 76

ShopUI.onNotify = function(_packet: any) end

-- ── giro de las miniaturas ─────────────────────────────────────────

local function startSpin()
	if spinLoop then
		return
	end
	local angle = 0
	spinLoop = RunService.RenderStepped:Connect(function(dt: number)
		angle += dt * 0.9
		for index = #spinning, 1, -1 do
			local model = spinning[index]
			if not model.Parent then
				table.remove(spinning, index)
			else
				-- Un balanceo leve en X ademas del giro: un objeto que
				-- gira sobre un solo eje se lee como una animacion de
				-- carga, no como un objeto.
				model:PivotTo(CFrame.Angles(math.sin(angle * 0.6) * 0.18, angle, 0))
			end
		end
	end)
end

local function stopSpin()
	if spinLoop then
		spinLoop:Disconnect()
		spinLoop = nil
	end
	table.clear(spinning)
end

--[[
	Un ViewportFrame con su propia camara. La camara se planta a una
	distancia fija mirando al origen: como todos los modelos de
	`Previews` entran en un cubo de ~2 studs, no hay que encuadrar uno
	por uno.
--]]
local function thumbnail(parent: Instance, id: string, layer: number): Frame
	local frame = UI.new("Frame", {
		Name = "Miniatura",
		Size = UDim2.fromOffset(THUMB, THUMB),
		Position = UDim2.fromOffset(12, (CARD_HEIGHT - THUMB) * 0.5),
		BackgroundColor3 = Theme.Surface.Deep,
		BorderSizePixel = 0,
		ZIndex = layer,
		Parent = parent,
	})
	UI.corner(frame, UI.Radius.sm)

	local model = Previews.build(id)
	if not model then
		-- Sin silueta definida cae en el icono plano. Es peor, pero no
		-- deja un cuadrado vacio.
		UI.icon(frame, "moneda", 34, Theme.Surface.Faint, layer + 1).Position =
			UDim2.new(0.5, -17, 0.5, -17)
		return frame
	end

	local viewport: ViewportFrame = UI.new("ViewportFrame", {
		Name = "Vista",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 175, 185),
		LightColor = Color3.fromRGB(255, 250, 238),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
		ZIndex = layer + 1,
		Parent = frame,
	})

	local camera = UI.new("Camera", {
		CFrame = CFrame.lookAt(Vector3.new(0, 0.6, 4.2), Vector3.new(0, 0, 0)),
		FieldOfView = 42,
		Parent = viewport,
	})
	viewport.CurrentCamera = camera
	model.Parent = viewport
	table.insert(spinning, model)

	return frame
end

-- ── tarjetas ───────────────────────────────────────────────────────

local function row(entry: any, order: number)
	local layer = UI.Layer.Modal + 1
	local owned = wallet.comprados and wallet.comprados[entry.id] == true
	local isGear = entry.tipo == "objeto"
	local active = (isGear and wallet.objeto == entry.id)
		or (not isGear and wallet.estetica and wallet.estetica[entry.id] == true)
	local credits = wallet.creditos or 0
	local affordable = owned or credits >= entry.precio

	local card = UI.new("Frame", {
		Name = entry.id,
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, CARD_HEIGHT),
		BackgroundColor3 = Theme.Surface.Raised,
		BackgroundTransparency = affordable and 0 or 0.45,
		BorderSizePixel = 0,
		ZIndex = layer,
		Parent = list,
	})
	UI.corner(card, UI.Radius.md)
	UI.stroke(card, active and Theme.Brand.Mint or Theme.Surface.Line, 1, active and 0.2 or 0.6)

	thumbnail(card, entry.id, layer + 1)

	UI.label({
		parent = card,
		name = "Nombre",
		text = Strings.get("item." .. entry.id),
		size = UDim2.new(1, -230, 0, 22),
		position = UDim2.fromOffset(THUMB + 26, 16),
		font = Theme.FontBold,
		textSize = UI.Type.subtitle,
		color = affordable and Theme.Surface.Text or Theme.Surface.Faint,
		layer = layer + 1,
	})

	local description = UI.label({
		parent = card,
		name = "Detalle",
		text = Strings.get("item.desc_" .. entry.id, { n = Config.Objetos.ChuletaRevela }),
		size = UDim2.new(1, -240, 0, 38),
		position = UDim2.fromOffset(THUMB + 26, 40),
		font = Theme.Font,
		textSize = UI.Type.small,
		color = Theme.Surface.Muted,
		wrapped = true,
		layer = layer + 1,
	})
	description.TextYAlignment = Enum.TextYAlignment.Top

	-- El precio, aparte del boton, para que se lea sin interpretar el
	-- estado del boton. En rojo cuando no alcanza.
	if not owned then
		UI.label({
			parent = card,
			name = "Precio",
			text = Strings.get("shop.price", { n = entry.precio }),
			size = UDim2.fromOffset(110, 18),
			position = UDim2.new(1, -122, 0, 14),
			anchor = Vector2.new(0, 0),
			font = Theme.FontBold,
			textSize = UI.Type.small,
			color = affordable and Theme.Hud.Credit or Theme.Brand.Tomato,
			align = Enum.TextXAlignment.Right,
			layer = layer + 1,
		})
	end

	local text: string
	local color: Color3
	if not owned then
		text = Strings.get("shop.buy")
		color = affordable and Theme.Hud.Credit or Theme.Surface.Faint
	elseif active then
		text = Strings.get("shop.equipped")
		color = Theme.Brand.Mint
	else
		text = Strings.get("shop.equip")
		color = Theme.Brand.Teal
	end

	local pending = false
	local button: UI.Button
	button = UI.button({
		parent = card,
		name = "Accion",
		text = text,
		size = UDim2.fromOffset(110, 34),
		position = UDim2.new(1, -122, 0, 44),
		color = color,
		ghost = true,
		textSize = UI.Type.small,
		radius = UI.Radius.sm,
		layer = layer + 1,
		onClick = function()
			if pending then
				return
			end
			pending = true
			button.setEnabled(false)
			task.spawn(function()
				local remote = owned and Net.func(Net.Functions.Equip)
					or Net.func(Net.Functions.Buy)
				local ok, result = pcall(function()
					return remote:InvokeServer(entry.id)
				end)
				pending = false
				if ok and result then
					if result.reason then
						ShopUI.onNotify(result.reason)
					end
					if result.ok then
						-- Un destello verde: la lista se reconstruye
						-- sola cuando llega la billetera nueva, pero el
						-- servidor puede tardar y el silencio se lee
						-- como que el clic no entro.
						TweenService:Create(card, UI.Motion.snap, {
							BackgroundColor3 = Theme.Brand.Mint,
						}):Play()
						task.delay(0.16, function()
							if card.Parent then
								TweenService:Create(card, UI.Motion.base, {
									BackgroundColor3 = Theme.Surface.Raised,
								}):Play()
							end
						end)
					end
				end
				if card.Parent then
					button.setEnabled(true)
				end
			end)
		end,
	})

	-- Ya comprado y ya equipado: no hay nada que hacer con el boton.
	if owned and active and not isGear then
		button.setEnabled(false)
	end
	if not owned and not affordable then
		button.setEnabled(false)
	end
end

local function rebuild()
	if not list then
		return
	end
	table.clear(spinning)
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local order = 0
	for _, entry in Config.Economia.Tienda do
		if entry.tipo == currentTab then
			order += 1
			row(entry, order)
		end
	end
	creditLabel.Text = Strings.get("shop.price", { n = wallet.creditos or 0 })
end

local function selectTab(id: string)
	currentTab = id
	local target = tabButtons[id]
	for otherId, other in tabButtons do
		TweenService:Create(other, UI.Motion.snap, {
			TextColor3 = otherId == id and Theme.Surface.Text or Theme.Surface.Muted,
		}):Play()
	end
	if target and tabUnderline then
		TweenService:Create(tabUnderline, UI.Motion.base, {
			Position = UDim2.fromOffset(target.Position.X.Offset, 82),
			Size = UDim2.fromOffset(target.Size.X.Offset, 3),
		}):Play()
	end
	rebuild()
end

-- ── construccion ───────────────────────────────────────────────────

function ShopUI.mount(parent: ScreenGui)
	root = UI.new("Frame", {
		Name = "Tienda",
		Size = UDim2.fromOffset(560, 520),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Surface.Base,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = UI.Layer.Modal,
		Parent = parent,
	})
	UI.corner(root, UI.Radius.lg)
	UI.stroke(root, Theme.Surface.Line, 1, 0.35)

	UI.icon(root, "moneda", 22, Theme.Hud.Credit, UI.Layer.Modal + 1).Position =
		UDim2.fromOffset(20, 20)

	UI.label({
		parent = root,
		name = "Titulo",
		text = Strings.get("shop.title"),
		size = UDim2.new(1, -220, 0, 28),
		position = UDim2.fromOffset(52, 16),
		font = Theme.FontBlack,
		textSize = UI.Type.title,
		color = Theme.Surface.Text,
		layer = UI.Layer.Modal + 1,
	})

	creditLabel = UI.label({
		parent = root,
		name = "Creditos",
		text = "0 cr",
		size = UDim2.fromOffset(120, 24),
		position = UDim2.new(1, -172, 0, 20),
		font = Theme.FontBold,
		textSize = UI.Type.subtitle,
		color = Theme.Hud.Credit,
		align = Enum.TextXAlignment.Right,
		layer = UI.Layer.Modal + 1,
	})

	UI.closeButton(root, UI.Layer.Modal + 1, function()
		ShopUI.close()
	end)

	local tabs = { { "objeto", "shop.tab_items" }, { "estetica", "shop.tab_looks" } }
	for i, tab in tabs do
		local button = UI.button({
			parent = root,
			name = tab[1],
			text = Strings.get(tab[2]),
			size = UDim2.fromOffset(130, 32),
			position = UDim2.fromOffset(20 + (i - 1) * 138, 50),
			color = Theme.Brand.Teal,
			ghost = true,
			textSize = UI.Type.small,
			radius = UI.Radius.sm,
			layer = UI.Layer.Modal + 1,
			onClick = function()
				selectTab(tab[1])
			end,
		})
		button.instance.TextColor3 = Theme.Surface.Muted
		tabButtons[tab[1]] = button.instance
	end

	-- El subrayado que se desliza entre pestanas. Antes el estado de la
	-- pestana activa se comunicaba cambiando dos colores de golpe.
	tabUnderline = UI.new("Frame", {
		Name = "Subrayado",
		Size = UDim2.fromOffset(130, 3),
		Position = UDim2.fromOffset(20, 82),
		BackgroundColor3 = Theme.Brand.Teal,
		BorderSizePixel = 0,
		ZIndex = UI.Layer.Modal + 2,
		Parent = root,
	})
	UI.corner(tabUnderline, 2)

	list = UI.scroller(
		root,
		UDim2.new(1, -32, 1, -112),
		UDim2.fromOffset(16, 96),
		UI.Layer.Modal + 1,
		UI.Space.sm
	)

	tabButtons.objeto.TextColor3 = Theme.Surface.Text
end

function ShopUI.setWallet(data: any)
	wallet = data
	if root and root.Visible then
		rebuild()
	elseif creditLabel then
		creditLabel.Text = Strings.get("shop.price", { n = data.creditos or 0 })
	end
end

function ShopUI.open()
	if not root or root.Visible then
		return
	end
	rebuild()
	startSpin()
	UI.show(root)
end

function ShopUI.close()
	if not root or not root.Visible then
		return
	end
	stopSpin()
	UI.hide(root)
end

function ShopUI.isOpen(): boolean
	return root ~= nil and root.Visible
end

return ShopUI

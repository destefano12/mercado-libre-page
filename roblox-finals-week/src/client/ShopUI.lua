--!strict
--[[
	ShopUI
	------------------------------------------------------------------
	La tienda del pasillo: dos pestanas, objetos de trampa y estetica.

	El cliente solo dibuja precios y manda "quiero esto". Quien decide
	si alcanza la plata, si ya lo tenias y si la tienda esta abierta es
	el servidor (ShopService).
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Strings = require(Shared:WaitForChild("Strings"))
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local ShopUI = {}

local root: Frame
local creditLabel: TextLabel
local list: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}
local currentTab = "objeto"
local wallet: any = { creditos = 0, comprados = {}, estetica = {}, objeto = "nota" }

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
	Util.playSound(Config.Sonidos.Click, workspace :: any, 0.25, 1.1)
end

ShopUI.onNotify = function(_packet: any) end

-- ── filas ──────────────────────────────────────────────────────────

local function row(entry: any, order: number)
	local owned = wallet.comprados and wallet.comprados[entry.id] == true
	local isGear = entry.tipo == "objeto"
	local active = isGear and wallet.objeto == entry.id
		or (not isGear and wallet.estetica and wallet.estetica[entry.id] == true)

	local card = new("Frame", {
		Name = entry.id,
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 72),
		BackgroundColor3 = Theme.Menu.PanelAlt,
		BorderSizePixel = 0,
	}, list)
	corner(card, 10)

	new("TextLabel", {
		Text = Strings.get("item." .. entry.id),
		Size = UDim2.new(1, -120, 0, 20),
		Position = UDim2.new(0, 14, 0, 10),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		TextSize = 15,
		TextColor3 = Theme.Menu.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)

	new("TextLabel", {
		Text = Strings.get("item.desc_" .. entry.id, { n = Config.Objetos.ChuletaRevela }),
		Size = UDim2.new(1, -130, 0, 32),
		Position = UDim2.new(0, 14, 0, 30),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextSize = 12,
		TextColor3 = Theme.Menu.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
	}, card)

	-- Un solo boton que cambia de papel: comprar, equipar o equipado.
	local canBuy = not owned or isGear
	local text: string
	local color: Color3
	if not owned then
		text = string.format("%s  %s", Strings.get("shop.buy"),
			Strings.get("shop.price", { n = entry.precio }))
		color = Theme.Hud.Credit
	elseif active then
		text = Strings.get("shop.equipped")
		color = Theme.Hud.Safe
	else
		text = Strings.get("shop.equip")
		color = Theme.Menu.Accent
	end

	local button = new("TextButton", {
		Name = "Accion",
		Text = text,
		Size = UDim2.new(0, 96, 0, 34),
		Position = UDim2.new(1, -108, 0, 19),
		BackgroundColor3 = color,
		BackgroundTransparency = active and 0.82 or 0.86,
		AutoButtonColor = false,
		Font = Theme.FontBold,
		TextSize = 12,
		TextColor3 = color,
		BorderSizePixel = 0,
	}, card)
	corner(button, 8)
	new("UIStroke", { Color = color, Thickness = 1, Transparency = 0.55 }, button)

	button.MouseButton1Click:Connect(function()
		click()
		task.spawn(function()
			local remote = owned and Net.func(Net.Functions.Equip) or Net.func(Net.Functions.Buy)
			local ok, result = pcall(function()
				return remote:InvokeServer(entry.id)
			end)
			if ok and result and result.reason then
				ShopUI.onNotify(result.reason)
			end
		end)
	end)

	if not canBuy and not owned then
		button.Active = false
	end
end

local function rebuild()
	if not list then
		return
	end
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
	list.CanvasSize = UDim2.new(0, 0, 0, order * 78 + 8)
	creditLabel.Text = Strings.get("shop.price", { n = wallet.creditos or 0 })
end

-- ── construccion ───────────────────────────────────────────────────

function ShopUI.mount(parent: ScreenGui)
	root = new("Frame", {
		Name = "Tienda",
		Size = UDim2.new(0, 440, 0, 460),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Menu.Panel,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 12,
	}, parent)
	corner(root, 14)
	new("UIStroke", { Color = Theme.Menu.Line, Thickness = 1, Transparency = 0.4 }, root)

	new("TextLabel", {
		Text = Strings.get("shop.title"),
		Size = UDim2.new(1, -120, 0, 28),
		Position = UDim2.new(0, 18, 0, 14),
		BackgroundTransparency = 1,
		Font = Theme.FontBlack,
		TextSize = 20,
		TextColor3 = Theme.Menu.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 13,
	}, root)

	creditLabel = new("TextLabel", {
		Text = "0 cr",
		Size = UDim2.new(0, 100, 0, 24),
		Position = UDim2.new(1, -118, 0, 16),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		TextSize = 15,
		TextColor3 = Theme.Hud.Credit,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 13,
	}, root)

	local close = new("TextButton", {
		Text = "X",
		Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(1, -40, 0, 14),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		TextSize = 16,
		TextColor3 = Theme.Menu.Muted,
		ZIndex = 13,
	}, root)
	close.MouseButton1Click:Connect(function()
		click()
		ShopUI.close()
	end)

	local tabs = { { "objeto", "shop.tab_items" }, { "estetica", "shop.tab_looks" } }
	for i, tab in tabs do
		local button = new("TextButton", {
			Name = tab[1],
			Text = Strings.get(tab[2]),
			Size = UDim2.new(0, 120, 0, 30),
			Position = UDim2.new(0, 18 + (i - 1) * 128, 0, 50),
			BackgroundColor3 = Theme.Menu.PanelAlt,
			AutoButtonColor = false,
			Font = Theme.FontBold,
			TextSize = 13,
			TextColor3 = Theme.Menu.Muted,
			BorderSizePixel = 0,
			ZIndex = 13,
		}, root)
		corner(button, 8)
		button.MouseButton1Click:Connect(function()
			click()
			currentTab = tab[1]
			for id, other in tabButtons do
				other.TextColor3 = id == currentTab and Theme.Menu.Text or Theme.Menu.Muted
				other.BackgroundColor3 = id == currentTab and Theme.Menu.Line or Theme.Menu.PanelAlt
			end
			rebuild()
		end)
		tabButtons[tab[1]] = button
	end
	tabButtons.objeto.TextColor3 = Theme.Menu.Text
	tabButtons.objeto.BackgroundColor3 = Theme.Menu.Line

	list = new("ScrollingFrame", {
		Name = "Lista",
		Size = UDim2.new(1, -32, 1, -104),
		Position = UDim2.new(0, 16, 0, 90),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Menu.Line,
		CanvasSize = UDim2.new(),
		ZIndex = 13,
	}, root)
	new("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, list)
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
	if not root then
		return
	end
	root.Visible = true
	rebuild()
end

function ShopUI.close()
	if root then
		root.Visible = false
	end
end

function ShopUI.isOpen(): boolean
	return root ~= nil and root.Visible
end

return ShopUI

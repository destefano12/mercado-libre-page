--!strict
--[[
	LobbyUI
	------------------------------------------------------------------
	El buscador de salas: buscar por nombre, entrar (con clave si la
	tiene) y crear la tuya eligiendo nombre, clave y capacidad.

	Todo lo pesado lo hace LobbyService en el servidor; aca solo se
	dibuja la lista y se manda lo que el jugador escribio.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Strings = require(Shared:WaitForChild("Strings"))
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local player = Players.LocalPlayer

local LobbyUI = {}

local root: Frame
local list: ScrollingFrame
local searchBox: TextBox
local nameBox: TextBox
local passwordBox: TextBox
local joinPasswordBox: TextBox
local capacityButton: TextButton
local statusLabel: TextLabel

local capacityIndex = 1
local selected: string? = nil

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

LobbyUI.onNotify = function(_packet: any) end

local function status(packet: any)
	if statusLabel and packet then
		statusLabel.Text = Strings.render(packet)
	end
end

local function textBox(parent: Instance, name: string, placeholder: string,
	size: UDim2, position: UDim2): TextBox
	local box = new("TextBox", {
		Name = name,
		Text = "",
		PlaceholderText = placeholder,
		Size = size,
		Position = position,
		BackgroundColor3 = Theme.Menu.PanelAlt,
		Font = Theme.Font,
		TextSize = 13,
		TextColor3 = Theme.Menu.Text,
		PlaceholderColor3 = Theme.Menu.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		BorderSizePixel = 0,
		ZIndex = 22,
	}, parent)
	corner(box, 8)
	new("UIPadding", { PaddingLeft = UDim.new(0, 10) }, box)
	return box
end

local function actionButton(parent: Instance, name: string, text: string, color: Color3,
	size: UDim2, position: UDim2, callback: () -> ()): TextButton
	local button = new("TextButton", {
		Name = name,
		Text = text,
		Size = size,
		Position = position,
		BackgroundColor3 = color,
		BackgroundTransparency = 0.85,
		AutoButtonColor = false,
		Font = Theme.FontBold,
		TextSize = 13,
		TextColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 22,
	}, parent)
	corner(button, 8)
	new("UIStroke", { Color = color, Thickness = 1, Transparency = 0.5 }, button)
	button.MouseButton1Click:Connect(function()
		click()
		callback()
	end)
	return button
end

-- ── lista ──────────────────────────────────────────────────────────

local function drawRoom(room: any, order: number)
	local card = new("TextButton", {
		Name = room.code,
		LayoutOrder = order,
		Text = "",
		Size = UDim2.new(1, -8, 0, 54),
		BackgroundColor3 = selected == room.code and Theme.Menu.Line or Theme.Menu.PanelAlt,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 22,
	}, list)
	corner(card, 10)

	new("TextLabel", {
		Text = room.name,
		Size = UDim2.new(1, -140, 0, 20),
		Position = UDim2.new(0, 14, 0, 8),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		TextSize = 14,
		TextColor3 = Theme.Menu.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 23,
	}, card)

	new("TextLabel", {
		Text = string.format("%s%s", room.host or "",
			room.locked and ("  -  " .. Strings.get("room.locked")) or ""),
		Size = UDim2.new(1, -140, 0, 16),
		Position = UDim2.new(0, 14, 0, 28),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextSize = 11,
		TextColor3 = room.locked and Theme.Hud.Warn or Theme.Menu.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 23,
	}, card)

	new("TextLabel", {
		Text = Strings.get("room.players", { n = room.count, max = room.maxPlayers }),
		Size = UDim2.new(0, 70, 0, 20),
		Position = UDim2.new(1, -86, 0, 17),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		TextSize = 14,
		TextColor3 = Theme.Menu.Text,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 23,
	}, card)

	card.MouseButton1Click:Connect(function()
		click()
		selected = room.code
		for _, child in list:GetChildren() do
			if child:IsA("TextButton") then
				child.BackgroundColor3 = child.Name == room.code
					and Theme.Menu.Line or Theme.Menu.PanelAlt
			end
		end
	end)
end

function LobbyUI.refresh()
	if not list then
		return
	end
	task.spawn(function()
		local ok, result = pcall(function()
			return Net.func(Net.Functions.ListRooms):InvokeServer(searchBox.Text)
		end)
		for _, child in list:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		if not ok or not result or not result.ok then
			status(result and result.reason or { key = "room.unavailable" })
			list.CanvasSize = UDim2.new()
			return
		end
		if #result.rooms == 0 then
			status({ key = "room.empty" })
		else
			status({ key = "room.title" })
		end
		for i, room in result.rooms do
			drawRoom(room, i)
		end
		list.CanvasSize = UDim2.new(0, 0, 0, #result.rooms * 60 + 8)
	end)
end

-- ── construccion ───────────────────────────────────────────────────

function LobbyUI.mount(parent: ScreenGui)
	root = new("Frame", {
		Name = "Salas",
		Size = UDim2.new(0, 720, 0, 470),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Menu.Panel,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 21,
	}, parent)
	corner(root, 14)
	new("UIStroke", { Color = Theme.Menu.Line, Thickness = 1, Transparency = 0.4 }, root)

	new("TextLabel", {
		Text = Strings.get("room.title"),
		Size = UDim2.new(0, 200, 0, 28),
		Position = UDim2.new(0, 18, 0, 14),
		BackgroundTransparency = 1,
		Font = Theme.FontBlack,
		TextSize = 20,
		TextColor3 = Theme.Menu.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 22,
	}, root)

	statusLabel = new("TextLabel", {
		Text = "",
		Size = UDim2.new(0, 330, 0, 18),
		Position = UDim2.new(0, 18, 0, 42),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextSize = 12,
		TextColor3 = Theme.Menu.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 22,
	}, root)

	local close = new("TextButton", {
		Text = "X",
		Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(1, -40, 0, 14),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		TextSize = 16,
		TextColor3 = Theme.Menu.Muted,
		ZIndex = 22,
	}, root)
	close.MouseButton1Click:Connect(function()
		click()
		LobbyUI.close()
	end)

	-- Columna izquierda: buscador y lista.
	searchBox = textBox(root, "Buscar", Strings.get("room.search"),
		UDim2.new(0, 300, 0, 32), UDim2.new(0, 18, 0, 68))
	searchBox.FocusLost:Connect(function()
		LobbyUI.refresh()
	end)

	actionButton(root, "Actualizar", Strings.get("room.refresh"), Theme.Menu.Accent,
		UDim2.new(0, 88, 0, 32), UDim2.new(0, 326, 0, 68), function()
			LobbyUI.refresh()
		end)

	list = new("ScrollingFrame", {
		Name = "Lista",
		Size = UDim2.new(0, 396, 1, -170),
		Position = UDim2.new(0, 18, 0, 110),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Menu.Line,
		CanvasSize = UDim2.new(),
		ZIndex = 22,
	}, root)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	joinPasswordBox = textBox(root, "ClaveEntrar", Strings.get("room.password"),
		UDim2.new(0, 250, 0, 32), UDim2.new(0, 18, 1, -52))
	actionButton(root, "Entrar", Strings.get("room.join"), Theme.Hud.Safe,
		UDim2.new(0, 130, 0, 32), UDim2.new(0, 276, 1, -52), function()
			if not selected then
				status({ key = "room.gone" })
				return
			end
			task.spawn(function()
				local ok, result = pcall(function()
					return Net.func(Net.Functions.JoinRoom)
						:InvokeServer(selected, joinPasswordBox.Text)
				end)
				if ok and result and result.reason then
					status(result.reason)
					LobbyUI.onNotify(result.reason)
				end
			end)
		end)

	-- Columna derecha: crear sala.
	local panel = new("Frame", {
		Name = "Crear",
		Size = UDim2.new(0, 260, 1, -86),
		Position = UDim2.new(1, -278, 0, 68),
		BackgroundColor3 = Theme.Menu.PanelAlt,
		BorderSizePixel = 0,
		ZIndex = 22,
	}, root)
	corner(panel, 12)

	new("TextLabel", {
		Text = Strings.get("room.create"),
		Size = UDim2.new(1, -28, 0, 24),
		Position = UDim2.new(0, 14, 0, 12),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		TextSize = 16,
		TextColor3 = Theme.Menu.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 23,
	}, panel)

	nameBox = textBox(panel, "Nombre", Strings.get("room.name"),
		UDim2.new(1, -28, 0, 32), UDim2.new(0, 14, 0, 46))
	passwordBox = textBox(panel, "Clave", Strings.get("room.password"),
		UDim2.new(1, -28, 0, 32), UDim2.new(0, 14, 0, 86))

	capacityButton = actionButton(panel, "Capacidad",
		Strings.get("room.capacity", { n = Config.Salas.CapacidadesPosibles[1] }),
		Theme.Menu.Accent, UDim2.new(1, -28, 0, 32), UDim2.new(0, 14, 0, 126), function()
			capacityIndex = (capacityIndex % #Config.Salas.CapacidadesPosibles) + 1
			capacityButton.Text = Strings.get("room.capacity",
				{ n = Config.Salas.CapacidadesPosibles[capacityIndex] })
		end)

	actionButton(panel, "Confirmar", Strings.get("room.create"), Theme.Hud.Safe,
		UDim2.new(1, -28, 0, 36), UDim2.new(0, 14, 0, 172), function()
			task.spawn(function()
				local ok, result = pcall(function()
					return Net.func(Net.Functions.CreateRoom):InvokeServer({
						name = nameBox.Text,
						password = passwordBox.Text,
						maxPlayers = Config.Salas.CapacidadesPosibles[capacityIndex],
					})
				end)
				if ok and result and result.reason then
					status(result.reason)
					LobbyUI.onNotify(result.reason)
				end
			end)
		end)

	actionButton(panel, "Invitar", Strings.get("room.invite"), Theme.Hud.Credit,
		UDim2.new(1, -28, 0, 32), UDim2.new(0, 14, 0, 218), function()
			local ok, can = pcall(function()
				return SocialService:CanSendGameInviteAsync(player)
			end)
			if ok and can then
				pcall(function()
					SocialService:PromptGameInvite(player)
				end)
			end
		end)

	actionButton(panel, "Volver", Strings.get("menu.back"), Theme.Menu.Muted,
		UDim2.new(1, -28, 0, 32), UDim2.new(0, 14, 1, -46), function()
			LobbyUI.close()
		end)
end

function LobbyUI.open()
	if not root then
		return
	end
	root.Visible = true
	LobbyUI.refresh()
end

function LobbyUI.close()
	if root then
		root.Visible = false
	end
end

function LobbyUI.isOpen(): boolean
	return root ~= nil and root.Visible
end

return LobbyUI

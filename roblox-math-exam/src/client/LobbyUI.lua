--!strict
--[[
	LobbyUI
	------------------------------------------------------------------
	El buscador de salas: buscás por nombre, entrás a una, o creás la
	tuya poniendole nombre, cuanta gente entra y contraseña si la querés
	privada.

	Se dibuja adentro del panel del menu, con la misma sobriedad que el
	resto: una lista, un buscador y nada mas.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Strings = require(Shared:WaitForChild("Strings"))
local Theme = require(Shared:WaitForChild("Theme"))
local Util = require(Shared:WaitForChild("Util"))

local L = Config.Lobby

local LobbyUI = {}

local refs: { [string]: any } = {}
local creating = false
local pending = false

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

local function reasonText(reason: any, fallback: string): string
	if typeof(reason) == "table" and reason.key then
		return Strings.get(reason.key, reason.args)
	end
	return Strings.get(fallback)
end

local function status(text: string)
	if refs.status then
		refs.status.Text = text
	end
end

-- ─────────────────────────────────────────────────────────────
-- Piezas
-- ─────────────────────────────────────────────────────────────

local function field(parent: Instance, order: number, placeholderKey: string, limit: number): TextBox
	local box = el("TextBox", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Theme.Menu.Panel,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Font = Theme.Font,
		PlaceholderText = Strings.get(placeholderKey),
		PlaceholderColor3 = Theme.Menu.Line,
		Text = "",
		TextColor3 = Theme.Menu.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
	}, parent)
	Util.roundify(box, 8, Theme.Menu.Line, 1)
	el("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, box)

	box:GetPropertyChangedSignal("Text"):Connect(function()
		if #box.Text > limit then
			box.Text = string.sub(box.Text, 1, limit)
		end
	end)
	return box
end

local function button(parent: Instance, order: number, labelKey: string, primary: boolean): TextButton
	local instance = el("TextButton", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = primary and Theme.Menu.Accent or Theme.Menu.Panel,
		BackgroundTransparency = primary and 0 or 0.2,
		AutoButtonColor = false,
		Font = Theme.FontBold,
		Text = Strings.get(labelKey),
		TextColor3 = primary and Color3.fromRGB(16, 17, 21) or Theme.Menu.Text,
		TextSize = 17,
		BorderSizePixel = 0,
	}, parent)
	Util.roundify(instance, 10, Theme.Menu.Line, primary and 0 or 1)
	return instance
end

-- ─────────────────────────────────────────────────────────────
-- Lista de salas
-- ─────────────────────────────────────────────────────────────

local function roomRow(room: any, order: number)
	local card = el("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 66),
		BackgroundColor3 = Theme.Menu.Panel,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
	}, refs.list)
	Util.roundify(card, 8, Theme.Menu.Line, 1)

	el("TextLabel", {
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -120, 0, 22),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		Text = (room.locked and "🔒  " or "") .. room.name,
		TextColor3 = Theme.Menu.Text,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, card)

	el("TextLabel", {
		Position = UDim2.fromOffset(14, 34),
		Size = UDim2.new(1, -120, 0, 18),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = string.format("%s  ·  %s",
			Strings.get("lobby.slots", { count = room.count, max = room.maxPlayers }),
			Strings.get("lobby.host", { host = room.host or "?" })),
		TextColor3 = Theme.Menu.Muted,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)

	local join = el("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(92, 38),
		BackgroundColor3 = Theme.Menu.Accent,
		AutoButtonColor = false,
		Font = Theme.FontBold,
		Text = Strings.get("lobby.join"),
		TextColor3 = Color3.fromRGB(16, 17, 21),
		TextSize = 15,
		BorderSizePixel = 0,
	}, card)
	Util.roundify(join, 8)

	join.MouseButton1Click:Connect(function()
		if pending then
			return
		end
		-- Si tiene candado, la contraseña sale del campo de arriba.
		local password = refs.joinPassword and refs.joinPassword.Text or ""
		if room.locked and password == "" then
			status(Strings.get("lobby.locked"))
			if refs.joinPassword then
				refs.joinPassword.Visible = true
			end
			return
		end

		pending = true
		status(Strings.get("lobby.joining"))
		task.spawn(function()
			local response = Net.func(Net.Functions.JoinRoom):InvokeServer(room.code, password)
			pending = false
			if not response or not response.ok then
				status(reasonText(response and response.reason, "lobby.unavailable"))
			end
		end)
	end)
end

function LobbyUI.refresh()
	if not refs.list then
		return
	end
	for _, child in refs.list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	status(Strings.get("lobby.loading"))

	task.spawn(function()
		local query = refs.search and refs.search.Text or ""
		local response = Net.func(Net.Functions.ListRooms):InvokeServer(query)

		if not refs.list or not refs.list.Parent then
			return
		end
		if not response or not response.ok then
			status(reasonText(response and response.reason, "lobby.unavailable"))
			return
		end

		if #response.rooms == 0 then
			status(Strings.get("lobby.empty"))
			return
		end

		status("")
		for index, room in response.rooms do
			roomRow(room, index)
		end
	end)
end

-- ─────────────────────────────────────────────────────────────
-- Crear
-- ─────────────────────────────────────────────────────────────

local function buildCreateForm(parent: Instance)
	local form = el("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, parent)
	el("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, form)

	el("TextLabel", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		Text = Strings.get("lobby.create"),
		TextColor3 = Theme.Menu.Text,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, form)

	local name = field(form, 2, "lobby.name", L.NameLimit)
	local password = field(form, 3, "lobby.passwordOptional", L.PasswordLimit)

	local slots = L.DefaultMaxPlayers
	local size = button(form, 4, "lobby.maxPlayers", false)
	size.Text = Strings.get("lobby.maxPlayers", { count = slots })
	size.MouseButton1Click:Connect(function()
		slots = slots >= L.MaxPlayers and L.MinPlayers or slots + 2
		size.Text = Strings.get("lobby.maxPlayers", { count = slots })
	end)

	local confirm = button(form, 5, "lobby.create", true)
	confirm.MouseButton1Click:Connect(function()
		if pending then
			return
		end
		pending = true
		status(Strings.get("lobby.creating"))
		task.spawn(function()
			local response = Net.func(Net.Functions.CreateRoom):InvokeServer({
				name = name.Text,
				password = password.Text,
				maxPlayers = slots,
			})
			pending = false
			if not response or not response.ok then
				status(reasonText(response and response.reason, "lobby.unavailable"))
			end
		end)
	end)

	local back = button(form, 6, "lobby.back", false)
	back.MouseButton1Click:Connect(function()
		creating = false
		LobbyUI.render(parent.Parent :: Instance)
	end)

	return form
end

-- ─────────────────────────────────────────────────────────────
-- Render
-- ─────────────────────────────────────────────────────────────

function LobbyUI.render(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	refs = {}

	local root = el("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, parent)

	if creating then
		buildCreateForm(root)
		refs.status = el("TextLabel", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			Font = Theme.Font,
			Text = "",
			TextColor3 = Theme.Menu.Muted,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
		}, root)
		return
	end

	el("TextLabel", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		Text = Strings.get("lobby.title"),
		TextColor3 = Theme.Menu.Text,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, root)

	local searchRow = el("Frame", {
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
	}, root)

	refs.search = field(searchRow, 1, "lobby.search", L.NameLimit)
	refs.search.Size = UDim2.new(1, -104, 0, 44)
	refs.search.FocusLost:Connect(function()
		LobbyUI.refresh()
	end)

	local refresh = el("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(94, 44),
		BackgroundColor3 = Theme.Menu.Panel,
		BackgroundTransparency = 0.2,
		AutoButtonColor = false,
		Font = Theme.Font,
		Text = Strings.get("lobby.refresh"),
		TextColor3 = Theme.Menu.Text,
		TextSize = 15,
		BorderSizePixel = 0,
	}, searchRow)
	Util.roundify(refresh, 8, Theme.Menu.Line, 1)
	refresh.MouseButton1Click:Connect(LobbyUI.refresh)

	refs.joinPassword = field(root, 2, "lobby.password", L.PasswordLimit)
	refs.joinPassword.Position = UDim2.fromOffset(0, 94)
	refs.joinPassword.Size = UDim2.new(1, 0, 0, 40)
	refs.joinPassword.Visible = false

	refs.list = el("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 142),
		Size = UDim2.new(1, 0, 1, -212),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Menu.Line,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, root)
	el("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, refs.list)

	refs.status = el("TextLabel", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -56),
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = "",
		TextColor3 = Theme.Menu.Muted,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}, root)

	-- Invitar amigos al servidor actual: es la forma nativa de Roblox y
	-- sirve igual estes en una sala o en el servidor publico.
	local invite = el("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(150, 46),
		BackgroundColor3 = Theme.Menu.Panel,
		BackgroundTransparency = 0.2,
		AutoButtonColor = false,
		Font = Theme.Font,
		Text = Strings.get("menu.mode.invite"),
		TextColor3 = Theme.Menu.Text,
		TextSize = 15,
		BorderSizePixel = 0,
	}, root)
	Util.roundify(invite, 10, Theme.Menu.Line, 1)
	invite.MouseButton1Click:Connect(function()
		task.spawn(function()
			local player = Players.LocalPlayer
			local can = false
			pcall(function()
				can = SocialService:CanSendGameInviteAsync(player)
			end)
			if can then
				pcall(function()
					SocialService:PromptGameInvite(player)
				end)
			else
				status(Strings.get("lobby.unavailable"))
			end
		end)
	end)

	local create = el("TextButton", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, -160, 0, 46),
		BackgroundColor3 = Theme.Menu.Accent,
		AutoButtonColor = false,
		Font = Theme.FontBold,
		Text = Strings.get("lobby.create"),
		TextColor3 = Color3.fromRGB(16, 17, 21),
		TextSize = 17,
		BorderSizePixel = 0,
	}, root)
	Util.roundify(create, 10)
	create.MouseButton1Click:Connect(function()
		creating = true
		LobbyUI.render(parent)
	end)

	LobbyUI.refresh()
end

return LobbyUI

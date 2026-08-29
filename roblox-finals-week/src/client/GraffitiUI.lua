--!strict
--[[
	GraffitiUI
	------------------------------------------------------------------
	El aerosol: paleta de ocho colores, cuatro grosores, y pintar
	manteniendo el clic.

	El cliente no dibuja nada por su cuenta. Manda la direccion en la
	que apunta la camara y el servidor decide contra que pared pego y
	estampa el punto — que despues se replica a todos. Por eso lo que
	pintas lo ven los demas, y por eso no se puede pintar a traves de
	una pared por mucho que se toque el cliente.

	El ritmo de envio esta limitado aca ademas de en el servidor: sin
	eso, a 240 fps mandarias 240 puntos por segundo y el servidor
	tiraria 222 a la basura.
--]]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Theme = require(Shared:WaitForChild("Theme"))
local Strings = require(Shared:WaitForChild("Strings"))
local Net = require(Shared:WaitForChild("Net"))

local player = Players.LocalPlayer

local GraffitiUI = {}

local G = Config.Grafiti

local root: Frame
local swatches: { TextButton } = {}
local sizeLabel: TextLabel
local preview: Frame

local colorIndex = 1
local sizeIndex = 2
local painting = false
local lastSend = 0
local equipped = false

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

local function refresh()
	for i, button in swatches do
		local on = i == colorIndex
		button.Size = on and UDim2.fromOffset(30, 30) or UDim2.fromOffset(24, 24)
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = on and 0 or 0.75
		end
	end
	local studs = G.Tamanos[sizeIndex]
	sizeLabel.Text = string.format("%s  %.1f", Strings.get("paint.size"), studs)
	preview.BackgroundColor3 = G.Paleta[colorIndex]
	-- La muestra se dibuja a la misma escala que el lienzo del mundo.
	local pixels = math.max(4, math.round(studs * G.PixelesPorStud))
	preview.Size = UDim2.fromOffset(pixels, pixels)
end

function GraffitiUI.mount(parent: ScreenGui)
	root = new("Frame", {
		Name = "Aerosol",
		Size = UDim2.new(0, 300, 0, 96),
		Position = UDim2.new(0.5, 0, 1, -150),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Theme.Hud.Panel,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 5,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, root)
	new("UIStroke", { Color = Theme.Hud.Line, Thickness = 1, Transparency = 0.4 }, root)

	new("TextLabel", {
		Text = Strings.get("paint.hint"),
		Size = UDim2.new(1, -20, 0, 16),
		Position = UDim2.new(0, 10, 0, 6),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextSize = 11,
		TextColor3 = Theme.Hud.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6,
	}, root)

	local strip = new("Frame", {
		Name = "Paleta",
		Size = UDim2.new(1, -20, 0, 32),
		Position = UDim2.new(0, 10, 0, 26),
		BackgroundTransparency = 1,
		ZIndex = 6,
	}, root)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, strip)

	for i, color in G.Paleta do
		local button = new("TextButton", {
			Name = "C" .. i,
			LayoutOrder = i,
			Text = "",
			Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = color,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			ZIndex = 7,
		}, strip)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, button)
		new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.75 }, button)
		button.MouseButton1Click:Connect(function()
			colorIndex = i
			refresh()
		end)
		swatches[i] = button
	end

	sizeLabel = new("TextLabel", {
		Text = "",
		Size = UDim2.new(1, -70, 0, 18),
		Position = UDim2.new(0, 10, 0, 66),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		TextSize = 12,
		TextColor3 = Theme.Hud.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6,
	}, root)

	preview = new("Frame", {
		Name = "Muestra",
		Size = UDim2.fromOffset(12, 12),
		Position = UDim2.new(1, -34, 0, 75),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = G.Paleta[1],
		BorderSizePixel = 0,
		ZIndex = 7,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, preview)

	refresh()
	GraffitiUI.bind()
end

-- ── herramienta equipada ───────────────────────────────────────────

local function watch(character: Model)
	local function check()
		local tool = character:FindFirstChildOfClass("Tool")
		equipped = tool ~= nil and tool:GetAttribute("Pintar") == true
		root.Visible = equipped
		if not equipped then
			painting = false
		end
	end
	character.ChildAdded:Connect(check)
	character.ChildRemoved:Connect(check)
	check()
end

function GraffitiUI.bind()
	if player.Character then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(watch)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not equipped then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			painting = true
		elseif input.KeyCode == Enum.KeyCode.C then
			colorIndex = (colorIndex % #G.Paleta) + 1
			refresh()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			painting = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input, processed)
		if processed or not equipped then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local step = input.Position.Z > 0 and 1 or -1
			sizeIndex = math.clamp(sizeIndex + step, 1, #G.Tamanos)
			refresh()
		end
	end)

	RunService.RenderStepped:Connect(function()
		if not painting or not equipped then
			return
		end
		local now = os.clock()
		if now - lastSend < 1 / G.PuntosPorSegundo then
			return
		end
		lastSend = now

		local camera = workspace.CurrentCamera
		if camera then
			Net.event(Net.Events.Paint):FireServer(camera.CFrame.LookVector, colorIndex, sizeIndex)
		end
	end)
end

function GraffitiUI.setVisible(visible: boolean)
	if root then
		root.Visible = visible and equipped
	end
	if not visible then
		painting = false
	end
end

return GraffitiUI

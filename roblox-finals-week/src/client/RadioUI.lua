--!strict
--[[
	RadioUI
	------------------------------------------------------------------
	El walkie y el celular. Misma pantalla, dos alcances distintos:
	el walkie llega a todo el colegio, el celular solo al de al lado.

	El panel aparece solo cuando tenes el aparato en la mano — es
	deliberado: si el walkie estuviera siempre abierto no habria nada
	que arriesgar al sacarlo en pleno examen, que es justo donde el
	profesor te lo puede ver.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Theme = require(Shared:WaitForChild("Theme"))
local Strings = require(Shared:WaitForChild("Strings"))
local Net = require(Shared:WaitForChild("Net"))

local player = Players.LocalPlayer

local RadioUI = {}

local root: Frame
local title: TextLabel
local log: ScrollingFrame
local box: TextBox
local kind: string? = nil
local entries = 0

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

function RadioUI.mount(parent: ScreenGui)
	root = new("Frame", {
		Name = "Radio",
		Size = UDim2.new(0, 290, 0, 210),
		Position = UDim2.new(1, -16, 1, -170),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = Theme.Hud.Panel,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 5,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, root)
	new("UIStroke", { Color = Theme.Hud.Line, Thickness = 1, Transparency = 0.4 }, root)

	title = new("TextLabel", {
		Text = Strings.get("radio.title"),
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.new(0, 10, 0, 8),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		TextSize = 14,
		TextColor3 = Theme.Hud.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6,
	}, root)

	log = new("ScrollingFrame", {
		Name = "Registro",
		Size = UDim2.new(1, -20, 1, -80),
		Position = UDim2.new(0, 10, 0, 32),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Hud.Line,
		CanvasSize = UDim2.new(),
		ZIndex = 6,
	}, root)
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, log)

	box = new("TextBox", {
		Name = "Mensaje",
		Text = "",
		PlaceholderText = Strings.get("radio.placeholder"),
		Size = UDim2.new(1, -84, 0, 30),
		Position = UDim2.new(0, 10, 1, -40),
		BackgroundColor3 = Theme.Hud.PanelSoft,
		Font = Theme.Font,
		TextSize = 13,
		TextColor3 = Theme.Hud.Text,
		PlaceholderColor3 = Theme.Hud.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, box)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, box)

	local send = new("TextButton", {
		Name = "Transmitir",
		Text = Strings.get("radio.send"),
		Size = UDim2.new(0, 64, 0, 30),
		Position = UDim2.new(1, -74, 1, -40),
		BackgroundColor3 = Theme.Hud.Safe,
		BackgroundTransparency = 0.84,
		AutoButtonColor = false,
		Font = Theme.FontBold,
		TextSize = 12,
		TextColor3 = Theme.Hud.Safe,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, send)
	new("UIStroke", { Color = Theme.Hud.Safe, Thickness = 1, Transparency = 0.5 }, send)

	send.MouseButton1Click:Connect(function()
		RadioUI.send()
	end)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			RadioUI.send()
		end
	end)

	box:GetPropertyChangedSignal("Text"):Connect(function()
		local limit = Config.Herramientas.RadioCaracteres
		if #box.Text > limit then
			box.Text = string.sub(box.Text, 1, limit)
		end
	end)

	RadioUI.watch()
end

function RadioUI.send()
	if not kind then
		return
	end
	local text = box.Text
	if text == "" then
		return
	end
	box.Text = ""
	Net.event(Net.Events.Radio):FireServer(kind, text)
end

--- Una linea en el registro. Se guardan las ultimas veinte.
function RadioUI.receive(data: any)
	if not log or not data then
		return
	end
	entries += 1
	local key = data.tipo == "celular" and "radio.phone" or "radio.heard"

	local line = new("TextLabel", {
		Name = "L" .. entries,
		LayoutOrder = entries,
		Text = Strings.get(key, { name = data.de or "?", text = data.texto or "" }),
		Size = UDim2.new(1, -6, 0, 30),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextSize = 12,
		TextColor3 = data.tipo == "celular" and Theme.Hud.Credit or Theme.Hud.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		ZIndex = 7,
	}, log)

	local children = log:GetChildren()
	if #children > 22 then
		for _, child in children do
			if child:IsA("TextLabel") and child.LayoutOrder <= entries - 20 then
				child:Destroy()
			end
		end
	end

	log.CanvasSize = UDim2.new(0, 0, 0, entries * 34)
	log.CanvasPosition = Vector2.new(0, math.max(0, entries * 34 - log.AbsoluteSize.Y))
	line.Parent = log
end

-- ── herramienta equipada ───────────────────────────────────────────

local function watchCharacter(character: Model)
	local function check()
		local tool = character:FindFirstChildOfClass("Tool")
		local radio = tool and tool:GetAttribute("Radio")
		kind = typeof(radio) == "string" and radio or nil
		root.Visible = kind ~= nil
		if kind then
			title.Text = Strings.get(kind == "celular" and "item.celular" or "radio.title")
		end
	end
	character.ChildAdded:Connect(check)
	character.ChildRemoved:Connect(check)
	check()
end

function RadioUI.watch()
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
end

function RadioUI.setVisible(visible: boolean)
	if root then
		root.Visible = visible and kind ~= nil
	end
end

return RadioUI

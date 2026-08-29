--!strict
--[[
	ZoomUI
	------------------------------------------------------------------
	Los prismaticos.

	Manteniendo Z se cierra el campo de vision de la camara y aparece
	la mascara de dos circulos. Mientras estas asi, apuntar a un
	companero y pulsar Q lee SU hoja desde donde estes: es espiar, pero
	a cuarenta studs.

	El cliente decide a quien apuntas (tiene la camara), el servidor
	comprueba que ese alguien exista, este en tu misma aula y dentro
	del alcance del aparato. Si el cliente miente, el servidor dice que
	no hay nadie en la mira.

	Detalle importante: el FOV se guarda y se restaura. Una camara que
	se queda con FOV 16 porque alguien solto la tecla en el frame
	equivocado deja el juego injugable.
--]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Theme = require(Shared:WaitForChild("Theme"))
local Strings = require(Shared:WaitForChild("Strings"))
local Net = require(Shared:WaitForChild("Net"))
local UI = require(Shared:WaitForChild("UI"))

local player = Players.LocalPlayer

local ZoomUI = {}

local H = Config.Herramientas

local mask: Frame
local hint: TextLabel
local equipped = false
local zoomed = false
local restoreFov = 70

--- Lo rellena el init del cliente: la pregunta que mira el alumno.
ZoomUI.currentIndex = function(): number
	return 1
end

--[[
	Adaptador al constructor compartido. Mantiene la firma posicional
	(class, props, parent) que usan las llamadas de este archivo, pero
	la logica vive una sola vez, en UI.new — antes este mismo bucle
	estaba copiado literal en nueve archivos.
--]]
local function new(class: string, props: { [string]: any }, parent: Instance?): any
	if parent then
		props.Parent = parent
	end
	return UI.new(class, props)
end

function ZoomUI.mount(parent: ScreenGui)
	mask = new("Frame", {
		Name = "Prismaticos",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = UI.Layer.Overlay,
	}, parent)

	-- Cuatro bandas negras dejan al descubierto una franja central, y
	-- dos circulos oscuros terminan de dar la forma del binocular.
	for _, edge in {
		{ UDim2.new(1, 0, 0.16, 0), UDim2.fromScale(0, 0), Vector2.new(0, 0) },
		{ UDim2.new(1, 0, 0.16, 0), UDim2.fromScale(0, 1), Vector2.new(0, 1) },
		{ UDim2.new(0.2, 0, 1, 0), UDim2.fromScale(0, 0), Vector2.new(0, 0) },
		{ UDim2.new(0.2, 0, 1, 0), UDim2.fromScale(1, 0), Vector2.new(1, 0) },
	} do
		new("Frame", {
			Size = edge[1],
			Position = edge[2],
			AnchorPoint = edge[3],
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			ZIndex = UI.Layer.Overlay,
		}, mask)
	end

	for _, side in { -1, 1 } do
		local ring = new("Frame", {
			Name = "Circulo",
			Size = UDim2.fromScale(0.34, 0.62),
			Position = UDim2.fromScale(0.5 + side * 0.16, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = UI.Layer.Overlay + 1,
		}, mask)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
		new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 90, Transparency = 0.05 }, ring)
	end

	-- Retícula.
	new("Frame", {
		Size = UDim2.fromOffset(1, 26),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(210, 230, 210),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = UI.Layer.Overlay + 2,
	}, mask)
	new("Frame", {
		Size = UDim2.fromOffset(26, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(210, 230, 210),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = UI.Layer.Overlay + 2,
	}, mask)

	hint = new("TextLabel", {
		Text = Strings.get("zoom.on"),
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromScale(0, 0.82),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		TextSize = 13,
		TextColor3 = Theme.Hud.Text,
		ZIndex = UI.Layer.Overlay + 2,
	}, mask)

	ZoomUI.bind()
end

-- ── zoom ───────────────────────────────────────────────────────────

local function setZoom(on: boolean)
	local camera = workspace.CurrentCamera
	if not camera or zoomed == on then
		return
	end
	zoomed = on
	mask.Visible = on

	if on then
		restoreFov = camera.FieldOfView
		TweenService:Create(camera, TweenInfo.new(0.22), {
			FieldOfView = H.PrismaticosFov,
		}):Play()
	else
		TweenService:Create(camera, TweenInfo.new(0.22), {
			FieldOfView = restoreFov,
		}):Play()
	end
end

--- A quien estas apuntando: se tira un rayo desde la camara y se mira
--- si lo que corta pertenece al personaje de otro jugador.
local function aimedPlayer(): Player?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: any }

	local hit = workspace:Raycast(camera.CFrame.Position,
		camera.CFrame.LookVector * (H.PrismaticosAlcance + 10), params)
	if not hit then
		return nil
	end
	local model = hit.Instance:FindFirstAncestorOfClass("Model")
	return model and Players:GetPlayerFromCharacter(model) or nil
end

function ZoomUI.read()
	if not zoomed then
		return
	end
	local target = aimedPlayer()
	if not target then
		hint.Text = Strings.get("zoom.no_target")
		task.delay(2, function()
			if hint then
				hint.Text = Strings.get("zoom.on")
			end
		end)
		return
	end
	Net.event(Net.Events.Cheat):FireServer("zoom", ZoomUI.currentIndex(), target.UserId)
end

-- ── herramienta equipada ───────────────────────────────────────────

local function watchCharacter(character: Model)
	local function check()
		local tool = character:FindFirstChildOfClass("Tool")
		equipped = tool ~= nil and tool:GetAttribute("Zoom") == true
		if not equipped then
			setZoom(false)
		end
	end
	character.ChildAdded:Connect(check)
	character.ChildRemoved:Connect(check)
	check()
end

function ZoomUI.bind()
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Z and equipped then
			setZoom(true)
		elseif input.KeyCode == Enum.KeyCode.Q and zoomed then
			ZoomUI.read()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Z then
			setZoom(false)
		end
	end)
end

function ZoomUI.isZoomed(): boolean
	return zoomed
end

function ZoomUI.setVisible(visible: boolean)
	if not visible then
		setZoom(false)
	end
end

return ZoomUI

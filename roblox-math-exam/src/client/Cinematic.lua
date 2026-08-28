--!strict
--[[
	Cinematic
	------------------------------------------------------------------
	Las cinematicas: barras negras, fundidos, movimientos de camara y
	subtitulos. Es lo que convierte el final de la prueba en el final
	de un dia.

	El servidor manda la secuencia y los puntos clave del mundo; el
	encuadre y los tiempos se arman aca, que es donde corren los frames.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Strings = require(Shared:WaitForChild("Strings"))
local Theme = require(Shared:WaitForChild("Theme"))
local Util = require(Shared:WaitForChild("Util"))

local CameraRig = require(script.Parent:WaitForChild("CameraRig"))

local player = Players.LocalPlayer
local S = Config.Story

local Cinematic = {}
Cinematic.onChoice = nil :: ((string) -> ())?
Cinematic.active = false

local refs: { [string]: any } = {}
local token = 0

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

-- ─────────────────────────────────────────────────────────────
-- Montaje
-- ─────────────────────────────────────────────────────────────

function Cinematic.mount()
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("AulaCine")
	if existing then
		existing:Destroy()
	end

	local screen = el("ScreenGui", {
		Name = "AulaCine",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 50,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	refs.screen = screen

	-- Barras de cine
	refs.topBar = el("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 5,
	}, screen)
	refs.bottomBar = el("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 5,
	}, screen)

	-- Fundido a negro
	refs.fade = el("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 8,
	}, screen)

	-- Subtitulo
	refs.subtitle = el("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -70),
		Size = UDim2.fromScale(0.7, 0.08),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = "",
		TextColor3 = Color3.fromRGB(244, 244, 240),
		TextStrokeTransparency = 0.5,
		TextScaled = true,
		TextTransparency = 1,
		ZIndex = 9,
	}, screen)

	-- Placa final
	refs.card = el("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 9,
	}, screen)

	refs.cardTitle = el("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.8, 0.1),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		Text = "",
		TextColor3 = Color3.fromRGB(246, 246, 242),
		TextScaled = true,
		TextTransparency = 1,
		ZIndex = 9,
	}, refs.card)

	refs.cardBody = el("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.54),
		Size = UDim2.fromScale(0.6, 0.16),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = "",
		TextColor3 = Color3.fromRGB(168, 172, 180),
		TextScaled = true,
		TextTransparency = 1,
		ZIndex = 9,
	}, refs.card)

	-- Botones de decision
	refs.prompt = el("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -130),
		Size = UDim2.fromOffset(560, 60),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 9,
	}, screen)
	el("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 14),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, refs.prompt)

	return screen
end

-- ─────────────────────────────────────────────────────────────
-- Piezas
-- ─────────────────────────────────────────────────────────────

local function letterbox(show: boolean)
	local height = show and UDim2.new(1, 0, 0.11, 0) or UDim2.new(1, 0, 0, 0)
	local info = TweenInfo.new(S.LetterboxTime, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	TweenService:Create(refs.topBar, info, { Size = height }):Play()
	TweenService:Create(refs.bottomBar, info, { Size = height }):Play()
end

function Cinematic.fade(to: number, duration: number)
	TweenService:Create(refs.fade, TweenInfo.new(duration), { BackgroundTransparency = 1 - to }):Play()
end

function Cinematic.line(key: string, args: { [string]: any }?, duration: number)
	if not refs.subtitle then
		return
	end
	refs.subtitle.Text = Strings.get(key, args)
	TweenService:Create(refs.subtitle, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
	local mine = token
	task.delay(duration, function()
		if token == mine and refs.subtitle then
			TweenService:Create(refs.subtitle, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
	end)
end

--- Un plano: de un encuadre a otro, con el tiempo que le des.
local function shot(from: CFrame, to: CFrame, duration: number, mine: number)
	local elapsed = 0
	while elapsed < duration do
		if token ~= mine then
			return false
		end
		elapsed += RunService.RenderStepped:Wait()
		local alpha = math.clamp(elapsed / duration, 0, 1)
		-- Suavizado en las puntas: ningun plano arranca ni frena de golpe.
		local eased = alpha * alpha * (3 - 2 * alpha)
		CameraRig.setCine(from:Lerp(to, eased))
	end
	return true
end

local function characterPivot(): CFrame?
	local character = player.Character
	return character and character:GetPivot() or nil
end

-- ─────────────────────────────────────────────────────────────
-- Secuencias
-- ─────────────────────────────────────────────────────────────

local function playDismissal(payload: any, mine: number)
	local pivot = characterPivot()
	if not pivot then
		return
	end
	local exit = payload.exit and (payload.exit :: CFrame).Position or (pivot.Position + Vector3.new(0, 0, 30))
	local toExit = (exit - pivot.Position)
	if toExit.Magnitude < 1 then
		toExit = pivot.LookVector * 20
	end
	local forward = Vector3.new(toExit.X, 0, toExit.Z).Unit
	local side = forward:Cross(Vector3.new(0, 1, 0))

	letterbox(true)
	CameraRig.setMode("cine")

	-- 1. El aula entera, desde atras del alumno
	local a1 = CFrame.lookAt(pivot.Position - forward * 9 + side * 5 + Vector3.new(0, 7, 0), pivot.Position + Vector3.new(0, 2, 0))
	local a2 = CFrame.lookAt(pivot.Position - forward * 6 + side * 2 + Vector3.new(0, 5.5, 0), pivot.Position + Vector3.new(0, 2, 0))
	if not shot(a1, a2, 4.5, mine) then
		return
	end

	-- 2. Acompañando a la salida
	local b1 = CFrame.lookAt(pivot.Position + side * 7 + Vector3.new(0, 5, 0), exit + Vector3.new(0, 2, 0))
	local b2 = CFrame.lookAt(exit - forward * 12 + side * 4 + Vector3.new(0, 5, 0), exit + Vector3.new(0, 2, 0))
	if not shot(b1, b2, 5.5, mine) then
		return
	end

	-- 3. La puerta, mirando para afuera
	local c1 = CFrame.lookAt(exit - forward * 5 + Vector3.new(0, 4, 0), exit + forward * 14 + Vector3.new(0, 2, 0))
	local c2 = CFrame.lookAt(exit + forward * 3 + Vector3.new(0, 4.5, 0), exit + forward * 20 + Vector3.new(0, 2, 0))
	shot(c1, c2, 6, mine)
end

local function playHome(payload: any, mine: number)
	letterbox(true)
	CameraRig.setMode("cine")
	CameraRig.setCine(payload.wide)
	Cinematic.fade(0, S.FadeTime)

	local wide = payload.wide :: CFrame
	local close = payload.close :: CFrame
	if not shot(wide, wide * CFrame.new(0, 0, -3), 4.5, mine) then
		return
	end
	shot(close * CFrame.new(0, 0, 4), close, 4, mine)
end

local function playEpilogue(payload: any, mine: number)
	letterbox(false)
	Cinematic.fade(1, 1.4)
	task.wait(1.5)
	if token ~= mine then
		return
	end

	refs.card.Visible = true
	refs.cardTitle.Text = Strings.get(payload.titleKey or "story.epilogue.title")
	refs.cardBody.Text = table.concat({
		Strings.get("story.epilogue.grade", { grade = payload.grade }),
		Strings.get("story.epilogue.cheated", { count = payload.cheated }),
		Strings.get("story.epilogue.caught", { count = payload.caught }),
		"",
		Strings.get("story.epilogue.again"),
	}, "\n")

	TweenService:Create(refs.cardTitle, TweenInfo.new(1.6), { TextTransparency = 0 }):Play()
	task.wait(1)
	TweenService:Create(refs.cardBody, TweenInfo.new(1.6), { TextTransparency = 0 }):Play()
end

local function showPrompt(payload: any)
	for _, child in refs.prompt:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	for index, option in payload.options do
		local button = el("TextButton", {
			LayoutOrder = index,
			Size = UDim2.fromOffset(250, 54),
			BackgroundColor3 = Theme.Menu.Panel,
			BackgroundTransparency = 0.1,
			AutoButtonColor = false,
			Font = Theme.FontBold,
			Text = Strings.get(option.key),
			TextColor3 = Theme.Menu.Text,
			TextSize = 18,
			BorderSizePixel = 0,
			ZIndex = 9,
		}, refs.prompt)
		Util.roundify(button, 10, Theme.Menu.Line, 1)

		button.MouseButton1Click:Connect(function()
			refs.prompt.Visible = false
			if Cinematic.onChoice then
				Cinematic.onChoice(option.id)
			end
		end)
	end

	refs.prompt.Visible = true
end

function Cinematic.clear()
	token += 1
	Cinematic.active = false
	letterbox(false)
	Cinematic.fade(0, 0.8)
	if refs.card then
		refs.card.Visible = false
		refs.cardTitle.TextTransparency = 1
		refs.cardBody.TextTransparency = 1
	end
	if refs.prompt then
		refs.prompt.Visible = false
	end
	if refs.subtitle then
		refs.subtitle.TextTransparency = 1
	end
	CameraRig.setCine(nil)
	CameraRig.setMode("libre")
end

--- Punto de entrada: el servidor dice que secuencia va.
function Cinematic.handle(payload: any)
	if not refs.screen or typeof(payload) ~= "table" then
		return
	end

	if payload.sequence == "prompt" then
		showPrompt(payload)
		return
	end

	token += 1
	local mine = token
	Cinematic.active = true

	if payload.sequence == "fade" then
		Cinematic.fade(payload.to or 1, payload.duration or S.FadeTime)
	elseif payload.sequence == "salida" then
		task.spawn(playDismissal, payload, mine)
	elseif payload.sequence == "casa" then
		task.spawn(playHome, payload, mine)
	elseif payload.sequence == "epilogo" then
		task.spawn(playEpilogue, payload, mine)
	elseif payload.sequence == "libre" then
		Cinematic.clear()
	end
end

return Cinematic

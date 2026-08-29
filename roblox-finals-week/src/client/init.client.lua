--!strict
--[[
	Cliente — arranque de Finals Week
	------------------------------------------------------------------
	Monta la interfaz, engancha los remotes y traduce todo al idioma
	que el jugador tiene puesto en Roblox.

	Un solo ScreenGui con ResetOnSpawn = false: si el HUD se
	reconstruyera en cada respawn perderiamos el estado del examen
	justo cuando mas importa.
--]]

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
local Net = require(Shared:WaitForChild("Net"))
local Strings = require(Shared:WaitForChild("Strings"))
local UI = require(Shared:WaitForChild("UI"))

local Hud = require(script:WaitForChild("Hud"))
local ExamUI = require(script:WaitForChild("ExamUI"))
local NoteUI = require(script:WaitForChild("NoteUI"))
local ShopUI = require(script:WaitForChild("ShopUI"))
local MainMenu = require(script:WaitForChild("MainMenu"))
local LobbyUI = require(script:WaitForChild("LobbyUI"))
local CameraDirector = require(script:WaitForChild("CameraDirector"))
local Music = require(script:WaitForChild("Music"))
local Poses = require(script:WaitForChild("Poses"))
local GraffitiUI = require(script:WaitForChild("GraffitiUI"))
local RadioUI = require(script:WaitForChild("RadioUI"))
local ZoomUI = require(script:WaitForChild("ZoomUI"))
local Viewmodel = require(script:WaitForChild("Viewmodel"))

-- ── idioma ─────────────────────────────────────────────────────────
-- Cada jugador ve el juego en SU idioma: el servidor manda claves.
do
	local ok, locale = pcall(function()
		return LocalizationService.RobloxLocaleId
	end)
	Strings.setLocale(ok and locale or "en")
end

-- ── raiz de la interfaz ────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name = "FinalsWeek"
gui.ResetOnSpawn = false
-- En false, el panel del reloj (arriba y al centro, a 12 px del borde)
-- quedaba tapado por la barra superior del propio Roblox.
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

-- Toda la interfaz esta medida en pixeles contra un diseno de 1280x720.
-- Este UIScale la ajusta al viewport real: sin el, el lobby de 720 px de
-- ancho se sale de la pantalla en un telefono.
UI.responsive(gui)

-- Grupo de sonido para que el deslizador de volumen mande sobre todo.
if not SoundService:FindFirstChild("Master") then
	local group = Instance.new("SoundGroup")
	group.Name = "Master"
	group.Volume = 0.6
	group.Parent = SoundService
end

CameraDirector.mount(gui)
Poses.mount()
Hud.mount(gui)
ExamUI.mount(gui)
NoteUI.mount(gui)
ShopUI.mount(gui)
LobbyUI.mount(gui)
GraffitiUI.mount(gui)
RadioUI.mount(gui)
ZoomUI.mount(gui)
MainMenu.mount(gui)
-- Primera persona con brazos propios, como el juego real.
Viewmodel.mount()
Music.start()

ExamUI.onNotify = Hud.notify
ShopUI.onNotify = Hud.notify
LobbyUI.onNotify = Hud.notify
ExamUI.onWrite = function()
	Poses.write()
end
NoteUI.onThrow = function()
	Poses.throw()
end
-- Los prismaticos espian la pregunta que estas mirando en la hoja.
ZoomUI.currentIndex = ExamUI.currentIndex

-- Chat de proximidad: las burbujas arriba de la cabeza son lo que hace
-- que hablar en el pasillo se sienta cara a cara. Va en pcall porque la
-- configuracion cambio de lugar entre versiones del motor.
pcall(function()
	local TextChatService = game:GetService("TextChatService")
	local bubbles = TextChatService:FindFirstChildOfClass("BubbleChatConfiguration")
	if bubbles then
		bubbles.Enabled = true
		bubbles.MaxDistance = 45
		bubbles.TextSize = 17
	end
end)

-- ── menu ───────────────────────────────────────────────────────────

MainMenu.onVisible = function(open: boolean)
	Hud.setVisible(not open)
	ExamUI.setVisible(not open)
	NoteUI.setVisible(not open)
	GraffitiUI.setVisible(not open)
	RadioUI.setVisible(not open)
	ZoomUI.setVisible(not open)
	-- El menu se queda con la camara para la toma del atrio: los brazos
	-- flotando en el medio del encuadre arruinarian la pantalla de
	-- titulo.
	Viewmodel.setVisible(not open)
	if open then
		ShopUI.close()
		LobbyUI.close()
	end
end
MainMenu.onRooms = function()
	LobbyUI.open()
end
-- La tienda y el lobby viven en UI.Layer.Modal (200), por encima del
-- menu (100): se abren *sobre* el menu en vez de detras, que es lo que
-- pasaba cuando la tienda estaba fija en ZIndex 12 y el scrim en 20.
MainMenu.onShop = function()
	ShopUI.open()
end
MainMenu.onMusic = function(on: boolean)
	Music.setEnabled(on)
end

--[[
	Antes esto era una funcion vacia: el boton "Jugar" solo cerraba el
	menu y el modo lo elegia `MainMenu.close` por su cuenta, siempre
	"publico". Ahora la eleccion llega hasta el servidor.
--]]
MainMenu.onPlay = function(mode: string)
	task.spawn(function()
		pcall(function()
			Net.func(Net.Functions.ChooseMode):InvokeServer(mode)
		end)
	end)
end

-- ── remotes ────────────────────────────────────────────────────────

local lastPhase = "espera"

Net.event(Net.Events.RoundUpdate).OnClientEvent:Connect(function(data)
	Hud.setRound(data)

	if data.fase ~= lastPhase then
		local previous = lastPhase
		lastPhase = data.fase

		-- El fundido tapa el teletransporte al pupitre y la vuelta.
		if data.fase == "examen" or (previous == "examen" and data.fase == "boletin") then
			CameraDirector.transition()
		end

		if data.fase == "examen" then
			Music.setClimate("examen")
		elseif data.fase == "recreo" then
			Music.setClimate("pasillo")
		else
			Music.setClimate("pasillo")
		end
	end
end)

Net.event(Net.Events.ExamUpdate).OnClientEvent:Connect(function(data)
	ExamUI.setState(data)
end)

Net.event(Net.Events.SuspicionUpdate).OnClientEvent:Connect(function(data)
	Hud.setSuspicion(data)
	-- La musica sigue la sospecha: es el aviso que se escucha antes de
	-- que el jugador llegue a mirar la barra.
	if lastPhase == "examen" then
		local value = data.valor or 0
		if value >= 0.75 then
			Music.setClimate("persecucion")
		elseif value >= 0.45 or data.cerca then
			Music.setClimate("tension")
		else
			Music.setClimate("examen")
		end
	end
end)

Net.event(Net.Events.Notify).OnClientEvent:Connect(function(packet)
	Hud.notify(packet)
end)

Net.event(Net.Events.TeacherSay).OnClientEvent:Connect(function(packet)
	Hud.teacherSay(packet)
end)

Net.event(Net.Events.Punish).OnClientEvent:Connect(function(data)
	Hud.punish(data)
	if data.tipo == "expulsion" then
		CameraDirector.transition()
		CameraDirector.shake(1.2, 0.8)
	elseif data.tipo == "cono" then
		CameraDirector.shake(0.8, 0.6)
	end
end)

Net.event(Net.Events.Wallet).OnClientEvent:Connect(function(data)
	Hud.setWallet(data)
	ShopUI.setWallet(data)
	if data.abrir then
		ShopUI.open()
	end
end)

Net.event(Net.Events.Report).OnClientEvent:Connect(function(data)
	Hud.report(data)
end)

Net.event(Net.Events.NoteReceived).OnClientEvent:Connect(function(data)
	NoteUI.received(data)
end)

Net.event(Net.Events.Radio).OnClientEvent:Connect(function(data)
	RadioUI.receive(data)
end)

Net.event(Net.Events.Stunned).OnClientEvent:Connect(function(data)
	-- Te tiraron al piso o te pego la goma: sacudida y aviso. El
	-- control del personaje lo bloquea el servidor con PlatformStand,
	-- aca solo se acusa el golpe.
	CameraDirector.shake(data.motivo == "ko" and 1.6 or 0.9, 0.7)
	Hud.punish({ tipo = "aturdido", segundos = data.segundos })
end)

Net.event(Net.Events.Score).OnClientEvent:Connect(function(data)
	Hud.setScore(data)
end)

Net.event(Net.Events.Music).OnClientEvent:Connect(function(data)
	if data and data.clima then
		Music.setClimate(data.clima)
	end
end)

-- ── atajos ─────────────────────────────────────────────────────────

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or MainMenu.isOpen() then
		return
	end
	if input.KeyCode == Enum.KeyCode.Q then
		-- Con los prismaticos en la mira, Q lo maneja ZoomUI.
		if not ZoomUI.isZoomed() then
			Net.event(Net.Events.Cheat):FireServer("peek", ExamUI.currentIndex())
		end
	elseif input.KeyCode == Enum.KeyCode.R then
		Net.event(Net.Events.Cheat):FireServer("whisper", ExamUI.currentIndex())
	elseif input.KeyCode == Enum.KeyCode.G then
		Net.event(Net.Events.Knock):FireServer()
		Poses.throw(0.35)
	elseif input.KeyCode == Enum.KeyCode.B then
		local camera = workspace.CurrentCamera
		if camera then
			Net.event(Net.Events.Ball):FireServer("shoot", camera.CFrame.LookVector)
			Poses.throw(0.5)
		end
	elseif input.KeyCode == Enum.KeyCode.H then
		-- Leer el libro que llevas en la mano.
		Net.event(Net.Events.Cheat):FireServer("book", 1)
	elseif input.KeyCode == Enum.KeyCode.T then
		if ShopUI.isOpen() then
			ShopUI.close()
		else
			ShopUI.open()
		end
	end
end)

-- ── sentado / de pie ───────────────────────────────────────────────

local function watchSeat(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
			CameraDirector.setSeated(humanoid.SeatPart ~= nil)
		end)
	end
end

if player.Character then
	task.spawn(watchSeat, player.Character)
end
player.CharacterAdded:Connect(function(character)
	task.spawn(watchSeat, character)
end)

-- ── bucle de dibujo ────────────────────────────────────────────────

RunService.RenderStepped:Connect(function()
	ExamUI.step()
end)

-- ── estado inicial ─────────────────────────────────────────────────

task.spawn(function()
	local ok, state = pcall(function()
		return Net.func(Net.Functions.GetState):InvokeServer()
	end)
	if ok and state then
		if state.billetera then
			Hud.setWallet(state.billetera)
			ShopUI.setWallet(state.billetera)
		end
		if state.examen then
			ExamUI.setState(state.examen)
		end
	end
	MainMenu.open()
end)

print(string.format("[Finals Week] Cliente listo (%s).", Strings.locale()))

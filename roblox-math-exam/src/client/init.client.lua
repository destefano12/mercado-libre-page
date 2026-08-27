--!strict
--[[
	CLIENTE — punto de entrada
	------------------------------------------------------------------
	Une las piezas: menu de inicio, la hoja 3D del banco, el celular 3D
	con RoGPT y el HUD de acciones. Toda la logica sensible (respuestas
	correctas, bateria, riesgo) vive en el servidor; aca solo se
	presenta y se pide.

	El idioma sale del Roblox de cada jugador y se puede forzar desde
	Ajustes. Nada de texto del servidor llega ya escrito: llegan claves.

	Controles:
		E  -> acercar la camara a la hoja
		F  -> sacar / usar el celular  (mismo boton grande de abajo)
		Q  -> guardar el celular
		M  -> abrir el menu
--]]

local ContextActionService = game:GetService("ContextActionService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Strings = require(Shared:WaitForChild("Strings"))
local Util = require(Shared:WaitForChild("Util"))

local CameraRig = require(script:WaitForChild("CameraRig"))
local Hud = require(script:WaitForChild("Hud"))
local MainMenu = require(script:WaitForChild("MainMenu"))
local PaperUI = require(script:WaitForChild("PaperUI"))
local PhoneUI = require(script:WaitForChild("PhoneUI"))
local TeacherBubble = require(script:WaitForChild("TeacherBubble"))

local player = Players.LocalPlayer

local state = {
	phoneOut = false,
	busy = false,
	phase = "Preparacion",
	started = false,
	paper = nil :: BasePart?,
	screen = nil :: BasePart?,
	phoneState = { battery = 100, out = false, confiscated = false, confiscatedFor = 0 },
}

-- ─────────────────────────────────────────────────────────────
-- Idioma
-- ─────────────────────────────────────────────────────────────

local function resolveLocale()
	local choice = MainMenu.settings.locale
	if choice == "auto" then
		local ok, id = pcall(function()
			return LocalizationService.RobloxLocaleId
		end)
		Strings.setLocale(ok and id or nil)
	else
		Strings.setLocale(choice)
	end
end

local function refreshAllTexts()
	Hud.refreshTexts()
	MainMenu.refreshTexts()
	PaperUI.render()
	PhoneUI.refreshTexts()
end

-- ─────────────────────────────────────────────────────────────
-- Encontrar mi banco y mi celular
-- ─────────────────────────────────────────────────────────────

local function findMyPaper(): BasePart?
	local classroom = workspace:FindFirstChild("Aula")
	local desks = classroom and classroom:FindFirstChild("Bancos")
	if not desks then
		return nil
	end
	for _, desk in desks:GetChildren() do
		local paper = desk:FindFirstChild("HojaDePrueba") :: BasePart?
		if paper and paper:GetAttribute("OwnerUserId") == player.UserId then
			return paper
		end
	end
	return nil
end

local function bindPaper()
	local paper = findMyPaper()
	if not paper or paper == state.paper then
		return
	end
	state.paper = paper
	CameraRig.setPaper(paper)
	PaperUI.mount(paper)
	if PaperUI.snapshot then
		PaperUI.render()
	end
end

local function bindPhone(character: Model)
	local phone = character:FindFirstChild("Celular")
	local screen = phone and phone:FindFirstChild("Pantalla") :: BasePart?
	if not screen or screen == state.screen then
		return
	end
	state.screen = screen
	CameraRig.setScreen(screen)
	PhoneUI.mount(screen)
	PhoneUI.setPhoneState(state.phoneState)
end

local function watchCharacter(character: Model)
	bindPhone(character)
	character.ChildAdded:Connect(function(child)
		if child.Name == "Celular" then
			task.wait(0.1)
			bindPhone(character)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child.Name == "Celular" then
			state.screen = nil
			CameraRig.setScreen(nil)
			PhoneUI.destroy()
			if state.phoneOut then
				state.phoneOut = false
				Hud.setPhoneOut(false)
				CameraRig.setMode("libre")
			end
		end
	end)
end

-- ─────────────────────────────────────────────────────────────
-- Acciones
-- ─────────────────────────────────────────────────────────────

local function reasonText(reason: any, fallback: string): string
	if typeof(reason) == "table" and reason.key then
		return Strings.get(reason.key, reason.args)
	end
	return Strings.get(fallback)
end

local function setPhoneOut(out: boolean)
	if state.phoneOut == out then
		return
	end
	state.phoneOut = out
	Net.event(Net.Events.PhoneState):FireServer(out)
	Hud.setPhoneOut(out)

	if out then
		PhoneUI.reset()
		Hud.setHasPhoto(false)
		CameraRig.setMode("celu")
		Util.playSound(Config.Sounds.PhoneOut, workspace, 0.4)
	else
		CameraRig.setMode("libre")
	end
end

local function takePhoto()
	if state.busy or not state.phoneOut then
		return
	end
	local questionId = PaperUI.current
	state.busy = true
	PhoneUI.setBusy(true)

	-- Gesto completo: apuntás el celu a la hoja, flash, y volvés a la pantalla.
	CameraRig.setMode("hoja")
	task.wait(0.28)
	Hud.flash("", Color3.fromRGB(255, 255, 255))
	Util.playSound(Config.Sounds.Shutter, workspace, 0.5)
	task.wait(0.18)
	CameraRig.setMode("celu")

	local response = Net.func(Net.Functions.TakePhoto):InvokeServer(questionId)
	state.busy = false
	PhoneUI.setBusy(false)

	if not response or not response.ok then
		PhoneUI.system(reasonText(response and response.reason, "phone.error.photo"))
		return
	end

	PhoneUI.photo(response)
	PhoneUI.setPendingPhoto(response)
	Hud.setHasPhoto(true)
end

local function sendToRoGPT()
	local photo = PhoneUI.getPendingPhoto()
	if state.busy or not photo then
		return
	end
	state.busy = true
	PhoneUI.setBusy(true)
	PhoneUI.setPendingPhoto(nil)
	Hud.setHasPhoto(false)

	PhoneUI.system(Strings.get("phone.uploading", { id = photo.photoId }))
	Util.playSound(Config.Sounds.Send, workspace, 0.4)
	task.wait(photo.uploadTime or 0.8)

	local _, dismiss = PhoneUI.typing()
	local response = Net.func(Net.Functions.AskRoGPT):InvokeServer(photo.photoId)

	if not response or not response.ok then
		dismiss()
		PhoneUI.system(reasonText(response and response.reason, "phone.error.generic"))
		state.busy = false
		PhoneUI.setBusy(false)
		return
	end

	task.wait(response.thinkTime or 1.5)
	dismiss()
	Util.playSound(Config.Sounds.Reply, workspace, 0.4)
	PhoneUI.answer(response)

	state.busy = false
	PhoneUI.setBusy(false)
end

--- El boton grande de abajo cambia segun el momento.
local function primaryAction()
	if MainMenu.open then
		return
	end
	if state.phoneState.confiscated then
		Hud.notify("notify.confiscated", "warn")
		return
	end
	if state.phase ~= "Prueba" then
		Hud.notify("notify.notStarted", "info")
		return
	end
	if not state.phoneOut then
		setPhoneOut(true)
		return
	end
	if PhoneUI.getPendingPhoto() then
		task.spawn(sendToRoGPT)
		return
	end
	task.spawn(takePhoto)
end

local function stashPhone()
	if state.phoneOut then
		setPhoneOut(false)
	end
end

local function togglePaper()
	if MainMenu.open then
		return
	end
	CameraRig.toggle("hoja")
end

-- ─────────────────────────────────────────────────────────────
-- Menu
-- ─────────────────────────────────────────────────────────────

local function openMenu()
	MainMenu.show()
	stashPhone()
	CameraRig.setMode("menu")
	Hud.setVisible(false)
	TeacherBubble.hide()
end

local function closeMenu()
	MainMenu.hide()
	CameraRig.setMode("libre")
	Hud.setVisible(true)
	state.started = true
end

-- ─────────────────────────────────────────────────────────────
-- Montaje
-- ─────────────────────────────────────────────────────────────

resolveLocale()

-- Cada pieza de interfaz se monta aislada: si una falla, el resto del
-- juego (los controles, los remotes) tiene que seguir andando.
local function safely(name: string, run: () -> ())
	local ok, err = pcall(run)
	if not ok then
		warn(string.format("[Aula] Fallo %s: %s", name, tostring(err)))
	end
end

safely("el HUD", function()
	Hud.mount()
	Hud.setVisible(false)
end)
safely("la camara", CameraRig.start)
safely("el menu", function()
	MainMenu.mount()
	-- El menu arranca con el aula girando de fondo, no con la camara del
	-- personaje detras de un panel oscuro.
	CameraRig.setMode("menu")
end)

Hud.onPrimary = primaryAction
Hud.onStash = stashPhone
Hud.onPaper = togglePaper
Hud.onMenu = openMenu

MainMenu.onPlay = closeMenu
MainMenu.onLocaleChanged = function()
	resolveLocale()
	refreshAllTexts()
end

MainMenu.onMode = function(mode: string)
	if mode == "public" then
		MainMenu.setModeStatus(Strings.get("menu.mode.current"))
		return
	end
	MainMenu.setModeStatus(Strings.get("menu.mode.moving"))
	task.spawn(function()
		local response = Net.func(Net.Functions.ChooseMode):InvokeServer(mode)
		if not response or not response.ok then
			MainMenu.setModeStatus(reasonText(response and response.reason, "menu.mode.unavailable"))
		end
	end)
end

MainMenu.onInvite = function()
	task.spawn(function()
		local can = false
		pcall(function()
			can = SocialService:CanSendGameInviteAsync(player)
		end)
		if can then
			pcall(function()
				SocialService:PromptGameInvite(player)
			end)
		else
			MainMenu.setModeStatus(Strings.get("menu.mode.unavailable"))
		end
	end)
end

PhoneUI.onTakePhoto = function()
	task.spawn(takePhoto)
end
PhoneUI.onSend = function()
	task.spawn(sendToRoGPT)
end
PhoneUI.onClose = stashPhone

PaperUI.onAnswer = function(questionId: number, choice: number)
	if state.phase ~= "Prueba" then
		Hud.notify("notify.notRunning", "info")
		return
	end
	task.spawn(function()
		local response = Net.func(Net.Functions.SubmitAnswer):InvokeServer(questionId, choice)
		if not response or not response.ok then
			Hud.notify("notify.answerFailed", "warn")
			return
		end
		if response.correct then
			Util.playSound(Config.Sounds.Correct, workspace, 0.45)
			Hud.notify("notify.correct", "success")
		else
			Util.playSound(Config.Sounds.Wrong, workspace, 0.45)
			Hud.notify("notify.wrong", "warn")
		end
		if response.finished then
			Hud.notify("notify.finished", "info", { grade = string.format("%.1f", response.grade) })
		end
	end)
end

-- ─────────────────────────────────────────────────────────────
-- Remotes
-- ─────────────────────────────────────────────────────────────

Net.event(Net.Events.ExamUpdate).OnClientEvent:Connect(function(snapshot)
	bindPaper()
	PaperUI.setSnapshot(snapshot)
	Hud.setExam(snapshot)
end)

Net.event(Net.Events.RiskUpdate).OnClientEvent:Connect(function(data)
	Hud.setRisk(data)
end)

Net.event(Net.Events.RoundUpdate).OnClientEvent:Connect(function(data)
	state.phase = data.phase
	Hud.setRound(data)
	if data.phase ~= "Prueba" and state.phoneOut then
		setPhoneOut(false)
	end
	if data.phase == "Prueba" then
		task.delay(1, bindPaper)
	end
end)

Net.event(Net.Events.PhoneState).OnClientEvent:Connect(function(data)
	state.phoneState = data
	PhoneUI.setPhoneState(data)
	Hud.setPhoneState(data)
	if not data.out and state.phoneOut then
		-- El servidor lo guardo por su cuenta (bateria, confiscacion, ronda).
		state.phoneOut = false
		Hud.setPhoneOut(false)
		CameraRig.setMode("libre")
	end
end)

Net.event(Net.Events.Notify).OnClientEvent:Connect(function(data)
	Hud.notify(data.key, data.kind, data.args)
end)

Net.event(Net.Events.TeacherSay).OnClientEvent:Connect(function(data)
	if not MainMenu.open then
		TeacherBubble.say(data.key, data.duration)
	end
end)

Net.event(Net.Events.Caught).OnClientEvent:Connect(function(data)
	state.phoneOut = false
	Hud.setPhoneOut(false)
	Hud.setHasPhoto(false)
	CameraRig.setMode("libre")
	PhoneUI.reset()
	Util.playSound(Config.Sounds.Caught, workspace, 0.6)
	Hud.flash(Strings.get(data.expelled and "hud.flash.expelled" or "hud.flash.caught"))
end)

-- ─────────────────────────────────────────────────────────────
-- Teclado / gamepad
-- ─────────────────────────────────────────────────────────────

local function bind(name: string, callback: () -> (), ...)
	ContextActionService:BindAction(name, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			callback()
		end
		return Enum.ContextActionResult.Sink
	end, false, ...)
end

bind("AulaCelular", primaryAction, Enum.KeyCode.F, Enum.KeyCode.ButtonX)
bind("AulaGuardar", stashPhone, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
bind("AulaHoja", togglePaper, Enum.KeyCode.E, Enum.KeyCode.ButtonY)
bind("AulaMenu", function()
	if MainMenu.open then
		closeMenu()
	else
		openMenu()
	end
end, Enum.KeyCode.M, Enum.KeyCode.ButtonStart)

-- ─────────────────────────────────────────────────────────────
-- Personaje
-- ─────────────────────────────────────────────────────────────

if player.Character then
	watchCharacter(player.Character)
end
player.CharacterAdded:Connect(function(character)
	task.wait(0.5)
	watchCharacter(character)
	bindPaper()
end)

-- Reloj del celular, para que la barra de estado no quede muerta.
task.spawn(function()
	while true do
		local now = os.date("*t")
		PhoneUI.setClock(string.format("%02d:%02d", now.hour, now.min))
		task.wait(20)
	end
end)

-- Primer estado
task.spawn(function()
	local snapshot = Net.func(Net.Functions.GetExam):InvokeServer()
	bindPaper()
	if snapshot then
		PaperUI.setSnapshot(snapshot)
		Hud.setExam(snapshot)
	end
end)

-- El banco puede tardar en asignarse (por ejemplo si entraste tarde), y
-- el menu necesita saber a donde apuntar la camara.
task.spawn(function()
	while not state.paper do
		bindPaper()
		local classroom = workspace:FindFirstChild("Aula")
		if classroom then
			local board = classroom:FindFirstChild("Pizarron")
			if board and board:IsA("BasePart") then
				CameraRig.setMenuFocus(board.Position + Vector3.new(0, -2, 18))
			end
		end
		task.wait(1)
	end
end)

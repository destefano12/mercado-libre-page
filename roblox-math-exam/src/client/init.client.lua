--!strict
--[[
	CLIENTE — punto de entrada
	------------------------------------------------------------------
	Une las tres piezas: la hoja 3D del banco, el celular 3D con RoGPT
	y el HUD de acciones. Toda la logica sensible (respuestas correctas,
	bateria, riesgo) vive en el servidor; aca solo se presenta y se pide.

	Controles:
		E  -> acercar la camara a la hoja
		F  -> sacar / usar el celular  (mismo boton grande de abajo)
		Q  -> guardar el celular
--]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local CameraRig = require(script:WaitForChild("CameraRig"))
local Hud = require(script:WaitForChild("Hud"))
local PaperUI = require(script:WaitForChild("PaperUI"))
local PhoneUI = require(script:WaitForChild("PhoneUI"))

local player = Players.LocalPlayer

local state = {
	phoneOut = false,
	busy = false,
	phase = "Preparacion",
	paper = nil :: BasePart?,
	screen = nil :: BasePart?,
	phoneState = { battery = 100, out = false, confiscated = false, confiscatedFor = 0 },
}

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

local function setPhoneOut(out: boolean)
	if state.phoneOut == out then
		return
	end
	state.phoneOut = out
	Net.event(Net.Events.PhoneState):FireServer(out)
	Hud.setPhoneOut(out)

	if out then
		PhoneUI.reset()
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
		PhoneUI.system(response and response.reason or "No se pudo sacar la foto.")
		return
	end

	PhoneUI.photo(response)
	PhoneUI.setPendingPhoto(response)
	Hud.refreshPrimary()
end

local function sendToRoGPT()
	local photo = PhoneUI.getPendingPhoto()
	if state.busy or not photo then
		return
	end
	state.busy = true
	PhoneUI.setBusy(true)
	PhoneUI.setPendingPhoto(nil)

	PhoneUI.system(string.format("Subiendo %s ...", photo.photoId))
	Util.playSound(Config.Sounds.Send, workspace, 0.4)
	task.wait(photo.uploadTime or 0.8)

	local _, dismiss = PhoneUI.typing()
	local response = Net.func(Net.Functions.AskRoGPT):InvokeServer(photo.photoId)

	if not response or not response.ok then
		dismiss()
		PhoneUI.system(response and response.reason or "RoGPT no contesta.")
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
	Hud.refreshPrimary()
end

--- El boton grande de abajo cambia segun el momento.
local function primaryAction()
	if state.phoneState.confiscated then
		Hud.notify("El profe te lo saco. Bancá un poco.", "warn")
		return
	end
	if state.phase ~= "Prueba" then
		Hud.notify("Todavia no empezo la prueba.", "info")
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
	CameraRig.toggle("hoja")
end

-- ─────────────────────────────────────────────────────────────
-- Montaje
-- ─────────────────────────────────────────────────────────────

Hud.mount()
CameraRig.start()

Hud.onPrimary = primaryAction
Hud.onStash = stashPhone
Hud.onPaper = togglePaper

PhoneUI.onTakePhoto = function()
	task.spawn(takePhoto)
end
PhoneUI.onSend = function()
	task.spawn(sendToRoGPT)
end
PhoneUI.onClose = stashPhone

PaperUI.onAnswer = function(questionId: number, choice: number)
	if state.phase ~= "Prueba" then
		Hud.notify("La prueba no esta en curso.", "info")
		return
	end
	task.spawn(function()
		local response = Net.func(Net.Functions.SubmitAnswer):InvokeServer(questionId, choice)
		if not response or not response.ok then
			Hud.notify(response and response.reason or "No se pudo responder.", "warn")
			return
		end
		if response.correct then
			Util.playSound(Config.Sounds.Correct, workspace, 0.45)
			Hud.notify("Correcto.", "success")
		else
			Util.playSound(Config.Sounds.Wrong, workspace, 0.45)
			Hud.notify("Ese estaba mal.", "warn")
		end
		if response.finished then
			Hud.notify(string.format("Entregaste la prueba. Nota: %.1f", response.grade), "info")
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
	Hud.notify(data.text, data.kind)
end)

Net.event(Net.Events.Caught).OnClientEvent:Connect(function(data)
	state.phoneOut = false
	Hud.setPhoneOut(false)
	CameraRig.setMode("libre")
	PhoneUI.reset()
	Util.playSound(Config.Sounds.Caught, workspace, 0.6)
	Hud.flash(data.expelled and "TE SACARON DE LA PRUEBA" or "TE PILLARON")
end)

-- ─────────────────────────────────────────────────────────────
-- Teclado / gamepad
-- ─────────────────────────────────────────────────────────────

ContextActionService:BindAction("AulaCelular", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		primaryAction()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonX)

ContextActionService:BindAction("AulaGuardar", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		stashPhone()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)

ContextActionService:BindAction("AulaHoja", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		togglePaper()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonY)

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

-- El banco puede tardar en asignarse (por ejemplo si entraste tarde).
task.spawn(function()
	while not state.paper do
		bindPaper()
		task.wait(1)
	end
end)

--!strict
--[[
	CameraRig
	------------------------------------------------------------------
	Cuatro encuadres, todos en 3D adentro del aula:

		"libre"  -> camara normal de Roblox
		"hoja"   -> mirás la hoja, desde tus propios ojos
		"celu"   -> mirás el celular, desde tus propios ojos
		"menu"   -> paneo lento del aula, para el menu de inicio

	Ojo con "hoja" y "celu": la camara se planta un poco ADELANTE de la
	cara y apunta al objeto. Anclarla al objeto y tirarla para atras
	(que fue el primer intento) la mete adentro de tu propia cabeza y no
	se ve nada.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local player = Players.LocalPlayer

local CameraRig = {}
CameraRig.mode = "libre"

local camera = workspace.CurrentCamera
local paperPart: BasePart? = nil
local screenPart: BasePart? = nil
local menuFocus: Vector3? = nil
local current: CFrame? = nil

function CameraRig.setPaper(part: BasePart?)
	paperPart = part
end

function CameraRig.setScreen(part: BasePart?)
	screenPart = part
end

function CameraRig.setMenuFocus(position: Vector3?)
	menuFocus = position
end

function CameraRig.setMode(mode: string)
	if CameraRig.mode == mode then
		return
	end
	CameraRig.mode = mode
end

function CameraRig.toggle(mode: string)
	CameraRig.setMode(CameraRig.mode == mode and "libre" or mode)
end

local function head(): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	return (character:FindFirstChild("Head") :: BasePart?)
		or (character:FindFirstChild("HumanoidRootPart") :: BasePart?)
end

--- Camara a la altura de los ojos, apenas adelante de la cara, mirando
--- al objeto. Es como mirás una hoja o el celular en la vida real.
local function eyesOn(target: BasePart): CFrame?
	local reference = head()
	if not reference then
		return nil
	end
	local origin = reference.CFrame * Config.Camera.EyeOffset
	local direction = target.Position - origin.Position
	if direction.Magnitude < 0.05 then
		return nil
	end
	return CFrame.lookAt(origin.Position, target.Position)
end

local function goalCFrame(): (CFrame?, number)
	if CameraRig.mode == "menu" then
		local focus = menuFocus or Vector3.new(0, 8, 24)
		local angle = os.clock() * 0.08
		local radius = 34
		local origin = focus + Vector3.new(math.cos(angle) * radius, 9, math.sin(angle) * radius)
		return CFrame.lookAt(origin, focus + Vector3.new(0, 2, 0)), Config.Camera.MenuFieldOfView
	end

	if CameraRig.mode == "celu" and screenPart and screenPart.Parent then
		return eyesOn(screenPart), Config.Camera.PhoneFieldOfView
	end

	if CameraRig.mode == "hoja" and paperPart and paperPart.Parent then
		return eyesOn(paperPart), Config.Camera.PaperFieldOfView
	end

	return nil, Config.Camera.FieldOfView
end

function CameraRig.start()
	camera = workspace.CurrentCamera

	RunService:BindToRenderStep("AulaCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		camera = workspace.CurrentCamera
		if not camera then
			return
		end

		local goal, fov = goalCFrame()
		local alpha = math.clamp(dt / Config.Camera.BlendTime, 0, 1)

		if goal then
			if camera.CameraType ~= Enum.CameraType.Scriptable then
				camera.CameraType = Enum.CameraType.Scriptable
				current = camera.CFrame
			end
			-- El menu arranca ya en su lugar; los encuadres de juego entran
			-- con un blend corto para que no haya corte seco.
			current = (current or goal):Lerp(goal, CameraRig.mode == "menu" and 1 or alpha)
			camera.CFrame = current
		else
			if camera.CameraType == Enum.CameraType.Scriptable then
				camera.CameraType = Enum.CameraType.Custom
				local character = player.Character
				camera.CameraSubject = character and character:FindFirstChildOfClass("Humanoid")
				current = nil
			end
		end

		camera.FieldOfView += (fov - camera.FieldOfView) * alpha
	end)
end

function CameraRig.stop()
	RunService:UnbindFromRenderStep("AulaCamera")
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
end

return CameraRig

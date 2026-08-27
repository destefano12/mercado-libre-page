--!strict
--[[
	CameraRig
	------------------------------------------------------------------
	Tres encuadres, todos en 3D dentro del aula:

		"libre"  -> camara normal de Roblox (mirás el aula, al profe, etc.)
		"hoja"   -> plano cerrado sobre la hoja de la prueba
		"celu"   -> plano cerrado sobre la pantalla del celular

	Los cambios son con blend suave: nunca hay un corte seco.
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
local blend = 0
local current: CFrame? = nil
local baseFov = Config.Camera.FieldOfView

function CameraRig.setPaper(part: BasePart?)
	paperPart = part
end

function CameraRig.setScreen(part: BasePart?)
	screenPart = part
end

function CameraRig.setMode(mode: string)
	if CameraRig.mode == mode then
		return
	end
	CameraRig.mode = mode
	if mode == "libre" then
		blend = 0
	end
end

function CameraRig.toggle(mode: string)
	CameraRig.setMode(CameraRig.mode == mode and "libre" or mode)
end

local function goalCFrame(): CFrame?
	local character = player.Character
	if not character then
		return nil
	end

	if CameraRig.mode == "celu" and screenPart and screenPart.Parent then
		-- La cara -Z de la pantalla es la que mira al alumno.
		local origin = screenPart.CFrame * CFrame.new(0, 0, -2.15)
		return CFrame.lookAt(origin.Position, screenPart.Position)
	end

	if CameraRig.mode == "hoja" and paperPart and paperPart.Parent then
		local offset = Config.Camera.DeskOffset
		local origin = paperPart.CFrame * CFrame.new(offset.X, offset.Y, offset.Z)
		local target = paperPart.Position + Config.Camera.DeskLookOffset
		return CFrame.lookAt(origin.Position, target)
	end

	return nil
end

function CameraRig.start()
	camera = workspace.CurrentCamera

	RunService:BindToRenderStep("AulaCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		camera = workspace.CurrentCamera
		if not camera then
			return
		end

		local goal = goalCFrame()
		local speed = math.clamp(dt / Config.Camera.BlendTime, 0, 1)

		if goal then
			if camera.CameraType ~= Enum.CameraType.Scriptable then
				camera.CameraType = Enum.CameraType.Scriptable
				current = camera.CFrame
			end
			current = (current or camera.CFrame):Lerp(goal, speed)
			camera.CFrame = current
			blend = math.min(1, blend + dt * 3)

			local targetFov = CameraRig.mode == "celu" and Config.Camera.PhoneFieldOfView or baseFov
			camera.FieldOfView += (targetFov - camera.FieldOfView) * speed
		else
			if camera.CameraType == Enum.CameraType.Scriptable then
				camera.CameraType = Enum.CameraType.Custom
				camera.CameraSubject = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				current = nil
			end
			camera.FieldOfView += (baseFov - camera.FieldOfView) * speed
		end
	end)
end

function CameraRig.stop()
	RunService:UnbindFromRenderStep("AulaCamera")
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
end

return CameraRig

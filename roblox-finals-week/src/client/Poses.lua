--!strict
--[[
	Poses
	------------------------------------------------------------------
	Animaciones propias sin subir ninguna animacion.

	Roblox anima con assets, y este proyecto no depende de ninguno. La
	alternativa es escribir el `Transform` de los Motor6D DESPUES de que
	corra el Animator: el motor lo recalcula cada frame, asi que hay que
	pisarlo en cada frame, con prioridad posterior a la del personaje.

	Dos poses, las dos que pide el juego:
	  escribir   el brazo derecho baja al pupitre cuando contestas
	  lanzar     el brazo sube y va hacia adelante al tirar un papel

	Funciona igual en R6 y en R15: la unica diferencia es de que parte
	cuelga el Motor6D del hombro.
--]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local Poses = {}

local writingUntil = 0
local throwingUntil = 0
local phase = 0

--- El Motor6D del hombro derecho, en cualquiera de los dos rigs.
local function rightShoulder(character: Model): Motor6D?
	local torso = character:FindFirstChild("Torso")
	if torso then
		local joint = torso:FindFirstChild("Right Shoulder")
		if joint and joint:IsA("Motor6D") then
			return joint
		end
	end
	local upperArm = character:FindFirstChild("RightUpperArm")
	if upperArm then
		local joint = upperArm:FindFirstChild("RightShoulder")
		if joint and joint:IsA("Motor6D") then
			return joint
		end
	end
	return nil
end

function Poses.write(seconds: number?)
	writingUntil = os.clock() + (seconds or 0.9)
end

function Poses.throw(seconds: number?)
	throwingUntil = os.clock() + (seconds or 0.5)
end

function Poses.mount()
	RunService:BindToRenderStep("FinalsWeekPoses",
		Enum.RenderPriority.Character.Value + 1, function(dt)
			local now = os.clock()
			local writing = now < writingUntil
			local throwing = now < throwingUntil
			if not writing and not throwing then
				return
			end

			local character = player.Character
			if not character then
				return
			end
			local joint = rightShoulder(character)
			if not joint then
				return
			end

			phase += dt
			if throwing then
				-- Un latigazo hacia adelante, corto.
				local alpha = math.clamp((throwingUntil - now) / 0.5, 0, 1)
				joint.Transform = CFrame.Angles(-math.pi * 0.75 * alpha, 0, 0)
			else
				-- Escribir: el brazo abajo, con un temblorcito.
				local wobble = math.sin(phase * 14) * 0.09
				joint.Transform = CFrame.Angles(-1.15 + wobble, 0, 0.18)
			end
		end)
end

function Poses.unmount()
	pcall(function()
		RunService:UnbindFromRenderStep("FinalsWeekPoses")
	end)
end

return Poses

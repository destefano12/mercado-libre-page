--!strict
--[[
	CameraDirector
	------------------------------------------------------------------
	La camara en las transiciones. Deliberadamente conservador: no se
	pone en Scriptable salvo que haga falta, porque una camara tomada
	por script que se olvida de soltarse te deja el juego injugable.

	Lo que hace:
	  * fundido a negro entre fases (tapa el teletransporte al pupitre)
	  * al sentarte, acerca el zoom y lo limita, para que mires tu
	    hoja y a los costados, no el techo
	  * sacudida corta cuando te castigan, enganchada DESPUES del paso
	    de camara del motor para que no se la pise
--]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"))

local player = Players.LocalPlayer

local CameraDirector = {}

local fade: Frame
local shakeUntil = 0
local shakeStrength = 0
local seated = false


function CameraDirector.mount(parent: ScreenGui)
	fade = Instance.new("Frame")
	fade.Name = "Fundido"
	fade.Size = UDim2.fromScale(1, 1)
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.BackgroundTransparency = 1
	fade.BorderSizePixel = 0
	fade.ZIndex = UI.Layer.Fade
	fade.Visible = false
	fade.Parent = parent

	RunService:BindToRenderStep("FinalsWeekCamara", Enum.RenderPriority.Camera.Value + 1, function()
		if os.clock() >= shakeUntil then
			return
		end
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local amount = shakeStrength * ((shakeUntil - os.clock()) / 0.6)
		camera.CFrame = camera.CFrame * CFrame.new(
			(math.random() - 0.5) * amount,
			(math.random() - 0.5) * amount,
			0
		)
	end)
end

--- Funde a negro, corre `middle` con la pantalla tapada y vuelve.
function CameraDirector.transition(middle: (() -> ())?)
	if not fade then
		if middle then
			middle()
		end
		return
	end
	fade.Visible = true
	TweenService:Create(fade, TweenInfo.new(0.35), { BackgroundTransparency = 0 }):Play()
	task.delay(0.4, function()
		if middle then
			pcall(middle)
		end
		task.wait(0.25)
		TweenService:Create(fade, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		task.delay(0.55, function()
			fade.Visible = false
		end)
	end)
end

--[[
	Antes esto acercaba el zoom al sentarte, para que miraras la mesa y a
	los vecinos en vez del techo. Con el juego en primera persona no hay
	zoom que ajustar: `Viewmodel` traba la camara con LockFirstPerson y
	forzar los limites aca la peleaba, dejandola temblando al sentarse.

	Se conserva la funcion porque `init.client` la llama al sentarse y al
	pararse, y el estado sirve para lo que venga; lo que se va es el
	toqueteo del zoom.
--]]
function CameraDirector.setSeated(value: boolean)
	seated = value
end

function CameraDirector.isSeated(): boolean
	return seated
end

function CameraDirector.shake(strength: number, seconds: number?)
	shakeStrength = strength
	shakeUntil = os.clock() + (seconds or 0.6)
end

return CameraDirector

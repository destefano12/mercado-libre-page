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

local player = Players.LocalPlayer

local CameraDirector = {}

local fade: Frame
local shakeUntil = 0
local shakeStrength = 0
local seated = false

local DEFAULT_MIN = 0.5
local DEFAULT_MAX = 128

function CameraDirector.mount(parent: ScreenGui)
	fade = Instance.new("Frame")
	fade.Name = "Fundido"
	fade.Size = UDim2.fromScale(1, 1)
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.BackgroundTransparency = 1
	fade.BorderSizePixel = 0
	fade.ZIndex = 30
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

--- Al sentarse el zoom se acerca: la mesa, la hoja y los vecinos.
function CameraDirector.setSeated(value: boolean)
	if seated == value then
		return
	end
	seated = value
	local ok = pcall(function()
		if value then
			player.CameraMaxZoomDistance = 14
			player.CameraMinZoomDistance = 4
		else
			player.CameraMinZoomDistance = DEFAULT_MIN
			player.CameraMaxZoomDistance = DEFAULT_MAX
		end
	end)
	if not ok then
		-- Si la propiedad no se puede tocar, no pasa nada: el juego
		-- sigue con la camara por defecto.
	end
end

function CameraDirector.shake(strength: number, seconds: number?)
	shakeStrength = strength
	shakeUntil = os.clock() + (seconds or 0.6)
end

return CameraDirector

--!strict
--[[
	Util
	------------------------------------------------------------------
	Azucar para construir cosas en 3D y animarlas sin repetir 40 lineas
	de Instance.new por cada mueble del aula.
--]]

local TweenService = game:GetService("TweenService")

local Util = {}

--- Instance.new + props + hijos, en una sola expresion.
function Util.new(className: string, props: { [string]: any }?, children: { Instance }?): Instance
	local instance = Instance.new(className)
	if props then
		local parent = props.Parent
		for key, value in props do
			if key ~= "Parent" then
				(instance :: any)[key] = value
			end
		end
		if children then
			for _, child in children do
				child.Parent = instance
			end
		end
		if parent then
			instance.Parent = parent
		end
	elseif children then
		for _, child in children do
			child.Parent = instance
		end
	end
	return instance
end

--- Bloque solido estandar del aula: anclado, sin colisiones raras.
function Util.part(props: { [string]: any }): BasePart
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = true
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		if key ~= "Parent" then
			(part :: any)[key] = value
		end
	end
	part.Parent = props.Parent
	return part
end

--- Suelda una parte a otra manteniendo la posicion actual.
function Util.weld(part0: BasePart, part1: BasePart): WeldConstraint
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part0
	weld.Part1 = part1
	weld.Parent = part0
	return weld
end

function Util.tween(instance: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local tween = TweenService:Create(instance, info, goal)
	tween:Play()
	return tween
end

Util.ease = function(time: number, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): TweenInfo
	return TweenInfo.new(time, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out)
end

--- Redondea esquinas + borde, para las UI que van sobre superficies 3D.
function Util.roundify(gui: GuiObject, radius: number, strokeColor: Color3?, strokeThickness: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = gui
	if strokeColor then
		local stroke = Instance.new("UIStroke")
		stroke.Color = strokeColor
		stroke.Thickness = strokeThickness or 2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = gui
	end
end

--- Etiqueta 3D flotante (BillboardGui) — usado para nombres y burbujas.
function Util.billboard(adornee: BasePart, size: UDim2, offset: Vector3): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = adornee
	billboard.Size = size
	billboard.StudsOffsetWorldSpace = offset
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 60
	billboard.LightInfluence = 0
	return billboard
end

--- Interpola angulos evitando el salto en ±180.
function Util.lerpAngle(from: number, to: number, alpha: number): number
	local delta = (to - from + math.pi) % (math.pi * 2) - math.pi
	return from + delta * alpha
end

function Util.randomInRange(range: NumberRange, rng: Random?): number
	local generator = rng or Random.new()
	return generator:NextNumber(range.Min, range.Max)
end

--- Toca un sonido posicional y lo limpia solo.
function Util.playSound(soundId: string, parent: Instance, volume: number?, speed: number?)
	if soundId == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = speed or 1
	sound.RollOffMaxDistance = 80
	sound.Parent = parent
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(10, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

return Util

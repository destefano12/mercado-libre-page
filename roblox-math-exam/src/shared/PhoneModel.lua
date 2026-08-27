--!strict
--[[
	PhoneModel
	------------------------------------------------------------------
	El celular, en 3D, soldado al cuerpo del alumno. Lo crea el servidor
	(asi lo ven todos, incluido el que se copia al lado) y el cliente le
	monta encima la interfaz de RoGPT sobre la parte "Pantalla".

	El Weld tiene C0 animable: guardado va abajo del banco, "afuera"
	sube a la altura del pecho. Ese tween es literalmente el gesto de
	sacar el celular.
--]]

local TweenService = game:GetService("TweenService")

local Util = require(script.Parent:WaitForChild("Util"))
local Config = require(script.Parent:WaitForChild("Config"))

local PhoneModel = {}

-- Escondido abajo del banco, sobre las piernas.
PhoneModel.HIDDEN_C0 = CFrame.new(0.75, -1.9, -0.75)
	* CFrame.Angles(0, math.pi, 0)
	* CFrame.Angles(math.rad(-70), 0, 0)

-- Levantado a la altura del pecho, pantalla mirando al alumno.
PhoneModel.RAISED_C0 = CFrame.new(0.55, 0.15, -1.35)
	* CFrame.Angles(0, math.pi, 0)
	* CFrame.Angles(math.rad(-22), 0, 0)

-- Apuntando a la hoja: el celu baja y se inclina para que la camara
-- mire el banco. Antes disparabas con el celu mirando al techo.
PhoneModel.AIM_C0 = CFrame.new(0.35, -0.35, -1.5)
	* CFrame.Angles(0, math.pi, 0)
	* CFrame.Angles(math.rad(-72), 0, 0)

local function findHold(character: Model): BasePart?
	return (character:FindFirstChild("HumanoidRootPart") :: BasePart?)
		or (character:FindFirstChild("UpperTorso") :: BasePart?)
		or (character:FindFirstChild("Torso") :: BasePart?)
end

--- Construye el celular y lo suelda al personaje. Devuelve model, weld, pantalla.
function PhoneModel.attach(character: Model): (Model?, Weld?, BasePart?)
	local hold = findHold(character)
	if not hold then
		return nil, nil, nil
	end

	local existing = character:FindFirstChild("Celular")
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "Celular"

	local body = Util.part({
		Name = "Cuerpo",
		Size = Vector3.new(0.78, 1.58, 0.09),
		Color = Color3.fromRGB(28, 30, 36),
		Material = Enum.Material.Metal,
		Anchored = false,
		CanCollide = false,
		CastShadow = false,
		Parent = model,
	})
	body.CFrame = hold.CFrame * PhoneModel.HIDDEN_C0
	body.Massless = true
	model.PrimaryPart = body

	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, transparency: number?): BasePart
		local part = Util.part({
			Name = name,
			Size = size,
			CFrame = body.CFrame * offset,
			Color = color,
			Material = material,
			Anchored = false,
			CanCollide = false,
			CastShadow = false,
			Transparency = transparency or 0,
			Parent = model,
		})
		part.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = part
		weld.Parent = body
		return part
	end

	-- Pantalla (la cara -Z del celular es la que mira al alumno)
	local screen = piece("Pantalla", Vector3.new(0.72, 1.46, 0.02),
		CFrame.new(0, 0.02, -0.05), Color3.fromRGB(10, 11, 14), Enum.Material.SmoothPlastic)

	-- Marco, camara y detalles
	piece("Marco", Vector3.new(0.82, 1.62, 0.06), CFrame.new(0, 0, 0.01),
		Color3.fromRGB(52, 56, 66), Enum.Material.Metal)
	local lens = piece("Camara", Vector3.new(0.16, 0.16, 0.04), CFrame.new(-0.22, 0.62, 0.06),
		Color3.fromRGB(16, 18, 24), Enum.Material.Glass)
	lens.Shape = Enum.PartType.Cylinder
	lens.Orientation = Vector3.new(0, 90, 0)
	piece("Flash", Vector3.new(0.09, 0.09, 0.03), CFrame.new(-0.02, 0.62, 0.06),
		Color3.fromRGB(240, 236, 210), Enum.Material.Neon)
	piece("BotonVolumen", Vector3.new(0.04, 0.34, 0.05), CFrame.new(0.42, 0.35, 0),
		Color3.fromRGB(64, 68, 78), Enum.Material.Metal)

	model.Parent = character

	local weld = Instance.new("Weld")
	weld.Name = "Sujecion"
	weld.Part0 = hold
	weld.Part1 = body
	weld.C0 = PhoneModel.HIDDEN_C0
	weld.Parent = body

	return model, weld, screen
end

--- Anima el gesto de sacar / guardar el celular.
function PhoneModel.setRaised(weld: Weld, raised: boolean)
	local goal = raised and PhoneModel.RAISED_C0 or PhoneModel.HIDDEN_C0
	TweenService:Create(weld, TweenInfo.new(Config.Phone.RaiseTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		C0 = goal,
	}):Play()
end

--- Baja el celu a apuntar la hoja, dispara, y lo vuelve a subir.
function PhoneModel.aimAtPaper(weld: Weld)
	TweenService:Create(weld, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		C0 = PhoneModel.AIM_C0,
	}):Play()
	task.delay(0.55, function()
		if weld.Parent then
			TweenService:Create(weld, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				C0 = PhoneModel.RAISED_C0,
			}):Play()
		end
	end)
end

return PhoneModel

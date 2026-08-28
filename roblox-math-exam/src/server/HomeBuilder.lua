--!strict
--[[
	HomeBuilder
	------------------------------------------------------------------
	La casa. Es la segunda mitad del juego: llegaste de la escuela y
	ahora tenés que sobrevivir la pregunta de tu viejo.

	Living chico y creible, con luz de tarde entrando por la ventana:
	sillon, mesa ratona, tele, alfombra, lampara y la puerta por la que
	entrás. Nada mas — la escena dura un minuto y medio y lo que importa
	esta en la charla, no en los muebles.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local HomeBuilder = {}

export type Home = {
	model: Model,
	playerSpawn: CFrame,
	dadStand: CFrame,
	doorway: CFrame,
	couchSpot: CFrame,
	cameraWide: CFrame,
	cameraClose: CFrame,
}

local WALL = Color3.fromRGB(226, 216, 200)
local WOOD = Color3.fromRGB(146, 106, 68)
local DARK = Color3.fromRGB(58, 54, 58)
local FABRIC = Color3.fromRGB(102, 106, 118)

local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): BasePart
	return Util.part({
		Name = name,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = material,
		Parent = parent,
	})
end

function HomeBuilder.build(parent: Instance): Home
	local existing = parent:FindFirstChild("Casa")
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "Casa"

	local origin = Config.Story.HomeOrigin
	local width, depth, height = 34, 28, 12

	-- Envolvente
	block(model, "Piso", Vector3.new(width, 1, depth), origin * CFrame.new(0, -0.5, 0),
		Color3.fromRGB(168, 132, 92), Enum.Material.WoodPlanks)
	block(model, "Techo", Vector3.new(width, 1, depth), origin * CFrame.new(0, height + 0.5, 0),
		Color3.fromRGB(240, 238, 232), Enum.Material.Plaster)
	block(model, "ParedFondo", Vector3.new(width, height, 1), origin * CFrame.new(0, height / 2, -depth / 2), WALL, Enum.Material.Plaster)
	block(model, "ParedIzq", Vector3.new(1, height, depth), origin * CFrame.new(-width / 2, height / 2, 0), WALL, Enum.Material.Plaster)
	block(model, "ParedDer", Vector3.new(1, height, depth), origin * CFrame.new(width / 2, height / 2, 0), WALL, Enum.Material.Plaster)

	-- Pared de entrada, partida para dejar el vano de la puerta
	block(model, "ParedFrenteA", Vector3.new(width / 2 - 3, height, 1), origin * CFrame.new(-width / 4 - 1.5, height / 2, depth / 2), WALL, Enum.Material.Plaster)
	block(model, "ParedFrenteB", Vector3.new(width / 2 - 3, height, 1), origin * CFrame.new(width / 4 + 1.5, height / 2, depth / 2), WALL, Enum.Material.Plaster)
	block(model, "Dintel", Vector3.new(6, height - 9, 1), origin * CFrame.new(0, height - (height - 9) / 2, depth / 2), WALL, Enum.Material.Plaster)
	block(model, "MarcoPuerta", Vector3.new(6.6, 9.4, 0.5), origin * CFrame.new(0, 4.7, depth / 2 - 0.2), WOOD, Enum.Material.Wood)

	-- Ventana con luz de tarde
	local glass = block(model, "Ventana", Vector3.new(0.3, 6, 10), origin * CFrame.new(-width / 2, 6.5, -2),
		Color3.fromRGB(226, 214, 190), Enum.Material.Glass)
	glass.Transparency = 0.7
	glass.CastShadow = false
	for _, piece in {
		{ Vector3.new(0.6, 0.4, 10.6), CFrame.new(0, 3, 0) },
		{ Vector3.new(0.6, 0.4, 10.6), CFrame.new(0, -3, 0) },
		{ Vector3.new(0.6, 6, 0.4), CFrame.new(0, 0, 5) },
		{ Vector3.new(0.6, 6, 0.4), CFrame.new(0, 0, -5) },
		{ Vector3.new(0.5, 6, 0.3), CFrame.new(0, 0, 0) },
	} do
		block(model, "MarcoVentana", piece[1] :: Vector3, glass.CFrame * (piece[2] :: CFrame), WOOD, Enum.Material.Wood)
	end

	local sun = Instance.new("SurfaceLight")
	sun.Face = Enum.NormalId.Right
	sun.Brightness = 1.6
	sun.Range = 30
	sun.Angle = 140
	sun.Color = Color3.fromRGB(255, 226, 178)
	sun.Parent = glass

	-- Sillon contra la pared del fondo
	local couch = origin * CFrame.new(-4, 0, -8)
	block(model, "Sillon", Vector3.new(11, 1.6, 4), couch * CFrame.new(0, 1.8, 0), FABRIC, Enum.Material.Fabric)
	block(model, "Respaldo", Vector3.new(11, 3.2, 1), couch * CFrame.new(0, 3.2, -1.9), FABRIC, Enum.Material.Fabric)
	block(model, "BrazoIzq", Vector3.new(1, 2.4, 4), couch * CFrame.new(-5.2, 2.4, 0), FABRIC, Enum.Material.Fabric)
	block(model, "BrazoDer", Vector3.new(1, 2.4, 4), couch * CFrame.new(5.2, 2.4, 0), FABRIC, Enum.Material.Fabric)
	for _, x in { -4.5, 4.5 } do
		block(model, "PataSillon", Vector3.new(0.5, 1, 0.5), couch * CFrame.new(x, 0.5, 1.5), DARK, Enum.Material.Wood)
		block(model, "PataSillon", Vector3.new(0.5, 1, 0.5), couch * CFrame.new(x, 0.5, -1.5), DARK, Enum.Material.Wood)
	end

	-- Alfombra y mesa ratona
	local rug = block(model, "Alfombra", Vector3.new(14, 0.08, 9), origin * CFrame.new(-3, 0.05, -2),
		Color3.fromRGB(142, 104, 96), Enum.Material.Fabric)
	rug.CanCollide = false
	block(model, "MesaRatona", Vector3.new(6, 0.3, 3), origin * CFrame.new(-3, 2, -2.5), WOOD, Enum.Material.Wood)
	for _, offset in { Vector3.new(-2.5, 0, -1.1), Vector3.new(2.5, 0, -1.1), Vector3.new(-2.5, 0, 1.1), Vector3.new(2.5, 0, 1.1) } do
		block(model, "PataMesa", Vector3.new(0.3, 2, 0.3), origin * CFrame.new(-3 + offset.X, 1, -2.5 + offset.Z), WOOD, Enum.Material.Wood)
	end

	-- Tele en su mueble
	block(model, "MuebleTV", Vector3.new(9, 2.2, 2.4), origin * CFrame.new(-3, 1.1, 4.5), WOOD, Enum.Material.Wood)
	local tv = block(model, "Tele", Vector3.new(8, 4.6, 0.3), origin * CFrame.new(-3, 4.6, 4.5), DARK, Enum.Material.Metal)
	local screen = block(model, "Pantalla", Vector3.new(7.4, 4, 0.1), origin * CFrame.new(-3, 4.6, 4.32),
		Color3.fromRGB(28, 34, 46), Enum.Material.SmoothPlastic)
	screen.CastShadow = false
	tv.CanCollide = false

	-- Lampara de pie
	block(model, "BaseLampara", Vector3.new(1.6, 0.3, 1.6), origin * CFrame.new(3.5, 0.15, -9), DARK, Enum.Material.Metal)
	block(model, "PieLampara", Vector3.new(0.25, 7, 0.25), origin * CFrame.new(3.5, 3.6, -9), DARK, Enum.Material.Metal)
	local shade = block(model, "Pantalla", Vector3.new(2.6, 2, 2.6), origin * CFrame.new(3.5, 8, -9),
		Color3.fromRGB(244, 232, 206), Enum.Material.Fabric)
	local bulb = Instance.new("PointLight")
	bulb.Brightness = 1.4
	bulb.Range = 22
	bulb.Color = Color3.fromRGB(255, 232, 196)
	bulb.Parent = shade

	-- Mesa del comedor, donde te espera tu viejo
	local table = origin * CFrame.new(9, 0, -3)
	block(model, "Mesa", Vector3.new(7, 0.35, 5), table * CFrame.new(0, 3, 0), WOOD, Enum.Material.Wood)
	for _, offset in { Vector3.new(-3, 0, -2), Vector3.new(3, 0, -2), Vector3.new(-3, 0, 2), Vector3.new(3, 0, 2) } do
		block(model, "PataMesa", Vector3.new(0.4, 3, 0.4), table * CFrame.new(offset.X, 1.5, offset.Z), WOOD, Enum.Material.Wood)
	end
	block(model, "Taza", Vector3.new(0.9, 1, 0.9), table * CFrame.new(-1.5, 3.6, 0.5), Color3.fromRGB(196, 88, 72), Enum.Material.SmoothPlastic)

	model.Parent = parent

	local doorway = origin * CFrame.new(0, 3, depth / 2 - 1)
	local dadStand = origin * CFrame.new(9, 3, 1)

	return {
		model = model,
		playerSpawn = origin * CFrame.new(0, 3.5, depth / 2 - 3),
		dadStand = CFrame.lookAt(dadStand.Position, (origin * CFrame.new(0, 3, depth / 2 - 3)).Position),
		doorway = doorway,
		couchSpot = couch * CFrame.new(0, 3.5, 0),
		cameraWide = CFrame.lookAt((origin * CFrame.new(-11, 8, 11)).Position, (origin * CFrame.new(2, 3, -3)).Position),
		cameraClose = CFrame.lookAt((origin * CFrame.new(4.5, 5, 4)).Position, (origin * CFrame.new(9, 4.2, 0)).Position),
	}
end

return HomeBuilder

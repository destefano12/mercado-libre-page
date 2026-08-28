--!strict
--[[
	HomeBuilder
	------------------------------------------------------------------
	La casa. Es la segunda mitad del juego: llegaste de la escuela y
	ahora tenés que sobrevivir la pregunta de tu viejo.

	Living moderno de planta abierta: ventanal de piso a techo con luz
	de tarde, sillon bajo, panel de tele, isla de cocina, comedor con
	lampara colgante. Paleta corta y materiales que se leen — madera
	clara, tela gris, negro mate — para que no parezca una maqueta de
	bloques.
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

local WALL = Color3.fromRGB(238, 235, 229)
local FLOOR = Color3.fromRGB(196, 166, 128)
local WOOD = Color3.fromRGB(168, 128, 88)
local FABRIC = Color3.fromRGB(126, 128, 134)
local DARK = Color3.fromRGB(38, 38, 42)
local WARM = Color3.fromRGB(255, 226, 184)

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

--- Mueble de patas finas: lo que separa un sillon moderno de un cajon.
local function legs(parent: Instance, base: CFrame, spanX: number, spanZ: number, height: number)
	for _, offset in { Vector3.new(-spanX, 0, -spanZ), Vector3.new(spanX, 0, -spanZ),
		Vector3.new(-spanX, 0, spanZ), Vector3.new(spanX, 0, spanZ) } do
		local leg = block(parent, "Pata", Vector3.new(0.22, height, 0.22),
			base * CFrame.new(offset.X, height / 2, offset.Z), DARK, Enum.Material.Metal)
		leg.CanCollide = false
	end
end

function HomeBuilder.build(parent: Instance): Home
	local existing = parent:FindFirstChild("Casa")
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "Casa"

	local origin = Config.Story.HomeOrigin
	local width, depth, height = 42, 34, 13

	-- ── Envolvente ────────────────────────────────────────
	block(model, "Piso", Vector3.new(width, 1, depth), origin * CFrame.new(0, -0.5, 0), FLOOR, Enum.Material.WoodPlanks)
	block(model, "Techo", Vector3.new(width, 1, depth), origin * CFrame.new(0, height + 0.5, 0),
		Color3.fromRGB(248, 246, 242), Enum.Material.Plaster)
	block(model, "ParedFondo", Vector3.new(width, height, 1), origin * CFrame.new(0, height / 2, -depth / 2), WALL, Enum.Material.Plaster)
	block(model, "ParedDer", Vector3.new(1, height, depth), origin * CFrame.new(width / 2, height / 2, 0), WALL, Enum.Material.Plaster)

	-- Zocalo fino, detalle que se nota
	for _, spec in {
		{ Vector3.new(width, 0.6, 1.2), CFrame.new(0, 0.3, -depth / 2) },
		{ Vector3.new(1.2, 0.6, depth), CFrame.new(width / 2, 0.3, 0) },
	} do
		block(model, "Zocalo", spec[1] :: Vector3, origin * (spec[2] :: CFrame), Color3.fromRGB(250, 250, 248), Enum.Material.SmoothPlastic)
	end

	-- ── Ventanal de piso a techo ──────────────────────────
	local glassWall = origin * CFrame.new(-width / 2, height / 2, 0)
	local glass = block(model, "Ventanal", Vector3.new(0.3, height - 1, depth - 4), glassWall,
		Color3.fromRGB(232, 226, 210), Enum.Material.Glass)
	glass.Transparency = 0.72
	glass.Reflectance = 0.08
	glass.CastShadow = false

	for offset = -1, 1 do
		block(model, "Carpinteria", Vector3.new(0.45, height - 1, 0.35),
			glassWall * CFrame.new(0, 0, offset * (depth - 4) / 3), DARK, Enum.Material.Metal)
	end
	block(model, "MarcoSup", Vector3.new(0.5, 0.4, depth - 3), glassWall * CFrame.new(0, (height - 1) / 2, 0), DARK, Enum.Material.Metal)
	block(model, "MarcoInf", Vector3.new(0.5, 0.4, depth - 3), glassWall * CFrame.new(0, -(height - 1) / 2, 0), DARK, Enum.Material.Metal)

	local afternoon = Instance.new("SurfaceLight")
	afternoon.Face = Enum.NormalId.Right
	afternoon.Brightness = 2.2
	afternoon.Range = 42
	afternoon.Angle = 150
	afternoon.Color = WARM
	afternoon.Parent = glass

	-- ── Entrada ───────────────────────────────────────────
	block(model, "ParedFrenteA", Vector3.new(width / 2 - 4, height, 1), origin * CFrame.new(-width / 4 - 2, height / 2, depth / 2), WALL, Enum.Material.Plaster)
	block(model, "ParedFrenteB", Vector3.new(width / 2 - 4, height, 1), origin * CFrame.new(width / 4 + 2, height / 2, depth / 2), WALL, Enum.Material.Plaster)
	block(model, "Dintel", Vector3.new(8, height - 10, 1), origin * CFrame.new(0, height - (height - 10) / 2, depth / 2), WALL, Enum.Material.Plaster)
	block(model, "MarcoPuerta", Vector3.new(7.4, 10.2, 0.4), origin * CFrame.new(0, 5.1, depth / 2 - 0.3), DARK, Enum.Material.Metal)
	local mat = block(model, "Felpudo", Vector3.new(5, 0.08, 2.6), origin * CFrame.new(0, 0.05, depth / 2 - 3.2),
		Color3.fromRGB(96, 92, 88), Enum.Material.Fabric)
	mat.CanCollide = false

	-- ── Sillon bajo, de tres cuerpos ──────────────────────
	local couch = origin * CFrame.new(-8, 0, -6)
	block(model, "SillonBase", Vector3.new(13, 1.3, 4.6), couch * CFrame.new(0, 1.9, 0), FABRIC, Enum.Material.Fabric)
	block(model, "SillonRespaldo", Vector3.new(13, 3, 1.1), couch * CFrame.new(0, 3.4, -2.2), FABRIC, Enum.Material.Fabric)
	for _, x in { -6.4, 6.4 } do
		block(model, "SillonBrazo", Vector3.new(1.1, 2.2, 4.6), couch * CFrame.new(x, 2.3, 0), FABRIC, Enum.Material.Fabric)
	end
	for _, x in { -4, 0, 4 } do
		local cushion = block(model, "Almohadon", Vector3.new(3.6, 0.5, 4), couch * CFrame.new(x, 2.7, 0.2),
			Color3.fromRGB(146, 148, 154), Enum.Material.Fabric)
		cushion.CanCollide = false
	end
	legs(model, couch, 5.8, 1.8, 1.2)

	-- Alfombra y mesa ratona
	local rug = block(model, "Alfombra", Vector3.new(17, 0.06, 11), origin * CFrame.new(-8, 0.05, 0.5),
		Color3.fromRGB(214, 206, 192), Enum.Material.Fabric)
	rug.CanCollide = false
	local table1 = origin * CFrame.new(-8, 0, 0.5)
	block(model, "MesaRatona", Vector3.new(7, 0.25, 3.4), table1 * CFrame.new(0, 2, 0), WOOD, Enum.Material.Wood)
	legs(model, table1, 3, 1.3, 2)
	local mug = block(model, "Taza", Vector3.new(0.8, 0.9, 0.8), table1 * CFrame.new(1.8, 2.55, 0), Color3.fromRGB(228, 226, 220), Enum.Material.SmoothPlastic)
	mug.CanCollide = false

	-- ── Panel de tele ─────────────────────────────────────
	local tvWall = origin * CFrame.new(-8, 0, 7.5)
	block(model, "PanelTV", Vector3.new(16, 9, 0.5), tvWall * CFrame.new(0, 5.5, 0.6), Color3.fromRGB(64, 58, 54), Enum.Material.Wood)
	block(model, "MuebleTV", Vector3.new(12, 1.8, 2.2), tvWall * CFrame.new(0, 0.9, 0), WOOD, Enum.Material.Wood)
	local tv = block(model, "Tele", Vector3.new(11, 6, 0.25), tvWall * CFrame.new(0, 6, 0.3), DARK, Enum.Material.Metal)
	tv.CanCollide = false
	local screen = block(model, "PantallaTV", Vector3.new(10.4, 5.5, 0.08), tvWall * CFrame.new(0, 6, 0.16),
		Color3.fromRGB(22, 26, 34), Enum.Material.SmoothPlastic)
	screen.CastShadow = false
	screen.CanCollide = false

	-- ── Comedor con lampara colgante ──────────────────────
	local dining = origin * CFrame.new(11, 0, -4)
	block(model, "Mesa", Vector3.new(8, 0.3, 5), dining * CFrame.new(0, 3, 0), WOOD, Enum.Material.Wood)
	legs(model, dining, 3.4, 2, 3)
	for _, spot in { Vector3.new(-2.4, 0, 3.4), Vector3.new(2.4, 0, 3.4), Vector3.new(-2.4, 0, -3.4), Vector3.new(2.4, 0, -3.4) } do
		local chair = dining * CFrame.new(spot.X, 0, spot.Z)
		block(model, "Silla", Vector3.new(2, 0.25, 2), chair * CFrame.new(0, 1.9, 0), Color3.fromRGB(206, 200, 190), Enum.Material.SmoothPlastic)
		block(model, "SillaRespaldo", Vector3.new(2, 2.4, 0.22),
			chair * CFrame.new(0, 3.1, spot.Z > 0 and 0.9 or -0.9), Color3.fromRGB(206, 200, 190), Enum.Material.SmoothPlastic)
		legs(model, chair, 0.8, 0.8, 1.9)
	end

	for _, x in { -2, 2 } do
		block(model, "Cable", Vector3.new(0.08, height - 7.4, 0.08), dining * CFrame.new(x, height - (height - 7.4) / 2, 0), DARK, Enum.Material.Metal)
		local shade = block(model, "Colgante", Vector3.new(2.2, 1.4, 2.2), dining * CFrame.new(x, 7.2, 0), DARK, Enum.Material.Metal)
		shade.CanCollide = false
		local bulb = Instance.new("PointLight")
		bulb.Brightness = 1.5
		bulb.Range = 20
		bulb.Color = WARM
		bulb.Parent = shade
	end

	-- ── Cocina al fondo ───────────────────────────────────
	local kitchen = origin * CFrame.new(11, 0, -12)
	block(model, "Bajomesada", Vector3.new(14, 3.4, 3), kitchen * CFrame.new(0, 1.7, 0), Color3.fromRGB(52, 54, 60), Enum.Material.SmoothPlastic)
	block(model, "Mesada", Vector3.new(14.4, 0.35, 3.4), kitchen * CFrame.new(0, 3.55, 0), Color3.fromRGB(226, 224, 218), Enum.Material.Marble)
	block(model, "Alacena", Vector3.new(14, 3, 1.6), kitchen * CFrame.new(0, 8.5, -0.8), Color3.fromRGB(238, 236, 232), Enum.Material.SmoothPlastic)
	local sink = block(model, "Bacha", Vector3.new(2.6, 0.2, 2), kitchen * CFrame.new(-3, 3.7, 0.2), Color3.fromRGB(186, 190, 196), Enum.Material.Metal)
	sink.CanCollide = false
	block(model, "Grifo", Vector3.new(0.2, 1.6, 0.2), kitchen * CFrame.new(-3, 4.5, -0.7), Color3.fromRGB(186, 190, 196), Enum.Material.Metal)

	-- ── Detalles ──────────────────────────────────────────
	for _, spot in { Vector3.new(-18, 0, 12), Vector3.new(17, 0, 12) } do
		local potCF = origin * CFrame.new(spot.X, 0, spot.Z)
		local pot = block(model, "Maceta", Vector3.new(2, 2.4, 2), potCF * CFrame.new(0, 1.2, 0), Color3.fromRGB(212, 206, 196), Enum.Material.Concrete)
		pot.CanCollide = false
		for leaf = 1, 5 do
			local angle = (leaf / 5) * math.pi * 2
			local blade = block(model, "Hoja", Vector3.new(0.7, 4, 0.25),
				potCF * CFrame.new(math.cos(angle) * 0.6, 4.2, math.sin(angle) * 0.6)
					* CFrame.Angles(math.rad(math.cos(angle) * 14), 0, math.rad(math.sin(angle) * 14)),
				Color3.fromRGB(72, 118, 74), Enum.Material.Grass)
			blade.CanCollide = false
		end
	end

	for index, x in { -14, -8, -2 } do
		local frame = block(model, "Cuadro", Vector3.new(3.4, 4.4, 0.2),
			origin * CFrame.new(x, 8.5, -depth / 2 + 0.6), DARK, Enum.Material.Wood)
		frame.CanCollide = false
		local art = block(model, "Lamina", Vector3.new(2.9, 3.9, 0.08),
			origin * CFrame.new(x, 8.5, -depth / 2 + 0.5),
			({ Color3.fromRGB(198, 186, 168), Color3.fromRGB(160, 176, 186), Color3.fromRGB(206, 176, 158) })[index],
			Enum.Material.SmoothPlastic)
		art.CanCollide = false
	end

	model.Parent = parent

	local dadSpot = origin * CFrame.new(11, 3, 2)
	local entrance = origin * CFrame.new(0, 3, depth / 2 - 5)

	return {
		model = model,
		playerSpawn = CFrame.lookAt(entrance.Position, dadSpot.Position),
		dadStand = CFrame.lookAt(dadSpot.Position, entrance.Position),
		doorway = origin * CFrame.new(0, 3, depth / 2 - 1),
		couchSpot = couch * CFrame.new(0, 3.5, 0),
		-- Plano general: entra el ventanal, el sillon y el comedor.
		cameraWide = CFrame.lookAt((origin * CFrame.new(-15, 9, 15)).Position, (origin * CFrame.new(2, 3.5, -2)).Position),
		-- Plano corto sobre tu viejo, a la altura de la cara.
		cameraClose = CFrame.lookAt((origin * CFrame.new(4, 5.2, 4.5)).Position, dadSpot.Position + Vector3.new(0, 1.6, 0)),
	}
end

return HomeBuilder

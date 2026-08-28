--!strict
--[[
	CharacterArt
	------------------------------------------------------------------
	Caras, pelo y anteojos, todo hecho con partes y una SurfaceGui —
	sin depender de ningun asset subido, asi funciona en cualquier lugar
	de Studio apenas lo abris.

	La cara es una placa finita pegada adelante de la cabeza. Las cejas,
	los ojos y la boca son objetos de verdad que se mueven: cambiar de
	expresion no cambia una imagen, mueve las cejas y curva la boca.
--]]

local InsertService = game:GetService("InsertService")

local Config = require(script.Parent:WaitForChild("Config"))
local Util = require(script.Parent:WaitForChild("Util"))

local CharacterArt = {}

export type Face = {
	part: BasePart,
	setExpression: (string) -> (),
	blink: () -> (),
	expression: string,
}

-- ─────────────────────────────────────────────────────────────
-- Expresiones
-- ─────────────────────────────────────────────────────────────

type Expression = {
	eyeHeight: number,     -- 1 = ojo normal, 0.35 = entrecerrado
	browRotation: number,  -- grados, positivo = punta interna para abajo (enojo)
	browLift: number,      -- desplazamiento vertical de las cejas
	mouthCurve: number,    -- >0 sonrisa, <0 boca para abajo
	mouthWidth: number,
	blush: boolean,
}

local EXPRESSIONS: { [string]: Expression } = {
	neutral = { eyeHeight = 1.0, browRotation = 0, browLift = 0, mouthCurve = 0.02, mouthWidth = 1, blush = false },
	contento = { eyeHeight = 0.6, browRotation = -8, browLift = -0.03, mouthCurve = 0.22, mouthWidth = 1.25, blush = true },
	enojado = { eyeHeight = 0.55, browRotation = 26, browLift = 0.05, mouthCurve = -0.18, mouthWidth = 1.1, blush = false },
	sospecha = { eyeHeight = 0.4, browRotation = 14, browLift = 0.03, mouthCurve = -0.06, mouthWidth = 0.85, blush = false },
	sorprendido = { eyeHeight = 1.35, browRotation = -14, browLift = -0.06, mouthCurve = -0.02, mouthWidth = 0.55, blush = false },
	aburrido = { eyeHeight = 0.45, browRotation = -4, browLift = 0.04, mouthCurve = -0.04, mouthWidth = 0.8, blush = false },
	nervioso = { eyeHeight = 1.2, browRotation = -20, browLift = -0.02, mouthCurve = -0.1, mouthWidth = 0.7, blush = true },
	concentrado = { eyeHeight = 0.7, browRotation = 10, browLift = 0.02, mouthCurve = 0, mouthWidth = 0.6, blush = false },
}

CharacterArt.Expressions = EXPRESSIONS

local MOUTH_SEGMENTS = 9

local function el(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

-- ─────────────────────────────────────────────────────────────
-- Cara
-- ─────────────────────────────────────────────────────────────

--- Pega una cara a la cabeza y devuelve el control para cambiarle el humor.
function CharacterArt.attachFace(head: BasePart, skinColor: Color3): Face
	-- Si el rig traia la carita default de Roblox, se va: ahora manda esta.
	local decal = head:FindFirstChild("face")
	if decal then
		decal:Destroy()
	end
	local previous = head:FindFirstChild("Cara")
	if previous then
		previous:Destroy()
	end

	local depth = head.Size.Z / 2
	local plate = Util.part({
		Name = "Cara",
		Size = Vector3.new(head.Size.X * 0.94, head.Size.Y * 0.94, 0.06),
		CFrame = head.CFrame * CFrame.new(0, head.Size.Y * 0.03, -depth - 0.02),
		Color = skinColor,
		Material = Enum.Material.SmoothPlastic,
		Anchored = false,
		CanCollide = false,
		CastShadow = false,
		Parent = head,
	})
	plate.Massless = true
	Util.weld(head, plate)

	local gui = el("SurfaceGui", {
		Name = "Rasgos",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 260,
		LightInfluence = 0.6,
		MaxDistance = 90,
		Parent = plate,
	})

	local canvas = el("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = skinColor,
		BorderSizePixel = 0,
	}, gui)

	local ink = Color3.fromRGB(28, 26, 30)

	-- Ojos (con brillito, para que no queden muertos)
	local eyes: { Frame } = {}
	local pupils: { Frame } = {}
	for index, x in { 0.3, 0.7 } do
		local eye = el("Frame", {
			Name = "Ojo" .. index,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.38),
			Size = UDim2.fromScale(0.13, 0.17),
			BackgroundColor3 = Color3.fromRGB(250, 250, 252),
			BorderSizePixel = 0,
		}, canvas)
		Util.roundify(eye, 40, ink, 2)

		local pupil = el("Frame", {
			Name = "Pupila",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.55),
			Size = UDim2.fromScale(0.55, 0.55),
			BackgroundColor3 = ink,
			BorderSizePixel = 0,
		}, eye)
		Util.roundify(pupil, 40)

		el("Frame", {
			Name = "Brillo",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.32, 0.3),
			Size = UDim2.fromScale(0.3, 0.3),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
		}, pupil)

		eyes[index] = eye
		pupils[index] = pupil
	end

	-- Cejas
	local brows: { Frame } = {}
	for index, x in { 0.3, 0.7 } do
		local brow = el("Frame", {
			Name = "Ceja" .. index,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.22),
			Size = UDim2.fromScale(0.2, 0.05),
			BackgroundColor3 = ink,
			BorderSizePixel = 0,
		}, canvas)
		Util.roundify(brow, 6)
		brows[index] = brow
	end

	-- Boca: varios segmentos sobre una parabola, asi curva de verdad
	local mouth: { Frame } = {}
	for index = 1, MOUTH_SEGMENTS do
		mouth[index] = el("Frame", {
			Name = "Boca" .. index,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(0.035, 0.035),
			BackgroundColor3 = ink,
			BorderSizePixel = 0,
		}, canvas)
		Util.roundify(mouth[index], 6)
	end

	-- Cachetes (solo se prenden cuando corresponde)
	local blushes: { Frame } = {}
	for index, x in { 0.17, 0.83 } do
		local blush = el("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.55),
			Size = UDim2.fromScale(0.16, 0.1),
			BackgroundColor3 = Color3.fromRGB(232, 132, 128),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, canvas)
		Util.roundify(blush, 30)
		blushes[index] = blush
	end

	local face: any = { part = plate, expression = "neutral" }
	local baseEyeHeight = 0.17

	local function apply(name: string)
		local data = EXPRESSIONS[name] or EXPRESSIONS.neutral
		face.expression = name

		for _, eye in eyes do
			eye.Size = UDim2.fromScale(0.13, baseEyeHeight * data.eyeHeight)
		end
		for index, brow in brows do
			local sign = index == 1 and 1 or -1
			brow.Position = UDim2.fromScale(index == 1 and 0.3 or 0.7, 0.22 + data.browLift)
			brow.Rotation = data.browRotation * sign
		end
		for index, segment in mouth do
			local t = (index - 1) / (MOUTH_SEGMENTS - 1)      -- 0..1
			local offset = (t - 0.5) * 2                       -- -1..1
			local x = 0.5 + offset * 0.13 * data.mouthWidth
			local y = 0.68 - data.mouthCurve * (1 - offset * offset)
			segment.Position = UDim2.fromScale(x, y)
		end
		for _, blush in blushes do
			blush.BackgroundTransparency = data.blush and 0.45 or 1
		end
	end

	apply("neutral")

	function face.setExpression(name: string)
		if face.expression ~= name then
			apply(name)
		end
	end

	function face.blink()
		for _, eye in eyes do
			eye.Size = UDim2.fromScale(0.13, 0.02)
		end
		task.delay(0.12, function()
			if plate.Parent then
				apply(face.expression)
			end
		end)
	end

	--- Mueve las pupilas: sirve para que el profe "clave" la mirada.
	function face.look(dx: number, dy: number)
		for _, pupil in pupils do
			pupil.Position = UDim2.fromScale(0.5 + math.clamp(dx, -1, 1) * 0.22, 0.55 + math.clamp(dy, -1, 1) * 0.2)
		end
	end

	return face
end

-- ─────────────────────────────────────────────────────────────
-- Pelo
-- ─────────────────────────────────────────────────────────────

local function hairPiece(head: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3): BasePart
	local part = Util.part({
		Name = name,
		Size = size,
		CFrame = head.CFrame * offset,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Anchored = false,
		CanCollide = false,
		CastShadow = false,
		Parent = head,
	})
	part.Massless = true
	Util.weld(head, part)
	return part
end

--- Pelo de viejo: pelado arriba, canas a los costados y en la nuca.
function CharacterArt.attachOldHair(head: BasePart, color: Color3?)
	local gray = color or Color3.fromRGB(214, 214, 210)
	local w, h, d = head.Size.X, head.Size.Y, head.Size.Z

	-- Corona de canas: dos costados y la nuca
	hairPiece(head, "CanasIzq", Vector3.new(w * 0.16, h * 0.42, d * 1.02),
		CFrame.new(-w * 0.46, h * 0.12, 0), gray)
	hairPiece(head, "CanasDer", Vector3.new(w * 0.16, h * 0.42, d * 1.02),
		CFrame.new(w * 0.46, h * 0.12, 0), gray)
	hairPiece(head, "Nuca", Vector3.new(w * 1.02, h * 0.4, d * 0.16),
		CFrame.new(0, h * 0.14, d * 0.46), gray)
	-- Una isla de pelo arriba, que es lo que lo hace gracioso
	hairPiece(head, "Islita", Vector3.new(w * 0.34, h * 0.1, d * 0.5),
		CFrame.new(0, h * 0.52, d * 0.12), gray)
	-- Patillas
	hairPiece(head, "PatillaIzq", Vector3.new(w * 0.14, h * 0.2, d * 0.2),
		CFrame.new(-w * 0.45, -h * 0.12, d * 0.2), gray)
	hairPiece(head, "PatillaDer", Vector3.new(w * 0.14, h * 0.2, d * 0.2),
		CFrame.new(w * 0.45, -h * 0.12, d * 0.2), gray)
end

local HAIR_STYLES = { "corto", "largo", "rulos", "colita", "gorra" }
CharacterArt.HairStyles = HAIR_STYLES

--- Peinados de alumno. Variados, para que no parezcan clones.
function CharacterArt.attachHair(head: BasePart, style: string, color: Color3)
	local w, h, d = head.Size.X, head.Size.Y, head.Size.Z

	if style == "gorra" then
		hairPiece(head, "Gorra", Vector3.new(w * 1.04, h * 0.24, d * 1.04),
			CFrame.new(0, h * 0.44, 0), color)
		hairPiece(head, "Visera", Vector3.new(w * 1.0, h * 0.07, d * 0.6),
			CFrame.new(0, h * 0.33, -d * 0.72), color)
		hairPiece(head, "Flequillo", Vector3.new(w * 0.98, h * 0.12, d * 0.2),
			CFrame.new(0, h * 0.28, -d * 0.46), Color3.fromRGB(58, 42, 32))
		return
	end

	-- Casquete comun a todos
	hairPiece(head, "Pelo", Vector3.new(w * 1.04, h * 0.3, d * 1.04),
		CFrame.new(0, h * 0.42, 0), color)
	hairPiece(head, "Flequillo", Vector3.new(w * 1.02, h * 0.16, d * 0.22),
		CFrame.new(0, h * 0.3, -d * 0.45), color)

	if style == "largo" then
		hairPiece(head, "MelenaIzq", Vector3.new(w * 0.18, h * 0.75, d * 0.9),
			CFrame.new(-w * 0.48, -h * 0.05, d * 0.05), color)
		hairPiece(head, "MelenaDer", Vector3.new(w * 0.18, h * 0.75, d * 0.9),
			CFrame.new(w * 0.48, -h * 0.05, d * 0.05), color)
		hairPiece(head, "Espalda", Vector3.new(w * 1.0, h * 0.7, d * 0.2),
			CFrame.new(0, -h * 0.05, d * 0.5), color)
	elseif style == "rulos" then
		for index = 1, 6 do
			local angle = (index / 6) * math.pi * 2
			hairPiece(head, "Rulo" .. index, Vector3.new(w * 0.42, h * 0.34, d * 0.42),
				CFrame.new(math.cos(angle) * w * 0.36, h * 0.44, math.sin(angle) * d * 0.36), color)
		end
	elseif style == "colita" then
		hairPiece(head, "Colita", Vector3.new(w * 0.3, h * 0.3, d * 0.3),
			CFrame.new(0, h * 0.36, d * 0.62), color)
		hairPiece(head, "Cola", Vector3.new(w * 0.22, h * 0.55, d * 0.22),
			CFrame.new(0, h * 0.12, d * 0.68), color)
	end
end

--- Anteojos: dos aros y el puente. El profe no los usa de adorno,
--- se los baja para mirarte fijo cuando desconfia.
function CharacterArt.attachGlasses(head: BasePart, color: Color3?)
	local frameColor = color or Color3.fromRGB(38, 40, 46)
	local w, h, d = head.Size.X, head.Size.Y, head.Size.Z
	local z = -d * 0.55

	for index, x in { -w * 0.24, w * 0.24 } do
		local lens = hairPiece(head, "Cristal" .. index, Vector3.new(w * 0.34, h * 0.26, 0.05),
			CFrame.new(x, h * 0.06, z - 0.03), Color3.fromRGB(226, 240, 248))
		lens.Transparency = 0.55
		lens.Material = Enum.Material.Glass
		hairPiece(head, "Aro" .. index, Vector3.new(w * 0.38, h * 0.3, 0.04),
			CFrame.new(x, h * 0.06, z), frameColor)
	end
	hairPiece(head, "Puente", Vector3.new(w * 0.16, h * 0.04, 0.04),
		CFrame.new(0, h * 0.06, z), frameColor)
	hairPiece(head, "PatillaAnteojoIzq", Vector3.new(0.05, h * 0.04, d * 0.9),
		CFrame.new(-w * 0.44, h * 0.06, 0), frameColor)
	hairPiece(head, "PatillaAnteojoDer", Vector3.new(0.05, h * 0.04, d * 0.9),
		CFrame.new(w * 0.44, h * 0.06, 0), frameColor)
end

-- ─────────────────────────────────────────────────────────────
-- Pelo del catalogo
-- ─────────────────────────────────────────────────────────────

-- Se baja una sola vez por id y despues se clona: pedirle el mismo
-- accesorio a Roblox veinte veces tarda una eternidad.
local hairPool: { Accessory } = {}
local hairLoaded = false

--- Baja los pelos configurados en Config.Avatars.HairIds. Si la lista
--- esta vacia o Roblox no los da, devuelve falso y se usa el pelo
--- hecho con partes.
function CharacterArt.loadHairPool(): boolean
	if hairLoaded then
		return #hairPool > 0
	end
	hairLoaded = true

	for _, id in Config.Avatars.HairIds do
		local ok, container = pcall(function()
			return InsertService:LoadAsset(id)
		end)
		if ok and container then
			local accessory = container:FindFirstChildOfClass("Accessory")
			if accessory then
				accessory.Parent = nil
				table.insert(hairPool, accessory)
			end
			container:Destroy()
		else
			warn(string.format(
				"[Aula] No se pudo bajar el pelo %d. Tiene que ser gratis y estar en tu inventario.", id))
		end
	end

	if #hairPool > 0 then
		print(string.format("[Aula] %d pelos del catalogo listos.", #hairPool))
	end
	return #hairPool > 0
end

--- Le pone un pelo del catalogo a un personaje. Devuelve falso si no
--- hay ninguno cargado, para que el llamador use el de partes.
function CharacterArt.attachCatalogHair(model: Model, rng: Random?): boolean
	if #hairPool == 0 then
		return false
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	local index = rng and rng:NextInteger(1, #hairPool) or math.random(1, #hairPool)
	local ok = pcall(function()
		humanoid:AddAccessory(hairPool[index]:Clone())
	end)
	return ok
end

-- ─────────────────────────────────────────────────────────────
-- Ropa
-- ─────────────────────────────────────────────────────────────

--- Busca una parte del cuerpo probando los nombres de los dos rigs
--- posibles (avatar R15 y el rig propio de respaldo).
local function findPart(model: Model, candidates: { string }): BasePart?
	for _, name in candidates do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

--- Funda una parte del cuerpo con una capa de ropa apenas mas grande.
local function shell(host: BasePart, name: string, scale: Vector3, offset: CFrame, color: Color3, material: Enum.Material): BasePart
	local part = Util.part({
		Name = name,
		Size = host.Size * scale,
		CFrame = host.CFrame * offset,
		Color = color,
		Material = material,
		Anchored = false,
		CanCollide = false,
		CastShadow = false,
		Parent = host,
	})
	part.Massless = true
	Util.weld(host, part)
	return part
end

--- Traje entero: saco, solapas, camisa, corbata, pantalon y zapatos.
--- Anda igual sobre un avatar R15 que sobre el rig de respaldo.
function CharacterArt.attachSuit(model: Model, suitColor: Color3?, tieColor: Color3?)
	local suit = suitColor or Color3.fromRGB(52, 56, 68)
	local tie = tieColor or Color3.fromRGB(112, 40, 46)
	local shirt = Color3.fromRGB(238, 240, 244)

	local torso = findPart(model, { "UpperTorso", "Torso" })
	if torso then
		local depth = torso.Size.Z
		shell(torso, "Saco", Vector3.new(1.08, 1.04, 1.14), CFrame.new(0, 0, 0.01), suit, Enum.Material.Fabric)
		-- Camisa y corbata asomando entre las solapas
		shell(torso, "Camisa", Vector3.new(0.42, 0.86, 1.2), CFrame.new(0, 0.04, -0.01), shirt, Enum.Material.Fabric)
		shell(torso, "Corbata", Vector3.new(0.16, 0.72, 1.26), CFrame.new(0, -0.04, -0.01), tie, Enum.Material.Fabric)
		shell(torso, "Nudo", Vector3.new(0.2, 0.14, 1.28), CFrame.new(0, torso.Size.Y * 0.34, -0.01), tie, Enum.Material.Fabric)
		-- Solapas: dos tiras inclinadas sobre el pecho
		for _, side in { -1, 1 } do
			local lapel = shell(torso, "Solapa", Vector3.new(0.26, 0.62, 1.18),
				CFrame.new(side * torso.Size.X * 0.17, torso.Size.Y * 0.1, -depth * 0.01)
					* CFrame.Angles(0, 0, math.rad(side * 9)), suit, Enum.Material.Fabric)
			lapel.Color = suit:Lerp(Color3.new(0, 0, 0), 0.12)
		end
		shell(torso, "Cuello", Vector3.new(0.62, 0.12, 1.16), CFrame.new(0, torso.Size.Y * 0.44, 0), shirt, Enum.Material.Fabric)
	end

	local lowerTorso = findPart(model, { "LowerTorso" })
	if lowerTorso then
		shell(lowerTorso, "Cintura", Vector3.new(1.06, 1.04, 1.1), CFrame.new(), suit, Enum.Material.Fabric)
		shell(lowerTorso, "Cinturon", Vector3.new(1.1, 0.22, 1.14), CFrame.new(0, lowerTorso.Size.Y * 0.42, 0),
			Color3.fromRGB(38, 32, 30), Enum.Material.Fabric)
	end

	-- Mangas
	for _, name in { "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "BrazoIzq", "BrazoDer" } do
		local arm = model:FindFirstChild(name)
		if arm and arm:IsA("BasePart") then
			local cuff = string.find(name, "Lower") ~= nil
			shell(arm, "Manga", Vector3.new(1.09, 1.02, 1.09), CFrame.new(), suit, Enum.Material.Fabric)
			if cuff then
				shell(arm, "Puño", Vector3.new(1.12, 0.16, 1.12), CFrame.new(0, -arm.Size.Y * 0.42, 0), shirt, Enum.Material.Fabric)
			end
		end
	end

	-- Pantalon
	for _, name in { "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "PiernaIzq", "PiernaDer" } do
		local leg = model:FindFirstChild(name)
		if leg and leg:IsA("BasePart") then
			shell(leg, "Pantalon", Vector3.new(1.08, 1.02, 1.08), CFrame.new(), suit:Lerp(Color3.new(0, 0, 0), 0.18), Enum.Material.Fabric)
		end
	end

	-- Zapatos
	for _, name in { "LeftFoot", "RightFoot" } do
		local foot = model:FindFirstChild(name)
		if foot and foot:IsA("BasePart") then
			shell(foot, "Zapato", Vector3.new(1.14, 1.1, 1.2), CFrame.new(0, 0, -foot.Size.Z * 0.06),
				Color3.fromRGB(32, 28, 28), Enum.Material.SmoothPlastic)
		end
	end
end

--- La tablilla con la lista de curso. Un profesor sin tablilla no
--- asusta a nadie.
function CharacterArt.attachClipboard(model: Model): BasePart?
	local hand = findPart(model, { "RightHand", "RightLowerArm", "BrazoDer", "Right Arm" })
	if not hand then
		return nil
	end

	local board = Util.part({
		Name = "Tablilla",
		Size = Vector3.new(1.5, 0.12, 2),
		CFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y * 0.5 - 0.2, -0.4) * CFrame.Angles(math.rad(-15), 0, 0),
		Color = Color3.fromRGB(150, 116, 78),
		Material = Enum.Material.Wood,
		Anchored = false,
		CanCollide = false,
		CastShadow = false,
		Parent = hand,
	})
	board.Massless = true
	Util.weld(hand, board)

	local sheet = Util.part({
		Name = "Planilla",
		Size = Vector3.new(1.3, 0.05, 1.7),
		CFrame = board.CFrame * CFrame.new(0, 0.09, -0.1),
		Color = Color3.fromRGB(248, 248, 244),
		Material = Enum.Material.SmoothPlastic,
		Anchored = false,
		CanCollide = false,
		CastShadow = false,
		Parent = board,
	})
	sheet.Massless = true
	Util.weld(board, sheet)

	local clip = Util.part({
		Name = "Clip",
		Size = Vector3.new(0.7, 0.14, 0.28),
		CFrame = board.CFrame * CFrame.new(0, 0.14, -0.82),
		Color = Color3.fromRGB(176, 180, 188),
		Material = Enum.Material.Metal,
		Anchored = false,
		CanCollide = false,
		CastShadow = false,
		Parent = board,
	})
	clip.Massless = true
	Util.weld(board, clip)

	return board
end

return CharacterArt

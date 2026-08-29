--!strict
--[[
	Style
	------------------------------------------------------------------
	La direccion de arte del mundo 3D: paleta, materiales y brillo.
	(La paleta de la *interfaz* es otra cosa y vive en Theme.lua.)

	Esta version da vuelta la anterior por completo, y conviene decir
	por que.

	La version vieja perseguia "que no parezca Roblox": nada saturado,
	nada por encima del 60% de saturacion, materiales PBR del motor
	(Concrete, Brick, CeramicTiles, CorrodedMetal) para que las
	superficies tuvieran grano real, y desgaste geometrico encima —
	rayones en los casilleros, oxido, baldosas gastadas, manchas de roce
	a la altura del hombro.

	La referencia del juego real es exactamente lo contrario:
	**superficies mates y planas, de color saturado, limpias.** No hay
	grano, no hay reflejo y no hay mugre. Es una imagen pintada, no
	fotografiada.

	Por eso aca casi todo es `SmoothPlastic`: en Roblox es el unico
	material verdaderamente liso, y resulta que el "plastico" que la
	version anterior evitaba a toda costa es justamente lo que acerca el
	resultado a la referencia. Los PBR del motor son los que rompen el
	parecido.

	Tambien desaparece el camino de `SurfaceAppearance`: dependia de
	subir imagenes a Roblox, nunca tuvo un solo id cargado, y con un
	look plano no aporta nada.
--]]

local Style = {}

-- ── paleta ─────────────────────────────────────────────────────────
--[[
	Sacada de los fotogramas del trailer. Las claves de "desgaste"
	(MuroSucio, BaldosaGastada, Rayon, Oxido, PlacaSucia) sobreviven
	como variantes tonales suaves en vez de mugre: sirven para romper la
	uniformidad de una superficie grande sin ensuciarla.
--]]
Style.Color = {
	-- Atrio: crema calido con banda turquesa y piso salmon.
	MuroAlto = Color3.fromRGB(240, 230, 212),
	MuroBajo = Color3.fromRGB(86, 178, 176),      -- la banda turquesa
	MuroFranja = Color3.fromRGB(66, 152, 152),
	MuroSucio = Color3.fromRGB(232, 221, 202),

	-- Aula: verde salvia arriba, crema abajo.
	MuroAula = Color3.fromRGB(150, 172, 146),
	MuroAulaBajo = Color3.fromRGB(236, 228, 210),

	-- Techos.
	Placa = Color3.fromRGB(246, 240, 228),
	PlacaSucia = Color3.fromRGB(238, 231, 216),
	Rejilla = Color3.fromRGB(228, 224, 214),
	Losa = Color3.fromRGB(232, 226, 214),

	-- Piso del atrio: salmon calido en damero suave.
	Baldosa = Color3.fromRGB(218, 156, 132),
	BaldosaAlterna = Color3.fromRGB(208, 146, 122),
	BaldosaGastada = Color3.fromRGB(200, 140, 118),

	-- Piso del aula: tablones color miel.
	Tablon = Color3.fromRGB(206, 158, 102),
	TablonAlterno = Color3.fromRGB(194, 148, 96),

	-- Casilleros: celeste lavanda, el color que mas se ve en el atrio.
	Casillero = Color3.fromRGB(154, 180, 226),
	CasilleroLuz = Color3.fromRGB(172, 196, 236),
	Rayon = Color3.fromRGB(140, 166, 212),
	Oxido = Color3.fromRGB(196, 148, 120),
	Manija = Color3.fromRGB(228, 232, 238),

	-- Mobiliario.
	Madera = Color3.fromRGB(210, 166, 114),
	MaderaGastada = Color3.fromRGB(196, 152, 102),
	MaderaOscura = Color3.fromRGB(152, 106, 66),
	Metal = Color3.fromRGB(124, 132, 146),
	Asiento = Color3.fromRGB(92, 122, 190),

	-- Aula: pizarron verde con marco de madera grueso.
	Pizarra = Color3.fromRGB(56, 80, 64),
	MarcoPizarra = Color3.fromRGB(152, 106, 66),
	Pantalla = Color3.fromRGB(248, 246, 240),      -- la del proyector
	Tiza = Color3.fromRGB(244, 246, 240),

	-- Aberturas.
	Puerta = Color3.fromRGB(200, 134, 92),
	MarcoPuerta = Color3.fromRGB(236, 230, 218),
	MarcoVentana = Color3.fromRGB(244, 242, 236),
	Vidrio = Color3.fromRGB(214, 234, 244),

	-- La estatua del centro del atrio.
	Estatua = Color3.fromRGB(190, 188, 182),
	Pedestal = Color3.fromRGB(176, 172, 166),

	-- Detalles.
	Dorado = Color3.fromRGB(228, 184, 84),         -- tiradores de cajon
	Tubo = Color3.fromRGB(255, 250, 236),
	LuzCalida = Color3.fromRGB(255, 244, 218),
	LuzFria = Color3.fromRGB(255, 248, 232),
	Salida = Color3.fromRGB(226, 66, 54),
}

-- ── materiales ─────────────────────────────────────────────────────
--[[
	Casi todo `SmoothPlastic`. No es pereza: es la unica superficie
	realmente lisa de Roblox, y la referencia no tiene grano en ningun
	lado. `Neon` queda para lo que emite y `Glass` para el vidrio del
	ventanal, que es lo unico que deja pasar luz.
--]]
local FLAT = Enum.Material.SmoothPlastic

Style.Material = {
	MuroAlto = FLAT,
	MuroBajo = FLAT,
	Placa = FLAT,
	Rejilla = FLAT,
	Piso = FLAT,
	PisoGastado = FLAT,
	Casillero = FLAT,
	Oxido = FLAT,
	Madera = FLAT,
	MaderaLisa = FLAT,
	Metal = FLAT,
	MetalLiso = FLAT,
	Pizarra = FLAT,
	Tela = FLAT,
	Piedra = FLAT,
	Vidrio = Enum.Material.Glass,
	Neon = Enum.Material.Neon,
}

-- ── reflectancia ───────────────────────────────────────────────────
--[[
	Antes el piso encerado, el vidrio y las manijas reflejaban. En una
	imagen mate no refleja nada: un solo brillo especular delata el
	motor y rompe el dibujo. Queda apenas el vidrio.
--]]
Style.Reflectance = {
	Piso = 0,
	Casillero = 0,
	Pizarra = 0,
	Manija = 0,
	Vidrio = 0.1,
}

--- Aplica color + material + reflectancia de una sola vez.
function Style.paint(part: BasePart, color: Color3, material: Enum.Material, reflectance: number?)
	part.Color = color
	part.Material = material
	part.Reflectance = reflectance or 0
end

table.freeze(Style.Color)
table.freeze(Style.Material)
table.freeze(Style.Reflectance)

return Style

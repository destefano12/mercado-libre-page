--!nonstrict
-- Characters.luau — the roster. Colour schemes and a stage name, nothing that
-- changes the rules: no character scores better than another. Cosmetic only,
-- on purpose, so the wheel stays the only source of unfairness.

local Characters = {}

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local roster = {
	{ id = "duna",   name = "Duna",   tag = "la que nunca ensaya",      body = rgb(206, 170, 126), shirt = rgb(92, 64, 82),   pants = rgb(48, 42, 52),  accent = rgb(214, 160, 86) },
	{ id = "tito",   name = "Tito",   tag = "cree que afina",           body = rgb(176, 132, 98),  shirt = rgb(66, 86, 92),   pants = rgb(42, 48, 52),  accent = rgb(126, 174, 182) },
	{ id = "mora",   name = "Mora",   tag = "ataca primero",            body = rgb(228, 196, 164), shirt = rgb(104, 58, 58),  pants = rgb(52, 38, 38),  accent = rgb(192, 92, 92) },
	{ id = "rulo",   name = "Rulo",   tag = "especialista en pedos",     body = rgb(150, 112, 82),  shirt = rgb(74, 88, 58),   pants = rgb(44, 50, 38),  accent = rgb(146, 172, 110) },
	{ id = "sol",    name = "Sol",    tag = "melodía impecable",         body = rgb(238, 212, 184), shirt = rgb(112, 96, 56),  pants = rgb(56, 50, 36),  accent = rgb(226, 188, 74) },
	{ id = "nene",   name = "Nene",   tag = "solo hace ruidos",          body = rgb(124, 94, 72),   shirt = rgb(58, 62, 86),   pants = rgb(38, 40, 52),  accent = rgb(118, 128, 186) },
	{ id = "beba",   name = "Beba",   tag = "ritmo de metrónomo",        body = rgb(214, 180, 148), shirt = rgb(86, 70, 92),   pants = rgb(46, 40, 52),  accent = rgb(166, 134, 190) },
	{ id = "chino",  name = "Chino",  tag = "sabotea por deporte",       body = rgb(188, 146, 110), shirt = rgb(48, 52, 56),   pants = rgb(34, 36, 40),  accent = rgb(150, 145, 156) },
}

local byId = {}
for i, c in ipairs(roster) do
	c.order = i
	byId[c.id] = c
end

function Characters.all()
	return roster
end

function Characters.get(id)
	return byId[id]
end

function Characters.default()
	return roster[1]
end

-- Pick a character nobody in `taken` is using, so two players on stage are
-- never the same silhouette.
function Characters.firstFree(taken)
	for _, c in ipairs(roster) do
		if not taken[c.id] then
			return c
		end
	end
	return roster[1]
end

return Characters

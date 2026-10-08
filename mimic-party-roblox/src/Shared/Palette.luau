--!nonstrict
-- Palette.luau — a cartoon living room.
--
-- Taken from the reference footage: honey wood floor, warm red-brown walls, a
-- magenta rug, a big red armchair, string lights. Saturated and high-value —
-- every surface is unmistakably a colour, nothing sits near grey.
--
-- What does NOT change: nothing here flashes, strobes or animates. Bright is
-- not harsh. The light holds perfectly still through a round; it just does it
-- in colour.

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

return {
	-- Room
	Floor        = rgb(214, 148, 78),
	FloorDark    = rgb(178, 112, 54),
	Wall         = rgb(112, 54, 54),
	WallDark     = rgb(88, 40, 44),
	Skirting     = rgb(142, 74, 68),

	-- Rug
	RugOuter     = rgb(192, 62, 96),
	RugMid       = rgb(214, 92, 124),
	RugInner     = rgb(236, 130, 156),

	-- Furniture
	Chair        = rgb(226, 54, 58),
	ChairDark    = rgb(178, 36, 44),
	Speaker      = rgb(86, 102, 128),
	SpeakerDark  = rgb(58, 70, 92),
	SpeakerCone  = rgb(42, 44, 54),
	Plant        = rgb(74, 160, 92),
	PlantDark    = rgb(48, 120, 70),
	Pot          = rgb(206, 118, 76),
	Shelf        = rgb(166, 104, 56),
	Cat          = rgb(238, 232, 220),

	-- Metal and trim
	Trim         = rgb(252, 202, 88),
	TrimDark     = rgb(208, 150, 54),
	Chrome       = rgb(150, 154, 170),
	Dark         = rgb(44, 32, 38),

	-- Light
	Practical    = rgb(255, 226, 168),
	Wash         = rgb(255, 240, 212),
	Bulb         = rgb(255, 214, 128),

	-- Party accents, used for the string lights and the wheel.
	Pink         = rgb(244, 86, 150),
	Cyan         = rgb(86, 212, 226),
	Lime         = rgb(164, 222, 92),
	Violet       = rgb(168, 110, 232),
	Orange       = rgb(250, 148, 64),

	-- UI
	Ink          = rgb(30, 20, 28),
	Panel        = rgb(52, 32, 44),
	PanelRaised  = rgb(72, 46, 60),
	Hairline     = rgb(122, 82, 98),
	Cream        = rgb(255, 250, 240),
	Muted        = rgb(200, 168, 184),

	-- The two signature waveform colours.
	Reference    = rgb(255, 206, 72),
	Yours        = rgb(96, 226, 230),   -- the reference footage reads cyan
	CoreWarm     = rgb(255, 250, 226),
	CoreCool     = rgb(238, 255, 255),
	Playhead     = rgb(248, 68, 62),
	Well         = rgb(18, 14, 24),

	-- Scoreboard cards.
	CardBack     = rgb(58, 36, 50),
	CardLeader   = rgb(252, 202, 88),

	Good         = rgb(126, 226, 136),
	Warn         = rgb(252, 184, 72),
	Bad          = rgb(246, 86, 86),

	-- Aliases kept so older call sites still resolve.
	HouseFloor   = rgb(214, 148, 78),
	HouseWall    = rgb(112, 54, 54),
	Scrim        = rgb(88, 40, 44),
	Deck         = rgb(214, 148, 78),
	DeckDark     = rgb(178, 112, 54),
	Fascia       = rgb(142, 74, 68),
	Truss        = rgb(92, 88, 104),
	Curtain      = rgb(196, 54, 64),
	CurtainFold  = rgb(152, 34, 48),
	Valance      = rgb(224, 82, 88),
	Crowd        = rgb(92, 62, 74),
}

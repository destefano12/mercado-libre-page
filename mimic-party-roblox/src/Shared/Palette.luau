--!nonstrict
-- Palette.luau — a muted theatre palette. Warm woods, deep plum, brass, cream.
-- Deliberately low-contrast and low-saturation: no neon, no strobes, nothing
-- that fights the performance for attention.

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

return {
	-- Room
	HouseFloor   = rgb(38, 33, 36),
	HouseWall    = rgb(30, 27, 30),
	Scrim        = rgb(22, 20, 23),

	-- Stage
	Deck         = rgb(122, 86, 55),
	DeckDark     = rgb(92, 64, 41),
	Fascia       = rgb(46, 38, 38),
	Trim         = rgb(150, 116, 66),   -- brass
	TrimDark     = rgb(104, 79, 44),
	Truss        = rgb(44, 42, 45),

	-- Curtain
	Curtain      = rgb(84, 40, 56),
	CurtainFold  = rgb(66, 31, 45),
	Valance      = rgb(96, 48, 64),

	-- Crowd
	Crowd        = rgb(26, 24, 28),

	-- Light
	Practical    = rgb(255, 214, 160),
	Wash         = rgb(255, 228, 192),

	-- UI
	Ink          = rgb(18, 17, 20),
	Panel        = rgb(29, 28, 33),
	PanelRaised  = rgb(38, 37, 43),
	Hairline     = rgb(58, 56, 64),
	Cream        = rgb(238, 233, 224),
	Muted        = rgb(150, 145, 156),

	-- The two signature waveform colours, straight from the original.
	Reference    = rgb(226, 188, 74),   -- yellow — the sound you must match
	Yours        = rgb(118, 196, 128),  -- green  — your voice

	Good         = rgb(118, 196, 128),
	Warn         = rgb(214, 160, 86),
	Bad          = rgb(192, 92, 92),
}

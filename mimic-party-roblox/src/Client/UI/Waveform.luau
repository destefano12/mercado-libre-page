--!nonstrict
-- Waveform.luau — the two tracks: the reference above, your voice below.
--
-- Each track is a framed well: near-black inside, a bright hairline border in
-- the track's own colour, and the signal drawn symmetrically about the centre
-- line. Every bar carries a vertical gradient that burns from the track colour
-- at its edges to an almost-white core, so loudness reads as heat rather than
-- as height alone — which is what makes a quiet passage still legible.
--
-- A red playhead rides over both. It is the only red in the HUD and never
-- encodes a score, so it can never be confused with one.
--
-- The signature detail from the original is kept exactly: these show loudness
-- over time, not notes, and the pitch ribbon between them is what carries
-- contour.

local Theme = require(script.Parent.Theme)
local Palette = require(game.ReplicatedStorage.Shared.Palette)
local Config = require(game.ReplicatedStorage.Shared.Config)

local Waveform = {}
Waveform.__index = Waveform

local BARS = Config.TAKE.ENVELOPE_SAMPLES
local INSET = 7          -- breathing room inside the frame
local MIN_BAR = 0.035    -- a silent bar is still a tick, not nothing

-- Burns from the track colour at the extremes to a near-white core.
local function barGradient(accent, core)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, accent:Lerp(Palette.Ink, 0.45)),
		ColorSequenceKeypoint.new(0.28, accent),
		ColorSequenceKeypoint.new(0.50, core),
		ColorSequenceKeypoint.new(0.72, accent),
		ColorSequenceKeypoint.new(1.00, accent:Lerp(Palette.Ink, 0.45)),
	})
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, 0.55),
		NumberSequenceKeypoint.new(0.22, 0.08),
		NumberSequenceKeypoint.new(0.50, 0),
		NumberSequenceKeypoint.new(0.78, 0.08),
		NumberSequenceKeypoint.new(1.00, 0.55),
	})
	return g
end

-- `accent` is the track colour. `flipped` is accepted for call-site
-- compatibility and ignored: a mirrored track has no up or down.
function Waveform.new(parent, accent, flipped)
	local self = setmetatable({}, Waveform)
	self.accent = accent
	self.core = (accent == Palette.Yours) and Palette.CoreCool or Palette.CoreWarm

	-- ── the well ──
	self.root = Instance.new("Frame")
	self.root.BackgroundColor3 = Palette.Well
	self.root.BackgroundTransparency = 0.04
	self.root.BorderSizePixel = 0
	self.root.Size = UDim2.fromScale(1, 1)
	self.root.ClipsDescendants = true
	self.root.Parent = parent
	Theme.corner(self.root, UDim.new(0, 12))

	local edge = Instance.new("UIStroke")
	edge.Color = accent
	edge.Thickness = 1.6
	edge.Transparency = 0.34
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = self.root
	self.edge = edge

	-- A faint inner glow along the top and bottom, so the well has depth.
	local sheen = Instance.new("Frame")
	sheen.BackgroundColor3 = accent
	sheen.BackgroundTransparency = 0.94
	sheen.BorderSizePixel = 0
	sheen.Size = UDim2.fromScale(1, 1)
	sheen.Parent = self.root
	Theme.corner(sheen, UDim.new(0, 12))
	local sheenGradient = Instance.new("UIGradient")
	sheenGradient.Rotation = 90
	sheenGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0.3),
	})
	sheenGradient.Parent = sheen

	-- ── bars ──
	self.plot = Instance.new("Frame")
	self.plot.BackgroundTransparency = 1
	self.plot.Position = UDim2.fromOffset(INSET, INSET)
	self.plot.Size = UDim2.new(1, -INSET * 2, 1, -INSET * 2)
	self.plot.Parent = self.root

	local axis = Instance.new("Frame")
	axis.BackgroundColor3 = accent
	axis.BackgroundTransparency = 0.82
	axis.BorderSizePixel = 0
	axis.AnchorPoint = Vector2.new(0, 0.5)
	axis.Position = UDim2.fromScale(0, 0.5)
	axis.Size = UDim2.new(1, 0, 0, 1)
	axis.Parent = self.plot

	self.bars = table.create(BARS)
	local width = 1 / BARS
	for i = 1, BARS do
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = accent
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale((i - 0.5) * width, 0.5)
		bar.Size = UDim2.new(width * 0.68, 0, MIN_BAR, 0)
		bar.Parent = self.plot
		Theme.corner(bar, UDim.new(1, 0))
		barGradient(accent, self.core).Parent = bar
		self.bars[i] = bar
	end

	-- ── playhead ──
	self.head = Instance.new("Frame")
	self.head.BackgroundTransparency = 1
	self.head.AnchorPoint = Vector2.new(0.5, 0)
	self.head.Size = UDim2.new(0, 14, 1, 0)
	self.head.Visible = false
	self.head.Parent = self.root

	local halo = Instance.new("Frame")
	halo.BackgroundColor3 = Palette.Playhead
	halo.BackgroundTransparency = 0.78
	halo.BorderSizePixel = 0
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.Position = UDim2.fromScale(0.5, 0.5)
	halo.Size = UDim2.new(0, 10, 1, 0)
	halo.Parent = self.head
	Theme.corner(halo, UDim.new(0, 5))

	local line = Instance.new("Frame")
	line.BackgroundColor3 = Palette.Playhead
	line.BorderSizePixel = 0
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.fromScale(0.5, 0.5)
	line.Size = UDim2.new(0, 2, 1, 0)
	line.Parent = self.head

	return self
end

local function applyBar(self, bar, v)
	local level = math.clamp(v or 0, 0, 1)
	bar.Size = UDim2.new(bar.Size.X.Scale, 0, math.max(MIN_BAR, level * 0.96), 0)
	bar.BackgroundTransparency = level > 0 and 0 or 0.72
end

function Waveform:setEnvelope(envelope)
	for i, bar in ipairs(self.bars) do
		applyBar(self, bar, envelope and envelope[i] or 0)
	end
end

-- Used while recording: fills in left to right as the take happens.
function Waveform:setBar(index, value)
	local bar = self.bars[index]
	if bar then
		applyBar(self, bar, value)
	end
end

function Waveform:clear()
	for _, bar in ipairs(self.bars) do
		applyBar(self, bar, 0)
	end
	self:setPlayhead(nil)
end

function Waveform:setPlayhead(alpha)
	if alpha == nil then
		self.head.Visible = false
		return
	end
	self.head.Visible = true
	self.head.Position = UDim2.fromScale(math.clamp(alpha, 0, 1), 0)
end

-- Dims the whole well, for a track that is not the one being performed.
function Waveform:setActive(active)
	self.edge.Transparency = active and 0.2 or 0.55
	self.plot.Visible = true
end

function Waveform:destroy()
	self.root:Destroy()
end

-- ── pitch ribbon ─────────────────────────────────────────────────────────────
-- The reference contour as a line of dots, with the player's live pitch riding
-- on top of it. This is where melody lives; the tracks above and below are
-- loudness only.

local Ribbon = {}
Ribbon.__index = Ribbon
Waveform.Ribbon = Ribbon

function Ribbon.new(parent)
	local self = setmetatable({}, Ribbon)
	self.root = Instance.new("Frame")
	self.root.BackgroundTransparency = 1
	self.root.Size = UDim2.fromScale(1, 1)
	self.root.ClipsDescendants = true
	self.root.Parent = parent

	self.dots = table.create(BARS)
	for i = 1, BARS do
		local dot = Instance.new("Frame")
		dot.BackgroundColor3 = Palette.Reference
		dot.BackgroundTransparency = 1
		dot.BorderSizePixel = 0
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Size = UDim2.fromOffset(3, 3)
		dot.Parent = self.root
		Theme.corner(dot, UDim.new(1, 0))
		self.dots[i] = dot
	end

	self.cursor = Instance.new("Frame")
	self.cursor.BackgroundColor3 = Palette.Yours
	self.cursor.BorderSizePixel = 0
	self.cursor.AnchorPoint = Vector2.new(0.5, 0.5)
	self.cursor.Size = UDim2.fromOffset(12, 12)
	self.cursor.Visible = false
	self.cursor.Parent = self.root
	Theme.corner(self.cursor, UDim.new(1, 0))
	Theme.stroke(self.cursor, Palette.Ink, 2, 0.15)

	return self
end

local function pitchToScale(pitch)
	return 0.5 - (pitch / (Config.TAKE.PITCH_RANGE * 2))
end

function Ribbon:setReference(notes, duration)
	for i, dot in ipairs(self.dots) do
		local t = (i - 0.5) / #self.dots * duration
		local pitch, voiced = 0, false
		for _, n in ipairs(notes) do
			if t >= n.t and t <= n.t + n.dur then
				pitch, voiced = n.pitch, true
				break
			end
		end
		dot.Position = UDim2.fromScale((i - 0.5) / #self.dots, pitchToScale(pitch))
		dot.BackgroundTransparency = voiced and 0.1 or 1
	end
end

function Ribbon:setCursor(alpha, pitch, voiced)
	self.cursor.Visible = voiced == true
	self.cursor.Position = UDim2.fromScale(math.clamp(alpha, 0, 1), pitchToScale(pitch or 0))
end

function Ribbon:destroy()
	self.root:Destroy()
end

return Waveform

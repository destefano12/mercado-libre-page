--!nonstrict
-- Waveform.luau — the two tracks: yellow reference above, green voice below.
--
-- Bars are plain Frames, pooled and reused. The signature detail from the
-- original is preserved exactly: these show loudness over time, not notes, and
-- the pitch ribbon that sits between them is what carries contour.

local Theme = require(script.Parent.Theme)
local Palette = require(game.ReplicatedStorage.Shared.Palette)
local Config = require(game.ReplicatedStorage.Shared.Config)

local Waveform = {}
Waveform.__index = Waveform

local BARS = Config.TAKE.ENVELOPE_SAMPLES

function Waveform.new(parent, color, flipped)
	local self = setmetatable({}, Waveform)

	self.root = Instance.new("Frame")
	self.root.BackgroundTransparency = 1
	self.root.Size = UDim2.fromScale(1, 1)
	self.root.ClipsDescendants = true
	self.root.Parent = parent

	-- Centre line: gives a silent track something to be, instead of nothing.
	local axis = Instance.new("Frame")
	axis.BackgroundColor3 = Palette.Hairline
	axis.BackgroundTransparency = 0.55
	axis.BorderSizePixel = 0
	axis.Size = UDim2.new(1, 0, 0, 1)
	axis.Position = flipped and UDim2.fromScale(0, 0) or UDim2.new(0, 0, 1, -1)
	axis.Parent = self.root

	self.bars = table.create(BARS)
	local width = 1 / BARS
	for i = 1, BARS do
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = color
		bar.BorderSizePixel = 0
		bar.AnchorPoint = flipped and Vector2.new(0, 0) or Vector2.new(0, 1)
		bar.Position = UDim2.fromScale((i - 1) * width, flipped and 0 or 1)
		bar.Size = UDim2.new(width * 0.76, 0, 0, 0)
		bar.BackgroundTransparency = 0.25
		bar.Parent = self.root
		Theme.corner(bar, UDim.new(0, 2))
		self.bars[i] = bar
	end

	self.playhead = Instance.new("Frame")
	self.playhead.BackgroundColor3 = Palette.Cream
	self.playhead.BackgroundTransparency = 0.45
	self.playhead.BorderSizePixel = 0
	self.playhead.Size = UDim2.new(0, 1, 1, 0)
	self.playhead.Visible = false
	self.playhead.Parent = self.root

	self.color = color
	return self
end

function Waveform:setEnvelope(envelope)
	for i, bar in ipairs(self.bars) do
		local v = envelope and envelope[i] or 0
		bar.Size = UDim2.new(bar.Size.X.Scale, 0, v * 0.94, 0)
		bar.BackgroundTransparency = v > 0 and 0.12 or 0.82
	end
end

-- Used while recording: fills in left to right as the take happens.
function Waveform:setBar(index, value)
	local bar = self.bars[index]
	if bar then
		bar.Size = UDim2.new(bar.Size.X.Scale, 0, math.clamp(value, 0, 1) * 0.94, 0)
		bar.BackgroundTransparency = value > 0 and 0.12 or 0.82
	end
end

function Waveform:clear()
	for _, bar in ipairs(self.bars) do
		bar.Size = UDim2.new(bar.Size.X.Scale, 0, 0, 0)
		bar.BackgroundTransparency = 0.82
	end
end

function Waveform:setPlayhead(alpha)
	if alpha == nil then
		self.playhead.Visible = false
		return
	end
	self.playhead.Visible = true
	self.playhead.Position = UDim2.fromScale(math.clamp(alpha, 0, 1), 0)
end

function Waveform:destroy()
	self.root:Destroy()
end

-- The ribbon between the two tracks: reference contour drawn as a line of dots,
-- with the player's live pitch riding on top of it.
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
	self.cursor.Size = UDim2.fromOffset(11, 11)
	self.cursor.Visible = false
	self.cursor.Parent = self.root
	Theme.corner(self.cursor, UDim.new(1, 0))
	Theme.stroke(self.cursor, Palette.Ink, 2, 0.2)

	return self
end

local function pitchToScale(pitch)
	-- Centre is 0 semitones; the full strip spans ±PITCH_RANGE.
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

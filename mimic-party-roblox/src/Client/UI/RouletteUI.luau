--!nonstrict
-- RouletteUI.luau — the wheel. One spin, the whole table at once.
--
-- Built as a ring of segment chips rather than a rendered disc: it stays
-- readable at any resolution, it tells you the odds by showing every outcome,
-- and the deceleration curve is the only animation in the game that is allowed
-- to be showy.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Palette = require(game.ReplicatedStorage.Shared.Palette)
local Roulette = require(game.ReplicatedStorage.Shared.Roulette)
local Sabotages = require(game.ReplicatedStorage.Shared.Sabotages)

local RouletteUI = {}
RouletteUI.__index = RouletteUI

local function colorFor(kind)
	if kind == "points" then return Palette.Reference end
	if kind == "multiplier" then return Palette.Yours end
	if kind == "sabotage" then return Palette.Bad end
	return Palette.Muted
end

function RouletteUI.new(parent)
	local self = setmetatable({}, RouletteUI)

	self.root = Instance.new("Frame")
	self.root.BackgroundTransparency = 1
	self.root.AnchorPoint = Vector2.new(0.5, 0.5)
	self.root.Position = UDim2.fromScale(0.5, 0.46)
	self.root.Size = UDim2.fromOffset(620, 420)
	self.root.Visible = false
	self.root.Parent = parent

	local panel = Theme.panel(self.root, { BackgroundTransparency = 0.04 })
	Theme.pad(panel, 20)
	self.panel = panel

	Theme.title(panel, "LA RULETA", { Size = UDim2.new(1, 0, 0, 30), TextSize = 22 })
	Theme.caption(panel, "Gira una vez para toda la mesa.", {
		Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, 0, 0, 16),
	})

	-- The ring.
	self.ring = Instance.new("Frame")
	self.ring.BackgroundTransparency = 1
	self.ring.AnchorPoint = Vector2.new(0.5, 0)
	self.ring.Position = UDim2.new(0.5, 0, 0, 56)
	self.ring.Size = UDim2.fromOffset(260, 260)
	self.ring.Parent = panel

	self.segments = {}
	local defs = Roulette.segments()
	for i, seg in ipairs(defs) do
		local angle = (i - 1) / #defs * math.pi * 2
		local chip = Instance.new("TextLabel")
		chip.AnchorPoint = Vector2.new(0.5, 0.5)
		chip.Position = UDim2.fromScale(0.5 + math.sin(angle) * 0.42, 0.5 - math.cos(angle) * 0.42)
		chip.Size = UDim2.fromOffset(92, 26)
		chip.BackgroundColor3 = Palette.PanelRaised
		chip.BackgroundTransparency = 0.3
		chip.BorderSizePixel = 0
		chip.Text = seg.label
		chip.TextColor3 = colorFor(seg.kind)
		chip.TextSize = 12
		chip.FontFace = Theme.Font.Medium
		chip.Parent = self.ring
		Theme.corner(chip, UDim.new(0, 6))
		self.segments[i] = chip
	end

	-- Hub and needle.
	local hub = Instance.new("Frame")
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromScale(0.5, 0.5)
	hub.Size = UDim2.fromOffset(104, 104)
	hub.BackgroundColor3 = Palette.Ink
	hub.BorderSizePixel = 0
	hub.Parent = self.ring
	Theme.corner(hub, UDim.new(1, 0))
	Theme.stroke(hub, Palette.TrimDark, 2, 0.1)

	self.needle = Instance.new("Frame")
	self.needle.AnchorPoint = Vector2.new(0.5, 1)
	self.needle.Position = UDim2.fromScale(0.5, 0.5)
	self.needle.Size = UDim2.fromOffset(3, 104)
	self.needle.BackgroundColor3 = Palette.Trim
	self.needle.BorderSizePixel = 0
	self.needle.Parent = self.ring
	Theme.corner(self.needle, UDim.new(1, 0))

	self.result = Theme.label(hub, "", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.5),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true,
		FontFace = Theme.Font.Display,
	})

	-- Per-player outcome strip.
	self.outcomes = Instance.new("Frame")
	self.outcomes.BackgroundTransparency = 1
	self.outcomes.Position = UDim2.new(0, 0, 0, 326)
	self.outcomes.Size = UDim2.new(1, 0, 0, 54)
	self.outcomes.Parent = panel
	Theme.list(self.outcomes, 6, Enum.FillDirection.Horizontal)

	return self
end

-- `results` is the server's list; `localUserId` decides which card is yours.
function RouletteUI:spin(results, seconds, localUserId)
	self.root.Visible = true
	self.result.Text = ""

	for _, child in ipairs(self.outcomes:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local mine
	for _, r in ipairs(results) do
		if r.userId == localUserId then
			mine = r
		end
	end

	local count = #Roulette.segments()
	local landing = mine and mine.segmentIndex or 1
	-- Five full turns plus the landing offset, decelerating into place.
	local degrees = 360 * 5 + (landing - 1) / count * 360

	self.needle.Rotation = 0
	local tween = TweenService:Create(self.needle, TweenInfo.new(
		seconds * 0.82, Enum.EasingStyle.Quint, Enum.EasingDirection.Out
	), { Rotation = degrees })
	tween:Play()

	task.delay(seconds * 0.84, function()
		if not self.root.Visible then
			return
		end
		for i, chip in ipairs(self.segments) do
			chip.BackgroundTransparency = (i == landing) and 0 or 0.55
			chip.TextTransparency = (i == landing) and 0 or 0.35
		end
		if mine then
			self.result.Text = mine.label
			self.result.TextColor3 = colorFor(mine.kind)
		end

		for _, r in ipairs(results) do
			local card = Theme.panel(self.outcomes, {
				Size = UDim2.new(0, 112, 1, 0),
				BackgroundTransparency = 0.3,
			})
			Theme.pad(card, 8)
			Theme.caption(card, r.name, { Size = UDim2.new(1, 0, 0, 14), TextSize = 11,
				TextTruncate = Enum.TextTruncate.AtEnd })
			Theme.label(card, r.label, {
				Position = UDim2.new(0, 0, 0, 16),
				Size = UDim2.new(1, 0, 0, 18),
				TextSize = 14,
				FontFace = Theme.Font.Display,
				TextColor3 = colorFor(r.kind),
			})
		end
	end)
end

-- The aiming window: only shown to a player who actually won a sabotage.
function RouletteUI:showTargetPicker(sabotageId, candidates, onPick)
	local def = Sabotages.get(sabotageId)
	self.picker = Theme.panel(self.root, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(560, 118),
		BackgroundTransparency = 0.02,
	})
	Theme.pad(self.picker, 14)

	Theme.title(self.picker, ("ELEGÍ A QUIÉN · %s"):format(def and def.name:upper() or "SABOTAJE"), {
		Size = UDim2.new(1, 0, 0, 22), TextSize = 17, TextColor3 = Palette.Bad,
	})
	Theme.caption(self.picker, def and def.blurb or "", {
		Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, 0, 0, 14),
	})

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.new(0, 0, 0, 44)
	row.Size = UDim2.new(1, 0, 0, 44)
	row.Parent = self.picker
	Theme.list(row, 8, Enum.FillDirection.Horizontal)

	for _, candidate in ipairs(candidates) do
		Theme.button(row, candidate.name, function()
			if onPick then
				onPick(candidate.userId)
			end
			self:hideTargetPicker()
		end, { Size = UDim2.new(0, 128, 1, 0), TextSize = 14 })
	end
end

function RouletteUI:hideTargetPicker()
	if self.picker then
		self.picker:Destroy()
		self.picker = nil
	end
end

function RouletteUI:hide()
	self.root.Visible = false
	self:hideTargetPicker()
	for _, chip in ipairs(self.segments) do
		chip.BackgroundTransparency = 0.3
		chip.TextTransparency = 0
	end
end

return RouletteUI

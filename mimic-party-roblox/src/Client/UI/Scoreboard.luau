--!nonstrict
-- Scoreboard.luau — standings, always on screen, never in the way.
-- Rows reorder with a tween so overtakes are visible rather than instant.

local Theme = require(script.Parent.Theme)
local Palette = require(game.ReplicatedStorage.Shared.Palette)
local Characters = require(game.ReplicatedStorage.Shared.Characters)

local Scoreboard = {}
Scoreboard.__index = Scoreboard

local ROW_H = 38

function Scoreboard.new(parent)
	local self = setmetatable({}, Scoreboard)

	self.root = Theme.panel(parent, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -22, 0, 22),
		Size = UDim2.fromOffset(268, 60),
		BackgroundTransparency = 0.12,
	})
	Theme.pad(self.root, 12)

	Theme.caption(self.root, "EN ESCENA", { Size = UDim2.new(1, 0, 0, 14), TextSize = 11 })

	self.list = Instance.new("Frame")
	self.list.BackgroundTransparency = 1
	self.list.Position = UDim2.new(0, 0, 0, 22)
	self.list.Size = UDim2.new(1, 0, 1, -22)
	self.list.Parent = self.root

	self.rows = {}
	return self
end

local function buildRow(parent)
	local row = Instance.new("Frame")
	row.BackgroundColor3 = Palette.PanelRaised
	row.BackgroundTransparency = 0.45
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, 0, 0, ROW_H - 6)
	row.Parent = parent
	Theme.corner(row, UDim.new(0, 7))

	local chip = Instance.new("Frame")
	chip.BackgroundColor3 = Palette.Muted
	chip.BorderSizePixel = 0
	chip.Position = UDim2.new(0, 8, 0.5, -9)
	chip.Size = UDim2.fromOffset(4, 18)
	chip.Parent = row
	Theme.corner(chip, UDim.new(1, 0))

	local name = Theme.label(row, "", {
		Position = UDim2.new(0, 20, 0, 0),
		Size = UDim2.new(1, -96, 1, 0),
		TextSize = 14,
		FontFace = Theme.Font.Medium,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local score = Theme.label(row, "0", {
		Position = UDim2.new(1, -78, 0, 0),
		Size = UDim2.fromOffset(70, ROW_H - 6),
		TextXAlignment = Enum.TextXAlignment.Right,
		FontFace = Theme.Font.Mono,
		TextSize = 15,
	})

	return { frame = row, chip = chip, name = name, score = score }
end

function Scoreboard:update(scores)
	scores = scores or {}

	for i, entry in ipairs(scores) do
		local row = self.rows[i]
		if not row then
			row = buildRow(self.list)
			self.rows[i] = row
		end

		local character = Characters.get(entry.characterId)
		row.chip.BackgroundColor3 = character and character.accent or Palette.Muted

		local mult = (entry.multiplier and entry.multiplier > 1)
			and (" <font color='#D6A056'>×%s</font>"):format(entry.multiplier)
			or ""
		row.name.Text = entry.name .. mult
		row.score.Text = tostring(entry.score)
		row.frame.Visible = true
		row.frame:TweenPosition(UDim2.new(0, 0, 0, (i - 1) * ROW_H), Enum.EasingDirection.Out,
			Enum.EasingStyle.Quart, 0.4, true)
	end

	for i = #scores + 1, #self.rows do
		self.rows[i].frame.Visible = false
	end

	self.root.Size = UDim2.fromOffset(268, 34 + math.max(#scores, 1) * ROW_H + 12)
end

return Scoreboard

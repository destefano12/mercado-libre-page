--!nonstrict
-- Theme.luau — the UI kit. Every pixel in this game is built from these.
--
-- House style: dark panels, one hairline, generous padding, two type weights,
-- and colour used only to carry meaning (yellow = reference, green = you,
-- red = damage). No gradients that pulse, no glow, no pure white.

local Palette = require(game.ReplicatedStorage.Shared.Palette)

local Theme = {}

Theme.Palette = Palette
Theme.CORNER = UDim.new(0, 10)
Theme.PAD = 14

local function font(enum)
	return Font.fromEnum(enum)
end

Theme.Font = {
	Display = font(Enum.Font.GothamBold),
	Body = font(Enum.Font.Gotham),
	Medium = font(Enum.Font.GothamMedium),
	Mono = font(Enum.Font.Code),
}

function Theme.corner(instance, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or Theme.CORNER
	c.Parent = instance
	return c
end

function Theme.stroke(instance, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or Palette.Hairline
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0.25
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = instance
	return s
end

function Theme.pad(instance, amount)
	local p = Instance.new("UIPadding")
	local v = UDim.new(0, amount or Theme.PAD)
	p.PaddingTop, p.PaddingBottom, p.PaddingLeft, p.PaddingRight = v, v, v, v
	p.Parent = instance
	return p
end

-- A panel: the base surface everything else sits on.
function Theme.panel(parent, props)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Palette.Panel
	f.BackgroundTransparency = 0.06
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	if props then
		for k, v in pairs(props) do
			f[k] = v
		end
	end
	f.Parent = parent
	Theme.corner(f)
	Theme.stroke(f)

	-- A barely-there vertical gradient so a large panel does not read flat.
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(Palette.PanelRaised, Palette.Panel)
	g.Parent = f
	return f
end

function Theme.label(parent, text, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text or ""
	l.TextColor3 = Palette.Cream
	l.FontFace = Theme.Font.Body
	l.TextSize = 16
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.RichText = true
	l.Size = UDim2.new(1, 0, 0, 20)
	if props then
		for k, v in pairs(props) do
			l[k] = v
		end
	end
	l.Parent = parent
	return l
end

function Theme.title(parent, text, props)
	local merged = { FontFace = Theme.Font.Display, TextSize = 26, TextColor3 = Palette.Cream }
	if props then
		for k, v in pairs(props) do
			merged[k] = v
		end
	end
	return Theme.label(parent, text, merged)
end

function Theme.caption(parent, text, props)
	local merged = { TextSize = 13, TextColor3 = Palette.Muted, FontFace = Theme.Font.Medium }
	if props then
		for k, v in pairs(props) do
			merged[k] = v
		end
	end
	return Theme.label(parent, text, merged)
end

-- A button with a real pressed state. No tween on hover that outlives the
-- cursor; everything settles in under 120ms.
function Theme.button(parent, text, onClick, props)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = Palette.PanelRaised
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Text = text
	b.TextColor3 = Palette.Cream
	b.FontFace = Theme.Font.Medium
	b.TextSize = 16
	b.Size = UDim2.new(1, 0, 0, 42)
	if props then
		for k, v in pairs(props) do
			b[k] = v
		end
	end
	b.Parent = parent
	Theme.corner(b, UDim.new(0, 8))
	local stroke = Theme.stroke(b, Palette.Hairline, 1, 0.2)

	local base = b.BackgroundColor3
	b.MouseEnter:Connect(function()
		b.BackgroundColor3 = base:Lerp(Palette.Cream, 0.07)
		stroke.Transparency = 0
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = base
		stroke.Transparency = 0.2
	end)
	b.MouseButton1Down:Connect(function()
		b.BackgroundColor3 = base:Lerp(Color3.new(0, 0, 0), 0.25)
	end)
	b.MouseButton1Up:Connect(function()
		b.BackgroundColor3 = base
	end)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

function Theme.list(parent, padding, direction)
	local l = Instance.new("UIListLayout")
	l.FillDirection = direction or Enum.FillDirection.Vertical
	l.Padding = UDim.new(0, padding or 8)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
	return l
end

-- A thin meter used for the three scoring axes.
function Theme.meter(parent, label, color)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 30)
	row.Parent = parent

	Theme.caption(row, label, { Size = UDim2.new(0, 96, 1, 0) })

	local track = Instance.new("Frame")
	track.BackgroundColor3 = Palette.Ink
	track.BorderSizePixel = 0
	track.Position = UDim2.new(0, 102, 0.5, -4)
	track.Size = UDim2.new(1, -160, 0, 8)
	track.Parent = row
	Theme.corner(track, UDim.new(1, 0))

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = color or Palette.Yours
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = track
	Theme.corner(fill, UDim.new(1, 0))

	local value = Theme.label(row, "0", {
		Size = UDim2.new(0, 52, 1, 0),
		Position = UDim2.new(1, -52, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		FontFace = Theme.Font.Mono,
		TextSize = 15,
	})

	return {
		set = function(score, max)
			local alpha = math.clamp(score / (max or 1000), 0, 1)
			fill:TweenSize(UDim2.fromScale(alpha, 1), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.45, true)
			value.Text = tostring(score)
		end,
	}
end

return Theme

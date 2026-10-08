--!nonstrict
-- Scoreboard.luau — the row of player cards across the top of the screen.
--
-- One card per player: their character's face, their name under it, and their
-- running total under that. When a take is scored the points that take earned
-- fly up off the card as "+120" and the total counts up to meet them, so you
-- can see where a number came from instead of watching a figure change.
--
-- The portrait is a ViewportFrame holding a clone of that player's actual
-- avatar, framed on the head. That is how you get a real face in a Roblox UI
-- without uploading a single image, and it means the card shows whoever the
-- player actually is rather than a stand-in.
--
-- Cards sit in stage order, not score order, so each one is above the person it
-- belongs to. The leader is marked with a gold edge instead of being moved,
-- because a row that reshuffles mid-round is unreadable.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Theme)
local Palette = require(game.ReplicatedStorage.Shared.Palette)
local Characters = require(game.ReplicatedStorage.Shared.Characters)

local Scoreboard = {}
Scoreboard.__index = Scoreboard

local CARD_W, CARD_H = 128, 158
local PORTRAIT = 104
local GAP = 10

-- ── portrait ─────────────────────────────────────────────────────────────────

local function clearViewport(vp)
	for _, child in ipairs(vp:GetChildren()) do
		if not child:IsA("Camera") then
			child:Destroy()
		end
	end
end

-- Clones the player's avatar into the viewport and frames it on the head.
-- Returns false when there is nothing to clone yet, so the caller can fall back.
local function buildPortrait(vp, player)
	local character = player and player.Character
	if not character then
		return false
	end
	local head = character:FindFirstChild("Head")
	if not head then
		return false
	end

	local ok, clone = pcall(function()
		return character:Clone()
	end)
	if not ok or not clone then
		return false
	end

	-- Strip anything that would try to run, make noise, or draw a second name
	-- tag inside the card.
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("BillboardGui")
			or d:IsA("ParticleEmitter") or d:IsA("Light") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
		end
	end

	clearViewport(vp)
	clone.Parent = vp

	local clonedHead = clone:FindFirstChild("Head")
	if not clonedHead then
		clone:Destroy()
		return false
	end

	local camera = vp.CurrentCamera
	if not camera then
		camera = Instance.new("Camera")
		camera.Parent = vp
		vp.CurrentCamera = camera
	end
	-- Slightly above eye level and a little off-axis: a portrait, not a mugshot.
	local focus = clonedHead.Position + Vector3.new(0, 0.12, 0)
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(0.55, 0.35, 2.75), focus)
	camera.FieldOfView = 34

	return true
end

-- ── card ─────────────────────────────────────────────────────────────────────

local function buildCard(parent, index)
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Palette.CardBack
	card.BackgroundTransparency = 0.06
	card.BorderSizePixel = 0
	card.Size = UDim2.fromOffset(CARD_W, CARD_H)
	card.LayoutOrder = index
	card.Parent = parent
	Theme.corner(card, UDim.new(0, 12))
	local stroke = Theme.stroke(card, Palette.Hairline, 1, 0.2)

	-- The character's accent, as a cap across the top of the card.
	local accent = Instance.new("Frame")
	accent.BackgroundColor3 = Palette.Muted
	accent.BorderSizePixel = 0
	accent.Size = UDim2.new(1, 0, 0, 3)
	accent.Parent = card
	Theme.corner(accent, UDim.new(0, 3))

	-- Portrait well.
	local well = Instance.new("Frame")
	well.BackgroundColor3 = Palette.Well
	well.BackgroundTransparency = 0.1
	well.BorderSizePixel = 0
	well.Position = UDim2.fromOffset((CARD_W - PORTRAIT) / 2, 10)
	well.Size = UDim2.fromOffset(PORTRAIT, PORTRAIT)
	well.ClipsDescendants = true
	well.Parent = card
	Theme.corner(well, UDim.new(0, 9))

	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.Ambient = Color3.fromRGB(168, 158, 150)
	vp.LightColor = Palette.Practical
	vp.LightDirection = Vector3.new(-0.4, -0.8, -0.5)
	vp.Parent = well

	-- Shown until an avatar is available to clone.
	local initial = Theme.label(well, "", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 40,
		FontFace = Theme.Font.Display,
		TextColor3 = Palette.Muted,
	})

	local name = Theme.label(card, "", {
		Position = UDim2.new(0, 6, 0, 118),
		Size = UDim2.new(1, -12, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 13,
		FontFace = Theme.Font.Medium,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local score = Theme.label(card, "0", {
		Position = UDim2.new(0, 6, 0, 134),
		Size = UDim2.new(1, -12, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 19,
		FontFace = Theme.Font.Mono,
	})

	-- The points a take just earned, flying up off the card.
	local delta = Theme.label(card, "", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 134),
		Size = UDim2.fromOffset(CARD_W, 26),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 19,
		FontFace = Theme.Font.Display,
		TextTransparency = 1,
	})

	local mult = Theme.label(card, "", {
		Position = UDim2.new(0, 0, 0, 10),
		Size = UDim2.fromOffset(CARD_W - 8, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 13,
		FontFace = Theme.Font.Display,
		TextColor3 = Palette.Warn,
	})

	return {
		frame = card, stroke = stroke, accent = accent, vp = vp, well = well,
		initial = initial, name = name, score = score, delta = delta, mult = mult,
		shown = 0, target = 0, portraitOf = nil,
	}
end

-- ── public ───────────────────────────────────────────────────────────────────

function Scoreboard.new(parent)
	local self = setmetatable({}, Scoreboard)

	self.root = Instance.new("Frame")
	self.root.BackgroundTransparency = 1
	self.root.AnchorPoint = Vector2.new(0.5, 0)
	self.root.Position = UDim2.new(0.5, 0, 0, 14)
	self.root.Size = UDim2.fromOffset(CARD_W, CARD_H)
	self.root.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = self.root

	self.cards = {}
	self.byUser = {}

	-- Totals ease toward their target rather than snapping, so a jump of 900 is
	-- visibly bigger than a jump of 90.
	self._tick = RunService.RenderStepped:Connect(function(dt)
		for _, card in ipairs(self.cards) do
			if card.shown ~= card.target then
				local step = math.max(1, math.abs(card.target - card.shown) * math.min(1, dt * 7))
				if math.abs(card.target - card.shown) <= step then
					card.shown = card.target
				else
					card.shown += step * (card.target > card.shown and 1 or -1)
				end
				card.score.Text = tostring(math.floor(card.shown + 0.5))
			end
		end
	end)

	return self
end

function Scoreboard:_card(index)
	local card = self.cards[index]
	if not card then
		card = buildCard(self.root, index)
		self.cards[index] = card
	end
	return card
end

function Scoreboard:update(scores)
	scores = scores or {}

	-- Stage order, so a card sits above the person it belongs to. Score order
	-- would reshuffle the row every round and nobody could follow it.
	local ordered = table.clone(scores)
	table.sort(ordered, function(a, b)
		local am, bm = a.markIndex or 99, b.markIndex or 99
		if am == bm then
			return (a.name or "") < (b.name or "")
		end
		return am < bm
	end)

	local best = 0
	for _, entry in ipairs(ordered) do
		best = math.max(best, entry.score or 0)
	end

	table.clear(self.byUser)

	for i, entry in ipairs(ordered) do
		local card = self:_card(i)
		local character = Characters.get(entry.characterId)
		local accent = character and character.accent or Palette.Muted
		local leader = (entry.score or 0) == best and best > 0

		card.frame.Visible = true
		card.accent.BackgroundColor3 = accent
		card.name.Text = entry.name or "?"
		card.mult.Text = (entry.multiplier and entry.multiplier > 1)
			and ("×%s"):format(entry.multiplier) or ""
		card.target = entry.score or 0
		card.score.TextColor3 = leader and Palette.CardLeader or Palette.Cream
		card.stroke.Color = leader and Palette.CardLeader or Palette.Hairline
		card.stroke.Transparency = leader and 0.1 or 0.2

		-- Portrait, rebuilt only when that player's avatar actually changed.
		local player = Players:GetPlayerByUserId(entry.userId)
		local currentCharacter = player and player.Character
		if currentCharacter ~= card.portraitOf then
			if buildPortrait(card.vp, player) then
				card.portraitOf = currentCharacter
				card.initial.Text = ""
			else
				card.portraitOf = nil
				clearViewport(card.vp)
				card.initial.Text = (entry.name or "?"):sub(1, 1):upper()
				card.initial.TextColor3 = accent
			end
		end

		self.byUser[entry.userId] = card
	end

	for i = #ordered + 1, #self.cards do
		self.cards[i].frame.Visible = false
	end

	local count = math.max(#ordered, 1)
	self.root.Size = UDim2.fromOffset(count * CARD_W + (count - 1) * GAP, CARD_H)
end

-- Called when a take is scored: the points fly up and the total climbs to meet
-- them. This is the whole reason the card shows a number at all.
function Scoreboard:award(userId, amount)
	local card = self.byUser[userId]
	if not card or not amount or amount == 0 then
		return
	end

	card.delta.Text = (amount > 0 and "+" or "") .. tostring(amount)
	card.delta.TextColor3 = amount > 0 and Palette.Good or Palette.Bad
	card.delta.TextTransparency = 0
	card.delta.Position = UDim2.new(0.5, 0, 0, 134)

	TweenService:Create(card.delta, TweenInfo.new(1.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 96),
		TextTransparency = 1,
	}):Play()

	-- A quick pulse on the card edge, so the eye lands on the right one.
	local stroke = card.stroke
	local was = stroke.Color
	stroke.Color = amount > 0 and Palette.Good or Palette.Bad
	stroke.Transparency = 0
	TweenService:Create(stroke, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {
		Transparency = 0.2,
	}):Play()
	task.delay(0.8, function()
		if stroke.Parent then
			stroke.Color = was
		end
	end)
end

function Scoreboard:setVisible(visible)
	self.root.Visible = visible
end

function Scoreboard:destroy()
	if self._tick then
		self._tick:Disconnect()
	end
	self.root:Destroy()
end

return Scoreboard

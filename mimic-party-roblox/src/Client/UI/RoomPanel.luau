--!nonstrict
-- RoomPanel.luau — create a room, join one by code, and host controls.
--
-- Two states, and the panel is only ever in one of them:
--
--   public server  →  CREAR SALA, plus a code field to join someone else's
--   inside a room  →  the code, big enough to read out loud over voice chat,
--                     the roster, and — for the host only — pack toggles and a
--                     remove button per player
--
-- Non-hosts see the same roster and the same pack state, greyed out. Hiding it
-- would leave four people guessing why a pack vanished mid-party.

local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)
local Palette = require(game.ReplicatedStorage.Shared.Palette)
local Rooms = require(game.ReplicatedStorage.Shared.Rooms)

local RoomPanel = {}
RoomPanel.__index = RoomPanel

local localPlayer = Players.LocalPlayer

function RoomPanel.new(parent, callbacks)
	local self = setmetatable({}, RoomPanel)
	self.callbacks = callbacks or {}

	self.root = Theme.panel(parent, {
		Position = UDim2.new(0, 34, 0, 490),
		Size = UDim2.fromOffset(1074, 196),
		BackgroundTransparency = 0.06,
	})
	Theme.pad(self.root, 16)

	-- ── left: code / create-join ──
	local left = Instance.new("Frame")
	left.BackgroundTransparency = 1
	left.Size = UDim2.fromOffset(330, 164)
	left.Parent = self.root

	self.headline = Theme.caption(left, "SALA", { Size = UDim2.new(1, 0, 0, 14), TextSize = 11 })

	-- The code, when we are in a room. Monospaced and large: somebody is going
	-- to read this out loud over voice chat.
	self.codeLabel = Theme.label(left, "", {
		Position = UDim2.new(0, 0, 0, 20),
		Size = UDim2.new(1, 0, 0, 52),
		TextSize = 46,
		FontFace = Theme.Font.Mono,
		TextColor3 = Palette.Reference,
		Visible = false,
	})
	self.codeHint = Theme.caption(left, "", {
		Position = UDim2.new(0, 0, 0, 74),
		Size = UDim2.new(1, 0, 0, 28),
		TextSize = 11,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Visible = false,
	})

	-- Create / join, when we are not.
	self.createButton = Theme.button(left, "CREAR SALA", function()
		if self.callbacks.onCreate then
			self.callbacks.onCreate()
		end
	end, {
		Position = UDim2.new(0, 0, 0, 22),
		Size = UDim2.fromOffset(330, 44),
		TextSize = 15,
	})

	self.codeBox = Instance.new("TextBox")
	self.codeBox.BackgroundColor3 = Palette.Ink
	self.codeBox.BackgroundTransparency = 0.2
	self.codeBox.BorderSizePixel = 0
	self.codeBox.Position = UDim2.new(0, 0, 0, 78)
	self.codeBox.Size = UDim2.fromOffset(208, 44)
	self.codeBox.PlaceholderText = "CÓDIGO"
	self.codeBox.PlaceholderColor3 = Palette.Muted
	self.codeBox.Text = ""
	self.codeBox.TextColor3 = Palette.Cream
	self.codeBox.FontFace = Theme.Font.Mono
	self.codeBox.TextSize = 22
	self.codeBox.ClearTextOnFocus = false
	self.codeBox.Parent = left
	Theme.corner(self.codeBox, UDim.new(0, 8))
	Theme.stroke(self.codeBox)

	-- Uppercase as they type, and refuse characters the alphabet does not have,
	-- so a bad code is impossible to submit rather than rejected after a trip.
	self.codeBox:GetPropertyChangedSignal("Text"):Connect(function()
		local cleaned = self.codeBox.Text:upper():gsub("[^" .. Rooms.ALPHABET .. "]", "")
		if #cleaned > Rooms.LENGTH then
			cleaned = cleaned:sub(1, Rooms.LENGTH)
		end
		if cleaned ~= self.codeBox.Text then
			self.codeBox.Text = cleaned
		end
	end)

	local function submit()
		local code = self.codeBox.Text
		if #code == Rooms.LENGTH and self.callbacks.onJoin then
			self.callbacks.onJoin(code)
		end
	end
	self.codeBox.FocusLost:Connect(function(enter)
		if enter then
			submit()
		end
	end)

	self.joinButton = Theme.button(left, "ENTRAR", submit, {
		Position = UDim2.new(0, 216, 0, 78),
		Size = UDim2.fromOffset(114, 44),
		TextSize = 15,
	})

	self.status = Theme.caption(left, "", {
		Position = UDim2.new(0, 0, 0, 130),
		Size = UDim2.new(1, 0, 0, 30),
		TextSize = 11,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	})

	-- ── middle: packs ──
	local mid = Instance.new("Frame")
	mid.BackgroundTransparency = 1
	mid.Position = UDim2.new(0, 356, 0, 0)
	mid.Size = UDim2.fromOffset(356, 164)
	mid.Parent = self.root

	self.packsTitle = Theme.caption(mid, "PAQUETES DE SONIDOS", {
		Size = UDim2.new(1, 0, 0, 14), TextSize = 11,
	})

	local packList = Instance.new("Frame")
	packList.BackgroundTransparency = 1
	packList.Position = UDim2.new(0, 0, 0, 20)
	packList.Size = UDim2.new(1, 0, 1, -20)
	packList.Parent = mid
	Theme.list(packList, 6)
	self.packList = packList
	self.packRows = {}

	-- ── right: roster ──
	local right = Instance.new("Frame")
	right.BackgroundTransparency = 1
	right.Position = UDim2.new(0, 738, 0, 0)
	right.Size = UDim2.fromOffset(304, 164)
	right.Parent = self.root

	self.rosterTitle = Theme.caption(right, "EN LA SALA", {
		Size = UDim2.new(1, 0, 0, 14), TextSize = 11,
	})

	local rosterList = Instance.new("Frame")
	rosterList.BackgroundTransparency = 1
	rosterList.Position = UDim2.new(0, 0, 0, 20)
	rosterList.Size = UDim2.new(1, 0, 1, -20)
	rosterList.Parent = right
	Theme.list(rosterList, 5)
	self.rosterList = rosterList
	self.rosterRows = {}

	return self
end

-- ── packs ────────────────────────────────────────────────────────────────────

function RoomPanel:_packRow(index)
	local row = self.packRows[index]
	if row then
		return row
	end

	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Palette.PanelRaised
	frame.BackgroundTransparency = 0.45
	frame.BorderSizePixel = 0
	frame.Size = UDim2.new(1, 0, 0, 32)
	frame.LayoutOrder = index
	frame.Parent = self.packList
	Theme.corner(frame, UDim.new(0, 7))

	local toggle = Instance.new("TextButton")
	toggle.BackgroundColor3 = Palette.Ink
	toggle.BorderSizePixel = 0
	toggle.AutoButtonColor = false
	toggle.Position = UDim2.new(0, 8, 0.5, -9)
	toggle.Size = UDim2.fromOffset(34, 18)
	toggle.Text = ""
	toggle.Parent = frame
	Theme.corner(toggle, UDim.new(1, 0))

	local knob = Instance.new("Frame")
	knob.BackgroundColor3 = Palette.Muted
	knob.BorderSizePixel = 0
	knob.Position = UDim2.new(0, 2, 0.5, -7)
	knob.Size = UDim2.fromOffset(14, 14)
	knob.Parent = toggle
	Theme.corner(knob, UDim.new(1, 0))

	local name = Theme.label(frame, "", {
		Position = UDim2.new(0, 50, 0, 0),
		Size = UDim2.new(1, -112, 1, 0),
		TextSize = 13,
		FontFace = Theme.Font.Medium,
	})

	local count = Theme.caption(frame, "", {
		Position = UDim2.new(1, -58, 0, 0),
		Size = UDim2.fromOffset(50, 32),
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	row = { frame = frame, toggle = toggle, knob = knob, name = name, count = count }
	self.packRows[index] = row
	return row
end

-- ── roster ───────────────────────────────────────────────────────────────────

function RoomPanel:_rosterRow(index)
	local row = self.rosterRows[index]
	if row then
		return row
	end

	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Palette.PanelRaised
	frame.BackgroundTransparency = 0.45
	frame.BorderSizePixel = 0
	frame.Size = UDim2.new(1, 0, 0, 27)
	frame.LayoutOrder = index
	frame.Parent = self.rosterList
	Theme.corner(frame, UDim.new(0, 6))

	local name = Theme.label(frame, "", {
		Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(1, -100, 1, 0),
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local tag = Theme.caption(frame, "", {
		Position = UDim2.new(1, -90, 0, 0),
		Size = UDim2.fromOffset(44, 27),
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Palette.Reference,
	})

	local kick = Theme.button(frame, "SACAR", nil, {
		Position = UDim2.new(1, -42, 0.5, -10),
		Size = UDim2.fromOffset(38, 20),
		TextSize = 10,
		Visible = false,
	})

	row = { frame = frame, name = name, tag = tag, kick = kick }
	self.rosterRows[index] = row
	return row
end

-- ── update ───────────────────────────────────────────────────────────────────

function RoomPanel:update(payload)
	payload = payload or {}
	local inRoom = payload.isRoom == true
	local amHost = inRoom and payload.hostUserId == localPlayer.UserId

	-- Left column swaps wholesale between the two states.
	self.codeLabel.Visible = inRoom and payload.display ~= nil
	self.codeHint.Visible = inRoom
	self.createButton.Visible = not inRoom
	self.codeBox.Visible = not inRoom
	self.joinButton.Visible = not inRoom

	if inRoom then
		self.headline.Text = amHost and "TU SALA" or "SALA"
		self.codeLabel.Text = payload.display or "—"
		self.codeHint.Text = amHost
			and "Pasale este código a tus amigos. Sos el anfitrión: elegís los paquetes y podés sacar gente."
			or "Estás en una sala privada. El anfitrión elige los paquetes."
	else
		self.headline.Text = "SALA"
		self.status.Text = payload.unavailable
			or "Creá una sala privada y te manda a un servidor propio, o entrá a una con su código."
		self.status.TextColor3 = payload.unavailable and Palette.Warn or Palette.Muted
		self.createButton.Active = payload.canCreate ~= false
		self.createButton.BackgroundColor3 = (payload.canCreate ~= false)
			and Palette.PanelRaised or Palette.Panel
	end

	-- Packs. Interactive for the host, visible to everyone.
	self.packsTitle.Text = amHost and "PAQUETES — TOCÁ PARA ACTIVAR" or "PAQUETES DE SONIDOS"
	local packs = payload.packs or {}
	for i, pack in ipairs(packs) do
		local row = self:_packRow(i)
		row.frame.Visible = true
		row.name.Text = pack.name
		row.count.Text = ("%d"):format(pack.sounds)
		row.name.TextColor3 = pack.enabled and Palette.Cream or Palette.Muted

		row.knob:TweenPosition(
			pack.enabled and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
			Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.18, true)
		row.knob.BackgroundColor3 = pack.enabled and Palette.Yours or Palette.Muted
		row.toggle.BackgroundColor3 = pack.enabled and Palette.Ink:Lerp(Palette.Yours, 0.2) or Palette.Ink
		row.toggle.Active = amHost
		row.toggle.AutoButtonColor = false

		if row.connection then
			row.connection:Disconnect()
			row.connection = nil
		end
		if amHost then
			row.connection = row.toggle.Activated:Connect(function()
				if self.callbacks.onTogglePack then
					self.callbacks.onTogglePack(pack.id, not pack.enabled)
				end
			end)
		end
	end
	for i = #packs + 1, #self.packRows do
		self.packRows[i].frame.Visible = false
	end

	-- Roster, with a remove button only where it is allowed to exist.
	local roster = payload.roster or {}
	self.rosterTitle.Text = ("EN LA SALA · %d"):format(#roster)
	for i, entry in ipairs(roster) do
		local row = self:_rosterRow(i)
		row.frame.Visible = true
		row.name.Text = entry.name
		row.tag.Text = entry.isHost and "ANFITRIÓN" or ""
		row.kick.Visible = amHost and not entry.isHost

		if row.connection then
			row.connection:Disconnect()
			row.connection = nil
		end
		if row.kick.Visible then
			row.connection = row.kick.Activated:Connect(function()
				if self.callbacks.onKick then
					self.callbacks.onKick(entry.userId, entry.name)
				end
			end)
		end
	end
	for i = #roster + 1, #self.rosterRows do
		self.rosterRows[i].frame.Visible = false
	end
end

function RoomPanel:setStatus(text, tone)
	self.status.Text = text or ""
	self.status.TextColor3 = (tone == "bad" and Palette.Bad)
		or (tone == "warn" and Palette.Warn)
		or (tone == "good" and Palette.Good)
		or Palette.Muted
end

function RoomPanel:setVisible(visible)
	self.root.Visible = visible
end

return RoomPanel

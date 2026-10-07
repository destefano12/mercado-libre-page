--!nonstrict
-- Menu.luau — the lobby. Modes, roster, and the one-screen explanation.
--
-- It lives inside the venue (the house camera is behind it), so it is a panel
-- over a room rather than a title screen in a void.

local Theme = require(script.Parent.Theme)
local Palette = require(game.ReplicatedStorage.Shared.Palette)
local Modes = require(game.ReplicatedStorage.Shared.Modes)
local Characters = require(game.ReplicatedStorage.Shared.Characters)
local SoundLibrary = require(game.ReplicatedStorage.Shared.SoundLibrary)

local Menu = {}
Menu.__index = Menu

function Menu.new(parent, callbacks)
	local self = setmetatable({}, Menu)
	self.callbacks = callbacks or {}
	self.selectedMode = "party"

	self.root = Instance.new("Frame")
	self.root.BackgroundTransparency = 1
	self.root.Size = UDim2.fromScale(1, 1)
	self.root.Visible = true
	self.root.Parent = parent

	-- Masthead.
	local head = Instance.new("Frame")
	head.BackgroundTransparency = 1
	head.Position = UDim2.new(0, 34, 0, 28)
	head.Size = UDim2.fromOffset(520, 76)
	head.Parent = self.root

	Theme.label(head, "MIMIC", {
		Size = UDim2.new(1, 0, 0, 44), TextSize = 42, FontFace = Theme.Font.Display,
	})
	Theme.label(head, "PARTY", {
		Position = UDim2.new(0, 124, 0, 0), Size = UDim2.new(1, 0, 0, 44),
		TextSize = 42, FontFace = Theme.Font.Display, TextColor3 = Palette.Reference,
	})
	Theme.caption(head, "Suena. Lo imitás. Una sola toma.", {
		Position = UDim2.new(0, 2, 0, 46), Size = UDim2.new(1, 0, 0, 18), TextSize = 14,
	})

	-- ── modes column ──
	local modesPanel = Theme.panel(self.root, {
		Position = UDim2.new(0, 34, 0, 118),
		Size = UDim2.fromOffset(340, 356),
	})
	Theme.pad(modesPanel, 16)
	Theme.caption(modesPanel, "MODOS", { Size = UDim2.new(1, 0, 0, 14), TextSize = 11 })

	local modeList = Instance.new("Frame")
	modeList.BackgroundTransparency = 1
	modeList.Position = UDim2.new(0, 0, 0, 22)
	modeList.Size = UDim2.new(1, 0, 1, -22)
	modeList.Parent = modesPanel
	Theme.list(modeList, 7)

	self.modeButtons = {}
	for _, mode in ipairs(Modes) do
		local b = Theme.button(modeList, "", function()
			self:selectMode(mode.id)
		end, { Size = UDim2.new(1, 0, 0, 56), Text = "" })

		Theme.label(b, mode.name, {
			Position = UDim2.new(0, 12, 0, 8), Size = UDim2.new(1, -24, 0, 18),
			TextSize = 15, FontFace = Theme.Font.Medium,
		})
		Theme.caption(b, mode.players, {
			Position = UDim2.new(0, 12, 0, 26), Size = UDim2.new(1, -24, 0, 14),
			TextSize = 11, TextColor3 = Palette.Reference,
		})
		Theme.caption(b, mode.blurb, {
			Position = UDim2.new(0, 12, 0, 38), Size = UDim2.new(1, -24, 0, 14),
			TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd,
		})

		self.modeButtons[mode.id] = b
	end

	-- ── roster ──
	local rosterPanel = Theme.panel(self.root, {
		Position = UDim2.new(0, 390, 0, 118),
		Size = UDim2.fromOffset(372, 356),
	})
	Theme.pad(rosterPanel, 16)
	Theme.caption(rosterPanel, "PERSONAJE", { Size = UDim2.new(1, 0, 0, 14), TextSize = 11 })

	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.new(0, 0, 0, 22)
	grid.Size = UDim2.new(1, 0, 1, -22)
	grid.Parent = rosterPanel

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(164, 74)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	self.characterButtons = {}
	for _, character in ipairs(Characters.all()) do
		local b = Theme.button(grid, "", function()
			if self.callbacks.onCharacter then
				self.callbacks.onCharacter(character.id)
			end
		end, { Size = UDim2.fromOffset(164, 74), Text = "" })

		local swatch = Instance.new("Frame")
		swatch.BackgroundColor3 = character.accent
		swatch.BorderSizePixel = 0
		swatch.Position = UDim2.new(0, 10, 0, 10)
		swatch.Size = UDim2.fromOffset(6, 54)
		swatch.Parent = b
		Theme.corner(swatch, UDim.new(1, 0))

		Theme.label(b, character.name, {
			Position = UDim2.new(0, 24, 0, 12), Size = UDim2.new(1, -34, 0, 18),
			TextSize = 15, FontFace = Theme.Font.Medium,
		})
		Theme.caption(b, character.tag, {
			Position = UDim2.new(0, 24, 0, 32), Size = UDim2.new(1, -34, 0, 28),
			TextSize = 11, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
		})

		self.characterButtons[character.id] = b
	end

	-- ── how it works ──
	local howPanel = Theme.panel(self.root, {
		Position = UDim2.new(0, 778, 0, 118),
		Size = UDim2.fromOffset(330, 356),
	})
	Theme.pad(howPanel, 16)
	Theme.caption(howPanel, "CÓMO SE JUEGA", { Size = UDim2.new(1, 0, 0, 14), TextSize = 11 })

	local steps = {
		{ "1", "Suena el sonido de referencia para toda la mesa." },
		{ "2", "Mantené apretado para vocalizar. Movés el mouse arriba y abajo para el tono." },
		{ "3", "Todos graban a la vez, con la misma cuenta atrás. Una sola toma, sin repetir." },
		{ "4", "Las tomas se escuchan una por una. Se puntúa melodía, ritmo y ataques — nunca tu timbre." },
		{ "5", "La ruleta reparte puntos, multiplicadores y sabotajes. Si te toca uno, elegís víctima." },
	}

	local stepList = Instance.new("Frame")
	stepList.BackgroundTransparency = 1
	stepList.Position = UDim2.new(0, 0, 0, 24)
	stepList.Size = UDim2.new(1, 0, 1, -82)
	stepList.Parent = howPanel
	Theme.list(stepList, 10)

	for _, step in ipairs(steps) do
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 46)
		row.Parent = stepList

		Theme.label(row, step[1], {
			Size = UDim2.fromOffset(20, 20), TextSize = 15,
			FontFace = Theme.Font.Display, TextColor3 = Palette.Reference,
		})
		Theme.caption(row, step[2], {
			Position = UDim2.new(0, 24, 0, 0), Size = UDim2.new(1, -24, 1, 0),
			TextSize = 12, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
		})
	end

	local packCount = #SoundLibrary.packs()
	local soundCount = #SoundLibrary.all()
	Theme.caption(howPanel, ("%d sonidos · %d paquetes"):format(soundCount, packCount), {
		Position = UDim2.new(0, 0, 1, -52), Size = UDim2.new(1, 0, 0, 14), TextSize = 11,
	})

	self.status = Theme.label(howPanel, "", {
		Position = UDim2.new(0, 0, 1, -34),
		Size = UDim2.new(1, 0, 0, 30),
		TextSize = 13,
		FontFace = Theme.Font.Medium,
		TextWrapped = true,
		TextColor3 = Palette.Reference,
	})

	self:selectMode("party")
	return self
end

function Menu:selectMode(id)
	self.selectedMode = id
	for modeId, button in pairs(self.modeButtons) do
		local on = (modeId == id)
		button.BackgroundColor3 = on and Palette.PanelRaised:Lerp(Palette.Reference, 0.12) or Palette.PanelRaised
	end
	if self.callbacks.onMode then
		self.callbacks.onMode(id)
	end
end

function Menu:setCharacter(id)
	for characterId, button in pairs(self.characterButtons) do
		local on = (characterId == id)
		button.BackgroundColor3 = on and Palette.PanelRaised:Lerp(Palette.Yours, 0.16) or Palette.PanelRaised
	end
end

function Menu:setStatus(text)
	self.status.Text = text or ""
end

function Menu:setVisible(visible)
	self.root.Visible = visible
end

return Menu

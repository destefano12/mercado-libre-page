--!nonstrict
-- Root.luau — the screen. Owns the ScreenGui and every panel on it, and is the
-- only thing init.client talks to about pixels.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Menu = require(script.Parent.Menu)
local StagePanel = require(script.Parent.StagePanel)
local Scoreboard = require(script.Parent.Scoreboard)
local RouletteUI = require(script.Parent.RouletteUI)
local RoomPanel = require(script.Parent.RoomPanel)
local Palette = require(game.ReplicatedStorage.Shared.Palette)

local Root = {}
Root.__index = Root

local PHASE_TEXT = {
	lobby = "ESPERANDO A LA SALA",
	procession = "AL ESCENARIO",
	round_intro = "PREPARATE",
	reference = "ESCUCHÁ",
	record = "GRABANDO",
	playback = "ESCUCHANDO LAS TOMAS",
	roulette = "LA RULETA",
	sabotage_pick = "ELEGÍ VÍCTIMA",
	results = "RESULTADOS",
}

function Root.new(callbacks)
	local self = setmetatable({}, Root)
	self.callbacks = callbacks or {}

	local gui = Instance.new("ScreenGui")
	gui.Name = "MimicParty"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui

	-- A gentle vignette. It is the only full-screen effect, and it never moves.
	local vignette = Instance.new("Frame")
	vignette.BackgroundTransparency = 1
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.ZIndex = 0
	vignette.Parent = gui
	local topShade = Instance.new("Frame")
	topShade.BackgroundColor3 = Palette.Ink
	topShade.BorderSizePixel = 0
	topShade.Size = UDim2.new(1, 0, 0, 150)
	topShade.Parent = vignette
	local g1 = Instance.new("UIGradient")
	g1.Rotation = 90
	g1.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	g1.Parent = topShade

	-- ── phase banner ──
	self.banner = Theme.panel(gui, {
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 22, 0, 22),
		Size = UDim2.fromOffset(250, 60),
		BackgroundTransparency = 0.12,
		Visible = false,
		ZIndex = 4,
	})
	Theme.pad(self.banner, 12)
	self.bannerPhase = Theme.label(self.banner, "", {
		Size = UDim2.new(1, 0, 0, 18), TextSize = 13, FontFace = Theme.Font.Medium,
		TextColor3 = Palette.Reference,
	})
	self.bannerClock = Theme.label(self.banner, "", {
		Position = UDim2.new(0, 0, 0, 18), Size = UDim2.new(1, 0, 0, 22),
		TextSize = 19, FontFace = Theme.Font.Mono,
	})

	-- ── mic / voice indicator ──
	-- Under the round banner, on the left. The top centre belongs to the player
	-- cards and the centre to the playback card; this is the only clear corner.
	self.voiceTag = Theme.panel(gui, {
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 22, 0, 92),
		Size = UDim2.fromOffset(250, 34),
		BackgroundTransparency = 0.06,
		Visible = false,
		ZIndex = 5,
	})
	Theme.label(self.voiceTag, "MESA SILENCIADA", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 12,
		FontFace = Theme.Font.Medium,
		TextColor3 = Palette.Warn,
	})

	-- ── toast ──
	self.toast = Theme.panel(gui, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 40),
		Size = UDim2.fromOffset(520, 44),
		BackgroundTransparency = 0.02,
		ZIndex = 9,
	})
	self.toastLabel = Theme.label(self.toast, "", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 14,
		FontFace = Theme.Font.Medium,
	})

	-- ── panels ──
	self.menu = Menu.new(gui, {
		onMode = function(id)
			if self.callbacks.onMode then
				self.callbacks.onMode(id)
			end
		end,
		onCharacter = function(id)
			if self.callbacks.onCharacter then
				self.callbacks.onCharacter(id)
			end
		end,
	})
	self.room = RoomPanel.new(gui, {
		onCreate = function()
			if self.callbacks.onCreateRoom then
				self.callbacks.onCreateRoom()
			end
		end,
		onJoin = function(code)
			if self.callbacks.onJoinRoom then
				self.callbacks.onJoinRoom(code)
			end
		end,
		onTogglePack = function(packId, enabled)
			if self.callbacks.onTogglePack then
				self.callbacks.onTogglePack(packId, enabled)
			end
		end,
		onKick = function(userId, name)
			if self.callbacks.onKick then
				self.callbacks.onKick(userId, name)
			end
		end,
	})
	self.stage = StagePanel.new(gui)
	self.scoreboard = Scoreboard.new(gui)
	self.roulette = RouletteUI.new(gui)
	self.roulette.root.ZIndex = 6

	-- ── results ──
	self.results = Theme.panel(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromOffset(460, 330),
		BackgroundTransparency = 0.02,
		Visible = false,
		ZIndex = 7,
	})
	Theme.pad(self.results, 20)
	Theme.title(self.results, "FIN DE LA FIESTA", { Size = UDim2.new(1, 0, 0, 30), TextSize = 23 })
	self.resultsList = Instance.new("Frame")
	self.resultsList.BackgroundTransparency = 1
	self.resultsList.Position = UDim2.new(0, 0, 0, 44)
	self.resultsList.Size = UDim2.new(1, 0, 1, -44)
	self.resultsList.Parent = self.results
	Theme.list(self.resultsList, 8)

	return self
end

function Root:setPhase(phase)
	local inMenu = (phase == "lobby" or phase == "boot")
	self.menu:setVisible(inMenu)
	-- Room controls belong to the lobby: mid-party is not the moment to be
	-- toggling packs or removing the person currently on their mark.
	self.room:setVisible(inMenu)
	self.scoreboard:setVisible(not inMenu)
	self.stage:setVisible(not inMenu and phase ~= "results")
	self.banner.Visible = not inMenu
	self.bannerPhase.Text = PHASE_TEXT[phase] or ""

	if phase ~= "roulette" and phase ~= "sabotage_pick" then
		self.roulette:hide()
	end
	if phase ~= "playback" then
		self.stage:hideCard()
	end
	self.results.Visible = (phase == "results")
end

function Root:setClock(secondsLeft)
	if not secondsLeft or secondsLeft <= 0 then
		self.bannerClock.Text = "—"
		return
	end
	self.bannerClock.Text = ("%0.1f s"):format(secondsLeft)
end

function Root:setVoiceGated(gated)
	self.voiceTag.Visible = gated == true
end

function Root:showToast(text, tone)
	local color = Palette.Cream
	if tone == "good" then color = Palette.Good end
	if tone == "warn" then color = Palette.Warn end
	if tone == "bad" then color = Palette.Bad end

	self.toastLabel.Text = text
	self.toastLabel.TextColor3 = color

	TweenService:Create(self.toast, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 1, -24),
	}):Play()

	self._toastToken = (self._toastToken or 0) + 1
	local token = self._toastToken
	task.delay(4, function()
		if self._toastToken ~= token then
			return
		end
		TweenService:Create(self.toast, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 1, 40),
		}):Play()
	end)
end

function Root:showResults(scores)
	for _, child in ipairs(self.resultsList:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for i, entry in ipairs(scores or {}) do
		local row = Theme.panel(self.resultsList, {
			Size = UDim2.new(1, 0, 0, 46),
			BackgroundTransparency = i == 1 and 0.0 or 0.4,
		})
		Theme.pad(row, 10)
		Theme.label(row, ("%d"):format(i), {
			Size = UDim2.fromOffset(26, 24), TextSize = 17, FontFace = Theme.Font.Display,
			TextColor3 = i == 1 and Palette.Reference or Palette.Muted,
		})
		Theme.label(row, entry.name, {
			Position = UDim2.new(0, 32, 0, 0), Size = UDim2.new(1, -118, 0, 24),
			TextSize = 15, FontFace = Theme.Font.Medium,
		})
		Theme.label(row, tostring(entry.score), {
			Position = UDim2.new(1, -86, 0, 0), Size = UDim2.fromOffset(80, 24),
			TextXAlignment = Enum.TextXAlignment.Right, FontFace = Theme.Font.Mono, TextSize = 16,
		})
	end
end

return Root

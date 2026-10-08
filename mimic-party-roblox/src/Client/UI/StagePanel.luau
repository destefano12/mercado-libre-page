--!nonstrict
-- StagePanel.luau — the performance HUD: the two waveforms and everything
-- attached to them. This is the panel the original is recognisable by, so the
-- layout is deliberate: reference on top in yellow, the pitch ribbon in the
-- middle, your voice underneath in green, and a count-in that covers nothing.

local Theme = require(script.Parent.Theme)
local Waveform = require(script.Parent.Waveform)
local Palette = require(game.ReplicatedStorage.Shared.Palette)
local Scoring = require(game.ReplicatedStorage.Shared.Scoring)
local Sabotages = require(game.ReplicatedStorage.Shared.Sabotages)
local SoundLibrary = require(game.ReplicatedStorage.Shared.SoundLibrary)

local StagePanel = {}
StagePanel.__index = StagePanel

function StagePanel.new(parent)
	local self = setmetatable({}, StagePanel)

	self.root = Instance.new("Frame")
	self.root.BackgroundTransparency = 1
	self.root.AnchorPoint = Vector2.new(0.5, 1)
	self.root.Position = UDim2.new(0.5, 0, 1, -24)
	self.root.Size = UDim2.fromOffset(900, 300)
	self.root.Visible = false
	self.root.Parent = parent

	local panel = Theme.panel(self.root, { BackgroundTransparency = 0.08 })
	Theme.pad(panel, 18)
	self.panel = panel

	-- Header: what you are imitating, and which pack it came from.
	self.soundName = Theme.title(panel, "", { Size = UDim2.new(1, -200, 0, 26), TextSize = 21 })
	self.packName = Theme.caption(panel, "", {
		Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, -200, 0, 14), TextSize = 11,
	})
	self.roundTag = Theme.label(panel, "", {
		Position = UDim2.new(1, -200, 0, 0), Size = UDim2.fromOffset(200, 26),
		TextXAlignment = Enum.TextXAlignment.Right, FontFace = Theme.Font.Mono,
		TextSize = 14, TextColor3 = Palette.Muted,
	})

	-- ── reference track (yellow) ──
	local refLabel = Theme.caption(panel, "REFERENCIA", {
		Position = UDim2.new(0, 0, 0, 50), Size = UDim2.fromOffset(100, 12),
		TextSize = 10, TextColor3 = Palette.Reference,
	})
	self.refLabel = refLabel

	-- Plain containers: Waveform draws its own framed well inside them.
	local refBox = Instance.new("Frame")
	refBox.BackgroundTransparency = 1
	refBox.Position = UDim2.new(0, 0, 0, 66)
	refBox.Size = UDim2.new(1, 0, 0, 58)
	refBox.Parent = panel
	self.reference = Waveform.new(refBox, Palette.Reference, false)

	-- ── pitch ribbon ──
	local ribbonBox = Instance.new("Frame")
	ribbonBox.BackgroundTransparency = 1
	ribbonBox.Position = UDim2.new(0, 0, 0, 124)
	ribbonBox.Size = UDim2.new(1, 0, 0, 44)
	ribbonBox.Parent = panel
	self.ribbon = Waveform.Ribbon.new(ribbonBox)

	-- ── your track (green) ──
	local yourBox = Instance.new("Frame")
	yourBox.BackgroundTransparency = 1
	yourBox.Position = UDim2.new(0, 0, 0, 170)
	yourBox.Size = UDim2.new(1, 0, 0, 58)
	yourBox.Parent = panel
	self.yours = Waveform.new(yourBox, Palette.Yours, true)

	self.yourLabel = Theme.caption(panel, "TU VOZ", {
		Position = UDim2.new(0, 0, 0, 228), Size = UDim2.fromOffset(100, 12),
		TextSize = 10, TextColor3 = Palette.Yours,
	})

	self.hint = Theme.caption(panel, "", {
		Position = UDim2.new(0, 108, 0, 228), Size = UDim2.new(1, -108, 0, 12),
		TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right,
	})

	-- ── microphone meter ──
	-- Sits under your own track, because that is what it is measuring. It is
	-- the only element that moves continuously, so it is small and desaturated.
	self.micRow = Instance.new("Frame")
	self.micRow.BackgroundTransparency = 1
	self.micRow.AnchorPoint = Vector2.new(0, 1)
	self.micRow.Position = UDim2.new(0, 0, 1, 10)
	self.micRow.Size = UDim2.fromOffset(420, 22)
	self.micRow.Parent = panel

	self.micBadge = Theme.label(self.micRow, "", {
		Size = UDim2.fromOffset(150, 22), TextSize = 11, FontFace = Theme.Font.Medium,
		TextColor3 = Palette.Muted,
	})

	local micTrack = Instance.new("Frame")
	micTrack.BackgroundColor3 = Palette.Ink
	micTrack.BackgroundTransparency = 0.3
	micTrack.BorderSizePixel = 0
	micTrack.Position = UDim2.new(0, 156, 0.5, -3)
	micTrack.Size = UDim2.fromOffset(150, 6)
	micTrack.Parent = self.micRow
	Theme.corner(micTrack, UDim.new(1, 0))

	self.micFill = Instance.new("Frame")
	self.micFill.BackgroundColor3 = Palette.Yours
	self.micFill.BorderSizePixel = 0
	self.micFill.Size = UDim2.fromScale(0, 1)
	self.micFill.Parent = micTrack
	Theme.corner(self.micFill, UDim.new(1, 0))

	-- The gate threshold, drawn on the meter: you can see what counts as sound.
	self.micGate = Instance.new("Frame")
	self.micGate.BackgroundColor3 = Palette.Reference
	self.micGate.BorderSizePixel = 0
	self.micGate.Size = UDim2.new(0, 1, 1, 4)
	self.micGate.Position = UDim2.fromScale(0.3, -0.3)
	self.micGate.Visible = false
	self.micGate.Parent = micTrack

	self.micNote = Theme.caption(self.micRow, "", {
		Position = UDim2.new(0, 314, 0, 0), Size = UDim2.new(1, -314, 1, 0),
		TextSize = 10, TextColor3 = Palette.Warn,
	})

	-- ── count-in overlay ──
	self.countIn = Theme.label(panel, "", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(240, 120),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 86,
		FontFace = Theme.Font.Display,
		Visible = false,
	})

	-- ── playback card ──
	self.card = Theme.panel(parent, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 172),
		Size = UDim2.fromOffset(452, 224),
		BackgroundTransparency = 0.02,
		Visible = false,
	})
	Theme.pad(self.card, 16)

	self.cardWho = Theme.title(self.card, "", { Size = UDim2.new(1, -110, 0, 26), TextSize = 20 })
	self.cardVerdict = Theme.label(self.card, "", {
		Position = UDim2.new(1, -110, 0, 0), Size = UDim2.fromOffset(110, 26),
		TextXAlignment = Enum.TextXAlignment.Right, FontFace = Theme.Font.Display, TextSize = 15,
	})
	self.cardSabotage = Theme.caption(self.card, "", {
		Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, 0, 0, 16),
		TextSize = 12, TextColor3 = Palette.Bad,
	})

	local meters = Instance.new("Frame")
	meters.BackgroundTransparency = 1
	meters.Position = UDim2.new(0, 0, 0, 48)
	meters.Size = UDim2.new(1, 0, 0, 90)
	meters.Parent = self.card
	Theme.list(meters, 0)

	self.meterMelody = Theme.meter(meters, "Melodía", Palette.Reference)
	self.meterRhythm = Theme.meter(meters, "Ritmo", Palette.Yours)
	self.meterAttacks = Theme.meter(meters, "Ataques", Palette.Warn)

	local rule = Instance.new("Frame")
	rule.BackgroundColor3 = Palette.Hairline
	rule.BackgroundTransparency = 0.4
	rule.BorderSizePixel = 0
	rule.Position = UDim2.new(0, 0, 0, 144)
	rule.Size = UDim2.new(1, 0, 0, 1)
	rule.Parent = self.card

	Theme.caption(self.card, "TOTAL", {
		Position = UDim2.new(0, 0, 0, 154), Size = UDim2.fromOffset(80, 32), TextSize = 11,
	})
	self.cardTotal = Theme.label(self.card, "0", {
		Position = UDim2.new(0, 0, 0, 148), Size = UDim2.new(1, 0, 0, 38),
		TextXAlignment = Enum.TextXAlignment.Right, FontFace = Theme.Font.Display, TextSize = 32,
	})
	self.cardAwarded = Theme.caption(self.card, "", {
		Position = UDim2.new(0, 0, 0, 178), Size = UDim2.new(1, 0, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Right, TextSize = 11,
	})

	return self
end

function StagePanel:setVisible(visible)
	self.root.Visible = visible
	if not visible then
		self.card.Visible = false
	end
end

function StagePanel:setSound(sound, round, rounds)
	self.soundName.Text = sound and sound.name:upper() or ""
	if sound then
		local pack
		for _, p in ipairs(SoundLibrary.packs()) do
			if p.id == sound.pack then
				pack = p
			end
		end
		local stars = string.rep("●", sound.difficulty) .. string.rep("○", 3 - sound.difficulty)
		self.packName.Text = ("%s   %s   %.1fs"):format(pack and pack.name or sound.pack, stars, sound.duration)
		self.reference:setEnvelope(SoundLibrary.envelope(sound.notes, sound.duration))
		self.ribbon:setReference(sound.notes, sound.duration)
	else
		self.packName.Text = ""
		self.reference:clear()
	end
	self.roundTag.Text = (round and rounds) and ("RONDA %d / %d"):format(round, rounds) or ""
	self.yours:clear()
	self.ribbon:setCursor(0, 0, false)
end

function StagePanel:setHint(text)
	self.hint.Text = text or ""
end

function StagePanel:setReferencePlayhead(alpha)
	self.reference:setPlayhead(alpha)
end

function StagePanel:showCountIn(n)
	if n == nil then
		self.countIn.Visible = false
		return
	end
	self.countIn.Visible = true
	self.countIn.Text = (n > 0) and tostring(n) or "¡YA!"
	self.countIn.TextColor3 = (n > 0) and Palette.Cream or Palette.Yours
	if n == 0 then
		task.delay(0.55, function()
			self.countIn.Visible = false
		end)
	end
end

-- Live, per frame, while the take is being recorded.
function StagePanel:onRecordFrame(alpha, pitch, voiced, index, level)
	self.yours:setBar(index, level)
	self.yours:setPlayhead(alpha)
	self.reference:setPlayhead(alpha)
	self.ribbon:setCursor(alpha, pitch, voiced)
end

function StagePanel:showTake(take, duration)
	-- A microphone take carries the loudness curve the player actually produced;
	-- only a pointer take has to be reconstructed from its notes.
	self.yours:setEnvelope(take.envelope or SoundLibrary.envelope(take.notes, duration))
end

local MODE_TEXT = {
	voice = "MICRÓFONO + TONO",
	voice_only = "SOLO MICRÓFONO",
	pointer = "PUNTERO",
}

local MODE_HINT = {
	voice = "HABLÁ AL MICRÓFONO · MOVÉ EL MOUSE PARA EL TONO",
	voice_only = "HABLÁ AL MICRÓFONO",
	pointer = "MANTENÉ APRETADO · MOVÉ EL MOUSE PARA EL TONO",
}

-- Called once per take, before the count-in, with the mode actually resolved.
function StagePanel:setInputMode(mode, reason)
	self.inputMode = mode
	self.micBadge.Text = MODE_TEXT[mode] or ""
	self.micBadge.TextColor3 = (mode == "pointer") and Palette.Muted or Palette.Yours
	self.micGate.Visible = (mode ~= "pointer")
	self.micNote.Text = reason or ""
	self:setHint(MODE_HINT[mode] or "")
end

-- `calibrating` draws the meter in the reference colour, so the player can see
-- the room being measured during the count-in rather than wondering.
function StagePanel:setMicLevel(level, calibrating)
	local alpha = math.clamp(level or 0, 0, 1)
	self.micFill.Size = UDim2.fromScale(alpha, 1)
	self.micFill.BackgroundColor3 = calibrating and Palette.Reference or Palette.Yours
	if calibrating then
		self.micBadge.Text = "MIDIENDO LA SALA…"
	elseif self.inputMode then
		self.micBadge.Text = MODE_TEXT[self.inputMode] or ""
	end
end

function StagePanel:showCard(payload)
	local grade = payload.grade or { melody = 0, rhythm = 0, attacks = 0, total = 0 }

	self.card.Visible = true
	self.cardWho.Text = (payload.name or "?"):upper()
	self.cardVerdict.Text = payload.verdict or Scoring.verdict(grade.total)
	local band = Scoring.band(grade.total)
	self.cardVerdict.TextColor3 = (band == "good" and Palette.Good)
		or (band == "warn" and Palette.Warn)
		or Palette.Bad

	if payload.sabotage then
		local def = Sabotages.get(payload.sabotage)
		self.cardSabotage.Text = ("SABOTEADO · %s%s  −%d"):format(
			def and def.name:upper() or "?",
			payload.sabotageFrom and (" por " .. payload.sabotageFrom) or "",
			Sabotages.penalty())
	else
		self.cardSabotage.Text = ""
	end

	-- An axis that carried no weight is shown as not counted, rather than as a
	-- bad score the player had no way to influence.
	local weighted = grade.weighted
	local melodyCounted = (not weighted) or weighted.melody > 0
	self.meterMelody.set(melodyCounted and grade.melody or 0)
	self.meterMelody.setMuted(not melodyCounted)
	self.meterRhythm.set(grade.rhythm)
	self.meterAttacks.set(grade.attacks)

	self.cardTotal.Text = tostring(grade.total)
	local mult = payload.multiplier or 1
	self.cardAwarded.Text = (mult > 1)
		and ("×%s  →  +%d al marcador"):format(mult, payload.awarded or grade.total)
		or ("+%d al marcador"):format(payload.awarded or grade.total)
end

function StagePanel:hideCard()
	self.card.Visible = false
end

return StagePanel

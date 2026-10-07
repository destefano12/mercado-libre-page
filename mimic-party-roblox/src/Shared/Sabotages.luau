--!nonstrict
-- Sabotages.luau — what the wheel lets you do to somebody else's take.
--
-- Every one of these is a native Roblox SoundEffect, so the ruined take is
-- genuinely ruined in the audio graph rather than faked with a label. The
-- victim finds out only when their own take plays back — nothing here is
-- announced earlier, and that delay is the point.

local Config = require(script.Parent.Config)

local Sabotages = {}

local defs = {
	{
		id = "saturate",
		name = "Saturación",
		blurb = "Su toma sale reventada, al borde del clip.",
		icon = "▲",
		apply = function(sound)
			local fx = Instance.new("DistortionSoundEffect")
			fx.Level = 0.72
			fx.Parent = sound
			local gain = Instance.new("EqualizerSoundEffect")
			gain.LowGain = 4
			gain.MidGain = 6
			gain.HighGain = -2
			gain.Parent = sound
			return function()
				fx:Destroy()
				gain:Destroy()
			end
		end,
	},
	{
		id = "echo",
		name = "Eco",
		blurb = "Se repite, y se repite, y se repite.",
		icon = "◌",
		apply = function(sound)
			local fx = Instance.new("EchoSoundEffect")
			fx.Delay = 0.19
			fx.Feedback = 0.62
			fx.DryLevel = 0
			fx.WetLevel = -2
			fx.Parent = sound
			return function()
				fx:Destroy()
			end
		end,
	},
	{
		id = "pitch",
		name = "Cambio de tono",
		blurb = "Ardilla o demonio. No elige quién lo recibe.",
		icon = "◆",
		apply = function(sound)
			local fx = Instance.new("PitchShiftSoundEffect")
			fx.Octave = (math.random() < 0.5) and 0.58 or 1.72
			fx.Parent = sound
			return function()
				fx:Destroy()
			end
		end,
	},
	{
		id = "chop",
		name = "Picado",
		blurb = "La toma se corta en pedazos a media frase.",
		icon = "▌",
		apply = function(sound)
			-- A hard gate on the fader: Roblox has no stutter effect, so we cut
			-- the volume on a fixed grid while the take plays.
			local original = sound.Volume
			local alive = true
			task.spawn(function()
				local open = true
				while alive and sound.Parent do
					sound.Volume = open and original or 0
					open = not open
					task.wait(0.085)
				end
			end)
			return function()
				alive = false
				if sound.Parent then
					sound.Volume = original
				end
			end
		end,
	},
	{
		id = "swap",
		name = "Sustitución",
		blurb = "La mesa no escucha su voz. Escucha otra cosa.",
		icon = "✖",
		-- Handled upstream by the audio engine: the take is never rendered,
		-- Config.AUDIO.SWAP_SFX plays in its place.
		replacesTake = true,
		apply = function()
			return function() end
		end,
	},
}

local byId = {}
for _, d in ipairs(defs) do
	byId[d.id] = d
end

function Sabotages.all()
	return defs
end

function Sabotages.get(id)
	return byId[id]
end

function Sabotages.penalty()
	return Config.ROULETTE.SABOTAGE_POINT_PENALTY
end

-- Applies a sabotage to a live Sound and returns a cleanup function.
-- Safe to call with nil / unknown ids: you get a no-op cleanup back.
function Sabotages.applyTo(sound, id)
	local def = id and byId[id]
	if not def or not sound then
		return function() end
	end
	local ok, cleanup = pcall(def.apply, sound)
	if not ok or type(cleanup) ~= "function" then
		warn(("[Sabotages] %q failed to apply: %s"):format(tostring(id), tostring(cleanup)))
		return function() end
	end
	return cleanup
end

return Sabotages

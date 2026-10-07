--!nonstrict
-- VoiceGate.luau — mutes the table while a take plays back.
--
-- In the original, mics close during playback so everyone hears the same take,
-- then reopen for the reaction. Roblox can do this properly through the current
-- audio API: each player with voice chat gets an AudioDeviceInput, and the
-- server can deactivate it. Older places, or places with voice chat disabled,
-- have no such instance — so every call is guarded and degrades to a no-op,
-- and the client shows the "MESA SILENCIADA" indicator either way.

local Players = game:GetService("Players")

local VoiceGate = {}

local function deviceInput(player)
	local ok, found = pcall(function()
		return player:FindFirstChildOfClass("AudioDeviceInput")
	end)
	return ok and found or nil
end

local function setActive(player, active)
	local input = deviceInput(player)
	if not input then
		return false
	end
	local ok = pcall(function()
		input.Active = active
	end)
	return ok
end

-- Returns true if at least one real mic was actually gated.
function VoiceGate.closeAll()
	local gated = false
	for _, player in ipairs(Players:GetPlayers()) do
		if setActive(player, false) then
			gated = true
		end
	end
	return gated
end

function VoiceGate.openAll()
	for _, player in ipairs(Players:GetPlayers()) do
		setActive(player, true)
	end
end

-- Keeps one player audible (used for nothing today, but the playback phase of a
-- "Pass the Mic" party needs exactly this, so it stays in the surface).
function VoiceGate.soloOnly(target)
	for _, player in ipairs(Players:GetPlayers()) do
		setActive(player, player == target)
	end
end

return VoiceGate

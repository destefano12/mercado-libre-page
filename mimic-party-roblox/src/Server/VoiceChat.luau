--!nonstrict
-- VoiceChat.luau — the voice graph, wired by hand.
--
-- Voice is the whole game, so none of this is left to the engine's defaults.
-- The chain, per the current audio API:
--
--   AudioDeviceInput (.Player = them, .Muted, .Volume)
--        └─ Wire ─→ AudioEmitter (parented to their Head, DistanceAttenuation)
--                        └─ picked up by the listener that
--                           SoundService.ListenerLocation provides
--                                └─ AudioDeviceOutput (engine-provided)
--
-- Owning the wires is what buys the three things this game needs:
--
--   1. A real mute. Closing the table during playback sets `.Muted` on a real
--      input, so everyone genuinely hears the same take and not five people
--      reacting over it. `.Active` is NOT usable for this — it is flagged
--      Roblox Script Security and a game script cannot write it.
--   2. Reach. The house is ~45 studs deep; the attenuation curve is tuned so a
--      voice on stage carries to the back row without five performers turning
--      into mud when they all talk at once.
--   3. Per-player volume, for the reaction window.
--
-- What no amount of configuration can do: give voice to an account that does
-- not have it. Roblox gates microphone access on age verification, per user.
-- Those players get the pointer input mode and are told why, in plain words.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local Config = require(game.ReplicatedStorage.Shared.Config)

local VoiceChat = {}
local VC = Config.VOICE_CHAT

local rigs = {}        -- player → { input, emitter, wire, ownsInput }
local tableClosed = false

-- ── attenuation ──────────────────────────────────────────────────────────────

-- DistanceAttenuation wants { [distance] = volume }. Config keeps it as an
-- ordered list because a list is readable and a dict is not.
local function attenuationCurve()
	local curve = {}
	for _, point in ipairs(VC.ATTENUATION) do
		curve[point[1]] = point[2]
	end
	return curve
end

-- ── rig ──────────────────────────────────────────────────────────────────────

local function anchorFor(player)
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("Head")
		or character:FindFirstChild("HumanoidRootPart")
		or character.PrimaryPart
end

-- Reuses the input the engine already made for this player when default voice
-- is on; creates one only if there is none. Creating a second input for a player
-- who already has one would double their voice.
local function ensureInput(player)
	local existing = player:FindFirstChildOfClass("AudioDeviceInput")
	if existing then
		return existing, false
	end
	local ok, made = pcall(function()
		local input = Instance.new("AudioDeviceInput")
		input.Player = player
		input.Parent = player
		return input
	end)
	if ok and made then
		return made, true
	end
	return nil, false
end

function VoiceChat.rig(player)
	if not VC.CUSTOM_ROUTING then
		return nil
	end

	local anchor = anchorFor(player)
	if not anchor then
		return nil
	end

	-- Already rigged and still valid.
	local rig = rigs[player]
	if rig and rig.emitter and rig.emitter.Parent == anchor and rig.input and rig.input.Parent then
		return rig
	end

	VoiceChat.unrig(player, true)

	local input, ownsInput = ensureInput(player)
	if not input then
		return nil
	end

	local emitter, wire
	local ok = pcall(function()
		-- If default voice already put an emitter on this character, use it
		-- rather than adding a second one.
		emitter = anchor:FindFirstChildOfClass("AudioEmitter")
		if not emitter then
			emitter = Instance.new("AudioEmitter")
			emitter.Name = "MimicVoiceEmitter"
			emitter.Parent = anchor
		end
		pcall(function()
			emitter:SetDistanceAttenuation(attenuationCurve())
		end)

		-- Only add a wire if this input is not already feeding this emitter.
		local wired = false
		for _, existing in ipairs(input:GetConnectedWires("Output")) do
			if existing.TargetInstance == emitter then
				wired = true
			end
		end
		if not wired then
			wire = Instance.new("Wire")
			wire.Name = "MimicVoiceWire"
			wire.SourceInstance = input
			wire.TargetInstance = emitter
			wire.Parent = emitter
		end

		input.Volume = VC.INPUT_VOLUME
		input.Muted = tableClosed
	end)

	if not ok then
		return nil
	end

	rigs[player] = {
		input = input,
		emitter = emitter,
		wire = wire,
		ownsInput = ownsInput,
	}
	return rigs[player]
end

function VoiceChat.unrig(player, keepEntry)
	local rig = rigs[player]
	if not rig then
		return
	end
	-- Only destroy what we made. Tearing down an engine-provided input would
	-- cut the player's actual voice chat for the rest of the session.
	if rig.wire then
		pcall(function() rig.wire:Destroy() end)
	end
	if rig.emitter and rig.emitter.Name == "MimicVoiceEmitter" then
		pcall(function() rig.emitter:Destroy() end)
	end
	if rig.ownsInput and rig.input then
		pcall(function() rig.input:Destroy() end)
	end
	if not keepEntry then
		rigs[player] = nil
	end
end

-- ── the gate ─────────────────────────────────────────────────────────────────

local function setMuted(player, muted)
	local rig = rigs[player]
	local input = rig and rig.input or player:FindFirstChildOfClass("AudioDeviceInput")
	if not input then
		return false
	end
	local ok = pcall(function()
		input.Muted = muted
	end)
	return ok
end

VoiceChat.setMuted = setMuted

-- Closes every mic. Returns true if at least one real input was gated, which is
-- what the client uses to decide whether to show the "MESA SILENCIADA" badge.
function VoiceChat.closeTable()
	tableClosed = true
	local gated = false
	for _, player in ipairs(Players:GetPlayers()) do
		if setMuted(player, true) then
			gated = true
		end
	end
	return gated
end

function VoiceChat.openTable()
	tableClosed = false
	for _, player in ipairs(Players:GetPlayers()) do
		setMuted(player, false)
	end
end

-- Everyone muted except one. The reaction window after a take uses this when a
-- single performer is still on their mark.
function VoiceChat.soloOnly(target)
	tableClosed = true
	for _, player in ipairs(Players:GetPlayers()) do
		setMuted(player, player ~= target)
	end
end

function VoiceChat.isTableClosed()
	return tableClosed
end

-- ── lifecycle ────────────────────────────────────────────────────────────────

function VoiceChat.onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		-- The head has to exist before an emitter can hang off it.
		task.wait(0.35)
		VoiceChat.rig(player)
	end)
	if player.Character then
		VoiceChat.rig(player)
	end

	-- Voice is provisioned asynchronously: an input can appear a second or two
	-- after the player does, so watch for it instead of assuming.
	player.ChildAdded:Connect(function(child)
		if child:IsA("AudioDeviceInput") then
			task.wait(0.1)
			VoiceChat.rig(player)
		end
	end)
end

function VoiceChat.onPlayerRemoving(player)
	VoiceChat.unrig(player)
end

function VoiceChat.start()
	-- Camera-anchored listening: the camera is where the player's point of view
	-- actually is in this game, and it is the shot director that moves it.
	pcall(function()
		SoundService.ListenerLocation = Enum.ListenerLocation.Camera
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		VoiceChat.onPlayerAdded(player)
	end

	-- A periodic re-rig: respawns, late voice provisioning and character
	-- reloads all invalidate an emitter, and a silent voice chat is the single
	-- worst failure this game can have.
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in ipairs(Players:GetPlayers()) do
				if player.Character then
					VoiceChat.rig(player)
				end
			end
		end
	end)

	print("[VoiceChat] graph ready (custom routing: " .. tostring(VC.CUSTOM_ROUTING) .. ")")
end

-- Diagnostics the client can show the host, because "voice is broken" needs to
-- be answerable without a developer present.
function VoiceChat.report()
	local out = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local rig = rigs[player]
		local input = rig and rig.input or player:FindFirstChildOfClass("AudioDeviceInput")
		table.insert(out, {
			userId = player.UserId,
			name = player.DisplayName,
			hasInput = input ~= nil,
			muted = input and input.Muted or nil,
			rigged = rig ~= nil and rig.emitter ~= nil,
		})
	end
	return out
end

return VoiceChat

--!nonstrict
-- VoiceInput.luau — the real microphone.
--
-- What Roblox actually allows, verified against the engine reference:
--
--   AudioAnalyzer.RmsLevel / .PeakLevel   live, per audio buffer, CLIENT ONLY
--                                         ("on the server this property is
--                                         always 0"). Works on a microphone.
--   AudioAnalyzer:GetSpectrum()           returns an EMPTY ARRAY if any input
--                                         comes from an AudioDeviceInput.
--
-- So loudness is available and frequency is not. That is the whole shape of
-- this module: it turns a loudness stream into clean note onsets — which is
-- genuinely two of the three scoring axes (rhythm and attacks) plus the real
-- envelope for the green waveform. Pitch has to come from somewhere else, and
-- SpectrumEnabled is left off because for a mic it would only burn CPU.
--
-- Everything is guarded: no voice permission, no AudioDeviceInput, an older
-- client, a denied mic — each one degrades to `nil` and the Booth falls back to
-- pointer input instead of failing a take.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game.ReplicatedStorage.Shared.Config)

local VoiceInput = {}

local V = Config.VOICE
local localPlayer = Players.LocalPlayer

-- ── capability probe ─────────────────────────────────────────────────────────

-- Returns available, reason. The reason is shown to the player, so it is
-- written for a player and not for a log.
function VoiceInput.probe()
	if not RunService:IsClient() then
		return false, "El análisis de audio solo corre en el cliente."
	end

	local ok = pcall(function()
		return Instance.new("AudioAnalyzer")
	end)
	if not ok then
		return false, "Tu cliente de Roblox no tiene la API de audio nueva."
	end

	local service = game:FindFirstChild("VoiceChatService") or game:GetService("VoiceChatService")
	if service then
		local enabled, result = pcall(function()
			return service:IsVoiceEnabledForUserIdAsync(localPlayer.UserId)
		end)
		if enabled and result == false then
			return false, "No tenés el chat de voz habilitado en tu cuenta de Roblox."
		end
	end

	return true, nil
end

-- ── session ──────────────────────────────────────────────────────────────────

local Session = {}
Session.__index = Session

-- Opens the mic → analyzer graph. Returns nil plus a reason on any failure.
function VoiceInput.open()
	local available, reason = VoiceInput.probe()
	if not available then
		return nil, reason
	end

	local created = {}

	-- Prefer the input Roblox already made for this player; only create one if
	-- voice chat has not provided it.
	local device = localPlayer:FindFirstChildOfClass("AudioDeviceInput")
	if not device then
		local ok, made = pcall(function()
			local d = Instance.new("AudioDeviceInput")
			d.Player = localPlayer
			d.Parent = localPlayer
			return d
		end)
		if not ok or not made then
			return nil, "No se pudo abrir el micrófono."
		end
		device = made
		table.insert(created, device)
	end

	local analyzer
	local wire
	local ok = pcall(function()
		analyzer = Instance.new("AudioAnalyzer")
		-- GetSpectrum is empty for microphone inputs anyway; leaving the
		-- spectrum off "dramatically reduces" the analyzer's CPU cost.
		analyzer.SpectrumEnabled = false
		analyzer.Parent = localPlayer

		wire = Instance.new("Wire")
		wire.SourceInstance = device
		wire.TargetInstance = analyzer
		wire.Parent = analyzer
	end)

	if not ok or not analyzer then
		for _, inst in ipairs(created) do
			inst:Destroy()
		end
		if analyzer then analyzer:Destroy() end
		return nil, "No se pudo conectar el micrófono al analizador."
	end

	table.insert(created, analyzer)
	table.insert(created, wire)

	local self = setmetatable({
		device = device,
		analyzer = analyzer,
		wire = wire,
		_created = created,
		floor = V.FLOOR_MIN,
		ceiling = V.LEVEL_CEILING_MIN,
		_closed = false,
	}, Session)

	-- The device must be live for the analyzer to see anything.
	pcall(function()
		device.Active = true
	end)

	return self
end

function Session:rms()
	if self._closed then
		return 0
	end
	local ok, value = pcall(function()
		return self.analyzer.RmsLevel
	end)
	return (ok and type(value) == "number" and value == value) and value or 0
end

function Session:peak()
	if self._closed then
		return 0
	end
	local ok, value = pcall(function()
		return self.analyzer.PeakLevel
	end)
	return (ok and type(value) == "number" and value == value) and value or 0
end

-- Measures the room while the count-in runs. Called with the count-in duration;
-- uses the 60th percentile rather than the mean so one cough does not raise the
-- floor for the whole take.
function Session:calibrate(seconds, onTick)
	local samples = {}
	local deadline = os.clock() + math.max(0.4, seconds)
	while os.clock() < deadline and not self._closed do
		local v = self:rms()
		table.insert(samples, v)
		if onTick then
			onTick(v)
		end
		task.wait(0.03)
	end

	if #samples == 0 then
		self.floor = V.FLOOR_MIN
		return self.floor
	end

	table.sort(samples)
	local pick = samples[math.max(1, math.floor(#samples * 0.6))]
	self.floor = math.max(V.FLOOR_MIN, pick * V.FLOOR_HEADROOM)
	return self.floor
end

-- Normalised 0..1 level for the waveform and the meter. Tracks a decaying peak
-- so a quiet mic still draws a full-height bar when the player shouts.
function Session:level(rms, dt)
	self.ceiling = math.max(
		V.LEVEL_CEILING_MIN,
		math.max(rms, self.ceiling - self.ceiling * V.LEVEL_DECAY * (dt or 0.016))
	)
	return math.clamp(rms / self.ceiling, 0, 1)
end

function Session:thresholds()
	return self.floor * V.GATE_OPEN, self.floor * V.GATE_CLOSE
end

function Session:close()
	if self._closed then
		return
	end
	self._closed = true
	-- Only tear down what this session created. If voice chat owns the device,
	-- destroying it would cut the player's actual voice chat.
	for _, inst in ipairs(self._created) do
		if inst ~= self.device or inst.Parent == nil then
			pcall(function()
				inst:Destroy()
			end)
		end
	end
	if self.device and self.device.Parent == localPlayer then
		local ownedByUs = false
		for _, inst in ipairs(self._created) do
			if inst == self.device then
				ownedByUs = true
			end
		end
		if ownedByUs then
			pcall(function()
				self.device:Destroy()
			end)
		end
	end
end

-- ── gate ─────────────────────────────────────────────────────────────────────
-- A small state machine that turns the loudness stream into attacks. Pulled out
-- of the Booth so it can be reasoned about (and tested) on its own.

local Gate = {}
Gate.__index = Gate
VoiceInput.Gate = Gate

function Gate.new(openAt, closeAt)
	return setmetatable({
		openAt = openAt,
		closeAt = closeAt,
		open = false,
		lastClosed = -math.huge,
		pendingClose = nil,
	}, Gate)
end

-- Feed it (rms, t). Returns: voiced, event, at
--   event == "onset"  a new attack just started; `at` is t
--   event == "end"    the current attack just ended; `at` is when the level
--                     actually dropped, NOT when we decided it had — otherwise
--                     every note is reported BRIDGE_GAP longer than it was, and
--                     the melody axis compares a window the player never filled.
function Gate:step(rms, t)
	if not self.open then
		if rms >= self.openAt and (t - self.lastClosed) >= Config.VOICE.REFRACTORY then
			self.open = true
			self.pendingClose = nil
			return true, "onset", t
		end
		return false, nil, nil
	end

	if rms < self.closeAt then
		-- Do not end the note on a single quiet frame: a syllable boundary is
		-- not the end of the attack. Wait out BRIDGE_GAP first.
		self.pendingClose = self.pendingClose or t
		if (t - self.pendingClose) >= Config.VOICE.BRIDGE_GAP then
			local droppedAt = self.pendingClose
			self.open = false
			self.lastClosed = droppedAt
			self.pendingClose = nil
			return false, "end", droppedAt
		end
		return true, nil, nil
	end

	self.pendingClose = nil
	return true, nil, nil
end

function Gate:forceClose(t)
	if self.open then
		self.open = false
		self.lastClosed = t
		self.pendingClose = nil
		return true
	end
	return false
end

return VoiceInput

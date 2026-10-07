--!nonstrict
-- AudioCatalog.luau — reference audio, taken from Roblox's own audio library.
--
-- Nothing is bundled and nothing is uploaded. At boot the server asks Roblox for
-- audio matching each sound's keywords (AssetService:SearchAudioAsync), prefers
-- assets Roblox marks as endorsed, and publishes the chosen ids as attributes on
-- a replicated folder. Clients read them from there and verify each one actually
-- loads before relying on it.
--
-- Why this way:
--   · the audio is Roblox-hosted and Roblox-licensed, so there is no third-party
--     rights question to answer and nothing to clear;
--   · the search runs once, on the server, so every player in a room hears the
--     same asset for the same sound;
--   · search results are documented to sometimes include assets an experience
--     cannot actually play, so an id is a candidate until a client has loaded it.
--
-- Everything degrades: no result, a refused asset, a slow load — the round still
-- happens, rendered through the synthesised tone. The contour never depends on
-- any of this, so scoring is identical either way.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundLibrary = require(script.Parent.SoundLibrary)

local AudioCatalog = {}

local FOLDER_NAME = "MimicPartyAudio"
local MIN_DURATION = 0.3
local MAX_DURATION = 12
local PAGE_LIMIT = 1

local folder
local verified = {}     -- soundId → true (loads) / false (refused)

local function root()
	if folder and folder.Parent then
		return folder
	end
	if RunService:IsServer() then
		folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
	else
		folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
			or ReplicatedStorage:WaitForChild(FOLDER_NAME, 20)
	end
	return folder
end

-- ── server: resolve ──────────────────────────────────────────────────────────

-- Scores a search result. Endorsed first, then a duration close to the contour's,
-- because a 40-second track is useless as a one-second reference.
local function rank(entry, wanted)
	local score = 0
	if entry.IsEndorsed then
		score += 100
	end
	local duration = tonumber(entry.Duration) or 0
	if duration >= MIN_DURATION and duration <= MAX_DURATION then
		score += 40
		score -= math.abs(duration - wanted) * 4
	else
		score -= 60
	end
	return score
end

local function searchOne(sound)
	if sound.asset then
		return sound.asset   -- pinned by hand; no search
	end
	if not sound.search then
		return nil
	end

	for _, keyword in ipairs(sound.search) do
		local ok, pages = pcall(function()
			local params = Instance.new("AudioSearchParams")
			params.SearchKeyword = keyword
			params.MinDuration = MIN_DURATION
			params.MaxDuration = MAX_DURATION
			return game:GetService("AssetService"):SearchAudioAsync(params)
		end)

		if ok and pages then
			local best, bestScore = nil, -math.huge
			local page = 0
			repeat
				local gotPage, entries = pcall(function()
					return pages:GetCurrentPage()
				end)
				if not gotPage or type(entries) ~= "table" then
					break
				end
				for _, entry in ipairs(entries) do
					local id = entry.Id or entry.id
					if id then
						local score = rank(entry, sound.duration)
						if score > bestScore then
							best, bestScore = id, score
						end
					end
				end
				page += 1
				local advanced = pcall(function()
					if not pages.IsFinished then
						pages:AdvanceToNextPageAsync()
						return true
					end
					return false
				end)
			until page >= PAGE_LIMIT or not advanced or pages.IsFinished

			if best then
				return ("rbxassetid://%d"):format(tonumber(best) or 0)
			end
		end
	end

	return nil
end

-- Server-only. Runs in its own coroutine; the game does not wait on it, because
-- the synthesised fallback covers every sound until an id lands.
function AudioCatalog.resolveAsync()
	assert(RunService:IsServer(), "AudioCatalog.resolveAsync is server-only")
	local store = root()

	task.spawn(function()
		local found, missing = 0, 0
		for _, sound in ipairs(SoundLibrary.all()) do
			local asset = searchOne(sound)
			if asset then
				store:SetAttribute(sound.id, asset)
				found += 1
			else
				missing += 1
			end
			task.wait(0.08)   -- the search is rate-limited; do not hammer it
		end
		store:SetAttribute("__resolved", true)
		print(("[AudioCatalog] %d/%d sonidos resueltos desde la biblioteca de Roblox (%d con tono sintetizado)")
			:format(found, found + missing, missing))
	end)
end

-- ── both: read ───────────────────────────────────────────────────────────────

-- The asset chosen for this sound, or nil to use the synthesised tone.
function AudioCatalog.assetFor(soundId)
	if verified[soundId] == false then
		return nil
	end
	local store = root()
	if not store then
		return nil
	end
	local value = store:GetAttribute(soundId)
	return (type(value) == "string" and value ~= "") and value or nil
end

-- Client-side playability check. Search results can include assets this
-- experience is not allowed to play, so an id is only trusted once a Sound built
-- from it reports itself loaded.
function AudioCatalog.verifyAsync(soundId, timeout)
	if verified[soundId] ~= nil then
		return verified[soundId]
	end
	local asset = AudioCatalog.assetFor(soundId)
	if not asset then
		return false
	end

	local probe = Instance.new("Sound")
	probe.SoundId = asset
	probe.Volume = 0
	probe.Parent = game:GetService("SoundService")

	pcall(function()
		game:GetService("ContentProvider"):PreloadAsync({ probe })
	end)

	local deadline = os.clock() + (timeout or 3)
	while not probe.IsLoaded and os.clock() < deadline do
		task.wait(0.05)
	end

	local ok = probe.IsLoaded
	probe:Destroy()
	verified[soundId] = ok
	if not ok then
		warn(("[AudioCatalog] %s no se pudo cargar; usando tono sintetizado"):format(soundId))
	end
	return ok
end

function AudioCatalog.isResolved()
	local store = root()
	return store and store:GetAttribute("__resolved") == true
end

return AudioCatalog

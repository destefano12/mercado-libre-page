--!nonstrict
-- TakeStore.luau — holds this round's takes, and refuses anything malformed.
--
-- Takes arrive from the client, so they are untrusted input: a crafted payload
-- could otherwise claim a perfect contour, 10 000 notes, or negative times.
-- Everything is clamped and re-sorted here before it ever reaches Scoring,
-- and the server does its own grading — the client's score is never trusted.

local Config = require(game.ReplicatedStorage.Shared.Config)

local TakeStore = {}
local takes = {}

local MAX_NOTES = Config.TAKE.MAX_NOTES
local MIN_NOTE = Config.TAKE.MIN_NOTE
local PITCH_RANGE = Config.TAKE.PITCH_RANGE

local function sanitise(raw, duration)
	if type(raw) ~= "table" then
		return nil
	end
	local rawNotes = raw.notes
	if type(rawNotes) ~= "table" then
		return nil
	end

	local notes = {}
	for _, n in ipairs(rawNotes) do
		if #notes >= MAX_NOTES then
			break
		end
		if type(n) == "table"
			and type(n.t) == "number" and type(n.dur) == "number" and type(n.pitch) == "number"
			and n.t == n.t and n.dur == n.dur and n.pitch == n.pitch   -- reject NaN
		then
			local t = math.clamp(n.t, 0, duration)
			local dur = math.clamp(n.dur, MIN_NOTE, duration)
			if t + dur > duration then
				dur = math.max(MIN_NOTE, duration - t)
			end
			table.insert(notes, {
				t = t,
				dur = dur,
				pitch = math.clamp(n.pitch, -PITCH_RANGE, PITCH_RANGE),
			})
		end
	end

	table.sort(notes, function(a, b)
		return a.t < b.t
	end)

	return { notes = notes }
end

function TakeStore.submit(userId, raw, duration)
	if takes[userId] then
		return false, "already-submitted"   -- one take. No retries.
	end
	local clean = sanitise(raw, duration)
	if not clean then
		return false, "malformed"
	end
	takes[userId] = clean
	return true
end

function TakeStore.get(userId)
	return takes[userId]
end

function TakeStore.has(userId)
	return takes[userId] ~= nil
end

function TakeStore.count()
	local n = 0
	for _ in pairs(takes) do
		n += 1
	end
	return n
end

function TakeStore.clear()
	table.clear(takes)
end

-- A silent take, for a player who never submitted (left, crashed, froze).
function TakeStore.empty()
	return { notes = {} }
end

return TakeStore

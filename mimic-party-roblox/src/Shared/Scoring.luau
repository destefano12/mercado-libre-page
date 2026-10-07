--!nonstrict
-- Scoring.luau — melody, rhythm, attacks. Never timbre.
--
-- The one rule that matters: contours are mean-normalised before comparison,
-- so a low voice and a high voice tracing the same shape score identically.
-- Shared verbatim by server (party rounds) and client (solo modes), so a solo
-- run and a party round are graded by the same code path.

local Config = require(script.Parent.Config)

local Scoring = {}
local S = Config.SCORING

local function clamp01(x)
	return math.clamp(x, 0, 1)
end

-- Sample a note list into a per-frame pitch contour plus a voiced mask.
local function contour(notes, duration, samples)
	local pitch = table.create(samples, 0)
	local voiced = table.create(samples, false)
	if duration <= 0 then
		return pitch, voiced
	end
	for i = 1, samples do
		local t = (i - 0.5) / samples * duration
		for _, n in ipairs(notes) do
			if t >= n.t and t <= n.t + n.dur then
				pitch[i] = n.pitch
				voiced[i] = true
				break
			end
		end
	end
	return pitch, voiced
end

-- ── Melody ───────────────────────────────────────────────────────────────────
-- Compared only where both performances are voiced, each side mean-centred.
local function melodyAxis(ref, take, duration)
	local n = S.MELODY_SAMPLES
	local rp, rv = contour(ref.notes, duration, n)
	local tp, tv = contour(take.notes, duration, n)

	local idx, sumR, sumT = {}, 0, 0
	for i = 1, n do
		if rv[i] and tv[i] then
			table.insert(idx, i)
			sumR += rp[i]
			sumT += tp[i]
		end
	end
	if #idx == 0 then
		return 0, 0
	end

	local meanR, meanT = sumR / #idx, sumT / #idx
	local err = 0
	for _, i in ipairs(idx) do
		err += math.abs((rp[i] - meanR) - (tp[i] - meanT))
	end
	err /= #idx

	-- Overlap matters too: nailing the shape of one third of the sound is not
	-- the same as nailing the whole sound.
	local voicedRef = 0
	for i = 1, n do
		if rv[i] then voicedRef += 1 end
	end
	local coverage = voicedRef > 0 and (#idx / voicedRef) or 0

	local shape = clamp01(1 - err / S.MELODY_TOLERANCE)
	return shape * (0.35 + 0.65 * coverage), coverage
end

-- ── Rhythm ───────────────────────────────────────────────────────────────────
-- Onset-to-onset alignment, penalised for dropped or invented onsets.
local function rhythmAxis(ref, take)
	local a, b = ref.notes, take.notes
	local n = math.min(#a, #b)
	if n == 0 then
		return 0
	end
	local err = 0
	for i = 1, n do
		err += math.abs(a[i].t - b[i].t)
	end
	err /= n

	local accuracy = clamp01(1 - err / S.RHYTHM_TOLERANCE)
	local pairing = n / math.max(#a, #b)
	return accuracy * pairing
end

-- ── Attacks ──────────────────────────────────────────────────────────────────
-- How many times you actually hit it. Counting, not shaping.
local function attacksAxis(ref, take)
	local want = #ref.notes
	local got = #take.notes
	if want == 0 then
		return got == 0 and 1 or 0
	end
	return clamp01(1 - math.abs(got - want) / want)
end

-- ── Public ───────────────────────────────────────────────────────────────────
-- `take` is { notes = {...} }.
-- `weights` is optional and overrides the axis weights — used by the voice-only
-- input mode, which has no pitch to measure. Weights are renormalised, so a
-- dropped axis redistributes rather than shrinking the achievable total: a
-- perfect take scores MAX_SCORE under any weighting.
function Scoring.grade(ref, take, weights)
	take = take or { notes = {} }
	local duration = math.max(ref.duration, 0.2)

	local wM = weights and weights.WEIGHT_MELODY or S.WEIGHT_MELODY
	local wR = weights and weights.WEIGHT_RHYTHM or S.WEIGHT_RHYTHM
	local wA = weights and weights.WEIGHT_ATTACKS or S.WEIGHT_ATTACKS
	local sum = wM + wR + wA
	if sum <= 0 then
		wM, wR, wA, sum = S.WEIGHT_MELODY, S.WEIGHT_RHYTHM, S.WEIGHT_ATTACKS, 1
	else
		wM, wR, wA = wM / sum, wR / sum, wA / sum
	end

	local melody, coverage = melodyAxis(ref, take, duration)
	local rhythm = rhythmAxis(ref, take)
	local attacks = attacksAxis(ref, take)

	local blended = melody * wM + rhythm * wR + attacks * wA

	local max = S.MAX_SCORE
	return {
		melody = math.floor(melody * max + 0.5),
		rhythm = math.floor(rhythm * max + 0.5),
		attacks = math.floor(attacks * max + 0.5),
		total = math.floor(blended * max + 0.5),
		coverage = coverage,
		-- Which axes actually counted, so the playback card can grey out the rest.
		weighted = { melody = wM, rhythm = wR, attacks = wA },
	}
end

-- Plain-language verdict for the playback card.
function Scoring.verdict(total)
	if total >= 900 then return "IDÉNTICO" end
	if total >= 780 then return "CLAVADO" end
	if total >= 620 then return "CERCA" end
	if total >= 440 then return "RECONOCIBLE" end
	if total >= 240 then return "LEJOS" end
	return "¿QUÉ FUE ESO?"
end

return Scoring

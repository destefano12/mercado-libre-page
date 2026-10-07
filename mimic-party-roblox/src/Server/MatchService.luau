--!nonstrict
-- MatchService.luau — the authoritative match loop.
--
-- One coroutine owns the whole match. Phases advance on the server clock and
-- every transition is broadcast with an absolute deadline (GetServerTimeNow),
-- so clients render countdowns without ever being asked what time it is.
--
-- Three rules this file exists to enforce:
--   1. One take per round. TakeStore rejects a second submission outright.
--   2. The server grades. A client's own number is never read, only its contour.
--   3. A sabotage is revealed at playback, never when it is aimed.

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Scoring = require(Shared.Scoring)
local SoundLibrary = require(Shared.SoundLibrary)
local Roulette = require(Shared.Roulette)
local Sabotages = require(Shared.Sabotages)

-- A take recorded without pitch control is graded without the melody axis; the
-- weight is redistributed so a perfect take still reaches 1000 either way.
local function weightsForMode(mode)
	if mode == "voice_only" then
		return Config.SCORING_VOICE_ONLY
	end
	return nil
end

local PlayerProfiles = require(script.Parent.PlayerProfiles)
local TakeStore = require(script.Parent.TakeStore)
local StageBuilder = require(script.Parent.StageBuilder)
local VoiceGate = require(script.Parent.VoiceGate)

local MatchService = {}
local PHASE = Config.PHASE

local state = {
	phase = "boot",
	round = 0,
	rounds = Config.ROUNDS_PER_PARTY,
	soundId = nil,
	seed = 0,
	playlist = {},
	endsAt = 0,
	running = false,
	sabotagePickers = {},
}

local anchors

-- ── broadcast ────────────────────────────────────────────────────────────────

local function now()
	return workspace:GetServerTimeNow()
end

local function broadcast(extra)
	local payload = {
		phase = state.phase,
		round = state.round,
		rounds = state.rounds,
		soundId = state.soundId,
		endsAt = state.endsAt,
		serverNow = now(),
		scores = PlayerProfiles.snapshot(),
		sabotagePickers = state.sabotagePickers,
		minPlayers = Config.MIN_PLAYERS,
		playerCount = #Players:GetPlayers(),
	}
	if extra then
		for k, v in pairs(extra) do
			payload[k] = v
		end
	end
	Net.fireAll(Net.State, payload)
end

local function setPhase(phase, duration, extra)
	state.phase = phase
	state.endsAt = duration and (now() + duration) or 0
	broadcast(extra)
end

local function toast(text, tone)
	Net.fireAll(Net.Toast, { text = text, tone = tone or "neutral" })
end

-- ── stage choreography ───────────────────────────────────────────────────────

local function freeze(player, frozen)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = frozen and 0 or 10
		humanoid.JumpPower = frozen and 0 or 0   -- nobody jumps on a stage
		humanoid.AutoRotate = not frozen
	end
end

local function assignMarks()
	local profiles = PlayerProfiles.all()
	for i, profile in ipairs(profiles) do
		profile.markIndex = math.clamp(i, 1, Config.STAGE_MARKS)
	end
end

-- Puts everyone in the house, then walks them to their mark. This is the
-- opening shot of a party and the reason the venue has an aisle at all.
local function procession()
	assignMarks()
	anchors = anchors or StageBuilder.anchors()
	if not anchors then
		return
	end

	for _, profile in ipairs(PlayerProfiles.all()) do
		local player = profile.player
		local character = player.Character
		local spawnCF = anchors:FindFirstChild("SpawnCFrame" .. (profile.markIndex or 1))
		if character and spawnCF then
			character:PivotTo(spawnCF.Value + Vector3.new(0, 3, 0))
		end
		freeze(player, false)
		PlayerProfiles.dress(player)
	end

	setPhase("procession", PHASE.PROCESSION)

	-- Staggered departures: five people stepping off in unison looks like a
	-- cutscene, a half-second apart looks like a group of friends.
	for i, profile in ipairs(PlayerProfiles.all()) do
		task.delay((i - 1) * 0.45, function()
			local character = profile.player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local mark = anchors:FindFirstChild("Mark" .. (profile.markIndex or 1))
			if humanoid and mark then
				humanoid:MoveTo(mark.Position)
			end
		end)
	end

	task.wait(PHASE.PROCESSION)

	-- Snap to the mark and lock: the recording phase must not have anybody
	-- drifting off their light.
	for _, profile in ipairs(PlayerProfiles.all()) do
		local character = profile.player.Character
		local markCF = anchors:FindFirstChild("MarkCFrame" .. (profile.markIndex or 1))
		if character and markCF then
			character:PivotTo(markCF.Value)
		end
		freeze(profile.player, true)
	end
end

-- ── rounds ───────────────────────────────────────────────────────────────────

local function collectTakes(sound)
	TakeStore.clear()
	local deadline = PHASE.COUNT_IN + sound.duration + PHASE.TAKE_TAIL
	setPhase("record", deadline, { countIn = PHASE.COUNT_IN })

	local expected = #PlayerProfiles.all()
	local started = now()
	-- Close the window early once everybody is in, but never before the take
	-- window itself has elapsed — an early submit must not cut anyone short.
	while now() - started < deadline do
		if TakeStore.count() >= expected and now() - started >= PHASE.COUNT_IN + sound.duration then
			break
		end
		task.wait(0.1)
	end
end

local function gradeAndPlayback(sound)
	setPhase("playback")

	local gated = VoiceGate.closeAll()

	for _, profile in ipairs(PlayerProfiles.all()) do
		local take = TakeStore.get(profile.userId) or TakeStore.empty()
		local grade = Scoring.grade(sound, take, weightsForMode(take.mode))

		-- Multiplier won on a previous wheel.
		local awarded = math.floor(grade.total * profile.multiplier + 0.5)

		-- Sabotage: the penalty and the reveal land together, right here.
		local sabotage = profile.incomingSabotage
		if sabotage then
			awarded = math.max(0, awarded - Sabotages.penalty())
		end

		profile.score += awarded
		profile.lastGrade = grade

		Net.fireAll(Net.Playback, {
			userId = profile.userId,
			name = profile.name,
			characterId = profile.characterId,
			soundId = sound.id,
			take = take,
			grade = grade,
			awarded = awarded,
			multiplier = profile.multiplier,
			sabotage = sabotage and sabotage.id or nil,
			sabotageFrom = sabotage and sabotage.fromName or nil,
			verdict = Scoring.verdict(grade.total),
			inputMode = take.mode,
			voiceGated = gated,
		})

		profile.incomingSabotage = nil

		task.wait(sound.duration + PHASE.PLAYBACK_GAP)
	end

	VoiceGate.openAll()

	-- Multipliers are spent now that the round they applied to is scored.
	for _, profile in ipairs(PlayerProfiles.all()) do
		if profile.multiplierRounds > 0 then
			profile.multiplierRounds -= 1
			if profile.multiplierRounds <= 0 then
				profile.multiplier = 1
			end
		end
	end

	Net.fireAll(Net.Scores, { scores = PlayerProfiles.snapshot() })
end

local function spinWheel()
	local rng = Random.new(os.clock() * 1e6 % 2 ^ 31)
	local results = {}
	state.sabotagePickers = {}

	for _, profile in ipairs(PlayerProfiles.all()) do
		local index, segment = Roulette.spin(rng)
		table.insert(results, {
			userId = profile.userId,
			name = profile.name,
			segmentIndex = index,
			segmentId = segment.id,
			kind = segment.kind,
			label = segment.label,
			detail = Roulette.describe(segment),
		})

		if segment.kind == "points" then
			profile.score += segment.amount
		elseif segment.kind == "multiplier" then
			profile.multiplier = segment.amount
			profile.multiplierRounds = Config.ROULETTE.MULTIPLIER_DECAY
		elseif segment.kind == "sabotage" then
			profile.pendingSabotage = segment.sabotage
			table.insert(state.sabotagePickers, profile.userId)
		end
	end

	setPhase("roulette", PHASE.ROULETTE_SPIN)
	Net.fireAll(Net.RouletteSpin, { results = results, spin = PHASE.ROULETTE_SPIN })
	task.wait(PHASE.ROULETTE_SPIN)

	-- Aiming window. Only the winners see a picker; everyone else waits, and
	-- crucially nobody is told who is being aimed at.
	if #state.sabotagePickers > 0 then
		setPhase("sabotage_pick", PHASE.SABOTAGE_PICK)
		local deadline = now() + PHASE.SABOTAGE_PICK
		while now() < deadline do
			local outstanding = false
			for _, profile in ipairs(PlayerProfiles.all()) do
				if profile.pendingSabotage then
					outstanding = true
					break
				end
			end
			if not outstanding then
				break
			end
			task.wait(0.15)
		end

		-- Unaimed sabotages pick a victim themselves. Declining is not an out.
		for _, profile in ipairs(PlayerProfiles.all()) do
			if profile.pendingSabotage then
				local candidates = {}
				for _, other in ipairs(PlayerProfiles.all()) do
					if other ~= profile then
						table.insert(candidates, other)
					end
				end
				if #candidates > 0 then
					local victim = candidates[math.random(1, #candidates)]
					victim.incomingSabotage = {
						id = profile.pendingSabotage,
						fromName = profile.name,
					}
				end
				profile.pendingSabotage = nil
			end
		end
		state.sabotagePickers = {}
	end

	Net.fireAll(Net.Scores, { scores = PlayerProfiles.snapshot() })
end

-- ── the loop ─────────────────────────────────────────────────────────────────

local function enoughPlayers()
	return #Players:GetPlayers() >= Config.MIN_PLAYERS
end

local function lobby()
	PlayerProfiles.resetScores()
	TakeStore.clear()

	for _, player in ipairs(Players:GetPlayers()) do
		freeze(player, false)
	end

	-- Wait for a room. The countdown restarts if the room empties out.
	while not enoughPlayers() do
		setPhase("lobby")
		repeat
			task.wait(0.5)
		until enoughPlayers()
	end

	local wait_for = (#Players:GetPlayers() >= Config.MAX_PLAYERS)
		and PHASE.QUICK_START
		or PHASE.LOBBY_COUNTDOWN
	setPhase("lobby", wait_for)

	local deadline = now() + wait_for
	while now() < deadline do
		if not enoughPlayers() then
			return false   -- room collapsed; start over
		end
		if #Players:GetPlayers() >= Config.MAX_PLAYERS and deadline - now() > PHASE.QUICK_START then
			deadline = now() + PHASE.QUICK_START
			state.endsAt = deadline
			broadcast()
		end
		task.wait(0.25)
	end

	return enoughPlayers()
end

local function playParty()
	state.seed = os.time() + math.random(1, 10000)
	state.playlist = SoundLibrary.playlist(state.seed, state.rounds)
	state.rounds = Config.ROUNDS_PER_PARTY

	procession()

	for round = 1, state.rounds do
		if not enoughPlayers() then
			toast("La sala se quedó vacía. Volvemos al lobby.", "warn")
			return
		end

		local sound = state.playlist[round]
		state.round = round
		state.soundId = sound.id

		setPhase("round_intro", PHASE.ROUND_INTRO)
		task.wait(PHASE.ROUND_INTRO)

		-- The reference plays for the whole table at once.
		setPhase("reference", sound.duration + PHASE.REFERENCE_PAD * 2)
		task.wait(sound.duration + PHASE.REFERENCE_PAD * 2)

		collectTakes(sound)
		gradeAndPlayback(sound)

		if round < state.rounds then
			spinWheel()
		end
	end

	state.soundId = nil
	setPhase("results", PHASE.RESULTS)

	local ranked = PlayerProfiles.snapshot()
	if ranked[1] then
		toast(("Gana %s con %d puntos."):format(ranked[1].name, ranked[1].score), "good")
	end
	task.wait(PHASE.RESULTS)
end

function MatchService.start()
	if state.running then
		return
	end
	state.running = true

	anchors = StageBuilder.anchors()

	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				if lobby() then
					playParty()
				end
			end)
			if not ok then
				-- A match must never take the server down with it: log, reset,
				-- and put everybody back in the lobby.
				warn("[MatchService] match aborted: " .. tostring(err))
				VoiceGate.openAll()
				state.round = 0
				state.soundId = nil
				toast("Hubo un problema en la partida. Reiniciando la sala.", "bad")
				task.wait(3)
			end
			state.round = 0
			TakeStore.clear()
			task.wait(1)
		end
	end)
end

-- ── client intents ───────────────────────────────────────────────────────────

function MatchService.bindRemotes()
	Net.onServer(Net.SubmitTake, function(player, payload)
		if state.phase ~= "record" then
			return
		end
		local profile = PlayerProfiles.get(player)
		local sound = state.soundId and SoundLibrary.get(state.soundId)
		if not profile or not sound then
			return
		end
		TakeStore.submit(profile.userId, payload, sound.duration)
	end)

	Net.onServer(Net.ChooseCharacter, function(player, payload)
		if state.phase ~= "lobby" and state.phase ~= "results" then
			return   -- no swapping costume mid-performance
		end
		if type(payload) ~= "table" or type(payload.characterId) ~= "string" then
			return
		end
		if PlayerProfiles.setCharacter(player, payload.characterId) then
			broadcast()
		end
	end)

	Net.onServer(Net.ChooseSabotageTarget, function(player, payload)
		if state.phase ~= "sabotage_pick" then
			return
		end
		local profile = PlayerProfiles.get(player)
		if not profile or not profile.pendingSabotage then
			return
		end
		if type(payload) ~= "table" or type(payload.userId) ~= "number" then
			return
		end
		local victim = PlayerProfiles.byUserId(payload.userId)
		if not victim or victim == profile then
			return
		end
		victim.incomingSabotage = {
			id = profile.pendingSabotage,
			fromName = profile.name,
		}
		profile.pendingSabotage = nil
		-- The victim is told nothing. They find out when their take plays.
		Net.fireClient(Net.SabotageHit, player, { aimed = true, at = victim.name })
	end)

	Net.onServer(Net.SetReady, function(player, payload)
		local profile = PlayerProfiles.get(player)
		if profile then
			profile.ready = type(payload) == "table" and payload.ready == true
			broadcast()
		end
	end)
end

function MatchService.onPlayerAdded(player)
	PlayerProfiles.add(player)
	player.CharacterAppearanceLoaded:Connect(function()
		PlayerProfiles.dress(player)
	end)
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		PlayerProfiles.dress(player)
		freeze(player, state.phase == "record" or state.phase == "playback")
	end)
	broadcast()
end

function MatchService.onPlayerRemoving(player)
	PlayerProfiles.remove(player)
	broadcast()
end

return MatchService

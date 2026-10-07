--!nonstrict
-- Roulette.luau — the wheel between rounds. One spin, the whole table at once.
--
-- The wheel is the reason this game is not a karaoke scoreboard. Weights are
-- tuned so roughly a third of spins hand somebody a sabotage: enough that the
-- threat is real every round, rare enough that it still lands as an event.

local Sabotages = require(script.Parent.Sabotages)

local Roulette = {}

local segments = {
	{ id = "p50",   kind = "points",     label = "+50",        amount = 50,   weight = 14 },
	{ id = "p100",  kind = "points",     label = "+100",       amount = 100,  weight = 10 },
	{ id = "p150",  kind = "points",     label = "+150",       amount = 150,  weight = 6 },
	{ id = "m15",   kind = "multiplier", label = "×1.5",       amount = 1.5,  weight = 8 },
	{ id = "m20",   kind = "multiplier", label = "×2",         amount = 2.0,  weight = 4 },
	{ id = "sab1",  kind = "sabotage",   label = "SATURACIÓN", sabotage = "saturate", weight = 7 },
	{ id = "sab2",  kind = "sabotage",   label = "ECO",        sabotage = "echo",     weight = 7 },
	{ id = "sab3",  kind = "sabotage",   label = "TONO",       sabotage = "pitch",    weight = 7 },
	{ id = "sab4",  kind = "sabotage",   label = "PICADO",     sabotage = "chop",     weight = 6 },
	{ id = "sab5",  kind = "sabotage",   label = "SUSTITUIR",  sabotage = "swap",     weight = 4 },
	{ id = "none",  kind = "nothing",    label = "APLAUSO",    weight = 5 },
}

local total = 0
for _, s in ipairs(segments) do
	total += s.weight
end

function Roulette.segments()
	return segments
end

function Roulette.indexOf(id)
	for i, s in ipairs(segments) do
		if s.id == id then
			return i
		end
	end
	return nil
end

-- Weighted draw. `rng` is passed in so the server stays the only authority.
function Roulette.spin(rng)
	local roll = (rng and rng:NextNumber() or math.random()) * total
	local acc = 0
	for i, s in ipairs(segments) do
		acc += s.weight
		if roll <= acc then
			return i, s
		end
	end
	return #segments, segments[#segments]
end

function Roulette.describe(segment)
	if segment.kind == "points" then
		return ("Te llevás %d puntos."):format(segment.amount)
	elseif segment.kind == "multiplier" then
		return ("Tu próxima ronda vale ×%s."):format(segment.amount)
	elseif segment.kind == "sabotage" then
		local def = Sabotages.get(segment.sabotage)
		return def and ("Elegí a quién: " .. def.blurb) or "Elegí a quién."
	end
	return "Nada. La mesa aplaude igual."
end

return Roulette

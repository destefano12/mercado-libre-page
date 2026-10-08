--!nonstrict
-- Rooms.luau — room codes: the alphabet, the format, and the key naming.
--
-- Shared so the client can reject a malformed code before spending a round
-- trip, and so the server and client can never disagree about what a code is.

local Rooms = {}

-- No O/0, no I/1, no S/5: a code gets read out loud over voice chat, and those
-- are the pairs people get wrong. 32 symbols, 5 places → 33.5M combinations.
Rooms.ALPHABET = "ABCDEFGHJKLMNPQRTUVWXYZ2346789"
Rooms.LENGTH = 5
Rooms.DATASTORE = "MimicPartyRooms_v1"
Rooms.TTL = 60 * 60 * 6    -- a code stops resolving after six hours

-- Codes are generated server-side only; this lives here so the format is
-- defined in one place.
function Rooms.generate(rng)
	rng = rng or Random.new(os.clock() * 1e6 % 2 ^ 31)
	local chars = {}
	for i = 1, Rooms.LENGTH do
		local pick = rng:NextInteger(1, #Rooms.ALPHABET)
		chars[i] = Rooms.ALPHABET:sub(pick, pick)
	end
	return table.concat(chars)
end

-- Accepts what a person typed and returns a canonical code, or nil plus a
-- reason. Lowercase and stray spaces or dashes are the user being normal.
function Rooms.normalise(input)
	if type(input) ~= "string" then
		return nil, "Escribí un código."
	end
	local cleaned = input:upper():gsub("[%s%-_]", "")
	if #cleaned == 0 then
		return nil, "Escribí un código."
	end
	if #cleaned ~= Rooms.LENGTH then
		return nil, ("El código tiene %d caracteres."):format(Rooms.LENGTH)
	end
	for i = 1, #cleaned do
		local c = cleaned:sub(i, i)
		if not Rooms.ALPHABET:find(c, 1, true) then
			return nil, ("“%s” no es un carácter válido."):format(c)
		end
	end
	return cleaned
end

function Rooms.key(code)
	return "room_" .. code
end

-- Pretty-prints a code for display: ABC-DE reads better than ABCDE.
function Rooms.display(code)
	if type(code) ~= "string" or #code ~= Rooms.LENGTH then
		return code or ""
	end
	return code:sub(1, 3) .. "-" .. code:sub(4)
end

return Rooms

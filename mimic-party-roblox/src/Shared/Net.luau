--!nonstrict
-- Net.luau — the only place RemoteEvents are named. The server creates them,
-- the client waits for them; callers on both sides use the same accessor.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IS_SERVER = RunService:IsServer()
local FOLDER_NAME = "MimicPartyNet"

local Net = {}

-- Server → client
Net.State = "State"                 -- authoritative phase payload
Net.Playback = "Playback"           -- one take is about to play
Net.RouletteSpin = "RouletteSpin"   -- wheel result for the whole table
Net.SabotageHit = "SabotageHit"     -- you were targeted (revealed at playback)
Net.Scores = "Scores"               -- scoreboard delta
Net.Toast = "Toast"                 -- short room-wide notice

-- Client → server
Net.SubmitTake = "SubmitTake"
Net.ChooseCharacter = "ChooseCharacter"
Net.ChooseSabotageTarget = "ChooseSabotageTarget"
Net.SetReady = "SetReady"
Net.RequestSoloScore = "RequestSoloScore"

local ALL = {
	Net.State, Net.Playback, Net.RouletteSpin, Net.SabotageHit, Net.Scores, Net.Toast,
	Net.SubmitTake, Net.ChooseCharacter, Net.ChooseSabotageTarget, Net.SetReady,
	Net.RequestSoloScore,
}

local folder

local function root()
	if folder then
		return folder
	end
	if IS_SERVER then
		folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		for _, name in ipairs(ALL) do
			if not folder:FindFirstChild(name) then
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = folder
			end
		end
	else
		folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 30)
	end
	return folder
end

function Net.get(name)
	local r = root()
	if not r then
		error("[Net] network folder never replicated", 2)
	end
	local remote = r:FindFirstChild(name) or r:WaitForChild(name, 20)
	if not remote then
		error(("[Net] remote %q is missing"):format(tostring(name)), 2)
	end
	return remote
end

-- Convenience wrappers so call sites read cleanly.
function Net.fireClient(name, player, payload)
	Net.get(name):FireClient(player, payload)
end

function Net.fireAll(name, payload)
	Net.get(name):FireAllClients(payload)
end

function Net.fireServer(name, payload)
	Net.get(name):FireServer(payload)
end

function Net.onServer(name, fn)
	return Net.get(name).OnServerEvent:Connect(fn)
end

function Net.onClient(name, fn)
	return Net.get(name).OnClientEvent:Connect(fn)
end

function Net.init()
	assert(IS_SERVER, "Net.init is server-only")
	root()
end

return Net

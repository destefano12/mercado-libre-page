--!nonstrict
-- init.server.luau — boot order, and nothing else.
--
-- Build the venue before anyone can spawn, open the network, then hand control
-- to MatchService. Everything after this line is event-driven.

local Players = game:GetService("Players")

local Net = require(game.ReplicatedStorage.Shared.Net)
local AudioCatalog = require(game.ReplicatedStorage.Shared.AudioCatalog)

local StageBuilder = require(script.StageBuilder)
local LightingRig = require(script.LightingRig)
local MatchService = require(script.MatchService)
local RoomService = require(script.RoomService)
local VoiceChat = require(script.VoiceChat)

-- Players must not fall into a half-built room.
Players.CharacterAutoLoads = false

LightingRig.apply()
StageBuilder.build()
Net.init()

-- Pulls reference audio from Roblox's own library. Runs in the background: every
-- sound has a synthesised fallback, so no round ever waits on this.
AudioCatalog.resolveAsync()

MatchService.bindRemotes()
RoomService.bindRemotes()

-- Is this a public server or somebody's private room? Everything downstream
-- (pack selection, host controls) depends on the answer.
RoomService.start()
VoiceChat.start()

Players.PlayerAdded:Connect(function(player)
	MatchService.onPlayerAdded(player)
	RoomService.onPlayerAdded(player)
	VoiceChat.onPlayerAdded(player)
	player:LoadCharacter()
end)

Players.PlayerRemoving:Connect(function(player)
	MatchService.onPlayerRemoving(player)
	RoomService.onPlayerRemoving(player)
	VoiceChat.onPlayerRemoving(player)
end)

-- Anyone already in (Studio solo test, or a hot reload).
for _, player in ipairs(Players:GetPlayers()) do
	MatchService.onPlayerAdded(player)
	RoomService.onPlayerAdded(player)
	VoiceChat.onPlayerAdded(player)
	player:LoadCharacter()
end

MatchService.start()

print("[Mimic Party] venue built, match loop running.")

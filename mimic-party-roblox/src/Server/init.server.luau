--!nonstrict
-- init.server.luau — boot order, and nothing else.
--
-- Build the venue before anyone can spawn, open the network, then hand control
-- to MatchService. Everything after this line is event-driven.

local Players = game:GetService("Players")

local Net = require(game.ReplicatedStorage.Shared.Net)

local StageBuilder = require(script.StageBuilder)
local LightingRig = require(script.LightingRig)
local MatchService = require(script.MatchService)

-- Players must not fall into a half-built room.
Players.CharacterAutoLoads = false

LightingRig.apply()
StageBuilder.build()
Net.init()

MatchService.bindRemotes()

Players.PlayerAdded:Connect(function(player)
	MatchService.onPlayerAdded(player)
	player:LoadCharacter()
end)

Players.PlayerRemoving:Connect(MatchService.onPlayerRemoving)

-- Anyone already in (Studio solo test, or a hot reload).
for _, player in ipairs(Players:GetPlayers()) do
	MatchService.onPlayerAdded(player)
	player:LoadCharacter()
end

MatchService.start()

print("[Mimic Party] venue built, match loop running.")

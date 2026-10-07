--!nonstrict
-- PlayerProfiles.luau — per-player match state, and the character they wear.

local Players = game:GetService("Players")
local Characters = require(game.ReplicatedStorage.Shared.Characters)

local PlayerProfiles = {}
local profiles = {}

local function takenCharacters(except)
	local taken = {}
	for player, p in pairs(profiles) do
		if player ~= except and p.characterId then
			taken[p.characterId] = true
		end
	end
	return taken
end

function PlayerProfiles.add(player)
	local character = Characters.firstFree(takenCharacters(player))
	profiles[player] = {
		player = player,
		userId = player.UserId,
		name = player.DisplayName,
		characterId = character.id,
		score = 0,
		multiplier = 1,
		multiplierRounds = 0,
		ready = false,
		markIndex = nil,
		lastGrade = nil,
		incomingSabotage = nil,   -- set by a saboteur, consumed at playback
		pendingSabotage = nil,    -- won from the wheel, not yet aimed
	}
	return profiles[player]
end

function PlayerProfiles.remove(player)
	profiles[player] = nil
end

function PlayerProfiles.get(player)
	return profiles[player]
end

function PlayerProfiles.byUserId(userId)
	for _, p in pairs(profiles) do
		if p.userId == userId then
			return p
		end
	end
	return nil
end

function PlayerProfiles.all()
	local out = {}
	for _, p in pairs(profiles) do
		table.insert(out, p)
	end
	table.sort(out, function(a, b)
		return a.userId < b.userId
	end)
	return out
end

function PlayerProfiles.setCharacter(player, characterId)
	local profile = profiles[player]
	local character = Characters.get(characterId)
	if not profile or not character then
		return false
	end
	if takenCharacters(player)[characterId] then
		return false   -- somebody on stage is already wearing it
	end
	profile.characterId = characterId
	PlayerProfiles.dress(player)
	return true
end

-- Applies the character's palette to the avatar. Cosmetic only.
function PlayerProfiles.dress(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local character = Characters.get(profile.characterId)
	local model = player.Character
	if not character or not model then
		return
	end

	local colors = model:FindFirstChildOfClass("BodyColors") or Instance.new("BodyColors")
	colors.HeadColor3 = character.body
	colors.LeftArmColor3 = character.body
	colors.RightArmColor3 = character.body
	colors.TorsoColor3 = character.shirt
	colors.LeftLegColor3 = character.pants
	colors.RightLegColor3 = character.pants
	colors.Parent = model

	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") then
			part.Material = Enum.Material.SmoothPlastic
		end
	end

	-- Stage name over the performer, legible from the house camera.
	local head = model:FindFirstChild("Head")
	if head then
		local old = head:FindFirstChild("StageName")
		if old then
			old:Destroy()
		end
		local gui = Instance.new("BillboardGui")
		gui.Name = "StageName"
		gui.Size = UDim2.fromOffset(190, 46)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 2.3, 0)
		gui.AlwaysOnTop = false
		gui.MaxDistance = 90
		gui.Parent = head

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 0.62)
		label.BackgroundTransparency = 1
		label.Text = character.name
		label.TextColor3 = Color3.fromRGB(238, 233, 224)
		label.TextScaled = true
		label.FontFace = Font.fromEnum(Enum.Font.GothamBold)
		label.TextStrokeTransparency = 0.6
		label.Parent = gui

		local tag = Instance.new("TextLabel")
		tag.Size = UDim2.fromScale(1, 0.38)
		tag.Position = UDim2.fromScale(0, 0.62)
		tag.BackgroundTransparency = 1
		tag.Text = character.tag
		tag.TextColor3 = character.accent
		tag.TextScaled = true
		tag.FontFace = Font.fromEnum(Enum.Font.Gotham)
		tag.TextStrokeTransparency = 0.8
		tag.Parent = gui
	end
end

function PlayerProfiles.resetScores()
	for _, p in pairs(profiles) do
		p.score = 0
		p.multiplier = 1
		p.multiplierRounds = 0
		p.lastGrade = nil
		p.incomingSabotage = nil
		p.pendingSabotage = nil
	end
end

-- The payload every client gets for the scoreboard.
function PlayerProfiles.snapshot()
	local out = {}
	for _, p in ipairs(PlayerProfiles.all()) do
		table.insert(out, {
			userId = p.userId,
			name = p.name,
			characterId = p.characterId,
			score = p.score,
			multiplier = p.multiplier,
			markIndex = p.markIndex,
		})
	end
	table.sort(out, function(a, b)
		if a.score == b.score then
			return a.name < b.name
		end
		return a.score > b.score
	end)
	return out
end

Players.PlayerRemoving:Connect(PlayerProfiles.remove)

return PlayerProfiles

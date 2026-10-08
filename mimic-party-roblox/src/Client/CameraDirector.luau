--!nonstrict
-- CameraDirector.luau — the camera is a character in this game.
--
-- Six framed shots live on the stage anchors; this module blends between them
-- with a critically-damped spring, so nothing ever snaps and nothing overshoots.
-- The procession shot is the only live one: it tracks the centroid of the
-- players walking down the aisle, which is the shot the whole opening is for.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)

local CameraDirector = {}

local camera = Workspace.CurrentCamera
local anchors
local current = { cf = nil, fov = Config.CAMERA_FOV.HOUSE }
local target = { cf = nil, fov = Config.CAMERA_FOV.HOUSE }
local mode = "static"
local blend = 3.2        -- higher = tighter follow
local bound = false

local function anchorShot(name)
	if not anchors then
		return nil, nil
	end
	local cf = anchors:FindFirstChild(name)
	local fov = anchors:FindFirstChild(name .. "FOV")
	return cf and cf.Value or nil, fov and fov.Value or nil
end

local function centroidOfPlayers()
	local sum, count = Vector3.zero, 0
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			sum += root.Position
			count += 1
		end
	end
	if count == 0 then
		return nil
	end
	return sum / count
end

function CameraDirector.init(stageAnchors)
	anchors = stageAnchors
	camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = Config.CAMERA_FOV.HOUSE

	local cf = select(1, anchorShot("CamHouse"))
	current.cf = cf or CFrame.new(0, 16, 44)
	target.cf = current.cf
	camera.CFrame = current.cf

	if bound then
		RunService:UnbindFromRenderStep("MimicPartyCamera")
		bound = false
	end

	bound = true
	RunService:BindToRenderStep("MimicPartyCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if not camera or not current.cf then
			return
		end

		if mode == "procession" then
			-- Dolly from the back of the house toward the apron while keeping the
			-- group framed slightly left of centre: a tracking shot, not a pan.
			local base = select(1, anchorShot("CamProcession"))
			local focus = centroidOfPlayers()
			if base and focus then
				local drift = math.clamp((focus.Z - 2) / 32, 0, 1)
				-- The dolly's end point has to clear the crowd too: the seats run
				-- to z = 44 and heads reach y ~ 7, so the camera stays above 10.
				local from = base.Position:Lerp(Vector3.new(-7, 10.5, 21), 1 - drift)
				target.cf = CFrame.lookAt(from, focus + Vector3.new(0, 2.4, 0))
			elseif base then
				target.cf = base
			end
		end

		-- Exponential smoothing: frame-rate independent, never overshoots.
		local alpha = 1 - math.exp(-blend * dt)
		current.cf = current.cf:Lerp(target.cf, alpha)
		current.fov += (target.fov - current.fov) * alpha

		camera.CFrame = current.cf
		camera.FieldOfView = current.fov
	end)
end

-- `tightness` lets a cut feel like a cut (high) or a drift feel like a drift (low).
function CameraDirector.setShot(name, tightness)
	local cf, fov = anchorShot(name)
	if not cf then
		return
	end
	mode = "static"
	target.cf = cf
	target.fov = fov or Config.CAMERA_FOV.WIDE
	blend = tightness or 3.2
end

function CameraDirector.setProcession()
	mode = "procession"
	target.fov = Config.CAMERA_FOV.HOUSE
	blend = 1.5   -- slow, so the walk has weight
end

-- Pushes in on one mark. Used when a single take is playing back.
function CameraDirector.focusMark(markIndex, tightness)
	if not anchors then
		return
	end
	local mark = anchors:FindFirstChild("Mark" .. tostring(markIndex))
	if not mark then
		CameraDirector.setShot("CamWide", tightness)
		return
	end
	mode = "static"
	local focus = mark.Position + Vector3.new(0, 4.2, 0)
	target.cf = CFrame.lookAt(focus + Vector3.new(mark.Position.X * -0.12, 2.6, 15.5), focus)
	target.fov = Config.CAMERA_FOV.CLOSE + 6
	blend = tightness or 2.6
end

function CameraDirector.stop()
	if bound then
		RunService:UnbindFromRenderStep("MimicPartyCamera")
		bound = false
	end
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
end

-- Phase → shot. The single place the look of the game is decided.
local SHOTS = {
	lobby = function() CameraDirector.setShot("CamHouse", 2.0) end,
	procession = function() CameraDirector.setProcession() end,
	round_intro = function() CameraDirector.setShot("CamWide", 2.4) end,
	reference = function() CameraDirector.setShot("CamWide", 2.4) end,
	record = function() CameraDirector.setShot("CamBooth", 3.0) end,
	playback = function() CameraDirector.setShot("CamWide", 2.8) end,
	roulette = function() CameraDirector.setShot("CamRoulette", 3.4) end,
	sabotage_pick = function() CameraDirector.setShot("CamRoulette", 3.0) end,
	results = function() CameraDirector.setShot("CamResults", 2.2) end,
}

function CameraDirector.onPhase(phase)
	local shot = SHOTS[phase]
	if shot then
		shot()
	end
end

return CameraDirector

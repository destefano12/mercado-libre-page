--!nonstrict
-- StageBuilder.luau — builds the room procedurally, at runtime.
--
-- A cosy cartoon living room, taken from the reference footage: honey plank
-- floor, warm red walls, a big magenta rug the performers stand on, a red
-- armchair, two speaker stacks, potted plants, a shelf with a cat, a wall sign,
-- and a string of party bulbs across the back.
--
-- Everything is primitives, because the project ships without uploaded assets.
-- What keeps it from reading as a pile of boxes is layering: nested trims for
-- mouldings, a cylinder on every exposed edge to kill the hard 90° corner, and
-- controlled randomness so no two objects line up.
--
-- NOTE on cylinders: a Roblox cylinder already lies along its LOCAL X axis. So
-- `cyl` with no rotation gives a horizontal rod, and CFrame.Angles(0, 0, rad(90))
-- STANDS IT UP. Getting this backwards once put a 62-stud pole through the
-- middle of the room.
--
-- Geometry: floor at y = 0, the rug centred on (0, -2), performers in a row at
-- z = -2 facing +Z, camera out at +Z.

local Workspace = game:GetService("Workspace")
local Palette = require(game.ReplicatedStorage.Shared.Palette)
local Config = require(game.ReplicatedStorage.Shared.Config)

local StageBuilder = {}

local ROOM_X = 38          -- half-width
local ROOM_BACK = -30
local ROOM_FRONT = 34
local WALL_H = 30
local LINE_Z = -2          -- where the performers stand
local MARK_X = { -16, -8, 0, 8, 16 }

-- ── primitives ───────────────────────────────────────────────────────────────

local function box(parent, size, position, color, material, props)
	local p = Instance.new("Part")
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in pairs(props) do p[k] = v end
	end
	p.Parent = parent
	return p
end

local function cyl(parent, diameter, length, cframe, color, material, props)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(length, diameter, diameter)
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in pairs(props) do p[k] = v end
	end
	p.Parent = parent
	return p
end

local function ball(parent, diameter, position, color, material, props)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(diameter, diameter, diameter)
	p.Position = position
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	if props then
		for k, v in pairs(props) do p[k] = v end
	end
	p.Parent = parent
	return p
end

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- A flat disc lying on the floor. Used for the rug and every round inlay.
local function disc(parent, diameter, y, center, color, material)
	return cyl(parent, diameter, 0.12,
		CFrame.new(center.X, y, center.Z) * CFrame.Angles(0, 0, math.rad(90)),
		color, material)
end

-- Text painted on a wall. No decals, no uploads.
local function sign(parent, text, size, cframe, color, font)
	local plate = Instance.new("Part")
	plate.Size = size
	plate.CFrame = cframe
	plate.Transparency = 1
	plate.Anchored = true
	plate.CanCollide = false
	plate.CanQuery = false
	plate.Parent = parent

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(size.X * 24, size.Y * 24)
	gui.LightInfluence = 0.25
	gui.Parent = plate

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.FontFace = Font.fromEnum(font or Enum.Font.FredokaOne)
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = Palette.Dark
	stroke.Thickness = 3
	stroke.Transparency = 0.2
	stroke.Parent = label

	return plate
end

-- ── shell ────────────────────────────────────────────────────────────────────

local function buildShell(root)
	local shell = folder("Shell", root)

	-- Plank floor, laid along X with per-plank tone variation.
	box(shell, Vector3.new(ROOM_X * 2, 2, ROOM_FRONT - ROOM_BACK),
		Vector3.new(0, -1, (ROOM_FRONT + ROOM_BACK) / 2),
		Palette.FloorDark, Enum.Material.WoodPlanks, { CanCollide = true })
	local plankW = 2.4
	local planks = math.floor((ROOM_FRONT - ROOM_BACK) / plankW)
	for i = 0, planks - 1 do
		local z = ROOM_BACK + plankW * (i + 0.5)
		local shade = (i % 3 == 0) and Palette.FloorDark or Palette.Floor
		box(shell, Vector3.new(ROOM_X * 2 - 0.3, 0.3, plankW - 0.14),
			Vector3.new(0, -0.15, z),
			shade:Lerp(Palette.Dark, (i % 5) * 0.012), Enum.Material.WoodPlanks,
			{ CanCollide = true })
	end

	-- Walls.
	local function wall(size, position)
		box(shell, size, position, Palette.Wall, Enum.Material.SmoothPlastic, { CanCollide = true })
	end
	wall(Vector3.new(ROOM_X * 2 + 4, WALL_H, 2), Vector3.new(0, WALL_H / 2, ROOM_BACK - 1))
	wall(Vector3.new(2, WALL_H, ROOM_FRONT - ROOM_BACK), Vector3.new(-ROOM_X - 1, WALL_H / 2, (ROOM_FRONT + ROOM_BACK) / 2))
	wall(Vector3.new(2, WALL_H, ROOM_FRONT - ROOM_BACK), Vector3.new(ROOM_X + 1, WALL_H / 2, (ROOM_FRONT + ROOM_BACK) / 2))
	box(shell, Vector3.new(ROOM_X * 2 + 4, 2, ROOM_FRONT - ROOM_BACK + 4),
		Vector3.new(0, WALL_H + 1, (ROOM_FRONT + ROOM_BACK) / 2), Palette.WallDark)

	-- Skirting board, and a picture rail higher up: two horizontal lines are
	-- what stop a flat wall reading as a void.
	local function rail(y, thickness, colour)
		box(shell, Vector3.new(ROOM_X * 2, thickness, 0.5), Vector3.new(0, y, ROOM_BACK + 0.2), colour)
		box(shell, Vector3.new(0.5, thickness, ROOM_FRONT - ROOM_BACK), Vector3.new(-ROOM_X + 0.2, y, (ROOM_FRONT + ROOM_BACK) / 2), colour)
		box(shell, Vector3.new(0.5, thickness, ROOM_FRONT - ROOM_BACK), Vector3.new(ROOM_X - 0.2, y, (ROOM_FRONT + ROOM_BACK) / 2), colour)
	end
	rail(0.9, 1.8, Palette.Skirting)
	rail(18, 0.8, Palette.Skirting)
	rail(18.7, 0.3, Palette.TrimDark)

	return shell
end

-- ── rug ──────────────────────────────────────────────────────────────────────

local function buildRug(root)
	local rug = folder("Rug", root)
	local centre = Vector3.new(0, 0, LINE_Z)
	disc(rug, 46, 0.08, centre, Palette.RugOuter, Enum.Material.Fabric)
	disc(rug, 38, 0.14, centre, Palette.RugMid, Enum.Material.Fabric)
	disc(rug, 29, 0.2, centre, Palette.RugInner, Enum.Material.Fabric)
	disc(rug, 24, 0.26, centre, Palette.RugMid, Enum.Material.Fabric)
	return rug
end

-- ── furniture ────────────────────────────────────────────────────────────────

local function buildArmchair(root)
	local chair = folder("Armchair", root)
	local base = CFrame.new(-28, 0, -8) * CFrame.Angles(0, math.rad(34), 0)

	local function piece(size, offset, colour)
		local p = box(chair, size, Vector3.zero, colour, Enum.Material.Fabric)
		p.CFrame = base * CFrame.new(offset)
		return p
	end
	piece(Vector3.new(9, 2.6, 9), Vector3.new(0, 2.2, 0), Palette.Chair)        -- seat
	piece(Vector3.new(9, 9, 2.2), Vector3.new(0, 6, -3.6), Palette.Chair)       -- back
	piece(Vector3.new(2.2, 5, 9), Vector3.new(-3.6, 4.4, 0), Palette.ChairDark) -- arms
	piece(Vector3.new(2.2, 5, 9), Vector3.new(3.6, 4.4, 0), Palette.ChairDark)
	-- Buttoned back: a grid of little dimples, the cheapest upholstery there is.
	for row = 0, 2 do
		for col = -1, 1 do
			local p = ball(chair, 0.7, Vector3.zero, Palette.ChairDark)
			p.CFrame = base * CFrame.new(col * 2.4, 4.6 + row * 2, -2.5)
		end
	end
	for _, dx in ipairs({ -3.2, 3.2 }) do
		for _, dz in ipairs({ -3.2, 3.2 }) do
			local leg = cyl(chair, 1.1, 1.8, CFrame.new(0, 0, 0), Palette.Shelf, Enum.Material.Wood)
			leg.CFrame = base * CFrame.new(dx, 0.9, dz) * CFrame.Angles(0, 0, math.rad(90))
		end
	end
	return chair
end

local function buildSpeaker(root, x)
	local sp = folder("Speaker", root)
	local z = -22
	box(sp, Vector3.new(8, 1.2, 7), Vector3.new(x, 0.6, z), Palette.Dark)
	box(sp, Vector3.new(7.4, 16, 6.4), Vector3.new(x, 9.2, z), Palette.Speaker, Enum.Material.SmoothPlastic, { CanCollide = true })
	box(sp, Vector3.new(6.6, 15.2, 0.4), Vector3.new(x, 9.2, z + 3.3), Palette.SpeakerDark)
	-- Two cones and a tweeter, facing the room.
	for _, spec in ipairs({ { 4.6, 5.4 }, { 3.4, 11 } }) do
		cyl(sp, spec[1], 0.5, CFrame.new(x, spec[2], z + 3.6) * CFrame.Angles(0, math.rad(90), 0), Palette.SpeakerCone)
		cyl(sp, spec[1] * 0.42, 0.7, CFrame.new(x, spec[2], z + 3.75) * CFrame.Angles(0, math.rad(90), 0), Palette.Chrome, Enum.Material.Metal)
	end
	cyl(sp, 1.6, 0.5, CFrame.new(x, 15.4, z + 3.6) * CFrame.Angles(0, math.rad(90), 0), Palette.SpeakerCone)
	box(sp, Vector3.new(7.8, 0.6, 6.8), Vector3.new(x, 17.4, z), Palette.TrimDark)
	return sp
end

local function buildPlant(root, x, z, scale)
	local plant = folder("Plant", root)
	scale = scale or 1
	cyl(plant, 4.4 * scale, 4 * scale, CFrame.new(x, 2 * scale, z) * CFrame.Angles(0, 0, math.rad(90)),
		Palette.Pot, Enum.Material.Slate)
	cyl(plant, 4.9 * scale, 0.7 * scale, CFrame.new(x, 3.9 * scale, z) * CFrame.Angles(0, 0, math.rad(90)),
		Palette.Pot:Lerp(Palette.Dark, 0.2), Enum.Material.Slate)
	cyl(plant, 0.6 * scale, 5 * scale, CFrame.new(x, 6 * scale, z) * CFrame.Angles(0, 0, math.rad(90)),
		Palette.PlantDark, Enum.Material.Grass)
	local rng = Random.new(math.floor(x * 31 + z * 7))
	for i = 1, 9 do
		local a = rng:NextNumber(0, math.pi * 2)
		local lean = rng:NextNumber(0.5, 1.2)
		local len = rng:NextNumber(4, 7) * scale
		local leaf = box(plant, Vector3.new(1.1 * scale, 0.35 * scale, len),
			Vector3.zero, i % 2 == 0 and Palette.Plant or Palette.PlantDark, Enum.Material.Grass)
		leaf.CFrame = CFrame.new(x, (7.5 + rng:NextNumber(0, 2.5)) * scale, z)
			* CFrame.Angles(0, a, 0) * CFrame.Angles(-lean, 0, 0) * CFrame.new(0, 0, -len / 2)
	end
	return plant
end

local function buildShelf(root)
	local shelf = folder("Shelf", root)
	local x, y, z = 33, 14, ROOM_BACK + 1.6
	box(shelf, Vector3.new(11, 0.7, 3.4), Vector3.new(x, y, z), Palette.Shelf, Enum.Material.Wood)
	for _, dx in ipairs({ -4, 4 }) do
		box(shelf, Vector3.new(0.6, 1.6, 2.6), Vector3.new(x + dx, y - 1.1, z), Palette.Shelf)
	end

	-- A cat, asleep on the shelf. Everyone needs a witness.
	local cat = folder("Cat", shelf)
	local cx, cy = x + 1, y + 1.5
	box(cat, Vector3.new(4.2, 1.9, 2.2), Vector3.new(cx, cy, z), Palette.Cat, Enum.Material.SmoothPlastic)
	ball(cat, 2.3, Vector3.new(cx - 2.4, cy + 0.5, z), Palette.Cat)
	for _, ex in ipairs({ -0.55, 0.55 }) do
		ball(cat, 0.34, Vector3.new(cx - 3.35, cy + 0.75, z + ex), Palette.Dark)
	end
	local nose = ball(cat, 0.3, Vector3.new(cx - 3.5, cy + 0.25, z), Palette.Pink)
	for _, side in ipairs({ -1, 1 }) do
		local ear = Instance.new("WedgePart")
		ear.Size = Vector3.new(0.5, 1.1, 1.1)
		ear.CFrame = CFrame.new(cx - 2.4, cy + 1.7, z + side * 0.7) * CFrame.Angles(0, math.rad(90), 0)
		ear.Color = Palette.Cat
		ear.Anchored = true
		ear.CanCollide = false
		ear.Parent = cat
	end
	cyl(cat, 0.6, 3.4, CFrame.new(cx + 3.2, cy - 0.3, z) * CFrame.Angles(0, math.rad(22), 0), Palette.Cat)
	return shelf
end

-- ── wall dressing ────────────────────────────────────────────────────────────

local function buildWallArt(root)
	local art = folder("WallArt", root)
	local z = ROOM_BACK + 0.6

	-- The house sign.
	sign(art, "GOOD\nVIBES\nONLY", Vector3.new(9, 9, 0.3),
		CFrame.new(-25, 14, z) * CFrame.Angles(0, 0, math.rad(-7)), Palette.Pink)

	-- A record on the wall.
	disc(art, 9.5, 0, Vector3.new(0, 0, 0), Palette.Dark, Enum.Material.SmoothPlastic).CFrame =
		CFrame.new(16, 16, z) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(90))
	disc(art, 3.4, 0, Vector3.new(0, 0, 0), Palette.Orange).CFrame =
		CFrame.new(16, 16, z + 0.2) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(90))
	disc(art, 0.8, 0, Vector3.new(0, 0, 0), Palette.Cream).CFrame =
		CFrame.new(16, 16, z + 0.3) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(90))

	-- A skateboard leaning in the corner.
	local deck = box(art, Vector3.new(3.2, 0.5, 13), Vector3.zero, Palette.Cyan)
	deck.CFrame = CFrame.new(-34, 6.5, -20) * CFrame.Angles(math.rad(74), math.rad(16), 0)
	for _, dz in ipairs({ -4, 4 }) do
		local truck = cyl(art, 1.3, 3.4, CFrame.new(0, 0, 0), Palette.Chrome, Enum.Material.Metal)
		truck.CFrame = deck.CFrame * CFrame.new(0, -0.9, dz)
	end

	-- The marquee over the back wall: our own lettering, not a traced logo.
	sign(art, "MIMIC PARTY", Vector3.new(26, 6, 0.3), CFrame.new(0, 22.5, z), Palette.Trim)
	sign(art, "imitá · puntuá · saboteá", Vector3.new(22, 2.2, 0.3), CFrame.new(0, 18.8, z),
		Palette.Pink, Enum.Font.GothamMedium)

	return art
end

-- A sagging run of party bulbs. The single most "cartoon party" object in the
-- room, and the only one that is also a light source.
local function buildStringLights(root)
	local lights = folder("StringLights", root)
	local colours = { Palette.Pink, Palette.Cyan, Palette.Lime, Palette.Trim, Palette.Violet, Palette.Orange }
	local span, segments = 64, 26
	local topY, sag = 25.5, 3.2

	local function curve(t)
		return Vector3.new(-span / 2 + span * t, topY - math.sin(t * math.pi) * sag, ROOM_BACK + 1.2)
	end

	for i = 0, segments - 1 do
		local a, b = curve(i / segments), curve((i + 1) / segments)
		local mid = (a + b) / 2
		local length = (b - a).Magnitude
		local wire = cyl(lights, 0.22, length + 0.1, CFrame.lookAt(mid, b) * CFrame.Angles(0, math.rad(90), 0),
			Palette.Dark)
		wire.CastShadow = false

		if i % 2 == 0 then
			local colour = colours[(i // 2) % #colours + 1]
			local bulb = ball(lights, 1.5, b - Vector3.new(0, 1.1, 0), colour, Enum.Material.Neon)
			cyl(lights, 0.5, 0.7, CFrame.new(b - Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Palette.Dark)
			local glow = Instance.new("PointLight")
			glow.Brightness = 0.85
			glow.Range = 16
			glow.Color = colour
			glow.Shadows = false
			glow.Parent = bulb
		end
	end
	return lights
end

-- ── the line ─────────────────────────────────────────────────────────────────

local function buildMarks(root, anchors)
	local marks = folder("Marks", root)

	for i = 1, Config.STAGE_MARKS do
		local x = MARK_X[i]
		local base = Vector3.new(x, 0, LINE_Z)

		-- A soft pad on the rug: where to stand, without a painted line.
		disc(marks, 6.4, 0.32, base, Palette.RugOuter:Lerp(Palette.Cream, 0.18), Enum.Material.Fabric)
		disc(marks, 5.2, 0.38, base, Palette.RugInner, Enum.Material.Fabric)

		local mark = Instance.new("Part")
		mark.Name = "Mark" .. i
		mark.Size = Vector3.new(3, 0.2, 3)
		mark.Position = base + Vector3.new(0, 0.3, 0)
		mark.Transparency = 1
		mark.Anchored = true
		mark.CanCollide = false
		mark.CanQuery = false
		mark.Parent = anchors

		local cf = Instance.new("CFrameValue")
		cf.Name = "MarkCFrame" .. i
		cf.Value = CFrame.lookAt(base + Vector3.new(0, 3, 0), base + Vector3.new(0, 3, 20))
		cf.Parent = anchors
	end

	-- One mic stand, centre, in front of the line.
	local sx, sz = 3.5, LINE_Z + 6.5
	cyl(marks, 3, 0.4, CFrame.new(sx, 0.35, sz) * CFrame.Angles(0, 0, math.rad(90)), Palette.Dark)
	for leg = 0, 2 do
		local a = math.rad(leg * 120)
		cyl(marks, 0.4, 2.2,
			CFrame.new(sx + math.cos(a) * 1, 0.5, sz + math.sin(a) * 1)
				* CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, math.rad(72)),
			Palette.Chrome, Enum.Material.Metal)
	end
	cyl(marks, 0.42, 6.6, CFrame.new(sx, 3.6, sz) * CFrame.Angles(0, 0, math.rad(90)), Palette.Chrome, Enum.Material.Metal)
	cyl(marks, 0.34, 2.2, CFrame.new(sx, 6.7, sz - 0.9) * CFrame.Angles(0, math.rad(90), 0), Palette.Chrome, Enum.Material.Metal)
	local capsule = cyl(marks, 1.05, 1.8, CFrame.new(sx, 6.45, sz - 2.1) * CFrame.Angles(math.rad(-24), math.rad(90), 0),
		Palette.Dark, Enum.Material.Metal)
	ball(marks, 1.15, capsule.Position + Vector3.new(0, -0.35, -0.6), Palette.Chrome, Enum.Material.DiamondPlate)

	return marks
end

-- ── spawns and cameras ───────────────────────────────────────────────────────

local function buildSpawns(root, anchors)
	local spawns = folder("Spawns", root)
	for i = 1, Config.STAGE_MARKS do
		local x = -8 + (i - 1) * 4
		local s = Instance.new("SpawnLocation")
		s.Name = "Spawn" .. i
		s.Size = Vector3.new(3.6, 0.4, 3.6)
		s.CFrame = CFrame.lookAt(Vector3.new(x, 1, 20), Vector3.new(x, 1, LINE_Z))
		s.Anchored = true
		s.Neutral = true
		s.Duration = 0
		s.Transparency = 1
		s.CanCollide = false
		s.Parent = spawns

		local cf = Instance.new("CFrameValue")
		cf.Name = "SpawnCFrame" .. i
		cf.Value = s.CFrame
		cf.Parent = anchors
	end
	return spawns
end

local function buildCameraAnchors(anchors)
	local function shot(name, from, look, fov)
		local cf = Instance.new("CFrameValue")
		cf.Name = name
		cf.Value = CFrame.lookAt(from, look)
		cf.Parent = anchors
		local f = Instance.new("NumberValue")
		f.Name = name .. "FOV"
		f.Value = fov
		f.Parent = anchors
	end

	-- The room, framed from the near side. This is the menu shot.
	shot("CamHouse", Vector3.new(0, 14, 40), Vector3.new(0, 8, -8), Config.CAMERA_FOV.HOUSE)
	-- Walking in: low and off-axis, so the entrance reads as an entrance.
	shot("CamProcession", Vector3.new(-16, 9, 30), Vector3.new(0, 5, -1), Config.CAMERA_FOV.HOUSE)
	-- Everyone on their pad at once.
	shot("CamWide", Vector3.new(0, 11, 33), Vector3.new(0, 6, -5), Config.CAMERA_FOV.WIDE)
	-- Pushed in for recording, so the waveforms own the frame.
	shot("CamBooth", Vector3.new(0, 8.5, 22), Vector3.new(0, 5.5, -2), Config.CAMERA_FOV.BOOTH)
	-- The wheel hangs in the middle of the room.
	shot("CamRoulette", Vector3.new(0, 10, 24), Vector3.new(0, 8, -2), Config.CAMERA_FOV.ROULETTE)
	-- The bow.
	shot("CamResults", Vector3.new(-7, 10, 26), Vector3.new(0, 5.5, -3), Config.CAMERA_FOV.CLOSE)
end

-- ── room light ───────────────────────────────────────────────────────────────

local function buildRoomLight(root)
	local rig = folder("RoomLight", root)

	-- A paper lantern over the line. Soft, warm, and the key light on faces.
	local function lantern(x, z, size, brightness)
		cyl(rig, 0.25, 6, CFrame.new(x, 26, z) * CFrame.Angles(0, 0, math.rad(90)), Palette.Dark)
		local shade = ball(rig, size, Vector3.new(x, 22.4, z), Palette.Cream, Enum.Material.Neon,
			{ Transparency = 0.25 })
		local lamp = Instance.new("PointLight")
		lamp.Brightness = brightness
		lamp.Range = 54
		lamp.Color = Palette.Practical
		lamp.Shadows = true
		lamp.Parent = shade
	end

	-- Over the line…
	for _, x in ipairs({ -14, 0, 14 }) do
		lantern(x, LINE_Z, 5.4, 1.5)
	end
	-- …and over the room, so the near half of the floor is not a dark band.
	for _, x in ipairs({ -18, 0, 18 }) do
		lantern(x, 14, 4.4, 1.2)
	end

	-- A low front fill so nobody performs in silhouette.
	local fillAnchor = box(rig, Vector3.new(1, 1, 1), Vector3.new(0, 12, 18), Palette.Dark,
		Enum.Material.SmoothPlastic, { Transparency = 1, CanQuery = false })
	local fill = Instance.new("SpotLight")
	fill.Angle = 110
	fill.Brightness = 1.1
	fill.Range = 56
	fill.Color = Palette.Wash
	fill.Face = Enum.NormalId.Back
	fill.Shadows = false
	fill.Parent = fillAnchor

	return rig
end

-- ── entry point ──────────────────────────────────────────────────────────────

function StageBuilder.build()
	local existing = Workspace:FindFirstChild("Venue")
	if existing then
		existing:Destroy()
	end

	local root = Instance.new("Model")
	root.Name = "Venue"
	local anchors = folder("StageAnchors", root)

	buildShell(root)
	buildRug(root)
	buildArmchair(root)
	buildSpeaker(root, -27)
	buildSpeaker(root, 27)
	buildPlant(root, -32, -26, 1.1)
	buildPlant(root, 33, -8, 0.85)
	buildPlant(root, 20, -27, 0.7)
	buildShelf(root)
	buildWallArt(root)
	buildStringLights(root)
	buildMarks(root, anchors)
	buildSpawns(root, anchors)
	buildCameraAnchors(anchors)
	buildRoomLight(root)

	root.Parent = Workspace

	-- Everything is anchored decor; keep it out of raycasts and physics work.
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and not d.CanCollide then
			d.CanQuery = false
			d.CanTouch = false
		end
	end

	return root
end

function StageBuilder.anchors()
	local venue = Workspace:WaitForChild("Venue", 30)
	return venue and venue:WaitForChild("StageAnchors", 10)
end

return StageBuilder

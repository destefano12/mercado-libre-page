--!nonstrict
-- StageBuilder.luau — builds the venue procedurally, at runtime.
--
-- Everything here is primitives, because the project ships without uploaded
-- assets. The trick to not looking like a pile of boxes is layering: nested
-- trims to read as mouldings, cylinders on every exposed edge to kill the hard
-- 90° corner, and controlled randomness on the curtain and the crowd so no two
-- panels line up. Swap any folder for a real model later; the anchors below are
-- the only contract the rest of the game depends on.
--
-- Geometry: the deck sits at y = 4, centred on x = 0. The audience looks toward
-- −Z; performers face +Z. Marks run left to right at x = −20 … +20.

local Workspace = game:GetService("Workspace")
local Palette = require(game.ReplicatedStorage.Shared.Palette)
local Config = require(game.ReplicatedStorage.Shared.Config)

local StageBuilder = {}

local DECK_Y = 4
local DECK_HALF_X = 31
local DECK_Z_FRONT = 8
local DECK_Z_BACK = -14
local CURTAIN_Z = -13.2
local ARCH_Z = 8.6

-- ── primitives ───────────────────────────────────────────────────────────────

local function box(parent, size, position, color, material, props)
	local p = Instance.new("Part")
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

-- NOTE: a Roblox cylinder already lies along its LOCAL X axis. So `cyl` with no
-- rotation gives a horizontal rod, and CFrame.Angles(0, 0, rad(90)) STANDS IT
-- UP. Getting this backwards is how you end up with a 62-stud pole through the
-- middle of the room — which is exactly what the first render of this file
-- showed.
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
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function ball(parent, diameter, position, color, material)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(diameter, diameter, diameter)
	p.Position = position
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.Parent = parent
	return p
end

local function wedge(parent, size, cframe, color, material)
	local p = Instance.new("WedgePart")
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.Parent = parent
	return p
end

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- A horizontal moulding: three stacked slabs of decreasing width. Cheap, and
-- it is the single biggest difference between "stage" and "grey block".
local function moulding(parent, width, centre, depth, color, colorDark)
	box(parent, Vector3.new(width, 0.5, depth + 0.5), centre, colorDark, Enum.Material.Wood)
	box(parent, Vector3.new(width - 0.6, 0.35, depth + 0.9), centre + Vector3.new(0, 0.42, 0), color, Enum.Material.Metal)
	box(parent, Vector3.new(width - 1.4, 0.28, depth + 0.3), centre + Vector3.new(0, 0.74, 0), colorDark, Enum.Material.Wood)
end

-- ── the room ─────────────────────────────────────────────────────────────────

local function buildShell(root)
	local shell = folder("Shell", root)

	-- House floor, raked slightly toward the stage so the crowd reads as tiered.
	for i = 0, 5 do
		local z = 13 + i * 6
		box(shell, Vector3.new(84, 1.2, 6.2), Vector3.new(0, 0.6 + i * 0.9, z),
			Palette.HouseFloor, Enum.Material.Fabric, { CanCollide = true })
	end
	-- Flat apron between the front row and the stage.
	box(shell, Vector3.new(84, 1.2, 6), Vector3.new(0, 0.6, 10),
		Palette.HouseFloor, Enum.Material.Fabric, { CanCollide = true })

	-- Walls.
	box(shell, Vector3.new(2, 40, 84), Vector3.new(-42, 20, 8), Palette.HouseWall, Enum.Material.Concrete, { CanCollide = true })
	box(shell, Vector3.new(2, 40, 84), Vector3.new(42, 20, 8), Palette.HouseWall, Enum.Material.Concrete, { CanCollide = true })
	box(shell, Vector3.new(86, 40, 2), Vector3.new(0, 20, 50), Palette.HouseWall, Enum.Material.Concrete, { CanCollide = true })
	box(shell, Vector3.new(86, 2, 86), Vector3.new(0, 39, 8), Palette.Scrim, Enum.Material.Concrete)

	-- Vertical wall ribs: breaks up 80 studs of flat concrete.
	for i = 0, 7 do
		local z = 16 + i * 4.5
		for _, x in ipairs({ -40.6, 40.6 }) do
			box(shell, Vector3.new(0.8, 26, 1.1), Vector3.new(x, 14, z), Palette.Scrim, Enum.Material.Wood)
		end
	end

	-- Wall sconces: warm, dim, and the only light source in the house.
	for i = 0, 3 do
		local z = 18 + i * 8
		for _, x in ipairs({ -40, 40 }) do
			local housing = box(shell, Vector3.new(0.6, 2.2, 1.4), Vector3.new(x, 13, z),
				Palette.TrimDark, Enum.Material.Metal)
			cyl(shell, 1.3, 0.5, CFrame.new(x - (x > 0 and 0.5 or -0.5), 14.3, z),
				Palette.Practical, Enum.Material.Neon)
			local light = Instance.new("PointLight")
			light.Brightness = 0.55
			light.Range = 17
			light.Color = Palette.Practical
			light.Shadows = false
			light.Parent = housing
		end
	end

	-- House pendants. Dim on purpose: the room should read, not compete with the
	-- stage. Without them the audience is an unreadable black mass in the one
	-- shot the menu sits on top of.
	for i = 0, 3 do
		local z = 17 + i * 9
		local stem = cyl(shell, 0.3, 5, CFrame.new(0, 31, z) * CFrame.Angles(0, 0, math.rad(90)),
			Palette.Truss, Enum.Material.Metal)
		local shade = box(shell, Vector3.new(3.2, 0.7, 3.2), Vector3.new(0, 28.4, z),
			Palette.TrimDark, Enum.Material.Metal)
		cyl(shell, 2.4, 0.3, CFrame.new(0, 28, z) * CFrame.Angles(0, 0, math.rad(90)),
			Palette.Practical, Enum.Material.Neon, { Transparency = 0.3 })

		local pendant = Instance.new("PointLight")
		pendant.Brightness = 0.7
		pendant.Range = 40
		pendant.Color = Palette.Practical
		pendant.Shadows = false
		pendant.Parent = shade
	end

	return shell
end

-- ── the deck ─────────────────────────────────────────────────────────────────

local function buildDeck(root)
	local deck = folder("Deck", root)
	local depth = DECK_Z_FRONT - DECK_Z_BACK

	-- Structural slab (the collidable one).
	box(deck, Vector3.new(DECK_HALF_X * 2, 4, depth),
		Vector3.new(0, DECK_Y - 2, (DECK_Z_FRONT + DECK_Z_BACK) / 2),
		Palette.Fascia, Enum.Material.WoodPlanks, { CanCollide = true })

	-- Individual planks on top, with per-plank tone variation.
	local plankW = 1.55
	local count = math.floor((DECK_HALF_X * 2) / plankW)
	for i = 0, count - 1 do
		local x = -DECK_HALF_X + plankW * (i + 0.5)
		local shade = (i % 3 == 0) and Palette.DeckDark or Palette.Deck
		local jitter = (i % 7) * 0.004
		box(deck, Vector3.new(plankW - 0.08, 0.35, depth - 0.3),
			Vector3.new(x, DECK_Y - 0.17, (DECK_Z_FRONT + DECK_Z_BACK) / 2),
			shade:Lerp(Color3.new(0, 0, 0), jitter), Enum.Material.WoodPlanks,
			{ CanCollide = true, Reflectance = 0.02 })
	end

	-- Bullnose along the downstage edge: no hard corner facing the audience.
	cyl(deck, 0.9, DECK_HALF_X * 2, CFrame.new(0, DECK_Y - 0.25, DECK_Z_FRONT),
		Palette.DeckDark, Enum.Material.Wood)

	-- Fascia with recessed panels.
	local fasciaZ = DECK_Z_FRONT + 0.18
	box(deck, Vector3.new(DECK_HALF_X * 2, 3.6, 0.4), Vector3.new(0, DECK_Y - 2.1, fasciaZ),
		Palette.Fascia, Enum.Material.Wood)
	for i = 0, 9 do
		local x = -27.9 + i * 6.2
		box(deck, Vector3.new(4.9, 2.2, 0.22), Vector3.new(x, DECK_Y - 2.1, fasciaZ + 0.22),
			Palette.Scrim, Enum.Material.Wood)
		box(deck, Vector3.new(5.5, 2.7, 0.14), Vector3.new(x, DECK_Y - 2.1, fasciaZ + 0.16),
			Palette.TrimDark, Enum.Material.Metal)
	end
	moulding(deck, DECK_HALF_X * 2, Vector3.new(0, DECK_Y - 3.8, fasciaZ), 0.5, Palette.Trim, Palette.TrimDark)

	-- Two steps up from the house, stage left and right.
	for _, sx in ipairs({ -1, 1 }) do
		for s = 0, 2 do
			box(deck, Vector3.new(7, 1.35, 2.2),
				Vector3.new(sx * 23, 1.1 + s * 1.3, DECK_Z_FRONT + 3.4 - s * 2.1),
				Palette.DeckDark, Enum.Material.Wood, { CanCollide = true })
		end
	end

	return deck
end

-- ── proscenium ───────────────────────────────────────────────────────────────

local function buildProscenium(root)
	local arch = folder("Proscenium", root)

	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * 33
		-- Nested pylon: three shells, each narrower, reads as a fluted column.
		box(arch, Vector3.new(6.4, 30, 4.6), Vector3.new(x, 16, ARCH_Z), Palette.Scrim, Enum.Material.Concrete)
		box(arch, Vector3.new(5.2, 29, 3.6), Vector3.new(x, 16.2, ARCH_Z + 0.4), Palette.HouseWall, Enum.Material.Wood)
		box(arch, Vector3.new(3.6, 27.5, 2.6), Vector3.new(x, 16.4, ARCH_Z + 0.8), Palette.Fascia, Enum.Material.Wood)
		-- Flutes.
		for i = -1, 1 do
			cyl(arch, 0.7, 26, CFrame.new(x + i * 1.1, 16.4, ARCH_Z + 2.0) * CFrame.Angles(0, 0, math.rad(90)),
				Palette.Scrim, Enum.Material.Wood)
		end
		-- Base and capital.
		moulding(arch, 7.4, Vector3.new(x, 3.2, ARCH_Z), 5.4, Palette.Trim, Palette.TrimDark)
		moulding(arch, 7.4, Vector3.new(x, 29.4, ARCH_Z), 5.4, Palette.Trim, Palette.TrimDark)
		cyl(arch, 1.1, 7.4, CFrame.new(x, 31.1, ARCH_Z),
			Palette.Trim, Enum.Material.Metal)
	end

	-- Header beam with coffers.
	box(arch, Vector3.new(73, 4.4, 4.6), Vector3.new(0, 31.5, ARCH_Z), Palette.Scrim, Enum.Material.Concrete)
	for i = 0, 11 do
		local x = -30 + i * 5.45
		box(arch, Vector3.new(4.1, 2.6, 0.5), Vector3.new(x, 31.5, ARCH_Z + 2.4), Palette.HouseWall, Enum.Material.Wood)
		box(arch, Vector3.new(4.7, 3.1, 0.3), Vector3.new(x, 31.5, ARCH_Z + 2.2), Palette.TrimDark, Enum.Material.Metal)
	end
	moulding(arch, 74, Vector3.new(0, 29.2, ARCH_Z), 5, Palette.Trim, Palette.TrimDark)
	moulding(arch, 74, Vector3.new(0, 33.6, ARCH_Z), 5, Palette.Trim, Palette.TrimDark)

	-- Scalloped valance hanging just upstage of the arch.
	local valance = folder("Valance", arch)
	for i = 0, 23 do
		local x = -29.5 + i * 2.57
		local drop = 3.1 + math.abs(math.sin(i * 0.78)) * 1.5
		box(valance, Vector3.new(2.7, drop, 1.0), Vector3.new(x, 29 - drop / 2, ARCH_Z - 2.6),
			Palette.Valance, Enum.Material.Fabric)
		wedge(valance, Vector3.new(1.0, 1.5, 2.7),
			CFrame.new(x, 29 - drop - 0.75, ARCH_Z - 2.6) * CFrame.Angles(0, math.rad(90), math.rad(180)),
			Palette.CurtainFold, Enum.Material.Fabric)
	end

	return arch
end

-- ── curtain ──────────────────────────────────────────────────────────────────

local function buildCurtain(root)
	local curtain = folder("Curtain", root)
	-- Parted, hanging upstage. Folds come from alternating depth and a small
	-- per-panel yaw; a flat plane here would kill the whole room.
	for _, side in ipairs({ -1, 1 }) do
		local panels = 13
		for i = 0, panels - 1 do
			local inner = 2.4 + i * 2.3
			local x = side * inner
			local fold = (i % 2 == 0)
			local depth = fold and 1.5 or 0.9
			local color = fold and Palette.Curtain or Palette.CurtainFold
			local yaw = math.rad(side * (fold and -7 or 6))
			local height = 25 - math.abs(math.sin(i * 0.5)) * 0.8
			local p = box(curtain, Vector3.new(2.5, height, depth),
				Vector3.new(x, DECK_Y + height / 2 - 0.2, CURTAIN_Z),
				color, Enum.Material.Fabric)
			p.CFrame = CFrame.new(p.Position) * CFrame.Angles(0, yaw, 0)
			-- Weighted hem.
			cyl(curtain, 1.0, 2.5, CFrame.new(x, DECK_Y - 0.1, CURTAIN_Z) * CFrame.Angles(0, yaw, 0),
				Palette.CurtainFold, Enum.Material.Fabric)
		end
	end
	-- Track and pelmet.
	box(curtain, Vector3.new(70, 0.8, 2.2), Vector3.new(0, DECK_Y + 25.2, CURTAIN_Z), Palette.Truss, Enum.Material.Metal)
	return curtain
end

-- ── backdrop ─────────────────────────────────────────────────────────────────

local function buildBackdrop(root)
	local back = folder("Backdrop", root)
	-- Slatted timber wall with a dark scrim behind it: depth for free.
	box(back, Vector3.new(70, 30, 1.2), Vector3.new(0, DECK_Y + 14, DECK_Z_BACK - 1.4),
		Palette.Scrim, Enum.Material.Concrete, { CanCollide = true })
	for i = 0, 45 do
		local x = -34 + i * 1.5
		local shade = (i % 4 == 0) and Palette.DeckDark or Palette.Fascia
		box(back, Vector3.new(1.1, 27, 0.45), Vector3.new(x, DECK_Y + 13.5, DECK_Z_BACK - 0.7),
			shade, Enum.Material.WoodPlanks)
	end
	moulding(back, 70, Vector3.new(0, DECK_Y + 0.6, DECK_Z_BACK - 0.7), 1.2, Palette.Trim, Palette.TrimDark)
	return back
end

-- ── truss and stage light ────────────────────────────────────────────────────

local function buildTruss(root)
	local truss = folder("Truss", root)
	local y = DECK_Y + 24

	for _, z in ipairs({ -2, 4 }) do
		-- Two chords plus cross-bracing: a real truss silhouette, not a bar.
		cyl(truss, 0.7, 66, CFrame.new(0, y + 0.9, z), Palette.Truss, Enum.Material.Metal)
		cyl(truss, 0.7, 66, CFrame.new(0, y - 0.9, z), Palette.Truss, Enum.Material.Metal)
		for i = 0, 21 do
			local x = -31 + i * 2.95
			local lean = (i % 2 == 0) and 32 or -32
			cyl(truss, 0.42, 2.9, CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(lean)), Palette.Truss, Enum.Material.Metal)
		end
	end

	-- Six soft practicals. Low brightness, wide angle, warm: a wash, not a beam.
	for i = 0, 5 do
		local x = -25 + i * 10
		local body = cyl(truss, 2.0, 2.6,
			CFrame.new(x, y - 2.4, 1) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(26), 0, 0),
			Palette.Truss, Enum.Material.Metal)
		cyl(truss, 1.5, 0.4, CFrame.new(x, y - 3.5, 1.9) * CFrame.Angles(0, 0, math.rad(90)),
			Palette.Wash, Enum.Material.Neon, { Transparency = 0.25 })
		-- Yoke.
		box(truss, Vector3.new(0.3, 2.4, 0.3), Vector3.new(x - 1.2, y - 1.4, 1), Palette.Truss, Enum.Material.Metal)
		box(truss, Vector3.new(0.3, 2.4, 0.3), Vector3.new(x + 1.2, y - 1.4, 1), Palette.Truss, Enum.Material.Metal)

		local spot = Instance.new("SpotLight")
		spot.Angle = 86
		spot.Brightness = 1.35
		spot.Range = 46
		spot.Color = Palette.Wash
		spot.Face = Enum.NormalId.Bottom
		spot.Shadows = true
		spot.Parent = body
	end

	-- ── front of house ──
	-- Four soft washes on the proscenium header, angled down and upstage at the
	-- marks. Without these the six overheads light the deck and leave every
	-- face in shadow — which is exactly what the first render showed. Low
	-- brightness and a wide cone: this is fill, not a follow spot.
	for i = 0, 3 do
		local x = -21 + i * 14
		-- Tilted down and upstage, then lit through its Back face (−Z), so the
		-- cone actually lands on the performers. Face = Front would throw it
		-- into the audience's eyes, which is what the first render did.
		local housing = box(truss, Vector3.new(1.8, 1.4, 2.2), Vector3.new(x, 27.5, ARCH_Z - 1.2),
			Palette.Truss, Enum.Material.Metal)
		housing.CFrame = CFrame.new(housing.Position) * CFrame.Angles(math.rad(-52), 0, 0)
		cyl(truss, 1.2, 0.4, CFrame.new(x, 26.6, ARCH_Z - 2.0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(38), 0, 0),
			Palette.Wash, Enum.Material.Neon, { Transparency = 0.35 })

		local wash = Instance.new("SpotLight")
		wash.Angle = 96
		wash.Brightness = 1.3
		wash.Range = 60
		wash.Color = Palette.Practical
		wash.Face = Enum.NormalId.Back
		wash.Shadows = false   -- fill light does not cast; it fills
		wash.Parent = housing
	end

	return truss
end

-- ── performance marks ────────────────────────────────────────────────────────

local function buildMarks(root, anchors)
	local marks = folder("Marks", root)
	local xs = { -20, -10, 0, 10, 20 }

	for i = 1, Config.STAGE_MARKS do
		local x = xs[i]
		local base = Vector3.new(x, DECK_Y, 0)

		-- Brass inlay ring set into the deck.
		cyl(marks, 5.4, 0.12, CFrame.new(x, DECK_Y + 0.04, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Palette.TrimDark, Enum.Material.Metal)
		cyl(marks, 4.6, 0.16, CFrame.new(x, DECK_Y + 0.06, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Palette.Trim, Enum.Material.Metal, { Reflectance = 0.08 })
		cyl(marks, 4.0, 0.2, CFrame.new(x, DECK_Y + 0.07, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Palette.DeckDark, Enum.Material.Wood)

		-- Mic stand: tripod foot, column, boom, capsule.
		local standZ = -2.4
		cyl(marks, 2.6, 0.3, CFrame.new(x, DECK_Y + 0.2, standZ) * CFrame.Angles(0, 0, math.rad(90)),
			Palette.Truss, Enum.Material.Metal)
		for leg = 0, 2 do
			local a = math.rad(leg * 120)
			cyl(marks, 0.3, 1.8,
				CFrame.new(x + math.cos(a) * 0.8, DECK_Y + 0.35, standZ + math.sin(a) * 0.8)
					* CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, math.rad(74)),
				Palette.Truss, Enum.Material.Metal)
		end
		cyl(marks, 0.36, 6.2, CFrame.new(x, DECK_Y + 3.3, standZ) * CFrame.Angles(0, 0, math.rad(90)),
			Palette.Truss, Enum.Material.Metal)
		cyl(marks, 0.3, 1.9, CFrame.new(x, DECK_Y + 6.2, standZ + 0.95) * CFrame.Angles(0, math.rad(90), 0),
			Palette.Truss, Enum.Material.Metal)
		local capsule = cyl(marks, 0.9, 1.5,
			CFrame.new(x, DECK_Y + 5.95, standZ + 1.9) * CFrame.Angles(math.rad(-28), math.rad(90), 0),
			Palette.Fascia, Enum.Material.Metal)
		ball(marks, 0.95, capsule.Position + Vector3.new(0, -0.3, 0.55), Palette.Truss, Enum.Material.DiamondPlate)

		-- Anchors the rest of the game reads.
		local mark = Instance.new("Part")
		mark.Name = "Mark" .. i
		mark.Size = Vector3.new(3, 0.2, 3)
		mark.Position = base + Vector3.new(0, 0.2, 0)
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

	return marks
end

-- ── crowd ────────────────────────────────────────────────────────────────────

local function buildCrowd(root)
	local crowd = folder("Crowd", root)
	local rng = Random.new(20260827)
	for row = 0, 5 do
		local z = 14 + row * 6
		local y = 1.2 + row * 0.9
		for seat = 0, 15 do
			local x = -36 + seat * 4.8 + rng:NextNumber(-0.7, 0.7)
			-- Leave the centre aisle actually empty. The spawns sit at x = −8…8
			-- and the procession walks straight up the middle, so seating across
			-- the full width meant five people walking through the chairs.
			local inAisle = math.abs(x) < 7.5
			if not inAisle and rng:NextNumber() > 0.12 then
				local h = rng:NextNumber(3.3, 4.1)
				local shade = Palette.Crowd:Lerp(Palette.HouseWall, rng:NextNumber(0, 0.45))
				-- Torso + head silhouette, slightly turned. Dark on purpose:
				-- the crowd should register peripherally and never pull focus.
				local torso = box(crowd, Vector3.new(2.3, h, 1.5), Vector3.new(x, y + h / 2, z), shade, Enum.Material.Fabric)
				torso.CFrame = CFrame.new(torso.Position) * CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), 0)
				ball(crowd, 1.5, Vector3.new(x, y + h + 0.6, z), shade, Enum.Material.Fabric)
				-- Seat back.
				box(crowd, Vector3.new(3.4, 2.1, 0.6), Vector3.new(x, y + 1.1, z + 1.8),
					Palette.Curtain:Lerp(Color3.new(0, 0, 0), 0.45), Enum.Material.Fabric)
			end
		end
	end
	return crowd
end

-- ── spawns ───────────────────────────────────────────────────────────────────

local function buildSpawns(root, anchors)
	local spawns = folder("Spawns", root)
	-- Players arrive in the house, centre aisle, facing the stage. The walk to
	-- the marks is the opening shot, so the spawn has to be behind the camera's
	-- subject, not on the deck.
	for i = 1, Config.STAGE_MARKS do
		local x = -8 + (i - 1) * 4
		local s = Instance.new("SpawnLocation")
		s.Name = "Spawn" .. i
		s.Size = Vector3.new(3.6, 0.4, 3.6)
		s.CFrame = CFrame.lookAt(Vector3.new(x, 1.5, 34), Vector3.new(x, 1.5, 0))
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

-- ── camera anchors ───────────────────────────────────────────────────────────

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

	-- House: the menu shot. Stage framed from the back of the room.
	shot("CamHouse", Vector3.new(0, 16, 44), Vector3.new(0, 9, -2), Config.CAMERA_FOV.HOUSE)
	-- Procession: down the aisle and over the crowd's heads. It used to sit at
	-- (-14, 7.5, 27) — which is INSIDE seating row 3 (rows run z = 14…44, heads
	-- reach y ≈ 7), so the opening shot of every party was the back of an
	-- audience member's skull. Rendering the venue is how that was caught.
	shot("CamProcession", Vector3.new(-16, 12.5, 35), Vector3.new(0, 6, 4), Config.CAMERA_FOV.HOUSE)
	-- Wide: the shot that shows every performer on their mark at once.
	shot("CamWide", Vector3.new(0, 13.5, 29), Vector3.new(0, 7.5, 0), Config.CAMERA_FOV.WIDE)
	-- Booth: pushed in for recording, so the waveform UI owns the frame.
	shot("CamBooth", Vector3.new(0, 10.5, 20), Vector3.new(0, 7, 0), Config.CAMERA_FOV.BOOTH)
	-- Roulette: slight off-axis, looking up at the wheel.
	shot("CamRoulette", Vector3.new(9, 11, 23), Vector3.new(0, 9, 2), Config.CAMERA_FOV.ROULETTE)
	-- Results: the curtain call.
	shot("CamResults", Vector3.new(-7, 11, 24), Vector3.new(0, 7.5, -1), Config.CAMERA_FOV.CLOSE)
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
	buildDeck(root)
	buildBackdrop(root)
	buildCurtain(root)
	buildProscenium(root)
	buildTruss(root)
	buildMarks(root, anchors)
	buildCrowd(root)
	buildSpawns(root, anchors)
	buildCameraAnchors(anchors)

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

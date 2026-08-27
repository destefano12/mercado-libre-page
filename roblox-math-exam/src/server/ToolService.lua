--!strict
--[[
	ToolService
	------------------------------------------------------------------
	El inventario: un lapiz y un celular en la mochila de Roblox.

	Son Tools de verdad, no un boton que prende un flag. Eso importa
	porque el "a veces sale y a veces no" del celular venia justamente
	de manejar el estado a mano: ahora equipar y guardar es lo que
	Roblox ya sabe hacer, y el servidor solo escucha.

		Lapiz   -> equipado y con click, hacés que escribís. Mientras
		           escribís parecés aplicado: la sospecha baja mas
		           rapido y el profe te pasa de largo antes.
		Celular -> equipado, sale de abajo del banco (y el profe te lo
		           puede ver). Con click, sacás la foto.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local PhoneService = require(script.Parent:WaitForChild("PhoneService"))
local SuspicionService = require(script.Parent:WaitForChild("SuspicionService"))

local ToolService = {}

local writingUntil: { [Player]: number } = {}

-- ─────────────────────────────────────────────────────────────
-- Lapiz
-- ─────────────────────────────────────────────────────────────

local function attachPencil(character: Model): BasePart?
	local hand = (character:FindFirstChild("RightHand") :: BasePart?)
		or (character:FindFirstChild("Right Arm") :: BasePart?)
		or (character:FindFirstChild("RightLowerArm") :: BasePart?)
	if not hand then
		return nil
	end

	local existing = character:FindFirstChild("LapizEnMano")
	if existing then
		existing:Destroy()
	end

	local pencil = Util.part({
		Name = "LapizEnMano",
		Size = Vector3.new(0.12, 0.12, 1.1),
		CFrame = hand.CFrame * CFrame.new(0, -0.3, -0.2) * CFrame.Angles(math.rad(-40), 0, 0),
		Color = Color3.fromRGB(226, 178, 60),
		Material = Enum.Material.SmoothPlastic,
		Anchored = false,
		CanCollide = false,
		CastShadow = false,
		Parent = character,
	})
	pencil.Massless = true
	Util.weld(hand, pencil)

	local tip = Util.part({
		Name = "Punta",
		Size = Vector3.new(0.1, 0.1, 0.16),
		CFrame = pencil.CFrame * CFrame.new(0, 0, -0.63),
		Color = Color3.fromRGB(42, 40, 44),
		Material = Enum.Material.SmoothPlastic,
		Anchored = false,
		CanCollide = false,
		CastShadow = false,
		Parent = pencil,
	})
	tip.Massless = true
	Util.weld(pencil, tip)

	return pencil
end

--- Mientras "escribís" pasás por alumno aplicado.
function ToolService.isWriting(player: Player): boolean
	return (writingUntil[player] or 0) > os.clock()
end

-- ─────────────────────────────────────────────────────────────
-- Alta de herramientas
-- ─────────────────────────────────────────────────────────────

local function buildTool(name: string): Tool
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.RequiresHandle = false      -- el modelo lo ponemos nosotros
	tool.CanBeDropped = false
	tool.ManualActivationOnly = false
	return tool
end

function ToolService.give(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	for _, name in { "Lapiz", "Celular" } do
		local existing = backpack:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
		local held = player.Character and player.Character:FindFirstChild(name)
		if held then
			held:Destroy()
		end
	end

	-- ── Lapiz ─────────────────────────────────────────────
	local pencil = buildTool("Lapiz")
	pencil.Parent = backpack

	pencil.Equipped:Connect(function()
		if player.Character then
			attachPencil(player.Character)
		end
	end)

	pencil.Unequipped:Connect(function()
		local held = player.Character and player.Character:FindFirstChild("LapizEnMano")
		if held then
			held:Destroy()
		end
	end)

	pencil.Activated:Connect(function()
		writingUntil[player] = os.clock() + Config.Exam.WriteDuration
		Util.playSound(Config.Sounds.Write, player.Character or workspace, 0.25)
	end)

	-- ── Celular ───────────────────────────────────────────
	local phone = buildTool("Celular")
	phone.Parent = backpack

	phone.Equipped:Connect(function()
		PhoneService.setOut(player, true)
	end)

	phone.Unequipped:Connect(function()
		PhoneService.setOut(player, false)
	end)

	-- El click para sacar la foto lo escucha el cliente en su propia
	-- Tool: es el unico que sabe que ejercicio estas mirando.
end

--- Guarda el celular de verdad: lo desequipa, no solo baja un flag.
function ToolService.stashPhone(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:UnequipTools()
	end
	PhoneService.setOut(player, false)
end

Players.PlayerRemoving:Connect(function(player)
	writingUntil[player] = nil
end)

return ToolService

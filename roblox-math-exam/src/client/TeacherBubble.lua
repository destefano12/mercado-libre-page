--!strict
--[[
	TeacherBubble
	------------------------------------------------------------------
	El globo de dialogo del profesor. Lo dibuja el cliente y no el
	servidor: asi cada jugador lo lee en su idioma aunque esten todos
	en la misma partida.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local Theme = require(Shared:WaitForChild("Theme"))
local Util = require(Shared:WaitForChild("Util"))

local TeacherBubble = {}

local billboard: BillboardGui? = nil
local label: TextLabel? = nil
local token = 0

local function teacherHead(): BasePart?
	local teacher = workspace:FindFirstChild("Profesor")
	if not teacher then
		return nil
	end
	return (teacher:FindFirstChild("Head") :: BasePart?)
		or (teacher:FindFirstChild("HumanoidRootPart") :: BasePart?)
end

local function ensure(): boolean
	if billboard and billboard.Parent then
		return true
	end
	local head = teacherHead()
	if not head then
		return false
	end

	local gui = Util.billboard(head, UDim2.fromScale(9, 2.2), Vector3.new(0, 3, 0))
	gui.Name = "Dialogo"
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Theme.Menu.Panel
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Parent = gui
	Util.roundify(frame, 12, Theme.Menu.Line, 1)

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(0.9, 0.72)
	text.Position = UDim2.fromScale(0.05, 0.14)
	text.BackgroundTransparency = 1
	text.Font = Theme.Font
	text.TextColor3 = Theme.Menu.Text
	text.TextScaled = true
	text.Text = ""
	text.Parent = frame

	billboard = gui
	label = text
	return true
end

--- Muestra una frase del profe, traducida, por unos segundos.
function TeacherBubble.say(key: string, duration: number?)
	if not ensure() or not billboard or not label then
		return
	end
	label.Text = Strings.get(key)
	billboard.Enabled = true
	billboard.Adornee = teacherHead()

	token += 1
	local mine = token
	task.delay(duration or 3.2, function()
		if token == mine and billboard then
			billboard.Enabled = false
		end
	end)
end

function TeacherBubble.hide()
	token += 1
	if billboard then
		billboard.Enabled = false
	end
end

return TeacherBubble

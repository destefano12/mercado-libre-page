--!strict
--[[
	PaperUI
	------------------------------------------------------------------
	La hoja de la prueba. No es una pantalla plana pegada a la camara:
	es una SurfaceGui montada sobre la hoja fisica que esta apoyada en
	el banco, con el Adornee puesto desde el PlayerGui (que es lo que
	hace que los botones sean clickeables en el mundo 3D).

	Se ve un ejercicio por vez, con sus cuatro opciones y una tira de
	pestañas abajo para moverse entre los 8 ejercicios.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Util = require(Shared:WaitForChild("Util"))

local player = Players.LocalPlayer

local PaperUI = {}
PaperUI.current = 1
PaperUI.snapshot = nil :: any
PaperUI.onAnswer = nil :: ((number, number) -> ())?
PaperUI.onSelect = nil :: ((number) -> ())?

local LETTERS = { "A", "B", "C", "D" }

local gui: SurfaceGui? = nil
local refs: { [string]: any } = {}

local function el(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

-- ─────────────────────────────────────────────────────────────
-- Construccion
-- ─────────────────────────────────────────────────────────────

function PaperUI.mount(paperPart: BasePart)
	if gui then
		gui:Destroy()
	end

	local playerGui = player:WaitForChild("PlayerGui")

	gui = el("SurfaceGui", {
		Name = "HojaDePrueba",
		Adornee = paperPart,
		Face = Enum.NormalId.Top,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 340,
		LightInfluence = 0.25,
		MaxDistance = 40,
		AlwaysOnTop = false,
		Active = true,  -- sin esto los botones no se pueden clickear en 3D
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})

	local sheet = el("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Paper.Background,
		BorderSizePixel = 0,
	}, gui)

	-- ── Encabezado ────────────────────────────────────────
	local header = el("Frame", {
		Size = UDim2.new(1, 0, 0, 92),
		BackgroundTransparency = 1,
	}, sheet)

	el("TextLabel", {
		Size = UDim2.new(0.62, 0, 0, 34),
		Position = UDim2.fromOffset(28, 16),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		Text = "EVALUACION DE MATEMATICA",
		TextColor3 = Theme.Paper.Ink,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, header)

	refs.student = el("TextLabel", {
		Size = UDim2.new(0.62, 0, 0, 24),
		Position = UDim2.fromOffset(28, 52),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = string.format("Alumno: %s   ·   Curso: 3° B   ·   Tema: unico", player.DisplayName),
		TextColor3 = Theme.Paper.InkSoft,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, header)

	local gradeBox = el("Frame", {
		Size = UDim2.fromOffset(120, 62),
		Position = UDim2.new(1, -148, 0, 16),
		BackgroundColor3 = Theme.Paper.Background,
		BorderSizePixel = 0,
	}, header)
	Util.roundify(gradeBox, 8, Theme.Paper.Line, 2)

	el("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 6),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = "NOTA",
		TextColor3 = Theme.Paper.InkSoft,
		TextSize = 14,
	}, gradeBox)

	refs.grade = el("TextLabel", {
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 22),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		Text = "-",
		TextColor3 = Theme.Paper.Accent,
		TextSize = 30,
	}, gradeBox)

	el("Frame", {
		Size = UDim2.new(1, -56, 0, 2),
		Position = UDim2.fromOffset(28, 88),
		BackgroundColor3 = Theme.Paper.Line,
		BorderSizePixel = 0,
	}, header)

	-- ── Cuerpo del ejercicio ──────────────────────────────
	local body = el("Frame", {
		Size = UDim2.new(1, -56, 1, -212),
		Position = UDim2.fromOffset(28, 104),
		BackgroundTransparency = 1,
	}, sheet)

	refs.topic = el("TextLabel", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = "",
		TextColor3 = Theme.Paper.Accent,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, body)

	refs.prompt = el("TextLabel", {
		Size = UDim2.new(1, 0, 0, 84),
		Position = UDim2.fromOffset(0, 26),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		Text = "",
		TextColor3 = Theme.Paper.Ink,
		TextSize = 34,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, body)

	local options = el("Frame", {
		Size = UDim2.new(1, 0, 1, -118),
		Position = UDim2.fromOffset(0, 118),
		BackgroundTransparency = 1,
	}, body)

	el("UIGridLayout", {
		CellSize = UDim2.new(0.5, -10, 0.5, -10),
		CellPadding = UDim2.fromOffset(20, 16),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, options)

	refs.options = {}
	for index = 1, 4 do
		local button = el("TextButton", {
			Name = "Opcion" .. index,
			LayoutOrder = index,
			BackgroundColor3 = Theme.Paper.Background,
			AutoButtonColor = false,
			Font = Theme.Font,
			Text = "",
			TextColor3 = Theme.Paper.Ink,
			TextSize = 26,
			TextXAlignment = Enum.TextXAlignment.Left,
			BorderSizePixel = 0,
		}, options)
		Util.roundify(button, 10, Theme.Paper.Line, 2)

		el("UIPadding", { PaddingLeft = UDim.new(0, 58), PaddingRight = UDim.new(0, 12) }, button)

		local bullet = el("Frame", {
			Name = "Bullet",
			Size = UDim2.fromOffset(34, 34),
			Position = UDim2.new(0, -48, 0.5, -17),
			BackgroundColor3 = Theme.Paper.Background,
			BorderSizePixel = 0,
		}, button)
		Util.roundify(bullet, 17, Theme.Paper.InkSoft, 2)

		el("TextLabel", {
			Name = "Letra",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Theme.FontBold,
			Text = LETTERS[index],
			TextColor3 = Theme.Paper.InkSoft,
			TextSize = 20,
		}, bullet)

		button.MouseButton1Click:Connect(function()
			if PaperUI.onAnswer then
				PaperUI.onAnswer(PaperUI.current, index)
			end
		end)

		refs.options[index] = button
	end

	-- ── Pestañas de ejercicios ────────────────────────────
	local tabs = el("Frame", {
		Size = UDim2.new(1, -56, 0, 64),
		Position = UDim2.new(0, 28, 1, -84),
		BackgroundTransparency = 1,
	}, sheet)

	el("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, tabs)

	refs.tabs = {}
	refs.tabsFrame = tabs

	el("Frame", {
		Size = UDim2.new(1, -56, 0, 2),
		Position = UDim2.new(0, 28, 1, -96),
		BackgroundColor3 = Theme.Paper.Line,
		BorderSizePixel = 0,
	}, sheet)

	refs.footer = el("TextLabel", {
		Size = UDim2.new(1, -56, 0, 20),
		Position = UDim2.new(0, 28, 1, -22),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = "Tocá una opcion para responder. El celular esta abajo del banco.",
		TextColor3 = Theme.Paper.InkSoft,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, sheet)

	return gui
end

-- ─────────────────────────────────────────────────────────────
-- Render
-- ─────────────────────────────────────────────────────────────

local function buildTabs(count: number)
	if #refs.tabs == count then
		return
	end
	for _, tab in refs.tabs do
		tab:Destroy()
	end
	refs.tabs = {}

	for index = 1, count do
		local tab = el("TextButton", {
			Name = "Tab" .. index,
			LayoutOrder = index,
			Size = UDim2.fromOffset(46, 46),
			BackgroundColor3 = Theme.Paper.Background,
			AutoButtonColor = false,
			Font = Theme.FontBold,
			Text = tostring(index),
			TextColor3 = Theme.Paper.InkSoft,
			TextSize = 20,
			BorderSizePixel = 0,
		}, refs.tabsFrame)
		Util.roundify(tab, 10, Theme.Paper.Line, 2)

		tab.MouseButton1Click:Connect(function()
			PaperUI.setCurrent(index)
		end)
		refs.tabs[index] = tab
	end
end

function PaperUI.setCurrent(index: number)
	local snapshot = PaperUI.snapshot
	if not snapshot then
		return
	end
	PaperUI.current = math.clamp(index, 1, #snapshot.questions)
	PaperUI.render()
	if PaperUI.onSelect then
		PaperUI.onSelect(PaperUI.current)
	end
end

function PaperUI.firstUnanswered(): number
	local snapshot = PaperUI.snapshot
	if not snapshot then
		return 1
	end
	for index = 1, #snapshot.questions do
		if not snapshot.answers[index] then
			return index
		end
	end
	return #snapshot.questions
end

function PaperUI.setSnapshot(snapshot: any)
	local first = PaperUI.snapshot == nil
	PaperUI.snapshot = snapshot
	if first or snapshot.answers[PaperUI.current] then
		PaperUI.current = PaperUI.firstUnanswered()
	end
	PaperUI.render()
	if PaperUI.onSelect then
		PaperUI.onSelect(PaperUI.current)
	end
end

function PaperUI.render()
	local snapshot = PaperUI.snapshot
	if not gui or not snapshot then
		return
	end

	buildTabs(#snapshot.questions)

	local question = snapshot.questions[PaperUI.current]
	if not question then
		return
	end
	local record = snapshot.answers[PaperUI.current]

	refs.topic.Text = string.format("Ejercicio %d de %d  ·  %s", PaperUI.current, #snapshot.questions, question.topic)
	refs.prompt.Text = question.prompt
	refs.grade.Text = snapshot.answered > 0 and string.format("%.1f", snapshot.grade) or "-"

	for index, button in refs.options do
		local text = question.choices[index] or ""
		button.Text = text
		button.Visible = text ~= ""

		local bullet = button:FindFirstChild("Bullet")
		local letter = bullet and bullet:FindFirstChild("Letra")
		local stroke = button:FindFirstChildOfClass("UIStroke")
		local bulletStroke = bullet and bullet:FindFirstChildOfClass("UIStroke")

		local color = Theme.Paper.Line
		local fill = Theme.Paper.Background
		local ink = Theme.Paper.Ink

		if record then
			if index == record.choice then
				color = record.correct and Theme.Paper.Correct or Theme.Paper.Wrong
				fill = color:Lerp(Theme.Paper.Background, 0.85)
				ink = color
			else
				ink = Theme.Paper.InkSoft
			end
		end

		button.BackgroundColor3 = fill
		button.TextColor3 = ink
		if stroke then
			stroke.Color = color
			stroke.Thickness = record and index == record.choice and 3 or 2
		end
		if bulletStroke then
			bulletStroke.Color = color
		end
		if letter then
			letter.TextColor3 = ink
		end
	end

	for index, tab in refs.tabs do
		local answered = snapshot.answers[index]
		local stroke = tab:FindFirstChildOfClass("UIStroke")
		local isCurrent = index == PaperUI.current

		if answered then
			local color = answered.correct and Theme.Paper.Correct or Theme.Paper.Wrong
			tab.BackgroundColor3 = color:Lerp(Theme.Paper.Background, 0.82)
			tab.TextColor3 = color
			if stroke then
				stroke.Color = color
			end
		else
			tab.BackgroundColor3 = Theme.Paper.Background
			tab.TextColor3 = Theme.Paper.InkSoft
			if stroke then
				stroke.Color = Theme.Paper.Line
			end
		end

		if isCurrent then
			tab.TextColor3 = Theme.Paper.Accent
			if stroke then
				stroke.Color = Theme.Paper.Accent
				stroke.Thickness = 3
			end
		elseif stroke then
			stroke.Thickness = 2
		end
	end

	if record then
		refs.footer.Text = record.correct
			and "Bien. Pasá al siguiente ejercicio."
			or "Ese estaba mal. Ya no se puede corregir."
	elseif snapshot.finished then
		refs.footer.Text = "Prueba entregada."
	else
		refs.footer.Text = "Tocá una opcion para responder. La foto del celular sale de este ejercicio."
	end
end

function PaperUI.setEnabled(enabled: boolean)
	if gui then
		gui.Enabled = enabled
	end
end

function PaperUI.destroy()
	if gui then
		gui:Destroy()
		gui = nil
	end
end

return PaperUI

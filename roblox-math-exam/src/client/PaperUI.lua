--!strict
--[[
	PaperUI
	------------------------------------------------------------------
	La hoja de la prueba. No es una pantalla plana pegada a la camara:
	es una SurfaceGui montada sobre la hoja fisica apoyada en el banco,
	con el Adornee puesto desde el PlayerGui (que es lo que hace que los
	botones sean clickeables en el mundo 3D).

	Formato vertical, como una hoja de verdad: encabezado arriba, el
	ejercicio, las cuatro opciones una debajo de la otra, y abajo la
	tira de numeros para moverse entre ejercicios.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
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
	refs = {}

	local playerGui = player:WaitForChild("PlayerGui")

	gui = el("SurfaceGui", {
		Name = "HojaDePrueba",
		Adornee = paperPart,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 340,
		LightInfluence = 0.2,
		MaxDistance = 40,
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

	el("UIPadding", {
		PaddingTop = UDim.new(0.03, 0),
		PaddingBottom = UDim.new(0.03, 0),
		PaddingLeft = UDim.new(0.06, 0),
		PaddingRight = UDim.new(0.06, 0),
	}, sheet)

	-- ── Encabezado ────────────────────────────────────────
	refs.headerTitle = el("TextLabel", {
		Size = UDim2.fromScale(1, 0.045),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		Text = Strings.get("paper.title"),
		TextColor3 = Theme.Paper.Ink,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, sheet)

	refs.student = el("TextLabel", {
		Position = UDim2.fromScale(0, 0.052),
		Size = UDim2.fromScale(0.72, 0.028),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = Strings.get("paper.student", { name = player.DisplayName }),
		TextColor3 = Theme.Paper.InkSoft,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, sheet)

	local gradeBox = el("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.2, 0.075),
		BackgroundTransparency = 1,
	}, sheet)
	Util.roundify(gradeBox, 8, Theme.Paper.Line, 2)

	refs.gradeLabel = el("TextLabel", {
		Size = UDim2.fromScale(1, 0.32),
		Position = UDim2.fromScale(0, 0.08),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = Strings.get("paper.grade"),
		TextColor3 = Theme.Paper.InkSoft,
		TextScaled = true,
	}, gradeBox)

	refs.grade = el("TextLabel", {
		Size = UDim2.fromScale(1, 0.5),
		Position = UDim2.fromScale(0, 0.42),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		Text = "-",
		TextColor3 = Theme.Paper.Accent,
		TextScaled = true,
	}, gradeBox)

	el("Frame", {
		Position = UDim2.fromScale(0, 0.092),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = Theme.Paper.Line,
		BorderSizePixel = 0,
	}, sheet)

	-- ── Ejercicio ─────────────────────────────────────────
	refs.topic = el("TextLabel", {
		Position = UDim2.fromScale(0, 0.115),
		Size = UDim2.fromScale(1, 0.028),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = "",
		TextColor3 = Theme.Paper.Accent,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, sheet)

	refs.prompt = el("TextLabel", {
		Position = UDim2.fromScale(0, 0.155),
		Size = UDim2.fromScale(1, 0.145),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		Text = "",
		TextColor3 = Theme.Paper.Ink,
		TextSize = 46,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, sheet)

	-- ── Opciones, una debajo de la otra ───────────────────
	local options = el("Frame", {
		Position = UDim2.fromScale(0, 0.32),
		Size = UDim2.fromScale(1, 0.44),
		BackgroundTransparency = 1,
	}, sheet)

	el("UIListLayout", {
		Padding = UDim.new(0.03, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, options)

	refs.options = {}
	for index = 1, 4 do
		local button = el("TextButton", {
			Name = "Opcion" .. index,
			LayoutOrder = index,
			Size = UDim2.fromScale(1, 0.2275),
			BackgroundColor3 = Theme.Paper.Background,
			AutoButtonColor = false,
			Font = Theme.Font,
			Text = "",
			TextColor3 = Theme.Paper.Ink,
			TextSize = 38,
			TextXAlignment = Enum.TextXAlignment.Left,
			BorderSizePixel = 0,
		}, options)
		Util.roundify(button, 10, Theme.Paper.Line, 2)

		el("UIPadding", { PaddingLeft = UDim.new(0, 78), PaddingRight = UDim.new(0, 18) }, button)

		local bullet = el("Frame", {
			Name = "Bullet",
			Size = UDim2.fromOffset(44, 44),
			Position = UDim2.new(0, -62, 0.5, -22),
			BackgroundColor3 = Theme.Paper.Background,
			BorderSizePixel = 0,
		}, button)
		Util.roundify(bullet, 22, Theme.Paper.InkSoft, 2)

		el("TextLabel", {
			Name = "Letra",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Theme.FontBold,
			Text = LETTERS[index],
			TextColor3 = Theme.Paper.InkSoft,
			TextSize = 26,
		}, bullet)

		button.MouseButton1Click:Connect(function()
			if PaperUI.onAnswer then
				PaperUI.onAnswer(PaperUI.current, index)
			end
		end)

		refs.options[index] = button
	end

	-- ── Tira de ejercicios ────────────────────────────────
	el("Frame", {
		Position = UDim2.fromScale(0, 0.79),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = Theme.Paper.Line,
		BorderSizePixel = 0,
	}, sheet)

	local tabs = el("Frame", {
		Position = UDim2.fromScale(0, 0.815),
		Size = UDim2.fromScale(1, 0.075),
		BackgroundTransparency = 1,
	}, sheet)

	el("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0.014, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, tabs)

	refs.tabs = {}
	refs.tabsFrame = tabs

	refs.footer = el("TextLabel", {
		Position = UDim2.fromScale(0, 0.915),
		Size = UDim2.fromScale(1, 0.06),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = Strings.get("paper.footer.default"),
		TextColor3 = Theme.Paper.InkSoft,
		TextSize = 26,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
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
			Size = UDim2.fromScale(0.098, 1),
			BackgroundColor3 = Theme.Paper.Background,
			AutoButtonColor = false,
			Font = Theme.FontBold,
			Text = tostring(index),
			TextColor3 = Theme.Paper.InkSoft,
			TextScaled = true,
			BorderSizePixel = 0,
		}, refs.tabsFrame)
		Util.roundify(tab, 8, Theme.Paper.Line, 2)

		el("UIPadding", {
			PaddingTop = UDim.new(0.22, 0),
			PaddingBottom = UDim.new(0.22, 0),
		}, tab)

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
	PaperUI.current = math.clamp(index, 1, math.max(1, #snapshot.questions))
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
	return math.max(1, #snapshot.questions)
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
	if not gui or not snapshot or not refs.topic then
		return
	end

	refs.headerTitle.Text = Strings.get("paper.title")
	refs.student.Text = Strings.get("paper.student", { name = player.DisplayName })
	refs.gradeLabel.Text = Strings.get("paper.grade")

	buildTabs(#snapshot.questions)

	local question = snapshot.questions[PaperUI.current]
	if not question then
		return
	end
	local record = snapshot.answers[PaperUI.current]

	refs.topic.Text = Strings.get("paper.exercise", {
		index = PaperUI.current,
		total = #snapshot.questions,
		topic = Strings.get(question.topicKey),
	})
	refs.prompt.Text = Strings.get(question.promptKey, question.promptArgs)
	refs.grade.Text = snapshot.answered > 0 and string.format("%.1f", snapshot.grade) or "-"

	for index, button in refs.options do
		-- Las opciones son numeros (iguales en todo idioma) salvo las de
		-- relleno, que viajan como "@clave".
		local text = question.choices[index] and Strings.choice(question.choices[index]) or ""
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

		if index == PaperUI.current then
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
		refs.footer.Text = Strings.get(record.correct and "paper.footer.correct" or "paper.footer.wrong")
	elseif snapshot.finished then
		refs.footer.Text = Strings.get("paper.footer.finished")
	else
		refs.footer.Text = Strings.get("paper.footer.default")
	end
end

function PaperUI.setFooter(text: string)
	if refs.footer then
		refs.footer.Text = text
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
	refs = {}
end

return PaperUI

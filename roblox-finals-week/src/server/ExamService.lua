--!strict
--[[
	ExamService
	------------------------------------------------------------------
	El examen: quien se sienta donde, que pregunta le toca a cada uno,
	que respondio y como se copia.

	Decision de diseno: todos los alumnos de un aula reciben EL MISMO
	examen. Es lo que hace que copiar valga la pena — si cada uno
	tuviera preguntas distintas, espiar al de al lado seria inutil y la
	mecanica cooperativa se cae.

	El servidor nunca manda la respuesta correcta al cliente. Lo unico
	que viaja es el enunciado, las opciones y — si usaste una chuleta —
	los indices que la chuleta te revelo.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Theme = require(Shared:WaitForChild("Theme"))

local QuestionBank = require(script.Parent:WaitForChild("QuestionBank"))
local SuspicionService = require(script.Parent:WaitForChild("SuspicionService"))

local X = Config.Examen

local ExamService = {}

export type Sitting = {
	player: Player,
	aula: number,
	desk: any,               -- MapBuilder.Desk
	answers: { [number]: number },
	revealed: { [number]: boolean },
	sheetUses: number,
	lastPeek: number,
	lastWhisper: number,
	typing: { [number]: boolean },
}

local map: any = nil
local exams: { [number]: { any } } = {}      -- aula -> preguntas (con respuesta)
local sittings: { [Player]: Sitting } = {}
-- Chuletas conseguidas en el recreo, cuando todavia no hay pupitre
-- asignado: se cobran al sentarse. Sin esto, comprar una chuleta antes
-- del examen (que es el unico momento en que se puede) no servia.
local pendingSheets: { [Player]: number } = {}
-- Respuestas aprendidas leyendo libros en el recreo: se revelan solas
-- al sentarse. Estudiar tambien es una forma de ganar.
local pendingKnowledge: { [Player]: number } = {}
local running = false
local currentDay = 1

local LETRAS = { "A", "B", "C", "D", "E", "F" }

-- ── la hoja del pupitre ────────────────────────────────────────────
-- Se dibuja en el mundo a proposito: por eso se puede espiar.

local function paperGui(desk: any): SurfaceGui
	local paper: BasePart = desk.paper
	local existing = paper:FindFirstChild("Hoja")
	if existing and existing:IsA("SurfaceGui") then
		return existing
	end

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Hoja"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	-- 120 sobre una hoja de 3.2 studs da 384 px de ancho: alcanza para
	-- que las filas se lean de cerca, que es como se usa.
	gui.PixelsPerStud = 120
	gui.LightInfluence = 0.35
	gui.MaxDistance = 60
	gui.Parent = paper

	local sheet = Instance.new("Frame")
	sheet.Name = "Papel"
	sheet.Size = UDim2.fromScale(1, 1)
	sheet.BackgroundColor3 = Theme.Paper.Background
	sheet.BorderSizePixel = 0
	sheet.Parent = gui

	-- El margen rojo de toda hoja de examen.
	local margin = Instance.new("Frame")
	margin.Name = "Margen"
	margin.Size = UDim2.new(0, 2, 1, 0)
	margin.Position = UDim2.fromOffset(34, 0)
	margin.BackgroundColor3 = Color3.fromRGB(216, 128, 124)
	margin.BackgroundTransparency = 0.3
	margin.BorderSizePixel = 0
	margin.Parent = sheet

	local title = Instance.new("TextLabel")
	title.Name = "Titulo"
	title.Size = UDim2.new(1, -56, 0, 22)
	title.Position = UDim2.fromOffset(44, 8)
	title.BackgroundTransparency = 1
	title.Font = Theme.FontBold
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.Paper.Ink
	title.Text = ""
	title.Parent = sheet

	-- El contador de avance, abajo a la derecha, como el "2/4" que se ve
	-- en el trailer.
	local progress = Instance.new("TextLabel")
	progress.Name = "Avance"
	progress.Size = UDim2.fromOffset(70, 22)
	progress.Position = UDim2.new(1, -78, 1, -28)
	progress.BackgroundTransparency = 1
	progress.Font = Theme.FontBold
	progress.TextSize = 18
	progress.TextXAlignment = Enum.TextXAlignment.Right
	progress.TextColor3 = Theme.Paper.InkSoft
	progress.Text = ""
	progress.Parent = sheet

	--[[
		Las filas: una por pregunta, con su numero y las casillas A-D. Es
		una hoja de respuestas de burbujas, que es lo que se ve en la
		referencia — no una lista de texto.
	--]]
	local rows = Instance.new("Frame")
	rows.Name = "Filas"
	rows.Size = UDim2.new(1, -56, 1, -66)
	rows.Position = UDim2.fromOffset(44, 34)
	rows.BackgroundTransparency = 1
	rows.Parent = sheet

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 3)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = rows

	return gui
end

--[[
	Redibuja la hoja del pupitre.

	Una fila por pregunta: el numero y cuatro casillas A-D, la elegida
	rellena. Es la hoja de burbujas que se ve en el trailer, y esta en el
	mundo a proposito — por eso se puede espiar la del de al lado, y por
	eso vale la pena que se lea bien.
--]]
local function refreshPaper(sitting: Sitting)
	local ok = pcall(function()
		local gui = paperGui(sitting.desk)
		local sheet = gui:FindFirstChild("Papel") :: Frame
		local title = sheet:FindFirstChild("Titulo") :: TextLabel
		local progress = sheet:FindFirstChild("Avance") :: TextLabel
		local rows = sheet:FindFirstChild("Filas") :: Frame

		title.Text = sitting.player.DisplayName

		local questions = exams[sitting.aula] or {}
		local answered = 0

		for i = 1, #questions do
			local row = rows:FindFirstChild("Q" .. i) :: Frame?
			if not row then
				local created = Instance.new("Frame")
				created.Name = "Q" .. i
				created.LayoutOrder = i
				created.Size = UDim2.new(1, 0, 0, 20)
				created.BackgroundTransparency = 1
				created.Parent = rows

				local number = Instance.new("TextLabel")
				number.Name = "N"
				number.Size = UDim2.fromOffset(26, 20)
				number.BackgroundTransparency = 1
				number.Font = Theme.FontBold
				number.TextSize = 15
				number.TextXAlignment = Enum.TextXAlignment.Right
				number.TextColor3 = Theme.Paper.InkSoft
				number.Text = tostring(i) .. "."
				number.Parent = created

				for option = 1, Config.Examen.OpcionesPorPregunta do
					local box = Instance.new("TextLabel")
					box.Name = "O" .. option
					box.Size = UDim2.fromOffset(18, 16)
					box.Position = UDim2.fromOffset(34 + (option - 1) * 22, 2)
					box.BackgroundColor3 = Theme.Paper.Background
					box.BorderSizePixel = 0
					box.Font = Theme.FontBold
					box.TextSize = 11
					box.TextColor3 = Theme.Paper.InkSoft
					box.Text = LETRAS[option] or "?"
					box.Parent = created

					local corner = Instance.new("UICorner")
					corner.CornerRadius = UDim.new(1, 0)
					corner.Parent = box

					local stroke = Instance.new("UIStroke")
					stroke.Color = Theme.Paper.Line
					stroke.Thickness = 1
					stroke.Parent = box
				end
				row = created
			end

			local choice = sitting.answers[i]
			if choice then
				answered += 1
			end
			local assertRow = row :: Frame
			for option = 1, Config.Examen.OpcionesPorPregunta do
				local box = assertRow:FindFirstChild("O" .. option) :: TextLabel?
				if box then
					local chosen = choice == option
					box.BackgroundColor3 = chosen and Theme.Paper.Accent
						or Theme.Paper.Background
					box.TextColor3 = chosen and Color3.fromRGB(250, 250, 246)
						or Theme.Paper.InkSoft
				end
			end
		end

		progress.Text = string.format("%d/%d", answered, #questions)
	end)
	if not ok then
		-- Una hoja que no se dibuja no puede tumbar el examen.
	end
end

-- ── estado que ve el cliente ───────────────────────────────────────

local function publicState(sitting: Sitting): any
	local questions = exams[sitting.aula]
	if not questions then
		return { activo = false }
	end
	-- Arrays DENSOS, no tablas con huecos: un remote de Roblox no
	-- serializa de forma confiable { [3] = 2, [7] = 1 }, y el cliente
	-- recibiria basura justo en la mitad del examen. 0 = sin responder.
	local answers = table.create(#questions, 0)
	local revealed = table.create(#questions, 0)
	for index = 1, #questions do
		answers[index] = sitting.answers[index] or 0
		if sitting.revealed[index] then
			revealed[index] = (questions[index] :: any).respuesta
		end
	end

	return {
		activo = running,
		dia = currentDay,
		preguntas = QuestionBank.publicView(questions),
		respuestas = answers,
		reveladas = revealed,
		chuleta = sitting.sheetUses,
		fila = sitting.desk.fila,
		asiento = sitting.desk.asiento,
		aula = sitting.aula,
	}
end

local function pushState(player: Player)
	local sitting = sittings[player]
	if not sitting then
		Net.event(Net.Events.ExamUpdate):FireClient(player, { activo = false })
		return
	end
	Net.event(Net.Events.ExamUpdate):FireClient(player, publicState(sitting))
end

function ExamService.pushState(player: Player)
	pushState(player)
end

function ExamService.state(player: Player): any
	local sitting = sittings[player]
	if not sitting then
		return { activo = false }
	end
	return publicState(sitting)
end

-- ── asientos ───────────────────────────────────────────────────────

function ExamService.setMap(newMap: any)
	map = newMap
end

function ExamService.sitting(player: Player): Sitting?
	return sittings[player]
end

--- Sentado de verdad en SU pupitre (no en cualquier silla).
function ExamService.isSeated(player: Player): boolean
	local sitting = sittings[player]
	if not sitting then
		return false
	end
	return sitting.desk.seat.Occupant ~= nil
		and sitting.desk.seat.Occupant.Parent == player.Character
end

--- Reparte a los jugadores por aulas y pupitres, en orden.
function ExamService.assignSeats(players: { Player })
	sittings = {}
	if not map or #map.classrooms == 0 then
		return
	end

	local rooms = map.classrooms
	local perRoom = math.max(1, math.ceil(#players / #rooms))

	for index, player in players do
		local roomIndex = math.min(#rooms, math.floor((index - 1) / perRoom) + 1)
		local room = rooms[roomIndex]
		local deskIndex = ((index - 1) % #room.desks) + 1
		local desk = room.desks[deskIndex]
		if desk then
			sittings[player] = {
				player = player,
				aula = room.index,
				desk = desk,
				answers = {},
				revealed = {},
				sheetUses = pendingSheets[player] or 0,
				lastPeek = 0,
				lastWhisper = 0,
				typing = {},
			}
		end
	end
end

--- Teletransporta a cada uno a su pupitre y lo sienta.
function ExamService.seatEveryone()
	for player, sitting in sittings do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and root:IsA("BasePart") then
			local seat = sitting.desk.seat
			root.CFrame = seat.CFrame * CFrame.new(0, 3, 0)
			task.defer(function()
				-- Un intento inmediato y otro un instante despues: si el
				-- personaje todavia estaba cayendo, el primero no prende.
				pcall(function()
					seat:Sit(humanoid)
				end)
				task.wait(0.35)
				if seat.Occupant == nil then
					pcall(function()
						seat:Sit(humanoid)
					end)
				end
			end)
			Net.event(Net.Events.Notify):FireClient(player, {
				key = "notify.seat",
				args = { row = sitting.desk.fila, seat = sitting.desk.asiento },
			})
		end
	end
end

-- ── ciclo del examen ───────────────────────────────────────────────

function ExamService.begin(day: number, players: { Player })
	currentDay = day
	running = true
	exams = {}

	ExamService.assignSeats(players)

	if map then
		for _, room in map.classrooms do
			exams[room.index] = QuestionBank.generate(day)
		end
	end

	-- Lo que aprendiste leyendo aparece ya revelado en la hoja.
	for player, sitting in sittings do
		local learned = pendingKnowledge[player] or 0
		if learned > 0 then
			local questions = exams[sitting.aula] or {}
			local pool = {}
			for i, question in questions do
				if question.tipo == "opcion" then
					table.insert(pool, i)
				end
			end
			for _ = 1, math.min(learned, #pool) do
				local pick = table.remove(pool, math.random(1, #pool))
				if pick then
					sitting.revealed[pick] = true
				end
			end
		end
	end
	pendingKnowledge = {}

	for player, sitting in sittings do
		refreshPaper(sitting)
		pushState(player)
	end
end

--- Cierra el examen y devuelve el recuento de cada alumno.
function ExamService.finish(): { [Player]: { correct: number, wrong: number, blank: number } }
	running = false
	local results: { [Player]: { correct: number, wrong: number, blank: number } } = {}

	for player, sitting in sittings do
		local questions = exams[sitting.aula] or {}
		local correct, wrong, blank = 0, 0, 0
		for i, question in questions do
			local answer = sitting.answers[i]
			if answer == nil then
				blank += 1
			elseif question.tipo == "escritura" then
				if sitting.typing[i] then
					correct += 1
				else
					wrong += 1
				end
			elseif answer == question.respuesta then
				correct += 1
			else
				wrong += 1
			end
		end
		results[player] = { correct = correct, wrong = wrong, blank = blank }
		Net.event(Net.Events.ExamUpdate):FireClient(player, { activo = false })
	end

	-- Las hojas vuelven a estar en blanco para el dia siguiente.
	for _, sitting in sittings do
		pcall(function()
			local gui = sitting.desk.paper:FindFirstChild("Hoja")
			if gui then
				gui:Destroy()
			end
		end)
	end

	return results
end

function ExamService.clear()
	running = false
	exams = {}
	sittings = {}
	pendingSheets = {}
end

function ExamService.isRunning(): boolean
	return running
end

-- ── responder ──────────────────────────────────────────────────────

function ExamService.submit(player: Player, index: number, option: number): any
	local sitting = sittings[player]
	if not running or not sitting then
		return { ok = false, reason = { key = "exam.not_started" } }
	end
	if not ExamService.isSeated(player) then
		return { ok = false, reason = { key = "error.not_seated" } }
	end

	local questions = exams[sitting.aula]
	local question = questions and questions[index]
	if not question or question.tipo ~= "opcion" then
		return { ok = false, reason = { key = "error.generic" } }
	end
	if type(option) ~= "number" or option < 1 or option > #question.opciones then
		return { ok = false, reason = { key = "error.generic" } }
	end

	sitting.answers[index] = math.floor(option)
	refreshPaper(sitting)
	return { ok = true }
end

--- Minijuego de escritura rapida: se valida la secuencia entera.
function ExamService.submitSequence(player: Player, index: number, typed: string): any
	local sitting = sittings[player]
	if not running or not sitting then
		return { ok = false, reason = { key = "exam.not_started" } }
	end
	if not ExamService.isSeated(player) then
		return { ok = false, reason = { key = "error.not_seated" } }
	end

	local questions = exams[sitting.aula]
	local question = questions and questions[index]
	if not question or question.tipo ~= "escritura" then
		return { ok = false, reason = { key = "error.generic" } }
	end
	if type(typed) ~= "string" or #typed > 32 then
		return { ok = false, reason = { key = "error.generic" } }
	end

	local hit = string.upper(typed) == string.upper(question.secuencia or "")
	sitting.answers[index] = hit and 1 or 2
	sitting.typing[index] = hit
	refreshPaper(sitting)
	return { ok = true, correcto = hit, reason = { key = hit and "exam.correct" or "exam.type_fail" } }
end

-- ── trampas ────────────────────────────────────────────────────────

--- El vecino sentado mas cerca dentro del alcance de copia.
local function nearestClassmate(sitting: Sitting, range: number): Sitting?
	local origin = sitting.desk.seat.Position
	local best: Sitting? = nil
	local bestDistance = range

	for other, candidate in sittings do
		if other ~= sitting.player and candidate.aula == sitting.aula then
			local distance = (candidate.desk.seat.Position - origin).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				best = candidate
			end
		end
	end
	return best
end

--- Espiar: te llevas la respuesta que el otro ya escribio, con riesgo
--- de leer mal. Si el vecino no contesto todavia, no hay nada que ver.
function ExamService.peek(player: Player, index: number): any
	local sitting = sittings[player]
	if not running or not sitting then
		return { ok = false, reason = { key = "exam.not_started" } }
	end
	if not ExamService.isSeated(player) then
		return { ok = false, reason = { key = "error.not_seated" } }
	end
	local now = os.clock()
	if now - sitting.lastPeek < X.CopiarSegundos then
		return { ok = false, reason = { key = "cheat.cooldown" } }
	end
	sitting.lastPeek = now

	local neighbour = nearestClassmate(sitting, X.CopiarAlcance)
	if not neighbour then
		return { ok = false, reason = { key = "cheat.peek_none" } }
	end

	-- Espiar siempre se paga: el gesto se ve, lo vea o no el profesor.
	SuspicionService.infraction(player, Config.Sospecha.PorEspiar, "peek")

	local seen = neighbour.answers[index]
	if not seen then
		return { ok = false, reason = { key = "cheat.peek_fail" } }
	end

	local questions = exams[sitting.aula]
	local question = questions and questions[index]
	if not question then
		return { ok = false, reason = { key = "error.generic" } }
	end

	-- A veces se lee mal de reojo.
	local value = seen
	if math.random() > X.CopiarAcierto then
		value = math.random(1, math.max(1, #question.opciones))
	end

	sitting.answers[index] = value
	refreshPaper(sitting)
	pushState(player)
	return { ok = true, indice = index, reason = { key = "cheat.peek_ok", args = { i = index } } }
end

--- Soplar: le pasas tu respuesta a los que estan cerca.
function ExamService.whisper(player: Player, index: number): any
	local sitting = sittings[player]
	if not running or not sitting then
		return { ok = false, reason = { key = "exam.not_started" } }
	end
	local now = os.clock()
	if now - sitting.lastWhisper < Config.Objetos.SoplarEnfriamiento then
		return { ok = false, reason = { key = "cheat.cooldown" } }
	end
	local mine = sitting.answers[index]
	if not mine then
		return { ok = false, reason = { key = "cheat.none" } }
	end
	sitting.lastWhisper = now

	SuspicionService.infraction(player, Config.Sospecha.PorSoplar, "whisper")

	local origin = sitting.desk.seat.Position
	local reached = 0
	for other, candidate in sittings do
		if other ~= player and candidate.aula == sitting.aula
			and (candidate.desk.seat.Position - origin).Magnitude <= Config.Objetos.SoplarAlcance then
			reached += 1
			Net.event(Net.Events.Notify):FireClient(other, {
				key = "cheat.whisper_got",
				args = { name = player.DisplayName, i = index, opt = LETRAS[mine] or "?" },
			})
		end
	end

	return { ok = true, alcanzados = reached,
		reason = { key = "cheat.whisper_sent", args = { i = index } } }
end

--- Chuleta: revela respuestas correctas al azar entre las que faltan.
function ExamService.useSheet(player: Player): any
	local sitting = sittings[player]
	if not running or not sitting then
		return { ok = false, reason = { key = "exam.not_started" } }
	end
	if sitting.sheetUses <= 0 then
		return { ok = false, reason = { key = "cheat.sheet_empty" } }
	end
	if not ExamService.isSeated(player) then
		return { ok = false, reason = { key = "error.not_seated" } }
	end

	local questions = exams[sitting.aula] or {}
	local pending: { number } = {}
	for i, question in questions do
		if question.tipo == "opcion" and not sitting.revealed[i] and sitting.answers[i] == nil then
			table.insert(pending, i)
		end
	end
	if #pending == 0 then
		for i, question in questions do
			if question.tipo == "opcion" and not sitting.revealed[i] then
				table.insert(pending, i)
			end
		end
	end
	if #pending == 0 then
		return { ok = false, reason = { key = "cheat.sheet_empty" } }
	end

	sitting.sheetUses -= 1
	SuspicionService.infraction(player, Config.Sospecha.PorChuleta, "sheet")

	local revealed = 0
	for _ = 1, math.min(Config.Objetos.ChuletaRevela, #pending) do
		local pick = table.remove(pending, math.random(1, #pending))
		if pick then
			sitting.revealed[pick] = true
			revealed += 1
		end
	end

	pushState(player)
	return { ok = true, reason = { key = "cheat.sheet_used", args = { n = revealed } } }
end

--[[
	Los escondites con la hoja de respuestas: el cajon del escritorio del
	profesor y la alcoba secreta de la biblioteca.

	Son la misma idea con costos opuestos, y esa oposicion es el diseno:

	  cajon   esta al alcance de la mano durante el examen, revela poco y
	          cuesta casi toda la barra de sospecha. Es la jugada
	          desesperada del que ya no tiene nada que perder.
	  alcoba  revela el doble y no cuesta sospecha, pero esta del otro
	          lado del atrio y solo se puede abrir en el recreo. Lo que
	          pagas es el tiempo: mientras vas y volves no estas
	          comprando en el kiosco ni juntando libros.

	Esta funcion es tambien el arreglo de un prompt muerto: el cajon se
	construia con su ProximityPrompt desde la entrega anterior, pero
	nadie escuchaba el Triggered, asi que mantener E no hacia nada.
--]]
local stashCooldowns: { [Player]: { [string]: number } } = {}

function ExamService.openStash(player: Player, kind: string): any
	local now = os.clock()
	local perPlayer = stashCooldowns[player]
	if not perPlayer then
		perPlayer = {}
		stashCooldowns[player] = perPlayer
	end
	if (perPlayer[kind] or 0) > now then
		return { ok = false, reason = { key = "stash.cooling" } }
	end

	if kind == "cajon" then
		local sitting = sittings[player]
		if not running or not sitting then
			-- Fuera del examen el cajon esta vacio: la hoja del dia
			-- todavia no existe.
			return { ok = false, reason = { key = "stash.empty" } }
		end

		local questions = exams[sitting.aula] or {}
		local pending: { number } = {}
		for i, question in questions do
			if question.tipo == "opcion" and not sitting.revealed[i] then
				table.insert(pending, i)
			end
		end
		if #pending == 0 then
			return { ok = false, reason = { key = "stash.empty" } }
		end

		perPlayer[kind] = now + Config.Examen.CajonEnfriamiento
		SuspicionService.infraction(player, Config.Sospecha.PorCajon, "stash")

		local revealed = 0
		for _ = 1, math.min(Config.Examen.CajonRevela, #pending) do
			local pick = table.remove(pending, math.random(1, #pending))
			if pick then
				sitting.revealed[pick] = true
				revealed += 1
			end
		end

		pushState(player)
		return { ok = true, reason = { key = "stash.drawer", args = { n = revealed } } }
	end

	--[[
		La alcoba se abre en el recreo, cuando todavia no hay pupitre
		asignado, asi que las respuestas se anotan como conocimiento
		pendiente — el mismo camino que usan los libros de texto. Se
		cobran solas al sentarte.
	--]]
	if running then
		return { ok = false, reason = { key = "stash.locked" } }
	end
	perPlayer[kind] = now + Config.Examen.AlcobaEnfriamiento
	ExamService.grantKnowledge(player, Config.Examen.AlcobaRevela)
	return {
		ok = true,
		reason = { key = "stash.alcove", args = { n = Config.Examen.AlcobaRevela } },
	}
end

--[[
	Engancha los ProximityPrompt de los escondites. Se llama una vez al
	construir el mapa, igual que `ItemService.bindLockers`.

	Sin esto el prompt del cajon existia y no hacia nada: la barra se
	llenaba y no pasaba absolutamente nada. Es el arreglo del defecto.
--]]
function ExamService.bindStashes(root: Instance)
	local bound = 0
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("ProximityPrompt")
			and (descendant.Name == "Cajon" or descendant.Name == "Alcoba") then
			local kind = descendant.Name == "Cajon" and "cajon" or "alcoba"
			descendant.Triggered:Connect(function(player)
				local result = ExamService.openStash(player, kind)
				if result and result.reason then
					Net.event(Net.Events.Notify):FireClient(player, result.reason)
				end
			end)
			bound += 1
		end
	end
	print(string.format("[Examen] %d escondites enganchados.", bound))
end

--- Suma usos de chuleta. Si todavia no hay pupitre (estamos en el
--- recreo), quedan anotados y se cobran al sentarse.
function ExamService.grantSheetUses(player: Player, uses: number)
	local sitting = sittings[player]
	if sitting then
		sitting.sheetUses += uses
		pushState(player)
	else
		pendingSheets[player] = (pendingSheets[player] or 0) + uses
	end
end

--- Leer un libro de texto: te deja aprendidas N respuestas del
--- proximo examen. Se cobra al sentarse, igual que las chuletas.
function ExamService.grantKnowledge(player: Player, answers: number)
	pendingKnowledge[player] = (pendingKnowledge[player] or 0) + answers
end

function ExamService.knowledgeOf(player: Player): number
	return pendingKnowledge[player] or 0
end

--- Espiar con prismaticos: mismo mecanismo que espiar al de al lado,
--- pero contra un alumno concreto y con el alcance del aparato. Se
--- valida igual: solo se copia lo que el otro YA escribio.
function ExamService.peekAt(player: Player, target: Player, index: number, range: number): any
	local sitting = sittings[player]
	local other = sittings[target]
	if not running or not sitting or not other then
		return { ok = false, reason = { key = "zoom.no_target" } }
	end
	if sitting.aula ~= other.aula then
		return { ok = false, reason = { key = "zoom.no_target" } }
	end
	local distance = (other.desk.seat.Position - sitting.desk.seat.Position).Magnitude
	if distance > range then
		return { ok = false, reason = { key = "zoom.no_target" } }
	end

	local now = os.clock()
	if now - sitting.lastPeek < X.CopiarSegundos then
		return { ok = false, reason = { key = "cheat.cooldown" } }
	end
	sitting.lastPeek = now

	SuspicionService.infraction(player, Config.Herramientas.PrismaticosSospecha, "zoom")

	local seen = other.answers[index]
	if not seen then
		return { ok = false, reason = { key = "cheat.peek_fail" } }
	end

	-- Con prismaticos se lee mejor que de reojo: no hay error de lectura.
	sitting.answers[index] = seen
	refreshPaper(sitting)
	pushState(player)
	return { ok = true, reason = { key = "zoom.read", args = { i = index } } }
end

--- Todos los alumnos sentados en el aula de `player`, para que los
--- prismaticos sepan a quien pueden apuntar.
function ExamService.classmatesOf(player: Player): { { jugador: Player, asiento: BasePart } }
	local sitting = sittings[player]
	local list = {}
	if not sitting then
		return list
	end
	for other, candidate in sittings do
		if other ~= player and candidate.aula == sitting.aula then
			table.insert(list, { jugador = other, asiento = candidate.desk.seat })
		end
	end
	return list
end

--- Una nota recibida escribe la respuesta directamente en la hoja.
function ExamService.applyNote(player: Player, index: number, option: number)
	local sitting = sittings[player]
	if not running or not sitting then
		return
	end
	local questions = exams[sitting.aula]
	local question = questions and questions[index]
	if question and question.tipo == "opcion" and option >= 1 and option <= #question.opciones then
		sitting.answers[index] = option
		refreshPaper(sitting)
		pushState(player)
	end
end

function ExamService.start()
	Players.PlayerRemoving:Connect(function(player)
		sittings[player] = nil
		pendingSheets[player] = nil
		pendingKnowledge[player] = nil
	end)
end

return ExamService

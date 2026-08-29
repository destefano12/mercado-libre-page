--!strict
--[[
	Music
	------------------------------------------------------------------
	Musica sin subir un solo archivo.

	Roblox trae unos pocos sonidos en rbxasset:// que existen siempre y
	en cualquier lugar. Cambiandoles PlaybackSpeed se los puede afinar:
	2^(n/12) es un semitono. Con eso se arma un secuenciador chiquito
	que toca bajo, arpegio y percusion segun el clima:

		pasillo      mayor, tranquilo, ritmo de recreo
		examen       menor, lento, se siente el reloj
		tension      menor, mas rapido, pulso en cada tiempo
		persecucion  menor, corcheas, el profesor viene

	Si algun dia queres musica de verdad, poné el id en
	Config.Musica.IdPersonalizado y este modulo toca esa pista en loop
	en vez de sintetizar.
--]]

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Music = {}

local BAJO = "rbxasset://sounds/bass.wav"
local LEAD = "rbxasset://sounds/electronicpingshort.wav"
local PERC = "rbxasset://sounds/switch3.wav"

-- Grados de la escala, en semitonos desde la tonica.
local MAYOR = { 0, 2, 4, 7, 9 }
local MENOR = { 0, 3, 5, 7, 10 }

type Pattern = {
	escala: { number },
	raiz: number,
	bajo: { number },      -- indice de grado por corchea, 0 = silencio
	lead: { number },
	perc: { number },
	volumen: number,
}

local PATRONES: { [string]: Pattern } = {
	pasillo = {
		escala = MAYOR, raiz = -12,
		bajo = { 1, 0, 0, 0, 3, 0, 0, 0 },
		lead = { 0, 4, 0, 5, 0, 3, 0, 2 },
		perc = { 1, 0, 1, 0, 1, 0, 1, 1 },
		volumen = 0.75,
	},
	examen = {
		escala = MENOR, raiz = -12,
		bajo = { 1, 0, 0, 0, 0, 0, 4, 0 },
		lead = { 0, 0, 3, 0, 0, 0, 0, 2 },
		perc = { 1, 0, 0, 0, 1, 0, 0, 0 },
		volumen = 0.6,
	},
	tension = {
		escala = MENOR, raiz = -14,
		bajo = { 1, 0, 1, 0, 1, 0, 1, 0 },
		lead = { 0, 2, 0, 3, 0, 2, 0, 5 },
		perc = { 1, 0, 1, 1, 1, 0, 1, 1 },
		volumen = 0.85,
	},
	persecucion = {
		escala = MENOR, raiz = -17,
		bajo = { 1, 1, 4, 1, 1, 1, 5, 3 },
		lead = { 5, 4, 3, 4, 5, 4, 2, 1 },
		perc = { 1, 1, 1, 1, 1, 1, 1, 1 },
		volumen = 1,
	},
}

local group: SoundGroup
local custom: Sound? = nil
local climate = "pasillo"
local enabled = true
local running = false
local step = 0

local function semitone(n: number): number
	return 2 ^ (n / 12)
end

local function ensureGroup(): SoundGroup
	if group and group.Parent then
		return group
	end
	local existing = SoundService:FindFirstChild("Musica")
	if existing and existing:IsA("SoundGroup") then
		group = existing
		return group
	end
	local created = Instance.new("SoundGroup")
	created.Name = "Musica"
	created.Volume = Config.Musica.Volumen
	created.Parent = SoundService
	group = created
	return group
end

--- Una nota suelta. Se destruye sola: a ~4 notas por segundo no vale
--- la pena mantener un pool.
local function note(soundId: string, pitch: number, volume: number, length: number)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.PlaybackSpeed = pitch
	sound.Volume = volume
	sound.SoundGroup = ensureGroup()
	sound.Parent = SoundService
	sound:Play()
	task.delay(length, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

local function playStep(pattern: Pattern, eighth: number)
	local index = (eighth % 8) + 1
	local scale = pattern.escala

	local bass = pattern.bajo[index]
	if bass and bass > 0 then
		note(BAJO, semitone(pattern.raiz + scale[bass]), 0.55 * pattern.volumen, 0.7)
	end

	local lead = pattern.lead[index]
	if lead and lead > 0 then
		note(LEAD, semitone(pattern.raiz + 12 + scale[lead]), 0.32 * pattern.volumen, 0.5)
	end

	local perc = pattern.perc[index]
	if perc and perc > 0 then
		note(PERC, 0.85 + (index % 3) * 0.1, 0.2 * pattern.volumen, 0.25)
	end
end

local function stopCustom()
	if custom then
		custom:Stop()
		custom:Destroy()
		custom = nil
	end
end

--- Si hay un id puesto en Config, se usa esa pista y no el secuenciador.
local function tryCustom(name: string): boolean
	local id = Config.Musica.IdPersonalizado[name]
	if not id or id == "" then
		stopCustom()
		return false
	end
	stopCustom()
	local sound = Instance.new("Sound")
	sound.SoundId = string.find(id, "://") and id or ("rbxassetid://" .. id)
	sound.Looped = true
	sound.Volume = 1
	sound.SoundGroup = ensureGroup()
	sound.Parent = SoundService
	sound:Play()
	custom = sound
	return true
end

function Music.setClimate(name: string)
	if not PATRONES[name] then
		name = "pasillo"
	end
	if climate == name then
		return
	end
	climate = name
	step = 0
	tryCustom(name)
end

function Music.setEnabled(on: boolean)
	enabled = on
	ensureGroup().Volume = on and Config.Musica.Volumen or 0
	if not on then
		stopCustom()
	elseif custom == nil then
		tryCustom(climate)
	end
end

function Music.setVolume(alpha: number)
	ensureGroup().Volume = enabled and (Config.Musica.Volumen * alpha * 2) or 0
end

function Music.start()
	if running or not Config.Musica.Habilitada then
		return
	end
	running = true
	ensureGroup()
	tryCustom(climate)

	task.spawn(function()
		while running do
			local pattern = PATRONES[climate] or PATRONES.pasillo
			local bpm = Config.Musica.Bpm[climate] or 100
			local eighth = 30 / bpm

			if enabled and custom == nil then
				local ok, err = pcall(playStep, pattern, step)
				if not ok then
					warn("[Musica] " .. tostring(err))
				end
			end
			step += 1
			task.wait(eighth)
		end
	end)
end

function Music.stop()
	running = false
	stopCustom()
end

return Music

--!strict
--[[
	TextFilter
	------------------------------------------------------------------
	Cualquier texto que escribe un jugador y lee OTRO jugador tiene que
	pasar por el filtro de Roblox. Es una obligacion de la plataforma,
	no una opcion, y aplica a los tres sitios donde este juego deja
	escribir: las notas de papel, el walkie y el celular.

	Regla de este modulo: si el filtro no responde, NO se manda nada.
	Es preferible perder un mensaje que publicar texto sin filtrar.
--]]

local TextService = game:GetService("TextService")

local TextFilter = {}

--- Devuelve el texto filtrado listo para mostrarselo a cualquiera, o
--- nil si el filtro fallo (en cuyo caso no hay que mandar nada).
function TextFilter.forBroadcast(text: string, fromUserId: number): string?
	if text == "" then
		return ""
	end

	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(
			text, fromUserId, Enum.TextFilterContext.PublicChat)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)

	if ok and type(result) == "string" then
		return result
	end
	warn("[Filtro] no se pudo filtrar un mensaje: no se envia.")
	return nil
end

--- Recorta a `limit` caracteres y saca los espacios de los bordes.
function TextFilter.trim(text: any, limit: number): string
	if typeof(text) ~= "string" then
		return ""
	end
	local clean = string.gsub(text, "^%s+", "")
	clean = string.gsub(clean, "%s+$", "")
	return string.sub(clean, 1, limit)
end

return TextFilter

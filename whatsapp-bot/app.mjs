import 'dotenv/config'
import http from 'node:http'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import QRCode from 'qrcode'
import { GoogleGenAI } from '@google/genai'
import { createBot, createProvider, createFlow, addKeyword, EVENTS, MemoryDB } from '@builderbot/bot'
import { BaileysProvider } from '@builderbot/provider-baileys'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const PORT = Number(process.env.PORT || 3008)
// gemini-2.5-flash-lite: el más rápido del plan gratis y suficiente para preguntas frecuentes.
// (gemini-flash-latest era el valor anterior por defecto: "piensa" antes de responder y es lento)
const MODEL = !process.env.GEMINI_MODEL || process.env.GEMINI_MODEL === 'gemini-flash-latest'
  ? 'gemini-2.5-flash-lite'
  : process.env.GEMINI_MODEL
const NO_SE = '[NO_SE]'
const DATA_DIR = path.join(__dirname, 'datos')
const CHATS_FILE = path.join(DATA_DIR, 'chats.json')

if (!process.env.GEMINI_API_KEY || process.env.GEMINI_API_KEY.includes('pega_aqui')) {
  console.error('\n❌ Falta GEMINI_API_KEY en el archivo .env (mira el paso 4 del README)\n')
  process.exit(1)
}
const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY })

// Si ya hay un bot abierto, no abrir otro: dos bots con la misma sesión hacen que WhatsApp la cierre
const puertoLibre = await new Promise((ok) => {
  const t = http.createServer().once('error', () => ok(false)).listen(PORT, () => t.close(() => ok(true)))
})
if (!puertoLibre) {
  console.error(`\n⚠️  Ya hay un bot abierto (el puerto ${PORT} está en uso). Usá esa ventana o cerrala antes de abrir otra.\n`)
  process.exit(2)
}

// ---------------------------------------------------------------- errores
// Ningún error apaga el bot: se anota en errores.log y en el panel.
const ERR_FILE = path.join(__dirname, 'errores.log')
let ultimoError = null
function anotarError(origen, e) {
  const msg = `[${new Date().toLocaleString()}] ${origen}: ${e?.stack || e?.message || e}`
  console.error('❌ ' + msg)
  ultimoError = { text: `${origen}: ${e?.message || e}`, ts: Date.now() }
  try { fs.appendFileSync(ERR_FILE, msg + '\n') } catch {}
}
process.on('uncaughtException', (e) => anotarError('Error inesperado', e))
process.on('unhandledRejection', (e) => anotarError('Error inesperado', e))

// ---------------------------------------------------------------- estado
fs.mkdirSync(DATA_DIR, { recursive: true })
const state = {
  status: 'iniciando', // iniciando | qr | conectado | desconectado
  qr: null,
  me: null,
  chats: loadChats(), // { [id]: { id, name, paused, unread, messages: [{from:'cliente'|'bot'|'yo'|'sistema', text, ts}] } }
  alerts: [], // { chatId, name, question, ts }
}

function loadChats() {
  try { return JSON.parse(fs.readFileSync(CHATS_FILE, 'utf8')) } catch { return {} }
}
let saveTimer
function saveChats() {
  clearTimeout(saveTimer)
  saveTimer = setTimeout(() => fs.writeFile(CHATS_FILE, JSON.stringify(state.chats), () => {}), 500)
}
function chat(id, name) {
  const c = (state.chats[id] ??= { id, name: name || id, paused: false, unread: 0, messages: [] })
  if (name) c.name = name
  return c
}
function log(id, from, text, name) {
  const c = chat(id, name)
  c.messages.push({ from, text, ts: Date.now() })
  if (c.messages.length > 300) c.messages.splice(0, c.messages.length - 300)
  if (from === 'cliente') c.unread++
  saveChats()
}

// ---------------------------------------------------------------- Gemini
// Si un modelo está saturado o tarda, prueba otro. Nunca más de ~30 s en total
// (BuilderBot corta cada mensaje a los 50 s y el cliente se quedaría sin respuesta).
const MODELOS = [...new Set([MODEL, 'gemini-2.5-flash-lite', 'gemini-flash-lite-latest', 'gemini-2.5-flash', 'gemini-flash-latest'])]
const LIMITE_TOTAL_MS = 30000
const LIMITE_POR_MODELO_MS = 12000
let modeloBueno = null // el último que respondió bien se prueba primero
const esperar = (ms) => new Promise((r) => setTimeout(r, ms))
const codigo = (e) => Number(e?.status || e?.code || String(e?.message).match(/"code":\s*(\d{3})/)?.[1] || 0)
const claveInvalida = (e) => [401, 403].includes(codigo(e)) || /API_KEY_INVALID|API key not valid/i.test(String(e?.message))
async function generar(params) {
  const inicio = Date.now()
  let ultimo
  const orden = modeloBueno ? [modeloBueno, ...MODELOS.filter((m) => m !== modeloBueno)] : MODELOS
  for (const model of orden) {
    const resta = LIMITE_TOTAL_MS - (Date.now() - inicio)
    if (resta < 3000) break
    try {
      const res = await ai.models.generateContent({
        ...params,
        model,
        config: {
          ...params.config,
          // sin "pensamiento" interno: responde en 1-3 s en vez de 5-15 s
          ...(model.startsWith('gemini-2.5') ? { thinkingConfig: { thinkingBudget: 0 } } : {}),
          abortSignal: AbortSignal.timeout(Math.min(LIMITE_POR_MODELO_MS, resta)),
        },
      })
      console.log(`⏱️  Gemini respondió en ${((Date.now() - inicio) / 1000).toFixed(1)} s (${model})`)
      modeloBueno = model
      return res
    } catch (e) {
      ultimo = e
      if (claveInvalida(e)) throw e // clave mal: no sirve reintentar
      if (modeloBueno === model) modeloBueno = null
      await esperar(300)
    }
  }
  throw ultimo || new Error('Gemini tardó demasiado en responder')
}

function explicarError(e) {
  const c = codigo(e)
  if (claveInvalida(e)) return 'La clave de Gemini no es válida. Revisá GEMINI_API_KEY en el archivo .env'
  if (/AbortError|TimeoutError/.test(e?.name) || /aborted|tardó/i.test(String(e?.message))) return 'Gemini tardó demasiado en responder (está saturado). Reintentará con el próximo mensaje.'
  if (c === 429) return 'Se alcanzó el límite gratis de Gemini por ahora. Se libera solo en un rato.'
  if (c === 503 || c === 500) return 'Gemini está saturado en este momento (problema de Google, no tuyo). Reintentará solo.'
  return e?.message || String(e)
}

function leerNegocio() {
  return fs.readFileSync(path.join(__dirname, 'negocio.txt'), 'utf8')
    .split('\n').filter((l) => !l.trim().startsWith('#')).join('\n').trim()
}

async function responder(chatId) {
  const historial = state.chats[chatId].messages
    .filter((m) => m.from !== 'sistema')
    .slice(-12)
    .map((m) => ({ role: m.from === 'cliente' ? 'user' : 'model', parts: [{ text: m.text }] }))

  const res = await generar({
    contents: historial,
    config: {
      temperature: 0.3,
      systemInstruction: `Eres el asistente de WhatsApp de un negocio. Respondes a clientes en español, de forma breve (máximo 3-4 líneas), amable y natural, como una persona del local. Puedes usar algún emoji, sin exagerar.

REGLAS IMPORTANTES:
1. Responde SOLO con la información de la sección INFORMACIÓN DEL NEGOCIO. Nunca inventes precios, horarios, productos, stock, promociones ni datos.
2. Saludos, agradecimientos y despedidas puedes responderlos normalmente.
3. Si el cliente pregunta algo que NO está en la información, o pide algo que requiere a una persona (reclamos, reservas concretas, pedidos especiales, hablar con alguien), responde EXACTAMENTE con el texto ${NO_SE} y nada más.

INFORMACIÓN DEL NEGOCIO:
${leerNegocio()}`,
    },
  })
  return (res.text || '').trim()
}

// Prueba la clave de Gemini al arrancar, para avisar en el panel si está mal
generar({ contents: 'Responde solo: OK' })
  .then(() => console.log('✅ Clave de Gemini OK'))
  .catch((e) => anotarError('Gemini', { message: explicarError(e) }))

// ---------------------------------------------------------------- respuestas instantáneas
// Horarios, dirección, pagos, precios y saludos se contestan al instante desde negocio.txt,
// sin esperar a Gemini. Gemini solo se usa para las demás preguntas.
const normalizar = (t) => t.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '')
function secciones() {
  const out = {}
  let actual = null
  for (const linea of leerNegocio().split('\n')) {
    const m = linea.match(/^([A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑ ]{2,}):\s*(.*)$/)
    if (m) { actual = normalizar(m[1].trim()); out[actual] = m[2] ? [m[2]] : []; continue }
    if (actual) out[actual].push(linea)
  }
  for (const k in out) out[k] = out[k].join('\n').trim()
  return out
}
const TEMAS = [
  { seccion: 'horarios', titulo: '🕐 *Horarios*', claves: /horario|\bhora|abren|abris|abre|cierran|cierra|atienden|atencion|abierto|domingo|sabado|feriado/ },
  { seccion: 'direccion', titulo: '📍 *Dirección*', claves: /direcci|donde|ubica|queda|local|llego|llegar|mapa|calle|zona/ },
  { seccion: 'medios de pago', titulo: '💳 *Formas de pago*', claves: /pago|pagar|abonar|abono|tarjeta|efectivo|transfer|mercado ?pago|debito|credito|cuotas/ },
  { seccion: 'precios', titulo: '💲 *Precios*', claves: /precio|cuanto|cuesta|sale |salen|valor|costo|tarifa|cuota mensual|abono mensual|mensualidad/ },
]
const SALUDO = /^(hola+|buenas?|buen dia|buenos dias|buenas tardes|buenas noches|hey|holi|que tal|como va)[\s!.,?¡¿]*$/
function respuestaInstantanea(texto) {
  const t = normalizar(texto)
  const sec = secciones()
  const nombre = (sec['nombre del negocio'] || '').replace(/\s*\(.*\)\s*$/, '') || 'nosotros'
  if (SALUDO.test(t)) return `¡Hola! 👋 Gracias por escribir a *${nombre}*. ¿En qué te puedo ayudar? Podés consultarme horarios, dirección, precios o formas de pago.`
  const partes = []
  for (const tema of TEMAS) {
    if (!tema.claves.test(t)) continue
    const info = sec[tema.seccion]
    if (!info || /todav[ií]a no|no cargad|^\(/i.test(info)) return null // sin datos: que decida Gemini / avise al dueño
    partes.push(`${tema.titulo}\n${info}`)
  }
  if (!partes.length) return null
  // si la pregunta trae algo más que el tema (ej: "¿abren el sábado y hacen clases de prueba?") mejor que responda Gemini
  if (t.split(/\s+/).length > 14) return null
  return partes.join('\n\n')
}

// ---------------------------------------------------------------- bot
let provider
async function avisarDueno(c, pregunta) {
  state.alerts.unshift({ chatId: c.id, name: c.name, question: pregunta, ts: Date.now() })
  state.alerts = state.alerts.slice(0, 50)
  const destino = (process.env.NUMERO_DUENO || '').replace(/\D/g, '') || state.me
  if (!destino) return
  const aviso = `🔔 *El bot no supo responder*\n👤 ${c.name} (${c.id})\n❓ "${pregunta}"\n\nResponde tú desde el panel o desde WhatsApp.`
  try { await provider.sendMessage(destino, aviso, {}) } catch (e) { anotarError('Aviso al dueño', e) }
}

const flujoPrincipal = addKeyword(EVENTS.WELCOME).addAction(async (ctx, { flowDynamic }) => {
  const id = ctx.from
  if (!id || id.includes('@g.us') || id === 'status') return // ignora grupos y estados
  const texto = (ctx.body || '').trim()
  if (!texto || texto.startsWith('_event_')) {
    log(id, 'cliente', '📎 (envió un archivo, audio o sticker)', ctx.pushName)
    return
  }
  log(id, 'cliente', texto, ctx.pushName)
  const c = state.chats[id]
  if (c.paused) return // tú tomaste el control de este chat

  const rapida = respuestaInstantanea(texto)
  if (rapida) {
    log(id, 'bot', rapida)
    try { await flowDynamic(rapida) } catch (e) { anotarError('Enviar respuesta', e) }
    console.log('⚡ Respuesta instantánea (sin Gemini)')
    return
  }
  // muestra "escribiendo..." en el WhatsApp del cliente mientras Gemini piensa
  const jid = ctx.key?.remoteJid || id
  Promise.resolve().then(() => provider.sendPresenceUpdate(jid, 'composing')).catch(() => {})
  const t0 = Date.now()
  try {
    let respuesta = await responder(id)
    console.log(`💬 Respuesta lista en ${((Date.now() - t0) / 1000).toFixed(1)} s`)
    if (!respuesta || respuesta.includes(NO_SE)) {
      respuesta = '¡Buena pregunta! 🙌 Dejame consultarlo y te respondo en un ratito.'
      await avisarDueno(c, texto)
    }
    log(id, 'bot', respuesta)
    try { await flowDynamic(respuesta) } catch (e) { anotarError('Enviar respuesta', e); log(id, 'sistema', '⚠️ No se pudo enviar: ' + e.message) }
  } catch (e) {
    anotarError('Gemini', { message: explicarError(e) })
    log(id, 'sistema', '⚠️ ' + explicarError(e))
    const disculpa = '¡Hola! 🙌 Recibimos tu mensaje, en un ratito te respondemos.'
    try { await flowDynamic(disculpa); log(id, 'bot', disculpa) } catch (e2) { anotarError('Enviar respuesta', e2) }
    await avisarDueno(c, texto + '  (' + explicarError(e) + ')')
  }
})

provider = createProvider(BaileysProvider, { name: 'bot', groupsIgnore: true, readStatus: false, clearAuthOnLogout: true })

provider.on('require_action', async ({ payload }) => {
  if (payload?.qr) {
    state.status = 'qr'
    state.qr = await QRCode.toDataURL(payload.qr, { margin: 1, width: 320 })
    console.log(`📱 Escanea el QR en http://localhost:${PORT}`)
  }
})
provider.on('host', (host) => { state.me = host?.phone || null })
provider.on('message', (m) => console.log(`📩 Mensaje recibido de ${m?.from} (${m?.pushName || ''}): ${String(m?.body || '').slice(0, 60)}`))
provider.on('ready', () => {
  state.status = 'conectado'
  state.qr = null
  console.log('✅ WhatsApp conectado. El bot ya está respondiendo.')
})
provider.on('auth_failure', (info) => {
  state.status = 'desconectado'
  const txt = JSON.stringify(info)
  anotarError('WhatsApp', txt.includes('440')
    ? 'La sesión se abrió en otro bot o computador. Dejá un solo bot abierto y reinicialo.'
    : txt)
})

const { httpServer } = await createBot({ flow: createFlow([flujoPrincipal]), provider, database: new MemoryDB() })
// BuilderBot solo conecta con WhatsApp al iniciar su servidor interno (puerto PORT+1, no hace falta abrirlo)
httpServer(PORT + 1)

// ---------------------------------------------------------------- panel web
const send = (res, code, body, type = 'application/json') => {
  res.writeHead(code, { 'Content-Type': type })
  res.end(typeof body === 'string' ? body : JSON.stringify(body))
}
const readBody = (req) => new Promise((ok) => {
  let d = ''
  req.on('data', (x) => (d += x))
  req.on('end', () => { try { ok(JSON.parse(d || '{}')) } catch { ok({}) } })
})

http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://x')
  try {
    if (req.method === 'GET' && url.pathname === '/') {
      return send(res, 200, fs.readFileSync(path.join(__dirname, 'public', 'index.html'), 'utf8'), 'text/html; charset=utf-8')
    }
    if (req.method === 'GET' && url.pathname === '/api/state') {
      const chats = Object.values(state.chats)
        .map(({ messages, ...c }) => ({ ...c, last: messages.at(-1) }))
        .sort((a, b) => (b.last?.ts || 0) - (a.last?.ts || 0))
      // estado real: si el socket de WhatsApp se cortó, no mostrar "Conectado"
      const ws = provider.vendor?.ws
      const status = state.status === 'conectado' && ws && ws.isOpen === false ? 'reconectando' : state.status
      return send(res, 200, { status, qr: state.qr, me: state.me, chats, alerts: state.alerts, error: ultimoError })
    }
    if (req.method === 'GET' && url.pathname === '/api/chat') {
      const c = state.chats[url.searchParams.get('id')]
      if (!c) return send(res, 404, { error: 'no existe' })
      c.unread = 0
      return send(res, 200, c)
    }
    if (req.method === 'POST' && url.pathname === '/api/send') {
      const { id, text } = await readBody(req)
      if (!id || !text?.trim()) return send(res, 400, { error: 'faltan datos' })
      await provider.sendMessage(id, text.trim(), {})
      log(id, 'yo', text.trim())
      return send(res, 200, { ok: true })
    }
    if (req.method === 'POST' && url.pathname === '/api/pause') {
      const { id, paused } = await readBody(req)
      if (!state.chats[id]) return send(res, 404, { error: 'no existe' })
      state.chats[id].paused = !!paused
      log(id, 'sistema', paused ? '⏸️ Bot pausado: estás respondiendo tú' : '▶️ Bot reactivado')
      return send(res, 200, { ok: true })
    }
    if (req.method === 'POST' && url.pathname === '/api/alerts/clear') {
      state.alerts = []
      return send(res, 200, { ok: true })
    }
    send(res, 404, { error: 'no encontrado' })
  } catch (e) {
    anotarError('Panel', e)
    send(res, 500, { error: e.message })
  }
}).listen(PORT, () => {
  console.log(`\n🟢 Panel abierto en  http://localhost:${PORT}\n`)
})

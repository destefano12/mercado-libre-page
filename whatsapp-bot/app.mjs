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
const MODEL = process.env.GEMINI_MODEL || 'gemini-flash-latest'
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
// Si un modelo está saturado (503/429/500), reintenta y prueba modelos de respaldo
const MODELOS = [...new Set([MODEL, 'gemini-flash-latest', 'gemini-2.5-flash', 'gemini-flash-lite-latest', 'gemini-2.5-flash-lite'])]
const esperar = (ms) => new Promise((r) => setTimeout(r, ms))
const codigo = (e) => Number(e?.status || e?.code || String(e?.message).match(/"code":\s*(\d{3})/)?.[1] || 0)
async function generar(params) {
  let ultimo
  for (const model of MODELOS) {
    for (let intento = 0; intento < 2; intento++) {
      try {
        return await ai.models.generateContent({ ...params, model })
      } catch (e) {
        ultimo = e
        const c = codigo(e)
        if (c === 400 || c === 401 || c === 403) throw e // clave inválida: no sirve reintentar
        if (c === 404) break // modelo no existe: probar el siguiente
        await esperar(1500 * (intento + 1))
      }
    }
  }
  throw ultimo
}
function explicarError(e) {
  const c = codigo(e)
  if (c === 400 || c === 401 || c === 403) return 'La clave de Gemini no es válida. Revisá GEMINI_API_KEY en el archivo .env'
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

  try {
    let respuesta = await responder(id)
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
      return send(res, 200, { status: state.status, qr: state.qr, me: state.me, chats, alerts: state.alerts, error: ultimoError })
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

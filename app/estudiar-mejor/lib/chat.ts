import { crearId } from "./id";

/**
 * Chat del grupo, con dos conexiones posibles:
 *
 * 1. `artifact`: la base de datos que provee la plataforma donde está
 *    publicada la página. No hace falta crear nada; escriben quienes tengan
 *    permiso de edición sobre la página.
 * 2. `supabase`: una base propia, para cuando la página se publica en otro
 *    lado. Se configura con `window.__EM_SUPABASE__ = { url, anonKey }`.
 *
 * Si no hay ninguna, la aplicación sigue funcionando entera sin chat.
 */

export interface MensajeChat {
  id: string;
  autor: string;
  texto: string;
  cuando: string;
}

/**
 * La ficha del grupo que viaja al servidor: con ella, cualquiera cuyo correo
 * figure en la lista abre la página y ya se encuentra adentro del grupo.
 */
export interface GrupoPublicado {
  codigo: string;
  nombre: string;
  materia: string;
  entrega: string;
  /** Los correos de todos, en minúscula: es la llave para reconocer a cada uno. */
  correos: string[];
  integrantes: { nombre: string; email: string; rol: string }[];
  actualizado: string;
}

export interface Chat {
  tipo: "artifact" | "supabase";
  puedeEscribir: boolean;
  enviar: (sala: string, autor: string, texto: string) => Promise<void>;
  escuchar: (sala: string, alRecibir: (mensajes: MensajeChat[]) => void) => () => void;
  publicarGrupo: (grupo: GrupoPublicado) => Promise<void>;
  escucharGrupos: (alRecibir: (grupos: GrupoPublicado[]) => void) => () => void;
}

/** De cada código queda la ficha más nueva, venga de quien venga. */
function masNuevos(fichas: GrupoPublicado[]): GrupoPublicado[] {
  const porCodigo = new Map<string, GrupoPublicado>();
  for (const ficha of fichas) {
    if (!ficha?.codigo) continue;
    const previa = porCodigo.get(ficha.codigo);
    if (!previa || (ficha.actualizado ?? "") > (previa.actualizado ?? "")) porCodigo.set(ficha.codigo, ficha);
  }
  return [...porCodigo.values()];
}

const TOPE_POR_SALA = 200;

function ordenar(mensajes: MensajeChat[]): MensajeChat[] {
  return [...mensajes].sort((a, b) => a.cuando.localeCompare(b.cuando)).slice(-TOPE_POR_SALA);
}

// --------------------------------------------------------------- plataforma

interface ClaudeGlobal {
  use: (nombre: string) => Promise<unknown>;
}

interface DocumentoDb {
  get: () => Promise<{ exists: boolean; data: () => Record<string, unknown> | undefined }>;
  set: (datos: Record<string, unknown>) => Promise<void>;
}

interface ColeccionDb {
  doc: (id: string) => DocumentoDb;
  onSnapshot: (
    siguiente: (snap: { docs: { id: string; data: () => Record<string, unknown> | undefined }[] }) => void,
    error?: (e: { code: string }) => void,
  ) => () => void;
}

interface Db {
  collection: (ruta: string) => ColeccionDb;
}

interface Usuario {
  id: () => Promise<string | null>;
  can: (permiso: string) => Promise<boolean | null>;
}

type BuzonPorSala = Record<string, MensajeChat[]>;

async function conectarPlataforma(): Promise<Chat | null> {
  const claude = (globalThis as { claude?: ClaudeGlobal }).claude;
  if (!claude?.use) return null;

  const db = (await claude.use("db")) as Db | null;
  const usuario = (await claude.use("user")) as Usuario | null;
  if (!db || !usuario) return null;

  const yo = await usuario.id();
  if (!yo) return null;

  const puedeEscribir = (await usuario.can("data.write")) !== false;
  const buzon = db.collection("mensajes");
  const fichero = db.collection("grupos");

  /**
   * Cada uno escribe únicamente su propio documento y lee los de todos: así
   * dos personas escribiendo al mismo tiempo nunca se pisan.
   */
  const enviar = async (sala: string, autor: string, texto: string) => {
    const mio = buzon.doc(yo);
    const actual = await mio.get();
    const porSala = ((actual.data()?.porSala ?? {}) as BuzonPorSala);
    const previos = Array.isArray(porSala[sala]) ? porSala[sala] : [];

    await mio.set({
      porSala: {
        ...porSala,
        [sala]: [...previos, { id: crearId("msj"), autor, texto, cuando: new Date().toISOString() }].slice(-TOPE_POR_SALA),
      },
    });
  };

  const escuchar = (sala: string, alRecibir: (mensajes: MensajeChat[]) => void) =>
    buzon.onSnapshot(
      (snap) => {
        const juntos = snap.docs.flatMap((documento) => {
          const porSala = ((documento.data()?.porSala ?? {}) as BuzonPorSala);
          return Array.isArray(porSala[sala]) ? porSala[sala] : [];
        });
        alRecibir(ordenar(juntos));
      },
      () => alRecibir([]),
    );

  /** Cada uno publica los grupos que armó en su propio documento. */
  const publicarGrupo = async (grupo: GrupoPublicado) => {
    const mio = fichero.doc(yo);
    const actual = await mio.get();
    const porCodigo = (actual.data()?.porCodigo ?? {}) as Record<string, GrupoPublicado>;
    await mio.set({ porCodigo: { ...porCodigo, [grupo.codigo]: grupo } });
  };

  const escucharGrupos = (alRecibir: (grupos: GrupoPublicado[]) => void) =>
    fichero.onSnapshot(
      (snap) => {
        const fichas = snap.docs.flatMap((documento) =>
          Object.values((documento.data()?.porCodigo ?? {}) as Record<string, GrupoPublicado>),
        );
        alRecibir(masNuevos(fichas));
      },
      () => alRecibir([]),
    );

  return { tipo: "artifact", puedeEscribir, enviar, escuchar, publicarGrupo, escucharGrupos };
}

// ----------------------------------------------------------------- supabase

interface ConfiguracionSupabase {
  url: string;
  anonKey: string;
  tabla?: string;
  tablaGrupos?: string;
}

function conectarSupabase(): Chat | null {
  const configuracion = (globalThis as { __EM_SUPABASE__?: ConfiguracionSupabase }).__EM_SUPABASE__;
  if (!configuracion?.url || !configuracion?.anonKey) return null;

  const tabla = configuracion.tabla ?? "mensajes";
  const base = `${configuracion.url.replace(/\/$/, "")}/rest/v1/${tabla}`;
  const cabeceras = {
    apikey: configuracion.anonKey,
    Authorization: `Bearer ${configuracion.anonKey}`,
    "Content-Type": "application/json",
  };

  const enviar = async (sala: string, autor: string, texto: string) => {
    const respuesta = await fetch(base, {
      method: "POST",
      headers: { ...cabeceras, Prefer: "return=minimal" },
      body: JSON.stringify({ sala, autor, texto }),
    });
    if (!respuesta.ok) throw new Error(`No se pudo enviar el mensaje (${respuesta.status}).`);
  };

  /** Sin librería de tiempo real: se consulta cada pocos segundos. */
  const escuchar = (sala: string, alRecibir: (mensajes: MensajeChat[]) => void) => {
    let vivo = true;

    const traer = async () => {
      try {
        const consulta = `${base}?sala=eq.${encodeURIComponent(sala)}&order=creado_en.asc&limit=${TOPE_POR_SALA}`;
        const respuesta = await fetch(consulta, { headers: cabeceras });
        if (!respuesta.ok || !vivo) return;
        const filas = (await respuesta.json()) as { id: string; autor: string; texto: string; creado_en: string }[];
        alRecibir(
          ordenar(filas.map((fila) => ({ id: String(fila.id), autor: fila.autor, texto: fila.texto, cuando: fila.creado_en }))),
        );
      } catch {
        // Una consulta que falla no rompe el chat: se reintenta en la próxima.
      }
    };

    void traer();
    const reloj = window.setInterval(() => void traer(), 3000);
    return () => {
      vivo = false;
      window.clearInterval(reloj);
    };
  };

  const tablaGrupos = `${configuracion.url.replace(/\/$/, "")}/rest/v1/${configuracion.tablaGrupos ?? "grupos"}`;

  const publicarGrupo = async (grupo: GrupoPublicado) => {
    const respuesta = await fetch(tablaGrupos, {
      method: "POST",
      headers: { ...cabeceras, Prefer: "resolution=merge-duplicates,return=minimal" },
      body: JSON.stringify({ codigo: grupo.codigo, datos: grupo, actualizado: grupo.actualizado }),
    });
    if (!respuesta.ok) throw new Error(`No se pudo publicar el grupo (${respuesta.status}).`);
  };

  const escucharGrupos = (alRecibir: (grupos: GrupoPublicado[]) => void) => {
    let vivo = true;

    const traer = async () => {
      try {
        const respuesta = await fetch(`${tablaGrupos}?select=datos&limit=500`, { headers: cabeceras });
        if (!respuesta.ok || !vivo) return;
        const filas = (await respuesta.json()) as { datos: GrupoPublicado }[];
        alRecibir(masNuevos(filas.map((fila) => fila.datos).filter(Boolean)));
      } catch {
        // Una consulta que falla no rompe nada: se reintenta en la próxima.
      }
    };

    void traer();
    const reloj = window.setInterval(() => void traer(), 8000);
    return () => {
      vivo = false;
      window.clearInterval(reloj);
    };
  };

  return { tipo: "supabase", puedeEscribir: true, enviar, escuchar, publicarGrupo, escucharGrupos };
}

let conexion: Promise<Chat | null> | null = null;

export function conectarChat(): Promise<Chat | null> {
  if (conexion) return conexion;
  conexion = (async () => conectarSupabase() ?? (await conectarPlataforma()))();
  return conexion;
}

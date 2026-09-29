import { getDatabase, type MarketplaceDatabase } from "./auth";

/**
 * Servidor de los trabajos grupales de Estudiar Mejor.
 *
 * Usa la misma base del proyecto (Cloudflare D1), así el chat y los grupos
 * funcionan sin contratar nada ni configurar claves: donde se publique la
 * aplicación completa, el servidor ya está.
 */

export const TOPE_MENSAJES = 200;
const LARGO_TEXTO = 1000;
const LARGO_NOMBRE = 80;

export interface GrupoGuardado {
  codigo: string;
  nombre: string;
  materia: string;
  entrega: string;
  correos: string[];
  integrantes: { nombre: string; email: string; rol: string }[];
  actualizado: string;
}

/** Se permite llamar desde la copia estática publicada en otro dominio. */
export const CABECERAS = {
  "cache-control": "no-store",
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "content-type",
  "access-control-allow-methods": "GET,POST,OPTIONS",
};

export function json(datos: unknown, estado = 200) {
  return Response.json(datos, { status: estado, headers: CABECERAS });
}

export function recortar(valor: unknown, largo: number): string {
  return typeof valor === "string" ? valor.trim().slice(0, largo) : "";
}

export function codigoValido(codigo: unknown): string {
  const limpio = recortar(codigo, 12).toUpperCase();
  return /^[A-Z0-9]{4,12}$/.test(limpio) ? limpio : "";
}

export function correoValido(correo: unknown): string {
  const limpio = recortar(correo, 120).toLowerCase();
  return /^[\w.+-]+@[\w-]+\.[\w.-]+$/.test(limpio) ? limpio : "";
}

export function textoDeMensaje(valor: unknown): string {
  return recortar(valor, LARGO_TEXTO);
}

export function nombreDePersona(valor: unknown): string {
  return recortar(valor, LARGO_NOMBRE);
}

let preparada = false;

export async function base(): Promise<MarketplaceDatabase> {
  const conexion = await getDatabase();
  if (!preparada) {
    await conexion.batch([
      conexion.prepare(
        `CREATE TABLE IF NOT EXISTS estudiar_grupos (
          codigo TEXT PRIMARY KEY NOT NULL,
          nombre TEXT NOT NULL,
          materia TEXT NOT NULL,
          entrega TEXT NOT NULL,
          correos TEXT NOT NULL,
          integrantes TEXT NOT NULL,
          actualizado TEXT NOT NULL
        )`,
      ),
      conexion.prepare(
        `CREATE TABLE IF NOT EXISTS estudiar_mensajes (
          id TEXT PRIMARY KEY NOT NULL,
          sala TEXT NOT NULL,
          autor TEXT NOT NULL,
          texto TEXT NOT NULL,
          creado_en TEXT NOT NULL
        )`,
      ),
      conexion.prepare(
        "CREATE INDEX IF NOT EXISTS estudiar_mensajes_sala_idx ON estudiar_mensajes(sala, creado_en)",
      ),
    ]);
    preparada = true;
  }
  return conexion;
}

interface FilaGrupo {
  codigo: string;
  nombre: string;
  materia: string;
  entrega: string;
  correos: string;
  integrantes: string;
  actualizado: string;
}

export function armarGrupo(fila: FilaGrupo): GrupoGuardado {
  const leer = <T>(texto: string, porDefecto: T): T => {
    try {
      return JSON.parse(texto) as T;
    } catch {
      return porDefecto;
    }
  };

  return {
    codigo: fila.codigo,
    nombre: fila.nombre,
    materia: fila.materia,
    entrega: fila.entrega,
    correos: leer<string[]>(fila.correos, []),
    integrantes: leer<GrupoGuardado["integrantes"]>(fila.integrantes, []),
    actualizado: fila.actualizado,
  };
}

export type { FilaGrupo };

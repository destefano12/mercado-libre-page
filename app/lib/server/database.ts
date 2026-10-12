import type { Client, InStatement, InValue } from "@libsql/client";

/**
 * Acceso a la base del proyecto, sin importar donde este publicado.
 *
 * Todas las rutas estan escritas contra la interfaz de Cloudflare D1
 * (`prepare` / `bind` / `first` / `all` / `run` / `batch`). Este archivo es el
 * unico que sabe que base hay detras:
 *
 * - En Cloudflare, `env.DB` es D1 y se devuelve tal cual.
 * - En Netlify o en cualquier Node, se usa Turso (libSQL) envuelto en un
 *   adaptador con la misma forma. libSQL es SQLite, igual que D1, asi que las
 *   consultas no cambian ni una coma.
 *
 * Para libSQL hacen falta `TURSO_DATABASE_URL` y, salvo en una base local,
 * `TURSO_AUTH_TOKEN`.
 */

export interface Sentencia {
  bind(...valores: unknown[]): Sentencia;
  first<T = Record<string, unknown>>(): Promise<T | null>;
  all<T = Record<string, unknown>>(): Promise<{ results: T[] }>;
  run(): Promise<unknown>;
}

export interface BaseDatos {
  prepare(sql: string): Sentencia;
  batch(sentencias: Sentencia[]): Promise<unknown[]>;
}

/** libSQL puede devolver enteros como bigint; D1 siempre da number. */
function normalizar(valor: unknown) {
  return typeof valor === "bigint" ? Number(valor) : valor;
}

class SentenciaLibsql implements Sentencia {
  constructor(
    private readonly cliente: Client,
    readonly sql: string,
    readonly args: InValue[] = [],
  ) {}

  bind(...valores: unknown[]): Sentencia {
    return new SentenciaLibsql(this.cliente, this.sql, valores as InValue[]);
  }

  async all<T>(): Promise<{ results: T[] }> {
    const resultado = await this.cliente.execute({ sql: this.sql, args: this.args });
    const results = resultado.rows.map((fila) => {
      const objeto: Record<string, unknown> = {};
      resultado.columns.forEach((columna, indice) => {
        objeto[columna] = normalizar(fila[indice]);
      });
      return objeto as T;
    });
    return { results };
  }

  async first<T>(): Promise<T | null> {
    const { results } = await this.all<T>();
    return results[0] ?? null;
  }

  async run(): Promise<unknown> {
    return this.cliente.execute({ sql: this.sql, args: this.args });
  }
}

class BaseLibsql implements BaseDatos {
  constructor(private readonly cliente: Client) {}

  prepare(sql: string): Sentencia {
    return new SentenciaLibsql(this.cliente, sql);
  }

  /** Como en D1, el lote corre entero dentro de una transaccion. */
  async batch(sentencias: Sentencia[]): Promise<unknown[]> {
    const lote: InStatement[] = sentencias.map((sentencia) => {
      if (!(sentencia instanceof SentenciaLibsql)) {
        throw new Error("batch() recibio una sentencia de otra base");
      }
      return { sql: sentencia.sql, args: sentencia.args };
    });
    return this.cliente.batch(lote, "write");
  }
}

async function baseCloudflare(): Promise<BaseDatos | null> {
  try {
    const { env } = await import("cloudflare:workers");
    return ((env as { DB?: BaseDatos }).DB) ?? null;
  } catch {
    return null;
  }
}

// Un cliente por proceso: las funciones de Netlify reutilizan la instancia
// mientras siguen calientes.
let libsql: Promise<BaseDatos> | null = null;

function baseLibsql(): Promise<BaseDatos> {
  libsql ??= (async () => {
    const url = process.env.TURSO_DATABASE_URL?.trim();
    if (!url) {
      throw new Error(
        "No hay base de datos: falta TURSO_DATABASE_URL (y TURSO_AUTH_TOKEN) en las variables del sitio",
      );
    }
    // La variante web habla con Turso solo por fetch, sin binarios nativos:
    // es la que conviene dentro de una funcion. La de Node se usa unicamente
    // para una base en un archivo local (`file:`), util para probar.
    const { createClient } = url.startsWith("file:")
      ? await import("@libsql/client")
      : await import("@libsql/client/web");
    return new BaseLibsql(
      createClient({ url, authToken: process.env.TURSO_AUTH_TOKEN?.trim(), intMode: "number" }),
    );
  })();
  // Si falla (por ejemplo, faltan variables) se vuelve a intentar en el
  // proximo pedido en lugar de quedar roto hasta que la funcion se enfrie.
  libsql.catch(() => {
    libsql = null;
  });
  return libsql;
}

export async function getDatabase(): Promise<BaseDatos> {
  return (await baseCloudflare()) ?? baseLibsql();
}

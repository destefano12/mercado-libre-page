import {
  base,
  CABECERAS,
  codigoValido,
  json,
  nombreDePersona,
  textoDeMensaje,
  TOPE_MENSAJES,
} from "../../../lib/server/estudiar";

interface FilaMensaje {
  id: string;
  autor: string;
  texto: string;
  creado_en: string;
}

export function OPTIONS() {
  return new Response(null, { status: 204, headers: CABECERAS });
}

/** Los mensajes de una sala, del más viejo al más nuevo. */
export async function GET(request: Request) {
  const sala = codigoValido(new URL(request.url).searchParams.get("sala"));
  if (!sala) return json({ error: "Sala inválida." }, 400);

  try {
    const conexion = await base();
    const filas = (await conexion
      .prepare(
        "SELECT id, autor, texto, creado_en FROM estudiar_mensajes WHERE sala = ? ORDER BY creado_en DESC LIMIT ?",
      )
      .bind(sala, TOPE_MENSAJES)
      .all()) as { results?: FilaMensaje[] };

    const mensajes = (filas.results ?? [])
      .map((fila: FilaMensaje) => ({ id: fila.id, autor: fila.autor, texto: fila.texto, cuando: fila.creado_en }))
      .reverse();

    return json({ mensajes });
  } catch {
    return json({ error: "La base no está disponible." }, 503);
  }
}

export async function POST(request: Request) {
  let cuerpo: { sala?: string; autor?: string; texto?: string };
  try {
    cuerpo = (await request.json()) as typeof cuerpo;
  } catch {
    return json({ error: "Cuerpo inválido." }, 400);
  }

  const sala = codigoValido(cuerpo.sala);
  const texto = textoDeMensaje(cuerpo.texto);
  const autor = nombreDePersona(cuerpo.autor) || "Alguien";
  if (!sala || !texto) return json({ error: "Falta la sala o el texto." }, 400);

  const mensaje = { id: crypto.randomUUID(), autor, texto, cuando: new Date().toISOString() };

  try {
    const conexion = await base();
    await conexion
      .prepare("INSERT INTO estudiar_mensajes (id, sala, autor, texto, creado_en) VALUES (?, ?, ?, ?, ?)")
      .bind(mensaje.id, sala, mensaje.autor, mensaje.texto, mensaje.cuando)
      .run();

    // La sala guarda sólo los últimos mensajes: es un chat de trabajo, no un archivo.
    await conexion
      .prepare(
        `DELETE FROM estudiar_mensajes WHERE sala = ? AND id NOT IN (
           SELECT id FROM estudiar_mensajes WHERE sala = ? ORDER BY creado_en DESC LIMIT ?
         )`,
      )
      .bind(sala, sala, TOPE_MENSAJES)
      .run();

    return json({ mensaje });
  } catch {
    return json({ error: "No se pudo enviar el mensaje." }, 503);
  }
}

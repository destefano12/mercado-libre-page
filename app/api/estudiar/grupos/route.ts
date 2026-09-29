import {
  armarGrupo,
  base,
  CABECERAS,
  codigoValido,
  correoValido,
  json,
  nombreDePersona,
  recortar,
  type FilaGrupo,
  type GrupoGuardado,
} from "../../../lib/server/estudiar";

export function OPTIONS() {
  return new Response(null, { status: 204, headers: CABECERAS });
}

/**
 * Con `codigo`, la ficha de un grupo: es lo que ve quien abre una invitación
 * antes de decidir si se suma. Con `correo`, todos los grupos donde figura esa
 * persona: por eso, al entrar con su correo, el trabajo ya le aparece.
 */
export async function GET(request: Request) {
  const parametros = new URL(request.url).searchParams;
  const codigo = codigoValido(parametros.get("codigo"));
  const correo = correoValido(parametros.get("correo"));

  try {
    const conexion = await base();

    if (codigo) {
      const fila = (await conexion
        .prepare("SELECT * FROM estudiar_grupos WHERE codigo = ?")
        .bind(codigo)
        .first()) as FilaGrupo | null;
      return json({ grupo: fila ? armarGrupo(fila) : null });
    }

    if (correo) {
      const filas = (await conexion
        .prepare("SELECT * FROM estudiar_grupos WHERE correos LIKE ? ORDER BY actualizado DESC LIMIT 50")
        .bind(`%"${correo}"%`)
        .all()) as { results?: FilaGrupo[] };
      return json({ grupos: (filas.results ?? []).map(armarGrupo) });
    }

    return json({ error: "Falta el código o el correo." }, 400);
  } catch {
    return json({ error: "La base no está disponible." }, 503);
  }
}

/** Guarda o actualiza la ficha del grupo. Gana siempre la versión más nueva. */
export async function POST(request: Request) {
  let cuerpo: { grupo?: Partial<GrupoGuardado> };
  try {
    cuerpo = (await request.json()) as typeof cuerpo;
  } catch {
    return json({ error: "Cuerpo inválido." }, 400);
  }

  const entrada = cuerpo.grupo;
  const codigo = codigoValido(entrada?.codigo);
  if (!entrada || !codigo) return json({ error: "Código inválido." }, 400);

  const correos = (Array.isArray(entrada.correos) ? entrada.correos : [])
    .map(correoValido)
    .filter(Boolean)
    .slice(0, 30);

  const integrantes = (Array.isArray(entrada.integrantes) ? entrada.integrantes : [])
    .slice(0, 30)
    .map((integrante) => ({
      nombre: nombreDePersona(integrante?.nombre),
      email: correoValido(integrante?.email),
      rol: nombreDePersona(integrante?.rol),
    }));

  const ficha: GrupoGuardado = {
    codigo,
    nombre: recortar(entrada.nombre, 120) || `Grupo ${codigo}`,
    materia: recortar(entrada.materia, 60) || "General",
    entrega: recortar(entrada.entrega, 10),
    correos,
    integrantes,
    actualizado: new Date().toISOString(),
  };

  try {
    const conexion = await base();
    await conexion
      .prepare(
        `INSERT INTO estudiar_grupos (codigo, nombre, materia, entrega, correos, integrantes, actualizado)
         VALUES (?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(codigo) DO UPDATE SET
           nombre = excluded.nombre,
           materia = excluded.materia,
           entrega = excluded.entrega,
           correos = excluded.correos,
           integrantes = excluded.integrantes,
           actualizado = excluded.actualizado`,
      )
      .bind(
        ficha.codigo,
        ficha.nombre,
        ficha.materia,
        ficha.entrega,
        JSON.stringify(ficha.correos),
        JSON.stringify(ficha.integrantes),
        ficha.actualizado,
      )
      .run();

    return json({ grupo: ficha });
  } catch {
    return json({ error: "No se pudo guardar el grupo." }, 503);
  }
}

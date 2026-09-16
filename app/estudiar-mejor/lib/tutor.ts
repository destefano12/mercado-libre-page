import { hoyClave, sumarDias } from "./fechas";
import { crearId } from "./id";
import { analizarMaterial, mayuscula, recortar, terminosClave, tokens } from "./texto";
import type { Material, RegistroError, TarjetaTutor, TipoTarjeta } from "./tipos";

/**
 * Generador socrático: convierte el material del alumno en preguntas.
 * Nunca guarda ni muestra la respuesta: sólo guarda términos clave ocultos
 * para poder decirle "te falta una idea", jamás cuál.
 */

export type Calificacion = "no-pude" | "dude" | "lo-tenia";

const PISTAS_POR_TIPO: Record<TipoTarjeta, (foco: string) => string[]> = {
  definicion: (foco) => [
    `Arrancá por la categoría: “${foco} es un/una…”. Todavía no expliques para qué sirve.`,
    `Volvé al material y buscá dónde aparece “${foco}” por primera vez. Leelo, tapalo y contalo de memoria.`,
    "Armá la respuesta en tres partes: qué es, para qué sirve y un ejemplo tuyo.",
  ],
  causa: (foco) => [
    `Separá dos cosas: qué pasa (el efecto) y por qué pasa (la causa) en “${foco}”.`,
    "Probá decirlo con la fórmula: “pasa X porque antes ocurrió Y”. Si no te cierra, te falta un eslabón.",
    "Preguntate qué pasaría si la causa no estuviera. Si el efecto sigue igual, esa no era la causa.",
  ],
  proceso: (foco) => [
    `Escribí los pasos de “${foco}” en cualquier orden y recién después numeralos.`,
    "Fijate qué paso no podría ocurrir antes que otro: eso te ordena la secuencia.",
    "Contá el proceso como si fuera una receta, sin saltear ningún paso intermedio.",
  ],
  dato: (foco) => [
    `No arranques por el número: primero decí de qué habla el dato en “${foco}”.`,
    "Si no te acordás el valor exacto, arriesgá el orden de magnitud y después verificá.",
    "Preguntate qué cambiaría en el tema si ese dato fuera el doble o la mitad.",
  ],
  enumeracion: (foco) => [
    `Decí primero cuántos elementos son en “${foco}” y después intentá nombrarlos.`,
    "Agrupá los que se parecen entre sí: es más fácil recordar 2 grupos que 6 elementos sueltos.",
    "Inventá una palabra con las iniciales para acordarte la lista completa.",
  ],
  transferencia: (foco) => [
    `Pensá en algo de tu vida cotidiana donde aparezca “${foco}”.`,
    "Si el ejemplo te sale del material, no cuenta: tiene que ser uno tuyo.",
    "Probá explicárselo a alguien que no cursa la materia y mirá dónde te interrumpe.",
  ],
};

function repasoInicial(hoy: string) {
  return { intervalo: 0, proxima: hoy, facilidad: 2.2, aciertos: 0, fallos: 0 };
}

function clavesDe(texto: string, cantidad = 4): string[] {
  const terminos = terminosClave(texto, cantidad * 2);
  if (terminos.length >= cantidad) return terminos.slice(0, cantidad);
  return [...terminos, ...tokens(texto).filter((palabra) => palabra.length > 5)].slice(0, cantidad);
}

/** Arma las preguntas de un material recién cargado. */
export function generarTarjetas(material: Material, maximo = 12): TarjetaTutor[] {
  const analisis = analizarMaterial(material.texto);
  const hoy = hoyClave();
  const tarjetas: TarjetaTutor[] = [];
  const focosUsados = new Set<string>();

  const agregar = (tipo: TipoTarjeta, foco: string, enunciado: string, fuente: string) => {
    const clave = `${tipo}:${foco.toLowerCase()}`;
    if (focosUsados.has(clave) || tarjetas.length >= maximo) return;
    focosUsados.add(clave);
    tarjetas.push({
      id: crearId("tarjeta"),
      temaId: material.temaId,
      materialId: material.id,
      tipo,
      enunciado,
      foco,
      pistas: PISTAS_POR_TIPO[tipo](foco),
      clave: clavesDe(fuente),
      creadaEn: new Date().toISOString(),
      repaso: repasoInicial(hoy),
    });
  };

  analisis.definiciones.slice(0, 5).forEach((definicion) => {
    agregar(
      "definicion",
      definicion.termino,
      `¿Cómo le explicarías a alguien de tu curso qué es “${definicion.termino}”, sin mirar el material?`,
      definicion.cuerpo,
    );
  });

  analisis.causas.slice(0, 4).forEach((causa) => {
    const foco = terminosClave(causa.oracion, 1)[0] ?? "este punto";
    agregar(
      "causa",
      foco,
      `El material conecta dos ideas con “${causa.conector}”. ¿Cuál es la causa y cuál la consecuencia en el caso de “${foco}”?`,
      causa.oracion,
    );
  });

  analisis.procesos.slice(0, 3).forEach((proceso) => {
    const foco = terminosClave(proceso.oracion, 1)[0] ?? "este proceso";
    agregar(
      "proceso",
      foco,
      `¿En qué orden ocurren los pasos de “${foco}”? Enumeralos de memoria y recién después chequeá.`,
      proceso.oracion,
    );
  });

  analisis.datos.slice(0, 3).forEach((dato) => {
    const foco = terminosClave(dato.oracion, 1)[0] ?? "este dato";
    agregar(
      "dato",
      foco,
      `Hay un dato numérico ligado a “${foco}”. ¿Cuál es y por qué el material lo menciona?`,
      dato.oracion,
    );
  });

  analisis.enumeraciones.slice(0, 3).forEach((lista) => {
    const foco = terminosClave(lista.oracion, 1)[0] ?? "esta lista";
    agregar(
      "enumeracion",
      foco,
      `El material enumera varios elementos al hablar de “${foco}”. ¿Cuántos son y cuáles podés nombrar sin mirar?`,
      lista.oracion,
    );
  });

  analisis.terminos.slice(0, 4).forEach((termino) => {
    agregar(
      "transferencia",
      termino,
      `¿Dónde aparece “${termino}” fuera de la escuela? Dame un ejemplo propio, no uno del material.`,
      termino,
    );
  });

  return tarjetas;
}

/** Repaso espaciado: el intervalo crece cuando lo tenés y se reinicia cuando no. */
export function calificarTarjeta(tarjeta: TarjetaTutor, calificacion: Calificacion): TarjetaTutor {
  const hoy = hoyClave();
  const repaso = { ...tarjeta.repaso, ultimaVez: hoy };

  if (calificacion === "lo-tenia") {
    repaso.facilidad = Math.min(2.8, repaso.facilidad + 0.12);
    repaso.intervalo = repaso.intervalo === 0 ? 1 : Math.max(1, Math.round(repaso.intervalo * repaso.facilidad));
    repaso.aciertos += 1;
  } else if (calificacion === "dude") {
    repaso.facilidad = Math.max(1.3, repaso.facilidad - 0.08);
    repaso.intervalo = repaso.intervalo <= 1 ? 1 : Math.max(1, Math.round(repaso.intervalo * 0.6));
  } else {
    repaso.facilidad = Math.max(1.3, repaso.facilidad - 0.2);
    repaso.intervalo = 0;
    repaso.fallos += 1;
  }

  repaso.proxima = sumarDias(hoy, Math.max(repaso.intervalo, 0));
  return { ...tarjeta, repaso };
}

export interface ColaRepaso {
  pendientes: TarjetaTutor[];
  proximas: TarjetaTutor[];
}

/**
 * Cola del día. Las tarjetas de temas con errores abiertos van primero:
 * así el registro de errores se reinyecta en cada repaso.
 */
export function armarCola(
  tarjetas: TarjetaTutor[],
  errores: RegistroError[],
  temaId: string | "todos",
): ColaRepaso {
  const hoy = hoyClave();
  const temasConError = new Set(errores.filter((error) => !error.resuelto).map((error) => error.temaId));
  const filtradas = tarjetas.filter((tarjeta) => temaId === "todos" || tarjeta.temaId === temaId);

  const peso = (tarjeta: TarjetaTutor) =>
    (temasConError.has(tarjeta.temaId) ? 100 : 0) + tarjeta.repaso.fallos * 10 - tarjeta.repaso.aciertos;

  const pendientes = filtradas
    .filter((tarjeta) => tarjeta.repaso.proxima <= hoy)
    .sort((a, b) => peso(b) - peso(a));

  const proximas = filtradas
    .filter((tarjeta) => tarjeta.repaso.proxima > hoy)
    .sort((a, b) => a.repaso.proxima.localeCompare(b.repaso.proxima));

  return { pendientes, proximas };
}

/** Preguntas de reinyección construidas a partir de los errores abiertos. */
export function preguntaDeError(error: RegistroError): string {
  const causas: Record<RegistroError["causa"], string> = {
    "no-entendi": "¿Qué parte del concepto no te cerraba la última vez? Empezá por ahí.",
    distraccion: "¿Qué vas a hacer distinto esta vez para no volver a saltear el paso?",
    consigna: "Leé la consigna y subrayá el verbo. ¿Qué te está pidiendo exactamente?",
    tiempo: "¿Cuánto tiempo le vas a dar a esta parte antes de pasar a la siguiente?",
    calculo: "¿En qué paso del cálculo se te escapó? Rehacelo en voz alta.",
    memoria: "¿Con qué truco propio podrías acordarte esto la próxima?",
  };
  return `${mayuscula(recortar(error.titulo, 90))} — ${causas[error.causa]}`;
}

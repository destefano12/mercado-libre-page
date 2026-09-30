import { detectarMateria } from "./esquemas";
import { normalizar } from "./texto";
import { verboDeLaConsigna, type VerboConsigna } from "./verbos";

/**
 * Desarmar un ejercicio, sin resolverlo.
 *
 * El momento más difícil de la tarea no es hacerla: es el minuto en que tenés
 * la consigna adelante y no sabés por dónde empezar. Esto da el andamio —qué
 * preguntarte, en qué orden— y te obliga a escribir vos cada paso. Al final te
 * queda tu propio procedimiento escrito, que es con lo que vas a resolver.
 *
 * Ningún paso contiene la respuesta, ni puede contenerla: las preguntas son
 * sobre tu ejercicio, que sólo vos tenés.
 */

export type FamiliaPaso = "calculo" | "texto" | "practico";

export interface Paso {
  id: string;
  titulo: string;
  /** Lo que el alumno tiene que escribir. */
  pide: string;
  /** Cómo hacerlo. Nunca qué contestar. */
  ayuda: string;
  /** Cuántos caracteres hacen falta para que el paso cuente como hecho. */
  minimo: number;
}

export interface Protocolo {
  familia: FamiliaPaso;
  materia: string | null;
  verbo: VerboConsigna | null;
  pasos: Paso[];
  /** Maneras de controlar el resultado uno mismo, sin que nadie lo corrija. */
  verificacion: string[];
}

const PASOS_CALCULO: Paso[] = [
  {
    id: "piden",
    titulo: "Qué te piden",
    pide: "Escribí con tus palabras qué hay que encontrar. Una sola cosa, en una oración.",
    ayuda: "Si no podés decirlo en una oración, la consigna tiene más de una parte: numerálas y hacé una por vez.",
    minimo: 15,
  },
  {
    id: "datos",
    titulo: "Qué datos tenés",
    pide: "Listá todos los datos con su unidad, uno por renglón.",
    ayuda: "Escribí también los datos escondidos: «parte del reposo» es velocidad inicial cero, «el doble» es una relación.",
    minimo: 10,
  },
  {
    id: "falta",
    titulo: "Qué te falta",
    pide: "¿Qué necesitás y no te dieron? ¿De dónde puede salir?",
    ayuda: "Casi siempre sale de otra fórmula, de una equivalencia de unidades o de un dato que se deduce de otro.",
    minimo: 10,
  },
  {
    id: "relacion",
    titulo: "Qué conecta los datos con lo que buscás",
    pide: "Escribí la fórmula, la propiedad o la relación que une lo que tenés con lo que te piden.",
    ayuda: "Si hay varias candidatas, elegí la que contenga la incógnita y la mayor cantidad de datos que ya tenés.",
    minimo: 5,
  },
  {
    id: "estimacion",
    titulo: "Cuánto te parece que va a dar",
    pide: "Antes de calcular: ¿grande o chico? ¿positivo o negativo? ¿de qué orden?",
    ayuda: "Este paso parece al pedo y es el que salva. Si después el resultado se va lejos de tu estimación, hay un error.",
    minimo: 10,
  },
  {
    id: "primerpaso",
    titulo: "El primer renglón",
    pide: "Escribí sólo el primer paso del procedimiento, no todo.",
    ayuda: "Casi siempre es despejar la incógnita o pasar todo a las mismas unidades. Uno solo: después seguís en la carpeta.",
    minimo: 10,
  },
];

const PASOS_TEXTO: Paso[] = [
  {
    id: "piden",
    titulo: "Qué te piden exactamente",
    pide: "Reescribí la consigna con tus palabras, sin copiarla.",
    ayuda: "Si al reescribirla te sale igual que la original, todavía no la entendiste: leela de nuevo y buscá el verbo.",
    minimo: 20,
  },
  {
    id: "fuente",
    titulo: "De dónde sale la información",
    pide: "¿Qué parte del apunte, del libro o de la clase tenés que usar? Escribí páginas o títulos.",
    ayuda: "Si no sabés de dónde sale, eso es lo primero que hay que resolver, antes de escribir una sola línea.",
    minimo: 10,
  },
  {
    id: "ideas",
    titulo: "Las ideas que no pueden faltar",
    pide: "Anotá en punteo las ideas que tu respuesta tiene que contener. Sin desarrollar, sólo la lista.",
    ayuda: "Tres o cuatro alcanzan. Si ponés diez, la respuesta va a ser un revoltijo.",
    minimo: 20,
  },
  {
    id: "orden",
    titulo: "En qué orden van",
    pide: "Numerá esas ideas en el orden en que las vas a escribir, y decí por qué ese orden.",
    ayuda: "El orden es parte de la respuesta: cronológico, de causa a consecuencia, de lo general a lo particular.",
    minimo: 15,
  },
  {
    id: "primera",
    titulo: "La primera oración",
    pide: "Escribí sólo la oración con la que arranca tu respuesta.",
    ayuda: "Que ya diga de qué vas a hablar. Empezar con «bueno, el tema es muy importante» es perder el primer renglón.",
    minimo: 20,
  },
];

const PASOS_PRACTICO: Paso[] = [
  {
    id: "piden",
    titulo: "Qué hay que entregar",
    pide: "Escribí qué es lo que se entrega y en qué formato.",
    ayuda: "Maqueta, informe, lámina, exposición: cambia todo el trabajo según cuál sea.",
    minimo: 15,
  },
  {
    id: "partes",
    titulo: "En qué partes se divide",
    pide: "Listá las partes del trabajo, una por renglón.",
    ayuda: "Si una parte te lleva más de dos días, es más de una parte: partila.",
    minimo: 20,
  },
  {
    id: "primero",
    titulo: "Qué va primero",
    pide: "¿Cuál de esas partes no puede esperar a las otras? Esa empieza.",
    ayuda: "Suele ser la que los demás necesitan para arrancar: buscar el material, elegir el tema.",
    minimo: 10,
  },
  {
    id: "hoy",
    titulo: "Qué hacés hoy",
    pide: "Escribí la primera cosa concreta que vas a hacer hoy, que entre en media hora.",
    ayuda: "«Estudiar» no es una tarea. «Buscar tres fuentes y anotar el título de cada una» sí.",
    minimo: 15,
  },
];

const VERIFICACION_CALCULO = [
  "Reemplazá tu resultado en la relación original: los dos lados tienen que dar lo mismo.",
  "Mirá las unidades: si te queda una que no corresponde, el error está en el despeje.",
  "Comparalo con tu estimación. Si se fue lejos, revisá los signos primero.",
];

const VERIFICACION_TEXTO = [
  "Leé tu respuesta y subrayá dónde contestás el verbo de la consigna. Si no lo encontrás, no está.",
  "Tapá la consigna y leé tu respuesta sola: ¿se entiende de qué hablás?",
  "Contá tus ideas: ¿están todas las de tu lista? ¿Metiste alguna que no aportaba?",
];

const VERIFICACION_PRACTICO = [
  "Poné las partes al lado de la fecha de entrega: ¿entran?",
  "Preguntate qué pasa si una parte se atrasa dos días. Si se cae todo, esa parte necesita ayuda.",
  "Mirá si lo que vas a entregar se parece a lo que pedía la consigna, no a lo que te resultó más fácil.",
];

/** Qué clase de ejercicio es, por la materia y por lo que la consigna pide. */
function familiaDe(consigna: string, materia: string | null): FamiliaPaso {
  const plano = normalizar(consigna);

  if (/trabajo practico|maqueta|lamina|afiche|exposicion|informe grupal|presentacion|tp\b/.test(plano)) {
    return "practico";
  }
  if (/calcula|resolve|ecuacion|despeja|hall[ae]|cuanto (vale|mide|da)|balancea|demostra|grafica/.test(plano)) {
    return "calculo";
  }
  if (materia && ["Matemática", "Física", "Química"].includes(materia)) return "calculo";

  return "texto";
}

export function armarProtocolo(consigna: string, anio: number): Protocolo {
  const materia = detectarMateria(consigna)?.nombre ?? null;
  const familia = familiaDe(consigna, materia);
  const verbo = verboDeLaConsigna(consigna);

  const base =
    familia === "calculo" ? PASOS_CALCULO : familia === "practico" ? PASOS_PRACTICO : PASOS_TEXTO;

  // En los primeros años se saca la estimación: pide una intuición que todavía
  // se está formando, y de arranque estorba más de lo que ayuda.
  const pasos = anio <= 2 ? base.filter((paso) => paso.id !== "estimacion") : base;

  return {
    familia,
    materia,
    verbo,
    pasos,
    verificacion:
      familia === "calculo"
        ? VERIFICACION_CALCULO
        : familia === "practico"
          ? VERIFICACION_PRACTICO
          : VERIFICACION_TEXTO,
  };
}

/**
 * Señales de que lo escrito no es trabajo propio todavía: copiar la consigna,
 * o escribir que no se sabe. No se bloquea nada; se devuelve una pregunta más
 * chica, que es la manera de destrabar.
 */
export function revisarLoEscrito(texto: string, consigna: string): string | null {
  const escrito = normalizar(texto);
  const pedido = normalizar(consigna);
  if (escrito.length < 3) return null;

  if (pedido.includes(escrito) && escrito.length > 15) {
    return "Eso es la consigna copiada. Deciló con tus palabras, aunque te salga feo: si no te sale, ahí está lo que falta entender.";
  }
  if (/^(no se|ni idea|nose|no entiendo|no lo se)\b/.test(escrito)) {
    return "Está bien no saberlo entero. ¿Qué parte sí entendés? Escribí eso solo, aunque sea una palabra suelta.";
  }
  return null;
}

import { normalizar } from "./texto";

/**
 * Los verbos de las consignas.
 *
 * Buena parte de lo que se pierde en una prueba no es por no saber el tema,
 * sino por no hacer lo que la consigna pedía: te piden justificar y describís,
 * te piden comparar y contás uno solo. Acá está qué exige cada verbo —la forma
 * de la respuesta, nunca su contenido— y cómo darse cuenta de que está completa.
 */

export interface VerboConsigna {
  verbo: string;
  /** Otras formas de escribirlo que aparecen en las consignas. */
  formas: string[];
  pide: string;
  /** Señales de que la respuesta está entera. Se marcan a mano, uno mismo. */
  seCompletaCuando: string[];
  errorTipico: string;
}

export const VERBOS: VerboConsigna[] = [
  {
    verbo: "Definir",
    formas: ["defini", "definicion", "que es", "que son"],
    pide: "Decir qué es algo: a qué grupo más grande pertenece y qué lo distingue de los demás de ese grupo.",
    seCompletaCuando: [
      "Nombraste la categoría general a la que pertenece.",
      "Agregaste al menos un rasgo que lo separa de lo parecido.",
      "No usaste la misma palabra dentro de la definición.",
    ],
    errorTipico: "Dar un ejemplo en lugar de una definición.",
  },
  {
    verbo: "Caracterizar",
    formas: ["caracteriza", "caracteristicas", "rasgos"],
    pide: "Enumerar los rasgos propios de algo, los que le son característicos y no se comparten con cualquier otra cosa.",
    seCompletaCuando: [
      "Listaste tres rasgos o más.",
      "Cada rasgo es de eso y no de la categoría entera.",
      "Ordenaste de más importante a menos.",
    ],
    errorTipico: "Confundir características con partes o con historia.",
  },
  {
    verbo: "Describir",
    formas: ["describi", "descripcion", "como es", "como era"],
    pide: "Contar cómo es algo: sus partes, su aspecto, su funcionamiento, en un orden que se pueda seguir.",
    seCompletaCuando: [
      "Seguiste un orden (de afuera hacia adentro, del principio al final, de lo general a lo particular).",
      "Alguien que no lo vio nunca podría imaginárselo con tu texto.",
    ],
    errorTipico: "Mezclar descripción con opinión.",
  },
  {
    verbo: "Explicar",
    formas: ["explica", "explicacion", "por que ocurre", "a que se debe"],
    pide: "Decir por qué pasa algo: la causa, el mecanismo, lo que lo produce. No alcanza con contar qué pasa.",
    seCompletaCuando: [
      "Aparece por lo menos un «porque» de verdad, no un «entonces».",
      "Se entiende el orden: primero esto, y por eso aquello.",
      "Alguien podría predecir qué pasaría si sacás la causa.",
    ],
    errorTipico: "Describir el resultado y llamarlo explicación.",
  },
  {
    verbo: "Justificar",
    formas: ["justifica", "justificacion", "fundamenta", "fundamentacion", "por que si", "por que no"],
    pide: "Sostener una afirmación con pruebas: primero decís qué sostenés, después con qué dato o texto lo apoyás.",
    seCompletaCuando: [
      "Se entiende cuál es tu afirmación, en una sola oración.",
      "Hay al menos una prueba concreta: un dato, una cita, un ejemplo del material.",
      "Se ve la conexión entre la prueba y lo que afirmás.",
    ],
    errorTipico: "Repetir la afirmación con otras palabras y creer que eso la justifica.",
  },
  {
    verbo: "Argumentar",
    formas: ["argumenta", "argumentacion", "defende", "sostene"],
    pide: "Defender una postura con razones ordenadas, y hacerse cargo de lo que diría quien piensa lo contrario.",
    seCompletaCuando: [
      "Tu postura está dicha desde el principio.",
      "Hay dos razones o más, cada una con su apoyo.",
      "Nombraste una objeción y la respondiste.",
    ],
    errorTipico: "Dar la opinión sin ninguna razón que la sostenga.",
  },
  {
    verbo: "Comparar",
    formas: ["compara", "comparacion", "diferencias", "semejanzas", "en que se parecen", "en que se diferencian"],
    pide: "Poner dos o más cosas frente a frente usando los mismos criterios para todas.",
    seCompletaCuando: [
      "Elegiste criterios y los escribiste (tiempo, causas, consecuencias, forma…).",
      "Cada criterio se aplica a todos los términos, no a uno solo.",
      "Hay parecidos y diferencias, no sólo una de las dos.",
    ],
    errorTipico: "Contar uno entero y después el otro entero, sin cruzarlos nunca.",
  },
  {
    verbo: "Relacionar",
    formas: ["relaciona", "relacion", "vincula", "que tiene que ver"],
    pide: "Mostrar qué une a dos cosas: si una causa la otra, si una es parte de la otra, si van juntas en el tiempo.",
    seCompletaCuando: [
      "Dijiste de qué tipo es la relación, no sólo que existe.",
      "La relación va en un sentido claro: cuál afecta a cuál.",
    ],
    errorTipico: "Decir «se relacionan» sin decir cómo.",
  },
  {
    verbo: "Analizar",
    formas: ["analiza", "analisis"],
    pide: "Separar algo en sus partes, mirar cada una y después decir cómo funcionan juntas.",
    seCompletaCuando: [
      "Nombraste las partes antes de opinar sobre ellas.",
      "Miraste cada parte por separado.",
      "Cerraste diciendo qué se ve al juntarlas de nuevo.",
    ],
    errorTipico: "Resumir el texto en vez de desarmarlo.",
  },
  {
    verbo: "Clasificar",
    formas: ["clasifica", "clasificacion", "agrupa", "ordena en grupos"],
    pide: "Armar grupos con un criterio único, de modo que cada cosa entre en un grupo y en uno solo.",
    seCompletaCuando: [
      "Escribiste cuál es el criterio.",
      "Ningún elemento quedó afuera ni en dos grupos a la vez.",
    ],
    errorTipico: "Cambiar de criterio en el medio.",
  },
  {
    verbo: "Enumerar",
    formas: ["enumera", "menciona", "nombra", "indica cuales", "cuales son"],
    pide: "Dar la lista completa, sin desarrollar cada punto.",
    seCompletaCuando: ["Están todos los que pide la consigna.", "Cada punto es corto: acá no se explica."],
    errorTipico: "Desarrollar el primero y olvidarse de los demás.",
  },
  {
    verbo: "Ejemplificar",
    formas: ["ejemplifica", "da un ejemplo", "ejemplos"],
    pide: "Dar un caso concreto que muestre la idea funcionando.",
    seCompletaCuando: [
      "El ejemplo es concreto: tiene lugar, tiempo o nombres.",
      "Se ve qué parte de la idea muestra.",
      "No es el mismo ejemplo del libro.",
    ],
    errorTipico: "Repetir la definición en lugar de dar un caso.",
  },
  {
    verbo: "Sintetizar",
    formas: ["sintetiza", "sintesis", "resumi", "resumen", "en pocas palabras"],
    pide: "Quedarte con lo que no se puede sacar sin que el tema se caiga.",
    seCompletaCuando: [
      "Sacaste todos los ejemplos.",
      "Si borrás cualquier oración de lo que queda, se pierde algo.",
      "Está en tus palabras, no copiado.",
    ],
    errorTipico: "Copiar las primeras oraciones de cada párrafo.",
  },
  {
    verbo: "Interpretar",
    formas: ["interpreta", "interpretacion", "que quiere decir", "a que se refiere"],
    pide: "Decir qué significa algo y mostrar en qué parte del texto o del dato te apoyás para decirlo.",
    seCompletaCuando: [
      "Tu lectura está dicha en una oración.",
      "Señalaste el fragmento o el dato que te llevó a ella.",
    ],
    errorTipico: "Contar lo que dice, sin decir qué significa.",
  },
  {
    verbo: "Calcular",
    formas: ["calcula", "resolve", "halla", "obtene", "determina"],
    pide: "Llegar a un número con su unidad, dejando ver el procedimiento.",
    seCompletaCuando: [
      "Están los datos con sus unidades.",
      "Se ve qué hiciste en cada renglón.",
      "El resultado tiene unidad y lo verificaste.",
    ],
    errorTipico: "Escribir sólo el resultado final.",
  },
  {
    verbo: "Demostrar",
    formas: ["demostra", "demostracion", "proba que", "verifica que"],
    pide: "Partir de lo que ya está aceptado y llegar a lo que te piden, sin saltos.",
    seCompletaCuando: [
      "Cada paso se apoya en el anterior o en algo conocido.",
      "No usaste en el camino lo que querías demostrar.",
    ],
    errorTipico: "Dar por cierto justo lo que había que probar.",
  },
  {
    verbo: "Evaluar",
    formas: ["evalua", "valora", "que opinas", "considera si"],
    pide: "Tomar posición diciendo con qué criterio la tomás, y reconocer lo que juega en contra.",
    seCompletaCuando: [
      "Dijiste el criterio antes del juicio.",
      "Aparece al menos un punto en contra de tu posición.",
    ],
    errorTipico: "Decir «está bien» o «está mal» sin criterio.",
  },
];

/** El verbo que manda en la consigna: se busca el primero que aparezca. */
export function verboDeLaConsigna(consigna: string): VerboConsigna | null {
  const plano = ` ${normalizar(consigna)} `;
  let elegido: VerboConsigna | null = null;
  let posicion = Number.POSITIVE_INFINITY;

  for (const candidato of VERBOS) {
    for (const forma of [normalizar(candidato.verbo).slice(0, -1), ...candidato.formas]) {
      const donde = plano.indexOf(` ${forma}`);
      if (donde !== -1 && donde < posicion) {
        posicion = donde;
        elegido = candidato;
      }
    }
  }

  return elegido;
}

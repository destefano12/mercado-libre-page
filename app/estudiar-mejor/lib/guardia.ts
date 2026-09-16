import { normalizar } from "./texto";

/**
 * Guardia del principio inviolable: la plataforma nunca resuelve. Detecta
 * pedidos de respuesta directa y devuelve preguntas que empujan al alumno a
 * encontrarla por su cuenta.
 */

export type IntencionPedido =
  | "resolver-ejercicio"
  | "escribir-texto"
  | "resumir"
  | "traducir"
  | "respuesta-directa"
  | "consulta-legitima";

export interface RespuestaGuardia {
  intencion: IntencionPedido;
  bloqueado: boolean;
  titulo: string;
  preguntas: string[];
  cierre: string;
}

const PATRONES: { intencion: IntencionPedido; patrones: RegExp[] }[] = [
  {
    intencion: "resolver-ejercicio",
    patrones: [
      /\bresolv[eéê]/i, /\bresuelve\b/i, /\bresolver(me|lo|los)?\b/i,
      /\bcalcul[aá](me|lo)?\b/i, /\bhac[eé](me|lo)\s+(el|la|los|las|este|esta)?\s*(ejercicio|problema|cuenta|tarea|tp|actividad)/i,
      /\bcomplet[aá](me)?\s+(el|la|los|las)/i, /\bterminame\b/i,
      /\bejercicio\s+\d+\s*(resuelto|hecho)/i,
    ],
  },
  {
    intencion: "escribir-texto",
    patrones: [
      /\bescrib[ií](me|le)?\b/i, /\bredact[aá](me)?\b/i, /\barm[aá](me)\s+(el|la|un|una)\s*(trabajo|ensayo|informe|texto|monograf)/i,
      /\bhac[eé](me)?\s+(el|la|un|una)\s*(trabajo|ensayo|informe|monograf|exposici|presentaci)/i,
      /\bdame\s+(el|la|un|una)\s*(trabajo|ensayo|informe|texto)/i,
      /\bpas[aá]me\s+(el|la|un|una)\s*(trabajo|informe|texto)/i,
    ],
  },
  {
    intencion: "resumir",
    patrones: [/\bresum[ií](me)?\b/i, /\bhac[eé](me)?\s+(un|el)\s*resumen/i, /\bresumen\s+(de|del)\b/i],
  },
  {
    intencion: "traducir",
    patrones: [/\btraduc[ií](me)?\b/i, /\btraducci[oó]n\s+(de|del)\b/i],
  },
  {
    intencion: "respuesta-directa",
    patrones: [
      /\bdame\s+la\s+respuesta\b/i, /\bcu[aá]l\s+es\s+la\s+respuesta\b/i,
      /\bdecime\s+la\s+respuesta\b/i, /\bdecime\s+qu[eé]\s+(poner|contestar|responder)/i,
      /\bqu[eé]\s+(pongo|contesto|respondo)\b/i, /\bla\s+respuesta\s+correcta\s+es\b/i,
      /\bhacelo\s+(vos|por\s*m[ií])\b/i, /\bhazlo\s+t[uú]\b/i, /\bpor\s*m[ií]\b.*\bhac/i,
    ],
  },
];

const BANCOS: Record<Exclude<IntencionPedido, "consulta-legitima">, { titulo: string; preguntas: string[] }> = {
  "resolver-ejercicio": {
    titulo: "No te lo resuelvo, pero lo desarmamos juntos",
    preguntas: [
      "¿Qué te pide exactamente la consigna? Escribila con tus palabras, sin copiarla.",
      "¿Qué datos te dan y cuál es la incógnita que tenés que encontrar?",
      "¿Qué procedimiento parecido ya hiciste en clase? ¿En qué se parece y en qué cambia?",
      "Si tuvieras que dar el primer paso, ¿cuál sería y por qué ese y no otro?",
      "Cuando llegues a un resultado: ¿cómo podés verificar que tiene sentido?",
    ],
  },
  "escribir-texto": {
    titulo: "El trabajo lo escribís vos: yo te ayudo a pensarlo",
    preguntas: [
      "¿Cuál es la idea principal que querés sostener? Decila en una sola oración.",
      "¿Qué tres partes necesitás sí o sí para que esa idea se entienda?",
      "¿Qué evidencia del material apoya cada parte?",
      "¿Qué le respondería alguien que piensa lo contrario?",
      "¿Con qué frase cerrarías para que quede claro qué aprendiste?",
    ],
  },
  resumir: {
    titulo: "El resumen es tuyo: te doy el andamio",
    preguntas: [
      "Si tuvieras que contarle el tema a alguien en 30 segundos, ¿por dónde empezarías?",
      "¿Cuáles son los 3 conceptos sin los cuales el tema no se entiende?",
      "¿Qué parte del material es ejemplo y qué parte es idea central?",
      "¿Qué se pierde si sacás el párrafo más largo? Si no se pierde nada, no va al resumen.",
    ],
  },
  traducir: {
    titulo: "Traducir también es entender",
    preguntas: [
      "¿Qué palabras reconocés sin diccionario? Marcalas primero.",
      "¿De qué se trata la oración aunque te falten palabras? Arriesgá el sentido general.",
      "¿Qué tiempo verbal aparece y cómo cambia lo que se dice?",
      "Después de tu intento, ¿qué parte te quedó rara? Esa es la que hay que revisar.",
    ],
  },
  "respuesta-directa": {
    titulo: "La respuesta la tenés que encontrar vos",
    preguntas: [
      "¿Qué parte ya sabés con seguridad y cuál es la que te traba?",
      "¿Qué te dice tu material sobre esa parte que te traba?",
      "Si tuvieras que arriesgar una respuesta ahora, ¿cuál sería? Después la revisamos.",
      "¿Qué tendría que pasar para que tu respuesta esté mal? Probá encontrarle el punto flojo.",
    ],
  },
};

const CONSULTA_LEGITIMA = {
  titulo: "Vamos a ordenarlo con preguntas",
  preguntas: [
    "¿Qué es lo que ya entendés del tema y qué es lo que se te mezcla?",
    "¿Podés explicarlo en voz alta sin mirar el material? ¿Dónde te frenás?",
    "¿Qué ejemplo propio se te ocurre para este tema?",
    "¿Qué pregunta te haría un docente para ver si lo entendiste de verdad?",
  ],
};

export function detectarIntencion(texto: string): IntencionPedido {
  const plano = normalizar(texto);
  if (!plano) return "consulta-legitima";

  for (const grupo of PATRONES) {
    if (grupo.patrones.some((patron) => patron.test(texto) || patron.test(plano))) {
      return grupo.intencion;
    }
  }
  return "consulta-legitima";
}

/** Elige preguntas distintas en cada pedido, sin repetir dentro de la tanda. */
function elegir(preguntas: string[], cantidad: number, semilla: number): string[] {
  const disponibles = [...preguntas];
  const elegidas: string[] = [];
  let paso = Math.abs(semilla) % Math.max(1, disponibles.length);

  while (elegidas.length < Math.min(cantidad, preguntas.length)) {
    paso = (paso + 1 + elegidas.length) % disponibles.length;
    elegidas.push(disponibles.splice(paso, 1)[0]);
    if (disponibles.length === 0) break;
    paso = paso % disponibles.length;
  }
  return elegidas;
}

export function responderComoGuia(texto: string, semilla = Date.now()): RespuestaGuardia {
  const intencion = detectarIntencion(texto);
  const banco = intencion === "consulta-legitima" ? CONSULTA_LEGITIMA : BANCOS[intencion];
  const bloqueado = intencion !== "consulta-legitima";

  return {
    intencion,
    bloqueado,
    titulo: banco.titulo,
    preguntas: elegir(banco.preguntas, 4, semilla + texto.length),
    cierre: bloqueado
      ? "Esto no es un no porque sí: si te doy la respuesta, el día del examen no la vas a tener."
      : "Contestá estas preguntas en tu carpeta y volvé. Ahí vemos qué quedó flojo.",
  };
}

export const ETIQUETAS_INTENCION: Record<IntencionPedido, string> = {
  "resolver-ejercicio": "Pedido de resolución",
  "escribir-texto": "Pedido de redacción",
  resumir: "Pedido de resumen",
  traducir: "Pedido de traducción",
  "respuesta-directa": "Pedido de respuesta",
  "consulta-legitima": "Consulta de estudio",
};

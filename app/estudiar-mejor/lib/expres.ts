import { nivelDominio } from "./metricas";
import { analizarMaterial, terminosClave } from "./texto";
import type { EvidenciaDominio, NivelDominio, RegistroError, Tema } from "./tipos";

/**
 * El plan de estudio según cuánto falta para la prueba.
 *
 * No se estudia igual con cuarenta minutos que con cinco días, y el error más
 * caro es estudiar con el método equivocado: leer y subrayar tres veces cuando
 * quedan cuarenta minutos no sirve, y leer una sola vez a las corridas cuando
 * quedaban cinco días desperdicia los cinco. Según el horizonte cambia todo:
 * qué se hace, en qué orden y qué se deja afuera.
 *
 * Lo que no cambia: el plan dice qué hacer con el material; el material lo
 * carga el alumno y el que estudia es él.
 */

export type Horizonte = "rescate" | "hoy" | "dias" | "semana";

export interface BloqueExpres {
  id: string;
  titulo: string;
  detalle: string;
  minutos: number;
  tipo: "error" | "flojo" | "medio" | "firme" | "control" | "descanso" | "lectura";
}

export interface DiaDePlan {
  numero: number;
  cuando: string;
  titulo: string;
  tecnica: string;
  acciones: string[];
}

export interface PlanDeEstudio {
  horizonte: Horizonte;
  /** Cómo hay que leer con este tiempo, que es lo que casi nadie decide bien. */
  comoLeer: { titulo: string; pasos: string[]; nunca: string };
  /** Con poco tiempo: un solo bloque de trabajo, ahora. */
  bloques: BloqueExpres[];
  /** Con varios días: qué se hace cada día. */
  dias: DiaDePlan[];
  afuera: string[];
  advertencia: string | null;
  /** Conceptos sacados del apunte cargado, para que el plan hable de lo tuyo. */
  conceptos: string[];
  faltaMaterial: boolean;
}

export interface EntradaPlan {
  temas: Tema[];
  dominio: Record<string, EvidenciaDominio>;
  errores: RegistroError[];
  /** El texto de los apuntes cargados de esos temas. */
  material: string;
  /** Minutos hasta la prueba. */
  faltan: number;
  /** Minutos que se pueden estudiar por día. */
  porDia: number;
}

const HORA = 60;
const DIA = 24 * HORA;

export function horizonteDe(faltan: number): Horizonte {
  if (faltan <= 3 * HORA) return "rescate";
  if (faltan < 2 * DIA) return "hoy";
  if (faltan < 5 * DIA) return "dias";
  return "semana";
}

// ----------------------------------------------------------- cómo leer

const COMO_LEER: Record<Horizonte, PlanDeEstudio["comoLeer"]> = {
  rescate: {
    titulo: "Lectura de rescate: no leas todo",
    pasos: [
      "Leé únicamente los títulos y subtítulos. Esos son el esqueleto del tema y son lo que el profe usó para armar la prueba.",
      "De cada sección, leé sólo la primera y la última oración. Ahí está la idea; el medio son ejemplos.",
      "Anotá en UNA hoja los conceptos que aparezcan en negrita, recuadro o repetidos. No más de diez.",
      "Tapá la hoja y decí en voz alta qué es cada uno. Los que no te salgan, volvé a mirarlos. Esa vuelta es la que te hace acordar, no la lectura.",
    ],
    nunca: "No subrayes ni hagas resumen: con este tiempo, subrayar es una forma elegante de perder los minutos que te quedan.",
  },
  hoy: {
    titulo: "Dos pasadas, no cinco",
    pasos: [
      "Primera pasada: leé todo de corrido, sin subrayar ni anotar nada. Sólo entender de qué va.",
      "Segunda pasada: subrayá únicamente lo que NO podrías reconstruir solo. Si lo podrías decir sin mirar, no se subraya.",
      "Cerrá la carpeta y escribí de memoria el esquema del tema: títulos y una línea de cada uno.",
      "Comparalo con el apunte. Los huecos que encontraste son tu lista de estudio real: buscá sólo eso.",
      "Última media hora: preguntas. Hacéte las que te tomarías vos y contestalas por escrito.",
    ],
    nunca: "No vuelvas a leer entero por tercera vez. Releer se siente productivo y casi no deja nada: lo que deja es intentar acordarte.",
  },
  dias: {
    titulo: "Repartido en días, cambiando de método cada día",
    pasos: [
      "Antes de leer, convertí cada título en pregunta y escribilas. Leer buscando respuestas deja mucho más que leer de corrido.",
      "Un día lo leés y lo entendés; otro día lo recordás sin mirar. Nunca el mismo método dos días seguidos.",
      "Mezclá temas en la misma sesión en vez de agotar uno y pasar al otro: cuesta más y por eso funciona mejor.",
      "Dejá el último día sólo para probarte, no para aprender cosas nuevas.",
    ],
    nunca: "No dejes todo para el día anterior aunque te sobre tiempo: lo que estudiás en dos días separados queda mucho más que lo mismo junto.",
  },
  semana: {
    titulo: "Con una semana se estudia de verdad, no se repasa",
    pasos: [
      "Día 1 — Lectura activa: convertí los títulos en preguntas, leé buscando las respuestas y escribilas con tus palabras.",
      "Día 2 — Tu resumen: armá una hoja con el tema entero sin mirar el apunte. Después comparás y corregís en otro color.",
      "Día 3 — Explicárselo a alguien: a un hermano, a un amigo, a la pared. Donde te trabás está el agujero; anotalo.",
      "Día 4 — Preguntas y ejercicios, mezclando temas. Acá es donde aparecen los errores que te van a tomar.",
      "Día 5 — Simulacro cronometrado como si fuera la prueba, y corrección honesta.",
      "Día anterior — Veinte minutos mirando sólo tus errores. Y a dormir.",
    ],
    nunca: "No uses la semana para leer el mismo apunte seis veces. Cada día tiene que pedirte algo distinto, o los seis días valen como uno.",
  },
};

// --------------------------------------------------------------- bloques

const ORDEN: Record<NivelDominio, number> = { rojo: 0, "sin-datos": 1, amarillo: 2, verde: 3 };

function repartir(total: number, pesos: number[]): number[] {
  const suma = pesos.reduce((a, b) => a + b, 0);
  if (suma === 0) return pesos.map(() => 0);
  return pesos.map((peso) => Math.max(5, Math.round(((peso / suma) * total) / 5) * 5));
}

/** Los conceptos del apunte cargado: hacen que el plan hable de tu tema. */
function conceptosDelMaterial(material: string): string[] {
  if (material.trim().length < 200) return [];
  const analisis = analizarMaterial(material);
  const deDefiniciones = analisis.definiciones.map((definicion) => definicion.termino);
  return [...new Set([...deDefiniciones, ...terminosClave(material, 10)])].slice(0, 8);
}

function bloquesDeSesion(entrada: EntradaPlan, conceptos: string[]): { bloques: BloqueExpres[]; afuera: string[] } {
  const { temas, dominio, errores, porDia } = entrada;

  const control = Math.min(15, Math.max(5, Math.round((porDia * 0.12) / 5) * 5));
  const descanso = porDia >= 90 ? 10 : porDia >= 50 ? 5 : 0;
  const paraEstudiar = Math.max(10, porDia - control - descanso);

  const ordenados = [...temas].sort(
    (a, b) => ORDEN[nivelDominio(dominio[a.id])] - ORDEN[nivelDominio(dominio[b.id])],
  );
  const caben = Math.max(1, Math.floor(paraEstudiar / 10));
  const entran = ordenados.slice(0, caben);
  const afuera = ordenados.slice(caben).map((tema) => tema.nombre);

  const pesos = entran.map((tema) => {
    const nivel = nivelDominio(dominio[tema.id]);
    return nivel === "rojo" ? 4 : nivel === "sin-datos" ? 3 : nivel === "amarillo" ? 2 : 1;
  });
  const minutosPorTema = repartir(paraEstudiar, pesos);
  const bloques: BloqueExpres[] = [];

  entran.forEach((tema, indice) => {
    const nivel = nivelDominio(dominio[tema.id]);
    const suyos = errores
      .filter((error) => error.temaId === tema.id && !error.resuelto)
      .sort((a, b) => b.veces - a.veces)
      .slice(0, 3);

    if (suyos.length > 0) {
      const minutosError = Math.min(15, Math.max(5, Math.round((minutosPorTema[indice] * 0.35) / 5) * 5));
      bloques.push({
        id: `error-${tema.id}`,
        titulo: `${tema.nombre}: tus errores de siempre`,
        detalle: `Rehacé estos sin mirar: ${suyos.map((error) => error.titulo).join(" · ")}. Si uno te vuelve a salir mal, ese es el que va a aparecer.`,
        minutos: minutosError,
        tipo: "error",
      });
      minutosPorTema[indice] = Math.max(5, minutosPorTema[indice] - minutosError);
    }

    const mios = conceptos.length > 0 ? ` Mirá sobre todo: ${conceptos.slice(0, 4).join(", ")}.` : "";

    if (nivel === "rojo" || nivel === "sin-datos") {
      bloques.push({
        id: `flojo-${tema.id}`,
        titulo: `${tema.nombre}: entenderlo, no memorizarlo`,
        detalle: `Leé una vez entero sin subrayar. Después cerrá la carpeta y escribí las 5 preguntas que te tomarías.${mios}`,
        minutos: minutosPorTema[indice],
        tipo: "flojo",
      });
      return;
    }

    if (nivel === "amarillo") {
      bloques.push({
        id: `medio-${tema.id}`,
        titulo: `${tema.nombre}: explicalo en voz alta`,
        detalle: `Explicáselo a alguien, o a la pared. Donde te trabes está el agujero: anotalo y buscá sólo eso.${mios}`,
        minutos: minutosPorTema[indice],
        tipo: "medio",
      });
      return;
    }

    bloques.push({
      id: `firme-${tema.id}`,
      titulo: `${tema.nombre}: pasada rápida`,
      detalle: "Este lo tenés. Mirá sólo los títulos y decí de memoria de qué va cada uno. Si salen todos, no le des más tiempo.",
      minutos: minutosPorTema[indice],
      tipo: "firme",
    });
  });

  if (descanso > 0) {
    bloques.splice(Math.ceil(bloques.length / 2), 0, {
      id: "descanso",
      titulo: "Parar",
      detalle: "Levantate, tomá agua, mirá lejos. Sin pantalla. Es lo que hace que lo de antes te quede.",
      minutos: descanso,
      tipo: "descanso",
    });
  }

  bloques.push({
    id: "control",
    titulo: "Control final",
    detalle:
      "Cerrá todo y escribí de memoria, en una hoja, los títulos del tema y una línea de cada uno. Lo que no salga ahora, no va a salir en la prueba.",
    minutos: control,
    tipo: "control",
  });

  return { bloques, afuera };
}

// ------------------------------------------------------------------ días

const PASOS_POR_DIA: { titulo: string; tecnica: string; acciones: (temas: string[], conceptos: string[]) => string[] }[] = [
  {
    titulo: "Entender",
    tecnica: "Lectura activa",
    acciones: (temas, conceptos) => [
      `Convertí cada título de ${temas[0] ?? "el tema"} en una pregunta y escribilas antes de leer.`,
      "Leé buscando esas respuestas y contestalas con tus palabras, no copiadas.",
      conceptos.length > 0 ? `Asegurate de poder definir: ${conceptos.slice(0, 5).join(", ")}.` : "Marcá los conceptos que se repiten: esos son los que entran.",
    ],
  },
  {
    titulo: "Tu propio resumen",
    tecnica: "Recuerdo activo",
    acciones: (temas) => [
      `Sin mirar el apunte, escribí en una hoja todo lo que te acordás de ${temas.join(" y ")}.`,
      "Recién después abrí el apunte y corregí en otro color.",
      "Lo que escribiste en el segundo color es tu lista de estudio: nada más.",
    ],
  },
  {
    titulo: "Explicarlo",
    tecnica: "Método de Feynman",
    acciones: () => [
      "Explicá el tema en voz alta a alguien que no lo cursa, o a la pared.",
      "Donde te trabes, pará y anotá qué te trabó. Ahí está el agujero.",
      "Buscá sólo esos puntos y volvé a explicarlo entero.",
    ],
  },
  {
    titulo: "Practicar",
    tecnica: "Preguntas e intercalado",
    acciones: (temas) => [
      `Hacé preguntas de ${temas.join(" y ")}, mezclando los temas en vez de uno por vez.`,
      "Usá el tutor con tu apunte cargado: te las arma de tu propio material.",
      "Cada error que aparezca, anotalo en el registro de errores. Esos vuelven solos en los repasos.",
    ],
  },
  {
    titulo: "Probarte",
    tecnica: "Simulacro cronometrado",
    acciones: () => [
      "Hacé el simulacro con reloj, como si fuera la prueba, sin mirar nada.",
      "Corregí con honestidad y mirá la corrección explicada tema por tema.",
      "Lo que falle acá es exactamente lo que vas a repasar el día anterior.",
    ],
  },
  {
    titulo: "El día anterior",
    tecnica: "Repaso corto y dormir",
    acciones: () => [
      "Veinte minutos mirando SÓLO tus errores frecuentes. Nada nuevo.",
      "Una última pasada de títulos, diciendo de memoria de qué va cada uno.",
      "Y a dormir. Dormir ocho horas rinde más que las dos horas que podrías robarle a la noche.",
    ],
  },
];

function armarDias(entrada: EntradaPlan, conceptos: string[]): DiaDePlan[] {
  const cuantos = Math.max(2, Math.min(6, Math.floor(entrada.faltan / DIA)));
  const nombres = entrada.temas.map((tema) => tema.nombre);

  // Con pocos días se juntan pasos: entender y resumir el mismo día, por ejemplo.
  const elegidos =
    cuantos >= 6
      ? PASOS_POR_DIA
      : cuantos === 5
        ? [PASOS_POR_DIA[0], PASOS_POR_DIA[1], PASOS_POR_DIA[2], PASOS_POR_DIA[3], PASOS_POR_DIA[5]]
        : cuantos === 4
          ? [PASOS_POR_DIA[0], PASOS_POR_DIA[1], PASOS_POR_DIA[3], PASOS_POR_DIA[5]]
          : cuantos === 3
            ? [PASOS_POR_DIA[0], PASOS_POR_DIA[3], PASOS_POR_DIA[5]]
            : [PASOS_POR_DIA[0], PASOS_POR_DIA[5]];

  return elegidos.map((paso, indice) => ({
    numero: indice + 1,
    cuando:
      indice === elegidos.length - 1
        ? "El día anterior"
        : indice === 0
          ? "Hoy"
          : `Día ${indice + 1}`,
    titulo: paso.titulo,
    tecnica: paso.tecnica,
    acciones: paso.acciones(nombres, conceptos),
  }));
}

// ------------------------------------------------------------------ plan

export function armarPlanDeEstudio(entrada: EntradaPlan): PlanDeEstudio {
  const horizonte = horizonteDe(entrada.faltan);
  const conceptos = conceptosDelMaterial(entrada.material);
  const faltaMaterial = conceptos.length === 0;

  const base = {
    horizonte,
    comoLeer: COMO_LEER[horizonte],
    conceptos,
    faltaMaterial,
  };

  if (entrada.temas.length === 0) {
    return {
      ...base,
      bloques: [],
      dias: [],
      afuera: [],
      advertencia: "Elegí al menos un tema de los que entran en la prueba.",
    };
  }

  if (horizonte === "rescate" || horizonte === "hoy") {
    const { bloques, afuera } = bloquesDeSesion(entrada, conceptos);
    return {
      ...base,
      bloques,
      dias: [],
      afuera,
      advertencia:
        afuera.length > 0
          ? `Con ${entrada.porDia} minutos no entra todo. Dejé afuera ${afuera.join(", ")}: es mejor saber bien lo que más te falta que pasar por arriba de todo.`
          : horizonte === "rescate"
            ? "Queda poco: esto es lo único que rinde. No le agregues nada más."
            : null,
    };
  }

  return {
    ...base,
    bloques: [],
    dias: armarDias(entrada, conceptos),
    afuera: [],
    advertencia:
      horizonte === "semana"
        ? "Tenés tiempo de aprenderlo, no de repasarlo. Cada día pide algo distinto: si hacés lo mismo seis días, los seis valen como uno."
        : null,
  };
}

import { normalizar } from "./texto";

/**
 * Esquemas por materia. Cuando el tema pedido no está en el banco, las
 * consignas igual tienen que ser sobre ese tema y con la forma de pensar de esa
 * materia: en Historia se pregunta por causas y cronología, en Matemática por
 * procedimiento y verificación, en Lengua por estructura y recursos.
 *
 * Así no existe el "esta materia no está cargada": siempre hay consignas, y
 * recorren el tema entero en lugar de tocarlo de costado.
 */

export interface Materia {
  nombre: string;
  alias: string[];
  preguntas: ((tema: string) => string)[];
}

export const MATERIAS: Materia[] = [
  {
    nombre: "Historia",
    alias: ["historia", "historica", "historico", "sociales", "ciencias sociales"],
    preguntas: [
      (t) => `¿En qué época y en qué lugar se ubica ${t}? Escribí al menos una fecha de referencia.`,
      (t) => `¿Qué venía pasando antes de ${t}? Describí la situación previa.`,
      (t) => `¿Qué causas explican ${t}? Separá las económicas de las políticas y las sociales.`,
      (t) => `¿Quiénes fueron los protagonistas de ${t} y qué buscaba cada grupo?`,
      (t) => `Ordená cronológicamente los hechos principales de ${t} y explicá por qué van en ese orden.`,
      (t) => `¿Qué consecuencias inmediatas tuvo ${t}? ¿Y cuáles se ven a largo plazo?`,
      (t) => `¿Qué habría cambiado si ${t} no hubiera ocurrido? Fundamentá.`,
      (t) => `¿Con qué otro proceso que hayas estudiado se puede comparar ${t}? ¿En qué se parecen y en qué no?`,
      (t) => `¿Qué huellas de ${t} se pueden reconocer hoy?`,
      (t) => `Si tuvieras que explicar ${t} en cinco renglones, ¿qué no podría faltar?`,
    ],
  },
  {
    nombre: "Geografía",
    alias: ["geografia", "geografico", "territorio", "cartografia"],
    preguntas: [
      (t) => `¿Dónde se ubica ${t}? Describí su posición y qué lo rodea.`,
      (t) => `¿Qué características naturales definen ${t}?`,
      (t) => `¿Cómo influye ${t} en la vida de la población que vive ahí?`,
      (t) => `¿Qué actividades económicas se asocian con ${t} y por qué?`,
      (t) => `¿Qué problemas ambientales se vinculan con ${t}?`,
      (t) => `Compará ${t} con otra zona que hayas estudiado: ¿qué cambia?`,
      (t) => `¿Cómo se representa ${t} en un mapa y qué información hace falta para leerlo?`,
      (t) => `¿Qué decisiones humanas modificaron ${t} con el tiempo?`,
    ],
  },
  {
    nombre: "Biología",
    alias: ["biologia", "biologico", "naturales", "ciencias naturales", "anatomia", "salud"],
    preguntas: [
      (t) => `Definí ${t} y explicá qué función cumple dentro del organismo o del sistema al que pertenece.`,
      (t) => `¿De qué partes se compone ${t}? Nombralas y explicá qué hace cada una.`,
      (t) => `¿Cómo funciona ${t} paso a paso? Describí el proceso completo.`,
      (t) => `¿Qué pasa si ${t} falla o no se cumple? Dé un ejemplo concreto.`,
      (t) => `¿Con qué otros procesos o sistemas se relaciona ${t}?`,
      (t) => `¿Qué factores modifican ${t} y de qué manera?`,
      (t) => `Dé un ejemplo de ${t} que puedas observar en la vida cotidiana.`,
      (t) => `¿Qué error se comete con frecuencia al explicar ${t}?`,
    ],
  },
  {
    nombre: "Química",
    alias: ["quimica", "quimico", "sustancias", "reacciones"],
    preguntas: [
      (t) => `Definí ${t} y explicá con qué concepto de la materia se relaciona.`,
      (t) => `¿Qué ocurre a nivel de átomos o moléculas en ${t}?`,
      (t) => `¿Qué se conserva y qué cambia en ${t}?`,
      (t) => `Escribí un ejemplo de ${t} con su representación simbólica y explicá cada término.`,
      (t) => `¿Qué factores modifican ${t} y por qué?`,
      (t) => `¿Cómo se reconoce ${t} experimentalmente? ¿Qué se observa?`,
      (t) => `¿Dónde aparece ${t} fuera del laboratorio?`,
      (t) => `¿Qué error se comete más seguido al resolver ejercicios de ${t}?`,
    ],
  },
  {
    nombre: "Física",
    alias: ["fisica", "fisico", "mecanica", "optica", "termodinamica"],
    preguntas: [
      (t) => `¿Qué magnitud o fenómeno describe ${t} y en qué unidades se mide?`,
      (t) => `Enunciá con tus palabras la ley o el principio que rige ${t}.`,
      (t) => `¿Qué variables intervienen en ${t} y cómo se afectan entre sí?`,
      (t) => `Resolvé un problema sencillo de ${t} y verificá si el resultado tiene sentido físico.`,
      (t) => `Dé un ejemplo cotidiano donde se observe ${t}.`,
      (t) => `¿Qué pasaría si una de las variables de ${t} se duplicara?`,
      (t) => `¿Qué confusión frecuente aparece al estudiar ${t}? Explicá por qué está mal.`,
      (t) => `Dibujá un esquema de ${t} y justificá cada elemento que pusiste.`,
    ],
  },
  {
    nombre: "Matemática",
    alias: ["matematica", "matematicas", "mate", "algebra", "geometria", "aritmetica", "analisis"],
    preguntas: [
      (t) => `¿Qué problema resuelve ${t} y cuándo conviene usarlo?`,
      (t) => `Escribí el procedimiento de ${t} paso a paso, justificando cada paso.`,
      (t) => `Resolvé un ejercicio de ${t} y verificá el resultado reemplazando.`,
      (t) => `¿Qué condiciones tienen que cumplirse para poder aplicar ${t}?`,
      (t) => `¿En qué caso ${t} no se puede usar? Dé un ejemplo.`,
      (t) => `¿Cuál es el error más frecuente al trabajar con ${t} y cómo lo detectás?`,
      (t) => `Inventá un problema de la vida real que se resuelva con ${t}.`,
      (t) => `¿Cómo se relaciona ${t} con algo que hayas visto antes en la materia?`,
    ],
  },
  {
    nombre: "Lengua",
    alias: ["lengua", "gramatica", "sintaxis", "ortografia", "practicas del lenguaje", "comunicacion"],
    preguntas: [
      (t) => `Definí ${t} y explicá para qué sirve en la comunicación.`,
      (t) => `¿Cómo se reconoce ${t} en un texto? Explicá el procedimiento, no sólo el resultado.`,
      (t) => `Escribí tres ejemplos propios de ${t} y explicá por qué lo son.`,
      (t) => `¿Con qué otro concepto se confunde ${t} y cómo los diferenciás?`,
      (t) => `¿Qué cambia en un texto si ${t} está mal usado?`,
      (t) => `Analizá un caso de ${t} tomado de algo que leas habitualmente.`,
      (t) => `¿Qué regla hay que recordar sí o sí sobre ${t}?`,
      (t) => `Explicá ${t} como si se lo enseñaras a alguien de primer año.`,
    ],
  },
  {
    nombre: "Literatura",
    alias: ["literatura", "literario", "obra", "novela", "cuento", "poesia", "teatro"],
    preguntas: [
      (t) => `¿A qué género y a qué época pertenece ${t}? Ubicalo.`,
      (t) => `¿Cuál es el tema central de ${t} y con qué recursos se construye?`,
      (t) => `¿Quién narra o habla en ${t} y cómo afecta eso a lo que entendemos?`,
      (t) => `Describí a los personajes o voces de ${t} y qué representa cada uno.`,
      (t) => `¿Qué contexto histórico ayuda a entender ${t}?`,
      (t) => `¿Qué recursos literarios aparecen en ${t} y qué efecto producen?`,
      (t) => `¿Qué interpretación personal podés defender sobre ${t}? Sostenela con una cita.`,
      (t) => `¿Con qué otra obra dialoga ${t} y en qué se diferencian?`,
    ],
  },
  {
    nombre: "Formación Ciudadana",
    alias: ["ciudadania", "civica", "formacion etica", "etica", "derecho", "politica", "constitucion"],
    preguntas: [
      (t) => `Definí ${t} y explicá en qué norma o principio se apoya.`,
      (t) => `¿Por qué existe ${t}? ¿Qué problema busca resolver?`,
      (t) => `¿A quiénes alcanza ${t} y quién debe garantizarlo?`,
      (t) => `¿Qué pasa cuando ${t} no se cumple? Dé un ejemplo real.`,
      (t) => `¿Cómo se relaciona ${t} con tu vida cotidiana o la de tu escuela?`,
      (t) => `¿Qué posturas distintas existen sobre ${t}? Explicá al menos dos.`,
      (t) => `¿Cómo cambió ${t} a lo largo del tiempo?`,
      (t) => `Defendé una posición sobre ${t} con dos argumentos.`,
    ],
  },
  {
    nombre: "Economía",
    alias: ["economia", "economico", "contabilidad", "administracion", "mercado", "finanzas"],
    preguntas: [
      (t) => `Definí ${t} y explicá qué mide o describe.`,
      (t) => `¿Qué factores hacen que ${t} suba o baje?`,
      (t) => `¿A quiénes beneficia y a quiénes perjudica ${t}?`,
      (t) => `Explicá ${t} con un ejemplo de precios o sueldos concretos.`,
      (t) => `¿Cómo se relaciona ${t} con lo que ves en tu casa o en el barrio?`,
      (t) => `¿Qué medidas se suelen tomar frente a ${t} y qué costo tiene cada una?`,
      (t) => `¿Qué indicadores se usan para seguir ${t}?`,
      (t) => `¿Qué confusión habitual hay alrededor de ${t}?`,
    ],
  },
  {
    nombre: "Inglés",
    alias: ["ingles", "english", "idioma", "frances", "portugues"],
    preguntas: [
      (t) => `¿Para qué se usa ${t}? Explicalo en castellano, con tus palabras.`,
      (t) => `¿Cómo se forma ${t}? Escribí la estructura y un ejemplo.`,
      (t) => `Escribí tres oraciones propias usando ${t}.`,
      (t) => `¿Con qué otra estructura se confunde ${t} y cómo las distinguís?`,
      (t) => `Convertí una oración afirmativa de ${t} a negativa e interrogativa.`,
      (t) => `¿Qué error cometen habitualmente los hispanohablantes con ${t}?`,
      (t) => `Encontrá un ejemplo de ${t} en una canción o una serie que conozcas.`,
      (t) => `Explicá ${t} a un compañero que faltó a esa clase.`,
    ],
  },
  {
    nombre: "Arte y Música",
    alias: ["arte", "artes", "plastica", "musica", "dibujo"],
    preguntas: [
      (t) => `¿Qué caracteriza a ${t} y en qué época o corriente se ubica?`,
      (t) => `¿Qué elementos o técnicas se reconocen en ${t}?`,
      (t) => `¿Qué buscaba transmitir ${t} y en qué contexto surgió?`,
      (t) => `Describí un ejemplo concreto de ${t} y analizalo.`,
      (t) => `¿Con qué otra corriente o estilo contrasta ${t}?`,
      (t) => `¿Qué influencia de ${t} se reconoce en lo que consumís hoy?`,
      (t) => `¿Qué te genera ${t} y con qué elementos lo logra?`,
    ],
  },
  {
    nombre: "Filosofía y Psicología",
    alias: ["filosofia", "psicologia", "logica", "pensamiento"],
    preguntas: [
      (t) => `¿Qué problema plantea ${t} y por qué es un problema?`,
      (t) => `¿Qué respuestas se dieron a ${t} a lo largo del tiempo? Nombrá al menos dos.`,
      (t) => `¿Qué autor o corriente se asocia con ${t} y qué sostiene?`,
      (t) => `¿Qué objeción se le puede hacer a esa postura sobre ${t}?`,
      (t) => `¿Cómo se relaciona ${t} con una situación de tu vida cotidiana?`,
      (t) => `Defendé una posición propia sobre ${t} con dos argumentos.`,
      (t) => `¿Qué conceptos hay que tener claros para discutir ${t}?`,
    ],
  },
  {
    nombre: "Informática y Tecnología",
    alias: ["informatica", "tecnologia", "computacion", "programacion", "sistemas"],
    preguntas: [
      (t) => `Definí ${t} y explicá qué problema resuelve.`,
      (t) => `¿Cómo funciona ${t} paso a paso?`,
      (t) => `¿Qué partes o componentes intervienen en ${t}?`,
      (t) => `Dé un ejemplo de ${t} que uses todos los días sin darte cuenta.`,
      (t) => `¿Qué pasa si ${t} falla? ¿Qué consecuencias tiene?`,
      (t) => `¿Con qué otra herramienta o concepto se compara ${t}?`,
      (t) => `¿Qué cuidados o riesgos hay que tener en cuenta con ${t}?`,
    ],
  },
  {
    nombre: "Educación Física",
    alias: ["educacion fisica", "deporte", "gimnasia", "entrenamiento"],
    preguntas: [
      (t) => `¿En qué consiste ${t} y qué capacidades pone en juego?`,
      (t) => `¿Cuáles son las reglas o los pasos principales de ${t}?`,
      (t) => `¿Qué efectos tiene ${t} sobre el cuerpo?`,
      (t) => `¿Qué precauciones hay que tomar al practicar ${t}?`,
      (t) => `¿Cómo se progresa en ${t}? Describí una rutina razonable.`,
      (t) => `¿Qué error técnico es el más común en ${t}?`,
      (t) => `¿Cómo se relaciona ${t} con la salud a largo plazo?`,
    ],
  },
];

/** Consignas que sirven para cualquier tema, cuando no se reconoce la materia. */
const GENERAL: ((tema: string) => string)[] = [
  (t) => `Definí ${t} con tus palabras, sin copiar del apunte.`,
  (t) => `¿De dónde viene ${t}? Contá su origen o cómo surgió.`,
  (t) => `¿De qué partes o etapas se compone ${t}? Nombralas en orden.`,
  (t) => `¿Por qué ocurre o para qué sirve ${t}? Explicá la razón, no sólo el resultado.`,
  (t) => `¿Qué elementos no pueden faltar al explicar ${t}?`,
  (t) => `Dé un ejemplo concreto de ${t} que no esté en tu carpeta.`,
  (t) => `¿Qué pasaría si ${t} no existiera o no ocurriera?`,
  (t) => `¿Con qué otro tema se relaciona ${t} y en qué se diferencian?`,
  (t) => `¿Cuál es el error más frecuente al estudiar ${t}? ¿Cómo vas a evitarlo?`,
  (t) => `Explicá ${t} completo en cinco renglones, como si tomaras la prueba vos.`,
];

/** Reconoce la materia a partir de lo que escribió el alumno. */
export function detectarMateria(pedido: string): Materia | null {
  const plano = ` ${normalizar(pedido)} `;
  let elegida: Materia | null = null;
  let largo = 0;

  MATERIAS.forEach((materia) => {
    [materia.nombre, ...materia.alias].forEach((etiqueta) => {
      const clave = normalizar(etiqueta);
      if (clave.length < 4 || !plano.includes(clave) || clave.length <= largo) return;
      largo = clave.length;
      elegida = materia;
    });
  });

  return elegida;
}

export function consignasDeMateria(pedido: string, tema: string): { materia: string | null; consignas: string[] } {
  const materia = detectarMateria(pedido);
  const plantillas = materia?.preguntas ?? GENERAL;
  return { materia: materia?.nombre ?? null, consignas: plantillas.map((plantilla) => plantilla(tema)) };
}

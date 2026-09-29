import { normalizar } from "./texto";

/**
 * Ejercitación: material para trabajar, no preguntas sobre el material.
 *
 * Cuando el alumno pide "hacéme oraciones para analizar sintácticamente" lo
 * que necesita son oraciones, no preguntas acerca de la sintaxis. Este módulo
 * arma el material —oraciones, palabras, cuentas, ecuaciones— junto con la
 * consigna y una guía para que él mismo verifique si le salió bien.
 *
 * Lo único que nunca aparece es la resolución: el ejercicio se entrega abierto.
 */

export interface Ejercitacion {
  tipo: string;
  titulo: string;
  /** Qué hay que hacer con el material. */
  consigna: string;
  /** El material propiamente dicho: una línea por ejercicio. */
  material: string[];
  /** Cómo darse cuenta solo de si está bien, sin que nadie le diga la respuesta. */
  comoVerificar: string[];
  nota: string;
}

// ------------------------------------------------------------------ al azar

function alAzar<T>(lista: readonly T[]): T {
  return lista[Math.floor(Math.random() * lista.length)];
}

function tomar<T>(lista: readonly T[], cantidad: number): T[] {
  const copia = [...lista];
  const elegidos: T[] = [];
  while (copia.length > 0 && elegidos.length < cantidad) {
    elegidos.push(copia.splice(Math.floor(Math.random() * copia.length), 1)[0]);
  }
  return elegidos;
}

function entero(desde: number, hasta: number): number {
  return desde + Math.floor(Math.random() * (hasta - desde + 1));
}

/** Los años más altos reciben el material más largo y más enredado. */
function porAnio<T>(anio: number, faciles: readonly T[], medias: readonly T[], dificiles: readonly T[]): readonly T[] {
  if (anio <= 2) return [...faciles, ...medias.slice(0, 2)];
  if (anio <= 4) return [...faciles.slice(0, 2), ...medias, ...dificiles.slice(0, 2)];
  return [...medias.slice(0, 2), ...dificiles];
}

// --------------------------------------------------------------- sintaxis

const ORACIONES_SIMPLES = [
  "Los chicos de tercero pintaron el mural del patio.",
  "Mi abuela prepara empanadas los domingos.",
  "El colectivo llegó tarde a la parada.",
  "Ayer llovió toda la tarde.",
  "El perro del vecino ladra de noche.",
  "Nosotros estudiamos en la biblioteca del barrio.",
];

const ORACIONES_MEDIAS = [
  "La profesora de Historia les entregó las notas a los alumnos el viernes.",
  "Durante el recreo, Martina le prestó la calculadora a su compañero.",
  "En el laboratorio, los estudiantes observaron las células con el microscopio.",
  "El intendente inauguró la plaza nueva frente a la escuela.",
  "Mi hermano le regaló una bicicleta usada a su mejor amigo.",
  "Los bomberos rescataron al gato del techo con mucho cuidado.",
];

const ORACIONES_DIFICILES = [
  "Aunque había estudiado toda la semana, Julián se puso nervioso cuando lo llamaron al frente.",
  "El libro que me prestaste la semana pasada quedó olvidado en el aula de música.",
  "Los vecinos que reclamaron por el ruido consiguieron que la municipalidad interviniera.",
  "Si el tren no se hubiera demorado, habríamos llegado a tiempo a la entrega del trabajo.",
  "La periodista explicó que las inundaciones afectaron a tres provincias del litoral.",
  "Mientras el docente explicaba el tema, varios alumnos tomaban apuntes en sus carpetas.",
];

function ejercitacionSintaxis(anio: number): Ejercitacion {
  return {
    tipo: "sintaxis",
    titulo: "Oraciones para analizar sintácticamente",
    consigna:
      anio <= 2
        ? "Separá sujeto y predicado en cada oración, marcá los núcleos y clasificá la oración en bimembre o unimembre."
        : anio <= 4
          ? "Marcá sujeto y predicado con sus núcleos, e identificá objeto directo, objeto indirecto y circunstanciales."
          : "Analizá cada oración completa: sujeto y predicado con sus núcleos y modificadores, objetos, circunstanciales y, donde las haya, las proposiciones subordinadas con su tipo.",
    material: tomar(porAnio(anio, ORACIONES_SIMPLES, ORACIONES_MEDIAS, ORACIONES_DIFICILES), 6),
    comoVerificar: [
      "Cambiá el verbo de singular a plural: lo que cambia con él es el sujeto.",
      "Reemplazá el candidato a objeto directo por «lo» o «la»; si la oración sigue en pie, era objeto directo.",
      "Reemplazá el candidato a objeto indirecto por «le» o «les».",
      "Preguntale al verbo dónde, cuándo, cómo, con qué: cada respuesta es un circunstancial distinto.",
      "Si no encontrás sujeto y el verbo no admite ninguno, fijate si la oración es unimembre.",
    ],
    nota: "El análisis lo hacés vos: acá están las oraciones y la manera de controlarte solo.",
  };
}

// ------------------------------------------------------- clases de palabras

const TEXTOS_MORFOLOGIA = [
  "El viejo reloj de la estación marcaba las siete cuando el último tren partió lentamente.",
  "Varias alumnas entregaron ayer sus trabajos prácticos en la sala de profesores.",
  "Aquella tarde fría, dos perros callejeros corrían detrás de una pelota rota.",
  "Nuestro equipo jugó muy bien, pero perdió el partido por un gol.",
  "La computadora nueva funciona mejor que la anterior, aunque cuesta el doble.",
  "Mi tía siempre cocina arroz con pollo para las fiestas familiares.",
];

function ejercitacionMorfologia(anio: number): Ejercitacion {
  return {
    tipo: "morfologia",
    titulo: "Oraciones para analizar morfológicamente",
    consigna:
      anio <= 2
        ? "Clasificá cada palabra: sustantivo, adjetivo, verbo, artículo, pronombre, adverbio, preposición o conjunción."
        : "Clasificá cada palabra por su clase y agregale los accidentes: género, número y grado en sustantivos y adjetivos; persona, número, tiempo y modo en los verbos.",
    material: tomar(TEXTOS_MORFOLOGIA, 5),
    comoVerificar: [
      "Si le podés poner «el», «la», «los» o «las» adelante, es sustantivo.",
      "Si acompaña al sustantivo y cambia de género y número con él, es adjetivo.",
      "Si lo podés conjugar («yo…», «vos…»), es verbo.",
      "Si no cambia nunca de forma, pensá en adverbio, preposición o conjunción.",
    ],
    nota: "Las palabras están: la clasificación es tuya.",
  };
}

// ------------------------------------------------------- tildes y sílabas

const PALABRAS_TILDES = [
  "arbol", "cancion", "examen", "facil", "lapiz", "musica", "reloj", "ventana",
  "brujula", "caracter", "corazon", "dificil", "esdrujula", "jovenes", "pajaro",
  "resumen", "telefono", "volcan", "atmosfera", "miercoles", "sabado", "camion",
];

function ejercitacionTildes(): Ejercitacion {
  return {
    tipo: "tildes",
    titulo: "Palabras para separar en sílabas y tildar",
    consigna:
      "Copiá cada palabra, separala en sílabas, marcá la sílaba tónica, clasificala en aguda, grave, esdrújula o sobresdrújula y decidí si lleva tilde. Las palabras van a propósito sin tildar.",
    material: tomar(PALABRAS_TILDES, 10),
    comoVerificar: [
      "Decila en voz alta y exagerá: la sílaba que suena más fuerte es la tónica.",
      "Aguda con tilde sólo si termina en vocal, n o s. Grave con tilde sólo si NO termina en vocal, n o s.",
      "Toda esdrújula y sobresdrújula lleva tilde, sin excepción.",
      "Al final, buscá dos o tres en el diccionario: si coinciden con lo que pusiste, la regla te salió.",
    ],
    nota: "Ninguna palabra viene tildada: el que decide sos vos.",
  };
}

// ------------------------------------------------------------------ verbos

const VERBOS = [
  "cantar", "correr", "vivir", "poner", "traer", "decir", "hacer", "salir",
  "querer", "poder", "venir", "andar", "caber", "conducir", "elegir", "dormir",
];
const TIEMPOS = [
  "presente del indicativo",
  "pretérito perfecto simple del indicativo",
  "pretérito imperfecto del indicativo",
  "futuro simple del indicativo",
  "condicional simple",
  "presente del subjuntivo",
  "pretérito imperfecto del subjuntivo",
];

function ejercitacionVerbos(anio: number): Ejercitacion {
  const tiempos = anio <= 2 ? TIEMPOS.slice(0, 4) : TIEMPOS;
  return {
    tipo: "verbos",
    titulo: "Verbos para conjugar",
    consigna: "Conjugá cada verbo completo en el tiempo que se pide, en las seis personas.",
    material: tomar(VERBOS, 6).map((verbo) => `${verbo} — ${alAzar(tiempos)}`),
    comoVerificar: [
      "Escribí primero la conjugación regular de la terminación (-ar, -er, -ir) y después fijate si el verbo se aparta.",
      "Si el verbo es irregular, subrayá la letra que cambia: esa irregularidad suele repetirse en otros verbos parecidos.",
      "Leé las seis personas seguidas en voz alta: si alguna suena rara, ahí está el error.",
    ],
    nota: "La conjugación la escribís vos; si una forma te hace dudar, marcala y consultala al final.",
  };
}

// ------------------------------------------------------------- matemática

function ecuacionesPrimerGrado(cantidad: number): string[] {
  return Array.from({ length: cantidad }, () => {
    const a = entero(2, 9);
    const b = entero(-12, 12);
    const x = entero(-8, 9);
    const c = a * x + b;
    const signo = b < 0 ? `- ${Math.abs(b)}` : `+ ${b}`;
    return `${a}x ${signo} = ${c}`;
  });
}

function ecuacionesSegundoGrado(cantidad: number): string[] {
  return Array.from({ length: cantidad }, () => {
    const r1 = entero(-6, 6);
    const r2 = entero(-6, 6);
    const b = -(r1 + r2);
    const c = r1 * r2;
    const termB = b === 0 ? "" : b < 0 ? ` - ${Math.abs(b)}x` : ` + ${b}x`;
    const termC = c === 0 ? "" : c < 0 ? ` - ${Math.abs(c)}` : ` + ${c}`;
    return `x²${termB}${termC} = 0`;
  });
}

function operacionesCombinadas(cantidad: number): string[] {
  return Array.from({ length: cantidad }, () =>
    `${entero(2, 12)} + ${entero(2, 9)} × ${entero(2, 9)} − (${entero(10, 40)} ÷ ${entero(2, 5)}) ${alAzar(["+", "−"])} ${entero(2, 15)}`,
  );
}

function porcentajes(cantidad: number): string[] {
  return Array.from({ length: cantidad }, () =>
    alAzar([
      `Una campera cuesta $${entero(20, 90) * 1000}. Le hacen un ${entero(5, 40)}% de descuento. ¿Cuánto se paga?`,
      `En un curso de ${entero(20, 35)} alumnos, el ${entero(20, 80)}% aprobó. ¿Cuántos aprobaron?`,
      `Un producto de $${entero(5, 30) * 100} aumenta un ${entero(5, 35)}%. ¿Cuál es el precio nuevo?`,
    ]),
  );
}

function pitagoras(cantidad: number): string[] {
  return Array.from({ length: cantidad }, () =>
    `Un triángulo rectángulo tiene catetos de ${entero(3, 18)} cm y ${entero(3, 18)} cm. Calculá la hipotenusa.`,
  );
}

function ejercitacionMatematica(pedido: string, anio: number): Ejercitacion {
  const plano = normalizar(pedido);
  const segundoGrado = /cuadratic|segundo grado|parabol/.test(plano);
  const porcentaje = /porcentaje|descuento|aumento/.test(plano);
  const teorema = /pitagoras|triangulo|hipotenusa|cateto/.test(plano);
  const combinadas = /combinada|operacion|cuenta/.test(plano);

  const material = teorema
    ? pitagoras(5)
    : porcentaje
      ? porcentajes(5)
      : segundoGrado
        ? ecuacionesSegundoGrado(6)
        : combinadas
          ? operacionesCombinadas(6)
          : anio >= 4
            ? [...ecuacionesPrimerGrado(3), ...ecuacionesSegundoGrado(3)]
            : ecuacionesPrimerGrado(6);

  return {
    tipo: "matematica",
    titulo: teorema
      ? "Problemas de Pitágoras"
      : porcentaje
        ? "Problemas de porcentaje"
        : segundoGrado
          ? "Ecuaciones de segundo grado"
          : combinadas
            ? "Operaciones combinadas"
            : "Ecuaciones para resolver",
    consigna: teorema || porcentaje
      ? "Resolvé cada problema escribiendo los datos, el planteo y el resultado con su unidad."
      : "Resolvé cada ecuación paso por paso, dejando escrito qué hacés en cada renglón.",
    material,
    comoVerificar: [
      "Reemplazá tu resultado en la ecuación o en el problema original: si los dos lados dan lo mismo, está bien.",
      "Estimá antes de calcular: si el resultado se aleja mucho de tu estimación, revisá.",
      "Mirá los signos: la mayoría de los errores están ahí, no en la cuenta.",
    ],
    nota: "Las cuentas están sin resolver, a propósito. La verificación te dice sola si acertaste.",
  };
}

// ---------------------------------------------------------------- inglés

const ORACIONES_INGLES = [
  "She (to go) to the club every Saturday.",
  "They (not / to finish) their homework yet.",
  "We (to watch) a film when the lights went out.",
  "My brother (to live) in Córdoba since 2019.",
  "If it (to rain), we will stay at home.",
  "The students (to present) their projects next Monday.",
  "I (to see) that movie three times.",
  "He (not / to like) getting up early.",
];

function ejercitacionIngles(): Ejercitacion {
  return {
    tipo: "ingles",
    titulo: "Sentences to complete",
    consigna:
      "Escribí cada oración completa poniendo el verbo entre paréntesis en el tiempo que corresponde, y al lado anotá qué tiempo usaste y por qué.",
    material: tomar(ORACIONES_INGLES, 6),
    comoVerificar: [
      "Buscá la marca de tiempo en la oración (every Saturday, yet, since, next Monday): ella decide el tiempo verbal.",
      "Revisá la tercera persona del singular en presente simple: casi siempre falta la -s.",
      "Leé la oración en voz alta: si el sentido no cierra en español, el tiempo elegido está mal.",
    ],
    nota: "Las oraciones vienen con el verbo sin conjugar: el que lo pone sos vos.",
  };
}

// ---------------------------------------------------------------- química

const ECUACIONES_QUIMICA = [
  "H₂ + O₂ → H₂O",
  "Fe + O₂ → Fe₂O₃",
  "CH₄ + O₂ → CO₂ + H₂O",
  "Na + H₂O → NaOH + H₂",
  "Al + HCl → AlCl₃ + H₂",
  "C₃H₈ + O₂ → CO₂ + H₂O",
  "KClO₃ → KCl + O₂",
  "N₂ + H₂ → NH₃",
];

function ejercitacionQuimica(): Ejercitacion {
  return {
    tipo: "quimica",
    titulo: "Ecuaciones para balancear",
    consigna: "Balanceá cada ecuación y escribí al lado cuántos átomos de cada elemento quedan de cada lado.",
    material: tomar(ECUACIONES_QUIMICA, 6),
    comoVerificar: [
      "Contá los átomos de cada elemento a un lado y al otro: tienen que coincidir todos.",
      "Empezá por el elemento que aparece en menos compuestos y dejá el oxígeno para el final.",
      "Los coeficientes se cambian; los subíndices de las fórmulas, nunca.",
    ],
    nota: "Las ecuaciones están sin balancear: el conteo lo hacés vos.",
  };
}

// ----------------------------------------------------------------- física

function ejercitacionFisica(): Ejercitacion {
  const material = Array.from({ length: 5 }, () =>
    alAzar([
      `Un auto recorre ${entero(60, 300)} km en ${entero(1, 5)} h a velocidad constante. Calculá su velocidad en km/h y en m/s.`,
      `Un cuerpo parte del reposo y acelera a ${entero(2, 9)} m/s² durante ${entero(3, 12)} s. Calculá la velocidad final y la distancia recorrida.`,
      `Se deja caer una piedra desde ${entero(10, 80)} m de altura. Calculá cuánto tarda en llegar al suelo.`,
      `Sobre un cuerpo de ${entero(2, 40)} kg actúa una fuerza de ${entero(10, 200)} N. Calculá la aceleración.`,
    ]),
  );
  return {
    tipo: "fisica",
    titulo: "Problemas para resolver",
    consigna: "Escribí los datos con sus unidades, elegí la fórmula, despejá y recién ahí reemplazá por los números.",
    material,
    comoVerificar: [
      "Controlá las unidades: si te queda una unidad que no corresponde, la fórmula o el despeje están mal.",
      "Preguntate si el número tiene sentido físico: una piedra no cae durante veinte minutos desde un tercer piso.",
      "Rehacé el despeje al revés partiendo de tu resultado: tenés que volver al dato original.",
    ],
    nota: "Los problemas vienen con datos y sin resolución.",
  };
}

// ------------------------------------------------------------- detección

interface Familia {
  tipo: string;
  /** Si aparece cualquiera de estas marcas, es esta ejercitación. */
  marcas: RegExp[];
  armar: (pedido: string, anio: number) => Ejercitacion;
}

/** El orden importa: las familias más específicas van primero, porque una
 *  ecuación química también dice "ecuación". */
const FAMILIAS: Familia[] = [
  { tipo: "sintaxis", marcas: [/sintact/, /sintaxis/, /analisis sintac/, /sujeto y predicado/, /oraciones para analizar/, /bimembre/, /circunstancial/], armar: (_p, anio) => ejercitacionSintaxis(anio) },
  { tipo: "morfologia", marcas: [/morfolog/, /clases de palabras/, /sustantivo/, /adjetivo/, /clasificar palabras/], armar: (_p, anio) => ejercitacionMorfologia(anio) },
  { tipo: "tildes", marcas: [/tilde/, /acentuac/, /silaba/, /agudas/, /graves/, /esdrujul/, /ortograf/], armar: () => ejercitacionTildes() },
  { tipo: "verbos", marcas: [/conjuga/, /verbos para/, /tiempos verbales/], armar: (_p, anio) => ejercitacionVerbos(anio) },
  { tipo: "ingles", marcas: [/ingles/, /english/, /present perfect/, /past simple/, /present simple/, /tiempos en ingles/], armar: () => ejercitacionIngles() },
  { tipo: "quimica", marcas: [/balance/, /quimic/, /formulas quimicas/, /reaccion/], armar: () => ejercitacionQuimica() },
  { tipo: "fisica", marcas: [/fisica/, /mru/, /velocidad/, /aceleracion/, /caida libre/, /newton/], armar: () => ejercitacionFisica() },
  { tipo: "matematica", marcas: [/ecuacion/, /matematica/, /cuentas/, /operaciones combinadas/, /porcentaje/, /pitagoras/, /algebra/, /despejar/], armar: (pedido, anio) => ejercitacionMatematica(pedido, anio) },
];

/**
 * ¿El alumno está pidiendo material para trabajar? Se reconoce por el objeto
 * del pedido —oraciones, palabras, cuentas, ejercicios, ejemplos— y no por
 * cómo esté escrito: acentos, mayúsculas y redacción dan igual.
 */
const PIDE_MATERIAL =
  /\b(oracion|oraciones|frase|frases|palabra|palabras|ejercicio|ejercicios|ejercitacion|ejercitar|actividad|actividades|cuenta|cuentas|ecuacion|ecuaciones|problema|problemas|practic\w*|ejemplo|ejemplos|texto|textos|verbo|verbos|analizar|entren\w*)\b/;

/** "Hacé el ejercicio 4", en cambio, es pedirle a la página que resuelva. */
const PIDE_RESOLUCION =
  /\b(el|la|los|las|este|esta|estos|estas|ese|esa|mi|mis|del)\s+(ejercicio|problema|cuenta|actividad|consigna|tarea|tp)\b|\bejercicio\s+\d|\bpagina\s+\d|\bresolve|\bresuelve|\bresolucion|\bresultado|\brespuesta/;

export function detectarEjercitacion(pedido: string, anio: number): Ejercitacion | null {
  const plano = normalizar(pedido);
  if (!PIDE_MATERIAL.test(plano)) return null;
  if (PIDE_RESOLUCION.test(plano)) return null;

  const familia = FAMILIAS.find((candidata) => candidata.marcas.some((marca) => marca.test(plano)));
  if (familia) return familia.armar(pedido, anio);

  // Sin materia declarada, el objeto del pedido alcanza: pedir oraciones es
  // pedir sintaxis, y pedir cuentas es pedir matemática.
  if (/\b(oracion|oraciones|frase|frases)\b/.test(plano)) return ejercitacionSintaxis(anio);
  if (/\b(cuenta|cuentas|ecuacion|ecuaciones)\b/.test(plano)) return ejercitacionMatematica(pedido, anio);
  if (/\bverbo|verbos\b/.test(plano)) return ejercitacionVerbos(anio);
  if (/\b(palabra|palabras)\b/.test(plano)) return ejercitacionTildes();

  return null;
}

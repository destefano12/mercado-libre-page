/**
 * Motor de análisis de texto en español. Todo corre en el navegador: no hay
 * servicios externos ni modelos remotos. Su trabajo es encontrar de qué habla
 * el material del alumno para poder preguntarle, nunca para responderle.
 */

const STOPWORDS = new Set([
  "a", "al", "algo", "alguna", "algunas", "alguno", "algunos", "ante", "antes",
  "aquel", "aquella", "aquello", "aqui", "asi", "aunque", "cada", "casi",
  "como", "con", "contra", "cual", "cuales", "cuando", "cuanto", "de", "del",
  "desde", "donde", "dos", "el", "ella", "ellas", "ellos", "en", "entre",
  "era", "eran", "eres", "es", "esa", "esas", "ese", "eso", "esos", "esta",
  "estaba", "estan", "estas", "este", "esto", "estos", "fue", "fueron", "ha",
  "habia", "hace", "hacia", "han", "hasta", "hay", "la", "las", "le", "les",
  "lo", "los", "mas", "me", "mi", "mientras", "misma", "mismo", "mucho", "muy",
  "nada", "ni", "no", "nos", "nuestra", "nuestro", "o", "otra", "otras",
  "otro", "otros", "para", "pero", "poco", "por", "porque", "puede", "pueden",
  "que", "quien", "se", "segun", "ser", "si", "sin", "sobre", "solo", "son",
  "su", "sus", "tal", "tambien", "tan", "tanto", "te", "tiene", "tienen",
  "toda", "todas", "todo", "todos", "tras", "un", "una", "uno", "unos", "y",
  "ya", "yo", "sera", "seria", "fueron", "estar", "esta", "estos", "tener",
  "hacer", "cuya", "cuyo", "ademas", "luego", "entonces", "entonce", "cabe",
  // Verbos y muletillas de alta frecuencia: aparecen en cualquier apunte y no
  // sirven como concepto a preguntar.
  "ocurre", "ocurren", "ocurrio", "sucede", "suceden", "tiene", "tienen",
  "hace", "hacen", "existe", "existen", "indica", "indican", "incluye",
  "incluyen", "llama", "llaman", "permite", "permiten", "pueden", "puede",
  "debe", "deben", "suele", "suelen", "sirve", "sirven", "resulta",
  "resultan", "aparece", "aparecen", "presenta", "presentan", "realiza",
  "realizan", "utiliza", "utilizan", "usan", "logra", "logran", "consiste",
  "consisten", "desarrolla", "desarrollan", "produce", "producen", "significa", "significan", "conoce", "conocen", "denomina",
  "denominan", "define", "definen", "trata", "tratan", "comienza",
  "comienzan", "termina", "terminan", "sigue", "siguen", "queda", "quedan",
  "manera", "modo", "caso", "casos", "veces", "parte", "partes", "traves",
  "mediante", "durante", "general", "generalmente", "principalmente",
  "especialmente", "solamente", "primero", "segundo", "tercero", "finalmente",
  "decir", "ejemplo", "ejemplos", "forma", "formas", "tipo", "tipos", "cosa",
  "cosas", "algunos", "algunas", "varios", "varias", "mismo", "misma",
  "grande", "grandes", "nuevo", "nueva", "mejor", "peor", "sino", "pues",
]);

const CONECTORES_CAUSA = [
  "porque", "debido a", "ya que", "gracias a", "por lo tanto", "por eso",
  "en consecuencia", "como resultado", "provoca", "produce", "genera",
  "permite", "origina", "causa", "lleva a", "hace que", "da lugar a",
];

const MARCAS_DEFINICION = [
  "se define como", "se conoce como", "se llama", "se denomina",
  "consiste en", "significa", "es decir", "es el", "es la", "es un",
  "es una", "son los", "son las", "son un", "son unos", "refiere a",
  "se refiere a", "se entiende por",
];

const MARCAS_PROCESO = [
  "primero", "segundo", "luego", "después", "despues", "finalmente",
  "a continuación", "a continuacion", "etapa", "fase", "paso", "comienza",
  "termina", "se inicia", "por último", "por ultimo",
];

const VAGUEDADES = [
  "cosa", "cosas", "algo", "eso", "esas cosas", "tipo", "o sea", "básicamente",
  "basicamente", "no sé", "no se", "y demás", "y demas", "etcétera", "etcetera",
  "bla", "cualquier cosa", "más o menos", "mas o menos", "creo que sí",
];

export interface Definicion {
  termino: string;
  cuerpo: string;
  oracion: string;
  indice: number;
}

export interface Relacion {
  conector: string;
  oracion: string;
  indice: number;
}

export interface DatoNumerico {
  valor: string;
  oracion: string;
  indice: number;
}

export interface AnalisisMaterial {
  oraciones: string[];
  terminos: string[];
  definiciones: Definicion[];
  causas: Relacion[];
  procesos: Relacion[];
  datos: DatoNumerico[];
  enumeraciones: Relacion[];
  palabras: number;
}

export function sinAcentos(texto: string): string {
  return texto.normalize("NFD").replace(/[̀-ͯ]/g, "");
}

export function normalizar(texto: string): string {
  return sinAcentos(texto.toLowerCase()).replace(/[^a-z0-9ñ\s]/g, " ").replace(/\s+/g, " ").trim();
}

export function tokens(texto: string): string[] {
  return normalizar(texto).split(" ").filter(Boolean);
}

export function contarPalabras(texto: string): number {
  return tokens(texto).length;
}

export function dividirEnOraciones(texto: string): string[] {
  return texto
    .replace(/\s+/g, " ")
    .split(/(?<=[.!?;:])\s+|\n+/)
    .map((parte) => parte.trim().replace(/^[-•*\d.)\s]+/, "").trim())
    .filter((parte) => tokens(parte).length >= 5);
}

/** Términos clave por frecuencia, largo y aparición temprana en el material. */
export function terminosClave(texto: string, limite = 14): string[] {
  const oraciones = dividirEnOraciones(texto);
  const puntajes = new Map<string, number>();
  const original = new Map<string, string>();

  oraciones.forEach((oracion, indice) => {
    const bonusPosicion = indice < 3 ? 1.4 : 1;
    const crudas = oracion.split(/\s+/);

    crudas.forEach((cruda) => {
      const limpia = cruda.replace(/[^\p{L}\p{N}-]/gu, "");
      const clave = normalizar(limpia);
      if (clave.length < 4 || STOPWORDS.has(clave) || /^\d+$/.test(clave)) return;
      const puntaje = (puntajes.get(clave) ?? 0) + bonusPosicion + Math.min(limpia.length, 12) / 24;
      puntajes.set(clave, puntaje);
      if (!original.has(clave)) original.set(clave, limpia.toLowerCase());
    });

    for (let i = 0; i < crudas.length - 1; i += 1) {
      const limpiaA = crudas[i].replace(/[^\p{L}\p{N}-]/gu, "");
      const limpiaB = crudas[i + 1].replace(/[^\p{L}\p{N}-]/gu, "");
      const a = normalizar(limpiaA);
      const b = normalizar(limpiaB);
      if (a.length < 4 || b.length < 4) continue;
      if (STOPWORDS.has(a) || STOPWORDS.has(b)) continue;
      const clave = `${a} ${b}`;
      puntajes.set(clave, (puntajes.get(clave) ?? 0) + 1.6 * bonusPosicion);
      if (!original.has(clave)) original.set(clave, `${limpiaA} ${limpiaB}`.toLowerCase());
    }
  });

  return [...puntajes.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, limite)
    .map(([clave]) => original.get(clave) ?? clave);
}

function indiceDeMarca(oracionNormalizada: string, marcas: string[]): string | null {
  for (const marca of marcas) {
    const normalizada = normalizar(marca);
    if (oracionNormalizada.includes(` ${normalizada} `)) return marca;
  }
  return null;
}

export function analizarMaterial(texto: string): AnalisisMaterial {
  const oraciones = dividirEnOraciones(texto);
  const definiciones: Definicion[] = [];
  const causas: Relacion[] = [];
  const procesos: Relacion[] = [];
  const datos: DatoNumerico[] = [];
  const enumeraciones: Relacion[] = [];

  oraciones.forEach((oracion, indice) => {
    const plana = ` ${normalizar(oracion)} `;

    const marcaDefinicion = indiceDeMarca(plana, MARCAS_DEFINICION);
    if (marcaDefinicion) {
      const partes = oracion.split(new RegExp(`\\b${marcaDefinicion.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\b`, "i"));
      const termino = (partes[0] ?? "").trim().replace(/^(el|la|los|las|un|una)\s+/i, "");
      const cuerpo = (partes[1] ?? "").trim();
      if (termino && tokens(termino).length <= 6 && tokens(cuerpo).length >= 3) {
        definiciones.push({ termino, cuerpo, oracion, indice });
      }
    }

    const marcaCausa = indiceDeMarca(plana, CONECTORES_CAUSA);
    if (marcaCausa) causas.push({ conector: marcaCausa, oracion, indice });

    const marcaProceso = indiceDeMarca(plana, MARCAS_PROCESO);
    if (marcaProceso) procesos.push({ conector: marcaProceso, oracion, indice });

    const numero = oracion.match(/\b(\d{1,4}(?:[.,]\d+)?%?|siglo\s+[IVXLC]+)\b/i);
    if (numero) datos.push({ valor: numero[0], oracion, indice });

    if ((oracion.match(/,/g) ?? []).length >= 2 && / y | o /i.test(oracion)) {
      enumeraciones.push({ conector: "enumeración", oracion, indice });
    }
  });

  return {
    oraciones,
    terminos: terminosClave(texto),
    definiciones,
    causas,
    procesos,
    datos,
    enumeraciones,
    palabras: contarPalabras(texto),
  };
}

/** Qué proporción de los términos esperados aparece en un texto del alumno. */
export function cobertura(textoAlumno: string, esperados: string[]): {
  presentes: string[];
  faltantes: string[];
  porcentaje: number;
} {
  const plano = ` ${normalizar(textoAlumno)} `;
  const presentes: string[] = [];
  const faltantes: string[] = [];

  esperados.forEach((esperado) => {
    const clave = normalizar(esperado);
    if (!clave) return;
    const raiz = clave.length > 6 ? clave.slice(0, clave.length - 2) : clave;
    if (plano.includes(clave) || plano.includes(raiz)) presentes.push(esperado);
    else faltantes.push(esperado);
  });

  const total = presentes.length + faltantes.length;
  return {
    presentes,
    faltantes,
    porcentaje: total === 0 ? 0 : Math.round((presentes.length / total) * 100),
  };
}

export interface SenalesRazonamiento {
  causales: number;
  ejemplos: number;
  definiciones: number;
  comparaciones: number;
  vaguedades: number;
  circular: boolean;
  palabras: number;
}

export function señalesDeRazonamiento(texto: string, foco: string): SenalesRazonamiento {
  const plano = ` ${normalizar(texto)} `;
  const cuenta = (lista: string[]) =>
    lista.reduce((total, marca) => (plano.includes(` ${normalizar(marca)}`) ? total + 1 : total), 0);

  const focoPlano = normalizar(foco);
  const primeraOracion = normalizar(dividirEnOraciones(texto)[0] ?? texto);
  const circular =
    focoPlano.length > 3 &&
    primeraOracion.split(focoPlano).length > 2 &&
    tokens(primeraOracion).length < 24;

  return {
    causales: cuenta(CONECTORES_CAUSA),
    ejemplos: cuenta(["por ejemplo", "como cuando", "un caso", "por caso", "ejemplo"]),
    definiciones: cuenta(MARCAS_DEFINICION),
    comparaciones: cuenta(["a diferencia", "en cambio", "mientras que", "se parece", "igual que", "mas que", "menos que"]),
    vaguedades: cuenta(VAGUEDADES),
    circular,
    palabras: contarPalabras(texto),
  };
}

/**
 * Oculta un término dentro de una oración para armar un ejercicio de completar.
 * Si el término abre la oración se descarta: tapar la primera palabra da una
 * consigna sin contexto suficiente para razonarla.
 */
export function ocultarTermino(oracion: string, termino: string): string | null {
  const patron = new RegExp(`\\b${termino.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\b`, "i");
  const encontrado = oracion.match(patron);
  if (!encontrado || encontrado.index === undefined) return null;
  if (encontrado.index < 2) return null;
  return oracion.replace(patron, "_______");
}

/** Recorta una oración larga para usarla como opción de multiple choice. */
export function recortar(texto: string, maximo = 130): string {
  const limpio = texto.trim().replace(/\s+/g, " ");
  if (limpio.length <= maximo) return limpio;
  return `${limpio.slice(0, maximo).replace(/[\s,;.]+\S*$/, "")}…`;
}

export function mayuscula(texto: string): string {
  return texto.charAt(0).toUpperCase() + texto.slice(1);
}

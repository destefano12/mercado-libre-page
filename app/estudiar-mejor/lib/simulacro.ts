import { crearId } from "./id";
import {
  analizarMaterial,
  cobertura,
  mayuscula,
  normalizar,
  ocultarTermino,
  recortar,
  terminosClave,
  tokens,
} from "./texto";
import type { ItemSimulacro, Material, OpcionItem, RespuestaItem } from "./tipos";

/**
 * Simulador de evaluación: arma una prueba parecida a la que tomaría un
 * docente a partir del material del alumno, la cronometra y después la corrige
 * explicando tema por tema. Corregir una práctica terminada no es resolver la
 * tarea: es mostrarle al alumno dónde se le escapó el razonamiento.
 */

function generadorPseudoAleatorio(semilla: number) {
  let estado = semilla % 2147483647;
  if (estado <= 0) estado += 2147483646;
  return () => {
    estado = (estado * 16807) % 2147483647;
    return (estado - 1) / 2147483646;
  };
}

function mezclar<T>(lista: T[], azar: () => number): T[] {
  const copia = [...lista];
  for (let i = copia.length - 1; i > 0; i -= 1) {
    const j = Math.floor(azar() * (i + 1));
    [copia[i], copia[j]] = [copia[j], copia[i]];
  }
  return copia;
}

function distanciaEdicion(a: string, b: string): number {
  const filas = a.length + 1;
  const columnas = b.length + 1;
  const matriz = Array.from({ length: filas }, (_, i) => [i, ...Array<number>(columnas - 1).fill(0)]);
  for (let j = 0; j < columnas; j += 1) matriz[0][j] = j;

  for (let i = 1; i < filas; i += 1) {
    for (let j = 1; j < columnas; j += 1) {
      const costo = a[i - 1] === b[j - 1] ? 0 : 1;
      matriz[i][j] = Math.min(matriz[i - 1][j] + 1, matriz[i][j - 1] + 1, matriz[i - 1][j - 1] + costo);
    }
  }
  return matriz[filas - 1][columnas - 1];
}

const CRITERIOS_BASE = [
  "Definí el concepto con tus palabras.",
  "Explicaste el porqué, no sólo el qué.",
  "Usaste un ejemplo propio.",
  "Cerraste con una conclusión.",
];

function negar(oracion: string): string | null {
  const reemplazos: [RegExp, string][] = [
    [/\bes\b/i, "no es"],
    [/\bson\b/i, "no son"],
    [/\bpermite\b/i, "impide"],
    [/\baumenta\b/i, "disminuye"],
    [/\bdisminuye\b/i, "aumenta"],
    [/\bantes\b/i, "después"],
    [/\bdespués\b/i, "antes"],
    [/\bmayor\b/i, "menor"],
    [/\bmenor\b/i, "mayor"],
    [/\bsiempre\b/i, "nunca"],
    [/\btodos\b/i, "ninguno de"],
  ];
  for (const [patron, reemplazo] of reemplazos) {
    if (patron.test(oracion)) return oracion.replace(patron, reemplazo);
  }
  const numero = oracion.match(/\b(\d{1,4})\b/);
  if (numero) {
    const valor = Number(numero[1]);
    return oracion.replace(numero[0], `${valor === 0 ? 7 : Math.round(valor * 1.5) + 1}`);
  }
  return null;
}

export interface EntradaSimulacro {
  temaId: string;
  materiales: Material[];
  cantidad: number;
  duracionMin: number;
  focosPrioritarios?: string[];
}

export function generarItems(entrada: EntradaSimulacro): ItemSimulacro[] {
  const texto = entrada.materiales.map((material) => material.texto).join("\n");
  const analisis = analizarMaterial(texto);
  const azar = generadorPseudoAleatorio(texto.length * 7919 + (Date.now() % 100000));
  const multiples: ItemSimulacro[] = [];
  const verdaderoFalso: ItemSimulacro[] = [];
  const completar: ItemSimulacro[] = [];
  const desarrollo: ItemSimulacro[] = [];

  const definiciones = mezclar(analisis.definiciones, azar);
  const cuerpos = analisis.definiciones.map((definicion) => recortar(definicion.cuerpo));

  // 1) Multiple choice a partir de las definiciones del material.
  definiciones.forEach((definicion) => {
    const correcta = recortar(definicion.cuerpo);

    // Los distractores salen primero de otras definiciones y, si no alcanzan,
    // de otras oraciones del propio material: así suenan plausibles.
    const otrasDefiniciones = cuerpos.filter((cuerpo) => cuerpo !== correcta);
    const otrasOraciones = analisis.oraciones
      .filter((oracion) => !normalizar(oracion).includes(normalizar(definicion.termino)))
      .map((oracion) => recortar(oracion));
    const distractores: string[] = [];

    mezclar([...otrasDefiniciones, ...otrasOraciones], azar).forEach((candidato) => {
      if (distractores.length >= 3) return;
      if (candidato === correcta || distractores.includes(candidato)) return;
      distractores.push(candidato);
    });

    const opciones: OpcionItem[] = mezclar([correcta, ...distractores], azar).map((textoOpcion, indice) => ({
      id: `op-${indice}`,
      texto: mayuscula(textoOpcion),
    }));

    if (opciones.length < 3) return;
    const elegida = opciones.find((opcion) => normalizar(opcion.texto) === normalizar(correcta));
    if (!elegida) return;

    multiples.push({
      id: crearId("item"),
      tipo: "multiple",
      foco: definicion.termino,
      enunciado: `¿Cuál de estas opciones describe mejor a “${definicion.termino}”?`,
      opciones,
      correcta: elegida.id,
      referencia: definicion.oracion,
    });
  });

  // 2) Verdadero o falso sobre afirmaciones del material.
  const candidatasVf = mezclar([...analisis.causas, ...analisis.datos], azar);
  candidatasVf.forEach((candidata) => {
    const debeSerFalsa = azar() > 0.45;
    const alterada = debeSerFalsa ? negar(candidata.oracion) : null;
    const enunciado = alterada ?? candidata.oracion;

    verdaderoFalso.push({
      id: crearId("item"),
      tipo: "vf",
      foco: terminosClave(candidata.oracion, 1)[0] ?? "afirmación",
      enunciado: `“${recortar(enunciado, 180)}”`,
      opciones: [
        { id: "V", texto: "Verdadero" },
        { id: "F", texto: "Falso" },
      ],
      correcta: alterada ? "F" : "V",
      referencia: candidata.oracion,
    });
  });

  // 3) Completar: se tapa un término clave dentro de su oración.
  const terminos = mezclar(analisis.terminos, azar);
  terminos.forEach((termino) => {
    const oracion = analisis.oraciones.find(
      (candidata) => normalizar(candidata).includes(normalizar(termino)) && tokens(candidata).length >= 8,
    );
    if (!oracion) return;
    const tapada = ocultarTermino(oracion, termino);
    if (!tapada) return;

    completar.push({
      id: crearId("item"),
      tipo: "completar",
      foco: termino,
      enunciado: `Completá con el término que falta: “${recortar(tapada, 190)}”`,
      esperado: [termino],
      referencia: oracion,
    });
  });

  // 4) Desarrollo con rúbrica: se corrige por criterios, no por palabra exacta.
  const candidatasDesarrollo = mezclar([...analisis.procesos, ...analisis.causas], azar);
  candidatasDesarrollo.forEach((candidata) => {
    const foco = terminosClave(candidata.oracion, 1)[0] ?? "el tema";
    desarrollo.push({
      id: crearId("item"),
      tipo: "desarrollo",
      foco,
      enunciado: `Desarrollá con tus palabras: ¿cómo funciona “${foco}” y por qué? Usá un ejemplo propio.`,
      esperado: terminosClave(candidata.oracion, 4),
      criterios: CRITERIOS_BASE,
      referencia: candidata.oracion,
    });
  });

  // Mezcla equilibrada: se reparte por tipo y, si un tipo se queda sin
  // candidatos, los que sobran se completan con los demás. Los focos donde el
  // alumno ya venía fallando entran primero.
  const prioritarios = new Set((entrada.focosPrioritarios ?? []).map((foco) => normalizar(foco)));
  const porPrioridad = (lista: ItemSimulacro[]) =>
    [...lista].sort((a, b) => {
      const pesoA = [...prioritarios].some((foco) => foco.includes(normalizar(a.foco))) ? 1 : 0;
      const pesoB = [...prioritarios].some((foco) => foco.includes(normalizar(b.foco))) ? 1 : 0;
      return pesoB - pesoA;
    });

  const pools: [ItemSimulacro[], number][] = [
    [porPrioridad(multiples), 0.35],
    [porPrioridad(verdaderoFalso), 0.25],
    [porPrioridad(completar), 0.2],
    [porPrioridad(desarrollo), 0.2],
  ];

  const elegidos: ItemSimulacro[] = [];
  pools.forEach(([pool, proporcion]) => {
    elegidos.push(...pool.splice(0, Math.round(entrada.cantidad * proporcion)));
  });

  // Relleno con lo que haya quedado disponible, sin repetir.
  const sobrantes = pools.flatMap(([pool]) => pool);
  elegidos.push(...sobrantes.slice(0, Math.max(0, entrada.cantidad - elegidos.length)));

  return mezclar(elegidos, azar).slice(0, entrada.cantidad);
}

export interface CorreccionItem {
  item: ItemSimulacro;
  respuesta: RespuestaItem;
  explicacion: string;
  sugerencia: string;
}

export interface CorreccionPorFoco {
  foco: string;
  correctas: number;
  total: number;
  detalles: CorreccionItem[];
}

function textoDeOpcion(item: ItemSimulacro, id: string): string {
  return item.opciones?.find((opcion) => opcion.id === id)?.texto ?? id;
}

export function corregirItem(item: ItemSimulacro, valor: string, criteriosMarcados: string[] = []): RespuestaItem {
  if (item.tipo === "multiple" || item.tipo === "vf") {
    const correcta = valor !== "" && valor === item.correcta;
    return { itemId: item.id, valor, correcta, puntaje: correcta ? 1 : 0 };
  }

  if (item.tipo === "completar") {
    const esperado = normalizar(item.esperado?.[0] ?? "");
    const dado = normalizar(valor);
    const cerca =
      dado.length > 0 &&
      (dado === esperado ||
        dado.includes(esperado) ||
        esperado.includes(dado) ||
        distanciaEdicion(dado, esperado) <= Math.max(1, Math.round(esperado.length * 0.2)));
    return { itemId: item.id, valor, correcta: cerca, puntaje: cerca ? 1 : 0 };
  }

  const resultado = cobertura(valor, item.esperado ?? []);
  const criterios = criteriosMarcados.length / Math.max(1, item.criterios?.length ?? 1);
  const palabras = tokens(valor).length;
  const puntaje = Math.min(1, resultado.porcentaje / 100 * 0.6 + criterios * 0.25 + (palabras >= 25 ? 0.15 : palabras / 25 * 0.15));

  return {
    itemId: item.id,
    valor,
    criteriosMarcados,
    correcta: puntaje >= 0.6,
    puntaje: Math.round(puntaje * 100) / 100,
  };
}

export function explicarItem(item: ItemSimulacro, respuesta: RespuestaItem): CorreccionItem {
  let explicacion = "";
  let sugerencia = "";

  if (item.tipo === "multiple") {
    const tuya = respuesta.valor ? textoDeOpcion(item, respuesta.valor) : "—";
    explicacion = respuesta.correcta
      ? `Elegiste “${recortar(tuya, 90)}” y coincide con lo que dice tu material sobre ${item.foco}.`
      : `Elegiste “${recortar(tuya, 90)}”. La opción correcta era “${recortar(textoDeOpcion(item, item.correcta ?? ""), 90)}”, porque en tu material ${item.foco} aparece definido en: “${recortar(item.referencia, 150)}”.`;
    sugerencia = respuesta.correcta
      ? `Probá explicar ${item.foco} sin leer ninguna opción: ahí se ve si lo sabés o lo reconociste.`
      : `Releé esa parte y anotá en qué se diferencia la opción que elegiste de la correcta.`;
  } else if (item.tipo === "vf") {
    explicacion = respuesta.correcta
      ? `Bien: la afirmación era ${item.correcta === "V" ? "verdadera" : "falsa"}. En tu material figura: “${recortar(item.referencia, 150)}”.`
      : `Era ${item.correcta === "V" ? "verdadera" : "falsa"}. La afirmación original de tu material es: “${recortar(item.referencia, 150)}”. ${item.correcta === "F" ? "La versión del examen cambiaba un dato o invertía la relación." : ""}`;
    sugerencia = "En verdadero o falso, buscá siempre la palabra que cambia todo: nunca, siempre, todos, ninguno.";
  } else if (item.tipo === "completar") {
    explicacion = respuesta.correcta
      ? `Completaste bien con “${respuesta.valor}”.`
      : `Escribiste “${respuesta.valor || "—"}” y el término que faltaba era “${item.esperado?.[0]}”. La oración completa de tu material es: “${recortar(item.referencia, 150)}”.`;
    sugerencia = respuesta.correcta
      ? "Ahora probá definir ese término sin la oración alrededor."
      : "Anotá este término en tu registro de errores: los que se tapan son los que no quedaron fijados.";
  } else {
    const resultado = cobertura(respuesta.valor, item.esperado ?? []);
    explicacion = respuesta.correcta
      ? `Tu desarrollo cubre ${resultado.porcentaje}% de las ideas centrales del material sobre ${item.foco}.`
      : `Tu desarrollo cubre ${resultado.porcentaje}% de las ideas centrales sobre ${item.foco}: quedaron ${resultado.faltantes.length} sin aparecer. No te digo cuáles: volvé al material y buscá qué falta.`;
    sugerencia = respuesta.correcta
      ? "Sumá un contraejemplo: es lo que separa un 8 de un 10."
      : `Reescribilo respetando los criterios: qué es, por qué, ejemplo propio y conclusión.`;
  }

  return { item, respuesta, explicacion, sugerencia };
}

export function agruparPorFoco(items: ItemSimulacro[], respuestas: RespuestaItem[]): CorreccionPorFoco[] {
  const mapa = new Map<string, CorreccionPorFoco>();

  items.forEach((item) => {
    const respuesta =
      respuestas.find((candidata) => candidata.itemId === item.id) ??
      ({ itemId: item.id, valor: "", correcta: false, puntaje: 0 } as RespuestaItem);
    const clave = item.foco.toLowerCase();
    const grupo = mapa.get(clave) ?? { foco: item.foco, correctas: 0, total: 0, detalles: [] };

    grupo.total += 1;
    if (respuesta.correcta) grupo.correctas += 1;
    grupo.detalles.push(explicarItem(item, respuesta));
    mapa.set(clave, grupo);
  });

  return [...mapa.values()].sort((a, b) => a.correctas / a.total - b.correctas / b.total);
}

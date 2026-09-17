import { buscarEnBanco, elegirPorNivel, nombreDelAnio } from "./banco";
import { analizarMaterial, mayuscula, normalizar, recortar, terminosClave } from "./texto";

/**
 * Arma tandas de consignas para resolver en la carpeta cuando el alumno las
 * pide ("hacéme preguntas de Biología sobre fotosíntesis"). Devuelve preguntas,
 * nunca respuestas: si hay material cargado del tema salen de ahí, y si no,
 * se arman con un esquema que sirve para cualquier materia.
 */

export interface ConsignasArmadas {
  tema: string;
  materia?: string;
  origen: "material" | "banco" | "esquema";
  consignas: string[];
  nota: string;
}

const ESQUEMA: ((tema: string) => string)[] = [
  (tema) => `Definí ${tema} con tus palabras, sin copiar del libro ni del apunte.`,
  (tema) => `¿A qué categoría más general pertenece ${tema}? ¿Con qué otro concepto se puede confundir y en qué se diferencian?`,
  (tema) => `¿Por qué ocurre ${tema}? Escribí la causa, no solamente lo que se ve como resultado.`,
  (tema) => `¿Qué pasos o etapas tiene ${tema}? Enumeralos en orden y justificá por qué van en ese orden.`,
  (tema) => `¿Qué pasaría si ${tema} no existiera o no ocurriera? Explicá qué cambiaría.`,
  (tema) => `Dame un ejemplo de ${tema} que no esté en tu carpeta.`,
  (tema) => `¿Qué datos, fechas o cantidades conviene recordar de ${tema}, y por qué son importantes?`,
  (tema) => `Explicá ${tema} en cinco renglones a alguien que no cursa la materia.`,
  (tema) => `¿Cuál es el error más frecuente al estudiar ${tema}? ¿Cómo vas a evitarlo esta vez?`,
  (tema) => `Si te tomaran una sola pregunta de ${tema}, ¿cuál sería la más difícil? Escribila y respondela.`,
];

function desdeMaterial(tema: string, texto: string, cantidad: number): string[] {
  const analisis = analizarMaterial(texto);
  const consignas: string[] = [];
  const usados = new Set<string>();

  const agregar = (consigna: string, clave: string) => {
    if (usados.has(clave) || consignas.length >= cantidad) return;
    usados.add(clave);
    consignas.push(consigna);
  };

  analisis.definiciones.forEach((definicion) => {
    agregar(
      `Explicá con tus palabras qué es ${definicion.termino}, sin mirar el apunte.`,
      `def:${normalizar(definicion.termino)}`,
    );
  });

  analisis.causas.forEach((causa) => {
    const foco = terminosClave(causa.oracion, 1)[0] ?? tema;
    agregar(
      `Tu material relaciona dos ideas al hablar de ${foco}. Escribí cuál es la causa y cuál la consecuencia.`,
      `causa:${normalizar(foco)}`,
    );
  });

  analisis.procesos.forEach((proceso) => {
    const foco = terminosClave(proceso.oracion, 1)[0] ?? tema;
    agregar(
      `Enumerá en orden los pasos de ${foco} y explicá por qué ninguno puede ir antes que el anterior.`,
      `proceso:${normalizar(foco)}`,
    );
  });

  analisis.datos.forEach((dato) => {
    const foco = terminosClave(dato.oracion, 1)[0] ?? tema;
    agregar(
      `Hay un dato numérico ligado a ${foco}. Escribí cuál es y por qué el material lo menciona.`,
      `dato:${normalizar(foco)}`,
    );
  });

  analisis.enumeraciones.forEach((lista) => {
    const foco = terminosClave(lista.oracion, 1)[0] ?? tema;
    agregar(
      `Tu material enumera varios elementos al tratar ${foco}. Escribí cuántos son y nombralos de memoria.`,
      `lista:${normalizar(foco)}`,
    );
  });

  analisis.terminos.forEach((termino) => {
    agregar(
      `¿Dónde aparece ${termino} fuera de la escuela? Dame un ejemplo tuyo, no uno del material.`,
      `term:${normalizar(termino)}`,
    );
  });

  // Si el material era corto, se completa con el esquema general.
  ESQUEMA.forEach((plantilla, indice) => agregar(plantilla(tema), `esquema:${indice}`));

  return consignas.slice(0, cantidad);
}

export interface EntradaConsignas {
  /** Lo que escribió el alumno, tal cual: sirve para buscar el tema en el banco. */
  pedido: string;
  tema: string;
  textoMaterial: string;
  anio: number;
  cantidad?: number;
}

/**
 * Tres fuentes, en orden de preferencia:
 * 1. El material que cargó el alumno, que siempre le gana a cualquier otra cosa.
 * 2. El banco de temas frecuentes de secundaria, con consignas puntuales.
 * 3. El esquema general, que sirve para cualquier tema aunque no lo conozcamos.
 * En los tres casos el nivel se ajusta al año que cursa.
 */
export function armarConsignas(entrada: EntradaConsignas): ConsignasArmadas {
  const { pedido, textoMaterial, anio } = entrada;
  const cantidad = entrada.cantidad ?? 8;
  const nombre = entrada.tema.trim() || "el tema";
  const curso = nombreDelAnio(anio);

  if (textoMaterial.trim().length > 200) {
    return {
      tema: nombre,
      origen: "material",
      consignas: elegirPorNivel(desdeMaterial(nombre, textoMaterial, cantidad * 2), anio, cantidad),
      nota: `Salieron del material que cargaste de ${nombre}, con el nivel de ${curso}. Resolvelas en la carpeta y después verificá contra el apunte.`,
    };
  }

  const delBanco = buscarEnBanco(pedido) ?? buscarEnBanco(nombre);
  if (delBanco) {
    return {
      tema: delBanco.nombre,
      materia: delBanco.materia,
      origen: "banco",
      consignas: elegirPorNivel(delBanco.preguntas, anio, cantidad),
      nota: `Consignas de ${delBanco.materia} sobre ${delBanco.nombre}, con el nivel de ${curso}. Si cargás tu apunte en el tutor, las próximas salen de tu propia carpeta.`,
    };
  }

  return {
    tema: nombre,
    origen: "esquema",
    consignas: elegirPorNivel(ESQUEMA.map((plantilla) => plantilla(nombre)), anio, cantidad),
    nota: `No tengo este tema cargado ni encontré material tuyo, así que estas consignas son el esquema general, adaptado a ${curso}. Cargá el apunte en el tutor y te armo preguntas sobre tu propio texto.`,
  };
}

/** Saca el tema de un pedido del tipo "hacéme preguntas de Biología sobre la fotosíntesis". */
export function temaDelPedido(texto: string): string {
  const limpio = texto.trim().replace(/[¿?¡!.]+/g, " ").replace(/\s+/g, " ");
  const sobre = limpio.match(/\bsobre\s+(.+)$/i);
  if (sobre) return recortar(mayuscula(sobre[1].trim()), 60);

  const de = limpio.match(/\b(?:de|del|acerca de)\s+(.+)$/i);
  if (de) return recortar(mayuscula(de[1].trim()), 60);

  return "";
}

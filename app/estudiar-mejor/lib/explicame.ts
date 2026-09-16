import { crearId } from "./id";
import { analizarMaterial, cobertura, señalesDeRazonamiento } from "./texto";
import type { HuecoRazonamiento } from "./tipos";

/**
 * Modo "Explicámelo vos": el alumno explica, la plataforma marca los huecos del
 * razonamiento. Nunca completa la explicación ni dice qué idea falta: dice que
 * falta y pregunta hasta que el alumno la encuentre.
 */

export interface DiagnosticoExplicacion {
  solidez: number;
  cobertura: number;
  ideasFaltantes: number;
  huecos: HuecoRazonamiento[];
  fortalezas: string[];
  aciertos: number;
  intentos: number;
}

export function revisarExplicacion(
  explicacion: string,
  materialDelTema: string,
  tema: string,
): DiagnosticoExplicacion {
  const analisis = analizarMaterial(materialDelTema);
  const esperados = analisis.terminos.slice(0, 10);
  const resultado = cobertura(explicacion, esperados);
  const señales = señalesDeRazonamiento(explicacion, tema);

  const huecos: HuecoRazonamiento[] = [];
  const fortalezas: string[] = [];
  const agregar = (titulo: string, pregunta: string, gravedad: HuecoRazonamiento["gravedad"]) => {
    huecos.push({ id: crearId("hueco"), titulo, pregunta, gravedad });
  };

  const hayMaterial = esperados.length > 0;
  const coberturaOk = !hayMaterial || resultado.porcentaje >= 60;

  if (hayMaterial && resultado.faltantes.length > 0) {
    agregar(
      `Quedaron ${resultado.faltantes.length} ideas del material sin aparecer`,
      "Volvé a tu material y buscá qué concepto central no nombraste. No te digo cuál: eso es parte del ejercicio.",
      resultado.porcentaje < 40 ? "alta" : "media",
    );
  } else if (hayMaterial) {
    fortalezas.push("Tocaste todas las ideas centrales del material.");
  }

  if (señales.palabras < 40) {
    agregar(
      "La explicación es demasiado corta para ver tu razonamiento",
      "Sumá dos oraciones: una que explique el porqué y otra con un ejemplo propio.",
      "alta",
    );
  } else {
    fortalezas.push("Te extendiste lo suficiente como para mostrar cómo pensás.");
  }

  if (señales.causales === 0) {
    agregar(
      "Contaste qué pasa, pero no por qué pasa",
      `¿Por qué ocurre lo que describís en ${tema}? Sumá al menos un “porque” y sostenelo.`,
      "alta",
    );
  } else {
    fortalezas.push("Usaste conectores causales: eso muestra que estás explicando, no repitiendo.");
  }

  if (señales.ejemplos === 0) {
    agregar(
      "Falta un ejemplo propio",
      `¿Qué situación tuya, fuera de la escuela, sirve para mostrar ${tema} funcionando?`,
      "media",
    );
  } else {
    fortalezas.push("Diste un ejemplo: es la prueba más rápida de que entendiste.");
  }

  if (señales.definiciones === 0) {
    agregar(
      "No arrancás definiendo de qué hablás",
      "¿Con qué frase empezarías para que alguien que no vio el tema entienda de qué se trata?",
      "media",
    );
  }

  if (señales.vaguedades >= 2) {
    agregar(
      "Aparecen palabras comodín (“cosa”, “algo”, “o sea”)",
      "Reemplazá cada comodín por el nombre técnico que corresponde. ¿Cuál es en cada caso?",
      "media",
    );
  }

  if (señales.circular) {
    agregar(
      "Definiste el tema usando el mismo tema",
      `¿A qué categoría más general pertenece ${tema}? Empezá por ahí y después diferencialo.`,
      "alta",
    );
  }

  if (señales.comparaciones === 0 && esperados.length > 3) {
    agregar(
      "No aparece ninguna comparación",
      `¿Con qué otro concepto se puede confundir ${tema}? ¿En qué se diferencian?`,
      "baja",
    );
  }

  const controles = [
    coberturaOk,
    señales.palabras >= 40,
    señales.causales > 0,
    señales.ejemplos > 0,
    señales.definiciones > 0,
    señales.vaguedades < 2,
    !señales.circular,
  ];
  const aciertos = controles.filter(Boolean).length;

  return {
    solidez: Math.round((aciertos / controles.length) * 100),
    cobertura: hayMaterial ? resultado.porcentaje : 0,
    ideasFaltantes: resultado.faltantes.length,
    huecos,
    fortalezas,
    aciertos,
    intentos: controles.length,
  };
}

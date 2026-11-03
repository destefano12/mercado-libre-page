import * as THREE from "three";
import { PAQ } from "./modelos";
import { easeOut, lerp, ss } from "./util";

/*
 * Coreografía del ritual en función del progreso de scroll p ∈ [0, 1].
 * Todo es función pura de p (salvo el vapor y la cámara en mano, que respiran
 * con el tiempo), así volver hacia arriba rebobina la escena.
 *
 *  0.00–0.24  se abre el paquete
 *  0.22–0.64  se levanta, se inclina y vuelca la yerba en el mate
 *  0.63–0.75  vuelve a la mesa
 *  0.64–0.72  el mate se inclina y se forma la montañita
 *  0.72–0.86  entra la bombilla
 *  0.84–0.965 llega el termo y ceba
 *  0.965–1    sale el termo, queda el mate humeando
 */

export const ALTURA_LLENO = 0.93;
export const nivelYerba = (p: number) => lerp(0.06, ALTURA_LLENO, ss(0.38, 0.64, p));
export const alturaMontaña = (p: number) => 0.13 * ss(0.42, 0.66, p);
export const ladeo = (p: number) => ss(0.66, 0.72, p);

export function posePaquete(p: number) {
  const apertura = ss(0.08, 0.22, p) * (1 - ss(0.72, 0.8, p) * 0.75);
  const ida = ss(0.22, 0.36, p);
  const vuelta = ss(0.63, 0.75, p);
  const m = ida * (1 - vuelta);
  const vertiendo = ss(0.36, 0.4, p) * (1 - ss(0.6, 0.63, p));
  // Sacudidas leves de la mano mientras vuelca
  const temblor = Math.sin(p * 1400) * 0.01 * vertiendo;
  const reposo = PAQ.alto / 2;
  const x = lerp(lerp(-1.5, -0.95, vuelta), -0.66, m) + temblor;
  const y = lerp(reposo, 2.08, m) + Math.sin(p * 900) * 0.007 * vertiendo;
  const z = lerp(lerp(0.2, -1.25, vuelta), 0, m);
  const rz = lerp(0, -2.0, easeOut(m)) + Math.sin(p * 600) * 0.025 * vertiendo;
  const ry = lerp(0.42, 0, ss(0.2, 0.32, p)) + 0.3 * vuelta;
  // Cuánta yerba queda adentro
  const contenido = 1 - ss(0.38, 0.62, p) * 0.92;
  return { x, y, z, rz, ry, apertura, contenido, vertiendo };
}

/** Centro de la boca del paquete en coordenadas del mundo. */
export function bocaPaquete(p: number, destino = new THREE.Vector3()) {
  const { x, y, z, rz } = posePaquete(p);
  const h = PAQ.alto / 2 + 0.02;
  return destino.set(x - Math.sin(rz) * h, y + Math.cos(rz) * h, z);
}

export function inclinacionMate(p: number) {
  return 0.22 * ss(0.64, 0.7, p) * (1 - ss(0.88, 0.93, p));
}

export function poseTermo(p: number) {
  const entrada = ss(0.84, 0.9, p);
  const salida = ss(0.965, 1, p);
  const reposo = 0.6;
  if (salida > 0) {
    return { x: lerp(1.0, 1.55, salida), y: lerp(1.92, reposo, easeOut(salida)), z: lerp(0.05, -0.9, salida), rz: 1.85 * (1 - salida) };
  }
  return { x: lerp(3.4, 1.0, entrada), y: lerp(reposo, 1.92, easeOut(entrada)), z: lerp(0.4, 0.05, entrada), rz: 1.85 * ss(0.865, 0.9, p) };
}

/** Cuánto está saliendo el agua (0..1). */
export const caudal = (p: number) => ss(0.895, 0.905, p) * (1 - ss(0.955, 0.965, p));
/** Cuánta agua hay en el hueco (sube al cebar y se absorbe un poco después). */
export const charco = (p: number) => ss(0.9, 0.95, p) * (1 - 0.35 * ss(0.97, 1, p));
export const espuma = (p: number) => ss(0.915, 0.97, p);
export const vapor = (p: number) => ss(0.9, 0.97, p);

export function poseBombilla(p: number) {
  const ins = ss(0.72, 0.86, p);
  return { visible: ins > 0, y: lerp(3.6, 0.2, easeOut(ins)), insercion: ins };
}

/** Lugar del hueco (donde va el agua y la bombilla), en coordenadas locales del mate. */
export const HUECO = new THREE.Vector3(-0.15, 0, 0.06);

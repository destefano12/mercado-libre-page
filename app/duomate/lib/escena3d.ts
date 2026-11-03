import * as THREE from "three";
import { crearAgua } from "./ritual3d/agua";
import {
  caudal,
  charco,
  espuma,
  HUECO,
  inclinacionMate,
  poseBombilla,
  posePaquete,
  poseTermo,
  vapor,
} from "./ritual3d/coreografia";
import { crearCiclorama, crearHDRI, DIRECCION_VENTANA } from "./ritual3d/entorno";
import { BOCA_Y, crearBombilla, crearContacto, crearMate, crearMesa, crearPaquete, crearTermo, PAQ } from "./ritual3d/modelos";
import { crearPostpro } from "./ritual3d/postpro";
import {
  texturaCalabaza,
  texturaCepillado,
  texturaCincelado,
  texturaContacto,
  texturaCuero,
  texturaEspuma,
  texturaFibraPapel,
  texturaMadera,
  texturasPaquete,
  texturasTermo,
  texturaYerba,
} from "./ritual3d/texturas";
import { crearVapor } from "./ritual3d/vapor";
import { crearYerba } from "./ritual3d/yerba";
import { ceder, clamp01, curvaLlaves, lerp, ruido1, ss } from "./ritual3d/util";

/*
 * Ritual del mate en 3D, manejado por el scroll.
 *
 * Calidad fotográfica sin descargar assets: HDRI procedural filtrado con PMREM,
 * materiales PBR con texturas generadas (cuero, alpaca cincelada, madera,
 * papel), sombras suaves + sombras de contacto, agua con transmisión, vapor
 * volumétrico y postprocesado (profundidad de campo, bloom, ACES y grading).
 *
 * La escena es función del progreso `p` (0 → 1): hacer scroll hacia atrás la
 * rebobina. Lo único que depende del tiempo es lo que "vive" (vapor, ondas,
 * polvo flotando y la cámara en mano), así la imagen nunca queda congelada.
 */

export type Escena = {
  setProgreso: (p: number) => void;
  redimensionar: () => void;
  activar: (activa: boolean) => void;
  destruir: () => void;
};

type Calidad = "alta" | "media";

function detectarCalidad(): Calidad {
  const movil = matchMedia("(pointer: coarse)").matches || Math.min(screen.width, screen.height) < 700;
  const nucleos = navigator.hardwareConcurrency ?? 4;
  return movil || nucleos <= 4 ? "media" : "alta";
}

/* ---------- cámara cinematográfica: llaves por progreso ---------- */
// az: azimut alrededor del objetivo (rad), el: elevación (rad), d: distancia, fov en grados.
const LLAVES = {
  t: [0.0, 0.1, 0.22, 0.34, 0.46, 0.58, 0.68, 0.79, 0.88, 0.935, 1.0],
  az: [-0.62, -0.78, -0.5, -0.18, 0.02, 0.16, 0.34, 0.5, 0.38, 0.16, -0.12],
  el: [0.15, 0.2, 0.3, 0.46, 0.66, 0.74, 0.42, 0.24, 0.32, 0.46, 0.3],
  d: [8.2, 4.6, 5.3, 4.9, 4.3, 3.7, 4.8, 5.3, 5.9, 4.1, 5.2],
  fov: [30, 27, 29, 30, 30, 28, 30, 27, 30, 25, 29],
  // objetivo
  ox: [-0.55, -1.35, -0.85, -0.25, 0.0, 0.0, 0.0, 0.0, 0.42, 0.02, 0.12],
  oy: [0.8, 0.8, 1.35, 1.45, 1.15, 1.02, 0.9, 1.15, 1.35, 1.2, 0.95],
  oz: [0.0, 0.2, 0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
  // punto de foco (nítido)
  fx: [-0.4, -1.45, -0.8, -0.3, 0.0, 0.0, 0.0, -0.05, 0.3, -0.12, 0.0],
  fy: [0.8, 1.05, 1.6, 1.4, 1.0, 0.95, 0.95, 1.25, 1.3, 1.0, 1.0],
  fz: [0.0, 0.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.06, 0.0],
  // apertura (más alta = menos profundidad de campo)
  ap: [3.2, 6.5, 4.0, 4.2, 5.0, 6.5, 4.5, 6.0, 3.6, 7.5, 4.6],
};
const k = (serie: number[], p: number) => curvaLlaves(LLAVES.t, serie, p);

export async function crearEscena(canvas: HTMLCanvasElement): Promise<Escena> {
  const calidad = detectarCalidad();
  const reducirMovimiento = matchMedia("(prefers-reduced-motion: reduce)").matches;
  let ratioMax = Math.min(window.devicePixelRatio, calidad === "alta" ? 1.75 : 1.25);
  let ratio = ratioMax;

  const renderer = new THREE.WebGLRenderer({ canvas, antialias: false, alpha: false, powerPreference: "high-performance", stencil: false });
  renderer.setPixelRatio(ratio);
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 0.78;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFShadowMap;
  renderer.localClippingEnabled = true;
  renderer.setClearColor(0xe9dfcc);

  const escena = new THREE.Scene();
  const camara = new THREE.PerspectiveCamera(30, 1, 0.1, 60);

  // ---------- iluminación: HDRI + sol de ventana ----------
  const pmrem = new THREE.PMREMGenerator(renderer);
  const hdri = crearHDRI(calidad === "alta" ? 1024 : 512);
  const entorno = pmrem.fromEquirectangular(hdri).texture;
  hdri.dispose();
  escena.environment = entorno;
  escena.environmentIntensity = 0.6;
  await ceder();

  const sol = new THREE.DirectionalLight(0xfff0dc, 2.0);
  sol.position.copy(DIRECCION_VENTANA).multiplyScalar(9);
  sol.castShadow = true;
  sol.shadow.mapSize.setScalar(calidad === "alta" ? 2048 : 1024);
  Object.assign(sol.shadow.camera, { left: -3.2, right: 3.2, top: 3.2, bottom: -3.2, near: 1, far: 20 });
  sol.shadow.bias = -0.00025;
  sol.shadow.normalBias = 0.02;
  sol.shadow.radius = 5;
  escena.add(sol);

  escena.add(crearCiclorama());

  // ---------- texturas (se generan de a una para no trabar la página) ----------
  const res = calidad === "alta" ? 1024 : 512;
  const tCuero = texturaCuero(res);
  await ceder();
  const tCincelado = texturaCincelado();
  await ceder();
  const tCepillado = texturaCepillado(res / 2);
  await ceder();
  const tMadera = texturaMadera(res);
  await ceder();
  const tPaquete = texturasPaquete();
  const tFibra = texturaFibraPapel(512);
  await ceder();
  const tYerba = texturaYerba(res);
  await ceder();
  const tCalabaza = texturaCalabaza(res);
  const tTermo = texturasTermo();
  const tContacto = texturaContacto();
  const tEspuma = texturaEspuma();
  await ceder();

  // ---------- objetos ----------
  escena.add(crearMesa(tMadera));

  const mate = crearMate({ cuero: tCuero, cincelado: tCincelado, cepillado: tCepillado, calabaza: tCalabaza });
  escena.add(mate.grupo);
  const sombraMate = crearContacto(tContacto, 0.78, 0.75);
  escena.add(sombraMate);

  const bombilla = crearBombilla(mate.matAlpaca);
  mate.grupo.add(bombilla);

  const paquete = crearPaquete({ ...tPaquete, fibra: tFibra, yerba: tYerba });
  escena.add(paquete.grupo);
  const sombraPaq = crearContacto(tContacto, 0.85, 0.7);
  sombraPaq.scale.set(1, 0.7, 1);
  escena.add(sombraPaq);

  const matAcero = new THREE.MeshPhysicalMaterial({
    map: tCepillado.map,
    normalMap: tCepillado.normalMap,
    roughnessMap: tCepillado.roughnessMap,
    normalScale: new THREE.Vector2(0.3, 0.3),
    metalness: 1,
    roughness: 0.75,
    anisotropy: 0.7,
    color: 0xdfe2e6,
  });
  const termo = crearTermo(tTermo, matAcero);
  escena.add(termo);
  const sombraTermo = crearContacto(tContacto, 0.6, 0.7);
  escena.add(sombraTermo);

  const yerba = crearYerba({ mate: mate.grupo, escena, textura: tYerba, calidad });
  const agua = crearAgua(escena, mate.grupo, tEspuma, calidad);
  const vaporMate = crearVapor(escena, calidad === "alta" ? 6 : 4);

  const post = crearPostpro(renderer, escena, camara, calidad);
  await ceder();

  // ---------- actualización ----------
  let progreso = 0;
  let activa = true;
  let raf = 0;
  const reloj = new THREE.Timer();
  const objetivo = new THREE.Vector3();
  const foco = new THREE.Vector3();
  const tmp = new THREE.Vector3();
  const pico = new THREE.Vector3();
  const ctrl = new THREE.Vector3();
  const destino = new THREE.Vector3();
  const bocaMate = new THREE.Vector3();
  const dirCam = new THREE.Vector3();

  function actualizar(t: number) {
    const p = progreso;

    // Mate
    mate.grupo.rotation.z = inclinacionMate(p);
    mate.grupo.updateMatrixWorld(true);

    // Paquete
    const pp = posePaquete(p);
    paquete.grupo.position.set(pp.x, pp.y, pp.z);
    paquete.grupo.rotation.set(0, pp.ry, pp.rz);
    paquete.abrir(pp.apertura);
    paquete.nivel(pp.contenido);
    const altPaq = pp.y - PAQ.alto / 2;
    sombraPaq.position.set(pp.x, 0.002, pp.z);
    sombraPaq.rotation.z = -pp.ry;
    sombraPaq.material.opacity = 0.7 * (1 - ss(0.0, 0.5, altPaq));
    sombraPaq.scale.setScalar(1 + altPaq * 0.8);

    // Yerba
    yerba.actualizar(p, t);
    yerba.setMojado(ss(0.9, 0.96, p));

    // Bombilla (clavada en el hueco, apoyada contra la pared)
    const pb = poseBombilla(p);
    bombilla.visible = pb.visible;
    bombilla.position.set(HUECO.x + 0.02, pb.y, HUECO.z - 0.02);
    bombilla.rotation.set(0.05, -0.75, 0.13);

    // Termo y agua
    const pt = poseTermo(p);
    termo.position.set(pt.x, pt.y, pt.z);
    termo.rotation.set(0, -0.35, pt.rz);
    termo.visible = p > 0.835;
    termo.updateMatrixWorld(true);
    const altTermo = pt.y - 0.6;
    sombraTermo.visible = termo.visible;
    sombraTermo.position.set(pt.x, 0.002, pt.z);
    sombraTermo.material.opacity = 0.7 * (1 - ss(0, 0.6, altTermo));
    sombraTermo.scale.setScalar(1 + altTermo);

    const q = caudal(p);
    const yHueco = yerba.alturaEn(HUECO.x, HUECO.z, p);
    if (q > 0.01) {
      pico.set(0, 0.94, 0).applyMatrix4(termo.matrixWorld);
      tmp.set(0, 1, 0).transformDirection(termo.matrixWorld);
      destino.set(HUECO.x, yHueco + 0.01, HUECO.z).applyMatrix4(mate.grupo.matrixWorld);
      ctrl.copy(pico).addScaledVector(tmp, 0.32);
      ctrl.y = Math.max(ctrl.y, destino.y + 0.05);
    }
    agua.actualizar({ t, pico, ctrl, destino, caudal: q, charco: charco(p), espuma: espuma(p), hueco: HUECO, yHueco });

    // Vapor desde la boca del mate (y un poco del chorro mientras cae)
    bocaMate.set(HUECO.x * 0.5, BOCA_Y + 0.02, 0).applyMatrix4(mate.grupo.matrixWorld);
    vaporMate.actualizar(t, bocaMate, vapor(p) * (reducirMovimiento ? 0.7 : 1), camara.position);

    // Cámara
    const aspecto = camara.aspect;
    let dist = k(LLAVES.d, p);
    if (aspecto < 1) dist *= lerp(1.85, 1, clamp01((aspecto - 0.45) / 0.55));
    const mano = reducirMovimiento ? 0 : 1;
    const az = k(LLAVES.az, p) + ruido1(t * 0.35, 1) * 0.006 * mano;
    const el = k(LLAVES.el, p) + ruido1(t * 0.3, 2) * 0.004 * mano;
    dist *= 1 + Math.sin(t * 0.25) * 0.006 * mano;
    objetivo.set(k(LLAVES.ox, p), k(LLAVES.oy, p), k(LLAVES.oz, p));
    camara.position.set(objetivo.x + dist * Math.cos(el) * Math.sin(az), objetivo.y + dist * Math.sin(el), objetivo.z + dist * Math.cos(el) * Math.cos(az));
    camara.lookAt(objetivo);
    camara.rotateZ(ruido1(t * 0.2, 3) * 0.003 * mano);
    const fov = k(LLAVES.fov, p);
    if (Math.abs(camara.fov - fov) > 0.01) {
      camara.fov = fov;
      camara.updateProjectionMatrix();
    }

    // Foco: distancia a lo largo del eje de la cámara hasta el punto de interés
    foco.set(k(LLAVES.fx, p), k(LLAVES.fy, p), k(LLAVES.fz, p));
    camara.getWorldDirection(dirCam);
    const dFoco = tmp.copy(foco).sub(camara.position).dot(dirCam);
    post.setFoco(dFoco, k(LLAVES.ap, p) * ratio, (calidad === "alta" ? 11 : 7) * ratio);
    yerba.setEscalaPuntos(canvas.clientHeight * ratio * 0.9);

    post.render(t);
  }

  // Ajuste automático: si la placa no llega, baja la resolución interna.
  let muestras = 0;
  let acumulado = 0;
  let anterior = performance.now();

  function bucle() {
    raf = requestAnimationFrame(bucle);
    if (!activa) return;
    const ahora = performance.now();
    const dt = ahora - anterior;
    anterior = ahora;
    reloj.update();
    actualizar(reloj.getElapsed());
    if (dt < 200) {
      acumulado += dt;
      muestras++;
    }
    if (muestras >= 90) {
      const medio = acumulado / muestras;
      if (medio > 26 && ratio > 1) {
        ratio = Math.max(1, ratio - 0.25);
        ratioMax = ratio;
        redimensionar();
      }
      muestras = 0;
      acumulado = 0;
    }
  }

  function redimensionar() {
    const w = canvas.clientWidth || 1;
    const h = canvas.clientHeight || 1;
    renderer.setPixelRatio(ratio);
    renderer.setSize(w, h, false);
    post.setSize(w, h, ratio);
    camara.aspect = w / h;
    // En pantallas anchas la escena va a la derecha (los textos quedan a la izquierda);
    // en el celular sube un poco para dejar lugar a la tarjeta de abajo.
    if (w / h > 1.1) camara.setViewOffset(w, h, -w * 0.17, 0, w, h);
    else camara.setViewOffset(w, h, 0, h * 0.1, w, h);
    camara.updateProjectionMatrix();
  }

  redimensionar();
  bucle();

  return {
    setProgreso: (p) => {
      progreso = clamp01(p);
    },
    redimensionar,
    activar: (v) => {
      activa = v;
      if (v) anterior = performance.now();
    },
    destruir: () => {
      cancelAnimationFrame(raf);
      escena.traverse((o) => {
        const m = o as THREE.Mesh;
        m.geometry?.dispose();
        const mats = Array.isArray(m.material) ? m.material : m.material ? [m.material] : [];
        mats.forEach((mt) => {
          Object.values(mt).forEach((v) => v instanceof THREE.Texture && v.dispose());
          mt.dispose();
        });
      });
      post.dispose();
      entorno.dispose();
      pmrem.dispose();
      renderer.dispose();
    },
  };
}

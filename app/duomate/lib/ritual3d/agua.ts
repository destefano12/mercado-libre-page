import * as THREE from "three";
import { azar, llenar, normalDesdeAltura, nuevoMapa, ruido, ss, texturaDatos } from "./util";

/*
 * Agua del cebado:
 *  - chorro: cilindro doblado en el vertex shader sobre una curva de Bézier,
 *    con material de transmisión (refracta lo que hay detrás) y ondulación,
 *  - charco en el hueco con ondas animadas,
 *  - espuma y burbujas que se forman sobre la yerba,
 *  - gotitas que salpican al impactar.
 */

function texturaOndas() {
  const m = nuevoMapa(256, 256);
  llenar(m, (u, v) => {
    const x = u - 0.5;
    const y = v - 0.5;
    const r = Math.hypot(x, y);
    return Math.sin(r * 90) * 0.5 * Math.exp(-r * 3) + ruido(u * 16, v * 16, 16, 2) * 0.6;
  });
  return texturaDatos(normalDesdeAltura(m, 1.2), 256, 256, false);
}

export function crearAgua(escena: THREE.Scene, mate: THREE.Group, espumaTex: THREE.Texture, calidad: "alta" | "media") {
  /* ---------- chorro ---------- */
  const uni = {
    uP0: { value: new THREE.Vector3() },
    uP1: { value: new THREE.Vector3() },
    uP2: { value: new THREE.Vector3() },
    uLargo: { value: 1 },
    uTiempo: { value: 0 },
    uRadio: { value: new THREE.Vector2(0.03, 0.017) },
  };
  const matChorro = new THREE.MeshPhysicalMaterial({
    color: 0xffffff,
    roughness: 0.02,
    metalness: 0,
    transmission: 1,
    transparent: true,
    opacity: 0.85,
    ior: 1.33,
    thickness: 0.06,
    attenuationColor: new THREE.Color(0xe8f0e6),
    attenuationDistance: 0.6,
    specularIntensity: 1,
    envMapIntensity: 1.3,
  });
  matChorro.onBeforeCompile = (s) => {
    Object.assign(s.uniforms, uni);
    s.vertexShader = s.vertexShader
      .replace(
        "#include <common>",
        `#include <common>
        uniform vec3 uP0; uniform vec3 uP1; uniform vec3 uP2;
        uniform float uLargo; uniform float uTiempo; uniform vec2 uRadio;
        vec3 dmBez(float s) { float u = 1.0 - s; return u*u*uP0 + 2.0*u*s*uP1 + s*s*uP2; }
        vec3 dmTan(float s) { return normalize(2.0*(1.0 - s)*(uP1 - uP0) + 2.0*s*(uP2 - uP1)); }`,
      )
      .replace(
        "#include <beginnormal_vertex>",
        `float dmS = position.y * uLargo;
        vec3 dmT = dmTan(dmS);
        vec3 dmRef = abs(dmT.z) < 0.9 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
        vec3 dmN = normalize(cross(dmT, dmRef));
        vec3 dmB = cross(dmT, dmN);
        vec3 dmRad = normalize(position.x * dmN + position.z * dmB);
        vec3 objectNormal = dmRad;
        #ifdef USE_TANGENT
          vec3 objectTangent = dmT;
        #endif`,
      )
      .replace(
        "#include <begin_vertex>",
        `float dmAng = atan(position.z, position.x);
        float dmOnda = 1.0 + 0.16 * sin(dmS * 46.0 - uTiempo * 26.0) * smoothstep(0.0, 0.3, dmS)
                     + 0.07 * sin(dmAng * 3.0 + dmS * 30.0 - uTiempo * 18.0);
        float dmR = mix(uRadio.x, uRadio.y, smoothstep(0.0, 0.5, dmS)) * dmOnda;
        vec3 transformed = dmBez(dmS) + dmRad * dmR;`,
      );
  };
  const geoChorro = new THREE.CylinderGeometry(1, 1, 1, 18, 90, true);
  geoChorro.translate(0, 0.5, 0);
  const chorro = new THREE.Mesh(geoChorro, matChorro);
  chorro.frustumCulled = false;
  escena.add(chorro);

  /* ---------- charco en el hueco ---------- */
  const ondas = texturaOndas();
  ondas.wrapS = ondas.wrapT = THREE.RepeatWrapping;
  const matCharco = new THREE.MeshPhysicalMaterial({
    color: 0xd9dfb8,
    roughness: 0.04,
    transmission: 0.85,
    ior: 1.33,
    thickness: 0.02,
    attenuationColor: new THREE.Color(0x8c8d3a),
    attenuationDistance: 0.08,
    normalMap: ondas,
    normalScale: new THREE.Vector2(0.4, 0.4),
    transparent: true,
    envMapIntensity: 1.4,
  });
  const charco = new THREE.Mesh(new THREE.CircleGeometry(1, 48), matCharco);
  charco.rotation.x = -Math.PI / 2;
  mate.add(charco);

  /* ---------- espuma ---------- */
  const matEspuma = new THREE.MeshStandardMaterial({ map: espumaTex, transparent: true, roughness: 0.35, depthWrite: false, alphaTest: 0.02 });
  const espuma = new THREE.Mesh(new THREE.CircleGeometry(1, 48), matEspuma);
  espuma.rotation.x = -Math.PI / 2;
  espuma.renderOrder = 2;
  mate.add(espuma);

  const nB = calidad === "alta" ? 160 : 70;
  const burbujas = new THREE.InstancedMesh(
    new THREE.SphereGeometry(1, 12, 8, 0, Math.PI * 2, 0, Math.PI / 2),
    new THREE.MeshPhysicalMaterial({ color: 0xf2f1df, roughness: 0.08, clearcoat: 1, clearcoatRoughness: 0.05, transparent: true, opacity: 0.85 }),
    nB,
  );
  mate.add(burbujas);
  const rb = azar(31);
  const datosB = Array.from({ length: nB }, () => {
    const a = rb() * Math.PI * 2;
    const r = Math.pow(rb(), 0.7);
    return { a, r, tam: 0.004 + Math.pow(rb(), 3) * 0.014, ciclo: 2 + rb() * 5, fase: rb() * 10, aparece: rb() };
  });

  /* ---------- salpicaduras ---------- */
  const nG = calidad === "alta" ? 48 : 24;
  const gotas = new THREE.InstancedMesh(
    new THREE.SphereGeometry(1, 10, 8),
    new THREE.MeshPhysicalMaterial({ color: 0xffffff, roughness: 0.02, transmission: 1, ior: 1.33, thickness: 0.01 }),
    nG,
  );
  gotas.frustumCulled = false;
  escena.add(gotas);
  const rg = azar(13);
  const datosG = Array.from({ length: nG }, () => ({
    dir: new THREE.Vector3(rg() - 0.5, 0, rg() - 0.5).normalize(),
    vel: 0.3 + rg() * 0.6,
    alto: 0.4 + rg() * 0.9,
    ciclo: 0.35 + rg() * 0.4,
    fase: rg(),
    tam: 0.004 + rg() * 0.007,
  }));

  const dummy = new THREE.Object3D();
  const impactoMundo = new THREE.Vector3();

  /**
   * pico, control y destino del chorro en el mundo; caudal 0..1; nivel del charco
   * 0..1; espuma 0..1; posición local del hueco y la altura de la yerba ahí.
   */
  function actualizar(o: {
    t: number;
    pico: THREE.Vector3;
    ctrl: THREE.Vector3;
    destino: THREE.Vector3;
    caudal: number;
    charco: number;
    espuma: number;
    hueco: THREE.Vector3;
    yHueco: number;
  }) {
    const { t } = o;
    uni.uTiempo.value = t;
    chorro.visible = o.caudal > 0.01;
    if (chorro.visible) {
      uni.uP0.value.copy(o.pico);
      uni.uP1.value.copy(o.ctrl);
      uni.uP2.value.copy(o.destino);
      // al empezar el chorro "crece" desde el pico; al cortar, se adelgaza
      uni.uLargo.value = ss(0, 0.6, o.caudal);
      uni.uRadio.value.set(0.026 * (0.4 + 0.6 * o.caudal), 0.016 * (0.4 + 0.6 * o.caudal));
    }

    charco.visible = o.charco > 0.01;
    const rc = 0.06 + 0.13 * o.charco;
    charco.position.set(o.hueco.x, o.yHueco + 0.008 + o.charco * 0.012, o.hueco.z);
    charco.scale.setScalar(rc);
    ondas.offset.set(Math.sin(t * 0.7) * 0.05, t * (0.04 + o.caudal * 0.4));
    matCharco.normalScale.setScalar(0.25 + o.caudal * 0.6);

    espuma.visible = o.espuma > 0.01;
    espuma.position.set(o.hueco.x + 0.02, o.yHueco + 0.022 + o.charco * 0.012, o.hueco.z);
    espuma.scale.setScalar(rc * (1.05 + 0.5 * o.espuma));
    espuma.rotation.z = t * 0.03;
    matEspuma.opacity = o.espuma;

    burbujas.visible = o.espuma > 0.01;
    if (burbujas.visible) {
      for (let i = 0; i < nB; i++) {
        const b = datosB[i];
        const vive = o.espuma > b.aparece;
        const ciclo = ((t + b.fase) % b.ciclo) / b.ciclo;
        const s = vive ? b.tam * Math.sin(Math.min(1, ciclo * 1.15) * Math.PI) ** 0.3 * (ciclo < 0.97 ? 1 : 0) : 0;
        const r = rc * (0.5 + b.r * 0.9);
        dummy.position.set(o.hueco.x + Math.cos(b.a) * r, o.yHueco + 0.022 + o.charco * 0.012, o.hueco.z + Math.sin(b.a) * r);
        dummy.scale.set(s, s * 0.8, s);
        dummy.rotation.set(0, 0, 0);
        dummy.updateMatrix();
        burbujas.setMatrixAt(i, dummy.matrix);
      }
      burbujas.instanceMatrix.needsUpdate = true;
    }

    gotas.visible = o.caudal > 0.15;
    if (gotas.visible) {
      impactoMundo.copy(o.destino);
      for (let i = 0; i < nG; i++) {
        const g = datosG[i];
        const f = ((t / g.ciclo + g.fase) % 1 + 1) % 1;
        const d = g.vel * f * 0.35;
        dummy.position.set(
          impactoMundo.x + g.dir.x * d,
          impactoMundo.y + g.alto * f * 0.3 - 1.4 * f * f * 0.3,
          impactoMundo.z + g.dir.z * d,
        );
        const s = g.tam * (1 - f) * o.caudal;
        dummy.scale.setScalar(s);
        dummy.updateMatrix();
        gotas.setMatrixAt(i, dummy.matrix);
      }
      gotas.instanceMatrix.needsUpdate = true;
    }
  }

  return { actualizar };
}

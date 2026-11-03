import * as THREE from "three";
import { alturaMontaña, bocaPaquete, HUECO, ladeo, nivelYerba, posePaquete } from "./coreografia";
import { PAQ, PUNTOS_PERFIL, radioEn } from "./modelos";
import { azar, lerp, ruido, ss } from "./util";

/*
 * Yerba en tres escalas:
 *  - la cama dentro del mate (volumen recortado + superficie con relieve y montañita),
 *  - copos de hoja y palitos sueltos (instancias) que caen del paquete y quedan arriba,
 *  - polvo fino (puntos) que sale en nube y queda flotando un rato.
 */

const VERDES = [0x5f7d2e, 0x6f8f3c, 0x86a54f, 0x4f6a27, 0x98b465, 0x7a9440, 0xa8b97a, 0x667a36];
const PALOS = [0xcdbb8a, 0xbba675, 0xd8c99d, 0xa99464];

/** Copo de hoja: polígono irregular apenas curvado. */
function geometriaCopo() {
  const forma = new THREE.Shape();
  const r = azar(12);
  const n = 7;
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2;
    const rr = 0.5 + r() * 0.5;
    const x = Math.cos(a) * rr;
    const y = Math.sin(a) * rr * 0.62;
    if (i === 0) forma.moveTo(x, y);
    else forma.lineTo(x, y);
  }
  const g = new THREE.ShapeGeometry(forma);
  const pos = g.attributes.position as THREE.BufferAttribute;
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i);
    pos.setZ(i, x * x * 0.18);
  }
  g.rotateX(-Math.PI / 2);
  g.computeVertexNormals();
  return g;
}

/** Inyecta oscurecimiento y brillo de "yerba mojada" alrededor del hueco. */
function mojable(mat: THREE.MeshStandardMaterial, u: { uMojado: { value: number }; uCentro: { value: THREE.Vector3 }; uRadio: { value: number } }) {
  mat.onBeforeCompile = (s) => {
    Object.assign(s.uniforms, u);
    s.vertexShader = s.vertexShader
      .replace("#include <common>", "#include <common>\nvarying vec3 vMundo;")
      .replace(
        "#include <project_vertex>",
        `#include <project_vertex>
        vec4 dmW = vec4(transformed, 1.0);
        #ifdef USE_INSTANCING
          dmW = instanceMatrix * dmW;
        #endif
        vMundo = (modelMatrix * dmW).xyz;`,
      );
    s.fragmentShader = s.fragmentShader
      .replace("#include <common>", "#include <common>\nvarying vec3 vMundo;\nuniform float uMojado;\nuniform vec3 uCentro;\nuniform float uRadio;")
      .replace(
        "#include <color_fragment>",
        `#include <color_fragment>
        float dmD = length(vMundo.xz - uCentro.xz);
        float dmM = uMojado * smoothstep(uRadio, uRadio * 0.25, dmD);
        diffuseColor.rgb *= mix(1.0, 0.48, dmM);`,
      )
      .replace(
        "#include <roughnessmap_fragment>",
        `#include <roughnessmap_fragment>
        roughnessFactor = mix(roughnessFactor, 0.28, dmM);`,
      );
  };
}

export function crearYerba(opts: { mate: THREE.Group; escena: THREE.Scene; textura: { map: THREE.Texture; normalMap: THREE.Texture }; calidad: "alta" | "media" }) {
  const { mate, escena, textura, calidad } = opts;
  const uMojado = { uMojado: { value: 0 }, uCentro: { value: new THREE.Vector3() }, uRadio: { value: 0.28 } };

  /* ---------- cama dentro del mate ---------- */
  const planoCorte = new THREE.Plane(new THREE.Vector3(0, -1, 0), 0);
  const tx = textura.map.clone();
  tx.repeat.set(2, 2);
  tx.needsUpdate = true;
  const nx = textura.normalMap.clone();
  nx.repeat.set(2, 2);
  nx.needsUpdate = true;
  const matVol = new THREE.MeshStandardMaterial({ map: tx, normalMap: nx, roughness: 0.95, clippingPlanes: [planoCorte] });
  const volumen = new THREE.Mesh(
    new THREE.LatheGeometry(
      [new THREE.Vector2(0, 0.06), ...PUNTOS_PERFIL.filter((v) => v.y > 0.07).map((v) => new THREE.Vector2(v.x * 0.905, v.y))],
      80,
    ),
    matVol,
  );
  mate.add(volumen);

  const matSup = new THREE.MeshStandardMaterial({ map: textura.map, normalMap: textura.normalMap, normalScale: new THREE.Vector2(1.2, 1.2), roughness: 0.92 });
  mojable(matSup, uMojado);
  const geoSup = new THREE.CircleGeometry(1, 96, 0, Math.PI * 2);
  // Más anillos para que el relieve tenga resolución
  const anillos = 18;
  const sup = new THREE.RingGeometry(0.0001, 1, 96, anillos);
  geoSup.dispose();
  sup.rotateX(-Math.PI / 2);
  const basePos = (sup.attributes.position as THREE.BufferAttribute).array.slice() as Float32Array;
  const superficie = new THREE.Mesh(sup, matSup);
  superficie.receiveShadow = true;
  superficie.castShadow = false;
  mate.add(superficie);

  /** Altura del relieve (en unidades del mate) en un punto normalizado del disco. */
  function relieve(x: number, z: number, p: number) {
    const montaña = alturaMontaña(p);
    const l = ladeo(p);
    const cx = 0.28 * l;
    const d2 = ((x - cx) * (x - cx)) / (0.95 * 0.95) + (z * z) / (0.9 * 0.9);
    const domo = Math.pow(Math.max(0, 1 - d2), 0.85);
    // en diagonal: de un lado alto, del otro el hueco
    const pendiente = lerp(1, 0.55 + 0.45 * ss(-0.9, 0.6, x), l);
    const hueco = l * Math.exp(-((x - HUECO.x / 0.4) ** 2 + (z - HUECO.z / 0.4) ** 2) / 0.12) * 0.55;
    const grumos = (ruido(x * 7 + 11, z * 7 + 11, 9999, 3) - 0.5) * 0.022 + (ruido(x * 19 + 3, z * 19 + 3, 9999, 4) - 0.5) * 0.009;
    return montaña * domo * pendiente - montaña * hueco + grumos * ss(0.06, 0.2, nivelYerba(p));
  }

  // Copos y palitos apoyados sobre la superficie (le dan volumen real al primer plano)
  const geoCopo = geometriaCopo();
  const nSup = calidad === "alta" ? 1600 : 800;
  const matCopo = new THREE.MeshStandardMaterial({ roughness: 0.85, side: THREE.DoubleSide });
  mojable(matCopo, uMojado);
  const coposSup = new THREE.InstancedMesh(geoCopo, matCopo, nSup);
  coposSup.receiveShadow = true;
  coposSup.castShadow = calidad === "alta";
  const rs = azar(77);
  const datosSup = Array.from({ length: nSup }, () => {
    const a = rs() * Math.PI * 2;
    const rad = Math.sqrt(rs()) * 0.97;
    return {
      x: Math.cos(a) * rad,
      z: Math.sin(a) * rad,
      rot: new THREE.Euler((rs() - 0.5) * 0.9, rs() * Math.PI * 2, (rs() - 0.5) * 0.9),
      sx: 0.011 + rs() * 0.016,
      sz: 0.6 + rs() * 0.6,
      palo: rs() < 0.14,
    };
  });
  const col = new THREE.Color();
  datosSup.forEach((d, i) => coposSup.setColorAt(i, col.setHex(d.palo ? PALOS[i % PALOS.length] : VERDES[i % VERDES.length])));
  mate.add(coposSup);

  /* ---------- lo que cae del paquete ---------- */
  const N = calidad === "alta" ? 3200 : 1500;
  const NP = calidad === "alta" ? 420 : 200;
  const NPolvo = calidad === "alta" ? 2600 : 1200;

  const hojas = new THREE.InstancedMesh(geoCopo, new THREE.MeshStandardMaterial({ roughness: 0.8, side: THREE.DoubleSide }), N);
  hojas.castShadow = calidad === "alta";
  hojas.frustumCulled = false;
  const palitos = new THREE.InstancedMesh(new THREE.CylinderGeometry(0.5, 0.5, 1, 6, 1), new THREE.MeshStandardMaterial({ roughness: 0.7 }), NP);
  palitos.frustumCulled = false;
  palitos.castShadow = calidad === "alta";
  escena.add(hojas, palitos);

  type Grano = { emision: number; duracion: number; ang: number; rad: number; ox: number; oz: number; giro: THREE.Euler; velGiro: number; sx: number; sy: number; sz: number };
  const rp = azar(42);
  const grano = (i: number, n: number, palo: boolean): Grano => ({
    emision: 0.385 + (i / n) * 0.215 + rp() * 0.01,
    duracion: 0.026 + rp() * 0.014,
    ang: rp() * Math.PI * 2,
    rad: Math.sqrt(rp()) * 0.8,
    ox: rp() - 0.5,
    oz: rp() - 0.5,
    giro: new THREE.Euler(rp() * 6, rp() * 6, rp() * 6),
    velGiro: 5 + rp() * 12,
    sx: palo ? 0.005 + rp() * 0.004 : 0.009 + rp() * 0.014,
    sy: palo ? 0.025 + rp() * 0.045 : 1,
    sz: palo ? 1 : 0.55 + rp() * 0.6,
  });
  const granos = Array.from({ length: N }, (_, i) => grano(i, N, false));
  const granosPalo = Array.from({ length: NP }, (_, i) => grano(i, NP, true));
  granos.forEach((_, i) => hojas.setColorAt(i, col.setHex(VERDES[i % VERDES.length])));
  granosPalo.forEach((_, i) => palitos.setColorAt(i, col.setHex(PALOS[i % PALOS.length])));

  // Polvo: puntos con shader propio (disco suave, tamaño con perspectiva)
  const posPolvo = new Float32Array(NPolvo * 3);
  const alfaPolvo = new Float32Array(NPolvo);
  const tamPolvo = new Float32Array(NPolvo);
  const geoPolvo = new THREE.BufferGeometry();
  geoPolvo.setAttribute("position", new THREE.BufferAttribute(posPolvo, 3));
  geoPolvo.setAttribute("aAlfa", new THREE.BufferAttribute(alfaPolvo, 1));
  geoPolvo.setAttribute("aTam", new THREE.BufferAttribute(tamPolvo, 1));
  const matPolvo = new THREE.ShaderMaterial({
    transparent: true,
    depthWrite: false,
    uniforms: { uEscala: { value: 400 }, uColor: { value: new THREE.Color(0xb8b483).convertSRGBToLinear() } },
    vertexShader: /* glsl */ `
      attribute float aAlfa;
      attribute float aTam;
      uniform float uEscala;
      varying float vAlfa;
      void main() {
        vAlfa = aAlfa;
        vec4 mv = modelViewMatrix * vec4(position, 1.0);
        gl_PointSize = aTam * uEscala / -mv.z;
        gl_Position = projectionMatrix * mv;
      }`,
    fragmentShader: /* glsl */ `
      uniform vec3 uColor;
      varying float vAlfa;
      void main() {
        vec2 c = gl_PointCoord - 0.5;
        float d = length(c);
        float a = smoothstep(0.5, 0.0, d) * vAlfa;
        if (a < 0.003) discard;
        gl_FragColor = vec4(uColor, a);
      }`,
  });
  const polvo = new THREE.Points(geoPolvo, matPolvo);
  polvo.frustumCulled = false;
  escena.add(polvo);
  const rd = azar(91);
  const motas = Array.from({ length: NPolvo }, (_, i) => ({
    emision: 0.38 + (i / NPolvo) * 0.24 + rd() * 0.01,
    vida: 0.05 + rd() * 0.06,
    deImpacto: rd() < 0.4,
    ox: rd() - 0.5,
    oy: rd() - 0.5,
    oz: rd() - 0.5,
    deriva: new THREE.Vector3((rd() - 0.5) * 0.9, 0.15 + rd() * 0.35, (rd() - 0.5) * 0.9),
    fase: rd() * 100,
    tam: 0.006 + Math.pow(rd(), 2) * 0.022,
  }));

  /* ---------- actualización ---------- */
  const dummy = new THREE.Object3D();
  const tmpBoca = new THREE.Vector3();
  const tmpCtrl = new THREE.Vector3();
  const tmpDest = new THREE.Vector3();
  const tmpPos = new THREE.Vector3();
  const planoLocal = new THREE.Plane();
  const centroMundo = new THREE.Vector3();
  let ultimoP = -1;
  const cacheBoca = new Map<number, { boca: THREE.Vector3; rz: number }>();
  const bocaEn = (e: number) => {
    const k = Math.round(e * 4000);
    let c = cacheBoca.get(k);
    if (!c) {
      c = { boca: bocaPaquete(k / 4000), rz: posePaquete(k / 4000).rz };
      cacheBoca.set(k, c);
    }
    return c;
  };

  function trayectoria(g: Grano, p: number, salida: THREE.Vector3) {
    const fase = (p - g.emision) / g.duracion;
    const { boca, rz } = bocaEn(g.emision);
    // ancho de la boca: el eje W del paquete rotado por rz
    tmpBoca
      .copy(boca)
      .add(tmpPos.set(Math.cos(rz) * g.ox * PAQ.ancho * 0.85, Math.sin(rz) * g.ox * PAQ.ancho * 0.85, g.oz * PAQ.prof * 0.8));
    tmpCtrl.set(tmpBoca.x - Math.sin(rz) * 0.2, tmpBoca.y + Math.cos(rz) * 0.2 - 0.05, tmpBoca.z);
    const yDest = nivelYerba(g.emision + g.duracion) + 0.02;
    const rDest = radioEn(yDest) * 0.85 * g.rad;
    tmpDest.set(Math.cos(g.ang) * rDest, yDest, Math.sin(g.ang) * rDest);
    const s = fase * fase * 0.7 + fase * 0.3; // acelera al caer
    const u = 1 - s;
    return salida.set(0, 0, 0).addScaledVector(tmpBoca, u * u).addScaledVector(tmpCtrl, 2 * u * s).addScaledVector(tmpDest, s * s);
  }

  function actualizar(p: number, t: number) {
    const h = nivelYerba(p);
    const hay = h > 0.065;
    volumen.visible = superficie.visible = coposSup.visible = hay;
    const rh = radioEn(h) * 0.905;

    planoLocal.set(new THREE.Vector3(0, -1, 0), h);
    planoCorte.copy(planoLocal).applyMatrix4(mate.matrixWorld);

    // mojado alrededor del hueco
    centroMundo.set(HUECO.x, h, HUECO.z).applyMatrix4(mate.matrixWorld);
    uMojado.uCentro.value.copy(centroMundo);

    if (p !== ultimoP && hay) {
      // relieve de la superficie
      const pos = sup.attributes.position as THREE.BufferAttribute;
      for (let i = 0; i < pos.count; i++) {
        const x = basePos[i * 3];
        const z = basePos[i * 3 + 2];
        const borde = ss(1.0, 0.86, Math.hypot(x, z)); // pegada a la pared, un poco más baja
        pos.setXYZ(i, x * rh, h + relieve(x, z, p) * (0.6 + 0.4 * borde) - (1 - borde) * 0.01, z * rh);
      }
      pos.needsUpdate = true;
      sup.computeVertexNormals();

      // copos apoyados: aparecen a medida que sube la cama
      const visibles = Math.floor(nSup * ss(0.4, 0.62, p));
      for (let i = 0; i < nSup; i++) {
        const d = datosSup[i];
        if (i >= visibles) {
          dummy.scale.setScalar(0);
        } else {
          dummy.position.set(d.x * rh * 0.97, h + relieve(d.x, d.z, p) + 0.004, d.z * rh * 0.97);
          dummy.rotation.copy(d.rot);
          if (d.palo) dummy.scale.set(d.sx * 0.35, d.sx * 0.35, d.sx * 2.6);
          else dummy.scale.set(d.sx, d.sx, d.sx * d.sz);
        }
        dummy.updateMatrix();
        coposSup.setMatrixAt(i, dummy.matrix);
      }
      coposSup.instanceMatrix.needsUpdate = true;
    }

    if (p !== ultimoP) {
      // hojas en el aire
      for (let i = 0; i < N; i++) {
        const g = granos[i];
        const fase = (p - g.emision) / g.duracion;
        if (fase <= 0 || fase >= 1) dummy.scale.setScalar(0);
        else {
          trayectoria(g, p, dummy.position);
          dummy.rotation.set(g.giro.x + fase * g.velGiro, g.giro.y + fase * g.velGiro * 0.7, g.giro.z);
          dummy.scale.set(g.sx, g.sx, g.sx * g.sz);
        }
        dummy.updateMatrix();
        hojas.setMatrixAt(i, dummy.matrix);
      }
      hojas.instanceMatrix.needsUpdate = true;
      for (let i = 0; i < NP; i++) {
        const g = granosPalo[i];
        const fase = (p - g.emision) / g.duracion;
        if (fase <= 0 || fase >= 1) dummy.scale.setScalar(0);
        else {
          trayectoria(g, p, dummy.position);
          dummy.rotation.set(g.giro.x + fase * g.velGiro, g.giro.y, g.giro.z + fase * g.velGiro * 0.5);
          dummy.scale.set(g.sx, g.sy, g.sx);
        }
        dummy.updateMatrix();
        palitos.setMatrixAt(i, dummy.matrix);
      }
      palitos.instanceMatrix.needsUpdate = true;
    }
    ultimoP = p;

    // polvo: depende también del tiempo (turbulencia), se actualiza siempre que haya
    let algun = false;
    for (let i = 0; i < NPolvo; i++) {
      const m = motas[i];
      const edad = (p - m.emision) / m.vida;
      if (edad <= 0 || edad >= 1) {
        alfaPolvo[i] = 0;
        continue;
      }
      algun = true;
      let x: number;
      let y: number;
      let z: number;
      if (m.deImpacto) {
        // nube que se levanta al chocar la yerba con la cama
        const hy = nivelYerba(m.emision) + 0.05;
        const e = Math.sqrt(edad);
        x = m.ox * 0.5 + m.deriva.x * e * 0.6;
        y = hy + m.deriva.y * e * 0.9;
        z = m.oz * 0.5 + m.deriva.z * e * 0.6;
      } else {
        const { boca, rz } = bocaEn(m.emision);
        const caida = edad * edad * 1.1;
        x = boca.x + Math.cos(rz) * m.ox * PAQ.ancho * 0.8 + m.deriva.x * edad * 0.5 + 0.25 * edad;
        y = boca.y + Math.sin(rz) * m.ox * PAQ.ancho * 0.8 - caida + m.deriva.y * edad * 0.4;
        z = boca.z + m.oz * PAQ.prof + m.deriva.z * edad * 0.5;
      }
      x += Math.sin(t * 0.9 + m.fase) * 0.03 * edad;
      y += Math.sin(t * 0.7 + m.fase * 1.3) * 0.02 * edad;
      z += Math.cos(t * 0.8 + m.fase) * 0.03 * edad;
      posPolvo[i * 3] = x;
      posPolvo[i * 3 + 1] = y;
      posPolvo[i * 3 + 2] = z;
      alfaPolvo[i] = Math.sin(edad * Math.PI) * (m.deImpacto ? 0.28 : 0.4);
      tamPolvo[i] = m.tam * (1 + edad * 1.5);
    }
    polvo.visible = algun;
    if (algun) {
      geoPolvo.attributes.position.needsUpdate = true;
      geoPolvo.attributes.aAlfa.needsUpdate = true;
      geoPolvo.attributes.aTam.needsUpdate = true;
    }
  }

  return {
    actualizar,
    setMojado: (v: number) => (uMojado.uMojado.value = v),
    setEscalaPuntos: (px: number) => (matPolvo.uniforms.uEscala.value = px),
    alturaEn: (xLocal: number, zLocal: number, p: number) => {
      const h = nivelYerba(p);
      const rh = radioEn(h) * 0.905;
      return h + relieve(xLocal / rh, zLocal / rh, p);
    },
  };
}

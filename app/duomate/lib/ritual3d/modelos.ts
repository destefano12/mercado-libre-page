import * as THREE from "three";
import type { MaterialPBR } from "./texturas";
import { azar, fbm, lerp, ruido, ss } from "./util";

/* ---------- perfil de la calabaza ---------- */
const PERFIL = [
  [0.0, 0.02],
  [0.22, 0.03],
  [0.4, 0.12],
  [0.52, 0.3],
  [0.555, 0.47],
  [0.53, 0.66],
  [0.46, 0.84],
  [0.385, 0.98],
  [0.36, 1.1],
].map(([r, y]) => new THREE.Vector2(r, y));
export const PUNTOS_PERFIL = new THREE.SplineCurve(PERFIL).getPoints(96);
export const BOCA_Y = 1.1;

/** Radio de la calabaza a una altura dada, interpolando el perfil. */
export function radioEn(y: number) {
  const pts = PUNTOS_PERFIL;
  if (y <= pts[0].y) return pts[0].x;
  for (let i = 1; i < pts.length; i++) {
    if (pts[i].y >= y) {
      const a = pts[i - 1];
      const b = pts[i];
      return lerp(a.x, b.x, (y - a.y) / (b.y - a.y || 1));
    }
  }
  return pts[pts.length - 1].x;
}

/* ---------- mesa ---------- */
export function crearMesa(madera: MaterialPBR) {
  const lado = 30;
  const rep = lado / 6;
  for (const t of [madera.map, madera.normalMap, madera.roughnessMap]) t.repeat.set(rep, rep);
  const mat = new THREE.MeshPhysicalMaterial({
    ...madera,
    normalScale: new THREE.Vector2(0.6, 0.6),
    roughness: 1,
    clearcoat: 0.35,
    clearcoatRoughness: 0.32,
    specularIntensity: 0.6,
  });
  const mesa = new THREE.Mesh(new THREE.PlaneGeometry(lado, lado), mat);
  mesa.rotation.x = -Math.PI / 2;
  mesa.rotation.z = 0.08;
  mesa.receiveShadow = true;
  return mesa;
}

/** Sombra de contacto (oclusión cercana al apoyo), complementa la sombra direccional. */
export function crearContacto(textura: THREE.Texture, radio: number, opacidad: number) {
  const mat = new THREE.MeshBasicMaterial({ color: 0x000000, alphaMap: textura, transparent: true, opacity: opacidad, depthWrite: false });
  const m = new THREE.Mesh(new THREE.PlaneGeometry(radio * 2, radio * 2), mat);
  m.rotation.x = -Math.PI / 2;
  m.position.y = 0.002;
  m.renderOrder = 1;
  return m;
}

/* ---------- mate ---------- */
export type Mate = ReturnType<typeof crearMate>;

export function crearMate(t: { cuero: MaterialPBR; cincelado: MaterialPBR; cepillado: MaterialPBR; calabaza: THREE.Texture }) {
  const grupo = new THREE.Group();

  for (const x of [t.cuero.map, t.cuero.normalMap, t.cuero.roughnessMap]) x.repeat.set(3, 1);
  const matCuero = new THREE.MeshPhysicalMaterial({
    ...t.cuero,
    normalScale: new THREE.Vector2(0.55, 0.55),
    roughness: 1,
    clearcoat: 0.28,
    clearcoatRoughness: 0.5,
    sheen: 0.45,
    sheenRoughness: 0.55,
    sheenColor: new THREE.Color(0x7a4a2a),
  });
  const exterior = new THREE.Mesh(new THREE.LatheGeometry(PUNTOS_PERFIL, 160), matCuero);
  exterior.castShadow = true;
  exterior.receiveShadow = true;
  grupo.add(exterior);

  const interior = new THREE.Mesh(
    new THREE.LatheGeometry(
      PUNTOS_PERFIL.filter((v) => v.y > 0.07).map((v) => new THREE.Vector2(v.x * 0.92, v.y)),
      96,
    ),
    new THREE.MeshStandardMaterial({ map: t.calabaza, roughness: 0.92, side: THREE.BackSide }),
  );
  interior.receiveShadow = true;
  grupo.add(interior);

  // Virola de alpaca cincelada
  for (const x of [t.cincelado.map, t.cincelado.normalMap, t.cincelado.roughnessMap]) x.repeat.set(4, 1);
  const matVirola = new THREE.MeshPhysicalMaterial({
    ...t.cincelado,
    color: 0xffffff,
    metalness: 1,
    roughness: 1,
    normalScale: new THREE.Vector2(1, 1),
    anisotropy: 0.35,
    anisotropyRotation: Math.PI / 2,
  });
  const virola = new THREE.Mesh(new THREE.CylinderGeometry(0.392, 0.402, 0.15, 160, 1, true), matVirola);
  virola.position.y = BOCA_Y + 0.015;
  virola.castShadow = true;
  virola.receiveShadow = true;
  grupo.add(virola);

  const matAlpaca = new THREE.MeshPhysicalMaterial({
    map: t.cepillado.map,
    normalMap: t.cepillado.normalMap,
    roughnessMap: t.cepillado.roughnessMap,
    normalScale: new THREE.Vector2(0.4, 0.4),
    metalness: 1,
    roughness: 0.9,
    color: 0xf2efe8,
    anisotropy: 0.6,
  });
  // Labio enrollado de la boca
  const labio = new THREE.Mesh(new THREE.TorusGeometry(0.385, 0.019, 20, 160), matAlpaca);
  labio.rotation.x = Math.PI / 2;
  labio.position.y = BOCA_Y + 0.09;
  labio.castShadow = true;
  grupo.add(labio);
  // Cordón inferior de la virola
  const cordon = new THREE.Mesh(new THREE.TorusGeometry(0.401, 0.008, 12, 160), matAlpaca);
  cordon.rotation.x = Math.PI / 2;
  cordon.position.y = BOCA_Y - 0.058;
  grupo.add(cordon);

  // Pie de alpaca torneado
  const perfilPie = [
    [0.0, 0.0],
    [0.3, 0.0],
    [0.315, 0.008],
    [0.316, 0.02],
    [0.302, 0.03],
    [0.29, 0.034],
    [0.282, 0.046],
    [0.262, 0.058],
    [0.25, 0.074],
    [0.235, 0.082],
  ].map(([r, y]) => new THREE.Vector2(r, y));
  const pie = new THREE.Mesh(new THREE.LatheGeometry(perfilPie, 128), matAlpaca);
  pie.castShadow = true;
  pie.receiveShadow = true;
  grupo.add(pie);

  return { grupo, exterior, matAlpaca, matVirola };
}

/* ---------- bombilla pico de loro ---------- */
export function crearBombilla(matAlpaca: THREE.Material) {
  const g = new THREE.Group();
  const curva = new THREE.CatmullRomCurve3([
    new THREE.Vector3(0, 0.02, 0),
    new THREE.Vector3(0, 0.6, 0),
    new THREE.Vector3(0, 1.25, 0),
    new THREE.Vector3(0, 1.42, 0),
    new THREE.Vector3(-0.035, 1.55, 0),
    new THREE.Vector3(-0.12, 1.63, 0),
    new THREE.Vector3(-0.2, 1.655, 0),
  ]);
  const caño = new THREE.Mesh(new THREE.TubeGeometry(curva, 160, 0.019, 18), matAlpaca);
  caño.castShadow = true;
  g.add(caño);
  // Boquilla aplanada
  const boquilla = new THREE.Mesh(new THREE.CapsuleGeometry(0.02, 0.05, 6, 16), matAlpaca);
  boquilla.scale.set(1.25, 1, 0.7);
  boquilla.position.set(-0.2, 1.655, 0);
  boquilla.rotation.z = Math.PI / 2 + 0.15;
  g.add(boquilla);
  // Filtro tipo cuchara con ranuras
  const perfil = [
    [0.0, -0.075],
    [0.03, -0.072],
    [0.055, -0.055],
    [0.066, -0.02],
    [0.062, 0.02],
    [0.045, 0.05],
    [0.022, 0.07],
    [0.019, 0.08],
  ].map(([r, y]) => new THREE.Vector2(r, y));
  const filtro = new THREE.Mesh(new THREE.LatheGeometry(perfil, 48), matAlpaca);
  filtro.scale.set(1.25, 1, 0.55);
  filtro.position.y = 0.07;
  filtro.castShadow = true;
  g.add(filtro);
  const ranura = new THREE.MeshStandardMaterial({ color: 0x1a1612, roughness: 0.8, metalness: 0.4 });
  for (let i = -3; i <= 3; i++) {
    const r = new THREE.Mesh(new THREE.BoxGeometry(0.11, 0.004, 0.005), ranura);
    r.position.set(0, 0.07 + i * 0.016, 0.036);
    r.scale.x = 1 - Math.abs(i) * 0.11;
    g.add(r);
    const r2 = r.clone();
    r2.position.z = -0.036;
    g.add(r2);
  }
  // Anillo de bronce
  const bronce = new THREE.MeshPhysicalMaterial({ color: 0xc9953f, metalness: 1, roughness: 0.28, clearcoat: 0.2 });
  for (const y of [1.0, 1.06]) {
    const a = new THREE.Mesh(new THREE.TorusGeometry(0.024, 0.008, 12, 32), bronce);
    a.rotation.x = Math.PI / 2;
    a.position.y = y;
    g.add(a);
  }
  const anillo = new THREE.Mesh(new THREE.CylinderGeometry(0.026, 0.026, 0.05, 32), bronce);
  anillo.position.y = 1.03;
  g.add(anillo);
  return g;
}

/* ---------- termo ---------- */
export function crearTermo(t: { map: THREE.Texture; metalnessMap: THREE.Texture; normalMap: THREE.Texture }, matAcero: THREE.Material) {
  const g = new THREE.Group();
  const pintura = new THREE.MeshPhysicalMaterial({
    map: t.map,
    metalnessMap: t.metalnessMap,
    metalness: 1,
    normalMap: t.normalMap,
    normalScale: new THREE.Vector2(0.25, 0.25),
    roughness: 0.48,
    clearcoat: 0.35,
    clearcoatRoughness: 0.35,
  });
  const cuerpo = new THREE.Mesh(new THREE.CylinderGeometry(0.27, 0.27, 1.12, 96, 1, true), pintura);
  cuerpo.castShadow = true;
  cuerpo.receiveShadow = true;
  g.add(cuerpo);
  const perfilBase = [
    [0.0, -0.6],
    [0.25, -0.6],
    [0.272, -0.592],
    [0.276, -0.575],
    [0.271, -0.56],
  ].map(([r, y]) => new THREE.Vector2(r, y));
  g.add(new THREE.Mesh(new THREE.LatheGeometry(perfilBase, 96), matAcero));
  const perfilCuello = [
    [0.271, 0.56],
    [0.272, 0.585],
    [0.25, 0.64],
    [0.205, 0.69],
    [0.19, 0.72],
    [0.19, 0.75],
    [0.2, 0.765],
    [0.2, 0.79],
    [0.14, 0.8],
    [0.1, 0.83],
    [0.075, 0.88],
    [0.05, 0.925],
    [0.042, 0.935],
    [0.0, 0.935],
  ].map(([r, y]) => new THREE.Vector2(r, y));
  const cuello = new THREE.Mesh(new THREE.LatheGeometry(perfilCuello, 96), matAcero);
  cuello.castShadow = true;
  g.add(cuello);
  // Manija
  const asa = new THREE.Mesh(
    new THREE.TubeGeometry(
      new THREE.CatmullRomCurve3([
        new THREE.Vector3(0, 0.52, -0.25),
        new THREE.Vector3(0, 0.52, -0.42),
        new THREE.Vector3(0, 0.3, -0.47),
        new THREE.Vector3(0, -0.15, -0.46),
        new THREE.Vector3(0, -0.3, -0.4),
        new THREE.Vector3(0, -0.32, -0.25),
      ]),
      64,
      0.035,
      14,
    ),
    new THREE.MeshPhysicalMaterial({ color: 0x1d382a, roughness: 0.6, clearcoat: 0.2 }),
  );
  asa.castShadow = true;
  g.add(asa);
  return g;
}

/* ---------- paquete de yerba de papel con pliegues ---------- */
export const PAQ = { ancho: 0.78, alto: 1.25, prof: 0.46 };

/** Desplaza los vértices de una caja para que parezca una bolsa de papel llena y manoseada. */
function deformarBolsa(geo: THREE.BufferGeometry, semilla: number, encogido = 1) {
  const { ancho: W, alto: H, prof: D } = PAQ;
  const pos = geo.attributes.position as THREE.BufferAttribute;
  const v = new THREE.Vector3();
  for (let i = 0; i < pos.count; i++) {
    v.fromBufferAttribute(pos, i);
    const u = v.x / (W / 2);
    const h = v.y / (H / 2);
    const w = v.z / (D / 2);
    const enFrente = Math.abs(Math.abs(w) - 1) < 1e-4;
    const enCostado = Math.abs(Math.abs(u) - 1) < 1e-4;
    const arriba = ss(0.55, 1, h); // zona del doblez superior
    const abajo = ss(-0.82, -1, h);
    // Panza: el papel lleno de yerba se abomba
    const panza = (1 - u * u) * (1 - Math.pow(Math.abs(h), 4)) * (1 - abajo);
    // Arrugas: ruido "ridged" en las coordenadas de la cara
    const cu = enCostado ? w : u;
    const n1 = 1 - Math.abs(ruido(cu * 3 + 10, h * 5 + 3, 999, semilla) * 2 - 1);
    const n2 = 1 - Math.abs(ruido(cu * 7 + 40, h * 11 + 7, 999, semilla + 5) * 2 - 1);
    const arruga = (Math.pow(n1, 6) * 0.008 + Math.pow(n2, 8) * 0.004) * (0.5 + arriba);
    // Marca del doblez de cierre (línea horizontal) y diagonales de las esquinas
    const yDoblez = 0.66;
    const doblez = Math.exp(-Math.pow((h - yDoblez) / 0.018, 2)) * 0.012;
    const diag = Math.exp(-Math.pow((h - yDoblez - (1 - Math.abs(cu)) * 0.25) / 0.02, 2)) * 0.006 * arriba;
    if (enFrente) {
      v.z += Math.sign(w) * (D * 0.11 * panza + arruga + doblez - diag);
      v.x *= 1 - 0.035 * arriba;
    } else if (enCostado) {
      // Fuelle: pliegue en V hacia adentro en el centro del costado, más marcado arriba
      const v_ = (1 - Math.abs(w)) * (0.35 + arriba * 0.65);
      v.x += Math.sign(u) * (-W * 0.085 * v_ + W * 0.03 * panza + arruga + doblez);
    } else if (v.y < 0) {
      v.y += 0.004 * fbm(u * 0.5 + 0.5, w * 0.5 + 0.5, 3, 2, semilla);
    }
    v.x *= encogido;
    v.z *= encogido;
    pos.setXYZ(i, v.x, v.y, v.z);
  }
  pos.needsUpdate = true;
  geo.computeVertexNormals();
}

export type Paquete = ReturnType<typeof crearPaquete>;

export function crearPaquete(t: { frente: THREE.Texture; lateral: THREE.Texture; dorso: THREE.Texture; fibra: THREE.Texture; yerba: { map: THREE.Texture; normalMap: THREE.Texture } }) {
  const { ancho: W, alto: H, prof: D } = PAQ;
  const grupo = new THREE.Group();
  const papel = (map: THREE.Texture) =>
    new THREE.MeshPhysicalMaterial({
      map,
      normalMap: t.fibra,
      normalScale: new THREE.Vector2(0.35, 0.35),
      roughness: 0.78,
      sheen: 0.25,
      sheenRoughness: 0.8,
      sheenColor: new THREE.Color(0xffffff),
    });
  const invisible = new THREE.MeshBasicMaterial({ visible: false });
  const lateral = papel(t.lateral);
  const geo = new THREE.BoxGeometry(W, H, D, 20, 36, 12);
  deformarBolsa(geo, 3);
  // orden de caras de BoxGeometry: +x, -x, +y, -y, +z, -z
  const cuerpo = new THREE.Mesh(geo, [lateral, lateral, invisible, papel(t.dorso), papel(t.frente), papel(t.dorso)]);
  cuerpo.castShadow = true;
  cuerpo.receiveShadow = true;
  grupo.add(cuerpo);

  // Cara interna del papel (kraft sin imprimir)
  const geoInt = new THREE.BoxGeometry(W, H, D, 20, 36, 12);
  deformarBolsa(geoInt, 3, 0.975);
  const kraft = new THREE.MeshStandardMaterial({ color: 0xc8ad84, roughness: 0.95, side: THREE.BackSide, normalMap: t.fibra });
  const interior = new THREE.Mesh(geoInt, [kraft, kraft, invisible, kraft, kraft, kraft]);
  grupo.add(interior);

  // Yerba adentro (se ve al abrir)
  const matYerba = new THREE.MeshStandardMaterial({ map: t.yerba.map, normalMap: t.yerba.normalMap, roughness: 0.95 });
  const contenido = new THREE.Mesh(new THREE.PlaneGeometry(W * 0.95, D * 0.92, 12, 8), matYerba);
  contenido.rotation.x = -Math.PI / 2;
  const pc = contenido.geometry.attributes.position as THREE.BufferAttribute;
  for (let i = 0; i < pc.count; i++) pc.setZ(i, (ruido(pc.getX(i) * 9 + 5, pc.getY(i) * 9 + 5, 999, 4) - 0.5) * 0.04);
  contenido.geometry.computeVertexNormals();
  grupo.add(contenido);

  // Solapa de cierre: tira de papel que se despliega curvándose
  const L = 0.62;
  const segL = 26;
  const geoSolapa = new THREE.PlaneGeometry(W * 0.97, L, 14, segL);
  const uv = geoSolapa.attributes.uv as THREE.BufferAttribute;
  // usa la franja superior oscura del frente
  for (let i = 0; i < uv.count; i++) uv.setY(i, lerp(0.875, 1.0, uv.getY(i)));
  const solapaMat = papel(t.frente);
  solapaMat.side = THREE.DoubleSide;
  const solapa = new THREE.Mesh(geoSolapa, solapaMat);
  solapa.castShadow = true;
  grupo.add(solapa);
  const base = (geoSolapa.attributes.position as THREE.BufferAttribute).array.slice() as Float32Array;
  const r = azar(9);
  const rugosidad = Array.from({ length: (segL + 1) * 15 }, () => r() - 0.5);

  let ultimaApertura = -1;
  /** a: 0 cerrado (doblado sobre la boca), 1 abierto (parado, con el pliegue marcado). */
  function abrir(a: number) {
    if (Math.abs(a - ultimaApertura) < 1e-4) return;
    ultimaApertura = a;
    const pos = geoSolapa.attributes.position as THREE.BufferAttribute;
    const filas = segL + 1;
    const cols = 15;
    // Ángulo a lo largo de la solapa (0 = horizontal hacia el frente, π/2 = vertical arriba)
    const angs: number[] = [];
    for (let j = 0; j < filas; j++) {
      const s = (j / segL) * L; // desde la bisagra
      const cerrado = s < D * 0.98 ? 0.02 : -Math.PI / 2 + 0.05; // tapa + caída por el frente
      const abierto = Math.PI / 2 + 0.25 + (s / L) * 0.55 + (s > D ? -0.35 : 0); // parada, curvándose hacia atrás
      angs.push(lerp(cerrado, abierto, a));
    }
    for (let j = 0; j < filas; j++) {
      // integrar posición a lo largo de s
      let y = H / 2 + 0.004;
      let z = -D / 2;
      const ds = L / segL;
      // el plano de three va de +L/2 (fila 0) a -L/2: la fila 0 es el extremo, la invertimos
      const fila = segL - j;
      for (let k = 0; k < j; k++) {
        const ang = angs[k];
        z += Math.cos(ang) * ds;
        y += Math.sin(ang) * ds;
      }
      for (let c = 0; c < cols; c++) {
        const idx = fila * cols + c;
        const x = base[idx * 3];
        const xn = x / (W / 2);
        // el papel se curva un poco en los bordes y tiene micro-arrugas
        const arrugado = rugosidad[j * cols + c] * 0.006 * (0.3 + a);
        const comba = (1 - xn * xn) * 0.025 * Math.sin((j / segL) * Math.PI) * a;
        const off = comba + arrugado;
        // normal de la tira en el plano (z, y): (-sen, cos)
        pos.setXYZ(idx, x, y + off * Math.cos(angs[j]), z - off * Math.sin(angs[j]));
      }
    }
    pos.needsUpdate = true;
    geoSolapa.computeVertexNormals();
  }
  abrir(0);

  /** Nivel de yerba restante dentro del paquete (1 lleno, 0 vacío). */
  function nivel(n: number) {
    contenido.position.y = lerp(-H / 2 + 0.08, H / 2 - 0.1, n);
    contenido.visible = n > 0.02;
  }
  nivel(1);

  return { grupo, abrir, nivel };
}

import * as THREE from "three";
import { RoomEnvironment } from "three/examples/jsm/environments/RoomEnvironment.js";

/*
 * Escena 3D del ritual del mate, manejada por el scroll.
 *
 * Todo lo que se ve es función pura del progreso `p` (0 → 1): el paquete se abre,
 * se inclina y vuelca la yerba, el mate se llena, se clava la bombilla y el termo
 * ceba. Como no depende del tiempo (salvo el vapor), hacer scroll hacia atrás
 * rebobina la escena exactamente.
 */

// ---------- utilidades ----------
const clamp01 = (x: number) => Math.min(1, Math.max(0, x));
const ss = (a: number, b: number, x: number) => {
  const t = clamp01((x - a) / (b - a));
  return t * t * (3 - 2 * t);
};
const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
const easeOut = (t: number) => 1 - Math.pow(1 - t, 3);

/** Generador pseudoaleatorio con semilla, para que las partículas sean siempre las mismas. */
function azar(semilla: number) {
  let s = semilla >>> 0;
  return () => {
    s = (s + 0x6d2b79f5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function texturaCanvas(ancho: number, alto: number, dibujar: (c: CanvasRenderingContext2D, w: number, h: number) => void) {
  const canvas = document.createElement("canvas");
  canvas.width = ancho;
  canvas.height = alto;
  const ctx = canvas.getContext("2d")!;
  dibujar(ctx, ancho, alto);
  const tex = new THREE.CanvasTexture(canvas);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = 4;
  return tex;
}

// ---------- perfil de la calabaza ----------
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
const CURVA = new THREE.SplineCurve(PERFIL);
const PUNTOS_PERFIL = CURVA.getPoints(80);
const BOCA_Y = 1.1;

/** Radio de la calabaza a una altura dada, interpolando el perfil. */
function radioEn(y: number) {
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

// ---------- coreografía ----------
const ALTURA_LLENO = 0.93;
const nivelYerba = (p: number) => lerp(0.06, ALTURA_LLENO, ss(0.38, 0.64, p));

function posePaquete(p: number) {
  const apertura = ss(0.1, 0.22, p);
  const ida = ss(0.22, 0.36, p);
  const vuelta = ss(0.63, 0.75, p);
  const m = ida * (1 - vuelta);
  const vertiendo = ss(0.36, 0.4, p) * (1 - ss(0.6, 0.63, p));
  const temblor = Math.sin(p * 1400) * 0.012 * vertiendo;
  // Al terminar de volcar, el paquete vuelve a la mesa, un poco más atrás.
  const x = lerp(lerp(-1.45, -1.05, vuelta), -0.62, m) + temblor;
  const y = lerp(0.5, 2.0, m) + Math.sin(p * 900) * 0.008 * vertiendo;
  const z = lerp(lerp(0.25, -0.9, vuelta), 0, m);
  const rz = lerp(0, -2.0, easeOut(m)) + Math.sin(p * 600) * 0.03 * vertiendo;
  const tapa = -2.15 * apertura * (1 - ss(0.72, 0.8, p) * 0.85);
  return { x, y, z, rz, tapa };
}

/** Boca del paquete (donde sale la yerba) en coordenadas del mundo. */
function bocaPaquete(p: number, destino = new THREE.Vector3()) {
  const { x, y, z, rz } = posePaquete(p);
  return destino.set(x - Math.sin(rz) * 0.5, y + Math.cos(rz) * 0.5, z);
}

function inclinacionMate(p: number) {
  return 0.24 * ss(0.64, 0.7, p) * (1 - ss(0.88, 0.93, p));
}

function poseTermo(p: number) {
  const entrada = ss(0.84, 0.9, p);
  const salida = ss(0.965, 1, p);
  if (salida > 0) {
    return { x: lerp(1.02, 1.35, salida), y: lerp(1.95, 0.62, salida), z: lerp(0.05, 0.35, salida), rz: 1.85 * (1 - salida) };
  }
  return { x: lerp(3.2, 1.02, entrada), y: lerp(0.62, 1.95, easeOut(entrada)), z: lerp(0.3, 0.05, entrada), rz: 1.85 * ss(0.865, 0.9, p) };
}

// ---------- escena ----------
export type Escena = {
  setProgreso: (p: number) => void;
  redimensionar: () => void;
  activar: (activa: boolean) => void;
  destruir: () => void;
};

export function crearEscena(canvas: HTMLCanvasElement): Escena {
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true, powerPreference: "high-performance" });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.05;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.localClippingEnabled = true;

  const escena = new THREE.Scene();
  const pmrem = new THREE.PMREMGenerator(renderer);
  const entorno = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
  escena.environment = entorno;
  escena.environmentIntensity = 0.55;

  const camara = new THREE.PerspectiveCamera(32, 1, 0.1, 60);

  // Luces
  escena.add(new THREE.HemisphereLight(0xfff4e0, 0x5a4630, 0.9));
  const sol = new THREE.DirectionalLight(0xfff1dc, 2.6);
  sol.position.set(-3.5, 6, 4);
  sol.castShadow = true;
  sol.shadow.mapSize.set(2048, 2048);
  sol.shadow.camera.left = -4;
  sol.shadow.camera.right = 4;
  sol.shadow.camera.top = 4;
  sol.shadow.camera.bottom = -4;
  sol.shadow.bias = -0.0004;
  sol.shadow.radius = 6;
  escena.add(sol);
  const relleno = new THREE.DirectionalLight(0xd7e6ff, 0.6);
  relleno.position.set(4, 3, -2);
  escena.add(relleno);

  // Piso que solo recibe sombra
  const piso = new THREE.Mesh(new THREE.CircleGeometry(8, 64), new THREE.ShadowMaterial({ opacity: 0.16 }));
  piso.rotation.x = -Math.PI / 2;
  piso.receiveShadow = true;
  escena.add(piso);

  // ---------- materiales ----------
  const r = azar(7);
  const texCuero = texturaCanvas(1024, 512, (c, w, h) => {
    const g = c.createLinearGradient(0, 0, 0, h);
    g.addColorStop(0, "#3f2414");
    g.addColorStop(0.5, "#56321c");
    g.addColorStop(1, "#4a2a17");
    c.fillStyle = g;
    c.fillRect(0, 0, w, h);
    for (let i = 0; i < 9000; i++) {
      c.fillStyle = r() > 0.5 ? "rgba(20,10,4,0.18)" : "rgba(255,215,170,0.05)";
      c.fillRect(r() * w, r() * h, 1 + r() * 3, 1 + r() * 2);
    }
    // vetas suaves del cuero
    for (let i = 0; i < 260; i++) {
      c.strokeStyle = `rgba(${r() > 0.5 ? "255,220,180" : "15,8,3"},${0.03 + r() * 0.05})`;
      c.lineWidth = 1 + r() * 2;
      c.beginPath();
      const x = r() * w;
      const y = r() * h;
      c.moveTo(x, y);
      c.bezierCurveTo(x + 20, y + r() * 10, x + 40, y - r() * 10, x + 60 + r() * 60, y);
      c.stroke();
    }
    // costura de tiento
    c.strokeStyle = "rgba(232,214,184,0.9)";
    c.lineWidth = 5;
    c.setLineDash([18, 14]);
    for (const v of [0.3, 0.62]) {
      c.beginPath();
      c.moveTo(0, h * (1 - v));
      c.lineTo(w, h * (1 - v));
      c.stroke();
    }
  });
  const texYerba = texturaCanvas(512, 512, (c, w, h) => {
    c.fillStyle = "#7c9a45";
    c.fillRect(0, 0, w, h);
    const tonos = ["#5f7d32", "#93b35a", "#a7c46c", "#4e6a28", "#b9cf86", "#6d8a3a", "#c8b27a"];
    for (let i = 0; i < 16000; i++) {
      c.fillStyle = tonos[Math.floor(r() * tonos.length)];
      c.save();
      c.translate(r() * w, r() * h);
      c.rotate(r() * Math.PI);
      c.fillRect(0, 0, 2 + r() * 6, 1 + r() * 2.5);
      c.restore();
    }
  });
  texYerba.wrapS = texYerba.wrapT = THREE.RepeatWrapping;

  const texEtiqueta = texturaCanvas(512, 728, (c, w, h) => {
    c.fillStyle = "#2f5a3e";
    c.fillRect(0, 0, w, h);
    for (let i = 0; i < 4000; i++) {
      c.fillStyle = "rgba(0,0,0,0.06)";
      c.fillRect(r() * w, r() * h, 2, 2);
    }
    c.fillStyle = "#f6efe2";
    c.beginPath();
    c.roundRect(56, 190, w - 112, 380, 28);
    c.fill();
    c.fillStyle = "#2f5a3e";
    c.beginPath();
    c.moveTo(w / 2, 240);
    c.bezierCurveTo(w / 2 - 70, 290, w / 2 - 70, 370, w / 2, 400);
    c.bezierCurveTo(w / 2 + 70, 370, w / 2 + 70, 290, w / 2, 240);
    c.fill();
    c.strokeStyle = "#f6efe2";
    c.lineWidth = 5;
    c.beginPath();
    c.moveTo(w / 2, 250);
    c.lineTo(w / 2, 395);
    c.stroke();
    c.textAlign = "center";
    c.fillStyle = "#1f3d2b";
    c.font = "700 64px Georgia, serif";
    c.fillText("duomate", w / 2, 480);
    c.fillStyle = "#b4572e";
    c.font = "700 30px Arial, sans-serif";
    c.fillText("BLEND SUAVE · 1 KG", w / 2, 530);
    c.fillStyle = "#c9a24b";
    c.fillRect(0, 640, w, 14);
  });
  const texKraft = texturaCanvas(256, 256, (c, w, h) => {
    c.fillStyle = "#2f5a3e";
    c.fillRect(0, 0, w, h);
    for (let i = 0; i < 1500; i++) {
      c.fillStyle = "rgba(0,0,0,0.07)";
      c.fillRect(r() * w, r() * h, 2, 2);
    }
  });
  const texHumo = texturaCanvas(128, 128, (c, w, h) => {
    const g = c.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, w / 2);
    g.addColorStop(0, "rgba(255,255,255,0.9)");
    g.addColorStop(1, "rgba(255,255,255,0)");
    c.fillStyle = g;
    c.fillRect(0, 0, w, h);
  });

  const matCuero = new THREE.MeshPhysicalMaterial({ map: texCuero, bumpMap: texCuero, bumpScale: 1.6, roughness: 0.55, clearcoat: 0.35, clearcoatRoughness: 0.45, sheen: 0.3, sheenRoughness: 0.6, sheenColor: new THREE.Color(0x8a5a36) });
  const matInterior = new THREE.MeshStandardMaterial({ color: 0x4a2f1c, roughness: 0.9, side: THREE.BackSide });
  const matMetal = new THREE.MeshStandardMaterial({ color: 0xdfe1e6, metalness: 1, roughness: 0.22 });
  const matOro = new THREE.MeshStandardMaterial({ color: 0xc9a24b, metalness: 1, roughness: 0.3 });
  const planoYerba = new THREE.Plane(new THREE.Vector3(0, -1, 0), 0);
  const matYerba = new THREE.MeshStandardMaterial({ map: texYerba, bumpMap: texYerba, bumpScale: 2, roughness: 1, clippingPlanes: [planoYerba] });
  const matYerbaSup = new THREE.MeshStandardMaterial({ map: texYerba, bumpMap: texYerba, bumpScale: 3, roughness: 1 });
  const colorSeco = new THREE.Color(1, 1, 1);
  const colorMojado = new THREE.Color(0.55, 0.6, 0.42);

  // ---------- mate ----------
  const mate = new THREE.Group();
  escena.add(mate);
  const exterior = new THREE.Mesh(new THREE.LatheGeometry(PUNTOS_PERFIL, 96), matCuero);
  exterior.castShadow = true;
  mate.add(exterior);
  const interior = new THREE.Mesh(
    new THREE.LatheGeometry(
      PUNTOS_PERFIL.filter((v) => v.y > 0.07).map((v) => new THREE.Vector2(v.x * 0.92, v.y)),
      96,
    ),
    matInterior,
  );
  mate.add(interior);
  const virola = new THREE.Mesh(new THREE.CylinderGeometry(0.39, 0.4, 0.13, 96, 1, true), matMetal);
  virola.position.y = BOCA_Y + 0.02;
  virola.castShadow = true;
  mate.add(virola);
  const labio = new THREE.Mesh(new THREE.TorusGeometry(0.378, 0.02, 16, 96), matMetal);
  labio.rotation.x = Math.PI / 2;
  labio.position.y = BOCA_Y + 0.08;
  mate.add(labio);
  for (let i = 0; i < 24; i++) {
    const remache = new THREE.Mesh(new THREE.SphereGeometry(0.012, 8, 8), matOro);
    const a = (i / 24) * Math.PI * 2;
    remache.position.set(Math.cos(a) * 0.401, BOCA_Y + 0.02, Math.sin(a) * 0.401);
    mate.add(remache);
  }
  const pie = new THREE.Mesh(new THREE.CylinderGeometry(0.26, 0.31, 0.07, 64), matMetal);
  pie.position.y = 0.035;
  pie.castShadow = true;
  mate.add(pie);

  // yerba dentro del mate
  const volumen = new THREE.Mesh(
    new THREE.LatheGeometry(
      [new THREE.Vector2(0, 0.06), ...PUNTOS_PERFIL.filter((v) => v.y > 0.07).map((v) => new THREE.Vector2(v.x * 0.9, v.y))],
      64,
    ),
    matYerba,
  );
  mate.add(volumen);
  const superficie = new THREE.Mesh(new THREE.CircleGeometry(1, 64), matYerbaSup);
  superficie.rotation.x = -Math.PI / 2;
  mate.add(superficie);
  const monticulo = new THREE.Mesh(new THREE.SphereGeometry(1, 48, 16, 0, Math.PI * 2, 0, Math.PI / 2), matYerbaSup);
  mate.add(monticulo);

  // ---------- paquete de yerba ----------
  const paquete = new THREE.Group();
  escena.add(paquete);
  const matKraft = new THREE.MeshStandardMaterial({ map: texKraft, roughness: 0.85 });
  const matFrente = new THREE.MeshStandardMaterial({ map: texEtiqueta, roughness: 0.75 });
  const matBoca = new THREE.MeshStandardMaterial({ map: texYerba, roughness: 1 });
  const cuerpo = new THREE.Mesh(new THREE.BoxGeometry(0.7, 1, 0.42), [matKraft, matKraft, matBoca, matKraft, matFrente, matKraft]);
  cuerpo.castShadow = true;
  paquete.add(cuerpo);
  const bisagra = new THREE.Group();
  bisagra.position.set(0, 0.5, -0.21);
  paquete.add(bisagra);
  const tapa = new THREE.Mesh(new THREE.BoxGeometry(0.72, 0.02, 0.44), matKraft);
  tapa.position.set(0, 0.01, 0.22);
  tapa.castShadow = true;
  bisagra.add(tapa);

  // ---------- partículas de yerba ----------
  const N = 1100;
  const hojas = new THREE.InstancedMesh(new THREE.BoxGeometry(0.03, 0.008, 0.018), new THREE.MeshStandardMaterial({ roughness: 1 }), N);
  hojas.castShadow = true;
  hojas.frustumCulled = false;
  const rp = azar(42);
  const datos = Array.from({ length: N }, (_, i) => ({
    emision: 0.38 + (i / N) * 0.225 + rp() * 0.008,
    duracion: 0.03 + rp() * 0.012,
    ang: rp() * Math.PI * 2,
    rad: Math.sqrt(rp()) * 0.75,
    dispersion: new THREE.Vector3((rp() - 0.5) * 0.12, (rp() - 0.5) * 0.05, (rp() - 0.5) * 0.12),
    giro: new THREE.Euler(rp() * 6, rp() * 6, rp() * 6),
    velGiro: 4 + rp() * 10,
    escala: 0.6 + rp() * 0.9,
  }));
  const tonos = [0x6f8f3c, 0x8aa955, 0x5a7a2f, 0xa4bf6a, 0x7d9a45, 0xb9a46e];
  const col = new THREE.Color();
  datos.forEach((_, i) => hojas.setColorAt(i, col.setHex(tonos[i % tonos.length])));
  escena.add(hojas);

  // ---------- bombilla (hija del mate, se inclina con él) ----------
  const bombilla = new THREE.Group();
  const caño = new THREE.Mesh(
    new THREE.TubeGeometry(
      new THREE.CatmullRomCurve3([
        new THREE.Vector3(0, 0, 0),
        new THREE.Vector3(0, 1.25, 0),
        new THREE.Vector3(0, 1.45, 0),
        new THREE.Vector3(-0.05, 1.58, 0),
        new THREE.Vector3(-0.17, 1.65, 0),
      ]),
      80,
      0.021,
      14,
    ),
    matMetal,
  );
  caño.castShadow = true;
  bombilla.add(caño);
  const filtro = new THREE.Mesh(new THREE.SphereGeometry(0.065, 24, 16), matMetal);
  filtro.scale.set(1, 0.5, 1);
  bombilla.add(filtro);
  const anillo = new THREE.Mesh(new THREE.CylinderGeometry(0.033, 0.033, 0.07, 24), matOro);
  anillo.position.y = 1.02;
  bombilla.add(anillo);
  mate.add(bombilla);

  // ---------- termo ----------
  const termo = new THREE.Group();
  escena.add(termo);
  const matPintura = new THREE.MeshPhysicalMaterial({ color: 0x2f5a3e, metalness: 0.35, roughness: 0.38, clearcoat: 0.7, clearcoatRoughness: 0.2 });
  const cuerpoTermo = new THREE.Mesh(new THREE.CylinderGeometry(0.27, 0.27, 1.15, 64), matPintura);
  cuerpoTermo.castShadow = true;
  termo.add(cuerpoTermo);
  const base = new THREE.Mesh(new THREE.CylinderGeometry(0.275, 0.27, 0.08, 64), matMetal);
  base.position.y = -0.58;
  termo.add(base);
  const cuello = new THREE.Mesh(new THREE.CylinderGeometry(0.2, 0.27, 0.2, 64), matMetal);
  cuello.position.y = 0.67;
  cuello.castShadow = true;
  termo.add(cuello);
  const pico = new THREE.Mesh(new THREE.CylinderGeometry(0.045, 0.08, 0.16, 32), matMetal);
  pico.position.y = 0.85;
  termo.add(pico);

  const chorro = new THREE.Mesh(
    new THREE.CylinderGeometry(0.022, 0.03, 1, 16, 1, true),
    new THREE.MeshPhysicalMaterial({ color: 0xd9ecf2, roughness: 0.05, transmission: 0.6, transparent: true, opacity: 0.75, thickness: 0.2 }),
  );
  escena.add(chorro);

  // ---------- vapor ----------
  const vapores = Array.from({ length: 16 }, () => {
    const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: texHumo, transparent: true, depthWrite: false, opacity: 0 }));
    escena.add(s);
    return s;
  });

  // ---------- actualización ----------
  let progreso = 0;
  let activa = true;
  let raf = 0;
  const reloj = new THREE.Clock();
  const tmpBoca = new THREE.Vector3();
  const tmpCtrl = new THREE.Vector3();
  const tmpDest = new THREE.Vector3();
  const tmpPos = new THREE.Vector3();
  const dummy = new THREE.Object3D();
  const objetivo = new THREE.Vector3();
  const planoLocal = new THREE.Plane();

  function actualizar(t: number) {
    const p = progreso;

    // Mate
    mate.rotation.z = inclinacionMate(p);
    mate.updateMatrixWorld(true);

    // Yerba en el mate
    const h = nivelYerba(p);
    const hayYerba = h > 0.065;
    volumen.visible = superficie.visible = monticulo.visible = hayYerba;
    const rh = radioEn(h) * 0.9;
    superficie.position.y = h;
    superficie.scale.setScalar(rh);
    const alturaMont = 0.13 * ss(0.42, 0.66, p);
    const ladeo = ss(0.66, 0.72, p);
    monticulo.position.set(0.06 * ladeo, h - 0.005, 0);
    monticulo.rotation.z = -0.5 * ladeo;
    monticulo.scale.set(rh * 0.86, Math.max(0.001, alturaMont), rh * 0.86);
    planoLocal.set(new THREE.Vector3(0, -1, 0), h);
    planoYerba.copy(planoLocal).applyMatrix4(mate.matrixWorld);
    const mojado = ss(0.9, 0.96, p);
    matYerbaSup.color.copy(colorSeco).lerp(colorMojado, mojado);

    // Paquete
    const pp = posePaquete(p);
    paquete.position.set(pp.x, pp.y, pp.z);
    paquete.rotation.set(0, 0.35 * (1 - ss(0.2, 0.32, p)), pp.rz);
    bisagra.rotation.x = pp.tapa;

    // Partículas: cada hoja sale de la boca del paquete en su momento y cae al mate
    for (let i = 0; i < N; i++) {
      const d = datos[i];
      const fase = (p - d.emision) / d.duracion;
      if (fase <= 0 || fase >= 1) {
        dummy.position.set(0, -10, 0);
        dummy.scale.setScalar(0);
      } else {
        bocaPaquete(d.emision, tmpBoca).add(d.dispersion);
        const rz = posePaquete(d.emision).rz;
        tmpCtrl.set(tmpBoca.x - Math.sin(rz) * 0.22, tmpBoca.y + Math.cos(rz) * 0.22, tmpBoca.z);
        const yDest = nivelYerba(d.emision + d.duracion) + 0.02;
        const rDest = radioEn(yDest) * 0.85 * d.rad;
        tmpDest.set(Math.cos(d.ang) * rDest, yDest, Math.sin(d.ang) * rDest);
        const s = fase * fase * 0.65 + fase * 0.35; // acelera al caer
        const u = 1 - s;
        tmpPos.set(0, 0, 0).addScaledVector(tmpBoca, u * u).addScaledVector(tmpCtrl, 2 * u * s).addScaledVector(tmpDest, s * s);
        dummy.position.copy(tmpPos);
        dummy.rotation.set(d.giro.x + fase * d.velGiro, d.giro.y + fase * d.velGiro * 0.7, d.giro.z);
        dummy.scale.setScalar(d.escala);
      }
      dummy.updateMatrix();
      hojas.setMatrixAt(i, dummy.matrix);
    }
    hojas.instanceMatrix.needsUpdate = true;

    // Bombilla
    const ins = ss(0.72, 0.86, p);
    bombilla.visible = ins > 0;
    bombilla.position.set(0.13, lerp(3.6, 0.28, easeOut(ins)), 0.02);
    bombilla.rotation.set(0, -0.5, 0.17);

    // Termo y chorro
    const pt = poseTermo(p);
    termo.position.set(pt.x, pt.y, pt.z);
    termo.rotation.set(0, 0, pt.rz);
    termo.visible = p > 0.835;
    const vierte = ss(0.895, 0.905, p) * (1 - ss(0.955, 0.965, p));
    chorro.visible = vierte > 0.01;
    if (chorro.visible) {
      termo.updateMatrixWorld(true);
      const pico = new THREE.Vector3(0, 0.93, 0).applyMatrix4(termo.matrixWorld);
      const destino = new THREE.Vector3(-0.08, h + alturaMont * 0.6, 0.02).applyMatrix4(mate.matrixWorld);
      const largo = pico.distanceTo(destino) * vierte;
      chorro.position.copy(pico).lerp(destino, vierte * 0.5);
      chorro.scale.set(1, Math.max(0.001, largo), 1);
      chorro.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), pico.clone().sub(destino).normalize());
    }

    // Vapor
    const vis = ss(0.92, 0.98, p);
    vapores.forEach((s, i) => {
      const fase = (t * 0.22 + i / vapores.length) % 1;
      s.visible = vis > 0.01;
      s.position.set(-0.05 + Math.sin(i * 2.3 + t * 0.6) * 0.12 * (0.4 + fase), BOCA_Y + 0.15 + fase * 1.1, Math.cos(i * 1.7) * 0.1);
      const esc = 0.22 + fase * 0.6;
      s.scale.set(esc, esc, esc);
      (s.material as THREE.SpriteMaterial).opacity = vis * 0.32 * Math.sin(fase * Math.PI);
    });

    // Cámara: sigue la acción y se eleva para mirar dentro del mate mientras se llena
    const aspecto = camara.aspect;
    const az = lerp(-0.42, 0.38, p);
    const mirarAdentro = ss(0.3, 0.42, p) * (1 - ss(0.6, 0.7, p));
    const elev = 0.26 + 0.34 * mirarAdentro + 0.2 * ss(0.86, 0.94, p);
    let dist = lerp(7.4, 6.0, ss(0, 0.4, p)) - 0.3 * ss(0.7, 0.86, p) + 0.5 * ss(0.84, 0.92, p);
    if (aspecto < 1) dist *= lerp(1.9, 1, clamp01((aspecto - 0.45) / 0.55));
    const tx = lerp(-0.7, 0, ss(0.18, 0.4, p)) + 0.35 * ss(0.84, 0.92, p) * (1 - ss(0.96, 1, p) * 0.6);
    objetivo.set(tx, lerp(0.85, 1.25, mirarAdentro), 0);
    camara.position.set(objetivo.x + dist * Math.cos(elev) * Math.sin(az), objetivo.y + dist * Math.sin(elev), objetivo.z + dist * Math.cos(elev) * Math.cos(az));
    camara.lookAt(objetivo);

    renderer.render(escena, camara);
  }

  function bucle() {
    raf = requestAnimationFrame(bucle);
    if (!activa) return;
    actualizar(reloj.getElapsedTime());
  }

  function redimensionar() {
    const w = canvas.clientWidth || 1;
    const h = canvas.clientHeight || 1;
    renderer.setSize(w, h, false);
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
      entorno.dispose();
      pmrem.dispose();
      renderer.dispose();
    },
  };
}

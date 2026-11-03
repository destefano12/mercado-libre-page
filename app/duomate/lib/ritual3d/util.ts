import * as THREE from "three";

/* ---------- matemática ---------- */
export const clamp01 = (x: number) => Math.min(1, Math.max(0, x));
export const clamp = (x: number, a: number, b: number) => Math.min(b, Math.max(a, x));
/** smoothstep entre a y b. */
export const ss = (a: number, b: number, x: number) => {
  const t = clamp01((x - a) / (b - a));
  return t * t * (3 - 2 * t);
};
export const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
export const easeOut = (t: number) => 1 - Math.pow(1 - t, 3);
export const easeInOut = (t: number) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);
export const fract = (x: number) => x - Math.floor(x);

/** Generador pseudoaleatorio con semilla (mulberry32): todo lo "al azar" es siempre igual. */
export function azar(semilla: number) {
  let s = semilla >>> 0;
  return () => {
    s = (s + 0x6d2b79f5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/* ---------- ruido 2D repetible (para texturas que hacen mosaico) ---------- */
function hash2(x: number, y: number, semilla: number) {
  let h = Math.imul(x, 374761393) + Math.imul(y, 668265263) + Math.imul(semilla, 982451653);
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}

/** Ruido de valor periódico: `periodo` celdas en cada eje. */
export function ruido(x: number, y: number, periodo: number, semilla = 0) {
  const xi = Math.floor(x);
  const yi = Math.floor(y);
  const xf = x - xi;
  const yf = y - yi;
  const m = (n: number) => ((n % periodo) + periodo) % periodo;
  const x0 = m(xi);
  const x1 = m(xi + 1);
  const y0 = m(yi);
  const y1 = m(yi + 1);
  const u = xf * xf * (3 - 2 * xf);
  const v = yf * yf * (3 - 2 * yf);
  const a = hash2(x0, y0, semilla);
  const b = hash2(x1, y0, semilla);
  const c = hash2(x0, y1, semilla);
  const d = hash2(x1, y1, semilla);
  return lerp(lerp(a, b, u), lerp(c, d, u), v);
}

/** fBm periódico. `u`,`v` en [0,1); `escala` celdas en la octava base. */
export function fbm(u: number, v: number, escala: number, octavas = 5, semilla = 0, ganancia = 0.5) {
  let suma = 0;
  let amp = 0.5;
  let f = escala;
  let norma = 0;
  for (let o = 0; o < octavas; o++) {
    suma += amp * ruido(u * f, v * f, f, semilla + o * 17);
    norma += amp;
    amp *= ganancia;
    f *= 2;
  }
  return suma / norma;
}

/** Worley (celular) periódico: devuelve [F1, F2] normalizados aproximadamente a [0,1]. */
export function worley(u: number, v: number, celdas: number, semilla = 0): [number, number] {
  const x = u * celdas;
  const y = v * celdas;
  const xi = Math.floor(x);
  const yi = Math.floor(y);
  let f1 = 9;
  let f2 = 9;
  for (let j = -1; j <= 1; j++) {
    for (let i = -1; i <= 1; i++) {
      const cx = xi + i;
      const cy = yi + j;
      const wx = ((cx % celdas) + celdas) % celdas;
      const wy = ((cy % celdas) + celdas) % celdas;
      const px = cx + hash2(wx, wy, semilla);
      const py = cy + hash2(wx, wy, semilla + 101);
      const dx = px - x;
      const dy = py - y;
      const d = Math.sqrt(dx * dx + dy * dy);
      if (d < f1) {
        f2 = f1;
        f1 = d;
      } else if (d < f2) f2 = d;
    }
  }
  return [f1, f2];
}

/* ---------- texturas ---------- */
export type Mapa = { w: number; h: number; datos: Float32Array };

export function nuevoMapa(w: number, h: number): Mapa {
  return { w, h, datos: new Float32Array(w * h) };
}

/** Llena un mapa escalar evaluando f(u, v) en cada píxel. */
export function llenar(m: Mapa, f: (u: number, v: number, x: number, y: number) => number) {
  const { w, h, datos } = m;
  for (let y = 0; y < h; y++) {
    const v = (y + 0.5) / h;
    for (let x = 0; x < w; x++) datos[y * w + x] = f((x + 0.5) / w, v, x, y);
  }
  return m;
}

/** Normal map (espacio tangente, OpenGL) a partir de una altura, con bordes que repiten. */
export function normalDesdeAltura(alt: Mapa, fuerza: number): Uint8Array {
  const { w, h, datos } = alt;
  const out = new Uint8Array(w * h * 4);
  const at = (x: number, y: number) => datos[((y + h) % h) * w + ((x + w) % w)];
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      // Sobel
      const tl = at(x - 1, y - 1);
      const t = at(x, y - 1);
      const tr = at(x + 1, y - 1);
      const l = at(x - 1, y);
      const r = at(x + 1, y);
      const bl = at(x - 1, y + 1);
      const b = at(x, y + 1);
      const br = at(x + 1, y + 1);
      const dx = (tr + 2 * r + br - (tl + 2 * l + bl)) * fuerza;
      const dy = (bl + 2 * b + br - (tl + 2 * t + tr)) * fuerza;
      // y de la imagen crece hacia abajo; en UV crece hacia arriba (flipY = false en DataTexture).
      let nx = -dx;
      let ny = -dy;
      let nz = 1;
      const len = Math.hypot(nx, ny, nz);
      nx /= len;
      ny /= len;
      nz /= len;
      const i = (y * w + x) * 4;
      out[i] = (nx * 0.5 + 0.5) * 255;
      out[i + 1] = (ny * 0.5 + 0.5) * 255;
      out[i + 2] = (nz * 0.5 + 0.5) * 255;
      out[i + 3] = 255;
    }
  }
  return out;
}

export function texturaDatos(datos: Uint8Array, w: number, h: number, srgb: boolean, repetir = true) {
  const tex = new THREE.DataTexture(datos, w, h, THREE.RGBAFormat, THREE.UnsignedByteType);
  tex.colorSpace = srgb ? THREE.SRGBColorSpace : THREE.NoColorSpace;
  tex.wrapS = tex.wrapT = repetir ? THREE.RepeatWrapping : THREE.ClampToEdgeWrapping;
  tex.generateMipmaps = true;
  tex.minFilter = THREE.LinearMipmapLinearFilter;
  tex.magFilter = THREE.LinearFilter;
  tex.anisotropy = 8;
  tex.needsUpdate = true;
  return tex;
}

export function lienzo(w: number, h: number) {
  const c = document.createElement("canvas");
  c.width = w;
  c.height = h;
  const ctx = c.getContext("2d", { willReadFrequently: true })!;
  return { c, ctx };
}

export function texturaLienzo(c: HTMLCanvasElement, srgb = true) {
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = srgb ? THREE.SRGBColorSpace : THREE.NoColorSpace;
  tex.anisotropy = 8;
  return tex;
}

/** Lee el canal rojo de un lienzo como mapa de altura [0,1]. */
export function alturaDesdeLienzo(ctx: CanvasRenderingContext2D, w: number, h: number): Mapa {
  const img = ctx.getImageData(0, 0, w, h).data;
  const m = nuevoMapa(w, h);
  for (let i = 0; i < w * h; i++) m.datos[i] = img[i * 4] / 255;
  return m;
}

/** Cede el hilo principal para que la generación de texturas no congele la página. */
export const ceder = () => new Promise<void>((r) => setTimeout(r, 0));

/** Interpolación cúbica (Catmull-Rom no uniforme) de una serie de llaves {t, v}. */
export function curvaLlaves(ts: number[], vs: number[], t: number) {
  const n = ts.length;
  if (t <= ts[0]) return vs[0];
  if (t >= ts[n - 1]) return vs[n - 1];
  let i = 0;
  while (i < n - 2 && t > ts[i + 1]) i++;
  const t0 = ts[i];
  const t1 = ts[i + 1];
  const p0 = vs[i];
  const p1 = vs[i + 1];
  const pm = i > 0 ? vs[i - 1] : p0;
  const pp = i < n - 2 ? vs[i + 2] : p1;
  const tm = i > 0 ? ts[i - 1] : t0 - (t1 - t0);
  const tp = i < n - 2 ? ts[i + 2] : t1 + (t1 - t0);
  const m0 = ((p1 - pm) / (t1 - tm)) * (t1 - t0);
  const m1 = ((pp - p0) / (tp - t0)) * (t1 - t0);
  const s = (t - t0) / (t1 - t0);
  const s2 = s * s;
  const s3 = s2 * s;
  return (2 * s3 - 3 * s2 + 1) * p0 + (s3 - 2 * s2 + s) * m0 + (-2 * s3 + 3 * s2) * p1 + (s3 - s2) * m1;
}

/** Ruido suave 1D en el tiempo (para la cámara en mano). */
export function ruido1(t: number, semilla: number) {
  const i = Math.floor(t);
  const f = t - i;
  const a = hash2(i, semilla, 7) * 2 - 1;
  const b = hash2(i + 1, semilla, 7) * 2 - 1;
  const u = f * f * (3 - 2 * f);
  return lerp(a, b, u);
}

import * as THREE from "three";
import {
  alturaDesdeLienzo,
  azar,
  clamp01,
  fbm,
  fract,
  lerp,
  lienzo,
  llenar,
  normalDesdeAltura,
  nuevoMapa,
  ruido,
  ss,
  texturaDatos,
  texturaLienzo,
  worley,
} from "./util";

/*
 * Texturas PBR generadas en el navegador (color, normal y rugosidad).
 * No se descarga ninguna imagen: todo sale de ruido procedural con semilla fija,
 * así la escena pesa poco y se ve igual en cada carga.
 */

export type MaterialPBR = { map: THREE.Texture; normalMap: THREE.Texture; roughnessMap: THREE.Texture };

/** Empaqueta color (sRGB), rugosidad (canal G) y normal en DataTextures. */
function empaquetar(w: number, h: number, color: Float32Array, rug: Float32Array, normal: Uint8Array): MaterialPBR {
  const c = new Uint8Array(w * h * 4);
  const r = new Uint8Array(w * h * 4);
  for (let i = 0; i < w * h; i++) {
    c[i * 4] = clamp01(color[i * 3]) * 255;
    c[i * 4 + 1] = clamp01(color[i * 3 + 1]) * 255;
    c[i * 4 + 2] = clamp01(color[i * 3 + 2]) * 255;
    c[i * 4 + 3] = 255;
    const g = clamp01(rug[i]) * 255;
    r[i * 4] = g;
    r[i * 4 + 1] = g;
    r[i * 4 + 2] = g;
    r[i * 4 + 3] = 255;
  }
  return { map: texturaDatos(c, w, h, true), normalMap: texturaDatos(normal, w, h, false), roughnessMap: texturaDatos(r, w, h, false) };
}

/* ------------------------------------------------------------------ */
/* Cuero vacuno: grano "flor" de celdas, arrugas, pátina y costura de tiento */
/* ------------------------------------------------------------------ */
export const COSTURAS_V = [0.4, 0.79];

export function texturaCuero(res: number): MaterialPBR {
  const w = res;
  const h = res;
  const alt = nuevoMapa(w, h);
  const color = new Float32Array(w * h * 3);
  const rug = new Float32Array(w * h);
  const base = [0.29, 0.155, 0.075];
  const claro = [0.47, 0.27, 0.13];
  const tiento = [0.82, 0.7, 0.52];
  const anchoBanda = 0.03;
  llenar(alt, (u, v, x, y) => {
    const [f1, f2] = worley(u, v, 150, 3);
    const poro = ss(0.0, 0.14, f2 - f1); // 0 en los surcos entre "piedritas"
    const domo = 1 - ss(0.0, 0.75, f1);
    const arrugas = fbm(u, v * 0.4, 6, 4, 9);
    const pliegues = 1 - Math.abs(fbm(u, v, 3, 3, 21) * 2 - 1);
    let hgt = poro * 0.55 + domo * 0.25 + arrugas * 0.2 - ss(0.86, 0.98, pliegues) * 0.25;

    const patina = fbm(u, v, 4, 4, 33);
    const manchas = fbm(u, v, 12, 3, 41);
    const t = clamp01(0.35 + patina * 0.6 + (manchas - 0.5) * 0.25);
    let cr = lerp(base[0], claro[0], t);
    let cg = lerp(base[1], claro[1], t);
    let cb = lerp(base[2], claro[2], t);
    // Los surcos acumulan tinte y quedan más oscuros; los domos, gastados por la mano, más claros.
    const oscuro = 0.8 + 0.2 * poro;
    cr *= oscuro * (0.92 + domo * 0.16);
    cg *= oscuro * (0.92 + domo * 0.14);
    cb *= oscuro * (0.92 + domo * 0.1);
    let r = 0.62 - domo * 0.2 + (1 - poro) * 0.18 + (manchas - 0.5) * 0.1;

    // Costura de tiento trenzado
    for (const v0 of COSTURAS_V) {
      const dv = (v - v0) / anchoBanda;
      if (Math.abs(dv) < 1.6) {
        const s = fract(u * 48);
        // dos hilos cruzados en diagonal
        const a = Math.abs(fract(s + dv * 0.32) - 0.5);
        const b = Math.abs(fract(s - dv * 0.32 + 0.5) - 0.5);
        const hilo = Math.max(ss(0.32, 0.12, a), ss(0.32, 0.12, b)) * ss(1.25, 0.85, Math.abs(dv));
        const agujero = ss(0.2, 0.05, Math.abs(s - 0.5)) * ss(1.6, 1.25, Math.abs(dv)) * ss(1.05, 1.25, Math.abs(dv));
        if (hilo > 0.001) {
          hgt = lerp(hgt, 1.1 + hilo * 0.4, hilo);
          const sombra = 0.75 + 0.25 * hilo;
          cr = lerp(cr, tiento[0] * sombra, hilo);
          cg = lerp(cg, tiento[1] * sombra, hilo);
          cb = lerp(cb, tiento[2] * sombra, hilo);
          r = lerp(r, 0.55, hilo);
        }
        hgt -= agujero * 0.5;
        cr *= 1 - agujero * 0.6;
        cg *= 1 - agujero * 0.6;
        cb *= 1 - agujero * 0.6;
      }
    }
    const i = y * w + x;
    color[i * 3] = cr;
    color[i * 3 + 1] = cg;
    color[i * 3 + 2] = cb;
    rug[i] = r;
    return hgt;
  });
  return empaquetar(w, h, color, rug, normalDesdeAltura(alt, res / 700));
}

/* ------------------------------------------------------------------ */
/* Alpaca (plata alemana): cincelado a mano y cepillado                 */
/* ------------------------------------------------------------------ */
export function texturaCincelado(): MaterialPBR {
  const w = 1024;
  const h = 256;
  const { ctx } = lienzo(w, h);
  ctx.fillStyle = "#fff";
  ctx.fillRect(0, 0, w, h);
  ctx.strokeStyle = "#000";
  ctx.fillStyle = "#000";
  ctx.lineCap = "round";
  // filetes arriba y abajo
  for (const y of [18, 30, h - 30, h - 18]) {
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(w, y);
    ctx.stroke();
  }
  // perlado
  for (let x = 6; x < w; x += 12) {
    for (const y of [42, h - 42]) {
      ctx.beginPath();
      ctx.arc(x, y, 3.2, 0, Math.PI * 2);
      ctx.fill();
    }
  }
  // volutas y hojas (4 motivos por mosaico)
  const r = azar(77);
  const motivo = w / 4;
  for (let m = 0; m < 4; m++) {
    const cx = m * motivo + motivo / 2;
    const cy = h / 2;
    ctx.lineWidth = 3.4;
    for (const lado of [-1, 1]) {
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.bezierCurveTo(cx + lado * 40, cy - 60, cx + lado * 100, cy + 50, cx + lado * 118, cy - 6);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(cx + lado * 104, cy - 10, 16, 0, Math.PI * 2 * 0.8);
      ctx.stroke();
      // hojas
      for (let k = 0; k < 4; k++) {
        const t = 0.2 + k * 0.2;
        const px = cx + lado * (20 + 90 * t);
        const py = cy - 30 + 50 * Math.sin(t * Math.PI * 1.2) * (k % 2 ? 1 : -1) * 0.6;
        ctx.save();
        ctx.translate(px, py);
        ctx.rotate(lado * (0.6 + r() * 0.5) * (k % 2 ? 1 : -1));
        ctx.beginPath();
        ctx.ellipse(0, 0, 13, 4.5, 0, 0, Math.PI * 2);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(-11, 0);
        ctx.lineTo(11, 0);
        ctx.lineWidth = 1.6;
        ctx.stroke();
        ctx.lineWidth = 3.4;
        ctx.restore();
      }
    }
    // flor central
    for (let k = 0; k < 6; k++) {
      ctx.save();
      ctx.translate(cx, cy);
      ctx.rotate((k / 6) * Math.PI * 2);
      ctx.beginPath();
      ctx.ellipse(0, -11, 5, 10, 0, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
    }
    ctx.beginPath();
    ctx.arc(cx, cy, 4, 0, Math.PI * 2);
    ctx.fill();
  }
  // golpes de buril: punteado irregular de fondo
  for (let i = 0; i < 2600; i++) {
    const x = r() * w;
    const y = 50 + r() * (h - 100);
    ctx.globalAlpha = 0.18 + r() * 0.2;
    ctx.fillRect(x, y, 1.6, 1.6);
  }
  ctx.globalAlpha = 1;
  const altBruta = alturaDesdeLienzo(ctx, w, h);
  // suavizado leve para que los surcos tengan bisel
  const alt = nuevoMapa(w, h);
  for (let y = 0; y < h; y++)
    for (let x = 0; x < w; x++) {
      let s = 0;
      for (let j = -1; j <= 1; j++) for (let i = -1; i <= 1; i++) s += altBruta.datos[Math.min(h - 1, Math.max(0, y + j)) * w + ((x + i + w) % w)];
      alt.datos[y * w + x] = s / 9;
    }
  const color = new Float32Array(w * h * 3);
  const rug = new Float32Array(w * h);
  for (let y = 0; y < h; y++)
    for (let x = 0; x < w; x++) {
      const i = y * w + x;
      const a = alt.datos[i];
      const cep = ruido((x / w) * 6, (y / h) * 180, 6, 5) * 0.5 + ruido((x / w) * 24, (y / h) * 360, 24, 6) * 0.5;
      const ox = 0.42 + 0.58 * a; // oxidación en el surco
      color[i * 3] = 0.93 * ox;
      color[i * 3 + 1] = 0.91 * ox;
      color[i * 3 + 2] = 0.86 * ox;
      rug[i] = 0.17 + (1 - a) * 0.45 + cep * 0.08;
    }
  const t = empaquetar(w, h, color, rug, normalDesdeAltura(alt, 2.6));
  t.map.wrapT = t.normalMap.wrapT = t.roughnessMap.wrapT = THREE.ClampToEdgeWrapping;
  return t;
}

/** Metal cepillado (vetas en una dirección), para bombilla, base y termo. */
export function texturaCepillado(res: number): MaterialPBR {
  const w = res;
  const h = res;
  const alt = nuevoMapa(w, h);
  const color = new Float32Array(w * h * 3);
  const rug = new Float32Array(w * h);
  llenar(alt, (u, v, x, y) => {
    const a = ruido(u * 8, v * 512, 8, 2) * 0.6 + ruido(u * 32, v * 256, 32, 3) * 0.4;
    const rayas = ruido(u * 2, v * 1024, 2, 4);
    const marcas = fbm(u, v, 4, 3, 8);
    const i = y * w + x;
    const k = 0.94 + (a - 0.5) * 0.06;
    color[i * 3] = 0.9 * k;
    color[i * 3 + 1] = 0.9 * k;
    color[i * 3 + 2] = 0.88 * k;
    rug[i] = 0.2 + a * 0.12 + rayas * 0.06 + ss(0.6, 0.8, marcas) * 0.08;
    return a * 0.6 + rayas * 0.4;
  });
  return empaquetar(w, h, color, rug, normalDesdeAltura(alt, 0.35));
}

/* ------------------------------------------------------------------ */
/* Madera de mesa: tablas de petiribí con veta, poros y juntas          */
/* ------------------------------------------------------------------ */
export function texturaMadera(res: number): MaterialPBR {
  const w = res;
  const h = res;
  const tablas = 4;
  const alt = nuevoMapa(w, h);
  const color = new Float32Array(w * h * 3);
  const rug = new Float32Array(w * h);
  const r = azar(5);
  const tintes = Array.from({ length: tablas }, () => ({ k: 0.85 + r() * 0.25, des: r() * 50, corte: r(), veta: 2.2 + r() * 2.5 }));
  const claro = [0.55, 0.41, 0.29];
  const oscuro = [0.27, 0.17, 0.1];
  llenar(alt, (u, v, x, y) => {
    const fila = Math.min(tablas - 1, Math.floor(v * tablas));
    const t = tintes[fila];
    const vl = v * tablas - fila; // 0..1 dentro de la tabla
    // junta de testa: cada tabla corta en un lugar distinto
    const uu = fract(u + t.corte * 0.5);
    const juntaU = ss(0.004, 0.0, Math.min(uu, 1 - uu));
    const warp = fbm(u, v * 0.5, 2, 5, 50 + fila) * 3.4;
    // veta "catedral": los anillos se cierran en arcos a lo largo de la tabla
    const catedral = Math.abs(vl - 0.5) * 2 * t.veta + Math.cos(u * Math.PI * 2 + t.des) * 0.9;
    const anillos = catedral + warp;
    const anillo = fract(anillos);
    const perfil = ss(0.0, 0.18, anillo) * ss(1.0, 0.55, anillo); // madera temprana/tardía
    const poros = ruido(u * 6, v * 700, 6, 70 + fila);
    const fibra = ruido(u * 40, v * 900, 40, 80 + fila);
    const mezcla = clamp01(0.3 + perfil * 0.45 + (fibra - 0.5) * 0.35 - ss(0.72, 0.95, poros) * 0.35);
    let cr = lerp(oscuro[0], claro[0], mezcla) * t.k;
    let cg = lerp(oscuro[1], claro[1], mezcla) * t.k;
    let cb = lerp(oscuro[2], claro[2], mezcla) * t.k;
    const juntaV = ss(0.012, 0.0, Math.min(vl, 1 - vl));
    const junta = Math.max(juntaV, juntaU);
    cr *= 1 - junta * 0.7;
    cg *= 1 - junta * 0.7;
    cb *= 1 - junta * 0.7;
    const i = y * w + x;
    color[i * 3] = cr;
    color[i * 3 + 1] = cg;
    color[i * 3 + 2] = cb;
    rug[i] = 0.42 + ss(0.75, 0.95, poros) * 0.2 + junta * 0.3 + (1 - perfil) * 0.06;
    return perfil * 0.25 - ss(0.75, 0.95, poros) * 0.35 - junta * 1.4 + fibra * 0.08;
  });
  return empaquetar(w, h, color, rug, normalDesdeAltura(alt, res / 512));
}

/* ------------------------------------------------------------------ */
/* Papel del paquete: fibra + etiqueta impresa                          */
/* ------------------------------------------------------------------ */
export function texturaFibraPapel(res: number) {
  const w = res;
  const h = res;
  const alt = nuevoMapa(w, h);
  const r = azar(19);
  llenar(alt, (u, v) => fbm(u, v, 32, 3, 12) * 0.6 + ruido(u * 128, v * 128, 128, 13) * 0.4);
  // fibras sueltas
  for (let k = 0; k < 2200; k++) {
    let x = r() * w;
    let y = r() * h;
    const a = r() * Math.PI * 2;
    const l = 6 + r() * 18;
    for (let s = 0; s < l; s++) {
      x += Math.cos(a) + (r() - 0.5) * 0.4;
      y += Math.sin(a) + (r() - 0.5) * 0.4;
      const i = (((Math.floor(y) % h) + h) % h) * w + (((Math.floor(x) % w) + w) % w);
      alt.datos[i] += 0.25;
    }
  }
  return texturaDatos(normalDesdeAltura(alt, 0.9), w, h, false);
}

/** Frente, laterales y dorso impresos del paquete de yerba (sRGB). */
export function texturasPaquete() {
  const verde = "#2c573b";
  const verdeOsc = "#1d3d29";
  const crema = "#f3ead8";
  const oro = "#c9a24b";
  const terracota = "#b4572e";
  const r = azar(3);
  const granulado = (ctx: CanvasRenderingContext2D, w: number, h: number, n: number) => {
    for (let i = 0; i < n; i++) {
      ctx.fillStyle = r() > 0.5 ? "rgba(0,0,0,0.05)" : "rgba(255,255,255,0.035)";
      ctx.fillRect(r() * w, r() * h, 1 + r() * 2, 1 + r() * 2);
    }
  };
  const hoja = (ctx: CanvasRenderingContext2D, x: number, y: number, s: number, rot: number, fill: string) => {
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(rot);
    ctx.fillStyle = fill;
    ctx.beginPath();
    ctx.moveTo(0, -s);
    ctx.bezierCurveTo(s * 0.62, -s * 0.5, s * 0.6, s * 0.55, 0, s);
    ctx.bezierCurveTo(-s * 0.6, s * 0.55, -s * 0.62, -s * 0.5, 0, -s);
    ctx.fill();
    ctx.strokeStyle = "rgba(0,0,0,0.25)";
    ctx.lineWidth = s * 0.05;
    ctx.beginPath();
    ctx.moveTo(0, -s * 0.9);
    ctx.lineTo(0, s * 0.9);
    ctx.stroke();
    for (let k = -3; k <= 3; k++) {
      if (!k) continue;
      ctx.beginPath();
      ctx.moveTo(0, k * s * 0.22);
      ctx.lineTo(Math.sign(k) * s * 0.4, k * s * 0.22 - s * 0.18);
      ctx.moveTo(0, k * s * 0.22);
      ctx.lineTo(-Math.sign(k) * s * 0.4, k * s * 0.22 - s * 0.18);
      ctx.stroke();
    }
    ctx.restore();
  };

  // Frente
  const F = lienzo(1024, 1600);
  {
    const { ctx } = F;
    const w = 1024;
    const h = 1600;
    ctx.fillStyle = verde;
    ctx.fillRect(0, 0, w, h);
    // trama de hojitas impresa en el fondo
    for (let i = 0; i < 70; i++) hoja(ctx, r() * w, r() * h, 26 + r() * 30, r() * 6, "rgba(255,255,255,0.045)");
    granulado(ctx, w, h, 14000);
    // franja superior (zona del doblez)
    ctx.fillStyle = verdeOsc;
    ctx.fillRect(0, 0, w, 210);
    ctx.fillStyle = oro;
    ctx.fillRect(0, 210, w, 14);
    ctx.fillStyle = crema;
    ctx.font = "600 34px Georgia, serif";
    ctx.textAlign = "center";
    ctx.fillText("ESTACIONADA 24 MESES · MISIONES", w / 2, 130);
    // etiqueta
    ctx.fillStyle = crema;
    ctx.beginPath();
    ctx.roundRect(80, 330, w - 160, 860, 40);
    ctx.fill();
    ctx.strokeStyle = oro;
    ctx.lineWidth = 6;
    ctx.beginPath();
    ctx.roundRect(104, 354, w - 208, 812, 30);
    ctx.stroke();
    hoja(ctx, w / 2, 560, 130, 0.25, verde);
    ctx.fillStyle = verdeOsc;
    ctx.font = "italic 700 150px Georgia, serif";
    ctx.fillText("duomate", w / 2, 860);
    ctx.fillStyle = terracota;
    ctx.font = "800 54px Arial, Helvetica, sans-serif";
    ctx.fillText("BLEND SUAVE", w / 2, 950);
    ctx.fillStyle = "#5c5246";
    ctx.font = "600 34px Arial, Helvetica, sans-serif";
    ctx.fillText("YERBA MATE ELABORADA CON PALO", w / 2, 1020);
    ctx.fillText("Bajo contenido de polvo", w / 2, 1070);
    // sello
    ctx.fillStyle = oro;
    ctx.beginPath();
    ctx.arc(w - 190, 1290, 105, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = verdeOsc;
    ctx.font = "800 64px Arial, Helvetica, sans-serif";
    ctx.fillText("1 kg", w - 190, 1312);
    ctx.fillStyle = crema;
    ctx.textAlign = "left";
    ctx.font = "700 40px Arial, Helvetica, sans-serif";
    ctx.fillText("INDUSTRIA ARGENTINA", 90, 1300);
    ctx.font = "500 30px Arial, Helvetica, sans-serif";
    ctx.fillText("Contenido neto 1 kg · RNPA 13-000420", 90, 1350);
    ctx.fillStyle = oro;
    ctx.fillRect(0, h - 120, w, 12);
  }
  // Lateral (fuelle): verde con texto vertical
  const L = lienzo(512, 1600);
  {
    const { ctx } = L;
    const w = 512;
    const h = 1600;
    ctx.fillStyle = verde;
    ctx.fillRect(0, 0, w, h);
    granulado(ctx, w, h, 6000);
    ctx.fillStyle = verdeOsc;
    ctx.fillRect(0, 0, w, 210);
    ctx.fillStyle = oro;
    ctx.fillRect(0, 210, w, 14);
    ctx.save();
    ctx.translate(w / 2, h / 2 + 80);
    ctx.rotate(-Math.PI / 2);
    ctx.fillStyle = crema;
    ctx.textAlign = "center";
    ctx.font = "italic 700 120px Georgia, serif";
    ctx.fillText("duomate", 0, 40);
    ctx.restore();
    ctx.fillStyle = oro;
    ctx.fillRect(0, h - 120, w, 12);
  }
  // Dorso: modo de preparación + código de barras
  const D = lienzo(1024, 1600);
  {
    const { ctx } = D;
    const w = 1024;
    const h = 1600;
    ctx.fillStyle = verde;
    ctx.fillRect(0, 0, w, h);
    granulado(ctx, w, h, 12000);
    ctx.fillStyle = verdeOsc;
    ctx.fillRect(0, 0, w, 210);
    ctx.fillStyle = oro;
    ctx.fillRect(0, 210, w, 14);
    ctx.fillStyle = crema;
    ctx.textAlign = "left";
    ctx.font = "700 56px Georgia, serif";
    ctx.fillText("Cómo cebar", 90, 340);
    ctx.font = "500 32px Arial, Helvetica, sans-serif";
    ["1. Llená ¾ del mate con yerba.", "2. Tapá, invertí y sacudí.", "3. Inclinalo y clavá la bombilla.", "4. Cebá con agua a 75–80 °C."].forEach((t, i) =>
      ctx.fillText(t, 90, 420 + i * 60),
    );
    ctx.fillStyle = crema;
    ctx.fillRect(90, 1160, 360, 200);
    ctx.fillStyle = "#111";
    let x = 110;
    while (x < 430) {
      const a = 2 + Math.floor(r() * 4);
      ctx.fillRect(x, 1180, a, 140);
      x += a + 2 + Math.floor(r() * 4);
    }
    ctx.fillStyle = oro;
    ctx.fillRect(0, h - 120, w, 12);
  }
  return {
    frente: texturaLienzo(F.c),
    lateral: texturaLienzo(L.c),
    dorso: texturaLienzo(D.c),
  };
}

/* ------------------------------------------------------------------ */
/* Yerba (superficie del mate y boca del paquete)                       */
/* ------------------------------------------------------------------ */
export function texturaYerba(res: number) {
  const w = res;
  const h = res;
  const C = lienzo(w, h);
  const A = lienzo(w, h);
  const r = azar(42);
  const verdes = ["#5c7a2e", "#6f8f3c", "#86a54f", "#4b6626", "#9bb664", "#7a9440", "#a9b979", "#62743a"];
  C.ctx.fillStyle = "#56702d";
  C.ctx.fillRect(0, 0, w, h);
  A.ctx.fillStyle = "#606060";
  A.ctx.fillRect(0, 0, w, h);
  const escala = res / 1024;
  const dibujar = (fn: (ctx: CanvasRenderingContext2D, alto: boolean) => void) => {
    fn(C.ctx, false);
    fn(A.ctx, true);
  };
  // copos de hoja (polígonos irregulares)
  const n = Math.floor(26000 * escala * escala);
  for (let i = 0; i < n; i++) {
    const x = r() * w;
    const y = r() * h;
    const s = (3 + r() * 9) * escala;
    const lados = 4 + Math.floor(r() * 3);
    const rot = r() * Math.PI;
    const col = verdes[Math.floor(r() * verdes.length)];
    const altura = Math.floor(110 + r() * 145);
    const forma: [number, number][] = [];
    for (let k = 0; k < lados; k++) {
      const a = rot + (k / lados) * Math.PI * 2;
      const rr = s * (0.5 + r() * 0.6);
      forma.push([Math.cos(a) * rr * 1.4, Math.sin(a) * rr * 0.8]);
    }
    dibujar((ctx, alto) => {
      ctx.fillStyle = alto ? `rgb(${altura},${altura},${altura})` : col;
      ctx.beginPath();
      forma.forEach(([fx, fy], k) => (k ? ctx.lineTo(x + fx, y + fy) : ctx.moveTo(x + fx, y + fy)));
      ctx.closePath();
      ctx.fill();
    });
  }
  // palitos
  for (let i = 0; i < 900 * escala * escala * 4; i++) {
    const x = r() * w;
    const y = r() * h;
    const a = r() * Math.PI;
    const l = (8 + r() * 22) * escala;
    const g = (1.4 + r() * 1.8) * escala;
    const col = ["#cdbb8a", "#bba675", "#d8c99d", "#a99464"][Math.floor(r() * 4)];
    dibujar((ctx, alto) => {
      ctx.strokeStyle = alto ? "#fff" : col;
      ctx.lineWidth = g;
      ctx.lineCap = "round";
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(x + Math.cos(a) * l, y + Math.sin(a) * l);
      ctx.stroke();
    });
  }
  // polvo
  for (let i = 0; i < 30000 * escala * escala; i++) {
    const x = r() * w;
    const y = r() * h;
    C.ctx.fillStyle = r() > 0.4 ? "rgba(196,200,140,0.5)" : "rgba(60,80,30,0.5)";
    C.ctx.fillRect(x, y, escala, escala);
  }
  const alt = alturaDesdeLienzo(A.ctx, w, h);
  const color = texturaLienzo(C.c);
  color.wrapS = color.wrapT = THREE.RepeatWrapping;
  return { map: color, normalMap: texturaDatos(normalDesdeAltura(alt, 1.4), w, h, false) };
}

/* ------------------------------------------------------------------ */
/* Interior de calabaza curada                                          */
/* ------------------------------------------------------------------ */
export function texturaCalabaza(res: number) {
  const w = res / 2;
  const h = res / 2;
  const c = new Uint8Array(w * h * 4);
  for (let y = 0; y < h; y++)
    for (let x = 0; x < w; x++) {
      const u = x / w;
      const v = y / h;
      const n = fbm(u, v, 6, 5, 90);
      const f = ruido(u * 8, v * 64, 8, 91);
      const i = (y * w + x) * 4;
      c[i] = (0.2 + n * 0.16 + f * 0.04) * 255;
      c[i + 1] = (0.12 + n * 0.1 + f * 0.03) * 255;
      c[i + 2] = (0.06 + n * 0.05) * 255;
      c[i + 3] = 255;
    }
  return texturaDatos(c, w, h, true);
}

/* ------------------------------------------------------------------ */
/* Termo: pintura en polvo con logo grabado (metal a la vista)           */
/* ------------------------------------------------------------------ */
export function texturasTermo() {
  const w = 1024;
  const h = 512;
  const C = lienzo(w, h);
  const M = lienzo(w, h);
  C.ctx.fillStyle = "#24493a";
  C.ctx.fillRect(0, 0, w, h);
  M.ctx.fillStyle = "#000";
  M.ctx.fillRect(0, 0, w, h);
  const r = azar(8);
  for (let i = 0; i < 30000; i++) {
    C.ctx.fillStyle = r() > 0.5 ? "rgba(0,0,0,0.06)" : "rgba(255,255,255,0.03)";
    C.ctx.fillRect(r() * w, r() * h, 1.5, 1.5);
  }
  for (const [ctx, col] of [
    [C.ctx, "#c9ccd0"],
    [M.ctx, "#fff"],
  ] as const) {
    ctx.save();
    ctx.translate(w * 0.25, h * 0.52);
    ctx.rotate(-Math.PI / 2);
    ctx.fillStyle = col;
    ctx.textAlign = "center";
    ctx.font = "italic 700 92px Georgia, serif";
    ctx.fillText("duomate", 0, 30);
    ctx.restore();
  }
  // piel de naranja de la pintura
  const alt = nuevoMapa(512, 256);
  llenar(alt, (u, v) => fbm(u, v * 0.5, 64, 2, 31));
  return {
    map: texturaLienzo(C.c),
    metalnessMap: texturaLienzo(M.c, false),
    normalMap: texturaDatos(normalDesdeAltura(alt, 1.2), 512, 256, false),
  };
}

/* ------------------------------------------------------------------ */
/* Sprites y máscaras                                                   */
/* ------------------------------------------------------------------ */
/** Sombra de contacto: degradé radial suave (alpha). */
export function texturaContacto() {
  const { c, ctx } = lienzo(256, 256);
  const g = ctx.createRadialGradient(128, 128, 0, 128, 128, 128);
  g.addColorStop(0, "rgba(0,0,0,1)");
  g.addColorStop(0.35, "rgba(0,0,0,0.65)");
  g.addColorStop(0.7, "rgba(0,0,0,0.18)");
  g.addColorStop(1, "rgba(0,0,0,0)");
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, 256, 256);
  return texturaLienzo(c, false);
}

/** Espuma de cebado: burbujas apiñadas con densidad variable (color + alpha). */
export function texturaEspuma() {
  const w = 512;
  const { c, ctx } = lienzo(w, w);
  ctx.clearRect(0, 0, w, w);
  const r = azar(55);
  for (let i = 0; i < 5200; i++) {
    const x = r() * w;
    const y = r() * w;
    const u = x / w;
    const v = y / w;
    const dens = fbm(u, v, 4, 3, 66);
    if (r() > dens * 1.5 - 0.1) continue;
    const rad = 1.5 + Math.pow(r(), 3) * 10;
    const g = ctx.createRadialGradient(x - rad * 0.3, y - rad * 0.3, 0, x, y, rad);
    g.addColorStop(0, "rgba(255,255,248,0.95)");
    g.addColorStop(0.65, "rgba(236,238,214,0.75)");
    g.addColorStop(0.9, "rgba(170,180,130,0.85)");
    g.addColorStop(1, "rgba(150,160,110,0)");
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(x, y, rad, 0, Math.PI * 2);
    ctx.fill();
  }
  const t = texturaLienzo(c);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  return t;
}

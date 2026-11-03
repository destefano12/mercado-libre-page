import * as THREE from "three";
import { fbm, ss } from "./util";

/*
 * HDRI procedural: un "estudio-cocina" equirectangular en punto flotante.
 * Tiene una ventana grande con parteluces (la luz principal, que es la que se
 * refleja en la alpaca y el termo), un panel de relleno frío, un rim cálido y
 * paredes que rebotan luz tibia. Se filtra con PMREM para la iluminación por
 * imagen, igual que una .hdr descargada pero sin pesar megas.
 */

export const DIRECCION_VENTANA = new THREE.Vector3(-0.62, 0.55, 0.56).normalize();

type Panel = {
  centro: THREE.Vector3;
  ancho: number; // tangente del semiángulo
  alto: number;
  color: [number, number, number];
  intensidad: number;
  parteluces?: { cols: number; filas: number; grosor: number };
  suavidad: number;
};

function base(c: THREE.Vector3) {
  const arriba = Math.abs(c.y) > 0.95 ? new THREE.Vector3(1, 0, 0) : new THREE.Vector3(0, 1, 0);
  const der = new THREE.Vector3().crossVectors(arriba, c).normalize();
  const sup = new THREE.Vector3().crossVectors(c, der).normalize();
  return { der, sup };
}

export function crearHDRI(ancho = 1024) {
  const alto = ancho / 2;
  const datos = new Float32Array(ancho * alto * 4);
  const paneles: Panel[] = [
    {
      centro: DIRECCION_VENTANA.clone(),
      ancho: 0.55,
      alto: 0.62,
      color: [1.0, 0.95, 0.86],
      intensidad: 11,
      parteluces: { cols: 3, filas: 2, grosor: 0.035 },
      suavidad: 0.03,
    },
    { centro: new THREE.Vector3(0.85, 0.3, 0.42).normalize(), ancho: 0.5, alto: 0.4, color: [0.86, 0.92, 1.0], intensidad: 3.2, suavidad: 0.25 },
    { centro: new THREE.Vector3(0.25, 0.45, -0.86).normalize(), ancho: 0.9, alto: 0.12, color: [1.0, 0.82, 0.6], intensidad: 7, suavidad: 0.08 },
    { centro: new THREE.Vector3(0, 1, 0), ancho: 0.7, alto: 0.7, color: [1.0, 0.97, 0.92], intensidad: 1.6, suavidad: 0.4 },
  ];
  const bases = paneles.map((p) => base(p.centro));
  const d = new THREE.Vector3();
  for (let y = 0; y < alto; y++) {
    const v = (y + 0.5) / alto;
    const lat = (v - 0.5) * Math.PI;
    for (let x = 0; x < ancho; x++) {
      const u = (x + 0.5) / ancho;
      const lon = (u - 0.5) * Math.PI * 2;
      d.set(Math.cos(lat) * Math.cos(lon), Math.sin(lat), Math.cos(lat) * Math.sin(lon));
      // Ambiente: paredes crema arriba, mesa/piso madera abajo, horizonte tibio.
      const h = d.y;
      const pared = [0.62, 0.55, 0.47];
      const piso = [0.2, 0.13, 0.08];
      const t = ss(-0.12, 0.08, h);
      const variacion = 0.85 + fbm(u, v, 6, 3, 4) * 0.3;
      let r = (piso[0] + (pared[0] - piso[0]) * t) * variacion;
      let g = (piso[1] + (pared[1] - piso[1]) * t) * variacion;
      let b = (piso[2] + (pared[2] - piso[2]) * t) * variacion;
      // muebles oscuros difusos a los costados (dan contraste a los reflejos)
      const mueble = ss(0.25, 0.0, Math.abs(h - 0.05)) * ss(0.2, 0.6, Math.abs(Math.sin(lon * 1.5 + 0.7)));
      r *= 1 - mueble * 0.5;
      g *= 1 - mueble * 0.5;
      b *= 1 - mueble * 0.5;
      for (let k = 0; k < paneles.length; k++) {
        const p = paneles[k];
        const cd = d.dot(p.centro);
        if (cd <= 0.05) continue;
        const px = d.dot(bases[k].der) / cd;
        const py = d.dot(bases[k].sup) / cd;
        const mx = ss(p.ancho + p.suavidad, p.ancho - p.suavidad, Math.abs(px));
        const my = ss(p.alto + p.suavidad, p.alto - p.suavidad, Math.abs(py));
        let m = mx * my;
        if (m <= 0) continue;
        if (p.parteluces) {
          const { cols, filas, grosor } = p.parteluces;
          const fx = ((px / p.ancho) * 0.5 + 0.5) * cols;
          const fy = ((py / p.alto) * 0.5 + 0.5) * filas;
          const bx = Math.abs(fx - Math.round(fx)) / cols;
          const by = Math.abs(fy - Math.round(fy)) / filas;
          m *= ss(grosor * 0.5, grosor, Math.min(bx, by) * 2);
          // cielo: un poco más azul arriba de la ventana
          const cielo = ss(-0.2, 0.6, py / p.alto);
          r += m * p.intensidad * (p.color[0] - cielo * 0.08);
          g += m * p.intensidad * p.color[1];
          b += m * p.intensidad * (p.color[2] + cielo * 0.12);
          continue;
        }
        r += m * p.intensidad * p.color[0];
        g += m * p.intensidad * p.color[1];
        b += m * p.intensidad * p.color[2];
      }
      const i = (y * ancho + x) * 4;
      datos[i] = r;
      datos[i + 1] = g;
      datos[i + 2] = b;
      datos[i + 3] = 1;
    }
  }
  const tex = new THREE.DataTexture(datos, ancho, alto, THREE.RGBAFormat, THREE.FloatType);
  tex.mapping = THREE.EquirectangularReflectionMapping;
  tex.colorSpace = THREE.LinearSRGBColorSpace;
  tex.magFilter = THREE.LinearFilter;
  tex.minFilter = THREE.LinearFilter;
  tex.needsUpdate = true;
  return tex;
}

/** Fondo de estudio: ciclorama curvo con degradé cálido y caída de luz. */
export function crearCiclorama() {
  const geo = new THREE.CylinderGeometry(14, 14, 14, 96, 1, true, Math.PI * 0.62, Math.PI * 0.76);
  const mat = new THREE.ShaderMaterial({
    side: THREE.BackSide,
    depthWrite: true,
    uniforms: {
      uArriba: { value: new THREE.Color(0xeee4d2).convertSRGBToLinear() },
      uAbajo: { value: new THREE.Color(0xcdb99a).convertSRGBToLinear() },
      uLuz: { value: new THREE.Color(0xfff1da).convertSRGBToLinear() },
    },
    vertexShader: /* glsl */ `
      varying vec3 vPos;
      void main() {
        vPos = position;
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }`,
    fragmentShader: /* glsl */ `
      uniform vec3 uArriba;
      uniform vec3 uAbajo;
      uniform vec3 uLuz;
      varying vec3 vPos;
      void main() {
        float h = clamp((vPos.y + 1.0) / 4.0, 0.0, 1.0);
        vec3 c = mix(uAbajo, uArriba, smoothstep(0.0, 0.7, h));
        // mancha de luz de la ventana sobre la pared
        float ang = atan(vPos.z, vPos.x);
        float spot = exp(-pow((ang + 1.9) * 2.2, 2.0)) * exp(-pow((vPos.y - 2.6) * 0.32, 2.0));
        c += uLuz * spot * 0.55;
        gl_FragColor = vec4(c, 1.0);
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
      }`,
  });
  // El fragment hace su propio tonemapping solo si se renderiza a pantalla; en el composer lo hace OutputPass.
  const m = new THREE.Mesh(geo, mat);
  m.position.set(0, 6, 0);
  return m;
}

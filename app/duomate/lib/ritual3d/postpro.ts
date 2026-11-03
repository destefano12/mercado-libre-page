import * as THREE from "three";
import { EffectComposer } from "three/examples/jsm/postprocessing/EffectComposer.js";
import { OutputPass } from "three/examples/jsm/postprocessing/OutputPass.js";
import { FullScreenQuad, Pass } from "three/examples/jsm/postprocessing/Pass.js";
import { RenderPass } from "three/examples/jsm/postprocessing/RenderPass.js";
import { ShaderPass } from "three/examples/jsm/postprocessing/ShaderPass.js";
import { UnrealBloomPass } from "three/examples/jsm/postprocessing/UnrealBloomPass.js";

/*
 * Cadena de postprocesado, en HDR (half float) hasta el tone mapping:
 *  render (MSAA) → profundidad de campo (bokeh de disco, usa el depth del render)
 *  → bloom suave → tone mapping ACES + sRGB → grading de lente
 *  (aberración cromática, viñeta, virado cálido y grano de película).
 */

class PasoDOF extends Pass {
  material: THREE.ShaderMaterial;
  private quad: FullScreenQuad;
  constructor(muestras: number) {
    super();
    this.material = new THREE.ShaderMaterial({
      defines: { MUESTRAS: muestras },
      uniforms: {
        tColor: { value: null },
        tDepth: { value: null },
        uRes: { value: new THREE.Vector2(1, 1) },
        uFoco: { value: 5 },
        uApertura: { value: 10 },
        uMaxCoc: { value: 12 },
        uNear: { value: 0.1 },
        uFar: { value: 60 },
      },
      vertexShader: /* glsl */ `
        varying vec2 vUv;
        void main() { vUv = uv; gl_Position = vec4(position.xy, 0.0, 1.0); }`,
      fragmentShader: /* glsl */ `
        #include <packing>
        uniform sampler2D tColor; uniform sampler2D tDepth;
        uniform vec2 uRes; uniform float uFoco; uniform float uApertura; uniform float uMaxCoc;
        uniform float uNear; uniform float uFar;
        varying vec2 vUv;
        float prof(vec2 uv) { return -perspectiveDepthToViewZ(texture2D(tDepth, uv).x, uNear, uFar); }
        float coc(float z) { return clamp(uApertura * abs(z - uFoco) / max(z, 0.001), 0.0, uMaxCoc); }
        void main() {
          vec4 base = texture2D(tColor, vUv);
          float zc = prof(vUv);
          float cc = coc(zc);
          vec3 acc = base.rgb;
          float tot = 1.0;
          const float GA = 2.39996323;
          for (int i = 0; i < MUESTRAS; i++) {
            float fi = float(i) + 0.5;
            float r = sqrt(fi / float(MUESTRAS)) * uMaxCoc;
            float a = fi * GA;
            vec2 uv2 = vUv + vec2(cos(a), sin(a)) * r / uRes;
            float z = prof(uv2);
            float cs = coc(z);
            // lo que está detrás de algo enfocado no se derrama encima
            if (z > zc) cs = min(cs, cc * 2.0);
            float m = smoothstep(r - 1.0, r + 1.0, cs);
            acc += texture2D(tColor, uv2).rgb * m;
            tot += m;
          }
          gl_FragColor = vec4(acc / tot, base.a);
        }`,
      depthTest: false,
      depthWrite: false,
    });
    this.quad = new FullScreenQuad(this.material);
  }
  setSize(w: number, h: number) {
    this.material.uniforms.uRes.value.set(w, h);
  }
  render(renderer: THREE.WebGLRenderer, writeBuffer: THREE.WebGLRenderTarget, readBuffer: THREE.WebGLRenderTarget) {
    this.material.uniforms.tColor.value = readBuffer.texture;
    this.material.uniforms.tDepth.value = readBuffer.depthTexture;
    renderer.setRenderTarget(this.renderToScreen ? null : writeBuffer);
    this.quad.render(renderer);
  }
  dispose() {
    this.material.dispose();
    this.quad.dispose();
  }
}

const Grading = {
  uniforms: {
    tDiffuse: { value: null },
    uT: { value: 0 },
    uRes: { value: new THREE.Vector2(1, 1) },
    uVineta: { value: 0.32 },
    uGrano: { value: 0.035 },
    uCA: { value: 0.003 },
  },
  vertexShader: /* glsl */ `
    varying vec2 vUv;
    void main() { vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }`,
  fragmentShader: /* glsl */ `
    uniform sampler2D tDiffuse; uniform float uT; uniform vec2 uRes;
    uniform float uVineta; uniform float uGrano; uniform float uCA;
    varying vec2 vUv;
    float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
    void main() {
      vec2 d = vUv - 0.5;
      float r2 = dot(d, d);
      vec2 ca = d * uCA * r2 * 4.0;
      vec3 col;
      col.r = texture2D(tDiffuse, vUv - ca).r;
      col.g = texture2D(tDiffuse, vUv).g;
      col.b = texture2D(tDiffuse, vUv + ca).b;
      float l = dot(col, vec3(0.2126, 0.7152, 0.0722));
      // virado: altas luces tibias, sombras apenas verdosas (la paleta de la marca)
      col *= mix(vec3(0.985, 1.0, 1.01), vec3(1.025, 1.0, 0.965), smoothstep(0.15, 0.9, l));
      col *= mix(1.0, 1.0 - uVineta, smoothstep(0.08, 0.55, r2 * 1.3));
      float g = hash(vUv * uRes + fract(uT * 7.13) * 91.7) - 0.5;
      col += g * uGrano * (1.0 - l * 0.7);
      gl_FragColor = vec4(col, 1.0);
    }`,
};

export function crearPostpro(renderer: THREE.WebGLRenderer, escena: THREE.Scene, camara: THREE.PerspectiveCamera, calidad: "alta" | "media") {
  const rt = new THREE.WebGLRenderTarget(1, 1, {
    type: THREE.HalfFloatType,
    samples: calidad === "alta" ? 4 : 0,
    depthTexture: new THREE.DepthTexture(1, 1, THREE.UnsignedIntType),
  });
  const composer = new EffectComposer(renderer, rt);
  composer.addPass(new RenderPass(escena, camara));
  const dof = new PasoDOF(calidad === "alta" ? 40 : 18);
  composer.addPass(dof);
  const bloom = new UnrealBloomPass(new THREE.Vector2(256, 256), 0.07, 0.4, 1.6);
  composer.addPass(bloom);
  composer.addPass(new OutputPass());
  const grading = new ShaderPass(Grading);
  composer.addPass(grading);

  return {
    composer,
    setSize(w: number, h: number, ratio: number) {
      composer.setPixelRatio(ratio);
      composer.setSize(w, h);
      grading.uniforms.uRes.value.set(w * ratio, h * ratio);
    },
    /** foco: distancia (unidades de vista) al plano nítido; apertura: tamaño del bokeh. */
    setFoco(foco: number, apertura: number, maxCoc: number) {
      const u = dof.material.uniforms;
      u.uFoco.value = foco;
      u.uApertura.value = apertura;
      u.uMaxCoc.value = maxCoc;
      u.uNear.value = camara.near;
      u.uFar.value = camara.far;
    },
    render(t: number) {
      grading.uniforms.uT.value = t;
      composer.render();
    },
    dispose() {
      composer.dispose();
      dof.dispose();
      bloom.dispose();
      rt.dispose();
    },
  };
}

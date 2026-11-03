import * as THREE from "three";
import { azar } from "./util";

/*
 * Vapor volumétrico falso: columnas de planos que miran a la cámara (billboard
 * cilíndrico) con ruido simplex 3D advectado hacia arriba, warp de dominio y
 * desvanecimiento por altura. Depende del tiempo: sigue humeando aunque el
 * scroll esté quieto.
 */

const RUIDO = /* glsl */ `
vec3 mod289(vec3 x){return x-floor(x*(1.0/289.0))*289.0;}
vec4 mod289(vec4 x){return x-floor(x*(1.0/289.0))*289.0;}
vec4 permute(vec4 x){return mod289(((x*34.0)+1.0)*x);}
vec4 taylorInvSqrt(vec4 r){return 1.79284291400159-0.85373472095314*r;}
float snoise(vec3 v){
  const vec2 C=vec2(1.0/6.0,1.0/3.0);const vec4 D=vec4(0.0,0.5,1.0,2.0);
  vec3 i=floor(v+dot(v,C.yyy));vec3 x0=v-i+dot(i,C.xxx);
  vec3 g=step(x0.yzx,x0.xyz);vec3 l=1.0-g;vec3 i1=min(g.xyz,l.zxy);vec3 i2=max(g.xyz,l.zxy);
  vec3 x1=x0-i1+C.xxx;vec3 x2=x0-i2+C.yyy;vec3 x3=x0-D.yyy;
  i=mod289(i);
  vec4 p=permute(permute(permute(i.z+vec4(0.0,i1.z,i2.z,1.0))+i.y+vec4(0.0,i1.y,i2.y,1.0))+i.x+vec4(0.0,i1.x,i2.x,1.0));
  float n_=0.142857142857;vec3 ns=n_*D.wyz-D.xzx;
  vec4 j=p-49.0*floor(p*ns.z*ns.z);vec4 x_=floor(j*ns.z);vec4 y_=floor(j-7.0*x_);
  vec4 x=x_*ns.x+ns.yyyy;vec4 y=y_*ns.x+ns.yyyy;vec4 h=1.0-abs(x)-abs(y);
  vec4 b0=vec4(x.xy,y.xy);vec4 b1=vec4(x.zw,y.zw);
  vec4 s0=floor(b0)*2.0+1.0;vec4 s1=floor(b1)*2.0+1.0;vec4 sh=-step(h,vec4(0.0));
  vec4 a0=b0.xzyw+s0.xzyw*sh.xxyy;vec4 a1=b1.xzyw+s1.xzyw*sh.zzww;
  vec3 p0=vec3(a0.xy,h.x);vec3 p1=vec3(a0.zw,h.y);vec3 p2=vec3(a1.xy,h.z);vec3 p3=vec3(a1.zw,h.w);
  vec4 norm=taylorInvSqrt(vec4(dot(p0,p0),dot(p1,p1),dot(p2,p2),dot(p3,p3)));
  p0*=norm.x;p1*=norm.y;p2*=norm.z;p3*=norm.w;
  vec4 m=max(0.6-vec4(dot(x0,x0),dot(x1,x1),dot(x2,x2),dot(x3,x3)),0.0);m=m*m;
  return 42.0*dot(m*m,vec4(dot(p0,x0),dot(p1,x1),dot(p2,x2),dot(p3,x3)));
}
float fbm(vec3 p){float s=0.0;float a=0.5;for(int i=0;i<4;i++){s+=a*snoise(p);p*=2.03;a*=0.5;}return s*0.5+0.5;}
`;

export function crearVapor(escena: THREE.Scene, n: number) {
  const r = azar(4);
  const geo = new THREE.PlaneGeometry(1, 1, 1, 1);
  geo.translate(0, 0.5, 0);
  const columnas = Array.from({ length: n }, () => {
    const mat = new THREE.ShaderMaterial({
      transparent: true,
      depthWrite: false,
      side: THREE.DoubleSide,
      uniforms: {
        uT: { value: 0 },
        uSemilla: { value: r() * 50 },
        uIntensidad: { value: 0 },
        uColor: { value: new THREE.Color(0xf7f3ea).convertSRGBToLinear().multiplyScalar(1.15) },
        uSombra: { value: new THREE.Color(0xa69c8c).convertSRGBToLinear() },
      },
      vertexShader: /* glsl */ `
        varying vec2 vUv;
        void main() {
          vUv = uv;
          gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
        }`,
      fragmentShader: /* glsl */ `
        uniform float uT; uniform float uSemilla; uniform float uIntensidad;
        uniform vec3 uColor; uniform vec3 uSombra;
        varying vec2 vUv;
        ${RUIDO}
        void main() {
          float y = vUv.y;
          float x = vUv.x - 0.5;
          // la columna se mece y se abre al subir
          float t = uT;
          x += sin(y * 3.4 + t * 0.9 + uSemilla) * 0.07 * y;
          x += (fbm(vec3(y * 1.6, t * 0.18, uSemilla)) - 0.5) * 0.35 * y;
          float ancho = mix(0.06, 0.42, pow(y, 0.8));
          float perfil = smoothstep(ancho, ancho * 0.1, abs(x));
          vec3 q = vec3(x * 3.2, y * 2.6 - t * 0.62, t * 0.12 + uSemilla);
          float w = fbm(q * 1.3 + vec3(0.0, -t * 0.2, 0.0));
          float n = fbm(q + vec3(w * 1.4, w * 0.6, 0.0));
          float dens = smoothstep(0.38, 0.82, n * (0.55 + perfil * 0.7)) * perfil;
          dens *= smoothstep(0.0, 0.1, y) * smoothstep(1.0, 0.4, y);
          float a = clamp(dens * uIntensidad, 0.0, 1.0) * 0.5;
          if (a < 0.003) discard;
          // autosombreado aproximado: más denso, un poco más gris
          vec3 col = mix(uColor, uSombra, smoothstep(0.55, 0.95, n) * 0.35);
          gl_FragColor = vec4(col, a);
        }`,
    });
    const m = new THREE.Mesh(geo, mat);
    m.frustumCulled = false;
    m.renderOrder = 5;
    escena.add(m);
    return { m, mat, dx: (r() - 0.5) * 0.22, dz: (r() - 0.5) * 0.22, alto: 1.2 + r() * 0.8, ancho: 0.55 + r() * 0.35, giro: (r() - 0.5) * 0.6, vel: 0.8 + r() * 0.4 };
  });

  /** origen en el mundo, intensidad 0..1, posición de la cámara para el billboard. */
  function actualizar(t: number, origen: THREE.Vector3, intensidad: number, camara: THREE.Vector3) {
    for (const c of columnas) {
      c.m.visible = intensidad > 0.01;
      if (!c.m.visible) continue;
      c.m.position.set(origen.x + c.dx, origen.y, origen.z + c.dz);
      c.m.rotation.y = Math.atan2(camara.x - c.m.position.x, camara.z - c.m.position.z) + c.giro;
      c.m.scale.set(c.ancho, c.alto * (0.6 + 0.4 * intensidad), 1);
      c.mat.uniforms.uT.value = t * c.vel;
      c.mat.uniforms.uIntensidad.value = intensidad;
    }
  }
  return { actualizar };
}

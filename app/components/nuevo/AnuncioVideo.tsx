"use client";

import { useState } from "react";

/**
 * Anuncio animado con aspecto de video: una camioneta de reparto cruza la
 * ciudad mientras corre la barra de progreso. Todo es SVG y CSS, sin archivos
 * de video, asi que carga al instante. Con "reducir movimiento" activado en el
 * sistema queda quieto.
 */
export function AnuncioVideo({ onAbrir }: { onAbrir: () => void }) {
  const [pausado, setPausado] = useState(false);

  return (
    <section className={`nv-video${pausado ? " is-pausado" : ""}`} aria-label="Anuncio: envíos en el día">
      <div className="nv-video__escena" aria-hidden="true">
        <svg viewBox="0 0 640 240" preserveAspectRatio="xMidYMax slice">
          <rect width="640" height="240" fill="url(#nv-cielo)" />
          <circle className="nv-video__sol" cx="540" cy="60" r="28" fill="#ffd166" />
          <g className="nv-video__nubes" fill="rgba(255,255,255,.85)">
            <ellipse cx="120" cy="50" rx="38" ry="12" />
            <ellipse cx="380" cy="34" rx="30" ry="10" />
            <ellipse cx="760" cy="56" rx="40" ry="12" />
          </g>
          <g fill="#3d4b6b">
            <rect x="20" y="110" width="60" height="100" />
            <rect x="90" y="80" width="46" height="130" />
            <rect x="146" y="124" width="70" height="86" />
            <rect x="226" y="96" width="52" height="114" />
            <rect x="288" y="132" width="80" height="78" />
            <rect x="378" y="70" width="44" height="140" />
            <rect x="432" y="112" width="66" height="98" />
            <rect x="508" y="90" width="56" height="120" />
            <rect x="574" y="126" width="60" height="84" />
          </g>
          <g fill="rgba(255,224,138,.8)">
            {[100, 112, 238, 250, 390, 402, 520, 532].map((x) =>
              [96, 120, 144].map((y) => <rect key={`${x}-${y}`} x={x} y={y} width="8" height="10" />),
            )}
          </g>
          <rect y="206" width="640" height="34" fill="#2b2d42" />
          <g className="nv-video__lineas" fill="#ffd166">
            {Array.from({ length: 12 }, (_, i) => (
              <rect key={i} x={i * 70} y="221" width="34" height="4" />
            ))}
          </g>
          <g className="nv-video__camioneta">
            <rect x="0" y="160" width="96" height="42" rx="5" fill="#ff5a5f" />
            <path d="M96 170 H124 L142 188 V202 H96 Z" fill="#e0484d" />
            <path d="M102 175 H122 L134 188 H102 Z" fill="#cfe8ff" />
            <text x="48" y="186" textAnchor="middle" fontSize="13" fontWeight="700" fill="#fff">LIVE</text>
            <circle cx="26" cy="204" r="10" fill="#14121f" />
            <circle cx="118" cy="204" r="10" fill="#14121f" />
          </g>
          <defs>
            <linearGradient id="nv-cielo" x1="0" x2="0" y1="0" y2="1">
              <stop offset="0" stopColor="#7cc6ff" />
              <stop offset="1" stopColor="#d9f0ff" />
            </linearGradient>
          </defs>
        </svg>
      </div>

      <div className="nv-video__texto">
        <span className="nv-video__etiqueta">Anuncio</span>
        <h2>Comprá antes de las 13 y lo recibís hoy</h2>
        <p>Envíos en el día en productos con el sello Live Express.</p>
        <button type="button" onClick={onAbrir}>Ver productos con envío hoy</button>
      </div>

      <div className="nv-video__controles">
        <button
          type="button"
          onClick={() => setPausado((valor) => !valor)}
          aria-label={pausado ? "Reproducir anuncio" : "Pausar anuncio"}
        >
          {pausado ? "▶" : "❚❚"}
        </button>
        <div className="nv-video__barra" aria-hidden="true">
          <span />
        </div>
        <span className="nv-video__tiempo" aria-hidden="true">0:12</span>
      </div>
    </section>
  );
}

import type { CategoryId } from "../../data/marketplace";

/**
 * Ilustraciones propias de Mercado Live, dibujadas en SVG. Sirven para los
 * banners, las portadas de categoria y los anuncios: no dependen de fotos de
 * terceros y se ven nitidas en cualquier pantalla.
 */

type Arte =
  | "auto"
  | "casa"
  | "tecno"
  | "moda"
  | "hogar"
  | "herramienta"
  | "super"
  | "play"
  | "deporte"
  | "envio"
  | "regalo";

const ARTE_POR_CATEGORIA: Partial<Record<CategoryId, Arte>> = {
  vehiculos: "auto",
  "accesorios-vehiculos": "auto",
  inmuebles: "casa",
  construccion: "casa",
  tecnologia: "tecno",
  electrodomesticos: "tecno",
  juegos: "tecno",
  moda: "moda",
  belleza: "moda",
  hogar: "hogar",
  bebes: "hogar",
  herramientas: "herramienta",
  industrias: "herramienta",
  agro: "herramienta",
  supermercado: "super",
  mascotas: "super",
  salud: "super",
  streaming: "play",
  deportes: "deporte",
  internacional: "envio",
  negocio: "envio",
};

export function arteDeCategoria(id: CategoryId): Arte {
  return ARTE_POR_CATEGORIA[id] ?? "regalo";
}

export function ArteCategoria({ arte, className }: { arte: Arte; className?: string }) {
  return (
    <svg className={className} viewBox="0 0 240 160" role="presentation" aria-hidden="true">
      {DIBUJOS[arte]}
    </svg>
  );
}

const DIBUJOS: Record<Arte, React.ReactNode> = {
  auto: (
    <g>
      <ellipse cx="120" cy="132" rx="96" ry="10" fill="rgba(0,0,0,.18)" />
      <path d="M30 108 L44 78 Q52 62 72 60 L150 58 Q170 58 184 74 L204 96 Q214 98 216 110 L216 118 Q216 124 210 124 L36 124 Q28 124 28 116 Z" fill="#ff5a5f" />
      <path d="M62 66 L148 64 Q162 64 172 78 L180 90 L56 92 Z" fill="#cfe8ff" />
      <path d="M112 64 L114 92" stroke="#ff5a5f" strokeWidth="6" />
      <rect x="196" y="100" width="16" height="8" rx="3" fill="#ffe08a" />
      <rect x="30" y="102" width="12" height="8" rx="3" fill="#ffb3b3" />
      <circle cx="72" cy="124" r="20" fill="#2b2d42" />
      <circle cx="72" cy="124" r="9" fill="#d9dde3" />
      <circle cx="176" cy="124" r="20" fill="#2b2d42" />
      <circle cx="176" cy="124" r="9" fill="#d9dde3" />
    </g>
  ),
  casa: (
    <g>
      <rect x="24" y="130" width="192" height="10" rx="5" fill="rgba(0,0,0,.15)" />
      <rect x="54" y="70" width="132" height="62" fill="#fff4e0" />
      <path d="M40 76 L120 22 L200 76 Z" fill="#2fa36b" />
      <rect x="104" y="92" width="32" height="40" rx="3" fill="#7a4b2a" />
      <circle cx="129" cy="113" r="2.5" fill="#ffd166" />
      <rect x="66" y="88" width="26" height="22" rx="2" fill="#bfe3ff" />
      <rect x="148" y="88" width="26" height="22" rx="2" fill="#bfe3ff" />
      <path d="M79 88 V110 M66 99 H92 M161 88 V110 M148 99 H174" stroke="#fff" strokeWidth="2" />
      <rect x="150" y="34" width="14" height="26" fill="#b23a48" />
      <circle cx="206" cy="112" r="16" fill="#3cc47c" />
      <rect x="203" y="118" width="6" height="14" fill="#7a4b2a" />
    </g>
  ),
  tecno: (
    <g>
      <rect x="34" y="34" width="132" height="86" rx="8" fill="#1f2433" />
      <rect x="42" y="42" width="116" height="70" rx="3" fill="url(#pantalla)" />
      <path d="M22 124 H178 L170 134 H30 Z" fill="#9aa3b5" />
      <rect x="168" y="50" width="48" height="86" rx="9" fill="#1f2433" />
      <rect x="172" y="58" width="40" height="68" rx="3" fill="url(#pantalla)" />
      <circle cx="192" cy="131" r="2.5" fill="#9aa3b5" />
      <path d="M58 92 L78 72 L94 86 L112 62 L142 92" fill="none" stroke="#fff" strokeWidth="4" strokeLinecap="round" strokeLinejoin="round" />
      <defs>
        <linearGradient id="pantalla" x1="0" x2="1" y1="0" y2="1">
          <stop offset="0" stopColor="#6a5cff" />
          <stop offset="1" stopColor="#00d4c8" />
        </linearGradient>
      </defs>
    </g>
  ),
  moda: (
    <g>
      <path d="M120 24 Q132 24 132 36 Q132 44 124 48 L120 52" fill="none" stroke="#3a3a3a" strokeWidth="4" strokeLinecap="round" />
      <path d="M120 52 L40 92 Q34 96 40 98 L200 98 Q206 96 200 92 Z" fill="none" stroke="#3a3a3a" strokeWidth="4" strokeLinejoin="round" />
      <path d="M62 98 L52 140 H112 L104 98 Z" fill="#f28fad" />
      <path d="M136 98 L128 140 H188 L178 98 Z" fill="#ffc857" />
      <path d="M52 140 L58 112 M188 140 L182 112" stroke="rgba(0,0,0,.12)" strokeWidth="6" />
      <circle cx="82" cy="118" r="3" fill="#fff" />
      <circle cx="158" cy="118" r="3" fill="#fff" />
    </g>
  ),
  hogar: (
    <g>
      <rect x="24" y="134" width="192" height="8" rx="4" fill="rgba(0,0,0,.14)" />
      <rect x="40" y="78" width="160" height="40" rx="14" fill="#e07a5f" />
      <rect x="54" y="60" width="132" height="34" rx="12" fill="#f2a488" />
      <rect x="40" y="96" width="28" height="30" rx="10" fill="#c96a50" />
      <rect x="172" y="96" width="28" height="30" rx="10" fill="#c96a50" />
      <rect x="52" y="124" width="8" height="12" fill="#5c4033" />
      <rect x="180" y="124" width="8" height="12" fill="#5c4033" />
      <rect x="90" y="66" width="26" height="22" rx="6" fill="#f4f1de" />
      <path d="M206 30 V70" stroke="#3d405b" strokeWidth="3" />
      <path d="M194 70 H218 L212 54 H200 Z" fill="#f2cc8f" />
    </g>
  ),
  herramienta: (
    <g>
      <path d="M44 70 H140 Q150 70 150 80 V96 Q150 104 140 104 H96 L86 140 H62 L70 104 H44 Q36 104 36 96 V78 Q36 70 44 70 Z" fill="#f4a300" />
      <rect x="150" y="80" width="26" height="14" rx="3" fill="#3a3a3a" />
      <rect x="176" y="84" width="40" height="6" rx="3" fill="#9aa3b5" />
      <rect x="48" y="78" width="40" height="8" rx="4" fill="rgba(255,255,255,.4)" />
      <rect x="66" y="112" width="14" height="10" rx="2" fill="#3a3a3a" />
      <circle cx="198" cy="40" r="16" fill="none" stroke="#9aa3b5" strokeWidth="6" />
    </g>
  ),
  super: (
    <g>
      <path d="M40 68 H200 L186 136 Q184 142 178 142 H62 Q56 142 54 136 Z" fill="#2fa36b" />
      <path d="M70 68 Q76 30 120 30 Q164 30 170 68" fill="none" stroke="#1d6b45" strokeWidth="6" />
      <circle cx="92" cy="58" r="16" fill="#ff6b4a" />
      <path d="M92 42 Q96 36 102 38" stroke="#2fa36b" strokeWidth="3" fill="none" />
      <rect x="112" y="34" width="20" height="38" rx="4" fill="#ffd166" />
      <ellipse cx="152" cy="58" rx="18" ry="12" fill="#a7d676" />
      <path d="M56 92 H184 M60 114 H180" stroke="rgba(255,255,255,.35)" strokeWidth="4" />
    </g>
  ),
  play: (
    <g>
      <rect x="28" y="30" width="184" height="104" rx="12" fill="#14121f" />
      <rect x="36" y="38" width="168" height="88" rx="6" fill="url(#cine)" />
      <circle cx="120" cy="82" r="26" fill="rgba(255,255,255,.9)" />
      <path d="M112 68 L136 82 L112 96 Z" fill="#7b2ff7" />
      <rect x="92" y="138" width="56" height="8" rx="4" fill="#14121f" />
      <defs>
        <linearGradient id="cine" x1="0" x2="1" y1="0" y2="1">
          <stop offset="0" stopColor="#7b2ff7" />
          <stop offset="1" stopColor="#f107a3" />
        </linearGradient>
      </defs>
    </g>
  ),
  deporte: (
    <g>
      <path d="M36 112 Q40 84 70 80 L110 76 Q122 60 140 64 L150 92 Q196 96 204 112 Q206 124 194 126 H48 Q34 126 36 112 Z" fill="#3a86ff" />
      <path d="M48 126 H194 Q204 126 204 132 Q204 138 194 138 H48 Q38 138 38 132 Q38 126 48 126 Z" fill="#fff" stroke="#d0d6e0" strokeWidth="2" />
      <path d="M92 80 L100 98 M108 78 L116 96 M124 74 L132 92" stroke="#fff" strokeWidth="4" strokeLinecap="round" />
      <circle cx="190" cy="44" r="22" fill="#ffbe0b" />
      <path d="M176 36 Q190 44 204 36 M176 52 Q190 44 204 52" stroke="#e09f00" strokeWidth="3" fill="none" />
    </g>
  ),
  envio: (
    <g>
      <rect x="20" y="132" width="200" height="6" rx="3" fill="rgba(0,0,0,.15)" />
      <rect x="28" y="64" width="112" height="64" rx="6" fill="#3a86ff" />
      <path d="M140 80 H182 L206 104 V128 H140 Z" fill="#2563c9" />
      <path d="M150 88 H178 L194 104 H150 Z" fill="#cfe8ff" />
      <circle cx="66" cy="130" r="13" fill="#2b2d42" />
      <circle cx="176" cy="130" r="13" fill="#2b2d42" />
      <rect x="54" y="44" width="40" height="30" rx="3" fill="#d9a066" />
      <path d="M74 44 V74" stroke="#b07a40" strokeWidth="3" />
      <path d="M42 92 H90" stroke="rgba(255,255,255,.5)" strokeWidth="6" strokeLinecap="round" />
    </g>
  ),
  regalo: (
    <g>
      <rect x="56" y="70" width="128" height="70" rx="6" fill="#7b2ff7" />
      <rect x="48" y="56" width="144" height="22" rx="5" fill="#9b5cff" />
      <rect x="110" y="56" width="20" height="84" fill="#ffd166" />
      <path d="M120 56 Q96 22 82 40 Q74 54 120 56 Q166 54 158 40 Q144 22 120 56 Z" fill="#ffd166" />
    </g>
  ),
};

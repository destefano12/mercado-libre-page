import { useId } from "react";
import type { Arte } from "../lib/catalogo";

type Props = { arte: Arte; color: string; className?: string };

/** Ilustraciones vectoriales de cada producto, pintadas con el color de la variante elegida. */
export function ArteProducto({ arte, color, className }: Props) {
  const uid = useId().replace(/:/g, "");
  const g = (n: string) => `${n}-${uid}`;
  const url = (n: string) => `url(#${g(n)})`;

  const defs = (
    <defs>
      <linearGradient id={g("cuerpo")} x1="0" x2="1" y1="0" y2="0">
        <stop offset="0" stopColor={color} stopOpacity="0.75" />
        <stop offset="0.35" stopColor={color} />
        <stop offset="1" stopColor="#000" stopOpacity="0.35" />
      </linearGradient>
      <linearGradient id={g("metal")} x1="0" x2="1" y1="0" y2="0">
        <stop offset="0" stopColor="#8d9096" />
        <stop offset="0.3" stopColor="#f4f5f7" />
        <stop offset="0.6" stopColor="#b9bcc2" />
        <stop offset="1" stopColor="#6f7277" />
      </linearGradient>
      <linearGradient id={g("bronce")} x1="0" x2="1" y1="0" y2="0">
        <stop offset="0" stopColor="#7a5524" />
        <stop offset="0.35" stopColor="#f0c878" />
        <stop offset="1" stopColor="#7a5524" />
      </linearGradient>
      <radialGradient id={g("yerba")} cx="0.5" cy="0.4" r="0.6">
        <stop offset="0" stopColor="#8fb15a" />
        <stop offset="1" stopColor="#4d6b2c" />
      </radialGradient>
      <radialGradient id={g("sombra")} cx="0.5" cy="0.5" r="0.5">
        <stop offset="0" stopColor="#000" stopOpacity="0.28" />
        <stop offset="1" stopColor="#000" stopOpacity="0" />
      </radialGradient>
    </defs>
  );

  const sombra = <ellipse cx="100" cy="182" rx="58" ry="9" fill={url("sombra")} />;

  const bombilla = (x: number, y: number, rot = 14, metal = "metal") => (
    <g transform={`rotate(${rot} ${x} ${y})`}>
      <rect x={x - 3} y={y - 70} width="6" height="92" rx="3" fill={url(metal)} />
      <path d={`M${x - 3} ${y - 70} q0 -12 -12 -14`} stroke={url(metal)} strokeWidth="6" fill="none" strokeLinecap="round" />
      <rect x={x - 5} y={y - 30} width="10" height="7" rx="2" fill={url("bronce")} />
    </g>
  );

  let cuerpo: React.ReactNode;

  switch (arte) {
    case "imperial":
    case "calabaza": {
      const virola = arte === "imperial" ? "metal" : "bronce";
      cuerpo = (
        <>
          {bombilla(118, 70)}
          <path d="M58 82 C 40 112, 44 160, 100 168 C 156 160, 160 112, 142 82 Z" fill={url("cuerpo")} />
          {arte === "imperial" && (
            <path d="M60 120 C 80 128, 120 128, 140 120" stroke="#000" strokeOpacity="0.25" strokeWidth="2" fill="none" strokeDasharray="3 4" />
          )}
          <ellipse cx="100" cy="84" rx="44" ry="10" fill="#3a2a16" />
          <ellipse cx="100" cy="82" rx="36" ry="6" fill={url("yerba")} />
          <path d="M54 78 h92 v10 a46 10 0 0 1 -92 0 Z" fill={url(virola)} />
          {arte === "imperial" &&
            [64, 76, 88, 100, 112, 124, 136].map((x) => <circle key={x} cx={x} cy="86" r="1.6" fill="#6f7277" />)}
          <path d="M80 166 h40 l6 10 h-52 Z" fill={url(virola)} />
        </>
      );
      break;
    }
    case "camionero":
      cuerpo = (
        <>
          {bombilla(122, 64, 18)}
          <path d="M48 74 C 34 110, 40 162, 100 170 C 160 162, 166 110, 152 74 Z" fill={url("cuerpo")} />
          <path d="M52 100 C 70 106, 130 106, 148 100" stroke="#f4e9d3" strokeOpacity="0.55" strokeWidth="2" strokeDasharray="5 5" fill="none" />
          <path d="M50 150 C 70 158, 130 158, 150 150" stroke="#f4e9d3" strokeOpacity="0.45" strokeWidth="2" strokeDasharray="5 5" fill="none" />
          <ellipse cx="100" cy="76" rx="54" ry="11" fill="#3a2a16" />
          <ellipse cx="100" cy="74" rx="46" ry="7" fill={url("yerba")} />
          <path d="M44 70 h112 v8 a56 11 0 0 1 -112 0 Z" fill={url("metal")} />
        </>
      );
      break;
    case "torpedo":
      cuerpo = (
        <>
          {bombilla(112, 52, 10)}
          <path d="M72 60 C 64 100, 70 150, 86 172 h28 C 130 150, 136 100, 128 60 Z" fill={url("cuerpo")} />
          {[80, 100, 120, 140].map((y) => (
            <path key={y} d={`M${74 - (y - 60) * 0.02} ${y} q26 6 52 0`} stroke="#000" strokeOpacity="0.15" strokeWidth="2" fill="none" />
          ))}
          <ellipse cx="100" cy="60" rx="28" ry="7" fill="#3a2a16" />
          <ellipse cx="100" cy="59" rx="22" ry="4.5" fill={url("yerba")} />
        </>
      );
      break;
    case "vidrio":
      cuerpo = (
        <>
          {bombilla(116, 62, 14)}
          <path d="M60 66 L 66 168 h68 L 140 66 Z" fill="#e6f1ee" fillOpacity="0.55" stroke="#ffffff" strokeOpacity="0.8" strokeWidth="2" />
          <path d="M63 96 L 66 168 h68 L 137 96 Z" fill={url("cuerpo")} />
          <path d="M63 96 h74" stroke="#f4e9d3" strokeOpacity="0.6" strokeWidth="2" strokeDasharray="4 4" />
          <ellipse cx="100" cy="68" rx="38" ry="7" fill={url("yerba")} />
          <path d="M70 72 L 72 92" stroke="#fff" strokeOpacity="0.7" strokeWidth="3" strokeLinecap="round" />
        </>
      );
      break;
    case "acero":
      cuerpo = (
        <>
          {bombilla(116, 62, 14)}
          <path d="M56 70 C 52 120, 60 160, 100 170 C 140 160, 148 120, 144 70 Z" fill={url("cuerpo")} />
          <path d="M74 84 C 70 118, 74 146, 86 160" stroke="#fff" strokeOpacity="0.35" strokeWidth="6" strokeLinecap="round" fill="none" />
          <ellipse cx="100" cy="72" rx="44" ry="9" fill={url("metal")} />
          <ellipse cx="100" cy="72" rx="37" ry="6" fill={url("yerba")} />
        </>
      );
      break;
    case "bombilla":
      cuerpo = (
        <g transform="rotate(-28 100 100)">
          <rect x="96" y="26" width="8" height="140" rx="4" fill={url(color === "#c59b55" ? "bronce" : "metal")} />
          <path d="M96 30 q0 -18 -20 -20" stroke={url("metal")} strokeWidth="8" fill="none" strokeLinecap="round" />
          <rect x="93" y="84" width="14" height="10" rx="3" fill={url("bronce")} />
          <ellipse cx="100" cy="168" rx="16" ry="10" fill={url("metal")} />
          {[-8, -3, 2, 7].map((dx) => (
            <rect key={dx} x={100 + dx - 1} y="162" width="2" height="12" rx="1" fill="#55585d" />
          ))}
          <rect x="96" y="26" width="8" height="140" rx="4" fill={color} opacity="0.18" />
        </g>
      );
      break;
    case "yerba":
      cuerpo = (
        <>
          <path d="M58 44 L 62 30 h76 l4 14 Z" fill="#d9ccb1" />
          <path d="M54 44 h92 l6 128 H48 Z" fill={url("cuerpo")} />
          <rect x="62" y="72" width="76" height="70" rx="6" fill="#f6efe2" />
          <path d="M100 84 c-14 10 -14 26 0 34 c14 -8 14 -24 0 -34 Z" fill={color} />
          <path d="M100 86 v32" stroke="#f6efe2" strokeWidth="1.5" />
          <rect x="72" y="124" width="56" height="5" rx="2.5" fill={color} opacity="0.7" />
          <rect x="80" y="133" width="40" height="4" rx="2" fill={color} opacity="0.45" />
          <path d="M54 44 h92" stroke="#000" strokeOpacity="0.2" strokeWidth="2" />
        </>
      );
      break;
    case "termo":
      cuerpo = (
        <>
          <rect x="72" y="30" width="56" height="20" rx="6" fill={url("metal")} />
          <path d="M80 30 l-14 -10 h20 l6 10 Z" fill={url("metal")} />
          <rect x="66" y="48" width="68" height="128" rx="14" fill={url("cuerpo")} />
          <rect x="66" y="48" width="68" height="10" fill={url("metal")} />
          <rect x="66" y="164" width="68" height="12" rx="6" fill={url("metal")} />
          <path d="M80 66 v88" stroke="#fff" strokeOpacity="0.28" strokeWidth="7" strokeLinecap="round" />
          <circle cx="100" cy="112" r="11" fill="none" stroke="#f6efe2" strokeOpacity="0.7" strokeWidth="2" />
          <path d="M95 112 a5 5 0 0 0 10 0" stroke="#f6efe2" strokeOpacity="0.7" strokeWidth="2" fill="none" />
        </>
      );
      break;
    case "matera":
      cuerpo = (
        <>
          <path d="M64 70 C 64 20, 136 20, 136 70" stroke={color} strokeWidth="8" fill="none" />
          <rect x="74" y="44" width="22" height="34" rx="5" fill={url("metal")} />
          <rect x="40" y="66" width="120" height="104" rx="14" fill={url("cuerpo")} />
          <rect x="48" y="74" width="104" height="88" rx="10" fill="none" stroke="#f4e9d3" strokeOpacity="0.5" strokeWidth="2" strokeDasharray="5 5" />
          <rect x="70" y="96" width="60" height="40" rx="8" fill="#000" fillOpacity="0.18" />
          <rect x="94" y="88" width="12" height="16" rx="3" fill={url("bronce")} />
        </>
      );
      break;
    case "kit":
      cuerpo = (
        <>
          <g transform="translate(-28 6) scale(0.78)">
            <path d="M58 44 L 62 30 h76 l4 14 Z" fill="#d9ccb1" />
            <path d="M54 44 h92 l6 128 H48 Z" fill="#3d6b47" />
            <rect x="62" y="72" width="76" height="70" rx="6" fill="#f6efe2" />
            <path d="M100 84 c-14 10 -14 26 0 34 c14 -8 14 -24 0 -34 Z" fill="#3d6b47" />
          </g>
          <g transform="translate(40 34) scale(0.72)">
            {bombilla(122, 64, 18)}
            <path d="M48 74 C 34 110, 40 162, 100 170 C 160 162, 166 110, 152 74 Z" fill={url("cuerpo")} />
            <ellipse cx="100" cy="76" rx="54" ry="11" fill="#3a2a16" />
            <ellipse cx="100" cy="74" rx="46" ry="7" fill={url("yerba")} />
            <path d="M44 70 h112 v8 a56 11 0 0 1 -112 0 Z" fill={url("metal")} />
          </g>
        </>
      );
      break;
  }

  return (
    <svg viewBox="0 0 200 200" className={className} role="img" aria-hidden="true">
      {defs}
      {sombra}
      {cuerpo}
    </svg>
  );
}

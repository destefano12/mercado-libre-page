import type { SVGProps } from "react";

/**
 * Set de íconos de trazo. Reemplazan a los emoji decorativos: un ícono dibujado
 * al mismo peso en toda la app ordena la lectura, un emoji la interrumpe.
 */
export type NombreIcono =
  | "hoy"
  | "manifiesto"
  | "planificador"
  | "tutor"
  | "explicame"
  | "mapa"
  | "errores"
  | "grupos"
  | "agenda"
  | "pomodoro"
  | "simulador"
  | "adultos"
  | "ayuda"
  | "menu"
  | "cerrar"
  | "mas"
  | "check"
  | "flecha"
  | "racha"
  | "idea"
  | "repetir"
  | "reloj"
  | "archivo"
  | "papelera"
  | "copiar";

const TRAZOS: Record<NombreIcono, string> = {
  hoy: "M3 10.5 12 3l9 7.5M5.5 9.5V20h13V9.5M10 20v-5.5h4V20",
  manifiesto: "M12 3 5 5.8v5.4c0 4.2 2.9 7.6 7 8.8 4.1-1.2 7-4.6 7-8.8V5.8L12 3Zm-2.6 8.6 2 2 3.8-3.8",
  planificador: "M4.5 6.5h15M4.5 12h15M4.5 17.5h15M8 4.5v4M16 10v4M11 15.5v4",
  tutor: "M4 5.5h16v11H12l-4.5 3.5v-3.5H4v-11Zm5.8 3.6a2.3 2.3 0 0 1 4.4.9c0 1.6-2.2 1.8-2.2 3.2m0 2.1h.01",
  explicame: "M12 3.5a2.6 2.6 0 0 0-2.6 2.6v5a2.6 2.6 0 0 0 5.2 0v-5A2.6 2.6 0 0 0 12 3.5ZM6 10.6v.7a6 6 0 0 0 12 0v-.7M12 17.4V21M8.8 21h6.4",
  mapa: "M4.5 4.5h6v6h-6v-6Zm9 0h6v6h-6v-6Zm-9 9h6v6h-6v-6Zm9 0h6v6h-6v-6Z",
  errores: "M9 4.5h6M8 6.5h8a1.5 1.5 0 0 1 1.5 1.5v11A1.5 1.5 0 0 1 16 20.5H8A1.5 1.5 0 0 1 6.5 19V8A1.5 1.5 0 0 1 8 6.5Zm4 3.5v4.2m0 2.3h.01M9 4.5a1.5 1.5 0 0 1 1.5-1.5h3A1.5 1.5 0 0 1 15 4.5",
  grupos: "M9 11.5a3.2 3.2 0 1 0 0-6.4 3.2 3.2 0 0 0 0 6.4ZM3.5 20v-1.2A4.3 4.3 0 0 1 7.8 14.5h2.4a4.3 4.3 0 0 1 4.3 4.3V20M16 5.6a3 3 0 0 1 0 5.8m1.4 3.4a4.3 4.3 0 0 1 3.1 4.1V20",
  agenda: "M4.5 6.5h15v13h-15v-13Zm0 4.2h15M8.5 3.5v3m7-3v3M8.5 14.5h2m3 0h2m-7 3h2m3 0h2",
  pomodoro: "M12 21a8 8 0 1 0 0-16 8 8 0 0 0 0 16Zm0-12.2V13l3 2M9.2 3.6h5.6",
  simulador: "M8 4.5h8a1.5 1.5 0 0 1 1.5 1.5v13A1.5 1.5 0 0 1 16 20.5H8A1.5 1.5 0 0 1 6.5 19V6A1.5 1.5 0 0 1 8 4.5Zm1.4 7.7 1.8 1.8 3.4-3.6M9.5 3.5h5v2h-5v-2Z",
  adultos: "M4 19.5h16M5.5 19.5V13m4.3 6.5V8.5m4.4 11V11m4.3 8.5V5.5",
  ayuda: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Zm-2.2-11.4a2.3 2.3 0 0 1 4.4.9c0 1.6-2.2 1.8-2.2 3.2m0 2.6h.01",
  menu: "M4 7h16M4 12h16M4 17h16",
  cerrar: "m6 6 12 12M18 6 6 18",
  mas: "M12 5v14M5 12h14",
  check: "m5 12.5 4.5 4.5L19 7.5",
  flecha: "M5 12h13m-5.5-5.5L18.5 12l-6 5.5",
  racha: "M13.6 2.8 6.4 12.4h4.7l-1.1 8.8 7.3-9.6h-4.8l1.1-8.8Z",
  idea: "M9 17.5h6M10 20.5h4M12 3.5a5.5 5.5 0 0 0-3.2 10c.5.4.7.9.7 1.5h5c0-.6.2-1.1.7-1.5A5.5 5.5 0 0 0 12 3.5Z",
  repetir: "M4.5 9.5A7.5 7.5 0 0 1 18 6.8M19.5 14.5A7.5 7.5 0 0 1 6 17.2M4.5 5v4.5H9M19.5 19v-4.5H15",
  reloj: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Zm0-13.5V12l3.5 2",
  archivo: "M14 3.5H8A1.5 1.5 0 0 0 6.5 5v14A1.5 1.5 0 0 0 8 20.5h8a1.5 1.5 0 0 0 1.5-1.5V7L14 3.5Zm-.5 0V7h4",
  papelera: "M5.5 7h13M10 7V5.5A1.5 1.5 0 0 1 11.5 4h1A1.5 1.5 0 0 1 14 5.5V7m3 0v12a1.5 1.5 0 0 1-1.5 1.5h-7A1.5 1.5 0 0 1 7 19V7m3 3.5v7m4-7v7",
  copiar: "M9 9V5.5A1.5 1.5 0 0 1 10.5 4h8A1.5 1.5 0 0 1 20 5.5v8a1.5 1.5 0 0 1-1.5 1.5H15M5.5 9h8A1.5 1.5 0 0 1 15 10.5v8A1.5 1.5 0 0 1 13.5 20h-8A1.5 1.5 0 0 1 4 18.5v-8A1.5 1.5 0 0 1 5.5 9Z",
};

interface PropsIcono extends SVGProps<SVGSVGElement> {
  nombre: NombreIcono;
  tamaño?: number;
}

export function Icono({ nombre, tamaño = 20, className = "", ...props }: PropsIcono) {
  return (
    <svg
      {...props}
      width={tamaño}
      height={tamaño}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.6}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
      className={`shrink-0 ${className}`}
    >
      <path d={TRAZOS[nombre]} />
    </svg>
  );
}

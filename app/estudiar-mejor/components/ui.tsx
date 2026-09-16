"use client";

import type { ButtonHTMLAttributes, InputHTMLAttributes, ReactNode, SelectHTMLAttributes, TextareaHTMLAttributes } from "react";
import { Icono, type NombreIcono } from "./iconos";

export function Tarjeta({
  children,
  className = "",
  animada = true,
  retraso = 0,
  tono = "normal",
}: {
  children: ReactNode;
  className?: string;
  animada?: boolean;
  retraso?: number;
  tono?: "normal" | "plana" | "oscura";
}) {
  const fondos = {
    normal: "border-linea bg-superficie shadow-[0_1px_2px_rgba(15,31,51,0.04),0_8px_24px_-20px_rgba(15,31,51,0.35)]",
    plana: "border-linea bg-papel",
    oscura: "border-transparent bg-tinta text-white",
  };

  return (
    <section
      className={`rounded-xl border p-5 sm:p-6 ${fondos[tono]} ${animada ? "em-aparecer" : ""} ${className}`}
      style={animada ? { animationDelay: `${retraso}ms` } : undefined}
    >
      {children}
    </section>
  );
}

export function TituloSeccion({
  titulo,
  bajada,
  icono,
  accion,
}: {
  titulo: string;
  bajada?: string;
  icono?: NombreIcono;
  accion?: ReactNode;
}) {
  return (
    <header className="mb-5 flex flex-wrap items-start justify-between gap-x-4 gap-y-3 border-b border-linea pb-4">
      <div className="flex min-w-0 items-start gap-3">
        {icono ? (
          <span className="mt-0.5 grid h-8 w-8 shrink-0 place-items-center rounded-md bg-acento-tenue text-acento">
            <Icono nombre={icono} tamaño={18} />
          </span>
        ) : null}
        <div className="min-w-0">
          <h2 className="text-lg text-tinta sm:text-xl">{titulo}</h2>
          {bajada ? <p className="mt-1 max-w-prose text-sm leading-relaxed text-media">{bajada}</p> : null}
        </div>
      </div>
      {accion ? <div className="shrink-0">{accion}</div> : null}
    </header>
  );
}

type VarianteBoton = "primario" | "secundario" | "fantasma" | "peligro" | "exito";

const ESTILOS_BOTON: Record<VarianteBoton, string> = {
  primario: "bg-acento text-white hover:bg-acento-fuerte",
  secundario: "border border-linea-fuerte bg-superficie text-tinta hover:border-acento hover:text-acento",
  fantasma: "text-media hover:bg-papel hover:text-tinta",
  peligro: "border border-alerta-linea bg-superficie text-alerta hover:bg-alerta-tenue",
  exito: "bg-logro text-white hover:brightness-95",
};

export function Boton({
  variante = "primario",
  icono,
  className = "",
  children,
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { variante?: VarianteBoton; icono?: NombreIcono }) {
  return (
    <button
      type="button"
      {...props}
      className={`inline-flex items-center justify-center gap-2 rounded-md px-3.5 py-2 text-sm font-semibold transition-colors duration-150 disabled:cursor-not-allowed disabled:opacity-40 ${ESTILOS_BOTON[variante]} ${className}`}
    >
      {icono ? <Icono nombre={icono} tamaño={16} /> : null}
      {children}
    </button>
  );
}

const CLASES_CAMPO =
  "w-full rounded-md border border-linea-fuerte bg-superficie px-3 py-2 text-sm text-tinta outline-none transition-colors focus:border-acento";

export function Campo({
  etiqueta,
  ayuda,
  className = "",
  ...props
}: InputHTMLAttributes<HTMLInputElement> & { etiqueta: string; ayuda?: string }) {
  return (
    <label className={`block ${className}`}>
      <span className="em-rotulo mb-1.5 block">{etiqueta}</span>
      <input {...props} className={CLASES_CAMPO} />
      {ayuda ? <span className="mt-1 block text-xs text-tenue">{ayuda}</span> : null}
    </label>
  );
}

export function Area({
  etiqueta,
  ayuda,
  className = "",
  ...props
}: TextareaHTMLAttributes<HTMLTextAreaElement> & { etiqueta: string; ayuda?: string }) {
  return (
    <label className={`block ${className}`}>
      <span className="em-rotulo mb-1.5 block">{etiqueta}</span>
      <textarea {...props} className={`${CLASES_CAMPO} min-h-28 leading-relaxed`} />
      {ayuda ? <span className="mt-1 block text-xs text-tenue">{ayuda}</span> : null}
    </label>
  );
}

export function Selector({
  etiqueta,
  className = "",
  children,
  ...props
}: SelectHTMLAttributes<HTMLSelectElement> & { etiqueta: string }) {
  return (
    <label className={`block ${className}`}>
      <span className="em-rotulo mb-1.5 block">{etiqueta}</span>
      <select {...props} className={`${CLASES_CAMPO} cursor-pointer`}>
        {children}
      </select>
    </label>
  );
}

export function Deslizador({
  etiqueta,
  valor,
  unidad = "",
  className = "",
  ayuda,
  ...props
}: InputHTMLAttributes<HTMLInputElement> & { etiqueta: string; valor: number; unidad?: string; ayuda?: string }) {
  return (
    <label className={`block ${className}`}>
      <span className="mb-1.5 flex items-baseline justify-between gap-2">
        <span className="em-rotulo">{etiqueta}</span>
        <span className="em-cifra text-sm font-semibold text-tinta">
          {valor}
          {unidad ? ` ${unidad}` : ""}
        </span>
      </span>
      <input {...props} type="range" value={valor} className="w-full accent-[#0e5a8a]" />
      {ayuda ? <span className="mt-1 block text-xs text-tenue">{ayuda}</span> : null}
    </label>
  );
}

export type Tono = "neutro" | "acento" | "logro" | "atencion" | "alerta";

const TONOS_BARRA: Record<Tono, string> = {
  neutro: "bg-linea-fuerte",
  acento: "bg-acento",
  logro: "bg-logro",
  atencion: "bg-atencion",
  alerta: "bg-alerta",
};

export function Barra({ valor, tono = "acento", alto = "h-1.5" }: { valor: number; tono?: Tono; alto?: string }) {
  return (
    <div className={`em-barra w-full overflow-hidden rounded-full bg-linea ${alto}`}>
      <span
        className={`block h-full rounded-full ${TONOS_BARRA[tono]}`}
        style={{ width: `${Math.max(0, Math.min(100, valor))}%` }}
      />
    </div>
  );
}

const TONOS_PILDORA: Record<Tono, string> = {
  neutro: "border-linea bg-papel text-media",
  acento: "border-acento-linea bg-acento-tenue text-acento",
  logro: "border-logro-linea bg-logro-tenue text-logro",
  atencion: "border-atencion-linea bg-atencion-tenue text-atencion",
  alerta: "border-alerta-linea bg-alerta-tenue text-alerta",
};

export function Pildora({
  children,
  tono = "neutro",
  className = "",
}: {
  children: ReactNode;
  tono?: Tono;
  className?: string;
}) {
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full border px-2 py-0.5 text-xs font-semibold ${TONOS_PILDORA[tono]} ${className}`}
    >
      {children}
    </span>
  );
}

export function Vacio({
  icono,
  titulo,
  texto,
  accion,
}: {
  icono: NombreIcono;
  titulo: string;
  texto: string;
  accion?: ReactNode;
}) {
  return (
    <div className="rounded-lg border border-dashed border-linea-fuerte bg-papel px-6 py-9 text-center">
      <span className="mx-auto mb-3 grid h-10 w-10 place-items-center rounded-full border border-linea bg-superficie text-tenue">
        <Icono nombre={icono} tamaño={20} />
      </span>
      <h3 className="text-base text-tinta">{titulo}</h3>
      <p className="mx-auto mt-1.5 max-w-sm text-sm leading-relaxed text-media">{texto}</p>
      {accion ? <div className="mt-4 flex justify-center">{accion}</div> : null}
    </div>
  );
}

/** Cifra con su rótulo. Se apoya en la grilla que la contenga. */
export function Dato({ valor, etiqueta, tono = "neutro" }: { valor: string; etiqueta: string; tono?: Tono }) {
  const colores: Record<Tono, string> = {
    neutro: "text-tinta",
    acento: "text-acento",
    logro: "text-logro",
    atencion: "text-atencion",
    alerta: "text-alerta",
  };

  return (
    <div className="rounded-md border border-linea bg-superficie px-4 py-3">
      <p className={`em-cifra text-2xl font-semibold ${colores[tono]}`}>{valor}</p>
      <p className="em-rotulo mt-0.5">{etiqueta}</p>
    </div>
  );
}

export function AvisoPrincipio({ texto }: { texto: string }) {
  return (
    <p className="mt-5 flex items-start gap-2.5 border-t border-linea pt-4 text-xs leading-relaxed text-media">
      <Icono nombre="manifiesto" tamaño={15} className="mt-0.5 text-acento" />
      <span>{texto}</span>
    </p>
  );
}

/** Nota al pie de un módulo: contexto o advertencia, sin peso de tarjeta. */
export function Nota({ children, tono = "acento" }: { children: ReactNode; tono?: Tono }) {
  const colores: Record<Tono, string> = {
    neutro: "border-linea bg-papel text-media",
    acento: "border-acento-linea bg-acento-tenue text-acento-fuerte",
    logro: "border-logro-linea bg-logro-tenue text-logro",
    atencion: "border-atencion-linea bg-atencion-tenue text-atencion",
    alerta: "border-alerta-linea bg-alerta-tenue text-alerta",
  };

  return <p className={`rounded-md border px-4 py-2.5 text-sm leading-relaxed ${colores[tono]}`}>{children}</p>;
}

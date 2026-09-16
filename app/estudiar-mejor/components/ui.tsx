"use client";

import type { ButtonHTMLAttributes, InputHTMLAttributes, ReactNode, SelectHTMLAttributes, TextareaHTMLAttributes } from "react";

export function Tarjeta({
  children,
  className = "",
  animada = true,
  retraso = 0,
}: {
  children: ReactNode;
  className?: string;
  animada?: boolean;
  retraso?: number;
}) {
  return (
    <section
      className={`rounded-3xl border border-slate-200/80 bg-white p-5 shadow-[0_10px_30px_-18px_rgba(22,18,58,0.45)] sm:p-6 ${animada ? "em-aparecer" : ""} ${className}`}
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
  icono?: string;
  accion?: ReactNode;
}) {
  return (
    <header className="mb-5 flex flex-wrap items-start justify-between gap-3">
      <div className="flex items-start gap-3">
        {icono ? (
          <span aria-hidden className="grid h-11 w-11 shrink-0 place-items-center rounded-2xl bg-indigo-50 text-2xl">
            {icono}
          </span>
        ) : null}
        <div>
          <h2 className="text-xl font-extrabold tracking-tight text-slate-900 sm:text-2xl">{titulo}</h2>
          {bajada ? <p className="mt-1 max-w-2xl text-sm text-slate-500">{bajada}</p> : null}
        </div>
      </div>
      {accion}
    </header>
  );
}

type VarianteBoton = "primario" | "secundario" | "fantasma" | "peligro" | "exito";

const ESTILOS_BOTON: Record<VarianteBoton, string> = {
  primario:
    "bg-indigo-600 text-white hover:bg-indigo-700 focus-visible:outline-indigo-600 shadow-[0_10px_20px_-12px_rgba(79,70,229,0.9)]",
  secundario: "bg-indigo-50 text-indigo-700 hover:bg-indigo-100 focus-visible:outline-indigo-600",
  fantasma: "bg-transparent text-slate-600 hover:bg-slate-100 focus-visible:outline-slate-400",
  peligro: "bg-rose-50 text-rose-700 hover:bg-rose-100 focus-visible:outline-rose-500",
  exito: "bg-emerald-600 text-white hover:bg-emerald-700 focus-visible:outline-emerald-600",
};

export function Boton({
  variante = "primario",
  className = "",
  children,
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { variante?: VarianteBoton }) {
  return (
    <button
      type="button"
      {...props}
      className={`inline-flex items-center justify-center gap-2 rounded-full px-4 py-2 text-sm font-bold transition-all duration-200 focus-visible:outline-2 focus-visible:outline-offset-2 active:scale-[0.97] disabled:cursor-not-allowed disabled:opacity-40 ${ESTILOS_BOTON[variante]} ${className}`}
    >
      {children}
    </button>
  );
}

const CLASES_CAMPO =
  "w-full rounded-2xl border border-slate-200 bg-slate-50/70 px-4 py-2.5 text-sm text-slate-800 outline-none transition focus:border-indigo-400 focus:bg-white focus:ring-4 focus:ring-indigo-100 placeholder:text-slate-400";

export function Campo({
  etiqueta,
  ayuda,
  className = "",
  ...props
}: InputHTMLAttributes<HTMLInputElement> & { etiqueta: string; ayuda?: string }) {
  return (
    <label className={`block ${className}`}>
      <span className="mb-1.5 block text-xs font-bold uppercase tracking-wide text-slate-500">{etiqueta}</span>
      <input {...props} className={CLASES_CAMPO} />
      {ayuda ? <span className="mt-1 block text-xs text-slate-400">{ayuda}</span> : null}
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
      <span className="mb-1.5 block text-xs font-bold uppercase tracking-wide text-slate-500">{etiqueta}</span>
      <textarea {...props} className={`${CLASES_CAMPO} min-h-32 resize-y leading-relaxed`} />
      {ayuda ? <span className="mt-1 block text-xs text-slate-400">{ayuda}</span> : null}
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
      <span className="mb-1.5 block text-xs font-bold uppercase tracking-wide text-slate-500">{etiqueta}</span>
      <select {...props} className={`${CLASES_CAMPO} cursor-pointer`}>
        {children}
      </select>
    </label>
  );
}

export function Barra({
  valor,
  tono = "indigo",
  alto = "h-2.5",
}: {
  valor: number;
  tono?: "indigo" | "emerald" | "amber" | "rose" | "slate";
  alto?: string;
}) {
  const tonos: Record<string, string> = {
    indigo: "bg-gradient-to-r from-indigo-500 to-violet-500",
    emerald: "bg-gradient-to-r from-emerald-500 to-teal-500",
    amber: "bg-gradient-to-r from-amber-400 to-orange-400",
    rose: "bg-gradient-to-r from-rose-500 to-pink-500",
    slate: "bg-slate-300",
  };

  return (
    <div className={`em-barra w-full overflow-hidden rounded-full bg-slate-100 ${alto}`}>
      <span
        className={`block h-full rounded-full ${tonos[tono]}`}
        style={{ width: `${Math.max(0, Math.min(100, valor))}%` }}
      />
    </div>
  );
}

export function Pildora({
  children,
  tono = "slate",
  className = "",
}: {
  children: ReactNode;
  tono?: "slate" | "indigo" | "emerald" | "amber" | "rose" | "violet";
  className?: string;
}) {
  const tonos: Record<string, string> = {
    slate: "bg-slate-100 text-slate-600",
    indigo: "bg-indigo-50 text-indigo-700",
    emerald: "bg-emerald-50 text-emerald-700",
    amber: "bg-amber-50 text-amber-700",
    rose: "bg-rose-50 text-rose-700",
    violet: "bg-violet-50 text-violet-700",
  };

  return (
    <span className={`inline-flex items-center gap-1 rounded-full px-2.5 py-1 text-xs font-bold ${tonos[tono]} ${className}`}>
      {children}
    </span>
  );
}

export function Vacio({ icono, titulo, texto, accion }: { icono: string; titulo: string; texto: string; accion?: ReactNode }) {
  return (
    <div className="em-pop rounded-3xl border border-dashed border-slate-200 bg-slate-50/60 px-6 py-10 text-center">
      <span aria-hidden className="em-flotar mb-3 block text-4xl">
        {icono}
      </span>
      <h3 className="text-base font-extrabold text-slate-800">{titulo}</h3>
      <p className="mx-auto mt-1.5 max-w-md text-sm text-slate-500">{texto}</p>
      {accion ? <div className="mt-4 flex justify-center">{accion}</div> : null}
    </div>
  );
}

export function Dato({ valor, etiqueta, icono }: { valor: string; etiqueta: string; icono?: string }) {
  return (
    <div className="rounded-2xl border border-slate-200/70 bg-white px-4 py-3">
      <div className="flex items-center gap-1.5 text-2xl font-black tracking-tight text-slate-900">
        {icono ? <span aria-hidden className="text-lg">{icono}</span> : null}
        {valor}
      </div>
      <p className="mt-0.5 text-xs font-semibold uppercase tracking-wide text-slate-400">{etiqueta}</p>
    </div>
  );
}

export function AvisoPrincipio({ texto }: { texto: string }) {
  return (
    <p className="mt-4 flex items-start gap-2 rounded-2xl bg-violet-50 px-4 py-3 text-xs font-semibold leading-relaxed text-violet-800">
      <span aria-hidden>🛡️</span>
      <span>{texto}</span>
    </p>
  );
}

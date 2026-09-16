"use client";

import { useState } from "react";
import { Agenda } from "../modulos/Agenda";
import { Errores } from "../modulos/Errores";
import { Explicame } from "../modulos/Explicame";
import { Grupos } from "../modulos/Grupos";
import { Inicio } from "../modulos/Inicio";
import { Manifiesto } from "../modulos/Manifiesto";
import { MapaDominio } from "../modulos/MapaDominio";
import { PanelAdultos } from "../modulos/PanelAdultos";
import { Planificador } from "../modulos/Planificador";
import { Pomodoro } from "../modulos/Pomodoro";
import { Simulador } from "../modulos/Simulador";
import { Tutor } from "../modulos/Tutor";
import { ProveedorEstudiar, useEstudiar } from "../lib/store";
import { calcularConstancia } from "../lib/metricas";
import { armarCola } from "../lib/tutor";
import { DockGuardia } from "./DockGuardia";
import { SECCIONES, type SeccionId } from "./navegacion";
import { Boton } from "./ui";

function Cargando() {
  return (
    <div className="grid min-h-[60vh] place-items-center">
      <div className="text-center">
        <span aria-hidden className="em-flotar block text-5xl">
          📚
        </span>
        <p className="mt-3 text-sm font-bold text-slate-500">Abriendo tu escritorio…</p>
      </div>
    </div>
  );
}

function Contenido() {
  const { estado, hidratado, acciones } = useEstudiar();
  const [seccion, setSeccion] = useState<SeccionId>("inicio");
  const [copiaVisible, setCopiaVisible] = useState(false);
  const [avisoCopia, setAvisoCopia] = useState<string | null>(null);

  if (!hidratado) return <Cargando />;

  const constancia = calcularConstancia(estado.logs);
  const pendientes = armarCola(estado.tarjetas, estado.errores, "todos").pendientes.length;
  const activa = SECCIONES.find((candidata) => candidata.id === seccion) ?? SECCIONES[0];

  // Copiar en vez de descargar: un archivo generado por la página no se puede
  // guardar en todos los contextos donde corre esta app.
  const copiarDatos = async () => {
    try {
      await navigator.clipboard.writeText(JSON.stringify(estado, null, 2));
      setCopiaVisible(false);
      setAvisoCopia("Copiado. Pegalo en un archivo de texto para tener tu respaldo.");
    } catch {
      setCopiaVisible(true);
      setAvisoCopia("Tu navegador no me deja copiar solo: seleccioná el texto de abajo y copialo a mano.");
    }
  };

  const borrar = () => {
    if (typeof window !== "undefined" && !window.confirm("Se borra todo lo que cargaste en este navegador. ¿Seguro?")) return;
    acciones.borrarTodo();
    setSeccion("inicio");
  };

  return (
    <div className="em-app min-h-screen bg-gradient-to-b from-slate-50 via-white to-slate-50 font-sans text-slate-800">
      <header className="sticky top-0 z-30 border-b border-slate-200/80 bg-white/90 backdrop-blur">
        <div className="mx-auto w-full max-w-6xl px-4 py-3 sm:px-6">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <button type="button" onClick={() => setSeccion("inicio")} className="flex items-center gap-2.5 text-left">
              <span aria-hidden className="grid h-10 w-10 place-items-center rounded-2xl bg-gradient-to-br from-indigo-600 to-violet-600 text-xl">
                📚
              </span>
              <span>
                <span className="block text-base font-black leading-tight tracking-tight text-slate-900">Estudiar Mejor</span>
                <span className="hidden text-[11px] font-bold uppercase tracking-wide text-indigo-500 min-[420px]:block">
                  No hace tu tarea. Te hace pensarla.
                </span>
              </span>
            </button>

            <div className="flex items-center gap-2">
              {estado.nombre ? (
                <span className="hidden rounded-full bg-slate-100 px-3 py-1.5 text-xs font-bold text-slate-600 sm:inline">
                  🔥 {constancia.rachaActual} · 🧠 {pendientes} para hoy
                </span>
              ) : null}
              <Boton variante="secundario" onClick={() => setSeccion("manifiesto")}>
                🛡️ Manifiesto
              </Boton>
            </div>
          </div>

          <nav aria-label="Módulos" className="em-scroll-suave -mx-1 mt-3 flex gap-1.5 overflow-x-auto pb-1">
            {SECCIONES.map((candidata) => {
              const activo = candidata.id === seccion;
              return (
                <button
                  key={candidata.id}
                  type="button"
                  onClick={() => setSeccion(candidata.id)}
                  aria-current={activo ? "page" : undefined}
                  className={`shrink-0 whitespace-nowrap rounded-full px-3.5 py-2 text-sm font-bold transition-all duration-200 active:scale-95 ${
                    activo
                      ? "bg-slate-900 text-white shadow-[0_8px_18px_-10px_rgba(15,23,42,0.9)]"
                      : "bg-slate-100 text-slate-500 hover:bg-slate-200 hover:text-slate-700"
                  }`}
                >
                  <span aria-hidden className="mr-1">
                    {candidata.icono}
                  </span>
                  {candidata.nombre}
                </button>
              );
            })}
          </nav>
        </div>
      </header>

      <main className="mx-auto w-full max-w-6xl px-4 py-6 pb-28 sm:px-6">
        <p className="mb-4 text-sm font-semibold text-slate-400">{activa.descripcion}</p>

        <div key={seccion} className="em-aparecer">
          {seccion === "inicio" ? <Inicio irA={setSeccion} /> : null}
          {seccion === "manifiesto" ? <Manifiesto /> : null}
          {seccion === "planificador" ? <Planificador /> : null}
          {seccion === "tutor" ? <Tutor /> : null}
          {seccion === "explicame" ? <Explicame /> : null}
          {seccion === "mapa" ? <MapaDominio /> : null}
          {seccion === "errores" ? <Errores /> : null}
          {seccion === "grupos" ? <Grupos /> : null}
          {seccion === "agenda" ? <Agenda /> : null}
          {seccion === "pomodoro" ? <Pomodoro /> : null}
          {seccion === "simulador" ? <Simulador /> : null}
          {seccion === "adultos" ? <PanelAdultos /> : null}
        </div>

        <footer className="mt-10 rounded-3xl border border-slate-200 bg-white p-5 text-sm text-slate-500">
          <p className="font-bold text-slate-700">Tus datos viven en este navegador</p>
          <p className="mt-1">
            No hay servidores, ni cuentas, ni sincronización: todo se guarda en el almacenamiento local de este dispositivo. Si
            borrás los datos del navegador, se borra tu progreso.
          </p>
          <div className="mt-3 flex flex-wrap gap-2">
            <Boton variante="secundario" onClick={() => void copiarDatos()}>
              📋 Copiar mis datos
            </Boton>
            {estado.temas.length === 0 ? (
              <Boton variante="secundario" onClick={acciones.cargarEjemplo}>
                🧪 Cargar datos de ejemplo
              </Boton>
            ) : null}
            <Boton variante="peligro" onClick={borrar}>
              Borrar todo
            </Boton>
          </div>

          {avisoCopia ? <p className="mt-3 font-semibold text-indigo-700">{avisoCopia}</p> : null}
          {copiaVisible ? (
            <textarea
              id="respaldo-datos"
              readOnly
              value={JSON.stringify(estado, null, 2)}
              onFocus={(evento) => evento.currentTarget.select()}
              className="mt-2 h-40 w-full rounded-2xl border border-slate-200 bg-slate-50 p-3 font-mono text-xs"
            />
          ) : null}
        </footer>
      </main>

      <DockGuardia />
    </div>
  );
}

export function EstudiarMejorApp() {
  return (
    <ProveedorEstudiar>
      <Contenido />
    </ProveedorEstudiar>
  );
}

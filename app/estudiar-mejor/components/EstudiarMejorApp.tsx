"use client";

import { useEffect, useState } from "react";
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
import { Icono } from "./iconos";
import { PanelGuardia } from "./PanelGuardia";
import { GRUPOS, buscarSeccion, type SeccionId } from "./navegacion";
import { Boton } from "./ui";

function Marca({ compacta = false }: { compacta?: boolean }) {
  return (
    <span className="flex items-center gap-2.5">
      <span className="grid h-8 w-8 shrink-0 place-items-center rounded-md bg-tinta text-white">
        <Icono nombre="manifiesto" tamaño={17} />
      </span>
      <span className="min-w-0">
        <span className="block font-serif text-[15px] font-semibold leading-tight text-tinta">Estudiar Mejor</span>
        {!compacta ? (
          <span className="block text-[11px] leading-tight text-tenue">No hace tu tarea. Te hace pensarla.</span>
        ) : null}
      </span>
    </span>
  );
}

function ListaNavegacion({
  seccion,
  onElegir,
}: {
  seccion: SeccionId;
  onElegir: (id: SeccionId) => void;
}) {
  return (
    <nav aria-label="Módulos" className="space-y-6">
      {GRUPOS.map((grupo) => (
        <div key={grupo.titulo}>
          <p className="em-rotulo mb-2 px-3">{grupo.titulo}</p>
          <ul className="space-y-0.5">
            {grupo.secciones.map((candidata) => {
              const activo = candidata.id === seccion;
              return (
                <li key={candidata.id}>
                  <button
                    type="button"
                    onClick={() => onElegir(candidata.id)}
                    aria-current={activo ? "page" : undefined}
                    className={`flex w-full items-center gap-2.5 rounded-md px-3 py-2 text-sm font-medium transition-colors ${
                      activo ? "bg-acento-tenue text-acento-fuerte" : "text-media hover:bg-papel hover:text-tinta"
                    }`}
                  >
                    <Icono nombre={candidata.icono} tamaño={18} className={activo ? "text-acento" : "text-tenue"} />
                    <span className="truncate">{candidata.nombre}</span>
                  </button>
                </li>
              );
            })}
          </ul>
        </div>
      ))}
    </nav>
  );
}

function Cargando() {
  return (
    <div className="em-app grid min-h-screen place-items-center bg-papel font-sans">
      <p className="em-rotulo em-latido">Abriendo tu escritorio…</p>
    </div>
  );
}

function Contenido() {
  const { estado, hidratado, acciones } = useEstudiar();
  const [seccion, setSeccion] = useState<SeccionId>("inicio");
  const [menuAbierto, setMenuAbierto] = useState(false);
  const [ayudaAbierta, setAyudaAbierta] = useState(false);
  const [copiaVisible, setCopiaVisible] = useState(false);
  const [avisoCopia, setAvisoCopia] = useState<string | null>(null);

  useEffect(() => {
    if (typeof document === "undefined") return;
    const bloqueado = menuAbierto || ayudaAbierta;
    document.body.style.overflow = bloqueado ? "hidden" : "";
    return () => {
      document.body.style.overflow = "";
    };
  }, [menuAbierto, ayudaAbierta]);

  if (!hidratado) return <Cargando />;

  const constancia = calcularConstancia(estado.logs);
  const pendientes = armarCola(estado.tarjetas, estado.errores, "todos").pendientes.length;
  const activa = buscarSeccion(seccion);

  const ir = (id: SeccionId) => {
    setSeccion(id);
    setMenuAbierto(false);
    if (typeof window !== "undefined") window.scrollTo({ top: 0, behavior: "instant" });
  };

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
    <div className="em-app min-h-screen bg-papel font-sans text-tinta">
      <div className="mx-auto flex w-full max-w-[1400px]">
        {/* Barra lateral: sólo en pantallas anchas. */}
        <aside className="sticky top-0 hidden h-screen w-64 shrink-0 flex-col border-r border-linea bg-superficie lg:flex">
          <div className="border-b border-linea px-4 py-4">
            <button type="button" onClick={() => ir("inicio")} className="text-left">
              <Marca />
            </button>
          </div>

          <div className="em-scroll-suave flex-1 overflow-y-auto px-3 py-5">
            <ListaNavegacion seccion={seccion} onElegir={ir} />
          </div>

          <div className="border-t border-linea p-3">
            {estado.nombre ? (
              <div className="mb-3 flex items-center gap-2.5 rounded-md bg-papel px-3 py-2.5">
                <span className="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-tinta font-semibold text-white">
                  {estado.nombre.slice(0, 1).toUpperCase()}
                </span>
                <span className="min-w-0">
                  <span className="block truncate text-sm font-semibold text-tinta">{estado.nombre}</span>
                  <span className="flex items-center gap-1 text-xs text-media">
                    <Icono nombre="racha" tamaño={13} className="text-atencion" />
                    <span className="em-cifra">{constancia.rachaActual}</span> días · {pendientes} preguntas
                  </span>
                </span>
              </div>
            ) : null}
            <Boton variante="secundario" icono="ayuda" className="w-full" onClick={() => setAyudaAbierta(true)}>
              Pedime ayuda
            </Boton>
          </div>
        </aside>

        <div className="flex min-w-0 flex-1 flex-col">
          {/* Barra superior: navegación del celular. */}
          <header className="sticky top-0 z-30 border-b border-linea bg-superficie/95 backdrop-blur lg:hidden">
            <div className="flex items-center justify-between gap-3 px-4 py-3">
              <button type="button" onClick={() => ir("inicio")} className="min-w-0 text-left">
                <Marca compacta />
              </button>
              <div className="flex shrink-0 items-center gap-1">
                <button
                  type="button"
                  onClick={() => setAyudaAbierta(true)}
                  aria-label="Pedime ayuda"
                  className="rounded-md p-2 text-media transition-colors hover:bg-papel hover:text-tinta"
                >
                  <Icono nombre="ayuda" />
                </button>
                <button
                  type="button"
                  onClick={() => setMenuAbierto(true)}
                  aria-label="Abrir el menú"
                  aria-expanded={menuAbierto}
                  className="rounded-md p-2 text-media transition-colors hover:bg-papel hover:text-tinta"
                >
                  <Icono nombre="menu" />
                </button>
              </div>
            </div>
          </header>

          <main className="min-w-0 flex-1 px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
            <div className="mx-auto w-full max-w-5xl">
              <div className="mb-6 flex flex-wrap items-end justify-between gap-3 border-b border-linea pb-4">
                <div>
                  <p className="em-rotulo">{activa.descripcion}</p>
                  <h1 className="mt-1 text-2xl text-tinta sm:text-3xl">{activa.nombre}</h1>
                </div>
                {estado.nombre ? (
                  <p className="flex items-center gap-1.5 text-sm text-media lg:hidden">
                    <Icono nombre="racha" tamaño={15} className="text-atencion" />
                    <span className="em-cifra font-semibold text-tinta">{constancia.rachaActual}</span> días seguidos
                  </p>
                ) : null}
              </div>

              <div key={seccion} className="em-aparecer">
                {seccion === "inicio" ? <Inicio irA={ir} /> : null}
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

              <footer className="mt-10 border-t border-linea pt-5 text-sm text-media">
                <p className="font-semibold text-tinta">Tus datos viven en este navegador</p>
                <p className="mt-1 max-w-prose leading-relaxed">
                  No hay servidores, ni cuentas, ni sincronización: todo se guarda en el almacenamiento local de este
                  dispositivo. Si borrás los datos del navegador, se borra tu progreso.
                </p>
                <div className="mt-3 flex flex-wrap gap-2">
                  <Boton variante="secundario" icono="copiar" onClick={() => void copiarDatos()}>
                    Copiar mis datos
                  </Boton>
                  {estado.temas.length === 0 ? (
                    <Boton variante="secundario" icono="archivo" onClick={acciones.cargarEjemplo}>
                      Cargar datos de ejemplo
                    </Boton>
                  ) : null}
                  <Boton variante="peligro" icono="papelera" onClick={borrar}>
                    Borrar todo
                  </Boton>
                </div>

                {avisoCopia ? <p className="mt-3 font-medium text-acento">{avisoCopia}</p> : null}
                {copiaVisible ? (
                  <textarea
                    id="respaldo-datos"
                    readOnly
                    value={JSON.stringify(estado, null, 2)}
                    onFocus={(evento) => evento.currentTarget.select()}
                    className="mt-2 h-40 w-full rounded-md border border-linea bg-superficie p-3 font-mono text-xs"
                  />
                ) : null}
              </footer>
            </div>
          </main>
        </div>
      </div>

      {/* Menú del celular, a pantalla completa. */}
      {menuAbierto ? (
        <div className="fixed inset-0 z-50 flex flex-col bg-superficie lg:hidden">
          <div className="flex items-center justify-between border-b border-linea px-4 py-3">
            <Marca compacta />
            <button
              type="button"
              onClick={() => setMenuAbierto(false)}
              aria-label="Cerrar el menú"
              className="rounded-md p-2 text-media transition-colors hover:bg-papel hover:text-tinta"
            >
              <Icono nombre="cerrar" />
            </button>
          </div>
          <div className="em-scroll-suave flex-1 overflow-y-auto px-3 py-5">
            <ListaNavegacion seccion={seccion} onElegir={ir} />
          </div>
        </div>
      ) : null}

      <PanelGuardia abierto={ayudaAbierta} onCerrar={() => setAyudaAbierta(false)} />
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

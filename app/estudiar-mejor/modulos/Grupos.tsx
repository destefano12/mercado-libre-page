"use client";

import { useState } from "react";
import { AvisoPrincipio, Barra, Boton, Campo, Pildora, Tarjeta, TituloSeccion, Vacio } from "../components/ui";
import { Icono } from "../components/iconos";
import { cuandoEs, fechaLarga, hoyClave, sumarDias } from "../lib/fechas";
import { useEstudiar } from "../lib/store";
import type { Integrante } from "../lib/tipos";

const ROLES_SUGERIDOS = [
  "Coordinación",
  "Investigación",
  "Armado",
  "Revisión",
  "Presentación",
  "Diseño",
];

function avanceDe(integrante: Integrante): number {
  if (integrante.tareas.length === 0) return 0;
  return Math.round((integrante.tareas.filter((tarea) => tarea.hecho).length / integrante.tareas.length) * 100);
}

export function Grupos() {
  const { estado, acciones } = useEstudiar();
  const [nombre, setNombre] = useState("");
  const [materia, setMateria] = useState("");
  const [entrega, setEntrega] = useState(sumarDias(hoyClave(), 14));
  const [integrantes, setIntegrantes] = useState("");
  const [nuevaTarea, setNuevaTarea] = useState<Record<string, string>>({});
  const [nuevoIntegrante, setNuevoIntegrante] = useState<Record<string, string>>({});

  const crear = () => {
    const lista = integrantes
      .split(/[,\n]/)
      .map((parte) => parte.trim())
      .filter(Boolean);
    if (!nombre.trim() || lista.length === 0) return;

    acciones.crearGrupo(
      nombre.trim(),
      materia.trim() || "General",
      entrega,
      lista.map((integrante, indice) => ({ nombre: integrante, rol: ROLES_SUGERIDOS[indice % ROLES_SUGERIDOS.length] })),
    );
    setNombre("");
    setMateria("");
    setIntegrantes("");
  };

  return (
    <div className="space-y-6">
      <Tarjeta>
        <TituloSeccion
          icono="grupos"
          titulo="Trabajos grupales"
          bajada="Repartí responsabilidades y mirá el avance de cada integrante. Todo se guarda en tu navegador: es tu tablero, no un grupo en la nube."
        />

        <div className="grid gap-4 sm:grid-cols-2">
          <Campo etiqueta="Nombre del trabajo" placeholder="Ej: Maqueta del ecosistema" value={nombre} onChange={(evento) => setNombre(evento.target.value)} />
          <Campo etiqueta="Materia" placeholder="Ej: Biología" value={materia} onChange={(evento) => setMateria(evento.target.value)} />
          <Campo etiqueta="Fecha de entrega" type="date" min={hoyClave()} value={entrega} onChange={(evento) => setEntrega(evento.target.value)} ayuda={`Es ${cuandoEs(entrega)}`} />
          <Campo
            etiqueta="Integrantes (separados por coma)"
            placeholder="Vos, Tomás, Juana"
            value={integrantes}
            onChange={(evento) => setIntegrantes(evento.target.value)}
            ayuda="El primero de la lista sos vos. Los roles se asignan solos y los podés cambiar después."
          />
        </div>

        <Boton className="mt-4" onClick={crear} disabled={!nombre.trim() || !integrantes.trim()}>
          Crear trabajo grupal
        </Boton>

        <AvisoPrincipio texto="Reparto las tareas, no las hago. Cada parte del trabajo la escribe la persona que la tiene asignada." />
      </Tarjeta>

      {estado.grupos.length === 0 ? (
        <Vacio icono="grupos" titulo="Todavía no hay trabajos grupales" texto="Cargá uno y vas a ver quién va cómo, sin tener que preguntar por el grupo de chat." />
      ) : (
        estado.grupos.map((grupo, indice) => {
          const totalTareas = grupo.integrantes.reduce((total, integrante) => total + integrante.tareas.length, 0);
          const hechas = grupo.integrantes.reduce(
            (total, integrante) => total + integrante.tareas.filter((tarea) => tarea.hecho).length,
            0,
          );
          const avanceGlobal = totalTareas === 0 ? 0 : Math.round((hechas / totalTareas) * 100);

          return (
            <Tarjeta key={grupo.id} retraso={indice * 70}>
              <div className="mb-4 flex flex-wrap items-start justify-between gap-3">
                <div>
                  <h3 className="text-lg font-semibold text-tinta">{grupo.nombre}</h3>
                  <p className="text-sm text-media">
                    {grupo.materia} · entrega {fechaLarga(grupo.entrega)} ({cuandoEs(grupo.entrega)})
                  </p>
                </div>
                <Boton variante="peligro" onClick={() => acciones.eliminarGrupo(grupo.id)}>
                  Borrar
                </Boton>
              </div>

              <div className="mb-5">
                <div className="mb-1.5 flex items-center justify-between text-sm font-bold text-media">
                  <span>Avance del grupo</span>
                  <span>{avanceGlobal}%</span>
                </div>
                <Barra valor={avanceGlobal} tono={avanceGlobal >= 70 ? "logro" : avanceGlobal >= 35 ? "acento" : "atencion"} alto="h-3" />
              </div>

              <div className="grid gap-3 lg:grid-cols-2">
                {grupo.integrantes.map((integrante) => {
                  const avance = avanceDe(integrante);
                  return (
                    <article key={integrante.id} className="rounded-md border border-linea bg-superficie p-4">
                      <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
                        <div className="flex items-center gap-2">
                          <span className="grid h-9 w-9 place-items-center rounded-full bg-acento-tenue text-sm font-semibold text-acento-fuerte">
                            {integrante.nombre.slice(0, 2).toUpperCase()}
                          </span>
                          <div>
                            <p className="text-sm font-semibold text-tinta">
                              {integrante.nombre} {integrante.esYo ? <Pildora tono="acento">vos</Pildora> : null}
                            </p>
                            <p className="em-rotulo">{integrante.rol}</p>
                          </div>
                        </div>
                        <Boton
                          variante="fantasma"
                          aria-label={`Quitar a ${integrante.nombre}`}
                          onClick={() => acciones.eliminarIntegrante(grupo.id, integrante.id)}
                        >
                          <Icono nombre="cerrar" tamaño={15} />
                        </Boton>
                      </div>

                      <div className="mb-3 flex items-center gap-3">
                        <Barra valor={avance} tono={avance >= 70 ? "logro" : avance >= 35 ? "acento" : "alerta"} />
                        <span className="w-12 shrink-0 text-right text-sm font-semibold text-tinta">{avance}%</span>
                      </div>

                      <ul className="space-y-1.5">
                        {integrante.tareas.map((tarea) => (
                          <li key={tarea.id} className="flex items-center gap-2">
                            <label className="flex flex-1 cursor-pointer items-center gap-2">
                              <input
                                type="checkbox"
                                checked={tarea.hecho}
                                onChange={() => acciones.alternarTarea(grupo.id, integrante.id, tarea.id)}
                                className="h-4 w-4 accent-[#1c7a54]"
                              />
                              <span className={`text-sm ${tarea.hecho ? "text-tenue line-through" : "text-tinta"}`}>
                                {tarea.titulo}
                              </span>
                            </label>
                            <button
                              type="button"
                              onClick={() => acciones.eliminarTarea(grupo.id, integrante.id, tarea.id)}
                              className="text-tenue transition-colors hover:text-alerta"
                              aria-label={`Borrar tarea ${tarea.titulo}`}
                            >
                              <Icono nombre="cerrar" tamaño={14} />
                            </button>
                          </li>
                        ))}
                        {integrante.tareas.length === 0 ? (
                          <li className="text-xs italic text-tenue">Sin responsabilidades asignadas todavía.</li>
                        ) : null}
                      </ul>

                      <div className="mt-3 flex gap-2">
                        <input
                          value={nuevaTarea[integrante.id] ?? ""}
                          onChange={(evento) => setNuevaTarea((previo) => ({ ...previo, [integrante.id]: evento.target.value }))}
                          onKeyDown={(evento) => {
                            if (evento.key !== "Enter") return;
                            const valor = (nuevaTarea[integrante.id] ?? "").trim();
                            if (!valor) return;
                            acciones.agregarTarea(grupo.id, integrante.id, valor);
                            setNuevaTarea((previo) => ({ ...previo, [integrante.id]: "" }));
                          }}
                          placeholder="Sumar responsabilidad…"
                          className="flex-1 rounded-full border border-linea bg-papel px-3 py-1.5 text-sm outline-none transition focus:border-acento focus:bg-superficie"
                        />
                        <Boton
                          variante="secundario"
                          onClick={() => {
                            const valor = (nuevaTarea[integrante.id] ?? "").trim();
                            if (!valor) return;
                            acciones.agregarTarea(grupo.id, integrante.id, valor);
                            setNuevaTarea((previo) => ({ ...previo, [integrante.id]: "" }));
                          }}
                        >
                          +
                        </Boton>
                      </div>
                    </article>
                  );
                })}
              </div>

              <div className="mt-4 flex gap-2">
                <input
                  value={nuevoIntegrante[grupo.id] ?? ""}
                  onChange={(evento) => setNuevoIntegrante((previo) => ({ ...previo, [grupo.id]: evento.target.value }))}
                  placeholder="Sumar integrante…"
                  className="flex-1 rounded-full border border-linea bg-papel px-4 py-2 text-sm outline-none transition focus:border-acento focus:bg-superficie"
                />
                <Boton
                  variante="secundario"
                  onClick={() => {
                    const valor = (nuevoIntegrante[grupo.id] ?? "").trim();
                    if (!valor) return;
                    acciones.agregarIntegrante(grupo.id, valor, ROLES_SUGERIDOS[grupo.integrantes.length % ROLES_SUGERIDOS.length]);
                    setNuevoIntegrante((previo) => ({ ...previo, [grupo.id]: "" }));
                  }}
                >
                  Agregar
                </Boton>
              </div>

              {avanceGlobal < 40 && grupo.entrega <= sumarDias(hoyClave(), 5) ? (
                <p className="mt-4 rounded-md bg-alerta-tenue px-4 py-3 text-sm font-semibold text-alerta">
                  Falta poco para la entrega y el avance está bajo. ¿Qué parte se puede dividir en dos para que no dependa de una sola persona?
                </p>
              ) : null}
            </Tarjeta>
          );
        })
      )}
    </div>
  );
}

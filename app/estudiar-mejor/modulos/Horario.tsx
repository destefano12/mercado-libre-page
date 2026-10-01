"use client";

import { useState } from "react";
import { Boton, Nota, Pildora, Tarjeta, TituloSeccion } from "../components/ui";
import { Icono } from "../components/iconos";
import { armarDia, cosasSugeridas, DIAS } from "../lib/horario";
import { useEstudiar } from "../lib/store";

const DIAS_DE_CLASE = [1, 2, 3, 4, 5];

/** La pregunta de todas las noches, contestada sola. */
export function QueLlevoManana({ compacto = false }: { compacto?: boolean }) {
  const { estado } = useEstudiar();
  const manana = armarDia(1, estado.horario, estado.agenda);

  if (estado.horario.length === 0) return null;

  if (manana.clases.length === 0) {
    return (
      <Tarjeta>
        <p className="em-rotulo">Mañana · {manana.nombre}</p>
        <p className="mt-1.5 text-base font-semibold text-tinta">No tenés clase.</p>
        {manana.eventos.length > 0 ? (
          <p className="mt-1 text-sm text-media">Pero sí tenés: {manana.eventos.map((evento) => evento.titulo).join(", ")}.</p>
        ) : null}
      </Tarjeta>
    );
  }

  return (
    <Tarjeta>
      <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
        <p className="em-rotulo">Mañana · {manana.nombre}</p>
        {manana.eventos.length > 0 ? <Pildora tono="alerta">{manana.eventos.length} para entregar</Pildora> : null}
      </div>

      <p className="text-base leading-relaxed text-tinta">
        Tenés <span className="font-semibold">{manana.clases.map((clase) => clase.materia).join(", ")}</span>.
      </p>

      <div className="mt-4">
        <p className="em-rotulo mb-2">Llevá</p>
        <ul className="flex flex-wrap gap-2">
          {manana.lleva.map((cosa) => (
            <li key={cosa} className="rounded-full border border-linea bg-papel px-3.5 py-1.5 text-sm text-tinta">
              {cosa}
            </li>
          ))}
        </ul>
      </div>

      {manana.eventos.length > 0 ? (
        <div className="mt-4 rounded-md bg-alerta-tenue px-4 py-3">
          <p className="em-rotulo mb-1 text-alerta">Para mañana</p>
          <ul className="space-y-1">
            {manana.eventos.map((evento) => (
              <li key={evento.id} className="text-sm font-semibold text-alerta">
                {evento.titulo}
              </li>
            ))}
          </ul>
        </div>
      ) : null}

      {!compacto ? (
        <p className="mt-4 text-xs leading-relaxed text-tenue">
          Esto sale de tu horario. Si falta algo, agregalo en el horario y queda para siempre.
        </p>
      ) : null}
    </Tarjeta>
  );
}

export function Horario() {
  const { estado, acciones } = useEstudiar();
  const [materia, setMateria] = useState<Record<number, string>>({});
  const hoy = new Date().getDay();

  const agregar = (dia: number) => {
    const nombre = (materia[dia] ?? "").trim();
    if (!nombre) return;
    acciones.agregarClase(dia, nombre, cosasSugeridas(nombre));
    setMateria((previo) => ({ ...previo, [dia]: "" }));
  };

  return (
    <div className="space-y-6">
      <QueLlevoManana />

      <Tarjeta>
        <TituloSeccion
          icono="agenda"
          titulo="Mi horario"
          bajada="Cargalo una vez y después contesta solo: qué tenés mañana, qué llevar y qué hay que entregar. Al escribir la materia te sugiero lo que se lleva, y lo podés cambiar."
        />

        <div className="grid gap-4 lg:grid-cols-2">
          {DIAS_DE_CLASE.map((dia) => {
            const clases = estado.horario.filter((clase) => clase.dia === dia).sort((a, b) => a.orden - b.orden);
            const esHoy = dia === hoy;

            return (
              <section
                key={dia}
                className={`rounded-md border p-4 ${esHoy ? "border-acento bg-acento-tenue" : "border-linea bg-superficie"}`}
              >
                <div className="mb-3 flex items-center justify-between">
                  <h3 className="font-semibold capitalize text-tinta">{DIAS[dia]}</h3>
                  {esHoy ? <Pildora tono="acento">hoy</Pildora> : null}
                </div>

                <ul className="mb-3 space-y-2">
                  {clases.map((clase) => (
                    <li key={clase.id} className="rounded-md border border-linea bg-superficie p-3">
                      <div className="mb-1.5 flex items-start justify-between gap-2">
                        <span className="font-semibold text-tinta">{clase.materia}</span>
                        <button
                          type="button"
                          onClick={() => acciones.eliminarClase(clase.id)}
                          aria-label={`Sacar ${clase.materia} del ${DIAS[dia]}`}
                          className="text-tenue transition-colors hover:text-alerta"
                        >
                          <Icono nombre="cerrar" tamaño={14} />
                        </button>
                      </div>
                      <input
                        value={clase.lleva.join(", ")}
                        onChange={(evento) =>
                          acciones.cambiarCosas(
                            clase.id,
                            evento.target.value.split(",").map((cosa) => cosa.trim()).filter(Boolean),
                          )
                        }
                        aria-label={`Qué llevar a ${clase.materia}`}
                        placeholder="Qué llevar, separado por comas"
                        className="w-full rounded-md border border-linea bg-papel px-3 py-1.5 text-sm text-media outline-none transition-colors focus:border-acento focus:bg-superficie"
                      />
                    </li>
                  ))}
                  {clases.length === 0 ? (
                    <li className="text-sm italic text-tenue">Sin materias cargadas.</li>
                  ) : null}
                </ul>

                <div className="flex gap-2">
                  <input
                    value={materia[dia] ?? ""}
                    onChange={(evento) => setMateria((previo) => ({ ...previo, [dia]: evento.target.value }))}
                    onKeyDown={(evento) => {
                      if (evento.key === "Enter") agregar(dia);
                    }}
                    aria-label={`Sumar materia al ${DIAS[dia]}`}
                    placeholder="Sumar materia…"
                    className="flex-1 rounded-full border border-linea bg-papel px-3.5 py-1.5 text-sm outline-none transition focus:border-acento focus:bg-superficie"
                  />
                  <Boton variante="secundario" onClick={() => agregar(dia)}>
                    +
                  </Boton>
                </div>
              </section>
            );
          })}
        </div>

        {estado.horario.length === 0 ? (
          <div className="mt-5">
            <Nota tono="acento">
              Cargalo una vez, en cinco minutos, y no lo tocás más en todo el año. Después, cada noche, la app te dice
              sola qué llevar.
            </Nota>
          </div>
        ) : null}
      </Tarjeta>
    </div>
  );
}

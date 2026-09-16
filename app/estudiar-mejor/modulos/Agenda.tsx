"use client";

import { useMemo, useState } from "react";
import { Boton, Campo, Dato, Pildora, Selector, Tarjeta, TituloSeccion, Vacio, type Tono } from "../components/ui";
import { Icono, type NombreIcono } from "../components/iconos";
import { cuandoEs, diaCorto, diferenciaEnDias, fechaCorta, fechaLarga, hoyClave, sumarDias } from "../lib/fechas";
import { useEstudiar } from "../lib/store";
import type { EventoAgenda } from "../lib/tipos";

const TIPOS: { valor: EventoAgenda["tipo"]; nombre: string; icono: NombreIcono; tono: Tono }[] = [
  { valor: "entrega", nombre: "Entrega", icono: "agenda", tono: "atencion" },
  { valor: "examen", nombre: "Examen", icono: "simulador", tono: "alerta" },
  { valor: "sesion", nombre: "Sesión de estudio", icono: "archivo", tono: "acento" },
];

export function Agenda() {
  const { estado, acciones } = useEstudiar();
  const [tipo, setTipo] = useState<EventoAgenda["tipo"]>("examen");
  const [titulo, setTitulo] = useState("");
  const [fecha, setFecha] = useState(sumarDias(hoyClave(), 3));
  const [temaId, setTemaId] = useState("");

  const eventos = useMemo(() => {
    const desdePlanes = estado.planes.flatMap((plan) =>
      plan.sesiones
        .filter((sesion) => !sesion.hecho && sesion.fecha >= hoyClave())
        .map((sesion) => ({
          id: `${plan.id}-${sesion.id}`,
          tipo: "sesion" as const,
          titulo: sesion.objetivo,
          fecha: sesion.fecha,
          temaId: plan.temaId,
          hecho: false,
          delPlan: true,
        })),
    );

    return [...estado.agenda.map((evento) => ({ ...evento, delPlan: false })), ...desdePlanes].sort((a, b) =>
      a.fecha.localeCompare(b.fecha),
    );
  }, [estado.agenda, estado.planes]);

  const proximos = eventos.filter((evento) => !evento.hecho && evento.fecha >= hoyClave());
  const pasados = eventos.filter((evento) => evento.hecho || evento.fecha < hoyClave());
  const estaSemana = proximos.filter((evento) => diferenciaEnDias(hoyClave(), evento.fecha) <= 7);
  const proximoExamen = proximos.find((evento) => evento.tipo === "examen");

  const agregar = () => {
    if (!titulo.trim()) return;
    acciones.agregarEvento({ tipo, titulo: titulo.trim(), fecha, temaId: temaId || undefined });
    setTitulo("");
  };

  return (
    <div className="space-y-6">
      <Tarjeta>
        <TituloSeccion icono="agenda" titulo="Agenda" bajada="Entregas, exámenes y sesiones en un solo lugar. Las sesiones de tus planes aparecen solas." />

        <div className="mb-5 grid gap-3 sm:grid-cols-3">
          <Dato valor={`${estaSemana.length}`} etiqueta="En los próximos 7 días" />
          <Dato valor={`${proximos.filter((evento) => evento.tipo === "entrega").length}`} etiqueta="Entregas pendientes" />
          <Dato
            valor={proximoExamen ? cuandoEs(proximoExamen.fecha) : "—"}
            etiqueta="Próximo examen"
          />
        </div>

        <div className="grid gap-4 sm:grid-cols-2">
          <Selector etiqueta="Tipo" value={tipo} onChange={(evento) => setTipo(evento.target.value as EventoAgenda["tipo"])}>
            {TIPOS.map((opcion) => (
              <option key={opcion.valor} value={opcion.valor}>
                {opcion.nombre}
              </option>
            ))}
          </Selector>
          <Campo etiqueta="Fecha" type="date" value={fecha} onChange={(evento) => setFecha(evento.target.value)} ayuda={`Es ${cuandoEs(fecha)}`} />
          <Campo
            etiqueta="¿Qué es?"
            placeholder="Ej: Prueba de Historia, unidad 3"
            value={titulo}
            onChange={(evento) => setTitulo(evento.target.value)}
            onKeyDown={(evento) => {
              if (evento.key === "Enter") agregar();
            }}
          />
          <Selector etiqueta="Tema (opcional)" value={temaId} onChange={(evento) => setTemaId(evento.target.value)}>
            <option value="">Sin tema asociado</option>
            {estado.temas.map((tema) => (
              <option key={tema.id} value={tema.id}>
                {tema.nombre}
              </option>
            ))}
          </Selector>
        </div>

        <Boton className="mt-4" onClick={agregar} disabled={!titulo.trim()}>
          Agregar a la agenda
        </Boton>
      </Tarjeta>

      <Tarjeta retraso={70}>
        <TituloSeccion icono="flecha" titulo="Lo que viene" />

        {proximos.length === 0 ? (
          <Vacio icono="agenda" titulo="No tenés nada agendado" texto="Cargá tu próxima prueba o entrega y te aviso cuánto falta." />
        ) : (
          <ol className="space-y-2">
            {proximos.map((evento, indice) => {
              const info = TIPOS.find((opcion) => opcion.valor === evento.tipo);
              const dias = diferenciaEnDias(hoyClave(), evento.fecha);
              const urgente = dias <= 2;

              return (
                <li
                  key={evento.id}
                  className={`em-aparecer flex flex-wrap items-center gap-3 rounded-md border px-4 py-3 ${
                    urgente ? "border-alerta-linea bg-alerta-tenue" : "border-linea bg-superficie"
                  }`}
                  style={{ animationDelay: `${indice * 45}ms` }}
                >
                  <div className="grid h-12 w-12 shrink-0 place-items-center rounded-md bg-tinta text-white">
                    <span className="em-rotulo leading-none">{diaCorto(evento.fecha)}</span>
                    <span className="text-sm font-semibold leading-tight">{fechaCorta(evento.fecha)}</span>
                  </div>

                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-semibold text-tinta">{evento.titulo}</p>
                    <div className="mt-1 flex flex-wrap gap-1.5">
                      <Pildora tono={info?.tono ?? "neutro"}>
                        {info ? <Icono nombre={info.icono} tamaño={12} /> : null}
                        {info?.nombre}
                      </Pildora>
                      <Pildora tono={urgente ? "alerta" : "neutro"}>{cuandoEs(evento.fecha)}</Pildora>
                      {evento.delPlan ? <Pildora tono="acento">de tu plan</Pildora> : null}
                    </div>
                  </div>

                  {!evento.delPlan ? (
                    <div className="flex gap-2">
                      <Boton variante="exito" onClick={() => acciones.alternarEvento(evento.id)}>
                        Hecho
                      </Boton>
                      <Boton variante="fantasma" onClick={() => acciones.eliminarEvento(evento.id)} aria-label="Borrar evento">
                        <Icono nombre="papelera" tamaño={16} />
                      </Boton>
                    </div>
                  ) : null}
                </li>
              );
            })}
          </ol>
        )}

        {pasados.length > 0 ? (
          <details className="mt-5">
            <summary className="cursor-pointer text-sm font-bold text-media hover:text-tinta">
              Ver {pasados.length} evento{pasados.length === 1 ? "" : "s"} pasado{pasados.length === 1 ? "" : "s"}
            </summary>
            <ul className="mt-3 space-y-1.5">
              {pasados.map((evento) => (
                <li key={evento.id} className="flex items-center justify-between gap-3 rounded-xl bg-papel px-3 py-2 text-sm text-media">
                  <span className={evento.hecho ? "line-through" : ""}>
                    {fechaLarga(evento.fecha)} · {evento.titulo}
                  </span>
                  {!evento.delPlan ? (
                    <button
                      type="button"
                      onClick={() => acciones.eliminarEvento(evento.id)}
                      className="text-tenue transition-colors hover:text-alerta"
                      aria-label={`Borrar ${evento.titulo}`}
                    >
                      <Icono nombre="papelera" tamaño={15} />
                    </button>
                  ) : null}
                </li>
              ))}
            </ul>
          </details>
        ) : null}
      </Tarjeta>
    </div>
  );
}

"use client";

import { useState } from "react";
import { FormularioTema } from "../components/FormularioTema";
import { Area, AvisoPrincipio, Barra, Boton, Campo, Dato, Deslizador, Nota, Pildora, Selector, Tarjeta, TituloSeccion, Vacio, type Tono } from "../components/ui";
import { cuandoEs, diaCorto, fechaCorta, fechaLarga, hoyClave, minutosLegibles, sumarDias } from "../lib/fechas";
import {
  ETAPAS,
  MINUTOS_MAXIMOS_POR_DIA,
  diagnosticoPlan,
  minutosTotales,
  progresoPlan,
  sesionesAtrasadas,
} from "../lib/plan";
import { useEstudiar } from "../lib/store";
import type { EtapaPlan } from "../lib/tipos";

const DIAS_SEMANA = [
  { valor: 1, nombre: "Lun" },
  { valor: 2, nombre: "Mar" },
  { valor: 3, nombre: "Mié" },
  { valor: 4, nombre: "Jue" },
  { valor: 5, nombre: "Vie" },
  { valor: 6, nombre: "Sáb" },
  { valor: 0, nombre: "Dom" },
];

const TONOS_ETAPA: Record<EtapaPlan, Tono> = {
  reconocimiento: "neutro",
  comprension: "acento",
  practica: "atencion",
  repaso: "logro",
  simulacro: "alerta",
};

export function Planificador() {
  const { estado, acciones } = useEstudiar();
  const [temaId, setTemaId] = useState("");
  const [fechaLimite, setFechaLimite] = useState(sumarDias(hoyClave(), 7));
  const [minutos, setMinutos] = useState(40);
  const [dias, setDias] = useState<number[]>([1, 2, 3, 4, 5]);
  const [notas, setNotas] = useState("");

  const temaElegido = estado.temas.find((tema) => tema.id === temaId) ?? estado.temas[0];
  const planes = estado.planes;

  const alternarDia = (valor: number) =>
    setDias((previo) => (previo.includes(valor) ? previo.filter((dia) => dia !== valor) : [...previo, valor]));

  const armar = () => {
    if (!temaElegido) return;
    acciones.crearPlan({
      temaId: temaElegido.id,
      titulo: temaElegido.nombre,
      fechaLimite,
      minutosPorDia: minutos,
      diasSemana: dias,
    });
    if (notas.trim()) {
      acciones.agregarEvento({
        tipo: "sesion",
        titulo: `Nota del plan: ${notas.trim()}`,
        fecha: fechaLimite,
        temaId: temaElegido.id,
      });
      setNotas("");
    }
  };

  return (
    <div className="space-y-6">
      <Tarjeta>
        <TituloSeccion
          icono="planificador"
          titulo="Planificador"
          bajada="Decime el tema y la fecha límite. Armo un plan diario que entre de verdad en tus días, no uno que te haga sentir mal."
        />

        {estado.temas.length === 0 ? (
          <div className="space-y-4">
            <Vacio
              icono="archivo"
              titulo="Todavía no cargaste ningún tema"
              texto="Creá tu primer tema para poder planificarlo, estudiarlo y medirlo."
            />
            <FormularioTema onCreado={setTemaId} />
          </div>
        ) : (
          <div className="space-y-4">
            <div className="grid gap-4 sm:grid-cols-2">
              <Selector etiqueta="Tema" value={temaElegido?.id ?? ""} onChange={(evento) => setTemaId(evento.target.value)}>
                {estado.temas.map((tema) => (
                  <option key={tema.id} value={tema.id}>
                    {tema.nombre} · {tema.materia}
                  </option>
                ))}
              </Selector>
              <Campo
                etiqueta="Fecha límite"
                type="date"
                min={hoyClave()}
                value={fechaLimite}
                onChange={(evento) => setFechaLimite(evento.target.value)}
                ayuda={`Es ${cuandoEs(fechaLimite)}`}
              />
            </div>

            <Deslizador
              etiqueta="Minutos por día"
              unidad="min"
              valor={minutos}
              min={15}
              max={MINUTOS_MAXIMOS_POR_DIA}
              step={5}
              onChange={(evento) => setMinutos(Number(evento.target.value))}
              ayuda="Sé honesta con vos: es mejor sostener 30 minutos reales que planificar 3 horas que no vas a hacer."
            />

            <div>
              <span className="em-rotulo mb-2 block">Días que podés estudiar</span>
              <div className="flex flex-wrap gap-2">
                {DIAS_SEMANA.map((dia) => {
                  const activo = dias.includes(dia.valor);
                  return (
                    <button
                      key={dia.valor}
                      type="button"
                      onClick={() => alternarDia(dia.valor)}
                      aria-pressed={activo}
                      className={`rounded-full px-4 py-2 text-sm font-bold transition-all duration-200 active:scale-95 ${
                        activo ? "bg-acento text-white " : "bg-papel text-media hover:bg-linea"
                      }`}
                    >
                      {dia.nombre}
                    </button>
                  );
                })}
              </div>
            </div>

            <Area
              etiqueta="¿Algo que tengas que tener en cuenta? (opcional)"
              placeholder="Ej: el jueves tengo entrenamiento y llego tarde"
              value={notas}
              onChange={(evento) => setNotas(evento.target.value)}
              className="[&_textarea]:min-h-20"
            />

            <div className="flex flex-wrap items-center gap-3">
              <Boton onClick={armar} disabled={!temaElegido}>
                Armar plan diario
              </Boton>
              <span className="text-xs text-tenue">Si ya había un plan para este tema, se reemplaza.</span>
            </div>

            <FormularioTema onCreado={setTemaId} />
          </div>
        )}

        <AvisoPrincipio texto="El plan organiza tu tiempo, no hace el trabajo. Cada sesión te pide a vos leer, explicar, practicar o revisar." />
      </Tarjeta>

      {planes.map((plan, indice) => {
        const avance = progresoPlan(plan);
        const atrasadas = sesionesAtrasadas(plan);
        const diagnostico = diagnosticoPlan(plan);
        const tema = estado.temas.find((candidato) => candidato.id === plan.temaId);

        return (
          <Tarjeta key={plan.id} retraso={indice * 60}>
            <div className="mb-4 flex flex-wrap items-start justify-between gap-3">
              <div>
                <h3 className="text-lg font-semibold text-tinta">{plan.titulo}</h3>
                <p className="text-sm text-media">
                  {tema?.materia ?? "General"} · entrega {fechaLarga(plan.fechaLimite)} ({cuandoEs(plan.fechaLimite)})
                </p>
              </div>
              <Boton variante="peligro" onClick={() => acciones.eliminarPlan(plan.id)}>
                Borrar plan
              </Boton>
            </div>

            <div className="mb-4 grid gap-3 sm:grid-cols-3">
              <Dato valor={`${avance}%`} etiqueta="Avance" />
              <Dato valor={`${plan.sesiones.filter((sesion) => sesion.hecho).length}/${plan.sesiones.length}`} etiqueta="Sesiones hechas" />
              <Dato valor={minutosLegibles(minutosTotales(plan))} etiqueta="Tiempo total del plan" />
            </div>

            <Barra valor={avance} tono={avance >= 70 ? "logro" : avance >= 35 ? "acento" : "atencion"} alto="h-3" />

            {diagnostico ? (
              <div className="mt-3">
                <Nota tono="atencion">{diagnostico}</Nota>
              </div>
            ) : null}

            {atrasadas.length > 0 ? (
              <div className="mt-3">
                <Nota>
                  Tenés {atrasadas.length} {atrasadas.length === 1 ? "sesión atrasada" : "sesiones atrasadas"}. No hace falta
                  recuperarlas todas: empezá por la más vieja y seguí.
                </Nota>
              </div>
            ) : null}

            <ul className="mt-4 space-y-2">
              {plan.sesiones.map((sesion) => {
                const esHoy = sesion.fecha === hoyClave();
                return (
                  <li
                    key={sesion.id}
                    className={`flex flex-wrap items-center gap-3 rounded-md border px-4 py-3 transition-colors ${
                      sesion.hecho
                        ? "border-logro-linea bg-logro-tenue"
                        : esHoy
                          ? "border-acento-linea bg-acento-tenue"
                          : "border-linea bg-superficie"
                    }`}
                  >
                    <label className="flex flex-1 cursor-pointer items-start gap-3">
                      <input
                        type="checkbox"
                        checked={sesion.hecho}
                        onChange={() => acciones.alternarSesion(plan.id, sesion.id)}
                        className="mt-1 h-5 w-5 shrink-0 accent-[#1c7a54]"
                      />
                      <span className="min-w-0">
                        <span className={`block text-sm font-bold ${sesion.hecho ? "text-logro line-through" : "text-tinta"}`}>
                          {sesion.objetivo}
                        </span>
                        <span className="mt-1 flex flex-wrap items-center gap-2 text-xs text-media">
                          <Pildora tono={TONOS_ETAPA[sesion.etapa] ?? "acento"}>{ETAPAS[sesion.etapa].nombre}</Pildora>
                          <span>
                            {diaCorto(sesion.fecha)} {fechaCorta(sesion.fecha)}
                          </span>
                          <span>· {sesion.minutos} min</span>
                          {esHoy && !sesion.hecho ? <span className="font-bold text-acento">· es hoy</span> : null}
                        </span>
                      </span>
                    </label>
                  </li>
                );
              })}
            </ul>
          </Tarjeta>
        );
      })}
    </div>
  );
}

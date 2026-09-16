"use client";

import { Barra, Dato, Pildora, Tarjeta, TituloSeccion, Vacio } from "../components/ui";
import { cuandoEs, fechaCorta, minutosLegibles } from "../lib/fechas";
import { calcularConstancia, resumenProceso } from "../lib/metricas";
import { useEstudiar } from "../lib/store";

function intensidad(minutos: number): string {
  if (minutos === 0) return "bg-slate-100";
  if (minutos < 20) return "bg-indigo-200";
  if (minutos < 45) return "bg-indigo-400";
  if (minutos < 90) return "bg-indigo-600";
  return "bg-indigo-800";
}

export function PanelAdultos() {
  const { estado } = useEstudiar();
  const constancia = calcularConstancia(estado.logs);
  const proceso = resumenProceso(estado);
  const semanas: { fecha: string; minutos: number }[][] = [];

  for (let i = 0; i < constancia.mapaCalor.length; i += 7) {
    semanas.push(constancia.mapaCalor.slice(i, i + 7));
  }

  const cumplimiento =
    proceso.sesionesPlanificadas === 0
      ? 0
      : Math.round((proceso.sesionesCumplidas / proceso.sesionesPlanificadas) * 100);

  return (
    <div className="space-y-6">
      <Tarjeta>
        <TituloSeccion
          icono="👩‍👦"
          titulo="Panel para familias y docentes"
          bajada="Para acompañar sin vigilar. Muestra constancia y proceso de estudio."
        />

        <div className="mb-5 rounded-2xl border border-violet-200 bg-violet-50 px-4 py-3 text-sm font-semibold text-violet-900">
          🔒 Este panel <strong>no muestra notas ni calificaciones</strong>, ni el contenido de lo que el alumno escribe. Muestra si
          estudió, cuánto sostuvo el hábito y en qué está trabajando. Las notas son cosa de la escuela; acá se ve el proceso.
        </div>

        {estado.logs.length === 0 ? (
          <Vacio icono="🌱" titulo="Todavía no hay actividad registrada" texto="En cuanto empiece a usar los módulos, acá aparece el seguimiento." />
        ) : (
          <>
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              <Dato valor={`${constancia.rachaActual} días`} etiqueta="Racha actual" icono="🔥" />
              <Dato valor={`${constancia.diasActivos30}/30`} etiqueta="Días con estudio (último mes)" icono="📆" />
              <Dato valor={minutosLegibles(constancia.minutos7)} etiqueta="Tiempo en los últimos 7 días" icono="⏳" />
              <Dato valor={`${cumplimiento}%`} etiqueta="Sesiones del plan cumplidas" icono="✅" />
            </div>

            <div className="mt-6">
              <p className="mb-2 text-xs font-bold uppercase tracking-wide text-slate-500">Constancia de las últimas 8 semanas</p>
              <div className="em-scroll-suave flex gap-1 overflow-x-auto pb-2">
                {semanas.map((semana) => (
                  <div key={semana[0]?.fecha} className="flex flex-col gap-1">
                    {semana.map((dia) => (
                      <span
                        key={dia.fecha}
                        title={`${fechaCorta(dia.fecha)}: ${dia.minutos} min`}
                        className={`h-4 w-4 rounded-[5px] ${intensidad(dia.minutos)}`}
                      />
                    ))}
                  </div>
                ))}
              </div>
              <div className="mt-1.5 flex items-center gap-2 text-xs text-slate-400">
                <span>Menos</span>
                {["bg-slate-100", "bg-indigo-200", "bg-indigo-400", "bg-indigo-600", "bg-indigo-800"].map((clase) => (
                  <span key={clase} className={`h-3 w-3 rounded-[4px] ${clase}`} />
                ))}
                <span>Más</span>
              </div>
            </div>
          </>
        )}
      </Tarjeta>

      <Tarjeta retraso={70}>
        <TituloSeccion icono="🔬" titulo="Proceso de estudio" bajada="Qué tipo de trabajo viene haciendo, no cuánto sabe." />

        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          <Dato valor={`${proceso.preguntasTrabajadas}`} etiqueta="Preguntas respondidas" icono="🧠" />
          <Dato valor={`${proceso.explicaciones}`} etiqueta="Veces que explicó un tema" icono="🗣️" />
          <Dato valor={`${proceso.simulacros}`} etiqueta="Simulacros hechos" icono="⏱️" />
          <Dato valor={`${proceso.erroresAbiertos}`} etiqueta="Errores en revisión" icono="🔁" />
          <Dato valor={`${proceso.erroresResueltos}`} etiqueta="Errores superados" icono="🟢" />
          <Dato valor={`${proceso.temasFirmes}/${estado.temas.length}`} etiqueta="Temas que ya puede explicar" icono="🚦" />
        </div>

        <div className="mt-5">
          <div className="mb-1.5 flex items-center justify-between text-sm font-bold text-slate-600">
            <span>Cumplimiento del plan</span>
            <span>
              {proceso.sesionesCumplidas} de {proceso.sesionesPlanificadas} sesiones
            </span>
          </div>
          <Barra valor={cumplimiento} tono={cumplimiento >= 70 ? "emerald" : cumplimiento >= 40 ? "indigo" : "amber"} alto="h-3" />
        </div>

        <div className="mt-6 space-y-2 rounded-2xl bg-slate-50 p-4">
          <p className="text-sm font-bold text-slate-700">Cómo leer esto</p>
          <ul className="space-y-1.5 text-sm text-slate-600">
            <li>• Una racha corta con sesiones cumplidas es mejor señal que una maratón de un día.</li>
            <li>• Muchos errores registrados no es mala noticia: significa que los está detectando y trabajando.</li>
            <li>• Si un tema está en revisión hace semanas, ahí conviene ofrecer ayuda humana.</li>
            <li>• Preguntar “¿qué entendiste hoy?” funciona mejor que preguntar “¿cuánto te sacaste?”.</li>
          </ul>
        </div>
      </Tarjeta>

      {estado.temas.length > 0 ? (
        <Tarjeta retraso={140}>
          <TituloSeccion icono="📋" titulo="En qué está trabajando" />
          <ul className="space-y-2">
            {estado.temas.map((tema) => {
              const evidencia = estado.dominio[tema.id];
              const erroresAbiertos = estado.errores.filter((error) => error.temaId === tema.id && !error.resuelto).length;
              return (
                <li key={tema.id} className="flex flex-wrap items-center justify-between gap-2 rounded-2xl border border-slate-200 px-4 py-3">
                  <div>
                    <p className="text-sm font-bold text-slate-800">{tema.nombre}</p>
                    <p className="text-xs text-slate-500">{tema.materia}</p>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    <Pildora tono="slate">{evidencia?.intentos ?? 0} actividades</Pildora>
                    <Pildora tono={erroresAbiertos > 0 ? "amber" : "emerald"}>
                      {erroresAbiertos > 0 ? `${erroresAbiertos} en revisión` : "sin pendientes"}
                    </Pildora>
                    {evidencia ? <Pildora tono="indigo">visto {cuandoEs(evidencia.actualizado)}</Pildora> : null}
                  </div>
                </li>
              );
            })}
          </ul>
        </Tarjeta>
      ) : null}
    </div>
  );
}

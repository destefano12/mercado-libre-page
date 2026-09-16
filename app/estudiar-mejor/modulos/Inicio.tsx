"use client";

import { useState } from "react";
import { Barra, Boton, Campo, Dato, Pildora, Tarjeta, TituloSeccion, Vacio } from "../components/ui";
import { cuandoEs, diferenciaEnDias, hoyClave, minutosLegibles } from "../lib/fechas";
import { COLORES_DOMINIO, calcularConstancia, nivelDominio } from "../lib/metricas";
import { progresoPlan } from "../lib/plan";
import { useEstudiar } from "../lib/store";
import { armarCola, preguntaDeError } from "../lib/tutor";
import type { SeccionId } from "../components/navegacion";

const ATAJOS: { seccion: SeccionId; icono: string; nombre: string; texto: string }[] = [
  { seccion: "tutor", icono: "🧠", nombre: "Preguntame", texto: "Repasá con preguntas de tu material" },
  { seccion: "explicame", icono: "🗣️", nombre: "Explicámelo vos", texto: "Contámelo y te marco los huecos" },
  { seccion: "simulador", icono: "⏱️", nombre: "Simulacro", texto: "Prueba cronometrada y corregida" },
  { seccion: "pomodoro", icono: "🍅", nombre: "Pomodoro", texto: "Un bloque de enfoque de verdad" },
];

export function Inicio({ irA }: { irA: (seccion: SeccionId) => void }) {
  const { estado, acciones } = useEstudiar();
  const [nombre, setNombre] = useState(estado.nombre);

  const hoy = hoyClave();
  const constancia = calcularConstancia(estado.logs);
  const cola = armarCola(estado.tarjetas, estado.errores, "todos");
  const minutosHoy = estado.logs.filter((log) => log.fecha === hoy).reduce((total, log) => total + log.minutos, 0);

  const sesionesHoy = estado.planes.flatMap((plan) =>
    plan.sesiones.filter((sesion) => sesion.fecha === hoy).map((sesion) => ({ plan, sesion })),
  );
  const proximos = [...estado.agenda]
    .filter((evento) => !evento.hecho && evento.fecha >= hoy)
    .sort((a, b) => a.fecha.localeCompare(b.fecha))
    .slice(0, 3);

  const errorMasRepetido = [...estado.errores]
    .filter((error) => !error.resuelto)
    .sort((a, b) => b.veces - a.veces)[0];

  const semaforo = estado.temas.map((tema) => ({ tema, nivel: nivelDominio(estado.dominio[tema.id]) }));

  if (!estado.nombre) {
    return (
      <Tarjeta>
        <TituloSeccion icono="👋" titulo="Hola, ¿cómo te llamás?" bajada="Con esto alcanza: no hay cuentas, ni mails, ni contraseñas. Todo queda en este navegador." />
        <div className="grid gap-4 sm:grid-cols-[1fr_auto] sm:items-end">
          <Campo
            etiqueta="Tu nombre"
            placeholder="Ej: Sofi"
            value={nombre}
            onChange={(evento) => setNombre(evento.target.value)}
            onKeyDown={(evento) => {
              if (evento.key === "Enter" && nombre.trim()) acciones.guardarNombre(nombre.trim());
            }}
          />
          <Boton className="h-11" disabled={!nombre.trim()} onClick={() => acciones.guardarNombre(nombre.trim())}>
            Empezar
          </Boton>
        </div>
        <div className="mt-6 rounded-2xl bg-violet-50 p-4 text-sm leading-relaxed text-violet-900">
          <strong>Antes de entrar, el trato:</strong> esta plataforma no resuelve tareas, no redacta trabajos y no responde
          ejercicios. Organiza, pregunta y te muestra dónde se corta tu razonamiento. Si buscás que alguien lo haga por vos,
          este no es el lugar. Si buscás entenderlo, sí.
        </div>
        <div className="mt-4">
          <Boton variante="secundario" onClick={acciones.cargarEjemplo}>
            Ver la app con datos de ejemplo
          </Boton>
        </div>
      </Tarjeta>
    );
  }

  return (
    <div className="space-y-6">
      <Tarjeta className="bg-gradient-to-br from-indigo-600 to-violet-600 text-white">
        <p className="text-sm font-bold text-indigo-200">
          {new Date().getHours() < 13 ? "Buen día" : new Date().getHours() < 20 ? "Buenas tardes" : "Buenas noches"}
        </p>
        <h2 className="text-3xl font-black tracking-tight sm:text-4xl">{estado.nombre}</h2>
        <p className="mt-2 max-w-xl text-sm text-indigo-100">
          {cola.pendientes.length > 0
            ? `Tenés ${cola.pendientes.length} preguntas esperándote y ${sesionesHoy.filter((entrada) => !entrada.sesion.hecho).length} sesiones para hoy.`
            : sesionesHoy.some((entrada) => !entrada.sesion.hecho)
              ? "Hoy tenés sesión de estudio agendada. Arrancá por ahí."
              : "No hay repasos pendientes. Buen momento para cargar material nuevo o descansar sin culpa."}
        </p>

        <div className="mt-5 grid gap-3 sm:grid-cols-3">
          <div className="rounded-2xl bg-white/15 px-4 py-3 backdrop-blur">
            <p className="text-2xl font-black">{constancia.rachaActual} 🔥</p>
            <p className="text-xs font-semibold uppercase tracking-wide text-indigo-100">Días seguidos</p>
          </div>
          <div className="rounded-2xl bg-white/15 px-4 py-3 backdrop-blur">
            <p className="text-2xl font-black">{minutosLegibles(minutosHoy)}</p>
            <p className="text-xs font-semibold uppercase tracking-wide text-indigo-100">Estudiado hoy</p>
          </div>
          <div className="rounded-2xl bg-white/15 px-4 py-3 backdrop-blur">
            <p className="text-2xl font-black">{cola.pendientes.length}</p>
            <p className="text-xs font-semibold uppercase tracking-wide text-indigo-100">Preguntas para hoy</p>
          </div>
        </div>
      </Tarjeta>

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {ATAJOS.map((atajo, indice) => (
          <button
            key={atajo.seccion}
            type="button"
            onClick={() => irA(atajo.seccion)}
            style={{ animationDelay: `${indice * 60}ms` }}
            className="em-aparecer group rounded-3xl border border-slate-200 bg-white p-5 text-left transition-all duration-200 hover:-translate-y-1 hover:border-indigo-300 hover:shadow-lg"
          >
            <span aria-hidden className="text-3xl transition-transform duration-200 group-hover:scale-110">
              {atajo.icono}
            </span>
            <p className="mt-2 text-base font-extrabold text-slate-900">{atajo.nombre}</p>
            <p className="text-sm text-slate-500">{atajo.texto}</p>
          </button>
        ))}
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <Tarjeta retraso={60}>
          <TituloSeccion icono="📌" titulo="Tu día" />
          {sesionesHoy.length === 0 ? (
            <Vacio
              icono="🗓️"
              titulo="No hay sesiones para hoy"
              texto="Armá un plan con fecha límite y te reparto el tema en sesiones diarias."
              accion={<Boton onClick={() => irA("planificador")}>Ir al planificador</Boton>}
            />
          ) : (
            <ul className="space-y-2">
              {sesionesHoy.map(({ plan, sesion }) => (
                <li
                  key={sesion.id}
                  className={`flex items-start gap-3 rounded-2xl border px-4 py-3 ${sesion.hecho ? "border-emerald-200 bg-emerald-50/60" : "border-indigo-200 bg-indigo-50/50"}`}
                >
                  <input
                    type="checkbox"
                    checked={sesion.hecho}
                    onChange={() => acciones.alternarSesion(plan.id, sesion.id)}
                    className="mt-1 h-5 w-5 accent-emerald-600"
                  />
                  <div className="min-w-0">
                    <p className={`text-sm font-bold ${sesion.hecho ? "text-emerald-800 line-through" : "text-slate-800"}`}>
                      {sesion.objetivo}
                    </p>
                    <p className="text-xs text-slate-500">
                      {plan.titulo} · {sesion.minutos} min · avance del plan {progresoPlan(plan)}%
                    </p>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </Tarjeta>

        <Tarjeta retraso={120}>
          <TituloSeccion icono="⏭️" titulo="Lo que se viene" />
          {proximos.length === 0 ? (
            <Vacio
              icono="🌤️"
              titulo="Sin entregas ni exámenes cargados"
              texto="Cargalos y te aviso cuánto falta, sin sorpresas."
              accion={<Boton onClick={() => irA("agenda")}>Abrir agenda</Boton>}
            />
          ) : (
            <ul className="space-y-2">
              {proximos.map((evento) => {
                const dias = diferenciaEnDias(hoy, evento.fecha);
                return (
                  <li key={evento.id} className="flex items-center justify-between gap-3 rounded-2xl border border-slate-200 px-4 py-3">
                    <span className="text-sm font-bold text-slate-800">{evento.titulo}</span>
                    <Pildora tono={dias <= 2 ? "rose" : dias <= 7 ? "amber" : "slate"}>{cuandoEs(evento.fecha)}</Pildora>
                  </li>
                );
              })}
            </ul>
          )}
        </Tarjeta>
      </div>

      {semaforo.length > 0 ? (
        <Tarjeta retraso={160}>
          <TituloSeccion
            icono="🚦"
            titulo="Tus temas de un vistazo"
            accion={
              <Boton variante="secundario" onClick={() => irA("mapa")}>
                Ver mapa completo
              </Boton>
            }
          />
          <ul className="space-y-2">
            {semaforo.map(({ tema, nivel }) => (
              <li key={tema.id} className="flex items-center gap-3 rounded-2xl border border-slate-200 px-4 py-3">
                <span className={`h-3 w-3 shrink-0 rounded-full ${COLORES_DOMINIO[nivel].punto}`} />
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-bold text-slate-800">{tema.nombre}</p>
                  <p className="text-xs text-slate-500">{COLORES_DOMINIO[nivel].etiqueta}</p>
                </div>
                <div className="w-24 shrink-0">
                  <Barra
                    valor={estado.dominio[tema.id] ? (estado.dominio[tema.id].aciertos / Math.max(1, estado.dominio[tema.id].intentos)) * 100 : 0}
                    tono={nivel === "verde" ? "emerald" : nivel === "amarillo" ? "amber" : nivel === "rojo" ? "rose" : "slate"}
                    alto="h-2"
                  />
                </div>
              </li>
            ))}
          </ul>
        </Tarjeta>
      ) : null}

      {errorMasRepetido ? (
        <Tarjeta retraso={200}>
          <TituloSeccion icono="🔁" titulo="Tu error más repetido" bajada="Vuelve a aparecer hasta que deje de fallar. No es insistencia: es el método." />
          <p className="text-base font-extrabold text-slate-900">{errorMasRepetido.titulo}</p>
          <p className="mt-2 rounded-2xl bg-amber-50 px-4 py-3 text-sm font-semibold text-amber-900">
            {preguntaDeError(errorMasRepetido)}
          </p>
          <div className="mt-3 flex flex-wrap gap-2">
            <Boton variante="secundario" onClick={() => irA("errores")}>
              Ver todos mis errores
            </Boton>
            <Dato valor={`×${errorMasRepetido.veces}`} etiqueta="Veces que te pasó" />
          </div>
        </Tarjeta>
      ) : null}
    </div>
  );
}

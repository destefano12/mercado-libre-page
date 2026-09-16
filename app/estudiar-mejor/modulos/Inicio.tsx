"use client";

import { useState } from "react";
import { Barra, Boton, Campo, Dato, Pildora, Tarjeta, TituloSeccion, Vacio } from "../components/ui";
import { cuandoEs, diferenciaEnDias, hoyClave, minutosLegibles } from "../lib/fechas";
import { COLORES_DOMINIO, calcularConstancia, nivelDominio } from "../lib/metricas";
import { progresoPlan } from "../lib/plan";
import { useEstudiar } from "../lib/store";
import { armarCola, preguntaDeError } from "../lib/tutor";
import type { SeccionId } from "../components/navegacion";
import { Icono, type NombreIcono } from "../components/iconos";

const ATAJOS: { seccion: SeccionId; icono: NombreIcono; nombre: string; texto: string }[] = [
  { seccion: "tutor", icono: "tutor", nombre: "Preguntame", texto: "Repasá con preguntas de tu material" },
  { seccion: "explicame", icono: "explicame", nombre: "Explicámelo vos", texto: "Contámelo y te marco los huecos" },
  { seccion: "simulador", icono: "simulador", nombre: "Simulacro", texto: "Prueba cronometrada y corregida" },
  { seccion: "pomodoro", icono: "pomodoro", nombre: "Pomodoro", texto: "Un bloque de enfoque de verdad" },
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
        <TituloSeccion icono="hoy" titulo="Hola, ¿cómo te llamás?" bajada="Con esto alcanza: no hay cuentas, ni mails, ni contraseñas. Todo queda en este navegador." />
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
        <div className="mt-6 rounded-md bg-acento-tenue p-4 text-sm leading-relaxed text-acento-fuerte">
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
      <Tarjeta className="bg-tinta text-white">
        <p className="text-sm font-bold text-white/70">
          {new Date().getHours() < 13 ? "Buen día" : new Date().getHours() < 20 ? "Buenas tardes" : "Buenas noches"}
        </p>
        <h2 className="text-3xl font-semibold tracking-tight sm:text-4xl">{estado.nombre}</h2>
        <p className="mt-2 max-w-xl text-sm text-white/80">
          {cola.pendientes.length > 0
            ? `Tenés ${cola.pendientes.length} preguntas esperándote y ${sesionesHoy.filter((entrada) => !entrada.sesion.hecho).length} sesiones para hoy.`
            : sesionesHoy.some((entrada) => !entrada.sesion.hecho)
              ? "Hoy tenés sesión de estudio agendada. Arrancá por ahí."
              : "No hay repasos pendientes. Buen momento para cargar material nuevo o descansar sin culpa."}
        </p>

        <div className="mt-5 grid grid-cols-3 gap-2 sm:gap-3">
          <div className="rounded-md border border-white/15 px-3 py-2.5 sm:px-4 sm:py-3">
            <p className="em-cifra flex items-center gap-1.5 whitespace-nowrap text-lg font-semibold sm:text-2xl">
              {constancia.rachaActual}
              <Icono nombre="racha" tamaño={18} className="text-white/60" />
            </p>
            <p className="em-rotulo mt-0.5 text-white/70">Días seguidos</p>
          </div>
          <div className="rounded-md border border-white/15 px-3 py-2.5 sm:px-4 sm:py-3">
            <p className="em-cifra whitespace-nowrap text-lg font-semibold sm:text-2xl">{minutosLegibles(minutosHoy)}</p>
            <p className="em-rotulo mt-0.5 text-white/70">Estudiado hoy</p>
          </div>
          <div className="rounded-md border border-white/15 px-3 py-2.5 sm:px-4 sm:py-3">
            <p className="em-cifra whitespace-nowrap text-lg font-semibold sm:text-2xl">{cola.pendientes.length}</p>
            <p className="em-rotulo mt-0.5 text-white/70">Preguntas para hoy</p>
          </div>
        </div>
      </Tarjeta>

      <div className="grid grid-cols-2 gap-3 xl:grid-cols-4">
        {ATAJOS.map((atajo, indice) => (
          <button
            key={atajo.seccion}
            type="button"
            onClick={() => irA(atajo.seccion)}
            style={{ animationDelay: `${indice * 60}ms` }}
            className="em-aparecer group rounded-lg border border-linea bg-superficie p-4 text-left transition-colors duration-150 hover:border-acento"
          >
            <span className="grid h-9 w-9 place-items-center rounded-md bg-acento-tenue text-acento">
              <Icono nombre={atajo.icono} tamaño={18} />
            </span>
            <p className="mt-2.5 font-semibold text-tinta">{atajo.nombre}</p>
            <p className="mt-0.5 text-sm leading-snug text-media">{atajo.texto}</p>
          </button>
        ))}
      </div>

      <div className="grid items-start gap-6 lg:grid-cols-2">
        <Tarjeta retraso={60}>
          <TituloSeccion icono="hoy" titulo="Tu día" />
          {sesionesHoy.length === 0 ? (
            <Vacio
              icono="planificador"
              titulo="No hay sesiones para hoy"
              texto="Armá un plan con fecha límite y te reparto el tema en sesiones diarias."
              accion={<Boton onClick={() => irA("planificador")}>Ir al planificador</Boton>}
            />
          ) : (
            <ul className="space-y-2">
              {sesionesHoy.map(({ plan, sesion }) => (
                <li
                  key={sesion.id}
                  className={`flex items-start gap-3 rounded-md border px-4 py-3 ${sesion.hecho ? "border-logro-linea bg-logro-tenue" : "border-acento-linea bg-acento-tenue"}`}
                >
                  <input
                    type="checkbox"
                    checked={sesion.hecho}
                    onChange={() => acciones.alternarSesion(plan.id, sesion.id)}
                    className="mt-1 h-5 w-5 accent-[#1c7a54]"
                  />
                  <div className="min-w-0">
                    <p className={`text-sm font-bold ${sesion.hecho ? "text-logro line-through" : "text-tinta"}`}>
                      {sesion.objetivo}
                    </p>
                    <p className="text-xs text-media">
                      {plan.titulo} · {sesion.minutos} min · avance del plan {progresoPlan(plan)}%
                    </p>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </Tarjeta>

        <Tarjeta retraso={120}>
          <TituloSeccion icono="flecha" titulo="Lo que se viene" />
          {proximos.length === 0 ? (
            <Vacio
              icono="agenda"
              titulo="Sin entregas ni exámenes cargados"
              texto="Cargalos y te aviso cuánto falta, sin sorpresas."
              accion={<Boton onClick={() => irA("agenda")}>Abrir agenda</Boton>}
            />
          ) : (
            <ul className="space-y-2">
              {proximos.map((evento) => {
                const dias = diferenciaEnDias(hoy, evento.fecha);
                return (
                  <li key={evento.id} className="flex items-center justify-between gap-3 rounded-md border border-linea px-4 py-3">
                    <span className="text-sm font-bold text-tinta">{evento.titulo}</span>
                    <Pildora tono={dias <= 2 ? "alerta" : dias <= 7 ? "atencion" : "neutro"}>{cuandoEs(evento.fecha)}</Pildora>
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
            icono="mapa"
            titulo="Tus temas de un vistazo"
            accion={
              <Boton variante="secundario" onClick={() => irA("mapa")}>
                Ver mapa completo
              </Boton>
            }
          />
          <ul className="space-y-2">
            {semaforo.map(({ tema, nivel }) => (
              <li key={tema.id} className="flex items-center gap-3 rounded-md border border-linea px-4 py-3">
                <span className={`h-3 w-3 shrink-0 rounded-full ${COLORES_DOMINIO[nivel].punto}`} />
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-bold text-tinta">{tema.nombre}</p>
                  <p className="text-xs text-media">{COLORES_DOMINIO[nivel].etiqueta}</p>
                </div>
                <div className="w-24 shrink-0">
                  <Barra
                    valor={estado.dominio[tema.id] ? (estado.dominio[tema.id].aciertos / Math.max(1, estado.dominio[tema.id].intentos)) * 100 : 0}
                    tono={nivel === "verde" ? "logro" : nivel === "amarillo" ? "atencion" : nivel === "rojo" ? "alerta" : "neutro"}
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
          <TituloSeccion icono="repetir" titulo="Tu error más repetido" bajada="Vuelve a aparecer hasta que deje de fallar. No es insistencia: es el método." />
          <p className="text-base font-semibold text-tinta">{errorMasRepetido.titulo}</p>
          <p className="mt-2 rounded-md bg-atencion-tenue px-4 py-3 text-sm font-semibold text-atencion">
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

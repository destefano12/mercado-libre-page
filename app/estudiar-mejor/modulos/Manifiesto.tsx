"use client";

import { Boton, Nota, Tarjeta, TituloSeccion } from "../components/ui";
import { Icono } from "../components/iconos";
import { useEstudiar } from "../lib/store";

const COMPROMISOS = [
  {
    icono: "cerrar" as const,
    titulo: "Nunca resuelvo tus tareas",
    texto: "No completo ejercicios, no respondo consignas y no entrego nada que tenga que entregar tu nombre.",
  },
  {
    icono: "explicame" as const,
    titulo: "Nunca redacto tus trabajos",
    texto: "Ni ensayos, ni informes, ni conclusiones, ni ese párrafo que te falta. El texto que entregás lo escribís vos.",
  },
  {
    icono: "ayuda" as const,
    titulo: "Ante un pedido de respuesta, devuelvo preguntas",
    texto: "Si me pedís la respuesta, te devuelvo el camino: qué pide la consigna, qué datos tenés, por dónde empezar.",
  },
  {
    icono: "planificador" as const,
    titulo: "Doy pistas, no soluciones",
    texto: "Las pistas te acercan de a un escalón. La última pista nunca es la respuesta: es una forma de ordenarla.",
  },
  {
    icono: "mapa" as const,
    titulo: "Te muestro los huecos, no los tapo",
    texto: "Cuando falta una idea, te digo que falta y te pregunto hasta que la encuentres. No te la escribo.",
  },
  {
    icono: "adultos" as const,
    titulo: "Mido proceso, no talento",
    texto: "El mapa de dominio y el panel de adultos muestran constancia y trabajo. Las notas son cosa de la escuela.",
  },
  {
    icono: "manifiesto" as const,
    titulo: "Tus cosas son tuyas",
    texto: "Todo lo que cargás se guarda en este navegador. No hay servidores, ni cuentas, ni nadie leyendo tus apuntes.",
  },
];

export function Manifiesto() {
  const { estado, acciones } = useEstudiar();

  return (
    <div className="space-y-6">
      <Tarjeta className="overflow-hidden bg-tinta text-white">
        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-white/70">Principio inviolable</p>
        <h2 className="mt-2 text-2xl font-semibold leading-tight sm:text-4xl">
          Esta plataforma no hace tu tarea.
          <br />
          Te hace pensarla.
        </h2>
        <p className="mt-4 max-w-2xl text-sm leading-relaxed text-white/80 sm:text-base">
          Si te diera las respuestas, el día de la prueba no las ibas a tener. Todo lo que hay acá —el plan, las preguntas,
          los simulacros, el registro de errores— existe para que llegues vos a la respuesta, con tu cabeza y tu letra.
          Eso no es ponerte el camino más difícil: es el único camino que después sirve.
        </p>
      </Tarjeta>

      <Tarjeta retraso={60}>
        <TituloSeccion icono="grupos" titulo="Lo que me comprometo a hacer y a no hacer" />

        <ul className="grid gap-3 sm:grid-cols-2">
          {COMPROMISOS.map((compromiso, indice) => (
            <li
              key={compromiso.titulo}
              className="em-aparecer rounded-md border border-linea bg-superficie p-4"
              style={{ animationDelay: `${indice * 60}ms` }}
            >
              <span className="grid h-8 w-8 place-items-center rounded-md bg-acento-tenue text-acento">
                <Icono nombre={compromiso.icono} tamaño={17} />
              </span>
              <h3 className="mt-2.5 text-base text-tinta">{compromiso.titulo}</h3>
              <p className="mt-1 text-sm leading-relaxed text-media">{compromiso.texto}</p>
            </li>
          ))}
        </ul>
      </Tarjeta>

      <Tarjeta retraso={120}>
        <TituloSeccion icono="ayuda" titulo="Cómo se ve esto en la práctica" />
        <div className="grid gap-3 sm:grid-cols-2">
          <div className="rounded-md border border-alerta-linea bg-alerta-tenue p-4">
            <p className="text-xs font-semibold uppercase tracking-wide text-alerta">Lo que pedís</p>
            <p className="mt-2 text-sm font-bold text-tinta">“Resolveme el ejercicio 4 y explicame después.”</p>
          </div>
          <div className="rounded-md border border-logro-linea bg-logro-tenue p-4">
            <p className="text-xs font-semibold uppercase tracking-wide text-logro">Lo que te devuelvo</p>
            <ul className="em-lista mt-2 space-y-1.5 text-sm leading-relaxed text-tinta">
              <li>¿Qué te pide exactamente la consigna, con tus palabras?</li>
              <li>¿Qué datos tenés y cuál es la incógnita?</li>
              <li>¿Qué ejercicio parecido ya hiciste? ¿En qué cambia este?</li>
              <li>Cuando tengas un resultado: ¿cómo lo verificás?</li>
            </ul>
          </div>
        </div>

        {!estado.manifiestoAceptado ? (
          <div className="mt-5 flex flex-wrap items-center gap-3">
            <Boton onClick={acciones.aceptarManifiesto}>Entendido, arranquemos así</Boton>
            <span className="text-sm text-media">Vas a ver este recordatorio en cada módulo igual.</span>
          </div>
        ) : (
          <div className="mt-5">
            <Nota tono="logro">
              Ya aceptaste el trato. Está bueno volver a leerlo el día que estés apurado y tentado de pedir la respuesta.
            </Nota>
          </div>
        )}
      </Tarjeta>
    </div>
  );
}

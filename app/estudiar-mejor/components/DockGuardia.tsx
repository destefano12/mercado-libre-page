"use client";

import { useState } from "react";
import { ETIQUETAS_INTENCION, responderComoGuia, type RespuestaGuardia } from "../lib/guardia";
import { Boton, Pildora } from "./ui";

export function DockGuardia() {
  const [abierto, setAbierto] = useState(false);
  const [texto, setTexto] = useState("");
  const [respuesta, setRespuesta] = useState<RespuestaGuardia | null>(null);

  const preguntar = () => {
    if (!texto.trim()) return;
    setRespuesta(responderComoGuia(texto.trim()));
  };

  return (
    <>
      <button
        type="button"
        onClick={() => setAbierto((previo) => !previo)}
        aria-expanded={abierto}
        className="fixed bottom-5 right-5 z-40 flex items-center gap-2 rounded-full bg-slate-900 px-5 py-3 text-sm font-bold text-white shadow-2xl transition-transform duration-200 hover:scale-105 active:scale-95"
      >
        <span aria-hidden className="text-lg">
          {abierto ? "✕" : "💬"}
        </span>
        {abierto ? "Cerrar" : "Pedí ayuda"}
      </button>

      {abierto ? (
        <div className="em-pop fixed bottom-24 right-5 z-40 flex max-h-[70vh] w-[min(24rem,calc(100vw-2.5rem))] flex-col overflow-hidden rounded-3xl border border-slate-200 bg-white shadow-2xl">
          <header className="bg-gradient-to-r from-indigo-600 to-violet-600 px-5 py-4 text-white">
            <p className="text-sm font-black">Pedime lo que quieras</p>
            <p className="text-xs text-indigo-100">Spoiler: te voy a devolver preguntas, no respuestas.</p>
          </header>

          <div className="em-scroll-suave flex-1 overflow-y-auto px-5 py-4">
            {respuesta ? (
              <div className="em-aparecer space-y-3">
                <Pildora tono={respuesta.bloqueado ? "rose" : "indigo"}>{ETIQUETAS_INTENCION[respuesta.intencion]}</Pildora>
                <p className="text-sm font-extrabold text-slate-900">{respuesta.titulo}</p>
                <ul className="space-y-2">
                  {respuesta.preguntas.map((pregunta, indice) => (
                    <li
                      key={pregunta}
                      className="em-aparecer rounded-2xl bg-indigo-50 px-3.5 py-2.5 text-sm text-indigo-900"
                      style={{ animationDelay: `${indice * 80}ms` }}
                    >
                      {pregunta}
                    </li>
                  ))}
                </ul>
                <p className="text-xs font-semibold italic text-slate-500">{respuesta.cierre}</p>
              </div>
            ) : (
              <div className="space-y-2 text-sm text-slate-500">
                <p>Probá escribiendo lo que realmente estás pensando, por ejemplo:</p>
                <ul className="space-y-1.5">
                  {["Resolveme el ejercicio 4", "Escribime la conclusión del TP", "No entiendo el ciclo de Calvin"].map((ejemplo) => (
                    <li key={ejemplo}>
                      <button
                        type="button"
                        onClick={() => {
                          setTexto(ejemplo);
                          setRespuesta(responderComoGuia(ejemplo));
                        }}
                        className="w-full rounded-2xl bg-slate-100 px-3.5 py-2 text-left text-sm text-slate-700 transition hover:bg-slate-200"
                      >
                        “{ejemplo}”
                      </button>
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </div>

          <div className="border-t border-slate-200 p-3">
            <textarea
              value={texto}
              onChange={(evento) => setTexto(evento.target.value)}
              onKeyDown={(evento) => {
                if (evento.key === "Enter" && !evento.shiftKey) {
                  evento.preventDefault();
                  preguntar();
                }
              }}
              placeholder="Escribí tu pedido…"
              className="h-20 w-full resize-none rounded-2xl border border-slate-200 bg-slate-50 px-3.5 py-2.5 text-sm outline-none transition focus:border-indigo-400 focus:bg-white"
            />
            <div className="mt-2 flex gap-2">
              <Boton className="flex-1" onClick={preguntar} disabled={!texto.trim()}>
                Preguntar
              </Boton>
              {respuesta ? (
                <Boton
                  variante="fantasma"
                  onClick={() => {
                    setRespuesta(null);
                    setTexto("");
                  }}
                >
                  Limpiar
                </Boton>
              ) : null}
            </div>
          </div>
        </div>
      ) : null}
    </>
  );
}

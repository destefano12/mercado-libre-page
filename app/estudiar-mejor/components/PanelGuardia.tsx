"use client";

import { useState } from "react";
import { ETIQUETAS_INTENCION, responderComoGuia, type RespuestaGuardia } from "../lib/guardia";
import { Icono } from "./iconos";
import { Boton, Pildora } from "./ui";

const EJEMPLOS = [
  "Resolveme el ejercicio 4",
  "Escribime la conclusión del trabajo práctico",
  "No entiendo el ciclo de Calvin",
];

export function PanelGuardia({ abierto, onCerrar }: { abierto: boolean; onCerrar: () => void }) {
  const [texto, setTexto] = useState("");
  const [respuesta, setRespuesta] = useState<RespuestaGuardia | null>(null);

  if (!abierto) return null;

  const preguntar = (pedido: string) => {
    const limpio = pedido.trim();
    if (!limpio) return;
    setTexto(limpio);
    setRespuesta(responderComoGuia(limpio));
  };

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <button
        type="button"
        aria-label="Cerrar el panel de ayuda"
        onClick={onCerrar}
        className="absolute inset-0 bg-tinta/30"
      />

      <aside className="em-surgir relative flex h-full w-full max-w-md flex-col border-l border-linea bg-superficie">
        <header className="flex items-start justify-between gap-3 border-b border-linea px-5 py-4">
          <div>
            <h2 className="text-lg text-tinta">Pedime ayuda</h2>
            <p className="mt-0.5 text-sm text-media">Te voy a devolver preguntas, no respuestas.</p>
          </div>
          <button
            type="button"
            onClick={onCerrar}
            aria-label="Cerrar"
            className="rounded-md p-1.5 text-tenue transition-colors hover:bg-papel hover:text-tinta"
          >
            <Icono nombre="cerrar" tamaño={18} />
          </button>
        </header>

        <div className="em-scroll-suave flex-1 overflow-y-auto px-5 py-5">
          {respuesta ? (
            <div className="em-aparecer space-y-4">
              <Pildora tono={respuesta.bloqueado ? "alerta" : "acento"}>{ETIQUETAS_INTENCION[respuesta.intencion]}</Pildora>
              <h3 className="text-base text-tinta">{respuesta.titulo}</h3>
              <ol className="space-y-2">
                {respuesta.preguntas.map((pregunta, indice) => (
                  <li key={pregunta} className="flex gap-3 border-l-2 border-acento-linea py-1 pl-3 text-sm leading-relaxed text-tinta">
                    <span className="em-cifra em-rotulo mt-0.5 text-acento">{indice + 1}</span>
                    <span>{pregunta}</span>
                  </li>
                ))}
              </ol>
              <p className="border-t border-linea pt-3 text-sm italic leading-relaxed text-media">{respuesta.cierre}</p>
            </div>
          ) : (
            <div className="space-y-3">
              <p className="text-sm text-media">Escribí lo que realmente estás pensando. Por ejemplo:</p>
              <ul className="space-y-2">
                {EJEMPLOS.map((ejemplo) => (
                  <li key={ejemplo}>
                    <button
                      type="button"
                      onClick={() => preguntar(ejemplo)}
                      className="w-full rounded-md border border-linea bg-papel px-3.5 py-2.5 text-left text-sm text-tinta transition-colors hover:border-acento hover:text-acento"
                    >
                      {ejemplo}
                    </button>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>

        <div className="border-t border-linea p-4">
          <label htmlFor="pedido-ayuda" className="em-rotulo mb-1.5 block">
            Tu pedido
          </label>
          <textarea
            id="pedido-ayuda"
            value={texto}
            onChange={(evento) => setTexto(evento.target.value)}
            onKeyDown={(evento) => {
              if (evento.key === "Enter" && !evento.shiftKey) {
                evento.preventDefault();
                preguntar(texto);
              }
            }}
            placeholder="Escribí acá…"
            className="h-20 w-full rounded-md border border-linea-fuerte bg-superficie px-3 py-2 text-sm outline-none transition-colors focus:border-acento"
          />
          <div className="mt-2 flex gap-2">
            <Boton className="flex-1" onClick={() => preguntar(texto)} disabled={!texto.trim()}>
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
      </aside>
    </div>
  );
}

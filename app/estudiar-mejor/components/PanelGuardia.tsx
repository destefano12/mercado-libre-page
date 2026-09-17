"use client";

import { useState } from "react";
import { armarConsignas, temaDelPedido, type ConsignasArmadas } from "../lib/consignas";
import { ETIQUETAS_INTENCION, responderComoGuia, type RespuestaGuardia } from "../lib/guardia";
import { useEstudiar } from "../lib/store";
import { normalizar } from "../lib/texto";
import { Icono } from "./iconos";
import { Boton, Nota, Pildora } from "./ui";

const EJEMPLOS = [
  "Hacéme preguntas de Biología sobre la fotosíntesis",
  "Resolveme el ejercicio 4",
  "No entiendo el ciclo de Calvin",
];

export function PanelGuardia({ abierto, onCerrar }: { abierto: boolean; onCerrar: () => void }) {
  const { estado } = useEstudiar();
  const [texto, setTexto] = useState("");
  const [respuesta, setRespuesta] = useState<RespuestaGuardia | null>(null);
  const [consignas, setConsignas] = useState<ConsignasArmadas | null>(null);

  if (!abierto) return null;

  /** Busca el tema entre los cargados: por nombre, por materia o al revés. */
  const buscarTema = (pedido: string) => {
    const plano = normalizar(pedido);
    return estado.temas.find((tema) => {
      const nombre = normalizar(tema.nombre);
      const materia = normalizar(tema.materia);
      return plano.includes(nombre) || (materia.length > 3 && plano.includes(materia)) || nombre.includes(plano);
    });
  };

  const preguntar = (pedido: string) => {
    const limpio = pedido.trim();
    if (!limpio) return;
    setTexto(limpio);

    const resultado = responderComoGuia(limpio);
    setRespuesta(resultado);

    if (resultado.intencion !== "pedir-preguntas") {
      setConsignas(null);
      return;
    }

    const tema = buscarTema(limpio);
    const nombre = tema?.nombre ?? temaDelPedido(limpio);

    if (!nombre) {
      setConsignas(null);
      return;
    }

    const material = tema
      ? estado.materiales
          .filter((archivo) => archivo.temaId === tema.id)
          .map((archivo) => archivo.texto)
          .join("\n")
      : "";

    setConsignas(armarConsignas(nombre, material));
  };

  const limpiar = () => {
    setRespuesta(null);
    setConsignas(null);
    setTexto("");
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
          {consignas ? (
            <div className="em-aparecer space-y-4">
              <Pildora tono="acento">{ETIQUETAS_INTENCION["pedir-preguntas"]}</Pildora>
              <h3 className="text-base text-tinta">Consignas de {consignas.tema}</h3>
              <Nota tono={consignas.origen === "material" ? "acento" : "atencion"}>{consignas.nota}</Nota>
              <ol className="space-y-2">
                {consignas.consignas.map((consigna, indice) => (
                  <li
                    key={consigna}
                    className="flex gap-3 border-l-2 border-acento-linea py-1 pl-3 text-sm leading-relaxed text-tinta"
                  >
                    <span className="em-cifra em-rotulo mt-0.5 text-acento">{indice + 1}</span>
                    <span>{consigna}</span>
                  </li>
                ))}
              </ol>
              <p className="border-t border-linea pt-3 text-sm italic leading-relaxed text-media">
                Resolvelas en la carpeta. Las respuestas las escribís vos: para eso están.
              </p>
            </div>
          ) : respuesta ? (
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
              <p className="text-sm leading-relaxed text-media">
                Pedime consignas de un tema y te armo una tanda para resolver en la carpeta. O contame qué te traba, y
                lo desarmamos con preguntas. Por ejemplo:
              </p>
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
              <Boton variante="fantasma" onClick={limpiar}>
                Limpiar
              </Boton>
            ) : null}
          </div>
        </div>
      </aside>
    </div>
  );
}

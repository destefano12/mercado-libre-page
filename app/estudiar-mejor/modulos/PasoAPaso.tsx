"use client";

import { useMemo, useState } from "react";
import { AvisoPrincipio, Area, Boton, Campo, Nota, Pildora, Tarjeta, TituloSeccion, Vacio } from "../components/ui";
import { Icono } from "../components/iconos";
import { armarProtocolo, revisarLoEscrito } from "../lib/pasoApaso";
import { useEstudiar } from "../lib/store";
import type { Desarmado } from "../lib/tipos";

const EJEMPLOS = [
  "Calculá la velocidad de un auto que recorre 120 km en 2 horas",
  "Justificá por qué la Revolución de Mayo fue un proceso y no un hecho aislado",
  "Analizá sintácticamente la oración del punto 3",
];

function FichaDesarmada({ desarmado }: { desarmado: Desarmado }) {
  const { estado, acciones } = useEstudiar();
  const protocolo = useMemo(() => armarProtocolo(desarmado.consigna, estado.anio || 1), [desarmado.consigna, estado.anio]);
  const [aviso, setAviso] = useState<Record<string, string | null>>({});

  const hechos = protocolo.pasos.filter(
    (paso) => (desarmado.respuestas[paso.id] ?? "").trim().length >= paso.minimo,
  ).length;
  const completo = hechos === protocolo.pasos.length;

  const escribir = (pasoId: string, texto: string) => {
    acciones.anotarPaso(desarmado.id, pasoId, texto);
    setAviso((previo) => ({ ...previo, [pasoId]: revisarLoEscrito(texto, desarmado.consigna) }));
  };

  const copiarPlan = async () => {
    const plan = [
      desarmado.consigna,
      "",
      ...protocolo.pasos.map((paso) => `${paso.titulo}: ${desarmado.respuestas[paso.id] ?? "—"}`),
    ].join("\n");
    try {
      await navigator.clipboard.writeText(plan);
    } catch {
      // Si el navegador no deja copiar, el plan está igual en pantalla.
    }
  };

  return (
    <Tarjeta>
      <div className="mb-4 flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="em-rotulo">Tu ejercicio</p>
          <h3 className="mt-1 text-lg font-semibold leading-snug text-tinta">{desarmado.consigna}</h3>
          <div className="mt-2 flex flex-wrap gap-2">
            {protocolo.materia ? <Pildora tono="acento">{protocolo.materia}</Pildora> : null}
            {protocolo.verbo ? <Pildora tono="atencion">Te piden: {protocolo.verbo.verbo.toLowerCase()}</Pildora> : null}
            <Pildora tono={completo ? "logro" : "neutro"}>
              {hechos} de {protocolo.pasos.length}
            </Pildora>
          </div>
        </div>
        <Boton variante="peligro" onClick={() => acciones.eliminarDesarmado(desarmado.id)}>
          Borrar
        </Boton>
      </div>

      {protocolo.verbo ? (
        <div className="mb-5 rounded-md border border-atencion-linea bg-atencion-tenue p-4">
          <p className="em-rotulo mb-1.5 text-atencion">Qué exige «{protocolo.verbo.verbo.toLowerCase()}»</p>
          <p className="text-sm leading-relaxed text-tinta">{protocolo.verbo.pide}</p>
          <p className="mt-2 text-sm leading-relaxed text-media">
            <span className="font-semibold">Error típico:</span> {protocolo.verbo.errorTipico}
          </p>
          <ul className="mt-2.5 space-y-1">
            {protocolo.verbo.seCompletaCuando.map((señal) => (
              <li key={señal} className="flex gap-2 text-sm leading-relaxed text-media">
                <span className="mt-2 h-1 w-1 shrink-0 rounded-full bg-atencion" />
                <span>{señal}</span>
              </li>
            ))}
          </ul>
        </div>
      ) : null}

      <ol className="space-y-4">
        {protocolo.pasos.map((paso, indice) => {
          const escrito = desarmado.respuestas[paso.id] ?? "";
          const listo = escrito.trim().length >= paso.minimo;
          const anterior = indice === 0 || (desarmado.respuestas[protocolo.pasos[indice - 1].id] ?? "").trim().length >= protocolo.pasos[indice - 1].minimo;

          return (
            <li key={paso.id} className={`rounded-md border p-4 transition-colors ${listo ? "border-logro-linea bg-logro-tenue" : "border-linea bg-superficie"}`}>
              <div className="mb-2 flex items-center gap-2.5">
                <span className={`grid h-7 w-7 shrink-0 place-items-center rounded-full text-sm font-semibold ${listo ? "bg-logro text-white" : "bg-acento-tenue text-acento-fuerte"}`}>
                  {listo ? <Icono nombre="check" tamaño={14} /> : indice + 1}
                </span>
                <p className="font-semibold text-tinta">{paso.titulo}</p>
              </div>

              <p className="mb-1 text-sm leading-relaxed text-tinta">{paso.pide}</p>
              <p className="mb-2.5 text-xs leading-relaxed text-tenue">{paso.ayuda}</p>

              <Area
                etiqueta=""
                value={escrito}
                onChange={(evento) => escribir(paso.id, evento.target.value)}
                placeholder={anterior ? "Escribí acá…" : "Primero completá el paso de arriba."}
                disabled={!anterior}
              />

              {aviso[paso.id] ? <p className="mt-1.5 text-sm font-medium text-atencion">{aviso[paso.id]}</p> : null}
            </li>
          );
        })}
      </ol>

      <div className="mt-5 rounded-md border border-linea bg-papel p-4">
        <p className="em-rotulo mb-2">Cuando lo resuelvas, controlalo así</p>
        <ul className="space-y-1.5">
          {protocolo.verificacion.map((forma) => (
            <li key={forma} className="flex gap-2 text-sm leading-relaxed text-media">
              <span className="mt-2 h-1 w-1 shrink-0 rounded-full bg-acento" />
              <span>{forma}</span>
            </li>
          ))}
        </ul>
      </div>

      <div className="mt-4 flex flex-wrap gap-2">
        <Boton variante={desarmado.resuelto ? "secundario" : "primario"} icono="check" onClick={() => acciones.marcarResuelto(desarmado.id)}>
          {desarmado.resuelto ? "Marcado como resuelto" : "Ya lo resolví"}
        </Boton>
        <Boton variante="secundario" icono="copiar" onClick={() => void copiarPlan()} disabled={hechos === 0}>
          Copiar mi plan
        </Boton>
      </div>

      {completo ? (
        <p className="mt-4 rounded-md bg-logro-tenue px-4 py-3 text-sm font-semibold leading-relaxed text-logro">
          Ahí tenés tu procedimiento, escrito por vos. Eso es lo que llevás a la carpeta: ya no estás mirando la
          consigna sin saber por dónde empezar.
        </p>
      ) : null}
    </Tarjeta>
  );
}

export function PasoAPaso() {
  const { estado, acciones } = useEstudiar();
  const [consigna, setConsigna] = useState("");

  const empezar = (texto: string) => {
    const limpio = texto.trim();
    if (limpio.length < 8) return;
    acciones.desarmarEjercicio(limpio);
    setConsigna("");
  };

  return (
    <div className="space-y-6">
      <Tarjeta>
        <TituloSeccion
          icono="explicame"
          titulo="Paso a paso"
          bajada="Pegá la consigna que no sabés por dónde agarrar. No te la resuelvo: te hago las preguntas que hay que hacerse, en orden, y las contestás vos. Al final te queda tu propio procedimiento escrito."
        />

        <Campo
          etiqueta="La consigna, tal como está en la carpeta"
          placeholder="Ej: Justificá por qué el agua es un recurso estratégico"
          value={consigna}
          onChange={(evento) => setConsigna(evento.target.value)}
          onKeyDown={(evento) => {
            if (evento.key === "Enter") empezar(consigna);
          }}
          ayuda="Copiala entera, con el verbo y todo: de ahí saco qué te están pidiendo en realidad."
        />

        <Boton className="mt-4" icono="explicame" onClick={() => empezar(consigna)} disabled={consigna.trim().length < 8}>
          Desarmar el ejercicio
        </Boton>

        <div className="mt-4">
          <p className="em-rotulo mb-2">O probá con uno de estos</p>
          <ul className="flex flex-wrap gap-2">
            {EJEMPLOS.map((ejemplo) => (
              <li key={ejemplo}>
                <button
                  type="button"
                  onClick={() => empezar(ejemplo)}
                  className="rounded-full border border-linea bg-papel px-3.5 py-1.5 text-left text-sm text-media transition-colors hover:border-acento hover:text-acento"
                >
                  {ejemplo}
                </button>
              </li>
            ))}
          </ul>
        </div>

        <AvisoPrincipio texto="Las preguntas son sobre tu ejercicio, que sólo tenés vos. Por eso ninguna respuesta puede venir de acá." />
      </Tarjeta>

      {estado.desarmados.length === 0 ? (
        <Vacio
          icono="explicame"
          titulo="Todavía no desarmaste ninguno"
          texto="La próxima vez que te trabes con una consigna, pegala acá antes de mirar el celular."
        />
      ) : (
        estado.desarmados.map((desarmado) => <FichaDesarmada key={desarmado.id} desarmado={desarmado} />)
      )}

      {estado.desarmados.length > 0 ? (
        <Nota tono="neutro">
          Cada ejercicio que desarmás queda guardado. Volvé a mirarlos antes de una prueba: las preguntas se repiten
          más de lo que parece, y ahí tenés escrito cómo las agarraste la vez pasada.
        </Nota>
      ) : null}
    </div>
  );
}

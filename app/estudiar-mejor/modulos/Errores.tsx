"use client";

import { useState } from "react";
import { Area, AvisoPrincipio, Boton, Campo, Dato, Pildora, Selector, Tarjeta, TituloSeccion, Vacio } from "../components/ui";
import { cuandoEs } from "../lib/fechas";
import { useEstudiar } from "../lib/store";
import { preguntaDeError } from "../lib/tutor";
import type { CausaError } from "../lib/tipos";

const CAUSAS: { valor: CausaError; nombre: string; consejo: string }[] = [
  { valor: "no-entendi", nombre: "No entendí el concepto", consejo: "Volvé al material, no a la fórmula." },
  { valor: "distraccion", nombre: "Me distraje", consejo: "Probá pomodoros más cortos." },
  { valor: "consigna", nombre: "Leí mal la consigna", consejo: "Subrayá el verbo de la consigna antes de arrancar." },
  { valor: "tiempo", nombre: "Me quedé sin tiempo", consejo: "Cronometrá la práctica, no sólo el examen." },
  { valor: "calculo", nombre: "Error de cálculo", consejo: "Rehacé el paso en voz alta, no mentalmente." },
  { valor: "memoria", nombre: "Me lo olvidé", consejo: "Eso se arregla con repaso espaciado, no con releer." },
];

export function Errores() {
  const { estado, acciones } = useEstudiar();
  const [temaId, setTemaId] = useState("");
  const [titulo, setTitulo] = useState("");
  const [detalle, setDetalle] = useState("");
  const [causa, setCausa] = useState<CausaError>("no-entendi");
  const [verResueltos, setVerResueltos] = useState(false);

  const tema = estado.temas.find((candidato) => candidato.id === temaId) ?? estado.temas[0];
  const visibles = estado.errores
    .filter((error) => (verResueltos ? true : !error.resuelto))
    .sort((a, b) => b.veces - a.veces || b.ultimaVez.localeCompare(a.ultimaVez));

  const abiertos = estado.errores.filter((error) => !error.resuelto);
  const reincidentes = abiertos.filter((error) => error.veces >= 2);

  const guardar = () => {
    if (!tema || !titulo.trim()) return;
    acciones.registrarError({ temaId: tema.id, titulo: titulo.trim(), detalle: detalle.trim(), causa, origen: "manual" });
    setTitulo("");
    setDetalle("");
  };

  return (
    <div className="space-y-6">
      <Tarjeta>
        <TituloSeccion
          icono="🧾"
          titulo="Registro de errores frecuentes"
          bajada="Cada error que anotás vuelve a aparecer en tus repasos hasta que deje de ser un error. Esa es toda la magia."
        />

        <div className="mb-5 grid gap-3 sm:grid-cols-3">
          <Dato valor={`${abiertos.length}`} etiqueta="Errores abiertos" icono="🔴" />
          <Dato valor={`${reincidentes.length}`} etiqueta="Se repiten 2+ veces" icono="🔁" />
          <Dato valor={`${estado.errores.filter((error) => error.resuelto).length}`} etiqueta="Ya resueltos" icono="🟢" />
        </div>

        {estado.temas.length === 0 ? (
          <Vacio icono="📚" titulo="Necesitás al menos un tema" texto="Los errores se anotan asociados a un tema para poder reinyectarlos." />
        ) : (
          <div className="space-y-4">
            <div className="grid gap-4 sm:grid-cols-2">
              <Selector etiqueta="Tema" value={tema?.id ?? ""} onChange={(evento) => setTemaId(evento.target.value)}>
                {estado.temas.map((candidato) => (
                  <option key={candidato.id} value={candidato.id}>
                    {candidato.nombre} · {candidato.materia}
                  </option>
                ))}
              </Selector>
              <Selector etiqueta="¿Por qué te pasó?" value={causa} onChange={(evento) => setCausa(evento.target.value as CausaError)}>
                {CAUSAS.map((opcion) => (
                  <option key={opcion.valor} value={opcion.valor}>
                    {opcion.nombre}
                  </option>
                ))}
              </Selector>
            </div>

            <Campo
              etiqueta="¿Qué error cometiste?"
              placeholder="Ej: confundo causas con consecuencias"
              value={titulo}
              onChange={(evento) => setTitulo(evento.target.value)}
            />
            <Area
              etiqueta="Detalle (opcional)"
              placeholder="Ej: puse el crecimiento de las ciudades como causa cuando es consecuencia"
              value={detalle}
              onChange={(evento) => setDetalle(evento.target.value)}
              className="[&_textarea]:min-h-20"
            />

            <div className="flex flex-wrap items-center gap-3">
              <Boton onClick={guardar} disabled={!titulo.trim()}>
                Anotar error
              </Boton>
              <span className="text-xs text-slate-400">
                {CAUSAS.find((opcion) => opcion.valor === causa)?.consejo}
              </span>
            </div>
          </div>
        )}

        <AvisoPrincipio texto="Anotar el error no es castigarte: es la forma más rápida de que deje de repetirse." />
      </Tarjeta>

      <Tarjeta retraso={70}>
        <TituloSeccion
          icono="📌"
          titulo="Tus errores"
          accion={
            <Boton variante="secundario" onClick={() => setVerResueltos((previo) => !previo)}>
              {verResueltos ? "Ver sólo abiertos" : "Ver también resueltos"}
            </Boton>
          }
        />

        {visibles.length === 0 ? (
          <Vacio icono="✨" titulo="No hay errores registrados" texto="Van a ir apareciendo solos cuando falles en el tutor o en un simulacro." />
        ) : (
          <ul className="space-y-3">
            {visibles.map((error, indice) => {
              const temaDelError = estado.temas.find((candidato) => candidato.id === error.temaId);
              const causaInfo = CAUSAS.find((opcion) => opcion.valor === error.causa);

              return (
                <li
                  key={error.id}
                  className={`em-aparecer rounded-2xl border p-4 ${error.resuelto ? "border-emerald-200 bg-emerald-50/50" : "border-slate-200 bg-white"}`}
                  style={{ animationDelay: `${indice * 50}ms` }}
                >
                  <div className="flex flex-wrap items-start justify-between gap-2">
                    <div className="min-w-0 flex-1">
                      <p className={`text-sm font-extrabold ${error.resuelto ? "text-emerald-800 line-through" : "text-slate-900"}`}>
                        {error.titulo}
                      </p>
                      {error.detalle ? <p className="mt-1 text-sm text-slate-500">{error.detalle}</p> : null}
                    </div>
                    <div className="flex shrink-0 gap-2">
                      <Boton variante={error.resuelto ? "fantasma" : "exito"} onClick={() => acciones.alternarError(error.id)}>
                        {error.resuelto ? "Reabrir" : "Ya lo tengo"}
                      </Boton>
                      <Boton variante="fantasma" onClick={() => acciones.eliminarError(error.id)}>
                        ✕
                      </Boton>
                    </div>
                  </div>

                  <div className="mt-2 flex flex-wrap gap-2">
                    <Pildora tono="indigo">{temaDelError?.nombre ?? "Sin tema"}</Pildora>
                    <Pildora tono="amber">{causaInfo?.nombre ?? error.causa}</Pildora>
                    <Pildora tono={error.veces >= 3 ? "rose" : "slate"}>×{error.veces}</Pildora>
                    <Pildora tono="slate">visto {cuandoEs(error.ultimaVez)}</Pildora>
                    <Pildora tono="violet">desde {error.origen}</Pildora>
                  </div>

                  {!error.resuelto ? (
                    <p className="mt-3 rounded-2xl bg-indigo-50 px-4 py-2.5 text-sm font-semibold text-indigo-800">
                      🔁 {preguntaDeError(error)}
                    </p>
                  ) : null}
                </li>
              );
            })}
          </ul>
        )}
      </Tarjeta>
    </div>
  );
}

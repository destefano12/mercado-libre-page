"use client";

import { useCallback, useEffect, useState } from "react";
import { Area, AvisoPrincipio, Barra, Boton, Dato, Pildora, Selector, Tarjeta, TituloSeccion, Vacio } from "../components/ui";
import { relojMmSs } from "../lib/fechas";
import { agruparPorFoco, corregirItem, generarItems, type CorreccionPorFoco } from "../lib/simulacro";
import { useEstudiar } from "../lib/store";
import { contarPalabras } from "../lib/texto";
import type { ItemSimulacro, RespuestaItem } from "../lib/tipos";

type Fase = "config" | "curso" | "correccion";

const NOMBRE_TIPO: Record<ItemSimulacro["tipo"], string> = {
  multiple: "Multiple choice",
  vf: "Verdadero o falso",
  completar: "Completar",
  desarrollo: "Desarrollo",
};

export function Simulador() {
  const { estado, acciones } = useEstudiar();
  const [fase, setFase] = useState<Fase>("config");
  const [temaId, setTemaId] = useState("");
  const [cantidad, setCantidad] = useState(8);
  const [duracion, setDuracion] = useState(20);
  const [items, setItems] = useState<ItemSimulacro[]>([]);
  const [respuestas, setRespuestas] = useState<Record<string, string>>({});
  const [criterios, setCriterios] = useState<Record<string, string[]>>({});
  const [segundos, setSegundos] = useState(0);
  const [corregidas, setCorregidas] = useState<RespuestaItem[]>([]);
  const [aviso, setAviso] = useState<string | null>(null);

  const tema = estado.temas.find((candidato) => candidato.id === temaId) ?? estado.temas[0];
  const materiales = estado.materiales.filter((material) => material.temaId === tema?.id);

  const entregar = useCallback(() => {
    const resultado = items.map((item) => corregirItem(item, respuestas[item.id] ?? "", criterios[item.id] ?? []));
    const correctas = resultado.filter((respuesta) => respuesta.correcta).length;
    const usadoSeg = duracion * 60 - segundos;

    setCorregidas(resultado);
    setFase("correccion");

    if (!tema) return;
    acciones.guardarSimulacro({
      temaId: tema.id,
      duracionMin: duracion,
      usadoSeg,
      items,
      respuestas: resultado,
      correctas,
      total: items.length,
    });
    acciones.registrarEvidencia(tema.id, correctas, items.length);
    acciones.registrarLog({ minutos: Math.max(1, Math.round(usadoSeg / 60)), tipo: "simulacro", temaId: tema.id });

    items.forEach((item, indice) => {
      const respuesta = resultado[indice];
      if (respuesta.correcta) return;
      acciones.registrarError({
        temaId: tema.id,
        titulo: `Fallé en “${item.foco}” (${NOMBRE_TIPO[item.tipo].toLowerCase()})`,
        detalle: item.enunciado,
        causa: respuesta.valor.trim() === "" ? "tiempo" : item.tipo === "completar" ? "memoria" : "no-entendi",
        origen: "simulacro",
      });
    });
  }, [acciones, criterios, duracion, items, respuestas, segundos, tema]);

  useEffect(() => {
    if (fase !== "curso" || segundos <= 0) return undefined;
    const temporizador = window.setTimeout(() => {
      // Cuando se acaba el tiempo, la prueba se entrega sola.
      if (segundos <= 1) entregar();
      else setSegundos(segundos - 1);
    }, 1000);
    return () => window.clearTimeout(temporizador);
  }, [fase, segundos, entregar]);

  const arrancar = () => {
    if (!tema || materiales.length === 0) {
      setAviso("Para armar una prueba necesito material cargado de este tema. Subilo en el tutor socrático.");
      return;
    }
    const focosPrioritarios = estado.errores
      .filter((error) => error.temaId === tema.id && !error.resuelto)
      .map((error) => error.titulo);

    const generados = generarItems({ temaId: tema.id, materiales, cantidad, duracionMin: duracion, focosPrioritarios });

    if (generados.length < 3) {
      setAviso("Tu material es muy corto o muy esquemático: no me alcanza para una prueba decente. Cargá un texto más explicativo.");
      return;
    }

    setItems(generados);
    setRespuestas({});
    setCriterios({});
    setSegundos(duracion * 60);
    setCorregidas([]);
    setAviso(null);
    setFase("curso");
  };

  const grupos: CorreccionPorFoco[] = fase === "correccion" ? agruparPorFoco(items, corregidas) : [];
  const correctas = corregidas.filter((respuesta) => respuesta.correcta).length;
  const respondidas = items.filter((item) => (respuestas[item.id] ?? "").trim() !== "").length;

  if (fase === "curso") {
    const progresoTiempo = ((duracion * 60 - segundos) / Math.max(1, duracion * 60)) * 100;
    const apurado = segundos <= 120;

    return (
      <div className="space-y-4">
        <div className="sticky top-2 z-20 rounded-3xl border border-slate-200 bg-white/95 p-4 shadow-lg backdrop-blur">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <p className="text-xs font-bold uppercase tracking-wide text-slate-500">Simulacro de {tema?.nombre}</p>
              <p className={`text-3xl font-black tabular-nums ${apurado ? "em-latido text-rose-600" : "text-slate-900"}`}>
                {relojMmSs(segundos)}
              </p>
            </div>
            <div className="text-right">
              <p className="text-sm font-bold text-slate-600">
                {respondidas}/{items.length} respondidas
              </p>
              <Boton variante="exito" className="mt-1" onClick={entregar}>
                Entregar y corregir
              </Boton>
            </div>
          </div>
          <div className="mt-3">
            <Barra valor={progresoTiempo} tono={apurado ? "rose" : "indigo"} />
          </div>
        </div>

        {items.map((item, indice) => (
          <Tarjeta key={item.id} animada={false}>
            <div className="mb-3 flex flex-wrap items-center gap-2">
              <span className="grid h-7 w-7 place-items-center rounded-full bg-slate-900 text-xs font-black text-white">
                {indice + 1}
              </span>
              <Pildora tono="indigo">{NOMBRE_TIPO[item.tipo]}</Pildora>
            </div>

            <p className="text-base font-bold leading-snug text-slate-900">{item.enunciado}</p>

            {item.opciones ? (
              <div className="mt-3 space-y-2">
                {item.opciones.map((opcion) => {
                  const elegida = respuestas[item.id] === opcion.id;
                  return (
                    <label
                      key={opcion.id}
                      className={`flex cursor-pointer items-start gap-3 rounded-2xl border px-4 py-3 text-sm transition ${
                        elegida ? "border-indigo-400 bg-indigo-50 font-bold text-indigo-900" : "border-slate-200 hover:bg-slate-50"
                      }`}
                    >
                      <input
                        type="radio"
                        name={item.id}
                        checked={elegida}
                        onChange={() => setRespuestas((previo) => ({ ...previo, [item.id]: opcion.id }))}
                        className="mt-0.5 h-4 w-4 accent-indigo-600"
                      />
                      <span>{opcion.texto}</span>
                    </label>
                  );
                })}
              </div>
            ) : item.tipo === "completar" ? (
              <input
                value={respuestas[item.id] ?? ""}
                onChange={(evento) => setRespuestas((previo) => ({ ...previo, [item.id]: evento.target.value }))}
                placeholder="Escribí el término que falta"
                className="mt-3 w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 py-2.5 text-sm outline-none transition focus:border-indigo-400 focus:bg-white"
              />
            ) : (
              <div className="mt-3 space-y-3">
                <Area
                  etiqueta="Tu desarrollo"
                  placeholder="Escribí como si lo entregaras: qué es, por qué, ejemplo propio y conclusión."
                  value={respuestas[item.id] ?? ""}
                  onChange={(evento) => setRespuestas((previo) => ({ ...previo, [item.id]: evento.target.value }))}
                  ayuda={`${contarPalabras(respuestas[item.id] ?? "")} palabras`}
                />
                <div>
                  <p className="mb-1.5 text-xs font-bold uppercase tracking-wide text-slate-500">Antes de entregar, chequeá:</p>
                  <div className="space-y-1.5">
                    {(item.criterios ?? []).map((criterio) => {
                      const marcados = criterios[item.id] ?? [];
                      const activo = marcados.includes(criterio);
                      return (
                        <label key={criterio} className="flex cursor-pointer items-center gap-2 text-sm text-slate-600">
                          <input
                            type="checkbox"
                            checked={activo}
                            onChange={() =>
                              setCriterios((previo) => ({
                                ...previo,
                                [item.id]: activo ? marcados.filter((valor) => valor !== criterio) : [...marcados, criterio],
                              }))
                            }
                            className="h-4 w-4 accent-indigo-600"
                          />
                          {criterio}
                        </label>
                      );
                    })}
                  </div>
                </div>
              </div>
            )}
          </Tarjeta>
        ))}

        <Boton variante="exito" className="w-full py-3" onClick={entregar}>
          Entregar y ver la corrección
        </Boton>
      </div>
    );
  }

  if (fase === "correccion") {
    const porcentaje = items.length === 0 ? 0 : Math.round((correctas / items.length) * 100);

    return (
      <div className="space-y-6">
        <Tarjeta>
          <TituloSeccion icono="🧪" titulo="Corrección explicada" bajada="Tema por tema, qué salió bien, qué no y por qué. Esto corrige tu práctica: no resuelve tu tarea." />

          <div className="grid gap-3 sm:grid-cols-3">
            <Dato valor={`${correctas}/${items.length}`} etiqueta="Respuestas correctas" icono="✅" />
            <Dato valor={`${porcentaje}%`} etiqueta="Desempeño en la práctica" icono="📊" />
            <Dato valor={relojMmSs(duracion * 60 - segundos)} etiqueta="Tiempo usado" icono="⏱️" />
          </div>

          <div className="mt-4">
            <Barra valor={porcentaje} tono={porcentaje >= 80 ? "emerald" : porcentaje >= 50 ? "amber" : "rose"} alto="h-3" />
          </div>

          <p className="mt-4 rounded-2xl bg-indigo-50 px-4 py-3 text-sm font-semibold text-indigo-900">
            {porcentaje >= 80
              ? "Muy bien. Ahora la prueba de fuego: explicá los temas que fallaste sin mirar nada."
              : porcentaje >= 50
                ? "Vas por buen camino. Los temas de abajo, en rojo, son los que hay que atacar primero."
                : "No te asustes con el número: esto es una práctica, y acaba de mostrarte exactamente qué estudiar."}
          </p>

          <div className="mt-4 flex flex-wrap gap-2">
            <Boton onClick={() => setFase("config")}>Armar otra prueba</Boton>
          </div>
        </Tarjeta>

        {grupos.map((grupo, indice) => {
          const logrado = Math.round((grupo.correctas / grupo.total) * 100);
          return (
            <Tarjeta key={grupo.foco} retraso={indice * 60}>
              <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
                <h3 className="text-lg font-extrabold capitalize text-slate-900">{grupo.foco}</h3>
                <Pildora tono={logrado >= 80 ? "emerald" : logrado >= 50 ? "amber" : "rose"}>
                  {grupo.correctas}/{grupo.total} correctas
                </Pildora>
              </div>
              <Barra valor={logrado} tono={logrado >= 80 ? "emerald" : logrado >= 50 ? "amber" : "rose"} />

              <ul className="mt-4 space-y-3">
                {grupo.detalles.map((detalle) => (
                  <li
                    key={detalle.item.id}
                    className={`rounded-2xl border p-4 ${detalle.respuesta.correcta ? "border-emerald-200 bg-emerald-50/50" : "border-rose-200 bg-rose-50/40"}`}
                  >
                    <div className="mb-1.5 flex flex-wrap items-center gap-2">
                      <span aria-hidden>{detalle.respuesta.correcta ? "✅" : "❌"}</span>
                      <Pildora tono="slate">{NOMBRE_TIPO[detalle.item.tipo]}</Pildora>
                    </div>
                    <p className="text-sm font-bold text-slate-900">{detalle.item.enunciado}</p>
                    <p className="mt-2 text-sm text-slate-700">{detalle.explicacion}</p>
                    <p className="mt-2 text-sm font-semibold text-indigo-800">💡 {detalle.sugerencia}</p>
                  </li>
                ))}
              </ul>
            </Tarjeta>
          );
        })}

        <Tarjeta>
          <p className="text-sm text-slate-600">
            Los temas que fallaste ya se cargaron en tu <strong>registro de errores</strong> y actualizaron tu{" "}
            <strong>mapa de dominio</strong>. Van a volver a aparecer en tus repasos hasta que dejen de fallar.
          </p>
        </Tarjeta>
      </div>
    );
  }

  return (
    <Tarjeta>
      <TituloSeccion
        icono="⏱️"
        titulo="Simulador de evaluación"
        bajada="Armo una prueba parecida a la que te tomaría un docente, con tu material y con tiempo cronometrado. Al final, corrección explicada."
      />

      {estado.temas.length === 0 || estado.materiales.length === 0 ? (
        <Vacio
          icono="📄"
          titulo="Necesito material tuyo"
          texto="Cargá un apunte en el tutor socrático y desde ahí te armo la prueba: las preguntas salen de tu material, no de internet."
        />
      ) : (
        <div className="space-y-4">
          <Selector etiqueta="Tema a evaluar" value={tema?.id ?? ""} onChange={(evento) => setTemaId(evento.target.value)}>
            {estado.temas.map((candidato) => (
              <option key={candidato.id} value={candidato.id}>
                {candidato.nombre} · {candidato.materia}
              </option>
            ))}
          </Selector>

          <p className="text-sm text-slate-500">
            {materiales.length > 0
              ? `${materiales.length} material${materiales.length === 1 ? "" : "es"} cargado${materiales.length === 1 ? "" : "s"} para este tema.`
              : "Este tema no tiene material cargado todavía."}
          </p>

          <div className="grid gap-4 sm:grid-cols-2">
            <label className="block">
              <span className="mb-1.5 block text-xs font-bold uppercase tracking-wide text-slate-500">Cantidad de consignas: {cantidad}</span>
              <input type="range" min={4} max={16} value={cantidad} onChange={(evento) => setCantidad(Number(evento.target.value))} className="w-full accent-indigo-600" />
            </label>
            <label className="block">
              <span className="mb-1.5 block text-xs font-bold uppercase tracking-wide text-slate-500">Duración: {duracion} min</span>
              <input type="range" min={5} max={90} step={5} value={duracion} onChange={(evento) => setDuracion(Number(evento.target.value))} className="w-full accent-indigo-600" />
            </label>
          </div>

          {aviso ? <p className="rounded-2xl bg-amber-50 px-4 py-3 text-sm font-semibold text-amber-800">{aviso}</p> : null}

          <Boton onClick={arrancar}>Empezar la prueba</Boton>

          <ul className="space-y-1.5 text-sm text-slate-500">
            <li>• Vas a tener multiple choice, verdadero o falso, completar y desarrollo.</li>
            <li>• Cuando se acaba el tiempo, se entrega sola: así aprendés a administrarlo.</li>
            <li>• Las consignas priorizan los temas donde ya venías fallando.</li>
          </ul>
        </div>
      )}

      {estado.simulacros.length > 0 ? (
        <div className="mt-6 border-t border-slate-200 pt-5">
          <h3 className="mb-3 text-sm font-bold uppercase tracking-wide text-slate-500">Tus simulacros anteriores</h3>
          <ul className="space-y-2">
            {estado.simulacros.slice(0, 5).map((simulacro) => {
              const temaDelSimulacro = estado.temas.find((candidato) => candidato.id === simulacro.temaId);
              const logrado = Math.round((simulacro.correctas / Math.max(1, simulacro.total)) * 100);
              return (
                <li key={simulacro.id} className="flex flex-wrap items-center justify-between gap-2 rounded-2xl border border-slate-200 px-4 py-3">
                  <span className="text-sm font-bold text-slate-700">
                    {temaDelSimulacro?.nombre ?? "Tema borrado"} · {new Date(simulacro.creadoEn).toLocaleDateString("es-AR")}
                  </span>
                  <Pildora tono={logrado >= 80 ? "emerald" : logrado >= 50 ? "amber" : "rose"}>
                    {simulacro.correctas}/{simulacro.total} · {relojMmSs(simulacro.usadoSeg)}
                  </Pildora>
                </li>
              );
            })}
          </ul>
        </div>
      ) : null}

      <AvisoPrincipio texto="El simulacro es práctica tuya: yo armo las consignas y te muestro dónde se cortó el razonamiento. Las respuestas del examen real las vas a escribir vos." />
    </Tarjeta>
  );
}

"use client";

import { FormularioTema } from "../components/FormularioTema";
import { AvisoPrincipio, Barra, Boton, Pildora, Tarjeta, TituloSeccion, Vacio } from "../components/ui";
import { cuandoEs } from "../lib/fechas";
import { COLORES_DOMINIO, nivelDominio, porcentajeDominio } from "../lib/metricas";
import { useEstudiar } from "../lib/store";
import type { NivelDominio } from "../lib/tipos";

const ORDEN: NivelDominio[] = ["rojo", "amarillo", "verde", "sin-datos"];

export function MapaDominio() {
  const { estado, acciones } = useEstudiar();

  const temas = [...estado.temas].sort((a, b) => {
    const nivelA = ORDEN.indexOf(nivelDominio(estado.dominio[a.id]));
    const nivelB = ORDEN.indexOf(nivelDominio(estado.dominio[b.id]));
    return nivelA - nivelB;
  });

  const conteo = ORDEN.reduce<Record<NivelDominio, number>>(
    (acumulado, nivel) => {
      acumulado[nivel] = estado.temas.filter((tema) => nivelDominio(estado.dominio[tema.id]) === nivel).length;
      return acumulado;
    },
    { rojo: 0, amarillo: 0, verde: 0, "sin-datos": 0 },
  );

  return (
    <div className="space-y-6">
      <Tarjeta>
        <TituloSeccion
          icono="🚦"
          titulo="Mapa de dominio"
          bajada="Un semáforo por tema, armado con lo que hiciste: preguntas del tutor, explicaciones y simulacros. No es una nota."
        />

        <div className="mb-5 flex flex-wrap gap-2">
          {ORDEN.map((nivel) => (
            <Pildora key={nivel} tono={nivel === "rojo" ? "rose" : nivel === "amarillo" ? "amber" : nivel === "verde" ? "emerald" : "slate"}>
              <span className={`h-2 w-2 rounded-full ${COLORES_DOMINIO[nivel].punto}`} />
              {COLORES_DOMINIO[nivel].etiqueta}: {conteo[nivel]}
            </Pildora>
          ))}
        </div>

        {temas.length === 0 ? (
          <div className="space-y-4">
            <Vacio icono="🗺️" titulo="El mapa está vacío" texto="Cargá tus temas y el semáforo se va pintando solo a medida que estudiás." />
            <FormularioTema />
          </div>
        ) : (
          <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
            {temas.map((tema, indice) => {
              const evidencia = estado.dominio[tema.id];
              const nivel = nivelDominio(evidencia);
              const porcentaje = porcentajeDominio(evidencia);
              const colores = COLORES_DOMINIO[nivel];
              const erroresAbiertos = estado.errores.filter((error) => error.temaId === tema.id && !error.resuelto).length;

              return (
                <article
                  key={tema.id}
                  className={`em-aparecer rounded-3xl border p-4 transition-transform duration-200 hover:-translate-y-1 ${colores.borde} ${colores.fondo}`}
                  style={{ animationDelay: `${indice * 60}ms` }}
                >
                  <div className="mb-2 flex items-start justify-between gap-2">
                    <div className="min-w-0">
                      <h3 className="truncate text-base font-extrabold text-slate-900">{tema.nombre}</h3>
                      <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">{tema.materia}</p>
                    </div>
                    <span className={`mt-1 h-3.5 w-3.5 shrink-0 rounded-full ${colores.punto} ${nivel === "rojo" ? "em-latido" : ""}`} />
                  </div>

                  <p className={`text-sm font-bold ${colores.texto}`}>{colores.etiqueta}</p>

                  <div className="mt-3">
                    <Barra
                      valor={porcentaje ?? 0}
                      tono={nivel === "verde" ? "emerald" : nivel === "amarillo" ? "amber" : nivel === "rojo" ? "rose" : "slate"}
                    />
                  </div>

                  <dl className="mt-3 space-y-1 text-xs text-slate-500">
                    <div className="flex justify-between">
                      <dt>Evidencias registradas</dt>
                      <dd className="font-bold text-slate-700">{evidencia?.intentos ?? 0}</dd>
                    </div>
                    <div className="flex justify-between">
                      <dt>Errores abiertos</dt>
                      <dd className={`font-bold ${erroresAbiertos > 0 ? "text-rose-600" : "text-slate-700"}`}>{erroresAbiertos}</dd>
                    </div>
                    <div className="flex justify-between">
                      <dt>Última actualización</dt>
                      <dd className="font-bold text-slate-700">{evidencia ? cuandoEs(evidencia.actualizado) : "—"}</dd>
                    </div>
                  </dl>

                  <p className="mt-3 text-xs italic text-slate-500">
                    {nivel === "verde"
                      ? "Sostenelo con un repaso corto cada tanto."
                      : nivel === "amarillo"
                        ? "Te falta poder explicarlo sin ayuda. Probá el modo Explicámelo vos."
                        : nivel === "rojo"
                          ? "Empezá de nuevo desde el material: no es falta de memoria, es falta de comprensión."
                          : "Todavía no hiciste nada de este tema: hacé una tanda de preguntas para empezar a medirlo."}
                  </p>

                  <Boton variante="fantasma" className="mt-2 px-2 text-xs" onClick={() => acciones.eliminarTema(tema.id)}>
                    Eliminar tema
                  </Boton>
                </article>
              );
            })}
          </div>
        )}

        <AvisoPrincipio texto="Los colores miden proceso, no talento. Un tema en rojo no dice que no puedas: dice por dónde seguir." />
      </Tarjeta>

      {estado.temas.length > 0 ? <FormularioTema /> : null}
    </div>
  );
}

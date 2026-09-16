"use client";

import { useState } from "react";
import { Area, AvisoPrincipio, Barra, Boton, Dato, Nota, Pildora, Selector, Tarjeta, TituloSeccion, Vacio, type Tono } from "../components/ui";
import { Icono } from "../components/iconos";
import { revisarExplicacion, type DiagnosticoExplicacion } from "../lib/explicame";
import { useEstudiar } from "../lib/store";
import { contarPalabras } from "../lib/texto";
import type { HuecoRazonamiento } from "../lib/tipos";

const TONOS_GRAVEDAD: Record<HuecoRazonamiento["gravedad"], Tono> = { alta: "alerta", media: "atencion", baja: "neutro" };

export function Explicame() {
  const { estado, acciones } = useEstudiar();
  const [temaId, setTemaId] = useState("");
  const [texto, setTexto] = useState("");
  const [diagnostico, setDiagnostico] = useState<DiagnosticoExplicacion | null>(null);

  const tema = estado.temas.find((candidato) => candidato.id === temaId) ?? estado.temas[0];
  const materialDelTema = estado.materiales
    .filter((material) => material.temaId === tema?.id)
    .map((material) => material.texto)
    .join("\n");

  const revisar = () => {
    if (!tema || contarPalabras(texto) < 15) return;
    const resultado = revisarExplicacion(texto, materialDelTema, tema.nombre);
    setDiagnostico(resultado);
    acciones.guardarExplicacion({
      temaId: tema.id,
      texto,
      cobertura: resultado.cobertura,
      ideasFaltantes: resultado.ideasFaltantes,
      huecos: resultado.huecos,
    });
    acciones.registrarEvidencia(tema.id, resultado.aciertos, resultado.intentos);
    acciones.registrarLog({ minutos: 10, tipo: "explicacion", temaId: tema.id });
  };

  const guardarComoError = (titulo: string) => {
    if (!tema) return;
    acciones.registrarError({
      temaId: tema.id,
      titulo,
      detalle: "Detectado al explicar el tema con mis palabras.",
      causa: "no-entendi",
      origen: "explicacion",
    });
  };

  const historial = estado.explicaciones.filter((explicacion) => explicacion.temaId === tema?.id).slice(0, 5);

  return (
    <div className="space-y-6">
      <Tarjeta>
        <TituloSeccion
          icono="explicame"
          titulo="Explicámelo vos"
          bajada="Explicá el tema como si me lo estuvieras enseñando. Yo no te corrijo el contenido: te marco dónde se corta tu razonamiento."
        />

        {estado.temas.length === 0 ? (
          <Vacio icono="archivo" titulo="Necesitás un tema cargado" texto="Creá un tema en el planificador o en el tutor y volvé." />
        ) : (
          <div className="space-y-4">
            <Selector etiqueta="¿Qué tema vas a explicar?" value={tema?.id ?? ""} onChange={(evento) => setTemaId(evento.target.value)}>
              {estado.temas.map((candidato) => (
                <option key={candidato.id} value={candidato.id}>
                  {candidato.nombre} · {candidato.materia}
                </option>
              ))}
            </Selector>

            {materialDelTema.length === 0 ? (
              <Nota tono="atencion">
                Este tema no tiene material cargado. Igual puedo revisar cómo razonás, pero no voy a poder decirte si te faltan
                ideas del apunte.
              </Nota>
            ) : null}

            <Area
              etiqueta="Explicalo con tus palabras, sin mirar el apunte"
              placeholder="Arrancá por qué es, seguí por por qué pasa y terminá con un ejemplo tuyo…"
              value={texto}
              onChange={(evento) => setTexto(evento.target.value)}
              ayuda={`${contarPalabras(texto)} palabras · con menos de 40 no se ve tu razonamiento`}
              className="[&_textarea]:min-h-48"
            />

            <Boton onClick={revisar} disabled={contarPalabras(texto) < 15}>
              Buscá mis huecos
            </Boton>
          </div>
        )}

        <AvisoPrincipio texto="No te voy a decir qué idea te falta ni te la voy a escribir. Te digo cuántas faltan y te hago la pregunta que te lleva hasta ellas." />
      </Tarjeta>

      {diagnostico ? (
        <Tarjeta retraso={60}>
          <TituloSeccion icono="explicame" titulo="Lo que encontré en tu explicación" />

          <div className="grid gap-3 sm:grid-cols-3">
            <Dato valor={`${diagnostico.solidez}%`} etiqueta="Solidez del razonamiento" />
            <Dato valor={`${diagnostico.cobertura}%`} etiqueta="Ideas del material tocadas" />
            <Dato valor={`${diagnostico.huecos.length}`} etiqueta="Huecos detectados" />
          </div>

          <div className="mt-4">
            <Barra
              valor={diagnostico.solidez}
              tono={diagnostico.solidez >= 75 ? "logro" : diagnostico.solidez >= 45 ? "atencion" : "alerta"}
              alto="h-3"
            />
          </div>

          {diagnostico.fortalezas.length > 0 ? (
            <ul className="mt-4 space-y-1.5">
              {diagnostico.fortalezas.map((fortaleza) => (
                <li key={fortaleza} className="flex items-start gap-2 text-sm text-media">
                  <Icono nombre="check" tamaño={15} className="mt-0.5 text-logro" />
                  <span>{fortaleza}</span>
                </li>
              ))}
            </ul>
          ) : null}

          {diagnostico.huecos.length === 0 ? (
            <div className="mt-4">
              <Nota tono="logro">
                No encontré huecos en cómo lo explicaste. Probá ahora explicarlo en 3 oraciones: la síntesis es el siguiente
                nivel.
              </Nota>
            </div>
          ) : (
            <ul className="mt-5 space-y-3">
              {diagnostico.huecos.map((hueco, indice) => (
                <li
                  key={hueco.id}
                  className="em-aparecer rounded-md border border-linea bg-superficie p-4"
                  style={{ animationDelay: `${indice * 70}ms` }}
                >
                  <div className="mb-2 flex flex-wrap items-center gap-2">
                    <Pildora tono={TONOS_GRAVEDAD[hueco.gravedad]}>
                      {hueco.gravedad === "alta" ? "Prioridad alta" : hueco.gravedad === "media" ? "Prioridad media" : "Para pulir"}
                    </Pildora>
                    <span className="text-sm font-semibold text-tinta">{hueco.titulo}</span>
                  </div>
                  <p className="text-sm text-media">{hueco.pregunta}</p>
                  <Boton variante="fantasma" className="mt-2 px-2" onClick={() => guardarComoError(hueco.titulo)}>
                    + Anotarlo en mis errores frecuentes
                  </Boton>
                </li>
              ))}
            </ul>
          )}
        </Tarjeta>
      ) : null}

      {historial.length > 0 ? (
        <Tarjeta retraso={120}>
          <TituloSeccion icono="adultos" titulo="Tus explicaciones anteriores" bajada="Mirá si los mismos huecos se repiten: eso es lo que hay que atacar." />
          <ul className="space-y-2">
            {historial.map((explicacion) => (
              <li key={explicacion.id} className="rounded-md border border-linea px-4 py-3">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <span className="text-sm font-bold text-tinta">
                    {new Date(explicacion.creadaEn).toLocaleDateString("es-AR")}
                  </span>
                  <div className="flex gap-2">
                    <Pildora tono="acento">{explicacion.cobertura}% del material</Pildora>
                    <Pildora tono={explicacion.huecos.length === 0 ? "logro" : "atencion"}>
                      {explicacion.huecos.length} huecos
                    </Pildora>
                  </div>
                </div>
                <p className="mt-1 line-clamp-2 text-sm text-media">{explicacion.texto}</p>
              </li>
            ))}
          </ul>
        </Tarjeta>
      ) : null}
    </div>
  );
}

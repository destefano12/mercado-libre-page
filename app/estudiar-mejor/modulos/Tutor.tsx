"use client";

import { useMemo, useRef, useState } from "react";
import { FormularioTema } from "../components/FormularioTema";
import { Area, AvisoPrincipio, Barra, Boton, Campo, Pildora, Selector, Tarjeta, TituloSeccion, Vacio , type Tono } from "../components/ui";
import { cuandoEs } from "../lib/fechas";
import { useEstudiar } from "../lib/store";
import { contarPalabras } from "../lib/texto";
import { armarCola, preguntaDeError } from "../lib/tutor";
import type { TarjetaTutor, TipoTarjeta } from "../lib/tipos";

const ETIQUETA_TIPO: Record<TipoTarjeta, { nombre: string; tono: Tono }> = {
  definicion: { nombre: "Definición", tono: "acento" },
  causa: { nombre: "Causa y efecto", tono: "alerta" },
  proceso: { nombre: "Proceso", tono: "acento" },
  dato: { nombre: "Dato", tono: "atencion" },
  enumeracion: { nombre: "Enumeración", tono: "logro" },
  transferencia: { nombre: "Transferencia", tono: "neutro" },
};

function TarjetaPregunta({ tarjeta, onCerrar }: { tarjeta: TarjetaTutor; onCerrar: (falló: boolean) => void }) {
  const { acciones } = useEstudiar();
  const [pistasVisibles, setPistasVisibles] = useState(0);
  const [respuesta, setRespuesta] = useState("");
  const etiqueta = ETIQUETA_TIPO[tarjeta.tipo];

  const responder = (calificacion: "no-pude" | "dude" | "lo-tenia") => {
    acciones.calificar(tarjeta.id, calificacion);
    acciones.registrarEvidencia(tarjeta.temaId, calificacion === "lo-tenia" ? 1 : calificacion === "dude" ? 0.5 : 0, 1);
    acciones.registrarLog({ minutos: 3, tipo: "tutor", temaId: tarjeta.temaId });
    setPistasVisibles(0);
    setRespuesta("");
    onCerrar(calificacion === "no-pude");
  };

  return (
    <div className="em-surgir rounded-lg border border-acento-linea bg-papel p-5 sm:p-6">
      <div className="mb-3 flex flex-wrap items-center gap-2">
        <Pildora tono={etiqueta.tono}>{etiqueta.nombre}</Pildora>
        <Pildora tono="neutro">
          <span className="em-cifra">{tarjeta.repaso.aciertos}</span> bien ·{" "}
          <span className="em-cifra">{tarjeta.repaso.fallos}</span> mal
        </Pildora>
      </div>

      <p className="text-lg font-semibold leading-snug text-tinta sm:text-xl">{tarjeta.enunciado}</p>

      <Area
        etiqueta="Tu respuesta (escribila antes de mirar pistas)"
        placeholder="Escribí lo que te salga, aunque sea a medias. Después vemos."
        value={respuesta}
        onChange={(evento) => setRespuesta(evento.target.value)}
        className="mt-4"
      />

      <div className="mt-4 space-y-2">
        {tarjeta.pistas.slice(0, pistasVisibles).map((pista, indice) => (
          <p key={pista} className="em-aparecer rounded-md bg-superficie px-4 py-3 text-sm text-tinta shadow-sm">
            <span className="mr-1 font-bold text-acento">Pista {indice + 1}:</span>
            {pista}
          </p>
        ))}

        {pistasVisibles < tarjeta.pistas.length ? (
          <Boton variante="secundario" onClick={() => setPistasVisibles((previo) => previo + 1)}>
            {pistasVisibles === 0 ? "Necesito una pista" : "Otra pista más"} ({tarjeta.pistas.length - pistasVisibles} quedan)
          </Boton>
        ) : (
          <p className="text-xs font-semibold text-tenue">
            Ya no hay más pistas. Las que faltan las tenés que poner vos volviendo al material.
          </p>
        )}
      </div>

      <div className="mt-5 border-t border-linea pt-4">
        <p className="em-rotulo mb-2">¿Cómo te fue?</p>
        <div className="flex flex-wrap gap-2">
          <Boton variante="peligro" onClick={() => responder("no-pude")}>
            No pude
          </Boton>
          <Boton variante="secundario" onClick={() => responder("dude")}>
            Dudé
          </Boton>
          <Boton variante="exito" onClick={() => responder("lo-tenia")}>
            Lo tenía
          </Boton>
        </div>
        <p className="mt-2 text-xs text-tenue">
          Contestá honestamente: de esto depende cuándo te vuelvo a preguntar.
        </p>
      </div>
    </div>
  );
}

export function Tutor() {
  const { estado, acciones } = useEstudiar();
  const [temaId, setTemaId] = useState<string>("todos");
  const [temaMaterial, setTemaMaterial] = useState("");
  const [titulo, setTitulo] = useState("");
  const [texto, setTexto] = useState("");
  const [aviso, setAviso] = useState<string | null>(null);
  const [vistas, setVistas] = useState<string[]>([]);
  const inputArchivo = useRef<HTMLInputElement>(null);

  const temaMaterialElegido = estado.temas.find((tema) => tema.id === temaMaterial) ?? estado.temas[0];
  const cola = useMemo(() => armarCola(estado.tarjetas, estado.errores, temaId), [estado.tarjetas, estado.errores, temaId]);
  const pendientes = cola.pendientes;
  // Las que fallaste vuelven al final de la tanda, no de inmediato: así no se traba en la misma.
  const actual = pendientes.find((tarjeta) => !vistas.includes(tarjeta.id)) ?? pendientes[0];
  const erroresAbiertos = estado.errores.filter((error) => !error.resuelto).slice(0, 2);

  const subirArchivo = async (archivo: File | undefined) => {
    if (!archivo) return;
    if (!/\.(txt|md|csv|text)$/i.test(archivo.name)) {
      setAviso("Por ahora leo archivos de texto (.txt, .md). Si tenés un PDF, copiá y pegá el contenido acá abajo.");
      return;
    }
    const contenido = await archivo.text();
    setTexto(contenido);
    if (!titulo.trim()) setTitulo(archivo.name.replace(/\.[^.]+$/, ""));
    setAviso(null);
  };

  const cargar = () => {
    if (!temaMaterialElegido || contarPalabras(texto) < 40) {
      setAviso("Necesito al menos 40 palabras de material para poder armarte preguntas que valgan la pena.");
      return;
    }
    const { preguntas } = acciones.agregarMaterial(temaMaterialElegido.id, titulo.trim() || "Material sin título", texto.trim());
    setTexto("");
    setTitulo("");
    setAviso(
      preguntas > 0
        ? `Listo: saqué ${preguntas} preguntas de tu material. No te voy a dar las respuestas, sólo las preguntas.`
        : "Pude guardar el material, pero me costó encontrar preguntas. Probá con un texto más explicativo y menos esquemático.",
    );
  };

  const avanzar = (falló: boolean) => {
    if (!actual) return;
    if (falló) {
      acciones.registrarError({
        temaId: actual.temaId,
        titulo: `No pude explicar “${actual.foco}”`,
        detalle: actual.enunciado,
        causa: "no-entendi",
        origen: "tutor",
      });
    }
    setVistas((previo) => {
      const siguiente = [...previo, actual.id];
      const quedan = pendientes.some((tarjeta) => tarjeta.id !== actual.id && !siguiente.includes(tarjeta.id));
      return quedan ? siguiente : [];
    });
  };

  return (
    <div className="space-y-6">
      <Tarjeta>
        <TituloSeccion
          icono="tutor"
          titulo="Tutor socrático"
          bajada="Subí tu material y lo convierto en preguntas. Las respuestas las ponés vos: yo doy pistas que te acercan, nunca la solución."
        />

        {estado.temas.length === 0 ? (
          <div className="space-y-4">
            <Vacio icono="archivo" titulo="Primero necesito un tema" texto="Creá el tema al que pertenece el material que vas a cargar." />
            <FormularioTema onCreado={setTemaMaterial} />
          </div>
        ) : (
          <div className="space-y-4">
            <div className="grid gap-4 sm:grid-cols-2">
              <Selector
                etiqueta="¿A qué tema pertenece?"
                value={temaMaterialElegido?.id ?? ""}
                onChange={(evento) => setTemaMaterial(evento.target.value)}
              >
                {estado.temas.map((tema) => (
                  <option key={tema.id} value={tema.id}>
                    {tema.nombre} · {tema.materia}
                  </option>
                ))}
              </Selector>
              <Campo
                etiqueta="Título del material"
                placeholder="Ej: Apunte de clase del martes"
                value={titulo}
                onChange={(evento) => setTitulo(evento.target.value)}
              />
            </div>

            <Area
              etiqueta="Pegá acá tu apunte, resumen o capítulo"
              placeholder="Copiá el texto tal cual lo tenés. Cuanto más explicativo, mejores preguntas salen."
              value={texto}
              onChange={(evento) => setTexto(evento.target.value)}
              ayuda={`${contarPalabras(texto)} palabras cargadas`}
            />

            <div className="flex flex-wrap items-center gap-3">
              <Boton onClick={cargar} disabled={contarPalabras(texto) < 40}>
                Generar preguntas
              </Boton>
              <Boton variante="secundario" icono="archivo" onClick={() => inputArchivo.current?.click()}>
                Subir archivo de texto
              </Boton>
              <input
                ref={inputArchivo}
                type="file"
                accept=".txt,.md,.csv,text/plain"
                className="hidden"
                onChange={(evento) => {
                  void subirArchivo(evento.target.files?.[0]);
                  evento.target.value = "";
                }}
              />
            </div>

            {aviso ? <p className="rounded-md bg-acento-tenue px-4 py-3 text-sm font-semibold text-acento-fuerte">{aviso}</p> : null}
          </div>
        )}

        {estado.materiales.length > 0 ? (
          <ul className="mt-5 space-y-2">
            {estado.materiales.map((material) => {
              const tema = estado.temas.find((candidato) => candidato.id === material.temaId);
              const preguntas = estado.tarjetas.filter((tarjeta) => tarjeta.materialId === material.id).length;
              return (
                <li key={material.id} className="flex flex-wrap items-center justify-between gap-3 rounded-md border border-linea px-4 py-3">
                  <div className="min-w-0">
                    <p className="truncate text-sm font-bold text-tinta">{material.titulo}</p>
                    <p className="text-xs text-media">
                      {tema?.nombre ?? "Sin tema"} · {contarPalabras(material.texto)} palabras · {preguntas} preguntas
                    </p>
                  </div>
                  <Boton variante="fantasma" onClick={() => acciones.eliminarMaterial(material.id)}>
                    Quitar
                  </Boton>
                </li>
              );
            })}
          </ul>
        ) : null}

        <AvisoPrincipio texto="Tu material no sale del navegador: no se sube a ningún servidor. Y las preguntas se arman con lo que vos cargaste, no con respuestas de otro lado." />
      </Tarjeta>

      <Tarjeta retraso={80}>
        <TituloSeccion
          icono="repetir"
          titulo="Repaso de hoy"
          bajada="Repaso espaciado: lo que te sale bien vuelve más lejos en el tiempo, lo que falla vuelve enseguida."
          accion={
            <Selector etiqueta="Filtrar" value={temaId} onChange={(evento) => setTemaId(evento.target.value)} className="min-w-44">
              <option value="todos">Todos los temas</option>
              {estado.temas.map((tema) => (
                <option key={tema.id} value={tema.id}>
                  {tema.nombre}
                </option>
              ))}
            </Selector>
          }
        />

        {erroresAbiertos.length > 0 ? (
          <div className="mb-5 rounded-lg border border-atencion-linea bg-atencion-tenue p-4">
            <p className="em-rotulo mb-2 text-atencion">Reinyección de errores</p>
            <ul className="em-lista space-y-2">
              {erroresAbiertos.map((error) => (
                <li key={error.id} className="text-sm leading-relaxed text-atencion">
                  {preguntaDeError(error)}
                </li>
              ))}
            </ul>
          </div>
        ) : null}

        {estado.tarjetas.length === 0 ? (
          <Vacio icono="tutor" titulo="No hay preguntas todavía" texto="Cargá material arriba y en segundos tenés tu primera tanda." />
        ) : pendientes.length === 0 ? (
          <Vacio
            icono="check"
            titulo="Terminaste el repaso de hoy"
            texto={
              cola.proximas.length > 0
                ? `La próxima tanda vuelve ${cuandoEs(cola.proximas[0].repaso.proxima)}. Descansar también es parte del método.`
                : "Cargá más material o volvé mañana."
            }
          />
        ) : (
          <div className="space-y-4">
            <div className="flex items-center justify-between text-sm font-semibold text-media">
              <span>Quedan {pendientes.length} preguntas</span>
              <span>{cola.proximas.length} agendadas para más adelante</span>
            </div>
            <Barra valor={(1 - pendientes.length / Math.max(1, pendientes.length + cola.proximas.length)) * 100} />
            {actual ? <TarjetaPregunta key={actual.id} tarjeta={actual} onCerrar={avanzar} /> : null}
          </div>
        )}
      </Tarjeta>
    </div>
  );
}

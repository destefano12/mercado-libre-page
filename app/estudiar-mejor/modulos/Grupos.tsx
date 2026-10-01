"use client";

import { useState } from "react";
import { AvisoPrincipio, Barra, Boton, Campo, Pildora, Tarjeta, TituloSeccion, Vacio } from "../components/ui";
import { ChatGrupo } from "../components/ChatGrupo";
import { conectarChat } from "../lib/chat";
import { Icono } from "../components/iconos";
import { cuandoEs, fechaLarga, hoyClave, sumarDias } from "../lib/fechas";
import { nombreDesdeCorreo, separarCorreo } from "../lib/correo";
import { enlaceDeCorreo, enlaceDeInvitacion, textoDeInvitacion, type DatosInvitacion } from "../lib/invitacion";
import { useEstudiar } from "../lib/store";
import type { Integrante } from "../lib/tipos";

const ROLES_SUGERIDOS = [
  "Coordinación",
  "Investigación",
  "Armado",
  "Revisión",
  "Presentación",
  "Diseño",
];

function avanceDe(integrante: Integrante): number {
  if (integrante.tareas.length === 0) return 0;
  return Math.round((integrante.tareas.filter((tarea) => tarea.hecho).length / integrante.tareas.length) * 100);
}

export function Grupos() {
  const { estado, acciones } = useEstudiar();
  const [nombre, setNombre] = useState("");
  const [materia, setMateria] = useState("");
  const [entrega, setEntrega] = useState(sumarDias(hoyClave(), 14));
  const [integrantes, setIntegrantes] = useState("");
  const [nuevaTarea, setNuevaTarea] = useState<Record<string, string>>({});
  const [nuevoIntegrante, setNuevoIntegrante] = useState<Record<string, string>>({});
  const [codigoParaEntrar, setCodigoParaEntrar] = useState("");
  const [entrando, setEntrando] = useState(false);
  const [avisoDeCodigo, setAvisoDeCodigo] = useState<{ tono: "alerta" | "logro"; texto: string } | null>(null);

  const crear = () => {
    const lista = integrantes
      .split(/[,;\n]/)
      .map((parte) => parte.trim())
      .filter(Boolean)
      .map(separarCorreo);
    if (!nombre.trim() || lista.length === 0) return;

    // Vos encabezás el grupo aunque no te hayas escrito en la lista.
    const mio = estado.email.trim().toLowerCase();
    const yaEstoy = mio && lista.some((integrante) => integrante.email === mio);
    const todos = yaEstoy
      ? lista
      : [{ nombre: estado.nombre || (mio ? nombreDesdeCorreo(mio) : "Vos"), email: estado.email }, ...lista];

    acciones.crearGrupo(
      nombre.trim(),
      materia.trim() || "General",
      entrega,
      todos.map((integrante, indice) => ({
        ...integrante,
        rol: ROLES_SUGERIDOS[indice % ROLES_SUGERIDOS.length],
      })),
    );
    setNombre("");
    setMateria("");
    setIntegrantes("");
  };

  /**
   * Salir de un grupo: se va de tu pantalla y también te saca de la ficha del
   * servidor, para que tus compañeros vean que no estás y para que no te lo
   * vuelvan a mandar. Sin conexión, igual te vas de tu lado.
   */
  const salirDelGrupo = async (grupoId: string, codigo: string) => {
    acciones.eliminarGrupo(grupoId);

    const mio = estado.email.trim().toLowerCase();
    if (!mio) return;

    const chat = await conectarChat();
    const ficha = await chat?.buscarGrupo?.(codigo);
    if (!chat || !ficha) return;

    await chat
      .publicarGrupo({
        ...ficha,
        correos: ficha.correos.filter((correo) => correo.toLowerCase() !== mio),
        integrantes: ficha.integrantes.filter((integrante) => integrante.email.toLowerCase() !== mio),
        actualizado: new Date().toISOString(),
      })
      .catch(() => {
        // Si no se puede avisar al servidor, de tu lado ya saliste igual.
      });
  };

  /**
   * Un código suelto no alcanza para entrar: se busca el grupo en el servidor
   * y, si no existe, no se crea nada. Un grupo inventado no le sirve a nadie.
   */
  const entrarConCodigo = async () => {
    const codigo = codigoParaEntrar.trim().toUpperCase();
    if (codigo.length < 4) return;

    if (estado.grupos.some((grupo) => grupo.codigo === codigo)) {
      setAvisoDeCodigo({ tono: "logro", texto: "Ya estabas en ese grupo: miralo más abajo." });
      setCodigoParaEntrar("");
      return;
    }

    setEntrando(true);
    setAvisoDeCodigo(null);

    const chat = await conectarChat();
    if (!chat?.buscarGrupo) {
      setEntrando(false);
      setAvisoDeCodigo({
        tono: "alerta",
        texto: "No hay conexión con el servidor, así que no puedo comprobar el código. Probá de nuevo en un momento.",
      });
      return;
    }

    const ficha = await chat.buscarGrupo(codigo);
    setEntrando(false);

    if (!ficha) {
      setAvisoDeCodigo({
        tono: "alerta",
        texto: `No existe ningún grupo con el código ${codigo}. Pedile a quien lo armó que te lo pase de nuevo o que te invite por mail.`,
      });
      return;
    }

    const mio = estado.email.trim().toLowerCase();
    acciones.adoptarGrupoPublicado(
      {
        ...ficha,
        correos: mio ? [...ficha.correos, mio] : ficha.correos,
        integrantes: mio && !ficha.correos.includes(mio)
          ? [...ficha.integrantes, { nombre: estado.nombre || "Vos", email: mio, rol: "Integrante" }]
          : ficha.integrantes,
      },
      true,
    );
    setAvisoDeCodigo({ tono: "logro", texto: `Entraste a "${ficha.nombre}".` });
    setCodigoParaEntrar("");
  };

  return (
    <div className="space-y-6">
      <Tarjeta>
        <TituloSeccion
          icono="grupos"
          titulo="Trabajos grupales"
          bajada="Cargá los correos de tus compañeros y repartí responsabilidades. A quien entre a la página con ese correo le va a aparecer el grupo ya armado."
        />

        <div className="grid gap-4 sm:grid-cols-2">
          <Campo etiqueta="Nombre del trabajo" placeholder="Ej: Maqueta del ecosistema" value={nombre} onChange={(evento) => setNombre(evento.target.value)} />
          <Campo etiqueta="Materia" placeholder="Ej: Biología" value={materia} onChange={(evento) => setMateria(evento.target.value)} />
          <Campo etiqueta="Fecha de entrega" type="date" min={hoyClave()} value={entrega} onChange={(evento) => setEntrega(evento.target.value)} ayuda={`Es ${cuandoEs(entrega)}`} />
          <Campo
            etiqueta="Correos de los integrantes"
            placeholder="tomas@gmail.com, juana@gmail.com"
            value={integrantes}
            onChange={(evento) => setIntegrantes(evento.target.value)}
            ayuda="Con el correo alcanza. Cuando entren a la página con ese correo, el grupo les aparece solo y el nombre se completa."
          />
        </div>

        <Boton className="mt-4" onClick={crear} disabled={!nombre.trim() || !integrantes.trim()}>
          Crear trabajo grupal
        </Boton>

        <div className="mt-5 border-t border-linea pt-4">
          <div className="flex flex-wrap items-end gap-3">
            <Campo
              etiqueta="¿Te pasaron un código?"
              placeholder="Ej: BIO4KM"
              value={codigoParaEntrar}
              onChange={(evento) => {
                setCodigoParaEntrar(evento.target.value.toUpperCase());
                setAvisoDeCodigo(null);
              }}
              className="w-44"
            />
            <Boton variante="secundario" disabled={codigoParaEntrar.trim().length < 4 || entrando} onClick={() => void entrarConCodigo()}>
              {entrando ? "Buscando…" : "Entrar al grupo"}
            </Boton>
          </div>
          <p className="mt-2 text-xs text-tenue">
            El código tiene que ser el de un grupo que ya existe: se busca en el servidor antes de sumarte.
          </p>
          {avisoDeCodigo ? (
            <p className={`mt-2 text-sm font-medium ${avisoDeCodigo.tono === "alerta" ? "text-alerta" : "text-logro"}`}>
              {avisoDeCodigo.texto}
            </p>
          ) : null}
        </div>

        <AvisoPrincipio texto="Reparto las tareas, no las hago. Cada parte del trabajo la escribe la persona que la tiene asignada." />
      </Tarjeta>

      {estado.grupos.length === 0 ? (
        <Vacio icono="grupos" titulo="Todavía no hay trabajos grupales" texto="Cargá uno y vas a ver quién va cómo, sin tener que preguntar por el grupo de chat." />
      ) : (
        estado.grupos.map((grupo, indice) => {
          const totalTareas = grupo.integrantes.reduce((total, integrante) => total + integrante.tareas.length, 0);
          const hechas = grupo.integrantes.reduce(
            (total, integrante) => total + integrante.tareas.filter((tarea) => tarea.hecho).length,
            0,
          );
          const avanceGlobal = totalTareas === 0 ? 0 : Math.round((hechas / totalTareas) * 100);

          return (
            <Tarjeta key={grupo.id} retraso={indice * 70}>
              <div className="mb-4 flex flex-wrap items-start justify-between gap-3">
                <div>
                  <h3 className="flex flex-wrap items-center gap-2 text-lg font-semibold text-tinta">
                    {grupo.nombre}
                    {grupo.compartido ? <Pildora tono="acento">te sumaron</Pildora> : null}
                  </h3>
                  <p className="text-sm text-media">
                    {grupo.materia} · entrega {fechaLarga(grupo.entrega)} ({cuandoEs(grupo.entrega)})
                  </p>
                </div>
                <Boton variante="peligro" onClick={() => void salirDelGrupo(grupo.id, grupo.codigo)}>
                  Salir del grupo
                </Boton>
              </div>

              <div className="mb-5">
                <div className="mb-1.5 flex items-center justify-between text-sm font-bold text-media">
                  <span>Avance del grupo</span>
                  <span>{avanceGlobal}%</span>
                </div>
                <Barra valor={avanceGlobal} tono={avanceGlobal >= 70 ? "logro" : avanceGlobal >= 35 ? "acento" : "atencion"} alto="h-3" />
              </div>

              <div className="grid gap-3 lg:grid-cols-2">
                {grupo.integrantes.map((integrante) => {
                  const avance = avanceDe(integrante);
                  return (
                    <article key={integrante.id} className="rounded-md border border-linea bg-superficie p-4">
                      <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
                        <div className="flex items-center gap-2">
                          <span className="grid h-9 w-9 place-items-center rounded-full bg-acento-tenue text-sm font-semibold text-acento-fuerte">
                            {integrante.nombre.slice(0, 2).toUpperCase()}
                          </span>
                          <div>
                            <p className="text-sm font-semibold text-tinta">
                              {integrante.nombre} {integrante.esYo ? <Pildora tono="acento">vos</Pildora> : null}
                            </p>
                            <p className="em-rotulo">{integrante.rol}</p>
                            {integrante.email ? (
                              <p className="truncate text-xs text-tenue">{integrante.email}</p>
                            ) : null}
                          </div>
                        </div>
                        <Boton
                          variante="fantasma"
                          aria-label={`Quitar a ${integrante.nombre}`}
                          onClick={() => acciones.eliminarIntegrante(grupo.id, integrante.id)}
                        >
                          <Icono nombre="cerrar" tamaño={15} />
                        </Boton>
                      </div>

                      <div className="mb-3 flex items-center gap-3">
                        <Barra valor={avance} tono={avance >= 70 ? "logro" : avance >= 35 ? "acento" : "alerta"} />
                        <span className="w-12 shrink-0 text-right text-sm font-semibold text-tinta">{avance}%</span>
                      </div>

                      <ul className="space-y-1.5">
                        {integrante.tareas.map((tarea) => (
                          <li key={tarea.id} className="flex items-center gap-2">
                            <label className="flex flex-1 cursor-pointer items-center gap-2">
                              <input
                                type="checkbox"
                                checked={tarea.hecho}
                                onChange={() => acciones.alternarTarea(grupo.id, integrante.id, tarea.id)}
                                className="h-4 w-4 accent-[#1c7a54]"
                              />
                              <span className={`text-sm ${tarea.hecho ? "text-tenue line-through" : "text-tinta"}`}>
                                {tarea.titulo}
                              </span>
                            </label>
                            <button
                              type="button"
                              onClick={() => acciones.eliminarTarea(grupo.id, integrante.id, tarea.id)}
                              className="text-tenue transition-colors hover:text-alerta"
                              aria-label={`Borrar tarea ${tarea.titulo}`}
                            >
                              <Icono nombre="cerrar" tamaño={14} />
                            </button>
                          </li>
                        ))}
                        {integrante.tareas.length === 0 ? (
                          <li className="text-xs italic text-tenue">Sin responsabilidades asignadas todavía.</li>
                        ) : null}
                      </ul>

                      <div className="mt-3 flex gap-2">
                        <input
                          value={nuevaTarea[integrante.id] ?? ""}
                          onChange={(evento) => setNuevaTarea((previo) => ({ ...previo, [integrante.id]: evento.target.value }))}
                          onKeyDown={(evento) => {
                            if (evento.key !== "Enter") return;
                            const valor = (nuevaTarea[integrante.id] ?? "").trim();
                            if (!valor) return;
                            acciones.agregarTarea(grupo.id, integrante.id, valor);
                            setNuevaTarea((previo) => ({ ...previo, [integrante.id]: "" }));
                          }}
                          placeholder="Sumar responsabilidad…"
                          className="flex-1 rounded-full border border-linea bg-papel px-3 py-1.5 text-sm outline-none transition focus:border-acento focus:bg-superficie"
                        />
                        <Boton
                          variante="secundario"
                          onClick={() => {
                            const valor = (nuevaTarea[integrante.id] ?? "").trim();
                            if (!valor) return;
                            acciones.agregarTarea(grupo.id, integrante.id, valor);
                            setNuevaTarea((previo) => ({ ...previo, [integrante.id]: "" }));
                          }}
                        >
                          +
                        </Boton>
                      </div>
                    </article>
                  );
                })}
              </div>

              <div className="mt-4 flex gap-2">
                <input
                  value={nuevoIntegrante[grupo.id] ?? ""}
                  onChange={(evento) => setNuevoIntegrante((previo) => ({ ...previo, [grupo.id]: evento.target.value }))}
                  placeholder="Sumar integrante por correo…"
                  className="flex-1 rounded-full border border-linea bg-papel px-4 py-2 text-sm outline-none transition focus:border-acento focus:bg-superficie"
                />
                <Boton
                  variante="secundario"
                  onClick={() => {
                    const valor = (nuevoIntegrante[grupo.id] ?? "").trim();
                    if (!valor) return;
                    const datos = separarCorreo(valor);
                    acciones.agregarIntegrante(
                      grupo.id,
                      datos.nombre,
                      datos.email,
                      ROLES_SUGERIDOS[grupo.integrantes.length % ROLES_SUGERIDOS.length],
                    );
                    setNuevoIntegrante((previo) => ({ ...previo, [grupo.id]: "" }));
                  }}
                >
                  Agregar
                </Boton>
              </div>

              <InvitarAlGrupo
                datos={{
                  codigo: grupo.codigo,
                  nombreDelGrupo: grupo.nombre,
                  materia: grupo.materia,
                  entrega: fechaLarga(grupo.entrega),
                  deParteDe: estado.nombre,
                  correos: grupo.integrantes
                    .filter((integrante) => !integrante.esYo)
                    .map((integrante) => integrante.email)
                    .filter(Boolean),
                }}
              />

              <ChatGrupo codigo={grupo.codigo} nombreDelGrupo={grupo.nombre} />

              {avanceGlobal < 40 && grupo.entrega <= sumarDias(hoyClave(), 5) ? (
                <p className="mt-4 rounded-md bg-alerta-tenue px-4 py-3 text-sm font-semibold text-alerta">
                  Falta poco para la entrega y el avance está bajo. ¿Qué parte se puede dividir en dos para que no dependa de una sola persona?
                </p>
              ) : null}
            </Tarjeta>
          );
        })
      )}
    </div>
  );
}

/**
 * El mail sale del correo de quien armó el grupo, desde su propio programa de
 * correo: al compañero le llega de una dirección que conoce y el enlace lo
 * deja directamente en la pantalla para unirse.
 */
function InvitarAlGrupo({ datos }: { datos: DatosInvitacion }) {
  const [aviso, setAviso] = useState("");

  const copiar = async (texto: string, dicho: string) => {
    try {
      await navigator.clipboard.writeText(texto);
      setAviso(dicho);
    } catch {
      setAviso("No pude copiar. Marcá el texto a mano.");
    }
  };

  return (
    <div className="mt-5 border-t border-linea pt-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <p className="em-rotulo">Invitar a tus compañeros</p>
        <p className="text-xs text-tenue">
          Código: <span className="em-cifra font-semibold text-tinta">{datos.codigo}</span>
        </p>
      </div>

      <p className="mt-1.5 max-w-prose text-sm leading-relaxed text-media">
        Se abre tu correo con el mensaje escrito. Lo mandás vos, así les llega de tu dirección y saben que sos vos.
      </p>

      <div className="mt-3 flex flex-wrap gap-2">
        <Boton
          variante={datos.correos.length > 0 ? "primario" : "secundario"}
          icono="archivo"
          disabled={datos.correos.length === 0}
          onClick={() => {
            window.location.href = enlaceDeCorreo(datos);
            setAviso("Se abre tu correo con la invitación lista para enviar.");
          }}
        >
          Invitar por mail ({datos.correos.length})
        </Boton>
        <Boton variante="secundario" icono="copiar" onClick={() => void copiar(enlaceDeInvitacion(datos.codigo), "Enlace copiado.")}>
          Copiar el enlace
        </Boton>
        <Boton variante="fantasma" icono="copiar" onClick={() => void copiar(textoDeInvitacion(datos), "Mensaje copiado, listo para WhatsApp.")}>
          Copiar el mensaje
        </Boton>
      </div>

      {datos.correos.length === 0 ? (
        <p className="mt-2 text-xs text-tenue">Cargá el correo de tus compañeros y el botón del mail se enciende.</p>
      ) : null}
      {aviso ? <p className="mt-2 text-xs font-medium text-acento">{aviso}</p> : null}
    </div>
  );
}

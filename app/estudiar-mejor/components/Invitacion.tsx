"use client";

import { useEffect, useState, useSyncExternalStore } from "react";
import { conectarChat, type GrupoPublicado } from "../lib/chat";
import { esCorreo, normalizarCorreo } from "../lib/correo";
import { codigoInvitado, olvidarInvitacion } from "../lib/invitacion";
import { useEstudiar } from "../lib/store";
import { Icono } from "./iconos";
import { Boton, Campo, Nota } from "./ui";

/**
 * Lo primero que ve quien abre el enlace de una invitación: qué trabajo es,
 * quiénes están y un botón para entrar. Si ya usó la página antes, el botón lo
 * mete derecho; si es la primera vez, le pide el nombre y el correo, que es
 * todo lo que hace falta para que sus compañeros lo reconozcan.
 */
// La dirección sólo existe en el navegador. En el servidor no hay invitación
// que dibujar, así que el código se lee como estado externo: el primer dibujo
// coincide en los dos lados y recién después aparece la tarjeta.
const sinSuscripcion = () => () => {};
const sinCodigo = () => "";

export function Invitacion() {
  const { estado, acciones } = useEstudiar();
  const codigo = useSyncExternalStore(sinSuscripcion, codigoInvitado, sinCodigo);
  const [ficha, setFicha] = useState<GrupoPublicado | null>(null);
  const [buscando, setBuscando] = useState(true);
  const [nombre, setNombre] = useState(() => estado.nombre);
  const [correo, setCorreo] = useState(() => estado.email);
  const [cerrada, setCerrada] = useState(false);

  const yaEstoy = estado.grupos.some((grupo) => grupo.codigo === codigo);

  useEffect(() => {
    if (!codigo) return undefined;

    let vivo = true;
    void conectarChat()
      .then((chat) => chat?.buscarGrupo?.(codigo) ?? null)
      .then((encontrada) => {
        if (!vivo) return;
        setFicha(encontrada);
        setBuscando(false);
      });
    return () => {
      vivo = false;
    };
  }, [codigo]);

  if (!codigo || cerrada || yaEstoy) return null;

  const registrado = Boolean(estado.nombre.trim() && esCorreo(estado.email));
  const datosListos = registrado || (nombre.trim().length >= 2 && esCorreo(correo));
  // Sin la ficha del servidor no se entra a ningún lado: el grupo tiene que existir.
  const listoParaEntrar = datosListos && Boolean(ficha);

  const entrar = () => {
    if (!registrado) {
      acciones.guardarNombre(nombre.trim());
      acciones.guardarEmail(normalizarCorreo(correo));
    }

    if (!ficha) return;

    const mio = normalizarCorreo(registrado ? estado.email : correo);
    acciones.adoptarGrupoPublicado(
      {
        ...ficha,
        correos: [...ficha.correos, mio].filter(Boolean),
        integrantes: mio && !ficha.correos.includes(mio)
          ? [...ficha.integrantes, { nombre: (registrado ? estado.nombre : nombre).trim(), email: mio, rol: "Integrante" }]
          : ficha.integrantes,
      },
      true,
    );

    olvidarInvitacion();
    setCerrada(true);
  };

  const rechazar = () => {
    olvidarInvitacion();
    setCerrada(true);
  };

  return (
    <div className="fixed inset-0 z-[60] grid place-items-center overflow-y-auto bg-tinta/40 p-4">
      <div className="em-surgir w-full max-w-lg rounded-lg border border-linea bg-superficie p-6 shadow-lg sm:p-8">
        <span className="grid h-11 w-11 place-items-center rounded-md bg-acento-tenue text-acento-fuerte">
          <Icono nombre="grupos" tamaño={21} />
        </span>

        <h2 className="mt-4 text-xl text-tinta">Te invitaron a un trabajo grupal</h2>

        {buscando ? (
          <p className="em-latido mt-3 text-sm text-media">Buscando el grupo…</p>
        ) : ficha ? (
          <div className="mt-3 space-y-1">
            <p className="text-lg font-semibold text-tinta">{ficha.nombre}</p>
            <p className="text-sm text-media">
              {ficha.materia}
              {ficha.entrega ? ` · entrega ${ficha.entrega}` : ""} · {ficha.integrantes.length} integrantes
            </p>
            <p className="text-sm text-tenue">
              {ficha.integrantes.map((integrante) => integrante.nombre).join(", ")}
            </p>
          </div>
        ) : (
          <div className="mt-3">
            <Nota tono="alerta">
              No existe ningún grupo con el código <span className="em-cifra font-semibold">{codigo}</span>. Puede que
              el enlace esté cortado o que quien lo armó todavía no haya abierto la página. Pedile que te invite de
              nuevo.
            </Nota>
          </div>
        )}

        {!registrado && ficha ? (
          <div className="mt-5 grid gap-4 sm:grid-cols-2">
            <Campo
              etiqueta="Tu nombre"
              placeholder="Cómo te dicen"
              value={nombre}
              onChange={(evento) => setNombre(evento.target.value)}
            />
            <Campo
              etiqueta="Tu correo"
              type="email"
              placeholder="nombre@gmail.com"
              value={correo}
              onChange={(evento) => setCorreo(evento.target.value)}
              ayuda="Con el correo tus compañeros te reconocen."
            />
          </div>
        ) : registrado && ficha ? (
          <p className="mt-5 text-sm leading-relaxed text-media">
            Vas a entrar como <span className="font-semibold text-tinta">{estado.nombre}</span> ({estado.email}).
          </p>
        ) : null}

        <div className="mt-6 flex flex-wrap gap-2">
          {ficha ? (
            <Boton onClick={entrar} disabled={!listoParaEntrar} icono="grupos">
              Unirme al grupo
            </Boton>
          ) : null}
          <Boton variante="fantasma" onClick={rechazar}>
            {ficha ? "Ahora no" : "Cerrar"}
          </Boton>
        </div>

        <p className="mt-4 border-t border-linea pt-3 text-xs leading-relaxed text-tenue">
          Lo único que se comparte con el grupo es el trabajo: el reparto de tareas, el avance y el chat. Lo que
          estudiás por tu cuenta no sale de tu dispositivo.
        </p>
      </div>
    </div>
  );
}

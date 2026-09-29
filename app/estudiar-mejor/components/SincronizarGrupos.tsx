"use client";

import { useEffect, useRef, useState } from "react";
import { conectarChat, type Chat, type GrupoPublicado } from "../lib/chat";
import { normalizarCorreo } from "../lib/correo";
import { useEstudiar } from "../lib/store";

/**
 * Mantiene los grupos en línea, sin dibujar nada:
 *
 * - publica la ficha de cada grupo que armaste, con los correos de todos;
 * - escucha las fichas ajenas y, si tu correo figura en alguna, te mete
 *   adentro de ese grupo sin que tengas que pedir el código.
 */
export function SincronizarGrupos() {
  const { estado, acciones } = useEstudiar();
  const [chat, setChat] = useState<Chat | null>(null);
  const publicadas = useRef(new Map<string, string>());

  useEffect(() => {
    let vivo = true;
    void conectarChat().then((conexion) => {
      if (vivo) setChat(conexion);
    });
    return () => {
      vivo = false;
    };
  }, []);

  // Publicar lo propio: sólo cuando la ficha cambió de verdad.
  useEffect(() => {
    if (!chat?.puedeEscribir) return;

    for (const grupo of estado.grupos) {
      const correos = grupo.integrantes.map((integrante) => normalizarCorreo(integrante.email)).filter(Boolean);
      if (correos.length === 0) continue;

      const ficha: GrupoPublicado = {
        codigo: grupo.codigo,
        nombre: grupo.nombre,
        materia: grupo.materia,
        entrega: grupo.entrega,
        correos,
        integrantes: grupo.integrantes.map((integrante) => ({
          nombre: integrante.nombre,
          email: normalizarCorreo(integrante.email),
          rol: integrante.rol,
        })),
        actualizado: new Date().toISOString(),
      };

      const huella = JSON.stringify({ ...ficha, actualizado: "" });
      if (publicadas.current.get(grupo.codigo) === huella) continue;
      publicadas.current.set(grupo.codigo, huella);
      void chat.publicarGrupo(ficha).catch(() => publicadas.current.delete(grupo.codigo));
    }
  }, [chat, estado.grupos]);

  // Escuchar lo ajeno: si tu correo está en la lista, ya estás adentro.
  useEffect(() => {
    const mio = normalizarCorreo(estado.email);
    if (!chat || !mio) return undefined;

    return chat.escucharGrupos((fichas) => {
      for (const ficha of fichas) {
        if (ficha.correos?.some((correo) => normalizarCorreo(correo) === mio)) {
          acciones.adoptarGrupoPublicado(ficha);
        }
      }
    });
  }, [chat, estado.email, acciones]);

  return null;
}

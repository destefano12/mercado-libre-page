"use client";

import { useEffect, useRef, useState } from "react";
import { conectarChat, type Chat, type MensajeChat } from "../lib/chat";
import { useEstudiar } from "../lib/store";
import { Icono } from "./iconos";
import { Boton, Nota } from "./ui";

function hora(cuando: string): string {
  const fecha = new Date(cuando);
  return Number.isNaN(fecha.getTime())
    ? ""
    : fecha.toLocaleTimeString("es-AR", { hour: "2-digit", minute: "2-digit" });
}

export function ChatGrupo({ codigo, nombreDelGrupo }: { codigo: string; nombreDelGrupo: string }) {
  const { estado } = useEstudiar();
  const [chat, setChat] = useState<Chat | null>(null);
  const [conectando, setConectando] = useState(true);
  const [mensajes, setMensajes] = useState<MensajeChat[]>([]);
  const [borrador, setBorrador] = useState("");
  const [error, setError] = useState<string | null>(null);
  const fondo = useRef<HTMLDivElement>(null);

  useEffect(() => {
    let vivo = true;
    void conectarChat().then((conexion) => {
      if (!vivo) return;
      setChat(conexion);
      setConectando(false);
    });
    return () => {
      vivo = false;
    };
  }, []);

  useEffect(() => {
    if (!chat) return undefined;
    return chat.escuchar(codigo, setMensajes);
  }, [chat, codigo]);

  useEffect(() => {
    fondo.current?.scrollTo({ top: fondo.current.scrollHeight });
  }, [mensajes.length]);

  const enviar = async () => {
    const texto = borrador.trim();
    if (!texto || !chat) return;
    setBorrador("");
    try {
      await chat.enviar(codigo, estado.nombre || "Alguien", texto);
    } catch {
      setBorrador(texto);
      setError("No se pudo enviar. Probá de nuevo en un momento.");
    }
  };

  if (conectando) {
    return <p className="em-rotulo em-latido mt-4">Conectando el chat…</p>;
  }

  if (!chat) {
    return (
      <div className="mt-4">
        <Nota tono="neutro">
          El chat necesita conexión con un servidor y esta copia de la aplicación no la tiene. Todo lo demás del grupo
          —el reparto de tareas y el avance— funciona igual, guardado en este dispositivo.
        </Nota>
      </div>
    );
  }

  return (
    <div className="mt-5 border-t border-linea pt-4">
      <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
        <p className="em-rotulo">Chat del grupo</p>
        <p className="text-xs text-tenue">
          Código para que entren tus compañeros: <span className="em-cifra font-semibold text-tinta">{codigo}</span>
        </p>
      </div>

      <div
        ref={fondo}
        className="em-scroll-suave max-h-72 overflow-y-auto rounded-md border border-linea bg-papel p-3"
        aria-label={`Mensajes de ${nombreDelGrupo}`}
      >
        {mensajes.length === 0 ? (
          <p className="py-6 text-center text-sm text-tenue">
            Todavía no hay mensajes. Pasales el código a tus compañeros y escriban por acá.
          </p>
        ) : (
          <ul className="space-y-2.5">
            {mensajes.map((mensaje) => {
              const mio = mensaje.autor === estado.nombre;
              return (
                <li key={mensaje.id} className={`flex ${mio ? "justify-end" : "justify-start"}`}>
                  <div
                    className={`max-w-[78%] rounded-md border px-3 py-2 ${
                      mio ? "border-acento-linea bg-acento-tenue" : "border-linea bg-superficie"
                    }`}
                  >
                    <p className="em-rotulo mb-0.5">
                      {mio ? "Vos" : mensaje.autor} · {hora(mensaje.cuando)}
                    </p>
                    <p className="text-sm leading-relaxed text-tinta">{mensaje.texto}</p>
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </div>

      {chat.puedeEscribir ? (
        <div className="mt-3 flex gap-2">
          <label className="sr-only" htmlFor={`mensaje-${codigo}`}>
            Escribí un mensaje
          </label>
          <input
            id={`mensaje-${codigo}`}
            value={borrador}
            onChange={(evento) => setBorrador(evento.target.value)}
            onKeyDown={(evento) => {
              if (evento.key === "Enter") void enviar();
            }}
            placeholder="Escribí un mensaje…"
            className="flex-1 rounded-md border border-linea-fuerte bg-superficie px-3 py-2 text-sm outline-none transition-colors focus:border-acento"
          />
          <Boton onClick={() => void enviar()} disabled={!borrador.trim()} aria-label="Enviar mensaje">
            <Icono nombre="flecha" tamaño={16} />
          </Boton>
        </div>
      ) : (
        <p className="mt-3 text-xs leading-relaxed text-tenue">
          Podés leer los mensajes, pero no escribir: quien publicó la página tiene que darte permiso de edición.
        </p>
      )}

      {error ? <p className="mt-2 text-xs text-alerta">{error}</p> : null}
    </div>
  );
}

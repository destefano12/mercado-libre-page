"use client";

import { useState } from "react";
import { useEstudiar } from "../lib/store";
import { Boton, Campo } from "./ui";

export function FormularioTema({ onCreado }: { onCreado?: (temaId: string) => void }) {
  const { acciones } = useEstudiar();
  const [nombre, setNombre] = useState("");
  const [materia, setMateria] = useState("");

  const crear = () => {
    const limpio = nombre.trim();
    if (!limpio) return;
    const tema = acciones.agregarTema(limpio, materia.trim() || "General");
    setNombre("");
    setMateria("");
    onCreado?.(tema.id);
  };

  return (
    <div className="grid gap-3 rounded-md border border-dashed border-acento-linea bg-acento-tenue p-4 sm:grid-cols-[1fr_1fr_auto] sm:items-end">
      <Campo
        etiqueta="Tema nuevo"
        placeholder="Ej: Fotosíntesis"
        value={nombre}
        onChange={(evento) => setNombre(evento.target.value)}
        onKeyDown={(evento) => {
          if (evento.key === "Enter") crear();
        }}
      />
      <Campo
        etiqueta="Materia"
        placeholder="Ej: Biología"
        value={materia}
        onChange={(evento) => setMateria(evento.target.value)}
        onKeyDown={(evento) => {
          if (evento.key === "Enter") crear();
        }}
      />
      <Boton onClick={crear} disabled={!nombre.trim()} className="h-11">
        Agregar tema
      </Boton>
    </div>
  );
}

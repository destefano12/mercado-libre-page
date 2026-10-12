"use client";

import { useEffect } from "react";
import type { CategoryId } from "../../data/marketplace";
import {
  registrarBusqueda,
  registrarCategoria,
  registrarVisto,
} from "../../lib/personalizacion";

/**
 * No dibuja nada: mira que producto, busqueda o categoria se esta mostrando y
 * lo anota en la actividad del visitante, con o sin sesion iniciada.
 */
export function RegistroActividad({
  usuarioId,
  listingId,
  consulta,
  categoriaId,
}: {
  usuarioId: string | null;
  listingId: string | null;
  consulta: string;
  categoriaId: CategoryId | null;
}) {
  useEffect(() => {
    if (listingId) registrarVisto(usuarioId, listingId);
  }, [usuarioId, listingId]);

  useEffect(() => {
    if (consulta) registrarBusqueda(usuarioId, consulta);
  }, [usuarioId, consulta]);

  useEffect(() => {
    if (categoriaId) registrarCategoria(usuarioId, categoriaId);
  }, [usuarioId, categoriaId]);

  return null;
}

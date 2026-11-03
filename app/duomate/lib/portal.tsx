"use client";

import { createContext, useContext } from "react";

/**
 * Raíz `.dm` de la página. Los paneles de Radix (Sheet) se montan ahí adentro en
 * vez de en <body>, así heredan los tokens de marca y la tipografía de Duomate.
 */
export const RaizDuomate = createContext<HTMLElement | null>(null);

export const useRaizDuomate = () => useContext(RaizDuomate);

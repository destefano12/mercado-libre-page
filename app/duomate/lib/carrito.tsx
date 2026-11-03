"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useReducer, useRef, useState } from "react";
import { COSTO_ENVIO, CUPONES, ENVIO_GRATIS_DESDE, PRODUCTOS, type Producto } from "./catalogo";

export type Linea = { clave: string; id: string; variante: string; cantidad: number };

type Accion =
  | { tipo: "agregar"; id: string; variante: string; cantidad: number }
  | { tipo: "cantidad"; clave: string; cantidad: number }
  | { tipo: "quitar"; clave: string }
  | { tipo: "vaciar" }
  | { tipo: "cargar"; lineas: Linea[] }
  | { tipo: "cupon"; cupon: string | null };

type Estado = { lineas: Linea[]; cupon: string | null };

const LIMITE = 20;

function reductor(estado: Estado, a: Accion): Estado {
  if (a.tipo === "cupon") return { ...estado, cupon: a.cupon };
  if (a.tipo === "vaciar") return { lineas: [], cupon: null };
  return { ...estado, lineas: reductorLineas(estado.lineas, a) };
}

function reductorLineas(lineas: Linea[], a: Accion): Linea[] {
  switch (a.tipo) {
    case "agregar": {
      const clave = `${a.id}__${a.variante}`;
      const existe = lineas.find((l) => l.clave === clave);
      if (existe) {
        return lineas.map((l) => (l.clave === clave ? { ...l, cantidad: Math.min(LIMITE, l.cantidad + a.cantidad) } : l));
      }
      return [...lineas, { clave, id: a.id, variante: a.variante, cantidad: Math.min(LIMITE, a.cantidad) }];
    }
    case "cantidad":
      return a.cantidad <= 0
        ? lineas.filter((l) => l.clave !== a.clave)
        : lineas.map((l) => (l.clave === a.clave ? { ...l, cantidad: Math.min(LIMITE, a.cantidad) } : l));
    case "quitar":
      return lineas.filter((l) => l.clave !== a.clave);
    case "cargar":
      return a.lineas;
    default:
      return lineas;
  }
}

export type Vuelo = { id: number; x: number; y: number; dx: number; dy: number; color: string };

type Contexto = {
  lineas: (Linea & { producto: Producto })[];
  unidades: number;
  subtotal: number;
  descuento: number;
  envio: number;
  total: number;
  faltaEnvioGratis: number;
  cupon: string | null;
  aplicarCupon: (codigo: string) => boolean;
  quitarCupon: () => void;
  modoEntrega: "retiro" | "envio";
  setModoEntrega: (m: "retiro" | "envio") => void;
  agregar: (p: Producto, variante: string, cantidad?: number, origen?: DOMRect | null) => void;
  cambiarCantidad: (clave: string, cantidad: number) => void;
  quitar: (clave: string) => void;
  vaciar: () => void;
  abierto: boolean;
  setAbierto: (v: boolean) => void;
  vuelos: Vuelo[];
  terminarVuelo: (id: number) => void;
  destinoRef: React.RefObject<HTMLButtonElement | null>;
  pulso: number;
  aviso: string | null;
};

const Ctx = createContext<Contexto | null>(null);
const CLAVE_STORAGE = "duomate-carrito-v1";

export function CarritoProvider({ children }: { children: React.ReactNode }) {
  const [{ lineas, cupon }, despachar] = useReducer(reductor, { lineas: [], cupon: null });
  const saltarGuardado = useRef(true);
  const [abierto, setAbierto] = useState(false);
  const [modoEntrega, setModoEntrega] = useState<"retiro" | "envio">("retiro");
  const [vuelos, setVuelos] = useState<Vuelo[]>([]);
  const [pulso, setPulso] = useState(0);
  const [aviso, setAviso] = useState<string | null>(null);
  const destinoRef = useRef<HTMLButtonElement | null>(null);
  const timerAviso = useRef<ReturnType<typeof setTimeout> | null>(null);

  // El carrito se guarda en este navegador para que no se pierda al recargar.
  useEffect(() => {
    try {
      const crudo = localStorage.getItem(CLAVE_STORAGE);
      if (crudo) {
        const datos = JSON.parse(crudo) as { lineas?: Linea[]; cupon?: string | null };
        const validas = (datos.lineas ?? []).filter((l) => PRODUCTOS.some((p) => p.id === l.id));
        despachar({ tipo: "cargar", lineas: validas });
        if (datos.cupon && CUPONES[datos.cupon]) despachar({ tipo: "cupon", cupon: datos.cupon });
      }
    } catch {
      /* almacenamiento no disponible: el carrito vive solo en memoria */
    }
  }, []);

  useEffect(() => {
    // La primera pasada todavía tiene el carrito vacío: no hay que pisar lo guardado.
    if (saltarGuardado.current) {
      saltarGuardado.current = false;
      return;
    }
    try {
      localStorage.setItem(CLAVE_STORAGE, JSON.stringify({ lineas, cupon }));
    } catch {
      /* ignorar */
    }
  }, [lineas, cupon]);

  const avisar = useCallback((texto: string) => {
    setAviso(texto);
    if (timerAviso.current) clearTimeout(timerAviso.current);
    timerAviso.current = setTimeout(() => setAviso(null), 2600);
  }, []);

  const agregar = useCallback<Contexto["agregar"]>(
    (p, variante, cantidad = 1, origen) => {
      despachar({ tipo: "agregar", id: p.id, variante, cantidad });
      const color = p.variantes.find((v) => v.nombre === variante)?.color ?? "#2f5a3e";
      if (origen) {
        const destino = destinoRef.current?.getBoundingClientRect();
        const dx = destino ? destino.left + destino.width / 2 : window.innerWidth - 40;
        const dy = destino ? destino.top + destino.height / 2 : 30;
        setVuelos((v) => [...v, { id: Date.now() + Math.random(), x: origen.left + origen.width / 2, y: origen.top + origen.height / 2, dx, dy, color }]);
      } else {
        setPulso((n) => n + 1);
      }
      avisar(`${p.nombre} se agregó al carrito`);
    },
    [avisar],
  );

  const terminarVuelo = useCallback((id: number) => {
    setVuelos((v) => v.filter((x) => x.id !== id));
    setPulso((n) => n + 1);
  }, []);

  const valor = useMemo<Contexto>(() => {
    const conProducto = lineas
      .map((l) => ({ ...l, producto: PRODUCTOS.find((p) => p.id === l.id)! }))
      .filter((l) => l.producto);
    const unidades = conProducto.reduce((s, l) => s + l.cantidad, 0);
    const subtotal = conProducto.reduce((s, l) => s + l.cantidad * l.producto.precio, 0);
    const descuento = cupon ? Math.round(subtotal * (CUPONES[cupon] ?? 0)) : 0;
    const base = subtotal - descuento;
    const envio = modoEntrega === "retiro" || base >= ENVIO_GRATIS_DESDE || unidades === 0 ? 0 : COSTO_ENVIO;
    return {
      lineas: conProducto,
      unidades,
      subtotal,
      descuento,
      envio,
      total: base + envio,
      faltaEnvioGratis: Math.max(0, ENVIO_GRATIS_DESDE - base),
      cupon,
      aplicarCupon: (codigo) => {
        const c = codigo.trim().toUpperCase();
        if (CUPONES[c]) {
          despachar({ tipo: "cupon", cupon: c });
          return true;
        }
        return false;
      },
      quitarCupon: () => despachar({ tipo: "cupon", cupon: null }),
      modoEntrega,
      setModoEntrega,
      agregar,
      cambiarCantidad: (clave, cantidad) => despachar({ tipo: "cantidad", clave, cantidad }),
      quitar: (clave) => despachar({ tipo: "quitar", clave }),
      vaciar: () => despachar({ tipo: "vaciar" }),
      abierto,
      setAbierto,
      vuelos,
      terminarVuelo,
      destinoRef,
      pulso,
      aviso,
    };
  }, [lineas, cupon, modoEntrega, agregar, abierto, vuelos, terminarVuelo, pulso, aviso]);

  return <Ctx.Provider value={valor}>{children}</Ctx.Provider>;
}

export function useCarrito() {
  const c = useContext(Ctx);
  if (!c) throw new Error("useCarrito necesita CarritoProvider");
  return c;
}

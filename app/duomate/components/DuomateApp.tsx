"use client";

import { MotionConfig } from "framer-motion";
import { useCallback, useState } from "react";
import type { Categoria, Producto } from "../lib/catalogo";
import { CarritoProvider, useCarrito } from "../lib/carrito";
import { RaizDuomate } from "../lib/portal";
import { Aviso, Carrito, Checkout, VistaRapida, Vuelos } from "./Paneles";
import { RitualScroll } from "./RitualScroll";
import { Beneficios, Encabezado, Hero, Marquesina, Newsletter, Opiniones, Pie, Sucursal } from "./Secciones";
import { Tienda } from "./Tienda";

export function DuomateApp() {
  return (
    <CarritoProvider>
      {/* Con "user", framer-motion desactiva las animaciones de movimiento si el sistema pide menos movimiento. */}
      <MotionConfig reducedMotion="user">
        <Pagina />
      </MotionConfig>
    </CarritoProvider>
  );
}

function Pagina() {
  const [vista, setVista] = useState<Producto | null>(null);
  const [checkout, setCheckout] = useState(false);
  const [categoria, setCategoria] = useState<Categoria | "todo">("todo");
  const [raiz, setRaiz] = useState<HTMLDivElement | null>(null);
  const { setAbierto } = useCarrito();
  const cerrarVista = useCallback(() => setVista(null), []);
  const cerrarCheckout = useCallback(() => setCheckout(false), []);

  return (
    <RaizDuomate.Provider value={raiz}>
      <div className="dm" ref={setRaiz}>
        <a className="dm-saltar" href="#tienda">
          Saltar a la tienda
        </a>
        <Encabezado />
        <main>
          <Hero onVer={setVista} onCategoria={setCategoria} />
          <Marquesina />
          <RitualScroll />
          <Beneficios />
          <Tienda onVer={setVista} categoria={categoria} setCategoria={setCategoria} />
          <Sucursal />
          <Opiniones />
          <Newsletter />
        </main>
        <Pie />

        <VistaRapida producto={vista} cerrar={cerrarVista} />
        <Carrito
          onCheckout={() => {
            setAbierto(false);
            setTimeout(() => setCheckout(true), 250);
          }}
        />
        <Checkout abierto={checkout} cerrar={cerrarCheckout} />
        <Vuelos />
        <Aviso />
      </div>
    </RaizDuomate.Provider>
  );
}

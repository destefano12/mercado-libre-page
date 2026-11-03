"use client";

import { MotionConfig } from "framer-motion";
import { useCallback, useState } from "react";
import type { Producto } from "../lib/catalogo";
import { CarritoProvider, useCarrito } from "../lib/carrito";
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
  const { setAbierto } = useCarrito();
  const cerrarVista = useCallback(() => setVista(null), []);
  const cerrarCheckout = useCallback(() => setCheckout(false), []);

  return (
    <div className="dm">
      <a className="dm-saltar" href="#tienda">
        Saltar a la tienda
      </a>
      <Encabezado />
      <main>
        <Hero onVer={setVista} />
        <Marquesina />
        <RitualScroll />
        <Beneficios />
        <Tienda onVer={setVista} />
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
  );
}

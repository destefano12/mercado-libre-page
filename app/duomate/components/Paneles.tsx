"use client";

import { AnimatePresence, motion } from "framer-motion";
import { Landmark, Smartphone, Store } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { PaymentMethodSelector, type PaymentMethod } from "@/components/ui/payment-1";
import { COSTO_ENVIO, ENVIO_GRATIS_DESDE, formatearPrecio, type Producto } from "../lib/catalogo";
import { useCarrito } from "../lib/carrito";
import { ArteProducto } from "./ArteProducto";
import {
  Estrellas,
  IconoBasura,
  IconoBolsa,
  IconoCamion,
  IconoCerrar,
  IconoCheck,
  IconoEscudo,
  IconoMas,
  IconoMenos,
  IconoTicket,
  IconoTienda,
} from "./Iconos";

/** Cierra con Escape, bloquea el scroll del fondo y devuelve el foco al cerrar. */
function useDialogo(abierto: boolean, cerrar: () => void) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!abierto) return;
    const previo = document.activeElement as HTMLElement | null;
    const overflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const t = setTimeout(() => ref.current?.querySelector<HTMLElement>("[data-autofoco], button, input")?.focus(), 60);
    const alTeclear = (e: KeyboardEvent) => {
      if (e.key === "Escape") cerrar();
      if (e.key === "Tab" && ref.current) {
        const focos = ref.current.querySelectorAll<HTMLElement>('button:not([disabled]), input, select, textarea, a[href]');
        if (!focos.length) return;
        const primero = focos[0];
        const ultimo = focos[focos.length - 1];
        if (e.shiftKey && document.activeElement === primero) {
          e.preventDefault();
          ultimo.focus();
        } else if (!e.shiftKey && document.activeElement === ultimo) {
          e.preventDefault();
          primero.focus();
        }
      }
    };
    document.addEventListener("keydown", alTeclear);
    return () => {
      clearTimeout(t);
      document.body.style.overflow = overflow;
      document.removeEventListener("keydown", alTeclear);
      previo?.focus?.();
    };
  }, [abierto, cerrar]);
  return ref;
}

const fondo = {
  initial: { opacity: 0 },
  animate: { opacity: 1 },
  exit: { opacity: 0 },
  transition: { duration: 0.25 },
};

/* ---------------------------------- Vista rápida ---------------------------------- */

export function VistaRapida({ producto, cerrar }: { producto: Producto | null; cerrar: () => void }) {
  const ref = useDialogo(!!producto, cerrar);
  return (
    <AnimatePresence>
      {producto && (
        <motion.div className="dm-capa" {...fondo} onClick={cerrar}>
          <motion.div
            ref={ref}
            role="dialog"
            aria-modal="true"
            aria-labelledby="vr-titulo"
            className="dm-modal dm-vista"
            initial={{ opacity: 0, y: 40, scale: 0.96 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 30, scale: 0.97 }}
            transition={{ type: "spring", stiffness: 320, damping: 30 }}
            onClick={(e) => e.stopPropagation()}
          >
            <ContenidoVista key={producto.id} producto={producto} cerrar={cerrar} />
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

function ContenidoVista({ producto: p, cerrar }: { producto: Producto; cerrar: () => void }) {
  const { agregar, setAbierto } = useCarrito();
  const [variante, setVariante] = useState(p.variantes[0].nombre);
  const [cantidad, setCantidad] = useState(1);
  const color = p.variantes.find((v) => v.nombre === variante)?.color ?? p.variantes[0].color;
  const botonRef = useRef<HTMLButtonElement>(null);

  return (
    <>
      <button className="dm-cerrar" onClick={cerrar} aria-label="Cerrar">
        <IconoCerrar />
      </button>
      <div className="dm-vista-arte" style={{ ["--tinte" as string]: color }}>
        <motion.div key={color} initial={{ rotate: -8, scale: 0.9, opacity: 0 }} animate={{ rotate: 0, scale: 1, opacity: 1 }} transition={{ type: "spring", stiffness: 200, damping: 16 }}>
          <ArteProducto arte={p.arte} color={color} className="dm-arte" />
        </motion.div>
      </div>
      <div className="dm-vista-info">
        {p.etiqueta && <span className="dm-sobretitulo">{p.etiqueta}</span>}
        <h2 id="vr-titulo">{p.nombre}</h2>
        <div className="dm-tarjeta-meta">
          <Estrellas valor={p.puntaje} />
          <span>
            {p.puntaje.toFixed(1)} · {p.opiniones} opiniones
          </span>
        </div>
        <div className="dm-precio dm-precio-grande">
          {p.precioAnterior && <span className="dm-precio-anterior">{formatearPrecio(p.precioAnterior)}</span>}
          <strong>{formatearPrecio(p.precio)}</strong>
          <span className="dm-cuotas">3 cuotas sin interés de {formatearPrecio(Math.round(p.precio / 3))}</span>
        </div>
        <p className="dm-vista-descripcion">{p.descripcion}</p>
        <ul className="dm-detalles">
          {p.detalles.map((d) => (
            <li key={d}>
              <IconoCheck size={16} /> {d}
            </li>
          ))}
        </ul>

        {p.variantes.length > 1 && (
          <fieldset className="dm-campo">
            <legend>
              Variante: <strong>{variante}</strong>
            </legend>
            <div className="dm-variantes">
              {p.variantes.map((v) => (
                <button
                  key={v.nombre}
                  aria-pressed={variante === v.nombre}
                  aria-label={v.nombre}
                  title={v.nombre}
                  className={`dm-muestra dm-muestra-grande ${variante === v.nombre ? "es-activo" : ""}`}
                  style={{ background: v.color }}
                  onClick={() => setVariante(v.nombre)}
                />
              ))}
            </div>
          </fieldset>
        )}

        <div className="dm-vista-acciones">
          <Contador valor={cantidad} onCambio={setCantidad} max={Math.min(p.stock, 20)} etiqueta={p.nombre} />
          <motion.button
            ref={botonRef}
            className="dm-boton dm-boton-principal dm-boton-ancho"
            whileTap={{ scale: 0.97 }}
            onClick={() => {
              agregar(p, variante, cantidad, botonRef.current?.getBoundingClientRect() ?? null);
              cerrar();
              setTimeout(() => setAbierto(true), 650);
            }}
          >
            <IconoBolsa size={18} /> Agregar · {formatearPrecio(p.precio * cantidad)}
          </motion.button>
        </div>
        <p className="dm-vista-nota">
          <IconoTienda size={16} /> {p.stock > 10 ? "Disponible para retirar hoy en la sucursal" : `Últimas ${p.stock} unidades en la sucursal`}
        </p>
      </div>
    </>
  );
}

function Contador({ valor, onCambio, max = 20, etiqueta }: { valor: number; onCambio: (n: number) => void; max?: number; etiqueta: string }) {
  return (
    <div className="dm-contador" role="group" aria-label={`Cantidad de ${etiqueta}`}>
      <button onClick={() => onCambio(valor - 1)} disabled={valor <= 1} aria-label="Restar uno">
        <IconoMenos size={16} />
      </button>
      <AnimatePresence mode="popLayout" initial={false}>
        <motion.span key={valor} initial={{ y: -10, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: 10, opacity: 0 }} transition={{ duration: 0.15 }} aria-live="polite">
          {valor}
        </motion.span>
      </AnimatePresence>
      <button onClick={() => onCambio(valor + 1)} disabled={valor >= max} aria-label="Sumar uno">
        <IconoMas size={16} />
      </button>
    </div>
  );
}

/* ---------------------------------- Carrito ---------------------------------- */

export function Carrito({ onCheckout }: { onCheckout: () => void }) {
  const c = useCarrito();
  const cerrar = () => c.setAbierto(false);
  const ref = useDialogo(c.abierto, cerrar);
  const [codigo, setCodigo] = useState("");
  const [errorCupon, setErrorCupon] = useState(false);
  const progreso = Math.min(100, ((ENVIO_GRATIS_DESDE - c.faltaEnvioGratis) / ENVIO_GRATIS_DESDE) * 100);

  return (
    <AnimatePresence>
      {c.abierto && (
        <motion.div className="dm-capa dm-capa-derecha" {...fondo} onClick={cerrar}>
          <motion.aside
            ref={ref}
            role="dialog"
            aria-modal="true"
            aria-labelledby="carrito-titulo"
            className="dm-cajon"
            initial={{ x: "100%" }}
            animate={{ x: 0 }}
            exit={{ x: "100%" }}
            transition={{ type: "spring", stiffness: 300, damping: 34 }}
            onClick={(e) => e.stopPropagation()}
          >
            <header className="dm-cajon-cabecera">
              <h2 id="carrito-titulo">
                Tu carrito <span>{c.unidades}</span>
              </h2>
              <button className="dm-cerrar dm-cerrar-estatico" onClick={cerrar} aria-label="Cerrar carrito">
                <IconoCerrar />
              </button>
            </header>

            {c.lineas.length === 0 ? (
              <div className="dm-cajon-vacio">
                <motion.div initial={{ scale: 0.8, rotate: -10 }} animate={{ scale: 1, rotate: 0 }} transition={{ type: "spring", stiffness: 200, damping: 12 }}>
                  <ArteProducto arte="calabaza" color="#b88a4a" className="dm-arte-vacio" />
                </motion.div>
                <h3>Tu mate está vacío</h3>
                <p>Sumá productos de la tienda y retiralos hoy en la sucursal.</p>
                <a className="dm-boton dm-boton-principal" href="#tienda" onClick={cerrar}>
                  Ir a la tienda
                </a>
              </div>
            ) : (
              <>
                <div className="dm-envio-barra">
                  <p>
                    {c.modoEntrega === "retiro" ? (
                      <>
                        <IconoTienda size={16} /> Retiro en sucursal <strong>gratis</strong>
                      </>
                    ) : c.faltaEnvioGratis > 0 ? (
                      <>
                        <IconoCamion size={16} /> Te faltan <strong>{formatearPrecio(c.faltaEnvioGratis)}</strong> para el envío gratis
                      </>
                    ) : (
                      <>
                        <IconoCamion size={16} /> ¡Tenés <strong>envío gratis</strong>!
                      </>
                    )}
                  </p>
                  {c.modoEntrega === "envio" && (
                    <div className="dm-progreso" aria-hidden="true">
                      <motion.span initial={false} animate={{ width: `${progreso}%` }} transition={{ type: "spring", stiffness: 120, damping: 20 }} />
                    </div>
                  )}
                </div>

                <ul className="dm-lineas">
                  <AnimatePresence initial={false}>
                    {c.lineas.map((l) => {
                      const color = l.producto.variantes.find((v) => v.nombre === l.variante)?.color ?? l.producto.variantes[0].color;
                      return (
                        <motion.li
                          key={l.clave}
                          layout
                          initial={{ opacity: 0, x: 40 }}
                          animate={{ opacity: 1, x: 0 }}
                          exit={{ opacity: 0, x: 60, height: 0, marginBottom: 0, paddingTop: 0, paddingBottom: 0 }}
                          transition={{ type: "spring", stiffness: 300, damping: 30 }}
                          className="dm-linea"
                        >
                          <div className="dm-linea-arte" style={{ ["--tinte" as string]: color }}>
                            <ArteProducto arte={l.producto.arte} color={color} className="dm-arte" />
                          </div>
                          <div className="dm-linea-info">
                            <h3>{l.producto.nombre}</h3>
                            {l.producto.variantes.length > 1 && <p>{l.variante}</p>}
                            <div className="dm-linea-pie">
                              <Contador valor={l.cantidad} onCambio={(n) => c.cambiarCantidad(l.clave, n)} max={Math.min(l.producto.stock, 20)} etiqueta={l.producto.nombre} />
                              <strong>{formatearPrecio(l.producto.precio * l.cantidad)}</strong>
                            </div>
                          </div>
                          <button className="dm-quitar" onClick={() => c.quitar(l.clave)} aria-label={`Quitar ${l.producto.nombre}`}>
                            <IconoBasura size={17} />
                          </button>
                        </motion.li>
                      );
                    })}
                  </AnimatePresence>
                </ul>

                <footer className="dm-cajon-pie">
                  <div className="dm-entrega" role="radiogroup" aria-label="Forma de entrega">
                    {(["retiro", "envio"] as const).map((m) => (
                      <button key={m} role="radio" aria-checked={c.modoEntrega === m} className={c.modoEntrega === m ? "es-activo" : ""} onClick={() => c.setModoEntrega(m)}>
                        {c.modoEntrega === m && <motion.span layoutId="entrega-activa" className="dm-entrega-fondo" />}
                        <span>
                          {m === "retiro" ? <IconoTienda size={16} /> : <IconoCamion size={16} />}
                          {m === "retiro" ? "Retiro gratis" : `Envío ${formatearPrecio(COSTO_ENVIO)}`}
                        </span>
                      </button>
                    ))}
                  </div>

                  {c.cupon ? (
                    <div className="dm-cupon-aplicado">
                      <IconoTicket size={16} /> Cupón <strong>{c.cupon}</strong> aplicado
                      <button onClick={c.quitarCupon}>Quitar</button>
                    </div>
                  ) : (
                    <form
                      className="dm-cupon"
                      onSubmit={(e) => {
                        e.preventDefault();
                        const ok = c.aplicarCupon(codigo);
                        setErrorCupon(!ok);
                        if (ok) setCodigo("");
                      }}
                    >
                      <label className="dm-oculto" htmlFor="cupon">
                        Código de descuento
                      </label>
                      <input
                        id="cupon"
                        placeholder="Código (ej. DUO10)"
                        value={codigo}
                        onChange={(e) => {
                          setCodigo(e.target.value);
                          setErrorCupon(false);
                        }}
                        aria-invalid={errorCupon}
                        aria-describedby={errorCupon ? "cupon-error" : undefined}
                      />
                      <button type="submit">Aplicar</button>
                      {errorCupon && (
                        <span id="cupon-error" className="dm-error">
                          Ese código no existe.
                        </span>
                      )}
                    </form>
                  )}

                  <dl className="dm-totales">
                    <div>
                      <dt>Subtotal</dt>
                      <dd>{formatearPrecio(c.subtotal)}</dd>
                    </div>
                    {c.descuento > 0 && (
                      <div className="dm-total-descuento">
                        <dt>Descuento</dt>
                        <dd>-{formatearPrecio(c.descuento)}</dd>
                      </div>
                    )}
                    <div>
                      <dt>{c.modoEntrega === "retiro" ? "Retiro" : "Envío"}</dt>
                      <dd>{c.envio === 0 ? "Gratis" : formatearPrecio(c.envio)}</dd>
                    </div>
                    <div className="dm-total-final">
                      <dt>Total</dt>
                      <dd>
                        <AnimatePresence mode="popLayout" initial={false}>
                          <motion.span key={c.total} initial={{ y: -12, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: 12, opacity: 0 }}>
                            {formatearPrecio(c.total)}
                          </motion.span>
                        </AnimatePresence>
                      </dd>
                    </div>
                  </dl>

                  <motion.button className="dm-boton dm-boton-principal dm-boton-ancho" whileTap={{ scale: 0.98 }} onClick={onCheckout}>
                    Finalizar compra
                  </motion.button>
                  <p className="dm-seguro">
                    <IconoEscudo size={15} /> Reservamos tu pedido y pagás al retirar o por transferencia
                  </p>
                </footer>
              </>
            )}
          </motion.aside>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

/* ----------------------------- Animación "vuela al carrito" ----------------------------- */

export function Vuelos() {
  const { vuelos, terminarVuelo } = useCarrito();
  return (
    <div className="dm-vuelos" aria-hidden="true">
      <AnimatePresence>
        {vuelos.map((v) => {
          const { dx, dy } = v;
          return (
            <motion.span
              key={v.id}
              className="dm-vuelo"
              style={{ background: v.color }}
              initial={{ x: v.x - 14, y: v.y - 14, scale: 1, opacity: 1 }}
              animate={{
                x: [v.x - 14, (v.x + dx) / 2 - 14, dx - 14],
                y: [v.y - 14, Math.min(v.y, dy) - 120, dy - 14],
                scale: [1, 1.2, 0.35],
                opacity: [1, 1, 0.6],
              }}
              transition={{ duration: 0.75, ease: [0.5, 0, 0.3, 1] }}
              onAnimationComplete={() => terminarVuelo(v.id)}
            />
          );
        })}
      </AnimatePresence>
    </div>
  );
}

export function Aviso() {
  const { aviso, setAbierto, abierto } = useCarrito();
  return (
    <div className="dm-aviso-zona" aria-live="polite">
      <AnimatePresence>
        {aviso && !abierto && (
          <motion.div
            key={aviso}
            className="dm-aviso"
            initial={{ opacity: 0, y: 30, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 20, scale: 0.95 }}
            transition={{ type: "spring", stiffness: 380, damping: 28 }}
          >
            <span className="dm-aviso-icono">
              <IconoCheck size={16} />
            </span>
            {aviso}
            <button onClick={() => setAbierto(true)}>Ver carrito</button>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

/* ---------------------------------- Checkout ---------------------------------- */

type Pago = "sucursal" | "transferencia" | "link";

const iconoPago = (Icono: typeof Store) => (
  <span className="flex h-10 w-10 items-center justify-center rounded-lg bg-muted text-primary">
    <Icono className="h-5 w-5" aria-hidden="true" />
  </span>
);

const METODOS_PAGO: PaymentMethod[] = [
  { id: "sucursal", icon: iconoPago(Store), label: "Pagar en la sucursal", description: "Efectivo, débito o crédito al retirar" },
  { id: "transferencia", icon: iconoPago(Landmark), label: "Transferencia bancaria", description: "Te pasamos el alias por WhatsApp" },
  { id: "link", icon: iconoPago(Smartphone), label: "Link de pago", description: "Hasta 3 cuotas sin interés" },
];

export function Checkout({ abierto, cerrar }: { abierto: boolean; cerrar: () => void }) {
  const c = useCarrito();
  const ref = useDialogo(abierto, cerrar);
  const [paso, setPaso] = useState<"datos" | "listo">("datos");
  const [pago, setPago] = useState<Pago>("sucursal");
  const [datos, setDatos] = useState({ nombre: "", telefono: "", email: "", direccion: "", notas: "" });
  const [errores, setErrores] = useState<Record<string, string>>({});
  const [pedido, setPedido] = useState<{ codigo: string; total: number; retiro: boolean } | null>(null);

  // Al volver a abrirlo, arranca otra vez desde el formulario.
  const [abiertoAntes, setAbiertoAntes] = useState(abierto);
  if (abierto !== abiertoAntes) {
    setAbiertoAntes(abierto);
    if (abierto) setPaso("datos");
  }

  const validar = () => {
    const e: Record<string, string> = {};
    if (datos.nombre.trim().length < 2) e.nombre = "Escribí tu nombre.";
    if (datos.telefono.replace(/\D/g, "").length < 8) e.telefono = "Necesitamos un teléfono válido para avisarte.";
    if (!/^\S+@\S+\.\S+$/.test(datos.email)) e.email = "Revisá el formato del email.";
    if (c.modoEntrega === "envio" && datos.direccion.trim().length < 5) e.direccion = "Indicá la dirección de entrega.";
    setErrores(e);
    return Object.keys(e).length === 0;
  };

  const confirmar = (ev: React.FormEvent) => {
    ev.preventDefault();
    if (!validar()) {
      ref.current?.querySelector<HTMLElement>("[aria-invalid='true']")?.focus();
      return;
    }
    setPedido({ codigo: `DM-${Math.floor(100000 + Math.random() * 900000)}`, total: c.total, retiro: c.modoEntrega === "retiro" });
    setPaso("listo");
    c.vaciar();
  };

  const campo = (id: keyof typeof datos, etiqueta: string, tipo = "text", extra: React.InputHTMLAttributes<HTMLInputElement> = {}) => (
    <div className="dm-campo-texto">
      <label htmlFor={`co-${id}`}>{etiqueta}</label>
      <input
        id={`co-${id}`}
        type={tipo}
        value={datos[id]}
        onChange={(e) => setDatos((d) => ({ ...d, [id]: e.target.value }))}
        aria-invalid={!!errores[id]}
        aria-describedby={errores[id] ? `co-${id}-error` : undefined}
        {...extra}
      />
      {errores[id] && (
        <span id={`co-${id}-error`} className="dm-error">
          {errores[id]}
        </span>
      )}
    </div>
  );

  return (
    <AnimatePresence>
      {abierto && (
        <motion.div className="dm-capa" {...fondo} onClick={cerrar}>
          <motion.div
            ref={ref}
            role="dialog"
            aria-modal="true"
            aria-labelledby="co-titulo"
            className="dm-modal dm-checkout"
            initial={{ opacity: 0, y: 40, scale: 0.96 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 30, scale: 0.97 }}
            transition={{ type: "spring", stiffness: 320, damping: 30 }}
            onClick={(e) => e.stopPropagation()}
          >
            <button className="dm-cerrar" onClick={cerrar} aria-label="Cerrar">
              <IconoCerrar />
            </button>
            <AnimatePresence mode="wait">
              {paso === "datos" ? (
                <motion.form key="datos" onSubmit={confirmar} noValidate initial={{ opacity: 0, x: -20 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -30 }}>
                  <span className="dm-sobretitulo">Paso final</span>
                  <h2 id="co-titulo">Confirmá tu pedido</h2>
                  <p className="dm-checkout-resumen">
                    {c.unidades} {c.unidades === 1 ? "producto" : "productos"} · {c.modoEntrega === "retiro" ? "Retiro en sucursal" : "Envío a domicilio"} ·{" "}
                    <strong>{formatearPrecio(c.total)}</strong>
                  </p>

                  <div className="dm-grilla-campos">
                    {campo("nombre", "Nombre y apellido", "text", { autoComplete: "name" })}
                    {campo("telefono", "Teléfono / WhatsApp", "tel", { autoComplete: "tel", inputMode: "tel" })}
                    {campo("email", "Email", "email", { autoComplete: "email" })}
                    {c.modoEntrega === "envio" && campo("direccion", "Dirección de entrega", "text", { autoComplete: "street-address" })}
                  </div>

                  <PaymentMethodSelector
                    className="dm-ui dm-selector-pago"
                    title="¿Cómo querés pagar?"
                    methods={METODOS_PAGO}
                    defaultSelectedId={pago}
                    onSelectionChange={(id) => setPago(id as Pago)}
                  />

                  <div className="dm-campo-texto">
                    <label htmlFor="co-notas">Notas (opcional)</label>
                    <textarea id="co-notas" rows={2} value={datos.notas} onChange={(e) => setDatos((d) => ({ ...d, notas: e.target.value }))} placeholder="Ej.: es para regalo, ¿lo envuelven?" />
                  </div>

                  <button type="submit" className="dm-boton dm-boton-principal dm-boton-ancho">
                    Confirmar pedido · {formatearPrecio(c.total)}
                  </button>
                  <p className="dm-seguro">
                    <IconoEscudo size={15} /> No pedimos datos de tarjeta en la web. Coordinamos el pago por WhatsApp o en la sucursal.
                  </p>
                </motion.form>
              ) : (
                <motion.div key="listo" className="dm-listo" initial={{ opacity: 0, scale: 0.9 }} animate={{ opacity: 1, scale: 1 }} transition={{ type: "spring", stiffness: 260, damping: 20 }}>
                  <motion.div className="dm-listo-icono" initial={{ scale: 0, rotate: -90 }} animate={{ scale: 1, rotate: 0 }} transition={{ delay: 0.15, type: "spring", stiffness: 260, damping: 14 }}>
                    <IconoCheck size={40} />
                  </motion.div>
                  <h2 id="co-titulo">¡Pedido confirmado!</h2>
                  <p>
                    Tu número de pedido es <strong className="dm-codigo">{pedido?.codigo}</strong>
                  </p>
                  <p>
                    {pedido?.retiro
                      ? "Te escribimos por WhatsApp cuando esté listo para retirar (normalmente en menos de 2 horas)."
                      : "Te escribimos por WhatsApp para coordinar el envío."}
                  </p>
                  <p className="dm-listo-total">Total: {formatearPrecio(pedido?.total ?? 0)}</p>
                  <button className="dm-boton dm-boton-principal" onClick={cerrar} data-autofoco>
                    Seguir comprando
                  </button>
                </motion.div>
              )}
            </AnimatePresence>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

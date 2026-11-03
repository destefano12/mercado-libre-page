"use client";

import { AnimatePresence, motion } from "framer-motion";
import { Landmark, Smartphone, Store } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { PaymentMethodSelector, type PaymentMethod } from "@/components/ui/payment-1";
import { Separator } from "@/components/ui/separator";
import { Sheet, SheetClose, SheetContent, SheetDescription, SheetHeader, SheetTitle } from "@/components/ui/sheet";
import { cn } from "@/lib/utils";
import { COSTO_ENVIO, ENVIO_GRATIS_DESDE, formatearPrecio, type Producto } from "../lib/catalogo";
import { useCarrito } from "../lib/carrito";
import { useRaizDuomate } from "../lib/portal";
import { ArteProducto } from "./ArteProducto";
import {
  Estrellas,
  IconoBasura,
  IconoBolsa,
  IconoCamion,
  IconoCerrar,
  IconoCheck,
  IconoEscudo,
  IconoFlecha,
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

/*
 * Cajón del carrito: Sheet de Radix (instalado desde 21st con Commerce Hero).
 * Radix se ocupa del foco, Escape, bloqueo de scroll y aria; acá solo va el contenido.
 */
export function Carrito({ onCheckout }: { onCheckout: () => void }) {
  const c = useCarrito();
  const raiz = useRaizDuomate();
  const [codigo, setCodigo] = useState("");
  const [errorCupon, setErrorCupon] = useState(false);
  const progreso = Math.min(100, ((ENVIO_GRATIS_DESDE - c.faltaEnvioGratis) / ENVIO_GRATIS_DESDE) * 100);

  return (
    <Sheet open={c.abierto} onOpenChange={c.setAbierto}>
      <SheetContent
        side="right"
        container={raiz}
        closeLabel="Cerrar carrito"
        overlayClassName="bg-[rgb(18_26_20/0.5)] backdrop-blur-[3px]"
        className="flex w-full flex-col gap-0 border-l-0 bg-background p-0 sm:max-w-[460px]"
      >
        <SheetHeader className="space-y-1 border-b px-6 pb-4 pt-6 text-left">
          <SheetTitle className="flex items-center gap-2.5 font-serif text-[26px] font-semibold text-primary">
            Tu carrito
            <Badge className="h-6 min-w-6 justify-center rounded-full bg-destructive px-2 text-destructive-foreground hover:bg-destructive">{c.unidades}</Badge>
          </SheetTitle>
          <SheetDescription>
            {c.lineas.length === 0 ? "Todavía no sumaste productos." : "Reservamos tu pedido en la sucursal Palermo."}
          </SheetDescription>
        </SheetHeader>

        {c.lineas.length === 0 ? (
          <div className="flex flex-1 flex-col items-center justify-center gap-3 p-8 text-center text-muted-foreground">
            <motion.div initial={{ scale: 0.8, rotate: -10 }} animate={{ scale: 1, rotate: 0 }} transition={{ type: "spring", stiffness: 200, damping: 12 }}>
              <ArteProducto arte="calabaza" color="#b88a4a" className="dm-arte-vacio" />
            </motion.div>
            <h3 className="font-serif text-2xl font-semibold text-primary">Tu mate está vacío</h3>
            <p className="max-w-[28ch]">Sumá productos de la tienda y retiralos hoy en la sucursal.</p>
            <SheetClose asChild>
              <Button asChild className="mt-2 h-11 rounded-full px-6 font-bold">
                <a href="#tienda">Ir a la tienda</a>
              </Button>
            </SheetClose>
          </div>
        ) : (
          <>
            <div className="border-b bg-accent/40 px-6 py-3 text-sm">
              <p className="flex items-center gap-2 text-foreground">
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
                <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-border" aria-hidden="true">
                  <motion.span
                    className="block h-full rounded-full bg-[hsl(var(--accent-strong))]"
                    initial={false}
                    animate={{ width: `${progreso}%` }}
                    transition={{ type: "spring", stiffness: 120, damping: 20 }}
                  />
                </div>
              )}
            </div>

            <ul className="flex-1 overflow-y-auto px-6 py-2" aria-label="Productos en el carrito">
              <AnimatePresence initial={false}>
                {c.lineas.map((l) => {
                  const color = l.producto.variantes.find((v) => v.nombre === l.variante)?.color ?? l.producto.variantes[0].color;
                  return (
                    <motion.li
                      key={l.clave}
                      layout
                      initial={{ opacity: 0, x: 40 }}
                      animate={{ opacity: 1, x: 0 }}
                      exit={{ opacity: 0, x: 60, height: 0, paddingTop: 0, paddingBottom: 0 }}
                      transition={{ type: "spring", stiffness: 300, damping: 30 }}
                      className="flex gap-4 overflow-hidden border-b py-4 last:border-b-0"
                    >
                      <div
                        className="grid h-20 w-20 shrink-0 place-items-center rounded-[14px] p-2"
                        style={{ background: `color-mix(in srgb, ${color} 12%, hsl(var(--secondary)))` }}
                      >
                        <ArteProducto arte={l.producto.arte} color={color} className="dm-arte" />
                      </div>
                      <div className="flex min-w-0 flex-1 flex-col gap-1">
                        <div className="flex items-start justify-between gap-2">
                          <div className="min-w-0">
                            <h3 className="text-[15px] font-bold leading-tight">{l.producto.nombre}</h3>
                            {l.producto.variantes.length > 1 && <p className="text-xs text-muted-foreground">{l.variante}</p>}
                          </div>
                          <Button
                            variant="ghost"
                            size="icon"
                            className="-mr-2 -mt-1 h-9 w-9 shrink-0 rounded-full text-muted-foreground hover:bg-destructive/10 hover:text-destructive"
                            onClick={() => c.quitar(l.clave)}
                            aria-label={`Quitar ${l.producto.nombre}`}
                          >
                            <IconoBasura size={17} />
                          </Button>
                        </div>
                        <div className="mt-auto flex items-center justify-between gap-2">
                          <Contador valor={l.cantidad} onCambio={(n) => c.cambiarCantidad(l.clave, n)} max={Math.min(l.producto.stock, 20)} etiqueta={l.producto.nombre} />
                          <strong className="text-[15px]">{formatearPrecio(l.producto.precio * l.cantidad)}</strong>
                        </div>
                      </div>
                    </motion.li>
                  );
                })}
              </AnimatePresence>
            </ul>

            <div className="space-y-4 border-t bg-card px-6 pb-6 pt-4 shadow-[0_-12px_30px_rgb(31_61_43/0.06)]">
              <SelectorEntrega />

              {c.cupon ? (
                <div className="flex items-center gap-2 rounded-md bg-[hsl(var(--success)/0.1)] px-3 py-2.5 text-sm text-[hsl(var(--success))]">
                  <IconoTicket size={16} /> Cupón <strong>{c.cupon}</strong> aplicado
                  <Button variant="link" className="ml-auto h-auto p-0 text-[hsl(var(--success))]" onClick={c.quitarCupon}>
                    Quitar
                  </Button>
                </div>
              ) : (
                <form
                  className="space-y-1.5"
                  onSubmit={(e) => {
                    e.preventDefault();
                    const ok = c.aplicarCupon(codigo);
                    setErrorCupon(!ok);
                    if (ok) setCodigo("");
                  }}
                >
                  <Label htmlFor="cupon" className="sr-only">
                    Código de descuento
                  </Label>
                  <div className="flex gap-2">
                    <Input
                      id="cupon"
                      placeholder="Código (ej. DUO10)"
                      value={codigo}
                      className="h-11 rounded-full px-4 uppercase placeholder:normal-case aria-[invalid=true]:border-destructive"
                      onChange={(e) => {
                        setCodigo(e.target.value);
                        setErrorCupon(false);
                      }}
                      aria-invalid={errorCupon}
                      aria-describedby={errorCupon ? "cupon-error" : undefined}
                    />
                    <Button type="submit" variant="outline" className="h-11 rounded-full px-5 font-bold">
                      Aplicar
                    </Button>
                  </div>
                  {errorCupon && (
                    <p id="cupon-error" className="pl-4 text-xs font-semibold text-destructive">
                      Ese código no existe.
                    </p>
                  )}
                </form>
              )}

              <Totales />

              <Button className="h-12 w-full rounded-full text-base font-bold shadow-lg" onClick={onCheckout}>
                Finalizar compra · {formatearPrecio(c.total)}
              </Button>
              <p className="flex items-center justify-center gap-1.5 text-center text-xs text-muted-foreground">
                <IconoEscudo size={14} /> Reservamos tu pedido y pagás al retirar o por transferencia
              </p>
            </div>
          </>
        )}
      </SheetContent>
    </Sheet>
  );
}

function SelectorEntrega() {
  const c = useCarrito();
  return (
    <div className="grid grid-cols-2 gap-1 rounded-full bg-muted p-1" role="radiogroup" aria-label="Forma de entrega">
      {(["retiro", "envio"] as const).map((m) => {
        const activo = c.modoEntrega === m;
        return (
          <button
            key={m}
            type="button"
            role="radio"
            aria-checked={activo}
            onClick={() => c.setModoEntrega(m)}
            className={cn("relative h-10 rounded-full text-sm font-bold transition-colors", activo ? "text-primary-foreground" : "text-muted-foreground hover:text-foreground")}
          >
            {activo && <motion.span layoutId="entrega-activa" className="absolute inset-0 rounded-full bg-primary shadow" transition={{ type: "spring", stiffness: 420, damping: 34 }} />}
            <span className="relative inline-flex items-center gap-1.5">
              {m === "retiro" ? <IconoTienda size={16} /> : <IconoCamion size={16} />}
              {m === "retiro" ? "Retiro gratis" : `Envío ${formatearPrecio(COSTO_ENVIO)}`}
            </span>
          </button>
        );
      })}
    </div>
  );
}

/** Desglose del total (patrón "Checkout Summary" de 21st). */
function Totales({ compacto = false }: { compacto?: boolean }) {
  const c = useCarrito();
  const fila = "flex items-center justify-between";
  return (
    <dl className={cn("space-y-1.5 text-sm", compacto && "text-[13px]")}>
      <div className={fila}>
        <dt className="text-muted-foreground">Subtotal</dt>
        <dd>{formatearPrecio(c.subtotal)}</dd>
      </div>
      {c.descuento > 0 && (
        <div className={cn(fila, "text-[hsl(var(--success))]")}>
          <dt>Descuento {c.cupon}</dt>
          <dd>-{formatearPrecio(c.descuento)}</dd>
        </div>
      )}
      <div className={fila}>
        <dt className="text-muted-foreground">{c.modoEntrega === "retiro" ? "Retiro en sucursal" : "Envío"}</dt>
        <dd>{c.envio === 0 ? "Gratis" : formatearPrecio(c.envio)}</dd>
      </div>
      <Separator className="my-2" />
      <div className={cn(fila, "text-base font-bold")}>
        <dt>Total</dt>
        <dd className="overflow-hidden font-serif text-2xl text-primary">
          <AnimatePresence mode="popLayout" initial={false}>
            <motion.span key={c.total} className="inline-block" initial={{ y: -12, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: 12, opacity: 0 }}>
              {formatearPrecio(c.total)}
            </motion.span>
          </AnimatePresence>
        </dd>
      </div>
    </dl>
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

const NOMBRE_PAGO: Record<Pago, string> = { sucursal: "Pago en la sucursal", transferencia: "Transferencia bancaria", link: "Link de pago" };

const PASOS_CHECKOUT = [
  { id: "datos", titulo: "Tus datos" },
  { id: "pago", titulo: "Pago" },
  { id: "listo", titulo: "Listo" },
] as const;
type PasoCheckout = (typeof PASOS_CHECKOUT)[number]["id"];

/*
 * Checkout en pasos (patrón "Checkout Block" de 21st) dentro de un Sheet:
 * datos → pago y resumen → confirmación ("Order Confirmation Card").
 */
export function Checkout({ abierto, cerrar }: { abierto: boolean; cerrar: () => void }) {
  const c = useCarrito();
  const raiz = useRaizDuomate();
  const formRef = useRef<HTMLFormElement>(null);
  const [paso, setPaso] = useState<PasoCheckout>("datos");
  const [pago, setPago] = useState<Pago>("sucursal");
  const [datos, setDatos] = useState({ nombre: "", telefono: "", email: "", direccion: "", notas: "" });
  const [errores, setErrores] = useState<Record<string, string>>({});
  const [pedido, setPedido] = useState<{ codigo: string; total: number; retiro: boolean; pago: Pago; unidades: number } | null>(null);

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

  const continuar = (ev: React.FormEvent) => {
    ev.preventDefault();
    if (!validar()) {
      requestAnimationFrame(() => formRef.current?.querySelector<HTMLElement>("[aria-invalid='true']")?.focus());
      return;
    }
    setPaso("pago");
  };

  const confirmar = () => {
    setPedido({
      codigo: `DM-${Math.floor(100000 + Math.random() * 900000)}`,
      total: c.total,
      retiro: c.modoEntrega === "retiro",
      pago,
      unidades: c.unidades,
    });
    setPaso("listo");
    c.vaciar();
  };

  const indice = PASOS_CHECKOUT.findIndex((p) => p.id === paso);

  const campo = (id: keyof typeof datos, etiqueta: string, tipo = "text", extra: React.InputHTMLAttributes<HTMLInputElement> = {}) => (
    <div className="space-y-1.5">
      <Label htmlFor={`co-${id}`} className="text-[13px] font-bold text-foreground/80">
        {etiqueta}
      </Label>
      <Input
        id={`co-${id}`}
        type={tipo}
        value={datos[id]}
        className="h-11 rounded-[12px] bg-card text-[15px] aria-[invalid=true]:border-destructive aria-[invalid=true]:ring-destructive/30"
        onChange={(e) => {
          setDatos((d) => ({ ...d, [id]: e.target.value }));
          if (errores[id]) setErrores((er) => ({ ...er, [id]: "" }));
        }}
        aria-invalid={!!errores[id]}
        aria-describedby={errores[id] ? `co-${id}-error` : undefined}
        {...extra}
      />
      {errores[id] && (
        <p id={`co-${id}-error`} className="text-xs font-semibold text-destructive">
          {errores[id]}
        </p>
      )}
    </div>
  );

  return (
    <Sheet open={abierto} onOpenChange={(v) => !v && cerrar()}>
      <SheetContent
        side="right"
        container={raiz}
        overlayClassName="bg-[rgb(18_26_20/0.5)] backdrop-blur-[3px]"
        className="flex w-full flex-col gap-0 border-l-0 bg-background p-0 sm:max-w-[520px]"
      >
        <SheetHeader className="space-y-3 border-b px-6 pb-5 pt-6 text-left">
          <div>
            <span className="dm-sobretitulo">{paso === "listo" ? "Pedido" : "Paso final"}</span>
            <SheetTitle className="mt-1 font-serif text-[28px] font-semibold leading-tight text-primary">
              {paso === "listo" ? "¡Pedido confirmado!" : "Confirmá tu pedido"}
            </SheetTitle>
            <SheetDescription className="mt-1">
              {paso === "listo"
                ? "Te avisamos por WhatsApp cuando esté listo."
                : `${c.unidades} ${c.unidades === 1 ? "producto" : "productos"} · ${c.modoEntrega === "retiro" ? "Retiro en sucursal" : "Envío a domicilio"} · ${formatearPrecio(c.total)}`}
            </SheetDescription>
          </div>
          <ol className="flex items-center gap-2" aria-label="Pasos del checkout">
            {PASOS_CHECKOUT.map((p, i) => {
              const hecho = i < indice;
              const actual = i === indice;
              return (
                <li key={p.id} className="flex flex-1 items-center gap-2" aria-current={actual ? "step" : undefined}>
                  <span
                    className={cn(
                      "grid h-7 w-7 shrink-0 place-items-center rounded-full text-xs font-bold transition-colors",
                      hecho || actual ? "bg-primary text-primary-foreground" : "bg-muted text-muted-foreground",
                    )}
                  >
                    {hecho ? <IconoCheck size={14} /> : i + 1}
                  </span>
                  <span className={cn("text-xs font-bold", actual ? "text-foreground" : "text-muted-foreground")}>{p.titulo}</span>
                  {i < PASOS_CHECKOUT.length - 1 && (
                    <span className="h-0.5 flex-1 overflow-hidden rounded-full bg-muted">
                      <motion.span className="block h-full bg-primary" initial={false} animate={{ width: hecho ? "100%" : "0%" }} transition={{ duration: 0.4 }} />
                    </span>
                  )}
                </li>
              );
            })}
          </ol>
        </SheetHeader>

        <div className="flex-1 overflow-y-auto">
          <AnimatePresence mode="wait" initial={false}>
            {paso === "datos" && (
              <motion.form
                key="datos"
                ref={formRef}
                onSubmit={continuar}
                noValidate
                className="space-y-5 px-6 py-6"
                initial={{ opacity: 0, x: 24 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: -24 }}
                transition={{ duration: 0.22 }}
              >
                <section className="space-y-4" aria-labelledby="co-contacto">
                  <h3 id="co-contacto" className="text-sm font-bold uppercase tracking-wider text-muted-foreground">
                    Contacto
                  </h3>
                  {campo("nombre", "Nombre y apellido", "text", { autoComplete: "name" })}
                  <div className="grid gap-4 sm:grid-cols-2">
                    {campo("telefono", "Teléfono / WhatsApp", "tel", { autoComplete: "tel", inputMode: "tel" })}
                    {campo("email", "Email", "email", { autoComplete: "email" })}
                  </div>
                </section>
                <Separator />
                <section className="space-y-4" aria-labelledby="co-entrega">
                  <h3 id="co-entrega" className="text-sm font-bold uppercase tracking-wider text-muted-foreground">
                    Entrega
                  </h3>
                  <SelectorEntrega />
                  {c.modoEntrega === "envio" ? (
                    campo("direccion", "Dirección de entrega", "text", { autoComplete: "street-address" })
                  ) : (
                    <p className="flex items-start gap-2 rounded-[12px] bg-accent/50 p-3 text-sm">
                      <IconoTienda size={18} />
                      <span>
                        <strong className="block">Duomate Palermo · Gorriti 4820</strong>
                        <span className="text-muted-foreground">Listo para retirar en menos de 2 horas.</span>
                      </span>
                    </p>
                  )}
                </section>
                <Button type="submit" className="h-12 w-full rounded-full text-base font-bold shadow-lg">
                  Continuar al pago <IconoFlecha size={18} />
                </Button>
              </motion.form>
            )}

            {paso === "pago" && (
              <motion.div
                key="pago"
                className="space-y-5 px-6 py-6"
                initial={{ opacity: 0, x: 24 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: -24 }}
                transition={{ duration: 0.22 }}
              >
                <PaymentMethodSelector
                  className="dm-ui max-w-none rounded-[var(--radius)] p-5"
                  title="¿Cómo querés pagar?"
                  methods={METODOS_PAGO}
                  defaultSelectedId={pago}
                  onSelectionChange={(id) => setPago(id as Pago)}
                />

                <div className="space-y-1.5">
                  <Label htmlFor="co-notas" className="text-[13px] font-bold text-foreground/80">
                    Notas (opcional)
                  </Label>
                  <textarea
                    id="co-notas"
                    rows={2}
                    value={datos.notas}
                    onChange={(e) => setDatos((d) => ({ ...d, notas: e.target.value }))}
                    placeholder="Ej.: es para regalo, ¿lo envuelven?"
                    className="flex w-full rounded-[12px] border border-input bg-card px-3 py-2 text-[15px] placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                  />
                </div>

                <Card className="rounded-[var(--radius)] border-border/80 shadow-none">
                  <CardHeader className="p-5 pb-3">
                    <CardTitle className="text-base font-bold">Resumen</CardTitle>
                    <CardDescription>
                      {datos.nombre} · {datos.telefono}
                    </CardDescription>
                  </CardHeader>
                  <CardContent className="space-y-3 p-5 pt-0">
                    <ul className="space-y-2 text-sm">
                      {c.lineas.map((l) => (
                        <li key={l.clave} className="flex justify-between gap-3">
                          <span className="min-w-0 truncate">
                            {l.cantidad} × {l.producto.nombre}
                            {l.producto.variantes.length > 1 && <span className="text-muted-foreground"> · {l.variante}</span>}
                          </span>
                          <span className="shrink-0">{formatearPrecio(l.producto.precio * l.cantidad)}</span>
                        </li>
                      ))}
                    </ul>
                    <Separator />
                    <Totales compacto />
                  </CardContent>
                </Card>

                <div className="flex gap-3">
                  <Button variant="outline" className="h-12 rounded-full px-5 font-bold" onClick={() => setPaso("datos")}>
                    Volver
                  </Button>
                  <Button className="h-12 flex-1 rounded-full text-base font-bold shadow-lg" onClick={confirmar} disabled={c.unidades === 0}>
                    Confirmar · {formatearPrecio(c.total)}
                  </Button>
                </div>
                <p className="flex items-start gap-1.5 text-xs text-muted-foreground">
                  <IconoEscudo size={14} /> No pedimos datos de tarjeta en la web. Coordinamos el pago por WhatsApp o en la sucursal.
                </p>
              </motion.div>
            )}

            {paso === "listo" && pedido && (
              <motion.div
                key="listo"
                className="flex flex-col items-center gap-5 px-6 py-10 text-center"
                initial={{ opacity: 0, scale: 0.94 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ type: "spring", stiffness: 260, damping: 20 }}
              >
                <motion.div
                  className="grid h-20 w-20 place-items-center rounded-full bg-[hsl(var(--success))] text-white shadow-lg"
                  initial={{ scale: 0, rotate: -90 }}
                  animate={{ scale: 1, rotate: 0 }}
                  transition={{ delay: 0.15, type: "spring", stiffness: 260, damping: 14 }}
                >
                  <IconoCheck size={40} />
                </motion.div>
                <p className="max-w-sm text-muted-foreground">
                  {pedido.retiro
                    ? "Te escribimos por WhatsApp cuando esté listo para retirar (normalmente en menos de 2 horas)."
                    : "Te escribimos por WhatsApp para coordinar el envío."}
                </p>
                <Card className="w-full rounded-[var(--radius)] text-left shadow-none">
                  <CardContent className="space-y-3 p-5 text-sm">
                    {[
                      ["Número de pedido", <span key="c" className="font-mono text-base font-bold tracking-wider text-primary">{pedido.codigo}</span>],
                      ["Productos", `${pedido.unidades}`],
                      ["Entrega", pedido.retiro ? "Retiro en Duomate Palermo" : "Envío a domicilio"],
                      ["Pago", NOMBRE_PAGO[pedido.pago]],
                    ].map(([k, v]) => (
                      <div key={String(k)} className="flex items-center justify-between gap-3">
                        <span className="text-muted-foreground">{k}</span>
                        <span className="text-right font-semibold">{v}</span>
                      </div>
                    ))}
                    <Separator />
                    <div className="flex items-center justify-between font-bold">
                      <span>Total</span>
                      <span className="font-serif text-2xl text-primary">{formatearPrecio(pedido.total)}</span>
                    </div>
                  </CardContent>
                </Card>
                <Button className="h-12 w-full rounded-full text-base font-bold" onClick={cerrar}>
                  Seguir comprando
                </Button>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </SheetContent>
    </Sheet>
  );
}

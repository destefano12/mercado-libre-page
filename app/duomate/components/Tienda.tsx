"use client";

import { AnimatePresence, motion } from "framer-motion";
import { useMemo, useState } from "react";
import { ProductCard, type ProductCardBadge } from "@/components/ui/product-card-1";
import { CATEGORIAS, PRODUCTOS, formatearPrecio, type Categoria, type Producto } from "../lib/catalogo";
import { useCarrito } from "../lib/carrito";
import { ArteProducto } from "./ArteProducto";
import { IconoBuscar } from "./Iconos";

type Orden = "destacados" | "menor" | "mayor" | "puntaje";

export function Tienda({
  onVer,
  categoria,
  setCategoria,
}: {
  onVer: (p: Producto) => void;
  categoria: Categoria | "todo";
  setCategoria: (c: Categoria | "todo") => void;
}) {
  const [busqueda, setBusqueda] = useState("");
  const [orden, setOrden] = useState<Orden>("destacados");
  const [favoritos, setFavoritos] = useState<Set<string>>(new Set());

  const lista = useMemo(() => {
    const q = busqueda
      .trim()
      .toLowerCase()
      .normalize("NFD")
      .replace(/\p{Diacritic}/gu, "");
    const filtrada = PRODUCTOS.filter((p) => {
      if (categoria !== "todo" && p.categoria !== categoria) return false;
      if (!q) return true;
      const texto = `${p.nombre} ${p.resumen} ${p.categoria}`.toLowerCase().normalize("NFD").replace(/\p{Diacritic}/gu, "");
      return texto.includes(q);
    });
    const copia = [...filtrada];
    if (orden === "menor") copia.sort((a, b) => a.precio - b.precio);
    if (orden === "mayor") copia.sort((a, b) => b.precio - a.precio);
    if (orden === "puntaje") copia.sort((a, b) => b.puntaje - a.puntaje || b.opiniones - a.opiniones);
    return copia;
  }, [categoria, busqueda, orden]);

  const conteo = (id: Categoria | "todo") => (id === "todo" ? PRODUCTOS.length : PRODUCTOS.filter((p) => p.categoria === id).length);

  const alternarFavorito = (id: string) =>
    setFavoritos((f) => {
      const n = new Set(f);
      if (n.has(id)) n.delete(id);
      else n.add(id);
      return n;
    });

  return (
    <section id="tienda" className="dm-seccion dm-tienda" aria-labelledby="titulo-tienda">
      <div className="dm-contenedor">
        <motion.div
          className="dm-encabezado-seccion"
          initial={{ opacity: 0, y: 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-80px" }}
          transition={{ duration: 0.5 }}
        >
          <span className="dm-sobretitulo">La tienda</span>
          <h2 id="titulo-tienda">Todo para tu ronda, elegido a mano</h2>
          <p>Mates curados, bombillas que no se tapan y yerbas estacionadas. Comprá online y retirá hoy en la sucursal.</p>
        </motion.div>

        <div className="dm-controles">
          <div className="dm-chips" role="tablist" aria-label="Categorías">
            {CATEGORIAS.map((c) => (
              <button
                key={c.id}
                role="tab"
                aria-selected={categoria === c.id}
                className={`dm-chip ${categoria === c.id ? "es-activo" : ""}`}
                onClick={() => setCategoria(c.id)}
              >
                {categoria === c.id && <motion.span layoutId="chip-activo" className="dm-chip-fondo" transition={{ type: "spring", stiffness: 420, damping: 34 }} />}
                <span className="dm-chip-texto">
                  {c.nombre} <span className="dm-chip-conteo">{conteo(c.id)}</span>
                </span>
              </button>
            ))}
          </div>

          <div className="dm-filtros">
            <label className="dm-buscador">
              <IconoBuscar size={18} />
              <span className="dm-oculto">Buscar productos</span>
              <input type="search" placeholder="Buscar mate, yerba, termo…" value={busqueda} onChange={(e) => setBusqueda(e.target.value)} />
            </label>
            <label className="dm-orden">
              <span className="dm-oculto">Ordenar por</span>
              <select value={orden} onChange={(e) => setOrden(e.target.value as Orden)}>
                <option value="destacados">Destacados</option>
                <option value="menor">Menor precio</option>
                <option value="mayor">Mayor precio</option>
                <option value="puntaje">Mejor puntuados</option>
              </select>
            </label>
          </div>
        </div>

        <p className="dm-resultados" aria-live="polite">
          {lista.length === 1 ? "1 producto" : `${lista.length} productos`}
        </p>

        <motion.ul layout className="dm-grilla">
          <AnimatePresence mode="popLayout">
            {lista.map((p, i) => (
              <Tarjeta key={p.id} producto={p} indice={i} favorito={favoritos.has(p.id)} onFavorito={() => alternarFavorito(p.id)} onVer={() => onVer(p)} />
            ))}
          </AnimatePresence>
        </motion.ul>

        {lista.length === 0 && (
          <div className="dm-vacio">
            <p>No encontramos productos para “{busqueda}”.</p>
            <button
              className="dm-boton dm-boton-secundario"
              onClick={() => {
                setBusqueda("");
                setCategoria("todo");
              }}
            >
              Ver todo el catálogo
            </button>
          </div>
        )}
      </div>
    </section>
  );
}

function Tarjeta({
  producto: p,
  indice,
  favorito,
  onFavorito,
  onVer,
}: {
  producto: Producto;
  indice: number;
  favorito: boolean;
  onFavorito: () => void;
  onVer: () => void;
}) {
  const { agregar } = useCarrito();
  const [variante, setVariante] = useState(p.variantes[0].nombre);
  const color = p.variantes.find((v) => v.nombre === variante)?.color ?? p.variantes[0].color;
  const ahorro = p.precioAnterior ? Math.round((1 - p.precio / p.precioAnterior) * 100) : 0;

  const insignias: ProductCardBadge[] = [];
  if (p.etiqueta) insignias.push({ label: p.etiqueta, className: CLASE_ETIQUETA[p.etiqueta] });
  if (ahorro > 0 && p.etiqueta !== "Oferta") insignias.push({ label: `-${ahorro}%`, className: CLASE_ETIQUETA.Oferta });
  else if (ahorro > 0) insignias[0].label = `Oferta -${ahorro}%`;

  return (
    <motion.li
      layout
      initial={{ opacity: 0, y: 30, scale: 0.97 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      exit={{ opacity: 0, scale: 0.94, transition: { duration: 0.18 } }}
      transition={{ duration: 0.45, delay: Math.min(indice, 8) * 0.04, ease: [0.22, 1, 0.36, 1] }}
      className="dm-tarjeta"
    >
      <ProductCard
        name={p.nombre}
        description={p.resumen}
        price={formatearPrecio(p.precio)}
        originalPrice={p.precioAnterior ? formatearPrecio(p.precioAnterior) : undefined}
        priceNote={`3 cuotas sin interés de ${formatearPrecio(Math.round(p.precio / 3))}`}
        rating={p.puntaje}
        reviewCount={p.opiniones}
        mediaTint={color}
        media={
          <AnimatePresence mode="wait" initial={false}>
            <motion.span
              key={color}
              className="dm-arte-envoltura"
              initial={{ opacity: 0, rotate: -6, scale: 0.92 }}
              animate={{ opacity: 1, rotate: 0, scale: 1 }}
              exit={{ opacity: 0, rotate: 6, scale: 0.92 }}
              transition={{ duration: 0.25 }}
            >
              <ArteProducto arte={p.arte} color={color} className="dm-arte" />
            </motion.span>
          </AnimatePresence>
        }
        badges={insignias}
        colors={p.variantes.map((v) => ({ name: v.nombre, value: v.color }))}
        selectedColor={variante}
        onColorChange={setVariante}
        wishlisted={favorito}
        onWishlistChange={onFavorito}
        onAddToCart={(origen) => agregar(p, variante, 1, origen)}
        onOpen={onVer}
        shippingNote={p.stock > 10 ? "Retiro hoy" : undefined}
        footnote={p.stock <= 10 ? `¡Quedan solo ${p.stock} en la sucursal!` : undefined}
      />
    </motion.li>
  );
}

const CLASE_ETIQUETA: Record<NonNullable<Producto["etiqueta"]>, string> = {
  "Más vendido": "bg-primary text-primary-foreground hover:bg-primary",
  Nuevo: "bg-[hsl(var(--accent-strong))] text-[hsl(var(--foreground))] hover:bg-[hsl(var(--accent-strong))]",
  "Edición limitada": "bg-[hsl(var(--foreground))] text-background hover:bg-[hsl(var(--foreground))]",
  Oferta: "bg-destructive text-destructive-foreground hover:bg-destructive",
};

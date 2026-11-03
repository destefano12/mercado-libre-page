"use client";

import { AnimatePresence, motion } from "framer-motion";
import { useMemo, useRef, useState } from "react";
import { CATEGORIAS, PRODUCTOS, formatearPrecio, type Categoria, type Producto } from "../lib/catalogo";
import { useCarrito } from "../lib/carrito";
import { ArteProducto } from "./ArteProducto";
import { Estrellas, IconoBolsa, IconoBuscar, IconoCheck, IconoCorazon, IconoOjo } from "./Iconos";

type Orden = "destacados" | "menor" | "mayor" | "puntaje";

export function Tienda({ onVer }: { onVer: (p: Producto) => void }) {
  const [categoria, setCategoria] = useState<Categoria | "todo">("todo");
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
  const [agregado, setAgregado] = useState(false);
  const botonRef = useRef<HTMLButtonElement>(null);
  const color = p.variantes.find((v) => v.nombre === variante)?.color ?? p.variantes[0].color;
  const ahorro = p.precioAnterior ? Math.round((1 - p.precio / p.precioAnterior) * 100) : 0;

  const alAgregar = () => {
    agregar(p, variante, 1, botonRef.current?.getBoundingClientRect() ?? null);
    setAgregado(true);
    setTimeout(() => setAgregado(false), 1400);
  };

  return (
    <motion.li
      layout
      initial={{ opacity: 0, y: 30, scale: 0.97 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      exit={{ opacity: 0, scale: 0.94, transition: { duration: 0.18 } }}
      transition={{ duration: 0.45, delay: Math.min(indice, 8) * 0.04, ease: [0.22, 1, 0.36, 1] }}
      className="dm-tarjeta"
    >
      <div className="dm-tarjeta-imagen" style={{ ["--tinte" as string]: color }}>
        {p.etiqueta && <span className={`dm-etiqueta dm-etiqueta-${p.etiqueta === "Oferta" ? "oferta" : p.etiqueta === "Nuevo" ? "nuevo" : "base"}`}>{p.etiqueta}</span>}
        <motion.button
          className={`dm-favorito ${favorito ? "es-activo" : ""}`}
          onClick={onFavorito}
          aria-pressed={favorito}
          aria-label={favorito ? `Quitar ${p.nombre} de favoritos` : `Guardar ${p.nombre} en favoritos`}
          whileTap={{ scale: 0.8 }}
        >
          <motion.span key={String(favorito)} initial={{ scale: 0.4 }} animate={{ scale: 1 }} transition={{ type: "spring", stiffness: 500, damping: 15 }}>
            <IconoCorazon size={18} lleno={favorito} />
          </motion.span>
        </motion.button>
        <button className="dm-tarjeta-arte" onClick={onVer} aria-label={`Ver detalle de ${p.nombre}`}>
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
          <span className="dm-vista-rapida">
            <IconoOjo size={16} /> Vista rápida
          </span>
        </button>
      </div>

      <div className="dm-tarjeta-cuerpo">
        <div className="dm-tarjeta-meta">
          <Estrellas valor={p.puntaje} size={13} />
          <span>
            {p.puntaje.toFixed(1)} ({p.opiniones})
          </span>
        </div>
        <h3>
          <button className="dm-tarjeta-titulo" onClick={onVer}>
            {p.nombre}
          </button>
        </h3>
        <p className="dm-tarjeta-resumen">{p.resumen}</p>

        {p.variantes.length > 1 && (
          <div className="dm-variantes" role="radiogroup" aria-label={`Variante de ${p.nombre}`}>
            {p.variantes.map((v) => (
              <button
                key={v.nombre}
                role="radio"
                aria-checked={variante === v.nombre}
                aria-label={v.nombre}
                title={v.nombre}
                className={`dm-muestra ${variante === v.nombre ? "es-activo" : ""}`}
                style={{ background: v.color }}
                onClick={() => setVariante(v.nombre)}
              />
            ))}
            <span className="dm-variante-nombre">{variante}</span>
          </div>
        )}

        <div className="dm-tarjeta-pie">
          <div className="dm-precio">
            {p.precioAnterior && (
              <span className="dm-precio-anterior">
                {formatearPrecio(p.precioAnterior)} <em>-{ahorro}%</em>
              </span>
            )}
            <strong>{formatearPrecio(p.precio)}</strong>
            <span className="dm-cuotas">3 cuotas sin interés de {formatearPrecio(Math.round(p.precio / 3))}</span>
          </div>
          <motion.button ref={botonRef} className={`dm-agregar ${agregado ? "es-ok" : ""}`} onClick={alAgregar} whileTap={{ scale: 0.92 }} aria-label={`Agregar ${p.nombre} al carrito`}>
            <AnimatePresence mode="wait" initial={false}>
              {agregado ? (
                <motion.span key="ok" initial={{ y: 12, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: -12, opacity: 0 }}>
                  <IconoCheck size={20} />
                </motion.span>
              ) : (
                <motion.span key="bolsa" initial={{ y: 12, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: -12, opacity: 0 }}>
                  <IconoBolsa size={20} />
                </motion.span>
              )}
            </AnimatePresence>
          </motion.button>
        </div>
        {p.stock <= 10 && <p className="dm-stock">¡Quedan solo {p.stock} en la sucursal!</p>}
      </div>
    </motion.li>
  );
}

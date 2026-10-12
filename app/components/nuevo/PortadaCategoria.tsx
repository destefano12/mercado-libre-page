"use client";

import type { CategoryConfig, CategoryId } from "../../data/marketplace";
import { ArteCategoria, arteDeCategoria } from "./ArteCategoria";
import "./nuevo.css";

/**
 * Encabezado de cada categoria con identidad propia: colores, ilustracion,
 * textos y beneficios pensados para lo que se busca ahi. Las categorias sin
 * tema propio usan el acento y el tinte que ya tienen en los datos.
 */

interface Tema {
  estilo: "oscuro" | "claro";
  fondo: string;
  titulo: string;
  bajada: string;
  beneficios: { titulo: string; texto: string }[];
}

const TEMAS: Partial<Record<CategoryId, Tema>> = {
  vehiculos: {
    estilo: "oscuro",
    fondo: "radial-gradient(circle at 80% 20%, #3b4252 0%, #15171c 60%)",
    titulo: "Encontrá el auto que estás buscando",
    bajada: "Comparás por año, kilómetros y transmisión, y coordinás la visita por chat.",
    beneficios: [
      { titulo: "Trato directo", texto: "Hablás con quien vende, sin intermediarios" },
      { titulo: "Ficha completa", texto: "Kilometraje, año y estado a la vista" },
      { titulo: "Reputación", texto: "Opiniones reales de compras anteriores" },
    ],
  },
  inmuebles: {
    estilo: "claro",
    fondo: "linear-gradient(120deg, #e8f7ef 0%, #c9eedb 100%)",
    titulo: "Tu próximo hogar empieza acá",
    bajada: "Casas, departamentos y PH para comprar o alquilar, por zona y ambientes.",
    beneficios: [
      { titulo: "Por ambientes", texto: "Filtrá por metros y cantidad de cuartos" },
      { titulo: "Por zona", texto: "Elegí el barrio antes que el precio" },
      { titulo: "Consultas", texto: "Pedí más fotos o una visita al instante" },
    ],
  },
  tecnologia: {
    estilo: "oscuro",
    fondo: "linear-gradient(120deg, #0f0c29 0%, #302b63 60%, #24243e 100%)",
    titulo: "Tecnología para trabajar, estudiar y jugar",
    bajada: "Celulares, notebooks y accesorios comparados por lo que importa.",
    beneficios: [
      { titulo: "Cuotas fijas", texto: "Planes simulados para cada compra" },
      { titulo: "Garantía visible", texto: "Estado y garantía en cada publicación" },
      { titulo: "Envío seguido", texto: "Mirá el recorrido en el mapa" },
    ],
  },
  moda: {
    estilo: "claro",
    fondo: "linear-gradient(120deg, #fff1f4 0%, #ffe0e8 50%, #fff4d6 100%)",
    titulo: "Nueva temporada, tu estilo",
    bajada: "Ropa, calzado y accesorios por talle, color y ocasión.",
    beneficios: [
      { titulo: "Por talle", texto: "Encontrá solo lo que te queda" },
      { titulo: "Cambios fáciles", texto: "Coordiná con el vendedor por chat" },
      { titulo: "Liquidación", texto: "Temporada pasada a mejor precio" },
    ],
  },
  hogar: {
    estilo: "claro",
    fondo: "linear-gradient(120deg, #fdf0e6 0%, #f8d9c4 100%)",
    titulo: "Hacé de tu casa tu lugar favorito",
    bajada: "Muebles, cocina, deco y jardín de vendedores cerca tuyo.",
    beneficios: [
      { titulo: "Cerca tuyo", texto: "Priorizamos vendedores de tu zona" },
      { titulo: "Ambiente por ambiente", texto: "Living, cocina, dormitorio y más" },
      { titulo: "Envío coordinado", texto: "Para muebles grandes, día y hora" },
    ],
  },
  herramientas: {
    estilo: "oscuro",
    fondo: "repeating-linear-gradient(135deg, #22252b 0 18px, #262a31 18px 36px)",
    titulo: "Herramientas para cada trabajo",
    bajada: "Eléctricas, manuales y de medición, para obra o para casa.",
    beneficios: [
      { titulo: "Para profesionales", texto: "Equipos de uso intensivo" },
      { titulo: "Para casa", texto: "Kits para arreglos de todos los días" },
      { titulo: "Repuestos", texto: "Mechas, discos y baterías" },
    ],
  },
  supermercado: {
    estilo: "claro",
    fondo: "linear-gradient(120deg, #eafaf0 0%, #d3f3df 100%)",
    titulo: "Súper Live: la compra del mes sin salir",
    bajada: "Almacén, bebidas, limpieza y cuidado personal en un solo pedido.",
    beneficios: [
      { titulo: "Ahorro por cantidad", texto: "Más unidades, mejor precio" },
      { titulo: "Un solo envío", texto: "Todo junto en la misma entrega" },
      { titulo: "Repetí tu compra", texto: "Volvé a pedir lo de siempre" },
    ],
  },
  streaming: {
    estilo: "oscuro",
    fondo: "linear-gradient(120deg, #14121f 0%, #3b1260 60%, #7b2ff7 100%)",
    titulo: "Entretenimiento digital al instante",
    bajada: "Accesos y códigos digitales con entrega inmediata.",
    beneficios: [
      { titulo: "Entrega inmediata", texto: "Sin esperas ni envíos" },
      { titulo: "Soporte por chat", texto: "Te ayudamos a activarlo" },
      { titulo: "Para toda la familia", texto: "Series, películas y más" },
    ],
  },
  deportes: {
    estilo: "claro",
    fondo: "linear-gradient(120deg, #e6f0ff 0%, #cfe0ff 100%)",
    titulo: "Todo para entrenar a tu ritmo",
    bajada: "Running, fútbol, ciclismo y gimnasio en casa.",
    beneficios: [
      { titulo: "Por disciplina", texto: "Elegí tu deporte y listo" },
      { titulo: "Calzado", texto: "Filtrado por talle y pisada" },
      { titulo: "Equipamiento", texto: "Desde pesas hasta bicis" },
    ],
  },
};

function temaPorDefecto(categoria: CategoryConfig): Tema {
  return {
    estilo: "claro",
    fondo: `linear-gradient(120deg, ${categoria.tint} 0%, #ffffff 100%)`,
    titulo: categoria.bannerTitle,
    bajada: categoria.bannerText,
    beneficios: categoria.ads.slice(0, 3).map((anuncio) => ({ titulo: anuncio.title, texto: anuncio.body })),
  };
}

export function PortadaCategoria({
  categoria,
  filtrosActivos,
  onFiltro,
}: {
  categoria: CategoryConfig;
  filtrosActivos: Record<string, string>;
  onFiltro: (etiqueta: string, valor: string) => void;
}) {
  const tema = TEMAS[categoria.id] ?? temaPorDefecto(categoria);
  const atajos = categoria.filters.flatMap((filtro) =>
    filtro.values.slice(0, 3).map((valor) => ({ etiqueta: filtro.label, valor })),
  );

  return (
    <section
      className={`nv-cat nv-cat--${tema.estilo}`}
      style={{ "--nv-acento": categoria.accent, background: tema.fondo } as React.CSSProperties}
      aria-label={`Portada de ${categoria.label}`}
    >
      <div className="nv-cat__cuerpo">
        <div className="nv-cat__texto">
          <span className="nv-cat__ante">{categoria.label}</span>
          <h1>{tema.titulo}</h1>
          <p>{tema.bajada}</p>
          {atajos.length ? (
            <div className="nv-cat__atajos" role="group" aria-label="Filtros rápidos">
              {atajos.slice(0, 8).map(({ etiqueta, valor }) => (
                <button
                  key={`${etiqueta}-${valor}`}
                  type="button"
                  aria-pressed={filtrosActivos[etiqueta] === valor}
                  onClick={() => onFiltro(etiqueta, valor)}
                >
                  {valor}
                </button>
              ))}
            </div>
          ) : null}
        </div>
        <ArteCategoria arte={arteDeCategoria(categoria.id)} className="nv-cat__arte" />
      </div>

      {tema.beneficios.length ? (
        <ul className="nv-cat__beneficios">
          {tema.beneficios.map((beneficio) => (
            <li key={beneficio.titulo}>
              <strong>{beneficio.titulo}</strong>
              <span>{beneficio.texto}</span>
            </li>
          ))}
        </ul>
      ) : null}
    </section>
  );
}

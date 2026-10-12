"use client";

import { useCallback, useEffect, useState } from "react";
import type { CategoryId } from "../../data/marketplace";
import { ArteCategoria, arteDeCategoria } from "./ArteCategoria";

/**
 * Carrusel de anuncios de la portada. Pasa solo cada pocos segundos, se frena
 * cuando el mouse esta encima y se maneja con flechas, puntos o teclado.
 *
 * Si el visitante ya tiene categorias favoritas, sus anuncios van primero.
 */

export interface Promo {
  categoria: CategoryId;
  antetitulo: string;
  titulo: string;
  bajada: string;
  boton: string;
  fondo: string;
  tinta: string;
}

export const PROMOS: Promo[] = [
  {
    categoria: "tecnologia",
    antetitulo: "Semana tecno",
    titulo: "Notebooks y celulares con hasta 25% menos",
    bajada: "Y pagás en cuotas fijas, sin sorpresas al final del mes.",
    boton: "Ver tecnología",
    fondo: "linear-gradient(120deg, #1b1446 0%, #3a2a9e 55%, #00b3a8 100%)",
    tinta: "#ffffff",
  },
  {
    categoria: "hogar",
    antetitulo: "Tu casa, a tu manera",
    titulo: "Muebles y deco que llegan en 48 horas",
    bajada: "Armá cada ambiente con vendedores de tu zona.",
    boton: "Renovar mi casa",
    fondo: "linear-gradient(120deg, #fbe3d6 0%, #f6c1a6 100%)",
    tinta: "#4a2516",
  },
  {
    categoria: "supermercado",
    antetitulo: "Súper Live",
    titulo: "Llená la alacena y ahorrá por cantidad",
    bajada: "Llevando 3 unidades del mismo producto, la tercera sale a mitad de precio.",
    boton: "Ir al súper",
    fondo: "linear-gradient(120deg, #e3f7ea 0%, #b6ebc9 100%)",
    tinta: "#0f4d2c",
  },
  {
    categoria: "vehiculos",
    antetitulo: "Motor",
    titulo: "Tu próximo auto, de dueño a dueño",
    bajada: "Filtrá por año, kilómetros y transmisión, y hablá directo con quien vende.",
    boton: "Ver vehículos",
    fondo: "linear-gradient(120deg, #111318 0%, #2a2f3a 100%)",
    tinta: "#ffffff",
  },
  {
    categoria: "deportes",
    antetitulo: "Arrancá a moverte",
    titulo: "Zapatillas, bicis y todo para entrenar",
    bajada: "Elegí por disciplina y recibilo antes del fin de semana.",
    boton: "Ver deportes",
    fondo: "linear-gradient(120deg, #e6f0ff 0%, #b9d3ff 100%)",
    tinta: "#0d2a66",
  },
];

const INTERVALO_MS = 6000;

export function CarruselPromos({
  favoritas,
  onAbrir,
}: {
  favoritas: CategoryId[];
  onAbrir: (categoria: CategoryId) => void;
}) {
  const promos = [...PROMOS].sort((a, b) => {
    const rango = (promo: Promo) => {
      const posicion = favoritas.indexOf(promo.categoria);
      return posicion === -1 ? Number.POSITIVE_INFINITY : posicion;
    };
    return rango(a) - rango(b);
  });

  const [actual, setActual] = useState(0);
  const [pausado, setPausado] = useState(false);
  const total = promos.length;

  const ir = useCallback((indice: number) => setActual((indice + total) % total), [total]);

  useEffect(() => {
    if (pausado) return;
    const reloj = window.setInterval(() => setActual((previo) => (previo + 1) % total), INTERVALO_MS);
    return () => window.clearInterval(reloj);
  }, [pausado, total]);

  return (
    <section
      className="nv-carrusel"
      aria-roledescription="carrusel"
      aria-label="Anuncios destacados"
      onMouseEnter={() => setPausado(true)}
      onMouseLeave={() => setPausado(false)}
      onFocus={() => setPausado(true)}
      onBlur={() => setPausado(false)}
      onKeyDown={(evento) => {
        if (evento.key === "ArrowRight") ir(actual + 1);
        if (evento.key === "ArrowLeft") ir(actual - 1);
      }}
    >
      <div className="nv-carrusel__pista" style={{ transform: `translateX(-${actual * 100}%)` }}>
        {promos.map((promo, indice) => (
          <article
            key={promo.categoria}
            className="nv-carrusel__slide"
            style={{ background: promo.fondo, color: promo.tinta }}
            aria-roledescription="anuncio"
            aria-label={`${indice + 1} de ${total}: ${promo.titulo}`}
            aria-hidden={indice !== actual}
          >
            <div className="nv-carrusel__texto">
              <span className="nv-carrusel__ante">{promo.antetitulo}</span>
              <h2>{promo.titulo}</h2>
              <p>{promo.bajada}</p>
              <button
                type="button"
                tabIndex={indice === actual ? 0 : -1}
                onClick={() => onAbrir(promo.categoria)}
              >
                {promo.boton}
              </button>
            </div>
            <ArteCategoria arte={arteDeCategoria(promo.categoria)} className="nv-carrusel__arte" />
          </article>
        ))}
      </div>

      <button type="button" className="nv-carrusel__flecha nv-carrusel__flecha--izq" onClick={() => ir(actual - 1)} aria-label="Anuncio anterior">
        ‹
      </button>
      <button type="button" className="nv-carrusel__flecha nv-carrusel__flecha--der" onClick={() => ir(actual + 1)} aria-label="Anuncio siguiente">
        ›
      </button>

      <div className="nv-carrusel__puntos">
        {promos.map((promo, indice) => (
          <button
            key={promo.categoria}
            type="button"
            className={indice === actual ? "is-activo" : undefined}
            onClick={() => ir(indice)}
            aria-label={`Ir al anuncio ${indice + 1}`}
            aria-current={indice === actual}
          />
        ))}
      </div>
    </section>
  );
}

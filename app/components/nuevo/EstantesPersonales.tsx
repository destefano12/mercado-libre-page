"use client";

import { useMemo, useRef, useSyncExternalStore } from "react";
import {
  categories,
  type CategoryId,
  type Listing,
  type MarketplaceState,
  type UserProfile,
} from "../../data/marketplace";
import {
  armarEstantes,
  escucharActividad,
  leerActividad,
  type Actividad,
} from "../../lib/personalizacion";
import { ProductCard } from "../ProductCard";
import { AnuncioVideo } from "./AnuncioVideo";
import { ArteCategoria, arteDeCategoria } from "./ArteCategoria";
import { CarruselPromos } from "./CarruselPromos";
import "./nuevo.css";

/**
 * Bloques de la portada que se arman segun lo que hizo cada visitante:
 * anuncios ordenados por sus categorias, lo ultimo que vio, parecidos a eso,
 * su ultima busqueda y ofertas de lo que le interesa. Para alguien nuevo
 * muestra una invitacion a explorar en lugar de estantes vacios.
 */

const SIN_ACTIVIDAD = JSON.stringify({ vistos: [], busquedas: [], categorias: [] });

function useActividad(usuarioId: string | null): Actividad {
  // Se guarda el texto y no el objeto para que la comparacion sea estable.
  const texto = useSyncExternalStore(
    escucharActividad,
    () => JSON.stringify(leerActividad(usuarioId)),
    () => SIN_ACTIVIDAD,
  );
  return useMemo(() => JSON.parse(texto) as Actividad, [texto]);
}

function Estante({
  titulo,
  bajada,
  accion,
  listings,
  usuarios,
  onAbrir,
}: {
  titulo: React.ReactNode;
  bajada?: string;
  accion?: { texto: string; onClick: () => void };
  listings: Listing[];
  usuarios: UserProfile[];
  onAbrir: (listing: Listing) => void;
}) {
  const fila = useRef<HTMLDivElement>(null);
  const mover = (sentido: number) =>
    fila.current?.scrollBy({ left: sentido * fila.current.clientWidth * 0.9, behavior: "smooth" });

  return (
    <section className="nv-estante">
      <header className="nv-estante__cabecera">
        <div>
          <h2>{titulo}</h2>
          {bajada ? <p>{bajada}</p> : null}
        </div>
        {accion ? (
          <button type="button" className="nv-enlace" onClick={accion.onClick}>
            {accion.texto}
          </button>
        ) : null}
      </header>
      <div className="nv-estante__marco">
        {listings.length > 4 ? (
          <button type="button" className="nv-estante__flecha nv-estante__flecha--izq" onClick={() => mover(-1)} aria-label="Ver anteriores">
            ‹
          </button>
        ) : null}
        <div className="nv-estante__fila" ref={fila}>
          {listings.map((listing) => (
            <div className="nv-estante__item" key={listing.id}>
              <ProductCard
                listing={listing}
                seller={usuarios.find((usuario) => usuario.id === listing.sellerId)}
                onOpen={onAbrir}
                compact
              />
            </div>
          ))}
        </div>
        {listings.length > 4 ? (
          <button type="button" className="nv-estante__flecha nv-estante__flecha--der" onClick={() => mover(1)} aria-label="Ver siguientes">
            ›
          </button>
        ) : null}
      </div>
    </section>
  );
}

export function EstantesPersonales({
  state,
  usuarioId,
  onAbrirListing,
  onAbrirCategoria,
  onBuscar,
  onOfertas,
}: {
  state: MarketplaceState;
  usuarioId: string | null;
  onAbrirListing: (listing: Listing) => void;
  onAbrirCategoria: (categoria: CategoryId) => void;
  onBuscar: (consulta: string) => void;
  onOfertas: () => void;
}) {
  const actividad = useActividad(usuarioId);
  const estantes = useMemo(
    () =>
      armarEstantes(
        state.listings,
        actividad,
        usuarioId ? state.views.filter((vista) => vista.userId === usuarioId) : [],
        usuarioId ? state.searches.filter((busqueda) => busqueda.userId === usuarioId) : [],
      ),
    [actividad, state.listings, state.searches, state.views, usuarioId],
  );

  const sugeridas = (
    estantes.categoriasFavoritas.length
      ? estantes.categoriasFavoritas
      : (["tecnologia", "hogar", "moda", "vehiculos", "supermercado", "deportes"] as CategoryId[])
  )
    .map((id) => categories.find((categoria) => categoria.id === id))
    .filter((categoria): categoria is (typeof categories)[number] => Boolean(categoria))
    .slice(0, 6);

  return (
    <div className="nv-portada">
      <CarruselPromos favoritas={estantes.categoriasFavoritas} onAbrir={onAbrirCategoria} />

      {estantes.vistos.length ? (
        <Estante
          titulo="Visto recientemente"
          bajada="Retomá donde lo dejaste"
          listings={estantes.vistos}
          usuarios={state.users}
          onAbrir={onAbrirListing}
        />
      ) : null}

      {estantes.porqueViste ? (
        <Estante
          titulo={
            <>
              Porque viste <em>{estantes.porqueViste.base.title}</em>
            </>
          }
          listings={estantes.porqueViste.parecidos}
          usuarios={state.users}
          onAbrir={onAbrirListing}
          accion={{
            texto: "Ver la categoría",
            onClick: () => onAbrirCategoria(estantes.porqueViste!.base.categoryId),
          }}
        />
      ) : null}

      <section className="nv-categorias" aria-label="Categorías para vos">
        <header className="nv-estante__cabecera">
          <div>
            <h2>{estantes.tieneActividad ? "Tus categorías" : "Empezá a explorar"}</h2>
            <p>
              {estantes.tieneActividad
                ? "Ordenadas según lo que más mirás"
                : "Lo que veas va a ir armando esta página a tu medida"}
            </p>
          </div>
        </header>
        <div className="nv-categorias__grilla">
          {sugeridas.map((categoria) => (
            <button
              key={categoria.id}
              type="button"
              className="nv-categorias__tarjeta"
              style={{ "--nv-acento": categoria.accent, "--nv-tinte": categoria.tint } as React.CSSProperties}
              onClick={() => onAbrirCategoria(categoria.id)}
            >
              <ArteCategoria arte={arteDeCategoria(categoria.id)} className="nv-categorias__arte" />
              <span>{categoria.label}</span>
            </button>
          ))}
        </div>
      </section>

      {estantes.seguiBuscando ? (
        <Estante
          titulo={
            <>
              Seguí buscando <em>“{estantes.seguiBuscando.consulta}”</em>
            </>
          }
          listings={estantes.seguiBuscando.resultados}
          usuarios={state.users}
          onAbrir={onAbrirListing}
          accion={{ texto: "Ver resultados", onClick: () => onBuscar(estantes.seguiBuscando!.consulta) }}
        />
      ) : null}

      <AnuncioVideo onAbrir={onOfertas} />

      {estantes.ofertas.length ? (
        <Estante
          titulo={estantes.tieneActividad ? "Ofertas para vos" : "Ofertas del día"}
          bajada={estantes.tieneActividad ? "Elegidas según tus intereses" : undefined}
          listings={estantes.ofertas}
          usuarios={state.users}
          onAbrir={onAbrirListing}
          accion={{ texto: "Ver todas", onClick: onOfertas }}
        />
      ) : null}
    </div>
  );
}

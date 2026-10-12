import type {
  CategoryId,
  Listing,
  SearchEvent,
  ViewEvent,
} from "../data/marketplace";
import { matchesListingQuery, normalize } from "./recommendations";

/**
 * Actividad de cada visitante para armar la portada a su medida.
 *
 * El historial del store solo registra a quien inicio sesion. Este registro
 * vive en el navegador y anota tambien a los invitados, asi "Visto
 * recientemente" funciona desde la primera visita. Cuando hay sesion se
 * combina con el historial de la cuenta.
 */

const CLAVE = "mercado-live-actividad-v1";
const EVENTO = "mercado-live-actividad";
const TOPE = 40;

interface Marca<T> {
  valor: T;
  en: string;
}

export interface Actividad {
  vistos: Marca<string>[];
  busquedas: Marca<string>[];
  categorias: Marca<CategoryId>[];
}

const VACIA: Actividad = { vistos: [], busquedas: [], categorias: [] };

function clave(usuarioId: string | null) {
  return `${CLAVE}:${usuarioId ?? "invitado"}`;
}

export function leerActividad(usuarioId: string | null): Actividad {
  try {
    const crudo = window.localStorage.getItem(clave(usuarioId));
    if (!crudo) return VACIA;
    const datos = JSON.parse(crudo) as Partial<Actividad>;
    return {
      vistos: Array.isArray(datos.vistos) ? datos.vistos : [],
      busquedas: Array.isArray(datos.busquedas) ? datos.busquedas : [],
      categorias: Array.isArray(datos.categorias) ? datos.categorias : [],
    };
  } catch {
    return VACIA;
  }
}

function anotar<T>(lista: Marca<T>[], valor: T): Marca<T>[] {
  // El ultimo queda primero y sin repetidos.
  return [{ valor, en: new Date().toISOString() }, ...lista.filter((marca) => marca.valor !== valor)].slice(0, TOPE);
}

function actualizar(usuarioId: string | null, cambio: (actual: Actividad) => Actividad) {
  try {
    const siguiente = cambio(leerActividad(usuarioId));
    window.localStorage.setItem(clave(usuarioId), JSON.stringify(siguiente));
    window.dispatchEvent(new Event(EVENTO));
  } catch {
    // Sin almacenamiento (modo privado estricto) la portada queda generica.
  }
}

export function registrarVisto(usuarioId: string | null, listingId: string) {
  actualizar(usuarioId, (a) => ({ ...a, vistos: anotar(a.vistos, listingId) }));
}

export function registrarBusqueda(usuarioId: string | null, consulta: string) {
  const limpia = consulta.trim();
  if (limpia.length < 2) return;
  actualizar(usuarioId, (a) => ({ ...a, busquedas: anotar(a.busquedas, limpia) }));
}

export function registrarCategoria(usuarioId: string | null, categoriaId: CategoryId) {
  actualizar(usuarioId, (a) => ({ ...a, categorias: anotar(a.categorias, categoriaId) }));
}

export function escucharActividad(aviso: () => void) {
  window.addEventListener(EVENTO, aviso);
  window.addEventListener("storage", aviso);
  return () => {
    window.removeEventListener(EVENTO, aviso);
    window.removeEventListener("storage", aviso);
  };
}

export interface Estantes {
  vistos: Listing[];
  /** El ultimo producto visto y los parecidos a el. */
  porqueViste: { base: Listing; parecidos: Listing[] } | null;
  /** La ultima busqueda y lo que hoy coincide con ella. */
  seguiBuscando: { consulta: string; resultados: Listing[] } | null;
  ofertas: Listing[];
  categoriasFavoritas: CategoryId[];
  tieneActividad: boolean;
}

function fusionar(
  locales: Marca<string>[],
  deCuenta: { valor: string; en: string }[],
) {
  return [...locales, ...deCuenta]
    .sort((a, b) => b.en.localeCompare(a.en))
    .map((marca) => marca.valor)
    .filter((valor, indice, todos) => todos.indexOf(valor) === indice);
}

export function descuento(listing: Listing) {
  return listing.oldPrice && listing.oldPrice > listing.price
    ? Math.round((1 - listing.price / listing.oldPrice) * 100)
    : 0;
}

export function armarEstantes(
  listings: Listing[],
  actividad: Actividad,
  vistasCuenta: ViewEvent[],
  busquedasCuenta: SearchEvent[],
): Estantes {
  const porId = new Map(listings.map((listing) => [listing.id, listing]));

  const vistos = fusionar(
    actividad.vistos,
    vistasCuenta.map((vista) => ({ valor: vista.listingId, en: vista.viewedAt })),
  )
    .map((id) => porId.get(id))
    .filter((listing): listing is Listing => Boolean(listing));

  const busquedas = fusionar(
    actividad.busquedas,
    busquedasCuenta.map((busqueda) => ({ valor: busqueda.query, en: busqueda.searchedAt })),
  );

  // Afinidad por categoria: lo visto pesa mas que lo navegado, y lo reciente
  // mas que lo viejo.
  const afinidad = new Map<CategoryId, number>();
  const sumar = (id: CategoryId, puntos: number) => afinidad.set(id, (afinidad.get(id) ?? 0) + puntos);
  vistos.forEach((listing, indice) => sumar(listing.categoryId, Math.max(1, 6 - indice)));
  actividad.categorias.forEach((marca, indice) => sumar(marca.valor, Math.max(0.5, 3 - indice)));
  const categoriasFavoritas = [...afinidad.entries()]
    .sort((a, b) => b[1] - a[1])
    .map(([id]) => id);

  const yaVistos = new Set(vistos.map((listing) => listing.id));

  let porqueViste: Estantes["porqueViste"] = null;
  const base = vistos[0];
  if (base) {
    const etiquetas = new Set(base.tags.map(normalize));
    const parecidos = listings
      .filter((listing) => listing.id !== base.id)
      .map((listing) => ({
        listing,
        puntos:
          (listing.categoryId === base.categoryId ? 5 : 0) +
          listing.tags.filter((tag) => etiquetas.has(normalize(tag))).length * 2 -
          (yaVistos.has(listing.id) ? 3 : 0),
      }))
      .filter((candidato) => candidato.puntos > 0)
      .sort((a, b) => b.puntos - a.puntos)
      .map((candidato) => candidato.listing)
      .slice(0, 10);
    if (parecidos.length) porqueViste = { base, parecidos };
  }

  let seguiBuscando: Estantes["seguiBuscando"] = null;
  for (const consulta of busquedas.slice(0, 5)) {
    const resultados = listings.filter((listing) => matchesListingQuery(listing, consulta)).slice(0, 10);
    if (resultados.length) {
      seguiBuscando = { consulta, resultados };
      break;
    }
  }

  const ofertas = listings
    .filter((listing) => descuento(listing) > 0)
    .sort((a, b) => {
      const porAfinidad = (afinidad.get(b.categoryId) ?? 0) - (afinidad.get(a.categoryId) ?? 0);
      return porAfinidad || descuento(b) - descuento(a);
    })
    .slice(0, 10);

  return {
    vistos: vistos.slice(0, 12),
    porqueViste,
    seguiBuscando,
    ofertas,
    categoriasFavoritas,
    tieneActividad: vistos.length > 0 || busquedas.length > 0 || actividad.categorias.length > 0,
  };
}

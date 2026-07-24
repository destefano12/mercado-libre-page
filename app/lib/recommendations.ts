import type {
  CategoryId,
  Listing,
  MarketplaceState,
  SearchEvent,
  ViewEvent,
} from "../data/marketplace";

export interface RecommendationShelves {
  recentlyViewed: Listing[];
  inspiredByHistory: Listing[];
  nearYou: Listing[];
  trending: Listing[];
  hasPersonalActivity: boolean;
}

export function normalize(value: string) {
  return value.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
}

function categoryWeight(history: ViewEvent[], searches: SearchEvent[], categoryId: CategoryId) {
  const viewScore = history.reduce((score, view, index) => {
    if (view.categoryId !== categoryId) {
      return score;
    }

    return score + Math.max(1, 8 - index * 1.4);
  }, 0);

  const searchScore = searches.reduce((score, search, index) => {
    if (search.categoryId !== categoryId) {
      return score;
    }

    return score + Math.max(1, 5 - index);
  }, 0);

  return viewScore + searchScore;
}

function tagOverlap(personalTags: string[], listing: Listing) {
  const normalizedTags = new Set(personalTags.map(normalize));
  return listing.tags.reduce(
    (score, tag) => score + (normalizedTags.has(normalize(tag)) ? 4 : 0),
    0,
  );
}

function queryOverlap(searches: SearchEvent[], listing: Listing) {
  const haystack = normalize(
    [
      listing.title,
      listing.description,
      listing.location,
      listing.shipping,
      listing.condition,
      listing.tags.join(" "),
      Object.values(listing.meta).join(" "),
    ].join(" "),
  );

  return searches.reduce((score, search, index) => {
    const words = normalize(search.query).split(/\s+/).filter((word) => word.length > 2);
    const matches = words.filter((word) => haystack.includes(word)).length;
    return score + matches * Math.max(1, 4 - index * 0.6);
  }, 0);
}

function freshnessScore(createdAt: string) {
  const created = new Date(createdAt).getTime();
  const now = new Date("2026-07-24T02:00:00.000Z").getTime();
  const ageHours = Math.max(1, (now - created) / 1000 / 60 / 60);
  return Math.max(0, 4 - ageHours / 12);
}

function scoreListing(
  listing: Listing,
  history: ViewEvent[],
  searches: SearchEvent[],
  personalTags: string[],
) {
  const commercialBoost = listing.source === "catalog" ? 1 : 0;
  const sponsoredBoost = listing.sponsored ? 0.8 : 0;

  return (
    categoryWeight(history, searches, listing.categoryId) +
    tagOverlap(personalTags, listing) +
    queryOverlap(searches, listing) +
    freshnessScore(listing.createdAt) +
    listing.rating +
    commercialBoost +
    sponsoredBoost
  );
}

export function inferCategoryFromText(query: string): CategoryId | undefined {
  const value = normalize(query);
  if (/auto|moto|toyota|honda|ford|kilometraje|vehiculo/.test(value)) return "vehiculos";
  if (/casa|departamento|ph|ambiente|alquiler|venta|inmueble/.test(value)) return "inmuebles";
  if (/hbo|disney|prime|stream|pelicula|serie|max|video/.test(value)) return "streaming";
  if (/iphone|samsung|notebook|celular|tecnologia|apple|lenovo/.test(value)) return "tecnologia";
  if (/zapatilla|ropa|moda|talle|campera|jean/.test(value)) return "moda";
  if (/mueble|mesa|sillon|hogar|cocina|dormitorio/.test(value)) return "hogar";
  if (/taladro|herramienta|bosch|makita|dewalt/.test(value)) return "herramientas";
  if (/super|limpieza|bebida|almacen|pack/.test(value)) return "supermercado";
  return undefined;
}

export function tagsFromQuery(query: string) {
  return normalize(query)
    .split(/\s+/)
    .map((word) => word.trim())
    .filter((word) => word.length > 2)
    .slice(0, 8);
}

export function getRecommendationShelves(
  state: MarketplaceState,
  userId: string,
): RecommendationShelves {
  const user = state.users.find((candidate) => candidate.id === userId);
  const history = state.views
    .filter((view) => view.userId === userId)
    .sort((a, b) => new Date(b.viewedAt).getTime() - new Date(a.viewedAt).getTime());
  const searches = state.searches
    .filter((search) => search.userId === userId)
    .sort((a, b) => new Date(b.searchedAt).getTime() - new Date(a.searchedAt).getTime());
  const hasPersonalActivity = history.length > 0 || searches.length > 0;
  const viewedIds = new Set(history.map((view) => view.listingId));
  const personalTags = [
    ...history.flatMap((view) => view.tags),
    ...searches.flatMap((search) => search.tags),
  ];
  const recentlyViewed = history
    .map((view) => state.listings.find((listing) => listing.id === view.listingId))
    .filter((listing): listing is Listing => Boolean(listing))
    .slice(0, 6);

  const inspiredByHistory = hasPersonalActivity
    ? state.listings
        .filter((listing) => !viewedIds.has(listing.id))
        .map((listing) => ({
          listing,
          score: scoreListing(listing, history, searches, personalTags),
        }))
        .filter(({ score }) => score > 4)
        .sort((a, b) => b.score - a.score)
        .map(({ listing }) => listing)
        .slice(0, 10)
    : [];

  const userArea = normalize(user?.location.split(",")[0] ?? "");
  const nearYou = userArea
    ? state.listings
        .filter((listing) => listing.source === "user")
        .filter((listing) => normalize(listing.location).includes(userArea.split(" ")[0] ?? ""))
        .sort((a, b) => b.rating + b.views / 200 - (a.rating + a.views / 200))
        .slice(0, 8)
    : [];

  const trending = [...state.listings]
    .filter((listing) => listing.source === "catalog" || hasPersonalActivity)
    .sort((a, b) => b.views + b.sold * 12 + b.rating * 20 - (a.views + a.sold * 12 + a.rating * 20))
    .slice(0, 8);

  return {
    recentlyViewed,
    inspiredByHistory,
    nearYou,
    trending,
    hasPersonalActivity,
  };
}

export function sortListingsForCategory(
  listings: Listing[],
  categoryId: CategoryId,
  sortMode: string,
) {
  const sorted = [...listings].filter((listing) => listing.categoryId === categoryId);

  if (/menor precio/i.test(sortMode)) {
    return sorted.sort((a, b) => a.price - b.price);
  }

  if (/mayor descuento|descuentos/i.test(sortMode)) {
    return sorted.sort((a, b) => {
      const discountA = a.oldPrice ? (a.oldPrice - a.price) / a.oldPrice : 0;
      const discountB = b.oldPrice ? (b.oldPrice - b.price) / b.oldPrice : 0;
      return discountB - discountA;
    });
  }

  if (/kilometraje/i.test(sortMode)) {
    return sorted.sort((a, b) => {
      const kmA = Number(String(a.meta.kilometraje ?? "999999").replace(/\D/g, "")) || 999999;
      const kmB = Number(String(b.meta.kilometraje ?? "999999").replace(/\D/g, "")) || 999999;
      return kmA - kmB;
    });
  }

  if (/anio/i.test(sortMode)) {
    return sorted.sort((a, b) => Number(b.meta.anio ?? 0) - Number(a.meta.anio ?? 0));
  }

  if (/superficie/i.test(sortMode)) {
    return sorted.sort((a, b) => {
      const metersA = Number(String(a.meta.metros ?? "0").replace(/\D/g, "")) || 0;
      const metersB = Number(String(b.meta.metros ?? "0").replace(/\D/g, "")) || 0;
      return metersB - metersA;
    });
  }

  if (/rapida|rating/i.test(sortMode)) {
    return sorted.sort((a, b) => b.rating + b.sold / 100 - (a.rating + a.sold / 100));
  }

  if (/recientes|novedades/i.test(sortMode)) {
    return sorted.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
  }

  return sorted.sort((a, b) => b.views + b.rating * 120 - (a.views + a.rating * 120));
}

export function matchesListingQuery(listing: Listing, query: string) {
  const needle = normalize(query.trim());
  if (!needle) {
    return true;
  }

  const haystack = normalize(
    [
      listing.title,
      listing.description,
      listing.location,
      listing.shipping,
      listing.condition,
      listing.tags.join(" "),
      Object.values(listing.meta).join(" "),
    ].join(" "),
  );

  return haystack.includes(needle);
}

export function matchesCategoryFilter(listing: Listing, activeFilter: string | null) {
  if (!activeFilter) {
    return true;
  }

  const needle = normalize(activeFilter);
  const values = [
    ...listing.tags,
    ...Object.values(listing.meta).map((value) => String(value)),
    listing.badge ?? "",
    listing.shipping,
  ];

  return values.some((value) => normalize(value).includes(needle));
}

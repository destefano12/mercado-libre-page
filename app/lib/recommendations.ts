import type { CategoryId, Listing, MarketplaceState, ViewEvent } from "../data/marketplace";

export interface RecommendationShelves {
  recentlyViewed: Listing[];
  inspiredByHistory: Listing[];
  nearYou: Listing[];
  trending: Listing[];
}

function normalize(value: string) {
  return value.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
}

function categoryWeight(history: ViewEvent[], categoryId: CategoryId) {
  return history.reduce((score, view, index) => {
    if (view.categoryId !== categoryId) {
      return score;
    }

    return score + Math.max(1, 8 - index * 1.4);
  }, 0);
}

function tagOverlap(historyTags: string[], listing: Listing) {
  const normalizedHistory = new Set(historyTags.map(normalize));
  return listing.tags.reduce(
    (score, tag) => score + (normalizedHistory.has(normalize(tag)) ? 3 : 0),
    0,
  );
}

function freshnessScore(createdAt: string) {
  const created = new Date(createdAt).getTime();
  const now = new Date("2026-07-24T02:00:00.000Z").getTime();
  const ageHours = Math.max(1, (now - created) / 1000 / 60 / 60);
  return Math.max(0, 8 - ageHours / 8);
}

function scoreListing(listing: Listing, history: ViewEvent[], historyTags: string[]) {
  const popularity = Math.min(10, listing.views / 180) + Math.min(5, listing.sold / 30);
  const commercialBoost = listing.badge ? 2 : 0;
  const sponsoredBoost = listing.sponsored ? 1.5 : 0;

  return (
    categoryWeight(history, listing.categoryId) +
    tagOverlap(historyTags, listing) +
    popularity +
    freshnessScore(listing.createdAt) +
    listing.rating +
    commercialBoost +
    sponsoredBoost
  );
}

export function getRecommendationShelves(
  state: MarketplaceState,
  userId: string,
): RecommendationShelves {
  const user = state.users.find((candidate) => candidate.id === userId);
  const history = state.views
    .filter((view) => view.userId === userId)
    .sort((a, b) => new Date(b.viewedAt).getTime() - new Date(a.viewedAt).getTime());
  const viewedIds = new Set(history.map((view) => view.listingId));
  const historyTags = history.flatMap((view) => view.tags);
  const recentlyViewed = history
    .map((view) => state.listings.find((listing) => listing.id === view.listingId))
    .filter((listing): listing is Listing => Boolean(listing))
    .slice(0, 6);

  const inspiredByHistory = state.listings
    .filter((listing) => !viewedIds.has(listing.id))
    .map((listing) => ({
      listing,
      score: scoreListing(listing, history, historyTags),
    }))
    .sort((a, b) => b.score - a.score)
    .map(({ listing }) => listing)
    .slice(0, 10);

  const userArea = user?.location.split(",")[0] ?? "";
  const nearYou = state.listings
    .filter((listing) => normalize(listing.location).includes(normalize(userArea.split(" ")[0] ?? "")))
    .sort((a, b) => b.rating + b.views / 200 - (a.rating + a.views / 200))
    .slice(0, 8);

  const trending = [...state.listings]
    .sort((a, b) => b.views + b.sold * 12 - (a.views + a.sold * 12))
    .slice(0, 8);

  return {
    recentlyViewed,
    inspiredByHistory,
    nearYou,
    trending,
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

  if (/mayor descuento/i.test(sortMode)) {
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

  if (/año/i.test(sortMode)) {
    return sorted.sort((a, b) => Number(b.meta.año ?? 0) - Number(a.meta.año ?? 0));
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

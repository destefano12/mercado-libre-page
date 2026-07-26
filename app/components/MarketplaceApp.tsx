"use client";

import { useEffect, useMemo, useState } from "react";
import mercadoLibreLogo from "@/IMG/official/mercado-libre-logo.webp";
import homeHero from "@/IMG/official/home-hero.webp";
import headerOffer from "@/IMG/official/header-offer.webp";
import newBuyerIcon from "@/IMG/official/new-buyer.svg";
import registrationIcon from "@/IMG/official/registration.svg";
import paymentMethodsIcon from "@/IMG/official/payment-methods.svg";
import categoryVehicles from "@/IMG/official/category-vehicles.webp";
import categoryProperties from "@/IMG/official/category-properties.webp";
import categoryTechnology from "@/IMG/official/category-technology.webp";
import categoryFashion from "@/IMG/official/category-fashion.webp";
import categoryHome from "@/IMG/official/category-home.webp";
import categoryTools from "@/IMG/official/category-tools.webp";
import categoryStreaming from "@/IMG/official/category-streaming.webp";
import categorySupermarket from "@/IMG/official/category-supermarket.webp";
import {
  categories,
  type CategoryId,
  type ChatThread,
  type Listing,
} from "../data/marketplace";
import {
  getRecommendationShelves,
  inferCategoryFromText,
  matchesCategoryFilter,
  matchesListingQuery,
  sortListingsForCategory,
} from "../lib/recommendations";
import {
  useMarketplaceStore,
  type PublishListingInput,
} from "../lib/useMarketplaceStore";
import { AuthModal } from "./AuthModal";
import { ChatDock } from "./ChatDock";
import { MessagesView } from "./MessagesView";
import { formatPrice, ListingVisual, ProductCard } from "./ProductCard";
import { PublishModal } from "./PublishModal";
import { ReviewSection } from "./ReviewSection";
import { ShippingMap } from "./ShippingMap";

type ViewName =
  | "home"
  | "results"
  | "detail"
  | "purchases"
  | "coupons"
  | "offers"
  | "favorites"
  | "messages"
  | "help"
  | "cart";

function assetSource(asset: string | { src: string }) {
  return typeof asset === "string" ? asset : asset.src;
}

const officialAssets = {
  logo: assetSource(mercadoLibreLogo),
  hero: assetSource(homeHero),
  headerOffer: assetSource(headerOffer),
  newBuyer: assetSource(newBuyerIcon),
  registration: assetSource(registrationIcon),
  paymentMethods: assetSource(paymentMethodsIcon),
};

const categoryImages: Partial<Record<CategoryId, string>> = {
  vehiculos: assetSource(categoryVehicles),
  inmuebles: assetSource(categoryProperties),
  streaming: assetSource(categoryStreaming),
  tecnologia: assetSource(categoryTechnology),
  moda: assetSource(categoryFashion),
  hogar: assetSource(categoryHome),
  herramientas: assetSource(categoryTools),
  supermercado: assetSource(categorySupermarket),
};

const fallbackCategoryImage = assetSource(categoryHome);

const categoryMenuOrder: CategoryId[] = [
  "vehiculos",
  "inmuebles",
  "supermercado",
  "tecnologia",
  "internacional",
  "hogar",
  "electrodomesticos",
  "herramientas",
  "construccion",
  "deportes",
  "accesorios-vehiculos",
  "negocio",
  "mascotas",
  "moda",
  "juegos",
  "bebes",
  "belleza",
  "salud",
  "industrias",
  "agro",
  "sustentables",
  "servicios",
  "mas-vendidos",
  "tiendas-oficiales",
];

function useSelectedThread(
  state: ReturnType<typeof useMarketplaceStore>["state"],
  activeUserId: string | undefined,
  listing?: Listing,
  selectedThreadId?: string | null,
) {
  return useMemo(() => {
    if (!listing) {
      return undefined;
    }

    if (selectedThreadId) {
      return state.chats.find(
        (thread) =>
          thread.id === selectedThreadId &&
          thread.listingId === listing.id &&
          (thread.buyerId === activeUserId || thread.sellerId === activeUserId),
      );
    }

    if (listing.sellerId === activeUserId) {
      return undefined;
    }

    return state.chats.find(
      (thread) =>
        thread.listingId === listing.id &&
        thread.buyerId === activeUserId,
    );
  }, [activeUserId, listing, selectedThreadId, state.chats]);
}

function listingCategory(listing?: Listing) {
  return categories.find((category) => category.id === listing?.categoryId);
}

function CategoryGlyph({ categoryId }: { categoryId: CategoryId }) {
  return (
    <span className={`category-glyph category-glyph--${categoryId}`}>
      <img src={categoryImages[categoryId] ?? fallbackCategoryImage} alt="" />
    </span>
  );
}

function LocationIcon() {
  return (
    <svg className="ml-nav-icon ml-nav-icon--location" viewBox="0 0 18 22" aria-hidden="true">
      <path d="M9 21S2 12.9 2 7.9C2 4 5.1 1 9 1s7 3 7 6.9C16 12.9 9 21 9 21Z" />
      <path d="M9 10.6a2.7 2.7 0 1 0 0-5.4 2.7 2.7 0 0 0 0 5.4Z" />
    </svg>
  );
}

function BellIcon() {
  return (
    <svg className="ml-nav-icon ml-nav-icon--bell" viewBox="0 0 20 22" aria-hidden="true">
      <path d="M16.8 14.7c-1.2-1.4-1.8-2.9-1.8-5V8a5 5 0 0 0-10 0v1.7c0 2.1-.6 3.6-1.8 5L2 16h16l-1.2-1.3Z" />
      <path d="M7.4 18.2a2.7 2.7 0 0 0 5.2 0" />
      <path d="M10 1v2" />
    </svg>
  );
}

function CartIcon() {
  return (
    <svg className="ml-nav-icon ml-nav-icon--cart" viewBox="0 0 24 22" aria-hidden="true">
      <path d="M1.7 2.2h3l2.4 11.2a2.1 2.1 0 0 0 2.1 1.7h8.4a2.1 2.1 0 0 0 2-1.5l1.8-6.7H6" />
      <path d="M9.3 20.1a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3Z" />
      <path d="M18 20.1a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3Z" />
    </svg>
  );
}

function PurchasesEmptyIcon() {
  return (
    <svg className="purchases-empty__icon" viewBox="0 0 260 160" aria-hidden="true">
      <path d="M38 136h184" />
      <path d="M83 32h94a10 10 0 0 1 10 10v86H73V42a10 10 0 0 1 10-10Z" />
      <path d="M95 48h80v72H85V48h10Z" />
      <path d="M57 128h146l-8 16H65l-8-16Z" />
      <path d="M101 128h58v8h-58v-8Z" />
      <circle cx="130" cy="85" r="38" />
      <path d="M116 76c1.8-10.8 10.6-16.8 21.2-14.4 10 2.2 16 11.2 12.2 21-2 5.4-6.2 8.8-11.2 12.4-4.6 3.2-6.6 6.2-6.6 11.8" />
      <path d="M131.5 119h.2" />
      <path className="purchases-empty__pen" d="M173 18l-36 42 10 8 36-42-10-8Z" />
    </svg>
  );
}

function WalletIcon() {
  return (
    <svg className="service-icon" viewBox="0 0 28 28" aria-hidden="true">
      <path d="M5 8.5h17a3 3 0 0 1 3 3v9a3 3 0 0 1-3 3H5a3 3 0 0 1-3-3v-9a3 3 0 0 1 3-3Z" />
      <path d="M7 8.5V5h12v3.5" />
      <path d="M20 15.5h5" />
      <path d="M20 18h.1" />
    </svg>
  );
}

function TruckIcon() {
  return (
    <svg className="service-icon" viewBox="0 0 30 28" aria-hidden="true">
      <path d="M3 8h16v12H3V8Z" />
      <path d="M19 12h4l4 4v4h-8v-8Z" />
      <path d="M8 23a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5Z" />
      <path d="M22 23a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5Z" />
    </svg>
  );
}

function CreditIcon() {
  return (
    <svg className="service-icon" viewBox="0 0 28 28" aria-hidden="true">
      <path d="M4 7h20a2 2 0 0 1 2 2v13a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2Z" />
      <path d="M2 12h24" />
      <path d="M7 18h5" />
    </svg>
  );
}

function ShieldIcon() {
  return (
    <svg className="service-icon" viewBox="0 0 28 28" aria-hidden="true">
      <path d="M14 3 24 7v7c0 6-4 9.5-10 11-6-1.5-10-5-10-11V7l10-4Z" />
      <path d="m9.5 14 3 3 6-7" />
    </svg>
  );
}

export function MarketplaceApp() {
  const { state, activeUser, ratingSummaries, actions } = useMarketplaceStore();
  const [view, setView] = useState<ViewName>("home");
  const [query, setQuery] = useState("");
  const [searchSuggestionsOpen, setSearchSuggestionsOpen] = useState(false);
  const [resultQuery, setResultQuery] = useState("");
  const [resultCategoryId, setResultCategoryId] = useState<CategoryId | undefined>();
  const [sortMode, setSortMode] = useState("Más relevantes");
  const [activeFilters, setActiveFilters] = useState<Record<string, string>>({});
  const [selectedListingId, setSelectedListingId] = useState<string | null>(null);
  const [selectedThreadId, setSelectedThreadId] = useState<string | null>(null);
  const [categoryMenuOpen, setCategoryMenuOpen] = useState(false);
  const [accountMenuOpen, setAccountMenuOpen] = useState(false);
  const [favoritesMenuOpen, setFavoritesMenuOpen] = useState(false);
  const [notificationsOpen, setNotificationsOpen] = useState(false);
  const [chatOpen, setChatOpen] = useState(false);
  const [publishOpen, setPublishOpen] = useState(false);
  const [favoriteIds, setFavoriteIds] = useState<string[]>([]);
  const [cartIds, setCartIds] = useState<string[]>([]);
  const [couponCode, setCouponCode] = useState("");
  const [appliedCoupon, setAppliedCoupon] = useState<string | null>(null);
  const [helpTopic, setHelpTopic] = useState<string | null>(null);
  const [preferencesReady, setPreferencesReady] = useState(false);
  const [locationModalOpen, setLocationModalOpen] = useState(false);
  const [locationDraft, setLocationDraft] = useState("");
  const [locationError, setLocationError] = useState("");
  const [locationSaving, setLocationSaving] = useState(false);

  useEffect(() => {
    const timer = window.setInterval(actions.advanceShipments, 2400);
    return () => window.clearInterval(timer);
  }, [actions.advanceShipments]);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      if (!activeUser) {
        setPreferencesReady(false);
        return;
      }

      try {
        const saved = window.localStorage.getItem(`mercado-live:preferences:${activeUser.id}`);
        const parsed = saved ? JSON.parse(saved) as { favorites?: string[]; cart?: string[] } : {};
        setFavoriteIds(Array.isArray(parsed.favorites) ? parsed.favorites : []);
        setCartIds(Array.isArray(parsed.cart) ? parsed.cart : []);
      } catch {
        setFavoriteIds([]);
        setCartIds([]);
      }
      setPreferencesReady(true);
    }, 0);

    return () => window.clearTimeout(timer);
  }, [activeUser]);

  useEffect(() => {
    if (!activeUser || !preferencesReady) {
      return;
    }

    window.localStorage.setItem(
      `mercado-live:preferences:${activeUser.id}`,
      JSON.stringify({ favorites: favoriteIds, cart: cartIds }),
    );
  }, [activeUser, cartIds, favoriteIds, preferencesReady]);

  const selectedListing = useMemo(
    () => state.listings.find((listing) => listing.id === selectedListingId),
    [selectedListingId, state.listings],
  );
  const selectedThread = useSelectedThread(
    state,
    activeUser?.id,
    selectedListing,
    selectedThreadId,
  );
  const selectedSeller = state.users.find((user) => user.id === selectedListing?.sellerId);
  const selectedProductRating = selectedListing
    ? ratingSummaries.listings[selectedListing.id] ?? { average: 0, count: 0 }
    : { average: 0, count: 0 };
  const selectedSellerRating = selectedListing
    ? ratingSummaries.sellers[selectedListing.sellerId] ?? { average: 0, count: 0 }
    : { average: 0, count: 0 };
  const selectedCategory = listingCategory(selectedListing);
  const shelves = useMemo(
    () => (activeUser ? getRecommendationShelves(state, activeUser.id) : null),
    [activeUser, state],
  );
  const notificationItems = useMemo(() => {
    const live = state.notifications.slice(0, 4).map((notification) => ({
      id: notification.id,
      title: notification.text,
      body: "Actividad reciente del marketplace",
    }));

    return [
      ...live,
      {
        id: "benefit-shipping",
        title: "Envios gratis desde $ 16.000",
        body: "El beneficio se calcula segun tu ubicacion y el vendedor.",
      },
      {
        id: "benefit-coupon",
        title: "Cupones disponibles",
        body: "Revisa la seccion Cupones para aplicar descuentos.",
      },
      {
        id: "benefit-play",
        title: "Mercado Play gratis",
        body: "Series y accesos digitales desde el catalogo inicial.",
      },
    ].slice(0, 5);
  }, [state.notifications]);
  const streamingCatalog = useMemo(
    () =>
      sortListingsForCategory(state.listings, "streaming", "Entrega más rápida").filter(
        (listing) => listing.source === "catalog",
      ),
    [state.listings],
  );
  const userListings = useMemo(
    () =>
      state.listings
        .filter((listing) => listing.source === "user")
        .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()),
    [state.listings],
  );
  const liveResults = useMemo(
    () =>
      query.trim()
        ? state.listings
            .filter((listing) => matchesListingQuery(listing, query))
            .sort((a, b) => b.views + b.rating * 10 - (a.views + a.rating * 10))
            .slice(0, 6)
        : [],
    [query, state.listings],
  );
  const resultCategory = categories.find((category) => category.id === resultCategoryId);
  const categoryMenuItems = useMemo(
    () =>
      categoryMenuOrder
        .map((categoryId) => categories.find((category) => category.id === categoryId))
        .filter((category): category is (typeof categories)[number] => Boolean(category)),
    [],
  );
  const resultListings = useMemo(() => {
    let listings = resultCategoryId
      ? sortListingsForCategory(state.listings, resultCategoryId, sortMode)
      : [...state.listings].sort(
          (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
        );

    if (resultQuery) {
      listings = listings.filter((listing) => matchesListingQuery(listing, resultQuery));
    }

    return listings.filter((listing) =>
      Object.values(activeFilters).every((filter) => matchesCategoryFilter(listing, filter)),
    );
  }, [activeFilters, resultCategoryId, resultQuery, sortMode, state.listings]);
  const purchases = useMemo(
    () => state.shipments.filter((shipment) => shipment.buyerId === activeUser?.id),
    [activeUser?.id, state.shipments],
  );
  const favoriteListings = useMemo(
    () => state.listings.filter((listing) => favoriteIds.includes(listing.id)),
    [favoriteIds, state.listings],
  );
  const cartListings = useMemo(
    () => state.listings.filter((listing) => cartIds.includes(listing.id)),
    [cartIds, state.listings],
  );
  const offerListings = useMemo(
    () => state.listings.filter((listing) => listing.oldPrice || listing.badge),
    [state.listings],
  );
  const cartSubtotal = useMemo(
    () => cartListings.reduce((total, listing) => total + listing.price, 0),
    [cartListings],
  );
  const accountThreads = useMemo(
    () =>
      state.chats
        .filter(
          (thread) =>
            thread.buyerId === activeUser?.id || thread.sellerId === activeUser?.id,
        )
        .sort(
          (a, b) =>
            new Date(b.lastMessageAt).getTime() - new Date(a.lastMessageAt).getTime(),
        ),
    [activeUser?.id, state.chats],
  );
  const unreadMessageCount = useMemo(
    () =>
      accountThreads.reduce(
        (total, thread) =>
          total +
          thread.messages.filter(
            (message) => message.senderId !== activeUser?.id && !message.read,
          ).length,
        0,
      ),
    [accountThreads, activeUser?.id],
  );
  const relatedListings = useMemo(
    () =>
      selectedListing
        ? state.listings
            .filter(
              (listing) =>
                listing.id !== selectedListing.id &&
                listing.categoryId === selectedListing.categoryId,
            )
            .slice(0, 5)
        : [],
    [selectedListing, state.listings],
  );

  function goHome() {
    setView("home");
    setSelectedListingId(null);
    setSelectedThreadId(null);
    setChatOpen(false);
    setCategoryMenuOpen(false);
    setSearchSuggestionsOpen(false);
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  function openCategory(categoryId: CategoryId) {
    const category = categories.find((candidate) => candidate.id === categoryId);
    setResultCategoryId(categoryId);
    setResultQuery("");
    setQuery("");
    setSearchSuggestionsOpen(false);
    setSortMode(category?.sortModes[0] ?? "Más relevantes");
    setActiveFilters({});
    setCategoryMenuOpen(false);
    setView("results");
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  function submitSearch(value = query) {
    const cleanQuery = value.trim();
    if (!cleanQuery) {
      return;
    }

    const inferredCategory = inferCategoryFromText(cleanQuery);
    actions.recordSearch(cleanQuery);
    setResultQuery(cleanQuery);
    setResultCategoryId(inferredCategory);
    setSortMode(
      categories.find((category) => category.id === inferredCategory)?.sortModes[0] ??
        "Más relevantes",
    );
    setActiveFilters({});
    setView("results");
    setCategoryMenuOpen(false);
    setQuery(cleanQuery);
    setSearchSuggestionsOpen(false);
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  function openListing(listing: Listing) {
    actions.recordView(listing.id);
    setSelectedListingId(listing.id);
    setSelectedThreadId(null);
    setView("detail");
    setChatOpen(false);
    setQuery("");
    setSearchSuggestionsOpen(false);
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  function openReviews(listing: Listing) {
    openListing(listing);
    window.setTimeout(() => {
      document.getElementById("reviews")?.scrollIntoView({ behavior: "smooth" });
    }, 120);
  }

  function publishListing(input: PublishListingInput) {
    const id = actions.publishListing(input);
    setPublishOpen(false);
    if (id) {
      setSelectedListingId(id);
      setView("detail");
      window.scrollTo({ top: 0, behavior: "smooth" });
    }
  }

  function openConversation(listing: Listing) {
    const seller = state.users.find((user) => user.id === listing.sellerId);
    if (seller?.isSystem) {
      return;
    }
    if (listing.sellerId === activeUser?.id) {
      openPage("messages");
      return;
    }

    const existingThread = state.chats.find(
      (thread) =>
        thread.listingId === listing.id &&
        thread.buyerId === activeUser?.id &&
        thread.sellerId === listing.sellerId,
    );
    setSelectedListingId(listing.id);
    setSelectedThreadId(existingThread?.id ?? null);
    setChatOpen(true);
    if (existingThread) {
      actions.markThreadRead(existingThread.id);
    }
  }

  function openThread(thread: ChatThread, listing: Listing) {
    setSelectedListingId(listing.id);
    setSelectedThreadId(thread.id);
    setChatOpen(true);
    actions.markThreadRead(thread.id);
  }

  function toggleFilter(label: string, value: string) {
    setActiveFilters((previous) => {
      if (previous[label] === value) {
        const next = { ...previous };
        delete next[label];
        return next;
      }
      return { ...previous, [label]: value };
    });
  }

  function openPage(nextView: ViewName) {
    setView(nextView);
    setCategoryMenuOpen(false);
    setAccountMenuOpen(false);
    setFavoritesMenuOpen(false);
    setNotificationsOpen(false);
    setSearchSuggestionsOpen(false);
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  function addToCart(listingId: string) {
    setCartIds((previous) =>
      previous.includes(listingId) ? previous : [...previous, listingId],
    );
    openPage("cart");
  }

  function checkoutCart() {
    cartListings.forEach((listing) => actions.buyListing(listing));
    setCartIds([]);
    openPage("purchases");
  }

  if (!activeUser) {
    return (
      <main className="marketplace-shell marketplace-shell--auth">
        <header className="auth-header">
          <img className="ml-logo" src={officialAssets.logo} alt="Mercado Libre" />
        </header>
        <section className="auth-stage">
          <AuthModal
            onLogin={actions.login}
            onRegister={actions.registerUser}
            blocking
          />
        </section>
      </main>
    );
  }

  return (
    <main className="marketplace-shell">
      <header className="site-header">
        <div className="header-primary">
          <button className="logo-button" type="button" onClick={goHome} aria-label="Ir al inicio">
            <img className="ml-logo" src={officialAssets.logo} alt="" />
          </button>

          <div className="search-shell">
            <form
              className="search-box"
              onSubmit={(event) => {
                event.preventDefault();
                submitSearch();
              }}
            >
              <input
                value={query}
                onChange={(event) => {
                  setQuery(event.target.value);
                  setSearchSuggestionsOpen(true);
                }}
                onFocus={() => setSearchSuggestionsOpen(true)}
                placeholder="Buscar productos, marcas y más..."
                aria-label="Buscar productos, marcas y más"
              />
              {query ? (
                <button
                  className="search-box__clear"
                  type="button"
                  onClick={() => {
                    setQuery("");
                    setSearchSuggestionsOpen(false);
                  }}
                  aria-label="Borrar búsqueda"
                  title="Borrar búsqueda"
                >
                  ×
                </button>
              ) : null}
              <button className="search-box__submit" type="submit" aria-label="Buscar" title="Buscar">
                <span />
              </button>
            </form>

            {query.trim() && searchSuggestionsOpen ? (
              <div className="search-suggestions">
                <button className="search-suggestions__all" type="button" onClick={() => submitSearch()}>
                  <span className="search-mini-icon" />
                  <strong>Buscar “{query}”</strong>
                </button>
                {liveResults.map((listing) => (
                  <button key={listing.id} type="button" onClick={() => openListing(listing)}>
                    <CategoryGlyph categoryId={listing.categoryId} />
                    <span>
                      <strong>{listing.title}</strong>
                      <small>{formatPrice(listing.price)}</small>
                    </span>
                  </button>
                ))}
                {liveResults.length === 0 ? (
                  <p>No hay publicaciones que coincidan todavía.</p>
                ) : null}
              </div>
            ) : null}
          </div>

          <button className="header-offer" type="button" onClick={() => openPage("offers")}>
            <img src={officialAssets.headerOffer} alt="Envío gratis en tu primera compra" />
          </button>
        </div>

        <nav className="header-secondary" aria-label="Navegación principal">
          <button
            className="delivery-location"
            type="button"
            onClick={() => {
              setLocationDraft(activeUser.location);
              setLocationError("");
              setLocationModalOpen(true);
            }}
          >
            <LocationIcon />
            <span>
              Enviar a
              <strong>{activeUser.location}</strong>
            </span>
          </button>

          <div className="nav-links">
            <button type="button" onClick={() => setCategoryMenuOpen((open) => !open)}>
              Categorías <span className="nav-chevron">⌄</span>
            </button>
            <button type="button" onClick={() => openPage("offers")}>Ofertas</button>
            <button type="button" onClick={() => openPage("coupons")}>Cupones</button>
            <button type="button" onClick={() => openCategory("supermercado")}>Supermercado</button>
            <button type="button" onClick={() => openCategory("moda")}>Moda</button>
            <button className="nav-play-link" type="button" onClick={() => openCategory("streaming")}>
              <span>GRATIS</span>
              Mercado Play
            </button>
            <button type="button" onClick={() => setPublishOpen(true)}>Vender</button>
            <button type="button" onClick={() => openPage("help")}>Ayuda</button>
          </div>

          <div className="account-links">
            <button
              className="account-button"
              type="button"
              onClick={() => setAccountMenuOpen((open) => !open)}
            >
              <span>{activeUser.avatar}</span>
              {activeUser.name.split(" ")[0].toUpperCase()}
              <span className="nav-chevron">⌄</span>
            </button>
            <button type="button" onClick={() => openPage("purchases")}>Mis compras</button>
            <button
              className={favoritesMenuOpen ? "is-open" : ""}
              type="button"
              onClick={() => {
                setFavoritesMenuOpen((open) => !open);
                setAccountMenuOpen(false);
                setCategoryMenuOpen(false);
              }}
            >
              Favoritos <span className="nav-chevron">⌄</span>
            </button>
            <button
              className="notification-button"
              type="button"
              title="Mensajes"
              aria-label={`${unreadMessageCount} mensajes sin leer`}
              onClick={() => {
                setNotificationsOpen((open) => !open);
                setAccountMenuOpen(false);
                setFavoritesMenuOpen(false);
                setCategoryMenuOpen(false);
              }}
            >
              <BellIcon />
              {unreadMessageCount ? <b>{Math.min(unreadMessageCount, 99)}</b> : null}
            </button>
            <button className="cart-button" type="button" title="Carrito" aria-label={`${cartIds.length} productos en tu carrito`} onClick={() => openPage("cart")}>
              <CartIcon />
              <span>{cartIds.length || ""}</span>
            </button>
          </div>
        </nav>

        {notificationsOpen ? (
          <>
            <button
              className="menu-backdrop menu-backdrop--clear"
              type="button"
              aria-label="Cerrar notificaciones"
              onClick={() => setNotificationsOpen(false)}
            />
            <div className="notifications-popover">
              <div className="notifications-popover__heading">
                <strong>Notificaciones</strong>
                <button
                  type="button"
                  onClick={() => {
                    setNotificationsOpen(false);
                    openPage("messages");
                  }}
                >
                  Ver mensajes
                </button>
              </div>
              <div className="notifications-popover__list">
                {notificationItems.map((item) => (
                  <button
                    key={item.id}
                    type="button"
                    onClick={() => {
                      setNotificationsOpen(false);
                      if (item.id.includes("coupon")) {
                        openPage("coupons");
                        return;
                      }
                      openPage("offers");
                    }}
                  >
                    <span aria-hidden="true" />
                    <div>
                      <strong>{item.title}</strong>
                      <small>{item.body}</small>
                    </div>
                  </button>
                ))}
              </div>
            </div>
          </>
        ) : null}

        {favoritesMenuOpen ? (
          <>
            <button
              className="menu-backdrop menu-backdrop--clear"
              type="button"
              aria-label="Cerrar favoritos"
              onClick={() => setFavoritesMenuOpen(false)}
            />
            <div className="favorites-popover">
              <div className="favorites-popover__title">Favoritos</div>
              <div className="favorites-popover__body">
                {favoriteListings.length > 0 ? (
                  <div className="favorites-popover__list">
                    {favoriteListings.slice(0, 3).map((listing) => (
                      <button
                        key={listing.id}
                        type="button"
                        onClick={() => {
                          setFavoritesMenuOpen(false);
                          openListing(listing);
                        }}
                      >
                        <ListingVisual visual={listing.visual} />
                        <span>{listing.title}</span>
                      </button>
                    ))}
                  </div>
                ) : (
                  <p>Agregá acá los productos que te gustaron para poder verlos más tarde.</p>
                )}
              </div>
              <button
                className="favorites-popover__link"
                type="button"
                onClick={() => {
                  setFavoritesMenuOpen(false);
                  openPage("favorites");
                }}
              >
                Ver todos los favoritos y listas
              </button>
            </div>
          </>
        ) : null}

        {accountMenuOpen ? (
          <div className="account-menu">
            <div className="account-menu__profile">
              <span>{activeUser.avatar}</span>
              <p>
                <strong>{activeUser.name.toUpperCase()}</strong>
                <small>{activeUser.email}</small>
              </p>
              <button type="button" aria-label="Cerrar cuenta" onClick={() => setAccountMenuOpen(false)}>
                <span>⌃</span>
              </button>
            </div>
            <button className="account-menu__add" type="button" onClick={() => openPage("help")}>
              <span aria-hidden="true" />
              Agregar cuenta
            </button>
            <button className="account-menu__meli" type="button" onClick={() => openPage("help")}>
              meli+ Viví Mercado Libre como un experto <span>›</span>
            </button>
            <div className="account-menu__section">
              <button type="button" onClick={() => openPage("purchases")}>Compras</button>
              <button type="button" onClick={() => submitSearch("historial")}>Historial</button>
              <button
                type="button"
                onClick={() => {
                  setHelpTopic("buy");
                  openPage("help");
                }}
              >
                Preguntas
              </button>
              <button type="button" onClick={() => openPage("purchases")}>Opiniones</button>
            </div>
            <div className="account-menu__section">
              <button type="button" onClick={() => openPage("coupons")}>Créditos</button>
              <button type="button" onClick={() => openCategory("streaming")}>Suscripciones</button>
              <button type="button" onClick={() => openCategory("streaming")}>
                Mercado Play <span className="account-menu__free">GRATIS</span>
              </button>
            </div>
            <div className="account-menu__section">
              <button type="button" onClick={() => setPublishOpen(true)}>Vender</button>
              <button type="button" onClick={() => openPage("messages")}>
                Resumen{unreadMessageCount ? ` (${Math.min(unreadMessageCount, 99)})` : ""}
              </button>
            </div>
            <button
              className="account-menu__logout"
              type="button"
              onClick={async () => {
                setAccountMenuOpen(false);
                setView("home");
                setSelectedListingId(null);
                setSelectedThreadId(null);
                setChatOpen(false);
                await actions.logout();
              }}
            >
              Salir
            </button>
          </div>
        ) : null}

        {categoryMenuOpen ? (
          <>
            <button
              className="menu-backdrop"
              type="button"
              aria-label="Cerrar categorías"
              onClick={() => setCategoryMenuOpen(false)}
            />
            <div className="category-menu">
              <div className="category-menu__list">
                {categoryMenuItems.map((category) => (
                  <button key={category.id} type="button" onClick={() => openCategory(category.id)}>
                    {category.label}
                    {category.id === "tecnologia" ? <span>›</span> : null}
                  </button>
                ))}
                <button type="button" onClick={() => openCategory("streaming")}>
                  Ver mas categorias
                </button>
              </div>
            </div>
          </>
        ) : null}
      </header>

      {view === "home" ? (
        <>
          <section className="home-hero" aria-label="Promociones destacadas">
            <img src={officialAssets.hero} alt="Ofertazos: hasta 30% off y hasta 18 cuotas sin interés" />
          </section>

          <div className="home-content">
            <section className="quick-access" aria-label="Accesos rápidos">
              <button type="button" onClick={() => openPage("offers")}>
                <span className="quick-icon"><img src={officialAssets.newBuyer} alt="" /></span>
                <strong>Envío gratis</strong>
                <p>Beneficio en tu primera compra</p>
                <small>Mostrar productos</small>
              </button>
              <button
                type="button"
                onClick={() =>
                  shelves?.recentlyViewed[0]
                    ? openListing(shelves.recentlyViewed[0])
                    : openCategory("streaming")
                }
              >
                <span className="quick-icon quick-icon--history" />
                <strong>Visto recientemente</strong>
                <p>{shelves?.recentlyViewed[0]?.title ?? "Tu actividad aparecerá acá"}</p>
                <small>{shelves?.recentlyViewed.length ? "Volver a ver" : "Explorar"}</small>
              </button>
              <button type="button" onClick={() => setAccountMenuOpen(true)}>
                <span className="quick-icon"><img src={officialAssets.registration} alt="" /></span>
                <strong>Ingresá a tu cuenta</strong>
                <p>Consultá compras y publicaciones</p>
                <small>Ver mi cuenta</small>
              </button>
              <button type="button" onClick={() => openCategory("streaming")}>
                <span className="quick-icon quick-icon--recommendation" />
                <strong>Porque te interesa</strong>
                <p>Contenido relacionado con tu actividad</p>
                <small>Ver recomendaciones</small>
              </button>
              <button type="button" onClick={() => openPage("favorites")}>
                <span className="quick-icon quick-icon--favorite">♡</span>
                <strong>Lo querés, lo tenés</strong>
                <p>Guardá publicaciones para después</p>
                <small>Ver favoritos</small>
              </button>
              <button type="button" onClick={() => openPage("help")}>
                <span className="quick-icon"><img src={officialAssets.paymentMethods} alt="" /></span>
                <strong>Medios de pago</strong>
                <p>Pagá tus compras de forma rápida y segura</p>
                <small>Conocer medios de pago</small>
              </button>
            </section>

            <section className="service-strip" aria-label="Servicios de Mercado Live">
              <button type="button" onClick={() => openPage("help")}>
                <WalletIcon />
                <span><strong>Mercado Pago</strong><small>Pagá rápido y seguro</small></span>
              </button>
              <button type="button" onClick={() => openPage("offers")}>
                <TruckIcon />
                <span><strong>Envíos gratis</strong><small>Desde $ 16.000 en productos elegibles</small></span>
              </button>
              <button type="button" onClick={() => openPage("coupons")}>
                <CreditIcon />
                <span><strong>Mercado Crédito</strong><small>Cuotas y beneficios simulados</small></span>
              </button>
              <button type="button" onClick={() => openCategory("streaming")}>
                <ShieldIcon />
                <span><strong>Compra protegida</strong><small>Seguimiento, chat y reputación real</small></span>
              </button>
            </section>

            {shelves?.hasPersonalActivity && shelves.inspiredByHistory.length > 0 ? (
              <section className="home-shelf">
                <div className="home-shelf__heading">
                  <h2>Basado en lo último que viste</h2>
                  <button type="button" onClick={() => submitSearch(resultQuery || "streaming")}>
                    Ver historial
                  </button>
                </div>
                <div className="product-row">
                  {shelves.inspiredByHistory.slice(0, 5).map((listing) => (
                    <ProductCard
                      key={listing.id}
                      listing={listing}
                      seller={state.users.find((user) => user.id === listing.sellerId)}
                      onOpen={openListing}
                      compact
                    />
                  ))}
                </div>
              </section>
            ) : null}

            <section className="home-shelf home-shelf--play">
              <div className="play-band">
                <span className="play-band__mark">mercado play</span>
                <strong>Series, películas y accesos digitales</strong>
                <button type="button" onClick={() => openCategory("streaming")}>Ver todo</button>
              </div>
              <div className="product-row">
                {streamingCatalog.map((listing) => (
                  <ProductCard
                    key={listing.id}
                    listing={listing}
                    seller={state.users.find((user) => user.id === listing.sellerId)}
                    onOpen={openListing}
                    compact
                  />
                ))}
              </div>
            </section>

            {userListings.length > 0 ? (
              <section className="home-shelf">
                <div className="home-shelf__heading">
                  <h2>Publicado recientemente</h2>
                  <button type="button" onClick={() => submitSearch("nuevo")}>Ver más</button>
                </div>
                <div className="product-row">
                  {userListings.slice(0, 5).map((listing) => (
                    <ProductCard
                      key={listing.id}
                      listing={listing}
                      seller={state.users.find((user) => user.id === listing.sellerId)}
                      onOpen={openListing}
                      compact
                    />
                  ))}
                </div>
              </section>
            ) : null}

            <section className="category-shortcuts">
              <h2>Explorá categorías</h2>
              <div>
                {categories.map((category) => (
                  <button key={category.id} type="button" onClick={() => openCategory(category.id)}>
                    <CategoryGlyph categoryId={category.id} />
                    <span>{category.label}</span>
                  </button>
                ))}
              </div>
            </section>
          </div>
        </>
      ) : null}

      {view === "results" ? (
        <section className="results-page">
          <div className="breadcrumb">
            <button type="button" onClick={goHome}>Inicio</button>
            <span>›</span>
            <span>{resultCategory?.label ?? resultQuery}</span>
          </div>

          {resultCategory?.id === "streaming" ? (
            <div className="results-promo results-promo--streaming">
              <span>ENTRETENIMIENTO</span>
              <h1>Todo para ver, escuchar y disfrutar</h1>
              <p>Accesos digitales con entrega online.</p>
            </div>
          ) : null}

          <div className="results-heading">
            <div>
              <h1>{resultQuery || resultCategory?.label || "Publicaciones"}</h1>
              <p>{resultListings.length} {resultListings.length === 1 ? "resultado" : "resultados"}</p>
            </div>
            <label>
              Ordenar por
              <select value={sortMode} onChange={(event) => setSortMode(event.target.value)}>
                {(resultCategory?.sortModes ?? ["Más relevantes", "Menor precio", "Más recientes"]).map(
                  (mode) => <option key={mode}>{mode}</option>,
                )}
              </select>
            </label>
          </div>

          <div className="results-layout">
            <aside className="filters-column">
              {resultCategory ? (
                <>
                  <section>
                    <h2>Categoría</h2>
                    <strong>{resultCategory.label}</strong>
                    <span>{resultListings.length} publicaciones</span>
                  </section>
                  {resultCategory.filters.map((filter) => (
                    <section key={filter.label}>
                      <h2>{filter.label}</h2>
                      {filter.values.map((value) => (
                        <button
                          className={activeFilters[filter.label] === value ? "is-active" : ""}
                          key={value}
                          type="button"
                          onClick={() => toggleFilter(filter.label, value)}
                        >
                          {value}
                        </button>
                      ))}
                    </section>
                  ))}
                </>
              ) : (
                <section>
                  <h2>Categorías</h2>
                  {categories.map((category) => (
                    <button key={category.id} type="button" onClick={() => openCategory(category.id)}>
                      {category.label}
                    </button>
                  ))}
                </section>
              )}
            </aside>

            <div className="results-content">
              {resultListings.length > 0 ? (
                <div className="results-grid">
                  {resultListings.map((listing) => (
                    <ProductCard
                      key={listing.id}
                      listing={listing}
                      seller={state.users.find((user) => user.id === listing.sellerId)}
                      onOpen={openListing}
                    />
                  ))}
                </div>
              ) : (
                <div className="results-empty">
                  <span className="results-empty__icon" />
                  <h2>No hay publicaciones todavía</h2>
                  <p>
                    Esta categoría se completa solamente con artículos publicados por usuarios.
                  </p>
                  <button type="button" onClick={() => setPublishOpen(true)}>
                    Publicar un producto
                  </button>
                </div>
              )}
            </div>
          </div>
        </section>
      ) : null}

      {view === "detail" && selectedListingId && !selectedListing ? (
        <section className="product-page">
          <div className="results-empty">
            <span className="results-empty__icon" />
            <h2>La publicacion ya no esta disponible</h2>
            <p>Puede haber sido eliminada por quien la publico.</p>
            <button type="button" onClick={goHome}>
              Volver al inicio
            </button>
          </div>
        </section>
      ) : null}

      {view === "detail" && selectedListing ? (
        <section className="product-page">
          <div className="breadcrumb">
            <button type="button" onClick={goHome}>Inicio</button>
            <span>›</span>
            <button type="button" onClick={() => openCategory(selectedListing.categoryId)}>
              {selectedCategory?.label}
            </button>
            <span>›</span>
            <span>{selectedListing.title}</span>
          </div>

          <article className="product-main">
            <section className="product-gallery">
              <div className="product-gallery__thumb">
                <ListingVisual visual={selectedListing.visual} />
              </div>
              <ListingVisual
                visual={selectedListing.visual}
                className="product-gallery__hero"
              />
            </section>

            <section className="product-summary">
              <p className="product-summary__condition">
                {selectedListing.condition} | {selectedListing.sold} vendidos
              </p>
              <div className="product-summary__title">
                <h1>{selectedListing.title}</h1>
                <button
                  className={favoriteIds.includes(selectedListing.id) ? "is-active" : ""}
                  type="button"
                  title="Agregar a favoritos"
                  aria-label="Agregar a favoritos"
                  onClick={() =>
                    setFavoriteIds((previous) =>
                      previous.includes(selectedListing.id)
                        ? previous.filter((id) => id !== selectedListing.id)
                        : [...previous, selectedListing.id],
                    )
                  }
                >
                  ♡
                </button>
              </div>
              <button className="rating-link" type="button" onClick={() => document.getElementById("reviews")?.scrollIntoView()}>
                {selectedProductRating.count > 0 ? (
                  <>
                    <span>{selectedProductRating.average.toFixed(1)}</span>
                    <span className="stars">
                      {[1, 2, 3, 4, 5]
                        .map((value) =>
                          value <= Math.round(selectedProductRating.average) ? "★" : "☆",
                        )
                        .join("")}
                    </span>
                    <span>
                      {selectedProductRating.count}{" "}
                      {selectedProductRating.count === 1 ? "opinión" : "opiniones"}
                    </span>
                  </>
                ) : (
                  <span>Sin opiniones todavía</span>
                )}
              </button>
              {selectedListing.oldPrice ? (
                <p className="product-summary__old-price">{formatPrice(selectedListing.oldPrice)}</p>
              ) : null}
              <strong className="product-summary__price">{formatPrice(selectedListing.price)}</strong>
              {selectedListing.price > 0 ? (
                <p className="product-summary__installments">
                  en 6 cuotas de {formatPrice(Math.ceil(selectedListing.price / 6))}
                </p>
              ) : null}
              <button
                className="product-summary__payment-link"
                type="button"
                onClick={() => {
                  setHelpTopic("payments");
                  openPage("help");
                }}
              >
                Ver los medios de pago
              </button>

              <div className="product-summary__features">
                <h2>Lo que tenés que saber de este producto</h2>
                <ul>
                  {Object.entries(selectedListing.meta).map(([key, value]) => (
                    <li key={key}><strong>{key}:</strong> {value}</li>
                  ))}
                  <li>{selectedListing.description}</li>
                </ul>
              </div>
            </section>

            <aside className="buy-box">
              <p className="buy-box__shipping">{selectedListing.shipping}</p>
              <p className="buy-box__destination">Enviar a {activeUser.location}</p>
              <strong>{selectedListing.condition === "Digital" ? "Disponible ahora" : "Stock disponible"}</strong>
              <label>
                Cantidad:
                <select defaultValue="1">
                  <option value="1">1 unidad</option>
                  <option value="2">2 unidades</option>
                </select>
              </label>
              {selectedListing.sellerId === activeUser.id ? (
                <>
                  <button className="buy-box__disabled" type="button" disabled>
                    Esta es tu publicación
                  </button>
                  {selectedListing.source === "user" ? (
                    <button
                      className="buy-box__danger"
                      type="button"
                      onClick={() => {
                        if (actions.deleteListing(selectedListing.id)) {
                          setFavoriteIds((previous) =>
                            previous.filter((id) => id !== selectedListing.id),
                          );
                          setCartIds((previous) =>
                            previous.filter((id) => id !== selectedListing.id),
                          );
                          setSelectedListingId(null);
                          setChatOpen(false);
                          setView("home");
                          window.scrollTo({ top: 0, behavior: "smooth" });
                        }
                      }}
                    >
                      Eliminar publicación
                    </button>
                  ) : null}
                </>
              ) : selectedCategory?.layout === "vehicle" || selectedCategory?.layout === "real-estate" ? (
                <button
                  className="buy-box__primary"
                  type="button"
                  onClick={() => openConversation(selectedListing)}
                >
                  Contactar al vendedor
                </button>
              ) : (
                <>
                  <button
                    className="buy-box__primary"
                    type="button"
                    onClick={() => {
                      actions.buyListing(selectedListing);
                      setView("purchases");
                      window.scrollTo({ top: 0, behavior: "smooth" });
                    }}
                  >
                    Comprar ahora
                  </button>
                  <button
                    className="buy-box__secondary"
                    type="button"
                    onClick={() => addToCart(selectedListing.id)}
                  >
                    Agregar al carrito
                  </button>
                  {!selectedSeller?.isSystem ? (
                    <button
                      className="buy-box__message"
                      type="button"
                      onClick={() => openConversation(selectedListing)}
                    >
                      Preguntar al vendedor
                    </button>
                  ) : null}
                </>
              )}
              <p className="buyer-protection">
                <span>✓</span>
                Compra protegida. Recibí el producto que esperabas o te devolvemos tu dinero.
              </p>
              <p className="seller-line">
                Vendido por <strong>{selectedSeller?.name ?? "Vendedor"}</strong>
                <small>
                  {selectedSellerRating.count > 0
                    ? `${selectedSellerRating.average.toFixed(1)} de reputación · ${selectedSellerRating.count} ${
                        selectedSellerRating.count === 1 ? "calificación" : "calificaciones"
                      }`
                    : "Sin calificaciones todavía"}
                </small>
              </p>
            </aside>
          </article>

          <div className="product-sections">
            <section className="product-section seller-section">
              <h2>Información sobre el vendedor</h2>
              <div className="seller-section__identity">
                <span>{selectedSeller?.avatar ?? "VE"}</span>
                <div>
                  <strong>{selectedSeller?.name ?? "Vendedor"}</strong>
                  <p>{selectedSeller?.location ?? selectedListing.location}</p>
                </div>
              </div>
              <div className="reputation-meter" aria-label="Reputación del vendedor">
                {[1, 2, 3, 4, 5].map((value) => (
                  <span
                    className={
                      value <= Math.round(selectedSellerRating.average) ? "is-active" : ""
                    }
                    key={value}
                  />
                ))}
              </div>
              <div className="seller-metrics">
                <div>
                  <strong>
                    {selectedSellerRating.count > 0
                      ? selectedSellerRating.average.toFixed(1)
                      : "Nueva"}
                  </strong>
                  <span>
                    {selectedSellerRating.count > 0
                      ? `${selectedSellerRating.count} ${
                          selectedSellerRating.count === 1 ? "calificación" : "calificaciones"
                        }`
                      : "sin calificaciones"}
                  </span>
                </div>
                <div><strong>{selectedListing.sold}</strong><span>Ventas</span></div>
                <div>
                  <strong>{selectedSeller?.isSystem ? "Catálogo" : "Mensajes"}</strong>
                  <span>{selectedSeller?.isSystem ? "digital" : "entre personas"}</span>
                </div>
              </div>
            </section>

            <section className="product-section">
              <h2>Descripción</h2>
              <p className="description-copy">{selectedListing.description}</p>
            </section>

            <section className="product-section questions-section">
              <h2>Preguntas y respuestas</h2>
              {selectedSeller?.isSystem ? (
                <p>
                  Esta publicación pertenece al catálogo digital y no tiene un vendedor
                  particular por chat.
                </p>
              ) : selectedListing.sellerId === activeUser.id ? (
                <>
                  <h3>Consultas de compradores</h3>
                  <div>
                    <button type="button" onClick={() => openPage("messages")}>
                      Ver mensajes recibidos
                    </button>
                  </div>
                </>
              ) : (
                <>
                  <h3>¿Qué querés saber?</h3>
                  <div>
                    <button type="button" onClick={() => openConversation(selectedListing)}>
                      ¿Está disponible?
                    </button>
                    <button type="button" onClick={() => openConversation(selectedListing)}>
                      ¿Cómo es la entrega?
                    </button>
                    <button type="button" onClick={() => openConversation(selectedListing)}>
                      Hacer otra pregunta
                    </button>
                  </div>
                  <p>La respuesta llegará desde la cuenta del vendedor.</p>
                </>
              )}
            </section>

            <ReviewSection
              key={selectedListing.id}
              listing={selectedListing}
              seller={selectedSeller}
              onRatingsChanged={actions.refreshRatings}
            />
          </div>

          {relatedListings.length > 0 ? (
            <section className="home-shelf product-related">
              <div className="home-shelf__heading"><h2>Productos relacionados</h2></div>
              <div className="product-row">
                {relatedListings.map((listing) => (
                  <ProductCard
                    key={listing.id}
                    listing={listing}
                    seller={state.users.find((user) => user.id === listing.sellerId)}
                    onOpen={openListing}
                    compact
                  />
                ))}
              </div>
            </section>
          ) : null}
        </section>
      ) : null}

      {view === "offers" ? (
        <section className="special-page">
          <div className="breadcrumb">
            <button type="button" onClick={goHome}>Inicio</button><span>›</span><span>Ofertas</span>
          </div>
          <div className="offers-banner">
            <img src={officialAssets.hero} alt="Ofertas destacadas" />
          </div>
          <div className="special-heading">
            <div>
              <h1>Ofertas</h1>
              <p>Beneficios disponibles para tu cuenta.</p>
            </div>
            <button type="button" onClick={() => openCategory("streaming")}>Ver entretenimiento</button>
          </div>
          {offerListings.length > 0 ? (
            <div className="results-grid special-grid">
              {offerListings.map((listing) => (
                <ProductCard
                  key={listing.id}
                  listing={listing}
                  seller={state.users.find((user) => user.id === listing.sellerId)}
                  onOpen={openListing}
                />
              ))}
            </div>
          ) : (
            <div className="account-empty">
              <h2>No hay ofertas publicadas</h2>
              <p>Las promociones aparecerán acá cuando estén disponibles.</p>
            </div>
          )}
        </section>
      ) : null}

      {view === "coupons" ? (
        <section className="special-page coupons-page">
          <div className="breadcrumb">
            <button type="button" onClick={goHome}>Inicio</button><span>›</span><span>Cupones</span>
          </div>
          <div className="coupons-hero">
            <div>
              <span>BENEFICIOS</span>
              <h1>Cupones</h1>
              <p>Aplicá un código o elegí un beneficio disponible para tu cuenta.</p>
            </div>
            <form
              onSubmit={(event) => {
                event.preventDefault();
                const code = couponCode.trim().toUpperCase();
                if (code) setAppliedCoupon(code);
              }}
            >
              <label htmlFor="coupon-code">Ingresá tu código</label>
              <div>
                <input
                  id="coupon-code"
                  value={couponCode}
                  onChange={(event) => setCouponCode(event.target.value)}
                  placeholder="Ej.: BIENVENIDA10"
                />
                <button type="submit" disabled={!couponCode.trim()}>Aplicar</button>
              </div>
            </form>
          </div>
          {appliedCoupon ? (
            <div className="coupon-confirmation" role="status">
              <span>✓</span>
              <div>
                <strong>Cupón {appliedCoupon} aplicado</strong>
                <p>Vas a ver el descuento antes de confirmar una compra elegible.</p>
              </div>
              <button type="button" onClick={() => setAppliedCoupon(null)}>Quitar</button>
            </div>
          ) : null}
          <div className="special-heading">
            <div>
              <h2>Cupones disponibles</h2>
              <p>Revisá las condiciones de cada beneficio.</p>
            </div>
          </div>
          <div className="coupon-grid">
            {[
              { code: "BIENVENIDA10", amount: "10% OFF", detail: "En tu primera compra", minimum: "Compra mínima $ 5.000" },
              { code: "PLAY15", amount: "15% OFF", detail: "En entretenimiento digital", minimum: "Tope de reintegro $ 3.000" },
              { code: "ENVIO", amount: "ENVÍO GRATIS", detail: "En productos seleccionados", minimum: "Sujeto a cobertura" },
            ].map((coupon) => (
              <article className="coupon-card" key={coupon.code}>
                <div>
                  <span>{coupon.amount}</span>
                  <h3>{coupon.detail}</h3>
                  <p>{coupon.minimum}</p>
                </div>
                <button
                  type="button"
                  onClick={() => {
                    setCouponCode(coupon.code);
                    setAppliedCoupon(coupon.code);
                  }}
                >
                  Aplicar cupón
                </button>
              </article>
            ))}
          </div>
          <button className="text-action" type="button" onClick={() => openCategory("streaming")}>
            Buscar productos elegibles
          </button>
        </section>
      ) : null}

      {view === "favorites" ? (
        <section className="special-page">
          <div className="breadcrumb">
            <button type="button" onClick={goHome}>Inicio</button><span>›</span><span>Favoritos</span>
          </div>
          <div className="special-heading">
            <div>
              <h1>Favoritos</h1>
              <p>{favoriteListings.length} publicaciones guardadas</p>
            </div>
          </div>
          {favoriteListings.length > 0 ? (
            <div className="results-grid special-grid">
              {favoriteListings.map((listing) => (
                <ProductCard
                  key={listing.id}
                  listing={listing}
                  seller={state.users.find((user) => user.id === listing.sellerId)}
                  onOpen={openListing}
                />
              ))}
            </div>
          ) : (
            <div className="account-empty">
              <span className="empty-heart">♡</span>
              <h2>Guardá lo que te gusta</h2>
              <p>Marcá el corazón de una publicación para encontrarla rápidamente.</p>
              <button type="button" onClick={() => openCategory("streaming")}>Explorar publicaciones</button>
            </div>
          )}
        </section>
      ) : null}

      {view === "cart" ? (
        <section className="special-page cart-page">
          <div className="breadcrumb">
            <button type="button" onClick={goHome}>Inicio</button><span>›</span><span>Carrito</span>
          </div>
          <div className="special-heading">
            <div>
              <h1>Carrito</h1>
              <p>{cartListings.length} {cartListings.length === 1 ? "producto" : "productos"}</p>
            </div>
          </div>
          {cartListings.length > 0 ? (
            <div className="cart-layout">
              <div className="cart-list">
                {cartListings.map((listing) => (
                  <article className="cart-item" key={listing.id}>
                    <button type="button" onClick={() => openListing(listing)}>
                      <ListingVisual visual={listing.visual} />
                    </button>
                    <div>
                      <span>{listing.condition}</span>
                      <button type="button" onClick={() => openListing(listing)}>{listing.title}</button>
                      <p>{listing.shipping}</p>
                      <button
                        className="cart-item__remove"
                        type="button"
                        onClick={() => setCartIds((previous) => previous.filter((id) => id !== listing.id))}
                      >
                        Eliminar
                      </button>
                    </div>
                    <strong>{formatPrice(listing.price)}</strong>
                  </article>
                ))}
              </div>
              <aside className="cart-summary">
                <h2>Resumen de compra</h2>
                <p><span>Productos</span><strong>{formatPrice(cartSubtotal)}</strong></p>
                <p><span>Envío</span><strong className="is-free">Gratis</strong></p>
                {appliedCoupon ? <p><span>Cupón {appliedCoupon}</span><strong className="is-free">Aplicado</strong></p> : null}
                <div><span>Total</span><strong>{formatPrice(cartSubtotal)}</strong></div>
                <button type="button" onClick={checkoutCart}>Continuar compra</button>
              </aside>
            </div>
          ) : (
            <div className="account-empty">
              <span className="empty-cart" aria-hidden="true">
                <CartIcon />
              </span>
              <h2>Tu carrito está vacío</h2>
              <p>Agregá productos y vas a poder comprarlos juntos desde acá.</p>
              <button type="button" onClick={() => openCategory("streaming")}>Explorar publicaciones</button>
            </div>
          )}
        </section>
      ) : null}

      {view === "help" ? (
        <section className="special-page help-page">
          <div className="breadcrumb">
            <button type="button" onClick={goHome}>Inicio</button><span>›</span><span>Ayuda</span>
          </div>
          <div className="help-hero">
            <h1>¿Con qué podemos ayudarte?</h1>
            <div className="help-search"><span className="search-mini-icon" /><input placeholder="Buscá en Ayuda" /></div>
          </div>
          <div className="help-layout">
            <nav aria-label="Temas de ayuda">
              {[
                ["buy", "Compras", "Pagos, entregas y devoluciones"],
                ["sell", "Ventas", "Publicaciones, cobros y reputación"],
                ["account", "Tu cuenta", "Datos, seguridad y acceso"],
                ["shipping", "Envíos", "Seguimiento y direcciones"],
                ["payments", "Medios de pago", "Tarjetas, cuotas y promociones"],
              ].map(([id, label, detail]) => (
                <button
                  className={helpTopic === id ? "is-active" : ""}
                  key={id}
                  type="button"
                  onClick={() => setHelpTopic(id)}
                >
                  <span />
                  <div><strong>{label}</strong><small>{detail}</small></div>
                  <b>›</b>
                </button>
              ))}
            </nav>
            <article className="help-detail">
              {helpTopic ? (
                <>
                  <button type="button" onClick={() => setHelpTopic(null)}>‹ Todos los temas</button>
                  <h2>{
                    helpTopic === "buy" ? "Ayuda con tus compras" :
                    helpTopic === "sell" ? "Ayuda con tus ventas" :
                    helpTopic === "account" ? "Seguridad de tu cuenta" :
                    helpTopic === "shipping" ? "Seguimiento de envíos" :
                    "Medios de pago"
                  }</h2>
                  <p>{
                    helpTopic === "sell"
                      ? "Desde Vender podés identificar el artículo, agregar fotos propias, completar sus características y definir las condiciones de venta."
                      : helpTopic === "shipping"
                        ? "Después de comprar, entrá en Mis compras para ver el estado y el recorrido actualizado de tu envío."
                        : helpTopic === "payments"
                          ? "Las alternativas disponibles y las cuotas se muestran antes de confirmar cada compra."
                          : "Elegí una operación para consultar sus detalles y próximos pasos."
                  }</p>
                  <button
                    className="help-detail__action"
                    type="button"
                    onClick={() => helpTopic === "sell" ? setPublishOpen(true) : openPage("purchases")}
                  >
                    {helpTopic === "sell" ? "Ir a Vender desde el menú" : "Ver mis compras"}
                  </button>
                </>
              ) : (
                <>
                  <h2>Elegí un tema</h2>
                  <p>Vas a encontrar respuestas y accesos directos relacionados con tu cuenta.</p>
                </>
              )}
            </article>
          </div>
        </section>
      ) : null}

      {view === "messages" ? (
        <MessagesView
          activeUser={activeUser}
          threads={accountThreads}
          listings={state.listings}
          users={state.users}
          onHome={goHome}
          onOpen={openThread}
        />
      ) : null}

      {view === "purchases" ? (
        <section className="purchases-page">
          <h1>Compras</h1>
          {purchases.length > 0 ? (
            <div className="purchase-list">
              {purchases.map((shipment) => {
                const listing = state.listings.find((candidate) => candidate.id === shipment.listingId);
                if (!listing) return null;
                return (
                  <article className="purchase-item" key={shipment.id}>
                    <div className="purchase-item__heading">
                      <ListingVisual visual={listing.visual} />
                      <div>
                        <span>{listing.condition === "Digital" ? "Entrega digital" : "Envío en curso"}</span>
                        <h2>{listing.title}</h2>
                        <p>{shipment.status}</p>
                      </div>
                      <div className="purchase-item__actions">
                        <button type="button" onClick={() => openListing(listing)}>Ver compra</button>
                        <button type="button" onClick={() => openReviews(listing)}>Opinar</button>
                      </div>
                    </div>
                    {listing.condition === "Digital" ? (
                      <div className="digital-delivery">
                        <span>✓</span>
                        <div><strong>Tu acceso está disponible</strong><p>La confirmación fue enviada al chat de la compra.</p></div>
                      </div>
                    ) : (
                      <ShippingMap shipment={shipment} />
                    )}
                  </article>
                );
              })}
            </div>
          ) : (
            <div className="purchases-empty">
              <PurchasesEmptyIcon />
              <h2>¡Hacé tu primera compra!</h2>
              <p>Aquí podrás ver tus compras y hacer el seguimiento de tus envíos.</p>
              <button type="button" onClick={() => openPage("offers")}>Ver ofertas del día</button>
            </div>
          )}
        </section>
      ) : null}

      {locationModalOpen ? (
        <div className="modal-layer" role="dialog" aria-modal="true" aria-labelledby="location-title">
          <form
            className="modal-card location-modal"
            onSubmit={async (event) => {
              event.preventDefault();
              setLocationSaving(true);
              setLocationError("");
              const result = await actions.updateLocation(locationDraft);
              setLocationSaving(false);
              if (result.ok) {
                setLocationModalOpen(false);
                return;
              }
              setLocationError(result.error);
            }}
          >
            <div className="modal-card__header">
              <div>
                <span>Direccion de entrega</span>
                <h2 id="location-title">Cambiar ubicacion</h2>
              </div>
              <button type="button" aria-label="Cerrar" onClick={() => setLocationModalOpen(false)}>
                x
              </button>
            </div>
            <p className="location-modal__intro">
              Elegi la zona o escribi el numero de casa para calcular compras y envios.
            </p>
            <label>
              Numero o zona
              <input
                autoFocus
                value={locationDraft}
                placeholder="Ej: 7043, 9072 o Vivienda 1202"
                onChange={(event) => setLocationDraft(event.target.value)}
              />
            </label>
            <div className="location-modal__quick" aria-label="Ubicaciones rapidas">
              {["7043", "4055", "9072", "1202"].map((location) => (
                <button
                  key={location}
                  type="button"
                  onClick={() => {
                    setLocationDraft(location);
                    setLocationError("");
                  }}
                >
                  {location}
                </button>
              ))}
            </div>
            {locationError ? <p className="auth-modal__error" role="alert">{locationError}</p> : null}
            <button className="location-modal__submit" type="submit" disabled={locationSaving}>
              {locationSaving ? "Guardando..." : "Guardar ubicacion"}
            </button>
          </form>
        </div>
      ) : null}

      <footer className="site-footer">
        <div>
          <span>Trabajá con nosotros</span>
          <span>Términos y condiciones</span>
          <span>Promociones</span>
          <span>Cómo cuidamos tu privacidad</span>
          <span>Ayuda</span>
        </div>
        <p>Demo privada inspirada en la experiencia de marketplace. No afiliada a Mercado Libre.</p>
      </footer>

      {chatOpen && selectedListing ? (
        <ChatDock
          activeUser={activeUser}
          listing={selectedListing}
          onClose={() => setChatOpen(false)}
          onSend={actions.sendMessage}
          onRead={actions.markThreadRead}
          thread={selectedThread}
          users={state.users}
        />
      ) : null}

      {publishOpen ? (
        <PublishModal onPublish={publishListing} onClose={() => setPublishOpen(false)} />
      ) : null}
    </main>
  );
}

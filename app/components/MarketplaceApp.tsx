"use client";

import { useEffect, useMemo, useState, type CSSProperties } from "react";
import homeReference from "@/IMG/Captura de pantalla 2026-07-24 015510.png";
import categoriesReference from "@/IMG/Captura de pantalla 2026-07-24 015558.png";
import { categories, type AssetKey, type CategoryId, type Listing } from "../data/marketplace";
import {
  getRecommendationShelves,
  inferCategoryFromText,
  matchesCategoryFilter,
  matchesListingQuery,
  sortListingsForCategory,
} from "../lib/recommendations";
import { useMarketplaceStore } from "../lib/useMarketplaceStore";
import { AuthModal } from "./AuthModal";
import { ChatDock } from "./ChatDock";
import { ProductCard } from "./ProductCard";
import { PublishModal } from "./PublishModal";
import { ShippingMap } from "./ShippingMap";

function assetSource(asset: string | { src: string }) {
  return typeof asset === "string" ? asset : asset.src;
}

const assetUrls: Record<AssetKey, string> = {
  home: assetSource(homeReference),
  categories: assetSource(categoriesReference),
};

function money(value: number) {
  if (value === 0) {
    return "Gratis";
  }

  return new Intl.NumberFormat("es-AR", {
    style: "currency",
    currency: "ARS",
    maximumFractionDigits: 0,
  }).format(value);
}

function timeAgo(value: string) {
  const minutes = Math.max(1, Math.round((Date.now() - new Date(value).getTime()) / 60000));
  if (minutes < 60) {
    return `hace ${minutes} min`;
  }

  const hours = Math.round(minutes / 60);
  return `hace ${hours} h`;
}

function categoryIcon(categoryId: CategoryId) {
  const icons: Record<CategoryId, string> = {
    vehiculos: "AU",
    inmuebles: "IN",
    streaming: "MP",
    tecnologia: "TE",
    moda: "MO",
    hogar: "HO",
    herramientas: "HE",
    supermercado: "SU",
  };

  return icons[categoryId];
}

function useSelectedThread(state: ReturnType<typeof useMarketplaceStore>["state"], listing?: Listing) {
  const activeUserId = state.activeUserId;

  return useMemo(() => {
    if (!listing) {
      return undefined;
    }

    return state.chats.find((thread) => {
      const belongsToListing = thread.listingId === listing.id;
      const hasActiveUser = thread.buyerId === activeUserId || thread.sellerId === activeUserId;
      return belongsToListing && hasActiveUser;
    });
  }, [activeUserId, listing, state.chats]);
}

export function MarketplaceApp() {
  const { state, activeUser, actions } = useMarketplaceStore();
  const [query, setQuery] = useState("");
  const [categoryMenuOpen, setCategoryMenuOpen] = useState(false);
  const [activeCategoryId, setActiveCategoryId] = useState<CategoryId>("streaming");
  const [sortMode, setSortMode] = useState("Entrega mas rapida");
  const [activeFilter, setActiveFilter] = useState<string | null>(null);
  const [selectedListingId, setSelectedListingId] = useState<string | null>(null);
  const [chatOpen, setChatOpen] = useState(false);
  const [authOpen, setAuthOpen] = useState(false);
  const [publishOpen, setPublishOpen] = useState(false);

  useEffect(() => {
    const timer = window.setInterval(actions.advanceShipments, 2400);
    return () => window.clearInterval(timer);
  }, [actions.advanceShipments]);

  const selectedListing = useMemo(
    () => state.listings.find((listing) => listing.id === selectedListingId),
    [selectedListingId, state.listings],
  );
  const selectedThread = useSelectedThread(state, selectedListing);
  const selectedShipment = useMemo(
    () => state.shipments.find((shipment) => shipment.listingId === selectedListing?.id),
    [selectedListing?.id, state.shipments],
  );
  const shelves = useMemo(
    () => (activeUser ? getRecommendationShelves(state, activeUser.id) : null),
    [activeUser, state],
  );
  const activeCategory = categories.find((category) => category.id === activeCategoryId) ?? categories[0];
  const liveResults = useMemo(
    () =>
      state.listings
        .filter((listing) => matchesListingQuery(listing, query))
        .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
        .slice(0, 8),
    [query, state.listings],
  );
  const categoryListings = useMemo(
    () =>
      sortListingsForCategory(state.listings, activeCategoryId, sortMode)
        .filter((listing) => matchesCategoryFilter(listing, activeFilter))
        .slice(0, 8),
    [activeCategoryId, activeFilter, sortMode, state.listings],
  );
  const streamingCatalog = useMemo(
    () =>
      sortListingsForCategory(state.listings, "streaming", "Entrega mas rapida").filter(
        (listing) => listing.source === "catalog",
      ),
    [state.listings],
  );
  function openListing(listing: Listing) {
    setSelectedListingId(listing.id);
    actions.recordView(listing.id);
  }

  function submitSearch() {
    const cleanQuery = query.trim();
    if (!cleanQuery) {
      return;
    }

    actions.recordSearch(cleanQuery);
    const inferredCategory = inferCategoryFromText(cleanQuery);
    if (inferredCategory) {
      changeCategory(inferredCategory);
    }
  }

  function changeCategory(categoryId: CategoryId) {
    const next = categories.find((category) => category.id === categoryId) ?? categories[0];
    setActiveCategoryId(categoryId);
    setSortMode(next.sortModes[0]);
    setActiveFilter(null);
    setCategoryMenuOpen(false);
  }

  if (!activeUser) {
    return (
      <main
        className="marketplace-shell auth-shell"
        style={{ "--asset-home": `url("${assetUrls.home}")` } as CSSProperties}
      >
        <header className="topbar topbar--auth">
          <div className="topbar__inner topbar__inner--auth">
            <button className="brand brand--capture" type="button" aria-label="Mercado Libre">
              <span
                className="brand__mark"
                style={{ backgroundImage: `url("${assetUrls.home}")` }}
                aria-hidden="true"
              />
              <span className="brand__text">mercado libre</span>
            </button>
            <div className="topbar__promo">
              <span className="promo-badge">%</span>
              <strong>Ofertas por tiempo limitado</strong>
            </div>
          </div>
        </header>
        <section className="auth-landing">
          <div className="auth-landing__visual" aria-hidden="true" />
          <AuthModal
            users={state.users}
            onLogin={actions.loginAs}
            onRegister={actions.registerUser}
            blocking
          />
        </section>
      </main>
    );
  }

  return (
    <main
      className="marketplace-shell"
      style={{ "--asset-home": `url("${assetUrls.home}")` } as CSSProperties}
    >
      <header className="topbar">
        <div className="topbar__inner">
          <button className="brand brand--capture" type="button" onClick={() => setSelectedListingId(null)}>
            <span
              className="brand__mark"
              style={{ backgroundImage: `url("${assetUrls.home}")` }}
              aria-hidden="true"
            />
            <span className="brand__text">mercado libre</span>
          </button>

          <div className="search-zone">
            <form
              className="search-box"
              onSubmit={(event) => {
                event.preventDefault();
                submitSearch();
              }}
            >
              <input
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                onKeyDown={(event) => {
                  if (event.key === "Enter") {
                    event.preventDefault();
                    submitSearch();
                  }
                }}
                placeholder="Buscar productos, marcas y mas..."
                aria-label="Buscar productos"
              />
              <button type="submit" aria-label="Buscar">
                <span />
              </button>
            </form>

            {query.trim() ? (
              <div className="search-results">
                <div className="search-results__header">
                  <strong>Resultados online</strong>
                  <span>{liveResults.length} publicaciones vivas</span>
                </div>
                {liveResults.length === 0 ? (
                  <p className="search-results__empty">No hay coincidencias todavia.</p>
                ) : (
                  liveResults.map((listing) => {
                    const seller = state.users.find((user) => user.id === listing.sellerId);
                    return (
                      <button
                        key={listing.id}
                        type="button"
                        onClick={() => {
                          actions.recordSearch(query);
                          openListing(listing);
                          setQuery("");
                        }}
                      >
                        <span>{categoryIcon(listing.categoryId)}</span>
                        <div>
                          <strong>{listing.title}</strong>
                          <small>
                            {money(listing.price)} - {seller?.name ?? "Vendedor"} -{" "}
                            {timeAgo(listing.createdAt)}
                          </small>
                        </div>
                      </button>
                    );
                  })
                )}
              </div>
            ) : null}
          </div>

          <div className="topbar__promo">
            <span className="promo-badge">%</span>
            <strong>Ofertas por tiempo limitado</strong>
          </div>
        </div>

        <nav className="nav-row" aria-label="Navegacion principal">
          <button className="location-pill" type="button">
            <span />
            Enviar a <strong>{activeUser?.location ?? "Buenos Aires"}</strong>
          </button>
          <div className="nav-row__links">
            <button type="button" onClick={() => setCategoryMenuOpen((open) => !open)}>
              Categorias
            </button>
            <button type="button">Ofertas</button>
            <button type="button">Cupones</button>
            <button type="button">Supermercado</button>
            <button type="button" onClick={() => changeCategory("moda")}>
              Moda
            </button>
            <button type="button" onClick={() => changeCategory("streaming")}>
              Mercado Play
            </button>
            <button type="button" onClick={() => setPublishOpen(true)}>
              Vender
            </button>
          </div>
          <div className="account-actions">
            <button type="button" onClick={() => setAuthOpen(true)}>
              <span>{activeUser?.avatar ?? "US"}</span>
              {activeUser.name}
            </button>
            <button type="button">Mis compras</button>
            <button type="button">Favoritos</button>
            <button type="button" onClick={actions.logout}>
              Salir
            </button>
          </div>

          {categoryMenuOpen ? (
            <div className="category-menu">
              {categories.map((category) => (
                <button key={category.id} type="button" onClick={() => changeCategory(category.id)}>
                  <span>{category.label}</span>
                  <small>{category.navLabel}</small>
                </button>
              ))}
              <button type="button" onClick={() => setPublishOpen(true)}>
                Publicar servicio o producto
              </button>
            </div>
          ) : null}
        </nav>
      </header>

      <section className="hero">
        <img src={assetUrls.home} alt="Banner promocional tomado de IMG" />
        <div className="hero__overlay">
          <span>Cupones, favoritos y entregas Full</span>
          <h1>Encontra tus favoritos a precios increibles</h1>
          <button type="button" onClick={() => changeCategory("streaming")}>
            Ver recomendaciones
          </button>
        </div>
      </section>

      <section className="quick-access" aria-label="Accesos rapidos">
        {[
          ["Envio gratis", "Beneficio por tu primera compra", "Mostrar productos"],
          ["Visto recientemente", shelves?.recentlyViewed[0]?.title ?? "Todavia no viste nada", "Retomar"],
          ["Porque te interesa", shelves?.inspiredByHistory[0]?.title ?? "Busca para personalizar", "Ver mas"],
          ["Lo queres", shelves?.hasPersonalActivity ? "Ofertas por historial y tags" : "Se activa con tu actividad", "Guardar"],
          ["Mercado Play", "Peliculas, accesos y streaming", "Ver gratis"],
          ["Medios de pago", "Compra rapida, cuotas y proteccion", "Conocer"],
        ].map(([title, body, action], index) => (
          <button className="quick-card" key={title} type="button" onClick={() => changeCategory(index === 4 ? "streaming" : activeCategoryId)}>
            <span className={`quick-card__icon quick-card__icon--${index + 1}`} />
            <strong>{title}</strong>
            <p>{body}</p>
            <small>{action}</small>
          </button>
        ))}
      </section>

      <section className="content-grid">
        <div className="main-column">
          <section className="shelf">
            <div className="section-heading">
              <div>
                <span>Historial inteligente</span>
                <h2>{shelves?.hasPersonalActivity ? "Basado en tu actividad" : "Tu historial empieza vacio"}</h2>
              </div>
              <button type="button" onClick={actions.resetDemo}>
                Reiniciar demo
              </button>
            </div>
            {shelves?.hasPersonalActivity && shelves.inspiredByHistory.length > 0 ? (
              <div className="product-row">
                {shelves.inspiredByHistory.slice(0, 6).map((listing) => (
                    <ProductCard
                      assetUrls={assetUrls}
                      key={listing.id}
                      listing={listing}
                      seller={state.users.find((user) => user.id === listing.sellerId)}
                      onOpen={openListing}
                      compact
                    />
                  ))}
              </div>
            ) : (
              <div className="empty-state">
                <strong>No hay recomendaciones todavia</strong>
                <p>Busca HBO, Disney, tecnologia o cualquier categoria. Desde esa accion esta cuenta empieza a recibir productos similares.</p>
              </div>
            )}
          </section>

          <section className="shelf shelf--play">
            <div className="section-heading">
              <div>
                <span>Catalogo inicial permitido</span>
                <h2>Disney, HBO Max y entretenimiento</h2>
              </div>
              <button type="button" onClick={() => changeCategory("streaming")}>
                Mercado Play
              </button>
            </div>
            <div className="product-row">
              {streamingCatalog.slice(0, 6).map((listing) => (
                <ProductCard
                  assetUrls={assetUrls}
                  key={listing.id}
                  listing={listing}
                  seller={state.users.find((user) => user.id === listing.sellerId)}
                  onOpen={openListing}
                  compact
                />
              ))}
            </div>
          </section>

          <section className="category-showcase" style={{ "--accent": activeCategory.accent } as CSSProperties}>
            <div className="category-showcase__banner" style={{ background: activeCategory.tint }}>
              <div>
                <span>{activeCategory.navLabel}</span>
                <h2>{activeCategory.bannerTitle}</h2>
                <p>{activeCategory.bannerText}</p>
              </div>
              <div className="category-showcase__stats">
                <strong>{categoryListings.length}</strong>
                <span>publicaciones filtradas</span>
              </div>
            </div>

            <div className="category-controls">
              <div className="category-tabs">
                {categories.map((category) => (
                  <button
                    className={category.id === activeCategoryId ? "is-active" : ""}
                    key={category.id}
                    type="button"
                    onClick={() => changeCategory(category.id)}
                  >
                    {category.navLabel}
                  </button>
                ))}
              </div>
              <select value={sortMode} onChange={(event) => setSortMode(event.target.value)} aria-label="Orden">
                {activeCategory.sortModes.map((mode) => (
                  <option key={mode}>{mode}</option>
                ))}
              </select>
            </div>

            <div className="filter-strip">
              <button
                className={!activeFilter ? "is-active" : ""}
                type="button"
                onClick={() => setActiveFilter(null)}
              >
                Todo
              </button>
              {activeCategory.filters.flatMap((filter) =>
                filter.values.map((value) => (
                  <button
                    className={activeFilter === value ? "is-active" : ""}
                    key={`${filter.label}-${value}`}
                    type="button"
                    onClick={() => setActiveFilter((current) => (current === value ? null : value))}
                  >
                    {filter.label}: {value}
                  </button>
                )),
              )}
            </div>

            <div className={`category-layout category-layout--${activeCategory.layout}`}>
              <div className="category-ads">
                {activeCategory.ads.map((ad) => (
                  <article key={ad.title}>
                    <span>{ad.eyebrow}</span>
                    <h3>{ad.title}</h3>
                    <p>{ad.body}</p>
                    <strong>{ad.metric}</strong>
                  </article>
                ))}
              </div>
              {categoryListings.length > 0 ? (
                <div className="category-products">
                  {categoryListings.map((listing) => (
                    <ProductCard
                      assetUrls={assetUrls}
                      key={listing.id}
                      listing={listing}
                      seller={state.users.find((user) => user.id === listing.sellerId)}
                      onOpen={openListing}
                    />
                  ))}
                </div>
              ) : (
                <div className="empty-state empty-state--category">
                  <strong>Todavia no hay publicaciones en {activeCategory.label}</strong>
                  <p>Cuando un usuario publique algo en esta categoria, aparecera aca y tambien en la busqueda global.</p>
                  <button type="button" onClick={() => setPublishOpen(true)}>
                    Publicar primero
                  </button>
                </div>
              )}
            </div>
          </section>
        </div>

        <aside className="side-column">
          <section className="live-panel">
            <div className="section-heading section-heading--compact">
              <div>
                <span>Online</span>
                <h2>Publicaciones en vivo</h2>
              </div>
            </div>
            {state.notifications.length > 0 ? (
              state.notifications.slice(0, 5).map((notification) => (
                <div className="live-event" key={notification.id}>
                  <span />
                  <p>{notification.text}</p>
                  <small>{timeAgo(notification.createdAt)}</small>
                </div>
              ))
            ) : (
              <div className="empty-state empty-state--small">
                <strong>Sin publicaciones nuevas</strong>
                <p>El feed se mueve cuando una cuenta publica o manda mensajes.</p>
              </div>
            )}
          </section>

          <section className="shelf shelf--side">
            <div className="section-heading section-heading--compact">
              <div>
                <span>Cerca tuyo</span>
                <h2>Entrega rapida</h2>
              </div>
            </div>
            <div className="mini-list">
              {shelves?.nearYou.length ? (
                shelves.nearYou.slice(0, 4).map((listing) => (
                  <button key={listing.id} type="button" onClick={() => openListing(listing)}>
                    <strong>{listing.title}</strong>
                    <span>{money(listing.price)}</span>
                  </button>
                ))
              ) : (
                <div className="empty-state empty-state--small">
                  <strong>Sin entregas cercanas</strong>
                  <p>Se activa con publicaciones de usuarios en tu zona.</p>
                </div>
              )}
            </div>
          </section>

          <ShippingMap shipment={selectedShipment} />
        </aside>
      </section>

      {selectedListing ? (
        <aside className="detail-drawer" aria-label="Detalle de publicacion">
          <button
            className="detail-drawer__close"
            type="button"
            onClick={() => {
              setSelectedListingId(null);
              setChatOpen(false);
            }}
            aria-label="Cerrar detalle"
          >
            x
          </button>
          <ProductCard
            assetUrls={assetUrls}
            listing={selectedListing}
            seller={state.users.find((user) => user.id === selectedListing.sellerId)}
            onOpen={() => undefined}
          />
          <div className="detail-drawer__body">
            <span className="detail-drawer__condition">
              {selectedListing.condition} - {selectedListing.sold} vendidos
            </span>
            <h2>{selectedListing.title}</h2>
            <strong>{money(selectedListing.price)}</strong>
            <p>{selectedListing.description}</p>
            <div className="detail-drawer__meta">
              {Object.entries(selectedListing.meta).map(([key, value]) => (
                <span key={key}>
                  {key}: {value}
                </span>
              ))}
            </div>
            <button className="buy-button" type="button">
              Comprar ahora
            </button>
            <button className="secondary-button" type="button" onClick={() => setChatOpen(true)}>
              Chatear con vendedor
            </button>
          </div>
          <ShippingMap shipment={selectedShipment} />
        </aside>
      ) : null}

      {chatOpen && selectedListing && activeUser ? (
        <ChatDock
          activeUser={activeUser}
          listing={selectedListing}
          onClose={() => setChatOpen(false)}
          onSend={actions.sendMessage}
          thread={selectedThread}
          users={state.users}
        />
      ) : null}

      {authOpen ? (
        <AuthModal
          users={state.users}
          onLogin={actions.loginAs}
          onRegister={actions.registerUser}
          onClose={() => setAuthOpen(false)}
        />
      ) : null}

      {publishOpen ? (
        <PublishModal onPublish={actions.publishListing} onClose={() => setPublishOpen(false)} />
      ) : null}
    </main>
  );
}

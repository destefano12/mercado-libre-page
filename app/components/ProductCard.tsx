"use client";

import type { AssetKey, Listing, ProductVisual, UserProfile } from "../data/marketplace";

interface ProductCardProps {
  listing: Listing;
  seller?: UserProfile;
  assetUrls: Record<AssetKey, string>;
  onOpen: (listing: Listing) => void;
  compact?: boolean;
}

function formatPrice(value: number) {
  if (value === 0) {
    return "Gratis";
  }

  return new Intl.NumberFormat("es-AR", {
    style: "currency",
    currency: "ARS",
    maximumFractionDigits: 0,
  }).format(value);
}

function ProductVisualBlock({
  visual,
  assetUrls,
}: {
  visual: ProductVisual;
  assetUrls: Record<AssetKey, string>;
}) {
  if (visual.type === "asset") {
    return (
      <div className="product-visual product-visual--asset">
        <img
          src={assetUrls[visual.asset]}
          alt={visual.label ?? "Producto"}
          style={{ objectPosition: visual.objectPosition }}
        />
      </div>
    );
  }

  return (
    <div className="product-visual product-visual--generated" style={{ background: visual.gradient }}>
      <span>{visual.label}</span>
    </div>
  );
}

export function ProductCard({ listing, seller, assetUrls, onOpen, compact }: ProductCardProps) {
  const discount = listing.oldPrice
    ? Math.round(((listing.oldPrice - listing.price) / listing.oldPrice) * 100)
    : 0;

  return (
    <button
      className={`product-card ${compact ? "product-card--compact" : ""}`}
      type="button"
      onClick={() => onOpen(listing)}
      aria-label={`Abrir publicacion ${listing.title}`}
    >
      <ProductVisualBlock visual={listing.visual} assetUrls={assetUrls} />
      <div className="product-card__body">
        <div className="product-card__title-row">
          {listing.badge ? <span className="product-card__badge">{listing.badge}</span> : null}
          {listing.sponsored ? <span className="product-card__sponsored">Anuncio</span> : null}
        </div>
        <h3>{listing.title}</h3>
        <div className="product-card__price-line">
          <strong>{formatPrice(listing.price)}</strong>
          {discount > 0 ? <span>{discount}% OFF</span> : null}
        </div>
        {listing.oldPrice ? <p className="product-card__old-price">{formatPrice(listing.oldPrice)}</p> : null}
        <p className="product-card__shipping">{listing.shipping}</p>
        <div className="product-card__meta">
          <span>{seller?.name ?? "Vendedor"}</span>
          <span>{listing.location}</span>
        </div>
      </div>
    </button>
  );
}

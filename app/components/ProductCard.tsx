"use client";

import type { Listing, ProductVisual, UserProfile } from "../data/marketplace";

interface ProductCardProps {
  listing: Listing;
  seller?: UserProfile;
  onOpen: (listing: Listing) => void;
  compact?: boolean;
}

export function formatPrice(value: number) {
  if (value === 0) {
    return "Gratis";
  }

  return new Intl.NumberFormat("es-AR", {
    style: "currency",
    currency: "ARS",
    maximumFractionDigits: 0,
  }).format(value);
}

export function ListingVisual({
  visual,
  className = "",
}: {
  visual: ProductVisual;
  className?: string;
}) {
  if (visual.type === "image") {
    return (
      <div className={`product-visual product-visual--image ${className}`}>
        <img
          src={visual.src}
          alt={visual.alt}
          style={{ objectPosition: visual.objectPosition ?? "center" }}
        />
      </div>
    );
  }

  return (
    <div
      className={`product-visual product-visual--generated ${className}`}
      style={{ backgroundColor: visual.gradient }}
    >
      <span>{visual.label}</span>
      <small>Acceso digital</small>
    </div>
  );
}

export function ProductCard({ listing, seller, onOpen, compact }: ProductCardProps) {
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
      <ListingVisual visual={listing.visual} />
      <div className="product-card__body">
        <div className="product-card__title-row">
          {listing.badge ? <span className="product-card__badge">{listing.badge}</span> : null}
          {listing.sponsored ? <span className="product-card__sponsored">Anuncio</span> : null}
        </div>
        <h3>{listing.title}</h3>
        {listing.oldPrice ? <p className="product-card__old-price">{formatPrice(listing.oldPrice)}</p> : null}
        <div className="product-card__price-line">
          <strong>{formatPrice(listing.price)}</strong>
          {discount > 0 ? <span>{discount}% OFF</span> : null}
        </div>
        <p className="product-card__shipping">{listing.shipping}</p>
        <div className="product-card__meta">
          <span>Vendido por {seller?.name ?? "Vendedor"}</span>
        </div>
      </div>
    </button>
  );
}

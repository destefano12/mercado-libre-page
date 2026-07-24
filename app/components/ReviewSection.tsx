"use client";

import { useCallback, useEffect, useState } from "react";
import type { Listing, UserProfile } from "../data/marketplace";

interface ReviewRecord {
  id: string;
  authorName: string;
  authorAvatar: string;
  productRating: number;
  sellerRating: number;
  comment: string;
  createdAt: string;
  updatedAt: string;
  verifiedPurchase: boolean;
}

interface OwnReview {
  id: string;
  productRating: number;
  sellerRating: number;
  comment: string;
}

interface ReviewData {
  product: {
    average: number;
    count: number;
    distribution: number[];
  };
  seller: {
    average: number;
    count: number;
  };
  reviews: ReviewRecord[];
  ownReview: OwnReview | null;
  canReview: boolean;
  reason: "login_required" | "own_listing" | "purchase_required" | null;
}

interface ReviewSectionProps {
  listing: Listing;
  seller?: UserProfile;
  onRatingsChanged: () => void;
}

function reviewDate(value: string) {
  return new Intl.DateTimeFormat("es-AR", {
    day: "numeric",
    month: "long",
    year: "numeric",
  }).format(new Date(value));
}

function StarDisplay({ value, label }: { value: number; label: string }) {
  return (
    <span className="review-stars" aria-label={`${label}: ${value.toFixed(1)} de 5`}>
      {[1, 2, 3, 4, 5].map((star) => (
        <span className={star <= Math.round(value) ? "is-active" : ""} key={star}>
          ★
        </span>
      ))}
    </span>
  );
}

function RatingPicker({
  label,
  value,
  onChange,
}: {
  label: string;
  value: number;
  onChange: (rating: number) => void;
}) {
  return (
    <fieldset className="rating-picker">
      <legend>{label}</legend>
      <div>
        {[1, 2, 3, 4, 5].map((star) => (
          <button
            className={star <= value ? "is-active" : ""}
            key={star}
            type="button"
            aria-label={`${star} ${star === 1 ? "estrella" : "estrellas"}`}
            aria-pressed={star === value}
            title={`${star} de 5`}
            onClick={() => onChange(star)}
          >
            ★
          </button>
        ))}
      </div>
    </fieldset>
  );
}

export function ReviewSection({
  listing,
  seller,
  onRatingsChanged,
}: ReviewSectionProps) {
  const [data, setData] = useState<ReviewData | null>(null);
  const [productRating, setProductRating] = useState(0);
  const [sellerRating, setSellerRating] = useState(0);
  const [comment, setComment] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);

  const loadReviews = useCallback(async () => {
    setData(null);
    setLoading(true);
    setError(null);
    setSaved(false);
    try {
      const response = await fetch(
        `/api/reviews?listingId=${encodeURIComponent(listing.id)}`,
        { cache: "no-store" },
      );
      const result = await response.json() as ReviewData & { error?: string };
      if (!response.ok) {
        setError(result.error ?? "No se pudieron cargar las opiniones");
        return;
      }

      setData(result);
      if (result.ownReview) {
        setProductRating(result.ownReview.productRating);
        setSellerRating(result.ownReview.sellerRating);
        setComment(result.ownReview.comment);
      }
    } catch {
      setError("No se pudieron cargar las opiniones");
    } finally {
      setLoading(false);
    }
  }, [listing.id]);

  useEffect(() => {
    const timer = window.setTimeout(() => void loadReviews(), 0);
    return () => window.clearTimeout(timer);
  }, [loadReviews]);

  const maxDistribution = data?.product.count ?? 0;

  return (
    <section className="product-section reviews-section" id="reviews">
      <h2>Opiniones del producto</h2>

      {loading ? (
        <p className="reviews-empty">Cargando opiniones...</p>
      ) : data ? (
        <>
          <div className="reviews-summary">
            <div>
              {data.product.count > 0 ? (
                <>
                  <strong>{data.product.average.toFixed(1)}</strong>
                  <StarDisplay value={data.product.average} label="Calificación del producto" />
                  <p>
                    {data.product.count} {data.product.count === 1 ? "opinión" : "opiniones"}
                  </p>
                </>
              ) : (
                <>
                  <strong className="reviews-summary__new">Nuevo</strong>
                  <p>Este producto todavía no tiene opiniones.</p>
                </>
              )}
            </div>

            <div className="rating-bars" aria-label="Distribución de calificaciones">
              {[5, 4, 3, 2, 1].map((rating) => {
                const count = data.product.distribution[rating - 1] ?? 0;
                const width = maxDistribution > 0
                  ? Math.round((count / maxDistribution) * 100)
                  : 0;
                return (
                  <span key={rating}>
                    <small>{rating}</small>
                    <i><b style={{ width: `${width}%` }} /></i>
                    <em>{count}</em>
                  </span>
                );
              })}
            </div>
          </div>

          <div className="seller-rating-summary">
            <span>Reputación del vendedor</span>
            {data.seller.count > 0 ? (
              <div>
                <strong>{data.seller.average.toFixed(1)}</strong>
                <StarDisplay value={data.seller.average} label="Reputación del vendedor" />
                <small>
                  {data.seller.count}{" "}
                  {data.seller.count === 1 ? "comprador calificó" : "compradores calificaron"} a{" "}
                  {seller?.name ?? "este vendedor"}
                </small>
              </div>
            ) : (
              <p>El vendedor todavía no recibió calificaciones de compradores.</p>
            )}
          </div>

          {data.canReview ? (
            <form
              className="review-form"
              onSubmit={async (event) => {
                event.preventDefault();
                setError(null);
                setSaved(false);
                if (!productRating || !sellerRating) {
                  setError("Elegí una calificación para el producto y para el vendedor.");
                  return;
                }

                setSaving(true);
                try {
                  const response = await fetch("/api/reviews", {
                    method: "POST",
                    headers: { "content-type": "application/json" },
                    body: JSON.stringify({
                      listingId: listing.id,
                      productRating,
                      sellerRating,
                      comment,
                    }),
                  });
                  const result = await response.json() as ReviewData & { error?: string };
                  if (!response.ok) {
                    setError(result.error ?? "No se pudo guardar la opinión");
                    return;
                  }
                  setData(result);
                  setSaved(true);
                  onRatingsChanged();
                } catch {
                  setError("No se pudo guardar la opinión");
                } finally {
                  setSaving(false);
                }
              }}
            >
              <div className="review-form__heading">
                <div>
                  <span>{data.ownReview ? "Opinión registrada" : "Cuenta registrada"}</span>
                  <h3>{data.ownReview ? "Editá tu opinión" : "Contá tu experiencia"}</h3>
                </div>
                {data.ownReview ? <small>Podés actualizarla cuando quieras</small> : null}
              </div>

              <div className="review-form__ratings">
                <RatingPicker
                  label="Producto"
                  value={productRating}
                  onChange={setProductRating}
                />
                <RatingPicker
                  label="Vendedor"
                  value={sellerRating}
                  onChange={setSellerRating}
                />
              </div>

              <label className="review-form__comment">
                Tu opinión
                <textarea
                  value={comment}
                  onChange={(event) => {
                    setComment(event.target.value);
                    setSaved(false);
                  }}
                  minLength={10}
                  maxLength={1000}
                  placeholder="¿Qué te pareció el producto y la atención del vendedor?"
                  required
                />
                <small>{comment.length}/1000</small>
              </label>

              {error ? <p className="review-form__error" role="alert">{error}</p> : null}
              {saved ? (
                <p className="review-form__saved" role="status">
                  Tu opinión quedó publicada.
                </p>
              ) : null}
              <button type="submit" disabled={saving}>
                {saving
                  ? "Guardando..."
                  : data.ownReview
                    ? "Actualizar opinión"
                    : "Publicar opinión"}
              </button>
            </form>
          ) : (
            <div className="review-eligibility">
              {data.reason === "own_listing"
                ? "No podés calificar tu propia publicación."
                : "Ingresá con tu cuenta para publicar una opinión."}
            </div>
          )}

          {data.reviews.length > 0 ? (
            <div className="review-list">
              <h3>Opiniones de usuarios</h3>
              {data.reviews.map((review) => (
                <article className="review-item" key={review.id}>
                  <div className="review-item__author">
                    <span>{review.authorAvatar}</span>
                    <div>
                      <strong>{review.authorName}</strong>
                      <small>
                        {review.verifiedPurchase ? "Compra verificada" : "Usuario registrado"} · {reviewDate(review.updatedAt)}
                      </small>
                    </div>
                  </div>
                  <StarDisplay value={review.productRating} label="Calificación del producto" />
                  <p>{review.comment}</p>
                  <small>
                    Atención del vendedor: {review.sellerRating} de 5
                  </small>
                </article>
              ))}
            </div>
          ) : null}
        </>
      ) : (
        <p className="reviews-empty">{error ?? "No se pudieron cargar las opiniones."}</p>
      )}
    </section>
  );
}

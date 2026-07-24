import {
  authenticateRequest,
  getDatabase,
  type AuthenticatedProfile,
  type MarketplaceDatabase,
} from "../../lib/server/auth";
import { createInitialMarketplaceState } from "../../data/marketplace";

interface MarketplaceListing {
  id: string;
  sellerId: string;
  title: string;
}

interface MarketplaceShipment {
  listingId: string;
  buyerId: string;
}

interface MarketplaceSnapshot {
  listings?: MarketplaceListing[];
  shipments?: MarketplaceShipment[];
}

interface ReviewRow {
  id: string;
  listing_id: string;
  seller_id: string;
  author_id: string;
  product_rating: number;
  seller_rating: number;
  comment: string;
  created_at: string;
  updated_at: string;
  author_name: string | null;
  author_avatar: string | null;
  verified_purchase: number | null;
}

interface AggregateRow {
  average: number | null;
  count: number;
}

interface GroupedAggregateRow extends AggregateRow {
  target_id: string;
}

interface DistributionRow {
  rating: number;
  count: number;
}

const noStoreHeaders = { "cache-control": "no-store" };

function json(data: unknown, status = 200) {
  return Response.json(data, { status, headers: noStoreHeaders });
}

async function ensureReviewTables(database: MarketplaceDatabase) {
  await database.batch([
    database.prepare(
      `CREATE TABLE IF NOT EXISTS marketplace_reviews (
        id TEXT PRIMARY KEY NOT NULL,
        listing_id TEXT NOT NULL,
        seller_id TEXT NOT NULL,
        author_id TEXT NOT NULL,
        product_rating INTEGER NOT NULL,
        seller_rating INTEGER NOT NULL,
        comment TEXT NOT NULL,
        verified_purchase INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(listing_id, author_id)
      )`,
    ),
    database.prepare(
      "CREATE INDEX IF NOT EXISTS marketplace_reviews_listing_idx ON marketplace_reviews(listing_id, updated_at)",
    ),
    database.prepare(
      "CREATE INDEX IF NOT EXISTS marketplace_reviews_seller_idx ON marketplace_reviews(seller_id, updated_at)",
    ),
    database.prepare(
      `CREATE TABLE IF NOT EXISTS marketplace_realtime (
        id TEXT PRIMARY KEY NOT NULL,
        payload TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )`,
    ),
  ]);
  try {
    await database.prepare(
      "ALTER TABLE marketplace_reviews ADD COLUMN verified_purchase INTEGER NOT NULL DEFAULT 0",
    ).run();
  } catch {
    // Existing databases already have the column.
  }
}

async function marketplaceSnapshot(database: MarketplaceDatabase) {
  const initial = createInitialMarketplaceState();
  const row = await database.prepare(
    "SELECT payload FROM marketplace_realtime WHERE id = ?",
  )
    .bind("marketplace")
    .first<{ payload: string }>();
  if (!row) {
    return {
      listings: initial.listings,
      shipments: initial.shipments,
    };
  }

  try {
    const payload = JSON.parse(row.payload) as MarketplaceSnapshot;
    const payloadListings = Array.isArray(payload.listings) ? payload.listings : [];
    const catalogIds = new Set(payloadListings.map((listing) => listing.id));
    return {
      ...payload,
      listings: [
        ...initial.listings.filter((listing) => !catalogIds.has(listing.id)),
        ...payloadListings,
      ],
      shipments: Array.isArray(payload.shipments) ? payload.shipments : initial.shipments,
    };
  } catch {
    return {
      listings: initial.listings,
      shipments: initial.shipments,
    };
  }
}

function listingContext(snapshot: MarketplaceSnapshot | null, listingId: string) {
  const listing = snapshot?.listings?.find((candidate) => candidate.id === listingId);
  if (!listing?.sellerId) {
    return null;
  }
  return {
    listing,
    shipments: Array.isArray(snapshot?.shipments) ? snapshot.shipments : [],
  };
}

function ratingSummary(row: AggregateRow | null) {
  return {
    average: row?.count ? Number(Number(row.average ?? 0).toFixed(1)) : 0,
    count: Number(row?.count ?? 0),
  };
}

async function aggregateFor(
  database: MarketplaceDatabase,
  column: "listing_id" | "seller_id",
  ratingColumn: "product_rating" | "seller_rating",
  value: string,
) {
  return database.prepare(
    `SELECT AVG(${ratingColumn}) AS average, COUNT(*) AS count
     FROM marketplace_reviews
     WHERE ${column} = ?`,
  )
    .bind(value)
    .first<AggregateRow>();
}

async function reviewDetails(
  database: MarketplaceDatabase,
  user: AuthenticatedProfile | null,
  listingId: string,
  context: NonNullable<ReturnType<typeof listingContext>>,
) {
  const reviewsResult = await database.prepare(
    `SELECT r.id, r.listing_id, r.seller_id, r.author_id,
            r.product_rating, r.seller_rating, r.comment,
            r.verified_purchase,
            r.created_at, r.updated_at,
            a.name AS author_name, a.avatar AS author_avatar
     FROM marketplace_reviews r
     LEFT JOIN marketplace_accounts a ON a.id = r.author_id
     WHERE r.listing_id = ?
     ORDER BY r.updated_at DESC`,
  )
    .bind(listingId)
    .all<ReviewRow>();
  const rows = reviewsResult.results ?? [];

  const productAggregate = await aggregateFor(
    database,
    "listing_id",
    "product_rating",
    listingId,
  );
  const sellerAggregate = await aggregateFor(
    database,
    "seller_id",
    "seller_rating",
    context.listing.sellerId,
  );
  const distributionResult = await database.prepare(
    `SELECT product_rating AS rating, COUNT(*) AS count
     FROM marketplace_reviews
     WHERE listing_id = ?
     GROUP BY product_rating`,
  )
    .bind(listingId)
    .all<DistributionRow>();
  const distribution = [0, 0, 0, 0, 0];
  for (const row of distributionResult.results ?? []) {
    if (row.rating >= 1 && row.rating <= 5) {
      distribution[row.rating - 1] = Number(row.count);
    }
  }

  const ownReview = user
    ? rows.find((review) => review.author_id === user.id)
    : undefined;
  const ownListing = user?.id === context.listing.sellerId;
  const reason = !user
    ? "login_required"
    : ownListing
      ? "own_listing"
      : null;

  return {
    product: {
      ...ratingSummary(productAggregate),
      distribution,
    },
    seller: ratingSummary(sellerAggregate),
    reviews: rows.map((review) => ({
      id: review.id,
      authorName: review.author_name ?? "Usuario",
      authorAvatar: review.author_avatar ?? "US",
      productRating: review.product_rating,
      sellerRating: review.seller_rating,
      comment: review.comment,
      createdAt: review.created_at,
      updatedAt: review.updated_at,
      verifiedPurchase: Boolean(review.verified_purchase),
    })),
    ownReview: ownReview
      ? {
          id: ownReview.id,
          productRating: ownReview.product_rating,
          sellerRating: ownReview.seller_rating,
          comment: ownReview.comment,
        }
      : null,
    canReview: Boolean(user && !ownListing),
    reason,
  };
}

export async function GET(request: Request) {
  try {
    const database = await getDatabase();
    await ensureReviewTables(database);
    const url = new URL(request.url);

    if (url.searchParams.get("summary") === "1") {
      const listingResult = await database.prepare(
        `SELECT listing_id AS target_id, AVG(product_rating) AS average, COUNT(*) AS count
         FROM marketplace_reviews
         GROUP BY listing_id`,
      ).all<GroupedAggregateRow>();
      const sellerResult = await database.prepare(
        `SELECT seller_id AS target_id, AVG(seller_rating) AS average, COUNT(*) AS count
         FROM marketplace_reviews
         GROUP BY seller_id`,
      ).all<GroupedAggregateRow>();

      return json({
        listings: Object.fromEntries(
          (listingResult.results ?? []).map((row) => [
            row.target_id,
            ratingSummary(row),
          ]),
        ),
        sellers: Object.fromEntries(
          (sellerResult.results ?? []).map((row) => [
            row.target_id,
            ratingSummary(row),
          ]),
        ),
      });
    }

    const listingId = url.searchParams.get("listingId")?.trim();
    if (!listingId) {
      return json({ error: "Falta la publicación" }, 400);
    }

    const snapshot = await marketplaceSnapshot(database);
    const context = listingContext(snapshot, listingId);
    if (!context) {
      return json({ error: "La publicación no está disponible" }, 404);
    }

    const user = await authenticateRequest(request, database);
    return json(await reviewDetails(database, user, listingId, context));
  } catch {
    return json({ error: "No se pudieron cargar las opiniones" }, 503);
  }
}

export async function POST(request: Request) {
  let input: {
    listingId?: string;
    productRating?: number;
    sellerRating?: number;
    comment?: string;
  };
  try {
    input = await request.json() as typeof input;
  } catch {
    return json({ error: "Solicitud inválida" }, 400);
  }

  const listingId = input.listingId?.trim() ?? "";
  const comment = input.comment?.trim() ?? "";
  const productRating = Number(input.productRating);
  const sellerRating = Number(input.sellerRating);
  if (
    !listingId ||
    !Number.isInteger(productRating) ||
    productRating < 1 ||
    productRating > 5 ||
    !Number.isInteger(sellerRating) ||
    sellerRating < 1 ||
    sellerRating > 5 ||
    comment.length < 10 ||
    comment.length > 1000
  ) {
    return json(
      { error: "Completá ambas calificaciones y una opinión de 10 a 1000 caracteres" },
      400,
    );
  }

  try {
    const database = await getDatabase();
    const user = await authenticateRequest(request, database);
    if (!user) {
      return json({ error: "Tu sesión venció. Volvé a ingresar" }, 401);
    }
    await ensureReviewTables(database);

    const snapshot = await marketplaceSnapshot(database);
    const context = listingContext(snapshot, listingId);
    if (!context) {
      return json({ error: "La publicación no está disponible" }, 404);
    }
    if (context.listing.sellerId === user.id) {
      return json({ error: "No podés calificar tu propia publicación" }, 403);
    }
    const purchased = context.shipments.some(
      (shipment) =>
        shipment.listingId === listingId && shipment.buyerId === user.id,
    );
    const existing = await database.prepare(
      "SELECT id, created_at FROM marketplace_reviews WHERE listing_id = ? AND author_id = ?",
    )
      .bind(listingId, user.id)
      .first<{ id: string; created_at: string }>();
    const now = new Date().toISOString();
    await database.prepare(
      `INSERT INTO marketplace_reviews (
        id, listing_id, seller_id, author_id, product_rating,
        seller_rating, comment, verified_purchase, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(listing_id, author_id) DO UPDATE SET
        product_rating = excluded.product_rating,
        seller_rating = excluded.seller_rating,
        comment = excluded.comment,
        verified_purchase = MAX(marketplace_reviews.verified_purchase, excluded.verified_purchase),
        updated_at = excluded.updated_at`,
    )
      .bind(
        existing?.id ?? `review-${crypto.randomUUID()}`,
        listingId,
        context.listing.sellerId,
        user.id,
        productRating,
        sellerRating,
        comment,
        purchased ? 1 : 0,
        existing?.created_at ?? now,
        now,
      )
      .run();

    await database.prepare(
      `UPDATE marketplace_accounts
       SET reputation = COALESCE((
         SELECT AVG(seller_rating)
         FROM marketplace_reviews
         WHERE seller_id = ?
       ), 0)
       WHERE id = ?`,
    )
      .bind(context.listing.sellerId, context.listing.sellerId)
      .run();

    return json(
      await reviewDetails(database, user, listingId, context),
      existing ? 200 : 201,
    );
  } catch {
    return json({ error: "No se pudo guardar la opinión" }, 503);
  }
}

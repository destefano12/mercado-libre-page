import {
  authenticateRequest,
  getDatabase,
  type AuthenticatedProfile,
  type MarketplaceDatabase,
} from "../../lib/server/auth";

type ApplicationStatus = "pending" | "accepted" | "rejected";
type OrderStatus =
  | "offered"
  | "preparing"
  | "pickup"
  | "active"
  | "delivered"
  | "cancelled";

interface WorkApplicationRow {
  id: string;
  user_id: string;
  user_name: string | null;
  roblox_username: string;
  roblox_user_id: string;
  discord_username: string;
  discord_id: string;
  email: string;
  age: number;
  character_name: string;
  rp_experience: string;
  work_experience: string;
  availability: string;
  desired_work: string;
  additional_info: string;
  status: ApplicationStatus;
  review_note: string | null;
  reviewed_by: string | null;
  created_at: string;
  updated_at: string;
}

interface WorkerRow {
  user_id: string;
  application_id: string;
  status: "accepted";
  available: number;
  started_at: string | null;
  completed_count: number;
  total_rewards: number;
  total_km: number;
  total_minutes: number;
  level: number;
  xp: number;
  created_at: string;
  updated_at: string;
}

interface WorkOrderRow {
  id: string;
  worker_id: string;
  source_shipment_id: string | null;
  listing_id: string | null;
  buyer_id: string | null;
  seller_id: string | null;
  kind: string;
  product: string;
  quantity: number;
  client_name: string;
  address: string;
  house: string;
  distance_km: number;
  reward: number;
  eta_minutes: number;
  difficulty: string;
  status: OrderStatus;
  coordination_note: string | null;
  created_at: string;
  accepted_at: string | null;
  completed_at: string | null;
}

interface MarketplaceListing {
  id: string;
  title: string;
  categoryId: string;
  sellerId: string;
  location: string;
  condition: string;
  source: "catalog" | "user";
}

interface MarketplaceUser {
  id: string;
  name: string;
  location: string;
}

interface MarketplaceShipment {
  id: string;
  listingId: string;
  buyerId: string;
  origin: string;
  destination: string;
  status: string;
  progress: number;
  etaMinutes: number;
  route?: Array<{ label: string; x: number; y: number }>;
  courierId?: string;
  courierRobloxUserId?: string;
  courierRobloxUsername?: string;
}

interface MarketplaceSnapshot {
  listings?: MarketplaceListing[];
  users?: MarketplaceUser[];
  shipments?: MarketplaceShipment[];
}

const noStoreHeaders = { "cache-control": "no-store" };

function json(data: unknown, status = 200) {
  return Response.json(data, { status, headers: noStoreHeaders });
}

async function ensureWorkTables(database: MarketplaceDatabase) {
  await database.batch([
    database.prepare(
      `CREATE TABLE IF NOT EXISTS marketplace_work_applications (
        id TEXT PRIMARY KEY NOT NULL,
        user_id TEXT NOT NULL,
        roblox_username TEXT NOT NULL,
        roblox_user_id TEXT NOT NULL,
        discord_username TEXT NOT NULL,
        discord_id TEXT NOT NULL,
        email TEXT NOT NULL,
        age INTEGER NOT NULL,
        character_name TEXT NOT NULL,
        rp_experience TEXT NOT NULL,
        work_experience TEXT NOT NULL,
        availability TEXT NOT NULL,
        desired_work TEXT NOT NULL,
        additional_info TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'pending',
        terms_accepted INTEGER NOT NULL DEFAULT 1,
        reviewed_by TEXT,
        review_note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )`,
    ),
    database.prepare(
      "CREATE INDEX IF NOT EXISTS marketplace_work_applications_user_idx ON marketplace_work_applications(user_id, status)",
    ),
    database.prepare(
      "CREATE INDEX IF NOT EXISTS marketplace_work_applications_status_idx ON marketplace_work_applications(status, created_at)",
    ),
    database.prepare(
      `CREATE TABLE IF NOT EXISTS marketplace_workers (
        user_id TEXT PRIMARY KEY NOT NULL,
        application_id TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'accepted',
        available INTEGER NOT NULL DEFAULT 0,
        started_at TEXT,
        completed_count INTEGER NOT NULL DEFAULT 0,
        total_rewards INTEGER NOT NULL DEFAULT 0,
        total_km REAL NOT NULL DEFAULT 0,
        total_minutes INTEGER NOT NULL DEFAULT 0,
        level INTEGER NOT NULL DEFAULT 1,
        xp INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )`,
    ),
    database.prepare(
      `CREATE TABLE IF NOT EXISTS marketplace_work_orders (
        id TEXT PRIMARY KEY NOT NULL,
        worker_id TEXT NOT NULL,
        source_shipment_id TEXT,
        listing_id TEXT,
        buyer_id TEXT,
        seller_id TEXT,
        kind TEXT NOT NULL,
        product TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        client_name TEXT NOT NULL,
        address TEXT NOT NULL,
        house TEXT NOT NULL,
        distance_km REAL NOT NULL,
        reward INTEGER NOT NULL,
        eta_minutes INTEGER NOT NULL,
        difficulty TEXT NOT NULL,
        status TEXT NOT NULL,
        coordination_note TEXT,
        created_at TEXT NOT NULL,
        accepted_at TEXT,
        completed_at TEXT
      )`,
    ),
    database.prepare(
      "CREATE INDEX IF NOT EXISTS marketplace_work_orders_worker_idx ON marketplace_work_orders(worker_id, status, created_at)",
    ),
  ]);

  const migrations = [
    "ALTER TABLE marketplace_work_orders ADD COLUMN source_shipment_id TEXT",
    "ALTER TABLE marketplace_work_orders ADD COLUMN listing_id TEXT",
    "ALTER TABLE marketplace_work_orders ADD COLUMN buyer_id TEXT",
    "ALTER TABLE marketplace_work_orders ADD COLUMN seller_id TEXT",
  ];
  for (const migration of migrations) {
    try {
      await database.prepare(migration).run();
    } catch {
      // Existing databases may already have the column.
    }
  }

  await database.prepare(
    "CREATE UNIQUE INDEX IF NOT EXISTS marketplace_work_orders_shipment_idx ON marketplace_work_orders(source_shipment_id)",
  ).run();
}

function normalize(value: unknown, max = 500) {
  return typeof value === "string" ? value.trim().slice(0, max) : "";
}

function numberInRange(value: unknown, min: number, max: number) {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed >= min && parsed <= max ? parsed : null;
}

function validateApplication(input: Record<string, unknown>) {
  const application = {
    robloxUsername: normalize(input.robloxUsername, 40),
    robloxUserId: normalize(input.robloxUserId, 30),
    discordUsername: normalize(input.discordUsername, 60),
    discordId: normalize(input.discordId, 30),
    email: normalize(input.email, 120).toLowerCase(),
    age: numberInRange(input.age, 13, 80),
    characterName: normalize(input.characterName, 60),
    rpExperience: normalize(input.rpExperience, 1200),
    workExperience: normalize(input.workExperience, 1200),
    availability: normalize(input.availability, 300),
    desiredWork: normalize(input.desiredWork, 80),
    additionalInfo: normalize(input.additionalInfo, 1200),
    termsAccepted: input.termsAccepted === true,
  };

  const missing =
    !application.robloxUsername ||
    !/^\d{3,30}$/.test(application.robloxUserId) ||
    !application.discordUsername ||
    !/^\d{3,30}$/.test(application.discordId) ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(application.email) ||
    application.age === null ||
    !application.characterName ||
    application.rpExperience.length < 20 ||
    application.workExperience.length < 10 ||
    !application.availability ||
    !application.desiredWork ||
    !application.termsAccepted;

  return missing
    ? { ok: false as const, error: "Completa todos los datos obligatorios con informacion valida." }
    : { ok: true as const, application: { ...application, age: application.age } };
}

function mapApplication(row: WorkApplicationRow) {
  return {
    id: row.id,
    userId: row.user_id,
    userName: row.user_name ?? "Usuario",
    robloxUsername: row.roblox_username,
    robloxUserId: row.roblox_user_id,
    discordUsername: row.discord_username,
    discordId: row.discord_id,
    email: row.email,
    age: row.age,
    characterName: row.character_name,
    rpExperience: row.rp_experience,
    workExperience: row.work_experience,
    availability: row.availability,
    desiredWork: row.desired_work,
    additionalInfo: row.additional_info,
    status: row.status,
    reviewNote: row.review_note ?? "",
    reviewedBy: row.reviewed_by ?? "",
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function mapWorker(row: WorkerRow | null) {
  if (!row) {
    return null;
  }

  return {
    userId: row.user_id,
    applicationId: row.application_id,
    status: row.status,
    available: Boolean(row.available),
    startedAt: row.started_at,
    completedCount: row.completed_count,
    totalRewards: row.total_rewards,
    totalKm: Number(row.total_km.toFixed(1)),
    totalMinutes: row.total_minutes,
    level: row.level,
    xp: row.xp,
  };
}

function mapOrder(row: WorkOrderRow) {
  return {
    id: row.id,
    workerId: row.worker_id,
    sourceShipmentId: row.source_shipment_id ?? "",
    listingId: row.listing_id ?? "",
    buyerId: row.buyer_id ?? "",
    sellerId: row.seller_id ?? "",
    kind: row.kind,
    product: row.product,
    quantity: row.quantity,
    clientName: row.client_name,
    address: row.address,
    house: row.house,
    distanceKm: Number(row.distance_km.toFixed(1)),
    reward: row.reward,
    etaMinutes: row.eta_minutes,
    difficulty: row.difficulty,
    status: row.status,
    coordinationNote: row.coordination_note ?? "",
    createdAt: row.created_at,
    acceptedAt: row.accepted_at,
    completedAt: row.completed_at,
  };
}

function randomBetween(min: number, max: number) {
  const bytes = crypto.getRandomValues(new Uint32Array(1));
  return min + (bytes[0] % (max - min + 1));
}

async function readMarketplaceSnapshot(database: MarketplaceDatabase) {
  const row = await database.prepare(
    "SELECT payload FROM marketplace_realtime WHERE id = ?",
  )
    .bind("marketplace")
    .first<{ payload: string }>();
  if (!row) {
    return null;
  }

  try {
    return JSON.parse(row.payload) as MarketplaceSnapshot;
  } catch {
    return null;
  }
}

function distanceFor(shipment: MarketplaceShipment) {
  const route = shipment.route ?? [];
  const start = route[1] ?? route[0];
  const end = route[route.length - 1];
  if (!start || !end) {
    return Number((2 + randomBetween(0, 30) / 10).toFixed(1));
  }
  const dx = end.x - start.x;
  const dy = end.y - start.y;
  return Number(Math.max(1.2, Math.hypot(dx, dy) / 7).toFixed(1));
}

function orderKindFor(categoryId: string) {
  if (categoryId === "supermercado") {
    return "supermarket";
  }
  if (categoryId === "vehiculos" || categoryId === "accesorios-vehiculos") {
    return "vehicle";
  }
  return "general";
}

function rewardFor(kind: string, distance: number) {
  const base = kind === "vehicle" ? 2600 : kind === "supermarket" ? 1400 : 1700;
  return base + Math.round(distance * 210);
}

function buildOrderFromShipment(
  workerId: string,
  listing: MarketplaceListing,
  buyer: MarketplaceUser | undefined,
  shipment: MarketplaceShipment,
) {
  const kind = orderKindFor(listing.categoryId);
  const distance = distanceFor(shipment);
  const eta = shipment.etaMinutes > 0
    ? shipment.etaMinutes
    : Math.max(8, Math.round(distance * 5) + 6);

  return {
    id: `work-order-${crypto.randomUUID()}`,
    workerId,
    sourceShipmentId: shipment.id,
    listingId: listing.id,
    buyerId: shipment.buyerId,
    sellerId: listing.sellerId,
    kind,
    product: listing.title,
    quantity: 1,
    clientName: buyer?.name ?? "Comprador",
    address: shipment.destination,
    house: shipment.destination.match(/\d+/)?.[0] ?? shipment.destination,
    distanceKm: distance,
    reward: rewardFor(kind, distance),
    etaMinutes: eta,
    difficulty: kind === "vehicle" ? "Coordinacion" : distance > 5 ? "Media" : "Normal",
    coordinationNote: kind === "vehicle"
      ? "Este pedido viene de una compra real de vehiculos o repuestos y requiere coordinar con comprador y vendedor dentro del roleplay."
      : "",
  };
}

async function findRealPendingShipment(database: MarketplaceDatabase, workerId: string) {
  const snapshot = await readMarketplaceSnapshot(database);
  const shipments = Array.isArray(snapshot?.shipments) ? snapshot.shipments : [];
  const listings = Array.isArray(snapshot?.listings) ? snapshot.listings : [];
  const users = Array.isArray(snapshot?.users) ? snapshot.users : [];

  for (const shipment of shipments) {
    if (
      shipment.destination === "Entrega online" ||
      shipment.progress >= 100 ||
      shipment.status.toLowerCase().includes("entregado")
    ) {
      continue;
    }
    const listing = listings.find((candidate) => candidate.id === shipment.listingId);
    if (!listing || listing.source !== "user" || listing.condition === "Digital") {
      continue;
    }
    if (listing.sellerId === workerId || shipment.buyerId === workerId) {
      continue;
    }
    const assigned = await database.prepare(
      "SELECT id FROM marketplace_work_orders WHERE source_shipment_id = ? LIMIT 1",
    )
      .bind(shipment.id)
      .first<{ id: string }>();
    if (assigned) {
      continue;
    }
    return {
      listing,
      buyer: users.find((candidate) => candidate.id === shipment.buyerId),
      shipment,
    };
  }

  return null;
}

async function updateShipmentStage(
  database: MarketplaceDatabase,
  shipmentId: string | null,
  update: {
    status: string;
    progress: number;
    etaMinutes?: number;
    courierId?: string;
    courierRobloxUserId?: string;
    courierRobloxUsername?: string;
  },
) {
  if (!shipmentId) {
    return;
  }
  const snapshot = await readMarketplaceSnapshot(database);
  if (!snapshot || !Array.isArray(snapshot.shipments)) {
    return;
  }
  const finished = update.progress >= 100 || update.status.toLowerCase().includes("entregado");
  const shipments = finished
    ? snapshot.shipments.filter((shipment) => shipment.id !== shipmentId)
    : snapshot.shipments.map((shipment) =>
        shipment.id === shipmentId
          ? {
              ...shipment,
              status: update.status,
              progress: update.progress,
              etaMinutes: update.etaMinutes ?? shipment.etaMinutes,
              courierId: update.courierId ?? shipment.courierId,
              courierRobloxUserId: update.courierRobloxUserId ?? shipment.courierRobloxUserId,
              courierRobloxUsername: update.courierRobloxUsername ?? shipment.courierRobloxUsername,
            }
          : shipment,
      );
  await database.prepare(
    `INSERT INTO marketplace_realtime (id, payload, updated_at)
     VALUES (?, ?, ?)
     ON CONFLICT(id) DO UPDATE SET payload = excluded.payload, updated_at = excluded.updated_at`,
  )
    .bind(
      "marketplace",
      JSON.stringify({ ...snapshot, shipments }),
      new Date().toISOString(),
    )
    .run();
}

function nextShipmentStage(status: OrderStatus, etaMinutes: number) {
  if (status === "offered") {
    return {
      nextStatus: "preparing" as const,
      shipment: {
        status: "El producto se esta preparando",
        progress: 15,
        etaMinutes: Math.max(etaMinutes, 20),
      },
    };
  }
  if (status === "preparing") {
    return {
      nextStatus: "pickup" as const,
      shipment: {
        status: "El repartidor retiro el producto",
        progress: 35,
        etaMinutes: Math.max(10, Math.round(etaMinutes * 0.75)),
      },
    };
  }
  if (status === "pickup") {
    return {
      nextStatus: "active" as const,
      shipment: {
        status: "El repartidor esta en camino",
        progress: 68,
        etaMinutes: Math.max(4, Math.round(etaMinutes * 0.4)),
      },
    };
  }
  if (status === "active") {
    return {
      nextStatus: "delivered" as const,
      shipment: {
        status: "Entregado",
        progress: 100,
        etaMinutes: 0,
      },
    };
  }
  return null;
}

async function isWorkAdmin(database: MarketplaceDatabase, user: AuthenticatedProfile) {
  const configuredEmails = (globalThis as { process?: { env?: Record<string, string | undefined> } })
    .process?.env?.WORK_ADMIN_EMAILS;
  const allowed = configuredEmails
    ?.split(",")
    .map((email) => email.trim().toLowerCase())
    .filter(Boolean) ?? [];
  if (allowed.includes(user.email.toLowerCase())) {
    return true;
  }
  if (user.email.toLowerCase() === "destebenjamin@gmail.com") {
    return true;
  }

  const first = await database.prepare(
    "SELECT id FROM marketplace_accounts ORDER BY joined_at ASC LIMIT 1",
  ).first<{ id: string }>();
  return first?.id === user.id;
}

async function currentApplication(database: MarketplaceDatabase, userId: string) {
  return database.prepare(
    `SELECT a.*, u.name AS user_name
     FROM marketplace_work_applications a
     LEFT JOIN marketplace_accounts u ON u.id = a.user_id
     WHERE a.user_id = ?
     ORDER BY a.created_at DESC
     LIMIT 1`,
  )
    .bind(userId)
    .first<WorkApplicationRow>();
}

async function currentWorker(database: MarketplaceDatabase, userId: string) {
  return database.prepare(
    `SELECT user_id, application_id, status, available, started_at,
            completed_count, total_rewards, total_km, total_minutes,
            level, xp, created_at, updated_at
     FROM marketplace_workers
     WHERE user_id = ? AND status = 'accepted'`,
  )
    .bind(userId)
    .first<WorkerRow>();
}

async function currentOrders(database: MarketplaceDatabase, userId: string) {
  const result = await database.prepare(
    `SELECT id, worker_id, source_shipment_id, listing_id, buyer_id, seller_id,
            kind, product, quantity, client_name, address, house,
            distance_km, reward, eta_minutes, difficulty, status, coordination_note,
            created_at, accepted_at, completed_at
     FROM marketplace_work_orders
     WHERE worker_id = ? AND source_shipment_id IS NOT NULL
     ORDER BY created_at DESC
     LIMIT 24`,
  )
    .bind(userId)
    .all<WorkOrderRow>();
  return (result.results ?? []).map(mapOrder);
}

async function snapshot(database: MarketplaceDatabase, user: AuthenticatedProfile) {
  await ensureWorkTables(database);
  const [application, worker, orders, admin] = await Promise.all([
    currentApplication(database, user.id),
    currentWorker(database, user.id),
    currentOrders(database, user.id),
    isWorkAdmin(database, user),
  ]);

  let applications: ReturnType<typeof mapApplication>[] = [];
  if (admin) {
    const result = await database.prepare(
      `SELECT a.*, u.name AS user_name
       FROM marketplace_work_applications a
       LEFT JOIN marketplace_accounts u ON u.id = a.user_id
       ORDER BY
         CASE a.status WHEN 'pending' THEN 0 WHEN 'accepted' THEN 1 ELSE 2 END,
         a.created_at DESC
       LIMIT 80`,
    ).all<WorkApplicationRow>();
    applications = (result.results ?? []).map(mapApplication);
  }

  return {
    application: application ? mapApplication(application) : null,
    worker: mapWorker(worker),
    orders,
    isAdmin: admin,
    applications,
  };
}

async function requireWorker(database: MarketplaceDatabase, userId: string) {
  const worker = await currentWorker(database, userId);
  if (!worker) {
    return null;
  }
  return worker;
}

async function ensureOfferedOrder(database: MarketplaceDatabase, workerId: string) {
  const existing = await database.prepare(
    `SELECT id, worker_id, source_shipment_id, listing_id, buyer_id, seller_id,
            kind, product, quantity, client_name, address, house,
            distance_km, reward, eta_minutes, difficulty, status, coordination_note,
            created_at, accepted_at, completed_at
     FROM marketplace_work_orders
     WHERE worker_id = ?
       AND source_shipment_id IS NOT NULL
       AND status IN ('offered', 'preparing', 'pickup', 'active')
     ORDER BY created_at DESC
     LIMIT 1`,
  )
    .bind(workerId)
    .first<WorkOrderRow>();
  if (existing) {
    return existing;
  }

  const source = await findRealPendingShipment(database, workerId);
  if (!source) {
    return null;
  }
  const order = buildOrderFromShipment(
    workerId,
    source.listing,
    source.buyer,
    source.shipment,
  );
  const now = new Date().toISOString();
  await database.prepare(
    `INSERT INTO marketplace_work_orders (
      id, worker_id, source_shipment_id, listing_id, buyer_id, seller_id,
      kind, product, quantity, client_name, address, house,
      distance_km, reward, eta_minutes, difficulty, status, coordination_note,
      created_at, accepted_at, completed_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'offered', ?, ?, NULL, NULL)`,
  )
    .bind(
      order.id,
      workerId,
      order.sourceShipmentId,
      order.listingId,
      order.buyerId,
      order.sellerId,
      order.kind,
      order.product,
      order.quantity,
      order.clientName,
      order.address,
      order.house,
      order.distanceKm,
      order.reward,
      order.etaMinutes,
      order.difficulty,
      order.coordinationNote,
      now,
    )
    .run();

  return database.prepare(
    `SELECT id, worker_id, source_shipment_id, listing_id, buyer_id, seller_id,
            kind, product, quantity, client_name, address, house,
            distance_km, reward, eta_minutes, difficulty, status, coordination_note,
            created_at, accepted_at, completed_at
     FROM marketplace_work_orders
     WHERE id = ?`,
  )
    .bind(order.id)
    .first<WorkOrderRow>();
}

export async function GET(request: Request) {
  try {
    const database = await getDatabase();
    const user = await authenticateRequest(request, database);
    if (!user) {
      return json({ error: "Sesion no valida" }, 401);
    }
    return json(await snapshot(database, user));
  } catch {
    return json({ error: "No se pudo cargar el sistema de trabajo" }, 503);
  }
}

export async function POST(request: Request) {
  let input: Record<string, unknown>;
  try {
    input = await request.json() as Record<string, unknown>;
  } catch {
    return json({ error: "Solicitud invalida" }, 400);
  }

  try {
    const database = await getDatabase();
    const user = await authenticateRequest(request, database);
    if (!user) {
      return json({ error: "Tu sesion vencio. Volve a ingresar" }, 401);
    }
    await ensureWorkTables(database);

    const action = normalize(input.action, 40);

    if (action === "apply") {
      const validation = validateApplication(input);
      if (!validation.ok) {
        return json({ error: validation.error }, 400);
      }
      const existing = await database.prepare(
        "SELECT id, status FROM marketplace_work_applications WHERE user_id = ? AND status IN ('pending', 'accepted') LIMIT 1",
      )
        .bind(user.id)
        .first<{ id: string; status: string }>();
      if (existing) {
        return json({ error: "Ya tenes una solicitud activa para trabajar." }, 409);
      }

      const now = new Date().toISOString();
      await database.prepare(
        `INSERT INTO marketplace_work_applications (
          id, user_id, roblox_username, roblox_user_id, discord_username,
          discord_id, email, age, character_name, rp_experience,
          work_experience, availability, desired_work, additional_info,
          status, terms_accepted, reviewed_by, review_note, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', 1, NULL, NULL, ?, ?)`,
      )
        .bind(
          `work-app-${crypto.randomUUID()}`,
          user.id,
          validation.application.robloxUsername,
          validation.application.robloxUserId,
          validation.application.discordUsername,
          validation.application.discordId,
          validation.application.email,
          validation.application.age,
          validation.application.characterName,
          validation.application.rpExperience,
          validation.application.workExperience,
          validation.application.availability,
          validation.application.desiredWork,
          validation.application.additionalInfo,
          now,
          now,
        )
        .run();
      return json(await snapshot(database, user), 201);
    }

    if (action === "review") {
      if (!(await isWorkAdmin(database, user))) {
        return json({ error: "No tenes permisos para revisar solicitudes" }, 403);
      }
      const applicationId = normalize(input.applicationId, 80);
      const status = normalize(input.status, 20) as ApplicationStatus;
      if (!applicationId || !["accepted", "rejected"].includes(status)) {
        return json({ error: "Revision invalida" }, 400);
      }
      const application = await database.prepare(
        "SELECT user_id FROM marketplace_work_applications WHERE id = ?",
      )
        .bind(applicationId)
        .first<{ user_id: string }>();
      if (!application) {
        return json({ error: "La solicitud no existe" }, 404);
      }

      const now = new Date().toISOString();
      await database.prepare(
        `UPDATE marketplace_work_applications
         SET status = ?, reviewed_by = ?, review_note = ?, updated_at = ?
         WHERE id = ?`,
      )
        .bind(status, user.id, normalize(input.reviewNote, 500), now, applicationId)
        .run();

      if (status === "accepted") {
        await database.prepare(
          `INSERT INTO marketplace_workers (
            user_id, application_id, status, available, started_at,
            completed_count, total_rewards, total_km, total_minutes,
            level, xp, created_at, updated_at
          ) VALUES (?, ?, 'accepted', 0, NULL, 0, 0, 0, 0, 1, 0, ?, ?)
          ON CONFLICT(user_id) DO UPDATE SET
            application_id = excluded.application_id,
            status = 'accepted',
            updated_at = excluded.updated_at`,
        )
          .bind(application.user_id, applicationId, now, now)
          .run();
      }

      return json(await snapshot(database, user));
    }

    const worker = await requireWorker(database, user.id);
    if (!worker) {
      return json({ error: "Tu cuenta todavia no esta aceptada como trabajador" }, 403);
    }

    if (action === "setAvailability") {
      const available = input.available === true;
      const now = new Date().toISOString();
      const extraMinutes = worker.available && worker.started_at
        ? Math.max(0, Math.round((Date.now() - new Date(worker.started_at).getTime()) / 60000))
        : 0;
      await database.prepare(
        `UPDATE marketplace_workers
         SET available = ?, started_at = ?, total_minutes = total_minutes + ?, updated_at = ?
         WHERE user_id = ?`,
      )
        .bind(available ? 1 : 0, available ? now : null, available ? 0 : extraMinutes, now, user.id)
        .run();
      if (available) {
        await ensureOfferedOrder(database, user.id);
      }
      return json(await snapshot(database, user));
    }

    if (action === "generateOrder") {
      if (!worker.available) {
        return json({ error: "Primero activa tu disponibilidad" }, 409);
      }
      await ensureOfferedOrder(database, user.id);
      return json(await snapshot(database, user));
    }

    if (action === "acceptOrder") {
      const orderId = normalize(input.orderId, 90);
      const now = new Date().toISOString();
      const order = await database.prepare(
        `SELECT id, source_shipment_id, status, reward, distance_km, eta_minutes
         FROM marketplace_work_orders
         WHERE id = ?
           AND worker_id = ?
           AND source_shipment_id IS NOT NULL
           AND status IN ('offered', 'preparing', 'pickup', 'active')`,
      )
        .bind(orderId, user.id)
        .first<{
          id: string;
          source_shipment_id: string | null;
          status: OrderStatus;
          reward: number;
          distance_km: number;
          eta_minutes: number;
        }>();
      if (!order) {
        return json({ error: "El pedido ya no esta disponible" }, 409);
      }
      const stage = nextShipmentStage(order.status, order.eta_minutes);
      if (!stage) {
        return json({ error: "El pedido no tiene otra etapa pendiente" }, 409);
      }
      const workerApplication = await database.prepare(
        `SELECT a.roblox_username, a.roblox_user_id
         FROM marketplace_workers w
         JOIN marketplace_work_applications a ON a.id = w.application_id
         WHERE w.user_id = ?
         LIMIT 1`,
      )
        .bind(user.id)
        .first<{ roblox_username: string; roblox_user_id: string }>();

      if (stage.nextStatus === "delivered") {
        const xp = Math.round(order.reward / 120) + Math.round(order.distance_km * 4);
        await database.batch([
          database.prepare(
            `UPDATE marketplace_work_orders
             SET status = 'delivered', completed_at = ?
             WHERE id = ? AND worker_id = ? AND status = 'active'`,
          )
            .bind(now, orderId, user.id),
          database.prepare(
            `UPDATE marketplace_workers
             SET completed_count = completed_count + 1,
                 total_rewards = total_rewards + ?,
                 total_km = total_km + ?,
                 total_minutes = total_minutes + ?,
                 xp = xp + ?,
                 level = MAX(1, CAST(((xp + ?) / 100) AS INTEGER) + 1),
                 updated_at = ?
             WHERE user_id = ?`,
          )
            .bind(order.reward, order.distance_km, order.eta_minutes, xp, xp, now, user.id),
        ]);
      } else {
        await database.prepare(
          `UPDATE marketplace_work_orders
           SET status = ?, accepted_at = COALESCE(accepted_at, ?)
           WHERE id = ? AND worker_id = ? AND status = ?`,
        )
          .bind(stage.nextStatus, now, orderId, user.id, order.status)
          .run();
      }
      await updateShipmentStage(database, order.source_shipment_id, {
        ...stage.shipment,
        courierId: user.id,
        courierRobloxUsername: workerApplication?.roblox_username,
        courierRobloxUserId: workerApplication?.roblox_user_id,
      });
      return json(await snapshot(database, user));
    }

    return json({ error: "Accion no reconocida" }, 400);
  } catch {
    return json({ error: "No se pudo procesar la accion laboral" }, 503);
  }
}

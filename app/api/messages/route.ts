import type { ChatMessage, ChatThread } from "../../data/marketplace";
import {
  authenticateRequest,
  getDatabase,
  type MarketplaceDatabase,
} from "../../lib/server/auth";

interface ThreadRow {
  id: string;
  listing_id: string;
  buyer_id: string;
  seller_id: string;
  last_message_at: string;
}

interface MessageRow {
  id: string;
  thread_id: string;
  sender_id: string;
  body: string;
  created_at: string;
  read_at: string | null;
}

const noStoreHeaders = { "cache-control": "no-store" };

function json(data: unknown, status = 200) {
  return Response.json(data, { status, headers: noStoreHeaders });
}

async function ensureMessageTables(database: MarketplaceDatabase) {
  await database.batch([
    database.prepare(
      `CREATE TABLE IF NOT EXISTS marketplace_chat_threads (
        id TEXT PRIMARY KEY NOT NULL,
        listing_id TEXT NOT NULL,
        buyer_id TEXT NOT NULL,
        seller_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        last_message_at TEXT NOT NULL,
        UNIQUE(listing_id, buyer_id, seller_id)
      )`,
    ),
    database.prepare(
      `CREATE TABLE IF NOT EXISTS marketplace_chat_messages (
        id TEXT PRIMARY KEY NOT NULL,
        thread_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at TEXT NOT NULL,
        read_at TEXT
      )`,
    ),
    database.prepare(
      "CREATE INDEX IF NOT EXISTS marketplace_chat_user_idx ON marketplace_chat_threads(buyer_id, seller_id, last_message_at)",
    ),
    database.prepare(
      "CREATE INDEX IF NOT EXISTS marketplace_chat_message_idx ON marketplace_chat_messages(thread_id, created_at)",
    ),
    database.prepare(
      `CREATE TABLE IF NOT EXISTS marketplace_realtime (
        id TEXT PRIMARY KEY NOT NULL,
        payload TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )`,
    ),
  ]);
}

function mapMessage(row: MessageRow): ChatMessage {
  return {
    id: row.id,
    threadId: row.thread_id,
    senderId: row.sender_id,
    body: row.body,
    createdAt: row.created_at,
    read: Boolean(row.read_at),
  };
}

async function getThreadsForUser(
  database: MarketplaceDatabase,
  userId: string,
): Promise<ChatThread[]> {
  const threadResult = await database.prepare(
    `SELECT id, listing_id, buyer_id, seller_id, last_message_at
     FROM marketplace_chat_threads
     WHERE buyer_id = ? OR seller_id = ?
     ORDER BY last_message_at DESC`,
  )
    .bind(userId, userId)
    .all<ThreadRow>();
  const rows = threadResult.results ?? [];
  if (rows.length === 0) {
    return [];
  }

  const messageResult = await database.prepare(
    `SELECT m.id, m.thread_id, m.sender_id, m.body, m.created_at, m.read_at
     FROM marketplace_chat_messages m
     JOIN marketplace_chat_threads t ON t.id = m.thread_id
     WHERE t.buyer_id = ? OR t.seller_id = ?
     ORDER BY m.created_at ASC`,
  )
    .bind(userId, userId)
    .all<MessageRow>();

  const messagesByThread = new Map<string, ChatMessage[]>();
  for (const messageRow of messageResult.results ?? []) {
    const messages = messagesByThread.get(messageRow.thread_id) ?? [];
    messages.push(mapMessage(messageRow));
    messagesByThread.set(messageRow.thread_id, messages);
  }

  return rows.map((row) => ({
    id: row.id,
    listingId: row.listing_id,
    buyerId: row.buyer_id,
    sellerId: row.seller_id,
    messages: messagesByThread.get(row.id) ?? [],
    lastMessageAt: row.last_message_at,
  }));
}

async function getAuthorizedThread(
  database: MarketplaceDatabase,
  threadId: string,
  userId: string,
) {
  return database.prepare(
    `SELECT id, listing_id, buyer_id, seller_id, last_message_at
     FROM marketplace_chat_threads
     WHERE id = ? AND (buyer_id = ? OR seller_id = ?)`,
  )
    .bind(threadId, userId, userId)
    .first<ThreadRow>();
}

async function listingSeller(database: MarketplaceDatabase, listingId: string) {
  const row = await database.prepare(
    "SELECT payload FROM marketplace_realtime WHERE id = ?",
  )
    .bind("marketplace")
    .first<{ payload: string }>();
  if (!row) {
    return null;
  }

  try {
    const state = JSON.parse(row.payload) as {
      listings?: Array<{ id?: string; sellerId?: string; source?: string }>;
    };
    const listing = state.listings?.find((candidate) => candidate.id === listingId);
    if (!listing?.sellerId || listing.source !== "user") {
      return null;
    }
    return listing.sellerId;
  } catch {
    return null;
  }
}

export async function GET(request: Request) {
  try {
    const database = await getDatabase();
    const user = await authenticateRequest(request, database);
    if (!user) {
      return json({ error: "Sesión no válida" }, 401);
    }

    await ensureMessageTables(database);
    return json({ threads: await getThreadsForUser(database, user.id) });
  } catch {
    return json({ error: "No se pudieron cargar los mensajes" }, 503);
  }
}

export async function POST(request: Request) {
  let input: { listingId?: string; threadId?: string; body?: string };
  try {
    input = await request.json() as typeof input;
  } catch {
    return json({ error: "Solicitud inválida" }, 400);
  }

  const body = input.body?.trim() ?? "";
  if (!input.listingId || body.length === 0 || body.length > 2000) {
    return json({ error: "Escribí un mensaje de hasta 2000 caracteres" }, 400);
  }

  try {
    const database = await getDatabase();
    const user = await authenticateRequest(request, database);
    if (!user) {
      return json({ error: "Tu sesión venció. Volvé a ingresar" }, 401);
    }
    await ensureMessageTables(database);

    let thread: ThreadRow | null = null;
    if (input.threadId) {
      thread = await getAuthorizedThread(database, input.threadId, user.id);
      if (!thread || thread.listing_id !== input.listingId) {
        return json({ error: "No tenés acceso a esta conversación" }, 403);
      }
    } else {
      const sellerId = await listingSeller(database, input.listingId);
      if (!sellerId) {
        return json(
          { error: "Esta publicación no tiene un vendedor particular disponible por chat" },
          400,
        );
      }
      if (sellerId === user.id) {
        return json({ error: "Abrí una consulta existente desde Mensajes" }, 400);
      }

      thread = await database.prepare(
        `SELECT id, listing_id, buyer_id, seller_id, last_message_at
         FROM marketplace_chat_threads
         WHERE listing_id = ? AND buyer_id = ? AND seller_id = ?`,
      )
        .bind(input.listingId, user.id, sellerId)
        .first<ThreadRow>();

      if (!thread) {
        const now = new Date().toISOString();
        const newThread: ThreadRow = {
          id: `chat-${crypto.randomUUID()}`,
          listing_id: input.listingId,
          buyer_id: user.id,
          seller_id: sellerId,
          last_message_at: now,
        };
        await database.prepare(
          `INSERT OR IGNORE INTO marketplace_chat_threads (
            id, listing_id, buyer_id, seller_id, created_at, last_message_at
          ) VALUES (?, ?, ?, ?, ?, ?)`,
        )
          .bind(
            newThread.id,
            newThread.listing_id,
            newThread.buyer_id,
            newThread.seller_id,
            now,
            now,
          )
          .run();
        thread = await database.prepare(
          `SELECT id, listing_id, buyer_id, seller_id, last_message_at
           FROM marketplace_chat_threads
           WHERE listing_id = ? AND buyer_id = ? AND seller_id = ?`,
        )
          .bind(input.listingId, user.id, sellerId)
          .first<ThreadRow>();
      }
    }

    if (!thread) {
      return json({ error: "No se pudo abrir la conversación" }, 409);
    }

    const now = new Date().toISOString();
    await database.batch([
      database.prepare(
        `INSERT INTO marketplace_chat_messages (
          id, thread_id, sender_id, body, created_at, read_at
        ) VALUES (?, ?, ?, ?, ?, NULL)`,
      )
        .bind(`msg-${crypto.randomUUID()}`, thread.id, user.id, body, now),
      database.prepare(
        "UPDATE marketplace_chat_threads SET last_message_at = ? WHERE id = ?",
      )
        .bind(now, thread.id),
    ]);

    const threads = await getThreadsForUser(database, user.id);
    return json({ thread: threads.find((candidate) => candidate.id === thread?.id) });
  } catch {
    return json({ error: "No se pudo enviar el mensaje" }, 503);
  }
}

export async function PATCH(request: Request) {
  let input: { threadId?: string };
  try {
    input = await request.json() as typeof input;
  } catch {
    return json({ error: "Solicitud inválida" }, 400);
  }
  if (!input.threadId) {
    return json({ error: "Falta la conversación" }, 400);
  }

  try {
    const database = await getDatabase();
    const user = await authenticateRequest(request, database);
    if (!user) {
      return json({ error: "Sesión no válida" }, 401);
    }
    await ensureMessageTables(database);
    if (!(await getAuthorizedThread(database, input.threadId, user.id))) {
      return json({ error: "No tenés acceso a esta conversación" }, 403);
    }

    await database.prepare(
      `UPDATE marketplace_chat_messages
       SET read_at = ?
       WHERE thread_id = ? AND sender_id <> ? AND read_at IS NULL`,
    )
      .bind(new Date().toISOString(), input.threadId, user.id)
      .run();
    return json({ ok: true });
  } catch {
    return json({ error: "No se pudo actualizar la conversación" }, 503);
  }
}

const ROW_ID = "marketplace";

async function getDatabase() {
  const { env } = await import("cloudflare:workers");
  return env.DB;
}

function sanitizePublicState(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  const state = value as Record<string, unknown>;
  const users = Array.isArray(state.users)
    ? state.users.map((value) => {
        if (!value || typeof value !== "object" || Array.isArray(value)) {
          return value;
        }
        const profile = { ...(value as Record<string, unknown>) };
        delete profile.email;
        return profile;
      })
    : [];

  return {
    ...state,
    activeUserId: null,
    users,
    chats: [],
  };
}

async function ensureTable(database: Awaited<ReturnType<typeof getDatabase>>) {
  await database.prepare(
    `CREATE TABLE IF NOT EXISTS marketplace_realtime (
      id TEXT PRIMARY KEY NOT NULL,
      payload TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )`,
  ).run();
}

export async function GET() {
  try {
    const database = await getDatabase();
    await ensureTable(database);
    const row = await database.prepare(
      "SELECT payload, updated_at FROM marketplace_realtime WHERE id = ?",
    )
      .bind(ROW_ID)
      .first<{ payload: string; updated_at: string }>();

    return Response.json({
      state: row ? sanitizePublicState(JSON.parse(row.payload)) : null,
      updatedAt: row?.updated_at ?? null,
    });
  } catch {
    return Response.json({ state: null, updatedAt: null });
  }
}

export async function POST(request: Request) {
  try {
    const body = await request.json() as { state?: unknown };
    if (!body.state || typeof body.state !== "object") {
      return Response.json({ ok: false, error: "Estado invalido" }, { status: 400 });
    }

    const updatedAt = new Date().toISOString();
    const publicState = sanitizePublicState(body.state);
    if (!publicState) {
      return Response.json({ ok: false, error: "Estado invalido" }, { status: 400 });
    }
    const payload = JSON.stringify(publicState);

    if (payload.length > 7_500_000) {
      return Response.json(
        { ok: false, error: "Las imagenes superan el limite online" },
        { status: 413 },
      );
    }

    const database = await getDatabase();
    await ensureTable(database);
    await database.prepare(
      `INSERT INTO marketplace_realtime (id, payload, updated_at)
       VALUES (?, ?, ?)
       ON CONFLICT(id) DO UPDATE SET
         payload = excluded.payload,
         updated_at = excluded.updated_at`,
    )
      .bind(ROW_ID, payload, updatedAt)
      .run();

    return Response.json({ ok: true, updatedAt });
  } catch {
    return Response.json({ ok: false, error: "No se pudo sincronizar" }, { status: 500 });
  }
}

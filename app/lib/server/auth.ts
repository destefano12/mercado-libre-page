const SESSION_COOKIE = "mercado_live_session";
const SESSION_MAX_AGE_SECONDS = 60 * 60 * 24 * 30;
const PASSWORD_ITERATIONS = 120_000;
const encoder = new TextEncoder();

export interface AuthenticatedProfile {
  id: string;
  name: string;
  email: string;
  location: string;
  avatar: string;
  reputation: number;
  joinedAt: string;
}

interface AccountRow {
  id: string;
  name: string;
  email: string;
  location: string;
  avatar: string;
  reputation: number;
  joined_at: string;
  password_hash: string;
  password_salt: string;
}

interface SessionAccountRow extends AccountRow {
  expires_at: string;
}

export async function getDatabase() {
  const { env } = await import("cloudflare:workers");
  return env.DB;
}

export type MarketplaceDatabase = Awaited<ReturnType<typeof getDatabase>>;

export async function ensureAuthTables(database: MarketplaceDatabase) {
  await database.batch([
    database.prepare(
      `CREATE TABLE IF NOT EXISTS marketplace_accounts (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        email TEXT NOT NULL COLLATE NOCASE UNIQUE,
        location TEXT NOT NULL,
        avatar TEXT NOT NULL,
        reputation REAL NOT NULL DEFAULT 0,
        joined_at TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        password_salt TEXT NOT NULL
      )`,
    ),
    database.prepare(
      `CREATE TABLE IF NOT EXISTS marketplace_sessions (
        token_hash TEXT PRIMARY KEY NOT NULL,
        user_id TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        created_at TEXT NOT NULL
      )`,
    ),
    database.prepare(
      "CREATE INDEX IF NOT EXISTS marketplace_sessions_user_idx ON marketplace_sessions(user_id)",
    ),
  ]);
}

function toHex(value: ArrayBuffer | Uint8Array) {
  const bytes = value instanceof Uint8Array ? value : new Uint8Array(value);
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function fromHex(value: string) {
  const bytes = new Uint8Array(value.length / 2);
  for (let index = 0; index < bytes.length; index += 1) {
    bytes[index] = Number.parseInt(value.slice(index * 2, index * 2 + 2), 16);
  }
  return bytes;
}

async function sha256(value: string) {
  return toHex(await crypto.subtle.digest("SHA-256", encoder.encode(value)));
}

export async function createPasswordHash(password: string, salt?: string) {
  const saltBytes = salt
    ? fromHex(salt)
    : crypto.getRandomValues(new Uint8Array(16));
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(password),
    "PBKDF2",
    false,
    ["deriveBits"],
  );
  const hash = await crypto.subtle.deriveBits(
    {
      name: "PBKDF2",
      hash: "SHA-256",
      iterations: PASSWORD_ITERATIONS,
      salt: saltBytes,
    },
    key,
    256,
  );

  return { hash: toHex(hash), salt: toHex(saltBytes) };
}

export async function passwordMatches(password: string, row: AccountRow) {
  const candidate = await createPasswordHash(password, row.password_salt);
  if (candidate.hash.length !== row.password_hash.length) {
    return false;
  }

  let difference = 0;
  for (let index = 0; index < candidate.hash.length; index += 1) {
    difference |= candidate.hash.charCodeAt(index) ^ row.password_hash.charCodeAt(index);
  }
  return difference === 0;
}

function readCookie(request: Request, name: string) {
  const cookies = request.headers.get("cookie") ?? "";
  for (const cookie of cookies.split(";")) {
    const [key, ...value] = cookie.trim().split("=");
    if (key === name) {
      return decodeURIComponent(value.join("="));
    }
  }
  return null;
}

function cookieHeader(request: Request, token: string, maxAge: number) {
  const secure = new URL(request.url).protocol === "https:" ? "; Secure" : "";
  return [
    `${SESSION_COOKIE}=${encodeURIComponent(token)}`,
    "Path=/",
    "HttpOnly",
    "SameSite=Lax",
    `Max-Age=${maxAge}`,
  ].join("; ") + secure;
}

function toProfile(row: AccountRow): AuthenticatedProfile {
  return {
    id: row.id,
    name: row.name,
    email: row.email,
    location: row.location,
    avatar: row.avatar,
    reputation: row.reputation,
    joinedAt: row.joined_at,
  };
}

export async function findAccountByEmail(
  database: MarketplaceDatabase,
  email: string,
) {
  return database.prepare(
    `SELECT id, name, email, location, avatar, reputation, joined_at,
            password_hash, password_salt
     FROM marketplace_accounts
     WHERE email = ? COLLATE NOCASE`,
  )
    .bind(email)
    .first<AccountRow>();
}

export async function createSession(
  database: MarketplaceDatabase,
  request: Request,
  userId: string,
) {
  const token = toHex(crypto.getRandomValues(new Uint8Array(32)));
  const tokenHash = await sha256(token);
  const createdAt = new Date();
  const expiresAt = new Date(
    createdAt.getTime() + SESSION_MAX_AGE_SECONDS * 1000,
  ).toISOString();

  await database.prepare(
    `INSERT INTO marketplace_sessions (token_hash, user_id, expires_at, created_at)
     VALUES (?, ?, ?, ?)`,
  )
    .bind(tokenHash, userId, expiresAt, createdAt.toISOString())
    .run();

  return cookieHeader(request, token, SESSION_MAX_AGE_SECONDS);
}

export async function authenticateRequest(
  request: Request,
  database: MarketplaceDatabase,
) {
  await ensureAuthTables(database);
  const token = readCookie(request, SESSION_COOKIE);
  if (!token) {
    return null;
  }

  const tokenHash = await sha256(token);
  const row = await database.prepare(
    `SELECT a.id, a.name, a.email, a.location, a.avatar, a.reputation,
            a.joined_at, a.password_hash, a.password_salt, s.expires_at
     FROM marketplace_sessions s
     JOIN marketplace_accounts a ON a.id = s.user_id
     WHERE s.token_hash = ?`,
  )
    .bind(tokenHash)
    .first<SessionAccountRow>();

  if (!row) {
    return null;
  }

  if (new Date(row.expires_at).getTime() <= Date.now()) {
    await database.prepare(
      "DELETE FROM marketplace_sessions WHERE token_hash = ?",
    )
      .bind(tokenHash)
      .run();
    return null;
  }

  return toProfile(row);
}

export async function revokeSession(
  request: Request,
  database: MarketplaceDatabase,
) {
  const token = readCookie(request, SESSION_COOKIE);
  if (token) {
    await database.prepare(
      "DELETE FROM marketplace_sessions WHERE token_hash = ?",
    )
      .bind(await sha256(token))
      .run();
  }
  return cookieHeader(request, "", 0);
}

export function accountRowToProfile(row: AccountRow) {
  return toProfile(row);
}

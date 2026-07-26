import {
  accountRowToProfile,
  authenticateRequest,
  createPasswordHash,
  createSession,
  ensureAuthTables,
  findAccountByEmail,
  getDatabase,
  passwordMatches,
  revokeCurrentSession,
} from "../../lib/server/auth";

interface AuthInput {
  action?: "login" | "register";
  name?: string;
  email?: string;
  location?: string;
  password?: string;
}

const noStoreHeaders = { "cache-control": "no-store" };

function json(data: unknown, status = 200, headers?: HeadersInit) {
  return Response.json(data, {
    status,
    headers: { ...noStoreHeaders, ...headers },
  });
}

function normalizeEmail(value: string | undefined) {
  return value?.trim().toLowerCase() ?? "";
}

function validEmail(value: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function initialsFor(name: string) {
  return (
    name
      .split(/\s+/)
      .filter(Boolean)
      .map((part) => part[0])
      .join("")
      .slice(0, 2)
      .toUpperCase() || "US"
  );
}

export async function GET(request: Request) {
  try {
    const database = await getDatabase();
    const user = await authenticateRequest(request, database);
    if (!user) {
      return json({ authenticated: false }, 401);
    }
    return json({ authenticated: true, user });
  } catch {
    return json({ authenticated: false, error: "No se pudo validar la sesión" }, 503);
  }
}

export async function POST(request: Request) {
  let input: AuthInput;
  try {
    input = await request.json() as AuthInput;
  } catch {
    return json({ error: "Solicitud inválida" }, 400);
  }

  const email = normalizeEmail(input.email);
  const password = input.password ?? "";
  if (!validEmail(email) || password.length < 8 || password.length > 128) {
    return json(
      { error: "Ingresá un email válido y una contraseña de al menos 8 caracteres" },
      400,
    );
  }

  try {
    const database = await getDatabase();
    await ensureAuthTables(database);

    if (input.action === "login") {
      const account = await findAccountByEmail(database, email);
      if (!account || !(await passwordMatches(password, account))) {
        return json({ error: "El email o la contraseña no son correctos" }, 401);
      }

      const sessionCookie = await createSession(database, request, account.id);
      return json(
        { user: accountRowToProfile(account) },
        200,
        { "set-cookie": sessionCookie },
      );
    }

    if (input.action !== "register") {
      return json({ error: "Acción inválida" }, 400);
    }

    const name = input.name?.trim() ?? "";
    const location = input.location?.trim() ?? "";
    if (name.length < 2 || name.length > 80 || location.length < 2 || location.length > 120) {
      return json({ error: "Completá tu nombre y ubicación" }, 400);
    }

    if (await findAccountByEmail(database, email)) {
      return json({ error: "Ya existe una cuenta con ese email" }, 409);
    }

    const id = `u-${crypto.randomUUID()}`;
    const joinedAt = new Date().toISOString();
    const credentials = await createPasswordHash(password);
    const account = {
      id,
      name,
      email,
      location,
      avatar: initialsFor(name),
      reputation: 0,
      joined_at: joinedAt,
      password_hash: credentials.hash,
      password_salt: credentials.salt,
    };

    try {
      await database.prepare(
        `INSERT INTO marketplace_accounts (
          id, name, email, location, avatar, reputation, joined_at,
          password_hash, password_salt
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
        .bind(
          account.id,
          account.name,
          account.email,
          account.location,
          account.avatar,
          account.reputation,
          account.joined_at,
          account.password_hash,
          account.password_salt,
        )
        .run();
    } catch {
      return json({ error: "Ya existe una cuenta con ese email" }, 409);
    }

    const sessionCookie = await createSession(database, request, id);
    return json(
      { user: accountRowToProfile(account) },
      201,
      { "set-cookie": sessionCookie },
    );
  } catch {
    return json({ error: "No se pudo completar el acceso. Intentá nuevamente" }, 503);
  }
}

export async function DELETE(request: Request) {
  try {
    const database = await getDatabase();
    await ensureAuthTables(database);
    const expiredCookie = await revokeCurrentSession(request, database);
    return json({ ok: true }, 200, { "set-cookie": expiredCookie });
  } catch {
    return json({ ok: true });
  }
}

export async function PATCH(request: Request) {
  let input: AuthInput;
  try {
    input = await request.json() as AuthInput;
  } catch {
    return json({ error: "Solicitud invÃ¡lida" }, 400);
  }

  const location = input.location?.trim() ?? "";
  if (location.length < 2 || location.length > 120) {
    return json({ error: "IngresÃ¡ una ubicaciÃ³n vÃ¡lida" }, 400);
  }

  try {
    const database = await getDatabase();
    await ensureAuthTables(database);
    const user = await authenticateRequest(request, database);
    if (!user) {
      return json({ error: "IniciÃ¡ sesiÃ³n para cambiar tu ubicaciÃ³n" }, 401);
    }

    await database.prepare(
      "UPDATE marketplace_accounts SET location = ? WHERE id = ?",
    )
      .bind(location, user.id)
      .run();

    return json({ user: { ...user, location } });
  } catch {
    return json({ error: "No se pudo actualizar la ubicaciÃ³n" }, 503);
  }
}

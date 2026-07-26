const ERLC_API_BASE = "https://api.erlc.gg";

type RuntimeEnv = {
  ERLC_API_KEY?: string;
};

async function readEnv(): Promise<RuntimeEnv> {
  try {
    const { env } = await import("cloudflare:workers");
    return env as RuntimeEnv;
  } catch {
    return {
      ERLC_API_KEY: globalThis.process?.env?.ERLC_API_KEY,
    };
  }
}

function boolParam(request: Request, key: string) {
  return new URL(request.url).searchParams.get(key) === "true";
}

export async function GET(request: Request) {
  const env = await readEnv();
  const serverKey = env.ERLC_API_KEY?.trim();

  if (!serverKey) {
    return Response.json(
      { ok: false, error: "Falta configurar ERLC_API_KEY en .env.local" },
      { status: 500 },
    );
  }

  const upstreamUrl = new URL("/v2/server", ERLC_API_BASE);
  const includePlayers = boolParam(request, "players");
  const includeVehicles = boolParam(request, "vehicles");
  const includeCalls = boolParam(request, "calls");
  const includeStaff = boolParam(request, "staff");

  if (includePlayers) upstreamUrl.searchParams.set("Players", "true");
  if (includeVehicles) upstreamUrl.searchParams.set("Vehicles", "true");
  if (includeCalls) upstreamUrl.searchParams.set("EmergencyCalls", "true");
  if (includeStaff) upstreamUrl.searchParams.set("Staff", "true");

  try {
    const response = await fetch(upstreamUrl, {
      headers: {
        "server-key": serverKey,
      },
      cache: "no-store",
    });
    const contentType = response.headers.get("content-type") ?? "";
    const payload = contentType.includes("application/json")
      ? await response.json()
      : { message: await response.text() };

    if (!response.ok) {
      return Response.json(
        {
          ok: false,
          status: response.status,
          error: payload?.message ?? payload?.error ?? "No se pudo conectar con ER:LC",
        },
        { status: response.status },
      );
    }

    return Response.json({
      ok: true,
      server: payload,
      fetchedAt: new Date().toISOString(),
    });
  } catch {
    return Response.json(
      { ok: false, error: "No se pudo contactar la API de ER:LC" },
      { status: 502 },
    );
  }
}

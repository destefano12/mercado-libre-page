/**
 * Publica el proyecto en Cloudflare: crea la base D1 si no existe, le pone su
 * identificador de verdad a la configuración que arma la compilación (que sale
 * con uno de relleno) y sube el Worker.
 *
 *   CLOUDFLARE_API_TOKEN=... CLOUDFLARE_ACCOUNT_ID=... node build/publicar.mjs
 *
 * El token se guarda como variable de entorno; nunca va escrito en el código.
 */
import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";

const NOMBRE_BASE = process.env.EM_D1 ?? "estudiar-mejor";
const CONFIGURACION = "dist/server/wrangler.json";

function wrangler(argumentos, { silencioso = false } = {}) {
  return execFileSync("npx", ["wrangler", ...argumentos], {
    encoding: "utf8",
    stdio: silencioso ? ["ignore", "pipe", "pipe"] : ["ignore", "pipe", "inherit"],
  });
}

if (!process.env.CLOUDFLARE_API_TOKEN) {
  console.error(
    [
      "Falta CLOUDFLARE_API_TOKEN.",
      "",
      "Creá un token en el panel de Cloudflare (Mi perfil > API Tokens > Create Token)",
      "con permisos de editar Workers y D1, y guardalo como variable de entorno.",
      "No hace falta escribirlo en ningún archivo del proyecto.",
    ].join("\n"),
  );
  process.exit(1);
}

// 1. La base. Si ya está, se reutiliza; si no, se crea.
console.log(`▸ Buscando la base "${NOMBRE_BASE}"…`);
let identificador = "";
try {
  const lista = JSON.parse(wrangler(["d1", "list", "--json"], { silencioso: true }));
  identificador = lista.find((base) => base.name === NOMBRE_BASE)?.uuid ?? "";
} catch {
  // Una cuenta sin bases todavía no devuelve nada útil: se sigue de largo.
}

if (!identificador) {
  console.log("▸ No estaba: la creo.");
  const creada = wrangler(["d1", "create", NOMBRE_BASE], { silencioso: true });
  identificador = creada.match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/)?.[0] ?? "";
  if (!identificador) {
    console.error("No pude leer el identificador de la base recién creada:\n" + creada);
    process.exit(1);
  }
}
console.log(`▸ Base lista: ${identificador}`);

// 2. Compilar y ponerle a la configuración la base de verdad.
console.log("▸ Compilando…");
execFileSync("npm", ["run", "build"], { stdio: "inherit" });

const configuracion = JSON.parse(readFileSync(CONFIGURACION, "utf8"));
configuracion.d1_databases = [{ binding: "DB", database_name: NOMBRE_BASE, database_id: identificador }];
writeFileSync(CONFIGURACION, JSON.stringify(configuracion, null, 2));
console.log("▸ Configuración apuntada a tu base.");

// 3. Subir.
console.log("▸ Publicando…");
wrangler(["deploy", "--config", CONFIGURACION]);
console.log("\n✔ Listo. La dirección que imprimió Wrangler es la de la página.");
console.log("  Las tablas de los grupos y del chat se crean solas la primera vez que alguien las usa.");

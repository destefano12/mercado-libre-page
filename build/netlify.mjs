/**
 * Compila el proyecto para Netlify.
 *
 *   npm run build:netlify
 *
 * vinext solo compila para Node (lo que necesita Netlify) cuando no encuentra
 * una configuracion de Cloudflare en la raiz; si la ve, exige el plugin de
 * Cloudflare y arma un Worker. Por eso este script aparta `wrangler.jsonc`
 * mientras dura la compilacion y lo devuelve a su lugar pase lo que pase, asi
 * el deploy de Cloudflare sigue intacto.
 */
import { spawnSync } from "node:child_process";
import { existsSync, renameSync } from "node:fs";

const CONFIGURACION = "wrangler.jsonc";
const APARTADA = "wrangler.jsonc.netlify-build";

if (existsSync(APARTADA)) {
  // Quedo de una compilacion que se corto a la mitad: se recupera primero.
  if (!existsSync(CONFIGURACION)) renameSync(APARTADA, CONFIGURACION);
  else throw new Error(`Sobra ${APARTADA}; revisalo y borralo a mano.`);
}

const habiaConfiguracion = existsSync(CONFIGURACION);
if (habiaConfiguracion) renameSync(CONFIGURACION, APARTADA);

let estado = 1;
try {
  const resultado = spawnSync("npx", ["vinext", "build"], {
    stdio: "inherit",
    env: { ...process.env, BUILD_TARGET: "netlify" },
  });
  estado = resultado.status ?? 1;
} finally {
  if (habiaConfiguracion) renameSync(APARTADA, CONFIGURACION);
}

process.exit(estado);

import { resolve } from "node:path";

import vinext from "vinext";
import { defineConfig } from "vite";
import { sites } from "./build/sites-vite-plugin";

const SITE_CREATOR_PLACEHOLDER_DATABASE_ID =
  "00000000-0000-4000-8000-000000000000";

const d1 = "DB";
const r2 = null;

// macOS Seatbelt blocks FSEvents, so Codex previews need polling for HMR.
const isCodexSeatbeltSandbox = process.env.CODEX_SANDBOX === "seatbelt";

// Destino de la compilacion. Por omision Cloudflare, que es donde vive el
// proyecto; `BUILD_TARGET=netlify` compila el mismo codigo para Netlify, que
// no tiene ni Workers ni D1. La unica diferencia es el plugin de Cloudflare
// (que inyecta el runtime workerd) y el modulo `cloudflare:workers`.
const destino = process.env.BUILD_TARGET ?? "cloudflare";
const esNetlify = destino === "netlify";

// Las banderas de compatibilidad viven en wrangler.jsonc, que es la
// configuracion del proyecto. Repetirlas aca hace que el runtime local se
// niegue a arrancar por bandera duplicada.
const localBindingConfig = {
  main: "./worker/index.ts",
  d1_databases: d1
    ? [
        {
          binding: d1,
          database_name: "site-creator-d1",
          database_id: SITE_CREATOR_PLACEHOLDER_DATABASE_ID,
        },
      ]
    : [],
  r2_buckets: r2
    ? [
        {
          binding: r2,
          bucket_name: "site-creator-r2",
        },
      ]
    : [],
};

export default defineConfig(async () => {
  // Keep Wrangler and Miniflare state project-local. These are non-secret tool
  // settings; application environment belongs in ignored `.env*` files.
  process.env.WRANGLER_WRITE_LOGS ??= "false";
  process.env.WRANGLER_LOG_PATH ??= ".wrangler/logs";
  process.env.MINIFLARE_REGISTRY_PATH ??= ".wrangler/registry";

  // Wrangler snapshots its log path while the Cloudflare plugin is imported.
  const { cloudflare } = await import("@cloudflare/vite-plugin");

  return {
    server: isCodexSeatbeltSandbox
      ? { watch: { useFsEvents: false, usePolling: true } }
      : undefined,
    resolve: esNetlify
      ? {
          alias: {
            "cloudflare:workers": resolve(
              import.meta.dirname,
              "build/stubs/cloudflare-workers.ts",
            ),
          },
        }
      : undefined,
    plugins: [
      vinext(),
      sites(),
      ...(esNetlify
        ? []
        : [
            cloudflare({
              viteEnvironment: { name: "rsc", childEnvironments: ["ssr"] },
              config: localBindingConfig,
            }),
          ]),
    ],
  };
});

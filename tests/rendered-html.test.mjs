import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

async function render() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request("http://localhost/", {
      headers: { accept: "text/html" },
    }),
    {
      ASSETS: {
        fetch: async () => new Response("Not found", { status: 404 }),
      },
    },
    {
      waitUntil() {},
      passThroughOnException() {},
    },
  );
}

test("server-renders the Mercado Live marketplace shell", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<title>Mercado Live \| Home<\/title>/i);
  assert.match(html, /mercado/i);
  assert.match(html, /Iniciá sesión o registrate/i);
  assert.match(html, /Todavía no hay cuentas creadas/i);
  assert.match(html, /Crear cuenta y entrar/i);
  assert.doesNotMatch(html, /codex-preview|react-loading-skeleton|Your site is taking shape/i);
});

test("keeps the product implementation wired to local IMG assets", async () => {
  const page = await readFile(new URL("../app/components/MarketplaceApp.tsx", import.meta.url), "utf8");
  const marketplace = await readFile(new URL("../app/data/marketplace.ts", import.meta.url), "utf8");
  const packageJson = await readFile(new URL("../package.json", import.meta.url), "utf8");

  assert.match(page, /@\/IMG\/official\/mercado-libre-logo\.webp/);
  assert.match(page, /@\/IMG\/official\/home-hero\.webp/);
  assert.match(marketplace, /@\/IMG\/official\/hbo-widget\.jpg/);
  assert.match(marketplace, /@\/IMG\/official\/disney-widget\.jpg/);
  assert.doesNotMatch(page, /Captura de pantalla/);
  assert.doesNotMatch(packageJson, /react-loading-skeleton/);
});

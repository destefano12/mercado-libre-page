import assert from "node:assert/strict";
import { readFile, stat } from "node:fs/promises";
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
  assert.match(html, /Ingresá/i);
  assert.match(html, /Crear cuenta/i);
  assert.match(html, /Contraseña/i);
  assert.doesNotMatch(html, /cuentas creadas|elegir una cuenta/i);
  assert.doesNotMatch(html, /codex-preview|react-loading-skeleton|Your site is taking shape/i);
});

test("adds the Mercado Libre RP work application and worker flow", async () => {
  const page = await readFile(
    new URL("../app/components/MarketplaceApp.tsx", import.meta.url),
    "utf8",
  );
  const workRoute = await readFile(
    new URL("../app/api/work/route.ts", import.meta.url),
    "utf8",
  );
  const stylesheet = await readFile(
    new URL("../app/globals.css", import.meta.url),
    "utf8",
  );

  assert.match(page, /\"jobs\"/);
  assert.match(page, /\"work-admin\"/);
  assert.match(page, /submitWorkApplication/);
  assert.match(page, /Panel del trabajador/);
  assert.match(page, /Pedido recibido/);
  assert.match(page, /Panel administrativo/);
  assert.match(page, /Trabaja con nosotros/);
  assert.match(workRoute, /authenticateRequest/);
  assert.match(workRoute, /isWorkAdmin/);
  assert.match(workRoute, /marketplace_work_applications/);
  assert.match(workRoute, /marketplace_workers/);
  assert.match(workRoute, /marketplace_work_orders/);
  assert.match(workRoute, /status IN \('pending', 'accepted'\)/);
  assert.match(workRoute, /reward = template\.base/);
  assert.match(workRoute, /WHERE id = \? AND worker_id = \? AND status = 'offered'/);
  assert.match(stylesheet, /\.work-form/);
  assert.match(stylesheet, /\.work-order-card/);
  assert.match(stylesheet, /\.worker-nav-button/);
});

test("lets users update delivery location and keeps cart icons consistent", async () => {
  const page = await readFile(
    new URL("../app/components/MarketplaceApp.tsx", import.meta.url),
    "utf8",
  );
  const stylesheet = await readFile(
    new URL("../app/globals.css", import.meta.url),
    "utf8",
  );

  assert.match(page, /setLocationModalOpen\(true\)/);
  assert.match(page, /actions\.updateLocation\(locationDraft\)/);
  assert.match(page, /<CartIcon \/>/);
  assert.doesNotMatch(page, /<span className="empty-cart" \/>/);
  assert.match(stylesheet, /\.location-modal/);
  assert.match(stylesheet, /\.empty-cart \.ml-nav-icon/);
});

test("matches official empty favorites and purchases surfaces", async () => {
  const page = await readFile(
    new URL("../app/components/MarketplaceApp.tsx", import.meta.url),
    "utf8",
  );
  const stylesheet = await readFile(
    new URL("../app/globals.css", import.meta.url),
    "utf8",
  );

  assert.match(page, /favoritesMenuOpen/);
  assert.match(page, /favorites-popover/);
  assert.match(page, /Ver todos los favoritos y listas/);
  assert.match(page, /<PurchasesEmptyIcon \/>/);
  assert.match(page, /Hacé tu primera compra/);
  assert.match(page, /Ver ofertas del día/);
  assert.match(stylesheet, /\.favorites-popover/);
  assert.match(stylesheet, /\.purchases-empty__icon/);
  assert.match(stylesheet, /min-height: 690px/);
});

test("includes the expanded official-style category menu", async () => {
  const page = await readFile(
    new URL("../app/components/MarketplaceApp.tsx", import.meta.url),
    "utf8",
  );
  const marketplace = await readFile(
    new URL("../app/data/marketplace.ts", import.meta.url),
    "utf8",
  );
  const publishModal = await readFile(
    new URL("../app/components/PublishModal.tsx", import.meta.url),
    "utf8",
  );
  const recommendations = await readFile(
    new URL("../app/lib/recommendations.ts", import.meta.url),
    "utf8",
  );

  assert.match(page, /categoryMenuOrder/);
  assert.match(page, /\"electrodomesticos\"/);
  assert.match(page, /\"tiendas-oficiales\"/);
  assert.match(marketplace, /label: \"Construccion\"/);
  assert.match(marketplace, /label: \"Belleza y Cuidado Personal\"/);
  assert.match(marketplace, /label: \"Salud y Equipamiento Medico\"/);
  assert.match(publishModal, /Partial<Record<CategoryId/);
  assert.match(recommendations, /return \"mascotas\"/);
});

test("matches the official-style account profile menu", async () => {
  const page = await readFile(
    new URL("../app/components/MarketplaceApp.tsx", import.meta.url),
    "utf8",
  );
  const stylesheet = await readFile(
    new URL("../app/globals.css", import.meta.url),
    "utf8",
  );

  assert.match(page, /account-menu__profile/);
  assert.match(page, /Agregar cuenta/);
  assert.match(page, /meli\+ Viví Mercado Libre como un experto/);
  assert.match(page, /Créditos/);
  assert.match(page, /Suscripciones/);
  assert.match(page, /Mercado Play/);
  assert.match(stylesheet, /\.account-menu__meli/);
  assert.match(stylesheet, /\.account-menu__free/);
});

test("adds official-style services strip and notification center", async () => {
  const page = await readFile(
    new URL("../app/components/MarketplaceApp.tsx", import.meta.url),
    "utf8",
  );
  const stylesheet = await readFile(
    new URL("../app/globals.css", import.meta.url),
    "utf8",
  );

  assert.match(page, /notificationsOpen/);
  assert.match(page, /notifications-popover/);
  assert.match(page, /Generales/);
  assert.match(page, /Tiendas que sigo/);
  assert.match(page, /No tenés notificaciones/);
  assert.match(page, /Aprovechá para descubrir productos increíbles/);
  assert.match(page, /Mercado Pago/);
  assert.match(page, /Mercado Crédito/);
  assert.match(page, /Compra protegida/);
  assert.match(stylesheet, /\.service-strip/);
  assert.match(stylesheet, /\.notifications-popover/);
  assert.match(stylesheet, /\.notifications-popover__tabs button\.is-active/);
  assert.match(stylesheet, /\.notifications-popover__empty/);
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

test("keeps accounts private and routes messages through authenticated APIs", async () => {
  const authModal = await readFile(
    new URL("../app/components/AuthModal.tsx", import.meta.url),
    "utf8",
  );
  const store = await readFile(
    new URL("../app/lib/useMarketplaceStore.ts", import.meta.url),
    "utf8",
  );
  const authRoute = await readFile(
    new URL("../app/api/auth/route.ts", import.meta.url),
    "utf8",
  );
  const serverAuth = await readFile(
    new URL("../app/lib/server/auth.ts", import.meta.url),
    "utf8",
  );

  assert.doesNotMatch(authModal, /users\.map|loginAs/);
  assert.match(authModal, /type="password"/);
  assert.match(store, /fetch\("\/api\/messages"/);
  assert.match(store, /setState\(\(previous\) => \(\{ \.\.\.previous, chats: result\.threads/);
  const page = await readFile(
    new URL("../app/components/MarketplaceApp.tsx", import.meta.url),
    "utf8",
  );
  assert.match(page, /className="notification-button"/);
  assert.match(page, /openPage\("messages"\)/);
  assert.doesNotMatch(store, /setTimeout[\s\S]{0,500}respond/);
  assert.match(authRoute, /passwordMatches/);
  assert.match(authRoute, /export async function PATCH/);
  assert.match(store, /updateLocation/);
  assert.match(serverAuth, /PBKDF2/);
  assert.match(serverAuth, /HttpOnly/);
  assert.match(serverAuth, /ALTER TABLE marketplace_accounts ADD COLUMN password_hash/);
  assert.match(serverAuth, /ALTER TABLE marketplace_accounts ADD COLUMN password_salt/);
});

test("keeps product opinions and seller reputation tied to verified users", async () => {
  const page = await readFile(
    new URL("../app/components/MarketplaceApp.tsx", import.meta.url),
    "utf8",
  );
  const reviewSection = await readFile(
    new URL("../app/components/ReviewSection.tsx", import.meta.url),
    "utf8",
  );
  const reviewRoute = await readFile(
    new URL("../app/api/reviews/route.ts", import.meta.url),
    "utf8",
  );
  const marketplace = await readFile(
    new URL("../app/data/marketplace.ts", import.meta.url),
    "utf8",
  );

  assert.match(page, /<ReviewSection/);
  assert.doesNotMatch(page, /128 opiniones|128 calificaciones/i);
  assert.match(reviewSection, /Compra verificada/);
  assert.match(reviewSection, /Usuario registrado/);
  assert.match(reviewSection, /productRating/);
  assert.match(reviewSection, /sellerRating/);
  assert.match(reviewRoute, /marketplace_reviews/);
  assert.match(reviewRoute, /verified_purchase/);
  assert.match(reviewRoute, /UNIQUE\(listing_id, author_id\)/);
  assert.match(reviewRoute, /context\.listing\.sellerId === user\.id/);
  assert.match(marketplace, /rating: 0/);
});

test("publishes category-specific listings and lets owners remove them", async () => {
  const publishModal = await readFile(
    new URL("../app/components/PublishModal.tsx", import.meta.url),
    "utf8",
  );
  const page = await readFile(
    new URL("../app/components/MarketplaceApp.tsx", import.meta.url),
    "utf8",
  );
  const store = await readFile(
    new URL("../app/lib/useMarketplaceStore.ts", import.meta.url),
    "utf8",
  );

  assert.match(publishModal, /categories\.map\(\(type\)/);
  assert.match(publishModal, /Mesa ratona de madera/);
  assert.match(publishModal, /Muebles, decoracion y articulos del hogar/);
  assert.match(page, /Eliminar publicación/);
  assert.match(page, /actions\.deleteListing/);
  assert.match(store, /listing\.source !== "user"/);
  assert.match(store, /listing\.sellerId !== activeUser\.id/);
  assert.match(store, /Array\.isArray\(previous\.chats\)/);
  assert.doesNotMatch(store, /previous\.favorites\.filter|previous\.carts\.filter/);
});

test("uses the ERLC map for shipment tracking zones", async () => {
  const shippingMap = await readFile(
    new URL("../app/components/ShippingMap.tsx", import.meta.url),
    "utf8",
  );
  const store = await readFile(
    new URL("../app/lib/useMarketplaceStore.ts", import.meta.url),
    "utf8",
  );
  const authModal = await readFile(
    new URL("../app/components/AuthModal.tsx", import.meta.url),
    "utf8",
  );
  const stylesheet = await readFile(
    new URL("../app/globals.css", import.meta.url),
    "utf8",
  );
  const mapAsset = await stat(
    new URL("../IMG/official/erlc-delivery-map.webp", import.meta.url),
  );

  assert.ok(mapAsset.size > 1_000_000);
  assert.match(shippingMap, /erlc-delivery-map\.webp/);
  assert.match(shippingMap, /Creacion 3031/);
  assert.match(shippingMap, /Reparto \/ retiro 308/);
  assert.match(shippingMap, /routeFor\(shipment\.destination\)/);
  assert.doesNotMatch(shippingMap, /shipment\.route\.map/);
  assert.match(store, /destinationZoneFor/);
  assert.match(store, /x: 49\.5, y: 82\.4/);
  assert.match(store, /x: 47\.8, y: 61\.1/);
  assert.match(store, /Vivienda 1202/);
  assert.match(stylesheet, /aspect-ratio: 16 \/ 9/);
  assert.match(stylesheet, /object-fit: contain/);
  assert.match(authModal, /número de casa/);
});

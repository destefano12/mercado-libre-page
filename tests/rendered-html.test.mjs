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
  assert.match(workRoute, /readMarketplaceSnapshot/);
  assert.match(workRoute, /source_shipment_id/);
  assert.match(workRoute, /buildOrderFromShipment/);
  assert.match(workRoute, /updateShipmentStage/);
  assert.match(workRoute, /nextShipmentStage/);
  assert.match(workRoute, /preparing/);
  assert.match(workRoute, /pickup/);
  assert.doesNotMatch(page, /<option>Conductor<\/option>/);
  assert.match(workRoute, /status IN \('offered', 'preparing', 'pickup', 'active'\)/);
  assert.match(page, /workOrderActionLabel/);
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

test("removes delivered purchases from the visible purchases tray", async () => {
  const page = await readFile(new URL("../app/components/MarketplaceApp.tsx", import.meta.url), "utf8");
  const store = await readFile(new URL("../app/lib/useMarketplaceStore.ts", import.meta.url), "utf8");
  const workRoute = await readFile(new URL("../app/api/work/route.ts", import.meta.url), "utf8");

  assert.match(page, /shipment\.progress < 100/);
  assert.match(page, /!shipment\.status\.toLowerCase\(\)\.includes\("entregado"\)/);
  assert.match(store, /function isFinishedShipment/);
  assert.match(store, /\.filter\(\(shipment\) => !isFinishedShipment\(shipment\)\)/);
  assert.match(workRoute, /const finished = update\.progress >= 100/);
  assert.match(workRoute, /snapshot\.shipments\.filter\(\(shipment\) => shipment\.id !== shipmentId\)/);
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

test("applies category coupons to real purchase totals", async () => {
  const page = await readFile(
    new URL("../app/components/MarketplaceApp.tsx", import.meta.url),
    "utf8",
  );
  const marketplace = await readFile(
    new URL("../app/data/marketplace.ts", import.meta.url),
    "utf8",
  );
  const store = await readFile(
    new URL("../app/lib/useMarketplaceStore.ts", import.meta.url),
    "utf8",
  );
  const stylesheet = await readFile(
    new URL("../app/globals.css", import.meta.url),
    "utf8",
  );

  assert.match(page, /interface MarketplaceCoupon/);
  assert.match(page, /marketplaceCoupons/);
  assert.match(page, /TECNO50000/);
  assert.match(page, /SUPER8000/);
  assert.match(page, /calculateCouponDiscount/);
  assert.match(page, /applyCouponCode/);
  assert.match(page, /cartTotal/);
  assert.match(page, /couponPurchaseForListing/);
  assert.match(page, /couponDiscount/);
  assert.match(page, /paidPrice/);
  assert.match(marketplace, /couponCode\?: string/);
  assert.match(marketplace, /couponDiscount\?: number/);
  assert.match(store, /paidPrice: Math\.max\(0, purchase\?\.paidPrice/);
  assert.match(stylesheet, /\.buy-box__coupon/);
  assert.match(stylesheet, /\.purchase-item__coupon/);
});

test("adds official-style surfaces for supermarket, fashion, play, help and offers", async () => {
  const page = await readFile(
    new URL("../app/components/MarketplaceApp.tsx", import.meta.url),
    "utf8",
  );
  const stylesheet = await readFile(
    new URL("../app/globals.css", import.meta.url),
    "utf8",
  );

  assert.match(page, /supermarket-page/);
  assert.match(page, /supermarketAisles/);
  assert.match(page, /supermarketTab/);
  assert.match(page, /fashion-page/);
  assert.match(page, /fashionBrands/);
  assert.match(page, /fashion-campaign-original\.png/);
  assert.match(page, /Suscribite a Paramount\+ con 15% OFF/);
  assert.match(page, /play-shell/);
  assert.match(page, /play-splash/);
  assert.match(page, /playHeroIndex/);
  assert.match(page, /playTabs/);
  assert.match(page, /visiblePlayContent/);
  assert.match(page, /openPlay\("inicio"\)/);
  assert.match(page, /offers-tabs/);
  assert.match(page, /offers-sidebar/);
  assert.match(page, /offerFullOnly/);
  assert.match(page, /visibleHelpTopics/);
  assert.match(page, /Atajos personalizados/);
  assert.match(page, /Necesitás más ayuda/);
  assert.match(stylesheet, /\.supermarket-hero/);
  assert.match(stylesheet, /\.fashion-hero/);
  assert.match(stylesheet, /\.play-splash/);
  assert.match(stylesheet, /\.play-topbar/);
  assert.match(stylesheet, /\.play-hero-official/);
  assert.match(stylesheet, /\.play-modal/);
  assert.match(stylesheet, /\.offers-layout/);
  assert.match(stylesheet, /\.help-layout--official/);
  assert.match(stylesheet, /\.help-contact/);
});

test("uses real catalog artwork and proper visual icons in Play, supermarket and offers", async () => {
  const page = await readFile(
    new URL("../app/components/MarketplaceApp.tsx", import.meta.url),
    "utf8",
  );
  const visuals = await readFile(
    new URL("../app/data/marketplaceVisuals.ts", import.meta.url),
    "utf8",
  );
  const stylesheet = await readFile(
    new URL("../app/globals.css", import.meta.url),
    "utf8",
  );

  assert.match(page, /Películas gratis para ver ahora/);
  assert.match(page, /Series para maratonear/);
  assert.match(page, /Saga Harry Potter: 30% OFF/);
  assert.match(page, /Duna: Parte Dos/);
  assert.match(page, /The Rookie/);
  assert.match(page, /OfferTabIcon/);
  assert.match(page, /SupermarketBenefitIcon/);
  assert.match(page, /<img src=\{aisle\.image\}/);
  assert.match(page, /Demo no afiliada/);
  assert.match(page, /supermarketBrandImages\.logo/);
  assert.match(visuals, /streaming\/catalog\/harry-potter-1\.webp/);
  assert.match(visuals, /streaming\/catalog\/friends\.webp/);
  assert.match(visuals, /supermarket\/aisles\/offers\.webp/);
  assert.match(visuals, /supermarket\/full-super-header\.webp/);
  assert.match(visuals, /supermarket\/full-super-logo\.jpg/);
  assert.match(stylesheet, /\.offer-tab-icon/);
  assert.match(stylesheet, /\.supermarket-symbol/);
  assert.match(stylesheet, /\.supermarket-hero__groceries/);
});

test("does not leave inert button-looking controls in the main marketplace", async () => {
  const page = await readFile(
    new URL("../app/components/MarketplaceApp.tsx", import.meta.url),
    "utf8",
  );
  const inertButtons = [...page.matchAll(/<button\b(?<attributes>[^>]*)>/gs)]
    .map((match) => match.groups?.attributes ?? "")
    .filter((attributes) =>
      !attributes.includes("onClick=") &&
      !attributes.includes('type="submit"') &&
      !attributes.includes("disabled"),
    );

  assert.deepEqual(inertButtons, []);
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

test("keeps Liberty County trial products removed from the catalog", async () => {
  const marketplace = await readFile(new URL("../app/data/marketplace.ts", import.meta.url), "utf8");
  const store = await readFile(new URL("../app/lib/useMarketplaceStore.ts", import.meta.url), "utf8");

  assert.match(marketplace, /Mercado Play/);
  assert.doesNotMatch(marketplace, /Liberty County Store/);
  assert.doesNotMatch(marketplace, /Pack Tool Store|Strugatti Ettore|Falcon Traveller/);
  assert.doesNotMatch(marketplace, /Combo hamburguesa Three Guys|Drone GadgetShack|Celular Liberty County/);
  assert.doesNotMatch(marketplace, /@\/IMG\/erlc/);
  assert.match(store, /RETIRED_LISTING_IDS/);
  assert.match(store, /cleanRetiredMarketplaceState/);
  assert.match(store, /!RETIRED_LISTING_IDS\.has\(shipment\.listingId\) &&/);
  assert.match(store, /!isFinishedShipment\(shipment\)/);
  assert.match(store, /u-erlc-catalog/);
});

test("keeps the ERLC private server key behind a backend route", async () => {
  const erlcRoute = await readFile(new URL("../app/api/erlc/route.ts", import.meta.url), "utf8");
  const page = await readFile(new URL("../app/components/MarketplaceApp.tsx", import.meta.url), "utf8");
  const gitignore = await readFile(new URL("../.gitignore", import.meta.url), "utf8");

  assert.match(erlcRoute, /https:\/\/api\.erlc\.gg/);
  assert.match(erlcRoute, /\/v2\/server/);
  assert.match(erlcRoute, /"server-key": serverKey/);
  assert.match(erlcRoute, /ERLC_API_KEY/);
  assert.doesNotMatch(page, /ERLC_API_KEY|server-key/);
  assert.match(gitignore, /\.env\*/);
});

test("tracks delivery courier location from ERLC players on the shipment map", async () => {
  const marketplace = await readFile(new URL("../app/data/marketplace.ts", import.meta.url), "utf8");
  const page = await readFile(new URL("../app/components/MarketplaceApp.tsx", import.meta.url), "utf8");
  const shippingMap = await readFile(new URL("../app/components/ShippingMap.tsx", import.meta.url), "utf8");
  const workRoute = await readFile(new URL("../app/api/work/route.ts", import.meta.url), "utf8");
  const stylesheet = await readFile(new URL("../app/globals.css", import.meta.url), "utf8");

  assert.match(marketplace, /courierRobloxUserId/);
  assert.match(workRoute, /courierRobloxUsername/);
  assert.match(workRoute, /roblox_user_id/);
  assert.match(page, /\/api\/erlc\?players=true/);
  assert.match(page, /parseErlcPlayer/);
  assert.match(page, /LocationX/);
  assert.match(page, /LocationZ/);
  assert.match(page, /courierLocations/);
  assert.match(shippingMap, /LiveCourierLocation/);
  assert.match(shippingMap, /worldToMapPoint/);
  assert.match(shippingMap, /worldX \* 0\.03547/);
  assert.match(shippingMap, /worldZ \* 0\.03532/);
  assert.match(shippingMap, /MAP_IMAGE_LEFT_PERCENT = 0/);
  assert.match(shippingMap, /MAP_IMAGE_WIDTH_PERCENT = 100/);
  assert.match(shippingMap, /NUMBERED_MAP_LEFT_PERCENT/);
  assert.match(shippingMap, /mapPointStyle/);
  assert.match(shippingMap, /PostalCode|postalCode/);
  assert.match(shippingMap, /addressPointFor/);
  assert.match(shippingMap, /addressPoint \?\? exact/);
  assert.match(shippingMap, /Vivienda 7042/);
  assert.match(shippingMap, /Postal 4071/);
  assert.match(shippingMap, /🛵/);
  assert.match(stylesheet, /gps-map__vehicle small/);
  assert.match(stylesheet, /is-courier/);
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
  assert.match(authRoute, /revokeCurrentSession/);
  assert.match(serverAuth, /DELETE FROM marketplace_sessions WHERE token_hash = \?/);
  assert.doesNotMatch(serverAuth, /DELETE FROM marketplace_sessions WHERE user_id = \?/);
  assert.match(store, /const logout = useCallback/);
  assert.doesNotMatch(store, /logout[\s\S]{0,500}broadcast\(/);
  assert.doesNotMatch(store, /logout[\s\S]{0,500}pushRemote\(/);
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
  assert.match(publishModal, /key === "marca"/);
  assert.match(publishModal, /Escribi la marca/);
  assert.match(publishModal, /clipboardData\.files/);
  assert.match(publishModal, /onDrop/);
  assert.match(publishModal, /is-dragging/);
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
    new URL("../IMG/official/erlc-delivery-map-numbered-4k.png", import.meta.url),
  );

  assert.ok(mapAsset.size > 1_000_000);
  assert.match(shippingMap, /erlc-delivery-map-numbered-4k\.png/);
  assert.match(shippingMap, /Creacion 303/);
  assert.match(shippingMap, /Reparto \/ retiro 308/);
  assert.match(shippingMap, /routeFor\(shipment\.destination\)/);
  assert.doesNotMatch(shippingMap, /shipment\.route\.map/);
  assert.match(store, /destinationZoneFor/);
  assert.match(store, /exactHousePoints/);
  assert.match(store, /Vivienda 707/);
  assert.match(store, /Vivienda 7042/);
  assert.match(store, /Postal 4071/);
  assert.match(store, /Vivienda 7094/);
  assert.match(store, /exactPointKeyForDigits/);
  assert.match(store, /routeForLocation\(result\.user\.location\)/);
  assert.match(store, /x: 49\.6, y: 79\.7/);
  assert.match(store, /x: 47\.8, y: 61\.1/);
  assert.match(store, /pointBehindHome/);
  assert.match(store, /Vivienda 703/);
  assert.match(store, /Vivienda 1202/);
  assert.match(stylesheet, /aspect-ratio: 16 \/ 9/);
  assert.match(stylesheet, /object-fit: contain/);
  assert.match(stylesheet, /var\(--route-left, 0%\) bottom \/ var\(--route-width, 0%\)/);
  assert.match(authModal, /número de casa/);
});

async function renderEstudiarMejor() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `estudiar-${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request("http://localhost/estudiar-mejor", {
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

test("server-renders the Estudiar Mejor platform shell", async () => {
  const response = await renderEstudiarMejor();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<title>Estudiar Mejor \| Acompañamiento para estudiantes de secundaria<\/title>/i);
  assert.match(html, /Estudiar Mejor/);
});

test("keeps the Estudiar Mejor modules and the never-solve principle", async () => {
  const app = await readFile(
    new URL("../app/estudiar-mejor/components/EstudiarMejorApp.tsx", import.meta.url),
    "utf8",
  );
  const navegacion = await readFile(
    new URL("../app/estudiar-mejor/components/navegacion.ts", import.meta.url),
    "utf8",
  );
  const manifiesto = await readFile(
    new URL("../app/estudiar-mejor/modulos/Manifiesto.tsx", import.meta.url),
    "utf8",
  );
  const guardia = await readFile(
    new URL("../app/estudiar-mejor/lib/guardia.ts", import.meta.url),
    "utf8",
  );
  const panelAdultos = await readFile(
    new URL("../app/estudiar-mejor/modulos/PanelAdultos.tsx", import.meta.url),
    "utf8",
  );

  for (const modulo of [
    "planificador",
    "tutor",
    "explicame",
    "mapa",
    "errores",
    "grupos",
    "agenda",
    "pomodoro",
    "simulador",
    "adultos",
  ]) {
    assert.match(navegacion, new RegExp(`id: "${modulo}"`));
    assert.match(app, new RegExp(`seccion === "${modulo}"`));
  }

  assert.match(manifiesto, /Nunca resuelvo tus tareas/);
  assert.match(manifiesto, /Nunca redacto tus trabajos/);
  assert.match(manifiesto, /devuelvo preguntas/);
  assert.match(guardia, /resolver-ejercicio/);
  assert.match(guardia, /escribir-texto/);
  assert.match(guardia, /responderComoGuia/);
  assert.match(panelAdultos, /no muestra notas ni calificaciones/);
});

test("keeps Estudiar Mejor data in the browser and away from the marketplace styles", async () => {
  const store = await readFile(
    new URL("../app/estudiar-mejor/lib/store.tsx", import.meta.url),
    "utf8",
  );
  const hoja = await readFile(
    new URL("../app/estudiar-mejor/estudiar.css", import.meta.url),
    "utf8",
  );

  assert.match(store, /window\.localStorage\.setItem\(CLAVE_ALMACENAMIENTO/);
  assert.match(store, /window\.localStorage\.getItem\(CLAVE_ALMACENAMIENTO\)/);
  assert.doesNotMatch(store, /fetch\(/);

  // El bundle de CSS es único para todo el sitio: el preflight de Tailwind
  // pisaría los estilos del marketplace, así que el reset va acotado a .em-app.
  assert.doesNotMatch(hoja, /@import "tailwindcss";/);
  assert.match(hoja, /\.em-app \*::before/);

  // Las utilidades van sin capa: el marketplace declara `color: inherit` sobre
  // los botones fuera de toda capa y le ganaría a cualquier `@layer`.
  assert.match(hoja, /@import "tailwindcss\/utilities\.css";/);
  assert.doesNotMatch(hoja, /@import "tailwindcss\/utilities\.css" layer\(utilities\);/);
});

test("generates practice questions on request and keeps refusing to solve", async () => {
  const consignas = await readFile(
    new URL("../app/estudiar-mejor/lib/consignas.ts", import.meta.url),
    "utf8",
  );
  const guardia = await readFile(
    new URL("../app/estudiar-mejor/lib/guardia.ts", import.meta.url),
    "utf8",
  );
  const panel = await readFile(
    new URL("../app/estudiar-mejor/components/PanelGuardia.tsx", import.meta.url),
    "utf8",
  );

  assert.match(guardia, /"pedir-preguntas"/);
  assert.match(guardia, /pregunt\[a\u00e1\]me/);
  assert.match(consignas, /export function armarConsignas/);
  assert.match(consignas, /export function temaDelPedido/);
  assert.match(panel, /armarConsignas/);

  // Pedir consignas no es un pedido bloqueado, pero resolver sigue estándolo.
  assert.match(guardia, /bloqueado: bloqueado && intencion !== "pedir-preguntas"/);
  assert.match(guardia, /"resolver-ejercicio"/);
});

test("answers topic requests from a curated bank, calibrated by school year", async () => {
  const banco = await readFile(
    new URL("../app/estudiar-mejor/lib/banco.ts", import.meta.url),
    "utf8",
  );
  const consignas = await readFile(
    new URL("../app/estudiar-mejor/lib/consignas.ts", import.meta.url),
    "utf8",
  );
  const panel = await readFile(
    new URL("../app/estudiar-mejor/components/PanelGuardia.tsx", import.meta.url),
    "utf8",
  );
  const tipos = await readFile(
    new URL("../app/estudiar-mejor/lib/tipos.ts", import.meta.url),
    "utf8",
  );

  // El banco cubre materias de secundaria con consignas propias del tema.
  for (const tema of [
    "Grecia antigua",
    "Revoluci\u00f3n Francesa",
    "Fotos\u00edntesis",
    "Leyes de Newton",
    "Tabla peri\u00f3dica",
    "Funciones cuadr\u00e1ticas",
    "Derechos humanos",
  ]) {
    assert.match(banco, new RegExp(`nombre: "${tema}"`));
  }
  assert.match(banco, /Guerras M\u00e9dicas/);
  assert.match(banco, /export function buscarEnBanco/);
  assert.match(banco, /export function elegirPorNivel/);
  assert.match(banco, /export function nivelDePregunta/);

  // Tres fuentes en orden: material propio, banco, esquema general.
  assert.match(consignas, /origen: "material"/);
  assert.match(consignas, /origen: "banco"/);
  assert.match(consignas, /origen: "esquema"/);
  assert.match(consignas, /anio/);

  // El a\u00f1o que cursa vive en el estado y se usa para calibrar.
  assert.match(tipos, /anio: number/);
  assert.match(panel, /anio: estado\.anio/);

  // El tema se busca por su nombre, nunca por la materia sola.
  assert.match(panel, /nunca por la materia/);
  assert.doesNotMatch(panel, /plano\.includes\(materia\)/);
});

test("reads PDF notes in the browser without uploading them", async () => {
  const lector = await readFile(
    new URL("../app/estudiar-mejor/lib/pdf.ts", import.meta.url),
    "utf8",
  );
  const cargador = await readFile(
    new URL("../app/estudiar-mejor/lib/cargarPdfjs.ts", import.meta.url),
    "utf8",
  );
  const tutor = await readFile(
    new URL("../app/estudiar-mejor/modulos/Tutor.tsx", import.meta.url),
    "utf8",
  );
  const worker = await stat(new URL("../public/pdf.worker.min.mjs", import.meta.url));

  assert.ok(worker.size > 500_000);
  assert.match(cargador, /pdfjs-dist\/legacy\/build\/pdf\.min\.mjs/);
  assert.match(lector, /export async function extraerTextoDePdf/);
  assert.match(lector, /__EM_PDF_WORKER__/);

  // Un PDF escaneado no tiene texto: hay que decirlo en lugar de fallar en silencio.
  assert.match(lector, /son im\u00e1genes escaneadas/);
  assert.match(lector, /contrase\u00f1a/);

  assert.match(tutor, /extraerTextoDePdf/);
  assert.match(tutor, /accept="\.pdf,application\/pdf,\.txt,\.md,\.csv,text\/plain"/);
  assert.match(tutor, /Leyendo el PDF/);
});

test("offers fixed study durations with a drift-free timer", async () => {
  const pomodoro = await readFile(
    new URL("../app/estudiar-mejor/modulos/Pomodoro.tsx", import.meta.url),
    "utf8",
  );

  assert.match(pomodoro, /const DURACIONES = \[5, 10, 15, 25, 40, 60\]/);
  assert.match(pomodoro, /empezarSesion/);
  // El reloj se ancla a un instante final para no atrasarse en segundo plano.
  assert.match(pomodoro, /finRef\.current = Date\.now\(\) \+/);
  assert.match(pomodoro, /setAviso\(/);
});

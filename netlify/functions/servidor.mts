/**
 * Toda la aplicacion corre en esta funcion de Netlify.
 *
 * `npm run build:netlify` deja en dist/server el servidor de vinext, que ya
 * habla Request -> Response igual que una funcion de Netlify; aca solo se lo
 * conecta. Los archivos estaticos (dist/client) los sirve Netlify antes de
 * llegar aca gracias a `preferStatic`.
 */
// @ts-expect-error: lo genera la compilacion, no existe antes de compilar.
import servidor from "../../dist/server/index.js";

type Manejador = (pedido: Request, ...resto: unknown[]) => Promise<Response>;

const manejar: Manejador =
  typeof servidor === "function" ? servidor : servidor.fetch.bind(servidor);

const contexto = { waitUntil() {}, passThroughOnException() {} };

export default function servirPedido(pedido: Request) {
  return manejar(pedido, {}, contexto);
}

export const config = {
  path: "/*",
  preferStatic: true,
};

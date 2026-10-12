/**
 * Reemplazo de `cloudflare:workers` para los destinos que no son Cloudflare.
 *
 * Las rutas piden la base con `await import("cloudflare:workers")` y leen
 * `env.DB`. Fuera de Cloudflare ese modulo no existe y el bundler no sabria
 * resolverlo, asi que en el build de Netlify se lo apunta a este archivo:
 * devuelve un entorno sin `DB`, con lo cual `getBaseDatos()` detecta que no hay
 * D1 y usa libSQL. No lanza error a proposito, para que la deteccion sea un
 * dato y no una excepcion.
 */
export const env: Record<string, unknown> = {};

export default { env };

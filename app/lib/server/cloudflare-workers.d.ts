// En Cloudflare el runtime provee este modulo; en Netlify lo reemplaza
// build/stubs/cloudflare-workers.ts. Solo se lee `env`.
declare module "cloudflare:workers" {
  export const env: Record<string, unknown>;
}

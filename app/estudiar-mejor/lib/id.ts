export function crearId(prefijo: string): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
    return `${prefijo}-${crypto.randomUUID().slice(0, 8)}`;
  }
  return `${prefijo}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 7)}`;
}

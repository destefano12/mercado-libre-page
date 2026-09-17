/**
 * Carga del motor de escaneo, aislada igual que la de pdf.js para que cada
 * empaquetado la resuelva a su manera.
 */
export function cargarOcr(): Promise<unknown> {
  return import("tesseract.js");
}

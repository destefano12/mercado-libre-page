/**
 * Carga de pdf.js, aislada en su propio módulo para que cada empaquetado
 * resuelva la librería a su manera: la app del sitio la parte en un chunk
 * aparte, y las versiones de un solo archivo la sirven como archivo suelto
 * al lado del index (ver `__EM_PDF_JS__`).
 */
export function cargarPdfjs(): Promise<unknown> {
  return import("pdfjs-dist/legacy/build/pdf.min.mjs");
}

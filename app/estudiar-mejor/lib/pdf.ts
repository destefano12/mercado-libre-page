import { cargarPdfjs } from "./cargarPdfjs";

/**
 * Lectura de PDF dentro del navegador. El archivo no se sube a ningún lado:
 * pdf.js corre en el propio dispositivo, igual que el resto de la aplicación.
 */

export interface AvanceLectura {
  /** Verdadero mientras se leen las páginas como imagen, que tarda más. */
  escaneando?: boolean;
  pagina: number;
  total: number;
}

export class ErrorPdf extends Error {}

/**
 * Tipos mínimos de pdf.js. El paquete publica su build minificado sin
 * declaraciones, así que se describe acá sólo lo que esta función usa.
 */
interface ItemTexto {
  str?: string;
  transform?: number[];
  hasEOL?: boolean;
}

interface PaginaPdf {
  getTextContent: () => Promise<{ items: ItemTexto[] }>;
  getViewport: (opciones: { scale: number }) => { width: number; height: number };
  render: (opciones: { canvasContext: CanvasRenderingContext2D; viewport: { width: number; height: number } }) => {
    promise: Promise<void>;
  };
  cleanup: () => void;
}

interface DocumentoPdf {
  numPages: number;
  getPage: (numero: number) => Promise<PaginaPdf>;
}

/** `getDocument` devuelve la tarea de carga, y es ella la que se libera al final. */
interface TareaPdf {
  promise: Promise<DocumentoPdf>;
  destroy: () => Promise<void>;
}

interface ModuloPdfJs {
  GlobalWorkerOptions: { workerSrc: string };
  getDocument: (opciones: Record<string, unknown>) => TareaPdf;
}

/** Dónde vive el worker de pdf.js; cada empaquetado lo publica en su lugar. */
function rutaDelWorker(): string {
  const configurada = (globalThis as { __EM_PDF_WORKER__?: string }).__EM_PDF_WORKER__;
  return typeof configurada === "string" && configurada ? configurada : "/pdf.worker.min.mjs";
}

function limpiar(texto: string): string {
  return texto
    // Une las palabras cortadas por guión al final de renglón.
    .replace(/(\w)-\n(\w)/g, "$1$2")
    .replace(/[ \t]+/g, " ")
    .replace(/ ?\n ?/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

/** Cuántas páginas se escanean como imagen: más que esto tarda demasiado. */
const TOPE_ESCANEADO = 10;

/**
 * Un PDF escaneado no tiene letras, tiene fotos de letras. Para esos se dibuja
 * cada página y se la pasa por el mismo escáner que usan las fotos sacadas con
 * el celular. Es más lento que leer el texto, así que sólo se hace cuando el
 * PDF no trae ninguno.
 */
async function escanearPaginas(
  documento: DocumentoPdf,
  onAvance?: (avance: AvanceLectura) => void,
): Promise<string> {
  const { escanearImagen } = await import("./ocr");
  const hasta = Math.min(documento.numPages, TOPE_ESCANEADO);
  const partes: string[] = [];

  for (let numero = 1; numero <= hasta; numero += 1) {
    onAvance?.({ pagina: numero, total: hasta, escaneando: true });

    const pagina = await documento.getPage(numero);
    // El doble de tamaño: el escáner lee bastante mejor con más resolución.
    const vista = pagina.getViewport({ scale: 2 });
    const lienzo = document.createElement("canvas");
    lienzo.width = Math.round(vista.width);
    lienzo.height = Math.round(vista.height);
    const pincel = lienzo.getContext("2d");
    if (!pincel) break;

    await pagina.render({ canvasContext: pincel, viewport: vista }).promise;
    pagina.cleanup();

    const imagen = await new Promise<Blob | null>((listo) => lienzo.toBlob(listo, "image/png"));
    lienzo.width = 0;
    lienzo.height = 0;
    if (!imagen) continue;

    try {
      partes.push(await escanearImagen(new File([imagen], `pagina-${numero}.png`, { type: "image/png" })));
    } catch {
      // Una página que no se deja leer no tira abajo las demás.
    }
  }

  const texto = limpiar(partes.join("\n\n"));
  if (texto.replace(/\s/g, "").length < 40) {
    throw new ErrorPdf(
      "Ese PDF son imágenes escaneadas y no pude leerlas. Si están torcidas o con poca luz, probá sacando la foto de nuevo, o copiá el texto a mano.",
    );
  }

  return documento.numPages > hasta
    ? `${texto}\n\n[Se leyeron las primeras ${hasta} páginas de ${documento.numPages}.]`
    : texto;
}

export async function extraerTextoDePdf(
  archivo: File,
  onAvance?: (avance: AvanceLectura) => void,
): Promise<string> {
  const pdfjs = (await cargarPdfjs()) as ModuloPdfJs;
  pdfjs.GlobalWorkerOptions.workerSrc = rutaDelWorker();

  let documento: DocumentoPdf;
  let tarea: TareaPdf;
  try {
    tarea = pdfjs.getDocument({
      data: new Uint8Array(await archivo.arrayBuffer()),
      // El texto alcanza: no hace falta descargar tipografías ni mapas de caracteres.
      isEvalSupported: false,
      useSystemFonts: true,
    });
    documento = await tarea.promise;
  } catch (error) {
    const detalle = error instanceof Error ? error.message : "";
    if (/password/i.test(detalle)) {
      throw new ErrorPdf("Ese PDF está protegido con contraseña y no puedo abrirlo.");
    }
    throw new ErrorPdf("No pude abrir ese PDF. Revisá que el archivo no esté dañado.");
  }

  const partes: string[] = [];
  for (let numero = 1; numero <= documento.numPages; numero += 1) {
    onAvance?.({ pagina: numero, total: documento.numPages });
    const pagina = await documento.getPage(numero);
    const contenido = await pagina.getTextContent();

    const renglones: string[] = [];
    let ultimaAltura: number | null = null;

    contenido.items.forEach((item) => {
      if (typeof item.str !== "string" || !item.transform) return;
      const altura = Math.round(item.transform[5]);
      // Un salto de altura marca renglón nuevo; el mismo renglón se concatena.
      if (ultimaAltura === null || Math.abs(altura - ultimaAltura) > 2) renglones.push(item.str);
      else renglones[renglones.length - 1] += item.str;
      ultimaAltura = altura;
      if (item.hasEOL) ultimaAltura = null;
    });

    partes.push(renglones.join("\n"));
    pagina.cleanup();
  }

  const texto = limpiar(partes.join("\n\n"));

  // Sin texto, el PDF es un escaneo: se lo pasa por el escáner de fotos.
  try {
    return texto.replace(/\s/g, "").length < 40 ? await escanearPaginas(documento, onAvance) : texto;
  } finally {
    await tarea.destroy();
  }
}

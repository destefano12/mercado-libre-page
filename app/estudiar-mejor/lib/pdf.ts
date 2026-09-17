import { cargarPdfjs } from "./cargarPdfjs";

/**
 * Lectura de PDF dentro del navegador. El archivo no se sube a ningún lado:
 * pdf.js corre en el propio dispositivo, igual que el resto de la aplicación.
 */

export interface AvanceLectura {
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

  await tarea.destroy();
  const texto = limpiar(partes.join("\n\n"));

  if (texto.replace(/\s/g, "").length < 40) {
    throw new ErrorPdf(
      "Ese PDF no tiene texto: son imágenes escaneadas. Probá con uno donde puedas seleccionar las letras.",
    );
  }

  return texto;
}

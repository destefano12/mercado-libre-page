import { cargarOcr } from "./cargarOcr";

/**
 * Escaneo de fotos dentro del navegador (OCR). La imagen no se sube a ningún
 * lado: el motor corre en el propio dispositivo.
 *
 * Importante: esto lee **texto impreso**. Con letra manuscrita los resultados
 * son malos, y por eso la interfaz lo advierte antes de que el alumno saque la
 * foto.
 */

export class ErrorOcr extends Error {}

interface TrabajadorOcr {
  recognize: (imagen: File | Blob | string) => Promise<{ data: { text: string; confidence: number } }>;
  terminate: () => Promise<void>;
}

interface ModuloOcr {
  createWorker: (
    idiomas: string,
    oem: number,
    opciones: Record<string, unknown>,
  ) => Promise<TrabajadorOcr>;
}

function ruta(nombre: "__EM_OCR_WORKER__" | "__EM_OCR_CORE__" | "__EM_OCR_LANG__", porDefecto: string): string {
  const configurada = (globalThis as Record<string, unknown>)[nombre];
  return typeof configurada === "string" && configurada ? configurada : porDefecto;
}

let trabajador: Promise<TrabajadorOcr> | null = null;

/** Un solo motor para toda la sesión: arrancarlo es lo que más tarda. */
function obtenerTrabajador(onEstado?: (mensaje: string) => void): Promise<TrabajadorOcr> {
  if (trabajador) return trabajador;

  trabajador = (async () => {
    const modulo = (await cargarOcr()) as ModuloOcr;
    onEstado?.("Preparando el escáner…");

    return modulo.createWorker("spa", 1, {
      workerPath: ruta("__EM_OCR_WORKER__", "/ocr/worker.min.js"),
      // Se apunta al archivo exacto en vez de a la carpeta: así no hace falta
      // publicar las tres variantes del motor, sólo la que vamos a usar.
      corePath: ruta("__EM_OCR_CORE__", "/ocr/tesseract-core-simd-lstm.wasm.js"),
      langPath: ruta("__EM_OCR_LANG__", "/ocr"),
      // El diccionario va sin comprimir: varios servidores estáticos no
      // entregan archivos .gz tal cual y el motor se queda esperándolo.
      gzip: false,
      cacheMethod: "none",
      logger: (registro: { status?: string; progress?: number }) => {
        if (registro.status === "recognizing text") {
          onEstado?.(`Escaneando… ${Math.round((registro.progress ?? 0) * 100)}%`);
        }
      },
    });
  })();

  trabajador.catch(() => {
    trabajador = null;
  });

  return trabajador;
}

export async function escanearImagen(
  archivo: File,
  onEstado?: (mensaje: string) => void,
): Promise<string> {
  let motor: TrabajadorOcr;
  try {
    motor = await obtenerTrabajador(onEstado);
  } catch {
    throw new ErrorOcr("No pude preparar el escáner de fotos. Probá recargando la página.");
  }

  let texto: string;
  let confianza: number;
  try {
    const resultado = await motor.recognize(archivo);
    texto = resultado.data.text;
    confianza = resultado.data.confidence;
  } catch {
    throw new ErrorOcr("No pude leer esa foto. Probá con una más nítida y derecha.");
  }

  const limpio = texto
    .replace(/(\w)-\n(\w)/g, "$1$2")
    .replace(/[ \t]+/g, " ")
    .replace(/ ?\n ?/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();

  if (limpio.replace(/\s/g, "").length < 40) {
    throw new ErrorOcr("De esa foto casi no salió texto. Fijate que se lea bien y que no esté escrita a mano.");
  }

  if (confianza < 55) {
    throw new ErrorOcr(
      "La foto salió muy borrosa para leerla con seguridad. Sacala más de cerca, derecha y con buena luz.",
    );
  }

  return limpio;
}

/** Libera el motor cuando ya no se va a escanear más. */
export async function soltarEscaner(): Promise<void> {
  if (!trabajador) return;
  const motor = await trabajador.catch(() => null);
  trabajador = null;
  await motor?.terminate();
}

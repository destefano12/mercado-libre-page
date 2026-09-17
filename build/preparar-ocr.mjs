/**
 * Prepara los archivos del escáner de fotos en `public/ocr`.
 *
 * El diccionario de Tesseract se publica como `spa.traineddata.wasm`: varios
 * servidores de archivos estáticos sólo entregan extensiones conocidas, y
 * `.traineddata` no lo es. Como el nombre del archivo lo arma el worker de
 * Tesseract, se ajusta también esa línea en la copia que publicamos.
 *
 * Se ejecuta con `npm run ocr:preparar` cada vez que se actualiza tesseract.js.
 */
import { createGunzip } from "node:zlib";
import { createReadStream, createWriteStream } from "node:fs";
import { copyFile, mkdir, readFile, writeFile, access } from "node:fs/promises";
import { pipeline } from "node:stream/promises";
import { resolve } from "node:path";

const raiz = resolve(import.meta.dirname, "..");
const destino = resolve(raiz, "public/ocr");
const IDIOMA = "https://cdn.jsdelivr.net/npm/@tesseract.js-data/spa@1.0.0/4.0.0_best_int/spa.traineddata.gz";

const URL_ORIGINAL = '.concat(i,".traineddata").concat(w?".gz":"")';
const URL_PARCHEADA = '.concat(i,".traineddata.wasm").concat(w?".gz":"")';

await mkdir(destino, { recursive: true });

// 1. Motor: una sola variante en vez de las tres que el runtime elegiría.
await copyFile(
  resolve(raiz, "node_modules/tesseract.js-core/tesseract-core-simd-lstm.wasm.js"),
  resolve(destino, "tesseract-core-simd-lstm.wasm.js"),
);

// 2. Worker, con la ruta del diccionario ajustada.
const worker = await readFile(resolve(raiz, "node_modules/tesseract.js/dist/worker.min.js"), "utf8");
if (!worker.includes(URL_ORIGINAL)) {
  throw new Error("El worker de tesseract.js cambió: revisá cómo arma la ruta del diccionario.");
}
await writeFile(resolve(destino, "worker.min.js"), worker.replaceAll(URL_ORIGINAL, URL_PARCHEADA));

// 3. Diccionario en español, descomprimido y con extensión servible.
const salida = resolve(destino, "spa.traineddata.wasm");
const comprimido = resolve(destino, "spa.traineddata.gz");

try {
  await access(salida);
  console.log("El diccionario ya estaba descargado.");
} catch {
  const respuesta = await fetch(IDIOMA);
  if (!respuesta.ok) throw new Error(`No se pudo descargar el diccionario: ${respuesta.status}`);
  await writeFile(comprimido, Buffer.from(await respuesta.arrayBuffer()));
  await pipeline(createReadStream(comprimido), createGunzip(), createWriteStream(salida));
}

console.log("Archivos del escáner listos en public/ocr");

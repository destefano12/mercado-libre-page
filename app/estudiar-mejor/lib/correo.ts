/**
 * Con el correo alcanza. El nombre se deduce mientras la persona no entró
 * todavía, y se reemplaza por el de verdad en cuanto entra con ese correo.
 */

const CORREO = /^[\w.+-]+@[\w-]+\.[\w.-]+$/;

export function esCorreo(texto: string): boolean {
  return CORREO.test(texto.trim());
}

export function normalizarCorreo(texto: string): string {
  return texto.trim().toLowerCase();
}

/** "juana.perez23@gmail.com" → "Juana Perez". */
export function nombreDesdeCorreo(correo: string): string {
  const local = correo.split("@")[0] ?? "";
  const palabras = local
    .replace(/\d+/g, " ")
    .split(/[._\-+]+/)
    .map((parte) => parte.trim())
    .filter(Boolean)
    .map((parte) => parte[0].toUpperCase() + parte.slice(1));

  return palabras.join(" ") || correo;
}

/** Acepta "juana@mail.com", "Juana <juana@mail.com>" o "Juana juana@mail.com". */
export function separarCorreo(entrada: string): { nombre: string; email: string } {
  const encontrado = entrada.match(/[\w.+-]+@[\w-]+\.[\w.-]+/);
  const email = normalizarCorreo(encontrado?.[0] ?? "");
  const resto = entrada
    .replace(encontrado?.[0] ?? "", "")
    .replace(/[<>,]/g, "")
    .trim();

  if (email) return { nombre: resto || nombreDesdeCorreo(email), email };
  return { nombre: entrada.trim(), email: "" };
}

/**
 * Invitaciones a un trabajo grupal.
 *
 * El mail sale del correo del dueño del grupo, desde su propio programa de
 * correo: la aplicación arma el mensaje y el enlace, y la persona lo manda.
 * No hay servidor de correo de por medio, así que nadie tiene que dar una
 * clave ni contratar nada, y al compañero le llega de una dirección que
 * conoce.
 */

export interface DatosInvitacion {
  codigo: string;
  nombreDelGrupo: string;
  materia: string;
  entrega: string;
  deParteDe: string;
  correos: string[];
}

/** La dirección que abre la página directo en la invitación. */
export function enlaceDeInvitacion(codigo: string): string {
  if (typeof window === "undefined") return `?grupo=${codigo}`;
  const { origin, pathname } = window.location;
  const base = origin.startsWith("http") ? `${origin}${pathname}` : pathname;
  return `${base}?grupo=${encodeURIComponent(codigo)}`;
}

export function textoDeInvitacion(datos: DatosInvitacion): string {
  const quien = datos.deParteDe.trim();
  return [
    `Hola: te sumé al trabajo práctico "${datos.nombreDelGrupo}" de ${datos.materia}.`,
    "",
    "Lo organizamos en Estudiar Mejor, una página donde se ve quién hace qué parte, cuánto falta para la entrega y tenemos el chat del grupo.",
    "",
    `Para entrar, abrí este enlace y tocá "Unirme al grupo":`,
    enlaceDeInvitacion(datos.codigo),
    "",
    `Si te pide el código, es: ${datos.codigo}`,
    "",
    datos.entrega ? `La entrega es el ${datos.entrega}.` : "",
    quien ? `Nos vemos,\n${quien}` : "",
  ]
    .filter((renglon) => renglon !== "")
    .join("\n");
}

/** El enlace que abre el programa de correo con todo escrito. */
export function enlaceDeCorreo(datos: DatosInvitacion): string {
  const para = datos.correos.filter(Boolean).join(",");
  const asunto = `Te sumé al trabajo práctico de ${datos.materia}: ${datos.nombreDelGrupo}`;
  return `mailto:${encodeURIComponent(para)}?subject=${encodeURIComponent(asunto)}&body=${encodeURIComponent(
    textoDeInvitacion(datos),
  )}`;
}

/** El código que venía en el enlace, si la página se abrió desde una invitación. */
export function codigoInvitado(): string {
  if (typeof window === "undefined") return "";
  const busqueda = new URLSearchParams(window.location.search);
  const enElHash = window.location.hash.includes("grupo=")
    ? new URLSearchParams(window.location.hash.replace(/^#/, "")).get("grupo")
    : null;
  const crudo = busqueda.get("grupo") ?? enElHash ?? "";
  const limpio = crudo.trim().toUpperCase();
  return /^[A-Z0-9]{4,12}$/.test(limpio) ? limpio : "";
}

/** Saca el código de la dirección para que la invitación no vuelva a abrirse. */
export function olvidarInvitacion(): void {
  if (typeof window === "undefined") return;
  const url = new URL(window.location.href);
  url.searchParams.delete("grupo");
  url.hash = "";
  window.history.replaceState(null, "", `${url.pathname}${url.search}`);
}

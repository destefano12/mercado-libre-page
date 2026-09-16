const DIAS = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"];
const DIAS_CORTOS = ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"];
const MESES = [
  "enero", "febrero", "marzo", "abril", "mayo", "junio",
  "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre",
];

/** Devuelve la fecha local (no UTC) en formato YYYY-MM-DD. */
export function claveFecha(fecha: Date): string {
  const anio = fecha.getFullYear();
  const mes = `${fecha.getMonth() + 1}`.padStart(2, "0");
  const dia = `${fecha.getDate()}`.padStart(2, "0");
  return `${anio}-${mes}-${dia}`;
}

export function hoyClave(): string {
  return claveFecha(new Date());
}

/** Parsea YYYY-MM-DD como fecha local, evitando el corrimiento de zona horaria. */
export function desdeClave(clave: string): Date {
  const [anio, mes, dia] = clave.split("-").map(Number);
  return new Date(anio, (mes ?? 1) - 1, dia ?? 1);
}

export function sumarDias(clave: string, dias: number): string {
  const fecha = desdeClave(clave);
  fecha.setDate(fecha.getDate() + dias);
  return claveFecha(fecha);
}

export function diferenciaEnDias(desde: string, hasta: string): number {
  const a = desdeClave(desde).getTime();
  const b = desdeClave(hasta).getTime();
  return Math.round((b - a) / 86_400_000);
}

export function nombreDia(clave: string): string {
  return DIAS[desdeClave(clave).getDay()] ?? "";
}

export function diaCorto(clave: string): string {
  return DIAS_CORTOS[desdeClave(clave).getDay()] ?? "";
}

export function fechaLarga(clave: string): string {
  const fecha = desdeClave(clave);
  return `${DIAS[fecha.getDay()]} ${fecha.getDate()} de ${MESES[fecha.getMonth()]}`;
}

export function fechaCorta(clave: string): string {
  const fecha = desdeClave(clave);
  return `${fecha.getDate()}/${`${fecha.getMonth() + 1}`.padStart(2, "0")}`;
}

/** "hoy", "mañana", "en 4 días", "hace 2 días". */
export function cuandoEs(clave: string, referencia = hoyClave()): string {
  const dias = diferenciaEnDias(referencia, clave);
  if (dias === 0) return "hoy";
  if (dias === 1) return "mañana";
  if (dias === -1) return "ayer";
  if (dias > 1) return `en ${dias} días`;
  return `hace ${Math.abs(dias)} días`;
}

export function minutosLegibles(minutos: number): string {
  if (minutos < 60) return `${minutos} min`;
  const horas = Math.floor(minutos / 60);
  const resto = minutos % 60;
  return resto === 0 ? `${horas} h` : `${horas} h ${resto} min`;
}

export function relojMmSs(segundos: number): string {
  const seguros = Math.max(0, Math.floor(segundos));
  const mm = `${Math.floor(seguros / 60)}`.padStart(2, "0");
  const ss = `${seguros % 60}`.padStart(2, "0");
  return `${mm}:${ss}`;
}

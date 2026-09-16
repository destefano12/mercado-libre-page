import { claveFecha, desdeClave, diferenciaEnDias, hoyClave, sumarDias } from "./fechas";
import { crearId } from "./id";
import type { EtapaPlan, Plan, SesionPlan } from "./tipos";

/**
 * Planificador realista: reparte el tema en sesiones cortas sobre los días que
 * el alumno dice tener, deja aire antes de la fecha límite y termina siempre
 * con un simulacro y un repaso liviano.
 */

export const ETAPAS: Record<EtapaPlan, { nombre: string; color: string; descripcion: string }> = {
  reconocimiento: {
    nombre: "Reconocimiento",
    color: "sky",
    descripcion: "Leer, marcar lo que no se entiende y anotar preguntas.",
  },
  comprension: {
    nombre: "Comprensión",
    color: "violet",
    descripcion: "Explicar con tus palabras, sin copiar del material.",
  },
  practica: {
    nombre: "Práctica",
    color: "amber",
    descripcion: "Responder preguntas del tutor y ejercitar.",
  },
  repaso: {
    nombre: "Repaso",
    color: "emerald",
    descripcion: "Volver sobre lo que falló, con repaso espaciado.",
  },
  simulacro: {
    nombre: "Simulacro",
    color: "rose",
    descripcion: "Prueba cronometrada y corrección explicada.",
  },
};

export const MINUTOS_MAXIMOS_POR_DIA = 120;
export const MINUTOS_MINIMOS_POR_DIA = 15;

export interface EntradaPlan {
  temaId: string;
  titulo: string;
  fechaLimite: string;
  minutosPorDia: number;
  diasSemana: number[];
}

function diasDisponibles(fechaLimite: string, diasSemana: number[]): string[] {
  const hoy = hoyClave();
  const total = diferenciaEnDias(hoy, fechaLimite);
  if (total < 0) return [];

  const permitidos = diasSemana.length > 0 ? new Set(diasSemana) : new Set([0, 1, 2, 3, 4, 5, 6]);
  const dias: string[] = [];

  for (let offset = 0; offset <= total; offset += 1) {
    const clave = sumarDias(hoy, offset);
    if (permitidos.has(desdeClave(clave).getDay())) dias.push(clave);
  }

  // Si los días elegidos no alcanzan, se usan todos los días hasta la entrega.
  if (dias.length === 0) {
    for (let offset = 0; offset <= total; offset += 1) dias.push(sumarDias(hoy, offset));
  }
  return dias;
}

function repartirEtapas(cantidad: number): EtapaPlan[] {
  if (cantidad <= 0) return [];
  if (cantidad === 1) return ["simulacro"];
  if (cantidad === 2) return ["comprension", "simulacro"];
  if (cantidad === 3) return ["reconocimiento", "practica", "simulacro"];

  // Las dos últimas jornadas quedan reservadas: simulacro y después repaso liviano.
  const cuerpo = cantidad - 2;
  const reconocimiento = Math.max(1, Math.round(cuerpo * 0.25));
  const comprension = Math.max(1, Math.round(cuerpo * 0.35));
  const practica = Math.max(1, cuerpo - reconocimiento - comprension - Math.round(cuerpo * 0.15));

  const secuencia: EtapaPlan[] = [
    ...Array<EtapaPlan>(reconocimiento).fill("reconocimiento"),
    ...Array<EtapaPlan>(comprension).fill("comprension"),
    ...Array<EtapaPlan>(practica).fill("practica"),
  ].slice(0, cuerpo);

  while (secuencia.length < cuerpo) secuencia.push("repaso");

  return [...secuencia, "simulacro", "repaso"];
}

function objetivoDe(etapa: EtapaPlan, titulo: string, numero: number, totalEtapa: number): string {
  const parte = totalEtapa > 1 ? ` (parte ${numero} de ${totalEtapa})` : "";
  switch (etapa) {
    case "reconocimiento":
      return `Leer ${titulo}${parte} y anotar 3 preguntas de lo que no se entiende.`;
    case "comprension":
      return `Explicar con tus palabras ${titulo}${parte} en el modo Explicámelo vos.`;
    case "practica":
      return `Responder las preguntas del tutor sobre ${titulo}${parte} y anotar los errores.`;
    case "repaso":
      return `Repaso espaciado de ${titulo}: tarjetas pendientes y errores sin resolver.`;
    case "simulacro":
      return `Simulacro cronometrado de ${titulo} y corrección tema por tema.`;
    default:
      return titulo;
  }
}

export function generarPlan(entrada: EntradaPlan): Plan {
  const minutos = Math.min(
    MINUTOS_MAXIMOS_POR_DIA,
    Math.max(MINUTOS_MINIMOS_POR_DIA, Math.round(entrada.minutosPorDia)),
  );
  const dias = diasDisponibles(entrada.fechaLimite, entrada.diasSemana);
  const etapas = repartirEtapas(dias.length);
  const conteo = new Map<EtapaPlan, number>();
  const totales = etapas.reduce<Record<string, number>>((acumulado, etapa) => {
    acumulado[etapa] = (acumulado[etapa] ?? 0) + 1;
    return acumulado;
  }, {});

  const sesiones: SesionPlan[] = dias.map((fecha, indice) => {
    const etapa = etapas[indice] ?? "repaso";
    const numero = (conteo.get(etapa) ?? 0) + 1;
    conteo.set(etapa, numero);

    // El simulacro necesita aire; el repaso final es liviano a propósito.
    const factor = etapa === "simulacro" ? 1 : etapa === "repaso" ? 0.7 : 1;

    return {
      id: crearId("sesion"),
      fecha,
      etapa,
      objetivo: objetivoDe(etapa, entrada.titulo, numero, totales[etapa] ?? 1),
      minutos: Math.max(MINUTOS_MINIMOS_POR_DIA, Math.round((minutos * factor) / 5) * 5),
      hecho: false,
    };
  });

  return {
    id: crearId("plan"),
    temaId: entrada.temaId,
    titulo: entrada.titulo,
    fechaLimite: entrada.fechaLimite,
    minutosPorDia: minutos,
    diasSemana: entrada.diasSemana,
    creadoEn: new Date().toISOString(),
    sesiones,
  };
}

export function progresoPlan(plan: Plan): number {
  if (plan.sesiones.length === 0) return 0;
  const hechas = plan.sesiones.filter((sesion) => sesion.hecho).length;
  return Math.round((hechas / plan.sesiones.length) * 100);
}

export function minutosTotales(plan: Plan): number {
  return plan.sesiones.reduce((total, sesion) => total + sesion.minutos, 0);
}

export function sesionDeHoy(plan: Plan): SesionPlan | undefined {
  const hoy = hoyClave();
  return plan.sesiones.find((sesion) => sesion.fecha === hoy && !sesion.hecho);
}

export function sesionesAtrasadas(plan: Plan): SesionPlan[] {
  const hoy = hoyClave();
  return plan.sesiones.filter((sesion) => !sesion.hecho && sesion.fecha < hoy);
}

/** Advertencia honesta cuando el plan no entra en los días disponibles. */
export function diagnosticoPlan(plan: Plan): string | null {
  const dias = plan.sesiones.length;
  if (dias === 0) return "La fecha límite ya pasó: elegí una fecha futura para armar el plan.";
  if (dias === 1) return "Queda un solo día. El plan es de emergencia: priorizá entender lo central, no todo.";
  if (dias <= 3) return "Quedan pocos días. El plan prioriza comprender y practicar antes que abarcar todo.";
  if (plan.minutosPorDia >= MINUTOS_MAXIMOS_POR_DIA) {
    return "Dos horas por día es el techo que sostiene la mayoría. Si un día no llegás, no rompiste el plan.";
  }
  return null;
}

export function hoyDeLaSemana(): number {
  return desdeClave(claveFecha(new Date())).getDay();
}

import { hoyClave, sumarDias } from "./fechas";
import type { EstadoEstudiar, EvidenciaDominio, LogEstudio, NivelDominio } from "./tipos";

export const COLORES_DOMINIO: Record<NivelDominio, { etiqueta: string; punto: string; fondo: string; borde: string; texto: string }> = {
  "sin-datos": {
    etiqueta: "Sin datos todavía",
    punto: "bg-slate-300",
    fondo: "bg-slate-100",
    borde: "border-slate-200",
    texto: "text-slate-600",
  },
  rojo: {
    etiqueta: "Necesita trabajo",
    punto: "bg-rose-500",
    fondo: "bg-rose-50",
    borde: "border-rose-200",
    texto: "text-rose-700",
  },
  amarillo: {
    etiqueta: "En construcción",
    punto: "bg-amber-400",
    fondo: "bg-amber-50",
    borde: "border-amber-200",
    texto: "text-amber-700",
  },
  verde: {
    etiqueta: "Lo tenés firme",
    punto: "bg-emerald-500",
    fondo: "bg-emerald-50",
    borde: "border-emerald-200",
    texto: "text-emerald-700",
  },
};

export function porcentajeDominio(evidencia: EvidenciaDominio | undefined): number | null {
  if (!evidencia || evidencia.intentos === 0) return null;
  return Math.round((evidencia.aciertos / evidencia.intentos) * 100);
}

export function nivelDominio(evidencia: EvidenciaDominio | undefined): NivelDominio {
  const porcentaje = porcentajeDominio(evidencia);
  if (porcentaje === null) return "sin-datos";
  if (porcentaje >= 80) return "verde";
  if (porcentaje >= 50) return "amarillo";
  return "rojo";
}

export interface Constancia {
  rachaActual: number;
  mejorRacha: number;
  diasActivos30: number;
  minutos7: number;
  minutosTotales: number;
  mapaCalor: { fecha: string; minutos: number }[];
}

function minutosPorFecha(logs: LogEstudio[]): Map<string, number> {
  const mapa = new Map<string, number>();
  logs.forEach((log) => {
    mapa.set(log.fecha, (mapa.get(log.fecha) ?? 0) + Math.max(0, log.minutos));
  });
  return mapa;
}

export function calcularConstancia(logs: LogEstudio[], dias = 56): Constancia {
  const porFecha = minutosPorFecha(logs);
  const hoy = hoyClave();
  const mapaCalor: { fecha: string; minutos: number }[] = [];

  for (let offset = dias - 1; offset >= 0; offset -= 1) {
    const fecha = sumarDias(hoy, -offset);
    mapaCalor.push({ fecha, minutos: porFecha.get(fecha) ?? 0 });
  }

  let rachaActual = 0;
  for (let offset = 0; offset < dias; offset += 1) {
    const fecha = sumarDias(hoy, -offset);
    const minutos = porFecha.get(fecha) ?? 0;
    if (minutos > 0) rachaActual += 1;
    else if (offset > 0) break;
    else if (offset === 0) continue; // todavía puede estudiar hoy
  }

  let mejorRacha = 0;
  let corriendo = 0;
  mapaCalor.forEach((dia) => {
    if (dia.minutos > 0) {
      corriendo += 1;
      mejorRacha = Math.max(mejorRacha, corriendo);
    } else {
      corriendo = 0;
    }
  });

  const ultimos30 = mapaCalor.slice(-30);
  const ultimos7 = mapaCalor.slice(-7);

  return {
    rachaActual,
    mejorRacha,
    diasActivos30: ultimos30.filter((dia) => dia.minutos > 0).length,
    minutos7: ultimos7.reduce((total, dia) => total + dia.minutos, 0),
    minutosTotales: logs.reduce((total, log) => total + Math.max(0, log.minutos), 0),
    mapaCalor,
  };
}

export interface ResumenProceso {
  preguntasTrabajadas: number;
  explicaciones: number;
  simulacros: number;
  erroresAbiertos: number;
  erroresResueltos: number;
  sesionesCumplidas: number;
  sesionesPlanificadas: number;
  temasFirmes: number;
  temasEnRevision: number;
}

export function resumenProceso(estado: EstadoEstudiar): ResumenProceso {
  const sesiones = estado.planes.flatMap((plan) => plan.sesiones);
  const niveles = estado.temas.map((tema) => nivelDominio(estado.dominio[tema.id]));

  return {
    preguntasTrabajadas: estado.tarjetas.reduce(
      (total, tarjeta) => total + tarjeta.repaso.aciertos + tarjeta.repaso.fallos,
      0,
    ),
    explicaciones: estado.explicaciones.length,
    simulacros: estado.simulacros.length,
    erroresAbiertos: estado.errores.filter((error) => !error.resuelto).length,
    erroresResueltos: estado.errores.filter((error) => error.resuelto).length,
    sesionesCumplidas: sesiones.filter((sesion) => sesion.hecho).length,
    sesionesPlanificadas: sesiones.length,
    temasFirmes: niveles.filter((nivel) => nivel === "verde").length,
    temasEnRevision: niveles.filter((nivel) => nivel === "rojo" || nivel === "amarillo").length,
  };
}

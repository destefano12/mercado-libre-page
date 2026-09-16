import type { NombreIcono } from "./iconos";

export type SeccionId =
  | "inicio"
  | "manifiesto"
  | "planificador"
  | "tutor"
  | "explicame"
  | "mapa"
  | "errores"
  | "grupos"
  | "agenda"
  | "pomodoro"
  | "simulador"
  | "adultos";

export interface Seccion {
  id: SeccionId;
  nombre: string;
  icono: NombreIcono;
  descripcion: string;
}

export interface GrupoSecciones {
  titulo: string;
  secciones: Seccion[];
}

/** La navegación se agrupa por momento de uso, no por orden de construcción. */
export const GRUPOS: GrupoSecciones[] = [
  {
    titulo: "Tu día",
    secciones: [
      { id: "inicio", nombre: "Hoy", icono: "hoy", descripcion: "Tu día de un vistazo" },
      { id: "agenda", nombre: "Agenda", icono: "agenda", descripcion: "Entregas, exámenes y sesiones" },
      { id: "pomodoro", nombre: "Pomodoro", icono: "pomodoro", descripcion: "Enfoque con descansos" },
    ],
  },
  {
    titulo: "Estudiar",
    secciones: [
      { id: "planificador", nombre: "Planificador", icono: "planificador", descripcion: "Plan diario hasta la fecha límite" },
      { id: "tutor", nombre: "Tutor socrático", icono: "tutor", descripcion: "Preguntas desde tu material" },
      { id: "explicame", nombre: "Explicámelo vos", icono: "explicame", descripcion: "Los huecos de tu razonamiento" },
      { id: "simulador", nombre: "Simulacro", icono: "simulador", descripcion: "Prueba cronometrada y corregida" },
    ],
  },
  {
    titulo: "Tu progreso",
    secciones: [
      { id: "mapa", nombre: "Mapa de dominio", icono: "mapa", descripcion: "Semáforo por tema" },
      { id: "errores", nombre: "Errores frecuentes", icono: "errores", descripcion: "Los que se repiten vuelven" },
      { id: "grupos", nombre: "Trabajos grupales", icono: "grupos", descripcion: "Reparto y avance por integrante" },
      { id: "adultos", nombre: "Familias y docentes", icono: "adultos", descripcion: "Constancia y proceso, nunca notas" },
    ],
  },
  {
    titulo: "La regla de la casa",
    secciones: [{ id: "manifiesto", nombre: "Manifiesto", icono: "manifiesto", descripcion: "El principio inviolable" }],
  },
];

export const SECCIONES: Seccion[] = GRUPOS.flatMap((grupo) => grupo.secciones);

export function buscarSeccion(id: SeccionId): Seccion {
  return SECCIONES.find((seccion) => seccion.id === id) ?? SECCIONES[0];
}

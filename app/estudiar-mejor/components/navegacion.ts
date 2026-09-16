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
  icono: string;
  descripcion: string;
}

export const SECCIONES: Seccion[] = [
  { id: "inicio", nombre: "Hoy", icono: "🏠", descripcion: "Tu día de un vistazo" },
  { id: "manifiesto", nombre: "Manifiesto", icono: "🛡️", descripcion: "El principio inviolable" },
  { id: "planificador", nombre: "Planificador", icono: "🗓️", descripcion: "Plan diario hasta la fecha límite" },
  { id: "tutor", nombre: "Tutor socrático", icono: "🧠", descripcion: "Preguntas desde tu material" },
  { id: "explicame", nombre: "Explicámelo vos", icono: "🗣️", descripcion: "Huecos de tu razonamiento" },
  { id: "mapa", nombre: "Mapa de dominio", icono: "🚦", descripcion: "Semáforo por tema" },
  { id: "errores", nombre: "Errores", icono: "🧾", descripcion: "Los que se repiten vuelven" },
  { id: "grupos", nombre: "Trabajos grupales", icono: "👥", descripcion: "Reparto y avance por integrante" },
  { id: "agenda", nombre: "Agenda", icono: "📅", descripcion: "Entregas, exámenes y sesiones" },
  { id: "pomodoro", nombre: "Pomodoro", icono: "🍅", descripcion: "Enfoque con descansos" },
  { id: "simulador", nombre: "Simulacro", icono: "⏱️", descripcion: "Prueba cronometrada y corregida" },
  { id: "adultos", nombre: "Familias y docentes", icono: "👩‍👦", descripcion: "Constancia y proceso, nunca notas" },
];

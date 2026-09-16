export type NivelDominio = "sin-datos" | "rojo" | "amarillo" | "verde";

export type EtapaPlan =
  | "reconocimiento"
  | "comprension"
  | "practica"
  | "repaso"
  | "simulacro";

export type TipoTarjeta =
  | "definicion"
  | "causa"
  | "proceso"
  | "dato"
  | "enumeracion"
  | "transferencia";

export type TipoItem = "multiple" | "vf" | "completar" | "desarrollo";

export type CausaError =
  | "no-entendi"
  | "distraccion"
  | "consigna"
  | "tiempo"
  | "calculo"
  | "memoria";

export interface Tema {
  id: string;
  nombre: string;
  materia: string;
  creadoEn: string;
}

export interface Material {
  id: string;
  temaId: string;
  titulo: string;
  texto: string;
  creadoEn: string;
}

export interface RepasoEspaciado {
  intervalo: number;
  proxima: string;
  facilidad: number;
  aciertos: number;
  fallos: number;
  ultimaVez?: string;
}

export interface TarjetaTutor {
  id: string;
  temaId: string;
  materialId: string;
  tipo: TipoTarjeta;
  enunciado: string;
  foco: string;
  pistas: string[];
  clave: string[];
  creadaEn: string;
  repaso: RepasoEspaciado;
  origenError?: string;
}

export interface SesionPlan {
  id: string;
  fecha: string;
  etapa: EtapaPlan;
  objetivo: string;
  minutos: number;
  hecho: boolean;
  completadaEn?: string;
}

export interface Plan {
  id: string;
  temaId: string;
  titulo: string;
  fechaLimite: string;
  minutosPorDia: number;
  diasSemana: number[];
  creadoEn: string;
  sesiones: SesionPlan[];
}

export interface RegistroError {
  id: string;
  temaId: string;
  titulo: string;
  detalle: string;
  causa: CausaError;
  origen: "simulacro" | "tutor" | "explicacion" | "manual";
  veces: number;
  resuelto: boolean;
  creadoEn: string;
  ultimaVez: string;
}

export interface TareaGrupo {
  id: string;
  titulo: string;
  hecho: boolean;
}

export interface Integrante {
  id: string;
  nombre: string;
  rol: string;
  esYo: boolean;
  tareas: TareaGrupo[];
}

export interface Grupo {
  id: string;
  nombre: string;
  materia: string;
  entrega: string;
  creadoEn: string;
  integrantes: Integrante[];
}

export interface EventoAgenda {
  id: string;
  tipo: "entrega" | "examen" | "sesion";
  titulo: string;
  fecha: string;
  temaId?: string;
  nota?: string;
  hecho: boolean;
}

export interface LogEstudio {
  id: string;
  fecha: string;
  minutos: number;
  tipo: "pomodoro" | "plan" | "tutor" | "explicacion" | "simulacro";
  temaId?: string;
}

export interface HuecoRazonamiento {
  id: string;
  titulo: string;
  pregunta: string;
  gravedad: "alta" | "media" | "baja";
}

export interface Explicacion {
  id: string;
  temaId: string;
  texto: string;
  creadaEn: string;
  cobertura: number;
  ideasFaltantes: number;
  huecos: HuecoRazonamiento[];
}

export interface OpcionItem {
  id: string;
  texto: string;
}

export interface ItemSimulacro {
  id: string;
  tipo: TipoItem;
  foco: string;
  enunciado: string;
  opciones?: OpcionItem[];
  correcta?: string;
  esperado?: string[];
  referencia: string;
  criterios?: string[];
}

export interface RespuestaItem {
  itemId: string;
  valor: string;
  criteriosMarcados?: string[];
  correcta: boolean;
  puntaje: number;
}

export interface Simulacro {
  id: string;
  temaId: string;
  creadoEn: string;
  duracionMin: number;
  usadoSeg: number;
  items: ItemSimulacro[];
  respuestas: RespuestaItem[];
  correctas: number;
  total: number;
}

export interface EvidenciaDominio {
  aciertos: number;
  intentos: number;
  actualizado: string;
}

export interface EstadoEstudiar {
  version: number;
  nombre: string;
  temas: Tema[];
  materiales: Material[];
  planes: Plan[];
  tarjetas: TarjetaTutor[];
  errores: RegistroError[];
  grupos: Grupo[];
  agenda: EventoAgenda[];
  logs: LogEstudio[];
  explicaciones: Explicacion[];
  simulacros: Simulacro[];
  dominio: Record<string, EvidenciaDominio>;
  pomodoro: {
    enfoque: number;
    descansoCorto: number;
    descansoLargo: number;
    ciclosHoy: number;
    fechaCiclos: string;
  };
  manifiestoAceptado: boolean;
}

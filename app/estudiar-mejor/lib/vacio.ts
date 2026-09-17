import type { EstadoEstudiar } from "./tipos";

/** Estado limpio. Vive aparte del store para que los datos de ejemplo puedan reusarlo. */
export function estadoInicialVacio(): EstadoEstudiar {
  return {
    version: 1,
    nombre: "",
    anio: 0,
    temas: [],
    materiales: [],
    planes: [],
    tarjetas: [],
    errores: [],
    grupos: [],
    agenda: [],
    logs: [],
    explicaciones: [],
    simulacros: [],
    dominio: {},
    pomodoro: {
      enfoque: 25,
      descansoCorto: 5,
      descansoLargo: 15,
      ciclosHoy: 0,
      fechaCiclos: "",
    },
    manifiestoAceptado: false,
  };
}

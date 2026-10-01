import type { ClaseHorario, EventoAgenda } from "./tipos";

/**
 * El horario de clases, que sirve para la pregunta de todas las noches: qué
 * tengo mañana y qué me tengo que llevar. Se carga una vez y después contesta
 * solo, cruzándose con la agenda para avisar lo que hay que entregar.
 */

export const DIAS = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"] as const;

/**
 * Lo que se lleva, sugerido por materia: se puede cambiar a mano.
 *
 * El orden importa y es por lo específico primero: "Educación Física" contiene
 * "física", y si gana la regla de Física te manda al colegio con la tabla
 * periódica en vez de con las zapatillas.
 */
const COSAS_POR_MATERIA: { busca: RegExp; lleva: string[] }[] = [
  { busca: /educaci[oó]n f[ií]sica|deporte|gimnasia/i, lleva: ["Ropa deportiva", "Botella de agua", "Toalla"] },
  { busca: /matem|algebra|geometr/i, lleva: ["Carpeta", "Calculadora", "Regla y compás"] },
  { busca: /f[ií]sica|qu[ií]mica/i, lleva: ["Carpeta", "Calculadora", "Tabla periódica"] },
  { busca: /lengua|literatura|pr[aá]cticas del lenguaje/i, lleva: ["Carpeta", "El libro de lectura"] },
  { busca: /ingl[eé]s|portugu[eé]s|franc[eé]s/i, lleva: ["Carpeta", "Diccionario o la app"] },
  { busca: /arte|pl[aá]stica|dibujo/i, lleva: ["Block", "Lápices", "Goma"] },
  { busca: /m[uú]sica/i, lleva: ["Carpeta", "Flauta o el instrumento"] },
  { busca: /inform[aá]tica|tecnolog/i, lleva: ["Carpeta", "Pendrive o la notebook"] },
  { busca: /biolog|naturales/i, lleva: ["Carpeta", "Guardapolvo para el laboratorio"] },
];

export function cosasSugeridas(materia: string): string[] {
  return COSAS_POR_MATERIA.find((fila) => fila.busca.test(materia))?.lleva ?? ["Carpeta"];
}

export interface DiaDeClase {
  dia: number;
  nombre: string;
  clases: ClaseHorario[];
  /** Todo lo que hay que llevar ese día, sin repetir. */
  lleva: string[];
  eventos: EventoAgenda[];
}

function fechaDe(desplazamiento: number): { clave: string; dia: number } {
  const fecha = new Date();
  fecha.setHours(0, 0, 0, 0);
  fecha.setDate(fecha.getDate() + desplazamiento);
  const mes = `${fecha.getMonth() + 1}`.padStart(2, "0");
  const dia = `${fecha.getDate()}`.padStart(2, "0");
  return { clave: `${fecha.getFullYear()}-${mes}-${dia}`, dia: fecha.getDay() };
}

/** Lo de hoy o lo de mañana, ya ordenado y con las entregas de ese día. */
export function armarDia(
  desplazamiento: 0 | 1,
  horario: ClaseHorario[],
  agenda: EventoAgenda[],
): DiaDeClase {
  const { clave, dia } = fechaDe(desplazamiento);
  const clases = horario.filter((clase) => clase.dia === dia).sort((a, b) => a.orden - b.orden);

  const lleva: string[] = [];
  clases.forEach((clase) => {
    clase.lleva.forEach((cosa) => {
      const limpia = cosa.trim();
      if (limpia && !lleva.some((puesta) => puesta.toLowerCase() === limpia.toLowerCase())) {
        lleva.push(limpia);
      }
    });
  });

  return {
    dia,
    nombre: DIAS[dia],
    clases,
    lleva,
    eventos: agenda.filter((evento) => evento.fecha === clave && !evento.hecho),
  };
}

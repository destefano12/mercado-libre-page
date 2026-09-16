import { hoyClave, sumarDias } from "./fechas";
import { crearId } from "./id";
import { generarPlan } from "./plan";
import { estadoInicialVacio } from "./vacio";
import { generarTarjetas } from "./tutor";
import type { EstadoEstudiar, Material } from "./tipos";

const TEXTO_FOTOSINTESIS = `La fotosíntesis es el proceso por el cual las plantas, las algas y algunas bacterias transforman la energía de la luz en energía química almacenada en forma de glucosa. Ocurre principalmente en los cloroplastos, organelas que contienen clorofila, el pigmento verde que captura la luz.
El proceso tiene dos etapas. Primero ocurre la fase luminosa, que se desarrolla en las membranas de los tilacoides: la luz rompe moléculas de agua y libera oxígeno, y se producen ATP y NADPH. Luego ocurre la fase oscura o ciclo de Calvin, que se desarrolla en el estroma y usa el ATP y el NADPH para fijar el dióxido de carbono y formar glucosa.
La ecuación general indica que 6 moléculas de dióxido de carbono y 6 de agua, en presencia de luz, producen 1 molécula de glucosa y 6 de oxígeno. La fotosíntesis es importante porque produce el oxígeno que respiramos y porque constituye la base de casi todas las cadenas alimentarias del planeta.
La intensidad de la fotosíntesis depende de tres factores: la cantidad de luz disponible, la concentración de dióxido de carbono y la temperatura. Si la temperatura sube demasiado, las enzimas se desnaturalizan y el proceso disminuye.`;

const TEXTO_REVOLUCION = `La Revolución Industrial fue el proceso de transformación económica y social que comenzó en Inglaterra a mediados del siglo XVIII y se extendió luego al resto de Europa. Consistió en el pasaje de una producción artesanal y rural a una producción mecanizada y fabril.
Comenzó en Inglaterra porque allí se combinaron varios factores: abundancia de carbón y hierro, capital acumulado por el comercio colonial, mano de obra disponible por los cambios en el campo y estabilidad política.
La máquina de vapor, perfeccionada por James Watt en 1769, permitió independizar las fábricas de los cursos de agua y fue el motor del cambio. Como resultado, las ciudades industriales crecieron muy rápido y aparecieron nuevos grupos sociales: la burguesía industrial y el proletariado.
Las condiciones de vida de los obreros eran muy duras: jornadas de catorce horas, trabajo infantil y viviendas hacinadas. Por eso surgieron las primeras organizaciones obreras, que reclamaban mejores salarios y menos horas de trabajo.`;

/** Datos de muestra para que la app se pueda recorrer sin cargar nada. */
export function estadoDeEjemplo(): EstadoEstudiar {
  const base = estadoInicialVacio();
  const hoy = hoyClave();

  const biologia = { id: crearId("tema"), nombre: "Fotosíntesis", materia: "Biología", creadoEn: new Date().toISOString() };
  const historia = { id: crearId("tema"), nombre: "Revolución Industrial", materia: "Historia", creadoEn: new Date().toISOString() };
  const matematica = { id: crearId("tema"), nombre: "Funciones cuadráticas", materia: "Matemática", creadoEn: new Date().toISOString() };

  const materiales: Material[] = [
    { id: crearId("material"), temaId: biologia.id, titulo: "Apunte de clase: fotosíntesis", texto: TEXTO_FOTOSINTESIS, creadoEn: new Date().toISOString() },
    { id: crearId("material"), temaId: historia.id, titulo: "Resumen del manual, capítulo 4", texto: TEXTO_REVOLUCION, creadoEn: new Date().toISOString() },
  ];

  const tarjetas = materiales.flatMap((material) => generarTarjetas(material));

  const plan = generarPlan({
    temaId: biologia.id,
    titulo: "Fotosíntesis",
    fechaLimite: sumarDias(hoy, 9),
    minutosPorDia: 40,
    diasSemana: [1, 2, 3, 4, 5],
  });

  plan.sesiones = plan.sesiones.map((sesion, indice) =>
    indice < 2 ? { ...sesion, hecho: true, completadaEn: new Date().toISOString() } : sesion,
  );

  return {
    ...base,
    nombre: "Sofi",
    manifiestoAceptado: true,
    temas: [biologia, historia, matematica],
    materiales,
    tarjetas,
    planes: [plan],
    dominio: {
      [biologia.id]: { aciertos: 14, intentos: 20, actualizado: hoy },
      [historia.id]: { aciertos: 5, intentos: 16, actualizado: sumarDias(hoy, -2) },
    },
    errores: [
      {
        id: crearId("error"),
        temaId: historia.id,
        titulo: "Confundo causas con consecuencias de la Revolución Industrial",
        detalle: "Puse el crecimiento de las ciudades como causa cuando es consecuencia.",
        causa: "no-entendi",
        origen: "simulacro",
        veces: 2,
        resuelto: false,
        creadoEn: sumarDias(hoy, -6),
        ultimaVez: sumarDias(hoy, -2),
      },
      {
        id: crearId("error"),
        temaId: biologia.id,
        titulo: "Mezclo fase luminosa con ciclo de Calvin",
        detalle: "Digo que el oxígeno se libera en el ciclo de Calvin.",
        causa: "memoria",
        origen: "tutor",
        veces: 3,
        resuelto: false,
        creadoEn: sumarDias(hoy, -8),
        ultimaVez: sumarDias(hoy, -1),
      },
      {
        id: crearId("error"),
        temaId: matematica.id,
        titulo: "Me olvido el signo al aplicar la fórmula resolvente",
        detalle: "Sobre todo cuando b es negativo.",
        causa: "calculo",
        origen: "manual",
        veces: 1,
        resuelto: true,
        creadoEn: sumarDias(hoy, -12),
        ultimaVez: sumarDias(hoy, -12),
      },
    ],
    grupos: [
      {
        id: crearId("grupo"),
        nombre: "Maqueta del ecosistema",
        materia: "Biología",
        entrega: sumarDias(hoy, 14),
        creadoEn: new Date().toISOString(),
        integrantes: [
          {
            id: crearId("integrante"),
            nombre: "Sofi",
            rol: "Coordinación",
            esYo: true,
            tareas: [
              { id: crearId("tarea"), titulo: "Armar el cronograma del grupo", hecho: true },
              { id: crearId("tarea"), titulo: "Revisar que todas las partes usen las mismas fuentes", hecho: false },
            ],
          },
          {
            id: crearId("integrante"),
            nombre: "Tomás",
            rol: "Investigación",
            esYo: false,
            tareas: [
              { id: crearId("tarea"), titulo: "Buscar 3 fuentes sobre cadenas alimentarias", hecho: true },
              { id: crearId("tarea"), titulo: "Fichar las fuentes", hecho: false },
            ],
          },
          {
            id: crearId("integrante"),
            nombre: "Juana",
            rol: "Armado",
            esYo: false,
            tareas: [{ id: crearId("tarea"), titulo: "Conseguir materiales de la maqueta", hecho: false }],
          },
        ],
      },
    ],
    agenda: [
      { id: crearId("evento"), tipo: "examen", titulo: "Prueba de Biología: fotosíntesis", fecha: sumarDias(hoy, 9), temaId: biologia.id, hecho: false },
      { id: crearId("evento"), tipo: "entrega", titulo: "Entrega de la maqueta", fecha: sumarDias(hoy, 14), hecho: false },
      { id: crearId("evento"), tipo: "sesion", titulo: "Repaso de Historia con Tomás", fecha: sumarDias(hoy, 3), temaId: historia.id, hecho: false },
    ],
    logs: [
      { id: crearId("log"), fecha: hoy, minutos: 25, tipo: "pomodoro", temaId: biologia.id },
      { id: crearId("log"), fecha: sumarDias(hoy, -1), minutos: 50, tipo: "plan", temaId: biologia.id },
      { id: crearId("log"), fecha: sumarDias(hoy, -2), minutos: 35, tipo: "simulacro", temaId: historia.id },
      { id: crearId("log"), fecha: sumarDias(hoy, -3), minutos: 25, tipo: "tutor", temaId: historia.id },
      { id: crearId("log"), fecha: sumarDias(hoy, -5), minutos: 40, tipo: "plan", temaId: biologia.id },
      { id: crearId("log"), fecha: sumarDias(hoy, -6), minutos: 20, tipo: "explicacion", temaId: biologia.id },
      { id: crearId("log"), fecha: sumarDias(hoy, -8), minutos: 45, tipo: "plan", temaId: historia.id },
      { id: crearId("log"), fecha: sumarDias(hoy, -9), minutos: 25, tipo: "pomodoro", temaId: matematica.id },
    ],
    pomodoro: { ...base.pomodoro, ciclosHoy: 1, fechaCiclos: hoy },
  };
}

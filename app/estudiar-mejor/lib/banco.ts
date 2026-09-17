/**
 * Banco de consignas por tema. La plataforma no consulta internet ni ningún
 * libro digital: todo corre en el navegador. Para que un pedido como
 * "preguntas de Historia sobre Grecia" devuelva consignas puntuales y no un
 * esquema genérico, los temas más frecuentes de secundaria vienen escritos acá.
 *
 * Son preguntas, nunca respuestas: el principio de la plataforma no cambia.
 */

import { normalizar } from "./texto";

export interface TemaBanco {
  nombre: string;
  materia: string;
  alias: string[];
  preguntas: string[];
}

export const BANCO: TemaBanco[] = [
  {
    nombre: "Grecia antigua",
    materia: "Historia",
    alias: ["grecia", "antigua grecia", "grecia antigua", "polis", "atenas", "esparta", "helenico", "helenistico"],
    preguntas: [
      "¿Qué es una polis y por qué las polis griegas se mantenían independientes entre sí, aunque compartían lengua, religión y costumbres?",
      "¿Qué formas de gobierno atravesó Atenas antes de llegar a la democracia? Ordenalas y explicá qué cambiaba en cada una.",
      "Compará el gobierno de Atenas con el de Esparta: nombrá al menos dos instituciones de cada una y decí quién tenía el poder real.",
      "En la democracia ateniense, ¿quiénes podían participar y quiénes quedaban excluidos? ¿Por qué esa exclusión era tan grande?",
      "¿Qué fueron las Guerras Médicas, contra quién se enfrentaron los griegos y cómo cambió la posición de Atenas después de ganarlas?",
      "¿Qué fue la Guerra del Peloponeso y por qué se dice que debilitó al conjunto del mundo griego?",
      "¿Qué función cumplían el ágora y el ejército en la vida cotidiana de un ciudadano griego?",
      "Nombrá tres aportes de la Grecia antigua que sigan presentes hoy y explicá en qué se nota cada uno.",
    ],
  },
  {
    nombre: "Roma antigua",
    materia: "Historia",
    alias: ["roma", "romano", "romana", "imperio romano", "republica romana", "antigua roma"],
    preguntas: [
      "Ordená las tres etapas de la historia romana y explicá qué distingue a cada una en cuanto a quién gobierna.",
      "¿Qué diferencia había entre patricios y plebeyos, y cómo fueron cambiando esas diferencias con el tiempo?",
      "¿Qué instituciones tenía la República romana y cómo se repartían el poder entre ellas?",
      "¿Por qué la República entró en crisis y qué papel cumplieron los ejércitos y sus generales en ese proceso?",
      "¿Cómo logró Roma administrar un territorio tan extenso? Nombrá al menos tres herramientas concretas.",
      "¿Qué causas se suelen señalar para explicar la caída del Imperio Romano de Occidente? Elegí dos y fundamentá cuál te parece más importante.",
      "¿Qué elementos del derecho romano siguen presentes en las leyes actuales?",
    ],
  },
  {
    nombre: "Edad Media y feudalismo",
    materia: "Historia",
    alias: ["edad media", "feudalismo", "feudal", "medieval", "señores feudales", "vasallaje"],
    preguntas: [
      "¿Qué es el feudalismo y qué relación unía al señor feudal con sus vasallos? Explicá qué daba cada uno.",
      "Describí la estructura social del feudalismo y ubicá en ella a los campesinos, la nobleza y el clero.",
      "¿Qué era un feudo y cómo se organizaba la producción dentro de él?",
      "¿Por qué la Iglesia tenía tanto poder en la Edad Media? Nombrá al menos dos motivos.",
      "¿Qué cambió con el resurgimiento de las ciudades y del comercio hacia el final de la Edad Media?",
      "¿Por qué se discute la idea de que la Edad Media fue una época totalmente oscura y sin avances?",
      "Compará la vida de un campesino con la de un señor feudal en cuanto a trabajo, obligaciones y derechos.",
    ],
  },
  {
    nombre: "Revolución Francesa",
    materia: "Historia",
    alias: ["revolucion francesa", "1789", "bastilla", "robespierre", "antiguo regimen"],
    preguntas: [
      "¿Cómo se organizaba la sociedad del Antiguo Régimen y por qué el Tercer Estado estaba en desventaja?",
      "Separá las causas económicas de las causas políticas de la Revolución. ¿Cuál te parece que pesó más y por qué?",
      "¿Qué ideas de la Ilustración influyeron en la Revolución y cómo se ven reflejadas en sus documentos?",
      "¿Qué proclama la Declaración de los Derechos del Hombre y del Ciudadano, y a quiénes dejaba afuera?",
      "Ordená cronológicamente las etapas de la Revolución y explicá qué caracteriza a cada una.",
      "¿Qué fue el Terror y cómo se justificó en su momento?",
      "¿Qué consecuencias de la Revolución Francesa llegan hasta la organización política actual?",
    ],
  },
  {
    nombre: "Revolución Industrial",
    materia: "Historia",
    alias: ["revolucion industrial", "industrializacion", "maquina de vapor", "obreros"],
    preguntas: [
      "¿Por qué la Revolución Industrial comenzó en Inglaterra? Nombrá al menos tres factores que se combinaron allí.",
      "¿Qué cambió en la forma de producir al pasar del taller artesanal a la fábrica?",
      "¿Qué papel cumplió la máquina de vapor y por qué se la considera el motor del proceso?",
      "Distinguí las causas de las consecuencias de la Revolución Industrial: escribí dos de cada una y justificá por qué las ubicás ahí.",
      "¿Qué nuevos grupos sociales aparecieron y qué relación había entre ellos?",
      "¿Cómo eran las condiciones de vida y de trabajo de los obreros, y qué respuestas organizadas surgieron frente a eso?",
      "¿Qué relación hay entre la Revolución Industrial y el crecimiento acelerado de las ciudades?",
    ],
  },
  {
    nombre: "Revolución de Mayo e independencia argentina",
    materia: "Historia",
    alias: ["revolucion de mayo", "1810", "1816", "independencia argentina", "san martin", "virreinato"],
    preguntas: [
      "¿Qué situación en España precipitó los hechos de mayo de 1810 en Buenos Aires?",
      "¿Qué causas internas del Virreinato venían acumulándose antes de 1810? Nombrá al menos dos.",
      "¿Qué se discutió en el Cabildo Abierto del 22 de mayo y qué posiciones se enfrentaron?",
      "¿Por qué entre 1810 y 1816 pasaron seis años hasta la declaración de la independencia?",
      "¿Qué proyectos de país se enfrentaban entre unitarios y federales, y en qué se diferenciaban concretamente?",
      "Explicá la estrategia de San Martín para llegar al Perú y por qué eligió ese camino.",
      "¿Qué cambió y qué siguió igual en la vida de la mayoría de la población después de la independencia?",
    ],
  },
  {
    nombre: "Primera Guerra Mundial",
    materia: "Historia",
    alias: ["primera guerra", "gran guerra", "1914", "primera guerra mundial"],
    preguntas: [
      "Explicá las causas profundas de la Primera Guerra Mundial y diferencialas del hecho puntual que la desencadenó.",
      "¿Qué alianzas se enfrentaron y por qué un conflicto entre dos países terminó arrastrando a casi toda Europa?",
      "¿Qué fue la guerra de trincheras y por qué el conflicto se estancó durante años?",
      "¿Qué novedades tecnológicas se usaron y cómo cambiaron la forma de combatir?",
      "¿Qué papel cumplió la población civil y la economía de cada país durante la guerra?",
      "¿Qué estableció el Tratado de Versalles y por qué se afirma que contenía las semillas de un conflicto posterior?",
      "¿Qué mapas políticos cambiaron al terminar la guerra? Nombrá al menos dos imperios que desaparecieron.",
    ],
  },
  {
    nombre: "Segunda Guerra Mundial",
    materia: "Historia",
    alias: ["segunda guerra", "1939", "segunda guerra mundial", "nazismo", "hitler", "holocausto"],
    preguntas: [
      "¿Qué condiciones de la posguerra de 1918 favorecieron el ascenso de los regímenes totalitarios?",
      "¿Qué características definen a un régimen totalitario? Nombrá al menos cuatro y ejemplificá.",
      "¿Cómo llegó el nazismo al poder en Alemania y por qué contó con apoyo social?",
      "Ordená las etapas principales de la guerra e identificá en qué momento cambia la ventaja de bando.",
      "¿Qué fue el Holocausto y por qué se lo estudia como algo distinto de las bajas militares de la guerra?",
      "¿Qué papel tuvo la entrada de Estados Unidos y de la Unión Soviética en el desenlace?",
      "¿Qué organismos e ideas surgieron después de 1945 para evitar que algo así se repitiera?",
    ],
  },
  {
    nombre: "Guerra Fría",
    materia: "Historia",
    alias: ["guerra fria", "bipolar", "muro de berlin", "urss"],
    preguntas: [
      "¿Por qué se la llama Guerra Fría si los dos bloques nunca se enfrentaron directamente?",
      "Compará el modelo capitalista y el socialista en cuanto a economía, política y sociedad.",
      "¿Qué fue la carrera armamentística y qué lógica la sostenía?",
      "Nombrá dos conflictos donde la tensión entre bloques se volvió guerra real y explicá uno.",
      "¿Qué representó el Muro de Berlín y qué significó su caída?",
      "¿Cómo repercutió la Guerra Fría en América Latina? Dé un ejemplo concreto.",
      "¿Qué quedó del orden mundial de la Guerra Fría después de 1991?",
    ],
  },
  {
    nombre: "Peronismo",
    materia: "Historia",
    alias: ["peronismo", "peron", "17 de octubre", "evita", "justicialismo"],
    preguntas: [
      "¿Qué situación social y económica de la Argentina explica el surgimiento del peronismo?",
      "¿Qué ocurrió el 17 de octubre de 1945 y por qué es una fecha central de ese proceso?",
      "Nombrá tres medidas concretas del primer gobierno peronista y explicá a quién beneficiaba cada una.",
      "¿Qué derechos laborales se consolidaron en ese período?",
      "¿Qué papel tuvo Eva Perón y qué transformación impulsó respecto del voto?",
      "¿Qué sectores se opusieron al peronismo y con qué argumentos?",
      "¿Por qué el peronismo sigue siendo un tema discutido en la Argentina actual?",
    ],
  },
  {
    nombre: "Conquista y colonización de América",
    materia: "Historia",
    alias: ["conquista de america", "colonizacion", "colonial", "descubrimiento de america", "1492", "aztecas", "incas"],
    preguntas: [
      "¿Qué motivos económicos y políticos empujaron a los reinos europeos a buscar nuevas rutas comerciales?",
      "¿Cómo era la organización de los grandes imperios americanos antes de la llegada de los europeos?",
      "¿Por qué un número reducido de conquistadores pudo vencer a imperios enormes? Nombrá al menos tres factores.",
      "¿Qué fueron la encomienda y la mita, y cómo afectaron a la población originaria?",
      "¿Qué consecuencias demográficas tuvo la conquista y a qué se debieron principalmente?",
      "¿Qué se intercambió entre América y Europa, en productos, enfermedades y costumbres?",
      "¿Por qué la palabra “descubrimiento” es discutida para nombrar lo que ocurrió en 1492?",
    ],
  },
  {
    nombre: "La célula",
    materia: "Biología",
    alias: ["celula", "celulas", "organelas", "membrana celular", "mitosis"],
    preguntas: [
      "¿Qué diferencia a una célula procariota de una eucariota? Nombrá al menos tres diferencias.",
      "Compará la célula animal con la vegetal: ¿qué estructuras tiene una que la otra no?",
      "¿Qué función cumple la membrana celular y por qué se la llama selectivamente permeable?",
      "Relacioná cada organela con su función: núcleo, mitocondria, cloroplasto, ribosoma y vacuola.",
      "¿Por qué se dice que la mitocondria es la central de energía de la célula?",
      "¿Para qué se divide una célula y qué diferencia hay entre mitosis y meiosis?",
      "Si una célula perdiera su núcleo, ¿qué funciones dejaría de poder cumplir y por qué?",
    ],
  },
  {
    nombre: "Fotosíntesis",
    materia: "Biología",
    alias: ["fotosintesis", "clorofila", "cloroplasto", "ciclo de calvin"],
    preguntas: [
      "Escribí la ecuación general de la fotosíntesis e identificá qué entra y qué sale del proceso.",
      "¿En qué parte de la célula ocurre la fotosíntesis y qué pigmento hace posible captar la luz?",
      "Diferenciá la fase luminosa de la fase oscura: dónde ocurre cada una, qué necesita y qué produce.",
      "¿De dónde proviene el oxígeno que libera la planta? Justificá tu respuesta.",
      "¿Qué factores modifican la intensidad de la fotosíntesis y qué pasa si la temperatura sube demasiado?",
      "¿Qué relación hay entre fotosíntesis y respiración celular? ¿Son procesos opuestos o complementarios?",
      "¿Por qué se afirma que la fotosíntesis sostiene casi todas las cadenas alimentarias del planeta?",
    ],
  },
  {
    nombre: "Genética y leyes de Mendel",
    materia: "Biología",
    alias: ["genetica", "mendel", "herencia", "adn", "genes", "cromosomas", "dominante", "recesivo"],
    preguntas: [
      "Diferenciá gen, alelo, genotipo y fenotipo con un ejemplo concreto.",
      "¿Qué significa que un alelo sea dominante y otro recesivo? ¿Cómo se nota en el individuo?",
      "Enunciá las leyes de Mendel y explicá qué afirma cada una con tus palabras.",
      "Resolvé un cruzamiento entre dos individuos heterocigotas y explicá la proporción que obtenés.",
      "¿Qué función cumple el ADN y cómo se relaciona con los cromosomas?",
      "¿Por qué los hijos se parecen a los padres pero no son idénticos a ninguno?",
      "¿Qué es una mutación y por qué no siempre es perjudicial?",
    ],
  },
  {
    nombre: "Evolución y selección natural",
    materia: "Biología",
    alias: ["evolucion", "darwin", "seleccion natural", "adaptacion", "especies"],
    preguntas: [
      "¿Qué propone la teoría de la selección natural? Explicala en tres pasos.",
      "Diferenciá la explicación de Lamarck de la de Darwin usando un mismo ejemplo.",
      "¿Qué es una adaptación y por qué no es algo que el individuo decida desarrollar?",
      "¿Qué pruebas sostienen la evolución? Nombrá al menos tres tipos distintos de evidencia.",
      "¿Cómo se forma una especie nueva a partir de otra?",
      "¿Por qué la frase “el más fuerte sobrevive” es una simplificación incorrecta de la teoría?",
      "Explicá con un ejemplo actual cómo la selección natural sigue operando hoy.",
    ],
  },
  {
    nombre: "Ecosistemas y cadenas alimentarias",
    materia: "Biología",
    alias: ["ecosistema", "ecosistemas", "cadena alimentaria", "ecologia", "productores", "biodiversidad"],
    preguntas: [
      "¿Qué componentes bióticos y abióticos forman un ecosistema? Dé ejemplos de cada uno.",
      "Diferenciá productores, consumidores y descomponedores, y explicá qué pasaría si faltara uno de esos grupos.",
      "Armá una cadena alimentaria de tu zona con al menos cuatro eslabones y justificá el orden.",
      "¿Por qué la energía disponible disminuye a medida que se sube de nivel trófico?",
      "¿Qué diferencia hay entre una cadena y una red alimentaria?",
      "¿Cómo repercute la extinción de una sola especie en el resto del ecosistema?",
      "¿Qué actividades humanas alteran los ecosistemas y de qué manera concreta lo hacen?",
    ],
  },
  {
    nombre: "Sistema digestivo",
    materia: "Biología",
    alias: ["sistema digestivo", "digestivo", "digestion", "estomago", "intestino"],
    preguntas: [
      "Ordená el recorrido que hace un alimento desde la boca hasta su eliminación, nombrando cada órgano.",
      "Diferenciá digestión mecánica de digestión química y dé un ejemplo de cada una.",
      "¿Qué función cumplen las enzimas digestivas y por qué el proceso no podría ocurrir sin ellas?",
      "¿Qué papel cumplen el hígado y el páncreas, si los alimentos no pasan por ellos?",
      "¿Dónde ocurre la absorción de nutrientes y qué características del órgano la favorecen?",
      "¿Qué le pasaría al organismo si el intestino grueso no reabsorbiera agua?",
      "Relacioná una alimentación desequilibrada con problemas concretos del sistema digestivo.",
    ],
  },
  {
    nombre: "Tabla periódica",
    materia: "Química",
    alias: ["tabla periodica", "elementos quimicos", "grupos y periodos", "atomo"],
    preguntas: [
      "¿Con qué criterio están ordenados los elementos en la tabla periódica actual?",
      "¿Qué información comparten los elementos de un mismo grupo? ¿Y los de un mismo período?",
      "Diferenciá número atómico de número másico y explicá qué indica cada uno.",
      "¿Qué son los electrones de valencia y por qué determinan el comportamiento químico de un elemento?",
      "Ubicá metales, no metales y gases nobles en la tabla y explicá qué caracteriza a cada zona.",
      "¿Por qué los gases nobles casi no reaccionan con otros elementos?",
      "Elegí dos elementos de un mismo grupo y predecí en qué se van a parecer al reaccionar.",
    ],
  },
  {
    nombre: "Enlaces químicos",
    materia: "Química",
    alias: ["enlace quimico", "enlaces", "ionico", "covalente", "metalico"],
    preguntas: [
      "¿Por qué los átomos se unen entre sí en lugar de permanecer aislados?",
      "Diferenciá enlace iónico, covalente y metálico según cómo se comportan los electrones.",
      "¿Qué propiedades tiene un compuesto iónico y cómo se explican a partir de su enlace?",
      "¿Por qué la sal conduce electricidad disuelta en agua pero no en estado sólido?",
      "Explicá qué es un enlace covalente polar y dé un ejemplo.",
      "¿Cómo se relaciona la posición de dos elementos en la tabla periódica con el tipo de enlace que van a formar?",
      "Predecí qué tipo de enlace formarían un metal y un no metal, y justificá.",
    ],
  },
  {
    nombre: "Reacciones químicas",
    materia: "Química",
    alias: ["reaccion quimica", "reacciones", "ecuaciones quimicas", "estequiometria", "balanceo"],
    preguntas: [
      "¿Cómo se reconoce que ocurrió una reacción química y no sólo un cambio físico? Nombrá al menos tres señales.",
      "Diferenciá reactivos de productos e identificalos en una ecuación concreta.",
      "¿Qué enuncia la ley de conservación de la masa y por qué obliga a balancear las ecuaciones?",
      "Balanceá una ecuación y explicá paso a paso el criterio que seguiste.",
      "Clasificá los tipos de reacción que estudiaste y dé un ejemplo de cada uno.",
      "¿Qué factores modifican la velocidad de una reacción y por qué?",
      "¿Qué diferencia hay entre una reacción exotérmica y una endotérmica? Dé un ejemplo cotidiano de cada una.",
    ],
  },
  {
    nombre: "Leyes de Newton",
    materia: "Física",
    alias: ["newton", "leyes de newton", "dinamica", "fuerza", "fuerzas", "inercia"],
    preguntas: [
      "Enunciá las tres leyes de Newton con tus palabras y dé un ejemplo cotidiano de cada una.",
      "¿Qué es la inercia y por qué un pasajero se va hacia adelante cuando el colectivo frena?",
      "¿Qué relación establece la segunda ley entre fuerza, masa y aceleración? ¿Qué pasa si duplicás la masa?",
      "Si acción y reacción son iguales y opuestas, ¿por qué los objetos igual se mueven? Explicá el error del razonamiento.",
      "Diferenciá masa de peso y explicá por qué el peso cambia en la Luna y la masa no.",
      "Dibujá el diagrama de fuerzas de un cuerpo apoyado en una mesa y justificá cada flecha.",
      "¿Qué papel cumple el rozamiento y qué pasaría si desapareciera por completo?",
    ],
  },
  {
    nombre: "Cinemática y movimiento",
    materia: "Física",
    alias: ["cinematica", "movimiento", "mru", "mruv", "velocidad", "aceleracion"],
    preguntas: [
      "Diferenciá posición, distancia recorrida y desplazamiento con un ejemplo donde no coincidan.",
      "¿Qué distingue al movimiento rectilíneo uniforme del uniformemente variado?",
      "¿Qué significa que la velocidad sea negativa? ¿Y la aceleración?",
      "Interpretá qué información da la pendiente en un gráfico de posición en función del tiempo.",
      "Un cuerpo puede tener velocidad cero y aceleración distinta de cero: dé un ejemplo y explicalo.",
      "Escribí las ecuaciones del MRUV e indicá qué representa cada término.",
      "Resolvé un problema de caída libre y verificá si el resultado tiene sentido físico.",
    ],
  },
  {
    nombre: "Energía y trabajo",
    materia: "Física",
    alias: ["energia", "trabajo", "potencia", "energia cinetica", "energia potencial"],
    preguntas: [
      "¿Cuándo, en física, se dice que una fuerza realiza trabajo? ¿Sostener una mochila quieta es trabajo?",
      "Diferenciá energía cinética de energía potencial y dé un ejemplo donde una se transforme en la otra.",
      "Enunciá el principio de conservación de la energía y aplicalo a un objeto que cae.",
      "¿Qué diferencia hay entre trabajo y potencia? ¿Por qué dos personas pueden hacer el mismo trabajo con potencias distintas?",
      "¿A dónde va la energía que parece perderse por rozamiento?",
      "Analizá las transformaciones de energía en una montaña rusa desde el punto más alto hasta el más bajo.",
      "¿Por qué no existen las máquinas de movimiento perpetuo?",
    ],
  },
  {
    nombre: "Electricidad y circuitos",
    materia: "Física",
    alias: ["electricidad", "circuito", "circuitos", "corriente", "voltaje", "ley de ohm", "resistencia"],
    preguntas: [
      "Diferenciá corriente, tensión y resistencia, y explicá qué mide cada una.",
      "Enunciá la ley de Ohm y explicá qué le pasa a la corriente si aumenta la resistencia.",
      "Compará un circuito en serie con uno en paralelo: ¿qué ocurre si se quema una lámpara en cada caso?",
      "¿Por qué los artefactos de una casa se conectan en paralelo y no en serie?",
      "¿Qué es un cortocircuito y por qué resulta peligroso?",
      "¿Qué función cumplen los fusibles y las llaves térmicas?",
      "Calculá la potencia consumida por un artefacto y explicá cómo se traduce en la factura de luz.",
    ],
  },
  {
    nombre: "Funciones cuadráticas",
    materia: "Matemática",
    alias: ["funcion cuadratica", "cuadratica", "cuadraticas", "parabola", "segundo grado", "resolvente"],
    preguntas: [
      "¿Qué forma tiene la gráfica de una función cuadrática y qué determina si sus ramas van hacia arriba o hacia abajo?",
      "Identificá vértice, eje de simetría y raíces en una parábola, y explicá qué significa cada elemento.",
      "¿Qué información aporta el discriminante antes de resolver la ecuación?",
      "Resolvé una ecuación de segundo grado con la fórmula resolvente y verificá las soluciones reemplazando.",
      "Pasá una función de la forma general a la forma canónica y explicá para qué sirve cada una.",
      "¿Qué significa que una parábola no corte el eje x? ¿La ecuación tiene solución?",
      "Planteá una situación real que se modele con una función cuadrática y explicá qué representa el vértice en ese contexto.",
    ],
  },
  {
    nombre: "Funciones lineales",
    materia: "Matemática",
    alias: ["funcion lineal", "lineal", "lineales", "recta", "pendiente", "ordenada al origen"],
    preguntas: [
      "¿Qué representan la pendiente y la ordenada al origen en la fórmula de una recta?",
      "¿Cómo se nota en el gráfico que una función es creciente, decreciente o constante?",
      "Hallá la ecuación de la recta que pasa por dos puntos dados y explicá cada paso.",
      "¿Qué significa que dos rectas sean paralelas o perpendiculares, en términos de sus pendientes?",
      "Interpretá el punto de intersección entre dos rectas y qué representa al resolver un sistema.",
      "Planteá una situación cotidiana que se modele con una función lineal e identificá qué es la pendiente allí.",
      "¿Por qué una función lineal no sirve para modelar un crecimiento que se acelera?",
    ],
  },
  {
    nombre: "Teorema de Pitágoras",
    materia: "Matemática",
    alias: ["pitagoras", "teorema de pitagoras", "triangulo rectangulo", "hipotenusa"],
    preguntas: [
      "Enunciá el teorema de Pitágoras e identificá cuál es la hipotenusa y cuáles los catetos.",
      "¿Por qué el teorema sólo se aplica a triángulos rectángulos?",
      "Calculá un cateto conociendo la hipotenusa y el otro cateto, y explicá cómo despejaste.",
      "Verificá si un triángulo de lados dados es rectángulo y justificá tu conclusión.",
      "Resolvé un problema donde haya que hallar una distancia que no se puede medir directamente.",
      "¿Cómo se relaciona el teorema con el cálculo de la diagonal de un rectángulo?",
      "Dé un ejemplo de un oficio o actividad donde se use este teorema en la práctica.",
    ],
  },
  {
    nombre: "Trigonometría",
    materia: "Matemática",
    alias: ["trigonometria", "seno", "coseno", "tangente", "razones trigonometricas"],
    preguntas: [
      "Definí seno, coseno y tangente como razones entre lados de un triángulo rectángulo.",
      "¿Por qué esas razones no cambian aunque el triángulo sea más grande o más chico?",
      "¿Cuándo conviene usar cada razón? Explicá cómo elegís según los datos del problema.",
      "Hallá un ángulo conociendo dos lados y explicá qué función usaste y por qué.",
      "Resolvé un problema de altura inaccesible, como un edificio o un árbol.",
      "¿Qué relación hay entre el teorema de Pitágoras y las razones trigonométricas?",
      "¿Qué error se comete si se usa la calculadora en radianes cuando el problema está en grados?",
    ],
  },
  {
    nombre: "Probabilidad y estadística",
    materia: "Matemática",
    alias: ["probabilidad", "estadistica", "media", "promedio", "mediana", "moda", "frecuencia"],
    preguntas: [
      "Diferenciá media, mediana y moda, y explicá en qué situación conviene cada una.",
      "¿Por qué un solo valor extremo puede distorsionar el promedio? Dé un ejemplo con números.",
      "Definí probabilidad como relación entre casos favorables y posibles, y aplicala a un caso concreto.",
      "¿Qué diferencia hay entre sucesos independientes y dependientes? Dé un ejemplo de cada uno.",
      "Interpretá un gráfico de barras o una tabla de frecuencias y explicá qué conclusión permite sacar.",
      "¿Por qué una probabilidad nunca puede ser mayor que 1 ni menor que 0?",
      "Explicá por qué en un juego de azar los resultados anteriores no modifican la próxima tirada.",
    ],
  },
  {
    nombre: "Análisis sintáctico",
    materia: "Lengua",
    alias: ["sintaxis", "analisis sintactico", "oracion", "sujeto", "predicado", "modificadores"],
    preguntas: [
      "¿Cómo se reconoce el sujeto de una oración? Explicá el procedimiento que usás, no sólo el resultado.",
      "Diferenciá sujeto expreso, tácito y simple o compuesto, con un ejemplo de cada uno.",
      "Identificá el núcleo del predicado en una oración y explicá por qué es ese y no otro.",
      "Diferenciá objeto directo de objeto indirecto y explicá cómo los comprobás.",
      "¿Qué son los modificadores del sustantivo? Nombralos y ejemplificá.",
      "Analizá una oración compuesta e indicá cómo se relacionan sus proposiciones.",
      "¿Para qué sirve analizar sintácticamente, más allá de aprobar la materia?",
    ],
  },
  {
    nombre: "Texto argumentativo",
    materia: "Lengua",
    alias: ["texto argumentativo", "argumentacion", "argumentativo", "ensayo", "tesis"],
    preguntas: [
      "¿Cuál es el propósito de un texto argumentativo y en qué se diferencia de uno expositivo?",
      "Identificá las partes de un texto argumentativo y explicá qué función cumple cada una.",
      "¿Qué es una tesis y cómo se distingue de un simple tema?",
      "Nombrá tres tipos de argumento y escribí un ejemplo de cada uno sobre un mismo tema.",
      "¿Qué es una contraargumentación y por qué fortalece al texto en lugar de debilitarlo?",
      "¿Qué recursos lingüísticos ayudan a sostener una postura sin caer en la agresión?",
      "Tomá una opinión tuya y escribí la tesis en una sola oración, con dos argumentos que la sostengan.",
    ],
  },
  {
    nombre: "Géneros literarios",
    materia: "Literatura",
    alias: ["generos literarios", "genero narrativo", "lirico", "dramatico", "narrativa"],
    preguntas: [
      "Diferenciá los géneros narrativo, lírico y dramático según su forma y su intención.",
      "¿Qué elementos componen una narración? Nombrá al menos cinco y explicá su función.",
      "Diferenciá autor, narrador y personaje, y explicá por qué confundirlos cambia la interpretación.",
      "¿Qué tipos de narrador existen y cómo cambia el relato según cuál se elija?",
      "¿Qué caracteriza al género lírico y qué papel cumple el yo poético?",
      "¿Qué distingue a un texto dramático de una narración con diálogos?",
      "Elegí una obra que hayas leído y justificá a qué género pertenece con al menos dos rasgos.",
    ],
  },
  {
    nombre: "Figuras retóricas",
    materia: "Literatura",
    alias: ["figuras retoricas", "recursos literarios", "metafora", "comparacion", "personificacion"],
    preguntas: [
      "Diferenciá metáfora de comparación y explicá con un ejemplo propio de cada una.",
      "¿Qué es la personificación y qué efecto produce en quien lee?",
      "Reconocé la hipérbole en un ejemplo cotidiano y explicá para qué se usa.",
      "¿Qué aportan la aliteración y la repetición al ritmo de un poema?",
      "¿Qué es una metonimia y en qué se diferencia de la metáfora?",
      "Elegí un verso o una canción e identificá al menos dos figuras, explicando qué logra cada una.",
      "¿Por qué un texto no mejora sólo por acumular figuras retóricas?",
    ],
  },
  {
    nombre: "Constitución y división de poderes",
    materia: "Formación Ciudadana",
    alias: ["constitucion", "division de poderes", "poderes del estado", "republica", "ciudadania"],
    preguntas: [
      "¿Qué es una Constitución y por qué se la considera la norma suprema?",
      "Nombrá los tres poderes del Estado, quién los integra y qué función cumple cada uno.",
      "¿Qué significa que los poderes se controlen entre sí? Dé un ejemplo concreto.",
      "Diferenciá derechos de garantías y explicá para qué sirve la diferencia.",
      "¿Qué caracteriza a una república y en qué se distingue de otras formas de gobierno?",
      "¿Qué significa que el gobierno argentino sea representativo, republicano y federal?",
      "¿Por qué una Constitución puede reformarse, y qué requisitos se exigen para hacerlo?",
    ],
  },
  {
    nombre: "Derechos humanos",
    materia: "Formación Ciudadana",
    alias: ["derechos humanos", "ddhh", "declaracion universal"],
    preguntas: [
      "¿Qué características tienen los derechos humanos? Explicá qué significa que sean universales e inalienables.",
      "¿En qué contexto histórico se redactó la Declaración Universal de 1948 y por qué en ese momento?",
      "Diferenciá derechos civiles, políticos, sociales y culturales, con un ejemplo de cada uno.",
      "¿Qué obligaciones tiene el Estado frente a los derechos humanos? Nombrá al menos dos.",
      "¿Por qué se dice que los derechos humanos no se conceden sino que se reconocen?",
      "Identificá una situación actual donde algún derecho no se cumpla y explicá cuál.",
      "¿Qué relación hay entre derechos y responsabilidades en la vida cotidiana?",
    ],
  },
  {
    nombre: "Oferta y demanda",
    materia: "Economía",
    alias: ["oferta y demanda", "oferta", "demanda", "mercado", "precio"],
    preguntas: [
      "¿Qué establece la ley de la demanda y qué la explica?",
      "¿Qué establece la ley de la oferta y por qué actúa en sentido contrario a la demanda?",
      "¿Qué es el precio de equilibrio y qué pasa cuando el precio se fija por encima o por debajo?",
      "Nombrá tres factores, además del precio, que desplacen la demanda de un producto.",
      "Explicá con un ejemplo real cómo un aumento de la demanda afecta al precio.",
      "¿Qué significa que un bien tenga demanda elástica o inelástica? Dé un ejemplo de cada uno.",
      "¿Por qué el precio de las entradas de un recital sube cuando el artista es muy convocante?",
    ],
  },
  {
    nombre: "Inflación",
    materia: "Economía",
    alias: ["inflacion", "indice de precios", "poder adquisitivo"],
    preguntas: [
      "¿Qué es la inflación y por qué no alcanza con mirar el precio de un solo producto para medirla?",
      "¿Cómo se mide la inflación y qué representa una canasta de bienes?",
      "Nombrá tres causas posibles de inflación y explicá el mecanismo de cada una.",
      "¿Qué es el poder adquisitivo y cómo lo afecta la inflación si el sueldo no se actualiza?",
      "¿Por qué la inflación perjudica más a quienes tienen ingresos fijos?",
      "Diferenciá inflación de aumento de precios puntual, y de devaluación.",
      "¿Qué medidas suelen tomar los gobiernos frente a la inflación y qué costos tiene cada una?",
    ],
  },
];

/** Busca el tema pedido entre los del banco, por nombre o por sus alias. */
export function buscarEnBanco(pedido: string): TemaBanco | null {
  const plano = ` ${normalizar(pedido)} `;
  let mejor: TemaBanco | null = null;
  let largoMejor = 0;

  BANCO.forEach((tema) => {
    [tema.nombre, ...tema.alias].forEach((etiqueta) => {
      const clave = normalizar(etiqueta);
      if (clave.length < 4 || !plano.includes(clave)) return;
      // Gana la coincidencia más específica: "revolucion industrial" sobre "roma".
      if (clave.length > largoMejor) {
        largoMejor = clave.length;
        mejor = tema;
      }
    });
  });

  return mejor;
}

export const TEMAS_DISPONIBLES = BANCO.map((tema) => `${tema.materia}: ${tema.nombre}`);

/**
 * Nivel de exigencia de una consigna, deducido del verbo con que empieza.
 * 1 = reconocer y describir · 2 = relacionar y aplicar · 3 = analizar y fundamentar.
 * Se calcula en vez de anotarse a mano para que valga también para las
 * consignas que se generan a partir del material del alumno.
 */
export function nivelDePregunta(texto: string): 1 | 2 | 3 {
  const plano = normalizar(texto);

  const avanzado = [
    "justifica", "fundamenta", "predeci", "analiza", "por que se discute",
    "por que se dice", "por que se afirma", "que pasaria", "elegi",
    "plantea", "que error", "por que no", "discutida", "compara y",
    "cual te parece", "verifica si",
  ];
  const intermedio = [
    "compara", "explica por que", "por que", "relaciona", "calcula", "resolve",
    "aplica", "interpreta", "arma", "halla", "balancea", "identifica el",
    "que relacion", "como se", "que pasa si", "que diferencia hay",
  ];

  if (avanzado.some((marca) => plano.includes(marca))) return 3;
  if (intermedio.some((marca) => plano.includes(marca))) return 2;
  return 1;
}

/** Mezcla de niveles que le corresponde a cada año de la secundaria. */
export function mezclaPorAnio(anio: number): (1 | 2 | 3)[] {
  if (anio >= 5) return [3, 2, 3, 2, 3, 2, 1, 3];
  if (anio >= 3) return [1, 2, 2, 3, 2, 1, 3, 2];
  if (anio >= 1) return [1, 1, 2, 1, 2, 1, 2, 1];
  return [1, 2, 1, 2, 3, 1, 2, 3];
}

/**
 * Elige consignas del tema respetando el año del alumno: los primeros años
 * reciben más consignas de reconocer y describir, los últimos más de analizar.
 */
export function elegirPorNivel(preguntas: string[], anio: number, cantidad: number): string[] {
  const porNivel: Record<1 | 2 | 3, string[]> = { 1: [], 2: [], 3: [] };
  preguntas.forEach((pregunta) => porNivel[nivelDePregunta(pregunta)].push(pregunta));

  const elegidas: string[] = [];
  const usadas = new Set<string>();

  const tomar = (nivel: 1 | 2 | 3) => {
    const disponible = porNivel[nivel].find((pregunta) => !usadas.has(pregunta));
    if (!disponible) return false;
    usadas.add(disponible);
    elegidas.push(disponible);
    return true;
  };

  mezclaPorAnio(anio).forEach((nivel) => {
    if (elegidas.length >= cantidad) return;
    // Si no quedan de ese nivel, se busca en el más cercano.
    const orden: (1 | 2 | 3)[] = nivel === 1 ? [1, 2, 3] : nivel === 2 ? [2, 1, 3] : [3, 2, 1];
    orden.some(tomar);
  });

  // Relleno por si el tema tiene menos consignas que las pedidas.
  preguntas.forEach((pregunta) => {
    if (elegidas.length < cantidad && !usadas.has(pregunta)) {
      usadas.add(pregunta);
      elegidas.push(pregunta);
    }
  });

  return elegidas.slice(0, cantidad);
}

export function nombreDelAnio(anio: number): string {
  if (anio <= 0) return "tu curso";
  const ordinales = ["", "1.er", "2.º", "3.er", "4.º", "5.º", "6.º"];
  return `${ordinales[anio] ?? `${anio}.º`} año`;
}

"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { AvisoPrincipio, Boton, Dato, Deslizador, Selector, Tarjeta, TituloSeccion } from "../components/ui";
import { Icono, type NombreIcono } from "../components/iconos";
import { hoyClave, minutosLegibles, relojMmSs } from "../lib/fechas";
import { useEstudiar } from "../lib/store";

type Fase = "enfoque" | "corto" | "largo";

/** Duraciones de un toque, de un repaso corto a una sesión larga. */
const DURACIONES = [5, 10, 15, 25, 40, 60];

const TEXTOS: Record<Fase, { nombre: string; icono: NombreIcono; consejo: string; color: string }> = {
  enfoque: {
    nombre: "Enfoque",
    icono: "pomodoro" as const,
    consejo: "Celular boca abajo y fuera de la mesa. Si aparece una idea que no es del tema, anotala y seguí.",
    color: "text-acento",
  },
  corto: {
    nombre: "Descanso corto",
    icono: "check" as const,
    consejo: "Parate, tomá agua, mirá lejos. No abras redes: el cerebro no descansa scrolleando.",
    color: "text-logro",
  },
  largo: {
    nombre: "Descanso largo",
    icono: "reloj" as const,
    consejo: "Este descanso es en serio: caminá un poco o comé algo antes de volver.",
    color: "text-atencion",
  },
};

function sonarCampana() {
  if (typeof window === "undefined") return;
  try {
    const Contexto = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!Contexto) return;
    const contexto = new Contexto();
    const oscilador = contexto.createOscillator();
    const ganancia = contexto.createGain();
    oscilador.frequency.value = 660;
    oscilador.connect(ganancia);
    ganancia.connect(contexto.destination);
    ganancia.gain.setValueAtTime(0.14, contexto.currentTime);
    ganancia.gain.exponentialRampToValueAtTime(0.0001, contexto.currentTime + 0.9);
    oscilador.start();
    oscilador.stop(contexto.currentTime + 0.9);
    window.setTimeout(() => void contexto.close(), 1200);
  } catch {
    // Si el navegador bloquea el audio, el temporizador sigue funcionando igual.
  }
}

export function Pomodoro() {
  const { estado, acciones } = useEstudiar();
  const { pomodoro } = estado;

  const [fase, setFase] = useState<Fase>("enfoque");
  const [restante, setRestante] = useState(pomodoro.enfoque * 60);
  const [corriendo, setCorriendo] = useState(false);
  const [temaId, setTemaId] = useState("");
  const [aviso, setAviso] = useState<string | null>(null);
  // Instante en que termina la cuenta. Se calcula contra el reloj del sistema
  // para que el tiempo siga corriendo aunque la pestaña quede en segundo plano.
  const finRef = useRef<number | null>(null);
  const ciclosDeHoy = pomodoro.fechaCiclos === hoyClave() ? pomodoro.ciclosHoy : 0;

  const duracionDe = useCallback(
    (cual: Fase) =>
      (cual === "enfoque" ? pomodoro.enfoque : cual === "corto" ? pomodoro.descansoCorto : pomodoro.descansoLargo) * 60,
    [pomodoro.enfoque, pomodoro.descansoCorto, pomodoro.descansoLargo],
  );

  const cambiarFase = useCallback(
    (nueva: Fase) => {
      finRef.current = null;
      setFase(nueva);
      setRestante(duracionDe(nueva));
      setCorriendo(false);
    },
    [duracionDe],
  );

  /** Elegir una duración fija ajusta el bloque de enfoque y arranca el reloj. */
  const empezarSesion = useCallback(
    (minutos: number) => {
      acciones.configurarPomodoro({
        enfoque: minutos,
        descansoCorto: pomodoro.descansoCorto,
        descansoLargo: pomodoro.descansoLargo,
      });
      setAviso(null);
      setFase("enfoque");
      setRestante(minutos * 60);
      finRef.current = Date.now() + minutos * 60 * 1000;
      setCorriendo(true);
    },
    [acciones, pomodoro.descansoCorto, pomodoro.descansoLargo],
  );

  const alternarReloj = useCallback(() => {
    setCorriendo((previo) => {
      if (previo) {
        finRef.current = null;
        return false;
      }
      finRef.current = Date.now() + restante * 1000;
      return true;
    });
  }, [restante]);

  const completar = useCallback(() => {
    sonarCampana();
    finRef.current = null;

    if (fase === "enfoque") {
      const siguiente: Fase = (ciclosDeHoy + 1) % 4 === 0 ? "largo" : "corto";
      const minutosDescanso = siguiente === "largo" ? pomodoro.descansoLargo : pomodoro.descansoCorto;
      acciones.sumarCicloPomodoro();
      acciones.registrarLog({ minutos: pomodoro.enfoque, tipo: "pomodoro", temaId: temaId || undefined });
      setAviso(
        `Se cumplieron tus ${pomodoro.enfoque} minutos de estudio. Te toca un descanso de ${minutosDescanso} minutos: levantate de la silla.`,
      );
      cambiarFase(siguiente);
    } else {
      setAviso("Terminó el descanso. Cuando quieras, arrancá otro bloque de estudio.");
      cambiarFase("enfoque");
    }
  }, [acciones, cambiarFase, ciclosDeHoy, fase, pomodoro.descansoCorto, pomodoro.descansoLargo, pomodoro.enfoque, temaId]);

  useEffect(() => {
    if (!corriendo) return undefined;
    const intervalo = window.setInterval(() => {
      const fin = finRef.current;
      if (fin === null) return;
      const quedan = Math.max(0, Math.round((fin - Date.now()) / 1000));
      setRestante(quedan);
      if (quedan === 0) completar();
    }, 500);
    return () => window.clearInterval(intervalo);
  }, [corriendo, completar]);

  const total = duracionDe(fase);
  const progreso = total === 0 ? 0 : 1 - restante / total;
  const radio = 86;
  const circunferencia = 2 * Math.PI * radio;
  const info = TEXTOS[fase];

  return (
    <div className="space-y-6">
      <Tarjeta>
        <TituloSeccion
          icono="pomodoro"
          titulo="Pomodoro"
          bajada="Bloques de enfoque con descansos de verdad. Cada bloque terminado suma a tu constancia."
        />

        <div className="mb-6">
          <p className="em-rotulo mb-2">¿Cuánto vas a estudiar?</p>
          <div className="flex flex-wrap gap-2">
            {DURACIONES.map((minutos) => (
              <button
                key={minutos}
                type="button"
                onClick={() => empezarSesion(minutos)}
                className={`rounded-md border px-3.5 py-2 text-sm font-semibold transition-colors ${
                  fase === "enfoque" && pomodoro.enfoque === minutos
                    ? "border-acento bg-acento-tenue text-acento"
                    : "border-linea-fuerte text-media hover:border-acento hover:text-acento"
                }`}
              >
                {minutos} min
              </button>
            ))}
          </div>
          <p className="mt-2 text-xs text-tenue">
            Elegís el tiempo y el reloj arranca solo. Cuando se cumple, suena un aviso aunque tengas la pantalla en otra cosa.
          </p>
        </div>

        {aviso ? (
          <div className="mb-6 flex flex-wrap items-center justify-between gap-3 rounded-md border border-logro-linea bg-logro-tenue px-4 py-3">
            <p className="flex items-start gap-2 text-sm font-semibold leading-relaxed text-logro">
              <Icono nombre="check" tamaño={16} className="mt-0.5" />
              <span>{aviso}</span>
            </p>
            <Boton variante="fantasma" onClick={() => setAviso(null)}>
              Entendido
            </Boton>
          </div>
        ) : null}

        <div className="flex flex-col items-center gap-6 sm:flex-row sm:items-center sm:justify-center">
          <div className="relative grid place-items-center">
            <svg width="208" height="208" viewBox="0 0 208 208" className="-rotate-90">
              <circle cx="104" cy="104" r={radio} fill="none" stroke="#eef2ff" strokeWidth="14" />
              <circle
                cx="104"
                cy="104"
                r={radio}
                fill="none"
                stroke={fase === "enfoque" ? "#0e5a8a" : fase === "corto" ? "#1c7a54" : "#a4690a"}
                strokeWidth="14"
                strokeLinecap="round"
                strokeDasharray={circunferencia}
                strokeDashoffset={circunferencia * (1 - progreso)}
                style={{ transition: "stroke-dashoffset 1s linear" }}
              />
            </svg>
            <div className="absolute grid place-items-center text-center">
              <Icono nombre={info.icono} tamaño={18} className={`${info.color} ${corriendo ? "em-latido" : ""}`} />
              <span className="em-cifra mt-1 text-4xl font-semibold text-tinta">{relojMmSs(restante)}</span>
              <span className={`em-rotulo mt-0.5 ${info.color}`}>{info.nombre}</span>
            </div>

          </div>

          <div className="w-full max-w-xs space-y-3">
            <div className="flex flex-wrap gap-2">
              <Boton variante={corriendo ? "secundario" : "primario"} onClick={alternarReloj}>
                {corriendo ? "Pausar" : restante === total ? "Empezar" : "Seguir"}
              </Boton>
              <Boton variante="fantasma" icono="repetir" onClick={() => cambiarFase(fase)}>
                Reiniciar
              </Boton>
              <Boton variante="fantasma" icono="flecha" onClick={completar}>
                Saltar
              </Boton>
            </div>

            <div className="flex flex-wrap gap-2">
              {(["enfoque", "corto", "largo"] as Fase[]).map((cual) => (
                <button
                  key={cual}
                  type="button"
                  onClick={() => cambiarFase(cual)}
                  aria-pressed={fase === cual}
                  className={`rounded-full border px-3 py-1.5 text-xs font-semibold transition-colors ${
                    fase === cual ? "border-tinta bg-tinta text-white" : "border-linea text-media hover:border-acento hover:text-acento"
                  }`}
                >
                  {TEXTOS[cual].nombre}
                </button>
              ))}
            </div>

            <Selector etiqueta="¿Qué estás estudiando?" value={temaId} onChange={(evento) => setTemaId(evento.target.value)}>
              <option value="">Sin tema asociado</option>
              {estado.temas.map((tema) => (
                <option key={tema.id} value={tema.id}>
                  {tema.nombre}
                </option>
              ))}
            </Selector>
          </div>
        </div>

        <p className="mt-6 rounded-md bg-papel px-4 py-3 text-center text-sm font-semibold text-media">{info.consejo}</p>
      </Tarjeta>

      <Tarjeta retraso={70}>
        <TituloSeccion icono="pomodoro" titulo="Tus tiempos" bajada="Ajustalos a cómo te concentrás vos, no a lo que dice el manual." />

        <div className="mb-5 grid gap-3 sm:grid-cols-3">
          <Dato valor={`${ciclosDeHoy}`} etiqueta="Bloques de hoy" />
          <Dato valor={minutosLegibles(ciclosDeHoy * pomodoro.enfoque)} etiqueta="Enfoque de hoy" />
          <Dato valor={`${4 - (ciclosDeHoy % 4)}`} etiqueta="Bloques hasta el descanso largo" />
        </div>

        <div className="grid gap-4 sm:grid-cols-3">
          {(
            [
              ["enfoque", "Enfoque", 10, 60],
              ["descansoCorto", "Descanso corto", 3, 15],
              ["descansoLargo", "Descanso largo", 10, 40],
            ] as const
          ).map(([clave, nombre, minimo, maximo]) => (
            <Deslizador
              key={clave}
              etiqueta={nombre}
              unidad="min"
              valor={pomodoro[clave]}
              min={minimo}
              max={maximo}
              step={1}
              onChange={(evento) => {
                  const valor = Number(evento.target.value);
                  acciones.configurarPomodoro({
                    enfoque: pomodoro.enfoque,
                    descansoCorto: pomodoro.descansoCorto,
                    descansoLargo: pomodoro.descansoLargo,
                    [clave]: valor,
                  });
                  const faseDeLaClave = clave === "enfoque" ? "enfoque" : clave === "descansoCorto" ? "corto" : "largo";
                  if (!corriendo && fase === faseDeLaClave) setRestante(valor * 60);
              }}
            />
          ))}
        </div>

        <AvisoPrincipio texto="El pomodoro cuida tu atención. Lo que hacés dentro del bloque —leer, explicar, practicar— lo hacés vos." />
      </Tarjeta>
    </div>
  );
}

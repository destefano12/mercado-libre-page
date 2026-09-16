"use client";

import { useCallback, useEffect, useState } from "react";
import { AvisoPrincipio, Boton, Dato, Deslizador, Selector, Tarjeta, TituloSeccion } from "../components/ui";
import { Icono, type NombreIcono } from "../components/iconos";
import { hoyClave, minutosLegibles, relojMmSs } from "../lib/fechas";
import { useEstudiar } from "../lib/store";

type Fase = "enfoque" | "corto" | "largo";

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
  const ciclosDeHoy = pomodoro.fechaCiclos === hoyClave() ? pomodoro.ciclosHoy : 0;

  const duracionDe = useCallback(
    (cual: Fase) =>
      (cual === "enfoque" ? pomodoro.enfoque : cual === "corto" ? pomodoro.descansoCorto : pomodoro.descansoLargo) * 60,
    [pomodoro.enfoque, pomodoro.descansoCorto, pomodoro.descansoLargo],
  );

  const cambiarFase = useCallback(
    (nueva: Fase) => {
      setFase(nueva);
      setRestante(duracionDe(nueva));
      setCorriendo(false);
    },
    [duracionDe],
  );

  const completar = useCallback(() => {
    sonarCampana();
    if (fase === "enfoque") {
      acciones.sumarCicloPomodoro();
      acciones.registrarLog({ minutos: pomodoro.enfoque, tipo: "pomodoro", temaId: temaId || undefined });
      cambiarFase((ciclosDeHoy + 1) % 4 === 0 ? "largo" : "corto");
    } else {
      cambiarFase("enfoque");
    }
  }, [acciones, cambiarFase, ciclosDeHoy, fase, pomodoro.enfoque, temaId]);

  useEffect(() => {
    if (!corriendo || restante <= 0) return undefined;
    const temporizador = window.setTimeout(() => {
      if (restante <= 1) completar();
      else setRestante(restante - 1);
    }, 1000);
    return () => window.clearTimeout(temporizador);
  }, [corriendo, restante, completar]);

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
              <Boton variante={corriendo ? "secundario" : "primario"} onClick={() => setCorriendo((previo) => !previo)}>
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

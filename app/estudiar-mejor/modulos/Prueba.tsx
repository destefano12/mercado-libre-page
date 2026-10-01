"use client";

import { useMemo, useState } from "react";
import { AvisoPrincipio, Boton, Nota, Pildora, Tarjeta, TituloSeccion, Vacio } from "../components/ui";
import { Icono, type NombreIcono } from "../components/iconos";
import { armarPlanDeEstudio, horizonteDe, type BloqueExpres } from "../lib/expres";
import { nivelDominio } from "../lib/metricas";
import { useEstudiar } from "../lib/store";

/** Cuánto falta para la prueba, en minutos. */
const CUANDO = [
  { etiqueta: "En 40 minutos", minutos: 40 },
  { etiqueta: "En 1 hora", minutos: 60 },
  { etiqueta: "En 3 horas", minutos: 180 },
  { etiqueta: "Mañana", minutos: 20 * 60 },
  { etiqueta: "En 2 días", minutos: 2 * 24 * 60 },
  { etiqueta: "En 3 días", minutos: 3 * 24 * 60 },
  { etiqueta: "En 5 días", minutos: 5 * 24 * 60 },
  { etiqueta: "En una semana", minutos: 7 * 24 * 60 },
];

const POR_DIA = [20, 30, 45, 60, 90, 120];

const TONOS: Record<BloqueExpres["tipo"], { borde: string; fondo: string; texto: string; icono: NombreIcono }> = {
  error: { borde: "border-alerta-linea", fondo: "bg-alerta-tenue", texto: "text-alerta", icono: "errores" },
  flojo: { borde: "border-atencion-linea", fondo: "bg-atencion-tenue", texto: "text-atencion", icono: "mapa" },
  medio: { borde: "border-acento-linea", fondo: "bg-acento-tenue", texto: "text-acento-fuerte", icono: "explicame" },
  firme: { borde: "border-logro-linea", fondo: "bg-logro-tenue", texto: "text-logro", icono: "check" },
  lectura: { borde: "border-linea", fondo: "bg-papel", texto: "text-media", icono: "tutor" },
  descanso: { borde: "border-linea", fondo: "bg-papel", texto: "text-media", icono: "pomodoro" },
  control: { borde: "border-linea-fuerte", fondo: "bg-superficie", texto: "text-tinta", icono: "check" },
};

const NOMBRE_HORIZONTE: Record<string, string> = {
  rescate: "Modo rescate",
  hoy: "Para hoy y mañana",
  dias: "Repartido en días",
  semana: "Semana completa",
};

export function Prueba() {
  const { estado } = useEstudiar();
  const [elegidos, setElegidos] = useState<string[]>([]);
  const [faltan, setFaltan] = useState(60);
  const [porDia, setPorDia] = useState(45);
  const [hechos, setHechos] = useState<string[]>([]);
  const [armado, setArmado] = useState(false);

  const temas = useMemo(() => estado.temas.filter((tema) => elegidos.includes(tema.id)), [estado.temas, elegidos]);

  // El apunte cargado de esos temas: de ahí salen los conceptos del plan.
  const material = useMemo(
    () =>
      estado.materiales
        .filter((archivo) => elegidos.includes(archivo.temaId))
        .map((archivo) => archivo.texto)
        .join("\n"),
    [estado.materiales, elegidos],
  );

  const plan = useMemo(
    () =>
      armado
        ? armarPlanDeEstudio({ temas, dominio: estado.dominio, errores: estado.errores, material, faltan, porDia })
        : null,
    [armado, temas, estado.dominio, estado.errores, material, faltan, porDia],
  );

  const alternar = (id: string) =>
    setElegidos((previo) => (previo.includes(id) ? previo.filter((otro) => otro !== id) : [...previo, id]));

  if (estado.temas.length === 0) {
    return (
      <Vacio
        icono="simulador"
        titulo="Primero cargá los temas"
        texto="Para armarte el plan necesito saber qué entra. Cargá los temas en el tutor —y si podés, subí el apunte en PDF o sacale fotos— y volvé."
      />
    );
  }

  const horizonte = horizonteDe(faltan);
  const faltanMinutos = plan ? plan.bloques.filter((b) => !hechos.includes(b.id)).reduce((t, b) => t + b.minutos, 0) : 0;

  return (
    <div className="space-y-6">
      <Tarjeta>
        <TituloSeccion
          icono="simulador"
          titulo="Tengo prueba"
          bajada="No se estudia igual con cuarenta minutos que con cinco días. Decime cuándo es y cuánto podés estudiar, y te armo el plan con el método que corresponde a ese tiempo."
        />

        <p className="em-rotulo mb-2">¿Qué entra?</p>
        <ul className="mb-5 flex flex-wrap gap-2">
          {estado.temas.map((tema) => {
            const elegido = elegidos.includes(tema.id);
            const nivel = nivelDominio(estado.dominio[tema.id]);
            const color = nivel === "rojo" ? "bg-alerta" : nivel === "amarillo" ? "bg-atencion" : nivel === "verde" ? "bg-logro" : "bg-tenue";
            return (
              <li key={tema.id}>
                <button
                  type="button"
                  onClick={() => alternar(tema.id)}
                  aria-pressed={elegido}
                  className={`flex items-center gap-2 rounded-full border px-3.5 py-1.5 text-sm transition-colors ${
                    elegido ? "border-acento bg-acento-tenue font-semibold text-acento-fuerte" : "border-linea bg-papel text-media hover:border-acento"
                  }`}
                >
                  <span className={`h-2 w-2 rounded-full ${color}`} />
                  {tema.nombre}
                </button>
              </li>
            );
          })}
        </ul>

        <p className="em-rotulo mb-2">¿Cuándo es la prueba?</p>
        <ul className="mb-5 flex flex-wrap gap-2">
          {CUANDO.map((opcion) => (
            <li key={opcion.etiqueta}>
              <button
                type="button"
                onClick={() => setFaltan(opcion.minutos)}
                aria-pressed={faltan === opcion.minutos}
                className={`rounded-full border px-4 py-1.5 text-sm transition-colors ${
                  faltan === opcion.minutos ? "border-acento bg-acento text-white" : "border-linea bg-papel text-media hover:border-acento"
                }`}
              >
                {opcion.etiqueta}
              </button>
            </li>
          ))}
        </ul>

        <p className="em-rotulo mb-2">
          {horizonte === "rescate" || horizonte === "hoy" ? "¿Cuánto tiempo tenés ahora?" : "¿Cuánto podés estudiar por día?"}
        </p>
        <ul className="mb-5 flex flex-wrap gap-2">
          {POR_DIA.map((cuanto) => (
            <li key={cuanto}>
              <button
                type="button"
                onClick={() => setPorDia(cuanto)}
                aria-pressed={porDia === cuanto}
                className={`em-cifra rounded-full border px-4 py-1.5 text-sm transition-colors ${
                  porDia === cuanto ? "border-acento bg-acento text-white" : "border-linea bg-papel text-media hover:border-acento"
                }`}
              >
                {cuanto < 60 ? `${cuanto} min` : `${cuanto / 60} h`}
              </button>
            </li>
          ))}
        </ul>

        <Boton
          icono="simulador"
          disabled={elegidos.length === 0}
          onClick={() => {
            setHechos([]);
            setArmado(true);
          }}
        >
          Armame el plan
        </Boton>

        <AvisoPrincipio texto="El plan dice qué hacer con tu apunte y en qué orden. El apunte lo subís vos y el que estudia sos vos: eso no se puede delegar." />
      </Tarjeta>

      {plan ? (
        <>
          <Tarjeta>
            <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
              <p className="em-rotulo">Cómo leer con este tiempo</p>
              <Pildora tono="acento">{NOMBRE_HORIZONTE[plan.horizonte]}</Pildora>
            </div>
            <h3 className="mb-3 text-lg font-semibold text-tinta">{plan.comoLeer.titulo}</h3>
            <ol className="space-y-2.5">
              {plan.comoLeer.pasos.map((paso, indice) => (
                <li key={paso} className="flex gap-3 text-sm leading-relaxed text-tinta">
                  <span className="em-cifra em-rotulo mt-0.5 shrink-0 text-acento">{indice + 1}</span>
                  <span>{paso}</span>
                </li>
              ))}
            </ol>
            <p className="mt-4 rounded-md bg-alerta-tenue px-4 py-3 text-sm font-semibold leading-relaxed text-alerta">
              {plan.comoLeer.nunca}
            </p>

            {plan.faltaMaterial ? (
              <div className="mt-4">
                <Nota tono="atencion">
                  No tengo tu apunte de estos temas. Subilo en el tutor —PDF o fotos— y el plan deja de hablar en
                  general: te va a decir qué conceptos tuyos mirar en cada paso.
                </Nota>
              </div>
            ) : (
              <div className="mt-4">
                <p className="em-rotulo mb-2">De tu apunte, lo que más pesa</p>
                <ul className="flex flex-wrap gap-2">
                  {plan.conceptos.map((concepto) => (
                    <li key={concepto} className="rounded-full border border-acento-linea bg-acento-tenue px-3 py-1 text-sm text-acento-fuerte">
                      {concepto}
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </Tarjeta>

          <Tarjeta>
            <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
              <div>
                <p className="em-rotulo">Tu plan</p>
                <h3 className="mt-1 text-lg font-semibold text-tinta">
                  {temas.length} {temas.length === 1 ? "tema" : "temas"}
                </h3>
              </div>
              {plan.bloques.length > 0 ? (
                <Pildora tono={faltanMinutos === 0 ? "logro" : "acento"}>
                  {faltanMinutos === 0 ? "Terminaste" : `Faltan ${faltanMinutos} min`}
                </Pildora>
              ) : null}
            </div>

            {plan.advertencia ? <Nota tono="atencion">{plan.advertencia}</Nota> : null}

            {plan.bloques.length > 0 ? (
              <ol className="mt-4 space-y-3">
                {plan.bloques.map((bloque) => {
                  const tono = TONOS[bloque.tipo];
                  const hecho = hechos.includes(bloque.id);
                  return (
                    <li key={bloque.id}>
                      <label className={`flex cursor-pointer gap-3 rounded-md border p-4 transition-opacity ${tono.borde} ${tono.fondo} ${hecho ? "opacity-50" : ""}`}>
                        <input
                          type="checkbox"
                          checked={hecho}
                          onChange={() =>
                            setHechos((previo) =>
                              previo.includes(bloque.id) ? previo.filter((otro) => otro !== bloque.id) : [...previo, bloque.id],
                            )
                          }
                          className="mt-1 h-4 w-4 shrink-0 accent-[#1c7a54]"
                        />
                        <div className="min-w-0 flex-1">
                          <div className="mb-1 flex flex-wrap items-center gap-2">
                            <Icono nombre={tono.icono} tamaño={15} className={tono.texto} />
                            <span className={`font-semibold ${hecho ? "text-tenue line-through" : "text-tinta"}`}>{bloque.titulo}</span>
                            <span className="em-cifra em-rotulo">{bloque.minutos} min</span>
                          </div>
                          <p className="text-sm leading-relaxed text-media">{bloque.detalle}</p>
                        </div>
                      </label>
                    </li>
                  );
                })}
              </ol>
            ) : (
              <ol className="mt-4 space-y-3">
                {plan.dias.map((dia) => {
                  const hecho = hechos.includes(`dia-${dia.numero}`);
                  return (
                    <li key={dia.numero} className={`rounded-md border border-linea bg-superficie p-4 transition-opacity ${hecho ? "opacity-50" : ""}`}>
                      <div className="mb-2 flex flex-wrap items-center gap-2">
                        <label className="flex cursor-pointer items-center gap-2">
                          <input
                            type="checkbox"
                            checked={hecho}
                            onChange={() =>
                              setHechos((previo) =>
                                previo.includes(`dia-${dia.numero}`)
                                  ? previo.filter((otro) => otro !== `dia-${dia.numero}`)
                                  : [...previo, `dia-${dia.numero}`],
                              )
                            }
                            className="h-4 w-4 accent-[#1c7a54]"
                          />
                          <span className="em-rotulo text-acento">{dia.cuando}</span>
                        </label>
                        <span className={`font-semibold ${hecho ? "text-tenue line-through" : "text-tinta"}`}>{dia.titulo}</span>
                        <Pildora tono="neutro">{dia.tecnica}</Pildora>
                      </div>
                      <ul className="space-y-1.5 pl-6">
                        {dia.acciones.map((accion) => (
                          <li key={accion} className="flex gap-2 text-sm leading-relaxed text-media">
                            <span className="mt-2 h-1 w-1 shrink-0 rounded-full bg-acento" />
                            <span>{accion}</span>
                          </li>
                        ))}
                      </ul>
                    </li>
                  );
                })}
              </ol>
            )}

            <p className="mt-5 border-t border-linea pt-4 text-sm italic leading-relaxed text-media">
              Si algo no entra, no agregues horas: sacá un tema. Estudiar hasta las tres de la mañana rinde menos que
              dormir, y eso no es una frase hecha.
            </p>
          </Tarjeta>
        </>
      ) : null}
    </div>
  );
}

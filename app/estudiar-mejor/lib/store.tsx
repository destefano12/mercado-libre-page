"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  useSyncExternalStore,
  type ReactNode,
} from "react";
import { hoyClave } from "./fechas";
import { crearId } from "./id";
import { generarPlan, type EntradaPlan } from "./plan";
import { generarTarjetas, calificarTarjeta, type Calificacion } from "./tutor";
import { estadoDeEjemplo } from "./ejemplo";
import { estadoInicialVacio } from "./vacio";
import type {
  CausaError,
  EstadoEstudiar,
  EventoAgenda,
  Explicacion,
  Grupo,
  HuecoRazonamiento,
  Integrante,
  LogEstudio,
  Material,
  Simulacro,
  Tema,
} from "./tipos";

const CLAVE_ALMACENAMIENTO = "estudiar-mejor:v1";

export const estadoInicial = estadoInicialVacio;

// Marca si ya estamos corriendo en el navegador, sin efectos ni renders en cascada.
const sinSuscripcion = () => () => {};
const enCliente = () => true;
const enServidor = () => false;

function leerAlmacenado(): EstadoEstudiar | null {
  if (typeof window === "undefined") return null;
  try {
    const crudo = window.localStorage.getItem(CLAVE_ALMACENAMIENTO);
    if (!crudo) return null;
    const datos = JSON.parse(crudo) as Partial<EstadoEstudiar>;
    if (typeof datos !== "object" || datos === null) return null;
    return { ...estadoInicial(), ...datos, pomodoro: { ...estadoInicial().pomodoro, ...datos.pomodoro } };
  } catch {
    return null;
  }
}

export interface AccionesEstudiar {
  guardarNombre: (nombre: string) => void;
  guardarAnio: (anio: number) => void;
  aceptarManifiesto: () => void;
  agregarTema: (nombre: string, materia: string) => Tema;
  eliminarTema: (id: string) => void;
  agregarMaterial: (temaId: string, titulo: string, texto: string) => { material: Material; preguntas: number };
  eliminarMaterial: (id: string) => void;
  crearPlan: (entrada: EntradaPlan) => void;
  eliminarPlan: (id: string) => void;
  alternarSesion: (planId: string, sesionId: string) => void;
  calificar: (tarjetaId: string, calificacion: Calificacion) => void;
  registrarError: (entrada: {
    temaId: string;
    titulo: string;
    detalle: string;
    causa: CausaError;
    origen: "simulacro" | "tutor" | "explicacion" | "manual";
  }) => void;
  alternarError: (id: string) => void;
  eliminarError: (id: string) => void;
  guardarExplicacion: (explicacion: Omit<Explicacion, "id" | "creadaEn">) => void;
  crearGrupo: (nombre: string, materia: string, entrega: string, integrantes: { nombre: string; rol: string }[]) => void;
  eliminarGrupo: (id: string) => void;
  agregarIntegrante: (grupoId: string, nombre: string, rol: string) => void;
  eliminarIntegrante: (grupoId: string, integranteId: string) => void;
  agregarTarea: (grupoId: string, integranteId: string, titulo: string) => void;
  alternarTarea: (grupoId: string, integranteId: string, tareaId: string) => void;
  eliminarTarea: (grupoId: string, integranteId: string, tareaId: string) => void;
  agregarEvento: (evento: Omit<EventoAgenda, "id" | "hecho">) => void;
  alternarEvento: (id: string) => void;
  eliminarEvento: (id: string) => void;
  registrarLog: (log: Omit<LogEstudio, "id" | "fecha"> & { fecha?: string }) => void;
  guardarSimulacro: (simulacro: Omit<Simulacro, "id" | "creadoEn">) => void;
  registrarEvidencia: (temaId: string, aciertos: number, intentos: number) => void;
  configurarPomodoro: (config: { enfoque: number; descansoCorto: number; descansoLargo: number }) => void;
  sumarCicloPomodoro: () => void;
  cargarEjemplo: () => void;
  borrarTodo: () => void;
}

interface ContextoEstudiar {
  estado: EstadoEstudiar;
  hidratado: boolean;
  acciones: AccionesEstudiar;
}

const Contexto = createContext<ContextoEstudiar | null>(null);

export function ProveedorEstudiar({ children }: { children: ReactNode }) {
  // El estado se lee del navegador en el primer render del cliente. Hasta que
  // `hidratado` se enciende, cliente y servidor pintan lo mismo (la pantalla de
  // carga), así que no hay desajuste de hidratación.
  const [estado, setEstado] = useState<EstadoEstudiar>(() => leerAlmacenado() ?? estadoInicial());
  const hidratado = useSyncExternalStore(sinSuscripcion, enCliente, enServidor);

  useEffect(() => {
    if (!hidratado || typeof window === "undefined") return;
    try {
      window.localStorage.setItem(CLAVE_ALMACENAMIENTO, JSON.stringify(estado));
    } catch {
      // Si el navegador bloquea el almacenamiento, la app sigue andando en memoria.
    }
  }, [estado, hidratado]);

  const registrarEvidencia = useCallback((temaId: string, aciertos: number, intentos: number) => {
    setEstado((previo) => {
      const actual = previo.dominio[temaId] ?? { aciertos: 0, intentos: 0, actualizado: hoyClave() };
      return {
        ...previo,
        dominio: {
          ...previo.dominio,
          [temaId]: {
            aciertos: actual.aciertos + aciertos,
            intentos: actual.intentos + intentos,
            actualizado: hoyClave(),
          },
        },
      };
    });
  }, []);

  const registrarLog = useCallback<AccionesEstudiar["registrarLog"]>((log) => {
    setEstado((previo) => ({
      ...previo,
      logs: [
        { id: crearId("log"), fecha: log.fecha ?? hoyClave(), minutos: log.minutos, tipo: log.tipo, temaId: log.temaId },
        ...previo.logs,
      ].slice(0, 500),
    }));
  }, []);

  const acciones = useMemo<AccionesEstudiar>(() => {
    const mapearGrupo = (grupoId: string, transformar: (grupo: Grupo) => Grupo) =>
      setEstado((previo) => ({
        ...previo,
        grupos: previo.grupos.map((grupo) => (grupo.id === grupoId ? transformar(grupo) : grupo)),
      }));

    const mapearIntegrante = (
      grupoId: string,
      integranteId: string,
      transformar: (integrante: Integrante) => Integrante,
    ) =>
      mapearGrupo(grupoId, (grupo) => ({
        ...grupo,
        integrantes: grupo.integrantes.map((integrante) =>
          integrante.id === integranteId ? transformar(integrante) : integrante,
        ),
      }));

    return {
      guardarNombre: (nombre) => setEstado((previo) => ({ ...previo, nombre })),
      guardarAnio: (anio) => setEstado((previo) => ({ ...previo, anio })),
      aceptarManifiesto: () => setEstado((previo) => ({ ...previo, manifiestoAceptado: true })),

      agregarTema: (nombre, materia) => {
        const tema: Tema = { id: crearId("tema"), nombre, materia, creadoEn: new Date().toISOString() };
        setEstado((previo) => ({ ...previo, temas: [...previo.temas, tema] }));
        return tema;
      },

      eliminarTema: (id) =>
        setEstado((previo) => ({
          ...previo,
          temas: previo.temas.filter((tema) => tema.id !== id),
          materiales: previo.materiales.filter((material) => material.temaId !== id),
          tarjetas: previo.tarjetas.filter((tarjeta) => tarjeta.temaId !== id),
          planes: previo.planes.filter((plan) => plan.temaId !== id),
        })),

      agregarMaterial: (temaId, titulo, texto) => {
        const material: Material = {
          id: crearId("material"),
          temaId,
          titulo,
          texto,
          creadoEn: new Date().toISOString(),
        };
        const preguntas = generarTarjetas(material);
        setEstado((previo) => ({
          ...previo,
          materiales: [...previo.materiales, material],
          tarjetas: [...previo.tarjetas, ...preguntas],
        }));
        return { material, preguntas: preguntas.length };
      },

      eliminarMaterial: (id) =>
        setEstado((previo) => ({
          ...previo,
          materiales: previo.materiales.filter((material) => material.id !== id),
          tarjetas: previo.tarjetas.filter((tarjeta) => tarjeta.materialId !== id),
        })),

      crearPlan: (entrada) => {
        const plan = generarPlan(entrada);
        setEstado((previo) => ({
          ...previo,
          planes: [plan, ...previo.planes.filter((existente) => existente.temaId !== entrada.temaId)],
          agenda: [
            ...previo.agenda.filter((evento) => evento.nota !== `plan:${entrada.temaId}`),
            {
              id: crearId("evento"),
              tipo: "entrega",
              titulo: `Fecha límite: ${entrada.titulo}`,
              fecha: entrada.fechaLimite,
              temaId: entrada.temaId,
              nota: `plan:${entrada.temaId}`,
              hecho: false,
            },
          ],
        }));
      },

      eliminarPlan: (id) => setEstado((previo) => ({ ...previo, planes: previo.planes.filter((plan) => plan.id !== id) })),

      alternarSesion: (planId, sesionId) =>
        setEstado((previo) => {
          let minutosSumados = 0;
          let temaId: string | undefined;

          const planes = previo.planes.map((plan) => {
            if (plan.id !== planId) return plan;
            temaId = plan.temaId;
            return {
              ...plan,
              sesiones: plan.sesiones.map((sesion) => {
                if (sesion.id !== sesionId) return sesion;
                const hecho = !sesion.hecho;
                minutosSumados = hecho ? sesion.minutos : -sesion.minutos;
                return { ...sesion, hecho, completadaEn: hecho ? new Date().toISOString() : undefined };
              }),
            };
          });

          const logs =
            minutosSumados > 0
              ? [
                  { id: crearId("log"), fecha: hoyClave(), minutos: minutosSumados, tipo: "plan" as const, temaId },
                  ...previo.logs,
                ].slice(0, 500)
              : previo.logs;

          return { ...previo, planes, logs };
        }),

      calificar: (tarjetaId, calificacion) => {
        setEstado((previo) => ({
          ...previo,
          tarjetas: previo.tarjetas.map((tarjeta) =>
            tarjeta.id === tarjetaId ? calificarTarjeta(tarjeta, calificacion) : tarjeta,
          ),
        }));
      },

      registrarError: (entrada) =>
        setEstado((previo) => {
          const existente = previo.errores.find(
            (error) =>
              error.temaId === entrada.temaId &&
              error.titulo.toLowerCase().trim() === entrada.titulo.toLowerCase().trim(),
          );

          if (existente) {
            return {
              ...previo,
              errores: previo.errores.map((error) =>
                error.id === existente.id
                  ? { ...error, veces: error.veces + 1, resuelto: false, ultimaVez: hoyClave(), detalle: entrada.detalle || error.detalle }
                  : error,
              ),
            };
          }

          return {
            ...previo,
            errores: [
              {
                id: crearId("error"),
                ...entrada,
                veces: 1,
                resuelto: false,
                creadoEn: hoyClave(),
                ultimaVez: hoyClave(),
              },
              ...previo.errores,
            ],
          };
        }),

      alternarError: (id) =>
        setEstado((previo) => ({
          ...previo,
          errores: previo.errores.map((error) => (error.id === id ? { ...error, resuelto: !error.resuelto } : error)),
        })),

      eliminarError: (id) =>
        setEstado((previo) => ({ ...previo, errores: previo.errores.filter((error) => error.id !== id) })),

      guardarExplicacion: (explicacion) =>
        setEstado((previo) => ({
          ...previo,
          explicaciones: [
            { ...explicacion, id: crearId("explicacion"), creadaEn: new Date().toISOString() },
            ...previo.explicaciones,
          ].slice(0, 100),
        })),

      crearGrupo: (nombre, materia, entrega, integrantes) =>
        setEstado((previo) => ({
          ...previo,
          grupos: [
            {
              id: crearId("grupo"),
              nombre,
              materia,
              entrega,
              creadoEn: new Date().toISOString(),
              integrantes: integrantes.map((integrante, indice) => ({
                id: crearId("integrante"),
                nombre: integrante.nombre,
                rol: integrante.rol,
                esYo: indice === 0,
                tareas: [],
              })),
            },
            ...previo.grupos,
          ],
        })),

      eliminarGrupo: (id) =>
        setEstado((previo) => ({ ...previo, grupos: previo.grupos.filter((grupo) => grupo.id !== id) })),

      agregarIntegrante: (grupoId, nombre, rol) =>
        mapearGrupo(grupoId, (grupo) => ({
          ...grupo,
          integrantes: [...grupo.integrantes, { id: crearId("integrante"), nombre, rol, esYo: false, tareas: [] }],
        })),

      eliminarIntegrante: (grupoId, integranteId) =>
        mapearGrupo(grupoId, (grupo) => ({
          ...grupo,
          integrantes: grupo.integrantes.filter((integrante) => integrante.id !== integranteId),
        })),

      agregarTarea: (grupoId, integranteId, titulo) =>
        mapearIntegrante(grupoId, integranteId, (integrante) => ({
          ...integrante,
          tareas: [...integrante.tareas, { id: crearId("tarea"), titulo, hecho: false }],
        })),

      alternarTarea: (grupoId, integranteId, tareaId) =>
        mapearIntegrante(grupoId, integranteId, (integrante) => ({
          ...integrante,
          tareas: integrante.tareas.map((tarea) => (tarea.id === tareaId ? { ...tarea, hecho: !tarea.hecho } : tarea)),
        })),

      eliminarTarea: (grupoId, integranteId, tareaId) =>
        mapearIntegrante(grupoId, integranteId, (integrante) => ({
          ...integrante,
          tareas: integrante.tareas.filter((tarea) => tarea.id !== tareaId),
        })),

      agregarEvento: (evento) =>
        setEstado((previo) => ({
          ...previo,
          agenda: [...previo.agenda, { ...evento, id: crearId("evento"), hecho: false }],
        })),

      alternarEvento: (id) =>
        setEstado((previo) => ({
          ...previo,
          agenda: previo.agenda.map((evento) => (evento.id === id ? { ...evento, hecho: !evento.hecho } : evento)),
        })),

      eliminarEvento: (id) =>
        setEstado((previo) => ({ ...previo, agenda: previo.agenda.filter((evento) => evento.id !== id) })),

      registrarLog,

      guardarSimulacro: (simulacro) =>
        setEstado((previo) => ({
          ...previo,
          simulacros: [{ ...simulacro, id: crearId("simulacro"), creadoEn: new Date().toISOString() }, ...previo.simulacros].slice(0, 50),
        })),

      registrarEvidencia,

      configurarPomodoro: (config) =>
        setEstado((previo) => ({ ...previo, pomodoro: { ...previo.pomodoro, ...config } })),

      sumarCicloPomodoro: () =>
        setEstado((previo) => {
          const hoy = hoyClave();
          const ciclosHoy = previo.pomodoro.fechaCiclos === hoy ? previo.pomodoro.ciclosHoy + 1 : 1;
          return { ...previo, pomodoro: { ...previo.pomodoro, ciclosHoy, fechaCiclos: hoy } };
        }),

      cargarEjemplo: () => setEstado(estadoDeEjemplo()),

      borrarTodo: () => {
        setEstado(estadoInicial());
        if (typeof window !== "undefined") {
          try {
            window.localStorage.removeItem(CLAVE_ALMACENAMIENTO);
          } catch {
            // Sin almacenamiento disponible no hay nada que borrar.
          }
        }
      },
    };
  }, [registrarEvidencia, registrarLog]);

  const valor = useMemo<ContextoEstudiar>(() => ({ estado, hidratado, acciones }), [estado, hidratado, acciones]);

  return <Contexto.Provider value={valor}>{children}</Contexto.Provider>;
}

export function useEstudiar(): ContextoEstudiar {
  const contexto = useContext(Contexto);
  if (!contexto) throw new Error("useEstudiar necesita estar dentro de ProveedorEstudiar");
  return contexto;
}

export type HuecosDeExplicacion = HuecoRazonamiento[];
